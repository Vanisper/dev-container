#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/envs.sh
source "$SCRIPT_DIR/lib/envs.sh"

ENV_NAME=${1:-}
require_explicit_env "$ENV_NAME"
NORMALIZED_ENVS="$(normalize_or_exit "$ENV_NAME")"

"$SCRIPT_DIR/ensure-env.sh"

DEV_IMAGE="$(dev_image_name "$NORMALIZED_ENVS")"
SOURCE_PROFILE="$(source_profile_for_envs "$NORMALIZED_ENVS")"

echo "➡️  启动 dev 环境：$NORMALIZED_ENVS"

prepare_runtime_dirs
prepare_compose "$NORMALIZED_ENVS" "$DEV_IMAGE"

COMPOSE_EVAL="$(compose_cmd "$NORMALIZED_ENVS" "$DEV_IMAGE" "$SOURCE_PROFILE")"
eval "$COMPOSE_EVAL up -d --build"
remove_legacy_containers
printf '%s\n' "$NORMALIZED_ENVS" > "$ACTIVE_ENV_FILE"

echo "✅ dev 环境已启动：$NORMALIZED_ENVS (${DEV_IMAGE})"
