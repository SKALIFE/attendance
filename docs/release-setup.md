# Release Setup

이 문서는 Apple 승인과 GitHub Secrets 및 repository variables 설정 후 수행할 릴리스 절차를 설명합니다. 이 저장소 작업에서는 remote push, tag, GitHub Release, 운영 Umami 설정 변경을 수행하지 않습니다.

## Required GitHub Secrets

- `APPLE_TEAM_ID`
- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`
- `SPARKLE_EDDSA_PRIVATE_KEY`
- `SPARKLE_PUBLIC_KEY`
- `APPCAST_REPO_TOKEN` (fine-grained token with Contents: read and write access to `SKALIFE/attendance-appcast`)

## Sparkle EdDSA Key Setup

Sparkle 업데이트는 앱에 포함된 공개 키와 appcast 서명에 사용하는 비공개 키가 한 쌍이어야 합니다. 키는 릴리스 담당자의 보안 저장소에서 한 번 생성합니다.

먼저 키를 만들고 표시되는 공개 키를 기록합니다.

```bash
SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
"$SPARKLE_BIN/generate_keys"
```

이 명령이 표시한 공개 키를 GitHub Secret `SPARKLE_PUBLIC_KEY`에 저장합니다.

CI에 쓸 비공개 키는 제한된 권한의 로컬 디렉터리로 export합니다.

```bash
umask 077
SPARKLE_KEY_DIR="$HOME/.config/skala-attendance/sparkle"
SPARKLE_KEY_EXPORT="$SPARKLE_KEY_DIR/eddsa-private-key.base64"
mkdir -p "$SPARKLE_KEY_DIR"
chmod 700 "$SPARKLE_KEY_DIR"
"$SPARKLE_BIN/generate_keys" -x "$SPARKLE_KEY_EXPORT"
chmod 600 "$SPARKLE_KEY_EXPORT"
```

`generate_keys -x`가 만든 export 파일에는 CI가 그대로 사용할 한 줄 Base64 값이 들어 있습니다. 줄바꿈·따옴표·추가 encoding 없이 해당 한 줄만 GitHub Secret `SPARKLE_EDDSA_PRIVATE_KEY`에 저장합니다. release workflow는 이 값을 표준 입력으로 `generate_appcast --ed-key-file -`에 전달합니다.

export 파일은 로컬 보안 저장소에만 보관하고, 사용 후 안전하게 삭제합니다. 비공개 키와 export 파일을 저장소, `xcconfig`, appcast, Release notes, Issue, CI 로그에 commit하지 않습니다. release workflow는 공개 키를 `SUPublicEDKey` build setting으로 전달하여 앱의 `Info.plist`에 포함합니다. 공개 키를 변경하면 이전 앱이 새 appcast를 검증할 수 없으므로, 공개 릴리스 후에는 기존 키를 유지합니다.

키를 등록한 뒤에는 GitHub release environment에서 `SPARKLE_PUBLIC_KEY`가 비어 있지 않은지 확인하고, 실제 서명된 이전 버전에서 업데이트를 수동 검증합니다. 로컬 unsigned 빌드는 공개 키가 비어 있어도 정상 빌드되지만 Sparkle 업데이트 검증을 대신하지 않습니다.

## Required GitHub Variables

- `UMAMI_BASE_URL`: `https://gateway.umami.is`
- `UMAMI_WEBSITE_ID`: Umami Cloud Website ID, 실제 값은 저장소에 기록하지 않음
- `UMAMI_HOSTNAME`

이 값들은 GitHub Secrets가 아니라 GitHub repository variables입니다. release workflow는 production Umami variable이 하나라도 없으면 archive signing 전에 실패합니다. 로컬 unsigned 빌드는 Umami 설정이 비어 있어도 계속 동작하며 분석 이벤트를 전송하지 않습니다.

현재 production은 Umami Cloud Hobby US를 사용합니다. 앱은 `UMAMI_BASE_URL`에 `/api/send`를 붙여 `https://gateway.umami.is/api/send`으로 전송합니다. 일부 Umami 문서에는 이전 Cloud 수집 URL인 `https://cloud.umami.is`가 보일 수 있지만, 현재 Cloud changelog는 `https://gateway.umami.is`를 수집 주소로 식별합니다. `https://cloud.umami.is/script.js`는 브라우저 추적기 전달용 URL이며 이 앱의 직접 수집 endpoint가 아닙니다.

## Local Validation

```bash
scripts/test.sh
scripts/build.sh Release
scripts/release-local.sh --unsigned
```

## Credential-Gated Validation

```bash
codesign --verify --deep --strict SKALAAttendance.app
spctl --assess --type execute SKALAAttendance.app
xcrun stapler validate SKALAAttendance.app
xcrun stapler validate SKALA-Attendance-1.0.0-arm64.dmg
```

## Release Workflow

The tag workflow is guarded by the `release` GitHub environment and runs only for `v*.*.*` tags. After credentials are configured and a tag is approved, it performs:

- Developer ID archive build
- app and DMG notarization and stapling
- ZIP and DMG artifact creation using the tag version
- Sparkle appcast generation with `generate_appcast --ed-key-file -`
- GitHub Release creation with ZIP and DMG assets
- `appcast.xml` and release notes publication to the `main` branch of the public `SKALIFE/attendance-appcast` repository

The workflow checks out the public appcast repository with `APPCAST_REPO_TOKEN` and does not persist that token in the checkout. It copies only `appcast.xml` and the release notes markdown, and commits only when either file changes. Sparkle production validation still requires installing an older signed build and confirming it updates through the published appcast. This local repository pass did not push a tag, create a GitHub Release, publish to the public repository, or validate production Sparkle installation.
