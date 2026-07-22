#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"
xcodegen generate
if [[ "${SKALA_RUN_CHROME_INTEGRATION_TEST:-}" == "1" ]]; then
  xcodebuild test \
    -project SKALAAttendance.xcodeproj \
    -scheme SKALAAttendance \
    -derivedDataPath build \
    -destination 'platform=macOS,arch=arm64' \
    SKALA_CHROME_INTEGRATION_CONDITION=SKALA_CHROME_INTEGRATION_ENABLED
else
  xcodebuild test \
    -project SKALAAttendance.xcodeproj \
    -scheme SKALAAttendance \
    -derivedDataPath build \
    -destination 'platform=macOS,arch=arm64'
fi
