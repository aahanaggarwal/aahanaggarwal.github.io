import init, { PongGame } from './pkg/pong.js';

let animFrameId = null;
let game = null;
let pauseOverlay = null;
let handleKeyDown = null;
let handleKeyUp = null;
let handleVisibilityChange = null;
let handleMouseMove = null;
let handleClick = null;
let canvas = null;
let handleTouch = null;
let stopTouch = null;

export function cleanup() {
    if (animFrameId) {
        cancelAnimationFrame(animFrameId);
        animFrameId = null;
    }
    if (handleKeyDown) window.removeEventListener('keydown', handleKeyDown);
    if (handleKeyUp) window.removeEventListener('keyup', handleKeyUp);
    if (handleVisibilityChange) document.removeEventListener('visibilitychange', handleVisibilityChange);
    if (handleMouseMove) document.removeEventListener('mousemove', handleMouseMove);
    if (handleClick) document.removeEventListener('click', handleClick);
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
    if (game) {
        game.free();
        game = null;
    }
    handleKeyDown = null;
    handleKeyUp = null;
    handleVisibilityChange = null;
    handleMouseMove = null;
    handleClick = null;
    handleTouch = null;
    stopTouch = null;
    canvas = null;
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

    const cursor = document.getElementById("cursor");
    if (!window.HAS_SPA_ROUTER) {
        handleMouseMove = (e) => {
            if (cursor) {
                cursor.style.transform = `translate3d(${e.clientX}px, ${e.clientY}px, 0)`;
            }
        };
        handleClick = () => {
            if (cursor) {
                cursor.classList.add("expand");
                setTimeout(() => cursor.classList.remove("expand"), 200);
            }
        };
        document.addEventListener("mousemove", handleMouseMove);
        document.addEventListener("click", handleClick);
    }

    const togglePause = () => {
        isPaused = !isPaused;
        if (isPaused) {
            if (pauseOverlay) pauseOverlay.classList.add('visible');
        } else {
            if (pauseOverlay) pauseOverlay.classList.remove('visible');
        }
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
        if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
            game.set_player_movement(0);
        } else if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
            game.set_player_movement(0);
        }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    handleVisibilityChange = () => {
        if (document.hidden) {
            if (!isPaused) togglePause();
        }
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);

    handleTouch = (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const relativeY = touch.clientY - rect.top;
        if (relativeY < rect.height / 2) {
            game.set_player_movement(-1);
        } else {
            game.set_player_movement(1);
        }
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

    let lastTime = 0;

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

        const targetFrameMs = 1000 / 60;
        const dt = Math.min(elapsed / targetFrameMs, 3);
        game.tick_with_dt(dt);

        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = textColor;

        ctx.shadowBlur = 10;
        ctx.shadowColor = textColor;

        ctx.fillRect(10, game.paddle_left_y(), 10, 100);
        ctx.fillRect(width - 20, game.paddle_right_y(), 10, 100);

        ctx.fillRect(game.ball_x(), game.ball_y(), 10, 10);
        let currentStreak = game.streak();

        if (streakEl && streakEl.innerText !== currentStreak.toString()) {
            if (pongContainer) {
                pongContainer.classList.remove('shake');
                void pongContainer.offsetWidth;
                pongContainer.classList.add('shake');
            }
        }

        if (streakEl) streakEl.innerText = currentStreak;

        if (currentStreak > highScore) {
            highScore = currentStreak;
            if (highScoreEl) highScoreEl.innerText = highScore;
            localStorage.setItem('pong_high_score', highScore);
        }

        if (speedIndicator && speedValue) {
            const speed = game.get_ball_speed();
            const normalizedSpeed = speed / 8.0;
            speedIndicator.style.display = 'block';
            speedValue.innerText = normalizedSpeed.toFixed(1);
        }
    }

    animFrameId = requestAnimationFrame(render);
}

if (!window.HAS_SPA_ROUTER) {
    run().catch(console.error);
}
