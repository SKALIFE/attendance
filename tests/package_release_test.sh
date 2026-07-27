#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGER="$ROOT/scripts/package-release.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file=$1
    local expected=$2

    grep -Fq -- "$expected" "$file" || fail "Expected output to contain: $expected"
}

expect_failure() {
    local output=$1
    shift

    if "$@" >"$output" 2>&1; then
        cat "$output" >&2
        fail 'Expected a failing exit status.'
    fi
}

snapshot_worktree_contents() {
    local worktree=$1
    local snapshot=$2

    git -C "$worktree" ls-files -co --exclude-standard -z |
        while IFS= read -r -d '' path; do
            shasum -a 256 "$worktree/$path"
        done | sort >"$snapshot"
}

make_app() {
    local app_path=$1
    local version=$2
    local executable="$app_path/Contents/MacOS/SKALA Attendance"
    local sparkle_root="$app_path/Contents/Frameworks/Sparkle.framework/Versions/B"

    mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$sparkle_root"
    cat >"$app_path/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>$version</string><key>CFBundleExecutable</key><string>SKALA Attendance</string></dict></plist>
EOF
    : >"$executable"
    : >"$sparkle_root/Autoupdate"
    : >"$sparkle_root/fileop"
    : >"$sparkle_root/InstallerLauncher"
    chmod +x "$executable" "$sparkle_root/Autoupdate" "$sparkle_root/fileop" "$sparkle_root/InstallerLauncher"
    printf 'linked resource\n' >"$app_path/Contents/Resources/real-resource"
    ln -s real-resource "$app_path/Contents/Resources/resource-link"
}

mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/codesign" <<'EOF'
#!/bin/bash
set -euo pipefail

printf 'codesign' >>"$COMMAND_LOG"
printf ' <%s>' "$@" >>"$COMMAND_LOG"
printf '\n' >>"$COMMAND_LOG"

case "$1" in
    -d)
        printf 'Authority=Developer ID Application: Test Identity (TEAMID)\n' >&2
        ;;
    --verify)
        printf '%s\n' "${FAKE_CODESIGN_VERIFY_OUTPUT:-}" >&2
        if [ -n "${FAKE_CODESIGN_SIGNED_MARKER:-}" ] && [ -e "$FAKE_CODESIGN_SIGNED_MARKER" ]; then
            [ "${FAKE_CODESIGN_POST_SIGN_VERIFY_STATUS:-0}" = 0 ] || exit "$FAKE_CODESIGN_POST_SIGN_VERIFY_STATUS"
        else
            [ "${FAKE_CODESIGN_VERIFY_STATUS:-0}" = 0 ] || exit "$FAKE_CODESIGN_VERIFY_STATUS"
        fi
        ;;
    --force)
        [ -z "${FAKE_CODESIGN_SIGNED_MARKER:-}" ] || touch "$FAKE_CODESIGN_SIGNED_MARKER"
        ;;
esac
EOF
cat >"$TEMP_DIR/bin/lipo" <<'EOF'
#!/bin/bash
set -euo pipefail

printf 'lipo <%s>\n' "$*" >>"$COMMAND_LOG"
printf '%s\n' "${FAKE_ARCHITECTURES:-arm64}"
EOF
cat >"$TEMP_DIR/bin/hdiutil" <<'EOF'
#!/bin/bash
set -euo pipefail

printf 'hdiutil' >>"$COMMAND_LOG"
printf ' <%s>' "$@" >>"$COMMAND_LOG"
printf '\n' >>"$COMMAND_LOG"

srcfolder=
while [ "$#" -gt 0 ]; do
    if [ "$1" = '-srcfolder' ]; then
        srcfolder=$2
        break
    fi
    shift
done
output=${!#}
case "$output" in
    "$srcfolder"/*)
        printf 'DMG output must be outside the hdiutil source folder.\n' >&2
        exit 87
        ;;
esac
touch "$output"
EOF
chmod +x "$TEMP_DIR/bin/codesign" "$TEMP_DIR/bin/lipo" "$TEMP_DIR/bin/hdiutil"

APP="$TEMP_DIR/build/SKALA Attendance.app"
APP_012="$TEMP_DIR/build/SKALA Attendance 0.1.2.app"
APP_013="$TEMP_DIR/build/SKALA Attendance 0.1.3.app"
OUTPUT_DIR="$TEMP_DIR/release"
make_app "$APP" 0.1.1
make_app "$APP_012" 0.1.2
make_app "$APP_013" 0.1.3
snapshot_worktree_contents "$ROOT" "$TEMP_DIR/target-before.sha256"

SUCCESS_OUTPUT="$TEMP_DIR/success.out"
env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/success.commands" \
    bash "$PACKAGER" --app "$APP" --version 0.1.1 --architecture arm64 --output-dir "$OUTPUT_DIR" \
    --identity 'Developer ID Application: Test Identity (TEAMID)' >"$SUCCESS_OUTPUT" 2>&1 || {
    cat "$SUCCESS_OUTPUT" >&2
    fail 'Expected release packaging fixture success.'
}

DMG="$OUTPUT_DIR/SKALA-Attendance-0.1.1-arm64.dmg"
ZIP="$OUTPUT_DIR/SKALA-Attendance-0.1.1-arm64.zip"
[ -f "$DMG" ] || fail 'Expected a versioned DMG artifact.'
[ -f "$ZIP" ] || fail 'Expected a versioned Sparkle ZIP artifact.'
[ ! -e "$OUTPUT_DIR/.skala-release-staging" ] || fail 'Fixture staging path was not cleaned up.'
assert_contains "$SUCCESS_OUTPUT" "Created: $DMG"
assert_contains "$SUCCESS_OUTPUT" "Created: $ZIP"
assert_contains "$TEMP_DIR/success.commands" "<--verify> <--deep> <--strict> <--verbose=2> <$APP>"
for helper in Autoupdate fileop InstallerLauncher; do
    helper_path="$APP/Contents/Frameworks/Sparkle.framework/Versions/B/$helper"
    assert_contains "$TEMP_DIR/success.commands" "<--verify> <--strict> <--verbose=2> <$helper_path>"
    assert_contains "$TEMP_DIR/success.commands" "<--force> <--options> <runtime> <--sign> <Developer ID Application: Test Identity (TEAMID)> <--timestamp> <$helper_path>"
    [ "$(grep -Fc "<--verify> <--strict> <--verbose=2> <$helper_path>" "$TEMP_DIR/success.commands")" = 2 ] || fail "Expected post-sign verification for $helper."
done
[ "$(grep -Fc "<--verify> <--strict> <--verbose=2> <$APP>" "$TEMP_DIR/success.commands")" = 2 ] || fail 'Expected post-sign verification for the app.'
[ "$(grep -Fc "<--verify> <--deep> <--strict> <--verbose=2> <$APP>" "$TEMP_DIR/success.commands")" = 2 ] || fail 'Expected post-sign deep verification for the app.'

ZIP_LISTING="$TEMP_DIR/zip-listing.txt"
/usr/bin/unzip -l "$ZIP" >"$ZIP_LISTING"
[ -z "${PACKAGE_RELEASE_ZIP_LISTING:-}" ] || cp "$ZIP_LISTING" "$PACKAGE_RELEASE_ZIP_LISTING"
assert_contains "$ZIP_LISTING" 'SKALA Attendance.app/Contents/Info.plist'
assert_contains "$ZIP_LISTING" 'SKALA Attendance.app/Contents/Resources/resource-link'
/usr/bin/unzip -Z1 "$ZIP" | awk 'index($0, "SKALA Attendance.app/") != 1 { exit 1 }' || fail 'Sparkle ZIP must contain the app at archive root only.'
ZIP_EXTRACT_DIR="$TEMP_DIR/zip-extracted"
/usr/bin/unzip -q "$ZIP" -d "$ZIP_EXTRACT_DIR"
[ -L "$ZIP_EXTRACT_DIR/SKALA Attendance.app/Contents/Resources/resource-link" ] || fail 'Sparkle ZIP must preserve app symlinks.'
if grep -Fq '.dmg' "$ZIP_LISTING"; then
    fail 'Sparkle ZIP must not contain a DMG.'
fi

SENTINEL="$OUTPUT_DIR/.skala-release-staging/sentinel"
mkdir -p "$(dirname "$SENTINEL")"
printf 'preserve me\n' >"$SENTINEL"
SENTINEL_OUTPUT="$TEMP_DIR/sentinel.out"
env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/sentinel.commands" \
    bash "$PACKAGER" --app "$APP_012" --version 0.1.2 --architecture arm64 --output-dir "$OUTPUT_DIR" \
    --identity 'Developer ID Application: Test Identity (TEAMID)' >"$SENTINEL_OUTPUT" 2>&1 || {
    cat "$SENTINEL_OUTPUT" >&2
    fail 'Expected unique staging to preserve an existing staging sentinel.'
}
[ "$(cat "$SENTINEL")" = 'preserve me' ] || fail 'Packaging removed an unrelated staging sentinel.'
[ -f "$OUTPUT_DIR/SKALA-Attendance-0.1.2-arm64.dmg" ] || fail 'Expected packaging to succeed beside a stale staging sentinel.'
[ -f "$OUTPUT_DIR/SKALA-Attendance-0.1.2-arm64.zip" ] || fail 'Expected ZIP packaging to succeed beside a stale staging sentinel.'

POST_SIGN_FAILURE_OUTPUT="$TEMP_DIR/post-sign-failure.out"
POST_SIGN_FAILURE_DIR="$TEMP_DIR/post-sign-failure-release"
POST_SIGN_MARKER="$TEMP_DIR/post-sign.marker"
expect_failure "$POST_SIGN_FAILURE_OUTPUT" env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/post-sign-failure.commands" \
    FAKE_CODESIGN_SIGNED_MARKER="$POST_SIGN_MARKER" FAKE_CODESIGN_POST_SIGN_VERIFY_STATUS=42 \
    bash "$PACKAGER" --app "$APP_013" --version 0.1.3 --architecture arm64 --output-dir "$POST_SIGN_FAILURE_DIR" \
    --identity 'Developer ID Application: Test Identity (TEAMID)'
assert_contains "$POST_SIGN_FAILURE_OUTPUT" 'Post-sign signature verification failed.'
[ ! -e "$POST_SIGN_FAILURE_DIR" ] || fail 'Post-sign verification must fail before creating artifacts.'
assert_contains "$TEMP_DIR/post-sign-failure.commands" '<--force>'

MISMATCH_OUTPUT="$TEMP_DIR/mismatch.out"
MISMATCH_OUTPUT_DIR="$TEMP_DIR/mismatch-release"
expect_failure "$MISMATCH_OUTPUT" env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/mismatch.commands" \
    bash "$PACKAGER" --app "$APP" --version 0.1.2 --architecture arm64 --output-dir "$MISMATCH_OUTPUT_DIR" \
    --identity 'Developer ID Application: Test Identity (TEAMID)'
assert_contains "$MISMATCH_OUTPUT" 'Expected version 0.1.2 does not match built app version 0.1.1.'
[ ! -e "$MISMATCH_OUTPUT_DIR" ] || fail 'Version mismatches must fail before creating output paths.'
[ ! -e "$TEMP_DIR/mismatch.commands" ] || fail 'Version mismatches must fail before external tools.'

WRONG_ARCHITECTURE_OUTPUT="$TEMP_DIR/wrong-architecture.out"
WRONG_ARCHITECTURE_DIR="$TEMP_DIR/wrong-architecture-release"
expect_failure "$WRONG_ARCHITECTURE_OUTPUT" env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/wrong-architecture.commands" \
    FAKE_ARCHITECTURES=x86_64 bash "$PACKAGER" --app "$APP" --version 0.1.1 --architecture arm64 \
    --output-dir "$WRONG_ARCHITECTURE_DIR" --identity 'Developer ID Application: Test Identity (TEAMID)'
assert_contains "$WRONG_ARCHITECTURE_OUTPUT" 'Built app architecture must be arm64; found x86_64.'
[ ! -e "$WRONG_ARCHITECTURE_DIR" ] || fail 'Architecture mismatches must fail before creating output paths.'

SIGNATURE_FAILURE_OUTPUT="$TEMP_DIR/signature-failure.out"
SIGNATURE_FAILURE_DIR="$TEMP_DIR/signature-failure-release"
expect_failure "$SIGNATURE_FAILURE_OUTPUT" env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/signature-failure.commands" \
    FAKE_CODESIGN_VERIFY_OUTPUT='verification passed' FAKE_CODESIGN_VERIFY_STATUS=42 \
    bash "$PACKAGER" --app "$APP" --version 0.1.1 --architecture arm64 \
    --output-dir "$SIGNATURE_FAILURE_DIR" --identity 'Developer ID Application: Test Identity (TEAMID)'
assert_contains "$SIGNATURE_FAILURE_OUTPUT" 'Existing signature verification failed.'
[ ! -e "$SIGNATURE_FAILURE_DIR" ] || fail 'Signature failures must fail before creating output paths.'
if grep -Fq '<--force>' "$TEMP_DIR/signature-failure.commands"; then
    fail 'Packaging must not re-sign after pre-existing signature verification fails.'
fi

STALE_DMG="$OUTPUT_DIR/SKALA-Attendance-0.1.3-arm64.dmg"
STALE_ZIP="$OUTPUT_DIR/SKALA-Attendance-0.1.3-arm64.zip"
touch "$STALE_DMG"
STALE_OUTPUT="$TEMP_DIR/stale.out"
expect_failure "$STALE_OUTPUT" env PATH="$TEMP_DIR/bin:$PATH" COMMAND_LOG="$TEMP_DIR/stale.commands" \
    bash "$PACKAGER" --app "$APP_013" --version 0.1.3 --architecture arm64 --output-dir "$OUTPUT_DIR" \
    --identity 'Developer ID Application: Test Identity (TEAMID)'
assert_contains "$STALE_OUTPUT" "Release artifact already exists: $STALE_DMG"
[ -f "$STALE_DMG" ] || fail 'Existing artifacts must not be removed.'
[ ! -e "$STALE_ZIP" ] || fail 'No-clobber failures must not create the sibling ZIP.'
if [ -e "$TEMP_DIR/stale.commands" ]; then
    fail 'Stale artifacts must fail before signing or packaging tools.'
fi

snapshot_worktree_contents "$ROOT" "$TEMP_DIR/target-after.sha256"
cmp -s "$TEMP_DIR/target-before.sha256" "$TEMP_DIR/target-after.sha256" || fail 'Packaging tests modified target worktree content.'

printf 'Release DMG and Sparkle ZIP packaging tests passed.\n'
