extends SceneTree
## Penguin arc, new game to day 2 (CONDUCT 1): the intro ends with the drawn Star
## Crystal standing in the field, the mailbox marker shows only while a letter
## waits, the morning toast only fires when there's mail, and the partner scene
## comes on day 2 with the visitors on screen and the chosen partner following.
##   godot --headless --path . -s res://tools/newgame_penguin_test.gd

var fails := 0


func _initialize() -> void:
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
	await create_timer(0.7).timeout
	check(Mail.waiting(), "a letter waits on day 1")
	var mark: Sprite2D = farm.get("_mail_mark")
	check(mark != null and mark.visible, "mailbox marker shows while a letter waits")
	check(not GameState.run["flags"].has("partner_scene"), "no partner scene on day 1")
	farm.later(farm._mailbox)
	said = await talk_through()
	check(said.any(func(t: String) -> bool: return t.find("Maple") >= 0), "Maple's letter read")
	await create_timer(0.7).timeout
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
	check(said.any(func(t: String) -> bool: return t.find("followed the light") >= 0), "Pip-Pip and Nova ask to stay")
	check(not said.any(func(t: String) -> bool: return t.find("at dawn") >= 0), "no 'at dawn' when it can be any hour")
	check(Companion.active_id() == "penguin_m", "Pip-Pip joined (%s)" % Companion.active_id())
	check(farm.companion != null and is_instance_valid(farm.companion), "the new partner follows you right away")
	check(said.any(func(t: String) -> bool: return t.find("round button") >= 0), "partner button explained by where it is")
	await create_timer(2.5).timeout
	var left := 0
	for c in farm.get_children():
		if c.has_meta("partner_visitor") and not c.is_queued_for_deletion():
			left += 1
	check(left == 0, "the visitors are gone (one follows, one left)")
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
