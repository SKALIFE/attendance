# Release operator runbook

This is the canonical human-controlled procedure for a signed macOS release.
A release starts only after an explicit maintainer request. This runbook does
not replace the tag-triggered CI workflow, and it never requires putting a
secret value in the repository, command history, issue, or log.

## Release authorization

Repository changes do not authorize a release by themselves. Source, resource,
documentation, test, CI, release-note, or `main` changes; passing checks; a
completed milestone; and elapsed time must never cause an agent or automation
to start a release.

An explicit maintainer instruction such as "release v0.1.12" or "publish the
current reviewed changes as a new version" authorizes preparation through the
tag-triggered release job and verification of the signed GitHub Release
artifacts. A request to edit, commit, merge, push, prepare for a future release,
or update release notes is not release authorization.

The initial release instruction does **not** authorize appcast publication.
After the release job succeeds, verify the exact tag commit, workflow result,
ZIP, DMG, `checksums.txt`, Developer ID signature, notarization, Sparkle
signature, candidate history, and unchanged live appcast. Present that evidence
to the maintainer and request a second approval. Approval cannot be granted
prospectively in the initial release request. Do not approve the protected
`appcast-publish` Environment or otherwise publish the feed until the maintainer
responds with explicit approval after reviewing the evidence.

## Release scope

Documentation-only, test-only, comment, formatting, and CI or developer-tooling
changes that do not alter the distributed app require ordinary review and
validation but no app release. They may be merged without changing
`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, a tag, a GitHub Release, or the
appcast. Editing release documentation never authorizes a release.

The maintainer decides when to release and which completed changes to group.
Every application-affecting change reachable from the exact tagged `main`
commit is included; there is no hidden per-feature selection after tagging.
Keep unfinished or intentionally deferred application work outside that
commit. If an explicitly requested release contains no distributable behavior
change, state that the new app will differ only in release metadata before
preparation; the maintainer may still direct the release.

## Unreleased change record

Use `docs/releases/unreleased.md` to preserve the user-relevant scope of the
next possible release across sessions. Add completed, shipped-app changes when
they merge. Do not add repository-only documentation, tests, or tooling unless
they materially change installation, update, or release reliability visible to
users.

At release preparation:

1. Compare the exact previous app tag with the proposed tagged `main` commit.
2. Reconcile every user-relevant app change with
   `docs/releases/unreleased.md`; the Git diff remains the source of truth.
3. Copy the reconciled entries into `docs/releases/<version>.md`.
4. Reset `docs/releases/unreleased.md` to its empty template in the same
   release-preparation commit.

An empty unreleased record does not block a metadata-only release that the
maintainer explicitly requested, but it must be called out. Updating or
emptying the record is never release authorization.

## Version and build policy

While the product remains on the `0.1.x` line, increment the patch component by
exactly one for each public app release. Increase
`CURRENT_PROJECT_VERSION` to a decimal build number greater than every build in
the live appcast; never reuse a build number. Features and fixes may share one
release. Use `0.2.0` or another milestone version only when the maintainer
explicitly selects it. Documentation-only work does not change either number.

## Release readiness gate

Do not prepare or push a release tag until all of these conditions hold:

- The maintainer explicitly requested a release.
- The exact included commit and all application-affecting changes are known.
- Included work is complete, reviewed, and verified; no release blocker remains.
- The unreleased record is reconciled and the versioned release note is ready.
- Version and build values satisfy the policy above and are unique.
- The complete release diff is reviewed and the worktree is clean.
- The tag will point to the exact reviewed commit reachable from `origin/main`.

These checks determine whether the requested release can proceed safely. They
never decide that a release should occur.

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

1. Confirm the explicit release instruction and freeze the included commit
   scope. Reconcile `docs/releases/unreleased.md` against the complete diff
   from the previous app tag, create `docs/releases/<version>.md`, and reset
   the unreleased file to its empty template.
2. Apply the version policy: increment the current `0.1.x` patch by exactly
   one unless the maintainer selected a milestone version. Update
   `MARKETING_VERSION` without the `v` prefix and increase
   `CURRENT_PROJECT_VERSION` beyond every build in the live appcast.
3. Run the ordinary local checks and review the complete diff, including
   untracked release notes. Stage every intended path explicitly; for example:
   `git add -- project.yml docs/releases/unreleased.md docs/releases/0.1.12.md`.
   Add any reviewed workflow, generated metadata, fixture, test, or other
   release path explicitly rather than using `git add -A`. Run
   `git diff --cached --check`, inspect `git diff --cached`, and confirm
   `git status --short` shows no intended release file left unstaged. Then
   create a preparation commit such as
   `git commit -m 'build(release): prepare v0.1.12 build 13'`.
4. Push the release branch, open a reviewed pull request, and merge it into
   `main`. Fetch `origin/main`, identify the exact merged commit, and confirm
   that its complete contents are the intended release. The tag must point to
   that exact commit, not merely the pre-merge branch commit.
5. Run the required checks and read-only preflight from the exact merged
   source. Create the annotated tag on that commit, for example:
   `git tag -a v0.1.12 <exact-main-commit> -m 'Release v0.1.12'`.
6. Push only that tag: `git push origin refs/tags/v0.1.12`. This starts the
   release CI workflow. Do not retag, force-push, or reuse a released version.

Before pushing the tag, run the read-only preflight with the locally prepared
candidate inputs. A fixture-style invocation is:

```bash
bash scripts/release/preflight.sh v0.1.11 \
  --project tests/fixtures/release-0.1.11-build-12.yml \
  --appcast tests/fixtures/current-appcast.xml \
  --candidate /path/to/appcast-candidate.xml \
  --archive /path/to/SKALA-Attendance-0.1.11-arm64.zip \
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

## Publication approval gate

The initial release instruction ends at a verified GitHub Release while the
`publish-appcast` job waits on the protected Environment. Before asking for the
second approval, report all of the following:

- exact tag and tagged `main` commit;
- successful release job and workflow URL;
- ZIP, DMG, and `checksums.txt` asset names, sizes, and SHA-256 values;
- Developer ID identity, hardened-runtime result, and notarization ticket;
- Sparkle signature verification and candidate version/build uniqueness;
- candidate preservation of prior appcast history; and
- proof that the live appcast still exposes the previous release.

Ask the maintainer whether to approve publication only after presenting this
evidence. Silence, the initial release request, a successful release job, and a
created GitHub Release are not approval. After the maintainer explicitly
approves, grant the `appcast-publish` deployment approval, wait for the
publisher to succeed, and verify that the live feed contains the new
version/build exactly once while preserving prior history.

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
