#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: validate.sh ARCHIVE" >&2
  exit 1
fi

archive=$1
validation_suffix=$(tr -d '-' < /proc/sys/kernel/random/uuid)
validation_database="fitness_restore_validation_${validation_suffix}"

cleanup() {
  dropdb \
    --maintenance-db=postgres \
    --if-exists \
    --force \
    "$validation_database" >/dev/null 2>&1 || true
}

trap cleanup EXIT HUP INT TERM

createdb --maintenance-db=postgres "$validation_database"
pg_restore \
  --exit-on-error \
  --no-owner \
  --no-privileges \
  --dbname="$validation_database" \
  "$archive"
