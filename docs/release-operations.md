# Release operator runbook

This runbook describes the human-controlled path for a signed macOS release. It
does not replace the tag-triggered CI workflow, and it never requires putting a
secret value in the repository, command history, issue, or log.

## Release secrets

Configure these existing GitHub Actions secret **names** only; their values are
not documented here.

- `DEVELOPER_ID_APPLICATION_P12_BASE64` — Developer ID certificate archive for
  the isolated CI keychain.
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD` — password for that certificate
  archive.
- `APPLE_TEAM_ID` — Apple team used by notarization.
- `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect API issuer identifier.
- `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key identifier.
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` — App Store Connect API private-key
  archive.
- `SPARKLE_EDDSA_PRIVATE_KEY` — signing key used only to create the Sparkle
  update signature.
- `APPCAST_REPO_TOKEN` — token used only for the separate appcast repository.

`APPCAST_REPO_TOKEN` must follow least privilege: use a fine-grained token
restricted to `SKALIFE/attendance-appcast`, grant only the repository contents
access needed to update `appcast.xml`, and do not grant access to the main
application repository, organization administration, Actions, packages, or any
other repository. Rotate or revoke it if it is exposed. The workflow's built-in
`github.token` creates the release in this repository; it is not a replacement
for the cross-repository token.

## Protected `appcast-publish` environment

The `publish-appcast` job is the sole appcast publication boundary. Configure
the GitHub Environment named `appcast-publish` before enabling releases:

```yaml
environment: appcast-publish
```

1. Restrict deployment branches and tags to the approved `v*` release-tag
   policy.
2. Enable required reviewers and assign the approved release reviewers. At
   least one reviewer must approve each publication; do not allow self-review
   where the repository plan offers that control.
3. Scope `APPCAST_REPO_TOKEN` to this Environment only. Do not put signing,
   notarization, or unrelated repository credentials in it.

An explicitly approved single-operator exception may use the sole operator as
the required reviewer with self-review allowed. This remains a manual pause,
not independent approval. Do not create a second account controlled by the
same person to simulate separation of duties. Record the exception, keep the
workflow disabled until GitHub can enforce the required-reviewer rule, and
replace self-review with another trusted reviewer when one becomes available.

The release job builds, signs, notarizes, creates the GitHub Release, and
uploads the generated `appcast-candidate.xml` as a short-lived workflow
artifact. It has no appcast publisher invocation or appcast token. The
dependent `publish-appcast` job cannot start until the Environment approval is
granted. It checks out the tagged source without persisted credentials,
downloads that candidate, and anonymously downloads and verifies the released
ZIP against the release job's immutable URL, size, and SHA-256 outputs before
it invokes the publisher. The appcast token is unavailable during this
anonymous verification step and is mapped only for the subsequent publisher.

No appcast publication may occur before approval. A created GitHub Release is
not authorization to edit the update feed. Do not manually edit the feed,
bypass the Environment, replay the candidate with a local token, or weaken the
reviewer and tag restrictions.

If a Sparkle signing key is suspected compromised, stop at the Environment
approval gate and follow the incident procedure before publishing a new feed
item. Key rotation must preserve a verifiable transition for already installed
versions; it cannot make an already compromised signing key trustworthy. Keep
the same Developer ID Application team identity for update releases: the final
notarized app must report the configured `APPLE_TEAM_ID`. Coordinate any
Developer ID or update-key transition with the Sparkle compatibility and
incident owners rather than publishing a manual feed edit.

## Prepare, commit, push, and tag

1. Pick the next semantic version and update `MARKETING_VERSION` in
   `project.yml` to that version without the `v` prefix.
2. Increase `CURRENT_PROJECT_VERSION` to a decimal build number greater than
   the newest build already present in the appcast. Do not reuse a build number.
3. Run the ordinary local checks and review the complete diff, including
   untracked release notes. Stage every intended path explicitly; for a normal
   version bump, for example:
   `git add -- project.yml docs/releases/0.1.10.md`. If the release includes
   other reviewed workflow, generated metadata, test, or documentation
   changes, add those exact paths as well rather than using `git add -A`.
   Run `git diff --cached --check`, inspect `git diff --cached`, and confirm
   `git status --short` shows no intended release file left unstaged. Then
   create the commit with `git commit -m 'build(release): prepare v0.1.10 build 11'`.
4. Push that reviewed commit to `main`: `git push origin main`. The tag must
   point at a commit reachable from `main`.
5. Create the annotated tag from that exact commit, for example:
   `git tag -a v0.1.10 -m 'Release v0.1.10'`.
6. Push only that tag: `git push origin v0.1.10`. This starts the release CI
   workflow. Do not retag, force-push, or reuse a released version.

Before pushing the tag, run the read-only preflight with the locally prepared
candidate inputs. A fixture-style invocation is:

```bash
bash scripts/release/preflight.sh v0.1.10 \
  --project tests/fixtures/release-0.1.10-build-11.yml \
  --appcast tests/fixtures/current-appcast.xml \
  --candidate /path/to/appcast-candidate.xml \
  --archive /path/to/SKALA-Attendance-0.1.10-arm64.zip \
  --archive-sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef \
  --sparkle-tools-root /path/to/pinned-sparkle-tools \
  --release-probe /path/to/release-probe
```

The tag is the first argument. The command validates a clean Git worktree,
release metadata, release-workflow policy, all offline release helper tests,
candidate XML, URL, version/build uniqueness, archive digest and length, and
availability probe. It resolves the pinned Sparkle `sign_update` artifact and
verifies the local archive's Ed25519 signature with the project public key; no
private Sparkle key is supplied.
It does not sign, notarize, contact GitHub, create a release, publish an
appcast, or write the feed.

## CI outputs and publication order

CI builds, signs, notarizes, and validates the final artifacts. A successful
GitHub Release contains these outputs:

- `SKALA-Attendance-<version>-arm64.zip`
- `SKALA-Attendance-<version>-arm64.dmg`
- `checksums.txt`

The appcast candidate is generated and validated before release creation. Once
the GitHub Release and assets exist, the release job hands the candidate to the
approval-gated `publish-appcast` job as a short-lived artifact. After an
`appcast-publish` reviewer approves it, that job anonymously verifies the
released ZIP's immutable URL, byte size, and SHA-256 before it can publish the
candidate to the separate appcast repository. The appcast publication is the
last public availability step; a green build or created release alone does not
mean the update feed has changed.

## Rollback before feed publication

Before the tag is pushed, correct the version bump or candidate, remove the
unpublished local tag if one was made, and make a new reviewed commit. Do not
push an unreviewed release tag.

If the tag-triggered workflow has started but the Environment has not approved
publication, the existing appcast remains unchanged. Stop escalation, preserve
CI logs and the candidate for diagnosis, and do not manually edit the feed or
overwrite the tag or release. Fix forward with a new version and build after
the failure is understood. Once feed publication has completed, follow the
appcast repository's incident procedure rather than attempting an in-place
rewrite.

## CI GUI boundary

CI is limited to building and validating the distributable application. It
must not launch or automate the menu-bar UI, WKWebView, login page, attendance
actions, cookies, or browser controls. Any GUI smoke check is a manual operator
activity after obtaining the signed artifact; it is not part of release CI.
