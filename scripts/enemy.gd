class_name Enemy
extends Node2D
## A Grump (or bigger): wanders, chases when you're close, hurts on touch.
## Drawn procedurally until real art arrives.

var hp := 3
var max_hp := 3
var speed := 34.0
var damage := 1
var reward := 3
var kind := "grump"   # grump, big_grump, slime, bat
var map: GameMap
var _t := 0.0
var _dir := Vector2.ZERO
var _hit_flash := 0.0
var _anim_t := 0.0
var _knock := Vector2.ZERO
var _alive := true


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
	max_hp = hp


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
	queue_redraw()


func hit(n: int, from: Vector2) -> bool:
	if not _alive:
		return false
	hp -= n
	_hit_flash = 0.15
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
	var s := 1.0 if kind != "big_grump" else 1.9
	var col := Color("6a6a7a") if _hit_flash <= 0.0 else Color(1, 1, 1)
	match kind:
		"slime":
			col = Color("5ac86a") if _hit_flash <= 0.0 else Color(1, 1, 1)
		"bat":
			col = Color("3a2a4a") if _hit_flash <= 0.0 else Color(1, 1, 1)
	var bob := sin(_anim_t * 6.0) * 1.5
	draw_circle(Vector2(0, 0), 5.0 * s, Color(0, 0, 0, 0.2))
	if kind == "bat":
		var flap := sin(_anim_t * 14.0) * 3.0
		draw_rect(Rect2(-3, -14 + bob, 6, 5), col)
		draw_line(Vector2(-3, -12 + bob), Vector2(-9, -14 + bob - flap), col, 2.0)
		draw_line(Vector2(3, -12 + bob), Vector2(9, -14 + bob - flap), col, 2.0)
		draw_rect(Rect2(-2, -13 + bob, 1, 1), Color(1, 0.3, 0.3))
		draw_rect(Rect2(1, -13 + bob, 1, 1), Color(1, 0.3, 0.3))
		return
	if kind == "slime":
		var sq := 1.0 + sin(_anim_t * 5.0) * 0.1
		draw_circle(Vector2(0, -5), 6.0 * sq, col)
		draw_rect(Rect2(-3, -7, 1.5, 1.5), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(1.5, -7, 1.5, 1.5), Color(0, 0, 0, 0.7))
		return
	# Grump: a stormy little cloud with angry eyebrows and stubby legs.
	draw_circle(Vector2(-4 * s, -8 * s + bob), 5 * s, col)
	draw_circle(Vector2(3 * s, -9 * s + bob), 6 * s, col)
	draw_circle(Vector2(0, -5 * s + bob), 5.5 * s, col)
	draw_rect(Rect2(-4 * s, -2 * s + bob, 2 * s, 3 * s), col.darkened(0.3))
	draw_rect(Rect2(2 * s, -2 * s + bob, 2 * s, 3 * s), col.darkened(0.3))
	draw_rect(Rect2(-3 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))
	draw_rect(Rect2(1.5 * s, -9 * s + bob, 2 * s, 2 * s), Color(1, 0.9, 0.3))
	draw_line(Vector2(-4 * s, -11 * s + bob), Vector2(-1 * s, -10 * s + bob), Color(0.1, 0.1, 0.15), 1.5)
	draw_line(Vector2(4 * s, -11 * s + bob), Vector2(1 * s, -10 * s + bob), Color(0.1, 0.1, 0.15), 1.5)
	if max_hp > 3:
		draw_rect(Rect2(-10, -24, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, -24, 20.0 * hp / max_hp, 3), Color(0.9, 0.2, 0.2))
