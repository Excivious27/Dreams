extends Bot
## A point's Gun Turret (gangsters) / Crystal Pylon (penguins) on a battlefield:
## a Bot that stands in the "allies" group, so it holds its point's ring and
## foes come to break it (it has health). The penguin arc draws the crystal
## pylon (props/crystal_pylon, or the battle kit's pylon) instead of the robot.

var hp := 40
var max_hp := 40
var _hurt := 0.0
var _frames: Array = []   # penguin pylon: props/crystal_pylon_0..3 (0-1 glow, 2-3 zap beam to the right)
var _ft := 0.0


static func make_at(m: GameMap, at: Vector2, it: Dictionary) -> Bot:
	var b = load("res://scripts/battle_turret.gd").new()
	b.map = m
	b.item = "guard_bot"
	b.life = 45.0
	b.dmg = int(it.get("dmg", 4)) + GameState.progress_tier()
	b.reach = float(it.get("reach", 90.0))
	b.rate = float(it.get("rate", 1.0))
	b.max_hp = 40 + 8 * GameState.progress_tier()
	b.hp = b.max_hp
	b.position = HelperUnit.free_spot(m, at)
	b.z_index = 1
	var tex: Texture2D = null
	if GameState.is_penguins() and Art.has("props", "crystal_pylon_0"):
		for k in 4:
			if Art.has("props", "crystal_pylon_%d" % k):
				b._frames.append(Art.tex("props", "crystal_pylon_%d" % k))
		tex = b._frames[0]
	elif GameState.is_penguins():
		tex = Art.tex("props", "crystal_pylon") if Art.has("props", "crystal_pylon") else Art.tex("battle", "pylon")
	elif Art.has("props", "bot_guard_bot"):
		tex = Art.tex("props", "bot_guard_bot")
	if tex:
		b._spr = Sprite2D.new()
		b._spr.texture = tex
		var hgt := 20.0 if GameState.is_penguins() else tex.get_height() * 0.5
		var sc := hgt / float(tex.get_height())
		b._spr.scale = Vector2(sc, sc)
		b._spr.offset = Vector2(0, -tex.get_height() / 2.0)
		if not b._frames.is_empty():
			# Frames are wide (the beam runs right); the body is the left ~half: centre it.
			b._spr.offset.x = tex.get_width() / 2.0 - tex.get_height() * 0.32
		b.add_child(b._spr)
	b.add_to_group("allies")
	m.add_child(b)
	if m.player and m.player.position.distance_to(b.position) < 220.0:
		Music.instance(m.get_tree()).sfx("power_up", "pop")
	return b


## Gangster Gun Turret fires a gun; the penguin pylon hums a crystal bolt (c6_11).
func _fire_sfx() -> void:
	if map.player and map.player.position.distance_to(position) > 220.0:
		return
	if GameState.is_penguins():
		Music.instance(get_tree()).sfx("laser", "zap")
	else:
		Music.instance(get_tree()).sfx("shot_smg", "shot")


var _hit_ms := -10000


func take_damage(n: int, _from: Vector2) -> void:
	hp -= maxi(1, n / 2)
	_hurt = 0.2
	if _spr:
		_spr.modulate = Color(1.8, 1.8, 1.8)
	var near := map.player != null and map.player.position.distance_to(position) < 220.0
	if hp > 0 and near and Time.get_ticks_msec() - _hit_ms > 400:
		_hit_ms = Time.get_ticks_msec()
		Music.instance(get_tree()).sfx("glass" if GameState.is_penguins() else "hit", "thud")
	if hp <= 0:
		map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
		if near:
			Music.instance(get_tree()).sfx("glass" if GameState.is_penguins() else "power_off", "pop")
		queue_free()


func provoke(_by: Node2D) -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	if not _frames.is_empty() and _spr and is_instance_valid(_spr):
		_ft += delta
		var zap := _zap_t > 0.0 and _frames.size() >= 4
		var i := (2 + int(_ft * 12.0) % 2) if zap else int(_ft * 3.0) % mini(2, _frames.size())
		_spr.texture = _frames[i]
		var left := zap and _zap_to != Vector2.INF and _zap_to.x < position.x
		_spr.flip_h = left
		_spr.offset.x = absf(_spr.offset.x) * (-1.0 if left else 1.0)
	if _hurt > 0.0:
		_hurt -= delta
		if _hurt <= 0.0 and _spr:
			_spr.modulate = Color.WHITE


func _draw() -> void:
	super()
	if hp < max_hp:
		draw_rect(Rect2(-7, -24, 14, 1.5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-7, -24, 14.0 * hp / max_hp, 1.5), Color(0.4, 1, 0.5))
