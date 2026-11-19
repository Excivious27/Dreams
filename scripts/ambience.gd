class_name Ambience
extends Node
## Background sound that follows the clock, the season, the weather and where
## you are: birds at dawn, crickets on summer nights, wind in winter, rain,
## waves at the shore, the hum of the city, drips in the mine.
##
## Beds are looping files in audio/amb/<bed>.ogg; spots are one-shots in
## audio/amb/spot_<name>.wav, played a little way off so they pan. Real
## recordings drop in under the same names (tools/make_ambience.py makes the
## placeholders and never overwrites a name listed in audio/amb/REAL.txt).

static var _inst: Ambience
var _beds := {}        # bed -> AudioStreamPlayer
var _target := {}      # bed -> dB
var _eval_t := 0.0
var _fade := 2.5
var _spot_t := {}      # spot -> seconds until next
var _rooster_day := -1
var _thunder_in := -1.0
var _cache := {}
const OFF_DB := -45.0
const MAX_BEDS := 4

const SEA_MAPS := ["beach", "docks", "bf_dockside", "colony_coral", "colony_kelp"]
const WINDY_MAPS := ["mountain", "highlands", "sky", "station", "colony_ice", "quarry"]
const CITY_MAPS := ["neon", "uptown", "docks", "hideout", "bf_neon_block"]
const CAVE_MAPS := ["mine", "underground", "hollow_heart"]  # the quarry is an open pit: wind, not a cave drone
const OWL_MAPS := ["farm", "forest", "meadow", "orchard_hills", "countryside", "lake"]
const BIRDY_MAPS := ["forest", "orchard_hills", "meadow"]
## Outdoors but no birds, crickets or frogs: the underground country, dead or hot lands, space.
const QUIET_MAPS := ["hollow_heart", "wastes", "colony_ember", "moon", "station", "sky"]
var _quick_t := 0.0


static func instance(tree: SceneTree) -> Ambience:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Ambience.new()
		_inst.name = "Ambience"
		tree.root.add_child.call_deferred(_inst)
	return _inst


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called by GameMap when a new map is ready: re-evaluate now with a quicker fade.
func scene_changed() -> void:
	_eval_t = 0.0
	_quick_t = 1.5  # _apply_targets uses the quicker fade while this runs


## Thunder a moment after a lightning flash.
func thunder() -> void:
	_thunder_in = randf_range(0.3, 1.8)


func _process(delta: float) -> void:
	_quick_t -= delta
	_eval_t -= delta
	if _eval_t <= 0.0:
		_eval_t = 0.5
		_target = _evaluate()
		_apply_targets()
	# Move each bed toward its target volume.
	for b: String in _beds.keys():
		var p: AudioStreamPlayer = _beds[b]
		var want: float = _target.get(b, OFF_DB)
		var cur := db_to_linear(p.volume_db)
		var goal := db_to_linear(want)
		var step := delta / maxf(0.1, _fade)
		cur = move_toward(cur, goal, step)
		p.volume_db = linear_to_db(maxf(cur, 0.0001))
		if want <= OFF_DB and p.volume_db <= OFF_DB + 1.0:
			p.stop()
			p.queue_free()
			_beds.erase(b)
	if _thunder_in >= 0.0 and not get_tree().paused:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			_spot("thunder", -2.0)
	_spots(delta)


func _map() -> GameMap:
	var t := get_tree()
	return t.current_scene as GameMap if t and t.current_scene is GameMap else null


func _muted() -> bool:
	var m := Music._inst
	return m != null and is_instance_valid(m) and m._muted


## Dawn, day, dusk or night, using the same seasonal sun times as the lighting.
static func phase(t: int) -> String:
	var sr := GameState.sunrise()
	var ss := GameState.sunset()
	if t >= sr - 30 and t < sr + 90:
		return "dawn"
	if t >= ss - 60 and t < ss + 60:
		return "dusk"
	if t >= sr + 90 and t < ss - 60:
		return "day"
	return "night"


func _evaluate() -> Dictionary:
	var out := {}
	var m := _map()
	if m == null or _muted() or Epilogue.showing:
		return out
	var id := m.scene_id()
	var t := int(GameState.run.get("time", 480))
	var ph := phase(t)
	var se := GameState.look_se()  # the region's look (an ice colony in summer still sounds like winter)
	var w := GameState.weather_today()
	if m.sky and m.has_sky:
		w = m.sky.weather
	var deep := id == "hollow_heart"  # underground country: no surface weather, wind or night sky
	if deep:
		w = "clear"
	var wet := w in ["rain", "storm"]
	var snowy := w in ["snow", "blizzard"]
	var outdoors := m.has_sky and id not in ["house", "interior"]
	var gang := Racket.on()
	var wild := outdoors and id not in QUIET_MAPS
	if outdoors:
		var near := _water_near(m)
		if wild:
			if ph == "dawn" and se != "winter" and not wet and not snowy:
				out["birds_dawn"] = -10.0 + (3.0 if id in BIRDY_MAPS else 0.0)
			if ph == "day" and se in ["spring", "summer", "fall"] and not wet and not snowy and id not in CITY_MAPS:
				out["birds_day"] = -16.0 - (4.0 if se == "fall" else 0.0)
			if ph in ["dusk", "night"] and se in ["spring", "summer", "fall"] and not wet and id not in CITY_MAPS:
				out["crickets"] = -14.0 - (4.0 if se == "spring" else 0.0)
			if ph == "night" and se in ["spring", "summer"] and (near > 0.3 or id in ["marsh", "bf_bog_crossing"]):
				out["frogs"] = -16.0 + 6.0 * (near - 1.0)
		if (se == "winter" and not deep) or id in WINDY_MAPS or w == "wind":
			out["wind_soft"] = -10.0 if w == "wind" else -14.0
		if w == "blizzard" or id == "colony_ice":
			out["wind_strong"] = -6.0
		if w == "rain":
			out["rain_light"] = -8.0
		elif w == "storm":
			out["rain_heavy"] = -5.0
		if id in SEA_MAPS:
			out["waves"] = -8.0
		elif near > 0.05:
			out["water_lap"] = -14.0 + 10.0 * (near - 1.0)
		if id == "colony_ember":
			out["lava"] = -18.0
		if id == "wastes":
			out["wind_soft"] = -12.0
		if w == "leaves" or (se == "fall" and id == "forest"):
			out["leaves"] = -18.0
		if id == "town" and t >= 8 * 60 and t < (23 * 60 if GameState.festival_today() != "" else 20 * 60) and not wet:
			if GameState.festival_today() != "":
				out["crowd"] = -14.0
			else:
				out["town_day"] = -20.0
		if gang and id in CITY_MAPS:
			out["city_hum"] = -18.0
	else:
		if id in ["house", "interior"]:
			if GameState.is_wet():
				out["rain_roof"] = -16.0
			if se in ["fall", "winter"] or ph == "night":
				out["hearth"] = -18.0
	if id in CAVE_MAPS:
		out["cave"] = -14.0
		var th: Dictionary = m.get("theme") if m.get("theme") is Dictionary else {}
		var feat := str(th.get("feat", ""))
		if feat == "lava":
			out["lava"] = -14.0
		elif "crystal" in str(th.get("cave", "")):
			out["crystal_hum"] = -20.0
	if id in ["moon", "station"]:
		out["space"] = -16.0
	# CC0 recordings (tools/cc0_import.py): rivers, fires, streets, jungles, marsh.
	if outdoors:
		var wn := _water_near(m)
		if id in ["riverlands", "farm"] and wn > 0.2:
			out["river"] = -16.0 + 8.0 * (wn - 1.0)
		if id == "jungle" and not wet:
			out["jungle_insects"] = -14.0
		if id in ["marsh", "bf_bog_crossing"]:
			out["marsh"] = -16.0
		if gang and id in ["neon", "bf_neon_block", "uptown"]:
			out["neon_street"] = -16.0
		if id in ["countryside", "highlands", "mountain"] and not wet and ph != "night":
			out["wind_soft"] = maxf(float(out.get("wind_soft", -40.0)), -18.0)
		if GameState.festival_today() != "" and id == "town" and ph == "night":
			out["campfire"] = -20.0
	elif id == "interior":
		var kind := str(m.get("interior_id")) if m.get("interior_id") != null else ""
		if "kitchen" in kind or "bakery" in kind or "diner" in kind:
			out["boiling"] = -22.0
		if "smith" in kind or "forge" in kind or "workshop" in kind:
			out["machines"] = -24.0
	# Regions can name their own beds (regions.json "amb": {bed: dB}, the mega regions).
	var rd: Variant = m.get("R")
	if rd is Dictionary and (rd as Dictionary).has("amb"):
		for k: String in rd["amb"]:
			if ph != "night" or not str(k).begins_with("birds"):
				out[k] = float(rd["amb"][k])
	# Keep the loudest few.
	if out.size() > MAX_BEDS:
		var ks := out.keys()
		ks.sort_custom(func(a: String, b: String) -> bool: return float(out[a]) > float(out[b]))
		var trimmed := {}
		for k in ks.slice(0, MAX_BEDS):
			trimmed[k] = out[k]
		out = trimmed
	# Let night sounds and storms through by dipping the music a little.
	var duck := 0.0
	if outdoors and ph == "night" and not deep:
		duck = -4.0
	if w in ["storm", "blizzard"] and outdoors:
		duck = minf(duck, -3.0) - (1.0 if duck < 0.0 else 0.0)  # a night storm dips more than a calm night
	var mu := Music._inst
	if mu and is_instance_valid(mu):
		mu.set_duck(duck)
	return out


func _apply_targets() -> void:
	for b: String in _target:
		if _beds.has(b):
			continue
		var s := _stream("res://audio/amb/%s.ogg" % b)
		if s == null:
			continue
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") != -1 else "SFX"
		p.stream = s
		p.volume_db = OFF_DB
		add_child(p)
		p.play(randf() * 8.0)
		_beds[b] = p
	_fade = 1.2 if _quick_t > 0.0 else 2.5


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## 0..1: how close the nearest swimmable water is (checks 13x13 cells).
func _water_near(m: GameMap) -> float:
	if m.player == null:
		return 0.0
	var pc := m.world_to_cell(m.player.position)
	var best := 99.0
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if m.is_water_cell(pc + Vector2i(dx, dy)):
				best = minf(best, Vector2(dx, dy).length())
	return 0.0 if best > 8.0 else clampf(1.0 - best / 8.0, 0.0, 1.0)


func _spots(delta: float) -> void:
	var m := _map()
	if m == null or _muted() or Epilogue.showing or m.player == null or get_tree().paused:
		return
	var id := m.scene_id()
	var t := int(GameState.run.get("time", 480))
	var ph := phase(t)
	var outdoors := m.has_sky and id not in ["house", "interior"]
	var w := m.sky.weather if m.sky and m.has_sky and id != "hollow_heart" else GameState.weather_today()
	var calm := w not in ["rain", "storm", "blizzard", "snow"]
	var rules := []  # [spot, min_s, max_s, dB]
	if outdoors and calm and ph == "night" and id in OWL_MAPS:
		rules.append(["owl", 25.0, 60.0, -8.0])
	if outdoors and calm and id not in QUIET_MAPS and GameState.look_se() == "winter" and ph == "day":
		rules.append(["bird_chirp", 8.0, 20.0, -12.0])
	if id == "crystal_meadow" and GameState.is_penguins():
		rules.append(["penguin_chatter", 10.0, 25.0, -10.0])
	if id in CAVE_MAPS:
		rules.append(["drip", 3.0, 9.0, -10.0])
	if outdoors and calm and id in SEA_MAPS and ph != "night":
		rules.append(["gull", 10.0, 26.0, -12.0])
		rules.append(["wave", 7.0, 16.0, -14.0])
	if outdoors and calm and ph == "day" and id in ["farm", "countryside", "orchard_hills", "meadow"] and GameState.look_se() != "winter":
		rules.append(["crow", 30.0, 70.0, -14.0])
	if outdoors and ph in ["dusk", "night"] and id in ["marsh", "lake", "bf_bog_crossing"]:
		rules.append(["frog", 6.0, 16.0, -12.0])
	if outdoors and calm and ph == "day" and GameState.look_se() == "summer" and id in ["jungle", "forest", "meadow", "orchard_hills"]:
		rules.append(["cicada", 20.0, 45.0, -16.0])
	if outdoors and calm and id in ["jungle", "marsh"]:
		rules.append(["insect", 12.0, 30.0, -16.0])
	for r: Array in rules:
		var k := str(r[0])
		_spot_t[k] = float(_spot_t.get(k, randf_range(float(r[1]), float(r[2])))) - delta
		if float(_spot_t[k]) <= 0.0:
			_spot_t[k] = randf_range(float(r[1]), float(r[2]))
			_spot(k, float(r[3]))
	# The rooster crows once each morning on the farm.
	var day := int(GameState.run.get("day", 1))
	if id == "farm" and _rooster_day != day and t >= mini(GameState.sunrise(), GameState.DAY_START) and t < maxi(GameState.sunrise(), GameState.DAY_START) + 40:
		_rooster_day = day
		_spot("rooster", -6.0)


func _spot(name: String, db: float) -> void:
	var m := _map()
	var s := _stream("res://audio/amb/spot_%s.ogg" % name)  # CC0 recording (tools/cc0_import.py)
	if s == null:
		s = _stream("res://audio/amb/spot_%s.wav" % name)
	if s == null or m == null or m.player == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") != -1 else "SFX"
	p.volume_db = db
	p.max_distance = 400.0
	var ang := randf() * TAU
	p.position = m.player.position + Vector2(cos(ang), sin(ang)) * randf_range(60.0, 140.0)
	if name == "thunder":
		p.position = m.player.position + Vector2(randf_range(-40, 40), -60)
	m.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
