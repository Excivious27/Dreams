class_name PrizeScreen
extends CanvasLayer
## The Rec Center prize counter: prizes by tier, priced in tickets. Locked prizes
## show the milestone that opens them (Tickets.lock_text). UP/DOWN pick, LEFT/RIGHT
## change shelf, USE buys, B leaves. Touch: tap a shelf tab, tap a prize, tap BUY.

signal closed

const TIERS := ["Treats", "Toys", "Prizes", "Grand"]
const ROW_H := 34.0
const LIST_Y := 98.0
const BTN_BUY := Rect2(150, 420, 100, 34)
const BTN_CLOSE := Rect2(20, 420, 100, 34)

var map: GameMap
var tier := 0
var sel := 0
var _rows: Array = []
var _canvas: Control
var _font: Font
var _arm := 0
var _flash := ""
var _flash_t := 0.0
var _flash_good := true
var bought := 0


static func open(m: GameMap) -> int:
	var t := int(GameState.run["time"]) % 1440
	if t < 9 * 60 or t >= 24 * 60 - 30:
		m.hud.toast("The prize counter's shutter is down. Opens at 9am.", Color(1, 0.85, 0.7))
		return 0
	var s := PrizeScreen.new()
	s.map = m
	m.add_child(s)
	await s.closed
	return s.bought


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	get_tree().paused = true
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_it)
	_canvas.gui_input.connect(_tap)
	add_child(_canvas)
	_fill()


func _fill() -> void:
	_rows.clear()
	var pz: Dictionary = Tickets.prizes()
	var all: Dictionary = pz.get("prizes", {})
	for id in pz.get("order", all.keys()):
		var p: Dictionary = all.get(id, {})
		if p.is_empty() or int(p.get("tier", 1)) != tier + 1:
			continue
		var it: Dictionary = GameState.items.get(str(p.get("item", id)), {})
		if it.has("arc") and str(it["arc"]) != str(GameState.run.get("arc", "")):
			continue
		_rows.append(str(id))
	sel = clampi(sel, 0, maxi(0, _rows.size() - 1))


func _process(delta: float) -> void:
	_arm += 1
	_flash_t = maxf(0.0, _flash_t - delta)
	_canvas.queue_redraw()
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		_close()
		return
	if Input.is_action_just_pressed("left"):
		_tier(tier - 1)
	elif Input.is_action_just_pressed("right"):
		_tier(tier + 1)
	elif Input.is_action_just_pressed("up"):
		sel = maxi(0, sel - 1)
		Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")
	elif Input.is_action_just_pressed("down"):
		sel = mini(_rows.size() - 1, sel + 1)
		Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")
	elif Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action"):
		_buy()


func _tier(t: int) -> void:
	tier = wrapi(t, 0, TIERS.size())
	sel = 0
	_fill()
	Music.instance(get_tree()).sfx("tab", "ui_tap")


func _buy() -> void:
	if sel < 0 or sel >= _rows.size():
		return
	var id: String = _rows[sel]
	var why := Tickets.buy(id)
	if why == "":
		bought += 1
		var p := Tickets.prize(id)
		var item := str(p.get("item", id))
		_flash = "Got it: %s!" % GameState.item_name(item)
		_flash_good = true
		Music.instance(get_tree()).sfx("j_buy", "coin")
		if str(GameState.items.get(item, {}).get("type", "")) == "decor":
			_flash += "  (It's in your house now.)"
	else:
		_flash = why
		_flash_good = false
		Music.instance(get_tree()).sfx("nope", "ui_tap")
	_flash_t = 2.2


func _close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _tab_rect(i: int) -> Rect2:
	return Rect2(10 + i * 63.0, 66, 60, 22)


func _tap(ev: InputEvent) -> void:
	var p := Vector2.INF
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		p = (ev as InputEventMouseButton).position
	elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		p = (ev as InputEventScreenTouch).position
	if p == Vector2.INF:
		return
	if BTN_CLOSE.has_point(p):
		_close()
		return
	if BTN_BUY.has_point(p):
		_buy()
		return
	for i in TIERS.size():
		if _tab_rect(i).has_point(p):
			_tier(i)
			return
	var row := int(floor((p.y - LIST_Y) / ROW_H))
	if p.y >= LIST_Y and row >= 0 and row < _rows.size() and p.x > 10 and p.x < 260:
		if row == sel:
			_buy()
		else:
			sel = row
			Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")


func _draw_it() -> void:
	var c := _canvas
	var gang := not GameState.is_penguins()
	c.draw_rect(Rect2(0, 0, 270, 480), Color(0.07, 0.04, 0.1) if gang else Color(0.16, 0.07, 0.1))
	# Striped awning like the prize counter's.
	for i in 14:
		c.draw_rect(Rect2(i * 20.0, 0, 10, 14), Color("c8323c") if not gang else Color("b02aa0"))
		c.draw_rect(Rect2(i * 20.0 + 10, 0, 10, 14), Color("f2e6c8") if not gang else Color("2a1840"))
	c.draw_string(_font, Vector2(0, 36), "PRIZE COUNTER", HORIZONTAL_ALIGNMENT_CENTER, 270, 16, Color(1, 0.85, 0.35))
	c.draw_string(_font, Vector2(0, 56), "♦ %d tickets" % Tickets.count(), HORIZONTAL_ALIGNMENT_CENTER, 270, 11, Color(1, 0.7, 0.9))
	for i in TIERS.size():
		var r := _tab_rect(i)
		c.draw_rect(r, Color(1, 0.85, 0.35, 0.95) if i == tier else Color(1, 1, 1, 0.1))
		c.draw_string(_font, Vector2(r.position.x, r.position.y + 15), TIERS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Color(0.15, 0.08, 0.05) if i == tier else Color(1, 1, 1, 0.8))
	if _rows.is_empty():
		c.draw_string(_font, Vector2(0, LIST_Y + 30), "Nothing on this shelf.", HORIZONTAL_ALIGNMENT_CENTER, 270, 9, Color(1, 1, 1, 0.6))
	for i in _rows.size():
		var id: String = _rows[i]
		var p := Tickets.prize(id)
		var item := str(p.get("item", id))
		var y := LIST_Y + i * ROW_H
		var r := Rect2(10, y, 250, ROW_H - 3)
		var lock := Tickets.lock_text(id)
		var can := lock == "" and Tickets.count() >= int(p.get("cost", 0))
		c.draw_rect(r, Color(1, 0.85, 0.35, 0.22) if i == sel else Color(1, 1, 1, 0.06))
		if i == sel:
			c.draw_rect(r, Color(1, 0.85, 0.35, 0.9), false, 1.0)
		var ic := Art.tex("items", Hud.icon_for(item))
		if ic:
			var s := 24.0 / maxf(1.0, float(maxi(ic.get_width(), ic.get_height())))
			var sz := Vector2(ic.get_width(), ic.get_height()) * s
			c.draw_texture_rect(ic, Rect2(Vector2(26, y + ROW_H / 2.0 - 1.5) - sz / 2.0, sz), false, Color(1, 1, 1, 1.0 if lock == "" or lock == "Already yours" else 0.35))
		c.draw_string(_font, Vector2(44, y + 13), GameState.item_name(item), HORIZONTAL_ALIGNMENT_LEFT, 150, 9, Color.WHITE if lock == "" else Color(1, 1, 1, 0.5))
		var sub := lock if lock != "" else str(GameState.items.get(item, {}).get("desc", "")).left(44)
		c.draw_string(_font, Vector2(44, y + 25), ("Locked: " if lock != "" and lock != "Already yours" else "") + sub, HORIZONTAL_ALIGNMENT_LEFT, 170, 7, Color(1, 0.75, 0.6) if lock != "" else Color(0.8, 0.8, 0.9))
		c.draw_string(_font, Vector2(196, y + 18), "♦%d" % int(p.get("cost", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, Color(1, 0.85, 0.35) if can else Color(1, 1, 1, 0.4))
	if _flash_t > 0.0:
		c.draw_rect(Rect2(10, 380, 250, 30), Color(0, 0, 0, 0.7))
		c.draw_string(_font, Vector2(10, 399), _flash, HORIZONTAL_ALIGNMENT_CENTER, 250, 8, Color(0.6, 1, 0.6) if _flash_good else Color(1, 0.7, 0.6))
	for b: Array in [[BTN_CLOSE, "LEAVE"], [BTN_BUY, "BUY"]]:
		var br: Rect2 = b[0]
		c.draw_rect(br, Color(1, 1, 1, 0.12))
		c.draw_rect(br, Color(1, 0.85, 0.35, 0.8), false, 1.0)
		c.draw_string(_font, Vector2(br.position.x, br.position.y + 22), str(b[1]), HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 11, Color(1, 0.9, 0.6))
	c.draw_string(_font, Vector2(0, 470), "◀ ▶ shelf · ▲▼ pick · USE buy · B leave", HORIZONTAL_ALIGNMENT_CENTER, 270, 7, Color(1, 1, 1, 0.5))
