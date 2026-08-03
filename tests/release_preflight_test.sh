#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFLIGHT_SOURCE="$ROOT/scripts/release/preflight.sh"
PREFLIGHT="$PREFLIGHT_SOURCE"
DOCUMENTATION="$ROOT/docs/runbooks/release.md"
UNRELEASED="$ROOT/docs/releases/unreleased.md"
FIXTURES="$ROOT/tests/fixtures"
OPENSSL=$(command -v openssl)
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

expect_success() {
    local output=$1
    shift

    if ! "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected preflight success.'
    fi
}

expect_failure() {
    local output=$1
    shift

    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected preflight failure.'
    fi
    assert_not_contains "$output" 'Release preflight passed.'
}

require_documentation() {
    [ -f "$DOCUMENTATION" ] || fail 'Release operator documentation is missing.'

    for text in \
        '# Release operator runbook' \
        'Release authorization' \
        'explicit maintainer request' \
        'Approval cannot be granted' \
        'Unreleased change record' \
        'docs/releases/unreleased.md' \
        'Version and build policy' \
        'DEVELOPER_ID_APPLICATION_P12_BASE64' \
        'DEVELOPER_ID_APPLICATION_P12_PASSWORD' \
        'APPLE_TEAM_ID' \
        'APP_STORE_CONNECT_ISSUER_ID' \
        'APP_STORE_CONNECT_KEY_ID' \
        'APP_STORE_CONNECT_PRIVATE_KEY_BASE64' \
        'SPARKLE_EDDSA_PRIVATE_KEY' \
        'APPCAST_REPO_TOKEN' \
        'least privilege' \
        'Protected `appcast-publish` environment' \
        'environment: appcast-publish' \
        'required reviewers' \
        'single-operator exception' \
        'Do not create a second account' \
        'MARKETING_VERSION' \
        'CURRENT_PROJECT_VERSION' \
        'git add -- project.yml docs/releases/unreleased.md docs/releases/0.1.12.md' \
        'git diff --cached --check' \
        'git commit' \
        'origin/main' \
        'git tag -a' \
        'git push origin refs/tags/' \
        'checksums.txt' \
        'Publication approval gate' \
        'second approval' \
        'Rollback before feed publication' \
        'CI GUI boundary' \
        'scripts/release/preflight.sh v0.1.11'; do
        assert_contains "$DOCUMENTATION" "$text"
    done

    [ -f "$UNRELEASED" ] || fail 'Unreleased change record is missing.'
    assert_contains "$UNRELEASED" '# SKALA Attendance — 다음 릴리스'
    assert_contains "$UNRELEASED" '이 문서의 변경만으로 릴리스가 승인되거나 시작되지는 않습니다.'
    assert_contains "$UNRELEASED" '아직 기록된 변경 사항이 없습니다.'

    assert_not_contains "$DOCUMENTATION" 'git commit -am'

    for secret in \
        DEVELOPER_ID_APPLICATION_P12_BASE64 \
        DEVELOPER_ID_APPLICATION_P12_PASSWORD \
        APPLE_TEAM_ID \
        APP_STORE_CONNECT_ISSUER_ID \
        APP_STORE_CONNECT_KEY_ID \
        APP_STORE_CONNECT_PRIVATE_KEY_BASE64 \
        SPARKLE_EDDSA_PRIVATE_KEY \
        APPCAST_REPO_TOKEN; do
        if grep -Eq "${secret}[[:space:]]*=" "$DOCUMENTATION"; then
            fail "Documentation must name $secret without a value."
        fi
    done
}

make_candidate() {
    local destination=$1
    local signature=$2
    local duplicate=${3:-false}
    local candidate_version=${4:-0.1.11}
    local candidate_build=${5:-12}

    cat >"$destination" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version $candidate_version</title>
      <sparkle:version>$candidate_build</sparkle:version>
      <sparkle:shortVersionString>$candidate_version</sparkle:shortVersionString>
      <enclosure url="$ARCHIVE_URL" length="$ARCHIVE_SIZE" type="application/octet-stream" sparkle:edSignature="$signature" />
    </item>
EOF
    if [ "$duplicate" = true ]; then
        cat >>"$destination" <<EOF
    <item>
      <title>Duplicate Version $candidate_version</title>
      <sparkle:version>$candidate_build</sparkle:version>
      <sparkle:shortVersionString>$candidate_version</sparkle:shortVersionString>
      <enclosure url="$ARCHIVE_URL" length="$ARCHIVE_SIZE" type="application/octet-stream" sparkle:edSignature="$signature" />
    </item>
EOF
    fi
    cat >>"$destination" <<'EOF'
  </channel>
</rss>
EOF
}

make_probe() {
    local status=$1

    cat >"$TEMP_DIR/release-probe" <<EOF
#!/bin/bash
set -euo pipefail
[ "\$#" = 3 ]
    [ "\$1" = '$ARCHIVE_URL' ]
    [ "\$2" = '$ARCHIVE_SIZE' ]
    [ "\$3" = '$ARCHIVE_DIGEST' ]
exit $status
EOF
    chmod +x "$TEMP_DIR/release-probe"
}

make_archive_and_verifier() {
    local source="$TEMP_DIR/archive-source"

    mkdir -p "$source/SKALA Attendance.app/Contents/MacOS"
    printf 'preflight archive fixture\n' >"$source/SKALA Attendance.app/Contents/MacOS/SKALAAttendance"
    ARCHIVE="$TEMP_DIR/SKALA-Attendance-0.1.11-arm64.zip"
    (cd "$source" && /usr/bin/zip -qry "$ARCHIVE" 'SKALA Attendance.app')
    ARCHIVE_SIZE=$(stat -f '%z' "$ARCHIVE")
    ARCHIVE_DIGEST=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
    ARCHIVE_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.11/SKALA-Attendance-0.1.11-arm64.zip'

    TEST_PRIVATE_KEY="$TEMP_DIR/disposable-ed25519-private.pem"
    TEST_PUBLIC_PEM="$TEMP_DIR/disposable-ed25519-public.pem"
    "$OPENSSL" genpkey -algorithm ED25519 -out "$TEST_PRIVATE_KEY"
    "$OPENSSL" pkey -in "$TEST_PRIVATE_KEY" -pubout -out "$TEST_PUBLIC_PEM"
    TEST_PUBLIC_KEY=$("$OPENSSL" pkey -pubin -in "$TEST_PUBLIC_PEM" -pubout -outform DER | dd bs=1 skip=12 2>/dev/null | "$OPENSSL" base64 -A)
    TEST_PROJECT="$TEMP_DIR/project.yml"
    awk -v public_key="$TEST_PUBLIC_KEY" '
        /^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ { sub(/:.*/, ": \"0.1.11\"") }
        /^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*/ { sub(/:.*/, ": \"12\"") }
        /^[[:space:]]*SUPublicEDKey:[[:space:]]*/ { sub(/:.*/, ": " public_key) }
        { print }
    ' "$ROOT/project.yml" >"$TEST_PROJECT"

    TOOLS_ROOT="$TEMP_DIR/sparkle-tools"
    TOOLS_BIN="$TOOLS_ROOT/bin"
    mkdir -p "$TOOLS_BIN"
    make_sign_update
}

make_sign_update() {
    cat >"$TOOLS_BIN/sign_update" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF
    chmod +x "$TOOLS_BIN/sign_update"
}

make_mutating_openssl() {
    cat >"$TEMP_DIR/mutating-openssl" <<'EOF'
#!/bin/bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
    if [ "$1" = -in ]; then
        printf 'mutated by verifier\n' >>"$2"
        exit 0
    fi
    shift
done
exit 1
EOF
    chmod +x "$TEMP_DIR/mutating-openssl"
}

sign_archive() {
    local rawin=''
    if "$OPENSSL" pkeyutl -help 2>&1 | grep -Fq -- ' -rawin'; then
        rawin=-rawin
    fi
    if ! signature=$("$OPENSSL" pkeyutl -sign $rawin -inkey "$TEST_PRIVATE_KEY" -in "$ARCHIVE" 2>/dev/null | "$OPENSSL" base64 -A); then
        printf '%s' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
        return 0
    fi
    printf '%s' "$signature"
}

can_sign_archive() {
    local rawin=''
    if "$OPENSSL" pkeyutl -help 2>&1 | grep -Fq -- ' -rawin'; then
        rawin=-rawin
    fi
    "$OPENSSL" pkeyutl -sign $rawin -inkey "$TEST_PRIVATE_KEY" -in "$ARCHIVE" >/dev/null 2>&1
}

make_unsupported_signing_openssl() {
    cat >"$TEMP_DIR/unsupported-signing-openssl" <<EOF
#!/bin/bash
set -euo pipefail
if [ "\$1" = pkeyutl ] && [ "\$2" = -sign ]; then
    printf '%s\\n' 'pkeyutl: EVP_PKEY_sign_init operation not supported' >&2
    exit 1
fi
exec "$OPENSSL" "\$@"
EOF
    chmod +x "$TEMP_DIR/unsupported-signing-openssl"
}

make_portable_openssl() {
    cat >"$TEMP_DIR/portable-openssl" <<EOF
#!/bin/bash
set -euo pipefail
if [ "\$1" = pkeyutl ] && [ "\$2" = -help ]; then
    "$OPENSSL" "\$@" 2>&1 | grep -v -- ' -rawin' || true
    exit 0
fi
if [ "\$1" = pkeyutl ]; then
    shift
    exec "$OPENSSL" pkeyutl -rawin "\$@"
fi
exec "$OPENSSL" "\$@"
EOF
    chmod +x "$TEMP_DIR/portable-openssl"
}

make_baseline_with_released_version() {
    local destination=$1

    awk '
        /<channel>/ {
            print
            print "    <item>"
            print "      <title>Released Version 0.1.11</title>"
            print "      <sparkle:version>10</sparkle:version>"
            print "      <sparkle:shortVersionString>0.1.11</sparkle:shortVersionString>"
            print "    </item>"
            next
        }
        { print }
    ' "$FIXTURES/current-appcast.xml" >"$destination"
}

make_clean_worktree() {
    CLEAN_WORKTREE="$TEMP_DIR/clean-worktree"
    cp -R "$ROOT" "$CLEAN_WORKTREE"
    rm -rf "$CLEAN_WORKTREE/.git"
    git -C "$CLEAN_WORKTREE" init -q
    git -C "$CLEAN_WORKTREE" add -A
    git -C "$CLEAN_WORKTREE" -c user.name='Preflight Test' -c user.email='test@example.invalid' \
        commit -qm 'Clean fixture'
    PREFLIGHT="$CLEAN_WORKTREE/scripts/release/preflight.sh"
}

run_preflight() {
    local candidate=$1
    local tag=${2:-v0.1.11}
    local project=${3:-$TEST_PROJECT}
    local appcast=${4:-$FIXTURES/current-appcast.xml}

    env TMPDIR="$TEMP_DIR" OPENSSL_BIN="${PREFLIGHT_OPENSSL_BIN:-$OPENSSL}" bash "$PREFLIGHT" "$tag" \
        --project "$project" \
        --appcast "$appcast" \
        --candidate "$candidate" \
        --archive "$ARCHIVE" \
        --archive-sha256 "$ARCHIVE_DIGEST" \
        --sparkle-tools-root "$TOOLS_ROOT" \
        --release-probe "$TEMP_DIR/release-probe"
}

require_documentation
[ -x "$PREFLIGHT_SOURCE" ] || fail 'Release preflight command is missing or not executable.'

if grep -Eq '(codesign|notarytool|publish-appcast\.sh|generate-appcast-item\.sh|gh release|git push|(^|[^[:alnum:]_])mv[[:space:]])' "$PREFLIGHT_SOURCE"; then
    fail 'Preflight must not sign, notarize, publish, or mutate release inputs.'
fi
assert_contains "$PREFLIGHT_SOURCE" 'verification_archive=$(mktemp'
assert_contains "$PREFLIGHT_SOURCE" 'cp -p "$archive" "$verification_archive"'
assert_contains "$PREFLIGHT_SOURCE" 'trap cleanup EXIT'

make_clean_worktree
make_archive_and_verifier
VALID_CANDIDATE="$TEMP_DIR/valid.xml"
if can_sign_archive; then
    SYNTHETIC_SIGNING_SUPPORTED=true
else
    SYNTHETIC_SIGNING_SUPPORTED=false
fi
VALID_SIGNATURE=$(sign_archive)
make_candidate "$VALID_CANDIDATE" "$VALID_SIGNATURE"
make_probe 0

if [ "$SYNTHETIC_SIGNING_SUPPORTED" = true ]; then
    VALID_OUTPUT="$TEMP_DIR/valid.out"
    expect_success "$VALID_OUTPUT" run_preflight "$VALID_CANDIDATE"
    assert_contains "$VALID_OUTPUT" 'Release preflight passed: tag v0.1.11.'
else
    printf 'Skipping synthetic Ed25519 signing: OpenSSL cannot initialize EVP_PKEY_sign.\n'
fi

make_unsupported_signing_openssl
OPENSSL="$TEMP_DIR/unsupported-signing-openssl"
can_sign_archive && fail 'Unsupported-signing fixture unexpectedly initialized EVP_PKEY_sign.'
UNSUPPORTED_SIGNATURE=$(sign_archive)
OPENSSL=$(command -v openssl)

make_portable_openssl
PREFLIGHT_OPENSSL_BIN="$TEMP_DIR/portable-openssl"
OPENSSL="$TEMP_DIR/portable-openssl"
if can_sign_archive; then
    SYNTHETIC_SIGNING_SUPPORTED=true
else
    SYNTHETIC_SIGNING_SUPPORTED=false
fi
PORTABLE_SIGNATURE=$(sign_archive)
OPENSSL=$(command -v openssl)
PORTABLE_CANDIDATE="$TEMP_DIR/portable.xml"
make_candidate "$PORTABLE_CANDIDATE" "$PORTABLE_SIGNATURE"
if [ "$SYNTHETIC_SIGNING_SUPPORTED" = true ]; then
    PORTABLE_OUTPUT="$TEMP_DIR/portable.out"
    expect_success "$PORTABLE_OUTPUT" run_preflight "$PORTABLE_CANDIDATE"
    assert_contains "$PORTABLE_OUTPUT" 'Release preflight passed: tag v0.1.11.'
else
    printf 'Skipping portable synthetic signing: OpenSSL cannot initialize EVP_PKEY_sign.\n'
fi
unset PREFLIGHT_OPENSSL_BIN

MUTATING_ARCHIVE_BEFORE="$TEMP_DIR/archive-before-mutating-verifier.zip"
cp "$ARCHIVE" "$MUTATING_ARCHIVE_BEFORE"
make_mutating_openssl
PREFLIGHT_OPENSSL_BIN="$TEMP_DIR/mutating-openssl"
MUTATING_VERIFIER_OUTPUT="$TEMP_DIR/mutating-verifier.out"
expect_failure "$MUTATING_VERIFIER_OUTPUT" run_preflight "$VALID_CANDIDATE"
assert_contains "$MUTATING_VERIFIER_OUTPUT" 'Verification archive changed during Sparkle verification.'
cmp -s "$MUTATING_ARCHIVE_BEFORE" "$ARCHIVE" || fail 'Mutating verifier altered the original archive.'
if compgen -G "$TEMP_DIR/skala-preflight-archive.*" >/dev/null; then
    fail 'Preflight left its verification archive copy behind.'
fi
unset PREFLIGHT_OPENSSL_BIN

ALL_A_OUTPUT="$TEMP_DIR/all-a-signature.out"
ALL_A_CANDIDATE="$TEMP_DIR/all-a-signature.xml"
make_candidate "$ALL_A_CANDIDATE" 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
expect_failure "$ALL_A_OUTPUT" run_preflight "$ALL_A_CANDIDATE"
assert_contains "$ALL_A_OUTPUT" 'Sparkle signature verification failed.'

DUPLICATE_RELEASED_BASELINE="$TEMP_DIR/duplicate-released-version.xml"
make_baseline_with_released_version "$DUPLICATE_RELEASED_BASELINE"
DUPLICATE_RELEASED_OUTPUT="$TEMP_DIR/duplicate-released-version.out"
expect_failure "$DUPLICATE_RELEASED_OUTPUT" run_preflight "$VALID_CANDIDATE" v0.1.11 "$TEST_PROJECT" "$DUPLICATE_RELEASED_BASELINE"
assert_contains "$DUPLICATE_RELEASED_OUTPUT" 'Candidate version 0.1.11 already exists in baseline appcast.'

MISMATCHED_VERSION_CANDIDATE="$TEMP_DIR/mismatched-version.xml"
make_candidate "$MISMATCHED_VERSION_CANDIDATE" "$VALID_SIGNATURE" false 0.1.12 12
MISMATCHED_VERSION_OUTPUT="$TEMP_DIR/mismatched-version.out"
expect_failure "$MISMATCHED_VERSION_OUTPUT" run_preflight "$MISMATCHED_VERSION_CANDIDATE"
assert_contains "$MISMATCHED_VERSION_OUTPUT" 'Candidate version 0.1.12 does not match release tag v0.1.11.'

MISMATCHED_BUILD_CANDIDATE="$TEMP_DIR/mismatched-build.xml"
make_candidate "$MISMATCHED_BUILD_CANDIDATE" "$VALID_SIGNATURE" false 0.1.11 13
MISMATCHED_BUILD_OUTPUT="$TEMP_DIR/mismatched-build.out"
expect_failure "$MISMATCHED_BUILD_OUTPUT" run_preflight "$MISMATCHED_BUILD_CANDIDATE"
assert_contains "$MISMATCHED_BUILD_OUTPUT" 'Candidate build 13 does not match project build 12.'

MISMATCH_OUTPUT="$TEMP_DIR/mismatch.out"
expect_failure "$MISMATCH_OUTPUT" run_preflight "$VALID_CANDIDATE" v0.1.12
assert_contains "$MISMATCH_OUTPUT" 'Tag v0.1.12 does not match marketing version 0.1.11.'

STALE_OUTPUT="$TEMP_DIR/stale.out"
expect_failure "$STALE_OUTPUT" run_preflight "$VALID_CANDIDATE" v0.1.11 "$FIXTURES/release-0.1.11-build-10.yml"
assert_contains "$STALE_OUTPUT" 'Build 10 must be greater than current appcast build 10.'

DUPLICATE_CANDIDATE="$TEMP_DIR/duplicate.xml"
make_candidate "$DUPLICATE_CANDIDATE" "$VALID_SIGNATURE" true
DUPLICATE_OUTPUT="$TEMP_DIR/duplicate.out"
expect_failure "$DUPLICATE_OUTPUT" run_preflight "$DUPLICATE_CANDIDATE"
assert_contains "$DUPLICATE_OUTPUT" 'Candidate appcast must contain exactly one item for the expected release ZIP URL.'

INVALID_XML="$TEMP_DIR/invalid.xml"
printf '<broken' >"$INVALID_XML"
INVALID_XML_OUTPUT="$TEMP_DIR/invalid-xml.out"
expect_failure "$INVALID_XML_OUTPUT" run_preflight "$INVALID_XML"
assert_contains "$INVALID_XML_OUTPUT" 'Candidate appcast XML is not well-formed.'

make_probe 1
UNAVAILABLE_OUTPUT="$TEMP_DIR/unavailable.out"
expect_failure "$UNAVAILABLE_OUTPUT" run_preflight "$VALID_CANDIDATE"
assert_contains "$UNAVAILABLE_OUTPUT" 'Release asset availability check failed.'

make_probe 0
INVALID_SIGNATURE_CANDIDATE="$TEMP_DIR/invalid-signature.xml"
make_candidate "$INVALID_SIGNATURE_CANDIDATE" 'not-a-sparkle-signature'
INVALID_SIGNATURE_OUTPUT="$TEMP_DIR/invalid-signature.out"
expect_failure "$INVALID_SIGNATURE_OUTPUT" run_preflight "$INVALID_SIGNATURE_CANDIDATE"
assert_contains "$INVALID_SIGNATURE_OUTPUT" 'Candidate appcast item is missing a valid Sparkle EdDSA signature.'

DIRTY_WORKTREE="$TEMP_DIR/dirty-worktree"
cp -R "$CLEAN_WORKTREE" "$DIRTY_WORKTREE"
printf 'dirty\n' >"$DIRTY_WORKTREE/dirty-file"
DIRTY_OUTPUT="$TEMP_DIR/dirty.out"
expect_failure "$DIRTY_OUTPUT" bash "$DIRTY_WORKTREE/scripts/release/preflight.sh" v0.1.11 \
    --project "$TEST_PROJECT" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive "$ARCHIVE" \
    --archive-sha256 "$ARCHIVE_DIGEST" \
    --sparkle-tools-root "$TOOLS_ROOT" \
    --release-probe "$TEMP_DIR/release-probe"
assert_contains "$DIRTY_OUTPUT" 'Worktree has uncommitted changes.'

INJECTION_MARKER="$TEMP_DIR/tag-injection-ran"
TAG_INJECTION_OUTPUT="$TEMP_DIR/tag-injection.out"
expect_failure "$TAG_INJECTION_OUTPUT" bash "$PREFLIGHT" "v0.1.11;touch $INJECTION_MARKER" \
    --project "$TEST_PROJECT" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive "$ARCHIVE" \
    --archive-sha256 "$ARCHIVE_DIGEST" \
    --sparkle-tools-root "$TOOLS_ROOT" \
    --release-probe "$TEMP_DIR/release-probe"
[ ! -e "$INJECTION_MARKER" ] || fail 'Tag injection was executed.'

PATH_INJECTION_MARKER="$TEMP_DIR/path-injection-ran"
PATH_INJECTION_OUTPUT="$TEMP_DIR/path-injection.out"
expect_failure "$PATH_INJECTION_OUTPUT" bash "$PREFLIGHT" v0.1.11 \
    --project "$TEST_PROJECT" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE;touch $PATH_INJECTION_MARKER" \
    --archive "$ARCHIVE" \
    --archive-sha256 "$ARCHIVE_DIGEST" \
    --sparkle-tools-root "$TOOLS_ROOT" \
    --release-probe "$TEMP_DIR/release-probe"
[ ! -e "$PATH_INJECTION_MARKER" ] || fail 'Path injection was executed.'

printf 'Release preflight documentation and fixture matrix tests passed.\n'
