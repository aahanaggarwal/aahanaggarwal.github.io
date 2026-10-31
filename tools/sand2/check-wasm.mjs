import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {loadEngine} from '../../sand2/engine.js';

// Use the production browser adapter against the local packaged module.
const originalFetch = globalThis.fetch;
globalThis.fetch = async url => url.protocol === 'file:' ? new Response(await readFile(fileURLToPath(url))) : originalFetch(url);
const api = await loadEngine();
const reference = (await readFile(process.argv[2], 'utf8')).trim().split('\n');
assert.ok(reference.length >= 2200);
for (const line of reference) {
  const [block, noise, expected] = line.split(',').map(Number);
  assert.equal(api.physics_probe(block, noise) >>> 0, expected, `Lean/Wasm mismatch: ${line}`);
}
api.world_new(256, 160);
for (let x = 10; x < 250; x += 12) for (let y = 10; y < 145; y += 12) api.world_paint(x, y, 5, (x + y) % 3 ? 1 : 2);
const before = api.world_render();
for (let i = 0; i < 20; i++) api.world_tick();
const start = performance.now();
for (let i = 0; i < 120; i++) api.world_tick();
const msPerTick = (performance.now() - start) / 120;
assert.equal(api.world_render(), before, 'Wasm simulation lost inert particles');
api.world_clear();
assert.equal(api.world_render(), 0);
api.world_free();
console.log(`Lean/browser Wasm differential check: ${reference.length} vectors agree.\n19,440-particle benchmark: ${msPerTick.toFixed(2)} ms/tick; particles conserved.`);
