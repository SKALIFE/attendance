#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s --version X.Y.Z [--app path/to/SKALA\ Attendance.app] [--architecture arm64] [--output-dir release] [--identity "Developer ID Application: …"]\n' "${0##*/}" >&2
    exit 2
}

error() {
    printf '%s\n' "$1" >&2
    exit 1
}

read_plist_value() {
    local key=$1
    local plist=$2

    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null
}

verify_code_unit() {
    local code_path=$1
    local failure_message=$2
    local signature_details

    if ! codesign --verify --strict --verbose=2 "$code_path" >/dev/null 2>&1; then
        error "$failure_message"
    fi
    if ! signature_details=$(codesign -d --verbose=4 "$code_path" 2>&1); then
        error "$failure_message"
    fi
    if ! grep -Fq "Authority=$identity" <<<"$signature_details"; then
        error "$failure_message"
    fi
}

sign_code_unit() {
    local code_path=$1

    codesign --force --options runtime --sign "$identity" --timestamp "$code_path"
}

app_path='build/Build/Products/Release/SKALA Attendance.app'
expected_version=
architecture=arm64
output_dir=release
identity='Developer ID Application: DAYEON OH (9XY8538U7T)'

while [ "$#" -gt 0 ]; do
    case "$1" in
        --app)
            [ "$#" -ge 2 ] || usage
            app_path=$2
            shift 2
            ;;
        --version)
            [ "$#" -ge 2 ] || usage
            expected_version=$2
            shift 2
            ;;
        --architecture)
            [ "$#" -ge 2 ] || usage
            architecture=$2
            shift 2
            ;;
        --output-dir)
            [ "$#" -ge 2 ] || usage
            output_dir=$2
            shift 2
            ;;
        --identity)
            [ "$#" -ge 2 ] || usage
            identity=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error 'Expected version must use X.Y.Z format.'
[ "$architecture" = arm64 ] || error 'Only arm64 release packaging is supported.'
[ -d "$app_path" ] && [ -f "$app_path/Contents/Info.plist" ] || error 'Built app is missing or invalid.'

bundle_version=$(read_plist_value CFBundleShortVersionString "$app_path/Contents/Info.plist") || error 'Built app is missing or invalid.'
[[ "$bundle_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error 'Built app is missing or invalid.'
[ "$bundle_version" = "$expected_version" ] || error "Expected version $expected_version does not match built app version $bundle_version."

dmg_name="SKALA-Attendance-$bundle_version-$architecture.dmg"
zip_name="SKALA-Attendance-$bundle_version-$architecture.zip"
dmg_path="$output_dir/$dmg_name"
zip_path="$output_dir/$zip_name"
[ ! -e "$dmg_path" ] || error "Release artifact already exists: $dmg_path"
[ ! -e "$zip_path" ] || error "Release artifact already exists: $zip_path"

executable_name=$(read_plist_value CFBundleExecutable "$app_path/Contents/Info.plist") || error 'Built app is missing or invalid.'
app_executable="$app_path/Contents/MacOS/$executable_name"
[ -f "$app_executable" ] || error 'Built app is missing or invalid.'
built_architecture=$(lipo -archs "$app_executable") || error 'Unable to determine built app architecture.'
[ "$built_architecture" = "$architecture" ] || error "Built app architecture must be $architecture; found $built_architecture."

sparkle_root="$app_path/Contents/Frameworks/Sparkle.framework/Versions/B"
sparkle_helpers=(
    "$sparkle_root/Autoupdate"
    "$sparkle_root/fileop"
    "$sparkle_root/InstallerLauncher"
)
for helper_path in "${sparkle_helpers[@]}"; do
    [ -f "$helper_path" ] || error "Sparkle helper is missing: $helper_path"
done

if ! codesign --verify --deep --strict --verbose=2 "$app_path" >/dev/null 2>&1; then
    error 'Existing signature verification failed.'
fi
verify_code_unit "$app_path" 'Existing signature verification failed.'
for helper_path in "${sparkle_helpers[@]}"; do
    verify_code_unit "$helper_path" 'Existing signature verification failed.'
done

sign_code_unit "${sparkle_helpers[0]}"
sign_code_unit "${sparkle_helpers[1]}"
sign_code_unit "${sparkle_helpers[2]}"
sign_code_unit "$app_path"

if ! codesign --verify --deep --strict --verbose=2 "$app_path" >/dev/null 2>&1; then
    error 'Post-sign signature verification failed.'
fi
verify_code_unit "$app_path" 'Post-sign signature verification failed.'
for helper_path in "${sparkle_helpers[@]}"; do
    verify_code_unit "$helper_path" 'Post-sign signature verification failed.'
done

mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -L)
dmg_path="$output_dir/$dmg_name"
zip_path="$output_dir/$zip_name"
staging=

cleanup() {
    [ -z "$staging" ] || rm -rf "$staging"
}
trap cleanup EXIT

staging=$(mktemp -d "$output_dir/.skala-release.XXXXXX") || error 'Unable to create release staging directory.'
cp -R "$app_path" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create \
    -volname 'SKALA Attendance' \
    -srcfolder "$staging" \
    -format UDZO \
    "$dmg_path"

app_parent=$(dirname "$app_path")
app_name=$(basename "$app_path")
(
    cd "$app_parent"
    /usr/bin/zip -qry "$staging/$zip_name" "$app_name"
)

mv "$staging/$zip_name" "$zip_path"
printf 'Created: %s\nCreated: %s\n' "$dmg_path" "$zip_path"
