#!/bin/sh
set -eu
umask 077

backup_dir="/opt/chatlux/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
compose() {
  docker compose --env-file /opt/chatlux/.env -f /opt/chatlux/docker-compose.gcp.yaml "$@"
}

compose exec -T postgres pg_dump -U postgres -d chatwoot_production -Fc > "$backup_dir/database.dump"
docker run --rm --network none --entrypoint tar \
  -v chatlux_storage_data:/storage:ro \
  -v "$backup_dir:/backup" \
  redis:7-alpine -czf /backup/storage.tar.gz -C /storage .
cp /opt/chatlux/.env "$backup_dir/environment.env"
cp /opt/chatlux/docker-compose.gcp.yaml "$backup_dir/compose.yaml"
printf 'Backup saved: %s\n' "$backup_dir"
