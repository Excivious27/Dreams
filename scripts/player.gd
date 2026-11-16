class_name Player
extends Node2D
## The character you control. D-pad moves, B held runs, A attacks.
## B tapped while standing plays the "play" animation if the character has one (dog).

const WALK_SPEED := 55.0
const RUN_SPEED := 105.0
const PLAY_TIME := 1.5

var bounds := Rect2(-100000, -100000, 200000, 200000)
var char_id := ""
var facing := "down"  # down, up, left, right
var anim_name := ""

var _sprite: AnimatedSprite2D
var _busy := false
var _play_left := 0.0
var _bob := 0.0


func set_character(id: String) -> void:
	if _sprite:
		_sprite.queue_free()
	char_id = id
	_sprite = CharacterLibrary.make_sprite(id)
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_busy = false
	anim_name = ""
	_show_idle()


func has_anim(a: String) -> bool:
	return _sprite != null and _sprite.sprite_frames.has_animation(a)


func _physics_process(delta: float) -> void:
	if _sprite == null:
		return
	var dir := Input.get_vector("left", "right", "up", "down")

	if Input.is_action_just_pressed("a") and not _busy:
		_busy = true
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
		else:
			return

	if dir == Vector2.ZERO:
		_sprite.position.y = 0
		_show_idle()
		return

	var running := Input.is_action_pressed("b")
	var speed := RUN_SPEED if running else WALK_SPEED
	position = (position + dir * speed * delta).clamp(bounds.position, bounds.end)

	if absf(dir.x) >= absf(dir.y) * 0.9:
		facing = "left" if dir.x < 0 else "right"
		_sprite.position.y = 0
		_apply("run" if running else "walk", dir.x < 0)
	else:
		# No walk-toward/away art yet: front/back view with a small bob.
		facing = "up" if dir.y < 0 else "down"
		_apply("view_back" if dir.y < 0 else "view_front", false)
		_bob += delta * (16.0 if running else 10.0)
		_sprite.position.y = -absf(sin(_bob)) * 2.0


func _show_idle() -> void:
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
	_sprite.flip_h = flip
	if restart or anim_name != a:
		anim_name = a
		_sprite.play(a)


func _on_animation_finished() -> void:
	if anim_name == "attack":
		_busy = false
