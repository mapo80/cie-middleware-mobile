# CIE Mobile Signing SDK

Modernizzazione completa dello stack di firma per **Carta d'Identità Elettronica (CIE)** italiana con obiettivo di offrire:

- un **core nativo comune** (C/C++) che gestisce APDU IAS, firme PKCS#7/PDF/XML e validazioni;
- bridge Kotlin/Swift per piattaforme mobili con API simmetriche;
- un **plugin Flutter headless** riutilizzabile in qualsiasi applicazione multipiattaforma.

---

## Architettura

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter App (Demo)                      │
│       UI PDF viewer + NFC session + firma grafica       │
└────────────────────┬────────────────────────────────────┘
                     │ MethodChannel
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────────┐   ┌───────▼────────────┐
│  Android Bridge    │   │   iOS Bridge       │
│  (Kotlin Plugin)   │   │  (ObjC/Swift)      │
└────────┬───────────┘   └────────┬───────────┘
         │ JNI                    │ Native
         └────────────┬───────────┘
                      │
         ┌────────────▼────────────┐
         │   ciesign_core (C++)    │
         │  ├─ NFC/APDU Handler    │
         │  ├─ PIN Verification    │
         │  └─ Signature Engine    │
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │  cie_sign_sdk (C/C++)   │
         │  ├─ PdfSignatureGen     │
         │  ├─ PKCS#7 Generator    │
         │  └─ ASN.1 / Crypto      │
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │   Vendor Libraries      │
         │  PoDoFo, OpenSSL,       │
         │  Crypto++, libxml2      │
         └─────────────────────────┘
```

---

## Tecnologie e Linguaggi

| Layer | Tecnologia | Linguaggio | Note |
|-------|-----------|-----------|------|
| **Core Firma** | PoDoFo 1.x + Crypto++ | C/C++ (C++17) | PDF signing, PKCS#7, ASN.1, RSA, hashing |
| **Android** | Kotlin + JNI | Kotlin + C++ | MethodChannel → JNI → Native |
| **iOS** | CoreNFC | Objective-C/Swift | MethodChannel → CoreNFC bridge |
| **Flutter** | Flutter SDK 3.3+ | Dart | Plugin headless + UI demo |
| **Build** | CMake 3.15+ | CMake | Cross-compilation multipiattaforma |
| **Dipendenze** | vcpkg | - | OpenSSL, libcurl, libxml2, zlib, freetype, libpng |

### Versioni Tools Richieste

- CMake 3.15+
- Gradle 9.2
- Kotlin 1.9.24
- Android Gradle Plugin 8.6.0
- Android NDK r26
- Xcode (per iOS)
- Flutter SDK 3.3+ (Dart 3.10+)
- Java 17

---

## Struttura del Repository

```
cie-middleware-linux/
│
├── cie_sign_sdk/                     # Core C/C++ della libreria di firma
│   ├── src/                          # Codice sorgente (~160 file)
│   │   ├── ASN1/                     # Parsing/generazione strutture ASN.1
│   │   ├── Crypto/                   # Algoritmi crittografici
│   │   ├── PCSC/                     # Protocollo smart card
│   │   ├── CSP/                      # IAS e gestione ATR
│   │   ├── RSA/                      # Implementazione RSA
│   │   ├── Util/                     # Utilita generiche
│   │   ├── mobile/                   # Bridge mobile (cie_sign_core.cpp)
│   │   ├── PdfSignatureGenerator.cpp # Generatore firme PDF
│   │   ├── PdfVerifier.cpp           # Verifica firme PDF
│   │   └── SignatureGenerator.cpp    # PKCS#7 generator
│   ├── include/
│   │   ├── mobile/                   # API pubblica (cie_sign.h)
│   │   └── disigonsdk.h
│   ├── tests/
│   │   ├── mock/                     # Test mock signer
│   │   ├── tools/                    # CLI (pdf_signature_check.cpp)
│   │   └── dart_host/                # Bridge Dart host
│   ├── Dependencies/                 # Librerie precompilate host
│   ├── Dependencies-ios/             # Librerie per iOS device
│   ├── Dependencies-ios-sim/         # Librerie per iOS simulator
│   ├── cmake/toolchains/             # Toolchain cross-compilation
│   └── CMakeLists.txt                # Build configuration
│
├── cie_sign_flutter/                 # Plugin Flutter
│   ├── lib/
│   │   ├── cie_sign_flutter.dart                    # Interfaccia pubblica
│   │   ├── cie_sign_flutter_method_channel.dart     # MethodChannel bridge
│   │   ├── cie_sign_flutter_platform_interface.dart
│   │   └── src/
│   │       ├── nfc_session_event.dart               # Eventi NFC
│   │       └── pdf_signature_appearance.dart        # Config firma PDF
│   ├── android/src/main/kotlin/.../
│   │   └── CieSignFlutterPlugin.kt   # Handler Android
│   ├── ios/Classes/
│   │   ├── CieSignFlutterPlugin.m    # Handler iOS
│   │   └── Bridge/                   # CieNfcSession.mm, CieSignMobileBridge.mm
│   ├── example/                      # App demo Flutter
│   │   ├── lib/main.dart             # UI principale
│   │   ├── android/                  # Build Android
│   │   └── ios/                      # Build iOS
│   ├── test/                         # Unit/widget test
│   └── pubspec.yaml                  # Dipendenze Flutter
│
├── android/                          # Modulo Gradle principale
│   ├── cieSignSdk/                   # SDK Kotlin con JNI
│   │   ├── src/main/kotlin/          # Codice Kotlin
│   │   ├── src/main/jni/             # Bindings JNI → C++
│   │   └── build.gradle
│   ├── CieSignMockApp/               # App di test Android
│   ├── build.gradle                  # Root gradle config
│   ├── settings.gradle
│   └── gradle.properties
│
├── ios/                              # Progetto Xcode
│   ├── CieSignIosHost/               # App host demo iOS
│   ├── CieSignIosTests/              # Test suite iOS
│   └── CieSignIosTests.xcodeproj/
│
├── scripts/                          # Script helper
│   ├── build_ios_libs.sh             # Compila librerie native iOS
│   ├── deploy_ios_device.sh          # Deploy su iPhone
│   └── deploy_android_device.sh      # Deploy su Android
│
└── README.md
```

### Mappa delle Directory

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              REPOSITORY ROOT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        cie_sign_sdk/                                 │   │
│  │  CORE C/C++ - Motore di firma digitale                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  src/                                                                │   │
│  │  ├── ASN1/          → Parser strutture ASN.1 per certificati       │   │
│  │  ├── Crypto/        → AES, DES3, SHA*, MD5, MAC                    │   │
│  │  ├── RSA/           → Firma RSA e gestione chiavi                  │   │
│  │  ├── CSP/           → Comunicazione IAS con smart card CIE         │   │
│  │  ├── PCSC/          → Protocollo PC/SC per lettori NFC             │   │
│  │  ├── Util/          → Logging, TLV, utilities                      │   │
│  │  ├── mobile/        → Bridge per Android/iOS (cie_sign_core.cpp)   │   │
│  │  ├── PdfSignatureGenerator.cpp  → Genera firme PDF                 │   │
│  │  ├── PdfVerifier.cpp            → Verifica firme esistenti         │   │
│  │  └── SignatureGenerator.cpp     → PKCS#7 / CMS                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  include/mobile/    → Header pubblici (cie_sign.h)                  │   │
│  │  tests/tools/       → CLI pdf_signature_check                       │   │
│  │  Dependencies*/     → Librerie precompilate (OpenSSL, PoDoFo...)   │   │
│  │  cmake/toolchains/  → Cross-compilation iOS/Android                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       cie_sign_flutter/                              │   │
│  │  PLUGIN FLUTTER - Wrapper Dart per il core nativo                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  lib/                                                                │   │
│  │  ├── cie_sign_flutter.dart      → API pubblica Dart                │   │
│  │  ├── *_method_channel.dart      → Bridge MethodChannel             │   │
│  │  └── src/                       → Eventi NFC, appearance firma     │   │
│  │                                                                      │   │
│  │  android/                       → Plugin Android (Kotlin)           │   │
│  │  ios/Classes/                   → Plugin iOS (Objective-C)          │   │
│  │  ios/Classes/Bridge/            → CoreNFC bridge                    │   │
│  │                                                                      │   │
│  │  example/                       → App demo completa                 │   │
│  │  └── lib/main.dart              → UI con PDF viewer + firma        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌───────────────────────┐    ┌───────────────────────┐                   │
│  │      android/         │    │        ios/           │                   │
│  │  SDK Kotlin standalone │    │  Test Xcode standalone│                   │
│  ├───────────────────────┤    ├───────────────────────┤                   │
│  │  cieSignSdk/          │    │  CieSignIosHost/      │                   │
│  │  ├── JNI bindings     │    │  └── App test nativa  │                   │
│  │  └── Kotlin wrapper   │    │  CieSignIosTests/     │                   │
│  │  CieSignMockApp/      │    │  └── XCTest suite     │                   │
│  │  └── App test         │    │                       │                   │
│  └───────────────────────┘    └───────────────────────┘                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          scripts/                                    │   │
│  │  AUTOMAZIONE - Script per build e deploy                            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  build_ios_libs.sh      → Compila ciesign_core per iOS arm64       │   │
│  │  deploy_ios_device.sh   → Build Flutter + deploy su iPhone         │   │
│  │  deploy_android_device.sh → Build Flutter + deploy su Android      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Descrizione Moduli

| Directory | Tipo | Contenuto | Output |
|-----------|------|-----------|--------|
| `cie_sign_sdk/` | C/C++ | Core firma digitale | `libcie_sign_sdk.a`, `libciesign_core.a` |
| `cie_sign_flutter/` | Dart | Plugin Flutter | Package `cie_sign_flutter` |
| `cie_sign_flutter/example/` | Flutter | App demo | APK / IPA |
| `android/` | Kotlin | SDK Android standalone | AAR library |
| `ios/` | ObjC/Swift | Test iOS standalone | XCTest bundle |
| `scripts/` | Bash | Automazione | - |

### Dipendenze tra Moduli

```
┌──────────────┐
│ Flutter App  │  (cie_sign_flutter/example)
└──────┬───────┘
       │ dipende da
       ▼
┌──────────────┐
│Flutter Plugin│  (cie_sign_flutter)
└──────┬───────┘
       │ dipende da
       ├─────────────────┬─────────────────┐
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│Android Plugin│  │  iOS Plugin  │  │    (test)    │
│   (Kotlin)   │  │   (ObjC)     │  │              │
└──────┬───────┘  └──────┬───────┘  └──────────────┘
       │                 │
       └────────┬────────┘
                │ link statico
                ▼
       ┌──────────────┐
       │ ciesign_core │  (C++)
       └──────┬───────┘
              │
              ▼
       ┌──────────────┐
       │cie_sign_sdk  │  (C/C++)
       └──────┬───────┘
              │
              ▼
       ┌──────────────┐
       │   Vendors    │  (OpenSSL, PoDoFo, Crypto++, libxml2...)
       └──────────────┘
```

---

## Componenti Principali

| Componente | Linguaggio | Responsabilita | File Chiave |
|------------|-----------|----------------|-------------|
| **Core Firma** | C/C++ | PKCS#7, PDF, XML signing | `PdfSignatureGenerator.cpp`, `SignatureGenerator.cpp` |
| **ASN.1** | C++ | Parsing/generazione strutture | `src/ASN1/` (~50 file) |
| **Crypto** | C/C++ | AES, DES3, RSA, SHA*, MD5, MAC | `src/Crypto/`, `src/RSA/` |
| **IAS/PCSC** | C++ | Comunicazione smart card CIE | `src/CSP/IAS.cpp`, `src/PCSC/Token.cpp` |
| **Mobile Core** | C++ | Bridge NFC e APDU | `src/mobile/cie_sign_core.cpp` |
| **PDF Verifier** | C++ | Estrazione e validazione firme | `PdfVerifier.cpp` |
| **Android Plugin** | Kotlin | MethodChannel + NFC | `CieSignFlutterPlugin.kt` |
| **iOS Plugin** | ObjC | MethodChannel + CoreNFC | `CieSignFlutterPlugin.m`, `CieNfcSession.mm` |
| **Flutter API** | Dart | Interfaccia pubblica | `cie_sign_flutter.dart` |
| **CLI Tool** | C++ | Verifica PDF offline | `tests/tools/pdf_signature_check.cpp` |

---

## Dipendenze Esterne (Vendor)

| Libreria | Scopo |
|----------|-------|
| **OpenSSL** | TLS, certificati, hashing |
| **Crypto++** | Crittografia avanzata |
| **PoDoFo 1.x** | Manipolazione PDF |
| **libxml2** | Parsing XML, XAdES |
| **libcurl** | HTTP per TSA (timestamp authority) |
| **zlib** | Compressione |
| **libpng** | Immagini firma PNG |
| **FreeType** | Font per firma |
| **bzip2** | Compressione |

---

## Flussi Operativi

### Firma PDF Mock (senza NFC)

```
Flutter UI
    │
    ▼ mockSignPdf(pdfBytes, appearance)
MethodChannel
    │
    ▼
Kotlin/Swift Handler
    │
    ▼
ciesign_core (mock mode)
    │
    ▼
PdfSignatureGenerator
    │
    ▼ genera firma con certificato mock
PDF Firmato
    │
    ▼
Flutter UI (visualizza/salva)
```

### Firma PDF con NFC (carta reale)

```
Flutter UI (inserisci PIN)
    │
    ▼ signPdfWithNfc(pdfBytes, pin, appearance)
MethodChannel
    │
    ▼
NFC Adapter (Android/iOS)
    │
    ▼ avvicina carta CIE
Legge carta via APDU
    │
    ▼
ciesign_core (NFC mode)
    │
    ▼ estrae chiave RSA dalla carta
PdfSignatureGenerator
    │
    ▼ firma con chiave reale
PDF Firmato
    │
    ▼
Flutter UI (visualizza/salva)
```

### Verifica PIN via NFC

```
Flutter UI (inserisci PIN)
    │
    ▼ verifyPinWithNfc(pin)
MethodChannel
    │
    ▼
NFC Adapter
    │
    ▼ avvicina carta CIE
Invia PIN via APDU
    │
    ▼
CIE verifica internamente
    │
    ▼ Success / Fail (tentativi rimasti)
Flutter UI (mostra risultato)
```

### Stream Eventi NFC

```
NFC Adapter
    │
    ├─ state         → Stato sessione
    ├─ listening     → In attesa carta
    ├─ tag           → Carta rilevata
    ├─ error         → Errore comunicazione
    └─ completed     → Operazione completata
    │
    ▼ EventChannel
Flutter App (Stream<NfcSessionEvent>)
```

---

## Flow di Compilazione

```
                    CMake Configure
                          │
            ┌─────────────┼─────────────┐
            │             │             │
            ▼             ▼             ▼
      cie_sign_sdk   ciesign_core    Tests
      (static lib)   (mobile wrap)   (executables)
            │             │
            └──────┬──────┘
                   │
     ┌─────────────┼─────────────┐
     │             │             │
     ▼             ▼             ▼
  Host Build   Android NDK    iOS Xcode
  (macOS/Linux)    │             │
                   ▼             ▼
              arm64-v8a      arm64 device
              (via Gradle)   (via xcframework)
```

---

## Funzionalita Implementate

- Firma PDF/PKCS#7 mock e via NFC reale (Android e iOS testati su device fisici)
- **Verifica PIN via NFC** esposta da Flutter/Android/iOS con UI dedicata nell'app di esempio
- Gestione completa dell'apparenza grafica (firma disegnata, motivi, field IDs, posizionamento)
- Tool CLI `pdf_signature_check` per estrarre i CMS da un PDF e validare il certificato utilizzato
- Streaming eventi NFC (stato, ascolto, tag letto, completamento/cancellazione) consumabili dal front-end Flutter
- Suite di test:
  - `cie_sign_sdk` (C++) esercita sia il mock signer sia la nuova `cie_sign_verify_pin`
  - `android/CieSignMockApp` instrumentation test genera PDF firmati anche su emulatori
  - `cie_sign_flutter` unit/widget test coprono MethodChannel, eventi e UI mock NFC

---

## Build & Test

### Requisiti

| Tool | Versione Minima | Installazione |
|------|-----------------|---------------|
| CMake | 3.15+ | `brew install cmake` |
| Java | 17 | `brew install openjdk@17` |
| Android SDK | API 34 | Android Studio |
| Android NDK | r26 | Android Studio SDK Manager |
| Flutter | 3.3+ | [flutter.dev](https://flutter.dev) |
| Xcode | 15+ | App Store |
| CocoaPods | latest | `sudo gem install cocoapods` |

### Comandi Principali

| Target | Comando | Note |
|--------|---------|------|
| **Core host** | `cd cie_sign_sdk && cmake -B build/host && cmake --build build/host && ctest --test-dir build/host --output-on-failure` | Produce librerie + `pdf_signature_check` |
| **Android SDK/app** | `cd android && JAVA_HOME=<jdk17> ./gradlew CieSignMockApp:connectedDebugAndroidTest` | Richiede emulator API34 con NFC |
| **Flutter plugin** | `cd cie_sign_flutter && flutter test` | Unit/widget test |
| **Flutter integration** | `cd cie_sign_flutter/example && flutter test integration_test/mock_nfc_ui_test.dart` | Test integrazione |
| **iOS mock tests** | `cd ios && xcodebuild test -scheme CieSignIosTests -destination 'platform=iOS Simulator,name=iPhone 15'` | Mock-only |

---

## Deploy su Device Fisici

### iOS - Deploy su iPhone

#### Prerequisiti iOS

1. **Xcode** installato con command line tools
2. **Certificato sviluppatore** Apple configurato
3. **iPhone** connesso via USB e "trusted"
4. **Dipendenze native** in `cie_sign_sdk/Dependencies-ios/`

#### Metodo Rapido (Script)

```bash
# Build librerie native + deploy app Flutter
./scripts/deploy_ios_device.sh

# Solo build librerie native (senza deploy)
./scripts/build_ios_libs.sh device

# Build per simulator
./scripts/build_ios_libs.sh simulator

# Build per entrambi
./scripts/build_ios_libs.sh all
```

#### Metodo Manuale

```bash
# 1. Compila librerie native per iOS arm64
cd cie_sign_sdk
cmake -B build/ios-arm64 \
  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ios-arm64.cmake \
  -DDEPENDENCIES_DIR="$(pwd)/Dependencies-ios" \
  -DCIE_SIGN_SDK_SKIP_TESTS=ON
cmake --build build/ios-arm64 --target ciesign_core -j8

# 2. Copia librerie nella directory attesa dal podspec
mkdir -p build/ios
cp build/ios-arm64/*.a build/ios/

# 3. Aggiorna CocoaPods
cd ../cie_sign_flutter/example/ios
pod install

# 4. Deploy con Flutter
cd ..
flutter run
```

#### Apertura in Xcode

```bash
# Apri il workspace (non il .xcodeproj!)
open cie_sign_flutter/example/ios/Runner.xcworkspace
```

In Xcode:
1. Seleziona il tuo iPhone come target
2. Verifica Signing & Capabilities (Team, Provisioning Profile)
3. Clicca **Run** (Cmd+R)

#### Troubleshooting iOS

| Problema | Soluzione |
|----------|-----------|
| `Library 'ciesign_core' not found` | Esegui `./scripts/build_ios_libs.sh device` |
| Errore signing | Configura Team ID in Xcode |
| Pod install fallisce | `cd ios && rm -rf Pods Podfile.lock && pod install` |
| Build fallisce | `flutter clean && flutter pub get` |

### Android - Deploy su Device

```bash
# Build e deploy
./scripts/deploy_android_device.sh <device_id>

# Lista device disponibili
adb devices
```

---

## Script Disponibili

Gli script si trovano in `scripts/`:

| Script | Descrizione | Uso |
|--------|-------------|-----|
| `build_ios_libs.sh` | Compila librerie native iOS | `./scripts/build_ios_libs.sh [device\|simulator\|all]` |
| `deploy_ios_device.sh` | Build + deploy su iPhone | `./scripts/deploy_ios_device.sh [device_id] [--release]` |
| `deploy_android_device.sh` | Build + deploy su Android | `./scripts/deploy_android_device.sh [device_id] [--release]` |

### Esempi

```bash
# iOS
./scripts/build_ios_libs.sh                    # Compila device + simulator
./scripts/build_ios_libs.sh device             # Solo device fisico
./scripts/deploy_ios_device.sh                 # Deploy debug
./scripts/deploy_ios_device.sh --release       # Deploy release

# Android
./scripts/deploy_android_device.sh             # Deploy sul primo device
./scripts/deploy_android_device.sh AE6RUT47    # Deploy su device specifico
```

---

## Strumenti Utili

### Verifica PIN via NFC

Nell'app esempio basta inserire il PIN e toccare "Verifica PIN" per avviare lo stesso flusso di lettura carta utilizzato dalla firma.

### CLI `pdf_signature_check`

```bash
# Compila il tool
cmake --build cie_sign_sdk/build/host --target pdf_signature_check

# Esegui verifica
./cie_sign_sdk/build/host/pdf_signature_check signed.pdf "CN atteso"
```

Utile per validare i PDF estratti dal device (`adb shell run-as ... cat > file.pdf`).

### Deployment Android

```bash
# Build e deploy su device connesso
cie_sign_flutter/scripts/deploy_android_device.sh <deviceId>
```

Compila le dipendenze native, installa l'esempio Flutter e apre logcat pronto per i test NFC.

---

## API Flutter

### Classe principale: `CieSignFlutter`

```dart
final cieSign = CieSignFlutter();

// Firma mock (senza NFC)
Uint8List signedPdf = await cieSign.mockSignPdf(
  pdfBytes,
  appearance: PdfSignatureAppearance(
    page: 1,
    x: 100, y: 100,
    width: 200, height: 80,
  ),
);

// Firma con NFC
Uint8List signedPdf = await cieSign.signPdfWithNfc(
  pdfBytes,
  pin: "12345678",
  appearance: appearance,
);

// Verifica PIN
bool valid = await cieSign.verifyPinWithNfc("12345678");

// Stream eventi NFC
cieSign.watchNfcEvents().listen((event) {
  switch (event.type) {
    case NfcEventType.listening:
      print("Avvicina la carta...");
    case NfcEventType.tag:
      print("Carta rilevata");
    case NfcEventType.completed:
      print("Operazione completata");
    case NfcEventType.error:
      print("Errore: ${event.message}");
  }
});
```

---

## Stato & Prossimi Passi

| Stato | Dettagli |
|-------|----------|
| ✅ Core C/C++ modernizzato | PoDoFo 1.x, toolkit mock, CLI, API `cie_sign_verify_pin` |
| ✅ Plugin Flutter headless | Mock signing, firma NFC Android, verifica PIN + eventi NFC |
| ✅ Deploy iOS su device | App Flutter testata su iPhone fisico con mock signing funzionante |
| ✅ Script automazione | `build_ios_libs.sh`, `deploy_ios_device.sh`, `deploy_android_device.sh` |
| 🔄 Firma NFC iOS reale | CoreNFC bridge pronto, da testare con carta CIE fisica |
| 🔜 Automazione CI | Pipeline macOS per build host + test Flutter/Android |

---

## Contribuire

1. Installa gli strumenti necessari (Xcode, Android SDK+NDK r26, Flutter SDK, vcpkg)
2. Segui gli script in `cie_sign_sdk/scripts/` per compilare le dipendenze native (arm64 host/ios/android)
3. Verifica sempre i test pertinenti (`ctest`, `flutter test`, `gradlew connectedAndroidTest`) prima della PR
4. Non committare output generati (`Dependencies-*`, `.cxx`, `build/`, PDF firmati, ecc.)
5. Documenta le novita qui nel README quando impattano il flusso (nuove API, strumenti, requisiti)

Il contributo di ciascuno aiuta ad arrivare rapidamente all'integrazione completa, in particolare lato **CoreNFC iOS**: se hai accesso a dispositivi fisici o puoi lavorare sull'UX di avvicinamento carta, sei il benvenuto.

---

## Licenza

Vedi file LICENSE per i dettagli.
