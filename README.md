# dev-container

跨平台（Mac / Linux）多环境 Docker 开发套件。支持 Rust、Go、Node、Python 等环境独立管理、按需启动。

## 项目定位

这个仓库只负责管理本机或服务器上的语言开发容器：初始化环境、启动/停止容器、进入容器、共享工作区和开发者配置。

它不负责某个具体项目的编译、测试、启动或发布。`workspace/` 下可以放多个项目，每个项目应该在自己的目录里保留自己的 `Makefile`、`package.json`、`Cargo.toml`、`go.mod`、`pyproject.toml` 等工程配置。

## 目录结构

```
dev-container/
├── envs/                  # 所有环境定义（集中归集）
│   ├── common.yml         # 共享网络、卷、基础配置
│   ├── Dockerfile.base    # 各语言环境共用的基础 Dockerfile
│   ├── rust/
│   │   └── docker-compose.yml
│   ├── go/
│   ├── node/
│   └── python/
├── scripts/               # 统一操作脚本
│   ├── init.sh            # 初始化指定环境
│   ├── enter.sh           # 进入指定环境
│   └── tmux.sh            # 进入/附着指定环境的 Tmux 会话
├── docs/                  # 示例文档
│   └── rust-hello-api.md  # Rust hello-api 与 Cargo 包管理示例
├── workspace/             # 代码工作区（按项目分）
│   └── hello-api/
├── volumes/               # 容器数据卷（缓存、编译产物）
│   ├── rust-cargo/
│   ├── rust-target/
│   ├── go-pkg/
│   ├── node-cache/
│   └── ...
├── shared/                # 跨容器共享配置（所有容器共用）
│   ├── .gitconfig
│   ├── .ssh/
│   ├── .bashrc
│   ├── .vimrc
│   └── .tmux.conf
├── .env
├── Makefile
└── README.md
```

`volumes/` 下的语言缓存目录由 `make init` 按需创建，属于运行时数据；仓库只保留目录约定，不提交缓存内容。

## 快速开始

```bash
# 1. 初始化（生成 .env、构建镜像）
make init

# 2. 启动 Rust 环境
make up

# 3. 进入开发
make enter

# 容器内
cargo new /workspace/hello-api --bin
cd /workspace/hello-api
cargo run
```

更完整的 Cargo 包管理示例见 [docs/rust-hello-api.md](docs/rust-hello-api.md)。

## 多环境操作

### 初始化多个环境
```bash
make init ENV=rust,go       # 同时初始化 Rust 和 Go
make init ENV=all           # 初始化所有环境（rust, go, node, python）
```

### 启动多个环境
```bash
make up ENV=rust,go         # 同时启动 Rust 和 Go 容器
make up ENV=all             # 启动全部
```

### 进入指定环境
```bash
make enter ENV=go           # 进入 Go 容器
make enter ENV=node         # 进入 Node 容器
make enter ENV=python       # 进入 Python 容器
make tmux ENV=rust          # 进入/附着 Rust 容器里的 Tmux 会话
```

### 停止环境
```bash
make down ENV=rust,go
make down ENV=all
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `make init` | 初始化默认环境（rust） |
| `make init ENV=all` | 初始化所有环境 |
| `make up` | 启动默认环境 |
| `make up ENV=rust,go` | 启动多个环境 |
| `make down` | 停止默认环境 |
| `make enter` | 进入默认环境 |
| `make enter ENV=go` | 进入指定环境 |
| `make tmux` | 进入/附着默认环境的 Tmux 会话 |
| `make tmux ENV=go` | 进入/附着指定环境的 Tmux 会话 |
| `make logs` | 查看容器日志 |
| `make clean` | 清理所有镜像和容器 |
| `make help` | 显示所有命令 |

项目的编译、测试、启动命令建议进入对应环境后，在具体项目目录内执行，例如：

```bash
make enter ENV=node
cd /workspace/hello-api/web
npm test
```

## 核心设计

### 1. 环境集中归集（envs/）

所有环境定义集中在 `envs/` 下。每个环境有自己的 `docker-compose.yml`，共同复用 `envs/Dockerfile.base`：

- **新增环境**：新增 `envs/<name>/docker-compose.yml`，指定 `BASE_IMAGE` 和环境特有挂载即可
- **公共配置**：`envs/common.yml` 定义共享网络、shared 挂载、基础容器行为，各环境通过 `extends` 继承
- **独立生命周期**：只启动你需要的环境，2 核服务器也不会爆
- **自动发现环境**：`make init ENV=all`、`make up ENV=all` 和 `make clean` 会从 `envs/*/docker-compose.yml` 自动发现环境，不需要改 Makefile

### 2. 按项目分 workspace

`workspace/` 不按语言分，而是按项目分：

```
workspace/
├── hello-api/          # 你的项目
│   ├── src/            # Rust 后端
│   ├── web/            # 前端
│   └── scripts/        # Python 脚本
└── another-service/
```

所有容器都把 `workspace/` 挂载到 `/workspace`。你在 **Rust 容器** 里编译 `hello-api/src/`，在 **Node 容器** 里跑 `hello-api/web/`，在 **Python 容器** 里跑 `hello-api/scripts/`，**同一套代码，不同环境处理不同部分**。

为了避免不同项目互相污染，公共缓存尽量挂到语言工具自己的缓存目录。例如 Node 的 npm 缓存在 `/home/dev/.npm`，Rust 的 target 目录挂到 `/workspace/.cache/rust-target`。项目自己的依赖目录和构建命令仍由项目本身管理。

### 3. 共享 shared（跨容器身份一致）

`shared/` 目录存放跨容器共用的开发者配置和身份凭证：

| 文件 | 作用 |
|------|------|
| `.gitconfig` | Git 身份（名字、邮箱） |
| `.ssh/` | SSH 密钥，用于 `git clone` 私有仓库 |
| `.bashrc` | Shell 别名、提示符风格 |
| `.vimrc` | Vim 编辑器配置 |
| `.tmux.conf` | Tmux 按键、鼠标、状态栏和历史配置 |

**为什么要共享？**

容器每次重建都是干净的。没有这些配置，你进容器后：

- `git commit` 报错 "Please tell me who you are"
- `git clone git@github.com:...` 权限拒绝
- vim 没有语法高亮，bash 没有 `ll` 别名

通过 `envs/common.yml`，所有容器启动时自动把 `shared/` 中的配置挂载到 `/home/dev/`，**一次配置，所有环境生效**。

**使用方式：**

1. 修改 `shared/.gitconfig` 填上你的真实姓名和邮箱
2. 把你的 SSH 私钥复制到 `shared/.ssh/`（已加入 `.gitignore`，不会提交）
3. 调整 `shared/.bashrc`、`.vimrc`、`.tmux.conf` 符合你的习惯
4. 所有容器自动继承

### 4. Tmux 会话

基础镜像默认安装 `tmux`，并把 `shared/.tmux.conf` 挂载到容器内 `/home/dev/.tmux.conf`。普通 shell 入口仍然是：

```bash
make enter ENV=rust
```

如果希望进入后直接使用可恢复的 Tmux 会话：

```bash
make tmux ENV=rust
```

`make tmux` 会在容器未运行时自动启动容器，然后执行 `tmux new-session -A -s <env>`：已有会话会直接附着，没有会话会新建。默认会话名等于环境名，也可以临时指定：

```bash
TMUX_SESSION=work make tmux ENV=node
```

### 5. 用户身份设计

容器内统一使用 `dev` 用户运行，而非 root：

- **UID/GID 对齐**：`init.sh` 会把容器内 `dev` 用户使用的 `DEV_UID` 和 `DEV_GID` 写入 `.env`，`Dockerfile.base` 构建时用这组数字创建容器内的 `dev` 用户
- **sudo 可用**：`dev` 拥有免密 sudo 权限，需要 root 时可以直接执行 `sudo apt install xxx`
- **安全习惯**：日常开发不用 root，减少误操作风险；需要系统级权限时再显式使用 `sudo`

**为什么要设置 UID/GID？**

Linux 文件权限认的是数字 UID/GID，而不是用户名。`workspace/` 是宿主机目录挂载到容器里的，如果容器内用户和宿主机用户的 UID/GID 不一致，容器创建的文件在宿主机上可能变成“别的用户”的文件，导致编辑器无法保存、`rm`/`git clean` 权限不足，或者 `node_modules`、`target`、缓存目录权限混乱。

Mac 用户常见 UID/GID 是 `501/20`，Linux 普通用户常见是 `1000/1000`。Docker Desktop for Mac 会做一层文件共享转换，所以问题有时不明显；但在 Colima、远程 Linux、CI 或直接使用 Linux Docker 时，UID/GID 不一致会更直接地暴露出来。因此初始化时会自动写入合适的 `DEV_UID/DEV_GID`，让容器内 `dev` 用户尽量像“宿主机当前用户”一样写文件。

如果你在 Linux 服务器上直接用 `root` 用户运行，宿主机的 `id -u` 和 `id -g` 会是 `0/0`。容器内 `dev` 不能使用 `0/0`，否则就等于把开发用户变成 root，还会触发基础镜像里 root 用户无法被改名的问题。因此 `init.sh` 检测到宿主机是 root 时，会自动把容器内 `dev` 固定为 `1000/1000`，并整理 `workspace/`、`volumes/` 的目录权限。

**sudo 免密是什么意思？**

`Dockerfile.base` 里给 `dev` 用户配置了 `NOPASSWD` sudo。也就是说，容器里执行 `sudo apt install curl` 这类命令时不需要输入密码。这样既能保持日常开发不使用 root，又能在需要临时安装系统包时方便提权。这个设置只面向本地开发容器，不建议照搬到生产服务器。

## 跨平台说明

### Mac

- `init.sh` 自动检测 UID（通常为 `501`）写入 `.env`
- `Dockerfile.base` 创建同 UID 的 `dev` 用户，避免 Docker Desktop 挂载后的文件权限问题
- 如果使用 Colima：`colima start --cpu 4 --memory 8`

### Linux 服务器

- 普通用户 UID/GID 通常为 `1000/1000`，脚本自动适配
- 如果直接用 root 运行，脚本会让容器内 `dev` 使用 `1000/1000`，避免使用 `0/0`
- 旧版 `.env` 中的 `UID/GID` 会在初始化时迁移为 `DEV_UID/DEV_GID`

## 初始化问题排查

`make init` 会先从 Docker Hub 拉取基础镜像，例如 `rust:latest`、`golang:latest`、`node:lts`、`python:3.12`。如果看到类似下面的错误：

```text
failed to resolve source metadata for docker.io/library/rust:latest
failed to do request ... production.cloudfront.docker.com ... EOF
```

这通常是 Docker Hub 或其 CDN 访问失败，不是 compose 配置错误。可以先单独验证拉取：

```bash
docker pull rust:latest
```

如果单独拉取也失败，优先检查网络、代理或 Docker Desktop/Colima 的 registry mirror 配置。配置好镜像源后再重新执行：

```bash
make init ENV=rust
```

`Dockerfile.base` 中的 `BASE_IMAGE` 只是为了让不同语言环境复用同一个 Dockerfile；各环境实际使用的基础镜像由对应 `envs/<name>/docker-compose.yml` 里的 `build.args.BASE_IMAGE` 指定。

如果构建长时间停在 `apt-get update` 或 `apt-get install`，通常是服务器访问 Debian 源较慢。可以在 `.env` 中配置更近的 apt 镜像源：

```bash
APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian
```

基础镜像默认安装 `sudo git vim tmux ca-certificates`，Rust 额外安装 `pkg-config libssl-dev`。如果服务器构建时下载 `vim-runtime` 等 Debian 包很慢，优先配置上面的 `APT_MIRROR`，再重新执行 `make init ENV=<name>`。

Python 环境还会在构建时安装 `black flake8 pytest ipython`。如果访问 PyPI 较慢，可以在 `.env` 中配置 pip 镜像源：

```bash
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
```

设置后会写入镜像内的 `/etc/pip.conf`，构建阶段和进入容器后的 `pip install` 都会默认使用这个源。修改后重新执行 `make init ENV=python` 即可生效。

Rust 环境执行 `cargo add` 或 `cargo build` 时需要访问 crates.io。如果看到 `Could not resolve host: index.crates.io` 或 `Could not resolve host: static.crates.io`，通常是容器内 DNS 或网络无法访问 crates.io 索引或 crate 下载地址。可以在 `.env` 中配置 Cargo 镜像源：

```bash
CARGO_REGISTRY_MIRROR=sparse+https://mirrors.ustc.edu.cn/crates.io-index/
```

设置后会写入镜像内的 `$CARGO_HOME/config.toml`，让 crates.io 自动替换为镜像源。这里推荐 USTC 是因为它的 crates.io index 配置同时代理索引和 crate 包下载；TUNA 的 crates.io index 仍可能把包下载指向 `static.crates.io`。修改后重新执行 `make init ENV=rust`，再重新启动/进入 Rust 容器即可生效。

## 扩展新环境

以添加 **Java** 为例：

1. 创建 `envs/java/docker-compose.yml`，继承 `common.yml`
2. 在 `build.args` 中指定 `BASE_IMAGE=openjdk:21`
3. 按需增加 Java 自己的缓存卷或环境变量
4. 执行 `make init ENV=java` 和 `make up ENV=java`

参考现有 4 个环境的结构复制即可。
