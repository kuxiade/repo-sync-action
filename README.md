# 目录

- [特别说明](#特别说明)
- [简单使用](#简单使用)
- [特殊变量](#特殊变量)
  - [`request_tool`(仅作参考)](#request_tool仅作参考)
  - [`process_error_in_advance_flag`(仅作参考)](#process_error_in_advance_flag仅作参考)
  - [`remove_cache_dir_flag`(仅作参考)](#remove_cache_dir_flag仅作参考)
  - [`force_push_flag`(仅作参考)](#force_push_flag仅作参考)
- [参数配置](#参数配置)
  - [`SSH_PRIVATE_KEY`(必需)](#SSH_PRIVATE_KEY必需)
  - [`src_to_dst`(必需)](#src_to_dst必需)
  - [`src_repo_branch`(可选)](#src_repo_branch可选)
  - [`dst_repo_branch`(可选)](#dst_repo_branch可选)
  - [`src_repo_tag`(可选)](#src_repo_tag可选)
  - [`dst_repo_tag`(可选)](#dst_repo_tag可选)
  - [`cache_path`(可选)](#cache_path可选)
  - [`errexit_flag`(可选)](#errexit_flag可选)
  - [`xtrace_debug`(可选)](#xtrace_debug可选)
- [单仓库同步-示例工作流](#单仓库同步-示例工作流)
  - [整个仓库同步](#整个仓库同步)
  - [单分支同步](#单分支同步)
  - [单标签同步](#单标签同步)
  - [删除目的端仓库上的某个分支](#删除目的端仓库上的某个分支)
  - [删除目的端仓库上的某个标签](#删除目的端仓库上的某个标签)
- [多仓库同步-示例工作流](#多仓库同步-示例工作流)
  - [多仓库-整个仓库同步](#多仓库-整个仓库同步)
- [参考资料](#参考资料)

## 特别说明

1. 本仓库 [action - kuxiade/repo-sync-action](https://github.com/kuxiade/repo-sync-action) 作为 Action 时，必需的核心文件实际上只有该仓库根目录下的 `Dockerfile`、`action.yml`、`entrypoint.sh` 这三个文件。其他文件与 Action 功能无关。

2. 工作流文件 [github-to-gitee.yml](./.github/workflows/github-to-gitee.yml) 中的 `jobs.<job_id>.runs-on` 设置为 `ubuntu-latest`，表示其虚拟环境为 `ubuntu-latest`，工作流中的操作就在该 `ubuntu-latest` 中构建执行。本 Action 为 `Docker Action`，`entrypoint.sh` 的执行实际在使用 `Dockerfile` 构建的容器内运行。其中，通过将 `ubuntu-latest` 中的文件夹设置为 Docker 容器的数据卷来存储容器中的数据（比如缓存文件），例如下面复制自示例工作流运行信息中的 `/usr/bin/docker run ... -v "/home/runner/work/repo-sync-action/repo-sync-action":"/github/workspace" ...`，挂载主机（示例工作流中为 ubuntu-latest）的本地目录 /home/runner/work/repo-sync-action/repo-sync-action 到容器的 /github/workspace 目录。

    示例工作流运行信息：在虚拟环境（示例工作流中的虚拟环境为 ubuntu-latest）中 build docker image
    ```shell
    /usr/bin/docker build -t 179394:2c2a9259b7df5e693b0d7e7217b3659a -f "/home/runner/work/repo-sync-action/repo-sync-action/./Dockerfile" "/home/runner/work/repo-sync-action/repo-sync-action"
    ```
    示例工作流运行信息：在虚拟环境（示例工作流中的虚拟环境为 ubuntu-latest）中 run docker container
    ```shell
    /usr/bin/docker run ... \
    -v "/var/run/docker.sock":"/var/run/docker.sock" \
    -v "/home/runner/work/_temp/_github_home":"/github/home" \
    -v "/home/runner/work/_temp/_github_workflow":"/github/workflow" \
    -v "/home/runner/work/_temp/_runner_file_commands":"/github/file_commands" \
    -v "/home/runner/work/repo-sync-action/repo-sync-action":"/github/workspace" \
    ...
    ```


3. `.github/workflows` 目录下面的 .yml 或 .yaml 文件就是该 Action 的示例工作流程文件，其作为测试该仓库作为 Action 工作时是否有效，可以删除 `.github/workflows` 下的所有文件，或者直接删除 `.github` 文件夹，这样做不会影响该仓库作为 Action 的功能。

4. `doc` 文件夹下的文件作为补充文档，对创建 action 来说非必需，同样可以删除 doc 文件夹。

5. `README.md` 作为说明文档，对创建 action 来说非必需，一样可以删除。不过说明文档还是非常重要的，方便其他用户参照使用该 Action。

6. 该 GitHub Action 使用 SSH 方式将源端平台（如 GitHub）上的仓库克隆到 GitHub 的虚拟环境中，然后再通过 SSH 方式将虚拟环境中的仓库推送到目的端平台（如 Gitee）上。

   由于克隆和推送都使用了 SSH 方式，因此，凡是使用了该 Action 的工作流，其所在的仓库必须在仓库 Settings -> Secrets -> New repository secret，将 SSH 私钥添加到其中。

   然后将 SSH 公钥分别添加到源端平台（如 GitHub）和目的端平台（如 Gitee），这样，就能把 GitHub 虚拟环境作为中转站来从源端平台（如 GitHub）同步仓库到目的端平台（如 Gitee）了。

## 简单使用

1. 请用户自行新建一个仓库，将其作为`同步git仓库`的专用仓库。

2. 基于 SSH 配置公钥和私钥。

3. 将私钥添加到步骤1新建的仓库设置中：通过仓库设置中的 Secrets 创建一个 `GITEE_PRIVATE_SSH_KEY` （名称可以自己取，符合规范即可）变量，将私钥内容拷贝到值区域。

4. 将 SSH 公钥分别添加到源端平台（如 GitHub）和目的端平台（如 Gitee），这样，就能把 GitHub 虚拟环境作为中转站来从源端平台（如 GitHub）同步仓库到目的端平台（如 Gitee）了。

5. 参照示例工作流文件 [github-to-gitee.yml](./.github/workflows/github-to-gitee.yml) 的模式，新建用户自己的工作流文件（可直接将示例工作流文件 [github-to-gitee.yml](./.github/workflows/github-to-gitee.yml) 中的内容复制到用户自己的工作流文件中），将用户自己的工作流文件中的源端和目的端设置为用户所需的账号即可。

## 特殊变量

`特殊变量`只作为仓库开发者测试部分功能时使用的，用户不需要关注这个，仅作参考或者请忽略。

### `request_tool`(仅作参考)

request_tool 变量位于 check_existence_of_url_for_hub 函数内，判断远程仓库是否存在时使用的命令工具，其值只能为 "git" 或 "curl"。

### `process_error_in_advance_flag`(仅作参考)

process_error_in_advance_flag 变量位于 entrypoint_main 函数内，值为 "true" 时用于提前判断源端和目的端仓库地址是否合法，避免后面克隆或推送时报错。其值只能为 "true" 或 "false"。

### `remove_cache_dir_flag`(仅作参考)

remove_cache_dir_flag 变量位于 entrypoint_main 函数内，用于判断是否删除缓存目录，其值只能为 "true" 或 "false"。

### `force_push_flag`(仅作参考)

force_push_flag 变量位于 entrypoint_main 函数内，用于是否强制推送，其值只能为 "mirror" 或 "normal"。

## 参数配置

### `SSH_PRIVATE_KEY`(必需)

环境变量，用于目的端上传代码的SSH key，用于上传代码。使用 SSH 协议可以连接远程服务器和服务并向它们验证。 利用 SSH 密钥可以连接 GitHub/Gitee，而无需在每次访问时都提供用户名和个人访问令牌。可参考：[服务器上的-Git-生成-SSH-公钥](https://git-scm.com/book/zh/v2/服务器上的-Git-生成-SSH-公钥) 和 [使用 SSH 连接到 GitHub](https://help.github.com/articles/generating-ssh-keys)

1. 我们需要使用 `ssh-keygen` 命令生成一对公钥和私钥，注意命名，然后将公钥（***.pub）的内容添加到 `Github` 和 `Gitee` 的可信名单里。

2. 接下来，在对应的仓库 setting 的 secrets 中添加 `GITEE_PRIVATE_SSH_KEY`,内容为之前使用 `ssh-keygen` 命令生成的私匙。

>注意：action 的虚拟机通过私钥和 Gitee 的公钥进行用户验证，验证通过即可通信。这里的公钥和私钥为一对密钥对，可以使用 `ssh-keygen` 命令生成

>注意：其实，上面步骤1中如果不将公钥添加到 Github 的可信名单里，则无法免密上下载私有库代码，添加公钥到GitHub更好。

这样子，每次 pull 之后，github 的源端仓库会自动推送到 gitee 的目的仓库。这里多加了时间触发，到某个时间会自动同步。

建议先在 `gitee` 上导入 `github` 的项目，这样就可以使用 `gitee` 的强制同步功能了（直接点击，动动手就可以同步）。

相互通信的简单示意图如下：

`GitHub(repository secret -> SSH private key)` --------> `虚拟机`(从 GitHub repository secret 获取到 SSH private key 并复制为自己的 SSH private key) <----(通过相对应的 SSH key 公私密钥对来相互通信)----> `Gitee(SSH public key)`

### `src_to_dst`(必需)

源端仓库链接（必须为 SSH URLs）到目的端仓库链接（必须为 SSH URLs）的映射关系列表。`src repo url` 和 `src repo url`之间可以使用**连续的非空白字符**作为分隔符或者直接使用**单个或连续的空格**作为分隔符（最好在视觉上 url 和分隔符有区分度），格式如下：

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync from Github to Gitee with repo-sync-action
  # 终止进程之前运行该步骤的最大分钟数。
  timeout-minutes: 30
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:github/docs.git ---> git@gitee.com:kuxiade/github-docs.git
      git@github.com:microsoft/vscode-dev-containers.git . git@gitee.com:kuxiade/vscode-dev-containers.git
      git@github.com:hlissner/doom-emacs.git  git@gitee.com:kuxiade/doom-emacs.git
      git@github.com:manateelazycat/color-rg.git <+..+--> git@gitee.com:emacs-hub/color-rg.git
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

### `src_repo_branch`(可选)

需要被同步的源端仓库中的分支，格式只能为 "dev" 或者 "refs/remotes/origin/dev"，表示 dev 分支，'dev' 可以替换为其他分支名。默认值为 "refs/remotes/origin/*"，表示所有分支。

### `dst_repo_branch`(可选)

需要同步到的目的端仓库中的分支，格式只能为 "dev" 或者 "refs/heads/dev"，表示 dev 分支，'dev' 可以替换为其他分支名。默认值为 "refs/heads/*"，表示所有分支。

> 注意， `src_repo_branch` 和 `dst_repo_branch` 均为默认值时，表示同步所有分支。

> 注意，当 `src_repo_branch` 为 "" 而 `dst_repo_branch` 为 "dev" 或者 "refs/heads/dev" 时，表示删除目的端仓库的 `dev` 分支。

### `src_repo_tag`(可选)

需要被同步的源端仓库中的标签，格式只能为 "v1" 或者 "refs/tags/v1"，表示 v1 标签，'v1' 可以替换为其他标签名。默认值为 "refs/tags/*"，表示所有标签。

### `dst_repo_tag`(可选)

需要同步到的目的端仓库中的标签，格式只能为 "v1" 或者 "refs/tags/v1"，表示 v1 标签，'v1' 可以替换为其他标签名。默认值为 "refs/tags/*"，表示所有标签。

> 注意， `src_repo_tag` 和 `dst_repo_tag` 均为默认值时，表示同步所有标签。

> 注意，当 `src_repo_tag` 为 "" 而 `dst_repo_tag` 为 "v1" 或者 "refs/tags/v1" 时，表示删除目的端仓库的 `v1` 标签。

### `cache_path`(可选)

默认值为 '/github/workspace/repo-mirror-cache'

`cache_path` 选项需要搭配 [actions/cache](https://github.com/actions/cache) 使用，配置后会对同步的仓库内容进行缓存，缩短仓库同步时间。有关缓存相关，请阅读[缓存依赖项以加快工作流程](https://docs.github.com/cn/free-pro-team@latest/actions/guides/caching-dependencies-to-speed-up-workflows)

### `request_tool`(可选)

判断仓库是否存在所使用的工具，其值必须为 "git" 或者 "curl"，默认值为 "git"。由于 curl 访问 GitHub API 在单位时间内有次数限制，其功能代码仅作参考。故最好使用默认值，即不要设置该参数为 "curl"。

### `errexit_flag`(可选)

为 entrypoint.sh 设置 'set -e'，其值必须为 "true" 或者 "false"，默认值为 "true"。如果不知其作用，请勿设置该参数。

### `xtrace_debug`(可选)

为 entrypoint.sh 设置 'set -x'，其值必须为 "true" 或者 "false"，默认值为 "false"。如果不知其作用，请勿设置该参数。


## 单仓库同步-示例工作流

详细的使用示例见：[github-to-gitee.yml](./.github/workflows/github-to-gitee.yml)。

### 整个仓库同步

整个仓库同步，包含同步所有分支和所有标签

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync Github:github/docs to Gitee with repo-sync-action
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    # ssh_private_key: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
    # 需要被同步的源端仓库
    src_repo_url: "git@github.com:github/docs.git"
    # 需要同步到的目的仓库
    dst_repo_url: "git@gitee.com:kuxiade/github-docs.git"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

### 单分支同步

同步 [git@github.com:microsoft/vscode-dev-containers.git](https://github.com/microsoft/vscode-dev-containers) 上的 `bowdenk7` 分支到 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支

[git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支不存在的话，会自动创建 `csharp-update` 分支

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:microsoft/vscode-dev-containers.git ---> git@gitee.com:kuxiade/vscode-dev-containers.git
    src_repo_branch: "refs/remotes/origin/bowdenk7"
    dst_repo_branch: "refs/heads/csharp-update"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

### 单标签同步

同步 [git@github.com:microsoft/vscode-dev-containers.git](https://github.com/microsoft/vscode-dev-containers) 上的 `v0.150.0` 标签到 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.148.0` 标签

[git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.148.0` 标签不存在的话，会自动创建 `v0.148.0` 标签

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:microsoft/vscode-dev-containers.git ---> git@gitee.com:kuxiade/vscode-dev-containers.git
    #src_repo_branch: "refs/remotes/origin/bowdenk7"
    src_repo_tag: "refs/tags/v0.150.0"
    #dst_repo_branch: "refs/heads/csharp-update"
    dst_repo_tag: "v0.148.0"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

### 删除目的端仓库上的某个分支

删除 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:microsoft/vscode-dev-containers.git ---> git@gitee.com:kuxiade/vscode-dev-containers.git
    src_repo_branch: ""
    dst_repo_branch: "refs/heads/csharp-update"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

### 删除目的端仓库上的某个标签

删除 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.150.0` 标签

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:microsoft/vscode-dev-containers.git ---> git@gitee.com:kuxiade/vscode-dev-containers.git
    #src_repo_branch: "refs/remotes/origin/bowdenk7"
    src_repo_tag: ""
    #dst_repo_branch: "refs/heads/csharp-update"
    dst_repo_tag: "v0.150.0"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

## 多仓库同步-示例工作流

详细的使用示例见：[github-to-gitee.yml](./.github/workflows/github-to-gitee.yml)。

### 多仓库-整个仓库同步

对当前 Action 而言，所有仓库都必须是整个仓库同步（包含同步所有分支和所有标签），无法为每个仓库单独指定分支或标签来同步。如果像上面那样指定分支或标签，那么就表示所有分支都如此。但是，不是所有分支都有同一个指定的分支或标签的。故，建议需要指定分支或标签的同步请使用上面的单仓库同步的方式。

$ cat .github/workflows/github-to-gitee.yml
```yaml
- name: Sync from Github to Gitee with repo-sync-action
  # 终止进程之前运行该步骤的最大分钟数。
  timeout-minutes: 30
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # 源端仓库链接 到 目的端仓库链接 的映射关系。
    src_to_dst: |
      git@github.com:github/docs.git ---> git@gitee.com:kuxiade/github-docs.git
      git@github.com:microsoft/vscode-dev-containers.git ---> git@gitee.com:kuxiade/vscode-dev-containers.git
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    # 'cache_path' 与 'steps.cacheSrcRepos.with.path' 值保持一致
    cache_path: /github/workspace/${{ github.job }}-cache
```

## 参考资料

- 本地（从官方拉取的）参考文档：[简体中文](./doc/creating-a-docker-container-action.zh-CN.md) | [English](./doc/creating-a-docker-container-action.md)

- 官方中文参考文档：[创建 Docker 容器操作](https://docs.github.com/cn/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  中文源文件见：[GitHub](https://github.com/github/docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方英文参考文档：[Creating a Docker container action](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  英文源文件见：[GitHub](https://github.com/github/docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方创建 Docker Action 的参考示例：[actions/hello-world-docker-action](https://github.com/actions/hello-world-docker-action)

- [复制（镜像）仓库](./doc/复制仓库.md)

  官方提供的复制仓库的方法。
  
  官方文档请见：[github/doc - 复制仓库](https://docs.github.com/cn/free-pro-team@latest/github/creating-cloning-and-archiving-repositories/duplicating-a-repository)

- [同步的几种实现方式](./doc/同步的几种实现方式.md)

  先从源端克隆仓库到“中转站”，再从“中转站”推送到目的端。