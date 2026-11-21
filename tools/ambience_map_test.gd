extends SceneTree
## C13 P6 (c13_10-12 / c13_12-13): no place is ever silent. Loads every scene (but
## title/test_map) and every data/interiors.json room in both arcs and evaluates the
## Ambience beds over 4 seasons x dawn/day/dusk/night (clear weather) plus a rainy
## noon. Asserts: >= 1 bed everywhere; no wildlife beds in caves or cities; no
## gang-only beds (neon_street) in the penguin arc; rain beds only when wet; every
## bed has a file; no night music dip without a night bed. AMB_MAP_WRITE=1 writes
## docs/AMBIENCE-MAP.tsv (place, arc, state, beds).
##   godot --headless --path . --fixed-fps 60 -s res://tools/ambience_map_test.gd
var fails := 0
var checks := 0
var rows: Array = []
const DAYS := {"spring": 10, "summer": 38, "fall": 66, "winter": 94}
const SKIP := ["title", "test_map", "interior"]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		if fails < 60:
			print("  FAIL ", what)


func _initialize() -> void:
	seed(13)
	Campaign.bypass = true
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _load(arc: String, sc: String) -> GameMap:
	GameState.new_run(arc, "man", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 10
	for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "gangsters_intro", "partner_scene"]:
		GameState.run["flags"][f] = true
	var scene := sc
	if sc.begins_with("in_"):
		GameMap.next_interior = sc.trim_prefix("in_")
		scene = "interior"
	GameState.run["flags"][scene + "_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 6:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 4:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _run() -> void:
	var amb := Ambience.instance(self)
	await process_frame
	var places: Array = []
	var da := DirAccess.open("res://scenes")
	for f in da.get_files():
		if f.ends_with(".tscn") and f.trim_suffix(".tscn") not in SKIP:
			places.append(f.trim_suffix(".tscn"))
	places.sort()
	var f2 := FileAccess.open("res://data/interiors.json", FileAccess.READ)
	var ints: Dictionary = JSON.parse_string(f2.get_as_text())
	for k: String in ints:
		places.append("in_" + k)
	var only := OS.get_environment("AMB_MAP_ONLY")
	for arc: String in ["penguins", "gangsters"]:
		for sc: String in places:
			if only != "" and not sc.contains(only):
				continue
			var m: GameMap = await _load(arc, sc)
			if m == null:
				continue  # gang-only maps that refuse the other arc
			var id := m.scene_id()
			var outdoors := m.has_sky and id not in ["house", "interior"]
			var cave := Ambience.is_cave(m)
			var urban := Ambience.is_urban(m)
			var quiet := Ambience.is_quiet(m)
			for se: String in DAYS:
				GameState.run["day"] = int(DAYS[se])
				var sr := GameState.sunrise()
				var ss := GameState.sunset()
				var states := [["dawn", sr, "clear"], ["day", 720, "clear"], ["dusk", ss, "clear"], ["night", 23 * 60, "clear"]]
				if outdoors and not cave and se == "summer":
					states.append(["rain", 720, "rain"])
				for st: Array in states:
					GameState.run["time"] = int(st[1])
					if m.sky and m.has_sky:
						m.sky.weather = str(st[2])
					var b: Dictionary = amb._evaluate()
					var tag := "%s %s %s %s" % [arc, sc, se, st[0]]
					check(not b.is_empty(), "%s: at least one bed" % tag)
					for k: String in b:
						check(ResourceLoader.exists("res://audio/amb/%s.ogg" % k), "%s: bed %s has a file" % [tag, k])
						if k in Ambience.WILD_BEDS:
							check(not cave and not urban and not quiet, "%s: no wildlife bed %s in a cave/city/quiet land" % [tag, k])
						if arc == "penguins":
							check(k != "neon_street", "%s: no gang-only neon bed in the penguin arc" % tag)
						if k in ["rain_light", "rain_heavy"]:
							check(str(st[2]) in ["rain", "storm"] or not m.has_sky, "%s: rain bed only when wet" % tag)
					var mu := Music._inst
					if mu != null and str(st[0]) == "night" and outdoors and str(st[2]) == "clear":
						var nightbed := false
						for k: String in b:
							nightbed = nightbed or k in ["crickets", "frogs", "campfire", "marsh", "jungle_insects"]
						if not nightbed:
							check(is_equal_approx(float(mu.get("_duck")), 0.0), "%s: no night dip without night sounds" % tag)
					var ks := b.keys()
					ks.sort()
					rows.append("%s\t%s\t%s\t%s\t%s" % [sc, arc, se, st[0], ",".join(ks)])
	if only == "":
		await _focused(amb)
	if OS.get_environment("AMB_MAP_WRITE") == "1":
		var out := FileAccess.open("res://docs/AMBIENCE-MAP.tsv", FileAccess.WRITE)
		out.store_string("place\tarc\tseason\tstate\tbeds\n" + "\n".join(rows) + "\n")
	print("ambience_map_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Focused rows: the Hideout is woodland (birds by day, no city by day; the gang arc's
## night hum only), penguin Neon/Uptown have a city bed on dry days and nights, the casino
## floor and the mill have their own tones, and bed fades take the intended time.
func _focused(amb: Ambience) -> void:
	for arc: String in ["penguins", "gangsters"]:
		var m: GameMap = await _load(arc, "hideout")
		if m != null:
			GameState.run["day"] = 10
			GameState.run["time"] = 720
			m.sky.weather = "clear"
			var b: Dictionary = amb._evaluate()
			check(b.has("birds_day") and not b.has("city_hum"), "%s hideout noon: birds, no city hum (%s)" % [arc, b.keys()])
			GameState.run["time"] = 23 * 60
			b = amb._evaluate()
			check(b.has("crickets"), "%s hideout night: crickets" % arc)
			check(b.has("city_hum") == (arc == "gangsters"), "%s hideout night: city hum only in the gang arc" % arc)
	for sc: String in ["neon", "uptown"]:
		var m2: GameMap = await _load("penguins", sc)
		if m2 == null:
			continue
		GameState.run["day"] = 10
		for t: int in [720, 23 * 60]:
			GameState.run["time"] = t
			m2.sky.weather = "clear"
			var b2: Dictionary = amb._evaluate()
			check(b2.has("town_day") or b2.has("city_hum"), "penguin %s %d: a city bed" % [sc, t])
	for arc2: String in ["penguins", "gangsters"]:
		var mc: GameMap = await _load(arc2, "in_gilt_casino")
		if mc != null:
			check(amb._evaluate().has("crowd"), "%s casino floor: crowd tone" % arc2)
	var mm: GameMap = await _load("penguins", "in_water_mill")
	if mm != null:
		check(amb._evaluate().has("river"), "water mill: the river through the wall")
	var ms: GameMap = await _load("gangsters", "in_stable")
	if ms != null:
		check(amb._evaluate().has("machines"), "gang stable door is Halo's garage: machines")
	# Fades: a bed from OFF_DB to -15 dB with the slow fade takes about _fade seconds.
	var p := AudioStreamPlayer.new()
	p.volume_db = Ambience.OFF_DB
	amb.add_child(p)
	amb._beds["zz_test"] = p
	amb._fade = 2.5
	var gt := 0.0
	var reached := -1.0
	while gt < 4.0:
		amb._eval_t = 99.0
		amb._target = {"zz_test": -15.0}
		amb._process(1.0 / 60.0)
		gt += 1.0 / 60.0
		if reached < 0.0 and p.volume_db >= -16.0:
			reached = gt
	check(reached >= 2.0 and reached <= 3.0, "bed fade-in takes ~2.5 s (%.2f)" % reached)
	amb._beds.erase("zz_test")
	p.queue_free()
