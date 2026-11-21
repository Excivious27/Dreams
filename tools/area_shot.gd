extends SceneTree
## Dev helper: 1:1 screenshots of a scene at given cells.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/area_shot.gd -- /tmp/out scene:x:y[:minutes[:flag]] [...]
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	if OS.get_environment("DAY") != "":
		GameState.run["day"] = int(OS.get_environment("DAY"))
	if OS.get_environment("TIME") != "":
		GameState.run["time"] = int(OS.get_environment("TIME"))
	if OS.get_environment("MONEY") != "":
		GameState.run["crystals"] = int(OS.get_environment("MONEY"))
	if OS.get_environment("MARINA") != "":  # C14: the beach marina's tier (MARINA=0..4)
		GameState.run["marina"] = {"tier": int(OS.get_environment("MARINA"))}
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	for i in range(1, args.size()):
		var p: PackedStringArray = args[i].split(":")
		var sc := p[0]
		if sc.begins_with("in_"):  # in_<interior id>: an interior
			GameMap.next_interior = sc.trim_prefix("in_")
			sc = "interior"
		GameState.run["flags"][sc + "_seen"] = true
		# Optional 4th/5th fields: time in minutes, and a flag to set (lighthouse_lit...).
		if p.size() >= 4 and p[3] != "":
			GameState.run["time"] = int(p[3])
		if p.size() >= 5 and p[4] != "":
			GameState.run["flags"][p[4]] = true
		GameMap.next_spawn = Vector2(int(p[1]) * 16 + 8, int(p[2]) * 16 + 8) if p.size() >= 3 else Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 25:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["energy"] = int(GameState.run["max_energy"])
		if m.player and m.is_water_cell(m.world_to_cell(m.player.position)):
			print("area_shot: %s is water, skipped" % args[i])
			continue
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, p[0], "_".join(p.slice(1))])
	quit()
