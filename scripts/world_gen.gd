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
	for y in range(1, m.rows - 1):
		for x in range(1, m.cols - 1):
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
	for nm: String in later:
		for p: Vector2 in later[nm]:
			Art.draw_prop(m, "nature", nm, p)
	# Placed once per map (this runs from _draw, which repeats on every redraw).
	if not m.has_meta("wx_dressed"):
		m.set_meta("wx_dressed", true)
		weather_dressing(m, seed_v + 99, avoid)


## Weather on the ground (Prompts 09 wx sheet): puddles on wet days, snowdrifts
## and icicles in winter. Decorative only; they never block.
static func weather_dressing(m: GameMap, seed_v: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# A region's own weather wins over the calendar (no puddles in snowy colony_ice or the clear sky).
	var rd: Variant = m.get("R")
	var ov := str((rd as Dictionary).get("weather", "")) if rd is Dictionary else ""
	var winter := GameState.season() == "winter" or ov in ["snow", "blizzard"]
	var wet := GameState.is_wet() and ov in ["", "rain", "storm"]
	if not wet and not winter:
		return
	var n := int(m.cols * m.rows * (0.012 if wet else 0.008))
	for i in n:
		var c := Vector2i(rng.randi_range(2, m.cols - 3), rng.randi_range(2, m.rows - 3))
		if m.blocked.has(c) or m.things.has(c) or avoid.has(c) or m.is_water_cell(c):
			continue
		if wet and Art.has("props", "puddle_storm_0") and int(Art.info("props", "puddle_storm_0").get("frames", 1)) > 1:
			_puddle(m, c, rng, GameState.weather_today() == "storm")
		elif winter and Art.has("props", "snowdrift_0"):
			m.prop("props", "snowdrift_%d" % rng.randi_range(0, 5), c, 0, 0.0, false)


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


## Random clusters of trees inside a rect.
static func tree_clumps(m: GameMap, rect: Rect2i, seed_v: int, clumps: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in clumps:
		var cx := rng.randi_range(rect.position.x, rect.end.x - 1)
		var cy := rng.randi_range(rect.position.y, rect.end.y - 1)
		var n := rng.randi_range(2, 5)
		for k in n:
			var c := Vector2i(cx + rng.randi_range(-2, 2), cy + rng.randi_range(-1, 1))
			if not rect.has_point(c) or m.things.has(c) or m.blocked.has(c) or avoid.has(c) or m.is_cleared(c):
				continue
			m.set_thing(c.x, c.y, {"type": "tree", "hp": 4, "hint": "A: chop"})
			m.prop("nature", GameState.tree_sprite(rng.randi_range(0, 2)), c)


## Rocks, logs, stumps, bushes scattered as interactable props.
static func scatter_props(m: GameMap, rect: Rect2i, seed_v: int, count: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var season := GameState.look_se()
	for i in count:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		var r := rng.randf()  # rolled first so the layout doesn't shift as things are cleared
		if m.things.has(c) or m.blocked.has(c) or avoid.has(c) or (r < 0.62 and m.is_cleared(c, 8 if r < 0.35 else 10)):
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
			var nm: String = {"fall": "log_fall", "summer": "logs"}.get(season, "log")
			m.set_thing(c.x, c.y, {"type": "log", "hp": 2, "hint": "A: chop"})
			m.prop("nature", nm if Art.has("nature", nm) else "log", c, 1 if nm == "log" else 0)
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
	var pool: Array = kinds if not kinds.is_empty() else ["sparrow", "sparrow", "butterfly_orange", "butterfly_blue", "rabbit", "squirrel", "bee"]
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
		var cr := Critter.new()
		cr.map = m
		cr.kind = kind
		cr.position = m.cell_center(c)
		cr.home = cr.position
		m.add_child(cr)


## Kinds that live in water only: spawned on water cells and kept there.
const WATER_CRITTERS := ["fish_jump"]  # (jungle jellies float in the air: flyers)


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


## A simple critter: a 2-frame drawn animal (no art yet for most) that wanders.
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

	func _ready() -> void:
		var g := "wildlife/" + kind
		_flyer = kind in ["sparrow", "crow", "seagull", "bat", "owl", "bee", "firefly", "dragonfly", "butterfly_orange", "butterfly_blue", "butterfly_yellow", "butterfly", "crystal_fish", "heron", "jelly"]
		if Art.has(g, "idle"):
			_anim = AnimatedSprite2D.new()
			var anims := {"idle": "idle"}
			anims["walk"] = "walk" if Art.has(g, "walk") else "idle"
			_anim.sprite_frames = Art.frames(g, anims, {"idle": 4.0 if _flyer else 3.0, "walk": 8.0})
			# Ground animals' idle strips are separate poses, not a loop: hold
			# the first pose and only now and then glance about (no twitching).
			var sf := _anim.sprite_frames
			if not _flyer and sf.has_animation("idle") and sf.get_frame_count("idle") > 1:
				sf.set_frame("idle", 0, sf.get_frame_texture("idle", 0), 9.0)
			_anim.animation = "idle"
			# True-to-world sizes: the hero is ~16px wide, so a duck is a third of that.
			var sz: float = {"sparrow": 0.2, "robin": 0.2, "finch": 0.2, "blue_jay": 0.22, "crow": 0.26, "pigeon": 0.22, "seagull": 0.26, "owl": 0.3, "hawk": 0.32, "bat": 0.24, "duck": 0.26, "heron": 0.38, "rabbit": 0.26, "squirrel": 0.22, "hedgehog": 0.24, "frog": 0.18, "turtle": 0.26, "mouse": 0.16, "rat": 0.2, "snake": 0.26, "butterfly_orange": 0.16, "butterfly_blue": 0.16, "butterfly_yellow": 0.16, "butterfly_purple": 0.16, "butterfly": 0.16, "bee": 0.12, "firefly": 0.12, "dragonfly": 0.16, "ladybug": 0.12, "grasshopper": 0.14, "snail": 0.16, "crab": 0.22, "deer": 0.5, "fox": 0.4, "boar": 0.46, "goat": 0.44, "raccoon": 0.34, "badger": 0.36, "otter": 0.34, "beaver": 0.34, "cat_grey": 0.36, "cat_orange": 0.36, "cat_black": 0.36, "stray_dog": 0.42, "jelly": 0.4, "six_deer": 0.5, "eagle": 0.36, "crystal_fish": 0.26, "fish_jump": 0.26}.get(kind, 0.3)
			_anim.scale = Vector2(sz, sz)
			# Feet on the ground for every frame, including the first frame after
			# an idle/walk swap (strips have different cell heights: no pop).
			_anim.frame_changed.connect(_fit)
			_anim.animation_changed.connect(_fit)
			add_child(_anim)
			_anim.play("idle")
			_fit()

	func _fit() -> void:
		var tex := _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
		if tex:
			_anim.offset = Vector2(0, -tex.get_height() / 2.0)

	func _process(delta: float) -> void:
		_t += delta
		_timer -= delta
		var to_player := map.player.position - position if map and map.player else Vector2(999, 999)
		if to_player.length() < 40.0 and not _flee:
			_flee = true
			_dir = -to_player.normalized()
			_timer = 1.2 if kind != "bird" else 2.5
		if _timer <= 0.0:
			_flee = false
			_timer = randf_range(1.0, 3.0)
			_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() if randf() < 0.6 else Vector2.ZERO
			if position.distance_to(home) > 80.0:
				_dir = (home - position).normalized()
		var spd := 60.0 if _flee else 14.0
		if _flyer and _flee:
			spd = 110.0
		if kind.begins_with("butterfly") or kind == "bee":
			spd = 18.0
		var np := position + _dir * spd * delta
		if _flyer and _flee:
			position = np
			if position.distance_to(home) > 400.0:
				queue_free()
		elif kind in WorldGen.WATER_CRITTERS:
			# Fish stay in deep water: a step that would reach the shore is refused.
			if map and WorldGen._deep_water(map, map.world_to_cell(np - Vector2(0, 2))):
				position = np
			else:
				_dir = Vector2.ZERO
		elif map and not map.rect_blocked(Rect2(np + Vector2(-2, -2), Vector2(4, 2))) and not map.is_water_cell(map.world_to_cell(np - Vector2(0, 2))):
			position = np
		if _anim:
			var moving := _dir != Vector2.ZERO
			var want := "walk" if moving else "idle"
			if _anim.animation != want:
				_anim.play(want)
			# Legs keep pace with the ground (no sliding at a stroll, no
			# scrabbling in place): the walk strip is tuned for ~28 px/s.
			_anim.speed_scale = clampf(spd / 28.0, 0.5, 2.0) if moving and not _flyer else 1.0
			# Turn only on a clear sideways lead (no flip-flicker on near-vertical moves).
			if absf(_dir.x) > 0.25:
				_anim.flip_h = _dir.x < 0
			_anim.position.y = -14.0 - sin(_t * 10.0) * 2.0 if _flyer and _flee else (-6.0 - sin(_t * 4.0) * 2.0 if _flyer else 0.0)
		else:
			queue_redraw()  # the sprite animates itself; its shadow follows position

	func _draw() -> void:
		if _anim:
			draw_circle(Vector2(0, 0), 3.0, Color(0, 0, 0, 0.15))
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
	var shrubs: Array = {"spring": ["bush", "bush2_green", "bush2_flower", "ferns", "hedge", "bush_white"], "summer": ["bush", "bush2_green", "ferns", "hedge", "bush2_yellow", "sunflower_bush"], "fall": ["bush_fall_orange", "bush_fall_red", "ferns", "bush2_red", "hedge"], "winter": ["bush_snow", "bush_bare_snow", "bush_snow", "hedge"]}.get(se, ["bush"])
	var young: Array = {"spring": ["mid_oak_b", "mid_birch_b", "mid_pine_b", "mid_cherry_b"], "summer": ["mid_oak_b", "mid_birch_b", "mid_pine_b", "mid_willow_b"], "fall": ["mid_maple_b", "mid_oak_b", "mid_pine_b"], "winter": ["mid_snowpine_b", "mid_dead_b", "mid_snowpine"]}.get(se, ["mid_oak_b"])
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
			for dy in range(-1, 3):
				var c := st + Vector2i(0, dy)
				var t := str(m.things.get(c, {}).get("type", ""))
				if t in ["tree", "rock", "log", "stump", "bush", "weeds", "forage", "grove"] or (t == "" and m.props.has(c) and m.blocked.has(c) and dy != -1):
					m.things.erase(c)
					if dy >= 0 or t != "":
						m.blocked.erase(c)
						m.hard.erase(c)
					var sp: Node = m.props.get(c, null)
					m.props.erase(c)
					if sp:
						sp.queue_free()


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
	for y in range(y0, y1 + 1):
		var cham := 0
		if y == y0:
			cham = 2
		elif y == y0 + 1:
			cham = 1
		elif y == y1:
			cham = 1
		if hold_l <= 0:
			ol = clampi(ol + rng.randi_range(-1, 1), -1, 2)
			hold_l = rng.randi_range(3, 5)
		if hold_r <= 0:
			orr = clampi(orr + rng.randi_range(-1, 1), -1, 2)
			hold_r = rng.randi_range(3, 5)
		hold_l -= 1
		hold_r -= 1
		var xa := roundi(center.x - rx) + maxi(ol, 0) + cham
		var xb := roundi(center.x + rx) - maxi(orr, 0) - cham
		for x in range(xa, xb + 1):
			if x >= margin and y >= margin and x < m.cols - margin and y < m.rows - margin:
				cells[Vector2i(x, y)] = true
	return smooth_cells(cells)
