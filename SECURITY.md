# Security Policy

## 취약점 공개 절차

1. 보안 취약점을 발견한 경우 GitHub의 **Security Advisory** 기능을 사용하여 비공개 보고해 주세요. 저장소의 Security 탭에서 "Report a vulnerability"를 선택합니다.
2. Security Advisory를 사용할 수 없는 경우 `skalife.security@gmail.com`으로 이메일을 보내주세요.
3. 공개 Issue에 인증 정보, 쿠키, 토큰, Chrome 프로필 파일, 개인정보를 포함하지 마세요.
4. 보고 후 72시간 이내에 확인하고, 30일 이내에 수정 계획을 전달합니다.
5. 수정이 완료되면 GitHub Security Advisory 또는 Release 노트로 공개합니다.

## 보안 경계

이 앱은 다음을 수행하지 않습니다.

- 출결 API 직접 호출
- 입실·퇴실 자동 실행
- 페이지 버튼 자동 클릭
- Google 로그인 화면 조작
- Chrome 쿠키 또는 인증 토큰 읽기·복사·저장
- 일반 Chrome 프로필 수정
- 원격 코드 실행
- 서버에서 내려받은 임의 스크립트 실행

## Chrome 검증

앱은 Chrome 실행 전 번들 식별자(`com.google.Chrome`)를 검증합니다. 번들 식별자가 일치하지 않으면 실행하지 않습니다.

## CDP 보안

Chrome DevTools Protocol은 `127.0.0.1` loopback에서만 연결합니다. 원격 주소로의 WebSocket 연결을 거부합니다.

## 통계 보안

익명 통계는 HTTPS로만 전송합니다. HTTP URL은 거부됩니다.

## 릴리스 보안

- Sparkle private key, Apple 인증서, GitHub secret은 저장소에 커밋하지 않습니다.
- Release workflow는 `environment: release`로 보호되며 credentials가 설정된 뒤에만 실제 서명·공증·배포 절차를 수행합니다.
- Release 전 GitHub Actions를 commit SHA로 pin하여 supply chain 공격을 방지하는 것을 권장합니다.
- Homebrew XcodeGen 의존성은 release 환경에서 설치 시 버전을 고정하는 것을 권장합니다.

## 알려진 제한사항

- 로컬 unsigned 빌드는 Hardened Runtime ad-hoc 서명만 적용됩니다. Developer ID 서명과 공증은 release workflow에서만 수행됩니다.
- Chrome 번들 서명 검증( codesign )은 번들 식별자 검증으로 대체합니다. 동일 사용자 권한의 정교한 위장은 방지하지 못할 수 있습니다.
