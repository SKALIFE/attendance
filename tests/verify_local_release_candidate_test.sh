#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROBE="$ROOT/scripts/verify-local-release-candidate.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

expect_failure() {
    if "$@" >"$TEMP_DIR/output" 2>&1; then
        fail 'Expected candidate probe failure.'
    fi
}

"$PROBE" \
    'https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip' \
    123 \
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'

expect_failure "$PROBE" \
    'https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.2-arm64.zip' \
    123 \
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
expect_failure "$PROBE" \
    'https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip' \
    123 \
    invalid
expect_failure "$PROBE" \
    'https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip' \
    invalid \
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'

printf 'Local release candidate probe tests passed.\n'
