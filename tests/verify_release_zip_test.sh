#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERIFIER="$ROOT/scripts/verify-release-zip.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

expect_failure() {
    local output=$1
    shift

    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected a failing exit status.'
    fi
}

SOURCE_DIR="$TEMP_DIR/source/SKALA Attendance.app/Contents/MacOS"
mkdir -p "$SOURCE_DIR"
printf 'release ZIP fixture\n' >"$SOURCE_DIR/SKALAAttendance"
ARCHIVE="$TEMP_DIR/SKALA-Attendance-0.1.1-arm64.zip"
(cd "$TEMP_DIR/source" && /usr/bin/zip -qry "$ARCHIVE" 'SKALA Attendance.app')
ARCHIVE_SIZE=$(stat -f '%z' "$ARCHIVE")
ARCHIVE_SHA256=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
ARCHIVE_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip'
CURL_MOCK="$TEMP_DIR/curl"

cat >"$CURL_MOCK" <<'EOF'
#!/bin/bash
set -euo pipefail
[ -z "${APPCAST_REPO_TOKEN+x}" ] || exit 71
[ -z "${LEAK_MARKER+x}" ] || exit 72
[ "$1" = --fail ] && [ "$2" = --location ] && [ "$3" = --silent ] && [ "$4" = --show-error ] && [ "$5" = --output ] || exit 73
[ "$7" = "$EXPECTED_URL" ] || exit 74
cp "$MOCK_ARCHIVE" "$6"
EOF
chmod +x "$CURL_MOCK"

run_verifier() {
    env APPCAST_REPO_TOKEN='offline-token-must-not-leak' LEAK_MARKER='must-not-reach-curl' \
        EXPECTED_URL="$ARCHIVE_URL" MOCK_ARCHIVE="$ARCHIVE" CURL_BIN="$CURL_MOCK" TMPDIR="$TEMP_DIR" \
        bash "$VERIFIER" "$ARCHIVE_URL" "$ARCHIVE_SIZE" "$ARCHIVE_SHA256"
}

run_verifier

expect_failure "$TEMP_DIR/bad-size.out" env EXPECTED_URL="$ARCHIVE_URL" MOCK_ARCHIVE="$ARCHIVE" CURL_BIN="$CURL_MOCK" \
    bash "$VERIFIER" "$ARCHIVE_URL" 1 "$ARCHIVE_SHA256"
expect_failure "$TEMP_DIR/bad-digest.out" env EXPECTED_URL="$ARCHIVE_URL" MOCK_ARCHIVE="$ARCHIVE" CURL_BIN="$CURL_MOCK" \
    bash "$VERIFIER" "$ARCHIVE_URL" "$ARCHIVE_SIZE" 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'

if compgen -G "$TEMP_DIR/release-zip.*" >/dev/null; then
    fail 'Release ZIP verifier left a downloaded archive behind.'
fi

printf 'Release ZIP download verification tests passed.\n'
