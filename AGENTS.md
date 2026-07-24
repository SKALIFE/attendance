# AGENTS.md — SKALA Attendance

## Product boundary

이 앱은 공식 출결 페이지(`https://att.skala-ai.com/`)를 모바일 환경으로 여는 편의 도구다.

**하지 않는 것:**
- 출결 API 직접 호출
- 입실·퇴실 자동 실행
- 페이지 버튼 자동 클릭
- 로그인 화면 조작
- 쿠키·토큰 추출 또는 복사

**하는 것:**
- 메뉴바에서 출결 페이지 열기
- WKWebView로 모바일 환경 제공
- 창 앞으로 가져오기 / 새로고침

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
