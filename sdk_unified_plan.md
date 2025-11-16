# SDK Unificato (iOS / Android) con supporto Flutter

## 1. Visione generale
Obiettivo: esporre un'unica API di firma CIE verso Flutter riutilizzando il core C/C++ (`cie_sign_sdk`). Le parti NFC rimangono specifiche per sistema operativo ma collegate tramite interfacce comuni per facilitare l’implementazione nativa e i test.

```
                 +---------------------+
                 |   Flutter Plugin    |
                 +----------+----------+
                            |
           +----------------+----------------+
           |                                 |
   +-------+--------+               +--------+-------+
   |  iOS Bridge    |               |  Android Bridge |
   |  Swift         |               |  Kotlin         |
   +-------+--------+               +--------+-------+
           \                               /
            \                             /
             +-----------+---------------+
                         |
               +---------+---------+
               |  C API (cie_sign) |
               +---------+---------+
                         |
               +---------+---------+
               |    Core C++       |
               +-------------------+
```

## 2. API design condiviso
1. Definire contratto di alto livello (`CieSignSdk`) con metodi asincroni:
   - `initialize(context)` → carica risorse, inizializza callback NFC.
   - `signPkcs7(input: SignInput) : SignResult`.
   - `signPdf(pdf: PdfInput, appearance: SignatureAppearance) : SignedPdf`.
   - `verify(signature)` → opzionale.
2. Schemi dati comuni (JSON-friendly) e codici errore tipizzati (`enum class CieSignError`).
3. Convenzione di logging/tracking (eventi, latenza, steps).

## 3. Layer nativo C/C++
1. Rifattorizzare `ciesign_core` per garantire:
   - API C stabile (`cie_sign_ctx`, `cie_sign_execute`).
   - Call-back virtualizzati per **NFC**, storage, log, networking (TSA) definiti in header dedicato (`cie_sign_platform.h`).
2. Compilare librerie statiche per tutte le piattaforme (host, iOS arm64/sim, Android arm64/armeabi/x64).

## 4. Interfacce NFC / Sistema Operativo
1. Creare interfaccia astratta lato C per le operazioni NFC (`cie_nfc_adapter` con `open`, `transceive`, `close`, `stateChanged`).
2. Nei bridge Android/iOS:
   - Implementare un adapter Kotlin/Swift che traduce le API NFC native (Android `NfcAdapter`, iOS `CoreNFC`) verso l’interfaccia C.
   - Permettere injection di mock per i test (strumentali / unit).
3. Definire protocolli per storage temporaneo (PDF output) e accesso file-system (permettere fallback in memoria).

## 5. Bridge piattaforma
### Android
- Libreria Gradle (`cieSignSdk`) con JNI:
  - Classe `CieSignSdk` Kotlin → espone sospend functions/flussi `Flow`.
  - Il bridge mantiene un `NativeContext` e registra un `NfcChannel`.
  - Fornisce binding per Flutter plugin (MethodChannel).

### iOS
- Framework Swift:
  - Classe `CieSignSdk` Swift + `CieSignError`.
  - Wrapper Objective‑C++ per chiamare il C API e interagire con `CoreNFC`.
  - Supporta Combine/async-await e callback per progressi.

## 6. Plugin Flutter
1. Pacchetto `cie_sign_flutter`:
   - `MethodChannel` o `FFI` (valutare, ma iniziare con channel).
   - API Dart `CieSign` con metodi asincroni (Future/Stream).
   - Gestione permission e notifiche NFC lato Dart.
2. Implementazioni `AndroidCieSignPlugin` / `IosCieSignPlugin` che delegano ai bridge nativi.
3. Esempio di applicazione e widget dimostrativi.

## 7. Build & Tooling
1. Script per dipendenze vcpkg:
   - `build_dependencies.sh <triplet>`
   - `build_ios_dependencies.sh <triplet>`
   - `build_android_dependencies.sh <triplet>`
2. Pipeline CI:
   - Linux/macOS: build core + test mock (`ctest`).
   - iOS: `xcodebuild test` su simulatori.
   - Android: `connectedDebugAndroidTest` su AVD.
   - Flutter: `flutter test` + `flutter drive --driver`.
3. Packaging:
   - `XCFramework` + `AAR`.
   - Pubblicazione plugin Dart (pub.dev) e binari (GitHub Releases).

## 8. Testing
1. **Unit test native**: mock transport, PoDoFo, PKCS#7.
2. **Instrumented test mobile**: pipeline mock (senza NFC reale).
3. **Integration test Flutter**: esecuzione plugin su emulatori/simulatori.
4. Pianificare test con NFC reale (hardware) quando l’implementazione sarà disponibile.

## 9. Roadmap sintetica
| Fase | Attività | Output |
| ---- | -------- | ------ |
| F1 | Spec API + modelli dati | Documento API condivisa |
| F2 | Refactor core C/C++ con callback NFC/storage/log | Header stabile `cie_sign_platform.h` |
| F3 | Bridge Kotlin/Swift con nuove interfacce | Librerie native uniformi |
| F4 | Plugin Flutter baseline + sample app | pacchetto `cie_sign_flutter` |
| F5 | Automazione build/test/artefatti | CI + release |
| F6 | Documentazione + manuali integrazione | README/guide |
| F7 | Estensioni NFC reali + security review | Supporto hardware |
