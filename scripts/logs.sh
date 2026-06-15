#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/envs.sh
source "$SCRIPT_DIR/lib/envs.sh"

"$SCRIPT_DIR/ensure-env.sh"
ACTIVE_ENVS="$(load_active_env)"
DEV_IMAGE="$(dev_image_name "$ACTIVE_ENVS")"
prepare_compose "$ACTIVE_ENVS" "$DEV_IMAGE"
COMPOSE_EVAL="$(compose_cmd "$ACTIVE_ENVS" "$DEV_IMAGE")"

eval "$COMPOSE_EVAL logs -f dev"
