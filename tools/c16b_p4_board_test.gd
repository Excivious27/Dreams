extends SceneTree
## C16b P4: the campaign board with the reward ladder, both arcs. The list intro no longer
## says regions are held until you win (optional battles); won/opened rows use the ✓ icon
## and normal tint with stars and what is left; the card shows foe level as dots (★ only
## for earned stars), the ladder line and star goals; a won board offers the next campaign;
## the briefing has a YOU WIN section; every card button sits inside the 270x480 screen
## even with many actions (c16b_10-08); no text below 7 px.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c16b_p4_board_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		fails += 1


func _initialize() -> void:
	seed(16)
	_run.call_deferred()


func _screen() -> CampaignScreen:
	for n in current_scene.get_children():
		if n is CampaignScreen and not n.is_queued_for_deletion():
			return n
	return null


func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(str(n.get("text")))
	for c in n.get_children():
		_texts(c, out)


func _fonts_ok(n: Node) -> bool:
	if (n is Label or n is Button) and (n as Control).has_theme_font_size_override("font_size"):
		if (n as Control).get_theme_font_size("font_size") < 7:
			return false
	for c in n.get_children():
		if not _fonts_ok(c):
			return false
	return true


func _shot(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [args[0], name])


func _run() -> void:
	InputSetup.ensure_actions()
	Campaign.bypass = false
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		GameState.run["party"] = {}
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/town.tscn")
		for i in 40:
			await process_frame
		var m := current_scene as GameMap
		check(m != null, "%s: town loads" % arc)
		var c0: String = Campaign.for_arc()[0]
		var c1: String = Campaign.for_arc()[1]
		# Win the first campaign outright (every node, 3 stars on one).
		for n: Dictionary in Campaign.get_c(c0)["nodes"]:
			Campaign.cs(c0)["taken"][str(n["id"])] = true
		Campaign.st()["won"][c0] = 1
		Campaign.st()["open"][str(Campaign.get_c(c0)["region"])] = true
		var nid: String = BattleRewards.camp(c0)["nodes"].keys()[0]
		BattleRewards.on_win(c0, nid, 3, {})
		CampaignScreen.open(m, "")
		await process_frame
		await process_frame
		var scr := _screen()
		check(scr != null, "%s: list opens" % arc)
		if scr == null:
			continue
		var tx: Array = []
		_texts(scr, tx)
		var all := "\n".join(tx)
		await _shot(arc + "_list")
		check(not all.contains("Each new region is held"), "%s: intro no longer says regions are held" % arc)
		check(all.contains("long way"), "%s: intro names the long way" % arc)
		var row := ""
		for t: String in tx:
			if t.contains(str(Campaign.get_c(c0)["title"])):
				row = t
		check(row.begins_with("✓") and row.contains("won · ★ 3/") and row.contains("replay for more"), "%s: won row shows stars and what is left: %s" % [arc, row])
		check(_fonts_ok(scr), "%s: list text >= 7 px" % arc)
		# c16b_10-10: the campaign the story needs next is tagged.
		var sreg := "wastes" if arc == "penguins" else "docks"
		var sq := "wastes_gate" if arc == "penguins" else "docks"
		GameState.run["quests"].append({"id": sq, "text": "x", "done": false})
		scr._show_list()
		await process_frame
		tx = []
		_texts(scr, tx)
		var srow := ""
		for t2: String in tx:
			if t2.contains(str(Campaign.get_c(Campaign.gate_of(sreg))["title"])):
				srow = t2
		check(srow.contains("▶ your story goes here") or Campaign.region_open(sreg), "%s: story campaign tagged: %s" % [arc, srow])
		# The won board: next campaign, ladder lines.
		scr._show_board(c0)
		scr._brief.visible = false
		scr.sel = nid
		scr._refresh()
		await process_frame
		await _shot(arc + "_won_board")
		check(scr._sub.text.contains("Foe Lv") or not scr._sub.text.contains("★"), "%s: foe level is dots, not stars: %s" % [arc, scr._sub.text])
		check(scr._body.text.contains("Best ★★★"), "%s: card shows best stars: %s" % [arc, scr._body.text])
		check(scr._body.text.contains("First clear") and scr._body.text.contains("Mastery"), "%s: won card shows the ladder preview" % arc)
		var has_next := false
		for a: Array in scr._acts:
			if str(a[0]).begins_with("Next: "):
				has_next = true
		check(has_next == (scr._next_campaign() != ""), "%s: won board offers the next campaign" % arc)
		scr._show_brief()
		await process_frame
		tx = []
		_texts(scr._brief_box, tx)
		await _shot(arc + "_brief")
		check("\n".join(tx).contains("YOU WIN") and "\n".join(tx).contains("First clear"), "%s: briefing says what winning gives" % arc)
		check(_fonts_ok(scr._brief_box), "%s: brief text >= 7 px" % arc)
		scr._brief.visible = false
		# c16b_10-08: many actions still fit the screen.
		scr._show_board(c1)
		scr._brief.visible = false
		scr._all_acts = []
		for k in 6:
			scr._all_acts.append(["A long action label number %d here" % k, func() -> void: pass])
		scr._build_acts()
		check(scr._acts.size() == 4 and str(scr._acts[3][0]).begins_with("More"), "%s: 6 actions page behind More" % arc)
		await _shot(arc + "_more")
		scr._more_acts()
		check(str(scr._acts[0][0]).ends_with("3 here"), "%s: More shows the next page" % arc)
		for i in 4:
			await process_frame
		for b: Control in scr._btns.get_children():
			var r := b.get_global_rect()
			check(r.position.x >= 0 and r.end.x <= 270 and r.end.y <= 480, "%s: action button inside the screen %s" % [arc, r])
		scr.close()
		for i in 4:
			await process_frame
	print("c16b_p4_board_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
