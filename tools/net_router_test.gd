extends SceneTree
## C17 P1: the message router (contract section 2) over NetTransportLoop:
## on_msg/off_msg, send_host (guest -> host, seq stamped), send_peer, broadcast
## (+include_self), host_id learned from joined, roster(), seq acks in world
## pushes, host_present()/host_away/host_back on a host drop and return, and
## local delivery while offline.
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(17)
	Campaign.bypass = true
	_run.call_deferred()


func _pump(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var bus := NetTransportLoop.Bus.new()
	var h := NetNode.new()
	root.add_child(h)
	# Offline: local delivery still works (solo games use the same code path).
	var solo := []
	h.on_msg("game_x", func(f: String, d: Dictionary) -> void: solo.append([f, d]))
	h.broadcast("game_x", {"v": 1}, true)
	check(solo.size() == 1 and str(solo[0][0]) == "local", "offline broadcast(include_self) delivers locally")
	check(h.host_present(), "solo: host_present")
	h._host = true
	h._pending_join = {"t": "join", "room": "", "token": "host", "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	h.tr = NetTransportLoop.new(bus)
	h.tr.open("", h._pending_join)
	await _pump(3)
	check(h.online() and h.is_host() and h._host_id == h.my_id, "host online, host id = itself")
	var g := NetNode.new()
	root.add_child(g)
	g._host = false
	g._pending_join = {"t": "join", "room": h.room, "create": false, "token": "g1", "name": "G", "look": {}, "arc": "gangsters", "proto": NetNode.PROTO}
	g.tr = NetTransportLoop.new(bus)
	g.tr.open("", g._pending_join)
	await _pump(4)
	check(g.online() and not g.is_host(), "guest online")
	check(g._host_id == h.my_id, "guest learned the host id from joined (%d)" % g._host_id)
	check(g.host_present(), "guest: host_present")
	var hp := []
	var gp := []
	var hcb := func(f: String, d: Dictionary) -> void: hp.append([f, d])
	var gcb := func(f: String, d: Dictionary) -> void: gp.append([f, d])
	h.on_msg("farm_op", hcb)
	g.on_msg("farm_op", gcb)
	h.on_msg("farm_op", hcb)  # double registration is ignored
	g.send_host("farm_op", {"op": "till", "key": "3,4"})
	await _pump(3)
	check(hp.size() == 1 and str(hp[0][0]) == str(g.my_id) and str(hp[0][1].get("op", "")) == "till", "send_host reached the host handler once, from the guest's peer id")
	check(int(hp[0][1].get("seq", 0)) == 1 if hp.size() > 0 else false, "send_host stamped seq 1")
	check(gp.is_empty(), "send_host did not echo to the sender")
	check(int(h._acks.get(str(g.my_id), 0)) == 1, "host recorded the guest's seq")
	h._push_world()
	await _pump(3)
	check(g.acked_seq() == 1, "world push carried _ack: guest acked_seq = 1")
	# Host -> one peer, and broadcast with include_self.
	h.send_peer(str(g.my_id), "farm_op", {"op": "ok"})
	await _pump(3)
	check(gp.size() == 1 and str(gp[0][0]) == str(h.my_id), "send_peer reached the guest from the host's peer id")
	h.broadcast("farm_op", {"op": "all"}, true)
	await _pump(3)
	check(gp.size() == 2 and hp.size() == 2, "broadcast(include_self) reached guest and host")
	# The host sends to itself via send_host: local, seq stamped.
	h.send_host("farm_op", {"op": "mine"})
	check(hp.size() == 3 and str(hp[2][0]) == str(h.my_id), "host's own send_host is delivered locally")
	# off_msg
	g.off_msg("farm_op", gcb)
	h.broadcast("farm_op", {"op": "gone"})
	await _pump(3)
	check(gp.size() == 2, "off_msg stops delivery")
	# A third peer: a host-only message (h flag) from a guest that doesn't know the host is ignored by guests.
	var g2 := NetNode.new()
	root.add_child(g2)
	g2._host = false
	g2._pending_join = {"t": "join", "room": h.room, "create": false, "token": "g2", "name": "G2", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	g2.tr = NetTransportLoop.new(bus)
	g2.tr.open("", g2._pending_join)
	await _pump(4)
	var g2p := []
	g2.on_msg("farm_op", func(f: String, d: Dictionary) -> void: g2p.append(d))
	g._host_id = -1
	g.send_host("farm_op", {"op": "flagged"})
	await _pump(3)
	check(hp.size() == 4 and g2p.is_empty(), "host-only frame: host handles it, other guests ignore it")
	g._host_id = h.my_id
	# Roster
	var r := g.roster()
	check(r.size() == 3 and bool(r[str(h.my_id)]["host"]) and bool(r[str(g.my_id)]["me"]) and str(r[str(h.my_id)]["arc"]) == "penguins", "roster: 3 players, host marked, me marked")
	# Ping
	for i in 200:
		await process_frame
	check(int(g.peers[h.my_id].get("ping_ms", -1)) >= 0, "ping_ms measured (%d)" % int(g.peers[h.my_id].get("ping_ms", -1)))
	# Host drop -> host_away; back -> host_back.
	var ev := []
	g.host_away.connect(func() -> void: ev.append("away"))
	g.host_back.connect(func() -> void: ev.append("back"))
	var pl := []
	g.peer_left.connect(func(p: String) -> void: pl.append(p))
	var hid := h.my_id
	(h.tr as NetTransportLoop).drop()
	h.tr = null
	h.my_id = -1
	await _pump(3)
	check(ev == ["away"] and not g.host_present(), "host dropped: host_away, host_present false")
	check(pl == [str(hid)], "peer_left(peer) signal with the host's id")
	h._pending_join = {"t": "join", "room": g.room, "create": false, "token": "host", "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	h.tr = NetTransportLoop.new(bus)
	h.tr.open("", h._pending_join)
	await _pump(4)
	check(h.is_host() and g._host_id == h.my_id, "host rejoined with its token, guest knows the new host id")
	check(ev == ["away", "back"] and g.host_present(), "host back: host_back, host_present true")
	g.queue_free()
	g2.queue_free()
	h.queue_free()
	await process_frame
	print("net_router_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
