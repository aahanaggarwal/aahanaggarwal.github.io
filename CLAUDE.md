# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Dev

```bash
./dev.sh          # build WASM modules, run optimizer, start dev server on :8000
python3 server.py # just the dev server (no-cache headers, port 8000)
```

Individual WASM builds:
```bash
wasm-pack build wasm/graph --target web --out-dir ../../graph/pkg
wasm-pack build wasm/sand --target web --out-dir ../../sand/pkg
wasm-pack build wasm/pong --target web --out-dir ../../pong/pkg
```

Optimizer (minifies HTML/CSS/JS into `/dist`):
```bash
cargo run --manifest-path tools/optimizer/Cargo.toml
```

## Content Management

- **Photos**: `python3 add_album.py path/to/folder` — uploads to Cloudinary, updates `pics/index.json`
- **Blog**: Create `.md` with frontmatter in `blog/posts/`, then `python3 update_blog.py` to regenerate `blog/posts.json`

## Architecture

**Vanilla JS SPA** — no frameworks, no bundler, no npm. Custom client-side router in `main.js`.

### Routing & Page Loading
`main.js` is the core: SPA router intercepts links, fetches page HTML, swaps `#content`, then calls page-specific initializers (graph loader, sand loader, etc.). Each tool page (`/graph/`, `/sand/`, `/pong/`) has its own `index.html` + `main.js` that gets loaded into the SPA shell.

### Rust/WASM Modules (`wasm/` workspace)
Three independent WASM modules, each built with `wasm-pack --target web`:
- **graph** — Marching squares algorithm for implicit equation plotting. Uses `meval` for expression parsing. Returns line segments and intersection points to JS for canvas rendering.
- **sand** — Cellular automaton physics engine. 128x128 grid, 15+ cell types with density-based settling, temperature system, and chemical reactions. JS handles canvas rendering and UI.
- **pong** — Game logic (ball physics, AI opponent, collision). JS handles rendering loop, input, and score display.

WASM output goes to `{module}/pkg/` directories (gitignored). Imported as ES modules.

### Build Pipeline
GitHub Actions (`deploy.yml`): install Rust → wasm-pack build all 3 modules → run optimizer → deploy `/dist` to GitHub Pages.

The optimizer (`tools/optimizer/`) uses `oxc_minifier` (JS), `lightningcss` (CSS), and `minify-html` (HTML). Copies non-minifiable files as-is.

### Visual Theme
Retro CRT aesthetic: green glow, Fira Code monospace, circuit board particle background on canvas, decrypt/scramble text animations, custom cursor tracking. The circuit background and HUD (coordinates, session timer) live in the root `index.html` shell.

## Deployment
- **Live host: Cloudflare Pages** (project `aahan-dev`) at `aahan.dev` — DNS is a proxied CNAME to `aahan-dev.pages.dev`; `www` 301s to apex
- GitHub Action on push to `master` (or manual dispatch): build wasm → optimizer → deploy `/dist` to **both** GH Pages (legacy backup, no traffic) and Cloudflare Pages (`cloudflare/wrangler-action`, secrets `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID`)
- GH Pages deploy can be removed once the Cloudflare setup has proven stable; also delete the `CNAME` file then
