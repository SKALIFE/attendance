#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s --tag vX.Y.Z --project path/to/project.yml --appcast path/to/appcast.xml\n' "$(basename "$0")" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

tag=
project=
appcast=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tag)
            [ "$#" -ge 2 ] || usage
            tag=$2
            shift 2
            ;;
        --project)
            [ "$#" -ge 2 ] || usage
            project=$2
            shift 2
            ;;
        --appcast)
            [ "$#" -ge 2 ] || usage
            appcast=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$tag" ] && [ -n "$project" ] && [ -n "$appcast" ] || usage
[ -f "$project" ] || error "Project file not found: $project"
[ -f "$appcast" ] || error "Appcast file not found: $appcast"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Tag must use vX.Y.Z format: $tag"
fi

marketing_version=$(awk '
    /^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ {
        value = $0
        sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/[[:space:]"]/, "", value)
        print value
        exit
    }
' "$project")
build=$(awk '
    /^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*/ {
        value = $0
        sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/[[:space:]"]/, "", value)
        print value
        exit
    }
' "$project")

[ -n "$marketing_version" ] || error "MARKETING_VERSION is missing from $project."
[ -n "$build" ] || error "CURRENT_PROJECT_VERSION is missing from $project."

if [[ ! "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "MARKETING_VERSION must use X.Y.Z format: $marketing_version"
fi
if [[ ! "$build" =~ ^[0-9]+$ ]]; then
    error "CURRENT_PROJECT_VERSION must be a non-negative integer: $build"
fi

if [ "${tag#v}" != "$marketing_version" ]; then
    error "Tag $tag does not match marketing version $marketing_version."
fi

appcast_build=$(awk '
    function record(value) {
        if (value ~ /^[0-9]+$/ && (!found || value + 0 > max)) {
            max = value + 0
            found = 1
        }
    }
    {
        if (match($0, /<sparkle:version>[0-9]+<\/sparkle:version>/)) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^<sparkle:version>/, "", value)
            sub(/<\/sparkle:version>$/, "", value)
            record(value)
        }
        if (match($0, /sparkle:version="[0-9]+"/)) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^sparkle:version="/, "", value)
            sub(/"$/, "", value)
            record(value)
        }
    }
    END {
        if (found) {
            print max
        }
    }
' "$appcast")

[ -n "$appcast_build" ] || error "No numeric sparkle:version found in $appcast."

if (( 10#$build <= 10#$appcast_build )); then
    error "Build $build must be greater than current appcast build $appcast_build."
fi

printf 'Release metadata valid: tag %s, marketing version %s, build %s, appcast build %s.\n' \
    "$tag" "$marketing_version" "$build" "$appcast_build"
