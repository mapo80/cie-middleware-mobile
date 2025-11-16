# Test firma mock su Android

Questa cartella (`android/`) contiene un progetto Gradle con due moduli:

- `cieSignSdk`: libreria Android che carica il core C++ (`ciesign_core`) tramite JNI e fornisce il bridge `CieSignSdk.mockSignPdf`.
- `CieSignMockApp`: piccola app usata come host per gli **instrumentation test**. Il test `MockSignInstrumentedTest` firma `sample.pdf`, verifica la presenza del campo firma e salva il file risultante tra i documenti dell'app.

## 1. Prerequisiti

```bash
# JDK 17
/usr/libexec/java_home -V              # verificare che sia disponibile Temurin 17

# Android SDK + NDK + CMake
brew install --cask android-commandlinetools
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
yes | sdkmanager "platform-tools" "platforms;android-34" \
                 "build-tools;34.0.0" "cmdline-tools;latest" \
                 "cmake;3.22.1" "ndk;26.2.11394342"

# Gradle (wrapper usa Gradle 8.7, ma serve il binario per gradle init)
brew install gradle
```

Impostare sempre queste variabili prima di avviare Gradle/CMake:

```bash
export JAVA_HOME=$HOME/Library/Java/JavaVirtualMachines/temurin-17.0.11.jdk/Contents/Home
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/26.2.11394342
```

## 2. Dipendenze native via vcpkg

Usiamo lo stesso script delle altre piattaforme ma con i triplet Android. Per i device/AVD `arm64-v8a` è sufficiente:

```bash
cd cie_sign_sdk
./scripts/bootstrap_vcpkg.sh                             # solo al primo avvio
./scripts/build_android_dependencies.sh arm64-android   # produce Dependencies-arm64-android/
```

(Se servissero altri ABI basta ripetere lo script con il relativo triplet, ad es. `x64-android`.)

## 3. Build della libreria e dell’app host

```bash
cd android
./gradlew :CieSignMockApp:assembleDebug
```

Il task esegue anche la toolchain CMake/NDK e genera `android/cieSignSdk/build/.../libciesign_mobile.so`.

## 4. Eseguire i test strumentali

Serve un emulatore **ARM64** (Pixel 8/Pixel Fold) per sfruttare gli stessi binari compilati con `arm64-android`. Esempio di provisioning:

```bash
sdkmanager "system-images;android-34;google_apis;arm64-v8a"
avdmanager create avd -n pixel8-arm64 -k "system-images;android-34;google_apis;arm64-v8a"
emulator @pixel8-arm64 -no-snapshot -dns-server 8.8.8.8 &
```

Poi lanciare:

```bash
cd android
./gradlew :CieSignMockApp:connectedDebugAndroidTest
```

Il test `MockSignInstrumentedTest`:

1. Carica `sample.pdf` dagli assets del test.
2. Invoca `CieSignSdk.mockSignPdf`, che passa per JNI → `cie_sign_execute` → PoDoFo.
3. Scrive il risultato in `mock_signed_android.pdf` dentro `Android/data/it.ipzs.ciesign.mock/files/` e verifica che il contenuto contenga `/Type/Sig`.

Puoi recuperare il PDF firmato con:

```bash
adb shell run-as it.ipzs.ciesign.mock cat files/mock_signed_android.pdf > mock_signed_android.pdf
```

## 5. Note

- L’SDK usa gli stessi fixture mock del test macOS/iOS (APDU sintetici + certificato embedded) e valida il CMS nello stesso modo.
- Per semplificare la build Android il TSA client è stub lato JNI: il test non effettua chiamate esterne.
- Se aggiungi nuovi ABI o cambi percorso delle librerie ricordati di aggiornare `DEPENDENCIES_DIR` nei moduli Gradle (`cieSignSdk/build.gradle`).
