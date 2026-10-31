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
assert.equal(reference.length, 66);
api.world_new(24, 20);
// Exercise repeated lifecycles, including large Nat literals in the fluid
// kernels. Memory should be reused after warmup, not grow with tick count.
for (let i = 0; i < 5; i++) api.world_tick();
const warmMemory = api.memory.buffer.byteLength;
for (let cycle = 0; cycle < 3; cycle++) {
  api.world_new(24, 20);
  for (let tick = 0; tick < 20; tick++) api.world_tick();
  api.world_free();
}
assert.ok(api.memory.buffer.byteLength <= warmMemory + 4 * 1024 * 1024,
  `Wasm memory grew across repeated worlds: ${warmMemory} -> ${api.memory.buffer.byteLength}`);
const reuseHighWater = api.memory.buffer.byteLength;
api.world_new(24, 20);
for (const line of reference) {
  const [scene, ticks, ...expected] = line.split(';');
  assert.equal(text(api.world_oracle(Number(scene), Number(ticks))), expected.join(';'), `Lean/Wasm mismatch: ${line}`);
}
const catalogue = JSON.parse(text(api.world_catalogue()));
assert.ok(catalogue.length >= 34);
for (const {id} of catalogue) {
  api.world_scene(0); api.world_paint(12, 6, 2, id);
  const before = text(api.world_audit());
  for (let i = 0; i < 3; i++) api.world_tick();
  assert.equal(text(api.world_audit()), before, `Element/energy drift for material ${id}`);
  assert.equal(api.world_solver_failures(), 0n, `Accuracy limit for material ${id}`);
}
api.world_free();
api.world_new(48, 32);
for (let scene = 0; scene < 11; scene++) {
  api.world_scene(scene);
  const budget = text(api.world_audit());
  for (let i = 0; i < 3; i++) api.world_tick();
  assert.equal(text(api.world_audit()), budget, `Default-size scene ${scene} budget drift`);
  assert.equal(api.world_solver_failures(), 0n, `Default-size scene ${scene} accuracy limit`);
  assert.equal(api.world_time_ms(), 5n, `Default-size scene ${scene} rejected a tick`);
}
api.world_free();
api.world_new(24, 20);
api.world_scene(3);
const checkpoint = api.world_digest();
const checkpointTime = api.world_time_ms();
api.world_checkpoint(); api.world_paint(12, 4, 3, 9); api.world_tick();
assert.notEqual(api.world_digest(), checkpoint);
assert.ok(api.world_time_ms() > checkpointTime, "Lean time did not advance");
api.world_undo(); assert.equal(api.world_digest(), checkpoint);
assert.equal(api.world_time_ms(), checkpointTime, "Undo did not restore Lean time");
for (const view of [0,1,2]) api.world_render(view);
assert.equal(api.world_digest(), checkpoint, 'Rendering mutated simulation');
api.world_free();
api.world_new(96, 64); api.world_scene(1);
const before = text(api.world_audit());
const start = performance.now();
for (let i = 0; i < 10; i++) api.world_tick();
const msPerTick = (performance.now() - start) / 10;
assert.equal(text(api.world_audit()), before, 'Full-size conservation failed');
assert.equal(api.world_solver_failures(), 0n, 'Full-size accuracy limit');
api.world_render(0);
api.world_clear(); assert.equal(api.world_render(0), 0);
api.world_free();
console.log(`Wasm memory reuse after 65 empty-world ticks: ${reuseHighWater} byte high-water mark.`);
console.log(`Lean/native/browser differential check: ${reference.length} complete-world states agree.`);
console.log(`All ${catalogue.length} palette materials conserve every tracked element and energy. Exact undo and read-only rendering verified.`);
console.log(`96x64 dam-break benchmark: ${msPerTick.toFixed(2)} ms/tick.`);
