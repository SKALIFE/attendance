#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
verification_archive=
verification_public_key=
verification_signature=
OPENSSL_BIN=${OPENSSL_BIN:-$(command -v openssl)}

usage() {
    printf 'Usage: %s vX.Y.Z [--project path] [--appcast path] --candidate path --archive path --archive-sha256 sha256 --sparkle-tools-root path [--archive-url url] [--release-probe path]\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

cleanup() {
    [ -z "$verification_archive" ] || rm -f "$verification_archive"
    [ -z "$verification_public_key" ] || rm -f "$verification_public_key"
    [ -z "$verification_signature" ] || rm -f "$verification_signature"
}

trap cleanup EXIT

project_value() {
    local key=$1

    awk -v key="$key" '
        $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
            value = $0
            sub(/^[^:]*:[[:space:]]*/, "", value)
            gsub(/[[:space:]"]/, "", value)
            print value
            exit
        }
    ' "$project"
}

candidate_value() {
    local expression=$1
    local prefix=$2
    local suffix=$3

    printf '%s' "$candidate_item" | awk -v expression="$expression" -v prefix="$prefix" -v suffix="$suffix" '
        $0 ~ expression {
            value = $0
            sub(/^[[:space:]]*/, "", value)
            sub(prefix, "", value)
            sub(suffix, "", value)
            count++
        }
        END {
            if (count == 1) print value
            else exit 1
        }
    '
}

baseline_contains() {
    local tag_name=$1
    local value=$2

    awk -v tag_name="$tag_name" -v value="$value" '
        $0 ~ "<sparkle:" tag_name ">" value "</sparkle:" tag_name ">" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$appcast"
}

run_helper_tests() {
    local test_script

    for test_script in \
        appcast_item_baseline_test.sh \
        appcast_item_test.sh \
        build_dmg_baseline_test.sh \
        ensure_release_absent_test.sh \
        notarize_baseline_test.sh \
        notarize_test.sh \
        package_release_test.sh \
        publish_appcast_test.sh \
        release_metadata_baseline_test.sh \
        release_metadata_test.sh \
        release_workflow_test.sh \
        verify_local_release_candidate_test.sh \
        verify_release_zip_test.sh; do
        bash "$ROOT/tests/$test_script"
    done
}

[ "$#" -ge 1 ] || usage
tag=$1
shift

project="$ROOT/project.yml"
appcast="$ROOT/tests/fixtures/current-appcast.xml"
candidate="$ROOT/release/appcast-candidate.xml"
archive=
archive_sha256=
sparkle_tools_root=
release_probe="$ROOT/scripts/verify-local-release-candidate.sh"

if [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    version=${BASH_REMATCH[1]}
else
    error "Tag must use vX.Y.Z format: $tag"
fi
archive_url="https://github.com/SKALIFE/attendance/releases/download/${tag}/SKALA-Attendance-${version}-arm64.zip"

while [ "$#" -gt 0 ]; do
    case "$1" in
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
        --candidate)
            [ "$#" -ge 2 ] || usage
            candidate=$2
            shift 2
            ;;
        --archive)
            [ "$#" -ge 2 ] || usage
            archive=$2
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
        --sparkle-tools-root)
            [ "$#" -ge 2 ] || usage
            sparkle_tools_root=$2
            shift 2
            ;;
        --release-probe)
            [ "$#" -ge 2 ] || usage
            release_probe=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$archive" ] && [ -n "$archive_sha256" ] && [ -n "$sparkle_tools_root" ] || usage
[ -f "$archive" ] && [ -r "$archive" ] || error 'Archive is missing or unreadable.'
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || error 'Expected archive SHA-256 must be lowercase hexadecimal.'
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "Release source is not a Git repository: $ROOT"
[ -z "$(git -C "$ROOT" status --porcelain)" ] || error 'Worktree has uncommitted changes.'

bash "$ROOT/scripts/validate-release-metadata.sh" --tag "$tag" --project "$project" --appcast "$appcast"
candidate_item=$(bash "$ROOT/scripts/validate-appcast-candidate.sh" \
    --candidate "$candidate" \
    --archive-url "$archive_url" \
    --archive-sha256 "$archive_sha256" \
    --release-probe "$release_probe" \
    --print-item)

marketing_version=$(project_value MARKETING_VERSION)
project_build=$(project_value CURRENT_PROJECT_VERSION)
sparkle_version=$(awk '
    /^  Sparkle:$/ { in_sparkle = 1; next }
    in_sparkle && /^  [^ ]/ { exit }
    in_sparkle && /^[[:space:]]*exactVersion:[[:space:]]*/ {
        value = $0
        sub(/^[^:]*:[[:space:]]*/, "", value)
        gsub(/[[:space:]"]/, "", value)
        print value
        exit
    }
' "$project")
public_key=$(project_value SUPublicEDKey)
[ "$marketing_version" = "$version" ] || error 'Project marketing version does not match release tag.'
[[ "$project_build" =~ ^[0-9]+$ ]] || error 'Project build is missing or invalid.'
[ "$sparkle_version" = '2.9.4' ] || error 'Project must pin Sparkle exactVersion: "2.9.4".'
[[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] || error 'Project SUPublicEDKey is missing or malformed.'

candidate_version=$(candidate_value '<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+</sparkle:shortVersionString>' '^<sparkle:shortVersionString>' '</sparkle:shortVersionString>$') || error 'Candidate appcast item must contain one semantic sparkle:shortVersionString.'
candidate_build=$(candidate_value '<sparkle:version>[0-9]+</sparkle:version>' '^<sparkle:version>' '</sparkle:version>$') || error 'Candidate appcast item must contain one numeric sparkle:version.'
candidate_signature=$(candidate_value 'sparkle:edSignature="[A-Za-z0-9+/]{86}=="' '^.*sparkle:edSignature="' '".*$') || error 'Candidate appcast item must contain one Sparkle EdDSA signature.'
candidate_length=$(printf '%s' "$candidate_item" | awk -v archive_url="$archive_url" '
    index($0, "url=\"" archive_url "\"") {
        if (match($0, /length="[0-9]+"/)) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^length="/, "", value)
            sub(/"$/, "", value)
            count++
        }
    }
    END {
        if (count == 1) print value
        else exit 1
    }
') || error 'Candidate appcast item must contain one release enclosure with a numeric length.'

[ "$candidate_version" = "$version" ] || error "Candidate version $candidate_version does not match release tag $tag."
[ "$candidate_build" = "$project_build" ] || error "Candidate build $candidate_build does not match project build $project_build."
baseline_contains shortVersionString "$candidate_version" && error "Candidate version $candidate_version already exists in baseline appcast."
baseline_contains version "$candidate_build" && error "Candidate build $candidate_build already exists in baseline appcast."

archive_size=$(stat -f '%z' "$archive") || error 'Unable to determine archive size.'
archive_digest=$(shasum -a 256 "$archive" | awk '{print $1}') || error 'Unable to digest archive.'
[ "$candidate_length" = "$archive_size" ] || error 'Candidate appcast enclosure length does not match archive size.'
[ "$archive_digest" = "$archive_sha256" ] || error 'Archive SHA-256 does not match the expected release asset digest.'
/usr/bin/unzip -tqq "$archive" >/dev/null 2>&1 || error 'Archive ZIP integrity validation failed.'

sparkle_tools_root=$(cd "$sparkle_tools_root" && pwd -P) || error 'Pinned Sparkle tools root is missing or unreadable.'
sparkle_sign_update="$sparkle_tools_root/bin/sign_update"
[ -x "$sparkle_sign_update" ] || error 'Pinned Sparkle sign_update is missing or not executable.'
signer_directory=$(cd "$(dirname "$sparkle_sign_update")" && pwd -P)
case "$signer_directory/" in "$sparkle_tools_root/"*) ;; *) error 'Pinned Sparkle signer escapes the tools root.' ;; esac
[ -x "$OPENSSL_BIN" ] || error 'OpenSSL is missing or not executable.'
verification_archive=$(mktemp "${TMPDIR:-/tmp}/skala-preflight-archive.XXXXXX") || error 'Unable to create verification archive copy.'
cp -p "$archive" "$verification_archive" || error 'Unable to create verification archive copy.'
verification_public_key=$(mktemp "${TMPDIR:-/tmp}/skala-preflight-public-key.XXXXXX") || error 'Unable to prepare Sparkle public key.'
verification_signature=$(mktemp "${TMPDIR:-/tmp}/skala-preflight-signature.XXXXXX") || error 'Unable to prepare Sparkle signature.'
printf '\060\052\060\005\006\003\053\145\160\003\041\000' >"$verification_public_key"
printf '%s' "$public_key" | /usr/bin/base64 -D >>"$verification_public_key" || error 'Project SUPublicEDKey is missing or malformed.'
printf '%s' "$candidate_signature" | /usr/bin/base64 -D >"$verification_signature" || error 'Candidate appcast item must contain one Sparkle EdDSA signature.'
"$OPENSSL_BIN" pkeyutl -verify -rawin -pubin -keyform DER -inkey "$verification_public_key" -in "$verification_archive" -sigfile "$verification_signature" >/dev/null 2>&1 || error 'Sparkle signature verification failed.'
verification_size=$(stat -f '%z' "$verification_archive") || error 'Unable to determine verification archive size.'
verification_digest=$(shasum -a 256 "$verification_archive" | awk '{print $1}') || error 'Unable to digest verification archive.'
[ "$verification_size" = "$archive_size" ] && [ "$verification_digest" = "$archive_digest" ] || error 'Verification archive changed during Sparkle verification.'
original_size_after_verification=$(stat -f '%z' "$archive") || error 'Unable to determine original archive size after Sparkle verification.'
original_digest_after_verification=$(shasum -a 256 "$archive" | awk '{print $1}') || error 'Unable to digest original archive after Sparkle verification.'
[ "$original_size_after_verification" = "$archive_size" ] && [ "$original_digest_after_verification" = "$archive_digest" ] || error 'Original archive changed during Sparkle verification.'

run_helper_tests

printf 'Release preflight passed: tag %s.\n' "$tag"
