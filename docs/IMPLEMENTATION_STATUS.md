# Implementation Status

이 문서는 루프와 개발자가 실제 구현 상태를 추적하기 위한 체크리스트다.

## Current state

- Status: Not started
- Current phase: Phase 0
- Current branch: 확인 필요
- Last verified commit: 없음
- Last updated: 작성 필요

## Phases

- [ ] Phase 0: 환경 및 저장소 확인
- [ ] Phase 1: 프로젝트 구조와 구현 계획
- [ ] Phase 2: Chrome/CDP 프로토타입
- [ ] Phase 3: Swift 메뉴바 앱
- [ ] Phase 4: 온보딩과 설정
- [ ] Phase 5: Umami 통계
- [ ] Phase 6: Sparkle 업데이트
- [ ] Phase 7: CI 및 릴리스 자동화
- [ ] Phase 8: 문서와 테스트
- [ ] Phase 9: 로컬 최종 검증과 repository review

## Functional verification

### Build and project

- [ ] XcodeGen 또는 선택한 프로젝트 생성 방식 동작
- [ ] arm64 Debug build
- [ ] arm64 Release build
- [ ] unit tests
- [ ] 인증서 없는 로컬 Debug build
- [ ] macOS 26.0 deployment target

### Menu bar app

- [ ] 메뉴바 아이콘 표시
- [ ] Dock에 상시 아이콘이 남지 않음
- [ ] 출결 페이지 열기
- [ ] 창 앞으로 가져오기
- [ ] 페이지 새로고침
- [ ] 앱 종료
- [ ] 설정 화면

### Chrome

- [ ] Chrome 설치 경로 탐색
- [ ] Chrome 미설치 안내
- [ ] 전용 프로필 자동 생성
- [ ] 일반 Chrome 프로필 미변경
- [ ] Chrome App Mode 실행
- [ ] 동적 localhost CDP 포트
- [ ] 기존 전용 Chrome 재연결
- [ ] 전용 Chrome 정상 종료
- [ ] 브라우저 세션 초기화

### CDP and mobile emulation

- [ ] target discovery
- [ ] WebSocket 연결
- [ ] JSON-RPC 요청·응답
- [ ] timeout 및 재연결
- [ ] device metrics 적용
- [ ] touch emulation 적용
- [ ] mobile User-Agent 적용
- [ ] User-Agent Client Hints 적용
- [ ] `https://att.skala-ai.com/` 탐색
- [ ] 창 위치·크기 설정
- [ ] 창 닫은 뒤 재열기

### Onboarding

- [ ] 비공식 앱 고지
- [ ] Chrome 확인
- [ ] 익명 통계 선택
- [ ] 로그인 시 자동 실행 선택
- [ ] Google 로그인 및 시작
- [ ] 온보딩 완료 상태 저장

### Analytics

- [ ] 설정이 없을 때 no-op
- [ ] 동의 전 이벤트 미전송
- [ ] 익명 UUID 생성
- [ ] install 이벤트 1회
- [ ] app_launch 이벤트
- [ ] attendance_open 이벤트
- [ ] app_version 데이터
- [ ] opt-out 즉시 반영
- [ ] 익명 ID 재설정
- [ ] Google 계정 및 출결 정보 payload 미포함
- [ ] Umami v3 Compose와 운영 문서

### Login item

- [ ] 최초 온보딩에서 사용자 선택
- [ ] `SMAppService.mainApp`
- [ ] 설정에서 변경
- [ ] 실패 오류 처리

### Sparkle

- [ ] Sparkle 2 SPM 통합
- [ ] 업데이트 확인 메뉴
- [ ] 자동 업데이트 확인 설정
- [ ] `SUFeedURL`
- [ ] EdDSA public key
- [ ] private key 저장소 미포함
- [ ] appcast 생성 절차
- [ ] GitHub Pages 배포 절차

### Distribution

- [ ] DMG 생성 스크립트
- [ ] Applications 바로가기
- [ ] arm64 파일명
- [ ] CI workflow
- [ ] release workflow
- [ ] SemVer tag 검증
- [ ] signing secret 검증
- [ ] notarization 명령
- [ ] stapling
- [ ] `codesign --verify`
- [ ] `spctl --assess`
- [ ] `xcrun stapler validate`
- [ ] GitHub Release artifact
- [ ] Sparkle ZIP artifact

### Documentation

- [ ] README.md
- [ ] PRIVACY.md
- [ ] SECURITY.md
- [ ] CONTRIBUTING.md
- [ ] LICENSE
- [ ] CHANGELOG.md
- [ ] docs/implementation-plan.md
- [ ] docs/manual-qa.md
- [ ] docs/release-setup.md
- [ ] infra/umami README
- [ ] v1.0.0 release notes draft

## Automated test coverage

- [ ] Chrome 경로 탐색
- [ ] Chrome argument 생성
- [ ] 전용 프로필 경로
- [ ] Chrome 버전 파싱
- [ ] 모바일 User-Agent
- [ ] User-Agent Metadata
- [ ] CDP JSON encode/decode
- [ ] pending request matching
- [ ] CDP timeout
- [ ] MobileEmulationProfile
- [ ] window bounds 보정
- [ ] Umami payload
- [ ] analytics opt-out
- [ ] install event 1회
- [ ] 익명 ID 생성·재설정
- [ ] version parsing
- [ ] SemVer tag parsing

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
- [ ] GitHub Pages appcast
- [ ] 실제 v1.0.0 Release

## Known issues

- 없음. 구현 중 발견 시 여기에 기록한다.

## Current blockers

- Apple Developer Program 승인이 완료되기 전에는 실제 Developer ID 서명과 공증을 검증할 수 없다.
- Google 로그인과 패스키는 사용자 상호작용이 필요하다.
- 운영 Umami 배포는 사용자의 명시적 승인 후 수행한다.
- GitHub tag, Release, remote push는 사용자의 명시적 승인 후 수행한다.

## Next actions

1. 저장소와 개발 환경 확인
2. `docs/implementation-plan.md` 작성
3. Chrome/CDP 최소 프로토타입 구현
4. arm64 build와 수동 모바일 페이지 검증
5. Swift 메뉴바 앱으로 통합

## Verification log

| Date | Branch/Commit | Command | Result | Notes |
|---|---|---|---|---|
| - | - | - | Not run | 구현 시작 후 갱신 |

## Git status

- Current branch: 확인 필요
- Created branches: 없음
- Created commits: 없음
- Uncommitted changes: 확인 필요
- Remote push: 수행하지 않음
- Pull Request: 생성하지 않음
- Tag: 생성하지 않음
- Release: 생성하지 않음
