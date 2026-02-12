import init, { PongGame } from './pkg/pong.js';

export async function run() {
    await init();

    const canvas = document.getElementById('pong-canvas');
    const ctx = canvas.getContext('2d');
    const width = 800;
    const height = 600;

    canvas.width = width;
    canvas.height = height;
    const game = PongGame.new(width, height);
    const scoreLeftEl = document.getElementById('score-left');
    const scoreRightEl = document.getElementById('score-right');
    const streakEl = document.getElementById('streak');
    const highScoreEl = document.getElementById('high-score');

    let highScore = parseInt(localStorage.getItem('pong_high_score') || '0');
    highScoreEl.innerText = highScore;

    let isPaused = false;
    const speedIndicator = document.getElementById('speed-indicator');
    const speedValue = document.getElementById('speed-value');
    let pauseOverlay = document.querySelector('.paused-overlay');
    if (!pauseOverlay) {
        pauseOverlay = document.createElement('div');
        pauseOverlay.className = 'paused-overlay';
        pauseOverlay.innerText = '⏸';
        document.body.appendChild(pauseOverlay);
    }

    const cursor = document.getElementById("cursor");
    const handleMouseMove = (e) => {
        if (cursor) {
            cursor.style.transform = `translate3d(${e.clientX}px, ${e.clientY}px, 0)`;
        }
    };
    const handleClick = () => {
        if (cursor) {
            cursor.classList.add("expand");
            setTimeout(() => cursor.classList.remove("expand"), 200);
        }
    };
    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("click", handleClick);

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

    const handleTouch = (e) => {
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

    const stopTouch = (e) => {
        e.preventDefault();
        game.set_player_movement(0);
    };

    canvas.addEventListener('touchstart', handleTouch, { passive: false });
    canvas.addEventListener('touchmove', handleTouch, { passive: false });
    canvas.addEventListener('touchend', stopTouch);

    let lastTime = 0;

    function render(timestamp) {
        if (!document.body.contains(canvas)) {
            if (pauseOverlay) pauseOverlay.remove();
            document.removeEventListener("visibilitychange", handleVisibilityChange);
            document.removeEventListener("mousemove", handleMouseMove);
            document.removeEventListener("click", handleClick);
            window.removeEventListener("keydown", handleKeyDown);
            window.removeEventListener("keyup", handleKeyUp);
            return;
        }

        if (isPaused) {
            lastTime = 0;
            requestAnimationFrame(render);
            return;
        }

        if (!lastTime) lastTime = timestamp;
        const elapsed = timestamp - lastTime;
        lastTime = timestamp;

        const targetFrameMs = 1000 / 60;
        const dt = Math.min(elapsed / targetFrameMs, 3);
        game.tick_with_dt(dt);

        ctx.clearRect(0, 0, width, height);

        const computedStyle = getComputedStyle(document.documentElement);
        const textColor = computedStyle.getPropertyValue('--text-color').trim() || '#33ff00';
        ctx.fillStyle = textColor;

        ctx.shadowBlur = 10;
        ctx.shadowColor = textColor;


        ctx.fillRect(10, game.paddle_left_y(), 10, 100);
        ctx.fillRect(width - 20, game.paddle_right_y(), 10, 100);

        ctx.fillRect(game.ball_x(), game.ball_y(), 10, 10);
        let currentStreak = game.streak();

        if (streakEl.innerText !== currentStreak.toString()) {
            const container = document.getElementById('pong-container');
            if (container) {
                container.classList.remove('shake');
                void container.offsetWidth;
                container.classList.add('shake');
            }
        }

        streakEl.innerText = currentStreak;

        if (currentStreak > highScore) {
            highScore = currentStreak;
            highScoreEl.innerText = highScore;
            localStorage.setItem('pong_high_score', highScore);
        }

        if (speedIndicator && speedValue) {
            const speed = game.get_ball_speed();
            const normalizedSpeed = speed / 8.0;
            speedIndicator.style.display = 'block';
            speedValue.innerText = normalizedSpeed.toFixed(1);
        }

        requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
}

if (!window.HAS_SPA_ROUTER) {
    run().catch(console.error);
}
