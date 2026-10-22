// Same rules as wasm/tron; online rounds have one authoritative simulation.
export class Match {
    constructor() {
        this.round = 0;
        this.scores = [0, 0];
        this.phase = 'waiting';
    }

    start(now) {
        this.round++;
        this.grid = new Uint8Array(80 * 60);
        this.players = [{ x: 20, y: 30, dir: 1, alive: true }, { x: 60, y: 30, dir: 3, alive: true }];
        this.pending = [null, null];
        this.tick = 0;
        this.winner = 0;
        this.phase = 'countdown';
        this.startAt = now + 3200;
    }

    input(player, dir, round) {
        if (this.phase !== 'playing' || round !== this.round || !Number.isInteger(dir) || dir < 0 || dir > 3) return;
        // Validate against the last simulated heading, so rapid keys cannot reverse.
        if ((dir + 2) % 4 !== this.players[player].dir) this.pending[player] = dir;
    }

    step() {
        if (this.phase !== 'playing') return [];
        const trail = this.players.map((p, i) => [p.y * 80 + p.x, i + 1]);
        for (const [index, value] of trail) this.grid[index] = value;
        const next = this.players.map((p, i) => {
            if (this.pending[i] !== null) p.dir = this.pending[i];
            this.pending[i] = null;
            const dx = [0, 1, 0, -1][p.dir], dy = [-1, 0, 1, 0][p.dir];
            return { x: p.x + dx, y: p.y + dy };
        });
        const headOn = next[0].x === next[1].x && next[0].y === next[1].y;
        for (let i = 0; i < 2; i++) {
            const p = this.players[i], n = next[i];
            const wall = n.x < 0 || n.y < 0 || n.x >= 80 || n.y >= 60;
            p.alive = !wall && !headOn && this.grid[n.y * 80 + n.x] === 0;
            if (!wall) { p.x = n.x; p.y = n.y; }
        }
        this.tick++;
        if (this.players.some(p => !p.alive)) {
            this.phase = 'over';
            this.winner = this.players[0].alive ? 1 : this.players[1].alive ? 2 : 0;
            if (this.winner) this.scores[this.winner - 1]++;
        }
        return trail;
    }

    snapshot(trail = [], full = false) {
        return { type: 'state', round: this.round, phase: this.phase, tick: this.tick,
            players: this.players, scores: this.scores, winner: this.winner,
            startAt: this.startAt, serverNow: Date.now(), trail,
            ...(full ? { grid: Array.from(this.grid) } : {}) };
    }
}
