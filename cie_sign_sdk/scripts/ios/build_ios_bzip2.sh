#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPS_DIR="${DEPS_DIR:-"$ROOT_DIR/Dependencies-ios"}"
VCPKG_ROOT="${VCPKG_ROOT:-"$ROOT_DIR/.vcpkg"}"
TRIPLET="${TRIPLET:-arm64-ios}"
PKG="bzip2"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  "$ROOT_DIR/scripts/bootstrap_vcpkg.sh"
fi

"$VCPKG_ROOT/vcpkg" install "$PKG:$TRIPLET"

SRC_PREFIX="$VCPKG_ROOT/installed/$TRIPLET"
DEST="$DEPS_DIR/$PKG"
mkdir -p "$DEST/include" "$DEST/lib"

if [[ -f "$SRC_PREFIX/include/bzlib.h" ]]; then
  cp "$SRC_PREFIX/include/bzlib.h" "$DEST/include/"
else
  echo "Warning: bzlib.h missing" >&2
fi

cp "$SRC_PREFIX/lib/libbz2.a" "$DEST/lib/"

"$VCPKG_ROOT/vcpkg" list "$PKG:$TRIPLET" | head -n 1
echo "Installed $PKG for $TRIPLET in $DEST"
