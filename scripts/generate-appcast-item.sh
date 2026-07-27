#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s --tag vX.Y.Z --build N --archive path/to/archive.zip --archive-sha256 SHA256 --archive-url immutable-release-url --appcast path/to/appcast.xml --project project.yml --sparkle-tools-root path/to/pinned-tools --release-probe path/to/probe [--write]\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

cleanup() {
    [ -z "${candidate:-}" ] || rm -f "$candidate"
    [ -z "${archive_backup:-}" ] || rm -f "$archive_backup"
    [ -z "${private_key_der:-}" ] || rm -f "$private_key_der"
    [ -z "${private_key_data:-}" ] || rm -f "$private_key_data"
    unset private_key_material
}

restore_archive() {
    if ! cmp -s "$archive_backup" "$archive"; then
        cp -p "$archive_backup" "$archive" || error 'Archive integrity restoration failed.'
    fi
    cmp -s "$archive_backup" "$archive" || error 'Archive integrity restoration failed.'
}

fail_after_signing() {
    local message=$1

    restore_archive
    error "$message"
}

validate_xml() {
    command -v "$XMLLINT_BIN" >/dev/null 2>&1 || error 'xmllint is required to validate appcast XML.'
    "$XMLLINT_BIN" --nonet --noout "$1" >/dev/null 2>&1 || error 'Appcast XML is not well-formed.'
}

maximum_build() {
    awk '
        function record(value) {
            if (value ~ /^[0-9]+$/ && (!found || value + 0 > maximum)) {
                maximum = value + 0
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
            if (found) print maximum
        }
    ' "$1"
}

version_is_greater() {
    local candidate=$1
    local existing=$2
    local candidate_major candidate_minor candidate_patch existing_major existing_minor existing_patch

    IFS=. read -r candidate_major candidate_minor candidate_patch <<<"$candidate"
    IFS=. read -r existing_major existing_minor existing_patch <<<"$existing"
    (( 10#$candidate_major > 10#$existing_major )) && return 0
    (( 10#$candidate_major < 10#$existing_major )) && return 1
    (( 10#$candidate_minor > 10#$existing_minor )) && return 0
    (( 10#$candidate_minor < 10#$existing_minor )) && return 1
    (( 10#$candidate_patch > 10#$existing_patch ))
}

read_project_metadata() {
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
    public_key=$(awk '
        /^[[:space:]]*SUPublicEDKey:[[:space:]]*/ {
            value = $0
            sub(/^[^:]*:[[:space:]]*/, "", value)
            gsub(/[[:space:]"]/, "", value)
            print value
            exit
        }
    ' "$project")

    [ "$sparkle_version" = '2.9.4' ] || error 'Project must pin Sparkle exactVersion: "2.9.4".'
    [[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] || error 'Project SUPublicEDKey is missing or malformed.'
}

resolve_sparkle_tools() {
    local signer_directory

    sparkle_tools_root=$(cd "$sparkle_tools_root" && pwd -P) || error 'Pinned Sparkle tools root is missing or unreadable.'
    sparkle_sign_update="$sparkle_tools_root/bin/sign_update"
    [ -x "$sparkle_sign_update" ] || error 'Pinned Sparkle sign_update is missing or not executable.'

    signer_directory=$(cd "$(dirname "$sparkle_sign_update")" && pwd -P)
    case "$signer_directory/" in "$sparkle_tools_root/"*) ;; *) error 'Pinned Sparkle signer escapes the tools root.' ;; esac
}

resolve_openssl() {
    local candidate

    for candidate in "${OPENSSL_BIN:-}" "$(command -v openssl 2>/dev/null || true)" \
        /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl; do
        [ -n "$candidate" ] && [ -x "$candidate" ] || continue
        if "$candidate" list -public-key-algorithms 2>/dev/null | grep -Fq ED25519; then
            openssl_bin=$candidate
            return
        fi
    done

    error 'An OpenSSL binary with Ed25519 support is required to validate the Sparkle signing key.'
}

derive_signing_public_key() {
    local key_size

    resolve_openssl
    private_key_data=$(mktemp "$appcast_dir/.sparkle-private-key.XXXXXX") || error 'Unable to prepare Sparkle signing key validation.'
    chmod 600 "$private_key_data" || error 'Unable to prepare Sparkle signing key validation.'
    if ! printf '%s' "$private_key_material" | /usr/bin/base64 -D >"$private_key_data" 2>/dev/null; then
        error 'SPARKLE_EDDSA_PRIVATE_KEY is invalid.'
    fi
    key_size=$(stat -f '%z' "$private_key_data") || error 'SPARKLE_EDDSA_PRIVATE_KEY is invalid.'

    case "$key_size" in
        32)
            private_key_der=$(mktemp "$appcast_dir/.sparkle-private-key-der.XXXXXX") || error 'Unable to prepare Sparkle signing key validation.'
            chmod 600 "$private_key_der" || error 'Unable to prepare Sparkle signing key validation.'
            printf '\060\056\002\001\000\060\005\006\003\053\145\160\004\042\004\040' >"$private_key_der"
            cat "$private_key_data" >>"$private_key_der"
            signing_public_key=$("$openssl_bin" pkey -inform DER -in "$private_key_der" -pubout -outform DER 2>/dev/null |
                dd bs=1 skip=12 2>/dev/null | "$openssl_bin" base64 -A) || error 'Unable to derive the Sparkle signing public key.'
            ;;
        96)
            signing_public_key=$(dd if="$private_key_data" bs=1 skip=64 count=32 2>/dev/null | "$openssl_bin" base64 -A) || error 'Unable to derive the Sparkle signing public key.'
            ;;
        *)
            error 'SPARKLE_EDDSA_PRIVATE_KEY is invalid.'
            ;;
    esac
}

ensure_clean_worktree() {
    local worktree

    worktree=$(git -C "$appcast_dir" rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$worktree" ] && [ -n "$(git -C "$worktree" status --porcelain)" ]; then
        error 'Refusing to mutate appcast in a dirty worktree.'
    fi
}

tag=
build=
archive=
archive_sha256=
archive_url=
appcast=
project=
sparkle_tools_root=
release_probe=
write=false
candidate=
archive_backup=
XMLLINT_BIN=${XMLLINT_BIN:-xmllint}
script_dir=$(cd "$(dirname "$0")" && pwd -P)

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tag)
            [ "$#" -ge 2 ] || usage
            tag=$2
            shift 2
            ;;
        --build)
            [ "$#" -ge 2 ] || usage
            build=$2
            shift 2
            ;;
        --archive)
            [ "$#" -ge 2 ] || usage
            archive=$2
            shift 2
            ;;
        --archive-sha256)
            [ "$#" -ge 2 ] || usage
            archive_sha256=$2
            shift 2
            ;;
        --archive-url)
            [ "$#" -ge 2 ] || usage
            archive_url=$2
            shift 2
            ;;
        --appcast)
            [ "$#" -ge 2 ] || usage
            appcast=$2
            shift 2
            ;;
        --project)
            [ "$#" -ge 2 ] || usage
            project=$2
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
        --write)
            write=true
            shift
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$tag" ] && [ -n "$build" ] && [ -n "$archive" ] && [ -n "$archive_sha256" ] && [ -n "$archive_url" ] && [ -n "$appcast" ] && [ -n "$project" ] && [ -n "$sparkle_tools_root" ] && [ -n "$release_probe" ] || usage
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Tag must use vX.Y.Z format: $tag"
[[ "$build" =~ ^[0-9]+$ ]] || error "Build must be a non-negative integer: $build"
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || error 'Expected archive SHA-256 must be lowercase hexadecimal.'
[ -f "$archive" ] && [ -r "$archive" ] || error 'Archive is missing or unreadable.'
[ -f "$appcast" ] && [ -r "$appcast" ] || error 'Appcast file is missing or unreadable.'
[ -f "$project" ] && [ -r "$project" ] || error 'Project file is missing or unreadable.'
[ -x "$release_probe" ] || error 'Release availability probe is missing or not executable.'

private_key_material=${SPARKLE_EDDSA_PRIVATE_KEY:-}
unset SPARKLE_EDDSA_PRIVATE_KEY
[ -n "$private_key_material" ] || error 'SPARKLE_EDDSA_PRIVATE_KEY is required for Sparkle signing.'
trap cleanup EXIT

version=${tag#v}
archive_name=$(basename "$archive")
expected_archive_name="SKALA-Attendance-$version-arm64.zip"
[ "$archive_name" = "$expected_archive_name" ] || error "Archive name must be $expected_archive_name."
expected_archive_url="https://github.com/SKALIFE/attendance/releases/download/$tag/$archive_name"
[ "$archive_url" = "$expected_archive_url" ] || error "Archive URL must be the immutable GitHub Release asset URL for $tag."

appcast_dir=$(cd "$(dirname "$appcast")" && pwd -P)
[ "$write" = false ] || ensure_clean_worktree
validate_xml "$appcast"
read_project_metadata
resolve_sparkle_tools
derive_signing_public_key
[ "$signing_public_key" = "$public_key" ] || error 'Signing key does not match project SUPublicEDKey.'

current_build=$(maximum_build "$appcast")
[ -n "$current_build" ] || error 'No numeric sparkle:version found in appcast.'
if (( 10#$build <= 10#$current_build )); then
    error "Build $build must be greater than current appcast build $current_build."
fi

while IFS= read -r existing_version; do
    [[ "$existing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error 'Appcast contains an invalid sparkle:shortVersionString.'
    version_is_greater "$version" "$existing_version" || error "Version $version must be greater than existing appcast version $existing_version."
done < <(awk '
    match($0, /<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<\/sparkle:shortVersionString>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:shortVersionString>/, "", value)
        sub(/<\/sparkle:shortVersionString>$/, "", value)
        print value
    }
' "$appcast")

/usr/bin/unzip -tqq "$archive" >/dev/null 2>&1 || error 'Archive ZIP integrity validation failed.'
archive_size=$(stat -f '%z' "$archive") || error 'Unable to determine archive size.'
[[ "$archive_size" =~ ^[0-9]+$ ]] || error 'Unable to determine archive size.'
archive_digest=$(shasum -a 256 "$archive" | awk '{print $1}') || error 'Unable to digest archive.'
[[ "$archive_digest" =~ ^[0-9a-f]{64}$ ]] || error 'Unable to digest archive.'
[ "$archive_digest" = "$archive_sha256" ] || error 'Archive SHA-256 does not match the expected release asset digest.'

env -i PATH=/usr/bin:/bin "$release_probe" "$archive_url" "$archive_size" "$archive_sha256" || error 'Release asset availability check failed.'

archive_backup=$(mktemp "$appcast_dir/.appcast-archive.XXXXXX") || error 'Unable to preserve archive integrity before signing.'
cp -p "$archive" "$archive_backup" || error 'Unable to preserve archive integrity before signing.'

signer_output=$(printf '%s\n' "$private_key_material" | env -i PATH=/usr/bin:/bin "$sparkle_sign_update" --ed-key-file - "$archive") || fail_after_signing 'Sparkle sign_update failed.'
if [[ ! "$signer_output" =~ ^sparkle:edSignature=\"([A-Za-z0-9+/]{86}==)\"[[:space:]]length=\"([0-9]+)\"$ ]]; then
    fail_after_signing 'Sparkle sign_update returned invalid signature metadata.'
fi
signature=${BASH_REMATCH[1]}
signed_length=${BASH_REMATCH[2]}
[ "$signed_length" = "$archive_size" ] || fail_after_signing 'Sparkle sign_update length does not match archive size.'

printf '%s\n' "$private_key_material" | env -i PATH=/usr/bin:/bin "$sparkle_sign_update" --verify --ed-key-file - "$archive" "$signature" || fail_after_signing 'Sparkle signature verification failed.'
verified_size=$(stat -f '%z' "$archive") || fail_after_signing 'Unable to determine archive size after signing.'
verified_digest=$(shasum -a 256 "$archive" | awk '{print $1}') || fail_after_signing 'Unable to digest archive after signing.'
if [ "$archive_size" != "$verified_size" ] || [ "$archive_sha256" != "$verified_digest" ]; then
    fail_after_signing 'Archive changed while it was being signed.'
fi

rm -f "$archive_backup"
archive_backup=
candidate=$(mktemp "$appcast_dir/.appcast-item.XXXXXX") || error 'Unable to create appcast candidate.'

item=$(cat <<EOF
    <item>
      <title>Version $version</title>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <enclosure url="$archive_url" length="$archive_size" type="application/octet-stream" sparkle:edSignature="$signature" sparkle:version="$build" sparkle:shortVersionString="$version" sparkle:minimumSystemVersion="14.0" sparkle:os="macos" sparkle:arch="arm64" />
    </item>
EOF
)

inserted=false
while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" >>"$candidate"
    if [ "$inserted" = false ] && [[ "$line" =~ ^[[:space:]]*\<channel([[:space:]]|\>) ]]; then
        printf '%s\n' "$item" >>"$candidate"
        inserted=true
    fi
done <"$appcast"
[ "$inserted" = true ] || error 'Appcast XML is not well-formed.'
validate_xml "$candidate"
bash "$script_dir/validate-appcast-candidate.sh" \
    --candidate "$candidate" --archive-url "$archive_url" --archive-sha256 "$archive_sha256" \
    --release-probe "$release_probe" >/dev/null

if [ "$write" = true ]; then
    mv "$candidate" "$appcast"
    candidate=
    cat "$appcast"
else
    cat "$candidate"
fi
