# Sand Game 2 — AI-authored implementation notes

Sand Game 2 lives at `/sand2/`; the original `/sand/` is retained.

`wasm/sand2/lean/Sand2.lean` is the sole source of particle movement and chemical
reactions. Lungo 1.117.0 compiles its Lean 4.34.1 IR into Rust at Cargo build time.
`wasm/sand2/src/lib.rs` stores the grid, schedules alternating disjoint 2×2
Margolus blocks, handles painting, and produces pixels. It calls the generated
`step_block` for every active block; it has no duplicate handwritten physics.
The JavaScript files handle input, scene geometry, rendering and the UI.

## Build and preview

Prerequisites: Rust with the `wasm32-wasip1` target, elan with
`leanprover/lean4:v4.34.1`, Node and Python 3. Dependencies are pinned in Cargo.lock
and lake-manifest.json. Local optional toolchains/caches live in ignored `.tools/`.

```sh
./dev.sh --sand2-only --no-serve  # verify proofs, test, generate, compare, package
./dev.sh --sand2-only            # same checks, serve source at 127.0.0.1:8012
./dev.sh                        # rebuild all games and optimized production site
```

The narrow preview uses the other games' existing local `pkg/` outputs. Run the
full development script first on a fresh checkout. The default script retains
the existing site's build pipeline.

## Browser Wasm and trust

Lungo's runtime supports `wasm32-wasip1`; it does not currently compile for
`wasm32-unknown-unknown`. The packaged module uses a small C ABI instead of
wasm-bindgen. `sand2/engine.js` supplies a bounded WASI host with empty environment,
no preopened directories, and console-only output. File access returns EBADF.
Unexpected new imports fail explicitly. The game runs entirely in the browser.

The four Lean proofs establish that pair movement preserves its particles,
stationary materials cannot move or be displaced by gravity, and blocked pairs
are unchanged. Chemistry intentionally changes particle types and counts. These
are scoped proofs, not a claim that the entire game or compiler is verified.
Lungo's translator/runtime, Rust, and the browser remain trusted components.

The independent Lean oracle computes 2,200 reference vectors. Native generated
Rust and the packaged browser module must agree on every vector. Integration
tests also cover conservation, material validity over all 14^4 input blocks,
reactions, determinism, static materials, joined-corner walls, clipping, erasure and boundary walls.

## Publishing through the existing site pipeline

The deployment workflow already builds the original four games and runs the
optimizer. Sand 2 commits its compiled 300 KB Wasm and a reviewable snapshot of
Lungo's generated Rust under `tools/sand2/generated/`; it needs no Lean install
on the existing hosting runner. `sand2/build.json` records SHA-256 digests of the
physics sources, build tools and generated artifacts. The optimizer runs
`verify-build.py` before packaging and refuses stale artifacts. Physics changes
must run the full Lean→Rust→Wasm build above before committing. Frontend-only
changes do not require rebuilding physics.

The existing GitHub Actions workflow publishes the optimized static files to
Cloudflare Pages. No workflow permission or new hosting service is required.
