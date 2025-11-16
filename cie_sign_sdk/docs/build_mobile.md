# Guida completa alla build di `ciesign_core`

Questa guida descrive come preparare l’ambiente, costruire le dipendenze e compilare lo SDK per desktop, iOS e Android. Tutti i comandi sono pensati per macOS/Linux; su Windows utilizzare PowerShell/CMD equivalenti dove specificato.

## 1. Struttura del repository
- `cie_sign_sdk/Dependencies`: cartella dove verranno copiati include/lib statici di terze parti.
- `cie_sign_sdk/scripts`: contiene gli script di automazione (`bootstrap_vcpkg`, `build_dependencies`, `build_host`, `build_ios`, `build_android`).
- `cie_sign_sdk/cmake/toolchains`: toolchain file per i target mobili.
- `cie_sign_sdk/src/mobile`: implementazione dell’SDK mobile (`ciesign_core`).

## 2. Prerequisiti generali
1. **Compilatori**
   - macOS: Xcode Command Line Tools (`xcode-select --install`).
   - Linux: `build-essential`, `clang`, `cmake`, `ninja`.
   - Windows: Visual Studio 2022 + `cmake`.
2. **Strumenti comuni**
   - `git`, `curl`, `rsync`, `python3`.
   - Per Android: Android Studio + NDK (configurare `ANDROID_NDK_ROOT`).
   - Per iOS: macOS 13+ e Xcode 14+.

## 3. Preparazione vcpkg
1. Posizionarsi nella root `cie_sign_sdk`.
2. Eseguire:
   ```bash
   ./scripts/bootstrap_vcpkg.sh
   ```
   Questo clona `vcpkg` in `cie_sign_sdk/.vcpkg` e ne esegue il bootstrap.
3. Facoltativo: esportare `VCPKG_ROOT` per sessioni future.

## 4. Costruzione delle dipendenze
1. Scegliere il triplet desiderato (default `x64-osx`). Esempi:
   - macOS Intel: `x64-osx`
   - macOS ARM: `arm64-osx`
   - Linux x86_64: `x64-linux`
2. Lanciare:
   ```bash
   ./scripts/build_dependencies.sh x64-osx
   ```
3. Lo script:
   - installa i pacchetti `openssl`, `curl`, `libxml2`, `zlib`, `libpng`, `freetype`, `fontconfig`, `podofo`, `bzip2`, `cryptopp`;
   - copia anche le dipendenze transitivi richieste da PoDoFo/Freetype (`brotli`, `libjpeg-turbo`, `libtiff`, `liblzma`, `utf8proc`, `expat`) nella cartella `Dependencies/<pacchetto>`.
4. Se servono più triplet ripetere con il relativo argomento.
5. **Per iOS** ora esiste uno script dedicato per ogni libreria (tutti in `scripts/ios/`). Ogni script:
   - identifica la versione esatta disponibile in vcpkg,
   - scarica e compila il pacchetto per `arm64-ios`,
   - copia header e `.a` in `Dependencies-ios/<nome>`.

   Esempio per OpenSSL:
   ```bash
   ./scripts/ios/build_ios_openssl.sh
   ```

   Script disponibili:

   | Dipendenza | Versione (vcpkg `arm64-ios`) | Script |
   | --- | --- | --- |
   | OpenSSL | `3.6.0#3` | `scripts/ios/build_ios_openssl.sh` |
   | cURL | `8.17.0` | `scripts/ios/build_ios_curl.sh` |
   | libxml2 | `2.15.0` | `scripts/ios/build_ios_libxml2.sh` |
   | zlib | `1.3.1` | `scripts/ios/build_ios_zlib.sh` |
   | libpng | `1.6.50` | `scripts/ios/build_ios_libpng.sh` |
   | freetype (con brotli/bzip2/png/zlib) | `2.13.3` | `scripts/ios/build_ios_freetype.sh` |
   | fontconfig | `2.15.0#4` | `scripts/ios/build_ios_fontconfig.sh` |
   | PoDoFo | `1.0.2#1` | `scripts/ios/build_ios_podofo.sh` |
   | bzip2 | `1.0.8#6` | `scripts/ios/build_ios_bzip2.sh` |
   | Crypto++ | `8.9.0` | `scripts/ios/build_ios_cryptopp.sh` |

   Prima di eseguire `build_ios_fontconfig.sh` assicurarsi di avere gli strumenti autotools:
   ```bash
   brew install autoconf autoconf-archive automake libtool
   ```

   Tutte le librerie vengono salvate in `Dependencies-ios/...`. Durante la configurazione CMake passare `-DDEPENDENCIES_DIR=/path/to/Dependencies-ios` (oppure impostare `IOS_DEPENDENCIES_DIR` quando si lancia `scripts/build_ios.sh`).

6. Lo script `build_dependencies.sh` ora copia anche le librerie ausiliarie richieste da PoDoFo/Freetype (brotli, libjpeg-turbo, libtiff, liblzma, utf8proc e libexpat) in `Dependencies/<pkg>`. Su macOS Apple Silicon è consigliato eseguire:
   ```bash
   ./scripts/build_dependencies.sh arm64-osx
   ```
   per evitare errori di linking causati da librerie x86_64.

> Nota: per ambienti con restrizioni di rete è possibile pre-installare i pacchetti vcpkg e settare `VCPKG_DISABLE_METRICS=1`.

## 5. Build su desktop (host)
1. Assicurarsi che `Dependencies` contenga i pacchetti richiesti.
2. Eseguire:
   ```bash
   ./scripts/build_host.sh
   ```
3. Artefatti:
   - `build/host/libciesign_core.a`
   - `build/host/libcie_sign_sdk.a` (libreria legacy)
   - headers pubblici in `include/mobile`.

## 6. Build per iOS
1. Dipendenze: utilizzare il triplet `arm64-osx` o compilare manualmente le librerie cross.
2. Assicurarsi di aver eseguito gli script in `scripts/ios/` per popolare `Dependencies-ios`, quindi lanciare:
   ```bash
   IOS_DEPENDENCIES_DIR=$(pwd)/Dependencies-ios ./scripts/build_ios.sh
   ```
   oppure utilizzare il wrapper `./scripts/build_ios_sdk.sh` che applica automaticamente la variabile e invoca `build_ios.sh`.
3. Il toolchain `cmake/toolchains/ios-arm64.cmake` genera `build/ios/libciesign_core.a` (architettura arm64).
4. Per creare una `xcframework`, ripetere la build con `iphonesimulator` (modificando il toolchain o impostando `CMAKE_OSX_SYSROOT`) e poi combinare gli output con `xcodebuild -create-xcframework`.

## 7. Build per Android
1. Impostare `ANDROID_NDK_ROOT` (es. `export ANDROID_NDK_ROOT=$HOME/Library/Android/sdk/ndk/25.2.9519653`).
2. Eseguire:
   ```bash
   ./scripts/build_android.sh
   ```
3. Il build produce `build/android/libciesign_core.a` pronto per essere inserito in un `.aar`.
4. Per ABI multiple ripetere cambiando `ANDROID_ABI` (passare `-DANDROID_ABI=armeabi-v7a` ecc. modificando lo script o esportando `ANDROID_ABI`).

## 8. Packaging suggerito
1. **iOS**:
   ```bash
   xcodebuild -create-xcframework \
     -library build/ios/libciesign_core.a -headers include/mobile \
     -output artifacts/CieSignKit.xcframework
   ```
2. **Android**:
   - Copiare `libciesign_core.a` in `android/` e creare JNI wrapper.
   - Generare `.aar` con Gradle includendo i headers in `src/main/cpp/include`.

## 9. Verifica e test
1. **Test automatici**:
   ```bash
   (cd build/host && ctest --output-on-failure)
   ```
   Assicurarsi di aver eseguito `./scripts/build_dependencies.sh <triplet>` con il triplet adatto (`arm64-osx` su Apple Silicon) così da avere tutte le librerie richieste (`brotli`, `libtiff`, `libjpeg`, `libexpat`, ecc.).
2. **Verifica manuale**:
   - Collegare un lettore NFC e fornire un callback APDU reale.
   - Invocare `cie_sign_execute` con `doc_type` differente e verificare dimensione output.
3. **Lint**: eseguire `cmake --build <dir> --target clang-format` se disponibile.

## 10. Risoluzione problemi
| Problema | Soluzione |
| --- | --- |
| `vcpkg` non trova un pacchetto | Aggiornare con `git pull` e ri-eseguire bootstrap. |
| `cmake` non trova header | Verificare che `Dependencies/<pkg>/include` contenga i file corretti e che gli script siano stati eseguiti col triplet adatto. |
| Build iOS fallisce per simboli mancanti | Assicurarsi che tutte le librerie copie siano Build per arm64 e aggiungere eventuali `-fembed-bitcode`. |
| Build Android: errore `ANDROID_NDK_ROOT not set` | Esportare la variabile e verificare che punti ad un NDK valido. |

## 11. Strumenti aggiuntivi
- `scripts/build_ios.sh` / `build_android.sh`: accettano variabili `BUILD_DIR`, `CMAKE_ARGS` per personalizzare (es. `CMAKE_ARGS="-DCMAKE_IOS_INSTALL_COMBINED=ON"`).
- È possibile usare `cmake -S cie_sign_sdk -B build/ninja -G Ninja` per velocizzare le build su CI.

## 12. Automazione CI
Suggerimento per GitHub Actions:
```yaml
- uses: actions/checkout@v4
- name: Bootstrap vcpkg
  run: cie_sign_sdk/scripts/bootstrap_vcpkg.sh
- name: Build deps
  run: cie_sign_sdk/scripts/build_dependencies.sh x64-linux
- name: Build core
  run: cie_sign_sdk/scripts/build_host.sh
```

Con queste istruzioni è possibile riprodurre l’ambiente completo per compilare `ciesign_core` e integrare lo SDK nei progetti mobili.
