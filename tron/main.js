import wasmInit, { TronGame } from './pkg/tron.js';

// === Constants ===
const GRID_W = 80, GRID_H = 60, CELL_PX = 10;
const TICK_MS = 100;
const CHECKSUM_INTERVAL = 30;
const P1_COLOR = '#00ffff';
const P2_COLOR = '#ff6600';
const P1_HEAD = '#ffffff';
const P2_HEAD = '#ffffff';

// === Module state ===
let game = null, memory = null;
let canvas = null, ctx = null;
let tickInterval = null, animFrameId = null;
let abortController = null;
let mode = null;
let playerNumber = 0;
let peer = null, conn = null;
let p1Score = 0, p2Score = 0;
let gameActive = false;
let countdownTimer = null;

// === Helpers ===

function send(msg) {
    if (conn && conn.open) conn.send(JSON.stringify(msg));
}

function setStatus(text) {
    const el = document.getElementById('tron-status');
    if (el) el.textContent = text;
}

function updateScores() {
    const p1El = document.getElementById('p1-score');
    const p2El = document.getElementById('p2-score');
    if (p1El) p1El.textContent = 'P1: ' + p1Score;
    if (p2El) p2El.textContent = 'P2: ' + p2Score;
}

function showGame() {
    const lobby = document.getElementById('tron-lobby');
    const gameEl = document.getElementById('tron-game');
    if (lobby) lobby.style.display = 'none';
    if (gameEl) gameEl.style.display = 'flex';
}

function generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ';
    let code = '';
    for (let i = 0; i < 4; i++) code += chars[Math.floor(Math.random() * chars.length)];
    return code;
}

function loadPeerJS() {
    if (window.Peer) return Promise.resolve();
    return new Promise((resolve, reject) => {
        const s = document.createElement('script');
        s.src = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
        s.onload = resolve;
        s.onerror = () => reject(new Error('Failed to load PeerJS'));
        document.head.appendChild(s);
    });
}

// === Countdown ===

function startCountdown(onDone) {
    const overlay = document.getElementById('tron-overlay');
    overlay.classList.add('visible');

    let count = 3;
    overlay.textContent = count;

    countdownTimer = setInterval(() => {
        count--;
        if (count > 0) {
            overlay.textContent = count;
        } else if (count === 0) {
            overlay.textContent = 'GO!';
        } else {
            clearInterval(countdownTimer);
            countdownTimer = null;
            overlay.classList.remove('visible');
            overlay.textContent = '';
            onDone();
        }
    }, 800);
}

// === Input ===

function keyToDir(key) {
    switch (key) {
        case 'w': case 'W': case 'ArrowUp': return 0;
        case 'd': case 'D': case 'ArrowRight': return 1;
        case 's': case 'S': case 'ArrowDown': return 2;
        case 'a': case 'A': case 'ArrowLeft': return 3;
        default: return null;
    }
}

function setupInput() {
    const signal = abortController.signal;

    document.addEventListener('keydown', (e) => {
        if (e.key === ' ' || e.key === 'Spacebar') {
            e.preventDefault();
            if (!gameActive && game && game.is_game_over()) {
                requestRematch();
            }
            return;
        }

        const dir = keyToDir(e.key);
        if (dir === null) return;
        e.preventDefault();

        if (mode === 'local') {
            const isArrow = e.key.startsWith('Arrow');
            game.set_direction(isArrow ? 1 : 0, dir);
        } else {
            game.set_direction(playerNumber - 1, dir);
            send({ type: 'dir', dir });
        }
    }, { signal });
}

// === Game loop ===

function gameTick() {
    if (!gameActive || !game) return;

    game.tick();

    if (game.is_game_over()) {
        gameActive = false;
        clearInterval(tickInterval);
        tickInterval = null;
        handleGameOver();
        return;
    }

    if (mode === 'online' && playerNumber === 1 && game.tick_count() % CHECKSUM_INTERVAL === 0) {
        send({ type: 'checksum', tick: game.tick_count(), sum: game.checksum() });
    }
}

function handleGameOver() {
    const w = game.winner();
    if (w === 1) p1Score++;
    else if (w === 2) p2Score++;

    updateScores();

    const overlay = document.getElementById('tron-overlay');
    let text = 'DRAW';
    if (w === 1) text = '<span class="tron-p1">P1 WINS</span>';
    if (w === 2) text = '<span class="tron-p2">P2 WINS</span>';

    overlay.innerHTML = text + '<div style="font-size:0.3em;margin-top:0.5em">SPACE to rematch</div>';
    overlay.classList.add('visible');
}

function startGame() {
    game = TronGame.new(GRID_W, GRID_H);
    gameActive = true;
    setupInput();
    tickInterval = setInterval(gameTick, TICK_MS);
    animFrameId = requestAnimationFrame(render);
}

// === Rematch ===

function requestRematch() {
    if (mode === 'online') {
        send({ type: 'rematch' });
    }
    newRound();
}

function newRound() {
    const overlay = document.getElementById('tron-overlay');
    overlay.classList.remove('visible');
    game.reset();
    gameActive = false;
    startCountdown(() => {
        gameActive = true;
        tickInterval = setInterval(gameTick, TICK_MS);
    });
}

// === Rendering ===

function render(timestamp) {
    if (!canvas || !document.body.contains(canvas)) {
        cleanup();
        return;
    }
    animFrameId = requestAnimationFrame(render);
    if (!game || !memory) return;

    const gridPtr = game.grid_ptr();
    const cells = new Uint8Array(memory.buffer, gridPtr, GRID_W * GRID_H);

    // Clear
    ctx.fillStyle = '#0a0a0a';
    ctx.fillRect(0, 0, 800, 600);

    // Subtle grid lines
    ctx.strokeStyle = 'rgba(0, 255, 65, 0.04)';
    ctx.lineWidth = 0.5;
    for (let x = 0; x <= 800; x += CELL_PX) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, 600);
        ctx.stroke();
    }
    for (let y = 0; y <= 600; y += CELL_PX) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(800, y);
        ctx.stroke();
    }

    // Trails
    ctx.shadowBlur = 0;
    for (let i = 0; i < cells.length; i++) {
        if (cells[i] === 0) continue;
        const x = (i % GRID_W) * CELL_PX;
        const y = Math.floor(i / GRID_W) * CELL_PX;
        ctx.fillStyle = cells[i] === 1 ? P1_COLOR : P2_COLOR;
        ctx.fillRect(x + 1, y + 1, CELL_PX - 2, CELL_PX - 2);
    }

    // Player heads with glow
    if (game.p1_alive()) {
        const hx = game.p1_x() * CELL_PX, hy = game.p1_y() * CELL_PX;
        ctx.shadowColor = P1_COLOR;
        ctx.shadowBlur = 15;
        ctx.fillStyle = P1_HEAD;
        ctx.fillRect(hx, hy, CELL_PX, CELL_PX);
        ctx.shadowBlur = 0;
    }
    if (game.p2_alive()) {
        const hx = game.p2_x() * CELL_PX, hy = game.p2_y() * CELL_PX;
        ctx.shadowColor = P2_COLOR;
        ctx.shadowBlur = 15;
        ctx.fillStyle = P2_HEAD;
        ctx.fillRect(hx, hy, CELL_PX, CELL_PX);
        ctx.shadowBlur = 0;
    }
}

// === Networking ===

function setupConnection(c) {
    conn = c;
    conn.on('data', (raw) => {
        const msg = JSON.parse(raw);
        handleMessage(msg);
    });
    conn.on('close', () => {
        setStatus('Opponent disconnected');
        gameActive = false;
        if (tickInterval) { clearInterval(tickInterval); tickInterval = null; }
    });
}

function handleMessage(msg) {
    switch (msg.type) {
        case 'ready':
            // Guest confirmed ready — host already started countdown in c.on('open')
            break;
        case 'start':
            // Guest receives: host says start
            startCountdown(() => {
                gameActive = true;
                tickInterval = setInterval(gameTick, TICK_MS);
            });
            break;
        case 'dir':
            if (game) {
                const opponentIdx = playerNumber === 1 ? 1 : 0;
                game.set_direction(opponentIdx, msg.dir);
            }
            break;
        case 'checksum':
            // Guest compares checksums
            if (game && playerNumber === 2) {
                const local = game.checksum();
                if (local !== msg.sum) {
                    send({ type: 'desync', tick: msg.tick });
                }
            }
            break;
        case 'sync':
            // Guest loads full state from host
            if (game) {
                game.load_state(new Uint8Array(msg.data));
            }
            break;
        case 'desync':
            // Host sends full state to guest
            if (game && playerNumber === 1) {
                send({ type: 'sync', data: Array.from(game.serialize_state()) });
            }
            break;
        case 'rematch':
            newRound();
            break;
    }
}

// === Cleanup & Run ===

export function cleanup() {
    if (abortController) {
        abortController.abort();
        abortController = null;
    }
    if (tickInterval) { clearInterval(tickInterval); tickInterval = null; }
    if (animFrameId) { cancelAnimationFrame(animFrameId); animFrameId = null; }
    if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }
    if (conn) { conn.close(); conn = null; }
    if (peer) { peer.destroy(); peer = null; }
    if (game) { game.free(); game = null; }

    canvas = null;
    ctx = null;
    memory = null;
    mode = null;
    playerNumber = 0;
    p1Score = 0;
    p2Score = 0;
    gameActive = false;

    // Remove PeerJS script if we added it
    const peerScript = document.querySelector('script[src*="peerjs"]');
    if (peerScript) peerScript.remove();
}

export async function run() {
    cleanup();
    const wasm = await wasmInit();
    memory = wasm.memory;

    canvas = document.getElementById('tron-canvas');
    if (!canvas) return;
    ctx = canvas.getContext('2d');

    abortController = new AbortController();
    const signal = abortController.signal;

    p1Score = 0;
    p2Score = 0;

    // Show lobby, hide game
    const lobby = document.getElementById('tron-lobby');
    const gameEl = document.getElementById('tron-game');
    if (lobby) lobby.style.display = '';
    if (gameEl) gameEl.style.display = 'none';

    // Local play
    document.getElementById('btn-local')?.addEventListener('click', () => {
        mode = 'local';
        showGame();
        const ctrl = document.getElementById('tron-controls');
        if (ctrl) ctrl.textContent = 'P1: WASD  |  P2: ARROWS  |  SPACE: rematch';
        game = TronGame.new(GRID_W, GRID_H);
        setupInput();
        animFrameId = requestAnimationFrame(render);
        startCountdown(() => {
            gameActive = true;
            tickInterval = setInterval(gameTick, TICK_MS);
        });
    }, { signal });

    // Create room
    document.getElementById('btn-create')?.addEventListener('click', async () => {
        try {
            setStatus('Loading...');
            await loadPeerJS();
            const code = generateCode();
            peer = new window.Peer(code, { debug: 0 });

            peer.on('open', () => {
                setStatus('ROOM: ' + code + ' \u2014 Waiting for opponent...');
            });

            peer.on('connection', (c) => {
                playerNumber = 1;
                mode = 'online';
                setupConnection(c);
                const beginHost = () => {
                    showGame();
                    const ctrl = document.getElementById('tron-controls');
                    if (ctrl) ctrl.textContent = 'YOU ARE CYAN  |  WASD or ARROWS';
                    game = TronGame.new(GRID_W, GRID_H);
                    setupInput();
                    animFrameId = requestAnimationFrame(render);
                    send({ type: 'start' });
                    startCountdown(() => {
                        gameActive = true;
                        tickInterval = setInterval(gameTick, TICK_MS);
                    });
                };
                if (c.open) beginHost();
                else c.on('open', beginHost);
            });

            peer.on('error', (err) => {
                if (err.type === 'unavailable-id') {
                    setStatus('Room code taken. Try again.');
                } else {
                    setStatus('Error: ' + err.message);
                }
            });
        } catch (e) {
            setStatus('Failed to load networking library');
        }
    }, { signal });

    // Join room
    document.getElementById('btn-join')?.addEventListener('click', async () => {
        const input = document.getElementById('room-input');
        const code = input?.value?.toUpperCase()?.trim();
        if (!code || code.length < 4) {
            setStatus('Enter a 4-letter room code');
            return;
        }

        try {
            setStatus('Connecting...');
            await loadPeerJS();
            peer = new window.Peer({ debug: 0 });

            peer.on('open', () => {
                const c = peer.connect(code, { reliable: true });
                playerNumber = 2;
                mode = 'online';
                setupConnection(c);
                const beginGuest = () => {
                    showGame();
                    const ctrl = document.getElementById('tron-controls');
                    if (ctrl) ctrl.textContent = 'YOU ARE ORANGE  |  WASD or ARROWS';
                    game = TronGame.new(GRID_W, GRID_H);
                    setupInput();
                    animFrameId = requestAnimationFrame(render);
                    send({ type: 'ready' });
                };
                if (c.open) beginGuest();
                else c.on('open', beginGuest);
                c.on('error', () => setStatus('Failed to connect'));
            });

            peer.on('error', (err) => {
                setStatus('Error: ' + err.message);
            });
        } catch (e) {
            setStatus('Failed to load networking library');
        }
    }, { signal });

    // Enter key on room input triggers join
    document.getElementById('room-input')?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            document.getElementById('btn-join')?.click();
        }
    }, { signal });
}

// === Standalone mode ===
if (!window.HAS_SPA_ROUTER) {
    run().catch(console.error);
}
