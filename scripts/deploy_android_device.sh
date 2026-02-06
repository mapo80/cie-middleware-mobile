#!/usr/bin/env bash
# =============================================================================
# deploy_android_device.sh - Build e deploy dell'app Flutter su Android device
# =============================================================================
#
# Uso:
#   ./scripts/deploy_android_device.sh [device_id] [--release]
#
# Argomenti:
#   device_id  - ID del device Android (opzionale, usa il primo disponibile)
#   --release  - Build in modalita release (opzionale)
#
# Prerequisiti:
#   - Android SDK installato
#   - Android NDK r26
#   - Flutter SDK nel PATH
#   - Java 17
#   - Device Android connesso via USB con debug abilitato
#
# Esempi:
#   ./scripts/deploy_android_device.sh                  # Deploy debug
#   ./scripts/deploy_android_device.sh --release        # Deploy release
#   ./scripts/deploy_android_device.sh AE6RUT47        # Deploy su device specifico
#
# Variabili d'ambiente opzionali:
#   JAVA_HOME          - Path a JDK 17
#   ANDROID_NDK_ROOT   - Path a Android NDK
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_ROOT="$PROJECT_ROOT/cie_sign_flutter"

# Default paths (modifica se necessario)
DEFAULT_JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
DEFAULT_NDK_ROOT="$HOME/Library/Android/sdk/ndk/26.2.11394342"

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

# Configura environment
setup_environment() {
    # Java Home
    if [[ -z "${JAVA_HOME:-}" ]]; then
        if [[ -d "$DEFAULT_JAVA_HOME" ]]; then
            export JAVA_HOME="$DEFAULT_JAVA_HOME"
        else
            # Cerca Java 17
            local java_path
            java_path=$(/usr/libexec/java_home -v 17 2>/dev/null || true)
            if [[ -n "$java_path" ]]; then
                export JAVA_HOME="$java_path"
            fi
        fi
    fi

    # Android NDK
    if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
        if [[ -d "$DEFAULT_NDK_ROOT" ]]; then
            export ANDROID_NDK_ROOT="$DEFAULT_NDK_ROOT"
        fi
    fi

    # Android SDK platform-tools (per adb)
    if ! command -v adb &> /dev/null; then
        local android_sdk_dirs=(
            "$HOME/Library/Android/sdk"
            "${ANDROID_HOME:-}"
            "${ANDROID_SDK_ROOT:-}"
        )

        for sdk_dir in "${android_sdk_dirs[@]}"; do
            if [[ -n "$sdk_dir" && -x "$sdk_dir/platform-tools/adb" ]]; then
                export PATH="$sdk_dir/platform-tools:$PATH"
                log_info "ADB aggiunto al PATH da: $sdk_dir/platform-tools"
                break
            fi
        done
    fi

    log_info "JAVA_HOME: ${JAVA_HOME:-non impostato}"
    log_info "ANDROID_NDK_ROOT: ${ANDROID_NDK_ROOT:-non impostato}"
}

# Verifica prerequisiti
check_prerequisites() {
    log_step "Verifico prerequisiti..."

    if ! command -v flutter &> /dev/null; then
        log_error "Flutter non trovato nel PATH"
        exit 1
    fi

    if ! command -v adb &> /dev/null; then
        log_error "ADB non trovato. Assicurati che Android SDK sia nel PATH"
        exit 1
    fi

    if [[ -z "${JAVA_HOME:-}" ]]; then
        log_warn "JAVA_HOME non impostato. La build potrebbe fallire."
    fi

    log_info "Prerequisiti OK"
}

# Lista device Android disponibili
list_devices() {
    log_step "Device Android disponibili:"
    adb devices -l | tail -n +2 | grep -v "^$" || true
}

# Aggiorna dipendenze
update_dependencies() {
    log_step "Aggiorno dipendenze Flutter..."
    (cd "$FLUTTER_ROOT/example" && flutter pub get)
}

# Build e deploy
deploy() {
    local flutter_args=()

    if [[ -n "$DEVICE_ID" ]]; then
        flutter_args+=("-d" "$DEVICE_ID")
    fi

    if [[ -n "$RELEASE_MODE" ]]; then
        flutter_args+=("--release")
        log_step "Build e deploy in modalita RELEASE..."
    else
        log_step "Build e deploy in modalita DEBUG..."
    fi

    (cd "$FLUTTER_ROOT/example" && flutter run ${flutter_args[@]+"${flutter_args[@]}"})
}

# Main
main() {
    parse_args "$@"

    echo ""
    log_info "=========================================="
    log_info "  Deploy CIE Sign Flutter su Android"
    log_info "=========================================="
    echo ""

    setup_environment
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
