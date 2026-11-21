extends SceneTree
## End-to-end co-op through a real relay (default: the live one, NetNode.DEFAULT_URL), two
## headless Godot processes driven by tools/net_e2e.sh:
##   godot --headless --path . -s res://tools/net_e2e_test.gd -- host  <url> <dir>
##   godot --headless --path . -s res://tools/net_e2e_test.gd -- guest <url> <dir>
## Host: new penguin save (day 7, 13:00), Net.host, farm; writes <dir>/code once its world
## snapshot is on the relay; then waits to see the guest's puppet walk to E2E_SPOT.
## Guest: 1) a raw late-join probe (its own WebSocketPeer) must get the relay's "world"
## snapshot (the host's host_save: day 7); 2) Net.join by code, gets the host's day/time,
## sees the host's puppet; 3) walks its player to E2E_SPOT; writes <dir>/guest_done.
## Real-time deadlines on purpose (network round trips; no --fixed-fps, which would flood
## the relay's 120 msg/s guard). Each side prints "ok"/"FAIL" lines and "NET E2E <role> OK|FAIL".
const E2E_SPOT := Vector2(212, 300)
var role := "host"
var url := ""
var dir := ""
var net: NetNode
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("  %s   %s: %s" % ["ok" if cond else "FAIL", role, what])


func _done() -> void:
	print("NET E2E %s %s" % [role, "OK" if fails == 0 else "FAIL (%d)" % fails])
	quit(0 if fails == 0 else 1)


func _wait_until(cond: Callable, ms: int) -> bool:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame
		if cond.call():
			return true
	return false


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(name: String) -> String:
	var p := dir.path_join(name)
	return FileAccess.get_file_as_string(p).strip_edges() if FileAccess.file_exists(p) else ""


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	url = args[1] if args.size() > 1 and args[1] != "" else NetNode.DEFAULT_URL
	dir = args[2] if args.size() > 2 else "/tmp/net_e2e"
	DirAccess.make_dir_recursive_absolute(dir)
	InputSetup.ensure_actions()
	net = root.get_node_or_null("NetSvc") as NetNode
	if net == null:
		net = NetNode.new()
		net.name = "NetSvc"
		root.add_child(net)
	var host := role == "host"
	GameState.new_run("penguins" if host else "gangsters", "kairi" if host else "dad", "Host" if host else "Guest", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	if host:
		await _host_side()
	else:
		await _guest_side()
	_done()


func _host_side() -> void:
	GameState.run["day"] = 7
	GameState.run["time"] = 13 * 60
	net.host(url)
	var on: bool = await _wait_until(func() -> bool: return net.online(), 20000)
	_ok(on and net.is_host() and net.room.length() == 4, "hosted room %s on %s" % [net.room, url])
	if not on:
		_write("code", "FAIL")
		return
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	# The first world push (within 2 s) is a full host_save: the relay keeps it for late joiners.
	await _wait_until(func() -> bool: return false, 3500)
	_write("code", net.room)
	var gid := [-1]
	var joined: bool = await _wait_until(func() -> bool:
		for id in net.peers:
			if str(net.peers[id].get("name", "")) == "Guest":
				gid[0] = int(id)
				return true
		return false, 60000)
	_ok(joined, "guest joined the room")
	if not joined:
		return
	var seen: bool = await _wait_until(func() -> bool:
		var m := current_scene as GameMap
		return m != null and not m._puppets.is_empty(), 20000)
	_ok(seen, "host sees the guest's puppet")
	var moved: bool = await _wait_until(func() -> bool:
		var pv: Variant = net.peers.get(gid[0], {}).get("pos", [])
		return pv is Array and (pv as Array).size() >= 2 and Vector2(float(pv[0]), float(pv[1])).distance_to(E2E_SPOT) < 1.0, 30000)
	var pv2: Variant = net.peers.get(gid[0], {}).get("pos", [])
	_ok(moved, "host sees the guest move to %s (last %s)" % [str(E2E_SPOT), str(pv2)])
	await _wait_until(func() -> bool: return _read("guest_done") != "", 30000)
	net.leave()
	await _wait_until(func() -> bool: return false, 300)


## A raw client (not NetNode) joins like a late joiner and must get the relay's "world".
func _probe_world(code: String) -> Dictionary:
	var ws := WebSocketPeer.new()
	ws.inbound_buffer_size = NetNode.BUFFER_BYTES
	if ws.connect_to_url(url) != OK:
		return {}
	var sent := false
	var out := {}
	var end := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < end and out.is_empty():
		await process_frame
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		if not sent:
			sent = true
			ws.send_text(JSON.stringify({"t": "join", "room": code, "create": false, "token": "e2e-probe-%d" % Time.get_ticks_usec(), "name": "Probe", "look": {}, "arc": "penguins"}))
		while ws.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if m is Dictionary and str(m.get("t", "")) == "world" and m.get("d") is Dictionary:
				out = m["d"]
	ws.close()
	for i in 10:
		await process_frame
		ws.poll()
	return out


func _guest_side() -> void:
	var code := ""
	var end := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < end and code == "":
		await process_frame
		code = _read("code")
	_ok(code.length() == 4, "got the room code (%s)" % code)
	if code.length() != 4:
		return
	var t0 := Time.get_ticks_msec()
	var w: Dictionary = await _probe_world(code)
	_ok(int(w.get("day", -1)) == 7 and w.has("farm"), "late joiner gets the host's world snapshot from the relay (day %s, %d ms)" % [str(w.get("day", "none")), Time.get_ticks_msec() - t0])
	net.join(url, code)
	var on: bool = await _wait_until(func() -> bool: return net.online(), 20000)
	_ok(on and not net.is_host() and net.room == code, "joined room %s by code" % code)
	if not on:
		_write("guest_done", "fail")
		return
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	var synced: bool = await _wait_until(func() -> bool: return int(GameState.run["day"]) == 7 and int(GameState.run["time"]) >= 13 * 60, 15000)
	_ok(synced, "guest runs on the host's day and clock (day %d, time %d)" % [int(GameState.run["day"]), int(GameState.run["time"])])
	var seen: bool = await _wait_until(func() -> bool:
		var m := current_scene as GameMap
		return m != null and m.player != null and not m._puppets.is_empty(), 20000)
	_ok(seen, "guest sees the host's puppet")
	var m2 := current_scene as GameMap
	if m2 and m2.player:
		m2.player.position = E2E_SPOT
	# keep it there while the host looks (the player may be nudged by collisions)
	await _wait_until(func() -> bool:
		var m3 := current_scene as GameMap
		if m3 and m3.player:
			m3.player.position = E2E_SPOT
		return false, 4000)
	_write("guest_done", "ok")
	net.leave()
	await _wait_until(func() -> bool: return false, 300)
