#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/tests/fixtures/build-dmg-before-task-2.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

APP="$TEMP_DIR/build/Build/Products/Release/SKALA Attendance.app"
mkdir -p "$APP/Contents" "$TEMP_DIR/bin" "$TEMP_DIR/scripts"
cat >"$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>0.1.1</string></dict></plist>
EOF

cat >"$TEMP_DIR/bin/codesign" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$COMMAND_LOG"
EOF
cat >"$TEMP_DIR/bin/hdiutil" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$COMMAND_LOG"
touch "${!#}"
EOF
chmod +x "$TEMP_DIR/bin/codesign" "$TEMP_DIR/bin/hdiutil"
cp "$SCRIPT" "$TEMP_DIR/scripts/build-dmg.sh"

(
    cd "$TEMP_DIR"
    PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/commands.log" bash scripts/build-dmg.sh
)

grep -Fqx -- '--deep --force --options runtime --sign Developer ID Application: DAYEON OH (9XY8538U7T) --timestamp build/Build/Products/Release/SKALA Attendance.app' "$TEMP_DIR/commands.log"
grep -Fqx -- 'create -volname SKALA Attendance -srcfolder release/dmg-staging -ov -format UDZO release/SKALA-Attendance-0.1.1-arm64.dmg' "$TEMP_DIR/commands.log"
[ -f "$TEMP_DIR/release/SKALA-Attendance-0.1.1-arm64.dmg" ]
[ ! -e "$TEMP_DIR/release/SKALA-Attendance-0.1.1-arm64.zip" ]
[ ! -e "$TEMP_DIR/release/dmg-staging" ]

printf 'Baseline DMG packaging behavior is covered.\n'
