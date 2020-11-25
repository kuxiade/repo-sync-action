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

# # 判断字符串中是否含有空格
# find_space_in_string() {
#     if [[ "$1" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
#     then
#         echo_color red "There are spaces in the repo url: $1."
#         exit 0
#     else
#         echo_color green "There are not spaces in the repo url: $1."
#     fi
# }

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

    # # 检查仓库是否存在
    # # 比较麻烦，对私有仓库的判断需要 GitHub 和 Gitee的 access_token，会导致整个操作变得复杂。故，注释掉此处代码，仅供参考。
    # repo_full_name_get_from_request_url=$(curl "$request_url_prefix"/"$ownername_reponame_in_repourl" | jq '.full_name')
    # echo "$request_url_prefix"/"$ownername_reponame_in_repourl"
    # echo "repo_full_name_get_from_request_url= $repo_full_name_get_from_request_url"
    # echo "\"$ownername_reponame_in_repourl\""
    # if [[ "$repo_full_name_get_from_request_url" == "\"$ownername_reponame_in_repourl\"" ]]; then
    #     echo_color green "$repo_url_var: $repo_url_value is existed"
    # else
    #     # 仓库不存在或者拒绝连接，可能由于网络问题导致无法连接到仓库的 request url，这样会导致误判，待解决。
    #     echo_color yellow "$repo_url_var: $repo_url_value is not existed"
    #     # 创建仓库或者直接退出
    #     if [[ "$repo_url_var" == "DESTINATION_REPO" ]]; then
    #         if [[ "$FORCE_CREAT_DESTINATION_REPO" == "tree" ]]; then
    #             # 创建仓库
    #             echo_color green "Creat $repo_url_var: $repo_url_value..."
    #         elif [[ "$FORCE_CREAT_DESTINATION_REPO" == "false" ]]; then
    #             echo_color red "Please make sure the $repo_url_var repo name is correct or create it manually"
    #             exit 0
    #         else
    #             echo_color red "The FORCE_CREAT_DESTINATION_REPO parameter passed in must be 'true' or 'false'"
    #             exit 0
    #         fi
    #     elif [[ "$repo_url_var" == "SOURCE_REPO" ]]; then
    #         echo_color red "Please make sure the $repo_url_var repo name is correct"
    #         exit 0
    #     else
    #         echo_color red "The parameter passed in must be 'SOURCE_REPO' or 'DESTINATION_REPO'!"
    #         exit 0
    #     fi
    # fi


    # 检查仓库是否存在
    # 比较麻烦，对私有仓库的判断需要 GitHub 和 Gitee的 access_token，会导致整个操作变得复杂。故，注释掉此处代码，仅供参考。
    local request_url="$request_url_prefix"/"$ownername_reponame_in_repourl"
    echo "request_url = $request_url"
    if content_get_from_request_url=$(curl -f "$request_url"); then
        exit_status_code_flag=$?
        echo $exit_status_code_flag
        echo "Success"
        #echo "$content_get_from_request_url"
        repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
        echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
        echo "\"$ownername_reponame_in_repourl\""
        if [[ "$repo_full_name_get_from_request_url" == "\"$ownername_reponame_in_repourl\"" ]]; then
            echo_color green "$repo_url_var: $repo_url_value is existed"
        else
            :
        fi
    else
        exit_status_code_flag=$?
        echo "exit_status_code_flag = $exit_status_code_flag"
        echo "Fail"
        #echo "$content_get_from_request_url"
        if [[ $exit_status_code_flag -eq 22 ]]; then
            echo "HTTP 找不到网页，url可能是私有仓库或者不存在该仓库。"
        elif [[ $exit_status_code_flag -eq 7 ]]; then
            echo "url拒接连接，被目标服务器限流。"
        else
            echo "Curl: exit_status_code_flag = $exit_status_code_flag"
        fi

        # if (( exit_status_code_flag == 22 )); then
        #     echo "HTTP 找不到网页，url可能是私有仓库或者不存在该仓库。"
        # elif (( exit_status_code_flag == 7 )); then
        #     echo "url拒接连接，被目标服务器限流。"
        # fi
    fi


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
# Exclude refs created by GitHub for pull request.排除 GitHub 为 pull request 创建的 refs。
# 不论是推送到 GitHub 还是 Gitee，必须有下面这一步，不然某些隐藏的引用无法推送到远程目的端仓库，会报错。如下：
# ! [remote rejected] refs/pull/1/head -> refs/pull/1/head (deny updating a hidden ref)
git for-each-ref --format 'delete %(refname)' refs/pull | git update-ref --stdin
# --mirror 表示 refs/* （包括但不限于 refs/heads/* , refs/remotes/* , and refs/tags/* . 事实上就还包含了 refs/pull/* ，所以上面需要排除 refs/pull）推送到远程
# 看情况来判断，--mirror 应该是包含了但不限于 --all 和 --tags 的作用的。
git push --mirror


### 对于推送，有下面四种方法
## 以下几种方法可能都无法将本地的'默认分支指定'也推送到远程，远程默认分支直接被gitee设置master或main了。待确认。
## 方法一：镜像克隆且镜像推送整个仓库，这个应该是同步的最完整的方式了。
git clone --mirror "$SOURCE_REPO"
git remote set-url --push origin "$DESTINATION_REPO"
git fetch -p origin
# Exclude refs created by GitHub for pull request.排除 GitHub 为 pull request 创建的 refs。
# 不论是推送到 GitHub 还是 Gitee，必须有下面这一步，不然某些隐藏的引用无法推送到远程目的端仓库，会报错。如下：
# ! [remote rejected] refs/pull/1/head -> refs/pull/1/head (deny updating a hidden ref)
git for-each-ref --format 'delete %(refname)' refs/pull | git update-ref --stdin
# --mirror 表示 refs/* （包括但不限于 refs/heads/* , refs/remotes/* , and refs/tags/* . 事实上就还包含了 refs/pull/* ，所以上面需要排除 refs/pull）推送到远程
# 看情况来判断，--mirror 应该是包含了但不限于 --all 和 --tags 的作用的。
git push --mirror

## 方法二：普通克隆，然后再推送所有分支到远程仓库，仅仅只有分支同步了，标签没有同步，相对没有方法一使用 --mirror 来的完整。
# --all 表示推送所有分支（branch），类似于 refs/remotes/origin/*:refs/heads/*。--all 不能与其他的 <refspec> 一起使用
# 下面这种写法报错，就是因为 --all 不能与其他的 refs/tags/*:refs/tags/* 一起使用。且 --all --tags --mirror 三种不兼容，三者只能选其一。
# git push origin refs/tags/*:refs/tags/* --all --prune
# 下面这种方法就是只推送所有分支到远程：
git clone "$SOURCE_REPO"
# git clone默认会把远程仓库整个给clone下来，但只会在本地默认创建一个master分支
# 想要把其他分支取到本地需要执行下面的命令：git checkout -b <branch>
# 所以，从GitHub上git clone代码，尽管克隆了整个仓库，但是其他分支没有取回本地并创建，这时候再推送到gitee上，
# 实际上只推送了一个分支，其他分支没有推送到gitee，就因为本地此时也只有一个分支。
# 要解决此问题，方法为一次性拉取该仓库的所有分支，命令如下：
# 参考链接：https://blog.csdn.net/weixin_41287260/article/details/98987135
for b in $(git branch -r | grep -v -- '->'); do git branch --track "${b##origin/}" "$b"; done
# 运行上一条命令后，使用 git branch -v 即可看到所有远程分支都取回到本地了。
git remote set-url --push origin "$DESTINATION_REPO"
git fetch -p origin
# push 使用了 --all 或者 --tags 时，那么前面克隆时就不能使用 --mirror 做镜像克隆，应使用普通克隆，因为三者不兼容。
# 推送本地的所有分支到远程，注意，这里是本地的分支，没有取回到本地的分支是不会推送的。
# 由于普通克隆到本地的仓库中并不含有 refs/pull/*，因此下面的两条命令似乎可以使用 git push --mirror 代替。
git push origin --all --prune --force
# 推送所有标签到远程
git push origin --tags --prune --force

## 方法三：普通克隆，然后再推送所有分支及所有标签到远程仓库，分支和标签都同步了，和方法二效果差不多，但依然没有方法一使用 --mirror 来的完整。
# --tags 表示推送所有标签（tag），类似于 refs/tags/*:refs/tags/*。--tags 可以与其他的 <refspec> 一起使用。
git clone "$SOURCE_REPO"
git remote set-url --push origin "$DESTINATION_REPO"
git fetch -p origin
# 需要删除 remotes/origin/HEAD，不然推送到目的端时，会创建一个HEAD分支。待确定该如何设置
git remote set-head origin --delete
# push 使用了 --all 或者 --tags 时，那么前面克隆时就不能使用 --mirror 做镜像克隆，应使用普通克隆，因为三者不兼容。
git push origin refs/remotes/origin/*:refs/heads/* --tags --prune --force

## 方法四：
# 标记灵活，可以实现指定推送
# SRC_REFS：可以是分支、标签等
# SRC_REFS="refs/remotes/origin/*" DST_REFS="refs/heads/*" 各表示src端的所有分支和dst端的所有分支。
# SRC_REFS="refs/tags/*" DST_REFS="refs/tags/*" 各表示src端所有标签和dst端的所有标签。
# SRC_REFS 和 DST_REFS 也可以直接指定分支或者标签。如，SRC_REFS="dev" DST_REFS="dev"
git push -f origin "${SRC_REFS}:${DST_REFS}"
#git push -f origin "${SOURCE_BRANCH}:${DESTINATION_BRANCH}"
###对于推送，有上面四种方法