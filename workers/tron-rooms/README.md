# Tron server

`https://aahan.dev/tron/` connects to this Cloudflare Worker over WebSockets.
One SQLite-backed Durable Object runs each two-player match. The server owns
movement, collisions, scores, countdowns and rematches; browsers render its
ordered state updates. The Rust/WASM engine remains in use for local games.

Each round has an increasing ID. Inputs and rematch requests carry that ID,
so stale inputs and simultaneous rematches cannot change a later round.
Disconnecting ends the room and returns the remaining player to the lobby.
Waiting rooms and finished rounds use WebSocket hibernation, with the scores
and round ID kept in small socket attachments. Active rounds stop after ten
minutes. No database writes or paid services are required.

This uses features available on the Workers Free plan. Cloudflare currently
includes 100,000 Durable Object requests and 13,000 GB-seconds of active
compute per day, shared with other Durable Objects in the account. On Free,
exceeding a limit stops operations until the quota resets; this configuration
does not upgrade the account. See https://developers.cloudflare.com/durable-objects/platform/pricing/.

Run regression tests with `npm test` in this directory. Deploy with
`wrangler deploy` after authenticating to the personal account configured in
`wrangler.toml`. The existing website workflow publishes only the frontend; deploy this Worker
separately when its source changes. Protocol changes require deploying both
the Worker and the frontend.

For local Worker development: `wrangler dev --local --var ALLOW_LOCALHOST:true`.
Localhost origins are disabled in production. `/health` returns the protocol
version. Version 2 clients send `?role=create|join&v=2` to `/room/ABCD`.
