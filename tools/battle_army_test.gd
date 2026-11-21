extends SceneTree
## CONDUCT 16b P1: battle commands, army building and allies (c16b_06/07/12/13).
## Hold here holds your team where it stood; the HELPERS button says what they really do
## (pushing on / follow me / hold here / ▸ point); Mend pulse and Barrage work anywhere with a
## cooldown; banner builds: switching keeps paid units, upkeep vs income, the broke state and its
## toast, the HUD rate counts supply_mul; ally rank adds health and hits; the brief's controls
## line matches the fight; button text fits; reduced motion stops the pulses; weapon out.
##   godot --headless --fixed-fps 60 --path . -s res://tools/battle_army_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	seed(1616)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func drain(n := 40) -> void:
	for i in n:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame


func _points_in(v: Variant, out: Array) -> void:
	if v is Dictionary:
		if v.has("cell") and v.has("name") and v.has("id"):
			out.append("▸ %s %s" % [str(v["id"]).to_upper(), str(v["name"])])
		for k in v:
			_points_in(v[k], out)
	elif v is Array:
		for x in v:
			_points_in(x, out)


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["flags"]["proj_war_table"] = true
	GameState.run["slot"] = 0  # the hoe in hand
	GameState.sync_selected()
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/bf_frostfield.tscn")
	await frames(12)
	await drain(30)
	var m := current_scene as GameMap
	var b: Battle = m.get("battle")
	check(b != null, "war-table field starts a battle")
	if b == null:
		quit(1)
		return
	b._briefing = false
	m.player.invuln = 9999.0
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	await frames(4)

	# ---- weapon out (c16b_06-12)
	check(GameState.held_tool() == "sword", "the field puts your weapon in hand, not the hoe (%s)" % GameState.held_tool())

	# ---- labels (c16b_06-02/06-04)
	check(b.rally_label().ends_with("follow me"), "fights open on Follow me (%s)" % b.rally_label())
	m.set_meta("team_push", m.player.position)
	b._rally_given = false
	check(b.rally_label().ends_with("pushing on"), "team push shows 'pushing on' (%s)" % b.rally_label())
	m.remove_meta("team_push")
	var font := ThemeDB.fallback_font
	var widest := 0.0
	var names: Array = []
	for f: String in ["res://data/battles.json", "res://data/campaigns.json"]:
		if FileAccess.file_exists(f):
			_points_in(JSON.parse_string(FileAccess.get_file_as_string(f)), names)
	check(names.size() > 10, "battle point names found (%d)" % names.size())
	for nm: String in names:
		widest = maxf(widest, font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	check(widest <= Battle.rally_rect().size.x - 18.0, "every order label fits the HELPERS button (%.0f px in %.0f)" % [widest, Battle.rally_rect().size.x])
	Settings.set_v("btn_size", 2)
	check(Battle.rally_rect().size.x > Battle.RALLY_RECT.size.x and not Battle.mend_rect().intersects(Battle.rally_rect()), "HELPERS grows with Button size; MEND sits below it")
	Settings.set_v("btn_size", 0)

	# ---- banner builds (c16b_07-03/07-05/07-04)
	var p: Dictionary = b.points[0]
	p["owner"] = "ally"
	p["prog"] = 1.0
	for q in b.points:
		if q != p:
			q["owner"] = "neutral"
			q["prog"] = 0.0
	b.supply = 500
	check(b.pick_build(p, "striker"), "Build helper goes through")
	for i in 6:
		b._tick()
	var made := (p["made"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x)).size()
	check(made >= 1 and b._built() == made, "the banner turns out crystals (%d)" % made)
	check(b.count_line().begins_with("Team 0 · Crystals %d" % b._built()), "HUD counts team and crystals apart (%s)" % b.count_line())
	check(b.pick_build(p, "healer"), "switching kind goes through")
	var kept := (p.get("old", []) as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x)).size()
	await frames(2)
	check(kept == made and (p["made"] as Array).is_empty(), "switching keeps the paid units fighting (%d of %d)" % [kept, made])
	b.d["supply_mul"] = 1.3
	b.supply = 0
	p["lvl"] = 3
	for i in 30:
		b._tick()
	var income := 1 * int(b.d.get("supply_per_point", 2)) * 0.35 * (1.0 + minf(1.0, GameState.bonus(GameState.arc_skill(), "supply_rate") + GameState.bonus("strategist", "supply_rate"))) * 1.3
	var units := 0
	for q in b.points:
		units += (q["made"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x)).size() + (q.get("old", []) as Array).size()
	check(absf(b._rate - (income - units * 0.2)) < 0.01, "HUD rate = income (supply_mul) - upkeep (%.2f vs %.2f)" % [b._rate, income - units * 0.2])
	check(units < 4 or (b._rate < 0.0 and b.warned_low), "upkeep over income: rate red and the warning said (%d units, %.2f)" % [units, b._rate])
	b.supply = 0
	b._upkeep = 0.9
	b._tick()
	check(b.broke_now or units == 0, "no supply: spawners paused (broke)")

	# ---- Mend pulse / Barrage anywhere (c16b_06-03)
	b.supply = 100
	check(b.command("mend") and b.supply == 100 - b._disc(25) and b._mend_cd > 0.0, "Mend pulse spends supply and recharges")
	check(not b.command("mend"), "Mend pulse can't fire while recharging")
	check(b.cmd_label("mend").begins_with("MEND ") and b.cmd_label("mend").ends_with("s"), "MEND button shows the seconds left (%s)" % b.cmd_label("mend"))
	check(b.command("barrage") and b._barrage_cd > 0.0, "Barrage fires away from any banner")

	# ---- Hold here holds the team (c16b_06-01/13-06)
	var at := m.player.position + Vector2(30, 0)
	var h := HelperUnit.make_team(m, ["mom", "Mom", "partner"], "healer", at, "")
	b.team.append(h)
	await frames(2)
	b._set_rally(-2)
	var spot := h.position
	var gt := 0.0
	while gt < 5.0:
		m.player.position += Vector2(60, 0) * root.get_process_delta_time()
		gt += root.get_process_delta_time()
		await process_frame
	check(is_instance_valid(h) and h.position.distance_to(spot) < 30.0, "Hold here: the team member stays at its spot (%.0f px)" % (h.position.distance_to(spot) if is_instance_valid(h) else -1.0))
	b._set_rally(-1)
	var d0 := h.position.distance_to(m.player.position)
	gt = 0.0
	while gt < 3.0:
		gt += root.get_process_delta_time()
		await process_frame
	check(h.position.distance_to(m.player.position) < d0, "Follow me: they come back to you")

	# ---- ranks (c16b_07-02/13-01)
	var lo := HelperUnit.make_team(m, ["pax", "Pax", "partner"], "striker", at, "")
	var hi := HelperUnit.make_team(m, ["mom", "Mom", "partner"], "striker", at, "")
	GameState.run["friendship"]["mom"] = 2000
	Battle.apply_rank(lo, ["pax", "Pax", "partner"])
	Battle.apply_rank(hi, ["mom", "Mom", "partner"])
	check(Battle.ally_rank(["mom", "Mom", "partner"]) == 5, "Mom at 10 hearts is rank 5")
	check(hi.max_hp > lo.max_hp and hi.strike_damage() > lo.strike_damage(), "rank 5 fights harder than rank 1 (%d/%d vs %d/%d)" % [hi.max_hp, hi.strike_damage(), lo.max_hp, lo.strike_damage()])
	check(BattleBrief.card_sub(["mom", "Mom", "partner"]) == "Healer · R5", "card button: job and rank (%s)" % BattleBrief.card_sub(["mom", "Mom", "partner"]))

	# ---- brief words (c16b_06-13/13-11/07-03)
	check(BattleBrief.controls_text({"mode": "drill"}).contains("(new helpers follow you)"), "drill controls: helpers follow you")
	check(not BattleBrief.controls_text({"mode": "skirmish"}).contains("pushes on its own"), "no push promise outside tier-1 campaigns")
	check(BattleBrief.build_line({}).contains("◇0.2/s") and BattleBrief.build_line({}).begins_with("Build crystals"), "brief says helpers can be built and what upkeep costs")

	# ---- reduced motion (c16b_12-01)
	Settings.set_v("shake", false)
	check(Battle.pulse_k() == 0.0, "reduced motion: battle rings stop pulsing")
	Settings.set_v("shake", true)
	check(Battle.pulse_k() == 1.0, "pulses back with motion on")

	# ---- leaving restores the old hand
	m.go_to("town", Vector2.ZERO, "down")
	for i in 900:
		await process_frame
		if current_scene is GameMap and (current_scene as GameMap).scene_id() == "town":
			break
	await frames(5)
	check(GameState.held_tool() == "hoe", "after the field you hold the hoe again (%s)" % GameState.held_tool())
	print("battle_army_test: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
