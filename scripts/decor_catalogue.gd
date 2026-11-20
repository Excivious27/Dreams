class_name DecorCatalogue
extends CanvasLayer
## CONDUCT 10a P3: the Decor catalogue (c10_08). A full-screen screen (like ChestScreen) opened from
## the Book hub, the Items tab "Decor box" link and the chest screen. Three views:
##   grid  every catalogue entry of this arc: OWNED (full colour + count), SEEN (full icon, can be
##         re-ordered for a fee, delivered next morning to the decor box), MISSING (silhouette + a
##         where-hint that gets vaguer with rarity; mythic/unique show a plain "?" tile).
##         Filter chips: category / rarity / show (all, owned, seen, missing) / set. Pages of PAGE.
##   sets  every set with n/N and its reward; a finished set is claimed once here.
##   box   the decor box (run.decor.box): Place (P2's DecorMode) or Wear (P5's Wardrobe), guarded.
## Data and ownership only through Decor (P1's contract). Orders live in run.decor["orders"]
## ([{id, day}]) and are delivered by Collections.morning() (deliver_orders). Claimed sets in
## run.decor["sets_done"] ({set id: day}). Static filter state survives closing; reset() on new run.

signal closed

const PAGE := 30            # 6 x 5 cells: the grid never scrolls on a 270x480 phone
const COLS := 6
const CELL := 38
const ORDER_MARKUP := 1.25  # fallback when Decor has no order_price(): shop price x this + fee
const ORDER_FEE := 25
const CATS := ["", "furniture", "wall_art", "decor", "light", "rug", "wallpaper", "flooring", "hat", "top", "bottom", "outfit", "acc", "shoes"]
const CAT_WORDS := {"": "All", "furniture": "Furniture", "wall_art": "Wall art", "decor": "Decor", "light": "Lights", "rug": "Rugs",
	"wallpaper": "Wallpaper", "flooring": "Floors", "hat": "Hats", "top": "Tops", "bottom": "Bottoms", "outfit": "Outfits", "acc": "Accessories", "shoes": "Shoes"}
const SHOWS := ["all", "owned", "seen", "missing"]
const SHOW_WORDS := {"all": "Show: all", "owned": "Owned", "seen": "Seen", "missing": "Missing"}
const WEAR_CATS := ["hat", "top", "bottom", "outfit", "acc", "shoes"]
const RARITY_GLYPH := {"common": "", "uncommon": "•", "rare": "••", "epic": "•••", "legendary": "••••", "mythic": "•••••", "unique": "★"}

static var view := "grid"
static var cat_i := 0
static var rar_i := 0     # 0 = all, else Decor.RARITIES[rar_i - 1]
static var show_i := 0
static var set_i := 0     # 0 = all, else _set_ids()[set_i - 1]
static var part := 0
static var box_page := 0
static var sel := ""
static var _cache_key := ""
static var _cache: Array = []   # sorted ids of this arc

var m: Node
var _root: PanelContainer
var _body: VBoxContainer
var _tip: Label
var _cur: ScreenCursor
var _was_paused := false
var _arm := 0
var _msg_t := 0.0
var _prev_modal := Rect2()
var _chip_down := 0
const LONG_MS := 450  # a chip held this long steps back (touch has no second button)


## Opens the catalogue on a view ("grid" | "sets" | "box") over whatever is on screen.
static func open(map: Node, v := "grid") -> DecorCatalogue:
	if map == null:
		return null
	var s := DecorCatalogue.new()
	s.m = map
	view = v if v in ["grid", "sets", "box"] else "grid"
	map.add_child(s)
	return s


## New run / load / arc switch: start from a clean slate (c10_08 stale-state finding).
static func reset() -> void:
	view = "grid"
	cat_i = 0
	rar_i = 0
	show_i = 0
	set_i = 0
	part = 0
	sel = ""
	_cache_key = ""


# ---- data helpers (static: the Book hub and tests use them) --------------------------------

static func _arc() -> String:
	return str(GameState.run.get("arc", ""))


static func arc_ok(e: Dictionary) -> bool:
	var a := str(e.get("arc", ""))
	return a == "" or a == _arc()


## Every catalogue id of this arc, sorted by category, rarity, name. Cached per arc + data size.
static func ids() -> Array:
	var items: Dictionary = Decor.data()["items"]
	var k := "%s|%d|%d" % [_arc(), items.size(), (Decor.data()["sets"] as Dictionary).size()]
	if k == _cache_key:
		return _cache
	var out := []
	for id in items:
		var e: Dictionary = items[id]
		if arc_ok(e) and not bool(e.get("hidden", false)):
			out.append(str(id))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ea: Dictionary = items[a]
		var eb: Dictionary = items[b]
		var ca := _cat_rank(str(ea.get("cat", "")))
		var cb := _cat_rank(str(eb.get("cat", "")))
		if ca != cb:
			return ca < cb
		var ra := Decor.rarity_rank(str(ea.get("rarity", "common")))
		var rb := Decor.rarity_rank(str(eb.get("rarity", "common")))
		if ra != rb:
			return ra < rb
		return str(ea.get("name", a)) < str(eb.get("name", b)))
	_cache = out
	_cache_key = k
	return out


static func worn_any(id: String) -> bool:
	for s in Decor.WEAR_SLOTS:
		if Decor.worn(s) == id:
			return true
	return false


## Everything the player holds of a piece: decor box + placed + worn.
static func have(id: String) -> int:
	return Decor.owned(id) + Decor.placed_count(id) + (1 if worn_any(id) else 0)


## Where the pieces you hold are (card "Find" line): "box 2, placed 1 (house), worn".
static func find_text(id: String) -> String:
	var bits := []
	if Decor.owned(id) > 0:
		bits.append("box %d" % Decor.owned(id))
	var rooms := []
	var placed: Dictionary = Decor.st()["placed"]
	for key in placed:
		for p in placed[key]:
			if p is Dictionary and str(p.get("id", "")) == id and not rooms.has(str(key)):
				rooms.append(str(key))
	if not rooms.is_empty():
		var names := rooms.map(func(k: String) -> String: return "home" if k == "house" else PlaceNames.for_id(k) if PlaceNames.for_id(k) != "" else k.replace("_", " "))
		bits.append("placed %d (%s)" % [Decor.placed_count(id), ", ".join(names.slice(0, 2))])
	if worn_any(id):
		bits.append("worn")
	return ", ".join(bits)


## "owned" | "seen" (seen in a shop, or owned once) | "missing".
static func state(id: String) -> String:
	if have(id) > 0:
		return "owned"
	var d := Decor.st()
	if (d["got"] as Dictionary).has(id) or (d["seen"] as Dictionary).has(id):
		return "seen"
	return "missing"


## Shops, prize counters and loot call this when a piece is shown to the player (P4 hook).
static func mark_seen(id: String) -> void:
	if Decor.is_decor(id) and not (Decor.st()["seen"] as Dictionary).has(id):
		Decor.st()["seen"][id] = int(GameState.run.get("day", 1))


## Kinds ever owned of this arc / total (Book hub row, Hero tab).
static func progress() -> Array:
	var got := 0
	var all := ids()
	var g: Dictionary = Decor.st()["got"]
	for id: String in all:
		if g.has(id) or have(id) > 0:
			got += 1
	return [got, all.size()]


## Kinds got since the catalogue was last looked at (Book tab glow, "• New!" on the hub row).
static func new_count() -> int:
	var d := Decor.st()
	var seen_v: Dictionary = d.get("viewed", {}) if d.get("viewed", null) is Dictionary else {}
	var n := 0
	for id in d["got"]:
		if not seen_v.has(id) and Decor.is_decor(str(id)):
			n += 1
	return n


static func clear_new() -> void:
	var d := Decor.st()
	if not (d.get("viewed", null) is Dictionary):
		d["viewed"] = {}
	for id in d["got"]:
		d["viewed"][id] = true


static func _set_ids() -> Array:
	var out := []
	var sets: Dictionary = Decor.data()["sets"]
	for sid in sets:
		if arc_ok(sets[sid] if sets[sid] is Dictionary else {}):
			out.append(str(sid))
	out.sort()
	return out


static func set_pieces(sid: String) -> Array:
	var s: Variant = (Decor.data()["sets"] as Dictionary).get(sid, {})
	return ((s as Dictionary).get("pieces", []) as Array) if s is Dictionary else []


## [have, need] for a set: pieces ever owned (selling one never undoes a finished set).
static func set_progress(sid: String) -> Array:
	var s: Dictionary = (Decor.data()["sets"] as Dictionary).get(sid, {})
	var pieces := set_pieces(sid)
	var g: Dictionary = Decor.st()["got"]
	var n := 0
	for p in pieces:
		if g.has(str(p)) or have(str(p)) > 0:
			n += 1
	return [n, int(s.get("need", pieces.size()))]


static func sets_done() -> Dictionary:
	var d := Decor.st()
	if not (d.get("sets_done", null) is Dictionary):
		d["sets_done"] = {}
	return d["sets_done"]


## [claimed, total] of this arc's sets.
static func set_counts() -> Array:
	var all := _set_ids()
	var n := 0
	for sid: String in all:
		if sets_done().has(sid):
			n += 1
	return [n, all.size()]


## Claims a finished set's reward once (money and/or a bonus piece). "" on success, else why not.
static func claim_set(sid: String) -> String:
	if sets_done().has(sid):
		return "Already claimed."
	var pr := set_progress(sid)
	if int(pr[1]) <= 0 or int(pr[0]) < int(pr[1]):
		return "%d more piece%s to go." % [int(pr[1]) - int(pr[0]), "" if int(pr[1]) - int(pr[0]) == 1 else "s"]
	sets_done()[sid] = int(GameState.run.get("day", 1))
	var rw: Dictionary = ((Decor.data()["sets"] as Dictionary).get(sid, {}) as Dictionary).get("reward", {})
	if int(rw.get("money", 0)) > 0:
		GameState.add_money(int(rw["money"]), "decor_set")
	if str(rw.get("decor", "")) != "":
		Decor.give(str(rw["decor"]), 1, "set:" + sid)
	return ""


static func reward_text(sid: String) -> String:
	var rw: Dictionary = ((Decor.data()["sets"] as Dictionary).get(sid, {}) as Dictionary).get("reward", {})
	var bits := []
	if int(rw.get("money", 0)) > 0:
		bits.append(Money.amount(int(rw["money"])))
	if str(rw.get("decor", "")) != "":
		bits.append(name_of(str(rw["decor"])))
	if str(rw.get("title", "")) != "":
		bits.append("title: " + str(rw["title"]))
	return ", ".join(bits) if not bits.is_empty() else "the set's look"


static func name_of(id: String) -> String:
	var e := Decor.entry(id)
	if e.has("name"):
		return str(e["name"])
	return GameState.item_name(id) if GameState.items.has(id) else id.trim_prefix("dc_").trim_prefix("wr_").replace("_", " ").capitalize()


## Re-order price: P1's Decor.order_price() when it exists, else shop price x ORDER_MARKUP + ORDER_FEE.
static func order_price(id: String) -> int:
	var dsc: Script = load("res://scripts/decor.gd")
	if dsc.get_script_method_list().any(func(md: Dictionary) -> bool: return str(md["name"]) == "order_price"):
		return int(dsc.call("order_price", id))
	var p := Decor.price(id)
	return 0 if p <= 0 else int(round(p * ORDER_MARKUP)) + ORDER_FEE


## "" when the piece can be ordered right now, else the reason (shown on the card).
static func order_block(id: String) -> String:
	var e := Decor.entry(id)
	if e.is_empty():
		return "Not in the catalogue."
	var r := Decor.rarity(id)
	if r == "unique":
		return "One of a kind: it can't be ordered."
	if r == "mythic" or e.get("order", true) == false:
		return "Can't be ordered: found only where it first turned up."
	if order_price(id) <= 0:
		return "Not sold anywhere."
	if state(id) == "missing":
		return "Find or see it once to order it."
	if GameState.visiting():
		return "Orders go to your own farm: order at home."
	for o in orders():
		if str((o as Dictionary).get("id", "")) == id:
			return "On order: it arrives tomorrow morning."
	if int(GameState.run.get("crystals", 0)) < order_price(id):
		return "Not enough money (%s)." % Money.amount(order_price(id))
	return ""


static func orders() -> Array:
	var d := Decor.st()
	if not (d.get("orders", null) is Array):
		d["orders"] = []
	return d["orders"]


## Pays and queues an order. "" on success, else why not.
static func order(id: String) -> String:
	var why := order_block(id)
	if why != "":
		return why
	GameState.add_money(-order_price(id), "decor_order")
	orders().append({"id": id, "day": int(GameState.run.get("day", 1))})
	return ""


## Morning post (Collections.morning): orders placed before today land in the decor box.
## Returns the delivered ids.
static func deliver_orders() -> Array:
	if GameState.run.is_empty() or not (GameState.run.get("decor", null) is Dictionary) or (GameState.run["decor"] as Dictionary).get("orders", []).is_empty():
		return []  # nothing on order: never creates run.decor for old saves
	var today := int(GameState.run.get("day", 1))
	var keep := []
	var got := []
	for o in orders():
		var od: Dictionary = o
		if int(od.get("day", today)) < today:
			Decor.give(str(od.get("id", "")), 1, "order")
			got.append(str(od.get("id", "")))
		else:
			keep.append(od)
	Decor.st()["orders"] = keep
	return got


## Where to find a piece, vaguer with rarity (c10_08 spoiler finding).
static func hint(id: String) -> String:
	var e := Decor.entry(id)
	var r := Decor.rarity(id)
	var src := []
	for s in e.get("sources", []):
		if s is Dictionary:
			src.append(str((s as Dictionary).get("where", (s as Dictionary).get("text", ""))))
		else:
			src.append(str(s))
	src = src.filter(func(x: String) -> bool: return x != "")
	var exact := ", ".join(src.slice(0, 2)) if not src.is_empty() else str(e.get("where", ""))
	var gate := str(e.get("gate", ""))
	if state(id) == "missing" and gate != "" and not (GameState.run.get("flags", {}) as Dictionary).has(gate):
		return "???"  # from a system not open yet (campaigns, mega regions): no spoilers
	if state(id) != "missing" and r != "unique":
		return exact if exact != "" else str(e.get("hint", "Found around the valley."))  # seen/owned: no riddles
	match r:
		"common", "uncommon":
			return exact if exact != "" else "Sold in shops around the valley."
		"rare", "epic":
			return str(e.get("hint", exact if exact != "" else "Something special: keep exploring."))
		"legendary":
			return str(e.get("hint", "???"))
	return str(e.get("riddle", "One of a kind. Nobody knows where it waits." if r == "unique" else "A legend: few have seen one."))


static func icon_tex(id: String) -> Texture2D:
	var e := Decor.entry(id)
	for k in ["icon", "art"]:
		var s := str(e.get(k, ""))
		if s.contains("/"):
			var gp := s.split("/", true, 1)
			if Art.has(gp[0], gp[1]):
				return _frame0(gp[0], gp[1])
	if Art.has("decor", id + "_icon"):
		return Art.tex("decor", id + "_icon")
	if Art.has("decor", id):
		return _frame0("decor", id)
	var ic := Hud.icon_for(id)
	return Art.tex("items", ic) if Art.has("items", ic) else null


## A strip with frames shows its first frame as the icon, not 4 tiny copies (c10b_08-11).
static func _frame0(g: String, n: String) -> Texture2D:
	var t := Art.tex(g, n)
	var fr := int(Art.info(g, n).get("frames", 1))
	if t == null or fr <= 1:
		return t
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(0, 0, float(Art.info(g, n).get("cell_w", t.get_width() / fr)), t.get_height())
	return at


## Rarity of any id: catalogue first, then items.json.
static func rarity_of(id: String) -> String:
	if Decor.is_decor(id):
		return Decor.rarity(id)
	return str(GameState.items.get(id, {}).get("rarity", "common"))


static func rarity_col(id: String) -> Color:
	var r := rarity_of(id)
	if r in ["mythic", "unique"] or Decor.is_decor(id):
		return Decor.rarity_color(r)
	return GameState.rarity_color(id)


## Shared rarity marks (c9_07: count, not colour alone) for every slot drawer: uncommon 1 dot ..
## legendary 4, mythic 5 (a tighter row), unique a star plate. Bottom-left of a slot of height h.
static func rarity_dots(b: Control, id: String, h: float) -> void:
	var r := rarity_of(id)
	var col := rarity_col(id)
	if r == "unique":
		var st := Label.new()
		st.text = "★"
		st.add_theme_font_size_override("font_size", 8)
		st.add_theme_color_override("font_color", col)
		st.add_theme_constant_override("outline_size", 2)
		st.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
		st.position = Vector2(1, h - 12)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(st)
		return
	var n := clampi(Decor.rarity_rank(r), 0, 5)
	var step := 4 if n <= 4 else 3
	for k in n:
		var dot := ColorRect.new()
		dot.color = Color(0.05, 0.03, 0.02)
		dot.size = Vector2(4, 4)
		dot.position = Vector2(2 + k * step, h - 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := ColorRect.new()
		inner.color = col
		inner.size = Vector2(2, 2)
		inner.position = Vector2(1, 1)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(inner)
		b.add_child(dot)


## The category chips: the hand list, then any new category in the data (outdoor_*,
## exterior_*, casino...) so they can be filtered too (c10b_14_26).
static var _cats_n := -1
static var _cats: Array = []


static func cats() -> Array:
	var items: Dictionary = Decor.data().get("items", {})
	if _cats_n != items.size():
		_cats_n = items.size()
		_cats = CATS.duplicate()
		var extra := {}
		for id in items:
			var c := str((items[id] as Dictionary).get("cat", ""))
			if c != "" and not CATS.has(c):
				extra[c] = true
		var ek := extra.keys()
		ek.sort()
		_cats.append_array(ek)
	return _cats


## Sort rank of a category: the hand list first, then any new data category
## (outdoor_*, exterior_*, casino...) after it, never first (c10b_14_26).
static func _cat_rank(c: String) -> int:
	var i := CATS.find(c)
	return i if i >= 0 else CATS.size() + absi(hash(c)) % 1000


## The filtered id list for the current chips.
static func filtered() -> Array:
	var out := []
	var c := str(cats()[cat_i % cats().size()])
	var rr := "" if rar_i == 0 else str(Decor.RARITIES[(rar_i - 1) % Decor.RARITIES.size()])
	var sh := str(SHOWS[show_i % SHOWS.size()])
	var sets := _set_ids()
	var sid := "" if set_i == 0 or sets.is_empty() else str(sets[(set_i - 1) % sets.size()])
	var in_set := {}
	if sid != "":
		for p in set_pieces(sid):
			in_set[str(p)] = true
	for id: String in ids():
		var e := Decor.entry(id)
		if c != "" and str(e.get("cat", "")) != c:
			continue
		if rr != "" and str(e.get("rarity", "common")) != rr:
			continue
		if sid != "" and not in_set.has(id) and str(e.get("set", "")) != sid:
			continue
		if sh != "all" and state(id) != sh:
			continue
		out.append(id)
	return out


# ---- the screen -----------------------------------------------------------------------------

func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_prev_modal = Hud.modal_rect  # opened over a chest: give its modal back on close
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "decor_catalogue")
	add_to_group("toast_hold")
	Music.instance(get_tree()).sfx("book", "page")
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.07, 1.0)
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	_root.add_theme_stylebox_override("panel", sb)
	Hud.skin_buttons(_root)
	_root.position = Vector2(4, 30)
	_root.size = Vector2(262, 446)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_root.add_child(v)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_tip = _label("", 7, TIP_COL)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_tip)
	_cur = ScreenCursor.make(self, _root)
	_cur.on_alt = _pad_alt
	_cur.on_page = func(_d: int) -> void: _turn(1)
	_cur.on_move = _edge_move
	_refresh()


const TIP_COL := Color(0.8, 0.75, 0.65)
const TIP_TOUCH := "Tap a chip to change it (hold: back), a piece for its card. B closes."


func _tip_text() -> String:
	if ScreenCursor.pad_active() or not TouchControls.visible_controls:
		return "%s: choose.  %s: chip back / order.  %s: next page.  %s: back." % [InputSetup.prompt("a"), InputSetup.prompt("action"), InputSetup.prompt("cycle_tool"), InputSetup.prompt("b")]
	return TIP_TOUCH


func _say(t: String, col := Color(1, 0.9, 0.7)) -> void:
	_tip.text = t
	_tip.add_theme_color_override("font_color", col)
	_msg_t = 3.0


func _process(d: float) -> void:
	_arm += 1
	if _msg_t > 0.0:
		_msg_t -= d
		if _msg_t <= 0.0:
			_tip.text = _tip_text()
			_tip.add_theme_color_override("font_color", TIP_COL)
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		back()


## B: the card, then the view, then the screen.
func back() -> void:
	if sel != "":
		sel = ""
		_refresh()
	elif view != "grid":
		view = "grid"
		_refresh()
	else:
		close()


func close() -> void:
	if not is_inside_tree():
		return
	Hud.modal_rect = _prev_modal
	get_tree().paused = _was_paused and (Hud.keep_paused(get_tree(), self) or _prev_modal.size != Vector2.ZERO)
	Music.instance(get_tree()).sfx("menu_close", "page")
	Dialogue.block_input(0.3)
	for ch in (get_parent().get_children() if get_parent() else []):
		if ch is GameMenu and (ch as GameMenu)._open:
			(ch as GameMenu)._refresh()
	closed.emit()
	queue_free()


func _label(t: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", Settings.font(sz))
	l.add_theme_color_override("font_color", c)
	l.clip_text = true
	return l


func _btn(text: String, cb: Callable, key := "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", Settings.font(8))
	b.custom_minimum_size = Vector2(0, 22)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.pressed.connect(cb)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if b.disabled and TapInput.is_release(ev):
			Music.instance(get_tree()).sfx("nope", "thud"))
	b.set_meta("pc_key", key if key != "" else "t:" + text)
	return b


func _sfx(n: String, fb := "ui_tap") -> void:
	Music.instance(get_tree()).sfx(n, fb)


func _refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var top := HBoxContainer.new()
	_body.add_child(top)
	var pg := progress()
	var sc := set_counts()
	var ttl := _label("Decor catalogue · %d/%d · sets %d/%d" % [pg[0], pg[1], sc[0], sc[1]], 9, Color(1, 0.9, 0.6))
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)
	var x := _btn("✕", close, "close")
	x.custom_minimum_size = Vector2(26, 22)
	top.add_child(x)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	_body.add_child(tabs)
	for pair in [["grid", "Catalogue"], ["sets", "Sets"], ["box", "Decor box %d" % _box_total()]]:
		var vv := str(pair[0])
		var tb := _btn(str(pair[1]), func() -> void: view = vv; sel = ""; _sfx("page"); _refresh(), "view:" + vv)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.modulate = Color(1, 0.9, 0.5) if view == vv else Color(0.8, 0.8, 0.8)
		tabs.add_child(tb)
	match view:
		"sets":
			_sets_view()
		"box":
			_box_view()
		_:
			_grid_view()
	if _msg_t <= 0.0:
		_tip.text = _tip_text()
	_cur.resync()


static func _box_total() -> int:
	var t := 0
	for id in Decor.st()["box"]:
		t += int(Decor.st()["box"][id])
	return t


func _chip_text(i: int) -> String:
	match i:
		0:
			return str(CAT_WORDS.get(cats()[cat_i % cats().size()], str(cats()[cat_i % cats().size()]).replace("_", " ").capitalize())) if cat_i != 0 else "Type: all"
		1:
			return "Rarity: all" if rar_i == 0 else str(Decor.RARITIES[(rar_i - 1) % Decor.RARITIES.size()]).capitalize()
		2:
			return str(SHOW_WORDS[SHOWS[show_i % SHOWS.size()]])
	var sets := _set_ids()
	if set_i == 0 or sets.is_empty():
		return "Set: all"
	var sid := str(sets[(set_i - 1) % sets.size()])
	return str(((Decor.data()["sets"] as Dictionary).get(sid, {}) as Dictionary).get("name", sid))


## Steps chip i by dir (tap = forward, pad X = back).
func cycle_chip(i: int, dir: int) -> void:
	match i:
		0: cat_i = posmod(cat_i + dir, cats().size())
		1: rar_i = posmod(rar_i + dir, Decor.RARITIES.size() + 1)
		2: show_i = posmod(show_i + dir, SHOWS.size())
		3: set_i = posmod(set_i + dir, _set_ids().size() + 1)
	part = 0
	sel = ""
	_sfx("page")
	_refresh()


func _turn(dir: int) -> void:
	if view != "grid":
		return
	var pages := maxi(1, int(ceil(filtered().size() / float(PAGE))))
	part = posmod(part + dir, pages)
	sel = ""
	_sfx("page")
	_refresh()


## Pad: left/right past the grid's edge turns the page (the cursor lands on the same row).
func _edge_move(dir: Vector2) -> bool:
	if view != "grid" or _cur.cur == null or not is_instance_valid(_cur.cur) or dir.y != 0.0:
		return false
	var k := _cur.key_of(_cur.cur)
	if not k.begins_with("cell:"):
		return false
	var list := filtered()
	var pages := maxi(1, int(ceil(list.size() / float(PAGE))))
	if pages <= 1:
		return false
	var i := list.find(k.trim_prefix("cell:")) - part * PAGE
	if i < 0:
		return false
	var col := i % COLS
	var row := i / COLS
	var last := mini(PAGE, list.size() - part * PAGE) - 1
	if not ((dir.x < 0.0 and col == 0) or (dir.x > 0.0 and (col == COLS - 1 or i == last))):
		return false
	_turn(1 if dir.x > 0.0 else -1)
	var shown := list.slice(part * PAGE, part * PAGE + PAGE)
	if not shown.is_empty():
		var j := clampi(row * COLS + (0 if dir.x > 0.0 else COLS - 1), 0, shown.size() - 1)
		_cur.select_key.call_deferred("cell:" + str(shown[j]))
	return true


func _pad_alt(c: Control) -> void:
	if c == null:
		return
	var k := _cur.key_of(c)
	if k.begins_with("chip:"):
		cycle_chip(int(k.trim_prefix("chip:")), -1)
	elif k.begins_with("cell:"):
		var id := k.trim_prefix("cell:")
		sel = id
		_do_order(id)


func _grid_view() -> void:
	clear_new()
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 2)
	_body.add_child(chips)
	for i in 4:
		var ii := i
		var cb := _btn(_chip_text(i), func() -> void:
			var held := _chip_down > 0 and Time.get_ticks_msec() - _chip_down >= LONG_MS
			_chip_down = 0  # a pad A press has no button_down: always forward
			cycle_chip(ii, -1 if held else 1), "chip:%d" % i)
		cb.button_down.connect(func() -> void: _chip_down = Time.get_ticks_msec())  # hold = step back
		cb.custom_minimum_size = Vector2(60, 22)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", Settings.font(7))
		cb.clip_text = true  # long set names stay inside their chip
		chips.add_child(cb)
	var list := filtered()
	var owned := 0
	for id: String in list:
		if state(id) == "owned":
			owned += 1
	if ids().is_empty():
		_body.add_child(_label("The catalogue is empty for now.", 8, Color(0.8, 0.8, 0.75)))
		return
	_body.add_child(_label("%d shown · %d owned" % [list.size(), owned], 7, Color(0.85, 0.85, 0.8)))
	var pages := maxi(1, int(ceil(list.size() / float(PAGE))))
	part = clampi(part, 0, pages - 1)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	g.custom_minimum_size = Vector2(0, 5 * (CELL + 2))
	_body.add_child(g)
	for id: String in list.slice(part * PAGE, part * PAGE + PAGE):
		g.add_child(_cell(id))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 2)
	_body.add_child(pr)
	var pb := _btn("‹ Page", func() -> void: _turn(-1), "page:prev")
	pb.disabled = pages <= 1
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(pb)
	var pn := _label("%d/%d" % [part + 1, pages], 8, Color(0.9, 0.85, 0.7))
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pn.custom_minimum_size = Vector2(36, 0)
	pr.add_child(pn)
	var nb := _btn("Page ›", func() -> void: _turn(1), "page:next")
	nb.disabled = pages <= 1
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(nb)
	_card_strip()


func _cell(id: String) -> Control:
	var s := state(id)
	var r := Decor.rarity(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.set_meta("pc_key", "cell:" + id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.17, 0.1) if s != "missing" else Color(0.19, 0.13, 0.08)
	sb.border_color = Color(1, 0.9, 0.5) if id == sel else Decor.rarity_color(r).darkened(0.3 if s != "missing" else 0.7)
	sb.set_border_width_all(2 if id == sel else 1)
	sb.set_corner_radius_all(2)
	for stn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(stn, sb)
	var tex := icon_tex(id)
	var hide_shape := s == "missing" and r in ["mythic", "unique"]
	if tex and not hide_shape:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_top = 3
		tr.offset_right = -3
		tr.offset_bottom = -3
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(0, 0, 0, 0.6) if s == "missing" else (Color(0.7, 0.7, 0.75, 0.5) if s == "seen" else Color.WHITE)
		b.add_child(tr)
	if s == "missing":
		b.text = "?"
		b.add_theme_font_size_override("font_size", Settings.font(8))
	else:
		rarity_dots(b, id, CELL)
		var n := have(id)
		if n > 1:
			var nl := _label(str(mini(n, 99)), 7, Color.WHITE)
			nl.add_theme_constant_override("outline_size", 2)
			nl.add_theme_color_override("font_outline_color", Color.BLACK)
			nl.clip_text = false
			nl.position = Vector2(CELL - 14, CELL - 13)
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(nl)
	b.pressed.connect(func() -> void:
		sel = "" if sel == id else id
		_sfx("ui_tap")
		_refresh())
	return b


## The fixed card strip under the grid: always on screen, so a tap on any cell shows its card.
func _card_strip() -> void:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.05)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(3)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(0, 92)
	_body.add_child(box)
	if sel == "" or not Decor.is_decor(sel):
		var l := _label("Tap a piece to see where it comes from.", 8, Color(0.75, 0.72, 0.65))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = false
		box.add_child(l)
		return
	var id := sel
	var s := state(id)
	var r := Decor.rarity(id)
	var e := Decor.entry(id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	box.add_child(h)
	var tex := icon_tex(id)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(44, 44)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if tex and not (s == "missing" and r in ["mythic", "unique"]):
		pic.texture = tex
		pic.modulate = Color(0, 0, 0, 0.6) if s == "missing" else Color.WHITE
	h.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var known := s != "missing" or r in ["common", "uncommon"]
	var nm := _label(("%s  %s" % [name_of(id), RARITY_GLYPH.get(r, "")]) if known else "???  " + str(RARITY_GLYPH.get(r, "")), 9, Decor.rarity_color(r))
	col.add_child(nm)
	var meta := "%s · %s" % [r.capitalize(), str(CAT_WORDS.get(str(e.get("cat", "")), str(e.get("cat", "")).capitalize()))]
	var sid := str(e.get("set", ""))
	if sid != "" and (Decor.data()["sets"] as Dictionary).has(sid):
		var sp := set_progress(sid)
		meta += " · set %d/%d" % [sp[0], sp[1]]
	if s == "owned":
		meta += " · " + find_text(id)
	col.add_child(_label(meta, 7, Color(0.85, 0.85, 0.8)))
	var where := _label(("From: " if s != "missing" else "") + hint(id), 7, Color(0.95, 0.95, 0.85))
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.clip_text = false
	where.max_lines_visible = 2
	col.add_child(where)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 2)
	col.add_child(acts)
	if s == "owned" and Decor.owned(id) > 0:
		var wear := str(e.get("cat", "")) in WEAR_CATS or str(e.get("layer", "")) == "wear"
		var ab := _btn("Wear" if wear else "Place", func() -> void: _use(id), "act:use")
		ab.disabled = GameState.visiting() and not wear
		acts.add_child(ab)
	if s != "missing" and not Decor.is_unique(id) and r != "mythic" and order_price(id) > 0:
		var why := order_block(id)
		var ob := _btn("Order · %s" % Money.amount(order_price(id)), func() -> void: _do_order(id), "act:order")
		ob.disabled = why != "" and not why.begins_with("Not enough")
		acts.add_child(ob)
		if why.begins_with("On order"):
			acts.add_child(_label("arrives tomorrow", 7, Color(0.8, 1, 0.8)))
	elif Decor.is_unique(id) and s != "missing":
		acts.add_child(_label("One of a kind", 7, Decor.rarity_color("unique")))


func _do_order(id: String) -> void:
	var why := order(id)
	if why == "":
		_sfx("cash_register" if Money.sym() == "$" else "j_buy", "coin")
		_say("Ordered %s: it arrives in your decor box tomorrow morning." % name_of(id), Color(0.8, 1, 0.8))
	else:
		_sfx("nope", "thud")
		_say(why, Color(1, 0.7, 0.6))
	_refresh()


## Place (P2's DecorMode) or Wear (P5's Wardrobe), each only when that script exists.
func _use(id: String) -> void:
	var e := Decor.entry(id)
	var wear := str(e.get("cat", "")) in WEAR_CATS or str(e.get("layer", "")) == "wear"
	if not wear:
		_place(id)
		return
	var path := "res://scripts/wardrobe_screen.gd"  # C10b P5: WardrobeScreen.open(map, id)
	var arg: Variant = id
	if not open_other(path, m, arg):
		_sfx("nope", "thud")
		_say("Wear it from the dresser at home." if wear else "Decorate from your house: tap Decorate there.", Color(1, 0.8, 0.6))
		return
	close()


## Place from the box: close this screen (and the menu under it) first, then open
## decorate mode on this map with the piece already held (c10b_09-33). Exterior
## parts go to the farmhouse style picker (P3's HouseExterior) when it exists.
func _place(id: String) -> void:
	var gm: GameMap = (m if m is GameMap else (get_tree().current_scene if get_tree() else null)) as GameMap
	var e := Decor.entry(id)
	if str(e.get("cat", "")).begins_with("exterior") or str(e.get("layer", "")) == "exterior":
		if gm and open_other("res://scripts/house_exterior.gd", gm, id):
			close()
			return
		_sfx("nope", "thud")
		_say("Restyle the farmhouse from its style sign by the door.", Color(1, 0.8, 0.6))
		return
	if gm == null or GameState.visiting() or not DecorMode.can_decorate(gm) or not DecorMode.fits_map(gm, id):
		_sfx("nope", "thud")
		var yard := DecorMode.where_of(id) == "out"
		_say("Yard pieces go outside: Decorate yard on the farm." if yard else "Decorate from your house: tap Decorate there.", Color(1, 0.8, 0.6))
		return
	var why := DecorMode.busy_why(gm)
	if why != "":
		_say(why, Color(1, 0.8, 0.6))
		return
	close()
	for ch in gm.get_children():
		if ch is GameMenu and (ch as GameMenu)._open:
			(ch as GameMenu).toggle()
	var start := func() -> void:
		if not is_instance_valid(gm):
			return
		var dm := DecorMode.open(gm)
		if dm:
			dm._choose.call_deferred(id)
	start.call_deferred()


## Calls <script>.open(map[, arg]) when the script exists. True when it opened.
static func open_other(path: String, map: Node, arg: Variant = null) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var sc: Script = load(path)
	if sc == null:
		return false
	for md: Dictionary in sc.get_script_method_list():
		if str(md["name"]) != "open":
			continue
		var n := (md.get("args", []) as Array).size()
		var map_arg: Variant = map
		if map is GameMap or map == null:
			pass
		elif map.get_tree() and map.get_tree().current_scene:
			map_arg = map.get_tree().current_scene
		if n >= 2 and arg != null:
			sc.call("open", map_arg, arg)
		elif n >= 1:
			sc.call("open", map_arg)
		else:
			sc.call("open")
		return true
	return false


func _sets_view() -> void:
	var sets := _set_ids()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.scroll_deadzone = 8
	_body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	sc.add_child(v)
	if sets.is_empty():
		v.add_child(_label("No sets yet.", 8, Color(0.8, 0.8, 0.75)))
		return
	var data_sets: Dictionary = Decor.data()["sets"]
	for sid: String in sets:
		var s: Dictionary = data_sets[sid]
		var pr := set_progress(sid)
		var done := sets_done().has(sid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		v.add_child(row)
		var nm := _label("%s  %d/%d" % [str(s.get("name", sid)), pr[0], pr[1]], 8, Color(0.6, 1, 0.6) if done else Color(1, 0.95, 0.8))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(40, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = maxi(1, int(pr[1]))
		bar.value = int(pr[0])
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.45, 0.85, 0.45) if int(pr[0]) >= int(pr[1]) else Color(0.95, 0.8, 0.4)
		fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var ready := not done and int(pr[1]) > 0 and int(pr[0]) >= int(pr[1])
		if ready:
			var cb := _btn("Claim", func() -> void:
				var why := claim_set(sid)
				if why == "":
					_sfx("j_treasure", "quest_done")
					_say("%s complete! Reward: %s." % [str(s.get("name", sid)), reward_text(sid)], Color(0.8, 1, 0.8))
				else:
					_say(why)
				_refresh(), "set:" + sid)
			row.add_child(cb)
		var rl := _label(("Claimed: " if done else "Reward: ") + reward_text(sid), 7, Color(0.8, 0.8, 0.75))
		v.add_child(rl)
		var b := _btn("Show pieces ›", func() -> void:
			view = "grid"
			set_i = _set_ids().find(sid) + 1
			cat_i = 0
			rar_i = 0
			show_i = 0
			part = 0
			sel = ""
			_refresh(), "setshow:" + sid)
		v.add_child(b)


func _box_view() -> void:
	var box: Dictionary = Decor.st()["box"]
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.scroll_deadzone = 8
	_body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	sc.add_child(v)
	var keys := box.keys().filter(func(k: Variant) -> bool: return int(box[k]) > 0)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return name_of(str(a)) < name_of(str(b)))
	# Pages of PAGE rows: a full box never builds one row + icon per kind (c10b_12).
	var bpages := maxi(1, ceili(keys.size() / float(PAGE)))
	box_page = clampi(box_page, 0, bpages - 1)
	if bpages > 1:
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 4)
		v.add_child(pr)
		var pv := _btn("◀", func() -> void:
			box_page = posmod(box_page - 1, bpages)
			_refresh(), "box:prev")
		pv.custom_minimum_size = Vector2(40, 22)
		pr.add_child(pv)
		var pl := _label("%d kinds · page %d/%d" % [keys.size(), box_page + 1, bpages], 8, Color(0.9, 0.9, 0.85))
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pr.add_child(pl)
		var nx := _btn("▶", func() -> void:
			box_page = posmod(box_page + 1, bpages)
			_refresh(), "box:next")
		nx.custom_minimum_size = Vector2(40, 22)
		pr.add_child(nx)
	keys = keys.slice(box_page * PAGE, box_page * PAGE + PAGE)
	if keys.is_empty():
		var l := _label("Your decor box is empty. Pieces you buy, win or find land here, never in your bag.", 8, Color(0.8, 0.8, 0.75))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = false
		v.add_child(l)
	for k in keys:
		var id := str(k)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		v.add_child(row)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(22, 22)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = icon_tex(id)
		row.add_child(pic)
		var nm := _label("%s ×%d" % [name_of(id), int(box[k])], 8, Decor.rarity_color(Decor.rarity(id)))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var e := Decor.entry(id)
		var wear := str(e.get("cat", "")) in WEAR_CATS or str(e.get("layer", "")) == "wear"
		var ub := _btn("Wear" if wear else "Place", func() -> void: _use(id), "box:" + id)
		ub.custom_minimum_size = Vector2(44, 22)
		ub.disabled = GameState.visiting() and not wear
		row.add_child(ub)
	var on := orders()
	if not on.is_empty():
		var names := []
		for o in on:
			names.append(name_of(str((o as Dictionary).get("id", ""))))
		var ol := _label("On order (tomorrow): " + ", ".join(names), 7, Color(0.8, 1, 0.8))
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.clip_text = false
		v.add_child(ol)
