#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-"$ROOT_DIR/build/ios"}"
IOS_DEPENDENCIES_DIR="${IOS_DEPENDENCIES_DIR:-"$ROOT_DIR/Dependencies-ios"}"

if [[ ! -d "$IOS_DEPENDENCIES_DIR" ]]; then
  echo "Dependencies directory '$IOS_DEPENDENCIES_DIR' not found. Run the scripts in scripts/ios/ first." >&2
  exit 1
fi

IOS_DEPENDENCIES_DIR="$IOS_DEPENDENCIES_DIR" "$ROOT_DIR/scripts/build_ios.sh"

echo "Built ciesign_core for iOS -> $BUILD_DIR/libciesign_core.a"
