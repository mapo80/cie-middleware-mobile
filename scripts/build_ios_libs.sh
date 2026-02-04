#!/usr/bin/env bash
# =============================================================================
# build_ios_libs.sh - Compila le librerie native per iOS (device e simulator)
# =============================================================================
#
# Uso:
#   ./scripts/build_ios_libs.sh [device|simulator|all]
#
# Argomenti:
#   device     - Compila solo per iOS device (arm64)
#   simulator  - Compila solo per iOS Simulator (arm64)
#   all        - Compila per entrambi (default)
#
# Prerequisiti:
#   - Xcode installato con command line tools
#   - CMake (brew install cmake)
#   - Dipendenze in cie_sign_sdk/Dependencies-ios/ e Dependencies-ios-sim/
#
# Esempi:
#   ./scripts/build_ios_libs.sh           # Compila device + simulator
#   ./scripts/build_ios_libs.sh device    # Solo device fisico
#   ./scripts/build_ios_libs.sh simulator # Solo simulator
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_ROOT="$PROJECT_ROOT/cie_sign_sdk"

TARGET="${1:-all}"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verifica prerequisiti
check_prerequisites() {
    log_info "Verifico prerequisiti..."

    if ! command -v cmake &> /dev/null; then
        log_error "CMake non trovato. Installa con: brew install cmake"
        exit 1
    fi

    if ! command -v xcrun &> /dev/null; then
        log_error "Xcode command line tools non trovati. Installa con: xcode-select --install"
        exit 1
    fi

    log_info "Prerequisiti OK"
}

# Compila per iOS device (arm64)
build_device() {
    log_info "==> Compilazione per iOS Device (arm64)..."

    local BUILD_DIR="$SDK_ROOT/build/ios-arm64"
    local DEPS_DIR="$SDK_ROOT/Dependencies-ios"

    if [[ ! -d "$DEPS_DIR" ]]; then
        log_error "Directory dipendenze non trovata: $DEPS_DIR"
        log_error "Assicurati che le dipendenze iOS siano state compilate."
        exit 1
    fi

    mkdir -p "$BUILD_DIR"

    cmake -B "$BUILD_DIR" -S "$SDK_ROOT" \
        -DCMAKE_TOOLCHAIN_FILE="$SDK_ROOT/cmake/toolchains/ios-arm64.cmake" \
        -DDEPENDENCIES_DIR="$DEPS_DIR" \
        -DCIE_SIGN_SDK_SKIP_TESTS=ON

    cmake --build "$BUILD_DIR" --target ciesign_core -j"$(sysctl -n hw.ncpu)"

    # Copia nella directory attesa dal podspec
    mkdir -p "$SDK_ROOT/build/ios"
    cp "$BUILD_DIR/libcie_sign_sdk.a" "$SDK_ROOT/build/ios/"
    cp "$BUILD_DIR/libciesign_core.a" "$SDK_ROOT/build/ios/"

    log_info "Librerie iOS device copiate in: $SDK_ROOT/build/ios/"
}

# Compila per iOS Simulator (arm64)
build_simulator() {
    log_info "==> Compilazione per iOS Simulator (arm64)..."

    local BUILD_DIR="$SDK_ROOT/build/ios-sim"
    local DEPS_DIR="$SDK_ROOT/Dependencies-ios-sim"

    if [[ ! -d "$DEPS_DIR" ]]; then
        log_error "Directory dipendenze non trovata: $DEPS_DIR"
        log_error "Assicurati che le dipendenze iOS Simulator siano state compilate."
        exit 1
    fi

    mkdir -p "$BUILD_DIR"

    cmake -B "$BUILD_DIR" -S "$SDK_ROOT" \
        -DCMAKE_TOOLCHAIN_FILE="$SDK_ROOT/cmake/toolchains/ios-sim-arm64.cmake" \
        -DDEPENDENCIES_DIR="$DEPS_DIR" \
        -DCIE_SIGN_SDK_SKIP_TESTS=ON

    cmake --build "$BUILD_DIR" --target ciesign_core -j"$(sysctl -n hw.ncpu)"

    log_info "Librerie iOS Simulator in: $BUILD_DIR/"
}

# Main
main() {
    log_info "Build iOS Native Libraries"
    log_info "SDK Root: $SDK_ROOT"
    log_info "Target: $TARGET"
    echo ""

    check_prerequisites

    case "$TARGET" in
        device)
            build_device
            ;;
        simulator)
            build_simulator
            ;;
        all)
            build_device
            build_simulator
            ;;
        *)
            log_error "Target non valido: $TARGET"
            log_error "Usa: device, simulator, o all"
            exit 1
            ;;
    esac

    echo ""
    log_info "Build completata!"
}

main "$@"
