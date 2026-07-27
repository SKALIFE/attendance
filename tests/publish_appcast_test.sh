#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PUBLISHER="$ROOT/scripts/publish-appcast.sh"
FIXTURE="$ROOT/tests/fixtures/current-appcast.xml"
TEMP_DIR=$(mktemp -d)
TEST_TMPDIR="$TEMP_DIR/publisher-tmp"
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

assert_unchanged() {
    cmp -s "$1" "$2" || fail "Expected $2 to remain unchanged."
}

expect_failure() {
    local output=$1
    shift

    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected a failing exit status.'
    fi
}

make_candidate() {
    local destination=$1
    local version=$2
    local build=$3
    local url=$4

    cat >"$destination" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version $version</title>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <enclosure url="$url" length="123" type="application/octet-stream" sparkle:edSignature="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==" sparkle:version="$build" sparkle:shortVersionString="$version" sparkle:minimumSystemVersion="14.0" sparkle:os="macos" sparkle:arch="arm64" />
    </item>
    <item>
      <title>Version 0.1.0</title>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
    </item>
  </channel>
</rss>
EOF
}

make_target() {
    TARGET="$TEMP_DIR/target.git"
    SEED="$TEMP_DIR/seed"
    git init --bare "$TARGET" >/dev/null
    git clone "$TARGET" "$SEED" >/dev/null 2>&1
    cp "$FIXTURE" "$SEED/appcast.xml"
    printf 'unrelated file\n' >"$SEED/README.md"
    git -C "$SEED" add appcast.xml README.md
    git -C "$SEED" -c user.name='Test Publisher' -c user.email='test@example.invalid' commit -m 'Seed appcast' >/dev/null
    git -C "$SEED" push origin HEAD:main >/dev/null
    git --git-dir="$TARGET" symbolic-ref HEAD refs/heads/main
    rm -rf "$SEED"
}

remote_file() {
    git --git-dir="$TARGET" show "main:$1"
}

make_probe() {
    PROBE="$TEMP_DIR/release-probe"
    cat >"$PROBE" <<EOF
#!/bin/bash
set -euo pipefail
[ "\$#" = 3 ] || exit 71
[ "\$1" = "$EXPECTED_URL" ] || exit 72
[ "\$2" = 123 ] || exit 73
[ "\$3" = "$EXPECTED_DIGEST" ] || exit 74
[ -z "\${APPCAST_REPO_TOKEN+x}" ] || exit 75
[ -z "\${LEAK_MARKER+x}" ] || exit 76
EOF
    chmod +x "$PROBE"
}

make_raw_fetcher() {
    RAW_FETCHER="$TEMP_DIR/raw-fetcher"
    cat >"$RAW_FETCHER" <<'EOF'
#!/bin/bash
set -euo pipefail
[ -z "${APPCAST_REPO_TOKEN+x}" ] || exit 81
[ -z "${LEAK_MARKER+x}" ] || exit 82
[ "$1" = --fail ] || exit 83
[ "$2" = --location ] || exit 84
[ "$3" = --silent ] || exit 85
[ "$4" = --show-error ] || exit 86
[ "$5" = --output ] || exit 87
[ "$7" = 'https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml' ] || exit 88
if [ "${RAW_MODE:-current}" = stale ]; then
    cat "$RAW_STALE" >"$6"
else
    git --git-dir="$RAW_TARGET" show main:appcast.xml >"$6"
fi
EOF
    chmod +x "$RAW_FETCHER"
}

run_publisher() {
    env APPCAST_REPO_TOKEN='offline-test-token-must-not-leak' LEAK_MARKER='must-not-reach-probe-or-hooks' \
        TMPDIR="$TEST_TMPDIR" RAW_TARGET="$TARGET" CURL_BIN="$RAW_FETCHER" bash "$PUBLISHER" \
        --candidate "$1" --archive-url "$EXPECTED_URL" --archive-sha256 "$EXPECTED_DIGEST" \
        --release-probe "$PROBE" --target-repo "$TARGET" --branch main --appcast-path appcast.xml \
        --raw-appcast-url 'https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml'
}

EXPECTED_DIGEST='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
EXPECTED_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.1/SKALA-Attendance-0.1.1-arm64.zip'
mkdir -p "$TEST_TMPDIR"
make_target
make_probe
make_raw_fetcher

if grep -Eq 'set[[:space:]]+-[^\n]*x|echo[[:space:]].*APPCAST_REPO_TOKEN|printf[[:space:]].*APPCAST_REPO_TOKEN' "$PUBLISHER" || ! grep -Fq 'unset APPCAST_REPO_TOKEN' "$PUBLISHER"; then
    fail 'Publisher must disable xtrace and scrub APPCAST_REPO_TOKEN without printing it.'
fi

INITIAL_APPCAST="$TEMP_DIR/initial-appcast.xml"
remote_file appcast.xml >"$INITIAL_APPCAST"
INITIAL_README="$TEMP_DIR/initial-readme.txt"
remote_file README.md >"$INITIAL_README"

MALFORMED="$TEMP_DIR/malformed.xml"
printf '<broken' >"$MALFORMED"
XTRACE_SENTINEL='xtrace-token-must-not-appear'
XTRACE_OUTPUT="$TEMP_DIR/xtrace.out"
expect_failure "$XTRACE_OUTPUT" env APPCAST_REPO_TOKEN="$XTRACE_SENTINEL" \
    bash -x "$PUBLISHER" --candidate "$MALFORMED" --archive-url "$EXPECTED_URL" \
    --archive-sha256 "$EXPECTED_DIGEST" --release-probe "$PROBE" \
    --target-repo https://github.com/SKALIFE/attendance-appcast.git --branch main --appcast-path appcast.xml
assert_not_contains "$XTRACE_OUTPUT" "$XTRACE_SENTINEL"
expect_failure "$TEMP_DIR/malformed.out" run_publisher "$MALFORMED"
assert_unchanged "$INITIAL_APPCAST" <(remote_file appcast.xml)

BAD_URL_CANDIDATE="$TEMP_DIR/bad-url.xml"
make_candidate "$BAD_URL_CANDIDATE" 0.1.1 2 'https://example.invalid/SKALA-Attendance-0.1.1-arm64.zip'
expect_failure "$TEMP_DIR/bad-url.out" run_publisher "$BAD_URL_CANDIDATE"
assert_unchanged "$INITIAL_APPCAST" <(remote_file appcast.xml)

VALID_CANDIDATE="$TEMP_DIR/candidate.xml"
make_candidate "$VALID_CANDIDATE" 0.1.1 2 "$EXPECTED_URL"
DUPLICATE_CANDIDATE="$TEMP_DIR/duplicate-candidate.xml"
cp "$VALID_CANDIDATE" "$DUPLICATE_CANDIDATE"
awk '
    /^[[:space:]]*<item>/ && !capturing && !duplicated {
        capturing = 1
    }
    {
        print
        if (capturing) item = item $0 ORS
    }
    capturing && /^[[:space:]]*<\/item>/ {
        print item
        capturing = 0
        duplicated = 1
    }
' "$VALID_CANDIDATE" >"$DUPLICATE_CANDIDATE"
expect_failure "$TEMP_DIR/duplicate.out" run_publisher "$DUPLICATE_CANDIDATE"
assert_unchanged "$INITIAL_APPCAST" <(remote_file appcast.xml)

BAD_DIGEST_OUTPUT="$TEMP_DIR/bad-digest.out"
if env APPCAST_REPO_TOKEN='offline-test-token-must-not-leak' TMPDIR="$TEST_TMPDIR" \
    bash "$PUBLISHER" --candidate "$VALID_CANDIDATE" --archive-url "$EXPECTED_URL" \
    --archive-sha256 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' \
    --release-probe "$PROBE" --target-repo "$TARGET" --branch main --appcast-path appcast.xml >"$BAD_DIGEST_OUTPUT" 2>&1; then
    fail 'Expected digest validation failure.'
fi
assert_unchanged "$INITIAL_APPCAST" <(remote_file appcast.xml)

cat >"$TARGET/hooks/pre-receive" <<'EOF'
#!/bin/bash
set -euo pipefail
[ -z "${APPCAST_REPO_TOKEN+x}" ]
[ -z "${LEAK_MARKER+x}" ]
EOF
chmod +x "$TARGET/hooks/pre-receive"

SUCCESS_OUTPUT="$TEMP_DIR/success.out"
run_publisher "$VALID_CANDIDATE" >"$SUCCESS_OUTPUT"
assert_not_contains "$SUCCESS_OUTPUT" 'offline-test-token-must-not-leak'
UPDATED_APPCAST="$TEMP_DIR/updated-appcast.xml"
remote_file appcast.xml >"$UPDATED_APPCAST"
assert_contains "$UPDATED_APPCAST" '<sparkle:version>2</sparkle:version>'
assert_contains "$UPDATED_APPCAST" "url=\"$EXPECTED_URL\""
assert_contains "$UPDATED_APPCAST" '<sparkle:version>1</sparkle:version>'
xmllint --nonet --noout "$UPDATED_APPCAST"
assert_unchanged "$INITIAL_README" <(remote_file README.md)

expect_failure "$TEMP_DIR/repeat.out" run_publisher "$VALID_CANDIDATE"
assert_unchanged "$UPDATED_APPCAST" <(remote_file appcast.xml)

NEXT_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.2/SKALA-Attendance-0.1.2-arm64.zip'
NEXT_CANDIDATE="$TEMP_DIR/next-candidate.xml"
make_candidate "$NEXT_CANDIDATE" 0.1.2 3 "$NEXT_URL"
EXPECTED_URL="$NEXT_URL"
make_probe
cat >"$TARGET/hooks/pre-receive" <<'EOF'
#!/bin/bash
exit 88
EOF
chmod +x "$TARGET/hooks/pre-receive"
PUSH_FAIL_OUTPUT="$TEMP_DIR/push-fail.out"
expect_failure "$PUSH_FAIL_OUTPUT" run_publisher "$NEXT_CANDIDATE"
assert_unchanged "$UPDATED_APPCAST" <(remote_file appcast.xml)

RAW_FAILURE_URL='https://github.com/SKALIFE/attendance/releases/download/v0.1.3/SKALA-Attendance-0.1.3-arm64.zip'
RAW_FAILURE_CANDIDATE="$TEMP_DIR/raw-failure-candidate.xml"
make_candidate "$RAW_FAILURE_CANDIDATE" 0.1.3 4 "$RAW_FAILURE_URL"
EXPECTED_URL="$RAW_FAILURE_URL"
make_probe
rm -f "$TARGET/hooks/pre-receive"
RAW_FAILURE_OUTPUT="$TEMP_DIR/raw-failure.out"
RAW_MODE=stale RAW_STALE="$INITIAL_APPCAST" expect_failure "$RAW_FAILURE_OUTPUT" run_publisher "$RAW_FAILURE_CANDIDATE"
assert_not_contains "$RAW_FAILURE_OUTPUT" 'Published appcast version'
assert_contains <(remote_file appcast.xml) '<sparkle:version>4</sparkle:version>'

if compgen -G "$TEST_TMPDIR/appcast-publisher.*" >/dev/null; then
    fail 'Publisher left its temporary clone behind.'
fi

printf 'Appcast publisher offline local-mock tests passed.\n'
