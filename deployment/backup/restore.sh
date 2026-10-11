#!/bin/sh

set -eu

if [ "${CONFIRM_RESTORE:-}" != "yes" ]; then
  echo "Set CONFIRM_RESTORE=yes to replace the current database" >&2
  exit 1
fi

case "${BACKUP_FILE:-}" in
  "")
    echo "Set BACKUP_FILE to a dump filename from the backup directory" >&2
    exit 1
    ;;
  */*|*\\*)
    echo "BACKUP_FILE must be a filename, not a path" >&2
    exit 1
    ;;
esac

backup="/backups/${BACKUP_FILE}"

if [ ! -f "$backup" ]; then
  echo "Backup not found: ${backup}" >&2
  exit 1
fi

case "${PGDATABASE:-}" in
  ""|postgres|template0|template1)
    echo "PGDATABASE must name a dedicated application database" >&2
    exit 1
    ;;
esac

/bin/sh /scripts/validate.sh "$backup"
dropdb \
  --maintenance-db=postgres \
  --if-exists \
  --force \
  "$PGDATABASE"
createdb --maintenance-db=postgres "$PGDATABASE"
pg_restore \
  --exit-on-error \
  --no-owner \
  --no-privileges \
  --dbname="$PGDATABASE" \
  "$backup"

echo "Restored and verified ${backup}"
