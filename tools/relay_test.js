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
  async join(room, extra = {}) { this.send({ t: "join", room, name: this.name, look: {}, arc: "penguins", ...extra }); return this.wait((m) => ["joined", "no_room", "full", "old_build"].includes(m.t), 8000); }
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
  const ob = await new Client(url, "v").open().then((x) => x.join(room, { create: false, proto: 99 }).then((m) => { x.close(); return m; }));
  ok(ob && ob.t === "old_build" && ob.need === 0, "a joiner on another protocol gets old_build");
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


// C17 (proto 2 rooms): host bye ends the room at once for every guest; a host lost for good
// ends it for everyone when the grace runs out (not one guest per grace); host peer_left is
// marked; ping/pong; one join per socket; refused joins keep the host; failed-join limit;
// byte budget answers slow; a relay restart: the host recreates its code, the guest rejoins.
async function c17Suite(url) {
  const P = { proto: 2 };
  const H = await new Client(url, "H2").open();
  const hj = await H.join("", { ...P, token: "c17h" });
  ok(hj && hj.host === true && hj.host_id === hj.id, "proto 2 host creates a room, joined carries host_id");
  const room = hj.room;
  const gs = [];
  for (let i = 0; i < 3; i++) { const g = await new Client(url, "G" + i).open(); const j = await g.join(room, { ...P, create: false, token: "c17g" + i }); gs.push(g); ok(j && j.host === false && j.host_id === hj.id && j.peers.some((p) => p.id === hj.id && p.host === true), "guest " + i + " joined, sees the host marked"); }
  const pj = await gs[0].wait((m) => m.t === "peer_joined" && m.peer.name === "G1");
  ok(pj && pj.peer.host === false, "peer_joined carries host:false for a guest");
  H.send({ t: "ping", s: 42 });
  const po = await H.waitT("pong");
  ok(po && po.s === 42, "ping -> pong");
  H.send({ t: "join", room: "", name: "again", proto: 2 });
  ok(!(await H.wait((m) => m.t === "joined", 400)), "a second join on one socket is ignored (no ghost)");
  const O = await new Client(url, "Old").open();
  const oj = await O.join(room, { proto: 1, create: false, token: "c17old" });
  ok(oj && oj.t === "old_build", "other proto refused");
  H.send({ t: "all", d: { k: "still-host" } });
  const sh = await gs[1].wait((m) => m.t === "msg" && m.d.k === "still-host");
  ok(sh && sh.host === true, "a refused join did not take the host role");
  O.close();
  const t0 = Date.now();
  H.send({ t: "bye" });
  const ends = await Promise.all(gs.map((g) => g.waitT("host_left", 1000)));
  ok(ends.every((e) => !!e) && Date.now() - t0 < 1000, "host bye: all 3 guests get host_left at once (" + (Date.now() - t0) + " ms)");
  const X = await new Client(url, "X").open();
  const xj = await X.join(room, { ...P, create: false, token: "c17x" });
  ok(xj && xj.t === "no_room", "the room is gone after the host's bye");
  for (const g of gs) g.close(); H.close(); X.close();
  // Host lost for good: everyone is released together when the grace ends.
  const H2 = await new Client(url, "H3").open();
  const h2 = await H2.join("", { ...P, token: "c17h3" });
  const g2 = [];
  for (let i = 0; i < 3; i++) { const g = await new Client(url, "K" + i).open(); await g.join(h2.room, { ...P, create: false, token: "c17k" + i }); g2.push(g); }
  await sleep(200);
  H2.kill();
  const pl = await g2[0].waitT("peer_left", 2000);
  ok(pl && pl.host === true && pl.grace === GRACE, "host drop: peer_left marked host:true with the grace");
  const t1 = Date.now();
  const e2 = await Promise.all(g2.map((g) => g.waitT("host_left", GRACE + 1500)));
  ok(e2.every((e) => !!e) && Date.now() - t1 < GRACE + 1200, "grace over: all 3 guests get host_left together (" + (Date.now() - t1) + " ms)");
  ok(!g2.some((g) => g.inbox.some((m) => m.t === "you_are_host")), "nobody gets you_are_host in a proto 2 room");
  for (const g of g2) g.close();
  // A guest's bye: peer_left bye:true, the room goes on.
  const H4 = await new Client(url, "H4").open();
  const h4 = await H4.join("", { ...P, token: "c17h4" });
  const G4 = await new Client(url, "G4").open();
  await G4.join(h4.room, { ...P, create: false, token: "c17g4" });
  await H4.waitT("peer_joined");
  G4.send({ t: "bye" });
  const bl = await H4.waitT("peer_left", 1000);
  ok(bl && bl.bye === true, "guest bye: host sees peer_left bye:true");
  G4.close();
  // Byte budget: > 256 KB/s from a guest answers slow.
  const G5 = await new Client(url, "G5").open();
  await G5.join(h4.room, { ...P, create: false, token: "c17g5" });
  for (let i = 0; i < 6; i++) G5.send({ t: "all", d: { k: "fat", pad: "x".repeat(60000) } });
  ok(!!(await G5.waitT("slow", 1500)), "guest over the byte budget gets slow");
  G5.close(); H4.close();
  // Failed joins per IP are limited (code sweeps).
  const S = await new Client(url, "Sweep").open();
  let slow = false;
  for (let i = 0; i < 25 && !slow; i++) { const r = await S.join("Q" + i + "ZZ", { create: false, token: "sw" }); if (!r || S.inbox.some((m) => m.t === "slow")) slow = true; }
  ok(slow || S.closed, "a code sweep from one IP gets slowed down after 20 misses");
  S.close();
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
    await c17Suite("ws://127.0.0.1:" + port);
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
