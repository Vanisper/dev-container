#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$MODULE_DIR/metadata.env"

major_minor="${TOOLCHAIN_VERSION%.*}"
archive="Python-${TOOLCHAIN_VERSION}.tgz"
download_base=${PYTHON_DOWNLOAD_MIRROR:-https://www.python.org/ftp/python}
download_base=${download_base%/}
url="${download_base}/${TOOLCHAIN_VERSION}/${archive}"
src_dir="/tmp/Python-${TOOLCHAIN_VERSION}"
prefix="$TOOLCHAIN_PREFIX"

mkdir -p "$TOOLCHAIN_HOME" "$TOOLCHAIN_CACHE/pip" "$TOOLCHAIN_CONFIG"
touch "$TOOLCHAIN_CONFIG/pip.conf"
if [ -n "${PYTHON_PIP_INDEX_URL:-}" ]; then
    printf '%s\n' '[global]' "index-url = $PYTHON_PIP_INDEX_URL" > "$TOOLCHAIN_CONFIG/pip.conf"
    export PIP_CONFIG_FILE="$TOOLCHAIN_CONFIG/pip.conf"
fi

curl -fsSL "$url" -o "/tmp/$archive"
tar -C /tmp -xzf "/tmp/$archive"
cd "$src_dir"
./configure --prefix="$prefix" --with-ensurepip=install
make -j"$(nproc)"
make install

ln -sf python3 "$prefix/bin/python"

"$prefix/bin/python3" -m pip install --no-cache-dir --upgrade pip
if [ -x "$prefix/bin/pip3" ]; then
    ln -sf pip3 "$prefix/bin/pip"
elif [ -x "$prefix/bin/pip${major_minor}" ]; then
    ln -sf "pip${major_minor}" "$prefix/bin/pip"
fi

if [ -n "${PYTHON_DEFAULT_PACKAGES:-}" ]; then
    "$prefix/bin/python3" -m pip install --no-cache-dir $PYTHON_DEFAULT_PACKAGES
fi
