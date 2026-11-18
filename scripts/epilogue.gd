class_name Epilogue
extends CanvasLayer
## The end slideshow, after the epilogue scene: where everyone ended up.
## Lines come from data/epilogue.json (tools/gen_epilogue.py). Tap or A for the
## next slide, B to skip. Shown once per run (flag epilogue_shown); the Options
## page can replay it.

signal closed

var _slides: Array = []
var _i := 0
var _title: Label
var _body: Label
var _foot: Label
var _arm := 0


static func data() -> Dictionary:
	var f := FileAccess.open("res://data/epilogue.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _fill(s: String) -> String:
	var n: Dictionary = GameState.run.get("names", {})
	return s.replace("%hero", str(n.get("character", "you"))).replace("%town", str(n.get("town", "the town"))).replace("%pet", str(n.get("pet", "the pup")))


## Every slide for this run: [title, text].
static func build() -> Array:
	var d := data()
	var r := GameState.run
	var out: Array = []
	var ending := str(r.get("ending", ""))
	out.append(["THE END: " + str(d.get("endings", {}).get(ending, "The Farm Goes On")), "%s of %s.\nDay %d. Here is where everyone ended up." % [str(r["names"]["character"]), str(r["names"]["town"]), int(r["day"])]])
	# Choices you made along the way.
	var ch: Array = []
	var dec: Dictionary = r.get("decisions", {})
	for k: String in d.get("choices", {}):
		if dec.has(k):
			var line := str(d["choices"][k].get(str(int(dec[k])), ""))
			if line != "":
				ch.append(_fill(line))
	# Moments flagged during play.
	for fk: String in d.get("flag_lines", {}):
		if r["flags"].has(fk):
			ch.append(_fill(str(d["flag_lines"][fk])))
	if not ch.is_empty():
		out.append(["What you chose", "\n\n".join(ch)])
	# Companions who stayed.
	var comps: Array = []
	for cid in Companion.party().get("known", []):
		var line := str(d.get("companions", {}).get(str(cid), ""))
		# e.g. Nova's line when Grandfather Auk was saved (knight_reverted).
		var alt: Array = d.get("companions_if", {}).get(str(cid), [])
		if alt.size() == 2 and r["flags"].has(str(alt[0])):
			line = str(alt[1])
		if line != "" and str(cid) not in (Companion.party().get("bitter", []) as Array):
			comps.append(line)
	if not comps.is_empty():
		out.append(["Who stayed", "\n\n".join(comps)])
	# Penguins: the colonies. Gangsters: the crew, the lieutenants, the Marked.
	if str(r.get("arc", "")) == "penguins":
		var cl: Array = []
		for id: String in d.get("colonies", {}):
			if bool(Colony.st(id).get("done", false)):
				cl.append(str(d["colonies"][id]))
		out.append(["The islands", "\n\n".join(cl) if not cl.is_empty() else "The merkitty islands still wait for someone to light their beacons. Maybe next summer."])
	else:
		var cr: Array = []
		for id: String in d.get("crew", {}):
			if Crew.recruited(id):
				cr.append(str(d["crew"][id][0 if Crew.loyalty(id) >= 3 else 1]))
		if not cr.is_empty():
			out.append(["The crew", "\n\n".join(cr)])
		# "The Chair" ending: you took the President's place, so nothing "stopped coming".
		var took := str(r.get("ending", "")) == "take"
		var lt: Array = []
		for id: String in d.get("lieutenants", {}):
			if not r["flags"].has("lt_" + id):
				continue
			var how := "joined" if r["flags"].has("lt_joined_" + id) else ("spared" if r["flags"].has("lt_spared_" + id) else "beaten")
			if took and how == "beaten":
				lt.append("%s takes orders from the tower again. Yours." % str(d["lieutenants"][id]))
			else:
				lt.append(str(d["lt_lines"][how]) % str(d["lieutenants"][id]))
		if not lt.is_empty():
			out.append(["The President's lieutenants", "\n\n".join(lt)])
		var mk: Array = []
		for mid in Marked.all():
			var st := Marked.state(str(mid))
			var md: Dictionary = Marked.all()[mid]
			if st == "crew":
				mk.append(("%s \"%s\" stays with your crew. Some nights the stone in their pocket is warm, and they look toward the tower." if took else "%s \"%s\" stays with your crew, and the Gift is steadier now.") % [str(md["name"]), str(md["epithet"])])
			elif st == "free":
				mk.append(("%s \"%s\" went home, and still turns toward the tower without knowing why." if took else "%s \"%s\" went home, and nobody calls them Marked any more.") % [str(md["name"]), str(md["epithet"])])
		if not mk.is_empty():
			out.append(["The Marked", "\n\n".join(mk)])
	# Villagers, closest first, four to a slide.
	var vs: Array = []
	for id: String in d.get("villagers", {}):
		if not GameState.npcs.has(id) or GameState.run["flags"].has(id + "_gone") or (id == "catkins" and not GameState.is_penguins()) or (id != "catkins" and not GameState.run["friendship"].has(id)):
			continue  # only villagers you actually got to know
		vs.append([GameState.friend_hearts(id), _fill(str(d["villagers"][id][0 if GameState.friend_hearts(id) >= 6 else 1]))])
	vs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in range(0, vs.size(), 4):
		var chunk: Array = []
		for v in vs.slice(i, i + 4):
			chunk.append(str(v[1]))
		out.append(["%s" % str(r["names"]["town"]), "\n\n".join(chunk)])
	out.append(["Thank you for playing", "The farm goes on. Your save keeps going: there are crops to grow, friends to make and corners of the map you haven't seen.\n\nMade by Tom and his daughter."])
	return out


static func play(m: GameMap) -> void:
	var e := Epilogue.new()
	e._slides = build()
	m.add_child(e)
	await e.closed


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	get_tree().paused = true
	# The ending gets its own song, not whatever the last fight left playing.
	Music.instance(get_tree()).set_duck(0.0)
	Music.instance(get_tree()).play("title")
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			_next())
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(14, 60)
	_title.size = Vector2(242, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_body = Label.new()
	_body.position = Vector2(18, 110)
	_body.size = Vector2(234, 300)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 9)
	_body.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_foot = Label.new()
	_foot.position = Vector2(14, 440)
	_foot.size = Vector2(242, 20)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.add_theme_font_size_override("font_size", 7)
	_foot.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foot)
	_show()


func _show() -> void:
	var s: Array = _slides[_i]
	_title.text = str(s[0])
	_body.text = str(s[1])
	_foot.text = "%d / %d · tap for more · B to skip" % [_i + 1, _slides.size()]
	_body.modulate.a = 0.0
	create_tween().tween_property(_body, "modulate:a", 1.0, 0.5)


func _process(_d: float) -> void:
	_arm += 1
	if _arm < 10:
		return
	if Input.is_action_just_pressed("a"):
		_next()
	elif Input.is_action_just_pressed("b"):
		_close()


func _next() -> void:
	if _arm < 10:
		return
	_arm = 0
	_i += 1
	if _i >= _slides.size():
		_close()
	else:
		_show()


func _close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	Dialogue.block_input(0.4)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()
