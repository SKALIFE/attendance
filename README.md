# SKALA Attendance

## 1. 프로젝트 소개

SKALA Attendance는 macOS 메뉴바에서 SKALA 출결 페이지(`https://att.skala-ai.com/`)를 모바일 브라우저 환경으로 여는 오픈소스 편의 도구입니다. 설치된 Google Chrome을 전용 프로필로 실행하고 CDP로 Android Chrome 모바일 환경을 적용합니다.

## 2. 비공식 앱 고지

SKALA Attendance는 SKALA 또는 SK AX가 제공하는 공식 애플리케이션이 아닌 독립적인 오픈소스 편의 도구입니다.

이 앱은 출결을 자동 처리하지 않습니다. 공식 웹페이지를 모바일 브라우저 환경으로 열어주며 최종 입실·퇴실 동작은 사용자가 직접 수행합니다.

## 3. 주요 기능

- macOS 메뉴바에서 `https://att.skala-ai.com/` 열기
- 설치된 Google Chrome Stable을 전용 프로필로 실행 (일반 프로필과 분리)
- Chrome App Mode와 CDP 기반 Android Chrome 모바일 환경 적용
- 창 앞으로 가져오기, 페이지 새로고침, 브라우저 세션 초기화
- 최초 실행 온보딩 (Chrome 확인, 익명 통계 선택, 로그인 시 자동 실행)
- 동의 기반 익명 Umami 통계
- Sparkle 2 자동 업데이트

## 4. 요구사항

- macOS 26.0 이상
- Apple Silicon arm64
- Google Chrome Stable (번들 식별자 `com.google.Chrome`)

## 5. 설치

1. [Releases](https://github.com/skalife/attendance/releases)에서 최신 DMG를 다운로드합니다.
2. DMG를 열고 `SKALA Attendance.app`을 Applications 폴더로 드래그합니다.
3. 처음 실행 시 Gatekeeper가 차단하면 시스템 설정에서 "확인된 개발자"를 허용합니다.

> Release는 Developer ID 서명과 Apple 공증이 적용된 DMG로 배포됩니다. 서명되지 않은 로컬 빌드는 Gatekeeper 통과가 보장되지 않습니다.

## 6. 최초 실행

1. 앱을 실행하면 온보딩 창이 나타납니다.
2. Google Chrome 설치를 확인합니다. 미설치 시 다운로드 페이지로 이동 후 "다시 확인"합니다.
3. 익명 사용 통계 동의 여부를 선택합니다 (기본 활성화, 설정에서 언제든 끌 수 있음).
4. 로그인 시 자동 실행 여부를 선택합니다.
5. "Google 로그인 및 시작" 버튼을 누르면 전용 Chrome이 모바일 환경으로 출결 페이지를 엽니다.
6. Chrome에서 Google 계정으로 로그인하고 Google 패스키로 인증합니다.

온보딩을 다시 확인하려면 설정 > 일반 > "최초 설정 다시 보기"를 선택하세요. 창을 닫으면 기존 설정 완료 상태가 유지됩니다. 이 동작은 전용 Chrome 프로필, 로그인 세션, 일반 Chrome 데이터를 변경하지 않습니다.

## 7. 개인정보

통계를 켠 경우에도 익명 설치 식별자, 앱 실행, 출결 페이지 열기, 앱 버전, macOS 버전, arm64 정보만 전송합니다. Google 계정, 이름, 이메일, 출결 기록, 페이지 내용, 쿠키, 인증 토큰, Chrome 프로필 데이터는 수집하지 않습니다.

자세한 내용은 [PRIVACY.md](PRIVACY.md)를 참고하세요.

## 8. 업데이트

앱은 Sparkle 2를 통해 자동 업데이트를 확인합니다. 메뉴바 "업데이트 확인…"을 눌러 수동으로 확인할 수도 있습니다. 업데이트는 EdDSA 서명이 검증된 경우에만 설치됩니다.

> Sparkle appcast는 공개 [`SKALIFE/attendance-appcast`](https://github.com/SKALIFE/attendance-appcast) 저장소의 `main` 브랜치에 배포됩니다. 실제 업데이트 설치는 수동 검증이 필요합니다.

키 생성과 서명·배포 흐름은 [Sparkle 업데이트 안내](docs/sparkle-guide.md)를 참고하세요.

## 9. 문제 해결

- **Chrome이 열리지 않음**: Google Chrome Stable이 설치되어 있는지 확인하세요. 설정 > 브라우저 > "연결 진단"으로 상태를 확인할 수 있습니다.
- **출결 페이지가 모바일로 표시되지 않음**: 전용 Chrome을 완전히 종료하고 다시 시도하세요. 설정 > 브라우저 > "브라우저 세션 초기화"로 프로필을 새로 만들 수 있습니다.
- **로그인이 유지되지 않음**: 전용 프로필이 초기화되었을 수 있습니다. 다시 Google 로그인을 수행하세요.
- **메뉴바 아이콘이 보이지 않음**: 앱이 실행 중인지 확인하고, 필요하면 Activity Monitor에서 `SKALAAttendance` 프로세스를 확인하세요.

## 10. 개발 환경

```bash
# 의존성 설치 및 프로젝트 생성
scripts/bootstrap.sh
```

요구사항: macOS 26.0, Xcode (Swift 6.0), XcodeGen, Apple Silicon.

`project.yml`이 Xcode 프로젝트의 source of truth입니다. `SKALAAttendance.xcodeproj`는 로컬에서 생성합니다.

## 11. 빌드

```bash
# 테스트
scripts/test.sh

# Debug 빌드
scripts/build.sh Debug

# Release 빌드
scripts/build.sh Release
```

## 12. Release

로컬 unsigned 검증:

```bash
scripts/release-local.sh --unsigned
```

Developer ID 서명, Apple 공증, Sparkle EdDSA 서명, GitHub Release, 공개 appcast 저장소 배포, 운영 Umami 수신은 credentials와 사용자 승인 후 tag push로 진행합니다. 자세한 절차는 [docs/release-setup.md](docs/release-setup.md)를 참고하세요.

## 13. Umami

익명 통계는 Umami Cloud Hobby US를 통해 수집됩니다. 운영 수집 주소는 `https://gateway.umami.is`이며, 앱은 여기에 `/api/send`를 붙여 전송합니다. `infra/umami/`은 자체 호스팅이 필요한 경우에만 참고하는 선택 사항입니다. 로컬 unsigned 빌드는 Umami 설정이 비어 있으면 어떤 이벤트도 전송하지 않습니다.

## 14. 기여

이슈와 풀 리퀘스트를 환영합니다. [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 코드는 Swift 6, strict concurrency, 250 LOC ceiling 원칙을 따릅니다.

## 15. 라이선스

MIT License. [LICENSE](LICENSE) 파일을 참고하세요.
