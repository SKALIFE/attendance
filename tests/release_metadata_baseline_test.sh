#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$ROOT/project.yml"
APPCAST="$ROOT/tests/fixtures/current-appcast.xml"

assert_contains() {
    local file=$1
    local expected=$2

    if ! grep -Fq "$expected" "$file"; then
        printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
        exit 1
    fi
}

assert_contains "$PROJECT" 'MARKETING_VERSION: "0.1.8"'
assert_contains "$PROJECT" 'CURRENT_PROJECT_VERSION: "9"'
assert_contains "$APPCAST" '<sparkle:version>1</sparkle:version>'
assert_contains "$APPCAST" '<sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>'

printf 'Baseline metadata fixture supports marketing version 0.1.8 and build 9 over released build 1.\n'
