extends SceneTree
## Penguin arc, new game to day 2 (CONDUCT 1): the intro ends with the drawn Star
## Crystal standing in the field, the mailbox marker shows only while a letter
## waits, the morning toast only fires when there's mail, and the partner scene
## comes on day 2 with the visitors on screen and the chosen partner following.
##   godot --headless --path . -s res://tools/newgame_penguin_test.gd

var fails := 0


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(20)
	var said := await talk_through()
	var farm := current_scene as GameMap
	check(bool(GameState.run["intro_done"]), "intro finished")
	check(said.any(func(t: String) -> bool: return t.find("line under the toolbar") >= 0), "intro points at the goal line")
	check(farm.get("_crystal_spr") != null, "the Star Crystal is its drawn sprite, not a polygon")
	check(GameState.has_quest("first_harvest") and GameState.has_quest("meet_town"), "first quests given")
	check(GameState.next_step().find("hoe") >= 0, "goal line starts with the hoe step (%s)" % GameState.next_step())
	# Day 1: Maple's letter waits, so the mailbox marker shows.
	await _wait_game(0.7)
	check(Mail.waiting(), "a letter waits on day 1")
	var mark: Sprite2D = farm.get("_mail_mark")
	check(mark != null and mark.visible, "mailbox marker shows while a letter waits")
	check(not GameState.run["flags"].has("partner_scene"), "no partner scene on day 1")
	farm.later(farm._mailbox)
	said = await talk_through()
	check(said.any(func(t: String) -> bool: return t.find("Maple") >= 0), "Maple's letter read")
	await _wait_game(0.7)
	check(not Mail.waiting(), "nothing waits after reading (unread=%d)" % Mail.unread())
	check(not mark.visible, "mailbox marker hides after reading")
	# Talking to the crystal before the harvest gives the next crop step and idle ideas.
	farm.later(farm._talk_crystal)
	said = await talk_through()
	check(said.any(func(t: String) -> bool: return t.find("While it grows") >= 0), "crystal suggests what to do while it grows")
	# Day 2: the partner scene plays at the farm with the visitors in view.
	GameState.sleep()
	check(int(GameState.run["day"]) == 2, "day 2")
	GameMap.next_spawn = Vector2(13 * 16 + 8, 11 * 16 + 4)
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(30)
	farm = current_scene as GameMap
	check(GameState.run["flags"].has("partner_scene"), "partner scene starts on day 2")
	var seen := 0
	for c in farm.get_children():
		if c.has_meta("partner_visitor"):
			seen += 1
	check(seen == 2, "both visitors stand in view while they ask (%d)" % seen)
	said = await talk_through(0)
	check(said.any(func(t: String) -> bool: return t.findn("can we stay") >= 0 or t.findn("can i stay") >= 0), "Pip-Pip and Nova ask to stay")
	check(not said.any(func(t: String) -> bool: return t.find("at dawn") >= 0), "no 'at dawn' when it can be any hour")
	check(Companion.active_id() == "penguin_m", "Pip-Pip joined (%s)" % Companion.active_id())
	check(farm.companion != null and is_instance_valid(farm.companion), "the new partner follows you right away")
	check(said.any(func(t: String) -> bool: return t.find("round button") >= 0), "partner button explained by where it is")
	await _wait_game(2.5)
	var left := 0
	for c in farm.get_children():
		if c.has_meta("partner_visitor") and not c.is_queued_for_deletion():
			left += 1
	check(left == 0, "the visitors are gone (one follows, one left)")
	await _chapter1()
	print("newgame_penguin_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Advances every dialogue until none is open for a while; picks `pick` at choices.
func talk_through(pick := 0) -> Array:
	var d := Dialogue.instance(self)
	var out: Array = []
	var last := ""
	var idle := 0
	for i in 600:
		await frames(2)
		var m := current_scene as GameMap
		if not d.active and m and m.player and m.player.frozen:
			idle = 0  # a fade between parts of a scene
			await _wait_game(0.1)
			continue
		if not d.active:
			idle += 1
			if idle > 30:
				break
			continue
		idle = 0
		if d._full != last:
			last = d._full
			out.append(last)
		if d._in_choice:
			await frames(14)
			if d._choices.get_child_count() > pick:
				(d._choices.get_child(pick) as Button).pressed.emit()
		else:
			d._advance()
			await frames(1)
			if d._typing:
				d._advance()
	return out


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func frames(k: int) -> void:
	for i in k:
		await process_frame


## Wait game time, not the wall clock (C2 determinism rule; check.sh runs this at --fixed-fps 60).
func _wait_game(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		await process_frame
		gt += root.get_process_delta_time()


## C7 (c7_12): chapter 1 goes on past day 2: the town arrival, the day-3 howl on the
## farm, and the meadow's truth when clear_meadow is done.
func _chapter1() -> void:
	GameState.run["flags"]["town_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	await frames(20)
	await talk_through()
	check(Story.fired("p1_town"), "the town arrival beat (p1_town) played")
	GameState.run["day"] = maxi(3, int(GameState.run["day"]))
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(20)
	await talk_through()
	var farm := current_scene as GameMap
	if farm and farm.player:
		farm.player.position = farm.cell_center(Vector2i(25, 10))
		await frames(20)
		await talk_through()
	check(Story.fired("p1_howl") and GameState.run["flags"].has("farm_bubble"), "day 3: the howl on the farm (p1_howl, farm_bubble)")
	if not GameState.has_quest("clear_meadow"):
		GameState.add_quest("clear_meadow", "x")
	GameState.run["flags"]["meadow_seen"] = true
	GameState.complete_quest("clear_meadow")
	await frames(10)
	await talk_through()
	check(Story.fired("p1_grump_truth"), "clear_meadow done -> p1_grump_truth played")
	check(GameState.run["decisions"].has("tell_town"), "the tell-the-town choice was recorded")
	check(GameState.count("old_collar") >= 1, "the old collar came with it")
	check(GameState.has_quest("cattopia"), "cattopia is the next step")
