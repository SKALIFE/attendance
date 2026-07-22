# Contributing

## 빌드 전제조건

- macOS 26.0 이상
- Xcode (Swift 6.0)
- XcodeGen (`brew install xcodegen`)
- Apple Silicon arm64

## 개발

```bash
# 의존성 설치 및 프로젝트 생성
scripts/bootstrap.sh

# 테스트
scripts/test.sh

# Debug 빌드
scripts/build.sh Debug

# Release 빌드
scripts/build.sh Release

# 앱 아이콘 재생성 (필요 시)
scripts/generate-icon.sh
```

`project.yml`이 Xcode 프로젝트의 source of truth입니다. `SKALAAttendance.xcodeproj`를 직접 수정하지 마세요.

## 코딩 규칙

- Swift 6, strict concurrency
- 250 LOC ceiling per file
- Conventional Commits
- 불확실성은 조사 후 합리적인 기본값으로 결정
- 검증하지 않은 기능을 완료로 표시하지 않음

## 브랜치와 커밋

- 브랜치는 `feat/`, `fix/`, `docs/`, `test/`, `chore/`, `ci/` 접두사를 사용합니다.
- `main` 브랜치에 직접 push하지 않습니다.
- 커밋 전 `git status`와 `git diff`를 확인합니다.
- 비밀값과 개인정보를 커밋하지 않습니다.

## Pull Request

PR에는 변경 내용, 변경 이유, 테스트 결과, 수동 확인 항목을 포함합니다. Google 로그인, 패스키, Sparkle 실제 업데이트, Apple 공증은 수동 확인 항목으로 명시합니다.

## 보안 주의

**GitHub Issue에 인증 정보, 쿠키, 토큰, Chrome 프로필 파일, 개인정보를 포함하지 마세요.** 보안 취약점은 [SECURITY.md](SECURITY.md)의 절차를 따라 비공개로 보고하세요.

## 범위 밖

출결 API 분석, 자동 입실·퇴실, 페이지 버튼 자동 클릭, Chrome 쿠키 또는 Google 인증 정보 접근은 프로젝트 범위 밖입니다. 이러한 기능을 구현하는 PR은 받지 않습니다.
