import init, { Universe, Cell } from './pkg/sand.js';

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

let universe;
let memory;
let selectedColor = 1;
let isDrawing = false;
let isPaused = false;
let animationId;
let mouseX = -1;
let mouseY = -1;
const radius = 1;

async function run() {
    const wasm = await init();
    memory = wasm.memory;

    universe = Universe.new(GRID_WIDTH, GRID_HEIGHT);

    const canvas = document.getElementById('sand-canvas');
    canvas.width = GRID_WIDTH * CELL_SIZE;
    canvas.height = GRID_HEIGHT * CELL_SIZE;

    const ctx = canvas.getContext('2d');

    setupControls();
    setupCursor();
    setupKeyboard();

    const renderLoop = () => {
        if (isDrawing) {
            paint(canvas);
        }

        if (!isPaused) {
            universe.tick();
        }
        draw(ctx);
        animationId = requestAnimationFrame(renderLoop);
    };
    renderLoop();

    setupInteractions(canvas);
}

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
    const data = imgData.data;

    for (let i = 0; i < cells.length; i++) {
        const colorIdx = cells[i];
        const color = COLORS[colorIdx] || COLORS[0];

        const base = i * 4;
        data[base] = color[0];
        data[base + 1] = color[1];
        data[base + 2] = color[2];
        data[base + 3] = color[3];
    }

    window.offscreenCtx.putImageData(imgData, 0, 0);

    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(window.offscreenCanvas, 0, 0, ctx.canvas.width, ctx.canvas.height);
}

function setupControls() {
    const container = document.getElementById('controls');
    const existingBtns = container.querySelectorAll('.color-btn');
    existingBtns.forEach(b => b.remove());

    let tooltip = document.getElementById('custom-tooltip');
    if (!tooltip) {
        tooltip = document.createElement('div');
        tooltip.id = 'custom-tooltip';
        tooltip.style.position = 'absolute';
        tooltip.style.padding = '8px 12px';
        tooltip.style.background = '#000';
        tooltip.style.border = '2px solid #33ff00';
        tooltip.style.color = '#33ff00';
        tooltip.style.fontFamily = "'Courier New', Courier, monospace";
        tooltip.style.fontSize = '14px';
        tooltip.style.fontWeight = 'bold';
        tooltip.style.pointerEvents = 'none';
        tooltip.style.display = 'none';
        tooltip.style.zIndex = '1000';
        tooltip.style.boxShadow = '0 0 10px #33ff00';
        tooltip.style.textTransform = 'uppercase';
        document.body.appendChild(tooltip);
    }

    ELEMENT_NAMES.forEach((name, idx) => {
        if (idx === 0) return;
        if (name === "Fire") return;
        if (["Smoke", "Glass", "Obsidian"].includes(name)) return;

        const btn = document.createElement('div');
        btn.className = 'color-btn';
        const rgba = COLORS[idx];
        btn.style.backgroundColor = `rgba(${rgba[0]}, ${rgba[1]}, ${rgba[2]}, ${rgba[3] / 255})`;

        if (idx === selectedColor) btn.classList.add('active');

        btn.onclick = () => {
            selectedColor = idx;
            document.querySelectorAll('.color-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        };

        btn.onmouseenter = () => {
            tooltip.innerText = name;
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

function setupKeyboard() {
    document.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
            isPaused = !isPaused;
            e.preventDefault();
        }
    });
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

function paint(canvas) {
    if (mouseX === -1 || mouseY === -1) return;

    const dx = mouseX;
    const dy = mouseY;

    universe.paint(dy, dx, selectedColor, radius);
}

function setupInteractions(canvas) {
    const updateMouse = (e) => {
        const coords = getCoords(e, canvas);
        mouseX = coords.x;
        mouseY = coords.y;
    };

    canvas.addEventListener('mousedown', (e) => {
        isDrawing = true;
        updateMouse(e);
        universe.paint(mouseY, mouseX, selectedColor, radius);
    });

    canvas.addEventListener('mousemove', (e) => {
        updateMouse(e);
    });

    window.addEventListener('mouseup', () => {
        isDrawing = false;
        mouseX = -1;
        mouseY = -1;
    });

    canvas.addEventListener('mouseleave', () => {
        mouseX = -1;
    });

    canvas.addEventListener('touchstart', (e) => {
        e.preventDefault();
        isDrawing = true;
        updateMouse(e);
    }, { passive: false });

    canvas.addEventListener('touchmove', (e) => {
        e.preventDefault();
        updateMouse(e);
    }, { passive: false });

    window.addEventListener('touchend', () => isDrawing = false);
}

function setupCursor() {
    const cursor = document.getElementById("cursor");
    document.addEventListener("mousemove", (e) => {
        if (cursor) {
            cursor.style.transform = `translate3d(${e.clientX}px, ${e.clientY}px, 0)`;
        }
    });

    document.addEventListener("click", () => {
        if (cursor) {
            cursor.classList.add("expand");
            setTimeout(() => cursor.classList.remove("expand"), 200);
        }
    });
}

run();
