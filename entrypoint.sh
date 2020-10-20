#!/bin/bash

set -e

if [[ -n "$SSH_PRIVATE_KEY" ]]; then
  echo "Setting ssh key"
  mkdir -p /root/.ssh
  echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
fi

mkdir -p ~/.ssh
cp /root/.ssh/* ~/.ssh/ 2> /dev/null || true


SOURCE_REPO="${INPUT_SOURCE_REPO}"
DESTINATION_REPO="${INPUT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"

echo "SOURCE=$SOURCE_REPO"
echo "DESTINATION=$DESTINATION_REPO"

if [ ! -d "$CACHE_PATH" ]; then
  mkdir -p "$CACHE_PATH"
fi
cd "$CACHE_PATH"

git clone --mirror "$SOURCE_REPO" && cd "$(basename "$SOURCE_REPO")"
git remote set-url --push origin "$DESTINATION_REPO"
git fetch -p origin
# Exclude refs created by GitHub for pull request.
git for-each-ref --format 'delete %(refname)' refs/pull | git update-ref --stdin
git push --mirror