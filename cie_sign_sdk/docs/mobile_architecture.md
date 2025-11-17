# Architettura SDK Mobile CIE

## Layer e responsabilità

| Layer | Responsabilità | Note |
| --- | --- | --- |
| **App / UI nativa** | Gestione sessione NFC, richiesta PIN/PUK, UX errori, storage sicuro delle credenziali. | Implementata in SwiftUI/UIKit e Jetpack Compose; comunica con l'SDK tramite binding nativi. |
| **Adapter NFC (`TokenTransmitCallback`)** | Espone a IAS un canale ISO-DEP. Traduce eventi CoreNFC / IsoDep in chiamate `HRESULT (*)(void*, uint8_t*, DWORD, uint8_t*, DWORD*)`. | Specifico per piattaforma. Mantiene ATR, selezione lettore e timeouts. |
| **Core C++ (riuso `IAS`, `CCIESigner`, `CSignatureGenerator`, `PdfSignatureGenerator`, ecc.)** | Autenticazione CIE, lettura certificati, generazione PKCS#7/CAdES/PDF/XML, gestione TSA. | Compilato come static library condivisa tra iOS/Android. Non contiene riferimenti a PC/SC o filesystem. |
| **Bindings pubblici (C API)** | Funzioni `extern "C"` per creare/distruggere contesti, passare buffer, opzioni, callback di log. | Esposte tramite modulemap (iOS) e JNI wrapper (Android). |

## Flusso principale di firma
1. L'app avvia la sessione NFC e ottiene ATR + handle: crea un `IASHandle` passando il callback verso il layer NFC.
2. L'app raccoglie PIN, parametri documento (tipo, buffer, impostazioni PDF) e li passa al core mediante la nuova API C.
3. Il core usa `IAS` per autenticarsi, `CCIESigner` per firmare digest e `CSignatureGenerator`/`PdfSignatureGenerator` per produrre il formato richiesto.
4. Il core restituisce il buffer firmato, insieme ai metadati (lunghezza, codice errore). L'app salva/condivide il risultato.

## Dipendenze e sostituzioni
- **Da ricompilare**: OpenSSL (solo engine e ASN.1), Crypto++, libxml2, PoDoFo (se mantenuto), zlib, libpng, freetype/fontconfig (necessari per rendering firma grafica).
- **Da sostituire**:
  - libcurl → wrapper su networking nativo (NSURLSession / OkHttp). Interfaccia comune da implementare in C++ tramite callback forniti dalla piattaforma.
  - PC/SC → già sostituito dal callback NFC.
- **Da ridurre**: logging (`UUCLogger`) deve offrire hook verso i logger di piattaforma ed essere disattivabile in produzione.

## Dati e errori
- Tutti gli input documento vengono passati come buffer (`uint8_t* + size_t`), mai come path.
- Gli errori tornano tramite enum:
  - `CIE_STATUS_OK`
  - `CIE_STATUS_CARD_ERROR` (include SW)
  - `CIE_STATUS_DEPENDENCY_ERROR`
  - `CIE_STATUS_INVALID_INPUT`
  - `CIE_STATUS_UNSUPPORTED_FEATURE`
- Dettagli aggiuntivi disponibili tramite `cie_get_last_error()` thread-local.

## Sicurezza
- I PIN passano come `const char*` + `size_t` e vengono azzerati subito dopo l'uso.
- Le funzioni di log sono opzionali e devono oscurare dati sensibili.
- Le librerie vengono compilate con `-fstack-protector`, `-fvisibility=hidden`, e integrano ASLR/bitcode dove richiesto.

## Deliverable configurati
- Static library `libciesign_core.a` (iOS) e `libciesign_core.so` (Android).
- Header pubblici in `include/mobile`.
- Binding Swift (`CieSignKit.xcframework`) e Android (`com.example.ciesign` AAR) costruiti sopra la C API.

## Bridge iOS (CoreNFC)

- **CieNfcSession** (`ios/CieSignBridge/CieNfcSession.*`): incapsula `NFCTagReaderSession` e traduce l'API asincrona di CoreNFC in tre callback sincroni (`open/transceive/close`) richiesti da `cie_platform_nfc_adapter`. Su simulator e piattaforme prive di NFC ritorna errori strutturati (`CieSignNfcErrorDomain`) mantenendo l’interfaccia identica.
- **CieSignMobileBridge**: espone un'API Objective-C/Swift-friendly (`sign(pdf:pin:appearance:)`) che costruisce al volo il `cie_platform_config`, crea il contesto `cie_sign_ctx` tramite `cie_sign_ctx_create_with_platform` e invoca `cie_sign_execute`. Gestisce buffer, traduzione errori e pulizia delle sessioni NFC.
- **SwiftUI Host** (`ios/CieSignIosHost`): usa il bridge reale. L'app avvia il flusso quando l’utente preme “Firma PDF di esempio”; durante la sessione mostra un loader e, su dispositivi reali, passa il controllo a CoreNFC per rilevare la carta. Sul simulatore l'utente riceve un messaggio “CoreNFC non disponibile”.
- I file bridge sono inseriti nel progetto Xcode principale (`CieSignIosTests.xcodeproj`) e linkano le stesse statiche `libciesign_core.a`/`libcie_sign_sdk.a` usate dagli XCTest, garantendo che il codice di produzione e quello di test condividano i medesimi binari.

## Riuso IAS e interfaccia NFC comune

- Il codice C++ riutilizza integralmente i moduli storici `IAS`, `CCIESigner`, `CSignatureGenerator` e `PdfSignatureGenerator`. La classe `IAS` (`cie_sign_sdk/src/CSP/IAS.cpp`) contiene già l’intera sequenza richiesta dalla CIE: selezione AID IAS/CIE, scambio Diffie-Hellman, gestione del secure messaging (3DES + MAC3), device authentication (“dApp”), verifica PIN e comandi `PSO: COMPUTE DIGITAL SIGNATURE`. Non è più necessario duplicare questa logica lato Kotlin/Swift.
- L’unico requisito per le piattaforme è fornire al core un adapter NFC tramite `cie_platform_nfc_adapter`:
  - `open`: restituisce ATR e lunghezza (derivati da `IsoDep.getHistoricalBytes()` su Android o `NFCTag.atrDescription` su iOS).
  - `transceive`: inoltra raw APDU/risposte, rispettando i timeout richiesti dal chip (tipicamente 60 s per la firma).
  - `close`: chiude la sessione fisica (`IsoDep.close()`, `invalidateSession()`).
- Le opzioni PDF (`cie_pdf_options`) contengono ora anche l'immagine della firma (`signature_image` + `len`), ricevuta come byte array direttamente dalle app (Flutter/host). `PdfSignatureGenerator` carica il buffer come immagine PoDoFo e costruisce la stream di appearance del widget, garantendo un rendering omogeneo tra piattaforme.
- `cie_sign_ctx_create_with_platform` usa l’adapter per popolare `IAS` e reimposta automaticamente il callback `TokenTransmitCallback`. Qualsiasi errore dallo strato NFC viene propagato tramite `cie_sign_get_last_error` e trasformato in eccezioni platform-specific (es. `RuntimeException` in JNI).
- Questo approccio replica esattamente il funzionamento del vecchio `Ias.kt` Android (FEASDK), ma delega la logica crittografica al core condiviso. In pratica: Android/iOS devono solo occuparsi di sessione reader-mode, raccolta PIN, progress UI e storage del PDF; tutto il protocollo IAS rimane invariato e comune.
- Per verificare la retrocompatibilità basta confrontare gli APDU inviati: sia l’SDK precedente sia il core attuale emettono gli stessi comandi (SELECT AID, READ FILE 0x100x, VERIFY PIN, ecc.). In caso di futuri adattamenti (nuovi SW, aggiornamenti CIE) è sufficiente modificare `IAS.cpp` e ricompilare; le app mobile ne beneficeranno automaticamente.

## Aggiornamento PoDoFo 1.x e pipeline PDF

- **Output PoDoFo full-buffer**: `PdfSignatureGenerator` mantiene una copia del PDF originale (`m_streamBuffer`) e consegna a PoDoFo un `ContainerStreamDevice<std::string>` in modalità read/write. In questo modo `StartSigning/FinishSigning` scrivono il documento completo (xref incluso) e `GetSignedPdf` restituisce direttamente `m_streamBuffer`, senza ricombinare manualmente chunk incrementali come avveniva con il vecchio PoDoFo.
- **Verifica ByteRange/Contents**: `PdfVerifier` non usa più parsing testuale con `strtok`; ora risolve gli oggetti nei dizionari di catalogo/AcroForm, legge `/ByteRange` come `PdfArray`, decodifica `/Contents` (anche se viene serializzato in hex) e ricostruisce il buffer firmato usando PoDoFo. Il certificato estratto dal CMS viene confrontato con quello presente nel documento.
- **Test end-to-end**: `tests/mock/mock_sign_test.cpp` scrive `build/host/mock_signed.pdf`, lo riapre con PoDoFo per assicurarsi che esista almeno un campo `/Sig` e, tramite il nuovo `PDFVerifier`, recupera il CMS e valida che il certificato corrisponda al mock usato dal signer. Lo stesso test continua a decodificare `/ByteRange` per garantire che la firma prodotta sia coerente.
- Questa architettura ci permette di riutilizzare la stessa pipeline sia in produzione (firmware PoDoFo 1.x) sia nei test, evitando workaround specifici per desktop e mantenendo la compatibilità con i reader iOS/Android.
- **Campo firma nominato**: `cie_pdf_options` espone `field_ids` (lista di stringhe UTF-8). Quando valorizzata l’SDK firma esattamente i campi corrispondenti (nell’ordine fornito), sovrascrivendo l’apparenza con l’immagine passata. Se l’elenco è vuoto, vengono firmati in sequenza tutti i widget `/Sig` ancora vuoti; solo quando il PDF non contiene campi firma l’SDK ne crea uno nuovo utilizzando `page_index/left/bottom/width/height`.
