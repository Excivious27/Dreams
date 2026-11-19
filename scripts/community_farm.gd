extends GameMap
## The community farm west of town: Dreamhollow Commons (penguins) / the
## Westside Lot Garden (gangsters, a vacant lot behind a brick wall). Hazel
## runs it; the logic, stages, schedule and economy live in `Commons`
## (scripts/commons.gd, data/community_farm.json).
## Layout (52x40): the road in from town on the east (rows 19-20), the notice
## board at the gate, a plaza with the well, four raised beds west of it, the
## tool shed and compost north, the greenhouse and cold frames north-east, the
## market stand south-east, the picnic corner and the orchard row south.
## What stands depends on the stage (the map reloads when a stage is done).

const TOWN_EXIT := Rect2i(51, 18, 1, 4)
const PLAZA_C := Vector2(29.0, 20.5)
const PLAZA_R := 4.3
const BOARD := Vector2i(45, 17)
const SHED := Vector2i(26, 7)
const WELL := Vector2i(28, 19)
const GREENHOUSE := Vector2i(38, 10)
const STAND := Vector2i(41, 26)
## Stage 0: what's piled on the lot. [x, y, penguin kind, gangster kind]
const DEBRIS := [[7, 15, "bramble", "tyres"], [10, 14, "boulder", "rubble"], [16, 15, "log", "crates"], [19, 16, "bramble", "weeds"],
	[6, 24, "stump", "drums"], [11, 23, "bramble", "tyres"], [16, 24, "boulder", "cart"], [20, 25, "bramble", "weeds"],
	[25, 17, "log", "crates"], [32, 23, "boulder", "rubble"], [12, 33, "stump", "drums"], [24, 33, "bramble", "weeds"],
	[38, 27, "log", "cart"], [44, 29, "bramble", "tyres"]]
## kind -> [art group, art name, tool ("" = hands), hits, item, n]
const JUNK := {
	"bramble": ["nature", "bramble", "", 1, "fiber", 2], "boulder": ["nature", "rock_m", "pickaxe", 3, "stone", 3],
	"log": ["nature", "log", "axe", 3, "wood", 4], "stump": ["nature", "stump", "axe", 2, "wood", 2],
	"tyres": ["props", "tyres", "", 2, "", 8], "rubble": ["props", "boulder_m", "pickaxe", 3, "stone", 3],
	"crates": ["props", "crates_c", "axe", 2, "wood", 3], "weeds": ["nature", "bramble", "", 1, "fiber", 2],
	"drums": ["props", "oil_drums", "", 2, "copper", 2], "cart": ["props", "abandoned_cart", "", 3, "nails", 4],
}

var npcs: Array = []
var _plots: Node2D
var _cells := {}          # plot key "x,y" -> cold frame?
var _jobs := {}           # Npc -> [plot key, seconds]
var _job_t := 0.0
var _busy := {}           # cells kept clear of trees and scatter


func scene_id() -> String:
	return Commons.SCENE


func default_spawn() -> Vector2:
	return Vector2(49 * TILE, 19 * TILE + 8) + offset()


func _s() -> int:
	return Commons.stage()


func _gang() -> bool:
	return not GameState.is_penguins()


func build() -> void:
	cols = 52
	rows = 40
	pad = 7
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "trees"}
	music_track = "countryside"
	add_exit(TOWN_EXIT, "town", Vector2(2 * TILE, 47 * TILE + 8), "right", "town ▶")
	var s := _s()
	if s == 0:
		var left := 0
		for d: Array in DEBRIS:
			var key := "%d,%d" % [int(d[0]), int(d[1])]
			if (Commons.st()["cleared"] as Dictionary).has(key):
				continue
			var kind := str(d[3] if _gang() else d[2])
			var j: Array = JUNK[kind]
			set_thing(int(d[0]), int(d[1]), {"type": "cf_debris", "kind": kind, "hp": int(j[3]), "key": key, "hint": "A: clear the %s" % _junk_name(kind)})
			left += 1
		Commons.st()["debris_left"] = left
	_cells = Commons.plot_cells()
	for key: String in _cells:
		var p := key.split(",")
		things[Vector2i(int(p[0]), int(p[1]))] = {"type": "cf_plot", "key": key, "hint": "A: the bed"}
	for c in cells_of(_paths()):
		_busy[c] = true
	for b: Array in Commons.data().get("beds", []) + Commons.data().get("frames", []):
		for c in cells_of([Rect2i(int(b[0]) - 1, int(b[1]) - 1, int(b[2]) + 2, int(b[3]) + 2)]):
			_busy[c] = true
	for c in cells_of([Rect2i(20, 3, 26, 9), Rect2i(31, 22, 20, 16), Rect2i(2, 30, 36, 9), Rect2i(41, 14, 8, 6)]):
		_busy[c] = true


func _junk_name(kind: String) -> String:
	return {"bramble": "brambles", "boulder": "boulder", "log": "fallen log", "stump": "stump", "tyres": "old tyres", "rubble": "rubble", "crates": "broken crates", "weeds": "weeds", "drums": "oil drums", "cart": "wrecked cart"}.get(kind, kind)


## Paths that exist at this stage (only the road in until the lot is cleared).
func _paths() -> Array:
	var out: Array = [Rect2i(36, 19, 16, 2)]
	if _s() >= 1:
		out += [Rect2i(3, 19, 33, 2), Rect2i(28, 8, 2, 11), Rect2i(28, 21, 2, 11), Rect2i(3, 31, 36, 2), Rect2i(39, 11, 2, 8)]
	if _s() >= 3:
		out.append(Rect2i(33, 27, 15, 2))
	return out


func _plaza() -> Dictionary:
	var out := {}
	for y in range(15, 27):
		for x in range(23, 36):
			if Vector2(x + 0.5, y + 0.5).distance_to(PLAZA_C) <= PLAZA_R + WorldGen.fbm(float(x), float(y), 818, 3.0) * 0.8:
				out[Vector2i(x, y)] = true
	return out


# ---- drawing --------------------------------------------------------------------

func draw_map() -> void:
	var s := _s()
	draw_grass(17)
	var avoid := _busy.duplicate()
	WorldGen.draw_ground_detail(self, 171, 0.14, avoid)
	if _gang():
		# The old lot's asphalt shows through where nothing grows.
		var lot := WorldGen.blob(self, Vector2(40.0, 28.0), 9.0, 6.0, 1717, 1, 0.3)
		lot.merge(_plaza())
		soft_ground(lot, "asphalt", Color(0.1, 0.1, 0.1, 0.25))
	if s == 0:
		var wild := WorldGen.blob(self, Vector2(16.0, 21.0), 15.0, 13.0, 1718, 2, 0.28)
		soft_ground(wild, "dry_grass", Color(0.2, 0.16, 0.05, 0.15))
	else:
		if not _gang():
			soft_ground(_plaza(), "cobble_warm", Color(0.15, 0.1, 0.05, 0.3))
		if s < 3:
			# Dug and marked out, waiting for the beds.
			var dug := {}
			for b: Array in Commons.data().get("beds", []):
				dug.merge(cells_of([Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))]))
			soft_ground(dug, "mud_field", Color(0.2, 0.12, 0.05, 0.3))
		if s < 7:
			# The greenhouse footings.
			soft_ground(cells_of([Rect2i(37, 6, 6, 5)]), "old_stone", Color(0.1, 0.1, 0.1, 0.25))
	var ways := {}
	var plaza := _plaza() if s >= 1 or _gang() else {}
	for c in cells_of(_paths()):
		if not plaza.has(c):
			ways[c] = true
	if not soft_ground(ways, "dirt_track", Color(0.25, 0.15, 0.06, 0.3)):
		draw_ground("dirt", ways)
	draw_exits()


## The beds: tilled soil in plank frames, crops, cold-frame glass. Redrawn as they change.
func _draw_plots(ci: CanvasItem) -> void:
	if _s() < 3:
		return
	var wet := GameState.sky_waters() or _s() >= 5
	var beds: Array = Commons.data().get("beds", [])
	var frames: Array = Commons.data().get("frames", []) if _s() >= 7 else []
	var bed_t := Art.tex("props", "cf_bed_frame")
	var cold_t := Art.tex("props", "cf_cold_frame")
	for b: Array in beds:
		var r := Rect2(Vector2(int(b[0]), int(b[1])) * TILE, Vector2(int(b[2]), int(b[3])) * TILE)
		if bed_t:
			# The plank frame, nine-sliced round the bed (posts and front board keep their size).
			_nine(ci, bed_t, Rect2(r.position - Vector2(4, 5), r.size + Vector2(8, 11)), 9.0, 10.0, 9.0, 16.0)
		else:
			ci.draw_rect(r.grow(3), Color("8a5a2b"))
	for b: Array in frames:
		var r := Rect2(Vector2(int(b[0]), int(b[1])) * TILE, Vector2(int(b[2]), int(b[3])) * TILE)
		if cold_t:
			# The cold frame box with its glass lid propped up behind (soil row = the bed cells).
			var w := r.size.x + 8.0
			var h := cold_t.get_height() * w / cold_t.get_width()
			ci.draw_texture_rect(cold_t, Rect2(r.position.x - 4, r.end.y + 6 - h, w, h), false)
	var tilled := {}
	for key: String in _cells:
		var p := key.split(",")
		tilled[Vector2i(int(p[0]), int(p[1]))] = key
	for c: Vector2i in tilled:
		var pl := Commons.plot(str(tilled[c]))
		var w := wet or bool(pl.get("w", false))
		if bed_t == null and not _bed_tile(ci, "tilled_wet" if w else "tilled_dry", c, tilled):
			ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("5c3d22") if w else Color("8a5f38"))
		if w:
			ci.draw_rect(Rect2(Vector2(c * TILE) + Vector2(1, 2), Vector2(TILE - 2, TILE - 3)), Color(0.05, 0.02, 0, 0.18))
	var cells: Array = tilled.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		var pl := Commons.plot(str(tilled[c]))
		var crop := str(pl.get("crop", ""))
		var cd: Dictionary = GameState.crops.get(crop, {})
		if cd.is_empty():
			continue
		var frac := clampf(float(pl.get("days", 0)) / float(cd.get("days", 1)), 0.0, 1.0)
		var art := str(cd.get("art", crop))
		if Art.has("crops", art + "_seed"):
			var st: String = ["seed", "sprout", "young", "growing", "mature", "ready"][mini(4, int(frac * 5.0)) if frac < 1.0 else 5]
			var tex := Art.tex("crops", "%s_%s" % [art, st])
			var ripe_t := Art.tex("crops", art + "_ready")
			if tex:
				var ks := minf(0.5, 30.0 / float(maxi(1, ripe_t.get_width() if ripe_t else tex.get_width())))
				var w2 := tex.get_width() * ks
				var h2 := tex.get_height() * ks
				ci.draw_texture_rect(tex, Rect2(c.x * TILE + TILE / 2.0 - w2 / 2.0, (c.y + 1) * TILE - h2, w2, h2), false)
		else:
			var col := Color(str(cd.get("top", "6fbf4f")))
			var h := 3.0 + 9.0 * frac
			ci.draw_rect(Rect2(c.x * TILE + 6, (c.y + 1) * TILE - 3 - h, 4, h), Color(str(cd.get("color", "4f9a3a"))))
			if frac >= 1.0:
				ci.draw_circle(Vector2(c.x * TILE + 8, (c.y + 1) * TILE - 4 - h), 3.0, col)


## A texture stretched into `dst` with fixed borders (margins in texture px; drawn at half size).
func _nine(ci: CanvasItem, t: Texture2D, dst: Rect2, ml: float, mt: float, mr: float, mb: float) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var xs := [0.0, ml, tw - mr, tw]
	var ys := [0.0, mt, th - mb, th]
	var dx := [dst.position.x, dst.position.x + ml * 0.5, dst.end.x - mr * 0.5, dst.end.x]
	var dy := [dst.position.y, dst.position.y + mt * 0.5, dst.end.y - mb * 0.5, dst.end.y]
	for yi in 3:
		for xi in 3:
			ci.draw_texture_rect_region(t, Rect2(dx[xi], dy[yi], dx[xi + 1] - dx[xi], dy[yi + 1] - dy[yi]), Rect2(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))


## A bed cell as four quarters of the 3x3 tilled painting (rounded rims), like the farm's.
func _bed_tile(ci: CanvasItem, name: String, c: Vector2i, tilled: Dictionary) -> bool:
	var t := Art.tex("tiles", name)
	if t == null or t.get_width() < 96:
		return false
	var cw := t.get_width() / 3.0
	var ch := t.get_height() / 3.0
	for q in 4:
		var qx := q % 2
		var qy := q / 2
		var hx := tilled.has(c + Vector2i(-1 if qx == 0 else 1, 0))
		var hy := tilled.has(c + Vector2i(0, -1 if qy == 0 else 1))
		var col := 1 if hx else (0 if qx == 0 else 2)
		var row := 1 if hy else (0 if qy == 0 else 2)
		var src := Rect2(col * cw + qx * cw / 2.0, row * ch + qy * ch / 2.0, cw / 2.0, ch / 2.0)
		ci.draw_texture_rect_region(t, Rect2(Vector2(c * TILE) + Vector2(qx, qy) * (TILE / 2.0), Vector2(TILE, TILE) / 2.0), src)
	return true


# ---- building the place ------------------------------------------------------------

func after_ready() -> void:
	if not GameState.run["flags"].has("cf_intro"):
		GameState.run["flags"]["cf_known"] = true  # walked in before the letter: Hazel's here on schedule to greet you
	WorldGen.add_backdrop(self, "hills")
	var s := _s()
	_plots = Node2D.new()
	_plots.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_plots.position = Vector2(offset().x, 0.5)  # just over the ground in the y-sort, under every prop and person
	_plots.draw.connect(func() -> void:
		_plots.draw_set_transform(Vector2(0, offset().y - 0.5))
		_draw_plots(_plots))
	add_child(_plots)
	# Stage 0: the junk on the lot.
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		if str(t.get("type", "")) == "cf_debris":
			var j: Array = JUNK[str(t["kind"])]
			var sc := 0.5 if str(j[0]) == "nature" else 0.42
			prop(str(j[0]), str(j[1]), c, 0, 0.0, true, sc)
	_place_board()
	_place_shed(s)
	_place_well(s)
	_place_greenhouse(s)
	_place_market(s)
	_place_extras(s)
	var young := s >= 6 and int(GameState.run["day"]) - int(GameState.run["flags"].get("cf_orchard_day", -99)) < 7
	for o: Array in Commons.data().get("orchard", []):
		var oc := Vector2i(int(o[0]), int(o[1]))
		if s >= 6 and not young:
			WorldGen.fruit_tree(self, oc, str(o[2]))
		elif young:
			prop("props", "cf_sapling", oc)  # the first week: staked saplings
			set_thing(oc.x, oc.y, {"type": "cf_note", "text": "A staked %s sapling, tied with twine. Give it a week to settle in." % str(o[2]), "hint": "A: the sapling"})
		elif s >= 1:
			prop("props", "cf_hole", oc, 0, 0.0, false)  # dug and staked, waiting on the orchard stage
	if s >= 6:
		for c: Vector2i in [Vector2i(3, 34), Vector2i(38, 37)]:
			prop("props", "beehive", c)
	_dress()
	_place_people()
	Commons.sync_quest()
	if GameState.run["flags"].has("cf_reveal"):
		later(_reveal)
	elif not GameState.run["flags"].has("community_farm_seen") or not GameState.run["flags"].has("cf_intro"):
		later(_first_visit)


func _place_board() -> void:
	prop("props", "notice_board" if Art.has("props", "notice_board") else "board", BOARD, 1)
	for x in range(BOARD.x, BOARD.x + 2):
		set_thing(x, BOARD.y, {"type": "cf_board", "hint": "A: the community board"})


func _place_shed(s: int) -> void:
	if s >= 2:
		prop("props", "shed", SHED, 2)
		prop("props", "cf_compost", Vector2i(23, 8))
		set_thing(23, 8, {"type": "cf_compost", "hint": "A: the compost"})
		prop("props", "chest_closed", Vector2i(31, 8))
		set_thing(31, 8, {"type": "cf_share", "hint": "A: your share crate"})
		prop("props", "farm_cart", Vector2i(20, 9))
		prop("props", "barrel_a", Vector2i(30, 6))
		prop("props", "crates_a", Vector2i(32, 7), 0, 0.0, true, 0.45)
		prop("props", "bucket", Vector2i(25, 9), 0, 0.0, false)
	else:
		prop("props", "cf_shed_ruin", SHED, 2)
		prop("props", "wood_fence_pile", Vector2i(30, 8), 0, 0.0, false)
	for x in range(SHED.x, SHED.x + 3):
		set_thing(x, SHED.y, {"type": "cf_shed", "hint": "A: the tool shed" if s >= 2 else "A: the old shed"})


func _place_well(s: int) -> void:
	prop("props", "well_roofed" if s >= 5 else "cf_well_broken", WELL, 1)
	for x in range(WELL.x, WELL.x + 2):
		set_thing(x, WELL.y, {"type": "cf_well", "hint": "A: drink from the well" if s >= 5 else "A: the old well"})
	if s >= 5:
		prop("props", "trough", Vector2i(31, 18))
		prop("props", "bucket", Vector2i(27, 20), 0, 0.0, false)


func _place_greenhouse(s: int) -> void:
	if s >= 7:
		prop("props", "greenhouse", GREENHOUSE, 3)
		for x in range(GREENHOUSE.x + 1, GREENHOUSE.x + 3):
			set_thing(x, GREENHOUSE.y, {"type": "cf_greenhouse", "hint": "A: the greenhouse"})
		for c: Vector2i in [Vector2i(36, 10), Vector2i(43, 10)]:
			prop("props", "planter2_%d" % (c.x % 4), c, 0, 0.0, true, 0.32)
	elif s >= 1:
		prop("props", "wood_fence_pile", Vector2i(39, 8), 0, 0.0, false)
		set_thing(39, 9, {"type": "cf_note", "text": "Stone footings, laid square. A greenhouse will stand here one day: it's on the board, near the end.", "hint": "A: the footings"}, false)


func _place_market(s: int) -> void:
	if s >= 7 + 1:
		prop("props", "stall2_red" if _gang() else "stall2_green", STAND, 4)
		for x in range(STAND.x, STAND.x + 5):
			set_thing(x, STAND.y, {"type": "cf_stand", "hint": "A: the market stand"})
		prop("props", "stall2_yellow", Vector2i(34, 26), 4)
		for x in range(34, 39):
			set_thing(x, 26, {"type": "cf_stand", "hint": "A: the market stand"})
		prop("props", "flower_cart", Vector2i(47, 25), 1, 0.0, true, 0.4)
		prop("props", "bunting_green", Vector2i(38, 23), 2, 0.0, false, 0.45)
		prop("props", "lanterns_pink" if _gang() else "lanterns_red", Vector2i(46, 23), 1, -18.0, false)
		prop("props", "apple_bucket2", Vector2i(46, 27), 0, 0.0, true, 0.28)
		prop("props", "hay", Vector2i(33, 29))
		if Commons.market_day():
			prop("props", "wheat_sheaf", Vector2i(40, 29), 0, 0.0, true, 0.28)
			prop("props", "carrot_bunch", Vector2i(32, 27), 0, 0.0, true, 0.26)
			prop("props", "bunting_red", Vector2i(32, 23), 2, 0.0, false, 0.45)
	if s >= 3:
		prop("props", "cf_donation_box", Vector2i(48, 27))
		set_thing(48, 27, {"type": "cf_donate", "hint": "A: the donation box"})
	if s >= 7 + 1:
		prop("props", "cf_crates", Vector2i(39, 29), 1, 0.0, true, 0.45)
		if Commons.market_day():
			prop("props", "cf_crates", Vector2i(44, 29), 1, 0.0, true, 0.45)
	elif s >= 3:
		prop("props", "cart_full", Vector2i(42, 26), 1)
		for x in range(42, 44):
			set_thing(x, 26, {"type": "cf_stand", "hint": "A: the produce stand"})
		prop("props", "signpost_2", Vector2i(45, 26))
		things[Vector2i(45, 26)] = {"type": "cf_note", "text": "Community produce. Pay what's marked, give what you can.", "hint": "A: read"}


func _place_extras(s: int) -> void:
	if _gang():
		# The lot's back wall, with the neighbourhood's art on it, and the chain-link gate.
		# The lot's back wall: plain brick, the neighbourhood's tags, and (once the beds are in) the garden mural.
		for x in range(3, 47, 7):
			var mural := s >= 3 and (x / 7) % 2 == 1
			if mural:
				prop("props", "cf_mural_wall", Vector2i(x, 2), 5)
			else:
				for k in 3:
					prop("props", "low_wall_a", Vector2i(x + 2 * k, 2), 1, 0.0, true, 0.55)
			if not mural and (x / 7) % 3 == 0:
				prop("props", "graffiti_%d" % ((x / 7) % 6), Vector2i(x + 1, 2), 0, -4.0, false, 0.45)
		for y in [17, 22]:
			for x in [47, 49]:
				prop("props", "chain_fence_h", Vector2i(x, y), 1, 0.0, true, 0.5)
		if s < 2:
			prop("props", "dumpster", Vector2i(34, 9))
	else:
		for x in [46, 49]:
			prop("props", "fence2_wood_h", Vector2i(x, 17), 1)
			prop("props", "fence2_wood_h", Vector2i(x, 22), 1)
	if s >= 1:
		prop("props", "cf_picnic_table", Vector2i(35, 33), 2)
		prop("props", "bench2_wood_a", Vector2i(41, 33), 2, 0.0, true, 0.4)
		if Art.has("props", "campfire_cook"):
			anim_prop("props", "campfire_cook", Vector2i(38, 35), 0, 6.0, true)
		prop("props", "bench_wood", Vector2i(33, 17), 1)
	if s >= 3:
		prop("props", "scarecrow_field" if not _gang() else "scarecrow_b", Vector2i(12, 15))
		prop("props", "sprinkler_basic" if s >= 5 and Art.has("props", "sprinkler_basic") else "bucket", Vector2i(12, 24), 0, 0.0, true, 0.4)
	if s >= 4:
		prop("props", "trellis", Vector2i(5, 28), 3, 0.0, true, 0.45)
		prop("props", "trellis", Vector2i(15, 28), 3, 0.0, true, 0.45)
	if s >= 2:
		for c: Vector2i in [Vector2i(33, 13), Vector2i(22, 28)]:
			prop("props", "flowerbed_yellow" if c.x > 30 else "flowerbed_pink", c, 0, 0.0, true, 0.4)


## Trees and undergrowth round the edges (never on the beds, paths or yards).
func _dress() -> void:
	var avoid := _busy.duplicate()
	for e in exits:
		for c in cells_of([(e["rect"] as Rect2i).grow(3)]):
			avoid[c] = true
	for sp: Vector2i in Commons.spots().values():
		for c in cells_of([Rect2i(sp.x - 1, sp.y - 1, 3, 3)]):
			avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(0, 0, 20, 12), 1741, 5, avoid)
	WorldGen.tree_clumps(self, Rect2i(44, 0, 8, 14), 1742, 3, avoid)
	WorldGen.tree_clumps(self, Rect2i(0, 26, 4, 14), 1743, 2, avoid)
	WorldGen.tree_clumps(self, Rect2i(46, 30, 6, 10), 1744, 3, avoid)
	WorldGen.scatter_props(self, Rect2i(0, 0, cols, rows), 1745, 12, avoid)
	WorldGen.dress_band(self, 1746)
	var kinds := ["butterfly_orange", "butterfly_blue", "butterfly_yellow", "bee", "sparrow"]
	kinds += ["rabbit"] if not _gang() else ["sparrow"]
	if _s() >= 6:
		kinds += ["bee", "bee", "butterfly_yellow"]
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 1747, 8 + _s(), kinds)


# ---- volunteers ----------------------------------------------------------------------

func _place_people() -> void:
	var who := {}
	for e: Array in Commons.data().get("schedule", []) + Commons.data().get("market_day", []):
		who[str(e[0])] = true
	var sp := Commons.spots()
	for id: String in who:
		var d: Dictionary = GameState.npcs.get(id, {})
		if d.is_empty() or not GameState.npc_present(id) or (d.get("routine", []) as Array).is_empty():
			continue
		var n := Npc.new()
		n.map = self
		n.routine = d.get("routine", [])
		n.spots = sp
		n.spots_only = true
		n.wander = 14.0
		n.setup(id, d, cell_center(sp["cf_lot"]))
		add_child(n)
		npcs.append(n)


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.visible and n.cell() == c:
			return true
	return false


func _process(delta: float) -> void:
	super(delta)
	if _changing or player == null:
		return
	_job_t -= delta
	for n: Npc in _jobs.keys():
		var jb: Array = _jobs[n]
		jb[1] = float(jb[1]) + delta
		var p := (jb[0] as String).split(",")
		var c := Vector2i(int(p[0]), int(p[1]))
		if not is_instance_valid(n) or not n.visible:
			_jobs.erase(n)
		elif n.position.distance_to(cell_center(c)) < 12.0 or float(jb[1]) > 9.0:
			_jobs.erase(n)
			if Commons.ripe(Commons.plot(str(jb[0]))):
				Commons.harvest(str(jb[0]))
				n.set_pose("carry")
				emote(n, "happy", 1.0, -30.0)
				if player.position.distance_to(n.position) < 140.0:
					Music.instance(get_tree()).sfx("harvest", "pickup")
				_plots.queue_redraw()
			n.home = cell_center(Commons.spots().get(_spot_of(n), n.cell()))
			n._target = n.home
	if _job_t > 0.0:
		return
	_job_t = 2.0
	# A volunteer at the beds with nothing to do picks the nearest ripe crop.
	for n: Npc in npcs:
		if not n.visible or _jobs.has(n) or n.activity != "farm" or n._chat_partner != null:
			continue
		var best := ""
		var bd := 40.0
		for key: String in _cells:
			if not Commons.ripe(Commons.plot(key)):
				continue
			var p := key.split(",")
			var dd := Vector2(int(p[0]), int(p[1])).distance_to(Vector2(n.cell()))
			if dd < bd and not _taken(key):
				bd = dd
				best = key
		if best != "":
			var p2 := best.split(",")
			_jobs[n] = [best, 0.0]
			n._path = find_path(n.cell(), Vector2i(int(p2[0]), int(p2[1])))
			break


func _taken(key: String) -> bool:
	for n: Npc in _jobs:
		if str(_jobs[n][0]) == key:
			return true
	return false


func _spot_of(n: Npc) -> String:
	return Npc.place_now(n.routine, n.id)


# ---- interacting ---------------------------------------------------------------------

func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if not n.visible:
			continue
		if n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0):
			later(_talk.bind(n))
			return true
	match str(thing.get("type", "")):
		"cf_debris":
			_clear_debris(c, thing)
			return true
		"cf_board":
			later(Commons.open_board.bind(self))
			return true
		"cf_stand":
			later(Commons.open_stand.bind(self))
			return true
		"cf_donate":
			later(Commons._donate.bind(self))
			return true
		"cf_share":
			Commons.collect_share(self)
			return true
		"cf_compost":
			later(Commons.compost.bind(self))
			return true
		"cf_well":
			if _s() >= 5:
				Commons.drink(self)
			else:
				tell([{"text": "The old well. Boarded over, the rope long gone, the pump rusted solid. It's on the board: stone, copper and rope would bring it back."}])
			return true
		"cf_shed":
			if _s() >= 2:
				tell([{"text": "Rakes on hooks, hoes in a row, a chalk list of who borrowed what. %s's handwriting: 'BRING IT BACK CLEAN.'" % Commons.keeper_name()}])
			else:
				tell([{"text": "Half a roof, one and a half walls. The tools inside have rusted into one sculpture."}])
			return true
		"cf_greenhouse":
			var frames := 0
			for key: String in _cells:
				if bool(_cells[key]) and str(Commons.plot(key).get("crop", "")) != "":
					frames += 1
			tell([{"text": "Warm, damp air and the smell of tomatoes. Juniper's herbs line the benches. %d cold-frame bed%s growing out front%s." % [frames, "" if frames == 1 else "s", ", snow or no snow" if GameState.season() == "winter" else ""]}])
			return true
		"cf_note":
			tell([{"text": str(thing.get("text", ""))}])
			return true
		"cf_plot":
			_plot_action(c, thing)
			return true
	return false


func hint_for(c: Vector2i, thing: Dictionary) -> String:
	if str(thing.get("type", "")) == "cf_plot":
		var p := Commons.plot(str(thing["key"]))
		if Commons.ripe(p):
			return "A: help harvest"
		if GameState.held_tool() == "can" and str(p.get("crop", "")) != "" and not bool(p.get("w", false)) and not GameState.sky_waters() and _s() < 5:
			return "A: water"
		return "A: the bed"
	return super(c, thing)


func _clear_debris(c: Vector2i, thing: Dictionary) -> void:
	if Net.visiting():
		hud.toast("Your host's lot: they'll clear it.", Color(1, 0.85, 0.7))
		return
	var kind := str(thing["kind"])
	var j: Array = JUNK[kind]
	var tool := str(j[2])
	var held := GameState.held_tool()
	if tool != "" and held != tool:
		ToolHint.need(self, tool, "to clear it")
		return
	if tool == "" and ToolHint.is_soft(held):
		ToolHint.say(self, "Clear it by hand or with a blade.")
		return
	if not GameState.spend_for(tool if tool != "" else "weed"):
		return
	player.play_tool(tool if tool != "" else "hold")
	Music.instance(get_tree()).sfx({"axe": "chop", "pickaxe": "rock_break"}.get(tool, "thud"), "thud")
	thing["hp"] = int(thing["hp"]) - 1
	if int(thing["hp"]) > 0:
		wobble(c, 0.1)
		return
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)
	fx("dust_puff", cell_center(c), 12.0, 0.5)
	(Commons.st()["cleared"] as Dictionary)[str(thing["key"])] = true
	if str(j[4]) == "":
		GameState.run["crystals"] = int(GameState.run["crystals"]) + int(j[5])
		hud.toast("The scrap dealer pays ◆%d for those." % int(j[5]), Color(1, 0.9, 0.5))
	else:
		pop_items(cell_center(c), str(j[4]), int(j[5]))
	xp("foraging", 4)
	var left := int(Commons.st().get("debris_left", 1)) - 1
	Commons.st()["debris_left"] = left
	if left > 0:
		hud.toast("%d more to clear." % left, Color(0.9, 1, 0.85))
		return
	later(_lot_cleared)


func _lot_cleared() -> void:
	player.frozen = true
	await say([{"who": Commons.keeper_name(), "text": str(Commons.tx(Commons.stages()[0]["done"]))}])
	player.frozen = false
	Commons.finish_stage(self)


func _plot_action(c: Vector2i, thing: Dictionary) -> void:
	var key := str(thing["key"])
	var p := Commons.plot(key)
	var cd: Dictionary = GameState.crops.get(str(p.get("crop", "")), {})
	if Commons.ripe(p):
		if Net.visiting():
			hud.toast("Your host's beds. Their volunteers will pick it.", Color(1, 0.85, 0.7))
			return
		var yid := Commons.harvest(key)
		player.play_tool("hold")
		Music.instance(get_tree()).sfx("harvest", "pickup")
		pop_items(cell_center(c), yid, 1)  # a handful for your trouble; the rest goes to the stand
		GameState.add_friend(Commons.keeper(), 1)
		xp("farming", 3)
		_plots.queue_redraw()
		return
	if GameState.held_tool() == "can" and not cd.is_empty() and not bool(p.get("w", false)) and not GameState.sky_waters() and _s() < 5:
		if not GameState.spend_for("can"):
			return
		player.play_tool("water")
		Music.instance(get_tree()).sfx("splash", "pickup")
		p["w"] = true
		xp("farming", 1)
		_plots.queue_redraw()
		return
	if cd.is_empty():
		hud.toast("Resting till spring. The cold frames by the greenhouse keep growing." if GameState.season() == "winter" and _s() >= 7 else ("Resting till spring." if GameState.season() == "winter" else ("Empty: the volunteers plant at dawn." if _s() >= 4 else "Raised and ready. It needs seeds: see the board.")), Color(0.95, 0.9, 0.8))
		return
	var left := ceili(float(cd["days"]) - float(p.get("days", 0)))
	hud.toast("%s: about %d day%s to go.%s" % [str(cd.get("name", "")), left, "" if left == 1 else "s", " Watered." if bool(p.get("w", false)) or GameState.sky_waters() or _s() >= 5 else " Dry (water it to speed it up)."], Color(0.9, 1, 0.85))


func _talk(n: Npc) -> void:
	emote(n, "talk", 1.0, -30.0)
	var id := n.id
	var name := str(GameState.npcs[id]["name"])
	player.frozen = true
	n.face(player.position)
	var talked: Dictionary = GameState.run["talked_today"]
	if not talked.has(id):
		talked[id] = true
		GameState.add_friend(id, 5)
	if await Quests.talk(self, id, name):
		player.frozen = false
		return
	var sel := str(GameState.run["selected"])
	if GameState.can_gift(id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(id, sel)
		await say([{"who": name, "text": gift_reaction(name, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	if id == Commons.keeper():
		if not GameState.run["flags"].has("cf_met"):
			GameState.run["flags"]["cf_met"] = true
			GameState.run["flags"]["cf_board_seen"] = true
			await say([{"who": name, "text": str(Commons.tx(Commons.data()["intro"]))}])
			Commons.sync_quest()
		elif Commons.complete():
			await say([{"who": name, "text": "Look at it. Every bed full, the trees fruiting, half the town here on market day. Thank you, really." if not Commons.market_day() else "Market day! Go see what Posy brought. And sell at the stand, folks pay well today."}])
		else:
			var lines := Commons.need_lines()
			await say([{"who": name, "text": "Next up: %s. %s" % [Commons.stage_name(_s()).to_lower(), ("Still need: " + "; ".join(lines.slice(0, 3))) if not lines.is_empty() else ""]}])
	elif randf() < 0.55:
		await say([{"who": name, "text": Commons.work_line(n.activity)}])
	else:
		await say(Talk.line(id))
	player.frozen = false


# ---- arrival and reveals -----------------------------------------------------------------

func _first_visit() -> void:
	GameState.run["flags"]["community_farm_seen"] = true
	if GameState.run["flags"].has("cf_intro"):
		return
	GameState.run["flags"]["cf_intro"] = true
	GameState.run["flags"]["cf_known"] = true
	player.frozen = true
	if _gang():
		await say([{"text": "A vacant lot behind a tagged brick wall. Tyres, drums, a cart with no wheels. But under the junk, the ground is soft, and someone's been at the weeds by hand."}])
	else:
		await say([{"text": "An old commons, gone wild. Brambles over the beds, a well with no rope, a shed with half a roof. But there are fresh footprints, and someone's pulled the weeds round the gate."}])
	var hz: Npc = null
	for n: Npc in npcs:
		if n.id == Commons.keeper() and n.visible:
			hz = n
	if hz != null and not GameState.run["flags"].has("cf_met"):
		GameState.run["flags"]["cf_met"] = true
		GameState.run["flags"]["cf_board_seen"] = true
		hz.face(player.position)
		await say([{"who": Commons.keeper_name(), "text": str(Commons.tx(Commons.data()["intro"]))}])
	else:
		hud.toast("The board by the gate says what the place needs.", Color(1, 0.95, 0.8))
	Commons.sync_quest()
	player.frozen = false


## After a stage: show what changed and what it earned.
func _reveal() -> void:
	var s := int(GameState.run["flags"].get("cf_reveal", 0))
	var got := str(GameState.run["flags"].get("cf_reveal_got", ""))
	GameState.run["flags"].erase("cf_reveal")
	GameState.run["flags"].erase("cf_reveal_got")
	player.frozen = true
	await get_tree().create_timer(0.4).timeout
	fx("levelup", player.position + Vector2(0, -12), 10.0, 0.9)
	Music.instance(get_tree()).sfx("j_victory", "quest_done")
	var lines: Array = [{"text": "%s: done! (stage %d of %d)\n%s" % [Commons.stage_name(s), s + 1, Commons.stages().size(), got]}]
	if s + 1 < Commons.stages().size():
		lines.append({"who": Commons.keeper_name(), "text": "Next: %s. It's on the board." % Commons.stage_name(s + 1).to_lower()})
	else:
		Music.instance(get_tree()).play("festival")
		lines.append({"who": "Mayor Alder" if not _gang() else "Sal", "text": "Friends! Neighbours! A year ago this was brambles and junk. Today it feeds us. Eat, buy, trade, and come back next week." if not _gang() else "Listen up. This block used to be where things got dumped. Now it's where we eat. Every week. Spread the word."})
		lines.append({"who": Commons.keeper_name(), "text": "From now on, the 7th, 14th, 21st and 28th are market days. Sell at the stand: folks pay a quarter over the shipping box."})
	await say(lines)
	GameState.save()
	player.frozen = false
