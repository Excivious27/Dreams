extends SceneTree
## C4 P5: the new enemy strips in game (area_shot-like, spawns kinds next to the player).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/c4_p5_enemy_shot.gd -- /tmp/out scene:x:y kind,kind,...
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 600
	GameState.run["flags"]["partner_scene"] = true
	var i := 1
	while i + 1 < args.size():
		var p: PackedStringArray = args[i].split(":")
		GameState.run["flags"][p[0] + "_seen"] = true
		GameMap.next_spawn = Vector2(int(p[1]) * 16 + 8, int(p[2]) * 16 + 8)
		change_scene_to_file("res://scenes/%s.tscn" % p[0])
		for k in 25:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		var kinds := args[i + 1].split(",")
		var n := 0
		for kd in kinds:
			var off := Vector2(-60 + (n % 3) * 60, -70 + (n / 3) * 90)
			var e: Enemy = m.spawn_enemy(kd, m.player.position + off)
			if e:
				e.set_process(false); e.set_physics_process(false)
			n += 1
		for k in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, args[i + 1].replace(",", "_")])
		i += 2
	quit()
