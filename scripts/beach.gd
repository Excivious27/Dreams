extends GameMap
## The south beach (C14 P3: grown east and south): zones west->east are the
## shipwreck point (x0-24), the family beach and the town lane (x24-46), the cove
## with a rowboat-only sandbar (x46-64), the MARINA (x64-92, Marina tiers T0-T4)
## and the lighthouse point (x92+). Exits: town (north), marsh (west), quarry (east).
## Gangster arc: a boardwalk, a vendor stall, concrete piers and the Tidewater Launch.

const COLS := 100
const ROWS := 46
const TOWN_EXIT := Rect2i(30, 0, 4, 1)
const MARSH_EXIT := Rect2i(0, 12, 1, 4)
const QUARRY_EXIT := Rect2i(COLS - 1, 12, 1, 4)
const SEA_Y := 24
const MARINA_X := 64
const QUAY_Y := 20      # the marina quay's sea line
const PIER_X := 76      # main pier, 3 wide (T1+)
const CAMP := Vector2i(86, 9)
const SANDBAR := Rect2i(52, 34, 6, 3)
## The sea's own shore fish (no freshwater salmon/goldfish; gen_collections scans this list).
const SEA_FISH := ["sunfish", "bass", "eel", "puffer", "starfin"]
var _sea := {}
var _sand := {}
var _pier_sea := {}  # sea cells under the piers: the water runs on beneath the planks
var _tip := Vector2i.ZERO
var _quay := {}  # the marina quay (boardwalk / concrete), drawn over the sand
## HiddenArea reads m.R["hidden"]: one sea-cave pocket in the west rocks (c14_04-23).
var R := {"hidden": {"pockets": 1, "ways": 1}}


func scene_id() -> String:
	return "beach"


func default_spawn() -> Vector2:
	return Vector2(32 * TILE, 3 * TILE) + offset()


func build() -> void:
	cols = COLS
	rows = ROWS
	pad = 7
	border = {"n": "trees", "s": "water", "w": "trees", "e": "trees"}  # (the east rock band was buried under the sand: an invisible wall)
	music_track = "beach" if GameState.is_penguins() else ("beach_gang" if Music.has_track("beach_gang") else "beach")
	add_exit(TOWN_EXIT, "town", Vector2(40 * TILE, 92 * TILE), "up", "▲ town")
	add_exit(MARSH_EXIT, "marsh", Vector2(49 * TILE, 22 * TILE + 8), "left", "◀ marsh")
	add_exit(QUARRY_EXIT, "quarry", Vector2(2 * TILE, 22 * TILE + 8), "right", "quarry ▶")
	# The tide line wanders: sea cells start at SEA_Y ± noise, with a cove on the east.
	for y in range(8, rows):
		for x in cols:
			# The grass/sand line wanders 0-2 rows (the lane columns keep row 8).
			var top := 8 + clampi(int(round((WorldGen.fbm(float(x), 1.0, 507, 5.0) + 0.5) * 2.0)), 0, 2)
			if y < top and (x < 28 or x > 35):
				continue  # grass
			var edge := _edge(x)
			if y >= edge and not SANDBAR.has_point(Vector2i(x, y)):
				_sea[Vector2i(x, y)] = true
				set_thing(x, y, {"type": "sea", "hint": "A: fish" if GameState.has_tool("rod") else ""})
			else:
				_sand[Vector2i(x, y)] = true
	# Piers out into the sea: the west (ferry) pier, the family pier and the marina's
	# main pier (a 2-wide broken stub until Marina tier 1 makes it 3 wide and long).
	var mt := Marina.tier()
	for px: Array in [[12, 2, 6], [31, 2, 6], [PIER_X, 3 if mt >= 1 else 2, 14 if mt >= 1 else 3]]:
		_pier(int(px[0]), int(px[1]), int(px[2]))
	if mt >= 2:  # finger docks off the main pier
		for fy: int in [QUAY_Y + 5, QUAY_Y + 10]:
			for x in range(PIER_X + 3, PIER_X + 10):
				_dock_cell(Vector2i(x, fy))
	# The west pier's tip: the colony ferry (penguins) or the Tidewater Launch (gangsters).
	var tip := Vector2i(12, SEA_Y + 4)
	for y in range(SEA_Y - 3, rows):
		if things.get(Vector2i(12, y), {}).get("type", "") == "dock":
			tip = Vector2i(12, y)
	_tip = tip
	if GameState.is_penguins():
		things[tip] = {"type": "ferry", "hint": "A: Skipper Barnacle's ferry", "station": "beach_colony_ferry"}
	else:
		things[tip] = {"type": "marina", "kind": "passage", "station": "beach_tidewater", "hint": "A: Tidewater Launch"}
	_marina_things(mt)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + int(GameState.run["day"]) / 7
	for i in 12:
		var c := Vector2i(rng.randi_range(2, MARINA_X - 2), rng.randi_range(9, SEA_Y + 2))
		if not _sand.has(c):
			continue
		if things.has(c):
			continue
		var key := "forage_beach_%d_%d" % [c.x, c.y]
		if not GameState.respawned(key, 2):  # Honey Sense shortens it
			continue
		var item: String = ["seashell", "seashell", "coconut", "fiber", "crab"][rng.randi_range(0, 4)]
		things[c] = {"type": "forage", "key": key, "item": item, "hint": "A: pick up %s" % GameState.item_name(item)}
	set_thing(5, 16, {"type": "wreck", "hint": "A: search the wreck"})
	for x in range(MARINA_X, 92):
		for y in range(QUAY_Y - 3, QUAY_Y + 1):
			if _sand.has(Vector2i(x, y)):
				_quay[Vector2i(x, y)] = true
	# The sea, the water under the piers and the water past the map edge are one body.
	if Art.has("seamless", "sea"):
		border_water_extra = _sea.duplicate()
		border_water_extra.merge(_pier_sea)
		border_water_shore = "sand"


## The tide line by column: the open beach, the cove (deepest at x 54), the
## marina's straight quay, and the lighthouse point jutting south.
func _edge(x: int) -> float:
	var n := WorldGen.fbm(float(x), 3.0, 505, 9.0) * 3.0
	if x < 44:
		return SEA_Y + n
	if x < MARINA_X:
		return SEA_Y + n - 5.0 * sin(PI * float(x - 44) / float(MARINA_X - 44))
	if x < 92:
		return QUAY_Y + n * 0.3
	return QUAY_Y + 2 + (x - 92) * 1.2 + n * 0.5


func _dock_cell(c: Vector2i) -> void:
	if not in_content(c):
		return
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	if _sea.has(c):
		_pier_sea[c] = true
	_sea.erase(c)
	things[c] = {"type": "dock"}


## A pier `w` wide starting one row above the first sea cell, `len` rows into the sea.
func _pier(x0: int, w: int, len: int) -> void:
	var y0 := 6
	while not _sea.has(Vector2i(x0, y0)) and y0 < rows - 1:
		y0 += 1
	for y in range(y0 - 1, mini(y0 + len, rows - 1)):
		for x in range(x0, x0 + w):
			_dock_cell(Vector2i(x, y))


## The marina's interactable things for tier `mt` (Marina.interact handles them).
func _marina_things(mt: int) -> void:
	var pen := GameState.is_penguins()
	# The harbour office board (always: T0 is where Hollis offers the first job).
	set_thing(MARINA_X + 6, QUAY_Y - 3, {"type": "marina", "kind": "board", "hint": "A: " + Marina.line("board")})
	set_thing(CAMP.x + 2, CAMP.y + 1, {"type": "marina", "kind": "camp", "hint": "A: the camp"})
	if mt >= 1:
		set_thing(PIER_X + 1, QUAY_Y - 1, {"type": "marina", "kind": "passage", "station": "beach_marina", "hint": "A: passage desk"})
	if mt >= 2:
		set_thing(MARINA_X + 17, QUAY_Y - 3, {"type": "marina", "kind": "market", "hint": "A: fish market"})
		set_thing(MARINA_X + 24, QUAY_Y - 3, {"type": "marina", "kind": "boathouse", "hint": "A: boatwright"})
	if mt >= 3 and Marina.npc_here("saffi", 12):
		set_thing(PIER_X + 8, QUAY_Y + 9, {"type": "marina", "kind": "trader", "hint": "A: the Gull's Wing" if pen else "A: the freighter"})
	# The rowboat-only sandbar: a buried chest (exploration secret, c14_04-15).
	if not GameState.run["flags"].has("sandbar_chest"):
		set_thing(SANDBAR.position.x + 3, SANDBAR.position.y + 1, {"type": "sandbar_chest", "hint": "A: dig"})


func after_ready() -> void:
	WorldGen.add_backdrop(self, "sea")
	_palm_band()
	WorldGen.dress_band(self, 812)
	# Roz's camp: anim_prop, so the fire glows at night (c14_04-05).
	if anim_prop("props", "campsite", CAMP, 1, 6.0, false):
		for x in range(CAMP.x, CAMP.x + 2):
			blocked[Vector2i(x, CAMP.y)] = true
	if Marina.tier() < 1:
		set_thing(CAMP.x + 2, CAMP.y + 2, {"type": "note", "text": "Someone's camp. The fire's still warm. Footprints lead down to the water, and a little way off, a rowing boat's keel-mark in the sand.", "hint": "A: the camp"}, false)
	var dock := DockLayer.new()
	dock.map = self
	dock.tiles_name = "dock" if GameState.is_penguins() or not Art.has("tiles", "concrete_pier") else "concrete_pier"
	dock.position = offset()
	add_child.call_deferred(dock)
	var avoid := {}
	for y in range(8, rows):
		for x in cols:
			avoid[Vector2i(x, y)] = true
	for c in cells_of([Rect2i(28, 0, 8, 9), MARSH_EXIT.grow(3), QUARRY_EXIT.grow(3), Rect2i(MARINA_X, 0, cols - MARINA_X, 9)]):
		avoid[c] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, 6), 83, 8, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, 6), 84, 10, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, 20), 85, 16, ["seagull", "seagull", "crab", "crab", "sparrow", "butterfly_yellow", "crab"])
	_place_props()
	_dress_marina()
	prop("props", "lantern_lit", Vector2i(30, SEA_Y - 5))
	prop("props", "lantern_lit", Vector2i(33, SEA_Y - 5))
	_clear_docks()
	# Station props for the TravelNet stations here (P4's TravelNet, when present).
	if Marina.has_travel_net():
		var tn: Script = load(Marina.TRAVEL)
		if tn and tn.has_method("station_prop"):
			for sid: String in ["beach_marina", "beach_colony_ferry" if GameState.is_penguins() else "beach_tidewater"]:
				tn.call("station_prop", self, sid)
	HiddenArea.place(self, "beach", 1)
	if not GameState.run["flags"].has("beach_seen"):
		GameState.run["flags"]["beach_seen"] = true
		player.frozen = true
		await say([{"text": "Salt wind. Gulls. The sea goes on until it becomes the sky. Half a boat lies in the sand like something the water spat out."}])
		player.frozen = false


## Nothing grows on the planks: drop any plant/decal dressing that landed on a
## dock/ferry cell or its one-cell ring (c14_04-19).
func _clear_docks() -> void:
	for c: Vector2i in things.keys():
		if not str(things[c].get("type", "")) in ["dock", "ferry"] and not (str(things[c].get("type", "")) == "marina" and str(things[c].get("kind", "")) == "passage"):
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var k := c + Vector2i(dx, dy)
				if props.has(k) and things.get(k, {}).get("type", "") in ["", "dock", "ferry"]:
					var n: Node = props[k]
					if n is Sprite2D and (n as Sprite2D).texture and str((n as Sprite2D).texture.resource_path).contains("/nature/"):
						n.queue_free()
						props.erase(k)


## Reload the beach after a marina upgrade so the new tier's harbour appears.
func rebuild_marina() -> void:
	if player:
		go_to("beach", player.position - offset(), "down", false)


## The side bands over the sand. The soft sand patch draws above the baked ground,
## so band trees baked under it vanished and left blocked, empty sand: the
## invisible walls down the left (and right) of the beach. Over sand the band is
## a palm grove of real sprites instead (above the sand), every edge cell dressed.
func _palm_band() -> void:
	var on_sand := func(c: Vector2i) -> bool:
		return c.y >= 8 and _sand.has(Vector2i(clampi(c.x, 0, cols - 1), clampi(c.y, 0, rows - 1)))
	var keep: Array = []
	for item: Array in _border_draw:
		if not on_sand.call(item[0] as Vector2i):
			keep.append(item)
	_border_draw.clear()
	_border_draw.append_array(keep)
	var rng := RandomNumberGenerator.new()
	var low := ["bk_dune_s", "bk_dune_m", "bush2_green", "ferns", "rock_m"]
	for c: Vector2i in _border_cells:
		if str(_border_cells[c]) != "tree" or not on_sand.call(c) or props.has(c):
			continue
		rng.seed = hash(Vector3i(911, c.x, c.y))
		var depth := _band_depth(c)
		var r := rng.randf()
		if depth <= 1 or r < (0.55 if depth == 2 else 0.7):
			if r < 0.6 or depth >= 2:
				var sp := prop("nature", "palm", c, 0, 0.0, false, rng.randf_range(0.42, 0.55))
				if sp:
					sp.position.x += rng.randf_range(-4.0, 4.0)
					sp.flip_h = rng.randf() < 0.5
			else:
				var nm: String = low[rng.randi_range(0, low.size() - 1)]
				var g := "props" if nm.begins_with("bk_") else "nature"
				if Art.has(g, nm):
					prop(g, nm, c, 0, 0.0, false, 0.3 if g == "props" else 0.5)


func interact(c: Vector2i, thing: Dictionary) -> bool:
	if Marina.interact(self, c, thing):
		return true
	match str(thing.get("type", "")):
		"note":
			tell([{"text": str(thing.get("text", "..."))}])
			return true
		"sea":
			# fish_at casts with the rod in hand, else says how to get it there
			_fish(c)
			return true
		"hut":
			if Marina.tier() >= 1:
				Marina.interact(self, c, {"type": "marina", "kind": "bait"})
			elif GameState.is_penguins():
				tell([{"text": "A thatched hut with surfboards leaning on it. Closed. A sign says 'back when the pier is'."}])
			else:
				tell([{"text": "A shuttered boardwalk stall. A card in the window: 'Open again when the harbour is.'"}])
			return true
		"sandbar_chest":
			GameState.run["flags"]["sandbar_chest"] = true
			things.erase(c)
			give("pearl", 1)
			give("map_scrap", 1)
			return true
		"wreck":
			_wreck()
			return true
	return false


## The galleon: loot every few days; the third search on a new day turns up the
## captain's log page (map_scrap) once: 'The Wreck's Log' (c14_04-16/12).
func _wreck() -> void:
	if int(GameState.run["flags"].get("wreck_day", 0)) >= int(GameState.run["day"]) - 3 and GameState.run["flags"].has("wreck_day"):
		hud.toast("Nothing new in the wreck yet.")
		return
	GameState.run["flags"]["wreck_day"] = int(GameState.run["day"])
	var ms := Marina.st()
	if int(ms["wreck_last"]) != int(GameState.run["day"]):
		ms["wreck_last"] = int(GameState.run["day"])
		ms["wreck_searches"] = int(ms["wreck_searches"]) + 1
		if int(ms["wreck_searches"]) == 3 and not (ms["quests"] as Dictionary).has("marina_wreck_log"):
			ms["quests"]["marina_wreck_log"] = true
			give("map_scrap", 1)
			tell([{"text": "Under a split plank: an oilskin pouch with a page of the captain's log. A sandbar is marked off the cove, and an X."}])
			return
	give(["copper", "iron", "shard"][randi() % 3], 2)


## Sea fish (c14_04-10): the sea's own shore pool; rowing out past the shallows
## (no land within 3 cells) adds the deep-water fish.
func _fish(c: Vector2i) -> void:
	var pool: Array = SEA_FISH.duplicate()
	for f in Marina.shore_pool():
		if not f in pool and f != "crab":
			pool.append(f)
	if player and player.vehicle_def().has("water"):
		var far := true
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var k := c + Vector2i(dx, dy)
				if in_content(k) and not _sea.has(k):
					far = false
		if far:
			for f in Marina.deep_pool():
				if not f in pool:
					pool.append(f)
	fish_at(c, pool)


func draw_map() -> void:
	draw_grass(8)
	WorldGen.draw_ground_detail(self, 86, 0.1)
	# Sand (with grass transition), wet strip, then sea with foam.
	var sand := _sand.duplicate()
	# The sand runs on under the side border bands (no straight grass strips down the edges).
	for y in range(8, rows + pad):
		for x in range(-pad, cols + pad):
			var cc := Vector2i(x, y)
			if not in_content(cc) and _sand.has(Vector2i(clampi(x, 0, cols - 1), clampi(y, 0, rows - 1))):
				sand[cc] = true
	for k in things:
		if str(things[k].get("type", "")) in ["dock", "ferry"] and not _pier_sea.has(k):
			sand[k] = true
	if Art.has("tiles", "sand"):
		if not soft_ground(sand, "sand", Color(0.3, 0.22, 0.1, 0.25)):
			draw_ground("sand", sand)
		# Wet sand along the tide line, soft-edged.
		var wet := {}
		for c: Vector2i in sand:
			for dd: Vector2i in [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if _sea.has(c + dd) or _pier_sea.has(c + dd):
					wet[c] = true
		if not soft_ground(wet, "wet_sand", Color(0, 0, 0, 0), Color(1.1, 1.08, 1.02, 0.7)):
			for c: Vector2i in wet:
				Art.draw_tile(self, "tiles", "sand_wet", Vector2(c * TILE), 4)
	else:
		draw_tileset_rect("shore_set", Rect2i(0, 8, cols, SEA_Y - 8), Color("e3cf8f"))
	# The marina quay: boardwalk planks (penguins) or concrete (gangsters).
	var qseam := "boardwalk" if GameState.is_penguins() else "pier_concrete"
	if not _quay.is_empty() and Art.has("seamless", qseam):
		soft_ground(_quay, qseam, Color(0.1, 0.08, 0.05, 0.3))
	if border_water_extra.is_empty():
		_draw_sea_cells()
	# Only the town lane is dirt (it runs over grass): draw_corridor draws it with the
	# town exit's corridor as one soft lane. On the sand, paths are just sand.
	_after_sea()


## No seamless sea art: the old per-cell sea with painted foam.
## Exit corridors: the quarry and marsh exits leave over sand that draw_map already
## runs under the band (a corridor shape on top drew a box outline); the town lane is dirt.
func draw_corridor(cells: Dictionary) -> void:
	var on_grass := {}
	for c: Vector2i in cells:
		if not _sand.has(Vector2i(clampi(c.x, 0, cols - 1), clampi(c.y, 0, rows - 1))):
			on_grass[c] = true
	on_grass.merge(cells_of([Rect2i(30, 1, 4, 8), TOWN_EXIT]))
	if not soft_ground(widen_path(on_grass), "dirt_track", Color(0.25, 0.15, 0.06, 0.3)):
		draw_ground("dirt", on_grass)


func _draw_sea_cells() -> void:
	_anim_layer.jobs.append(func(ci: CanvasItem) -> void:
		var frame := int(Time.get_ticks_msec() / 250) % 4
		var nm := "sea" if Art.has("tiles", "sea") else "water"
		var tt := Time.get_ticks_msec() / 1000.0
		var vis := _on_screen(_sea)
		for c: Vector2i in vis:
			if Art.has("seamless", "sea"):
				seam_cell(ci, "sea", c, Color.WHITE, Vector2(tt * 4.0, tt * 1.5))
				seam_cell(ci, "sea", c, Color(1, 1, 1, 0.3), Vector2(-tt * 2.5 + 40.0, tt * 3.0 + 60.0))
			elif not Art.draw_tile(ci, "tiles", nm, Vector2(c * TILE), 4 if nm == "sea" else frame):
				ci.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, TILE), Color("2f6fb5"))
		var foam_t := Art.tex("props", "bk_foam_%d" % (int(tt * 3.0) % 4))
		if foam_t:
			# The painted wave line: sand on top, surf, then sea; one window per edge cell.
			var fw := float(foam_t.get_width()) / 8.0
			for c: Vector2i in vis:
				if not _sea.has(c + Vector2i(0, -1)) and not things.get(c + Vector2i(0, -1), {}).get("type", "") == "dock":
					ci.draw_texture_rect_region(foam_t, Rect2(c.x * TILE, (c.y - 1) * TILE + 4, TILE, TILE * 1.5), Rect2(fw * posmod(c.x, 8), foam_t.get_height() * 0.25, fw, foam_t.get_height() * 0.6))
			return
		for c: Vector2i in _sea:
			if not _sea.has(c + Vector2i(0, -1)) and not things.get(c + Vector2i(0, -1), {}).get("type", "") == "dock":
				if not Art.draw_tile(ci, "tiles", "foam", Vector2(c * TILE), (frame + c.x) % 4):
					ci.draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, 2), Color(1, 1, 1, 0.5)))


func _after_sea() -> void:
	draw_exits()
	if not Art.has("buildings", "galleon"):
		var p := cell_center(Vector2i(5, 16))
		draw_rect(Rect2(p.x - 36, p.y - 20, 72, 18), Color("5a3a1a"))


func _place_props() -> void:
	if not Art.has("buildings", "galleon"):
		return
	var pen := GameState.is_penguins()
	var se := GameState.look_se()
	prop("buildings", "galleon", Vector2i(4, 20), 13)
	things.erase(Vector2i(5, 16))
	set_thing(10, 20, {"type": "wreck", "hint": "A: search the wreck"}, false)
	if pen:
		prop("buildings", "beach_hut", Vector2i(40, 12), 3, 0.0, true, 0.85)  # town-sized next to the hero
		set_thing(41, 13, {"type": "hut", "hint": "A: Surf & Bait Shack" if Marina.tier() >= 1 else "A: beach hut"}, false)
	else:
		_boardwalk()
	for c: Vector2i in [Vector2i(3, 10), Vector2i(20, 9), Vector2i(34, 9), Vector2i(57, 10), Vector2i(8, 11), Vector2i(50, 9), Vector2i(26, 10), Vector2i(94, 10), Vector2i(97, 16)]:
		prop("nature", "palm", c, 1)
	prop("props", "beached_boat", Vector2i(22, 20), 2)
	var bk := Art.has("props", "bk_umbrella_red")
	# The family beach follows the season (c14_04-20): full in summer, furled in
	# spring/fall, packed away in winter (driftwood piles instead).
	if se != "winter":
		prop("props", "bk_umbrella_red" if bk else "umbrella_red", Vector2i(16, 16), 1, 0.0, true, 0.35 if bk else 0.5)
	if se == "summer":
		prop("props", "bk_umbrella_blue" if bk else "umbrella_blue", Vector2i(37, 17), 1, 0.0, true, 0.35 if bk else 0.5)
		prop("props", "umbrella_yellow", Vector2i(24, 15), 1, 0.0, true, 0.5)
	prop("props", "bk_lifeguard" if bk else "lifeguard", Vector2i(27, 18), 0, 0.0, true, 0.35 if bk else 0.5)
	if bk:
		if se == "summer":
			prop("props", "bk_towel", Vector2i(18, 17), 0, 0.0, false, 0.3)
			prop("props", "bk_sandcastle", Vector2i(31, 17), 0, 0.0, true, 0.3)
			prop("props", "bk_sandcastle", Vector2i(20, 19), 0, 0.0, true, 0.26)
		elif se == "winter":
			for c: Vector2i in [Vector2i(18, 17), Vector2i(31, 17), Vector2i(24, 15)]:
				prop("props", "bk_driftwood_a" if c.x % 2 == 0 else "bk_driftwood_b", c, 0, 0.0, false, 0.3)
		# Small decals scattered over the sand (no pickup; the shells you can
		# take are the forage ones).
		var drng := RandomNumberGenerator.new()
		drng.seed = 4242
		var decals := ["bk_pebbles_s", "bk_pebbles_m", "bk_footprints", "bk_driftwood_a", "bk_driftwood_b", "bk_seaweed_a", "bk_seaweed_b", "bk_pebbles_s"]
		for i in 40:
			var dc := Vector2i(drng.randi_range(2, cols - 3), drng.randi_range(10, SEA_Y - 1))
			if things.has(dc) or blocked.has(dc) or props.has(dc) or not _sand.has(dc) or _quay.has(dc):
				continue
			var sp := prop("props", decals[drng.randi() % decals.size()], dc, 0, 0.0, false, 0.22)
			if sp:
				to_under(sp)
	# The bonfire burns except in winter (festival nights aside).
	if se != "winter" or GameState.festival_today() != "":
		if anim_prop("props", "bonfire", Vector2i(36, 15), 0, 8.0, true):
			blocked[Vector2i(36, 15)] = true  # you walk round a fire, not through it
	for c: Vector2i in [Vector2i(8, 29), Vector2i(44, 30), Vector2i(58, 26), Vector2i(70, 40), Vector2i(94, 38)]:
		anim_prop("props", "buoy", c, 0, 2.0)
	anim_prop("props", "tide_pool", Vector2i(48, 17), 1, 3.0)
	anim_prop("props", "tide_pool", Vector2i(56, 16), 1, 3.0)
	anim_prop("props", "tide_pool", Vector2i(SANDBAR.position.x + 1, SANDBAR.position.y + 2), 1, 3.0)
	for c: Vector2i in [Vector2i(53, 18), Vector2i(60, 19), Vector2i(2, 15), Vector2i(SANDBAR.end.x - 1, SANDBAR.position.y)]:
		prop("nature", "rock_l" if Art.has("nature", "rock_l") else "rock_m", c, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	for i in 14:
		var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(9, SEA_Y - 2))
		if things.has(c) or blocked.has(c) or not _sand.has(c) or _quay.has(c):
			continue
		if Art.has("props", "bk_dune_s"):
			prop("props", ["bk_dune_s", "bk_dune_m", "bk_dune_l"][rng.randi_range(0, 2)], c, 1, 0.0, true, 0.3)
		else:
			prop("nature", "dune_%d" % rng.randi_range(0, 9), c)
	for k in things.keys():
		if str(things[k].get("type", "")) == "forage":
			var item := str(things[k]["item"])
			var nm: String = {"seashell": ["shell_a", "shell_b", "shell_c", "starfish"][(k.x + k.y) % 4], "coconut": "coconut_p", "fiber": "seaweed", "crab": "crab"}.get(item, "shell_a")
			var sc := 0.5
			if Art.has("props", "bk_shell_conch") and item in ["seashell", "fiber"]:
				nm = (["bk_shell_conch", "bk_shell_scallop", "bk_shell_clam", "bk_shell_cowrie", "bk_starfish_orange", "bk_starfish_pink", "bk_sand_dollar_a"][(k.x * 3 + k.y) % 7]) if item == "seashell" else "bk_seaweed_c"
				sc = 0.22
			if props.has(k):
				(props[k] as Node).queue_free()
			prop("props", nm, k, 0, 0.0, true, sc)
	# (The old tiles/pier sprites under the dock cells are gone: DockLayer draws
	# every pier, c14_04-26.)
	_west_tip()


## The west pier's tip: the moored colony ferry and Skipper Barnacle (penguins),
## or the Tidewater Launch's boat and Dutch's lantern (gangsters) (c14_04-01/03).
func _west_tip() -> void:
	var t := _tip
	prop("props", "moor_a", t + Vector2i(-1, -2), 0, 0.0, false, 0.15)
	prop("props", "dock_lantern", t + Vector2i(1, -1), 0, 0.0, false, 0.15)
	if GameState.is_penguins():
		anim_prop("props", "ferry_moored", t + Vector2i(2, 1), 2, 2.0, false, 0.5)
		prop("props", "gangplank", t + Vector2i(1, 0), 0, 0.0, false, 0.12)
		anim_prop("fx", "merkitty_b", t + Vector2i(0, -1), 0, 3.0, false, 0.4)  # Skipper Barnacle
	else:
		prop("props", "tugboat", t + Vector2i(2, 1), 2, 0.0, false, 0.45)
		prop("props", "crates_pallet", t + Vector2i(-1, -1), 0, 0.0, false, 0.3)


## Gangster beach: a boardwalk along row 11 with the vendor's stall, a shuttered
## arcade and neon (c14_04-04 / 04-17).
func _boardwalk() -> void:
	for x in range(36, 48, 2):
		var nm := "mk_boardwalk_end" if x == 36 else ("mk_boardwalk_corner" if x == 46 else "mk_boardwalk")
		var sp := prop("props", nm, Vector2i(x, 11), 1, 0.0, false, 0.28)
		if sp:
			to_under(sp)
	prop("props", "stall2_red" if Marina.vendor_here() else "stall2_red_closed", Vector2i(40, 10), 2, 0.0, true, 0.3)
	set_thing(41, 11, {"type": "hut", "hint": "A: boardwalk vendor"}, false)
	prop("furniture", "stalls_closed", Vector2i(44, 10), 2, 0.0, true, 0.35)
	anim_prop("props", "neon_open", Vector2i(39, 9), 0, 2.0, false, 0.4)
	prop("props", "crates_b", Vector2i(48, 11), 0, 0.0, true, 0.3)


## The marina, dressed for its tier (both arcs; gangster arc gets concrete,
## cranes and containers). Baked-safe: everything through prop()/anim_prop().
func _dress_marina() -> void:
	var mt := Marina.tier()
	var pen := GameState.is_penguins()
	var ox := MARINA_X
	# Harbour office (Hollis) with the board: shuttered until tier 1.
	prop("props", "boathouse", Vector2i(ox + 3, QUAY_Y - 4), 6, 0.0, true, 0.3)
	prop("props", "dock_lantern", Vector2i(PIER_X - 1, QUAY_Y - 2), 0, 0.0, false, 0.15)
	if not pen:
		prop("props", "crane", Vector2i(ox + 28, QUAY_Y - 4), 2, 0.0, true, 0.5)
		for i in 3:
			prop("props", ["cargo_red", "cargo_grey", "cargo_yellow"][i], Vector2i(ox + 1 + i * 3, 12), 2, 0.0, true, 0.35)
	if mt < 1:
		prop("props", "rowboat2_c" if Art.has("props", "rowboat2_c") else "beached_boat", Vector2i(PIER_X + 3, QUAY_Y - 1), 1, 0.0, false, 0.3)
		return
	for y in [QUAY_Y + 3, QUAY_Y + 7, QUAY_Y + 11]:
		prop("props", "dock_lantern", Vector2i(PIER_X - 1, y), 0, 0.0, false, 0.15)
		prop("props", "moor_a", Vector2i(PIER_X + 3, y), 0, 0.0, false, 0.15)
	prop("props", "rowboat2_idle", Vector2i(PIER_X - 3, QUAY_Y + 4), 1, 0.0, false, 0.3)
	if mt >= 2:
		prop("props", "fish_market", Vector2i(ox + 15, QUAY_Y - 4), 3, 0.0, true, 0.6)
		prop("props", "canoe2", Vector2i(ox + 23, QUAY_Y - 2), 1, 0.0, false, 0.3)
		prop("props", "fish_rack", Vector2i(ox + 26, QUAY_Y - 3), 1, 0.0, true, 0.3)
		prop("props", "stall2_blue" if pen else "stall2_purple", Vector2i(ox + 22, QUAY_Y - 4), 2, 0.0, true, 0.3)
		prop("props", "tugboat", Vector2i(PIER_X + 5, QUAY_Y + 7), 2, 0.0, false, 0.45)
		for x in range(ox + 2, ox + 26, 2):  # the breakwater arm
			prop("nature", "rock_l" if Art.has("nature", "rock_l") else "rock_m", Vector2i(x, QUAY_Y + 20), 1, 0.0, false)
		prop("props", "crab_pot_water", Vector2i(ox + 4, QUAY_Y + 6), 0, 0.0, false, 0.3)
		prop("props", "crab_pot_water", Vector2i(ox + 7, QUAY_Y + 8), 0, 0.0, false, 0.3)
	if mt >= 3:
		prop("props", "trawler", Vector2i(PIER_X + 5, QUAY_Y + 12), 2, 0.0, false, 0.5)
		prop("buildings", "lighthouse", Vector2i(95, QUAY_Y + 4), 2, 0.0, true, 0.45)
		anim_prop("props", "lighthouse_lamp", Vector2i(95, QUAY_Y - 2), 0, 3.0, false, 0.3)
		if Marina.npc_here("saffi", 12):
			prop("props", "cargo_ship", Vector2i(PIER_X + 6, QUAY_Y + 17), 6, 0.0, false, 0.4)
	else:
		prop("buildings", "lighthouse_broken", Vector2i(95, QUAY_Y + 4), 2, 0.0, true, 0.45)
	if mt >= 4:
		prop("props", "stall2_white", Vector2i(ox + 9, 12), 2, 0.0, true, 0.35)
		prop("props", "umbrella_yellow", Vector2i(ox + 13, 13), 1, 0.0, true, 0.5)
		prop("props", "umbrella_red", Vector2i(ox + 6, 13), 1, 0.0, true, 0.5)
