export NODE_HOME=${DEV_ENV_HOME:-/opt/dev-env}/node/toolchain
export NPM_CONFIG_CACHE=${DEV_ENV_HOME:-/opt/dev-env}/node/cache/npm
dev_path_prepend "$NODE_HOME/bin"
