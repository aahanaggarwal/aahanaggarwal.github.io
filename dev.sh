#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Sand Game 2 has its own pinned Lean -> Rust -> WASI pipeline.
if [ -d "$ROOT/.tools/cargo/bin" ]; then
    export CARGO_HOME="$ROOT/.tools/cargo" RUSTUP_HOME="$ROOT/.tools/rust"
    export PATH="$CARGO_HOME/bin:$ROOT/.tools/bin:$PATH"
fi
if [ -x "$ROOT/.tools/cc" ] && ! command -v cc >/dev/null; then
    export CC="$ROOT/.tools/cc" CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$ROOT/.tools/cc"
fi
if [ "${1:-}" = "--sand2-profile" ]; then
    exec "$ROOT/tools/sand2/profile.sh" "${@:2}"
fi
if [ "${1:-}" = "--sand2-only" ]; then
    "$ROOT/tools/sand2/build.sh"
    if [ "${2:-}" = "--no-serve" ]; then exit 0; fi
    exec python3 -m http.server "${SAND2_PORT:-8012}" --bind 127.0.0.1 --directory "$ROOT"
fi
"$ROOT/tools/sand2/build.sh"

# Check for Cargo/Rust
if ! command -v cargo &> /dev/null; then
    echo "Cargo (Rust) not found. Installing via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Check for wasm-pack
if ! command -v wasm-pack &> /dev/null; then
    echo "wasm-pack not found. Installing..."
    curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
fi

echo "Building Wasm..."
wasm-pack build "$ROOT/wasm/graph" --target web --out-dir "$ROOT/graph/pkg"
wasm-pack build "$ROOT/wasm/sand" --target web --out-dir "$ROOT/sand/pkg"
wasm-pack build "$ROOT/wasm/pong" --target web --out-dir "$ROOT/pong/pkg"
wasm-pack build "$ROOT/wasm/tron" --target web --out-dir "$ROOT/tron/pkg"

echo "Running Optimizer..."
cd "$ROOT"
cargo run --manifest-path "$ROOT/tools/optimizer/Cargo.toml"

echo "Starting Server..."
PID=$(lsof -ti:8000 || true)
if [ -n "$PID" ]; then
  echo "Killing process on port 8000 (PID: $PID)..."
  kill -9 $PID || true
fi

cd "$ROOT/dist"
python3 "$ROOT/server.py"
