extends SceneTree
## Dev helper (CONDUCT 2): a whole-map picture of each scene, stitched from
## screen-sized shots with the HUD hidden, plus a JSON of exits, doors and
## travel points (cells) so tools/map_mosaic_c2.py can mark them.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 270x480 -s res://tools/map_mosaic_c2.gd -- /tmp/out farm town ...
## ARC=gangsters, DAY=n, TIME=minutes, BUILDS=barn:2. Then: python3 tools/map_mosaic_c2.py /tmp/out


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _hide_ui(n: Node) -> void:
	for ch in n.get_children():
		if ch is CanvasLayer and ch.layer > 0:
			(ch as CanvasLayer).visible = false
		_hide_ui(ch)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["day"] = int(OS.get_environment("DAY")) if OS.get_environment("DAY") != "" else 3
	GameState.run["time"] = int(OS.get_environment("TIME")) if OS.get_environment("TIME") != "" else 11 * 60
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	# BUILDS=barn:2,coop:2 builds farm buildings first (pens, animals).
	for b in OS.get_environment("BUILDS").split(",", false):
		var bp := b.split(":")
		GameState.run["builds"] = GameState.run.get("builds", {})
		GameState.run["builds"][bp[0]] = int(bp[1]) if bp.size() > 1 else 1
	for i in range(1, args.size()):
		var sc := args[i]
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 25:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 10:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		if m == null or m.player == null:
			print("mosaic: %s has no map/player" % sc)
			continue
		for e in m.enemies:
			if is_instance_valid(e):
				e.queue_free()
		m.enemies.clear()
		_hide_ui(root)
		var cam: Camera2D = null
		for ch in m.player.get_children():
			if ch is Camera2D:
				cam = ch
		cam.position_smoothing_enabled = false
		m.player.frozen = true  # no exits fire while the camera tours the map
		m.set_process(false)
		var mw := (m.cols + 2 * m.pad) * GameMap.TILE
		var mh := (m.rows + 2 * m.pad) * GameMap.TILE
		var tiles := []
		var y := 240
		var ti := 0
		while true:
			var x := 135
			while true:
				m.player.position = Vector2(x, y) - m.offset()
				cam.reset_smoothing()
				for k in 6:
					await process_frame
				await RenderingServer.frame_post_draw
				var c := cam.get_screen_center_position()
				var f := "%s/%s__t%03d.png" % [out, sc, ti]
				root.get_texture().get_image().save_png(f)
				tiles.append({"file": f.get_file(), "x": c.x - 135, "y": c.y - 240})
				ti += 1
				if x + 135 >= mw:
					break
				x = mini(x + 270, mw - 135)
			if y + 240 >= mh:
				break
			y = mini(y + 480, mh - 240)
		var exits := []
		for e in m.exits:
			var r: Rect2i = m._exit_zone(e)
			exits.append({"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "to": str(e["scene"]), "label": str(e.get("label", ""))})
		var gates := []
		for c: Vector2i in m.things:
			var t := str(m.things[c].get("type", ""))
			if t in ["mega_gate", "door", "travel"] or t.contains("gate"):
				gates.append({"cell": [c.x, c.y], "type": t})
		var info := {"scene": sc, "w": mw, "h": mh, "off": [m.offset().x, m.offset().y], "tiles": tiles,
			"exits": exits, "gates": gates, "track": m.area_track() if m.has_method("area_track") else ""}
		var fa := FileAccess.open("%s/%s.json" % [out, sc], FileAccess.WRITE)
		fa.store_string(JSON.stringify(info))
		fa.close()
		print("mosaic: %s %dx%d %d tiles" % [sc, mw, mh, tiles.size()])
	quit()
