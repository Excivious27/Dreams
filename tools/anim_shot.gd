extends SceneTree
## Dev helper: frame-by-frame close-ups of the hero walking and resting.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/anim_shot.gd -- /tmp/out penguin_m [scene:x:y]
## For each direction (right, left, down, up) it walks 0.6 s, then rests 0.6 s,
## saving a 96x96 crop around the hero every 4 frames: <dir>_walk_NN.png /
## <dir>_rest_NN.png, plus sheet_<dir>.png strips (all crops side by side).
## Also prints the animation + flip the hero rests in, so a rest that turns
## the wrong way shows up in text too.
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _crop(m: GameMap) -> Image:
	var img := root.get_texture().get_image()
	var vp := root.get_visible_rect().size
	var scale := float(img.get_width()) / vp.x
	var p: Vector2 = m.player.get_global_transform_with_canvas().origin * scale
	var r := Rect2i(int(p.x) - 48, int(p.y) - 72, 96, 96)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	return img.get_region(r)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var who := args[1] if args.size() > 1 else "penguin_m"
	var spot := args[2] if args.size() > 2 else "farm:20:14"
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", who, "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 600
	GameState.run["flags"]["partner_scene"] = true
	var p: PackedStringArray = spot.split(":")
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
	var bad := 0
	for dir in ["right", "left", "down", "up"]:
		var shots: Array[Image] = []
		Input.action_press(dir)
		for k in 36:
			await process_frame
			if k % 4 == 3:
				await RenderingServer.frame_post_draw
				var c := _crop(m)
				c.save_png("%s/%s_walk_%02d.png" % [out, dir, k])
				shots.append(c)
		Input.action_release(dir)
		for k in 36:
			await process_frame
			if k % 4 == 3:
				await RenderingServer.frame_post_draw
				var c := _crop(m)
				c.save_png("%s/%s_rest_%02d.png" % [out, dir, k])
				shots.append(c)
		var pl: Player = m.player
		var flip := pl._anim.flip_h if pl._anim else false
		var want: Array = {"right": ["view_right", false], "left": ["view_left", false], "down": ["idle", false], "up": ["view_back", false]}[dir]
		var ok: bool = pl.facing == dir and (pl.anim_name == want[0] or (dir == "left" and pl.anim_name == "view_right" and flip))
		if not ok:
			bad += 1
		print("anim_shot %s %s: facing=%s anim=%s flip=%s %s" % [who, dir, pl.facing, pl.anim_name, flip, "ok" if ok else "WRONG"])
		var sheet := Image.create(96 * shots.size(), 96, false, Image.FORMAT_RGBA8)
		for i in shots.size():
			var s := shots[i]
			if s.get_format() != Image.FORMAT_RGBA8:
				s.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()), Vector2i(96 * i, 0))
		sheet.save_png("%s/sheet_%s.png" % [out, dir])
	print("anim_shot done, wrong rests: %d" % bad)
	quit(1 if bad > 0 else 0)
