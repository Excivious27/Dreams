class_name Bot
extends Node2D
## A deployed robot (Robotics Bench, gangster arc): sits where you put it and
## zaps the nearest hostile until its battery runs out. Not a target itself.
var map: GameMap
var life := 30.0
var dmg := 2
var reach := 70.0
var rate := 1.0
var _cd := 0.5
var _zap_to := Vector2.INF
var _zap_t := 0.0
var _spr: Sprite2D
var item := "scrap_bot"


static func deploy(m: GameMap, id: String, it: Dictionary, quiet := false) -> Bot:
	var b := Bot.new()
	b.map = m
	b.item = id
	b.life = float(it.get("life", 30))
	b.dmg = int(it.get("dmg", 2)) + GameState.progress_tier()
	b.reach = float(it.get("reach", 70.0))
	b.rate = float(it.get("rate", 1.0))
	b.position = m.player.position + m.player.facing_dir() * 14.0
	b.z_index = 1
	if Art.has("props", "bot_" + id):
		b._spr = Sprite2D.new()
		b._spr.texture = Art.tex("props", "bot_" + id)
		b._spr.scale = Vector2(0.5, 0.5)
		b._spr.offset = Vector2(0, -b._spr.texture.get_height() / 2.0)
		b.add_child(b._spr)
	m.add_child(b)
	if not quiet:
		Music.instance(m.get_tree()).sfx("zap", "pickup")  # the player drops a bot: hear it boot
	return b


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	life -= delta
	_zap_t = maxf(0.0, _zap_t - delta)
	_cd -= delta
	if life <= 0.0:
		map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
		queue_free()
		return
	if _cd <= 0.0:
		var e := map.nearest_enemy_to(position, reach)
		if e and e._alive and map.line_clear(position, e.position):
			_cd = rate
			_zap_to = e.position + Vector2(0, -8)
			_zap_t = 0.12
			e.provoke(self)
			e.hit(dmg, position, true, true)
			if Art.has("fx", "cy_bot_zap"):
				map.fx("cy_bot_zap", e.position + Vector2(0, -8), 16.0, 0.35)
			Music.instance(get_tree()).sfx("zap", "hit")
	queue_redraw()


func _draw() -> void:
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.2))
	if _spr == null:
		# Stand-in: a squat chrome box with one cyan eye and an aerial.
		draw_rect(Rect2(-5, -10, 10, 9), Color(0.55, 0.6, 0.68))
		draw_rect(Rect2(-5, -10, 10, 9), Color(0.12, 0.14, 0.2), false, 1.0)
		draw_rect(Rect2(-6, -2, 4, 2), Color(0.2, 0.22, 0.3))
		draw_rect(Rect2(2, -2, 4, 2), Color(0.2, 0.22, 0.3))
		draw_line(Vector2(3, -10), Vector2(4, -15), Color(0.12, 0.14, 0.2), 1.0)
		draw_circle(Vector2(0, -6), 2.0, Color(0.2, 1.0, 0.95, 0.6 + 0.4 * blink))
		if item == "drone_swarm":
			for k in 5:
				var a := Time.get_ticks_msec() / 300.0 + TAU * k / 5.0
				draw_circle(Vector2(cos(a) * 14.0, -16 + sin(a) * 6.0), 1.6, Color(0.2, 1.0, 0.95))
	# Battery bar when nearly out.
	if life < 8.0:
		draw_rect(Rect2(-5, -18, 10.0 * life / 8.0, 1.5), Color(1, 0.4, 0.3))
	if _zap_t > 0.0 and _zap_to != Vector2.INF:
		var to := _zap_to - position
		var mid := to * 0.5 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		draw_polyline([Vector2(0, -6), mid, to], Color(0.4, 1.0, 1.0), 1.5)
		draw_polyline([Vector2(0, -6), mid, to], Color(1, 1, 1, 0.8), 0.6)
