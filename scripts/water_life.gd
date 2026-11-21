class_name WaterLife
extends Node2D
## C14b P1 (c14b_01-15): life on still water. One per outdoor map with water:
## every 1.5-4 s of game time a soft ripple ring opens on a random on-screen water
## cell away from the shore, every 20-40 s a fish jumps in deep water, and in rain
## or storms small splashes dot the visible water. Ground level (under the player),
## game time only (stops while paused), capped for phones, calmer with reduced motion.

const MAX_LIVE := 6
var map: GameMap
var _next_ring := 2.0
var _next_fish := 15.0
var _rain_acc := 0.0
var _live := 0
var _cells_cache: Array = []  # sampled water cells (refreshed when empty)


func _ready() -> void:
	_next_ring = randf_range(1.0, 3.0)
	_next_fish = randf_range(12.0, 30.0)


func _view_cells() -> Rect2i:
	var xf := get_viewport().get_canvas_transform()
	var r := xf.affine_inverse() * get_viewport_rect()
	var a := map.world_to_cell(r.position)
	var b := map.world_to_cell(r.end)
	return Rect2i(a, b - a + Vector2i.ONE)


## A random on-screen water cell whose ring of neighbours (radius 1, or 2 for deep) is water.
func _pick(deep: bool) -> Vector2i:
	var v := _view_cells()
	if v.size.x <= 0 or v.size.y <= 0:
		return Vector2i(-9999, -9999)
	for i in 14:
		var c := Vector2i(v.position.x + randi() % v.size.x, v.position.y + randi() % v.size.y)
		if not map.is_water_cell(c):
			continue
		var rad := 2 if deep else 1
		var ok := true
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if not map.is_water_cell(c + Vector2i(dx, dy)):
					ok = false
					break
			if not ok:
				break
		if ok:
			return c
	return Vector2i(-9999, -9999)


func _spawn(name: String, c: Vector2i, fps: float, sc: float, alpha: float) -> void:
	if _live >= MAX_LIVE or not Art.has("fx", name):
		return
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = Art.frames("fx", {name: name}, {name: fps}, {name: false})
	sp.animation = name
	sp.position = map.cell_pos(c.x + randf_range(0.2, 0.8), c.y + randf_range(0.2, 0.8))
	sp.scale = Vector2(sc, sc)
	sp.modulate = Color(1, 1, 1, alpha)
	sp.set_meta("anim_ph", true)  # one-shot: keep frame 0 start
	map.to_under(sp)
	sp.play(name)
	_live += 1
	sp.animation_finished.connect(func() -> void:
		_live -= 1
		sp.queue_free())


func _process(delta: float) -> void:
	if map == null or not is_instance_valid(map):
		return
	var calm := Anim.reduced()
	_next_ring -= delta
	if _next_ring <= 0.0:
		_next_ring = randf_range(1.5, 4.0) * (2.0 if calm else 1.0)
		var c := _pick(false)
		if c.x > -9999:
			_spawn("ripple_ring", c, 8.0, randf_range(0.3, 0.5), 0.55)
	_next_fish -= delta
	if _next_fish <= 0.0:
		_next_fish = randf_range(20.0, 40.0)
		var c := _pick(true)
		if c.x > -9999:
			_spawn("fish_jump_a" if randf() < 0.6 or not Art.has("fx", "fish_jump_b") else "fish_jump_b", c, 10.0, 0.4, 0.9)
	var w := map.sky.weather if map.sky else ""
	if w in ["rain", "storm", "drizzle"]:
		var per_s := (2.0 if calm else (10.0 if w == "storm" else (6.0 if w == "rain" else 3.0)))
		_rain_acc += delta * per_s
		while _rain_acc >= 1.0:
			_rain_acc -= 1.0
			var c := _pick(false)
			if c.x > -9999:
				_spawn("rain_splash", c, 12.0, 0.35, 0.6)
	else:
		_rain_acc = 0.0
