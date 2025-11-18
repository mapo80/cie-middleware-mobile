#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-AE6RUT4717000334}"
JAVA_HOME_OVERRIDE="/Users/politom/Library/Java/JavaVirtualMachines/temurin-17.0.11.jdk/Contents/Home"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="$(cd "$PROJECT_ROOT/../cie_sign_sdk" && pwd)"
DEFAULT_NDK_ROOT="/Users/politom/Library/Android/sdk/ndk/26.2.11394342"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$DEFAULT_NDK_ROOT}"

echo "==> Building native libraries (ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT)"
(cd "$SDK_ROOT" && ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" ./scripts/build_android.sh)

echo "==> Cleaning Flutter example project"
(cd "$PROJECT_ROOT/example" && flutter clean)

echo "==> Fetching dependencies"
(cd "$PROJECT_ROOT/example" && flutter pub get)

echo "==> Building and deploying to device $DEVICE_ID"
(
  cd "$PROJECT_ROOT/example"
  JAVA_HOME="$JAVA_HOME_OVERRIDE" flutter run -d "$DEVICE_ID"
)
