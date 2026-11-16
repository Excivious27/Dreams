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


static func draw_ground_detail(m: GameMap, seed_v: int, density := 0.12, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var season := GameState.season()
	for y in range(1, m.rows - 1):
		for x in range(1, m.cols - 1):
			var c := Vector2i(x, y)
			if m.blocked.has(c) or m.things.has(c) or avoid.has(c):
				continue
			var r := rng.randf()
			if r > density:
				continue
			var at := Vector2(x * TILE, y * TILE)
			if season == "spring" or season == "summer":
				if r < density * 0.5:
					Art.draw_tile(m, "tiles", "deco_%d" % rng.randi_range(0, 2), at)
				elif r < density * 0.8:
					Art.draw_tile(m, "tiles", "deco_%d" % rng.randi_range(3, 5), at)
				elif Art.has("nature", "gdeco_tuft_a") and rng.randf() < 0.6:
					Art.draw_prop(m, "nature", ["gdeco_tuft_a", "gdeco_tuft_b", "gdeco_tuft_c", "gdeco_clover", "gdeco_dandelion"][rng.randi_range(0, 4)], at + Vector2(8, 16))
				else:
					Art.draw_prop(m, "nature", "flowers" if season == "spring" else "sunflowers", at + Vector2(8, 16))
			elif season == "fall":
				if r < density * 0.6:
					Art.draw_prop(m, "nature", "flowers_fall", at + Vector2(8, 16))
				else:
					Art.draw_prop(m, "nature", "mushrooms_fall", at + Vector2(8, 16))
			else:
				if r < density * 0.5:
					Art.draw_tile(m, "tiles", "deco_0", at)


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
		if skip or m.things.has(c):
			continue
		var jitter := Vector2i(rng.randi_range(0, 1), 0) if every > 1 else Vector2i.ZERO
		var cc := c + jitter
		if cc.x >= m.cols - 1:
			cc = c
		m.set_thing(cc.x, cc.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
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
			if not rect.has_point(c) or m.things.has(c) or m.blocked.has(c) or avoid.has(c):
				continue
			m.set_thing(c.x, c.y, {"type": "tree", "hp": 3, "hint": "A: chop"})
			m.prop("nature", GameState.tree_sprite(rng.randi_range(0, 2)), c)


## Rocks, logs, stumps, bushes scattered as interactable props.
static func scatter_props(m: GameMap, rect: Rect2i, seed_v: int, count: int, avoid: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var season := GameState.season()
	for i in count:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		if m.things.has(c) or m.blocked.has(c) or avoid.has(c):
			continue
		var r := rng.randf()
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
			var has := int(GameState.run["flags"].get(key, 0)) < int(GameState.run["day"])
			m.set_thing(c.x, c.y, {"type": "bush", "key": key, "berries": has, "hint": "A: pick berries" if has else ""})
			m.prop("nature", GameState.bush_sprite(has), c)


## Wildlife: small critters that hop around and flee from the player.
static func add_critters(m: GameMap, rect: Rect2i, seed_v: int, count: int, kinds: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		if m.blocked.has(c):
			continue
		var cr := Critter.new()
		cr.map = m
		var pool: Array = kinds if not kinds.is_empty() else ["sparrow", "sparrow", "butterfly_orange", "butterfly_blue", "rabbit", "squirrel", "bee"]
		cr.kind = pool[rng.randi_range(0, pool.size() - 1)]
		cr.position = m.cell_center(c)
		cr.home = cr.position
		m.add_child(cr)


## A painted sky strip behind the map (parallax), plus distant hills.
static func add_backdrop(m: GameMap, kind := "hills") -> void:
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
		_flyer = kind in ["sparrow", "crow", "seagull", "bat", "owl", "bee", "firefly", "dragonfly", "butterfly_orange", "butterfly_blue", "butterfly_yellow", "butterfly", "crystal_fish", "heron"]
		if Art.has(g, "idle"):
			_anim = AnimatedSprite2D.new()
			var anims := {"idle": "idle"}
			anims["walk"] = "walk" if Art.has(g, "walk") else "idle"
			_anim.sprite_frames = Art.frames(g, anims, {"idle": 4.0, "walk": 8.0})
			_anim.animation = "idle"
			var sz: float = {"sparrow": 0.22, "crow": 0.3, "pigeon": 0.26, "seagull": 0.3, "bat": 0.28, "owl": 0.32, "bee": 0.16, "firefly": 0.16, "dragonfly": 0.2, "butterfly_orange": 0.2, "butterfly_blue": 0.2, "butterfly_yellow": 0.2, "butterfly": 0.2, "rabbit": 0.34, "squirrel": 0.3, "hedgehog": 0.3, "frog": 0.26, "turtle": 0.34, "crab": 0.26, "rat": 0.28, "duck": 0.36, "heron": 0.5, "deer": 0.55, "fox": 0.45, "goat": 0.5, "cat_grey": 0.4, "cat_orange": 0.4, "cat_black": 0.4, "stray_dog": 0.45, "jelly": 0.5, "six_deer": 0.55, "eagle": 0.4, "crystal_fish": 0.3, "fish_jump": 0.3}.get(kind, 0.4)
			_anim.scale = Vector2(sz, sz)
			_anim.frame_changed.connect(func() -> void:
				var tex := _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
				if tex:
					_anim.offset = Vector2(0, -tex.get_height() / 2.0))
			add_child(_anim)
			_anim.play("idle")

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
		elif map and not map.rect_blocked(Rect2(np + Vector2(-2, -2), Vector2(4, 2))):
			position = np
		if _anim:
			var moving := _dir != Vector2.ZERO
			var want := "walk" if moving else "idle"
			if _anim.animation != want:
				_anim.play(want)
			if _dir.x != 0.0:
				_anim.flip_h = _dir.x < 0
			_anim.position.y = -14.0 - sin(_t * 10.0) * 2.0 if _flyer and _flee else (-6.0 - sin(_t * 4.0) * 2.0 if _flyer else 0.0)
		queue_redraw()

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
		queue_redraw()

	func _draw() -> void:
		var W := 900.0
		var H := 1200.0
		var t := int(GameState.run.get("time", 480))
		var dark := clampf((t - 18 * 60) / 360.0, 0.0, 1.0)
		var strip_name: String = {"hills": "sky_day", "mountains": "sky_mountains", "sea": "sky_sea", "forest": "sky_forest", "night": "sky_night", "moon": "sky_night", "space": "sky_night"}.get(kind, "")
		if t >= 17 * 60 and t < 20 * 60 and kind in ["hills", "forest"]:
			strip_name = "sky_sunset"
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
