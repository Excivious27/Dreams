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
var _attacking := 0.0
var _sprite: AnimatedSprite2D
var _shadow_r := 5.0
var _stun := 0.0        # staggered after a hit: no AI, no attacks
var _windup := 0.0      # attack telegraph in progress
var _cooldown := 0.0    # time until it can attack again
var _flash_mat: ShaderMaterial
var _flash := 0.0
var reach := 16.0
var _squash := 0.0


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
		"soldier":
			hp = 5; speed = 36.0; damage = 1; reward = 6
		"archer":
			hp = 4; speed = 30.0; damage = 1; reward = 7
		"knight":
			hp = 12; speed = 28.0; damage = 2; reward = 25
		"wisp":
			hp = 3; speed = 44.0; damage = 1; reward = 5
		"commander":
			hp = 40; speed = 24.0; damage = 3; reward = 150
		"dark_crystal":
			hp = 80; speed = 20.0; damage = 3; reward = 500
		# Gangster arc (sprites live in characters/, not enemies/)
		"thug_cyber":
			hp = 10; speed = 34.0; damage = 2; reward = 20
		"thug_brute":
			hp = 18; speed = 22.0; damage = 3; reward = 35
		"thug_flame":
			hp = 12; speed = 30.0; damage = 2; reward = 30
		"thug_speedster":
			hp = 8; speed = 60.0; damage = 1; reward = 25
		"thug_gambler":
			hp = 10; speed = 32.0; damage = 2; reward = 30
		"thug_enforcer":
			hp = 24; speed = 20.0; damage = 3; reward = 45
		"president":
			hp = 120; speed = 26.0; damage = 4; reward = 1000
	max_hp = hp
	var art_kind := "grump" if k == "big_grump" else k
	var group := "enemies/" + art_kind
	if k.begins_with("thug_"):
		group = "characters/" + k.trim_prefix("thug_")
	elif k == "president":
		group = "characters/president"
	if Art.has(group, "idle"):
		_sprite = AnimatedSprite2D.new()
		var anims := {"idle": "idle", "hurt": "hurt"}
		anims["walk"] = "walk" if Art.has(group, "walk") else "idle"
		if Art.has(group, "attack"):
			anims["attack"] = "attack"
		_sprite.sprite_frames = Art.frames(group, anims, {"idle": 5.0, "walk": 8.0, "hurt": 8.0, "attack": 10.0}, {"attack": false, "hurt": false})
		_sprite.animation = "idle"
		var s := 0.5 if k != "big_grump" else 1.1
		_sprite.scale = Vector2(s, s)
		_sprite.frame_changed.connect(func() -> void:
			var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
			if tex:
				_sprite.offset = Vector2(0, -tex.get_height() / 2.0))
		_sprite.play("idle")
		add_child(_sprite)
		_shadow_r = 6.0 * s * 2.0
		var sh := load("res://shaders/flash.gdshader")
		if sh:
			_flash_mat = ShaderMaterial.new()
			_flash_mat.shader = sh
			_sprite.material = _flash_mat
	reach = 22.0 if hp >= 16 else 16.0


func _process(delta: float) -> void:
	if not _alive:
		return
	if map.hitstop > 0.0:
		return
	_anim_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_stun = maxf(0.0, _stun - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_squash = maxf(0.0, _squash - delta * 5.0)
	if _flash_mat:
		_flash_mat.set_shader_parameter("flash", _flash)
	var player := map.player
	var to := player.position - position
	var dist := to.length()
	_t -= delta
	var stunned := _stun > 0.0
	if not stunned and _windup <= 0.0:
		if dist < 80.0 and dist > reach * 0.6:
			_dir = to.normalized()
		elif dist <= reach * 0.6:
			_dir = Vector2.ZERO
		elif _t <= 0.0:
			_t = randf_range(1.0, 3.0)
			_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() if randf() < 0.7 else Vector2.ZERO
	# Keep a little distance from other enemies so they don't stack.
	var sep := Vector2.ZERO
	for o in map.enemies:
		if o != self and is_instance_valid(o):
			var d: Vector2 = position - o.position
			if d.length() < 12.0 and d.length() > 0.01:
				sep += d.normalized() * (12.0 - d.length())
	var move := (Vector2.ZERO if stunned or _windup > 0.0 else _dir * speed) + _knock + sep * 4.0
	_knock = _knock.move_toward(Vector2.ZERO, 520.0 * delta)
	_slide(move * delta)
	# Attacks telegraph: wind up, then strike if you're still in reach.
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if dist < reach + 4.0 and player.invuln <= 0.0:
				player.take_damage(damage, position)
			_cooldown = 1.1
	elif not stunned and dist < reach and _cooldown <= 0.0:
		_windup = 0.32
		if _sprite and _sprite.sprite_frames.has_animation("attack"):
			_sprite.play("attack")
		_attacking = 0.45
	_attacking = maxf(0.0, _attacking - delta)
	if _sprite:
		var want := "hurt" if _hit_flash > 0.0 else ("attack" if _attacking > 0.0 else ("walk" if _dir != Vector2.ZERO and not stunned else "idle"))
		if _sprite.animation != want and (want != "hurt" or _sprite.sprite_frames.has_animation("hurt")):
			_sprite.play(want)
		if _dir.x != 0.0:
			_sprite.flip_h = _dir.x < 0
		elif to.x != 0.0 and dist < 80.0:
			_sprite.flip_h = to.x < 0
		var tint := Color(1, 1, 1)
		if _windup > 0.0:
			tint = Color(1.0, 0.75, 0.7)
		_sprite.modulate = tint
		_sprite.scale = Vector2(0.5 * (1.0 + _squash * 0.25), 0.5 * (1.0 - _squash * 0.3)) if kind != "big_grump" else Vector2(1.1, 1.1)
	queue_redraw()


## Move with wall sliding (x then y) so knockback never cancels outright.
func _slide(step: Vector2) -> void:
	var feet := Rect2(Vector2(-4, -3), Vector2(8, 3))
	var nx := position + Vector2(step.x, 0)
	if not map.rect_blocked(Rect2(nx + feet.position, feet.size)):
		position = nx
	else:
		_knock.x = 0
		if _dir.x != 0.0 and _stun <= 0.0:
			_dir.x = -_dir.x
	var ny := position + Vector2(0, step.y)
	if not map.rect_blocked(Rect2(ny + feet.position, feet.size)):
		position = ny
	else:
		_knock.y = 0
		if _dir.y != 0.0 and _stun <= 0.0:
			_dir.y = -_dir.y


func hit(n: int, from: Vector2) -> bool:
	if not _alive:
		return false
	hp -= n
	_hit_flash = 0.22
	_flash = 1.0
	_squash = 1.0
	_stun = 0.32 if max_hp < 30 else 0.15
	_windup = 0.0
	var heavy := 1.0 if max_hp < 16 else (0.55 if max_hp < 40 else 0.3)
	_knock = (position - from).normalized() * 230.0 * heavy
	if hp <= 0:
		_die()
	return true


func _die() -> void:
	_alive = false
	map.enemies.erase(self)
	map.on_enemy_died(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + _knock.normalized() * 10.0, 0.2)
	tw.tween_property(self, "scale", Vector2(1.4, 0.1), 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2(0, 0), _shadow_r, Color(0, 0, 0, 0.2))
	if max_hp > 3:
		var top := -30.0 if max_hp < 30 else -60.0
		draw_rect(Rect2(-10, top, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, top, 20.0 * hp / max_hp, 3), Color(0.9, 0.2, 0.2))
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
