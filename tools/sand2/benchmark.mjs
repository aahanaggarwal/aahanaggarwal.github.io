import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {loadEngine} from '../../sand2/engine.js';

const artifact = process.env.SAND2_BENCH_WASM || fileURLToPath(new URL('../../sand2/pkg/sand2.wasm', import.meta.url));
const bytes = await readFile(artifact);
const sha256 = createHash('sha256').update(bytes).digest('hex');
const fetchOriginal = globalThis.fetch;
globalThis.fetch = async url => url.protocol === 'file:'
  ? new Response(url.pathname.endsWith('.wasm') ? bytes : await readFile(fileURLToPath(url))) : fetchOriginal(url);
const api = await loadEngine();
if (api.world_allocator_check) assert.equal(api.world_allocator_check(), 0);
if (api.world_runtime_check) assert.equal(api.world_runtime_check(), 0);
const text = pointer => new TextDecoder().decode(new Uint8Array(api.memory.buffer, pointer, api.world_text_length()));
const widths = process.argv[2] ? [Number(process.argv[2])] : [48,96];
const scenes = (process.env.SAND2_BENCH_SCENES || '0,1,2,6').split(',').map(Number);
const ticks = Number(process.env.SAND2_BENCH_TICKS || 5);
const warmup = Number(process.env.SAND2_BENCH_WARMUP || 0);
const windowSize = Number(process.env.SAND2_BENCH_WINDOW || ticks);
const maximumMs = Number(process.env.SAND2_BENCH_MAX_MS || Infinity);
assert.ok(Number.isSafeInteger(ticks) && ticks > 0);
assert.ok(Number.isSafeInteger(warmup) && warmup >= 0);
assert.ok(Number.isSafeInteger(windowSize) && windowSize > 0);
for (const width of widths) {
  assert.ok(Number.isInteger(width) && width >= 24 && width <= 192 && width%3 === 0);
  for (const scene of scenes) {
    assert.ok(Number.isInteger(scene) && scene >= 0 && scene <= 10);
    api.world_new(width,width*2/3); api.world_scene(scene);
    const budget = text(api.world_audit());
    for (let tick = 0; tick < warmup; tick++) api.world_tick();
    for (let elapsed = 0; elapsed < ticks;) {
      const count = Math.min(windowSize,ticks-elapsed);
      const start = performance.now();
      for (let tick = 0; tick < count; tick++) api.world_tick();
      const msPerTick = (performance.now()-start)/count;
      elapsed += count;
      assert.equal(text(api.world_audit()),budget,`Conservation failed for ${width}, scene ${scene}`);
      assert.equal(api.world_solver_failures(),0n,`Accuracy failed for ${width}, scene ${scene}`);
      assert.equal(api.world_steps(),warmup+elapsed,'Rejected or missing model step');
      console.log(JSON.stringify({sha256,width,scene,tick:warmup+elapsed,windowTicks:count,msPerTick,
        modelTimeMs:Number(api.world_time_ms()),memoryBytes:api.memory.buffer.byteLength,digest:String(api.world_digest())}));
      assert.ok(msPerTick <= maximumMs,`Performance budget exceeded: ${msPerTick.toFixed(2)} > ${maximumMs} ms/tick`);
    }
    api.world_free();
  }
}
