export PYTHON_HOME=${DEV_ENV_HOME:-/opt/dev-env}/python/toolchain
export PIP_CACHE_DIR=${DEV_ENV_HOME:-/opt/dev-env}/python/cache/pip
if [ -f "${DEV_ENV_HOME:-/opt/dev-env}/python/config/pip.conf" ]; then
    export PIP_CONFIG_FILE=${DEV_ENV_HOME:-/opt/dev-env}/python/config/pip.conf
fi
dev_path_prepend "$PYTHON_HOME/bin"
dev_path_prepend /home/dev/.local/bin
