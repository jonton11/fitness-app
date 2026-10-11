#!/bin/sh

set -eu

umask 077

backup_kind=${BACKUP_KIND:-daily}
daily_retention=${DAILY_BACKUP_RETENTION_COUNT:-14}
pre_deploy_retention=${PRE_DEPLOY_BACKUP_RETENTION_COUNT:-10}

case "$backup_kind" in
  daily)
    retention=$daily_retention
    ;;
  pre-deploy)
    retention=$pre_deploy_retention
    ;;
  *)
    echo "BACKUP_KIND must be daily or pre-deploy" >&2
    exit 1
    ;;
esac

case "$retention" in
  ""|*[!0-9]*|0)
    echo "Backup retention must be a positive integer" >&2
    exit 1
    ;;
esac

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
filename="fitness-${backup_kind}-${timestamp}.dump"
destination="/backups/${filename}"
temporary="/backups/.${filename}.$$"

cleanup() {
  rm -f "$temporary"
}

trap cleanup EXIT HUP INT TERM

pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="$temporary"

/bin/sh /scripts/validate.sh "$temporary"
mv "$temporary" "$destination"

kept=0
find /backups -maxdepth 1 -type f -name "fitness-${backup_kind}-*.dump" -print |
  sort -r |
  while IFS= read -r backup; do
    kept=$((kept + 1))
    if [ "$kept" -gt "$retention" ]; then
      rm -f "$backup"
    fi
  done

echo "Created and verified ${destination}"
