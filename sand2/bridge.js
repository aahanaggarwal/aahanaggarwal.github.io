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
  let commands = [], point, steps = 0, timeMs = 0n, failures = 0n, sentAt = 0, batchMs = 1000 / 60;
  let completedTicks = [];
  const writeText = value => {
    const text = encoder.encode(value);
    bytes.set(text, pixelBytes); textLength = text.length;
    return pixelBytes;
  };
  const pump = () => {
    if (disposed || busy || !dirty) return;
    // Return a rendered frame after each manual step even on a stiff scene.
    // Keeping the remaining commands here preserves their exact order.
    const manual = commands.findIndex(([name]) => name === 'world_tick');
    const batch = manual < 0 ? commands : commands.slice(0, manual + 1);
    commands = manual < 0 ? [] : commands.slice(manual + 1);
    const advance = manual < 0 && tick;
    if (advance) tick = false;
    busy = true; dirty = commands.length > 0 || tick; sentAt = performance.now();
    worker.postMessage({type: 'frame', commands: batch, tick: advance, view, inspect: point});
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
        steps = data.steps; timeMs = data.timeMs; failures = data.failures;
        const now = performance.now();
        if (data.stepsTaken) {
          const elapsed = (now - sentAt) / data.stepsTaken;
          batchMs = batchMs === 1000 / 60 ? elapsed : batchMs * .8 + elapsed * .2;
          for (let i = 0; i < data.stepsTaken; i++) completedTicks.push(now);
        }
        completedTicks = completedTicks.filter(t => now - t < 1000);
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
    world_step() { command('world_tick'); },
    world_pause() { tick = false; },
    world_steps() { return steps; },
    world_time_ms() { return timeMs; },
    world_solver_failures() { return failures; },
    world_render(nextView) { if (view !== nextView) { view = nextView; dirty = true; queueMicrotask(pump); } return count; },
    world_pixels() { return 0; },
    world_checkpoint() { history = Math.min(16, history + 1); command('world_checkpoint'); return history; },
    world_undo() { if (history) { history--; command('world_undo'); } return history; },
    world_catalogue() { return writeText(catalogue); },
    world_inspect(x, y) { point = [x, y]; dirty = true; queueMicrotask(pump); return writeText(inspect); },
    world_text_length() { return textLength; },
    simulation_hz() { const now = performance.now(); completedTicks = completedTicks.filter(t => now - t < 1000); return completedTicks.length; },
    simulation_interval() { return Math.max(1000 / 60, batchMs); },
  };
}
