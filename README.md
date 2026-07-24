# SKALA Attendance

SKALA Attendance는 macOS 메뉴바에서 SKALA 출결 페이지(`https://att.skala-ai.com/`)를 모바일 화면으로 여는 오픈소스 편의 도구입니다.

## 비공식 앱 고지

SKALA Attendance는 SKALA 또는 SK AX가 제공하는 공식 애플리케이션이 아닌 독립적인 오픈소스 편의 도구입니다. 이 앱은 출결을 자동 처리하지 않습니다. 공식 웹페이지를 모바일 환경으로 열어주며 최종 입실·퇴실 동작은 사용자가 직접 수행합니다.

## 작동 방식

1. 메뉴바 아이콘 클릭
2. "출결 열기" 버튼
3. 작은 창에서 모바일 출결 페이지 표시
4. 사용자가 페이지에서 직접 로그인 및 출결 처리

앱은 WKWebView를 사용해 출결 페이지를 표시합니다. Chrome, CDP, 원격 디버깅을 사용하지 않습니다.

## 기술 스택

- Swift / SwiftUI
- macOS MenuBarExtra + NSWindow
- WKWebView (mobile content mode + Android Chrome UA)
- 영속 WKWebsiteDataStore (로그인 상태 유지)

## 요구사항

- macOS 14.0 이상
- Apple Silicon arm64

## 빌드

```bash
xcodegen generate
xcodebuild build -project SKALAAttendance.xcodeproj \
  -scheme SKALAAttendance \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64'
```

## 라이선스

MIT License. [LICENSE](LICENSE) 파일을 참고하세요.
