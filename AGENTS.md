# AGENTS.md — SKALA Attendance

## Product boundary

이 앱은 공식 출결 페이지(`https://att.skala-ai.com/`)를 모바일 환경으로 여는 편의 도구다.

**하지 않는 것:**
- 출결 API 직접 호출
- 입실·퇴실 자동 실행
- 페이지 버튼·인증 제출·Google 인증 자동 실행
- 허용된 사용자 주도 입력 외 로그인·인증 화면 조작
- 쿠키·토큰 추출 또는 복사

**하는 것:**
- 메뉴바에서 출결 페이지 열기
- WKWebView로 모바일 환경 제공
- 창 앞으로 가져오기 / 새로고침
- 정확히 `https://auth.skala-ai.com/`에서 사용자가 직접 요청한 경우에만
  기기에 저장한 이름·지역·반을 입력하되 제출하지 않음

인증 정보 입력 예외는 이름·지역·반에만 적용한다. 프로필은 기기에만
저장하고 telemetry에서 제외한다. 예상한 origin, 필드 또는 선택 항목이
다르면 아무것도 제출하거나 대신 클릭하지 말고 입력을 중단한다.

## Architecture

```
SwiftUI MenuBarExtra (.window)
  └─ MenuBarPanel (buttons + status)
       └─ AttendanceWindowController (@MainActor ObservableObject)
            ├─ NSWindow (430×900, closable, resizable)
            └─ WKWebView (mobile UA + persistent data store)
```

## Tech constraints

- macOS 14.0+
- arm64 only
- Hardened Runtime on, App Sandbox off
- Swift 6 strict concurrency
- LSUIElement = true (메뉴바 전용)

## Release operations

- A release requires an explicit maintainer instruction. A source, resource,
  documentation, test, CI, release-note, or `main` change never authorizes a
  release by itself.
- Follow `docs/runbooks/release.md` for every release. Do not change release
  metadata or create or push a release tag outside that procedure.
- Record completed user-relevant app changes in
  `docs/releases/unreleased.md`; editing that file is not release
  authorization.
- The initial release instruction authorizes work only through a verified
  GitHub Release. After reporting the required artifact and unchanged-live-feed
  evidence, obtain a second explicit maintainer approval before approving the
  protected `appcast-publish` Environment.
