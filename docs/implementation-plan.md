# SKALA Attendance Implementation Plan

This plan follows `docs/PRODUCT_SPEC.md` as the source of truth and keeps credential-dependent checks separate from locally verifiable work.

## Scope Boundaries

- The app opens the official attendance page in installed Google Chrome with a dedicated profile and mobile browser emulation.
- The app never calls attendance APIs, clicks attendance buttons, manipulates Google login, reads Chrome cookies, stores auth tokens, or modifies the normal Chrome profile.
- Remote push, PR creation, tag/release publication, Apple certificate changes, production Umami deployment, and GitHub secret changes are out of scope without explicit user approval.

## Local Scenarios

1. Happy path: `scripts/test.sh` passes with tests proving dedicated Chrome profile paths, Chrome launch arguments, CDP command encoding, mobile emulation payloads, and Umami payload minimization.
2. Edge path: tests prove missing Chrome is user-safe, analytics is no-op when unconfigured or opted out, and browser reset cannot delete outside the app-owned support directory.
3. Adjacent regression: repository review confirms no attendance API automation, no normal Chrome profile access, no cookie/token collection, no Sparkle private key, and no official-app impersonation claim.

## Implementation Waves

1. Environment and repository baseline: record local Swift/Xcode/XcodeGen/Chrome state and keep existing untracked user files untouched.
2. Project skeleton: add XcodeGen project, xcconfig files, app entry point, menu-bar host, scripts, and a smoke test.
3. Core safety: add app constants, preferences, support paths, safe profile reset rules, status/error copy, and tests.
4. Chrome/CDP: add Chrome discovery, version parsing, isolated launch arguments, dynamic DevTools port support, CDP JSON-RPC foundations, mobile emulation commands, navigation/window commands, and tests.
5. Native app flows: add menu bar controls, onboarding, settings, login-item wrapper, update wrapper, and user-safe diagnostics.
6. Analytics: add consent-gated Umami v3 client with no-op configuration, anonymous install ID, bounded timeout, and payload tests.
7. Distribution: add Sparkle configuration shell, release scripts, DMG script, CI and release workflows, Umami self-hosting example, and release documentation.
8. Verification and documentation: run generated-project build/test, local release script validation, security-boundary searches, and update `docs/IMPLEMENTATION_STATUS.md` honestly.

## Manual Or Credential-Gated Checks

- Google SSO, passkey, Touch ID, and real attendance-page mobile detection require human interaction.
- Developer ID signing, notarization, stapling, Gatekeeper validation, Sparkle production update installation, GitHub Pages appcast publication, GitHub Release, and production Umami ingestion require credentials or explicit release approval.

## Verification Commands

```bash
scripts/bootstrap.sh
scripts/test.sh
scripts/build.sh Debug
scripts/build.sh Release
scripts/release-local.sh --unsigned
```

Final review also searches for prohibited attendance API automation, cookies/tokens, normal Chrome profile paths, AppleScript/Accessibility control, private keys, and official-app claims.
