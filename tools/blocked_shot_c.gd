extends SceneTree
## Dev helper: like area_shot, but tints blocked cells (red = blocked with no
## thing/prop on it, orange = blocked thing/prop, blue = water) so invisible walls show.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/blocked_shot_c.gd -- /tmp/out scene:x:y [...]
## SEASON=spring|summer|fall|winter (day picked), ARC=gangsters.

class Overlay extends Node2D:
	var m: GameMap
	func _draw() -> void:
		var o := m.offset()
		for c: Vector2i in m.blocked:
			var col := Color(1, 0, 0, 0.35)
			if m.things.has(c):
				var t := str(m.things[c].get("type", ""))
				col = Color(0.2, 0.4, 1, 0.3) if t in ["water", "sea"] else Color(1, 0.6, 0, 0.3)
			elif m.props.has(c):
				col = Color(1, 0.6, 0, 0.3)
			draw_rect(Rect2(o + Vector2(c * 16), Vector2(16, 16)), col)


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
	var se := OS.get_environment("SEASON")
	if se != "":
		GameState.run["day"] = {"spring": 3, "summer": 31, "fall": 59, "winter": 87}.get(se, 3)
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	var ov := OS.get_environment("OVERLAY") != ""
	for i in range(1, args.size()):
		var p: PackedStringArray = args[i].split(":")
		var sc := p[0]
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2(int(p[1]) * 16 + 8, int(p[2]) * 16 + 8) if p.size() >= 3 else Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
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
		if ov:
			var o := Overlay.new()
			o.m = m
			o.z_index = 100
			m.add_child(o)
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s%s.png" % [out, p[0], "_".join(p.slice(1)), ("_" + se) if se != "" else ""])
	quit()
