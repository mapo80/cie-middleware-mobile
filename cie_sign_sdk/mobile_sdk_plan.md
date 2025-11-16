# Piano per l'SDK di firma mobile

## Obiettivi principali
- Ricavare dai sorgenti `cie_sign_sdk` i componenti riutilizzabili su iOS/Android per la firma CIE.
- Sostituire o ricompilare le dipendenze native (PoDoFo, libcurl, OpenSSL, ecc.) in modo compatibile con i toolchain mobili.
- Esporre un'API moderna (Swift/Kotlin) orientata a buffer/stream anziché a file system.
- Integrare la lettura NFC/PIN nativa lasciando all'SDK il solo compito di orchestrare APDU, firma e formati (PKCS#7, PDF, XML, ecc.).

## Fasi operative

1. **Definizione architetturale**
   - Disegnare il perimetro dell'SDK mobile: quali moduli riusare (IAS, CIESigner, SignatureGenerator, PdfSignatureGenerator…), quali sostituire.
   - Definire le responsabilità tra layer nativo (APDU/NFC, UI PIN) e libreria multipiattaforma.

2. **Isolamento del core C++**
   - Estrarre un target C++ “core-signing” privo di dipendenze da PC/SC e filesystem (solo callback APDU + buffer in memoria).
   - Scrivere test/driver che usano un `TokenTransmitCallback` fittizio per validare il caricamento certificati e la generazione PKCS#7.

3. **Adattamento dipendenze**
   - Valutare per ciascuna dipendenza:
     - **Ricompilazione**: OpenSSL, Crypto++, libxml2, PoDoFo, libpng/freetype/fontconfig (solo se servono davvero per PDF).
     - **Sostituzione**: libcurl → NSURLSession/CFNetwork su iOS e HttpURLConnection/OkHttp su Android; eventuale rimozione di componenti desktop-only.
   - Preparare script/toolchain CMake o Bazel/podspec per produrre static library/xcframework ed equivalente Android (.aar o .so).

4. **Interfacce per le piattaforme**
   - Progettare API C (extern "C") pulite da esporre tramite JNI/Swift.
   - Definire modelli dati (struct) per input/output: documento da firmare (buffer), parametri PDF (page/rect, motivo, immagine), opzioni TSA.
   - Mappare errori `StatusWord`/codici DISIGON su enum/exception lato mobile.

5. **Integrazione NFC/PIN**
   - Implementare un `TokenTransmitCallback` per iOS (CoreNFC + Secure Enclave) e per Android (NfcAdapter + IsoDep) che fornisca ATR e mantenga la sessione.
   - Gestire il PIN sul lato app (secure text entry, keychain) e passarne solo la copia necessaria a `CCIESigner::Init`.

6. **Funzionalità PDF/XML**
   - Verificare se PoDoFo è sostenibile su mobile; in alternativa considerare wrapper verso librerie native (PDFKit/iText/AndroidPdfViewer) o limitare l'SDK al PKCS#7 lasciando al client l'apposizione grafica.
   - Per XML/XAdES assicurarsi che libxml2 o alternative leggere siano disponibili e compilabili.

7. **Packaging e tool di build**
   - Configurare build script:
     - iOS: CMake + toolchain iOS o Xcode project → static library/xcframework + module map.
     - Android: CMake + NDK (ABI arm64-v8a/armeabi-v7a) → .so + AAR di distribuzione.
   - Automatizzare la copia degli header pubblici (es. `include/`) e la generazione di documentazione.

8. **Testing e QA**
   - Integrare test automatici per PKCS#7/PDF/XML usando certificati e APDU mock.
   - Predisporre harness manuali per testare NFC reale con simulatori/QA device.
   - Verificare conformità ETSI/AgID e firma remota dove richiesto (TSA/CRL/OCSP).

9. **Documentazione**
   - Redigere guide per integratori: setup, flussi PIN, gestione errori, esempi Swift/Kotlin.
   - Documentare le limitazioni note (dipendenze non supportate, requisiti OS, ecc.).

10. **Rilascio e manutenzione**
    - Definire versionamento semantico, changelog e pipeline CI (GitHub Actions/Azure DevOps) per compilare artefatti iOS/Android.
    - Pianificare aggiornamenti periodici delle dipendenze crittografiche e patch di sicurezza.

## Prossimi passi concreti
1. Validare l’architettura descritta in `docs/mobile_architecture.md` con gli stakeholder e chiudere le decisioni aperte (PoDoFo vs alternative, gestione libcurl, formato API).
2. Implementare il target `ciesign_core` seguendo la strategia in `docs/core_isolation.md`, introducendo gradualmente le nuove API in memoria.
3. Preparare mock APDU e test automatici per il core rifattorizzato.
4. In parallelo avviare l’analisi delle dipendenze esterne (licenze, disponibilità mobile) per definire il backlog di cross-compilazione o sostituzione.
