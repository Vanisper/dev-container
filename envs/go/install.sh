#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$MODULE_DIR/metadata.env"

case "$(uname -m)" in
    x86_64) go_arch=amd64 ;;
    aarch64|arm64) go_arch=arm64 ;;
    *) echo "Unsupported Go architecture: $(uname -m)" >&2; exit 1 ;;
esac

archive="go${TOOLCHAIN_VERSION}.linux-${go_arch}.tar.gz"
download_base=${GO_DOWNLOAD_MIRROR:-https://go.dev/dl}
download_base=${download_base%/}
url="${download_base}/${archive}"

curl -fsSL "$url" -o "/tmp/$archive"
rm -rf "$TOOLCHAIN_PREFIX"
mkdir -p "$TOOLCHAIN_ROOT" "$TOOLCHAIN_HOME/bin" "$TOOLCHAIN_CACHE/build" "$TOOLCHAIN_CONFIG"
tar -C "$TOOLCHAIN_ROOT" -xzf "/tmp/$archive"
mv "$TOOLCHAIN_ROOT/go" "$TOOLCHAIN_PREFIX"
