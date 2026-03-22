import wasmInit, { TronGame } from './pkg/tron.js';

// === Constants ===
const GRID_W = 80, GRID_H = 60, CELL_PX = 10;
const TICK_MS = 120;
const CHECKSUM_INTERVAL = 30;
const P1_COLOR = '#00ffff';
const P2_COLOR = '#ff6600';
const P1_HEAD = '#ffffff';
const P2_HEAD = '#ffffff';

// === Module state ===
let game = null, memory = null;
let canvas = null, ctx = null;
let animFrameId = null;
let abortController = null;
let mode = null; // 'local' | 'online'
let playerNumber = 0; // 1 for host, 2 for guest
let p1Score = 0, p2Score = 0;
let gameActive = false;
let countdownTimer = null;
let lastTickTime = 0;

let history = {};
let localInputs = {};
let remoteInputs = {};

let mqttClient = null;
let sharedTopic = null;

// === Helpers ===
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

function send(msg) {
    if (mqttClient && mqttClient.connected && sharedTopic) {
        msg.sender = playerNumber; // Inject the sender ID globally!
        try { mqttClient.publish(sharedTopic, JSON.stringify(msg), { qos: 0 }); } catch(e) {}
    }
}

// === Flow ===
function startCountdown(onDone) {
    if (countdownTimer) clearInterval(countdownTimer);
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

function newRound() {
    if (countdownTimer) clearInterval(countdownTimer);
    const overlay = document.getElementById('tron-overlay');
    overlay.classList.remove('visible');
    game.reset();
    
    history = {};
    localInputs = {};
    remoteInputs = {};
    gameActive = false;
    startCountdown(() => {
        gameActive = true;
        lastTickTime = performance.now();
    });
}

function requestRematch() {
    if (mode === 'online') send({ type: 'rematch' });
    newRound();
}

function initGameSession() {
    showGame();
    const ctrl = document.getElementById('tron-controls');
    if (mode === 'local') {
        if (ctrl) ctrl.textContent = 'P1: WASD  |  P2: ARROWS  |  SPACE: rematch';
    } else {
        if (ctrl) ctrl.textContent = (playerNumber === 1 ? 'YOU ARE CYAN' : 'YOU ARE ORANGE') + '  |  WASD or ARROWS';
    }
    
    if (!game) game = TronGame.new(GRID_W, GRID_H);
    else game.reset();
    
    if (!animFrameId) animFrameId = requestAnimationFrame(render);
}

function handleGameOver() {
    const w = game.winner();
    if (w === 1) p1Score++;
    else if (w === 2) p2Score++;
    updateScores();
    const overlay = document.getElementById('tron-overlay');
    overlay.innerHTML = (w===1 ? '<span class="tron-p1">P1 WINS</span>' : w===2 ? '<span class="tron-p2">P2 WINS</span>' : 'DRAW') + 
                        '<div style="font-size:0.3em;margin-top:0.5em">SPACE to rematch</div>';
    overlay.classList.add('visible');
}

function gameTick() {
    if (!gameActive || !game) return;
    
    const currentTick = game.tick_count();
    
    if (remoteInputs[currentTick] !== undefined) {
        const opponentIdx = playerNumber === 1 ? 1 : 0;
        game.set_direction(opponentIdx, remoteInputs[currentTick]);
    }
    
    // Save state BEFORE ticking
    history[currentTick] = new Uint8Array(game.serialize_state());
    
    game.tick();
    
    if (game.is_game_over()) {
        gameActive = false;
        handleGameOver();
        return;
    }
}

function render(timestamp) {
    if (!canvas || !document.body.contains(canvas)) { cleanup(); return; }
    animFrameId = requestAnimationFrame(render);
    
    if (gameActive && game) {
        if (!lastTickTime) lastTickTime = timestamp;
        if (timestamp - lastTickTime >= TICK_MS) {
            gameTick();
            lastTickTime = timestamp;
        }
    }

    if (!game || !memory) return;
    const gridPtr = game.grid_ptr();
    const cells = new Uint8Array(memory.buffer, gridPtr, GRID_W * GRID_H);

    ctx.fillStyle = '#0a0a0a';
    ctx.fillRect(0, 0, 800, 600);

    ctx.strokeStyle = 'rgba(0, 255, 65, 0.04)';
    ctx.lineWidth = 0.5;
    for (let x = 0; x <= 800; x += CELL_PX) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 600); ctx.stroke();
    }
    for (let y = 0; y <= 600; y += CELL_PX) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(800, y); ctx.stroke();
    }

    ctx.shadowBlur = 0;
    for (let i = 0; i < cells.length; i++) {
        if (cells[i] === 0) continue;
        const x = (i % GRID_W) * CELL_PX, y = Math.floor(i / GRID_W) * CELL_PX;
        ctx.fillStyle = cells[i] === 1 ? P1_COLOR : P2_COLOR;
        ctx.fillRect(x + 1, y + 1, CELL_PX - 2, CELL_PX - 2);
    }

    if (game.p1_alive()) {
        ctx.shadowColor = P1_COLOR; ctx.shadowBlur = 15;
        ctx.fillStyle = P1_HEAD; ctx.fillRect(game.p1_x() * CELL_PX, game.p1_y() * CELL_PX, CELL_PX, CELL_PX);
    }
    if (game.p2_alive()) {
        ctx.shadowColor = P2_COLOR; ctx.shadowBlur = 15;
        ctx.fillStyle = P2_HEAD; ctx.fillRect(game.p2_x() * CELL_PX, game.p2_y() * CELL_PX, CELL_PX, CELL_PX);
    }
    ctx.shadowBlur = 0;
}

// === Networking (MQTT SINGLE-TOPIC) ===
function loadMQTT() {
    return new Promise(resolve => {
        if (window.mqtt) return resolve();
        const s = document.createElement('script');
        s.src = 'https://unpkg.com/mqtt@5.10.1/dist/mqtt.min.js';
        s.onload = resolve;
        document.head.appendChild(s);
    });
}

function handleMessage(msg) {
    if (!msg || !msg.type) return;
    
    // IMPORTANT: Ignore our own messages reflected by the broker!
    if (msg.sender === playerNumber) return;

    switch (msg.type) {
        case 'ready':
            if (playerNumber === 1) {
                initGameSession();
                send({ type: 'start' });
                startCountdown(() => { gameActive = true; lastTickTime = performance.now(); });
            }
            break;
        case 'start':
            if (playerNumber === 2) {
                startCountdown(() => { gameActive = true; lastTickTime = performance.now(); });
            }
            break;
        case 'dir':
            if (!gameActive || !game) return;
            const currentTick = game.tick_count();
            remoteInputs[msg.tick] = msg.dir;

            if (msg.tick < currentTick) {
                const rTick = msg.tick;
                if (!history[rTick]) break;

                // Restoring exact past reality
                game.load_state(history[rTick]);
                
                // Fast forward simulation back to present
                for (let t = rTick; t < currentTick; t++) {
                    if (localInputs[t] !== undefined) {
                        game.set_direction(playerNumber - 1, localInputs[t]);
                    }
                    if (remoteInputs[t] !== undefined) {
                        game.set_direction(playerNumber === 1 ? 1 : 0, remoteInputs[t]);
                    }
                    game.tick();
                    history[t + 1] = new Uint8Array(game.serialize_state());
                }
            }
            break;
        case 'rematch':
            newRound();
            break;
    }
}

// === Global Input Listener ===
function keyToDir(k) {
    switch (k) {
        case 'w': case 'W': case 'ArrowUp': return 0;
        case 'd': case 'D': case 'ArrowRight': return 1;
        case 's': case 'S': case 'ArrowDown': return 2;
        case 'a': case 'A': case 'ArrowLeft': return 3;
        default: return null;
    }
}

function handleKeyDown(e) {
    if (e.key === ' ' || e.key === 'Spacebar') {
        e.preventDefault();
        if (!gameActive && game && game.is_game_over()) requestRematch();
        return;
    }
    const dir = keyToDir(e.key);
    if (dir === null || !game || !gameActive) return;
    
    e.preventDefault();
    if (mode === 'local') {
        game.set_direction(e.key.startsWith('Arrow') ? 1 : 0, dir);
    } else if (mode === 'online') {
        const tick = game.tick_count();
        localInputs[tick] = dir;
        game.set_direction(playerNumber - 1, dir);
        send({ type: 'dir', dir: dir, tick: tick });
    }
}

export function cleanup() {
    if (abortController) { abortController.abort(); abortController = null; }
    if (animFrameId) { cancelAnimationFrame(animFrameId); animFrameId = null; }
    if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }
    if (mqttClient) { mqttClient.end(); mqttClient = null; }
    if (game) { game.free(); game = null; }
    window.removeEventListener('keydown', handleKeyDown);
    
    lastTickTime = 0;
    history = {};
    localInputs = {};
    remoteInputs = {};
    
    canvas = null; ctx = null; memory = null;
    mode = null; playerNumber = 0; p1Score = 0; p2Score = 0;
    gameActive = false; sharedTopic = null;
}

export async function run() {
    cleanup();
    const wasm = await wasmInit();
    memory = wasm.memory;
    
    canvas = document.getElementById('tron-canvas');
    if (!canvas) return;
    ctx = canvas.getContext('2d');
    
    abortController = new AbortController();
    window.addEventListener('keydown', handleKeyDown, { signal: abortController.signal });

    document.getElementById('tron-lobby').style.display = '';
    document.getElementById('tron-game').style.display = 'none';

    document.getElementById('btn-local')?.addEventListener('click', () => {
        mode = 'local';
        initGameSession();
        startCountdown(() => { gameActive = true; lastTickTime = performance.now(); });
    }, { signal: abortController.signal });

    document.getElementById('btn-create')?.addEventListener('click', async () => {
        try {
            setStatus('Loading...');
            await loadMQTT();
            const code = generateCode();
            setStatus('Connecting to remote server...');
            
            if (mqttClient) mqttClient.end();
            mqttClient = window.mqtt.connect('wss://broker.emqx.io:8084/mqtt');
            
            mqttClient.on('connect', () => {
                playerNumber = 1;
                mode = 'online';
                sharedTopic = `aahan-tron-${code}`;
                mqttClient.subscribe(sharedTopic, (err) => {
                    if (err) return setStatus('Error subscribing to room');
                    setStatus(`ROOM: ${code} — Waiting for opponent...`);
                });
            });
            
            mqttClient.on('message', (t, p) => {
                if (t === sharedTopic) {
                    try { handleMessage(JSON.parse(p.toString())); } catch(e){}
                }
            });
            
            mqttClient.on('error', (err) => setStatus('Connection error: ' + err.message));
        } catch (e) { setStatus('Failed to load networking: ' + e.message); }
    }, { signal: abortController.signal });

    document.getElementById('btn-join')?.addEventListener('click', async () => {
        const code = document.getElementById('room-input')?.value?.toUpperCase()?.trim();
        if (!code || code.length < 4) return setStatus('Enter a 4-letter room code');
        
        try {
            setStatus('Connecting...');
            await loadMQTT();
            
            if (mqttClient) mqttClient.end();
            mqttClient = window.mqtt.connect('wss://broker.emqx.io:8084/mqtt');
            
            mqttClient.on('connect', () => {
                playerNumber = 2;
                mode = 'online';
                sharedTopic = `aahan-tron-${code}`;
                mqttClient.subscribe(sharedTopic, (err) => {
                    if (err) return setStatus('Failed to join room');
                    initGameSession();
                    send({ type: 'ready' });
                });
            });
            
            mqttClient.on('message', (t, p) => {
                if (t === sharedTopic) {
                    try { handleMessage(JSON.parse(p.toString())); } catch(e){}
                }
            });
            
            mqttClient.on('error', (err) => setStatus('Connection error: ' + err.message));
        } catch (e) { setStatus('Failed to load networking: ' + e.message); }
    }, { signal: abortController.signal });
}

if (!window.HAS_SPA_ROUTER) run().catch(console.error);
