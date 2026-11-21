class_name WorldGen
extends RefCounted
## Fills a GameMap with life: dense ground decoration, tree lines, rock fields,
## flower patches, wildlife that wanders, and a painted parallax backdrop.
## Everything is seeded per map so it looks the same every visit.

const TILE := GameMap.TILE


## Scatter small ground decorations (drawn, not nodes) over free cells.
## Call from _draw(). density 0..1.
## Smooth value noise in [-1, 1]. `scale` = cells per bump.
static func noise2(x: float, y: float, seed_v: int, scale := 6.0) -> float:
	var fx := x / scale
	var fy := y / scale
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash01(x0, y0, seed_v)
	var b := _hash01(x0 + 1, y0, seed_v)
	var c := _hash01(x0, y0 + 1, seed_v)
	var d := _hash01(x0 + 1, y0 + 1, seed_v)
	var v := lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
	return v * 2.0 - 1.0


static func fbm(x: float, y: float, seed_v: int, scale := 8.0) -> float:
	return noise2(x, y, seed_v, scale) * 0.6 + noise2(x, y, seed_v + 7, scale * 0.5) * 0.3 + noise2(x, y, seed_v + 13, scale * 0.25) * 0.1


static func _hash01(x: int, y: int, seed_v: int) -> float:
	var h := int((x * 374761393 + y * 668265263 + seed_v * 1274126177) & 0x7fffffff)
	h = int((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h % 10007) / 10007.0


## Looks that mean "forage you can pick": decor never draws these, every forage
## thing uses one of them (forest, region, meadow and this file).
const FORAGE_LOOKS := ["mushrooms_fall", "wildflowers2"]


static func draw_ground_detail(m: GameMap, seed_v: int, density := 0.12, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var season := GameState.look_se()
	var later := {}  # texture name -> feet positions: drawn grouped after the loop (batches)
	# Every cell rolls from its own seed, so a clipped painter pass (one baked chunk)
	# can walk just the cells near it and draw the same pixels.
	var cr := Rect2i(1, 1, m.cols - 2, m.rows - 2).intersection(m.clip_cells())
	for y in range(cr.position.y, cr.end.y):
		for x in range(cr.position.x, cr.end.x):
			var c := Vector2i(x, y)
			# Roll first so each cell's roll never depends on its neighbours
			# (otherwise the decor reshuffles whenever a cell fills up).
			rng.seed = hash(Vector3i(seed_v, x, y))
			var r := rng.randf()
			if m.blocked.has(c) or m.things.has(c) or avoid.has(c):
				continue
			if r > density:
				continue
			var at := Vector2(x * TILE, y * TILE)
			# Some of the ground life is real forage you can pick (respawns daily).
			if r < density * 0.05 and m.resources_here and not m.things.has(c):
				var key := "fg_%s_%d_%d" % [m.scene_id(), x, y]
				if GameState.respawned(key, 2):  # Honey Sense shortens it
					var item: String = {"spring": "flower", "summer": "wild_herb", "fall": "mushroom", "winter": "wild_leek"}.get(season, "mushroom")
					if season == "fall" and rng.randf() < 0.03 and GameState.skill_level("foraging") >= 5:
						item = "truffle"
					m.set_thing(x, y, {"type": "forage", "key": key, "item": item, "hint": "A: pick %s" % GameState.item_name(item)}, false)
					var nm: String = {"flower": "wildflowers2", "wild_herb": "wildflowers2", "mushroom": "mushrooms_fall", "truffle": "mushrooms_fall", "wild_leek": "gdeco_tuft_a"}.get(item, "flowers")
					m.prop("nature", nm if Art.has("nature", nm) else "flowers", c, 0, 0.0, false)
				continue
			if season == "spring" or season == "summer":
				# (deco_N tiles are opaque squares in another green: they read as a checkerboard.)
				if r < density * 0.8 and not Art.has("nature", "gdeco_tuft_a"):
					Art.draw_tile(m, "tiles", "deco_%d" % rng.randi_range(0, 5), at)
				elif r < density * 0.8 and rng.randf() < 0.5:
					(later.get_or_add(["gdeco_tuft_a", "gdeco_tuft_b", "gdeco_tuft_c"][rng.randi_range(0, 2)], []) as Array).append(at + Vector2(rng.randf_range(4, 12), rng.randf_range(10, 16)))
				elif r < density * 0.8:
					pass
				elif Art.has("nature", "gdeco_tuft_a") and rng.randf() < 0.6:
					(later.get_or_add(["gdeco_tuft_a", "gdeco_tuft_b", "gdeco_tuft_c", "gdeco_clover", "gdeco_dandelion"][rng.randi_range(0, 4)], []) as Array).append(at + Vector2(8, 16))
				else:
					(later.get_or_add("flowers" if season == "spring" else "sunflowers", []) as Array).append(at + Vector2(8, 16))
			elif season == "fall":
				if r < density * 0.6:
					(later.get_or_add("flowers_fall", []) as Array).append(at + Vector2(8, 16))
				else:
					# Never mushrooms_fall here: that look means "forage, pick me" (FORAGE_LOOKS).
					var fd: Array = ["grass_tuft_fall", "grass_tuft_fall", "fd_acorns", "fd_pinecones"]
					var fnm: String = fd[rng.randi_range(0, fd.size() - 1)]
					(later.get_or_add(fnm if Art.has("nature", fnm) else "flowers_fall", []) as Array).append(at + Vector2(8, 16))
			else:
				if Art.has("nature", "grass_tuft_winter") and rng.randf() < 0.5:
					(later.get_or_add("grass_tuft_winter" if rng.randf() < 0.7 else "grass_tuft_frost", []) as Array).append(at + Vector2(8, 16))
	# Group order = first appearance over the whole map (a clipped pass sees only
	# some groups: it keeps the full pass's order so overlaps stack the same way).
	var okey := "gd_order:%d:%s" % [seed_v, season]
	var order: Array = later.keys()
	if not Art.clip.has_area():
		m._geom_memo[okey] = order
	elif m._geom_memo.has(okey):
		order = (m._geom_memo[okey] as Array).filter(func(k): return later.has(k))
		for k in later:
			if not order.has(k):
				order.append(k)
	for nm: String in order:
		for p: Vector2 in later[nm]:
			Art.draw_prop(m, "nature", nm, p)
	# Placed once per map (this runs from _draw, which repeats on every redraw).
	if not m.has_meta("wx_dressed"):
		m.set_meta("wx_dressed", true)
		# Deferred: the map's paths (step_word / ground_seam) are drawn later in draw_map,
		# and drifts and puddles must stay off them.
		var host: GameMap = m._painter_of if m._painter_of != null else m
		_after_paths.call_deferred(host, seed_v + 99, avoid)


## Runs once the map's paths are drawn: scatter off the paths, then weather dressing.
static func _after_paths(m: GameMap, seed_v: int, avoid: Dictionary) -> void:
	if not is_instance_valid(m):
		return
	clear_paths(m)
	mark_dead_ends(m)
	weather_dressing(m, seed_v, avoid)


## Scatter (trees, rocks, logs, stumps, bushes, boulder-sized props) that landed on a
## drawn path is removed: paths stay walkable and readable (c5_12 #5).
static func clear_paths(m: GameMap) -> int:
	var n := 0
	for c: Vector2i in m.props.keys():
		if not on_path(m, c):
			continue
		var t := str(m.things.get(c, {}).get("type", ""))
		var node: Variant = m.props[c]
		# a generic prop wider than its cell (crates with a width) is left alone: removing it would leave its other cells as an invisible wall
		if t in ["tree", "rock", "log", "stump", "bush", "weeds", "grove"] or (t == "" and _small_prop(node) and m.blocked.has(c) and not m.blocked.has(c + Vector2i(1, 0))):
			m.things.erase(c)
			m.blocked.erase(c)
			m.hard.erase(c)
			m.props.erase(c)
			if node is Node and is_instance_valid(node):
				(node as Node).queue_free()
			n += 1
	if n > 0:
		m._flows.clear()
	return n


## A path that just stops reads as a bug: give each dead end a reason to walk there
## (a bench, a milestone or a lantern) (c5_12 #4). Ends by an exit, a door, a sign
## or anything you can use are left alone. Returns the cells marked.
const DEAD_END_LOOKS := ["bench_wood", "lantern_lit", "ri_cairn"]  # no "milestone": its art read as a gravestone (c14_02-05)


static func mark_dead_ends(m: GameMap, most := 3) -> Array:
	var path := {}
	for c: Vector2i in m.step_word:
		if on_path(m, c):
			path[c] = true
	for c: Vector2i in m.ground_seam:
		if on_path(m, c):
			path[c] = true
	var cands: Array = []
	for c: Vector2i in path:
		if c.x < 3 or c.y < 3 or c.x > m.cols - 4 or c.y > m.rows - 4:
			continue
		var off := Vector2.ZERO
		var n := 0
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				if (dx != 0 or dy != 0) and path.has(c + Vector2i(dx, dy)):
					off += Vector2(dx, dy)
					n += 1
		if n < 10:
			continue
		off /= n
		if off.length() < 1.9:
			continue
		cands.append([off.length(), c, off])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var marked: Array = []
	for cd in cands:
		if marked.size() >= most:
			break
		var c: Vector2i = cd[1]
		var near := false
		for o: Vector2i in marked:
			if (o - c).length() < 8.0:
				near = true
		for e in m.exits:
			var r: Rect2i = e["rect"]
			if r.grow(5).has_point(c):
				near = true
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var t := str(m.things.get(c + Vector2i(dx, dy), {}).get("type", ""))
				if t != "" and not t in ["tree", "rock", "log", "stump", "bush", "weeds", "forage", "grove", "water"]:
					near = true  # a door, sign, npc spot or station is already the reason
		for bp: Array in m._bprops:
			if (Vector2(bp[1]) - Vector2(c)).length() < 6.0:
				near = true
		if near or m.blocked.has(c) or m.things.has(c) or m.props.has(c) or m.is_water_cell(c):
			continue
		var look: String = DEAD_END_LOOKS[absi(hash(Vector2i(c.x, c.y + m.cols))) % DEAD_END_LOOKS.size()]
		if not Art.has("props", look):
			look = "ri_cairn" if Art.has("props", "ri_cairn") else "bench_wood"
		if m.prop("props", look, c, 0, 0.0, false) != null:  # never solid: it can't wall off anything
			marked.append(c)
	return marked


## Weather on the ground (Prompts 09 wx sheet): puddles on wet days, snowdrifts
## and icicles in winter. Decorative only; they never block.
static func weather_dressing(m: GameMap, seed_v: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# A region's own weather wins over the calendar (no puddles in snowy colony_ice or the clear sky).
	var rd: Variant = m.get("R")
	var ov := str((rd as Dictionary).get("weather", "")) if rd is Dictionary else ""
	# The look season (a region's own "season") rules the ground, not the calendar:
	# jungles, deserts and the sky never get snowdrifts (c5_14 #4).
	var winter := (GameState.look_se() == "winter" and not ov in WARM_WEATHER) or ov in ["snow", "blizzard"]
	var wet := GameState.is_wet() and ov in ["", "rain", "storm"]
	if not wet and not winter:
		return
	if not is_instance_valid(m):
		return
	var n := int(m.cols * m.rows * (0.012 if wet else 0.008))
	for i in n:
		var c := Vector2i(rng.randi_range(2, m.cols - 3), rng.randi_range(2, m.rows - 3))
		if m.blocked.has(c) or m.things.has(c) or avoid.has(c) or m.is_water_cell(c):
			continue
		if on_path(m, c):
			continue  # no drifts or puddles on paths, roads or plaza paving (c5_14 #2)
		if wet and Art.has("props", "puddle_storm_0") and int(Art.info("props", "puddle_storm_0").get("frames", 1)) > 1:
			_puddle(m, c, rng, GameState.weather_today() == "storm")
		elif winter and Art.has("props", "snowdrift_0"):
			m.prop("props", "snowdrift_%d" % rng.randi_range(0, 5), c, 0, 0.0, false)


## Weathers that mean a warm place: no winter dressing even in a winter month.
const WARM_WEATHER := ["sun", "dust", "fireflies"]


## A drawn path, road or paved cell (tile paths mark step_word, soft paths ground_seam,
## exit corridors _ext_paths). Weather dressing and decor keep off these.
static func on_path(m: GameMap, c: Vector2i) -> bool:
	if m._ext_paths.has(c):
		return true
	var sm := str(m.ground_seam.get(c, ""))
	if sm == "":
		# Tile paths mark a step word; soft grass/snow/moss patches mark one too.
		return m.step_word.has(c) and not str(m.step_word[c]) in ["grass", "snow", "moss", "leaves", "water"]
	# A soft ground patch that is the map's base (grass/moss/snow fields) is not a path.
	for w in ["path", "road", "pave", "cobble", "stone", "flag", "brick", "plank", "trodden", "dirt", "sand_path", "asphalt"]:
		if w in sm:
			return true
	return false


## One rain puddle, flat on the ground. Uses the redrawn 3-frame storm puddles
## for every wet day (the old puddle_0..5 cuts held a different, rock-ringed
## pond in every frame, so they popped): smaller in plain rain, a bigger, quicker
## ripple in storms. Needs its neighbours free too, so a puddle never spills
## onto a building, fence or the water's edge; each starts on its own frame and
## pace so a field of puddles never pulses in step.
static func _puddle(m: GameMap, c: Vector2i, rng: RandomNumberGenerator, storm: bool) -> void:
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var n := c + d
		if m.blocked.has(n) or m.is_water_cell(n) or (m.things.has(n) and str((m.things[n] as Dictionary).get("type", "")) != "pet_animal"):
			return
	var a := m.anim_prop("props", "puddle_storm_%d" % rng.randi_range(0, 3), c, 0, 2.6 if storm else 2.0, false, 0.3 if storm else 0.22)
	if a == null:
		return
	a.position = m.cell_center(c) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2))
	a.offset = Vector2.ZERO  # flat decal: centred on its cell, not stood on its feet
	a.flip_h = rng.randf() < 0.5
	a.frame = rng.randi_range(0, 2)
	a.speed_scale = rng.randf_range(0.8, 1.15)
	a.modulate = Color(1, 1, 1, 0.9)
	m.to_under(a)


## Place a tree line along a rectangle's edge (inside it), leaving gaps at `gaps`.
static func tree_border(m: GameMap, rect: Rect2i, seed_v: int, gaps: Array = [], every := 2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x, every):
		cells.append(Vector2i(x, rect.position.y))
		cells.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.position.y + 1, rect.end.y - 1, every):
		cells.append(Vector2i(rect.position.x, y))
		cells.append(Vector2i(rect.end.x - 1, y))
	for c in cells:
		var skip := false
		for g: Rect2i in gaps:
			if g.has_point(c):
				skip = true
		if skip or m.things.has(c) or m.is_cleared(c):
			continue
		var jitter := Vector2i(rng.randi_range(0, 1), 0) if every > 1 else Vector2i.ZERO
		var cc := c + jitter
		if cc.x >= m.cols - 1:
			cc = c
		m.set_thing(cc.x, cc.y, {"type": "tree", "hp": 4, "hint": "A: chop"})
		m.prop("nature", GameState.tree_sprite(rng.randi_range(0, 2)), cc)


## A map's scatter theme (regions.json gen.theme, battlefields from tools/bf_themes.py):
## {"trees": [names] ([] = no tree clumps), "rocks": [names], "logs": bool, "bushes": bool,
##  "band": [names] (border undergrowth; [] = none)}. Names are nature/ or props/ art
## ("props/x" or bare). Keeps green trees and berry bushes off pavement, ash and snow.
static func theme(m: GameMap) -> Dictionary:
	var rd = m.get("R")
	if rd is Dictionary:
		var g = (rd as Dictionary).get("gen", {})
		if g is Dictionary and (g as Dictionary).get("theme") is Dictionary:
			return (g as Dictionary)["theme"]
	return {}


## [group, name] for a theme art name ("props/x", or bare: nature first, then props).
static func theme_art(nm: String) -> Array:
	if "/" in nm:
		return [nm.get_slice("/", 0), nm.get_slice("/", 1)]
	return ["nature" if Art.has("nature", nm) else "props", nm]


## Random clusters of trees inside a rect.
static func tree_clumps(m: GameMap, rect: Rect2i, seed_v: int, clumps: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var th := theme(m)
	var tpool: Array = th.get("trees", [])
	if th.has("trees") and tpool.is_empty():
		return  # pavement / deck / sky: no tree clumps at all
	for i in clumps:
		var cx := rng.randi_range(rect.position.x, rect.end.x - 1)
		var cy := rng.randi_range(rect.position.y, rect.end.y - 1)
		var n := rng.randi_range(2, 5)
		for k in n:
			var c := Vector2i(cx + rng.randi_range(-2, 2), cy + rng.randi_range(-1, 1))
			if not rect.has_point(c) or m.things.has(c) or m.blocked.has(c) or avoid.has(c) or m.is_cleared(c):
				continue
			if not tpool.is_empty():
				var ga := theme_art(str(tpool[rng.randi_range(0, tpool.size() - 1)]))
				if Art.has(str(ga[0]), str(ga[1])):
					if str(ga[0]) == "nature" and str(ga[1]).contains("tree") or str(ga[1]).contains("pine"):
						m.set_thing(c.x, c.y, {"type": "tree", "hp": 4, "hint": "A: chop"})
					m.prop(str(ga[0]), str(ga[1]), c)  # solid either way
				continue
			m.set_thing(c.x, c.y, {"type": "tree", "hp": 4, "hint": "A: chop"})
			m.prop("nature", GameState.tree_sprite(rng.randi_range(0, 2)), c)


## Rocks, logs, stumps, bushes scattered as interactable props.
static func scatter_props(m: GameMap, rect: Rect2i, seed_v: int, count: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var season := GameState.look_se()
	var th := theme(m)
	var rocks: Array = th.get("rocks", [])
	for i in count:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		var r := rng.randf()  # rolled first so the layout doesn't shift as things are cleared
		if m.things.has(c) or m.blocked.has(c) or avoid.has(c) or (r < 0.62 and m.is_cleared(c, 8 if r < 0.35 else 10)):
			continue
		# Themed ground: logs/stumps and berry bushes only where the theme allows them
		# (they turn into rocks or nothing on pavement, decks, ash and snow).
		if r >= 0.35 and r < 0.62 and not bool(th.get("logs", true)):
			r = 0.3 if not rocks.is_empty() else 2.0
		elif r >= 0.62 and not bool(th.get("bushes", true)):
			r = 0.3 if not rocks.is_empty() and r < 0.8 else 2.0
		if r > 1.0:
			continue
		if r < 0.35 and not rocks.is_empty():
			var ga := theme_art(str(rocks[rng.randi_range(0, rocks.size() - 1)]))
			if Art.has(str(ga[0]), str(ga[1])):
				m.set_thing(c.x, c.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
				m.prop(str(ga[0]), str(ga[1]), c)
			continue
		if r < 0.35:
			var nm := "rock_s" if r < 0.2 else "rock_m"
			if season == "winter" and Art.has("nature", nm.replace("rock_", "rock_snow_")):
				nm = nm.replace("rock_", "rock_snow_")
			elif season == "fall" and Art.has("nature", "rock_fall"):
				nm = "rock_fall"
			m.set_thing(c.x, c.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
			m.prop("nature", nm, c)
		elif r < 0.5:
			var nm: String = {"fall": "log_fall", "summer": "logs", "winter": "log_snow"}.get(season, "log")
			m.set_thing(c.x, c.y, {"type": "log", "hp": 2, "hint": "A: chop"})
			m.prop("nature", nm if Art.has("nature", nm) else "log", c, 1 if nm in ["log", "log_snow"] else 0)
		elif r < 0.62:
			var nm: String = {"fall": "stump_fall", "winter": "stump_snow"}.get(season, "stump")
			m.set_thing(c.x, c.y, {"type": "stump", "hp": 2, "hint": "A: chop"})
			m.prop("nature", nm if Art.has("nature", nm) else "stump", c)
		else:
			var key := "bush_%s_%d_%d" % [m.scene_id(), c.x, c.y]
			var has := GameState.respawned(key, 3)  # berries come back every 3 days (was daily: a jam battery)
			m.set_thing(c.x, c.y, {"type": "bush", "key": key, "berries": has, "hint": "A: pick berries" if has else ""})
			m.prop("nature", GameState.bush_sprite(has), c)


## Wildlife: small critters that hop around and flee from the player.
static func add_critters(m: GameMap, rect: Rect2i, seed_v: int, count: int, kinds: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pool: Array = critter_pool(kinds if not kinds.is_empty() else ["sparrow", "sparrow", "butterfly_orange", "butterfly_blue", "rabbit", "squirrel", "bee"])
	var wet: Array[Vector2i] = []  # water cells in the rect, for fish (never on land)
	for i in count:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
		if kind in WATER_CRITTERS:
			if wet.is_empty():
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						if _deep_water(m, Vector2i(x, y)):
							wet.append(Vector2i(x, y))
				if wet.is_empty():
					wet.append(Vector2i(-9999, -9999))  # none here: skip fish
			c = wet[rng.randi_range(0, wet.size() - 1)]
			if c.x == -9999:
				continue
		elif m.blocked.has(c) or m.is_water_cell(c):
			continue
		elif kind in TAKE_OFF and not _near_water(m, c, 2):
			continue  # c14b_09-23 / 11-15: waders stay by the water
		var cr := Critter.new()
		cr.map = m
		cr.kind = kind
		cr.position = m.cell_center(c)
		cr.home = cr.position
		m.add_child(cr)


## The winter look of a sprite when the look season is winter and the art exists:
## buildings/house(_2/_3)_snow, woodcutter_hut_snow, fountain_frozen,
## props/fountain2_frozen, props/planter2_N_winter, nature/log_snow (C5 P3).
const WINTER_LOOKS := {"house": "house_snow", "house_2": "house_2_snow", "house_3": "house_3_snow", "woodcutter_hut": "woodcutter_hut_snow",
	"fountain": "fountain_frozen", "fountain2": "fountain2_frozen", "planter2_0": "planter2_0_winter", "planter2_1": "planter2_1_winter",
	"planter2_2": "planter2_2_winter", "planter2_3": "planter2_3_winter", "log": "log_snow",
	"flowerbed_pink": "flowerbed_pink_winter", "hedge2_h": "hedge2_h_winter", "topiary_a": "topiary_a_winter", "hedge2_ball": "hedge2_ball_winter", "bench2_wood_a": "bench2_wood_a_winter", "statue": "statue_winter", "trellis": "trellis_winter", "stone_arch": "stone_arch_winter",
	"flowerbed_blue": "flowerbed_blue_winter", "flowerbed_red": "flowerbed_red_winter", "flowerbed_yellow": "flowerbed_yellow_winter", "topiary_b": "topiary_b_winter", "bench2_iron_a": "bench2_iron_a_winter", "wedding_arch": "wedding_arch_winter", "cat_statue": "cat_statue_winter", "statue_cane": "statue_cane_winter",
	"picket2_h": "picket2_h_winter", "fence2_wood_h": "fence2_wood_h_winter", "fence2_iron_h": "fence2_iron_h_winter", "fence2_stone_h": "fence2_stone_h_winter", "bench2_green_a": "bench2_green_a_winter", "well_stone": "well_stone_winter", "birdbath": "birdbath_winter", "scarecrow_knight": "scarecrow_knight_winter",
	"dc_y_arbor_swing": "dc_y_arbor_swing_winter", "dc_y_herb_box": "dc_y_herb_box_winter", "dc_y_wheelbarrow": "dc_y_wheelbarrow_winter", "dc_y_sundial": "dc_y_sundial_winter", "dc_y_rain_barrel": "dc_y_rain_barrel_winter", "dc_y_pin_statue": "dc_y_pin_statue_winter", "dc_y_twin_lamp": "dc_y_twin_lamp_winter", "dc_y_penguin_topiary": "dc_y_penguin_topiary_winter"}


static func winter_look(group: String, name: String) -> String:
	if GameState.look_se() != "winter":
		return name
	if not WINTER_LOOKS.has(name):
		# New outdoor art (yard decor, c10b_03) needs no table entry: a drawn
		# <name>_winter / <name>_snow twin is used when it exists.
		for suf in ["_winter", "_snow"]:
			if Art.has(group, name + suf):
				return name + suf
		return name
	var w: String = WINTER_LOOKS[name]
	return w if Art.has(group, w) else name


## Ground birds whose walk strip is a flying pose: they take off only when startled.
const TAKE_OFF := ["duck", "heron"]


## Kinds that live in water only: spawned on water cells and kept there.
## Day-only and warm-weather critters (c14_16-06): no butterflies, bees or wading herons
## at 9pm or in the snow. At night the day crowd gives way to owls, bats and (not in
## winter) fireflies; in winter the warm crowd goes. Never an empty pool.
const DAY_ONLY := ["bee", "dragonfly", "sparrow", "pigeon", "seagull", "heron", "duck", "robin", "finch", "blue_jay", "ladybug", "grasshopper"]
const WARM_ONLY := ["bee", "dragonfly", "frog", "ladybug", "grasshopper", "snail", "turtle", "heron", "duck"]
static func critter_pool(pool: Array, night := -1, winter := -1, wet := -1) -> Array:
	var is_night := GameState.is_night() if night < 0 else night == 1
	var is_winter := GameState.look_se() == "winter" if winter < 0 else winter == 1
	var is_wet := (GameState.is_wet() and night < 0) if wet < 0 else wet == 1  # a pinned night/day call (tests) pins dry weather too
	var out: Array = []
	for k: String in pool:
		var day_only := k in DAY_ONLY or k.begins_with("butterfly")
		var warm_only := k in WARM_ONLY or k.begins_with("butterfly")
		if (is_night and day_only) or (is_winter and warm_only):
			continue
		if is_wet and (k in FLUTTERS or k in ["hedgehog", "squirrel", "snake"]):
			continue  # c14b_09-28: no butterflies in a storm; small critters shelter
		out.append(k)
	if is_night:
		for k in (["owl", "bat"] if is_winter else ["owl", "bat", "firefly"]):
			if Art.has("wildlife/" + k, "idle"):
				out.append(k)
	if out.is_empty():
		out = pool.filter(func(k): return not str(k).begins_with("butterfly") and k != "bee") if not pool.is_empty() else []
	return out if not out.is_empty() else ["rabbit"]
const WATER_CRITTERS := ["fish_jump"]  # (jungle jellies float in the air: flyers)


static func _near_water(m: GameMap, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if m.is_water_cell(c + Vector2i(dx, dy)):
				return true
	return false


## A water cell with water on all four sides (a fish never sits on the shore line).
static func _deep_water(m: GameMap, c: Vector2i) -> bool:
	if not m.is_water_cell(c) or m.hard.has(c):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not m.is_water_cell(c + d):
			return false
	return true


## A painted sky strip behind the map (parallax), plus distant hills.
static func add_backdrop(m: GameMap, kind := "hills") -> void:
	# A map that fills the whole screen never shows its backdrop: skip the overdraw.
	if (m.cols + 2 * m.pad) * GameMap.TILE >= 300 and (m.rows + 2 * m.pad) * GameMap.TILE >= 520 and kind != "space":
		return
	var bd := Backdrop.new()
	bd.kind = kind
	bd.map = m
	m.add_child(bd)
	m.move_child(bd, 0)


## A simple critter: a drawn animal that wanders (C14b P6: idle life per kind).
## Perching birds sit on the ground, peck and hop, take off with an eased lift when
## startled and land again later; butterflies/bees flutter on wobbling paths;
## rabbits/frogs hop; the eagle soars; fish show ripple rings and leap now and then;
## fireflies pulse. Every critter has its own phase/speed (no lockstep), 1-frame
## idles breathe and peck/glance, and everything respects reduced motion.
const PERCHERS := ["sparrow", "robin", "finch", "pigeon", "crow", "seagull", "blue_jay", "owl", "hawk"]
const FLUTTERS := ["butterfly_orange", "butterfly_blue", "butterfly_yellow", "butterfly_purple", "butterfly", "bee", "dragonfly", "firefly"]
const HOPPERS := ["rabbit", "moon_rabbit", "frog", "grasshopper"]
const STILL_KINDS := ["six_deer"]  # idle-only art: they stand and graze, never skate
## Town cats walk on the pet cats' strips (wildlife/cat_* is a sitting-only strip).
const CAT_ART := {"cat_grey": "animals/cat2_calico", "cat_orange": "animals/cat2_orange", "cat_black": "animals/cat2_black"}
class Critter:
	extends Node2D
	var map: GameMap
	var kind := "bird"
	var home := Vector2.ZERO
	var _t := 0.0
	var _dir := Vector2.ZERO
	var _timer := 0.0
	var _flee := false
	var _anim: AnimatedSprite2D
	var _flyer := false
	## Waders/swimmers (duck, heron): stand and potter on the ground, and only
	## take off (their walk strip is a flying pose) when startled (c5_09 #3).
	var _lifts := false
	var _percher := false
	var _flutter := false
	var _hopper := false
	var _rng := RandomNumberGenerator.new()
	var _ph := 0.0
	var _spd := 0.0          # eased speed (no snap from stroll to sprint)
	var _lift := 0.0         # px above the ground (birds in flight)
	var _away := 0.0         # >0: flown off, hidden, lands again when it runs out
	var _fidget := 2.0       # next peck / glance / hop
	var _dip := 0.0          # peck dip timer
	var _hop_t := 0.0        # running hop (0 = on the ground)
	var _heading := 0.0      # flutter heading (radians)
	var _leap := -1.0        # fish leap progress (<0: under water)
	var _shadow := 3.0
	var _one_frame := false
	var _sz := 0.3
	var _spd_j := 1.0

	func _ready() -> void:
		var g := "wildlife/" + kind
		_rng = CreatureMotion.rng_for(self)
		_ph = _rng.randf()
		_t = _ph * 10.0
		_flyer = kind in ["sparrow", "crow", "seagull", "bat", "owl", "bee", "firefly", "dragonfly", "butterfly_orange", "butterfly_blue", "butterfly_yellow", "butterfly_purple", "butterfly", "crystal_fish", "jelly", "eagle", "robin", "finch", "pigeon", "blue_jay", "hawk"]
		_lifts = kind in TAKE_OFF
		_percher = kind in PERCHERS
		_flutter = kind in FLUTTERS
		_hopper = kind in HOPPERS
		_heading = _rng.randf() * TAU
		_fidget = _rng.randf_range(0.5, 3.5)
		_timer = _rng.randf_range(0.2, 2.0)
		if kind in WATER_CRITTERS:
			_leap = -1.0
			_timer = _rng.randf_range(2.0, 8.0)
		var cat_g: String = CAT_ART.get(kind, "")
		if cat_g != "" and Art.has(cat_g, "walk"):
			g = cat_g
		if Art.has(g, "idle"):
			_anim = AnimatedSprite2D.new()
			var anims := {"idle": "idle"}
			anims["walk"] = "walk" if Art.has(g, "walk") else "idle"
			for extra: String in ["waddle", "takeoff", "land", "sleep"]:
				if Art.has(g, extra):
					anims[extra] = extra  # ducks: a ground walk; crows: take-off / landing; cats: naps
			var flap := 11.0 if kind.begins_with("butterfly") else (16.0 if kind in ["bee", "dragonfly"] else 8.0)
			_anim.sprite_frames = Art.frames(g, anims, {"idle": 4.0 if _flyer else 3.0, "walk": flap, "waddle": 7.0, "takeoff": 10.0, "land": 10.0, "sleep": 1.0}, {"takeoff": false, "land": false})
			var sf := _anim.sprite_frames
			_one_frame = sf.get_frame_count("idle") <= 1
			# Ground animals' idle strips are separate poses, not a loop: hold the
			# first pose and only now and then glance (a copy: Art's cache is shared).
			if not _flyer and kind in WATER_CRITTERS:
				pass
			elif (not _flyer or _percher) and sf.get_frame_count("idle") > 1:
				_anim.sprite_frames = CreatureMotion.held_idle(sf, "idle", 4.0 if kind != "deer" else 6.0, 0.3 if kind != "deer" else 0.45)
			_anim.animation = "idle"
			# True-to-world sizes: the hero is ~16px wide, so a duck is a third of that.
			var sz: float = {"sparrow": 0.2, "robin": 0.2, "finch": 0.2, "blue_jay": 0.22, "crow": 0.26, "pigeon": 0.22, "seagull": 0.26, "owl": 0.3, "hawk": 0.32, "bat": 0.24, "duck": 0.26, "heron": 0.38, "rabbit": 0.26, "squirrel": 0.22, "hedgehog": 0.24, "frog": 0.18, "turtle": 0.26, "mouse": 0.16, "rat": 0.2, "snake": 0.26, "butterfly_orange": 0.16, "butterfly_blue": 0.16, "butterfly_yellow": 0.16, "butterfly_purple": 0.16, "butterfly": 0.16, "bee": 0.12, "firefly": 0.12, "dragonfly": 0.16, "ladybug": 0.12, "grasshopper": 0.14, "snail": 0.16, "crab": 0.22, "deer": 0.5, "fox": 0.4, "boar": 0.46, "goat": 0.44, "raccoon": 0.34, "badger": 0.36, "otter": 0.34, "beaver": 0.34, "cat_grey": 0.36, "cat_orange": 0.36, "cat_black": 0.36, "stray_dog": 0.42, "jelly": 0.4, "six_deer": 0.5, "eagle": 0.36, "crystal_fish": 0.26, "fish_jump": 0.26}.get(kind, 0.3)
			if g != "wildlife/" + kind:
				sz *= 1.18  # the pet cat strips are drawn in smaller cells
			sz *= _rng.randf_range(0.92, 1.08)  # c14b_11-17: no two the same size
			_anim.scale = Vector2(sz, sz)
			_sz = sz
			var t0 := sf.get_frame_texture("idle", 0)
			_shadow = clampf((t0.get_width() if t0 else 12) * sz * 0.32, 2.0, 9.0)  # c14b_09-22
			# Feet on the ground for every frame, including the first frame after
			# an idle/walk swap (strips have different cell heights: no pop).
			_anim.frame_changed.connect(_fit)
			_anim.animation_changed.connect(_fit)
			add_child(_anim)
			_anim.play("idle")
			CreatureMotion.random_start(_anim, _rng, 0.15)  # c14b_09-03 / 11-01: no lockstep
			_spd_j = _anim.speed_scale
			if kind in WATER_CRITTERS:
				_anim.visible = false  # under water: ripples only until it leaps
			_fit()

	func _fit() -> void:
		var tex := _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
		if tex:
			_anim.offset = Vector2(0, -tex.get_height() / 2.0)

	func _ease_speed(want: float, delta: float) -> void:
		_spd = lerpf(_spd, want, 1.0 - exp(-8.0 * delta))  # c14b_09-13

	func _process(delta: float) -> void:
		_t += delta
		_timer -= delta
		# c14b_15-13: off-screen critters skip their wander / animation work.
		if _away <= 0.0 and is_inside_tree():
			var vr := get_viewport().get_visible_rect().grow(48.0)
			if not vr.has_point(get_global_transform_with_canvas().origin):
				return
		var red := CreatureMotion.reduced()
		if _away > 0.0:
			# Flown off: hidden, then lands again near home (c14b_09-13 / 11-08: maps never empty).
			_away -= delta
			if _away <= 0.0:
				position = home + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 30))
				if map and (map.rect_blocked(Rect2(position + Vector2(-2, -2), Vector2(4, 2))) or map.is_water_cell(map.world_to_cell(position - Vector2(0, 2)))):
					position = home
				_lift = 40.0
				_flee = false
				_dir = Vector2.ZERO
				visible = true
				if _anim and _anim.sprite_frames.has_animation("land"):
					_anim.play("land")
			return
		if kind in WATER_CRITTERS:
			_fish(delta, red)
			return
		var to_player := map.player.position - position if map and map.player else Vector2(999, 999)
		if to_player.length() < 40.0 and not _flee:
			_flee = true
			_dir = -to_player.normalized()
			_timer = 1.2 if not (_percher or _lifts) else 2.5
			if _anim and (_percher or _lifts) and _anim.sprite_frames.has_animation("takeoff"):
				_anim.play("takeoff")
		if _timer <= 0.0:
			if _flee and (_percher or _lifts):
				_away = _rng.randf_range(20.0, 40.0)  # off-screen: lands again later
				visible = false
				return
			_flee = false
			_timer = _rng.randf_range(1.0, 3.0)
			_dir = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() if _rng.randf() < 0.6 else Vector2.ZERO
			if _percher and _rng.randf() < 0.6:
				_dir = Vector2.ZERO  # ground birds mostly stand and peck
			if position.distance_to(home) > 80.0:
				_dir = (home - position).normalized()
		var want := 60.0 if _flee else 14.0
		if _lifts and not _flee:
			# A heron stands still in the shallows; a duck potters slowly.
			want = 0.0 if kind == "heron" else 10.0
		if _percher and not _flee:
			want = 6.0  # short pottering steps, not a glide
		if (_flyer or _lifts) and _flee:
			want = 110.0
		if _flutter:
			want = 18.0 if not kind == "firefly" else 8.0
		if kind in STILL_KINDS or (kind.begins_with("cat_") and not CAT_ART.has(kind)):
			want = 0.0
		if kind.begins_with("cat_") and not _flee:
			want = minf(want, 9.0)
		_ease_speed(want, delta)
		if _flutter:
			_flutter_step(delta)
		elif _hopper and not _flee:
			_hop_step(delta)
		else:
			var np := position + _dir * _spd * delta
			if (_flyer or _lifts) and _flee:
				position = np
			elif map and not map.rect_blocked(Rect2(np + Vector2(-2, -2), Vector2(4, 2))) and not map.is_water_cell(map.world_to_cell(np - Vector2(0, 2))):
				position = np
			elif _dir != Vector2.ZERO:
				_dir = Vector2.ZERO  # c14b_11-16: blocked: stop (no running in place)
		# Lift: birds in flight rise with an eased curve; on the ground they sit at 0.
		var lift_want := 0.0
		if (_flyer or _lifts) and _flee:
			lift_want = 40.0
		elif _flyer and not _percher:
			lift_want = 70.0 if kind == "eagle" else 7.0
		_lift = lerpf(_lift, lift_want, 1.0 - exp(-(2.2 if _flee else 3.0) * delta))
		if _anim:
			_animate(delta, red)
		else:
			queue_redraw()  # the sprite animates itself; its shadow follows position

	func _animate(delta: float, red: bool) -> void:
		var moving := _dir != Vector2.ZERO and _spd > 1.0
		var want := "walk" if moving else "idle"
		if _percher:
			want = "walk" if (_flee or _lift > 4.0) else "idle"  # the walk strip is a flight pose
		if _lifts:
			want = "walk" if _flee else ("waddle" if moving and _anim.sprite_frames.has_animation("waddle") else "idle")  # walk = flight
		if _flutter:
			want = "walk"
		if kind == "eagle":
			want = "idle"
		var cur := _anim.animation
		if (cur == "takeoff" or cur == "land") and _anim.is_playing():
			want = cur
		if cur != want and _anim.sprite_frames.has_animation(want):
			_anim.play(want)
			if want == "idle":
				CreatureMotion.random_start(_anim, _rng, 0.0)
		# Legs keep pace with the ground (walk strips are tuned for ~28 px/s).
		if want == "walk" and not _flyer and not _flutter:
			_anim.speed_scale = clampf(_spd / 28.0, 0.5, 2.0)
		elif want == "walk" and _flyer and not _flutter:
			_anim.speed_scale = 1.4  # c14b_11-08: a real flap in flight
		elif want == "idle" or _flutter:
			_anim.speed_scale = _spd_j
		# Turn only on a clear sideways lead (no flip-flicker on near-vertical moves).
		if absf(_dir.x) > 0.25:
			_anim.flip_h = _dir.x < 0
		# Idle life for still critters: breath, peck dip, glance (c14b_09-05 / 11-03).
		_fidget -= delta
		if not moving and _lift < 2.0 and _hop_t <= 0.0:
			if _fidget <= 0.0:
				_fidget = _rng.randf_range(1.5, 4.0)
				if _percher and _rng.randf() < 0.3:
					_anim.flip_h = not _anim.flip_h  # look about
				elif not red:
					_dip = 0.16
		_dip = maxf(0.0, _dip - delta)
		var base := _sz
		var br := CreatureMotion.breath(_ph, 0.03 if _one_frame else 0.015, 1.8 + _ph * 0.8)
		var sgn := -1.0 if _anim.flip_h else 1.0
		_anim.rotation = sgn * deg_to_rad(6.0) * (_dip / 0.16) if _dip > 0.0 else 0.0
		var sq := 1.0
		if _hop_t > 0.0:
			var u := 1.0 - _hop_t / 0.28
			sq = 1.0 + 0.08 * sin(u * PI)  # stretch in the air
		_anim.scale = Vector2(base * br.x / sq, base * br.y * sq)
		var y := -_lift
		if _flyer and not _percher and not _flee:
			y -= sin(_t * (3.2 + _ph * 1.6)) * (0.6 if red else 2.0)
		if kind == "eagle":
			y = -_lift - sin(_t * 0.5 + _ph * TAU) * 6.0
		if _hop_t > 0.0:
			y -= 4.0 * sin(PI * (1.0 - _hop_t / 0.28))
		if _dip > 0.0 and not _percher:
			y += 1.0
		_anim.position.y = y
		if kind == "firefly":
			# c14b_09-12 / 11-11: a soft glow pulse on its own period (no full blink in reduced motion).
			var per := 1.2 + _ph * 1.3
			var p := 0.5 + 0.5 * sin(_t * TAU / per)
			_anim.modulate = Color(1.6, 1.7, 0.9, lerpf(0.55 if red else 0.25, 1.0, p))
		queue_redraw()

	## Butterflies / bees / dragonflies / fireflies: a smoothly turning heading plus a
	## sideways wobble; dragonflies dart and hover (c14b_09-11 / 11-10).
	func _flutter_step(delta: float) -> void:
		_heading += _rng.randf_range(-2.0, 2.0) * delta
		if position.distance_to(home) > 70.0:
			var back := (home - position).angle()
			_heading = lerp_angle(_heading, back, 1.0 - exp(-1.5 * delta))
		var sp := _spd
		if kind == "dragonfly":
			sp *= 3.0 if fmod(_t + _ph * 3.0, 2.2) < 0.25 else 0.15
		var fwd := Vector2.from_angle(_heading)
		var side := Vector2(-fwd.y, fwd.x) * sin(_t * (3.0 + _ph * 2.0) * TAU * 0.25) * 6.0
		var np := position + (fwd * sp + side) * delta
		if map == null or not map.is_water_cell(map.world_to_cell(np - Vector2(0, 2))) or _flyer:
			position = np
		_dir = fwd if absf(fwd.x) > 0.3 else Vector2(signf(fwd.x) if fwd.x != 0.0 else 1.0, 0) * 0.3

	## Rabbits / frogs: discrete hops (0.28 s, 10-14 px) with a pause between (c14b_09-06).
	func _hop_step(delta: float) -> void:
		if _hop_t > 0.0:
			var np := position + _dir * (12.0 / 0.28) * delta
			if map and not map.rect_blocked(Rect2(np + Vector2(-2, -2), Vector2(4, 2))) and not map.is_water_cell(map.world_to_cell(np - Vector2(0, 2))):
				position = np
			else:
				_dir = Vector2.ZERO
			_hop_t = maxf(0.0, _hop_t - delta)
			if _hop_t <= 0.0:
				_fidget = _rng.randf_range(0.1, 0.35)
		elif _dir != Vector2.ZERO and _fidget <= 0.0:
			_hop_t = 0.28

	## Fish: ripple rings under water, a one-shot leap along a small arc every 4-10 s.
	func _fish(delta: float, red: bool) -> void:
		if _leap >= 0.0:
			_leap += delta / 0.5
			if _anim:
				_anim.position.y = -10.0 * sin(PI * clampf(_leap, 0.0, 1.0))
				_anim.position.x = (_leap - 0.5) * 6.0 * (-1.0 if _anim.flip_h else 1.0)
			if _leap >= 1.0:
				_leap = -1.0
				_timer = _rng.randf_range(4.0, 10.0)
				if _anim:
					_anim.visible = false
				if map and map.has_method("fx") and Art.has("fx", "splash"):
					map.fx("splash", position, 10.0, 0.4)
		elif _timer <= 0.0 and not red:
			_leap = 0.0
			if _anim:
				_anim.visible = true
				_anim.flip_h = _rng.randf() < 0.5
				_anim.play("walk" if _anim.sprite_frames.has_animation("walk") else "idle")
				_anim.speed_scale = float(_anim.sprite_frames.get_frame_count(_anim.animation)) / 0.5 / maxf(1.0, _anim.sprite_frames.get_animation_speed(_anim.animation))
		elif _timer <= 0.0:
			_timer = 6.0
		# Drift slowly while under water (never faster than 6 px/s), staying in deep water.
		if _leap < 0.0:
			if _rng.randf() < delta * 0.3:
				_dir = Vector2.from_angle(_rng.randf() * TAU)
			var np := position + _dir * 5.0 * delta
			if map and WorldGen._deep_water(map, map.world_to_cell(np - Vector2(0, 2))):
				position = np
			else:
				_dir = Vector2.ZERO
		queue_redraw()

	func _draw() -> void:
		if kind in WATER_CRITTERS:
			# Two expanding rings, fading, on the critter's own period.
			for k in 2:
				var u := fposmod(_t / 1.5 + _ph + k * 0.5, 1.0)
				draw_arc(Vector2(0, -1), 2.0 + u * 7.0, 0.0, TAU, 18, Color(1, 1, 1, 0.35 * (1.0 - u)), 1.0)
			return
		if _anim:
			var shrink := clampf(1.0 - _lift / 90.0, 0.35, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2(0, 0), _shadow * shrink, Color(0, 0, 0, 0.16 * shrink))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var f := int(_t * 6.0) % 2
		var bob := sin(_t * 8.0) * 1.0
		match kind:
			"bird":
				var col := Color("3a3a4a") if not _flee else Color("2a2a3a")
				var lift := -20.0 - sin(_t * 10.0) * 2.0 if _flee else -2.0
				draw_circle(Vector2(0, lift), 2.2, col)
				draw_rect(Rect2(1.5, lift - 1, 2, 1), Color("e8a23a"))
				if _flee:
					draw_line(Vector2(-1, lift), Vector2(-5, lift - 3 + f * 3), col, 1.0)
					draw_line(Vector2(1, lift), Vector2(5, lift - 3 + f * 3), col, 1.0)
				else:
					draw_rect(Rect2(-1, lift + 2, 1, 1), col)
					draw_rect(Rect2(1, lift + 2, 1, 1), col)
			"butterfly":
				var col: Color = [Color("f2c84b"), Color("e36d8e"), Color("8ab4ff")][int(home.x) % 3]
				var w := 2.0 + f * 1.5
				draw_rect(Rect2(-w, -10 + bob, w, 2), col)
				draw_rect(Rect2(0, -10 + bob, w, 2), col)
				draw_rect(Rect2(-0.5, -11 + bob, 1, 4), Color("222"))
			"rabbit":
				var col := Color("c9b08a")
				draw_circle(Vector2(0, -3), 3.0, col)
				draw_circle(Vector2(2, -6), 2.2, col)
				draw_rect(Rect2(1.5, -10 + (f if _dir != Vector2.ZERO else 0), 1, 4), col)
				draw_rect(Rect2(3, -10 + (f if _dir != Vector2.ZERO else 0), 1, 4), col)
				draw_rect(Rect2(-3, -3, 1.5, 1.5), Color.WHITE)
				draw_circle(Vector2(0, 0), 3.0, Color(0, 0, 0, 0.15))


## Painted sky + hills that scroll slower than the camera.
class Backdrop:
	extends Node2D
	var kind := "hills"
	var map: GameMap
	var _t := 0.0
	var _redraw_t := 0.0
	var _clouds: Array = []

	func _ready() -> void:
		z_index = -10
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 8:
			_clouds.append({"x": rng.randf_range(-100, 600), "y": rng.randf_range(10, 70), "w": rng.randf_range(30, 80), "s": rng.randf_range(2, 6)})

	func _process(delta: float) -> void:
		_t += delta
		for c in _clouds:
			c["x"] += c["s"] * delta
			if c["x"] > 700:
				c["x"] = -120
		# Parallax: the backdrop moves at 30% of the camera.
		var cam := get_viewport().get_camera_2d()
		if cam:
			var center := cam.get_screen_center_position()
			position = center * 0.7 - Vector2(135, 240) * 0.7 - Vector2(0, 40)
		# Moving position needs no redraw; the slow cloud drift is fine at 10 Hz.
		_redraw_t -= delta
		if _redraw_t <= 0.0:
			_redraw_t = 0.1
			queue_redraw()

	func _draw() -> void:
		var W := 900.0
		var H := 1200.0
		var t := int(GameState.run.get("time", 480))
		var dark := GameState.darkness(t)
		var strip_name: String = {"hills": "sky_day", "mountains": "sky_mountains", "sea": "sky_sea", "forest": "sky_forest", "night": "sky_night", "moon": "sky_night", "space": "sky_night"}.get(kind, "")
		if t >= GameState.sunset() - 60 and t < GameState.full_dark() and kind in ["hills", "forest"]:
			strip_name = "sky_sunset"
		elif t < GameState.sunrise() + 45 and kind in ["hills", "forest"]:
			strip_name = "sky_sunset"  # sunrise reds
		elif dark > 0.5 and kind in ["hills", "forest", "mountains", "sea"]:
			strip_name = "sky_night"
		var st := Art.tex("backdrops", str(strip_name)) if strip_name != "" else null
		if st:
			# Tile the painted strip across the width; scale strip height to ~1/3 of the view, sitting above the map.
			var sw := st.get_width() * 0.5
			var sh := st.get_height() * 0.5
			var y := 240.0 - sh
			draw_rect(Rect2(-W / 2, -400, W, y + 400), Color(0.5, 0.75, 0.95).lerp(Color(0.05, 0.05, 0.15), dark))
			var x := -W / 2 + fposmod(_t * 2.0, sw) - sw
			while x < W / 2:
				draw_texture_rect(st, Rect2(x, y, sw, sh), false)
				x += sw
			var ground := Color(0.36, 0.6, 0.3) if kind != "sea" else Color(0.2, 0.45, 0.7)
			if kind == "mountains":
				ground = Color(0.4, 0.45, 0.5)
			draw_rect(Rect2(-W / 2, y + sh - 1, W, H), ground.lerp(Color(0.05, 0.08, 0.1), dark * 0.7))
			if dark > 0.0:
				draw_rect(Rect2(-W / 2, -400, W, H + 400), Color(0, 0, 0.1, dark * 0.5))
			return
		var top := Color("7ec8f0").lerp(Color("141a3a"), dark)
		var bot := Color("c8ecff").lerp(Color("2a2f55"), dark)
		if kind == "night" or kind == "space":
			top = Color("0a0a1e"); bot = Color("1a1a3a")
		if kind == "moon":
			top = Color("0a0612"); bot = Color("2a1a44")
		if kind == "gritty":
			top = Color("3a3a48").lerp(Color("0e0e18"), dark); bot = Color("6a5a60").lerp(Color("201828"), dark)
		for i in 12:
			var f := i / 12.0
			draw_rect(Rect2(-W / 2, -200 + f * (H * 0.45), W, H * 0.45 / 12 + 1), top.lerp(bot, f))
		if kind in ["night", "space", "moon"] or dark > 0.4:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 90:
				var p := Vector2(rng.randf_range(-W / 2, W / 2), rng.randf_range(-200, 300))
				var tw := 0.5 + 0.5 * sin(_t * 2.0 + i)
				draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, (0.3 + 0.7 * tw) * maxf(dark, 1.0 if kind != "hills" else 0.0)))
		for c in _clouds:
			if kind in ["space", "moon"]:
				break
			var col := Color(1, 1, 1, 0.75).lerp(Color(0.5, 0.5, 0.7, 0.5), dark)
			draw_rect(Rect2(c["x"] - W / 2, c["y"] - 100, c["w"], 10), col)
			draw_rect(Rect2(c["x"] - W / 2 + c["w"] * 0.2, c["y"] - 106, c["w"] * 0.5, 6), col)
		# Distant hills / city / craters.
		match kind:
			"hills":
				var h1 := Color("5f9e6e").lerp(Color("1e2a3a"), dark)
				var h2 := Color("4b8559").lerp(Color("16202c"), dark)
				for i in 9:
					var x := -W / 2 + i * 110.0
					draw_circle(Vector2(x, 360 + (i % 3) * 14), 120.0, h1)
				for i in 7:
					var x := -W / 2 + 60 + i * 140.0
					draw_circle(Vector2(x, 400 + (i % 2) * 10), 110.0, h2)
				draw_rect(Rect2(-W / 2, 400, W, H), h2)
			"mountains":
				var mc := Color("6b7a8c").lerp(Color("1c2030"), dark)
				for i in 8:
					var x := -W / 2 + i * 130.0
					draw_colored_polygon(PackedVector2Array([Vector2(x - 90, 420), Vector2(x, 250 + (i % 2) * 40), Vector2(x + 90, 420)]), mc)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 22, 300 + (i % 2) * 40), Vector2(x, 250 + (i % 2) * 40), Vector2(x + 22, 300 + (i % 2) * 40)]), Color.WHITE.lerp(Color(0.6, 0.6, 0.7), dark))
				draw_rect(Rect2(-W / 2, 420, W, H), mc)
			"sea":
				var sc := Color("2f6fb5").lerp(Color("0e1e3a"), dark)
				draw_rect(Rect2(-W / 2, 330, W, H), sc)
				for i in 30:
					var x := -W / 2 + fposmod(i * 37.0 + _t * 10.0, W)
					draw_rect(Rect2(x, 340 + (i % 5) * 12, 10, 1), Color(1, 1, 1, 0.3))
			"gritty":
				var cc := Color("2a2a36")
				for i in 14:
					var x := -W / 2 + i * 70.0
					var hh := 60 + (i * 37) % 120
					draw_rect(Rect2(x, 420 - hh, 50, hh + 800), cc)
					for wy in range(0, hh, 12):
						for wx in range(6, 44, 12):
							if (i + wy + wx) % 3 == 0:
								draw_rect(Rect2(x + wx, 420 - hh + wy + 4, 4, 4), Color("f2c84b", 0.6))
				draw_rect(Rect2(-W / 2, 420, W, H), Color("1a1a24"))
			"moon":
				draw_circle(Vector2(200, -60), 70.0, Color("c9d7ff"))
				draw_circle(Vector2(180, -80), 14.0, Color("a9b7e0"))
				draw_rect(Rect2(-W / 2, 380, W, H), Color("1a1230"))


## Fruit trees you can shake: cherry (spring), orange and plum (summer), apple
## (fall). Each gives fruit once a day; in winter they're bare. Used by the town
## orchard, the farm edge and the regions' tree lines.
const FRUIT := {"cherry": ["spring", "mid_cherry", "cherry"], "orange": ["summer", "orange_tree", "orange"], "plum": ["summer", "plum_tree", "plum"], "apple": ["fall", "apple_tree", "apple"]}


static func fruit_tree(m: GameMap, c: Vector2i, kind: String) -> void:
	if not FRUIT.has(kind) or m.things.has(c) or m.blocked.has(c):
		return
	var info: Array = FRUIT[kind]
	var season := GameState.look_se()
	var key := "fruit_%s_%d_%d" % [m.scene_id(), c.x, c.y]
	var ripe := str(info[0]) == season and int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
	# Early spring is blossom time for cherries and apples (c5_14 #7): cherries
	# fruit from day 8 of spring.
	var sday := (int(GameState.run.get("day", 1)) - 1) % GameState.DAYS_PER_SEASON + 1
	var blossoming := season == "spring" and sday <= 7 and kind in ["cherry", "apple"] and Art.has("nature", "ftree_%s_blossom" % kind)
	if blossoming:
		ripe = false
	var sprite := str(info[1])
	if Art.has("nature", "ftree_%s_fruit" % kind):
		# Prompts 10 painted fruit trees: bare / blossom / fruit / late / snow.
		var st := "bare"
		var fs := str(info[0])
		var order := ["spring", "summer", "fall", "winter"]
		var di := (order.find(season) - order.find(fs) + 4) % 4  # seasons after the fruiting one
		if season == "winter":
			st = "snow" if kind != "cherry" else "bare"
		elif di == 0:
			# In season: fruit until shaken, then plain leaves (no "late" autumn look mid-summer).
			st = "fruit" if ripe else ("green" if Art.has("nature", "ftree_%s_green" % kind) else "late")
		elif di == 3:
			st = "blossom"  # the season before fruiting
		elif di == 1:
			st = "late" if kind != "cherry" else "green"
		else:
			# Two seasons before fruiting (apples in spring): in leaf, not bare.
			st = "fall" if kind == "cherry" else ("green" if Art.has("nature", "ftree_%s_green" % kind) else "bare")
		if blossoming:
			st = "blossom"
		if not Art.has("nature", "ftree_%s_%s" % [kind, st]):
			st = "fruit"
		sprite = "ftree_%s_%s" % [kind, st]
	elif season == "winter":
		sprite = "tree_bare"
	elif str(info[0]) != season:
		sprite = "oak" if Art.has("nature", "oak") else sprite
	if not Art.has("nature", sprite):
		sprite = "oak"
	m.set_thing(c.x, c.y, {"type": "fruit", "kind": kind, "key": key, "item": str(info[2]), "ripe": ripe, "hint": "A: shake the %s tree" % kind if ripe else ""})
	m.prop("nature", sprite, c)


static func fruit_trees(m: GameMap, rect: Rect2i, seed_v: int, count: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds := FRUIT.keys()
	var placed := 0
	for i in count * 6:
		if placed >= count:
			break
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		if m.things.has(c) or m.blocked.has(c) or avoid.has(c) or m.is_water_cell(c):
			continue
		fruit_tree(m, c, str(kinds[rng.randi_range(0, kinds.size() - 1)]))
		placed += 1


## Inner edge of the organic border band: wherever a band cell touches open
## ground and has no tree of its own, put undergrowth there (shrubs, ferns, a
## young tree), so the band reads as a living forest edge, never as an empty
## blocked cell. Decorative (the band is already solid). Call from after_ready.
static func dress_band(m: GameMap, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	var se := GameState.look_se()
	var shrubs: Array = {"spring": ["bush", "bush2_green", "bush2_flower", "ferns", "hedge", "bush_white"], "summer": ["bush", "bush2_green", "ferns", "hedge", "bush2_yellow", "sunflower_bush"], "fall": ["bush_fall_orange", "bush_fall_red", "ferns", "bush2_red", "hedge"], "winter": ["bush_snow", "bush_bare_snow", "bush_snow", "bush_bare_snow"]}.get(se, ["bush"])  # winter: no green hedge in snow (c14_02-17)
	var young: Array = {"spring": ["mid_oak_b", "mid_birch_b", "mid_pine_b", "mid_cherry_b"], "summer": ["mid_oak_b", "mid_birch_b", "mid_pine_b", "mid_willow_b"], "fall": ["mid_maple_b", "mid_oak_b", "mid_pine_b"], "winter": ["mid_snowpine_b", "mid_dead_b", "mid_snowpine"]}.get(se, ["mid_oak_b"])
	var th := theme(m)
	var band: Array = th.get("band", [])
	if th.has("band") and band.is_empty():
		return
	for c: Vector2i in m._border_cells:
		if str(m._border_cells[c]) != "tree" or m.props.has(c):
			continue
		var open_side := false
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := c + d
			if m.in_content(n) and not m.blocked.has(n):
				open_side = true
				break
		if not open_side:
			continue
		rng.seed = hash(Vector3i(seed_v, c.x, c.y))
		var r := rng.randf()
		var nm: String
		if not band.is_empty():
			var ga := theme_art(str(band[rng.randi_range(0, band.size() - 1)]))
			if r < 0.7 and Art.has(str(ga[0]), str(ga[1])):
				var bs := m.prop(str(ga[0]), str(ga[1]), c, 0, 0.0, false, 0.5)
				if bs:
					bs.position.x += rng.randf_range(-3.0, 3.0)
			continue
		if r < 0.22 and Art.has("nature", str(young[0])):
			nm = str(young[rng.randi_range(0, young.size() - 1)])
		else:
			nm = str(shrubs[rng.randi_range(0, shrubs.size() - 1)])
		if not Art.has("nature", nm):
			nm = GameState.bush_sprite(false)
		var sp := m.prop("nature", nm, c, 0, 0.0, false, 0.5)
		if sp:
			sp.position.x += rng.randf_range(-3.0, 3.0)


## A noise-edged blob of cells (no one-cell notches), clipped to the content
## with `margin` cells spare. rx/ry are radii in cells.
static func blob(m: GameMap, center: Vector2, rx: float, ry: float, seed_v: int, margin := 2, rough := 0.22) -> Dictionary:
	var cells := {}
	for y in range(int(center.y - ry - 2), int(center.y + ry + 3)):
		for x in range(int(center.x - rx - 2), int(center.x + rx + 3)):
			if x < margin or y < margin or x >= m.cols - margin or y >= m.rows - margin:
				continue
			var n := fbm(float(x), float(y), seed_v, 5.0)
			var d := Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry).length()
			if d + n * rough <= 1.0:
				cells[Vector2i(x, y)] = true
	return smooth_cells(cells)


## Drop cells with 0-1 neighbours and fill cells with 3-4 (twice): cliff faces
## and shores then never show broken one-cell pieces.
static func smooth_cells(cells: Dictionary, passes := 2) -> Dictionary:
	var pc := cells.duplicate()
	for i in passes:
		var nx := pc.duplicate()
		var cand := {}
		for c: Vector2i in pc:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				cand[c + d] = true
			cand[c] = true
		for c: Vector2i in cand:
			var nb := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if pc.has(c + d):
					nb += 1
			if pc.has(c) and nb <= 1:
				nx.erase(c)
			elif not pc.has(c) and nb >= 3:
				nx[c] = true
		pc = nx
	return pc


## The cells of `outer` at least `side` cells from its west/east/north edge and
## `south` cells from its south edge: room for an upper tier whose cliff face and
## stairs land on the lower tier's open top, never on its rim.
static func inset(outer: Dictionary, side := 2, south := 4) -> Dictionary:
	var out := {}
	for c: Vector2i in outer:
		var ok := true
		for k in range(1, side + 1):
			if not outer.has(c + Vector2i(k, 0)) or not outer.has(c + Vector2i(-k, 0)) or not outer.has(c + Vector2i(0, -k)):
				ok = false
				break
		if ok:
			for k in range(1, south + 1):
				if not outer.has(c + Vector2i(0, k)):
					ok = false
					break
		if ok:
			out[c] = true
	return out


## A hill with a second, higher tier: a lower plateau and, inset on it, an upper
## one. Both get their stairs cut in the middle of their south edge (the upper
## flight lands on the lower top). Cells in `avoid` (paths, exits, doors, water)
## are kept off, with a cell of room. Call from build(); the map's draw_map must
## call draw_plateaus(). Returns [lower, upper] (upper may be empty).
static func tiered_hill(m: GameMap, center: Vector2, rx: float, ry: float, seed_v: int, avoid: Dictionary = {}, two_tiers := true) -> Array:
	var low := mesa(m, center, rx, ry, seed_v, 3)  # long straight runs: clean cliff faces and rims
	for c: Vector2i in low.keys():
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if avoid.has(n) or m.things.has(n) or m.is_water_cell(n):
					low.erase(c)
	low = smooth_cells(low)
	# The biggest piece only (avoid can split it).
	var best := {}
	for part: Dictionary in _parts(low):
		if part.size() > best.size():
			best = part
	low = best
	if low.size() < 12:
		return [{}, {}]
	m.add_plateau(low, pick_ramps(m, low))
	var up := {}
	if two_tiers:
		var room := inset(low, 2, 4)
		var cu := Vector2(center.x, center.y - ry * 0.25)
		var ub := mesa(m, cu, rx * 0.55, ry * 0.5, seed_v + 5, 3)
		for c: Vector2i in ub:
			if room.has(c):
				up[c] = true
		up = smooth_cells(up)
		var ubest := {}
		for part: Dictionary in _parts(up):
			if part.size() > ubest.size():
				ubest = part
		up = ubest
		if up.size() >= 8:
			m.add_plateau(up, pick_ramps(m, up))
		else:
			up = {}
	return [low, up]


static func _parts(cells: Dictionary) -> Array:
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


## After a map is dressed: nothing placed by the scatterers may stand on a
## flight of stairs or the cells just above/below it (call_deferred from
## after_ready, so it also runs after GameMap's extension filler).
static func clear_stairs(m: GameMap) -> void:
	if not is_instance_valid(m):
		return
	for pl: Dictionary in m.plateaus:
		for st: Vector2i in pl["stairs"]:
			for dy in range(-2, 3):  # two rows up too: the landing at the stair top (c5_12 #3)
				var c := st + Vector2i(0, dy)
				var t := str(m.things.get(c, {}).get("type", ""))
				if t in ["tree", "rock", "log", "stump", "bush", "weeds", "forage", "grove"] or (t == "" and m.props.has(c) and m.blocked.has(c) and (dy >= 0 or _small_prop(m.props[c]))):
					m.things.erase(c)
					if dy >= 0 or t != "":
						m.blocked.erase(c)
						m.hard.erase(c)
					var sp: Node = m.props.get(c, null)
					m.props.erase(c)
					if sp:
						sp.queue_free()


## A boulder/crate-sized scatter prop (not a building or big structure).
static func _small_prop(n: Variant) -> bool:
	if not (n is Sprite2D) or (n as Sprite2D).texture == null:
		return false
	var sp := n as Sprite2D
	return sp.texture.get_width() * sp.scale.x <= 40.0


## Two side-by-side south-edge cells for a plateau's stairs: both on the same
## row with open ground under the flight, nearest the middle of the plateau.
## (add_plateau's own pick can land on a stepped edge, where the second stair
## ends up under the plateau's own rim.) Empty if no such pair.
static func pick_ramps(m: GameMap, cells: Dictionary) -> Array:
	var cx := 0.0
	for c: Vector2i in cells:
		cx += c.x
	cx /= maxf(1.0, cells.size())
	var best: Array = []
	var best_score := INF
	for c: Vector2i in cells:
		var r := c + Vector2i(1, 0)
		if cells.has(c + Vector2i(0, 1)) or not cells.has(r) or cells.has(r + Vector2i(0, 1)):
			continue
		var ok := true
		for k in [c, r]:
			for dy in range(1, 3):
				var n: Vector2i = k + Vector2i(0, dy)
				if not m.in_content(n) or cells.has(n) or m.is_water_cell(n) or m.hard.has(n):
					ok = false
			# Sides of the flight stay rim: both neighbours on the row must be plateau.
		if not cells.has(c + Vector2i(-1, 0)) or not cells.has(r + Vector2i(1, 0)):
			ok = false
		if not ok:
			continue
		var score := absf(c.x + 0.5 - cx) - c.y * 0.5
		if score < best_score:
			best_score = score
			best = [c, r]
	return best


## A mesa: a raised block with long straight runs and few, gentle steps (each
## side moves in or out by one cell at most every 3 rows, corners chamfered).
## Cliff faces, rims and stairs draw cleanly on shapes like this; round noise
## blobs step every row and the rim reads as a ring of boxes.
const JOG_MAPS := ["highlands", "orchard_hills", "riverlands"]

static func mesa(m: GameMap, center: Vector2, rx: float, ry: float, seed_v: int, margin := 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cells := {}
	var y0 := roundi(center.y - ry)
	var y1 := roundi(center.y + ry)
	var ol := 0
	var orr := 0
	var hold_l := 0
	var hold_r := 0
	# C14 P1 (c14_14-10): big plateaus on the hand-made home regions jog their side
	# walls every 2-3 rows (wider in/out) so long sides never read as a box.
	var jog := rx >= 6.0 and m.scene_id() in JOG_MAPS
	for y in range(y0, y1 + 1):
		var cham := 0
		if y == y0:
			cham = 2
		elif y == y0 + 1:
			cham = 1
		elif y == y1:
			cham = 1
		if hold_l <= 0:
			ol = clampi(ol + rng.randi_range(-1, 1), -1, 3 if jog else 2)
			hold_l = rng.randi_range(2, 3) if jog else rng.randi_range(3, 5)
		if hold_r <= 0:
			orr = clampi(orr + rng.randi_range(-1, 1), -1, 3 if jog else 2)
			hold_r = rng.randi_range(2, 3) if jog else rng.randi_range(3, 5)
		hold_l -= 1
		hold_r -= 1
		var xa := roundi(center.x - rx) + maxi(ol, 0) + cham
		var xb := roundi(center.x + rx) - maxi(orr, 0) - cham
		for x in range(xa, xb + 1):
			if x >= margin and y >= margin and x < m.cols - margin and y < m.rows - margin:
				cells[Vector2i(x, y)] = true
	return smooth_cells(cells)


## C14 P1 (c14_02-13 / c14_14-01 / c14_02-08): home-region shapes from regions.json,
## called from Region.build (one hook) before anything else is placed.
## "rivers": [{"pts": [[x, y], ...], "w": 2.6, "seed": n, "fish": [...]}] winds a
## river along the polyline (noise meander, breathing width); the cells under a
## path become a walkable deck (drawn as water, a bridge over it from home_dress);
## cells on the map edge carry on out through the border band.
## "orchard": [{"rect": [x, y, w, h], "kinds": ["apple", ...], "step": [3, 3]}]
## plants staggered rows of fruit trees (skipping paths, water and things).
static func home_build(m: GameMap, R: Dictionary) -> void:
	# "season_ground": {"winter": {"ground_seam": "snow"}} swaps ground keys per look season (c14_02-03).
	var sg: Dictionary = R.get("season_ground", {}).get(GameState.look_se(), {})
	for k: String in sg:
		R[k] = sg[k]
	var pcs := {}
	for pr in R.get("paths", []):
		for y in range(int(pr[1]), int(pr[1]) + int(pr[3])):
			for x in range(int(pr[0]), int(pr[0]) + int(pr[2])):
				pcs[Vector2i(x, y)] = true
	var rivers: Array = R.get("rivers", [])
	if not rivers.is_empty():
		var wc: Dictionary = m.get("_water_cells")
		var decks := {}
		var all := {}
		for rv: Dictionary in rivers:
			var cells := river_cells(rv)
			for c: Vector2i in cells:
				if c.x < -1 or c.y < -1 or c.x > m.cols or c.y > m.rows:
					continue
				all[c] = true
				if not m.in_content(c):
					continue
				if pcs.has(c):
					decks[c] = true
					m.things[c] = {"type": "dock", "shore": "river", "deck": true}
					m.blocked.erase(c)
				elif not m.things.has(c) or str(m.things[c].get("type", "")) == "water":
					m.set_thing(c.x, c.y, {"type": "water", "river": true, "hint": "A: fish" if GameState.has_tool("rod") else "", "pool": rv.get("fish", []), "shore": "river"})
				else:
					continue
				wc[c] = true
		# Ponds the river runs through become one body with it (one shore look).
		for c: Vector2i in wc:
			if str(m.things.get(c, {}).get("shore", "")) != "river":
				m.things[c]["shore"] = "river"
		# Out through the border band like the farm river.
		for c: Vector2i in all:
			if c.x <= 0 or c.y <= 0 or c.x >= m.cols - 1 or c.y >= m.rows - 1:
				m.border_water_extra[c] = true
		if m.border_water_shore == "":
			m.border_water_shore = "river"
		m.set_meta("river_decks", decks)
		m.set_meta("river_cells", all)
	for ob: Dictionary in R.get("orchard", []):
		var r: Array = ob["rect"]
		var kinds: Array = ob.get("kinds", ["apple"])
		var st: Array = ob.get("step", [3, 3])
		var row := 0
		for y in range(int(r[1]), int(r[1]) + int(r[3]), int(st[1])):
			var col := 0
			for x in range(int(r[0]) + (row % 2) * int(int(st[0]) / 2), int(r[0]) + int(r[2]), int(st[0])):
				var c := Vector2i(x, y)
				var clear := true
				for d: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
					if pcs.has(c + d) or m.is_water_cell(c + d) or m.things.has(c + d):
						clear = false
				if clear:
					fruit_tree(m, c, str(kinds[(row + col) % kinds.size()]))
				col += 1
			row += 1


## Cells of one regions.json river: the polyline, nudged sideways by noise
## (never at its joints, so entry/exit points hold), width breathing +-0.4.
static func river_cells(rv: Dictionary) -> Dictionary:
	var pts: Array = rv.get("pts", [])
	var hw0 := float(rv.get("w", 2.6)) * 0.5
	var sd := int(rv.get("seed", 5))
	var cells := {}
	for i in range(pts.size() - 1):
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var n := maxi(1, ceili(a.distance_to(b) * 4.0))
		var dir := (b - a).normalized()
		var perp := Vector2(-dir.y, dir.x)
		for k in n + 1:
			var t := float(k) / float(n)
			var p := a.lerp(b, t)
			p += perp * (fbm(p.x, p.y, sd, 6.0) - 0.5) * 3.0 * sin(t * PI)
			var hw := hw0 + 0.4 * sin(p.x * 0.31 + p.y * 0.23 + float(sd))
			for cy in range(floori(p.y - hw - 1.0), ceili(p.y + hw + 1.0)):
				for cx in range(floori(p.x - hw - 1.0), ceili(p.x + hw + 1.0)):
					if Vector2(cx + 0.5, cy + 0.5).distance_to(p) <= hw:
						cells[Vector2i(cx, cy)] = true
	return smooth_cells(cells)


## C14 P1: after-ready dressing for home_build shapes (one hook in Region.after_ready):
## a bridge over every deck (sized bank to bank, the farm's bridge art), reeds and
## cattails on the banks (not in winter).
static func home_dress(m: GameMap) -> void:
	crop_rows(m)
	clear_arrivals.call_deferred(m)
	var decks: Dictionary = m.get_meta("river_decks", {})
	var river: Dictionary = m.get_meta("river_cells", {})
	if river.is_empty():
		return
	var groups: Array = []
	var seen := {}
	for c0: Vector2i in decks:
		if seen.has(c0):
			continue
		var grp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c0]
		seen[c0] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			grp.append(c)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if decks.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					stack.append(c + d)
		groups.append(grp)
	for grp: Array in groups:
		var lo := Vector2i(99999, 99999)
		var hi := Vector2i(-99999, -99999)
		for c: Vector2i in grp:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var ns := (hi.y - lo.y) >= (hi.x - lo.x)
		var nm := "foot3_ns_a" if ns else "bridge_wood2"
		if ns and Art.has("props", nm + "_dry"):
			nm += "_dry"  # keyed-out patch: the river shows under it
		var tex := Art.tex("props", nm)
		if tex == null:
			continue
		if ns:
			var sc := maxf(float(hi.y - lo.y + 3) * GameMap.TILE / float(tex.get_height()), 3.7 * GameMap.TILE / float(tex.get_width()))
			var sp := m.prop("props", nm, Vector2i(lo.x, hi.y + 1), 1, 0.0, false, sc)
			if sp:
				m.walk_over(sp, ceili(tex.get_height() * sc / GameMap.TILE))
		else:
			var sc2 := maxf(float(hi.x - lo.x + 3) * GameMap.TILE / float(tex.get_width()), 2.6 * GameMap.TILE / float(tex.get_height()))
			var sp2 := m.prop("props", nm, Vector2i(lo.x - 1, hi.y + 1), int(hi.x - lo.x + 2), 0.0, false, sc2)
			if sp2:
				m.walk_over(sp2, ceili(tex.get_height() * sc2 / GameMap.TILE))
	if GameState.look_se() == "winter":
		return  # reeds die back in the snow
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(m.scene_id()) % 9973 + 41
	var reeds := ["mk_reeds_2", "mk_reeds_3", "mk_cattail_1", "mk_cattail_2"]
	for c: Vector2i in river:
		if decks.has(c) or not m.in_content(c) or m.props.has(c):
			continue
		var edge := false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if not river.has(c + d) and not decks.has(c + d):
				edge = true
		if edge and rng.randf() < 0.14:
			var rn: String = reeds[rng.randi_range(0, reeds.size() - 1)]
			if Art.has("props", rn):
				var sp3 := m.prop("props", rn, c, 0, 0.0, false)
				if sp3:
					m.to_under(sp3)



## C14 P1 (c14_02-01): regions.json "crop_rows": [{"rect": [x, y, w, h], "crop": "corn"}]
## plants a field of crop sprites by look season (young in spring, tall in summer,
## ripe in fall, nothing in winter: snow), the outer row a stage younger so the
## field thins at its edge. Replaces the night-only cornfield tile at noon.
const CROP_STAGE := {"spring": "growing", "summer": "mature", "fall": "ready"}
const CROP_EDGE := {"growing": "young", "mature": "growing", "ready": "mature"}

static func crop_rows(m: GameMap) -> void:
	var rd: Dictionary = m.get("R") if m.get("R") is Dictionary else {}
	var stage: String = CROP_STAGE.get(GameState.look_se(), "")
	if stage == "":
		return
	for cr: Dictionary in rd.get("crop_rows", []):
		var r: Array = cr["rect"]
		var crop := str(cr.get("crop", "corn"))
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if m.things.has(c) or m.blocked.has(c) or m.props.has(c) or not m.in_content(c):
					continue
				var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
				var nm := "%s_%s" % [crop, CROP_EDGE[stage] if edge else stage]
				if not Art.has("crops", nm):
					nm = "%s_%s" % [crop, stage]
				if not Art.has("crops", nm):
					return
				var sp := m.prop("crops", nm, c, 0, 0.0, false)
				if sp:
					sp.position.x += float((x * 7 + y * 13) % 5) - 2.0



## C14 P1 (c14_01-33): no flower bush, fern or forage on (or next to) the cell you
## arrive on: the default spawn and the first cells inside every exit. Only loose
## decor goes (bush/flower/fern/wildflower sprites with no thing, and forage things).
const ARRIVAL_DECOR := ["bush", "flower", "fern", "wildflower", "sunflower"]

static func arrival_cells(m: GameMap) -> Dictionary:
	var out := {}
	var core: Array[Vector2i] = []
	if m.has_method("default_spawn"):
		var sp: Vector2 = m.call("default_spawn")
		core.append(Vector2i(floori(sp.x / GameMap.TILE), floori(sp.y / GameMap.TILE)))
	for e in m.exits:
		var er: Rect2i = e["rect"]
		var inw := Vector2i(1 if er.position.x <= 0 else (-1 if er.end.x >= m.cols else 0), 1 if er.position.y <= 0 else (-1 if er.end.y >= m.rows else 0))
		for c: Vector2i in m.cells_of([er]):
			for k in range(0, 4):
				core.append(c + inw * k)
	for c: Vector2i in core:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out[c + Vector2i(dx, dy)] = true
	return out


static func clear_arrivals(m: GameMap) -> void:
	if not is_instance_valid(m):
		return
	for c: Vector2i in arrival_cells(m):
		var t: Dictionary = m.things.get(c, {})
		var ty := str(t.get("type", ""))
		if ty != "" and ty != "forage":
			continue
		var n: Variant = m.props.get(c)
		if not (n is Sprite2D) or not is_instance_valid(n):
			continue
		var tex := (n as Sprite2D).texture
		var file := tex.resource_path.get_file() if tex != null else ""
		var decor := false
		for w: String in ARRIVAL_DECOR:
			if file.begins_with(w) or file.contains("_" + w):
				decor = true
		if ty == "forage" or (decor and not file.contains("tree")):
			(n as Node).queue_free()
			m.props.erase(c)
			if ty == "forage":
				m.things.erase(c)
				m.blocked.erase(c)
