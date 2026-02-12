import init, { Universe } from './pkg/sand.js';

const CELL_SIZE = 4;
const GRID_WIDTH = 128;
const GRID_HEIGHT = 128;

const COLORS = [
    [0, 0, 0, 0],             // Empty
    [237, 201, 175, 255],     // Sand
    [0, 119, 190, 255],       // Water
    [128, 128, 128, 255],     // Stone
    [139, 69, 19, 255],       // Wood
    [255, 69, 0, 255],        // Fire
    [220, 220, 220, 255],     // Steam
    [50, 50, 50, 255],        // Oil
    [173, 255, 47, 255],      // Acid
    [207, 16, 32, 255],       // Lava
    [34, 139, 34, 255],       // Plant
    [173, 216, 230, 255],     // Ice
    // Hidden Elements
    [50, 50, 50, 150],        // Smoke (Semi-transparent)
    [200, 220, 255, 180],     // Glass (Semi-transparent Blueish)
    [40, 0, 60, 255],         // Obsidian (Dark Purple)
    [64, 64, 64, 255],        // Gunpowder (Dark Grey)
];

const ELEMENT_NAMES = [
    "Empty", "Sand", "Water", "Stone", "Wood", "Fire",
    "Steam", "Oil", "Acid", "Lava", "Plant", "Ice",
    "Smoke", "Glass", "Obsidian", "Gunpowder"
];

const ELEMENT_KEYS = {
    '1': 1,  // Sand
    '2': 2,  // Water
    '3': 3,  // Stone
    '4': 4,  // Wood
    '5': 7,  // Oil
    '6': 8,  // Acid
    '7': 9,  // Lava
    '8': 10, // Plant
    '9': 11, // Ice
    '0': 15, // Gunpowder
};

let universe;
let memory;
let selectedColor = 1;
let isDrawing = false;
let isPaused = false;
let animationId;
let mouseX = -1;
let mouseY = -1;
const radius = 1;

let abortController = null;

export async function run() {
    // Clean up previous run
    if (abortController) abortController.abort();
    if (animationId) cancelAnimationFrame(animationId);
    abortController = new AbortController();
    const signal = abortController.signal;

    isDrawing = false;
    isPaused = false;
    mouseX = -1;
    mouseY = -1;

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

    const renderLoop = () => {
        if (!document.body.contains(canvas)) {
            cancelAnimationFrame(animationId);
            return;
        }

        if (isDrawing) {
            paint();
        }

        if (!isPaused) {
            universe.tick();
        }
        draw(ctx);
        animationId = requestAnimationFrame(renderLoop);
    };
    renderLoop();

    setupInteractions(canvas, signal);
}

let U32_COLORS = null;

function draw(ctx) {
    const cellsPtr = universe.cells();
    const width = universe.width();
    const height = universe.height();
    const cells = new Uint8Array(memory.buffer, cellsPtr, width * height);

    if (!window.offscreenCanvas) {
        window.offscreenCanvas = document.createElement('canvas');
        window.offscreenCanvas.width = width;
        window.offscreenCanvas.height = height;
        window.offscreenCtx = window.offscreenCanvas.getContext('2d');
        window.offscreenData = window.offscreenCtx.createImageData(width, height);
    }

    const imgData = window.offscreenData;
    const buf32 = new Uint32Array(imgData.data.buffer);

    if (!U32_COLORS) {
        U32_COLORS = new Uint32Array(COLORS.length);
        for (let i = 0; i < COLORS.length; i++) {
            const [r, g, b, a] = COLORS[i];
            U32_COLORS[i] = ((a << 24) | (b << 16) | (g << 8) | r) >>> 0;
        }
    }

    for (let i = 0; i < cells.length; i++) {
        buf32[i] = U32_COLORS[cells[i]];
    }

    window.offscreenCtx.putImageData(imgData, 0, 0);

    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(window.offscreenCanvas, 0, 0, ctx.canvas.width, ctx.canvas.height);
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

    ELEMENT_NAMES.forEach((name, idx) => {
        if (idx === 0) return;
        if (name === "Fire") return;
        if (["Smoke", "Glass", "Obsidian"].includes(name)) return;

        const btn = document.createElement('div');
        btn.className = 'color-btn';
        btn.dataset.idx = idx;
        const rgba = COLORS[idx];
        btn.style.backgroundColor = `rgba(${rgba[0]}, ${rgba[1]}, ${rgba[2]}, ${rgba[3] / 255})`;

        const keyLabel = Object.entries(ELEMENT_KEYS).find(([, v]) => v === idx);
        if (keyLabel) {
            btn.setAttribute('data-key', keyLabel[0]);
        }

        if (idx === selectedColor) btn.classList.add('active');

        btn.onclick = () => selectElement(idx);

        btn.onmouseenter = () => {
            const keyHint = keyLabel ? ` [${keyLabel[0]}]` : '';
            tooltip.innerText = name + keyHint;
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

    document.getElementById('reset-btn').onclick = () => {
        universe.clear();
    };
}

function selectElement(idx) {
    selectedColor = idx;
    const container = document.getElementById('controls');
    if (!container) return;
    container.querySelectorAll('.color-btn').forEach((b, i) => {
        b.classList.toggle('active', b.dataset.idx === String(idx));
    });
}

function setupKeyboard(signal) {
    document.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
            isPaused = !isPaused;
            e.preventDefault();
        }
        if (ELEMENT_KEYS[e.key] !== undefined) {
            selectElement(ELEMENT_KEYS[e.key]);
        }
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

    const x = (clientX - rect.left) * scaleX;
    const y = (clientY - rect.top) * scaleY;

    return {
        x: Math.floor(x / CELL_SIZE),
        y: Math.floor(y / CELL_SIZE)
    };
}

function paint() {
    if (mouseX === -1 || mouseY === -1) return;
    universe.paint(mouseY, mouseX, selectedColor, radius);
}

function setupInteractions(canvas, signal) {
    const updateMouse = (e) => {
        const coords = getCoords(e, canvas);
        mouseX = coords.x;
        mouseY = coords.y;
    };

    canvas.addEventListener('mousedown', (e) => {
        isDrawing = true;
        updateMouse(e);
        universe.paint(mouseY, mouseX, selectedColor, radius);
    }, { signal });

    canvas.addEventListener('mousemove', (e) => {
        updateMouse(e);
    }, { signal });

    window.addEventListener('mouseup', () => {
        isDrawing = false;
        mouseX = -1;
        mouseY = -1;
    }, { signal });

    canvas.addEventListener('mouseleave', () => {
        mouseX = -1;
        mouseY = -1;
    }, { signal });

    canvas.addEventListener('touchstart', (e) => {
        e.preventDefault();
        isDrawing = true;
        updateMouse(e);
    }, { passive: false, signal });

    canvas.addEventListener('touchmove', (e) => {
        e.preventDefault();
        updateMouse(e);
    }, { passive: false, signal });

    window.addEventListener('touchend', () => {
        isDrawing = false;
        mouseX = -1;
        mouseY = -1;
    }, { signal });
}

if (!window.HAS_SPA_ROUTER) {
    run();
}
