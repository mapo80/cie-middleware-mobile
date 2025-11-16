#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-"$ROOT_DIR/build/ios"}"
TOOLCHAIN="$ROOT_DIR/cmake/toolchains/ios-arm64.cmake"
CMAKE_ARGS=()

if [[ -n "${IOS_DEPENDENCIES_DIR:-}" ]]; then
  CMAKE_ARGS+=("-DDEPENDENCIES_DIR=${IOS_DEPENDENCIES_DIR}")
fi

cmake_cmd=(cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN")
if [[ ${#CMAKE_ARGS[@]} -gt 0 ]]; then
  cmake_cmd+=("${CMAKE_ARGS[@]}")
fi
"${cmake_cmd[@]}"

cmake --build "$BUILD_DIR" --target ciesign_core
