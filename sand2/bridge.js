// Keep the page responsive while the richer Lean model runs. Only one worker
// batch is in flight; delayed rendering never creates an unbounded tick queue.
export async function loadGame(width, height, onError) {
  const worker = new Worker(new URL('./worker.js', import.meta.url), {type: 'module'});
  const pixelBytes = width * height * 4;
  const buffer = new ArrayBuffer(pixelBytes + 32768);
  const bytes = new Uint8Array(buffer);
  const encoder = new TextEncoder();
  let textLength = 0, count = 0, history = 0, catalogue, inspect = '';
  let busy = false, tick = false, disposed = false, view = 0, dirty = false;
  let commands = [], point, tickMs = 0;
  const writeText = value => {
    const text = encoder.encode(value);
    bytes.set(text, pixelBytes); textLength = text.length;
    return pixelBytes;
  };
  const pump = () => {
    if (disposed || busy || !dirty) return;
    busy = true; dirty = false;
    worker.postMessage({type: 'frame', commands, tick, view, inspect: point});
    commands = []; tick = false;
  };
  const command = (name, ...args) => {
    if (disposed) return;
    // Coalesce excessive intermediate pointer samples, preserving control order.
    if (name === 'world_paint' && commands.length >= 512 && commands.at(-1)?.[0] === name) commands[commands.length - 1] = [name, ...args];
    else commands.push([name, ...args]);
    dirty = true; queueMicrotask(pump);
  };
  await new Promise((resolve, reject) => {
    worker.onerror = event => { disposed = true; commands = []; worker.terminate(); reject(new Error(event.message)); onError?.(new Error(event.message)); };
    worker.onmessage = ({data}) => {
      if (data.type === 'ready') { catalogue = data.catalogue; resolve(); }
      else if (data.type === 'error') { disposed = true; commands = []; worker.terminate(); reject(new Error(data.message)); onError?.(new Error(data.message)); }
      else if (data.type === 'frame') {
        busy = false; bytes.set(data.pixels, 0); count = data.count;
        if (data.inspect !== undefined) inspect = data.inspect;
        if (data.tickMs) tickMs = data.tickMs;
        pump();
      }
    };
    worker.postMessage({type: 'init', width, height});
  });
  return {
    memory: {buffer},
    world_new() {}, // The worker has already constructed the Lean world.
    world_free() { disposed = true; commands = []; worker.terminate(); },
    world_scene(scene) { command('world_scene', scene); },
    world_clear() { command('world_clear'); },
    world_paint(...args) { command('world_paint', ...args); },
    world_tick() { tick = true; dirty = true; queueMicrotask(pump); },
    world_render(nextView) { if (view !== nextView) { view = nextView; dirty = true; queueMicrotask(pump); } return count; },
    world_pixels() { return 0; },
    world_checkpoint() { history = Math.min(16, history + 1); command('world_checkpoint'); return history; },
    world_undo() { if (history) { history--; command('world_undo'); } return history; },
    world_catalogue() { return writeText(catalogue); },
    world_inspect(x, y) { point = [x, y]; dirty = true; queueMicrotask(pump); return writeText(inspect); },
    world_text_length() { return textLength; },
    simulation_hz() { return tickMs > 0 ? Math.round(1000 / tickMs) : 0; },
  };
}
