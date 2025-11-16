#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR"
TARGET_TRIPLET="${1:-arm64-android}"
DEFAULT_DEPS_DIR="$PROJECT_ROOT/Dependencies-${TARGET_TRIPLET}"
DEPS_DIR="${DEPS_DIR:-$DEFAULT_DEPS_DIR}"
VCPKG_ROOT="${VCPKG_ROOT:-"$PROJECT_ROOT/.vcpkg"}"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  echo "vcpkg not found. Run scripts/bootstrap_vcpkg.sh first." >&2
  exit 1
fi

echo "Building Android dependencies for triplet $TARGET_TRIPLET → $DEPS_DIR"
DEPS_DIR="$DEPS_DIR" VCPKG_ROOT="$VCPKG_ROOT" \
  "$PROJECT_ROOT/scripts/build_dependencies.sh" "$TARGET_TRIPLET"

cat <<EOF

Android dependencies ready in $DEPS_DIR.
Pass -DDEPENDENCIES_DIR=$DEPS_DIR when invoking CMake for ABI ${TARGET_TRIPLET}.
EOF
