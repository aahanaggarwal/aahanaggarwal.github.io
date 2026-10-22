import { Match } from './game.js';

const ORIGINS = new Set(['https://aahan.dev', 'https://www.aahan.dev', 'https://aahanaggarwal.github.io']);

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        if (url.pathname === '/health') return Response.json({ ok: true, protocol: 2 });
        const match = url.pathname.match(/^\/room\/([A-Z]{4})$/);
        if (!match) return new Response('not found', { status: 404 });
        if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return new Response('expected websocket', { status: 426 });
        const origin = request.headers.get('Origin');
        if (!ORIGINS.has(origin) && !(env.ALLOW_LOCALHOST === 'true' && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin))) {
            return new Response('origin not allowed', { status: 403 });
        }
        return env.ROOMS.get(env.ROOMS.idFromName(match[1])).fetch(request);
    },
};

export class TronRoom {
    constructor(ctx) {
        this.ctx = ctx;
        this.match = new Match();
        this.timer = null;
        const saved = this.ctx.getWebSockets().map(ws => ws.deserializeAttachment()?.completed).find(Boolean);
        if (saved) {
            Object.assign(this.match, saved);
            this.match.pending = [null, null];
        }
        // No timers or chargeable storage writes while waiting between rounds.
        this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
    }

    peers() { return this.ctx.getWebSockets().filter(ws => ws.readyState === 1); }

    fetch(request) {
        const url = new URL(request.url);
        const role = url.searchParams.get('role');
        const pair = new WebSocketPair();
        const [client, server] = [pair[0], pair[1]];
        const peers = this.peers();
        let reject = null;
        if (url.searchParams.get('v') !== '2') reject = 'Game updated. Reload this page to play.';
        else if (!['create', 'join'].includes(role)) reject = 'INVALID ROLE';
        else if (role === 'create' && peers.length) reject = 'ROOM CODE IN USE';
        else if (role === 'join' && !peers.some(ws => this.ctx.getTags(ws).includes('create'))) reject = 'ROOM NOT FOUND';
        else if (peers.length >= 2) reject = 'ROOM FULL';
        if (reject) {
            server.accept();
            server.send(JSON.stringify({ type: 'error', message: reject }));
            server.close(1008, reject);
        } else {
            this.ctx.acceptWebSocket(server, [role]);
            server.serializeAttachment({ protocol: 2, rateAt: Date.now(), messages: 0 });
            server.send(JSON.stringify({ type: 'welcome', player: role === 'create' ? 1 : 2 }));
            if (role === 'join') {
                // Existing connections from the old relay must reload together.
                if (peers.some(ws => !ws.deserializeAttachment()?.protocol)) {
                    this.closeRoom('Game updated. Reload this page to play.');
                } else {
                    this.match = new Match();
                    this.startRound();
                }
            }
        }
        return new Response(null, { status: 101, webSocket: client });
    }

    broadcast(message) {
        const data = JSON.stringify(message);
        for (const peer of this.peers()) { try { peer.send(data); } catch {} }
    }

    startRound() {
        if (this.timer !== null || this.peers().length !== 2) return;
        for (const peer of this.peers()) {
            const { completed, ...attachment } = peer.deserializeAttachment() || {};
            peer.serializeAttachment(attachment);
        }
        this.match.start(Date.now());
        this.expiresAt = Date.now() + 10 * 60 * 1000;
        this.broadcast(this.match.snapshot([], true));
        this.timer = setTimeout(() => this.advance(), 3200);
    }

    advance() {
        this.timer = null;
        if (this.peers().length !== 2) return this.closeRoom('Opponent disconnected. Create or join a new room.');
        if (Date.now() >= this.expiresAt) return this.closeRoom('Round timed out. Create or join a new room.');
        this.match.phase = 'playing';
        const trail = this.match.step();
        this.broadcast(this.match.snapshot(trail));
        if (this.match.phase === 'over') {
            for (const peer of this.peers()) {
                const attachment = peer.deserializeAttachment();
                peer.serializeAttachment({ ...attachment, completed: { round: this.match.round, scores: this.match.scores, phase: 'over' } });
            }
        }
        if (this.match.phase === 'playing') {
            this.timer = setTimeout(() => this.advance(), Math.max(40, 120 - Math.floor(this.match.tick / 10) * 2));
        }
    }

    webSocketMessage(ws, message) {
        if (typeof message !== 'string' || message.length > 256) return this.closeRoom('Invalid game message.');
        let msg;
        try { msg = JSON.parse(message); } catch { return; }
        if (!msg || typeof msg !== 'object') return;
        const attachment = ws.deserializeAttachment();
        if (!attachment?.protocol) return this.closeRoom('Game updated. Reload this page to play.');
        const now = Date.now();
        if (now - attachment.rateAt >= 1000) { attachment.rateAt = now; attachment.messages = 0; }
        attachment.messages++;
        ws.serializeAttachment(attachment);
        if (attachment.messages > 60) return this.closeRoom('Too many inputs. Rejoin the game.');
        const player = this.ctx.getTags(ws).includes('create') ? 0 : 1;
        if (msg.type === 'dir') this.match.input(player, msg.dir, msg.round);
        // Round identity makes simultaneous or delayed rematches idempotent.
        if (msg.type === 'rematch' && this.match.phase === 'over' && msg.round === this.match.round) this.startRound();
        // A sleeping object has no active round. Return both clients to the lobby.
        if (this.match.phase === 'waiting' && this.peers().length === 2) this.closeRoom('Session expired. Create or join a new room.');
    }

    closeRoom(message) {
        if (this.timer !== null) clearTimeout(this.timer);
        this.timer = null;
        this.match.phase = 'waiting';
        this.broadcast({ type: 'ended', message });
        for (const peer of this.peers()) { try { peer.close(1000, 'Session ended'); } catch {} }
    }

    webSocketClose(ws) {
        try { ws.close(1000, 'Disconnected'); } catch {}
        this.closeRoom('Opponent left. Create or join a new room.');
    }

    webSocketError(ws) { this.webSocketClose(ws); }
}
