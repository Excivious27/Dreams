extends SceneTree
## The training drill from the player's side (Tom's playtest, C11b P7): no helper
## until you pick "Build helper" at a banner, the helper follows you as you walk,
## each order in the HELPERS list says plainly what it does and works (Follow me,
## Hold here, Go to a point), and "Leave training" (button, confirm, or the pause
## menu row on a pad) ends it at any step: back on the map, unpaused, no stray
## modal rects, not trained, and the drill starts again.
##   godot --headless --fixed-fps 60 --path . -s res://tools/battle_drill_flow_test.gd   (ARC=gangsters too)
var fails := 0
var arc := "penguins"


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(11)
	_run.call_deferred()


func _brief() -> BattleBrief:
	var sc := current_scene
	if sc:
		for n in sc.get_children():
			if n is BattleBrief and not n.is_queued_for_deletion():
				return n
	return null


func _talk(frames := 30) -> void:
	for i in frames:
		var d := Dialogue.instance(self)
		if d.active and not d._in_choice:
			d._advance()
		await process_frame


func _arrive(sc: String, limit := 600) -> GameMap:
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


func _choices() -> Array:
	var o: Array = []
	for c in Dialogue.instance(self)._choices.get_children():
		o.append(str(c.get("text")) if c.get("text") != null else "")
	return o


func _find(opts: Array, word: String) -> int:
	for i in opts.size():
		if str(opts[i]).contains(word):
			return i
	return -1


func _helper() -> HelperUnit:
	for n in get_nodes_in_group("allies"):
		if n is HelperUnit and is_instance_valid(n):
			return n
	return null


## Walk the hero n px along dir, a little each frame (blocked cells stop the walk).
func _walk(m: GameMap, dir: Vector2, px: float) -> void:
	var went := 0.0
	var tries := 0
	while went < px and tries < 400:
		tries += 1
		var np: Vector2 = m.player.position + dir * 0.9
		if m.blocked.has(m.world_to_cell(np)):
			dir = Vector2(-dir.y, dir.x)  # turn at a wall
			continue
		m.player.position = np
		went += 0.9
		await process_frame


## Start the drill from town and close the briefing card.
func _enter(m: GameMap) -> Array:
	CampaignGate.launch_drill(m)
	m = await _arrive("bf_orchard_line")
	var bt: Battle = m.get("battle") if m else null
	for i in 20:
		await process_frame
	var bb := _brief()
	if bb:
		bb._arm = 99.0
		bb._close()
	await process_frame
	await _talk(60)
	return [m, bt]


func dr_ready(bt: Battle) -> bool:
	return bt.drill != null and bt.drill._said == bt.drill.step


func _left_ok(m: GameMap, what: String) -> void:
	# The campaign map reopens (where Training is started): it is a proper screen; close it.
	for i in 150:
		await process_frame
	var cs: CampaignScreen = null
	for n in current_scene.get_children():
		if n is CampaignScreen and not n.is_queued_for_deletion():
			cs = n
	check(cs != null, "%s: the campaign map is back, Training ready to retry" % what)
	if cs:
		cs.close()
	for i in 10:
		await process_frame
	check(m != null and m.scene_id() == "town", "%s: back in town (%s)" % [what, m.scene_id() if m else "null"])
	check(not paused, "%s: the game is not paused" % what)
	check(not Hud.extra_rects.has(BattleDrill.LEAVE_RECT) and not Hud.extra_rects.has(Battle.RALLY_RECT), "%s: no stray button rects" % what)
	check(Hud.modal_rect.size == Vector2.ZERO, "%s: no modal rect left" % what)
	check(not CampaignGate.trained() and Campaign.st()["fight"].is_empty(), "%s: not trained, no fight left open" % what)
	check(CampaignGate.drill_lock() == "", "%s: the drill can be started again" % what)


func _run() -> void:
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
	GameState.run["flags"]["meow_taught" if arc == "penguins" else "hideout_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	var m := await _arrive("town")
	# ---- 1. leave at step 1 with the button's confirm ------------------------------
	var r := await _enter(m)
	m = r[0]
	var bt: Battle = r[1]
	check(bt != null and bt.is_drill and bt.drill != null, "the drill runs")
	var dr := bt.drill
	check(dr.leave_btn != null and dr.leave_btn.visible and dr.leave_btn.text == "Leave training", "a Leave training button is on screen")
	check(Hud.extra_rects.has(BattleDrill.LEAVE_RECT), "the button gets taps (extra rect)")
	check(BattleDrill.LEAVE_RECT.size.y >= 20, "the button is a comfortable tap")
	dr.ask_leave()
	await process_frame
	var opts := _choices()
	check(opts.size() == 2 and Dialogue.is_way_out(str(opts[1])) and not Dialogue.is_way_out(str(opts[0])), "the confirm: B keeps training (%s)" % str(opts))
	Dialogue.instance(self)._choose("", 1)
	await _talk(10)
	check(current_scene == m and not bt._over, "Not now keeps you training")
	dr.ask_leave()
	await process_frame
	Dialogue.instance(self)._choose("", 0)
	m = await _arrive("town")
	await _left_ok(m, "leave at step 1")
	# ---- 2. re-enter; the helper only comes from "Build helper"; follow; orders ------
	r = await _enter(m)
	m = r[0]
	bt = r[1]
	dr = bt.drill
	check(dr != null and dr.step == 0, "the drill starts again from step 1")
	var post := bt.point("d")
	m.player.position = post["pos"]
	for i in 900:
		await process_frame
		if dr.step > 0:
			break
	await _talk(40)
	check(dr.step == 1, "taking the post passes step 1")
	for i in 240:
		await process_frame
	check(bt._helpers() == 0, "no helper appears on its own")
	check(dr.text(1).contains("Build helper") and dr.text(1).contains(InputSetup.prompt("a")), "the build step names the option and the button: %s" % dr.text(1))
	bt.interact("d")
	await process_frame
	opts = _choices()
	var bi := _find(opts, "Build helper")
	check(bi == 0, "the banner menu leads with Build helper while nothing is built (%s)" % str(opts.slice(0, 2)))
	check(Dialogue.is_way_out(str(opts.back())), "the banner menu ends with its way out")
	Dialogue.instance(self)._choose("", bi)
	for i in 900:
		await process_frame
		if bt._helpers() > 0:
			break
	check(bt._helpers() > 0, "Build helper brings a helper out of the banner")
	await _talk(40)
	for i in 120:
		await process_frame
		if dr.step > 1:
			break
	check(dr.step == 2 and bt._rally == -1, "step 3 is Follow, and the drill's helpers follow by default")
	await _talk(40)
	var h := _helper()
	var start: Vector2 = m.player.position
	await _walk(m, Vector2(0, 1), 96.0)
	for i in 60:
		await process_frame
	await _talk(20)
	h = _helper()
	check(m.player.position.distance_to(start) > 48.0, "the hero walked (%.0f px)" % m.player.position.distance_to(start))
	check(h != null and h.position.distance_to(m.player.position) < BattleDrill.NEAR, "the helper walked along (%.0f px away)" % (h.position.distance_to(m.player.position) if h else -1.0))
	for i in 120:
		await process_frame
		if dr.step > 2:
			break
		await _walk(m, Vector2(1, 0), 8.0)
	check(dr.step == 3, "walking with it passes the follow step (walked %.0f)" % dr._walked)
	await _talk(40)
	# Hold here, through the HELPERS list.
	bt._pick_rally()
	await process_frame
	opts = _choices()
	check(str(opts[0]).contains("Follow me") and str(opts[1]).contains("Hold here") and str(opts[2]).begins_with("Go to") and str(opts.back()) == "Close", "the HELPERS list says what each order does: %s" % str(opts))
	check(bt._rally_btn.text.begins_with("HELPERS"), "the button is called HELPERS: %s" % bt._rally_btn.text)
	Dialogue.instance(self)._choose("", 1)
	await _talk(10)
	check(bt._rally == -2 and not m.has_meta("follow_me"), "Hold here takes")
	h = _helper()
	var d0 := h.position.distance_to(h.home) if h else 0.0
	for i in 120:
		await process_frame
	check(h != null and h.position.distance_to(h.home) < maxf(30.0, d0 - 10.0), "on Hold here the helper goes back to its banner (%.0f -> %.0f)" % [d0, h.position.distance_to(h.home) if h else -1.0])
	check(dr.step == 4, "Hold here passes its step (%d)" % dr.step)
	await _talk(40)
	# ---- 3. leave from the pause menu row (pad / keys) mid-drill -------------------
	GameMenu.open_page(self, "Items")
	await process_frame
	await process_frame
	var row: Button = null
	var gmn: GameMenu = null
	for ch in current_scene.get_children():
		if ch is GameMenu:
			gmn = ch
	if gmn:
		for c in gmn._body.get_children():
			if c is Button and (c as Button).text.begins_with("End training"):
				row = c
	check(row != null, "the pause menu offers End training while the drill runs")
	if row:
		row.pressed.emit()
	m = await _arrive("town")
	for i in 30:
		await process_frame
	await _left_ok(m, "leave from the pause menu at step 5")
	# ---- 4. re-enter once more; orders Follow me and Go to a point work ------------
	r = await _enter(m)
	m = r[0]
	bt = r[1]
	check(bt != null and bt.drill != null and bt.drill.step == 0, "the drill starts a third time")
	if bt:
		var post2 := bt.point("d")
		m.player.position = post2["pos"]
		post2["owner"] = "ally"
		post2["prog"] = 1.0
		post2["spawner"] = "striker"
		post2["t"] = 10.0
		for i in 900:
			await _talk(1)
			if bt._helpers() > 0:
				break
		for i in 200:
			await _talk(2)
			if not Dialogue.instance(self).active and dr_ready(bt):
				break
		bt._set_rally(-2)
		bt._pick_rally()
		await process_frame
		Dialogue.instance(self)._choose("", 0)
		await _talk(10)
		check(bt._rally == -1 and m.has_meta("follow_me"), "Follow me (from the list) takes")
		bt._pick_rally()
		await process_frame
		opts = _choices()
		var mi := _find(opts, bt.point("b")["name"])
		Dialogue.instance(self)._choose("", mi)
		await _talk(10)
		check(bt._rally >= 0 and bt.points[bt._rally] == bt.point("b") and m.has_meta("rally_pos"), "Go to Old Mill takes")
		# A KO-free way out at the last step too.
		bt.drill.leave()
		m = await _arrive("town")
		for i in 30:
			await process_frame
		await _left_ok(m, "leave after the orders")
	print("battle_drill_flow_test (%s): %d fails" % [arc, fails])
	quit(1 if fails > 0 else 0)
