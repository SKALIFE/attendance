#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APPCAST="$ROOT/tests/fixtures/current-appcast.xml"

grep -Eq '^[[:space:]]*<sparkle:version>1</sparkle:version>[[:space:]]*$' "$APPCAST"
grep -Eq '^[[:space:]]*<sparkle:shortVersionString>0\.1\.0</sparkle:shortVersionString>[[:space:]]*$' "$APPCAST"
grep -Eq '^[[:space:]]*<item>[[:space:]]*$' "$APPCAST"
grep -Eq '^[[:space:]]*</item>[[:space:]]*$' "$APPCAST"
xmllint --noout "$APPCAST"

printf 'Baseline appcast fixture is valid at version 0.1.0 build 1.\n'
