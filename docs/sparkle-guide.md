# Sparkle 업데이트 안내

## Sparkle이란?

Sparkle은 macOS 앱용 자동 업데이트 프레임워크입니다. SKALA Attendance에서는 새 버전을 확인하고, 서명된 업데이트만 사용자 승인 후 설치합니다.

Sparkle은 Google 계정, 출결 정보, Chrome 쿠키를 다루지 않습니다.

## 업데이트 흐름

1. 개발자가 새 앱 버전을 Developer ID로 서명·공증합니다.
2. Sparkle EdDSA 개인키로 업데이트 ZIP에 서명합니다.
3. `appcast.xml`에 버전·다운로드 주소·서명을 게시합니다.
4. 설치된 앱이 공개 `SKALIFE/attendance-appcast` 저장소의 appcast를 확인합니다.
5. Sparkle이 서명을 검증한 뒤 사용자에게 업데이트를 제안합니다.
6. 사용자가 승인하면 업데이트를 설치하고 앱을 다시 실행합니다.

서명이 없거나 공개키와 일치하지 않는 업데이트는 설치되지 않습니다.

## 키 역할

- **공개키**: 앱에 포함됩니다. 업데이트 서명을 검증하는 데만 사용하며 공개해도 됩니다.
- **개인키**: 업데이트에 서명합니다. 절대 저장소, 채팅, Issue에 올리면 안 됩니다.

## 처음 키 만들기

Sparkle 도구가 설치된 환경에서 한 번 실행합니다.

```bash
generate_keys
```

명령이 공개키를 출력하고 개인키를 macOS Keychain에 저장합니다. 출력된 공개키는 `SPARKLE_PUBLIC_KEY` 빌드 설정에 넣습니다.

CI에서 서명해야 하면 개인키를 안전한 파일로 내보냅니다.

```bash
umask 077
mkdir -p "$HOME/.sparkle-keys"
generate_keys -x "$HOME/.sparkle-keys/skala-attendance-ed25519"
chmod 600 "$HOME/.sparkle-keys/skala-attendance-ed25519"
```

내보낸 파일의 Base64 값을 GitHub Secret `SPARKLE_EDDSA_PRIVATE_KEY`에 등록합니다. export 파일과 Keychain은 암호화 백업을 권장합니다.

## 아직 실제로 하지 않은 것

현재 로컬 Debug/unsigned 빌드에서는 실제 업데이트 설치를 검증하지 않았습니다. 실제 검증에는 Apple Developer ID 서명, 공증, GitHub Release, 공개 appcast 저장소 배포가 필요합니다.

## 참고 문서

- [Sparkle 공식 문서](https://sparkle-project.org/documentation/)
- [Sparkle 업데이트 배포 문서](https://sparkle-project.org/documentation/publishing)
- [프로젝트 릴리스 설정](release-setup.md)
