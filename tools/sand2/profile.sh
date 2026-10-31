#!/usr/bin/env bash
# Diagnostic build only: never packages or publishes unchecked artifacts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -d "$ROOT/.tools/cargo/bin" ]]; then
  export CARGO_HOME="$ROOT/.tools/cargo" RUSTUP_HOME="$ROOT/.tools/rust"
  export PATH="$CARGO_HOME/bin:$ROOT/.tools/bin:$PATH"
fi
export LUNGO_CACHE_DIR="$ROOT/.tools/lungo-cache"
if [[ -x "$ROOT/.tools/cc" ]] && ! command -v cc >/dev/null; then
  export CC="$ROOT/.tools/cc" CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$ROOT/.tools/cc"
fi
cd "$ROOT/wasm/sand2"
cargo build --release --locked --target wasm32-wasip1 --jobs "${SAND2_BUILD_JOBS:-2}"
export SAND2_BENCH_WASM="$ROOT/wasm/sand2/target/wasm32-wasip1/release/sand2.wasm"
node "$ROOT/tools/sand2/benchmark.mjs" "$@"
