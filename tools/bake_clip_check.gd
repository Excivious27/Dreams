extends SceneTree
## Clipped chunk bakes (GameMap.bake_clip) must draw exactly what the full painter
## list draws. For each scene: re-bake every chunk near the player once from the
## full list and once clipped, compare the pixels, and print draw calls / ms.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/bake_clip_check.gd -- [scene ...]
## Exit code 1 when any chunk differs (max channel difference > TOL on > 0.05% of pixels).
const TOL := 6
const DEFAULT := ["farm", "town", "meadow", "forest", "mountain", "community_farm", "gloam_lanternfall", "wind_breezehaven", "bf_orchard_line", "bf_neon_block"]
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scenes: Array = Array(args) if args.size() > 0 else DEFAULT
	InputSetup.ensure_actions()
	GameState.new_run(OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	for sc: String in scenes:
		GameState.run["flags"][sc + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		for k in 30:
			await process_frame
		var m := current_scene as GameMap
		if m == null or m._painter == null:
			print("%s: not baked, skipped" % sc)
			continue
		m.process_mode = Node.PROCESS_MODE_DISABLED  # freeze the world; the bake layer runs ALWAYS
		var keys: Array = m._bake.keys()
		var full := {}
		var clip := {}
		var stats := {"full": [0, 0.0], "clip": [0, 0.0]}
		for mode in ["full", "clip"]:
			GameMap.bake_clip = mode == "clip"
			m.queue_redraw()  # a fresh full pass first, as after any real redraw
			for k in 6:
				await process_frame
			for key: Vector2i in keys:
				if not m._bake.has(key):
					continue
				await process_frame
				var base := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var t0 := Time.get_ticks_usec()
				m._bake[key][2] = true  # stale: re-baked alone this frame
				m._bake_busy = true
				m._bake_last = Vector2(INF, INF)
				await process_frame
				var dt := (Time.get_ticks_usec() - t0) / 1000.0
				var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) - base
				await process_frame
				if not m._bake.has(key):
					continue
				var img: Image = (m._bake[key][0] as SubViewport).get_texture().get_image()
				(full if mode == "full" else clip)[key] = img
				stats[mode][0] += dc
				stats[mode][1] += dt
		GameMap.bake_clip = true
		var worst := 0.0
		for key in full:
			if not clip.has(key):
				continue
			var a: Image = full[key]
			var b: Image = clip[key]
			var bad := 0
			for y in range(0, a.get_height(), 2):
				for x in range(0, a.get_width(), 2):
					var ca := a.get_pixel(x, y)
					var cb := b.get_pixel(x, y)
					if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), maxf(absf(ca.b - cb.b), absf(ca.a - cb.a))) * 255.0 > TOL:
						bad += 1
			var frac := bad * 4.0 / float(a.get_width() * a.get_height())
			worst = maxf(worst, frac)
			if frac > 0.0005:
				fails += 1
				var out := OS.get_environment("OUT")
				if out != "":
					a.save_png("%s/%s_%d_%d_full.png" % [out, sc, key.x, key.y])
					b.save_png("%s/%s_%d_%d_clip.png" % [out, sc, key.x, key.y])
				print("BAKE_CLIP FAIL: %s chunk %s differs on %.2f%% of pixels" % [sc, key, frac * 100.0])
		var n := maxi(1, full.size())
		print("%-20s chunks %2d  full: %5.0f draws %6.1f ms   clipped: %5.0f draws %6.1f ms   worst diff %.3f%%" % [sc, full.size(),
			float(stats["full"][0]) / n, float(stats["full"][1]) / n, float(stats["clip"][0]) / n, float(stats["clip"][1]) / n, worst * 100.0])
	print("bake_clip_check: %d failures" % fails)
	quit(1 if fails > 0 else 0)
