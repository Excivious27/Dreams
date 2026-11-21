extends GameMap
## Data-driven region map. A scene sets `region_id` and the layout comes from
## data/regions.json: size, ground, paths, props, buildings, enemies, exits, a
## landmark, an intro line, and simple interactables. This is how every new
## region (wastes, districts, sky, station, jungle, sewers...) is built without a
## script each; story hooks still live in dialogue below.

@export var region_id := "wastes"
var R: Dictionary = {}
var _patch_memo := {}  # region patch cells, worked out on the first draw
var _anim_nodes: Array = []
var _water_cells := {}
var _forage_n := 0
var npcs: Array = []


## How tough this area's foes are. An enemy from an easier tier is brought up
## to the area's tier (never down), and one in ten comes as an elite a tier higher.
const AREA_TIER := {"orchard_hills": 1, "wastes": 1, "hideout": 1, "countryside": 1, "quarry": 2, "marsh": 2,
	"riverlands": 2, "highlands": 2, "docks": 2, "colony_coral": 2, "ruins": 3, "neon": 3, "uptown": 3, "jungle": 3,
	"colony_kelp": 3, "sky": 4, "station": 4, "underground": 4, "colony_ice": 4, "hollow_heart": 5, "colony_ember": 5}


const NO_FRUIT := ["hollow_heart", "wastes", "jungle", "quarry", "highlands", "station", "sky", "underground", "neon", "uptown", "docks", "hideout"]


var _rect_water := {}  # shore -> cells of painted water rects

## Fishing tier of this area's water (Fishing.T cap_per_area_tier, commons, treasure).
func fish_tier() -> int:
	return int(R.get("tier", AREA_TIER.get(region_id, 1)))


func _place_secrets() -> void:
	var lt := Secrets.loot_tier(int(R.get("tier", AREA_TIER.get(region_id, 1))), not (R.get("enemies", []) as Array).is_empty())
	Secrets.place(self, region_id, lt)
	var ha := HiddenArea.place(self, region_id, lt)
	if ha:
		for dc: Vector2i in Secrets.undug(self):
			ha.spots.append([dc, "cache"])
	_settle_enemies()
	_fix_access.call_deferred()
	_boss_markers()
	# Doors that are a hole or a ladder in the ground show it (manhole, sewer ladder).
	for c: Vector2i in things.keys():
		if str(things[c].get("type", "")) == "door" and things[c].has("sprite") and not props.has(c):
			var ds := prop("props", str(things[c]["sprite"]), c, 0, 0.0, false)
			if ds and str(things[c]["sprite"]).begins_with("manhole"):
				to_under(ds)


## Doors and "locked" reasons you can't reach get their front cell cleared, and a
## villager standing in a wall steps to the nearest open cell (CONDUCT 4).
func _fix_access() -> void:
	if player == null:
		return
	var start := world_to_cell(default_spawn() - Vector2(0, 2))
	var reach := HiddenArea._reach(self, start)
	if reach.size() < 8:
		return
	var near := func(c: Vector2i) -> bool:
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if reach.has(c + d):
				return true
		return false
	var changed := false
	for c: Vector2i in things.keys():
		if not str(things[c].get("type", "")) in ["locked", "door", "idoor", "shop"] or near.call(c) or reach.has(c):
			continue
		# Open the way straight down from the door to the nearest reachable cell (<= 3).
		for k in range(1, 4):
			var f := c + Vector2i(0, k)
			if not in_content(f) or is_water_cell(f) or things.has(f):
				break
			if reach.has(f):
				for j in range(1, k):
					blocked.erase(c + Vector2i(0, j))
					hard.erase(c + Vector2i(0, j))
				changed = true
				break
	if changed:
		_flows.clear()
		reach = HiddenArea._reach(self, start)
	for n: Npc in npcs:
		var nc := n.cell()
		if reach.has(nc) or near.call(nc):
			continue
		var best := Vector2i(-1, -1)
		var bd := INF
		for c: Vector2i in reach:
			var dd := float((c - nc).length_squared())
			if dd < bd and not things.has(c):
				bd = dd
				best = c
		if best.x >= 0:
			n.position = cell_center(best)
			if n.get("home") != null and n.get("home") is Vector2:
				n.set("home", n.position)


## Every foe stands where you can reach it: one spawned in a wall, a pond, a
## sealed hidden nook or a cell the late dressing filled is moved to the nearest
## reachable open cell (CONDUCT 4: enemies in blocked cells).
func _settle_enemies() -> void:
	if player == null or enemies.is_empty():
		return
	var reach := HiddenArea._reach(self, world_to_cell(default_spawn() - Vector2(0, 2)))
	if reach.size() < 8:
		return
	var cells: Array = reach.keys()
	for e in enemies:
		if not is_instance_valid(e) or (e as Node2D).has_meta("boss"):
			continue
		var ec := world_to_cell((e as Node2D).position - Vector2(0, 2))
		if reach.has(ec) and not is_water_cell(ec):
			continue
		var best := Vector2i(-1, -1)
		var bd := INF
		for c: Vector2i in cells:
			var dd := float((c - ec).length_squared())
			if dd < bd and not is_water_cell(c) and not things.has(c):
				bd = dd
				best = c
		if best.x >= 0:
			(e as Node2D).position = cell_center(best)


## Show who's waiting at a boss spot (a dim, still figure) until they're beaten,
## so a boss isn't an invisible wall.
func _boss_markers() -> void:
	if GameState.run["flags"].has("boss_%s" % region_id):
		return
	for c: Vector2i in things.keys():
		var t: Dictionary = things[c]
		if str(t.get("type", "")) != "boss":
			continue
		var gang := not GameState.is_penguins()
		var bk := str(t.get("kind_gangsters", t.get("kind", ""))) if gang else str(t.get("kind", ""))
		var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(bk, {})
		var grp := "enemies/" + str(ed.get("art", bk))
		if ed.has("char"):
			grp = "characters/" + str(ed["char"])
		elif bk.begins_with("thug_"):
			grp = "characters/" + bk.trim_prefix("thug_")
		var tex := Art.tex(grp, "idle")
		if tex == null:
			continue
		var info := Art.info(grp, "idle")
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, float(info.get("cell_w", tex.get_width())), tex.get_height())
		var sp := Sprite2D.new()
		sp.texture = at
		sp.scale = Vector2(0.5, 0.5)
		sp.offset = Vector2(0, -tex.get_height() / 2.0)
		sp.position = cell_center(c)
		sp.modulate = Color(0.55, 0.5, 0.65, 0.9)
		if ed.has("tint"):
			sp.self_modulate = Color(str(ed["tint"]))
		add_child(sp)
		if t.get("hint", "") == "":
			t["hint"] = "A: face it"


func _spawn_tier(kind: String) -> int:
	var at := int(R.get("tier", AREA_TIER.get(region_id, -1)))
	if at < 0:
		return -1
	var t := maxi(at, GameState.enemy_tier(kind))
	if randf() < 0.1:
		t = mini(5, t + 1)
	return t if t != GameState.enemy_tier(kind) else -1


func scene_id() -> String:
	return region_id


## Regions can name their cliff and stair look ("cliff_style": ["snow", "stair_snow"]).
func cliff_style() -> Array:
	if R.has("cliff_style"):
		return R["cliff_style"]
	return super()


func default_spawn() -> Vector2:
	var s: Array = R.get("spawn", [2, 2])
	var c := Vector2i(int(s[0]), int(s[1]))
	# At least 3 cells inside any exit strip, so arriving never sits on a way out.
	for step in 4:
		var moved := false
		for e in exits:
			var er: Rect2i = e["rect"]
			if not er.grow(2).has_point(c):
				continue
			var inw := Vector2i(1 if er.position.x <= 0 else (-1 if er.end.x >= cols else 0), 1 if er.position.y <= 0 else (-1 if er.end.y >= rows else 0))
			if inw != Vector2i.ZERO and not blocked.has(c + inw):
				c += inw
				moved = true
		if not moved:
			break
	return cell_center(c)


func build() -> void:
	R = RegionData.region(region_id).duplicate(true)  # parsed once per session (RegionData)
	GameState.look_season = str(R.get("season", ""))
	cols = int(R.get("cols", 30))
	rows = int(R.get("rows", 26))
	music_track = str(R.get("music", "meadow"))
	if R.has("music_fallback") and not Music.has_track(music_track):
		music_track = str(R["music_fallback"])  # a new area song not imported yet
	has_sky = bool(R.get("sky", true))
	has_pet = bool(R.get("pet", true))
	pad = int(R.get("pad", 5))
	border = R.get("border", "trees")
	for e in R.get("exits", []):
		var r: Array = e["rect"]
		add_exit(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), str(e["scene"]), Vector2(float(e["spawn"][0]) * TILE, float(e["spawn"][1]) * TILE), str(e.get("facing", "down")), str(e.get("label", "")))
	for b in R.get("blocks", []):
		block_rect(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
	# Battle maps: lanes (paths) cross water as causeways and cut through high ground.
	var lane_cells := {}
	if R.has("battle"):
		for pr in R.get("paths", []):
			for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
				for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
					lane_cells[Vector2i(x, y)] = true
	# Noise-shaped water bodies: {"c": [x, y], "r": radius, "seed": n, "shore": "grass"|"sand", "fish": [...]}
	for wb in R.get("water_blobs", []):
		var cx := float(wb["c"][0])
		var cy := float(wb["c"][1])
		var rad := float(wb.get("r", 5))
		var sdv := int(wb.get("seed", 1))
		var cells := {}
		for y in range(int(cy - rad - 3), int(cy + rad + 4)):
			for x in range(int(cx - rad - 3), int(cx + rad + 4)):
				if x < 1 or y < 1 or x >= cols - 1 or y >= rows - 1:
					continue
				var n := WorldGen.fbm(float(x), float(y), sdv, 5.0)
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
					cells[Vector2i(x, y)] = true
		for pass_i in 2:
			var add := {}
			var drop := {}
			for c: Vector2i in cells.keys():
				pass
			for y in range(int(cy - rad - 3), int(cy + rad + 4)):
				for x in range(int(cx - rad - 3), int(cx + rad + 4)):
					var c := Vector2i(x, y)
					var wn := 0
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if cells.has(c + d):
							wn += 1
					if not cells.has(c) and wn >= 3:
						add[c] = true
					elif cells.has(c) and wn <= 1:
						drop[c] = true
			for c: Vector2i in add:
				cells[c] = true
			for c: Vector2i in drop:
				cells.erase(c)
		for c: Vector2i in cells:
			if lane_cells.has(c):
				continue
			set_thing(c.x, c.y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": wb.get("fish", []), "shore": str(wb.get("shore", "grass"))})
			_water_cells[c] = true
	# Islands: everything that isn't island is sea (colony maps).
	if R.has("islands"):
		var land := {}
		for bl in R["islands"]:
			var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 8)); var sdv := int(bl.get("seed", 3))
			for y in range(int(cy - rad - 4), int(cy + rad + 5)):
				for x in range(int(cx - rad - 4), int(cx + rad + 5)):
					var n := WorldGen.fbm(float(x), float(y), sdv, 7.0)
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
						land[Vector2i(x, y)] = true
		for pr in R.get("paths", []):
			for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
				for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
					land[Vector2i(x, y)] = true  # sand bars along the paths
		for t in R.get("things", []):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					land[Vector2i(int(t["cell"][0]) + dx, int(t["cell"][1]) + dy)] = true
		var sp: Array = R.get("spawn", [2, 2])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				land[Vector2i(int(sp[0]) + dx, int(sp[1]) + dy)] = true
		for e in exits:
			for c in cells_of([e["rect"]]):
				land[c] = true
				land[c + Vector2i(0, -1)] = true
		for y in range(0, rows):
			for x in range(0, cols):  # to the edge: no grass rim between island sea and border sea
				var c := Vector2i(x, y)
				if not land.has(c) and not things.has(c):
					set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": R.get("fish", Fishing.T["sea_pool"]), "shore": str(R.get("island_shore", "sand"))})
					_water_cells[c] = true
	# Painted water rects ("water": [{"rect": [x, y, w, h], "fish": [...]}]) are real
	# water too: no walking on the sea, and you can fish off the dock.
	for wr in R.get("water", []):
		var rr: Array = wr.get("rect", [])
		if rr.size() < 4:
			continue
		for y in range(int(rr[1]), int(rr[1]) + int(rr[3])):
			for x in range(int(rr[0]), int(rr[0]) + int(rr[2])):
				if x < 0 or y < 0 or x >= cols or y >= rows or things.has(Vector2i(x, y)):
					continue
				var wsh := str(wr.get("shore", "sand"))
				set_thing(x, y, {"type": "water", "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": wr.get("fish", R.get("fish", [])), "shore": wsh})
				blocked[Vector2i(x, y)] = true
				if not _rect_water.has(wsh):
					_rect_water[wsh] = {}
				_rect_water[wsh][Vector2i(x, y)] = true
	# A water border joins the map's own water into one body (one shore look).
	var water_border := false
	if border is Dictionary:
		water_border = "water" in (border as Dictionary).values()
	else:
		water_border = str(border) == "water"
	if water_border:
		var bsh := str(R.get("border_water_shore", ""))
		if bsh == "":
			if R.has("islands"):
				bsh = str(R.get("island_shore", "sand"))
			elif _rect_water.has("sand"):
				bsh = "sand"
			elif str(R.get("patch_set", "")) == "bog":
				bsh = "bog"
			else:
				bsh = "grass"
		border_water_shore = bsh
		if _rect_water.has(bsh):
			border_water_extra.merge(_rect_water[bsh])
			_rect_water.erase(bsh)
		if R.has("islands"):
			border_water_extra.merge(_water_cells)  # one sea, one shore look
	# Forage spots from data/forage.json (respawn every 2 days, 1 with Tracker).
	var fcount := int(R.get("forage", 0))
	if fcount > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region_id) % 1000 + 9 + int(GameState.run["day"]) / 7
		for i in fcount * 3:
			if _forage_n >= fcount:
				break
			var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(2, rows - 3))
			if things.has(c) or blocked.has(c):
				continue
			var key := "forage_%s_%d_%d" % [region_id, c.x, c.y]
			var item := GameState.roll_forage(region_id)
			# Respawn: common forage every 1-2 days, rare finds take most of a week.
			var tier := int(GameState.items.get(item, {}).get("tier", 1))
			var every := (1 if GameState.has_perk("foraging", "Tracker") else 2) + maxi(0, tier - 1) * 2
			if not GameState.respawned(key, every):
				continue
			things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick %s" % GameState.item_name(item)}
			_forage_n += 1
	# Elevation: plateaus (each a set of noise blobs), drawn as cliffs with ramps.
	for pl in R.get("plateaus", []):
		var pc := {}
		for bl in pl.get("blobs", []):
			var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 6)); var sdv := int(bl.get("seed", 7))
			for y in range(int(cy - rad - 3), int(cy + rad + 4)):
				for x in range(int(cx - rad - 3), int(cx + rad + 4)):
					if x < 2 or y < 2 or x >= cols - 2 or y >= rows - 3:
						continue
					var n := WorldGen.fbm(float(x), float(y), sdv, 6.0)
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.3 <= rad:
						pc[Vector2i(x, y)] = true
		# Smooth: no one-cell notches (they draw as broken cliff pieces).
		for pass_i in 2:
			var nx := pc.duplicate()
			for c: Vector2i in pc:
				var nb := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if pc.has(c + d):
						nb += 1
				if nb <= 1:
					nx.erase(c)
			pc = nx
		if lane_cells.is_empty():
			if not pl.has("upper"):
				add_plateau(pc, pl.get("ramps", []))
				continue
			# Tiered hills (new layouts): kept off exits, paths and placed things,
			# with a cell of room, so every road, door and pickup stays reachable.
			var b0: Dictionary = pl["blobs"][0]
			pc = WorldGen.mesa(self, Vector2(float(b0["c"][0]), float(b0["c"][1])), float(b0.get("r", 6)), float(b0.get("ry", float(b0.get("r", 6)) * 0.8)), int(b0.get("seed", 7)), 3)
			var keep := {}
			for e in exits:
				keep.merge(cells_of([(e["rect"] as Rect2i).grow(3)]))
			for pr in R.get("paths", []):
				keep.merge(cells_of([Rect2i(int(pr[0]) - 2, int(pr[1]) - 2, int(pr[2]) + 4, int(pr[3]) + 4)]))
			for t in R.get("things", []):
				keep.merge(cells_of([Rect2i(int(t["cell"][0]) - 2, int(t["cell"][1]) - 2, 5, 5)]))
			for c: Vector2i in _water_cells:
				keep.merge(cells_of([Rect2i(c.x - 1, c.y - 1, 3, 3)]))
			var sp0: Array = R.get("spawn", [2, 2])
			keep.merge(cells_of([Rect2i(int(sp0[0]) - 3, int(sp0[1]) - 3, 7, 7)]))
			for c: Vector2i in keep:
				pc.erase(c)
			pc = WorldGen.smooth_cells(pc)
			var big := {}
			for part: Dictionary in _components(pc):
				if part.size() > big.size():
					big = part
			if big.size() >= 12:
				var rmp: Array = pl.get("ramps", []).filter(func(r: Array) -> bool: return big.has(Vector2i(int(r[0]), int(r[1]))))
				add_plateau(big, rmp if not rmp.is_empty() else WorldGen.pick_ramps(self, big))
				_upper_tier(big, pl)
			continue
		for c: Vector2i in lane_cells:
			pc.erase(c)
			pc.erase(c + Vector2i(0, -1))  # the rock face goes on the row below the plateau: keep it off the lane
		# The lanes may cut it in pieces: each piece gets its own ramp; slivers go.
		for part: Dictionary in _components(pc):
			if part.size() >= 8:
				add_plateau(part, pl.get("ramps", []).filter(func(r: Array) -> bool: return part.has(Vector2i(int(r[0]), int(r[1])))))
	if int(R.get("fruit", 0 if region_id in NO_FRUIT else 3)) > 0:
		var pav := {}  # keep fruit trees off the paths (and one cell either side)
		for pl: Dictionary in plateaus:
			for st: Vector2i in pl["stairs"]:
				pav.merge(cells_of([Rect2i(st.x - 1, st.y - 2, 3, 5)]))
		for pr in R.get("paths", []):
			for y in range(int(pr[1]) - 1, int(pr[1]) + int(pr[3]) + 1):
				for x in range(int(pr[0]) - 1, int(pr[0]) + int(pr[2]) + 1):
					pav[Vector2i(x, y)] = true
		WorldGen.fruit_trees(self, Rect2i(3, 3, cols - 6, rows - 6), hash(region_id) % 500 + 3, int(R.get("fruit", 3)), pav)
	for t in R.get("things", []):
		var c: Array = t["cell"]
		if str(t["type"]) == "mrock" and not GameState.respawned(mrock_key(Vector2i(int(c[0]), int(c[1]))), mrock_every(t)):
			continue  # broken: grows back after `every` days (CONDUCT 4)
		var d := {"type": str(t["type"]), "hint": str(t.get("hint", ""))}
		for k in t:
			if not k in ["cell", "solid"]:
				d[k] = t[k]
		set_thing(int(c[0]), int(c[1]), d, bool(t.get("solid", true)))


## A second, higher tier on a plateau ("upper": [blobs], optional "upper_ramps").
## It sits inset on the lower top (2 cells in from the sides and north, 4 from
## the south) so its rock face and stairs land on open ground, not on the rim.
## Exit strip cells with a path within 3 cells inward (GameMap._build_border opens
## only these through a void band).
func exit_lanes(r: Rect2i) -> Rect2i:
	var pcs := {}
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				pcs[Vector2i(x, y)] = true
	var inw := Vector2i(1 if r.position.x <= 0 else (-1 if r.end.x >= cols else 0), 1 if r.position.y <= 0 else (-1 if r.end.y >= rows else 0))
	var out := Rect2i()
	for c: Vector2i in cells_of([r]):
		for k in range(0, 4):
			if pcs.has(c + inw * k):
				out = Rect2i(c, Vector2i.ONE) if out.size.x == 0 else out.merge(Rect2i(c, Vector2i.ONE))
				break
	return out


func mrock_key(c: Vector2i) -> String:
	return "mrock_%s_%d_%d" % [region_id, c.x, c.y]


## Days an ore rock takes to come back: the data's `every`, else by ore tier (3-7).
static func mrock_every(t: Dictionary) -> int:
	if t.has("every"):
		return maxi(1, int(t["every"]))
	return clampi(2 + int(GameState.items.get(str(t.get("ore", "stone")), {}).get("tier", 1)), 3, 7)


func _upper_tier(low: Dictionary, pl: Dictionary) -> void:
	var ups: Array = pl.get("upper", [])
	if ups.is_empty() or low.is_empty():
		return
	var room := WorldGen.inset(low, 2, 4)
	var up := {}
	for bl in ups:
		var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 4)); var sdv := int(bl.get("seed", 9))
		for c: Vector2i in WorldGen.mesa(self, Vector2(cx, cy), rad, float(bl.get("ry", rad * 0.8)), sdv, 3):
			if room.has(c):
				up[c] = true
	up = WorldGen.smooth_cells(up)
	var best := {}
	for part: Dictionary in _components(up):
		if part.size() > best.size():
			best = part
	if best.size() >= 8:
		var urmp: Array = pl.get("upper_ramps", [])
		add_plateau(best, urmp if not urmp.is_empty() else WorldGen.pick_ramps(self, best))


## 4-connected pieces of a cell set.
func _components(cells: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		var part := {}
		var st: Array = [c]
		while not st.is_empty():
			var q: Vector2i = st.pop_back()
			if seen.has(q) or not cells.has(q):
				continue
			seen[q] = true
			part[q] = true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				st.append(q + d)
		out.append(part)
	return out


var battle: Battle = null


func after_ready() -> void:
	WorldGen.add_backdrop(self, str(R.get("backdrop", "hills")))
	WorldGen.clear_stairs.call_deferred(self)
	if not R.has("battle"):
		WorldGen.dress_band(self, hash(region_id) % 1000 + 9)  # undergrowth along the forest edge: no bare blocked cells
	if R.has("battle"):
		battle = Battle.start(self, region_id, R["battle"])
	place_project_site()
	if R.has("colony"):
		_place_colony()
	_place_secrets.call_deferred()
	for p in R.get("props", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		var g := str(p.get("group", "props"))
		var nm := str(p["name"])
		var w := int(p.get("w", 0))
		# Buildings carry a "scale" (round 13) so they stand at town size next to the
		# hero (town buildings are ~1.0); everything else is drawn at the usual 0.5.
		var psc := float(p.get("scale", 0.5))
		if bool(p.get("anim", false)) and Art.has(g, nm):
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames(g, {"idle": nm}, {"idle": float(p.get("fps", 4.0))})
			a.animation = "idle"
			a.scale = Vector2(psc, psc)
			a.position = cell_pos(c.x + (w + 1) / 2.0, c.y + 1)
			a.offset = Vector2(0, -float(Art.info(g, nm).get("cell_h", 48)) / 2.0)
			if bool(p.get("under", false)):
				to_under(a)
			else:
				add_child(a)
			a.play("idle")
			if g == "buildings":
				_bprops.append([nm, c, w, a])  # BuildingAccess: says why you can't go in
		else:
			var sp := prop(g, nm, c, w, 0.0, false, psc)  # footprint blocked below, sized to the art
			if sp and bool(p.get("under", false)):
				to_under(sp)
			if sp and p.has("scale") and g != "buildings":
				_bprops.append([nm, c, w, sp])  # a building drawn from props: BuildingAccess too
		if bool(p.get("solid", true)):
			var h := int(p.get("h", 1))
			# Footprint = the art's real size (declared w/h are upper bounds), so
			# a prop never blocks air beside it. Tall props block only their
			# lower part; you walk behind the roof/canopy.
			var bw := w + 1
			var bh := h
			if Art.has(g, nm):
				var info := Art.info(g, nm)
				var aw := int(floor(float(info.get("cell_w", info.get("w", bw * TILE * 2))) * psc / TILE + 0.4))
				var ah := int(floor(float(info.get("cell_h", info.get("h", bh * TILE * 2))) * psc / TILE + 0.4))
				if p.has("scale"):  # a scaled building: its own art decides the footprint
					bw = maxi(aw, 1)
					bh = maxi(ah, 1)
				else:
					bw = clampi(aw, 1, bw)
					bh = clampi(ah, 1, bh)
			if bh >= 3 and g != "nature":
				bh = maxi(2, int(ceil(bh * 0.62)))
			var x0 := c.x + (w + 1 - bw) / 2
			block_rect(x0, c.y - bh + 1, bw, bh)
			# "open": footprint cells (offsets from the prop's cell) the art doesn't cover,
			# measured from its alpha by the generator: no see-through walls at round corners.
			for oc: Array in p.get("open", []):
				var ocell := c + Vector2i(int(oc[0]), int(oc[1]))
				if not things.has(ocell):
					blocked.erase(ocell)
					hard.erase(ocell)
	for mc: Vector2i in things:
		if str(things[mc].get("type", "")) == "mrock" and not props.has(mc):
			prop("props", "mrock_stone_%d" % (absi(mc.x + mc.y) % 2), mc)  # every ore rock shows
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			if blocked.has(k):  # walled in by a landmark placed after the roll
				things.erase(k)
				continue
			var it := str(things[k]["item"])
			var nm := "mushrooms_fall" if it in ["mushroom", "glowcap", "truffle"] and Art.has("nature", "mushrooms_fall") else ("wildflowers2" if Art.has("nature", "wildflowers2") else "flowers")
			prop("nature", nm, k, 0, 0.0, false)
	# Villagers who live out here (regions.json "npcs": [{"id", "cell", "lines": [...]}]).
	for n in R.get("npcs", []):
		var id := str(n["id"])
		var data: Dictionary = GameState.npcs.get(id, n if n.has("name") else {"name": id.capitalize()})  # regional folk carry their own name/sprite
		var npc := Npc.new()
		npc.map = self
		npc.setup(id, data, cell_center(Vector2i(int(n["cell"][0]), int(n["cell"][1]))))
		npc.wander = float(n.get("wander", 14.0))
		add_child(npc)
		npcs.append(npc)
	Crew.place(self)
	if Crew.perk_level("heal_hideout") >= 1 and region_id == "hideout" and int(GameState.run["hp"]) < int(GameState.run["max_hp"]) and int(GameState.run["flags"].get("doc_heal_day", -1)) != int(GameState.run["day"]):
		GameState.run["flags"]["doc_heal_day"] = int(GameState.run["day"])  # only used up when you're hurt
		GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + 20)
		later(func() -> void: hud.toast("Doc patches you up at the door. +1 heart.", Color(0.8, 1, 0.8)))
	var gen: Dictionary = R.get("gen", {})
	var inner := Rect2i(2, 2, cols - 4, rows - 4)
	var avoid := {}
	for pl: Dictionary in plateaus:  # every flight of stairs and its landings stay clear
		for st: Vector2i in pl["stairs"]:
			avoid.merge(cells_of([Rect2i(st.x - 1, st.y - 2, 3, 5)]))
	for b in R.get("blocks", []):
		for y in range(int(b[1]) - 1, int(b[1]) + int(b[3]) + 1):
			for x in range(int(b[0]) - 1, int(b[0]) + int(b[2]) + 1):
				avoid[Vector2i(x, y)] = true
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				avoid[Vector2i(x, y)] = true
	for c: Vector2i in _water_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				avoid[c + Vector2i(dx, dy)] = true
	if gen.has("tree_border"):
		var gaps: Array = []
		for e in exits:
			gaps.append((e["rect"] as Rect2i).grow(2))
		WorldGen.tree_border(self, Rect2i(1, 1, cols - 2, rows - 2), hash(region_id) % 1000, gaps, int(gen["tree_border"]))
	if gen.has("clumps"):
		WorldGen.tree_clumps(self, inner, hash(region_id) % 1000 + 1, int(gen["clumps"]), avoid)
	if gen.has("scatter"):
		WorldGen.scatter_props(self, inner, hash(region_id) % 1000 + 2, int(gen["scatter"]), avoid)
	if gen.has("region_props"):
		# Random scatter of named props from this region's set (non-interactive).
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region_id) % 1000 + 3
		var names: Array = gen["region_props"]
		var wprops: Array = gen.get("water_props", [])
		var wkeys: Array = _water_cells.keys()
		for i in int(gen.get("region_count", 20)):
			var nm := str(names[rng.randi_range(0, names.size() - 1)])
			var g := "nature" if Art.has("nature", nm) else "props"
			if nm in wprops:
				# Lily pads, leaping fish and splashes belong on the water.
				if wkeys.is_empty():
					continue
				var wc: Vector2i = wkeys[rng.randi() % wkeys.size()]
				if props.has(wc):
					continue
				var ws := prop(g, nm, wc, 0, 0.0, false)
				if ws:
					to_under(ws)
				continue
			var c := Vector2i(rng.randi_range(inner.position.x, inner.end.x - 1), rng.randi_range(inner.position.y, inner.end.y - 1))
			if things.has(c) or blocked.has(c) or avoid.has(c):
				continue
			var tx := Art.tex(g, nm)
			prop(g, nm, c, 0, 0.0, tx != null and tx.get_width() * tx.get_height() >= 1000)  # ankle-high decals don't block
	if gen.has("critters") and not bool(R.get("cave", false)):  # caves: no surface critters
		var ccount := int(gen.get("critter_count", 6))
		if MegaRegion.region_of(region_id) != "":
			ccount = mini(ccount, 5)  # mega maps: a few critters read as life; dozens cost frames
		WorldGen.add_critters(self, inner, hash(region_id) % 1000 + 4, ccount, gen["critters"])
	var colony_kinds := 0
	for e0 in R.get("enemies", []):
		if bool(e0.get("colony", false)):
			colony_kinds += 1
	# Your own HQ and blocks you hold stay clear of the President's thugs.
	var safe: bool = (region_id == "hideout" and GameState.run["flags"].has("hideout_seen")) or Ops.holds(region_id)
	for e in R.get("enemies", []):
		if safe and not bool(e.get("colony", false)):
			continue
		var n := GameState.enemy_count(int(e.get("count", 1)))
		if bool(e.get("colony", false)) and R.has("colony"):
			var cs := Colony.st(region_id)
			if bool(cs.get("done", false)):
				continue  # a saved island stays clear
			# Enough foes this visit to finish the elder's count.
			var left := int(Colony.data().get(region_id, {}).get("kills", 0)) - int(cs.get("kills", 0))
			if left > 0 and colony_kinds > 0:
				n = maxi(n, int(ceil(float(left) / colony_kinds)))
		for i in n:
			var at := cell_center(Vector2i(randi_range(4, cols - 5), randi_range(4, rows - 5)))
			# Never right on top of where you walked in.
			for tries in 20:
				var cc := world_to_cell(at - Vector2(0, 2))
				if player == null or (cc - world_to_cell(player.position)).length() >= 8.0 and not is_water_cell(cc) and not blocked.has(cc):
					break
				at = cell_center(Vector2i(randi_range(4, cols - 5), randi_range(4, rows - 5)))
			if e.has("cell"):
				at = cell_center(Vector2i(int(e["cell"][0]), int(e["cell"][1])))
			var ek := str(e["kind"])
			if ek == "grump" and not GameState.is_penguins():
				ek = "thug_lookout"
			var se := spawn_enemy(ek, at, _spawn_tier(ek))
			if se and bool(e.get("colony", false)):
				se.set_meta("colony_foe", true)
	if R.has("weather"):
		set_weather(str(R["weather"]))
	var flag := region_id + "_seen"
	if not GameState.run["flags"].has(flag) and R.has("intro"):
		GameState.run["flags"][flag] = true
		player.frozen = true
		var lines: Array = []
		var intro = R["intro"]
		if intro is Dictionary:
			intro = intro.get("penguins" if GameState.is_penguins() else "gangsters", [])
		for l in intro:
			lines.append({"text": str(l)} if l is String else l)
		await say(lines)
		player.frozen = false


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.visible and n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.visible and (n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0)):
			later(_talk_npc.bind(n))
			return true
	if Secrets.interact(self, c, thing) or HiddenArea.interact(self, c, thing):
		return true
	match str(thing.get("type", "")):
		"cpoint":
			if battle:
				later(battle.interact.bind(str(thing.get("id", ""))))
			return true
		"note":
			if thing.has("story"):
				later(func() -> void:
					if await Story.talk(self, str(thing["story"])):
						return
					var txt := str(thing.get("text_after", thing.get("text", "..."))) if thing.has("after_flag") and GameState.run["flags"].has(str(thing["after_flag"])) else str(thing.get("text", "..."))
					tell([{"who": str(thing.get("who", "")), "text": txt, "mood": str(thing.get("mood", "neutral"))}]))
				return true
			var who := str(thing.get("who", ""))
			if who == "Star Crystal" and not GameState.is_penguins():
				who = ""  # no Star Crystal in the gangster arc: the note reads as narration
			tell([{"who": who, "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"water":
			# fish_at casts with the rod in hand, else says how to get it there
			var pool: Array = thing.get("pool", [])
			if pool.is_empty():
				pool = R.get("fish", Fishing.T["fresh_pool"])
			fish_at(c, pool)
			return true
		"shop":
			later(_shop.bind(thing))
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [region_id, c.x, c.y]
			if not GameState.run["flags"].has(key) or int(GameState.run["day"]) >= int(GameState.run["flags"][key]) + int(thing.get("every", 1)):
				GameState.run["flags"][key] = int(GameState.run["day"])
				give(str(thing.get("item", "stone")), int(thing.get("n", 1)))
				if Crew.perk_level("sell_bonus") >= 3:
					GameState.add_money(25, "loot")
					hud.toast("Deuce taught you where people hide coins. +◆25", Color(1, 0.9, 0.5))
			else:
				hud.toast(str(thing.get("empty", "Nothing here right now.")))
			return true
		"heal":
			if (int(GameState.run["energy"]) >= int(GameState.run["max_energy"]) or int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2) and int(GameState.run["hp"]) >= int(GameState.run["max_hp"]):
				hud.toast("You're fully rested. Come back when you're tired.")  # keep today's rest for later
			elif int(GameState.run["flags"].get("heal_%s" % region_id, 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["heal_%s" % region_id] = int(GameState.run["day"])
				GameState.heal(int(thing.get("hp", 3)))
				var got := GameState.rest_energy(int(thing.get("energy", 30)))
				hud.toast(str(thing.get("msg", "You feel better.")) + ("  +%d energy." % got if got > 0 else ("  You've rested plenty today." if int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2 else "")))
				fx("heal", player.position + Vector2(0, -10), 10.0, 0.6)
			else:
				hud.toast("Once a day.")
			return true
		"boss":
			later(_boss.bind(thing))
			return true
		"mega_gate":
			later(MegaTravel.gate.bind(self, thing))
			return true
		"door":
			go_to(str(thing["scene"]), Vector2(float(thing["spawn"][0]) * TILE + 8, float(thing["spawn"][1]) * TILE + 4), str(thing.get("facing", "down")))
			return true
		"idoor":
			var shut := idoor_shut(thing)
			if shut != "":
				hud.toast(shut, Color(1, 0.9, 0.6))
				Music.instance(get_tree()).sfx("nope", "thud")
				return true
			GameMap.next_interior = str(thing["interior"])
			go_to("interior", Vector2.ZERO, "up")
			return true
		"casino":
			later(Casino.enter.bind(self))
			return true
		"casino_odds":
			tell([{"who": "", "text": Casino.odds_board()}])
			return true
		"mrock":
			if GameState.held_tool() != "pickaxe":
				return ToolHint.need(self, "pickaxe", "to break it")
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				Music.instance(get_tree()).sfx("dry_click", "thud")
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("pick", "chop")
			hitstop = maxf(hitstop, 0.025)
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			if not thing.has("hp_scaled"):  # C8 P4: the pickaxe matters on mega ore too
				thing["hp_scaled"] = true
				thing["hp"] = Mining.mega_rock_hp(str(thing.get("ore", "stone")), int(thing.get("hp", 2)))
			GameState.toughen(thing, "pickaxe")
			thing["hp"] = int(thing.get("hp", 2)) - Mining.swing_roll()
			if int(thing["hp"]) <= 0:
				hitstop = maxf(hitstop, 0.05)
				Music.instance(get_tree()).sfx("rock_break", "thud")  # mega ore rocks shatter like stone (c6_10-12)
				fx("poof", cell_center(c) + Vector2(0, -6), 12.0, 0.4)
				things.erase(c)
				blocked.erase(c)
				hard.erase(c)
				if props.has(c):
					(props[c] as Node).queue_free()
					props.erase(c)
				GameState.run["flags"][mrock_key(c)] = maxi(1, int(GameState.run["day"]))
				var mo := str(thing.get("ore", "stone"))
				give(mo, int(thing.get("n", 1)) if mo == "stone" else Mining.lumps(int(thing.get("n", 1))))
				if mo != "stone" and randf() < Mining.gem_chance(false) * 0.5:
					give(["amethyst", "ruby", "emerald", "sapphire"][clampi(fish_tier() - 2, 0, 3)])
				xp("mining", 3 if mo == "stone" else 6 + int(GameState.ORE_TIER.get(mo, 0)))
			return true
	return false


func _shop(thing: Dictionary) -> void:
	# C8 P6/P4: the shared stall loop (stays open, 1/5/10, price floor, bartering XP).
	await Shops.stall(self, str(thing.get("who", "Shop")), str(thing.get("greet", "What'll it be?")), thing.get("items", []))


func _boss(thing: Dictionary) -> void:
	var key := "boss_%s" % region_id
	if GameState.run["flags"].has(key):
		await say([{"text": str(thing.get("after_gangsters", thing.get("after", "Quiet now."))) if not GameState.is_penguins() else str(thing.get("after", "Quiet now."))}])
		return
	if _boss_node != null and is_instance_valid(_boss_node) and _boss_node._alive:
		return  # already fighting it: A at the boss swings, it doesn't re-summon
	if thing.has("when") and not GameState._cond_ok(thing["when"]):
		await say([{"text": str(thing.get("locked", "Not yet. There's business to finish elsewhere first."))}])
		return
	player.frozen = true
	var gang := not GameState.is_penguins()
	var bk := str(thing.get("kind_gangsters", thing.get("kind", "commander"))) if gang else str(thing.get("kind", "commander"))
	var bw := str(thing.get("who_gangsters", thing.get("who", ""))) if gang else str(thing.get("who", ""))
	var bt := str(thing.get("text_gangsters", thing.get("text", "..."))) if gang else str(thing.get("text", "..."))
	await say([{"who": bw, "text": bt}])
	var b := spawn_enemy(bk, player.position + Vector2(40, 0), int(thing.get("tier", -1)))
	if b:
		b.set_meta("boss_name", bw if bw != "" else str(thing.get("title", "")))
	boss_card(bk, str(thing.get("title_gangsters", thing.get("title", bw))) if gang else str(thing.get("title", bw)))  # boss_card starts the boss's song (C4: no second play)
	player.frozen = false
	_boss_node = b
	_boss_thing = thing


var _boss_node: Enemy
var _boss_thing: Dictionary


func on_enemy_died(e: Enemy) -> void:
	super(e)
	if _boss_node != null and e == _boss_node:
		_boss_node = null
		GameState.run["flags"]["boss_%s" % region_id] = true
		DangerMusic.boss_ended(self)  # wind-down + victory sting, then the area song (C5)
		player.frozen = true
		var win: Variant = _boss_thing.get("win_reverted", _boss_thing.get("win", "It's over.")) if e.has_meta("reverted") else _boss_thing.get("win", "It's over.")
		if not GameState.is_penguins() and _boss_thing.has("win_gangsters"):
			win = _boss_thing["win_gangsters"]
		await say([{"text": str(win)}])
		var reward := str(_boss_thing.get("reward", ""))
		if reward != "":
			give(reward, int(_boss_thing.get("reward_n", 1)))
		if DecorSources.grant_key(self, "boss:" + region_id) == "":  # C10a P4: a trophy for the house (decor.json grants, else the "boss" pool)
			DecorSources.roll_grant(self, "boss", 0.0, "boss")
		if _boss_thing.has("max_hp"):
			# Data says hearts (old 6-heart scale); one heart is 20 health now.
			GameState.grow_vital("hp", int(_boss_thing["max_hp"]) * GameState.HEART_HP)
		GameState.save()
		player.frozen = false


## Out-of-town villagers: gifts, quests (quests.json by giver), daily hello.
func _talk_npc(n: Npc) -> void:
	player.frozen = true
	n.face(player.position)
	var id := n.id
	var name := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	for nd0 in R.get("npcs", []):
		if str(nd0["id"]) == id and not GameState.npcs.has(id):
			name = str(nd0.get("name", name))
	var fr: Dictionary = GameState.run["friendship"]
	var sel := str(GameState.run["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	if not GameState.run["talked_today"].has(id):
		GameState.run["talked_today"][id] = true
		GameState.add_friend(id, 5)
	if await Story.talk(self, id):
		Intros.mark(id)  # a story beat was the meeting
		player.frozen = false
		return
	if await Intros.talk(self, id):  # first meeting (Tam at his hut, C11a P5)
		player.frozen = false
		return
	if await Hearts.talk(self, id):
		player.frozen = false
		return
	if await Romance.talk(self, id):
		player.frozen = false
		return
	if await SideStory.talk(self, id):  # C7 P4 side stories
		player.frozen = false
		return
	if await Quests.talk(self, id, name):
		player.frozen = false
		return
	if await Crew.talk(self, id):
		player.frozen = false
		return
	if GameState.can_gift(id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(id, sel)
		await say([{"who": name, "text": gift_reaction(name, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	var lines: Array = []
	var hl := Hearts.daily(id)
	if hl != "" and (int(GameState.run["day"]) + GameState.friend_hearts(id)) % 2 == 0:
		lines.append({"who": name, "text": hl})
	for nd in R.get("npcs", []):
		if str(nd["id"]) == id and lines.is_empty():
			var ls: Array = nd.get("lines", [])
			if not ls.is_empty():
				lines.append({"who": name, "text": str(ls[(int(GameState.run["day"]) + GameState.friend_hearts(id)) % ls.size()])})
	if lines.is_empty():
		lines.append({"who": name, "text": "..."})
	await say(lines)
	player.frozen = false


## 96px tile sets that are nine plain variants (no edges or corners baked in), so
## they can be drawn in turn instead of the centre cell everywhere.
const VARIANT_SETS := ["dead_grass", "metal_a", "metal_b", "cloud", "cracked_earth", "wood_dock"]


## Feature-blob cells drawn from tiles (no soft seam): the soft patch layer keeps off them.
var _tile_feature := {}
const FEATURE_SOFT := {"snowpatch": "snow", "ruinfloor": "ruin_floor", "bog": "bog", "track": "dirt_track", "sand": "sand",
	"cave_ice": "cave_ice_floor", "cave_water": "cave_crystal_floor", "grass_dry": "dry_grass"}  # soft edges (CONDUCT 4)


## One feature blob entry's cells (noise blobs), with specks dropped and holes filled.
func _feature_cells(fb: Dictionary) -> Dictionary:
	var cells := {}
	for bl in fb.get("blobs", []):
		var cx := float(bl["c"][0]); var cy := float(bl["c"][1]); var rad := float(bl.get("r", 5)); var sdv := int(bl.get("seed", 3))
		for y in range(int(cy - rad - 3), int(cy + rad + 4)):
			for x in range(int(cx - rad - 3), int(cx + rad + 4)):
				if x < 0 or y < 0 or x >= cols or y >= rows:
					continue
				var n := WorldGen.fbm(float(x), float(y), sdv, 5.0)
				if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) + n * rad * 0.35 <= rad:
					cells[Vector2i(x, y)] = true
	for pass_i in 2:
		var next := cells.duplicate()
		var span := {}
		for c: Vector2i in cells:
			for off: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				span[c + off] = true
		for c: Vector2i in span:
			var nb := 0
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if cells.has(c + off):
					nb += 1
			if cells.has(c) and nb <= 1:
				next.erase(c)
			elif not cells.has(c) and nb >= 3 and c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
				next[c] = true
		cells = next
	# Soft feature patches draw over the map canvas: keep them off plateaus, their
	# rims and their rock faces (they buried tiered hills' cliffs and stairs).
	for pl: Dictionary in plateaus:
		for pc2: Vector2i in pl["cells"]:
			for d2: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				cells.erase(pc2 + d2)
	return cells


func draw_map() -> void:
	_tile_feature = {}
	for fb in R.get("feature_blobs", []):
		var setn := str(fb["set"])
		if Art.has("tiles", setn + "_top_0") and not FEATURE_SOFT.has(setn):
			_tile_feature.merge(_feature_cells(fb))
	var ground := str(R.get("ground", "grass"))
	if ground == "grass":
		draw_grass(hash(region_id) % 100)
		WorldGen.draw_ground_detail(self, hash(region_id) % 100 + 1, float(R.get("detail", 0.1)))
	elif Art.has("tiles", ground) or Art.has("seamless", str(R.get("ground_seam", ""))):
		# A seamless ground where the region names one; otherwise the set's variants
		# in turn, so the 16px grid doesn't show.
		var gseam := str(R.get("ground_seam", ""))
		var garea := Rect2(Vector2(-pad, -pad) * TILE, Vector2(cols + 2 * pad, rows + 2 * pad) * TILE)
		if gseam != "" and seam_fill(self, gseam, garea):
			pass  # whole texture repeats: the texels seam_cell drew cell by cell, ~1/64 of the calls
		elif gseam == "teal_moss" and seam_fill(self, "meadow_grass", garea, Color(0.42, 0.85, 0.82)):
			pass
		else:
			for y in range(-pad, rows + pad):
				for x in range(-pad, cols + pad):
					Art.draw_tile(self, "tiles", ground, Vector2(x * TILE, y * TILE), posmod(y, 3) * 3 + posmod(x, 3) if ground in VARIANT_SETS else 4)
	else:
		draw_rect(Rect2(-pad * TILE, -pad * TILE, (cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE), Color(str(R.get("ground_color", "5a9e4b"))))
	# Region ground set (Prompts-08 batch 3): the region's own fill tiles in
	# noise drifts over the grass, with its decals scattered on top.
	var ps := str(R.get("patch_set", ""))
	if ps != "" and (Art.has("tiles", ps + "_top_0") or (ps == "sand" and Art.has("seamless", "sand"))):
		# Coherent ground patches (noise blobs with real edges from the region's
		# blob set) instead of a per-cell tile lottery.
		# The patch shape never changes on this map: worked out once (~50 ms on a
		# colony map), not on every redraw (spells, co-op sync).
		var cells: Dictionary = _patch_memo.get("cells", {})
		if not _patch_memo.has("cells"):
			var sd := hash(region_id) % 977
			cells = {}
			for y in range(-pad + 1, rows + pad - 1):
				for x in range(-pad + 1, cols + pad - 1):
					var n := WorldGen.fbm(float(x), float(y), sd, float(R.get("patch_scale", 10.0)))
					if n > float(R.get("ground_threshold", 0.08)):
						cells[Vector2i(x, y)] = true
			# Drop single-cell specks and fill single-cell holes so edges read cleanly.
			for pass_i in 2:
				var next := cells.duplicate()
				for y in range(-pad + 1, rows + pad - 1):
					for x in range(-pad + 1, cols + pad - 1):
						var c := Vector2i(x, y)
						var nb := int(cells.has(Vector2i(x + 1, y))) + int(cells.has(Vector2i(x - 1, y))) + int(cells.has(Vector2i(x, y + 1))) + int(cells.has(Vector2i(x, y - 1)))
						var here := cells.has(c)
						if here and nb <= 1:
							next.erase(c)
						elif not here and nb >= 3:
							next[c] = true
				cells = next
			# Never over the border band (cliff walls, void, deep trees draw on the map
			# canvas, under the soft layer) nor under a feature blob drawn from tiles.
			for c: Vector2i in cells.keys():
				if not in_content(c) or _border_cells.has(c) or _tile_feature.has(c):
					cells.erase(c)
			for pl: Dictionary in plateaus:  # cliff faces, rims and stairs draw on the map canvas: never cover them
				for pc2: Vector2i in pl["cells"]:
					for d2: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(-1, 0)]:
						cells.erase(pc2 + d2)
			_patch_memo["cells"] = cells
		var soft_seam: String = {"bog": "bog", "ruinfloor": "ruin_floor", "snowpatch": "snow", "track": "dirt_track", "sand": "sand"}.get(ps, "")
		if ps == "snowpatch" and GameState.look_se() == "winter":
			cells = {}  # snow on snow
		if soft_seam != "" and soft_ground(cells, soft_seam):
			cells = {}  # drawn by the soft-edge layer
		# Fills, bog shade and decals in grouped passes (each covers only its own cell).
		var seam_ps: String = {"bog": "bog", "ruinfloor": "ruin_floor"}.get(ps, "")
		var pfills := {}
		var pdecos := {}
		var shade: Array[Vector2i] = []
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			if seam_ps != "" and seam_cell(self, seam_ps, c):
				continue
			(pfills.get_or_add(Art.fill_name(ps, h), []) as Array).append(c)
			if ps == "bog":
				shade.append(c)
			if h % 29 == 0 and _blob_interior(cells, c) and Art.has("tiles", "%s_deco_%d" % [ps, h / 29 % 36]):
				(pdecos.get_or_add("%s_deco_%d" % [ps, h / 29 % 36], []) as Array).append(c)
		for nm: String in pfills:
			for c: Vector2i in pfills[nm]:
				Art.draw_tile(self, "tiles", nm, Vector2(c * TILE), 0)
		for c in shade:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.32, 0.45, 0.22, 0.3))  # mossier, less void
		for nm: String in pdecos:
			for c: Vector2i in pdecos[nm]:
				Art.draw_tile(self, "tiles", nm, Vector2(c * TILE), 0)
		_draw_soft_rim(cells, Color(0.2, 0.13, 0.06, 0.22), Color(0.1, 0.2, 0.05, 0.18))
		var ds := str(R.get("deco_set", ""))
		var dc := int(R.get("deco_count", 0))
		# Only the deco tiles with clear borders (deco_keep); the rest are opaque squares.
		var keep: Array = R.get("deco_keep", range(dc))
		if ds != "" and dc > 0 and not keep.is_empty():
			for y in range(0, rows):
				for x in range(0, cols):
					var h := absi((x * 73856093) ^ (y * 19349663) ^ 7)
					if h % 41 == 0 and not blocked.has(Vector2i(x, y)):
						Art.draw_tile(self, "tiles", "%s_%d" % [ds, int(keep[h / 17 % keep.size()])], Vector2(x * TILE, y * TILE), 0)
	# Feature ground (Prompts 09 edge sets): noise blobs of e.g. terrace / snow / track / ruin floor.
	for fb in R.get("feature_blobs", []):
		var setn := str(fb["set"])
		if not Art.has("tiles", setn + "_top_0"):
			continue
		var cells := _feature_cells(fb)
		var fs: String = FEATURE_SOFT.get(setn, "")
		if setn == "snowpatch" and GameState.look_se() == "winter":
			continue  # snow on snow
		if fs != "" and soft_ground(cells, fs, Color(0.2, 0.14, 0.07, 0.12)):
			continue  # soft edges, like the patch set
		# Grouped by texture (fill variants, then decals): each piece covers only its
		# own cell, so the order between cells doesn't show, and the batch holds.
		var fills := {}
		var decos := {}
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			(fills.get_or_add(Art.fill_name(setn, h), []) as Array).append(c)
			if h % 23 == 0 and _blob_interior(cells, c) and Art.has("tiles", "%s_deco_%d" % [setn, h / 23 % 36]):
				(decos.get_or_add("%s_deco_%d" % [setn, h / 23 % 36], []) as Array).append(c)
		for group: Dictionary in [fills, decos]:
			for nm: String in group:
				for c: Vector2i in group[nm]:
					Art.draw_tile(self, "tiles", nm, Vector2(c * TILE), 0)
		Art.draw_blob(self, cells, setn, 16.0, 0)  # the set's rims and corners frame it
		_draw_soft_rim(cells, Color(0.2, 0.13, 0.06, 0.22), Color(0.1, 0.2, 0.05, 0.18))
	draw_plateaus()
	if region_id == "marsh" and Art.has("props", "mk_fog_l") and _anim_layer:
		# Low marsh mist (Prompts 16): a few soft puffs drifting slowly, faint.
		var fogs := ["mk_fog_l", "mk_fog_m", "mk_fog_s", "mk_fog_m", "mk_fog_l", "mk_fog_s"]
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
			var tt := Time.get_ticks_msec() / 1000.0
			for i in fogs.size():
				var ft := Art.tex("props", str(fogs[i]))
				if ft == null:
					continue
				var w := ft.get_width() * 0.35
				var span := float(cols * TILE) + w * 2.0
				var fx := fposmod(i * 211.0 + tt * (3.0 + i), span) - w
				var fy := 40.0 + fposmod(i * 157.0, float(rows * TILE) - 80.0) + sin(tt * 0.15 + i) * 10.0
				ci.draw_texture_rect(ft, Rect2(fx, fy, w, ft.get_height() * 0.35), false, Color(1, 1, 1, 0.22)))
	for layer in R.get("layers", []):
		var nm := str(layer["tile"])
		var r: Array = layer["rect"]
		var lr := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		if not (Art.has("seamless", nm) and soft_ground(cells_of([lr]), nm)):
			draw_tileset_rect(nm, lr, Color(str(layer.get("color", "888888"))))
	var path_kind := str(R.get("path", "dirt"))
	var pcs := {}
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				pcs[Vector2i(x, y)] = true
	for e in exits:
		# Run the path out over the exit's edge row in its own lanes only (all of the exit
		# when no path reaches it): the full 4-wide row widened into a slab with shoulders.
		var er: Rect2i = e["rect"]
		var inw := Vector2i(1 if er.position.x <= 0 else (-1 if er.end.x >= cols else 0), 1 if er.position.y <= 0 else (-1 if er.end.y >= rows else 0))
		var ecs := cells_of([er])
		var lane := {}
		for c: Vector2i in ecs:
			for k in range(1, 4):
				if pcs.has(c + inw * k):
					for j in k:
						lane[c + inw * j] = true  # (and the gap up to a path that stops short)
					break
		for c: Vector2i in (lane if not lane.is_empty() else ecs):
			pcs[c] = true
	_pcs = pcs
	if path_kind in ["dirt", "sand", "stone"]:
		draw_ground(path_kind, pcs)
	elif path_kind == "cracked_earth" and soft_ground(widen_path(pcs), "cave_stone_floor", Color(0.1, 0.05, 0.15, 0.3), Color(0.8, 0.75, 0.8)):
		pass  # soft cracked road on the ash, not a tile band
	elif path_kind.begins_with("bio_path") and soft_ground(widen_path(pcs), "cave_stone_floor", Color(0.1, 0.05, 0.15, 0.3), Color(0.85, 1.0, 0.95)):
		pass  # one soft paved path (the blue crystal floor read as a river)
	elif Art.has("seamless", path_kind) and soft_ground(widen_path(pcs), path_kind, Color(str(R.get("path_lip", "33221a48")))):
		pass  # any seamless texture as a soft path (mega regions: snow_trodden, cobble_warm, ballast...)
	else:
		_draw_path_tiles(pcs, path_kind)
	for wsh in _rect_water:
		draw_water(_rect_water[wsh], str(wsh))
	if not _water_cells.is_empty() and not (R.has("islands") and not border_water_extra.is_empty()):
		var by_shore := {}
		for c: Vector2i in _water_cells:
			var sh := str(things.get(c, {}).get("shore", "grass"))
			if not by_shore.has(sh):
				by_shore[sh] = {}
			by_shore[sh][c] = true
		for sh in by_shore:
			draw_water(by_shore[sh], str(sh))
	draw_exits()
	if bool(R.get("fence", false)) and pad == 0:
		draw_fence_border(Color(str(R.get("fence_color", "6b4a2b"))))


func _process(delta: float) -> void:
	super(delta)


## Tile-set paths (asphalt, neon sidewalk, polished road, docks...): the set's
## plain cells, never its edge pieces.
func _draw_path_tiles(pcs: Dictionary, path_kind: String) -> void:
	Footsteps.mark(self, pcs, Footsteps.path_word(path_kind))
	for c: Vector2i in pcs:
		var pi := posmod(c.y, 3) * 3 + posmod(c.x, 3) if path_kind in VARIANT_SETS else 4
		if path_kind == "asphalt2":
			pi = 3 if (c.x + c.y) % 2 == 0 else 5  # not the lane-stripe column
		if not Art.draw_tile(self, "tiles", path_kind, Vector2(c * TILE), pi):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("8a8a90"))


## Exit corridors through the border band use the region's own path, tile sets too
## (they used to turn into a dark cobble slab across the road).
var _pcs := {}  # the region's own path cells (draw_map), redrawn with the exit corridors as one shape


func draw_corridor(cells: Dictionary) -> void:
	var k := str(R.get("path", "dirt"))
	if k in ["dirt", "sand", "stone"]:
		# One soft body: the region's own path (as draw_map widened it) plus the corridor cells
		# unwidened, so the road runs on through the band at its own width (no 4-wide slab with
		# shoulders, no dark ring where two bodies meet). Only path cells: ground patches stay put.
		var body := widen_path(_pcs)
		body.merge(cells)
		var seam: String = {"dirt": "dirt_track", "sand": "sand", "stone": "ruin_floor"}[k]
		var lip := Color(0.12, 0.1, 0.08, 0.35) if k == "stone" else Color(0.25, 0.15, 0.06, 0.3 if k == "dirt" else 0.0)
		if not soft_ground(body, seam, lip):
			draw_ground(k, cells)
	elif k == "cracked_earth" and soft_ground(widen_path(cells), "cave_stone_floor", Color(0.1, 0.05, 0.15, 0.3), Color(0.8, 0.75, 0.8)):
		pass  # matches the soft wastes road
	elif k.begins_with("bio_path") and soft_ground(widen_path(cells), "cave_stone_floor", Color(0.1, 0.05, 0.15, 0.3), Color(0.85, 1.0, 0.95)):
		pass  # matches the soft jungle path
	elif Art.has("seamless", k) and soft_ground(widen_path(_pcs).merged(cells), k, Color(str(R.get("path_lip", "33221a48")))):
		pass  # a seamless soft path runs on through the band as one shape
	else:
		_draw_path_tiles(cells, k)


func draw_ground(kind: String, cells_in: Dictionary) -> void:
	# Stone paths: one soft paved shape (the cobble blob set made every cell an edge box).
	if kind == "stone" and soft_ground(widen_path(cells_in), "ruin_floor", Color(0.12, 0.1, 0.08, 0.35)):
		return
	super(kind, cells_in)


## Colony maps: the elder, the shop, the star crystal and the tide beacons.
func _place_colony() -> void:
	var cid := region_id.trim_prefix("colony_")
	var done := bool(Colony.st(region_id)["done"])
	const ELDERS := {"coral": "elder_brine", "kelp": "elder_tidewhisker", "ice": "elder_icewhisker", "ember": "elder_cinderpaw"}
	for t in R.get("things", []):
		var c := Vector2i(int(t["cell"][0]), int(t["cell"][1]))
		match str(t.get("type", "")):
			"elder":
				var eid := str(ELDERS.get(cid, "mer"))
				var sp := CharacterLibrary.make_sprite(eid if CharacterLibrary.has_character(eid) else "mer")
				if sp:
					sp.position = cell_center(c)
					sp.play("happy" if done and sp.sprite_frames.has_animation("happy") else ("idle" if done else ("sad" if sp.sprite_frames.has_animation("sad") else "idle")))
					add_child(sp)
				_colony_village(cid, c, done)
			"colony_shop":
				var stn := "%s_stall_%s" % [cid, "open" if done else "closed"]
				if Art.has("props", stn):
					prop("props", stn, c, 2, 0.0, true, 0.3)
				elif Art.has("props", "stall2_blue"):
					prop("props", "stall2_blue" if done else "stall2_blue_closed", c, 1)
			"star_crystal":
				var cn := "%s_crystal_%s" % [cid, "lit" if done else "dim"]
				var nm := "ccrystal_%d" % (4 if done else 2)
				if Art.has("props", cn):
					prop("props", cn, c, 1, 0.0, true, 0.3)
				elif Art.has("props", nm):
					prop("props", nm, c)
			"beacon":
				var lit := (Colony.st(region_id)["beacons"] as Dictionary).has(str(t.get("key", "")))
				var bn := "%s_beacon_%s" % [cid, "on" if lit else "off"]
				var ln := "lantern_lit" if lit else "lantern_unlit"
				if Art.has("props", bn):
					prop("props", bn, c, 0, 0.0, true, 0.22)
				elif Art.has("props", ln):
					prop("props", ln, c)


# Houses, villagers and (until the crystal wakes) the creeping blight around the elder.
func _colony_village(cid: String, at: Vector2i, done: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id)
	var spots := [Vector2i(-8, -3), Vector2i(0, -7), Vector2i(6, -5), Vector2i(-9, 4), Vector2i(7, 4), Vector2i(9, -2)]  # first three preferred; the rest are fallbacks off the roads
	var pav := {}
	for pr in R.get("paths", []):
		for y in range(int(pr[1]) - 1, int(pr[1]) + int(pr[3]) + 1):
			for x in range(int(pr[0]) - 1, int(pr[0]) + int(pr[2]) + 1):
				pav[Vector2i(x, y)] = true
	var used := 0
	for s: Vector2i in spots:
		if used >= 3:
			break
		var hn := "%s_house_%d" % [cid, used + 1]
		var hc: Vector2i = at + s
		var clear := not blocked.has(hc)
		for fy in range(hc.y - 3, hc.y + 1):
			for fx2 in range(hc.x - 1, hc.x + 4):
				if pav.has(Vector2i(fx2, fy)):
					clear = false
		if not clear:
			continue
		used += 1
		if Art.has("props", hn):
			prop("props", hn, hc, 2, 0.0, true, 0.32)
	for i in 3:
		var kid := "%s_kit_%d" % [cid, i + 1]
		if not CharacterLibrary.has_character(kid):
			continue
		var sp := CharacterLibrary.make_sprite(kid)
		if sp == null:
			continue
		var kc: Vector2i = at + Vector2i(-4 + i * 4, 3 + (i % 2))
		sp.position = cell_center(kc)
		sp.play("idle")
		sp.speed_scale = 0.7 + 0.2 * i
		sp.y_sort_enabled = true
		add_child(sp)
	if done:
		return
	for i in 10:
		var bn := "%s_blight_%d" % [cid, 1 + (i % 3)]
		var bc := Vector2i(rng.randi_range(4, cols - 5), rng.randi_range(4, rows - 5))
		if Art.has("props", bn) and not blocked.has(bc) and not things.has(bc) and not props.has(bc) and not is_water_cell(bc) and bc.distance_to(at) > 9:
			prop("props", bn, bc, 0, 0.0, true, 0.35)


## C10b P4 (c10b_04_15): a region interior door may carry "open": {"hours": [from, to]
## on the day's own scale (26 = 2am), "flag": "<flag>"} and "shut": "<words>". ""
## while it opens; never a silent door.
static func idoor_shut(thing: Dictionary) -> String:
	var o: Dictionary = thing.get("open", {})
	if o.is_empty():
		return ""
	var flag := str(o.get("flag", ""))
	if flag != "" and not GameState.run.get("flags", {}).has(flag):
		return str(thing.get("shut", "Locked for now."))
	var h: Array = o.get("hours", [])
	if h.size() == 2:
		var now := int(GameState.run.get("time", 0)) / 60.0
		if now < float(h[0]) or now >= float(h[1]):
			return str(thing.get("shut", "Closed. Open %s." % TownHours.hours_text(int(h[0]), int(h[1]))))
	return ""
