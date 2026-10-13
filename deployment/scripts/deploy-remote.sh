#!/usr/bin/env bash

set -euo pipefail

commit_sha=${1:-}

if [[ ! "$commit_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Usage: deploy-remote.sh COMMIT_SHA" >&2
  exit 1
fi

repository_root=$(git rev-parse --show-toplevel)
operator_config=${FITNESS_OPERATOR_CONFIG:-$HOME/.config/fitness-app/operator.env}

if [[ -n "${FITNESS_OPERATOR_CONFIG:-}" && ! -f "$operator_config" ]]; then
  echo "Operator configuration file not found: $operator_config" >&2
  exit 1
fi

if [[ -f "$operator_config" ]]; then
  # This file is owned by the operator and identifies the private SSH target.
  source "$operator_config"
fi

ssh_target=${FITNESS_PRODUCTION_SSH_TARGET:-}
deployment_repository_url=${FITNESS_DEPLOY_REPOSITORY_URL:-}

if [[ ! "$ssh_target" =~ ^[A-Za-z0-9._@-]+$ ]]; then
  echo "FITNESS_PRODUCTION_SSH_TARGET must be an SSH host alias or user@hostname" >&2
  exit 1
fi

if [[ "$deployment_repository_url" != https://* || "$deployment_repository_url" =~ [[:space:]] ]]; then
  echo "FITNESS_DEPLOY_REPOSITORY_URL must be a public HTTPS Git repository URL" >&2
  exit 1
fi

for command in git scp ssh; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required for remote deployment" >&2
    exit 1
  fi
done

git -C "$repository_root" fetch --quiet origin main

current_commit=$(git -C "$repository_root" rev-parse HEAD)
main_commit=$(git -C "$repository_root" rev-parse refs/remotes/origin/main)

if [[ "$commit_sha" != "$current_commit" || "$commit_sha" != "$main_commit" ]]; then
  echo "Deployment commit must match the checked-out tip of origin/main" >&2
  exit 1
fi

if ! git -C "$repository_root" diff --quiet "$commit_sha" -- \
  deployment/scripts/deploy-remote.sh \
  deployment/scripts/deploy.sh \
  deployment/scripts/checkout.sh; then
  echo "Deployment scripts have local changes; refusing to upload them" >&2
  exit 1
fi

remote_directory=.local/lib/fitness-app
remote_deploy_script=$remote_directory/deploy.sh
remote_checkout_script=$remote_directory/checkout.sh

ssh "$ssh_target" "install -d -m 700 '$remote_directory'"
scp \
  "$repository_root/deployment/scripts/deploy.sh" \
  "$repository_root/deployment/scripts/checkout.sh" \
  "$ssh_target:$remote_directory/"

printf -v remote_command 'chmod 700 %q %q && %q %q %q' \
  "$remote_deploy_script" \
  "$remote_checkout_script" \
  "$remote_deploy_script" \
  "$commit_sha" \
  "$deployment_repository_url"
ssh "$ssh_target" "$remote_command"
