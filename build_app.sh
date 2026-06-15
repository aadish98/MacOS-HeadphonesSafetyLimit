#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HeadphoneSafety"
BUNDLE_NAME="HeadphoneSafety.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

cp ".build/release/$APP_NAME" "$BUNDLE_NAME/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$BUNDLE_NAME/Contents/Info.plist"
chmod +x "$BUNDLE_NAME/Contents/MacOS/$APP_NAME"

echo "Built $BUNDLE_NAME"
echo "Run with: open $BUNDLE_NAME"
