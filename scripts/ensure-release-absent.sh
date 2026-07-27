#!/bin/bash
set -euo pipefail

[ "$#" = 1 ] || exit 2
[ -n "${GH_TOKEN:-}" ] || exit 1

tag=$1
release_view_output=$(mktemp)
cleanup() {
    rm -f "$release_view_output"
}
trap cleanup EXIT

if gh release view "$tag" --json id >"$release_view_output" 2>&1; then
    printf 'GitHub Release %s already exists.\n' "$tag" >&2
    exit 1
fi

grep -Fq 'release not found' "$release_view_output" || {
    printf 'Unable to determine whether GitHub Release %s already exists.\n' "$tag" >&2
    exit 1
}
