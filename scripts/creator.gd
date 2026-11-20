class_name Creator
extends VBoxContainer
## Character creator: outfit, hair style and colour, hat, pet.
## Used on the title screen (new game) and at the dresser in the house.
## Emits `done(look)`; `look` is the dictionary stored in run["look"].

signal done(look: Dictionary)
signal cancelled

var look := {}
var _preview_holder: Control
var _preview: Node2D
var _rows: VBoxContainer
var _playable_sprite := ""
var _show_cancel := false
## The arc being built (title screen sets it: the run there may be stale or empty, c10b_11-23).
var arc := ""


func _init(start_look: Dictionary = {}, playable_sprite := "", with_cancel := false) -> void:
	look = start_look.duplicate() if not start_look.is_empty() else PaperDoll.default_look()
	_playable_sprite = playable_sprite
	_show_cancel = with_cancel
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	Hud.skin_buttons(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


var _cancel_armed := 0
## Keys/pad (C9 c9_02): a row cursor. Up/down picks a picker row (or the
## bottom Random/Done/Cancel row), left/right steps that row's choice (or the
## bottom button), A presses the bottom button. The current row is lit.
const LIT := Color(1.3, 1.2, 0.8)
var _rows_cb: Array = []    # [prev Callable, next Callable, HBoxContainer]
var _bottom: Array = []     # [Control, Callable]
var _row := 0
var _col := 1               # bottom row: Done first
var _nav_arm := 0


func _process(_delta: float) -> void:
	_nav()
	# The dresser can be left with B (the press that opened it doesn't count).
	if not _show_cancel or not is_visible_in_tree():
		return
	_cancel_armed += 1
	if _cancel_armed > 6 and Input.is_action_just_pressed("b"):
		_cancel_armed = -999
		cancelled.emit()


func _nav() -> void:
	if not is_visible_in_tree():
		return
	_nav_arm += 1
	if _nav_arm < 6 or not PadFocus.wants_focus():
		_light(false)
		return
	var n := _rows_cb.size() + 1
	if PadInput.nav_pressed("up"):
		_row = (_row - 1 + n) % n
	elif PadInput.nav_pressed("down"):
		_row = (_row + 1) % n
	elif PadInput.nav_pressed("left") or PadInput.nav_pressed("right"):
		var step := -1 if Input.is_action_pressed("left") else 1
		if _row < _rows_cb.size():
			Music.instance(get_tree()).sfx("ui_tap")
			(_rows_cb[_row][0 if step < 0 else 1] as Callable).call()
			return  # _build() rebuilt the rows (the cursor stays on this row)
		_col = clampi(_col + step, 0, _bottom.size() - 1)
	elif Input.is_action_just_pressed("a") and _row == _rows_cb.size() and not _bottom.is_empty():
		Music.instance(get_tree()).sfx("ui_tap")
		(_bottom[clampi(_col, 0, _bottom.size() - 1)][1] as Callable).call()
		return
	_light(true)


func _light(on: bool) -> void:
	for i in _rows_cb.size():
		var h: Control = _rows_cb[i][2]
		if is_instance_valid(h):
			h.modulate = LIT if on and i == _row else Color.WHITE
	for i in _bottom.size():
		var b: Control = _bottom[i][0]
		if is_instance_valid(b):
			b.modulate = LIT if on and _row == _rows_cb.size() and i == _col else Color.WHITE


func _draw() -> void:
	# Prompts-12C creator panel behind everything (drawn by the container itself).
	if Art.has("ui_creator2", "panel"):
		draw_texture_rect(Art.tex("ui_creator2", "panel"), Rect2(Vector2(-10, -12), size + Vector2(20, 46)), false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## A picture button from art/gen/ui_creator2 when the piece exists, else text.
func _icon_btn(piece: String, text: String, cb: Callable, primary := false) -> Control:
	if not Art.has("ui_creator2", piece):
		return _btn(text, cb, primary)
	var b := TextureButton.new()
	b.texture_normal = Art.tex("ui_creator2", piece)
	if Art.has("ui_creator2", piece + "_down"):
		b.texture_pressed = Art.tex("ui_creator2", piece + "_down")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var t := b.texture_normal
	var h := 22.0
	b.custom_minimum_size = Vector2(t.get_width() * h / t.get_height(), h)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.focus_mode = Control.FOCUS_NONE  # the row cursor drives keys/pad (no second focus ring)
	b.pressed.connect(cb)
	return b


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_rows_cb.clear()
	_bottom.clear()
	var title := Label.new()
	title.text = "" if Art.has("ui_creator2", "panel") else "Your look"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 26)  # clears the panel's crest
	add_child(title)
	if Art.has("ui_creator2", "preview"):
		var fr := TextureRect.new()
		fr.texture = Art.tex("ui_creator2", "preview")
		fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fr.custom_minimum_size = Vector2(0, 104)
		_preview_holder = fr
	else:
		_preview_holder = Control.new()
		_preview_holder.custom_minimum_size = Vector2(0, 96)
	add_child(_preview_holder)
	_preview = Node2D.new()
	_preview.position = Vector2(123, 86)
	_preview_holder.add_child(_preview)
	_refresh_preview()
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)
	if _playable_sprite == "penguin":
		_picker("Feathers", PaperDoll.PENGUIN_TINTS.keys(), "tint_name", func(v: String) -> String: return v.capitalize())
		look["tint"] = str(PaperDoll.PENGUIN_TINTS.get(str(look.get("tint_name", "classic")), "ffffff"))
		_picker("Scarf", PaperDoll.SCARF_COLORS.keys(), "scarf", func(v: String) -> String: return "None" if v == "" else v.capitalize())
		var phats: Array = [""]
		if Art.has("characters/penguin_wear", "hat_straw_front"):
			phats.append_array(["straw", "beanie", "tophat", "wizard", "flower_crown", "miner", "sailor", "crown", "pumpkin", "santa", "bucket", "visor"])
		else:
			phats.append_array(PaperDoll.hat_styles())
		_picker("Hat", phats, "hat", func(v: String) -> String: return "None" if v == "" else v.replace("_", " ").capitalize())
		var ppets: Array = [""]
		for k in Art.manifest().keys():
			if str(k).begins_with("animals/dog_") or str(k).begins_with("animals/cat_"):
				ppets.append(str(k).trim_prefix("animals/"))
		ppets.sort()
		_picker("Pet", ppets, "pet", func(v: String) -> String: return "Pup (classic)" if v == "" else v.replace("_", " ").capitalize())
	elif PaperDoll.available():
		# The look's outfit is what the hero wears (PaperDoll.body_for), so that's the picker (the bare skin/build bases never show).
		# At the dresser (with Cancel) clothes and hats live in the wardrobe, so those rows
		# would be covered by worn pieces (c10b_11-15); new game offers the arc's starters.
		if not _show_cancel:
			Wardrobe.arc_override = arc
			var outs: Array = PaperDoll.starter_outfits()
			Wardrobe.arc_override = ""
			if not str(look.get("outfit", "")) in outs and not outs.is_empty():
				look["outfit"] = outs[0]
			_picker("Outfit", outs, "outfit", func(v: String) -> String: return v.trim_prefix("outfit_").capitalize())
		_picker("Hair", PaperDoll.hair_styles(), "hair", func(v: String) -> String: return v.trim_suffix("_b").trim_suffix("_c").replace("_", " ").capitalize() + (" 2" if v.ends_with("_b") else (" 3" if v.ends_with("_c") else "")))
		_picker("Hair colour", PaperDoll.HAIR_COLORS.keys(), "hair_color", func(v: String) -> String: return v.capitalize())
		if not _show_cancel:
			var hats: Array = [""]
			hats.append_array(starter_hats())  # only the free everyday hats; the rest come through the wardrobe (c10b_11-30)
			if not str(look.get("hat", "")) in hats:
				look["hat"] = ""
			_picker("Hat", hats, "hat", func(v: String) -> String: return "None" if v == "" else v.replace("_", " ").capitalize())
		else:
			var nl := Label.new()
			nl.text = "Clothes and hats: Wardrobe (Hero tab or this dresser)."
			nl.add_theme_font_size_override("font_size", 7)
			nl.add_theme_color_override("font_color", Color("4a2c14"))
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_rows.add_child(nl)
		var pets: Array = [""]
		for k in Art.manifest().keys():
			if str(k).begins_with("animals/dog_") or str(k).begins_with("animals/cat_"):
				pets.append(str(k).trim_prefix("animals/"))
		pets.sort()
		_picker("Pet", pets, "pet", func(v: String) -> String: return "Pup (classic)" if v == "" else v.replace("_", " ").capitalize())
	else:
		var l := Label.new()
		l.text = "(Body sheets not sliced: tint picker only.)"
		l.add_theme_font_size_override("font_size", 7)
		_rows.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	add_child(h)
	var rnd := func() -> void:
		if _playable_sprite == "penguin":
			look["tint_name"] = PaperDoll.PENGUIN_TINTS.keys()[randi() % PaperDoll.PENGUIN_TINTS.size()]
			look["scarf"] = PaperDoll.SCARF_COLORS.keys()[randi() % PaperDoll.SCARF_COLORS.size()]
			var hs: Array = ["straw", "beanie", "tophat", "wizard", "flower_crown", "miner", "sailor", "crown", "pumpkin", "santa", "bucket", "visor"] if Art.has("characters/penguin_wear", "hat_straw_front") else PaperDoll.hat_styles()
			look["hat"] = "" if hs.is_empty() or randf() < 0.4 else hs[randi() % hs.size()]
		else:
			var keep := {}
			for k: String in ["outfit", "show_armor", "pet"] + (["hat"] if _show_cancel else []):
				if look.has(k):
					keep[k] = look[k]  # dice re-rolls hair and face, not clothes or the wardrobe toggle (c10b_11-32)
			look = PaperDoll.random_look()
			look.merge(keep, true)
		_build()
	var fin := func() -> void: done.emit(look)
	var bb := _icon_btn("dice", "Random", rnd)
	h.add_child(bb)
	_bottom.append([bb, rnd])
	bb = _icon_btn("done", "Done", fin, true)
	h.add_child(bb)
	_bottom.append([bb, fin])
	if _show_cancel:
		var cc := func() -> void: cancelled.emit()
		bb = _icon_btn("x", "Cancel", cc)
		h.add_child(bb)
		_bottom.append([bb, cc])
	_row = clampi(_row, 0, _rows_cb.size())
	_col = clampi(_col, 0, _bottom.size() - 1)
	_light(PadFocus.wants_focus() and _nav_arm >= 6)


## Free everyday hats (wardrobe starters drawn from hats/): what new game offers.
static func starter_hats() -> Array:
	var out: Array = []
	var items: Dictionary = Wardrobe.data()["items"]
	for id: String in items:
		var e: Dictionary = items[id]
		var h := str((e.get("doll", {}) as Dictionary).get("hat", ""))
		if bool(e.get("starter", false)) and h.begins_with("hats/") and Art.has("hats", h.trim_prefix("hats/")):
			out.append(h.trim_prefix("hats/"))
	out.sort()
	return out


func _picker(label: String, options: Array, key: String, pretty: Callable) -> void:
	if options.is_empty():
		return
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 9)
	if Art.has("ui_creator2", "panel"):
		l.add_theme_color_override("font_color", Color("4a2c14"))  # dark ink on the parchment
	l.custom_minimum_size = Vector2(62, 0)
	h.add_child(l)
	var idx := options.find(str(look.get(key, "")))
	if idx < 0:
		idx = 0
		look[key] = options[0]
	var prev := func() -> void: look[key] = options[(idx - 1 + options.size()) % options.size()]; _build()
	var nxt := func() -> void: look[key] = options[(idx + 1) % options.size()]; _build()
	_rows_cb.append([prev, nxt, h])
	h.add_child(_icon_btn("arrow_l", "<", prev))
	var nm := Label.new()
	nm.text = str(pretty.call(str(options[idx])))
	nm.add_theme_font_size_override("font_size", 9)
	if Art.has("ui_creator2", "panel"):
		nm.add_theme_color_override("font_color", Color("4a2c14"))
	nm.custom_minimum_size = Vector2(84, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(nm)
	h.add_child(_icon_btn("arrow_r", ">", nxt))
	_rows.add_child(h)


func _btn(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 10 if primary else 9)
	b.custom_minimum_size = Vector2(26 if text.length() == 1 else 64, 22)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: Music.instance(get_tree()).sfx("ui_tap"))
	b.pressed.connect(cb)
	return b


func _refresh_preview() -> void:
	for ch in _preview.get_children():
		ch.queue_free()
	if _playable_sprite == "penguin":
		var pg := CharacterLibrary.make_sprite("penguin")
		pg.scale = pg.scale * 3.0
		pg.modulate = Color(str(look.get("tint", "ffffff")))
		pg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pg.play("idle")
		_preview.add_child(pg)
		Player.dress_penguin(_preview, pg, look, 3.0)
		return
	if PaperDoll.available():
		# The outfit you're picking, not the armour or wardrobe piece you wear.
		PaperDoll.build_preview(_preview, look, 2.4, "walk_down", true)
	elif _playable_sprite != "":
		var sp := CharacterLibrary.make_sprite(_playable_sprite)
		sp.scale *= 1.6
		sp.play("idle")
		_preview.add_child(sp)
