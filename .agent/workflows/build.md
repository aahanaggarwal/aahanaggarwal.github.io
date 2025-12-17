---
description: How to build the project
---


To build the project and start the development server, you **MUST** use the main development script. This script handles all necessary steps, including checking dependencies, building all Wasm modules, and starting the local server.

```bash
./dev.sh
```

// turbo-all

> [!IMPORTANT]
> Do NOT run `wasm-pack` manually. Always use `./dev.sh` to ensure all modules (graph, sand, pong) are built correctly and the environment is consistent.

This script will:
1.  Check for `cargo` and `wasm-pack`.
2.  Build all Wasm modules (`graph`, `sand`, `pong`).
3.  Start the local server.
