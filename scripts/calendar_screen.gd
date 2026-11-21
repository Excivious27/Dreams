class_name CalendarScreen
extends CanvasLayer
## C15 P1 (c15_01-01): the season calendar, both arcs. Opened from the town board (first
## choice), the Menu ("Calendar") and a tap on the HUD date box: CalendarScreen.open(tree).
## 7x4 grid of the 28-day season (day 1 is a Monday), each cell: day number and up to three
## event marks (festival, holiday, marina, event, market, birthday) from Calendar.events_on.
## Today is ringed, past days dimmed; tapping a cell lists that day below. < > page seasons
## (year 1 spring up to a year ahead); Close (way out, last) or B. Pad: ScreenCursor.

const DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const KIND_COL := {"weather": Color("4a6fa5"), "festival": Color("d9482b"), "holiday": Color("8a3fb8"), "marina": Color("2a7fc4"), "event": Color("2f9a52"), "market": Color("b07a1e"), "birthday": Color("d6589a")}
const KIND_TAG := {"weather": "W", "festival": "F", "holiday": "H", "marina": "M", "event": "E", "market": "$", "birthday": "B"}

var view := 0  # absolute season index: (year-1)*4 + season
var sel := 1  # selected day of the viewed season
var _root: Control
var _cursor: ScreenCursor
var _arm := 0
var _was_paused := false
var gang := false
var ink := Color("3b2412")
var ink_soft := Color("6b4a2c")
var paper := Color("f3e2bf")
var edge := Color("8a5a2b")
var cell_bg := Color("fbf1da")


static func open(tree: SceneTree) -> CalendarScreen:
	for n in tree.get_nodes_in_group("calendar_screen"):
		if is_instance_valid(n):
			return n
	var s := CalendarScreen.new()
	tree.root.add_child(s)
	return s


func _ready() -> void:
	layer = 74
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_hold")
	add_to_group("calendar_screen")
	gang = not GameState.run.is_empty() and not GameState.is_penguins()
	if gang:
		ink = Color("e8f4ff")
		ink_soft = Color("9fb4c8")
		paper = Color("1b1f29")
		edge = Color("38d0e0")
		cell_bg = Color("262c3a")
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "calendar")
	Music.instance(get_tree()).sfx("page", "menu_open")
	var today := int(GameState.run.get("day", 1)) if not GameState.run.is_empty() else 1
	view = (today - 1) / Calendar.SEASON_DAYS
	sel = Calendar.dos_of(today)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()
	_cursor = ScreenCursor.make(self, _root)


func view_season() -> String:
	return Calendar.SEASONS[view % 4]


func view_year() -> int:
	return view / 4 + 1


func _today_abs() -> int:
	return int(GameState.run.get("day", 1)) if not GameState.run.is_empty() else 1


func _lab(parent: Control, text: String, pos: Vector2, size: int, col: Color, w := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", Settings.font(size))
	l.add_theme_color_override("font_color", col)
	if w > 0.0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _box(bg: Color, border: Color, bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(3)
	return sb


func _ring(col: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(3)
	return sb


func _btn(parent: Control, text: String, pos: Vector2, sz: Vector2, cb: Callable, sb: StyleBox = null) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.add_theme_font_size_override("font_size", Settings.font(8))
	if sb == null:
		sb = _box(cell_bg, edge)
	for s: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.pressed.connect(func() -> void:
		Music.instance(get_tree()).sfx("ui_tap")
		cb.call())
	parent.add_child(b)
	return b


## Event marks for a day (what the cell shows), birthdays of unmet villagers as "?".
func marks(dos: int) -> Array:
	return Calendar.events_on(view_season(), dos, view_year())


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var bg := Panel.new()  # (the c15p1 frame art draws over it when present)
	bg.add_theme_stylebox_override("panel", _box(paper, edge, 2))
	bg.position = Vector2(4, 30)
	bg.size = Vector2(262, 440)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	var frame := "c15p1_cal_frame_" + ("gang" if gang else "pen")
	if Art.has("ui", frame):
		var np := NinePatchRect.new()
		np.texture = Art.tex("ui", frame)
		var pm: Array = Art.info("ui", frame).get("patch", [12, 16, 12, 16])
		np.patch_margin_left = int(pm[0])
		np.patch_margin_top = int(pm[1])
		np.patch_margin_right = int(pm[2])
		np.patch_margin_bottom = int(pm[3])
		np.position = Vector2(2, 26)
		np.size = Vector2(266, 448)
		np.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(np)
	var title := "%s  ·  Year %d" % [view_season().capitalize(), view_year()]
	_lab(_root, title, Vector2(18, 41), 11, ink)
	var arcline := "City calendar" if gang else "Town calendar"
	_lab(_root, arcline, Vector2(186, 44), 8, ink_soft)
	for i in 7:
		_lab(_root, DAYS[i], Vector2(17 + i * 34 + 6, 60), 8, ink_soft if i < 5 else edge)
	var t := _today_abs()
	var se_start := view * Calendar.SEASON_DAYS
	for dos in range(1, 29):
		var col := (dos - 1) % 7
		var rowi := (dos - 1) / 7
		var pos := Vector2(17 + col * 34, 75 + rowi * 50)
		var absd := se_start + dos
		var is_today := absd == t
		var sb: StyleBox = _box(cell_bg.lerp(edge, 0.25) if dos == sel else cell_bg, Color("e2a72e") if is_today else edge.lerp(paper, 0.4), 2 if is_today else 1)
		var cell := "c15p1_cell_" + ("gang" if gang else "pen")
		if Art.has("ui", cell):
			var st := StyleBoxTexture.new()
			st.texture = Art.tex("ui", cell)
			if dos == sel:
				st.modulate_color = Color(0.85, 0.95, 1.0) if gang else Color(1.0, 0.86, 0.62)
			sb = st
		var b := _btn(_root, "", pos, Vector2(32, 48), func() -> void: _pick(dos), sb)
		if is_today or dos == sel:
			var ring := Panel.new()
			ring.add_theme_stylebox_override("panel", _ring(Color("e2a72e") if is_today else edge, 2 if is_today else 1))
			ring.size = Vector2(32, 48)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ring)
		b.name = "day_%d" % dos
		if absd < t:
			b.modulate = Color(1, 1, 1, 0.55)
		_lab(b, str(dos), Vector2(3, 1), 9, ink)
		var ev := marks(dos)
		var k := 0
		for e: Dictionary in ev:
			if k >= 3:
				break
			_mark(b, e, Vector2(1 + (k % 2) * 16, 16 + (k / 2) * 16))
			k += 1
	_detail()
	# Paging and the way out (last).
	_btn(_root, "< Prev", Vector2(18, 436), Vector2(68, 24), func() -> void: _page(-1))
	_btn(_root, "Next >", Vector2(100, 436), Vector2(68, 24), func() -> void: _page(1))
	_btn(_root, "Close", Vector2(182, 436), Vector2(70, 24), _close)


func _mark(parent: Control, e: Dictionary, p: Vector2) -> void:
	var kind := str(e["kind"])
	var ic := str(e.get("icon", ""))
	if kind == "birthday" and not bool(e.get("met", false)):
		ic = "face"
	var art := "c15p1_ic_" + ic
	if Art.has("ui", art):
		var tr := TextureRect.new()
		tr.texture = Art.tex("ui", art)
		tr.position = p
		tr.size = Vector2(15, 15)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tr)
		return
	var c := ColorRect.new()
	c.color = KIND_COL.get(kind, Color("777777"))
	c.position = p
	c.size = Vector2(14, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	_lab(c, "?" if ic == "face" else str(KIND_TAG.get(kind, "*")), Vector2(3, 0), 8, Color.WHITE)


## The selected day's list under the grid.
func _detail() -> void:
	var y := 280.0
	var absd := view * Calendar.SEASON_DAYS + sel
	var dn: String = DAYS[(absd - 1) % 7]
	var head := "%s %s %d" % [dn, view_season().capitalize(), sel]
	if absd == _today_abs():
		head += "  (today)"
	_lab(_root, head, Vector2(18, y), 10, ink)
	var dd := absd - _today_abs()
	if not GameState.run.is_empty() and dd in [0, 1]:  # c15_14-13: today's weather and the forecast
		_lab(_root, GameState.weather_name(GameState.weather_for(absd)), Vector2(170, y + 2), 8, ink_soft, 84)
	y += 18
	var ev := marks(sel)
	if ev.is_empty():
		_lab(_root, "Nothing on. A good day for the farm.", Vector2(18, y), 8, ink_soft, 244)
	for e: Dictionary in ev:
		if y > 420:
			break
		var kind := str(e["kind"])
		var nm := str(e["name"])
		if kind == "birthday" and not bool(e.get("met", false)):
			nm = "Someone's birthday (you haven't met them yet)"
		var when := ""
		if kind != "birthday":
			when = "  %s%s" % [str(e.get("time", "")), (", " + str(e["where"])) if str(e.get("where", "")) != "" else ""]
		var sw := ColorRect.new()
		sw.color = KIND_COL.get(kind, Color("777777"))
		sw.position = Vector2(18, y + 3)
		sw.size = Vector2(6, 6)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(sw)
		var l := _lab(_root, nm + when, Vector2(28, y), 8, ink, 226)
		y += 12.0 * maxf(1.0, ceil(l.get_minimum_size().y / 12.0)) + 2
		var ln := str(e.get("line", ""))
		if ln != "" and kind != "market" and y < 410:
			var l2 := _lab(_root, ln, Vector2(28, y), 7, ink_soft, 226)
			y += maxf(11.0, l2.get_minimum_size().y) + 3


func _pick(dos: int) -> void:
	sel = dos
	_rebuild()


func _page(d: int) -> void:
	var t := _today_abs()
	var cur := (t - 1) / Calendar.SEASON_DAYS
	view = clampi(view + d, 0, cur + 4)
	sel = Calendar.dos_of(t) if view == cur else 1
	_rebuild()


func _rebuild() -> void:
	_build()
	if _cursor:
		_cursor.root = _root


func _process(_delta: float) -> void:
	_arm += 1
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		_close()


func _close() -> void:
	if not is_inside_tree():
		return
	(func() -> void: Hud.modal_rect = Rect2()).call_deferred()  # after this frame: a menu under us doesn't see the same B
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	Music.instance(get_tree()).sfx("menu_close", "ui_tap")
	Dialogue.block_input(0.3)
	queue_free()
