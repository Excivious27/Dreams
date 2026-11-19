extends SceneTree
## Desktop / full-screen play (CONDUCT 2, P8): the view widens on a landscape
## computer window and stays exactly 270x480 on a phone or portrait window.
## Checks, per window size: the logical view, the UI column offset, HUD pieces
## (hearts, toolbar, clock box, energy bar) inside the visible rect and at the
## right edges, menus/full-screen panels centred, camera limits wide enough (no
## void past small maps), touch controls hidden on desktop / shown on phone,
## and the side curtains while a full-screen panel is open.
##   godot --headless --path . -s res://tools/desktop_layout_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tools/desktop_layout_test.gd -- /tmp/desk   (also screenshots)
var fails := 0
var out_dir := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _set_mode(force: int, size: Vector2i) -> void:
	DisplayMode.force = force
	DisplayMode.test_size = size
	if DisplayServer.get_name() != "headless" and force == 1:
		DisplayMode.test_size = Vector2i.ZERO
		root.get_window().size = size
		await frames(3)
	DisplayMode.refit()
	await frames(4)


func _child(n: Node, cls: String) -> Node:
	for c in n.get_children():
		var s := c.get_script() as Script
		if s and s.get_global_name() == cls:
			return c
	return null


func _clear_dialogue() -> void:
	var d := Dialogue.instance(self)
	for i in 40:
		if not d.active:
			break
		if d._in_choice:
			d._choose("", d._choices.get_child_count() - 1)
		else:
			d._advance()
		await frames(3)


func _case(label: String, force: int, size: Vector2i) -> void:
	print("== ", label, " ", size)
	await _set_mode(force, size)
	var m := current_scene as GameMap
	var v := DisplayMode.view
	var phone := force == 0 or float(size.x) / size.y <= 270.0 / 480.0 + 0.01
	if phone:
		check(v == Vector2(270, 480), "%s: view stays 270x480 (%s)" % [label, v])
		check(DisplayMode.cx == 0.0, "%s: no column offset" % label)
		check(root.content_scale_size == Vector2i(270, 480), "%s: content scale 270x480" % label)
	else:
		var want := clampf(roundf(480.0 * size.x / size.y), 270, DisplayMode.MAX_W)
		check(absf(v.x - want) < 1.0 and v.y == 480.0, "%s: view widened to %dx480 (%s)" % [label, int(want), v])
		check(absf(DisplayMode.cx - floorf((v.x - 270) / 2.0)) < 0.5, "%s: column centred (cx %d)" % [label, int(DisplayMode.cx)])
	# Touch pad: hidden on a computer, shown on a phone.
	check(TouchControls.visible_controls == (force == 0), "%s: touch controls %s" % [label, "shown" if force == 0 else "hidden"])
	# HUD pieces: the clock box right edge and the energy bar sit at the visible right edge.
	var ex := DisplayMode.extra()
	var clock := Rect2(166 + ex, 2, 100, 28)
	var bar := Rect2(250 + ex, 186, 20, 150)
	var view := Rect2(Vector2.ZERO, v)
	check(view.encloses(clock) and absf(view.end.x - clock.end.x - 4) < 0.5, "%s: clock box at the top-right edge %s" % [label, clock])
	check(view.encloses(bar) and absf(view.end.x - bar.end.x) < 0.5, "%s: energy bar at the right edge %s" % [label, bar])
	check(view.encloses(Rect2(Hud.TOOLBAR_X - 6, Hud.TOOLBAR_Y - 5, 12 * Hud.SLOT + 12, Hud.SLOT + 10)), "%s: toolbar inside the view" % label)
	# Camera limits span at least the view (small maps centred, no pinned void).
	var cam := m.get_viewport().get_camera_2d()
	check(cam != null and cam.limit_right - cam.limit_left >= int(v.x) - 1, "%s: camera limits cover the view width (%d)" % [label, cam.limit_right - cam.limit_left if cam else -1])
	# Menu: a 270-px column in the middle.
	var menu := _child(m, "GameMenu") as GameMenu
	check(menu != null and absf(menu.offset.x - DisplayMode.cx) < 0.5, "%s: menu layer centred" % label)
	var hud := m.hud
	check(hud.offset.x == 0.0, "%s: HUD spans the whole view" % label)
	await shot("%s_hud" % label)
	menu.toggle()
	await frames(6)
	var pr := Rect2(menu._panel.get_global_rect().position + Vector2(menu.offset.x, 0), menu._panel.size)
	check(view.encloses(pr), "%s: menu panel inside the view %s" % [label, pr])
	check(absf(pr.get_center().x - v.x / 2.0) < 4.0, "%s: menu panel centred (%.0f vs %.0f)" % [label, pr.get_center().x, v.x / 2.0])
	var curt: bool = (DisplayMode.svc()._sides[0] as ColorRect).visible
	check(curt == (not phone), "%s: side curtains %s with the menu open" % [label, "up" if not phone else "off"])
	await shot("%s_menu" % label)
	menu.toggle()
	await frames(6)
	# A full-screen panel (chest): its 270x480 content is centred, curtains cover the sides.
	var cs := ChestScreen.new()
	cs.m = m
	cs.key = "chest"
	cs.head = "Chest"
	m.add_child(cs)
	await frames(8)
	var cl := cs as CanvasLayer
	check(absf(cl.offset.x - DisplayMode.cx) < 0.5, "%s: chest screen centred" % label)
	var bad := ""
	for c in cl.get_children():
		if c is Control and (c as Control).visible:
			var r := (c as Control).get_rect()
			r.position.x += cl.offset.x
			if not view.grow(1).encloses(r):
				bad += "%s %s; " % [c.name, r]
	check(bad == "", "%s: chest screen controls inside the view %s" % [label, bad])
	await shot("%s_chest" % label)
	cs.close()
	await frames(6)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for k in ["hoe", "can", "axe", "pickaxe", "scythe", "sword", "seed", "rod"]:
		GameState.run["flags"]["tip_" + k] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	await frames(30)
	await _clear_dialogue()
	var m := current_scene as GameMap
	check(m != null and m.hud != null, "town loaded")
	if m == null:
		return _finish()
	await _case("desk1080", 1, Vector2i(1920, 1080))
	await _case("desk768", 1, Vector2i(1366, 768))
	await _case("desk1440", 1, Vector2i(2560, 1440))
	await _case("ultrawide", 1, Vector2i(3440, 1440))
	await _case("deskportrait", 1, Vector2i(540, 960))
	await _case("phone", 0, Vector2i(1080, 1920))
	await _case("phone270", 0, Vector2i(270, 480))
	# A small interior on a wide view: the room sits in the middle.
	await _set_mode(1, Vector2i(1920, 1080))
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/house.tscn")
	await frames(30)
	await _clear_dialogue()
	var h := current_scene as GameMap
	if h:
		var cam := h.get_viewport().get_camera_2d()
		check(cam != null and cam.limit_right - cam.limit_left >= int(DisplayMode.view.x) - 1, "house: camera limits cover the wide view")
		await frames(3)
		check(Hud.y_offset == 0.0, "house: HUD stays at the top on a wide view (no phone bottom block)")
		await shot("desk1080_house")
	await _set_mode(0, Vector2i(270, 480))
	_finish()


func _finish() -> void:
	DisplayMode.force = -1
	DisplayMode.test_size = Vector2i.ZERO
	print("DESKTOP LAYOUT: %s (%d fail%s)" % ["PASS" if fails == 0 else "FAIL", fails, "" if fails == 1 else "s"])
	quit(1 if fails else 0)
