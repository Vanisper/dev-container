#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

get_env_value() {
    local key=$1
    sed -n "s/^${key}=//p" .env 2>/dev/null | tail -n 1
}

HOST_UID=$(id -u)
HOST_GID=$(id -g)
DEFAULT_DEV_UID=$HOST_UID
DEFAULT_DEV_GID=$HOST_GID

if [ "$HOST_UID" = "0" ] || [ "$HOST_GID" = "0" ]; then
    DEFAULT_DEV_UID=1000
    DEFAULT_DEV_GID=1000
fi

if [ ! -f .env ]; then
    cat > .env <<EOF
# 代码工作区（按项目分，所有容器共享）
WORKSPACE_HOST=$PROJECT_ROOT/workspace

# 共享配置路径（git、ssh、bash、vim、tmux 等，所有容器共用）
SHARED_HOST=$PROJECT_ROOT/shared

# 容器内 dev 用户 ID（Mac 通常是 501，Linux 普通用户通常是 1000；root 宿主机也使用 1000）
DEV_UID=$DEFAULT_DEV_UID
DEV_GID=$DEFAULT_DEV_GID

# 容器名前缀（避免多人共用服务器冲突）
COMPOSE_PROJECT_NAME=dev
EOF
    echo "✅ 已生成 .env"
    if [ "$HOST_UID" = "0" ] || [ "$HOST_GID" = "0" ]; then
        echo "ℹ️  检测到宿主机为 root，容器内 dev 用户将使用 ${DEFAULT_DEV_UID}:${DEFAULT_DEV_GID}"
    fi
    exit 0
fi

workspace_host=$(get_env_value WORKSPACE_HOST)
shared_host=$(get_env_value SHARED_HOST)
compose_project_name=$(get_env_value COMPOSE_PROJECT_NAME)
apt_mirror=$(get_env_value APT_MIRROR)
pip_index_url=$(get_env_value PIP_INDEX_URL)
cargo_registry_mirror=$(get_env_value CARGO_REGISTRY_MIRROR)
dev_uid=$(get_env_value DEV_UID)
dev_gid=$(get_env_value DEV_GID)
legacy_uid=$(get_env_value UID)
legacy_gid=$(get_env_value GID)

target_uid=${dev_uid:-${legacy_uid:-$DEFAULT_DEV_UID}}
target_gid=${dev_gid:-${legacy_gid:-$DEFAULT_DEV_GID}}

if [ "$target_uid" = "0" ] || [ "$target_gid" = "0" ]; then
    target_uid=$DEFAULT_DEV_UID
    target_gid=$DEFAULT_DEV_GID
fi

needs_update=0
if grep -qE '^(UID|GID)=' .env; then
    needs_update=1
fi
if [ -z "$dev_uid" ] || [ -z "$dev_gid" ] || [ "$dev_uid" = "0" ] || [ "$dev_gid" = "0" ]; then
    needs_update=1
fi
if [ -z "$workspace_host" ] || [ -z "$shared_host" ] || [ -z "$compose_project_name" ]; then
    needs_update=1
fi
if ! grep -q '^APT_MIRROR=' .env; then
    needs_update=1
fi
if ! grep -q '^PIP_INDEX_URL=' .env; then
    needs_update=1
fi
if ! grep -q '^CARGO_REGISTRY_MIRROR=' .env; then
    needs_update=1
fi
if ! grep -q '容器内 dev 用户 ID' .env; then
    needs_update=1
fi

if [ "$needs_update" = "1" ]; then
    tmp_env="$(mktemp)"
    cat > "$tmp_env" <<EOF
# 代码工作区（按项目分，所有容器共享）
WORKSPACE_HOST=${workspace_host:-$PROJECT_ROOT/workspace}

# 共享配置路径（git、ssh、bash、vim、tmux 等，所有容器共用）
SHARED_HOST=${shared_host:-$PROJECT_ROOT/shared}

# 容器内 dev 用户 ID（Mac 通常是 501，Linux 普通用户通常是 1000；root 宿主机也使用 1000）
DEV_UID=$target_uid
DEV_GID=$target_gid

# 容器名前缀（避免多人共用服务器冲突）
COMPOSE_PROJECT_NAME=${compose_project_name:-dev}

# 可选：Debian apt 镜像源。服务器访问 deb.debian.org 很慢时可启用。
# 示例：APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/debian
APT_MIRROR=${apt_mirror:-}

# 可选：Python pip 镜像源。Python 环境构建和后续 pip install 会使用。
# 示例：PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
PIP_INDEX_URL=${pip_index_url:-}

# 可选：Rust crates.io 镜像源。Rust 环境构建时会写入 Cargo config。
# 示例：CARGO_REGISTRY_MIRROR=sparse+https://mirrors.ustc.edu.cn/crates.io-index/
CARGO_REGISTRY_MIRROR=${cargo_registry_mirror:-}
EOF
    mv "$tmp_env" .env
    echo "✅ 已更新 .env"
    if [ "$HOST_UID" = "0" ] || [ "$HOST_GID" = "0" ]; then
        echo "ℹ️  检测到宿主机为 root，容器内 dev 用户将使用 ${target_uid}:${target_gid}"
    fi
fi
