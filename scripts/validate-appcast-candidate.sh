#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s --candidate path/to/appcast.xml --archive-url immutable-release-url --archive-sha256 SHA256 --release-probe path/to/probe [--print-item]\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

extract_item() {
    awk -v archive_url="$archive_url" '
        /^[[:space:]]*<item([[:space:]>])/ && !in_item {
            in_item = 1
            item = ""
        }
        in_item {
            item = item $0 ORS
        }
        in_item && /^[[:space:]]*<\/item>/ {
            if (index(item, "url=\"" archive_url "\"")) {
                matches++
                matched_item = item
            }
            in_item = 0
        }
        END {
            if (matches != 1) exit 1
            printf "%s", matched_item
        }
    ' "$candidate"
}

candidate=
archive_url=
archive_sha256=
release_probe=
print_item=false
XMLLINT_BIN=${XMLLINT_BIN:-xmllint}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --candidate)
            [ "$#" -ge 2 ] || usage
            candidate=$2
            shift 2
            ;;
        --archive-url)
            [ "$#" -ge 2 ] || usage
            archive_url=$2
            shift 2
            ;;
        --archive-sha256)
            [ "$#" -ge 2 ] || usage
            archive_sha256=$2
            shift 2
            ;;
        --release-probe)
            [ "$#" -ge 2 ] || usage
            release_probe=$2
            shift 2
            ;;
        --print-item)
            print_item=true
            shift
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$candidate" ] && [ -n "$archive_url" ] && [ -n "$archive_sha256" ] && [ -n "$release_probe" ] || usage
[ -f "$candidate" ] && [ -r "$candidate" ] || error 'Candidate appcast file is missing or unreadable.'
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || error 'Expected archive SHA-256 must be lowercase hexadecimal.'
[ -x "$release_probe" ] || error 'Release availability probe is missing or not executable.'
command -v "$XMLLINT_BIN" >/dev/null 2>&1 || error 'xmllint is required to validate appcast XML.'
"$XMLLINT_BIN" --nonet --noout "$candidate" >/dev/null 2>&1 || error 'Candidate appcast XML is not well-formed.'

item=$(extract_item) || error 'Candidate appcast must contain exactly one item for the expected release ZIP URL.'
build=$(printf '%s' "$item" | awk '
    match($0, /<sparkle:version>[0-9]+<\/sparkle:version>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:version>/, "", value)
        sub(/<\/sparkle:version>$/, "", value)
        count++
    }
    END {
        if (count == 1) print value
        else exit 1
    }
') || error 'Candidate appcast item must contain one numeric sparkle:version.'
version=$(printf '%s' "$item" | awk '
    match($0, /<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<\/sparkle:shortVersionString>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:shortVersionString>/, "", value)
        sub(/<\/sparkle:shortVersionString>$/, "", value)
        count++
    }
    END {
        if (count == 1) print value
        else exit 1
    }
') || error 'Candidate appcast item must contain one semantic sparkle:shortVersionString.'
length=$(printf '%s' "$item" | awk -v archive_url="$archive_url" '
    index($0, "url=\"" archive_url "\"") {
        count++
        if (match($0, /length="[0-9]+"/)) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^length="/, "", value)
            sub(/"$/, "", value)
        }
    }
    END {
        if (count == 1 && value ~ /^[0-9]+$/) print value
        else exit 1
    }
') || error 'Candidate appcast item must contain one release enclosure with a numeric length.'

printf '%s' "$item" | grep -Eq 'sparkle:edSignature="[A-Za-z0-9+/]{86}=="' || error 'Candidate appcast item is missing a valid Sparkle EdDSA signature.'
env -i PATH=/usr/bin:/bin "$release_probe" "$archive_url" "$length" "$archive_sha256" || error 'Release asset availability check failed.'

if [ "$print_item" = true ]; then
    printf '%s' "$item"
else
    printf 'Candidate appcast valid: version %s, build %s.\n' "$version" "$build"
fi
