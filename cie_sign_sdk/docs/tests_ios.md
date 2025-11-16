# Test firma mock su iOS

Il progetto `ios/CieSignIosTests.xcodeproj` contiene tutto l’occorrente per eseguire gli stessi test di firma mock presenti su macOS (`tests/mock/mock_sign_test.cpp`) direttamente in un target **XCTest** per iOS.

## 1. Prepara le dipendenze

Costruiamo le librerie native una sola volta con `vcpkg`. Per il device (iphoneos) e per il simulatore usiamo lo stesso script, cambiando il triplet/uscita:

```bash
cd cie_sign_sdk
./scripts/bootstrap_vcpkg.sh                     # solo se non già inizializzato
./scripts/build_ios_dependencies.sh arm64-ios    # librerie per device -> Dependencies-ios/
DEPS_DIR="$PWD/Dependencies-ios-sim" ./scripts/build_ios_dependencies.sh arm64-ios-simulator
```

In questo passaggio vengono copiati anche `libiconv/libcharset`, necessari perché PoDoFo/LibXML aspettano le versioni GNU (le .tbd di sistema non esportano i simboli `_libiconv_*`).

## 2. Librerie statiche dello SDK

Genera le static per `ciesign_core` e `cie_sign_sdk` usando i preset CMake già presenti (`scripts/build_ios.sh`, `scripts/build_ios_sim.sh`) oppure, in alternativa, il workflow documentato in `docs/build_mobile.md`. I test Xcode linkano direttamente:

- `cie_sign_sdk/build/ios/Release-iphoneos/libciesign_core.a`
- `cie_sign_sdk/build/ios/Release-iphoneos/libcie_sign_sdk.a`
- `cie_sign_sdk/build/ios-sim/Release-iphonesimulator/libciesign_core.a`
- `cie_sign_sdk/build/ios-sim/Release-iphonesimulator/libcie_sign_sdk.a`

Assicurati che le versioni per simulator siano disponibili perché sono quelle utilizzate dal bundle di test.

## 3. Struttura del progetto Xcode

`CieSignIosTests.xcodeproj` dichiara:

- Target host `CieSignIosHost` (SwiftUI minimale) usato solo per caricare gli XCTest.
- Target `CieSignIosTests` che include:
  - `tests/ios/mock_sign_ios.mm`, `tests/mock/mock_transport.cpp`, `tests/mock/mock_apdu_sequence.cpp`.
  - Bridging header `tests/ios/CieSignTests-Bridging-Header.h` con `CieSignTestBridge.h`.
  - Lo XCTest Swift `ios/CieSignIosTests/MockSignTests.swift`.
  - La risorsa `data/fixtures/sample.pdf` copiata nel bundle.
- Collegamenti a tutte le librerie statiche in `Dependencies-ios-sim` (openssl, libcurl, podofo, libiconv, ecc.).

Il target è già configurato con `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `CLANG_CXX_LANGUAGE_STANDARD = gnu++17` e `PODOFO_STATIC` per allinearsi alla toolchain usata dal core.

## 4. Esecuzione dei test

È possibile lanciare tutto da Xcode selezionando lo scheme `CieSignIosTests`, oppure via CLI con una destinazione simulatore compatibile (es. iOS 18 “iPhone 17”):

```bash
xcodebuild \
  -project ios/CieSignIosTests.xcodeproj \
  -scheme CieSignIosTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Il test `MockSignTests.testMockPdfSignature` esegue il workflow completo:

1. Firma un buffer fittizio PKCS#7 utilizzando `MockApduTransport`+`cie_sign_execute`.
2. Firma `sample.pdf` con PoDoFo 1.x, inserendo campo firma e ByteRange.
3. Estrae il CMS dal PDF e verifica che il certificato corrisponda esattamente al mock signer (`mock_signer_material.h`).

Il test fallisce se qualsiasi step del core restituisce un errore oppure se il CMS non combacia con il materiale del mock, garantendo che l’SDK funzioni in modalità “senza NFC” direttamente su iOS.

## 5. Test del bridge Swift/CoreNFC in modalità mock

Per mimare il comportamento dell’app mobile (ma senza richiedere un lettore NFC reale), lo scheme include anche `CieSignBridgeTests`. Il test `testMockBridgeProducesPdf` istanzia `CieSignMobileBridge(mockTransportWithLogger:)`, sfrutta la stessa `MockApduTransport` dei test nativi e verifica che:

- Il PDF firmato inizi con `%PDF` e contenga il dizionario `/Type/Sig`.
- Il file venga salvato nella sandbox del simulatore (`Documents/mock_signed_ios_bridge.pdf`).

In questo modo possiamo esercitare il layer Swift/Objective‑C++ esattamente come farà l’app Flutter/iOS, pur mantenendo l’I/O NFC completamente mockato nelle fasi iniziali di sviluppo.
