extends SceneTree
## Unspent skill points show: the menu's Skills tab shimmers with a count badge,
## every tree tab with points shimmers, the open tree shows a "N points to spend"
## banner, and all of it goes away once the points are spent.
##   godot --headless --path . -s res://tools/skill_glow_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/skill_glow_test.gd -- /tmp/shots
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	if out == "":
		return
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _glow_on(b: Control) -> bool:
	return b != null and b.get_node_or_null("SkillGlow") != null


func _find_label(n: Node, part: String) -> Label:
	if n is Label and (n as Label).text.contains(part):
		return n
	for c in n.get_children():
		var r := _find_label(c, part)
		if r:
			return r
	return null


func _run() -> void:
	var out := ""
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	for i in 60:
		if d.active:
			if d._in_choice:
				d._choose("", d._choices.get_child_count() - 1)
			else:
				d._advance()
		await process_frame
	var menu: GameMenu = null
	for c in m.get_children():
		if c is GameMenu:
			menu = c
	check(menu != null, "menu found")
	if menu == null:
		quit(1)
		return
	menu.toggle()
	menu._tab = "Items"
	menu._refresh()
	check(not _glow_on(menu._tab_buttons["Skills"]), "no points: Skills tab is plain")
	GameState.run["skills"]["farming"]["level"] = 4
	menu._refresh()
	check(_glow_on(menu._tab_buttons["Skills"]), "points to spend: Skills tab shimmers")
	var badge := _find_label(menu._tab_buttons["Skills"], "3")
	check(badge != null, "Skills tab badge shows 3")
	await _shot(out, "skill_glow_items")
	menu._tab = "Skills"
	menu._skill_open = "farming"
	menu._refresh()
	var banner := menu._body.get_node_or_null("PointsBanner")
	check(banner != null, "open tree shows the points banner")
	check(banner != null and _find_label(banner, "3 Farming points to spend") != null, "banner says how many points")
	var tree_tab_glow := false
	for c in menu._body.get_child(0).get_children():
		if c is Button and (c as Button).text.begins_with("Farming"):
			tree_tab_glow = _glow_on(c) and (c as Button).text.contains("+3")
	check(tree_tab_glow, "the Farming tree tab shimmers with +3")
	await _shot(out, "skill_glow_tree")
	# Spend them all: everything goes quiet.
	var guard := 0
	while GameState.points_free("farming") > 0 and guard < 40:
		guard += 1
		for n in GameState.nodes_of("farming"):
			if GameState.node_locked("farming", str(n["id"])) == "":
				GameState.buy_node("farming", str(n["id"]))
				break
	check(GameState.points_free("farming") == 0, "points spent")
	menu._refresh()
	check(menu._body.get_node_or_null("PointsBanner") == null, "no banner once spent")
	check(not _glow_on(menu._tab_buttons["Skills"]), "Skills tab plain once spent")
	print("skill_glow_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
