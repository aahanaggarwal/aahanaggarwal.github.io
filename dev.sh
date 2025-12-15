#!/bin/bash
set -e

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
cd wasm
wasm-pack build graph --target web --out-dir ../graph/pkg
wasm-pack build sand --target web --out-dir ../sand/pkg
cd ..


echo "Starting Server..."
# Kill process on port 8000 if it exists
# Kill process on port 8000 if it exists
PID=$(lsof -ti:8000 || true)
if [ -n "$PID" ]; then
  echo "Killing process on port 8000 (PID: $PID)..."
  kill -9 $PID || true
fi

python3 server.py
