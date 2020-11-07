#!/usr/bin/env bash

set -e
#set -o pipefail
#set -x

# cd git-test || exit

# #get_repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk -F '[[:blank:]]' '{print $2}')
# get_repo_remote_url_for_fetch_with_fuzzy_match=$(git remote -v | awk '/^origin.+\(fetch\)$/ {print $2}')

# echo "$get_repo_remote_url_for_fetch_with_fuzzy_match"

# if git remote -v | awk fgh '/^odrigin.+\(fetch\)$/ {print $2}'; then
#     echo "right"
# else
#     echo "error"
# fi

# repo_url="https://gitee.com/kuxiade/github-docs.git"
# ownername_reponame_in_repourl="${repo_url#https://gitee.com/}"
# echo "$ownername_reponame_in_repourl"

# if echo "${ownername_reponame_in_repourl#*/}" | grep -Eq "^[a-zA-Z][a-zA-Z0-9._-]{1,190}\.git$"; then
#     echo "Gitee repo: The format of the repoName:${ownername_reponame_in_repourl#*/} is right."
#     true_ownername_reponame_in_repourl="${ownername_reponame_in_repourl%*.git}"
#     echo "$true_ownername_reponame_in_repourl"
# else
#     echo "Gitee repo: The format of the repoName:${ownername_reponame_in_repourl#*/} is wrong."
#     exit 0
# fi

#DST_ACCOUNT="kuxiade"
#DST_REPO_NAME="mirror-repo-action.git"
#has_repo=$(curl https://gitee.com/api/v5/repos/kuxiade/github-docs | jq '.[] | select(.full_name=="'$DST_ACCOUNT'/'$DST_REPO_NAME'").name' | wc -l)
#has_repo=$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/kuxiade/github-docs' | jq '.[] | select(.full_name=="'$DST_ACCOUNT'/'$DST_REPO_NAME'").name' | wc -l)
#has_repo=$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/kuxiade/github-docs' | jq '.[] | select(.full_name=="'$DST_ACCOUNT'/'$DST_REPO_NAME'").name' | wc -l)
# has_repo="$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://api.github.com/repos/kuxiade/mirror-repo-action.git' | jq '.full_name')"
# echo "$has_repo"
# echo "\"$DST_ACCOUNT/$DST_REPO_NAME\""
# if [[ "$has_repo" == "\"$DST_ACCOUNT/$DST_REPO_NAME\"" ]]; then
#     echo "exist repo"
# else
#     echo "not exist repo"
# fi

# repo_name="..."
# if [ "$repo_name" = "." ] || [ "$repo_name" = ".." ]; then
#     echo "error"
# fi

# if curl -sL --fail http://google.com -o /dev/null; then
#     echo "Success"
# else
#     echo "Fail"
# fi

# if curl -f https://api.github.com/repos/kuxiade/git-mirror-sync -o /dev/null; then
#     echo $?
#     echo "Success"
# else
#     echo $?
#     echo "Fail"
# fi

# if aaaa=$(curl -f https://gitee.com/api/v5/repos/kuxiade/snail); then
#     exit_status_code_flag=$?
#     echo $exit_status_code_flag
#     echo "Success"
#     #echo "$aaaa"
#     has_repo=$(echo "$aaaa" | jq '.full_name')
#     echo "$has_repo"
# else
#     exit_status_code_flag=$?
#     echo $exit_status_code_flag
#     echo "Fail"
#     #echo "$aaaa"
#     if [[ $exit_status_code_flag -eq 22 ]]; then
#         echo "HTTP 找不到网页，url可能是私有仓库或者不存在该仓库。"
#     elif [[ $exit_status_code_flag -eq 7 ]]; then
#         echo "url拒接连接，被目标服务器限流。"
#     fi

#     if (( exit_status_code_flag == 22 )); then
#         echo "HTTP 找不到网页，url可能是私有仓库或者不存在该仓库。"
#     elif (( exit_status_code_flag == 7 )); then
#         echo "url拒接连接，被目标服务器限流。"
#     fi
# fi

#repo_url_with_ssh="git@github.com:kuxiade/arch-setup.git"
#repo_url_with_ssh="git@gitee.com:kuxiade/git-test.git"
# repo_url_with_ssh="git@gitee.com:kuxiade/vscode-dev-container.git"

# # { cmd > /dev/null; } 2>&1
# # cmd 的 stdout 丢入 /dev/null，然后将 stderr 输出到终端。即不打印标准输出信息，但是打印错误信息。
# if { git ls-remote "$repo_url_with_ssh" > /dev/null; } 2>&1; then
#     echo $?
#     echo "存在"
# else
#     echo $?
#     echo "不存在"
# fi

# echo "============================"

# # cmd > /dev/null 2>&1
# # stderr 和 stdout 都不在终端上显示
# if git ls-remote "$repo_url_with_ssh" > /dev/null 2>&1; then
#     echo $?
#     echo "存在"
# else
#     echo $?
#     echo "不存在"
# fi
# echo "hello"
# foo_to_bar_pair="(a A),(b B),(c C)"
# #echo "$foo_to_bar_pair" | awk -F, '{ print NF; for (i = 1; i <= NF; ++i) print $i }'
# echo "$foo_to_bar_pair" | awk -F, '{ for (i = 1; i <= NF; ++i) print "\""$i"\"" }'

# #foo_to_bar_pair1=$(echo "$foo_to_bar_pair" | awk -F, '{ for (i = 1; i <= NF; ++i) print "\{"$i"\}" }')
# # echo "$foo_to_bar_pair" | awk -F, '
# # BEGIN { print NF } 
# # { print NF; for (i = 1; i <= NF; ++i) print $i }
# # END { print NF; aaaaaaaaaa=NF } '


# # declare -A foo_to_bar
# # foo_to_bar[foo]="bar"

# # echo ${foo_to_bar[foo]}
# foo_to_bar_pair1=('(a A)' '(b B)' '(c C)')
# for n in "${foo_to_bar_pair1[@]}"
# do
#     echo "$n"
# done



a1="a111"
a2="a222"
b1="b111"
b2="b222"

echo "$a1  '$a2'"
echo '$b1 "$b2"'

echo "nonexist=$nonexist"

url_repoowner="kuxiade"
url_reponame="github-doc"
request_url_prefix="https://gitee.com/api/v5/repos"
#GITEE_ACCESS_TOKEN="sddggdkdlgldhsjgfjfhg"
#access_token="$GITEE_ACCESS_TOKEN"
request_url="$request_url_prefix/$url_repoowner/$url_reponame"
#curl_options="-f -X GET -H 'Content-Type: application/json;charset=UTF-8'"
curl_options=(-f -X GET -H 'Content-Type: application/json;charset=UTF-8')

#curl "${curl_options[@]}" "$request_url"

#curl -f 'https://gitee.com/api/v5/repos/kuxiade/github-docs'

# content_get_from_request_url=$(curl "${curl_options[@]}" "$request_url")
# exit_status_code_flag=$?
# echo "exit_status_code_flag=$exit_status_code_flag"
# if [[ $exit_status_code_flag -eq 0 ]]; then
#     echo "Success"

#     if type jq > /dev/null 2>&1; then
#         repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
#     else
#         echo "There is no 'jq' command, please install it"
#         exit 0
#     fi
    
#     echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
# elif [[ $exit_status_code_flag -eq 22 ]]; then
#     echo "HTTP 找不到网页，可能是私有仓库或者不存在该仓库。"
# elif [[ $exit_status_code_flag -eq 7 ]]; then
#     echo "$request_url 拒接连接，被目标服务器限流。"
# else
#     echo "Curl: exit_status_code_flag = $exit_status_code_flag"
# fi

# if content_get_from_request_url=$(curl "${curl_options[@]}" "$request_url"); then
#     exit_status_code_flag=$?
#     echo $exit_status_code_flag
#     echo "Success"
#     #echo "$content_get_from_request_url
#     if type jq > /dev/null 2>&1; then
#         repo_full_name_get_from_request_url=$(echo "$content_get_from_request_url" | jq '.full_name')
#     else
#         echo "There is no 'jq' command, please install it"
#         exit 0
#     fi
    
#     echo "repo_full_name_get_from_request_url = $repo_full_name_get_from_request_url"
#     echo "\"$url_repoowner/$url_reponame\""
#     if [[ "$repo_full_name_get_from_request_url" == "\"$url_repoowner/$url_reponame\"" ]]; then
#         echo "repo is existed as a remote repo on Hub"
#     else
#         # 占位，除非 Hub 服务器鬼畜了，不然不会出现从 url 获取的 $repo_full_name_get_from_request_url 和 url 中的 "$url_repoowner/$url_reponame" 不一致。
#         :
#     fi
# else
#     exit_status_code_flag=$?
#     echo "exit_status_code_flag = $exit_status_code_flag"
#     echo "Fail"
#     #echo "$content_get_from_request_url"
#     if [[ $exit_status_code_flag -eq 22 ]]; then
#         echo "HTTP 找不到网页，repo 可能是私有仓库或者不存在该仓库。"
#     elif [[ $exit_status_code_flag -eq 7 ]]; then
#         echo "$request_url 拒接连接，被目标服务器限流。"
#     else
#         echo "Curl: exit_status_code_flag = $exit_status_code_flag"
#     fi
# fi

hub_repo_url_var="$1"
hub_repo_url_value="${!hub_repo_url_var}"

if [[ "$hub_repo_url_var" == "DESTINATION_REPO" ]]; then
    if [[ "$CREATE_DST_REPO_NONEXIST" == "true" ]]; then
        nonexist_dst_repo_and_create_dst_repo="true"
    elif [[ "$CREATE_DST_REPO_NONEXIST" == "false" ]]; then
        echo_color green "Please create repo manually"
        exit 0
    else
        echo_color yellow "create_dst_repo_nonexist unknown! must be true or false."
        exit 0
    fi
else
    exit 0
fi

            if [[ "$CREATE_DST_REPO_NONEXIST" == "true" ]]; then
                nonexist_dst_repo_and_create_dst_repo="true"
            elif [[ "$CREATE_DST_REPO_NONEXIST" == "false" ]]; then
                echo_color green "Please create repo manually"
                exit 0
            else
                echo_color yellow "create_dst_repo_nonexist unknown! must be true or false."
                exit 0
            fi

create_repo() {
    :
}

if [[ "$nonexist_dst_repo_and_create_dst_repo" == "true" ]]; then
    create_repo
fi

TODO:
任务1
时间：2020.11.07 05:17
查看 GitHub API 验证用户，看看url中的用户是否能验证，能验证的话就能够创建仓库了，感觉够呛啊
# 使用 git 来判断 url 作为远程仓库是否存在于 hub 上
# check_existence_of_url_for_hub_with_git() {
#     local hub_repo_url_var="$1"
#     local hub_repo_url_value="${!hub_repo_url_var}"

#     if type git > /dev/null 2>&1; then
#         # 使用 `git ls-remote <repo_url>` 来检查仓库是否存在，repo_url 使用 SSH 方式
#         # 该方法需要使用到 SSH 密钥对，比较方便。
#         if { git ls-remote "$hub_repo_url_value" > /dev/null; } 2>&1; then
#             echo_color green "$hub_repo_url_value is existed as a remote repo on Hub"
#         else
#             echo_color red "$hub_repo_url_value is not existed as a remote repo on Hub"
#             if [[ "$hub_repo_url_var" == "DESTINATION_REPO" ]]; then
#                 if [[ "$CREATE_DST_REPO_NONEXIST" == "true" ]]; then
#                     nonexist_dst_repo_and_create_dst_repo="true"
#                 elif [[ "$CREATE_DST_REPO_NONEXIST" == "false" ]]; then
#                     echo_color green "Please create repo manually"
#                     exit 0
#                 else
#                     echo_color yellow "create_dst_repo_nonexist unknown! must be true or false."
#                     exit 0
#                 fi
#             else
#                 exit 0
#             fi
#         fi
#     else
#         echo_color red "There is no 'git' command, please install it"
#         exit 0
#     fi
# }