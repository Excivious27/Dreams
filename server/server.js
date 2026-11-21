// Dreams relay: rooms of up to 8 players. Pure forwarder with a tiny bit of
// room bookkeeping. Deploy anywhere Node runs (Fly.io, Render, a $4 VPS).
//   PORT (default 8787), MAX_PLAYERS (8), ROOM_TTL_MS (30 min empty), HOST_GRACE_MS (30 s).
// Protocol (JSON text frames):
//   client -> {t:"join", room:"ABCD", name, look, arc}   // room "" = create
//   server -> {t:"joined", id, room, host:true|false, host_id, peers:[{id,name,look,arc,host}]}
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
//   C17: client -> {t:"bye"} (deliberate leave; a proto 2+ host's ends the room: server -> {t:"host_left"} to all,
//     also when a proto 2+ host's grace runs out), {t:"ping", s} -> {t:"pong", s}; server -> {t:"slow"} (over a
//     budget, back off); peer_left of the host carries host:true + grace (ms); joined carries host_id.
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
// No vowels (A E I O U Y): a generated code never spells a word.
const code = () => { const a = "BCDFGHJKLMNPQRSTVWXZ23456789"; let s = ""; for (let i = 0; i < 4; i++) s += a[Math.floor(Math.random() * a.length)]; return rooms.has(s) ? code() : s; };
const send = (ws, o) => { if (ws.readyState === 1) ws.send(JSON.stringify(o)); };

const GUEST_CAP = 65536;      // a guest only sends small state/act frames
const HOST_CAP = 1048576;     // the host's world snapshot/deltas can be bigger on a late farm
// C17 abuse limits. Bytes per second per socket (the msg budget alone let 1 MB x 120/s fan out),
// failed joins per IP per minute (room codes can't be swept), sockets per IP, world keys kept.
const GUEST_BPS = 256 * 1024;
const HOST_BPS = 4 * 1048576;
const FAILED_JOINS_PER_MIN = 20;
const SOCKETS_PER_IP = 32;
const WORLD_KEYS_MAX = 64;
const LOOK_CAP = 8192;
const ipFails = new Map();    // ip -> failed joins this minute
const ipSockets = new Map();  // ip -> open sockets
// Behind Caddy every socket comes from 127.0.0.1: Caddy appends the real client to X-Forwarded-For.
const clientIp = (req) => {
  const ra = String((req && req.socket && req.socket.remoteAddress) || "");
  const xff = String((req && req.headers && req.headers["x-forwarded-for"]) || "");
  if (xff && /^(::ffff:)?127\.|^::1$/.test(ra)) return xff.split(",").pop().trim() || ra;
  return ra;
};
const cleanInfo = (id, m) => {
  let look = m.look && typeof m.look === "object" ? m.look : {};
  try { if (JSON.stringify(look).length > LOOK_CAP) look = {}; } catch { look = {}; }
  return { id, name: String(m.name || "Player").slice(0, 24), look, arc: m.arc === "gangsters" ? "gangsters" : "penguins", scene: "farm" };
};
// Proto 2+ rooms: a host that leaves on purpose (bye) or for good (grace over) ends the room for
// everyone at once ({t:"host_left"}); visiting guests can't take over a farm that went with its host.
// Proto 0/1 rooms keep the old you_are_host hand-over (backward compatible for one version).
const endRoom = (r, room, except) => {
  for (const p of room.peers.values()) { if (p !== except) { send(p, { t: "host_left" }); p.room = null; } }
  room.peers.clear(); rooms.delete(r);
};
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

wss.on("connection", (ws, req) => {
  ws.ip = clientIp(req);
  const nSock = (ipSockets.get(ws.ip) || 0) + 1;
  if (nSock > SOCKETS_PER_IP) { try { ws.close(1013, "busy"); } catch {} return; }
  ipSockets.set(ws.ip, nSock);
  ws.id = nextId++; ws.room = null; ws.info = {}; ws.isAlive = true; ws.budget = 120; ws.bytes = 0; ws.slowAt = 0;
  ws.on("pong", () => { ws.isAlive = true; });
  ws.on("error", () => {});  // a malformed frame must not take the relay down
  ws.on("message", (buf) => {
    const r0 = ws.room && rooms.get(ws.room);
    if (buf.length > (r0 && r0.host === ws.id ? HOST_CAP : GUEST_CAP)) return;  // only the host sends big frames
    ws.bytes += buf.length;
    if (--ws.budget < 0 || ws.bytes > (r0 && r0.host === ws.id ? HOST_BPS : GUEST_BPS)) {  // flood guard: ~120 msgs/s and a byte budget (refilled below)
      if (Date.now() - ws.slowAt > 1000) { ws.slowAt = Date.now(); send(ws, { t: "slow" }); }  // tell the client to back off instead of dropping in silence
      return;
    }
    let m; try { m = JSON.parse(buf.toString()); } catch { return; }
    if (!m || typeof m !== "object") return;
    if (m.t === "ping") return send(ws, { t: "pong", s: m.s });  // app-level liveness (a lone host has nobody else to hear from)
    if (m.t === "join") {
      if (ws.room) return;  // one join per socket (a second one left a ghost peer)
      let r = m.room ? String(m.room).toUpperCase().slice(0, 8) : "";
      if (r && !rooms.has(r) && m.create === false) {
        const f = (ipFails.get(ws.ip) || 0) + 1; ipFails.set(ws.ip, f);
        if (f > FAILED_JOINS_PER_MIN) { send(ws, { t: "slow" }); try { ws.close(1008, "slow"); } catch {} return; }
        return send(ws, { t: "no_room" });
      }
      const token = String(m.token || "");
      if (!r || !rooms.has(r)) { r = r && !rooms.has(r) ? r : code(); rooms.set(r, { host: ws.id, hostToken: token, peers: new Map(), world: null, emptySince: 0, proto: Number(m.proto) || 0 }); }
      const room = rooms.get(r);
      // Checks first: a refused join must not rewrite the room's host (or hostToken).
      if ((Number(m.proto) || 0) !== (room.proto || 0)) return send(ws, { t: "old_build", need: room.proto || 0 });
      if (room.peers.size >= MAX && !(token && [...room.peers.values()].some((p) => p.token === token))) return send(ws, { t: "full" });
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
      // A different device taking over never gets the old host's farm snapshot.
      if (!room.peers.has(room.host) && room.host !== ws.id && !(room.hostGoneAt && Date.now() - room.hostGoneAt < GRACE)) { if (room.hostToken !== token) room.world = null; room.host = ws.id; room.hostToken = token; room.hostGoneAt = 0; }
      ws.token = token;
      ws.room = r; ws.info = cleanInfo(ws.id, m);
      room.peers.set(ws.id, ws); room.emptySince = 0;
      const isHost = room.host === ws.id;
      send(ws, { t: "joined", id: ws.id, room: r, host: isHost, host_id: room.host, peers: [...room.peers.values()].filter(p => p !== ws).map(p => ({ ...p.info, host: p.id === room.host })) });
      if (!isHost && room.world) send(ws, { t: "world", d: room.world });
      for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_joined", peer: { ...ws.info, host: isHost } });
      return;
    }
    const room = ws.room && rooms.get(ws.room); if (!room) return;
    if (m.t === "host_save" && room.host === ws.id) {
      // A delta ({..., _delta:true}) merges into the kept snapshot; a full one replaces it.
      if (!m.d || typeof m.d !== "object" || Array.isArray(m.d)) return;
      if (m.d._delta && room.world) { for (const k of Object.keys(m.d)) if (k !== "_delta" && (k in room.world || Object.keys(room.world).length < WORLD_KEYS_MAX)) room.world[k] = m.d[k]; }
      else if (Object.keys(m.d).length <= WORLD_KEYS_MAX) room.world = m.d;
      return;
    }
    if (m.t === "bye") {  // a deliberate leave: a host's ends the room at once (proto 2+), no 30 s grace
      if (room.host === ws.id && (room.proto || 0) >= 2) { endRoom(ws.room, room, ws); ws.room = null; return; }
      room.peers.delete(ws.id); for (const p of room.peers.values()) send(p, { t: "peer_left", id: ws.id, bye: true });
      if (!room.peers.size) room.emptySince = Date.now();
      ws.room = null; return;
    }
    if (m.t === "scene") { ws.info.scene = String(m.scene || "").slice(0, 48); m.scene = ws.info.scene; for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_scene", id: ws.id, scene: m.scene }); return; }
    // host:true marks frames from the room's host, so guests only take world/toast from the host.
    const fromHost = room.host === ws.id;
    if (m.t === "to") { const p = room.peers.get(Number(m.id)); if (p) send(p, { t: "msg", from: ws.id, host: fromHost, d: m.d }); return; }
    if (m.t === "all") { for (const p of room.peers.values()) if (p !== ws) send(p, { t: "msg", from: ws.id, host: fromHost, d: m.d }); return; }
  });
  ws.on("close", () => {
    const n = (ipSockets.get(ws.ip) || 1) - 1; if (n > 0) ipSockets.set(ws.ip, n); else ipSockets.delete(ws.ip);
    const room = ws.room && rooms.get(ws.room); if (!room || !room.peers.has(ws.id)) return;
    room.peers.delete(ws.id);
    const wasHost = room.host === ws.id;
    for (const p of room.peers.values()) send(p, wasHost ? { t: "peer_left", id: ws.id, host: true, grace: GRACE } : { t: "peer_left", id: ws.id });
    if (wasHost && room.peers.size) {
      const gone = ws.id, code0 = ws.room; room.hostGoneAt = Date.now();
      setTimeout(() => {
        if (room.host !== gone || room.peers.has(gone) || !room.peers.size || rooms.get(code0) !== room) return;  // the host came back (or everyone left)
        if ((room.proto || 0) >= 2) return endRoom(code0, room, null);  // everyone at once, not one guest per grace
        room.host = [...room.peers.keys()][0]; room.hostToken = room.peers.get(room.host).token || ""; room.hostGoneAt = 0; room.world = null;
        send(room.peers.get(room.host), { t: "you_are_host" });
      }, GRACE);
    }
    if (!room.peers.size) room.emptySince = Date.now();
  });
});
setInterval(() => { for (const [k, r] of rooms) if (!r.peers.size && r.emptySince && Date.now() - r.emptySince > TTL) rooms.delete(k); }, 60000);
// Heartbeat: a socket that misses two pings (30 s) is dropped so its room frees up.
setInterval(() => { for (const ws of wss.clients) { if (!ws.isAlive) { ws.terminate(); continue; } ws.isAlive = false; ws.ping(); } }, 15000);
setInterval(() => { for (const ws of wss.clients) { ws.budget = 120; ws.bytes = 0; } }, 1000);
setInterval(() => ipFails.clear(), 60000);
