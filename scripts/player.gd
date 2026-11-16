class_name Player
extends Node2D
## The character you control. D-pad moves, B held runs, A attacks.
## B tapped while standing plays the "play" animation if the character has one (dog).
## Movement eases in and out, animation speed follows actual velocity, and
## footstep dust puffs appear while running, so motion reads as fluid.

const WALK_SPEED := 58.0
const RUN_SPEED := 110.0
const ACCEL := 520.0
const DECEL := 700.0
const PLAY_TIME := 1.5

var bounds := Rect2(-100000, -100000, 200000, 200000)
var char_id := ""
var facing := "down"  # down, up, left, right
var anim_name := ""
var velocity := Vector2.ZERO

var _sprite: Node2D
var _anim: AnimatedSprite2D
var _busy := false
var _play_left := 0.0
var _bob := 0.0
var _dust_timer := 0.0
var _shadow: Node2D


func set_character(id: String) -> void:
	if _sprite:
		_sprite.queue_free()
	char_id = id
	if id == "" or not CharacterLibrary.data().has(id):
		var ph := PlaceholderSprite.new()
		ph.tint = Color("2b3a67")
		_sprite = ph
		_anim = null
	else:
		_anim = CharacterLibrary.make_sprite(id)
		_anim.animation_finished.connect(_on_animation_finished)
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


func _physics_process(delta: float) -> void:
	if _sprite == null:
		return
	var dir := Input.get_vector("left", "right", "up", "down")

	if Input.is_action_just_pressed("a") and not _busy:
		_busy = true
		velocity = Vector2.ZERO
		_sprite.position.y = 0
		_apply("attack", facing == "left", true)
		return
	if Input.is_action_just_pressed("b") and dir == Vector2.ZERO and not _busy and has_anim("play"):
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
		elif _anim != null:
			return
		else:
			_busy = false

	var running := Input.is_action_pressed("b")
	var target := dir * (RUN_SPEED if running else WALK_SPEED)
	var rate := ACCEL if dir != Vector2.ZERO else DECEL
	velocity = velocity.move_toward(target, rate * delta)
	position = (position + velocity * delta).clamp(bounds.position, bounds.end)

	var speed := velocity.length()
	if dir == Vector2.ZERO and speed < 4.0:
		velocity = Vector2.ZERO
		_sprite.position.y = 0
		_show_idle()
		return

	var move_dir := dir if dir != Vector2.ZERO else velocity.normalized()
	if absf(move_dir.x) >= absf(move_dir.y) * 0.9:
		facing = "left" if move_dir.x < 0 else "right"
		_sprite.position.y = 0
		var is_run := speed > WALK_SPEED * 1.15
		_apply("run" if is_run else "walk", move_dir.x < 0)
		if _anim:
			_anim.speed_scale = clampf(speed / (RUN_SPEED if is_run else WALK_SPEED), 0.6, 1.3)
	else:
		# No walk-toward/away art yet: front/back view with a small bob.
		facing = "up" if move_dir.y < 0 else "down"
		_apply("view_back" if move_dir.y < 0 else "view_front", false)
		_bob += delta * speed * 0.16
		_sprite.position.y = -absf(sin(_bob)) * 2.0

	_dust_timer -= delta
	if speed > WALK_SPEED * 1.15 and _dust_timer <= 0.0:
		_dust_timer = 0.14
		_puff(-move_dir)


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
	_anim.flip_h = flip
	if restart or anim_name != a:
		anim_name = a
		_anim.play(a)


func _on_animation_finished() -> void:
	if anim_name == "attack":
		_busy = false
