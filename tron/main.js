import wasmInit, { TronGame } from './pkg/tron.js';

const RELAY_URL = 'wss://tron-rooms.aahan-aggarwal99.workers.dev';
const COLORS = ['#00ffff', '#ff6600'];
let game, memory, canvas, ctx, abortController, ws;
let animFrameId = null, countdownTimer = null, heartbeatTimer = null, connectionTimer = null;
let mode = null, playerNumber = 0, gameActive = false, lastTickTime = 0;
let scores = [0, 0], onlineState = null, generation = 0;

function setStatus(text) { document.getElementById('tron-status').textContent = text; }
function overlay(text = '') {
    const el = document.getElementById('tron-overlay');
    const [title, hint] = text.split('\n');
    el.textContent = title;
    if (hint) {
        const sub = document.createElement('div');
        sub.style.cssText = 'font-size:0.3em;margin-top:0.5em';
        sub.textContent = hint;
        el.appendChild(sub);
    }
    el.classList.toggle('visible', Boolean(text));
}
function updateScores() {
    document.getElementById('p1-score').textContent = `P1: ${scores[0]}`;
    document.getElementById('p2-score').textContent = `P2: ${scores[1]}`;
}
function busy(value) {
    for (const id of ['btn-create', 'btn-join', 'btn-local']) document.getElementById(id).disabled = value;
}
function showGame() {
    if (document.activeElement instanceof HTMLInputElement) document.activeElement.blur();
    document.getElementById('tron-lobby').style.display = 'none';
    document.getElementById('tron-game').style.display = 'flex';
    document.getElementById('btn-leave').hidden = false;
    document.getElementById('tron-controls').textContent = mode === 'local'
        ? 'P1: WASD  |  P2: ARROWS  |  SPACE: rematch'
        : `YOU ARE ${playerNumber === 1 ? 'CYAN' : 'ORANGE'}  |  WASD or ARROWS  |  SPACE: rematch`;
    if (!animFrameId) animFrameId = requestAnimationFrame(render);
}
function stopTimers() {
    clearInterval(countdownTimer); countdownTimer = null;
    clearInterval(heartbeatTimer); heartbeatTimer = null;
    clearTimeout(connectionTimer); connectionTimer = null;
}
function disconnect() {
    stopTimers();
    const previous = ws;
    ws = null;
    if (previous) previous.close();
}
function lobby(message = '') {
    disconnect();
    mode = null; gameActive = false; onlineState = null;
    scores = [0, 0]; updateScores();
    document.getElementById('tron-lobby').style.display = '';
    document.getElementById('tron-game').style.display = 'none';
    document.getElementById('btn-leave').hidden = true;
    overlay(); busy(false); setStatus(message);
}
function send(message) {
    if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(message));
}
function localRound() {
    clearInterval(countdownTimer);
    game.reset(); gameActive = false; lastTickTime = 0;
    let count = 3;
    overlay(String(count));
    countdownTimer = setInterval(() => {
        count--;
        if (count >= 0) overlay(count ? String(count) : 'GO!');
        else {
            clearInterval(countdownTimer); countdownTimer = null;
            overlay(); gameActive = true; lastTickTime = performance.now();
        }
    }, 800);
}
function winnerText(winner) { return `${winner ? `P${winner} WINS` : 'DRAW'}\nSPACE to rematch`; }

function connectRoom(code, role) {
    disconnect();
    busy(true); setStatus('Connecting...');
    const socket = new WebSocket(`${RELAY_URL}/room/${code}?role=${role}&v=2`);
    ws = socket;
    connectionTimer = setTimeout(() => { if (ws === socket) lobby('Connection timed out. Try again.'); }, 10000);
    socket.addEventListener('open', () => {
        if (ws !== socket) return;
        heartbeatTimer = setInterval(() => {
            if (socket.readyState === WebSocket.OPEN) socket.send('ping');
        }, 30000);
    });
    socket.addEventListener('message', e => {
        if (ws !== socket || e.data === 'pong') return;
        let msg;
        try { msg = JSON.parse(e.data); } catch { return; }
        if (msg.type === 'error' || msg.type === 'ended') return lobby(msg.message);
        if (msg.type === 'welcome') {
            clearTimeout(connectionTimer); connectionTimer = null;
            mode = 'online'; playerNumber = msg.player;
            document.getElementById('btn-leave').hidden = false;
            setStatus(`ROOM: ${code} — Waiting for opponent...`);
        }
        if (msg.type === 'state') {
            if (onlineState && msg.round < onlineState.round) return;
            const newRound = !onlineState || msg.round !== onlineState.round;
            if (newRound && !msg.grid) return;
            const grid = msg.grid ? Uint8Array.from(msg.grid) : onlineState.grid;
            for (const [index, value] of msg.trail) grid[index] = value;
            onlineState = { ...msg, grid, startLocal: performance.now() + Math.max(0, msg.startAt - msg.serverNow) };
            scores = msg.scores; updateScores();
            gameActive = msg.phase === 'playing';
            document.getElementById('tron-round').textContent = `ROUND ${msg.round}`;
            showGame();
            if (msg.phase === 'over') overlay(winnerText(msg.winner));
            else if (msg.phase !== 'countdown') overlay();
        }
    });
    socket.addEventListener('close', () => { if (ws === socket) lobby('Connection lost. Create or join a new room.'); });
    socket.addEventListener('error', () => { if (ws === socket) lobby('Could not connect to the game server. Try again.'); });
}
function handleKeyDown(e) {
    if (e.target instanceof HTMLInputElement) return;
    if (e.key === ' ' || e.key === 'Spacebar') {
        if (!mode) return;
        e.preventDefault();
        if (e.repeat) return;
        if (mode === 'online' && onlineState?.phase === 'over') send({ type: 'rematch', round: onlineState.round });
        if (mode === 'local' && game.is_game_over()) localRound();
        return;
    }
    const dir = ({ w: 0, ArrowUp: 0, d: 1, ArrowRight: 1, s: 2, ArrowDown: 2, a: 3, ArrowLeft: 3 })[e.key.length === 1 ? e.key.toLowerCase() : e.key];
    if (dir === undefined || !gameActive) return;
    e.preventDefault();
    if (e.repeat) return;
    if (mode === 'online') send({ type: 'dir', dir, round: onlineState.round });
    else game.set_direction(e.key.startsWith('Arrow') ? 1 : 0, dir);
}
function render(timestamp) {
    if (!canvas || !document.body.contains(canvas)) { cleanup(); return; }
    animFrameId = requestAnimationFrame(render);
    if (mode === 'local' && gameActive) {
        const tickMs = Math.max(40, 120 - Math.floor(game.tick_count() / 10) * 2);
        if (timestamp - lastTickTime >= tickMs) {
            game.tick(); lastTickTime = timestamp;
            if (game.is_game_over()) {
                gameActive = false;
                const winner = game.winner();
                if (winner) scores[winner - 1]++;
                updateScores(); overlay(winnerText(winner));
            }
        }
    }
    if (mode === 'online' && onlineState?.phase === 'countdown') {
        const remaining = onlineState.startLocal - timestamp;
        overlay(remaining > 800 ? String(Math.ceil((remaining - 800) / 800)) : 'GO!');
    }
    let cells, players;
    if (mode === 'online' && onlineState) {
        cells = onlineState.grid; players = onlineState.players;
    } else if (mode === 'local' && game) {
        cells = new Uint8Array(memory.buffer, game.grid_ptr(), 80 * 60);
        players = [{ x: game.p1_x(), y: game.p1_y(), alive: game.p1_alive() }, { x: game.p2_x(), y: game.p2_y(), alive: game.p2_alive() }];
    } else return;
    ctx.fillStyle = '#0a0a0a'; ctx.fillRect(0, 0, 800, 600);
    ctx.strokeStyle = 'rgba(0, 255, 65, 0.04)'; ctx.lineWidth = 0.5;
    for (let x = 0; x <= 800; x += 10) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 600); ctx.stroke(); }
    for (let y = 0; y <= 600; y += 10) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(800, y); ctx.stroke(); }
    ctx.shadowBlur = 0;
    for (let i = 0; i < cells.length; i++) {
        if (!cells[i]) continue;
        ctx.fillStyle = COLORS[cells[i] - 1];
        ctx.fillRect((i % 80) * 10 + 1, Math.floor(i / 80) * 10 + 1, 8, 8);
    }
    players.forEach((p, i) => {
        if (!p.alive) return;
        ctx.shadowColor = COLORS[i]; ctx.shadowBlur = 15; ctx.fillStyle = '#fff';
        ctx.fillRect(p.x * 10, p.y * 10, 10, 10);
    });
    ctx.shadowBlur = 0;
}
export function cleanup() {
    generation++;
    abortController?.abort(); abortController = null;
    if (animFrameId) cancelAnimationFrame(animFrameId);
    animFrameId = null;
    disconnect();
    game?.free(); game = null;
    canvas = null; ctx = null; memory = null;
    mode = null; onlineState = null; gameActive = false; playerNumber = 0; scores = [0, 0]; lastTickTime = 0;
}
export async function run() {
    cleanup();
    const currentGeneration = generation;
    const wasm = await wasmInit();
    if (generation !== currentGeneration) return;
    canvas = document.getElementById('tron-canvas');
    if (!canvas) return;
    ctx = canvas.getContext('2d'); memory = wasm.memory;
    game = TronGame.new(80, 60);
    abortController = new AbortController();
    const options = { signal: abortController.signal };
    window.addEventListener('keydown', handleKeyDown, options);
    document.getElementById('btn-local').addEventListener('click', () => {
        disconnect(); mode = 'local'; scores = [0, 0]; updateScores();
        document.getElementById('tron-round').textContent = '';
        showGame(); localRound();
    }, options);
    document.getElementById('btn-create').addEventListener('click', () => {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ';
        const bytes = crypto.getRandomValues(new Uint8Array(4));
        const code = Array.from(bytes, b => chars[b % chars.length]).join('');
        connectRoom(code, 'create');
    }, options);
    document.getElementById('btn-join').addEventListener('click', () => {
        const code = document.getElementById('room-input').value.toUpperCase().trim();
        if (!/^[A-Z]{4}$/.test(code)) return setStatus('Enter a 4-letter room code');
        connectRoom(code, 'join');
    }, options);
    document.getElementById('btn-leave').addEventListener('click', () => lobby(), options);
    lobby();
}
if (!window.HAS_SPA_ROUTER) run().catch(console.error);
