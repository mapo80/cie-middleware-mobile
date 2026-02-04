#!/usr/bin/env bash
# =============================================================================
# deploy_ios_device.sh - Build e deploy dell'app Flutter su iPhone fisico
# =============================================================================
#
# Uso:
#   ./scripts/deploy_ios_device.sh [device_id] [--release]
#
# Argomenti:
#   device_id  - ID del device iOS (opzionale, usa il primo disponibile)
#   --release  - Build in modalita release (opzionale)
#
# Prerequisiti:
#   - Xcode installato e configurato
#   - Flutter SDK nel PATH
#   - iPhone connesso via USB e trusted
#   - Certificato sviluppatore configurato in Xcode
#   - Dipendenze native compilate (esegui prima build_ios_libs.sh)
#
# Esempi:
#   ./scripts/deploy_ios_device.sh                    # Deploy debug sul primo device
#   ./scripts/deploy_ios_device.sh --release          # Deploy release sul primo device
#   ./scripts/deploy_ios_device.sh 00008030-XXXX      # Deploy su device specifico
#
# =============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_ROOT="$PROJECT_ROOT/cie_sign_sdk"
FLUTTER_ROOT="$PROJECT_ROOT/cie_sign_flutter"

DEVICE_ID=""
RELEASE_MODE=""

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse argomenti
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --release)
                RELEASE_MODE="--release"
                shift
                ;;
            *)
                DEVICE_ID="$1"
                shift
                ;;
        esac
    done
}

# Verifica prerequisiti
check_prerequisites() {
    log_step "Verifico prerequisiti..."

    if ! command -v flutter &> /dev/null; then
        log_error "Flutter non trovato nel PATH"
        log_error "Installa Flutter: https://flutter.dev/docs/get-started/install"
        exit 1
    fi

    if ! command -v pod &> /dev/null; then
        log_error "CocoaPods non trovato. Installa con: sudo gem install cocoapods"
        exit 1
    fi

    # Verifica librerie native
    if [[ ! -f "$SDK_ROOT/build/ios/libciesign_core.a" ]]; then
        log_warn "Librerie native iOS non trovate."
        log_info "Eseguo build_ios_libs.sh..."
        "$SCRIPT_DIR/build_ios_libs.sh" device
    fi

    log_info "Prerequisiti OK"
}

# Lista device iOS disponibili
list_devices() {
    log_step "Device iOS disponibili:"
    flutter devices | grep -i "ios\|iphone\|ipad" || true
}

# Aggiorna dipendenze
update_dependencies() {
    log_step "Aggiorno dipendenze Flutter..."
    (cd "$FLUTTER_ROOT/example" && flutter pub get)

    log_step "Aggiorno CocoaPods..."
    (cd "$FLUTTER_ROOT/example/ios" && pod install)
}

# Build e deploy
deploy() {
    local cmd="flutter run"

    if [[ -n "$DEVICE_ID" ]]; then
        cmd="$cmd -d $DEVICE_ID"
    fi

    if [[ -n "$RELEASE_MODE" ]]; then
        cmd="$cmd --release"
        log_step "Build e deploy in modalita RELEASE..."
    else
        log_step "Build e deploy in modalita DEBUG..."
    fi

    (cd "$FLUTTER_ROOT/example" && eval "$cmd")
}

# Main
main() {
    parse_args "$@"

    echo ""
    log_info "=========================================="
    log_info "  Deploy CIE Sign Flutter su iOS"
    log_info "=========================================="
    echo ""

    check_prerequisites
    echo ""

    list_devices
    echo ""

    update_dependencies
    echo ""

    deploy
}

main "$@"
