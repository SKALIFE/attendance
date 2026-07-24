#!/bin/bash
set -euo pipefail

APP_PATH="build/Build/Products/Release/SKALA Attendance.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_DIR="release"
DMG_PATH="$DMG_DIR/SKALA-Attendance-${VERSION}-arm64.dmg"
STAGING="$DMG_DIR/dmg-staging"

echo "Building DMG for version $VERSION..."

mkdir -p "$DMG_DIR"
rm -rf "$STAGING"
mkdir -p "$STAGING"

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "SKALA Attendance" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"
echo ""
echo "Created: $DMG_PATH"
echo "Mount it: open $DMG_PATH"
