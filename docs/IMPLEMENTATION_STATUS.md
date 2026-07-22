# Implementation Status

이 문서는 루프와 개발자가 실제 구현 상태를 추적하기 위한 체크리스트다.

## Current state

- Status: Locally verifiable v1.0.0-ready candidate with native SwiftUI shell redesign, reliability/UX follow-up, and verified limited-scope Umami Cloud ingestion
- Current phase: Phase 9 + Native shell redesign (DESIGN.md) + reliability/UX follow-up + Umami Cloud telemetry migration verification
- Current branch: `feat/initial-implementation`
- Last verified state: `2b20507` plus current uncommitted working tree (includes native shell redesign and Umami Cloud telemetry migration verification)
- Last updated: 2026-07-22 (Umami Cloud Hobby US telemetry migration verification)

## Phases

- [x] Phase 0: 환경 및 저장소 확인
- [x] Phase 1: 프로젝트 구조와 구현 계획
- [x] Phase 2: Chrome/CDP 프로토타입
- [x] Phase 3: Swift 메뉴바 앱
- [x] Phase 4: 온보딩과 설정
- [x] Phase 5: Umami 통계
- [x] Phase 6: Sparkle 업데이트
- [x] Phase 7: CI 및 릴리스 자동화
- [x] Phase 8: 문서와 테스트
- [x] Phase 9: 로컬 최종 검증과 repository review
- [x] Native shell redesign: DESIGN.md 기반 메뉴 패널/온보딩/설정 네이티브 다듬기 (window-style MenuBarExtra, SKALAAttendance/Design 토큰·프리미티브, 그룹 섹션·SF Symbols·helper text)
- [x] Reliability/UX follow-up: saved launch bounds, non-error diagnostics, concise panel status, transient app-owned onboarding replay, Sparkle key setup documentation

## Functional verification

### Build and project

- [x] XcodeGen 또는 선택한 프로젝트 생성 방식 동작
- [x] arm64 Debug build
- [x] arm64 Release build
- [x] unit tests
- [x] 인증서 없는 로컬 Debug build
- [x] macOS 26.0 deployment target

### Menu bar app

- [x] 메뉴바 아이콘 표시: Release app launch smoke passed; visual menu interaction remains manual QA.
- [x] 메뉴바 패널 다듬기 (DESIGN.md): `MenuBarExtra` switched to `.window` style; panel rendered with `SKALAAttendance/Design` primitives (header, `PrimaryAttendanceAction`, `CommandRow`, `StatusRow`); layout, dismissal, hover/focus/disabled states and onboarding activation preserved; visual panel interaction remains manual QA.
- [x] Dock에 상시 아이콘이 남지 않음: `LSUIElement = true` configured.
- [x] 출결 페이지 열기: command launches dedicated Chrome using saved window bounds, discovers target, connects CDP WebSocket, applies mobile emulation, then navigates; real Google/auth flow remains manual QA.
- [x] 창 앞으로 가져오기: command is wired and reads current CDP bounds for persisted window position.
- [x] 페이지 새로고침
- [x] 앱 종료
- [x] 설정 화면
- [x] 설정 네이티브 다듬기 (DESIGN.md): 일반/개인정보/브라우저/업데이트/정보 탭 유지하며 그룹 `Form` 섹션, SF Symbols, helper text, 접근성 라벨/힌트 추가; 토글·초기화 확인 다이얼로그·진단·Finder 표시·PRIVACY.md 열기 등 기존 바인딩/액션 경로 유지; 시각적 섹션 레이아웃은 수동 QA 필요.
- [x] 연결 진단: 진단 결과를 표시하지만 앱 상태를 연결 오류로 바꾸지 않음.
- [x] 메뉴바 상태 요약: 기본 패널에는 사용자용 상태만 표시하고 기술 세부정보는 설정의 연결 진단에 한정.

### Chrome

- [x] Chrome 설치 경로 탐색
- [x] Chrome 미설치 안내: onboarding checks standard Chrome install paths and exposes download plus `다시 확인` flow.
- [x] 전용 프로필 자동 생성
- [x] 일반 Chrome 프로필 미변경: path tests verify app-owned profile root only.
- [x] Chrome App Mode 실행
- [x] 동적 localhost CDP 포트
- [x] 기존 전용 Chrome 재연결: `DevToolsActivePort` port and browser WebSocket path are validated against `/json/version` before reconnecting; real reconnect remains manual QA.
- [x] 전용 Chrome 정상 종료: reset closes the dedicated browser target before deleting only the app-owned profile; process behavior remains manual QA.
- [x] 브라우저 세션 초기화

### CDP and mobile emulation

- [x] target discovery: `/json/list` reuses the existing loopback App Mode page target; only when no page exists does `/json/new?about:blank` create one, followed by the browser-WebSocket `Target.createTarget` fallback.
- [x] WebSocket 연결: `URLSessionWebSocketTask` transport is wired through `CDPClient.connect(to:)` and sends CDP JSON in UTF-8 text frames.
- [x] JSON-RPC 요청·응답: command IDs are encoded, sent, received, matched, and buffered for out-of-order responses in tests.
- [x] timeout 및 재연결: CDP command timeout, cancellation cleanup, loopback WebSocket validation, and DevTools port wait timeout are implemented; full real-Chrome reconnect remains manual QA.
- [x] device metrics 적용
- [x] touch emulation 적용
- [x] mobile User-Agent 적용
- [x] User-Agent Client Hints 적용
- [x] `https://att.skala-ai.com/` 탐색
- [x] 창 위치·크기 설정: saved bounds are passed into Chrome launch and CDP `Browser.setWindowBounds`; CDP bounds readback and saved-bound relaunch selection are covered by tests.
- [x] 창 닫은 뒤 재열기: missing page-target fallback creates a new `about:blank` target before applying emulation and navigating; real Chrome closed-window behavior remains manual QA.

### Onboarding

- [x] 비공식 앱 고지
- [x] Chrome 확인: first-run onboarding includes installed/missing state and retry.
- [x] 익명 통계 선택
- [x] 로그인 시 자동 실행 선택
- [x] Google 로그인 및 시작: button is gated until Chrome is found; Google login remains user-driven only and manual QA is required for real Google login/passkey.
- [x] 온보딩 완료 상태 저장
- [x] 최초 설정 다시 보기: 설정 > 일반에서 앱 소유 온보딩 창을 일시적으로 다시 열며, 닫아도 저장된 온보딩 완료 상태와 전용 Chrome 프로필·로그인 세션은 변경하지 않음.
- [x] 온보딩 네이티브 다듬기 (DESIGN.md): 그룹 박스 섹션, SF Symbols, helper text, 접근성 라벨/힌트 추가; Chrome 게이팅·분석 동의·로그인 항목·완료 시 `openAttendance` 호출 경로 유지; 시각적 단계별 레이아웃은 수동 QA 필요.

### Analytics

- [x] 설정이 없을 때 no-op
- [x] 동의 전 이벤트 미전송
- [x] 익명 UUID 생성
- [x] install 이벤트 1회: app startup or onboarding opt-in sends once when analytics is enabled; production ingestion manual.
- [x] app_launch 이벤트: app startup or onboarding opt-in sends for the current launch when analytics is enabled; production ingestion manual.
- [x] attendance_open 이벤트
- [x] app_version 데이터
- [x] opt-out 즉시 반영
- [x] 익명 ID 재설정
- [x] Google 계정 및 출결 정보 payload 미포함
- [x] Umami v3 Compose와 운영 문서
- [x] Umami Cloud Hobby US production configuration: GitHub repository variables are configured for collector base `https://gateway.umami.is`, Website ID, and hostname. Their values are not recorded in this document.
- [x] Production Umami ingestion, limited scope: one authorized direct app-shaped `app_launch` event was accepted by `https://gateway.umami.is/api/send`; the response was HTTP 200 and included server-generated session and visit identifiers. Umami Cloud dashboard Events > Activity showed one `app_launch` at hostname `attendance-app.skalife.kr`.
- [x] Collector migration note: the app appends `/api/send` to the configured base URL. `https://cloud.umami.is/script.js` is browser tracker delivery only, and legacy API documentation may still reference `https://cloud.umami.is`; direct Cloud collection uses `https://gateway.umami.is`.
- [ ] Real app consent-driven Umami end-to-end event path: manual QA remains required because the release workflow was not run. The verified production ingestion scope is limited to the one authorized direct event above.

### Login item

- [x] 최초 온보딩에서 사용자 선택
- [x] `SMAppService.mainApp`
- [x] 설정에서 변경
- [x] 실패 오류 처리: login item, reload, bring-forward, open, and reset commands surface user-facing status text.

### Sparkle

- [x] Sparkle 2 SPM 통합
- [x] 업데이트 확인 메뉴
- [x] 자동 업데이트 확인 설정
- [x] `SUFeedURL`
- [x] EdDSA public key injection: release workflow requires `SPARKLE_PUBLIC_KEY`; local unsigned artifacts keep `SUPublicEDKey` empty until credentials are provided.
- [x] private key 저장소 미포함
- [x] appcast 생성 절차: release workflow uses Sparkle `generate_appcast --ed-key-file -`; execution remains credential/tag-gated.
- [x] EdDSA key setup documentation: `docs/release-setup.md` documents initial `generate_keys` public-key capture, `umask 077` restricted export with `generate_keys -x`, `chmod 600`, the exported one-line Base64 CI secret, `SUPublicEDKey` injection, and private-key exclusions.
- [x] 공개 appcast 저장소 배포 절차: release workflow checks out `SKALIFE/attendance-appcast` with `APPCAST_REPO_TOKEN`, copies only `appcast.xml` and release notes markdown, and commits only when changes exist; execution remains credential/tag-gated.

### Distribution

- [x] DMG 생성 스크립트
- [x] Applications 바로가기
- [x] arm64 파일명
- [x] CI workflow
- [x] release workflow: environment-gated tag workflow validates Apple, Sparkle, production Umami, and public appcast repository configuration, then builds, signs, notarizes, staples, creates ZIP/DMG, generates Sparkle appcast, creates GitHub Release, and publishes appcast files to `SKALIFE/attendance-appcast` when approved credentials are present.
- [x] SemVer tag 검증
- [x] signing secret 검증
- [x] notarization 명령: documented; not executed without credentials.
- [ ] stapling: configured in release workflow; credential-gated, not executed locally.
- [x] `codesign --verify`
- [ ] `spctl --assess`: requires Developer ID signed/notarized artifact for meaningful result.
- [ ] `xcrun stapler validate`: requires notarized artifact.
- [ ] GitHub Release artifact: configured in release workflow; not created without tag and release-environment approval.
- [x] Sparkle ZIP artifact: unsigned local ZIP created; signed appcast generation is workflow-configured and credential-gated.

### Documentation

- [x] README.md
- [x] PRIVACY.md
- [x] SECURITY.md
- [x] CONTRIBUTING.md
- [x] LICENSE
- [x] CHANGELOG.md
- [x] docs/implementation-plan.md
- [x] docs/manual-qa.md
- [x] docs/release-setup.md
- [x] infra/umami README
- [x] v1.0.0 release notes draft: `CHANGELOG.md`

## Automated test coverage

- [x] Chrome 경로 탐색
- [x] Chrome argument 생성
- [x] 전용 프로필 경로
- [x] Chrome 버전 파싱
- [x] 모바일 User-Agent
- [x] User-Agent Metadata
- [x] CDP JSON encode/decode
- [x] pending request matching: transport-backed command tests verify response ID matching, event skipping, out-of-order buffering, and cancellation cleanup.
- [x] CDP timeout: CDP command timeout, cancellation cleanup, and DevTools port wait timeout are implemented.
- [x] MobileEmulationProfile
- [x] window bounds 보정
- [x] Umami payload
- [x] analytics opt-out
- [x] install event 1회: state modeled and onboarding opt-in path tested.
- [x] 익명 ID 생성·재설정
- [x] version parsing
- [x] SemVer tag parsing: GitHub Actions validates tag format.
- [x] release config validation: GitHub Actions validates Apple, Sparkle, and production Umami config before archive signing.
- [x] reliability/UX regressions: saved launch bounds, diagnostics state preservation, onboarding replay state, concise panel status construction, and Sparkle key setup documentation.

## Manual verification required

다음 항목은 자동 테스트 성공으로 대체하지 않는다.

- [ ] Google SSO 로그인
- [ ] Google 패스키 버튼
- [ ] Touch ID 인증
- [ ] 인증 후 출결 페이지 복귀
- [ ] 앱과 Chrome 재시작 후 로그인 세션 유지
- [ ] 실제 출결 페이지 모바일 판별 통과
- [ ] Developer ID 서명
- [ ] Apple 공증
- [ ] 공증된 DMG Gatekeeper 통과
- [ ] Sparkle 실제 업데이트 설치
- [ ] 운영 Umami 수신
- [ ] Release workflow로 구성된 실제 앱의 동의 기반 Umami 이벤트 전송 및 dashboard 확인
- [ ] Public appcast repository publication through approved release workflow
- [ ] 실제 v1.0.0 Release through approved tag workflow

## Known issues

- Release workflow is configured for signed/notarized artifacts, Sparkle appcast generation, GitHub Release creation, and public appcast repository publication, but it has not been executed because credentials, tag push, and release-environment approval are required.
- Production Umami Cloud Hobby US accepted one authorized direct app-shaped event and the dashboard showed it. This does not verify the release-built app's consent-driven event path, which remains manual QA because no release workflow ran.
- `SMAppService.mainApp` 실제 등록 상태는 macOS System Settings에서 수동 확인이 필요하다.
- 실제 Chrome App Mode에서 Google passkey가 동작하는지 수동 QA가 필요하다.
- 전용 프로필 충돌 감지는 Chrome이 CDP로 프로필 잠금 상태를 노출하지 않아 기술적으로 제한된다. 충돌이 의심되는 경우 "브라우저 세션 초기화"로 복구한다.
- CDP target lifecycle 이벤트는 `Target.setDiscoverTargets` 활성화 후 수신되지만, Chrome 프로세스 비정상 종료 시 WebSocket 연결 끊김만 감지된다.

## Current blockers

- Apple Developer Program 승인 및 Developer ID credentials 없이는 실제 Developer ID 서명과 공증을 검증할 수 없다.
- Google 로그인과 패스키는 사용자 상호작용이 필요하다.
- Production Umami Cloud Hobby US configuration and one authorized direct ingestion event are verified. The release-built app's consent-driven end-to-end event path still requires manual QA because the release workflow has not run.
- GitHub tag, Release, remote push는 사용자의 명시적 승인 후 수행한다.

## Next actions

1. 사용자 승인 후 manual QA checklist 실행
2. Apple credentials 설정 후 release environment에서 signed/notarized tag workflow 실행
3. 공개 appcast 저장소 publication과 production update 설치 검증
4. Release workflow로 구성된 앱에서 동의 기반 Umami 이벤트를 전송하고 dashboard 수신을 수동 확인

## Verification log

| Date | Branch/Commit | Command | Result | Notes |
|---|---|---|---|---|
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 28 XCTest cases, 0 failures; includes CDP timeout/event/window bounds/current-bounds/cancellation, DevTools endpoint parsing, loopback WebSocket validation, target creation command, onboarding analytics opt-in, diagnostics fields, menu activation preference, release config, and status wording regressions |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build; rerun sequentially after a parallel XcodeGen project-write collision |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG created at `release/SKALA-Attendance-1.0.0-arm64.dmg` |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | Release executable smoke launch | Passed | process stayed alive for 2s; teardown via kill; log empty |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `docker compose -f infra/umami/docker-compose.yml --env-file infra/umami/.env.example config` | Passed | Compose config rendered |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `xcodebuild analyze -project SKALAAttendance.xcodeproj -scheme SKALAAttendance -configuration Debug -destination 'platform=macOS,arch=arm64'` | Passed | Static analysis succeeded |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | Workflow YAML parse | Passed | `.github/workflows/ci.yml` and `.github/workflows/release.yml` parsed with Ruby YAML |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | Sparkle docs/tooling check | Passed | Context7 confirmed `generate_appcast --ed-key-file -`; local Sparkle artifact contains `generate_appcast` and `sign_update` |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | Secret pattern scan | Passed | No private-key, GitHub token, Slack token, AWS key, or OpenAI-key patterns found; `.env.example` contains documented placeholder values only |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after CDP/Chrome stabilization fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after CDP/Chrome stabilization fixes; rerun sequentially after a parallel XcodeGen project-write collision |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after CDP/Chrome stabilization fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after CDP/Chrome stabilization fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after CDP/Chrome stabilization fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 28 XCTest cases, 0 failures after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after Oracle blocker repairs |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 30 XCTest cases, 0 failures after analytics default/onboarding gate and CDP actual bounds readback fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after final blocker fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after final blocker fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after final blocker fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after final blocker fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after final blocker fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 31 XCTest cases, 0 failures after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after onboarding analytics disclosure fix |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 33 XCTest cases, 0 failures after security hardening (Chrome bundle identity, analytics HTTPS) and documentation completeness fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after security hardening and documentation fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after security hardening and documentation fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after security hardening and documentation fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after security hardening and documentation fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 33 XCTest cases, 0 failures after CDP event dispatch, profileConflict removal, app icon wiring, and documentation completion |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build with AppIcon.icns included |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated at `release/SKALA-Attendance-1.0.0-arm64.dmg` after final fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after final fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after final fixes |

| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after final fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 33 XCTest cases, 0 failures after CDP lifecycle (connection reuse, event subscription, target destroyed), quit Chrome close, portrait orientation, bundle version display, multi-monitor bounds, backup symlink fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after lifecycle and settings fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after lifecycle and settings fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after lifecycle and settings fixes |
| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after lifecycle and settings fixes |

| 2026-07-17 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after lifecycle and settings fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 33 XCTest cases, 0 failures after multi-monitor bounds fix, Chrome status init, endpoint reachability diagnostics, target discovery enable, process terminationHandler, Umami docs fix |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 4 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 4 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 4 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 4 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 4 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 36 XCTest cases, 0 failures after install-once configuration gate, anonymous ID uniqueness, SemVer tag validation tests, multi-monitor CDP/AppKit coordinate handling |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 5 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 5 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 5 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 5 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 5 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 36 XCTest cases, 0 failures after multi-monitor CDP/AppKit coordinate transform, UpdateController startup apply, app_launch dedup, full Chrome version UA, SemVer prerelease tags, session reset process exit wait |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 6 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 6 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 6 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 6 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 6 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 37 XCTest cases, 0 failures after Umami payload id field, valid Docker image, closeDedicatedChrome exit wait, strict SemVer regex, prerelease appcast skip, MenuBarView diagnostics/reset, install-once test |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 7 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 7 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 7 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 7 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 7 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 40 XCTest cases, 0 failures after Umami v3.2.0 image pin, closeDedicatedChrome exit verification, SemVer regex test, install-once configured test, app_launch dedup test |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 8 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 8 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 8 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 8 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 8 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 40 XCTest cases, 0 failures after reconnect Chrome exit verification, appLaunchTracked dedup flag |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 9 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 9 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 9 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 9 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 9 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 40 XCTest cases, 0 failures after appLaunchTracked pre-I/O set, closeDedicatedChrome always verifies endpoint exit |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 10 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 10 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 10 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 10 fixes |

| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 10 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 40 XCTest cases, 0 failures after temp CDP Browser.close on relaunch, installEventSent pre-I/O, analytics non-blocking Task, 문제 보고 action |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after round 11 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/release-local.sh --unsigned` | Passed | unsigned ZIP and DMG recreated after round 11 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Release/SKALAAttendance.app` | Passed | local ad-hoc signed app after round 11 fixes |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `git diff --check` | Passed | No whitespace errors after round 11 fixes |
| 2026-07-20 | feat/initial-implementation / working tree | Workflow YAML parse | Passed | `.github/workflows/release.yml` parses with Ruby YAML after switching appcast publication from Pages to `SKALIFE/attendance-appcast` |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 42 XCTest cases, 0 failures; includes URLSession WebSocket data/string conversion and pending-receive closure tests without Chrome |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after replacing the raw CDP WebSocket transport |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `SKALA_RUN_CHROME_INTEGRATION_TEST=1 scripts/test.sh` | Passed | 44 XCTest cases, 0 failures; real Google Chrome App Mode opened the attendance URL through `ChromeSessionController` using a temporary dedicated profile, then exited and cleaned up |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 44 XCTest cases, 1 opt-in integration test skipped, 0 failures |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after CDP text-frame fix |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after CDP text-frame fix |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `SKALA_RUN_CHROME_INTEGRATION_TEST=1 scripts/test.sh` | Passed | 44 XCTest cases, 0 failures; temporary-profile App Mode reused its existing page target before navigation |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 44 XCTest cases, 1 opt-in integration test skipped, 0 failures |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after App Mode target-first discovery change |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 52 XCTest cases, 1 opt-in integration test skipped, 0 failures after native SwiftUI shell redesign (window-style MenuBarExtra, SKALAAttendance/Design tokens + primitives, grouped onboarding/settings, PanelStatus tests) |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after native shell redesign |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `codesign --verify --deep --strict build/Build/Products/Debug/SKALAAttendance.app` | Passed | ad-hoc signed Debug bundle after native shell redesign |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `lipo -archs .../SKALAAttendance` | Passed | arm64 only, matches deployment target |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 52 XCTest cases, 1 opt-in integration test skipped, 0 failures after menu-panel browser-reset confirmation gating (PRODUCT_SPEC §8) |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Debug` | Passed | arm64 Debug app build after menu-panel reset confirmation fix |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 56 XCTest cases, 1 opt-in integration test skipped, 0 failures after saved-bound launch, diagnostics state, onboarding replay, concise panel, and Sparkle setup regressions |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build after the reliability/UX follow-up |
| 2026-07-20 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 56 XCTest cases, 1 opt-in integration test skipped, 0 failures after transient onboarding replay and Sparkle secure-export documentation fixes |
| 2026-07-22 | feat/initial-implementation / 2b20507 + working tree | `scripts/test.sh` | Passed | 57 XCTest total, 56 passed, 1 opt-in Chrome integration skipped, 0 failures |
| 2026-07-22 | feat/initial-implementation / 2b20507 + working tree | `scripts/build.sh Release` | Passed | arm64 Release app build |
| 2026-07-22 | feat/initial-implementation / 2b20507 + working tree | Direct authorized app-shaped Umami event | Passed | POST `https://gateway.umami.is/api/send` returned HTTP 200 with server-generated session and visit identifiers; identifiers are intentionally not recorded |
| 2026-07-22 | feat/initial-implementation / 2b20507 + working tree | Umami Cloud dashboard check | Passed | Events > Activity listed one `app_launch` at hostname `attendance-app.skalife.kr`; this verifies only the one authorized direct event |

## Git status

- Current branch: `feat/initial-implementation`
- Created branches: 없음
- Created commits: 없음
- Uncommitted changes: implementation files, docs, scripts, workflows, infra examples, and this status update
- Remote push: 수행하지 않음
- Pull Request: 생성하지 않음
- Tag: 생성하지 않음
- Release: 생성하지 않음
