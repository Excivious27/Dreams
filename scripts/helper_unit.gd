class_name HelperUnit
extends Node2D
## A battlefield helper made at a spawner you built on a control point:
## crystals in the penguin arc, drones in the gangster arc. Not strong alone;
## each kind does one job well.
##   striker  zaps the nearest foe           healer  mends you and other helpers
##   warden   shields you (less damage)      shade   veils you: foes lose track
## Helpers hold their point, or follow you when the point is safe.

const KINDS := {
	"striker": {"crystal": "Spark Crystal", "drone": "Striker Drone", "hp": 24, "colour": "ff8a5a"},
	"healer": {"crystal": "Mend Crystal", "drone": "Medic Drone", "hp": 20, "colour": "7af0a0"},
	"warden": {"crystal": "Ward Crystal", "drone": "Shield Drone", "hp": 34, "colour": "8ab8ff"},
	"shade": {"crystal": "Veil Crystal", "drone": "Ghost Drone", "hp": 16, "colour": "c49aff"},
}

var map: GameMap
var kind := "striker"
var style := "crystal"     # or "drone"
var hp := 20
var max_hp := 20
var home := Vector2.ZERO   # the point it guards
var _cd := 0.6
var _bob := 0.0
var _zap_to := Vector2.INF
var _zap_t := 0.0
var _hurt := 0.0


static func make(m: GameMap, k: String, at: Vector2, home_at: Vector2) -> HelperUnit:
	var h := HelperUnit.new()
	h.map = m
	h.kind = k
	h.style = "crystal" if GameState.is_penguins() else "drone"
	h.max_hp = int(KINDS[k]["hp"]) + 4 * GameState.progress_tier() + int(GameState.bonus(GameState.arc_skill(), "helper_hp")) + int(GameState.bonus("leadership", "helper_hp"))
	h.hp = h.max_hp
	h.position = at
	h.home = home_at
	h.z_index = 1
	h.add_to_group("allies")
	m.add_child(h)
	return h


func label() -> String:
	return str(KINDS[kind][style])


func take_damage(n: int, _from: Vector2) -> void:
	hp -= maxi(1, n / 3)
	_hurt = 0.2
	if hp <= 0:
		map.fx("poof", position + Vector2(0, -6), 12.0, 0.4)
		queue_free()


func provoke(_by: Node2D) -> void:
	pass


func _process(delta: float) -> void:
	if get_tree().paused or map == null or map.player == null:
		return
	_bob += delta
	_cd -= delta
	_zap_t = maxf(0.0, _zap_t - delta)
	_hurt = maxf(0.0, _hurt - delta)
	# Move: guard home; drift toward the player when no foe is near home.
	var foe := map.nearest_enemy_to(position, 120.0)
	var want := home
	if foe == null and map.player.position.distance_to(home) < 200.0:
		want = map.player.position + Vector2(cos(get_instance_id() % 7), sin(get_instance_id() % 5)) * 22.0
	if map.has_meta("rally_pos"):
		var rp: Vector2 = map.get_meta("rally_pos")
		want = rp + Vector2(cos(get_instance_id() % 11), sin(get_instance_id() % 13)) * 20.0
		if foe and foe.position.distance_to(position) > 70.0:
			foe = map.nearest_enemy_to(position, 70.0)
	if foe and kind == "striker":
		want = foe.position + (position - foe.position).normalized() * 40.0
	var step := (want - position)
	if step.length() > 4.0:
		var np := position + step.normalized() * minf(step.length(), 52.0 * delta)
		if not map.blocked.has(map.world_to_cell(np)):
			position = np
	if _cd > 0.0:
		queue_redraw()
		return
	match kind:
		"striker":
			if foe and foe._alive and foe.position.distance_to(position) < 90.0 and map.line_clear(position, foe.position):
				_cd = 1.1
				_zap_to = foe.position + Vector2(0, -8)
				_zap_t = 0.12
				foe.provoke(map.player)
				foe.hit(2 + GameState.progress_tier(), position, true)
		"healer":
			_cd = 3.0
			if map.player.position.distance_to(position) < 70.0 and int(GameState.run["hp"]) < int(GameState.run["max_hp"]):
				GameState.run["hp"] = mini(int(GameState.run["max_hp"]), int(GameState.run["hp"]) + 4 + GameState.progress_tier())
				map.fx("sparkle", map.player.position + Vector2(0, -12), 10.0, 0.4)
			for o in get_tree().get_nodes_in_group("allies"):
				if o is HelperUnit and o != self and o.position.distance_to(position) < 70.0:
					o.hp = mini(o.max_hp, o.hp + 4)
		"warden":
			_cd = 2.0
			if map.player.position.distance_to(position) < 70.0:
				GameState.run["buffs"] = GameState.run.get("buffs", {})
				GameState.run["buffs"]["defense"] = {"until": GameState.now_abs() + 3, "amount": 2.0}
		"shade":
			_cd = 6.0
			if foe and map.player.position.distance_to(position) < 80.0:
				map.set_meta("stealth_until", Time.get_ticks_msec() + 2500)
				map.fx("poof", map.player.position + Vector2(0, -8), 12.0, 0.4)
	queue_redraw()


func _draw() -> void:
	var c := Color(str(KINDS[kind]["colour"]))
	var y := -10.0 + sin(_bob * 3.0) * 2.0
	draw_circle(Vector2(0, 0), 4.0, Color(0, 0, 0, 0.2))
	if _hurt > 0.0:
		c = Color.WHITE
	if style == "crystal":
		var pts := PackedVector2Array([Vector2(0, y - 8), Vector2(5, y), Vector2(0, y + 6), Vector2(-5, y)])
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.8), 1.0)
		draw_circle(Vector2(0, y - 1), 1.5, Color(1, 1, 1, 0.9))
	else:
		draw_rect(Rect2(-5, y - 3, 10, 6), Color(0.3, 0.32, 0.38))
		draw_rect(Rect2(-5, y - 3, 10, 6), Color(0.1, 0.1, 0.14), false, 1.0)
		for sx in [-7.0, 7.0]:
			draw_line(Vector2(sx - 3, y - 5), Vector2(sx + 3, y - 5), Color(0.8, 0.85, 0.9, 0.7), 1.0)
		draw_circle(Vector2(0, y), 1.6, c)
	if hp < max_hp:
		draw_rect(Rect2(-6, y - 13, 12, 1.5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-6, y - 13, 12.0 * hp / max_hp, 1.5), Color(0.4, 1, 0.5))
	if _zap_t > 0.0 and _zap_to != Vector2.INF:
		var to := _zap_to - position
		draw_line(Vector2(0, y), to, Color(1, 1, 1, 0.9), 1.5)
		draw_line(Vector2(0, y), to, c, 0.8)
