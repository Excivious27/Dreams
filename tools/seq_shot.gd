extends SceneTree
## Dev helper: a timed sequence of screenshots of one spot, to check animated
## things (critters, farm animals, puddles, glowing props) over time.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/seq_shot.gd -- /tmp/out scene:x:y [shots=12] [every=6]
## Env: WEATHER=rain|storm|clear (today's weather), DAY, TIME, ARC.
## Saves seq_NN.png (every `every` frames) with the hero moved out of the way.
func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var p: PackedStringArray = args[1].split(":")
	var shots := int(args[2]) if args.size() > 2 else 12
	var every := int(args[3]) if args.size() > 3 else 6
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	if OS.get_environment("DAY") != "":
		GameState.run["day"] = int(OS.get_environment("DAY"))
	GameState.run["time"] = int(OS.get_environment("TIME")) if OS.get_environment("TIME") != "" else 600
	if OS.get_environment("WEATHER") != "":
		GameState.run["weather"] = {str(GameState.run["day"]): OS.get_environment("WEATHER")}
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
	# FOCUS=<critter kind or farm animal kind>: stand 3 cells from the first one
	# (outside its flee range) so it is on screen.
	var focus := OS.get_environment("FOCUS")
	if focus != "":
		for n in m.get_children():
			var kd: Variant = n.get("kind")
			if kd != null and str(kd) == focus:
				m.player.position = (n as Node2D).position + Vector2(0, 52)
				print("seq_shot: focus %s at %s" % [focus, (n as Node2D).position])
				break
	for k in 10:
		await process_frame
	for i in shots:
		for k in every:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/seq_%02d.png" % [out, i])
	quit()
