class_name WardrobeScreen
extends CanvasLayer
## Full-screen wardrobe (C10a P5): slot tabs (Outfit / Hat / Accessory), a live preview
## of your hero, every piece you own for that slot (tap = put on; "Take off" first),
## the Look toggle (show armour or cosmetics), set progress and an honest "shows on"
## line. Opened from the Hero tab and the house dresser: `WardrobeScreen.open(map)`.
## Pad/keyboard: ScreenCursor over the buttons, B closes.

signal closed

const INK := Color("3b2412")
const INK_SOFT := Color("6b4a2c")
const PAPER := Color("f3e2bf")
const EDGE := Color("8a5a2b")

var map: Node
var slot := "outfit"
var sel := ""
var _root: Control
var _arm := 0
var _was_paused := false
var _cursor: ScreenCursor


static func open(m: Node) -> WardrobeScreen:
	var s := WardrobeScreen.new()
	s.map = m
	m.add_child(s)
	return s


func _ready() -> void:
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_hold")  # HUD toasts wait while the wardrobe owns the screen
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "wardrobe")
	Wardrobe.register()
	if Wardrobe.hero_kind() == "penguin":
		slot = "acc"  # what shows on Pip-Pip / Nova
	var got := Wardrobe.sync_unlocks()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()
	if not got.is_empty():
		_note("New in your wardrobe: " + ", ".join(got.map(func(i: String) -> String: return _name(i))))
	_cursor = ScreenCursor.make(self, _root)


func _name(id: String) -> String:
	return str(Wardrobe.entry(id).get("name", id))


func _lab(parent: Control, text: String, size := 8, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Settings.font(size))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, w := 0.0, on := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.custom_minimum_size = Vector2(w, 22)
	b.add_theme_font_size_override("font_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e7c98f") if on else Color("f8ecd2")
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.pressed.connect(func() -> void:
		Music.instance(get_tree()).sfx("ui_tap")
		cb.call())
	parent.add_child(b)
	return b


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2(6, 8)
	bg.size = Vector2(258, 464)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(12, 12)
	v.size = Vector2(246, 456)
	v.add_theme_constant_override("separation", 3)
	_root.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := _lab(top, "Wardrobe", 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(top, "Close", _close, 44).set_meta("pc_key", "close")
	# Preview
	var pv := Control.new()
	pv.custom_minimum_size = Vector2(0, 104)
	pv.clip_contents = true
	v.add_child(pv)
	var holder := Node2D.new()
	holder.position = Vector2(123, 100)
	pv.add_child(holder)
	_preview(holder)
	var kind := Wardrobe.hero_kind()
	var who: String = {"doll": "Your hero wears what you pick.", "penguin": "Scarves, bowties and goggles show on your penguin hero."}.get(kind, "Your hero's clothes are drawn in. Pieces here show on the build-your-own and penguin heroes; they still count toward sets.")
	_lab(v, str(who), 7, INK_SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Slot tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	v.add_child(tabs)
	for s: String in Wardrobe.SHOWN_SLOTS:
		var cnt := Wardrobe.choices(s).size()
		var b := _btn(tabs, "%s %d" % [str(Wardrobe.SLOT_NAMES.get(s, s)), cnt], func() -> void: slot = s; sel = ""; _build(), 0.0, s == slot)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("pc_key", "tab_" + s)
	# List
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 190)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	var cur := Wardrobe.worn_id(slot)
	var off := _btn(list, "Take off (%s)" % (_name(cur) if cur != "" else "nothing worn"), func() -> void: Wardrobe.take_off(slot); _changed(), 0.0, cur == "")
	off.set_meta("pc_key", "off")
	off.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for id: String in Wardrobe.choices(slot):
		_row(list, id, id == cur)
	# Detail
	var d := sel if sel != "" else cur
	if d != "":
		var e := Wardrobe.entry(d)
		var r := Decor.rarity(d)
		_lab(v, "%s · %s%s" % [_name(d), r.capitalize(), "" if str(e.get("set", "")) == "" else " · " + _set_name(str(e["set"]))], 8, _ink(r))
		_lab(v, "%s %s No stats: looks only." % [str(e.get("desc", "")), Wardrobe.shows_label(d)], 7, INK_SOFT)
	# Sets
	var sets := _set_lines()
	if not sets.is_empty():
		_lab(v, "  ".join(sets), 7, INK_SOFT)
	# Look toggle (only the build-your-own hero wears armour sheets)
	if kind != "doll":
		if is_instance_valid(_cursor):
			_cursor.resync.call_deferred()
		return
	var lt := HBoxContainer.new()
	v.add_child(lt)
	var ll := _lab(lt, "When you wear armour or a helm:", 7, INK)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tg := _btn(lt, "Show armour" if Wardrobe.show_armor() else "Show wardrobe", func() -> void: Wardrobe.set_show_armor(not Wardrobe.show_armor()); _changed(), 92)
	tg.set_meta("pc_key", "look_toggle")
	if is_instance_valid(_cursor):
		_cursor.resync.call_deferred()


func _row(list: Control, id: String, worn: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	list.add_child(h)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = icon_tex(id)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var r := Decor.rarity(id)
	var txt := "%s %s%s" % [rank_glyphs(r), _name(id), "  (wearing)" if worn else ""]
	if not Wardrobe.shows_on(id):
		txt += "  ·  doesn't show"
	var b := _btn(h, txt, func() -> void:
		sel = id
		Wardrobe.put_on(id)
		_changed(), 0.0, worn)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", _ink(r))
	b.set_meta("pc_key", "w_" + id)


## Rank dots for the rarity (colour-blind safe, like the Hero tab): ● per rank, ★ unique.
static func rank_glyphs(r: String) -> String:
	if r == "unique":
		return "★"
	var n := mini(5, Decor.rarity_rank(r))
	return "·" if n == 0 else "●".repeat(n)


## Rarity ink readable on parchment (>= 4.5:1).
static func _ink(r: String) -> Color:
	if r == "common" or r == "":
		return INK
	return Decor.rarity_color(r).darkened(0.62)


func _set_name(s: String) -> String:
	return str((Wardrobe.data()["sets"] as Dictionary).get(s, {}).get("name", s.capitalize()))


func _set_lines() -> Array:
	var out: Array = []
	var sets: Dictionary = Wardrobe.data()["sets"]
	for s: String in sets:
		if s == "everyday":
			continue
		var a := str(sets[s].get("arc", ""))
		if a != "" and a != Wardrobe.arc():
			continue
		var tot := 0
		var have := 0
		for id: String in Wardrobe.data()["items"]:
			if str(Wardrobe.data()["items"][id].get("set", "")) == s:
				tot += 1
				if Wardrobe.owns(id):
					have += 1
		out.append("%s %d/%d" % [str(sets[s].get("name", s)), have, tot])
	return out


## Icon for a wear piece: outfit front frame, hat/face front view, penguin piece front.
static func icon_tex(id: String) -> Texture2D:
	var e := Wardrobe.entry(id)
	var d: Dictionary = e.get("doll", {})
	if d.has("body") and Art.has("body", str(d["body"])):
		var info := Art.info("body", str(d["body"]))
		var at := AtlasTexture.new()
		at.atlas = Art.tex("body", str(d["body"]))
		at.region = Rect2(0, 0, int(info.get("cell_w", 96)), int(info.get("cell_h", 96)))
		return at
	var gn := str(d.get("hat", d.get("face", "")))
	if gn == "":
		var pg: Dictionary = e.get("penguin", {})
		gn = str(pg.get("neck", pg.get("face", ""))) + "_front"
	var i := gn.rfind("/")
	if i > 0 and Art.has(gn.left(i), gn.substr(i + 1)):
		var g := gn.left(i)
		var n := gn.substr(i + 1)
		var info2 := Art.info(g, n)
		if info2.has("cell_w"):
			var at2 := AtlasTexture.new()
			at2.atlas = Art.tex(g, n)
			at2.region = Rect2(0, 0, int(info2["cell_w"]), int(info2.get("cell_h", info2.get("h", 96))))
			return at2
		return Art.tex(g, n)
	return null


func _preview(holder: Node2D) -> void:
	var kind := Wardrobe.hero_kind()
	var look: Dictionary = GameState.run.get("look", {})
	if kind == "doll" and PaperDoll.available():
		PaperDoll.build_preview(holder, look, 2.7, "walk_down")
		return
	var pid := str(GameState.run.get("playable", ""))
	var spr := GameState.sprite_for_playable(pid)
	if spr == "" or not CharacterLibrary.has_character(spr):
		return
	var sp := CharacterLibrary.make_sprite(spr)
	sp.scale *= 3.0
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(sp)
	sp.play("walk_down" if sp.sprite_frames.has_animation("walk_down") else "idle")
	if PaperDoll.is_penguin(spr):
		Wardrobe.dress_penguin_hero(holder, sp, spr)


func _changed() -> void:
	_refresh_player()
	_build()


func _refresh_player() -> void:
	if map and "player" in map and map.player and map.player.has_method("refresh_doll"):
		map.player.refresh_doll()


func _note(text: String) -> void:
	if map and "hud" in map and map.hud and map.hud.has_method("toast"):
		map.hud.toast(text, Color(0.8, 1, 0.8))


func _process(_delta: float) -> void:
	_arm += 1
	if _arm < 8:
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		_close()


func _close() -> void:
	if not is_inside_tree():
		return
	Hud.modal_rect = Rect2()
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	Music.instance(get_tree()).sfx("menu_close", "ui_tap")
	Dialogue.block_input(0.3)
	closed.emit()
	queue_free()

