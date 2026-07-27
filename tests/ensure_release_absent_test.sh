#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GUARD="$ROOT/scripts/ensure-release-absent.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

expect_failure() {
    if "$@" >"$TEMP_DIR/output" 2>&1; then
        fail 'Expected duplicate-release guard failure.'
    fi
}

mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/gh" <<'EOF'
#!/bin/bash
set -euo pipefail

case "${GH_MOCK_RESULT:-}" in
    absent)
        printf 'release not found\n' >&2
        exit 1
        ;;
    existing)
        printf '{"id":"1"}\n'
        ;;
    unavailable)
        printf 'authentication failed\n' >&2
        exit 1
        ;;
    *)
        exit 2
        ;;
esac
EOF
chmod +x "$TEMP_DIR/bin/gh"

env PATH="$TEMP_DIR/bin:$PATH" GH_TOKEN=test-token GH_MOCK_RESULT=absent \
    bash "$GUARD" v0.1.1
expect_failure env PATH="$TEMP_DIR/bin:$PATH" GH_TOKEN=test-token GH_MOCK_RESULT=existing \
    bash "$GUARD" v0.1.1
expect_failure env PATH="$TEMP_DIR/bin:$PATH" GH_TOKEN=test-token GH_MOCK_RESULT=unavailable \
    bash "$GUARD" v0.1.1
expect_failure env PATH="$TEMP_DIR/bin:$PATH" GH_MOCK_RESULT=absent \
    bash "$GUARD" v0.1.1

printf 'Duplicate-release guard tests passed.\n'
