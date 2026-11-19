extends SceneTree
## Rec Center visual audit shots: town lot day/night, both floors at afternoon and
## night (league), for the current arc.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/rec_vis_shot.gd -- /tmp/out
##   ARC=gangsters for the Rec Hall skin.
var out := "/tmp/recvis"


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _shot(name: String) -> void:
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _go(scene: String, interior: String, spawn: Vector2) -> GameMap:
	GameMap.next_interior = interior
	GameMap.next_spawn = spawn
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for k in 25:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance()
			await process_frame
			await process_frame
	return current_scene as GameMap


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	var a := arc.left(1)
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "rec_visited", "interior_seen", "int_rec", "int_rec_up"]:
		GameState.run["flags"][f] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "meet_town", "text": "x", "done": true}]
	GameState.run["day"] = 10
	GameState.run["flags"]["rec_open"] = 1
	var spots := {"rec": [Vector2(8 * 16 + 8, 11 * 16 + 8), Vector2(8 * 16 + 8, 5 * 16 + 8)],
		"rec_up": [Vector2(8 * 16 + 8, 13 * 16 + 8), Vector2(8 * 16 + 8, 5 * 16 + 8)]}
	for hm in [[14 * 60, "day"], [21 * 60, "night"]]:
		GameState.run["time"] = hm[0]
		await _go("town", "", Vector2(54 * 16 + 8, 89 * 16 + 8))
		await _shot("%s_lot_%s" % [a, hm[1]])
		for room in ["rec", "rec_up"]:
			var sp: Array = spots[room]
			for i in sp.size():
				GameState.run["time"] = hm[0]
				await _go("interior", room, sp[i])
				for k in 60:
					await process_frame
				await _shot("%s_%s_%s_%d" % [a, room, hm[1], i])
	quit()
