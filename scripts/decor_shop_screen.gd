class_name DecorShopScreen
extends CanvasLayer
## The decor shelf as a phone screen (C10a P4, c10_05-02): today's pieces with icon,
## rarity (colour + rank dots, colour-blind safe), footprint, price and how many you
## have. UP/DOWN pick, USE buys, B leaves. Touch: tap a row to pick, tap again or BUY.
## Opened by DecorSources.shelf; buys through DecorSources.buy (decor box, unique guard).

signal closed

const ROW_H := 34.0
const LIST_Y := 70.0
const DESC_Y := 342.0
const VISIBLE := 7
const BTN_BUY := Rect2(150, 420, 100, 34)
const BTN_CLOSE := Rect2(20, 420, 100, 34)

var map: GameMap
var shop := ""
var who := ""
var sel := 0
var top := 0
var bought := 0
var _rows: Array = []
var _rep := ScreenCursor.Rep.new()
var _canvas: Control
var _font: Font
var _arm := 0
var _flash := ""
var _flash_t := 0.0
var _flash_good := true
var _was_paused := false
var _confirm := ""      # c10b_10_20: rare+ buys ask once ("" = nothing armed)
var _confirm_t := 0.0


static func open(m: GameMap, shop_key: String, keeper: String) -> int:
	var s := DecorShopScreen.new()
	s.map = m
	s.shop = shop_key
	s.who = keeper
	m.add_child(s)
	await s.closed
	return s.bought


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	_was_paused = get_tree().paused
	Hud.pause(get_tree(), "decor_shop")
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_it)
	_canvas.gui_input.connect(_tap)
	add_child(_canvas)
	_fill()


func _fill() -> void:
	_rows = DecorSources.today(shop)
	for id in _rows:
		DecorCatalogue.mark_seen(str(id))  # c10_08: a piece on a shelf counts as seen
	sel = clampi(sel, 0, maxi(0, _rows.size() - 1))
	_keep_in_view()


func _process(delta: float) -> void:
	_arm += 1
	_flash_t = maxf(0.0, _flash_t - delta)
	_confirm_t = maxf(0.0, _confirm_t - delta)
	if _confirm_t <= 0.0:
		_confirm = ""
	_canvas.queue_redraw()
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		_close()
		return
	var up := _rep.pressed("up", delta)
	var dn := _rep.pressed("down", delta)
	if (up or dn) and not _rows.is_empty():
		sel = posmod(sel + (1 if dn else -1), _rows.size())
		_keep_in_view()
		Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")
	elif Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action"):
		_buy()


func _keep_in_view() -> void:
	var n := _rows.size()
	if n <= VISIBLE:
		top = 0
		return
	top = clampi(top, 0, n - VISIBLE)
	if sel < top + 1:
		top = maxi(0, sel - 1)
	elif sel > top + VISIBLE - 2:
		top = mini(n - VISIBLE, sel - VISIBLE + 2)


func _buy() -> void:
	if sel < 0 or sel >= _rows.size():
		return
	var id := str(_rows[sel])
	if Decor.rarity_rank(Decor.rarity(id)) >= int(DecorSources.T.get("confirm_rank", 2)) and _confirm != id \
			and int(GameState.run["crystals"]) >= Decor.buy_price(id) and not DecorSources.taken(id):
		_confirm = id
		_confirm_t = 3.0
		_flash = Money.t("Buy again to pay %s for the %s." % [Money.fmt(Decor.buy_price(id)), DecorSources.name_of(id)])
		_flash_good = true
		_flash_t = 3.0
		Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")
		return
	_confirm = ""
	match DecorSources.buy(map, id, 1):
		"ok":
			bought += 1
			_flash = "Sent to your %s: %s" % ["wardrobe" if DecorSources.is_wear(id) else "decor box", DecorSources.name_of(id)]
			_flash_good = true
			Music.instance(get_tree()).sfx("cash", "coin")
			if map:
				map.xp("bartering", 1)
			_fill()
		"poor":
			_flash = "Not enough %s." % ("cash" if Money.cash() else "crystals")
			_flash_good = false
			Music.instance(get_tree()).sfx("nope", "thud")
		_:
			_flash = "You already have that one."
			_flash_good = false
			Music.instance(get_tree()).sfx("nope", "ui_tap")
	_flash_t = 2.2


func _close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _was_paused or Hud.keep_paused(get_tree(), self)  # c10b_10_14: the was-paused rule
	Music.instance(get_tree()).sfx("menu_close", "ui_tap")
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _tap(ev: InputEvent) -> void:
	var p := TapInput.press_pos(ev)
	if p == Vector2.INF or _arm < 8:
		return
	if BTN_CLOSE.has_point(p):
		_close()
		return
	if BTN_BUY.has_point(p):
		_buy()
		return
	var vis := int(floor((p.y - LIST_Y) / ROW_H))
	var row := top + vis
	if p.y >= LIST_Y and vis >= 0 and vis < VISIBLE and row < _rows.size() and p.x > 10 and p.x < 260:
		if row == sel:
			_buy()
		else:
			sel = row
			_keep_in_view()
			Music.instance(get_tree()).sfx("scroll_tick", "ui_tap")


## Rank dots: one per rarity step, in the rarity colour (readable without colour).
func _dots(c: Control, x: float, y: float, id: String) -> void:
	var r := Decor.rarity(id)
	var n := Decor.rarity_rank(r) + 1
	for i in n:
		c.draw_circle(Vector2(x + i * 5.0, y), 1.8, Decor.rarity_color(r))


func _draw_it() -> void:
	var c := _canvas
	var gang := not GameState.is_penguins()
	c.draw_rect(Rect2(0, 0, 270, 480), Color(0.06, 0.05, 0.1) if gang else Color(0.14, 0.1, 0.07))
	var wear_only := not _rows.is_empty() and _rows.all(func(i: Variant) -> bool: return DecorSources.is_wear(str(i)))
	c.draw_string(_font, Vector2(0, 30), "WARDROBE" if wear_only else ("YARD AND HOME" if who == "Tess" else "HOME GOODS"), HORIZONTAL_ALIGNMENT_CENTER, 270, 16, Color(1, 0.85, 0.45))
	c.draw_string(_font, Vector2(0, 46), Money.t("%s · you have %s" % [who if who != "" else "Shelf", Money.fmt(int(GameState.run["crystals"]))]), HORIZONTAL_ALIGNMENT_CENTER, 270, 9, Color(1, 1, 1, 0.75))
	c.draw_string(_font, Vector2(0, 60), "New pieces every few days. Buys go to your %s." % ("wardrobe" if wear_only else "decor box"), HORIZONTAL_ALIGNMENT_CENTER, 270, 7, Color(1, 1, 1, 0.45))
	if _rows.is_empty():
		c.draw_string(_font, Vector2(0, LIST_Y + 30), "Shelf's bare today.", HORIZONTAL_ALIGNMENT_CENTER, 270, 9, Color(1, 1, 1, 0.6))
	for i in range(top, mini(_rows.size(), top + VISIBLE)):
		var id := str(_rows[i])
		var y := LIST_Y + (i - top) * ROW_H
		var r := Rect2(10, y, 250, ROW_H - 3)
		var price := Decor.buy_price(id)  # c10b_10_01: discounts shown as charged
		var can := int(GameState.run["crystals"]) >= price
		c.draw_rect(r, Color(1, 0.85, 0.35, 0.22) if i == sel else Color(1, 1, 1, 0.06))
		if i == sel:
			c.draw_rect(r, Color(1, 0.85, 0.35, 0.9), false, 1.0)
		var ic := DecorSources.icon_tex(id)
		if ic:
			var s := 24.0 / maxf(1.0, float(maxi(ic.get_width(), ic.get_height())))
			var sz := Vector2(ic.get_width(), ic.get_height()) * s
			c.draw_texture_rect(ic, Rect2(Vector2(26, y + ROW_H / 2.0 - 1.5) - sz / 2.0, sz), false)
		c.draw_string(_font, Vector2(44, y + 13), _fit(DecorSources.name_of(id), 140.0, 9), HORIZONTAL_ALIGNMENT_LEFT, 150, 9, Color.WHITE)
		_dots(c, 46, y + 22, id)
		var have := DecorSources.held(id)
		c.draw_string(_font, Vector2(84, y + 25), DecorSources.rarity_word(id) + (("  (have %d)" % have) if have > 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, 110, 7, Color(0.85, 0.85, 0.9))
		c.draw_string(_font, Vector2(196, y + 18), Money.t(Money.fmt(price)), HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, Color(1, 0.85, 0.35) if can else Color(1, 1, 1, 0.4))
	if sel >= 0 and sel < _rows.size():
		var id := str(_rows[sel])
		var e := Decor.entry(id)
		var sz: Array = e.get("size", [1, 1])
		var full := "%s %s. Takes %dx%d.%s" % [DecorSources.rarity_word(id), str(e.get("cat", "piece")).replace("_", " "), int(sz[0]) if sz.size() > 0 else 1, int(sz[1]) if sz.size() > 1 else 1, (" " + str(e.get("desc", ""))) if e.has("desc") else ""]
		if Decor.is_unique(id):
			full += " One of a kind."
		c.draw_rect(Rect2(10, DESC_Y, 250, 34), Color(0, 0, 0, 0.35))
		c.draw_multiline_string(_font, Vector2(16, 355), full, HORIZONTAL_ALIGNMENT_LEFT, 238, 8, 2, Color(0.9, 0.88, 0.95))
	if _flash_t > 0.0:
		c.draw_rect(Rect2(10, 380, 250, 30), Color(0, 0, 0, 0.7))
		c.draw_string(_font, Vector2(10, 399), _fit(_flash, 244.0, 8), HORIZONTAL_ALIGNMENT_CENTER, 250, 8, Color(0.6, 1, 0.6) if _flash_good else Color(1, 0.7, 0.6))
	for b: Array in [[BTN_CLOSE, "LEAVE"], [BTN_BUY, "BUY"]]:
		var br: Rect2 = b[0]
		c.draw_rect(br, Color(1, 1, 1, 0.12))
		c.draw_rect(br, Color(1, 0.85, 0.35, 0.8), false, 1.0)
		c.draw_string(_font, Vector2(br.position.x, br.position.y + 22), str(b[1]), HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 11, Color(1, 0.9, 0.6))
	c.draw_string(_font, Vector2(0, 470), PadInput.words("▲▼ pick · USE buy · B leave"), HORIZONTAL_ALIGNMENT_CENTER, 270, 7, Color(1, 1, 1, 0.5))


func _fit(t: String, w: float, fs: int) -> String:
	if _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return t
	var out := ""
	for wd in t.split(" "):
		var nxt := (out + " " + wd) if out != "" else wd
		if _font.get_string_size(nxt + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			break
		out = nxt
	return out.rstrip(",.;:") + "…"
