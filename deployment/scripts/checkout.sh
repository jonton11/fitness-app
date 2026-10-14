#!/usr/bin/env bash

set -euo pipefail

commit_sha=${1:-}
repository_url=${2:-}
source_path=${3:-}

if [[ ! "$commit_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Commit SHA must be 40 lowercase hexadecimal characters" >&2
  exit 1
fi

if [[ -z "$repository_url" || -z "$source_path" ]]; then
  echo "Usage: checkout.sh COMMIT_SHA REPOSITORY_URL SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -d "$source_path/.git" ]]; then
  if [[ -e "$source_path" ]]; then
    echo "Deployment source path exists but is not a Git checkout: $source_path" >&2
    exit 1
  fi

  git clone "$repository_url" "$source_path"
fi

cd "$source_path"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Deployment checkout has local changes; refusing to overwrite them" >&2
  exit 1
fi

git remote set-url origin "$repository_url"
git fetch --prune origin main

if ! git cat-file -e "${commit_sha}^{commit}" 2>/dev/null; then
  echo "Requested commit is not available from the deployment repository: $commit_sha" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$commit_sha" origin/main; then
  echo "Requested commit is not reachable from origin/main: $commit_sha" >&2
  exit 1
fi

git checkout --detach --force "$commit_sha"

checked_out_commit=$(git rev-parse HEAD)
if [[ "$checked_out_commit" != "$commit_sha" ]]; then
  echo "Deployment checkout does not match requested commit" >&2
  exit 1
fi
