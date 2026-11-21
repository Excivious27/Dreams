extends SceneTree
## S1 P4: NetNode over NetTransportLoop (the in-memory relay twin, NetRelayRoom =
## server.js rules): join, peer_joined + world push, state ticks, scene, no_room,
## host gone -> you_are_host after the grace -> a visiting guest goes home.
var fails := 0
var checks := 0
var got := {}


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(4)
	Campaign.bypass = true
	_run.call_deferred()


func _pump(n: int, raws: Array) -> void:
	for i in n:
		for t: NetTransport in raws:
			t.poll(1.0 / 60.0)
			if not got.has(t):
				got[t] = []
			(got[t] as Array).append_array(t.take())
		await process_frame


func _has(t: NetTransport, kind: String) -> Array:
	var out: Array = []
	for m: Dictionary in got.get(t, []):
		if str(m.get("t", "")) == kind:
			out.append(m)
	return out


func _join_frame(room: String, tok: String, arc := "penguins") -> Dictionary:
	return {"t": "join", "room": room, "create": false, "token": tok, "name": "G" + tok, "look": {}, "arc": arc, "proto": NetNode.PROTO}


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var bus := NetTransportLoop.Bus.new()
	var h := NetNode.new()
	root.add_child(h)
	h._host = true
	h._pending_join = {"t": "join", "room": "", "token": "host", "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	h.tr = NetTransportLoop.new(bus)
	h.tr.open("", h._pending_join)
	await _pump(3, [])
	check(h.online() and h.is_host() and h.my_id > 0, "host joined its own room as host (id %d)" % h.my_id)
	check(h.room != "", "room code set (%s)" % h.room)
	var g := NetTransportLoop.new(bus)
	g.open("", {})
	g.send(_join_frame(h.room, "g1", "gangsters"))
	await _pump(4, [g])
	var j := _has(g, "joined")
	check(j.size() == 1 and not bool(j[0]["host"]) and (j[0]["peers"] as Array).size() == 1, "guest joined as a guest, sees the host")
	check(h.peers.has(int(g.id)), "host got peer_joined")
	check(h._arc_mismatch, "other-arc guest flagged on the host")
	var w := _has(g, "msg").filter(func(m: Dictionary) -> bool: return str(m["d"].get("k", "")) == "world")
	check(w.size() >= 1 and bool(w[0]["host"]) and int(w[0]["from"]) == h.my_id, "host pushed the full world to the newcomer, stamped host")
	check(w.size() >= 1 and int(w[0]["d"]["d"].get("day", -1)) == int(GameState.run["day"]), "world frame carries the host's day")
	g.send({"t": "all", "d": {"k": "state", "pos": [5, 6], "scene": "town", "anim": "walk", "flip": true}})
	g.send({"t": "scene", "scene": "town"})
	await _pump(3, [g])
	check(h.peers.has(int(g.id)) and int(h.peers[g.id]["pos"][0]) == 5 and str(h.peers[g.id]["scene"]) == "town", "guest state tick + scene reached the host")
	h.send_all({"k": "toast", "text": "hi"})
	await _pump(2, [g])
	var st := _has(g, "msg").filter(func(m: Dictionary) -> bool: return str(m["d"].get("k", "")) == "toast")
	check(st.size() == 1 and bool(st[0]["host"]), "host send_all reaches the guest stamped host")
	# A guest can't pass for the host: its world frames are stamped host:false.
	var g2 := NetTransportLoop.new(bus)
	g2.open("", {})
	g2.send(_join_frame(h.room, "g2"))
	await _pump(3, [g, g2])
	g.send({"t": "all", "d": {"k": "world", "d": {"day": 999}}})
	await _pump(2, [g, g2])
	var fake := _has(g2, "msg").filter(func(m: Dictionary) -> bool: return int(m["from"]) == g.id and str(m["d"].get("k", "")) == "world")
	check(fake.size() == 1 and not bool(fake[0]["host"]), "guest world frame fanned out with host:false")
	check(int(GameState.run["day"]) != 999, "host ignored the guest's world")
	# Guards like server.js: 70 KB guest frame dropped; >120 msgs/s cut.
	var before := _has(g2, "msg").size()
	g.send({"t": "all", "d": {"k": "noise", "x": "a".repeat(70 * 1024)}})
	await _pump(1, [g, g2])
	check(_has(g2, "msg").size() == before, "70 KB guest frame dropped")
	bus.rooms[h.room].budget[g.id] = NetTransport.RATE_PER_SEC
	for i in 200:
		g.send({"t": "all", "d": {"k": "spam", "i": i}})
	await _pump(1, [g, g2])
	var spam := _has(g2, "msg").filter(func(m: Dictionary) -> bool: return str(m["d"].get("k", "")) == "spam")
	check(spam.size() <= NetTransport.RATE_PER_SEC and spam.size() >= 100, "flood guard: %d of 200 forwarded" % spam.size())
	# no_room
	var g3 := NetTransportLoop.new(bus)
	g3.open("", {})
	g3.send(_join_frame("ZZZZ", "g3"))
	await _pump(1, [g3])
	check(_has(g3, "no_room").size() == 1, "unknown code -> no_room")
	# peer_left
	g2.close()
	await _pump(2, [g])
	check(_has(g, "peer_left").size() == 1, "peer_left on close")
	h.leave()
	g.close()
	await _pump(1, [])
	# A visiting guest NetNode: the host drops, 30 s grace, you_are_host -> home.
	var hx := NetTransportLoop.new(bus)
	hx.open("", {})
	hx.send({"t": "join", "room": "", "token": "hx", "name": "HX", "look": {}, "arc": "penguins", "proto": NetNode.PROTO})
	await _pump(1, [hx])
	var code := str(_has(hx, "joined")[0]["room"])
	GameState.run["day"] = 3
	var n2 := NetNode.new()
	root.add_child(n2)
	var home := [false]
	n2.went_home.connect(func() -> void: home[0] = true)
	n2._host = false
	n2._pending_join = _join_frame(code, "n2")
	n2.tr = NetTransportLoop.new(bus)
	n2.tr.open("", n2._pending_join)
	await _pump(3, [hx])
	check(n2.online() and not n2.is_host() and not n2._solo_backup.is_empty(), "guest NetNode visiting over the loop")
	hx.drop()
	bus.rooms[code].tick(10.0)
	await _pump(2, [])
	check(n2.online() and not home[0], "host gone 10 s: guest still waiting (grace)")
	bus.rooms[code].tick(21.0)
	await _pump(3, [])
	check(home[0] and not n2.online(), "host gone 31 s: you_are_host -> guest went home")
	check(int(GameState.run["day"]) == 3, "guest's own day restored")
	n2.queue_free()
	h.queue_free()
	await process_frame
	print("net_transport_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
