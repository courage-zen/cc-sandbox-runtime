# cc-sandbox-runtime

Docker 容器化的 Claude Code + multica agent 沙箱运行时镜像（自 agents-with-multica base 部分迁移）。

## 项目结构

- `base/` — 镜像构建（Claude Code via npm on Node.js 22 + cc-proxy + multica + multica-stdio-mcp-proxy + bubblewrap/socat/ripgrep 沙箱依赖）
- `versions.yaml` — 镜像与依赖版本号（单一事实源）
- `build.sh` — 本地构建脚本
- `config/` — 配置模板（example 文件 + seccomp profile，不含敏感数据）
- `docs/` — sandbox 方案与部署文档（本地保留，不入库，见 .gitignore）

## 镜像架构

```
node:22-bookworm-slim → cc-sandbox-runtime
```

镜像内：multica、multica-stdio-mcp-proxy、cc-proxy、claude-code，以及
bwrap/socat/ripgrep（Claude Code 原生沙箱运行时依赖）。非 root `agent` 用户（uid 1001）。

## 版本管理

`versions.yaml` 集中管理所有版本：

```yaml
project:
  version: "1.0.0"
cc_proxy:
  version: "0.4.1"
  repo: "courage-zen/cc-proxy"
multica:
  version: "0.4.43"
  repo: "multica-ai/multica"
multica_stdio_mcp_proxy:
  version: "0.1.0"
  repo: "courage-zen/multica-stdio-mcp-proxy"
  # repo 为 private：CI 通过 CC_PROXY_TOKEN secret 下载（与 cc-proxy 共用）
claude_code:
  version: "2.1.296"
```

`project.version` 是镜像版本号，升级时 bump 这一个字段。Dockerfile 的 ARG
无默认值，版本必须通过 `--build-arg` 从 `versions.yaml` 传入，禁止硬编码。

**私有依赖**：`cc-proxy` 和 `multica-stdio-mcp-proxy` 是 private repo 的 GitHub
Release。构建前由 `build.sh`（本地，用已认证的 `gh`）/ CI（用 `CC_PROXY_TOKEN`
secret）下载到 `binaries/${ARCH}/`，Dockerfile 只 COPY。凭证不会进入任何镜像层。

## 构建命令

```bash
# 默认 amd64
./build.sh

# arm64
./build.sh arm64
```

## 发布流程

1. 更改版本号（`versions.yaml` 中的 `project.version` 及需要的组件版本）
2. commit + push to main → CI 自动构建双架构镜像并推送 GHCR
3. 打 git tag 触发 Release 发布：
   ```
   git tag v{project.version}
   git push origin v{project.version}
   ```
4. CI 创建 GitHub Release，附 `cc-sandbox-runtime-<arch>.tar.gz` 双架构离线包
