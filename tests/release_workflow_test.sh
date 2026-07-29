#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKFLOW="$ROOT/.github/workflows/release.yml"
PROJECT="$ROOT/project.yml"
RELEASE_NOTES="$ROOT/docs/releases/0.1.10.md"
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

assert_contains() {
    local file=$1
    local expected=$2

    grep -Fq -- "$expected" "$file" || fail "Expected $file to contain: $expected"
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
    abort unless workflow.fetch("permissions") == { "contents" => "read" }
    release = workflow.fetch("jobs").fetch("release")
    publish_appcast = workflow.fetch("jobs").fetch("publish-appcast")
    abort unless release.fetch("permissions") == { "contents" => "write" }
    abort if publish_appcast.key?("permissions")
    workflow.fetch("jobs").each_value do |job|
      abort if job.key?("if") || job.key?("continue-on-error")
      job.fetch("steps", []).each do |step|
        abort if step.key?("if") || step.key?("continue-on-error")
      end
    end
' "$WORKFLOW"; then
    fail 'Workflow trigger or permissions shape is broader than the release policy permits.'
fi

if ! ruby -e '
    require "yaml"

    workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
    jobs = workflow.fetch("jobs")
    abort unless jobs.keys.sort == ["publish-appcast", "release"]

    release = jobs.fetch("release")
    publish = jobs.fetch("publish-appcast")
    abort if release.fetch("env", {}).key?("APPCAST_REPO_TOKEN")
    abort if publish.fetch("env", {}).key?("APPCAST_REPO_TOKEN")
    abort unless publish.fetch("needs") == "release"
    abort unless publish.fetch("runs-on") == "macos-14"
    abort unless publish.fetch("environment") == "appcast-publish"

    outputs = release.fetch("outputs")
    abort unless outputs == {
      "archive_url" => "${{ steps.appcast_metadata.outputs.archive_url }}",
      "archive_sha256" => "${{ steps.appcast_metadata.outputs.archive_sha256 }}",
      "archive_size" => "${{ steps.appcast_metadata.outputs.archive_size }}"
    }

    release_steps = release.fetch("steps")
    publish_steps = publish.fetch("steps")
    metadata = release_steps.find { |step| step["id"] == "appcast_metadata" }
    abort unless metadata && metadata.fetch("run").include?("$GITHUB_OUTPUT")
    %w[archive_url archive_sha256 archive_size].each do |output|
      abort unless metadata.fetch("run").include?("#{output}=")
    end

    uploads = release_steps.select { |step| step.fetch("uses", "").start_with?("actions/upload-artifact@") }
    abort unless uploads.length == 1
    upload = uploads.first
    abort unless upload["uses"] == "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
    abort unless upload && upload.fetch("with").fetch("name") == "appcast-candidate"
    abort unless upload.fetch("with").fetch("path") == "release/appcast-candidate.xml"
    abort unless upload.fetch("with").fetch("if-no-files-found") == "error"
    abort unless upload.fetch("with").fetch("retention-days").is_a?(Integer) && upload.fetch("with").fetch("retention-days") <= 7

    download = publish_steps.find { |step| step["uses"] == "actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093" }
    abort unless download && download.fetch("with").fetch("name") == "appcast-candidate"
    abort unless download.fetch("with").fetch("path") == "release"

    checkout = publish_steps.find { |step| step["uses"] == "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683" }
    abort unless checkout && checkout.fetch("with") == {
      "ref" => "${{ github.ref }}",
      "fetch-depth" => 1,
      "persist-credentials" => false
    }

    release_steps.each do |step|
      abort if step.fetch("run", "").include?("scripts/publish-appcast.sh")
      abort if step.fetch("env", {}).key?("APPCAST_REPO_TOKEN")
    end
    publisher_index = publish_steps.index { |step| step.fetch("run", "").include?("scripts/publish-appcast.sh") }
    verifier_index = publish_steps.index { |step| step.fetch("run", "").include?("scripts/verify-release-zip.sh") }
    abort unless publisher_index && verifier_index && verifier_index < publisher_index
    verifier = publish_steps.fetch(verifier_index)
    abort unless verifier.fetch("name") == "Verify released ZIP anonymously"
    abort if verifier.key?("env") || verifier.fetch("run").include?("scripts/publish-appcast.sh")
    verifier_run = verifier.fetch("run")
    expected_verifier_lines = [
      "set -euo pipefail",
      "bash scripts/verify-release-zip.sh \\",
      "\"${{ needs.release.outputs.archive_url }}\" \\",
      "\"${{ needs.release.outputs.archive_size }}\" \\",
      "\"${{ needs.release.outputs.archive_sha256 }}\""
    ]
    abort unless verifier_run.lines.map(&:strip).reject(&:empty?) == expected_verifier_lines
    abort if verifier_run.include?("set +x") || verifier_run.include?("APPCAST_REPO_TOKEN")
    publisher = publish_steps.fetch(publisher_index)
    abort unless publisher.fetch("name") == "Publish verified appcast"
    abort unless publisher.fetch("env") == { "APPCAST_REPO_TOKEN" => "${{ secrets.APPCAST_REPO_TOKEN }}" }
    publisher_run = publisher.fetch("run")
    expected_publisher_lines = [
      "set -euo pipefail",
      "set +x",
      "bash scripts/publish-appcast.sh \\",
      "--candidate release/appcast-candidate.xml \\",
      "--archive-url \"${{ needs.release.outputs.archive_url }}\" \\",
      "--archive-sha256 \"${{ needs.release.outputs.archive_sha256 }}\" \\",
      "--release-probe scripts/verify-release-zip.sh \\",
      "--target-repo https://github.com/SKALIFE/attendance-appcast.git \\",
      "--branch main \\",
      "--appcast-path appcast.xml \\",
      "--raw-appcast-url https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml",
      "unset APPCAST_REPO_TOKEN"
    ]
    abort unless publisher_run.lines.map(&:strip).reject(&:empty?) == expected_publisher_lines
    abort if publisher_run.include?("bash scripts/verify-release-zip.sh")
    publish_steps.each_with_index do |step, index|
      abort if index != publisher_index && step.fetch("env", {}).key?("APPCAST_REPO_TOKEN")
    end

    notarized_app = release_steps.find { |step| step.fetch("name", "") == "Notarize and staple app" }
    abort unless notarized_app && notarized_app.fetch("env").fetch("APPLE_TEAM_ID") == "${{ secrets.APPLE_TEAM_ID }}"
    abort unless notarized_app.fetch("run").include?("codesign -d --verbose=4 \"$APP_PATH\" 2>&1")
    abort unless notarized_app.fetch("run").include?("grep -Fxq -- \"TeamIdentifier=$APPLE_TEAM_ID\" <<<\"$APP_SIGNATURE_DETAILS\"")
 ' "$WORKFLOW"; then
    fail 'Release and appcast publication boundary does not satisfy the protected handoff policy.'
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
require_text 'contents: read' 'read-only default contents permission'
require_text 'contents: write' 'contents: write release permission'
if [ "$(grep -Fc 'permissions:' "$WORKFLOW")" -ne 2 ]; then
    fail 'Workflow must declare default and release-job permissions only.'
fi
if [ "$(grep -Ec '^[[:space:]]+contents:[[:space:]]+read$' "$WORKFLOW")" -ne 1 ] || \
    [ "$(grep -Ec '^[[:space:]]+contents:[[:space:]]+write$' "$WORKFLOW")" -ne 1 ]; then
    fail 'Workflow must default to contents: read and grant contents: write only to the release job.'
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

if grep -E '^[[:space:]]+uses:' "$WORKFLOW" | grep -Ev '@[0-9a-f]{40}([[:space:]]+#.*)?$' >"$TEMP_DIR/mutable-actions"; then
    cat "$TEMP_DIR/mutable-actions" >&2
    fail 'Every action revision must be pinned to a full immutable commit SHA.'
fi
require_text 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' 'pinned checkout action'
require_text 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02' 'pinned appcast candidate upload action'
require_text 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093' 'pinned appcast candidate download action'
require_text 'fetch-depth: 0' 'full history for ancestry validation'
require_text 'persist-credentials: false' 'checkout credential persistence disabled'
require_text 'DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer' 'explicit Xcode selection'
require_text 'mint install yonaskolb/XcodeGen@2.42.0' 'pinned XcodeGen installation'
require_text 'printf '\''%s\n'\'' "$HOME/.mint/bin" >>"$GITHUB_PATH"' 'XcodeGen Mint path export'

require_text 'git rev-parse --verify --quiet refs/remotes/origin/main' 'fetched origin/main presence must be checked'
require_text 'git rev-parse --verify --quiet "$GITHUB_REF^{commit}"' 'tag commit presence must be checked'
require_text 'git merge-base --is-ancestor "$TAG_COMMIT" "refs/remotes/origin/main"' 'tag commit must be reachable from fetched main'
forbidden_fetches=$(grep -E '^[[:space:]]*git fetch([[:space:]]|$)' "$WORKFLOW" || true)
[ -z "$forbidden_fetches" ] || fail 'Release validation must not fetch after checkout credentials are disabled.'
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
require_text 'bash tests/sparkle_2_9_4_integration_test.sh' 'real Sparkle 2.9.4 layout and CLI integration probe'
require_text 'source-packages/artifacts/sparkle/Sparkle' 'resolved Sparkle 2.9.4 binary artifact root'
require_text 'test -x "$SPARKLE_TOOLS_ROOT/bin/sign_update"' 'resolved Sparkle 2.9.4 sign_update executable probe'
require_text 'bash scripts/package-release.sh' 'local package helper invocation'
require_text 'bash scripts/notarize.sh' 'local notarization helper invocation'
require_text 'bash scripts/notarize.sh --app "$APP_PATH"' 'app notarization before final archive creation'
require_text 'codesign -d --verbose=4 "$APP_PATH" 2>&1' 'final app signature detail inspection after notarization'
require_text 'grep -Fxq -- "TeamIdentifier=$APPLE_TEAM_ID" <<<"$APP_SIGNATURE_DETAILS"' 'final app TeamIdentifier verification after notarization'
require_text 'rm -f "$ZIP_PATH" "$DMG_PATH"' 'removal of pre-staple package artifacts'
require_text 'Rebuild ZIP from stapled app' 'ZIP recreation stage'
require_text 'Create and notarize DMG from stapled app' 'DMG finalization stage'
require_text 'KEYCHAIN_PATH="$RUNNER_TEMP/skala-dmg-release.keychain-db"' 'final DMG signing keychain path'
require_text 'P12_PATH="$RUNNER_TEMP/skala-dmg-release.p12"' 'final DMG certificate path'
require_text 'unset DEVELOPER_ID_APPLICATION_P12_BASE64 DEVELOPER_ID_APPLICATION_P12_PASSWORD' 'final DMG signing secret scrub'
require_text 'security default-keychain -d user -s "$ORIGINAL_KEYCHAIN"' 'final DMG default keychain restoration'
require_text 'security delete-keychain "$KEYCHAIN_PATH"' 'final DMG keychain cleanup'
require_text 'codesign --force --timestamp --identifier kr.skalife.attendance.disk-image --keychain "$KEYCHAIN_PATH" --sign "$IDENTITY_HASH" "$DMG_PATH"' 'Developer ID signature for final DMG'
require_text 'codesign --verify --strict --verbose=4 "$DMG_PATH"' 'final DMG signature verification'
require_text 'grep -Fxq -- "Authority=$IDENTITY" <<<"$SIGNATURE_DETAILS"' 'final DMG authority verification'
require_text 'grep -Fxq -- "TeamIdentifier=$APPLE_TEAM_ID" <<<"$SIGNATURE_DETAILS"' 'final DMG team verification'
require_text "grep -Eq '^Timestamp=.+$' <<<\"\$SIGNATURE_DETAILS\"" 'final DMG secure timestamp verification'
require_text 'bash scripts/notarize.sh --dmg "$DMG_PATH" --zip "$ZIP_PATH"' 'DMG notarization and rebuilt ZIP validation'

FINAL_DMG_STEP="$TEMP_DIR/final-dmg-step.yml"
awk '
    /- name: Create and notarize DMG from stapled app/ { capture = 1 }
    capture && /- name: Generate checksums for final release artifacts/ { exit }
    capture { print }
' "$WORKFLOW" >"$FINAL_DMG_STEP"
for final_dmg_policy in \
    'DEVELOPER_ID_APPLICATION_P12_BASE64: ${{ secrets.DEVELOPER_ID_APPLICATION_P12_BASE64 }}' \
    'DEVELOPER_ID_APPLICATION_P12_PASSWORD: ${{ secrets.DEVELOPER_ID_APPLICATION_P12_PASSWORD }}' \
    'ORIGINAL_KEYCHAIN=$(security default-keychain -d user 2>/dev/null | tr -d '\''"'\'' || true)' \
    '[ -z "$ORIGINAL_KEYCHAIN" ] || security default-keychain -d user -s "$ORIGINAL_KEYCHAIN"' \
    'printf '\''%s'\'' "$DEVELOPER_ID_APPLICATION_P12_BASE64" | base64 -D >"$P12_PATH"' \
    'trap cleanup EXIT' \
    'security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"' \
    'security import "$P12_PATH" -k "$KEYCHAIN_PATH"' \
    'security list-keychains -d user -s "$KEYCHAIN_PATH"' \
    'IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH"' \
    'IDENTITY_HASH=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH"' \
    'security default-keychain -d user -s "$ORIGINAL_KEYCHAIN"' \
    'rm -f "$P12_PATH"' \
    'security delete-keychain "$KEYCHAIN_PATH"' \
    'unset DEVELOPER_ID_APPLICATION_P12_BASE64 DEVELOPER_ID_APPLICATION_P12_PASSWORD'; do
    assert_contains "$FINAL_DMG_STEP" "$final_dmg_policy"
done
require_text 'bash scripts/generate-appcast-item.sh' 'real artifact appcast candidate validation'
require_text '--release-probe scripts/verify-local-release-candidate.sh' 'local candidate release probe'
require_text 'CHECKSUM_PATH="release/checksums.txt"' 'checksum artifact path'
require_text 'shasum -a 256 "$ZIP_PATH" "$DMG_PATH" >"$CHECKSUM_PATH"' 'checksum-file generation'
require_text 'gh release create "$TAG" "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"' 'atomic ZIP, DMG, and checksum attachment'
require_text 'RELEASE_NOTES_PATH="docs/releases/${VERSION}.md"' 'release notes path derived from VERSION'
require_text '--notes-file "$RELEASE_NOTES_PATH"' 'versioned release notes file'
require_text 'SOURCE_APPCAST_SHA256' 'source appcast integrity snapshot'
require_text 'test "$SOURCE_APPCAST_SHA256" = "$(shasum -a 256 tests/fixtures/current-appcast.xml' 'source appcast integrity check before release'
require_text 'environment: appcast-publish' 'protected appcast publication environment'
require_text 'bash scripts/verify-release-zip.sh' 'anonymous production release ZIP verification before appcast publication'
require_text 'bash scripts/publish-appcast.sh' 'guarded cross-repository appcast publisher'
require_text '--release-probe scripts/verify-release-zip.sh' 'production release ZIP verification before appcast mutation'
require_text '--target-repo https://github.com/SKALIFE/attendance-appcast.git' 'approved appcast repository target'
require_text '--raw-appcast-url https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml' 'actual raw appcast refetch verification'
require_text 'set +x' 'xtrace is explicitly disabled before appcast credential use'
require_text 'unset APPCAST_REPO_TOKEN' 'appcast credential is scrubbed after publisher setup'
forbid_text '--write' 'source appcast mutation before publication'
forbid_text 'gh release upload' 'release asset overwrite path'
forbid_text '--generate-notes' 'generated release notes in place of the approved release notes file'
forbid_text '--clobber' 'release asset overwrite path'
forbid_text 'verify_update' 'obsolete Sparkle verifier binary'
forbid_text 'checkouts/Sparkle/bin' 'Sparkle source checkout tool path'
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
[ -x "$ROOT/tests/sparkle_2_9_4_integration_test.sh" ] || fail 'Sparkle 2.9.4 integration probe is missing or not executable.'
grep -Fq 'SKALAAttendanceTests:' "$PROJECT" || fail 'project.yml must generate the SKALAAttendanceTests target.'
grep -Fq 'type: bundle.unit-test' "$PROJECT" || fail 'project.yml must define a unit-test bundle target.'
grep -Fq -- '- target: SKALAAttendance' "$PROJECT" || fail 'project.yml must declare the app dependency required by the release metadata tests.'
[ -f "$RELEASE_NOTES" ] || fail 'v0.1.10 Korean release notes are missing.'
grep -Fq '# SKALA Attendance 0.1.10' "$RELEASE_NOTES" || fail 'Release notes must identify v0.1.10.'
grep -Fq '익명 사용 통계' "$RELEASE_NOTES" || fail 'Release notes must describe the anonymous usage analytics setting.'
grep -Fq '출결 또는 로그인 자동화 동작에는 변경이 없습니다.' "$RELEASE_NOTES" || fail 'Release notes must preserve the attendance and login automation boundary.'
bash "$ROOT/tests/ensure_release_absent_test.sh"

REGRESSION_DIR="$TEMP_DIR/tag-ancestry-regression"
mkdir -p "$REGRESSION_DIR"
git -C "$REGRESSION_DIR" init --bare origin.git >/dev/null
git -C "$REGRESSION_DIR" clone -q origin.git source
git -C "$REGRESSION_DIR/source" config user.email test@example.invalid
git -C "$REGRESSION_DIR/source" config user.name 'Release Test'
printf 'release regression\n' >"$REGRESSION_DIR/source/README"
git -C "$REGRESSION_DIR/source" add README
git -C "$REGRESSION_DIR/source" commit -qm initial
git -C "$REGRESSION_DIR/source" branch -M main
git -C "$REGRESSION_DIR/source" push -q origin main
git -C "$REGRESSION_DIR/source" tag v1.0.0
git -C "$REGRESSION_DIR/source" push -q origin v1.0.0
git -C "$REGRESSION_DIR/source" fetch -q --tags origin
(cd "$REGRESSION_DIR/source" && GITHUB_REF=refs/tags/v1.0.0 bash -euo pipefail -c '
    test -n "$(git rev-parse --verify --quiet refs/remotes/origin/main)"
    TAG_COMMIT=$(git rev-parse --verify --quiet "$GITHUB_REF^{commit}")
    git merge-base --is-ancestor "$TAG_COMMIT" refs/remotes/origin/main
') 2>/dev/null || fail 'Local tag ancestry regression failed.'

git -C "$REGRESSION_DIR/source" update-ref -d refs/remotes/origin/main
if (cd "$REGRESSION_DIR/source" && GITHUB_REF=refs/tags/v1.0.0 bash -euo pipefail -c '
    test -n "$(git rev-parse --verify --quiet refs/remotes/origin/main)"
') 2>/dev/null; then
    fail 'Missing origin/main regression must fail closed.'
fi

stage_line() {
    grep -nF -- "$1" "$WORKFLOW" | /usr/bin/head -n 1 | cut -d: -f1
}

metadata_line=$(stage_line 'bash tests/release_metadata_test.sh')
install_xcodegen_line=$(stage_line 'mint install yonaskolb/XcodeGen@2.42.0')
generate_project_line=$(stage_line 'xcodegen generate')
keychain_line=$(stage_line 'security create-keychain')
release_build_line=$(stage_line 'xcodebuild build')
unit_test_line=$(stage_line 'xcodebuild test')
package_line=$(stage_line 'bash scripts/package-release.sh')
app_notarize_line=$(stage_line 'bash scripts/notarize.sh --app "$APP_PATH"')
zip_rebuild_line=$(stage_line 'Rebuild ZIP from stapled app')
final_dmg_line=$(stage_line 'Create and notarize DMG from stapled app')
dmg_create_line=$(stage_line 'hdiutil create \')
dmg_sign_line=$(stage_line 'codesign --force --timestamp --identifier kr.skalife.attendance.disk-image --keychain "$KEYCHAIN_PATH" --sign "$IDENTITY_HASH" "$DMG_PATH"')
dmg_verify_line=$(stage_line 'codesign --verify --strict --verbose=4 "$DMG_PATH"')
dmg_authority_line=$(stage_line 'grep -Fxq -- "Authority=$IDENTITY" <<<"$SIGNATURE_DETAILS"')
dmg_team_line=$(stage_line 'grep -Fxq -- "TeamIdentifier=$APPLE_TEAM_ID" <<<"$SIGNATURE_DETAILS"')
dmg_timestamp_line=$(stage_line "grep -Eq '^Timestamp=.+$' <<<\"\$SIGNATURE_DETAILS\"")
notarize_line=$(stage_line 'bash scripts/notarize.sh --dmg "$DMG_PATH" --zip "$ZIP_PATH"')
checksum_line=$(stage_line 'shasum -a 256 "$ZIP_PATH" "$DMG_PATH" >"$CHECKSUM_PATH"')
appcast_line=$(stage_line 'bash tests/appcast_item_test.sh')
candidate_line=$(stage_line 'bash scripts/generate-appcast-item.sh')
source_guard_line=$(stage_line 'Verify source appcast is unchanged')
release_line=$(stage_line 'gh release create "$TAG"')
candidate_upload_line=$(stage_line 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02')
verifier_line=$(stage_line 'bash scripts/verify-release-zip.sh')
publisher_line=$(stage_line 'bash scripts/publish-appcast.sh')
for line in "$metadata_line" "$install_xcodegen_line" "$generate_project_line" "$keychain_line" "$release_build_line" "$unit_test_line" "$package_line" "$app_notarize_line" "$zip_rebuild_line" "$final_dmg_line" "$dmg_create_line" "$dmg_sign_line" "$dmg_verify_line" "$dmg_authority_line" "$dmg_team_line" "$dmg_timestamp_line" "$notarize_line" "$checksum_line" "$appcast_line" "$candidate_line" "$source_guard_line" "$release_line" "$candidate_upload_line" "$verifier_line" "$publisher_line"; do
    [[ "$line" =~ ^[0-9]+$ ]] || fail 'Expected release stage is missing from the workflow.'
done
if ! (( metadata_line < install_xcodegen_line && install_xcodegen_line < generate_project_line && generate_project_line < keychain_line && keychain_line < release_build_line && release_build_line < unit_test_line && unit_test_line < package_line && package_line < app_notarize_line && app_notarize_line < zip_rebuild_line && zip_rebuild_line < final_dmg_line && final_dmg_line < dmg_create_line && dmg_create_line < dmg_sign_line && dmg_sign_line < dmg_verify_line && dmg_verify_line < dmg_authority_line && dmg_authority_line < dmg_team_line && dmg_team_line < dmg_timestamp_line && dmg_timestamp_line < notarize_line && notarize_line < checksum_line && checksum_line < appcast_line && appcast_line < candidate_line && candidate_line < source_guard_line && source_guard_line < release_line && release_line < candidate_upload_line && candidate_upload_line < verifier_line && verifier_line < publisher_line )); then
    fail 'Pinned XcodeGen installation and GitHub Release creation must follow the required release stage order.'
fi

if ! ruby -e '
    contents = File.read(ARGV.fetch(0))
    signed_build = /xcodebuild build \\\n+\s+-project SKALAAttendance\.xcodeproj \\\n+\s+-scheme SKALAAttendance \\\n+\s+-configuration Release \\\n+\s+-derivedDataPath build \\\n+\s+-clonedSourcePackagesDirPath "\$RUNNER_TEMP\/source-packages" \\\n+\s+-destination '\''platform=macOS,arch=arm64'\''/.match?(contents)
    unsigned_test = /xcodebuild test \\\n+\s+-project SKALAAttendance\.xcodeproj \\\n+\s+-scheme SKALAAttendance \\\n+\s+-configuration Release \\\n+\s+-derivedDataPath build \\\n+\s+-clonedSourcePackagesDirPath "\$RUNNER_TEMP\/source-packages" \\\n+\s+-destination '\''platform=macOS,arch=arm64'\'' \\\n+\s+CODE_SIGNING_ALLOWED=NO \\\n+\s+CODE_SIGNING_REQUIRED=NO\s*$/.match?(contents)
     abort unless signed_build && contents.include?(%q{-derivedDataPath "$RUNNER_TEMP/test-derived-data"}) && contents.include?(%q{CODE_SIGNING_ALLOWED=NO}) && contents.include?(%q{CODE_SIGNING_REQUIRED=NO})
' "$WORKFLOW"; then
    fail 'Signed app build must remain unchanged and XCTest must end with both unsigned build settings.'
fi

if grep -F -- 'xcodebuild test' "$WORKFLOW" | grep -F -- '-derivedDataPath build' >/dev/null; then
    fail 'Regression: XCTest must not share build derived data with the signed app (run 30274749016 removed Sparkle _CodeSignature).'
fi

printf 'Release workflow offline policy tests passed.\n'
