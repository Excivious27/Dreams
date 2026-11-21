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
var _rd_acc := 0.0
var _rd_pos := Vector2.INF
var _rd_face := 0.0


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
			return opened if (_wet() or open_t > 0.0) else closed
		"back":
			var behind := (from.x - e.position.x) * face < -2.0
			return opened if (behind or open_t > 0.0) else closed
		"range":
			var far := from.distance_to(e.position) > float(r.get("far", 46.0)) or magic or _pull > 0.0
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
	if Art.has("fx", "gift_guard"):
		e.map.fx("gift_guard", e.position + Vector2(0, -10), 16.0, 0.45)
	if not _told:
		_told = true
		e.map.hud.toast(str(d.get("tip", "Read their moves. Wait for the opening.")), Color(1, 0.9, 0.6))
	# Some answer a blocked hit.
	if rule() == "offbeat":
		_ring(8, 70.0, 2.5)
	elif rule() == "window" and bool(d.get("rule", {}).get("slip", false)):
		_slip()


func on_hit(mult: float) -> void:
	if mult < 1.0 and not _told:
		# A glancing blow: tell them how to land a real one, once.
		_told = true
		e.map.hud.toast(str(d.get("tip", "Read their moves. Wait for the opening.")), Color(1, 0.9, 0.6))
	if mult >= 1.5 or open_t > 0.0:
		_say("OPEN!", Color(1, 1, 0.6))
		if Art.has("fx", "gift_open"):
			e.map.fx("gift_open", e.position + Vector2(0, -10), 16.0, 0.5)
		var known: Dictionary = GameState.run.get("gifts_known", {})
		if not known.has(gid):
			known[gid] = true
			GameState.run["gifts_known"] = known
			GameState.add_hint("%s: %s" % [str(d.get("name", gid)), str(d.get("tip", ""))])


func _say(t: String, c: Color) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 7)
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
				if open_t <= 0.0 and e.position.distance_to(p.position) < 150.0:
					Music.instance(get_tree()).sfx("stun", "alert")  # hear the opening
				open_t = maxf(open_t, 0.1)
		"offbeat":
			var beat := float(d["rule"].get("beat", 1.6))
			var was_t := _closed_t
			_closed_t += delta
			# An audible beat on every bar line (c6_08_24): hit just after it.
			if int(was_t / beat) != int(_closed_t / beat) and e.position.distance_to(p.position) < 190.0:
				Music.instance(get_tree()).sfx("war_drum", "thud")
			if fmod(_closed_t, beat) < float(d["rule"].get("gap", 0.5)):
				open_t = maxf(open_t, 0.05)
	# Pull / gust act on you while they last.
	if _pull > 0.0:
		_pull -= delta
		if GameState.bonus("magic", "awakened") <= 0.0:
			_shove(p, (e.position - p.position).normalized() * float(d.get("pull_force", 42.0)) * delta)
		if _pull <= 0.0:
			_impact(p)
			_ring(14, 80.0, 3.0, 3)
			e.map.shake(3.0)
			_open_after("pull")
	if _gust > 0.0:
		_gust -= delta
		_shove(p, (p.position - e.position).normalized() * 70.0 * delta)
		if _gust <= 0.0:
			_open_after("gust")
	if _veil > 0.0:
		_veil -= delta
		if e._sprite:
			e._sprite.modulate.a = 0.07
		if _veil <= 0.0:
			# Step out behind you and strike.
			e.position = e.map.free_spot_near(p.position - p.facing_dir() * 18.0)
			if e._sprite:
				e._sprite.modulate.a = 1.0
			e.map.fx("blink" if Art.has("fx", "blink") else "poof", e.position + Vector2(0, -8), 14.0, 0.4)
			_lines.append({"a": e.position, "b": e.map.line_end(e.position, e.position + (p.position - e.position).normalized() * 40.0), "t": 0.35, "w": 9.0, "fired": false})
			_open_after("veil")
	elif not decoy and e._sprite and e._sprite.modulate.a < 1.0:
		e._sprite.modulate.a = 1.0
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
	# Every frame only while something moves or pulses; a guarded aura that stands
	# still needs no redraw (each Marked redrew an antialiased arc + its name every frame).
	_rd_acc += delta
	if not (_bul.is_empty() and _lines.is_empty() and _zones.is_empty()) or open_t > 0.0 or _pull > 0.0 or _gust > 0.0 or e.position != _rd_pos or face != _rd_face or _rd_acc >= 0.1:
		_rd_acc = 0.0
		_rd_pos = e.position
		_rd_face = face
		queue_redraw()


func _open_after(move: String) -> void:
	var r: Dictionary = d.get("rule", {})
	if str(r.get("after", "")) in [move, "any"]:
		open_t = float(r.get("secs", 2.0))
		Music.instance(get_tree()).sfx("stun", "alert")  # hear the opening
		e._stun = maxf(e._stun, minf(open_t, float(r.get("stagger", 0.0))))


## A gift's family word (cinder, volt, gale, iron, bramble, gravity, fortune,
## dark_burst, mirror, shade, tempo, or the id itself).
static func family(g: String) -> String:
	return {"beat": "tempo", "lt_tide": "gale", "lt_neonfire": "cinder", "lt_anvil": "iron", "lt_grid": "volt", "lt_thicket": "bramble",
		"lt_gravity": "gravity", "lt_express": "gale", "lt_ledger": "fortune", "b_dark": "dark_burst", "b_president": "dark_burst",
		"b_sentinel": "dark_burst", "b_mirror": "mirror", "b_witch": "shade", "b_elder": "shade", "c_ember": "cinder", "c_ice": "mirror",
		"c_kelp": "gale", "c_coral": "bramble"}.get(g, g)


## Which Prompt 16-5 effect strip belongs to a gift ("" for none).
static func fx_for(g: String) -> String:
	var fam := family(g)
	return "gift_" + fam if Art.has("fx", "gift_" + fam) else ""


## The impact sound of a gift's blasts by family (c6_08_09); shared with the
## Marked crew's borrowed powers (Companion). Every name exists or falls back.
const FAMILY_SFX := {"cinder": "spell_fire", "volt": "spell_lightning", "gale": "swing_heavy", "iron": "rock_break",
	"bramble": "spell_nature", "gravity": "spell_dark", "dark_burst": "spell_dark", "shade": "spell_dark",
	"mirror": "glass", "fortune": "dice_roll", "tempo": "war_drum", "ice": "spell_ice"}


static func sfx_for(g: String) -> String:
	var fam := family(g)
	if g == "c_ice":
		fam = "ice"
	return str(FAMILY_SFX.get(fam, "spell"))


## Play the family impact, near the player only.
func _impact(p: Player) -> void:
	if p and e.position.distance_to(p.position) < 190.0:
		var n := sfx_for(gid)
		Music.instance(get_tree()).sfx(n, "spell_earth" if n == "rock_break" else ("stun" if n in ["dice_roll", "war_drum"] else "spell"))


func _do(mv: Dictionary, p: Player) -> void:
	var t := str(mv.get("type", "ring"))
	var gf := fx_for(gid)
	Music.instance(get_tree()).sfx("tell", "spell")  # the move's tell (not the player's cast sound)
	e.play_power()
	if gf != "" and t != "roll":
		e.map.fx(gf, e.position + Vector2(0, -4), 14.0, 0.6)
	if t == "roll":
		_rolls += 1
		Music.instance(get_tree()).sfx("dice_roll", "cards")  # count her rolls by ear (c6_08_24)
		var opts: Array = mv.get("of", ["ring", "zones", "lines"])
		t = str(opts[randi() % opts.size()])
		_say(["Lucky!", "Double or nothing!", "Come on, sevens..."][randi() % 3], col)
		if _rolls % int(d.get("rule", {}).get("rolls", 3)) == 0:
			open_t = float(d.get("rule", {}).get("secs", 4.0))
			_say("...snake eyes.", Color(1, 1, 0.6))
			Music.instance(get_tree()).sfx("stun", "alert")  # hear the opening
		if t == "heal":
			e.hp = mini(e.max_hp, e.hp + int(e.max_hp * 0.06))
			e.map.fx("sparkle", e.position + Vector2(0, -10), 12.0, 0.5)
			return
	if t in ["ring", "spiral", "dash", "gust", "veil"]:
		_impact(p)
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
				var a0 := e.position + Vector2(0, -6)
				_lines.append({"a": a0, "b": e.map.line_end(a0, a0 + aim * float(mv.get("len", 150.0))), "t": 0.55 + 0.32 * k, "w": float(mv.get("w", 6.0)), "fired": false, "last": k == n - 1})
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
			var made: Array = []
			for k in int(cl.get("n", 2)):
				var c: Enemy = e.map.spawn_enemy(e.kind, e.position + Vector2(40, 0).rotated(TAU * k / 3.0 + 1.0))
				if c == null:
					continue
				c.hp = 1
				c.max_hp = 1
				c.reward = 0
				c.damage = maxi(1, e.damage - 1)
				c._shadow_r = 0.0; c.abilities = []; c.inflicts = ""; c._shield = 0.0; c.is_guardian = false   # the tell: reflections cast no shadow
				c.set_meta("decoy", true)
				if c._gift:
					c._gift.decoy = true
				spots.append(c.position); made.append(c)
			# Shuffle who stands where so you can't just track the real one (swap with a decoy).
			var pick := randi() % spots.size()
			if pick > 0 and is_instance_valid(made[pick - 1]):
				(made[pick - 1] as Enemy).position = e.position
				e.position = spots[pick]


# ---- shots, lanes, circles ---------------------------------------------------------

func _hurt(p: Player, n: int) -> void:
	if p.invuln <= 0.0:
		p.take_damage(GameState.enemy_damage(n), e.position)


func _shove(p: Player, step: Vector2) -> void:
	var np := p.position + step
	if not e.map.rect_blocked_player(Rect2(np + Player.FEET.position, Player.FEET.size), p):
		p.position = np


func _bullet_blocked(at: Vector2) -> bool:
	var bc := e.map.world_to_cell(at + Vector2(0, 6))
	return e.map.blocked.has(bc) and not e.map.is_water_cell(bc)


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
		elif _bullet_blocked(b["p"] as Vector2):
			_bul.erase(b)  # cover stops shots
		elif (b["p"] as Vector2).distance_to(feet) < float(b["r"]) + 5.0:
			_hurt(p, e.damage)
			_bul.erase(b)
	for l: Dictionary in _lines.duplicate():
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) <= 0.0:
			if not bool(l["fired"]):
				l["fired"] = true
				l["t"] = 0.14  # the flash
				Music.instance(get_tree()).sfx("zap", "shot")
				if _seg_dist(feet, l["a"], l["b"]) < float(l["w"]) + 3.0:
					_hurt(p, e.damage + 1)
				if bool(l.get("last", false)):
					_open_after("lines")
			else:
				_lines.erase(l)
	for z: Dictionary in _zones.duplicate():
		z["t"] = float(z["t"]) - delta
		if float(z["t"]) <= 0.0:
			if not z.has("rang"):
				z["rang"] = true
				_impact(p)  # each zone lands with the family's sound
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
		Art.draw_ring(self, e.position + Vector2(0, -8), 13.0 + (2.0 * pulse if open_t > 0.0 else 0.0), 2.0 if open_t > 0.0 else 1.2, ac)  # one quad (an antialiased draw_arc is 3 draw calls)
		if rule() == "back":
			var mid := 0.0 if face > 0.0 else PI
			draw_arc(e.position + Vector2(0, -8), 16.0, mid - 1.2, mid + 1.2, 14, Color(col.r, col.g, col.b, 0.95), 2.5, true)
		if e.has_meta("marked"):
			var nm := str(Marked.all().get(str(e.get_meta("marked")), {}).get("epithet", ""))
			var f := ThemeDB.fallback_font
			var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
			draw_string_outline(f, e.position + Vector2(-w / 2.0, -40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, DisplayMode.df(6), 2, Color(0.05, 0.05, 0.1))
			draw_string(f, e.position + Vector2(-w / 2.0, -40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, DisplayMode.df(6), col)
		if _pull > 0.0:
			for k in 3:
				draw_arc(e.position, 70.0 - fmod(Time.get_ticks_msec() / 14.0 + k * 22.0, 66.0), 0, TAU, 32, Color(col.r, col.g, col.b, 0.35), 1.0, true)
		if _gust > 0.0:
			for k in 3:
				draw_arc(e.position, 12.0 + fmod(Time.get_ticks_msec() / 10.0 + k * 20.0, 60.0), 0, TAU, 32, Color(1, 1, 1, 0.3), 1.0, true)
	for z: Dictionary in _zones:
		var zp: Vector2 = z["p"]
		if float(z["t"]) > 0.0:
			Art.draw_ring(self, zp, float(z["r"]), 1.2, Color(col.r, col.g, col.b, 0.85))
			Art.draw_disc(self, zp, float(z["r"]) * (1.0 - clampf(float(z["t"]) / 0.9, 0.0, 1.0)), Color(col.r, col.g, col.b, 0.22))
		else:
			Art.draw_disc(self, zp, float(z["r"]), Color(col.r, col.g, col.b, 0.42 + 0.15 * pulse))
			Art.draw_ring(self, zp, float(z["r"]), 1.0, Color(1, 1, 1, 0.5))
	for l: Dictionary in _lines:
		if bool(l["fired"]) and not bool(l.get("warn", false)):
			draw_line(l["a"], l["b"], Color(1, 1, 1, 0.95), float(l["w"]))
			draw_line(l["a"], l["b"], col, float(l["w"]) * 0.5)
		else:
			draw_line(l["a"], l["b"], Color(col.r, col.g, col.b, 0.3 + 0.25 * pulse), 1.5)
			draw_line(l["a"], l["b"], Color(col.r, col.g, col.b, 0.1), float(l["w"]) * 2.0)
	for b: Dictionary in _bul:
		# Textured discs: a 14-bullet ring x3 waves was ~126 draw calls as draw_circles, now one.
		Art.draw_disc(self, b["p"], float(b["r"]) + 1.5, Color(col.r, col.g, col.b, 0.35))
		Art.draw_disc(self, b["p"], float(b["r"]), col)
		Art.draw_disc(self, b["p"], float(b["r"]) * 0.45, Color(1, 1, 1, 0.9))


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
	var lf := fx_for(id)
	if lf != "":
		m.fx(lf, p.position + Vector2(0, -4), 14.0, 0.7)
	else:
		m.fx("ripple_ring" if Art.has("fx", "ripple_ring") else "sparkle", p.position + Vector2(0, -8), 12.0, 0.9)
	match str(g.get("lend", "burst")):
		"burn":
			for en: Enemy in near:
				en.hit(dmg, p.position, true, true)
				en.set_meta("burn", 4)
		"line":
			var dir := p.facing_dir()
			for en in m.enemies.duplicate():
				if is_instance_valid(en) and en._alive and _seg_dist(en.position, p.position, p.position + dir * 130.0) < 12.0 and m.line_clear(p.position, en.position):
					en.hit(dmg + 3, p.position, true, true)
		"dazzle":
			for en: Enemy in near:
				en._stun = maxf(en._stun, 1.0 if en._gift else 2.8)
		"root":
			for en: Enemy in near:
				en._stun = maxf(en._stun, 1.2 if en._gift else 3.2)
				en.hit(maxi(1, dmg - 2), p.position, true, true)
		"gale":
			for en: Enemy in near:
				en._knock = (en.position - p.position).normalized() * 320.0
				en._stun = maxf(en._stun, 0.8)
			GameState.run["buffs"] = GameState.run.get("buffs", {})
			if GameState.buff("speed") <= 2.0:
				GameState.run["buffs"]["speed"] = {"until": GameState.now_abs() + GameState.real_min(21.0), "amount": 2.0}
		"iron":
			GameState.run["buffs"] = GameState.run.get("buffs", {})
			if GameState.buff("defense") <= 3.0:
				GameState.run["buffs"]["defense"] = {"until": GameState.now_abs() + GameState.real_min(21.0), "amount": 3.0}
		"shade":
			p.invuln = maxf(p.invuln, 3.0)
		"beat":
			for en: Enemy in near:
				en.hit(maxi(1, dmg - 1), p.position, true, true)
				if is_instance_valid(en) and en._alive:
					en.hit(maxi(1, dmg - 1), p.position, true, true)
		"luck":
			var roll := randi() % 3
			# A map picked clean for today (12 paid kills) only pays luck on bosses.
			var kk := m.scene_id() + (":%d" % int(m.get("floor_no")) if m.scene_id() == "mine" else "")
			var kt_: Dictionary = GameState.run.get("kills_today", {})
			var picked: bool = int(kt_.get(kk, 0)) >= 12 or int(kt_.get("bf:" + kk, 0)) >= 12
			var payers: Array = near.filter(func(x: Enemy) -> bool: return not x.has_meta("luck_paid") and not x.has_meta("decoy") and not x.has_meta("minion") and (not picked or x.has_meta("boss_name")))
			if roll == 0 and not payers.is_empty():
				for x: Enemy in payers:
					x.set_meta("luck_paid", true)  # one payout per real foe
				var n := 20 + 15 * GameState.progress_tier()
				GameState.add_money(n, "luck")  # C16a P2: counted in run.earned_by
				m.hud.toast("Lucky: +◆%d" % n, Color(1, 0.9, 0.4))
			elif roll == 1 or near.is_empty() or roll == 0:
				GameState.heal_points(12)
				m.hud.toast("Lucky: +12 health", Color(1, 0.8, 0.8))
			else:
				for en: Enemy in near:
					en.hit(dmg + 4, p.position, true, true)
		"pull":
			for en: Enemy in near:
				var np: Vector2 = en.position.lerp(p.position + (en.position - p.position).normalized() * 18.0, 0.8)
				if m.line_clear(p.position, en.position) and not m.rect_blocked(Rect2(np + Vector2(-4, -3), Vector2(8, 3))):
					en.position = np
				en.hit(dmg, p.position, true, true)
				en._stun = maxf(en._stun, 1.0)
		_:
			# "burst" (and any gift without a lend arm): a plain hit on everything near.
			for en: Enemy in near:
				en.hit(dmg, p.position, true, true)
	m.hud.toast("%s!" % str(g.get("name", "Gift")), c)
