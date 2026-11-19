extends SceneTree
## Dev helper: screenshots of mine floors, several entries each (the layout is
## re-rolled on every entry). Also writes a whole-floor layout map per entry.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 \
##     -s res://tools/mine_shot.gd -- /tmp/out 1 2 3 10 25 [entries=3] [open=1] [maps_only=1]
## open=1 opens the shaft (keeper beaten) and stands you next to it.
## style=<id> forces a layout style (see scripts/mine_layouts.gd).
## keeper=1 wakes the floor's keeper and stands you in front of it.
## look=bridge stands you on the first hazard crossing (if the layout made one).
func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := str(args[0]) if args.size() > 0 else "/tmp/shots"
	DirAccess.make_dir_recursive_absolute(out)
	var entries := 1
	var open_way := false
	var maps_only := false
	var look_bridge := false
	var keeper := false
	var floors: Array = []
	for a: String in args.slice(1):
		if a.begins_with("entries="):
			entries = int(a.split("=")[1])
		elif a.begins_with("open="):
			open_way = a.ends_with("1")
		elif a.begins_with("style="):
			var ms: Variant = load("res://scripts/mine.gd")
			ms.force_style = a.split("=")[1]
		elif a == "keeper=1":
			keeper = true
		elif a == "look=bridge":
			look_bridge = true
		elif a.begins_with("maps_only="):
			maps_only = a.ends_with("1")
		else:
			floors.append(int(a))
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	GameState.run["flags"]["partner_scene"] = true
	var styles := {}
	for f: int in floors:
		for e in entries:
			GameState.run["mine_floor"] = f
			if open_way:
				GameState.run["flags"]["mine_open_%d" % f] = true
			change_scene_to_file("res://scenes/mine.tscn")
			for i in (12 if maps_only else 40):
				await process_frame
			var m := current_scene as GameMap
			var d := Dialogue.instance(self)
			for i in 20:
				if d.active:
					d._advance() if not d._in_choice else d._choose("", 0)
				await process_frame
			var n := 0
			var rocks := 0
			var ores := 0
			for c in m.things:
				var ty := str(m.things[c].get("type", ""))
				if ty in ["forage", "crate", "mchest", "bigchest"]:
					n += 1
				elif ty == "rock":
					rocks += 1
					if str(m.things[c].get("ore", "stone")) != "stone":
						ores += 1
			var st: Dictionary = m.get("_style")
			styles[str(st.get("id", ""))] = int(styles.get(str(st.get("id", "")), 0)) + 1
			print("floor %d entry %d: %s / %s  %dx%d open=%d rocks=%d ore=%d (1 in %.1f) findables=%d enemies=%d bridges=%d threshold=%d" % [f, e, str(st.get("id", "")), str(m.get("_dress")), m.cols, m.rows, (m.get("_open") as Dictionary).size(), rocks, ores, float(rocks) / maxf(1.0, ores), n, m.enemies.size(), (m.get("_bridge") as Dictionary).size(), int(m.call("_threshold"))])
			_layout_png(m, "%s/map_f%d_e%d.png" % [out, f, e])
			if maps_only:
				continue
			if open_way:
				var lad: Vector2i = m.get("_ladder")
				m.player.position = m.cell_center(lad + Vector2i(0, 2))
				for i in 10:
					await process_frame
			if keeper:
				m.call("_summon_guardian")
				var tk := Time.get_ticks_msec()
				while m.get("_guardian") == null and Time.get_ticks_msec() - tk < 3000:
					await process_frame
				var gk: Enemy = m.get("_guardian")
				if gk:
					m.player.position = gk.position + Vector2(0, 30)
					gk.set_process(false)
				for i in 10:
					await process_frame
			var brd: Dictionary = m.get("_bridge")
			if look_bridge and not brd.is_empty():
				var bc: Vector2i = brd.keys()[0]
				m.player.position = m.cell_center(bc)
				for i in 10:
					await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/mine_f%d_e%d.png" % [out, f, e])
	print("styles seen: ", styles)
	quit()


## Whole floor at 3 px a cell: rock, floor, water, chasm, lava, bridges, rocks,
## entry (green) and ladder (yellow).
func _layout_png(m: GameMap, path: String) -> void:
	var k := 3
	var img := Image.create(m.cols * k, m.rows * k, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.1, 0.14))
	var op: Dictionary = m.get("_open")
	var ch: Dictionary = m.get("_chasm")
	var lv: Dictionary = m.get("_lava")
	var br: Dictionary = m.get("_bridge")
	for c: Vector2i in op:
		var col := Color(0.55, 0.5, 0.45)
		var t: Dictionary = m.things.get(c, {})
		if ch.has(c):
			col = Color(0.02, 0.0, 0.05)
		elif lv.has(c):
			col = Color(0.95, 0.4, 0.1)
		elif str(t.get("type", "")) == "water":
			col = Color(0.2, 0.45, 0.75)
		elif br.has(c):
			col = Color(0.7, 0.5, 0.25)
		elif str(t.get("type", "")) == "rock":
			col = Color(0.35, 0.33, 0.36) if str(t.get("ore", "stone")) == "stone" else Color(0.85, 0.6, 0.2)
		img.fill_rect(Rect2i(c.x * k, c.y * k, k, k), col)
	var en: Vector2i = m.get("_entry")
	var la: Vector2i = m.get("_ladder")
	img.fill_rect(Rect2i(en.x * k - 3, en.y * k - 3, k + 6, k + 6), Color(0.2, 1.0, 0.3))
	img.fill_rect(Rect2i(la.x * k - 3, la.y * k - 3, k + 6, k + 6), Color(1.0, 0.95, 0.2))
	img.save_png(path)
