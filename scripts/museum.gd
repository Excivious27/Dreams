class_name Museum
extends Node2D
## The museum room (library east wing; interiors.json "museum" from tools/gen_collections.py).
## interior.gd adds one Museum node when interior_id == "museum" (draws donated items in their cases)
## and routes every thing of type "museum" to Museum.use (doorway, donation tray, cases, plaques).
## The tray works without Theo in the room: his thanks arrive by letter the next morning.

var map: GameMap
var _icons := {}   # item -> Sprite2D


static func attach(m: GameMap) -> Museum:
	var mu := Museum.new()
	mu.map = m
	mu.name = "Museum"
	m.add_child(mu)
	mu.refresh()
	return mu


## (Re)draws every donated item in its case: icons are y-sorted map children just in front of the case.
func refresh(sparkle := "") -> void:
	var iv: Variant = map.get("I")
	var room: Dictionary = iv if iv is Dictionary else {}
	for e: Dictionary in room.get("cases", []):
		var id := str(e["item"])
		if _icons.has(id) or not Collections.have("museum", id):
			continue
		var t := Art.sprite("items", id)
		if t == null or t.texture == null:
			continue
		var c := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
		var h := float(maxi(t.texture.get_width(), t.texture.get_height()))
		var s := (10.0 if str(e["wing"]) == "fish" else 11.0) / maxf(1.0, h)
		t.scale = Vector2(s, s)
		var lift := 9.0 if str(e["wing"]) == "fish" else (17.0 if str(e["wing"]) == "artifacts" else 11.0)
		t.position = Vector2(c.x * GameMap.TILE + 8, (c.y + 1) * GameMap.TILE + 0.5)
		t.offset = Vector2(0, -lift / s)
		map.add_child(t)
		_icons[id] = t
		if id == sparkle:
			map.fx("sparkle", t.position + Vector2(0, -lift), 12.0, 0.7)


static func room_name() -> String:
	return Collections.room_name()


static func use(m: GameMap, thing: Dictionary, _c: Vector2i) -> void:
	match str(thing.get("act", "")):
		"enter":
			if not Collections.museum_open():
				m.tell([{"who": "", "text": str(Collections.data().get("letters", {}).get("not_open", "The east wing is closed."))}])
				return
			GameMap.next_interior = "museum"
			m.go_to("interior", m.cell_center(Vector2i(8, 13)), "up")
		"case":
			_look(m, str(thing.get("item", "")))
		"plaque":
			_plaque(m)
		"counter":
			await _tray(m)


static func _look(m: GameMap, id: String) -> void:
	var w := Collections.wing_title(Collections.wing_of(id))
	if Collections.have("museum", id):
		var day := int(Collections.st()["donated"].get(id, 0))
		m.tell([{"who": w, "text": "%s. Donated on day %d." % [GameState.item_name(id), day]}])
	else:
		m.tell([{"who": w, "text": "An empty case. A card reads: \"%s\"" % Collections.where("museum", id)}])


static func _plaque(m: GameMap) -> void:
	var bits := []
	for wd: Dictionary in Collections.data().get("wings", []):
		var wid := str(wd["id"])
		bits.append("%s %d/%d" % [str(wd["title"]), Collections.count("museum", wid), Collections.total("museum", wid)])
	var nx := Collections.next_milestone("museum")
	Music.instance(m.get_tree()).sfx("j_page", "page")
	m.tell([{"who": Collections.room_name(), "text": "  ".join(bits) + ("\nNext: " + str(nx[0]) if not nx.is_empty() else "\nEvery case is full!")}])


## The donation tray: what can I give, one menu page at a time, last option a way out.
static func _tray(m: GameMap) -> void:
	var d := Dialogue.instance(m.get_tree())
	if GameState.visiting():
		m.tell([{"who": "Donation tray", "text": Collections.can_donate("old_coin")}])
		return
	var page := 0
	while true:
		var can := Collections.donatable()
		if can.is_empty():
			m.tell([{"who": "Donation tray", "text": _hint_line()}])
			return
		var start := page * 6
		if start >= can.size():
			page = 0
			start = 0
		var show := can.slice(start, start + 6)
		var opts := []
		for id in show:
			opts.append("%s (%s)" % [GameState.item_name(str(id)), Collections.wing_title(Collections.wing_of(str(id)))])
		var more := can.size() > start + 6
		if more:
			opts.append("More...")
		opts.append("Look at the collection")
		opts.append("Never mind")
		d.say([{"who": "Donation tray", "text": "Give to the museum? Theo will catalogue it tonight.", "choice": opts, "key": ""}])
		await d.finished
		var pick := d.last_choice
		if pick < 0 or pick >= show.size():
			if more and pick == show.size():
				page += 1
				continue
			if pick == show.size() + (1 if more else 0):
				await _open_book(m)
			return
		var id := str(show[pick])
		if GameState.count(id) == 1 and GameState.item_value(id) >= 100:
			d.say([{"who": "Donation tray", "text": "Donate your only %s?" % GameState.item_name(id), "choice": ["Donate", "Keep it"], "key": ""}])
			await d.finished
			if d.last_choice != 0:
				continue
		var why := Collections.donate(id)
		if why != "":
			m.hud.toast(why, Color(1, 0.8, 0.7))
			continue
		Music.instance(m.get_tree()).sfx("j_treasure", "quest_done")
		var wid := Collections.wing_of(id)
		m.hud.toast("%s %d/%d" % [Collections.wing_title(wid), Collections.count("museum", wid), Collections.total("museum", wid)], Color(1, 0.9, 0.5))
		var mu := m.get_node_or_null("Museum") as Museum
		if mu:
			mu.refresh(id)


static func _open_book(m: GameMap) -> void:
	var tree := m.get_tree()
	for i in 120:
		if not Dialogue.input_blocked() and not tree.paused:
			break
		await tree.process_frame
	GameMenu.open_page(tree, "Book", "museum")


## Nothing to give: point at one missing piece from the least complete wing.
static func _hint_line() -> String:
	var best := ""
	var best_r := 2.0
	for wd: Dictionary in Collections.data().get("wings", []):
		var wid := str(wd["id"])
		var tot := Collections.total("museum", wid)
		if tot == 0 or Collections.count("museum", wid) >= tot:
			continue
		var r := float(Collections.count("museum", wid)) / tot
		if r < best_r:
			best_r = r
			best = wid
	if best == "":
		return "Every case is full. Theo has run out of labels."
	for e: Dictionary in Collections.entries("museum", best):
		if not Collections.have("museum", str(e["item"])):
			return "Nothing in your bag for the cases. Theo's note on the tray: \"Still missing in %s: %s\"" % [Collections.wing_title(best), str(e.get("where", ""))]
	return "Nothing in your bag for the cases."
