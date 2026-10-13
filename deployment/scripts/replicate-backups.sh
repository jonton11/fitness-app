#!/usr/bin/env bash

set -euo pipefail

deployment_config=${FITNESS_DEPLOYMENT_CONFIG:-/etc/fitness-app/deployment.env}

if [[ -f "$deployment_config" ]]; then
  # This file is owned by the production host and contains non-secret settings.
  source "$deployment_config"
fi

data_root=${FITNESS_DATA_ROOT:-/srv/fitness-app}
backup_directory=${FITNESS_BACKUP_DIRECTORY:-$data_root/backups}
oci_namespace=${OCI_BACKUP_NAMESPACE:-}
oci_bucket=${OCI_BACKUP_BUCKET:-}
oci_prefix=${OCI_BACKUP_PREFIX:-production}

if [[ -z "$oci_namespace" || -z "$oci_bucket" ]]; then
  echo "OCI_BACKUP_NAMESPACE and OCI_BACKUP_BUCKET are required" >&2
  exit 1
fi

if [[ "$oci_prefix" == /* ]]; then
  echo "OCI_BACKUP_PREFIX must be relative" >&2
  exit 1
fi

if ! command -v oci >/dev/null 2>&1; then
  echo "OCI CLI is required to replicate backups" >&2
  exit 1
fi

if ! compgen -G "$backup_directory/*.dump" >/dev/null; then
  echo "No verified database backups found in $backup_directory" >&2
  exit 1
fi

object_prefix=${oci_prefix%/}/

oci os object sync \
  --auth instance_principal \
  --namespace-name "$oci_namespace" \
  --bucket-name "$oci_bucket" \
  --src-dir "$backup_directory" \
  --prefix "$object_prefix" \
  --include '*.dump' \
  --no-multipart \
  --no-follow-symlinks
