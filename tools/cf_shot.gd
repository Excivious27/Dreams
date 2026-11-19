extends SceneTree
## Community farm screenshots, stage by stage: a whole-map overview (camera zoomed
## out) plus close views of the beds, plaza, shed/greenhouse and market.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 -s res://tools/cf_shot.gd -- /tmp/cf [stages] [views]
##   stages: comma list (default 0..8); views: "all" (default), "over" (overview only) or "close".
##   ARC=gangsters for the Westside Lot Garden; SEASON=summer|fall|winter (default spring).
var out := "/tmp/cf"


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var stages := [0, 1, 2, 3, 4, 5, 6, 7, 8]
	if args.size() > 1 and args[1] != "":
		stages = Array(args[1].split(",")).map(func(s: String) -> int: return int(s))
	var views := args[2] if args.size() > 2 else "all"
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	var season := OS.get_environment("SEASON")
	for s: int in stages:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		GameState.run["day"] = {"summer": 38, "fall": 66, "winter": 94}.get(season, 10)
		GameState.run["time"] = 11 * 60
		for f in ["partner_scene", "community_farm_seen", "cf_intro", "cf_known", "cf_met", "cf_letter", "cf_board_seen"]:
			GameState.run["flags"][f] = true
		GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "meet_town", "text": "x", "done": true}]
		Commons.st()["stage"] = s
		if s >= 4:
			# Beds planted, at a spread of growth (the volunteers plant whole rows).
			var se := GameState.season()
			var i := 0
			for key: String in Commons.plot_cells():
				var c := Commons.pick_crop(key, se, bool(Commons.plot_cells()[key]))
				var cd: Dictionary = GameState.crops.get(c, {})
				var days := 0.0 if cd.is_empty() else float(cd.get("days", 4)) * float((i / 7) % 6) / 5.0
				(Commons.st()["plots"] as Dictionary)[key] = {"crop": c, "days": days, "w": false}
				i += 1
		GameMap.next_spawn = Vector2(29 * 16 + 8, 24 * 16 + 8)
		change_scene_to_file("res://scenes/community_farm.tscn")
		await _frames(25)
		var d := Dialogue.instance(self)
		for k in 12:
			if d.active:
				d._advance()
				await _frames(2)
		var m := current_scene as GameMap
		var tag := "%s_s%d%s" % [arc.left(1), s, ("_" + season) if season != "" else ""]
		var cam: Camera2D = null
		for ch in m.player.get_children():
			if ch is Camera2D:
				cam = ch
		if views in ["all", "close"]:
			for v: Array in [["beds", Vector2i(13, 20)], ["plaza", Vector2i(30, 18)], ["north", Vector2i(32, 10)], ["market", Vector2i(40, 28)], ["south", Vector2i(18, 33)]]:
				m.player.position = m.cell_center(v[1])
				if cam:
					cam.reset_smoothing()
				await _frames(10)
				await _shot("%s_%s" % [tag, v[0]])
		if views in ["all", "over"] and cam:
			# Whole map at about 1:1 on a 1080-wide window.
			cam.position_smoothing_enabled = false
			cam.limit_left = -100000
			cam.limit_top = -100000
			cam.limit_right = 100000
			cam.limit_bottom = 100000
			cam.zoom = Vector2(0.255, 0.255)
			m.player.position = Vector2((m.cols + 2 * m.pad) * 8.0, (m.rows + 2 * m.pad) * 8.0)
			if m.hud:
				m.hud.visible = false
			await _frames(12)
			await _shot("%s_over" % tag)
	quit()
