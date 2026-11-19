extends GameMap
## Your plot of land, Sun Haven scale: a big open field with a crooked house,
## a mailbox, a shipping bin and nothing else. The rest is weeds, rocks, logs
## and trees to clear (progress is saved). Buildings and crafting stations are
## added later from the plans board. Farming works on any open grass cell.
## Exits: forest (north), meadow (east), town (south), lake (west).

const HOUSE := Rect2i(10, 6, 6, 5)
const DOOR := Vector2i(13, 10)
const MAILBOX := Vector2i(16, 10)
const SELLBOX := Vector2i(8, 10)
const PLANS := Vector2i(17, 13)  # outside the greenhouse plot Rect2i(17,7,9,6)
const CRYSTAL_SPOT := Vector2i(12, 14)
const POND_C := Vector2(48.0, 37.0)
const LEDGE_Y := 11
const LEDGE_X0 := 38
const STAIRS_X := 52
const TOWN_EXIT := Rect2i(34, 58, 4, 2)
const MEADOW_EXIT := Rect2i(70, 28, 2, 4)
const FOREST_EXIT := Rect2i(34, 0, 4, 2)
const LAKE_EXIT := Rect2i(0, 28, 2, 4)
## Animal pens (kept clear of debris; the barn pen stops short of the cliff at x38).
const COOP_PEN := Rect2i(26, 9, 6, 3)
const BARN_PEN := Rect2i(32, 6, 5, 3)
## The river: in from the west edge, under the footbridge (the house path's line)
## and the stone bridge (the town road), past the pond and out the east edge.
const RIVER_PTS := [Vector2(0, 40), Vector2(18, 45), Vector2(36, 48), Vector2(50, 52), Vector2(71, 45)]
const BRIDGE_X := [12, 35]   # left column of each 2-wide bridge deck
const RIVER_FISH := ["minnow", "trout", "carp", "catfish", "salmon", "eel"]
## Raised ground: the old terrace gets a second, higher tier; a knoll by the pond.
const UPPER_C := Vector2(62.0, 5.0)
const KNOLL_C := Vector2(63.5, 36.0)
## Buildable things: name -> {cell, w, h, cost, group, sprite, thing}
const BUILDS := {
	"workbench": {"cell": Vector2i(6, 13), "w": 1, "h": 1, "cost": {"wood": 20}, "group": "props", "sprite": "workbench3", "thing": "workbench", "label": "Workbench (20 wood)"},
	"chest": {"cell": Vector2i(9, 13), "w": 0, "h": 1, "cost": {"wood": 10}, "group": "props", "sprite": "chest_closed", "thing": "chest", "label": "Storage chest (10 wood)"},
	"furnace": {"cell": Vector2i(8, 13), "w": 0, "h": 1, "cost": {"stone": 20, "copper": 5}, "group": "props", "sprite": "furnace2_off", "thing": "furnace", "label": "Furnace (20 stone, 5 copper ore)"},
	"well": {"cell": Vector2i(19, 13), "w": 0, "h": 1, "cost": {"stone": 30}, "group": "props", "sprite": "well_roofed", "thing": "well", "label": "Well (30 stone)"},
	"keg": {"cell": Vector2i(6, 15), "w": 0, "h": 1, "cost": {"wood": 30, "copper_bar": 1}, "group": "props", "sprite": "keg2", "thing": "keg", "label": "Keg (30 wood, 1 copper bar)"},
	"beehive": {"cell": Vector2i(21, 15), "w": 0, "h": 1, "cost": {"wood": 15, "fiber": 10}, "group": "props", "sprite": "beehive3_a", "thing": "beehive", "label": "Beehive (15 wood, 10 fiber)"},
	"resonator": {"cell": Vector2i(16, 16), "w": 0, "h": 1, "cost": {"stone": 10, "shard": 1}, "group": "props", "sprite": "resonator", "thing": "resonator", "label": "Crystal resonator (10 stone, 1 shard)"},
	"scarecrow": {"cell": Vector2i(24, 14), "w": 0, "h": 1, "cost": {"wood": 8, "fiber": 4}, "group": "props", "sprite": "scarecrow_classic", "thing": "", "label": "Scarecrow (8 wood, 4 fiber)"},
	"coop": {"cell": Vector2i(26, 8), "w": 3, "h": 3, "cost": {"wood": 120, "stone": 40}, "group": "props", "sprite": "coop_small", "thing": "", "label": "Coop (120 wood, 40 stone) - chickens"},
	"barn": {"cell": Vector2i(32, 5), "w": 4, "h": 3, "cost": {"wood": 200, "stone": 80}, "group": "props", "sprite": "barn_small", "thing": "", "label": "Barn (200 wood, 80 stone) - cows & sheep"},
	"silo": {"cell": Vector2i(30, 4), "w": 1, "h": 3, "cost": {"stone": 60, "wood": 30}, "group": "props", "sprite": "silo2", "thing": "", "label": "Silo (60 stone, 30 wood)"},
	"fish_pond": {"cell": Vector2i(26, 16), "w": 2, "h": 2, "cost": {"stone": 80, "wood": 20}, "group": "props", "sprite": "fish_pond", "anim": "fish_pond", "thing": "water", "label": "Fish pond (80 stone, 20 wood) - fish at home"},
	"shed": {"cell": Vector2i(6, 20), "w": 2, "h": 2, "cost": {"wood": 80, "stone": 20}, "group": "props", "sprite": "shed", "thing": "chest", "label": "Shed (80 wood, 20 stone) - big storage"},
	"stable": {"cell": Vector2i(32, 11), "w": 3, "h": 3, "cost": {"wood": 150, "iron_bar": 2}, "group": "props", "sprite": "stable2", "thing": "", "label": "Stable (150 wood, 2 iron bars) - a horse, soon"},
	"mill": {"cell": Vector2i(26, 2), "w": 2, "h": 4, "cost": {"wood": 120, "stone": 60}, "group": "props", "sprite": "windmill3", "anim": "windmill3", "thing": "", "label": "Mill (120 wood, 60 stone)"},
	"greenhouse": {"cell": Vector2i(20, 4), "w": 3, "h": 3, "cost": {"wood": 150, "stone": 100, "iron_bar": 2}, "group": "props", "sprite": "greenhouse2", "anim": "greenhouse2", "thing": "", "label": "Greenhouse (150 wood, 100 stone, 2 iron bars)"},
}

var _pond_cells := {}
var _ledge_cells := {}
var _path_cells := {}
var _river := {}         # every river cell (the water under the bridges too)
var _bridge_cells := {}  # walkable deck cells over the river
var _stair_keep := {}    # plateau stairs and the cells around them: kept clear
var _crystal: Node2D
var _fishing := false
var _crystal_t := 0.0
var _rng := RandomNumberGenerator.new()


func scene_id() -> String:
	return "farm"


func default_spawn() -> Vector2:
	return cell_center(Vector2i(13, 13))


func build() -> void:
	cols = 72
	rows = 60
	pad = 6
	border = "trees"  # a forest ring all round (the old east rock band read as grey slabs)
	music_track = "farm"
	add_exit(TOWN_EXIT, "town", Vector2(40 * TILE, 3 * TILE), "down", "▼ town")
	add_exit(MEADOW_EXIT, "meadow", Vector2(2 * TILE, 10 * TILE), "right", "meadow ▶")
	add_exit(FOREST_EXIT, "forest", Vector2(36 * TILE, 46 * TILE + 8), "up", "▲ forest")
	add_exit(LAKE_EXIT, "lake", Vector2(55 * TILE, 22 * TILE + 8), "left", "◀ lake")
	block_rect(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y)
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go inside"})
	set_thing(MAILBOX.x, MAILBOX.y, {"type": "mailbox", "hint": "A: check mailbox"})
	set_thing(SELLBOX.x, SELLBOX.y, {"type": "sellbox", "hint": "A: shipping bin (sell what you hold)"})
	set_thing(PLANS.x, PLANS.y, {"type": "plans", "hint": "A: building plans"})
	for dx in [-1, 0, 1]:  # the board and its overhanging posts
		_clear_tile(PLANS + Vector2i(dx, 0))
		blocked[PLANS + Vector2i(dx, 0)] = true
	# Pond: an organic blob.
	_rng.seed = 404
	for y in range(int(POND_C.y) - 6, int(POND_C.y) + 7):
		for x in range(int(POND_C.x) - 8, int(POND_C.x) + 9):
			var d := Vector2((x - POND_C.x) / 7.0, (y - POND_C.y) / 4.5).length()
			if d + _rng.randf_range(-0.12, 0.12) < 1.0:
				_pond_cells[Vector2i(x, y)] = true
	# Pond cells need to be a solid shape with no 1-wide bits for the autotiler.
	for c: Vector2i in _pond_cells.keys():
		set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# Raised terrace in the north-east with a cliff ledge and stairs down.
	for x in range(LEDGE_X0, cols):
		var c := Vector2i(x, LEDGE_Y)
		if x == STAIRS_X or x == STAIRS_X + 1:
			continue
		_ledge_cells[c] = true
		blocked[c] = true
	for y in range(0, LEDGE_Y):
		var c := Vector2i(LEDGE_X0, y)
		if y < 3:
			continue
		_ledge_cells[c] = true
		blocked[c] = true
	# Paths (dirt): door to south exit, and the east-west track.
	# (the north track runs on x36: its soft edge would paint over the terrace's rock wall on x38)
	_path_cells = cells_of([Rect2i(13, 11, 1, 20), Rect2i(13, 30, 24, 2), Rect2i(35, 30, 2, 28), Rect2i(2, 29, 70, 2), Rect2i(36, 2, 1, 10), Rect2i(36, 12, 2, 18), TOWN_EXIT, MEADOW_EXIT, FOREST_EXIT, LAKE_EXIT])
	for c: Vector2i in _pond_cells:
		_path_cells.erase(c)
	_make_river()
	_make_heights()
	# Everything you've built so far.
	var builds: Dictionary = GameState.run.get("builds", {})
	for id: String in builds:
		var b: Dictionary = _build_rec(id)
		if b.is_empty():
			continue
		var c: Vector2i = b["cell"]
		block_rect(c.x, c.y - int(b["h"]) + 1, int(b["w"]) + 1, int(b["h"]))
		# Nothing grows under a building.
		for fy in range(c.y - int(b["h"]) + 1, c.y + 1):
			for fx2 in range(c.x, c.x + int(b["w"]) + 1):
				_clear_tile(Vector2i(fx2, fy))
		if str(b["thing"]) == "station":
			for fx3 in range(c.x, c.x + int(b["w"]) + 1):
				set_thing(fx3, c.y, {"type": "station", "station": id, "hint": "A: %s" % str(Builds.current_def(id).get("name", id))})
		elif str(b["thing"]) != "":
			var td := {"type": str(b["thing"]), "hint": {"coop": "A: coop (hold an egg: incubator)" if Builds.built_tier("coop") >= 2 else "A: coop", "silo": "A: silo (store / take hay)"}.get(id, "A: " + str(id))}
			if str(b["thing"]) == "chest":
				td["build"] = id
				td["hint"] = "A: open the %s" % ("shed" if id == "shed" else "chest")
			for fx4 in range(c.x, c.x + int(b["w"]) + 1):  # the whole front row, like stations
				set_thing(fx4, c.y, td.duplicate())
	# The Merkitty Pool: its merkitties swim by day and sing at night.
	if Sanctuary.on() and Builds.is_built("pool"):
		var pc: Array = Builds.data().get("pool", {}).get("cell", [5, 27])
		for i in mini(3, Builds.built_tier("pool")):
			var mk := CharacterLibrary.make_sprite("merkitty_" + "abc"[i])
			if mk:
				mk.position = cell_center(Vector2i(int(pc[0]), int(pc[1]))) + Vector2(-10 + i * 10, 4)
				mk.play("sing" if GameState.is_night() else "swim")
				mk.flip_h = i == 1
				add_child(mk)
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Star Crystal"})
	_place_debris()


func _river_y(x: float) -> float:
	var y: float = RIVER_PTS[0].y
	for i in RIVER_PTS.size() - 1:
		var a: Vector2 = RIVER_PTS[i]
		var b: Vector2 = RIVER_PTS[i + 1]
		if x <= b.x or i == RIVER_PTS.size() - 2:
			y = lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
			break
	return y + 2.2 * sin(x * 0.17 + 1.1) + 1.0 * sin(x * 0.41 + 0.3)


## The river's shape: a winding centre line with a width that breathes, run
## straight and narrow across each bridge. Deterministic, same on every visit.
func _make_river() -> void:
	var centre := func(x: float) -> float:
		var y := _river_y(x)
		for bx: int in BRIDGE_X:
			var d := absf(x - (bx + 1.0))
			if d < 4.0:
				var t := maxf(0.0, (d - 2.0) / 2.0)
				y = lerpf(_river_y(bx + 1.0), y, t)
		return y
	var keep_out := {}  # never under a building (built or not yet), the house, pens, the pond's bank or the track
	keep_out.merge(cells_of([HOUSE.grow(2), COOP_PEN.grow(1), BARN_PEN.grow(1), GameState.GREENHOUSE_PLOT.grow(1), Rect2i(0, 28, cols, 4)]))
	for bid: String in Builds.all():
		var bd: Dictionary = Builds.all()[bid]
		if bd.has("cell"):
			var bc := Vector2i(int(bd["cell"][0]), int(bd["cell"][1]))
			var bh := int(bd.get("h", 1))
			keep_out.merge(cells_of([Rect2i(bc.x - 1, bc.y - bh, int(bd.get("w", 0)) + 3, bh + 2)]))
	for pc: Vector2i in _pond_cells:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				keep_out[pc + Vector2i(dx, dy)] = true
	var cells := {}
	var x := -1.0
	while x < cols + 1.0:
		var y0: float = centre.call(x)
		var hw := 1.75 + 0.35 * sin(x * 0.29 + 2.0)
		for bx: int in BRIDGE_X:
			if absf(x - (bx + 1.0)) < 4.0:
				hw = minf(hw, 1.5)
		for cy in range(int(y0 - hw - 1.0), int(y0 + hw + 2.0)):
			for cx in range(int(x - hw - 1.0), int(x + hw + 2.0)):
				if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
					continue
				if Vector2(cx + 0.5 - x, cy + 0.5 - y0).length() <= hw:
					cells[Vector2i(cx, cy)] = true
		x += 0.25
	for c: Vector2i in cells.keys():
		if keep_out.has(c):
			cells.erase(c)
	_river = WorldGen.smooth_cells(cells)
	# Bridge decks: the two columns under each bridge are walkable planks/stone.
	for bx: int in BRIDGE_X:
		for c: Vector2i in _river:
			if c.x == bx or c.x == bx + 1:
				_bridge_cells[c] = true
	for c: Vector2i in _river:
		_path_cells.erase(c)
		if _bridge_cells.has(c):
			blocked.erase(c)
			continue
		set_thing(c.x, c.y, {"type": "water", "river": true, "hint": "A: fish" if GameState.has_tool("rod") else ""})
	# One body of water with the band: the river runs on out through the trees.
	border_water_extra = _river.duplicate()
	border_water_shore = "river"


## Old saves: a field, sprinkler or chest that now sits in the river (or on a new
## hill's rim, rock face or stairs). Crops give
## their seed back; placed things move to the nearest dry, free cell (a chest's
## contents go with it). Buildings never stand there (the river avoids them).
func _migrate_river() -> void:
	if Net.visiting():
		return  # the host's farm is the host's to migrate
	var farm: Dictionary = GameState.run["farm"]
	# New solid ground: the river, and the hills' rims and rock faces.
	var solid := _river.duplicate()
	for p: Dictionary in plateaus:
		for pc: Vector2i in p["cells"]:
			for c2: Vector2i in [pc, pc + Vector2i(0, 1)]:
				if blocked.has(c2):
					solid[c2] = true
		for st: Vector2i in p["stairs"]:
			solid[st] = true  # no soil or sprinkler on a flight of stairs
	for c: Vector2i in solid:
		if farm.has("%d,%d" % [c.x, c.y]):
			_clear_tile(c)  # a crop's seed comes back
	var placed: Dictionary = GameState.run.get("placed", {})
	for pk in placed.keys():
		var xy := str(pk).split(",")
		var pc := Vector2i(int(xy[0]), int(xy[1]))
		if not solid.has(pc):
			continue
		var to := Vector2i(-1, -1)
		for rad in range(1, 12):
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var n := pc + Vector2i(dx, dy)
					if to.x < 0 and in_content(n) and not solid.has(n) and not blocked.has(n) and not things.has(n) and not placed.has("%d,%d" % [n.x, n.y]) and not _path_cells.has(n) and str(farm.get("%d,%d" % [n.x, n.y], {}).get("crop", "")) == "":
						to = n
			if to.x >= 0:
				break
		if to.x < 0:
			continue
		var nk := "%d,%d" % [to.x, to.y]
		placed[nk] = placed[pk]
		placed.erase(pk)
		farm.erase(nk)  # (never a crop: the pick above skips planted cells)
		var chests: Dictionary = GameState.run.get("chests", {})
		if chests.has("p:" + str(pk)):
			chests["p:" + nk] = chests["p:" + str(pk)]
			chests.erase("p:" + str(pk))


## Tiered ground: a second, higher tier on the north-east terrace and a knoll
## by the pond, each with stairs on its south face.
func _make_heights() -> void:
	var up := WorldGen.mesa(self, UPPER_C, 6.5, 3.4, 611, 2)
	var room := {}
	for c: Vector2i in up:
		if c.x >= LEDGE_X0 + 3 and c.y <= LEDGE_Y - 3:
			room[c] = true  # its face and stairs land on the terrace top (y 9-10 stay open)
	up = WorldGen.smooth_cells(room)
	var up_ramps := [Vector2i(int(UPPER_C.x) - 1, 0), Vector2i(int(UPPER_C.x), 0)]
	_add_hill(up, up_ramps)
	var knoll := WorldGen.mesa(self, KNOLL_C, 5.0, 3.4, 612, 2)
	for c: Vector2i in knoll.keys():
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if _river.has(n) or _pond_cells.has(n) or _path_cells.has(n):
					knoll.erase(c)
	knoll = WorldGen.smooth_cells(knoll)
	_add_hill(knoll, [Vector2i(int(KNOLL_C.x) - 1, 0), Vector2i(int(KNOLL_C.x), 0)])
	_migrate_river()


## add_plateau with the stairs put on the lowest south-edge cells of the given
## columns (ramps' y is found here), and their landing kept clear of debris.
func _add_hill(cells: Dictionary, ramp_cols: Array) -> void:
	if cells.size() < 10:
		return
	var ramps: Array = []
	for rc: Vector2i in ramp_cols:
		var best := -1
		for c: Vector2i in cells:
			if c.x == rc.x and not cells.has(c + Vector2i(0, 1)):
				best = maxi(best, c.y)
		if best >= 0:
			ramps.append(Vector2i(rc.x, best))
	if ramps.size() != 2 or (ramps[0] as Vector2i).y != (ramps[1] as Vector2i).y:
		ramps = WorldGen.pick_ramps(self, cells)  # a stepped edge: the best flat pair
	add_plateau(cells, ramps)
	var p: Dictionary = plateaus[plateaus.size() - 1]
	for s: Vector2i in p["stairs"]:
		for dy in range(-2, 3):
			for dx in range(-1, 2):
				_stair_keep[s + Vector2i(dx, dy)] = true


## Nothing grows under a building or the plans board: a crop there gives its seed back.
func _clear_tile(c: Vector2i) -> void:
	var pk := "%d,%d" % [c.x, c.y]
	var pt = (GameState.run["farm"] as Dictionary).get(pk)
	if pt is Dictionary and str(pt.get("crop", "")) != "" and GameState.items.has(str(pt["crop"]) + "_seed") and not Net.visiting():  # a guest gets no seed for the host's crop
		GameState.add_item(str(pt["crop"]) + "_seed", 1)  # the seed back
	(GameState.run["farm"] as Dictionary).erase(pk)


## Weeds, rocks, logs, stumps and saplings all over the field, thicker away from
## the house. Deterministic from a seed; cleared cells are remembered in the save.
func _place_debris() -> void:
	var home := Vector2(DOOR)
	# Keep the fronts of built things clear (beehive, shed, keg, fish pond...).
	var keep_clear := {}
	for kc: Vector2i in cells_of([Rect2i(PLANS.x - 2, PLANS.y - 1, 5, 4)]):
		keep_clear[kc] = true  # the plans board stays in view
	keep_clear.merge(_stair_keep)  # every flight of stairs and its landing
	for kc: Vector2i in cells_of([Rect2i(STAIRS_X - 1, LEDGE_Y - 2, 4, 5)]):
		keep_clear[kc] = true  # the terrace stairs
	for bc: Vector2i in _bridge_cells:
		for dy in range(-2, 3):
			keep_clear[bc + Vector2i(0, dy)] = true  # both ends of each bridge
	for bid: String in GameState.run.get("builds", {}):
		var bb := _build_rec(bid)
		if not bb.is_empty():
			var bc: Vector2i = bb["cell"]
			var bai := Art.info(str(bb["group"]), str(bb["sprite"]))
			var up := maxi(int(bb["h"]), ceili(float(bai.get("cell_h", bai.get("h", 0))) * 0.5 / TILE))  # roofs and rockets reach above the footprint
			for kc: Vector2i in cells_of([Rect2i(bc.x - 1, bc.y - up + 1, int(bb["w"]) + 3, up + 2)]):  # same sides as the construction site, so nothing pops in when it's done
				keep_clear[kc] = true
	for cid: String in GameState.run.get("construction", {}):
		var cbd: Dictionary = Builds.all().get(cid, {})
		if cbd.has("cell"):
			var cc0 := Vector2i(int(cbd["cell"][0]), int(cbd["cell"][1]))
			var ch := int(cbd.get("h", 1))
			for kc: Vector2i in cells_of([Rect2i(cc0.x - 1, cc0.y - ch + 1, int(cbd.get("w", 0)) + 3, ch + 2)]):
				keep_clear[kc] = true  # the crew's site: footprint, sign and front
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			var c := Vector2i(x, y)
			_rng.seed = 77 + x * 7919 + y * 104729  # per cell: clearing or tilling one cell never reshuffles the rest
			if blocked.has(c) or things.has(c) or _path_cells.has(c) or _pond_cells.has(c) or _ledge_cells.has(c):
				continue
			if HOUSE.grow(2).has_point(c) or c.distance_to(CRYSTAL_SPOT) < 3 or keep_clear.has(c):
				continue
			if (Builds.is_built("coop") and COOP_PEN.grow_individual(0, 0, 0, 2).has_point(c)) or (Builds.is_built("barn") and BARN_PEN.has_point(c)) or (Builds.is_built("greenhouse") and GameState.GREENHOUSE_PLOT.has_point(c)):
				continue
			var near_pond := false
			for pc: Vector2i in _pond_cells:
				if pc.distance_to(c) < 2.0:
					near_pond = true
					break
			if near_pond:
				continue
			var dist := Vector2(c).distance_to(home)
			# Stardew/Sun Haven start: the farm is properly overrun. Thick near the
			# edges, a cleared ring round the house and the first plot by the door.
			var chance := clampf(0.12 + dist / 70.0 * 0.26, 0.12, 0.36)
			if dist < 9.0:
				chance = 0.03
			var r := _rng.randf()
			if r > chance:
				continue
			# Never on soil you've tilled.
			if GameState.run["farm"].has("%d,%d" % [c.x, c.y]):
				continue
			var k := _rng.randf()
			if dist < 9.0:
				k = k * 0.4  # by the house: only weeds, so the first plot is quick to clear
			if is_cleared(c, 14 if k < 0.40 else 0):
				continue  # weeds come back in two weeks; rocks, logs and trees you cleared stay gone
			if k < 0.40:
				things[c] = {"type": "weeds", "hint": "A: pull weeds"}
				blocked[c] = true
			elif k < 0.62:
				things[c] = {"type": "rock", "hp": 2, "hint": "A: break rock"}
				blocked[c] = true
			elif k < 0.76:
				things[c] = {"type": "log" if _rng.randf() < 0.6 else "stump", "hp": 2, "hint": "A: chop"}
				blocked[c] = true
			elif k < 0.94:
				things[c] = {"type": "tree", "hp": 5, "fell": true, "hint": "A: chop down"}
				blocked[c] = true
			else:
				var key := "bush_farm_%d_%d" % [c.x, c.y]
				var has := GameState.respawned(key, 3)  # every 3 days, like the wild bushes
				things[c] = {"type": "bush", "key": key, "berries": has, "hint": "A: pick berries" if has else ""}
				blocked[c] = true


## Chapter 1 partner scene: the characters you didn't pick turn up at the gate.
func _partner_scene() -> void:
	var cfg: Dictionary = Companion.data().get("partner_scene", {}).get(GameState.run["arc"], {})
	if cfg.is_empty():
		return
	var pid := str(GameState.run["playable"])
	var pool: Array = []
	if GameState.is_penguins():
		for c in ["penguin_m", "penguin_f"]:
			if c != pid:
				pool.append(c)
		if pid in ["penguin_m", "penguin_f"]:
			for c in ["dad", "mom", "pax", "kairi"]:
				if c != pid:
					pool.append(c)
					break
	else:
		for c in ["big_jim", "sal"]:
			if c != pid:
				pool.append(c)
		for c in ["dad", "mom", "pax", "kairi"]:
			if c != pid and pool.size() < 3:
				pool.append(c)
	player.frozen = true
	# A line can be for everyone but one hero ("not_hero"), or only one ("only_hero"):
	# you don't hear yourself ask to stay.
	var ls: Array = []
	for l in cfg.get("lines", []):
		if str(l.get("not_hero", "")) == pid or (l.has("only_hero") and str(l["only_hero"]) != pid):
			continue
		ls.append(l)
	await say(ls)
	var d := Dialogue.instance(get_tree())
	var ch: Array = []
	for c in pool:
		var cd: Dictionary = Companion.defs()[c]
		ch.append("%s — %s" % [str(cd["name"]), str(cd["ability_name"])])
	ch.append("Nobody, for now")
	d.say([{"who": "", "text": str(cfg.get("ask", "Who comes with you?")), "choice": ch, "key": "partner"}])
	await d.finished
	if d.last_choice >= 0 and d.last_choice < pool.size():
		var cid: String = pool[d.last_choice]
		Companion.recruit(cid)
		for other in pool:
			if other != cid:
				Companion.party()["refused"][other] = int(Companion.party()["refused"].get(other, 0)) + 1
		await say([{"who": str(Companion.defs()[cid]["name"]), "text": str(Companion.defs()[cid]["join"])}, {"text": "%s joined your party. Tap the ♥ button to use %s. Change partners in the menu (Party)." % [str(Companion.defs()[cid]["name"]), str(Companion.defs()[cid]["ability_name"])]}])
		GameState.add_hint("Partners: tap ♥ to use %s's %s. Others who asked may take it badly if you keep saying no." % [str(Companion.defs()[cid]["name"]), str(Companion.defs()[cid]["ability_name"])])
	else:
		for other in pool:
			Companion.refuse(other)
		await say([{"text": "They look at each other. They go. The gate is quieter than before."}])
	player.frozen = false


func after_ready() -> void:
	_make_soil()
	for pk in GameState.run.get("placed", {}):
		var xy := str(pk).split(",")
		_show_placed(Vector2i(int(xy[0]), int(xy[1])), str(GameState.run["placed"][pk]))
	if int(GameState.run["day"]) >= 3 and not GameState.run["flags"].has("partner_scene") and bool(GameState.run["intro_done"]):
		GameState.run["flags"]["partner_scene"] = true
		_partner_scene.call_deferred()
	WorldGen.add_backdrop(self, "hills")
	_place_props()
	WorldGen.dress_band(self, 5150)
	WorldGen.clear_stairs.call_deferred(self)
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		_make_crystal()
	if not bool(GameState.run["intro_done"]):
		_intro.call_deferred()


func _make_crystal() -> void:
	_crystal = Node2D.new()
	_crystal.position = cell_center(CRYSTAL_SPOT)
	_crystal.draw.connect(func() -> void:
		var c := _crystal
		var glow := 0.5 + 0.5 * sin(_crystal_t * 2.0)
		c.draw_circle(Vector2(0, -8), 11.0 + glow * 2.0, Color(0.6, 0.85, 1.0, 0.18))
		var pts := PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, 2), Vector2(-5, -10)])
		c.draw_colored_polygon(pts, Color(0.75, 0.9, 1.0))
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, -8)]), Color(1, 1, 1, 0.8))
		c.draw_circle(Vector2(0, 1), 5.0, Color(0, 0, 0, 0.2)))
	add_child(_crystal)


func _process(delta: float) -> void:
	super(delta)
	if _crystal:
		_crystal_t += delta
		_crystal.position.y = cell_center(CRYSTAL_SPOT).y - 3.0 - sin(_crystal_t * 1.5) * 2.0
		if int(_crystal_t * 10.0) != int((_crystal_t - delta) * 10.0):
			_crystal.queue_redraw()  # the glow pulse at 10 Hz; the bob is a position change


# ---- interaction -------------------------------------------------------------

func interact(c: Vector2i, thing: Dictionary) -> bool:
	var sel := str(GameState.run["selected"])
	match str(thing.get("type", "")):
		"door":
			go_to("house", Vector2(8 * TILE + 8, 10 * TILE), "up")
			return true
		"mailbox":
			_mailbox()
			return true
		"sellbox":
			_sellbox(sel)
			return true
		"water":
			if GameState.held_tool() == "rod" and not _fishing:
				# The farm pond uses the same fishing as everywhere else.
				later(_pond_fish.bind(c, bool(thing.get("river", false))))
			elif GameState.has_tool("rod"):
				hud.toast("Hold the fishing rod.")
			return true
		"well":
			if int(GameState.run["energy"]) >= int(GameState.run["max_energy"]):
				hud.toast("You're not thirsty.")  # keep today's drink for later
			elif int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2:
				hud.toast("You've rested plenty today.")  # the half bar is used up: keep today's drink
			elif int(GameState.run["flags"].get("well_day", 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["well_day"] = int(GameState.run["day"])
				var got := GameState.rest_energy(20)
				hud.toast("Cold water. +%d energy." % got if got > 0 else "Cold water. You've rested plenty today.")
			else:
				hud.toast("You already drank today.")
			return true
		"crystal":
			_talk_crystal()
			return true
		"station":
			later(_station.bind(str(thing.get("station", ""))))
			return true
		"workbench":
			_workbench()
			return true
		"furnace":
			_furnace()
			return true
		"chest":
			if Net.visiting() and not GameState.run.get("chests", {}).has(str(thing.get("build", "chest"))):
				hud.toast("The host's chest. Build your own on your farm.")
				return true
			later(ChestScreen.open.bind(self, str(thing.get("build", "chest")), "Shed" if str(thing.get("build", "")) == "shed" else "Chest"))
			return true
		"beehive":
			_daily_pickup("beehive", "honey", "The bees are still working.")
			return true
		"keg":
			_keg(sel)
			return true
		"resonator":
			_resonator(sel)
			return true
		"silo":
			_silo(sel)
			return true
		"coop":
			_coop(sel)
			return true
		"barn":
			hud.toast("The animals live out in the pen: hold hay and tap them, pet them daily for milk and wool.%s" % (" The Big Barn feeds them from the silo." if Builds.built_tier("barn") >= 2 else ""))
			return true
		"greenhouse":
			hud.toast("Plant in the stone-bordered plot in front: crops there grow in any season.")
			return true
		"plans":
			_plans()
			return true
		"placed":
			if Net.visiting():
				hud.toast("That's the host's. Your own things stay on your farm.")
				return true
			if str(thing.get("kind", "")) == "chest":
				later(ChestScreen.open.bind(self, "p:%d,%d" % [c.x, c.y], "Chest"))
				return true
			# Hold-to-repeat with a field tool must never pull a sprinkler out of the row.
			if GameState.held_tool() in ["hoe", "can", "axe", "pickaxe", "scythe"]:
				hud.toast("Put the tool away to pick it up.")
				return true
			pickup_placed(c)
			return true
		"":
			var guest := Net.visiting()
			if str(GameState.items.get(sel, {}).get("type", "")) == "placeable" and GameState.count(sel) > 0 and not guest and can_till(c) and str(GameState.run["farm"].get("%d,%d" % [c.x, c.y], {}).get("crop", "")) == "":
				(GameState.run["farm"] as Dictionary).erase("%d,%d" % [c.x, c.y])  # an empty bed tile: the sprinkler goes in it
				if _soil:
					_soil.queue_redraw()
				else:
					queue_redraw()
				_place_item(c, sel)
				return true
			if str(GameState.items.get(sel, {}).get("type", "")) == "placeable" and GameState.count(sel) > 0 and not guest and GameState.run["farm"].has("%d,%d" % [c.x, c.y]):
				hud.toast("Not on a growing crop. Put it on open ground or empty soil.")
				return true
			# Open grass in front of you: farm it (hoe / seeds / water / harvest).
			if _tillable(c) and _farm_tile(c, sel):
				return true
	# Nothing in front of you: eat/drink what you hold. Anything else (animals,
	# weeds, rocks, trees...) goes on to interact_common instead of eating.
	return thing.is_empty() and not blocked.has(c) and use_consumable(sel)  # no eating when you face a wall


## Any free grass cell inside the field can be tilled, Stardew-style.
func can_till(c: Vector2i) -> bool:
	return _tillable(c) and not things.has(c) and not blocked.has(c)


## BUILDS-shaped record for what's actually built (tier-aware), from buildings.json.
func _build_rec(id: String) -> Dictionary:
	var bd: Dictionary = Builds.all().get(id, {})  # co-op: the host may be on the other story
	if bd.is_empty() or id == "house":
		return {}
	var td := Builds.current_def(id)
	if td.is_empty():
		return {}
	var rec := {"cell": Vector2i(int(bd["cell"][0]), int(bd["cell"][1])), "w": int(bd.get("w", 0)), "h": int(bd.get("h", 1)), "group": str(td.get("group", bd.get("group", "props"))), "sprite": str(td.get("sprite", "")), "thing": str(bd.get("thing", {"coop": "coop", "silo": "silo", "barn": "barn", "greenhouse": "greenhouse"}.get(id, ""))), "label": str(bd.get("label", id))}
	if bd.has("anim"):
		rec["anim"] = str(bd["anim"])
	if not Builds.data().has(id):
		rec["thing"] = ""  # the other story's building: solid and drawn, not ours to use
	return rec


func _tillable(c: Vector2i) -> bool:
	if not in_content(c) or blocked.has(c) or _path_cells.has(c) or _pond_cells.has(c) or _ledge_cells.has(c) or _river.has(c) or _stair_keep.has(c):
		return false
	if c.y <= LEDGE_Y and c.x >= LEDGE_X0:
		return false  # the terrace is for later
	for e in exits:
		if (e["rect"] as Rect2i).has_point(c):
			return false
	return true


func _plans() -> void:
	# The plans board. Everything on the farm is made from materials or bought
	# ready-made, tier by tier; each tier has its own gate (story, skill, friend).
	const CATS := [["farm", "Farm buildings"], ["workshop", "Workshop stations"], ["pantry", "Kitchen & cellar"], ["projects", "Big projects (vehicles, rocket)"], ["operation", "The operation"], ["sanctuary", "The sanctuary"]]
	var d := Dialogue.instance(get_tree())
	while true:
		var copts: Array = []
		var cids: Array = []
		for pair in CATS:
			var n := 0
			var have := 0
			for id: String in Builds.data():
				if str(Builds.data()[id].get("cat", "farm")) == str(pair[0]):
					n += 1
					have += 1 if Builds.is_built(id) else 0
			if n > 0:
				copts.append("%s  (%d of %d built)" % [str(pair[1]), have, n])
				cids.append(str(pair[0]))
		copts.append("Leave")
		d.say([{"who": "Plans", "text": "Build it from materials, or buy it ready-made. Each tier opens as your story, skills and friendships grow.", "choice": copts, "key": ""}])
		await d.finished
		if d.last_choice < 0 or d.last_choice >= cids.size():
			return
		var cat := str(cids[d.last_choice])
		var ids: Array = []
		var opts: Array = []
		for id: String in Builds.data():
			if str(Builds.data()[id].get("cat", "farm")) != cat:
				continue
			var bt := Builds.built_tier(id)
			var nd := Builds.next_def(id)
			var uc := Builds.under_construction(id)
			var label := str(Builds.data()[id]["label"])
			if not uc.is_empty():
				var dl := int(uc["done_day"]) - int(GameState.run["day"])
				opts.append("⌛ %s → %s (%d day%s left)" % [label, str(Builds.tier_def(id, int(uc["tier"]))["name"]), dl, "" if dl == 1 else "s"])
				ids.append("")
				continue
			if nd.is_empty():
				opts.append("✓ %s (%s, max)" % [label, str(Builds.current_def(id).get("name", ""))])
				ids.append("")
				continue
			var g := Builds.gate(id)
			var why := Builds.blocker(id)
			var mark := "" if why == "" else ("🔒 " if g != "" else "✗ ")
			var tag := ""
			if g == "permit":
				tag = "  [permit ◆%d at Town Hall]" % Builds.permit_price(id)
			elif g != "":
				tag = "  [%s]" % g
			opts.append("%s%s%s%s" % [mark, ("%s → " % str(Builds.current_def(id).get("name", label))) if bt > 0 else "", str(nd["name"]), tag])
			ids.append(id)
		opts.append("← Back")
		d.say([{"who": "Plans", "text": "🔒 = not open yet · ✗ = missing materials (you can still buy it)", "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= ids.size() or str(ids[i]) == "":
			continue
		var id := str(ids[i])
		var nd2 := Builds.next_def(id)
		var parts: Array = []
		for need in nd2.get("cost", {}):
			var c2 := Builds.cost_of(nd2)
			parts.append("%d/%d %s" % [mini(Builds._bag_free(str(need)) + Storage.total(str(need)), int(c2[need])), int(c2[need]), GameState.item_name(str(need))])
		var g2 := Builds.gate(id)
		var text := "%s: %s" % [str(nd2["name"]), str(nd2.get("desc", ""))]
		if int(nd2.get("days", 0)) > 0:
			var dd := maxi(0, int(nd2.get("days", 0)) - int(GameState.bonus("building", "quick_build")))
			text += ("\nTakes %d day%s." % [dd, "" if dd == 1 else "s"]) if dd > 0 else "\nReady at once (Quick Build)."
		var ch: Array = []
		var acts: Array = []
		if g2 != "":
			text += "\nNot yet: %s." % ("buy the permit from Alder (◆%d)" % Builds.permit_price(id) if g2 == "permit" else g2)
		else:
			ch.append("Build from materials  [%s]" % ", ".join(parts))
			acts.append("build")
			if Builds.price(id) > 0:
				ch.append("Buy ready-made from %s  [◆%d]" % [str(Builds.data()[id].get("seller", "Hazel")), Builds.price(id)])
				acts.append("buy")
		ch.append("← Back")
		d.say([{"who": "Plans", "text": text, "choice": ch, "key": ""}])
		await d.finished
		if d.last_choice < 0 or d.last_choice >= acts.size():
			continue
		var buy := str(acts[d.last_choice]) == "buy"
		if Net.visiting():
			# On someone else's farm the host decides (and pays).
			if not Net.online():
				hud.toast("Reconnecting to your host... try again in a moment.", Color(0.9, 0.95, 1.0))
				return
			net_act({"a": "build", "id": id})
			hud.toast("Asked the host to build it.", Color(0.9, 0.95, 1.0))
			return
		var msg := Builds.start(id, buy)
		var ok := not msg.begins_with("Can't")
		if not ok:
			hud.toast(msg, Color(1, 0.7, 0.7))
			continue
		# The scene reloads below (a new HUD): a note survives it and is announced after.
		GameState.notify(msg)
		Music.instance(get_tree()).sfx("craft_done", "levelup")
		GameState.save()
		# Simplest reliable refresh: reload the scene in place.
		GameMap.next_spawn = player.position - offset()
		GameMap.next_facing = player.facing
		get_tree().reload_current_scene()
		return


func _farm_tile(c: Vector2i, sel: String) -> bool:
	var key := "%d,%d" % [c.x, c.y]
	var farm: Dictionary = GameState.run["farm"]
	var tile: Dictionary = farm.get(key, {})
	if tile.is_empty():
		if GameState.held_tool() != "hoe":
			return false
		if not GameState.spend_for("hoe"):
			hud.toast("Too tired.", Color(1, 0.7, 0.7))
			return true
		farm[key] = {"watered": false, "crop": "", "days": 0}
		net_act({"a": "farm_tile", "key": key, "tile": farm[key]})
		player.play_tool("hoe")
		Music.instance(get_tree()).sfx("dig")
		xp("farming", 1)
		_soil.queue_redraw() if _soil else queue_redraw()
		return true
	var crop := str(tile.get("crop", ""))
	var ripe := crop != "" and GameState.crops.has(crop) and int(tile.get("days", 0)) >= int(GameState.crops[crop]["days"])
	if sel == "fertilizer" and GameState.count(sel) > 0 and GameState.held_tool() == "" and not ripe:
		if bool(tile.get("fert", false)):
			hud.toast("Already fertilised.")
			return true
		tile["fert"] = true
		GameState.add_item(sel, -1)
		net_act({"a": "farm_tile", "key": key, "tile": tile})
		player.play_tool("hold")
		Music.instance(get_tree()).sfx("plant")
		hud.toast("Fertilised: grows half again as fast.", Color(0.7, 1, 0.7))
		_soil.queue_redraw() if _soil else queue_redraw()
		return true
	if crop == "":
		var it: Dictionary = GameState.items.get(sel, {})
		if it.get("type", "") == "seed" and GameState.count(sel) > 0 and not GameState.crops.has(str(it.get("crop", ""))):
			hud.toast("%s won't take in this soil." % GameState.item_name(sel), Color(1, 0.8, 0.6))
			return true
		if it.get("type", "") == "seed" and GameState.count(sel) > 0:
			var pcd: Dictionary = GameState.crops[str(it["crop"])]
			var se := GameState.season()
			if not GameState.crop_fits_season(pcd, se) and not GameState.in_greenhouse(key) and not bool(pcd.get("tree", false)):
				var cs: Variant = pcd.get("season", "any")
				hud.toast("%s is a %s crop. It won't grow in %s%s." % [GameState.item_name(str(pcd.get("yield", it["crop"]))), " or ".join(cs) if cs is Array else str(cs), se, " (try the greenhouse plot)" if Builds.is_built("greenhouse") else ""], Color(1, 0.8, 0.6))
				Music.instance(get_tree()).sfx("nope")
				return true
			# It grows on the nights from today to day 27; it dies at the season's turn.
			var left := GameState.DAYS_PER_SEASON - GameState.day_of_season()
			if bool(pcd.get("tree", false)) and not GameState.crop_fits_season(pcd, se):
				hud.toast("Fruit trees only grow in their season: this one sleeps until then.", Color(1, 0.9, 0.6))
			elif not bool(pcd.get("tree", false)) and str(pcd.get("season", "any")) != "any" and int(pcd["days"]) > left and not GameState.in_greenhouse(key):
				hud.toast("Careful: it needs %d days and only %d are left this season." % [int(pcd["days"]), left], Color(1, 0.9, 0.6))
			if not GameState.spend_for("plant"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			tile["crop"] = str(it["crop"])
			tile["days"] = 0
			net_act({"a": "farm_tile", "key": key, "tile": tile})
			GameState.add_item(sel, -1)
			player.play_tool("hoe")
			Music.instance(get_tree()).sfx("plant")
			fx("sprout_pop", cell_center(c), 8.0, 0.5)
			xp("farming", 2)
			_soil.queue_redraw() if _soil else queue_redraw()
			return true
		if not bool(tile.get("watered", false)) and not GameState.sky_waters() and GameState.held_tool() == "can":
			return _water(tile, key)
		if GameState.held_tool() == "hoe":
			# Hold-to-repeat tills rows over soil that's already done: say it once, then stay quiet.
			if not GameState.run["flags"].has("told_tilled"):
				GameState.run["flags"]["told_tilled"] = true
				hud.toast("Already tilled. Pick seeds on the toolbar and USE here to plant.")
			return true
		if GameState.held_tool() == "can":
			hud.toast("%s Pick seeds on the toolbar to plant." % (("The %s has the soil wet." % ("snow" if GameState.weather_today() in ["snow", "blizzard"] else "rain")) if GameState.sky_waters() else "Watered."))
			return true
		if _hand_item(sel):
			return false  # a tonic in hand: it goes on to be used
		hud.toast("Pick seeds on your toolbar to plant here.")
		return true
	var cd: Dictionary = GameState.crops[crop]
	if int(tile["days"]) >= int(cd["days"]):
		var n := 1 + (1 if randf() < 0.03 * GameState.skill_level("farming") + GameState.bonus("farming", "extra_crop") else 0)
		if randf() < GameState.bonus("farming", "double_harvest"):
			n *= 2
		if randf() < GameState.bonus("farming", "star_chance"):
			n += 2
			hud.toast("★ Star-quality harvest!", Color(1, 0.95, 0.5))
		pop_items(cell_center(c), str(cd["yield"]), n)  # the crop hops out to you
		if str(cd["yield"]) == "wheat" and not Net.visiting():
			Builds.silo_add(1)  # chaff goes to the silo
		# Quality: farming skill and fertiliser raise the odds of silver and gold.
		var flv := GameState.skill_level("farming")
		var fert := bool(tile.get("fert", false))
		var qr := randf()
		var gold_p := 0.015 * flv + (0.10 if fert else 0.0) + GameState.bonus("farming", "star_chance")
		var silver_p := gold_p + 0.05 * flv + (0.20 if fert else 0.0)
		if qr < gold_p:
			GameState.add_quality(str(cd["yield"]), "g", n)
			hud.toast("★ Gold-star %s! Sells for half again as much." % GameState.item_name(str(cd["yield"])), Color(1, 0.85, 0.3))
			Music.instance(get_tree()).sfx("crit", "coin")
			fx("sparkle", cell_center(c) + Vector2(0, -10), 14.0, 0.6)
		elif qr < silver_p:
			GameState.add_quality(str(cd["yield"]), "s", n)
			hud.toast("☆ Silver-star %s: sells for a quarter more." % GameState.item_name(str(cd["yield"])), Color(0.85, 0.9, 1.0))
		if GameState.log_grown(crop):
			hud.toast("Field log: first %s! (%d of %d crops grown)" % [str(cd["name"]), (GameState.run["grown"] as Dictionary).size(), GameState.crops.size()], Color(0.8, 1, 0.7))
		if randf() < GameState.bonus("farming", "seed_back"):
			var seed_id := _seed_for(crop)
			if seed_id != "":
				give(seed_id, 1)
		player.play_tool("hold")
		Music.instance(get_tree()).sfx("harvest", "pickup")
		xp("farming", 4 + 2 * int(cd.get("tier", 1)))
		if cd.has("regrow"):
			# Bushes and vines keep producing: back to a few days before ripe.
			tile["days"] = int(cd["days"]) - int(cd["regrow"])
			var rk := "regrow_told_" + crop
			if not GameState.run["flags"].has(rk):  # say it once per crop, not every pick
				GameState.run["flags"][rk] = true
				hud.toast("%s will fruit again in %d days." % [str(cd["name"]), int(cd["regrow"])])
		else:
			tile["crop"] = ""
			tile["days"] = 0
			tile.erase("fert")
		net_act({"a": "farm_tile", "key": key, "tile": tile})
		_check_first_harvest()
		_soil.queue_redraw() if _soil else queue_redraw()
		return true
	var left := int(cd["days"]) - int(tile["days"])
	var thirsty := not bool(tile.get("watered", false)) and not GameState.sky_waters()
	if thirsty and GameState.held_tool() == "can":
		return _water(tile, key)
	if _hand_item(sel):
		return false  # a growth tonic in hand: use it, don't read the crop
	toast_growth(tile, cd, left, thirsty)
	return true


## A tonic in hand (growth potion, forged papers...): USE uses it even facing the
## field. Plain food doesn't: tapping a crop with a snack in hand reads the crop
## instead of eating (eat facing grass or anywhere off the beds).
func _hand_item(sel: String) -> bool:
	if sel == "" or GameState.held_tool() != "" or GameState.count(sel) <= 0 or sel == "fertilizer":
		return false
	var it: Dictionary = GameState.items.get(sel, {})
	return str(it.get("effect", "")) != "" or str(it.get("type", "")) == "vehicle"


## The growth text for a crop that isn't ripe: days left, and whether it's had
## its water today (a crop only grows on nights it was watered).
func toast_growth(tile: Dictionary, cd: Dictionary, left: int, thirsty: bool) -> void:
	var nm := str(cd["name"])
	var days := "%d more day%s" % [left, "" if left == 1 else "s"]
	if thirsty:
		hud.toast("%s: %s. Thirsty: water it with the can or it won't grow tonight." % [nm, days], Color(1, 0.9, 0.7))
	elif GameState.sky_waters():
		hud.toast("%s: %s. The %s is watering it today." % [nm, days, "snow" if GameState.weather_today() in ["snow", "blizzard"] else "rain"])
	elif bool(tile.get("fert", false)):
		hud.toast("%s: %s. Watered and fertilised." % [nm, days])
	else:
		hud.toast("%s: %s. Watered today." % [nm, days])


func _seed_for(crop: String) -> String:
	if GameState.items.has(crop + "_seed"):
		return crop + "_seed"
	for id in GameState.items:
		var it: Dictionary = GameState.items[id]
		if str(it.get("type", "")) == "seed" and str(it.get("crop", "")) == crop:
			return str(id)
	return ""


func _water(tile: Dictionary, key := "") -> bool:
	if GameState.held_tool() != "can":
		if GameState.has_tool("can") and str(GameState.run["selected"]) == "":
			hud.toast("Hold the watering can.")
		return false
	if not GameState.spend_for("can"):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return true
	tile["watered"] = true
	if key != "":
		net_act({"a": "farm_tile", "key": key, "tile": tile})
	# Wide Spout (Farming): the pour also soaks the tilled tiles either side (no extra energy).
	if key != "" and GameState.bonus("farming", "wide_water") > 0:
		var kp := key.split(",")
		var tc := Vector2i(int(kp[0]), int(kp[1]))
		var d := tc - player.cell()
		d = Vector2i(signi(d.x), signi(d.y))
		if d == Vector2i.ZERO or (d.x != 0 and d.y != 0):
			d = Vector2i(player.facing_dir())
		var side := Vector2i(d.y, d.x)
		for s: int in [-1, 1]:
			var k2 := "%d,%d" % [tc.x + side.x * s, tc.y + side.y * s]
			var t2: Dictionary = GameState.run["farm"].get(k2, {})
			if not t2.is_empty() and not bool(t2.get("watered", false)):
				t2["watered"] = true
				net_act({"a": "farm_tile", "key": k2, "tile": t2})
	player.play_tool("water")
	Music.instance(get_tree()).sfx("water")
	_soil.queue_redraw() if _soil else queue_redraw()
	return true


## Crops with no painted sheet yet: a drawn plant that grows (a trunk and canopy
## for trees), showing the produce's own icon when it's ready to pick.
func _draw_plain_crop(c: Vector2i, cd: Dictionary, frac: float, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	var cx := c.x * TILE + TILE / 2.0
	var base := (c.y + 1) * TILE - 2.0
	var leaf := Color(str(cd.get("color", "4f9a3a")))
	var top := Color(str(cd.get("top", "e8c84a")))
	if bool(cd.get("tree", false)):
		var th := 2.0 + frac * 8.0
		ci.draw_rect(Rect2(cx - 1, base - th, 2, th), Color("6a4a2a"))
		var r := 2.0 + frac * 4.5
		ci.draw_circle(Vector2(cx, base - th - r * 0.6), r, Color("3f8a3a"))
		ci.draw_circle(Vector2(cx - r * 0.5, base - th - r * 0.3), r * 0.7, Color("4f9a3a"))
		if frac >= 1.0:
			for p: Vector2 in [Vector2(-2.5, -1), Vector2(2, -3), Vector2(0.5, 1.5)]:
				ci.draw_circle(Vector2(cx, base - th - r * 0.6) + p, 1.4, top)
	else:
		var hgt := 2.0 + frac * 9.0
		ci.draw_rect(Rect2(cx - 0.5, base - hgt, 1.5, hgt), leaf.darkened(0.15))
		var leaves := 1 + int(frac * 3.0)
		for i in leaves:
			var y := base - 2.0 - i * (hgt / float(leaves + 1))
			var sgn := -1.0 if i % 2 == 0 else 1.0
			ci.draw_circle(Vector2(cx + sgn * 2.2, y), 1.6 + frac, leaf)
		if frac >= 0.75 and frac < 1.0:
			ci.draw_circle(Vector2(cx, base - hgt - 0.5), 1.5, top.darkened(0.3))
	if frac >= 1.0:
		var y := str(cd.get("yield", ""))
		var icon := Hud.icon_for(y)
		if Art.has("items", icon) and icon != "seeds":
			var t := Art.tex("items", icon)
			ci.draw_texture_rect(t, Rect2(cx - 5, base - 17, 10, 10), false)
		elif not bool(cd.get("tree", false)):
			ci.draw_circle(Vector2(cx, base - 12.0), 3.0, top)
			ci.draw_circle(Vector2(cx - 1, base - 13.0), 1.0, top.lightened(0.4))


func _check_first_harvest() -> void:
	if GameState.complete_quest("first_harvest"):
		hud.toast(GameMap.quest_done_text("first_harvest"), Color(1, 0.9, 0.4))


func _sellbox(sel: String) -> void:
	var box: Dictionary = GameState.run["sellbox"]
	var stype := str(GameState.items.get(sel, {}).get("type", ""))
	if sel != "" and GameState.count(sel) > 0 and stype in ["key", "vehicle"]:
		hud.toast("You can't sell the %s. It matters." % GameState.item_name(sel), Color(1, 0.85, 0.6))
		return
	if sel != "" and GameState.is_locked(sel):
		hud.toast("Your %s is locked in your bag. Unlock it to sell it." % GameState.item_name(sel), Color(1, 0.85, 0.6))
		return
	if sel != "" and GameState.count(sel) > 0 and stype != "tool":
		var n := GameState.count(sel)
		var prev := int(box.get(sel, 0))
		box[sel] = prev + n
		var tq := GameState.take_quality(sel, n)
		if int(tq["g"]) + int(tq["s"]) > 0:
			if not GameState.run.has("sellbox_q"):
				GameState.run["sellbox_q"] = {}
			var bq: Dictionary = GameState.run["sellbox_q"].get(sel, {})
			bq["g"] = int(bq.get("g", 0)) + int(tq["g"])
			bq["s"] = int(bq.get("s", 0)) + int(tq["s"])
			GameState.run["sellbox_q"][sel] = bq
		GameState.add_item(sel, -n)
		net_act({"a": "sellbox", "id": sel, "n": n})
		var est := GameState.sell_price(sel, prev + n) - GameState.sell_price(sel, prev) + GameState.quality_bonus_value({sel: tq})
		hud.toast("Put %s x%d in the sell box (about ◆%d tonight%s)." % [GameState.item_name(sel), n, est, ", in demand" if GameState.demand(sel) > 1.1 else ""])
		Music.instance(get_tree()).sfx("coin", "pickup")
		return
	if box.is_empty():
		await say([{"text": "The sell box is empty. Pick an item on the toolbar and tap USE here to sell it. You get paid in crystals overnight."}])
	else:
		var total := GameState.quality_bonus_value(GameState.run.get("sellbox_q", {}))
		for id in box:
			total += GameState.sell_price(id, int(box[id]))
		var txt := "In the box: %s. Worth ◆%d, paid tonight." % [", ".join(box.keys().map(func(k: String) -> String: return "%s x%d" % [GameState.item_name(k), int(box[k])])), total]
		if Net.visiting():
			await say([{"text": txt}])
			return
		# Changed your mind? Everything comes back out before the night's pickup.
		var dl := Dialogue.instance(get_tree())
		dl.say([{"text": txt, "choice": ["Leave it", "Take it all back"], "key": ""}])
		await dl.finished
		if dl.last_choice != 1:
			return
		var bq: Dictionary = GameState.run.get("sellbox_q", {})
		for id: String in box.keys():
			GameState.add_item(id, int(box[id]))
			var q: Dictionary = bq.get(id, {})
			for k in ["g", "s"]:
				if int(q.get(k, 0)) > 0:
					GameState.add_quality(id, k, int(q[k]))
		GameState.run["sellbox"] = {}
		GameState.run["sellbox_q"] = {}
		hud.toast("Took everything back out of the sell box.", Color(0.8, 1, 0.8))


func _mailbox() -> void:
	var flags: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	if GameState.is_penguins():
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "Welcome to %s! Here are a few strawberry seeds to start you off: they fruit again every few days once they're up. Stop by the general store when you can. - Maple" % GameState.names()["town"]},
			])
			give("strawberry_seed", 3)
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "Dear neighbor, something has been howling from the east meadow at night. Mayor Alder says it's nothing. It is not nothing. - Wren"}])
			GameState.add_quest("clear_meadow", "Find out what's howling in the east meadow.")
			return
	else:
		if not flags.has("mail_1"):
			flags["mail_1"] = true
			await say([
				{"who": "Letter", "text": "The plot is yours under the name on the deed. Nobody here knows your real one. Keep it that way. Earn your keep and don't draw eyes. - M."},
				{"text": "Folded inside: a twist of potato seeds and a note. \"Spring dirt. Plant them, water them, sell them. A farmer is the last thing anyone looks at.\""},
			])
			give("potato_seed", 3)
			return
		if day >= 3 and not flags.has("mail_2"):
			flags["mail_2"] = true
			await say([{"who": "Letter", "text": "A man came through town asking about a face like yours. He went east, toward the meadow. Be careful. - M."}])
			GameState.add_quest("clear_meadow", "Someone is asking about you. Check the east meadow.")
			return
	await read_mail()


func _talk_crystal() -> void:
	var r := GameState.run
	var d: Dictionary = r["decisions"]
	if await Story.talk(self, "light_crystal"):
		return
	if not GameState.quest_done("first_harvest"):
		await say([
			{"who": "Star Crystal", "text": "Tend the soil, %s. Every living thing you raise feeds the Meow Pow Wow a little." % GameState.names()["character"]},
			{"who": "Star Crystal", "text": "Hold the hoe and tap USE on grass to till. Pick seeds on the toolbar and tap USE to plant. Water each day with the can: a crop only grows on nights it was watered. The sell box pays you in crystals overnight."},
		])
	elif not GameState.quest_done("clear_meadow"):
		await say([
			{"who": "Star Crystal", "text": "I feel Grumps gathering in the meadow to the east. They are small now. They will not stay small."},
			{"who": "Star Crystal", "text": "Your sword is wood, but your heart is not. Go when you're ready."},
		])
	elif r["flags"].has("final_done"):
		await say([{"who": "Star Crystal", "text": ("He sleeps a lot. Crystals do, after. Thank you for the field, %s." if r["flags"].has("dc_reverted") else "It's quiet up there now. Down here there are turnips, %s.") % GameState.names()["character"], "mood": "happy"}])
	else:
		await say([
			{"who": "Star Crystal", "text": "The first spark of the Meow Pow Wow is yours. The rest is scattered across this world, and beyond it."},
			{"who": "Star Crystal", "text": ("What I feel next: %s" % GameState.next_step()) if GameState.next_step() != "" else "One thing at a time. Turnips first."},
		])


# ---- crafting ----------------------------------------------------------------

func _station(id: String) -> void:
	match id:
		"launchpad":
			await _launchpad()
		"laundromat":
			await Racket.laundromat(self)
		"training":
			await Racket.training(self)
		"pool":
			await Sanctuary.collect(self, "pool")
		"burrow":
			await Sanctuary.collect(self, "burrow")
		"shrine":
			await Sanctuary.shrine(self)
		_:
			await Crafting.run(self, id)


## The rocket yard: build parts here; from tier 3 it flies.
func _launchpad() -> void:
	var t := Builds.built_tier("launchpad")
	var opts: Array = ["Build rocket parts"]
	var dests: Array = []
	if t >= 3:
		opts.append("Launch: the moon (1 fuel cell)")
		dests.append("moon")
	if t >= 4:
		opts.append("Launch: the star station (1 fuel cell)")
		dests.append("station")
	opts.append("Leave")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": str(Builds.current_def("launchpad").get("name", "Rocket Yard")), "text": "The scaffold creaks in the wind." if t < 3 else "She's fuelled and pointed up.", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i == 0:
		await Crafting.run(self, "launchpad")
		return
	if i < 1 or i > dests.size():
		return
	var dest := str(dests[i - 1])
	# The rocket needs a beacon to land by: you have to have stood there once.
	var seen: bool = GameState.run["flags"].has("moon_seen") or GameState.run["flags"].has("moon_unlocked")
	if dest == "station":
		seen = GameState.run["flags"].has("station_seen") or GameState.quest_done("teleporter")
	if not seen:
		hud.toast("No landing beacon there yet. Reach it on foot once, and the rocket can follow.", Color(1, 0.85, 0.6))
		return
	if GameState.count("fuel_cell") < 1:
		hud.toast("The tank is dry. Build a Fuel Cell at the scaffold.", Color(1, 0.7, 0.7))
		return
	GameState.add_item("fuel_cell", -1)
	GameState.run["flags"]["rocket_flown"] = true
	Music.instance(get_tree()).sfx("quest_done", "levelup")
	shake(4.0)
	var c := Vector2i(int(Builds.data()["launchpad"]["cell"][0]), int(Builds.data()["launchpad"]["cell"][1]))
	fx("poof", cell_center(c) + Vector2(8, 0), 16.0, 1.0)
	fx("rocket_flame", cell_center(c) + Vector2(8, 4), 8.0, 0.6)
	if dest == "moon":
		go_to("moon", Vector2(12 * TILE, 18 * TILE), "down")
	else:
		go_to("station", Vector2(4 * TILE, 12 * TILE + 8), "right")


func _workbench() -> void:
	await Crafting.run(self, "workbench", "Workbench")


func _furnace() -> void:
	await Crafting.run(self, "furnace")
	var fc := Vector2i(int(Builds.data()["furnace"]["cell"][0]), int(Builds.data()["furnace"]["cell"][1]))
	if props.has(fc) and Art.tex("props", "furnace2_on"):
		(props[fc] as Sprite2D).texture = Art.tex("props", "furnace2_on")


func pickup_placed(c: Vector2i) -> void:
	var pk := "%d,%d" % [c.x, c.y]
	var kind := str(GameState.run.get("placed", {}).get(pk, ""))
	(GameState.run["placed"] as Dictionary).erase(pk)
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)
	if kind != "":
		give(kind, 1)
	hud.toast("Picked up the %s." % GameState.item_name(kind))


func _daily_pickup(key: String, item: String, wait_msg: String) -> void:
	var day := int(GameState.run["day"])
	if int(GameState.run["flags"].get(key, 0)) < day - 2:
		GameState.run["flags"][key] = day
		give(item)
		xp("farming", 2)
	else:
		hud.toast(wait_msg)


## The Silo: store held hay, or take 20 out. Scythed hay and wheat chaff go in by themselves.
func _silo(sel: String) -> void:
	if Net.visiting():
		hud.toast("The host keeps the silo.")
		return
	var have := Builds.silo_hay()
	var cap := Builds.silo_cap()
	if sel == "hay" and GameState.count("hay") > 0 and not GameState.is_locked("hay"):
		var n := mini(GameState.count("hay"), cap - have)
		if n <= 0:
			hud.toast("The silo is full (%d hay)." % cap)
			return
		GameState.add_item("hay", -n)
		GameState.run["silo"] = have + n
		hud.toast("Stored %d hay. Silo: %d/%d." % [n, have + n, cap], Color(0.9, 1, 0.8))
		return
	var take := mini(20, have)
	if take <= 0:
		hud.toast("The silo is empty. Scythe weeds or grow wheat to fill it.")
		return
	GameState.run["silo"] = have - take
	give("hay", take)
	hud.toast("Took %d hay. Silo: %d/%d." % [take, have - take, cap])


## The Big Coop's incubator: hold an egg and tap the coop; a chick in 3 days.
func _coop(sel: String) -> void:
	if Builds.built_tier("coop") < 2:
		hud.toast("The hens cluck at you. (The Big Coop has an incubator.)")
		return
	if Net.visiting():
		hud.toast("The host minds the incubator.")
		return
	var hatch: Array = GameState.run.get("coop_hatch", [])
	var day := int(GameState.run["day"])
	for hd in hatch:
		if int(hd) > day:
			hud.toast("An egg is warming: %d more day%s." % [int(hd) - day, "" if int(hd) - day == 1 else "s"])
			return
	if hatch.size() >= 4:
		hud.toast("The coop is full.")
		return
	if sel != "egg" or GameState.count("egg") <= 0:
		hud.toast("Hold an egg and tap the coop to hatch a chick (3 days).")
		return
	GameState.add_item("egg", -1)
	hatch.append(day + 3)
	GameState.run["coop_hatch"] = hatch
	hud.toast("The egg is in the incubator. A chick in 3 days.", Color(0.9, 1, 0.8))


func _keg(sel: String) -> void:
	var keg: Dictionary = GameState.run["flags"].get("keg", {})
	var day := int(GameState.run["day"])
	if not keg.is_empty():
		if day >= int(keg["ready"]):
			GameState.run["flags"]["keg"] = {}
			give(str(keg["out"]))
			xp("farming", 5)
		else:
			hud.toast("Fermenting... %d more day(s)." % (int(keg["ready"]) - day))
		return
	var brew := GameState.keg_brew(sel)
	if brew != "" and GameState.count(sel) > 0:
		GameState.add_item(sel, -1)
		var t := int(GameState.items.get(sel, {}).get("tier", 1))
		var days := 2 + mini(4, t)
		GameState.run["flags"]["keg"] = {"out": brew, "ready": day + days}
		hud.toast("%s → %s. Ready in %d days." % [GameState.item_name(sel), GameState.item_name(brew), days])
	else:
		hud.toast("Hold produce (fruit, vegetables, herbs, grain, mushrooms, flowers) and tap USE to brew.")





func _resonator(sel: String) -> void:
	if sel == "shard" and GameState.count("shard") >= 3:
		GameState.add_item("shard", -3)
		give("crystal_refined")
		xp("mining", 8)
		fx("pawring", cell_center(Vector2i(int(Builds.data()["resonator"]["cell"][0]), int(Builds.data()["resonator"]["cell"][1]))) + Vector2(0, -12), 10.0, 0.6)
	else:
		hud.toast("Hold 3 Crystal Shards to refine one.")


# ---- fishing -----------------------------------------------------------------

func _pond_fish(c: Vector2i, river := false) -> void:
	_fishing = true
	# The pond keeps the common fish; the rare ones live in the lake, the sea and at night.
	# The river runs cold and quick: trout and salmon, an eel at the bottom.
	await fish_at(c, RIVER_FISH if river else ["minnow", "sunfish", "carp", "bass", "trout", "catfish"])
	_fishing = false


# ---- story -------------------------------------------------------------------

func _intro() -> void:
	player.frozen = true
	var n := GameState.names()
	var dlg := Dialogue.instance(get_tree())
	dlg.begin_skippable(self)  # Skip (or MENU) jumps to the choices and the how-to-play lines
	if GameState.is_penguins():
		await _intro_penguins(n)
	else:
		await _intro_gangsters(n)
	if dlg._skip_owner == self:
		dlg.end_skippable()
	GameState.run["intro_done"] = true
	GameState.save()
	player.frozen = false


func _intro_penguins(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	await say([
		{"text": "Far past the edge of the sky, something fell.", "pic": "cut_star"},
		{"text": "It crossed a thousand dark skies, dimmer with every one, looking for a place that still had joy in it."},
		{"text": "It found %s. It found a little plot of land with a crooked house. It found you, %s." % [town, who]},
	])
	await hud.fade_out(0.6)
	_make_crystal()
	set_thing(CRYSTAL_SPOT.x, CRYSTAL_SPOT.y, {"type": "crystal", "hint": "A: talk to the Star Crystal"})
	player.position = cell_center(Vector2i(13, 15))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	Music.instance(get_tree()).sfx("spell", "levelup")
	await say([
		{"who": "???", "text": "...you can hear me? Good. Good. I was starting to think I'd landed on a world of rocks."},
		{"who": "Star Crystal", "text": "I am a Star Crystal. Where I come from, we are the memory of every kind thing anyone ever did. We are... fewer than we were."},
		{"who": "Star Crystal", "text": "One of us went dark. It calls itself the Dark Crystal now. It turned others. It built an army of Grumps whose only job is to squeeze the joy out of everything, world by world."},
		{"who": "Star Crystal", "text": "I carry the last piece of something that can stop it. A power called the Meow Pow Wow. Most of it is scattered. I can only give you the first spark."},
		{"who": "Star Crystal", "text": "I need someone with their feet in the dirt and their heart in the right place. The question is whether that's you."},
		{"who": "Star Crystal", "text": "So. %s. Will you help me?" % who, "choice": ["I'll help. Where do we start?", "I just want to farm in peace.", "Who said I'd trust a talking rock?"], "key": "crystal_answer"},
	])
	var ans := int(GameState.run["decisions"].get("crystal_answer", 0))
	if ans == 0:
		await say([
			{"who": "Star Crystal", "text": "Then we start small. Here, in this soil. The Meow Pow Wow grows from living things, so grow living things."},
		])
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 10
		GameState.run["flags"]["crystal_trust"] = 2
	elif ans == 1:
		await say([
			{"who": "Star Crystal", "text": "...Peace. Yes. That's exactly what the Grumps will take first. Farm, then. I'll wait. I'm very good at waiting."},
		])
		GameState.run["flags"]["crystal_trust"] = 1
	else:
		await say([
			{"who": "Star Crystal", "text": "Fair. I wouldn't either. I'll be here, glowing uselessly in your yard, until you change your mind."},
			{"who": "Star Crystal", "text": "...I am not a rock."},
		])
		GameState.run["flags"]["crystal_trust"] = 0
	await say([
		{"who": "Star Crystal", "text": "That little one by your feet - %s, is it? - has more Meow Pow Wow in one paw than this whole valley. Keep them close." % pet_name},
		{"who": "Star Crystal", "text": "Till the ground with the hoe. Pick the seeds on your toolbar, face the soil and tap USE. Water every morning. When your first crop comes in, we'll talk again.", "keep": true},
	])
	GameState.add_quest("first_harvest", "Grow and harvest your first crop.")
	GameState.add_quest("meet_town", "Walk south and meet the people of %s." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


func _intro_gangsters(n: Dictionary) -> void:
	var who: String = n["character"]
	var pet_name: String = n["pet"]
	var town: String = n["town"]
	Music.instance(get_tree()).play("rain")
	await say([
		{"text": "Rain. The kind that gets in under your collar and stays."},
		{"text": "You came up the south road after dark so nobody in %s would see your face. The deed in your pocket has a name on it that isn't yours." % town},
		{"text": "A crooked house. A plot of mud. A mailbox. This is what's left of your life, %s." % who},
		{"text": "Somewhere a long way from here, the man who took the rest of it is probably sleeping very well."},
	])
	await hud.fade_out(0.6)
	player.position = cell_center(Vector2i(14, 13))
	player.facing = "up"
	if pet:
		pet.position = player.position + Vector2(-14, 4)
	await hud.fade_in(0.8)
	await say([
		{"text": "There's a letter in the mailbox. You already know who it's from. M. is the only one who knows you're alive."},
		{"text": "The envelope has something written on the back, in a hand you don't recognize:"},
		{"who": "Unknown hand", "text": "\"WE KNOW WHERE YOU WENT.\""},
		{"who": who, "text": "What do you do with the letter?", "choice": ["Burn the letter. Leave no trail.", "Keep it. Evidence is evidence.", "Read it twice. Memorize the handwriting."], "key": "letter"},
	])
	var ans := int(GameState.run["decisions"].get("letter", 0))
	if ans == 0:
		await say([{"text": "You burn it in the sink. The handwriting goes with it. Whoever they are, they'll have to find you the hard way."}])
		GameState.run["flags"]["letter"] = "burned"
	elif ans == 1:
		await say([{"text": "You fold it into the deed. If this ever goes to court, it goes with you."}])
		GameState.run["flags"]["letter"] = "kept"
	else:
		await say([{"text": "The loops on the W. The hard press on the K. You'll know it when you see it again. You're sure you will."}])
		GameState.run["flags"]["letter"] = "memorized"
	await say([
		{"text": "%s shakes the rain off and looks up at you like all of this is normal. Maybe for a while it can be." % pet_name},
		{"text": "You'll need money to move on anyone. Money means crops. Crops mean dirt under your nails. Fine."},
		{"text": "Hold the hoe and tap USE on grass to till. Pick the seeds on the toolbar and tap USE to plant. Water each morning with the can. Sell at the box by the house. Don't draw eyes.", "keep": true},
	])
	GameState.add_quest("first_harvest", "Grow and harvest your first crop. Sell it at the box by the house.")
	GameState.add_quest("meet_town", "Go south. Learn who in %s can be bought, and who is watching." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	draw_grass(1)
	# No decor, forage, puddles or drifts on tilled soil, paths or the greenhouse plot.
	var av := {}
	for k in GameState.run["farm"]:
		var kp := str(k).split(",")
		av[Vector2i(int(kp[0]), int(kp[1]))] = true
	for pc: Vector2i in _path_cells:
		av[pc] = true
	av.merge(_bridge_cells)
	if Builds.is_built("greenhouse"):
		for gc: Vector2i in cells_of([GameState.GREENHOUSE_PLOT]):
			av[gc] = true
	WorldGen.draw_ground_detail(self, 21, 0.05, av)
	draw_ground("dirt", _path_cells)
	# Terrace: a lighter, drier grass up top and a cliff lip along the ledge.
	# (an old paved yard: soft-edged, not a hard grey box)
	var yard := cells_of([Rect2i(LEDGE_X0 + 1, 1, 6, 3)])
	for yc: Vector2i in [Vector2i(LEDGE_X0 + 1, 1), Vector2i(LEDGE_X0 + 6, 3)]:
		yard.erase(yc)
	if not soft_ground(yard, "ruin_floor"):
		draw_ground("stone", yard)
	draw_water(_pond_cells, "grass")
	if Art.has("tiles", "t_cliffg"):
		# The top runs on under the border band (no rim drawn along the map edge);
		# the blocked west column belongs to it, so its rock wall sits on that column.
		var top := {}
		for y in range(-pad, LEDGE_Y):
			for x in range(LEDGE_X0, cols + pad):
				top[Vector2i(x, y)] = true
		draw_plateau(top, "cliffg", {Vector2i(STAIRS_X, LEDGE_Y): true, Vector2i(STAIRS_X + 1, LEDGE_Y): true})
	draw_plateaus()  # the terrace's upper tier and the knoll
	if not Art.has("tiles", "t_cliffg"):
		Art.draw_prop(self, "props", "cliff_stairs_down", Vector2((STAIRS_X + 1) * TILE, (LEDGE_Y + 1) * TILE))
	draw_exits()
	if _soil:
		_soil.queue_redraw()
	if not Art.has("buildings", "house"):
		draw_building(HOUSE.position.x, HOUSE.position.y, HOUSE.size.x, HOUSE.size.y, Color("8b5a2b"), Color("b03a2e"), "")


func _place_props() -> void:
	if Art.has("buildings", "house"):
		prop("buildings", "house", Vector2i(HOUSE.position.x, HOUSE.end.y - 1), HOUSE.size.x - 1)
		prop("buildings", "mailbox", MAILBOX)
		prop("buildings", "sellbox", SELLBOX)
	prop("props", "notice_board", PLANS)
	# Under construction: a scaffold/sign where the crew is working.
	for cid in GameState.run.get("construction", {}):
		var bd: Dictionary = Builds.all().get(cid, {})
		if bd.is_empty():
			continue
		var cc := Vector2i(int(bd["cell"][0]), int(bd["cell"][1]))
		if not Builds.is_built(cid):  # an upgrade keeps the old picture: just the sign
			prop("props", "crates_c" if Art.has("props", "crates_c") else "crates_a", cc, int(bd.get("w", 0)))  # crates, pallet and tarp
		prop("props", "signpost" if Art.has("props", "signpost") else "notice_board", cc + Vector2i(int(bd.get("w", 0)) + 1, 0), 0, 0.0, false)  # a small sign that never blocks a path
	# Built things.
	var builds: Dictionary = GameState.run.get("builds", {})
	for id: String in builds:
		var b: Dictionary = _build_rec(id)
		if b.is_empty():
			continue
		var c: Vector2i = b["cell"]
		# Tiered station animations (Prompts 09 w177): the station's look follows the
		# crafting tier you've unlocked there.
		var station_anim := ""
		if str(b["group"]) == "stations":
			station_anim = str(b["sprite"])  # the look follows the tier you built
		elif str(b["thing"]) == "station" and not Art.has(str(b["group"]), str(b["sprite"])):
			# No painting yet: a stack of crates with the tier's name on it.
			prop("props", "crates_c" if Art.has("props", "crates_c") else "crates_a", c, int(b["w"]))
			var tag := Label.new()
			tag.text = str(Builds.current_def(id).get("name", id))
			tag.add_theme_font_size_override("font_size", 5)
			tag.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
			tag.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
			tag.add_theme_constant_override("outline_size", 3)
			tag.position = cell_center(c) + Vector2(-20, -30)
			tag.z_index = 5
			add_child(tag)
			continue
		match id:
			"beehive": station_anim = "honey_extractor"
		if station_anim != "" and Art.has("stations", station_anim):
			var st := AnimatedSprite2D.new()
			st.sprite_frames = Art.frames("stations", {"idle": station_anim}, {"idle": 4.0})
			st.animation = "idle"
			st.scale = Vector2(0.5, 0.5)
			st.position = cell_center(c)
			st.offset = Vector2(0, -float(Art.info("stations", station_anim).get("cell_h", 64)) / 2.0)
			add_child(st)
			st.play("idle")
			blocked[c] = true
			continue
		if b.has("anim") and Art.has("props", str(b["anim"])):
			var sc := AnimatedSprite2D.new()
			sc.sprite_frames = Art.frames("props", {"idle": str(b["anim"])}, {"idle": 5.0})
			sc.animation = "idle"
			var ai := Art.info("props", str(b["anim"]))
			# Fill the footprint like prop() does (one building per frame since the loop-6 re-cut).
			var fs := clampf(float(int(b["w"]) + 1) * TILE / maxf(1.0, float(ai.get("cell_w", 64))), 0.5, 1.0)
			sc.scale = Vector2(fs, fs)
			sc.position = cell_pos(c.x + (int(b["w"]) + 1) / 2.0, c.y + 1)
			sc.offset = Vector2(0, -float(ai.get("cell_h", 96)) / 2.0)
			add_child(sc)
			sc.play("idle")
		elif id == "resonator" and Art.has("props", "resonator"):
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames("props", {"idle": "resonator"}, {"idle": 4.0})
			a.animation = "idle"
			a.scale = Vector2(0.5, 0.5)
			a.position = cell_center(c)
			a.offset = Vector2(0, -float(Art.info("props", "resonator").get("cell_h", 80)) / 2.0)
			add_child(a)
			a.play("idle")
		else:
			var sinfo := Art.info(str(b["group"]), str(b["sprite"]))
			var sw := float(sinfo.get("cell_w", sinfo.get("w", 0)))
			var ssc := 0.5 if str(b["thing"]) != "station" or sw <= 0.0 else minf(0.5, float(int(b["w"]) + 3) * TILE / sw)  # a wide top-tier station stays in its slot (one cell spare each side)
			prop(str(b["group"]), str(b["sprite"]), c, int(b["w"]), 0.0, true, ssc)
	# Starter babies grow up two weeks after their coop/barn goes up (names kept, so friendship carries over).
	var fl: Dictionary = GameState.run["flags"]
	for bk in ["coop", "barn"]:
		if builds.has(bk) and not fl.has(bk + "_day"):
			fl[bk + "_day"] = int(GameState.run["day"])  # first time we see it built (old saves: today)
	if Builds.built_tier("barn") >= 2 and not fl.has("barn2_day"):
		fl["barn2_day"] = int(GameState.run["day"])
	var today := int(GameState.run["day"])
	var coop_kids := today < int(fl.get("coop_day", 0)) + 14
	var barn_kids := today < int(fl.get("barn_day", 0)) + 14
	var goat_kids := today < int(fl.get("barn2_day", 0)) + 14
	if builds.has("coop"):
		var pen := COOP_PEN
		_animal("chicken", Vector2i(27, 10), pen); _animal("chicken", Vector2i(29, 10), pen); _animal("rooster", Vector2i(30, 11), pen); _animal("chick" if coop_kids else "chicken", Vector2i(28, 11), pen, coop_kids, "chick_28_11")
		if Builds.built_tier("coop") >= 2:
			# The Big Coop: two more hens, two ducks, and the incubator's chicks.
			_animal("chicken", Vector2i(26, 10), pen); _animal("chicken", Vector2i(31, 10), pen); _animal("duck2", Vector2i(27, 11), pen); _animal("duck2", Vector2i(29, 11), pen)
			var hatch: Array = GameState.run.get("coop_hatch", [])
			for hi in hatch.size():
				var hd := int(hatch[hi])
				if int(GameState.run["day"]) >= hd:
					var young := int(GameState.run["day"]) < hd + 7
					_animal("chick" if young else "chicken", Vector2i(26 + hi, 9), pen, young, "hatch_%d" % hi)
	if builds.has("barn"):
		var pen := BARN_PEN
		_animal("cow2", Vector2i(33, 7), pen); _animal("cow_bw", Vector2i(36, 8), pen); _animal("sheep2", Vector2i(34, 8), pen); _animal("calf" if barn_kids else "cow2", Vector2i(35, 7), pen, barn_kids, "calf_35_7"); _animal("lamb" if barn_kids else "sheep2", Vector2i(36, 7), pen, barn_kids, "lamb_36_7")
		if Builds.built_tier("barn") >= 2:
			# The Big Barn: goats and a llama.
			_animal("goat", Vector2i(32, 8), pen); _animal("llama", Vector2i(35, 8), pen); _animal("goat_kid" if goat_kids else "goat", Vector2i(33, 6), pen, goat_kids, "goat_kid_33_6")
	# Debris sprites for the things placed in build().
	var season := GameState.season()
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		match str(t.get("type", "")):
			"weeds":
				prop("nature", "bush_bare_snow" if season == "winter" and Art.has("nature", "bush_bare_snow") else ("fdeco_%d" % ((c.x * 3 + c.y) % 4) if Art.has("nature", "fdeco_0") else "bush"), c)
			"rock":
				var nm := "rock_s" if (c.x + c.y) % 3 != 0 else "rock_m"
				if season == "winter" and Art.has("nature", nm.replace("rock_", "rock_snow_")):
					nm = nm.replace("rock_", "rock_snow_")
				prop("nature", nm, c)
			"log":
				var nm: String = {"fall": "log_fall", "summer": "logs"}.get(season, "log")
				prop("nature", nm if Art.has("nature", nm) else "log", c)
			"stump":
				var nm: String = {"fall": "stump_fall", "winter": "stump_snow"}.get(season, "stump")
				prop("nature", nm if Art.has("nature", nm) else "stump", c)
			"tree":
				prop("nature", GameState.tree_sprite((c.x * 7 + c.y) % 3), c)
			"bush":
				prop("nature", GameState.bush_sprite(bool(t.get("berries", false))), c)
	# Background life only: birds, butterflies, a rabbit. No livestock until you build for it.
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 15, 14, ["sparrow", "sparrow", "butterfly_orange", "butterfly_yellow", "bee", "rabbit", "squirrel", "pigeon"])
	# Stray pieces of the old world: a few boulders and a dead tree on the terrace.
	WorldGen.fruit_trees(self, Rect2i(40, 3, 30, 6), 44, 4, _stair_keep)
	prop("nature", "rock_l", Vector2i(44, 5))
	for rp: Vector2i in [Vector2i(58, 4), Vector2i(66, 4)]:
		if not blocked.has(rp) and not things.has(rp) and not _stair_keep.has(rp):
			prop("nature", "rock_m" if rp.x == 58 else ("tree_bare" if GameState.season() == "winter" else "dead_tree_m"), rp)
	_place_river_props()
	prop("props", "signpost_1" if Art.has("props", "signpost_1") else "signpost", Vector2i(32, 56))
	if Art.has("props", "abandoned_cart"):
		prop("props", "abandoned_cart", Vector2i(60, 50), 2)


## Bridges over the river, reeds and cattails along its banks, lily pads in the
## slack water, and the river's wildlife.
func _place_river_props() -> void:
	for bx: int in BRIDGE_X:
		var ys: Array = []
		for c: Vector2i in _bridge_cells:
			if c.x == bx:
				ys.append(c.y)
		if ys.is_empty():
			continue
		ys.sort()
		var y0: int = ys[0]
		var y1: int = ys[ys.size() - 1]
		var stone := bx == BRIDGE_X[1]  # the town road gets the stone bridge
		var nm := "bridge3_ns_3" if stone else "foot3_ns_a"
		if not Art.has("props", nm):
			nm = "bridge_wood2" if Art.has("props", "bridge_wood2") else "bridge"
		var tex := Art.tex("props", nm)
		if tex == null:
			continue
		# Sized so the deck is the path's width (2 cells) and spans the water bank to bank.
		var sc := maxf(float(y1 - y0 + 3) * TILE / float(tex.get_height()), (4.3 if stone else 3.7) * TILE / float(tex.get_width()))
		var rows_h := ceili(tex.get_height() * sc / TILE)
		var sp := prop("props", nm, Vector2i(bx, y1 + 1), 1, 0.0, false, sc)
		if sp:
			walk_over(sp, rows_h)  # drawn under the player (y-sort from the top bank)
	if GameState.look_se() == "winter":
		return  # reeds die back; the river runs dark between snowy banks
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for c: Vector2i in _river:
		if _bridge_cells.has(c) or not in_content(c):
			continue
		var edge := false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if not _river.has(c + d):
				edge = true
		var r := rng.randf()
		if edge and r < 0.16:
			var nm: String = ["mk_reeds_2", "mk_reeds_3", "mk_cattail_1", "mk_cattail_2", "reeds2_0", "reeds2_2"][rng.randi_range(0, 5)]
			if Art.has("props", nm):
				prop("props", nm, c, 0, 2.0, false, 0.32)
			elif Art.has("nature", nm):
				prop("nature", nm, c, 0, 2.0, false)
		elif not edge and r < 0.05 and Art.has("nature", "lily2_0"):
			var lp := prop("nature", "lily2_%d" % rng.randi_range(0, 3), c, 0, -2.0, false)
			if lp:
				to_under(lp)
	WorldGen.add_critters(self, Rect2i(2, 38, cols - 4, 18), 7172, 8, ["dragonfly", "frog", "heron", "duck", "dragonfly", "butterfly_blue"])


func _animal(kind: String, c: Vector2i, pen: Rect2i = Rect2i(), is_baby := false, nm := "") -> void:
	var full: String = {"cow2": "cow_brown", "sheep2": "sheep_woolly", "chicken": "chicken2", "pig": "pig_a", "horse": "horse3"}.get(kind, kind)
	if Art.has("animals/" + full, "idle"):
		var fa := FarmAnimal.new()
		fa.setup(self, str(full), c, pen, is_baby)
		if nm != "":
			fa.name = nm  # one name for life (a hatched chick keeps its friendship when grown)
		add_child(fa)
		return
	if not Art.has("props", kind):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("props", {"idle": kind}, {"idle": 2.0})
	a.animation = "idle"
	a.scale = Vector2(0.5, 0.5)
	a.position = cell_center(c)
	a.offset = Vector2(0, -float(Art.info("props", kind).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")
	blocked[c] = true


## Sprinklers and scarecrows: placed on open farm ground, picked up with USE.
func _place_item(c: Vector2i, id: String) -> void:
	GameState.run["placed"] = GameState.run.get("placed", {})
	GameState.run["placed"]["%d,%d" % [c.x, c.y]] = id
	GameState.add_item(id, -1)
	_show_placed(c, id)
	player.play_tool("hold")
	fx("poof", cell_center(c) + Vector2(0, -4), 10.0, 0.4)
	hud.toast("Placed the %s. USE it again to pick it up." % GameState.item_name(id), Color(0.8, 1, 0.8))


## Guests: the host's sprinklers/scarecrows come and go with the world sync (no ghosts).
var _placed_sig := 0
var _cleared_sig := 0


func on_world_sync(d: Dictionary) -> void:
	var csig := hash(GameState.run.get("cleared", {}).get("farm", {}))
	if csig != _cleared_sig:
		_cleared_sig = csig
		for c: Vector2i in things.keys():
			var ty := str(things[c].get("type", ""))
			if ty in ["weeds", "rock", "log", "stump", "tree"] and is_cleared(c, 14 if ty == "weeds" else 0):
				clear_cell(c)  # the other player cleared it
	var placed: Dictionary = GameState.run.get("placed", {})
	var psig := hash(placed)
	if psig != _placed_sig:
		_placed_sig = psig
		for c: Vector2i in things.keys():
			if str(things[c].get("type", "")) == "placed" and not placed.has("%d,%d" % [c.x, c.y]):
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Node).queue_free()
					props.erase(c)
		for pk in placed:
			var xy := str(pk).split(",")
			var pc := Vector2i(int(xy[0]), int(xy[1]))
			if not things.has(pc):
				_show_placed(pc, str(placed[pk]))
	super(d)


func _show_placed(c: Vector2i, id: String) -> void:
	set_thing(c.x, c.y, {"type": "placed", "kind": id, "hint": "A: pick up %s" % GameState.item_name(id)})
	blocked[c] = true
	var nm: String = {"sprinkler": "sprinkler_basic", "sprinkler_quality": "sprinkler_quality", "sprinkler_iridium": "sprinkler_iridium", "scarecrow": "scarecrow_classic"}.get(id, id)
	if not Art.has("props", nm):
		nm = "sprinkler" if id.begins_with("sprinkler") else "scarecrow"
	if Art.has("props", nm):
		prop("props", nm, c)


## Tilled soil and crops live on their own layer, so hoeing, planting and
## watering redraw only the field, not the whole farm (that hitched on phones).
var _soil: Node2D


func _make_soil() -> void:
	_soil = Node2D.new()
	_soil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Just below the map's own ground in the y-sort (the map draws at y=0 and is
	# sorted with its children): above the grass, under every prop and person.
	_soil.position = Vector2(offset().x, 0.5)
	_soil.draw.connect(func() -> void:
		_soil.draw_set_transform(Vector2(0, offset().y - 0.5))
		_draw_soil(_soil))
	add_child(_soil)


## A tilled cell as four quarters of the 3x3 bed painting, picked by which
## neighbours are tilled: beds get rounded rims and corners, not square tiles.
func _draw_bed(ci: CanvasItem, name: String, c: Vector2i, farm: Dictionary, tilled: Dictionary = {}) -> bool:
	var t := Art.tex("tiles", name)
	if t == null or t.get_width() < 96:
		return false
	var cw := t.get_width() / 3.0
	var ch := t.get_height() / 3.0
	for q in 4:
		var qx := q % 2
		var qy := q / 2
		var side_x := c + Vector2i(-1 if qx == 0 else 1, 0)
		var side_y := c + Vector2i(0, -1 if qy == 0 else 1)
		var hx := tilled.has(side_x) if not tilled.is_empty() else farm.has("%d,%d" % [side_x.x, side_x.y])
		var hy := tilled.has(side_y) if not tilled.is_empty() else farm.has("%d,%d" % [side_y.x, side_y.y])
		var col := 1 if hx else (0 if qx == 0 else 2)
		var row := 1 if hy else (0 if qy == 0 else 2)
		var src := Rect2(col * cw + qx * cw / 2.0, row * ch + qy * ch / 2.0, cw / 2.0, ch / 2.0)
		ci.draw_texture_rect_region(t, Rect2(Vector2(c * TILE) + Vector2(qx, qy) * (TILE / 2.0), Vector2(TILE, TILE) / 2.0), src)
	return true


var _crop_art := {}  # crop sheet -> [has stage sprites, stage textures, ripe width, sheet]


func _draw_soil(ci: CanvasItem) -> void:
	var farm: Dictionary = GameState.run["farm"]
	# The greenhouse plot (crops ignore the season here): a low stone border marks it.
	if Builds.is_built("greenhouse"):
		var gp := GameState.GREENHOUSE_PLOT
		var r := Rect2(Vector2(gp.position * TILE) + Vector2(1, 1), Vector2(gp.size * TILE) - Vector2(2, 2))
		ci.draw_rect(r, Color(0.85, 0.95, 0.8, 0.10))
		ci.draw_rect(r, Color(0.55, 0.5, 0.42, 0.9), false, 2.0)
		ci.draw_rect(r.grow(-2), Color(0.85, 0.8, 0.7, 0.5), false, 1.0)
	# Drawn in passes (dry beds, wet beds, overlays, crops) so the field batches:
	# bed, overlay and crop per tile in a row broke the batch three times a tile
	# (300 tiles: ~650 draw calls every frame; this way about a dozen).
	var cells: Array[Vector2i] = []
	var tiles := {}
	for key in farm:
		var parts: PackedStringArray = str(key).split(",")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		cells.append(c)
		tiles[c] = farm[key]
	# Row by row, so a tall crop overlaps the row behind it, never the one in front.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rain := GameState.sky_waters()
	for pass_wet: bool in [false, true]:
		for c: Vector2i in cells:
			var wet := rain or bool((tiles[c] as Dictionary).get("watered", false))
			if wet != pass_wet:
				continue
			if not _draw_bed(ci, "tilled_wet" if wet else "tilled_dry", c, farm, tiles):
				ci.draw_rect(Rect2(c * TILE + Vector2i(1, 1), Vector2i(TILE - 2, TILE - 2)), Color("5c3d22") if wet else Color("8a5f38"))
	for c: Vector2i in cells:
		var tile: Dictionary = tiles[c]
		if bool(tile.get("fert", false)):
			for k in 3:
				ci.draw_rect(Rect2(Vector2(c * TILE) + Vector2(3 + 4 * k, 12 - (k % 2) * 7), Vector2(2, 2)), Color(0.95, 0.85, 0.5, 0.8))
		if rain or bool(tile.get("watered", false)):
			# Watered soil reads darker (no blue: it turned the beds purple).
			ci.draw_rect(Rect2(Vector2(c * TILE) + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(0, 0, 0, 0.16))
	for c: Vector2i in cells:
		var tile: Dictionary = tiles[c]
		var crop := str(tile.get("crop", ""))
		if crop != "":
			var cd: Dictionary = GameState.crops.get(crop, {})
			if cd.is_empty():
				continue
			var frac := clampf(float(tile["days"]) / float(cd["days"]), 0.0, 1.0)
			var stage := mini(4, int(frac * 5.0))
			if frac >= 1.0:
				stage = 4
			var art := str(cd.get("art", crop))  # strain variants share their parent's sheet
			var ca: Array = _crop_art.get(art, [])
			if ca.is_empty():  # per crop sheet, once: stage textures and the ripe width (no string work per tile)
				var stx := []
				for st: String in ["seed", "sprout", "young", "growing", "mature", "ready"]:
					stx.append(Art.tex("crops", "%s_%s" % [art, st]))
				var rt0: Texture2D = stx[5]
				ca = [Art.has("crops", art + "_seed"), stx, rt0.get_width() if rt0 else 0, Art.tex("crops", art)]
				_crop_art[art] = ca
			var t: Texture2D = ca[3]
			if ca[0]:
				# Prompts-09 crops: one sprite per stage (seed, sprout, young, growing, mature, ready).
				var tex: Texture2D = ca[1][mini(4, int(frac * 5.0)) if frac < 1.0 else 5]
				# Sized by the ripe plant so a full bed reads as rows, not a hedge.
				var ks := minf(0.5, 30.0 / float(maxi(1, int(ca[2]) if int(ca[2]) > 0 else tex.get_width())))
				var w2 := tex.get_width() * ks
				var h2 := tex.get_height() * ks
				ci.draw_texture_rect(tex, Rect2(c.x * TILE + TILE / 2.0 - w2 / 2.0, (c.y + 1) * TILE - h2, w2, h2), false)
			elif t:
				var info := Art.info("crops", art)
				var cw := int(info.get("cell_w", 32))
				var ch := int(info.get("cell_h", 32))
				var w := cw / 2.0
				var h := ch / 2.0
				ci.draw_texture_rect_region(t, Rect2(c.x * TILE + TILE / 2.0 - w / 2.0, (c.y + 1) * TILE - h, w, h), Rect2(stage * cw, 0, cw, ch))
			else:
				_draw_plain_crop(c, cd, frac, ci)
