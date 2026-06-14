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
│   └── enter.sh           # 进入指定环境
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
│   └── .vimrc
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
cargo new /workspace/hello-api
cd /workspace/hello-api
cargo run
```

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

**为什么要共享？**

容器每次重建都是干净的。没有这些配置，你进容器后：

- `git commit` 报错 "Please tell me who you are"
- `git clone git@github.com:...` 权限拒绝
- vim 没有语法高亮，bash 没有 `ll` 别名

通过 `envs/common.yml`，所有容器启动时自动把 `shared/` 中的配置挂载到 `/home/dev/`，**一次配置，所有环境生效**。

**使用方式：**

1. 修改 `shared/.gitconfig` 填上你的真实姓名和邮箱
2. 把你的 SSH 私钥复制到 `shared/.ssh/`（已加入 `.gitignore`，不会提交）
3. 调整 `shared/.bashrc`、`.vimrc` 符合你的习惯
4. 所有容器自动继承

### 4. 用户身份设计

容器内统一使用 `dev` 用户运行，而非 root：

- **UID/GID 对齐**：`init.sh` 会把宿主机当前用户的 `id -u` 和 `id -g` 写入 `.env`，`Dockerfile.base` 构建时用这组数字创建容器内的 `dev` 用户
- **sudo 可用**：`dev` 拥有免密 sudo 权限，需要 root 时可以直接执行 `sudo apt install xxx`
- **安全习惯**：日常开发不用 root，减少误操作风险；需要系统级权限时再显式使用 `sudo`

**为什么要设置 UID/GID？**

Linux 文件权限认的是数字 UID/GID，而不是用户名。`workspace/` 是宿主机目录挂载到容器里的，如果容器内用户和宿主机用户的 UID/GID 不一致，容器创建的文件在宿主机上可能变成“别的用户”的文件，导致编辑器无法保存、`rm`/`git clean` 权限不足，或者 `node_modules`、`target`、缓存目录权限混乱。

Mac 用户常见 UID/GID 是 `501/20`，Linux 用户常见是 `1000/1000`。Docker Desktop for Mac 会做一层文件共享转换，所以问题有时不明显；但在 Colima、远程 Linux、CI 或直接使用 Linux Docker 时，UID/GID 不一致会更直接地暴露出来。因此初始化时自动写入当前宿主机的 UID/GID，可以让容器内 `dev` 用户尽量像“宿主机当前用户”一样写文件。

**sudo 免密是什么意思？**

`Dockerfile.base` 里给 `dev` 用户配置了 `NOPASSWD` sudo。也就是说，容器里执行 `sudo apt install curl` 这类命令时不需要输入密码。这样既能保持日常开发不使用 root，又能在需要临时安装系统包时方便提权。这个设置只面向本地开发容器，不建议照搬到生产服务器。

## 跨平台说明

### Mac

- `init.sh` 自动检测 UID（通常为 `501`）写入 `.env`
- `Dockerfile.base` 创建同 UID 的 `dev` 用户，避免 Docker Desktop 挂载后的文件权限问题
- 如果使用 Colima：`colima start --cpu 4 --memory 8`

### Linux 服务器

- UID 通常为 `1000`，脚本自动适配
- 无需额外配置

## 扩展新环境

以添加 **Java** 为例：

1. 创建 `envs/java/docker-compose.yml`，继承 `common.yml`
2. 在 `build.args` 中指定 `BASE_IMAGE=openjdk:21`
3. 按需增加 Java 自己的缓存卷或环境变量
4. 执行 `make init ENV=java` 和 `make up ENV=java`

参考现有 4 个环境的结构复制即可。
