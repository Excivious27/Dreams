class_name CampaignConvoy
extends Node2D
## The supply convoy of an escort battle (Campaign): a covered wagon (penguins:
## a crystal sled) that rolls from point to point toward its goal. It only rolls
## while you or a helper walk beside it and no foe stands on it; foes go for it.
## It is in the "allies" group, so enemies pick it as a target and hit it.

const SPEED := 20.0
const ESCORT_R := 72.0
const BLOCK_R := 34.0

var map: GameMap
var path: Array = []      # world positions, first = start
var _i := 1
var hp := 100
var max_hp := 100
var arrived := false
var state := "wait"       # wait (no friend near), roll, blocked (foe on it)
var _hit_cd := 0.0        # sounds: one hit sound per HIT_GAP, one alert per stop
var _rolled := false
const HIT_GAP := 0.4
var _hurt := 0.0
var _t := 0.0
var _face := 1.0
var _roll_t := 0.0        # rolling sound tick
var _warned := false      # "badly hurt" said once
var _honk_t := 0.0        # left-behind honk throttle


static func make(m: GameMap, waypoints: Array, life: int) -> CampaignConvoy:
	var c := CampaignConvoy.new()
	c.map = m
	c.path = waypoints
	c.max_hp = life
	c.hp = life
	c.position = (waypoints[0] as Vector2) + Vector2(0, 18)
	c.z_index = 1
	c.add_to_group("allies")
	m.add_child(c)
	return c


func progress() -> float:
	if path.size() < 2:
		return 1.0
	var total := 0.0
	var done := 0.0
	for k in range(1, path.size()):
		var seg := (path[k - 1] as Vector2).distance_to(path[k])
		total += seg
		if k < _i:
			done += seg
		elif k == _i:
			done += maxf(0.0, seg - position.distance_to(path[k]))
	return clampf(done / maxf(1.0, total), 0.0, 1.0) if not arrived else 1.0


func take_damage(n: int, _from: Vector2) -> void:
	if arrived or hp <= 0:
		return
	hp = maxi(0, hp - maxi(1, n))
	_hurt = 0.2
	if _hit_cd <= 0.0:
		_hit_cd = HIT_GAP
		_sfx("crate_break" if hp <= 0 else "hit")
	if not _warned and hp > 0 and hp < max_hp / 3:
		_warned = true
		map.hud.toast("The convoy is badly hurt!", Color(1, 0.6, 0.5))
		Music.instance(get_tree()).sfx("alert", "thud")  # heard anywhere: it's yours
	if hp <= 0:
		map.fx("poof", position + Vector2(0, -8), 12.0, 0.6)


func _sfx(n: String, fb := "pop") -> void:
	if map and map.player and position.distance_to(map.player.position) < 260.0:
		Music.instance(get_tree()).sfx(n, fb)


func provoke(_by: Node2D) -> void:
	pass


func _process(delta: float) -> void:
	if get_tree().paused or map == null or map.player == null or arrived or hp <= 0:
		return
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_honk_t = maxf(0.0, _honk_t - delta)
	var friend := map.player.position.distance_to(position) < ESCORT_R
	if not friend:
		for h in get_tree().get_nodes_in_group("allies"):
			if h is HelperUnit and (h as Node2D).position.distance_to(position) < ESCORT_R:
				friend = true
				break
	var foe := map.nearest_enemy_to(position, BLOCK_R)
	var was := state
	state = "blocked" if foe != null else ("roll" if friend else "wait")
	if state != was:
		if state == "blocked":
			_sfx("alert", "thud")  # foes on the convoy
		elif state == "roll" and not _rolled:
			_rolled = true
			_sfx("car_start" if not GameState.is_penguins() else "sled_bells", "j_confirm")  # it sets off
		elif state == "wait" and was == "roll" and _honk_t <= 0.0:
			# Left behind: a honk / bell to call you back (throttled).
			_honk_t = 6.0
			Music.instance(get_tree()).sfx("car_horn" if not GameState.is_penguins() else "sled_bells", "nope")
	if state == "roll":
		# Rolling: cart wheels / sled runners every ~0.6 s, near the player only.
		_roll_t -= delta
		if _roll_t <= 0.0:
			_roll_t = 0.6
			if position.distance_to(map.player.position) < 200.0:
				var mu := Music.instance(get_tree())
				if GameState.is_penguins():
					mu.step("snow")
				else:
					mu.step(Player.step_or(get_tree(), "wheels", "gravel"))
	if state == "roll" and _i < path.size():
		var goal: Vector2 = path[_i]
		if position.distance_to(goal) < 14.0:
			_i += 1
			if _i >= path.size():
				arrived = true
				map.fx("levelup", position + Vector2(0, -10), 10.0, 0.6)
				_sfx("car_horn" if not GameState.is_penguins() else "sled_bells", "levelup")  # never the bicycle horn
				queue_redraw()
				return
			goal = path[_i]
		var dir := map.flow_dir(position, goal) if position.distance_to(goal) > 24.0 else (goal - position).normalized()
		if dir.length() < 0.1:
			dir = (goal - position).normalized()
		var np := position + dir * SPEED * delta
		if _can_step(np):
			position = np
		else:
			for alt: Vector2 in [Vector2(dir.x, 0), Vector2(0, dir.y)]:
				if alt != Vector2.ZERO and _can_step(position + alt.normalized() * SPEED * delta):
					position += alt.normalized() * SPEED * delta
					break
		if absf(dir.x) > 0.2:
			_face = signf(dir.x)
	queue_redraw()


func _can_step(at: Vector2) -> bool:
	var c := map.world_to_cell(at)
	return not map.blocked.has(c) and (not map.is_water_cell(c) or map.is_water_cell(map.world_to_cell(position)))


func _draw() -> void:
	var bob := sin(_t * 8.0) * 0.6 if state == "roll" else 0.0
	draw_circle(Vector2(0, 1), 9.0, Color(0, 0, 0, 0.22))
	var tex: Texture2D = null
	var flip := GameState.is_penguins()
	if GameState.is_penguins():
		tex = Art.tex("props", "veh_crystal_sled_side")
	elif Art.has("props", "lux_car_black"):
		tex = Art.tex("props", "lux_car_black")  # the crew's convoy is a car (its engine and horn match)
		flip = true  # drawn facing left
	if tex == null:
		tex = Art.tex("props", "cart_covered")
	if tex == null:
		tex = Art.tex("props", "cart")
	var mod := Color(1, 0.6, 0.6) if _hurt > 0.0 else Color.WHITE
	if tex:
		var w := 30.0
		var h := w * tex.get_height() / tex.get_width()
		draw_set_transform(Vector2(0, bob), 0.0, Vector2(-_face if flip else _face, 1))
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, 3 - h), Vector2(w, h)), false, mod)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(-12, -14 + bob, 24, 12), Color(0.55, 0.38, 0.2) * mod)
		draw_rect(Rect2(-11, -22 + bob, 22, 9), Color(0.92, 0.88, 0.78) * mod)
		draw_circle(Vector2(-7, -1), 3.0, Color(0.2, 0.15, 0.1))
		draw_circle(Vector2(7, -1), 3.0, Color(0.2, 0.15, 0.1))
	# Life bar and a state mark: ▶ rolling, … waiting for a friend, ! foes on it.
	draw_rect(Rect2(-14, -32, 28, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-14, -32, 28.0 * hp / maxf(1.0, max_hp), 3), Color(0.45, 1, 0.55) if hp * 3 > max_hp else Color(1, 0.5, 0.4))
	var f := ThemeDB.fallback_font
	var mark := {"roll": "▶", "wait": "…", "blocked": "!"}.get(state, "") as String
	var mc := {"roll": Color(0.6, 1, 0.7), "wait": Color(1, 0.95, 0.7), "blocked": Color(1, 0.5, 0.4)}.get(state, Color.WHITE) as Color
	draw_string_outline(f, Vector2(-4, -36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-4, -36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, mc)
