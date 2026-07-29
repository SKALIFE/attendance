#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS_ROOT="$ROOT/.build/SourcePackages/artifacts/sparkle/Sparkle"
APP_PATH=
PROJECT="$ROOT/project.yml"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

usage() {
    printf 'Usage: %s [--tools-root path/to/Sparkle] [--app path/to/SKALA\ Attendance.app] [--project project.yml]\n' "${0##*/}" >&2
    exit 2
}

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

RAWIN_OPTION=$(printf '%s%s' '-raw' 'in')
if grep -Fq -- "$RAWIN_OPTION" "$0"; then
    fail "Sparkle integration test must not use LibreSSL pkeyutl $RAWIN_OPTION verification."
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tools-root)
            [ "$#" -ge 2 ] || usage
            TOOLS_ROOT=$2
            shift 2
            ;;
        --app)
            [ "$#" -ge 2 ] || usage
            APP_PATH=$2
            shift 2
            ;;
        --project)
            [ "$#" -ge 2 ] || usage
            PROJECT=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

project_public_key() {
    awk '
        /^[[:space:]]*SUPublicEDKey:[[:space:]]*/ {
            value = $0
            sub(/^[^:]*:[[:space:]]*/, "", value)
            gsub(/[[:space:]\"]/, "", value)
            print value
            exit
        }
    ' "$1"
}

write_project_with_public_key() {
    local destination=$1
    local public_key=$2

    awk -v public_key="$public_key" '
        /^[[:space:]]*SUPublicEDKey:[[:space:]]*/ {
            sub(/:.*/, ": " public_key)
        }
        { print }
    ' "$PROJECT" >"$destination"
}

verify_signature_with_sign_update() {
    local archive=$1
    local signature=$2
    local private_key=$3

    printf '%s\n' "$private_key" | "$SIGN_UPDATE" --verify --ed-key-file - \
        "$archive" "$signature" >/dev/null
}

SIGN_UPDATE="$TOOLS_ROOT/bin/sign_update"
FRAMEWORK_ROOT="$TOOLS_ROOT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework/Versions/B"
[ -x "$SIGN_UPDATE" ] || fail 'Sparkle 2.9.4 sign_update artifact is missing or not executable.'
[ -x "$FRAMEWORK_ROOT/Autoupdate" ] || fail 'Sparkle 2.9.4 Autoupdate helper is missing or not executable.'
[ -x "$FRAMEWORK_ROOT/Updater.app/Contents/MacOS/Updater" ] || fail 'Sparkle 2.9.4 Updater.app executable is missing or not executable.'
[ -x "$FRAMEWORK_ROOT/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" ] || fail 'Sparkle 2.9.4 Downloader XPC service is missing or not executable.'
[ -x "$FRAMEWORK_ROOT/XPCServices/Installer.xpc/Contents/MacOS/Installer" ] || fail 'Sparkle 2.9.4 Installer XPC service is missing or not executable.'
[ ! -e "$FRAMEWORK_ROOT/fileop" ] || fail 'Sparkle 2.9.4 must not be validated through the obsolete fileop helper.'
[ ! -e "$FRAMEWORK_ROOT/InstallerLauncher" ] || fail 'Sparkle 2.9.4 must not be validated through the obsolete InstallerLauncher helper.'

HELP_OUTPUT="$TEMP_DIR/sign-update-help.txt"
"$SIGN_UPDATE" --help >"$HELP_OUTPUT"
grep -Fq -- '--ed-key-file <private-key-file>' "$HELP_OUTPUT" || fail 'Sparkle 2.9.4 sign_update no longer exposes its documented secure key-file option.'

printf 'Sparkle 2.9.4 stdin signing probe\n' >"$TEMP_DIR/archive.zip"
PRIVATE_KEY=$(openssl rand -base64 32)
SIGNATURE=$(printf '%s\n' "$PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - -p "$TEMP_DIR/archive.zip")
[[ "$SIGNATURE" =~ ^[A-Za-z0-9+/]{86}==$ ]] || fail 'Sparkle 2.9.4 sign_update did not emit an EdDSA signature from standard input.'
printf '%s\n' "$PRIVATE_KEY" | "$SIGN_UPDATE" --verify --ed-key-file - "$TEMP_DIR/archive.zip" "$SIGNATURE" >/dev/null || fail 'Sparkle 2.9.4 sign_update could not verify an stdin-provided key signature.'

printf '\060\056\002\001\000\060\005\006\003\053\145\160\004\042\004\040' >"$TEMP_DIR/private-key.der"
printf '%s' "$PRIVATE_KEY" | base64 -D >>"$TEMP_DIR/private-key.der"
MATCHING_PUBLIC_KEY=$(openssl pkey -inform DER -in "$TEMP_DIR/private-key.der" -pubout -outform DER | dd bs=1 skip=12 2>/dev/null | openssl base64 -A)
MATCHING_PROJECT="$TEMP_DIR/matching-project.yml"
MISMATCHED_PROJECT="$TEMP_DIR/mismatched-project.yml"
write_project_with_public_key "$MATCHING_PROJECT" "$MATCHING_PUBLIC_KEY"
MISMATCHED_PUBLIC_KEY=$(openssl rand -base64 32)
[ "$MISMATCHED_PUBLIC_KEY" != "$MATCHING_PUBLIC_KEY" ] || fail 'Unable to construct a mismatched Sparkle public key fixture.'
write_project_with_public_key "$MISMATCHED_PROJECT" "$MISMATCHED_PUBLIC_KEY"

GENERATOR_ARCHIVE="$TEMP_DIR/SKALA-Attendance-0.1.10-arm64.zip"
GENERATOR_SOURCE="$TEMP_DIR/generator-source"
mkdir -p "$GENERATOR_SOURCE/SKALA Attendance.app/Contents/MacOS"
printf 'Sparkle signature compatibility fixture\n' >"$GENERATOR_SOURCE/SKALA Attendance.app/Contents/MacOS/SKALAAttendance"
(
    cd "$GENERATOR_SOURCE"
    /usr/bin/zip -qry "$GENERATOR_ARCHIVE" 'SKALA Attendance.app'
)
GENERATOR_DIGEST=$(shasum -a 256 "$GENERATOR_ARCHIVE" | awk '{print $1}')
GENERATOR_APPCAST="$TEMP_DIR/appcast.xml"
cp "$ROOT/tests/fixtures/current-appcast.xml" "$GENERATOR_APPCAST"
GENERATOR_PROBE="$TEMP_DIR/release-probe"
cat >"$GENERATOR_PROBE" <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$#" = 3 ]
EOF
chmod +x "$GENERATOR_PROBE"
GENERATOR_OUTPUT="$TEMP_DIR/appcast-item.xml"
env SPARKLE_EDDSA_PRIVATE_KEY="$PRIVATE_KEY" bash "$ROOT/scripts/generate-appcast-item.sh" \
    --tag v0.1.10 --build 11 --archive "$GENERATOR_ARCHIVE" --archive-sha256 "$GENERATOR_DIGEST" \
    --archive-url 'https://github.com/SKALIFE/attendance/releases/download/v0.1.10/SKALA-Attendance-0.1.10-arm64.zip' \
    --appcast "$GENERATOR_APPCAST" --project "$MATCHING_PROJECT" --sparkle-tools-root "$TOOLS_ROOT" \
    --release-probe "$GENERATOR_PROBE" >"$GENERATOR_OUTPUT"
GENERATOR_SIGNATURE=$(awk -F 'sparkle:edSignature="' 'NF > 1 { split($2, value, "\""); print value[1]; exit }' "$GENERATOR_OUTPUT")
verify_signature_with_sign_update "$GENERATOR_ARCHIVE" "$GENERATOR_SIGNATURE" "$PRIVATE_KEY" || fail 'Actual Sparkle 2.9.4 signature could not be verified by Sparkle sign_update.'

MISMATCH_OUTPUT="$TEMP_DIR/mismatched-project.out"
if env SPARKLE_EDDSA_PRIVATE_KEY="$PRIVATE_KEY" bash "$ROOT/scripts/generate-appcast-item.sh" \
    --tag v0.1.10 --build 11 --archive "$GENERATOR_ARCHIVE" --archive-sha256 "$GENERATOR_DIGEST" \
    --archive-url 'https://github.com/SKALIFE/attendance/releases/download/v0.1.10/SKALA-Attendance-0.1.10-arm64.zip' \
    --appcast "$GENERATOR_APPCAST" --project "$MISMATCHED_PROJECT" --sparkle-tools-root "$TOOLS_ROOT" \
    --release-probe "$GENERATOR_PROBE" >"$MISMATCH_OUTPUT" 2>&1; then
    fail 'Sparkle appcast generation must reject a signing key that does not match project SUPublicEDKey.'
fi
grep -Fq 'Signing key does not match project SUPublicEDKey.' "$MISMATCH_OUTPUT" || fail 'Mismatched project key did not report the expected diagnostic.'

if [ -n "$APP_PATH" ]; then
    APP_FRAMEWORK_ROOT="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
    [ -x "$APP_FRAMEWORK_ROOT/Autoupdate" ] || fail 'Built app is missing the Sparkle 2.9.4 Autoupdate helper.'
    [ -x "$APP_FRAMEWORK_ROOT/Updater.app/Contents/MacOS/Updater" ] || fail 'Built app is missing Sparkle 2.9.4 Updater.app.'
    [ -x "$APP_FRAMEWORK_ROOT/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" ] || fail 'Built app is missing Sparkle 2.9.4 Downloader XPC service.'
    [ -x "$APP_FRAMEWORK_ROOT/XPCServices/Installer.xpc/Contents/MacOS/Installer" ] || fail 'Built app is missing Sparkle 2.9.4 Installer XPC service.'
fi

printf 'Sparkle 2.9.4 layout and sign_update integration probes passed.\n'
