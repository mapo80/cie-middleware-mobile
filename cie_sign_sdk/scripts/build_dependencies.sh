#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR"
DEPS_DIR="${DEPS_DIR:-$PROJECT_ROOT/Dependencies}"
VCPKG_ROOT="${VCPKG_ROOT:-"$PROJECT_ROOT/.vcpkg"}"
TRIPLET="${1:-x64-osx}"

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  echo "vcpkg not found. Run scripts/bootstrap_vcpkg.sh first." >&2
  exit 1
fi

mkdir -p "$DEPS_DIR"

DEPS=(
  openssl
  curl
  libxml2
  zlib
  libpng
  freetype
  fontconfig
  podofo
  bzip2
  cryptopp
  libiconv
)

echo "Installing dependencies for triplet $TRIPLET"
"$VCPKG_ROOT/vcpkg" install "${DEPS[@]/%/:$TRIPLET}"

SRC_PREFIX="$VCPKG_ROOT/installed/$TRIPLET"

copy_dep() {
  local dep="$1"
  local include_paths="$2"
  local libs="$3"
  local dest="$DEPS_DIR/$dep"

  mkdir -p "$dest/include" "$dest/lib"

  for inc in $include_paths; do
    if [[ -d "$SRC_PREFIX/include/$inc" ]]; then
      rsync -a --delete "$SRC_PREFIX/include/$inc/" "$dest/include/$inc/"
    elif [[ -f "$SRC_PREFIX/include/$inc" ]]; then
      mkdir -p "$dest/include"
      cp "$SRC_PREFIX/include/$inc" "$dest/include/"
    else
      echo "Warning: include path $inc not found for $dep" >&2
    fi
  done

  for lib in $libs; do
    local src="$SRC_PREFIX/lib/$lib"
    if [[ -f "$src" ]]; then
      cp "$src" "$dest/lib/"
    else
      echo "Warning: library $lib not found for $dep" >&2
    fi
  done
}

copy_dep openssl "openssl" "libcrypto.a libssl.a"
copy_dep libcurl "curl" "libcurl.a"
copy_dep libxml2 "libxml2" "libxml2.a"
copy_dep zlib "zlib.h zconf.h" "libz.a"
copy_dep libpng "png.h pngconf.h libpng16" "libpng16.a"
copy_dep freetype "freetype2" "libfreetype.a"
copy_dep fontconfig "fontconfig" "libfontconfig.a"
copy_dep podofo "podofo" "libpodofo.a libpodofo_private.a libpodofo_3rdparty.a"
copy_dep bzip2 "bzlib.h" "libbz2.a"
copy_dep cryptopp "cryptopp" "libcryptopp.a"
copy_dep brotli "brotli" "libbrotlicommon.a libbrotlidec.a libbrotlienc.a"
copy_dep libjpeg "jconfig.h jerror.h jmorecfg.h jpeglib.h turbojpeg.h" "libjpeg.a libturbojpeg.a"
copy_dep libtiff "tiff.h tiffio.h tiffvers.h tiffconf.h" "libtiff.a"
copy_dep liblzma "lzma" "liblzma.a"
copy_dep utf8proc "utf8proc.h" "libutf8proc.a"
copy_dep expat "expat.h expat_config.h expat_external.h" "libexpat.a"
copy_dep libiconv "iconv.h libcharset.h localcharset.h" "libiconv.a libcharset.a"

echo "Dependencies copied to $DEPS_DIR"
