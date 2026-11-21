// Dreams relay: rooms of up to 8 players. Pure forwarder with a tiny bit of
// room bookkeeping. Deploy anywhere Node runs (Fly.io, Render, a $4 VPS).
//   PORT (default 8787), MAX_PLAYERS (8), ROOM_TTL_MS (30 min empty), HOST_GRACE_MS (30 s).
// Protocol (JSON text frames):
//   client -> {t:"join", room:"ABCD", name, look, arc}   // room "" = create
//   server -> {t:"joined", id, room, host:true|false, peers:[{id,name,look,arc}]}
//   server -> {t:"old_build", need} when the joiner's proto differs from the room creator's (no proto = 0)
//   server -> {t:"peer_joined", peer:{...}} / {t:"peer_left", id}
//   client -> {t:"to", id, d:{...}}      // to one peer (host sync replies)
//   client -> {t:"all", d:{...}}         // to everyone else in the room
//   server -> {t:"msg", from:id, host:bool, d:{...}}   // host = sent by the room's host
//   client -> {t:"host_save", d:{...}}   // host snapshot kept so late joiners get it (full keys; deltas merge in)
//   HTTP GET -> 200 "dreams relay ok" (health checks)
//   HTTP GET /version -> 200 JSON {commit, code, started, rooms, players} (CI's live relay check;
//     "code" = sha1 of server.js + package-lock.json, so CI can tell which server/ is live with no
//     git on either side; "commit" = see deployedCommit() below, "unknown" if nothing says)
//   server -> {t:"world", d:{...}}       // on join: the host's last snapshot
const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { execFileSync } = require("child_process");
const { WebSocketServer } = require("ws");
const PORT = process.env.PORT || 8787;
const MAX = parseInt(process.env.MAX_PLAYERS || "8", 10);
const TTL = parseInt(process.env.ROOM_TTL_MS || "1800000", 10);
const GRACE = parseInt(process.env.HOST_GRACE_MS || "30000", 10);  // a host's phone gets this long to come back (screen lock, app switch, signal)

const rooms = new Map(); // code -> {host, peers: Map(id -> ws), world, emptySince}
let nextId = 1;
const code = () => { const a = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; let s = ""; for (let i = 0; i < 4; i++) s += a[Math.floor(Math.random() * a.length)]; return rooms.has(s) ? code() : s; };
const send = (ws, o) => { if (ws.readyState === 1) ws.send(JSON.stringify(o)); };

const GUEST_CAP = 65536;      // a guest only sends small state/act frames
const HOST_CAP = 1048576;     // the host's world snapshot/deltas can be bigger on a late farm
// Which code is running, read once at start (the update script restarts us after a deploy).
// "code" needs nothing on the box; "commit" tries, in order: $DREAMS_COMMIT, the file the
// update script writes (server/.deployed_commit or the checkout's .deployed_commit, or
// $DREAMS_VERSION_FILE), then `git rev-parse HEAD` in the checkout we run from (the box runs
// server.js inside its sparse checkout of the repo), else "unknown".
const codeHash = () => { const h = crypto.createHash("sha1"); for (const f of ["server.js", "package-lock.json"]) { try { h.update(fs.readFileSync(path.join(__dirname, f))); } catch { h.update(""); } } return h.digest("hex").slice(0, 12); };
function deployedCommit() {
  const ok = (s) => /^[0-9a-f]{7,40}$/i.test(String(s || "").trim()) ? String(s).trim() : "";
  if (ok(process.env.DREAMS_COMMIT)) return ok(process.env.DREAMS_COMMIT);
  for (const f of [process.env.DREAMS_VERSION_FILE, path.join(__dirname, ".deployed_commit"), path.join(__dirname, "..", ".deployed_commit")]) {
    if (!f) continue;
    try { const c = ok(fs.readFileSync(f, "utf8")); if (c) return c; } catch {}
  }
  try { return ok(execFileSync("git", ["-c", "safe.directory=*", "-C", __dirname, "rev-parse", "HEAD"], { timeout: 3000, stdio: ["ignore", "pipe", "ignore"] }).toString()) || "unknown"; } catch {}
  return "unknown";
}
const VERSION = { commit: deployedCommit(), code: codeHash(), started: new Date().toISOString() };
// Plain HTTP answers 200 so Render/Fly health checks pass (instead of a 426 upgrade error).
const server = http.createServer((req, res) => {
  if ((req.url || "").split("?")[0] === "/version") {
    let players = 0; for (const r of rooms.values()) players += r.peers.size;
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    return res.end(JSON.stringify({ ...VERSION, rooms: rooms.size, players }) + "\n");
  }
  res.writeHead(200, { "Content-Type": "text/plain" }); res.end("dreams relay ok\n");
});
const wss = new WebSocketServer({ server, maxPayload: HOST_CAP });
server.listen(PORT);
console.log("dreams relay on", PORT);

wss.on("connection", (ws) => {
  ws.id = nextId++; ws.room = null; ws.info = {}; ws.isAlive = true; ws.budget = 120;
  ws.on("pong", () => { ws.isAlive = true; });
  ws.on("error", () => {});  // a malformed frame must not take the relay down
  ws.on("message", (buf) => {
    const r0 = ws.room && rooms.get(ws.room);
    if (buf.length > (r0 && r0.host === ws.id ? HOST_CAP : GUEST_CAP)) return;  // only the host sends big frames
    if (--ws.budget < 0) return;                     // flood guard: ~120 msgs/s (refilled below)
    let m; try { m = JSON.parse(buf.toString()); } catch { return; }
    if (!m || typeof m !== "object") return;
    if (m.t === "join") {
      let r = m.room ? String(m.room).toUpperCase().slice(0, 8) : "";
      if (r && !rooms.has(r) && m.create === false) return send(ws, { t: "no_room" });
      if (!r || !rooms.has(r)) { r = r && !rooms.has(r) ? r : code(); rooms.set(r, { host: ws.id, hostToken: String(m.token || ""), peers: new Map(), world: null, emptySince: 0, proto: Number(m.proto) || 0 }); }
      const room = rooms.get(r);
      const token = String(m.token || "");
      // Reconnect: the same device replaces its old socket (no ghost) and keeps the host role.
      if (token) {
        for (const [pid, p] of room.peers) {
          if (p !== ws && p.token === token) {
            room.peers.delete(pid);
            for (const q of room.peers.values()) send(q, { t: "peer_left", id: pid });
            if (room.host === pid) room.host = ws.id;
            try { p.terminate(); } catch {}
          }
        }
        if (room.hostToken && room.hostToken === token) { room.host = ws.id; room.hostGoneAt = 0; }
      }
      // A room whose host is gone (left alone, timed out) gets a new host: whoever comes in.
      if (!room.peers.has(room.host) && room.host !== ws.id && !(room.hostGoneAt && Date.now() - room.hostGoneAt < GRACE)) { room.host = ws.id; room.hostToken = token; room.hostGoneAt = 0; }
      // Build check (S1): a client on another protocol would desync silently; no proto = 0 (old clients).
      if ((Number(m.proto) || 0) !== (room.proto || 0)) return send(ws, { t: "old_build", need: room.proto || 0 });
      if (room.peers.size >= MAX) return send(ws, { t: "full" });
      ws.token = token;
      ws.room = r; ws.info = { id: ws.id, name: String(m.name || "Player").slice(0, 24), look: m.look || {}, arc: m.arc || "penguins", scene: "farm" };
      room.peers.set(ws.id, ws); room.emptySince = 0;
      const isHost = room.host === ws.id;
      send(ws, { t: "joined", id: ws.id, room: r, host: isHost, peers: [...room.peers.values()].filter(p => p !== ws).map(p => p.info) });
      if (!isHost && room.world) send(ws, { t: "world", d: room.world });
      for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_joined", peer: ws.info });
      return;
    }
    const room = ws.room && rooms.get(ws.room); if (!room) return;
    if (m.t === "host_save" && room.host === ws.id) {
      // A delta ({..., _delta:true}) merges into the kept snapshot; a full one replaces it.
      if (m.d && m.d._delta && room.world) { for (const k of Object.keys(m.d)) if (k !== "_delta") room.world[k] = m.d[k]; }
      else room.world = m.d;
      return;
    }
    if (m.t === "scene") { ws.info.scene = m.scene; for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_scene", id: ws.id, scene: m.scene }); return; }
    // host:true marks frames from the room's host, so guests only take world/toast from the host.
    const fromHost = room.host === ws.id;
    if (m.t === "to") { const p = room.peers.get(Number(m.id)); if (p) send(p, { t: "msg", from: ws.id, host: fromHost, d: m.d }); return; }
    if (m.t === "all") { for (const p of room.peers.values()) if (p !== ws) send(p, { t: "msg", from: ws.id, host: fromHost, d: m.d }); return; }
  });
  ws.on("close", () => {
    const room = ws.room && rooms.get(ws.room); if (!room) return;
    room.peers.delete(ws.id);
    for (const p of room.peers.values()) send(p, { t: "peer_left", id: ws.id });
    if (room.host === ws.id && room.peers.size) {
      const gone = ws.id; room.hostGoneAt = Date.now();
      setTimeout(() => {
        if (room.host !== gone || room.peers.has(gone) || !room.peers.size) return;  // the host came back (or everyone left)
        room.host = [...room.peers.keys()][0]; room.hostToken = room.peers.get(room.host).token || ""; room.hostGoneAt = 0;
        send(room.peers.get(room.host), { t: "you_are_host" });
      }, GRACE);
    }
    if (!room.peers.size) room.emptySince = Date.now();
  });
});
setInterval(() => { for (const [k, r] of rooms) if (!r.peers.size && r.emptySince && Date.now() - r.emptySince > TTL) rooms.delete(k); }, 60000);
// Heartbeat: a socket that misses two pings (30 s) is dropped so its room frees up.
setInterval(() => { for (const ws of wss.clients) { if (!ws.isAlive) { ws.terminate(); continue; } ws.isAlive = false; ws.ping(); } }, 15000);
setInterval(() => { for (const ws of wss.clients) ws.budget = 120; }, 1000);
