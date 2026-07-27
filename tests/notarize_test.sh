#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
NOTARIZE="$ROOT/scripts/notarize.sh"
FIXTURE_INFO_PLIST="$ROOT/tests/fixtures/notarize-0.1.1-Info.plist"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file=$1
    local expected=$2

    grep -Fq "$expected" "$file" || fail "Expected output to contain: $expected"
}

assert_not_contains() {
    local file=$1
    local unexpected=$2

    if grep -Fq "$unexpected" "$file"; then
        fail "Output unexpectedly contained: $unexpected"
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

snapshot_worktree_contents() {
    local worktree=$1
    local snapshot=$2

    GIT_MASTER=1 git -C "$worktree" ls-files -co --exclude-standard -z |
        while IFS= read -r -d '' path; do
            [ -f "$worktree/$path" ] || continue
            shasum -a 256 "$worktree/$path"
        done | sort >"$snapshot"
}

make_app() {
    local app_path=$1
    mkdir -p "$app_path/Contents"
    cp "$FIXTURE_INFO_PLIST" "$app_path/Contents/Info.plist"
}

mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/xcrun" <<'EOF'
#!/bin/bash
set -euo pipefail

{
    printf 'xcrun'
    redact_next=false
    for argument in "$@"; do
        if [ "$redact_next" = true ]; then
            printf ' <temporary-key>'
            redact_next=false
        else
            printf ' <%s>' "$argument"
            [ "$argument" != '--key' ] || redact_next=true
        fi
    done
    printf '\n'
} >>"$NOTARIZE_COMMAND_LOG"

if [ -n "${NOTARIZE_ENV_VIOLATION:-}" ] && [ -n "${APP_STORE_CONNECT_PRIVATE_KEY_BASE64+x}" ]; then
    printf 'Private API-key environment reached xcrun.\n' >"$NOTARIZE_ENV_VIOLATION"
    exit 93
fi

if [ "$1" = "notarytool" ] && [ "$2" = "submit" ]; then
    artifact_path=$3
    [ -f "$artifact_path" ] || exit 90
    case "$artifact_path" in
        *.zip) /usr/bin/unzip -tqq "$artifact_path" >/dev/null || exit 89 ;;
        *.dmg) ;;
        *) exit 88 ;;
    esac
    key_path=
    while [ "$#" -gt 0 ]; do
        if [ "$1" = "--key" ]; then
            key_path=$2
            break
        fi
        shift
    done
    [ -n "$key_path" ] || exit 91
    stat -f '%Lp' "$key_path" >"$NOTARIZE_KEY_MODE"
    printf '%s\n' "$key_path" >"$NOTARIZE_KEY_PATH"
    printf '%s\n' "$artifact_path" >>"$NOTARIZE_SUBMISSION_LOG"
    printf 'Notarization complete!\n'
    exit "${FAKE_NOTARY_EXIT:-0}"
fi

if [ "$1" = "stapler" ] && [ "$2" = "staple" ] && [ -d "$3" ]; then
    mkdir -p "$3/Contents/_CodeSignature"
    : >"$3/Contents/_CodeSignature/stapled-fixture"
fi

if [ "$1" = "stapler" ] && [ "$2" = "validate" ] && [ -d "$3" ]; then
    [ -f "$3/Contents/Info.plist" ] || exit 94
    [ -f "$3/Contents/_CodeSignature/stapled-fixture" ] || exit 95
    if [[ "$3" == *'/skala-notary-zip.'* ]]; then
        printf '%s\n' "$3" >"$NOTARIZE_EXTRACTED_APP_PATH"
    fi
fi
EOF
cat >"$TEMP_DIR/bin/spctl" <<'EOF'
#!/bin/bash
set -euo pipefail
{
    printf 'spctl'
    printf ' <%s>' "$@"
    printf '\n'
} >>"$NOTARIZE_COMMAND_LOG"

artifact=${!#}
if [[ "$artifact" == *.dmg ]]; then
    arguments=" $* "
    [[ "$arguments" == *' --type open '* ]] || exit 96
    [[ "$arguments" == *' --context context:primary-signature '* ]] || exit 97
fi
EOF
cat >"$TEMP_DIR/bin/unzip" <<'EOF'
#!/bin/bash
set -euo pipefail

original_args=("$@")
destination=
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-d" ]; then
        destination=$2
        break
    fi
    shift
done
[ -n "$destination" ] || exit 92
/usr/bin/unzip "${original_args[@]}"
printf 'unzip <verified>\n' >>"$NOTARIZE_COMMAND_LOG"
EOF
cat >"$TEMP_DIR/bin/rm" <<'EOF'
#!/bin/bash
set -euo pipefail

[ "${FAKE_CLEANUP_FAILURE:-0}" != '1' ] || exit 1
exec /bin/rm "$@"
EOF
chmod +x "$TEMP_DIR/bin/xcrun" "$TEMP_DIR/bin/spctl" "$TEMP_DIR/bin/unzip" "$TEMP_DIR/bin/rm"

APP="$TEMP_DIR/SKALA Attendance.app"
DMG="$TEMP_DIR/SKALA-Attendance-0.1.1-arm64.dmg"
STAPLED_ZIP="$TEMP_DIR/SKALA-Attendance-0.1.1-arm64.zip"
MISMATCHED_DMG="$TEMP_DIR/SKALA-Attendance-0.1.2-arm64.dmg"
make_app "$APP"
touch "$DMG" "$MISMATCHED_DMG"
snapshot_worktree_contents "$ROOT" "$TEMP_DIR/target-contents-before.sha256"

MISSING_OUTPUT="$TEMP_DIR/missing-artifact.out"
MISSING_SECRET_MARKER='missing-artifact-secret-marker'
expect_failure "$MISSING_OUTPUT" env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/missing-artifact.commands" \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64="$MISSING_SECRET_MARKER" \
    bash "$NOTARIZE" --app "$TEMP_DIR/$MISSING_SECRET_MARKER.app"
assert_contains "$MISSING_OUTPUT" 'Notarization artifact is missing or invalid.'
assert_not_contains "$MISSING_OUTPUT" "$MISSING_SECRET_MARKER"
[ ! -e "$TEMP_DIR/missing-artifact.commands" ] || fail 'Missing artifacts must fail before external commands.'

MISSING_CREDENTIALS_OUTPUT="$TEMP_DIR/missing-credentials.out"
expect_failure "$MISSING_CREDENTIALS_OUTPUT" env \
    -u APPLE_TEAM_ID \
    -u APP_STORE_CONNECT_ISSUER_ID \
    -u APP_STORE_CONNECT_KEY_ID \
    -u APP_STORE_CONNECT_PRIVATE_KEY_BASE64 \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/missing-credentials.commands" \
    bash "$NOTARIZE" --app "$APP"
assert_contains "$MISSING_CREDENTIALS_OUTPUT" 'APPLE_TEAM_ID is required.'
[ ! -e "$TEMP_DIR/missing-credentials.commands" ] || fail 'Missing credentials must fail before external commands.'

VERSION_MISMATCH_OUTPUT="$TEMP_DIR/version-mismatch.out"
expect_failure "$VERSION_MISMATCH_OUTPUT" env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/version-mismatch.commands" \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
    bash "$NOTARIZE" --app "$APP" --dmg "$MISMATCHED_DMG"
assert_contains "$VERSION_MISMATCH_OUTPUT" 'Artifact versions do not match.'
[ ! -e "$TEMP_DIR/version-mismatch.commands" ] || fail 'Version mismatches must fail before external commands.'

TRACE_SECRET_BASE64='dHJhY2Utc2VjcmV0LW1hcmtlcg=='
XTRACE_OUTPUT="$TEMP_DIR/xtrace.out"
env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/xtrace.commands" \
    NOTARIZE_KEY_PATH="$TEMP_DIR/xtrace-key-path" \
    NOTARIZE_KEY_MODE="$TEMP_DIR/xtrace-key-mode" \
    NOTARIZE_SUBMISSION_LOG="$TEMP_DIR/xtrace-submissions" \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64="$TRACE_SECRET_BASE64" \
    bash -x "$NOTARIZE" --app "$APP" >"$XTRACE_OUTPUT" 2>&1
assert_not_contains "$XTRACE_OUTPUT" "$TRACE_SECRET_BASE64"

run_success_case() {
    local command_log=$1
    local key_path=$2
    local key_mode=$3
    local submission_log=$4
    local environment_violation=$5

    env \
        PATH="$TEMP_DIR/bin:$PATH" \
        NOTARIZE_COMMAND_LOG="$command_log" \
        NOTARIZE_KEY_PATH="$key_path" \
        NOTARIZE_KEY_MODE="$key_mode" \
        NOTARIZE_SUBMISSION_LOG="$submission_log" \
        NOTARIZE_ENV_VIOLATION="$environment_violation" \
        NOTARIZE_EXTRACTED_APP_PATH="$TEMP_DIR/extracted-app-path" \
        NOTARIZE_ZIP_INFO_PLIST="$APP/Contents/Info.plist" \
        APPLE_TEAM_ID='test-team' \
        APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
        APP_STORE_CONNECT_KEY_ID='test-key-id' \
        APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
        bash "$NOTARIZE" --app "$APP"

    (
        cd "$(dirname "$APP")"
        /usr/bin/zip -qr "$STAPLED_ZIP" 'SKALA Attendance.app'
    )
    /usr/bin/unzip -Z1 "$STAPLED_ZIP" | grep -Fx 'SKALA Attendance.app/Contents/_CodeSignature/stapled-fixture' >/dev/null || fail 'Final ZIP must contain the stapled app fixture path.'

    env \
        PATH="$TEMP_DIR/bin:$PATH" \
        NOTARIZE_COMMAND_LOG="$command_log" \
        NOTARIZE_KEY_PATH="$key_path" \
        NOTARIZE_KEY_MODE="$key_mode" \
        NOTARIZE_SUBMISSION_LOG="$submission_log" \
        NOTARIZE_ENV_VIOLATION="$environment_violation" \
        NOTARIZE_EXTRACTED_APP_PATH="$TEMP_DIR/extracted-app-path" \
        NOTARIZE_ZIP_INFO_PLIST="$APP/Contents/Info.plist" \
        APPLE_TEAM_ID='test-team' \
        APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
        APP_STORE_CONNECT_KEY_ID='test-key-id' \
        APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
        bash "$NOTARIZE" --dmg "$DMG" --zip "$STAPLED_ZIP"
}

SUCCESS_OUTPUT="$TEMP_DIR/success.out"
if ! run_success_case "$TEMP_DIR/success.commands" "$TEMP_DIR/key-path" "$TEMP_DIR/key-mode" "$TEMP_DIR/success-submissions" "$TEMP_DIR/success-environment-violation" >"$SUCCESS_OUTPUT" 2>&1; then
    cat "$SUCCESS_OUTPUT" >&2
    fail 'Expected headless notarization fixture success.'
fi
assert_contains "$TEMP_DIR/success.commands" "<submit> <$DMG>"
assert_contains "$TEMP_DIR/success.commands" '<stapler> <validate>'
assert_contains "$TEMP_DIR/success.commands" 'spctl <--assess> <--verbose=4>'
assert_contains "$TEMP_DIR/success.commands" "spctl <--assess> <--type> <open> <--context> <context:primary-signature> <--verbose=4> <$DMG>"
[ "$(cat "$TEMP_DIR/key-mode")" = '600' ] || fail 'The temporary API-key file must be mode 600.'
[ ! -e "$(cat "$TEMP_DIR/key-path")" ] || fail 'The temporary API-key file was not deleted.'
[ ! -e "$TEMP_DIR/success-environment-violation" ] || fail 'The private API-key environment reached a child tool.'
assert_not_contains "$TEMP_DIR/success-submissions" "$APP"
assert_contains "$TEMP_DIR/success-submissions" "$DMG"
[ -n "$(cat "$TEMP_DIR/extracted-app-path")" ] || fail 'The actual ZIP app was not validated.'
assert_not_contains "$SUCCESS_OUTPUT" 'PRIVATE KEY'

ZIP_ONLY_OUTPUT="$TEMP_DIR/zip-only.out"
if ! env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/zip-only.commands" \
    NOTARIZE_KEY_PATH="$TEMP_DIR/zip-only-key-path" \
    NOTARIZE_KEY_MODE="$TEMP_DIR/zip-only-key-mode" \
    NOTARIZE_SUBMISSION_LOG="$TEMP_DIR/zip-only-submissions" \
    NOTARIZE_ENV_VIOLATION="$TEMP_DIR/zip-only-environment-violation" \
    NOTARIZE_EXTRACTED_APP_PATH="$TEMP_DIR/zip-only-extracted-app" \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
        bash "$NOTARIZE" --zip "$STAPLED_ZIP" >"$ZIP_ONLY_OUTPUT" 2>&1; then
    cat "$ZIP_ONLY_OUTPUT" >&2
    fail 'Expected rebuilt ZIP validation success without a notarization submission.'
fi
assert_not_contains "$TEMP_DIR/zip-only.commands" '<notarytool> <submit>'
assert_contains "$TEMP_DIR/zip-only.commands" '<stapler> <validate>'
assert_contains "$TEMP_DIR/zip-only.commands" 'spctl <--assess> <--verbose=4>'

SECOND_SUCCESS_OUTPUT="$TEMP_DIR/second-success.out"
if ! run_success_case "$TEMP_DIR/second-success.commands" "$TEMP_DIR/second-key-path" "$TEMP_DIR/second-key-mode" "$TEMP_DIR/second-success-submissions" "$TEMP_DIR/second-success-environment-violation" >"$SECOND_SUCCESS_OUTPUT" 2>&1; then
    cat "$SECOND_SUCCESS_OUTPUT" >&2
    fail 'Expected repeated headless notarization fixture success.'
fi
[ "$(grep -c '<notarytool> <submit>' "$TEMP_DIR/success.commands")" = '2' ] || fail 'The first invocation did not notarize both artifacts.'
[ "$(grep -c '<notarytool> <submit>' "$TEMP_DIR/second-success.commands")" = '2' ] || fail 'The repeated invocation did not notarize both artifacts.'
[ "$(grep -c '<stapler> <validate>' "$TEMP_DIR/success.commands")" = '3' ] || fail 'The first invocation did not validate each notarized form.'
[ "$(grep -c '<stapler> <validate>' "$TEMP_DIR/second-success.commands")" = '3' ] || fail 'The repeated invocation did not validate each notarized form.'

MISLEADING_OUTPUT="$TEMP_DIR/misleading-success.out"
expect_failure "$MISLEADING_OUTPUT" env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/misleading-success.commands" \
    NOTARIZE_KEY_PATH="$TEMP_DIR/misleading-key-path" \
    NOTARIZE_KEY_MODE="$TEMP_DIR/misleading-key-mode" \
    NOTARIZE_SUBMISSION_LOG="$TEMP_DIR/misleading-submissions" \
    FAKE_NOTARY_EXIT=1 \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
    bash "$NOTARIZE" --app "$APP"
assert_contains "$MISLEADING_OUTPUT" 'Notarization submission failed.'
assert_not_contains "$MISLEADING_OUTPUT" 'Notarization complete!'
assert_not_contains "$TEMP_DIR/misleading-success.commands" '<stapler> <staple>'
[ ! -e "$(cat "$TEMP_DIR/misleading-key-path")" ] || fail 'The API-key file survived a failed submission.'

INVALID_ZIP="$TEMP_DIR/invalid/SKALA-Attendance-0.1.1-arm64.zip"
mkdir -p "$TEMP_DIR/invalid" "$TEMP_DIR/invalid-source"
printf 'not an app\n' >"$TEMP_DIR/invalid-source/not-an-app.txt"
(
    cd "$TEMP_DIR/invalid-source"
    /usr/bin/zip -q "$INVALID_ZIP" not-an-app.txt
)
INVALID_ZIP_OUTPUT="$TEMP_DIR/invalid-zip.out"
expect_failure "$INVALID_ZIP_OUTPUT" env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/invalid-zip.commands" \
    NOTARIZE_KEY_PATH="$TEMP_DIR/invalid-zip-key-path" \
    NOTARIZE_KEY_MODE="$TEMP_DIR/invalid-zip-key-mode" \
    NOTARIZE_SUBMISSION_LOG="$TEMP_DIR/invalid-zip-submissions" \
    NOTARIZE_ENV_VIOLATION="$TEMP_DIR/invalid-zip-environment-violation" \
    NOTARIZE_EXTRACTED_APP_PATH="$TEMP_DIR/invalid-zip-extracted-app" \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
    bash "$NOTARIZE" --dmg "$DMG" --zip "$INVALID_ZIP"
assert_contains "$INVALID_ZIP_OUTPUT" 'Notarization artifact is missing or invalid.'
[ ! -e "$TEMP_DIR/invalid-zip-extracted-app" ] || fail 'Invalid ZIP content reached stapler validation.'

CLEANUP_FAILURE_OUTPUT="$TEMP_DIR/cleanup-failure.out"
expect_failure "$CLEANUP_FAILURE_OUTPUT" env \
    PATH="$TEMP_DIR/bin:$PATH" \
    NOTARIZE_COMMAND_LOG="$TEMP_DIR/cleanup-failure.commands" \
    NOTARIZE_KEY_PATH="$TEMP_DIR/cleanup-failure-key-path" \
    NOTARIZE_KEY_MODE="$TEMP_DIR/cleanup-failure-key-mode" \
    NOTARIZE_SUBMISSION_LOG="$TEMP_DIR/cleanup-failure-submissions" \
    FAKE_CLEANUP_FAILURE=1 \
    APPLE_TEAM_ID='test-team' \
    APP_STORE_CONNECT_ISSUER_ID='test-issuer' \
    APP_STORE_CONNECT_KEY_ID='test-key-id' \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64='LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t' \
    bash "$NOTARIZE" --app "$APP"
assert_contains "$CLEANUP_FAILURE_OUTPUT" 'Temporary credential cleanup failed.'
assert_not_contains "$CLEANUP_FAILURE_OUTPUT" 'Notarization completed.'

snapshot_worktree_contents "$ROOT" "$TEMP_DIR/target-contents-after.sha256"
cmp -s "$TEMP_DIR/target-contents-before.sha256" "$TEMP_DIR/target-contents-after.sha256" || fail 'Notarization tests modified target worktree content.'

printf 'Headless notarization tests passed.\n'
