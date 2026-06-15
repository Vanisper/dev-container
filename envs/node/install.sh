#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$MODULE_DIR/metadata.env"

case "$(uname -m)" in
    x86_64) node_arch=x64 ;;
    aarch64|arm64) node_arch=arm64 ;;
    *) echo "Unsupported Node.js architecture: $(uname -m)" >&2; exit 1 ;;
esac

dist="node-v${TOOLCHAIN_VERSION}-linux-${node_arch}"
archive="${dist}.tar.xz"
download_base=${NODE_DOWNLOAD_MIRROR:-https://nodejs.org/dist}
download_base=${download_base%/}
url="${download_base}/v${TOOLCHAIN_VERSION}/${archive}"

curl -fsSL "$url" -o "/tmp/$archive"
rm -rf "$TOOLCHAIN_PREFIX"
mkdir -p "$TOOLCHAIN_ROOT" "$TOOLCHAIN_HOME" "$TOOLCHAIN_CACHE/npm" "$TOOLCHAIN_CONFIG"
tar -C "$TOOLCHAIN_ROOT" -xJf "/tmp/$archive"
mv "$TOOLCHAIN_ROOT/$dist" "$TOOLCHAIN_PREFIX"
