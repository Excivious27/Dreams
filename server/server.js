// Dreams relay: rooms of up to 8 players. Pure forwarder with a tiny bit of
// room bookkeeping. Deploy anywhere Node runs (Fly.io, Render, a $4 VPS).
//   PORT (default 8787), MAX_PLAYERS (8), ROOM_TTL_MS (30 min empty).
// Protocol (JSON text frames):
//   client -> {t:"join", room:"ABCD", name, look, arc}   // room "" = create
//   server -> {t:"joined", id, room, host:true|false, peers:[{id,name,look,arc}]}
//   server -> {t:"peer_joined", peer:{...}} / {t:"peer_left", id}
//   client -> {t:"to", id, d:{...}}      // to one peer (host sync replies)
//   client -> {t:"all", d:{...}}         // to everyone else in the room
//   server -> {t:"msg", from:id, d:{...}}
//   client -> {t:"host_save", d:{...}}   // host snapshot kept so late joiners get it
//   server -> {t:"world", d:{...}}       // on join: the host's last snapshot
const { WebSocketServer } = require("ws");
const PORT = process.env.PORT || 8787;
const MAX = parseInt(process.env.MAX_PLAYERS || "8", 10);
const TTL = parseInt(process.env.ROOM_TTL_MS || "1800000", 10);

const rooms = new Map(); // code -> {host, peers: Map(id -> ws), world, emptySince}
let nextId = 1;
const code = () => { const a = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; let s = ""; for (let i = 0; i < 4; i++) s += a[Math.floor(Math.random() * a.length)]; return rooms.has(s) ? code() : s; };
const send = (ws, o) => { if (ws.readyState === 1) ws.send(JSON.stringify(o)); };

const wss = new WebSocketServer({ port: PORT });
console.log("dreams relay on", PORT);

wss.on("connection", (ws) => {
  ws.id = nextId++; ws.room = null; ws.info = {}; ws.isAlive = true; ws.budget = 120;
  ws.on("pong", () => { ws.isAlive = true; });
  ws.on("message", (buf) => {
    if (buf.length > 65536) return;                 // nothing in the protocol is this big
    if (--ws.budget < 0) return;                     // flood guard: ~120 msgs/s (refilled below)
    let m; try { m = JSON.parse(buf.toString()); } catch { return; }
    if (m.t === "join") {
      let r = m.room ? String(m.room).toUpperCase() : "";
      if (!r || !rooms.has(r)) { r = r && !rooms.has(r) && m.create !== false ? r : code(); rooms.set(r, { host: ws.id, peers: new Map(), world: null, emptySince: 0 }); }
      const room = rooms.get(r);
      if (room.peers.size >= MAX) return send(ws, { t: "full" });
      ws.room = r; ws.info = { id: ws.id, name: String(m.name || "Player").slice(0, 24), look: m.look || {}, arc: m.arc || "penguins", scene: "farm" };
      room.peers.set(ws.id, ws); room.emptySince = 0;
      const isHost = room.host === ws.id;
      send(ws, { t: "joined", id: ws.id, room: r, host: isHost, peers: [...room.peers.values()].filter(p => p !== ws).map(p => p.info) });
      if (!isHost && room.world) send(ws, { t: "world", d: room.world });
      for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_joined", peer: ws.info });
      return;
    }
    const room = ws.room && rooms.get(ws.room); if (!room) return;
    if (m.t === "host_save" && room.host === ws.id) { room.world = m.d; return; }
    if (m.t === "scene") { ws.info.scene = m.scene; for (const p of room.peers.values()) if (p !== ws) send(p, { t: "peer_scene", id: ws.id, scene: m.scene }); return; }
    if (m.t === "to") { const p = room.peers.get(m.id); if (p) send(p, { t: "msg", from: ws.id, d: m.d }); return; }
    if (m.t === "all") { for (const p of room.peers.values()) if (p !== ws) send(p, { t: "msg", from: ws.id, d: m.d }); return; }
  });
  ws.on("close", () => {
    const room = ws.room && rooms.get(ws.room); if (!room) return;
    room.peers.delete(ws.id);
    for (const p of room.peers.values()) send(p, { t: "peer_left", id: ws.id });
    if (room.host === ws.id && room.peers.size) { room.host = [...room.peers.keys()][0]; send(room.peers.get(room.host), { t: "you_are_host" }); }
    if (!room.peers.size) room.emptySince = Date.now();
  });
});
setInterval(() => { for (const [k, r] of rooms) if (!r.peers.size && r.emptySince && Date.now() - r.emptySince > TTL) rooms.delete(k); }, 60000);
// Heartbeat: a socket that misses two pings (30 s) is dropped so its room frees up.
setInterval(() => { for (const ws of wss.clients) { if (!ws.isAlive) { ws.terminate(); continue; } ws.isAlive = false; ws.ping(); } }, 15000);
setInterval(() => { for (const ws of wss.clients) ws.budget = 120; }, 1000);
