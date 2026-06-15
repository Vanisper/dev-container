# dev-container

跨平台（Mac / Linux）统一 Docker 开发容器。通过 `ENV` 选择要启用的工具链，然后进入同一个 `dev` 容器工作。

## 项目定位

这个仓库只负责管理本机或服务器上的开发容器：构建工具链、启动/停止容器、进入容器、共享工作区和开发者配置。

它不负责某个具体项目的编译、测试、启动或发布。`workspace/` 下可以放多个项目，每个项目应该在自己的目录里保留自己的 `Makefile`、`package.json`、`Cargo.toml`、`go.mod`、`pyproject.toml` 等工程配置。

## 核心模型

`ENV` 表示“当前 dev 容器启用哪些工具链”，不是“进入哪个容器”。

```bash
make up ENV=go,python
make enter
```

上面的命令会构建并启动一个统一 `dev` 容器，里面同时有 Go、Python 和 pip。再次执行：

```bash
make up ENV=node
make enter
```

当前激活环境会替换成只包含 Node.js 的 dev 容器。

支持的工具链：

- `go`
- `node`
- `python`
- `rust`
- `all`

## 目录结构

```text
dev-container/
├── envs/
│   ├── Dockerfile.dev          # 统一 dev 镜像
│   ├── docker-compose.template.yml
│   ├── install-envs.sh         # 构建期工具链安装入口
│   ├── go/
│   │   ├── metadata.env
│   │   ├── install.sh
│   │   ├── profile.sh
│   │   ├── sources.env
│   │   └── compose.fragment.yml
│   ├── node/
│   ├── python/
│   └── rust/
├── scripts/
│   ├── init.sh
│   ├── up.sh
│   ├── enter.sh
│   ├── tmux.sh
│   └── lib/envs.sh
├── workspace/                  # 代码工作区（按项目分）
├── volumes/                    # Go/Node/Python/Rust 缓存
├── shared/                     # git、ssh、bash、vim、tmux 配置
├── .generated/                 # 运行时生成的 compose 文件，本地文件，不提交
├── .env
├── .active-env                 # 当前激活工具链，本地文件，不提交
├── Makefile
└── README.md
```

`envs/<name>` 是工具链模块目录，不再是独立容器目录。新增工具链时，优先在这里补充 `metadata.env`、`install.sh` 和 `profile.sh`。

## 快速开始

```bash
# 1. 构建并启动 Rust 工具链
make up ENV=rust

# 2. 进入统一 dev 容器
make enter

# 容器内
cargo new /workspace/hello-api --bin
cd /workspace/hello-api
cargo run
```

更完整的 Cargo 包管理示例见 [docs/rust-hello-api.md](docs/rust-hello-api.md)。

## 常用命令

| 命令 | 说明 |
|------|------|
| `make init ENV=go@auto,python` | 生成/修复 `.env` 和目录，构建组合镜像，不启动 |
| `make up ENV=go,python` | 构建并启动统一 dev 容器，激活 Go + Python |
| `make up ENV=all` | 构建并启动包含全部工具链的 dev 容器 |
| `make enter` | 进入当前已启动的统一 dev 容器 |
| `make tmux` | 进入/附着当前 dev 容器里的 tmux 会话 |
| `make down` | 停止当前 dev 容器，保留 `.active-env` |
| `make logs` | 查看当前 dev 容器日志 |
| `make clean` | 清理 dev 容器和本项目组合镜像，保留 `volumes/` |
| `make help` | 显示所有命令 |

`make up` 和 `make init` 必须显式传 `ENV`。`make enter ENV=go` 是旧用法，现在应写成：

```bash
make up ENV=go
make enter
```

`ENV` 支持 source profile：

```bash
make up ENV=go@auto,python,rust@custom
```

- 不写 `@source` 等同 `@default`，不启用工具链镜像源。
- `@auto` 使用模块内置镜像源。
- `@custom` 读取 `.env` 中该工具链的自定义源变量；至少需要配置该工具链声明的一个变量。
- source 分隔符使用 `@`；不要使用 `|`，它在 shell 里会被当作管道。

## 构建机制

统一镜像使用 `envs/Dockerfile.dev`：

- 基础镜像是 `debian:bookworm-slim`
- 创建非 root 的 `dev` 用户，并对齐宿主机 UID/GID
- 安装基础工具：`sudo`、`git`、`vim`、`tmux`、`curl`、`build-essential` 等
- 复制整个 `envs/` 到镜像内 `/opt/dev-container/envs`
- 根据 build arg `ENABLED_ENVS` 执行 `/opt/dev-container/envs/install-envs.sh`
- 按顺序安装 `go`、`node`、`python`、`rust`
- 汇总已启用工具链的 `profile.sh` 到 `/etc/profile.d/dev-tools.sh`
- 每次运行前由脚本把 `envs/docker-compose.template.yml` 和已启用模块的 `compose.fragment.yml` 合并到 `.generated/docker-compose.yml`

默认精确版本：

| 工具链 | 版本 | 安装方式 |
|--------|------|----------|
| Go | `1.26.4` | 从 `go.dev/dl` 下载官方 tarball |
| Node.js | `24.16.0` | 从 `nodejs.org/dist` 下载官方 tarball |
| Python | `3.12.13` | 从 `python.org` 下载源码编译，启用 `ensurepip` |
| Rust | `1.96.0` | 使用 `rustup` 安装指定 toolchain |

组合镜像按工具链命名，例如：

```text
dev-go-python:latest
dev-node:latest
dev-go-node-python-rust:latest
```

因此切回已构建过的组合可以复用 Docker 构建缓存和镜像。

## 共享目录、缓存和模块片段

统一 dev 容器固定挂载 workspace/shared，工具链缓存由对应模块贡献：

| 宿主机路径 | 容器路径 |
|------------|----------|
| `${WORKSPACE_HOST}` | `/workspace` |
| `${SHARED_HOST}/.gitconfig` | `/home/dev/.gitconfig:ro` |
| `${SHARED_HOST}/.ssh` | `/home/dev/.ssh:ro` |
| `${SHARED_HOST}/.bashrc` | `/home/dev/.bashrc:ro` |
| `${SHARED_HOST}/.vimrc` | `/home/dev/.vimrc:ro` |
| `${SHARED_HOST}/.tmux.conf` | `/home/dev/.tmux.conf:ro` |
| `volumes/go-home` | `/opt/dev-env/go/home` |
| `volumes/go-cache` | `/opt/dev-env/go/cache` |
| `volumes/node-cache` | `/opt/dev-env/node/cache` |
| `volumes/python-cache` | `/opt/dev-env/python/cache` |
| `volumes/rust-cargo` | `/opt/dev-env/rust/home/cargo/registry` |
| `volumes/rust-target` | `/opt/dev-env/rust/cache/target` |

这些缓存目录会统一挂载，但只有启用对应工具链时才会使用。

模块的 `compose.fragment.yml` 只允许贡献：

- `services.dev.volumes`
- `services.dev.environment`

`build`、`build.args`、`container_name`、`networks`、`command` 等关键配置由中心模板控制，模块不能覆盖。

## shared 配置

`shared/` 目录存放跨容器共用的开发者配置和身份凭证：

| 文件 | 作用 |
|------|------|
| `.gitconfig` | Git 身份（名字、邮箱） |
| `.ssh/` | SSH 密钥，用于 `git clone` 私有仓库 |
| `.bashrc` | Shell 别名、提示符风格 |
| `.vimrc` | Vim 编辑器配置 |
| `.tmux.conf` | Tmux 按键、鼠标、状态栏和历史配置 |

容器每次重建都是干净的。通过挂载 `shared/`，Git 身份、SSH、bash、vim、tmux 配置可以在不同工具链组合之间复用。

## 环境变量与 PATH

工具链模块通过 `profile.sh` 写入 `/etc/profile.d/dev-tools.sh`。这样普通 shell、登录 shell 和 tmux pane 都能拿到一致的 PATH。

启用对应工具链时会设置：

- Go：`GOROOT=/opt/dev-env/go/toolchain`、`GOPATH=/opt/dev-env/go/home`、`GOCACHE=/opt/dev-env/go/cache/build`
- Node.js：`NODE_HOME=/opt/dev-env/node/toolchain`、`NPM_CONFIG_CACHE=/opt/dev-env/node/cache/npm`
- Python：`PYTHON_HOME=/opt/dev-env/python/toolchain`、`PIP_CACHE_DIR=/opt/dev-env/python/cache/pip`、`PIP_CONFIG_FILE=/opt/dev-env/python/config/pip.conf`
- Rust：`CARGO_HOME=/opt/dev-env/rust/home/cargo`、`RUSTUP_HOME=/opt/dev-env/rust/home/rustup`、`CARGO_TARGET_DIR=/opt/dev-env/rust/cache/target`

## 用户身份

容器内统一使用 `dev` 用户运行，而非 root：

- `ensure-env.sh` 会把宿主机 UID/GID 写入 `.env`
- `Dockerfile.dev` 构建时用 `DEV_UID/DEV_GID` 创建容器内 `dev` 用户
- `dev` 拥有免密 sudo 权限，需要 root 时可以执行 `sudo apt install xxx`

Linux 文件权限认数字 UID/GID。让容器内用户对齐宿主机用户，可以减少 `workspace/` 挂载后文件权限混乱的问题。

如果在 Linux 服务器上直接用 root 运行，脚本会把容器内 `dev` 固定为 `1000:1000`，避免把开发用户变成 root。

## 镜像源

如果构建长时间停在 `apt-get update` 或 `apt-get install`，可以在 `.env` 中配置 apt 镜像源：

```bash
APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian
```

工具链镜像源默认不开启。需要使用内置源时，在 ENV 里写 `@auto`：

```bash
make up ENV=go@auto,python@auto,rust@auto
```

需要自定义源时，在 `.env` 里配置变量，并使用 `@custom`：

```bash
GO_DOWNLOAD_MIRROR=
NODE_DOWNLOAD_MIRROR=
PYTHON_DOWNLOAD_MIRROR=
PYTHON_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
RUSTUP_DIST_SERVER=
RUSTUP_UPDATE_ROOT=
CARGO_REGISTRY_MIRROR=sparse+https://mirrors.ustc.edu.cn/crates.io-index/
```

`@custom` 不要求把某个工具链的所有源变量都填满；例如 Rust 只配置 `CARGO_REGISTRY_MIRROR` 也可以使用 `make up ENV=rust@custom`。

修改这些配置后，需要重新执行对应组合的构建，例如：

```bash
make up ENV=python@custom
make up ENV=rust@custom
make up ENV=go@auto,python
```

## 扩展新工具链

以添加 `java` 为例：

1. 创建 `envs/java/metadata.env`
2. 创建 `envs/java/install.sh`，在基础镜像内安装 Java
3. 创建 `envs/java/profile.sh`，写入 `JAVA_HOME` 和 PATH
4. 创建 `envs/java/sources.env`，声明 `@auto` 和 `@custom` 可使用的源变量
5. 创建 `envs/java/compose.fragment.yml`，只贡献 volumes 和 environment
6. 在 `scripts/lib/envs.sh` 和 `envs/install-envs.sh` 的工具链列表中加入 `java`

新增工具链后即可使用：

```bash
make up ENV=java
make enter
```
