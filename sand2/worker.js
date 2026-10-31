import {loadEngine} from './engine.js';

let api;
let width, height;
self.onmessage = async ({data}) => {
  try {
    if (data.type === 'init') {
      ({width, height} = data);
      api = await loadEngine();
      api.world_new(width, height);
      const pointer = api.world_catalogue();
      const catalogue = new TextDecoder().decode(new Uint8Array(api.memory.buffer, pointer, api.world_text_length()));
      self.postMessage({type: 'ready', catalogue});
      return;
    }
    if (!api || data.type !== 'frame') return;
    const start = performance.now();
    let stepsTaken = 0;
    const tick = () => {
      const previous = api.world_steps();
      api.world_tick();
      const advanced = api.world_steps() !== previous;
      stepsTaken += Number(advanced);
      return advanced;
    };
    for (const [name, ...args] of data.commands) {
      if (name === 'world_tick') tick(); else api[name](...args);
    }
    if (data.tick) {
      // A display frame may contain several finer Lean timesteps. Bound both
      // worker occupancy and model-time advance; manual steps remain exact.
      const modelStart = api.world_time_ms();
      do {
        if (!tick()) break;
      } while (performance.now() - start < 8 && api.world_time_ms() - modelStart < 16n);
    }
    const tickMs = stepsTaken ? (performance.now() - start) / stepsTaken : 0;
    const count = api.world_render(data.view);
    const pixels = new Uint8Array(api.memory.buffer, api.world_pixels(), width * height * 4).slice();
    let inspect;
    if (data.inspect) {
      const pointer = api.world_inspect(...data.inspect);
      inspect = new TextDecoder().decode(new Uint8Array(api.memory.buffer, pointer, api.world_text_length()));
    }
    self.postMessage({type: 'frame', pixels, count, inspect, tickMs, stepsTaken, steps: api.world_steps(), timeMs: api.world_time_ms(), failures: api.world_solver_failures()}, [pixels.buffer]);
  } catch (error) {
    self.postMessage({type: 'error', message: String(error?.stack || error)});
  }
};
