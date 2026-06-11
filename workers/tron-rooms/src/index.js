// Room relay for tron. URL: /room/<CODE>?role=create|join (WebSocket upgrade).
// The DO accepts the socket first, then reports problems as {type:"error"}
// messages before closing, so the client gets a readable reason.

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const match = url.pathname.match(/^\/room\/([A-Z]{4,8})$/);
        if (!match) return new Response('not found', { status: 404 });
        if (request.headers.get('Upgrade') !== 'websocket') {
            return new Response('expected websocket', { status: 426 });
        }
        const id = env.ROOMS.idFromName(match[1]);
        return env.ROOMS.get(id).fetch(request);
    },
};

export class TronRoom {
    constructor(ctx) {
        this.ctx = ctx;
    }

    async fetch(request) {
        const role = new URL(request.url).searchParams.get('role');
        const pair = new WebSocketPair();
        const [client, server] = [pair[0], pair[1]];

        const peers = this.ctx.getWebSockets();
        let reject = null;
        if (role === 'create' && peers.length > 0) reject = 'ROOM CODE IN USE';
        else if (role === 'join' && peers.length === 0) reject = 'ROOM NOT FOUND';
        else if (peers.length >= 2) reject = 'ROOM FULL';

        if (reject) {
            server.accept();
            server.send(JSON.stringify({ type: 'error', message: reject }));
            server.close(1008, reject);
        } else {
            this.ctx.acceptWebSocket(server, [role]);
            if (role === 'join') {
                for (const peer of peers) {
                    peer.send(JSON.stringify({ type: 'peer-joined' }));
                }
            }
        }
        return new Response(null, { status: 101, webSocket: client });
    }

    webSocketMessage(ws, message) {
        for (const peer of this.ctx.getWebSockets()) {
            if (peer !== ws) peer.send(message);
        }
    }

    webSocketClose(ws) {
        for (const peer of this.ctx.getWebSockets()) {
            if (peer !== ws) {
                peer.send(JSON.stringify({ type: 'peer-left' }));
            }
        }
    }
}
