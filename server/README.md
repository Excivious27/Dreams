# Dreams relay server

A tiny WebSocket relay so the web build can play together (up to 8 per room).
The HOST's game is the world (their save, clock, weather, farm); other players
are guests whose actions are sent to the host and echoed back. Nothing is
stored on the server except the host's last snapshot for late joiners.

## Run it (any of these is enough)

- **Fly.io / Render / Railway** (free or ~$5/mo): new Node app from this folder, start command `npm start`, expose the port. Use the `wss://` URL it gives you.
- **A $4 VPS**: `apt install nodejs npm`, `npm i`, `PORT=8787 node server.js`, put it behind Caddy/nginx with TLS (web builds need `wss://`).

Then in the game: Title → Play together → paste the server URL once (saved), Host or Join with a 4-letter code.

## Later: Steam
The client talks to a `NetTransport`; this relay is the WebSocket transport. A Steam build swaps in ENet/Steam Networking behind the same calls.
