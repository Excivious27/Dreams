extends SceneTree
## Farm look screenshots (C5 P1): the farm at a given build state, optionally zoomed out.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 -s res://tools/farm_look_shot.gd -- /tmp/out name:x:y[:zoom] ...
## Env: BUILDS=house=3,coop=2,barn=2,greenhouse=1  DAY=n  TIME=minutes  ARC=gangsters  SCENE=farm|house
func _initialize() -> void:
	Campaign.bypass = true
	seed(5)
	_run.call_deferred()

func _frames(n: int) -> void:
	for k in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["day"] = int(OS.get_environment("DAY")) if OS.get_environment("DAY") != "" else 30
	GameState.run["time"] = int(OS.get_environment("TIME")) if OS.get_environment("TIME") != "" else 11 * 60
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["farm_seen"] = true
	GameState.run["flags"]["coop_day"] = 1
	GameState.run["flags"]["barn_day"] = 1
	GameState.run["flags"]["barn2_day"] = 1
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	GameState.run["builds"] = GameState.run.get("builds", {})
	for kv in OS.get_environment("BUILDS").split(",", false):
		var q := kv.split("=")
		GameState.run["builds"][q[0]] = int(q[1])
	var scene := OS.get_environment("SCENE") if OS.get_environment("SCENE") != "" else "farm"
	GameMap.next_spawn = Vector2(13 * 16 + 8, 13 * 16 + 8)
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _frames(25)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await _frames(2)
	var m := current_scene as GameMap
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	var cam: Camera2D = null
	for ch in m.player.get_children():
		if ch is Camera2D:
			cam = ch
	for i in range(1, args.size()):
		var p: PackedStringArray = args[i].split(":")
		var z := float(p[3]) if p.size() >= 4 else 1.0
		m.player.position = m.cell_center(Vector2i(int(p[1]), int(p[2])))
		if cam:
			cam.position_smoothing_enabled = false
			if z != 1.0:
				cam.limit_left = -100000; cam.limit_top = -100000; cam.limit_right = 100000; cam.limit_bottom = 100000
			cam.zoom = Vector2(z, z)
			cam.reset_smoothing()
		if m.hud:
			m.hud.visible = z == 1.0
		await _frames(14)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, p[0]])
	quit()
