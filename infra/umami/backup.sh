#!/usr/bin/env bash
set -euo pipefail

mkdir -p backups
LATEST="backups/umami-$(date +%Y%m%d-%H%M%S).sql.gz"
docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-umami}" "${POSTGRES_DB:-umami}" | gzip > "$LATEST"
ln -sf "$(basename "$LATEST")" backups/latest.sql.gz
echo "Backup created: $LATEST"
