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
var _pic: TextureRect
var _credits_on := false
var _arm := 0
## True while the slideshow is up (Ambience can stay quiet under the title song).
static var showing := false


static func data() -> Dictionary:
	var f := FileAccess.open("res://data/epilogue.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _fill(s: String) -> String:
	var n: Dictionary = GameState.run.get("names", {})
	return s.replace("%hero", str(n.get("character", "you"))).replace("%town", str(n.get("town", "the town"))).replace("%pet", str(n.get("pet", "the pup")))


## Body text area (phone portrait): 234 px wide, font 9. A slide's body may be
## at most BODY_H tall (PIC_BODY_H under a picture); longer lists page on.
const BODY_W := 234.0
const BODY_FONT := 9
const BODY_H := 290.0
const PIC_BODY_H := 168.0
const PIC_SIZE := Vector2(234, 156)


static func text_h(t: String) -> float:
	return ThemeDB.fallback_font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, BODY_W, BODY_FONT).y


## Adds one or more slides for these lines, splitting by measured height:
## "The crew", "The crew (2/3)"... A picture goes on the first page only.
static func paged(out: Array, title: String, items: Array, pic := "") -> void:
	var pages: Array = []
	var cur: Array = []
	for it in items:
		var room := PIC_BODY_H if (pages.is_empty() and pic != "") else BODY_H
		var trial: Array = cur + [str(it)]
		if not cur.is_empty() and text_h("\n\n".join(trial)) > room:
			pages.append(cur)
			cur = [str(it)]
		else:
			cur = trial
	if not cur.is_empty() or pages.is_empty():
		pages.append(cur)
	for i in pages.size():
		var t := title if pages.size() == 1 else "%s (%d/%d)" % [title, i + 1, pages.size()]
		out.append([t, "\n\n".join(pages[i]), pic if i == 0 else ""])


## "a, b and c" (lists in the end slides).
static func join_and(items: Array) -> String:
	if items.size() <= 1:
		return "" if items.is_empty() else str(items[0])
	return ", ".join(items.slice(0, items.size() - 1)) + " and " + str(items[-1])


## A name used mid-sentence: "The Vault" -> "the Vault".
static func mid(n: String) -> String:
	return ("the" + n.substr(3)) if n.begins_with("The ") else n


## Gangster arc conditions for story beats (GameState._cond_ok hook):
## heat_min / heat_max (Racket heat 0-5), loyalty [crew id, n], clean_break
## (true: the Clean Break ending is open; false: it isn't).
static func cond_ok(when: Dictionary) -> bool:
	if when.has("heat_min") and Racket.heat() < int(when["heat_min"]):
		return false
	if when.has("heat_max") and Racket.heat() > int(when["heat_max"]):
		return false
	if when.has("loyalty"):
		var lv: Array = when["loyalty"]
		if not Crew.recruited(str(lv[0])) or Crew.loyalty(str(lv[0])) < int(lv[1]):
			return false
	if when.has("clean_break") and clean_ok() != bool(when["clean_break"]):
		return false
	return true


## The Clean Break (Guide 11 #14): heat 0 at the end, every Marked went home,
## and no shop still taken (a shop you gave back counts as clean).
static func clean_ok() -> bool:
	var fl: Dictionary = GameState.run.get("flags", {})
	if Racket.heat() > 0:
		return false
	for n in [1, 2, 3]:
		if fl.has("shop_%d" % n):
			return false
	var all := Marked.all()
	if all.is_empty():
		return false
	for mid_ in all:
		if Marked.state(str(mid_)) != "free":
			return false
	return true


static func _pic_ok(name: String) -> String:
	return name if name != "" and Art.has("ui", name) else ""


## Every slide for this run: [title, text, picture ("" for none)].
static func build() -> Array:
	var d := data()
	var r := GameState.run
	var fl: Dictionary = r["flags"]
	var gang := str(r.get("arc", "")) != "penguins"
	var hero := str(r.get("playable", ""))
	var known: Array = Companion.party().get("known", [])
	var out: Array = []
	var ending := str(r.get("ending", ""))
	out.append(["THE END: " + str(d.get("endings", {}).get(ending, "The Farm Goes On")), "%s of %s.\nDay %d. Here is where everyone ended up." % [str(r["names"]["character"]), str(r["names"]["town"]), int(r["day"])], _pic_ok(str(d.get("ending_pics", {}).get(ending, "")))])
	# Choices you made along the way.
	var ch: Array = []
	var dec: Dictionary = r.get("decisions", {})
	for k: String in d.get("choices", {}):
		if dec.has(k):
			var line := str(d["choices"][k].get(str(int(dec[k])), ""))
			if fl.has(k + "_returned") and d.get("returned", {}).has(k):
				line = str(d["returned"][k])  # a shop you took and gave back
			if line != "":
				ch.append(_fill(line))
	# Moments flagged during play (a "you" version when you play that character).
	var hfl: Dictionary = d.get("hero_flag_lines", {}).get(hero, {})
	for fk: String in d.get("flag_lines", {}):
		if fl.has(fk):
			var fline := str(hfl.get(fk, d["flag_lines"][fk]))
			for alt in d.get("flag_alt", {}).get(fk, []):  # C12 c12_04-05: Hale lines that fit the ending
				if fl.has(str(alt[0])):
					fline = str(alt[1])
					break
			if fline != "":
				ch.append(_fill(fline))
	if not ch.is_empty():
		paged(out, "What you chose", ch)
	# Companions who stayed.
	var comps: Array = []
	for cid in known:
		if str(cid) == hero:
			continue
		var line := str(d.get("companions", {}).get(str(cid), ""))
		# e.g. Nova's line when Grandfather Auk was saved (knight_reverted).
		var alt: Array = d.get("companions_if", {}).get(str(cid), [])
		if alt.size() == 2 and fl.has(str(alt[0])):
			line = str(alt[1])
		if line != "" and str(cid) not in (Companion.party().get("bitter", []) as Array):
			comps.append(_fill(line))
	if not comps.is_empty():
		paged(out, "Who stayed", comps)
	# Big Jim's tail (Tom's canon): his own slide, with its picture.
	var tail: Dictionary = d.get("tail", {})
	if not tail.is_empty() and (hero == "big_jim" or str(tail.get("known", "")) in known or (not gang and fl.has(str(tail.get("flag", ""))))):
		var tt := str(tail.get("text_hero" if hero == "big_jim" else "text", ""))
		paged(out, "Your tail" if hero == "big_jim" else str(tail.get("title", "")), Array(tt.split("\n\n")), _pic_ok(str(tail.get("pic", ""))))
	# Penguins: the colonies. Gangsters: the crew, the lieutenants, the Marked.
	if not gang:
		var cl: Array = []
		for id: String in d.get("colonies", {}):
			if bool(Colony.st(id).get("done", false)):
				cl.append(str(d["colonies"][id]))
		if cl.is_empty():
			cl = ["The merkitty islands still wait for someone to light their beacons. Maybe next summer."]
		paged(out, "The islands", cl)
	else:
		var took := ending == "take"
		var cr: Array = []
		var solo: Dictionary = d.get("crew_solo", {})
		for id: String in d.get("crew", {}):
			if Crew.recruited(id):
				var pair: Array = d["crew"][id]
				if solo.has(id) and not Crew.recruited("val"):
					pair = solo[id]  # Vic without Val
				var line := str(pair[0 if Crew.loyalty(id) >= 3 else 1])
				if Crew.loyalty(id) >= 3:
					var cif: Array = d.get("crew_if", {}).get(id, [])
					if cif.size() == 2 and fl.has(str(cif[0])) and not fl.has(str(cif[0]) + "_returned"):
						line = str(cif[1])
					if took and d.get("crew_take", {}).has(id):
						line = str(d["crew_take"][id])  # C12 c12_04-10: you sit in the chair now
				cr.append(line)
		# Threads the loyalty scenes planted (the Kid's sister, the twins' brother...).
		var th: Dictionary = d.get("crew_threads", {})
		for id: String in th:
			var t: Array = th[id]
			if Crew.recruited(id) and Crew.loyalty(id) >= int(t[0]) and str(t[2]) != ending:
				cr.append(str(t[1]))
		if not cr.is_empty():
			paged(out, "The crew", cr)
		# "The Chair" ending: you took the President's place, so nothing "stopped coming".
		var lt: Array = []
		for id: String in d.get("lieutenants", {}):
			if not fl.has("lt_" + id):
				continue
			var how := "joined" if fl.has("lt_joined_" + id) else ("spared" if fl.has("lt_spared_" + id) else "beaten")
			if took and how == "beaten":
				lt.append("%s takes orders from the tower again. Yours." % str(d["lieutenants"][id]))
			else:
				lt.append(str(d["lt_lines"][how]) % str(d["lieutenants"][id]))
		if not lt.is_empty():
			paged(out, "The President's lieutenants", lt)
		var mk: Array = []
		for mid_ in Marked.all():
			var st := Marked.state(str(mid_))
			var md: Dictionary = Marked.all()[mid_]
			if st == "crew":
				mk.append(("%s \"%s\" stays with your crew. Some nights the stone in their pocket is warm, and they look toward the tower." if took else "%s \"%s\" stays with your crew, and the Gift is steadier now.") % [str(md["name"]), str(md["epithet"])])
			elif st == "free":
				mk.append(("%s \"%s\" went home, and still turns toward the tower without knowing why." if took else "%s \"%s\" went home, and nobody calls them Marked any more.") % [str(md["name"]), str(md["epithet"])])
		if not mk.is_empty():
			paged(out, "The Marked", mk)
		# The side ops: blocks you hold and jobs you pulled.
		var ops_l: Array = []
		var blocks: Array = []
		for sid in Ops.turf():
			blocks.append(mid(str(Ops.TURF.get(sid, sid))))
		if not blocks.is_empty():
			var bs := join_and(blocks)
			ops_l.append("%s%s answer%s to your crew now. The rent stays on the block." % [bs.left(1).to_upper(), bs.substr(1), "s" if blocks.size() == 1 else ""])
		var jobs: Array = []
		for hid: String in Ops.HEISTS:
			if fl.has("heist_" + hid):
				jobs.append(mid(str(Ops.HEISTS[hid]["name"])))
		if not jobs.is_empty():
			ops_l.append("Nobody ever proved who pulled %s. Nobody got hurt, either." % join_and(jobs))
		if not ops_l.is_empty():
			paged(out, "The blocks", ops_l)
	# Villagers, closest first, as many to a slide as fit.
	var vs: Array = []
	var vg: Dictionary = d.get("villagers_gang", {}) if gang else {}
	var crew_sal := "sal" in known or fl.has("sal_recruited")
	for id: String in d.get("villagers", {}):
		if not GameState.npcs.has(id) or fl.has(id + "_gone") or (id == "catkins" and gang) or (id != "catkins" and not GameState.run["friendship"].has(id)):
			continue  # only villagers you actually got to know
		if id in (d.get("villagers_skip_if_known", []) as Array) and crew_sal:
			continue  # Sal has his line with the crew/companions
		var pair: Array = vg.get(id, d["villagers"][id])
		vs.append([GameState.friend_hearts(id), _fill(str(pair[0 if GameState.friend_hearts(id) >= 6 else 1]))])
	vs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	if not vs.is_empty():
		paged(out, str(r["names"]["town"]), vs.map(func(v: Array) -> String: return str(v[1])))
	if str(d.get("credits", "")) != "":
		out.append(["Credits", str(d["credits"]), ""])
	out.append(["Thank you for playing", "The farm goes on. Your save keeps going: there are crops to grow, friends to make and corners of the map you haven't seen.", _pic_ok(str(d.get("thanks_pics", {}).get("gangsters" if gang else "penguins", "")))])
	return out


static func play(m: GameMap) -> void:
	var e := Epilogue.new()
	e._slides = build()
	m.add_child(e)
	await e.closed


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_hold")  # Hud: morning toasts wait until the slideshow closes
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "epilogue")
	showing = true
	# The ending gets its own song, not whatever the last fight left playing.
	var mu := Music.instance(get_tree())
	mu.set_duck(0.0)
	var end_track := "ending_penguin" if GameState.is_penguins() else "ending_gangster"
	if Music.has_track(end_track):
		# Streamed on the web: the ending and credits jump the download queue; while
		# the ending downloads a packed stand-in plays (never the last fight's song).
		mu.prefetch([end_track, "credits"], true)
		mu.play(end_track, 1.6)
		mu.queue_after("credits")  # if the ending song ends first; the Credits slide starts it otherwise
		mu.queue_after("title", true)  # slides still up after the credits: the title theme
	else:
		mu.play("title")
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if TapInput.press_pos(ev) != Vector2.INF:  # one slide per tap (not the emulated mouse copy too)
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
	_pic = TextureRect.new()
	_pic.position = Vector2(18, 100)
	_pic.size = PIC_SIZE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.visible = false
	add_child(_pic)
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
	var pic := str(s[2]) if s.size() > 2 else ""
	_pic.visible = pic != "" and Art.has("ui", pic)
	if _pic.visible:
		_pic.texture = Art.tex("ui", pic)
		_pic.modulate.a = 0.0
		create_tween().tween_property(_pic, "modulate:a", 1.0, 0.6)
	# Under a picture the text starts lower (paged() kept it short enough).
	_body.position.y = 262.0 if _pic.visible else 110.0
	_body.size.y = 432.0 - _body.position.y
	# The credits song starts with the credits slide and plays on after the close.
	if str(s[0]) == "Credits" and not _credits_on and Music.has_track("credits"):
		_credits_on = true
		var mu := Music.instance(get_tree())
		if mu._current != "credits":
			mu.play("credits", 2.0)
		mu.queue_after("title")
	_foot.text = PadInput.words("%d / %d · tap for more · B to skip" % [_i + 1, _slides.size()])
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
	showing = false
	var gm := get_tree().current_scene as GameMap
	var mu := Music.instance(get_tree())
	if _credits_on and gm and mu._current == "credits":
		mu.queue_after(gm.area_track())  # the credits play out, then the map's song
	else:
		mu.queue_after("")  # the credits never start later, on the map
		if gm:
			mu.play(gm.area_track(), 2.5)  # the ending song winds down, no quick cut
	Dialogue.block_input(0.4)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	showing = false
