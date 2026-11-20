extends SceneTree
## Where sound plays (C6 P4): Ambience bed choice per place/time/season/weather, and the
## arc-aware area/boss songs. Headless:
##   godot --headless --path . --fixed-fps 60 -s res://tools/ambience_test.gd
var fails := 0
var checks := 0
const SPRING_DAY := 10
const WINTER_DAY := 92
const NOON := 720
const NIGHT := 23 * 60


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _load(arc: String, sc: String, day: int) -> GameMap:
	GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	GameState.run["day"] = day
	for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "gangsters_intro", "partner_scene"]:
		GameState.run["flags"][f] = true
	var scene := sc
	if sc.begins_with("in_"):
		GameMap.next_interior = sc.trim_prefix("in_")
		scene = "interior"
	GameState.run["flags"][scene + "_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 12:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 6:
		if d.active:
			d._advance()
			await process_frame
			await process_frame
	return current_scene as GameMap


func _beds(m: GameMap, day: int, t: int, weather := "") -> Dictionary:
	GameState.run["day"] = day
	GameState.run["time"] = t
	if weather != "" and m.sky and m.has_sky:
		m.sky.weather = weather
	return Ambience.instance(self)._evaluate()


func _run() -> void:
	var amb := Ambience.instance(self)
	await process_frame
	var m: GameMap
	var b: Dictionary
	# Caves: no surface beds (wind, streets) from the region lists.
	for sc: String in ["frost_caverns", "gilt_vaults", "iron_tunnels"]:
		m = await _load("gangsters", sc, SPRING_DAY)
		if m == null:
			check(false, "%s loads" % sc)
			continue
		b = _beds(m, SPRING_DAY, NOON)
		for k: String in ["wind_soft", "wind_strong", "town_day", "city_hum", "crowd", "birds_day"]:
			check(not b.has(k), "%s has no %s (got %s)" % [sc, k, str(b.keys())])
		check(b.has("cave"), "%s has the cave bed" % sc)
	# Region wildlife beds follow time and season.
	m = await _load("penguins", "gloam_moonpool", WINTER_DAY)
	if m:
		b = _beds(m, WINTER_DAY, NOON, "snow")
		check(not b.has("crickets") and not b.has("frogs"), "gloam_moonpool winter noon: no crickets/frogs (got %s)" % str(b.keys()))
		b = _beds(m, SPRING_DAY, NOON, "clear")
		check(not b.has("crickets"), "gloam_moonpool spring noon: no crickets (got %s)" % str(b.keys()))
	# Battlefields: themed, no birds on the station deck.
	m = await _load("penguins", "bf_station_deck", SPRING_DAY)
	if m:
		b = _beds(m, SPRING_DAY, NOON, "clear")
		check(not b.has("birds_day") and b.has("space"), "bf_station_deck: space, no birds (got %s)" % str(b.keys()))
		b = _beds(m, SPRING_DAY, NIGHT, "clear")
		check(not b.has("crickets"), "bf_station_deck night: no crickets (got %s)" % str(b.keys()))
	m = await _load("penguins", "bf_sewer_works", SPRING_DAY)
	if m:
		b = _beds(m, SPRING_DAY, NOON, "clear")
		check(Ambience.is_cave(m) and not b.has("birds_day"), "bf_sewer_works is a cave (got %s)" % str(b.keys()))
	# City mega areas: no countryside wildlife.
	m = await _load("gangsters", "gilt_casino_row", SPRING_DAY)
	if m:
		b = _beds(m, SPRING_DAY, NOON, "clear")
		check(not b.has("birds_day"), "casino row: no birds (got %s)" % str(b.keys()))
		b = _beds(m, SPRING_DAY, NIGHT, "clear")
		check(not b.has("crickets") and float(b.get("crowd", -99.0)) >= -18.0, "casino row night: busy, no crickets (got %s)" % str(b))
	# Mine lava floors (theme feat is an Array).
	m = await _load("penguins", "mine", SPRING_DAY)
	if m:
		m.set("theme", {"cave": "stone", "feat": ["lava"]})
		b = _beds(m, SPRING_DAY, NOON)
		check(b.has("lava"), "lava mine floor plays lava (got %s)" % str(b.keys()))
	# Hearth only in rooms with a fireplace.
	m = await _load("penguins", "in_rec", WINTER_DAY)
	if m:
		b = _beds(m, WINTER_DAY, NIGHT)
		check(not b.has("hearth"), "rec has no hearth (got %s)" % str(b.keys()))
	# Songs: arc-aware places and bosses.
	m = await _load("penguins", "countryside", SPRING_DAY)
	if m:
		GameState.run["time"] = NOON
		check(m.area_track() != "countryside", "penguin countryside is not the gang harmonica song (got %s)" % m.area_track())
		check(m.boss_track("big_grump") in ["boss_penguin", "boss"], "penguin big_grump -> penguin theme")
	m = await _load("gangsters", "countryside", SPRING_DAY)
	if m:
		GameState.run["time"] = NOON
		check(m.boss_track("big_grump") != "boss_penguin", "gang big_grump never plays boss_penguin")
		check(m.boss_track("garden_boss") in ["boss_gang", "boss"], "gang mega rival -> gang theme")
	m = await _load("gangsters", "crystal_meadow", SPRING_DAY)
	if m:
		GameState.run["time"] = NOON
		check(m.area_track() != "rain", "the Outskirts don't play the rain song on a dry day (got %s)" % m.area_track())
	m = await _load("penguins", "town", 14)  # spring festival day
	if m:
		GameState.run["time"] = 3 * 60
		check(m.area_track() != "festival", "no festival song at 3am (got %s)" % m.area_track())
		GameState.run["time"] = NOON
		check(m.area_track() == "festival", "festival song at noon (got %s)" % m.area_track())
	check("finargle" in GameMap.BOSS_TRACKS, "finargle counts as boss music")
	# Notes may carry a cue.
	GameMap.notify("Test note", "j_birthday")
	var last: Variant = (GameState.run.get("notes", []) as Array).back()
	check(last is Dictionary and str(last.get("sfx")) == "j_birthday", "notify keeps its cue")
	check(GameMap.animal_voice("cow") == "moo" and GameMap.animal_voice("chick") == "peep", "animal voices")
	print("ambience_test: %d failures (%d checks)" % [fails, checks])
	quit(1 if fails > 0 else 0)
