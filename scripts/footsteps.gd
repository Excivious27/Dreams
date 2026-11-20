class_name Footsteps
## Which footstep a cell gets: grass, dirt, sand, stone, wood, snow, water, mud,
## gravel or leaves (Music.step plays audio/sfx/step_<word>).
## Paths record their word in GameMap.step_word as they are drawn (soft_ground,
## draw_ground, tile-set region paths, the town plaza); everything else falls back
## to the map's own ground, so lawns and meadows never clomp like cobbles.

## Region ground sets -> step word (data/regions.json "ground").
const GROUND := {"grass": "grass", "lawn": "grass", "teal_moss": "grass", "dead_grass": "grass", "cloud": "grass",
	"weedy_lot": "dirt", "shoulder": "gravel", "concrete_pier": "stone", "wet_asphalt_0": "stone",
	"sewer_brick": "stone", "metal_a": "stone"}
## Region path sets -> step word ("path").
const PATH := {"dirt": "dirt", "sand": "sand", "stone": "stone", "cobble": "stone", "snow": "snow",
	"asphalt2": "stone", "neon_sidewalk": "stone", "wood_dock": "wood", "float_stone": "stone",
	"metal_b": "stone", "sewer_mossy": "stone", "cracked_earth": "gravel"}
## Whole maps with one floor.
const FLOOR := {"house": "wood", "interior": "wood",
	"mine": "stone", "underground": "stone", "quarry": "stone", "hollow_heart": "stone", "moon": "stone", "station": "stone",
	"beach": "sand"}


## Record a path's step word for its cells (on the real map, not the painter twin).
static func mark(m: GameMap, cells: Dictionary, word: String) -> void:
	if word == "" or m == null:
		return
	var host: GameMap = m._painter_of if m._painter_of != null else m
	for c in cells:
		host.step_word[c] = word


## Exact seamless texture names first (substring order misreads these: c6_06).
const SEAM_EXACT := {"cobble_moss": "stone", "floor_carpet": "grass", "cave_earth_floor": "dirt", "teal_moss_wet": "mud"}
## Interior floors (data/interiors.json "floor") -> step word; anything else is wood.
const INTERIOR_FLOOR := {"fl_concrete": "stone", "fl_tile": "stone", "fl_stone": "stone", "fl_round_stone": "stone",
	"fl_quarry": "stone", "fl_marble": "stone", "fl_cobble": "stone", "fl_clinic": "stone", "fl_grate": "stone",
	"fl_dirt": "dirt", "fl_flour": "dirt", "fl_camp": "dirt",
	"fl_carpet_purple": "grass", "fl_carpet_red": "grass", "fl_carpet_blue": "grass"}  # carpet: the soft step
## Words that winter snow can cover (natural soft ground); stone, wood, sand, gravel keep their own.
const SNOW_OVER := ["grass", "dirt", "leaves", "mud", ""]


## Soft ground patches (seamless textures) -> step word.
static func seam_word(seam: String) -> String:
	if SEAM_EXACT.has(seam):
		return str(SEAM_EXACT[seam])
	if seam.begins_with("cave_earth"):
		return "dirt"
	if seam.begins_with("cave_") or seam.begins_with("crystal_floor"):
		return "stone"
	if "carpet" in seam:
		return "grass"
	for pair: Array in [["sand", "sand"], ["snow", "snow"], ["slush", "snow"], ["frost", "snow"], ["ice", "snow"],
			["bog", "mud"], ["mud", "mud"], ["boardwalk", "wood"], ["floor_oak", "wood"], ["floor_parquet", "wood"], ["floor_barn", "wood"],
			["grass", "grass"], ["moss", "grass"], ["cloud", "grass"], ["forest_floor", "leaves"], ["ballast", "gravel"], ["ash", "gravel"],
			["ruin", "stone"], ["stone", "stone"], ["cobble", "stone"], ["pave", "stone"], ["plaza", "stone"], ["brick", "stone"],
			["concrete", "stone"], ["asphalt", "stone"], ["road", "stone"], ["floor_", "stone"]]:
		if str(pair[0]) in seam:
			return str(pair[1])
	return "dirt"


static func path_word(kind: String) -> String:
	return str(PATH.get(kind, "stone" if ("stone" in kind or "asphalt" in kind or "metal" in kind or "brick" in kind) else "dirt"))


## The map's own ground, where no path was drawn.
static func base_word(m: GameMap) -> String:
	var id := m.scene_id()
	var rd: Variant = m.get("R")
	if rd is Dictionary and str((rd as Dictionary).get("ground_seam", "")) != "":
		return seam_word(str((rd as Dictionary)["ground_seam"]))  # seamless region ground (c6_06): sand, snow, stone, ballast...
	if rd is Dictionary and (rd as Dictionary).has("ground"):
		var g := str((rd as Dictionary)["ground"])
		return str(GROUND.get(g, "stone" if ("asphalt" in g or "metal" in g or "concrete" in g or "brick" in g) else "grass"))
	if id == "neon":
		return "stone"
	if id == "wastes":
		return "gravel"
	return "grass"


## Wood for piers, docks and ferries (things of those types), else "".
static func _deck_word(m: GameMap, c: Vector2i) -> String:
	if m.things.has(c):
		var ty := str((m.things[c] as Dictionary).get("type", ""))
		if ty in ["dock", "ferry", "pier", "bridge"]:
			return "wood"
	return ""


## Interior floor word from the room's data (interior.gd I.floor).
static func interior_word(m: GameMap) -> String:
	var idata: Variant = m.get("I")
	if idata is Dictionary:
		var fl := str((idata as Dictionary).get("floor", "fl_wood"))
		return str(INTERIOR_FLOOR.get(fl, "dirt" if "dirt" in fl else ("stone" if ("stone" in fl or "tile" in fl) else "wood")))
	return "wood"


## Mine floors by theme (earth -> dirt, ice -> snow, stone/lava -> stone) and plank crossings.
static func mine_word(m: GameMap, c: Vector2i) -> String:
	var br: Variant = m.get("_bridge")
	if br is Dictionary and (br as Dictionary).has(c):
		return "wood"
	var th: Variant = m.get("theme")
	if th is Dictionary:
		match str((th as Dictionary).get("var", "stone")):
			"earth":
				return "dirt"
			"ice":
				return "snow"
	return "stone"


## True when the map's ground can be snowed over by Valley winter (not caves, cities, sky, deserts).
static func can_snow(m: GameMap) -> bool:
	if not m.has_sky:
		return false
	var rd: Variant = m.get("R")
	if rd is Dictionary:
		var R := rd as Dictionary
		if bool(R.get("cave", false)) or bool(R.get("quiet", false)):
			return false
		if str(R.get("ground_seam", "")) != "" and not (base_word(m) in SNOW_OVER):
			return false
	return true


static func word(m: GameMap, c: Vector2i, swimming := false) -> String:
	if m == null:
		return "grass"
	var id := m.scene_id()
	if swimming or (m.is_water_cell(c) and _deck_word(m, c) == ""):
		return "water"
	var deck := _deck_word(m, c)
	if deck != "":
		return deck
	if id == "interior":
		return interior_word(m)
	if m.has_method("floor_at"):
		return str(m.call("floor_at", c))  # the house's per-room flooring (C10a P2)
	if id == "mine":
		return mine_word(m, c)
	var gw := str(m.step_word.get(c, m.ground_word.get(c, "")))
	if gw == "" and FLOOR.has(id):
		gw = str(FLOOR[id])
	if gw == "" and id == "farm" and not GameState.run.is_empty() and (GameState.run.get("farm", {}) as Dictionary).has("%d,%d" % [c.x, c.y]):
		gw = "dirt"  # tilled soil
	if gw == "":
		gw = base_word(m)
		if gw == "grass" and GameState.look_se() == "fall" and id in ["forest", "orchard_hills", "meadow"]:
			gw = "leaves"
	# Winter covers soft natural ground only, on maps that really draw winter ground (c6_06).
	if GameState.look_se() == "winter" and gw in SNOW_OVER and can_snow(m) and not FLOOR.has(id):
		return "snow"
	return gw


## Seconds between steps (c6_06): follows the actual speed (horse, buffs, exhaustion, swim) instead of
## a fixed 0.33/0.25 s. speed_ratio = current speed / base walk (or run) speed.
static func interval(running: bool, speed_ratio: float, swimming := false, mounted := false) -> float:
	if swimming:
		return 0.7 / clampf(speed_ratio, 0.5, 1.5)  # strokes
	if mounted:
		return 0.2 / clampf(speed_ratio, 0.6, 2.0)  # hoof beats
	return (0.25 if running else 0.33) / clampf(speed_ratio, 0.5, 2.0)


## Play one stride for the player: water strokes on the step voice (step_water, quiet), hoof hits
## when mounted (P3's "hoof", falling back to a stone step), else the ground's footstep.
static func stride(tree: SceneTree, m: GameMap, c: Vector2i, swimming := false, mounted := false) -> void:
	var mu := Music.instance(tree)
	if swimming:
		mu.step("water")
	elif mounted:
		mu.sfx("hoof", "step_stone")
	else:
		mu.step(word(m, c))
