#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPS_DIR="${DEPS_DIR:-"$ROOT_DIR/Dependencies-ios"}"
VCPKG_ROOT="${VCPKG_ROOT:-"$ROOT_DIR/.vcpkg"}"
TRIPLET="${TRIPLET:-arm64-ios}"
PKG="fontconfig"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  "$ROOT_DIR/scripts/bootstrap_vcpkg.sh"
fi

"$VCPKG_ROOT/vcpkg" install "$PKG:$TRIPLET"

SRC_PREFIX="$VCPKG_ROOT/installed/$TRIPLET"
DEST="$DEPS_DIR/$PKG"
mkdir -p "$DEST/include" "$DEST/lib"

if [[ -d "$SRC_PREFIX/include/fontconfig" ]]; then
  rsync -a --delete "$SRC_PREFIX/include/fontconfig/" "$DEST/include/fontconfig/"
else
  echo "Warning: fontconfig headers missing" >&2
fi

cp "$SRC_PREFIX/lib/libfontconfig.a" "$DEST/lib/"

"$VCPKG_ROOT/vcpkg" list "$PKG:$TRIPLET" | head -n 1
echo "Installed $PKG for $TRIPLET in $DEST"
