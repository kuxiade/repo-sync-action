#!/usr/bin/env bash

set -e


SSH_PRIVATE_KEY="${INPUT_SSH_PRIVATE_KEY}"

if [ -n "$SSH_PRIVATE_KEY" ]; then
    echo "Setting ssh key"
    mkdir -p /root/.ssh
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
else
    echo "SSH_PRIVATE_KEY is empty!"
fi

mkdir -p ~/.ssh
cp /root/.ssh/* ~/.ssh/ 2> /dev/null || true


SOURCE_REPO="${INPUT_SOURCE_REPO}"
DESTINATION_REPO="${INPUT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"

SOURCE_REPO_DIR="$(basename "$SOURCE_REPO")"

echo "SOURCE=$SOURCE_REPO"
echo "DESTINATION=$DESTINATION_REPO"

if [ ! -d "$CACHE_PATH" ]; then
    mkdir -p "$CACHE_PATH"
fi
cd "$CACHE_PATH"

if [ -d "$SOURCE_REPO_DIR" ] ; then
    cd "$SOURCE_REPO_DIR"
    # 判断当前目录（此处为"$SOURCE_REPO_DIR"）是否为有效的 git 仓库。
    # git clone --mirror 克隆下来的为纯仓库。
    # git rev-parse --is-inside-work-tree 判断是否为非纯的普通仓库。
    # git rev-parse --is-bare-repository 判断是否为纯仓库（或者叫裸仓库）。
    if [ "$(git rev-parse --is-inside-work-tree)" = "true" ] || [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
        echo "$SOURCE_REPO_DIR is a git repo!"
    else
        echo "$SOURCE_REPO_DIR is not a git repo!"
        cd .. && rm -rf "$SOURCE_REPO_DIR"
        git clone --mirror "$SOURCE_REPO" && cd "$SOURCE_REPO_DIR"
    fi
else
    git clone --mirror "$SOURCE_REPO" && cd "$SOURCE_REPO_DIR"
fi

git remote set-url --push origin "$DESTINATION_REPO"
git fetch -p origin
# Exclude refs created by GitHub for pull request.
git for-each-ref --format 'delete %(refname)' refs/pull | git update-ref --stdin
git push --mirror