#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GENERATOR="$ROOT/scripts/generate-appcast-item.sh"
FIXTURES="$ROOT/tests/fixtures"
PROJECT="$ROOT/project.yml"

OPENSSL_CANDIDATES=()
[ -n "${OPENSSL_BIN:-}" ] && OPENSSL_CANDIDATES+=("$OPENSSL_BIN")
OPENSSL_CANDIDATES+=(
    "$(command -v openssl || true)"
    /opt/homebrew/opt/openssl@3/bin/openssl
    /usr/local/opt/openssl@3/bin/openssl
)
OPENSSL=''
for candidate in "${OPENSSL_CANDIDATES[@]}"; do
    [ -x "$candidate" ] || continue
    if "$candidate" list -public-key-algorithms 2>/dev/null | grep -Fq ED25519 \
        && "$candidate" pkeyutl -help 2>&1 | grep -Fq -- '-rawin'; then
        OPENSSL="$candidate"
        break
    fi
done
[ -n "$OPENSSL" ] || {
    printf '%s\n' 'No executable OpenSSL with Ed25519 and pkeyutl -rawin support was found.' >&2
    exit 1
}
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "Expected $1 to contain: $2"
}

assert_not_contains() {
    if grep -Fq -- "$2" "$1"; then
        fail "Expected $1 not to contain: $2"
    fi
}

expect_failure() {
    local output=$1
    shift
    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected a failing exit status.'
    fi
}

assert_unchanged() {
    cmp -s "$1" "$2" || fail 'Invalid input mutated the appcast.'
}

make_archive() {
    local archive=$1
    local source="$TEMP_DIR/archive-source"

    rm -rf "$source"
    mkdir -p "$source/SKALA Attendance.app/Contents/MacOS"
    printf 'fixture executable\n' >"$source/SKALA Attendance.app/Contents/MacOS/SKALAAttendance"
    (cd "$source" && /usr/bin/zip -qry "$archive" 'SKALA Attendance.app')
}

make_test_project() {
    local destination=${1:-$TEST_PROJECT}
    local public_key=${2:-$TEST_PUBLIC_KEY}

    awk -v public_key="$public_key" '
        /^[[:space:]]*SUPublicEDKey:[[:space:]]*/ {
            sub(/:.*/, ": " public_key)
        }
        { print }
    ' "$PROJECT" >"$destination"
}

make_signer() {
    local signing_status=${1:-0}
    local signing_mutate=${2:-false}
    local verification_status=${3:-0}
    local verification_mutate=${4:-false}

    cat >"$TOOLS_BIN/sign_update" <<EOF
#!/bin/bash
set -euo pipefail
printf 'sign_update' >>"$TOOL_LOG"
printf ' <%s>' "\$@" >>"$TOOL_LOG"
printf '\\n' >>"$TOOL_LOG"
[ -z "\${SPARKLE_EDDSA_PRIVATE_KEY+x}" ] || exit 91
[ -z "\${LEAK_MARKER+x}" ] || exit 92
mode=sign
if [ "\$1" = --verify ]; then
    mode=verify
    shift
fi
[ "\$1" = --ed-key-file ] && [ "\$2" = - ] || exit 93
shift 2
private_key_path=\$(cat)
[ "\$private_key_path" = '$TEST_PRIVATE_KEY' ] || exit 94
[ -f "\$1" ] || exit 95
archive=\$1
if [ "\$mode" = sign ]; then
    if [ "$signing_mutate" = true ]; then
        printf 'tampered by signer\\n' >>"\$archive"
    fi
    signature=\$("$OPENSSL" pkeyutl -sign -rawin -inkey '$TEST_PRIVATE_DER' -in "\$archive" | "$OPENSSL" base64 -A)
    printf 'sparkle:edSignature="%s" length="%s"\\n' "\$signature" "\$(stat -f '%z' "\$archive")"
    exit $signing_status
fi
signature_file=\$(mktemp)
trap 'rm -f "\$signature_file"' EXIT
printf '%s' "\$2" | "$OPENSSL" base64 -d -A >"\$signature_file"
"$OPENSSL" pkeyutl -verify -rawin -pubin -inkey '$TEST_PUBLIC_PEM' -in "\$archive" -sigfile "\$signature_file" >/dev/null
if [ "$verification_mutate" = true ]; then
    printf 'tampered by verifier\\n' >>"\$archive"
fi
exit $verification_status
EOF
    chmod +x "$TOOLS_BIN/sign_update"
}

make_release_probe() {
    local status=${1:-0}

    cat >"$PROBE" <<EOF
#!/bin/bash
set -euo pipefail
[ "\$#" = 3 ] || exit 71
[ "\$1" = '$ARCHIVE_URL' ] || exit 72
[ "\$2" = '$ARCHIVE_SIZE' ] || exit 73
[ "\$3" = '$ARCHIVE_DIGEST' ] || exit 74
[ -z "\${SPARKLE_EDDSA_PRIVATE_KEY+x}" ] || exit 75
[ -z "\${LEAK_MARKER+x}" ] || exit 76
exit $status
EOF
    chmod +x "$PROBE"
}

run_generator() {
    env LEAK_MARKER='must-not-reach-tools' OPENSSL_BIN="$OPENSSL" SPARKLE_EDDSA_PRIVATE_KEY="$TEST_PRIVATE_KEY" TOOL_LOG="$TOOL_LOG" \
        bash "$GENERATOR" \
        --tag v0.1.1 --build 2 --archive "$ARCHIVE" --archive-sha256 "$ARCHIVE_DIGEST" \
        --archive-url "$ARCHIVE_URL" --appcast "$APPCAST" --project "$TEST_PROJECT" \
        --sparkle-tools-root "$TOOLS_ROOT" --release-probe "$PROBE" "$@"
}

TEST_PRIVATE_KEY=$("$OPENSSL" rand -base64 32)
TEST_PRIVATE_DER="$TEMP_DIR/disposable-ed25519-private.der"
TEST_PUBLIC_PEM="$TEMP_DIR/disposable-ed25519-public.pem"
printf '\060\056\002\001\000\060\005\006\003\053\145\160\004\042\004\040' >"$TEST_PRIVATE_DER"
printf '%s' "$TEST_PRIVATE_KEY" | base64 -D >>"$TEST_PRIVATE_DER"
"$OPENSSL" pkey -inform DER -in "$TEST_PRIVATE_DER" -pubout -out "$TEST_PUBLIC_PEM"
TEST_PUBLIC_KEY=$("$OPENSSL" pkey -pubin -in "$TEST_PUBLIC_PEM" -pubout -outform DER | dd bs=1 skip=12 2>/dev/null | "$OPENSSL" base64 -A)

TEST_PROJECT="$TEMP_DIR/project.yml"
make_test_project
APPCAST="$TEMP_DIR/appcast.xml"
cp "$FIXTURES/current-appcast.xml" "$APPCAST"
ARCHIVE="$TEMP_DIR/SKALA-Attendance-0.1.1-arm64.zip"
make_archive "$ARCHIVE"
ARCHIVE_SIZE=$(stat -f '%z' "$ARCHIVE")
ARCHIVE_DIGEST=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
ARCHIVE_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip'
TOOLS_ROOT="$TEMP_DIR/sparkle-tools"
TOOLS_BIN="$TOOLS_ROOT/bin"
mkdir -p "$TOOLS_BIN"
TOOL_LOG="$TEMP_DIR/sign-update.log"
PROBE="$TEMP_DIR/release_probe"
make_signer
make_release_probe

BASELINE_BEFORE="$TEMP_DIR/baseline-before.xml"
cp "$APPCAST" "$BASELINE_BEFORE"
VALID_OUTPUT="$TEMP_DIR/valid.xml"
run_generator >"$VALID_OUTPUT"
xmllint --noout "$VALID_OUTPUT"
SIGNATURE=$(awk -F 'sparkle:edSignature="' 'NF > 1 { split($2, value, "\""); print value[1] }' "$VALID_OUTPUT")
assert_contains "$VALID_OUTPUT" "sparkle:edSignature=\"$SIGNATURE\""
assert_contains "$VALID_OUTPUT" "url=\"$ARCHIVE_URL\""
assert_contains "$TOOL_LOG" "<--ed-key-file> <-> <$ARCHIVE>"
assert_contains "$TOOL_LOG" "<--verify> <--ed-key-file> <-> <$ARCHIVE> <$SIGNATURE>"
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"
[ -z "${APPCAST_ITEM_MANUAL_QA:-}" ] || cp "$VALID_OUTPUT" "$APPCAST_ITEM_MANUAL_QA"
[ -z "${APPCAST_ITEM_MANUAL_QA_DIGEST:-}" ] || printf '%s  %s\n' "$ARCHIVE_DIGEST" "$(basename "$ARCHIVE")" >"$APPCAST_ITEM_MANUAL_QA_DIGEST"
[ -z "${APPCAST_ITEM_MANUAL_QA_PUBLIC_KEY:-}" ] || cp "$TEST_PUBLIC_PEM" "$APPCAST_ITEM_MANUAL_QA_PUBLIC_KEY"

MISMATCHED_PROJECT="$TEMP_DIR/mismatched-project.yml"
MISMATCHED_PUBLIC_KEY=$("$OPENSSL" rand -base64 32)
[ "$MISMATCHED_PUBLIC_KEY" != "$TEST_PUBLIC_KEY" ] || fail 'Unable to construct a mismatched Sparkle public key fixture.'
make_test_project "$MISMATCHED_PROJECT" "$MISMATCHED_PUBLIC_KEY"
MISMATCHED_KEY_OUTPUT="$TEMP_DIR/mismatched-key.out"
expect_failure "$MISMATCHED_KEY_OUTPUT" run_generator --project "$MISMATCHED_PROJECT"
assert_contains "$MISMATCHED_KEY_OUTPUT" 'Signing key does not match project SUPublicEDKey.'

MISSING_KEY_OUTPUT="$TEMP_DIR/missing-key.out"
expect_failure "$MISSING_KEY_OUTPUT" env -u SPARKLE_EDDSA_PRIVATE_KEY \
    bash "$GENERATOR" \
    --tag v0.1.1 --build 2 --archive "$ARCHIVE" --archive-sha256 "$ARCHIVE_DIGEST" \
    --archive-url "$ARCHIVE_URL" --appcast "$APPCAST" --project "$TEST_PROJECT" \
    --sparkle-tools-root "$TOOLS_ROOT" --release-probe "$PROBE"
assert_contains "$MISSING_KEY_OUTPUT" 'SPARKLE_EDDSA_PRIVATE_KEY is required for Sparkle signing.'

UNPINNED_OUTPUT="$TEMP_DIR/unpinned-tool.out"
expect_failure "$UNPINNED_OUTPUT" run_generator --sparkle-sign-update "$TOOLS_BIN/sign_update"
assert_contains "$UNPINNED_OUTPUT" 'Usage:'

DUPLICATE_BUILD_OUTPUT="$TEMP_DIR/duplicate-build.out"
expect_failure "$DUPLICATE_BUILD_OUTPUT" run_generator --build 1
assert_contains "$DUPLICATE_BUILD_OUTPUT" 'Build 1 must be greater than current appcast build 1.'
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"

RAW_MAIN_OUTPUT="$TEMP_DIR/raw-main.out"
expect_failure "$RAW_MAIN_OUTPUT" run_generator \
    --archive-url 'https://raw.githubusercontent.com/SKALIFE/attendance/main/SKALA-Attendance-0.1.1-arm64.zip'
assert_contains "$RAW_MAIN_OUTPUT" 'Archive URL must be the immutable GitHub Release asset URL for v0.1.1.'
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"

MALFORMED_APPCAST="$TEMP_DIR/malformed-appcast.xml"
cp "$APPCAST" "$MALFORMED_APPCAST"
printf '<broken' >>"$MALFORMED_APPCAST"
MALFORMED_XML_OUTPUT="$TEMP_DIR/malformed-xml.out"
expect_failure "$MALFORMED_XML_OUTPUT" run_generator --appcast "$MALFORMED_APPCAST"
assert_contains "$MALFORMED_XML_OUTPUT" 'Appcast XML is not well-formed.'
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"

mkdir -p "$TEMP_DIR/invalid"
INVALID_ZIP="$TEMP_DIR/invalid/SKALA-Attendance-0.1.1-arm64.zip"
printf 'not a zip\n' >"$INVALID_ZIP"
INVALID_ZIP_OUTPUT="$TEMP_DIR/invalid-zip.out"
expect_failure "$INVALID_ZIP_OUTPUT" env SPARKLE_EDDSA_PRIVATE_KEY="$TEST_PRIVATE_KEY" \
    bash "$GENERATOR" \
    --tag v0.1.1 --build 2 --archive "$INVALID_ZIP" --archive-sha256 "$(shasum -a 256 "$INVALID_ZIP" | awk '{print $1}')" \
    --archive-url "$ARCHIVE_URL" --appcast "$APPCAST" --project "$TEST_PROJECT" \
    --sparkle-tools-root "$TOOLS_ROOT" --release-probe "$PROBE"
assert_contains "$INVALID_ZIP_OUTPUT" 'Archive ZIP integrity validation failed.'
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"

BAD_DIGEST='0000000000000000000000000000000000000000000000000000000000000000'
[ "$BAD_DIGEST" != "$ARCHIVE_DIGEST" ] || BAD_DIGEST='1111111111111111111111111111111111111111111111111111111111111111'
BAD_DIGEST_OUTPUT="$TEMP_DIR/bad-digest.out"
expect_failure "$BAD_DIGEST_OUTPUT" run_generator --archive-sha256 "$BAD_DIGEST"
assert_contains "$BAD_DIGEST_OUTPUT" 'Archive SHA-256 does not match the expected release asset digest.'
assert_unchanged "$BASELINE_BEFORE" "$APPCAST"

MISSING_TOOLS_OUTPUT="$TEMP_DIR/missing-tools.out"
mkdir -p "$TEMP_DIR/missing-tools"
expect_failure "$MISSING_TOOLS_OUTPUT" run_generator --sparkle-tools-root "$TEMP_DIR/missing-tools"
assert_contains "$MISSING_TOOLS_OUTPUT" 'Pinned Sparkle sign_update is missing or not executable.'

MUTATING_SIGNER_OUTPUT="$TEMP_DIR/mutating-signer.out"
ARCHIVE_BEFORE="$TEMP_DIR/archive-before.zip"
cp "$ARCHIVE" "$ARCHIVE_BEFORE"
make_signer 77 true
expect_failure "$MUTATING_SIGNER_OUTPUT" run_generator
assert_contains "$MUTATING_SIGNER_OUTPUT" 'Sparkle sign_update failed.'
assert_unchanged "$ARCHIVE_BEFORE" "$ARCHIVE"
make_signer

MUTATING_VERIFIER_OUTPUT="$TEMP_DIR/mutating-verifier.out"
make_signer 0 false 0 true
expect_failure "$MUTATING_VERIFIER_OUTPUT" run_generator
assert_contains "$MUTATING_VERIFIER_OUTPUT" 'Archive changed while it was being signed.'
assert_unchanged "$ARCHIVE_BEFORE" "$ARCHIVE"
make_signer

BAD_SIGNATURE_OUTPUT="$TEMP_DIR/bad-signature.out"
cp "$TOOLS_BIN/sign_update" "$TOOLS_BIN/sign_update.good"
cat >"$TOOLS_BIN/sign_update" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'sparkle:edSignature="BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB==" length="1"\n'
EOF
chmod +x "$TOOLS_BIN/sign_update"
expect_failure "$BAD_SIGNATURE_OUTPUT" run_generator
assert_contains "$BAD_SIGNATURE_OUTPUT" 'Sparkle sign_update length does not match archive size.'
mv "$TOOLS_BIN/sign_update.good" "$TOOLS_BIN/sign_update"

printf 'Appcast item generation tests passed.\n'
