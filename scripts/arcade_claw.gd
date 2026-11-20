class_name ArcadeClaw
extends ArcadeGame
## Claw Machine: steer the claw with ◀ ▶ (12 seconds), A drops it. Centre it on
## a plush and it may hold on all the way to the chute: each plush carries a
## real prize. The machine's grip loosens a little after every win that day
## (it resets overnight, not by walking out and back in), so luck runs out.

const FEE := 20
const BOX := Rect2(16, 44, 238, 262)
const FLOOR_Y := 296.0
const CHUTE := Rect2(18, 236, 44, 60)
const TOP_Y := 58.0
const AIM_T := 12.0
## Prize item ids and weights (all existing items; plush shapes are just looks).
const POOL := [["rp_teddy", 14], ["rp_penguin_plush", 14], ["rp_fuzzy_dice", 14], ["rp_cat_plush", 14], ["candy", 16], ["toy", 12], ["gift_red", 8], ["old_coin", 8], ["map_scrap", 5], ["fossil", 4], ["pearl", 2], ["amethyst", 2], ["gift_gold", 1]]
const LOOKS := ["bear", "penguin", "star", "duck", "blob", "bunny"]
const LOOK_COL := {"bear": Color(0.75, 0.52, 0.32), "penguin": Color(0.2, 0.22, 0.3), "star": Color(1, 0.85, 0.3), "duck": Color(1, 0.9, 0.35), "blob": Color(0.55, 0.85, 1.0), "bunny": Color(1, 0.75, 0.85)}

static var pile: Array = []

var claw := Vector2(150, TOP_Y)
var phase := "aim"
var phase_t := 0.0
var open_amt := 1.0
var held_i := -1
var grip := 0.0
var won_item := ""
var aim_left := AIM_T


func _init() -> void:
	super()
	game_id = "claw"
	title = "Claw Machine"
	fee = FEE
	accent = Color(1.0, 0.5, 0.72)
	howto = ["◀ ▶ steer the claw · A drop", "Centre it on a plush for a good grip.", "Every plush hides a real prize!", "12 seconds to aim."]


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(10, 384, 52, 52), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(74, 384, 52, 52), "label": "▶", "skin": "blue"},
		{"action": "a", "rect": Rect2(192, 372, 70, 70), "label": "DROP", "skin": "gold"},
		{"action": "b", "rect": Rect2(146, 430, 36, 36), "label": "B", "skin": "red", "hint": "leave"},
	]


func _fill_pile() -> void:
	while pile.size() < 9:
		var r := rng.randf_range(10.0, 14.0)
		var x := rng.randf_range(CHUTE.end.x + 18.0, BOX.end.x - 16.0)
		var y := FLOOR_Y - r - (rng.randf() * 18.0 if pile.size() > 4 else 0.0)
		pile.append({"x": x, "y": y, "r": r, "look": LOOKS[rng.randi() % LOOKS.size()], "item": _roll_item(), "hue": rng.randf()})


func _roll_item() -> String:
	var pool := Tickets.claw_pool(POOL)  # the economy's list (tools/gen_rec.py CLAW_POOL)
	var tot := 0
	for p: Array in pool:
		if GameState.items.has(str(p[0])) and Tickets.arc_ok(str(p[0])):
			tot += int(p[1])
	var v := rng.randi_range(1, tot)
	for p: Array in pool:
		if not GameState.items.has(str(p[0])) or not Tickets.arc_ok(str(p[0])):
			continue
		v -= int(p[1])
		if v <= 0:
			return str(p[0])
	return "toy"


func _setup_round() -> void:
	_fill_pile()
	claw = Vector2(150, TOP_Y)
	phase = "aim"
	phase_t = 0.0
	open_amt = 1.0
	held_i = -1
	won_item = ""
	aim_left = AIM_T
	if dry_streak() >= 4:
		say("The machine hums warmly. Feels generous.", 2.0)


## How hard the claw holds: centring matters most (a few pixels off halves it),
## big plushes are heavier, wins today loosen it, luck (gear + popcorn) and a
## long dry run firm it up again (the old dialogue claw's pity win, kept fair).
static func grip_for(dx: float, r: float, tight: float, lk: float, dry: int) -> float:
	var c := clampf(1.0 - dx / (r * 1.1), 0.0, 1.0)
	var heavy := 0.84 if r > 12.5 else 0.94
	var g := pow(c, 1.5) * heavy * tight
	if c > 0.0:
		g += 0.03 * lk + minf(0.25, 0.05 * maxi(0, dry - 2))
	return clampf(g, 0.0, 0.97)


## Chance per second that a grip slips while lifting and carrying.
static func slip_rate(g: float) -> float:
	return (1.0 - g) * (1.0 - g) * 1.4


## Losses in a row since the last prize (run["arcade_hub"]["claw_dry"]).
static func dry_streak() -> int:
	return int(ArcadeHub._data().get("claw_dry", 0))


func _tightness() -> float:
	return maxf(0.45, 1.0 - 0.12 * wins_today())


## Prizes won from the machine today (run["arcade_hub"]["claw_today"] = [day, wins]).
static func wins_today() -> int:
	var ct: Variant = ArcadeHub._data().get("claw_today", [])
	if ct is Array and (ct as Array).size() == 2 and int(ct[0]) == int(GameState.run.get("day", 0)):
		return int(ct[1])
	return 0


func _step(dt: float) -> void:
	phase_t += dt
	match phase:
		"aim":
			aim_left -= dt
			var dir := (1.0 if held("right") else 0.0) - (1.0 if held("left") else 0.0)
			claw.x = clampf(claw.x + dir * 70.0 * dt, BOX.position.x + 14.0, BOX.end.x - 14.0)
			_motor(dt, dir != 0.0)
			if pressed("a") or aim_left <= 0.0:
				_set_phase("drop")
				_motor_t = 0.0
			elif pressed("b"):
				close()
		"drop":
			_motor(dt, true)
			claw.y += 90.0 * dt
			var hit := _prize_under()
			var stop_y := FLOOR_Y - 10.0
			if hit >= 0:
				var p: Dictionary = pile[hit]
				stop_y = float(p["y"]) - float(p["r"]) * 0.4
			if claw.y >= stop_y:
				claw.y = stop_y
				_set_phase("grab")
		"grab":
			open_amt = maxf(0.0, 1.0 - phase_t / 0.35)
			if phase_t >= 0.45:
				var i := _prize_under()
				if i >= 0:
					var p2: Dictionary = pile[i]
					var dx := absf(float(p2["x"]) - claw.x)
					grip = grip_for(dx, float(p2["r"]), _tightness(), ArcadeSkee.luck(), dry_streak())
					if grip > 0.15:
						held_i = i
						sfx("cloth", "pickup")
					open_amt = 0.15 if held_i >= 0 else 0.0
				_set_phase("lift")
		"lift":
			_motor(dt, true)
			claw.y -= 70.0 * dt
			_carry(dt)
			if claw.y <= TOP_Y:
				claw.y = TOP_Y
				_set_phase("carry")
		"carry":
			_motor(dt, true)
			claw.x = move_toward(claw.x, CHUTE.get_center().x, 60.0 * dt)
			_carry(dt)
			if absf(claw.x - CHUTE.get_center().x) < 0.5:
				_set_phase("release")
		"release":
			open_amt = minf(1.0, phase_t / 0.3)
			if held_i >= 0:
				var p3: Dictionary = pile[held_i]
				p3["y"] = float(p3["y"]) + 160.0 * dt
				if float(p3["y"]) > CHUTE.end.y + 10.0:
					_win(held_i)
			elif phase_t > 0.5:
				_lose()
		"fall":
			# A slipped prize drops back to the pile.
			if held_i >= 0:
				var p4: Dictionary = pile[held_i]
				p4["y"] = minf(float(p4["y"]) + 200.0 * dt, FLOOR_Y - float(p4["r"]))
				if float(p4["y"]) >= FLOOR_Y - float(p4["r"]):
					held_i = -1
					sfx("thud", "drop")
					shake(1.5)
			claw.y = maxf(TOP_Y, claw.y - 70.0 * dt)
			if held_i < 0 and claw.y <= TOP_Y and phase_t > 0.6:
				_lose()


## The claw's motor: one whirr on the first frame of a move, then once per take
## length while it keeps moving (never the old 80 ms stutter that ate voices).
var _motor_t := 0.0
const MOTOR_EVERY := 0.45


func _motor(dt: float, moving: bool) -> void:
	if not moving:
		_motor_t = 0.0
		return
	_motor_t -= dt
	if _motor_t <= 0.0:
		sfx("claw_motor", "servo")
		_motor_t = MOTOR_EVERY


func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0


func _carry(dt: float) -> void:
	if held_i < 0:
		return
	var p: Dictionary = pile[held_i]
	p["x"] = claw.x
	p["y"] = claw.y + float(p["r"]) * 0.7
	# A weak grip can slip on the way (a dead-centre grab mostly holds).
	if rng.randf() < slip_rate(grip) * dt:
		open_amt = 0.6
		sfx("nope", "drop")
		say("It slipped!")
		_set_phase("fall")


func _prize_under() -> int:
	var best := -1
	var by := INF
	for i in pile.size():
		var p: Dictionary = pile[i]
		if absf(float(p["x"]) - claw.x) < float(p["r"]) + 4.0 and float(p["y"]) < by and i != held_i:
			by = float(p["y"])
			best = i
	return best


func _win(i: int) -> void:
	var p: Dictionary = pile[i]
	won_item = str(p["item"])
	pile.remove_at(i)
	held_i = -1
	ArcadeHub._data()["claw_today"] = [int(GameState.run.get("day", 0)), wins_today() + 1]
	ArcadeHub._data()["claw_dry"] = 0
	GameState.add_item(won_item, 1)
	score = maxi(1, GameState.item_value(won_item)) if GameState.items.has(won_item) else 10
	var d: Dictionary = ArcadeHub._data()
	d["claw_wins"] = int(d.get("claw_wins", 0)) + 1
	ArcadeHub.set_milestone("claw_win")
	if int(d["claw_wins"]) >= 5:
		ArcadeHub.set_milestone("claw_5")
	burst(Vector2(CHUTE.get_center().x, CHUTE.position.y), Color(1, 0.85, 0.4), 24, 110.0)
	sfx("j_treasure", "j_victory")
	result_cue_done = true  # one win jingle: game_over must not stack j_victory on it
	# The plush is only the wrapping: say what was inside, never "(bear plush)" after candy.
	var inside := "" if won_item.begins_with("rp_") else "Tucked inside the %s plush." % str(p["look"])
	var lines: Array = ["!YOU WON!", GameState.item_name(won_item)]
	if inside != "":
		lines.append(inside)
	lines.append("It's in your bag.")
	game_over(lines)


func _lose() -> void:
	score = 0
	ArcadeHub._data()["claw_dry"] = dry_streak() + 1
	game_over(["!SO CLOSE", "Line it up dead centre next time."])


func _tickets_for(_s: int) -> int:
	return 10 + score / 10 if won_item != "" else 2


## A machine standing in the room: the room's song (the jukebox record) plays on.
func _start_music() -> void:
	pass


func _good_tickets() -> int:
	return 10


func _top_right() -> String:
	return "%ds" % int(ceil(aim_left)) if state == "play" and phase == "aim" else super()


func _draw_play(c: Control) -> void:
	c.draw_rect(PLAY, Color(0.2, 0.08, 0.18))
	# Cabinet lights.
	var tb := TriBatch.new()  # one draw call for the 18 bulbs
	for i in 18:
		var on := int(t * 6.0 + i) % 3 == 0
		tb.circle(Vector2(12 + i * 14.5, 34), 2.5, Color(1, 0.85, 0.4) if on else Color(0.5, 0.3, 0.3))
	tb.flush(c)
	panel(c, BOX.grow(4), Color(0.12, 0.05, 0.12), accent)
	if not cover(c, "stage_clawbox", BOX, 0.8):
		c.draw_rect(BOX, Color(0.55, 0.75, 0.95, 0.22))
		for i in 12:
			c.draw_circle(Vector2(BOX.position.x + 20 + (i % 6) * 40, BOX.position.y + 40 + (i / 6) * 50), 10, Color(1, 1, 1, 0.04))
	# Chute.
	# The prize chute: an acrylic box with a dark drop, a lit rim and a sign.
	c.draw_rect(CHUTE, Color(0.07, 0.03, 0.08))
	for i in 6:  # depth shading down the drop
		c.draw_rect(Rect2(CHUTE.position.x, CHUTE.position.y + i * 10, CHUTE.size.x, 10), Color(0.25, 0.1, 0.22, 0.32 - i * 0.05))
	c.draw_rect(CHUTE, Color(0.75, 0.85, 1.0, 0.07))
	c.draw_line(CHUTE.position + Vector2(5, 6), CHUTE.position + Vector2(5, CHUTE.size.y - 8), Color(1, 1, 1, 0.22), 2.0)
	c.draw_line(CHUTE.position + Vector2(10, 6), CHUTE.position + Vector2(10, 26), Color(1, 1, 1, 0.12), 1.0)
	c.draw_rect(CHUTE, accent.darkened(0.3), false, 1.0)
	var glow := 0.6 + 0.4 * sin(t * 5.0)
	c.draw_rect(Rect2(CHUTE.position.x - 1, CHUTE.position.y - 4, CHUTE.size.x + 2, 4), accent.lerp(Color(1, 0.95, 0.7), glow * 0.5))
	panel(c, Rect2(CHUTE.position.x + 4, CHUTE.position.y + 24, CHUTE.size.x - 8, 13), Color(0.95, 0.85, 0.3), Color(0.5, 0.3, 0.1))
	text(c, Vector2(CHUTE.position.x, CHUTE.position.y + 34), "PRIZE", CHUTE.size.x, 7, Color(0.35, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER)
	c.draw_line(CHUTE.position + Vector2(3, CHUTE.size.y - 12), CHUTE.end - Vector2(3, 12), Color(0.85, 0.85, 0.95, 0.5), 2.0)  # the flap
	if tex("stage_clawbox") == null:
		c.draw_rect(Rect2(CHUTE.end.x, FLOOR_Y, BOX.end.x - CHUTE.end.x, BOX.end.y - FLOOR_Y), Color(0.35, 0.15, 0.3))
	spr(c, "capsule", Rect2(CHUTE.position.x + 8, CHUTE.position.y - 34, 28, 28))
	if pile.is_empty():
		_fill_pile()
	var order := range(pile.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(pile[a]["y"]) < float(pile[b]["y"]))
	for i: int in order:
		if i != held_i:
			_plush(c, pile[i])
	# Rail and cable.
	c.draw_rect(Rect2(BOX.position.x, BOX.position.y + 4, BOX.size.x, 4), Color(0.7, 0.7, 0.75))
	c.draw_rect(Rect2(claw.x - 8, BOX.position.y + 2, 16, 8), Color(0.45, 0.45, 0.5))
	c.draw_line(Vector2(claw.x, BOX.position.y + 10), claw, Color(0.85, 0.85, 0.9), 1.0)
	if held_i >= 0:
		_plush(c, pile[held_i])
	_claw(c)
	# Aim guide while steering.
	if state == "play" and phase == "aim":
		for y in range(int(claw.y + 18), int(FLOOR_Y), 8):
			c.draw_rect(Rect2(claw.x, y, 1, 3), Color(1, 1, 1, 0.25))
		text_outline(c, Vector2(BOX.position.x, BOX.position.y + 30), "%d" % int(ceil(aim_left)), BOX.size.x, 16, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	c.draw_rect(Rect2(BOX.position.x + 6, BOX.position.y + 12, 3, 80), Color(1, 1, 1, 0.12))
	draw_fx(c)


func _claw(c: Control) -> void:
	var p := claw
	if spr(c, "claw_open" if open_amt > 0.45 else "claw_closed", Rect2(p.x - 18, p.y - 10, 36, 32)):
		return
	c.draw_rect(Rect2(p.x - 7, p.y - 6, 14, 8), Color(0.75, 0.75, 0.82))
	c.draw_rect(Rect2(p.x - 7, p.y - 6, 14, 2), Color(0.95, 0.95, 1))
	var spread := 4.0 + open_amt * 9.0
	for s in [-1.0, 1.0]:
		var a := p + Vector2(s * 5.0, 2.0)
		var b := p + Vector2(s * spread, 12.0)
		var e := p + Vector2(s * (spread - 6.0 + (1.0 - open_amt) * 2.0), 20.0)
		c.draw_line(a, b, Color(0.82, 0.82, 0.9), 2.0)
		c.draw_line(b, e, Color(0.82, 0.82, 0.9), 2.0)


func _plush(c: Control, p: Dictionary) -> void:
	var ctr := Vector2(float(p["x"]), float(p["y"]))
	var r := float(p["r"])
	var look := str(p["look"])
	if spr(c, "plush_" + look, Rect2(ctr.x - r * 1.35, ctr.y - r * 1.5, r * 2.7, r * 2.6)):
		return
	var col: Color = LOOK_COL[look]
	match look:
		"star":
			var pts := PackedVector2Array()
			for k in 10:
				var rr := r if k % 2 == 0 else r * 0.5
				var a := -PI / 2 + k * PI / 5
				pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
			c.draw_colored_polygon(pts, col)
		"penguin":
			c.draw_circle(ctr, r, col)
			c.draw_circle(ctr + Vector2(0, 2), r * 0.65, Color(0.95, 0.95, 1))
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-2, -1), ctr + Vector2(2, -1), ctr + Vector2(0, 2)]), Color(1, 0.6, 0.2))
		"duck":
			c.draw_circle(ctr, r, col)
			c.draw_circle(ctr + Vector2(r * 0.5, -r * 0.6), r * 0.55, col)
			c.draw_rect(Rect2(ctr + Vector2(r * 0.9, -r * 0.65), Vector2(5, 3)), Color(1, 0.55, 0.15))
		_:
			if look == "bear":
				c.draw_circle(ctr + Vector2(-r * 0.7, -r * 0.7), r * 0.35, col)
				c.draw_circle(ctr + Vector2(r * 0.7, -r * 0.7), r * 0.35, col)
			elif look == "bunny":
				c.draw_rect(Rect2(ctr + Vector2(-r * 0.55, -r * 1.6), Vector2(4, r)), col)
				c.draw_rect(Rect2(ctr + Vector2(r * 0.25, -r * 1.6), Vector2(4, r)), col)
			c.draw_circle(ctr, r, col)
			c.draw_circle(ctr + Vector2(0, r * 0.35), r * 0.4, col.lightened(0.3))
	c.draw_arc(ctr, r, 0, TAU, 20, col.darkened(0.5), 1.0)
	c.draw_rect(Rect2(ctr + Vector2(-r * 0.4, -r * 0.2), Vector2(2, 2)), Color.BLACK)
	c.draw_rect(Rect2(ctr + Vector2(r * 0.3, -r * 0.2), Vector2(2, 2)), Color.BLACK)
	# Prize tag.
	c.draw_rect(Rect2(ctr + Vector2(r * 0.4, r * 0.3), Vector2(5, 4)), Color.from_hsv(float(p["hue"]), 0.5, 1.0))


func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.55, 0.75, 0.95, 0.25))
	if cover(c, "stage_clawbox", r, 0.75):
		for i in 6:
			if i == 2 or i == 3:
				continue
			_plush(c, {"x": r.position.x + 22 + i * 32, "y": r.end.y - 16, "r": 11.0, "look": LOOKS[i], "hue": i / 6.0})
		draw_cabinet(c, r)
		return
	for i in 6:
		_plush(c, {"x": r.position.x + 22 + i * 32, "y": r.end.y - 14 - (i % 2) * 6, "r": 11.0, "look": LOOKS[i], "hue": i / 6.0})
	var cx := r.get_center().x + sin(t * 1.4) * 50
	c.draw_line(Vector2(cx, r.position.y), Vector2(cx, r.position.y + 40), Color(0.85, 0.85, 0.9), 1.0)
	var saved := claw
	var so := open_amt
	claw = Vector2(cx, r.position.y + 40)
	open_amt = 0.6 + 0.4 * sin(t * 2.0)
	_claw(c)
	claw = saved
	open_amt = so
