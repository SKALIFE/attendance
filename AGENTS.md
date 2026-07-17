# Repository Instructions

## Source of truth

모든 작업을 시작하기 전에 다음 문서를 읽어라.

- `docs/PRODUCT_SPEC.md`
- `docs/IMPLEMENTATION_STATUS.md`가 존재하면 함께 읽어라.

제품 요구사항과 완료 기준은 `docs/PRODUCT_SPEC.md`를 따른다.

## Working rules

- 계획만 작성하고 멈추지 말고 실제 구현과 검증까지 수행한다.
- 기존 사용자 변경사항을 임의로 되돌리지 않는다.
- 작은 불확실성은 조사 후 합리적인 기본값으로 결정한다.
- 실제 구현을 막는 정보가 없는 한 사용자에게 질문하지 않는다.
- 기능 단위로 구현하고 각 단계마다 build와 test를 실행한다.
- 실패를 숨기거나 검증하지 않은 기능을 성공으로 보고하지 않는다.
- Google 패스키처럼 사람의 조작이 필요한 기능은 `수동 검증 필요`로 구분한다.
- 최신 기술 동작은 추측하지 말고 공식 문서를 확인한다.

## Safety boundaries

사용자의 명시적 승인 없이 다음을 수행하지 않는다.

- remote push
- Pull Request 생성
- tag 생성 또는 push
- GitHub Release 생성
- 운영 Umami 서버 배포 또는 변경
- Apple 인증서나 GitHub Secret 변경
- force push
- `git reset --hard`
- 사용자의 미커밋 변경 삭제
- 기존 commit history rewrite
- 저장소 공개 범위 또는 branch protection 변경

## Product boundaries

- 출결 API를 직접 호출하지 않는다.
- 입실·퇴실을 자동 실행하지 않는다.
- 페이지 버튼을 자동 클릭하지 않는다.
- Chrome 쿠키나 Google 인증 정보를 읽거나 복사하지 않는다.
- 일반 Chrome 프로필을 수정하지 않는다.
- 앱은 공식 출결 페이지를 모바일 Chrome 환경으로 열어주는 런처다.
- SKALA 또는 SK AX의 공식 앱처럼 표현하지 않는다.

## Git rules

- 기본 전략은 GitHub Flow다.
- 장기간 유지하는 브랜치는 `main` 하나다.
- 작업은 `feat/`, `fix/`, `docs/`, `test/`, `chore/`, `ci/` 등의 짧은 브랜치에서 진행한다.
- Conventional Commits를 사용한다.
- commit 전 `git status`와 `git diff`를 확인한다.
- 비밀값과 개인정보를 commit하지 않는다.
- 사용자의 기존 변경을 임의로 덮어쓰지 않는다.
- 사용자의 승인 없이 `main`에 push하지 않는다.
- 실제 tag와 release는 사용자의 승인 후 수행한다.

## Progress tracking

`docs/IMPLEMENTATION_STATUS.md`에 다음을 계속 갱신한다.

- 완료한 Phase
- 현재 작업
- 빌드 결과
- 테스트 결과
- 수동 검증 필요 항목
- 알려진 문제
- 다음 작업
- 현재 Git branch와 commit 상태

작업이 끝나면 현재 상태를 해당 문서에 반영한다.

## Completion standard

코드가 작성되었다는 이유만으로 완료로 판단하지 않는다.

완료 조건:

- 로컬에서 가능한 구현 완료
- arm64 build 성공
- automated tests 성공
- CI 및 release 설정 검토
- 문서 갱신
- placeholder 또는 미완성 구현 확인
- 수동 검증 항목 명시
- 최종 repository review

검증하지 않은 항목은 솔직하게 `수동 확인 필요` 또는 `미검증`으로 표시한다.
