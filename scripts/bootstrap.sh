#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  printf 'xcodegen is required. Install it before bootstrapping.\n' >&2
  exit 1
fi

xcodegen generate
