#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKFLOW="$ROOT/.github/workflows/release.yml"
PARSE_ONLY_FIXTURE="$ROOT/tests/fixtures/release-workflow-parse-only.yml"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_text() {
    local text=$1
    local description=$2

    grep -Fq -- "$text" "$WORKFLOW" || fail "Missing workflow policy: $description"
}

forbid_text() {
    local text=$1
    local description=$2

    if grep -Fq -- "$text" "$WORKFLOW"; then
        fail "Forbidden workflow policy violation: $description"
    fi
}

parse_yaml() {
    local file=$1

    ruby -e '
        require "yaml"
        YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
    ' "$file" >/dev/null
}

secret_value_prints() {
    local file=$1

    grep -E '(echo|printf).*\$(DEVELOPER_ID_APPLICATION_P12_BASE64|DEVELOPER_ID_APPLICATION_P12_PASSWORD|APPLE_TEAM_ID|APP_STORE_CONNECT_ISSUER_ID|APP_STORE_CONNECT_KEY_ID|APP_STORE_CONNECT_PRIVATE_KEY_BASE64|SPARKLE_EDDSA_PRIVATE_KEY|GH_TOKEN|APPCAST_REPO_TOKEN)' "$file" |
        grep -Fv 'printf '\''%s'\'' "$DEVELOPER_ID_APPLICATION_P12_BASE64" | base64 -D >"$P12_PATH"'
}

[ -f "$WORKFLOW" ] || fail 'Release workflow is missing.'
parse_yaml "$WORKFLOW" || fail 'Release workflow YAML did not parse.'
parse_yaml "$PARSE_ONLY_FIXTURE" || fail 'Parse-only fixture YAML did not parse.'

if ! ruby -e '
    require "yaml"
    workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
    trigger = workflow.fetch(true)
    abort unless trigger.keys == ["push"]
    abort unless trigger.fetch("push").keys == ["tags"]
    abort unless trigger.fetch("push").fetch("tags") == ["v*"]
    abort unless workflow.fetch("permissions") == { "contents" => "write" }
    workflow.fetch("jobs").each_value do |job|
      abort if job.key?("if") || job.key?("continue-on-error")
      job.fetch("steps", []).each do |step|
        abort if step.key?("if") || step.key?("continue-on-error")
      end
    end
' "$WORKFLOW"; then
    fail 'Workflow trigger or permissions shape is broader than the release policy permits.'
fi

grep -Fq 'pull_request_target:' "$PARSE_ONLY_FIXTURE" || fail 'Parse-only fixture no longer demonstrates an unsafe trigger.'

require_text 'on:' 'an explicit workflow trigger'
require_text 'push:' 'a push-only trigger'
require_text 'tags:' 'a tag filter'
require_text "- 'v*'" 'the v* tag restriction'
forbid_text 'branches:' 'branch push triggers'
forbid_text 'pull_request_target' 'pull_request_target trigger'
forbid_text 'workflow_dispatch' 'manual release trigger'

require_text 'permissions:' 'least-privilege token permissions'
require_text 'contents: write' 'contents: write release permission'
if [ "$(grep -Fc 'permissions:' "$WORKFLOW")" -ne 1 ]; then
    fail 'Workflow must not add job-level permissions.'
fi
if [ "$(grep -Ec '^[[:space:]]+[[:alnum:]_-]+:[[:space:]]*(read|write|none)$' "$WORKFLOW")" -ne 1 ]; then
    fail 'Workflow must declare contents: write as its only permission.'
fi

for secret in \
    DEVELOPER_ID_APPLICATION_P12_BASE64 \
    DEVELOPER_ID_APPLICATION_P12_PASSWORD \
    APPLE_TEAM_ID \
    APP_STORE_CONNECT_ISSUER_ID \
    APP_STORE_CONNECT_KEY_ID \
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64 \
    SPARKLE_EDDSA_PRIVATE_KEY \
    APPCAST_REPO_TOKEN; do
    require_text "secrets.$secret" "existing secret name $secret"
done

if grep -oE 'secrets\.[A-Z0-9_]+' "$WORKFLOW" | sort -u | grep -Ev '^secrets\.(DEVELOPER_ID_APPLICATION_P12_BASE64|DEVELOPER_ID_APPLICATION_P12_PASSWORD|APPLE_TEAM_ID|APP_STORE_CONNECT_ISSUER_ID|APP_STORE_CONNECT_KEY_ID|APP_STORE_CONNECT_PRIVATE_KEY_BASE64|SPARKLE_EDDSA_PRIVATE_KEY|APPCAST_REPO_TOKEN)$' >"$TEMP_DIR/unexpected-secrets"; then
    cat "$TEMP_DIR/unexpected-secrets" >&2
    fail 'Workflow references a secret name outside the established release secret set.'
fi
forbid_text 'echo ${{ secrets.' 'direct secret interpolation in output'
forbid_text 'set -x' 'shell tracing that could expose secret-derived values'
forbid_text 'printenv' 'environment dumping that could expose secrets'
forbid_text 'env |' 'environment dumping that could expose secrets'
forbid_text 'declare -p' 'shell variable dumping that could expose secrets'
if grep -F '${{ secrets.' "$WORKFLOW" | grep -Ev '^[[:space:]]+[A-Z0-9_]+: \$\{\{ secrets\.[A-Z0-9_]+ \}\}$' >"$TEMP_DIR/secret-interpolation"; then
    cat "$TEMP_DIR/secret-interpolation" >&2
    fail 'Workflow must inject secrets only through step environment mappings.'
fi
for secret in DEVELOPER_ID_APPLICATION_P12_BASE64 DEVELOPER_ID_APPLICATION_P12_PASSWORD APPLE_TEAM_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_PRIVATE_KEY_BASE64 SPARKLE_EDDSA_PRIVATE_KEY GH_TOKEN APPCAST_REPO_TOKEN; do
    forbid_text "echo \"\$$secret\"" "printing the $secret value"
    forbid_text "echo '\$$secret'" "printing the $secret value"
done
if secret_value_prints "$WORKFLOW" >"$TEMP_DIR/secret-value-print"; then
    cat "$TEMP_DIR/secret-value-print" >&2
    fail 'Workflow must not print a secret value.'
fi
SECRET_OUTPUT_MUTATION="$TEMP_DIR/release-workflow-secret-output.yml"
cp "$WORKFLOW" "$SECRET_OUTPUT_MUTATION"
printf '\n      - run: echo "$GH_TOKEN"\n' >>"$SECRET_OUTPUT_MUTATION"
if ! secret_value_prints "$SECRET_OUTPUT_MUTATION" >"$TEMP_DIR/secret-output-mutation"; then
    fail 'Secret-output mutation fixture must be rejected.'
fi

require_text 'security create-keychain' 'temporary signing keychain creation'
require_text 'security import' 'Developer ID P12 import'
require_text 'security delete-keychain' 'temporary signing keychain cleanup'
require_text 'trap cleanup EXIT' 'cleanup on unsuccessful stages'

if grep -E '^[[:space:]]+uses:' "$WORKFLOW" | grep -Ev '@[0-9a-f]{40}$' >"$TEMP_DIR/mutable-actions"; then
    cat "$TEMP_DIR/mutable-actions" >&2
    fail 'Every action revision must be pinned to a full immutable commit SHA.'
fi
require_text 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' 'pinned checkout action'
require_text 'fetch-depth: 0' 'full history for ancestry validation'
require_text 'persist-credentials: false' 'checkout credential persistence disabled'
require_text 'DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer' 'explicit Xcode selection'

require_text 'git merge-base --is-ancestor "$TAG_COMMIT" "origin/main"' 'tag commit must be reachable from main'
require_text 'git status --porcelain' 'clean tagged checkout validation'
require_text 'bash scripts/ensure-release-absent.sh "$TAG"' 'duplicate release rejection hook'
require_text 'GH_TOKEN: ${{ github.token }}' 'GitHub CLI authentication'
if [ "$(grep -Fc 'GH_TOKEN: ${{ github.token }}' "$WORKFLOW")" -ne 2 ]; then
    fail 'Both guarded GitHub CLI release commands must receive GH_TOKEN.'
fi
require_text 'bash tests/release_metadata_test.sh' 'metadata helper test'
require_text 'bash tests/package_release_test.sh' 'package helper test'
require_text 'bash tests/notarize_test.sh' 'notarization helper test'
require_text 'bash tests/appcast_item_test.sh' 'appcast helper test'
require_text 'bash tests/publish_appcast_test.sh' 'appcast publisher helper test'
require_text 'bash tests/verify_release_zip_test.sh' 'release ZIP download verifier test'
require_text 'bash scripts/package-release.sh' 'local package helper invocation'
require_text 'bash scripts/notarize.sh' 'local notarization helper invocation'
require_text 'bash scripts/notarize.sh --app "$APP_PATH"' 'app notarization before final archive creation'
require_text 'rm -f "$ZIP_PATH" "$DMG_PATH"' 'removal of pre-staple package artifacts'
require_text 'Rebuild ZIP from stapled app' 'ZIP recreation stage'
require_text 'Create and notarize DMG from stapled app' 'DMG finalization stage'
require_text 'bash scripts/notarize.sh --dmg "$DMG_PATH" --zip "$ZIP_PATH"' 'DMG notarization and rebuilt ZIP validation'
require_text 'bash scripts/generate-appcast-item.sh' 'real artifact appcast candidate validation'
require_text '--release-probe scripts/verify-local-release-candidate.sh' 'local candidate release probe'
require_text 'CHECKSUM_PATH="release/checksums.txt"' 'checksum artifact path'
require_text 'shasum -a 256 "$ZIP_PATH" "$DMG_PATH" >"$CHECKSUM_PATH"' 'checksum-file generation'
require_text 'gh release create "$TAG" "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"' 'atomic ZIP, DMG, and checksum attachment'
require_text 'SOURCE_APPCAST_SHA256' 'source appcast integrity snapshot'
require_text 'test "$SOURCE_APPCAST_SHA256" = "$(shasum -a 256 tests/fixtures/current-appcast.xml' 'source appcast integrity check before release'
require_text 'APPCAST_REPO_TOKEN: ${{ secrets.APPCAST_REPO_TOKEN }}' 'cross-repository appcast publication credential mapping'
require_text 'bash scripts/publish-appcast.sh' 'guarded cross-repository appcast publisher'
require_text '--release-probe scripts/verify-release-zip.sh' 'production release ZIP verification before appcast mutation'
require_text '--target-repo https://github.com/SKALIFE/attendance-appcast.git' 'approved appcast repository target'
require_text '--raw-appcast-url https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml' 'actual raw appcast refetch verification'
require_text 'set +x' 'xtrace is explicitly disabled before appcast credential use'
require_text 'unset APPCAST_REPO_TOKEN' 'appcast credential is scrubbed after publisher setup'
forbid_text '--write' 'source appcast mutation before publication'
forbid_text 'gh release upload' 'release asset overwrite path'
forbid_text '--clobber' 'release asset overwrite path'
forbid_text 'continue-on-error' 'failure bypass'
forbid_text 'if: always()' 'failure bypass'
forbid_text 'if: ${{ always() }}' 'failure bypass'
forbid_text 'mv "$APPCAST_CANDIDATE"' 'source appcast mutation before release'
forbid_text 'cp "$APPCAST_CANDIDATE"' 'source appcast mutation before release'

for portable_test in tests/package_release_test.sh tests/notarize_test.sh; do
    if grep -Eq '/(Users|home)/' "$ROOT/$portable_test"; then
        fail "$portable_test must not depend on a developer-machine absolute path."
    fi
done
[ -x "$ROOT/scripts/verify-local-release-candidate.sh" ] || fail 'Local candidate release probe is missing or not executable.'
[ -x "$ROOT/scripts/ensure-release-absent.sh" ] || fail 'Release duplicate guard is missing or not executable.'
bash "$ROOT/tests/ensure_release_absent_test.sh"

stage_line() {
    grep -nF -- "$1" "$WORKFLOW" | /usr/bin/head -n 1 | cut -d: -f1
}

metadata_line=$(stage_line 'bash tests/release_metadata_test.sh')
package_line=$(stage_line 'bash scripts/package-release.sh')
app_notarize_line=$(stage_line 'bash scripts/notarize.sh --app "$APP_PATH"')
zip_rebuild_line=$(stage_line 'Rebuild ZIP from stapled app')
final_dmg_line=$(stage_line 'Create and notarize DMG from stapled app')
notarize_line=$(stage_line 'bash scripts/notarize.sh --dmg "$DMG_PATH" --zip "$ZIP_PATH"')
checksum_line=$(stage_line 'shasum -a 256 "$ZIP_PATH" "$DMG_PATH" >"$CHECKSUM_PATH"')
appcast_line=$(stage_line 'bash tests/appcast_item_test.sh')
candidate_line=$(stage_line 'bash scripts/generate-appcast-item.sh')
source_guard_line=$(stage_line 'Verify source appcast is unchanged')
release_line=$(stage_line 'gh release create "$TAG"')
publisher_line=$(stage_line 'bash scripts/publish-appcast.sh')
for line in "$metadata_line" "$package_line" "$app_notarize_line" "$zip_rebuild_line" "$final_dmg_line" "$notarize_line" "$checksum_line" "$appcast_line" "$candidate_line" "$source_guard_line" "$release_line" "$publisher_line"; do
    [[ "$line" =~ ^[0-9]+$ ]] || fail 'Expected release stage is missing from the workflow.'
done
if ! (( metadata_line < package_line && package_line < app_notarize_line && app_notarize_line < zip_rebuild_line && zip_rebuild_line < final_dmg_line && final_dmg_line < notarize_line && notarize_line < checksum_line && checksum_line < appcast_line && appcast_line < candidate_line && candidate_line < source_guard_line && source_guard_line < release_line && release_line < publisher_line )); then
    fail 'GitHub Release creation must follow final artifact validation and source appcast integrity checks.'
fi

printf 'Release workflow offline policy tests passed.\n'
