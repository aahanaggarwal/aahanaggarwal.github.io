#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Prefer the checkout's optional toolchain over global installs.
if [[ -d "$ROOT/.tools/cargo/bin" ]]; then
  export CARGO_HOME="$ROOT/.tools/cargo" RUSTUP_HOME="$ROOT/.tools/rust"
  export PATH="$CARGO_HOME/bin:$ROOT/.tools/bin:$PATH"
fi
export LUNGO_CACHE_DIR="$ROOT/.tools/lungo-cache"
if [[ -x "$ROOT/.tools/cc" ]] && ! command -v cc >/dev/null; then
  export CC="$ROOT/.tools/cc" CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$ROOT/.tools/cc"
fi
command -v cargo >/dev/null || { echo 'Rust is required. Install rustup first.' >&2; exit 1; }
command -v lake >/dev/null || { echo 'Lean/elan is required. Install elan first.' >&2; exit 1; }
command -v node >/dev/null
mkdir -p "$ROOT/.tools/sand2"
cd "$ROOT/wasm/sand2/lean"
lake build
lake env lean ProofReport.lean
lake env lean --run Oracle.lean > "$ROOT/.tools/sand2/oracle.csv"
cd ..
cargo test --release --locked --jobs "${SAND2_BUILD_JOBS:-2}"
cargo run --release --locked --example oracle --jobs "${SAND2_BUILD_JOBS:-2}" < "$ROOT/.tools/sand2/oracle.csv"
cargo build --release --locked --target wasm32-wasip1 --jobs "${SAND2_BUILD_JOBS:-2}" --message-format=json > "$ROOT/.tools/sand2/cargo-build.jsonl"
cd "$ROOT"
python3 tools/sand2/package.py
node tools/sand2/check-wasm.mjs "$ROOT/.tools/sand2/oracle.csv"
python3 tools/sand2/verify-build.py
