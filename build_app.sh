#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HeadphoneSafety"
MONITOR_NAME="HeadphoneSafetyMonitor"
BUNDLE_NAME="HeadphoneSafety.app"
MONITOR_BUNDLE_NAME="HeadphoneSafetyMonitor.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"
mkdir -p "$BUNDLE_NAME/Contents/Library/LoginItems/$MONITOR_BUNDLE_NAME/Contents/MacOS"

cp ".build/release/$APP_NAME" "$BUNDLE_NAME/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$BUNDLE_NAME/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
chmod +x "$BUNDLE_NAME/Contents/MacOS/$APP_NAME"

cp ".build/release/$MONITOR_NAME" "$BUNDLE_NAME/Contents/Library/LoginItems/$MONITOR_BUNDLE_NAME/Contents/MacOS/$MONITOR_NAME"
cp "Resources/MonitorInfo.plist" "$BUNDLE_NAME/Contents/Library/LoginItems/$MONITOR_BUNDLE_NAME/Contents/Info.plist"
chmod +x "$BUNDLE_NAME/Contents/Library/LoginItems/$MONITOR_BUNDLE_NAME/Contents/MacOS/$MONITOR_NAME"

echo "Built $BUNDLE_NAME"
echo "Run with: open $BUNDLE_NAME"
echo "Background monitor is bundled at Contents/Library/LoginItems/$MONITOR_BUNDLE_NAME"
