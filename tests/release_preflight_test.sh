#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFLIGHT_SOURCE="$ROOT/scripts/release/preflight.sh"
PREFLIGHT="$PREFLIGHT_SOURCE"
DOCUMENTATION="$ROOT/docs/release-operations.md"
FIXTURES="$ROOT/tests/fixtures"
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
        'DEVELOPER_ID_APPLICATION_P12_BASE64' \
        'DEVELOPER_ID_APPLICATION_P12_PASSWORD' \
        'APPLE_TEAM_ID' \
        'APP_STORE_CONNECT_ISSUER_ID' \
        'APP_STORE_CONNECT_KEY_ID' \
        'APP_STORE_CONNECT_PRIVATE_KEY_BASE64' \
        'SPARKLE_EDDSA_PRIVATE_KEY' \
        'APPCAST_REPO_TOKEN' \
        'least privilege' \
        'MARKETING_VERSION' \
        'CURRENT_PROJECT_VERSION' \
        'git commit' \
        'git push origin main' \
        'git tag -a' \
        'git push origin v' \
        'checksums.txt' \
        'Rollback before feed publication' \
        'CI GUI boundary' \
        'scripts/release/preflight.sh v0.1.1'; do
        assert_contains "$DOCUMENTATION" "$text"
    done

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
    local url='https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip'

    cat >"$destination" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version 0.1.1</title>
      <sparkle:version>2</sparkle:version>
      <sparkle:shortVersionString>0.1.1</sparkle:shortVersionString>
      <enclosure url="$url" length="123" type="application/octet-stream" sparkle:edSignature="$signature" />
    </item>
EOF
    if [ "$duplicate" = true ]; then
        cat >>"$destination" <<EOF
    <item>
      <title>Duplicate Version 0.1.1</title>
      <sparkle:version>2</sparkle:version>
      <sparkle:shortVersionString>0.1.1</sparkle:shortVersionString>
      <enclosure url="$url" length="123" type="application/octet-stream" sparkle:edSignature="$signature" />
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
[ "\$1" = 'https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip' ]
[ "\$2" = 123 ]
[ "\$3" = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' ]
exit $status
EOF
    chmod +x "$TEMP_DIR/release-probe"
}

make_clean_worktree() {
    CLEAN_WORKTREE="$TEMP_DIR/clean-worktree"
    cp -R "$ROOT" "$CLEAN_WORKTREE"
    git -C "$CLEAN_WORKTREE" add -A
    git -C "$CLEAN_WORKTREE" -c user.name='Preflight Test' -c user.email='test@example.invalid' \
        commit -qm 'Clean fixture'
    PREFLIGHT="$CLEAN_WORKTREE/scripts/release/preflight.sh"
}

run_preflight() {
    bash "$PREFLIGHT" v0.1.1 \
        --project "$FIXTURES/release-0.1.1-build-2.yml" \
        --appcast "$FIXTURES/current-appcast.xml" \
        --candidate "$1" \
        --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
        --release-probe "$TEMP_DIR/release-probe"
}

require_documentation
[ -x "$PREFLIGHT_SOURCE" ] || fail 'Release preflight command is missing or not executable.'

if grep -Eq '(codesign|notarytool|publish-appcast\.sh|generate-appcast-item\.sh|gh release|git push|(^|[^[:alnum:]_])mv[[:space:]]|(^|[^[:alnum:]_])cp[[:space:]])' "$PREFLIGHT_SOURCE"; then
    fail 'Preflight must not sign, notarize, publish, or mutate release inputs.'
fi

make_clean_worktree
VALID_CANDIDATE="$TEMP_DIR/valid.xml"
VALID_SIGNATURE='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
make_candidate "$VALID_CANDIDATE" "$VALID_SIGNATURE"
make_probe 0

VALID_OUTPUT="$TEMP_DIR/valid.out"
expect_success "$VALID_OUTPUT" run_preflight "$VALID_CANDIDATE"
assert_contains "$VALID_OUTPUT" 'Release preflight passed: tag v0.1.1.'

MISMATCH_OUTPUT="$TEMP_DIR/mismatch.out"
expect_failure "$MISMATCH_OUTPUT" bash "$PREFLIGHT" v0.1.2 \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    --release-probe "$TEMP_DIR/release-probe"
assert_contains "$MISMATCH_OUTPUT" 'Tag v0.1.2 does not match marketing version 0.1.1.'

STALE_OUTPUT="$TEMP_DIR/stale.out"
expect_failure "$STALE_OUTPUT" bash "$PREFLIGHT" v0.1.1 \
    --project "$FIXTURES/release-0.1.1-build-1.yml" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    --release-probe "$TEMP_DIR/release-probe"
assert_contains "$STALE_OUTPUT" 'Build 1 must be greater than current appcast build 1.'

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
expect_failure "$DIRTY_OUTPUT" bash "$DIRTY_WORKTREE/scripts/release/preflight.sh" v0.1.1 \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    --release-probe "$TEMP_DIR/release-probe"
assert_contains "$DIRTY_OUTPUT" 'Worktree has uncommitted changes.'

INJECTION_MARKER="$TEMP_DIR/tag-injection-ran"
TAG_INJECTION_OUTPUT="$TEMP_DIR/tag-injection.out"
expect_failure "$TAG_INJECTION_OUTPUT" bash "$PREFLIGHT" "v0.1.1;touch $INJECTION_MARKER" \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE" \
    --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    --release-probe "$TEMP_DIR/release-probe"
[ ! -e "$INJECTION_MARKER" ] || fail 'Tag injection was executed.'

PATH_INJECTION_MARKER="$TEMP_DIR/path-injection-ran"
PATH_INJECTION_OUTPUT="$TEMP_DIR/path-injection.out"
expect_failure "$PATH_INJECTION_OUTPUT" bash "$PREFLIGHT" v0.1.1 \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml" \
    --candidate "$VALID_CANDIDATE;touch $PATH_INJECTION_MARKER" \
    --archive-sha256 '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
    --release-probe "$TEMP_DIR/release-probe"
[ ! -e "$PATH_INJECTION_MARKER" ] || fail 'Path injection was executed.'

printf 'Release preflight documentation and fixture matrix tests passed.\n'
