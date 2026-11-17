class_name Creator
extends VBoxContainer
## Character creator: body (skin × build), hair style and colour, hat, face.
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


func _init(start_look: Dictionary = {}, playable_sprite := "", with_cancel := false) -> void:
	look = start_look.duplicate() if not start_look.is_empty() else PaperDoll.default_look()
	_playable_sprite = playable_sprite
	_show_cancel = with_cancel
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	Hud.skin_buttons(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Your look"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
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
		phats.append_array(PaperDoll.hat_styles())
		_picker("Hat", phats, "hat", func(v: String) -> String: return "None" if v == "" else v.replace("_", " ").capitalize())
		var ppets: Array = [""]
		for k in Art.manifest().keys():
			if str(k).begins_with("animals/dog_") or str(k).begins_with("animals/cat_"):
				ppets.append(str(k).trim_prefix("animals/"))
		ppets.sort()
		_picker("Pet", ppets, "pet", func(v: String) -> String: return "Pup (classic)" if v == "" else v.replace("_", " ").capitalize())
	elif PaperDoll.available():
		_picker("Body", PaperDoll.BODIES, "body", func(v: String) -> String: return v.replace("_", " ").capitalize())
		_picker("Hair", PaperDoll.hair_styles(), "hair", func(v: String) -> String: return v.replace("_", " ").capitalize())
		_picker("Hair colour", PaperDoll.HAIR_COLORS.keys(), "hair_color", func(v: String) -> String: return v.capitalize())
		var hats: Array = [""]
		hats.append_array(PaperDoll.hat_styles())
		_picker("Hat", hats, "hat", func(v: String) -> String: return "None" if v == "" else v.replace("_", " ").capitalize())
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
	h.add_child(_btn("Random", func() -> void:
		if _playable_sprite == "penguin":
			look["tint_name"] = PaperDoll.PENGUIN_TINTS.keys()[randi() % PaperDoll.PENGUIN_TINTS.size()]
			look["scarf"] = PaperDoll.SCARF_COLORS.keys()[randi() % PaperDoll.SCARF_COLORS.size()]
			var hs := PaperDoll.hat_styles()
			look["hat"] = "" if hs.is_empty() or randf() < 0.4 else hs[randi() % hs.size()]
		else:
			look = PaperDoll.random_look()
		_build()))
	h.add_child(_btn("Done", func() -> void: done.emit(look), true))
	if _show_cancel:
		h.add_child(_btn("Cancel", func() -> void: cancelled.emit()))


func _picker(label: String, options: Array, key: String, pretty: Callable) -> void:
	if options.is_empty():
		return
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 9)
	l.custom_minimum_size = Vector2(62, 0)
	h.add_child(l)
	var idx := options.find(str(look.get(key, "")))
	if idx < 0:
		idx = 0
		look[key] = options[0]
	h.add_child(_btn("<", func() -> void: look[key] = options[(idx - 1 + options.size()) % options.size()]; _build()))
	var nm := Label.new()
	nm.text = str(pretty.call(str(options[idx])))
	nm.add_theme_font_size_override("font_size", 9)
	nm.custom_minimum_size = Vector2(84, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(nm)
	h.add_child(_btn(">", func() -> void: look[key] = options[(idx + 1) % options.size()]; _build()))
	_rows.add_child(h)


func _btn(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 10 if primary else 9)
	b.custom_minimum_size = Vector2(26 if text.length() == 1 else 64, 22)
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
		var body := AnimatedSprite2D.new()
		body.sprite_frames = PaperDoll.body_frames(look)
		body.centered = true
		body.offset = Vector2(0, -48)
		var h := float(PaperDoll.anchor_of("body", str(look.get("body", "medium_slim")), 0)[4])
		var sc := 2.4 * CharacterLibrary.HERO_H / maxf(40.0, h)
		body.scale = Vector2(sc, sc)
		body.play("walk_down")
		body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.add_child(body)
		var hair := Sprite2D.new()
		hair.modulate = Color(str(PaperDoll.HAIR_COLORS.get(str(look.get("hair_color", "brown")), "ffffff")))
		hair.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var hat := Sprite2D.new()
		hat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.add_child(hair)
		_preview.add_child(hat)
		var upd := func() -> void:
			var pose := PaperDoll.pose_index(body.animation, body.frame)
			PaperDoll.place_layer(hair, "hair", str(look.get("hair", "")), str(look.get("body", "medium_slim")), pose, false, sc)
			PaperDoll.place_layer(hat, "hats", str(look.get("hat", "")), str(look.get("body", "medium_slim")), pose, false, sc)
		body.frame_changed.connect(upd)
		upd.call()
	elif _playable_sprite != "":
		var sp := CharacterLibrary.make_sprite(_playable_sprite)
		sp.scale *= 1.6
		sp.play("idle")
		_preview.add_child(sp)
