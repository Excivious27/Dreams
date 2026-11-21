#!/usr/bin/env node
// relay_test.js: protocol test for the multiplayer relay (server/server.js), run before any
// server/ change reaches main (a push of server/ to main deploys the live relay).
//   node tools/relay_test.js            starts server/server.js on a free local port and tests it
//   node tools/relay_test.js --live     runs the live-safe subset against the live relay
//   node tools/relay_test.js --url wss://...   the live-safe subset against any relay
// Local: create/join, peer lists, "to"/"all" routing with the host flag, unknown room,
// host_save full + delta and the late-join world, scene, room full, size caps (guest 64 KB,
// host 1 MB), host leave -> grace -> you_are_host, host reconnect by token inside the grace,
// GET /version and the health text. Prints "RELAY TEST OK" or "RELAY TEST FAIL: ..." (exit 1).
// --live also prints "RELAY LIVE: ok, <ms>ms" (median round trip of 5 pings host->guest->host).
"use strict";
const path = require("path");
const net = require("net");
const http = require("http");
const https = require("https");
const { spawn } = require("child_process");
const WebSocket = require(path.join(__dirname, "..", "server", "node_modules", "ws"));

const LIVE_URL = "wss://dreams-64-23-239-63.sslip.io";
const args = process.argv.slice(2);
const urlArg = args.includes("--url") ? args[args.indexOf("--url") + 1] : (args.includes("--live") ? LIVE_URL : "");
const GRACE = 1500;  // local server's HOST_GRACE_MS: short, so the hand-over test is quick
let fails = 0;
const ok = (cond, what) => { if (cond) console.log("  ok  " + what); else { fails++; console.log("  FAIL " + what); } };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function freePort() {
  return new Promise((res, rej) => { const s = net.createServer(); s.unref(); s.on("error", rej); s.listen(0, "127.0.0.1", () => { const p = s.address().port; s.close(() => res(p)); }); });
}

function httpGet(url) {
  return new Promise((res) => {
    const mod = url.startsWith("https") ? https : http;
    const rq = mod.get(url, { timeout: 10000 }, (r) => { let b = ""; r.on("data", (c) => (b += c)); r.on("end", () => res({ status: r.statusCode, body: b })); });
    rq.on("timeout", () => { rq.destroy(); res({ status: 0, body: "" }); });
    rq.on("error", () => res({ status: 0, body: "" }));
  });
}

// One client: a socket plus an inbox that tests wait on.
class Client {
  constructor(url, name) { this.url = url; this.name = name; this.inbox = []; this.waiters = []; this.closed = false; this.closeCode = 0; }
  open() {
    return new Promise((res, rej) => {
      this.ws = new WebSocket(this.url, { handshakeTimeout: 10000, maxPayload: 4 << 20 });
      this.ws.on("open", () => res(this));
      this.ws.on("error", (e) => rej(e));
      this.ws.on("close", (c) => { this.closed = true; this.closeCode = c; });
      this.ws.on("message", (buf) => {
        let m; try { m = JSON.parse(buf.toString()); } catch { return; }
        this.inbox.push(m);
        this.waiters = this.waiters.filter((w) => { const i = this.inbox.findIndex(w.pred); if (i < 0) return true; w.res(this.inbox.splice(i, 1)[0]); clearTimeout(w.timer); return false; });
      });
    });
  }
  send(o) { this.ws.send(typeof o === "string" ? o : JSON.stringify(o)); }
  // Resolves with the first message matching pred (already received or coming), or null after ms.
  wait(pred, ms = 3000) {
    const i = this.inbox.findIndex(pred);
    if (i >= 0) return Promise.resolve(this.inbox.splice(i, 1)[0]);
    return new Promise((res) => { const w = { pred, res, timer: setTimeout(() => { this.waiters = this.waiters.filter((x) => x !== w); res(null); }, ms) }; this.waiters.push(w); });
  }
  waitT(t, ms) { return this.wait((m) => m.t === t, ms); }
  async join(room, extra = {}) { this.send({ t: "join", room, name: this.name, look: {}, arc: "penguins", ...extra }); return this.wait((m) => ["joined", "no_room", "full"].includes(m.t), 8000); }
  close() { try { this.ws.close(); } catch {} }
  kill() { try { this.ws.terminate(); } catch {} }
}

async function liveSubset(url) {
  // Only what is safe on a shared live relay: one fresh room, two clients, a few small frames.
  const h = await new Client(url, "ci-host").open();
  const g = await new Client(url, "ci-guest").open();
  const hj = await h.join("", { token: "ci-h-" + Date.now() });
  ok(hj && hj.t === "joined" && hj.host === true && /^[A-Z2-9]{4}$/.test(hj.room), "live: host created room " + (hj && hj.room));
  if (!hj || hj.t !== "joined") throw new Error("no room on the live relay");
  h.send({ t: "host_save", d: { day: 7, probe: true } });
  await sleep(300);
  const gj = await g.join(hj.room, { create: false, token: "ci-g-" + Date.now() });
  ok(gj && gj.t === "joined" && gj.host === false && gj.peers.length === 1, "live: guest joined by code");
  const w = await g.waitT("world", 3000);
  ok(w && w.d && w.d.day === 7, "live: guest got the host's world on join");
  ok(!!(await h.waitT("peer_joined", 3000)), "live: host saw peer_joined");
  const rtts = [];
  for (let i = 0; i < 5; i++) {
    const t0 = process.hrtime.bigint();
    h.send({ t: "all", d: { ping: i } });
    const got = await g.wait((m) => m.t === "msg" && m.d && m.d.ping === i, 5000);
    if (!got) break;
    g.send({ t: "to", id: hj.id, d: { pong: i } });
    const back = await h.wait((m) => m.t === "msg" && m.d && m.d.pong === i, 5000);
    if (!back) break;
    ok(got.host === true && back.host === false, "live: round trip " + (i + 1) + " (host flag right)");
    rtts.push(Number(process.hrtime.bigint() - t0) / 1e6);
  }
  ok(rtts.length === 5, "live: 5 round trips");
  g.close(); h.close();
  const ver = await httpGet(url.replace(/^ws/, "http") + "/version");
  let v = null; try { v = JSON.parse(ver.body); } catch {}
  console.log("  live /version: " + (v ? JSON.stringify(v) : ("(no JSON yet: " + ver.body.trim().slice(0, 40) + ")")));
  rtts.sort((a, b) => a - b);
  return rtts.length ? Math.round(rtts[Math.floor(rtts.length / 2)]) : -1;
}

async function localSuite(url, httpUrl) {
  // health + version
  const hv = await httpGet(httpUrl + "/");
  ok(hv.status === 200 && hv.body.trim() === "dreams relay ok", "GET / answers the health text");
  const vv = await httpGet(httpUrl + "/version");
  let v = null; try { v = JSON.parse(vv.body); } catch {}
  ok(v && /^[0-9a-f]{12}$/.test(v.code) && typeof v.commit === "string" && v.commit.length > 0, "GET /version: " + vv.body.trim());

  const A = await new Client(url, "Ann").open();
  const B = await new Client(url, "Bo").open();
  const C = await new Client(url, "Cy").open();
  // create + join
  const aj = await A.join("", { token: "tokA" });
  ok(aj && aj.t === "joined" && aj.host === true && aj.peers.length === 0 && /^[A-Z2-9]{4}$/.test(aj.room), "host creates a room (" + (aj && aj.room) + ")");
  const room = aj.room;
  const nr = await new Client(url, "x").open().then((x) => x.join("ZZZZ", { create: false }).then((m) => { x.close(); return m; }));
  ok(nr && nr.t === "no_room", "joining an unknown code answers no_room");
  // host_save: full then delta; the late joiner gets the merged world
  A.send({ t: "host_save", d: { day: 3, farm: { a: 1 }, money: 10 } });
  A.send({ t: "host_save", d: { _delta: true, money: 25 } });
  B.send({ t: "host_save", d: { day: 99 } });  // not the host yet (not even in a room): ignored
  await sleep(150);
  const bj = await B.join(room.toLowerCase(), { create: false, token: "tokB" });
  ok(bj && bj.t === "joined" && bj.host === false && bj.room === room && bj.peers.length === 1 && bj.peers[0].name === "Ann", "guest joins by code (lower case ok), sees the host in peers");
  const bw = await B.waitT("world");
  ok(bw && bw.d.day === 3 && bw.d.money === 25 && bw.d.farm.a === 1 && !("_delta" in bw.d), "late joiner gets the host's world (full + delta merged)");
  const pj = await A.waitT("peer_joined");
  ok(pj && pj.peer.name === "Bo", "host gets peer_joined");
  const cj = await C.join(room, { create: false, token: "tokC" });
  ok(cj && cj.t === "joined" && cj.peers.length === 2, "third player joins (sees 2 peers)");
  await C.waitT("world"); await A.waitT("peer_joined"); await B.waitT("peer_joined");
  // routing: all / to, host flag
  A.send({ t: "all", d: { k: "from-host" } });
  const b1 = await B.wait((m) => m.t === "msg" && m.d.k === "from-host");
  const c1 = await C.wait((m) => m.t === "msg" && m.d.k === "from-host");
  ok(b1 && c1 && b1.host === true && b1.from === aj.id, "\"all\" from the host reaches both guests with host:true");
  ok(!(await A.wait((m) => m.t === "msg" && m.d.k === "from-host", 300)), "\"all\" is not echoed to the sender");
  B.send({ t: "to", id: cj.id, d: { k: "b-to-c" } });
  const c2 = await C.wait((m) => m.t === "msg" && m.d.k === "b-to-c");
  ok(c2 && c2.host === false && c2.from === bj.id, "\"to\" reaches only its target, host:false from a guest");
  ok(!(await A.wait((m) => m.t === "msg" && m.d.k === "b-to-c", 300)), "\"to\" does not leak to others");
  B.send({ t: "scene", scene: "town" });
  const ps = await A.waitT("peer_scene");
  ok(ps && ps.id === bj.id && ps.scene === "town", "scene change is broadcast");
  B.send("not json {"); B.send(JSON.stringify(42));
  B.send({ t: "all", d: { k: "still-alive" } });
  ok(!!(await A.wait((m) => m.t === "msg" && m.d.k === "still-alive")), "malformed frames are ignored, the socket keeps working");
  // size caps: a guest frame over 64 KB is dropped; the host may send big frames (up to 1 MB)
  const big = "x".repeat(70000);
  B.send({ t: "all", d: { k: "guest-big", pad: big } });
  ok(!(await A.wait((m) => m.t === "msg" && m.d.k === "guest-big", 600)), "guest frame > 64 KB is dropped");
  A.send({ t: "all", d: { k: "host-big", pad: "y".repeat(300000) } });
  const hb = await B.wait((m) => m.t === "msg" && m.d.k === "host-big", 4000);
  ok(hb && hb.d.pad.length === 300000, "host frame of 300 KB is forwarded");
  const X = await new Client(url, "Huge").open();
  X.send("z".repeat(1100000));
  for (let i = 0; i < 30 && !X.closed; i++) await sleep(100);
  ok(X.closed && X.closeCode === 1009, "a frame over 1 MB closes that socket (1009), close code " + X.closeCode);
  // room full (local server runs MAX_PLAYERS=4)
  const D = await new Client(url, "Di").open();
  const dj = await D.join(room, { create: false, token: "tokD" });
  ok(dj && dj.t === "joined", "4th player fits");
  const E = await new Client(url, "Ed").open();
  const ej = await E.join(room, { create: false, token: "tokE" });
  ok(ej && ej.t === "full", "5th player gets full");
  E.close(); D.close();
  await A.waitT("peer_left"); await B.waitT("peer_left"); await C.waitT("peer_left");
  // host reconnect inside the grace keeps the host role (same token), no ghost left behind
  A.kill();
  const pl = await B.waitT("peer_left", 2000);
  ok(pl && pl.id === aj.id, "guests see the host leave");
  const A2 = await new Client(url, "Ann").open();
  const a2 = await A2.join(room, { create: false, token: "tokA" });
  ok(a2 && a2.t === "joined" && a2.host === true && a2.peers.length === 2, "host reconnecting with its token inside the grace is host again");
  await sleep(GRACE + 400);
  ok(!B.inbox.some((m) => m.t === "you_are_host") && !C.inbox.some((m) => m.t === "you_are_host"), "no hand-over after the host came back");
  A2.send({ t: "all", d: { k: "back" } });
  const bk = await B.wait((m) => m.t === "msg" && m.d.k === "back");
  ok(bk && bk.host === true, "returned host's frames carry host:true");
  // host leaves for good: after the grace the oldest guest becomes host and can host_save
  A2.close();
  await B.waitT("peer_left", 2000);
  const yh = await B.waitT("you_are_host", GRACE + 2000);
  ok(!!yh, "after the grace the next guest gets you_are_host");
  B.send({ t: "host_save", d: { day: 4 } });
  B.send({ t: "all", d: { k: "new-host" } });
  const nh = await C.wait((m) => m.t === "msg" && m.d.k === "new-host");
  ok(nh && nh.host === true, "new host's frames carry host:true");
  const F = await new Client(url, "Fi").open();
  const fj = await F.join(room, { create: false, token: "tokF" });
  const fw = await F.waitT("world");
  ok(fj && fj.t === "joined" && fw && fw.d.day === 4, "a later joiner gets the new host's world");
  // guests leave first, then the host, alone: the room stays (empty TTL), there's no grace
  // (nobody was waiting on that host) and the next one in hosts it
  F.close(); C.close();
  await B.waitT("peer_left", 2000); await B.waitT("peer_left", 2000);
  B.close();
  await sleep(300);
  const G = await new Client(url, "Gu").open();
  const gj = await G.join(room, { create: false, token: "tokG" });
  ok(gj && gj.t === "joined" && gj.host === true, "someone joining an emptied room becomes its host");
  G.close();
}

(async () => {
  let srv = null;
  try {
    if (urlArg) {
      console.log("relay test (live subset) against " + urlArg);
      const ms = await liveSubset(urlArg);
      if (fails || ms < 0) { console.log("RELAY LIVE: FAIL (" + fails + " checks failed)"); process.exit(1); }
      console.log("RELAY LIVE: ok, " + ms + "ms");
      process.exit(0);
    }
    const port = await freePort();
    srv = spawn(process.execPath, [path.join(__dirname, "..", "server", "server.js")], {
      env: { ...process.env, PORT: String(port), MAX_PLAYERS: "4", HOST_GRACE_MS: String(GRACE), DREAMS_COMMIT: "" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let log = "";
    srv.stdout.on("data", (c) => (log += c)); srv.stderr.on("data", (c) => (log += c));
    for (let i = 0; i < 50 && !/dreams relay on/.test(log); i++) await sleep(100);
    if (!/dreams relay on/.test(log)) throw new Error("server did not start: " + log.slice(0, 300));
    console.log("relay test: server/server.js on port " + port);
    await localSuite("ws://127.0.0.1:" + port, "http://127.0.0.1:" + port);
    if (/Error|TypeError/.test(log)) { fails++; console.log("  FAIL server logged an error: " + log.slice(0, 300)); }
  } catch (e) {
    fails++;
    console.log("  FAIL " + (e && e.stack ? e.stack.split("\n").slice(0, 3).join(" | ") : e));
  } finally {
    if (srv) srv.kill();
  }
  console.log(fails ? "RELAY TEST FAIL: " + fails + " checks" : "RELAY TEST OK");
  process.exit(fails ? 1 : 0);
})();
