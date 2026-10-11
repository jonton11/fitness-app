#!/bin/sh

set -eu

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

/bin/sh /scripts/validate.sh "$backup"
echo "Verified ${backup}"
