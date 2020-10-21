# Hello world docker action

This action prints "Hello World" or "Hello" + the name of a person to greet to the log.

- 本地（从官方拉取的）参考文档：[简体中文](./doc/creating-a-docker-container-action.zh-CN.md) | [English](./doc/creating-a-docker-container-action.md)

- 官方中文参考文档：[创建 Docker 容器操作](https://docs.github.com/cn/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  中文源文件见：[GitHub](https://github.com/github/docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/translations/zh-CN/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方英文参考文档：[Creating a Docker container action](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action)

  英文源文件见：[GitHub](https://github.com/github/docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md) 或 [Gitee 镜像](https://gitee.com/kuxiade/github-docs/blob/main/content/actions/creating-actions/creating-a-docker-container-action.md)

- 官方参考示例：[actions/hello-world-docker-action](https://github.com/actions/hello-world-docker-action)

## Inputs

### `who-to-greet`

**Required** The name of the person to greet. Default `"World"`.

## Outputs

### `time`

The time we greeted you.

## Example usage

```yaml
uses: kuxiade/hello-world-docker-action@v1
with:
  who-to-greet: 'Mona the Octocat'
```

## 注意
1. 本仓库 [action - kuxiade/hello-world-docker-action](https://github.com/kuxiade/hello-world-docker-action) 作为 action 时，必需的有效文件实际上只有该仓库根目录下的 `Dockerfile`、`action.yml`、`entrypoint.sh` 这三个文件。

2. `.github/workflows` 目录下的文件只是作为测试该仓库作为 action 工作时是否有效，可以删除 `.github/workflows` 下的所有文件，或者直接删除 `.github` 文件夹，这样做不会影响该仓库作为 action 的功能。

3. doc 文件夹下的文件作为补充文档，对创建 action 来说非必需，同样可以删除 doc 文件夹。

4. README.md 作为说明文档，对创建 action 来说非必需，一样可以删除。不过说明文档还是非常重要的，方便其他用户使用该 action。