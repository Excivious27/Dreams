class_name CollectionScreen
## The Book tab (GameMenu): Collections hub, then one page per category (museum wings, shipping by
## family, fish, cookbook, crafting by station, forage) plus links to the Field log, journal pages and
## Foes. Pages show a 6-column icon grid (never more than PAGE cells at once); tap a cell for its card.
## State lives here (page/sub/sel/part) so GameMenu only needs one match arm.

const PAGE := 48
const COLS := 6
static var page := ""      # "" = hub, else a cat id
static var sub := ""       # wing / family / station (grouped pages)
static var part := 0       # page within a long group
static var sel := ""       # the tapped entry key


static func open(cat: String) -> void:
	page = cat
	sub = ""
	part = 0
	sel = ""


## B on a Book page steps back one level (entry card, then page, then hub).
## True when it went back; false on the hub (the menu then closes).
static func back() -> bool:
	if sel != "":
		sel = ""
		return true
	if page != "":
		page = ""
		sub = ""
		part = 0
		return true
	return false


static func build(gm: Node) -> void:
	if page == "":
		_hub(gm)
	else:
		_page(gm)


static func _badge(gm: Node, row: Control, name: String, lit: bool) -> void:
	if not Art.has("ui", name):
		return
	var ir := TextureRect.new()
	ir.texture = Art.tex("ui", name)
	ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ir.custom_minimum_size = Vector2(18, 18)
	ir.modulate = Color(1, 1, 1, 1) if lit else Color(0.35, 0.35, 0.35, 0.8)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ir)


static func _top_claimed(cat: String) -> bool:
	var last := ""
	for m: Dictionary in Collections.data().get("milestones", []):
		if str(m["cat"]) == cat:
			last = str(m["id"])
	return last != "" and Collections.st()["claimed"].has(last)


static func _hub(gm: Node) -> void:
	var badges := 0
	var all_b := 0
	for c: Dictionary in Collections.cats():
		all_b += 1
		if _top_claimed(str(c["id"])):
			badges += 1
	var head := HBoxContainer.new()
	gm._body.add_child(head)
	_badge(gm, head, "medal_champion", badges == all_b)
	var hl := Label.new()
	hl.text = "Collections · %d%% · Badges %d/%d" % [Collections.percent(), badges, all_b]
	hl.add_theme_font_size_override("font_size", 9)
	hl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	head.add_child(hl)
	for c: Dictionary in Collections.cats():
		var cid := str(c["id"])
		var row := HBoxContainer.new()
		gm._body.add_child(row)
		_badge(gm, row, str(c.get("badge", "")), _top_claimed(cid))
		var got := Collections.count(cid)
		var tot := Collections.total(cid)
		var b: Button = gm._button("%s%s  %d/%d ›" % [str(c["title"]), "  • New!" if Collections.is_new(cid) else "", got, tot], func() -> void: open(cid); gm._refresh())
		gm._body.remove_child(b)
		row.add_child(b)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(36, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = maxi(1, tot)
		bar.value = got
		row.add_child(bar)
	var r: Dictionary = GameState.run
	gm._button("Field log: %d of %d crops grown ›" % [(r.get("grown", {}) as Dictionary).size(), GameState.crops.size()], func() -> void: gm._tab = "FieldLog"; gm._refresh())
	gm._line("Wayfarer's Journal: %d/%d pages · hidden chests %d/%d" % [Secrets.found("page_"), Secrets.pages_total(), Secrets.found("secret_chest_") + Secrets.found("hidden_chest_"), Secrets.chests_total()], 8, Color(0.85, 0.85, 0.8))
	gm._button("Foes & Gifts: %d kinds met ›" % (r.get("kill_counts", {}) as Dictionary).size(), func() -> void: gm._tab = "Foes"; gm._refresh())
	gm._line("Shipping counts from the day the log arrived. Museum: the library's east wing.", 7, Color(0.65, 0.65, 0.65))


static func _groups(cat: String) -> Array:
	var out := []
	match cat:
		"museum":
			for w: Dictionary in Collections.data().get("wings", []):
				out.append([str(w["id"]), str(w["title"])])
		"shipping":
			var seen := {}
			for e: Dictionary in Collections.entries("shipping"):
				var f := str(e.get("family", ""))
				if not seen.has(f):
					seen[f] = true
					out.append([f, f])
		"crafting":
			var seen2 := {}
			for e: Dictionary in Collections.entries("crafting"):
				var s := str(e["station"])
				if not seen2.has(s):
					seen2[s] = true
					out.append([s, Crafting.label(s)])
	return out


static func _page(gm: Node) -> void:
	var cat := page
	Collections.clear_new(cat)
	gm._line("%s · %d/%d" % [Collections.cat_title(cat), Collections.count(cat), Collections.total(cat)], 9, Color(1, 0.9, 0.6))
	var groups := _groups(cat)
	var ents: Array
	if groups.is_empty():
		ents = Collections.entries(cat)
	else:
		if sub == "":
			sub = str(groups[0][0])
		for g: Array in groups:
			var gid := str(g[0])
			var open_g := gid == sub
			var n := 0
			var t := 0
			for e: Dictionary in _of_group(cat, gid):
				t += 1
				if Collections.have(cat, _key(cat, e)):
					n += 1
			gm._button("%s %s  %d/%d" % ["▾" if open_g else "▸", str(g[1]), n, t], func() -> void: sub = gid; part = 0; sel = ""; gm._refresh())
			if open_g:
				ents = _of_group(cat, gid)
				_grid(gm, cat, ents)
		ents = []
	if not ents.is_empty():
		_grid(gm, cat, ents)
	var nx := Collections.next_milestone(cat)
	if not nx.is_empty():
		gm._line("Next: " + str(nx[0]), 8, Color(0.8, 1, 0.8))
	if cat == "shipping":
		gm._line("Counts start the day the log arrived.", 7, Color(0.65, 0.65, 0.65))
	gm._button("← Back to Book", func() -> void: page = ""; sub = ""; sel = ""; gm._refresh())


static func _of_group(cat: String, gid: String) -> Array:
	if cat == "museum":
		return Collections.entries("museum", gid)
	var out := []
	for e: Dictionary in Collections.entries(cat):
		if str(e.get("station" if cat == "crafting" else "family", "")) == gid:
			out.append(e)
	return out


static func _key(cat: String, e: Dictionary) -> String:
	return str(e["recipe"]) if cat in ["cooking", "crafting"] else str(e["item"])


static func _grid(gm: Node, cat: String, ents: Array) -> void:
	var pages := int(ceil(ents.size() / float(PAGE)))
	part = clampi(part, 0, maxi(0, pages - 1))
	var shown := ents.slice(part * PAGE, part * PAGE + PAGE)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	gm._body.add_child(g)
	var card := ""
	for e: Dictionary in shown:
		var key := _key(cat, e)
		var got := Collections.have(cat, key)
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 30)
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		var item := str(e["item"])
		var ic := Hud.icon_for(item)
		if Art.has("items", ic):
			var ir := TextureRect.new()
			ir.texture = Art.tex("items", ic)
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.set_anchors_preset(Control.PRESET_FULL_RECT)
			ir.offset_left = 4
			ir.offset_right = -4
			ir.offset_top = 3
			ir.offset_bottom = -3
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ir.modulate = Color(1, 1, 1) if got else Color(0, 0, 0, 0.6)
			b.add_child(ir)
		if not got:
			b.text = "?"
		elif cat != "museum" and cat != "forage":
			var n := Collections.amount_of(cat, key)
			if n > 1:
				b.text = str(mini(n, 999))
				b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
				b.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.add_theme_font_size_override("font_size", 7)
		if key == sel:
			b.modulate = Color(1, 0.95, 0.6)
			card = _card(cat, e, got)
		b.pressed.connect(func() -> void: sel = key; Music.instance(gm.get_tree()).sfx("ui_tap"); gm._refresh())
		g.add_child(b)
	if card != "":
		gm._line(card, 8, Color(0.95, 0.95, 0.85))
	if pages > 1:
		gm._button("Page %d/%d ›" % [part + 1, pages], func() -> void: part = (part + 1) % pages; sel = ""; gm._refresh())


static func _card(cat: String, e: Dictionary, got: bool) -> String:
	var key := _key(cat, e)
	var name := str(e.get("name", GameState.item_name(str(e["item"])))) if cat in ["cooking", "crafting"] else GameState.item_name(str(e["item"]))
	if not got:
		var w := str(e.get("where", ""))
		if cat in ["cooking", "crafting"]:
			return "???  (a recipe at the %s)" % str(e["station"]).replace("_", " ")
		return "???  " + w
	var c := Collections.st()
	match cat:
		"museum":
			return "%s · Donated on day %d ✓" % [name, int(c["donated"].get(key, 0))]
		"fish":
			var f: Dictionary = c["caught"].get(key, {})
			return "%s · caught %d · first on day %d%s" % [name, int(f.get("n", 1)), int(f.get("first", 0)), " · at night" if bool(f.get("night", false)) else ""]
		"forage":
			return "%s · found" % name
	return "%s · %d" % [name, Collections.amount_of(cat, key)]
