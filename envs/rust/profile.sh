export CARGO_HOME=${DEV_ENV_HOME:-/opt/dev-env}/rust/home/cargo
export RUSTUP_HOME=${DEV_ENV_HOME:-/opt/dev-env}/rust/home/rustup
export CARGO_TARGET_DIR=${DEV_ENV_HOME:-/opt/dev-env}/rust/cache/target
dev_path_prepend "$CARGO_HOME/bin"
