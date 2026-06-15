#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

list_envs() {
    find envs -mindepth 2 -maxdepth 2 -name docker-compose.yml -exec dirname {} \; | sed 's#envs/##' | sort | sed 's/^/  - /'
}

ENV_NAME=${1:-}
if [ -z "$ENV_NAME" ]; then
    echo "Usage: init.sh <env-name>"
    echo "可用环境:"
    list_envs
    exit 1
fi

if [ ! -f "envs/$ENV_NAME/docker-compose.yml" ]; then
    echo "❌ 环境 '$ENV_NAME' 不存在，可用环境:"
    list_envs
    exit 1
fi

# 颜色
GREEN='\033[0;32m'
NC='\033[0m'

echo "➡️  初始化 $ENV_NAME..."

"$SCRIPT_DIR/ensure-env.sh"
COMPOSE=(docker compose --env-file .env -f "envs/$ENV_NAME/docker-compose.yml")

# 创建共享目录和对应 volumes
mkdir -p workspace shared/.ssh volumes

case $ENV_NAME in
    rust)
        mkdir -p volumes/rust-cargo volumes/rust-target
        ;;
    go)
        mkdir -p volumes/go-pkg
        ;;
    node)
        mkdir -p volumes/node-cache
        ;;
    python)
        mkdir -p volumes/python-pip
        ;;
    *)
        mkdir -p "volumes/$ENV_NAME-cache"
        ;;
esac

DEV_UID="$(sed -n 's/^DEV_UID=//p' .env | tail -n 1)"
DEV_GID="$(sed -n 's/^DEV_GID=//p' .env | tail -n 1)"
if [ "$(id -u)" = "0" ] || [ "$(id -g)" = "0" ]; then
    chown -R "${DEV_UID}:${DEV_GID}" workspace volumes
fi

# 构建镜像
"${COMPOSE[@]}" build

echo -e "${GREEN}✅ $ENV_NAME 初始化完成${NC}"
