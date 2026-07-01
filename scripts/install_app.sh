#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HeadphoneSafety"
INSTALL_PATH="/Applications/${APP_NAME}.app"
SOURCE_PATH="${ROOT_DIR}/${APP_NAME}.app"

cd "$ROOT_DIR"
./build_app.sh

if [ -d "$INSTALL_PATH" ]; then
  rm -rf "$INSTALL_PATH"
fi

ditto "$SOURCE_PATH" "$INSTALL_PATH"

echo "Installed to $INSTALL_PATH"
