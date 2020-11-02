#!/usr/bin/env bash

set -e

SOURCE_REPO="${INPUT_SOURCE_REPO}"
DESTINATION_REPO="${INPUT_DESTINATION_REPO}"
#FORCE_CREAT_DESTINATION_REPO="${INPUT_FORCE_CREAT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"

SOURCE_REPO_DIR="$(basename "$SOURCE_REPO")"

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

ssh_config() {
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
}

# 打印传入参数的值
print_var_info() {
    echo_color yellow "<-------------------parameter info BEGIN------------------->"
    echo "SOURCE_REPO=$SOURCE_REPO"
    echo "DESTINATION_REPO=$DESTINATION_REPO"
    echo "SOURCE_REPO_DIR=$SOURCE_REPO_DIR"
    echo "CACHE_PATH=$CACHE_PATH"
    echo_color yellow "<-------------------parameter info END------------------->\n"
}

# 判断字符串中是否含有空格
check_spaces_in_string() {
    if [[ "$1" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
    then
        echo_color red "There are spaces in the string: $1."
        exit 0
    else
        echo_color green "There are not spaces in the string: $1."
    fi
}

# 删除字符串前后空格
trim_spaces_around_string() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}

# 判断 url 是哪个 hub(github or gitee) 类型的
check_hub_type_for_url() {
    local url_hub_type
    if [[ "$1" == https://gitee.com/* ]]; then
        url_hub_type="gitee"
    elif [[ "$1" == git@gitee.com:* ]]; then
        url_hub_type="gitee"
    elif [[ "$1" == https://github.com/* ]]; then
        url_hub_type="github"
    elif [[ "$1" == git@github.com:* ]]; then
        url_hub_type="github"
    else
        echo_color red "$1 is unknow the hub type."
        exit 0
    fi

    echo "$url_hub_type"
}

# 判断 url 是哪个协议认证(HTTPS or SSH) 类型
check_protocol_type_for_url() {
    local url_protocol_type
    if [[ "$1" == https://gitee.com/* ]]; then
        url_protocol_type="HTTPS"
    elif [[ "$1" == git@gitee.com:* ]]; then
        url_protocol_type="SSH"
    elif [[ "$1" == https://github.com/* ]]; then
        url_protocol_type="HTTPS"
    elif [[ "$1" == git@github.com:* ]]; then
        url_protocol_type="SSH"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    echo "$url_protocol_type"
}

# 获取 url 的用户名
get_username_from_url() {
    local ownername_reponame_maybe_dotgit_in_repourl
    local hub_username
    if [[ "$1" == https://gitee.com/* ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#https://gitee.com/}"
    elif [[ "$1" == git@gitee.com:* ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#git@gitee.com:}"
    elif [[ "$1" == https://github.com/* ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#https://github.com/}"
    elif [[ "$1" == git@github.com:* ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#git@github.com:}"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    hub_username="${ownername_reponame_maybe_dotgit_in_repourl%/*}"
    echo "$hub_username"
}

# 获取 url 的仓库名
get_reponame_from_url() {
    local ownername_reponame_dotgit_in_repourl
    local ownername_reponame_in_repourl
    local hub_reponame
    # =~：左侧是字符串，右侧是一个模式，判断左侧的字符串能否被右侧的模式所匹配：通常只在 [[ ]] 中使用, 模式中可以使用行首、行尾锚定符，但是模式不要加引号。
    if [[ "$1" =~ ^https://gitee.com/.*\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#https://gitee.com/}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" == https://gitee.com/* ]]; then
        ownername_reponame_in_repourl="${1#https://gitee.com/}"
    elif [[ "$1" =~ ^git@gitee.com:.*\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#git@gitee.com:}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" == git@gitee.com:* ]]; then
        ownername_reponame_in_repourl="${1#git@gitee.com:}"
    elif [[ "$1" =~ ^https://github.com/.*\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#https://github.com/}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" == https://github.com/* ]]; then
        ownername_reponame_in_repourl="${1#https://github.com/}"
    elif [[ "$1" =~ ^git@github.com:.*\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#git@github.com:}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" == git@github.com:* ]]; then
        ownername_reponame_in_repourl="${1#git@github.com:}"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    hub_reponame="${ownername_reponame_in_repourl#/*}"
    echo "$hub_reponame"
}

# 判断 github 上的用户名是否合法
check_validity_for_username_adapt_github() {
    :
}

# 判断 gitee 上的用户名是否合法
check_validity_for_username_adapt_gitee() {
    # gitee 账户名只允许字母、数字或者下划线（_）、中划线（-），至少 2 个字符，必须以字母开头，不能以特殊字符结尾。
    if echo "$1" | grep -Eq "^[a-zA-Z][a-zA-Z0-9_-]{1,}$"; then
        echo_color green "Gitee repo: The format of the userName:$1 is right."
    else
        echo_color red "Gitee repo: The format of the userName:$1 is wrong."
        exit 0
    fi
}

# 判断 github 上的仓库名是否合法
check_validity_for_reponame_adapt_github() {
    # github 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，开头符合前面条件即可，长度至少为1个字符。
    # 注意，github 仓库名不能是一个或者两个英文句号(.)，可以为至少三个英文句号(.)。
    if [[ "$1" == "." ]] || [[ "$1" == ".." ]]; then
        echo_color red "Github repo: The format of the repoName:$1 is wrong."
        exit 0
    else
        if echo "$1" | grep -Eq "^[a-zA-Z0-9._-][a-zA-Z0-9._-]*$"; then
            echo_color green "Github repo: The format of the repoName:$1 is right."
        else
            echo_color red "Github repo: The format of the repoName:$1 is wrong."
            exit 0
        fi
    fi
}

# 判断 gitee 上的仓库名是否合法
check_validity_for_reponame_adapt_gitee() {
    # gitee 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符。
    if echo "$1" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
        echo_color green "Gitee repo: The format of the repoName:$1 is right."
    else
        echo_color red "Gitee repo: The format of the repoName:$1 is wrong."
        exit 0
    fi
}

# 判断 url 作为远程仓库是否存在于 hub 上
check_existence_for_url_on_hub() {
    # 使用 `git ls-remote <repo_url>` 来检查仓库是否存在，repo_url 使用 SSH 方式
    # 该方法需要使用到 SSH 密钥对，比较方便。
    if { git ls-remote "$1" > /dev/null; } 2>&1; then
        echo_color green "$1 is existed as a remote repo on Hub"
    else
        echo_color red "$1 is not existed as a remote repo on Hub"
        exit 0
    fi
}

check_overall_validity_for_url() {
    local url_hub_type
    #local url_protocol_type
    local url_username
    local url_reponame
    url_hub_type="$(check_hub_type_for_url "$1")"
    #url_protocol_type="$(check_protocol_type_for_url "$1")"
    url_username="$(get_username_from_url "$1")"
    url_reponame="$(get_reponame_from_url "$1")"
    echo "$url_hub_type"
    echo "$url_username"
    echo "$url_reponame"

    check_spaces_in_string "$1"

    if [[ "$url_hub_type" == "gitee" ]]; then
        check_validity_for_username_adapt_gitee "$url_username"
        check_validity_for_reponame_adapt_gitee "$url_reponame"
    elif [[ "$url_hub_type" == "github" ]]; then
        check_validity_for_reponame_adapt_github "$url_reponame"
    fi

    check_existence_for_url_on_hub "$1"
}

# 判断当前目录是否为有效的 git 仓库。
check_validity_for_current_dir_as_git_repo() {
    local repo_remote_url_for_fetch_with_fuzzy_match
    local repo_remote_url_for_fetch_with_exact_match

    # git clone --mirror 克隆下来的为纯仓库。
    # git rev-parse --is-inside-work-tree 判断是否为非纯的普通仓库。
    # git rev-parse --is-bare-repository 判断是否为纯仓库（或者叫裸仓库）。
    if [ "$(git rev-parse --is-inside-work-tree)" = "true" ] || [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
        echo_color green "current dir is a git repo!"
        # 模糊匹配，获取到的字符串前后可能有空格。
        # 此处有问题，GitHub action 使用的 ubuntu-latest 中的 grep 没有 -P 选项，而 -E 选项又不支持 (?<=origin).*(?=\(fetch\))，该问题待解决
        #repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | grep -Po "(?<=origin).*(?=\(fetch\))")
        repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk '/^origin.+\(fetch\)$/ {print $2}')
        echo "$repo_remote_url_for_fetch_with_fuzzy_match"
        # 精确匹配，删除字符串前后空格。
        repo_remote_url_for_fetch_with_exact_match=$(trim_spaces_around_string "$repo_remote_url_for_fetch_with_fuzzy_match")
        echo "$repo_remote_url_for_fetch_with_exact_match"
        if [[ "$repo_remote_url_for_fetch_with_exact_match" == "$1" ]]; then
            echo_color green "The repo url of pre-fetch matches the src repo url."
        else
            echo_color yellow "The repo url of pre-fetch dose not matches the src repo url."
        fi
    else
        echo_color yellow "current dir is not a git repo!"
    fi
}


# main 函数
entrypoint_main() {
    echo "main"
    print_var_info
    
    ssh_config

    check_overall_validity_for_url "$SOURCE_REPO"
    check_overall_validity_for_url "$DESTINATION_REPO"

    if [ ! -d "$CACHE_PATH" ]; then
        mkdir -p "$CACHE_PATH"
    fi
    cd "$CACHE_PATH"
    
    check_validity_for_current_dir_as_git_repo "$SOURCE_REPO"
}

# 入口
entrypoint_main "$@"
