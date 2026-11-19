extends SceneTree
## CONDUCT 2 P1 (Tom's mine playtest): tools fight weakly, crates/barrels break
## reliably with feedback, the floor keeper's pace and encounter vary (never the
## same encounter twice running, packs and big ones, both arcs), and the HUD
## arrow's route leads to the real shaft on every layout style.
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/mine_keeper_test.gd

var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(777)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(t: float, busy: Callable) -> void:
	var gt := 0.0
	while gt < t and busy.call():
		await process_frame
		gt += root.get_process_delta_time()


func _enter(floor_no: int, sd: int, style := "") -> GameMap:
	GameState.run["mine_floor"] = floor_no
	(load("res://scripts/mine.gd") as Variant).force_seed = sd
	(load("res://scripts/mine.gd") as Variant).force_style = style
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(6)
	var m := current_scene as GameMap
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	return m


func _new(arc: String) -> void:
	GameState.new_run(arc, "kairi" if arc == "penguins" else "vic", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999


func _run() -> void:
	InputSetup.ensure_actions()
	_new("penguins")
	_tools_and_crates_data()
	_variety("penguins")
	_new("gangsters")
	_variety("gangsters")
	_new("penguins")
	await _crates_live()
	await _pack_live()
	await _arrow_live()
	(load("res://scripts/mine.gd") as Variant).force_seed = 0
	(load("res://scripts/mine.gd") as Variant).force_style = ""
	print("MINE KEEPER DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)


func _tools_and_crates_data() -> void:
	for t in ["pickaxe", "axe", "hoe", "scythe"]:
		var d := GameState.tool_fight_damage(t, 10)
		check(d >= 2 and d <= 4, "%s deals %d of a sword's 10 (25-40%%)" % [t, d])
	check(GameState.tool_fight_damage("sword", 10) == 10 and GameState.tool_fight_damage("", 10) == 10, "swords and fists keep full damage")
	check(GameState.tool_fight_damage("pickaxe", 1) == 1, "a tool still scratches (min 1)")


func _variety(arc: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	var packs := 0
	var singles := 0
	var repeats := 0
	var no_art := []
	var recent: Array = []
	for i in 300:
		var f := 1 + (i * 7) % 150
		var tier := GameState.mine_tier(f)
		var en := MineKeepers.pick(f, tier, clampi((f - 1) / 10, 0, 14), rng, recent)
		if not recent.is_empty() and str(recent[-1]) == str(en["id"]):
			repeats += 1
		recent.append(str(en["id"]))
		seen[str(en["id"])] = true
		var units: Array = en["units"]
		if units.size() == 1:
			singles += 1
		else:
			packs += 1
		for u: Dictionary in units:
			if not MineKeepers.has_art(str(u["kind"])):
				no_art.append(str(u["kind"]))
			if arc == "gangsters" and str(u["kind"]) in ["grump", "big_grump", "shard"]:
				no_art.append("penguin-only " + str(u["kind"]))
	check(repeats == 0, "%s: 300 floors, never the same encounter twice running" % arc)
	check(seen.size() >= 20, "%s: %d different encounters (%s...)" % [arc, seen.size(), str(seen.keys().slice(0, 8))])
	check(packs >= 60 and singles >= 40, "%s: packs %d, single big keepers %d" % [arc, packs, singles])
	check(no_art.is_empty(), "%s: every keeper kind has art and fits the arc %s" % [arc, str(no_art)])
	# Floor 1 alone still varies.
	var f1 := {}
	recent = []
	for i in 40:
		var en := MineKeepers.pick(1, 0, 0, rng, recent)
		recent.append(str(en["id"]))
		f1[str(en["id"])] = true
	check(f1.size() >= 5, "%s: floor 1 rolls %d encounters %s" % [arc, f1.size(), str(f1.keys())])
	# Pace: some very quick, some long; no bucket three times running.
	var secs: Array = []
	var last: Array = []
	var triple := 0
	var buckets := {}
	for i in 400:
		var p := MineKeepers.roll_pace(3 + i % 140, rng, last)
		secs.append(float(p["secs"]))
		buckets[str(p["pace"])] = true
		if last.size() >= 2 and str(last[-1]) == str(p["pace"]) and str(last[-2]) == str(p["pace"]):
			triple += 1
		last.append(str(p["pace"]))
	secs.sort()
	check(float(secs[0]) < 10.0 and float(secs[-1]) > 250.0 and buckets.size() == 4, "%s: wake time spread %.0f-%.0f s over %d paces" % [arc, float(secs[0]), float(secs[-1]), buckets.size()])
	check(triple == 0, "%s: never the same pace three floors running" % arc)
	var p1 := MineKeepers.roll_pace(1, rng, [])
	check(float(p1["secs"]) >= 70.0 and float(p1["thr"]) >= 0.85, "floor 1 is never a quick wake (%.0f s)" % float(p1["secs"]))


func _crates_live() -> void:
	var m := await _enter(3, 31)
	var p := m.player
	var tb: Array = GameState.run["toolbar"]
	# Place a barrel two cells right of the player, stand beside it, face it.
	var pc := p.cell()
	var cc := pc + Vector2i(1, 0)
	for c in [cc]:
		m.things.erase(c)
		m.blocked.erase(c)
	m.set_thing(cc.x, cc.y, {"type": "crate", "key": "t_crate", "kind": "barrel_a", "hp": 3, "hint": ""}, true)
	p.facing = "right"
	GameState.select_slot(tb.find("pickaxe"))
	var hits0 := int(m.get("crate_hits"))
	var n := 0
	while m.things.has(cc) and n < 6:
		p._busy = false
		p.do_action("a")
		n += 1
		await frames(30)
	check(not m.things.has(cc) and int(m.get("crate_hits")) - hits0 == n and n <= 3, "pickaxe broke the barrel in %d blows, each counted" % n)
	# Sword: holding USE swings (mode tool), and the swing smashes the crate.
	m.set_thing(cc.x, cc.y, {"type": "crate", "key": "t_crate2", "kind": "crates_a", "hp": 2, "hint": ""}, true)
	GameState.select_slot(tb.find("sword"))
	n = 0
	while m.things.has(cc) and n < 8:
		p._busy = false
		p._attack_cd = 0.0
		p.do_action("tool")
		n += 1
		await frames(30)
	check(not m.things.has(cc), "held-USE sword swings smashed the crate (%d swings)" % n)
	# Off-centre: standing a cell below the crate's row, facing right, USE still finds it.
	var c2 := pc + Vector2i(1, -1)
	m.things.erase(c2)
	m.blocked.erase(c2)
	m.set_thing(c2.x, c2.y, {"type": "crate", "key": "t_crate3", "kind": "barrel_a", "hp": 1, "hint": ""}, true)
	GameState.select_slot(tb.find("pickaxe"))
	p._busy = false
	p.do_action("a")
	await frames(30)
	check(not m.things.has(c2), "USE beside an off-centre barrel still smashes it")
	# The wrong thing in hand: a hint, no hit.
	m.set_thing(cc.x, cc.y, {"type": "crate", "key": "t_crate4", "kind": "crates_a", "hp": 2, "hint": ""}, true)
	var h0 := int(m.get("crate_hits"))
	GameState.select_slot(tb.find("can"))
	p._busy = false
	m.try_interact(cc)
	check(int(m.get("crate_hits")) == h0 and int(m.things[cc]["hp"]) == 2, "watering can: a hint, the crate untouched")
	# A tool against a foe: about 30% of the sword.
	var e := m.spawn_enemy("golem", p.position + Vector2(14, 0), 0)
	e.armor = 0
	e.kb_resist = 99.0
	GameState.select_slot(tb.find("sword"))
	var sw := GameState.sword_damage()
	e.hp = 999
	e.max_hp = 999
	m.things.erase(cc)
	m.blocked.erase(cc)
	p._busy = false
	p._attack_cd = 0.0
	p._combo = 1
	p.facing = "right"
	p._last_swing_ms = Time.get_ticks_msec()
	p.do_action("tool")
	await frames(2)
	var by_sword := 999 - e.hp
	e.hp = 999
	await frames(30)
	GameState.select_slot(tb.find("pickaxe"))
	e.position = p.position + Vector2(14, 0)
	e._shield = 0.0
	p.facing = "right"
	p._busy = false
	p._attack_cd = 0.0
	p._last_swing_ms = Time.get_ticks_msec()
	p.do_action("a")
	await frames(2)
	var by_pick := 999 - e.hp
	check(by_sword > 0 and by_pick > 0 and by_pick <= ceili(by_sword * 0.45), "pickaxe hit %d vs sword %d (sword_damage %d)" % [by_pick, by_sword, sw])
	e.queue_free()
	m.enemies.erase(e)


func _pack_live() -> void:
	var ids := {}
	for f in [12, 47, 88]:
		var m := await _enter(f, 500 + f)
		m.set("_secs_live", 9999.0)
		m.call("_summon_guardian")
		await _wait(3.0, func() -> bool: return (m.call("keepers_left") as Array).is_empty())
		var ks: Array = m.call("keepers_left")
		var en: Dictionary = m.get("encounter")
		ids[str(en.get("id", ""))] = true
		check(not ks.is_empty() and ks.size() == (en["units"] as Array).size(), "floor %d: %s woke with %d unit(s)" % [f, str(en.get("name", "")), ks.size()])
		var g: Enemy = m.get("_guardian")
		check(g != null and g.is_guardian and g.has_meta("boss_name"), "floor %d: a lead keeper with a name on the boss bar" % f)
		var tgt: Vector2 = m.call("pointer_target")
		check(tgt != Vector2.ZERO, "floor %d: the arrow points at a keeper" % f)
		# Beat all but one: the shaft stays shut; the last opens it.
		for i in ks.size():
			var e: Enemy = ks[i]
			if i == ks.size() - 1:
				check(not GameState.run["flags"].has("mine_open_%d" % f), "floor %d: shaft shut while one keeper stands" % f)
			e.hit(99999, e.position + Vector2(-10, 0))
			await frames(4)
		await frames(20)
		check(GameState.run["flags"].has("mine_open_%d" % f), "floor %d: every keeper down opens the shaft" % f)
	check(ids.size() == 3, "three floors, three different encounters %s" % str(ids.keys()))


## Follow the arrow's aim point from the entry; it must arrive at the real shaft.
func _arrow_live() -> void:
	var styles: Array = []
	for st: Dictionary in (load("res://scripts/mine_layouts.gd") as Variant).STYLES:
		styles.append(str(st["id"]))
	var ok := 0
	var bad: Array = []
	var i := 0
	for sid in styles:
		i += 1
		var f: int = [1, 4, 9, 17, 33, 61, 95, 140][i % 8]
		var m := await _enter(f, 9000 + i * 13, str(sid))
		m.call("_open_way")
		var lad: Vector2i = m.get("_ladder")
		var real := Vector2i(-1, -1)
		for c: Vector2i in m.things:
			if str(m.things[c].get("type", "")) == "down":
				real = c
		var tgt: Vector2 = m.call("pointer_target")
		var good := real == lad and tgt == m.cell_center(lad)
		var p := m.player
		var steps := 0
		while good and steps < 600:
			var aim: Vector2 = m.call("pointer_aim")
			if aim == tgt or m.world_to_cell(p.position - Vector2(0, 2)) == lad:
				break
			var ac := m.world_to_cell(aim)
			var pc := m.world_to_cell(p.position - Vector2(0, 2))
			if ac == pc:
				good = false
				break
			# The aim is a route cell a few steps on, strictly closer to the shaft.
			var fl: Dictionary = m.get("_flow")
			if not fl.has(ac) or int(fl[ac]) >= int(fl.get(pc, 1 << 30)) or absi(ac.x - pc.x) + absi(ac.y - pc.y) > 6:
				good = false
				break
			p.position = m.cell_center(ac)
			steps += 1
		var end := m.world_to_cell(p.position - Vector2(0, 2))
		if good and (end.distance_to(lad) <= 2.0 or m.call("pointer_aim") == tgt):
			ok += 1
		else:
			bad.append("%s f%d (%d steps, end %s, shaft %s)" % [sid, f, steps, str(end), str(lad)])
	check(bad.is_empty(), "the arrow's route reaches the real shaft on %d/%d layout styles %s" % [ok, styles.size(), str(bad)])
