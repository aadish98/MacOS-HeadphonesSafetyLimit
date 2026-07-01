#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Building release app and verification target"
swift build -c release --product HeadphoneSafetyVerify
./build_app.sh

echo ""
echo "==> Running verification tests"
.build/release/HeadphoneSafetyVerify

echo ""
echo "==> Validating app bundle"
test -x "HeadphoneSafety.app/Contents/MacOS/HeadphoneSafety"
test -x "HeadphoneSafety.app/Contents/Library/LoginItems/HeadphoneSafetyMonitor.app/Contents/MacOS/HeadphoneSafetyMonitor"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' HeadphoneSafety.app/Contents/Info.plist | grep -q 'com.aadishms.HeadphoneSafetyLimit'
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' HeadphoneSafety.app/Contents/Library/LoginItems/HeadphoneSafetyMonitor.app/Contents/Info.plist | grep -q 'com.aadishms.HeadphoneSafetyLimit.monitor'

echo ""
echo "==> Installing to /Applications"
INSTALL_PATH="/Applications/HeadphoneSafety.app"
if [ -d "$INSTALL_PATH" ]; then
  rm -rf "$INSTALL_PATH"
fi
ditto "HeadphoneSafety.app" "$INSTALL_PATH"

echo "Installed HeadphoneSafety.app to $INSTALL_PATH"
