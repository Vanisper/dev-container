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
    echo "Usage: enter.sh <env-name>"
    echo "可用环境:"
    list_envs
    exit 1
fi

if [ ! -f "envs/$ENV_NAME/docker-compose.yml" ]; then
    echo "❌ 环境 '$ENV_NAME' 不存在，可用环境:"
    list_envs
    exit 1
fi

"$SCRIPT_DIR/ensure-env.sh"
ENV_PROJECT_NAME="$(sed -n 's/^COMPOSE_PROJECT_NAME=//p' .env | tail -n 1)"
COMPOSE=(env "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-${ENV_PROJECT_NAME:-dev}}" docker compose --env-file .env)
COMPOSE+=(-f "envs/$ENV_NAME/docker-compose.yml")

# 检查容器是否运行
SERVICE="${ENV_NAME}-dev"
if ! "${COMPOSE[@]}" ps --services --filter status=running | grep -qx "$SERVICE"; then
    echo "➡️  容器未运行，先启动..."
    "${COMPOSE[@]}" up -d
fi

"${COMPOSE[@]}" exec -it "$SERVICE" bash
