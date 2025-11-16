#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR_IOS="$ROOT_DIR/build/ios-unified/Release-iphoneos"
OUT_DIR_SIM="$ROOT_DIR/build/ios-unified/Release-iphonesimulator"
mkdir -p "$OUT_DIR_IOS" "$OUT_DIR_SIM"

LIBS=(
  libciesign_core.a
  libcie_sign_sdk.a
  libcrypto.a
  libssl.a
  libcurl.a
  libxml2.a
  libz.a
  libpng16.a
  libfreetype.a
  libfontconfig.a
  libpodofo.a
  libpodofo_private.a
  libpodofo_3rdparty.a
  libbz2.a
  libbrotlienc.a
  libbrotlidec.a
  libbrotlicommon.a
  libjpeg.a
  libturbojpeg.a
  libtiff.a
  liblzma.a
  libutf8proc.a
  libexpat.a
  libcryptopp.a
  libiconv.a
  libcharset.a
)

build_bundle() {
  local platform="$1"
  local build_dir deps_dir out_dir
  if [[ "$platform" == "ios" ]]; then
    build_dir="$ROOT_DIR/build/ios/Release-iphoneos"
    deps_dir="$ROOT_DIR/Dependencies-ios"
    out_dir="$OUT_DIR_IOS"
  else
    build_dir="$ROOT_DIR/build/ios-sim/Release-iphonesimulator"
    deps_dir="$ROOT_DIR/Dependencies-ios-sim"
    out_dir="$OUT_DIR_SIM"
  fi

  local inputs=()
  inputs+=("$build_dir/libciesign_core.a")
  inputs+=("$build_dir/libcie_sign_sdk.a")
  inputs+=("$deps_dir/openssl/lib/libcrypto.a")
  inputs+=("$deps_dir/openssl/lib/libssl.a")
  inputs+=("$deps_dir/libcurl/lib/libcurl.a")
  inputs+=("$deps_dir/libxml2/lib/libxml2.a")
  inputs+=("$deps_dir/zlib/lib/libz.a")
  inputs+=("$deps_dir/libpng/lib/libpng16.a")
  inputs+=("$deps_dir/freetype/lib/libfreetype.a")
  inputs+=("$deps_dir/fontconfig/lib/libfontconfig.a")
  inputs+=("$deps_dir/podofo/lib/libpodofo.a")
  inputs+=("$deps_dir/podofo/lib/libpodofo_private.a")
  inputs+=("$deps_dir/podofo/lib/libpodofo_3rdparty.a")
  inputs+=("$deps_dir/bzip2/lib/libbz2.a")
  inputs+=("$deps_dir/brotli/lib/libbrotlienc.a")
  inputs+=("$deps_dir/brotli/lib/libbrotlidec.a")
  inputs+=("$deps_dir/brotli/lib/libbrotlicommon.a")
  inputs+=("$deps_dir/libjpeg/lib/libjpeg.a")
  inputs+=("$deps_dir/libjpeg/lib/libturbojpeg.a")
  inputs+=("$deps_dir/libtiff/lib/libtiff.a")
  inputs+=("$deps_dir/liblzma/lib/liblzma.a")
  inputs+=("$deps_dir/utf8proc/lib/libutf8proc.a")
  inputs+=("$deps_dir/expat/lib/libexpat.a")
  inputs+=("$deps_dir/cryptopp/lib/libcryptopp.a")
  inputs+=("$deps_dir/libiconv/lib/libiconv.a")
  inputs+=("$deps_dir/libiconv/lib/libcharset.a")

  libtool -static -o "$out_dir/libciesign_unified.a" "${inputs[@]}"
}

build_bundle ios
build_bundle sim

echo "Created unified libs under $ROOT_DIR/build/ios-unified"
