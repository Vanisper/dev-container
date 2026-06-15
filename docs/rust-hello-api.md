# Rust hello-api：测试 Cargo 包管理

这个示例把 README 快速开始里的 `hello-api` 扩展成一个小型 HTTP API，用来观察 Cargo 的依赖管理、feature 解析、dev-dependencies、`Cargo.lock` 和缓存复用。

## 创建项目

先从宿主机进入 Rust 容器，然后创建示例项目：

```bash
make enter ENV=rust
cd /workspace
cargo new hello-api --bin
cd hello-api
```

## 添加依赖

如果 `cargo add` 或 `cargo metadata` 报错 `Could not resolve host: index.crates.io` / `Could not resolve host: static.crates.io`，先在仓库根目录的 `.env` 里加上 Cargo 镜像源：

```bash
CARGO_REGISTRY_MIRROR=sparse+https://mirrors.ustc.edu.cn/crates.io-index/
```

然后在宿主机重新初始化并进入 Rust 环境：

```bash
make init ENV=rust
make up ENV=rust
make enter ENV=rust
```

通过 `cargo add` 添加运行时依赖和测试依赖：

```bash
cargo add axum@0.8 --features macros,json
cargo add tokio@1 --features macros,rt-multi-thread,signal
cargo add serde@1 --features derive
cargo add --dev serde_json@1
cargo add --dev pretty_assertions@1
```

这一步会修改 `Cargo.toml`，并生成或更新 `Cargo.lock`。

在 `Cargo.toml` 里补充项目自己的 feature：

```toml
[features]
default = ["json"]
json = []
```

## 编写 API

把 `src/lib.rs` 写成：

```rust
use axum::{routing::get, Router};

pub fn app() -> Router {
    let router = Router::new()
        .route("/", get(root))
        .route("/health", get(health));

    #[cfg(feature = "json")]
    let router = router.route("/api/hello", get(hello_json));

    router
}

async fn root() -> &'static str {
    "hello-api\n"
}

async fn health() -> &'static str {
    "ok\n"
}

#[cfg(feature = "json")]
#[derive(serde::Serialize)]
struct HelloResponse {
    message: &'static str,
    package: &'static str,
}

#[cfg(feature = "json")]
async fn hello_json() -> axum::Json<HelloResponse> {
    axum::Json(HelloResponse {
        message: "hello from axum",
        package: env!("CARGO_PKG_NAME"),
    })
}

#[cfg(test)]
mod tests {
    use pretty_assertions::assert_eq;
    #[cfg(feature = "json")]
    use super::HelloResponse;

    #[test]
    fn exposes_package_name() {
        assert_eq!(env!("CARGO_PKG_NAME"), "hello-api");
    }

    #[cfg(feature = "json")]
    #[test]
    fn serializes_json_response() {
        let value = serde_json::to_value(HelloResponse {
            message: "hello from axum",
            package: env!("CARGO_PKG_NAME"),
        })
        .unwrap();

        assert_eq!(
            value,
            serde_json::json!({
                "message": "hello from axum",
                "package": "hello-api"
            })
        );
    }
}
```

把 `src/main.rs` 写成：

```rust
use std::net::SocketAddr;

#[tokio::main]
async fn main() {
    let addr: SocketAddr = "0.0.0.0:3000".parse().unwrap();
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("hello-api listening on http://{addr}");
    axum::serve(listener, hello_api::app()).await.unwrap();
}
```

## 运行和测试

```bash
RUST_LOG=info cargo run &
server_pid=$!

curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/api/hello

kill "$server_pid"
cargo test
```

## 观察 Cargo 行为

```bash
# 查看直接依赖和间接依赖
cargo tree

# 查看 feature 如何被依赖启用
cargo tree -e features

# 关闭默认 feature，验证 /api/hello 对应代码不会编译进来
cargo test --no-default-features

# 只更新某个包，Cargo.lock 会记录解析后的精确版本
cargo update -p serde_json

# 查看本项目元数据，适合排查 workspace、target、feature
cargo metadata --format-version 1
```

这里可以重点看两个文件：

- `Cargo.toml`：声明直接依赖、dev 依赖和项目 feature
- `Cargo.lock`：记录 Cargo 实际解析出来的精确版本，应用项目建议提交

本仓库把 Rust registry 缓存挂载到 `volumes/rust-cargo/`，把构建产物放到 `/workspace/.cache/rust-target`。因此删除并重建 `workspace/hello-api` 后，已经下载过的 crates 和编译缓存仍然可以复用。
