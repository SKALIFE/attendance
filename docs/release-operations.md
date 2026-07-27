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

## Protected GitHub Environment migration

Move release credentials to a protected GitHub Environment in a separately
reviewed workflow change; this documentation change does not alter the current
publication workflow. Create an environment named `release`, restrict its
deployment branches and tags to the approved release policy (the `v*` tag
pattern), and require reviewers before a job can access its secrets. If the
repository plan supports it, add an appropriate wait timer as a second human
review window.

After the protection rules are active, set the release job's
`environment: release` and add the eight existing release secret names to that
Environment. Confirm a protected test run reaches the approval gate without
printing a value, then remove the duplicate repository-level secrets. Do not
move unrelated credentials into this Environment, weaken deployment branch
restrictions, or remove a repository secret before the protected workflow has
been reviewed and exercised. Environment protection is an approval boundary;
it does not permit manual signing, publication, or appcast edits outside CI.

## Prepare, commit, push, and tag

1. Pick the next semantic version and update `MARKETING_VERSION` in
   `project.yml` to that version without the `v` prefix.
2. Increase `CURRENT_PROJECT_VERSION` to a decimal build number greater than
   the newest build already present in the appcast. Do not reuse a build number.
3. Run the ordinary local checks, review the version-only diff, then create a
   version-bump commit. For example: `git commit -am 'chore: release 0.1.1'`.
4. Push that reviewed commit to `main`: `git push origin main`. The tag must
   point at a commit reachable from `main`.
5. Create the annotated tag from that exact commit, for example:
   `git tag -a v0.1.1 -m 'Release v0.1.1'`.
6. Push only that tag: `git push origin v0.1.1`. This starts the release CI
   workflow. Do not retag, force-push, or reuse a released version.

Before pushing the tag, run the read-only preflight with the locally prepared
candidate inputs. A fixture-style invocation is:

```bash
bash scripts/release/preflight.sh v0.1.1 \
  --project tests/fixtures/release-0.1.1-build-2.yml \
  --appcast tests/fixtures/current-appcast.xml \
  --candidate /path/to/appcast-candidate.xml \
  --archive /path/to/SKALA-Attendance-0.1.1-arm64.zip \
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

The appcast candidate is generated and validated before release creation. Only
after the GitHub Release and its assets exist does CI publish that candidate to
the separate appcast repository. The appcast publication is therefore the last
public availability step; a green build or created release alone does not mean
the update feed has changed.

## Rollback before feed publication

Before the tag is pushed, correct the version bump or candidate, remove the
unpublished local tag if one was made, and make a new reviewed commit. Do not
push an unreviewed release tag.

If the tag-triggered workflow has started but has not yet published the feed,
the existing appcast remains unchanged. Stop escalation, preserve CI logs and
the candidate for diagnosis, and do not manually edit the feed or overwrite
the tag or release. Fix forward with a new version and build after the failure
is understood. Once feed publication has completed, follow the appcast
repository's incident procedure rather than attempting an in-place rewrite.

## CI GUI boundary

CI is limited to building and validating the distributable application. It
must not launch or automate the menu-bar UI, WKWebView, login page, attendance
actions, cookies, or browser controls. Any GUI smoke check is a manual operator
activity after obtaining the signed artifact; it is not part of release CI.
