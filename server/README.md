# Dreams relay server

A tiny WebSocket relay so the web build can play together (up to 8 per room).
The HOST's game is the world (their save, clock, weather, farm); other players
are guests whose actions are sent to the host and echoed back. Nothing is
stored on the server except the host's last snapshot for late joiners.

## The live relay (Nov 20, 2026)

- Game address **wss://dreams-64-23-239-63.sslip.io** (`NetNode.DEFAULT_URL` in scripts/net.gd): the
  game uses it out of the box. Title > Play together still has a server field for a custom
  relay, and "Reset to default" puts this one back (SaveGame `net_url` keeps only a custom
  address; "" = the default).
- Health: https://dreams-64-23-239-63.sslip.io answers `dreams relay ok`.
- `GET /version` answers JSON `{commit, code, started, rooms, players}`:
  - `code` = first 12 hex of sha1(server.js + package-lock.json), computed at start. It needs
    nothing on the box, so it works with the update script installed at setup. CI computes the
    same hash from its checkout to tell which server/ is live (tools/conduct/relay_live_check.py).
  - `commit`, first that answers: `$DREAMS_COMMIT`; the file `server/.deployed_commit` (or
    `.deployed_commit` beside server/, or `$DREAMS_VERSION_FILE`), which deploy/dreams-update.sh
    in this repo writes; else `git rev-parse HEAD` of the checkout server.js runs from (the box
    runs it inside its sparse checkout); else `"unknown"`.
  - The live box only shows /version after the next server/ deploy (the first push of this
    server.js to main). The box runs the update script copy installed at setup: if that copy
    doesn't write `.deployed_commit`, `commit` still comes from git (if the service runs from the
    checkout) and `code` always works. Nothing here needs the droplet console.
- Box: DigitalOcean droplet "dreams-relay" (SFO3, Ubuntu 24.04, 1 vCPU / 512 MB + 1 GB swap),
  Caddy (auto-HTTPS) -> Node on 127.0.0.1:8787 (systemd `dreams-relay`), ufw 22/80/443.
  No SSH keys; Tom holds the root password. Never ask him for it.
- **Deploying = pushing server/ to main.** A systemd timer runs the update every 10 min: sparse,
  shallow pull of server/ from main; if server/ changed, `npm ci` and restart. So every server/
  change must pass `node tools/relay_test.js` (in tools/check.sh) before it reaches main.
- `deploy/` holds reference copies of the box setup: `dreams-update.sh` (reconstructed update
  script; also writes `.deployed_commit`), `dreams-update.service/.timer`, `dreams-relay.service`,
  `Caddyfile`. A rebuilt box installs these (script to /usr/local/bin/dreams-update.sh,
  checkout at /opt/dreams). They may differ in paths from what was installed on Nov 20.

## Tests

- `node tools/relay_test.js`: starts this server on a free local port; 3-7 clients: create/join,
  peer lists, to/all routing with the host flag, unknown room, host_save full + delta and the
  late-join world, scene, room full, size caps (guest 64 KB dropped, host 300 KB forwarded,
  over 1 MB closes 1009), host reconnect by token inside the grace, host leave -> you_are_host,
  /version. In check.sh.
- `node tools/relay_test.js --live` (or `--url wss://...`): the live-safe subset against the live
  relay (one fresh room, 5 round trips); prints `RELAY LIVE: ok, <median ms>ms`.
- `bash tools/net_e2e.sh [url]`: two headless Godot instances (host + guest) play together with
  scripts/net.gd through the live relay (join by code, late-join world, clock, puppets, guest
  moves and the host sees it).
- CI (conduct-ci.yml "relay" job): post-merge runs and every push to main that touches server/,
  net.gd or these tests run the live check (`RELAY: ok, Xms` in summary.txt) and, when net.gd or
  server/ changed, the NET E2E. After a server/ push it waits up to 15 min for /version's `code`
  to match. An outage is reported, and fails the run only when that run changed server/.

## Run your own (any of these is enough)

- **Fly.io / Render / Railway** (free or ~$5/mo): new Node app from this folder, start command `npm start`, expose the port. Use the `wss://` URL it gives you.
- **A $4 VPS**: `apt install nodejs npm`, `npm i`, `PORT=8787 node server.js`, put it behind Caddy/nginx with TLS (web builds need `wss://`).

Then in the game: Title → Play together → type your server URL in the server field (saved; "Reset to default" goes back to the Dreams relay), Host or Join with a 4-letter code.

## Later: Steam
The client talks to a `NetTransport`; this relay is the WebSocket transport. A Steam build swaps in ENet/Steam Networking behind the same calls.
