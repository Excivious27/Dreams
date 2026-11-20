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
const OWL_MAPS := ["farm", "forest", "meadow", "orchard_hills", "countryside", "lake", "community_farm"]
const BIRDY_MAPS := ["forest", "orchard_hills", "meadow"]
## C11a P5: maps that can hold farm animals (pen spots, the rooster). A pasture scene joins here.
const RANCH_MAPS := ["farm"]
## Pen spots per species (C11a P5): [spot, min_s, max_s, dB]. A spot plays audio/amb/spot_<spot>
## takes, else the species' voice takes in audio/sfx (VOICE_FALLBACK), from a real animal of that
## species on the map (positional), so a named cow still moos and a co-op guest hears the host's herd.
const PEN_SPOTS := {"chicken": ["hens", 25.0, 60.0, -20.0], "cow": ["cow", 40.0, 90.0, -20.0],
	"goat": ["goat", 45.0, 100.0, -22.0], "sheep": ["sheep", 45.0, 100.0, -22.0], "duck": ["duck", 35.0, 80.0, -22.0],
	"horse": ["horse", 60.0, 120.0, -22.0], "llama": ["llama", 60.0, 120.0, -24.0], "pig": ["pig", 45.0, 100.0, -22.0],
	"bees": ["bees", 30.0, 60.0, -24.0]}
const VOICE_FALLBACK := {"goat": "bleat", "sheep": "sheep", "duck": "quack", "horse": "whinny", "llama": "bleat", "pig": "oink", "bees": "buzz"}
## Animal-kind prefixes (FarmAnimal.kind / art names) -> species. Babies count with their species.
const KIND_SPECIES := [["rooster", "rooster"], ["chick", "chicken"], ["chicken", "chicken"], ["hen", "chicken"],
	["calf", "cow"], ["cow", "cow"], ["kid", "goat"], ["goat", "goat"], ["lamb", "sheep"], ["sheep", "sheep"],
	["duck", "duck"], ["foal", "horse"], ["horse", "horse"], ["donkey", "horse"], ["llama", "llama"],
	["piglet", "pig"], ["pig", "pig"], ["rabbit", "rabbit"], ["bee", "bees"]]
## Animal buildings indoors: interior id -> species heard inside (spots from the animals themselves).
const ROOM_ANIMALS := {"stable": ["horse"], "coop": ["chicken", "duck"], "barn": ["cow", "goat", "sheep"]}
var _herd := {}        # species -> Array of Node2D (refreshed with the beds)
var _herd_t := 0.0
## Outdoors but no birds, crickets or frogs: the underground country, dead or hot lands, space.
const QUIET_MAPS := ["hollow_heart", "wastes", "colony_ember", "moon", "station", "sky"]
var _quick_t := 0.0
## Mega areas that are caves or vaults even before regions.json says "cave": true (C4 c4_12 #2).
const MEGA_CAVES := ["frost_caverns", "gilt_vaults", "iron_tunnels", "desert_sunken_temple", "hollow_deeps"]
## Mega regions with no birds, crickets or frogs anywhere (dry desert); regions.json "quiet": true adds more.
const QUIET_REGIONS := ["sunscorch"]
const WILD_BEDS := ["birds_dawn", "birds_day", "crickets", "frogs"]
## Where each bed sits (dB on a -26 LUFS file): weather loudest, wildlife and town below it,
## room tones and textures under that; indoor rain under outdoor rain.
const BED_LEVEL := {"birds_dawn": -11.0, "birds_day": -14.0, "crickets": -13.0, "frogs": -15.0,
	"wind_soft": -12.0, "wind_strong": -8.0, "rain_light": -10.0, "rain_heavy": -7.0, "waves": -9.0,
	"water_lap": -14.0, "lava": -12.0, "leaves": -16.0, "crowd": -12.0, "town_day": -15.0, "city_hum": -15.0,
	"campfire": -15.0, "rain_roof": -15.0, "hearth": -15.0, "cave": -12.0, "crystal_hum": -16.0,
	"basement_drips": -15.0, "space": -14.0, "river": -13.0, "jungle_insects": -12.0, "marsh": -14.0,
	"neon_street": -14.0, "boiling": -16.0, "machines": -17.0, "room_shop": -17.0, "room_chapel": -19.0}
## The base each rule above was written against (the old per-file-compensated numbers): modifiers
## (season, nearness, tapers, region tweaks) stay relative to these.
const OLD_BASE := {"birds_dawn": -10.0, "birds_day": -16.0, "crickets": -14.0, "frogs": -16.0,
	"wind_soft": -14.0, "wind_strong": -6.0, "rain_light": -8.0, "rain_heavy": -5.0, "waves": -8.0,
	"water_lap": -14.0, "lava": -14.0, "leaves": -18.0, "crowd": -14.0, "town_day": -20.0, "city_hum": -18.0,
	"campfire": -22.0, "rain_roof": -16.0, "hearth": -18.0, "cave": -14.0, "crystal_hum": -20.0,
	"basement_drips": -20.0, "space": -16.0, "river": -16.0, "jungle_insects": -14.0, "marsh": -16.0,
	"neon_street": -16.0, "boiling": -22.0, "machines": -24.0, "room_shop": -22.0, "room_chapel": -22.0}
## Rooms with a fireplace (the hearth bed plays only here, plus the farmhouse) (c6_07).
const HEARTH_ROOMS := ["cottage_a", "cottage_b", "cottage_c", "hazel_house", "inn", "lodge", "mansion", "moss_hut",
	"tam_hut", "river_hut", "fishing_hut", "sel_camp", "lighthouse"]
## Themed battlefields (bf_themes FIELDS): their own beds, and whether wildlife/caves apply (c6_07).
const BF_AMB := {
	"bf_station_deck": {"amb": {"space": -16.0, "machines": -24.0}, "quiet": true},
	"bf_ash_wastes": {"amb": {"wind_soft": -12.0}, "quiet": true},
	"bf_sewer_works": {"amb": {"cave": -16.0, "basement_drips": -18.0}, "cave": true},
	"bf_reef_shallows": {"amb": {"waves": -9.0}}, "bf_kelp_beds": {"amb": {"waves": -10.0}},
	"bf_rail_yards": {"amb": {"city_hum": -18.0, "machines": -26.0}, "urban": true},
	"bf_uptown_plaza": {"amb": {"city_hum": -18.0, "neon_street": -20.0}, "urban": true},
	"bf_neon_block": {"urban": true}, "bf_dockside": {"urban": true},
	"bf_highland_pass": {"amb": {"wind_soft": -13.0}}, "bf_cloud_stair": {"amb": {"wind_soft": -11.0}, "quiet": true},
	"bf_frostfield": {"amb": {"wind_soft": -11.0}}, "bf_jungle_grove": {"amb": {"jungle_insects": -15.0}},
	"bf_river_ford": {"amb": {"river": -15.0}}, "bf_quarry_cut": {"amb": {"wind_soft": -16.0}, "quiet": true},
}
## Region looks that are towns and cities: no birds, crickets or frogs (c6_07).
const URBAN_STYLES := ["city", "chrome", "clockwork"]
const URBAN_REGIONS := ["giltcity", "ironline"]
## Beds that stop under rain and snow, and the ones that are night/day only, wherever they come from.
const NIGHT_BEDS := ["crickets", "frogs", "campfire"]


## The map's region data (regions.json entry), or {}.
## Region beds a deep cave never plays (they belong above ground).
const SURFACE_BEDS := ["wind_soft", "wind_strong", "town_day", "crowd", "city_hum", "neon_street", "birds_day", "birds_dawn", "waves", "leaves", "rain_light", "rain_heavy"]


static func _rd(m: GameMap) -> Dictionary:
	var rd: Variant = m.get("R")
	return rd if rd is Dictionary else {}


## A cave-like map: the Valley's caves, or a region area flagged "cave" (default list MEGA_CAVES).
static func is_cave(m: GameMap) -> bool:
	var id := m.scene_id()
	if id in CAVE_MAPS:
		return true
	if bool((BF_AMB.get(id, {}) as Dictionary).get("cave", false)):
		return true
	var rd := _rd(m)
	return bool(rd.get("cave", id in MEGA_CAVES))


## Outdoors but no wildlife sounds: QUIET_MAPS, caves, regions marked quiet / dry.
static func is_quiet(m: GameMap) -> bool:
	var id := m.scene_id()
	if id in QUIET_MAPS or is_cave(m) or is_urban(m):
		return true
	if bool((BF_AMB.get(id, {}) as Dictionary).get("quiet", false)):
		return true
	var rd := _rd(m)
	return bool(rd.get("quiet", str(rd.get("mega", "")) in QUIET_REGIONS))


## A town or city map (Valley streets, Gilt City, Ironline, urban battlefields): no countryside wildlife.
static func is_urban(m: GameMap) -> bool:
	var id := m.scene_id()
	if id in CITY_MAPS or bool((BF_AMB.get(id, {}) as Dictionary).get("urban", false)):
		return true
	var rd := _rd(m)
	if bool(rd.get("urban", false)) or str(rd.get("mega", "")) in URBAN_REGIONS:
		return true
	var th: Variant = rd.get("theme")
	return th is Dictionary and str((th as Dictionary).get("style", "")) in URBAN_STYLES


## May a wildlife/weather-sensitive bed play now? The same gates for built-in and region beds.
static func wild_ok(bed: String, ph: String, se: String, wet: bool, snowy: bool) -> bool:
	match bed:
		"crickets":
			return ph in ["dusk", "night"] and se in ["spring", "summer", "fall"] and not wet and not snowy
		"frogs":
			return ph in ["dusk", "night"] and se in ["spring", "summer"] and not snowy
		"birds_day":
			return ph == "day" and se != "winter" and not wet and not snowy
		"birds_dawn":
			return ph == "dawn" and se != "winter" and not wet and not snowy
		"campfire":
			return ph in ["dusk", "night"] and not wet
		"leaves":
			return not wet and not snowy
		"jungle_insects":
			return se != "winter"
	return true


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
		_set_duck(0.0)  # never leave the night/storm dip on the ending songs (c6_07)
		return out
	var id := m.scene_id()
	var t := int(GameState.run.get("time", 480))
	var ph := phase(t)
	var se := GameState.look_se()  # the region's look (an ice colony in summer still sounds like winter)
	var w := GameState.weather_today()
	if m.sky and m.has_sky:
		w = m.sky.weather
	var cave := is_cave(m)
	var deep := id == "hollow_heart" or (cave and id not in CAVE_MAPS)  # underground: no surface weather, wind or night sky
	if deep:
		w = "clear"
	var wet := w in ["rain", "storm"]
	var snowy := w in ["snow", "blizzard"]
	var outdoors := m.has_sky and id not in ["house", "interior"]
	var gang := Racket.on()
	var wild := outdoors and not is_quiet(m)
	var urban := is_urban(m)
	if outdoors:
		var near := _water_near(m)
		if wild:
			if ph == "dawn" and se != "winter" and not wet and not snowy:
				out["birds_dawn"] = -10.0 + (3.0 if id in BIRDY_MAPS else 0.0)
			if ph == "day" and se in ["spring", "summer", "fall"] and not wet and not snowy and id not in CITY_MAPS:
				out["birds_day"] = -16.0 - (4.0 if se == "fall" else 0.0)
			if ph in ["dusk", "night"] and se in ["spring", "summer", "fall"] and not wet and id not in CITY_MAPS:
				out["crickets"] = -14.0 - (4.0 if se == "spring" else 0.0)
			if ph == "night" and se in ["spring", "summer"] and not snowy and id not in SEA_MAPS and (near > 0.3 or id in ["marsh", "bf_bog_crossing"]):
				out["frogs"] = -16.0 + 6.0 * (near - 1.0)  # fresh water only: no frogs at the salt docks
		if (se == "winter" and not deep) or id in WINDY_MAPS or w == "wind":
			# Winter wind by place: open ground gusts, sheltered streets and woods are calmer; nights a little quieter.
			var wdb := -14.0
			if se == "winter" and w != "wind":
				wdb = -12.0 if id in ["mountain", "meadow", "beach", "highlands", "crystal_meadow"] else (-18.0 if id in ["town", "forest"] or urban else -14.0)
				if ph == "night":
					wdb -= 2.0
			out["wind_soft"] = -10.0 if w == "wind" else wdb
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
		if id == "wastes" or (str(_rd(m).get("mega", "")) in QUIET_REGIONS and not cave):
			out["wind_soft"] = -12.0  # dry lands: a hot wind instead of birds
		if (w == "leaves" or (se == "fall" and id == "forest")) and not wet and not snowy:
			out["leaves"] = -18.0 - (6.0 if ph == "night" else 0.0)
		if id == "town" and t >= 8 * 60 and t < (23 * 60 if GameState.festival_today() != "" else 20 * 60) and not wet:
			if GameState.festival_today() != "":
				out["crowd"] = -14.0 - (10.0 * clampf(float(t - 22 * 60) / 60.0, 0.0, 1.0))  # tapers 22:00-23:00
			else:
				out["town_day"] = -20.0
		if gang and id in CITY_MAPS:
			out["city_hum"] = -18.0
		if id == "community_farm" and not wet and ph in ["day", "dusk"]:
			# Market day draws a crowd; otherwise the volunteers' campfire crackles in the picnic corner.
			if Commons.market_day() and ph == "day":
				out["crowd"] = -16.0
			elif Commons.stage() >= 1 and ph == "dusk":
				out["campfire"] = -22.0
	else:
		if id in ["house", "interior"]:
			if GameState.is_wet():
				out["rain_roof"] = -16.0
			var room := str(m.get("interior_id")) if m.get("interior_id") != null else ""
			if (id == "house" or room in HEARTH_ROOMS) and (se in ["fall", "winter"] or ph == "night"):
				out["hearth"] = -18.0
			if w == "storm" and out.has("rain_roof"):
				out["rain_roof"] = -12.0  # a storm drums harder than drizzle
	if cave:
		out["cave"] = -14.0
		var th: Dictionary = m.get("theme") if m.get("theme") is Dictionary else {}
		var fv: Variant = th.get("feat", [])
		var feat: Array = fv if fv is Array else [str(fv)]  # mine THEMES feat is an Array (c6_07)
		if "lava" in feat:
			out["lava"] = -14.0
		elif "crystals" in feat or "crystal" in str(th.get("cave", "")):
			out["crystal_hum"] = -20.0
		if "water" in feat:
			out["basement_drips"] = -20.0  # flooded floors: water in the dark
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
		if GameState.festival_today() != "" and id == "town" and ph == "night" and not wet:
			out["campfire"] = -20.0
	elif id == "interior":
		var kind := str(m.get("interior_id")) if m.get("interior_id") != null else ""
		if "kitchen" in kind or "bakery" in kind or "diner" in kind:
			out["boiling"] = -22.0
		if "smith" in kind or "forge" in kind or "workshop" in kind:
			out["machines"] = -24.0
		# Room tones (P3 C6 beds; silent until the files exist): shop murmur, chapel/library hush.
		if kind in ["store", "potions", "bakery", "bank", "inn"]:
			out["room_shop"] = -22.0
		elif kind in ["chapel", "library", "school"]:
			out["room_chapel"] = -22.0
		if kind in ["rec", "rec_up"]:
			out.merge(RecAudio.beds(kind), true)  # arcade cabinets downstairs, rolling balls and pins upstairs
	# Regions can name their own beds (regions.json "amb": {bed: dB}, the mega regions).
	# "amb_day" / "amb_night" (C4) take over from "amb" by time of day (a casino street is busy by
	# day and quiet at night); caves and quiet lands never take birds, crickets or frogs.
	if outdoors and BF_AMB.has(id):
		var bfa: Dictionary = (BF_AMB[id] as Dictionary).get("amb", {})
		for k: String in bfa:
			out[k] = float(bfa[k])
	var rdd := _rd(m)
	var night := ph in ["dusk", "night"]
	var bed_key := "amb"
	if night and rdd.has("amb_night"):
		bed_key = "amb_night"
	elif not night and rdd.has("amb_day"):
		bed_key = "amb_day"
	if rdd.get(bed_key) is Dictionary:
		var quiet := is_quiet(m)
		for k: String in rdd[bed_key]:
			if ph == "night" and str(k).begins_with("birds"):
				continue
			if quiet and k in WILD_BEDS:
				continue
			if (deep or cave) and k in SURFACE_BEDS:
				continue  # C5: a mega cave's region beds (wind, streets) stay on the surface
			if not wild_ok(k, ph, se, wet, snowy):
				continue  # region beds follow the clock, season and weather like the built-in ones (c6_07)
			var db := float(rdd[bed_key][k])
			if night and bed_key == "amb" and k in ["crowd", "town_day"]:
				db -= 10.0  # no night list: the streets thin out after dark
			out[k] = db
	# Equal-loudness beds (C6 P3: every bed file is a -26 LUFS loop): the dB above are relative
	# choices; rebase each onto its LEVEL so no per-file compensation is left (c6_07).
	for k: String in out.keys():
		if BED_LEVEL.has(k) and OLD_BASE.has(k):
			out[k] = float(out[k]) - float(OLD_BASE[k]) + float(BED_LEVEL[k])
	# Keep the loudest few (now a real loudness ranking).
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
	if cave or not outdoors:
		duck = 0.0
	_set_duck(duck)
	return out


func _set_duck(db: float) -> void:
	var mu := Music._inst
	if mu and is_instance_valid(mu):
		mu.set_duck(db)


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
		if OS.has_feature("web"):
			p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # long beds: no decoded PCM in page memory (C9 P4)
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
		rules.append(["owl", 25.0, 60.0, -14.0])
	if outdoors and calm and not is_quiet(m) and GameState.look_se() == "winter" and ph == "day":
		rules.append(["bird_chirp", 8.0, 20.0, -18.0])
	var se := GameState.look_se()
	if id == "crystal_meadow" and GameState.is_penguins() and calm and ph != "night":
		rules.append(["penguin_chatter", 10.0, 25.0, -14.0])
	if is_cave(m):
		rules.append(["drip", 3.0, 9.0, -10.0])
	if outdoors and calm and id in SEA_MAPS and ph != "night":
		rules.append(["gull", 10.0, 26.0, -16.0])
		rules.append(["wave", 7.0, 16.0, -14.0])
	if outdoors and calm and ph == "day" and id in ["farm", "countryside", "orchard_hills", "meadow", "community_farm"] and GameState.look_se() != "winter":
		rules.append(["crow", 30.0, 70.0, -14.0])
	if outdoors and ph in ["dusk", "night"] and id in ["marsh", "lake", "bf_bog_crossing"] and (se in ["spring", "summer"] or (se == "fall" and ph == "dusk")) and w not in ["snow", "blizzard"]:
		rules.append(["frog", 6.0, 16.0, -12.0])
	if outdoors and calm and ph == "day" and GameState.look_se() == "summer" and id in ["jungle", "forest", "meadow", "orchard_hills"]:
		rules.append(["cicada", 20.0, 45.0, -16.0])
	_herd_t -= delta
	if _herd_t <= 0.0:
		_herd_t = 2.0
		_herd = herd_on(m)
	var pen_rules := pen_rules_for(id, outdoors, calm, ph, str(m.get("interior_id")) if m.get("interior_id") != null else "", _herd)
	if outdoors and calm and id in ["jungle", "marsh"] and se != "winter":
		rules.append(["insect", 12.0, 30.0, -16.0])
	if not outdoors and id in ["house", "interior"] and GameState.weather_today() == "storm":
		rules.append(["thunder", 20.0, 50.0, -16.0])  # muffled thunder through the walls (c6_07)
	# Region spot lists (regions.json "spots": [[spot, min_s, max_s, dB, phase?]], mega areas).
	var rspots: Variant = _rd(m).get("spots")
	if outdoors and rspots is Array:
		for r: Variant in rspots:
			if r is Array and (r as Array).size() >= 4:
				var ra := r as Array
				var need := str(ra[4]) if ra.size() > 4 else ""
				if need == "night" and ph not in ["dusk", "night"]:
					continue
				if need == "day" and ph not in ["dawn", "day"]:
					continue
				if not calm or (str(ra[0]) in ["frog", "insect", "cicada"] and se == "winter"):
					continue
				rules.append([str(ra[0]), float(ra[1]), float(ra[2]), float(ra[3])])
	if id == "interior" and m.get("interior_id") != null:
		rules.append_array(RecAudio.spots(str(m.get("interior_id"))))  # pins through the ceiling, a cabinet win
	for r: Array in rules:
		var k := str(r[0])
		_spot_t[k] = float(_spot_t.get(k, randf_range(float(r[1]), float(r[2])))) - delta
		if float(_spot_t[k]) <= 0.0:
			_spot_t[k] = randf_range(float(r[1]), float(r[2]))
			_spot(k, float(r[3]))
	for r: Array in pen_rules:  # [spot, min, max, dB, species]: from one of that species' animals
		var pk := "pen_" + str(r[0])
		_spot_t[pk] = float(_spot_t.get(pk, randf_range(float(r[1]), float(r[2])))) - delta
		if float(_spot_t[pk]) <= 0.0:
			_spot_t[pk] = randf_range(float(r[1]), float(r[2]))
			var src: Array = _herd.get(str(r[4]), [])
			if not src.is_empty():
				_spot(str(r[0]), float(r[3]), (src.pick_random() as Node2D).position, str(r[4]))
	# The rooster crows once each morning, from the rooster, when the farm has one (c11a_13-09).
	var day := int(GameState.run.get("day", 1))
	var roosters: Array = _herd.get("rooster", [])
	if id in RANCH_MAPS and not roosters.is_empty() and _rooster_day != day and t >= mini(GameState.sunrise(), GameState.DAY_START) and t < maxi(GameState.sunrise(), GameState.DAY_START) + 40:
		_rooster_day = day
		_spot("rooster", -10.0, (roosters[0] as Node2D).position)


## Species -> the animal nodes of that species on this map (FarmAnimal or any node with a "kind").
static func herd_on(m: Node) -> Dictionary:
	var out := {}
	if m == null:
		return out
	for c in m.get_children():
		if not (c is Node2D):
			continue
		var k: Variant = c.get("kind") if c is FarmAnimal else null
		if k == null:
			continue
		var sp := species_of(str(k))
		if sp == "":
			continue
		if not out.has(sp):
			out[sp] = []
		(out[sp] as Array).append(c)
	return out


## FarmAnimal kind ("cow_brown", "kid_goat", "piglet") -> species id ("" = not farm stock).
static func species_of(kind: String) -> String:
	var k := kind.to_lower()
	var sp := Ranch.species(k)
	if not sp.is_empty():
		return k
	for row: Array in KIND_SPECIES:
		if k.begins_with(str(row[0])):
			return str(row[1])
	return ""


## Pen spot rules for the animals present: outdoors on ranch maps by day in calm weather,
## and inside animal buildings (ROOM_ANIMALS) at any hour, quieter at night. Each row carries
## its species as a 5th field. Total kept to 3 species so the farm isn't a zoo.
static func pen_rules_for(id: String, outdoors: bool, calm: bool, ph: String, room: String, herd: Dictionary) -> Array:
	var out: Array = []
	var allowed: Array = []
	var night_db := 0.0
	if outdoors and calm and ph == "day" and id in RANCH_MAPS:
		allowed = PEN_SPOTS.keys()
	elif not outdoors and id == "interior" and ROOM_ANIMALS.has(room):
		allowed = ROOM_ANIMALS[room]
		night_db = -8.0 if ph == "night" else 0.0
	var kinds: Array = []
	for sp: String in allowed:
		if herd.has(sp) and not (herd[sp] as Array).is_empty() and PEN_SPOTS.has(sp):
			kinds.append(sp)
	kinds.sort_custom(func(a: String, b: String) -> bool: return (herd[a] as Array).size() > (herd[b] as Array).size())
	for sp: String in kinds.slice(0, 3):
		var r: Array = PEN_SPOTS[sp]
		# A bigger flock calls a little more often (up to twice as often at 8+).
		var rate := 1.0 / clampf(1.0 + float((herd[sp] as Array).size() - 1) / 7.0, 1.0, 2.0)
		out.append([str(r[0]), float(r[1]) * rate, float(r[2]) * rate, float(r[3]) + night_db, sp])
	return out


func _spot(name: String, db: float, at := Vector2.INF, species := "") -> void:
	var m := _map()
	# Every take of the spot (spot_<n>, spot_<n>_2, spot_<n>_3; .ogg CC0 recordings win over .wav).
	var takes := []
	for suf: String in ["", "_2", "_3"]:
		var st := _stream("res://audio/amb/spot_%s%s.ogg" % [name, suf])
		if st == null:
			st = _stream("res://audio/amb/spot_%s%s.wav" % [name, suf])
		if st != null:
			takes.append(st)
	# C11a P5: a pen spot with no ambience recording borrows the species' voice takes (quieter).
	if takes.is_empty() and species != "" and VOICE_FALLBACK.has(species):
		for suf2: String in ["", "_2", "_3"]:
			var vs := _stream("res://audio/sfx/%s%s.ogg" % [str(VOICE_FALLBACK[species]), suf2])
			if vs != null:
				takes.append(vs)
		db -= 4.0
	var s: AudioStream = takes.pick_random() if not takes.is_empty() else null
	if s == null or m == null or m.player == null:
		return
	if at != Vector2.INF and at.distance_to(m.player.position) > 300.0:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") != -1 else "SFX"
	p.volume_db = db
	p.max_distance = 260.0
	p.attenuation = 1.6  # the 60-140 px offset reads as distance, not a pop in the ear (c6_07)
	p.pitch_scale = randf_range(0.94, 1.06) if name != "thunder" else randf_range(0.8, 0.9)
	var ang := randf() * TAU
	p.position = m.player.position + Vector2(cos(ang), sin(ang)) * randf_range(60.0, 140.0)
	if at != Vector2.INF:
		# From the animal itself (c11a_13-10): a far pen fades with distance (past range: skipped above).
		p.max_distance = 300.0
		p.position = at
	if name == "thunder":
		p.position = m.player.position + Vector2(randf_range(-40, 40), -60)
	m.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
