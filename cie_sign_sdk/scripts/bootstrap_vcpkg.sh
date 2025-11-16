#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VCPKG_ROOT="${VCPKG_ROOT:-"$ROOT_DIR/.vcpkg"}"

if [[ -d "$VCPKG_ROOT" ]]; then
  echo "vcpkg already available at $VCPKG_ROOT"
  exit 0
fi

git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"

UNAME="$(uname -s)"
if [[ "$UNAME" == "Darwin" || "$UNAME" == "Linux" ]]; then
  "$VCPKG_ROOT/bootstrap-vcpkg.sh"
else
  if command -v cygpath >/dev/null 2>&1; then
    WIN_VCPKG_ROOT="$(cygpath -w "$VCPKG_ROOT")"
  else
    WIN_VCPKG_ROOT="$VCPKG_ROOT"
  fi
  cmd.exe /C "${WIN_VCPKG_ROOT}\\bootstrap-vcpkg.bat"
fi

echo "vcpkg bootstrap completed in $VCPKG_ROOT"
