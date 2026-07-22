#!/usr/bin/env bash
set -euo pipefail

BACKUP="${1:?backup file required}"
gzip -dc "$BACKUP" | docker compose exec -T postgres psql -U "${POSTGRES_USER:-umami}" "${POSTGRES_DB:-umami}"
