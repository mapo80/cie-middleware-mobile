# Agent Notes

## Handling signature-appearance changes
1. Keep `PdfSignatureGenerator::InitSignature` signatures stable (9/13 args) to avoid breaking downstream consumers (Android JNI, disigon desktop, cached headers under `android/.cxx`).
2. To pass new data (e.g., signature image bytes), add dedicated setters on `PdfSignatureGenerator` and call them from the platform bridges (`cie_sign_core`, `disigonsdk`) before invoking `InitSignature`.
3. When header changes are required, delete `cie_sign_flutter/android/.cxx` (and `build/`) so Gradle/CMake picks up the updated headers and avoids stale build artifacts.

## Launching the Android sample app
1. Start the AVD: `emulator -avd CieSignArm64 -no-snapshot` and wait for `adb wait-for-device`.
2. Ensure `JAVA_HOME` targets JDK 17 (e.g., `temurin-17`). Run `JAVA_HOME=/path/to/jdk flutter run -d emulator-5554 -t lib/main.dart --debug` from `cie_sign_flutter/example`.
3. If Flutter complains about mismatched NDK versions, add `ndkVersion = "28.2.13676358"` to `example/android/app/build.gradle(.kts)` to silence the warning.
