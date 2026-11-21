extends SceneTree
## S1 P4: Steam co-op over FakeSteam (tools/fake_steam.gd), no Steam client needed.
## Host NetNode on a friends-only lobby; raw NetTransportSteam guests. Join,
## world push, unreliable state ticks, host stamping, guest guards, zstd +
## chunking of a 1.5 MB world, strangers refused, lobby full, old build,
## rich presence, paused tree, owner gone -> visiting guest goes home.
var fails := 0
var checks := 0
var got := {}
const SID := 76561190000000000


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(9)
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


func _has(t: NetTransport, kind: String, k := "") -> Array:
	var out: Array = []
	for m: Dictionary in got.get(t, []):
		if str(m.get("t", "")) == kind and (k == "" or (m.get("d") is Dictionary and str(m["d"].get("k", "")) == k)):
			out.append(m)
	return out


func _guest(fs: FakeSteam, n: int, lobby: int, proto := NetNode.PROTO) -> NetTransportSteam:
	var t := NetTransportSteam.new(fs.user(SID + n))
	t.open(str(lobby), {"proto": proto})
	if t.is_open():
		t.send({"t": "join", "room": "", "create": false, "token": "x%d" % n, "name": "G%d" % n, "look": {}, "arc": "penguins", "proto": proto})
	return t


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var fs := FakeSteam.new()
	var a := fs.user(SID + 1)
	var h := NetNode.new()
	root.add_child(h)
	h.steam_backend = a
	check(h.steam_ready(), "steam_ready with a backend")
	check(h.host_steam(), "host_steam started")
	await _pump(3, [])
	var lobby := int((h.tr as NetTransportSteam).lobby_id)
	check(h.online() and h.is_host() and h.my_id == 1, "host owns a lobby and is host id 1")
	check(h.room.length() == 4, "4-char room code for status text (%s)" % h.room)
	check(a.getLobbyData(lobby, "dreams") == "1" and a.getLobbyData(lobby, "proto") == str(NetNode.PROTO), "lobby data dreams=1 + proto")
	check(a.presence.get("steam_display", "") == "#Status_Coop" and a.presence.get("steam_player_group", "") == str(lobby), "rich presence: co-op status grouped by lobby")
	var g := _guest(fs, 2, lobby)
	await _pump(4, [g])
	var j := _has(g, "joined")
	check(j.size() == 1 and not bool(j[0]["host"]) and int(j[0]["id"]) == 2, "guest joined as id 2, not host")
	check(h.peers.has(2), "host got peer_joined")
	var w := _has(g, "msg", "world")
	check(w.size() >= 1 and bool(w[0]["host"]) and int(w[0]["from"]) == 1, "host pushed the world to the newcomer, stamped host")
	var sent0: int = fs.user(SID + 2).sent
	g.send({"t": "all", "d": {"k": "state", "pos": [7, 8], "scene": "farm", "anim": "walk", "flip": false}})
	await _pump(2, [g])
	check(h.peers.has(2) and int(h.peers[2]["pos"][0]) == 7, "guest state tick reached the host")
	check(fs.user(SID + 2).sent == sent0 + 1 and (fs.users[SID + 1].queue[1] as Array).is_empty(), "state tick went on the fast channel and was read")
	# Second guest: guest frames can't claim host; guards.
	var c := _guest(fs, 3, lobby)
	await _pump(3, [g, c])
	check(h.peers.size() == 2, "two guests in the room")
	g.send({"t": "all", "d": {"k": "world", "d": {"day": 999}}})
	await _pump(2, [g, c])
	var fake := _has(c, "msg", "world").filter(func(m: Dictionary) -> bool: return int(m["from"]) == 2)
	check(fake.size() == 1 and not bool(fake[0]["host"]), "guest world fanned out with host:false")
	check(int(GameState.run["day"]) != 999, "host ignored it")
	var before := _has(c, "msg").size()
	g.send({"t": "all", "d": {"k": "noise", "x": "a".repeat(70 * 1024)}})
	await _pump(2, [g, c])
	check(_has(c, "msg").size() == before, "70 KB guest frame dropped by the owner")
	(h.tr as NetTransportSteam).room.budget[2] = NetTransport.RATE_PER_SEC
	for i in 200:
		g.send({"t": "all", "d": {"k": "spam", "i": i, "look": {}}})
	await _pump(2, [g, c])
	var spam := _has(c, "msg", "spam")
	check(spam.size() <= NetTransport.RATE_PER_SEC and spam.size() >= 100, "owner flood guard: %d of 200 forwarded" % spam.size())
	# Big world: compressed, chunked, reassembled.
	var big := {}
	for i in 30000:
		big["%d,%d" % [i % 200, i / 200]] = {"crop": "c%x" % randi(), "days": randi() % 9, "w": randi()}
	var pk := NetTransportSteam.encode({"t": "msg", "d": {"k": "world", "d": {"farm": big}}}, 1)
	var raw_size := JSON.stringify({"farm": big}).length()
	h._send({"t": "to", "id": 2, "d": {"k": "world", "d": {"farm": big}}})
	await _pump(3, [g])
	var bw := _has(g, "msg", "world").filter(func(m: Dictionary) -> bool: return (m["d"]["d"] as Dictionary).has("farm") and (m["d"]["d"]["farm"] as Dictionary).size() == big.size())
	check(raw_size > 1000000, "synthetic world is %d KB of JSON" % (raw_size / 1024))
	check(bw.size() == 1, "%d KB world arrived intact (%d packet(s))" % [raw_size / 1024, pk.size()])
	var huge := PackedByteArray()
	for i in 1200 * 1024:
		huge.append(randi() % 256)
	var hp := NetTransportSteam.encode({"t": "msg", "d": {"k": "blob", "b": Marshalls.raw_to_base64(huge)}}, 2)
	check(hp.size() >= 3, "incompressible 1.6 MB frame split into %d chunks under 512 KB" % hp.size())
	check(hp.all(func(p: PackedByteArray) -> bool: return p.size() <= 512 * 1024), "every packet under Steam's 512 KB cap")
	h._send({"t": "to", "id": 2, "d": {"k": "blob", "b": Marshalls.raw_to_base64(huge)}})
	await _pump(3, [g])
	var bl := _has(g, "msg", "blob")
	check(bl.size() == 1 and Marshalls.base64_to_raw(str(bl[0]["d"]["b"])) == huge, "chunked blob reassembled byte for byte")
	# Paused tree: co-op keeps going (NetNode is PROCESS_MODE_ALWAYS).
	await _pump(70, [g])  # a second passes: the owner's msg budget refills after the flood
	paused = true
	g.send({"t": "all", "d": {"k": "state", "pos": [11, 12], "scene": "farm", "anim": "idle", "flip": false}})
	for i in 300:
		await _pump(1, [g])
	paused = false
	check(int(h.peers[2]["pos"][0]) == 11 and h.online(), "5 s paused: guest tick still reached the host")
	# A stranger (not in the lobby) is never accepted.
	var s := fs.user(SID + 99)
	s.sendMessageToUser(SID + 1, NetTransportSteam.encode({"t": "join", "proto": NetNode.PROTO, "name": "S"})[0], 9, 0)
	await _pump(2, [])
	check(not a.accepted.has(SID + 99) and h.peers.size() == 2, "stranger's session refused")
	# Old build refused.
	var o := _guest(fs, 4, lobby, 0)
	await _pump(3, [o])
	check(_has(o, "old_build").size() >= 1 and h.peers.size() == 2, "old build gets old_build, not a seat")
	o.close()
	# Lobby full at 8.
	var more: Array = []
	for n in range(5, 10):
		more.append(_guest(fs, n, lobby))
	await _pump(3, more)
	check(h.peers.size() == 7, "8 players in the lobby (%d peers)" % h.peers.size())
	var ninth := _guest(fs, 20, lobby)
	await _pump(2, [ninth])
	check(_has(ninth, "full").size() == 1, "9th joiner told the room is full")
	check(a.presence.get("steam_player_group_size", "") == "8", "presence group size follows the lobby")
	for t: NetTransportSteam in more:
		t.close()
	g.close()
	c.close()
	await _pump(3, [])
	check(h.peers.is_empty(), "guests leaving -> peer_left for each")
	h.leave()
	check(a.presence.is_empty(), "rich presence cleared on leave")
	# Visiting guest NetNode: owner leaves -> 30 s grace -> home.
	var hx := NetTransportSteam.new(fs.user(SID + 50))
	hx.open("", {"proto": NetNode.PROTO})
	hx.send({"t": "join", "room": "", "token": "hx", "name": "HX", "look": {}, "arc": "penguins", "proto": NetNode.PROTO})
	await _pump(1, [hx])
	GameState.run["day"] = 4
	var n2 := NetNode.new()
	root.add_child(n2)
	n2.steam_backend = fs.user(SID + 51)
	var home := [false]
	n2.went_home.connect(func() -> void: home[0] = true)
	check(n2.join_steam(hx.lobby_id), "join_steam")
	await _pump(4, [hx])
	check(n2.online() and not n2.is_host() and not n2._solo_backup.is_empty(), "guest NetNode visiting over Steam")
	hx.close()
	await _pump(2, [])
	n2.tr.poll(10.0)
	await _pump(2, [])
	check(not home[0], "owner gone 10 s: still in the grace")
	n2.tr.poll(21.0)
	await _pump(3, [])
	check(home[0] and int(GameState.run["day"]) == 4, "owner gone 31 s: guest went home to its own day")
	n2.queue_free()
	# Invites: "+connect_lobby <id>" at launch, join_requested in game -> asked on the farm.
	check(NetNode.lobby_from_args(PackedStringArray(["--x", "+connect_lobby", "1097752410000001"])) == 1097752410000001, "+connect_lobby <id> parsed")
	check(NetNode.lobby_from_args(PackedStringArray(["+connect_lobby=42"])) == 42 and NetNode.lobby_from_args(PackedStringArray(["--y"])) == 0, "+connect_lobby=<id> parsed, none = 0")
	var hy := NetTransportSteam.new(fs.user(SID + 60))
	hy.open("", {"proto": NetNode.PROTO})
	hy.send({"t": "join", "room": "", "token": "hy", "name": "HY", "look": {}, "arc": "penguins", "proto": NetNode.PROTO})
	await _pump(1, [hy])
	var n3 := NetNode.new()
	root.add_child(n3)
	n3.steam_backend = fs.user(SID + 61)
	n3.on_join_requested(hy.lobby_id, "Rook")
	await _pump(5, [hy])
	check(n3.pending_lobby == hy.lobby_id and not n3.online(), "invite waits while no farm map is up (title)")
	change_scene_to_file("res://scenes/farm.tscn")
	var asked := false
	var d := Dialogue.instance(self)
	for i in 240:
		await _pump(1, [hy])
		if d.active and d._in_choice:
			asked = true
			d._choose("", 0)
			break
	check(asked, "on the farm the invite asks first (Visit / Not now)")
	await _pump(6, [hy])
	check(n3.online() and not n3.is_host() and n3.pending_lobby == 0, "Visit joined the friend's lobby")
	n3.leave()
	hy.close()
	n3.queue_free()
	h.queue_free()
	await process_frame
	fs.free_all()
	print("net_steam_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
