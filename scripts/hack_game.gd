class_name HackGame
extends CanvasLayer
## The Hacking Terminal's daily hack: watch a string of arrows light up, then
## repeat it by tapping the arrows (or the arrow keys). Three rounds,
## each one longer. Clean run: heat −1 and a data chip; partial: some gold.

signal closed
var quit := false

const DIRS := ["up", "right", "down", "left"]
const GLYPH := {"up": "▲", "right": "▶", "down": "▼", "left": "◀"}
## On-screen way out: under a full-screen panel the touch B button is hidden.
const BTN_UNPLUG := Rect2(85, 436, 100, 28)
const POS := {"up": Vector2(135, 200), "right": Vector2(185, 250), "down": Vector2(135, 300), "left": Vector2(85, 250)}

var tier := 1
var _seq: Array = []
var _at := 0
var _round := 0
var _showing := true
var _lit := ""
var _lit_t := 0.0
var _msg := ""
var _canvas: Control
var _arm := 0
var _wins := 0
var result := 0   # rounds cleared


static func play(m: GameMap, t: int) -> int:
	var g := HackGame.new()
	g.tier = clampi(t, 1, 4)
	m.add_child(g)
	await g.closed
	# Walking away mid-hack banks nothing.
	return -1 if g.quit else g.result


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "hack_game")
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_it)
	_canvas.gui_input.connect(_tap)
	add_child(_canvas)
	_next_round()


func _next_round() -> void:
	_round += 1
	_seq.clear()
	for i in 2 + tier + _round:
		_seq.append(DIRS[randi() % 4])
	_at = 0
	_msg = "Round %d of 3: watch the wire..." % _round
	_play_back()


func _play_back() -> void:
	_showing = true
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	var gap := maxf(0.28, 0.55 - 0.05 * _round)
	for d in _seq:
		if not is_inside_tree():
			return
		_lit = str(d)
		_lit_t = gap * 0.8
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
		await get_tree().create_timer(gap).timeout
	if not is_inside_tree():
		return
	_lit = ""
	_showing = false
	_msg = "Your turn: repeat it (%d)." % _seq.size()


func _process(delta: float) -> void:
	_arm += 1
	_lit_t = maxf(0.0, _lit_t - delta)
	if _lit_t <= 0.0 and not _showing:
		_lit = ""
	_canvas.queue_redraw()
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b"):
		quit = true
		_finish()
		return
	if _showing:
		return
	if PadInput.using_pad():
		# A stick wobbles and crosses diagonals: one arrow per push, by its main
		# direction, and only after it came back to the middle (C9 c9_02).
		var pv := Input.get_vector("left", "right", "up", "down")
		var dir := HackGame.pad_dir(pv)
		if pv.length() < PAD_REST:
			_neutral = true
		elif dir != "" and _neutral:
			_neutral = false
			_press(dir)
		return
	for d in DIRS:
		if Input.is_action_just_pressed(d):
			_press(d)
			break  # one arrow per frame: a diagonal must not press two


## The arrow a stick/d-pad vector means ("" near the middle).
const PAD_PUSH := 0.5
const PAD_REST := 0.3
static func pad_dir(v: Vector2) -> String:
	if v.length() < PAD_PUSH:
		return ""
	if absf(v.x) >= absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


var _neutral := true


func _tap(ev: InputEvent) -> void:
	var p := TapInput.press_pos(ev)  # the touch, not also its emulated mouse copy
	if p == Vector2.INF or _arm < 8:
		return
	if BTN_UNPLUG.grow(2).has_point(p):
		quit = true
		_finish()
		return
	if _showing:
		return
	for d in DIRS:
		if p.distance_to(POS[d]) < 26.0:
			_press(d)


func _press(d: String) -> void:
	Music.instance(get_tree()).sfx("keypress", "ui_tap")
	if _showing or _at >= _seq.size():
		return
	_lit = d
	_lit_t = 0.15
	if d == str(_seq[_at]):
		_at += 1
		Music.instance(get_tree()).sfx("ui_tap", "pickup")
		if _at >= _seq.size():
			result += 1
			if _round >= 3:
				_msg = "You're in. Clean run."
				_showing = true
				await get_tree().create_timer(0.8).timeout
				if is_inside_tree():
					_finish()
			else:
				_msg = "Got it."
				_showing = true
				await get_tree().create_timer(0.6).timeout
				if is_inside_tree():
					_next_round()
	else:
		Music.instance(get_tree()).sfx("hurt")
		_msg = "Alarm tripped. You pull the plug."
		_showing = true
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			_finish()


func _finish() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _draw_it() -> void:
	var f := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(0, 0, 270, 480), Color(0.02, 0.05, 0.06, 0.94))
	# scanlines
	for y in range(0, 480, 4):
		_canvas.draw_line(Vector2(0, y), Vector2(270, y), Color(0.2, 1, 0.8, 0.04))
	_canvas.draw_string(f, Vector2(0, 110), "HACKING TERMINAL", HORIZONTAL_ALIGNMENT_CENTER, 270, 12, Color(0.4, 1, 0.85))
	_canvas.draw_string(f, Vector2(0, 130), _msg, HORIZONTAL_ALIGNMENT_CENTER, 270, 8, Color(0.75, 1, 0.9))
	for d in DIRS:
		var p: Vector2 = POS[d]
		var on: bool = _lit == d
		_canvas.draw_circle(p, 22.0, Color(0.2, 1, 0.8, 0.85) if on else Color(0.05, 0.2, 0.2, 0.9))
		_canvas.draw_arc(p, 22.0, 0, TAU, 32, Color(0.4, 1, 0.85), 1.5, true)
		_canvas.draw_string(f, p + Vector2(-11, 6), str(GLYPH[d]), HORIZONTAL_ALIGNMENT_CENTER, 22, 14, Color(0.02, 0.1, 0.1) if on else Color(0.5, 1, 0.9))
	# progress pips
	for i in _seq.size():
		var c := Color(0.4, 1, 0.85) if i < _at else Color(0.2, 0.4, 0.4)
		_canvas.draw_circle(Vector2(135 - _seq.size() * 6 + i * 12 + 6, 350), 4.0, c)
	_canvas.draw_string(f, Vector2(0, 420), "Tap the arrows (or arrow keys) · B to unplug", HORIZONTAL_ALIGNMENT_CENTER, 270, 7, Color(0.5, 0.8, 0.75))
	_canvas.draw_rect(BTN_UNPLUG, Color(0.05, 0.2, 0.2, 0.9))
	_canvas.draw_rect(BTN_UNPLUG, Color(0.4, 1, 0.85), false, 1.0)
	_canvas.draw_string(f, Vector2(BTN_UNPLUG.position.x, BTN_UNPLUG.position.y + 18), "UNPLUG", HORIZONTAL_ALIGNMENT_CENTER, BTN_UNPLUG.size.x, 10, Color(0.5, 1, 0.9))
