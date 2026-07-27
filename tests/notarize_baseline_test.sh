#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
NOTARIZE="$ROOT/scripts/notarize.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/xcrun" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" >>"$NOTARIZE_COMMAND_LOG"
if [ "$1" = "notarytool" ] && [ "$2" = "submit" ]; then
    exit 1
fi
EOF
chmod +x "$TEMP_DIR/bin/xcrun"

if PATH="$TEMP_DIR/bin:$PATH" NOTARIZE_COMMAND_LOG="$TEMP_DIR/commands.log" \
    bash "$NOTARIZE" --dmg "$TEMP_DIR/SKALA-Attendance-0.1.0-arm64.dmg" >"$TEMP_DIR/output.log" 2>&1; then
    printf 'Expected the missing-DMG invocation to fail.\n' >&2
    exit 1
fi

if ! grep -Fq 'Notarization artifact is missing or invalid.' "$TEMP_DIR/output.log"; then
    printf 'Expected the missing artifact error.\n' >&2
    exit 1
fi

if [ -e "$TEMP_DIR/commands.log" ]; then
    printf 'Missing artifacts must fail before notarytool submit.\n' >&2
    exit 1
fi

printf 'Missing-artifact behavior is covered.\n'
