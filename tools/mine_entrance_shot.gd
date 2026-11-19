extends SceneTree
## Dev helper: the meadow's mine entrance dressed by scripts/mine_entrance.gd
## (until meadow.gd calls it itself), by day and by night.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/mine_entrance_shot.gd -- /tmp/out
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := str(args[0]) if args.size() > 0 else "/tmp/shots"
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["meadow_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	for when in [["day", 600], ["night", 1290]]:
		GameState.run["time"] = int(when[1])
		GameMap.next_spawn = Vector2(32 * 16 + 8, 10 * 16 + 8)
		change_scene_to_file("res://scenes/meadow.tscn")
		for k in 25:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance()
			await process_frame
		var m := current_scene as GameMap
		var already := false
		for c in m.props:
			var n: Variant = m.props[c]
			if n is Sprite2D and (n as Sprite2D).texture and "mine_entrance2" in (n as Sprite2D).texture.resource_path:
				already = true
		if not already:
			preload("res://scripts/mine_entrance.gd").dress(m, Vector2i(32, 6))
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/entrance_%s.png" % [out, when[0]])
		print("door blocked=", m.blocked.has(Vector2i(32, 6)), " front cells->door=", m._building_doors.get(Vector2i(30, 6), Vector2i(-1, -1)))
	quit()
