class_name ArcadeGame
extends CanvasLayer
## Base for every arcade cabinet in the Recreation Center: a full-screen,
## tree-pausing UI (like HackGame) with
##   * a cabinet frame: top bar (title, tickets, score), play area, control deck;
##   * its own touch deck at the bottom whose buttons press the input actions
##     (up/down/left/right/a/b), so the game only polls actions;
##   * insert-coin title card -> play -> results (tickets paid by Tickets);
##   * fixed 60 Hz steps (tick) so tests can drive it frame by frame;
##   * particles, floating text and screen shake helpers.
## Subclasses set GAME_ID/TITLE/FEE in _init and override _setup_round,
## _step, _draw_play, _tickets_for and, if they like, _deck / _tap.

signal closed

const W := 270.0
const H := 480.0
const TOP := 24.0          # play area starts under the top bar
const DECK := 352.0        # control deck starts here
const PLAY := Rect2(0, 24, 270, 328)
const DT := 1.0 / 60.0
const ACTIONS := ["up", "down", "left", "right", "a", "b"]

var game_id := ""
var title := ""
var fee := 10
var howto: Array = []       # lines on the title card
var accent := Color(1.0, 0.75, 0.2)
var state := "title"        # title | play | over (subclasses may add their own)
var score := 0
var won_tickets := 0
var new_best := false
var over_lines: Array = []  # extra lines on the results card
var message := ""
var message_t := 0.0
var manual := false         # tests drive tick() themselves
var bot: Dictionary = {}    # tests: action -> held
var t := 0.0                # seconds since open (draw animation clock)
var play_t := 0.0           # seconds in the current round
var rng := RandomNumberGenerator.new()

var _canvas: Control
var _font: Font
var _acc := 0.0
var _prev := {}
var _held := {}
var _jp := {}
var _first_sub := true
var _arm := 0
var _touch := {}            # touch index -> action
var _mouse_action := ""
var _deck: Array = []       # [{action, rect, label, skin}]
var _parts: Array = []      # particles
var _floats: Array = []
var _shake := 0.0
var _was_paused := false
var _prev_track := ""
var draw_off := Vector2.ZERO  # this frame's shake offset (reset transforms to it)


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	Hud.modal_rect = Rect2(0, 0, W, H)
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # the art is 2x detail
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	_prev_track = Music.instance(get_tree())._current
	_start_music()
	_deck = _deck_buttons()
	for b: Dictionary in _deck:
		Hud.extra_rects.append(b["rect"])
	_opened()


## Cabinet music (Block Jumper has its own chiptune; the rest share the hall loop).
func _start_music() -> void:
	Music.instance(get_tree()).play("arcade_hall")


## The game's own buttons on the deck. Default: d-pad left, A and B right.
func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(8, 392, 40, 40), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(92, 392, 40, 40), "label": "▶", "skin": "blue"},
		{"action": "up", "rect": Rect2(50, 360, 40, 36), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(50, 430, 40, 36), "label": "▼", "skin": "blue"},
		{"action": "a", "rect": Rect2(196, 378, 64, 64), "label": "A", "skin": "gold"},
		{"action": "b", "rect": Rect2(150, 430, 40, 40), "label": "B", "skin": "red"},
	]


## Called once the screen exists (jumper opens its level select here).
func _opened() -> void:
	pass


# --- input -------------------------------------------------------------------

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			var a := _deck_at(st.position)
			if a != "":
				_touch[st.index] = a
				Input.action_press(a)
			elif PLAY.has_point(st.position):
				_tap(st.position)
		elif _touch.has(st.index):
			Input.action_release(str(_touch[st.index]))
			_touch.erase(st.index)
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		# Sliding a thumb from one deck button to another (◀ to ▶) follows it.
		if _touch.has(sd.index):
			var a2 := _deck_at(sd.position)
			if a2 != "" and a2 != str(_touch[sd.index]):
				Input.action_release(str(_touch[sd.index]))
				_touch[sd.index] = a2
				Input.action_press(a2)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var a3 := _deck_at(mb.position)
			if a3 != "":
				_mouse_action = a3
				Input.action_press(a3)
			elif PLAY.has_point(mb.position):
				_tap(mb.position)
		elif _mouse_action != "":
			Input.action_release(_mouse_action)
			_mouse_action = ""
		get_viewport().set_input_as_handled()


func _deck_at(p: Vector2) -> String:
	for b: Dictionary in _deck:
		if (b["rect"] as Rect2).grow(3).has_point(p):
			return str(b["action"])
	return ""


## A tap inside the play area (whack and gallery aim with it).
func _tap(_p: Vector2) -> void:
	pass


func held(a: String) -> bool:
	return bool(_held.get(a, false))


func pressed(a: String) -> bool:
	return bool(_jp.get(a, false))


func _read_input() -> void:
	for a in ACTIONS:
		var h: bool
		var j := false
		if not bot.is_empty() or manual:
			h = bool(bot.get(a, false))
		else:
			h = Input.is_action_pressed(a)
			# A tap shorter than a frame still counts (once, on the first sub-step).
			j = _first_sub and Input.is_action_just_pressed(a)
		_jp[a] = (h and not bool(_prev.get(a, false))) or j
		_held[a] = h
		_prev[a] = h
	if _arm < 6:  # the press that opened the cabinet must not also start it
		for a in ACTIONS:
			_jp[a] = false


# --- loop --------------------------------------------------------------------

func _process(delta: float) -> void:
	if manual:
		return
	tick(minf(delta, 0.1))


## Advance by real seconds (in fixed 60 Hz steps).
func tick(delta: float) -> void:
	t += delta
	_acc += delta
	_first_sub = true
	var n := 0
	while _acc >= DT - 0.0001 and n < 6:
		_acc -= DT
		n += 1
		frame()
		_first_sub = false
		if not is_inside_tree() or is_queued_for_deletion():
			return
	if _canvas:
		_canvas.queue_redraw()


## One fixed step.
func frame() -> void:
	_arm += 1
	_read_input()
	message_t = maxf(0.0, message_t - DT)
	_shake = maxf(0.0, _shake - DT * 18.0)
	_step_fx()
	match state:
		"title":
			if pressed("a"):
				start()
			elif pressed("b"):
				close()
		"play":
			play_t += DT
			_step(DT)
		"over":
			if play_t > 0.0:
				play_t = 0.0
			_over_t += DT
			if _over_t > 0.6 and pressed("a"):
				_after_over()
			elif _over_t > 0.3 and pressed("b"):
				close()
		_:
			_step_state(state, DT)


var _over_t := 0.0


## Insert coin and start a round. False (with a message) when you can't pay.
func start() -> bool:
	if not ArcadeHub.charge(fee):
		say("Not enough %s (%d)." % [ArcadeHub.money_word(), fee])
		sfx("nope", "locked")
		return false
	sfx("coin")
	score = 0
	won_tickets = 0
	new_best = false
	over_lines = []
	play_t = 0.0
	_parts.clear()
	_floats.clear()
	ArcadeHub.mark_played(game_id)
	_setup_round()
	state = "play"
	return true


## End the round: pay tickets, record the best score, show results.
func game_over(extra_lines: Array = []) -> void:
	if state == "over":
		return
	over_lines = extra_lines
	won_tickets = maxi(0, _tickets_for(score))
	if won_tickets > 0:
		Tickets.add(won_tickets, game_id)
	new_best = Tickets.set_best(game_id, score)
	ArcadeHub.check_milestones(game_id, score, self)
	_over_t = 0.0
	state = "over"
	if won_tickets >= _good_tickets():
		sfx("j_victory", "levelup")
	else:
		sfx("j_battle_lost", "nope")


## What A does on the results card (default: back to the title card).
func _after_over() -> void:
	state = "title"


func _good_tickets() -> int:
	return 15


func close() -> void:
	if not is_inside_tree():
		return
	for a in ACTIONS:
		Input.action_release(a)
	for b: Dictionary in _deck:
		Hud.extra_rects.erase(b["rect"])
	get_tree().paused = _was_paused
	if _prev_track != "":
		Music.instance(get_tree()).play(_prev_track)
	Hud.modal_rect = Rect2()
	Dialogue.block_input(0.3)
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	for b: Dictionary in _deck:
		Hud.extra_rects.erase(b["rect"])


# --- overridables --------------------------------------------------------------

func _setup_round() -> void:
	pass


func _step(_dt: float) -> void:
	pass


func _step_state(_s: String, _dt: float) -> void:
	pass


func _tickets_for(_s: int) -> int:
	return 0


func _draw_play(_c: Control) -> void:
	pass


## Extra drawing on top of the title card's art box (Rect2(35, 80, 200, 120)).
func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, accent.darkened(0.6))
	draw_cabinet(c, r)


## The cabinet's own art, standing in the middle of a box.
func draw_cabinet(c: Control, r: Rect2) -> void:
	spr(c, "cabinet_" + game_id, Rect2(r.position.x + r.size.x * 0.5 - 40, r.position.y + 4, 80, r.size.y - 6))


# --- fx ----------------------------------------------------------------------

func sfx(name: String, fallback := "") -> void:
	if is_inside_tree():
		Music.instance(get_tree()).sfx(name, fallback)


func say(text: String, secs := 1.6) -> void:
	message = text
	message_t = secs


func burst(p: Vector2, col: Color, n := 10, speed := 70.0, size := 2.0, grav := 160.0) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var s := speed * (0.4 + rng.randf() * 0.8)
		_parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * s, "life": 0.4 + rng.randf() * 0.4, "max": 0.8, "c": col, "s": size, "g": grav})


func float_text(p: Vector2, text: String, col := Color(1, 0.95, 0.5)) -> void:
	_floats.append({"p": p, "text": text, "c": col, "life": 0.9})


func shake(a := 3.0) -> void:
	_shake = maxf(_shake, a)


func _step_fx() -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q["life"] = float(q["life"]) - DT
		if float(q["life"]) <= 0.0:
			_parts.remove_at(i)
			continue
		q["v"] = (q["v"] as Vector2) + Vector2(0, float(q["g"]) * DT)
		q["p"] = (q["p"] as Vector2) + (q["v"] as Vector2) * DT
	for i in range(_floats.size() - 1, -1, -1):
		var f: Dictionary = _floats[i]
		f["life"] = float(f["life"]) - DT
		f["p"] = (f["p"] as Vector2) + Vector2(0, -22 * DT)
		if float(f["life"]) <= 0.0:
			_floats.remove_at(i)


## Particles in play-area space (offset added by the caller's draw transform).
func draw_fx(c: Control, off := Vector2.ZERO) -> void:
	for q: Dictionary in _parts:
		var a := clampf(float(q["life"]) / 0.4, 0.0, 1.0)
		var col: Color = q["c"]
		col.a *= a
		var s := float(q["s"])
		c.draw_rect(Rect2((q["p"] as Vector2) + off - Vector2(s, s) * 0.5, Vector2(s, s)), col)
	for f: Dictionary in _floats:
		var col2: Color = f["c"]
		col2.a = clampf(float(f["life"]) * 2.0, 0.0, 1.0)
		text_outline(c, (f["p"] as Vector2) + off + Vector2(-40, 0), str(f["text"]), 80, 8, col2, HORIZONTAL_ALIGNMENT_CENTER)


# --- drawing -----------------------------------------------------------------

func text(c: Control, p: Vector2, s: String, w: float, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(_font, p, s, align, w, size, col)


func text_outline(c: Control, p: Vector2, s: String, w: float, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string_outline(_font, p, s, align, w, size, 3, Color(0.05, 0.03, 0.08, col.a))
	c.draw_string(_font, p, s, align, w, size, col)


## Arcade art (art/gen/arcade, sliced by tools/slice_r13_arcade.py).
static func tex(name: String) -> Texture2D:
	return Art.tex("arcade", name)


## Draws an arcade sprite fitted into r (keeps aspect, bottom-centred). False if missing.
func spr(c: CanvasItem, name: String, r: Rect2, col := Color.WHITE, flip := false) -> bool:
	var tx := tex(name)
	if tx == null:
		return false
	var sz := Vector2(tx.get_size())
	var f := minf(r.size.x / sz.x, r.size.y / sz.y)
	var d := sz * f
	var p := Vector2(r.position.x + (r.size.x - d.x) * 0.5, r.end.y - d.y)
	if flip:
		c.draw_texture_rect(tx, Rect2(p + Vector2(d.x, 0), Vector2(-d.x, d.y)), false, col)
	else:
		c.draw_texture_rect(tx, Rect2(p, d), false, col)
	return true


## Draws a sprite at a given height, bottom-centred on foot.
func spr_h(c: CanvasItem, name: String, foot: Vector2, h: float, col := Color.WHITE, flip := false) -> bool:
	var tx := tex(name)
	if tx == null:
		return false
	var sz := Vector2(tx.get_size())
	var w := sz.x * h / sz.y
	return spr(c, name, Rect2(foot.x - w * 0.5, foot.y - h, w, h), col, flip)


## Fills dest with a texture, cropping the overflow (ay: 0 keeps the top, 1 the bottom).
func cover(c: CanvasItem, name: String, dest: Rect2, ay := 0.5, col := Color.WHITE) -> bool:
	var tx := tex(name)
	if tx == null:
		return false
	var sz := Vector2(tx.get_size())
	var f := maxf(dest.size.x / sz.x, dest.size.y / sz.y)
	var src_sz := dest.size / f
	var src := Rect2(Vector2((sz.x - src_sz.x) * 0.5, (sz.y - src_sz.y) * ay), src_sz)
	c.draw_texture_rect_region(tx, dest, src, col)
	return true


func panel(c: Control, r: Rect2, fill: Color, edge: Color) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r, edge, false, 1.0)
	c.draw_rect(r.grow(-2), Color(1, 1, 1, 0.05), false, 1.0)


func _draw_all() -> void:
	var c := _canvas
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(rng.randf_range(-_shake, _shake), rng.randf_range(-_shake, _shake)).round()
	# Play area (clipped by drawing the frame over it afterwards).
	c.draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.04, 0.1))
	draw_off = sh
	c.draw_set_transform(sh)
	match state:
		"title":
			_draw_title(c)
		"over":
			_draw_play(c)
			_draw_over(c)
		_:
			_draw_play(c)
	c.draw_set_transform(Vector2.ZERO)
	_draw_frame(c)
	if message_t > 0.0 and message != "":
		var a := clampf(message_t * 3.0, 0.0, 1.0)
		panel(c, Rect2(20, 318, 230, 22), Color(0.08, 0.05, 0.14, 0.92 * a), Color(accent, a))
		text(c, Vector2(20, 333), message, 230, 9, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_frame(c: Control) -> void:
	# Top bar.
	c.draw_rect(Rect2(0, 0, W, TOP), Color(0.12, 0.07, 0.2))
	c.draw_rect(Rect2(0, TOP - 2, W, 2), accent)
	text_outline(c, Vector2(6, 16), title.to_upper(), 130, 10, accent)
	_ticket_icon(c, Vector2(150, 7))
	text(c, Vector2(164, 16), str(Tickets.count()), 50, 9, Color(1, 0.9, 0.6))
	text(c, Vector2(186, 16), _top_right(), 80, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Control deck.
	c.draw_rect(Rect2(0, DECK, W, H - DECK), Color(0.14, 0.09, 0.22))
	c.draw_rect(Rect2(0, DECK, W, 2), accent)
	for i in 16:  # speaker-grille dots
		c.draw_circle(Vector2(140 + (i % 4) * 6, 362 + (i / 4) * 6), 1.2, Color(0, 0, 0, 0.35))
	for b: Dictionary in _deck:
		_draw_button(c, b)


const SKIN_COL := {"gold": Color(0.95, 0.72, 0.18), "red": Color(0.9, 0.3, 0.3), "blue": Color(0.3, 0.55, 0.95), "green": Color(0.35, 0.8, 0.4)}


func _draw_button(c: Control, b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var down := held(str(b["action"])) or Input.is_action_pressed(str(b["action"]))
	var skin := str(b.get("skin", "blue"))
	var tex := Art.tex("ui", "btn_%s%s" % [skin, "_down" if down else ""]) if Art.has("ui", "btn_" + skin) else null
	var ctr := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.5
	if tex:
		c.draw_texture_rect(tex, Rect2(ctr - Vector2(rad, rad), Vector2(rad, rad) * 2), false)
	else:
		var col: Color = SKIN_COL.get(skin, Color.GRAY)
		c.draw_circle(ctr + Vector2(0, 2), rad, col.darkened(0.5))
		c.draw_circle(ctr + (Vector2(0, 2) if down else Vector2.ZERO), rad - 1, col.darkened(0.2) if down else col)
	var fs := 14 if str(b["label"]).length() <= 1 else 8
	text_outline(c, Vector2(r.position.x - 10, ctr.y + fs * 0.35 + (1 if down else 0)), str(b["label"]), r.size.x + 20, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var hint := str(b.get("hint", ""))
	if hint != "":
		text(c, Vector2(r.position.x - 14, r.end.y + 7), hint, r.size.x + 28, 6, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)


func _top_right() -> String:
	return "%d" % score if state != "title" else "BEST %d" % Tickets.best_score(game_id)


func _ticket_icon(c: Control, p: Vector2) -> void:
	var r := Rect2(p, Vector2(11, 8))
	c.draw_rect(r, Color(0.95, 0.3, 0.35))
	c.draw_rect(r.grow(-1.5), Color(1, 0.85, 0.4), false, 1.0)
	c.draw_circle(p + Vector2(0, 4), 1.5, Color(0.12, 0.07, 0.2))
	c.draw_circle(p + Vector2(11, 4), 1.5, Color(0.12, 0.07, 0.2))


func _draw_title(c: Control) -> void:
	# Attract-mode backdrop: slow diagonal stripes in the cabinet colour.
	c.draw_rect(PLAY, accent.darkened(0.82))
	for i in 14:
		var x := fmod(i * 40.0 + t * 12.0, 560.0) - 280.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 352), Vector2(x + 20, 352), Vector2(x + 300, 24), Vector2(x + 280, 24)]), Color(accent, 0.05))
	var mr := Rect2(35, 44, 200, 110)
	panel(c, mr.grow(3), Color(0.05, 0.03, 0.08), accent)
	_draw_marquee(c, mr)
	text_outline(c, Vector2(0, 178), title.to_upper(), W, 16, accent, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 198.0
	for line in howto:
		text(c, Vector2(16, y), str(line), W - 32, 8, Color(0.92, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
		y += 12.0
	text(c, Vector2(0, 272), "Best: %d" % Tickets.best_score(game_id), W, 9, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	var blink := fmod(t, 1.0) < 0.65
	panel(c, Rect2(55, 284, 160, 24), Color(0.1, 0.05, 0.12), accent)
	if blink:
		text_outline(c, Vector2(55, 300), "A: INSERT %d %s" % [fee, ArcadeHub.money_word().to_upper()], 160, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(0, 322), "You have %d · B: leave" % ArcadeHub.money(), W, 8, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_over(c: Control) -> void:
	c.draw_rect(PLAY, Color(0, 0, 0, 0.55))
	var r := Rect2(30, 90, 210, 170)
	panel(c, r, Color(0.1, 0.06, 0.16, 0.97), accent)
	text_outline(c, Vector2(r.position.x, r.position.y + 24), "GAME OVER" if over_lines.is_empty() or not str(over_lines[0]).begins_with("!") else str(over_lines[0]).substr(1), r.size.x, 14, accent, HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(r.position.x, r.position.y + 48), "Score  %d" % score, r.size.x, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if new_best and score > 0:
		var pulse := 0.7 + 0.3 * sin(t * 8.0)
		text_outline(c, Vector2(r.position.x, r.position.y + 64), "NEW BEST!", r.size.x, 10, Color(1, 0.95, 0.4, pulse), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		text(c, Vector2(r.position.x, r.position.y + 64), "Best  %d" % Tickets.best_score(game_id), r.size.x, 9, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var y := r.position.y + 82
	for line in over_lines:
		if str(line).begins_with("!"):
			continue
		text(c, Vector2(r.position.x + 6, y), str(line), r.size.x - 12, 8, Color(0.9, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
		y += 11
	_ticket_icon(c, Vector2(r.position.x + 62, r.end.y - 50))
	text_outline(c, Vector2(r.position.x + 78, r.end.y - 42), "+%d tickets" % won_tickets, 120, 11, Color(1, 0.85, 0.4))
	if _over_t > 0.6:
		text(c, Vector2(r.position.x, r.end.y - 14), "A: again   B: leave", r.size.x, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
