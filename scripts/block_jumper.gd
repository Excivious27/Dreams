class_name BlockJumper
extends ArcadeGame
## Block Jumper, the flagship cabinet: an auto-scrolling runner. A jumps (hold
## for higher), DOWN ducks under low ceilings (and drops fast in the air).
## Eight levels that unlock in order, each faster and busier, plus Endless.
## Clearing level 4 unlocks a double jump. Checkpoints, coins, three lives.
## World and physics: JumperLevels.

const FEE := 10
const PX := 70.0   # player's screen x
const COLS := 3
const BG := ["meadow", "canyon", "forest", "clouds", "gears", "garden", "night", "space"]

var level := 1
var lv: Dictionary = {}
var st: Array = []
var lives := 3
var coins_got := {}
var check_i := -1
var respawn := Vector2(0, JumperLevels.GY0)
var dead_t := 0.0
var win_t := 0.0
var intro_t := 0.0
var best_x := 0.0
var cleared_now := false
var rot := 0.0
var squash := Vector2.ONE
var trail: Array = []
var sel := 0
var _dust := 0
var _unlock_lines: Array = []


func _init() -> void:
	super()
	game_id = "jumper"
	title = "Block Jumper"
	fee = FEE
	accent = Color(0.35, 0.82, 1.0)
	state = "select"


var _air_t := 0.0  # seconds off the ground (landing cue weight)


func _start_music() -> void:
	Music.instance(get_tree()).play("arcade_jumper")


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(8, 392, 40, 40), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(92, 392, 40, 40), "label": "▶", "skin": "blue"},
		{"action": "up", "rect": Rect2(50, 358, 40, 36), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(50, 430, 40, 36), "label": "▼", "skin": "blue", "hint": "duck"},
		{"action": "a", "rect": Rect2(192, 372, 70, 70), "label": "JUMP", "skin": "gold"},
		{"action": "b", "rect": Rect2(148, 430, 36, 36), "label": "B", "skin": "red", "hint": "quit"},
	]


## While running only ▼ (duck), JUMP and B do anything: the rest of the d-pad dims.
func _dead(b: Dictionary) -> bool:
	return state == "play" and str(b["action"]) in ["left", "right", "up"]


## While running, the whole play area is a second JUMP button: a thumb
## anywhere on the picture jumps (hold for higher), so you never miss the
## gold button while watching the level.
var _play_touch := {}


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var tch := ev as InputEventScreenTouch
		if tch.pressed and state == "play" and PLAY.has_point(DisplayMode.ui(tch.position)) and _deck_at(DisplayMode.ui(tch.position)) == "":
			_play_touch[tch.index] = true
			Input.action_press("a")
			get_viewport().set_input_as_handled()
			return
		if not tch.pressed and _play_touch.has(tch.index):
			_play_touch.erase(tch.index)
			if _play_touch.is_empty() and not _touch.values().has("a"):
				Input.action_release("a")
			get_viewport().set_input_as_handled()
			return
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed and state == "play" and PLAY.has_point(DisplayMode.ui(mb.position)) and _deck_at(DisplayMode.ui(mb.position)) == "":
			_play_touch[-1] = true
			Input.action_press("a")
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and _play_touch.has(-1):
			_play_touch.erase(-1)
			if _play_touch.is_empty() and _mouse_action != "a":
				Input.action_release("a")
			get_viewport().set_input_as_handled()
			return
	super(ev)


# --- progress ----------------------------------------------------------------

static func _jd() -> Dictionary:
	var d: Dictionary = ArcadeHub._data()["jumper"]
	for k in ["clear", "coins", "best"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}
	return d


## Best distance on a level (%; 0 = endless, in metres). Kept here: Tickets'
## best/plays are per cabinet, and the levels are one cabinet.
static func best(n: int) -> int:
	return int(_jd()["best"].get(str(n), 0))


static func _set_level_best(n: int, v: int) -> bool:
	if v > best(n):
		_jd()["best"][str(n)] = v
		return true
	return false


static func cleared(n: int) -> bool:
	return bool(_jd()["clear"].get(str(n), false))


static func is_unlocked(n: int) -> bool:
	if n == 1:
		return true
	if n <= 0:
		return cleared(1)
	return cleared(n - 1)


static func double_jump() -> bool:
	return cleared(4)


static func level_for_tile(i: int) -> int:
	return 0 if i >= JumperLevels.LEVELS.size() else i + 1


# --- level select --------------------------------------------------------------

func _tile(i: int) -> Rect2:
	return Rect2(14 + (i % COLS) * 82, 50 + (i / COLS) * 84, 76, 78)


func _step_state(s: String, _dt: float) -> void:
	if s != "select":
		return
	var n := JumperLevels.LEVELS.size() + 1
	if pressed("left"):
		sel = posmod(sel - 1, n)
		sfx("scroll_tick", "ui_tap")
	elif pressed("right"):
		sel = posmod(sel + 1, n)
		sfx("scroll_tick", "ui_tap")
	elif pressed("up"):
		sel = posmod(sel - COLS, n)
		sfx("scroll_tick", "ui_tap")
	elif pressed("down"):
		sel = posmod(sel + COLS, n)
		sfx("scroll_tick", "ui_tap")
	elif pressed("a"):
		play_tile(sel)
	elif pressed("b"):
		close()


func _tap(p: Vector2) -> void:
	if state != "select":
		return
	for i in JumperLevels.LEVELS.size() + 1:
		if _tile(i).has_point(p):
			if i == sel:
				play_tile(i)
			else:
				sel = i
				sfx("scroll_tick", "ui_tap")


func play_tile(i: int) -> bool:
	var n := level_for_tile(i)
	if not is_unlocked(n):
		sfx("locked", "nope")
		say("Clear level %d first." % maxi(1, n - 1) if n > 0 else "Clear level 1 first.")
		return false
	level = n
	return start()


func _after_over() -> void:
	state = "select"
	if cleared_now and level > 0 and level < JumperLevels.LEVELS.size():
		sel = level  # hop to the next level's tile


# --- a run -------------------------------------------------------------------

func _setup_round() -> void:
	lv = JumperLevels.build(level, double_jump())
	lives = 3
	coins_got = {}
	check_i = -1
	respawn = Vector2(0, JumperLevels.GY0)
	st = JumperLevels.new_state(0.0, JumperLevels.GY0)
	dead_t = 0.0
	win_t = 0.0
	intro_t = 1.4
	best_x = 0.0
	cleared_now = false
	rot = 0.0
	squash = Vector2.ONE
	trail.clear()
	_unlock_lines = []


func _step(dt: float) -> void:
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12.0))
	if pressed("b") and dead_t <= 0.0 and win_t <= 0.0:
		_end_run(false)
		return
	if intro_t > 0.0:
		intro_t -= dt
		if intro_t > 0.5:
			return
	if dead_t > 0.0:
		dead_t -= dt
		if dead_t <= 0.0:
			if lives > 0:
				_respawn()
			else:
				_end_run(false)
		return
	if win_t > 0.0:
		win_t -= dt
		if int(win_t * 60.0) % 12 == 0:
			burst(Vector2(float(st[JumperLevels.X]) + rng.randf_range(-40, 120), rng.randf_range(60, 160)), Color.from_hsv(rng.randf(), 0.7, 1.0), 14, 90.0, 2.0, 120.0)
		if win_t <= 0.0:
			_end_run(true)
		return
	if level <= 0:
		JumperLevels.extend(lv, float(st[JumperLevels.X]) + 700.0)
	var was_ground := int(st[JumperLevels.GND]) == 1
	_air_t = 0.0 if was_ground else _air_t + dt
	var ev := JumperLevels.step(st, lv, held("a"), held("down"), dt)
	var x := float(st[JumperLevels.X])
	var y := float(st[JumperLevels.Y])
	best_x = maxf(best_x, x)
	match ev:
		"jump":
			squash = Vector2(0.7, 1.35)
			sfx("pop", "ui_tap")
			burst(Vector2(x, y), Color(1, 1, 1, 0.7), 5, 30.0, 2.0, 0.0)
		"djump":
			squash = Vector2(0.75, 1.3)
			sfx("sparkle", "pop")
			burst(Vector2(x, y - 7), Color(0.6, 0.95, 1.0), 10, 50.0, 2.0, 0.0)
		"land":
			squash = Vector2(1.35, 0.7)
			rot = 0.0
			# A light step for a hop; the heavy thud only after a real fall.
			if _air_t > 0.45:
				sfx("thud", "step_wood")
			else:
				sfx("step_wood", "pop")
			burst(Vector2(x, y), _theme()[5].lightened(0.3), 6, 40.0, 2.0, 200.0)
		"bonk":
			sfx("block", "thud")
			squash = Vector2(1.2, 0.8)
		"dead":
			_die()
			return
		"win":
			_win()
			return
	if int(st[JumperLevels.GND]) == 0:
		rot += dt * TAU * 0.9 * (1.0 if float(st[JumperLevels.VY]) < 0 else 0.7)
		trail.append(Vector2(x, y - float(st[JumperLevels.HGT]) * 0.5))
		if trail.size() > 6:
			trail.pop_front()
	else:
		if not was_ground:
			rot = 0.0
		if not trail.is_empty():
			trail.pop_front()
		_dust += 1
		if _dust % 7 == 0:
			_parts.append({"p": Vector2(x - 6, y - 1), "v": Vector2(-30 - rng.randf() * 20, -10 - rng.randf() * 15), "life": 0.35, "max": 0.35, "c": Color(1, 1, 1, 0.5), "s": 2.0, "g": 60.0})
	_collect(x, y)
	_checkpoints(x)


func _collect(x: float, y: float) -> void:
	var h := float(st[JumperLevels.HGT])
	var ctr := Vector2(x, y - h * 0.5)
	var coins: Array = lv["coins"]
	for i: int in JumperLevels.near(lv, "coins", x - 12, x + 12):
		if coins_got.has(i):
			continue
		var cp: Vector2 = coins[i]
		if absf(cp.x - ctr.x) < 11.0 and absf(cp.y - ctr.y) < 6.0 + h * 0.5 + 3.0:
			coins_got[i] = true
			point_sfx()
			burst(cp, Color(1, 0.85, 0.3), 6, 50.0, 2.0, 60.0)


func _checkpoints(x: float) -> void:
	var checks: Array = lv["checks"]
	for i in range(check_i + 1, checks.size()):
		var cpos: Vector2 = checks[i]
		if x >= cpos.x:
			check_i = i
			respawn = cpos
			sfx("j_confirm", "unlock")
			float_text(Vector2(x + 50.0, cpos.y - 44), "CHECKPOINT", Color(0.6, 1, 0.6))  # ahead of you: the flag is already sliding off-screen
			burst(Vector2(cpos.x, cpos.y - 26), Color(0.5, 1, 0.5), 12, 60.0)


func _die() -> void:
	lives -= 1
	dead_t = 1.0
	var p := Vector2(float(st[JumperLevels.X]), float(st[JumperLevels.Y]) - 7)
	burst(p, accent, 18, 110.0, 3.0, 300.0)
	burst(p, Color.WHITE, 8, 70.0, 2.0, 200.0)
	shake(5.0)
	trail.clear()
	sfx("crate_break", "hurt")


func _respawn() -> void:
	st = JumperLevels.respawn_state(lv, respawn.x, respawn.y)
	intro_t = 0.9
	rot = 0.0
	squash = Vector2(1.3, 0.7)
	sfx("teleport", "pop")


func _win() -> void:
	win_t = 1.6
	cleared_now = true
	sfx("fireworks", "j_victory")
	shake(2.0)


func _end_run(done: bool) -> void:
	cleared_now = done
	var lines: Array = []
	var coins_n := coins_got.size()
	var coins_all: int = (lv["coins"] as Array).size()
	var jd := _jd()
	if level > 0:
		var pct := 100 if done else clampi(int(best_x / float(lv["finish"]) * 100.0), 0, 99)
		score = pct
		lines.append("!LEVEL CLEAR" if done else ("!OUT OF LIVES" if lives <= 0 else "!RUN ENDED"))
		lines.append("Level %d: %s" % [level, JumperLevels.level_def(level)["name"]])
		lines.append("Distance %d%%   Coins %d/%d" % [pct, coins_n, coins_all])
		jd["coins"][str(level)] = maxi(int(jd["coins"].get(str(level), 0)), coins_n)
		if done:
			var first := not cleared(level)
			jd["clear"][str(level)] = true
			ArcadeHub.set_milestone("jumper_%d" % level)
			if coins_n >= coins_all:
				ArcadeHub.set_milestone("jumper_coins")
			if first and level == 4:
				lines.append("Double jump unlocked! (A in the air)")
			elif first and level < JumperLevels.LEVELS.size():
				lines.append("Level %d unlocked!" % (level + 1))
			if first and level == 1:
				lines.append("Endless Run unlocked!")
	else:
		score = int(best_x / 16.0)
		lines.append("!RUN OVER")
		lines.append("Endless: %d m   Coins %d" % [score, coins_n])
		if score >= 300:
			ArcadeHub.set_milestone("jumper_endless_300")
		if score >= 1000:
			ArcadeHub.set_milestone("jumper_endless_1000")
	var lvl_best := _set_level_best(level, score)
	# The cabinet's own high score (Tickets): campaign progress, 100 per level.
	var cab := (level - 1) * 100 + score if level > 0 else score
	game_over(lines, cab)
	new_best = lvl_best


func _tickets_for(_s: int) -> int:
	var coins_n := coins_got.size()
	if level <= 0:
		return score / 12 + coins_n / 4
	var full := 6 + 4 * level
	if cleared_now:
		return full + coins_n / 3
	return int(score / 100.0 * full * 0.5) + coins_n / 4


func _good_tickets() -> int:
	return 0 if cleared_now or level <= 0 else 9999


func _top_right() -> String:
	if state == "select":
		return Money.amount(ArcadeHub.money())
	if level <= 0:
		return "%d m" % int(best_x / 16.0)
	return "%d%%" % (clampi(int(best_x / maxf(1.0, float(lv.get("finish", 1.0))) * 100.0), 0, 100))


func _theme() -> Array:
	return JumperLevels.theme(level, float(st[JumperLevels.X]) if not st.is_empty() else 0.0)


# --- drawing -----------------------------------------------------------------

func _draw_play(c: Control) -> void:
	if state == "select":
		_draw_select(c)
		return
	if lv.is_empty():
		return
	var th := _theme()
	var cam := float(st[JumperLevels.X]) - PX
	_draw_sky(c, th, cam)
	var off := Vector2(-cam, TOP) + draw_off
	c.draw_set_transform(off)
	var x0 := cam - 24.0
	var x1 := cam + W + 24.0
	_draw_world(c, th, x0, x1)
	_draw_player(c, off)
	c.draw_set_transform(off)
	draw_fx(c)
	c.draw_set_transform(draw_off)
	_draw_hud(c, th)


func _theme_i() -> int:
	return int(JumperLevels.level_def(level)["theme"]) if level > 0 else int(float(st[JumperLevels.X]) / 6400.0) % JumperLevels.THEMES.size()


func _draw_sky(c: Control, th: Array, cam: float) -> void:
	var bg := ArcadeGame.tex("bg_" + str(BG[_theme_i()]))
	if bg:
		# The painted panorama, wrapping, at a slow parallax.
		var sz := Vector2(bg.get_size())
		var h := PLAY.size.y + 8.0
		var w := sz.x * h / sz.y
		var ox := -fposmod(cam * 0.22, w)
		while ox < W:
			c.draw_texture_rect(bg, Rect2(ox, TOP - 4.0, w + 1.0, h), false)
			ox += w
		return
	var top: Color = th[0]
	var bot: Color = th[1]
	for i in 41:
		c.draw_rect(Rect2(0, TOP + i * 8, W, 8), top.lerp(bot, i / 40.0))
	var ti := int(JumperLevels.level_def(level)["theme"]) if level > 0 else int(float(st[JumperLevels.X]) / 6400.0) % JumperLevels.THEMES.size()
	if ti >= 6:  # night and space: stars
		for i in 46:
			var sx := fposmod(i * 61.0 - cam * 0.04, W)
			var sy := TOP + fposmod(i * 37.0, 180.0)
			var tw := 0.5 + 0.5 * sin(t * 3.0 + i)
			c.draw_rect(Rect2(sx, sy, 1 + (i % 3 == 0 as int), 1 + (i % 3 == 0 as int)), Color(1, 1, 1, 0.4 + 0.6 * tw))
		c.draw_circle(Vector2(210 - fposmod(cam * 0.01, 40), TOP + 52), 14, Color(1, 0.95, 0.8, 0.9))
	elif ti != 4:
		c.draw_circle(Vector2(220, TOP + 46), 16, Color(1, 1, 0.85, 0.75))
	# Far hills.
	var far: Color = th[2]
	var pts := PackedVector2Array()
	pts.append(Vector2(0, DECK))
	for sx in range(0, 277, 6):
		var wx := sx + cam * 0.15
		var hh := 92.0 + 26.0 * sin(wx * 0.012) + 12.0 * sin(wx * 0.043 + 2.0)
		if ti == 4:
			hh = 70.0 + (40.0 if int(wx / 36.0) % 3 == 0 else 14.0)  # factory skyline
		pts.append(Vector2(sx, TOP + 250 - hh))
	pts.append(Vector2(W, DECK))
	c.draw_colored_polygon(pts, far)
	if ti == 4:  # turning gears in the haze
		for i in 3:
			var gx := fposmod(i * 120.0 - cam * 0.3, 360.0) - 45.0
			_gear(c, Vector2(gx, TOP + 150 + i * 20), 22.0 + i * 6, t * (0.6 if i % 2 == 0 else -0.6), far.darkened(0.25))
	# Clouds.
	if ti != 4 and ti < 7:
		for i in 5:
			var cx := fposmod(i * 97.0 - cam * 0.08 - t * 4.0, 340.0) - 35.0
			var cy := TOP + 40 + (i * 23) % 70
			var cc := Color(1, 1, 1, 0.75 if ti != 6 else 0.15)
			c.draw_circle(Vector2(cx, cy), 9, cc)
			c.draw_circle(Vector2(cx + 10, cy - 4), 11, cc)
			c.draw_circle(Vector2(cx + 22, cy), 8, cc)
			c.draw_rect(Rect2(cx, cy, 22, 8), cc)
	# Near hills.
	var near_c: Color = th[3]
	var pts2 := PackedVector2Array()
	pts2.append(Vector2(0, DECK))
	for sx in range(0, 277, 6):
		var wx2 := sx + cam * 0.4
		var hh2 := 52.0 + 18.0 * sin(wx2 * 0.02 + 1.0) + 8.0 * sin(wx2 * 0.07)
		pts2.append(Vector2(sx, TOP + 300 - hh2))
	pts2.append(Vector2(W, DECK))
	c.draw_colored_polygon(pts2, near_c)


func _gear(c: Control, ctr: Vector2, r: float, a: float, col: Color) -> void:
	c.draw_circle(ctr, r, col)
	for k in 8:
		var aa := a + k * TAU / 8.0
		var d := Vector2(cos(aa), sin(aa))
		c.draw_colored_polygon(PackedVector2Array([ctr + d * r + d.orthogonal() * 4, ctr + d * (r + 6) + d.orthogonal() * 3, ctr + d * (r + 6) - d.orthogonal() * 3, ctr + d * r - d.orthogonal() * 4]), col)
	c.draw_circle(ctr, r * 0.35, col.lightened(0.15))


func _draw_world(c: Control, th: Array, x0: float, x1: float) -> void:
	var gtop: Color = th[4]
	var body: Color = th[5]
	var acc: Color = th[6]
	var view := Rect2(x0, -10, x1 - x0, 350)
	var solids: Array = lv["solids"]
	for i: int in JumperLevels.near(lv, "solids", x0, x1):
		var r: Rect2 = solids[i]
		var v := r.intersection(view)
		if v.size.x <= 0.0:
			continue
		if r.position.y < 0.0:
			# Low ceiling: a hanging slab of the level's own rock (shaded), with
			# hazard stripes along its underside.
			if not _ceiling_body(c, r, v):
				c.draw_rect(v, body.darkened(0.45))
			var by := r.end.y
			c.draw_rect(Rect2(v.position.x, by - 6, v.size.x, 6), Color(0.15, 0.12, 0.1))
			var sx := floorf(v.position.x / 8.0) * 8.0
			while sx < v.end.x:
				var p0 := maxf(sx, v.position.x)
				var p1 := minf(sx + 4.0, v.end.x)
				if p1 > p0:
					c.draw_rect(Rect2(p0, by - 6, p1 - p0, 6), Color(1, 0.8, 0.2))
				sx += 8.0
			c.draw_rect(Rect2(v.position.x, by - 1, v.size.x, 1), Color(0, 0, 0, 0.5))
			_ceiling_art(c, v, by)
			continue
		if _ground_tiles(c, r, v):
			continue
		c.draw_rect(v, body)
		# Speckles (fixed to the world so they scroll with it).
		var cx := floorf(v.position.x / 8.0) * 8.0
		while cx < v.end.x:
			var cy := r.position.y + 8.0
			while cy < minf(v.end.y, r.position.y + 80.0):
				var hsh := (int(cx) * 73856093) ^ (int(cy) * 19349663)
				if hsh % 5 == 0 and cx >= v.position.x:
					c.draw_rect(Rect2(cx + (hsh % 5), cy + (hsh % 3), 2, 2), body.darkened(0.2))
				elif hsh % 7 == 1 and cx >= v.position.x:
					c.draw_rect(Rect2(cx + 3, cy + 2, 1, 1), body.lightened(0.15))
				cy += 8.0
			cx += 8.0
		# Grass/top edge and outlines.
		c.draw_rect(Rect2(v.position.x, r.position.y, v.size.x, 4), gtop)
		c.draw_rect(Rect2(v.position.x, r.position.y, v.size.x, 1), gtop.lightened(0.35))
		c.draw_rect(Rect2(v.position.x, r.position.y + 4, v.size.x, 1), gtop.darkened(0.35))
		if r.position.x >= x0:
			c.draw_rect(Rect2(r.position.x, r.position.y, 1, v.end.y - r.position.y), body.darkened(0.45))
		if r.end.x <= x1:
			c.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, v.end.y - r.position.y), body.darkened(0.45))
	var plats: Array = lv["plats"]
	for i: int in JumperLevels.near(lv, "plats", x0, x1):
		var p: Rect2 = plats[i]
		_plat(c, p, th, false)
	var movers: Array = lv["movers"]
	for i: int in JumperLevels.near(lv, "movers", x0, x1):
		var m: Dictionary = movers[i]
		var mr := JumperLevels.mover_rect(m, float(st[JumperLevels.T]))
		if float(m["ay"]) > 0.0:
			c.draw_line(Vector2(mr.get_center().x, -10), Vector2(mr.get_center().x, mr.position.y), Color(0.3, 0.3, 0.35), 1.0)
		else:
			c.draw_line(Vector2(float(m["x"]) - float(m["ax"]), mr.position.y + 10), Vector2(float(m["x"]) + float(m["w"]) + float(m["ax"]), mr.position.y + 10), Color(0, 0, 0, 0.2), 1.0)
		_plat(c, mr, th, true)
	var spikes: Array = lv["spikes"]
	for i: int in JumperLevels.near(lv, "spikes", x0, x1):
		var k: Rect2 = spikes[i]
		var stx := ArcadeGame.tex("spikes")
		if stx:
			var ssz := Vector2(stx.get_size())
			var part := int(k.position.x / 16.0) % 3
			c.draw_texture_rect_region(stx, Rect2(k.position.x, k.end.y - 14, 16, 14), Rect2(part * ssz.x / 3.0, 0, ssz.x / 3.0, ssz.y))
			continue
		var a := k.position + Vector2(1, 12)
		var b := k.position + Vector2(8, 0)
		var d := k.position + Vector2(15, 12)
		c.draw_colored_polygon(PackedVector2Array([a, b, d]), Color(0.78, 0.8, 0.88))
		c.draw_colored_polygon(PackedVector2Array([a, b, k.position + Vector2(8, 12)]), Color(0.95, 0.96, 1))
		c.draw_polyline(PackedVector2Array([a, b, d, a]), Color(0.2, 0.18, 0.3), 1.0)
	var coins: Array = lv["coins"]
	for i: int in JumperLevels.near(lv, "coins", x0, x1):
		if coins_got.has(i):
			continue
		var cp: Vector2 = coins[i]
		var bob := sin(t * 3.0 + i) * 1.5
		if spr(c, "coin_%d" % (int(t * 9.0 + i) % 4), Rect2(cp.x - 6, cp.y - 6 + bob, 12, 12)):
			continue
		var w := absf(cos(t * 4.0 + i * 0.7)) * 6.0 + 1.0
		c.draw_rect(Rect2(cp.x - w * 0.5 - 0.5, cp.y - 5.5 + bob, w + 1, 11), Color(0.55, 0.35, 0.05))
		c.draw_rect(Rect2(cp.x - w * 0.5, cp.y - 5 + bob, w, 10), Color(1, 0.82, 0.25))
		c.draw_rect(Rect2(cp.x - minf(1.0, w * 0.2), cp.y - 3 + bob, minf(2.0, w * 0.4), 6), Color(1, 0.97, 0.7))
	var checks: Array = lv["checks"]
	for i in checks.size():
		var cpos: Vector2 = checks[i]
		if cpos.x < x0 or cpos.x > x1:
			continue
		var got := i <= check_i
		if spr_h(c, "flag_green" if got else "flag_red", Vector2(cpos.x + 6, cpos.y), 32.0):
			continue
		c.draw_rect(Rect2(cpos.x - 1, cpos.y - 30, 2, 30), Color(0.85, 0.85, 0.9))
		var wave := sin(t * 6.0) * 2.0
		var fc := Color(0.4, 0.95, 0.45) if got else Color(0.95, 0.35, 0.35)
		c.draw_colored_polygon(PackedVector2Array([Vector2(cpos.x + 1, cpos.y - 30), Vector2(cpos.x + 15, cpos.y - 26 + wave), Vector2(cpos.x + 1, cpos.y - 21)]), fc)
	var fx := float(lv["finish"])
	if fx > x0 and fx < x1 + 40:
		var fy := float(lv.get("finish_y", JumperLevels.GY0))
		if spr_h(c, "goal", Vector2(fx + 16.0, fy), 64.0):
			return
		for post in [fx - 4.0, fx + 36.0]:
			c.draw_rect(Rect2(post, fy - 60, 4, 60), Color(0.9, 0.9, 0.95))
		for k in 10:
			for row in 2:
				var col := Color.WHITE if (k + row) % 2 == 0 else Color(0.1, 0.1, 0.15)
				c.draw_rect(Rect2(fx + k * 4, fy - 60 + row * 4, 4, 4), col)
		text_outline(c, Vector2(fx - 10, fy - 66), "GOAL", 60, 9, acc, HORIZONTAL_ALIGNMENT_CENTER)


## Ground blocks from the theme's painted tiles: a 32 px top row, 16 px body rows,
## fixed to world multiples of 32 so they scroll with it.
func _ground_tiles(c: Control, r: Rect2, v: Rect2) -> bool:
	var ti := _theme_i()
	var top := ArcadeGame.tex("ground_%d" % ti)
	var body := ArcadeGame.tex("ground_body_%d" % ti)
	if top == null or body == null:
		return false
	var tsz := Vector2(top.get_size())   # 64x64 -> 32x32
	var bsz := Vector2(body.get_size())  # 64x32 -> 32x16
	var cx := floorf(v.position.x / 32.0) * 32.0
	while cx < v.end.x:
		var x0 := maxf(cx, v.position.x)
		var x1 := minf(cx + 32.0, v.end.x)
		if x1 > x0:
			var sx := (x0 - cx) * tsz.x / 32.0
			var sw := (x1 - x0) * tsz.x / 32.0
			var th := minf(32.0, r.size.y)
			c.draw_texture_rect_region(top, Rect2(x0, r.position.y, x1 - x0, th), Rect2(sx, 0, sw, th * tsz.y / 32.0))
			var y := r.position.y + 32.0
			while y < minf(r.end.y, v.end.y):
				var bh := minf(16.0, r.end.y - y)
				c.draw_texture_rect_region(body, Rect2(x0, y, x1 - x0, bh), Rect2(sx, 0, sw, bh * bsz.y / 16.0))
				y += 16.0
		cx += 32.0
	if r.position.x >= v.position.x:
		c.draw_rect(Rect2(r.position.x, r.position.y, 1, v.end.y - r.position.y), Color(0, 0, 0, 0.35))
	if r.end.x <= v.end.x:
		c.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, v.end.y - r.position.y), Color(0, 0, 0, 0.35))
	return true


## A ceiling's body from the theme's ground tiles, darker toward the top, with
## shaded side edges so it reads as a slab hanging into the run.
func _ceiling_body(c: Control, r: Rect2, v: Rect2) -> bool:
	var tx := ArcadeGame.tex("ground_body_%d" % _theme_i())
	if tx == null:
		return false
	var bsz := Vector2(tx.get_size())
	var by := r.end.y
	var cx := floorf(v.position.x / 32.0) * 32.0
	while cx < v.end.x:
		var x0 := maxf(cx, v.position.x)
		var x1 := minf(cx + 32.0, v.end.x)
		if x1 > x0:
			var sx := (x0 - cx) * bsz.x / 32.0
			var sw := (x1 - x0) * bsz.x / 32.0
			var y := by
			while y > v.position.y:
				var y0 := maxf(y - 16.0, v.position.y)
				var k := clampf((by - y) / 160.0, 0.0, 1.0)
				var col := Color(0.62, 0.6, 0.68).lerp(Color(0.3, 0.28, 0.36), k)
				c.draw_texture_rect_region(tx, Rect2(x0, y0, x1 - x0, y - y0), Rect2(sx, 0, sw, (y - y0) * bsz.y / 16.0), col)
				y -= 16.0
		cx += 32.0
	if r.position.x >= v.position.x:
		c.draw_rect(Rect2(r.position.x, v.position.y, 2, by - v.position.y), Color(0, 0, 0, 0.4))
	if r.end.x <= v.end.x:
		c.draw_rect(Rect2(r.end.x - 2, v.position.y, 2, by - v.position.y), Color(0, 0, 0, 0.4))
	return true


## The painted stone-and-hazard band along a low ceiling's underside.
func _ceiling_art(c: Control, v: Rect2, by: float) -> void:
	var tx := ArcadeGame.tex("ceiling")
	if tx == null:
		return
	var sz := Vector2(tx.get_size())
	var h := 24.0
	var seg := sz.x * h / sz.y
	var x := v.position.x
	while x < v.end.x:
		var w := minf(seg, v.end.x - x)
		c.draw_texture_rect_region(tx, Rect2(x, by - h, w, h), Rect2(0, 0, w * sz.x / seg, sz.y))
		x += seg


## A 3-slice strip (caps keep their shape, the middle stretches).
func _slice3(c: Control, name: String, r: Rect2, cap := 6.0) -> bool:
	var tx := ArcadeGame.tex(name)
	if tx == null:
		return false
	var sz := Vector2(tx.get_size())
	var sc := sz.y / r.size.y
	var cw := minf(cap, r.size.x * 0.5)
	c.draw_texture_rect_region(tx, Rect2(r.position, Vector2(cw, r.size.y)), Rect2(0, 0, cw * sc, sz.y))
	c.draw_texture_rect_region(tx, Rect2(r.position.x + cw, r.position.y, r.size.x - 2 * cw, r.size.y), Rect2(cw * sc, 0, sz.x - 2 * cw * sc, sz.y))
	c.draw_texture_rect_region(tx, Rect2(r.end.x - cw, r.position.y, cw, r.size.y), Rect2(sz.x - cw * sc, 0, cw * sc, sz.y))
	return true


func _plat(c: Control, r: Rect2, th: Array, metal: bool) -> void:
	if _slice3(c, "mover" if metal else "plank", Rect2(r.position.x, r.position.y - 1, r.size.x, 10)):
		return
	var ti := int(JumperLevels.level_def(level)["theme"]) if level > 0 else -1
	if metal:
		c.draw_rect(r, Color(0.55, 0.58, 0.65))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.8, 0.83, 0.9))
		c.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), (th[6] as Color))
		var rx := r.position.x + 4
		while rx < r.end.x - 2:
			c.draw_rect(Rect2(rx, r.position.y + 3, 1, 1), Color(0.3, 0.3, 0.35))
			rx += 8
		c.draw_rect(r, Color(0.2, 0.2, 0.28), false, 1.0)
	elif ti == 3:
		for k in int(r.size.x / 10.0) + 1:
			c.draw_circle(Vector2(r.position.x + 4 + k * 10, r.position.y + 4), 5, Color(1, 1, 1))
		c.draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, 6), Color(1, 1, 1))
		c.draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, 2), Color(0.8, 0.85, 1))
	else:
		c.draw_rect(r, Color(0.72, 0.5, 0.3))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(0.9, 0.7, 0.45))
		var px := r.position.x + 8
		while px < r.end.x:
			c.draw_rect(Rect2(px, r.position.y + 1, 1, r.size.y - 1), Color(0.5, 0.33, 0.2))
			px += 10
		c.draw_rect(r, Color(0.35, 0.22, 0.12), false, 1.0)


func _draw_player(c: Control, off: Vector2) -> void:
	if dead_t > 0.0:
		return
	var x := float(st[JumperLevels.X])
	var y := float(st[JumperLevels.Y])
	var h := float(st[JumperLevels.HGT])
	var blink := intro_t > 0.0 and intro_t < 0.9 and int(t * 12.0) % 2 == 0 and lives < 3
	for i in trail.size():
		var tp: Vector2 = trail[i]
		var a := (i + 1) / float(trail.size() + 1) * 0.35
		c.draw_rect(Rect2(tp - Vector2(5, 5), Vector2(10, 10)), Color(accent, a))
	if blink:
		return
	var pose := 0
	if h == JumperLevels.H_DUCK:
		pose = 4
	elif int(st[JumperLevels.GND]) == 0:
		pose = 3
	elif state == "play" and intro_t <= 0.5:
		pose = 1 + int(t * 10.0) % 2
	var ptx := ArcadeGame.tex("hero_%d" % pose)
	if ptx:
		var psz := Vector2(ptx.get_size())
		var ph := 19.0 if pose != 4 else 13.0
		var pw := psz.x * ph / psz.y
		var tilt := 0.0
		if pose == 3:
			tilt = clampf(float(st[JumperLevels.VY]) / 900.0, -0.25, 0.35)
		c.draw_set_transform(off + Vector2(x, y), tilt, squash)
		c.draw_texture_rect(ptx, Rect2(-pw * 0.5, -ph, pw, ph), false)
		c.draw_set_transform(off)
		return
	var ctr := Vector2(x, y - h * 0.5)
	var sq := squash
	if h == JumperLevels.H_DUCK:
		sq = Vector2(1.15, 1.0)
	c.draw_set_transform(off + ctr + Vector2(0, h * 0.5 * (1.0 - sq.y)), rot if int(st[JumperLevels.GND]) == 0 else 0.0, sq)
	var hw := 6.0
	var hh := h * 0.5
	c.draw_rect(Rect2(-hw - 1, -hh - 1, hw * 2 + 2, hh * 2 + 2), accent.darkened(0.6))
	c.draw_rect(Rect2(-hw, -hh, hw * 2, hh * 2), accent)
	c.draw_rect(Rect2(-hw, -hh, hw * 2, 2), accent.lightened(0.4))
	c.draw_rect(Rect2(-hw, hh - 2, hw * 2, 2), accent.darkened(0.25))
	# Face looks ahead; squints when ducking.
	var ey := -hh + (2.0 if h == JumperLevels.H_DUCK else 3.0)
	var eh := 1.0 if h == JumperLevels.H_DUCK else 3.0
	c.draw_rect(Rect2(0, ey, 3, eh), Color.WHITE)
	c.draw_rect(Rect2(4, ey, 2, eh), Color.WHITE)
	c.draw_rect(Rect2(1.5, ey + (0.0 if eh < 2 else 1.0), 1.5, minf(eh, 2.0)), Color(0.05, 0.05, 0.1))
	c.draw_rect(Rect2(4.5, ey + (0.0 if eh < 2 else 1.0), 1.5, minf(eh, 2.0)), Color(0.05, 0.05, 0.1))
	if h != JumperLevels.H_DUCK:
		c.draw_rect(Rect2(1, ey + 6, 4, 1), accent.darkened(0.5))


func _draw_hud(c: Control, th: Array) -> void:
	for i in 3:
		_heart(c, Vector2(8 + i * 11, 30), i < lives)
	var coins_all: int = (lv["coins"] as Array).size()
	c.draw_rect(Rect2(214, 29, 6, 8), Color(1, 0.82, 0.25))
	c.draw_rect(Rect2(216, 31, 2, 4), Color(1, 0.97, 0.7))
	text_outline(c, Vector2(224, 37), "%d" % coins_got.size() if level <= 0 else "%d/%d" % [coins_got.size(), coins_all], 44, 8, Color.WHITE)
	if level > 0:
		var bar := Rect2(48, 30, 160, 6)
		c.draw_rect(bar, Color(0, 0, 0, 0.45))
		var f := clampf(float(st[JumperLevels.X]) / float(lv["finish"]), 0.0, 1.0)
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(best_x / float(lv["finish"]), 0, 1), bar.size.y)), Color(accent, 0.35))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), accent)
		for cp: Vector2 in lv["checks"]:
			var cx := bar.position.x + bar.size.x * cp.x / float(lv["finish"])
			c.draw_rect(Rect2(cx - 1, bar.position.y - 2, 2, bar.size.y + 4), Color(0.5, 1, 0.5))
		c.draw_rect(Rect2(bar.end.x - 2, bar.position.y - 2, 3, bar.size.y + 4), Color.WHITE)
	else:
		text_outline(c, Vector2(48, 37), "%d m · speed %d" % [int(best_x / 16.0), int(JumperLevels.speed_at(lv, best_x))], 160, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if intro_t > 0.0 and state == "play":
		var name_s := "LEVEL %d" % level if level > 0 else "ENDLESS"
		if lives < 3 and best_x > 0.0:
			name_s = "READY"
		var go := intro_t <= 0.5
		text_outline(c, Vector2(0, 150), "GO!" if go else name_s, W, 22 if go else 18, th[6] if not go else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if not go and name_s != "READY":
			text_outline(c, Vector2(0, 170), str(JumperLevels.level_def(level)["name"]), W, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if dead_t > 0.7:
		c.draw_rect(PLAY, Color(1, 0.2, 0.2, (dead_t - 0.7) * 0.8))
	if win_t > 0.0:
		text_outline(c, Vector2(0, 140), "LEVEL CLEAR!", W, 18, Color(1, 0.95, 0.4), HORIZONTAL_ALIGNMENT_CENTER)


func _heart(c: Control, p: Vector2, full: bool) -> void:
	var col := Color(1, 0.3, 0.4) if full else Color(0.25, 0.2, 0.3)
	c.draw_rect(Rect2(p + Vector2(1, 0), Vector2(3, 2)), col)
	c.draw_rect(Rect2(p + Vector2(5, 0), Vector2(3, 2)), col)
	c.draw_rect(Rect2(p + Vector2(0, 1), Vector2(9, 3)), col)
	c.draw_rect(Rect2(p + Vector2(1, 4), Vector2(7, 2)), col)
	c.draw_rect(Rect2(p + Vector2(3, 6), Vector2(3, 1)), col)
	if full:
		c.draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 1)), Color(1, 0.8, 0.85))


func _draw_select(c: Control) -> void:
	c.draw_rect(PLAY, Color(0.06, 0.1, 0.18))
	for i in 30:
		var sx := fposmod(i * 53.0 + t * (6 + i % 4), W)
		var sy := TOP + fposmod(i * 41.0, 328.0)
		c.draw_rect(Rect2(sx, sy, 2, 2), Color(accent, 0.15))
	cover(c, "bg_night", PLAY, 0.5, Color(0.55, 0.6, 0.8))
	text_outline(c, Vector2(0, 42), "SELECT LEVEL", W, 11, accent, HORIZONTAL_ALIGNMENT_CENTER)
	for i in JumperLevels.LEVELS.size() + 1:
		var n := level_for_tile(i)
		var r := _tile(i)
		var open := is_unlocked(n)
		var th := JumperLevels.theme(n) if n > 0 else JumperLevels.THEMES[7]
		var on := i == sel
		var bgname := "bg_" + str(BG[int(JumperLevels.level_def(n)["theme"])] if n > 0 else "space")
		if open and cover(c, bgname, r, 0.6):
			pass
		elif open:
			for k in 10:
				c.draw_rect(Rect2(r.position.x, r.position.y + k * r.size.y / 10.0, r.size.x, r.size.y / 10.0 + 1), (th[0] as Color).lerp(th[1], k / 9.0))
			c.draw_rect(Rect2(r.position.x, r.end.y - 16, r.size.x, 16), th[5])
			c.draw_rect(Rect2(r.position.x, r.end.y - 16, r.size.x, 3), th[4])
		else:
			c.draw_rect(r, Color(0.14, 0.14, 0.2))
		c.draw_rect(r, accent if on else Color(0.3, 0.35, 0.5), false, 2.0 if on else 1.0)
		if on:
			c.draw_rect(r.grow(3), Color(accent, 0.35 + 0.3 * sin(t * 6.0)), false, 1.0)
		if not open:
			_lock(c, r.get_center() + Vector2(0, -6))
			text(c, Vector2(r.position.x, r.end.y - 8), "LOCKED", r.size.x, 7, Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var big := str(n) if n > 0 else "∞"
		text_outline(c, Vector2(r.position.x, r.position.y + 28), big, r.size.x, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var nm := str(JumperLevels.level_def(n)["name"])
		text_outline(c, Vector2(r.position.x, r.position.y + 42), nm, r.size.x, 7, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var bst := best(n)
		var line := ("%d%%" % bst if n > 0 else "%d m" % bst) if bst > 0 else "new"
		text_outline(c, Vector2(r.position.x, r.end.y - 4), line, r.size.x, 8, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		if n > 0 and cleared(n):
			_star(c, r.position + Vector2(r.size.x - 10, 9), Color(1, 0.85, 0.2))
		if n > 0:
			var lvc := int(_jd()["coins"].get(str(n), 0))
			if lvc > 0:
				text_outline(c, r.position + Vector2(3, 10), "●%d" % lvc, 40, 7, Color(1, 0.85, 0.3))
	var n2 := level_for_tile(sel)
	var info := "A: play · %s" % Money.amount(fee)
	if not is_unlocked(n2):
		info = "Clear level %d to unlock" % (maxi(1, n2 - 1))
	text(c, Vector2(0, 312), info, W, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(0, 326), "Double jump: ON (A in mid-air)" if double_jump() else "Clear level 4 for a double jump", W, 7, Color(0.7, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(0, 338), "Tap JUMP or the picture · hold = higher · ▼ ducks", W, 7, Color(0.7, 0.75, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


func _lock(c: Control, p: Vector2) -> void:
	c.draw_arc(p + Vector2(0, -4), 6, PI, TAU, 12, Color(0.75, 0.75, 0.8), 2.0)
	c.draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 12)), Color(0.85, 0.7, 0.3))
	c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 4)), Color(0.2, 0.15, 0.1))


func _star(c: Control, p: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var r := 6.0 if k % 2 == 0 else 2.6
		var a := -PI / 2 + k * PI / 5
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, col)
