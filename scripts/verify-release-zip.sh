#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s immutable-release-url archive-size archive-sha256\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

cleanup() {
    [ -z "${archive:-}" ] || /bin/rm -f "$archive" || return 1
    archive=
}

[ "$#" = 3 ] || usage

archive_url=$1
archive_size=$2
archive_sha256=$3
archive=
CURL_BIN=${CURL_BIN:-/usr/bin/curl}

[[ "$archive_size" =~ ^[0-9]+$ ]] || error 'Archive size must be a non-negative integer.'
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || error 'Archive SHA-256 must be lowercase hexadecimal.'
[[ "$archive_url" =~ ^https://github\.com/SKALIFE/attendance/releases/download/v([0-9]+\.[0-9]+\.[0-9]+)/SKALA-Attendance-([0-9]+\.[0-9]+\.[0-9]+)-arm64\.zip$ ]] || error 'Archive URL must be an immutable SKALA Attendance release ZIP URL.'
[ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ] || error 'Archive URL tag and filename version must match.'
[ -x "$CURL_BIN" ] || error 'Configured curl binary is missing or not executable.'

archive=$(mktemp "${TMPDIR:-/tmp}/release-zip.XXXXXX") || error 'Unable to create temporary release ZIP path.'
trap 'cleanup || exit 1' EXIT
env -u APPCAST_REPO_TOKEN -u LEAK_MARKER "$CURL_BIN" --fail --location --silent --show-error --output "$archive" "$archive_url" || error 'Release ZIP download failed.'
/usr/bin/unzip -tqq "$archive" >/dev/null 2>&1 || error 'Downloaded release asset is not a valid ZIP.'
actual_size=$(stat -f '%z' "$archive") || error 'Unable to determine downloaded release ZIP size.'
[ "$actual_size" = "$archive_size" ] || error 'Downloaded release ZIP size does not match the appcast enclosure.'
actual_sha256=$(shasum -a 256 "$archive" | awk '{print $1}') || error 'Unable to digest downloaded release ZIP.'
[ "$actual_sha256" = "$archive_sha256" ] || error 'Downloaded release ZIP SHA-256 does not match the expected digest.'

cleanup || error 'Unable to remove downloaded release ZIP.'
trap - EXIT
printf 'Release ZIP download verified.\n'
