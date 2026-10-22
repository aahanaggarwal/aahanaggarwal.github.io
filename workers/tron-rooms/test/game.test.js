import test from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../src/game.js';
import { TronRoom } from '../src/index.js';

globalThis.WebSocketRequestResponsePair = class {};
function roomFixture() {
    const peers = [0, 1].map(i => ({
        readyState: 1, messages: [], attachment: { protocol: 2, messages: 0, rateAt: Date.now() },
        send(value) { this.messages.push(JSON.parse(value)); },
        close() { this.readyState = 3; },
        serializeAttachment(value) { this.attachment = structuredClone(value); },
        deserializeAttachment() { return structuredClone(this.attachment); },
    }));
    const ctx = { getWebSockets: () => peers, getTags: ws => [ws === peers[0] ? 'create' : 'join'], setWebSocketAutoResponse() {} };
    return { room: new TronRoom(ctx), ctx, peers };
}
function finish(room) {
    while (room.match.phase !== 'over') {
        clearTimeout(room.timer);
        room.advance();
    }
}

test('straight-line head-on draw ends once and resets all round state', () => {
    const match = new Match();
    match.start(1000); match.phase = 'playing';
    for (let i = 0; i < 20; i++) match.step();
    assert.equal(match.phase, 'over');
    assert.equal(match.winner, 0);
    assert.deepEqual(match.players.map(p => p.alive), [false, false]);
    assert.equal(match.tick, 20);
    assert.deepEqual(match.step(), []);
    match.pending[0] = 0;
    match.start(9000);
    assert.equal(match.round, 2);
    assert.equal(match.tick, 0);
    assert.equal(match.grid.some(Boolean), false);
    assert.deepEqual(match.pending, [null, null]);
    assert.deepEqual(match.players.map(p => p.dir), [1, 3]);
});

test('stale, invalid and reverse inputs cannot change the next round', () => {
    const match = new Match(); match.start(0); match.phase = 'playing';
    for (const dir of [-1, 4, 1.5, '0', null, 3]) match.input(0, dir, 1);
    match.input(0, 0, 0);
    assert.deepEqual(match.pending, [null, null]);
    match.input(0, 0, 1);
    match.input(0, 3, 1); // two fast keys must not reverse the simulated direction
    match.step();
    assert.deepEqual([match.players[0].x, match.players[0].y], [20, 29]);
    match.start(0); match.phase = 'playing';
    match.input(0, 2, 1);
    match.step();
    assert.deepEqual([match.players[0].x, match.players[0].y], [21, 30]);
});

test('wall and trail crashes give one score, preserved through rematch', () => {
    const match = new Match(); match.start(0); match.phase = 'playing';
    match.players[0].x = 0; match.players[0].dir = 3;
    match.step(); match.step();
    assert.equal(match.winner, 2);
    assert.deepEqual(match.scores, [0, 1]);
    match.start(0); match.phase = 'playing';
    match.grid[30 * 80 + 59] = 1;
    match.step();
    assert.equal(match.winner, 1);
    assert.deepEqual(match.scores, [1, 1]);
    match.start(0);
    assert.deepEqual(match.scores, [1, 1]);
});

test('both peers receive identical states across five simultaneous rematches', () => {
    const {room, peers} = roomFixture();
    room.startRound();
    for (let round = 1; round <= 5; round++) {
        finish(room);
        assert.equal(room.match.round, round);
        const request = JSON.stringify({ type: 'rematch', round });
        room.webSocketMessage(peers[0], request);
        room.webSocketMessage(peers[1], request);
        room.webSocketMessage(peers[0], JSON.stringify({ type: 'dir', dir: 0, round }));
        assert.equal(room.match.round, round + 1);
        assert.equal(room.match.phase, 'countdown');
        assert.deepEqual(room.match.pending, [null, null]);
    }
    assert.deepEqual(peers[0].messages, peers[1].messages);
    room.closeRoom('done');
    assert.equal(room.timer, null);
});

test('rematch still works after Durable Object hibernation', () => {
    const {room, peers, ctx} = roomFixture();
    room.startRound(); finish(room);
    const resumed = new TronRoom(ctx);
    assert.equal(resumed.match.phase, 'over');
    resumed.webSocketMessage(peers[1], JSON.stringify({ type: 'rematch', round: 1 }));
    assert.equal(resumed.match.round, 2);
    assert.equal(resumed.match.grid.some(Boolean), false);
    resumed.closeRoom('done');
});

test('disconnect during countdown stops the round and closes the remaining peer', () => {
    const {room, peers} = roomFixture();
    room.startRound();
    room.webSocketClose(peers[1]);
    assert.equal(room.timer, null);
    assert.equal(room.match.phase, 'waiting');
    assert.deepEqual(peers.map(p => p.readyState), [3, 3]);
    assert.equal(peers[0].messages.at(-1).type, 'ended');
});
