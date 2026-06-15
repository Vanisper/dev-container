#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/envs.sh
source "$SCRIPT_DIR/lib/envs.sh"

"$SCRIPT_DIR/ensure-env.sh"

ACTIVE_ENVS=""
if [ -f "$ACTIVE_ENV_FILE" ]; then
    ACTIVE_ENVS="$(normalize_or_exit "$(tr -d '[:space:]' < "$ACTIVE_ENV_FILE")")"
fi
DEV_IMAGE="${ACTIVE_ENVS:+$(dev_image_name "$ACTIVE_ENVS")}"
prepare_runtime_dirs
prepare_compose "$ACTIVE_ENVS" "$DEV_IMAGE"
COMPOSE_EVAL="$(compose_cmd "$ACTIVE_ENVS" "$DEV_IMAGE")"

eval "$COMPOSE_EVAL down"
echo "✅ dev 环境已停止"
