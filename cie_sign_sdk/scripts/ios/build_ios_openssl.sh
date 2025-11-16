#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPS_DIR="${DEPS_DIR:-"$ROOT_DIR/Dependencies-ios"}"
VCPKG_ROOT="${VCPKG_ROOT:-"$ROOT_DIR/.vcpkg"}"
TRIPLET="${TRIPLET:-arm64-ios}"
PKG="openssl"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  "$ROOT_DIR/scripts/bootstrap_vcpkg.sh"
fi

"$VCPKG_ROOT/vcpkg" install "$PKG:$TRIPLET"

SRC_PREFIX="$VCPKG_ROOT/installed/$TRIPLET"
DEST="$DEPS_DIR/$PKG"
mkdir -p "$DEST/include" "$DEST/lib"

copy_include() {
  local entry="$1"
  if [[ -d "$SRC_PREFIX/include/$entry" ]]; then
    rsync -a --delete "$SRC_PREFIX/include/$entry/" "$DEST/include/$entry/"
  elif [[ -f "$SRC_PREFIX/include/$entry" ]]; then
    cp "$SRC_PREFIX/include/$entry" "$DEST/include/"
  else
    echo "Warning: missing include $entry for $PKG" >&2
  fi
}

copy_include "openssl"

for lib in libcrypto.a libssl.a; do
  cp "$SRC_PREFIX/lib/$lib" "$DEST/lib/"
done

"$VCPKG_ROOT/vcpkg" list "$PKG:$TRIPLET" | head -n 1
echo "Installed $PKG for $TRIPLET in $DEST"
