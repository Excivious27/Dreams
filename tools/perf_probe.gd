extends SceneTree
## Performance probe: load time, frame time, nodes, draw calls and memory per map.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/perf_probe.gd -- [scene ...]
## (headless works too: no draw calls then). ARC=gangsters for the other arc. FRAMES=n (default 180).
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
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	print("perf_probe: arc=%s frames=%d" % [arc, frames])
	print("%-22s %8s %7s %7s %7s %6s %6s %6s %7s %7s %6s %6s" % ["scene", "load", "med", "p95", "max", "nodes", "draws", "dmax", "memMB", "texMB", "bake", "bakems"])
	for sc in scenes:
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		var t0 := Time.get_ticks_usec()
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		await process_frame
		await process_frame
		var t1 := Time.get_ticks_usec()
		for k in 20:
			await process_frame
		var d := Dialogue.instance(self)
		for k in 8:
			if d.active:
				d._advance(); await process_frame; await process_frame
		var m := current_scene as GameMap
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
		times.sort()
		dl.sort()
		# One baked-ground chunk re-rendered on its own: the painter's whole draw list.
		var bake_draws := 0
		var bake_ms := 0.0
		if m and not m._bake.is_empty():
			await process_frame
			var base := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var ch: Array = m._bake.values()[0]
			var tb := Time.get_ticks_usec()
			(ch[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			bake_ms = _ms(tb, Time.get_ticks_usec())
			bake_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) - base
		var n := times.size()
		print("%-22s %8.0f %7.1f %7.1f %7.1f %6d %6d %6d %7.0f %7.0f %6d %6.0f" % [sc, _ms(t0, t1), times[n / 2], times[int(n * 0.95)], times[n - 1],
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), dl[dl.size() / 2], draws,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, bake_draws, bake_ms])
	print("perf_probe: done")
	quit()
