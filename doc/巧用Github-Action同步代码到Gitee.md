## 巧用 Github Action 同步代码到 Gitee

本文转载自 [Yikun/hub-mirror-action](https://github.com/Yikun/hub-mirror-action) 作者 Yikun 写的关于 Yikun/hub-mirror-action 的博客文章：[巧用Github Action同步代码到Gitee](http://yikun.github.io/2020/01/17/巧用Github-Action同步代码到Gitee/)

### 1. 背景
在开源贡献的代码托管的过程中，我们有时候有需要将 Github 的代码同步到其他远端仓库的需求。具体的，对于我们目前参与的项目来说核心诉求是：以 Github 社区作为主仓，并且定期自动同步到 Gitee 作为镜像仓库。

### 2. 调研
- 结论1: 由于会被 Github 屏蔽，Gitee 的自动同步功能暂时无法支持。

  这个问题在 Gitee 的官方反馈中，[建议github导入的项目能设置定时同步](https://gitee.com/oschina/git-osc/issues/IKH12)提及过，官方的明确答复是不支持。最近又再次和官方渠道求证，由于会被 Github 屏蔽的关系，这个功能不会被支持。本着有轮子用轮子，没轮子造轮子的原则，我们只能选择自己实现。

- 结论2: 靠手动同步存在时效问题，可能会造成部分 commit 的丢失。

  Gitee 本身是提供了手动同步功能的，也算比较好用，但是想想看，如果一个组织下面，发展到有几百上千个项目后，这种机制显然无法解决问题了。因此，我们需要某种计算资源去自动的完成同步。

- 结论3: 目前我们开源的好几个项目（例如 Mindspore, OpenGauss, Kunpeng）都有类似的需求。

  作为一个合格的程序员，为了守住 DRY（don’t repeat yourself，不造重复的轮子）的原则，所以，我们需要实现一个工具，同步简单的配置就可以完成多个项目的同步。

最终结论：我们需要自己实现一个工具，通过某种计算资源自动的去完成周期同步功能。

### 3. 选型
其实调研结论有了后，我们面对的选型就那么几种：

- 使用 crontab 调用脚本周期性同步。这个计算资源得我们自己维护，太重了。排除！
- 使用 Travis、OpenLab 等 CI 资源。这些也可以支持，但是和 Github 的集成性比较差。
- Github Action。无缝的和 Github 集成，处于对新生技术的新鲜感，还是想试一把的，就选他了！关于 Github Action 的详细内容可以直接在官网看到：[https://github.com/features/actions](https://github.com/features/actions)

PS：严格来讲，Github Action 其实是第二种选择的子集，其实就是单纯的想体验一把，并且把我们的业务需求实现了。

### 4. 实现

#### 4.1 GITHUB ACTION 的实现

Github Action 提供了[2种方式](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-actions#types-of-actions)去实现 Action：

- Docker container. 这种方式相当于在 Github 提供的计算资源起个 container，在 container 里面把功能实现。具体的原理大致如下：

  `初始化job` --------> `构建容器` --------> `运行容器` 

- JavaScript. 这种方式相当于在 Github 提供的计算资源上，直接用 JS 脚本去实现功能。

作为以后端开发为主的我们，没太多纠结就选择了第一种类型。关于怎么构建一个 Github 的 Action 可以参考 Github 的官方文档 [Building actions](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/building-actions)。官方文档真的写的非常详细了，并且也通了了 hello-world 级别的入门教程。

#### 4.1 同步的核心代码实现

而最终的关键实现就是，我们需要定义这个容器运行的脚本，原理很简单：

`读取 Github Repo 列表` --------> `更新 Github repo 的代码` --------> `设置远端分支` --------> `Push 到远端分支`

大致就是以上4步：

1. 通过 Github API 读取 Repo 列表。

2. 下载或者更新 Github repo 的代码

3. 设置远端分支

4. 将最新同步的 commit、branch、tag 推送到 Gitee。

关心细节的同学，具体可以参考代码：[https://github.com/Yikun/gitee-mirror-action/blob/master/entrypoint.sh](https://github.com/Yikun/gitee-mirror-action/blob/master/entrypoint.sh)

### 5. 怎么用呢？
举了个简单的例子，我们想将 Github/kunpengcompute 同步到 Gitee/kunpengcompute 上面，需要做的非常简单，只需要2步：

1. 将 Gitee 的`私钥`和 `Token`，上传到项目的 `setting` 的 `Secrets` 中。

    可以参考[官方指引](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets#creating-encrypted-secrets)

2. 新建一个 Github workflow，在这个 workflow 里面使用 Gitee Mirror Action。

    ```yaml
    name: Gitee repos mirror periodic job
    on:
    # 如果需要PR触发把push前的#去掉
    # push:
      schedule:
        # 每天北京时间9点跑
        - cron:  '0 1 * * *'
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
        - name: Mirror the Github organization repos to Gitee.
          uses: Yikun/gitee-mirror-action@v0.01
          with:
            # 必选，需要同步的Github用户（源）
            src: github/Yikun
            # 必选，需要同步到的Gitee的用户（目的）
            dst: gitee/yikunkero
            # 必选，Gitee公钥对应的私钥，https://gitee.com/profile/sshkeys
            dst_key: ${{ secrets.GITEE_PRIVATE_KEY }}
            # 必选，Gitee对应的用于创建仓库的token，https://gitee.com/profile/personal_access_tokens
            dst_token:  ${{ secrets.GITEE_TOKEN }}
            # 如果是组织，指定组织即可，默认为用户user
            # account_type: org
            # 还有黑、白名单，静态名单机制，可以用于更新某些指定库
            # static_list: repo_name
            # black_list: 'repo_name,repo_name2'
            # white_list: 'repo_name,repo_name2'
    ```

    可以参考[鲲鹏库的实现](https://github.com/kunpengcompute/Kunpeng/blob/master/.github/workflows/gitee-repos-mirror.yml)。

    可以在[链接](https://github.com/kunpengcompute/Kunpeng/actions)看到，这个使用 Gitee Mirror Action 的 workflow 已经运行起来后，每个阶段的原理和最终的效果

### 6. 最后

好啦，这篇硬核软文就写到这里，有同步需求的同学，放心使用。更多用法，可以参考 Hub-mirror-action 的主页 Readme。

Github Action 官方链接：[https://github.com/marketplace/actions/hub-mirror-action](https://github.com/marketplace/actions/hub-mirror-action)

代码仓库：[https://github.com/Yikun/hub-mirror-action](https://github.com/Yikun/hub-mirror-action)