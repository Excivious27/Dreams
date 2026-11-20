extends Bot
## A point's Gun Turret (gangsters) / Crystal Pylon (penguins) on a battlefield:
## a Bot that stands in the "allies" group, so it holds its point's ring and
## foes come to break it (it has health). The penguin arc draws the crystal
## pylon (props/crystal_pylon, or the battle kit's pylon) instead of the robot.

var hp := 40
var max_hp := 40
var _hurt := 0.0


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
	if GameState.is_penguins():
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
		b.add_child(b._spr)
	b.add_to_group("allies")
	m.add_child(b)
	Music.instance(m.get_tree()).sfx("power_up", "pop")
	return b


func take_damage(n: int, _from: Vector2) -> void:
	hp -= maxi(1, n / 2)
	_hurt = 0.2
	if _spr:
		_spr.modulate = Color(1.8, 1.8, 1.8)
	if hp <= 0:
		map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
		Music.instance(get_tree()).sfx("glass" if GameState.is_penguins() else "power_off", "pop")
		queue_free()


func provoke(_by: Node2D) -> void:
	pass


func _process(delta: float) -> void:
	super(delta)
	if _hurt > 0.0:
		_hurt -= delta
		if _hurt <= 0.0 and _spr:
			_spr.modulate = Color.WHITE


func _draw() -> void:
	super()
	if hp < max_hp:
		draw_rect(Rect2(-7, -24, 14, 1.5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-7, -24, 14.0 * hp / max_hp, 1.5), Color(0.4, 1, 0.5))
