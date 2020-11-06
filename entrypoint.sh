#!/usr/bin/env bash

ERREXIT_FLAG="${INPUT_ERREXIT_FLAG}"
XTRACE_DEBUG="${INPUT_XTRACE_DEBUG}"

if [[ "$ERREXIT_FLAG" == "true" ]]; then
  set -e
fi

if [[ "$XTRACE_DEBUG" == "true" ]]; then
  set -x
fi

# ENV: GITHUB_ACCESS_TOKEN GITEE_ACCESS_TOKEN SSH_PRIVATE_KEY
SRC_REPO_URL="${INPUT_SRC_REPO_URL}"
DST_REPO_URL="${INPUT_DST_REPO_URL}"
#FORCE_CREAT_DESTINATION_REPO="${INPUT_FORCE_CREAT_DESTINATION_REPO}"
CACHE_PATH="${INPUT_CACHE_PATH}"
REQUEST_TOOL="${INPUT_REQUEST_TOOL}"
SRC_REPO_DIR_MAYBE_DOTGIT_OF_URL="$(basename "$SRC_REPO_URL")"

# 提示语句字体颜色设置
echo_color() {
    case $1 in
    black)
        echo -e "\033[30m$2\033[0m"
        ;;
    red)    # error
        echo -e "\033[31m$2\033[0m"
        ;;
    green)  # success
        echo -e "\033[32m$2\033[0m"
        ;;
    yellow) # warn
        echo -e "\033[33m$2\033[0m"
        ;;
    blue)   # highlight info，突出信息显示
        echo -e "\033[34m$2\033[0m"
        ;;
    purple) # borderline，边界线
        echo -e "\033[35m$2\033[0m"
        ;;
    cyan)   # info，普通信息显示
        echo -e "\033[36m$2\033[0m"
        ;;
    white)
        echo -e "\033[37m$2\033[0m"
        ;;
    esac
}

ssh_config() {
    if [ -n "$SSH_PRIVATE_KEY" ]; then
        echo_color cyan "Setting SSH key\n"
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
    echo "ERREXIT_FLAG=$ERREXIT_FLAG"
    echo "XTRACE_DEBUG=$XTRACE_DEBUG"
    echo "SRC_REPO_URL=$SRC_REPO_URL"
    echo "DST_REPO_URL=$DST_REPO_URL"
    echo "SRC_REPO_DIR_OF_URL=$SRC_REPO_DIR_MAYBE_DOTGIT_OF_URL"
    echo "CACHE_PATH=$CACHE_PATH"
    echo "REQUEST_TOOL=$REQUEST_TOOL"
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
    if [[ "$1" =~ ^https://gitee.com/.+ ]]; then
        url_hub_type="gitee"
    elif [[ "$1" =~ ^git@gitee.com:.+ ]]; then
        url_hub_type="gitee"
    elif [[ "$1" =~ ^https://github.com/.+ ]]; then
        url_hub_type="github"
    elif [[ "$1" =~ ^git@github.com:.+ ]]; then
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
    if [[ "$1" =~ ^https://gitee.com/.+ ]]; then
        url_protocol_type="HTTPS"
    elif [[ "$1" =~ ^git@gitee.com:.+ ]]; then
        url_protocol_type="SSH"
    elif [[ "$1" =~ ^https://github.com/.+ ]]; then
        url_protocol_type="HTTPS"
    elif [[ "$1" =~ ^git@github.com:.+ ]]; then
        url_protocol_type="SSH"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    echo "$url_protocol_type"
}

# 获取 url 的仓库拥有者名称，可以是 users（用户） 也可以是 orgs（组织）或者 enterprises（企业）
get_repoowner_from_url() {
    local ownername_reponame_maybe_dotgit_in_repourl
    local hub_repoowner
    if [[ "$1" =~ ^https://gitee.com/.+ ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#https://gitee.com/}"
    elif [[ "$1" =~ ^git@gitee.com:.+ ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#git@gitee.com:}"
    elif [[ "$1" =~ ^https://github.com/.+ ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#https://github.com/}"
    elif [[ "$1" =~ ^git@github.com:.+ ]]; then
        ownername_reponame_maybe_dotgit_in_repourl="${1#git@github.com:}"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    # 或许也可以考虑使用 dirname 命令来得到 repoowner：
    #hub_repoowner="$(dirname "$ownername_reponame_maybe_dotgit_in_repourl")"
    hub_repoowner="${ownername_reponame_maybe_dotgit_in_repourl%/*}"
    echo "$hub_repoowner"
}

# 获取 url 的仓库名
get_reponame_from_url() {
    local ownername_reponame_dotgit_in_repourl
    local ownername_reponame_in_repourl
    local hub_reponame
    # =~：左侧是字符串，右侧是一个模式，判断左侧的字符串能否被右侧的模式所匹配：通常只在 [[ ]] 中使用, 模式中可以使用行首、行尾锚定符，但是模式不要加引号。
    if [[ "$1" =~ ^https://gitee.com/.+\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#https://gitee.com/}"
        # 这里其实可以直接使用 basename 命令来得到 reponame：
        #hub_reponame="$(basename "$ownername_reponame_dotgit_in_repourl" .git)"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" =~ ^https://gitee.com/.+ ]]; then
        ownername_reponame_in_repourl="${1#https://gitee.com/}"
    elif [[ "$1" =~ ^git@gitee.com:.+\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#git@gitee.com:}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" =~ ^git@gitee.com:.+ ]]; then
        ownername_reponame_in_repourl="${1#git@gitee.com:}"
    elif [[ "$1" =~ ^https://github.com/.+\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#https://github.com/}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" =~ ^https://github.com/.+ ]]; then
        ownername_reponame_in_repourl="${1#https://github.com/}"
    elif [[ "$1" =~ ^git@github.com:.+\.git$ ]]; then
        ownername_reponame_dotgit_in_repourl="${1#git@github.com:}"
        ownername_reponame_in_repourl="${ownername_reponame_dotgit_in_repourl%.git*}"
    elif [[ "$1" =~ ^git@github.com:.+ ]]; then
        ownername_reponame_in_repourl="${1#git@github.com:}"
    else
        echo_color red "$1 is unknow the protocol type."
        exit 0
    fi

    # 这里其实可以使用 basename 命令来得到 reponame：
    #hub_reponame="$(basename "$ownername_reponame_in_repourl")"
    hub_reponame="${ownername_reponame_in_repourl##*/}"
    echo "$hub_reponame"
}

# 判断 github 上的仓库拥有者名称是否合法
check_validity_of_repoowner_adapt_github() {
    :
}

# 判断 gitee 上的仓库拥有者名称是否合法
check_validity_of_repoowner_adapt_gitee() {
    # gitee 账户名只允许字母、数字或者下划线（_）、中划线（-），至少 2 个字符，必须以字母开头，不能以特殊字符结尾。
    if echo "$1" | grep -Eq "^[a-zA-Z][a-zA-Z0-9_-]{1,}$"; then
        echo_color green "Gitee repo: The format of the repoowner:$1 is right."
    else
        echo_color red "Gitee repo: The format of the repoowner:$1 is wrong."
        exit 0
    fi
}

# 判断 github 上的仓库名是否合法
check_validity_of_reponame_adapt_github() {
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
check_validity_of_reponame_adapt_gitee() {
    # gitee 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符。
    if echo "$1" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
        echo_color green "Gitee repo: The format of the repoName:$1 is right."
    else
        echo_color red "Gitee repo: The format of the repoName:$1 is wrong."
        exit 0
    fi
}

# 使用 curl 来判断 url 作为远程仓库是否存在于 hub 上
# Example for Gitee:
# Curl
    # curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/kuxiade/docker-arch?access_token=abcdefghijklmnopqrstuvwxyz'
# Request URL
    # https://gitee.com/api/v5/repos/kuxiade/docker-arch?access_token=abcdefghijklmnopqrstuvwxyz
# Example for Github:

check_existence_of_url_for_hub_with_curl() {
    local url_hub_type
    #local url_protocol_type
    local url_repoowner
    local url_reponame
    url_hub_type="$(check_hub_type_for_url "$1")"
    #url_protocol_type="$(check_protocol_type_for_url "$1")"
    url_repoowner="$(get_repoowner_from_url "$1")"
    url_reponame="$(get_reponame_from_url "$1")"
    echo "url_hub_type=$url_hub_type"
    echo "url_repoowner=$url_repoowner"
    echo "url_reponame=$url_reponame"

    if [[ "$url_hub_type" == "gitee" ]]; then
        local request_url_prefix="https://gitee.com/api/v5/repos"
        local access_token="$GITEE_ACCESS_TOKEN"
        local request_url="$request_url_prefix/$url_repoowner/$url_reponame?access_token=$access_token"
        local curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8')
    elif [[ "$url_hub_type" == "github" ]]; then
        local request_url_prefix="https://api.github.com/repos"
        local access_token="$GITHUB_ACCESS_TOKEN"
        local request_url="$request_url_prefix/$url_repoowner/$url_reponame"
        local curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/vnd.github.v3+json' -H "Authorization: token $access_token")
    fi

    echo "request_url = $request_url"

    if type curl > /dev/null 2>&1; then
        # 使用 `curl [-f | --fail] <request_url>` 来检查仓库是否存在
        # 该方法比较麻烦，对私有仓库的判断需要 GitHub 和 Gitee的 access_token，会导致整个操作变得复杂。故，注释掉此处代码，仅供参考。
        local content_get_from_request_url
        if content_get_from_request_url=$(curl "${curl_options[@]}" "$request_url"); then
            exit_status_code_flag=$?
            echo $exit_status_code_flag
            echo "Success"
            #echo "$content_get_from_request_url"

            if type jq > /dev/null 2>&1; then
                repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
            else
                echo_color red "There is no 'jq' command, please install it"
                exit 0
            fi
            
            echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
            echo "\"$url_repoowner/$url_reponame\""
            if [[ "$repo_full_name_get_from_request_url" == "\"$url_repoowner/$url_reponame\"" ]]; then
                echo_color green "$1 is existed as a remote repo on Hub"
            else
                # 占位，除非 Hub 服务器鬼畜了，不然不会出现从 url 获取的 $repo_full_name_get_from_request_url 和 url 中的 "$url_repoowner/$url_reponame" 不一致。
                :
            fi
        else
            exit_status_code_flag=$?
            echo "exit_status_code_flag = $exit_status_code_flag"
            echo "Fail"
            #echo "$content_get_from_request_url"
            if [[ $exit_status_code_flag -eq 22 ]]; then
                echo "HTTP 找不到网页，$1 可能是私有仓库或者不存在该仓库。"
            elif [[ $exit_status_code_flag -eq 7 ]]; then
                echo "$request_url 拒接连接，被目标服务器限流。"
            else
                echo "Curl: exit_status_code_flag = $exit_status_code_flag"
            fi
        fi
    else
        echo_color red "There is no 'curl' command, please install it"
        exit 0
    fi
}

# 使用 git 来判断 url 作为远程仓库是否存在于 hub 上
check_existence_of_url_for_hub_with_git() {
    if type git > /dev/null 2>&1; then
        # 使用 `git ls-remote <repo_url>` 来检查仓库是否存在，repo_url 使用 SSH 方式
        # 该方法需要使用到 SSH 密钥对，比较方便。
        if { git ls-remote "$1" > /dev/null; } 2>&1; then
            echo_color green "$1 is existed as a remote repo on Hub"
        else
            echo_color red "$1 is not existed as a remote repo on Hub"
            exit 0
        fi
    else
        echo_color red "There is no 'git' command, please install it"
        exit 0
    fi
}

# 判断 url 作为远程仓库是否存在于 hub 上
check_existence_of_url_for_hub() {
    echo "$GITEE_ACCESS_TOKEN" "damlsfg"
    echo "$GITHUB_ACCESS_TOKEN" "sjfdkgl"
    if [[ "$url_hub_type" == "curl" ]] && [ -n "$GITEE_ACCESS_TOKEN" ] && [ -n "$GITHUB_ACCESS_TOKEN" ]; then
        echo_color green "use curl"
        check_existence_of_url_for_hub_with_curl "$1"
    elif [[ "$url_hub_type" == "git" ]]; then
        echo_color green "use git"
        check_existence_of_url_for_hub_with_git "$1"
    else
        echo_color yellow "Request tool unknown! must be git or curl."
        exit 0
    fi
}

check_overall_validity_of_url() {
    local url_hub_type
    #local url_protocol_type
    local url_repoowner
    local url_reponame
    url_hub_type="$(check_hub_type_for_url "$1")"
    #url_protocol_type="$(check_protocol_type_for_url "$1")"
    url_repoowner="$(get_repoowner_from_url "$1")"
    url_reponame="$(get_reponame_from_url "$1")"
    echo "url_hub_type=$url_hub_type"
    echo "url_repoowner=$url_repoowner"
    echo "url_reponame=$url_reponame"

    check_spaces_in_string "$1"

    if [[ "$url_hub_type" == "gitee" ]]; then
        check_validity_of_repoowner_adapt_gitee "$url_repoowner"
        check_validity_of_reponame_adapt_gitee "$url_reponame"
    elif [[ "$url_hub_type" == "github" ]]; then
        check_validity_of_reponame_adapt_github "$url_reponame"
    fi

    check_existence_of_url_for_hub "$1"
}

# 判断当前目录是否为有效的 git 仓库。
check_validity_of_current_dir_as_git_repo() {
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
    echo -e ""
    echo_color cyan "------------------> go in entrypoint_main func\n"
    echo_color purple "<-------------------parameter info BEGIN------------------->"
    print_var_info
    echo_color purple "<-------------------parameter info END--------------------->\n"
    
    ssh_config

    echo_color purple "<-------------------SRC_REPO_URL check_overall_validity_of_url BEGIN------------------->"
    check_overall_validity_of_url "$SRC_REPO_URL"
    echo_color purple "<-------------------SRC_REPO_URL check_overall_validity_of_url END--------------------->\n"

    echo_color purple "<-------------------DST_REPO_URL check_overall_validity_of_url BEGIN------------------->"
    check_overall_validity_of_url "$DST_REPO_URL"
    echo_color purple "<-------------------DST_REPO_URL check_overall_validity_of_url END--------------------->\n"

    if [ ! -d "$CACHE_PATH" ]; then
        mkdir -p "$CACHE_PATH"
    fi
    cd "$CACHE_PATH"
    
    if [ -d "$SRC_REPO_DIR_MAYBE_DOTGIT_OF_URL" ] ; then
        cd "$SRC_REPO_DIR_MAYBE_DOTGIT_OF_URL"
        echo_color purple "<-------------------SRC_REPO_URL check_validity_of_current_dir_as_git_repo BEGIN------------------->"
        check_validity_of_current_dir_as_git_repo "$SRC_REPO_URL"
        echo_color purple "<-------------------SRC_REPO_URL check_validity_of_current_dir_as_git_repo END--------------------->\n"
    else
        echo_color red "no $SRC_REPO_DIR_MAYBE_DOTGIT_OF_URL:$SRC_REPO_URL cache\n"
    fi
}

# 入口
entrypoint_main "$@"
