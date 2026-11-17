extends SceneTree
## UI input test: menu tabs/skill rows respond to touch and mouse; dialogue
## advances on mouse click; left click on a door/NPC walks + interacts.
## Run: xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/ui_test.gd -- /tmp/shots

var out := "/tmp"
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["town_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	var farm: Node = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	current_scene = farm
	await frames(20)
	var menu: GameMenu = null
	for ch in farm.get_children():
		if ch is GameMenu:
			menu = ch
	check(menu != null, "menu exists")
	var tl := CanvasLayer.new(); tl.layer = 50; tl.process_mode = Node.PROCESS_MODE_ALWAYS; root.add_child(tl)
	var tb := Button.new(); tb.text = "T"; tb.position = Vector2(100, 150); tb.size = Vector2(60, 30); tl.add_child(tb)
	var hit := [0]
	tb.pressed.connect(func() -> void: hit[0] += 1)
	await mouse_click(Vector2(130, 165))
	check(hit[0] == 1, "bare button in game scene gets a mouse click (unpaused)")
	for ch in farm.get_children():
		if ch is TouchControls:
			ch.queue_free()
	await frames(2)
	await mouse_click(Vector2(130, 165))
	check(hit[0] == 2, "... without TouchControls")
	for ch in farm.get_children():
		if ch is Hud:
			(ch as Hud).set_process_input(false)
	await mouse_click(Vector2(130, 165))
	check(hit[0] == 3, "... without Hud input")
	Dialogue.instance(self).set_process_input(false)
	await mouse_click(Vector2(130, 165))
	check(hit[0] == 4, "... without Dialogue input")
	# Open via action, then tap the Skills tab with a touch.
	await press("menu", 2)
	await frames(4)
	check(paused and menu._open, "menu open")
	tl.queue_free()
	await frames(30)
	var skills_tab: Button = menu._tab_buttons["Skills"]
	var r := skills_tab.get_global_rect()
	_hook_all(root)
	print("quests rect ", menu._tab_buttons["Quests"].get_global_rect(), " focus owner=", root.gui_get_focus_owner(), " window size=", get_root().get_window().size, " content scale=", get_root().get_window().content_scale_size, " root size=", root.size)
	for xx in [30.0, 100.0, 196.0, 250.0]:
		print("--- click at x=", xx)
		await mouse_click(Vector2(xx, 48))
	await mouse_click(menu._tab_buttons["Quests"].get_global_rect().get_center())
	check(menu._tab == "Quests", "FIRST mouse click on Quests tab (%s)" % menu._tab)
	await touch_tap(r.get_center())
	check(menu._tab == "Skills", "touch on Skills tab switches tab (%s)" % menu._tab)
	# Find a skill row button and tap it.
	var row := _find_button(menu._body, "Farming")
	check(row != null, "farming row button exists")
	if row:
		await touch_tap(row.get_global_rect().get_center())
		check(menu._skill_open == "farming", "touch on Farming row opens tree (%s)" % menu._skill_open)
	# Mouse: click Social tab, then Skills row with a real mouse event.
	(menu._tab_buttons["Social"] as Button).gui_input.connect(func(e: InputEvent) -> void: print("social gui_input: ", e))
	(menu._tab_buttons["Social"] as Button).button_down.connect(func() -> void: print("social button_down"))
	await mouse_click(menu._tab_buttons["Social"].get_global_rect().get_center())
	_dump_controls(root, 0)
	print("hovered after click: ", root.gui_get_hovered_control(), " at ", menu._tab_buttons["Social"].get_global_rect())
	check(menu._tab == "Social", "mouse click on Social tab (%s)" % menu._tab)
	await mouse_click(menu._tab_buttons["Skills"].get_global_rect().get_center())
	row = _find_button(menu._body, "Mining")
	if row:
		var r0 := row.get_global_rect()
		for i in 60:
			await frames(1)
			var r1 := row.get_global_rect()
			if r1 != r0:
				print("mining rect changed at frame ", i, ": ", r0, " -> ", r1)
				r0 = r1
		print("mining final rect ", row.get_global_rect(), " visible=", row.is_visible_in_tree())
		await mouse_click(row.get_global_rect().get_center())
		print("after wait: skill_open=", menu._skill_open)
		menu._skill_open = ""
		menu._refresh()
		await frames(1)
		row = _find_button(menu._body, "Mining")
		print("fresh mining rect ", row.get_global_rect())
		await mouse_click(row.get_global_rect().get_center())
		print("fresh click 1 frame later: skill_open=", menu._skill_open)
		check(menu._skill_open == "mining", "mouse click on Mining row opens tree (%s)" % menu._skill_open)
	await shot("ui_skills")
	await press("menu", 2)
	await frames(4)
	check(not paused, "menu closed")
	# Dialogue: open one, then mouse click advances/closes it.
	var d := Dialogue.instance(self)
	d.say([{"text": "one"}, {"text": "two"}])
	await frames(6)
	check(d.active, "dialogue open")
	for i in 4:
		await mouse_click(Vector2(135, 240))
		await frames(3)
		print("dialogue click %d: active=%s typing=%s paused=%s text=%s" % [i, d.active, d._typing, paused, d._text.text])
	check(not d.active, "mouse clicks advance and close the dialogue")
	# Left click on the house door walks there and enters.
	var m := current_scene as GameMap
	var door_cell: Vector2i = Vector2i(13, 10)
	var screen := m.get_canvas_transform() * m.cell_center(door_cell)
	await mouse_click(screen)
	for i in 240:
		await frames(1)
		if current_scene != m:
			break
	check(current_scene != m and current_scene.scene_id() == "house", "left click on the door walks over and enters (%s)" % current_scene.scene_id())
	print("ui_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _dump_controls(n: Node, depth: int) -> void:
	if n is Control:
		var c := n as Control
		if c.visible and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(Vector2(134, 48)):
			print("  ".repeat(depth), c, " rect=", c.get_global_rect(), " filter=", c.mouse_filter, " parent=", c.get_parent())
	for ch in n.get_children():
		_dump_controls(ch, depth + 1)


func _hook_all(n: Node) -> void:
	if n is Control:
		var c := n as Control
		c.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton:
				print("GUI MouseButton -> ", c, " text=", c.get("text"), " rect=", c.get_global_rect(), " localpos=", (e as InputEventMouseButton).position, " pressed=", (e as InputEventMouseButton).pressed))
	for ch in n.get_children():
		_hook_all(ch)


func _find_button(node: Node, contains: String) -> Button:
	for ch in node.get_children():
		if ch is Button and (ch as Button).text.contains(contains):
			return ch
		var b := _find_button(ch, contains)
		if b:
			return b
	return null


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func press(action: String, hold_frames: int) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)


func touch_tap(pos: Vector2) -> void:
	var scale := Vector2(root.size) / Vector2(270, 480)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos * scale
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var ev2 := InputEventScreenTouch.new()
	ev2.index = 0
	ev2.position = pos * scale
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(3)


func mouse_click(pos: Vector2) -> void:
	var scale := Vector2(root.size) / Vector2(270, 480)
	var mv := InputEventMouseMotion.new()
	mv.position = pos * scale
	mv.relative = Vector2(1, 1)
	Input.parse_input_event(mv)
	await frames(1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos * scale
	ev.global_position = pos * scale
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.position = pos * scale
	ev2.global_position = pos * scale
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(3)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(2)
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
