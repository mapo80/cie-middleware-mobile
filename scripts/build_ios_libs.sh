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
#   - vcpkg bootstrappato (cie_sign_sdk/scripts/bootstrap_vcpkg.sh)
#
# Le dipendenze sono lette direttamente da .vcpkg/installed/<triplet>/
# senza copie intermedie.
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
VCPKG_ROOT="$SDK_ROOT/.vcpkg"

TARGET="${1:-all}"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
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

    if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
        log_error "vcpkg non trovato. Esegui: cie_sign_sdk/scripts/bootstrap_vcpkg.sh"
        exit 1
    fi

    log_info "Prerequisiti OK (cmake: $(cmake --version | head -1), vcpkg: $VCPKG_ROOT)"
}

# Trova il miglior triplet vcpkg installato per una data famiglia.
# Preferisce i triplet che hanno cryptopp (necessario per CryptoppUtils).
find_best_triplet() {
    local family="$1"
    local candidates=()

    case "$family" in
        arm64-ios)
            candidates=(arm64-ios-17 arm64-ios-15 arm64-ios)
            ;;
        arm64-ios-simulator)
            candidates=(arm64-ios-simulator)
            ;;
    esac

    for t in "${candidates[@]}"; do
        local dir="$VCPKG_ROOT/installed/$t"
        if [[ -f "$dir/lib/libcryptopp.a" && -d "$dir/include/openssl" ]]; then
            log_info "Triplet selezionato: $t (cryptopp + openssl OK)" >&2
            echo "$t"
            return
        fi
    done

    # Fallback: primo triplet che ha almeno openssl
    for t in "${candidates[@]}"; do
        local dir="$VCPKG_ROOT/installed/$t"
        if [[ -d "$dir/include/openssl" ]]; then
            log_warn "Triplet $t: openssl OK, cryptopp mancante" >&2
            echo "$t"
            return
        fi
    done

    log_error "Nessun triplet vcpkg trovato per $family." >&2
    log_error "Triplet disponibili:" >&2
    ls -1 "$VCPKG_ROOT/installed/" 2>/dev/null | grep -v vcpkg | sed 's/^/  /' >&2
    exit 1
}

# Verifica che il triplet abbia le librerie minime necessarie
verify_triplet() {
    local triplet="$1"
    local dir="$VCPKG_ROOT/installed/$triplet"
    local missing=()

    log_info "Verifico dipendenze in $dir ..."

    for lib in libcrypto.a libssl.a libpodofo.a libcurl.a libxml2.a libz.a libcryptopp.a; do
        if [[ -f "$dir/lib/$lib" ]]; then
            log_info "  $lib OK"
        else
            log_warn "  $lib MANCANTE"
            missing+=("$lib")
        fi
    done

    for hdr in openssl/crypto.h podofo/podofo.h; do
        if [[ -f "$dir/include/$hdr" ]]; then
            log_info "  include/$hdr OK"
        else
            log_warn "  include/$hdr MANCANTE"
            missing+=("include/$hdr")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "${#missing[@]} dipendenze mancanti (la build potrebbe fallire)"
    else
        log_info "Tutte le dipendenze verificate"
    fi
}

# Compila per iOS device (arm64)
build_device() {
    log_info "==> Compilazione per iOS Device (arm64)..."

    local BUILD_DIR="$SDK_ROOT/build/ios-arm64"
    local TRIPLET
    TRIPLET=$(find_best_triplet arm64-ios)
    local DEPS_DIR="$VCPKG_ROOT/installed/$TRIPLET"

    verify_triplet "$TRIPLET"

    log_info "DEPENDENCIES_DIR = $DEPS_DIR"
    log_info "BUILD_DIR        = $BUILD_DIR"
    log_info "TOOLCHAIN        = $SDK_ROOT/cmake/toolchains/ios-arm64.cmake"

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
    local TRIPLET
    TRIPLET=$(find_best_triplet arm64-ios-simulator)
    local DEPS_DIR="$VCPKG_ROOT/installed/$TRIPLET"

    verify_triplet "$TRIPLET"

    log_info "DEPENDENCIES_DIR = $DEPS_DIR"
    log_info "BUILD_DIR        = $BUILD_DIR"
    log_info "TOOLCHAIN        = $SDK_ROOT/cmake/toolchains/ios-sim-arm64.cmake"

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
