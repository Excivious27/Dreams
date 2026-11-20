extends SceneTree
## Battle outcomes and C3 battle runtime (fix P2): every way a fight ends, each
## on a fresh field, plus the helper / boss / music rules.
##   ticket drain (war table), siege all points, boss kill (campaign boss node,
##   tier-floored HP, boss theme + DangerMusic hold, wind-down on the kill),
##   defend timer, convoy destroyed, convoy arrived; the mustered team takes the
##   field; helpers spawn on a free cell; the Shade veil runs on game time.
## Game time only (frames), seeded.
##   godot --headless --path . --fixed-fps 60 -s res://tools/battle_win_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	seed(3131)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Answer any dialogue / close any briefing card (B picks the way out).
func drain(n := 40) -> void:
	for i in n:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		for c in get_nodes_in_group("toast_hold"):
			if c.has_method("_close"):
				c.set("_arm", 99)
				c.call("_close")
		await process_frame


func go(sc: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	await frames(12)
	await drain(30)
	return current_scene as GameMap


## After a fight ends: answer its lines and wait until we're off the field.
func settle() -> void:
	for i in 900:
		await drain(1)
		var cs := current_scene as GameMap
		if cs != null and not cs.scene_id().begins_with("bf_") and not cs.get("_changing"):
			break
	await drain(30)
	Campaign.st().erase("board_reopen")


func clear(m: GameMap) -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e) and not e.has_meta("boss_name"):
			e.queue_free()
	m.enemies = m.enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).has_meta("boss_name"))


## Start a campaign node's fight and walk onto its field.
func fight(cid: String, nid: String) -> Battle:
	var f := str(Campaign.cfg(cid, nid).get("field", ""))
	Campaign.cs(cid)
	Campaign.st()["fight"] = {"cid": cid, "nid": nid, "field": f, "day": int(GameState.run["day"]), "back": ["town", 400.0, 300.0]}
	var m := await go(f)
	var bt: Variant = m.get("battle")
	if bt == null:
		check(false, "%s %s: field %s starts a battle" % [cid, nid, f])
		return null
	var b: Battle = bt
	b._briefing = false
	m.player.invuln = 9999.0
	if b.camp != cid:
		print("  (debug) %s %s field %s scene %s camp '%s' fight %s" % [cid, nid, f, m.scene_id(), b.camp, str(Campaign.st().get("fight", {}))])
	return b


func node_of(cid: String, typ: String) -> String:
	for n: Dictionary in Campaign.get_c(cid).get("nodes", []):
		if str(n.get("type", "")) == typ:
			return str(n["id"])
	return ""


func _run() -> void:
	GameState.new_run("penguins", "mom", "T", "Town", "Pup")
	GameState.run["flags"]["proj_war_table"] = true
	GameState.save()

	# --- formulas
	var t1 := Battle.boss_hp(40, 1, 0)
	check(t1 >= 60 and t1 <= 96, "T1 commander HP stays a short fight (%d)" % t1)
	check(Battle.boss_hp(500, 1, 0) <= 96, "T1 cap holds for a big kind (%d)" % Battle.boss_hp(500, 1, 0))
	check(Battle.boss_hp(40, 4, 3) >= 240, "T4 commander floor (%d)" % Battle.boss_hp(40, 4, 3))
	check(Battle.boss_hp(40, 1, 3) > t1, "outgrown campaign: tougher captain (%d)" % Battle.boss_hp(40, 1, 3))

	# --- spawner kinds (C4 P6): Crystal Kin once befriended, penguins only
	check(not ("crystal_kin" in Battle.spawner_kinds()), "no Crystal Kin before the flag")
	GameState.run["flags"]["crystal_kin"] = true
	check("crystal_kin" in Battle.spawner_kinds(), "Crystal Kin at spawners once befriended")
	var cb := Battle.new()
	check(cb._cost("crystal_kin") == 20, "Crystal Kin costs its data cost (%d)" % cb._cost("crystal_kin"))
	cb.free()
	check(Art.tex("helpers", "crystal_kin_crystal_idle_0") != null, "Crystal Kin art present")

	# --- ticket drain (war-table field)
	var m := await go("bf_frostfield")
	var b: Battle = m.get("battle")
	check(b != null, "war-table field starts")
	if b:
		b._briefing = false
		check(Music.instance(self).wanted() == m.area_track(), "battle song from the first frame (%s)" % Music.instance(self).wanted())
		# A helper asked for inside a cliff steps out onto a free cell.
		var blk := Vector2i(-1, -1)
		for c: Vector2i in m.blocked:
			if not m.is_water_cell(c + Vector2i(2, 0)) and not m.blocked.has(c + Vector2i(2, 0)) and c.x + 2 < m.cols - 1 and c.x > 1 and c.y > 1 and c.y < m.rows - 2:
				blk = c
				break
		var spot := HelperUnit.free_spot(m, m.cell_pos(blk.x + 0.5, blk.y + 0.5))
		check(not m.blocked.has(m.world_to_cell(spot)), "free_spot leaves blocked cells")
		var h := HelperUnit.make(m, "shade", m.cell_pos(blk.x + 0.5, blk.y + 0.5), b.points[0]["pos"])
		check(not m.blocked.has(m.world_to_cell(h.position)), "helpers spawn on a free cell")
		# Veil on game time: up now, down 3 s of frames later.
		m.set_meta("stealth_until", HelperUnit.now() + 2.5)
		check(HelperUnit.veiled(m), "veil is up")
		var gt := 0.0
		while gt < 3.0:
			await process_frame
			gt += root.get_process_delta_time()
		check(not HelperUnit.veiled(m), "veil drops after 2.5 s game time")
		if is_instance_valid(h):
			h.queue_free()
		for p in b.points:
			p["owner"] = "ally"
			p["prog"] = 1.0
		b.points[0]["owner"] = "neutral"
		b.points[0]["prog"] = 0.0
		b.tickets["enemy"] = 3
		var key := "battle_" + b.bid
		for i in 6:
			clear(m)
			b._tick()
			if b._over:
				break
		check(b._over and GameState.run["flags"].has(key), "draining their tickets wins")
		await settle()

	# --- siege: take every point
	m = await go("bf_frostfield")
	b = m.get("battle")
	if b:
		b._briefing = false
		b.tickets["enemy"] = 999
		GameState.run["flags"].erase("battle_" + b.bid)
		for p in b.points:
			p["owner"] = "ally"
			p["prog"] = 1.0
		b._tick()
		check(b._over and GameState.run["flags"].has("battle_" + b.bid), "holding every point wins")
		await settle()

	# --- campaign: team on the field + boss kill
	for id: String in ["maple", "gideon", "wren"]:
		GameState.run["friendship"][id] = 5000
	var cid := "c_orchard_hills"
	var bn := node_of(cid, "boss")
	Campaign.cs(cid)["at"] = "n2"
	Campaign.cs(cid)["taken"]["n2"] = true
	b = await fight(cid, bn)
	if b:
		m = b.map
		await frames(4)
		var tm := 0
		for x in get_nodes_in_group("allies"):
			if x is HelperUnit and (x as HelperUnit).team_id != "":
				tm += 1
		check(tm >= 2, "the mustered team takes the field (%d)" % tm)
		for i in 10:
			b._tick()
			if b._boss_ref != null:
				break
		var bb := b._boss_ref
		b._count_kills()
		check(bb != null and is_instance_valid(bb), "the captain takes the field")
		if bb:
			check(bb.max_hp <= 96, "T1 captain HP <= 96 (%d)" % bb.max_hp)
			check(Music.instance(self).wanted() in GameMap.BOSS_TRACKS, "boss theme plays (%s)" % Music.instance(self).wanted())
			check(DangerMusic.tier == 4, "DangerMusic holds the boss tier")
			await frames(30)
			check(Music.instance(self).wanted() in GameMap.BOSS_TRACKS, "boss theme holds on the field")
			check(not b._goal_text().to_lower().contains("captain captain"), "goal line names the captain once (%s)" % b._goal_text())
			var tms: Array = b.team
			if tms.size() >= 2:
				check((tms[0] as HelperUnit).tag_row != (tms[1] as HelperUnit).tag_row, "team name tags alternate rows")
			b._elapsed = 10.0
			b._team_push()
			check(m.has_meta("team_push"), "early fight: the team pushes on its own")
			# Close the game mid-fight with the captain hurt: it comes back hurt.
			bb.hp = 30
			b._keep()
			check(int(Campaign.st()["fight"]["state"].get("boss_hp", -1)) == 30, "the fight record keeps the captain's health")
			var bf: Dictionary = Campaign.st()["fight"].duplicate(true)
			b._over = true
			Campaign.st()["fight"] = bf
			var mr := await go(str(bf["field"]))
			var br: Battle = mr.get("battle") if mr else null
			if br:
				br._briefing = false
				mr.player.invuln = 9999.0
				for i in 10:
					br._tick()
					if br._boss_ref != null:
						break
				check(br._boss_ref != null and br._boss_ref.hp == 30, "reopened fight: the captain is as hurt as you left them (%s)" % (str(br._boss_ref.hp) if br._boss_ref else "none"))
				if br._boss_ref:
					b = br
					m = mr
					bb = br._boss_ref
					b._count_kills()
					await frames(10)
			bb.hit(99999, bb.position + Vector2(10, 0), false, false)
			await frames(3)
			b._count_kills()
			check(b._boss_down, "the captain's fall is counted")
			check(DangerMusic.tier == 0, "boss music winds down at once")
			check(Music.instance(self).wanted() == m.area_track(), "back to the fight's song")
			b._tick()
			check(b._over and Campaign.taken(cid, bn), "killing the captain wins the boss node")
		await settle()

	# --- defend: hold out the timer
	var hcid := "c_highlands"
	GameState.run["flags"]["c_orchard_hills_won"] = true
	var dn := ""
	for c: String in Campaign.all():
		if Campaign.get_c(c).get("arc", "both") in ["both", "penguins"] and node_of(c, "defend") != "":
			hcid = c
			dn = node_of(c, "defend")
			break
	if dn != "":
		b = await fight(hcid, dn)
		if b:
			check(b.win_by == "hold", "defend node holds (%s)" % b.win_by)
			b.points[0]["owner"] = "ally"
			b._hold = 1.0
			b._tick()
			b._tick()
			check(b._over and Campaign.taken(hcid, dn), "holding out the timer wins (%s %s)" % [hcid, dn])
			await settle()
	else:
		print("  (no defend node in this arc's campaigns)")

	# --- escort: convoy lost, then convoy arrives
	var ecid := "c_wastes"
	var en := node_of(ecid, "escort")
	b = await fight(ecid, en)
	if b:
		check(b.convoy != null, "escort has a convoy")
		if b.convoy:
			b.convoy.hp = 0
			b._tick()
			check(b._over and not Campaign.taken(ecid, en), "a destroyed convoy loses")
		await settle()
	b = await fight(ecid, en)
	if b and b.convoy:
		b.convoy.arrived = true
		b._tick()
		check(b._over and Campaign.taken(ecid, en), "an arrived convoy wins")
		await settle()

	# --- a fight reopened from a save resumes (tickets, supply, point owners)
	var sn := node_of("c_highlands", "skirmish")
	b = await fight("c_highlands", sn)
	if b:
		b.tickets = {"ally": 77, "enemy": 33}
		b.supply = 41
		b.points[0]["owner"] = "ally"
		b.points[0]["prog"] = 1.0
		b._keep()
		var f: Dictionary = Campaign.st()["fight"].duplicate(true)
		b._over = true  # leave without a retreat (as if the game closed)
		Campaign.st()["fight"] = f
		var m2 := await go(str(f["field"]))
		var b2: Battle = m2.get("battle") if m2 else null
		check(b2 != null and int(b2.tickets["ally"]) == 77 and int(b2.tickets["enemy"]) == 33 and b2.supply == 41, "reopened fight keeps tickets and supply (%s)" % (str(b2.tickets) + " " + str(b2.supply) if b2 else "none"))
		check(b2 != null and str(b2.points[0]["owner"]) == "ally", "reopened fight keeps who holds the points")
		if b2:
			b2._over = true
		Campaign.st()["fight"] = {}

	# --- gangster battles play their own funk/noir variants
	GameState.new_run("gangsters", "dad", "T", "Town", "Pup")
	GameState.run["flags"]["proj_war_table"] = true
	GameState.run["flags"]["crystal_kin"] = true
	check(not ("crystal_kin" in Battle.spawner_kinds()), "no Crystal Kin in the gangster arc")
	m = await go("bf_frostfield")
	if m:
		check(Music.instance(self).wanted() == "battle_gang", "gangster field: battle_gang (%s)" % Music.instance(self).wanted())
		var gb: Battle = m.get("battle")
		if gb:
			gb.mode = "siege"
			check(m.area_track() == "battle_siege_gang", "gangster siege: battle_siege_gang (%s)" % m.area_track())
			gb.mode = "escort"
			check(m.area_track() in ["battle_escort", "battle_escort_gang"], "gangster escort keeps an escort song (%s)" % m.area_track())

	print("battle_win_test: %d fails" % fails)
	quit(1 if fails else 0)
