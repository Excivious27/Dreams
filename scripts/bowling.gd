class_name Bowling
extends CanvasLayer
## Ten-pin bowling at the Rec Center: a full-screen mini-game.
##   1) Line up: LEFT/RIGHT moves along the foul line, UP/DOWN sets spin. USE.
##   2) Aim: the arrow swings. USE locks it.   3) Power: the meter pulses. USE throws.
## Ten frames, real scoring (strikes, spares, the 10th frame's bonus balls), a
## score sheet on the overhead monitor, pins with simple 2D physics (Sim) drawn
## in perspective down the lane. Touch: on-screen ◀ ▶ / spin / GO buttons, or the
## stick + USE. B (or MENU, or the X button) twice leaves the game.
##
##   var res := await Bowling.play(map, lane)   # {"done", "score", "strikes", "spares", "rolls"}

signal closed

# ---- scoring -----------------------------------------------------------------------

## Running totals per frame for the rolls so far (-1 where a frame can't be scored yet).
static func frame_totals(rolls: Array) -> Array:
	var out: Array = []
	var i := 0
	var total := 0
	var known := true
	for f in 10:
		if i >= rolls.size():
			break
		var add := -1
		if f < 9:
			if int(rolls[i]) == 10:
				if i + 2 < rolls.size():
					add = 10 + int(rolls[i + 1]) + int(rolls[i + 2])
				i += 1
			else:
				if i + 1 >= rolls.size():
					out.append(-1)
					break
				var two := int(rolls[i]) + int(rolls[i + 1])
				if two == 10:
					if i + 2 < rolls.size():
						add = 10 + int(rolls[i + 2])
				else:
					add = two
				i += 2
		else:
			var r: Array = rolls.slice(i)
			var need := 3 if (r.size() >= 1 and int(r[0]) == 10) or (r.size() >= 2 and int(r[0]) + int(r[1]) == 10) else 2
			if r.size() >= need:
				add = 0
				for k in need:
					add += int(r[k])
			i = rolls.size()
		if add < 0 or not known:
			known = false
			out.append(-1)
		else:
			total += add
			out.append(total)
	return out


## Final (or so-far known) score.
static func score_of(rolls: Array) -> int:
	var t := frame_totals(rolls)
	var best := 0
	for v in t:
		if int(v) >= 0:
			best = int(v)
	return best


## Where the next ball goes: {"frame": 0-9, "ball": 0-2, "reset": bool (fresh rack), "over": bool}.
static func next_state(rolls: Array) -> Dictionary:
	var i := 0
	for f in 10:
		if f < 9:
			if i >= rolls.size():
				return {"frame": f, "ball": 0, "reset": true, "over": false}
			if int(rolls[i]) == 10:
				i += 1
				continue
			if i + 1 >= rolls.size():
				return {"frame": f, "ball": 1, "reset": false, "over": false}
			i += 2
		else:
			var r: Array = rolls.slice(i)
			match r.size():
				0: return {"frame": 9, "ball": 0, "reset": true, "over": false}
				1: return {"frame": 9, "ball": 1, "reset": int(r[0]) == 10, "over": false}
				2:
					if int(r[0]) == 10:
						return {"frame": 9, "ball": 2, "reset": int(r[1]) == 10, "over": false}
					if int(r[0]) + int(r[1]) == 10:
						return {"frame": 9, "ball": 2, "reset": true, "over": false}
					return {"frame": 9, "ball": 2, "reset": false, "over": true}
				_: return {"frame": 9, "ball": 3, "reset": false, "over": true}
	return {"frame": 9, "ball": 0, "reset": false, "over": true}


## Strikes and spares in a finished line (for tickets).
static func count_marks(rolls: Array) -> Dictionary:
	var strikes := 0
	var spares := 0
	var i := 0
	for f in 10:
		if i >= rolls.size():
			break
		if f < 9:
			if int(rolls[i]) == 10:
				strikes += 1
				i += 1
			else:
				if i + 1 < rolls.size() and int(rolls[i]) + int(rolls[i + 1]) == 10:
					spares += 1
				i += 2
		else:
			var r: Array = rolls.slice(i)
			var stand := 10
			for k in r.size():
				var v := int(r[k])
				if v == 10 and stand == 10:
					strikes += 1
				elif v == stand and k > 0:
					spares += 1
				stand = 10 if v == stand else stand - v
			break
	return {"strikes": strikes, "spares": spares}


## The marks for one frame's boxes ("X", "/", "-", "7"...).
static func frame_marks(rolls: Array, frame: int) -> Array:
	var i := 0
	for f in frame:
		if i >= rolls.size():
			return []
		if int(rolls[i]) == 10:
			i += 1
		else:
			i += 2
	var out: Array = []
	if frame < 9:
		if i < rolls.size():
			if int(rolls[i]) == 10:
				return ["", "X"]
			out.append("-" if int(rolls[i]) == 0 else str(int(rolls[i])))
			if i + 1 < rolls.size():
				out.append("/" if int(rolls[i]) + int(rolls[i + 1]) == 10 else ("-" if int(rolls[i + 1]) == 0 else str(int(rolls[i + 1]))))
		return out
	var stand := 10
	for k in range(i, mini(i + 3, rolls.size())):
		var v := int(rolls[k])
		if v == 10 and stand == 10:
			out.append("X")
		elif v == stand and stand < 10:
			out.append("/")
		else:
			out.append("-" if v == 0 else str(v))
		stand = 10 if v == stand else stand - v
	return out


# ---- the pin physics ----------------------------------------------------------------

## Inches. x across the lane (0 = middle board, + = right), y down the lane (0 = foul
## line, 720 = head pin). Ball and pins are discs; collisions are impulses.
class Sim:
	const LANE_HALF := 20.5
	const GUTTER_X := 23.5
	const HEAD_Y := 720.0
	const PIT_Y := 762.0
	const KICK_X := 25.5
	const BALL_R := 4.3
	const PIN_R := 2.4
	const BALL_M := 7.0
	const PIN_M := 1.6
	const FALL_SPEED := 14.0
	const HOOK_FROM := 430.0
	static var BALL_E := 0.7
	static var PIN_E := 0.8
	static var DOWN_DEC := 80.0

	var pins: Array = []        # {"p": Vector2, "v": Vector2, "down": bool, "gone": bool, "fall": 0..1, "dir": Vector2, "home": Vector2}
	var ball_p := Vector2.ZERO
	var ball_v := Vector2.ZERO
	var spin := 0.0             # -1..1, + hooks left
	var gutter := false
	var hit_any := false
	var t := 0.0
	var done := false
	var quiet := 0.0
	var rng := RandomNumberGenerator.new()

	func rack() -> void:
		pins.clear()
		for row in 4:
			for i in row + 1:
				var p := Vector2((i - row / 2.0) * 12.0, HEAD_Y + row * 10.39)
				pins.append({"p": p, "v": Vector2.ZERO, "down": false, "gone": false, "fall": 0.0, "dir": Vector2.UP, "home": p})

	## Fallen pins are swept off; standing ones stay where they are.
	func sweep() -> void:
		for p: Dictionary in pins:
			p["v"] = Vector2.ZERO
			if bool(p["down"]):
				p["gone"] = true

	func standing() -> int:
		var n := 0
		for p: Dictionary in pins:
			if not bool(p["down"]) and not bool(p["gone"]):
				n += 1
		return n

	func throw(x0: float, angle_deg: float, speed: float, spin_in: float) -> void:
		ball_p = Vector2(clampf(x0, -LANE_HALF + BALL_R, LANE_HALF - BALL_R), 0.0)
		var a := deg_to_rad(angle_deg + rng.randf_range(-0.12, 0.12))
		ball_v = Vector2(sin(a), cos(a)) * speed
		spin = clampf(spin_in, -1.0, 1.0)
		gutter = false
		hit_any = false
		t = 0.0
		done = false
		quiet = 0.0

	func step(dt: float) -> Array:
		## Returns events: "hit" (first pin contact), "gutter", "pit".
		var ev: Array = []
		t += dt
		if ball_p.y < PIT_Y + 30.0:
			if not gutter and not hit_any and ball_p.y > HOOK_FROM:
				# Back end: the lane is dry, the spin bites (slower balls hook more).
				var k := 330.0 / maxf(180.0, ball_v.length())
				ball_v.x -= spin * 26.0 * k * dt
			ball_p += ball_v * dt
			ball_v *= 1.0 - 0.02 * dt
			if not gutter and absf(ball_p.x) > LANE_HALF and ball_p.y < HEAD_Y - 10.0:
				gutter = true
				ball_p.x = signf(ball_p.x) * GUTTER_X
				ball_v.x = 0.0
				ev.append("gutter")
			if ball_p.y >= PIT_Y + 30.0:
				ev.append("pit")
		if not gutter:
			for p: Dictionary in pins:
				if bool(p["gone"]):
					continue
				var d: Vector2 = p["p"] - ball_p
				var dist := d.length()
				if dist < BALL_R + PIN_R and dist > 0.001:
					var n := d / dist
					var vrel := (ball_v - (p["v"] as Vector2)).dot(n)
					if vrel > 0.0:
						var j := (1.0 + BALL_E) * vrel / (1.0 / BALL_M + 1.0 / PIN_M)
						ball_v -= n * j / BALL_M
						p["v"] = (p["v"] as Vector2) + n * j / PIN_M
						if not hit_any:
							hit_any = true
							ev.append("hit")
					var over := BALL_R + PIN_R - dist
					p["p"] = (p["p"] as Vector2) + n * over * 0.8
					ball_p -= n * over * 0.2
		# Pins against pins.
		for a in pins.size():
			var pa: Dictionary = pins[a]
			if bool(pa["gone"]):
				continue
			for b in range(a + 1, pins.size()):
				var pb: Dictionary = pins[b]
				if bool(pb["gone"]):
					continue
				var d2: Vector2 = pb["p"] - pa["p"]
				var dist2 := d2.length()
				if dist2 < PIN_R * 2.0 and dist2 > 0.001:
					var n2 := d2 / dist2
					var vrel2 := ((pa["v"] as Vector2) - (pb["v"] as Vector2)).dot(n2)
					if vrel2 > 0.0:
						var j2 := (1.0 + PIN_E) * vrel2 / 2.0
						pa["v"] = (pa["v"] as Vector2) - n2 * j2
						pb["v"] = (pb["v"] as Vector2) + n2 * j2
					var ov := (PIN_R * 2.0 - dist2) / 2.0
					pa["p"] = (pa["p"] as Vector2) - n2 * ov
					pb["p"] = (pb["p"] as Vector2) + n2 * ov
		var moving := false
		for p: Dictionary in pins:
			if bool(p["gone"]):
				continue
			var v: Vector2 = p["v"]
			var sp := v.length()
			if sp > FALL_SPEED and not bool(p["down"]):
				p["down"] = true
				p["dir"] = v.normalized()
			if not bool(p["down"]) and ((p["p"] as Vector2) - (p["home"] as Vector2)).length() > 3.2:
				p["down"] = true
				p["dir"] = v.normalized() if sp > 0.1 else Vector2.UP
			if bool(p["down"]):
				p["fall"] = minf(1.0, float(p["fall"]) + dt * 4.0)
			# Tumbling pins slow fast; kickbacks throw them back in; the pit swallows them.
			var dec := DOWN_DEC if bool(p["down"]) else 600.0
			v = v.move_toward(Vector2.ZERO, dec * dt)
			var np: Vector2 = (p["p"] as Vector2) + v * dt
			if np.y > HEAD_Y - 6.0 and absf(np.x) > KICK_X:
				np.x = signf(np.x) * KICK_X
				v.x = -v.x * 0.45
			if np.y > PIT_Y or np.y < HEAD_Y - 60.0 or absf(np.x) > KICK_X + 1.0:
				p["down"] = true
				p["gone"] = true
			p["p"] = np
			p["v"] = v
			if v.length() > 1.0:
				moving = true
		var ball_live := ball_p.y < PIT_Y + 30.0 and ball_v.length() > 5.0
		if not moving and not ball_live:
			quiet += dt
			if quiet > 0.35 or not hit_any:
				done = true
		else:
			quiet = 0.0
		if t > 8.0:
			done = true
		return ev

	## Runs a whole throw (tests). Returns pins knocked.
	func run_throw(x0: float, angle_deg: float, speed: float, spin_in: float) -> int:
		var before := standing()
		throw(x0, angle_deg, speed, spin_in)
		var n := 0
		while not done and n < 4000:
			step(1.0 / 240.0)
			n += 1
		return before - standing()


# ---- the game screen ------------------------------------------------------------------

const F := 330.0       # focal length (px)
const CAM_H := 42.0    # camera height (in)
const HZ := 214.0      # horizon (screen y)
const MODAL := Rect2(0, 0, 270, 372)
const BTN_L := Rect2(8, 398, 42, 34)
const BTN_R := Rect2(54, 398, 42, 34)
const BTN_SPIN_L := Rect2(8, 438, 42, 28)
const BTN_SPIN_R := Rect2(54, 438, 42, 28)
const BTN_GO := Rect2(102, 398, 48, 68)
const BTN_QUIT := Rect2(6, 72, 30, 24)  # finger-sized (was 28x18)

var lane := 1
var sim := Sim.new()
var rolls: Array = []
var phase := "line"          # line, aim, power, roll, result, over
var x0 := 6.0
var spin_step := 1           # -3..3
var aim := 0.0
var power := 0.0
var _osc := 0.0
var _cam_y := -100.0
var _msg := ""
var _msg_t := 0.0
var _knocked := 0
var _before := 10
var _quit_arm := 0.0
var _arm := 0
var _hold := 0               # -1 / +1 from the on-screen arrows
var _canvas: Control
var _font: Font
var _was_down: Array = []
var result := {}
var _slowmo := 1.0
var _tap_go := false


static func play(m: GameMap, lane_no: int) -> Dictionary:
	var g := Bowling.new()
	g.lane = lane_no
	m.add_child(g)
	await g.closed
	return g.result


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	Hud.modal_rect = MODAL
	for r in [BTN_L, BTN_R, BTN_SPIN_L, BTN_SPIN_R, BTN_GO, BTN_QUIT]:
		Hud.extra_rects.append(r)
	get_tree().paused = true
	sim.rng.seed = int(GameState.run.get("day", 1)) * 977 + lane * 31 + int(GameState.run.get("time", 0))
	sim.rack()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_it)
	_canvas.gui_input.connect(_tap)
	add_child(_canvas)
	_new_ball()


func _exit_tree() -> void:
	for r in [BTN_L, BTN_R, BTN_SPIN_L, BTN_SPIN_R, BTN_GO, BTN_QUIT]:
		Hud.extra_rects.erase(r)


func _new_ball() -> void:
	var ns := next_state(rolls)
	if bool(ns["over"]):
		_game_over()
		return
	if bool(ns["reset"]):
		sim.rack()
	phase = "line"
	_cam_y = -100.0
	_before = sim.standing()
	_was_down.clear()
	for p: Dictionary in sim.pins:
		_was_down.append(bool(p["down"]) or bool(p["gone"]))
	sim.ball_p = Vector2(x0, -8.0)
	sim.ball_v = Vector2.ZERO
	sim.gutter = false


func _process(delta: float) -> void:
	_arm += 1
	_msg_t = maxf(0.0, _msg_t - delta)
	_quit_arm = maxf(0.0, _quit_arm - delta)
	_canvas.queue_redraw()
	if _arm < 8:
		return
	if (Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu")) and phase != "over":
		_ask_quit()
		return
	var go := Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action") or _tap_go
	_tap_go = false
	match phase:
		"line":
			var dir := _hold
			if Input.is_action_pressed("left"):
				dir = -1
			elif Input.is_action_pressed("right"):
				dir = 1
			x0 = clampf(x0 + dir * 16.0 * delta, -16.0, 16.0)
			if Input.is_action_just_pressed("up"):
				spin_step = mini(3, spin_step + 1)
			elif Input.is_action_just_pressed("down"):
				spin_step = maxi(-3, spin_step - 1)
			sim.ball_p = Vector2(x0, -8.0)
			if go:
				phase = "aim"
				_osc = 0.0
				Music.instance(get_tree()).sfx("ui_tap", "pickup")
		"aim":
			_osc += delta
			aim = sin(_osc * TAU / 1.7) * 1.7
			if go:
				phase = "power"
				_osc = 0.0
				Music.instance(get_tree()).sfx("ui_tap", "pickup")
		"power":
			_osc += delta
			var ph := fmod(_osc / 1.1, 2.0)
			power = ph if ph <= 1.0 else 2.0 - ph
			if go:
				_throw()
		"roll":
			var steps := int(ceil(delta * 240.0 * _slowmo))
			for i in mini(steps, 12):
				for e in sim.step(1.0 / 240.0):
					_on_event(str(e))
				if sim.done:
					break
			_slowmo = 0.55 if sim.ball_p.y > 640.0 and sim.ball_p.y < 780.0 and not sim.gutter else 1.0
			var want := clampf(sim.ball_p.y - 110.0, -100.0, 575.0)
			_cam_y = lerpf(_cam_y, want, minf(1.0, delta * 6.0))
			if sim.done:
				_scored()
		"result":
			if _msg_t <= 0.0 or go:
				sim.sweep()
				_new_ball()
		"over":
			if go or Input.is_action_just_pressed("b"):
				_finish()


func _throw() -> void:
	phase = "roll"
	var speed := 230.0 + 140.0 * power
	sim.throw(x0, aim, speed, spin_step / 3.0)
	_slowmo = 1.0
	Music.instance(get_tree()).sfx("swing_heavy", "swing")
	Music.instance(get_tree()).sfx("bowl_roll", "thud")


func _on_event(e: String) -> void:
	match e:
		"hit":
			Music.instance(get_tree()).sfx("pin_crash", "thud")
		"gutter":
			Music.instance(get_tree()).sfx("nope", "thud")
			_say("Gutter...", 1.0)


func _scored() -> void:
	_knocked = _before - sim.standing()
	rolls.append(_knocked)
	var ns := next_state(rolls)
	var last := frame_marks(rolls, int(next_state(rolls.slice(0, rolls.size() - 1))["frame"]))
	var mark := str(last.back()) if not last.is_empty() else ""
	if mark == "X":
		_say("STRIKE!", 1.6)
		Music.instance(get_tree()).sfx("j_treasure", "levelup")
		Music.instance(get_tree()).sfx("clap", "pickup")
	elif mark == "/":
		_say("SPARE!", 1.4)
		Music.instance(get_tree()).sfx("sparkle", "pickup")
	elif _knocked == 0:
		_say("Missed them all." if not sim.gutter else "Gutter ball.", 1.1)
	else:
		_say("%d pin%s" % [_knocked, "" if _knocked == 1 else "s"], 1.0)
	phase = "result"
	if bool(ns["over"]):
		_msg_t = maxf(_msg_t, 1.2)


func _say(t: String, secs: float) -> void:
	_msg = t
	_msg_t = secs


func _game_over() -> void:
	phase = "over"
	var mk := count_marks(rolls)
	result = {"done": true, "score": score_of(rolls), "strikes": int(mk["strikes"]), "spares": int(mk["spares"]), "rolls": rolls.duplicate()}


func _ask_quit() -> void:
	if _quit_arm > 0.0:
		result = {"done": false, "score": score_of(rolls), "rolls": rolls.duplicate()}
		_finish()
	else:
		_quit_arm = 2.0
		_say("Press again to leave (no tickets).", 2.0)


func _finish() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _tap(ev: InputEvent) -> void:
	var p := Vector2.INF
	var pressed := false
	if ev is InputEventMouseButton:
		p = (ev as InputEventMouseButton).position
		pressed = (ev as InputEventMouseButton).pressed
	elif ev is InputEventScreenTouch:
		p = (ev as InputEventScreenTouch).position
		pressed = (ev as InputEventScreenTouch).pressed
	else:
		return
	if not pressed:
		_hold = 0
		return
	if BTN_QUIT.has_point(p):
		_ask_quit()
	elif phase == "line" and BTN_L.has_point(p):
		_hold = -1
	elif phase == "line" and BTN_R.has_point(p):
		_hold = 1
	elif phase == "line" and BTN_SPIN_L.has_point(p):
		spin_step = maxi(-3, spin_step - 1)
	elif phase == "line" and BTN_SPIN_R.has_point(p):
		spin_step = mini(3, spin_step + 1)
	elif BTN_GO.has_point(p) or (MODAL.has_point(p) and p.y > 90):
		_tap_go = true


# ---- drawing -------------------------------------------------------------------------

## Lane point (x, y, h inches) to screen; z <= 0 is behind the camera.
func _proj(x: float, y: float, h := 0.0) -> Vector3:
	var z := y - _cam_y
	if z < 6.0:
		return Vector3(0, 0, -1)
	return Vector3(135.0 + F * x / z, HZ + F * (CAM_H - h) / z, F / z)


func _p2(x: float, y: float, h := 0.0) -> Vector2:
	var v := _proj(x, y, h)
	return Vector2(v.x, v.y)


func _quad(x0q: float, x1q: float, y0q: float, y1q: float, c: Color, h := 0.0) -> void:
	var ya := maxf(y0q, _cam_y + 8.0)
	if y1q <= ya:
		return
	_canvas.draw_colored_polygon(PackedVector2Array([_p2(x0q, ya, h), _p2(x1q, ya, h), _p2(x1q, y1q, h), _p2(x0q, y1q, h)]), c)


func _draw_it() -> void:
	var c := _canvas
	var gang := not GameState.is_penguins()
	# Room: ceiling and back wall.
	c.draw_rect(Rect2(0, 0, 270, 480), Color("1e140e") if not gang else Color("0a0614"))
	# The far wall: ceiling lamps and the mural over the pin decks, in perspective.
	var wall := Art.tex("backdrops", "bowling_wall")
	if wall:
		# Sized like a backdrop (it grows a little as you near the pins, never fills the view).
		var base := _proj(0.0, 790.0, 0.0)
		if base.z > 0:
			var ww := clampf(1000.0 * base.z, 300.0, 420.0)
			var wh := ww * wall.get_height() / wall.get_width()
			c.draw_texture_rect(wall, Rect2(base.x - ww / 2.0, base.y - wh, ww, wh), false, Color(1, 1, 1) if not gang else Color(0.75, 0.55, 1.0))
	# Neighbouring lanes, dimmer.
	for off in [-48.0, 48.0]:
		_quad(off - 20.5, off + 20.5, -60.0, 770.0, Color("6b4e30") if not gang else Color("1e1830"))
	_quad(-26.0, 26.0, -60.0, 770.0, Color("30303a"))  # gutters
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, -200.0, 0.0, Color("c9a36c") if not gang else Color("2c2246"))  # approach
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 0.0, 762.0, Color("dcb47c") if not gang else Color("342a58"))  # lane bed
	# Boards, oil sheen, arrows, foul line, pin deck.
	for b in range(-19, 20, 3):
		var a := _p2(float(b), maxf(0.0, _cam_y + 8.0))
		var e := _p2(float(b), 740.0)
		c.draw_line(a, e, Color(0.5, 0.33, 0.18, 0.22) if not gang else Color(0.6, 0.3, 1, 0.18), 1.0)
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 0.0, 430.0, Color(1, 1, 1, 0.05))
	for k in 7:
		var ax := (k - 3) * 5.0
		var ay := 180.0 + absf(k - 3) * 9.0
		if ay > _cam_y + 10.0:
			c.draw_colored_polygon(PackedVector2Array([_p2(ax, ay + 8.0), _p2(ax - 1.4, ay), _p2(ax + 1.4, ay)]), Color(0.3, 0.12, 0.06, 0.8) if not gang else Color(1, 0.3, 0.9, 0.9))
	if _cam_y < -8.0:
		var fa := _p2(-26.0, 0.0)
		var fb := _p2(26.0, 0.0)
		c.draw_line(fa, fb, Color("d23a3a"), maxf(1.0, _proj(0, 0).z * 2.0))
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 708.0, 762.0, Color(1, 1, 1, 0.1))
	# The pit and the masking unit behind the pins.
	_quad(-26.0, 26.0, 762.0, 790.0, Color("0a0a10"))
	# The dark opening over the pin deck, with the lane's number lit above it.
	var mu_a := _p2(-30.0, 790.0, 0.0)
	var mu_b := _p2(30.0, 790.0, 22.0)
	c.draw_rect(Rect2(mu_a.x, mu_b.y, mu_b.x - mu_a.x, mu_a.y - mu_b.y), Color("120c10") if not gang else Color("0a0412"))
	var lc := [Color("f5486e"), Color("3fa9f5"), Color("f5c842"), Color("3fdc8c")][(lane - 1) % 4] as Color
	var fsz := clampi(int((mu_a.y - mu_b.y) * 0.5), 5, 20)
	c.draw_string(_font, Vector2(mu_a.x, mu_b.y + fsz * 0.9), str(lane), HORIZONTAL_ALIGNMENT_CENTER, mu_b.x - mu_a.x, fsz, Color(lc, 0.9))
	# Kickbacks (side walls by the pins).
	for sx in [-1.0, 1.0]:
		var k0 := _p2(sx * 26.0, 700.0, 0.0)
		var k1 := _p2(sx * 26.0, 790.0, 0.0)
		var k2 := _p2(sx * 26.0, 790.0, 18.0)
		var k3 := _p2(sx * 26.0, 700.0, 18.0)
		if _proj(0, 700.0).z > 0:
			c.draw_colored_polygon(PackedVector2Array([k0, k1, k2, k3]), Color("3a2e44"))
	# Pins and ball, far to near.
	var objs: Array = []
	for i in sim.pins.size():
		var p: Dictionary = sim.pins[i]
		if not bool(p["gone"]):
			objs.append([(p["p"] as Vector2).y, "pin", i])
	if phase != "over":
		objs.append([sim.ball_p.y, "ball", 0])
	objs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for o: Array in objs:
		if str(o[1]) == "pin":
			_draw_pin(sim.pins[int(o[2])])
		else:
			_draw_ball()
	# Aim guide.
	if phase in ["line", "aim"]:
		var a2 := deg_to_rad(aim)
		var hook := spin_step / 3.0
		var prev := _p2(x0, 0.0, 0.5)
		for k in range(1, 26):
			var yy := k * 28.0
			var xx := x0 + tan(a2) * yy
			if yy > Sim.HOOK_FROM:
				xx -= 0.5 * hook * 28.6 * pow((yy - Sim.HOOK_FROM) / 300.0, 2.0)
			var cur := _p2(xx, yy, 0.5)
			if k % 2 == 0:
				c.draw_line(prev, cur, Color(1, 1, 0.6, 0.65 if phase == "aim" else 0.3), 1.5)
			prev = cur
		if phase == "aim":
			var tip := _p2(x0 + tan(a2) * 120.0, 120.0, 0.5)
			c.draw_circle(tip, 3.0, Color(1, 0.9, 0.3))
	_draw_sheet()
	_draw_pin_chart()
	_draw_controls()
	if _msg_t > 0.0 and _msg != "":
		var big := _msg.ends_with("!")
		var sz := 22 if big else 12
		c.draw_string_outline(_font, Vector2(0, 190), _msg, HORIZONTAL_ALIGNMENT_CENTER, 270, sz, 5, Color(0, 0, 0, 0.8))
		c.draw_string(_font, Vector2(0, 190), _msg, HORIZONTAL_ALIGNMENT_CENTER, 270, sz, Color(1, 0.85, 0.3) if big else Color.WHITE)
	if phase == "over":
		_draw_final()


func _draw_pin(p: Dictionary) -> void:
	var pos: Vector2 = p["p"]
	var base := _proj(pos.x, pos.y, 0.0)
	if base.z <= 0:
		return
	var s := base.z
	var c := _canvas
	c.draw_circle(Vector2(base.x, base.y), maxf(1.0, 2.6 * s), Color(0, 0, 0, 0.25))
	var fall := float(p["fall"])
	if fall <= 0.01:
		# Standing: a pin profile, belly, neck and head, with the red stripes.
		var prof := [[0.0, 1.1], [2.0, 1.9], [4.5, 2.4], [7.0, 2.0], [9.5, 1.0], [11.0, 0.9], [13.2, 1.25], [15.0, 0.4]]
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for q: Array in prof:
			left.append(_p2(pos.x - float(q[1]), pos.y, float(q[0])))
			right.append(_p2(pos.x + float(q[1]), pos.y, float(q[0])))
		right.reverse()
		var poly := left + right
		if Geometry2D.triangulate_polygon(poly).is_empty():
			return
		c.draw_colored_polygon(poly, Color(0.97, 0.96, 0.93))
		c.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.5, 0.5, 0.55, 0.6), maxf(0.5, s * 0.6))
		for band in [9.3, 10.4]:
			var b0 := _p2(pos.x - 1.0, pos.y, band)
			var b1 := _p2(pos.x + 1.0, pos.y, band)
			c.draw_line(b0, b1, Color("d23a3a"), maxf(1.0, s * 0.9))
		var hl := _p2(pos.x - 0.9, pos.y, 5.5)
		c.draw_circle(hl, maxf(0.6, s * 0.6), Color(1, 1, 1, 0.8))
		return
	# Tipping over / lying down along its fall direction.
	var d: Vector2 = p["dir"]
	if d.length() < 0.1:
		d = Vector2.UP
	var th := fall * PI / 2.0
	var axis_h := cos(th)
	var axis_g := sin(th)
	var perp := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	var prof2 := [[0.0, 1.1], [4.5, 2.4], [9.5, 1.0], [13.2, 1.25], [15.0, 0.4]]
	var side_a := PackedVector2Array()
	var side_b := PackedVector2Array()
	for q: Array in prof2:
		var along := float(q[0])
		var r := float(q[1])
		var gp := pos + d * along * axis_g
		var hh := along * axis_h + r * axis_g * 0.8
		side_a.append(_p2(gp.x + perp.x * r, gp.y + perp.y * r, hh))
		side_b.append(_p2(gp.x - perp.x * r, gp.y - perp.y * r, hh))
	side_b.reverse()
	pts = side_a + side_b
	if Geometry2D.triangulate_polygon(pts).is_empty():
		c.draw_polyline(side_a, Color(0.9, 0.89, 0.86), maxf(1.0, s * 2.4))
		return
	c.draw_colored_polygon(pts, Color(0.9, 0.89, 0.86))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.45, 0.45, 0.5, 0.6), maxf(0.5, s * 0.5))


func _draw_ball() -> void:
	var b := sim.ball_p
	var hh := Sim.BALL_R - (2.5 if sim.gutter else 0.0)
	var ctr := _proj(b.x, b.y, hh)
	if ctr.z <= 0:
		return
	var r := Sim.BALL_R * ctr.z
	var c := _canvas
	var g := _proj(b.x, b.y, 0.0)
	c.draw_circle(Vector2(g.x, g.y), r * 0.9, Color(0, 0, 0, 0.3))
	var col := Color("2f6fd6") if GameState.is_penguins() else Color("e03aa0")
	c.draw_circle(Vector2(ctr.x, ctr.y), r, col)
	c.draw_circle(Vector2(ctr.x, ctr.y), r, col.darkened(0.4), false, maxf(0.8, r * 0.08))
	# Finger holes roll with the ball.
	var rot := b.y * 0.12
	for k in 3:
		var ang := rot + k * 0.45
		var hp := Vector2(ctr.x, ctr.y) + Vector2(cos(ang) * 0.35, sin(ang) * 0.5 - 0.1) * r
		if sin(ang) < 0.7:
			c.draw_circle(hp, maxf(0.8, r * 0.13), Color(0.05, 0.05, 0.1, 0.85))
	c.draw_circle(Vector2(ctr.x - r * 0.35, ctr.y - r * 0.4), maxf(0.8, r * 0.22), Color(1, 1, 1, 0.45))


## The overhead monitor: ten frames, marks and running totals.
func _draw_sheet() -> void:
	var c := _canvas
	var r := Rect2(4, 4, 262, 62)
	c.draw_rect(r, Color("1b1b26"))
	c.draw_rect(r, Color("5a5a70"), false, 1.0)
	var pname := str(GameState.run.get("names", {}).get("character", "You")) if GameState.run.size() > 0 else "You"
	c.draw_string(_font, Vector2(9, 15), "%s · LANE %d" % [pname.to_upper(), lane], HORIZONTAL_ALIGNMENT_LEFT, 150, 8, Color(0.75, 0.9, 1))
	var best := Tickets.best_score("bowling") if GameState.run.size() > 0 else 0
	c.draw_string(_font, Vector2(110, 15), "BEST %d" % best, HORIZONTAL_ALIGNMENT_LEFT, 80, 8, Color(1, 0.85, 0.4))
	var totals := frame_totals(rolls)
	var cur := int(next_state(rolls)["frame"]) if phase != "over" else -1
	var x := 8.0
	for f in 10:
		var w := 24.0 if f < 9 else 34.0
		var box := Rect2(x, 20, w, 40)
		c.draw_rect(box, Color("262636") if f != cur else Color("34345a"))
		c.draw_rect(box, Color("6a6a88"), false, 1.0)
		c.draw_string(_font, Vector2(x, 27), str(f + 1), HORIZONTAL_ALIGNMENT_CENTER, w, 6, Color(0.6, 0.6, 0.75))
		var marks := frame_marks(rolls, f)
		var nbox := 2 if f < 9 else 3
		for k in nbox:
			var mb := Rect2(x + w - (nbox - k) * 10.0, 29, 10, 10)
			c.draw_rect(mb, Color(0, 0, 0, 0.25))
			c.draw_rect(mb, Color("6a6a88"), false, 1.0)
			if k < marks.size() and str(marks[k]) != "":
				var mc := Color(1, 0.4, 0.4) if str(marks[k]) == "X" else (Color(0.5, 0.85, 1) if str(marks[k]) == "/" else Color.WHITE)
				c.draw_string(_font, Vector2(mb.position.x, mb.end.y - 2), str(marks[k]), HORIZONTAL_ALIGNMENT_CENTER, 10, 8, mc)
		if f < totals.size() and int(totals[f]) >= 0:
			c.draw_string(_font, Vector2(x, 56), str(int(totals[f])), HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color(1, 1, 0.85))
		x += w + 0.5


## The ten-pin chart (standing / down) beside the lane.
func _draw_pin_chart() -> void:
	var c := _canvas
	var o := Vector2(242, 92)
	c.draw_rect(Rect2(o.x - 22, o.y - 18, 44, 40), Color(0, 0, 0, 0.45))
	var k := 0
	for row in 4:
		for i in row + 1:
			var p := o + Vector2((i - row / 2.0) * 10.0, 14.0 - row * 9.0)
			var pin: Dictionary = sim.pins[k] if k < sim.pins.size() else {}
			var down := pin.is_empty() or bool(pin.get("down", false)) or bool(pin.get("gone", false))
			var was := k < _was_down.size() and bool(_was_down[k])
			var col := Color(0.25, 0.25, 0.3) if (down and was) else (Color(1, 0.35, 0.3) if down else Color(0.97, 0.96, 0.93))
			c.draw_circle(p, 3.4, col)
			k += 1


func _btn(r: Rect2, text: String, on := true, hot := false) -> void:
	var c := _canvas
	c.draw_rect(r, Color(0.1, 0.1, 0.16, 0.85) if not hot else Color(0.35, 0.25, 0.08, 0.95))
	c.draw_rect(r, Color(1, 1, 1, 0.5 if on else 0.15), false, 1.0)
	c.draw_string(_font, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 4), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 1, 1, 1.0 if on else 0.35))


func _draw_controls() -> void:
	var c := _canvas
	var tip := ""
	match phase:
		"line": tip = "◀ ▶ line up · ▲▼ spin · USE"
		"aim": tip = "USE to lock the aim"
		"power": tip = "USE to throw!"
		"roll": tip = ""
		"result": tip = ""
	c.draw_rect(Rect2(0, 372, 270, 108), Color(0.05, 0.04, 0.08, 0.9))
	if tip != "":
		c.draw_string(_font, Vector2(0, 388), tip, HORIZONTAL_ALIGNMENT_CENTER, 270, 8, Color(0.85, 0.85, 1))
	var line := phase == "line"
	_btn(BTN_L, "◀", line)
	_btn(BTN_R, "▶", line)
	_btn(BTN_SPIN_L, "↶", line)
	_btn(BTN_SPIN_R, "↷", line)
	_btn(BTN_GO, "GO" if phase in ["line", "aim", "power"] else "OK", phase != "roll", phase in ["aim", "power"])
	_btn(BTN_QUIT, "✕", true)
	# Spin dial.
	var sc := Vector2(52, 474)
	for s in range(-3, 4):
		var dx := sc.x + s * 6.0
		c.draw_rect(Rect2(dx - 2, sc.y - 3, 4, 3), Color(1, 0.8, 0.3) if s == spin_step else Color(1, 1, 1, 0.2))
	# Power meter on the right of the lane.
	if phase in ["power", "roll", "result"]:
		var pr := Rect2(250, 140, 12, 120)
		c.draw_rect(pr, Color(0, 0, 0, 0.6))
		var h := pr.size.y * power
		var pc := Color(0.3, 1, 0.4).lerp(Color(1, 0.3, 0.2), power)
		c.draw_rect(Rect2(pr.position.x + 2, pr.end.y - h, pr.size.x - 4, h), pc)
		c.draw_rect(pr, Color(1, 1, 1, 0.5), false, 1.0)
		c.draw_string(_font, Vector2(pr.position.x - 10, pr.end.y + 10), "POWER", HORIZONTAL_ALIGNMENT_CENTER, 32, 6, Color(1, 1, 1, 0.7))
	var spin_txt := "straight" if spin_step == 0 else ("hook %s %d" % ["◀" if spin_step > 0 else "▶", absi(spin_step)])
	c.draw_string(_font, Vector2(150, 474), "spin: " + spin_txt, HORIZONTAL_ALIGNMENT_LEFT, 120, 7, Color(1, 1, 1, 0.6))


func _draw_final() -> void:
	var c := _canvas
	var r := Rect2(30, 120, 210, 170)
	c.draw_rect(r, Color(0.08, 0.06, 0.12, 0.96))
	c.draw_rect(r, Color(1, 0.85, 0.3, 0.9), false, 2.0)
	var sc := int(result.get("score", 0))
	var best := Tickets.best_score("bowling") if GameState.run.size() > 0 else 0
	c.draw_string(_font, Vector2(r.position.x, r.position.y + 24), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 0.85, 0.3))
	c.draw_string(_font, Vector2(r.position.x, r.position.y + 62), str(sc), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color.WHITE)
	c.draw_string(_font, Vector2(r.position.x, r.position.y + 84), "%d strikes · %d spares" % [int(result.get("strikes", 0)), int(result.get("spares", 0))], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Color(0.8, 0.85, 1))
	var t := Tickets.payout("bowling", RecCenter.tickets_for(sc, int(result.get("strikes", 0)), int(result.get("spares", 0))))
	c.draw_string(_font, Vector2(r.position.x, r.position.y + 108), "+%d tickets" % t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1, 0.7, 0.9))
	if sc > best:
		c.draw_string(_font, Vector2(r.position.x, r.position.y + 128), "NEW PERSONAL BEST!", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 0.9, 0.3, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)))
	c.draw_string(_font, Vector2(r.position.x, r.end.y - 12), "USE to finish", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(1, 1, 1, 0.7))
