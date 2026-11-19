extends SceneTree
## First hours, both arcs, played on the real maps (CONDUCT 2): new game ->
## till/plant/water -> town (arrival beat + guided tour) -> sleep -> day 2 mail
## -> sleep -> day 3 letter -> meadow goal. Checks that the goal line, the HUD
## arrow, the mailbox marker, the morning "Next:" line and the tool tips agree
## with each other at every step (the C1 systems working together).
##   godot --headless --path . -s res://tools/first_hours_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/first_hours_test.gd -- /tmp/fh   (screenshots)

var fails := 0
var out := ""
var arc := ""
var n := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	for a: String in ["penguins", "gangsters"]:
		arc = a
		await play(a)
	print("first_hours_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func play(a: String) -> void:
	var pen := a == "penguins"
	GameState.new_run(a, "kairi" if pen else "pax", "Kairi", "Dreamhollow", "Biscuit")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(20)
	await talk_through()
	var farm := current_scene as GameMap
	check(bool(GameState.run["intro_done"]), "intro finished")
	check(GameState.next_step().begins_with("Hold the hoe"), "goal starts on the hoe (%s)" % GameState.next_step())
	await shot("after_intro")
	# Day 1 mailbox: penguins get Maple's letter now; M.'s second letter comes on day 2.
	await create_timer(0.7).timeout
	var mark: Sprite2D = farm.get("_mail_mark")
	check(mark != null and mark.visible == pen, "day 1 mailbox marker %s" % ("shows (Maple's letter)" if pen else "hidden (M. writes on day 2)"))
	# Till, plant, water on a free cell south of the house.
	var p: Player = farm.player
	var spot := Vector2i(-1, -1)
	for dx in range(0, 12):
		var c := Vector2i(16 + dx, 13)
		if farm._tillable(c) and not farm.blocked.has(c + Vector2i(0, 1)) and not farm.things.has(c + Vector2i(0, 1)):
			spot = c
			break
	check(spot != Vector2i(-1, -1), "found a tillable cell")
	p.position = farm.cell_center(spot + Vector2i(0, 1))
	p.facing = "up"
	GameState.select_slot(0)
	await frames(5)
	await act()
	check(GameState.run["farm"].has("%d,%d" % [spot.x, spot.y]), "tilled with USE")
	check(GameState.next_step().begins_with("Pick Turnip"), "goal: plant (%s)" % GameState.next_step())
	GameState.run["selected"] = "turnip_seed"
	await act()
	GameState.run["selected"] = ""
	check(str(GameState.run["farm"]["%d,%d" % [spot.x, spot.y]].get("crop", "")) == "turnip", "planted")
	GameState.select_slot(1)
	await act()
	var gw := GameState.next_step()
	check(gw.begins_with("Watered") or gw.begins_with("The rain"), "goal: wait for the crop (%s)" % gw)
	await frames(10)
	var tips := toasts(farm)
	check(tips.any(func(t: String) -> bool: return t.begins_with("Hoe:")), "hoe tip shown once in hand")
	check(tips.any(func(t: String) -> bool: return t.begins_with("Watering Can:")), "can tip shown once in hand")
	await shot("watered")
	# Town: the arrival beat, then the tour, which completes meet_town.
	farm.go_to("town", Vector2(40 * 16, 3 * 16), "down")
	await frames(60)
	await talk_through()
	for i in 200:
		if GameState.quest_done("meet_town"):
			break
		await frames(5)
		await talk_through()
	var town := current_scene as GameMap
	check(GameState.run["flags"].has("town_tour"), "the town tour played")
	check(GameState.quest_done("meet_town"), "meeting the town is done after the tour")
	check(not (GameState.run.get("hints", []) as Array).is_empty(), "tour lines saved to the journal")
	await frames(20)
	check(town.player != null and not town.player.frozen, "free to move after the tour")
	# The arrow (first crop -> farm) points at the farm road at the top of town.
	var tgt := GoalLine.target(town)
	var fe: Rect2i = town.FARM_EXIT
	var exit_at := town.cell_pos(fe.position.x + fe.size.x * 0.5, fe.position.y + fe.size.y * 0.5)
	check(tgt != Vector2.ZERO and tgt.distance_to(exit_at) < 4.0, "town arrow points at the farm road (%s vs %s)" % [tgt, exit_at])
	check(town.world_to_cell(tgt).y <= 2 and town.in_content(town.world_to_cell(tgt)), "arrow target lies on the map's top road (%s)" % town.world_to_cell(tgt))
	await shot("town_after_tour")
	# Night 1.
	var said := await sleep_in_house()
	check(int(GameState.run["day"]) == 2, "day 2")
	var nx := _next_line(said)
	check(nx != "" and nx == GameState.next_step(), "morning Next: matches the goal line (%s | %s)" % [nx, GameState.next_step()])
	check(said.any(func(t: String) -> bool: return t.find("grew overnight") >= 0) or not pen, "watered crop grew")
	# Day 2 farm: partner scene (penguins), the mailbox marker is up.
	GameMap.next_spawn = Vector2(13 * 16 + 8, 11 * 16 + 4)
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	await talk_through()
	farm = current_scene as GameMap
	await create_timer(0.7).timeout
	mark = farm.get("_mail_mark")
	check(Mail.waiting() > 0 and mark.visible, "day 2: mail waits and the marker shows")
	await shot("farm_day2")
	farm.later(farm._mailbox)
	said = await talk_through()
	check(said.size() >= 1, "day 2 letters read (%d)" % said.size())
	if not pen:
		check(said.any(func(t: String) -> bool: return t.find("- M.") >= 0), "gang: M.'s second letter")
		check(GameState.count("strawberry_seed") >= 3, "gang: strawberry seeds came with it")
	await create_timer(0.7).timeout
	check(Mail.waiting() == 0 and not mark.visible, "marker hides once the box is empty (waiting %d)" % Mail.waiting())
	# Water again so the crop keeps growing.
	farm.player.position = farm.cell_center(spot + Vector2i(0, 1))
	farm.player.facing = "up"
	GameState.select_slot(1)
	await frames(3)
	await act()
	# Night 2 -> day 3: the meadow letter.
	said = await sleep_in_house()
	check(int(GameState.run["day"]) == 3, "day 3")
	nx = _next_line(said)
	check(nx.find("mailbox") >= 0, "day 3 morning Next: sends you to the letter (%s)" % nx)
	check(nx == GameState.next_step(), "morning Next: matches the goal line on day 3")
	GameMap.next_spawn = Vector2(13 * 16 + 8, 11 * 16 + 4)
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	await talk_through()
	farm = current_scene as GameMap
	check(GoalLine.goal_place() == ["farm", "thing:mailbox"], "day 3 arrow -> the mailbox (%s)" % str(GoalLine.goal_place()))
	var mt := GoalLine.target(farm)
	check(mt.distance_to(farm.cell_center(farm.MAILBOX)) < 2.0, "arrow target is the mailbox")
	await create_timer(0.7).timeout
	check(farm.get("_mail_mark").visible, "day 3 marker shows")
	await shot("farm_day3")
	farm.later(farm._mailbox)
	said = await talk_through()
	check(said.any(func(t: String) -> bool: return t.find("meadow") >= 0), "the meadow letter")
	var g3 := GameState.next_step()
	check(g3.find("meadow") >= 0 and g3.find("east gate") >= 0, "after the letter: goal is the east meadow (%s)" % g3)
	var et := GoalLine.target(farm)
	var east := Vector2.ZERO
	for e: Dictionary in farm.exits:
		if str(e["scene"]) == "meadow":
			var rc: Rect2i = e["rect"]
			east = farm.cell_pos(rc.position.x + rc.size.x * 0.5, rc.position.y + rc.size.y * 0.5)
	check(east != Vector2.ZERO and et.distance_to(east) < 4.0, "farm arrow points at the meadow gate (%s vs %s)" % [et, east])
	await frames(20)
	await shot("farm_day3_after_letter")


func _next_line(said: Array) -> String:
	for t: String in said:
		if t.begins_with("Next: "):
			return t.substr(6)
	return ""


func sleep_in_house() -> Array:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/house.tscn")
	await frames(40)
	await talk_through()
	var h := current_scene as GameMap
	h.later(h._sleep)
	await frames(90)
	return await talk_through()


func toasts(m: GameMap) -> Array:
	var t: Array = []
	for c in m.hud._toasts.get_children():
		if c is Label:
			t.append(str(c.get_meta("base", (c as Label).text)))
	return t


## Advances every dialogue until none is open for a while; picks the first choice.
func talk_through() -> Array:
	var d := Dialogue.instance(self)
	var said: Array = []
	var last := ""
	var idle := 0
	for i in 900:
		await frames(2)
		var m := current_scene as GameMap
		if not d.active and m and m.player and m.player.frozen:
			idle = 0  # a fade or a walk between parts of a scene
			await create_timer(0.1).timeout
			continue
		if not d.active:
			idle += 1
			if idle > 30:
				break
			continue
		idle = 0
		if d._full != last:
			last = d._full
			said.append(last)
			if n < 60 and said.size() % 4 == 1:
				await shot("talk")
		if d._in_choice:
			await frames(14)
			if d._choices.get_child_count() > 0:
				(d._choices.get_child(0) as Button).pressed.emit()
		else:
			d._advance()
			await frames(1)
			if d._typing:
				d._advance()
	return said


func act() -> void:
	Input.action_press("a")
	await frames(3)
	Input.action_release("a")
	for i in 60:
		await frames(1)
		var m := current_scene as GameMap
		if m and m.player and not m.player._busy:
			break
	await frames(3)


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   [%s] %s" % [arc, what])
	else:
		fails += 1
		printerr("  FAIL [%s] %s" % [arc, what])


func frames(k: int) -> void:
	for i in k:
		await process_frame


func shot(tag: String) -> void:
	if out == "":
		return
	n += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%03d_%s.png" % [out, arc.left(3), n, tag])
