#!/usr/bin/env bash

set -e

# 提示语句字体颜色设置
echo_color() {
    case $1 in
    red)
        echo -e "\033[31m$2\033[0m"
        ;;
    green)
        echo -e "\033[32m$2\033[0m"
        ;;
    yellow)
        echo -e "\033[33m$2\033[0m"
        ;;
    blue)
        echo -e "\033[34m$2\033[0m"
        ;;
    esac
}

#SSH_PRIVATE_KEY="${INPUT_SSH_PRIVATE_KEY}"

if [ -n "$SSH_PRIVATE_KEY" ]; then
    echo_color green "Setting SSH key"
    mkdir -p /root/.ssh
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
else
    echo_color red "SSH_PRIVATE_KEY is empty!"
fi

mkdir -p ~/.ssh
cp /root/.ssh/* ~/.ssh/ 2> /dev/null || true


SOURCE_REPO="${INPUT_SOURCE_REPO}"
DESTINATION_REPO="${INPUT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"

SOURCE_REPO_DIR="$(basename "$SOURCE_REPO")"

echo "SOURCE_REPO=$SOURCE_REPO"
echo "DESTINATION_REPO=$DESTINATION_REPO"
echo "SOURCE_REPO_DIR=$SOURCE_REPO_DIR"

# 判断字符串中是否含有空格
find_space_in_string() {
    if [[ "$1" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
    then
        echo_color red "There are spaces in the repo url: $1."
        exit 0
    else
        echo_color green "There are not spaces in the repo url: $1."
    fi
}

# 删除字符串前后空格
trim_string() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

# 判断是否为合法的 hub url。
# is_legal_hub_url() {
#     local repo_type
#     # 检查传入的仓库的 url 是否是 GitHub 或者 Gitee 链接，不是则退出。
#     if [[ "$1" == https://gitee.com/* ]]; then
#         echo_color green "$1 is a gitee url."
#         repo_type="gitee"
#         #ownername_reponame_in_repourl="${repo_url#https://gitee.com/}"
#     elif [[ "$1" == git@gitee.com:* ]]; then
#         echo_color green "$1 is a gitee url."
#         repo_type="gitee"
#         #ownername_reponame_in_repourl="${repo_url#git@gitee.com:}"
#     elif [[ "$1" == https://github.com/* ]]; then
#         echo_color green "$1 is a github url."
#         repo_type="github"
#         #ownername_reponame_in_repourl="${repo_url#https://github.com/}"
#     elif [[ "$1" == git@github.com:* ]]; then
#         echo_color green "$1 is a github url."
#         repo_type="github"
#         #ownername_reponame_in_repourl="${repo_url#git@github.com:}"
#     else
#         echo_color red "$1 is unknow the type."
#         exit 0
#     fi

#     # 判断传入的仓库的 url 中最后的仓库名称格式是否正确，不正确则退出。
#     if [[ "$repo_type" == "gitee" ]]; then
#         # 必须以字母或数字或点号或下划线开头：[a-zA-Z0-9._]*
#         # gitee 仓库路径只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符
#         if echo "${1##*/}" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
#             echo_color green "gitee repo: The format of the repoName:${1##*/} is right."
#         else
#             echo_color red "gitee repo: The format of the repoName:${1##*/} is wrong."
#             exit 0
#         fi
#     elif [[ "$repo_type" == "github" ]]; then
#         # github 仓库必须以点号或者字母开头
#         if echo "${1##*/}" | grep -Eq "^[.a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
#             echo_color green "github repo: The format of the repoName:${1##*/} is right."
#         else
#             echo_color red "github repo: The format of the repoName:${1##*/} is wrong."
#             exit 0
#         fi
#     fi
# }

is_legal_hub_url() {
    local repo_url_var="$1"
    local repo_url_value="${!repo_url_var}"
    local repo_type
    # 检查传入的仓库的 url 是否是 GitHub 或者 Gitee 链接，不是则退出。
    if [[ "$repo_url_value" == https://gitee.com/* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a gitee url."
        repo_type="gitee"
        #ownername_reponame_in_repourl="${repo_url#https://gitee.com/}"
    elif [[ "$repo_url_value" == git@gitee.com:* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a gitee url."
        repo_type="gitee"
        #ownername_reponame_in_repourl="${repo_url#git@gitee.com:}"
    elif [[ "$repo_url_value" == https://github.com/* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a github url."
        repo_type="github"
        #ownername_reponame_in_repourl="${repo_url#https://github.com/}"
    elif [[ "$repo_url_value" == git@github.com:* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a github url."
        repo_type="github"
        #ownername_reponame_in_repourl="${repo_url#git@github.com:}"
    else
        echo_color red "$repo_url_var: $repo_url_value is unknow the type."
        exit 0
    fi

    # 判断传入的仓库的 url 中最后的仓库名称格式是否正确，不正确则退出。
    if [[ "$repo_type" == "gitee" ]]; then
        # 必须以字母或数字或点号或下划线开头：[a-zA-Z0-9._]*
        # gitee 仓库路径只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符
        if echo "${repo_url_value##*/}" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
            echo_color green "$repo_url_var with Gitee repo: The format of the repoName:${repo_url_value##*/} is right."
        else
            echo_color red "$repo_url_var with Gitee repo: The format of the repoName:${repo_url_value##*/} is wrong."
            exit 0
        fi
    elif [[ "$repo_type" == "github" ]]; then
        # github 仓库必须以点号或者字母开头
        if echo "${repo_url_value##*/}" | grep -Eq "^[.a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
            echo_color green "$repo_url_var with Github repo: The format of the repoName:${repo_url_value##*/} is right."
        else
            echo_color red "$repo_url_var with Github repo: The format of the repoName:${repo_url_value##*/} is wrong."
            exit 0
        fi
    fi
}

# 检查传入的仓库的 url 中是否存在空格，存在则退出。
find_space_in_string "$SOURCE_REPO"
find_space_in_string "$DESTINATION_REPO"

# is_legal_hub_url "$SOURCE_REPO"
# is_legal_hub_url "$DESTINATION_REPO"

is_legal_hub_url SOURCE_REPO
is_legal_hub_url DESTINATION_REPO


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
        echo_color green "$SOURCE_REPO_DIR is a git repo!"
        # 模糊匹配，获取到的字符串前后可能有空格。
        # 此处有问题，GitHub action 使用的 ubuntu-latest 中的 grep 没有 -P 选项，而 -E 选项又不支持 (?<=origin).*(?=\(fetch\))，该问题待解决
        #get_repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | grep -Po "(?<=origin).*(?=\(fetch\))")
        get_repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk -F '[ ]+' '{print $1}')
        echo "$get_repo_remote_url_for_fetch_with_fuzzy_match"
        # 精确匹配，删除字符串前后空格。
        get_repo_remote_url_for_fetch_with_exact_match=$(trim_string "$get_repo_remote_url_for_fetch_with_fuzzy_match")
        echo "$get_repo_remote_url_for_fetch_with_exact_match"
        if [[ "$get_repo_remote_url_for_fetch_with_exact_match" == "$SOURCE_REPO" ]]; then
            echo_color green "The repo url of pre-fetch matches the src repo url."
        else
            echo_color yellow "The repo url of pre-fetch dose not matches the src repo url."
            cd .. && rm -rf "$SOURCE_REPO_DIR"
            git clone --mirror "$SOURCE_REPO" && cd "$SOURCE_REPO_DIR"
        fi
    else
        echo_color yellow "$SOURCE_REPO_DIR is not a git repo!"
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