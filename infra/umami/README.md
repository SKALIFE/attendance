# Umami Self-Hosting

Raspberry Pi OS arm64에서 Umami v3와 PostgreSQL을 실행하기 위한 선택적 자체 호스팅 예제입니다. 현재 production은 Umami Cloud Hobby US를 `https://gateway.umami.is`로 사용하며, 이 디렉터리는 운영 수집에 사용하지 않습니다. 자체 호스팅 운영 서버 배포는 사용자 승인 후 수행합니다.

## 시작

```bash
cp .env.example .env
# .env에서 POSTGRES_PASSWORD, APP_SECRET, DATABASE_URL을 강력한 값으로 변경
# POSTGRES_PASSWORD 변경 시 DATABASE_URL의 비밀번호도 함께 변경해야 함
docker compose up -d
```

PostgreSQL은 외부 포트를 공개하지 않습니다. Umami는 기본적으로 `127.0.0.1:3000`에만 바인딩됩니다.

## Cloudflare Tunnel 예제

Umami를 외부에 노출하려면 Cloudflare Tunnel 또는 reverse proxy를 사용합니다. Cloudflare Tunnel 예제:

```bash
# cloudflared 설치 후
cloudflared tunnel create umami
cloudflared tunnel route dns umami analytics.skalife.kr

cat > ~/.cloudflared/umami.yml <<EOF
tunnel: <tunnel-id>
credentials-file: ~/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: analytics.skalife.kr
    service: http://127.0.0.1:3000
  - service: http_status:404
EOF

cloudflared tunnel run umami
```

Cloudflare에서 rate limit과 WAF 규칙을 적용하는 것을 권장합니다.

## 자체 호스팅 초기 설정

1. 기본 관리자 비밀번호를 변경합니다.
2. Website를 생성합니다. hostname은 `attendance-app.skalife.kr`로 설정합니다.
3. Website ID를 GitHub Actions 변수(`UMAMI_WEBSITE_ID`)로 설정합니다.
4. `UMAMI_BASE_URL`을 `https://analytics.skalife.kr`로 설정합니다.
5. 필요하면 Cloudflare에서 rate limit을 적용합니다.

## 업데이트 절차

```bash
# Umami 버전 업데이트
docker compose pull
docker compose up -d

# 마이그레이션 확인
docker compose logs umami | grep -i migrat
```

업데이트 전에 백업을 수행합니다. Umami major 버전 업그레이드 시 데이터베이스 스키마 마이그레이션이 필요할 수 있습니다.

## 백업과 복원

```bash
# 백업
./backup.sh

# 복원
./restore.sh backups/latest.sql.gz
```

백업은 최소 일일 1회 자동화하는 것을 권장합니다 (cron 또는 systemd timer).

## 보안

- PostgreSQL 외부 포트 미공개
- 관리자 비밀번호 변경 필수
- HTTPS만 허용 (Cloudflare Tunnel이 자동 처리)
- `.env` 파일을 저장소에 커밋하지 않음
