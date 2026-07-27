#!/usr/bin/env ruby
require "yaml"

ROOT = File.expand_path("..", __dir__)
WORKFLOW = File.join(ROOT, ".github/workflows/validate-runner-setup.yml")
SIGNING_SECRETS = %w[
  DEVELOPER_ID_APPLICATION_P12_BASE64
  DEVELOPER_ID_APPLICATION_P12_PASSWORD
].freeze
FORBIDDEN_SECRET_VARIABLES = %w[
  DEVELOPER_ID_APPLICATION_P12_BASE64
  DEVELOPER_ID_APPLICATION_P12_PASSWORD
  APPLE_TEAM_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_PRIVATE_KEY_BASE64
  SPARKLE_EDDSA_PRIVATE_KEY
  APPCAST_REPO_TOKEN
  GH_TOKEN
].freeze
FORBIDDEN_TEXT = %w[
  notarytool
  stapler
  scripts/notarize.sh
  gh\ release
  gh\ api
  git\ push
  git\ tag
  git\ commit
  scripts/publish-appcast.sh
  scripts/generate-appcast-item.sh
  APPLE_TEAM_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_PRIVATE_KEY_BASE64
  SPARKLE_EDDSA_PRIVATE_KEY
  APPCAST_REPO_TOKEN
  actions/upload-artifact
  upload-release-asset
  softprops/action-gh-release
  ncipollo/release-action
].freeze

class PolicyError < StandardError; end

def require_policy(condition, message)
  raise PolicyError, message unless condition
end

def no_secret_output!(contents)
  FORBIDDEN_SECRET_VARIABLES.each do |secret|
    output = contents.lines.any? do |line|
      line.match?(/\b(?:echo|printf)\b.*\$\{?#{Regexp.escape(secret)}\}?/) &&
        line !~ /printf '%s' "\$DEVELOPER_ID_APPLICATION_P12_BASE64" \| base64 -D >"\$P12_PATH"/
    end
    require_policy(!output, "workflow must not write #{secret} to standard output")
  end
end

def no_direct_secret_interpolation!(contents)
  direct_reference = contents.lines.find do |line|
    line.include?("${{ secrets.") &&
      !SIGNING_SECRETS.any? { |secret| line.match?(/^\s+#{secret}: \$\{\{ secrets\.#{secret} \}\}\s*$/) }
  end
  require_policy(direct_reference.nil?, "workflow must inject secrets only through approved step environment mappings")
end

def no_environment_dump!(contents)
  dump = contents.lines.any? do |line|
    line.match?(/^\s*(?:printenv|\/usr\/bin\/printenv|env|\/usr\/bin\/env)(?:\s|$)/)
  end
  require_policy(!dump, "workflow must not dump the environment")
end

def no_xtrace!(contents)
  xtrace = contents.lines.any? do |line|
    line.match?(/^\s*set\s+-[[:alpha:]]*x/) ||
      line.match?(/^\s*set\s+-o\s+xtrace\b/) ||
      line.match?(/^\s*(?:bash|sh)\s+-[[:alpha:]]*x/)
  end
  require_policy(!xtrace, "workflow must not enable xtrace")
end

def validate_workflow!(contents, workflow)
  trigger = workflow.fetch(true)
  require_policy(trigger.keys == ["workflow_dispatch"], "workflow must be manual-only")
  require_policy(workflow.fetch("permissions") == { "contents" => "read" }, "workflow must have read-only contents permission")

  jobs = workflow.fetch("jobs")
  require_policy(jobs.keys == ["validate"], "workflow must have exactly one validation job")
  job = jobs.fetch("validate")
  require_policy(job.fetch("runs-on") == "macos-14", "workflow must use the macos-14 runner")
  require_policy(
    job.fetch("if") == "github.ref == 'refs/heads/main'",
    "workflow job must run only on main"
  )
  require_policy(job.fetch("env").fetch("DEVELOPER_DIR") == "/Applications/Xcode_16.2.app/Contents/Developer", "workflow must select Xcode 16.2")

  uses = contents.scan(/^\s+uses:\s*(\S+)$/).flatten
  require_policy(uses == ["actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"], "workflow must use only pinned checkout")
  require_policy(contents.include?("persist-credentials: false"), "checkout credentials must not persist")

  secret_names = contents.scan(/secrets\.([A-Z0-9_]+)/).flatten.uniq.sort
  require_policy(secret_names == SIGNING_SECRETS.sort, "workflow may reference only signing certificate secrets")
  no_secret_output!(contents)
  no_direct_secret_interpolation!(contents)
  no_environment_dump!(contents)
  no_xtrace!(contents)

  FORBIDDEN_TEXT.each do |text|
    require_policy(!contents.include?(text), "workflow must not contain prohibited publication capability: #{text}")
  end

  require_policy(
    contents.lines.count { |line| line.strip == 'CODE_SIGN_IDENTITY="$IDENTITY" xcodebuild build \\' } == 1,
    "release app build must remain signed"
  )
  require_policy(
    contents.match?(
      /xcodebuild test \\\n+\s+-project SKALAAttendance\.xcodeproj \\\n+\s+-scheme SKALAAttendance \\\n+\s+-configuration Release \\\n+\s+-derivedDataPath "\$RUNNER_TEMP\/derived-data" \\\n+\s+-clonedSourcePackagesDirPath "\$RUNNER_TEMP\/source-packages" \\\n+\s+-destination 'platform=macOS,arch=arm64' \\\n+\s+CODE_SIGNING_ALLOWED=NO \\\n+\s+CODE_SIGNING_REQUIRED=NO\s*$/
    ),
    "XCTest invocation must end with both code-signing build settings"
  )

  %w[
    security\ create-keychain
    security\ import
    security\ set-key-partition-list
    security\ default-keychain\ -d\ user\ -s\ "$KEYCHAIN_PATH"
    security\ default-keychain\ -d\ user\ -s\ "$ORIGINAL_KEYCHAIN"
    security\ delete-keychain\ "$KEYCHAIN_PATH"
    trap\ cleanup\ EXIT
    rm\ -f\ "$P12_PATH"
    security\ find-identity\ -v\ -p\ codesigning
    CODE_SIGN_IDENTITY="$IDENTITY"\ xcodebuild\ build
    xcodebuild\ test
    xcodegen\ generate
    xcodebuild\ -resolvePackageDependencies
    bash\ tests/release_workflow_test.sh
    bash\ tests/release_metadata_test.sh
    bash\ tests/release_preflight_test.sh
    mint\ install\ yonaskolb/XcodeGen@2.42.0
    printf\ '%s\\n'\ "$HOME/.mint/bin"\ >>"$GITHUB_PATH"
  ].each do |text|
    require_policy(contents.include?(text), "workflow is missing required validation: #{text}")
  end

  install_line = contents.index("mint install yonaskolb/XcodeGen@2.42.0")
  generate_line = contents.index("xcodegen generate")
  require_policy(install_line && generate_line && install_line < generate_line, "workflow must install pinned XcodeGen before generation")
end

abort "Runner setup workflow is missing." unless File.file?(WORKFLOW)

contents = File.read(WORKFLOW)
workflow = YAML.safe_load(contents, aliases: false)
validate_workflow!(contents, workflow)

release_automation_guard = contents.sub(
  "github.ref == 'refs/heads/main'",
  "github.ref == 'refs/heads/release-automation'"
)
begin
  validate_workflow!(release_automation_guard, YAML.safe_load(release_automation_guard, aliases: false))
rescue PolicyError
else
  raise "Release-automation-only workflow guard was not rejected."
end

secret_output_mutations = FORBIDDEN_SECRET_VARIABLES.to_h do |secret|
  ["secret-output-#{secret}", "echo \"$#{secret}\""]
end
secret_output_mutations.merge!(
  "direct-secret-interpolation" => "echo \"${{ secrets.DEVELOPER_ID_APPLICATION_P12_BASE64 }}\"",
  "printenv" => "printenv",
  "environment-dump" => "env | sort",
  "xtrace" => "set -x",
  "xtrace-option" => "set -o xtrace"
)

secret_output_mutations.each do |name, unsafe_line|
  mutated = contents.sub("set -euo pipefail", "set -euo pipefail\n          #{unsafe_line}")
  begin
    validate_workflow!(mutated, YAML.safe_load(mutated, aliases: false))
  rescue PolicyError
    next
  end
  raise "Unsafe workflow mutation #{name} was not rejected."
end

missing_test_signing_flag = contents.sub(
  /CODE_SIGNING_ALLOWED=NO \\\n+\s+CODE_SIGNING_REQUIRED=NO/,
  "CODE_SIGNING_REQUIRED=NO"
)
begin
  validate_workflow!(missing_test_signing_flag, YAML.safe_load(missing_test_signing_flag, aliases: false))
rescue PolicyError
else
  raise "Missing XCTest signing flag was not rejected."
end

misplaced_test_signing_flag = contents.sub(
  /CODE_SIGNING_ALLOWED=NO \\\n+\s+CODE_SIGNING_REQUIRED=NO/,
  "CODE_SIGNING_ALLOWED=NO xcodebuild test"
)
begin
  validate_workflow!(misplaced_test_signing_flag, YAML.safe_load(misplaced_test_signing_flag, aliases: false))
rescue PolicyError
else
  raise "Misplaced XCTest signing flags were not rejected."
end

puts "Runner setup workflow offline policy and YAML parser checks passed."
