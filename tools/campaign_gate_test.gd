extends SceneTree
## The campaign lead-in: day-one locks, the training drill played step by step
## (move, build, rally follow, point menu, rally to a point, capture), the
## battle briefing card (pauses, can be hidden after the first view), the
## campaign briefing on the board and mustering.
##   godot --headless --path . -s res://tools/campaign_gate_test.gd
## With an output folder (and a renderer) it saves screenshots:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/campaign_gate_test.gd -- /tmp/shots
var fails := 0
var out := ""
## ARC=gangsters runs the same lead-in for the gangster arc (Sal, Hideout town).
var arc := "penguins"


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(7)
	_run.call_deferred()


func _shot(name: String) -> void:
	if out == "":
		return
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _brief() -> BattleBrief:
	var sc := current_scene
	if sc:
		for n in sc.get_children():
			if n is BattleBrief and not n.is_queued_for_deletion():
				return n
	return null


func _screen() -> CampaignScreen:
	var sc := current_scene
	if sc:
		for n in sc.get_children():
			if n is CampaignScreen and not n.is_queued_for_deletion():
				return n
	return null


func _talk(frames := 30) -> void:
	for i in frames:
		var d := Dialogue.instance(self)
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame


func _arrive(sc: String, limit := 500) -> GameMap:
	for i in limit:
		var gm := current_scene as GameMap
		if gm != null and gm.scene_id() == sc and gm.player != null and not gm._changing:
			for k in 6:
				await process_frame
			return gm
		var d := Dialogue.instance(self)
		if d.active and _brief() == null:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	return current_scene as GameMap


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	Campaign.bypass = false
	if OS.get_environment("ARC") == "gangsters":
		arc = "gangsters"
	print("arc: " + arc)
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["hp"] = 999
	GameState.run["max_hp"] = 999
	GameState.run["party"] = {}
	# ---- day one ------------------------------------------------------------------
	check(not CampaignGate.story_ok() and not CampaignGate.trained(), "day one: no story, no training")
	check(CampaignGate.drill_lock() != "", "the drill waits for chapter 2")
	for cid: String in Campaign.for_arc():
		check(Campaign.why_locked(cid) != "" and Campaign.plan_lock(cid) != "", "%s is locked on day one" % cid)
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	var m := await _arrive("town")
	CampaignScreen.open(m, "")
	await process_frame
	await _shot("gate_list_locked")
	var scr := _screen()
	check(scr != null and scr._list.visible, "the campaign list opens and explains the lock")
	scr._start_drill()
	await process_frame
	check(Campaign.st()["fight"].is_empty(), "the drill can't start before chapter 2")
	scr.close()
	await process_frame
	# ---- chapter 2: the veteran's invite and the drill ---------------------------------
	check(CampaignGate.story_need() != "", "the lock says which story step opens it")
	GameState.run["flags"]["meow_taught" if arc == "penguins" else "hideout_seen"] = true
	check(CampaignGate.story_ok() and CampaignGate.drill_lock() == "", "chapter 2 opens the drill")
	check(CampaignGate.trainer() == ("Catkins" if arc == "penguins" else "Sal"), "the veteran is %s" % CampaignGate.trainer())
	var invite := false
	for b in Story.beats():
		if str(b["id"]) == ("bt_invite_p" if arc == "penguins" else "bt_invite_g") and Story._ready_beat(b, m):
			invite = true
	check(invite, "the veteran's invite beat is ready at chapter 2")
	check(Campaign.why_locked("c_orchard_hills").contains("Train"), "campaigns now wait for training")
	CampaignScreen.open(m, "")
	await process_frame
	await _shot("gate_list_training")
	_screen()._start_drill()
	m = await _arrive("bf_orchard_line")
	check(m != null and m.scene_id() == "bf_orchard_line", "the drill is fought on the orchard field")
	var bt: Battle = m.get("battle")
	check(bt != null and bt.is_drill and bt.drill != null, "the battle runs as the drill")
	check(bt.points.size() == 3, "three points close together")
	for i in 20:
		await process_frame
	var bb := _brief()
	check(bb != null and paused, "the briefing card opens and pauses the game")
	await _shot("gate_drill_briefing")
	if bb:
		bb._arm = 99.0
		bb._close()
	await process_frame
	check(_brief() == null and (not paused or Dialogue.instance(self).active), "Begin training unpauses (or the veteran starts talking)")
	check(GameState.run["flags"].has("bb_seen_drill"), "the card is marked as seen")
	await _talk(40)
	await _shot("gate_drill_step1")
	var dr := bt.drill
	check(dr.step == 0 and not dr.waves_on(), "step 1: move, and no foes yet")
	# 1 move: stand in the Scarecrow Post ring.
	var post := bt.point("d")
	m.player.position = post["pos"]
	post["prog"] = 0.9  # most of the ring filled: the rest must come from standing in it
	for i in 900:
		await process_frame
		if dr.step > 0:
			break
		if Dialogue.instance(self).active:
			await _talk(5)
	check(dr.step == 1 and str(post["owner"]) == "ally", "standing in the ring takes the point (step %d)" % dr.step)
	await _talk(20)
	# 2 build: a striker at the post.
	post["spawner"] = "striker"
	post["t"] = 10.0
	for i in 120:
		await process_frame
		if dr.step > 1:
			break
	check(dr.step == 2, "building a helper passes step 2")
	await _talk(20)
	# 3 rally follow
	bt._set_rally(-1)
	for i in 120:
		await process_frame
		if dr.step > 2:
			break
	check(dr.step == 3 and m.has_meta("follow_me"), "RALLY follow me passes step 3")
	await _talk(20)
	await _shot("gate_drill_follow")
	# 4 point menu: fortify
	post["fort"] = true
	for i in 120:
		await process_frame
		if dr.step > 3:
			break
	check(dr.step == 4, "the point menu passes step 4")
	await _talk(20)
	# 5 rally to the mill
	var mill_i := 0
	for i in bt.points.size():
		if str(bt.points[i]["id"]) == "b":
			mill_i = i
	bt._set_rally(mill_i)
	for i in 120:
		await process_frame
		if dr.step > 4:
			break
	check(dr.step == 5 and dr.waves_on(), "rallying to the mill passes step 5 and the foes come")
	await _talk(20)
	await _shot("gate_drill_rally")
	check(bt._goal_text().contains("TRAINING"), "the objective banner says what to do")
	# 6 take the mill
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	var mill := bt.point("b")
	mill["prog"] = 1.0
	mill["owner"] = "ally"
	m = await _arrive("town", 900)
	check(m != null and m.scene_id() == "town", "the drill ends back where it started (%s, paused %s, dlg %s)" % [m.scene_id() if m else "null", paused, Dialogue.instance(self).active])
	check(CampaignGate.trained(), "training is done")
	check(Campaign.why_locked("c_orchard_hills").begins_with("Recruit"), "now campaigns ask for a team and provisions: %s" % Campaign.why_locked("c_orchard_hills"))
	for i in 120:
		await process_frame
		await _talk(2)
	var rs := _screen()
	check(rs != null, "the campaign map opens again after training")
	if rs:
		rs.close()
	await process_frame
	# ---- the board briefing and mustering -----------------------------------------
	CampaignScreen.open(m, "c_orchard_hills")
	await process_frame
	scr = _screen()
	check(scr._brief.visible, "a campaign opens with its briefing card")
	await _shot("gate_board_briefing")
	scr._brief.visible = false
	check(scr._acts.is_empty() or str(scr._acts[0][0]) == "What's needed", "no attack before mustering")
	Companion.recruit("dad", false)
	Companion.recruit("mom", false)
	GameState.add_item("wood", 40)
	GameState.add_item("stone", 20)
	GameState.run["crystals"] = 1000
	scr._refresh()
	check(not scr._acts.is_empty() and str(scr._acts[0][0]).begins_with("⚑ Muster"), "with a team and provisions: Muster")
	await _shot("gate_board_muster")
	scr._muster()
	await process_frame
	check(Campaign.started("c_orchard_hills"), "mustered")
	var can := false
	for n in Campaign.get_c("c_orchard_hills")["nodes"]:
		if Campaign.can_attack("c_orchard_hills", str(n["id"])):
			can = true
	check(can, "after mustering a territory can be attacked")
	await _shot("gate_board_mustered")
	# ---- a campaign battle's briefing; hide it next time ----------------------------
	var target := ""
	for n in Campaign.get_c("c_orchard_hills")["nodes"]:
		if Campaign.can_attack("c_orchard_hills", str(n["id"])) and str(n["type"]) not in Campaign.NONBATTLE:
			target = str(n["id"])
	scr._close_now()
	await process_frame
	if target != "":
		Campaign.launch(m, "c_orchard_hills", target)
		m = await _arrive(str(Campaign.cfg("c_orchard_hills", target)["field"]))
		for i in 20:
			await process_frame
		bb = _brief()
		check(bb != null and bb._hide == null, "the first battle of a kind: full card, no hide button")
		await _shot("gate_battle_briefing")
		if bb:
			bb._arm = 99.0
			bb._close()
		await _talk(30)
		bt = m.get("battle")
		check(bt._goal_text() != "", "every battle shows an objective")
		m.player.position = bt.points[0]["pos"]
		bt._set_rally(1)
		for i in 30:
			await process_frame
		await _shot("gate_battle_hud")
		check(BattleBrief.seen(bt.mode), "seen flag set")
		GameState.run["flags"]["bb_hide_" + bt.mode] = true
		var d2 := bt.d.duplicate()
		await BattleBrief.show_for(m, d2)
		check(_brief() == null, "a hidden kind of fight only gets a toast")
	print("campaign_gate_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
