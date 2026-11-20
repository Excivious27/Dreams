extends GameMap
## Your plot of land, Sun Haven scale: a big open field with a crooked house,
## a mailbox, a shipping bin and nothing else. The rest is weeds, rocks, logs
## and trees to clear (progress is saved). Buildings and crafting stations are
## added later from the plans board. Farming works on any open grass cell.
## Exits: forest (north), meadow (east), town (south), lake (west).

## The farmhouse: drawn at 2/3 of its 2x art (128x116 px, 8 cells wide, ~4.5 heroes
## tall; it was 0.5 and read as a doll's house, C2). Solid over its walls and lower
## roof; the upper roof is walk-behind (it fades).
const HOUSE := Rect2i(9, 6, 8, 5)
## Harvest economy (C8 P2): level terms stop at lv_cap (20, same as P1's GameState.skill_level_eff) so yield and quality can't run away;
## star_chance is gold-star odds only; XP scales with how long the crop took.
const HARVEST := {"lv_cap": 20, "extra_per_lv": 0.012, "star_gold_share": 0.5, "gold_per_lv": 0.0075, "silver_per_lv": 0.025,
	"fert_gold": 0.10, "fert_silver": 0.20, "xp_base": 2, "xp_per_day": 0.8, "xp_per_tier": 2}
const HOUSE_SCALE := 0.667
const DOOR := Vector2i(13, 10)
const MAILBOX := Vector2i(16, 11)  # in the front yard (the wider house fills x9-16)
const SELLBOX := Vector2i(8, 10)
const PLANS := Vector2i(17, 13)  # in the front yard, clear of every house tier
## The farmhouse per tier (C5): its art, scale, solid rect, door and mailbox. The
## door is where each picture's front door is; the bigger tiers keep x9 as their
## west wall and grow east (the greenhouse plot moved out of the way, south-east).
const HOUSE_TIERS := {
	1: {"sprite": "house", "scale": 0.667, "rect": Rect2i(9, 6, 8, 5), "door": Vector2i(13, 10), "mail": Vector2i(16, 11)},
	2: {"sprite": "house_2", "scale": 0.6, "rect": Rect2i(9, 6, 12, 5), "door": Vector2i(13, 10), "mail": Vector2i(11, 11)},
	3: {"sprite": "house_3", "scale": 0.58, "rect": Rect2i(9, 6, 15, 5), "door": Vector2i(16, 10), "mail": Vector2i(11, 11)},
}
const OLD_GREENHOUSE_PLOT := Rect2i(17, 7, 9, 6)  # before C5 (crops there move to the new plot once)
var house_r := HOUSE
var _house_sprite: Sprite2D
var _house_pics := []  # [day name, night name, showing night]
var _house_scale := HOUSE_SCALE
var _house_t := 0.0
var door_c := DOOR
var mail_c := MAILBOX
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
const COOP_PEN := Rect2i(25, 9, 6, 4)  # bigger since C5 (fenced: posts x24/x31, rail y13 with a gate)
## Animal pacing (C8 P2): every youngster grows up in young_days; the Big Coop hatches up to hatch_max.
const ANIMAL := {"young_days": 7, "hatch_max": 4, "silver_streak": 5, "gold_streak": 14}
const BARN_PEN := Rect2i(31, 6, 4, 3)  # fenced on x30/x35 and y9 (C5); x31-35: the north track runs on x36 (C1), keep the herd off it
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
	"beehive": {"cell": Vector2i(29, 19), "w": 0, "h": 1, "cost": {"wood": 15, "fiber": 10}, "group": "props", "sprite": "beehive3_a", "thing": "beehive", "label": "Beehive (15 wood, 10 fiber)"},
	"resonator": {"cell": Vector2i(16, 16), "w": 0, "h": 1, "cost": {"stone": 10, "shard": 1}, "group": "props", "sprite": "resonator", "thing": "resonator", "label": "Crystal resonator (10 stone, 1 shard)"},
	"scarecrow": {"cell": Vector2i(21, 15), "w": 0, "h": 1, "cost": {"wood": 8, "fiber": 4}, "group": "props", "sprite": "scarecrow_classic", "thing": "", "label": "Scarecrow (8 wood, 4 fiber)"},
	"coop": {"cell": Vector2i(26, 8), "w": 3, "h": 3, "cost": {"wood": 120, "stone": 40}, "group": "props", "sprite": "coop_small", "thing": "", "label": "Coop (120 wood, 40 stone) - chickens"},
	"barn": {"cell": Vector2i(32, 5), "w": 4, "h": 3, "cost": {"wood": 200, "stone": 80}, "group": "props", "sprite": "barn_small", "thing": "", "label": "Barn (200 wood, 80 stone) - cows & sheep"},
	"silo": {"cell": Vector2i(30, 4), "w": 1, "h": 3, "cost": {"stone": 60, "wood": 30}, "group": "props", "sprite": "silo2", "thing": "", "label": "Silo (60 stone, 30 wood)"},
	"fish_pond": {"cell": Vector2i(26, 16), "w": 2, "h": 2, "cost": {"stone": 80, "wood": 20}, "group": "props", "sprite": "fish_pond", "anim": "fish_pond", "thing": "water", "label": "Fish pond (80 stone, 20 wood) - fish at home"},
	"shed": {"cell": Vector2i(6, 20), "w": 2, "h": 2, "cost": {"wood": 80, "stone": 20}, "group": "props", "sprite": "shed", "thing": "chest", "label": "Shed (80 wood, 20 stone) - big storage"},
	"stable": {"cell": Vector2i(32, 11), "w": 3, "h": 3, "cost": {"wood": 150, "iron_bar": 2}, "group": "props", "sprite": "stable2", "thing": "", "label": "Stable (150 wood, 2 iron bars) - a horse, soon"},
	"mill": {"cell": Vector2i(26, 2), "w": 2, "h": 4, "cost": {"wood": 120, "stone": 60}, "group": "props", "sprite": "windmill3", "anim": "windmill3", "thing": "", "label": "Mill (120 wood, 60 stone)"},
	"greenhouse": {"cell": Vector2i(22, 19), "w": 3, "h": 3, "cost": {"wood": 150, "stone": 100, "iron_bar": 2}, "group": "props", "sprite": "greenhouse2", "anim": "greenhouse2", "thing": "", "label": "Greenhouse (150 wood, 100 stone, 2 iron bars)"},
}

const WITHERED_KITS := 5  # crops/withered_any_0..4 (copied from kits/crops/withered_kit_*)
var _pond_cells := {}
var _ledge_cells := {}
var _path_cells := {}
var _river := {}         # every river cell (the water under the bridges too)
var _bridge_cells := {}  # walkable deck cells over the river
var _stair_keep := {}    # plateau stairs and the cells around them: kept clear
var _crystal: Node2D
var _fishing := false
var _crystal_t := 0.0
var _crystal_spr: AnimatedSprite2D
var _mail_mark: Sprite2D  # a letter bobbing over the mailbox while something waits in it
var _mail_t := 0.0
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
	_house_from_tier()
	block_rect(house_r.position.x, house_r.position.y, house_r.size.x, house_r.size.y)
	set_thing(door_c.x, door_c.y, {"type": "door", "hint": "A: go inside"})
	set_thing(mail_c.x, mail_c.y, {"type": "mailbox", "hint": "A: check mailbox"})
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
	_pond_cells = _round_blob(_pond_cells)  # no one-cell spurs or notches: the shore reads as a curve (c9_13)
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
	_path_cells = cells_of([Rect2i(13, 11, 1, 20), Rect2i(mini(13, door_c.x), 11, absi(door_c.x - 13) + 1, 1), Rect2i(13, 30, 24, 2), Rect2i(35, 30, 2, 28), Rect2i(2, 29, 70, 2), Rect2i(36, 2, 1, 10), Rect2i(36, 12, 2, 18), TOWN_EXIT, MEADOW_EXIT, FOREST_EXIT, LAKE_EXIT])
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
	_decor_cells = _read_decor_cells()  # yard decor is known before debris/fences/migrate (c10b_02_09)
	_place_debris()
	_plan_fences()
	_migrate_layout()


## Day/night farmhouse picture: swapped at dusk and dawn while you're on the farm.
func _house_lights() -> void:
	if _house_sprite == null or not is_instance_valid(_house_sprite) or _house_pics.is_empty():
		return
	var n := GameState.is_night()
	if n == bool(_house_pics[2]):
		return
	_house_pics[2] = n
	_house_sprite.texture = Art.tex("buildings", str(_house_pics[1] if n else _house_pics[0]))
	_fit_house_pic()


func _fit_house_pic() -> void:
	var day_t := Art.tex("buildings", str(_house_pics[0]))
	if _house_sprite.texture and day_t:
		var k := _house_scale * float(day_t.get_width()) / float(_house_sprite.texture.get_width())  # the same footprint as the day picture
		_house_sprite.scale = Vector2(k, k)
		_house_sprite.offset = Vector2(0, -_house_sprite.texture.get_height() / 2.0)


## Pen fences (C5): wooden rails (chain-link in the gangster arc) round the coop and
## barn pens, the building as the back wall, an open gate on the front rail.
var _fences: Array = []  # [cell, sprite, solid, scale]


func _plan_fences() -> void:
	_fences.clear()
	var gang := not GameState.is_penguins() and Art.has("props", "chain_fence_h")
	var h_name := "chain_fence_h" if gang else "fence2_wood_h"
	var v_name := "chain_fence_v" if gang else "fence2_wood_end"
	var gate := "fence2_iron_gate_open" if gang else "fence2_wood_gate_open"
	var specs: Array = []
	if Builds.is_built("coop"):
		specs.append([COOP_PEN, Vector2i(COOP_PEN.position.x + COOP_PEN.size.x / 2, COOP_PEN.end.y)])
	if Builds.is_built("barn"):
		specs.append([BARN_PEN, Vector2i(BARN_PEN.position.x + 1, BARN_PEN.end.y)])
	var taken := {}
	for sp: Array in specs:
		var r: Rect2i = sp[0]
		var g: Vector2i = sp[1]
		for gc: Vector2i in [g + Vector2i(0, 1), g + Vector2i(0, 2), g + Vector2i(-1, 1), g + Vector2i(1, 1)]:
			if things.has(gc) and str((things[gc] as Dictionary).get("type", "")) in ["weeds", "rock", "log", "stump", "tree", "bush"]:
				things.erase(gc)  # the way to the gate stays open
				blocked.erase(gc)
		var cells: Array = []
		for y in range(r.position.y, r.end.y):
			cells.append([Vector2i(r.position.x - 1, y), v_name])
			cells.append([Vector2i(r.end.x, y), v_name])
		for x in range(r.position.x - 1, r.end.x + 1):
			cells.append([Vector2i(x, r.end.y), h_name])
		for e: Array in cells:
			var c: Vector2i = e[0]
			if taken.has(c) or _path_cells.has(c) or not in_content(c) or (blocked.has(c) and not things.has(c)) or _river.has(c):
				continue  # a path, a building or water: leave the gap
			if things.has(c):
				var tt := str((things[c] as Dictionary).get("type", ""))
				if tt in ["weeds", "rock", "log", "stump", "tree", "bush", "forage"]:
					things.erase(c)
					blocked.erase(c)
				else:
					continue
			taken[c] = true
			var is_gate: bool = c == g
			var nm: String = gate if is_gate and Art.has("props", gate) else str(e[1])
			_fences.append([c, nm, not is_gate, 0.5])
			if not is_gate:
				blocked[c] = true


## One-off moves for old saves when the farm's layout changed (C5): soil or placed
## things under a building or the bigger farmhouse go (seed back / to a free cell),
## and crops in the old greenhouse plot move to the same spot in the new one.
func _migrate_layout() -> void:
	if Net.visiting():
		return
	var farm: Dictionary = GameState.run["farm"]
	var fl: Dictionary = GameState.run["flags"]
	if Builds.is_built("greenhouse") and not fl.has("gh_plot_c5"):
		fl["gh_plot_c5"] = true
		var off := GameState.GREENHOUSE_PLOT.position - OLD_GREENHOUSE_PLOT.position
		for oc: Vector2i in cells_of([OLD_GREENHOUSE_PLOT]):
			var ok := "%d,%d" % [oc.x, oc.y]
			if not farm.has(ok) or str((farm[ok] as Dictionary).get("crop", "")) == "":
				continue
			var nc := oc + off
			var nk := "%d,%d" % [nc.x, nc.y]
			if blocked.has(nc) or (farm.has(nk) and str((farm[nk] as Dictionary).get("crop", "")) != ""):
				continue
			farm[nk] = farm[ok]
			farm.erase(ok)
	var solid := {}
	for k in farm.keys():
		var kp := str(k).split(",")
		var c := Vector2i(int(kp[0]), int(kp[1]))
		if blocked.has(c) and not _river.has(c):
			solid[c] = true
	var keep_free := _pen_cells()
	keep_free.merge(_mega_cells())  # old saves: things in a built pen or on the limo's spot move aside (c10b_02_16/19)
	for pk in GameState.run.get("placed", {}).keys():
		var xy := str(pk).split(",")
		var pc := Vector2i(int(xy[0]), int(xy[1]))
		if blocked.has(pc) or keep_free.has(pc):
			solid[pc] = true
	for k in farm.keys():
		var kp2 := str(k).split(",")
		var kc := Vector2i(int(kp2[0]), int(kp2[1]))
		if _pen_cells().has(kc):
			solid[kc] = true
	if solid.is_empty():
		return
	for c: Vector2i in solid:
		if farm.has("%d,%d" % [c.x, c.y]):
			_clear_tile(c)
	_move_placed_off(solid)


## Rounds a cell blob: drops cells with few same neighbours (spurs, stair tips) and
## fills deep notches, twice. Old saves' soil/placed things on new cells are moved by
## _migrate_layout (it clears every blocked cell).
static func _round_blob(cells: Dictionary) -> Dictionary:
	var cur := cells.duplicate()
	for it in 2:
		var cand := {}
		for c: Vector2i in cur:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					cand[c + Vector2i(dx, dy)] = true
		var nxt := {}
		for c: Vector2i in cand:
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and cur.has(c + Vector2i(dx, dy)):
						n += 1
			if (cur.has(c) and n >= 4) or (not cur.has(c) and n >= 6):
				nxt[c] = true
		cur = nxt
	return cur


static func house_look(tier: int) -> Dictionary:
	return HOUSE_TIERS.get(clampi(tier, 1, 3), HOUSE_TIERS[1])


func _house_from_tier() -> void:
	var hl := house_look(Builds.built_tier("house"))
	house_r = hl["rect"]
	door_c = hl["door"]
	mail_c = hl["mail"]


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
	keep_out.merge(cells_of([house_r.grow(2), COOP_PEN.grow(1), BARN_PEN.grow(1), GameState.GREENHOUSE_PLOT.grow(1), Rect2i(0, 28, cols, 4)]))
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
	_move_placed_off(solid)


## Placed things (sprinklers, scarecrows, chests) standing on `solid` cells move to
## the nearest dry, free cell; a chest's contents go with it.
func _move_placed_off(solid: Dictionary) -> void:
	var farm: Dictionary = GameState.run["farm"]
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
					if to.x < 0 and in_content(n) and not solid.has(n) and not blocked.has(n) and not things.has(n) and not placed.has("%d,%d" % [n.x, n.y]) and not _path_cells.has(n) and _tillable(n) and str(farm.get("%d,%d" % [n.x, n.y], {}).get("crop", "")) == "":
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
	var home := Vector2(door_c)
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
			if _decor_cells.has(c) or (GameState.run.get("placed", {}) as Dictionary).has("%d,%d" % [c.x, c.y]):
				continue  # nothing regrows under a placed sprinkler/chest or yard decor (c10b_02_01)
			if _path_cells.has(c + Vector2i.LEFT) or _path_cells.has(c + Vector2i.RIGHT) or _path_cells.has(c + Vector2i.UP) or _path_cells.has(c + Vector2i.DOWN):
				continue  # the path's soft edge reaches its neighbours: nothing grows on the trail (C5)
			if house_r.grow(2).has_point(c) or c.distance_to(CRYSTAL_SPOT) < 3 or keep_clear.has(c):
				continue
			if (Builds.is_built("coop") and COOP_PEN.grow(1).has_point(c)) or (Builds.is_built("barn") and BARN_PEN.grow(1).has_point(c)) or (Builds.is_built("greenhouse") and GameState.GREENHOUSE_PLOT.has_point(c)):
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
			# Never on soil you've tilled.
			if GameState.run["farm"].has("%d,%d" % [c.x, c.y]):
				continue
			if r > chance:
				# Tall-grass meadows: patches of cuttable grass (fiber, hay) that
				# move with the seasons, out past the house ring.
				if dist >= 11.0 and r < chance + _meadow(c) and not is_cleared(c, regrow_days("grass", c)) and not _by_soil(c):
					# Meadow clumps: walk-through tall grass (it rustles and sways), hay half the time.
					things[c] = {"type": "weeds", "grass": true, "hay": MEADOW_HAY, "walk": true, "hint": "A: cut grass (a scythe makes hay)"}
				continue
			var k := _rng.randf()
			if dist < 9.0:
				k = k * 0.4  # by the house: only weeds, so the first plot is quick to clear
			# Tom (Guide 26 #23): debris regrows, tiered by rarity (REGROW), and the
			# weeds/tall grass shift with the season. Rocks, logs and trees never
			# come back near the house or beside your soil and builds.
			var kind := _debris_kind(k)
			var gk := _grass_or_weed(c) if k < 0.40 else ""
			if k < 0.40 and gk == "grass":
				kind = "grass"  # same regrow days as on_world_sync / the meadow clumps
			if is_cleared(c, regrow_days(kind, c)):
				continue
			if k < 0.40:
				if gk == "":
					continue  # this season leaves it bare (winter thins the weeds)
				if gk == "grass":
					things[c] = {"type": "weeds", "grass": true, "hay": 1.0, "walk": true, "hint": "A: cut grass (a scythe makes hay)"}
				else:
					things[c] = {"type": "weeds", "hint": "A: pull weeds"}
					blocked[c] = true  # weeds stay solid; tall grass is walk-through
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


## Days before cleared farm debris grows back, by how common it is (Tom, Guide 26
## #23): grass and weeds fast, stone and wood slower, trees slowest. 0 = never.
## Hay from a scythed meadow clump (old weed-spot grass always gives hay).
const MEADOW_HAY := 0.5
const REGROW := {"grass": 4, "weeds": 7, "rock": 28, "log": 21, "stump": 21, "tree": 56, "bush": 0}
## Share of the old weed spots that are tall grass, and how lush the meadows run, per season.
const GRASS_SHARE := {"spring": 0.45, "summer": 0.6, "fall": 0.45, "winter": 0.2}
const MEADOW := {"spring": 0.12, "summer": 0.18, "fall": 0.1, "winter": 0.03}


func _debris_kind(k: float) -> String:
	return "weeds" if k < 0.40 else ("rock" if k < 0.62 else ("log" if k < 0.76 else ("tree" if k < 0.94 else "bush")))


## Regrowth days for a kind of debris at cell c (inner ring and soil-side cells: never for stone/wood).
func regrow_days(kind: String, c: Vector2i) -> int:
	var d := int(REGROW.get(kind, 0))
	if d == 0 or kind in ["grass", "weeds"]:
		return d
	if Vector2(c).distance_to(Vector2(door_c)) < 14.0 or _by_soil(c):
		return 0
	return d


## Tilled soil or a placed thing next to c (regrowth never boxes your field in).
func _by_soil(c: Vector2i) -> bool:
	var farm: Dictionary = GameState.run.get("farm", {})
	var placed: Dictionary = GameState.run.get("placed", {})
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var key := "%d,%d" % [c.x + dx, c.y + dy]
			if farm.has(key) or placed.has(key) or _decor_cells.has(Vector2i(c.x + dx, c.y + dy)):
				return true
	return false


## An old weed spot this season: "grass", "weed" or "" (bare).
func _grass_or_weed(c: Vector2i) -> String:
	var se := GameState.season()
	var h := absi(hash("%s:%d:%d:%d" % [se, (int(GameState.run.get("day", 1)) - 1) / (GameState.DAYS_PER_SEASON * 4), c.x, c.y])) % 1000 / 1000.0
	if se == "winter" and h > 0.7:
		return ""
	return "grass" if h < float(GRASS_SHARE.get(se, 0.4)) else "weed"


## How likely an open cell is tall grass this season: clumped in 5-cell patches.
func _meadow(c: Vector2i) -> float:
	var se := GameState.season()
	var h := absi(hash("m:%s:%d:%d" % [se, c.x / 5, c.y / 5])) % 1000 / 1000.0
	return float(MEADOW.get(se, 0.1)) if h < 0.4 else 0.0


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
	player.facing = "down"
	var visitors := _partner_visitors(pool)
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
		ch.append("%s — %s" % [str(cd["name"]), Companion.ability_name(c)])
	ch.append("Nobody, for now")
	d.say([{"who": "", "text": str(cfg.get("ask", "Who comes with you?")), "choice": ch, "key": "partner"}])
	await d.finished
	if d.last_choice >= 0 and d.last_choice < pool.size():
		var cid: String = pool[d.last_choice]
		Companion.recruit(cid)
		for other in pool:
			if other != cid:
				Companion.party()["refused"][other] = int(Companion.party()["refused"].get(other, 0)) + 1
		# The one who stays becomes the follower standing in the same spot; the rest head off.
		var stay_at: Vector2 = (visitors[cid] as Node2D).position if visitors.has(cid) else player.position + Vector2(14, 6)
		_partner_leave(visitors, cid)
		_refresh_party()
		if companion:
			companion.position = stay_at
		var cname := str(Companion.defs()[cid]["name"])
		var ab := str(Companion.defs()[cid]["ability_name"])
		var how := "Tap %s's round button (bottom of the screen, left of CHECK) to use %s." % [cname, ab]
		if str(Companion.defs()[cid].get("ability", "")) == "meow_pow_wow" and not Companion.meow_known():
			how = "%s can't use the Meow Pow Wow yet: someone has to teach it. Catkins, in the crystal meadow past the east meadow, can." % cname
		await say([{"who": cname, "text": str(Companion.defs()[cid]["join"])}, {"text": "%s joined your party and follows you around. %s Change partners in MENU > Party." % [cname, how]}])
		GameState.add_hint("Partners: tap %s's round button (bottom, left of CHECK) to use %s. Others who asked may take it badly if you keep saying no." % [cname, ab])
	else:
		for other in pool:
			Companion.refuse(other)
		_partner_leave(visitors, "")
		await say([{"text": "They look at each other. They go. The gate is quieter than before."}])
	player.frozen = false


## The partner scene's visitors, standing in front of you while they ask.
func _partner_visitors(pool: Array) -> Dictionary:
	var out := {}
	var n := pool.size()
	for i in n:
		var cid := str(pool[i])
		var spr_id := str(Companion.defs().get(cid, {}).get("sprite", ""))
		if spr_id == "" or not CharacterLibrary.has_character(spr_id):
			continue
		var spr := CharacterLibrary.make_sprite(spr_id)
		# Beside you, level with you: below would be under the dialogue box.
		var side := -1.0 if i % 2 == 0 else 1.0
		var to := player.position + Vector2(side * (26.0 + 22.0 * floorf(i / 2.0)), 2.0)
		spr.position = to + Vector2(side * 60.0, 0)
		spr.z_index = 2
		spr.set_meta("partner_visitor", true)
		spr.flip_h = side > 0.0  # walking in toward you
		spr.play("walk" if spr.sprite_frames.has_animation("walk") else "idle")
		add_child(spr)
		var tw := spr.create_tween()
		tw.tween_property(spr, "position", to, 0.9)
		tw.tween_callback(func() -> void:
			if is_instance_valid(spr):
				spr.flip_h = false
				spr.play("idle"))
		out[cid] = spr
	return out


## Everyone but `stays` walks off south and fades; the one who stays is replaced by the follower.
func _partner_leave(visitors: Dictionary, stays: String) -> void:
	for cid in visitors:
		var spr := visitors[cid] as AnimatedSprite2D
		if not is_instance_valid(spr):
			continue
		if str(cid) == stays:
			spr.queue_free()
			continue
		spr.play("walk_down" if spr.sprite_frames.has_animation("walk_down") else "idle")
		var tw := spr.create_tween()
		tw.tween_property(spr, "position", spr.position + Vector2(0, 70), 1.6)
		tw.parallel().tween_property(spr, "modulate:a", 0.0, 1.6)
		tw.tween_callback(spr.queue_free)


func after_ready() -> void:
	_make_soil()
	for pk in GameState.run.get("placed", {}):
		var xy := str(pk).split(",")
		_show_placed(Vector2i(int(xy[0]), int(xy[1])), str(GameState.run["placed"][pk]))
	# Yard decor stands before critters, the spouse and the border pick their cells (c10b_02_09).
	if not Net.visiting():
		var gone: Array = DecorMode.relayout(self)
		if not gone.is_empty():
			hud.toast("The farm changed: %s went back to your decor box." % ", ".join(gone), Color(1, 0.9, 0.7))
	DecorMode.dress(self)
	_decor_after()
	_entry_button()
	# The partner scene's day comes from companions.json (penguins: day 2, the day after the crystal lands).
	var pday := int(Companion.data().get("partner_scene", {}).get(str(GameState.run.get("arc", "")), {}).get("when", {}).get("day", 3))
	if int(GameState.run["day"]) >= pday and not GameState.run["flags"].has("partner_scene") and bool(GameState.run["intro_done"]):
		GameState.run["flags"]["partner_scene"] = true
		_partner_scene.call_deferred()
	WorldGen.add_backdrop(self, "hills")
	_place_props()
	SpouseFarm.place(self)  # married: the spouse on the porch in the morning (C7 P1)
	WorldGen.dress_band(self, 5150)
	WorldGen.clear_stairs.call_deferred(self)
	if GameState.is_penguins() and bool(GameState.run["intro_done"]):
		_make_crystal()
	if not bool(GameState.run["intro_done"]):
		_intro.call_deferred()
	_make_mail_mark()


func _make_mail_mark() -> void:
	var t := Art.tex("items", "letter_sealed")
	if t == null:
		return
	_mail_mark = Sprite2D.new()
	_mail_mark.texture = t
	_mail_mark.region_enabled = true  # skip the stray stroke above the envelope
	_mail_mark.region_rect = Rect2(3, 6, t.get_width() - 3, t.get_height() - 6)
	_mail_mark.scale = Vector2(0.4, 0.4)
	_mail_mark.z_index = 20
	_mail_mark.position = cell_center(mail_c) + Vector2(0, -30)
	_mail_mark.visible = false
	add_child(_mail_mark)


func _make_crystal() -> void:
	_crystal = Node2D.new()
	_crystal.position = cell_center(CRYSTAL_SPOT)
	var drawn := CharacterLibrary.has_character("light_crystal")
	_crystal.draw.connect(func() -> void:
		var c := _crystal
		var glow := 0.5 + 0.5 * sin(_crystal_t * 2.0)
		c.draw_circle(Vector2(0, -10), 11.0 + glow * 2.0, Color(0.6, 0.85, 1.0, 0.14 if drawn else 0.18))
		if not drawn:
			var pts := PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, 2), Vector2(-5, -10)])
			c.draw_colored_polygon(pts, Color(0.75, 0.9, 1.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(5, -10), Vector2(0, -8)]), Color(1, 1, 1, 0.8))
		c.draw_circle(Vector2(0, 4.0 + sin(_crystal_t * 1.5) * 2.0), 4.0, Color(0, 0, 0, 0.2)))
	if drawn:
		# The Star Crystal's own sprite (the face from its portrait): it bobs, and talks when it talks.
		_crystal_spr = CharacterLibrary.make_sprite("light_crystal")
		_crystal_spr.scale *= 1.4
		_crystal_spr.play("idle")
		_crystal.add_child(_crystal_spr)
	add_child(_crystal)


func _process(delta: float) -> void:
	super(delta)
	_grass_step()
	_house_t += delta
	if _house_t > 2.0:
		_house_t = 0.0
		_house_lights()
	if _mail_mark:
		_mail_t += delta
		_mail_mark.position.y = cell_center(mail_c).y - 30.0 - absf(sin(_mail_t * 3.0)) * 3.0
		if int(_mail_t * 2.0) != int((_mail_t - delta) * 2.0):
			_mail_mark.visible = bool(GameState.run.get("intro_done", false)) and Mail.waiting() > 0
	if _crystal:
		_crystal_t += delta
		_crystal.position.y = cell_center(CRYSTAL_SPOT).y - 3.0 - sin(_crystal_t * 1.5) * 2.0
		if int(_crystal_t * 10.0) != int((_crystal_t - delta) * 10.0):
			_crystal.queue_redraw()  # the glow pulse at 10 Hz; the bob is a position change
			if _crystal_spr:
				var dl := Dialogue.instance(get_tree())
				var talking := dl.active and dl._who.text in ["Star Crystal", "???"] and dl._typing
				var want := "speak" if talking and _crystal_spr.sprite_frames.has_animation("speak") else "idle"
				if _crystal_spr.animation != want:
					_crystal_spr.play(want)


## Tall grass you walk through rustles and sways (Stardew-style), weeds stay solid.
var _grass_cell := Vector2i(-99, -99)


func _grass_step() -> void:
	if player == null:
		return
	var pc: Vector2i = player.cell()
	if pc == _grass_cell:
		return
	_grass_cell = pc
	var t: Dictionary = things.get(pc, {})
	if not bool(t.get("walk", false)):
		return
	sway_grass(pc)
	Music.instance(get_tree()).sfx("step_grass", "step_leaves")  # (level: Music GROUP_DB "step_", P1)
	if randf() < 0.35:
		_leaf(cell_center(pc) + Vector2(randf_range(-5, 5), -6))


func sway_grass(c: Vector2i) -> void:
	var sp: Variant = props.get(c, null)
	if not (sp is Node2D) or not is_instance_valid(sp):
		return
	var n := sp as Node2D
	var dir := -1.0 if player and player.position.x > n.position.x else 1.0
	var tw := create_tween()  # the map's tween: props may not process on their own
	tw.tween_property(n, "skew", 0.35 * dir, 0.08)
	tw.tween_property(n, "skew", -0.18 * dir, 0.16)
	tw.tween_property(n, "skew", 0.0, 0.22)


## The scythe cuts a 3-cell swath: the cell you aimed at plus the two beside it
## (across your facing). Called by GameMap's weed cut (has_method hook).
func scythe_sweep(c: Vector2i) -> void:
	if player == null:
		return
	var f := str(player.facing)
	var side := Vector2i(1, 0) if f in ["up", "down"] else Vector2i(0, 1)
	for sc: Vector2i in [c + side, c - side]:
		var t: Dictionary = things.get(sc, {})
		if str(t.get("type", "")) != "weeds":
			continue
		if randf() < float(t.get("hay", 0.5)):
			if not (not Net.visiting() and Builds.silo_add(1)):
				pop_items(cell_center(sc), "hay", 1)
		_mark_cleared(sc)
		var wsp: Node2D = props.get(sc, null)
		clear_cell(sc)
		if wsp:
			wsp.queue_free()
		for i in 2:
			_leaf(cell_center(sc) + Vector2(randf_range(-6, 6), -8))
		pop_items(cell_center(sc), "fiber", 1)
		# C5 c5_18 #5: side cells count too, at half the main cut's rolls (free swing, no extra energy)
		if randf() < 0.5:
			xp("foraging", 1)
		if randf() < (0.06 + 0.01 * GameState.skill_level("foraging")) * 0.5:
			pop_items(cell_center(sc), "seed_packet", 1)


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
			elif not _fishing:
				ToolHint.need(self, "rod", "to fish")
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
		"keg", "resonator":
			later(_station.bind(str(thing.get("type", "keg"))))  # old things: the station screen (C8 P2)
			return true
		"silo":
			_silo(sel)
			return true
		"coop":
			_coop(sel)
			return true
		"barn":
			hud.toast("The animals live out in the pen: hold hay and tap them, pet them daily for milk and wool. %d days running: silver goods; %d: gold. A missed day starts over.%s" % [int(ANIMAL["silver_streak"]), int(ANIMAL["gold_streak"]), " The Big Barn feeds them from the silo each morning." if Builds.built_tier("barn") >= 2 else ""])
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
			# c10_13: a tap meant to walk past must never lift it: the first USE asks, a
			# second one on the same spot within PICK_ARM_S seconds picks it up.
			if not pick_armed(c):
				_pick_arm = [c, PlayClock.now()]
				hud.toast("USE again to pick up the %s." % GameState.item_name(str(thing.get("kind", ""))))
				return true
			_pick_arm = []
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
			if str(GameState.items.get(sel, {}).get("type", "")) == "placeable" and GameState.count(sel) > 0 and not guest and till_why(c) != "" and not things.has(c):
				ToolHint.say(self, till_why(c))
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


## Why a free cell can't take soil or a placeable ("" = it can, or it's an ordinary wall).
func till_why(c: Vector2i) -> String:
	if _decor_cells.has(c):
		return "Your yard decor is there."
	if _pen_cells().has(c):
		return "That's the animals' pen."
	if _apron_cells().has(c):
		return "Keep that spot clear: it's in front of %s." % str(_apron_cells()[c])
	if _mega_cells().has(c):
		return "Leave room here: something will park on this spot."
	return ""


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
	if till_why(c) != "":
		return false  # decor, built pens, service fronts, travel spots (c10b_02_16/19/20)
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
		# Inside a category: a plan's "← Back" returns to this list, not the top (C4 P6).
		while true:
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
					opts.append("◷ %s → %s (%d day%s left)" % [label, str(Builds.tier_def(id, int(uc["tier"]))["name"]), dl, "" if dl == 1 else "s"])
					ids.append("")
					continue
				if nd.is_empty():
					opts.append("✓ %s (%s, max)" % [label, str(Builds.current_def(id).get("name", ""))])
					ids.append("")
					continue
				var g := Builds.gate(id)
				var why := Builds.blocker(id)
				var mark := "" if why == "" else ("⊘ " if g != "" else "✗ ")
				var tag := ""
				if g == "permit":
					tag = "  [permit ◆%d at Town Hall]" % Builds.permit_price(id)
				elif g != "":
					tag = "  [%s]" % g
				opts.append("%s%s%s%s" % [mark, ("%s → " % str(Builds.current_def(id).get("name", label))) if bt > 0 else "", str(nd["name"]), tag])
				ids.append(id)
			opts.append("← Back")
			var legend := "⊘ = not open yet · ✗ = missing materials (you can still buy it)"
			if cat == "operation":
				legend = "Your racket: print bills, wash them clean, run fronts, arm and train the crew. Heat rises when a bill gets noticed.\n" + legend
			elif cat == "sanctuary":
				legend = "Cat-topia's crafts, and homes for friends you turn back: pool, burrow and shrine open as you meet who they're for.\n" + legend
			d.say([{"who": "Plans", "text": legend, "choice": opts, "key": ""}])
			await d.finished
			var i := d.last_choice
			if i < 0 or i >= ids.size():
				break  # "← Back" (or B): back to the categories
			if str(ids[i]) == "":
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


## A crop that died at the season's turn stays as a withered plant (Stardew-style)
## until it's pulled: any tool or a bare hand clears it, leaving tilled soil.
func _clear_withered(c: Vector2i, key: String, tile: Dictionary) -> bool:
	var dead := str(tile.get("dead", ""))
	tile.erase("dead")
	tile["fert"] = false
	net_act({"a": "farm_tile", "key": key, "tile": tile})
	player.play_tool("hoe" if GameState.held_tool() == "hoe" else "hold")
	Music.instance(get_tree()).sfx("pickup", "dig")
	fx("crop_wilt", cell_center(c), 8.0, 0.5)
	if GameState.items.has("fiber") and randf() < 0.5:
		GameState.add_item("fiber", 1)
	var nm := GameState.item_name(str(GameState.crops.get(dead, {}).get("yield", dead)))
	hud.toast("Pulled up the withered %s." % nm.to_lower(), Color(0.9, 0.85, 0.7))
	_soil.queue_redraw() if _soil else queue_redraw()
	return true


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
		# The soil turns when the hoe bites (0.25 s into the swing), with a puff of dirt.
		_later(0.25, func() -> void:
			fx("dirt_puff", cell_center(c) + Vector2(0, 3), 14.0, 0.4)
			_soil.queue_redraw() if _soil else queue_redraw())
		return true
	if str(tile.get("dead", "")) != "":
		return _clear_withered(c, key, tile)
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
		hud.toast("Fertilised: grows half again as fast, better stars. Lasts until the next harvest.", Color(0.7, 1, 0.7))
		_soil.queue_redraw() if _soil else queue_redraw()
		return true
	if crop == "":
		var it: Dictionary = GameState.items.get(sel, {})
		if it.get("type", "") == "seed" and GameState.count(sel) > 0 and not GameState.crops.has(str(it.get("crop", ""))):
			hud.toast("%s won't take in this soil." % GameState.item_name(sel), Color(1, 0.8, 0.6))
			Music.instance(get_tree()).sfx("nope", "thud")
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
			player.play_tool("hold")  # seeds go in by hand (a hoe swing read as tilling)
			Music.instance(get_tree()).sfx("plant_pat", "plant")
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
		var flv := mini(GameState.skill_level("farming"), int(HARVEST["lv_cap"]))
		var n := harvest_count(flv, GameState.bonus("farming", "extra_crop"), GameState.bonus("farming", "double_harvest"), randf(), randf())
		pop_items(cell_center(c), str(cd["yield"]), n)  # the crop hops out to you
		if str(cd["yield"]) == "wheat" and not Net.visiting():
			Builds.silo_add(1)  # chaff goes to the silo
		# Quality: farming skill and fertiliser raise the odds of silver and gold.
		var fert := bool(tile.get("fert", false))
		var qd := quality_odds(flv, fert, GameState.bonus("farming", "star_chance"))
		var qr := randf()
		# Star toasts once a day each (a field of gold stars shouldn't bury the screen).
		var told: Dictionary = GameState.run["flags"].get("star_told", {})
		if int(told.get("day", -1)) != int(GameState.run.get("day", 0)):
			told = {"day": int(GameState.run.get("day", 0))}
		if qr < float(qd["gold"]):
			GameState.add_quality(str(cd["yield"]), "g", n)
			if not told.has("g"):
				told["g"] = true
				hud.toast("★ Gold-star %s! Sells for half again as much." % GameState.item_name(str(cd["yield"])), Color(1, 0.85, 0.3))
			Music.instance(get_tree()).sfx("crit", "coin")
			fx("sparkle", cell_center(c) + Vector2(0, -10), 14.0, 0.6)
		elif qr < float(qd["silver"]):
			GameState.add_quality(str(cd["yield"]), "s", n)
			if not told.has("s"):
				told["s"] = true
				hud.toast("☆ Silver-star %s: sells for a quarter more." % GameState.item_name(str(cd["yield"])), Color(0.85, 0.9, 1.0))
			Music.instance(get_tree()).sfx("sparkle", "coin")
		GameState.run["flags"]["star_told"] = told
		if GameState.log_grown(crop):
			hud.toast("Field log: first %s! (%d of %d crops grown)" % [str(cd["name"]), (GameState.run["grown"] as Dictionary).size(), GameState.crops.size()], Color(0.8, 1, 0.7))
		if randf() < GameState.bonus("farming", "seed_back"):
			var seed_id := _seed_for(crop)
			if seed_id != "":
				give(seed_id, 1)
		player.play_tool("hold")
		var hm := Music.instance(get_tree())
		hm.sfx("harvest", "pickup")
		# The reward pop on top of the rustle (c6_10-13).
		get_tree().create_timer(0.12, false).timeout.connect(func() -> void: hm.sfx("harvest_pluck", "pop"))
		xp("farming", harvest_xp(cd))
		tile.erase("fert")  # fertiliser feeds one growth cycle, regrowing crops included
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
	if GameState.held_tool() == "hoe" and player and player._hold_t > 0.25:
		return true  # hold-to-till rows run over crops: stay quiet (a fresh tap still reads it)
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
		if GameState.held_tool() == "hoe":
			return false  # a hoe row over planted soil stays quiet
		return ToolHint.need(self, "can", "to water it")
	if WaterCan.level() <= 0:
		WaterCan.say_empty(self)  # C6 P7: the can runs dry; refill at water
		return true
	if not GameState.spend_for("can"):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return true
	tile["watered"] = true
	WaterCan.use()
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
	if key != "":
		var wp := key.split(",")
		_later(0.3, func() -> void: fx("splash", cell_center(Vector2i(int(wp[0]), int(wp[1]))) + Vector2(0, 2), 14.0, 0.35))
	_later(0.3, func() -> void: _soil.queue_redraw() if _soil else queue_redraw())  # the soil darkens as the water lands
	return true


## Run f after `sec` seconds of game time (tool timing: soil changes when the swing lands).
func _later(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			f.call())


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


## True for an item the museum collects that is not in its cases yet.
static func museum_wants(id: String) -> bool:
	return Collections.in_log("museum", id) and not (Collections.st()["donated"] as Dictionary).has(id)


func _sellbox(sel: String) -> void:
	var box: Dictionary = GameState.run["sellbox"]
	var stype := str(GameState.items.get(sel, {}).get("type", ""))
	if sel != "" and GameState.count(sel) > 0 and stype in ["key", "vehicle"]:
		hud.toast("You can't sell the %s. It matters." % GameState.item_name(sel), Color(1, 0.85, 0.6))
		return
	if sel != "" and GameState.count(sel) > 0 and DecorSources.keeps(sel):
		hud.toast(DecorSources.KEEP_LINE, Color(1, 0.85, 0.6))  # one-of-a-kind pieces never ship (C10a)
		return
	if sel != "" and GameState.is_locked(sel):
		hud.toast("Your %s is locked in your bag. Unlock it to sell it." % GameState.item_name(sel), Color(1, 0.85, 0.6))
		return
	if sel != "" and GameState.count(sel) == 1 and stype != "tool" and museum_wants(sel) and not Net.visiting():
		# The last one of a museum piece not yet donated (the koi exists once): ask first (c10_07).
		var dm := Dialogue.instance(get_tree())
		dm.say([{"text": "The museum doesn't have a %s yet, and this is your only one. Sell it anyway?" % GameState.item_name(sel), "choice": ["Sell it", "Keep it"], "key": ""}])
		await dm.finished
		if dm.last_choice != 0:
			return
	if sel != "" and GameState.count(sel) > 0 and stype != "tool":
		var n := GameState.count(sel)
		if n > 1 and not Net.visiting():
			# Ship part of a stack: keep a few for gifts, quests and cooking (C8 P2).
			var amounts: Array = [n, n - 1, maxi(1, n / 2), 1]
			var dlg := Dialogue.instance(get_tree())
			dlg.say([{"text": "Sell how many %s? (you have %d)" % [GameState.item_name(sel), n], "choice": ["All %d" % n, "All but 1", "Half (%d)" % amounts[2], "Just 1", "Back"], "key": ""}])
			await dlg.finished
			if dlg.last_choice < 0 or dlg.last_choice >= amounts.size():
				return
			n = int(amounts[dlg.last_choice])
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
		GameState.add_item(sel, -n)  # the sell box is our own (guest_morning pays a guest); nothing to send the host
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
	# The story's letters first, then everything else, all in one visit.
	var story: Array = Mail.story_due()
	for sl: Dictionary in story:
		GameState.run["flags"][str(sl["flag"])] = true
		await say([{"who": str(sl["who"]), "text": str(sl["text"])}])
		if sl.has("give"):
			give(str(sl["give"][0]), int(sl["give"][1]))
		if sl.has("quest") and not GameState.has_quest(str(sl["quest"][0])):
			# Day-gated quests may already be open (opened quietly at wake-up): only announce new ones.
			GameState.add_quest(str(sl["quest"][0]), str(sl["quest"][1]))
			hud.toast("New quest: " + str(sl["quest"][1]), Color(1, 0.9, 0.4))
	if Mail.pending() > 0 or story.is_empty():
		await read_mail()


## After a story letter, any letters waiting in the mail list come too (one tap reads the box).
func _more_mail() -> void:
	if Mail.unread() > 0:
		await read_mail()


func _talk_crystal() -> void:
	var r := GameState.run
	var d: Dictionary = r["decisions"]
	if await Story.talk(self, "light_crystal"):
		return
	if not GameState.quest_done("first_harvest"):
		await say([
			{"who": "Star Crystal", "text": "Tend the soil, %s. Every living thing you raise feeds the Meow Pow Wow a little." % GameState.names()["character"]},
			{"who": "Star Crystal", "text": GameState._first_crop_step()},
			{"who": "Star Crystal", "text": "While it grows: clear weeds and stones with your tools, gather wild things to sell in the box by the house, meet the town to the south, or fish the pond with the rod in hand."},
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
	await ArcIntro.first(self, id)  # first use of an arc building says what it's for
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
	if Net.visiting():  # the host's rocket: flying it would earn the guest rocket_flown and Space
		hud.toast("Your host's rocket. Ask them to fly it; yours waits on your own farm.", Color(1, 0.85, 0.6))
		return
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


const PICK_ARM_S := 2.5
var _pick_arm: Array = []


func pick_armed(c: Vector2i) -> bool:
	return _pick_arm.size() == 2 and _pick_arm[0] == c and PlayClock.now() - float(_pick_arm[1]) <= PICK_ARM_S


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
	Music.instance(get_tree()).sfx("pickup")


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
			Music.instance(get_tree()).sfx("nope", "thud")
			return
		GameState.add_item("hay", -n)
		GameState.run["silo"] = have + n
		hud.toast("Stored %d hay. Silo: %d/%d." % [n, have + n, cap], Color(0.9, 1, 0.8))
		Music.instance(get_tree()).sfx("cloth", "step_leaves")
		return
	var take := mini(20, have)
	if take <= 0:
		hud.toast("The silo is empty. Scythe weeds or grow wheat to fill it.")
		Music.instance(get_tree()).sfx("nope", "thud")
		return
	GameState.run["silo"] = have - take
	give("hay", take)
	Music.instance(get_tree()).sfx("cloth", "step_leaves")
	hud.toast("Took %d hay. Silo: %d/%d." % [take, have - take, cap])


## The Big Coop's incubator: hold an egg and tap the coop; a chick in 3 days.
func _coop(sel: String) -> void:
	if Builds.built_tier("coop") < 2:
		hud.toast("The hens cluck at you. Feed and pet them daily: %d days running gives silver eggs, %d gold. (The Big Coop has an incubator.)" % [int(ANIMAL["silver_streak"]), int(ANIMAL["gold_streak"])])
		Music.instance(get_tree()).sfx("cluck", "critter")
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
	if hatch.size() >= int(ANIMAL["hatch_max"]):
		hud.toast("The coop has room for %d hatchlings, and it's full." % int(ANIMAL["hatch_max"]))
		return
	if sel != "egg" or GameState.count("egg") <= 0:
		hud.toast("Hold an egg and tap the coop to hatch a chick (3 days).")
		return
	GameState.add_item("egg", -1)
	hatch.append(day + 3)
	GameState.run["coop_hatch"] = hatch
	hud.toast("The egg is in the incubator. A chick in 3 days.", Color(0.9, 1, 0.8))
	Music.instance(get_tree()).sfx("pop", "pickup")
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void: Music.instance(get_tree()).sfx("cluck", "critter"))


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
		GameState.add_money(10, "farm")
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
		{"who": "Star Crystal", "text": "Hold the hoe (the first toolbar slot), face the grass and tap USE to till. Then pick the seeds, tap USE on the soil, and water it with the can.", "keep": true},
		{"who": "Star Crystal", "text": "Lost? The line under the toolbar always says what to do next. Water every morning; when your first crop comes in, we'll talk again.", "keep": true},
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
		{"text": "The envelope has something written on the back, in a hand you don't recognise:"},
		{"who": "Unknown hand", "text": "\"WE KNOW WHERE YOU WENT.\""},
		{"who": who, "text": "What do you do with the letter?", "choice": ["Burn the letter. Leave no trail.", "Keep it. Evidence is evidence.", "Read it twice. Memorise the handwriting."], "key": "letter"},
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
		{"text": "Tap the hoe on your toolbar, face grass and tap USE to till. Pick the seeds on the toolbar and tap USE to plant. Water each morning with the can. Sell at the box by the house. Don't draw eyes.", "keep": true},
	])
	GameState.add_quest("first_harvest", "Grow and harvest your first crop. Sell it at the box by the house.")
	GameState.add_quest("meet_town", "Go south. Learn who in %s can be bought, and who is watching." % town)
	hud.toast("New quests. Open MENU to see them.", Color(1, 0.9, 0.4))


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	dry_patches = false  # the per-cell dry squares read as hard tan boxes in the field (c5_01 #6)
	tuft_skip.clear()
	for pen_t: Array in [["coop", COOP_PEN], ["barn", BARN_PEN], ["greenhouse", GameState.GREENHOUSE_PLOT]]:
		if Builds.is_built(str(pen_t[0])):
			for tc: Vector2i in cells_of([(pen_t[1] as Rect2i).grow(1)]):
				tuft_skip[tc] = true  # grazed pens and the bed: short grass (C5)
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
		for gc: Vector2i in cells_of([GameState.GREENHOUSE_PLOT.grow(1)]):
			av[gc] = true
	for pen_b: Array in [["coop", COOP_PEN], ["barn", BARN_PEN]]:
		if Builds.is_built(str(pen_b[0])):
			for pc2: Vector2i in cells_of([(pen_b[1] as Rect2i).grow(1)]):
				av[pc2] = true  # a grazed pen: no tufts or flowers (C5)
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
		draw_building(house_r.position.x, house_r.position.y, house_r.size.x, house_r.size.y, Color("8b5a2b"), Color("b03a2e"), "")


func _place_props() -> void:
	if Art.has("buildings", "house"):
		var hl := house_look(Builds.built_tier("house"))
		var hs := str(hl["sprite"]) if Art.has("buildings", str(hl["sprite"])) else "house"
		var hn := hs + "_night"  # lit windows after dark (the night pictures were cut but unused)
		var hsc := float(hl["scale"]) if hs == str(hl["sprite"]) else HOUSE_SCALE
		var hday := WorldGen.winter_look("buildings", hs)  # snowy roof in winter (C5 P3 art)
		# Winter nights keep the snowy roof (the _night redraw has none, c10b_01-05):
		# the lit-window mask glows on it instead (c10b_01-36).
		var winter := hday != hs
		var night_pic := GameState.is_night() and Art.has("buildings", hn) and not winter
		_house_pics = [hday, hday if winter else (hn if Art.has("buildings", hn) else hday), night_pic]
		var hp := prop("buildings", hn if night_pic else hday, Vector2i(house_r.position.x, house_r.end.y - 1), house_r.size.x - 1, 0.0, false, hsc)
		_house_sprite = hp
		_house_scale = hsc
		if winter and glow and hp is Sprite2D:
			glow.add_windows(hp, hs)
		# P3's farmhouse exterior styles (palette swap + parts), when that script exists.
		if ResourceLoader.exists("res://scripts/house_exterior.gd"):
			var hx: Script = load("res://scripts/house_exterior.gd")
			if hx and hx.get_script_method_list().any(func(md: Dictionary) -> bool: return str(md["name"]) == "apply"):
				hx.call("apply", self, hp)
		if night_pic:
			_fit_house_pic()
		prop("buildings", "mailbox", mail_c)
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
			tag.add_theme_font_size_override("font_size", 7)
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
			if id in ["coop", "barn"] and sw > 0.0:
				ssc = minf(0.667, float(int(b["w"]) + 2) * TILE / sw)  # the farmhouse's scale (at 0.5 they read as toys, C5), one cell spare
			prop(str(b["group"]), str(b["sprite"]), c, int(b["w"]), 0.0, true, ssc)
	# Starter babies grow up two weeks after their coop/barn goes up (names kept, so friendship carries over).
	var fl: Dictionary = GameState.run["flags"]
	for bk in ["coop", "barn"]:
		if builds.has(bk) and not fl.has(bk + "_day"):
			fl[bk + "_day"] = int(GameState.run["day"])  # first time we see it built (old saves: today)
	if Builds.built_tier("barn") >= 2 and not fl.has("barn2_day"):
		fl["barn2_day"] = int(GameState.run["day"])
	var today := int(GameState.run["day"])
	var coop_kids := today < int(fl.get("coop_day", 0)) + int(ANIMAL["young_days"])
	var barn_kids := today < int(fl.get("barn_day", 0)) + int(ANIMAL["young_days"])
	var goat_kids := today < int(fl.get("barn2_day", 0)) + int(ANIMAL["young_days"])
	for f: Array in _fences:
		var fp := prop("props", str(f[1]), f[0], 0, 0.0, bool(f[2]), float(f[3]))
		if fp and str(f[1]).ends_with("_v"):
			fp.offset.y += 4.0  # a side post stands on its cell, not above it
	if builds.has("coop"):
		var pen := COOP_PEN
		_animal("chicken", Vector2i(27, 10), pen); _animal("chicken", Vector2i(29, 10), pen); _animal("rooster", Vector2i(30, 11), pen); _animal("chick" if coop_kids else "chicken", Vector2i(28, 11), pen, coop_kids, "chick_28_11")
		if Builds.built_tier("coop") >= 2:
			# The Big Coop: two more hens, two ducks, and the incubator's chicks.
			_animal("chicken", Vector2i(26, 12), pen); _animal("chicken", Vector2i(30, 12), pen); _animal("duck2", Vector2i(25, 11), pen); _animal("duck2", Vector2i(28, 12), pen)
			var hatch: Array = GameState.run.get("coop_hatch", [])
			for hi in hatch.size():
				var hd := int(hatch[hi])
				if int(GameState.run["day"]) >= hd:
					var young := int(GameState.run["day"]) < hd + int(ANIMAL["young_days"])
					if hud and int(GameState.run["day"]) == hd and not GameState.run["flags"].has("hatch_peep_%d" % hd):
						GameState.run["flags"]["hatch_peep_%d" % hd] = true
						hud.toast("A chick hatched in the coop!", Color(0.9, 1, 0.8))
						Music.instance(get_tree()).sfx("peep", "critter")  # hatch day (c6_10-15)
					_animal("chick" if young else "chicken", Vector2i(26 + hi, 9), pen, young, "hatch_%d" % hi)
	if builds.has("barn"):
		var pen := BARN_PEN
		_animal("cow2", Vector2i(33, 7), pen); _animal("cow_bw", Vector2i(31, 8), pen); _animal("sheep2", Vector2i(34, 8), pen); _animal("calf" if barn_kids else "cow2", Vector2i(34, 6), pen, barn_kids, "calf_35_7"); _animal("lamb" if barn_kids else "sheep2", Vector2i(31, 7), pen, barn_kids, "lamb_36_7")  # (name kept: friendship)
		if Builds.built_tier("barn") >= 2:
			# The Big Barn: goats and a llama.
			_animal("goat", Vector2i(32, 8), pen); _animal("llama", Vector2i(32, 6), pen); _animal("goat_kid" if goat_kids else "goat", Vector2i(33, 6), pen, goat_kids, "goat_kid_33_6")
	_silo_feed()
	# Debris sprites for the things placed in build().
	var season := GameState.season()
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		match str(t.get("type", "")):
			"weeds":
				var wn := "%s_%s" % ["tgrass" if bool(t.get("grass", false)) else "weed", season]
				prop("nature", wn if Art.has("nature", wn) else ("fdeco_%d" % ((c.x * 3 + c.y) % 4) if Art.has("nature", "fdeco_0") else "bush"), c, 0, 0.0, not bool(t.get("walk", false)))
			"rock":
				var nm := "rock_s" if (c.x + c.y) % 3 != 0 else "rock_m"
				if season == "winter" and Art.has("nature", nm.replace("rock_", "rock_snow_")):
					nm = nm.replace("rock_", "rock_snow_")
				prop("nature", nm, c)
			"log":
				var nm: String = {"fall": "log_fall", "summer": "logs", "winter": "log_snow"}.get(season, "log")
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
		if Art.has("props", nm + "_dry"):
			nm += "_dry"  # its painted pond patch keyed out: the river shows under it (c5_01 #7)
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
		var land := Vector2.ZERO  # towards the bank
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if not _river.has(c + d):
				edge = true
				land += Vector2(d)
		var r := rng.randf()
		if edge and r < 0.16:
			var nm: String = ["mk_reeds_2", "mk_reeds_3", "mk_cattail_1", "mk_cattail_2", "reeds2_0", "reeds2_2"][rng.randi_range(0, 5)]
			# Reeds stand in the shallows at the bank, not out in the stream (the soft
			# shore draws the edge cell half as water): nudged towards the land side.
			var nudge := land.normalized() * 7.0 if land != Vector2.ZERO else Vector2.ZERO
			var rp: Sprite2D = null
			if Art.has("props", nm):
				rp = prop("props", nm, c, 0, 2.0, false, 0.32)
			elif Art.has("nature", nm):
				rp = prop("nature", nm, c, 0, 2.0, false)
			if rp:
				rp.position += nudge
		elif not edge and r < 0.05 and Art.has("nature", "lily2_0"):
			var lp := prop("nature", "lily2_%d" % rng.randi_range(0, 3), c, 0, -2.0, false)
			if lp:
				to_under(lp)
	WorldGen.add_critters(self, Rect2i(2, 38, cols - 4, 18), 7172, 8, ["dragonfly", "frog", "heron", "duck", "dragonfly", "butterfly_blue"])


func _animal(kind: String, c: Vector2i, pen: Rect2i = Rect2i(), is_baby := false, nm := "") -> void:
	var full: String = {"cow2": "cow_brown", "sheep2": "sheep_woolly", "chicken": "chicken2", "pig": "pig_a", "horse": "horse3", "goat": "goat2"}.get(kind, kind)  # goat2: same sheet style as the cows and sheep (C5)
	if Art.has("animals/" + full, "idle"):
		var fa := FarmAnimal.new()
		fa.setup(self, str(full), c, pen, is_baby)
		if nm == "" and kind == "goat":
			nm = "goat_%d_%d" % [c.x, c.y]  # (drawn from goat2 since C5: the name, and its friendship, stay)
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
	Music.instance(get_tree()).sfx("drop", "thud")
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
			if ty in ["weeds", "rock", "log", "stump", "tree"] and is_cleared(c, regrow_days("grass" if bool(things[c].get("grass", false)) else ty, c)):
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
	if d.has("decor_home") or d.has("decor_home_d"):
		# The host changed the yard: redress it from the host's view (c10b_02_12).
		var dsig := hash(DecorMode.placed("farm"))
		if dsig != _decor_sig:
			_decor_sig = dsig
			DecorMode.dress(self)
			decor_changed()
			unstick_player()
	super(d)


var _decor_sig := 0


func _show_placed(c: Vector2i, id: String) -> void:
	set_thing(c.x, c.y, {"type": "placed", "kind": id, "hint": ("A: open chest" if id == "chest" else "A twice: pick up %s" % GameState.item_name(id))})
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
		_draw_kerb(ci, GameState.GREENHOUSE_PLOT)
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
		if crop == "" and str(tile.get("dead", "")) != "":
			_draw_withered(ci, c, str(tile["dead"]))
			continue
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


## A withered plant: the crop's own *_withered sprite, else one of the shared kit plants.
func _draw_withered(ci: CanvasItem, c: Vector2i, art: String) -> void:
	var tex: Texture2D = null
	if Art.has("crops", art + "_withered"):
		tex = Art.tex("crops", art + "_withered")
	else:
		var n := posmod(c.x * 7 + c.y * 3, WITHERED_KITS)
		if Art.has("crops", "withered_any_%d" % n):
			tex = Art.tex("crops", "withered_any_%d" % n)
	if tex == null:
		ci.draw_rect(Rect2(Vector2(c * TILE) + Vector2(5, 7), Vector2(6, 7)), Color("6b5a3a"))
		return
	var ks := minf(0.5, 22.0 / float(maxi(1, tex.get_width())))
	var w := tex.get_width() * ks
	var h := tex.get_height() * ks
	ci.draw_texture_rect(tex, Rect2(c.x * TILE + TILE / 2.0 - w / 2.0, (c.y + 1) * TILE - h - 1, w, h), false)


## The greenhouse bed's low stone kerb (C5: it was a thin debug-looking rectangle):
## a ring of rounded field stones in two greys with a light top and a dark base.
func _draw_kerb(ci: CanvasItem, gp: Rect2i) -> void:
	var r := Rect2(Vector2(gp.position * TILE) - Vector2(3, 3), Vector2(gp.size * TILE) + Vector2(6, 6))
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color(0.36, 0.27, 0.17, 0.35))  # darker bed soil under the glass's care
	var stones: Array[Rect2] = []
	var step := 8.0
	var n := int(r.size.x / step)
	for i in n:
		var w := step - 1.0 - float((i * 7) % 3) * 0.5
		stones.append(Rect2(r.position.x + i * step, r.position.y, w, 5))
		stones.append(Rect2(r.position.x + i * step, r.end.y - 5, w, 5))
	var m := int(r.size.y / step)
	for j in range(1, m):
		var h := step - 1.0 - float((j * 5) % 3) * 0.5
		stones.append(Rect2(r.position.x, r.position.y + j * step, 5, h))
		stones.append(Rect2(r.end.x - 5, r.position.y + j * step, 5, h))
	for k in stones.size():
		var st: Rect2 = stones[k]
		var base := Color(0.62, 0.6, 0.55) if k % 3 != 0 else Color(0.54, 0.53, 0.5)
		ci.draw_rect(st.grow(0.5), Color(0.22, 0.2, 0.2))
		ci.draw_rect(st, base)
		ci.draw_rect(Rect2(st.position, Vector2(st.size.x, 1.5)), base.lightened(0.25))
		ci.draw_rect(Rect2(st.position + Vector2(0, st.size.y - 1.5), Vector2(st.size.x, 1.5)), base.darkened(0.25))


## Crops per pick: 1, a bonus crop from (capped) level and skills, doubled by double_harvest.
static func harvest_count(flv: int, extra_crop: float, double_p: float, r1: float, r2: float) -> int:
	var lv := mini(flv, int(HARVEST["lv_cap"]))
	var n := 1 + (1 if r1 < float(HARVEST["extra_per_lv"]) * (lv - 1) + extra_crop else 0)  # C6 P7: no bonus crop at level 1
	if r2 < double_p:
		n *= 2
	return n


## Gold/silver odds (cumulative): capped level, fertiliser, star_chance (gold only).
static func quality_odds(flv: int, fert: bool, star_chance: float) -> Dictionary:
	var lv := mini(flv, int(HARVEST["lv_cap"]))
	var g := float(HARVEST["gold_per_lv"]) * lv + (float(HARVEST["fert_gold"]) if fert else 0.0) + star_chance * float(HARVEST["star_gold_share"])
	var sv := g + float(HARVEST["silver_per_lv"]) * lv + (float(HARVEST["fert_silver"]) if fert else 0.0)
	return {"gold": g, "silver": sv}


## Harvest XP grows with the wait (a 2-day crop gives less than a 10-day one).
static func harvest_xp(cd: Dictionary) -> int:
	var wait := int(cd.get("regrow", cd.get("days", 1)))
	return int(HARVEST["xp_base"]) + int(float(HARVEST["xp_per_day"]) * wait) + int(HARVEST["xp_per_tier"]) * int(cd.get("tier", 1))


## The Big Barn (and the Big Coop) feed their grown animals from the silo once each morning, 1 hay each (C8 P2).
func _silo_feed() -> void:
	if Net.visiting() or Builds.silo_hay() <= 0:
		return
	var day := int(GameState.run["day"])
	var all: Dictionary = GameState.run.get("animals", {})
	for ch in get_children():
		if not (ch is FarmAnimal) or (ch as FarmAnimal).baby or Builds.silo_hay() <= 0:
			continue
		var k := str((ch as FarmAnimal).kind)
		var bird := k.begins_with("chicken") or k.begins_with("hen") or k.begins_with("duck") or k == "rooster"
		if k == "rooster" or Builds.built_tier("coop" if bird else "barn") < 2:
			continue
		var st: Dictionary = all.get(str(ch.name), {"streak": 0, "last_pet": -9, "fed": -9})
		if int(st["fed"]) == day:
			continue
		st["fed"] = day
		GameState.run["silo"] = Builds.silo_hay() - 1
		all[str(ch.name)] = st
	GameState.run["animals"] = all


# ---- yard decorating (CONDUCT 10b P2: DecorMode outdoors) ---------------------------

## Yard decor cells (cell -> layer) from the farm's placed decor (the host's while
## visiting, through DecorMode.view()). Debris, soil, regrowth, placeables and
## villager paths all read it.
var _decor_cells := {}


func _read_decor_cells() -> Dictionary:
	var out := {}
	for p in DecorMode.placed("farm"):
		if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
			continue
		var id := str(p["id"])
		for c: Vector2i in DecorMode.footprint(id, DecorMode._cell_of(p), int(p.get("rot", 0))):
			out[c] = DecorMode.layer_of(id)
	return out


## Built coop/barn pens and a ring round them: the animals' ground (c10b_02_19).
func _pen_cells() -> Dictionary:
	var out := {}
	if Builds.is_built("coop"):
		for c: Vector2i in cells_of([COOP_PEN.grow(1)]):
			out[c] = true
	if Builds.is_built("barn"):
		for c: Vector2i in cells_of([BARN_PEN.grow(1)]):
			out[c] = true
	return out


## One-cell aprons in front of/beside the mailbox, shipping bin, plans board and the
## Star Crystal (cell -> what it serves), shared by placeables and yard decor (c10b_02_20).
func _apron_cells() -> Dictionary:
	var out := {}
	for pr: Array in [[mail_c, "the mailbox"], [SELLBOX, "the shipping bin"], [CRYSTAL_SPOT, "the Star Crystal"]]:
		var c: Vector2i = pr[0]
		for d: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
			out[c + d] = str(pr[1])
	for dx in range(-1, 2):
		out[PLANS + Vector2i(dx, 1)] = "the plans board"
	return out


## Where a travel keeper parks on the farm (the Gilt City limo): its cell, base row,
## keeper and arrival spots stay free (c10b_02_16).
func _mega_cells() -> Dictionary:
	var out := {}
	var regs: Variant = MegaTravel.data()
	if not (regs is Dictionary):
		return out
	for id in regs:
		var e: Variant = (regs[id] as Dictionary).get("entry", {}) if regs[id] is Dictionary else {}
		if not (e is Dictionary) or str((e as Dictionary).get("scene", "")) != "farm":
			continue
		var c := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
		for dy in range(-1, 1):
			for dx in range(-2, 2):
				out[c + Vector2i(dx, dy)] = true
		var ka: Array = (e as Dictionary).get("keeper_at", [-2, 0])
		out[c + Vector2i(int(ka[0]), int(ka[1]))] = true
		var sp: Array = (e as Dictionary).get("spawn", [c.x, c.y + 2])
		out[Vector2i(int(sp[0]), int(sp[1]))] = true
	return out


func decor_outdoor() -> bool:
	return true


func decor_bounds() -> Rect2i:
	return Rect2i(2, 2, cols - 4, rows - 4)


func decor_door() -> Vector2i:
	return door_c + Vector2i(0, 1)


## Cells no yard piece may cover, with why (c10b_02_02 / 08 / 09 / 16 / 19 / 20 / 23).
func decor_reserved() -> Dictionary:
	var r := {}
	for c: Vector2i in cells_of([house_r.grow(1)]):
		r[c] = "the house"
	for dy in range(1, 3):
		r[door_c + Vector2i(0, dy)] = "the doorway"
	r[mail_c] = "the mailbox"
	r[SELLBOX] = "the shipping bin"
	for dx in range(-1, 2):
		r[PLANS + Vector2i(dx, 0)] = "the plans board"
	if GameState.is_penguins():
		r[CRYSTAL_SPOT] = "the Star Crystal"
	r.merge(_apron_cells())
	for e in exits:
		for c: Vector2i in cells_of([(e["rect"] as Rect2i).grow(2)]):
			r[c] = "the road out"
	for c: Vector2i in _pond_cells:
		r[c] = "the pond"
	for c: Vector2i in _river:
		r[c] = "the river"
	for c: Vector2i in _bridge_cells:
		for dy in range(-2, 3):
			r[c + Vector2i(0, dy)] = "the bridge"
	for c: Vector2i in _ledge_cells:
		r[c] = "the terrace"
	for c: Vector2i in _stair_keep:
		r[c] = "the stairs"
	for y in range(0, LEDGE_Y + 1):
		for x in range(LEDGE_X0, cols):
			r[Vector2i(x, y)] = "the terrace (for later)"
	for c: Vector2i in _pen_cells():
		r[c] = "the animals' pen"
	for c: Vector2i in cells_of([COOP_PEN.grow(1), BARN_PEN.grow(1)]):
		r[c] = "the animals' pen"
	if Builds.is_built("greenhouse"):
		for c: Vector2i in cells_of([GameState.GREENHOUSE_PLOT.grow(1)]):
			r[c] = "the greenhouse plot"
	# Every building slot of this story (built, being built or planned) with its roof
	# rows and front: a building never goes up on top of a statue (c10b_02_08 / 23).
	for bid in Builds.all():
		if bid == "house" or not Builds.data().has(bid):
			continue
		var bd: Dictionary = Builds.all()[bid]
		if not bd.has("cell"):
			continue
		var bc := Vector2i(int(bd["cell"][0]), int(bd["cell"][1]))
		var bh := int(bd.get("h", 1))
		var up := bh + 2
		var lbl := "a %s spot" % str(bd.get("label", bid)).to_lower()
		for c: Vector2i in cells_of([Rect2i(bc.x - 1, bc.y - up + 1, int(bd.get("w", 0)) + 3, up + 2)]):
			r[c] = lbl
	for c: Vector2i in _mega_cells():
		r[c] = "a parking spot"
	# The farmhouse roof reaches rows above its footprint: pieces there would hide behind it.
	for c: Vector2i in cells_of([Rect2i(house_r.position.x, house_r.position.y - 4, house_r.size.x, 4)]):
		r[c] = "behind the roof"
	for pc: Vector2i in [Vector2i(44, 5), Vector2i(32, 56), Vector2i(60, 50), Vector2i(61, 50)]:
		r[pc] = "a landmark"
	var ha: Array = GameState.run["flags"].get("horse_at", [])
	if ha.size() >= 3 and str(ha[0]) == "farm":
		r[Vector2i(int(ha[1]), int(ha[2]))] = "your horse"
	return r


## Must stay reachable from the door: the services, each road out and every built front.
func decor_must_reach() -> Array:
	var out: Array = [mail_c + Vector2i(0, 1), SELLBOX + Vector2i(0, 1), PLANS + Vector2i(0, 1), Vector2i(STAIRS_X, LEDGE_Y + 1)]
	for e in exits:
		var er: Rect2i = e["rect"]
		out.append(er.position + er.size / 2)
	for bid: String in GameState.run.get("builds", {}):
		var b := _build_rec(bid)
		if not b.is_empty():
			out.append((b["cell"] as Vector2i) + Vector2i(0, 1))
	for pk in GameState.run.get("placed", {}):
		var xy := str(pk).split(",")
		out.append(Vector2i(int(xy[0]), int(xy[1])))
	# One cell of every field.
	var seen := {}
	for k in GameState.run.get("farm", {}):
		var xy := str(k).split(",")
		var c := Vector2i(int(xy[0]), int(xy[1]))
		var key := Vector2i(c.x / 6, c.y / 6)
		if not seen.has(key):
			seen[key] = true
			out.append(c)
	return out


## After a decor change: only the flat layer redraws (DecorMode.dress did), never a
## re-bake of the farm (c10b_02_06); fields and villager paths learn the new cells.
func decor_changed() -> void:
	_decor_cells = _read_decor_cells()
	_decor_after()


## Villagers keep off crop beds and flowerbeds (c10b_02_14); yard paths are paths for
## footsteps and weather dressing (c10b_02_15).
func _decor_after() -> void:
	keep_off.clear()
	for k in GameState.run.get("farm", {}):
		var xy := str(k).split(",")
		keep_off[Vector2i(int(xy[0]), int(xy[1]))] = true
	for p in DecorMode.placed("farm"):
		if not (p is Dictionary) or not Decor.is_decor(str(p.get("id", ""))):
			continue
		var id := str(p["id"])
		var e := Decor.entry(id)
		var cells: Array = DecorMode.footprint(id, DecorMode._cell_of(p), int(p.get("rot", 0)))
		if bool(e.get("keep_off", false)) or str(e.get("sub", "")) == "flowerbed":
			for c: Vector2i in cells:
				keep_off[c] = true
		var seam := str(e.get("seam", ""))
		if seam != "" or str(e.get("sub", "")) == "path":
			var w := "dirt" if ("dirt" in seam or "track" in seam) else ("wood" if "board" in seam else "stone")
			for c: Vector2i in cells:
				step_word[c] = w
				# a puddle / drift / leaf pile under a new path goes
				if props.has(c) and is_instance_valid(props[c]) and not blocked.has(c):
					var pn := str((props[c] as Node).name).to_lower()
					if pn.contains("puddle") or pn.contains("drift") or pn.contains("leaf"):
						(props[c] as Node).queue_free()
						props.erase(c)
	_flows.clear()


var _yard_btn: Button = null


## "Decorate yard" (never for guests): a small button clear of the HUD and touch deck.
func _entry_button() -> void:
	if Net.visiting() or not is_instance_valid(hud):
		return
	var ly := CanvasLayer.new()
	ly.layer = 5
	var bt := Button.new()
	bt.text = "Decorate yard"
	bt.add_theme_font_size_override("font_size", Settings.font(7))
	bt.clip_text = true
	bt.position = Vector2(196, 64)
	bt.size = Vector2(70, 18)
	bt.custom_minimum_size = Vector2(70, 18)
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(func() -> void:
		if not get_tree().paused and not Dialogue.instance(get_tree()).active:
			DecorMode.open(self))
	ly.add_child(bt)
	add_child(ly)
	_yard_btn = bt
	var hide_t := Timer.new()
	hide_t.wait_time = 0.25
	hide_t.process_mode = Node.PROCESS_MODE_ALWAYS
	hide_t.timeout.connect(func() -> void:
		if is_instance_valid(bt):
			# Only near the house (it's your yard tool, not a HUD fixture), never paused.
			bt.visible = not get_tree().paused and player != null and Vector2(player.cell()).distance_to(Vector2(door_c)) < 14.0 and DecorMode.busy_why(self) == "")
	ly.add_child(hide_t)
	hide_t.start()
	var rect := Rect2(bt.position, bt.size)
	Hud.extra_rects.append(rect)
	tree_exiting.connect(func() -> void: Hud.extra_rects.erase(rect))
