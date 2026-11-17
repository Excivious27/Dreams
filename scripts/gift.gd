class_name Gift
extends Node2D
## A Gift: the strange power a Marked gangster or a boss fights with.
##
## Data in data/gifts.json. A gift is a loop of MOVES (patterns you read and
## dodge) plus one RULE (how you actually hurt them). Nobody with a Gift goes
## down to plain button-mashing: closed, they shrug off or dodge most of what
## you do; you win by reading the move that leaves them OPEN.
##   moves: ring · spiral · lines · zones · dash · pull · gust · veil · clones · roll
##   rules: window (open after a named move) · wet (near water / in rain) ·
##          back (only from behind) · cycle (iron, then tired) · real (find the
##          one with a shadow) · offbeat (the white flash) · range (keep away)
## The engine draws every telegraph itself (rings, lanes, circles), so each
## gift reads clearly even before its own art arrives.

static var _data: Dictionary = {}

var e: Enemy
var gid := ""
var d: Dictionary = {}
var col := Color(0.8, 0.5, 1.0)
var open_t := 0.0        # seconds left of the vulnerable window
var _closed_t := 0.0     # for cycle / offbeat clocks
var _next := 2.0
var _i := 0
var _bul: Array = []     # {p, v, r, life}
var _lines: Array = []   # {a, b, t, w, fired}
var _zones: Array = []   # {p, r, t, linger, fx}
var _busy := 0.0
var _pull := 0.0
var _gust := 0.0
var _veil := 0.0
var _rolls := 0
var _clone_marks := {}
var _told := false
var _dash_to := Vector2.INF
var _dash_t := 0.0
var _spiral := 0.0
var _spiral_a := 0.0
var decoy := false
var face := 1.0          # which way a 'back' gift is turned (lags behind you)
var _turn_t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/gifts.json")
	return _data


static func def(id: String) -> Dictionary:
	return data().get("gifts", {}).get(id, {})


func setup(enemy: Enemy, id: String) -> void:
	e = enemy
	gid = id
	d = def(id)
	col = Color(str(d.get("colour", "c080ff")))
	z_index = 2
	_next = 1.6


func rule() -> String:
	return str(d.get("rule", {}).get("type", "window"))


# ---- how much of a hit lands -----------------------------------------------------

## Multiplier for a hit from `from` (0 = nothing lands).
func vuln(from: Vector2, magic: bool) -> float:
	if decoy:
		return 1.0
	var r: Dictionary = d.get("rule", {})
	var closed := float(r.get("closed", 0.0))
	var opened := float(r.get("open", 2.0))
	match rule():
		"wet":
			return opened if _wet() else closed
		"back":
			var behind := (from.x - e.position.x) * face < -2.0
			return opened if (behind or open_t > 0.0) else closed
		"range":
			var far := from.distance_to(e.position) > 46.0 or magic
			return opened if (far or open_t > 0.0) else closed
		"real":
			return opened
		_:
			return opened if open_t > 0.0 else closed


func _wet() -> bool:
	if GameState.is_wet():
		return true
	var c := e.map.world_to_cell(e.position)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if e.map.is_water_cell(c + Vector2i(dx, dy)):
				return true
	return false


## A hit bounced: say why, the first time.
func on_blocked() -> void:
	e.map.damage_number(e.position + Vector2(0, -24), 0)
	_say("GUARD", Color(0.75, 0.85, 1.0))
	if not _told:
		_told = true
		e.map.hud.toast(str(d.get("tip", "Read their moves. Wait for the opening.")), Color(1, 0.9, 0.6))
	# Some answer a blocked hit.
	if rule() == "offbeat":
		_ring(8, 70.0, 2.5)
	elif rule() == "window" and bool(d.get("rule", {}).get("slip", false)):
		_slip()


func on_hit(mult: float) -> void:
	if mult >= 1.5:
		_say("OPEN!", Color(1, 1, 0.6))
		var known: Dictionary = GameState.run.get("gifts_known", {})
		if not known.has(gid):
			known[gid] = true
			GameState.run["gifts_known"] = known
			GameState.add_hint("%s: %s" % [str(d.get("name", gid)), str(d.get("tip", ""))])


func _say(t: String, c: Color) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.position = e.position + Vector2(-12, -34)
	l.z_index = 6
	e.map.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 10, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _slip() -> void:
	# Blink a short way off, out of the swing.
	var at := e.map.free_spot_near(e.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 44.0)
	e.map.fx("blink" if Art.has("fx", "blink") else "poof", e.position + Vector2(0, -8), 14.0, 0.4)
	e.position = at


# ---- the loop --------------------------------------------------------------------

func _process(delta: float) -> void:
	if e == null or not is_instance_valid(e) or not e._alive or e.map == null:
		return
	if e.map.hitstop > 0.0 or get_tree().paused:
		return
	global_position = Vector2.ZERO + e.map.global_position  # draw in map space
	var p := e.map.player
	open_t = maxf(0.0, open_t - delta)
	_busy = maxf(0.0, _busy - delta)
	_tick_shots(delta, p)
	if decoy:
		queue_redraw()
		return
	# Clocks some rules run on.
	match rule():
		"back":
			# Turns to face you, but slowly: that lag is the whole fight.
			var want := 1.0 if p.position.x >= e.position.x else -1.0
			if want != face:
				_turn_t += delta
				if _turn_t >= float(d["rule"].get("turn", 1.5)):
					face = want
					_turn_t = 0.0
			else:
				_turn_t = 0.0
			if e._sprite:
				e._sprite.flip_h = face < 0.0
		"cycle":
			_closed_t += delta
			var on := float(d["rule"].get("on", 5.0))
			var off := float(d["rule"].get("off", 3.0))
			if fmod(_closed_t, on + off) > on:
				open_t = maxf(open_t, 0.1)
		"offbeat":
			_closed_t += delta
			var beat := float(d["rule"].get("beat", 1.6))
			if fmod(_closed_t, beat) < float(d["rule"].get("gap", 0.5)):
				open_t = maxf(open_t, 0.05)
	# Pull / gust act on you while they last.
	if _pull > 0.0:
		_pull -= delta
		_shove(p, (e.position - p.position).normalized() * float(d.get("pull_force", 42.0)) * delta)
		if _pull <= 0.0:
			_ring(14, 80.0, 3.0)
			e.map.shake(3.0)
			_open_after("pull")
	if _gust > 0.0:
		_gust -= delta
		_shove(p, (p.position - e.position).normalized() * 70.0 * delta)
		if _gust <= 0.0:
			_open_after("gust")
	if _veil > 0.0:
		_veil -= delta
		e.modulate.a = 0.07
		if _veil <= 0.0:
			# Step out behind you and strike.
			e.position = e.map.free_spot_near(p.position - p.facing_dir() * 18.0)
			e.modulate.a = 1.0
			e.map.fx("blink" if Art.has("fx", "blink") else "poof", e.position + Vector2(0, -8), 14.0, 0.4)
			_lines.append({"a": e.position, "b": e.position + (p.position - e.position).normalized() * 40.0, "t": 0.35, "w": 9.0, "fired": false})
			_open_after("veil")
	elif not decoy and e.modulate.a < 1.0:
		e.modulate.a = 1.0
	if _dash_t > 0.0:
		_dash_t -= delta
		if _dash_t <= 0.0 and _dash_to != Vector2.INF:
			var from := e.position
			e.position = e.map.free_spot_near(_dash_to)
			if _seg_dist(p.position, from, e.position) < 11.0:
				_hurt(p, e.damage + 1)
			if bool(d.get("trail", false)):
				for k in 4:
					_zones.append({"p": from.lerp(e.position, (k + 0.5) / 4.0), "r": 11.0, "t": 0.0, "linger": 2.6, "fx": "burn"})
			_dash_to = Vector2.INF
			_open_after("dash")
	if _spiral > 0.0:
		_spiral -= delta
		_spiral_a += delta * 5.5
		if int(_spiral * 14.0) != int((_spiral + delta) * 14.0):
			for k in 2:
				var a := _spiral_a + PI * k
				_bul.append({"p": e.position + Vector2(0, -6), "v": Vector2(cos(a), sin(a)) * 60.0, "r": 2.5, "life": 2.6})
		if _spiral <= 0.0:
			_open_after("spiral")
	# Next move.
	_next -= delta
	var moves: Array = d.get("moves", [])
	if _next <= 0.0 and _busy <= 0.0 and not moves.is_empty() and e._stun <= 0.0 and e.position.distance_to(p.position) < 150.0:
		var mv: Dictionary = moves[_i % moves.size()]
		_i += 1
		_next = float(mv.get("gap", d.get("gap", 3.2))) * (0.8 if float(e.hp) / e.max_hp < 0.4 else 1.0)
		_do(mv, p)
	_clones_check()
	queue_redraw()


func _open_after(move: String) -> void:
	var r: Dictionary = d.get("rule", {})
	if str(r.get("after", "")) in [move, "any"]:
		open_t = float(r.get("secs", 2.0))
		e._stun = maxf(e._stun, minf(open_t, float(r.get("stagger", 0.0))))


func _do(mv: Dictionary, p: Player) -> void:
	var t := str(mv.get("type", "ring"))
	if t == "roll":
		_rolls += 1
		var opts: Array = mv.get("of", ["ring", "zones", "lines"])
		t = str(opts[randi() % opts.size()])
		_say(["Lucky!", "Double or nothing!", "Come on, sevens..."][randi() % 3], col)
		if _rolls % int(d.get("rule", {}).get("rolls", 3)) == 0:
			open_t = float(d.get("rule", {}).get("secs", 4.0))
			_say("...snake eyes.", Color(1, 1, 0.6))
		if t == "heal":
			e.hp = mini(e.max_hp, e.hp + int(e.max_hp * 0.06))
			e.map.fx("sparkle", e.position + Vector2(0, -10), 12.0, 0.5)
			return
	match t:
		"ring":
			_ring(int(mv.get("n", 12)), float(mv.get("speed", 58.0)), 3.0, int(mv.get("gap_n", 3)))
			_busy = 0.3
			_open_after("ring")
		"spiral":
			_spiral = float(mv.get("secs", 1.6))
			_busy = _spiral
		"lines":
			var n := int(mv.get("n", 3))
			for k in n:
				var aim := (p.position + p.velocity * 0.25 * k - e.position).normalized()
				if bool(mv.get("fan", false)):
					aim = (p.position - e.position).normalized().rotated((k - (n - 1) / 2.0) * 0.38)
				_lines.append({"a": e.position + Vector2(0, -6), "b": e.position + aim * float(mv.get("len", 150.0)), "t": 0.55 + 0.32 * k, "w": float(mv.get("w", 6.0)), "fired": false, "last": k == n - 1})
			_busy = 0.55 + 0.32 * n
		"zones":
			var n := int(mv.get("n", 3))
			for k in n:
				var at := p.position + (Vector2.ZERO if k == 0 else Vector2(randf_range(-36, 36), randf_range(-36, 36)))
				_zones.append({"p": at, "r": float(mv.get("r", 15.0)), "t": 0.75 + 0.18 * k, "linger": float(mv.get("linger", 1.2)), "fx": str(mv.get("fx", "dmg"))})
			_busy = 0.9
			_open_after("zones")
		"dash":
			_dash_to = p.position + (p.position - e.position).normalized() * 26.0
			_dash_t = 0.42
			_lines.append({"a": e.position, "b": _dash_to, "t": 0.42, "w": 10.0, "fired": true, "warn": true})
			_busy = 0.6
		"pull":
			_pull = float(mv.get("secs", 1.5))
			_busy = _pull + 0.3
		"gust":
			_gust = float(mv.get("secs", 0.9))
			_busy = _gust
		"veil":
			_veil = float(mv.get("secs", 2.2))
			_busy = _veil + 0.5
			e.map.fx("poof", e.position + Vector2(0, -8), 12.0, 0.4)


func _ring(n: int, speed: float, r: float, gap_n := 0) -> void:
	var a0 := randf() * TAU
	for k in n:
		if gap_n > 0 and k < gap_n:
			continue  # the safe lane
		var a := a0 + TAU * k / float(n)
		_bul.append({"p": e.position + Vector2(0, -6), "v": Vector2(cos(a), sin(a)) * speed, "r": r, "life": 2.4})


func _clones_check() -> void:
	var cl: Dictionary = d.get("clones", {})
	if cl.is_empty():
		return
	for frac in cl.get("at", [0.7, 0.35]):
		if float(e.hp) / e.max_hp <= float(frac) and not _clone_marks.has(frac):
			_clone_marks[frac] = true
			e.map.fx("blink" if Art.has("fx", "blink") else "poof", e.position + Vector2(0, -8), 14.0, 0.5)
			var spots: Array = [e.position]
			for k in int(cl.get("n", 2)):
				var c: Enemy = e.map.spawn_enemy(e.kind, e.position + Vector2(40, 0).rotated(TAU * k / 3.0 + 1.0))
				if c == null:
					continue
				c.hp = 1
				c.max_hp = 1
				c.reward = 0
				c.damage = maxi(1, e.damage - 1)
				c._shadow_r = 0.0   # the tell: reflections cast no shadow
				c.set_meta("decoy", true)
				if c._gift:
					c._gift.decoy = true
				spots.append(c.position)
			# Shuffle who stands where so you can't just track the real one.
			e.position = spots[randi() % spots.size()]


# ---- shots, lanes, circles ---------------------------------------------------------

func _hurt(p: Player, n: int) -> void:
	if p.invuln <= 0.0:
		p.take_damage(GameState.enemy_damage(n), e.position)


func _shove(p: Player, step: Vector2) -> void:
	var np := p.position + step
	if not e.map.rect_blocked_player(Rect2(np + Player.FEET.position, Player.FEET.size), p):
		p.position = np


static func _seg_dist(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((pt - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	return pt.distance_to(a + ab * t)


func _tick_shots(delta: float, p: Player) -> void:
	var feet := p.position + Vector2(0, -6)
	for b: Dictionary in _bul.duplicate():
		b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			_bul.erase(b)
		elif (b["p"] as Vector2).distance_to(feet) < float(b["r"]) + 5.0:
			_hurt(p, e.damage)
			_bul.erase(b)
	for l: Dictionary in _lines.duplicate():
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) <= 0.0:
			if not bool(l["fired"]):
				l["fired"] = true
				l["t"] = 0.14  # the flash
				if _seg_dist(feet, l["a"], l["b"]) < float(l["w"]) + 3.0:
					_hurt(p, e.damage + 1)
				if bool(l.get("last", false)):
					_open_after("lines")
			else:
				_lines.erase(l)
	for z: Dictionary in _zones.duplicate():
		z["t"] = float(z["t"]) - delta
		if float(z["t"]) <= 0.0:
			z["linger"] = float(z["linger"]) - delta
			if (z["p"] as Vector2).distance_to(p.position) < float(z["r"]) and int(Time.get_ticks_msec() / 300) != int(z.get("tick", -1)):
				z["tick"] = int(Time.get_ticks_msec() / 300)
				match str(z["fx"]):
					"slow":
						GameState.status_apply("slow", e.tier)
					"burn":
						_hurt(p, 1)
						GameState.status_apply("burn", e.tier)
					_:
						_hurt(p, e.damage)
			if float(z["linger"]) <= 0.0:
				_zones.erase(z)


func _draw() -> void:
	if e == null or not is_instance_valid(e):
		return
	var off := e.map.offset() if e.map else Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)
	# Aura: gift colour while guarded, flashing white when open.
	if not decoy:
		var ac := Color(1, 1, 1, 0.55 + 0.4 * pulse) if open_t > 0.0 else Color(col.r, col.g, col.b, 0.5)
		draw_arc(e.position + Vector2(0, -8), 13.0 + (2.0 * pulse if open_t > 0.0 else 0.0), 0, TAU, 28, ac, 2.0 if open_t > 0.0 else 1.2, true)
		if rule() == "back":
			var mid := 0.0 if face > 0.0 else PI
			draw_arc(e.position + Vector2(0, -8), 16.0, mid - 1.2, mid + 1.2, 14, Color(col.r, col.g, col.b, 0.95), 2.5, true)
		if e.has_meta("marked"):
			var nm := str(Marked.all().get(str(e.get_meta("marked")), {}).get("epithet", ""))
			var f := ThemeDB.fallback_font
			var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
			draw_string_outline(f, e.position + Vector2(-w / 2.0, -40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0.05, 0.05, 0.1))
			draw_string(f, e.position + Vector2(-w / 2.0, -40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)
		if _pull > 0.0:
			for k in 3:
				draw_arc(e.position, 70.0 - fmod(Time.get_ticks_msec() / 14.0 + k * 22.0, 66.0), 0, TAU, 32, Color(col.r, col.g, col.b, 0.35), 1.0, true)
		if _gust > 0.0:
			for k in 3:
				draw_arc(e.position, 12.0 + fmod(Time.get_ticks_msec() / 10.0 + k * 20.0, 60.0), 0, TAU, 32, Color(1, 1, 1, 0.3), 1.0, true)
	for z: Dictionary in _zones:
		var zp: Vector2 = z["p"]
		if float(z["t"]) > 0.0:
			draw_arc(zp, float(z["r"]), 0, TAU, 24, Color(col.r, col.g, col.b, 0.85), 1.2, true)
			draw_circle(zp, float(z["r"]) * (1.0 - clampf(float(z["t"]) / 0.9, 0.0, 1.0)), Color(col.r, col.g, col.b, 0.22))
		else:
			draw_circle(zp, float(z["r"]), Color(col.r, col.g, col.b, 0.42 + 0.15 * pulse))
			draw_arc(zp, float(z["r"]), 0, TAU, 24, Color(1, 1, 1, 0.5), 1.0, true)
	for l: Dictionary in _lines:
		if bool(l["fired"]) and not bool(l.get("warn", false)):
			draw_line(l["a"], l["b"], Color(1, 1, 1, 0.95), float(l["w"]))
			draw_line(l["a"], l["b"], col, float(l["w"]) * 0.5)
		else:
			draw_line(l["a"], l["b"], Color(col.r, col.g, col.b, 0.3 + 0.25 * pulse), 1.5)
			draw_line(l["a"], l["b"], Color(col.r, col.g, col.b, 0.1), float(l["w"]) * 2.0)
	for b: Dictionary in _bul:
		draw_circle(b["p"], float(b["r"]) + 1.5, Color(col.r, col.g, col.b, 0.35))
		draw_circle(b["p"], float(b["r"]), col)
		draw_circle(b["p"], float(b["r"]) * 0.45, Color(1, 1, 1, 0.9))


# ---- your side: a recruited Marked lends you their Gift --------------------------

static func cast(m: GameMap, p: Player, id: String) -> void:
	var g := def(id)
	if g.is_empty():
		return
	if not GameState.spend_mana(int(g.get("mana", 8))):
		m.hud.toast("Not enough mana.", Color(0.7, 0.8, 1.0))
		return
	var c := Color(str(g.get("colour", "c080ff")))
	var dmg := 3 + GameState.progress_tier() * 2
	var near: Array = []
	for en in m.enemies.duplicate():
		if is_instance_valid(en) and en._alive and en.position.distance_to(p.position) < float(g.get("reach", 64.0)):
			near.append(en)
	m.fx("ripple_ring" if Art.has("fx", "ripple_ring") else "sparkle", p.position + Vector2(0, -8), 12.0, 0.9)
	match str(g.get("lend", "burst")):
		"burn":
			for en: Enemy in near:
				en.hit(dmg, p.position, true)
				en.set_meta("burn", 4)
		"line":
			var dir := p.facing_dir()
			for en in m.enemies.duplicate():
				if is_instance_valid(en) and en._alive and _seg_dist(en.position, p.position, p.position + dir * 130.0) < 12.0:
					en.hit(dmg + 3, p.position, true)
		"dazzle":
			for en: Enemy in near:
				en._stun = maxf(en._stun, 2.8)
		"root":
			for en: Enemy in near:
				en._stun = maxf(en._stun, 3.2)
				en.hit(maxi(1, dmg - 2), p.position, true)
		"gale":
			for en: Enemy in near:
				en._knock = (en.position - p.position).normalized() * 320.0
				en._stun = maxf(en._stun, 0.8)
			GameState.run["buffs"] = GameState.run.get("buffs", {})
			GameState.run["buffs"]["speed"] = {"until": GameState.now_abs() + 30, "amount": 1.25}
		"iron":
			GameState.run["buffs"] = GameState.run.get("buffs", {})
			GameState.run["buffs"]["defense"] = {"until": GameState.now_abs() + 30, "amount": 4.0}
		"shade":
			p.invuln = maxf(p.invuln, 3.0)
		"beat":
			for en: Enemy in near:
				en.hit(maxi(1, dmg - 1), p.position, true)
				if is_instance_valid(en) and en._alive:
					en.hit(maxi(1, dmg - 1), p.position, true)
		"luck":
			var roll := randi() % 3
			if roll == 0:
				var n := 20 + 15 * GameState.progress_tier()
				GameState.run["crystals"] = int(GameState.run["crystals"]) + n
				m.hud.toast("Lucky: +◆%d" % n, Color(1, 0.9, 0.4))
			elif roll == 1:
				GameState.heal(12)
			else:
				for en: Enemy in near:
					en.hit(dmg + 4, p.position, true)
		"pull":
			for en: Enemy in near:
				en.position = en.position.lerp(p.position + (en.position - p.position).normalized() * 18.0, 0.8)
				en.hit(dmg, p.position, true)
				en._stun = maxf(en._stun, 1.0)
	m.hud.toast("%s!" % str(g.get("name", "Gift")), c)
