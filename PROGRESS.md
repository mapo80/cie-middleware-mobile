# Progresso Implementazione SDK Mobile

## 2025-11-16

### 1. Abstraction layer per piattaforme native
- Creato il file `cie_sign_sdk/include/mobile/cie_platform.h` contenente le nuove interfacce:
  - `cie_platform_nfc_adapter` per incapsulare apertura, transceive e chiusura della sessione NFC.
  - `cie_platform_logger` per log opzionali.
  - `cie_platform_config` che descrive come inizializzare il contesto (`nfc`, `logger`, fallback legacy).
- Questo layer servirà per implementare gli adapter specifici di iOS (CoreNFC) e Android (NfcAdapter) mantenendo un'unica API C.

### 2. Nuova API di creazione del contesto
- Aggiornato `cie_sign_sdk/include/mobile/cie_sign.h` con la funzione `cie_sign_ctx_create_with_platform`.
- L’implementazione in `cie_sign_sdk/src/mobile/cie_sign_core.cpp`:
  - Supporta sia l’approccio legacy (APDU callback + ATR) sia il nuovo `cie_platform_config`.
  - Gestisce l’apertura/chiusura dell’adapter NFC e instrada le APDU tramite uno shim interno.
  - Archivia eventuale logger per utilizzi futuri (al momento solo memorizzato, non ancora utilizzato dal core).

### 3. Pulizia e compatibilità
- La funzione storica `cie_sign_ctx_create` ora delega alla nuova API garantendo retrocompatibilità.
- In distruzione del contesto viene effettuata la chiusura dell’adapter se definita.

### Prossimi passi
- Utilizzare il logger nella catena di FIRMA (strumentazione errori / tracing).
- Implementare gli adapter NFC reali su Android (Kotlin) e iOS (Swift) sfruttando le nuove strutture.
- Aggiornare i test mock per creare il contesto tramite `cie_sign_ctx_create_with_platform`.

## 2025-11-16 (Aggiornamento)

### 4. Logger di piattaforma e reporting errori
- Aggiornato `cie_sign_sdk/src/mobile/cie_sign_core.cpp` con helper `log_message` e storage `LoggerState`.
- Tutte le condizioni di errore (buffer pieno, input invalido, doc type non supportato, map_error) ora invocano il logger se presente.

### 5. Adapter mock basato su `cie_platform_config`
- `cie_sign_sdk/tests/mock/mock_transport.cpp` usa il nuovo `cie_platform_nfc_adapter` per creare i contesti dei test.
- Garantisce che i percorsi mock (strumentazione Android/iOS) sfruttino la stessa API delle implementazioni reali.

## 2025-11-17

### 6. Toolchain Android + Flutter
- Installati Android Build-Tools 28.0.3 e piattaforma SDK 36 necessari per `flutter doctor`.
- Accettate tutte le licenze Android con `JAVA_HOME` impostata su JDK17.
- Verificato setup Flutter 3.38.1 (`flutter doctor -v`), rimane aperto solo l’allineamento CocoaPods per i test iOS.

### 7. Plugin Flutter condiviso (`cie_sign_flutter/`)
- Creato plugin multipiattaforma (`flutter create --template=plugin`) e collegato il modulo nativo Android `android/cieSignSdk` tramite `settings.gradle` + dipendenza Gradle dedicata.
- Aggiornata `CieSignSdk` native lib per localizzare automaticamente `cie_sign_sdk/Dependencies-arm64-android` anche quando inclusa via plugin.
- Implementata API Dart `CieSignFlutter.mockSignPdf(...)` con supporto opzionale a un percorso di output.
- Metodo channel Android (`CieSignFlutterPlugin.kt`) richiama `CieSignSdk.mockSignPdf`, effettua validazioni input e propaga eventuali errori strutturati.
- Lato iOS lasciato un placeholder che emette `FlutterError` in attesa del binding reale.

### 8. App di esempio e test Dart
- L’app di esempio (`cie_sign_flutter/example/lib/main.dart`) carica l’asset `assets/sample.pdf`, invoca il plugin e salva `mock_signed_flutter.pdf` in Documenti mostrando stato e percorso.
- Configurato `path_provider` + asset nel `pubspec.yaml` e vincolato `minSdk` Android a 26.
- Aggiunto integration test (`integration_test/mock_sign_integration_test.dart`) che esercita la firma mock su device/emulatore e valida header PDF + presenza `/Type/Sig`.
- Aggiornata suite di unit test Dart per il nuovo contract MethodChannel; `flutter test` passa localmente.

### 9. Test end-to-end Flutter su Android (AVD)
- Configurato l’emulatore arm64 `CieSignArm64` e avviato tramite `emulator -avd CieSignArm64 -no-snapshot`.
- Adeguati i build script Android per usare NDK 26.2, includere direttamente i sorgenti `android/cieSignSdk` (CMake + sorgenti Kotlin) dentro il plugin e rimuovere la dipendenza Gradle separata.
- Eseguito `flutter test integration_test/mock_sign_integration_test.dart -d emulator-5554` che compila l’intera pipeline nativa, firma il PDF di esempio e salva `mock_signed_flutter_integration.pdf` nella sandbox dell’app (`/storage/emulated/0/Android/data/it.ipzs.cie_sign_flutter_example/files/`).

### 10. Visualizzazione PDF nell’app Flutter di esempio
- Aggiunta la dipendenza `flutter_pdfview` e integrato un visualizzatore embedded che carica automaticamente `mock_signed_flutter.pdf` dopo la firma.
- L’interfaccia ora mostra il percorso del file e consente di vedere immediatamente la pagina del PDF firmato o eventuali errori del viewer.

### 11. Esperienza utente migliorata durante la firma
- Lo stato `_busy` ora pilota una vista dedicata con `CircularProgressIndicator` per mostrare chiaramente il loader finché la firma mock è in corso.
- Il viewer viene renderizzato solo dopo il completamento con successo e con `_outputPath` valorizzato, evitando che venga mostrato un PDF precedente mentre la nuova firma è in esecuzione.

### 12. Bridge iOS reale (CoreNFC)
- Creato il modulo `ios/CieSignBridge` con `CieNfcSession` (Objective-C++) che incapsula `NFCTagReaderSession` e fornisce le callback richieste da `cie_platform_nfc_adapter`. Su simulatore e dispositivi senza NFC restituisce errori controllati.
- Implementato `CieSignMobileBridge` che costruisce il `cie_platform_config`, richiama `cie_sign_ctx_create_with_platform` e mappa l’output/errore verso API Swift. Include helper `CieSignPdfParameters` per configurare la firma PDF.
- Aggiornato `ios/CieSignIosHost` con `SigningViewModel`/`ContentView` per avviare la pipeline reale: caricamento del PDF di esempio, richiesta della sessione NFC, gestione stato UI.
- Allineato `CieSignIosTests.xcodeproj` (frameworks, search paths, bridging header) e ricompilate le statiche `libciesign_core.a`/`libcie_sign_sdk.a` per `ios-sim` così da includere la nuova API C e poter linkare il bridge direttamente dal target host.

### 13. Test iOS con NFC mock (parità con Android)
- `CieSignMobileBridge` espone ora l’inizializzatore `init(mockTransportWithLogger:)` che utilizza `MockApduTransport` al posto di CoreNFC; il metodo `sign(pdf:pin:appearance:)` viene eseguito con gli stessi parametri del bridge reale ma senza hardware.
- `SigningViewModel` viene eseguito integralmente in modalità mock così da poter usare l’app sull’emulatore iOS e ottenere immediatamente il PDF firmato.
- Aggiunto lo XCTest `CieSignBridgeTests` che replica le asserzioni dell’instrumented test Android (header `%PDF`, presenza `/Type/Sig`, persistenza del file in Documents) utilizzando il nuovo bridge.
- Il target host linka ora `mock_transport.cpp`/`mock_apdu_sequence.cpp`, permettendo di riutilizzare la fixture APDU già presente nei test C++.

### 14. Plugin Flutter: flusso NFC reale (Android) e test UI mock
- Estesa la piattaforma Dart (`CieSignFlutterPlatform`) con `signPdfWithNfc`, `cancelNfcSigning` e la classe `PdfSignatureAppearance`, esportata pubblicamente da `cie_sign_flutter.dart`.
- Aggiornato il channel Android (`CieSignFlutterPlugin.kt`) riutilizzando l’implementazione realizzata in precedenza per `signPdfWithNfc`; il MethodChannel ora accetta mappe `appearance/pin/outputPath` e può annullare sessioni NFC.
- L’app di esempio Flutter è stata riscritta per essere l’unica UI cross-platform: campo PIN condiviso, loader comune, pulsanti separati per “mock” e “NFC” e viewer PDF integrato. Aggiunto pulsante di annullo che richiama `cancelNfcSigning`.
- Creato un widget test (`example/test/mock_nfc_ui_test.dart`) che sostituisce sia il plugin sia `PathProvider` con mock e simula l’intero flusso UI, validando loader e stato finale senza hardware NFC.
- Aggiornati i test di pacchetto (`flutter test`) per coprire i nuovi metodi MethodChannel e garantire che l’API Flutter rimanga coerente con Android/iOS.

### 15. Plugin headless e immagine firma come byte array
- Il plugin Flutter non fornisce più componenti UI: `mockSignPdf` e `signPdfWithNfc` accettano un oggetto `PdfSignatureAppearance` (con coordinate normalizzate, metadati e `signatureImageBytes`). Le app Flutter host gestiscono PIN, loader e viewer; l’esempio rimane come demo esterna.
- `cie_pdf_options` include `signature_image`/`signature_image_len`; `PdfSignatureGenerator` carica il buffer con PoDoFo (`PdfImage`) e imposta l’appearance del widget tramite `PdfPainter`, così l’immagine compare nei PDF firmati (mock e NFC).
- JNI/SDK Android aggiornati: `CieSignSdk.mockSignPdf` supporta `PdfAppearanceOptions`, `NativeBridge` inoltra i nuovi parametri e sia `mock_sign_android.cpp` sia `nfc_sign_android.cpp` compilano `cie_sign_request` con l’immagine.
- Flutter tests (package + example) aggiornati per i nuovi parametri; gli asset necessari (PDF e PNG) sono iniettati nei test tramite callback per evitare dipendenze dalla toolchain.

### 16. Gestione campi firma preesistenti (AcroForm)
- Creato lo script `scripts/generate_sample_pdf.py` (ReportLab + pypdf) che rigenera `cie_sign_flutter/example/assets/sample.pdf` e `cie_sign_sdk/data/fixtures/sample.pdf` con il campo firma AcroForm `SignatureField1`, evidenziato dal rettangolo rosso iniziale.
- Esteso `cie_pdf_options` con `field_ids`/`field_ids_len`; `PdfSignatureGenerator` può ora: enumerare i campi non firmati, inizializzare un campo esistente per nome, iterare su tutti i campi disponibili e, se necessario, creare un nuovo campo fallback (come prima).
- `cie_sign_core::sign_pdf` esegue la firma in sequenza: se viene passato un elenco di ID firma li processa nell’ordine indicato; altrimenti firma tutti i campi disponibili e, solo se nessuno è presente, ne crea uno nuovo usando le coordinate normalizzate.
- Aggiornati JNI/SDK Android, plugin Flutter (Dart/Kotlin) e bridge mock/strumentali per ricevere e propagare `fieldIds`. `PdfSignatureAppearance`/`PdfAppearanceOptions` espongono la nuova lista; i test Dart/Kotlin verificano che il MethodChannel inoltri correttamente i valori.
- `mock_sign_test.cpp` ora copre i tre scenari (campo nominato, auto-detection e creazione forzata) verificando con PoDoFo che l’apparenza `/AP` venga applicata e che i certificati coincidano con il mock signer.
