# Manual QA Checklist

자동 테스트로 대체하지 않는 항목입니다. 각 항목은 실제 환경에서 수동으로 검증해야 합니다.

## 설치

- 공증된 DMG를 Applications로 드래그 설치
- Gatekeeper 경고 없이 실행
- 메뉴바 아이콘 표시
- Dock에 상시 아이콘이 남지 않음
- 설치 후 Chrome 미설치 상태에서 온보딩 Chrome 안내 표시
- Chrome 설치 후 "다시 확인"으로 온보딩 계속 진행

## Chrome과 인증

- Chrome 미설치 안내
- 전용 프로필과 일반 Chrome 프로필 분리 확인
  - 일반 Chrome 프로필의 북마크, 확장, 쿠키가 변경되지 않음
  - 전용 프로필 경로(`~/Library/Application Support/kr.skalife.attendance/ChromeProfile`)만 앱이 관리
- Google SSO 로그인
- Google 패스키 버튼과 Touch ID
- 인증 후 출결 페이지 복귀
- 앱과 Chrome 재시작 후 로그인 세션 유지

## 모바일 페이지

- 실제 출결 페이지가 모바일 브라우저로 인식
- viewport, touch 이벤트 정상 동작
- 마우스 클릭/터치로 입실·퇴실 버튼 조작 가능
- 새로고침, 창 닫은 뒤 재열기
- 다중 모니터에서 창 위치 보정
- 사용자가 창을 이동·크기 변경한 값이 다음 실행에서 복원

## 업데이트와 배포

- Developer ID 서명
- Apple 공증과 staple
- 공증된 DMG Gatekeeper 통과
- Sparkle 실제 업데이트 탐지·설치·재실행
- 업데이트 후 버전 번호 변경 확인 (메뉴바 > 설정 > 정보)
- GitHub Pages appcast 정상 배포
- 실제 v1.0.0 GitHub Release

## 통계

- 동의 전 미전송 (온보딩 완료 전)
- install 1회, app_launch, attendance_open
- opt-out 즉시 반영
- 운영 Umami 수신
- Google 계정 및 출결 정보 미포함

## 세션 초기화

- 브라우저 세션 초기화 후 전용 프로필 재생성
- 초기화 후 재로그인 정상 동작
- 초기화 중 기존 Chrome 프로세스 정상 종료
