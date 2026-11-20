extends SceneTree
## Seasonal looks and weather visuals (CONDUCT 5 P3):
##  - winter snowdrifts never sit on paths/roads/paving (WorldGen.on_path);
##  - a summer-look region (jungle) gets no snowdrifts in a winter month;
##  - leaves/petals drift as particles (no tiled overlay), each with its own pace;
##  - no bird flocks in storms; the weather layer dims at night;
##  - the calendar weather refreshes on a new day.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/season_look_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(5)
	_run.call_deferred()


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL ", msg)


func _drift_texs() -> Array:
	var out := []
	for i in 6:
		var t := Art.tex("props", "snowdrift_%d" % i)
		if t != null:
			out.append(t)
	return out


func _load(s: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = s
	GameState.run["flags"][s + "_seen"] = true
	change_scene_to_file("res://scenes/%s.tscn" % s)
	for i in 10:
		await process_frame
	return current_scene as GameMap


func _drifts(m: GameMap) -> Array:
	var dt := _drift_texs()
	var out := []
	for c in m.props:
		var n: Variant = m.props[c]
		if n is Sprite2D and is_instance_valid(n) and dt.has((n as Sprite2D).texture):
			out.append(c)
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["cm_seen", "meow_taught", "forest_seen", "lake_seen", "town_seen", "mountain_seen"]:
		GameState.run["flags"][f] = true
	var day := 3 * GameState.DAYS_PER_SEASON + 5  # winter
	GameState.run["day"] = day
	GameState.run["time"] = 9 * 60
	GameState.run["weather"] = {str(day): "snow", str(day + 1): "clear"}
	# 1. Town in winter: drifts exist, none on a path.
	if _drift_texs().is_empty():
		print("season_look_test: no snowdrift art, drift checks skipped")
	else:
		var total := 0
		for s in ["town", "mountain", "forest"]:
			var m: GameMap = await _load(s)
			if m == null:
				_fail("%s did not load" % s)
				continue
			var ds := _drifts(m)
			total += ds.size()
			for c: Vector2i in ds:
				if WorldGen.on_path(m, c):
					_fail("%s: snowdrift on a path at %s (%s)" % [s, c, m.ground_seam.get(c, m.step_word.get(c, "ext"))])
		if total == 0:
			_fail("no snowdrifts at all on winter maps (dressing broken?)")
		# 2. Jungle (summer look) in a winter month: no drifts.
		if ResourceLoader.exists("res://scenes/jungle.tscn"):
			var j: GameMap = await _load("jungle")
			if j != null:
				if GameState.look_se() != "summer":
					_fail("jungle look season is %s, want summer" % GameState.look_se())
				if not _drifts(j).is_empty():
					_fail("jungle has %d snowdrifts in winter" % _drifts(j).size())
	# 3. Weather layer: leaves/petals are particles; storm has no flocks; night dims it.
	var m2: GameMap = await _load("forest")
	var sky: Scenery = m2.sky
	if sky == null:
		_fail("forest has no sky")
	else:
		if paused:
			print("(tree paused by a scene beat: the test drives the sky anyway)")
		sky.process_mode = Node.PROCESS_MODE_ALWAYS
		sky._canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		for w in ["leaves", "petals"]:
			sky.weather = w
			if sky._overlay() != null:
				_fail("%s still uses a tiled overlay" % w)
			for i in 5:
				await process_frame
			if sky._parts.size() < 10:
				_fail("%s: only %d particles" % [w, sky._parts.size()])
			else:
				var speeds := {}
				for p: Dictionary in sky._parts:
					speeds[snappedf(float(p.get("fall", 0.0)), 0.1)] = true
				if speeds.size() < 5:
					_fail("%s particles all fall at the same pace (grid look)" % w)
		sky.weather = "storm"
		sky._birds.clear()
		sky._next_flock = 0.0
		var gt := 0.0
		while gt < 20.0:
			await process_frame
			gt += root.get_process_delta_time()
		if not sky._birds.is_empty():
			_fail("birds fly in a storm")
		GameState.run["time"] = 23 * 60
		sky._tint_acc = 1.0
		for i in 3:
			await process_frame
		var mc: Color = sky._canvas.modulate
		if mc.r > 0.95 and mc.g > 0.95 and mc.b > 0.95:
			_fail("weather layer not dimmed at night (%s)" % mc)
		# 4. Calendar weather follows the day.
		GameState.run["time"] = 9 * 60
		sky.weather = GameState.weather_today()
		GameState.run["day"] = day + 1
		for i in 3:
			await process_frame
		if sky.weather != "clear":
			_fail("weather did not refresh on the new day (%s)" % sky.weather)
	print("season_look_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
