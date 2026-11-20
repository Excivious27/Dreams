extends SceneTree
## Two-process multiplayer smoke: run with `-- host` then `-- guest CODE`.
## Host: creates a room, prints the code, waits for a guest, checks puppet appears.
## Guest: joins, checks it received the host's world (day/time) and sees a puppet.
var role := "host"
var code := ""
var net: NetNode


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	code = args[1] if args.size() > 1 else ""
	InputSetup.ensure_actions()
	net = root.get_node_or_null("NetSvc") as NetNode
	if net == null:
		net = NetNode.new()
		net.name = "NetSvc"
		root.add_child(net)
	GameState.new_run("penguins" if role == "host" else "gangsters", "kairi" if role == "host" else "dad", "Host" if role == "host" else "Guest", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	if role == "host":
		GameState.run["day"] = 7
		GameState.run["time"] = 13 * 60
		net.host("ws://127.0.0.1:8787")
	else:
		net.join("ws://127.0.0.1:8787", code)
	var ok := false
	for i in 600:
		await process_frame
		if net.online():
			ok = true
			break
	print("  %s   %s connected (room %s, host=%s)" % ["ok" if ok else "FAIL", role, net.room, str(net.is_host())])
	if not ok:
		quit(1)
		return
	if role == "host":
		print("ROOM " + net.room)
		var f := FileAccess.open("/tmp/room_code.txt", FileAccess.WRITE)
		f.store_string(net.room)
		f.close()
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	# wait for the other side
	var seen := false
	var synced := false
	for i in 1500:
		await process_frame
		var m := current_scene as GameMap
		if m and not m._puppets.is_empty():
			seen = true
		if i % 300 == 0 and m:
			m._sync_puppets()
			print("    after manual sync puppets=%d" % m._puppets.size())
		if role == "guest" and int(GameState.run["day"]) == 7 and int(GameState.run["time"]) >= 13 * 60:
			synced = true
		if seen and (role == "host" or synced):
			break
	print("  %s   %s sees a puppet" % ["ok" if seen else "FAIL", role])
	if role == "guest":
		print("  %s   guest received host world (day %d time %d)" % ["ok" if synced else "FAIL", int(GameState.run["day"]), int(GameState.run["time"])])
		# C9: later worlds are deltas (time only, a few bytes): the clock keeps following the host.
		var t_sync := int(GameState.run["time"])
		var moved := false
		var t_end := Time.get_ticks_msec() + 12000  # the host pushes every 2 s of real time
		while Time.get_ticks_msec() < t_end:
			await process_frame
			if int(GameState.run["time"]) >= 14 * 60:
				moved = true
				break
		print("  %s   guest follows the host's clock through world deltas (%d -> %d)" % ["ok" if moved else "FAIL", t_sync, int(GameState.run["time"])])
		# guest tills a tile: host should get it
		GameState.run["farm"]["5,5"] = {"watered": true, "crop": "turnip", "days": 1}
		(current_scene as GameMap).net_act({"a": "farm_tile", "key": "5,5", "tile": GameState.run["farm"]["5,5"]})
		for i in 120:
			await process_frame
	else:
		var got := false
		var t0 := Time.get_ticks_msec()
		var bumped := false
		while Time.get_ticks_msec() - t0 < 15000:
			await process_frame
			if not bumped and Time.get_ticks_msec() - t0 > 3000:
				bumped = true
				GameState.run["time"] = 14 * 60  # the host's clock moves after the guest synced: guests get it as a delta
			if GameState.run["farm"].has("5,5") and bumped and Time.get_ticks_msec() - t0 > 6000:
				got = true
				break
		print("  %s   host received the guest's farm action" % ("ok" if got else "FAIL"))
	for i in 60:
		await process_frame
	quit(0)
