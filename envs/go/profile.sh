export GOROOT=${DEV_ENV_HOME:-/opt/dev-env}/go/toolchain
export GOPATH=${DEV_ENV_HOME:-/opt/dev-env}/go/home
export GOCACHE=${DEV_ENV_HOME:-/opt/dev-env}/go/cache/build
dev_path_prepend "$GOROOT/bin"
dev_path_prepend "$GOPATH/bin"
