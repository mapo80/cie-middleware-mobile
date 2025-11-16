#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR"
DEFAULT_DEPS_DIR="$PROJECT_ROOT/Dependencies-ios"
DEPS_DIR="${DEPS_DIR:-$DEFAULT_DEPS_DIR}"
VCPKG_ROOT="${VCPKG_ROOT:-"$PROJECT_ROOT/.vcpkg"}"
TRIPLET="${1:-arm64-ios}"

# Delegate to the generic dependency builder so that the list of packages
# stays in a single script. We simply override the output directory and triplet.
DEPS_DIR="$DEPS_DIR" VCPKG_ROOT="$VCPKG_ROOT" \
  "$PROJECT_ROOT/scripts/build_dependencies.sh" "$TRIPLET"

cat <<EOF

iOS dependencies ready in $DEPS_DIR.
Use -DDEPENDENCIES_DIR=$DEPS_DIR when invoking CMake for iphoneos/iphonesimulator builds.
EOF
