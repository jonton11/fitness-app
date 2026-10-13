#!/usr/bin/env bash

set -Eeuo pipefail

commit_sha=${1:-}
repository_url=${2:-}

if [[ ! "$commit_sha" =~ ^[0-9a-f]{40}$ || -z "$repository_url" ]]; then
  echo "Usage: deploy.sh COMMIT_SHA REPOSITORY_URL" >&2
  exit 1
fi

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
deployment_config=${FITNESS_DEPLOYMENT_CONFIG:-/etc/fitness-app/deployment.env}

if [[ -f "$deployment_config" ]]; then
  # This file is owned by the production host and contains non-secret paths.
  source "$deployment_config"
fi

data_root=${FITNESS_DATA_ROOT:-/srv/fitness-app}
environment_file=${FITNESS_ENV_FILE:-/etc/fitness-app/production.env}
backup_directory=${FITNESS_BACKUP_DIRECTORY:-$data_root/backups}
source_path=$data_root/source
deployed_commit_file=$data_root/deployed-commit.txt
deployment_started=false
compose=()

report_failure() {
  status=$?
  trap - ERR

  if [[ "$deployment_started" == true ]]; then
    "${compose[@]}" ps || true
    "${compose[@]}" logs --tail 200 api web postgres || true
  fi

  exit "$status"
}

fail() {
  echo "$1" >&2
  return 1
}

trap report_failure ERR

if [[ ! -f "$environment_file" ]]; then
  echo "Production environment file not found: $environment_file" >&2
  exit 1
fi

mkdir -p "$data_root" "$backup_directory"
export FITNESS_BACKUP_DIRECTORY="$backup_directory"

"$script_directory/checkout.sh" "$commit_sha" "$repository_url" "$source_path"

compose=(
  docker compose
  --project-directory "$source_path"
  --env-file "$environment_file"
  -f "$source_path/compose.production.yml"
)
deployment_started=true

"${compose[@]}" config --quiet
"${compose[@]}" build api web
"${compose[@]}" up -d postgres
"${compose[@]}" stop web api
"${compose[@]}" run --rm -e BACKUP_KIND=pre-deploy backup
"${compose[@]}" run --rm api bin/rails db:migrate
"${compose[@]}" up -d --wait --remove-orphans

published_address=$("${compose[@]}" port web 8080 | head -n 1)
published_port=${published_address##*:}

if [[ ! "$published_port" =~ ^[0-9]+$ ]]; then
  fail "Unexpected published address: $published_address"
fi

health_url="http://127.0.0.1:${published_port}/health"
healthy=false

for _attempt in {1..12}; do
  if curl --fail --silent --show-error --max-time 5 "$health_url" >/dev/null; then
    healthy=true
    break
  fi

  sleep 5
done

if [[ "$healthy" != true ]]; then
  fail "Production health check failed: $health_url"
fi

temporary_commit_file=${deployed_commit_file}.tmp
printf '%s\n' "$commit_sha" > "$temporary_commit_file"
mv "$temporary_commit_file" "$deployed_commit_file"
trap - ERR

echo "Deployed $commit_sha"
