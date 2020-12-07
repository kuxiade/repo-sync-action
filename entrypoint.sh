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
SRC_TO_DST="${INPUT_SRC_TO_DST}"
SRC_REPO_BRANCH="${INPUT_SRC_REPO_BRANCH}"
SRC_REPO_TAG="${INPUT_SRC_REPO_TAG}"
DST_REPO_BRANCH="${INPUT_DST_REPO_BRANCH}"
DST_REPO_TAG="${INPUT_DST_REPO_TAG}"
CACHE_PATH="${INPUT_CACHE_PATH}"

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

        mkdir -p ~/.ssh
        cp /root/.ssh/* ~/.ssh/ 2> /dev/null || true
    else
        echo_color red "SSH_PRIVATE_KEY is empty!"
    fi
}

git_config_info() {

    # git config user.name || echo "failed 'git config user.name'"
    # git config user.email || echo "failed 'git config user.email'"
    git_user_name=$(git config user.name) && { echo_color cyan "user.name=$git_user_name";true; } || echo_color yellow "failed 'git config user.name'"
    git_user_email=$(git config user.email) && { echo_color cyan "user.email=$git_user_email";true; } || echo_color yellow "failed 'git config user.email'"

    # echo_color cyan "user.name=$git_user_name"
    # echo_color cyan "user.email=$git_user_email"
}

# 打印传入参数的值
print_var_info() {
    echo "SRC_TO_DST=$SRC_TO_DST"
    echo "ERREXIT_FLAG=$ERREXIT_FLAG"
    echo "XTRACE_DEBUG=$XTRACE_DEBUG"
    echo "CACHE_PATH=$CACHE_PATH"
}

# 判断字符串中是否含有空格
check_spaces_in_string() {
    if [[ "$1" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
    then
        echo_color red "There are spaces in the string:'$1'."
        exit 1
    else
        echo_color green "There are not spaces in the string:'$1'."
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
        exit 1
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
        exit 1
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
        exit 1
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
        exit 1
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
        echo_color green "Gitee repo: The format of the repoowner:'$1' is right."
    else
        echo_color red "Gitee repo: The format of the repoowner:'$1' is wrong."
        exit 1
    fi
}

# 判断 github 上的仓库名是否合法
check_validity_of_reponame_adapt_github() {
    # github 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，开头符合前面条件即可，长度至少为1个字符。
    # 注意，github 仓库名不能是一个或者两个英文句号(.)，可以为至少三个英文句号(.)。
    if [[ "$1" == "." ]] || [[ "$1" == ".." ]]; then
        echo_color red "Github repo: The format of the repoName:'$1' is wrong."
        exit 1
    else
        if echo "$1" | grep -Eq "^[a-zA-Z0-9._-][a-zA-Z0-9._-]*$"; then
            echo_color green "Github repo: The format of the repoName:'$1' is right."
        else
            echo_color red "Github repo: The format of the repoName:'$1' is wrong."
            exit 1
        fi
    fi
}

# 判断 gitee 上的仓库名是否合法
check_validity_of_reponame_adapt_gitee() {
    # gitee 仓库名只允许包含字母、数字或者下划线(_)、中划线(-)、英文句号(.)，必须以字母开头，且长度为2~191个字符。
    if echo "$1" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}$"; then
        echo_color green "Gitee repo: The format of the repoName:'$1' is right."
    else
        echo_color red "Gitee repo: The format of the repoName:'$1' is wrong."
        exit 1
    fi
}

# 使用 curl 来判断 url 作为远程仓库是否存在于 hub 上
# 注意，非授权用户使用 curl 访问 https://gitee.com/api/v5/*** 或者 https://api.github.com/*** 有次数限制，故不推荐该方法。
# Example for Gitee:
# Curl
    # curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/kuxiade/docker-arch?access_token=abcdefghijklmnopqrstuvwxyz'
# Request URL
    # https://gitee.com/api/v5/repos/kuxiade/docker-arch?access_token=abcdefghijklmnopqrstuvwxyz
# Example for Github:

check_existence_of_url_for_hub_with_curl() {
    local hub_repo_url_var="$1"
    local hub_repo_url_value="${!hub_repo_url_var}"

    local url_hub_type
    #local url_protocol_type
    local url_repoowner
    local url_reponame
    url_hub_type="$(check_hub_type_for_url "$hub_repo_url_value")"
    #url_protocol_type="$(check_protocol_type_for_url "$1")"
    url_repoowner="$(get_repoowner_from_url "$hub_repo_url_value")"
    url_reponame="$(get_reponame_from_url "$hub_repo_url_value")"
    echo "url_hub_type=$url_hub_type"
    echo "url_repoowner=$url_repoowner"
    echo "url_reponame=$url_reponame"

    if [[ "$url_hub_type" == "gitee" ]]; then
        local request_url_prefix="https://gitee.com/api/v5/repos"
        local access_token="$GITEE_ACCESS_TOKEN"
        # 下面request_url中，只在$access_token的'授权账户'与'需要验证存在性的仓库的所有者所属的账户'一致时，才需要加上 ?access_token=$access_token。
        # 不一致时，也就表明'需要验证存在性的仓库的所有者所属的账户'并非'授权账户'，无法查看私有仓库且无法突破访问次数限制。故，放弃该方法。
        if [ -n "$access_token" ]; then
            local request_url="$request_url_prefix/$url_repoowner/$url_reponame?access_token=$access_token"
        else
            local request_url="$request_url_prefix/$url_repoowner/$url_reponame"
        fi
        local curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8')
    elif [[ "$url_hub_type" == "github" ]]; then
        local request_url_prefix="https://api.github.com/repos"
        local access_token="$GITHUB_ACCESS_TOKEN"
        # 下面request_url中，只在$access_token的'授权账户'与'需要验证存在性的仓库的所有者所属的账户'一致时，才需要加上 ?access_token=$access_token。
        # 不一致时，也就表明'需要验证存在性的仓库的所有者所属的账户'并非'授权账户'，无法查看私有仓库且无法突破访问次数限制。故，放弃该方法。
        local request_url="$request_url_prefix/$url_repoowner/$url_reponame"
        if [ -n "$access_token" ]; then
            local curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/vnd.github.v3+json' -H "Authorization: token $access_token")
        else
            local curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/vnd.github.v3+json')
        fi
        
    fi

    echo "request_url = $request_url"

    if type curl > /dev/null 2>&1; then
        # 使用 `curl [-f | --fail] <request_url>` 来检查仓库是否存在
        # 该方法比较麻烦，对私有仓库的判断需要 GitHub 和 Gitee的 access_token，会导致整个操作变得复杂。故，注释掉此处代码，仅供参考。
        local content_get_from_request_url
        if content_get_from_request_url=$(curl "${curl_options[@]}" "$request_url"); then
            exit_status_code_flag=$?
            echo $exit_status_code_flag
            echo "Access Success"
            #echo "$content_get_from_request_url"

            if type jq > /dev/null 2>&1; then
                repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
            else
                echo_color red "There is no 'jq' command, please install it"
                exit 1
            fi
            
            echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
            echo "\"$url_repoowner/$url_reponame\""
            if [[ "$repo_full_name_get_from_request_url" == "\"$url_repoowner/$url_reponame\"" ]]; then
                echo_color green "'$hub_repo_url_value' is existed as a remote repo on Hub"
            else
                # 占位，除非 Hub 服务器鬼畜了，不然不会出现从 url 获取的 $repo_full_name_get_from_request_url 和 url 中的 "$url_repoowner/$url_reponame" 不一致。
                :
            fi
        else
            exit_status_code_flag=$?
            echo "exit_status_code_flag = $exit_status_code_flag"
            echo "Access Fail"
            #echo "$content_get_from_request_url"
            if [[ $exit_status_code_flag -eq 22 ]]; then
                echo_color red "HTTP 找不到网页，'$hub_repo_url_value' 可能是私有仓库或者不存在该仓库。"
                exit 1
            elif [[ $exit_status_code_flag -eq 7 ]]; then
                echo_color red "$request_url 拒接连接，被目标服务器限流。"
                exit 1
            else
                echo_color red "Curl: exit_status_code_flag = $exit_status_code_flag"
                exit 1
            fi
        fi
    else
        echo_color red "There is no 'curl' command, please install it"
        exit 1
    fi
}

# 使用 git 来判断 url 作为远程仓库是否存在于 hub 上
check_existence_of_url_for_hub_with_git() {
    local hub_repo_url_var="$1"
    local hub_repo_url_value="${!hub_repo_url_var}"

    if type git > /dev/null 2>&1; then
        # 使用 `git ls-remote <repo_url>` 来检查仓库是否存在，repo_url 使用 SSH 方式
        # 该方法需要使用到 SSH 密钥对，比较方便。
        if { git ls-remote "$hub_repo_url_value" > /dev/null; } 2>&1; then
            echo_color green "'$hub_repo_url_value' is existed as a remote repo on Hub"
        else
            echo_color red "'$hub_repo_url_value' is not existed as a remote repo on Hub"
            exit 1
        fi
    else
        echo_color red "There is no 'git' command, please install it"
        exit 1
    fi
}

# 判断 url 作为远程仓库是否存在于 hub 上
check_existence_of_url_for_hub() {
    local hub_repo_url_var="$1"
    #local hub_repo_url_value="${!hub_repo_url_var}"
    # 判断远程仓库是否存在时使用的命令工具，可以为 git 或 curl。
    local request_tool
    # 注释掉下面这行的话，则 request_tool 默认使用 git。
    #request_tool="curl"
    request_tool=${request_tool:-"git"}
    if [[ "$request_tool" == "curl" ]]; then
        echo_color green "Use 'curl' to check the existence of url for hub"
        check_existence_of_url_for_hub_with_curl "$hub_repo_url_var"
    elif [[ "$request_tool" == "git" ]]; then
        echo_color green "Use 'git' to check the existence of url for hub"
        check_existence_of_url_for_hub_with_git "$hub_repo_url_var"
    else
        echo_color yellow "'request_tool' unknown! must be 'git' or 'curl'."
        exit 1
    fi
}

check_overall_validity_of_url() {
    local hub_repo_url_var="$1"
    local hub_repo_url_value="${!hub_repo_url_var}"

    local url_hub_type
    #local url_protocol_type
    local url_repoowner
    local url_reponame
    url_hub_type="$(check_hub_type_for_url "$hub_repo_url_value")"
    #url_protocol_type="$(check_protocol_type_for_url "$1")"
    url_repoowner="$(get_repoowner_from_url "$hub_repo_url_value")"
    url_reponame="$(get_reponame_from_url "$hub_repo_url_value")"
    echo "url_hub_type=$url_hub_type"
    echo "url_repoowner=$url_repoowner"
    echo "url_reponame=$url_reponame"

    check_spaces_in_string "$hub_repo_url_value"

    if [[ "$url_hub_type" == "gitee" ]]; then
        check_validity_of_repoowner_adapt_gitee "$url_repoowner"
        check_validity_of_reponame_adapt_gitee "$url_reponame"
    elif [[ "$url_hub_type" == "github" ]]; then
        check_validity_of_reponame_adapt_github "$url_reponame"
    fi

    check_existence_of_url_for_hub "$hub_repo_url_var"
}

get_validity_of_current_dir_as_git_repo() {
    local validity_of_current_dir_as_git_repo
    local repo_remote_url_for_fetch_with_fuzzy_match
    local repo_remote_url_for_fetch_with_exact_match

    # git clone --mirror 克隆下来的为纯仓库。
    # git rev-parse --is-inside-work-tree 判断是否为非纯的普通仓库。
    # git rev-parse --is-bare-repository 判断是否为纯仓库（或者叫裸仓库）。
    if [ "$(git rev-parse --is-inside-work-tree)" = "true" ] || [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
        # 模糊匹配，获取到的字符串前后可能有空格。
        # 此处有问题，GitHub action 使用的 ubuntu-latest 中的 grep 没有 -P 选项，而 -E 选项又不支持 (?<=origin).*(?=\(fetch\))，该问题待解决
        #repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | grep -Po "(?<=origin).*(?=\(fetch\))")
        repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk '/^origin.+\(fetch\)$/ {print $2}')
        # 精确匹配，删除字符串前后空格。
        repo_remote_url_for_fetch_with_exact_match=$(trim_spaces_around_string "$repo_remote_url_for_fetch_with_fuzzy_match")
        if [[ "$repo_remote_url_for_fetch_with_exact_match" == "$1" ]]; then
            validity_of_current_dir_as_git_repo="true"
        else
            validity_of_current_dir_as_git_repo="warn"
        fi
    else
        validity_of_current_dir_as_git_repo="false"
    fi

    echo "$validity_of_current_dir_as_git_repo"
}

# 命令出错或失败或超时时重试
err_retry_cmd() {
    # 重试总次数
    local sum_retry=2
    # 重试计数
    local num_retry=0
    # 重试之前的等待时间，防止前次命令的进程还没有退出。
    local sleep_time=5
    until eval "$@"; do
        exit_status_code=$?
        pre_num_retry=$num_retry
        num_retry=$((num_retry + 1))
        if (( num_retry <= sum_retry )); then
            echo_color yellow "Command failed! exit_status_code=$exit_status_code"
            echo_color cyan "($num_retry/$sum_retry) Retry after $sleep_time seconds..."
            sleep $sleep_time
        else
            echo_color red "Command still failed! exit_status_code=$exit_status_code"
            echo_color yellow "($pre_num_retry/$sum_retry) Retry end!"
            return $exit_status_code
        fi
    done

    return 0
}

# main 函数
entrypoint_main() {
    echo -e ""
    echo_color cyan "--------> go in entrypoint_main func\n"
    echo_color purple "<-------------------parameter info BEGIN------------------->"
    print_var_info
    echo_color purple "<-------------------parameter info END--------------------->\n"
    
    ssh_config

    git_config_info
    
    # 是否删除缓存目录，取消注释的话则会删除缓存目录
    #remove_cache_dir_flag="true"
    remove_cache_dir_flag=${remove_cache_dir_flag:-"false"}
    # 删除缓存目录
    if [ -d "$CACHE_PATH" ] && [[ "$remove_cache_dir_flag" == "true" ]]; then
        rm -rf "$CACHE_PATH"
    fi

    if [ ! -d "$CACHE_PATH" ]; then
        mkdir -p "$CACHE_PATH"
    fi
    cd "$CACHE_PATH"

    # 下面块注释的内容仅供参考
:<<EOF
    ### 使用 while read 将多行内容中的每行遍历
    # 仓库映射的总个数
    i_total=$(echo "$SRC_TO_DST" | grep -cv "^$")
    # 处理到第几个仓库映射了
    i_count=0
    echo "$SRC_TO_DST" | while read -r src_to_dst_per_line; do     # 注意，read 后的 -r：不允许反斜杠来转义任何字符。
        if [ -n "$src_to_dst_per_line" ]; then
            i_count_tmp=$i_count
            ((i_count=i_count+1))

            # src_to_dst_array_per_line=($src_to_dst_per_line)   #<=== 好像不提倡这种方式，可使用下面 read -ra 方式。
            # IFS=" " 表示空格作为分隔符；read 后的 -r 表示不允许反斜杠来转义任何字符，-a(array) 表示把输入内容按分隔符(空格或者跳格之类)分配给数组，连续的空格也算为1个分割。
            IFS=" " read -r -a src_to_dst_array_per_line <<< "$src_to_dst_per_line"
            length_src_to_dst_array_per_line=${#src_to_dst_array_per_line[@]}

            ...
        fi
    done

    ### 这里也可以使用另一种方式
    ### 使用数组及 for 循环将多行内容中的每行遍历
    # 仓库映射的总个数
    i_total=$(echo "$SRC_TO_DST" | grep -cv "^$")
    # 处理到第几个仓库映射了
    i_count=0
    # 将多行内容（如下的 "$SRC_TO_DST"）赋值给数组变量（如下的 src_to_dst_array），每行作为一个元素。
    mapfile -t src_to_dst_array <<< "$SRC_TO_DST"
    for((i=0;i<${#src_to_dst_array[*]};i++)); do
        src_to_dst_per_line=${src_to_dst_array[i]}
        if [ -n "$src_to_dst_per_line" ]; then
            i_count_tmp=$i_count
            ((i_count=i_count+1))

            # src_to_dst_array_per_line=($src_to_dst_per_line)   #<=== 好像不提倡这种方式，可使用下面 read -ra 方式。
            # IFS=" " 表示空格作为分隔符；read 后的 -r 表示不允许反斜杠来转义任何字符，-a(array) 表示把输入内容按分隔符(空格或者跳格之类)分配给数组，连续的空格也算为1个分割。
            IFS=" " read -r -a src_to_dst_array_per_line <<< "$src_to_dst_per_line"
            length_src_to_dst_array_per_line=${#src_to_dst_array_per_line[@]}

            ...
        fi
    done
EOF

    # 仓库映射的总个数
    i_total=$(echo "$SRC_TO_DST" | grep -cv "^$")
    # 处理到第几个仓库映射了
    i_count=0
    echo "$SRC_TO_DST" | while read -r src_to_dst_per_line; do     # 注意，read 后的 -r：不允许反斜杠来转义任何字符。
        if [ -n "$src_to_dst_per_line" ]; then
            i_count_tmp=$i_count
            ((i_count=i_count+1))

            # src_to_dst_array_per_line=($src_to_dst_per_line)   #<=== 好像不提倡这种方式，可使用下面 read -ra 方式。
            # IFS=" " 表示空格作为分隔符；read 后的 -r 表示不允许反斜杠来转义任何字符，-a(array) 表示把输入内容按分隔符(空格或者跳格之类)分配给数组，连续的空格也算为1个分割。
            IFS=" " read -r -a src_to_dst_array_per_line <<< "$src_to_dst_per_line"
            length_src_to_dst_array_per_line=${#src_to_dst_array_per_line[@]}
            if (( length_src_to_dst_array_per_line == 2 )); then
                src_repo_url=${src_to_dst_array_per_line[0]}
                dst_repo_url=${src_to_dst_array_per_line[1]}
            elif (( length_src_to_dst_array_per_line == 3 )); then
                src_repo_url=${src_to_dst_array_per_line[0]}
                dst_repo_url=${src_to_dst_array_per_line[2]}
            else
                echo ""
                echo_color red "(${i_count}/${i_total}) 'src_to_dst' mapping error!"
                exit 1
            fi
            
            # 在前后两个打印信息之间添加空行
            if (( i_count_tmp > 0 )); then
                echo ""
            fi

            echo_color purple "<======================(${i_count}/${i_total}) $(get_reponame_from_url "$src_repo_url") BEGIN======================>"
            echo "src_repo_url=$src_repo_url"
            echo -e "dst_repo_url=${dst_repo_url}\n"

            # 提前判断源端和目的端仓库地址是否合法，避免后面克隆或推送时报错
            #process_error_in_advance_flag="true"
            process_error_in_advance_flag=${process_error_in_advance_flag:-"false"}
            if [[ "$process_error_in_advance_flag" == "true" ]]; then
                echo_color purple "<-------------------src_repo_url check_overall_validity_of_url BEGIN------------------->"
                check_overall_validity_of_url src_repo_url
                echo_color purple "<-------------------src_repo_url check_overall_validity_of_url END--------------------->\n"

                echo_color purple "<-------------------dst_repo_url check_overall_validity_of_url BEGIN------------------->"
                check_overall_validity_of_url dst_repo_url
                echo_color purple "<-------------------dst_repo_url check_overall_validity_of_url END--------------------->\n"
            fi
            
            SRC_REPO_DIR_NO_DOTGIT_OF_URL=$(get_reponame_from_url "$src_repo_url")
            # 超时的时间
            time_out=3m
            # 使用普通克隆/推送
            if [ -d "$SRC_REPO_DIR_NO_DOTGIT_OF_URL" ] ; then
                cd "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
                echo_color purple "<-------------------src_repo_url check_validity_of_current_dir_as_git_repo BEGIN------------------->"

                validity_of_current_dir_as_git_repo=$(get_validity_of_current_dir_as_git_repo "$src_repo_url")
                if [[ "$validity_of_current_dir_as_git_repo" == "true" ]]; then
                    echo_color green "current dir is a git repo!"
                    echo_color green "The repo url of pre-fetch matches the src repo url."
                    err_retry_cmd timeout $time_out git pull --prune || { echo_color red "error for 'git pull --prune'";exit 1; }
                elif [[ "$validity_of_current_dir_as_git_repo" == "warn" ]]; then
                    echo_color green "current dir is a git repo!"
                    echo_color yellow "The repo url of pre-fetch dose not matches the src repo url."
                    cd .. && rm -rf "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
                    echo_color cyan "--------> git clone..."
                    git clone "$src_repo_url" || { echo_color red "error for 'git clone $src_repo_url'";exit 1; }
                    cd "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
                elif [[ "$validity_of_current_dir_as_git_repo" == "false" ]]; then
                    echo_color yellow "current dir is not a git repo!"
                    cd .. && rm -rf "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
                    echo_color cyan "--------> git clone..."
                    git clone "$src_repo_url" || { echo_color red "error for 'git clone $src_repo_url'";exit 1; }
                    cd "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
                fi

                echo_color purple "<-------------------src_repo_url check_validity_of_current_dir_as_git_repo END--------------------->\n"
            else
                echo_color yellow "no '$SRC_REPO_DIR_NO_DOTGIT_OF_URL: $src_repo_url' cache\n"
                echo_color cyan "--------> git clone..."
                git clone "$src_repo_url" || { echo_color red "error for 'git clone $src_repo_url'";exit 1; }
                cd "$SRC_REPO_DIR_NO_DOTGIT_OF_URL"
            fi

            git remote set-url --push origin "$dst_repo_url"
            # 需要删除 remotes/origin/HEAD，不然使用 git push origin "refs/remotes/origin/*:refs/heads/*" 命令推送到目的端时，会创建一个HEAD分支。
            git remote set-head origin --delete
            
            # =~：左侧是字符串，右侧是一个模式，判断左侧的字符串能否被右侧的模式所匹配：通常只在 [[ ]] 中使用, 模式中可以使用行首、行尾锚定符，但是模式不要加引号。
            if [[ "$SRC_REPO_BRANCH" =~ ^refs/remotes/origin/$ ]]; then
                echo_color red "The format of the 'src_repo_branch' parameter is illegal"
                exit 1
            fi
            if [[ "$DST_REPO_BRANCH" =~ ^refs/heads/$ ]]; then
                echo_color red "The format of the 'dst_repo_branch' parameter is illegal"
                exit 1
            fi
            if [[ -z "$SRC_REPO_BRANCH" ]] && [[ -z "$DST_REPO_BRANCH" ]]; then
                echo_color red "Because only push the current branch to $dst_repo_url, so exit."
                exit 1
            elif [[ -z "$SRC_REPO_BRANCH" ]] && [[ -n "$DST_REPO_BRANCH" ]]; then
                remove_branch="true"
            elif [[ -n "$SRC_REPO_BRANCH" ]] && [[ -z "$DST_REPO_BRANCH" ]]; then
                echo_color red "The 'dst_repo_branch' parameter cannot be empty"
                exit 1
            fi
            if [[ -n "$SRC_REPO_BRANCH" ]] && [[ ! "$SRC_REPO_BRANCH" =~ ^refs/remotes/origin/.+ ]]; then
                SRC_REPO_BRANCH="refs/remotes/origin/$SRC_REPO_BRANCH"
            fi
            if [[ -n "$DST_REPO_BRANCH" ]] && [[ ! "$DST_REPO_BRANCH" =~ ^refs/heads/.+ ]]; then
                DST_REPO_BRANCH="refs/heads/$DST_REPO_BRANCH"
            fi

            if [[ "$SRC_REPO_TAG" =~ ^refs/tags/$ ]]; then
                echo_color red "The format of the 'src_repo_tag' parameter is illegal"
                exit 1
            fi
            if [[ "$DST_REPO_TAG" =~ ^refs/tags/$ ]]; then
                echo_color red "The format of the 'dst_repo_tag' parameter is illegal"
                exit 1
            fi
            if [[ -z "$SRC_REPO_TAG" ]] && [[ -z "$DST_REPO_TAG" ]]; then
                echo_color red "Because only push the current branch to $dst_repo_url, so exit."
                exit 1
            elif [[ -z "$SRC_REPO_TAG" ]] && [[ -n "$DST_REPO_TAG" ]]; then
                remove_tag="true"
            elif [[ -n "$SRC_REPO_TAG" ]] && [[ -z "$DST_REPO_TAG" ]]; then
                echo_color red "The 'dst_repo_tag' parameter cannot be empty"
                exit 1
            fi
            if [[ -n "$SRC_REPO_TAG" ]] && [[ ! "$SRC_REPO_TAG" =~ ^refs/tags/.+ ]]; then
                SRC_REPO_TAG="refs/tags/$SRC_REPO_TAG"
            fi
            if [[ -n "$DST_REPO_TAG" ]] && [[ ! "$DST_REPO_TAG" =~ ^refs/tags/.+ ]]; then
                DST_REPO_TAG="refs/tags/$DST_REPO_TAG"
            fi

            # 是否强制推送
            force_push_flag="true"
            force_push_flag=${force_push_flag:-"false"}
            if [[ "$force_push_flag" == "true" ]]; then
                git_push_branch_args=(--force)
                git_push_tag_args=(--force)
            fi

            if [[ "$SRC_REPO_BRANCH" == "refs/remotes/origin/*" && "$DST_REPO_BRANCH" == "refs/heads/*" ]]; then
                git_push_branch_args=("${git_push_branch_args[@]}" --prune)
            fi

            if [[ "$SRC_REPO_TAG" == "refs/tags/*" && "$DST_REPO_TAG" == "refs/tags/*" ]]; then
                git_push_tag_args=("${git_push_tag_args[@]}" --prune)
            fi

            echo_color cyan "--------> git push branch..."
            if [[ "$remove_branch" == "true" ]]; then
                echo_color yellow "remove $DST_REPO_BRANCH branch for $dst_repo_url."
            fi
            # 推送分支
            err_retry_cmd timeout $time_out git push origin "${SRC_REPO_BRANCH}:${DST_REPO_BRANCH}" "${git_push_branch_args[@]}" \
            || { echo_color red "error for 'git push origin ${SRC_REPO_BRANCH}:${DST_REPO_BRANCH} ${git_push_branch_args[*]}'";exit 1; }
            echo_color cyan "--------> git push tags..."
            if [[ "$remove_tag" == "true" ]]; then
                echo_color yellow "remove $DST_REPO_TAG tag for $dst_repo_url."
            fi
            # 推送标签
            err_retry_cmd timeout $time_out git push origin "${SRC_REPO_TAG}:${DST_REPO_TAG}" "${git_push_tag_args[@]}" \
            || { echo_color red "error for 'git push origin ${SRC_REPO_BRANCH}:${DST_REPO_BRANCH} ${git_push_branch_args[*]}'";exit 1; }
            
            echo_color purple "<======================(${i_count}/${i_total}) $(get_reponame_from_url "$src_repo_url") END========================>"
        fi
    done
}

# 入口
entrypoint_main "$@"
