class_name Player
extends Node2D
## The character you control.
## Input: D-pad/WASD/arrows move, B (X/Shift) runs (hold or tap-toggle), A (Z/Space)
## interacts with the cell in front of you or swings your sword. Tapping the
## world (or clicking with the mouse) walks there and uses what's in your hand
## on it when you arrive, Stardew-mobile style.

const WALK_SPEED := 58.0
const RUN_SPEED := 108.0
const ACCEL := 560.0
const DECEL := 760.0
const PLAY_TIME := 1.5
const FEET := Rect2(-4, -3, 8, 3)

var char_id := ""
var facing := "down"  # down, up, left, right
var anim_name := ""
var velocity := Vector2.ZERO
var map: GameMap
var frozen := false
var invuln := 0.0
## Tap-to-move target in world space; INF when none.
var auto_target := Vector2.INF
var auto_cell := Vector2i(-1, -1)

var _sprite: Node2D
var _anim: AnimatedSprite2D
var _busy := false
var _busy_t := 0.0
var _play_left := 0.0
var _bob := 0.0
var _dust_timer := 0.0
var _shadow: Node2D
var _attack_hit_done := false
var _stuck_t := 0.0


func set_character(id: String) -> void:
	GameState.load_data()
	if _sprite:
		_sprite.queue_free()
	char_id = id
	var pid := str(GameState.run.get("playable", ""))
	var pdata: Dictionary = GameState.playables.get(pid, {})
	if id == "" or not CharacterLibrary.has_character(id):
		var ph := PlaceholderSprite.new()
		ph.tint = Color(str(pdata.get("color", "2b3a67")))
		_sprite = ph
		_anim = null
	else:
		_anim = CharacterLibrary.make_sprite(id)
		_anim.animation_finished.connect(_on_animation_finished)
		if pdata.has("tint"):
			_anim.modulate = Color(str(pdata["tint"]))
		_sprite = _anim
	if _shadow == null:
		_shadow = Node2D.new()
		_shadow.draw.connect(func() -> void: _shadow.draw_circle(Vector2(0, -0.5), 5.0, Color(0, 0, 0, 0.22)))
		_shadow.scale = Vector2(1.0, 0.45)
		add_child(_shadow)
	add_child(_sprite)
	_busy = false
	anim_name = ""
	_show_idle()


func has_anim(a: String) -> bool:
	return _anim != null and _anim.sprite_frames.has_animation(a)


func facing_dir() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


func facing_cell() -> Vector2i:
	return cell() + Vector2i(facing_dir())


func cell() -> Vector2i:
	return Vector2i(floori(position.x / GameMap.TILE), floori((position.y - 2) / GameMap.TILE))


func face_toward(p: Vector2) -> void:
	var d := p - (position + Vector2(0, -8))
	if absf(d.x) > absf(d.y):
		facing = "left" if d.x < 0 else "right"
	else:
		facing = "up" if d.y < 0 else "down"


func go_to_cell(c: Vector2i, interact_there: bool) -> void:
	# Walk to a cell. If it's something to use, stop next to it and face it.
	auto_cell = c if interact_there else Vector2i(-1, -1)
	if interact_there:
		var target := map.cell_center(c)
		var d := target - position
		if d.length() < GameMap.TILE * 1.2:
			auto_target = Vector2.INF
			auto_cell = Vector2i(-1, -1)
			face_toward(target)
			_do_action()
			return
		# Pick the neighbouring cell nearest to us that isn't blocked.
		var best := Vector2.INF
		for off: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = c + off
			if map.blocked.has(n):
				continue
			var p := map.cell_center(n)
			if best == Vector2.INF or p.distance_to(position) < best.distance_to(position):
				best = p
		auto_target = best if best != Vector2.INF else target
	else:
		auto_target = map.cell_center(c)
	_stuck_t = 0.0


func _physics_process(delta: float) -> void:
	if _sprite == null:
		return
	invuln = maxf(0.0, invuln - delta)
	if _anim:
		var base := Color.WHITE
		var pid := str(GameState.run.get("playable", ""))
		var pdata: Dictionary = GameState.playables.get(pid, {})
		if pdata.has("tint"):
			base = Color(str(pdata["tint"]))
		_anim.modulate = Color(base, 0.5 if invuln > 0.0 and int(invuln * 20) % 2 == 0 else 1.0)
	if frozen:
		velocity = Vector2.ZERO
		auto_target = Vector2.INF
		_show_idle()
		return
	var dir := Input.get_vector("left", "right", "up", "down")
	if dir != Vector2.ZERO:
		auto_target = Vector2.INF
		auto_cell = Vector2i(-1, -1)
	if _busy:
		_busy_t += delta
		if _busy_t > 1.2:
			_busy = false  # watchdog: never stay stuck in an action
	else:
		_busy_t = 0.0

	if Input.is_action_just_pressed("a") and not _busy and not Dialogue.input_blocked():
		auto_target = Vector2.INF
		_do_action()
		return
	if Input.is_action_just_pressed("b") and dir == Vector2.ZERO and not _busy and has_anim("play") and not Dialogue.input_blocked():
		_busy = true
		_play_left = PLAY_TIME
		_apply("play", facing == "left")
		return
	if _busy:
		if anim_name == "play":
			_play_left -= delta
			if _play_left > 0.0 and dir == Vector2.ZERO:
				return
			_busy = false
		elif anim_name == "attack":
			if _anim and _anim.frame >= 1 and not _attack_hit_done:
				_attack_hit()
			return
		else:
			_busy = false

	# Tap-to-move steering.
	var auto := false
	if dir == Vector2.ZERO and auto_target != Vector2.INF:
		var to := auto_target - position
		if to.length() < 3.0:
			auto_target = Vector2.INF
			if auto_cell != Vector2i(-1, -1):
				face_toward(map.cell_center(auto_cell))
				auto_cell = Vector2i(-1, -1)
				velocity = Vector2.ZERO
				_do_action()
				return
		else:
			dir = to.normalized()
			auto = true

	var running := Input.is_action_pressed("b") or TouchControls.run_toggle or (auto and auto_target.distance_to(position) > 48.0)
	var target := dir * (RUN_SPEED if running else WALK_SPEED)
	var rate := ACCEL if dir != Vector2.ZERO else DECEL
	velocity = velocity.move_toward(target, rate * delta)
	var before := position
	_move(velocity * delta)
	if auto:
		# Give up if a wall stops us.
		if position.distance_to(before) < 0.2:
			_stuck_t += delta
			if _stuck_t > 0.35:
				auto_target = Vector2.INF
				auto_cell = Vector2i(-1, -1)
		else:
			_stuck_t = 0.0

	var speed := velocity.length()
	if dir == Vector2.ZERO and speed < 4.0:
		velocity = Vector2.ZERO
		_sprite.position.y = 0
		_show_idle()
		return

	var move_dir := dir if dir != Vector2.ZERO else velocity.normalized()
	var is_run := speed > WALK_SPEED * 1.15
	if absf(move_dir.x) >= absf(move_dir.y) * 0.9:
		facing = "left" if move_dir.x < 0 else "right"
		_sprite.position.y = 0
		_apply("run" if is_run else "walk", move_dir.x < 0)
	else:
		facing = "up" if move_dir.y < 0 else "down"
		var vert := ("run_" if is_run else "walk_") + facing
		if has_anim(vert):
			_sprite.position.y = 0
			_apply(vert, false)
		else:
			# No toward/away art for this character: front/back view with a bob.
			_apply("view_back" if move_dir.y < 0 else "view_front", false)
			_bob += delta * speed * 0.16
			_sprite.position.y = -absf(sin(_bob)) * 2.0
	if _anim:
		_anim.speed_scale = clampf(speed / (RUN_SPEED if is_run else WALK_SPEED), 0.6, 1.3)

	_dust_timer -= delta
	if is_run and _dust_timer <= 0.0:
		_dust_timer = 0.14
		_puff(-move_dir)


func _do_action() -> void:
	if map and map.try_interact(facing_cell()):
		velocity = Vector2.ZERO
		_show_idle()
		return
	_busy = true
	_attack_hit_done = false
	velocity = Vector2.ZERO
	_sprite.position.y = 0
	_apply("attack", facing == "left", true)
	if _anim == null:
		_attack_hit()
		_busy = false


func _move(step: Vector2) -> void:
	if map == null:
		position += step
		return
	var nx := position + Vector2(step.x, 0)
	if not map.rect_blocked(Rect2(nx + FEET.position, FEET.size)):
		position = nx
	else:
		velocity.x = 0
	var ny := position + Vector2(0, step.y)
	if not map.rect_blocked(Rect2(ny + FEET.position, FEET.size)):
		position = ny
	else:
		velocity.y = 0


func _attack_hit() -> void:
	_attack_hit_done = true
	if map:
		var center := position + facing_dir() * 10.0 + Vector2(0, -6)
		map.attack_at(Rect2(center - Vector2(11, 11), Vector2(22, 22)), GameState.sword_damage())
		_swing_arc(center)


## Stardew-style sword arc in the facing direction.
func _swing_arc(center: Vector2) -> void:
	var fx := Node2D.new()
	fx.position = center
	fx.z_index = 2
	var age := [0.0]
	var ang := facing_dir().angle()
	fx.draw.connect(func() -> void:
		var a: float = age[0]
		var col := Color(1, 1, 0.85, 0.8 * (1.0 - a))
		fx.draw_arc(Vector2.ZERO, 11.0 + a * 4.0, ang - 1.1, ang + 1.1, 12, col, 2.5))
	get_parent().add_child(fx)
	var tw := fx.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; fx.queue_redraw(), 0.0, 1.0, 0.18)
	tw.tween_callback(fx.queue_free)


func take_damage(n: int, from: Vector2) -> void:
	if invuln > 0.0:
		return
	invuln = 0.9
	GameState.run["hp"] = int(GameState.run["hp"]) - n
	velocity = (position - from).normalized() * 160.0
	auto_target = Vector2.INF
	Music.instance(get_tree()).sfx("hurt")
	if int(GameState.run["hp"]) <= 0 and map:
		map.player_down()


func _puff(back: Vector2) -> void:
	var d := Node2D.new()
	d.position = position + back * 3.0
	d.z_index = -1
	var age := [0.0]
	d.draw.connect(func() -> void:
		var a: float = age[0]
		d.draw_circle(Vector2(0, -1 - a * 6.0), 1.5 + a * 2.5, Color(0.95, 0.9, 0.8, 0.5 * (1.0 - a))))
	get_parent().add_child(d)
	var tw := d.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; d.queue_redraw(), 0.0, 1.0, 0.4)
	tw.tween_callback(d.queue_free)


func _show_idle() -> void:
	if _anim:
		_anim.speed_scale = 1.0
	match facing:
		"up":
			_apply("view_back", false)
		"left":
			_apply("view_left", false)
		"right":
			_apply("view_right", false)
		_:
			_apply("idle", false)


func _apply(a: String, flip: bool, restart := false) -> void:
	if _anim == null:
		anim_name = a
		_sprite.scale.x = -1.0 if flip else 1.0
		return
	if not _anim.sprite_frames.has_animation(a):
		a = "idle"
	_anim.flip_h = flip
	if restart or anim_name != a:
		anim_name = a
		_anim.play(a)


func _on_animation_finished() -> void:
	if anim_name == "attack" or anim_name == "powerup":
		_busy = false
		_show_idle()
