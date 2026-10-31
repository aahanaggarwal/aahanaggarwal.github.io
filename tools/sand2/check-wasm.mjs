import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {loadEngine} from '../../sand2/engine.js';

const originalFetch = globalThis.fetch;
globalThis.fetch = async url => url.protocol === 'file:' ? new Response(await readFile(fileURLToPath(url))) : originalFetch(url);
const api = await loadEngine();
const decoder = new TextDecoder();
const text = pointer => decoder.decode(new Uint8Array(api.memory.buffer, pointer, api.world_text_length()));
const reference = (await readFile(process.argv[2], 'utf8')).trim().split('\n');
assert.equal(reference.length, 25);
api.world_new(24, 20);
for (const line of reference) {
  const [scene, ticks, ...expected] = line.split(';');
  assert.equal(text(api.world_oracle(Number(scene), Number(ticks))), expected.join(';'), `Lean/Wasm mismatch: ${line}`);
}
const catalogue = JSON.parse(text(api.world_catalogue()));
assert.ok(catalogue.length >= 20);
for (const {id} of catalogue) {
  api.world_scene(0); api.world_paint(12, 6, 2, id);
  const before = text(api.world_audit());
  for (let i = 0; i < 3; i++) api.world_tick();
  assert.equal(text(api.world_audit()), before, `Element/energy drift for material ${id}`);
}
api.world_scene(3);
const checkpoint = api.world_digest();
api.world_checkpoint(); api.world_paint(12, 4, 3, 9); api.world_tick();
assert.notEqual(api.world_digest(), checkpoint);
api.world_undo(); assert.equal(api.world_digest(), checkpoint);
for (const view of [0,1,2]) api.world_render(view);
assert.equal(api.world_digest(), checkpoint, 'Rendering mutated simulation');
api.world_free();
api.world_new(96, 64); api.world_scene(1);
const before = text(api.world_audit());
const start = performance.now();
for (let i = 0; i < 10; i++) api.world_tick();
const msPerTick = (performance.now() - start) / 10;
assert.equal(text(api.world_audit()), before, 'Full-size conservation failed');
api.world_render(0);
api.world_clear(); assert.equal(api.world_render(0), 0);
api.world_free();
console.log(`Lean/native/browser differential check: ${reference.length} complete-world states agree.`);
console.log(`All ${catalogue.length} palette materials conserve every tracked element and energy. Exact undo and read-only rendering verified.`);
console.log(`96x64 dam-break benchmark: ${msPerTick.toFixed(2)} ms/tick.`);
