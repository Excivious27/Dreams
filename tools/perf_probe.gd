extends SceneTree
## Performance probe: load time, frame time, nodes, draw calls and memory per map.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/perf_probe.gd -- [scene ...]
## (headless works too: no draw calls then). ARC=gangsters for the other arc. FRAMES=n (default 180).
## BREAKDOWN=1 lists the nodes costing the most draw calls. Exits are off while walking (EXITS=1 to allow).
## arcade:<id> probes a cabinet game (jumper stack whack claw gallery).
## in_<interior> probes an interior (in_rec, in_rec_up); REC=1 opens the Rec Center on league night.
## Each line: scene, load ms (change_scene -> first frame), median/p95/max frame ms while
## the player walks a square, nodes, draw calls, static memory MB, texture MB.
const DEFAULT := ["title", "farm", "town", "meadow", "forest", "beach", "mountain", "community_farm",
	"gloam_lanternfall", "desert_mirage_post", "frost_hearthhold", "wind_breezehaven", "gilt_grand_plaza",
	"iron_junction", "bf_orchard_line", "bf_neon_block", "hollow_heart", "mine"]

func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()

func _ms(a: int, b: int) -> float:
	return (b - a) / 1000.0

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scenes: Array = Array(args) if args.size() > 0 else DEFAULT
	var frames := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 180
	InputSetup.ensure_actions()
	GameMap.exits_off = OS.get_environment("EXITS") == ""  # stay on the probed map (EXITS=1: old behaviour)
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	if OS.get_environment("REC") != "":  # league night at an open Rec Center: visitors on both floors
		GameState.run["flags"]["rec_open"] = 1
		GameState.run["day"] = 10
		GameState.run["time"] = 19 * 60 + 30
	print("perf_probe: arc=%s frames=%d" % [arc, frames])
	print("%-22s %8s %7s %7s %7s %6s %6s %6s %7s %7s %6s %6s" % ["scene", "load", "med", "p95", "max", "nodes", "draws", "dmax", "memMB", "texMB", "bake", "bakems"])
	for sc in scenes:
		if sc.begins_with("arcade:"):
			await _arcade(sc.trim_prefix("arcade:"), frames)
			continue
		var file: String = sc
		if sc.begins_with("in_"):  # in_<interior id>: an interior (in_rec, in_rec_up...)
			GameMap.next_interior = sc.trim_prefix("in_")
			GameState.run["flags"]["int_" + sc.trim_prefix("in_")] = true
			file = "interior"
		GameState.run["flags"][file + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		var t0 := Time.get_ticks_usec()
		change_scene_to_file("res://scenes/%s.tscn" % file)
		var fts: Array = []
		var uncover := -1  # frames until the arrival cover lifts (baked maps; GameMap._fade_in_when_baked)
		for k in 60:
			await process_frame
			fts.append(Time.get_ticks_usec())
			var lm := current_scene as GameMap
			if uncover < 0 and lm != null and k >= 1 and not bool(lm.get("_bake_covered")):
				uncover = k
			if k >= 3 and uncover >= 0:
				break
		var t1: int = fts[1]
		var fmax := 0.0
		for k in range(1, fts.size()):
			fmax = maxf(fmax, _ms(fts[k - 1], fts[k]))
		print("  %s load frames: %.0f / %.0f / %.0f / %.0f ms; longest load frame after the first %.0f ms; cover lifts at frame %d (%.0f ms)" % [sc, _ms(t0, fts[0]), _ms(fts[0], fts[1]), _ms(fts[1], fts[2]), _ms(fts[2], fts[3]), fmax, uncover, _ms(t0, fts[maxi(uncover, 0)])])
		for k in 18:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
		var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))  # at rest on arrival (C9 P6)
		var times: Array = []
		var dirs := ["right", "down", "left", "up"]
		var last := Time.get_ticks_usec()
		var draws := 0
		var dl: Array = []
		for k in frames:
			var act: String = dirs[(k / 30) % 4]
			if m and m.player:
				for a in dirs:
					Input.action_release(a)
				Input.action_press(act)
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(_ms(last, now))
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			draws = max(draws, dc)
			dl.append(dc)
			if OS.get_environment("SPIKES") != "" and (_ms(last, now) > 60.0 or dc > 1000):
				print("  spike %s frame %d: %.0f ms, %d draws, player %s" % [sc, k, _ms(last, now), dc, m.player.position if m and m.player else Vector2.ZERO])
			last = now
		for a in dirs:
			Input.action_release(a)
		var left_to := ""
		if not is_instance_valid(m) or current_scene != m:
			# The square walk went through an exit: the numbers below mix two maps
			# (the change_scene frame is the "hitch"). Say so instead of blaming this map.
			left_to = (current_scene as GameMap).scene_id() if current_scene is GameMap else "?"
		print("  %s nodes: %d on arrival, %d after the walk%s" % [sc, nodes0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), (" (walked out to %s: frame/node numbers mix both maps)" % left_to) if left_to != "" else ""])
		times.sort()
		dl.sort()
		# One baked-ground chunk re-rendered on its own: the painter's whole draw list.
		var bake_draws := 0
		var bake_ms := 0.0
		if m and not m._bake.is_empty():
			# Median of 5 single-chunk re-bakes (one is noisy on a shared CPU); ms = that whole frame.
			var bds: Array = []
			var bms: Array = []
			for rep in 5:
				await process_frame
				var base := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				# Re-bake one chunk the way the game does (stale, alone in its frame:
				# a clipped painter pass when GameMap.bake_clip is on).
				var key: Vector2i = m._bake.keys()[rep % m._bake.size()]
				var tb := Time.get_ticks_usec()
				m._bake[key][2] = true
				m._bake_busy = true
				m._bake_last = Vector2(INF, INF)
				await process_frame
				bms.append(_ms(tb, Time.get_ticks_usec()))
				bds.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) - base)
			bds.sort()
			bms.sort()
			bake_draws = bds[2]
			bake_ms = bms[2]
		# A full ground redraw (the painter's _draw in GDScript + the visible chunks): what a
		# map pays on its first frame and on every season/tilling redraw.
		var redraw_ms := 0.0
		if m and m.get("_painter") != null:
			var rds: Array = []
			var plain := 0.0
			for rep in 3:  # median of 3
				await process_frame
				var tq := Time.get_ticks_usec()
				await process_frame
				plain = _ms(tq, Time.get_ticks_usec())
				tq = Time.get_ticks_usec()
				if not is_instance_valid(m):
					break  # the probe walked into an exit: this map is gone
				m.queue_redraw()
				await process_frame
				await process_frame
				rds.append(_ms(tq, Time.get_ticks_usec()) - 2.0 * plain)
			rds.sort()
			redraw_ms = rds[rds.size() / 2] if not rds.is_empty() else 0.0
			print("  %s full redraw %.0f ms (median of 3; plain frame %.0f ms)" % [sc, redraw_ms, plain])
		if OS.get_environment("BREAKDOWN") != "" and is_instance_valid(m):
			await _breakdown(m)
		var n := times.size()
		print("%-22s %8.0f %7.1f %7.1f %7.1f %6d %6d %6d %7.0f %7.0f %6d %6.0f" % [sc, _ms(t0, t1), times[n / 2], times[int(n * 0.95)], times[n - 1],
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), dl[dl.size() / 2], draws,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, bake_draws, bake_ms])
	print("perf_probe: done")
	quit()


## arcade:<id> (jumper, stack, whack, claw, gallery): the cabinet over the Rec Center
## floor, started with a coin, mashed by a bot; open ms, frame ms, draws.
func _arcade(id: String, frames: int) -> void:
	if not (current_scene is GameMap and current_scene.get("interior_id") == "rec"):
		GameMap.next_interior = "rec"
		GameState.run["flags"]["int_rec"] = true
		change_scene_to_file("res://scenes/interior.tscn")
		for k in 20:
			await process_frame
	GameState.run["crystals"] = 99999
	var t0 := Time.get_ticks_usec()
	var g := ArcadeHub.open(current_scene, id)
	await process_frame
	var t1 := Time.get_ticks_usec()
	for k in 10:
		await process_frame
	if id == "jumper":
		g.call("play_tile", 0)
	else:
		g.start()
	var times: Array = []
	var dl: Array = []
	var last := Time.get_ticks_usec()
	var acts := ["a", "left", "right", "up", "down"]
	for k in frames:
		g.bot = {acts[(k / 7) % acts.size()]: k % 3 != 0}
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(_ms(last, now))
		dl.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		last = now
		if not is_instance_valid(g):
			break
	times.sort()
	dl.sort()
	var n := times.size()
	print("%-22s %8.0f %7.1f %7.1f %7.1f %6d %6d %6d" % ["arcade:" + id, _ms(t0, t1), times[n / 2], times[int(n * 0.95)], times[n - 1],
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), dl[dl.size() / 2], dl[dl.size() - 1]])
	if is_instance_valid(g):
		g.close()
	for k in 5:
		await process_frame


func _dc() -> int:
	await process_frame
	await process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


## BREAKDOWN=1: hide each visible CanvasItem under the map (two levels deep) in turn and
## print what it costs in draw calls (largest first): where a scene's draws go.
func _breakdown(m: Node) -> void:
	# Freeze the battle (units spawning/moving change the draw count between samples).
	var bt = m.get("battle")
	if bt is Node:
		(bt as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var base := await _dc()
	var rows: Array = []
	var items: Array = []
	for c in m.get_children():
		items.append(c)
		for g in c.get_children():
			items.append(g)
	for c in items:
		if not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		(c as CanvasItem).visible = false
		var dc := await _dc()
		(c as CanvasItem).visible = true
		if base - dc >= 3:
			rows.append([base - dc, "%s (%s%s)" % [c.name, c.get_class(), (" " + str(c.get("mode"))) if c.get("mode") != null else ""]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("  breakdown (%d draws):" % base)
	for r in rows.slice(0, 12):
		print("    %5d  %s" % [r[0], r[1]])
	if bt is Node and is_instance_valid(bt):
		(bt as Node).process_mode = Node.PROCESS_MODE_INHERIT
