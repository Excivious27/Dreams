extends SceneTree
## Region campaigns: data sanity for every board, region locks, then one whole
## campaign played through (camps/caches settled, battles forced won, one lost),
## save round trip, old-save migration and the gangster arc's list.
##   godot --headless --path . -s res://tools/campaign_map_test.gd
## With an output folder (and a renderer) it also saves screenshots of the board:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/campaign_map_test.gd -- /tmp/shots
var fails := 0
var out := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _drain(frames := 60) -> void:
	for i in frames:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame


func _go(sc: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	for i in 14:
		await process_frame
	await _drain(20)
	return current_scene as GameMap


## Wait until the current scene is `sc` (a go_to fades first).
func _arrive(sc: String, limit := 400) -> GameMap:
	for i in limit:
		var gm := current_scene as GameMap
		if gm != null and gm.scene_id() == sc and gm.player != null and not gm._changing:
			for k in 6:
				await process_frame
			return gm
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	return current_scene as GameMap


func _screen(m: GameMap) -> CampaignScreen:
	for n in m.get_children():
		if n is CampaignScreen:
			return n
	return null


func _shot(name: String) -> void:
	if out == "":
		return
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	_data_checks()
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	GameState.run["hp"] = 999
	GameState.run["max_hp"] = 999
	# ---- locks -----------------------------------------------------------------
	check(not Campaign.region_open("orchard_hills"), "a fresh run starts with the orchard hills held")
	check(Campaign.region_open("farm") and Campaign.region_open("town"), "home areas are never held")
	check(Campaign.gate_of("sky") == "c_sky" and Campaign.gate_of("docks") == "", "penguin run: sky is a campaign, the docks aren't this arc's")
	check(Campaign.why_locked("c_sky") != "", "the sky waits for the wastes and the story")
	check(Campaign.why_locked("c_orchard_hills") == "", "the orchard road can be fought at once")
	var m := await _go("town")
	check(m != null and m.scene_id() == "town", "town loads")
	check(Campaign.blocks(m, "orchard_hills"), "walking to a held region is stopped")
	await _drain(20)
	check(not Campaign.blocks(m, "beach"), "an open area isn't stopped")
	# ---- the board ----------------------------------------------------------------
	CampaignScreen.open(m, "")
	await process_frame
	var scr := _screen(m)
	check(scr != null and scr._list.visible, "the campaign list opens")
	await _shot("campaign_list")
	scr._show_board("c_orchard_hills")
	await process_frame
	check(scr.cid == "c_orchard_hills" and not scr._acts.is_empty(), "the board shows the orchard road with an action")
	await _shot("campaign_board_start")
	scr.close()
	await process_frame
	# ---- play the orchard road through -------------------------------------------
	var cid := "c_orchard_hills"
	var c := Campaign.get_c(cid)
	var lost_once := false
	var modes_seen := {}
	var guard := 0
	while not Campaign.is_won(cid) and guard < 14:
		guard += 1
		var target := ""
		for n in c["nodes"]:
			if Campaign.can_attack(cid, str(n["id"])):
				target = str(n["id"])
				break
		if target == "":
			# Nothing next to the army: march back over held ground to a node that has a neighbour to take.
			for n in c["nodes"]:
				var stg := Campaign.staging(cid, str(n["id"]))
				if stg != "":
					check(Campaign.march(cid, stg) or stg == str(Campaign.cs(cid)["at"]), "the army can march over held ground")
					target = str(n["id"])
					break
		check(target != "" and Campaign.can_attack(cid, target), "there is always a node to attack (step %d)" % guard)
		if target == "":
			break
		var nd := Campaign.node(cid, target)
		var typ := str(nd["type"])
		if typ in ["camp", "cache"]:
			var ch: Array = Campaign.board_choices(cid, target)
			check(not ch.is_empty(), "%s offers choices" % typ)
			var before := int(Campaign.cs(cid)["supply"]) + int(Campaign.cs(cid)["morale"])
			Campaign.settle(cid, target, str(ch[0][0]))
			check(Campaign.taken(cid, target) and str(Campaign.cs(cid)["at"]) == target, "settling %s takes it and moves the army" % typ)
			check(int(Campaign.cs(cid)["supply"]) + int(Campaign.cs(cid)["morale"]) > before or before >= 180, "%s helps the army" % typ)
			continue
		var field := str(Campaign.cfg(cid, target)["field"])
		Campaign.launch(m, cid, target)
		m = await _arrive(field)
		check(m != null and m.scene_id() == field, "%s is fought on %s" % [str(nd["name"]), field])
		if m == null or m.scene_id() != field:
			break
		var bt: Battle = m.get("battle")
		check(bt != null and bt.camp == cid, "the battle knows it's a campaign node")
		if bt == null:
			break
		check(bt.mode == typ, "battle mode %s (got %s)" % [typ, bt.mode])
		modes_seen[typ] = true
		var want_pts: Array = Campaign.cfg(cid, target)["points"]
		check(bt.points.size() == want_pts.size(), "node points used (%d)" % bt.points.size())
		check(int(bt.d.get("enemy_tier", -1)) == Campaign.enemy_tier(cid, target), "enemy level follows the node")
		match typ:
			"escort":
				check(bt.convoy != null and is_instance_valid(bt.convoy), "escort: the convoy rolls out")
				await _shot("campaign_escort")
			"defend":
				check(bt.points.any(func(p: Dictionary) -> bool: return bool(p["gate"])) and bt.win_by == "hold", "defend: enemy gates and a timer")
				await _shot("campaign_defend")
			"siege", "gate":
				check(bt.points.any(func(p: Dictionary) -> bool: return bool(p["efort"])), "%s: fortified enemy points" % typ)
				check(bt.d.has("boss") == (typ == "gate"), "only the gate brings a commander (siege)")
				if typ == "gate":
					await _shot("campaign_gate")
			"boss":
				check(bt.win_by == "boss" and bt.d.has("boss"), "boss node: bring down the captain")
		var exit_ok := false
		for e in m.exits:
			if str(e["label"]).contains("fall back") and str(e["scene"]) == "town":
				exit_ok = true
		check(exit_ok, "falling back leads to where the board was opened")
		var morale0 := int(Campaign.cs(cid)["morale"])
		if not lost_once:
			lost_once = true
			bt._end(false)
			m = await _arrive("town")
			check(not Campaign.taken(cid, target), "a lost battle takes nothing")
			check(int(Campaign.cs(cid)["morale"]) < morale0, "a loss costs morale")
			check(int(Campaign.cs(cid)["losses"]) == 1, "the loss is counted")
			for k in 90:
				await process_frame
			var rs := _screen(m)
			check(rs != null, "the board opens again after the fight")
			if rs:
				rs.close()
			await process_frame
			continue
		var cr0 := int(GameState.run["crystals"])
		bt._end(true)
		m = await _arrive("town")
		check(Campaign.taken(cid, target), "%s taken after a win" % str(nd["name"]))
		check(int(GameState.run["crystals"]) > cr0, "a win pays")
		for k in 90:
			await process_frame
		var rs2 := _screen(m)
		if rs2:
			if typ != "gate":
				await _shot("campaign_board_mid")
			rs2.close()
		await process_frame
	check(Campaign.is_won(cid), "the orchard road is won")
	check(Campaign.region_open("orchard_hills"), "the orchard hills are open")
	check(not Campaign.blocks(m, "orchard_hills"), "and the road lets you through")
	check(GameState.run["flags"].has("campaign_orchard_hills"), "the win leaves a flag for the story/menus")
	check(Campaign.why_locked("c_highlands") == "", "winning the orchards opens the highland campaign")
	check(modes_seen.size() >= 3, "several node types were fought (%s)" % ", ".join(modes_seen.keys()))
	# ---- a retreat --------------------------------------------------------------
	cid = "c_marsh"
	var first := ""
	for n in Campaign.get_c(cid)["nodes"]:
		if Campaign.can_attack(cid, str(n["id"])) and str(n["type"]) not in Campaign.NONBATTLE:
			first = str(n["id"])
			break
	if first != "":
		var mo := int(Campaign.cs(cid)["morale"])
		Campaign.launch(m, cid, first)
		m = await _arrive(str(Campaign.cfg(cid, first)["field"]))
		m.go_to("town", Vector2.ZERO)
		m = await _arrive("town")
		check(int(Campaign.cs(cid)["retreats"]) == 1 and int(Campaign.cs(cid)["morale"]) < mo, "walking off the field is a retreat")
		check(Campaign.st()["fight"].is_empty(), "the retreat ends the fight")
		await _drain(20)
		var rs3 := _screen(m)
		if rs3:
			rs3.close()
	# ---- save round trip --------------------------------------------------------
	GameState.save()
	var saved: Dictionary = SaveGame.get_value(GameState.save_key())
	var back: Dictionary = JSON.parse_string(JSON.stringify(saved))
	GameState.run = back
	check(Campaign.is_won("c_orchard_hills") and Campaign.region_open("orchard_hills"), "the win survives a save")
	check(int(Campaign.cs("c_marsh")["retreats"]) == 1, "campaign progress survives a save")
	# ---- old saves: places you've been stay open ----------------------------------
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["visited"] = {"marsh": [10, 10]}
	GameState.run["flags"]["sky_seen"] = true
	check(Campaign.region_open("marsh") and Campaign.region_open("sky"), "an old save keeps the regions it has seen")
	check(not Campaign.region_open("quarry"), "but not the ones it hasn't")
	# ---- gangster arc --------------------------------------------------------------
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var gl := Campaign.for_arc()
	check(gl.has("c_docks") and gl.has("c_underground") and not gl.has("c_sky"), "gangster run: its own campaigns")
	check(Campaign.gate_of("sky") == "" and Campaign.gate_of("neon") == "c_neon", "gangster run: sky isn't gated, neon is")
	check(Campaign.why_locked("c_neon") != "" and Campaign.why_locked("c_docks") == "", "neon waits for the docks")
	m = await _go("hideout")
	if m:
		CampaignScreen.open(m, "c_docks")
		await process_frame
		await _shot("campaign_board_gang")
		var gs := _screen(m)
		if gs:
			gs.close()
		await process_frame
		# An escort node: the convoy rolls with you and reaches its goal.
		var esc := ""
		for n in Campaign.get_c("c_docks")["nodes"]:
			if str(n["type"]) == "escort" and Campaign.can_attack("c_docks", str(n["id"])):
				esc = str(n["id"])
		check(esc != "", "the docks open with an escort")
		if esc != "":
			Campaign.launch(m, "c_docks", esc)
			m = await _arrive(str(Campaign.cfg("c_docks", esc)["field"]))
			var bt: Battle = m.get("battle")
			check(bt != null and bt.convoy != null, "escort: the convoy rolls out")
			await _drain(30)
			if bt and bt.convoy:
				for e in m.enemies:
					if is_instance_valid(e):
						e.queue_free()
				m.player.position = bt.convoy.position + Vector2(0, 20)
				var p0 := bt.convoy.position
				for k in 40:
					await process_frame
				m.player.position = bt.convoy.position + Vector2(0, 20)
				await _shot("campaign_escort")
				check(bt.convoy.position.distance_to(p0) > 4.0 or bt.convoy.state == "blocked", "the convoy rolls while you walk with it (%s)" % bt.convoy.state)
				bt.convoy.arrived = true
				for k in 90:
					await process_frame
				await _drain(30)
				m = await _arrive("hideout")
				check(Campaign.taken("c_docks", esc), "a convoy that arrives wins the node")
	print("campaign_map_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)


func _data_checks() -> void:
	var regions: Dictionary = GameState.load_json("res://data/regions.json")
	var all := Campaign.all()
	check(all.size() >= 18, "campaign data loaded (%d)" % all.size())
	for cid: String in all:
		var c: Dictionary = all[cid]
		var nodes: Array = c["nodes"]
		check(nodes.size() - 1 >= 4 and nodes.size() - 1 <= 7, "%s has 4-7 territories" % cid)
		check(ResourceLoader.exists("res://scenes/%s.tscn" % str(c["region"])), "%s opens a real region" % cid)
		var ids := {}
		for n in nodes:
			ids[str(n["id"])] = n
		# The gate can be reached from the camp, by more than one route.
		var gate := ""
		for n in nodes:
			if str(n["type"]) == "gate":
				gate = str(n["id"])
		check(gate != "", "%s has a gate" % cid)
		var seen := {"n0": true}
		var q: Array = ["n0"]
		while not q.is_empty():
			var cur: String = q.pop_front()
			for l in ids[cur]["links"]:
				if not seen.has(str(l)):
					seen[str(l)] = true
					q.append(str(l))
		check(seen.has(gate) and seen.size() == nodes.size(), "%s: every node is connected" % cid)
		check((ids["n0"]["links"] as Array).size() >= 2, "%s branches from the start" % cid)
		for n in nodes:
			for a: String in n.get("cfg", {}):
				var cf: Dictionary = n["cfg"][a]
				check(regions.has(str(cf["field"])) and ResourceLoader.exists("res://scenes/%s.tscn" % str(cf["field"])), "%s/%s field %s exists" % [cid, n["id"], cf["field"]])
				var pids := {}
				for p in cf["points"]:
					pids[str(p["id"])] = true
				check(pids.size() == (cf["points"] as Array).size(), "%s/%s points are unique" % [cid, n["id"]])
				check((cf["points"] as Array).any(func(p: Dictionary) -> bool: return str(p["owner"]) == "ally"), "%s/%s starts with a camp point" % [cid, n["id"]])
				for k in cf.get("convoy", []):
					check(pids.has(str(k)), "%s/%s convoy stop %s is a point" % [cid, n["id"], k])
				for k in cf["enemies"]:
					check(GameState.enemy_data.get("enemies", {}).has(str(k)), "%s enemy %s exists" % [cid, k])
