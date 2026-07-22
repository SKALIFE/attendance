# SKALA Attendance Product Specification

이 문서는 SKALA Attendance 프로젝트의 구현 기준이자 최종 요구사항이다.

## 문서 사용 원칙

- 구현 전 이 문서를 처음부터 끝까지 읽는다.
- 이 문서를 제품 요구사항의 source of truth로 취급한다.
- 불명확한 부분은 기존 코드와 공식 문서를 조사해 합리적으로 결정한다.
- 구현 편의를 위해 요구사항을 임의로 삭제하거나 축소하지 않는다.
- 실제로 검증하지 않은 기능을 완료되었다고 표시하지 않는다.
- 사용자의 명시적 지시 없이 remote push, Pull Request 생성, tag 생성, GitHub Release, 운영 서버 배포를 수행하지 않는다.
- 계획만 작성하고 멈추지 말고, 로컬에서 가능한 구현·빌드·테스트·문서화까지 완료한다.

---

## 1. 프로젝트 정보

- 앱 이름: `SKALA Attendance`
- 제품명: `SKALA Attendance`
- Bundle Identifier: `kr.skalife.attendance`
- GitHub Organization: `skalife`
- 저장소: `https://github.com/skalife/attendance`
- 라이선스: MIT
- 지원 OS: macOS 26.0 이상
- 지원 CPU: Apple Silicon arm64 전용
- 지원 브라우저: Google Chrome Stable만 지원
- 출결 페이지: `https://att.skala-ai.com/`
- 앱 형태: Dock에 상시 노출되지 않는 macOS 메뉴바 앱
- 주 언어: Swift
- UI: SwiftUI 중심, 필요한 경우 AppKit 사용
- 업데이트: Sparkle 2
- 익명 사용 통계: Umami Cloud Hobby US
- 배포:
  - GitHub Releases
  - 서명·공증된 DMG
  - Applications 폴더로 드래그 설치
  - Mac App Store에는 배포하지 않음

이 앱은 SKALA 또는 SK AX가 제공하는 공식 앱이 아니다. 공식 서비스와 제휴·승인된 것처럼 표현하지 않는다. SKALA나 SK의 공식 로고 또는 저작권이 있는 브랜드 자산을 무단 사용하지 않는다.

---

## 2. 제품 목표

사용자는 다음 흐름으로 사용할 수 있어야 한다.

```text
DMG 다운로드
→ Applications 폴더로 드래그
→ 앱 실행
→ 최초 설정
→ 메뉴바 아이콘 클릭
→ 휴대폰 크기의 출결 페이지 표시
→ Google 패스키로 최초 1회 로그인
→ 이후 메뉴바에서 클릭 한 번으로 출결 페이지 사용
```

사용자에게 다음 작업을 요구하면 안 된다.

- 터미널 명령 실행
- Xcode 설치
- Chrome 개발자 모드 활성화
- Chrome 확장 프로그램 설치
- User-Agent 수동 변경
- CDP 주소나 포트 입력
- Chrome 프로필 수동 생성
- 기존 Chrome 쿠키 복사
- 접근성 권한 허용
- Automation 권한 허용
- Gatekeeper 우회 명령 실행

앱은 사용자가 설치한 공식 Google Chrome을 사용하되, 일반 Chrome 프로필과 완전히 분리된 전용 프로필을 자동으로 생성하고 관리한다.

---

## 3. 제품 범위와 금지 사항

앱의 역할은 공식 출결 페이지를 편리하게 여는 것이다.

앱은 다음을 수행한다.

- 메뉴바에서 출결 페이지 열기
- 공식 Chrome을 전용 프로필로 실행
- Chrome App Mode 사용
- CDP로 모바일 브라우저 환경 적용
- 창 앞으로 가져오기
- 새로고침
- 전용 브라우저 세션 초기화
- 로그인 시 자동 실행 선택
- Sparkle 업데이트
- 사용자가 동의한 익명 통계 전송

앱은 다음을 수행하지 않는다.

- 출결 API 직접 호출
- 입실·퇴실 자동 실행
- 페이지 버튼 자동 클릭
- Google 로그인 화면 조작
- Chrome 쿠키 추출 또는 복사
- 인증 토큰 저장
- 출결 성공 여부 수집
- 일반 Chrome 프로필 수정
- 원격 코드 실행
- 서버에서 내려받은 임의 스크립트 실행

최종 입실·퇴실 동작은 사용자가 공식 페이지에서 직접 수행한다.

---

## 4. 핵심 아키텍처

```text
Swift 메뉴바 앱
    │
    ├─ Chrome 설치 확인
    ├─ 전용 Chrome 프로필 관리
    ├─ 전용 Chrome 프로세스 실행
    ├─ localhost CDP 연결
    ├─ 모바일 브라우저 환경 적용
    ├─ 출결 페이지 탐색
    ├─ 창 표시·복원·새로고침
    ├─ Sparkle 업데이트
    ├─ 로그인 시 실행
    └─ Umami 익명 통계
           │
           ▼
Google Chrome App Mode
    ├─ 실제 Chrome 인증 환경
    ├─ Google SSO
    ├─ Google 패스키 및 Touch ID
    ├─ 로그인 쿠키 유지
    └─ 출결 사이트에는 모바일 환경 제공
```

다음은 사용하지 않는다.

- WKWebView
- Electron
- 앱에 번들한 Chromium
- Chrome 확장 프로그램

---

## 5. 프로젝트 구성

재현 가능한 Xcode 프로젝트 구성을 사용한다.

권장:

- XcodeGen
- `project.yml`을 프로젝트 구성의 source of truth로 사용
- Sparkle은 Swift Package Manager로 추가
- 특정 개발자의 절대 경로를 프로젝트 파일에 넣지 않음

최소 구조:

```text
attendance/
├── AGENTS.md
├── SKALAAttendance/
│   ├── App/
│   ├── MenuBar/
│   ├── Onboarding/
│   ├── Settings/
│   ├── Chrome/
│   ├── CDP/
│   ├── Analytics/
│   ├── Updates/
│   ├── LoginItem/
│   ├── Models/
│   ├── Utilities/
│   └── Resources/
├── SKALAAttendanceTests/
├── Config/
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── Secrets.xcconfig.example
├── scripts/
│   ├── bootstrap.sh
│   ├── build.sh
│   ├── test.sh
│   ├── create-dmg.sh
│   └── release-local.sh
├── infra/
│   └── umami/
├── docs/
│   ├── PRODUCT_SPEC.md
│   ├── IMPLEMENTATION_STATUS.md
│   ├── implementation-plan.md
│   ├── manual-qa.md
│   └── release-setup.md
├── .github/
│   └── workflows/
├── project.yml
├── README.md
├── PRIVACY.md
├── SECURITY.md
├── CONTRIBUTING.md
├── LICENSE
└── CHANGELOG.md
```

기본 빌드 설정:

- `MACOSX_DEPLOYMENT_TARGET = 26.0`
- `ARCHS = arm64`
- Hardened Runtime 활성화
- App Sandbox 비활성화
- `LSUIElement = true`
- Swift Concurrency 사용
- Release 빌드에서 민감한 경로와 디버그 정보를 불필요하게 출력하지 않음

---

## 6. 메뉴바 UI

`MenuBarExtra`를 중심으로 구현한다.

예시:

```text
SKALA Attendance
────────────────────
출결 페이지 열기
창 앞으로 가져오기
페이지 새로고침
────────────────────
상태: 준비됨
Chrome: 실행 중
모바일 모드: 적용됨
────────────────────
업데이트 확인…
설정…
────────────────────
종료
```

상태 예시:

- Chrome 미설치
- Chrome 시작 중
- CDP 연결 중
- 출결 페이지 여는 중
- 준비됨
- 연결 오류
- 전용 프로필 초기화 필요

아이콘 원칙:

- 메뉴바는 SF Symbol 기반 단색 아이콘 사용 가능
- 앱 아이콘은 체크 표시, 출입구, 작은 모바일 창 등의 추상적 조합
- SK 또는 SKALA 공식 로고를 복제하지 않음
- 아이콘 세트 생성 절차 또는 스크립트를 저장소에 포함

---

## 7. 최초 실행 온보딩

최초 실행 시 네이티브 온보딩 창을 표시한다.

### 7.1 앱 설명

표시 내용:

- 비공식 오픈소스 편의 도구
- 공식 출결 페이지를 모바일 브라우저 환경으로 열어줌
- 출결을 자동 수행하지 않음
- Google 계정 정보와 출결 내용을 수집하지 않음
- 설치된 Google Chrome을 사용함

### 7.2 Chrome 확인

우선 확인 경로:

```text
/Applications/Google Chrome.app
~/Applications/Google Chrome.app
```

Chrome을 찾지 못하면:

- 오류로 종료하지 않음
- Chrome이 필요하다는 설명
- 공식 Chrome 다운로드 페이지 열기
- `다시 확인` 버튼
- 설치 후 온보딩 계속 진행

### 7.3 익명 통계 선택

- 기본값: 활성화
- 사용자가 설명을 확인한 뒤 진행
- 설정에서 언제든 비활성화 가능
- 비활성화 시 어떤 이벤트도 전송하지 않음

표시 문구:

```text
익명 사용 통계 보내기

앱 개선을 위해 다음 정보만 전송합니다.
• 익명 설치 식별자
• 앱 실행
• 출결 페이지 열기
• 앱 버전과 macOS 버전

Google 계정, 이름, 이메일, 출결 기록,
방문한 페이지 내용과 Chrome 데이터는 수집하지 않습니다.
설정에서 언제든 끌 수 있습니다.
```

### 7.4 로그인 시 자동 실행

- 최초 설정에서 사용자가 선택
- 기본값: 비활성화
- `SMAppService.mainApp` 사용
- 별도 Helper 앱 또는 오래된 LaunchAgent 방식은 사용하지 않음

### 7.5 Google 로그인 및 시작

버튼을 누르면:

1. 전용 Chrome 프로필 준비
2. Chrome App Mode 실행
3. CDP 연결
4. 모바일 환경 적용
5. 출결 URL 탐색
6. 사용자가 Google 로그인을 직접 수행

온보딩 완료 여부를 저장하고 다음 실행부터 반복하지 않는다.

---

## 8. Chrome 전용 프로필

일반 Chrome 프로필을 절대 사용하거나 수정하지 않는다.

논리적 경로:

```text
~/Library/Application Support/kr.skalife.attendance/
├── ChromeProfile/
├── State/
└── Logs/
```

요구사항:

- 기본 Chrome 프로필의 쿠키·비밀번호·Keychain 자료를 읽지 않음
- 일반 Chrome 프로필을 복사하지 않음
- 일반 Chrome 프로세스를 종료하지 않음
- 전용 프로필로 실행한 Chrome만 관리
- 프로필 중복 사용 감지
- 앱 재실행 시 기존 전용 Chrome에 재연결
- 재연결 불가 시 안전하게 새 프로세스 실행

`브라우저 세션 초기화`:

1. 사용자 확인
2. 전용 Chrome만 정상 종료
3. `ChromeProfile`만 삭제
4. 일반 Chrome 데이터에는 접근하지 않음
5. 다음 실행에서 새 프로필 생성
6. 다시 로그인해야 함을 안내

---

## 9. Chrome 실행

Chrome 바이너리 기본 경로:

```text
/Applications/Google Chrome.app/Contents/MacOS/Google Chrome
```

기본 인자 예시:

```text
--user-data-dir=<전용 프로필 절대경로>
--remote-debugging-address=127.0.0.1
--remote-debugging-port=<동적 로컬 포트>
--app=about:blank
--window-size=430,900
--no-first-run
--no-default-browser-check
```

중요 요구사항:

- 출결 URL을 `--app` 인자에 직접 넣지 않는다.
- `about:blank`로 시작한다.
- CDP 연결 및 모바일 에뮬레이션 후 `Page.navigate`로 출결 URL을 연다.
- 디버깅 서버는 반드시 `127.0.0.1`에만 바인딩한다.
- 고정 포트 `9222`를 전제로 하지 않는다.
- 가능한 경우 동적 포트와 `DevToolsActivePort`를 사용한다.
- 포트 경쟁 조건, 시작 타임아웃, 재시도, 프로세스 종료 감지를 처리한다.
- Chrome 버전을 읽어 모바일 User-Agent의 Chrome 버전과 가능한 한 일치시킨다.
- 명령행 전체나 민감한 절대경로를 일반 로그에 남기지 않는다.

---

## 10. CDP 클라이언트

범위가 작다면 외부 SDK 없이 구현한다.

- HTTP target discovery: `URLSession`
- WebSocket: `URLSessionWebSocketTask`
- JSON-RPC request/response
- 증가하는 request ID
- pending continuation 관리
- event dispatch
- 연결 종료, 타임아웃, 재연결, 취소

권장 타입:

```text
CDPClient
CDPConnection
CDPCommand
CDPResponse
CDPEvent
CDPTarget
ChromeSessionController
MobileEmulationProfile
```

동시성:

- 연결과 request map은 `actor`
- UI 상태는 `@MainActor`
- Chrome 수명주기는 별도 controller
- 로깅은 `os.Logger`
- 오류 타입을 명시적으로 정의

필수 CDP 기능:

- target 목록 조회
- target 생성 및 선택
- target lifecycle 감지
- `Page.enable`
- `Page.navigate`
- `Page.reload`
- `Page.bringToFront`
- `Browser.getWindowForTarget`
- `Browser.setWindowBounds`
- `Emulation.setDeviceMetricsOverride`
- `Emulation.setTouchEmulationEnabled`
- `Emulation.setUserAgentOverride`
- 필요 시 `Target.setDiscoverTargets`
- 정상 종료 시 `Browser.close`

창이 닫힌 경우 앱은 메뉴바에 계속 남고 다음 `출결 페이지 열기`에서 target 또는 Chrome을 재생성한다.

---

## 11. 모바일 에뮬레이션

Android Chrome 기반으로 구현한다. iPhone Safari로 위장하지 않는다.

기본 논리값:

```text
device name: Pixel 9 compatible profile
platform: Android
platform version: 15
mobile: true
touch: true
max touch points: 5
viewport width: 430
viewport height: 약 900
device scale factor: 3
orientation: portrait
```

다음을 일관되게 맞춘다.

- HTTP User-Agent
- `navigator.userAgent`
- User-Agent Client Hints
- `navigator.userAgentData.mobile`
- platform
- platformVersion
- model
- viewport
- screen dimensions
- device scale factor
- touch support

`userAgentMetadata`를 함께 지정한다.

Google 로그인 리디렉션에서도 같은 target의 Android Chrome 환경을 유지한다. 실제 Chrome이 인증을 담당하므로 패스키 동작 여부는 수동 QA 대상으로 둔다.

App Mode에서 패스키가 실패할 때만 다음 폴백을 검토한다.

```text
같은 전용 프로필의 일반 Chrome 창에서 로그인
→ 로그인 완료
→ 일반 창 종료
→ App Mode로 재실행
→ 같은 전용 프로필 세션 재사용
```

쿠키 추출 또는 복사는 금지한다.

---

## 12. 창 제어

macOS Accessibility API와 AppleScript에 의존하지 않는다.

CDP로 처리:

- `Page.bringToFront`
- `Browser.getWindowForTarget`
- `Browser.setWindowBounds`
- 최소화 상태 복원
- 화면 중앙 또는 적절한 위치에 배치
- 화면 밖 좌표 보정
- 다중 모니터 변경 대응

기본 크기:

```text
width: 430~480
height: 820~920
```

사용자가 이동·크기 변경한 값을 저장하고 다음 실행에서 복원한다. 잘못된 좌표는 화면 범위 안으로 보정한다.

---

## 13. 설정 화면

### 일반

- 로그인 시 자동 실행
- 메뉴바 아이콘 클릭 시 바로 출결창 열기
- 창 위치 초기화
- 출결 페이지 새로고침

### 개인정보

- 익명 사용 통계 토글
- 수집 항목 설명
- 익명 설치 식별자 재설정
- 개인정보 문서 열기

통계를 끄면 즉시 전송을 중단한다. 비활성화 이벤트도 보내지 않는다.

### 브라우저

- Chrome 설치 상태
- Chrome 버전
- 전용 프로필 위치를 Finder에서 보기
- 브라우저 세션 초기화
- 연결 진단

### 업데이트

- 자동 업데이트 확인
- 지금 업데이트 확인
- 현재 버전과 빌드 번호

### 정보

- GitHub 저장소
- 오픈소스 라이선스
- 비공식 앱 고지
- 앱 버전

---

## 14. Umami v3 익명 통계

Umami SDK 대신 `URLSession`으로 전송 API를 호출한다.

현재 production 계획:

- Umami Cloud Hobby US
- collector base URL: `https://gateway.umami.is`
- 실제 주소와 Website ID는 xcconfig 또는 build setting으로 주입
- 개발 환경에서 값이 없어도 앱 정상 작동
- 설정이 없으면 no-op
- Release workflow에서는 production 값 누락 검증

설정 키:

```text
UMAMI_BASE_URL
UMAMI_WEBSITE_ID
UMAMI_HOSTNAME
```

논리 hostname:

```text
attendance-app.skalife.kr
```

Endpoint:

```text
POST <UMAMI_BASE_URL>/api/send
Content-Type: application/json
User-Agent: SKALA-Attendance/<version> (macOS; arm64)
```

Umami Cloud dashboard의 `https://cloud.umami.is/script.js`는 브라우저 추적기 전달용 URL이다. 일부 문서에 이전 Cloud 수집 URL인 `https://cloud.umami.is`가 남아 있을 수 있으나, 현재 Cloud changelog가 식별하는 직접 수집 주소는 `https://gateway.umami.is`다.

### 익명 설치 ID

- 최초 통계 동의 후 임의 UUID 생성
- 이메일, Google ID, 이름, 학번 등에서 파생하지 않음
- UUID 문자열은 50자 미만
- 앱 전용 상태 저장소에 저장
- Umami Distinct ID로 사용
- 설정에서 재설정 가능
- Google 계정이나 Chrome 프로필과 연결하지 않음

### 이벤트

`install`

- 최초 통계 활성화 후 한 번만
- URL: `/app/install`

`app_launch`

- 통계 활성화 상태에서 앱 시작 시 한 번
- URL: `/app/launch`

`attendance_open`

- 출결 창 표시 또는 탐색이 성공했을 때
- URL: `/attendance/open`

공통 데이터:

```json
{
  "app_version": "1.0.0",
  "build_number": "1",
  "macos_version": "26.x",
  "architecture": "arm64"
}
```

수집 금지:

- Google 이메일
- Google 계정 식별자
- 사용자 이름
- 출결 성공 여부
- 입실·퇴실 시각
- 출결 응답 내용
- 페이지 HTML
- 쿠키
- 인증 토큰
- Chrome 프로필 데이터
- URL query string
- 기기 이름
- 시리얼 번호
- MAC 주소
- 하드웨어 UUID

전송 정책:

- 짧은 timeout
- best-effort
- 앱 동작을 막지 않음
- 무한 재시도 금지
- 민감한 payload 로그 금지

필요 지표:

- 누적 익명 설치 수
- 일간 활성 기기
- 주간 활성 기기
- 앱 버전별 활성 사용자
- 출결 페이지 열기 횟수

---

## 15. 선택적 Umami v3 셀프 호스팅 참고 자료

현재 production은 Umami Cloud Hobby US를 사용한다. `infra/umami/`에는 자체 호스팅이 필요한 경우를 위한 Raspberry Pi arm64 서버 예제를 선택적으로 준비한다.

원격 서버를 임의 변경하거나 배포하지 않는다. Compose와 문서까지만 작성하고 실제 적용은 사용자의 명시적 요청 후 수행한다.

요구사항:

- Umami v3
- PostgreSQL
- Docker Compose
- Raspberry Pi OS arm64 호환
- `latest` 대신 확인된 구체 버전 고정
- Umami와 PostgreSQL healthcheck
- PostgreSQL 외부 포트 미공개
- Umami는 기본적으로 `127.0.0.1` 바인딩
- Cloudflare Tunnel을 통한 `analytics.skalife.kr` 노출 예제
- 영속 볼륨
- `.env.example`
- secret gitignore
- 백업·복원·업데이트 절차
- 초기 관리자 비밀번호 변경
- Website 생성 및 Website ID 확인
- 앱 GitHub Actions 변수 설정

Website ID는 바이너리에 포함될 수 있으므로 비밀값으로 간주하지 않는다. 필요하면 reverse proxy 또는 Cloudflare에서 rate limit을 적용한다.

---

## 16. Sparkle 업데이트

Sparkle 2를 Swift Package Manager로 통합한다.

요구사항:

- `업데이트 확인…` 메뉴
- 자동 업데이트 확인 설정
- 표준 Sparkle UI
- 업데이트 설치는 사용자 승인 기반
- EdDSA 서명
- Apple Developer ID 코드 서명과 함께 검증
- private EdDSA key 저장소 커밋 금지
- public key만 앱에 포함
- 서명되지 않은 업데이트 금지

Appcast 기본 주소:

```text
https://raw.githubusercontent.com/SKALIFE/attendance-appcast/main/appcast.xml
```

Release workflow:

1. 서명·공증된 앱 생성
2. Sparkle용 ZIP 생성
3. EdDSA 서명
4. appcast 생성 또는 갱신
5. GitHub Release asset URL 반영
6. 공개 `SKALIFE/attendance-appcast` 저장소의 `main` 브랜치에 appcast와 release notes 게시

---

## 17. Apple 서명 및 공증

Apple Developer Program 결제는 완료했으나 승인 대기 중일 수 있다.

따라서:

- 로컬 Debug 빌드는 인증서 없이 동작
- PR CI는 unsigned build와 test 수행
- Release workflow는 자격증명 설정 후 동작
- 자격증명 누락으로 개발 빌드가 실패하지 않음
- Release 시작 시 필요한 secret을 명확히 검증

예시 GitHub Secrets:

```text
APPLE_TEAM_ID
DEVELOPER_ID_APPLICATION_P12_BASE64
DEVELOPER_ID_APPLICATION_P12_PASSWORD
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_PRIVATE_KEY_BASE64
SPARKLE_EDDSA_PRIVATE_KEY
SPARKLE_PUBLIC_KEY
```

Umami 설정은 GitHub Secrets가 아니라 GitHub repository variables로 관리한다.

```text
UMAMI_BASE_URL=https://gateway.umami.is
UMAMI_WEBSITE_ID=<Umami Cloud Website ID>
UMAMI_HOSTNAME
```

공증은 `notarytool`과 가능하면 App Store Connect API Key 방식을 사용한다.

Release 절차:

1. 임시 keychain 생성
2. Developer ID Application 인증서 import
3. arm64 Release archive
4. Hardened Runtime 코드 서명
5. 서명 검증
6. 공증 제출
7. 실패 로그 출력
8. 앱 staple
9. Sparkle ZIP 생성
10. DMG 생성
11. DMG 공증
12. DMG staple
13. Gatekeeper 검증
14. GitHub Release 업로드

검증:

```text
codesign --verify
spctl --assess
xcrun stapler validate
```

---

## 18. DMG

요구사항:

- 앱 아이콘
- Applications 폴더 바로가기
- 드래그 설치가 명확한 레이아웃
- arm64 표시
- 버전 포함 파일명

예시:

```text
SKALA-Attendance-1.0.0-arm64.dmg
SKALA-Attendance-1.0.0-arm64.zip
```

유지보수되지 않는 무거운 의존성을 피하고 macOS 기본 도구와 저장소 스크립트로 재현 가능하게 만든다.

---

## 19. GitHub Actions

### `ci.yml`

실행:

- Pull Request
- main push

수행:

1. checkout
2. 프로젝트 생성
3. Swift Package resolve
4. arm64 build
5. unit test
6. 정적 검사
7. 결과 요약

Apple Silicon GitHub-hosted runner를 사용한다. 실제 제공되는 runner label은 구현 시 최신 공식 문서를 확인해 선택한다.

### `release.yml`

실행 조건:

```text
v*.*.*
```

수행:

1. SemVer tag 검증
2. 앱 버전을 tag에서 설정
3. build number 설정
4. 인증서 설치
5. 빌드 및 서명
6. 공증 및 staple
7. ZIP과 DMG 생성
8. Sparkle 서명 및 appcast
9. GitHub Release 생성
10. asset 업로드
11. 공개 appcast 저장소에 appcast와 release notes 게시
12. 결과 요약

workflow 권한은 최소화하고 secret을 로그에 출력하지 않는다.

---

## 20. Git 전략

이 저장소는 복잡한 Git Flow 대신 GitHub Flow를 사용한다.

장기간 유지되는 브랜치는 `main` 하나만 둔다. 별도의 `develop`, `release`, `staging` 브랜치를 상시 운영하지 않는다.

```text
main
 ├─ feat/menu-bar-ui
 ├─ feat/chrome-cdp
 ├─ feat/sparkle-update
 ├─ fix/chrome-launch-timeout
 ├─ docs/release-guide
 └─ ci/signing
```

### 기본 원칙

- `main`은 항상 빌드 및 배포 가능한 상태 유지
- 기능과 수정은 별도 브랜치
- 작업 브랜치는 짧게 유지하고 병합 후 삭제
- `main` 직접 push 금지
- Pull Request를 통해 병합
- 병합 전 CI build와 test 통과
- 공유된 commit에 force push 금지
- 비밀값과 인증서 commit 금지

저장소 최초 bootstrap 단계에서는 초기 commit을 `main`에 직접 만들 수 있다. 이후에는 PR 기반으로 전환한다.

### 브랜치 이름

```text
feat/<기능>
fix/<버그>
refactor/<리팩터링>
docs/<문서>
test/<테스트>
chore/<설정·도구>
ci/<CI-CD>
release/<릴리스-준비>
```

예:

```text
feat/chrome-session-controller
feat/umami-analytics
fix/cdp-reconnect
docs/privacy-policy
ci/notarization
release/1.0.0
```

### 커밋

Conventional Commits:

```text
<type>(optional scope): <summary>
```

type:

```text
feat
fix
refactor
docs
test
chore
ci
build
perf
revert
```

예:

```text
feat(chrome): add dedicated profile launcher
feat(cdp): apply mobile device emulation
fix(cdp): reconnect after Chrome window closes
feat(analytics): add opt-in Umami events
ci(release): add notarized DMG workflow
docs: document Apple signing setup
```

커밋 전:

- `git diff`
- `git status`
- secret 및 개인정보 포함 여부
- 기존 사용자 변경 보존 여부
- 가능한 경우 build/test

### Pull Request

PR 제목도 Conventional Commits 형식을 사용한다.

본문 템플릿:

```markdown
## 변경 내용

## 변경 이유

## 테스트

## 수동 확인 항목

## 스크린샷
```

Chrome, Google 로그인, 패스키, Sparkle, Apple 공증처럼 자동화가 어려운 것은 수동 확인 항목을 명시한다.

### 병합

기본은 Squash and merge.

- 기능 단위 기록 유지
- 실험적 commit 정리
- revert와 changelog 작성 용이

예외적으로 개별 commit 보존 가치가 명확할 때만 merge commit을 검토한다.

### Branch Protection

`main` 권장 설정:

- PR 없이 직접 push 금지
- 필수 status check
- unresolved conversation 금지
- force push 금지
- branch 삭제 금지
- 관리자도 가능한 한 규칙 적용

초기 1인 개발에서는 필수 승인 수를 0으로 둘 수 있다. 외부 기여가 시작되면 최소 1명 승인으로 변경한다.

### 릴리스

```text
main의 검증된 commit
→ 필요 시 release/1.0.0에서 최종 준비
→ main 병합
→ annotated tag
→ tag push
→ release workflow
→ GitHub Release
```

tag:

```text
vMAJOR.MINOR.PATCH
```

annotated tag:

```bash
git tag -a v1.0.0 -m "SKALA Attendance v1.0.0"
git push origin v1.0.0
```

tag 전 확인:

- CI 성공
- 버전과 build number 일치
- CHANGELOG
- 수동 QA
- Sparkle 설정
- Apple signing secrets
- Umami production 설정
- working tree clean

공개된 asset이나 appcast가 있다면 같은 tag를 재사용하거나 덮어쓰지 않는다. 수정 후 patch version을 배포한다.

### 버전 정책

Semantic Versioning:

- MAJOR: 호환되지 않는 변경
- MINOR: 하위 호환 기능 추가
- PATCH: 버그 수정

개발·내부 테스트:

```text
v0.x.x
```

첫 공개 안정 버전:

```text
v1.0.0
```

Pre-release:

```text
v1.0.0-alpha.1
v1.0.0-beta.1
v1.0.0-rc.1
```

Pre-release는 stable Sparkle appcast에 포함하지 않는다.

### Hotfix

최신 `main`에서 fix 브랜치:

```text
fix/passkey-launch
fix/sparkle-signature
fix/analytics-opt-out
```

PR → CI/QA → main → patch tag → 새 Release 순서로 처리한다.

### CHANGELOG

Keep a Changelog 스타일:

```markdown
## Unreleased

### Added
### Changed
### Fixed
### Security

## 1.0.0 - YYYY-MM-DD
```

사용자 경험, 설치, 인증, 출결창, 개인정보, 업데이트, 호환성에 영향을 주는 변경을 우선 기록한다.

### 외부 기여

```text
Fork
→ feature branch
→ commit
→ Pull Request
→ CI
→ review
→ squash merge
```

`CONTRIBUTING.md`에 다음을 명시한다.

- 빌드 요구사항
- 브랜치·commit 규칙
- 테스트 방법
- PR 형식
- 인증 정보를 Issue에 올리지 말 것
- 출결 API 분석과 자동 출결은 범위 밖

### 에이전트의 Git 권한

에이전트가 할 수 있는 작업:

- branch와 working tree 확인
- 작업 branch 생성
- stage와 commit
- 기능 단위 commit 분리
- PR 설명 작성
- GitHub CLI 인증 상태 확인

사용자 명시적 승인 없이 금지:

- `main` 직접 push
- remote push
- PR 생성
- force push
- tag 생성·push
- GitHub Release 생성
- 기존 tag 삭제
- branch protection 변경
- 저장소 공개 범위 변경
- history rewrite
- `git reset --hard`
- 미커밋 변경 삭제
- 실제 v1.0.0 배포

작업 완료 보고:

- 현재 branch
- 생성 branch
- 생성 commit
- 미커밋 변경
- remote push 여부
- PR 여부
- tag 및 release 여부

---

## 21. 앱 버전 관리

- `CFBundleShortVersionString`: SemVer
- `CFBundleVersion`: 정수 build number
- Release에서 Git tag가 source of truth
- 로컬 빌드는 기본 개발 버전
- 앱 About와 Umami에 같은 버전
- `CHANGELOG.md` 유지
- v1.0.0 release notes 초안 작성

---

## 22. 오류 처리

개발자 용어만 사용자에게 노출하지 않는다.

### Chrome 미설치

```text
Google Chrome이 필요합니다.

이 앱은 Google 로그인과 패스키를 안전하게 사용하기 위해
설치된 Google Chrome을 사용합니다.
```

### Chrome 실행 실패

```text
출결 브라우저를 시작하지 못했습니다.

Chrome이 업데이트 중이거나 전용 프로필이
다른 프로세스에서 사용 중일 수 있습니다.
```

버튼:

- 다시 시도
- 연결 진단
- 브라우저 세션 초기화
- 문제 보고

### CDP 연결 실패

- 제한된 횟수의 재시도
- 타임아웃
- Chrome 프로세스 확인
- localhost 포트 확인
- 사용자용 오류와 기술 진단 분리

Issue 템플릿에 포함 가능:

- 앱 버전
- macOS 버전
- Chrome 버전
- 오류 코드

포함 금지:

- 계정
- 쿠키
- URL query
- 프로필 파일
- 인증 토큰
- 전체 브라우저 로그

---

## 23. 보안 원칙

- remote debugging은 localhost 전용
- 일반 Chrome 프로필 접근 금지
- 인증 정보 수집 금지
- 출결 API 직접 호출 금지
- 자동 입실·퇴실 금지
- 자동 버튼 클릭 금지
- 쿠키 복사·추출 금지
- secret commit 금지
- analytics payload 최소화
- Sparkle 서명 검증
- Apple 인증서와 API key 비공개
- 원격 코드 실행 금지

---

## 24. 테스트

최소 단위 테스트:

- Chrome 경로 탐색
- Chrome argument 생성
- 전용 프로필 경로
- Chrome 버전 파싱
- 모바일 User-Agent 생성
- User-Agent Metadata
- CDP JSON-RPC encode/decode
- pending request matching
- CDP timeout
- MobileEmulationProfile
- window bounds 보정
- Umami payload
- analytics opt-out
- install event 1회
- 익명 ID 생성·재설정
- version parsing
- SemVer tag parsing

가능하면 mock URLProtocol과 WebSocket abstraction을 사용한다.

Google 로그인과 패스키는 자동화하지 않고 수동 QA로 둔다.

수동 QA:

### 설치

- 공증된 DMG
- Applications 드래그
- Gatekeeper 경고 없이 실행
- 메뉴바 아이콘
- Dock에 상시 아이콘 없음

### Chrome

- 미설치 안내
- 설치 후 재확인
- 일반 프로필과 전용 프로필 분리
- 일반 데이터 미변경
- 앱 재실행 후 로그인 유지

### 모바일 페이지

- 모바일 인식
- viewport
- 마우스 조작
- 새로고침
- 창 닫은 뒤 재열기
- 다중 모니터

### 인증

- Google 로그인
- 패스키 버튼
- Touch ID
- 인증 후 출결 페이지 복귀
- 재시작 후 세션 유지

### 업데이트

- 이전 버전에서 새 버전 탐지
- Sparkle 서명 검증
- 설치 및 재실행
- 버전 변경

### 통계

- 동의 전 미전송
- install 1회
- app_launch
- attendance_open
- opt-out 즉시 반영
- Google 정보 미포함

---

## 25. 문서

README는 한국어 기본.

구조:

1. 프로젝트 소개
2. 비공식 앱 고지
3. 주요 기능
4. 요구사항
5. 설치
6. 최초 실행
7. 개인정보
8. 업데이트
9. 문제 해결
10. 개발 환경
11. 빌드
12. Release
13. Umami
14. 기여
15. 라이선스

반드시 포함:

```text
SKALA Attendance는 SKALA 또는 SK AX가 제공하는 공식 애플리케이션이
아닌 독립적인 오픈소스 편의 도구입니다.

이 앱은 출결을 자동 처리하지 않습니다. 공식 웹페이지를 모바일
브라우저 환경으로 열어주며 최종 입실·퇴실 동작은 사용자가 직접 수행합니다.
```

`PRIVACY.md`:

- 수집 이벤트
- 수집하지 않는 정보
- Umami Cloud 및 선택적 self-hosted 참고 자료
- 비활성화 방법
- 익명 ID 재설정
- 문의 경로

`SECURITY.md`:

- 취약점 공개 절차
- 공개 Issue에 인증 정보 금지

`docs/release-setup.md`:

- Apple 승인 후 설정
- GitHub Secrets
- 서명·공증
- Sparkle
- v1.0.0 배포

---

## 26. 구현 진행 방식

### Phase 0: 환경 확인

- 저장소 상태
- 기존 파일
- Git 상태
- Xcode와 Swift
- Chrome 설치
- XcodeGen
- GitHub CLI 인증

기존 작업을 파괴하지 않는다.

### Phase 1: 계획

`docs/implementation-plan.md` 작성:

- 요구사항
- 아키텍처
- 구조
- 위험
- 순서
- 수동 검증

계획 후 멈추지 않고 구현을 계속한다.

### Phase 2: Chrome/CDP 프로토타입

- 전용 Chrome
- CDP
- 모바일 환경
- 출결 URL

실험 파일은 최종 코드로 정리한다.

### Phase 3: 네이티브 앱

- 메뉴바
- 온보딩
- Chrome controller
- CDP
- 설정
- 로그인 시 실행
- 오류 처리

### Phase 4: Analytics와 Sparkle

- Umami
- 동의
- Sparkle
- 업데이트 메뉴

### Phase 5: CI·Release

- build/test
- signing/notarization
- DMG
- appcast
- GitHub Pages

### Phase 6: 문서와 검증

- README
- Privacy
- Security
- Release setup
- 테스트
- 최종 리뷰

---

## 27. 완료 기준

### 로컬 개발

- bootstrap 문서
- 프로젝트 생성
- arm64 macOS 26 build
- unit tests
- 인증서 없는 Debug build

### 기능

- 메뉴바 앱
- 온보딩
- Chrome 확인
- 전용 프로필
- App Mode
- CDP
- 모바일 환경
- `https://att.skala-ai.com/`
- 창 앞으로 가져오기
- 새로고침
- 세션 초기화
- 로그인 시 실행
- 설정 화면

### 사용자 경험

- 터미널 불필요
- 확장 프로그램 불필요
- 최초 Google 로그인 외 기술 설정 불필요
- 이후 클릭 한 번

### 개인정보

- 통계 선택
- opt-out
- Google 계정 미수집
- 출결 내용 미수집
- 익명 ID

### 배포

- CI
- tag release workflow
- Sparkle appcast
- Developer ID·공증 준비
- DMG·ZIP
- Secrets 문서

### 문서

- README
- PRIVACY
- SECURITY
- CONTRIBUTING
- release setup
- Umami deployment
- manual QA

---

## 28. 최종 보고

작업 완료 후:

1. 구현 요약
2. 아키텍처
3. 생성·수정 파일
4. 실행 명령
5. 빌드 결과
6. 테스트 결과
7. 실제 확인 기능
8. 수동 확인 기능
9. Apple 승인 후 설정
10. Umami 설정
11. GitHub Secrets와 Variables
12. v1.0.0 릴리스 방법
13. 알려진 제한
14. Git 상태

Google 패스키, Apple 공증, Sparkle production update, 운영 Umami 수신은 실제 확인하지 않았다면 성공했다고 보고하지 않는다.

---

## 29. `/ulw-loop` 실행 권장문

저장소 루트에서 다음과 같이 실행한다.

```text
/ulw-loop Read `AGENTS.md`, `docs/PRODUCT_SPEC.md`, and
`docs/IMPLEMENTATION_STATUS.md` completely, then implement SKALA Attendance
through the locally verifiable v1.0.0-ready state.

Treat `docs/PRODUCT_SPEC.md` as the source of truth. Work phase by phase, but
do not stop after planning. Inspect the existing repository before modifying
anything. Implement, build, test, review, and update
`docs/IMPLEMENTATION_STATUS.md` continuously.

Use official documentation when current technical behavior must be verified.
Do not claim that Google passkey, Apple notarization, Sparkle production
updates, or production Umami ingestion succeeded unless actually tested.

Do not push, create a PR, create or push tags, publish a GitHub Release,
deploy the Umami server, or modify remote infrastructure without explicit
user approval.

Completion requires:
1. all locally implementable requirements completed;
2. arm64 build and automated tests passing;
3. CI and release configuration validated as far as possible;
4. credential-dependent or human-interaction checks documented;
5. `docs/IMPLEMENTATION_STATUS.md` and the final report updated accurately.

Do not finish merely because code has been written. Finish only after
implementation, verification, documentation, and a final repository review.
```

첫 구현 루프 이후 새 세션에서 다음 검토 루프를 권장한다.

```text
/ulw-loop Perform a hostile final review of the repository against
`docs/PRODUCT_SPEC.md`.

Do not assume the previous implementation is correct. Verify every completion
claim in `docs/IMPLEMENTATION_STATUS.md`, inspect security boundaries, run all
available builds and tests, detect missing or placeholder implementations,
review GitHub Actions and release scripts, and fix every locally resolvable
issue.

Do not push, tag, release, or deploy. Finish only when the repository is
honestly ready for manual passkey testing and later Apple credential setup.
```
