import init, { PongGame } from './pkg/pong.js';

async function run() {
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
    window.addEventListener('keydown', (e) => {
        if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
            game.set_player_movement(-1);
        } else if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
            game.set_player_movement(1);
        }
    });

    window.addEventListener('keyup', (e) => {
        if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
            // Only stop if we were moving in that direction
            // This is a simplification; handling simultaneous keys perfectly needs more state
            game.set_player_movement(0);
        } else if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
            game.set_player_movement(0);
        }
    });

    function render() {
        // Update Game State
        game.tick();

        // Clear Canvas
        ctx.fillStyle = '#0a0a0a'; // Match background or black
        ctx.fillRect(0, 0, width, height);

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

        requestAnimationFrame(render);
    }

    requestAnimationFrame(render);
}

run().catch(console.error);
