extends SceneTree
## Softlock/stuck hunt: drop the player on a cell and try to walk out four ways.
##   godot --headless --path . -s res://tools/stuck_probe.gd -- scene:x:y [...]
## Prints "PROBE scene:x:y moved=[dirs] solid=..." and "PROBE STUCK ..." when no
## direction moves the player (a spot a player could be trapped in). Exit 1 if any stuck.
## ARC=gangsters for the other arc; in_<id> for an interior.

func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Probe", "Probetown", "Pup")
	GameState.run["intro_done"] = true
	var stuck := 0
	for spec in OS.get_cmdline_user_args():
		var p: PackedStringArray = spec.split(":")
		var sc := p[0]
		if sc.begins_with("in_"):
			GameMap.next_interior = sc.trim_prefix("in_")
			sc = "interior"
		GameState.run["flags"][sc + "_seen"] = true
		var c := Vector2i(int(p[1]), int(p[2]))
		GameMap.next_spawn = Vector2(c.x * 16 + 8, c.y * 16 + 8)
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 25:
			await process_frame
		await _close_dialogue()
		var m := current_scene as GameMap
		if m == null or m.player == null:
			print("PROBE %s: no map/player" % spec)
			continue
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		var start := m.player.position
		var moved: Array = []
		for dname in (["right", "down", "left", "up"] if OS.get_environment("REV") != "" else ["up", "down", "left", "right"]):
			if current_scene != m:
				break
			var before := m.player.position
			Input.action_press(dname)
			for k in 20:
				await process_frame
			Input.action_release(dname)
			await process_frame
			await _close_dialogue()
			if current_scene != m:
				moved.append(dname + "(exit)")
				break
			if m.player.position.distance_to(before) > 3.0:
				moved.append(dname)
		var info := "frozen=%s" % str(m.player.frozen) if is_instance_valid(m) and m.player else ""
		print("PROBE %s start_cell=%s moved=%s %s" % [spec, str(m.world_to_cell(start)) if is_instance_valid(m) else "?", str(moved), info])
		if moved.is_empty():
			stuck += 1
			print("PROBE STUCK %s" % spec)
	quit(1 if stuck > 0 else 0)


func _close_dialogue() -> void:
	var d := Dialogue.instance(self)
	for k in 30:
		if not d.active:
			return
		if d._in_choice:
			Input.action_press("b")
			await process_frame
			Input.action_release("b")
		else:
			d._advance()
		for j in 3:
			await process_frame
