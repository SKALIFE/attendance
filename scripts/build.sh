#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-Debug}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild build \
  -project SKALAAttendance.xcodeproj \
  -scheme SKALAAttendance \
  -configuration "$CONFIGURATION" \
  -derivedDataPath build \
  -destination 'platform=macOS,arch=arm64'
