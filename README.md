# CIE Mobile Signing SDK

Questo repository contiene il lavoro di modernizzazione e porting mobile dello stack di firma per Carta d'Identità Elettronica (CIE). L'obiettivo è fornire un **SDK nativo comune** per iOS e Android, con API allineate e riusabili da un plugin Flutter. Di seguito una panoramica delle componenti principali e delle attività completate/da completare.

## Obiettivi principali

1. **Core C/C++ condiviso** – rifattorizzare `cie_sign_sdk` in una libreria portabile (`ciesign_core`) che implementa la firma PKCS#7/PDF e offre callback per NFC, storage e logging.
2. **Bridge piattaforma** – fornire wrapper Kotlin (Android) e Swift (iOS) che espongono la stessa interfaccia (`CieSignSdk`), convertendo errori e modelli dati in strutture idiomatiche.
3. **Plugin Flutter** – progettare un pacchetto `cie_sign_flutter` che usi MethodChannel/FFI per interagire con i bridge nativi e offra API Dart asincrone per la firma.
4. **Test e automazione** – predisporre pipeline per buildare le dipendenze (vcpkg), compilare librerie native (AAR/XCFramework), eseguire test mock su emulatori/simulatori e produrre i PDF firmati da validare.

## Struttura del repository

```
├── android/                  # Progetto Gradle con moduli "cieSignSdk" e "CieSignMockApp"
├── ios/                      # Progetto Xcode per i test iOS
├── cie_sign_sdk/             # Sorgenti C/C++ e script vcpkg
├── sdk_unified_plan.md       # Piano architetturale per lo SDK unificato
└── README.md                 # Questo documento
```

### Modulo Android
- `android/cieSignSdk`: contiene il codice JNI (`mock_sign_android.cpp`) più le classi Kotlin `CieSignSdk`/`NativeBridge`.
- `android/CieSignMockApp`: host app di test con instrumentation `MockSignInstrumentedTest` che firma `sample.pdf` sia in memoria sia su disco. Il PDF prodotto è salvato in `android/mock_signed_android.pdf` per analisi.

### Modulo iOS
- `ios/CieSignIosTests.xcodeproj`: progetto Xcode con target `CieSignIosTests` e host app `CieSignIosHost`. Il test Swift (`MockSignTests`) usa la stessa pipeline mock e produce il PDF `mock_signed_ios.pdf`.

### Core native (`cie_sign_sdk/`)
- `CMakeLists.txt` aggiornata per funzionare in ambienti cross (Android/iOS) e saltare i test quando richiesto (`CIE_SIGN_SDK_SKIP_TESTS`).
- Script vcpkg:
  - `scripts/bootstrap_vcpkg.sh`
  - `scripts/build_dependencies.sh` (triplet desktop)
  - `scripts/build_ios_dependencies.sh`
  - `scripts/build_android_dependencies.sh`
- Documentazione:
  - `docs/build_mobile.md` – guida generale
  - `docs/tests_ios.md` – istruzioni per XCTest
  - `docs/tests_android.md` – istruzioni per AVD/test strumentali

## Stato attuale

- ✅ Aggiornamento PoDoFo/OpenSSL e supporto PDF signing mock.
- ✅ Progetto iOS con test che verifica ByteRange e certificato mock.
- ✅ Progetto Android con JNI, instrumentation test e PDF esportato.
- ✅ Script per dipendenze iOS/Android e pipeline manuale di build (Gradle/Xcode).
- 🔄 In corso: definizione interfaccia unificata e plugin Flutter (`sdk_unified_plan.md`).

## Prossimi passi

1. Consolidare l’API C (`cie_sign_platform.h`) con hook NFC/log/storage e implementare versioni mock per i test automatici.
2. Pubblicare wrapper Kotlin/Swift con interfacce identiche, includendo conversione degli errori, callback di stato e parametri di configurazione (policy, TSA, appearance).
3. Realizzare il plugin Flutter (channel) e l’app di esempio, sfruttando i build artefacts prodotti dai moduli native.
4. Automatizzare la CI (macOS host) per compilare, testare e allegare gli artefatti (PDF firmati) a ogni release/tag.
5. Pianificare l’integrazione NFC reale (Android `NfcAdapter`, iOS `CoreNFC`) con inserimento del codice specifico tramite interfacce condivise.

## Come contribuire

1. Assicurati di avere le dipendenze installate (vcpkg, Android SDK/NDK, Xcode).
2. Segui le guide in `docs/` per buildare host/iOS/Android.
3. Apri una PR con descrizione dettagliata, screenshot/log dei test e PDF generati. Ricordati di non committare directory generate (`cie_sign_sdk/.vcpkg`, `Dependencies-*`, `android/cieSignSdk/.cxx`).

Grazie per contribuire allo sviluppo dello SDK CIE mobile!
