#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VALIDATOR="$ROOT/scripts/validate-release-metadata.sh"
FIXTURES="$ROOT/tests/fixtures"
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

snapshot_tracked_contents() {
    local snapshot=$1

    git -C "$ROOT" ls-files -z |
        while IFS= read -r -d '' path; do
            [ -f "$ROOT/$path" ] || continue
            shasum -a 256 "$ROOT/$path"
        done >"$snapshot"
}

TRACKED_CONTENTS_BEFORE="$TEMP_DIR/tracked-contents-before.sha256"
snapshot_tracked_contents "$TRACKED_CONTENTS_BEFORE"

if ! awk '
    /^  Sparkle:/ { in_sparkle = 1; next }
    in_sparkle && /^  [^ ]/ { exit }
    in_sparkle && /exactVersion: "2\.9\.4"/ { found = 1 }
    END { exit found ? 0 : 1 }
' "$ROOT/project.yml"; then
    fail 'Sparkle must use exactVersion: "2.9.4".'
fi

expect_success() {
    local output=$1
    shift

    if ! "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail "Expected validator success, got a failing exit status"
    fi
}

expect_failure() {
    local output=$1
    shift

    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail "Expected validator failure, got a successful exit status"
    fi
}

VALID_OUTPUT="$TEMP_DIR/valid.out"
expect_success "$VALID_OUTPUT" bash "$VALIDATOR" \
    --tag v0.1.1 \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml"
assert_contains "$VALID_OUTPUT" 'Release metadata valid: tag v0.1.1, marketing version 0.1.1, build 2, appcast build 1.'

PROJECT_OUTPUT="$TEMP_DIR/project.out"
expect_success "$PROJECT_OUTPUT" bash "$VALIDATOR" \
    --tag v0.1.7 \
    --project "$ROOT/project.yml" \
    --appcast "$FIXTURES/current-appcast.xml"
assert_contains "$PROJECT_OUTPUT" 'Release metadata valid: tag v0.1.7, marketing version 0.1.7, build 8, appcast build 1.'

MISMATCH_OUTPUT="$TEMP_DIR/mismatched-tag.out"
expect_failure "$MISMATCH_OUTPUT" bash "$VALIDATOR" \
    --tag v0.1.2 \
    --project "$FIXTURES/release-0.1.1-build-2.yml" \
    --appcast "$FIXTURES/current-appcast.xml"
assert_contains "$MISMATCH_OUTPUT" 'Tag v0.1.2 does not match marketing version 0.1.1.'
assert_not_contains "$MISMATCH_OUTPUT" 'Release metadata valid:'

STALE_OUTPUT="$TEMP_DIR/stale-build.out"
expect_failure "$STALE_OUTPUT" bash "$VALIDATOR" \
    --tag v0.1.1 \
    --project "$FIXTURES/release-0.1.1-build-1.yml" \
    --appcast "$FIXTURES/current-appcast.xml"
assert_contains "$STALE_OUTPUT" 'Build 1 must be greater than current appcast build 1.'
assert_not_contains "$STALE_OUTPUT" 'Release metadata valid:'

TRACKED_CONTENTS_AFTER="$TEMP_DIR/tracked-contents-after.sha256"
snapshot_tracked_contents "$TRACKED_CONTENTS_AFTER"
if ! cmp -s "$TRACKED_CONTENTS_BEFORE" "$TRACKED_CONTENTS_AFTER"; then
    fail 'Validator modified tracked source while validating fixture data.'
fi

printf 'Release metadata validator tests passed.\n'
