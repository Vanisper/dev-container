#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/envs.sh
source "$SCRIPT_DIR/lib/envs.sh"

if [ -n "${1:-}" ]; then
    echo "❌ make tmux 不再接收 ENV 参数。请先执行：make up ENV=${1}" >&2
    echo "然后执行：make tmux" >&2
    exit 1
fi

"$SCRIPT_DIR/ensure-env.sh"
ACTIVE_ENVS="$(load_active_env)"
DEV_IMAGE="$(dev_image_name "$ACTIVE_ENVS")"
SESSION_NAME=${TMUX_SESSION:-dev}
prepare_compose "$ACTIVE_ENVS" "$DEV_IMAGE"
COMPOSE_EVAL="$(compose_cmd "$ACTIVE_ENVS" "$DEV_IMAGE")"

if ! eval "$COMPOSE_EVAL ps --services --filter status=running" | grep -qx "dev"; then
    echo "❌ dev 容器未运行，请先执行：make up ENV=$ACTIVE_ENVS" >&2
    exit 1
fi

eval "$COMPOSE_EVAL exec -it dev tmux new-session -A -s \"\$SESSION_NAME\""
