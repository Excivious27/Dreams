extends SceneTree
## C17 P1 net core over NetTransportLoop (game time, --fixed-fps 60):
## push coalescing (20 guest acts -> few world frames, no per-act host_save), world seq
## gap -> resync, act validation, empty-code join refused, host bye -> every guest home at
## once, host drop + grace -> all guests home together, guest drop 20 s -> rejoins the same
## room, host reconnect -> full world to guests, no_room during a reconnect -> retry.
var fails := 0
var checks := 0
var bus: NetTransportLoop.Bus
var frames := {}  # NetNode -> [frames sent]


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(1717)
	Campaign.bypass = true
	_run.call_deferred()


func _wait(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		await process_frame
		gt += root.get_process_delta_time()


func _host(tok: String) -> NetNode:
	var h := NetNode.new()
	root.add_child(h)
	h._host = true
	h._token = tok
	h._pending_join = {"t": "join", "room": "", "token": tok, "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	h.tr = NetTransportLoop.new(bus)
	h.tr.open("", h._pending_join)
	return h


func _guest(code: String, tok: String) -> NetNode:
	var g := NetNode.new()
	root.add_child(g)
	g._host = false
	g._token = tok
	g._pending_join = {"t": "join", "room": code, "create": false, "token": tok, "name": "G" + tok, "look": {}, "arc": "gangsters", "proto": NetNode.PROTO}
	g.tr = NetTransportLoop.new(bus)
	g.tr.open("", g._pending_join)
	return g


## Wrap a NetNode's transport so the test can count what it sends.
class Spy:
	extends NetTransportLoop
	var sent: Array = []
	func send(frame: Dictionary) -> void:
		sent.append(frame)
		super.send(frame)


class Flaky:
	extends NetTransportLoop
	var down := false
	func reopen() -> bool:
		if down:
			return false
		return super.reopen()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	bus = NetTransportLoop.Bus.new()
	# Validation
	check(NetNode.valid_act({"a": "farm_tile", "key": "3,4", "tile": {"t": "tilled"}}), "valid farm_tile passes")
	check(not NetNode.valid_act({"a": "farm_tile", "key": "evil", "tile": {}}), "farm_tile with a junk key refused")
	check(not NetNode.valid_act({"a": "farm_tile", "key": "3,4", "tile": {"x": "a".repeat(2000)}}), "huge farm tile refused")
	check(not NetNode.valid_act({"a": "permit", "id": "nope_build", "tier": 99}), "permit for an unknown build / tier refused")
	check(not NetNode.valid_act({"a": "cleared", "scene": "../../x", "key": "k"}), "cleared with a junk scene refused")
	check(NetNode.valid_act({"a": "farm_tiles", "tiles": {"1,1": {"t": "tilled"}, "2,2": null}}) and not NetNode.valid_act({"a": "farm_tiles", "tiles": {"x": {}}}), "farm_tiles batch checked tile by tile")
	# Decor piece keys survive the JSON round trip; the house look rides in deltas.
	var pc := {"id": "lamp", "cell": [3, 4], "rot": 1}
	var back: Dictionary = JSON.parse_string(JSON.stringify({"cell": [3, 4], "rot": 1, "id": "lamp"}))
	check(NetNode._piece_key(pc) == NetNode._piece_key(back), "piece key equal after JSON (ints -> floats, key order)")
	var dd := NetNode.world_delta({"decor_home": {"placed": {}, "wall": {}, "floor": {}, "house": "a"}}, {"decor_home": {"placed": {}, "wall": {}, "floor": {}, "house": "b"}})
	var run := {"decor_home": {"placed": {}, "wall": {}, "floor": {}, "house": "a"}}
	NetNode.merge_delta(run, dd)
	check(str(run["decor_home"].get("house", "")) == "b", "decor_home 'house' reaches guests in a delta")
	check(NetNode._toast_ok("Host: Coop built.") and not NetNode._toast_ok("Host: shit"), "host toast filter")
	# Empty code join
	var e := NetNode.new()
	root.add_child(e)
	var why := [""]
	e.disconnected.connect(func(w: String) -> void: why[0] = w)
	e.join("", "   ")
	check(e.tr == null and why[0].contains("code"), "empty code: nothing hosted, words shown (%s)" % why[0])
	e.queue_free()

	# Coalescing
	var h := NetNode.new()
	root.add_child(h)
	h._host = true
	h._pending_join = {"t": "join", "room": "", "token": "ch", "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	var spy := Spy.new(bus)
	h.tr = spy
	spy.open("", h._pending_join)
	await _wait(0.2)
	var g := _guest(h.room, "cg")
	await _wait(0.5)
	check(g.online() and h.peers.size() == 1, "guest joined the host")
	spy.sent.clear()
	for i in 20:
		g.send_host({"k": "act", "a": "farm_tile", "key": "%d,5" % i, "tile": {"t": "tilled"}})
		await _wait(1.0 / 20.0)
	await _wait(0.4)
	var worlds := spy.sent.filter(func(f: Dictionary) -> bool: return str(f.get("t", "")) == "all" and str((f.get("d", {}) as Dictionary).get("k", "")) == "world")
	var saves := spy.sent.filter(func(f: Dictionary) -> bool: return str(f.get("t", "")) == "host_save")
	check(worlds.size() >= 2 and worlds.size() <= 8, "20 guest acts in 1 s -> %d world frames (coalesced)" % worlds.size())
	check(saves.size() <= 1, "no host_save per act (%d)" % saves.size())
	check((GameState.run["farm"] as Dictionary).has("19,5"), "every act applied on the host")
	g.send_host({"k": "act", "a": "farm_tiles", "tiles": {"40,5": {"t": "tilled"}, "41,5": {"t": "tilled"}, "19,5": null}})
	await _wait(0.3)
	check((GameState.run["farm"] as Dictionary).has("41,5") and not (GameState.run["farm"] as Dictionary).has("19,5"), "farm_tiles: one act, many tiles applied")
	check(g.acked_seq() >= 15, "guest got acks (%d)" % g.acked_seq())
	# Seq gap -> resync request
	spy.sent.clear()
	var before := g._wseen
	g._take_seq({"_delta": true, "_s": before + 5})
	await _wait(0.3)
	var full := spy.sent.filter(func(f: Dictionary) -> bool: return str(f.get("t", "")) == "to" and int(f.get("id", -1)) == g.my_id and not bool(((f["d"] as Dictionary)["d"] as Dictionary).get("_delta", false)))
	check(full.size() == 1, "a world seq gap -> guest asked -> host sent it a full world")
	check(not g._take_seq({"_delta": true, "_s": 1}), "an old delta is skipped")

	# Host bye -> every guest home at once
	var g2 := _guest(h.room, "cg2")
	var g3 := _guest(h.room, "cg3")
	await _wait(0.5)
	var homes := [0]
	for n: NetNode in [g, g2, g3]:
		n.went_home.connect(func() -> void: homes[0] += 1)
	check(g.visiting() and g2.visiting() and g3.visiting(), "3 guests visiting")
	h.leave()
	await _wait(0.3)
	check(homes[0] == 3 and not g.online() and not g3.online(), "host's bye: all 3 guests home at once (%d)" % homes[0])
	h.queue_free()
	for n: NetNode in [g, g2, g3]:
		n.queue_free()
	await _wait(0.1)

	# Host lost: grace, then all guests together
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var h2 := _host("h2")
	await _wait(0.2)
	var k1 := _guest(h2.room, "k1")
	var k2 := _guest(h2.room, "k2")
	await _wait(0.5)
	var away := [0]
	k1.host_away.connect(func() -> void: away[0] += 1)
	var kh := [0]
	for n: NetNode in [k1, k2]:
		n.went_home.connect(func() -> void: kh[0] += 1)
	var code2 := h2.room
	(h2.tr as NetTransportLoop).drop()
	h2._last_room = ""
	h2.tr = null
	h2.my_id = -1
	await _wait(0.3)
	check(away[0] == 1 and not k1.host_present() and kh[0] == 0, "host dropped: guests hold (host_away), still in the room")
	(bus.rooms[code2] as NetRelayRoom).tick(NetTransport.HOST_GRACE)
	await _wait(0.3)
	check(kh[0] == 2, "grace over: both guests home together (%d)" % kh[0])
	for n: NetNode in [h2, k1, k2]:
		n.queue_free()
	await _wait(0.1)

	# Guest drop 20 s -> rejoins the same room; host reconnect -> full world to guests
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var h3 := _host("h3")
	await _wait(0.2)
	var r1 := NetNode.new()
	root.add_child(r1)
	r1._host = false
	r1._token = "r1"
	r1._pending_join = {"t": "join", "room": h3.room, "create": false, "token": "r1", "name": "R", "look": {}, "arc": "gangsters", "proto": NetNode.PROTO}
	var fl := Flaky.new(bus)
	r1.tr = fl
	fl.open("", r1._pending_join)
	await _wait(0.5)
	var code3 := h3.room
	fl.down = true
	fl.drop()
	await _wait(0.1)
	check(r1.tr == null and r1.visiting() and r1._retry_t > 0.0, "guest drop: reconnecting, still visiting")
	await _wait(20.0)
	check(r1.tr == null and r1.visiting() and r1._retries < NetNode.MAX_RETRIES, "20 s without signal: still trying (%d tries)" % r1._retries)
	fl.down = false
	await _wait(12.0)
	check(r1.online() and r1.room == code3 and r1.visiting(), "signal back: the guest is in the same room again (%s)" % r1.room)
	# host reconnect
	var hspy := Spy.new(bus)
	(h3.tr as NetTransportLoop).drop()
	await _wait(0.05)
	h3._last_tr = hspy
	await _wait(2.5)
	check(h3.online() and h3.is_host(), "host back in its room after a drop")
	var fw := hspy.sent.filter(func(f: Dictionary) -> bool: return str(f.get("t", "")) == "all" and str((f.get("d", {}) as Dictionary).get("k", "")) == "world" and not bool(((f["d"] as Dictionary)["d"] as Dictionary).get("_delta", false)))
	check(fw.size() == 1, "host rejoin: one full world to everyone")
	await _wait(0.3)
	check(r1.host_present(), "guest sees the host back")
	for n: NetNode in [h3, r1]:
		n.queue_free()
	await _wait(0.1)
	print("net_c17_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
