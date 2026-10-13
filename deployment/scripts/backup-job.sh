#!/usr/bin/env bash

set -euo pipefail

deployment_config=${FITNESS_DEPLOYMENT_CONFIG:-/etc/fitness-app/deployment.env}

if [[ -f "$deployment_config" ]]; then
  # This file is owned by the production host and contains non-secret settings.
  source "$deployment_config"
fi

data_root=${FITNESS_DATA_ROOT:-/srv/fitness-app}
source_path=$data_root/source

"$source_path/deployment/scripts/backup.sh" daily
"$source_path/deployment/scripts/replicate-backups.sh"
