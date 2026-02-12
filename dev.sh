#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

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

echo "Running Optimizer..."
cargo run --manifest-path "$ROOT/tools/optimizer/Cargo.toml"

echo "Starting Server..."
PID=$(lsof -ti:8000 || true)
if [ -n "$PID" ]; then
  echo "Killing process on port 8000 (PID: $PID)..."
  kill -9 $PID || true
fi

cd "$ROOT/dist"
python3 "$ROOT/server.py"
