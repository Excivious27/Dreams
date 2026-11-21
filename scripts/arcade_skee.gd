class_name ArcadeSkee
extends ArcadeGame
## Skee-Ball (the Rec Center's lane by the stairs): nine balls up a maple ramp.
## ◀ ▶ (or a tap on the lane) picks your line; hold ROLL and the power meter
## climbs and falls; let go to roll. Soft balls die on the ramp (0), the board
## pays 10, the outer ring 20, the inner ring 30, the collar round the cup 40, a
## firm centred roll finds the 50 cup, and the corner cups (100) need a line near
## the bumper AND a strong roll. Overshoot hits the net (10).
##
## Geometry lives in the 1024-wide source coordinates of art/gen/arcade/stage_skee
## (tools/slice_r13_c2_04.py); `scr()` maps them to the screen. Tests call
## throw(u, p) directly; zone_at(x, y) is the scoring rule.

const FEE := 10
const BALLS := 9
const K := 270.0 / 1024.0          # source px -> screen px
const START_Y := 1170.0            # ball rests here (source y)
const LIP_Y := 600.0               # the hop
const BOARD_TOP := 110.0           # above this: the net
const BOARD_BOT := 575.0           # below this the ball never cleared the hop
const P_MIN := 0.18                # weaker rolls die on the ramp
const P_NET := 0.92                # stronger rolls hit the net
const SWEEP := 0.85                # seconds for the meter to climb 0 -> 1
const U_MAX := 0.9
## Scoring zones: [points, centre, radii], tested in order (cups first).
const ZONES := [
	[100, Vector2(304, 181), Vector2(40, 24)],
	[100, Vector2(720, 181), Vector2(40, 24)],
	[50, Vector2(512, 268), Vector2(44, 26)],
	[40, Vector2(512, 276), Vector2(74, 46)],    # the collar round the 50 cup
	[30, Vector2(506, 330), Vector2(104, 84)],   # inside the inner ring
	[20, Vector2(505, 349), Vector2(207, 182)],  # inside the outer ring
]

const METER_COL := {0: Color(0.3, 0.3, 0.35), 10: Color(0.3, 0.45, 0.85), 20: Color(0.3, 0.75, 0.95), 30: Color(0.3, 0.85, 0.45), 40: Color(0.75, 0.9, 0.3), 50: Color(1, 0.8, 0.25), 100: Color(1, 0.4, 0.85)}

var u := 0.0            # line across the lane, -1..1
var power := 0.0
var charging := false
var charge_t := 0.0
var balls := BALLS
var phase := "aim"      # aim | roll | air | settle | back | wait
var phase_t := 0.0
var ball := Vector2(512, START_Y)   # source coordinates
var lift := 0.0                     # arc height above the board (source px)
var shot_u := 0.0
var shot_p := 0.0
var land := Vector2.ZERO
var land_pts := 0
var sink := Vector2.ZERO            # where the ball settles (cup / ring bottom)
var counts := {}                    # points -> balls
var flash_zone := -1
var flash_t := 0.0
var history: Array = []             # points per ball this game


func _init() -> void:
	super()
	game_id = "skee_ball"
	title = Tickets.game_name("skee_ball")  # Snowball Roll / Alley Roll (no real brand names)
	fee = FEE
	accent = Color(1.0, 0.45, 0.35)
	howto = ["◀ ▶ (or tap the lane) pick your line", "Hold ROLL, let go at the right power", "Rings 10 to 50 · corner cups 100", "Nine balls a game."]


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(10, 384, 52, 52), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(74, 384, 52, 52), "label": "▶", "skin": "blue"},
		{"action": "a", "rect": Rect2(192, 372, 70, 70), "label": "ROLL", "skin": "gold", "hint": "hold, let go"},
		{"action": "b", "rect": Rect2(146, 430, 36, 36), "label": "B", "skin": "red", "hint": "leave"},
	]


## Arcade luck: gear luck plus an active luck buff (the snack bar's popcorn).
static func luck() -> float:
	return float(GameState.gear_stat("luck")) + GameState.buff("luck")


# --- geometry -----------------------------------------------------------------

static func scr(p: Vector2) -> Vector2:
	return Vector2(p.x * K, TOP + p.y * K)


## Half width of the ramp at a source y (straight perspective edges).
static func ramp_hw(y: float) -> float:
	return 288.0 + (y - 660.0) * 0.331


static func board_hw(y: float) -> float:
	return 262.0 + (y - 240.0) * 0.135


## Ball radius (source px) at a source y.
static func ball_r(y: float) -> float:
	return 30.0 * clampf(ramp_hw(maxf(y, 300.0)) / ramp_hw(START_Y), 0.45, 1.0)


## Where a roll of line u and power p lands on the board (source coords); y > BOARD_BOT = never got there.
static func landing(lu: float, p: float) -> Vector2:
	if p < P_MIN:
		return Vector2(512 + lu * ramp_hw(LIP_Y + 200), BOARD_BOT + 400.0 * (P_MIN - p) / P_MIN + 1.0)
	var y := BOARD_BOT - (p - P_MIN) / (P_NET - P_MIN) * (BOARD_BOT - BOARD_TOP)
	return Vector2(512.0 + lu * board_hw(y), y)


## The power that lands a ball at source y (the inverse of landing()).
static func p_for(y: float) -> float:
	return P_MIN + (BOARD_BOT - y) / (BOARD_BOT - BOARD_TOP) * (P_NET - P_MIN)


## Points for a landing point: [points, zone index (-1 board, -2 net, -3 dead)].
static func zone_at(p: Vector2) -> Array:
	if p.y > BOARD_BOT:
		return [0, -3]
	if p.y < BOARD_TOP:
		return [10, -2]
	for i in ZONES.size():
		var z: Array = ZONES[i]
		var d := (p - (z[1] as Vector2)) / (z[2] as Vector2)
		if d.length_squared() <= 1.0:
			return [int(z[0]), i]
	return [10, -1]


# --- rounds -------------------------------------------------------------------

func _setup_round() -> void:
	u = 0.0
	balls = BALLS
	counts = {}
	history = []
	_next_ball()


func _next_ball() -> void:
	phase = "aim"
	phase_t = 0.0
	charging = false
	power = 0.0
	ball = Vector2(512 + u * ramp_hw(START_Y), START_Y)
	lift = 0.0


func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0


## Roll the ball now with line lu and power p (a small human wobble is added).
func throw(lu: float, p: float) -> void:
	if state != "play" or phase != "aim" or balls <= 0:
		return
	var steady := clampf(1.0 - 0.15 * luck(), 0.5, 1.0) if duel_sid == "" else 1.0  # duels: gear never decides (c17_06-14)
	# Harder rolls wander more: a soft line is easy, a corner-cup rocket is not.
	shot_u = clampf(lu + rng.randfn(0.0, (0.03 + 0.05 * p) * steady), -1.0, 1.0)
	shot_p = clampf(p + rng.randfn(0.0, 0.02 * steady), 0.0, 1.0)
	balls -= 1
	charging = false
	land = landing(shot_u, shot_p)
	var z := zone_at(land)
	land_pts = int(z[0])
	flash_zone = int(z[1])
	sink = _sink_for(land, flash_zone)
	ball = Vector2(512 + shot_u * ramp_hw(START_Y), START_Y)
	sfx("skee_roll", "bowl_roll")
	_set_phase("roll")


func _sink_for(p: Vector2, zone: int) -> Vector2:
	if zone >= 0 and zone <= 2:
		return ZONES[zone][1]
	if zone == 3:  # the collar funnels into the cup
		return ZONES[2][1]
	if zone == 4:
		return Vector2(p.x * 0.4 + 506 * 0.6, 392)
	if zone == 5:
		return Vector2(p.x * 0.5 + 505 * 0.5, 505)
	return Vector2(p.x, 560)


func _roll_time() -> float:
	return 0.62 - 0.22 * clampf(shot_p, 0.0, 1.0)


func _step(dt: float) -> void:
	phase_t += dt
	flash_t = maxf(0.0, flash_t - dt)
	match phase:
		"aim":
			var dir := (1.0 if held("right") else 0.0) - (1.0 if held("left") else 0.0)
			if not charging:
				u = clampf(u + dir * 0.9 * dt, -U_MAX, U_MAX)
				ball = Vector2(512 + u * ramp_hw(START_Y), START_Y)
			if held("a"):
				if not charging:
					charging = true
					charge_t = 0.0
				charge_t += dt
				var k := fmod(charge_t / SWEEP, 2.0)
				power = k if k <= 1.0 else 2.0 - k
				if int(charge_t * 12.0) != int((charge_t - dt) * 12.0):
					sfx("scroll_tick", "ui_tap")
			elif charging:
				throw(u, power)
			elif pressed("b"):
				_finish(true)
		"roll":
			var f := clampf(phase_t / _roll_time(), 0.0, 1.0)
			var e := 1.0 - (1.0 - f) * (1.0 - f) * 0.4 - (1.0 - f) * 0.6  # eases out a little
			if land.y > BOARD_BOT:
				# Too soft: it climbs part way, stalls and rolls back.
				var top := LIP_Y + 60.0 + (land.y - BOARD_BOT) * 0.9
				ball.y = lerpf(START_Y, top, e)
				ball.x = 512 + shot_u * ramp_hw(ball.y)
				if f >= 1.0:
					_set_phase("back")
			else:
				ball.y = lerpf(START_Y, LIP_Y, e)
				ball.x = 512 + shot_u * ramp_hw(ball.y)
				if f >= 1.0:
					sfx("pop", "thud")
					_set_phase("air")
		"air":
			var dur := 0.28 + 0.22 * clampf(shot_p, 0.0, 1.0)
			var f2 := clampf(phase_t / dur, 0.0, 1.0)
			var from := Vector2(512 + shot_u * ramp_hw(LIP_Y), LIP_Y)
			var to := land if land.y >= BOARD_TOP else Vector2(land.x, BOARD_TOP - 30.0)
			ball = from.lerp(to, f2)
			lift = sin(f2 * PI) * (50.0 + 90.0 * shot_p)
			if f2 >= 1.0:
				lift = 0.0
				if land.y < BOARD_TOP:
					sfx("thud", "drop")
					shake(1.0)
					say("Off the net!", 0.9)
				else:
					sfx("thud", "drop")
				_set_phase("settle")
		"settle":
			var f3 := clampf(phase_t / 0.45, 0.0, 1.0)
			var start := land if land.y >= BOARD_TOP else Vector2(land.x, BOARD_TOP - 30.0)
			ball = start.lerp(sink, f3 * f3)
			if f3 >= 1.0:
				_score_ball()
				_set_phase("wait")
		"back":
			var f4 := clampf(phase_t / 0.6, 0.0, 1.0)
			var top2 := LIP_Y + 60.0 + (land.y - BOARD_BOT) * 0.9
			ball.y = lerpf(top2, START_Y + 60.0, f4 * f4)
			ball.x = 512 + shot_u * ramp_hw(ball.y)
			if f4 >= 1.0:
				_score_ball()
				_set_phase("wait")
		"wait":
			if phase_t >= 0.35:
				if balls <= 0:
					_finish(false)
				else:
					_next_ball()


func _score_ball() -> void:
	var pts := land_pts
	history.append(pts)
	counts[pts] = int(counts.get(pts, 0)) + 1
	score += pts
	flash_t = 0.6 if pts > 0 else 0.0
	var at := scr(sink) + Vector2(0, -10)
	if pts == 0:
		say("Too soft! It never made the hop.", 1.2)
		sfx("nope", "drop")
		return
	float_text(at, "+%d" % pts, Color(1, 0.95, 0.5) if pts < 100 else Color(1, 0.6, 1))
	if pts >= 100:
		burst(at, Color(1, 0.85, 0.3), 26, 120.0)
		burst(at, Color(1, 0.5, 0.9), 14, 90.0)
		shake(2.0)
		sfx("j_treasure", "coin")
		say("CORNER CUP! 100!", 1.2)
		ArcadeHub.set_milestone("skee_cup")
	elif pts >= 50:
		burst(at, Color(1, 0.9, 0.4), 16, 90.0)
		point_sfx()
	else:
		burst(at, Color(1, 0.95, 0.8), 6, 50.0)
		sfx("drop", "thud")


func _finish(quit: bool) -> void:
	var parts: Array = []
	for pts in [100, 50, 40, 30, 20, 10]:
		if int(counts.get(pts, 0)) > 0:
			parts.append("%dx%d" % [int(counts[pts]), pts])
	var head := "!GAME ENDED" if quit else ("!SKEE-RIFIC!" if score >= 300 else "!NINE BALLS")
	game_over([head, " · ".join(parts) if not parts.is_empty() else "No points this time.", "300 or more earns 3 bonus tickets."])


func _tickets_for(s: int) -> int:
	# ~1.2 tickets per crystal for a casual game, ~2.5 for an expert (in line with the cabinets).
	return s / 20 + int(counts.get(100, 0)) + (3 if s >= 300 else 0)


## A lane in the room: the room's song (the jukebox record) plays on.
func _start_music() -> void:
	pass


## A good Skee game pays about 8 (s/20 + cups; gen_rec's pacing sim: 4-6 typical).
func _good_tickets() -> int:
	return 8


func _tap(p: Vector2) -> void:
	if state != "play" or phase != "aim" or charging:
		return
	if p.y > 240.0:
		var sy := START_Y
		u = clampf((p.x / K - 512.0) / ramp_hw(sy), -U_MAX, U_MAX)
		ball = Vector2(512 + u * ramp_hw(sy), sy)
		sfx("scroll_tick", "ui_tap")


func _top_right() -> String:
	return "%d" % score if state != "title" else super()


# --- drawing ------------------------------------------------------------------

func _draw_stage(c: Control, r: Rect2) -> bool:
	var tx := tex("stage_skee")
	if tx == null:
		return false
	var k := Vector2(tx.get_size()).x / 1024.0
	c.draw_texture_rect_region(tx, r, Rect2(0, 0, 1024.0 * k, (r.size.y / K) * k))
	return true


func _draw_play(c: Control) -> void:
	if not _draw_stage(c, PLAY):
		c.draw_rect(PLAY, Color(0.75, 0.55, 0.3))
		c.draw_rect(Rect2(PLAY.position, Vector2(W, 150)), Color(0.15, 0.25, 0.6))
	# Lit zone after a score.
	if flash_t > 0.0 and flash_zone >= 0:
		var z: Array = ZONES[flash_zone]
		var a := flash_t / 0.6
		_ellipse(c, scr(z[1]), (z[2] as Vector2) * K, Color(1, 0.95, 0.5, 0.8 * a), 2.0)
		_ellipse(c, scr(z[1]), (z[2] as Vector2) * K * 1.1, Color(1, 0.6, 0.9, 0.5 * a), 1.0)
	# The LED score panel on the cabinet.
	var led := Rect2(99, 29, 72, 19)
	c.draw_rect(led, Color(0.05, 0.02, 0.03, 0.85))
	text_outline(c, Vector2(led.position.x, led.position.y + 15), "%03d" % score, led.size.x, 14, Color(1, 0.3, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	# Aim guide + power meter while aiming.
	if state == "play" and phase == "aim":
		var y := START_Y - 60.0
		while y > LIP_Y + 20.0:
			var p := scr(Vector2(512 + u * ramp_hw(y), y))
			c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 3)), Color(1, 1, 1, 0.35))
			y -= 46.0
		_draw_meter(c)
	# The ball.
	if state == "play" and phase != "wait":
		var shrink := 1.0
		if phase == "settle" and land_pts >= 40:
			shrink = 1.0 - clampf(phase_t / 0.45, 0.0, 1.0) * 0.7
		var br := ball_r(ball.y) * K * shrink
		var ground := scr(ball)
		if lift > 0.0:
			c.draw_circle(ground + Vector2(0, br * 0.6), br * 0.8, Color(0, 0, 0, 0.25))
		_ball(c, ground - Vector2(0, lift * K), br)
	# Balls still to roll, in the return tray.
	for i in balls - (1 if state == "play" and phase == "aim" else 0):
		_ball(c, Vector2(16 + i * 11, 344), 4.5)
	if state == "play":
		text_outline(c, Vector2(150, 348), "Balls %d" % balls, 112, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_fx(c)


func _draw_meter(c: Control) -> void:
	var r := Rect2(250, 190, 12, 140)
	c.draw_rect(r.grow(2), Color(0.05, 0.03, 0.08, 0.85))
	# The meter is painted with what each power scores on your current line
	# (sampled from the real scoring rule), so it teaches the board.
	var n := 70
	for i in n:
		var p0 := float(i) / n
		var pts := int(zone_at(landing(u, p0 + 0.5 / n))[0])
		var y0 := r.end.y - float(i + 1) / n * r.size.y
		c.draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / n + 0.5), Color(METER_COL.get(pts, Color(0.35, 0.35, 0.4)) as Color, 0.6))
	# Label the bands at their middle, left of the meter (thin ones only when they pay big).
	var i0 := 0
	while i0 < n:
		var pv := int(zone_at(landing(u, (i0 + 0.5) / n))[0])
		var i1 := i0
		while i1 + 1 < n and int(zone_at(landing(u, (i1 + 1.5) / n))[0]) == pv:
			i1 += 1
		if pv >= 40 or (pv >= 10 and i1 - i0 >= 4):
			var ym := r.end.y - (i0 + i1 + 1) * 0.5 / n * r.size.y
			text_outline(c, Vector2(r.position.x - 24, ym + 3), str(pv), 21, 7, METER_COL[pv], HORIZONTAL_ALIGNMENT_RIGHT)
		i0 = i1 + 1
	if charging:
		var py := r.end.y - power * r.size.y
		c.draw_rect(Rect2(r.position.x, py, r.size.x, r.end.y - py), Color(1, 1, 1, 0.35))
		c.draw_rect(Rect2(r.position.x - 3, py - 1, r.size.x + 6, 3), Color.WHITE)
	text(c, Vector2(r.position.x - 30, r.position.y - 4), "POWER", 72, 6, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)


func _ball(c: Control, p: Vector2, r: float) -> void:
	var tx := tex("skee_ball_ball")
	if tx:
		c.draw_texture_rect(tx, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false)
		return
	c.draw_circle(p, r, Color(0.35, 0.18, 0.08))
	c.draw_circle(p, r - 1.0, Color(0.78, 0.5, 0.25))
	c.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 0.95, 0.85, 0.8))


func _ellipse(c: Control, ctr: Vector2, rad: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(ctr + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	c.draw_polyline(pts, col, w, true)


func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.15, 0.2, 0.5))
	var tx := tex("stage_skee")
	if tx:
		# The board end of the lane, cropped to the box.
		var k := Vector2(tx.get_size()).x / 1024.0
		var src_h := 1024.0 * r.size.y / r.size.x
		c.draw_texture_rect_region(tx, r, Rect2(0, 60.0 * k, 1024.0 * k, src_h * k))
		var bx := r.position.x + r.size.x * 0.5 + sin(t * 1.3) * 30.0
		var by := r.end.y - 14.0 - absf(sin(t * 2.6)) * 30.0
		_ball(c, Vector2(bx, by), 7.0)
	else:
		draw_cabinet(c, r)
