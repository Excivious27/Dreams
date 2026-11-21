extends SceneTree
## C14b P1: weather and sky motion (scripts/scenery.gd) on game time.
##   godot --headless --fixed-fps 60 --path . -s res://tools/weather_fx_test.gd
##   (with a display: ... -s res://tools/weather_fx_test.gd -- /tmp/out  saves frame strips)
## - rain/storm/drizzle/hail and snow/blizzard use code particles, never a tiled overlay
## - drops fall along their velocity between frames (no strobing in place); storm > rain counts
## - snow has 3 depth layers with different fall speeds; blizzard has more flakes
## - reduced motion halves the counts
## - a lightning bolt keeps one x for its whole flash
## - clear spring/fall days get a light petal/leaf sprinkle; summer none
## - the aurora draws (no boxed picture needed)
var fails := 0
var out := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	_run.call_deferred()


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["time"] = 12 * 60
	var was := bool(Settings.get_v("shake"))
	Settings.set_v("shake", true)
	var m := (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 4:
		await process_frame
	var sky: Scenery = m.sky
	check(sky != null, "farm has a sky")
	if sky == null:
		quit(1)
		return
	paused = false
	sky.process_mode = Node.PROCESS_MODE_ALWAYS
	sky._canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	var counts := {}
	for w: String in ["rain", "storm", "drizzle", "hail"]:
		sky.weather = w
		check(sky._overlay() == null, "%s draws code drops, not a tiled strip" % w)
		for i in 3:
			await process_frame
		counts[w] = sky._drops.size()
		check(sky._drops.size() >= 40, "%s has drops (%d)" % [w, sky._drops.size()])
		if sky._drops.is_empty():
			continue
		var d0: Dictionary = sky._drops[0]
		var p0: Vector2 = d0["p"]
		await process_frame
		var p1: Vector2 = d0["p"]
		check(p1.y > p0.y + 1.0 or p1.y < p0.y - 100.0, "%s drop falls (%.1f -> %.1f)" % [w, p0.y, p1.y])
		for i in 80:
			await process_frame
		await _shot("w_" + w)
	check(int(counts.get("storm", 0)) > int(counts.get("rain", 0)), "storm heavier than rain")
	check(int(counts.get("drizzle", 0)) < int(counts.get("rain", 0)), "drizzle lighter than rain")
	for w: String in ["snow", "blizzard"]:
		sky.weather = w
		check(sky._overlay() == null, "%s draws code flakes" % w)
		for i in 3:
			await process_frame
		counts[w] = sky._snow.size()
		var layers := {}
		var falls := {}
		for f: Dictionary in sky._snow:
			layers[int(f["l"])] = true
			falls[snappedf(float(f["fall"]), 1.0)] = true
		check(layers.size() == 3, "%s has 3 depth layers (%d)" % [w, layers.size()])
		check(falls.size() >= 10, "%s flakes fall at many speeds (%d)" % [w, falls.size()])
		check(sky._parts.is_empty(), "%s: no flipping snowflake icons" % w)
		for i in 80:
			await process_frame
		await _shot("w_" + w)
	check(int(counts.get("blizzard", 0)) > int(counts.get("snow", 0)), "blizzard denser than snow")
	# reduced motion: fewer
	Settings.set_v("shake", false)
	sky.weather = "rain"
	for i in 3:
		await process_frame
	check(sky._drops.size() < int(counts["rain"]), "reduced motion: fewer drops (%d < %d)" % [sky._drops.size(), int(counts["rain"])])
	Settings.set_v("shake", true)
	# lightning keeps one spot through the flash
	sky.weather = "storm"
	sky._next_flash = 0.0
	var xs := {}
	for i in 20:
		await process_frame
		if sky._flash_t > 0.0:
			xs[sky._flash_x] = true
	check(xs.size() == 1, "one bolt x per flash (%d)" % xs.size())
	# seasonal sprinkle
	sky.weather = "clear"
	GameState.look_season = "fall"
	for i in 5:
		await process_frame
	check(sky._parts.size() >= 3 and sky._parts.size() <= 12, "fall clear day: a few leaves (%d)" % sky._parts.size())
	await _shot("w_fall_clear")
	GameState.look_season = "summer"
	sky._parts.clear()
	for i in 5:
		await process_frame
	check(sky._parts.is_empty(), "summer clear day: no leaves (%d)" % sky._parts.size())
	GameState.look_season = ""
	# aurora at night
	GameState.run["time"] = 23 * 60
	sky.aurora = true
	sky.weather = "clear"
	for i in 90:
		await process_frame
	check(sky._aur_tris > 100, "aurora ribbons drawn (%d tris)" % sky._aur_tris)
	await _shot("w_aurora_a")
	for i in 120:
		await process_frame
	await _shot("w_aurora_b")
	# water life: rain splashes / ripples spawn on visible water (beach has the sea in view)
	var wls := m.find_children("*", "WaterLife", true, false)
	check(wls.size() == 1, "map has one WaterLife")
	Settings.set_v("shake", was)
	m.queue_free()
	await process_frame
	var bm := (load("res://scenes/beach.tscn") as PackedScene).instantiate()
	root.add_child(bm)
	for i in 4:
		await process_frame
	var wl: WaterLife = bm.find_children("*", "WaterLife", true, false)[0] if not bm.find_children("*", "WaterLife", true, false).is_empty() else null
	check(wl != null, "beach has WaterLife")
	if wl:
		var cam := root.get_viewport().get_camera_2d()
		var deep := Vector2i(-1, -1)
		for y in bm.rows:
			for x in bm.cols:
				var c := Vector2i(x, y)
				if bm.is_water_cell(c) and bm.is_water_cell(c + Vector2i(1, 1)) and bm.is_water_cell(c - Vector2i(1, 1)) and bm.is_water_cell(c + Vector2i(1, -1)) and bm.is_water_cell(c + Vector2i(-1, 1)):
					deep = c
					break
			if deep.x >= 0:
				break
		check(deep.x >= 0, "beach has open water")
		paused = false
		wl.process_mode = Node.PROCESS_MODE_ALWAYS
		if cam and deep.x >= 0 and bm.player:
			bm.player.position = bm.cell_pos(deep.x, deep.y)
			cam.process_mode = Node.PROCESS_MODE_ALWAYS
			for i in 10:
				await process_frame
		bm.sky.weather = "storm"
		var peak := 0
		for i in 120:
			await process_frame
			peak = maxi(peak, wl._live)
		check(peak > 0 and peak <= WaterLife.MAX_LIVE, "storm splashes on visible water (peak %d)" % peak)
		await _shot("w_water_storm")
	bm.queue_free()
	await process_frame
	print("weather_fx_test: %d failures (rain %d, storm %d, snow %d, blizzard %d)" % [fails, int(counts.get("rain", 0)), int(counts.get("storm", 0)), int(counts.get("snow", 0)), int(counts.get("blizzard", 0))])
	quit(1 if fails > 0 else 0)
