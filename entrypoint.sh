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
FORCE_CREAT_DESTINATION_REPO="${INPUT_FORCE_CREAT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"

SOURCE_REPO_DIR="$(basename "$SOURCE_REPO")"

echo_color yellow "<-------------------parameter info BEGIN------------------->"
echo "SOURCE_REPO=$SOURCE_REPO"
echo "DESTINATION_REPO=$DESTINATION_REPO"
echo "SOURCE_REPO_DIR=$SOURCE_REPO_DIR"
echo "CACHE_PATH=$CACHE_PATH"
echo_color yellow "<-------------------parameter info END------------------->\n"


# 删除字符串前后空格
trim_string() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

# 判断是否为合法的 hub url。
is_legal_hub_url() {
    local repo_url_var="$1"
    local repo_url_value="${!repo_url_var}"
    local hub_type
    local protocol_type
    local repo_url_with_ssh

    # 判断字符串中是否含有空格
    if [[ "$1" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
    then
        echo_color red "There are spaces in the $repo_url_var repo url: $repo_url_value."
        exit 0
    else
        echo_color green "There are not spaces in the $repo_url_var repo url: $repo_url_value."
    fi

    # 检查传入的仓库的 url 是否是 GitHub 或者 Gitee 链接，不是则退出。
    if [[ "$repo_url_value" == https://gitee.com/* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a gitee url."
        hub_type="gitee"
        protocol_type="HTTPS"
        ownername_reponame_dotgit_in_repourl="${repo_url_value#https://gitee.com/}"
        repo_url_with_ssh="git@gitee.com:$ownername_reponame_dotgit_in_repourl"
    elif [[ "$repo_url_value" == git@gitee.com:* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a gitee url."
        hub_type="gitee"
        protocol_type="SSH"
        ownername_reponame_dotgit_in_repourl="${repo_url_value#git@gitee.com:}"
        repo_url_with_ssh="$repo_url_value"
    elif [[ "$repo_url_value" == https://github.com/* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a github url."
        hub_type="github"
        protocol_type="HTTPS"
        ownername_reponame_dotgit_in_repourl="${repo_url_value#https://github.com/}"
        repo_url_with_ssh="git@github.com:$ownername_reponame_dotgit_in_repourl"
    elif [[ "$repo_url_value" == git@github.com:* ]]; then
        echo_color green "$repo_url_var: $repo_url_value is a github url."
        hub_type="github"
        protocol_type="SSH"
        ownername_reponame_dotgit_in_repourl="${repo_url_value#git@github.com:}"
        repo_url_with_ssh="$repo_url_value"
    else
        echo_color red "$repo_url_var: $repo_url_value is unknow the type."
        exit 0
    fi

    # 判断传入的仓库的 url 中用户名和仓库名的格式是否正确，不正确则退出。
    if [[ "$hub_type" == "gitee" ]]; then
        local request_url_prefix="https://gitee.com/api/v5/repos"
        # gitee 账户名只允许字母、数字或者下划线（_）、中划线（-），至少 2 个字符，必须以字母开头，不能以特殊字符结尾。
        if echo "${ownername_reponame_dotgit_in_repourl%/*}" | grep -Eq "^[a-zA-Z][a-zA-Z0-9_-]{1,}$"; then
            echo_color green "$repo_url_var with Gitee repo: The format of the userName:${ownername_reponame_dotgit_in_repourl%/*} is right."
        else
            echo_color red "$repo_url_var with Gitee repo: The format of the userName:${ownername_reponame_dotgit_in_repourl%/*} is wrong."
            exit 0
        fi
        # gitee 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符。
        if echo "${ownername_reponame_dotgit_in_repourl#*/}" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}\.git$"; then
            echo_color green "$repo_url_var with Gitee repo: The format of the repoName.git:${ownername_reponame_dotgit_in_repourl#*/} is right."
            ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%*.git}"
            echo "ownername_reponame_in_repourl= $ownername_reponame_in_repourl"
        else
            echo_color red "$repo_url_var with Gitee repo: The format of the repoName.git:${ownername_reponame_dotgit_in_repourl#*/} is wrong."
            exit 0
        fi
    elif [[ "$hub_type" == "github" ]]; then
        local request_url_prefix="https://api.github.com/repos"
        # github 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，开头符合前面条件即可，长度至少为1个字符。
        # 注意，github 仓库名不能是一个或者两个英文句号(.)，可以为至少三个英文句号(.)。
        if [[ "${ownername_reponame_dotgit_in_repourl#*/}" == "." ]] || [[ "${ownername_reponame_dotgit_in_repourl#*/}" == ".." ]]; then
            echo_color red "$repo_url_var with Github repo: The format of the repoName.git:${repo_url_value##*/} is wrong."
            exit 0
        else
            if echo "${ownername_reponame_dotgit_in_repourl#*/}" | grep -Eq "^[a-zA-Z0-9._-][a-zA-Z0-9._-]*\.git$"; then
                echo_color green "$repo_url_var with Github repo: The format of the repoName.git:${ownername_reponame_dotgit_in_repourl#*/} is right."
                ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%*.git}"
                echo "ownername_reponame_in_repourl= $ownername_reponame_in_repourl"
            else
                echo_color red "$repo_url_var with Github repo: The format of the repoName.git:${ownername_reponame_dotgit_in_repourl#*/} is wrong."
                exit 0
            fi
        fi
    fi

    # 使用 `git ls-remote <repo_url>` 来检查仓库是否存在，repo_url 使用 SSH 方式
    # 该方法需要使用到 SSH 密钥对，比较方便。
    if { git ls-remote "$repo_url_with_ssh" > /dev/null; } 2>&1; then
        echo_color green "$repo_url_var: $repo_url_with_ssh is existed"
    else
        echo_color red "$repo_url_var: $repo_url_with_ssh is not existed"
        exit 0
    fi

    # # 使用 `curl [-f | --fail] <request_url>` 来检查仓库是否存在
    # # 该方法比较麻烦，对私有仓库的判断需要 GitHub 和 Gitee的 access_token，会导致整个操作变得复杂。故，注释掉此处代码，仅供参考。
    # local request_url="$request_url_prefix"/"$ownername_reponame_in_repourl"
    # echo "request_url = $request_url"
    # if content_get_from_request_url=$(curl -f "$request_url"); then
    #     exit_status_code_flag=$?
    #     echo $exit_status_code_flag
    #     echo "Success"
    #     #echo "$content_get_from_request_url"
    #     repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
    #     echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
    #     echo "\"$ownername_reponame_in_repourl\""
    #     if [[ "$repo_full_name_get_from_request_url" == "\"$ownername_reponame_in_repourl\"" ]]; then
    #         echo_color green "$repo_url_var: $repo_url_value is existed"
    #     else
    #         # 占位，除非GitHub服务器鬼畜了，不然不会出现从 url 获取的 $repo_full_name_get_from_request_url 和 url 中的 "$ownername_reponame_in_repourl" 不一致
    #         :
    #     fi
    # else
    #     exit_status_code_flag=$?
    #     echo "exit_status_code_flag = $exit_status_code_flag"
    #     echo "Fail"
    #     #echo "$content_get_from_request_url"
    #     if [[ $exit_status_code_flag -eq 22 ]]; then
    #         echo "HTTP 找不到网页，url可能是私有仓库或者不存在该仓库。"
    #     elif [[ $exit_status_code_flag -eq 7 ]]; then
    #         echo "url拒接连接，被目标服务器限流。"
    #     else
    #         echo "Curl: exit_status_code_flag = $exit_status_code_flag"
    #     fi
    # fi
}


# 判断是否为合法的 hub url。
echo_color yellow "<-------------------SOURCE_REPO is_legal_hub_url BEGIN------------------->"
is_legal_hub_url SOURCE_REPO
echo_color yellow "<-------------------SOURCE_REPO is_legal_hub_url END------------------->\n"

echo_color yellow "<-------------------DESTINATION_REPO is_legal_hub_url BEGIN------------------->"
is_legal_hub_url DESTINATION_REPO
echo_color yellow "<-------------------DESTINATION_REPO is_legal_hub_url END------------------->\n"


if [ ! -d "$CACHE_PATH" ]; then
    mkdir -p "$CACHE_PATH"
fi
cd "$CACHE_PATH"
echo "============ ls -la BEGIN ================"
echo "ls -la CACHE_PATH"
ls -la
echo "============ ls -la END ================"
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
        get_repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk '/^origin.+\(fetch\)$/ {print $2}')
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