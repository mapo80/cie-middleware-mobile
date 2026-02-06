# CIE Mobile Signing SDK

Modernizzazione completa dello stack di firma per **Carta d'Identità Elettronica (CIE)** italiana con obiettivo di offrire:

- un **core nativo comune** (C/C++) che gestisce APDU IAS, firme PKCS#7/PDF/XML e validazioni;
- **SDK nativi standalone** (Kotlin per Android, Objective-C per iOS) utilizzabili direttamente da app native;
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
│  Flutter Android   │   │  Flutter iOS       │
│  Bridge (Kotlin)   │   │  Bridge (ObjC)     │
└────────┬───────────┘   └────────┬───────────┘
         │ include                │ include
┌────────▼───────────┐   ┌───────▼────────────┐
│cie_sign_android_sdk│   │  cie_sign_ios_sdk   │
│  (Kotlin + JNI)    │   │  (ObjC++ + CoreNFC) │
└────────┬───────────┘   └────────┬───────────┘
         │ JNI                    │ Native call
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
| **Android SDK** | Kotlin + JNI + CMake | Kotlin + C++ | SDK standalone nativo |
| **iOS SDK** | CoreNFC + ObjC++ | Objective-C/C++ | SDK standalone nativo |
| **Flutter Plugin** | Flutter SDK 3.3+ | Dart + platform bridge | Plugin headless multipiattaforma |
| **Build** | CMake 3.15+ | CMake | Cross-compilation multipiattaforma |
| **Dipendenze** | vcpkg | - | OpenSSL, libcurl, libxml2, zlib, freetype, libpng, PoDoFo |

### Versioni Tools Richieste

- CMake 3.15+
- Gradle 9.2
- Kotlin 2.2+
- Android Gradle Plugin 8.6+
- Android NDK r26 (26.2.11394342)
- Xcode 15+ (per iOS)
- Flutter SDK 3.3+ (Dart 3.10+)
- Java 17

---

## Struttura del Repository

```
cie-middleware-linux/
│
├── cie_sign_sdk/                          # Core C/C++ della libreria di firma
│   ├── src/                               # Codice sorgente (~160 file)
│   │   ├── ASN1/                          # Parsing/generazione strutture ASN.1
│   │   ├── Crypto/                        # Algoritmi crittografici (AES, DES3, SHA*, MD5, MAC)
│   │   ├── PCSC/                          # Protocollo smart card (APDU, Token)
│   │   ├── CSP/                           # IAS e gestione ATR
│   │   ├── RSA/                           # Implementazione RSA
│   │   ├── Util/                          # Logging, TLV, utilities
│   │   ├── mobile/                        # Bridge mobile (cie_sign_core.cpp)
│   │   ├── fonts/                         # Font embedded per firma auto-generata
│   │   ├── PdfSignatureGenerator.cpp      # Generatore firme PDF
│   │   ├── PdfVerifier.cpp                # Verifica firme PDF
│   │   ├── TextSignatureGenerator.cpp     # Generatore firma testuale automatica
│   │   └── SignatureGenerator.cpp         # PKCS#7 / CMS generator
│   ├── include/
│   │   ├── mobile/                        # API pubblica C (cie_sign.h, cie_platform.h)
│   │   ├── PdfSignatureGenerator.h
│   │   ├── TextSignatureGenerator.h
│   │   └── disigonsdk.h
│   ├── tests/
│   │   ├── mock/                          # Mock transport e APDU sequence
│   │   ├── ios/                           # Bridge test iOS (mock_sign_ios.mm)
│   │   ├── tools/                         # CLI (pdf_signature_check.cpp)
│   │   ├── dart_host/                     # Bridge Dart host per test desktop
│   │   ├── podofo_ios_test/               # Test PoDoFo su iOS
│   │   ├── auto_signature_test.cpp        # Test firma automatica
│   │   └── text_signature_generator_test.cpp
│   ├── data/fixtures/                     # PDF e certificati di test
│   ├── cmake/toolchains/                  # Toolchain cross-compilation
│   │   ├── ios-arm64.cmake                #   iOS device
│   │   ├── ios-sim-arm64.cmake            #   iOS simulator (Apple Silicon)
│   │   └── android-arm64.cmake            #   Android arm64-v8a
│   ├── scripts/                           # Script build SDK
│   │   ├── bootstrap_vcpkg.sh             # Inizializza vcpkg
│   │   ├── build_dependencies.sh          # Compila dipendenze via vcpkg
│   │   ├── build_host.sh                  # Build desktop (macOS/Linux)
│   │   ├── build_ios.sh                   # Build iOS
│   │   ├── build_ios_sdk.sh               # Pipeline completa iOS
│   │   ├── build_ios_dependencies.sh      # Dipendenze iOS via vcpkg
│   │   ├── build_android.sh               # Build Android
│   │   ├── build_android_dependencies.sh  # Dipendenze Android via vcpkg
│   │   ├── package_ios_unified.sh         # Packaging xcframework
│   │   └── ios/                           # Script individuali per dipendenze iOS
│   │       ├── build_ios_openssl.sh
│   │       ├── build_ios_podofo.sh
│   │       └── ... (altri)
│   ├── docs/                              # Documentazione tecnica
│   │   ├── mobile_architecture.md         # Architettura SDK mobile
│   │   ├── build_mobile.md                # Guida build completa
│   │   ├── core_isolation.md              # Isolamento core C++
│   │   ├── nfc_integration_plan.md        # Piano integrazione NFC
│   │   ├── tests_ios.md                   # Guida test iOS
│   │   └── tests_android.md              # Guida test Android
│   ├── .gitignore                         # Ignora Dependencies*/ e build/
│   └── CMakeLists.txt                     # Build configuration
│
├── cie_sign_android_sdk/                  # SDK Android nativo standalone
│   ├── build.gradle                       # Configurazione Gradle (Android Library)
│   ├── consumer-rules.pro                 # Regole ProGuard per consumatori
│   ├── .gitignore                         # Ignora .cxx/ e build/
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/it/ipzs/ciesign/sdk/
│       │   ├── CieSignSdk.kt             # API pubblica Kotlin
│       │   ├── NativeBridge.kt            # Bridge JNI → C++
│       │   └── PdfAppearanceOptions.kt    # Configurazione firma
│       └── cpp/
│           ├── CMakeLists.txt             # Build nativo (shared lib ciesign_mobile)
│           ├── mock_sign_android.cpp      # Implementazione mock signing
│           └── nfc_sign_android.cpp       # Implementazione NFC signing
│
├── cie_sign_ios_sdk/                      # SDK iOS nativo standalone
│   ├── Bridge/                            # Wrapper Objective-C++ del core C++
│   │   ├── CieSignMobileBridge.h          # API pubblica ObjC
│   │   ├── CieSignMobileBridge.mm         # Implementazione bridge
│   │   ├── CieNfcSession.h                # Wrapper CoreNFC
│   │   └── CieNfcSession.mm              # Implementazione sessione NFC
│   └── Mock/                              # Mock APDU transport per test
│       ├── mock_transport.h
│       ├── mock_transport.cpp
│       ├── mock_apdu_sequence.h
│       └── mock_apdu_sequence.cpp
│
├── cie_sign_flutter/                      # Plugin Flutter (solo bridge)
│   ├── lib/
│   │   ├── cie_sign_flutter.dart          # API pubblica Dart (export)
│   │   ├── cie_sign_flutter_method_channel.dart
│   │   ├── cie_sign_flutter_platform_interface.dart
│   │   └── src/
│   │       ├── nfc_session_event.dart      # Eventi NFC
│   │       ├── pdf_signature_appearance.dart
│   │       ├── pdf_signature_field_info.dart
│   │       ├── signed_pdf_document.dart
│   │       └── widgets/                   # Widget firma a mano
│   │           ├── cie_hand_signature.dart
│   │           ├── cie_hand_signature_controller.dart
│   │           └── cie_hand_signature_config.dart
│   ├── android/                           # Bridge Flutter → Android SDK
│   │   ├── build.gradle                   # Include sorgenti da ../../cie_sign_android_sdk/
│   │   └── src/main/kotlin/.../
│   │       └── CieSignFlutterPlugin.kt    # Handler MethodChannel Android
│   ├── ios/                               # Bridge Flutter → iOS SDK
│   │   ├── cie_sign_flutter.podspec       # Include sorgenti da ../../cie_sign_ios_sdk/
│   │   └── Classes/
│   │       ├── CieSignFlutterPlugin.h
│   │       └── CieSignFlutterPlugin.m     # Handler MethodChannel iOS
│   ├── example/                           # App demo Flutter
│   │   ├── lib/main.dart                  # UI principale
│   │   ├── assets/                        # PDF e firme di test
│   │   ├── android/                       # Build config Android
│   │   └── ios/                           # Build config iOS
│   ├── test/                              # Unit/widget test
│   └── pubspec.yaml
│
├── example-native-apps/                   # App native di test (senza Flutter)
│   ├── android/                           # Progetto Gradle Android
│   │   ├── settings.gradle                # Include ../../cie_sign_android_sdk
│   │   ├── build.gradle                   # Root config
│   │   ├── gradle/                        # Wrapper Gradle
│   │   └── CieSignMockApp/               # App di test mock signing
│   │       ├── build.gradle
│   │       └── src/
│   │           ├── main/java/.../MainActivity.kt
│   │           └── androidTest/.../MockSignInstrumentedTest.kt
│   └── ios/                               # Progetto Xcode iOS
│       ├── CieSignIosHost/                # App host SwiftUI
│       │   ├── CieSignIosHostApp.swift
│       │   ├── ContentView.swift
│       │   ├── SigningViewModel.swift
│       │   └── CieSignIosHost-Bridging-Header.h  # Import da ../../cie_sign_ios_sdk/
│       ├── CieSignIosTests/               # XCTest suite
│       │   ├── MockSignTests.swift
│       │   └── CieSignBridgeTests.swift
│       └── CieSignIosTests.xcodeproj/
│
├── scripts/                               # Script automazione deploy
│   ├── build_ios_libs.sh                  # Compila librerie native iOS
│   ├── deploy_ios_device.sh               # Build Flutter + deploy su iPhone
│   ├── deploy_android_device.sh           # Build Flutter + deploy su Android
│   └── generate_sample_pdf.py             # Genera PDF di test
│
└── README.md
```

### Mappa delle Directory

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              REPOSITORY ROOT                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        cie_sign_sdk/                                 │    │
│  │  CORE C/C++ - Motore di firma digitale                              │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │  src/                                                                │    │
│  │  ├── ASN1/          → Parser strutture ASN.1 per certificati       │    │
│  │  ├── Crypto/        → AES, DES3, SHA*, MD5, MAC                    │    │
│  │  ├── RSA/           → Firma RSA e gestione chiavi                  │    │
│  │  ├── CSP/           → Comunicazione IAS con smart card CIE         │    │
│  │  ├── PCSC/          → Protocollo PC/SC per lettori NFC             │    │
│  │  ├── Util/          → Logging, TLV, utilities                      │    │
│  │  ├── mobile/        → Bridge mobile (cie_sign_core.cpp)            │    │
│  │  ├── PdfSignatureGenerator.cpp  → Genera firme PDF con PoDoFo      │    │
│  │  ├── PdfVerifier.cpp            → Verifica firme esistenti         │    │
│  │  ├── TextSignatureGenerator.cpp → Firma testuale auto-generata     │    │
│  │  └── SignatureGenerator.cpp     → PKCS#7 / CMS                     │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │  include/mobile/    → Header pubblici (cie_sign.h)                  │    │
│  │  tests/             → Mock signer, CLI tool, test iOS               │    │
│  │  scripts/           → Build e dipendenze (vcpkg, CMake)             │    │
│  │  cmake/toolchains/  → Cross-compilation iOS/Android                 │    │
│  │  docs/              → Documentazione architettura e build           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                      │                                       │
│                    ┌─────────────────┼─────────────────┐                    │
│                    │                 │                 │                      │
│                    ▼                 ▼                 ▼                      │
│  ┌──────────────────────┐ ┌──────────────────┐ ┌──────────────────────┐    │
│  │cie_sign_android_sdk/ │ │cie_sign_ios_sdk/ │ │  cie_sign_flutter/   │    │
│  │ SDK Android nativo   │ │ SDK iOS nativo   │ │  Plugin Flutter      │    │
│  ├──────────────────────┤ ├──────────────────┤ ├──────────────────────┤    │
│  │ Kotlin + JNI + CMake │ │ ObjC++ + CoreNFC │ │ Dart + bridge nativi │    │
│  │ CieSignSdk.kt        │ │ CieSignMobile-   │ │ CieSignFlutter-      │    │
│  │ NativeBridge.kt      │ │   Bridge.mm      │ │   Plugin.kt/.m       │    │
│  │ mock_sign_android.cpp│ │ CieNfcSession.mm │ │ example/ (app demo)  │    │
│  │ nfc_sign_android.cpp │ │ Mock transport   │ │ test/ (unit test)    │    │
│  └──────────────────────┘ └──────────────────┘ └──────────────────────┘    │
│                    │                 │                                        │
│                    ▼                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      example-native-apps/                            │   │
│  │  App di test nativi (senza Flutter)                                  │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  android/                          │  ios/                           │   │
│  │  ├── CieSignMockApp/               │  ├── CieSignIosHost/ (SwiftUI) │   │
│  │  │   └── MockSignInstrumentedTest  │  ├── CieSignIosTests/ (XCTest) │   │
│  │  └── settings.gradle               │  └── CieSignIosTests.xcodeproj │   │
│  │      (→ cie_sign_android_sdk)      │      (→ cie_sign_ios_sdk)      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                           scripts/                                   │   │
│  │  AUTOMAZIONE - Script per build e deploy                             │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  build_ios_libs.sh          → Compila ciesign_core per iOS arm64    │   │
│  │  deploy_ios_device.sh       → Build Flutter + deploy su iPhone      │   │
│  │  deploy_android_device.sh   → Build Flutter + deploy su Android     │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Descrizione Moduli

| Directory | Tipo | Contenuto | Output |
|-----------|------|-----------|--------|
| `cie_sign_sdk/` | C/C++ | Core firma digitale | `libcie_sign_sdk.a`, `libciesign_core.a` |
| `cie_sign_android_sdk/` | Kotlin + JNI | SDK Android standalone | `libciesign_mobile.so` (shared lib) |
| `cie_sign_ios_sdk/` | Objective-C++ | SDK iOS standalone | Compilato nel pod Flutter o nel progetto Xcode |
| `cie_sign_flutter/` | Dart | Plugin Flutter (bridge) | Package `cie_sign_flutter` |
| `cie_sign_flutter/example/` | Flutter | App demo | APK / IPA |
| `example-native-apps/android/` | Kotlin | App test Android nativa | APK (mock signing test) |
| `example-native-apps/ios/` | Swift | App test iOS nativa | App + XCTest bundle |
| `scripts/` | Bash | Automazione deploy | - |

### Dipendenze tra Moduli

```
┌──────────────────┐                    ┌──────────────────┐
│ Flutter App      │  (example/)        │ Native Test Apps │  (example-native-apps/)
└──────┬───────────┘                    └──────┬───────────┘
       │ dipende da                            │ dipende da
       ▼                                       │
┌──────────────────┐                           │
│ Flutter Plugin   │  (cie_sign_flutter/)       │
└──────┬───────────┘                           │
       │ include sorgenti da                   │
       ├─────────────────┐                     │
       ▼                 ▼                     │
┌──────────────────┐  ┌──────────────────┐     │
│ Android SDK      │  │   iOS SDK        │◄────┘
│  (Kotlin + JNI)  │  │  (ObjC++ bridge) │
└──────┬───────────┘  └──────┬───────────┘
       │ JNI                 │ native
       └────────┬────────────┘
                │ link statico
                ▼
       ┌──────────────────┐
       │  ciesign_core    │  (C++ mobile wrapper)
       └──────┬───────────┘
              │
              ▼
       ┌──────────────────┐
       │  cie_sign_sdk    │  (C/C++ core)
       └──────┬───────────┘
              │
              ▼
       ┌──────────────────┐
       │    Vendors        │  (vcpkg: OpenSSL, PoDoFo, Crypto++, libxml2...)
       └──────────────────┘
```

**Come il plugin Flutter include gli SDK nativi:**

- **Android**: `cie_sign_flutter/android/build.gradle` referenzia i sorgenti Kotlin e il CMakeLists.txt da `../../cie_sign_android_sdk/`
- **iOS**: `cie_sign_flutter/ios/cie_sign_flutter.podspec` include i sorgenti ObjC++ da `../../cie_sign_ios_sdk/`
- **App native**: `example-native-apps/android/settings.gradle` punta a `../../cie_sign_android_sdk`; il progetto Xcode iOS referenzia `../../cie_sign_ios_sdk/Bridge/`

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
| **Text Signature** | C++ | Firma testuale auto-generata | `TextSignatureGenerator.cpp` |
| **Android SDK** | Kotlin | API nativa Android + JNI | `CieSignSdk.kt`, `NativeBridge.kt` |
| **iOS SDK** | ObjC++ | API nativa iOS + CoreNFC | `CieSignMobileBridge.mm`, `CieNfcSession.mm` |
| **Flutter Plugin** | Dart | Interfaccia pubblica | `cie_sign_flutter.dart` |
| **CLI Tool** | C++ | Verifica PDF offline | `tests/tools/pdf_signature_check.cpp` |

---

## Dipendenze Esterne (Vendor)

Gestite tramite **vcpkg**. Le librerie compilate risiedono direttamente in `cie_sign_sdk/.vcpkg/installed/<triplet>/` e vengono referenziate da CMake senza copie intermedie.

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
| **Fontconfig** | Gestione font |
| **bzip2** | Compressione |
| **Brotli** | Compressione |
| **libjpeg-turbo** | Immagini JPEG |
| **libtiff** | Immagini TIFF |
| **liblzma** | Compressione LZMA |
| **utf8proc** | Elaborazione UTF-8 |
| **expat** | Parsing XML |
| **date-tz** | Date e timezone |
| **fmt** | Formattazione stringa |

### Compilazione Dipendenze

```bash
# Inizializzazione vcpkg (una tantum)
cd cie_sign_sdk
./scripts/bootstrap_vcpkg.sh

# Build dipendenze per host (macOS/Linux)
./scripts/build_dependencies.sh

# Build dipendenze per iOS
./scripts/build_ios_dependencies.sh

# Build dipendenze per Android
./scripts/build_android_dependencies.sh
```

Le dipendenze vengono installate in `cie_sign_sdk/.vcpkg/installed/<triplet>/` con i seguenti triplet:

| Triplet | Piattaforma | Note |
|---------|-------------|------|
| `arm64-osx` | macOS host | Build e test desktop |
| `arm64-ios-17` | iOS device (arm64) | Include Crypto++ (preferito) |
| `arm64-ios` | iOS device (arm64) | Senza Crypto++ |
| `arm64-ios-simulator` | iOS simulator | |
| `arm64-android` | Android arm64-v8a | |

Lo script `build_ios_libs.sh` seleziona automaticamente il triplet piu completo disponibile (preferendo quelli con Crypto++).

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
              (via Gradle)   (via podspec)
```

---

## Funzionalita Implementate

- Firma PDF/PKCS#7 mock e via NFC reale (Android e iOS testati su device fisici)
- **Verifica PIN via NFC** esposta da Flutter/Android/iOS con UI dedicata nell'app di esempio
- **Estrazione campi firma** da PDF esistenti (`extractSignatureFields`) per analizzare quali campi sono disponibili e quali sono gia firmati
- **Firma testuale auto-generata** con `TextSignatureGenerator` che crea immagini firma dal nome del firmatario
- **Widget firma a mano** (`CieHandSignature`) con supporto inline e fullscreen, configurazione completa e callback per l'immagine PNG
- Gestione completa dell'apparenza grafica (firma disegnata, motivi, field IDs, posizionamento)
- Tool CLI `pdf_signature_check` per estrarre i CMS da un PDF e validare il certificato utilizzato
- Streaming eventi NFC (stato, ascolto, tag letto, completamento/cancellazione) consumabili dal front-end Flutter
- Suite di test:
  - `cie_sign_sdk` (C++) esercita sia il mock signer sia la firma auto-generata
  - `example-native-apps/android/CieSignMockApp` instrumentation test genera PDF firmati su emulatori
  - `example-native-apps/ios/CieSignIosTests` XCTest per mock signing e bridge
  - `cie_sign_flutter` unit/widget test coprono MethodChannel, eventi e UI mock NFC

---

## Build & Test

### Requisiti

| Tool | Versione Minima | Installazione |
|------|-----------------|---------------|
| CMake | 3.15+ | `brew install cmake` |
| Java | 17 | `brew install openjdk@17` |
| Android SDK | API 34 | Android Studio |
| Android NDK | r26 (26.2.11394342) | Android Studio SDK Manager |
| Flutter | 3.3+ | [flutter.dev](https://flutter.dev) |
| Xcode | 15+ | App Store |
| CocoaPods | latest | `sudo gem install cocoapods` |

### Comandi Principali

| Target | Comando | Note |
|--------|---------|------|
| **Core host** | `cd cie_sign_sdk && cmake -B build/host && cmake --build build/host && ctest --test-dir build/host --output-on-failure` | Produce librerie + `pdf_signature_check` |
| **Android native** | `cd example-native-apps/android && JAVA_HOME=<jdk17> ./gradlew :CieSignMockApp:connectedDebugAndroidTest` | Richiede emulator API34 |
| **iOS native** | `xcodebuild test -project example-native-apps/ios/CieSignIosTests.xcodeproj -scheme CieSignIosTests -destination 'platform=iOS Simulator,name=iPhone 15'` | Mock-only |
| **Flutter plugin** | `cd cie_sign_flutter && flutter test` | Unit/widget test |
| **Flutter integration** | `cd cie_sign_flutter/example && flutter test integration_test/` | Test integrazione |

---

## Deploy su Device Fisici

### iOS - Deploy su iPhone

#### Prerequisiti iOS

1. **Xcode** installato con command line tools
2. **Certificato sviluppatore** Apple configurato
3. **iPhone** connesso via USB e "trusted"
4. **Dipendenze native** compilate (vedi sezione Compilazione Dipendenze)

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
TRIPLET="arm64-ios-17"  # o arm64-ios se non serve Crypto++
cmake -B build/ios-arm64 \
  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ios-arm64.cmake \
  -DDEPENDENCIES_DIR="$(pwd)/.vcpkg/installed/$TRIPLET" \
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

### Script di deploy (`scripts/`)

| Script | Descrizione | Uso |
|--------|-------------|-----|
| `build_ios_libs.sh` | Compila librerie native iOS | `./scripts/build_ios_libs.sh [device\|simulator\|all]` |
| `deploy_ios_device.sh` | Build + deploy su iPhone | `./scripts/deploy_ios_device.sh [device_id] [--release]` |
| `deploy_android_device.sh` | Build + deploy su Android | `./scripts/deploy_android_device.sh [device_id] [--release]` |

### Script SDK (`cie_sign_sdk/scripts/`)

| Script | Descrizione |
|--------|-------------|
| `bootstrap_vcpkg.sh` | Inizializza vcpkg per la prima volta |
| `build_dependencies.sh` | Compila tutte le dipendenze via vcpkg (host) |
| `build_ios_dependencies.sh` | Compila dipendenze per iOS via vcpkg |
| `build_android_dependencies.sh` | Compila dipendenze per Android via vcpkg |
| `build_host.sh` | Build SDK per macOS/Linux |
| `build_ios.sh` | Build SDK per iOS |
| `build_ios_sdk.sh` | Pipeline completa build iOS |
| `build_android.sh` | Build SDK per Android |
| `package_ios_unified.sh` | Crea xcframework unificato |

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

### Estrazione Campi Firma

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

// Firma solo i campi non ancora firmati
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

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `name` | `String` | Nome univoco del campo (es. "SignatureField1") |
| `pageIndex` | `int` | Indice della pagina (0-based) |
| `left` | `double` | Coordinata X in punti PDF |
| `bottom` | `double` | Coordinata Y in punti PDF |
| `width` | `double` | Larghezza in punti PDF |
| `height` | `double` | Altezza in punti PDF |
| `isSigned` | `bool` | `true` se il campo contiene gia una firma |

---

## Widget Firma a Mano

L'SDK include un widget Flutter per la visualizzazione e cattura di firme manoscritte.

### Modalita Sola Lettura (default)

```dart
import 'package:cie_sign_flutter/cie_sign_flutter.dart';

Uint8List? _signatureBytes;

CieHandSignature(
  signatureImage: _signatureBytes,
  readOnly: true,
  onSignatureSaved: (bytes) {
    setState(() => _signatureBytes = bytes);
  },
)
```

### Modalita Disegno Diretto

```dart
CieHandSignature(
  readOnly: false,
  onSignatureSaved: (bytes) => saveSignature(bytes),
  onSignatureCleared: () => clearSignature(),
)
```

### Configurazione Pulsanti e Fullscreen

```dart
CieHandSignature(
  signatureImage: _signatureBytes,
  readOnly: true,
  showFullscreenButton: true,
  fullscreenOrientation: SignatureOrientation.landscape,
  fullscreenTitle: 'Firma documento',
  emptyPlaceholder: Text('Nessuna firma'),
  onSignatureSaved: (bytes) => handleSignature(bytes),
)
```

### Apertura Fullscreen Programmatica

```dart
final bytes = await CieHandSignature.openFullscreen(
  context,
  initialImage: _currentSignature,
  orientation: SignatureOrientation.landscape,
);

if (bytes != null && bytes.isNotEmpty) {
  setState(() => _signatureBytes = bytes);
}
```

### Configurazione Aspetto

```dart
CieHandSignature(
  config: CieHandSignatureConfig(
    strokeColor: Colors.blue,
    backgroundColor: Colors.grey.shade100,
    minStrokeWidth: 1.5,
    maxStrokeWidth: 5.0,
    outputWidth: 800,
    outputHeight: 300,
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

---

## Posizionamento Firma PDF

L'SDK supporta due modalita per posizionare la firma visiva nel documento PDF.

### Modalita 1: Firma su campi esistenti (consigliata)

Se il PDF contiene gia campi firma predefiniti, specificare i nomi dei campi tramite `fieldIds`:

```dart
final appearance = PdfSignatureAppearance(
  fieldIds: ['SignatureField1', 'SignatureField2'],
  signatureImageBytes: signatureImage,
  reason: 'Approvazione documento',
  location: 'Roma, Italia',
  name: 'Mario Rossi',
);
```

### Modalita 2: Creazione nuovo campo firma

Se `fieldIds` non e specificato o e vuoto, l'SDK crea un nuovo campo firma:

```dart
final appearance = PdfSignatureAppearance(
  pageIndex: 0,
  left: 0.20,
  bottom: 0.10,
  width: 0.50,
  height: 0.15,
  signatureImageBytes: signatureImage,
  reason: 'Firma con CIE',
);
```

### Sistema di Coordinate

Le coordinate usano il sistema **frazionale** (valori da 0 a 1):

```
                    Pagina PDF (612 x 792 pt)
    +-------------------------------------------------+
    |                                                 |  top = 1.0
    |                                                 |
    |    +-----------------------------+              |
    |    |                             |              |
    |    |    CAMPO FIRMA              |              |  bottom = 0.65
    |    |    (left=0.20, w=0.50)      |              |
    |    |                             |              |
    |    +-----------------------------+              |
    |         height = 0.20                           |
    |                                                 |
    +-------------------------------------------------+
   left=0                                        right=1.0
```

### Parametri `PdfSignatureAppearance`

| Parametro | Tipo | Descrizione |
|-----------|------|-------------|
| `pageIndex` | `int` | Pagina target (0 = prima, omesso = ultima) |
| `left` | `double` | Posizione X come frazione (0-1) |
| `bottom` | `double` | Posizione Y dal basso come frazione (0-1) |
| `width` | `double` | Larghezza come frazione (0-1) |
| `height` | `double` | Altezza come frazione (0-1) |
| `reason` | `String?` | Motivo della firma |
| `location` | `String?` | Luogo |
| `name` | `String?` | Nome firmatario |
| `fieldIds` | `List<String>?` | Nomi campi esistenti da firmare |
| `signatureImageBytes` | `Uint8List?` | Immagine firma PNG/JPEG |
| `useAutoSignature` | `bool` | Genera firma testuale automatica dal nome |
| `signerNameOverride` | `String?` | Override nome per firma auto-generata |

### API C++ Sottostante

Per riferimento, la struttura C++ che riceve i parametri:

```c
typedef struct {
    const char *reason;
    const char *location;
    const char *name;
    const uint8_t *signature_image;
    size_t signature_image_len;
    uint32_t signature_image_width;
    uint32_t signature_image_height;
    uint32_t page_index;
    float left;
    float bottom;
    float width;
    float height;
    const char *const *field_ids;
    size_t field_ids_len;
} cie_pdf_options;
```

---

## Stato & Prossimi Passi

| Stato | Dettagli |
|-------|----------|
| Core C/C++ modernizzato | PoDoFo 1.x, toolkit mock, CLI, API `cie_sign_verify_pin`, firma auto-generata |
| Plugin Flutter headless | Mock signing, firma NFC Android, verifica PIN + eventi NFC |
| SDK nativi standalone | Android SDK (Kotlin+JNI) e iOS SDK (ObjC++) separati dal plugin Flutter |
| Deploy iOS su device | App Flutter testata su iPhone fisico con mock signing funzionante |
| Script automazione | `build_ios_libs.sh`, `deploy_ios_device.sh`, `deploy_android_device.sh` |
| Firma NFC iOS reale | CoreNFC bridge pronto, da testare con carta CIE fisica |
| Automazione CI | Pipeline macOS per build host + test Flutter/Android |

---

## Contribuire

1. Installa gli strumenti necessari (Xcode, Android SDK+NDK r26, Flutter SDK)
2. Inizializza vcpkg: `cd cie_sign_sdk && ./scripts/bootstrap_vcpkg.sh`
3. Compila le dipendenze per la piattaforma target (vedi sezione Compilazione Dipendenze)
4. Verifica sempre i test pertinenti (`ctest`, `flutter test`, `gradlew connectedAndroidTest`) prima della PR
5. Non committare output generati (`Dependencies-*`, `.cxx`, `build/`, PDF firmati, file `.a`)
6. Documenta le novita qui nel README quando impattano il flusso (nuove API, strumenti, requisiti)

---

## Licenza

Vedi file LICENSE per i dettagli.
