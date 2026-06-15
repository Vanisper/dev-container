#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$MODULE_DIR/metadata.env"

export CARGO_HOME="$TOOLCHAIN_HOME/cargo"
export RUSTUP_HOME="$TOOLCHAIN_HOME/rustup"
export PATH="$CARGO_HOME/bin:$PATH"

mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" "$TOOLCHAIN_CACHE/target" "$TOOLCHAIN_CONFIG"

case "$(uname -m)" in
    x86_64) rustup_arch=x86_64-unknown-linux-gnu ;;
    aarch64|arm64) rustup_arch=aarch64-unknown-linux-gnu ;;
    *) echo "Unsupported Rust architecture: $(uname -m)" >&2; exit 1 ;;
esac

rustup_update_root=${RUSTUP_UPDATE_ROOT:-https://static.rust-lang.org/rustup}
rustup_update_root=${rustup_update_root%/}
curl --proto '=https' --tlsv1.2 -fsSL \
    "$rustup_update_root/dist/$rustup_arch/rustup-init" \
    -o /tmp/rustup-init
chmod +x /tmp/rustup-init
/tmp/rustup-init -y --no-modify-path --profile default --default-toolchain "$TOOLCHAIN_VERSION"

if [ -n "${CARGO_REGISTRY_MIRROR:-}" ]; then
    mirror_url="$CARGO_REGISTRY_MIRROR"
    case "$mirror_url" in sparse+*) ;; *) mirror_url="sparse+$mirror_url" ;; esac
    case "$mirror_url" in */) ;; *) mirror_url="$mirror_url/" ;; esac
    printf '%s\n' \
        '[source.crates-io]' \
        'replace-with = "mirror"' \
        '' \
        '[source.mirror]' \
        "registry = \"$mirror_url\"" \
        '' \
        '[registries.mirror]' \
        "index = \"$mirror_url\"" \
        > "$CARGO_HOME/config.toml"
fi
