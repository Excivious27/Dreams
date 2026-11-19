extends SceneTree
## Dev helper: the community farm's volunteers at a given stage/hour/weather.
## Prints every volunteer (cell, place, activity, pose, task) and saves shots.
##   STAGE=8 HOUR=16 WEATHER=clear DAY=10 ARC=penguins WAIT=6 \
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/cf_volunteer_shot.gd -- /tmp/out x:y [x:y ...]
## DAY=7 (or 21) is a market day once STAGE=8. Without cells it only prints.
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(_env("ARC", "penguins"), "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	var day := int(_env("DAY", "10"))
	GameState.run["day"] = day
	GameState.run["time"] = int(float(_env("HOUR", "16")) * 60)
	GameState.run["weather"] = {str(day): _env("WEATHER", "clear")}
	for f in ["partner_scene", "town_seen", "town_tour", "cf_known", "cf_intro", "cf_met", "cf_board_seen", "community_farm_seen", "cf_letter"]:
		GameState.run["flags"][f] = true
	GameState.run["flags"]["cf_orchard_day"] = -99
	Commons.st()["stage"] = int(_env("STAGE", "8"))
	if Commons.stage() >= 4:
		Commons.overnight({})
		Commons.overnight({})
	GameMap.next_spawn = Vector2(49 * 16, 19 * 16 + 8)
	change_scene_to_file("res://scenes/community_farm.tscn")
	for k in 25:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance(); await process_frame; await process_frame
	var m := current_scene as GameMap
	var wait := float(_env("WAIT", "6"))
	var t := 0.0
	while t < wait:
		await process_frame
		t += 1.0 / 60.0
		if d.active:
			d._advance()
	_report(m)
	for i in range(1, args.size()):
		var p: PackedStringArray = args[i].split(":")
		m.player.position = m.cell_center(Vector2i(int(p[0]), int(p[1])))
		for k in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/cf_s%s_h%s_%s_%s_%s.png" % [out, _env("STAGE", "8"), _env("HOUR", "16"), _env("WEATHER", "clear"), p[0], p[1]])
	quit()


func _report(m: GameMap) -> void:
	var n_vis := 0
	var cells := {}
	for n: Npc in m.get("npcs"):
		if not n.visible:
			continue
		n_vis += 1
		var c := n.cell()
		cells[c] = int(cells.get(c, 0)) + 1
		var task := ""
		if m.has_method("task_of"):
			task = str(m.call("task_of", n))
		print("  %-8s cell %s place %-14s act %-7s pose %-8s anim %-10s %s" % [n.id, c, n._place, n.activity, n._pose, n._anim.animation if n._anim else "-", task])
	var stacked := 0
	for c in cells:
		if int(cells[c]) > 1:
			stacked += 1
	print("cf_volunteer_shot: %d visible, %d shared cells" % [n_vis, stacked])
