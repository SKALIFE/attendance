#!/bin/bash
set -euo pipefail

case $- in
    *x*) set +x ;;
esac

usage() {
    printf 'Usage: %s [--app path/to/SKALA\ Attendance.app] [--dmg path/to/SKALA-Attendance-X.Y.Z-arm64.dmg] [--zip path/to/SKALA-Attendance-X.Y.Z-arm64.zip]\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_environment() {
    local name=$1

    [ -n "${!name:-}" ] || error "$name is required."
}

read_app_version() {
    local app_path=$1
    local version

    [ -d "$app_path" ] && [ -f "$app_path/Contents/Info.plist" ] || error 'Notarization artifact is missing or invalid.'
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist" 2>/dev/null) || error 'Notarization artifact is missing or invalid.'
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error 'Notarization artifact is missing or invalid.'
    printf '%s\n' "$version"
}

read_archive_version() {
    local archive_path=$1
    local extension=$2
    local archive_name=${archive_path##*/}

    [ -f "$archive_path" ] || error 'Notarization artifact is missing or invalid.'
    if [[ "$archive_name" =~ ^SKALA-Attendance-([0-9]+\.[0-9]+\.[0-9]+)-arm64\.$extension$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return
    fi

    error 'Notarization artifact is missing or invalid.'
}

submit_for_notarization() {
    local artifact=$1

    if ! xcrun notarytool submit "$artifact" \
        --key "$key_path" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" \
        --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --wait >/dev/null 2>&1; then
        error 'Notarization submission failed.'
    fi
}

staple_and_assess() {
    local artifact=$1

    if ! xcrun stapler staple "$artifact" >/dev/null 2>&1; then
        error 'Stapling failed.'
    fi

    if ! xcrun stapler validate "$artifact" >/dev/null 2>&1; then
        error 'Stapler validation failed.'
    fi

    if ! spctl --assess --verbose=4 "$artifact" >/dev/null 2>&1; then
        error 'Gatekeeper assessment failed.'
    fi
}

notarize_app() {
    local app=$1

    app_archive_dir=$(mktemp -d "${TMPDIR:-/tmp}/skala-notary-app.XXXXXX" 2>/dev/null) || error 'Unable to prepare app notarization archive.'
    app_archive="$app_archive_dir/SKALA Attendance.zip"
    if ! /usr/bin/ditto -c -k --keepParent "$app" "$app_archive" >/dev/null 2>&1; then
        error 'Unable to prepare app notarization archive.'
    fi
    submit_for_notarization "$app_archive"
    staple_and_assess "$app"
}

verify_zip_app() {
    local zip_path=$1
    local expected_version=$2
    local extracted_app
    local extracted_version

    zip_temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/skala-notary-zip.XXXXXX" 2>/dev/null) || error 'ZIP verification failed.'
    if ! unzip -q "$zip_path" -d "$zip_temp_dir" >/dev/null 2>&1; then
        error 'ZIP verification failed.'
    fi

    extracted_app="$zip_temp_dir/SKALA Attendance.app"
    extracted_version=$(read_app_version "$extracted_app")
    [ "$extracted_version" = "$expected_version" ] || error 'Artifact versions do not match.'

    if ! xcrun stapler validate "$extracted_app" >/dev/null 2>&1; then
        error 'Stapler validation failed.'
    fi

    if ! spctl --assess --verbose=4 "$extracted_app" >/dev/null 2>&1; then
        error 'Gatekeeper assessment failed.'
    fi
}

app_path=
dmg_path=
zip_path=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --app)
            [ "$#" -ge 2 ] || usage
            [ -z "$app_path" ] || usage
            app_path=$2
            shift 2
            ;;
        --dmg)
            [ "$#" -ge 2 ] || usage
            [ -z "$dmg_path" ] || usage
            dmg_path=$2
            shift 2
            ;;
        --zip)
            [ "$#" -ge 2 ] || usage
            [ -z "$zip_path" ] || usage
            zip_path=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

private_key_material=
export -n private_key_material
if [ -n "${APP_STORE_CONNECT_PRIVATE_KEY_BASE64+x}" ]; then
    private_key_material=$APP_STORE_CONNECT_PRIVATE_KEY_BASE64
fi
unset APP_STORE_CONNECT_PRIVATE_KEY_BASE64

[ -n "$app_path$dmg_path$zip_path" ] || error 'A notarization artifact is required.'

app_version=
dmg_version=
zip_version=
if [ -n "$app_path" ]; then
    app_version=$(read_app_version "$app_path")
fi
if [ -n "$dmg_path" ]; then
    dmg_version=$(read_archive_version "$dmg_path" dmg)
fi
if [ -n "$zip_path" ]; then
    zip_version=$(read_archive_version "$zip_path" zip)
fi

version=${app_version:-${dmg_version:-$zip_version}}
for artifact_version in "$app_version" "$dmg_version" "$zip_version"; do
    [ -z "$artifact_version" ] || [ "$artifact_version" = "$version" ] || error 'Artifact versions do not match.'
done

require_environment APPLE_TEAM_ID
require_environment APP_STORE_CONNECT_ISSUER_ID
require_environment APP_STORE_CONNECT_KEY_ID
[ -n "$private_key_material" ] || error 'APP_STORE_CONNECT_PRIVATE_KEY_BASE64 is required.'

key_path=
zip_temp_dir=
app_archive_dir=
app_archive=
cleanup() {
    local cleanup_failed=0

    if [ -n "$key_path" ] && [ -e "$key_path" ] && ! rm -f "$key_path" >/dev/null 2>&1; then
        cleanup_failed=1
    fi
    if [ -n "$zip_temp_dir" ] && [ -e "$zip_temp_dir" ] && ! rm -rf "$zip_temp_dir" >/dev/null 2>&1; then
        cleanup_failed=1
    fi
    if [ -n "$app_archive_dir" ] && [ -e "$app_archive_dir" ] && ! rm -rf "$app_archive_dir" >/dev/null 2>&1; then
        cleanup_failed=1
    fi

    [ "$cleanup_failed" -eq 0 ]
}

on_exit() {
    local status=$?

    trap - EXIT
    if ! cleanup; then
        printf 'Temporary credential cleanup failed.\n' >&2
        exit 1
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 1' HUP INT TERM

key_path=$(mktemp "${TMPDIR:-/tmp}/skala-notary-key.XXXXXX" 2>/dev/null) || error 'Unable to prepare notarization credentials.'
chmod 600 "$key_path" >/dev/null 2>&1 || error 'Unable to prepare notarization credentials.'
if ! printf '%s' "$private_key_material" | /usr/bin/env -u APP_STORE_CONNECT_PRIVATE_KEY_BASE64 /usr/bin/base64 -D >"$key_path" 2>/dev/null || [ ! -s "$key_path" ]; then
    unset private_key_material
    error 'The private API-key secret is invalid.'
fi
unset private_key_material

if [ -n "$app_path" ]; then
    notarize_app "$app_path"
fi
if [ -n "$dmg_path" ]; then
    submit_for_notarization "$dmg_path"
    staple_and_assess "$dmg_path"
fi
if [ -n "$zip_path" ]; then
    verify_zip_app "$zip_path" "$version"
fi

if ! cleanup; then
    trap - EXIT
    error 'Temporary credential cleanup failed.'
fi
trap - EXIT
printf 'Notarization completed.\n'
