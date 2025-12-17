import init, { PongGame } from './pkg/pong.js';

export async function run() {
    await init();

    const canvas = document.getElementById('pong-canvas');
    const ctx = canvas.getContext('2d');
    const width = 800;
    const height = 600;

    canvas.width = width;
    canvas.height = height;

    // Initialize Game
    const game = PongGame.new(width, height);

    // UI Elements
    const scoreLeftEl = document.getElementById('score-left');
    const scoreRightEl = document.getElementById('score-right');
    const streakEl = document.getElementById('streak');
    const highScoreEl = document.getElementById('high-score');

    let highScore = parseInt(localStorage.getItem('pong_high_score') || '0');
    highScoreEl.innerText = highScore;

    // Game State
    let isPaused = false;
    const speedIndicator = document.getElementById('speed-indicator');
    const speedValue = document.getElementById('speed-value');

    // Pause Overlay
    let pauseOverlay = document.querySelector('.paused-overlay');
    if (!pauseOverlay) {
        pauseOverlay = document.createElement('div');
        pauseOverlay.className = 'paused-overlay';
        pauseOverlay.innerText = '⏸'; // Symbol
        document.body.appendChild(pauseOverlay); // Global append for overlay
    }

    // Cursor Logic
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

    // Input Handling
    const handleKeyDown = (e) => {
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

    const handleKeyUp = (e) => {
        if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
            game.set_player_movement(0);
        } else if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
            game.set_player_movement(0);
        }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    const togglePause = () => {
        isPaused = !isPaused;
        if (isPaused) {
            if (pauseOverlay) pauseOverlay.classList.add('visible');
        } else {
            if (pauseOverlay) pauseOverlay.classList.remove('visible');
        }
    };

    const handleVisibilityChange = () => {
        if (document.hidden) {
            if (!isPaused) togglePause();
        }
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);

    // Touch Handling (Mobile)
    const handleTouch = (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        const rect = canvas.getBoundingClientRect();
        const relativeY = touch.clientY - rect.top;

        // Simple logic: if touch is in top half, move up. Bottom half, move down.
        // Better logic: move paddle towards touch Y? 
        // Let's stick to the requested "playable on mobile" with simple controls first.
        // Actually, direct mapping is best for touch.

        // But game expects -1, 0, 1. 
        // Let's implement virtual buttons or just zones?
        // Zones: Top half = Up, Bottom half = Down.

        if (relativeY < rect.height / 2) {
            game.set_player_movement(-1);
        } else {
            game.set_player_movement(1);
        }
    };

    const stopTouch = (e) => {
        e.preventDefault();
        game.set_player_movement(0);
    };

    canvas.addEventListener('touchstart', handleTouch, { passive: false });
    canvas.addEventListener('touchmove', handleTouch, { passive: false });
    canvas.addEventListener('touchend', stopTouch);

    function render() {
        // Cleanup check
        if (!document.body.contains(canvas)) {
            // Clean up overlay
            if (pauseOverlay) pauseOverlay.remove();
            document.removeEventListener("visibilitychange", handleVisibilityChange);
            window.removeEventListener("keydown", handleKeyDown);
            window.removeEventListener("keyup", handleKeyUp);
            return; // Stop loop
        }

        if (isPaused) {
            requestAnimationFrame(render);
            return;
        }

        // Update Game State
        game.tick();

        // Clear Canvas
        ctx.clearRect(0, 0, width, height); // Transparent

        // Draw Elements
        // Green phosphor color, match site variable usually
        const computedStyle = getComputedStyle(document.documentElement);
        const textColor = computedStyle.getPropertyValue('--text-color').trim() || '#33ff00';
        ctx.fillStyle = textColor;

        // Glow Effect
        ctx.shadowBlur = 10;
        ctx.shadowColor = textColor;


        // Draw Paddles
        ctx.fillRect(10, game.paddle_left_y(), 10, 100);
        ctx.fillRect(width - 20, game.paddle_right_y(), 10, 100);

        // Draw Ball
        ctx.fillRect(game.ball_x(), game.ball_y(), 10, 10);

        // Reset Shadow for text or future frames if needed (optional, but good practice if mixed rendering)
        // ctx.shadowBlur = 0;

        // Update Score / Streak
        let currentStreak = game.streak();

        // Shake check
        if (streakEl.innerText != currentStreak) {
            // Score changed (up or reset)
            if (currentStreak > 0) {
                const container = document.getElementById('pong-container');
                if (container) {
                    container.classList.add('shake');
                    setTimeout(() => container.classList.remove('shake'), 300);
                }
            }
        }

        streakEl.innerText = currentStreak;

        // High Score logic
        if (currentStreak > highScore) {
            highScore = currentStreak;
            highScoreEl.innerText = highScore;
            localStorage.setItem('pong_high_score', highScore);
        }

        // Update Speed
        if (speedIndicator && speedValue) {
            const speed = game.get_ball_speed();
            // Normalize: start speed is 8.0, display as 1.0
            const normalizedSpeed = speed / 8.0;
            speedIndicator.style.display = 'block';
            speedValue.innerText = normalizedSpeed.toFixed(1);
        }

        requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
}

// run().catch(console.error);
// Allow external call or auto-run if standalone
if (!window.HAS_SPA_ROUTER) {
    run().catch(console.error);
}
