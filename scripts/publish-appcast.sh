#!/bin/bash
set -euo pipefail
set +x

usage() {
    printf 'Usage: %s --candidate path/to/appcast.xml --archive-url immutable-release-url --archive-sha256 SHA256 --release-probe path/to/probe --target-repo local-path-or-approved-https-url --branch branch --appcast-path relative/path.xml\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

cleanup() {
    unset APPCAST_REPO_TOKEN
    [ -z "${workspace:-}" ] || /bin/rm -rf "$workspace" || return 1
    workspace=
}

cleanup_on_exit() {
    local status=$?

    cleanup || exit 1
    exit "$status"
}

validate_xml() {
    "$XMLLINT_BIN" --nonet --noout "$1" >/dev/null 2>&1 || error 'Target appcast XML is not well-formed.'
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
    local candidate_version=$1
    local existing_version=$2
    local candidate_major candidate_minor candidate_patch existing_major existing_minor existing_patch

    IFS=. read -r candidate_major candidate_minor candidate_patch <<<"$candidate_version"
    IFS=. read -r existing_major existing_minor existing_patch <<<"$existing_version"
    (( 10#$candidate_major > 10#$existing_major )) && return 0
    (( 10#$candidate_major < 10#$existing_major )) && return 1
    (( 10#$candidate_minor > 10#$existing_minor )) && return 0
    (( 10#$candidate_minor < 10#$existing_minor )) && return 1
    (( 10#$candidate_patch > 10#$existing_patch ))
}

item_value() {
    local expression=$1

    printf '%s' "$candidate_item" | awk "$expression"
}

candidate=
archive_url=
archive_sha256=
release_probe=
target_repo=
branch=
appcast_path=
raw_appcast_url=
workspace=
appcast_repo_token=
XMLLINT_BIN=${XMLLINT_BIN:-xmllint}
CURL_BIN=${CURL_BIN:-/usr/bin/curl}
script_dir=$(cd "$(dirname "$0")" && pwd -P)

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
        --target-repo)
            [ "$#" -ge 2 ] || usage
            target_repo=$2
            shift 2
            ;;
        --branch)
            [ "$#" -ge 2 ] || usage
            branch=$2
            shift 2
            ;;
        --appcast-path)
            [ "$#" -ge 2 ] || usage
            appcast_path=$2
            shift 2
            ;;
        --raw-appcast-url)
            [ "$#" -ge 2 ] || usage
            raw_appcast_url=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$candidate" ] && [ -n "$archive_url" ] && [ -n "$archive_sha256" ] && [ -n "$release_probe" ] && [ -n "$target_repo" ] && [ -n "$branch" ] && [ -n "$appcast_path" ] || usage
[[ "$branch" =~ ^[A-Za-z0-9._/-]+$ ]] || error 'Target branch contains unsupported characters.'
[[ "$appcast_path" != /* && "$appcast_path" != *'..'* && "$appcast_path" == *.xml ]] || error 'Appcast path must be a relative XML path without parent traversal.'
command -v "$XMLLINT_BIN" >/dev/null 2>&1 || error 'xmllint is required to validate appcast XML.'
[ -z "$raw_appcast_url" ] || [ -x "$CURL_BIN" ] || error 'Configured curl binary is missing or not executable.'

case "$target_repo" in
    https://github.com/SKALIFE/attendance-appcast.git)
        [ -n "${APPCAST_REPO_TOKEN:-}" ] || error 'APPCAST_REPO_TOKEN is required for the approved appcast repository.'
        appcast_repo_token=$APPCAST_REPO_TOKEN
        remote_target=true
        ;;
    /*|./*|../*)
        [ -d "$target_repo" ] || error 'Local appcast target repository is missing.'
        remote_target=false
        ;;
    *)
        error 'Target repository must be a local test repository or the approved appcast repository.'
        ;;
esac
unset APPCAST_REPO_TOKEN

candidate_item=$(bash "$script_dir/validate-appcast-candidate.sh" \
    --candidate "$candidate" --archive-url "$archive_url" --archive-sha256 "$archive_sha256" \
    --release-probe "$release_probe" --print-item) || exit 1
candidate_build=$(item_value '
    match($0, /<sparkle:version>[0-9]+<\/sparkle:version>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:version>/, "", value)
        sub(/<\/sparkle:version>$/, "", value)
        print value
        exit
    }
')
candidate_version=$(item_value '
    match($0, /<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<\/sparkle:shortVersionString>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:shortVersionString>/, "", value)
        sub(/<\/sparkle:shortVersionString>$/, "", value)
        print value
        exit
    }
')

workspace=$(mktemp -d "${TMPDIR:-/tmp}/appcast-publisher.XXXXXX") || error 'Unable to create temporary appcast publisher workspace.'
trap cleanup_on_exit EXIT
clone_dir="$workspace/target"

if [ "$remote_target" = true ]; then
    set +x
    askpass="$workspace/git-askpass"
    token_file="$workspace/token"
    umask 077
    cat >"$token_file" <<EOF
$appcast_repo_token
EOF
    unset appcast_repo_token
    cat >"$askpass" <<'EOF'
#!/bin/sh
case "$1" in
    *Username*) printf '%s\n' 'x-access-token' ;;
    *Password*) cat "$APPCAST_REPO_TOKEN_FILE" ;;
    *) exit 1 ;;
esac
EOF
    chmod 700 "$askpass"
    APPCAST_REPO_TOKEN_FILE="$token_file" GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0 \
        env -u APPCAST_REPO_TOKEN git clone --no-tags --branch "$branch" "$target_repo" "$clone_dir"
else
    env -u APPCAST_REPO_TOKEN -u LEAK_MARKER -u GIT_ASKPASS -u GIT_TERMINAL_PROMPT \
        git clone --no-tags --branch "$branch" "$target_repo" "$clone_dir"
fi

git -C "$clone_dir" symbolic-ref --quiet --short HEAD | grep -Fx -- "$branch" >/dev/null || error 'Temporary clone did not check out the requested branch.'
[ -z "$(git -C "$clone_dir" status --porcelain)" ] || error 'Temporary clone is unexpectedly dirty.'
target_appcast="$clone_dir/$appcast_path"
[ -f "$target_appcast" ] && [ -r "$target_appcast" ] || error 'Target appcast XML is missing or unreadable.'
validate_xml "$target_appcast"

current_build=$(maximum_build "$target_appcast")
[ -n "$current_build" ] || error 'Target appcast contains no numeric sparkle:version.'
if (( 10#$candidate_build <= 10#$current_build )); then
    error "Candidate build $candidate_build must be greater than target appcast build $current_build."
fi
while IFS= read -r existing_version; do
    [[ "$existing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error 'Target appcast contains an invalid sparkle:shortVersionString.'
    version_is_greater "$candidate_version" "$existing_version" || error "Candidate version $candidate_version must be greater than target appcast version $existing_version."
done < <(awk '
    match($0, /<sparkle:shortVersionString>[0-9]+\.[0-9]+\.[0-9]+<\/sparkle:shortVersionString>/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^<sparkle:shortVersionString>/, "", value)
        sub(/<\/sparkle:shortVersionString>$/, "", value)
        print value
    }
' "$target_appcast")
if grep -Fq -- "url=\"$archive_url\"" "$target_appcast"; then
    error 'Candidate release ZIP URL already exists in the target appcast.'
fi

updated_appcast="$workspace/appcast.xml"
inserted=false
while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" >>"$updated_appcast"
    if [ "$inserted" = false ] && [[ "$line" =~ ^[[:space:]]*\<channel([[:space:]]|\>) ]]; then
        printf '%s\n' "$candidate_item" >>"$updated_appcast"
        inserted=true
    fi
done <"$target_appcast"
[ "$inserted" = true ] || error 'Target appcast XML does not contain a channel element.'
validate_xml "$updated_appcast"
cp "$updated_appcast" "$target_appcast"

expected_status=" M $appcast_path"
[ "$(git -C "$clone_dir" status --porcelain)" = "$expected_status" ] || error 'Publisher must modify only the target appcast XML.'
git -C "$clone_dir" add -- "$appcast_path"
[ "$(git -C "$clone_dir" diff --cached --name-only)" = "$appcast_path" ] || error 'Publisher staged files outside the target appcast XML.'
git -C "$clone_dir" diff --cached --quiet && error 'Publisher did not create an appcast XML update.'
git -C "$clone_dir" -c user.name='SKALA Appcast Publisher' -c user.email='appcast-publisher@skalife.kr' \
    commit -m "Publish SKALA Attendance $candidate_version" >/dev/null

if [ "$remote_target" = true ]; then
    APPCAST_REPO_TOKEN_FILE="$token_file" GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0 \
        env -u APPCAST_REPO_TOKEN git -C "$clone_dir" push origin "HEAD:refs/heads/$branch"
    APPCAST_REPO_TOKEN_FILE="$token_file" GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0 \
        env -u APPCAST_REPO_TOKEN git -C "$clone_dir" fetch --no-tags origin "$branch"
else
    env -u APPCAST_REPO_TOKEN -u LEAK_MARKER -u GIT_ASKPASS -u GIT_TERMINAL_PROMPT \
        git -C "$clone_dir" push origin "HEAD:refs/heads/$branch"
    env -u APPCAST_REPO_TOKEN -u LEAK_MARKER -u GIT_ASKPASS -u GIT_TERMINAL_PROMPT \
        git -C "$clone_dir" fetch --no-tags origin "$branch"
fi
git -C "$clone_dir" show "origin/$branch:$appcast_path" | cmp -s - "$updated_appcast" || error 'Refetched appcast does not match the published XML.'

if [ -n "$raw_appcast_url" ]; then
    raw_appcast="$workspace/raw-appcast.xml"
    env -u APPCAST_REPO_TOKEN -u LEAK_MARKER "$CURL_BIN" --fail --location --silent --show-error --output "$raw_appcast" "$raw_appcast_url" || error 'Raw appcast fetch failed.'
    validate_xml "$raw_appcast"
    raw_item=$(bash "$script_dir/validate-appcast-candidate.sh" \
        --candidate "$raw_appcast" --archive-url "$archive_url" --archive-sha256 "$archive_sha256" \
        --release-probe "$release_probe" --print-item) || exit 1
    printf '%s' "$candidate_item" | cmp -s - <(printf '%s' "$raw_item") || error 'Raw appcast does not contain the published release item.'
fi

cleanup || error 'Unable to remove temporary appcast publisher workspace.'
trap - EXIT
printf 'Published appcast version %s build %s.\n' "$candidate_version" "$candidate_build"
