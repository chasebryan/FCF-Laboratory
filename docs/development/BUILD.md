# Development Build

## macOS reference application

Requirements:

- Apple Silicon Mac (`arm64`)
- macOS 15 or newer
- Xcode command-line development tools with Swift 6 support

Build from the repository root:

```sh
swift build --package-path apps/macos
```

Run the development executable:

```sh
swift run --package-path apps/macos FCF-Laboratory
```

The package contains a compile-time architecture guard and intentionally refuses an Intel macOS build.

## Portable Rust core

Requirements:

- Rust 1.85 or newer

Run the workspace tests:

```sh
cargo test --manifest-path packages/rust/Cargo.toml --workspace
```

Run formatting and lints:

```sh
cargo fmt --manifest-path packages/rust/Cargo.toml --all --check
cargo clippy --manifest-path packages/rust/Cargo.toml --workspace --all-targets --all-features -- -D warnings
```

## Runtime state

Do not store downloaded engines, credentials, caches, or user runtime state in the repository checkout. Platform-specific runtime locations will be introduced behind a dedicated platform storage abstraction.
