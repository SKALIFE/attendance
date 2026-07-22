#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---unsigned}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$MODE" != "--unsigned" ]; then
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required for signed release}"
  : "${DEVELOPER_ID_APPLICATION_P12_BASE64:?Developer ID certificate is required}"
  : "${SPARKLE_EDDSA_PRIVATE_KEY:?Sparkle private key is required}"
fi

cd "$ROOT_DIR"
scripts/build.sh Release
mkdir -p release
ditto -c -k --keepParent "build/Build/Products/Release/SKALAAttendance.app" "release/SKALA-Attendance-1.0.0-arm64.zip"
scripts/create-dmg.sh 1.0.0
