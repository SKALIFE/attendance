#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s immutable-release-url archive-size archive-sha256\n' "${0##*/}" >&2
    exit 2
}

[ "$#" = 3 ] || usage

archive_url=$1
archive_size=$2
archive_sha256=$3

[[ "$archive_size" =~ ^[0-9]+$ ]] || exit 1
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ "$archive_url" =~ ^https://github\.com/SKALIFE/attendance/releases/download/v([0-9]+\.[0-9]+\.[0-9]+)/SKALA-Attendance-([0-9]+\.[0-9]+\.[0-9]+)-arm64\.zip$ ]] || exit 1
[ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ] || exit 1
