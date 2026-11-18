class_name CraftScreen
extends CanvasLayer
## The crafting screen: every recipe at a station as a card with its icon, what it
## needs (have / need), the time, and why it's locked. Recipes you haven't
## discovered show as ??? until you've held each ingredient once.
## Tap a card to pick it, set how many, then MAKE. B or MENU closes.

signal closed

var m: GameMap
var station := ""
var key := ""
var tier := 1
var town := false
var head := ""
var _cat := ""
var _sel: Dictionary = {}
var _qty := 1
var _root: PanelContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _status: Label
var _cats: HFlowContainer
var _was_paused := false
var _arm := 0


static func open(map: GameMap, st: String, k: String, t: int, is_town: bool, title: String) -> void:
	var s := CraftScreen.new()
	s.m = map
	s.station = st
	s.key = k
	s.tier = t
	s.town = is_town
	s.head = title
	map.add_child(s)
	await s.closed


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	get_tree().paused = true
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.07, 0.97)
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	_root.add_theme_stylebox_override("panel", sb)
	_root.position = Vector2(4, 22)
	_root.size = Vector2(262, 436)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_root.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = head
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var x := _btn("✕", close)
	x.custom_minimum_size = Vector2(26, 22)
	top.add_child(x)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 7)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	v.add_child(_status)
	_cats = HFlowContainer.new()
	v.add_child(_cats)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 250)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	sc.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(250, 86)
	v.add_child(_detail)
	_refresh()


func _process(_d: float) -> void:
	# Touch buttons press actions: poll them (a short arm delay so the tap that
	# opened the screen doesn't close it).
	_arm += 1
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		close()


func close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _was_paused
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _icon(id: String, s := 22.0) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(s, s)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id != "":
		tr.texture = Art.tex("items", Hud.icon_for(id))
	return tr


func _refresh() -> void:
	Crafting.collect(m, station, key)
	for c in _list.get_children():
		c.queue_free()
	for c in _cats.get_children():
		c.queue_free()
	var js := Crafting.jobs(key)
	var st := "Tier %d · %d of %d slot%s busy" % [tier, js.size(), Crafting.slots(tier), "" if Crafting.slots(tier) == 1 else "s"]
	for j: Dictionary in js:
		var left := int(j["done_at"]) - Crafting.now_abs()
		st += "\n⏱ %s ×%d: %s" % [str(j["name"]), int(j.get("n", 1)), "READY" if left <= 0 else Crafting.fmt_minutes(left)]
	if town:
		st += "\nTown bench: a small ◆ fee per piece."
	_status.text = st
	var all: Array = Crafting._all(station)
	var cats: Array = []
	for rc in all:
		if Crafting._cat(rc) not in cats:
			cats.append(Crafting._cat(rc))
	if cats.size() > 1:
		for c in ["All"] + cats:
			var cb := _btn(str(c), func() -> void: _cat = "" if c == "All" else str(c); _refresh())
			cb.add_theme_font_size_override("font_size", 7)
			cb.modulate = Color(1, 0.9, 0.5) if (c == "All" and _cat == "") or str(c) == _cat else Color(0.8, 0.8, 0.8)
			_cats.add_child(cb)
	var known := 0
	var shown := 0
	var rows: Array = []
	for rc: Dictionary in all:
		if _cat != "" and Crafting._cat(rc) != _cat:
			continue
		var why := Crafting.why_locked(station, tier, rc)
		var disc := Crafting.discovered(rc)
		if disc:
			known += 1
		# Order: makeable, then known, then locked, then undiscovered.
		var rank := 0 if why == "" and disc and Crafting.can_make(rc) else (1 if why == "" and disc else (2 if disc else 3))
		rows.append([rank, rc, why, disc])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for row: Array in rows:
		shown += 1
		_list.add_child(_card(row[1], str(row[2]), bool(row[3])))
	if shown == 0:
		var l := Label.new()
		l.text = "Nothing here yet." if station != "keg" else "Bring produce: fruit, vegetables, herbs, grain, mushrooms or flowers."
		l.add_theme_font_size_override("font_size", 8)
		_list.add_child(l)
	_status.text += "\nRecipes discovered: %d of %d" % [known, rows.size()]
	_show_detail()


func _card(rc: Dictionary, why: String, disc: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(246, 34)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	var picked := not _sel.is_empty() and str(_sel["id"]) == str(rc["id"])
	sb.bg_color = Color(0.45, 0.33, 0.15) if picked else Color(0.24, 0.17, 0.1)
	sb.border_color = Color(1, 0.85, 0.4) if picked else Color(0.1, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := _icon(str(rc["give"]) if disc else "", 26)
	if not disc:
		ic.modulate = Color(0, 0, 0, 0.6)
	h.add_child(ic)
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 7)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not disc:
		l.text = "???\nFind: %s" % Crafting.discover_hint(rc)
		l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	else:
		var n := int(rc.get("n", 1))
		var top := "%s%s%s" % ["✓ " if Crafting._owned(rc) else "", str(rc["name"]), " ×%d" % n if n > 1 else ""]
		var bot := Crafting.have_text(rc)
		if why != "":
			bot = "Locked: " + why
		l.text = "%s   ⏱%s\n%s" % [top, Crafting.fmt_minutes(Crafting.minutes_for(station, rc, tier)), bot]
		var ok := why == "" and Crafting.can_make(rc)
		l.add_theme_color_override("font_color", Color(1, 0.96, 0.85) if ok else (Color(0.9, 0.7, 0.6) if why == "" else Color(0.7, 0.7, 0.75)))
	h.add_child(l)
	b.pressed.connect(func() -> void:
		if not disc:
			m.hud.toast("Hold every ingredient once to learn this recipe: %s." % Crafting.discover_hint(rc), Color(0.9, 0.85, 1.0))
			return
		_sel = rc
		_qty = 1
		_refresh())
	return b


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var js := Crafting.jobs(key)
	if _sel.is_empty():
		var l := Label.new()
		l.text = "Tap a recipe to pick it."
		l.add_theme_font_size_override("font_size", 8)
		_detail.add_child(l)
	else:
		var rc := _sel
		var why := Crafting.why_locked(station, tier, rc)
		var mx := mini(Crafting.max_qty(rc), 10 * tier)
		if Crafting._single(rc):
			mx = mini(mx, 1)
		_qty = clampi(_qty, 1, maxi(1, mx))
		var h := HBoxContainer.new()
		_detail.add_child(h)
		h.add_child(_icon(str(rc["give"]), 30))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 8)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var desc := str(GameState.items.get(str(rc["give"]), {}).get("desc", ""))
		l.text = "%s ×%d  ⏱%s\n%s%s" % [str(rc["name"]), int(rc.get("n", 1)) * _qty, Crafting.fmt_minutes(Crafting.minutes_for(station, rc, tier, _qty)), Crafting.have_text(rc, _qty), ("\n" + desc.left(90)) if desc != "" else ""]
		h.add_child(l)
		var row := HBoxContainer.new()
		_detail.add_child(row)
		if mx > 1:
			row.add_child(_btn(" − ", func() -> void: _qty = maxi(1, _qty - 1); _show_detail()))
			var ql := Label.new()
			ql.text = " %d " % _qty
			ql.add_theme_font_size_override("font_size", 9)
			row.add_child(ql)
			row.add_child(_btn(" + ", func() -> void: _qty = mini(mx, _qty + 1); _show_detail()))
			row.add_child(_btn("Max", func() -> void: _qty = mx; _show_detail()))
		var make := _btn("  MAKE  ", _make)
		make.disabled = why != "" or not Crafting.can_make(rc, _qty) or Crafting._owned(rc) or js.size() >= Crafting.slots(tier)
		make.add_theme_font_size_override("font_size", 10)
		row.add_child(make)
	if not js.is_empty():
		_detail.add_child(_btn("Wait here for the next job", _wait))
	if station == "terminal" and int(GameState.run["flags"].get("hack_day", -1)) != int(GameState.run["day"]):
		_detail.add_child(_btn("Run today's hack (a memory game)", _hack))


func _hack() -> void:
	GameState.run["flags"]["hack_day"] = int(GameState.run["day"])
	visible = false
	var got := await HackGame.play(m, tier)
	visible = true
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	get_tree().paused = true
	match got:
		3:
			Racket.set_heat(Racket.heat() - 1)
			GameState.add_item("data_chip", 1)
			GameState.run["crystals"] = int(GameState.run["crystals"]) + 150 * tier
			m.hud.toast("Clean hack: file wiped (heat −1), a data chip and ◆%d." % (150 * tier), Color(0.5, 1, 0.85))
		2:
			GameState.run["crystals"] = int(GameState.run["crystals"]) + 60 * tier
			m.hud.toast("Partial hack: ◆%d skimmed from a shell account." % (60 * tier), Color(0.5, 1, 0.85))
		-1:
			m.hud.toast("You pulled out before anything was taken.", Color(0.8, 0.85, 0.9))
		1:
			GameState.run["crystals"] = int(GameState.run["crystals"]) + 30
			m.hud.toast("You got a peek before the alarm: ◆30.", Color(0.7, 0.9, 0.85))
		_:
			m.hud.toast("The wire was hot today. Try again tomorrow.", Color(1, 0.75, 0.6))
	_refresh()


func _make() -> void:
	var rc := _sel
	if rc.is_empty():
		return
	if town:
		var fee := 5 * int(rc.get("tier", 1)) * _qty
		if int(GameState.run["crystals"]) < fee:
			m.hud.toast("The bench fee is ◆%d." % fee, Color(1, 0.7, 0.7))
			return
		GameState.run["crystals"] = int(GameState.run["crystals"]) - fee
	var j := Crafting.start(station, key, rc, tier, _qty)
	Crafting.mark_known(rc)
	m.hud.toast("%s: ready in %s." % [str(rc["name"]), Crafting.fmt_minutes(int(j["done_at"]) - Crafting.now_abs())], Color(1, 0.9, 0.4))
	Music.instance(get_tree()).sfx("craft_done", "pickup")
	_qty = 1
	if not Crafting.can_make(rc):
		_sel = {}
	_refresh()


func _wait() -> void:
	var soon := 999999
	for j: Dictionary in Crafting.jobs(key):
		soon = mini(soon, int(j["done_at"]) - Crafting.now_abs())
	var day_left := GameState.DAY_END - int(GameState.run["time"]) - 10
	if soon > day_left:
		m.hud.toast("That won't be ready today. Sleep on it.")
	elif soon > 0:
		GameState.run["time"] = int(GameState.run["time"]) + soon
		m.hud.toast("You wait. %s." % Crafting.fmt_minutes(soon))
	_refresh()
