# 目录

- [特别说明](#特别说明)
- [简单使用](#简单使用)
- [参数配置](#参数配置)
  - [`SSH_PRIVATE_KEY`(必需)](#SSH_PRIVATE_KEY必需)
  - [`src_repo_url`(必需)](#src_repo_url必需)
  - [`dst_repo_url`(必需)](#dst_repo_url必需)
  - [`src_repo_branch`(可选)](#src_repo_branch可选)
  - [`dst_repo_branch`(可选)](#dst_repo_branch可选)
  - [`src_repo_tag`(可选)](#src_repo_tag可选)
  - [`dst_repo_tag`(可选)](#dst_repo_tag可选)
  - [`cache_path`(可选)](#cache_path可选)
  - [`request_tool`(可选)](#request_tool可选)
  - [`errexit_flag`(可选)](#errexit_flag可选)
  - [`xtrace_debug`(可选)](#xtrace_debug可选)
- [示例workflow](#示例workflow)
  - [整个仓库同步](#整个仓库同步)
  - [单分支同步](#单分支同步)
  - [单标签同步](#单标签同步)
  - [删除目的端仓库上的某个分支](#删除目的端仓库上的某个分支)
  - [删除目的端仓库上的某个标签](#删除目的端仓库上的某个标签)
- [参考资料](#参考资料)

## 特别说明

1. 本仓库作为 [action - kuxiade/repo-sync-action](https://github.com/kuxiade/repo-sync-action) Action 时，必需的核心文件实际上只有该仓库根目录下的 `Dockerfile`、`action.yml`、`entrypoint.sh` 这三个文件。其他文件与 Action 功能无关。

2. `.github/workflows` 目录下面的 .yml 或 .yaml 文件就是该 Action 的示例工作流程文件，其作为测试该仓库作为 Action 工作时是否有效，可以删除 `.github/workflows` 下的所有文件，或者直接删除 `.github` 文件夹，这样做不会影响该仓库作为 Action 的功能。

3. `doc` 文件夹下的文件作为补充文档，对创建 action 来说非必需，同样可以删除 doc 文件夹。

4. `README.md` 作为说明文档，对创建 action 来说非必需，一样可以删除。不过说明文档还是非常重要的，方便其他用户参照使用该 Action。

5. 该 GitHub Action 使用 SSH 方式将源端平台（如 GitHub）上的仓库克隆到 GitHub 的虚拟环境中，然后再通过 SSH 方式将虚拟环境中的仓库推送到目的端平台（如 Gitee）上。

   由于克隆和推送都使用了 SSH 方式，因此，凡是使用了该 Action 的工作流，其所在的仓库必须在仓库 Settings -> Secrets -> New repository secret，将 SSH 私钥添加到其中。

   然后将 SSH 公钥分别添加到源端平台（如 GitHub）和目的端平台（如 Gitee），这样，就能把 GitHub 虚拟环境作为中转站来从源端平台（如 GitHub）同步仓库到目的端平台（如 Gitee）了。

## 简单使用

1. 请用户自行新建一个仓库，将其作为`同步git仓库`的专用仓库。

2. 基于 SSH 配置公钥和私钥。

3. 将私钥添加到步骤1新建的仓库设置中：通过仓库设置中的 Secrets 创建一个 `GITEE_PRIVATE_SSH_KEY` （名称可以自己取，符合规范即可）变量，将私钥内容拷贝到值区域。

4. 将 SSH 公钥分别添加到源端平台（如 GitHub）和目的端平台（如 Gitee），这样，就能把 GitHub 虚拟环境作为中转站来从源端平台（如 GitHub）同步仓库到目的端平台（如 Gitee）了。

5. 参照示例工作流文件[repo-sync-action-cache-test.yml](./.github/workflows/repo-sync-action-cache-test.yml)的模式，新建用户自己的工作流文件（可直接将示例工作流文件[repo-sync-action-cache-test.yml](./.github/workflows/repo-sync-action-cache-test.yml)中的内容复制到用户自己的工作流文件中），将用户自己的工作流文件中的源端和目的端设置为用户所需的账号即可。


## 参数配置

### `SSH_PRIVATE_KEY`(必需)

环境变量，用于目的端上传代码的SSH key，用于上传代码。

1. 我们需要使用 `ssh-keygen` 命令生成一对公钥和私钥，注意命名，然后将公钥（***.pub）的内容添加到 `Github` 和 `Gitee` 的可信名单里。

2. 接下来，在对应的仓库 setting 的 secrets 中添加 `GITEE_PRIVATE_SSH_KEY`,内容为之前使用 `ssh-keygen` 命令生成的私匙。

>注意：action 的虚拟机通过私钥和 Gitee 的公钥进行用户验证，验证通过即可通信。这里的公钥和私钥为一对密钥对，可以使用 `ssh-keygen` 命令生成

>注意：其实，上面步骤1中如果不将公钥添加到 Github 的可信名单里，则无法免密上下载私有库代码，添加公钥到GitHub更好。

这样子，每次 pull 之后，github 的源端仓库会自动推送到 gitee 的目的仓库。这里多加了时间触发，到某个时间会自动同步。

建议先在 `gitee` 上导入 `github` 的项目，这样就可以使用 `gitee` 的强制同步功能了（直接点击，动动手就可以同步）。

相互通信的简单示意图如下：

`GitHub(repository secret -> SSH private key)` --------> `虚拟机`(从 GitHub repository secret 获取到 SSH private key 并复制为自己的 SSH private key) <----(通过相对应的 SSH key 公私密钥对来相互通信)----> `Gitee(SSH public key)`

### `src_repo_url`(必需)

需要被同步的源端仓库（必须为 SSH URLs）。

### `dst_repo_url`(必需)

需要同步到的目的端仓库（必须为 SSH URLs）。

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

默认值为 '/github/workspace/mirror-repo-cache'

`cache_path` 选项需要搭配 [actions/cache](https://github.com/actions/cache) 使用，配置后会对同步的仓库内容进行缓存，缩短仓库同步时间。有关缓存相关，请阅读[缓存依赖项以加快工作流程](https://docs.github.com/cn/free-pro-team@latest/actions/guides/caching-dependencies-to-speed-up-workflows)

### `request_tool`(可选)

判断仓库是否存在所使用的工具，其值必须为 "git" 或者 "curl"，默认值为 "git"。由于 curl 访问 GitHub API 在单位时间内有次数限制，其功能代码仅作参考。故最好使用默认值，即不要设置该参数为 "curl"。

### `errexit_flag`(可选)

为 entrypoint.sh 设置 'set -e'，其值必须为 "true" 或者 "false"，默认值为 "true"。如果不知其作用，请勿设置该参数。

### `xtrace_debug`(可选)

为 entrypoint.sh 设置 'set -x'，其值必须为 "true" 或者 "false"，默认值为 "false"。如果不知其作用，请勿设置该参数。


## 示例workflow

详细的使用示例见：[repo-sync-action-cache-test.yml](./.github/workflows/repo-sync-action-cache-test.yml)。

### 整个仓库同步

整个仓库同步，包含同步所有分支和所有标签

$ cat .github/workflows/repo-sync-action-cache-test.yml
```yaml
- name: Mirror Github:github/docs to Gitee with repo-sync-action
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
    cache_path: /github/workspace/mirror-repo-cache
```

### 单分支同步

同步 [git@github.com:microsoft/vscode-dev-containers.git](https://github.com/microsoft/vscode-dev-containers) 上的 `bowdenk7` 分支到 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支

[git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支不存在的话，会自动创建 `csharp-update` 分支

$ cat .github/workflows/repo-sync-action-cache-test.yml
```yaml
- name: Mirror Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    # ssh_private_key: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
    # 需要被同步的源端仓库
    src_repo_url: "git@github.com:microsoft/vscode-dev-containers.git"
    src_repo_branch: "refs/remotes/origin/bowdenk7"
    # 需要同步到的目的仓库
    dst_repo_url: "git@gitee.com:kuxiade/vscode-dev-containers.git"
    dst_repo_branch: "refs/heads/csharp-update"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    cache_path: /github/workspace/mirror-repo-cache
```

### 单标签同步

同步 [git@github.com:microsoft/vscode-dev-containers.git](https://github.com/microsoft/vscode-dev-containers) 上的 `v0.150.0` 标签到 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.148.0` 标签

[git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.148.0` 标签不存在的话，会自动创建 `v0.148.0` 标签

$ cat .github/workflows/repo-sync-action-cache-test.yml
```yaml
- name: Mirror Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    # ssh_private_key: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
    # 需要被同步的源端仓库
    src_repo_url: "git@github.com:microsoft/vscode-dev-containers.git"
    #src_repo_branch: "refs/remotes/origin/bowdenk7"
    src_repo_tag: "refs/tags/v0.150.0"
    # 需要同步到的目的仓库
    dst_repo_url: "git@gitee.com:kuxiade/vscode-dev-containers.git"
    #dst_repo_branch: "refs/heads/csharp-update"
    dst_repo_tag: "v0.148.0"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    cache_path: /github/workspace/mirror-repo-cache
```

### 删除目的端仓库上的某个分支

删除 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `csharp-update` 分支

$ cat .github/workflows/repo-sync-action-cache-test.yml
```yaml
- name: Mirror Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    # ssh_private_key: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
    # 需要被同步的源端仓库
    src_repo_url: "git@github.com:microsoft/vscode-dev-containers.git"
    src_repo_branch: ""
    # 需要同步到的目的仓库
    dst_repo_url: "git@gitee.com:kuxiade/vscode-dev-containers.git"
    dst_repo_branch: "refs/heads/csharp-update"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    cache_path: /github/workspace/mirror-repo-cache
```

### 删除目的端仓库上的某个标签

删除 [git@gitee.com:kuxiade/vscode-dev-containers.git](https://gitee.com/kuxiade/vscode-dev-containers) 上的 `v0.150.0` 标签

$ cat .github/workflows/repo-sync-action-cache-test.yml
```yaml
- name: Mirror Github:microsoft/vscode-dev-containers to Gitee with repo-sync-action
  # 将 continue-on-error 设置为 true，表示即使当前 step 报错，后续的 steps 也能继续执行。
  continue-on-error: true
  uses: ./.
  env:
    # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    SSH_PRIVATE_KEY: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
  with:
    # # 用于目的端上传代码的SSH key，用于从gituhb虚拟机上传代码到目的端仓库。
    # ssh_private_key: ${{ secrets.GITEE_PRIVATE_SSH_KEY }}
    # 需要被同步的源端仓库
    src_repo_url: "git@github.com:microsoft/vscode-dev-containers.git"
    #src_repo_branch: "refs/remotes/origin/bowdenk7"
    src_repo_tag: ""
    # 需要同步到的目的仓库
    dst_repo_url: "git@gitee.com:kuxiade/vscode-dev-containers.git"
    #dst_repo_branch: "refs/heads/csharp-update"
    dst_repo_tag: "v0.150.0"
    # cache_path (optional) 将代码缓存在指定目录，用于与actions/cache配合以加速镜像过程。
    cache_path: /github/workspace/mirror-repo-cache
```

## 参考资料

- 本地（从官方拉取的）参考文档：[简体中文](./doc/creating-a-docker-container-action.zh-CN.md) | [English](./doc/creating-a-docker-container-action.md)

- 官方中文参考文档：[创建 Docker 容器操作](https://docs.github.com/cn/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  中文源文件见：[GitHub](https://github.com/github/docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方英文参考文档：[Creating a Docker container action](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  英文源文件见：[GitHub](https://github.com/github/docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方参考示例：[actions/hello-world-docker-action](https://github.com/actions/hello-world-docker-action)