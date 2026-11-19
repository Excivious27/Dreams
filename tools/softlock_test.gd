extends SceneTree
## Softlock hunt (CONDUCT 1 / 08): every menu and screen a new player meets can be
## left with B, dialogues always finish, the menu stays shut during story beats.
##   godot --headless --path . -s res://tools/softlock_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func press(action: String, hold := 2) -> void:
	Input.action_press(action)
	for i in hold:
		await process_frame
	Input.action_release(action)
	await process_frame


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	InputSetup.ensure_actions()
	# 1. What B counts as a way out.
	for t in ["Leave", "← Back", "Not now", "Stay", "Stay ashore", "Nobody, for now", "Just chat", "No", "Later", "Close", "Done", "Not tonight."]:
		check(Dialogue.is_way_out(t), "menu way out: " + t)
	for t in ["Buy seeds", "Take it all back", "No job", "Yes"]:
		check(not Dialogue.is_way_out(t), "not a way out: " + t)
	check(not Dialogue.is_way_out("Stay", false), "story decision: B never answers 'Stay'")
	check(Dialogue.is_way_out("Never mind", false), "story decision: 'Never mind' still backs out")

	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(25)
	var d := Dialogue.instance(self)
	for i in 20:
		if not d.active:
			break
		d._advance()
		await frames(3)
	var m := current_scene as GameMap
	check(m != null and m.scene_id() == "farm", "farm loaded")

	# 2. say([]) still answers `await finished` (it used to hang the caller).
	var got := [false]
	var waiter := func() -> void:
		d.say([])
		await d.finished
		got[0] = true
	waiter.call()
	await frames(3)
	check(got[0], "say([]) finishes")
	check(not d.active and not paused, "say([]) leaves nothing open")

	# 3. An empty choice list gets a Close button (no box without a way out).
	d.say([{"text": "?", "choice": [], "key": ""}])
	await frames(14)
	check(d._choices.get_child_count() == 1, "empty choice list gets one option")
	await press("b")
	await frames(3)
	check(not d.active, "empty choice list closes on B")

	# 4. The farm Plans board: B backs out of every level and leaves.
	Dialogue.audit = true
	Dialogue.audit_log.clear()
	var plans_done := [false]
	var runner := func() -> void:
		await m._plans()
		plans_done[0] = true
	runner.call()
	await frames(14)
	check(d.active and d._in_choice, "plans board opens")
	# Go one level in (first category), then B out twice.
	await press("a")
	await frames(14)
	check(d.active and d._text.text.begins_with("🔒"), "plans category list opens")
	for i in 4:
		if not d.active:
			break
		await press("b")
		await frames(14)
	check(not d.active and plans_done[0], "plans board leaves on B")
	check(Dialogue.audit_log.is_empty(), "plans menus all have a way out: %s" % str(Dialogue.audit_log))
	await frames(20)

	# 5. The game menu closes on B.
	var menu: GameMenu = null
	for ch in m.get_children():
		if ch is GameMenu:
			menu = ch
	check(menu != null, "game menu exists")
	if menu:
		menu.toggle()
		check(menu._open and paused, "menu opens")
		await frames(20)
		await press("b")
		await frames(3)
		check(not menu._open and not paused, "menu closes on B")
		# 6. ...and won't open in the middle of a story beat.
		await frames(20)
		GameState.run["story_pending"] = "x"
		m.player.frozen = true
		menu.toggle()
		check(not menu._open, "menu stays shut during a story beat")
		m.player.frozen = false
		menu.toggle()
		check(menu._open, "a beat that broke off doesn't lock the menu")
		if menu._open:
			menu.toggle()
		GameState.run.erase("story_pending")
		await frames(20)

	# 7. The dresser (Creator with cancel) leaves on B.
	var cancelled := [false]
	var cr := Creator.new({}, "", true)
	cr.cancelled.connect(func() -> void: cancelled[0] = true)
	root.add_child(cr)
	await frames(10)
	await press("b")
	await frames(2)
	check(cancelled[0], "dresser cancels on B")
	cr.queue_free()

	# 8. Story question (stored key): B must not pick an answer for the player.
	d.say([{"text": "Trust it?", "choice": ["Yes", "Stay away"], "key": "t_softlock"}])
	await frames(14)
	await press("b")
	await frames(3)
	check(d.active, "B doesn't answer a story question")
	await press("a")
	await frames(3)
	check(not d.active and int(GameState.run["decisions"].get("t_softlock", -1)) == 0, "A answers it")

	print("softlock_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
