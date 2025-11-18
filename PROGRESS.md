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

## 2025-11-18

### 12. Vendorizzazione di `flutter_pdfview` 1.2.2
- Copiata la release originale del plugin in `third_party/flutter_pdfview-1.2.2` così da poterla patchare in modo ripetibile senza toccare la `.pub-cache`.
- Aggiornato `android/build.gradle` del plugin con namespace moderno (`io.endigo.plugins.pdfview`), `compileSdkVersion 34`, `minSdkVersion 21`, compatibilità Java 8 e repository `google/mavenCentral/jitpack`.
- Rimpiazzata la dipendenza obsoleta `com.github.barteksc:android-pdf-viewer` (non più pubblicata) con `com.github.barteksc:AndroidPdfViewer:3.1.0-beta.1`, unico artefatto disponibile su JitPack che espone la stessa API Java attesa dal plugin.
- Allineato il `AndroidManifest.xml` del plugin al nuovo package per evitare collisioni con `com.shockwave.pdfium`.
- L’esempio Flutter punta ora alla directory vendorizzata tramite dependency path nel `pubspec.yaml`, garantendo a tutto il team lo stesso codice sorgente del viewer.

### 13. Tooling Gradle e Jetifier per l’esempio Android
- Aggiornati `cie_sign_flutter/example/android/settings.gradle.kts` e `build.gradle.kts` aggiungendo `maven("https://jitpack.io")` sia a livello di pluginManagement sia sugli `allprojects`.
- Abilitato `android.enableJetifier=true` in `cie_sign_flutter/example/android/gradle.properties` per riconciliare automaticamente le vecchie librerie `com.android.support` importate da AndroidPdfViewer con il mondo AndroidX.
- Rigenerato il `pubspec.lock` dell’esempio eseguendo `flutter pub get`, così da fissare il riferimento al plugin locale e al nuovo grafo di dipendenze.

### 14. Test di integrazione Flutter con il viewer legacy
- Eseguito `flutter test integration_test/ui_mock_flow_test.dart -d emulator-5554` (emulatore `CieSignArm64`) con `JAVA_HOME=/Users/politom/Library/Java/JavaVirtualMachines/temurin-17.0.11.jdk/Contents/Home`: compilazione, installazione APK e scenario di firma mock completano correttamente, confermando che `flutter_pdfview` 1.2.2 patchato continua a funzionare.
- Il test verifica che il PDF scritto dall’SDK contenga `/Type/Sig` e che il nuovo viewer full-screen apra la copia temporanea `_viewerPath`, requisito richiesto per visualizzare la firma appena salvata senza incorrere nella cache del plugin.
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

### 12. Plugin Flutter iOS con CoreNFC reale
- Il plugin iOS (`cie_sign_flutter/ios/Classes/CieSignFlutterPlugin.m`) supporta ora i metodi `signPdfWithNfc` e `cancelNfcSigning`, esponendo lo stesso contract disponibile su Android.
- Introdotta una coda seriale di lavoro per non bloccare il thread UI durante l’esecuzione di `cie_sign_execute`. Le chiamate NFC sono instradate al bridge `CieSignMobileBridge` che usa `CieNfcSession` per gestire `NFCTagReaderSession`.
- Per i test/simulatore resta disponibile la firma mock (`mockSignPdf`), sempre basata su `MockApduTransport`.
- Il layer Objective-C++ (`CieSignMobileBridge`) accetta ora field ID multipli e immagini di firma RGBA (width/height), allineandosi alle opzioni `cie_pdf_options`. È stata aggiunta l’API `cancelActiveSession` per invalidare la sessione CoreNFC quando l’utente annulla il flow.
- Il parsing dei parametri `PdfSignatureAppearance` lato iOS legge anche `fieldIds` e `signatureImage` (Uint8List) e li converte in RGBA tramite CoreGraphics, così l’apparenza risultante corrisponde al comportamento Android.

### 17. Firma disegnata dall’utente nell’app Flutter
- L’esempio Flutter dipende ora dal plugin `hand_signature`: abbiamo inserito un canvas tattile per disegnare la firma e salvarla come PNG (convertita poi in RGBA dai bridge nativi).
- L’utente deve esplicitamente premere “Salva firma” prima di procedere: in assenza di una firma salvata viene mostrato un errore e l’SDK non viene invocato.
- La firma salvata viene visualizzata come anteprima e riutilizzata sia nel flusso mock sia nel flusso NFC; i test continuano a funzionare tramite l’hook `loadSignatureImage` che fornisce bytes custom in contesti automatizzati.

### 18. Viewer Flutter aggiornato a `pdfrx`
- Rimosso il vendor locale di `flutter_pdfview` (directory `third_party/flutter_pdfview-1.2.2/`) e la relativa dipendenza dal `pubspec` dell’esempio.
- Aggiunta la dipendenza da `pdfrx ^2.2.15` e sostituito `PdfPreviewPage` con il widget `PdfViewer.file`, includendo banner di caricamento/errori e un overlay durante il salvataggio sul filesystem host.
- Rieseguito `flutter pub get` per rigenerare il `pubspec.lock` con il nuovo grafo.

### 19. Snellimento build Flutter (rimozione PDFium WASM)
- Eseguito `dart run pdfrx:remove_wasm_modules` nella cartella `cie_sign_flutter/example` subito dopo `flutter pub get`, così i binari WASM (~4 MB) non vengono più impacchettati nelle build Android/iOS.
- Notato nel README di pdfrx che il comando è reversibile (`--revert`); annotato il passaggio in questo log per ripeterlo prima di ogni build release.
- Verificato l’impatto ricompilando il test di integrazione sull’emulatore (`flutter test integration_test/ui_mock_flow_test.dart -d emulator-5554` con `JAVA_HOME` impostato a Temurin 17): il flusso mock produce ancora il PDF firmato e il viewer resta funzionante, ora senza warning “PDFium WASM” a runtime.

### 20. PIN di default aggiornato
- Aggiornati l’app d’esempio e tutti i test (unitari e widget) per usare il nuovo PIN predefinito `25051980` al posto del precedente `12345678`.
- `cie_sign_flutter/example/lib/main.dart` inizializza ora il campo PIN con il nuovo valore; i test `cie_sign_flutter_method_channel_test.dart`, `cie_sign_flutter_test.dart` e `example/test/mock_nfc_ui_test.dart` verificano la stessa costante per evitare regressioni.

### 21. Piano di integrazione NFC reale
- Analizzato il progetto di riferimento (`feasdk` in `/Users/politom/Downloads/bppb-android-app-master@b023b074cc3`) e documentato come l’attuale SDK C++ gestisce già IAS/DAPP (`cie_sign_sdk/src/CSP/IAS.cpp`).
- Creato `cie_sign_sdk/docs/nfc_integration_plan.md` con i task concreti: eventi reader mode nel plugin, logging IAS tramite `cie_platform_logger`, test mock basato su transcript reale, guida di test manuale per CIE fisica e allineamento iOS.
- Il piano servirà come backlog per l’implementazione effettiva della firma reale su Android/iOS senza duplicare la logica IAS in Kotlin/Swift.

### 22. Eventi NFC e UI Flutter
- Aggiunto un `EventChannel` (`cie_sign_flutter/nfc_events`) nel plugin Android (`CieSignFlutterPlugin.kt`): emette stati (`state/ready-disabled`), eventi di ascolto/tag, errori, completamento e annullo. Il stream è esposto in Dart tramite `NfcSessionEvent` (`lib/src/nfc_session_event.dart`) e reso disponibile via `CieSignFlutter.watchNfcEvents()`.
- Integrato la UI dell’esempio per reagire agli eventi (status automatici, loader visibile, invito ad avvicinare la carta) e subscribed agli eventi per aggiornare `_status`.
- Aggiornati i test:
  * `cie_sign_flutter_method_channel_test.dart` verifica che il `watchNfcEvents` del MethodChannel riceva eventi mappati.
  * `cie_sign_flutter_test.dart` e `example/test/mock_nfc_ui_test.dart` usano piattaforme fake con `StreamController` per simulare eventi.
- Documentazione e codice formattati; tutte le suite (`flutter test` nel plugin e nell’esempio) tornano verdi.

### 23. Copertura test >= 90%
- Aggiunti nuovi test unitari per il package Flutter: `nfc_session_event_test.dart` copre tutte le varianti di evento; `cie_sign_flutter_platform_interface_test.dart` esercita il token enforcement della PlatformInterface e i fallback `UnimplementedError`; `cie_sign_flutter_test.dart` ora verifica anche i casi di input non valido su `mockSignPdf` e `signPdfWithNfc`.
- Esecuzione `flutter test --coverage` in `cie_sign_flutter/` porta la copertura totale al ~95% (80/84 linee) con tutti i file principali al 100% tranne il MethodChannel (92%).

### 24. Verifica certificato nei PDF firmati
- Estratta la logica di lettura CMS (già usata in `mock_sign_test`) in un piccolo tool CLI `pdf_signature_check` (`cie_sign_sdk/tests/tools/pdf_signature_check.cpp`).
- Il tool si builda insieme al target host (`cmake --build cie_sign_sdk/build/host --target pdf_signature_check`) e accetta `pdf_signature_check signed.pdf [expected_CN]`, stampando il CN di ogni firma ed esitando con errore se `expected_CN` non compare.
- Per i test mock continuiamo a validare che il certificato coincida con `Mock Mobile Signer`; per il giro NFC reale basta estrarre il PDF dal dispositivo (via `adb shell run-as ... cat > file.pdf`) e lanciare il tool per verificare quale certificato è stato usato.
