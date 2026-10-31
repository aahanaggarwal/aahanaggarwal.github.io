import {loadGame} from './bridge.js';

const WIDTH = 96, HEIGHT = 64;
let epoch = 0;
let dispose;

export function cleanup() { epoch++; dispose?.(); dispose = undefined; }

export async function run() {
  cleanup();
  const generation = epoch;
  const root = document.getElementById('s2');
  if (!root) return;
  const el = name => root.querySelector(`#s2-${name}`);
  document.body.classList.add('s2-active');
  const controller = new AbortController();
  const signal = controller.signal;
  let api, animation, pointer = null, drawing = false, eraseStroke = false, lastPaint;
  let paused = false, speed = 1, brush = 3, material, count = 0, view = 0;
  let MATERIALS = [];
  let activePointer = null;
  let lastTime = 0, accumulator = 0, frames = 0, statsTime = 0;
  let history = 0;
  const decoder = new TextDecoder();
  const textResult = (pointer, length) => decoder.decode(new Uint8Array(api.memory.buffer, pointer, length));
  const canvas = el('canvas');
  const ctx = canvas.getContext('2d', {alpha: false});
  const buffer = document.createElement('canvas');
  buffer.width = WIDTH; buffer.height = HEIGHT;
  const bufferCtx = buffer.getContext('2d', {alpha: false});
  const on = (target, event, action, options = {}) => target.addEventListener(event, action, {...options, signal});
  let image;
  const draw = () => {
    count = api.world_render(view);
    // The module can grow its memory; never retain a detached typed-array view.
    image = new ImageData(new Uint8ClampedArray(api.memory.buffer, api.world_pixels(), WIDTH * HEIGHT * 4), WIDTH, HEIGHT);
    bufferCtx.putImageData(image, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(buffer, 0, 0, canvas.width, canvas.height);
    if (pointer) {
      ctx.strokeStyle = material.id === 0 || eraseStroke ? '#f5ada6cc' : '#dde8ddaa';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(pointer.x * canvas.width / WIDTH, pointer.y * canvas.height / HEIGHT, (brush + .5) * canvas.width / WIDTH, 0, Math.PI * 2);
      ctx.stroke();
    }
    el('empty-hint').hidden = count !== 0 || el('scene').value !== '0';
  };
  const snapshot = () => {
    if (!api) return;
    history = api.world_checkpoint();
    el('undo').disabled = false;
  };
  const stopDrawing = () => { activePointer = null; drawing = false; eraseStroke = false; lastPaint = undefined; };
  dispose = () => {
    controller.abort(); cancelAnimationFrame(animation);
    stopDrawing(); api?.world_free(); api = undefined;
    document.body.classList.remove('s2-active');
  };
  const select = item => {
    material = item;
    root.querySelectorAll('[data-material]').forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.material) === item.id)));
    el('eraser').setAttribute('aria-pressed', String(item.id === 0));
    el('selected-name').textContent = item.name;
    el('selected-type').textContent = item.type;
    el('selected-description').textContent = item.description;
    el('selected-swatch').style.background = item.color;
    root.style.setProperty('--selected-color', item.color);
  };
  const eraser = {id: 0, name: 'Eraser', type: 'TOOL', color: '#dfa19a', description: 'Make room for your next idea. Right-click or hold Shift while drawing to erase, too.'};
  const setPaused = value => {
    paused = value; accumulator = 0;
    el('play-label').textContent = value ? 'Play' : 'Pause';
    el('play-icon').textContent = value ? '▷' : 'Ⅱ';
    el('play').setAttribute('aria-label', value ? 'Play simulation' : 'Pause simulation');
    el('paused').hidden = !value;
    el('state').textContent = value ? 'PAUSED' : 'RUNNING';
    root.dataset.paused = String(value);
  };
  const setBrush = value => {
    brush = Math.min(16, Math.max(1, value));
    el('brush').value = brush; el('brush-value').value = brush;
  };
  const setScene = (name, remember = true) => {
    if (remember) snapshot();
    stopDrawing(); api.world_scene(Number(name));
    el('scene').value = name;
    accumulator = 0;
    draw();
    el('count').textContent = count.toLocaleString();
  };
  const undo = () => {
    if (!history) return;
    stopDrawing(); history = api.world_undo();
    el('undo').disabled = history === 0;
    draw();
  };
  const paint = () => {
    if (!pointer || !drawing) return;
    const previous = lastPaint ?? pointer;
    const distance = Math.hypot(pointer.x - previous.x, pointer.y - previous.y);
    const steps = Math.max(1, Math.ceil(distance / Math.max(1, brush * .5)));
    for (let i = 1; i <= steps; i++) {
      api.world_paint(Math.round(previous.x + (pointer.x - previous.x) * i / steps), Math.round(previous.y + (pointer.y - previous.y) * i / steps), brush, eraseStroke ? 0 : material.id);
    }
    lastPaint = {...pointer};
  };
  const location = event => {
    const bounds = canvas.getBoundingClientRect();
    return {x: (event.clientX - bounds.left) / bounds.width * WIDTH, y: (event.clientY - bounds.top) / bounds.height * HEIGHT};
  };
  try {
    api = await loadGame(WIDTH, HEIGHT, error => {
      if (generation !== epoch || !root.isConnected) return;
      console.error('Sand 2 worker:', error);
      root.dataset.state = 'error';
      el('loading').hidden = false;
      el('loading').textContent = 'Simulation stopped. Reload to start again.';
      setPaused(true);
    });
    if (generation !== epoch || !root.isConnected) { api.world_free(); return; }
    api.world_new(WIDTH, HEIGHT);
    const cataloguePointer = api.world_catalogue();
    MATERIALS = JSON.parse(textResult(cataloguePointer, api.world_text_length())).map((item, index) => ({...item, color: `#${item.color.toString(16).padStart(6, '0')}`, key: index < 9 ? String(index + 1) : ''}));
    material = MATERIALS[0];
  for (const item of MATERIALS) {
    const button = document.createElement('button');
    button.type = 'button'; button.className = 's2-material'; button.dataset.material = item.id;
    button.setAttribute('aria-pressed', String(item.id === material.id));
    button.setAttribute('aria-label', `${item.name}${item.key ? ` (${item.key})` : ''}`);
    const swatch = document.createElement('span');
    swatch.className = 's2-swatch'; swatch.style.background = item.color; swatch.setAttribute('aria-hidden', 'true');
    const label = document.createElement('span'); label.textContent = item.name;
    const key = document.createElement('kbd'); key.textContent = item.key;
    button.append(swatch, label, key);
    on(button, 'click', () => select(item));
    el('materials').append(button);
  }
    select(material);
    el('loading').hidden = true;
    root.dataset.state = 'ready';
    setPaused(false);
    setScene('1', false);

    on(el('play'), 'click', () => setPaused(!paused));
    on(el('step'), 'click', () => { setPaused(true); api.world_tick(); draw(); });
    on(el('speed'), 'click', () => {
      speed = speed === 1 ? 2 : speed === 2 ? .5 : 1;
      el('speed').textContent = `${speed}×`;
      el('speed').setAttribute('aria-label', `Simulation speed: ${speed} times`);
    });
    on(el('brush'), 'input', event => setBrush(Number(event.target.value)));
    on(el('eraser'), 'click', () => select(material.id === 0 ? MATERIALS[0] : eraser));
    on(el('undo'), 'click', undo);
    on(el('clear'), 'click', () => setScene('0'));
    on(el('scene'), 'change', event => setScene(event.target.value));
    on(el('view'), 'change', event => { view = Number(event.target.value); draw(); });
    on(el('snapshot'), 'click', () => {
      const picture = document.createElement('canvas');
      picture.width = WIDTH * 4; picture.height = HEIGHT * 4;
      const pictureCtx = picture.getContext('2d'); pictureCtx.imageSmoothingEnabled = false;
      pictureCtx.drawImage(buffer, 0, 0, picture.width, picture.height);
      picture.toBlob(blob => {
        if (!blob) return;
        const link = document.createElement('a'); link.href = URL.createObjectURL(blob);
        link.download = 'sand-game-2.png'; link.click();
        setTimeout(() => URL.revokeObjectURL(link.href), 1000);
      });
    });
    on(canvas, 'pointerdown', event => {
      if (drawing || (event.button !== 0 && event.button !== 2)) return;
      event.preventDefault(); canvas.focus({preventScroll: true});
      canvas.setPointerCapture(event.pointerId);
      snapshot(); activePointer = event.pointerId; pointer = location(event); drawing = true;
      eraseStroke = event.button === 2 || event.shiftKey;
      lastPaint = undefined; paint();
    });
    on(canvas, 'pointermove', event => { if (drawing && event.pointerId !== activePointer) return; pointer = location(event); if (drawing) paint(); });
    on(canvas, 'pointerup', event => { if (event.pointerId !== activePointer) return; if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId); stopDrawing(); });
    on(canvas, 'pointercancel', event => { if (event.pointerId === activePointer) stopDrawing(); });
    on(canvas, 'lostpointercapture', event => { if (event.pointerId === activePointer) stopDrawing(); });
    on(canvas, 'pointerleave', () => { if (!drawing) pointer = null; });
    on(canvas, 'contextmenu', event => event.preventDefault());
    on(canvas, 'wheel', event => { event.preventDefault(); setBrush(brush + (event.deltaY < 0 ? 1 : -1)); }, {passive: false});
    on(window, 'blur', () => { stopDrawing(); pointer = null; });
    on(document, 'visibilitychange', () => { stopDrawing(); lastTime = 0; accumulator = 0; });
    on(document, 'keydown', event => {
      if (/^(INPUT|SELECT|TEXTAREA)$/.test(event.target.tagName) || event.target.isContentEditable || event.metaKey || event.altKey) return;
      const key = event.key.toLowerCase();
      if (event.code === 'Space') { if (event.target.tagName === 'BUTTON' || event.target.tagName === 'A') return; event.preventDefault(); setPaused(!paused); }
      else if (key === 'z') { event.preventDefault(); undo(); }
      else if (event.ctrlKey) return;
      else if (key === 'e') select(eraser);
      else if (key === 'h') { view = view === 1 ? 0 : 1; el('view').value = String(view); }
      else if (key === '[' || key === '-') setBrush(brush - 1);
      else if (key === ']' || key === '=') setBrush(brush + 1);
      else if (key === '.') { setPaused(true); api.world_tick(); draw(); }
      else { const item = MATERIALS.find(item => item.key && item.key === key); if (item) select(item); }
    });
    const loop = time => {
      if (generation !== epoch || !root.isConnected) return;
      if (document.hidden) { lastTime = 0; animation = requestAnimationFrame(loop); return; }
      if (!lastTime) lastTime = time;
      const elapsed = Math.min(80, time - lastTime); lastTime = time;
      if (drawing) paint();
      if (!paused) {
        accumulator = Math.min(accumulator + elapsed * speed, 100);
        let ticks = 0;
        while (accumulator >= 1000 / 60 && ticks < 2) { api.world_tick(); accumulator -= 1000 / 60; ticks++; }
      }
      draw(); frames++;
      if (time - statsTime > 500) {
        if (pointer) { const p = api.world_inspect(Math.floor(pointer.x), Math.floor(pointer.y)); el('inspect').textContent = textResult(p, api.world_text_length()); }
        el('count').textContent = count.toLocaleString();
        el('fps').textContent = `${Math.min(240, Math.round(frames * 1000 / (time - statsTime)))} FPS · ${api.simulation_hz()} Hz`;
        frames = 0; statsTime = time;
      }
      animation = requestAnimationFrame(loop);
    };
    animation = requestAnimationFrame(loop);
  } catch (error) {
    if (generation !== epoch || !root.isConnected) return;
    console.error('Sand Game 2 failed:', error);
    root.dataset.state = 'error';
    el('loading').textContent = 'This world could not load. Reload the page to try again.';
    el('state').textContent = 'WORLD UNAVAILABLE';
  }
}
