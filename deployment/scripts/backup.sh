#!/usr/bin/env bash

set -euo pipefail

backup_kind=${1:-daily}
deployment_config=${FITNESS_DEPLOYMENT_CONFIG:-/etc/fitness-app/deployment.env}

case "$backup_kind" in
  daily | pre-deploy) ;;
  *)
    echo "Backup kind must be daily or pre-deploy" >&2
    exit 1
    ;;
esac

if [[ -f "$deployment_config" ]]; then
  # This file is owned by the production host and contains non-secret paths.
  source "$deployment_config"
fi

data_root=${FITNESS_DATA_ROOT:-/srv/fitness-app}
environment_file=${FITNESS_ENV_FILE:-/etc/fitness-app/production.env}
backup_directory=${FITNESS_BACKUP_DIRECTORY:-$data_root/backups}
source_path=$data_root/source

if [[ ! -d "$source_path/.git" ]]; then
  echo "Production checkout not found: $source_path" >&2
  exit 1
fi

if [[ ! -f "$environment_file" ]]; then
  echo "Production environment file not found: $environment_file" >&2
  exit 1
fi

mkdir -p "$backup_directory"
export FITNESS_BACKUP_DIRECTORY="$backup_directory"

exec docker compose \
  --project-directory "$source_path" \
  --env-file "$environment_file" \
  -f "$source_path/compose.production.yml" \
  run --rm -e "BACKUP_KIND=$backup_kind" backup
