extends SceneTree
## Toast layout (CONDUCT 2 / 16): toasts never sit over a boss intro card, a region
## name card or the pup command strip.
##   godot --headless --path . -s res://tools/toast_layout_test.gd
## Under xvfb with an output dir, saves a shot of each case:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 270x480 -s res://tools/toast_layout_test.gd -- /tmp/toasts
var fails := 0
var out_dir := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _toast_rect(hud: Hud) -> Rect2:
	var r := Rect2()
	for c in hud._toasts.get_children():
		var cr := Rect2(hud._toasts.position + (c as Control).position, (c as Control).size)
		r = cr if r.size == Vector2.ZERO else r.merge(cr)
	return r


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	InputSetup.ensure_actions()
	TouchControls.visible_controls = true
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for k in ["hoe", "can", "axe", "pickaxe", "scythe", "sword", "seed", "rod"]:
		GameState.run["flags"]["tip_" + k] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await frames(30)
	var d := Dialogue.instance(self)
	for i in 30:
		if not d.active:
			break
		d._advance()
		await frames(3)
	var m := current_scene as GameMap
	check(m != null and m.hud != null, "beach loaded")
	if m == null:
		return _finish()
	var hud: Hud = m.hud
	for c in hud._toasts.get_children():
		c.free()

	# 1. A boss intro card: toasts made under it wait (hidden, not fading), then show.
	m.boss_card("big_grump", "Big Grump")
	await frames(2)
	hud.toast("Sword: tap USE to swing at foes.", Color(0.85, 0.95, 1.0))
	await frames(3)
	check(not hud._toasts.visible, "toasts hidden while the boss card is up")
	await shot("1_boss_card")
	await create_timer(3.2).timeout
	await frames(3)
	var live := hud._toasts.get_child_count()
	check(live == 1, "the weapon tip waited out the card (%d left)" % live)
	check(hud._toasts.visible, "toasts back once the card is gone")
	if live == 1:
		check((hud._toasts.get_child(0) as Control).modulate.a > 0.9, "the tip shows at full strength after the card")
	await shot("1b_after_card")
	for c in hud._toasts.get_children():
		c.free()

	# 2. A region name card: toasts sit under it.
	MegaRegion.banner(m, MegaRegion.VALLEY, "beach", "Back home, by the sea.")
	await create_timer(1.0).timeout
	hud.toast("New map tab: Somewhere (Menu > Map)", Color(0.85, 0.95, 1.0))
	await frames(4)
	var box: Control = null
	for n in get_nodes_in_group("toast_under"):
		for cc in n.get_children():
			if cc is Control:
				box = cc
	check(box != null, "the name card is in the toast_under group")
	if box:
		check(_toast_rect(hud).position.y >= box.position.y + box.size.y, "toast under the name card (%s vs %s)" % [_toast_rect(hud), Rect2(box.position, box.size)])
	await shot("2_name_card")
	for n in get_nodes_in_group("toast_under"):
		n.free()
	for c in hud._toasts.get_children():
		c.free()
	await frames(3)

	# 3. A tall stack beside the pup strip steps in past the buttons.
	check(m.pet != null, "pup is with you")
	var fake := CanvasLayer.new()
	fake.add_to_group("toast_under")
	var pad := Control.new()
	pad.position = Vector2(0, 0)
	pad.size = Vector2(10, 150)  # pushes the stack down to the strip, like the battle bar does
	fake.add_child(pad)
	root.add_child(fake)
	for t in ["Heads up: the north gate is under attack, send someone!", "Your crew took the east point.", "+1 Wood"]:
		hud.toast(t)
	await frames(4)
	var tr := _toast_rect(hud)
	var strip_r := TouchControls.PUP_X + TouchControls.PUP_R + 4.0
	check(tr.end.y > TouchControls.PUP_Y0 - TouchControls.PUP_R, "case reaches the strip (%s)" % tr)
	check(tr.position.x >= strip_r, "toasts clear of the pup strip (left %.0f, strip to %.0f)" % [tr.position.x, strip_r])
	check(tr.end.x <= 249.0, "toasts clear of the energy bar (right %.0f)" % tr.end.x)
	await shot("3_pup_strip")
	fake.free()
	for c in hud._toasts.get_children():
		c.free()
	await frames(4)
	hud.toast("A short one")
	await frames(3)
	check(is_equal_approx(hud._toasts.position.x, 6.0), "no strip in the way: toasts back at the left edge")
	_finish()


func _finish() -> void:
	print("toast_layout_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
