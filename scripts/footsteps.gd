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


## Soft ground patches (seamless textures) -> step word.
static func seam_word(seam: String) -> String:
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
	if rd is Dictionary and (rd as Dictionary).has("ground"):
		var g := str((rd as Dictionary)["ground"])
		return str(GROUND.get(g, "stone" if ("asphalt" in g or "metal" in g or "concrete" in g or "brick" in g) else "grass"))
	if id == "neon":
		return "stone"
	if id == "wastes":
		return "gravel"
	return "grass"


static func word(m: GameMap, c: Vector2i, swimming := false) -> String:
	if m == null:
		return "grass"
	var id := m.scene_id()
	if FLOOR.has(id):
		return str(FLOOR[id])
	if GameState.look_se() == "winter" and m.has_sky:
		return "snow"
	if swimming or m.is_water_cell(c):
		return "water"
	if id in ["marsh", "bf_bog_crossing"]:
		return "mud"
	var gw := str(m.step_word.get(c, m.ground_word.get(c, "")))
	if gw != "":
		return gw
	if id == "farm" and not GameState.run.is_empty() and (GameState.run.get("farm", {}) as Dictionary).has("%d,%d" % [c.x, c.y]):
		return "dirt"  # tilled soil
	var base := base_word(m)
	if base == "grass" and GameState.look_se() == "fall" and id in ["forest", "orchard_hills", "meadow"]:
		return "leaves"
	return base
