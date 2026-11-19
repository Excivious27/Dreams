extends SceneTree
## Round 13 mega regions (new six): every area loads in each arc that can reach it,
## the spawn and every exit, thing, villager and boss can be walked to, every exit
## lands somewhere walkable, the home-world travel point sits where it should and
## can be reached, the hook quest opens the way, and the hub vehicle goes home.
##   godot --headless --path . -s res://tools/mega_regions_test.gd [-- shots_dir]
## With a shots dir (needs a renderer: xvfb-run ... --rendering-driver opengl3) it
## also saves a screenshot of every hub at its arrival point.
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func fail(msg: String) -> void:
	print("  FAIL ", msg)
	fails += 1


func _load(scene: String, spawn: Vector2) -> GameMap:
	GameMap.next_spawn = spawn
	GameMap.next_facing = "down"
	GameState.run["scene"] = scene
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 8:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 6:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _flood(m: GameMap, start: Vector2i) -> Dictionary:
	var seen := {}
	if m.blocked.has(start):
		return seen
	var q: Array[Vector2i] = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := c + d
			if seen.has(n) or m.blocked.has(n) or m.is_water_cell(n):
				continue
			if n.x < 0 or n.y < 0 or n.x >= m.cols or n.y >= m.rows:
				continue
			seen[n] = true
			q.append(n)
	return seen


func _near(seen: Dictionary, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if seen.has(c + d):
			return true
	return false


func _run() -> void:
	InputSetup.ensure_actions()
	var shots := ""
	if OS.get_cmdline_user_args().size() > 0:
		shots = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(shots)
	var data := MegaTravel.data()
	if data.size() < 6:
		fail("mega_travel.json has %d regions" % data.size())
	var regs := GameState.load_json("res://data/regions.json")
	var items := GameState.load_json("res://data/items.json")
	var foes: Dictionary = GameState.load_json("res://data/enemies.json").get("enemies", {})
	var arcs_seen := {"penguins": 0, "gangsters": 0}
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		for f in ["cm_seen", "mine_open_1", "meow_taught", "moon_seen", "mine_seen", "gangsters_intro"]:
			GameState.run["flags"][f] = true
		for id: String in data:
			var r: Dictionary = data[id]
			if not MegaTravel.arc_ok(r):
				continue
			arcs_seen[arc] += 1
			# Data sanity: foes, drops, the boss.
			var bosses := 0
			for aid: String in r["areas"]:
				var R: Dictionary = regs.get(aid, {})
				if R.is_empty():
					fail("%s: no region %s" % [id, aid])
					continue
				for e in R.get("enemies", []):
					if not foes.has(str(e["kind"])):
						fail("%s: unknown enemy %s" % [aid, e["kind"]])
				for t in R.get("things", []):
					if str(t["type"]) == "boss":
						bosses += 1
						if not foes.has(str(t["kind"])) or not bool(foes[str(t["kind"])].get("boss", false)):
							fail("%s: boss %s isn't a boss enemy" % [aid, t["kind"]])
						if not items.has(str(t.get("reward", ""))):
							fail("%s: boss reward %s missing" % [aid, t.get("reward", "")])
					if str(t["type"]) in ["loot", "mrock"]:
						var it := str(t.get("item", t.get("ore", "")))
						if not items.has(it):
							fail("%s: %s gives unknown item %s" % [aid, t["type"], it])
			if bosses != 1:
				fail("%s: %d bosses" % [id, bosses])
			# Locked at the start; the hook quest opens it.
			if MegaTravel.can_start(r) and int(r["unlock"]["tier"]) > 0:
				fail("%s: open on day one" % id)
			var q := GameState._quest_def(str(r["quest"]))
			if q.is_empty():
				fail("%s: no hook quest %s" % [id, r["quest"]])
			else:
				GameState.add_quest(str(r["quest"]), str(q["text"]))
				for pair in q["done_when"]["items"]:
					GameState.add_item(str(pair[0]), int(pair[1]))
				if not Quests._done(q):
					fail("%s: hook quest not done with its items" % id)
				GameState.complete_quest(str(r["quest"]))
				if not MegaTravel.is_open(id):
					fail("%s: hook quest didn't open the way" % id)
			# The travel point in the home world.
			var e: Dictionary = r["entry"]
			var hm: GameMap = await _load(str(e["scene"]), Vector2((float(e["spawn"][0]) + 0.5) * 16, (float(e["spawn"][1]) + 0.5) * 16))
			var gc := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			if hm == null or str(hm.things.get(gc, {}).get("type", "")) != "mega_gate":
				fail("%s: no travel point at %s in %s" % [id, gc, e["scene"]])
			else:
				var pc := hm.player.cell()
				if hm.blocked.has(pc) or hm.is_water_cell(pc):
					fail("%s: home landing %s blocked" % [id, pc])
				# Reachable from the way you walk in.
				var fs := _flood(hm, hm.world_to_cell(hm.default_spawn()) if not hm.blocked.has(hm.world_to_cell(hm.default_spawn())) else pc)
				if not _near(fs, gc) or not fs.has(pc):
					fail("%s: travel point in %s can't be walked to" % [id, e["scene"]])
			# Every area.
			for aid: String in r["areas"]:
				var hub: bool = aid == str(r["hub"])
				var sp := Vector2.ZERO
				if hub:
					sp = Vector2((float(r["hub_spawn"][0]) + 0.5) * 16, (float(r["hub_spawn"][1]) + 0.5) * 16)
				await _area(arc, aid, hub, sp, regs, shots, hub and arc == ("penguins" if str(r["arc"]) != "gangsters" else "gangsters"))
		# Second areas of the converted regions (Hollow Heart, Sky Isles).
		for aid: String in ["hollow_deeps", "sky_reaches"]:
			if aid == "sky_reaches" and arc != "penguins":
				continue
			await _area(arc, aid, false, Vector2.ZERO, regs, shots, arc == "penguins")
	if arcs_seen["penguins"] < 4 or arcs_seen["gangsters"] < 4:
		fail("arc coverage %s" % str(arcs_seen))
	print("mega_regions_test: %d failures" % fails)
	quit()


func _area(arc: String, aid: String, hub: bool, sp: Vector2, regs: Dictionary, shots: String, shoot: bool) -> void:
	var m: GameMap = await _load(aid, sp)
	if m == null:
		fail("%s didn't load" % aid)
		return
	var start := m.player.cell()
	if m.blocked.has(start) or m.is_water_cell(start):
		fail("[%s] %s: spawn %s blocked" % [arc, aid, start])
		return
	var seen := _flood(m, start)
	var open := 0
	for y in m.rows:
		for x in m.cols:
			if not m.blocked.has(Vector2i(x, y)) and not m.is_water_cell(Vector2i(x, y)):
				open += 1
	for ex in m.exits:
		var ok := false
		for c in m.cells_of([ex["rect"]]):
			if seen.has(c):
				ok = true
		if not ok:
			fail("[%s] %s: exit to %s unreachable" % [arc, aid, ex["scene"]])
	for c: Vector2i in m.things:
		var t := str(m.things[c].get("type", ""))
		if t in ["water", "forage", "tree", "rock", "bush", "log", "stump", "weed", "grass"]:
			continue
		if t == "locked" and m._building_doors.keys().any(func(w: Vector2i) -> bool: return m._building_doors[w] == c and _near(seen, w)):
			continue  # any wall cell of the building answers with the knock
		if not _near(seen, c):
			fail("[%s] %s: %s at %s unreachable (%s)" % [arc, aid, t, c, str(m.things[c].get("hint", ""))])
	for n in m.get_children():
		if n is Npc and (m.blocked.has((n as Npc).cell()) or not _near(seen, (n as Npc).cell())):
			fail("[%s] %s: villager %s stuck at %s" % [arc, aid, (n as Npc).id, (n as Npc).cell()])
	if hub:
		var g := false
		for c: Vector2i in m.things:
			if str(m.things[c].get("type", "")) == "mega_gate" and bool(m.things[c].get("home", false)):
				g = true
		if not g:
			fail("%s: no way home" % aid)
		if not m.enemies.is_empty():
			fail("%s: hub has foes" % aid)
	elif m.enemies.is_empty():
		fail("[%s] %s: no foes" % [arc, aid])
	print("[%s] %s ok: reach %d/%d things=%d foes=%d" % [arc, aid, seen.size(), open, m.things.size(), m.enemies.size()])
	if shots != "" and shoot:
		for en in m.enemies:
			if is_instance_valid(en):
				en.queue_free()
		for k in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [shots, aid])
	# Where each exit lands.
	for ex in m.exits:
		var dst := str(ex["scene"])
		if not regs.has(dst):
			continue
		var m2: GameMap = await _load(dst, ex["spawn"])
		var c2 := m2.player.cell()
		var why := ""
		if m2.blocked.has(c2):
			why = "blocked"
		elif m2.is_water_cell(c2):
			why = "water"
		else:
			for e2 in m2.exits:
				if (e2["rect"] as Rect2i).has_point(c2):
					why = "inside an exit"
		if why != "":
			fail("%s -> %s lands %s (%s)" % [aid, dst, c2, why])
