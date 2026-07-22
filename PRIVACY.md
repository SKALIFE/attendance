# Privacy Policy

SKALA Attendance는 공식 출결 페이지를 설치된 Google Chrome의 전용 프로필로 열어주는 런처입니다. 출결을 자동 처리하지 않고 Google 로그인 화면을 조작하지 않습니다.

## 수집하는 정보

사용자가 익명 사용 통계에 동의한 경우 다음만 전송합니다.

- 익명 설치 식별자
- 앱 실행 이벤트
- 출결 페이지 열기 이벤트
- 앱 버전과 build number
- macOS 버전
- arm64 아키텍처 정보

통계는 HTTPS로 암호화되어 Umami Cloud Hobby US의 `https://gateway.umami.is/api/send`으로 전송됩니다.

## 수집하지 않는 정보

- Google 이메일, 계정 식별자, 이름
- 출결 성공 여부, 입실·퇴실 시각, 출결 기록
- 페이지 HTML, URL query string, 쿠키, 인증 토큰
- Chrome 프로필 데이터, 기기 이름, 시리얼 번호, MAC 주소, 하드웨어 UUID

## 비활성화와 재설정

설정의 개인정보 탭에서 익명 통계를 끌 수 있습니다. 비활성화하면 어떤 이벤트도 전송하지 않습니다. 같은 화면에서 익명 설치 식별자를 재설정할 수 있습니다.

## 통계 인프라

운영 익명 통계는 Umami Cloud Hobby US에서 처리됩니다. Umami Cloud는 이 최소 분석 데이터를 처리하는 서드파티 처리자입니다. 수집 항목과 동의 기반 전송 정책은 위에 설명한 범위로 제한됩니다.

`infra/umami/`의 Umami v3 Compose 자료는 자체 호스팅이 필요한 경우를 위한 선택적 참고 자료이며, 현재 운영 수집에는 사용하지 않습니다.

## 문의

개인정보 관련 문의는 GitHub Issue 또는 저장소 owner에게 이메일로 연락해 주세요. 인증 정보, 쿠키, 토큰, Chrome 프로필 파일은 이슈에 포함하지 마세요.
