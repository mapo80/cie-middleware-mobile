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
│   │       ├── pdf_signature_appearance.dart        # Config firma PDF
│   │       ├── pdf_signature_field_info.dart        # Info campi firma
│   │       └── signed_pdf_document.dart             # Documento firmato
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
- **Estrazione campi firma** da PDF esistenti (`extractSignatureFields`) per analizzare quali campi sono disponibili e quali sono già firmati
- **Widget firma a mano** (`CieHandSignature`) con supporto inline e fullscreen, configurazione completa e callback per l'immagine PNG
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

// Firma mock (senza NFC) - restituisce SignedPdfDocument
SignedPdfDocument signedDoc = await cieSign.mockSignPdf(
  pdfBytes,
  appearance: PdfSignatureAppearance(
    left: 0.20,      // 20% dalla sinistra
    bottom: 0.65,    // 65% dal basso
    width: 0.50,     // 50% larghezza pagina
    height: 0.20,    // 20% altezza pagina
  ),
);

// Firma con NFC - restituisce SignedPdfDocument
SignedPdfDocument signedDoc = await cieSign.signPdfWithNfc(
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

### Classe `SignedPdfDocument`

I metodi `mockSignPdf` e `signPdfWithNfc` restituiscono un `SignedPdfDocument` invece di `Uint8List`.
Questa classe wrapper fornisce metodi helper per gestire il documento firmato:

```dart
class SignedPdfDocument {
  final Uint8List bytes;        // I byte grezzi del PDF firmato
  final DateTime signedAt;      // Timestamp della firma

  int get sizeInBytes;          // Dimensione in byte
  String get formattedSize;     // "1.5 MB", "512 KB", etc.
  bool get isValid;             // true se contiene dati validi
  bool get hasPdfHeader;        // true se inizia con %PDF-

  Future<File> saveToFile(String path);
  Future<File> saveToDirectory(String dir, {String? filename});
}
```

**Esempio di utilizzo:**

```dart
// Firma il documento
SignedPdfDocument signedDoc = await cieSign.signPdfWithNfc(
  pdfBytes,
  pin: pin,
  appearance: appearance,
);

// Ispeziona il risultato
print('Dimensione: ${signedDoc.formattedSize}');  // "1.5 MB"
print('Valido: ${signedDoc.isValid}');            // true
print('Firmato: ${signedDoc.signedAt}');          // 2024-01-15 10:30:00

// Salva su file
await signedDoc.saveToFile('/path/to/contratto_firmato.pdf');

// Oppure salva in una directory con nome auto-generato
await signedDoc.saveToDirectory('/documenti');
// Crea: /documenti/signed_1705312200000.pdf

// Accedi ai bytes grezzi se necessario
Uint8List rawBytes = signedDoc.bytes;
```

### Estrazione Campi Firma

Prima di firmare, puoi analizzare il PDF per estrarre l'elenco dei campi firma disponibili:

```dart
final cieSign = CieSignFlutter();

// Estrai i campi firma dal PDF
List<PdfSignatureFieldInfo> fields = await cieSign.extractSignatureFields(pdfBytes);

for (final field in fields) {
  print('Campo: ${field.name}');
  print('  Pagina: ${field.pageIndex}');
  print('  Posizione: (${field.left}, ${field.bottom})');
  print('  Dimensioni: ${field.width} x ${field.height}');
  print('  Firmato: ${field.isSigned}');
}

// Firma solo i campi selezionati (es. quelli non firmati)
final selectedFieldIds = fields
    .where((f) => !f.isSigned)
    .map((f) => f.name)
    .toList();

final signedDoc = await cieSign.signPdfWithNfc(
  pdfBytes,
  pin: pin,
  appearance: PdfSignatureAppearance(
    fieldIds: selectedFieldIds,
    signatureImageBytes: signatureImage,
  ),
);
```

### Classe `PdfSignatureFieldInfo`

Rappresenta le informazioni su un campo firma estratto dal PDF.

```dart
class PdfSignatureFieldInfo {
  final String name;       // Nome univoco del campo (es. "SignatureField1")
  final int pageIndex;     // Indice della pagina (0-based)
  final double left;       // Coordinata X in punti PDF
  final double bottom;     // Coordinata Y in punti PDF
  final double width;      // Larghezza in punti PDF
  final double height;     // Altezza in punti PDF
  final bool isSigned;     // true se il campo contiene già una firma
}
```

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `name` | `String` | Nome univoco del campo (es. "SignatureField1") |
| `pageIndex` | `int` | Indice della pagina (0-based) |
| `left` | `double` | Coordinata X in punti PDF |
| `bottom` | `double` | Coordinata Y in punti PDF |
| `width` | `double` | Larghezza in punti PDF |
| `height` | `double` | Altezza in punti PDF |
| `isSigned` | `bool` | `true` se il campo contiene già una firma |

**Metodi disponibili:**

```dart
// Crea da mappa (usato internamente dal MethodChannel)
final field = PdfSignatureFieldInfo.fromMap(map);

// Converte in mappa
final map = field.toMap();

// Supporta equality e hashCode
field1 == field2;
```

**Esempio di flusso completo:**

```dart
// 1. Carica il PDF
final pdfBytes = await File('documento.pdf').readAsBytes();

// 2. Estrai i campi firma
final fields = await cieSign.extractSignatureFields(pdfBytes);

// 3. Mostra all'utente quali campi sono disponibili
for (final field in fields) {
  print('${field.name}: ${field.isSigned ? "già firmato" : "da firmare"}');
}

// 4. L'utente seleziona i campi da firmare
final selectedFields = fields.where((f) => !f.isSigned).toList();

// 5. Se non ci sono campi, la firma andrà in basso a destra dell'ultima pagina
final appearance = selectedFields.isEmpty
    ? PdfSignatureAppearance(
        left: 0.55,
        bottom: 0.05,
        width: 0.40,
        height: 0.10,
      )
    : PdfSignatureAppearance(
        fieldIds: selectedFields.map((f) => f.name).toList(),
      );

// 6. Firma il documento
final signedDoc = await cieSign.signPdfWithNfc(
  pdfBytes,
  pin: userPin,
  appearance: appearance,
);

// 7. Salva il risultato
await signedDoc.saveToFile('documento_firmato.pdf');
```

---

## Widget Firma a Mano

L'SDK include un widget Flutter per la visualizzazione e cattura di firme manoscritte.

### Modalità Sola Lettura (default)

Per default il widget mostra la firma in sola lettura. L'utente deve aprire la modalità fullscreen per modificarla:

```dart
import 'package:cie_sign_flutter/cie_sign_flutter.dart';

Uint8List? _signatureBytes;

CieHandSignature(
  signatureImage: _signatureBytes,  // Immagine corrente (o null)
  readOnly: true,                   // Solo visualizzazione (default)
  onSignatureSaved: (bytes) {
    setState(() => _signatureBytes = bytes);
  },
)
```

L'utente vede l'immagine (o un placeholder). Toccando il widget o il pulsante fullscreen può modificare la firma. Le modifiche sono applicate **solo al salvataggio**.

### Modalità Disegno Diretto

Per permettere il disegno diretto sul widget senza aprire fullscreen:

```dart
CieHandSignature(
  readOnly: false,  // Permette disegno diretto
  onSignatureSaved: (bytes) => saveSignature(bytes),
  onSignatureCleared: () => clearSignature(),
)
```

### Configurazione Pulsanti

```dart
CieHandSignature(
  signatureImage: _signatureBytes,
  readOnly: true,

  // Testi pulsanti (solo se readOnly=false)
  clearButtonText: 'Cancella',
  saveButtonText: 'Conferma',

  // Pulsante fullscreen
  showFullscreenButton: true,
  fullscreenTooltip: 'Modifica a tutto schermo',

  // Configurazione dialog fullscreen
  fullscreenOrientation: SignatureOrientation.landscape,
  fullscreenTitle: 'Firma documento',
  fullscreenSaveText: 'Salva',
  fullscreenCancelText: 'Annulla',

  // Placeholder personalizzato (quando non c'è firma)
  emptyPlaceholder: Text('Nessuna firma'),
)
```

### Flusso Fullscreen

1. L'utente tocca il pulsante fullscreen (o il widget in readOnly mode)
2. Si apre l'editor con la firma esistente (se presente)
3. L'utente può disegnare o cancellare
4. **Salva**: modifiche applicate, callback `onSignatureSaved` chiamata
5. **Annulla**: modifiche scartate, firma originale preservata

```dart
// Aprire fullscreen programmaticamente
final bytes = await CieHandSignature.openFullscreen(
  context,
  initialImage: _currentSignature,  // Immagine esistente da modificare
  orientation: SignatureOrientation.landscape,
);

if (bytes != null && bytes.isNotEmpty) {
  // Utente ha salvato una nuova firma
  setState(() => _signatureBytes = bytes);
} else if (bytes != null && bytes.isEmpty) {
  // Utente ha cancellato la firma e salvato
  setState(() => _signatureBytes = null);
}
// Se bytes == null, utente ha annullato
```

### Configurazione Aspetto

Personalizza l'aspetto del widget tramite `CieHandSignatureConfig`:

```dart
CieHandSignature(
  config: CieHandSignatureConfig(
    strokeColor: Colors.blue,
    backgroundColor: Colors.grey.shade100,
    minStrokeWidth: 1.5,
    maxStrokeWidth: 5.0,
    outputWidth: 800,
    outputHeight: 300,
    threshold: 2.5,
    smoothRatio: 0.7,
  ),
  aspectRatio: 4.0,
  borderRadius: BorderRadius.circular(12),
  onSignatureSaved: (bytes) => handleSignature(bytes),
)
```

### Integrazione con Firma PDF

```dart
final cieSign = CieSignFlutter();

// 1. Cattura la firma con il widget fullscreen
final signatureBytes = await CieHandSignature.openFullscreen(
  context,
  orientation: SignatureOrientation.landscape,
);

if (signatureBytes != null && signatureBytes.isNotEmpty) {
  // 2. Firma il PDF con la firma catturata
  final signedDoc = await cieSign.signPdfWithNfc(
    pdfBytes,
    pin: pin,
    appearance: PdfSignatureAppearance(
      fieldIds: ['SignatureField1'],
      reason: 'Approvazione',
      signatureImageBytes: signatureBytes,
    ),
  );

  // 3. Salva il documento firmato
  await signedDoc.saveToFile('documento_firmato.pdf');
}
```

### Riferimento Parametri Widget

| Parametro | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `signatureImage` | `Uint8List?` | `null` | Immagine firma corrente |
| `readOnly` | `bool` | `true` | Se true, solo visualizzazione |
| `showButtons` | `bool` | `true` | Mostra barra pulsanti |
| `showFullscreenButton` | `bool` | `true` | Mostra pulsante fullscreen |
| `clearButtonText` | `String` | `'Pulisci'` | Testo pulsante pulisci |
| `saveButtonText` | `String` | `'Salva'` | Testo pulsante salva |
| `fullscreenOrientation` | `SignatureOrientation` | `auto` | Orientamento fullscreen |
| `fullscreenTitle` | `String` | `'Firma qui'` | Titolo dialog fullscreen |
| `emptyPlaceholder` | `Widget?` | icona+testo | Widget quando firma vuota |

### Riferimento Configurazione

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `strokeColor` | `Color` | `Colors.black` | Colore del tratto |
| `backgroundColor` | `Color` | `Color(0xFFF5F5F5)` | Colore di sfondo |
| `minStrokeWidth` | `double` | `2.0` | Larghezza minima del tratto |
| `maxStrokeWidth` | `double` | `6.0` | Larghezza massima del tratto |
| `outputWidth` | `int` | `600` | Larghezza PNG in output |
| `outputHeight` | `int` | `200` | Altezza PNG in output |
| `threshold` | `double` | `3.0` | Soglia di movimento minimo |
| `smoothRatio` | `double` | `0.65` | Ratio di smoothing curve |
| `velocityRange` | `double` | `2.0` | Range sensibilità velocità |
| `transparentBackground` | `bool` | `true` | Sfondo trasparente nel PNG |

---

## Posizionamento Firma PDF

L'SDK supporta due modalità per posizionare la firma visiva nel documento PDF.

### Modalità 1: Firma su campi esistenti (consigliata)

Se il PDF contiene già campi firma predefiniti, specificare i nomi dei campi tramite `fieldIds`:

```dart
final appearance = PdfSignatureAppearance(
  fieldIds: ['SignatureField1', 'SignatureField2'],  // Firma questi campi nell'ordine
  signatureImageBytes: signatureImage,               // Immagine PNG/JPEG della firma
  reason: 'Approvazione documento',
  location: 'Roma, Italia',
  name: 'Mario Rossi',
);
```

**Comportamento**:
- La firma viene apposta **solo** sui campi specificati, nell'ordine indicato
- La posizione e dimensione sono quelle definite nel PDF originale
- Se un campo non esiste o è già firmato, viene restituito un errore

### Modalità 2: Creazione nuovo campo firma

Se `fieldIds` non è specificato o è vuoto, l'SDK crea un nuovo campo firma:

```dart
final appearance = PdfSignatureAppearance(
  // Coordinate frazionali (0-1) rispetto alla pagina
  pageIndex: 0,      // Pagina (0 = prima, default: ultima se non specificato)
  left: 0.20,        // 20% dalla sinistra
  bottom: 0.10,      // 10% dal basso (vicino al margine inferiore)
  width: 0.50,       // 50% della larghezza pagina
  height: 0.15,      // 15% dell'altezza pagina
  signatureImageBytes: signatureImage,
  reason: 'Firma con CIE',
);
```

**Comportamento**:
- Se esistono campi firma vuoti nel PDF: vengono firmati automaticamente (solo Android)
- Se non esistono campi firma: viene creato un nuovo campo sulla **ultima pagina** (fallback)
- Se `pageIndex > 0`: viene usata la pagina specificata

### Sistema di Coordinate

Le coordinate usano il sistema **frazionale** (valori da 0 a 1):

```
                    Pagina PDF (612 x 792 pt)
    ┌─────────────────────────────────────────────┐
    │                                             │  top = 1.0
    │                                             │
    │    ┌─────────────────────────┐              │
    │    │                         │              │
    │    │    CAMPO FIRMA          │              │  bottom = 0.65
    │    │    (left=0.20, w=0.50)  │              │  (65% dal basso)
    │    │                         │              │
    │    └─────────────────────────┘              │
    │         height = 0.20                       │
    │                                             │
    │                                             │
    └─────────────────────────────────────────────┘
   left=0                                    right=1.0
        └─ left=0.20 (20% dalla sinistra)
```

| Parametro | Tipo | Descrizione | Esempio |
|-----------|------|-------------|---------|
| `pageIndex` | `int` | Indice pagina (0-based). Se 0 e nessun fieldIds, usa ultima pagina | `0` |
| `left` | `double` | Posizione X come frazione (0-1) della larghezza pagina | `0.20` = 20% |
| `bottom` | `double` | Posizione Y come frazione (0-1) dell'altezza pagina (dal basso) | `0.10` = 10% |
| `width` | `double` | Larghezza come frazione (0-1) della larghezza pagina | `0.50` = 50% |
| `height` | `double` | Altezza come frazione (0-1) dell'altezza pagina | `0.15` = 15% |

### Conversione a Punti PDF

L'SDK converte automaticamente le coordinate frazionali in punti PDF:

```
Per una pagina Letter (612 x 792 pt):
  left   = 0.20 × 612 = 122.4 pt
  bottom = 0.10 × 792 =  79.2 pt
  width  = 0.50 × 612 = 306.0 pt
  height = 0.15 × 792 = 118.8 pt
```

### Parametri `PdfSignatureAppearance`

```dart
class PdfSignatureAppearance {
  final int pageIndex;              // Pagina target (0 = prima, -1 o omesso = ultima)
  final double left;                // Coordinata X (0-1)
  final double bottom;              // Coordinata Y dal basso (0-1)
  final double width;               // Larghezza (0-1)
  final double height;              // Altezza (0-1)
  final String? reason;             // Motivo della firma
  final String? location;           // Luogo
  final String? name;               // Nome firmatario
  final List<String>? fieldIds;     // Nomi campi esistenti da firmare
  final Uint8List? signatureImageBytes;  // Immagine firma PNG/JPEG
}
```

### Logica di Selezione Pagina

```
┌─────────────────────────────────────────────────────────────┐
│                    INPUT                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │  fieldIds specificati?  │
              └─────────────────────────┘
                     │           │
                    YES         NO
                     │           │
                     ▼           ▼
          ┌──────────────┐  ┌────────────────────┐
          │ Firma SOLO   │  │ Esistono campi     │
          │ quei campi   │  │ firma vuoti?       │
          │ (posizione   │  └────────────────────┘
          │ dal PDF)     │       │           │
          └──────────────┘      YES         NO
                                 │           │
                                 ▼           ▼
                      ┌──────────────┐  ┌──────────────────┐
                      │ Firma campi  │  │ pageIndex > 0?   │
                      │ esistenti    │  └──────────────────┘
                      │ (Android)    │       │           │
                      └──────────────┘      YES         NO
                                             │           │
                                             ▼           ▼
                                  ┌──────────────┐  ┌──────────────┐
                                  │ Crea campo   │  │ Crea campo   │
                                  │ su pagina    │  │ su ULTIMA    │
                                  │ specificata  │  │ PAGINA       │
                                  └──────────────┘  └──────────────┘
```

### Esempi Completi

#### Firma su campo esistente
```dart
// Il PDF ha un campo "Firma_Direttore" predefinito
final appearance = PdfSignatureAppearance(
  fieldIds: ['Firma_Direttore'],
  signatureImageBytes: await loadSignatureImage(),
  reason: 'Approvazione definitiva',
  name: 'Dott. Mario Rossi',
);

final signedPdf = await cieSign.signPdfWithNfc(pdfBytes, pin: pin, appearance: appearance);
```

#### Firma in basso a destra dell'ultima pagina
```dart
final appearance = PdfSignatureAppearance(
  // Nessun fieldIds → crea nuovo campo sull'ultima pagina
  left: 0.55,       // 55% dalla sinistra (verso destra)
  bottom: 0.05,     // 5% dal basso (vicino al margine)
  width: 0.40,      // 40% larghezza
  height: 0.10,     // 10% altezza
  signatureImageBytes: signatureImage,
  reason: 'Firma digitale',
  location: 'Milano',
);
```

#### Firma al centro della prima pagina
```dart
final appearance = PdfSignatureAppearance(
  pageIndex: 0,     // Prima pagina (esplicito)
  left: 0.25,       // Centrato orizzontalmente
  bottom: 0.40,     // Centrato verticalmente
  width: 0.50,
  height: 0.20,
  signatureImageBytes: signatureImage,
);
```

### API C++ Sottostante

Per riferimento, la struttura C++ che riceve i parametri:

```c
typedef struct {
    const char *reason;
    const char *location;
    const char *name;
    const uint8_t *signature_image;
    size_t signature_image_len;
    uint32_t signature_image_width;   // 0 per PNG/JPEG (auto-detect)
    uint32_t signature_image_height;  // 0 per PNG/JPEG (auto-detect)
    uint32_t page_index;
    float left;                       // Coordinata frazionale 0-1
    float bottom;                     // Coordinata frazionale 0-1
    float width;                      // Coordinata frazionale 0-1
    float height;                     // Coordinata frazionale 0-1
    const char *const *field_ids;     // Array di nomi campi
    size_t field_ids_len;
} cie_pdf_options;
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
