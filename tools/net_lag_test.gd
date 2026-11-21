extends SceneTree
## C17 P3: phone conditions and co-op rooms for mines/interiors/battles.
## NetLag (latency, jitter, loss of droppable ticks only, stalls, half-open, pause)
## over the loop relay twin; PuppetSmooth under 150-300 ms jitter + 5% loss (no
## snaps, no walking in place, out-of-order packets ignored, warps snap); Mine
## net_scene/shared floor (same cave from a partner's key, remote break, time-only
## syncs repaint nothing); Interior net_scene per room; guest campaign guards.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/net_lag_test.gd

var fails := 0
const DT := 1.0 / 60.0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(1717)
	Campaign.bypass = true
	_run.call_deferred()


func _join(t: NetTransport, room: String, tok: String, create: bool) -> void:
	t.open("", {})
	t.send({"t": "join", "room": room, "create": create, "token": tok, "name": tok, "look": {}, "arc": "penguins", "proto": NetNode.PROTO})


func _ns(frames: Array) -> Array:
	var out: Array = []
	for f: Dictionary in frames:
		var d: Variant = f.get("d", {})
		if str(f.get("t", "")) == "msg" and d is Dictionary and (d as Dictionary).has("n"):
			out.append(int((d as Dictionary)["n"]))
	return out


func _lag_tests() -> void:
	var bus := NetTransportLoop.Bus.new()
	var h := NetTransportLoop.new(bus)
	_join(h, "LAGR", "h", true)
	var g := NetTransportLoop.new(bus)
	_join(g, "LAGR", "g", false)
	h.poll(DT); g.poll(DT); h.take(); g.take()
	(bus.rooms["LAGR"] as NetRelayRoom).guard = false   # frames here are synchronous: no rate window refill
	var hl := NetLag.new(h, 7).configure("lat=200,jit=100")
	# 1. Latency + jitter, order kept.
	for i in 20:
		hl.send({"t": "all", "d": {"k": "x", "n": i}})
	var got: Array = []
	var first_at := -1.0
	var tt := 0.0
	for f in 60:
		hl.poll(DT)
		g.poll(DT)
		tt += DT
		var ns := _ns(g.take())
		if not ns.is_empty() and first_at < 0.0:
			first_at = tt
		got.append_array(ns)
	check(first_at >= 0.19, "nothing arrives before the 200 ms latency (first at %.2f s)" % first_at)
	check(got.size() == 20, "every reliable frame arrives within 1 s (%d/20)" % got.size())
	var ordered := true
	for i in got.size():
		ordered = ordered and int(got[i]) == i
	check(ordered, "frames keep their order under jitter (a WebSocket is ordered)")
	# 2. Loss hits only droppable position ticks.
	var hl2 := NetLag.new(h, 11).configure("loss=0.05")
	# Paced like a real line (the relay's 120 frames/s guard drops floods).
	var ns2: Array = []
	for i in 400:
		hl2.send({"t": "all", "d": {"k": "state", "pos": [0, 0], "n": i}})
		if i % 4 == 0:
			hl2.send({"t": "all", "d": {"k": "act", "n": 1000 + i / 4}})
		hl2.poll(DT); g.poll(DT)
		ns2.append_array(_ns(g.take()))
	for f in 3:
		hl2.poll(DT); g.poll(DT)
	ns2.append_array(_ns(g.take()))
	var acts := ns2.filter(func(n: int) -> bool: return n >= 1000).size()
	var ticks := ns2.size() - acts
	check(acts == 100, "no action frame is ever lost (%d/100)" % acts)
	check(ticks >= 340 and ticks < 400 and hl2.lost == 400 - ticks, "about 5%% of position ticks lost (%d of 400 kept)" % ticks)
	# 3. Half-open: sends vanish, nothing arrives, the line still looks open.
	hl2.half_open = true
	hl2.send({"t": "all", "d": {"k": "act", "n": 5000}})
	for f in 30:
		hl2.poll(DT); g.poll(DT)
	check(_ns(g.take()).is_empty() and hl2.is_open(), "half-open line: the act never lands, socket still 'open'")
	hl2.half_open = false
	# 4. Stall (cell handover) on the guest's inbound: nothing for 0.8 s, then one burst.
	for f in 90:   # let the relay's rate window refill
		h.poll(DT); g.poll(DT)
	g.take()
	var gl := NetLag.new(g, 3)
	gl.stall(0.8)
	for i in 10:
		h.send({"t": "all", "d": {"k": "act", "n": 7000 + i}})
	var during := 0
	var after := 0
	for f in 60:
		h.poll(DT); gl.poll(DT)
		var n := _ns(gl.take()).size()
		if f < 45:
			during += n
		else:
			after += n
	check(during == 0 and after == 10, "a stall holds everything, then releases it in one burst (%d during, %d after)" % [during, after])
	# 5. Background pause: nothing taken until resumed, then the backlog.
	gl.paused = true
	for i in 5:
		h.send({"t": "all", "d": {"k": "act", "n": 8000 + i}})
	var p_n := 0
	for f in 20:
		h.poll(DT); gl.poll(DT)
		p_n += _ns(gl.take()).size()
	gl.paused = false
	gl.poll(DT)
	check(p_n == 0 and _ns(gl.take()).size() == 5, "a backgrounded app takes nothing, then the whole backlog on resume")


func _smooth_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var sm := PuppetSmooth.new()
	# A walker at 60 px/s for 3 s, then standing; 10 Hz packets, 150-300 ms delay, 5% loss.
	var inbox: Array = []   # [arrive_t, pos, seq]
	var shown := Vector2.ZERO
	var newest := Vector2.ZERO
	var newest_seq := -1
	var max_step := 0.0
	var moving_frames := 0
	var walk_frames := 0
	var last_arrive := 0.0
	var max_err := 0.0
	var seq := 0
	var t := 0.0
	var next_tick := 0.0
	for f in 300:
		t += DT
		var truth := Vector2(minf(t, 3.0) * 60.0, 100.0)
		if t >= next_tick:
			next_tick += 0.1
			seq += 1
			if rng.randf() >= 0.05:
				last_arrive = maxf(last_arrive, t + 0.15 + rng.randf() * 0.15)
				inbox.append([last_arrive, truth, seq])
		while not inbox.is_empty() and float(inbox[0][0]) <= t:
			var e: Array = inbox.pop_front()
			newest = e[1]
			newest_seq = int(e[2])
		var before := shown
		shown = sm.step(DT, newest, newest_seq)
		if f > 30:
			max_step = maxf(max_step, before.distance_to(shown))
		if t > 0.6 and t < 2.9:
			walk_frames += 1
			if sm.moving():
				moving_frames += 1
			max_err = maxf(max_err, shown.distance_to(Vector2((t - 0.4) * 60.0, 100.0)))
	check(max_step < 4.0, "no snaps or sprints under jitter (largest step %.2f px/frame, walk is 1 px)" % max_step)
	check(moving_frames >= int(walk_frames * 0.95), "walk anim while walking (%d/%d frames)" % [moving_frames, walk_frames])
	check(max_err < 20.0, "follows the true path closely, ~0.4 s behind (worst %.1f px)" % max_err)
	check(not sm.moving() and shown.distance_to(Vector2(180, 100)) < 1.0, "stands still (idle, no walking in place) once the walker stops")
	for f in 60:
		sm.step(DT, newest, newest_seq)
	check(sm.silent_for() > 0.9, "a peer that stopped sending reads as silent (%.1f s)" % sm.silent_for())
	# Out-of-order packet ignored; a warp snaps.
	var s2 := PuppetSmooth.new()
	s2.step(DT, Vector2(0, 0), 1)
	for i in 30:
		s2.step(DT, Vector2(i * 2, 0), 2 + i)
	var p_old := s2.step(DT, Vector2(-500, 0), 3)
	check(p_old.x > 0.0, "a late, older packet never pulls the puppet backwards")
	var p_tp := s2.step(DT, Vector2(900, 400), 99, true)
	check(p_tp == Vector2(900, 400), "a warp (teleport flag) snaps at once")
	var p_far := s2.step(DT, Vector2(3000, 400), 100)
	check(p_far == Vector2(3000, 400), "a jump no walk or ride could make snaps")


func _go(path: String) -> GameMap:
	change_scene_to_file(path)
	for i in 120:
		await process_frame
		if current_scene is GameMap and (current_scene as GameMap).player != null:
			break
	for i in 4:
		await process_frame
	return current_scene as GameMap


func _rocks(m: GameMap) -> Array:
	var out: Array = []
	for c in m.things:
		if str(m.things[c].get("type", "")) == "rock":
			out.append(c)
	out.sort()
	return out


func _map_tests() -> void:
	var MineS := preload("res://scripts/mine.gd")
	var f := MineS.parse_net_scene("mine:7:12345:caverns:mossy:-99887766")
	check(int(f.get("floor", 0)) == 7 and int(f.get("seed", 0)) == 12345 and str(f.get("style", "")) == "caverns" and int(f.get("state", 0)) == -99887766, "mine net_scene parses back")
	check(MineS.parse_net_scene("mine").is_empty() and MineS.parse_net_scene("interior:rec").is_empty(), "non-mine keys are not a shared floor")
	GameState.run["mine_floor"] = 3
	MineS.force_seed = 77
	var m1 := await _go("res://scenes/mine.tscn")
	var key: String = m1.call("net_scene")
	var rocks1 := _rocks(m1)
	check(key.begins_with("mine:3:") and rocks1.size() > 10, "mine floor key %s (%d rocks)" % [key.substr(0, 24), rocks1.size()])
	# Time-only host deltas repaint nothing; a new day does.
	for i in 10:
		m1.on_world_sync({"time": 400 + i})
	var r0 := int(m1.get("world_redraws"))
	m1.on_world_sync({"time": 500, "day": 4})
	check(r0 == 0 and int(m1.get("world_redraws")) == 1, "ten time-only syncs repaint nothing, a new day repaints once")
	# A partner is on floor 3 with that cave: we (a different seed) carve the same one.
	var bus := NetTransportLoop.Bus.new()
	var lt := NetTransportLoop.new(bus)
	lt.open("", {})
	var nn: NetNode = Net.i()
	var old_tr: NetTransport = nn.tr
	var old_id: int = nn.my_id
	var old_peers: Dictionary = nn.peers.duplicate(true)
	nn.tr = lt
	nn.my_id = 2
	nn.peers = {1: {"name": "H", "scene": key, "pos": [0, 0], "anim": "idle"}}
	MineS.force_seed = 999
	var m2 := await _go("res://scenes/mine.tscn")
	var rocks2 := _rocks(m2)
	check(str(m2.call("net_scene")) == key, "a guest entering the partner's floor gets the same room key")
	check(rocks2 == rocks1, "and the same cave: identical rock cells (%d)" % rocks2.size())
	# A partner on a different floor: our own cave.
	nn.peers = {1: {"name": "H", "scene": key.replace("mine:3:", "mine:4:"), "pos": [0, 0], "anim": "idle"}}
	var m3 := await _go("res://scenes/mine.tscn")
	check(str(m3.call("net_scene")) != key, "a partner on another floor never shares our cave")
	var pf: Array = m3.call("partner_floors")
	check(pf.size() == 1 and int(pf[0]["floor"]) == 4 and str(pf[0]["name"]) == "H", "the lift can offer 'Join H · Floor 4' (%s)" % str(pf))
	# A remote break takes the rock away without loot.
	var rc: Vector2i = _rocks(m3)[0]
	var bag := JSON.stringify(GameState.run.get("inventory", {}))
	check(bool(m3.call("apply_remote_break", rc)) and not m3.things.has(rc) and not m3.blocked.has(rc), "a partner's break removes the rock here")
	check(JSON.stringify(GameState.run.get("inventory", {})) == bag, "and drops nothing for us (each player's own loot)")
	check(not bool(m3.call("apply_remote_break", rc)), "a second break of the same cell is a no-op")
	nn.tr = old_tr
	nn.my_id = old_id
	nn.peers = old_peers
	MineS.force_seed = 0
	# Interiors: one key per room.
	GameMap.next_interior = "store"
	var mi := await _go("res://scenes/interior.tscn")
	check(mi.scene_id() == "interior" and str(mi.call("net_scene")) == "interior:store", "interior key is the room (%s), scene_id unchanged" % str(mi.call("net_scene")))
	# Campaign board while visiting: look only (no Muster/Attack/March buttons that refuse).
	var c0: String = Campaign.for_arc()[0]
	CampaignScreen.open(mi, "")
	await process_frame
	await process_frame
	var scr: CampaignScreen = null
	for n in current_scene.get_children():
		if n is CampaignScreen and not n.is_queued_for_deletion():
			scr = n
	check(scr != null, "campaign board opens")
	if scr != null:
		scr._show_board(c0)
		scr._brief.visible = false
		scr._refresh()
		var solo_has := false
		for a: Array in scr._all_acts:
			solo_has = solo_has or (a[1] as Callable).get_method() in CampaignScreen.GUEST_NO
		var ob: Dictionary = nn._solo_backup
		var oh: bool = nn._host
		nn._host = false
		nn._solo_backup = {"probe": true}
		scr._refresh()
		var bad: Array = []
		for a: Array in scr._all_acts:
			if (a[1] as Callable).get_method() in CampaignScreen.GUEST_NO:
				bad.append(str(a[0]))
		check(solo_has and bad.is_empty() and scr._body.text.begins_with("Visiting a friend"), "visiting: board is look-only (solo had acts; guest acts left: %s)" % str(bad))
		nn._solo_backup = ob
		nn._host = oh
		scr.queue_free()


func _guard_tests() -> void:
	var st := Campaign.st()
	st["fight"] = {"cid": "probe", "nid": "n1", "field": "bf_probe"}
	var nn: NetNode = Net.i()
	var old_backup: Dictionary = nn._solo_backup
	var old_host: bool = nn._host
	nn._host = false
	nn._solo_backup = {"probe": true}
	check(Net.visiting(), "test is visiting")
	check(Campaign.finish(true, 3).is_empty() and not (st.get("fight", {}) as Dictionary).is_empty(), "a guest's campaign fight is never finished/paid on a friend's world (it stays parked)")
	nn._solo_backup = old_backup
	nn._host = old_host
	st["fight"] = {}


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	_lag_tests()
	_smooth_tests()
	_guard_tests()
	await _map_tests()
	print("net_lag_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
