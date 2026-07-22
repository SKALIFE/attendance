#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/Build/Products/Release/SKALAAttendance.app}"
STAGING="$ROOT_DIR/release/dmg-staging"
DMG_PATH="$ROOT_DIR/release/SKALA-Attendance-${VERSION}-arm64.dmg"

if [ ! -d "$APP_PATH" ]; then
  printf 'Missing app at %s. Run scripts/build.sh Release first.\n' "$APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create -volname "SKALA Attendance" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
printf '%s\n' "$DMG_PATH"
