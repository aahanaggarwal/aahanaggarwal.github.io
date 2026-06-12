import init, { PongGame } from './pkg/pong.js';

// Event bits (mirror Rust)
const EVT_PADDLE_LEFT = 1;
const EVT_PADDLE_RIGHT = 2;
const EVT_WALL = 4;
const EVT_SCORE = 8;
const EVT_DEATH = 16;
const EVT_NEAR_MISS = 32;
const EVT_NEW_MOD = 64;
const EVT_SHIELD_SAVE = 128;
const EVT_TELEPORT = 256;
const EVT_BALL_LOST = 512;

const MOD_BLACKOUT = 1024;
const MOD_PHANTOM = 8;

const MOD_INFO = {
    1: ['SPLIT', 'TWO BALLS. EACH ONE IS A LIFE.'],
    2: ['SHRINK', 'YOUR PADDLE CONTRACTS.'],
    4: ['GRAVITY', 'THE BALL FALLS.'],
    8: ['PHANTOM', 'NOW YOU SEE IT.'],
    16: ['TURBO', 'EVERYTHING FASTER.'],
    32: ['MIRROR', 'UP IS DOWN.'],
    64: ['WRAP', 'NO WALLS. NO MERCY.'],
    128: ['DRUNK', 'THE BALL HAD A FEW.'],
    256: ['SNIPER', 'THE AI STOPS MISSING.'],
    512: ['JUGGERNAUT', 'THE AI GROWS.'],
    1024: ['BLACKOUT', 'LIGHTS OUT.'],
    2048: ['CURVE', 'EVERY RETURN BENDS.'],
    4096: ['TELEPORT', 'THE BALL CHEATS.'],
    8192: ['SHIELD', 'ONE FREE SAVE. USE IT WELL.'],
    16384: ['GIANT', 'YOUR PADDLE GROWS.'],
};

let animFrameId = null;
let game = null;
let pauseOverlay = null;
let handleKeyDown = null;
let handleKeyUp = null;
let handleVisibilityChange = null;
let canvas = null;
let handleTouch = null;
let stopTouch = null;
let audioCtx = null;
let unlockAudio = null;

export function cleanup() {
    if (animFrameId) {
        cancelAnimationFrame(animFrameId);
        animFrameId = null;
    }
    if (handleKeyDown) window.removeEventListener('keydown', handleKeyDown);
    if (handleKeyUp) window.removeEventListener('keyup', handleKeyUp);
    if (handleVisibilityChange) document.removeEventListener('visibilitychange', handleVisibilityChange);
    if (unlockAudio) {
        window.removeEventListener('keydown', unlockAudio);
        window.removeEventListener('mousedown', unlockAudio);
        window.removeEventListener('touchstart', unlockAudio);
    }
    if (canvas) {
        if (handleTouch) {
            canvas.removeEventListener('touchstart', handleTouch);
            canvas.removeEventListener('touchmove', handleTouch);
        }
        if (stopTouch) canvas.removeEventListener('touchend', stopTouch);
    }
    if (pauseOverlay) {
        pauseOverlay.remove();
        pauseOverlay = null;
    }
    if (audioCtx) {
        audioCtx.close().catch(() => {});
        audioCtx = null;
    }
    if (game) {
        game.free();
        game = null;
    }
    handleKeyDown = null;
    handleKeyUp = null;
    handleVisibilityChange = null;
    handleTouch = null;
    stopTouch = null;
    unlockAudio = null;
    canvas = null;
}

// === Procedural audio ===
function ensureAudio() {
    if (!audioCtx) {
        try {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        } catch (e) {
            audioCtx = null;
        }
    }
    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
}

function blip(freq, dur = 0.06, type = 'square', gain = 0.08) {
    if (!audioCtx || audioCtx.state !== 'running') return;
    const t = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.connect(g).connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + dur);
}

function noiseBurst(dur = 0.35, gain = 0.18) {
    if (!audioCtx || audioCtx.state !== 'running') return;
    const t = audioCtx.currentTime;
    const len = Math.floor(audioCtx.sampleRate * dur);
    const buf = audioCtx.createBuffer(1, len, audioCtx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) {
        data[i] = (Math.random() * 2 - 1) * (1 - i / len);
    }
    const src = audioCtx.createBufferSource();
    src.buffer = buf;
    const g = audioCtx.createGain();
    g.gain.setValueAtTime(gain, t);
    const filter = audioCtx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(900, t);
    src.connect(filter).connect(g).connect(audioCtx.destination);
    src.start(t);
}

function powerupArpeggio() {
    [440, 554, 659, 880].forEach((f, i) => {
        setTimeout(() => blip(f, 0.09, 'sawtooth', 0.06), i * 70);
    });
}

export async function run() {
    cleanup();
    await init();

    canvas = document.getElementById('pong-canvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = 800;
    const height = 600;

    canvas.width = width;
    canvas.height = height;
    game = PongGame.new(width, height);
    const streakEl = document.getElementById('streak');
    const highScoreEl = document.getElementById('high-score');

    let highScore = parseInt(localStorage.getItem('pong_high_score') || '0');
    if (highScoreEl) highScoreEl.innerText = highScore;

    let isPaused = false;
    const speedIndicator = document.getElementById('speed-indicator');
    const speedValue = document.getElementById('speed-value');

    const pongContainer = document.getElementById('pong-container');
    pauseOverlay = document.querySelector('.paused-overlay');
    if (!pauseOverlay) {
        pauseOverlay = document.createElement('div');
        pauseOverlay.className = 'paused-overlay';
        pauseOverlay.innerText = '⏸';
        (pongContainer || document.body).appendChild(pauseOverlay);
    }

    // modifier banner + active list
    let modBanner = document.getElementById('mod-banner');
    if (!modBanner && pongContainer) {
        modBanner = document.createElement('div');
        modBanner.id = 'mod-banner';
        pongContainer.appendChild(modBanner);
    }
    let modList = document.getElementById('mod-list');
    if (!modList && pongContainer) {
        modList = document.createElement('div');
        modList.id = 'mod-list';
        pongContainer.appendChild(modList);
    }

    // audio unlocks on first interaction (autoplay policy)
    unlockAudio = () => ensureAudio();
    window.addEventListener('keydown', unlockAudio);
    window.addEventListener('mousedown', unlockAudio);
    window.addEventListener('touchstart', unlockAudio);

    const togglePause = () => {
        isPaused = !isPaused;
        if (pauseOverlay) pauseOverlay.classList.toggle('visible', isPaused);
    };

    handleKeyDown = (e) => {
        if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
            e.preventDefault();
            game.set_player_movement(-1);
        } else if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
            e.preventDefault();
            game.set_player_movement(1);
        } else if (e.key === ' ') {
            e.preventDefault();
            if (!e.repeat) togglePause();
        }
    };

    handleKeyUp = (e) => {
        if (['w', 'W', 'ArrowUp', 's', 'S', 'ArrowDown'].includes(e.key)) {
            game.set_player_movement(0);
        }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    handleVisibilityChange = () => {
        if (document.hidden && !isPaused) togglePause();
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);

    handleTouch = (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const relativeY = touch.clientY - rect.top;
        game.set_player_movement(relativeY < rect.height / 2 ? -1 : 1);
    };

    stopTouch = (e) => {
        e.preventDefault();
        game.set_player_movement(0);
    };

    canvas.addEventListener('touchstart', handleTouch, { passive: false });
    canvas.addEventListener('touchmove', handleTouch, { passive: false });
    canvas.addEventListener('touchend', stopTouch, { passive: false });

    const textColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--primary-color').trim() || '#33ff00';

    // === Juice state ===
    const particles = [];
    const trails = []; // per ball: array of {x, y}
    let timeScale = 1;
    let timeScaleTarget = 1;
    let slowmoRelease = 0;
    let flashAlpha = 0;
    let lastTime = 0;
    let prevBallCount = 1;
    let blackoutCanvas = null;
    let blackoutCtx = null;

    function spawnBurst(x, y, color, n, power) {
        for (let i = 0; i < n; i++) {
            const a = Math.random() * Math.PI * 2;
            const v = (0.5 + Math.random()) * power;
            particles.push({
                x, y,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v,
                life: 1,
                color,
            });
        }
    }

    function slowmo(factor, durationMs, timestamp) {
        timeScaleTarget = factor;
        slowmoRelease = timestamp + durationMs;
    }

    function shake() {
        if (pongContainer) {
            pongContainer.classList.remove('shake');
            void pongContainer.offsetWidth;
            pongContainer.classList.add('shake');
        }
    }

    function showBanner(title, subtitle) {
        if (!modBanner) return;
        modBanner.innerHTML = '';
        const t = document.createElement('div');
        t.textContent = title;
        modBanner.appendChild(t);
        if (subtitle) {
            const s = document.createElement('div');
            s.className = 'mod-banner-sub';
            s.textContent = subtitle;
            modBanner.appendChild(s);
        }
        modBanner.classList.remove('show');
        void modBanner.offsetWidth;
        modBanner.classList.add('show');
    }

    function updateModList() {
        if (!modList) return;
        const mods = game.active_mods();
        const names = Object.entries(MOD_INFO)
            .filter(([bit]) => mods & bit)
            .map(([, [name]]) => name);
        modList.textContent = names.length ? 'ACTIVE PROTOCOL: ' + names.join(' + ') : '';
    }

    function render(timestamp) {
        if (!document.body.contains(canvas)) {
            cleanup();
            return;
        }

        animFrameId = requestAnimationFrame(render);

        if (isPaused) {
            lastTime = 0;
            return;
        }

        if (!lastTime) lastTime = timestamp;
        const elapsed = timestamp - lastTime;
        lastTime = timestamp;

        // slow-mo easing
        if (timestamp > slowmoRelease) timeScaleTarget = 1;
        timeScale += (timeScaleTarget - timeScale) * 0.12;

        const targetFrameMs = 1000 / 60;
        const dt = Math.min(elapsed / targetFrameMs, 3) * timeScale;
        const events = game.tick_with_dt(dt);

        const balls = game.balls_data();
        const ballCount = balls.length / 3;
        const playerH = game.player_paddle_height();
        const aiH = game.ai_paddle_height();
        const leftY = game.paddle_left_y();
        const rightY = game.paddle_right_y();
        const mods = game.active_mods();
        const phantom = (mods & MOD_PHANTOM) !== 0;

        // --- event-driven juice ---
        if (events & EVT_PADDLE_LEFT) {
            blip(220 + game.streak() * 18, 0.06, 'square', 0.09);
            spawnBurst(14, balls[1] + 5, textColor, 10, 4);
        }
        if (events & EVT_PADDLE_RIGHT) {
            blip(180, 0.05, 'square', 0.05);
            spawnBurst(width - 14, balls[1] + 5, '#ff4444', 8, 3);
        }
        if (events & EVT_WALL) {
            blip(140, 0.03, 'triangle', 0.04);
        }
        if (events & EVT_SCORE) {
            blip(660, 0.1, 'sawtooth', 0.07);
            shake();
        }
        if (events & EVT_NEAR_MISS) {
            slowmo(0.35, 450, timestamp);
            blip(90, 0.2, 'sine', 0.1);
        }
        if (events & EVT_NEW_MOD) {
            const [name, desc] = MOD_INFO[game.last_new_mod()] || ['???', ''];
            showBanner('PROTOCOL: ' + name, desc);
            powerupArpeggio();
            slowmo(0.45, 700, timestamp);
            updateModList();
        }
        if (events & EVT_SHIELD_SAVE) {
            showBanner('SHIELD SPENT', '');
            blip(880, 0.15, 'sine', 0.12);
            spawnBurst(6, balls[1] + 5, '#44ffff', 25, 6);
            shake();
        }
        if (events & EVT_TELEPORT) {
            blip(1200, 0.04, 'sine', 0.05);
        }
        if (events & EVT_BALL_LOST) {
            showBanner('BALL DOWN', 'ONE LEFT.');
            noiseBurst(0.2, 0.1);
            shake();
            slowmo(0.4, 500, timestamp);
        }
        if (events & EVT_DEATH) {
            noiseBurst();
            shake();
            slowmo(0.2, 800, timestamp);
            flashAlpha = 0.5;
            spawnBurst(20, height / 2, '#ff3333', 40, 7);
            updateModList();
        }

        // --- draw ---
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = textColor;
        ctx.shadowBlur = 10;
        ctx.shadowColor = textColor;

        ctx.fillRect(0, leftY, 10, playerH);
        ctx.fillRect(width - 10, rightY, 10, aiH);

        // shield: glowing safety line behind the player
        if (game.shield_charges() > 0) {
            ctx.shadowColor = '#44ffff';
            ctx.shadowBlur = 14;
            ctx.fillStyle = '#44ffff';
            ctx.globalAlpha = 0.5 + Math.sin(timestamp / 200) * 0.2;
            ctx.fillRect(1, 0, 3, height);
            ctx.globalAlpha = 1;
            ctx.fillStyle = textColor;
            ctx.shadowColor = textColor;
        }

        // trails
        if (ballCount !== prevBallCount) {
            trails.length = 0;
            prevBallCount = ballCount;
        }
        while (trails.length < ballCount) trails.push([]);

        ctx.shadowBlur = 0;
        for (let b = 0; b < ballCount; b++) {
            const bx = balls[b * 3];
            const by = balls[b * 3 + 1];
            const trail = trails[b];
            trail.push({ x: bx, y: by });
            if (trail.length > 14) trail.shift();
            for (let i = 0; i < trail.length; i++) {
                const f = i / trail.length;
                ctx.globalAlpha = f * 0.35;
                const s = 4 + f * 6;
                ctx.fillRect(trail[i].x + 5 - s / 2, trail[i].y + 5 - s / 2, s, s);
            }
        }
        ctx.globalAlpha = 1;

        // balls
        ctx.shadowBlur = 12;
        ctx.shadowColor = textColor;
        for (let b = 0; b < ballCount; b++) {
            const bx = balls[b * 3];
            const by = balls[b * 3 + 1];
            const phase = balls[b * 3 + 2];
            if (phantom) {
                // blink: solid half the cycle, ghost-faint the other half
                ctx.globalAlpha = Math.sin(phase) > 0 ? 1 : 0.12;
            }
            ctx.fillRect(bx, by, 10, 10);
            ctx.globalAlpha = 1;
        }
        ctx.shadowBlur = 0;

        // particles
        for (let i = particles.length - 1; i >= 0; i--) {
            const p = particles[i];
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.vx *= 0.92;
            p.vy *= 0.92;
            p.life -= 0.03 * dt;
            if (p.life <= 0) {
                particles.splice(i, 1);
                continue;
            }
            ctx.globalAlpha = p.life;
            ctx.fillStyle = p.color;
            ctx.fillRect(p.x, p.y, 3, 3);
        }
        ctx.globalAlpha = 1;

        // BLACKOUT: darkness everywhere except a light around each ball
        // (and a faint glow at your paddle so you're not totally lost)
        if (mods & MOD_BLACKOUT) {
            if (!blackoutCanvas) {
                blackoutCanvas = document.createElement('canvas');
                blackoutCanvas.width = width;
                blackoutCanvas.height = height;
                blackoutCtx = blackoutCanvas.getContext('2d');
            }
            const b = blackoutCtx;
            b.globalCompositeOperation = 'source-over';
            b.clearRect(0, 0, width, height);
            b.fillStyle = 'rgba(0, 0, 0, 0.93)';
            b.fillRect(0, 0, width, height);
            b.globalCompositeOperation = 'destination-out';
            const punch = (x, y, r) => {
                const g = b.createRadialGradient(x, y, 0, x, y, r);
                g.addColorStop(0, 'rgba(0,0,0,1)');
                g.addColorStop(1, 'rgba(0,0,0,0)');
                b.fillStyle = g;
                b.beginPath();
                b.arc(x, y, r, 0, Math.PI * 2);
                b.fill();
            };
            for (let bb = 0; bb < ballCount; bb++) {
                punch(balls[bb * 3] + 5, balls[bb * 3 + 1] + 5, 130);
            }
            punch(5, leftY + playerH / 2, 70);
            ctx.drawImage(blackoutCanvas, 0, 0);
        }

        // death flash
        if (flashAlpha > 0.01) {
            ctx.fillStyle = `rgba(255, 40, 40, ${flashAlpha})`;
            ctx.fillRect(0, 0, width, height);
            flashAlpha *= 0.88;
        }

        // --- HUD ---
        const currentStreak = game.streak();
        if (streakEl) streakEl.innerText = currentStreak;

        if (currentStreak > highScore) {
            highScore = currentStreak;
            if (highScoreEl) highScoreEl.innerText = highScore;
            localStorage.setItem('pong_high_score', highScore);
        }

        if (speedIndicator && speedValue) {
            const speed = game.get_ball_speed();
            speedIndicator.style.display = 'block';
            speedValue.innerText = (speed / 8.0).toFixed(1);
        }
    }

    animFrameId = requestAnimationFrame(render);
}

if (!window.HAS_SPA_ROUTER) {
    run().catch(console.error);
}
