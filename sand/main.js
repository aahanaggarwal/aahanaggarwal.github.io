import init, { Universe } from './pkg/sand.js';

const CELL_SIZE = 2;
const GRID_WIDTH = 256;
const GRID_HEIGHT = 256;

// Swatch colors for the toolbar (must match base_color() in Rust)
const COLORS = {
    1: [225, 191, 138],   // Sand
    2: [24, 96, 175],     // Water
    3: [118, 118, 118],   // Stone
    4: [102, 70, 40],     // Wood
    7: [58, 48, 38],      // Oil
    8: [130, 230, 40],    // Acid
    9: [215, 75, 18],     // Lava
    10: [42, 160, 52],    // Plant
    11: [160, 205, 240],  // Ice
    15: [78, 78, 88],     // Gunpowder
};

// Same placeable palette as before; everything else (fire, steam, smoke,
// embers, ash, glass, obsidian) only emerges from the simulation.
const TOOLBAR = [
    { id: 1, name: 'Sand', key: '1' },
    { id: 2, name: 'Water', key: '2' },
    { id: 3, name: 'Stone', key: '3' },
    { id: 4, name: 'Wood', key: '4' },
    { id: 7, name: 'Oil', key: '5' },
    { id: 8, name: 'Acid', key: '6' },
    { id: 9, name: 'Lava', key: '7' },
    { id: 10, name: 'Plant', key: '8' },
    { id: 11, name: 'Ice', key: '9' },
    { id: 15, name: 'Gunpowder', key: '0' },
];

let universe;
let memory;
let selectedColor = 1;
let isDrawing = false;
let isErasing = false;
let isPaused = false;
let heatView = false;
let animationId;
let mouseX = -1;
let mouseY = -1;
let lastPaintX = -1;
let lastPaintY = -1;
let brushRadius = 3;
let mouseCanvasX = -1;
let mouseCanvasY = -1;

let abortController = null;

let offscreenCanvas = null;
let offscreenCtx = null;

export async function run() {
    // Clean up previous run
    if (abortController) abortController.abort();
    if (animationId) cancelAnimationFrame(animationId);
    if (universe) { universe.free(); universe = null; }
    abortController = new AbortController();
    const signal = abortController.signal;

    isDrawing = false;
    isErasing = false;
    isPaused = false;
    heatView = false;
    mouseX = -1;
    mouseY = -1;
    lastPaintX = -1;
    lastPaintY = -1;
    offscreenCanvas = null;
    offscreenCtx = null;

    document.body.style.overflow = 'hidden';

    const wasm = await init();
    memory = wasm.memory;

    universe = Universe.new(GRID_WIDTH, GRID_HEIGHT);

    const canvas = document.getElementById('sand-canvas');
    if (!canvas) return;
    canvas.width = GRID_WIDTH * CELL_SIZE;
    canvas.height = GRID_HEIGHT * CELL_SIZE;

    const ctx = canvas.getContext('2d');

    setupControls();
    setupKeyboard(signal);

    // Fixed-timestep simulation (60 ticks/s) decoupled from display refresh
    // rate, so 120/144Hz monitors don't run the physics faster.
    const TICK_MS = 1000 / 60;
    let lastTime = 0;
    let accumulator = 0;

    const renderLoop = (timestamp) => {
        if (!document.body.contains(canvas)) {
            cancelAnimationFrame(animationId);
            return;
        }

        if (isDrawing) {
            paintStroke();
        }

        if (!lastTime) lastTime = timestamp;
        accumulator = Math.min(accumulator + (timestamp - lastTime), 100);
        lastTime = timestamp;

        while (accumulator >= TICK_MS) {
            if (!isPaused) universe.tick();
            accumulator -= TICK_MS;
        }

        draw(ctx);
        animationId = requestAnimationFrame(renderLoop);
    };
    animationId = requestAnimationFrame(renderLoop);

    setupInteractions(canvas, signal);
}

function draw(ctx) {
    universe.render();
    const ptr = universe.pixels();
    const width = universe.width();
    const height = universe.height();
    const pixels = new Uint8ClampedArray(memory.buffer, ptr, width * height * 4);

    if (!offscreenCanvas) {
        offscreenCanvas = document.createElement('canvas');
        offscreenCanvas.width = width;
        offscreenCanvas.height = height;
        offscreenCtx = offscreenCanvas.getContext('2d');
    }

    const imgData = new ImageData(pixels, width, height);
    offscreenCtx.putImageData(imgData, 0, 0);

    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(offscreenCanvas, 0, 0, ctx.canvas.width, ctx.canvas.height);

    // brush preview ring
    if (mouseCanvasX >= 0) {
        ctx.strokeStyle = isErasing ? 'rgba(255,80,80,0.7)' : 'rgba(255,255,255,0.5)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(mouseCanvasX, mouseCanvasY, (brushRadius + 0.5) * CELL_SIZE, 0, Math.PI * 2);
        ctx.stroke();
    }
}

function setupControls() {
    const container = document.getElementById('controls');
    if (!container) return;
    const existingBtns = container.querySelectorAll('.color-btn');
    existingBtns.forEach(b => b.remove());

    let tooltip = document.getElementById('custom-tooltip');
    if (!tooltip) {
        tooltip = document.createElement('div');
        tooltip.id = 'custom-tooltip';
        tooltip.style.cssText = `
            position: absolute; padding: 8px 12px; background: #000;
            border: 2px solid #33ff00; color: #33ff00;
            font-family: 'Courier New', Courier, monospace; font-size: 14px;
            font-weight: bold; pointer-events: none; display: none;
            z-index: 1000; box-shadow: 0 0 10px #33ff00; text-transform: uppercase;
        `;
        document.body.appendChild(tooltip);
    }

    TOOLBAR.forEach(({ id, name, key }) => {
        const btn = document.createElement('div');
        btn.className = 'color-btn';
        btn.dataset.idx = id;
        const rgb = COLORS[id];
        btn.style.backgroundColor = `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`;
        btn.setAttribute('data-key', key);

        if (id === selectedColor) btn.classList.add('active');

        btn.onclick = () => selectElement(id);

        btn.onmouseenter = () => {
            tooltip.innerText = `${name} [${key}]`;
            tooltip.style.display = 'block';
        };
        btn.onmousemove = (e) => {
            tooltip.style.left = (e.pageX + 15) + 'px';
            tooltip.style.top = (e.pageY + 15) + 'px';
        };
        btn.onmouseleave = () => {
            tooltip.style.display = 'none';
        };

        container.appendChild(btn);
    });

    const resetBtn = document.getElementById('reset-btn');
    if (resetBtn) resetBtn.onclick = () => universe.clear();
}

function selectElement(idx) {
    selectedColor = idx;
    const container = document.getElementById('controls');
    if (!container) return;
    container.querySelectorAll('.color-btn').forEach((b) => {
        b.classList.toggle('active', b.dataset.idx === String(idx));
    });
}

function setupKeyboard(signal) {
    document.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
            isPaused = !isPaused;
            e.preventDefault();
            return;
        }
        if (e.key === 'h' || e.key === 'H') {
            heatView = !heatView;
            universe.set_heat_view(heatView);
            return;
        }
        if (e.key === '[' || e.key === '-') {
            brushRadius = Math.max(1, brushRadius - 1);
            return;
        }
        if (e.key === ']' || e.key === '=') {
            brushRadius = Math.min(20, brushRadius + 1);
            return;
        }
        const entry = TOOLBAR.find(t => t.key === e.key.toLowerCase());
        if (entry) selectElement(entry.id);
    }, { signal });
}

function getCoords(e, canvas) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;

    let clientX = e.clientX;
    let clientY = e.clientY;

    if (e.touches && e.touches.length > 0) {
        clientX = e.touches[0].clientX;
        clientY = e.touches[0].clientY;
    }

    const cx = (clientX - rect.left) * scaleX;
    const cy = (clientY - rect.top) * scaleY;

    return {
        x: Math.floor(cx / CELL_SIZE),
        y: Math.floor(cy / CELL_SIZE),
        canvasX: cx,
        canvasY: cy,
    };
}

// Paint a connected stroke from the last position to the current one so fast
// mouse movement doesn't leave gaps.
function paintStroke() {
    if (mouseX === -1 || mouseY === -1) return;
    const mat = isErasing ? 0 : selectedColor;

    if (lastPaintX === -1) {
        universe.paint(mouseY, mouseX, mat, brushRadius);
    } else {
        const dx = mouseX - lastPaintX;
        const dy = mouseY - lastPaintY;
        const steps = Math.max(Math.abs(dx), Math.abs(dy), 1);
        for (let s = 1; s <= steps; s++) {
            const px = Math.round(lastPaintX + (dx * s) / steps);
            const py = Math.round(lastPaintY + (dy * s) / steps);
            universe.paint(py, px, mat, brushRadius);
        }
    }
    lastPaintX = mouseX;
    lastPaintY = mouseY;
}

function setupInteractions(canvas, signal) {
    const updateMouse = (e) => {
        const coords = getCoords(e, canvas);
        mouseX = coords.x;
        mouseY = coords.y;
        mouseCanvasX = coords.canvasX;
        mouseCanvasY = coords.canvasY;
    };

    canvas.addEventListener('mousedown', (e) => {
        isDrawing = true;
        isErasing = e.button === 2;
        updateMouse(e);
        lastPaintX = -1;
        lastPaintY = -1;
        paintStroke();
    }, { signal });

    canvas.addEventListener('contextmenu', (e) => e.preventDefault(), { signal });

    canvas.addEventListener('mousemove', (e) => {
        updateMouse(e);
    }, { signal });

    canvas.addEventListener('wheel', (e) => {
        e.preventDefault();
        brushRadius = Math.min(20, Math.max(1, brushRadius + (e.deltaY < 0 ? 1 : -1)));
    }, { passive: false, signal });

    window.addEventListener('mouseup', () => {
        isDrawing = false;
        isErasing = false;
        lastPaintX = -1;
        lastPaintY = -1;
    }, { signal });

    canvas.addEventListener('mouseleave', () => {
        mouseX = -1;
        mouseY = -1;
        mouseCanvasX = -1;
        mouseCanvasY = -1;
        lastPaintX = -1;
        lastPaintY = -1;
    }, { signal });

    canvas.addEventListener('touchstart', (e) => {
        e.preventDefault();
        isDrawing = true;
        updateMouse(e);
        lastPaintX = -1;
        lastPaintY = -1;
    }, { passive: false, signal });

    canvas.addEventListener('touchmove', (e) => {
        e.preventDefault();
        updateMouse(e);
    }, { passive: false, signal });

    window.addEventListener('touchend', () => {
        isDrawing = false;
        mouseX = -1;
        mouseY = -1;
        lastPaintX = -1;
        lastPaintY = -1;
    }, { signal });
}

export function cleanup() {
    if (abortController) {
        abortController.abort();
        abortController = null;
    }
    if (animationId) {
        cancelAnimationFrame(animationId);
        animationId = null;
    }
    const tooltip = document.getElementById('custom-tooltip');
    if (tooltip && tooltip.parentNode) {
        tooltip.parentNode.removeChild(tooltip);
    }
    document.body.style.overflow = '';
    if (universe) {
        universe.free();
        universe = null;
    }
    memory = null;
    offscreenCanvas = null;
    offscreenCtx = null;
    isDrawing = false;
    isErasing = false;
    isPaused = false;
    mouseX = -1;
    mouseY = -1;
}

if (!window.HAS_SPA_ROUTER) {
    run();
}
