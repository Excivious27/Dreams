class_name Enemy
extends Node2D
## A Grump (or bigger), slime, bat, golem or corrupted shard: wanders, chases when
## you're close, hurts on touch. Uses Tom's sprites from art/gen/enemies when
## present, otherwise a procedural drawing.

var hp := 3
var max_hp := 3
var speed := 34.0
var damage := 1
var reward := 3
var kind := "grump"   # grump, big_grump, slime, bat, golem, shard
var map: GameMap
var _t := 0.0
var _dir := Vector2.ZERO
var _hit_flash := 0.0
var _anim_t := 0.0
var _knock := Vector2.ZERO
var _alive := true
var _sprite: AnimatedSprite2D
var _shadow_r := 5.0


func setup(k: String) -> void:
	kind = k
	match k:
		"grump":
			hp = 3; speed = 34.0; damage = 1; reward = 3
		"big_grump":
			hp = 16; speed = 26.0; damage = 2; reward = 40
		"slime":
			hp = 2; speed = 22.0; damage = 1; reward = 2
		"bat":
			hp = 2; speed = 48.0; damage = 1; reward = 3
		"golem":
			hp = 8; speed = 18.0; damage = 2; reward = 12
		"shard":
			hp = 4; speed = 30.0; damage = 1; reward = 8
	max_hp = hp
	var art_kind := "grump" if k == "big_grump" else k
	if Art.has("enemies/" + art_kind, "idle"):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = Art.frames("enemies/" + art_kind, {"idle": "idle", "walk": "walk", "hurt": "hurt"}, {"idle": 5.0, "walk": 8.0, "hurt": 8.0})
		var s := 0.5 if k != "big_grump" else 1.1
		_sprite.scale = Vector2(s, s)
		_sprite.frame_changed.connect(func() -> void:
			var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
			if tex:
				_sprite.offset = Vector2(0, -tex.get_height() / 2.0))
		_sprite.play("idle")
		add_child(_sprite)
		_shadow_r = 6.0 * s * 2.0


func _process(delta: float) -> void:
	if not _alive:
		return
	_anim_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var player := map.player
	var to := player.position - position
	var dist := to.length()
	_t -= delta
	if dist < 70.0 and dist > 6.0:
		_dir = to.normalized()
	elif _t <= 0.0:
		_t = randf_range(1.0, 3.0)
		_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() if randf() < 0.7 else Vector2.ZERO
	var step := (_dir * speed + _knock) * delta
	_knock = _knock.move_toward(Vector2.ZERO, 400.0 * delta)
	var np := position + step
	if not map.rect_blocked(Rect2(np + Vector2(-4, -3), Vector2(8, 3))):
		position = np
	else:
		_dir = -_dir
	if dist < 9.0 and player.invuln <= 0.0:
		player.take_damage(damage, position)
	if _sprite:
		var want := "hurt" if _hit_flash > 0.0 else ("walk" if _dir != Vector2.ZERO else "idle")
		if _sprite.animation != want:
			_sprite.play(want)
		_sprite.flip_h = _dir.x < 0
		_sprite.modulate = Color(1, 1, 1) if _hit_flash <= 0.0 else Color(2, 1.6, 1.6)
	queue_redraw()


func hit(n: int, from: Vector2) -> bool:
	if not _alive:
		return false
	hp -= n
	_hit_flash = 0.2
	_knock = (position - from).normalized() * 140.0
	if hp <= 0:
		_die()
	return true


func _die() -> void:
	_alive = false
	map.enemies.erase(self)
	map.on_enemy_died(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.1), 0.2)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2(0, 0), _shadow_r, Color(0, 0, 0, 0.2))
	if max_hp > 3:
		draw_rect(Rect2(-10, -30, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, -30, 20.0 * hp / max_hp, 3), Color(0.9, 0.2, 0.2))
	if _sprite:
		return
	# Procedural fallback: a stormy little cloud.
	var s := 1.0 if kind != "big_grump" else 1.9
	var col := Color("6a6a7a") if _hit_flash <= 0.0 else Color(1, 1, 1)
	var bob := sin(_anim_t * 6.0) * 1.5
	draw_circle(Vector2(-4 * s, -8 * s + bob), 5 * s, col)
	draw_circle(Vector2(3 * s, -9 * s + bob), 6 * s, col)
	draw_circle(Vector2(0, -5 * s + bob), 5.5 * s, col)
	draw_rect(Rect2(-3 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))
	draw_rect(Rect2(1.5 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))
