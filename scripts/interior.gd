extends GameMap
## A building interior from data/interiors.json (GameMap.next_interior picks which).
## Floor + wall kit, furniture, a counter for shops, an NPC or two, and the door back.

var I: Dictionary = {}
var interior_id := ""
var npcs: Array = []

## Furniture art whose slice holds a whole row, a rule line or a baked caption:
## the one piece to show, as [sheet w, sheet h, x, y, w, h] in texture px. Only
## used while the file still has that exact size (a clean re-slice skips it).
const ART_CROP := {
	"stool_red": [67, 36, 0, 0, 20, 24], "stool_blue": [67, 36, 23, 0, 21, 24], "stool_green": [67, 36, 47, 0, 20, 24],
	"flour_sacks": [426, 117, 9, 9, 100, 98],
	"pew_a": [139, 46, 0, 0, 66, 40], "pew_b": [139, 46, 75, 0, 64, 40],
	"stained_a_day": [255, 61, 5, 6, 32, 46], "stained_b_day": [255, 61, 98, 6, 31, 46], "stained_c_day": [255, 61, 185, 6, 32, 46],
	"crate_carrots": [52, 47, 0, 0, 52, 38], "crate_tomatoes": [50, 46, 0, 0, 50, 37],
	"shelf_cans": [50, 95, 0, 0, 50, 90], "shelf_dry": [50, 96, 0, 0, 50, 90], "shelf_house": [50, 96, 0, 0, 50, 90],
	"shelf_misc": [50, 96, 0, 0, 50, 90], "shelf_seeds": [190, 99, 8, 6, 52, 88],
	"chair2_a_left": [98, 35, 81, 7, 17, 28], "chair2_a_right": [98, 35, 0, 7, 17, 28],
	"charts_hammock": [311, 196, 15, 85, 192, 102],
}

## Back-wall middle pieces per kit that tile cleanly side by side (the full
## _m/_m2/_m3 cycle steps or breaks for these: marble capitals, floral roses).
const WALL_MIDS := {"wl_marble": ["_m2"], "wl_floral": ["_m2"], "wl_wood": ["_m2"], "wl_hut": ["_m2"], "wl_log": ["_m", "_m2"], "wl_mill": ["_m2"], "wl_curve": ["_m"], "wl_reed": ["_m3"], "wl_plaster": ["_m2"], "wl_timber": ["_m2"]}


static func art_crop(g: String, nm: String) -> Rect2:
	if not ART_CROP.has(nm):
		# Uncut sheets often carry a caption or rule line just under the art.
		var tc := Art.tex(g, nm)
		return caption_crop(tc) if tc and not Art.info(g, nm).has("cell_w") else Rect2()
	var t := Art.tex(g, nm)
	var a: Array = ART_CROP[nm]
	if t == null or t.get_width() != int(a[0]) or t.get_height() != int(a[1]):
		return Rect2()
	return Rect2(float(a[2]), float(a[3]), float(a[4]), float(a[5]))


## A thin band (caption text or a rule line, 1-6 rows) under the art with a gap
## above it: the rect of the art without it, or an empty Rect2. Cached per texture.
static var _cap := {}


static func caption_crop(t: Texture2D) -> Rect2:
	var key := t.resource_path if t.resource_path != "" else str(t.get_instance_id())
	if _cap.has(key):
		return _cap[key]
	var out := Rect2()
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var rw := PackedInt32Array()
		rw.resize(h)
		var mx := 0
		for y in h:
			var n := 0
			for x in w:
				if img.get_pixel(x, y).a > 0.16:
					n += 1
			rw[y] = n
			mx = maxi(mx, n)
		var lim := mx * 0.15
		var y2 := h - 1
		while y2 >= 0 and rw[y2] == 0:
			y2 -= 1
		var band := 0
		while y2 >= 0 and rw[y2] > lim:
			band += 1
			y2 -= 1
		var gap := 0
		while y2 >= 0 and rw[y2] <= lim:
			gap += 1
			y2 -= 1
		if band >= 1 and band <= 6 and gap >= 1 and y2 > h / 2:
			out = Rect2(0, 0, w, y2 + 1)
	_cap[key] = out
	return out


## Back-wall columns with a window, as ints (JSON numbers load as floats, and 4 in [4.0] is false).
func window_cols() -> Array:
	var out := []
	for wx in I.get("windows", [4, cols - 5]):
		out.append(int(wx))
	return out


func scene_id() -> String:
	return "interior"


func default_spawn() -> Vector2:
	var d: Array = I.get("door", [cols / 2, rows - 2])
	return cell_center(Vector2i(int(d[0]), int(d[1]) - 1))


func build() -> void:
	interior_id = GameMap.next_interior if GameMap.next_interior != "" else str(GameState.run.get("interior", "store"))
	GameMap.next_interior = ""
	GameState.run["interior"] = interior_id
	var all := GameState.load_json("res://data/interiors.json")
	I = all.get(interior_id, all.get("store", {}))
	cols = int(I.get("cols", 14))
	rows = int(I.get("rows", 11))
	if bool(I.get("rec", false)):
		I = RecCenter.build_room(self, I)  # arc skin, lane cells
	else:
		I = arc_skin(I)
	exact_footprints = true
	has_sky = false
	has_pet = bool(I.get("pet", false))
	music_track = str(I.get("music", "house"))
	block_rect(1, 1, cols - 2, 1)  # back wall
	var d: Array = I.get("door", [cols / 2, rows - 2])
	set_thing(int(d[0]), int(d[1]), {"type": "exit", "hint": str(I.get("door_hint", "A: go outside"))}, false)
	for t in I.get("things", []):
		var c: Array = t["cell"]
		var dd := {}
		for k in t:
			if k != "cell":
				dd[k] = t[k]
		set_thing(int(c[0]), int(c[1]), dd, bool(t.get("solid", true)))


## Gangster-town look for a room (c5_04 #1): interiors.json "gangsters" block.
## Plain keys replace the room's (floor, wall, intro, music, windows...);
## "prop_swap" {old: new} renames props, "props_add" appends props,
## "props_drop" [names] removes them, "texts" {thing index: text} rewords notes,
## "if_flag" {flag: block} applies a further block once that flag is set
## (a crew member's shop moved in). Never writes into the loaded data.
static func arc_skin(d: Dictionary) -> Dictionary:
	if GameState.is_penguins() or not (d.get("gangsters") is Dictionary):
		return d
	var out := d.duplicate(true)
	var g: Dictionary = d["gangsters"]
	_skin_merge(out, g)
	var fl: Dictionary = GameState.run.get("flags", {})
	var ifs: Dictionary = g.get("if_flag", {})
	for f: String in ifs:
		if fl.has(f):
			_skin_merge(out, ifs[f])
	out.erase("gangsters")
	return out


## The room's name in this arc when a crew shop has moved in ("" = the usual
## name): PlaceNames asks this so a reload inside still says Specs' Net Cafe.
static var _all_rooms: Dictionary = {}
static func skin_name(iid: String) -> String:
	if GameState.is_penguins():
		return ""
	if _all_rooms.is_empty():
		_all_rooms = GameState.load_json("res://data/interiors.json")
	var d: Dictionary = _all_rooms.get(iid, {})
	if not (d.get("gangsters") is Dictionary):
		return ""
	return str(arc_skin(d).get("name", ""))


static func _skin_merge(out: Dictionary, g: Dictionary) -> void:
	for k: String in g:
		match k:
			"if_flag":
				pass
			"prop_swap":
				var sw: Dictionary = g[k]
				for p: Dictionary in out.get("props", []):
					if sw.has(str(p.get("name", ""))):
						p["name"] = sw[str(p["name"])]
			"props_drop":
				var keep: Array = []
				for p: Dictionary in out.get("props", []):
					if not (str(p.get("name", "")) in g[k]):
						keep.append(p)
				out["props"] = keep
			"props_add":
				var ps: Array = out.get("props", [])
				for p: Dictionary in g[k]:
					ps.append(p.duplicate(true))
				out["props"] = ps
			"texts":
				var th: Array = out.get("things", [])
				for i: String in g[k]:
					if int(i) < th.size():
						(th[int(i)] as Dictionary)["text"] = g[k][i]
			_:
				out[k] = g[k]


func after_ready() -> void:
	if bool(I.get("rec", false)):
		RecCenter.dress(self, interior_id)
	for p in I.get("props", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		var g := str(p.get("group", "furniture"))
		var nm := str(p["name"])
		if nm == "window_day" and GameState.is_night() and Art.has(g, "window_night"):
			nm = "window_night"
		var anim := bool(p.get("anim", false))
		if nm == "lamp_mechanism" and not GameState.run["flags"].has("lighthouse_lit") and Art.has(g, "lamp_mechanism_unlit"):
			nm = "lamp_mechanism_unlit"  # dark lens until the lighthouse is relit (c5_04 #4)
			anim = false
		var w := int(p.get("w", 0))
		if anim and Art.has(g, nm) and int(Art.info(g, nm).get("frames", 1)) > 1:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.frames(g, {"idle": nm}, {"idle": float(p.get("fps", 5.0))})
			a.animation = "idle"
			# Fitted like the still props: its footprint wide, never above the wall top.
			var ai := Art.info(g, nm)
			var amaxw := (w + 1) * TILE * 1.2 + 4.0
			var amaxh := minf(TILE * 3.4, (c.y + 1) * TILE)
			var asc := minf(0.5, minf(amaxw / maxf(1.0, float(ai.get("cell_w", 48))), amaxh / maxf(1.0, float(ai.get("cell_h", 48)))))
			a.scale = Vector2(asc, asc)
			a.position = cell_pos(c.x + (w + 1) / 2.0, c.y + 1)
			a.offset = Vector2(0, -float(Art.info(g, nm).get("cell_h", 48)) / 2.0)
			add_child(a)
			a.play("idle")
			if bool(p.get("solid", true)):
				for i in w + 1:
					blocked[Vector2i(c.x + i, c.y)] = true
			continue
		# Fit every piece to its footprint: painted furniture comes in all sizes,
		# and a wool bale must not be wider than the hut.
		var info := Art.info(g, nm)
		var tw := float(info.get("cell_w", info.get("w", 32)))
		var th := float(info.get("cell_h", info.get("h", 32)))
		var crop := art_crop(g, nm)
		if crop.has_area():
			tw = crop.size.x
			th = crop.size.y
		var on_wall := c.y <= 1
		var maxw := TILE * 1.6 if on_wall else (w + 1) * TILE * 1.2 + 4.0
		if on_wall:
			# Pictures never hang over the wall's windows: none on or between two, one cell wide beside one.
			var wins := window_cols()
			if c.x in wins or ((c.x - 1) in wins and (c.x + 1) in wins):
				continue
			if (c.x - 1) in wins or (c.x + 1) in wins:
				maxw = TILE
		# Pieces on the edge columns stop at the side walls.
		var cxp := (c.x + (w + 1) / 2.0) * TILE
		maxw = maxf(TILE, minf(maxw, 2.0 * minf(cxp - TILE, (cols - 1) * TILE - cxp)))
		# Never taller than the room above it: big machines by the back wall stop at the wall top.
		var maxh := TILE * 1.5 if on_wall else minf(TILE * 3.4, (c.y + 1) * TILE)
		var sc := minf(0.5, minf(maxw / maxf(1.0, tw), maxh / maxf(1.0, th)))
		var ps := prop(g, nm, c, w, 0.0, bool(p.get("solid", true)), sc)
		if ps and nm in ["window_day", "window_night"]:
			_win_props.append([ps, g])
		if ps and crop.has_area():
			ps.region_enabled = true
			ps.region_rect = crop
			ps.offset = Vector2(0, -crop.size.y / 2.0)
		if ps and (nm.begins_with("rug") or nm.begins_with("reed_mat") or nm.begins_with("pelt_") or nm == "round_rug_stone"):
			to_under(ps)  # rugs lie flat: you walk over them, not behind them
	# Keep the way in and the spot in front of every counter/thing walkable.
	var dd: Array = I.get("door", [cols / 2, rows - 2])
	blocked.erase(Vector2i(int(dd[0]), int(dd[1]) - 1))
	for t in I.get("things", []):
		var tc := Vector2i(int(t["cell"][0]), int(t["cell"][1]))
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var fc: Vector2i = tc + off
			if fc.x > 0 and fc.y > 1 and fc.x < cols - 1 and fc.y < rows - 1 and not things.has(fc):
				blocked.erase(fc)
				hard.erase(fc)
				break
	# Who is in here right now: anyone whose routine puts them in this interior
	# (their work, their home, or a named place like the inn/school/chapel). The
	# interior's own "npcs" list gives preferred standing cells; everyone else
	# takes a free floor cell.
	var listed := {}
	for n in I.get("npcs", []):
		listed[str(n["id"])] = Vector2i(int(n["cell"][0]), int(n["cell"][1]))
	if bool(I.get("rec", false)):
		listed.merge(RecCenter.stand_cells(interior_id), true)  # visitors at lanes and cabinets
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(interior_id) + int(GameState.run["day"])
	var used := {}
	var dl: Array = I.get("door", [cols / 2, rows - 2])
	for id in GameState.npcs:
		if GameState.run["flags"].has(str(id) + "_gone"):
			continue
		var data: Dictionary = GameState.npcs.get(id, {"name": str(id).capitalize()})
		var place := Npc.place_now(data.get("routine", []), str(id))
		var here := _interior_matches(place, str(id))
		if data.get("routine", []).is_empty():
			here = listed.has(id)  # region folk with no routine: where the file says
		if not here:
			continue
		# A shopkeeper at home in their own shop after hours: off duty, not at the counter.
		# Keepers with no routine (place "") are off duty in the same closed hours as _counter.
		var tnow := int(GameState.run["time"]) % 1440
		var off_duty := (place == "home" or (place == "" and (tnow < 7 * 60 or tnow >= 21 * 60))) and str(data.get("work", "")) == interior_id
		var at: Vector2i = Vector2i(-1, -1) if off_duty else listed.get(id, Vector2i(-1, -1))
		var posted := at != Vector2i(-1, -1)
		# A listed cell under furniture (or a thing) isn't a place to stand.
		if posted and (blocked.has(at) or (things.has(at) and not RecCenter.stand_on(things[at]))):
			at = Vector2i(-1, -1)
			posted = false
		if at == Vector2i(-1, -1) or used.has(at):
			for tries in 60:
				var c := Vector2i(rng.randi_range(2, cols - 3), rng.randi_range(4, rows - 3))
				if not blocked.has(c) and not blocked.has(c + Vector2i(0, 1)) and not blocked.has(c + Vector2i(0, -1)) and not things.has(c) and not used.has(c) and not (absi(c.x - int(dl[0])) <= 1 and c.y >= int(dl[1]) - 2):
					at = c
					break
		if at == Vector2i(-1, -1):
			continue
		used[at] = true
		var npc := Npc.new()
		npc.map = self
		npc.setup(str(id), data, cell_center(at))
		# Keepers hold their post behind the counter; visitors drift a little.
		npc.wander = 0.0 if posted else 6.0
		add_child(npc)
		npcs.append(npc)
	if I.has("intro") and not GameState.run["flags"].has("int_" + interior_id):
		GameState.run["flags"]["int_" + interior_id] = true
		player.frozen = true
		await say([{"text": str(I["intro"])}])
		player.frozen = false


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.cell() == c:
			return true
	return false


## Does a routine place ("work", "home", "inn", ...) mean this interior?
func _interior_matches(place: String, npc_id := "") -> bool:
	var nd: Dictionary = GameState.npcs.get(npc_id, {})
	match place:
		"work": return interior_id == str(nd.get("work", "")) or (nd.get("work", null) == null and interior_id in ["store", "smith", "potions", "hall", "bakery", "clinic", "library", "fishing_hut", "lodge", "inn"])
		"home": return interior_id == str(nd.get("home", "")) or (nd.get("home", null) == null and interior_id in ["mansion", "cottage_a", "cottage_b", "cottage_c", "hazel_house", "lodge"])
		"inn": return interior_id == "inn"
		"chapel": return interior_id == "chapel"
		"school": return interior_id == "school"
		"clinic": return interior_id == "clinic"
		"library": return interior_id == "library"
		"hall": return interior_id == "hall"
		"rec": return interior_id == RecCenter.floor_of(npc_id)
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0):
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"exit":
			_leave()
			return true
		"rec":
			later(RecCenter.use.bind(self, thing, c))
			return true
		"counter":
			later(_counter.bind(str(thing.get("shop", ""))))
			return true
		"craft":
			later(Crafting.run.bind(self, str(thing.get("station", "workbench")), str(thing.get("hint", "")).trim_prefix("A: "), "town"))
			return true
		"stable":
			later(_stable)
			return true
		"bank":
			later(_bank)
			return true
		"note":
			tell([{"who": str(thing.get("who", "")), "text": str(thing.get("text", "...")), "mood": str(thing.get("mood", "neutral"))}])
			return true
		"bed":
			hud.toast("Not your bed.")
			return true
		"loot":
			var key := "loot_%s_%d_%d" % [interior_id, c.x, c.y]
			if int(GameState.run["flags"].get(key, 0)) <= int(GameState.run["day"]) - int(thing.get("every", 1)):
				GameState.run["flags"][key] = int(GameState.run["day"])
				give(str(thing.get("item", "stone")), int(thing.get("n", 1)))
			else:
				hud.toast(str(thing.get("empty", "Nothing here right now.")))
			return true
		"heal":
			if int(GameState.run["energy"]) >= int(GameState.run["max_energy"]) and int(GameState.run["hp"]) >= int(GameState.run["max_hp"]):
				hud.toast("You're fully rested. Come back when you're tired.")  # keep today's rest for later
			elif int(GameState.run["flags"].get("heal_" + interior_id, 0)) < int(GameState.run["day"]):
				GameState.run["flags"]["heal_" + interior_id] = int(GameState.run["day"])
				GameState.heal(int(thing.get("hp", 3)))
				var got := GameState.rest_energy(int(thing.get("energy", 30)))
				hud.toast(str(thing.get("msg", "You feel better.")) + ("  +%d energy." % got if got > 0 else ("  You've rested plenty today." if int(GameState.run.get("rest_en", 0)) >= int(GameState.run["max_energy"]) / 2 else "")))
			else:
				hud.toast("Once a day.")
			return true
	return false


func _talk(n: Npc) -> void:
	emote(n, "talk", 1.0, -30.0)
	# Same lines as on the street: the town script owns the dialogue tables.
	var data: Dictionary = GameState.npcs.get(n.id, {})
	var lines: Array = data.get("inside", [])
	var name := str(data.get("name", n.id.capitalize()))
	player.frozen = true
	if not GameState.run["talked_today"].has(n.id):
		GameState.run["talked_today"][n.id] = true
		GameState.add_friend(n.id, 5)
	if await Story.talk(self, n.id):
		Intros.mark(n.id)  # a story beat was the meeting
		player.frozen = false
		return
	if not (n.id == "sal" and GameState.quest_done("clear_meadow")) and await Intros.talk(self, n.id):
		player.frozen = false
		return
	# Sal joins after the meadow wherever you find him (the inn too).
	if n.id == "sal" and not GameState.is_penguins() and GameState.quest_done("clear_meadow") and not GameState.run["flags"].has("sal_recruited"):
		GameState.run["flags"]["sal_recruited"] = true
		GameState.add_quest("gang", "Recruit your first crew in Hideout town: Deuce at his card table, Mama Rosa at the kitchen door.")
		await say([
			{"who": "Sal", "text": "That was the President's man in the meadow. Not a good one, but one of his. You sent him running."},
			{"who": "Sal", "text": "I used to run with a crew in the river cities, before. If you're building something... I'm in. Call it rent."},
		])
		player.frozen = false
		return
	if await Hearts.talk(self, n.id):
		player.frozen = false
		return
	if await SideStory.talk(self, n.id):  # C7 P4 side stories
		player.frozen = false
		return
	if await Quests.talk(self, n.id, name):
		player.frozen = false
		return
	# Gifts work indoors too.
	var sel := str(GameState.run["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	if GameState.can_gift(n.id, sel) and await confirm_gift(name, sel):
		var gain := GameState.give_gift(n.id, sel)
		await say([{"who": name, "text": gift_reaction(name, sel, gain)}])
		hud.toast("%s %s%d" % [name, "+" if gain >= 0 else "", gain], Color(1, 0.8, 0.9) if gain > 0 else Color(1, 0.7, 0.7))
		player.frozen = false
		return
	var hl := Hearts.daily(n.id)
	if bool(I.get("rec", false)) and str(data.get("work", "")) != interior_id:
		await RecCenter.visitor_talk(self, n)  # out for the evening: they talk about the games (and let you at their cabinet)
	elif hl != "" and (int(GameState.run["day"]) + GameState.friend_hearts(n.id)) % 2 == 0:
		await say([{"who": name, "text": hl}])
	elif lines.is_empty():
		await say(Talk.line(n.id))
	else:
		await say([{"who": name, "text": str(lines[int(GameState.run["day"]) % lines.size()])}])
	player.frozen = false


## The biggest fully painted window of a floor variant: the 8-variant floors were
## cut at equal widths, so a 2-3 px transparent gutter (with a dark outline) sits
## at a different x in each. Cached per texture.
static var _clean := {}


static func clean_src(t: Texture2D) -> Rect2:
	var key := t.resource_path if t.resource_path != "" else str(t.get_instance_id())
	if _clean.has(key):
		return _clean[key]
	var r := Rect2(Vector2.ZERO, t.get_size())
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var b0 := 0
		var b1 := 0
		var run0 := -1
		for x in w + 1:
			var ok := false
			if x < w:
				var sum := 0.0
				var n := 0
				for y in range(0, h, 2):
					sum += img.get_pixel(x, y).a
					n += 1
				ok = sum / float(n) > 0.9
			if ok and run0 < 0:
				run0 = x
			elif not ok and run0 >= 0:
				if x - run0 > b1 - b0:
					b0 = run0
					b1 = x
				run0 = -1
		if b1 - b0 > 0:
			# One more px off at a gutter side: the painted tiles have a dark rim there.
			var x0 := b0 + (1 if b0 > 0 else 0)
			var x1 := b1 - (1 if b1 < w else 0)
			r = Rect2(x0, 1, maxi(1, x1 - x0), h - 2)
	_clean[key] = r
	return r


var _floor_vars: Array = []


## Mean luminance of a floor tile's clean window (sampled every 3 px).
static func _lum(t: Texture2D) -> float:
	var img := t.get_image()
	if img == null:
		return 0.5
	if img.is_compressed():
		img.decompress()
	var r := clean_src(t)
	var s := 0.0
	var n := 0
	for y in range(int(r.position.y), int(r.end.y), 3):
		for x in range(int(r.position.x), int(r.end.x), 3):
			s += img.get_pixel(x, y).get_luminance()
			n += 1
	return s / maxf(1.0, float(n))


func _floor_cell(fl: String, c: Vector2i) -> void:
	if Art.has("tiles", fl + "_0"):
		if _floor_vars.is_empty():
			# Variants whose clean window is most of the tile (others would stretch too far),
			# kept to those near the middle brightness so the floor doesn't read as a checker.
			var lums := {}
			for i in 8:
				var tv := Art.tex("tiles", fl + "_%d" % i)
				if tv and clean_src(tv).size.x >= tv.get_width() * 0.72:
					_floor_vars.append(i)
					lums[i] = _lum(tv)
			if _floor_vars.size() > 2:
				var ls: Array = lums.values()
				ls.sort()
				var mid: float = ls[ls.size() / 2]
				var near := _floor_vars.filter(func(i: int) -> bool: return absf(float(lums[i]) - mid) <= 0.035)
				if near.size() >= 2:
					_floor_vars = near
			if _floor_vars.is_empty():
				_floor_vars = [0]
		var vi: int = _floor_vars[(c.x * 3 + c.y * 5) % _floor_vars.size()]
		var tt := Art.tex("tiles", fl + "_%d" % vi)
		if tt:
			draw_texture_rect_region(tt, Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), clean_src(tt))
		return
	var t := Art.tex("tiles", fl)
	if t == null:
		return
	if fl.begins_with("fl_carpet"):
		# One bordered rug image: sample only inside its gold border.
		var kc := t.get_width() / 96.0
		draw_texture_rect_region(t, Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), Rect2((22.0 + float(c.x % 2) * 26.0) * kc, (22.0 + float(c.y % 2) * 26.0) * kc, 26.0 * kc, 26.0 * kc))
		return
	# Stay inside the art's clean middle: its outer pixels carry a dark border.
	var k := t.get_width() / 96.0
	var band_h := minf(56.0, t.get_height() * 0.58)
	var sx := (4.0 + float(c.x % 3) * 28.0) * k
	var sy := 3.0 + float(c.y % 2) * (band_h - 30.0)
	draw_texture_rect_region(t, Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), Rect2(sx, sy, 28.0 * k, 26))


## First row of a wall tile that is mostly painted (tall walls like the mill's have a transparent top).
static func first_opaque_row(t: Texture2D) -> int:
	var key := "row:" + t.resource_path
	if _clean.has(key):
		return int(_clean[key])
	var row := 0
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		for y in img.get_height():
			var sum := 0.0
			for x in img.get_width():
				sum += img.get_pixel(x, y).a
			if sum / img.get_width() > 0.5:
				row = y
				break
	_clean[key] = row
	return row


## A sheet gutter inside a wall piece: a fully clear vertical run (3+ px, not at the
## edge) in the lower 70%. Its x range, or ZERO. Cached per texture.
static func wall_gap(t: Texture2D) -> Vector2i:
	var key := "gap:" + t.resource_path
	if _clean.has(key):
		return _clean[key]
	var g := Vector2i.ZERO
	var img := t.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var run := -1
		for x in img.get_width() + 1:
			var clear := x < img.get_width()
			if clear:
				for y in range(int(img.get_height() * 0.3), img.get_height(), 2):
					if img.get_pixel(x, y).a > 0.15:
						clear = false
						break
			if clear and run < 0:
				run = x
			elif not clear and run >= 0:
				if x - run >= 3 and run > 0 and (x < img.get_width() or x - run <= 6):  # (a short trailing strip too: wl_mill_m)
					g = Vector2i(run, x)
					break
				run = -1
	_clean[key] = g
	return g


## Side walls and a front lip so the room is a room, not a floating rug: the
## wall's own top moulding turned into thick rims, darker than the floor.
func _draw_side_walls(wl: String) -> void:
	var trim := Art.tex("tiles", wl + "_m")
	var ty := float(first_opaque_row(trim)) if trim else 0.0
	var d: Array = I.get("door", [cols / 2, rows - 2])
	var rim := Color("3a2a1c")
	var lip := Color(0, 0, 0, 0.28)
	# Sample the moulding beside a sheet gutter, never across it (comb-like lips).
	var sx := 12.0
	var gq := wall_gap(trim) if trim else Vector2i.ZERO
	if gq != Vector2i.ZERO and gq.x < 20 and gq.y > 12:
		sx = 2.0 if gq.x >= 10 else float(gq.y) + 1.0
	for side in [0, cols - 1]:
		var x0 := float(side * TILE) + (TILE - 8.0 if side == 0 else 0.0)
		for y in range(2, rows - 1):  # the last row is the 8 px front lip (its corner squares close it)
			var r := Rect2(x0, y * TILE, 8, TILE)
			if trim:
				# One small square of the moulding (the whole 32x12 squeezed to 8x16 reads as candy stripes).
				draw_texture_rect_region(trim, r, Rect2(sx, 26, 8, 16), Color(0.62, 0.56, 0.5))  # the wall's plain body, in shade
			else:
				draw_rect(r, rim)
	for side in [0, cols - 1]:
		var x0 := float(side * TILE) + (TILE - 8.0 if side == 0 else 0.0)
		for y in range(2, rows - 1):  # the last row is the 8 px front lip (its corner squares close it)
			# A soft shadow the wall throws onto the floor (own pass: it never overlaps a rim).
			draw_rect(Rect2(x0 + (8.0 if side == 0 else -4.0), y * TILE, 4, TILE), lip)
	for x in range(0, cols):
		if x == int(d[0]):
			continue
		var r2 := Rect2(x * TILE, (rows - 1) * TILE, TILE, 8)
		if x == 0:
			r2 = Rect2(TILE - 8, (rows - 1) * TILE, 8, 8)
		elif x == cols - 1:
			r2 = Rect2((cols - 1) * TILE, (rows - 1) * TILE, 8, 8)
		if trim:
			draw_texture_rect_region(trim, r2, Rect2(sx, ty + 2, 8, 8), Color(0.8, 0.75, 0.7))
		else:
			draw_rect(r2, rim)
	# Under the back wall: a shadow line where it meets the floor.
	draw_rect(Rect2(TILE, 2 * TILE, (cols - 2) * TILE, 3), Color(0, 0, 0, 0.22))


func draw_map() -> void:
	var fl := str(I.get("floor", "fl_wood"))
	var wl := str(I.get("wall", "wl_plaster"))
	if Art.has("tiles", fl + "_0") or Art.has("tiles", fl):
		# Cell by cell from the clean part of the floor art (the 3x3 sheets have dark slicing gutters).
		# Grouped by floor variant (each cell covers only itself): cell by cell the
		# variants alternated and every cell was its own draw call, every frame.
		var nv := 1
		if Art.has("tiles", fl + "_0") and rows > 3 and cols > 2:
			_floor_cell(fl, Vector2i(1, 2))  # picks _floor_vars
			nv = maxi(1, _floor_vars.size())
		for k in nv:
			for y in range(2, rows - 1):
				for x in range(1, cols - 1):
					if nv == 1 or (x * 3 + y * 5) % nv == k:
						_floor_cell(fl, Vector2i(x, y))
	else:
		draw_rect(Rect2(TILE, 2 * TILE, (cols - 2) * TILE, (rows - 3) * TILE), Color("a07a4c"))
	for r in I.get("rugs", []):
		draw_tileset_rect(str(r["tile"]), Rect2i(int(r["rect"][0]), int(r["rect"][1]), int(r["rect"][2]), int(r["rect"][3])), Color("b03a2e"))
	var windows := window_cols()
	var night := GameState.is_night()
	var night_glass := night and Art.has("furniture", "window_night")
	var mids: Array = WALL_MIDS.get(wl, ["_m", "_m2", "_m3"])
	mids = mids.filter(func(m: String) -> bool: return Art.has("tiles", wl + m))
	if mids.is_empty():
		mids = ["_m", "_m2", "_m3"]
	var parts := []
	for x in range(1, cols - 1):
		var part: String = "_l" if x == 1 else ("_r" if x == cols - 2 else mids[x % mids.size()])
		if x in windows and Art.has("tiles", wl + "_window"):
			part = "_window"
		elif not Art.has("tiles", wl + part):
			# No end pieces (the mill): use the corner, mirrored on the right; else the plain middle.
			part = "_corner" if part in ["_l", "_r"] and Art.has("tiles", wl + "_corner") else "_m"
		parts.append(part)
		# Backing first, in its own pass (each sits only behind its own panel), so the
		# panels below don't alternate with plain rects.
		var tb := Art.tex("tiles", wl + part)
		if tb and part != "_window" and not (part == "_corner" and x == cols - 2):
			var fy := float(first_opaque_row(tb)) * 2.0 * TILE / float(tb.get_height())
			draw_rect(Rect2(x * TILE, fy, TILE, 2 * TILE - fy), Color(0.16, 0.11, 0.07))
	for x in range(1, cols - 1):
		var part: String = parts[x - 1]
		var t := Art.tex("tiles", wl + part)
		if part == "_window" and not night and Art.has("tiles", wl + "_window_day"):
			t = Art.tex("tiles", wl + "_window_day")  # warm-lit glass painted in: daylight blue by day (c5_04 #9)
		if t and part == "_corner" and x == cols - 2:
			# Mirror with a transform (a negative-width rect lands one cell to the right).
			draw_set_transform(offset() + Vector2((x + 1) * TILE, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(t, Rect2(0, 0, TILE, TILE * 2), false)
			draw_set_transform(offset())
		elif t:
			# (Backing for see-through gaps between panels: drawn in the pass above.)
			var gp := wall_gap(t)
			if gp != Vector2i.ZERO:
				# A slicing gutter inside the piece: skip it and stretch the two halves over the cell.
				var tw := float(t.get_width())
				var lw := TILE * float(gp.x) / (tw - float(gp.y - gp.x))
				draw_texture_rect_region(t, Rect2(x * TILE, 0, lw, TILE * 2), Rect2(0, 0, gp.x, t.get_height()))
				if float(gp.y) < tw:
					draw_texture_rect_region(t, Rect2(x * TILE + lw, 0, TILE - lw, TILE * 2), Rect2(gp.y, 0, tw - gp.y, t.get_height()))
			else:
				draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
			if night_glass and part == "_window":
				Art.draw_prop(self, "furniture", "window_night", Vector2(x * TILE + 8, 2 * TILE - 4))  # dark glass after dark
		else:
			draw_rect(Rect2(x * TILE, 0, TILE, TILE * 2), Color("c9b08a"))
	_draw_side_walls(wl)
	if not Art.has("tiles", wl + "_window"):
		for wx in windows:
			Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(int(wx) * TILE + 8, 2 * TILE))
	for p in I.get("wall_props", []):
		# Fit to the wall (portraits and rubbings are drawn far taller than the 32 px wall).
		var wn := str(p["name"])
		if night and wn.ends_with("_day") and Art.has("furniture", wn.trim_suffix("_day") + "_night"):
			wn = wn.trim_suffix("_day") + "_night"  # stained glass goes dark too
		var wt := Art.tex("furniture", wn)
		if wt == null:
			continue
		var src := art_crop("furniture", wn)
		if not src.has_area():
			src = Rect2(Vector2.ZERO, wt.get_size())
		var ws := minf(0.5, 26.0 / maxf(1.0, src.size.y))
		var sz := src.size * ws
		draw_texture_rect_region(wt, Rect2(int(p["x"]) * TILE + 8 - sz.x / 2.0, 2 * TILE - 3 - sz.y, sz.x, sz.y), src)
	var d: Array = I.get("door", [cols / 2, rows - 2])
	draw_rect(Rect2(int(d[0]) * TILE, int(d[1]) * TILE, TILE, TILE), Color("3a2412"))
	Art.draw_prop(self, "furniture", str(I.get("door_prop", "door_wood_open")), Vector2(int(d[0]) * TILE + 8, (int(d[1]) + 1) * TILE))


func _counter(shop: String) -> void:
	# Shops close for the night (7am to 9pm) and on festival days the town's at the plaza.
	var shut := TownHours.counter_shut(shop)  # same table as the town doors
	if shut != "":
		hud.toast(shut, Color(1, 0.85, 0.7))
		return
	# The keeper is out (Maple at her market stall...): say so, and serve yourself.
	var keeper_out := false
	if shop != "":
		var keeper := ""
		for n in I.get("npcs", []):
			keeper = str(n["id"])
			break
		if keeper != "" and not npcs.any(func(x: Npc) -> bool: return x.id == keeper):
			keeper_out = true  # the till note / "The shop's empty..." line says so (no toast over the list)
	if shop == "hall":
		await Shops.hall(self)
	elif shop in ["smith", "potions"]:
		var d := Dialogue.instance(get_tree())
		var ch: Array = ["Buy", "Craft" if shop == "smith" else "Brew"]
		if shop == "smith":
			ch.append("Upgrade a tool")
		ch.append("Leave")
		d.say([{"who": "" if keeper_out else ("Gideon" if shop == "smith" else "Wren"), "text": "The shop's empty. Buy off the tags, or use the bench?" if keeper_out else "Buying, or making something?", "choice": ch, "key": ""}])
		await d.finished
		if d.last_choice == 0:
			await Shops.run(self, shop, keeper_out)
		elif d.last_choice == 1:
			await Crafting.run(self, "smith" if shop == "smith" else "alchemy", "Gideon's Forge" if shop == "smith" else "Wren's Cauldron", "town")
		elif d.last_choice == 2 and shop == "smith":
			await _upgrade_tools()
	elif shop != "":
		await Shops.run(self, shop, keeper_out)


## Gideon's upgrade bench: every tool climbs wood → copper → iron → steel →
## silver → gold → crystal → moon. Needs bars of the next metal and crystals.
func _upgrade_tools() -> void:
	# A tool left with Gideon comes back the next morning (Sun Haven style).
	var pend: Dictionary = GameState.run.get("jobs", {}).get("smith_upgrade", {})
	if not pend.is_empty():
		if Crafting.now_abs() >= int(pend["done_at"]):
			var k0 := str(pend["kind"])
			GameState.run["jobs"].erase("smith_upgrade")
			GameState.run["flags"]["tool_away_" + k0] = false
			GameState.run["flags"].erase("tool_away_" + k0)
			hud.toast("%s upgraded!" % GameState.item_name(k0), Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("quest_done", "levelup")
			xp("mining", 6)
			if player:
				fx("levelup", player.position + Vector2(0, -12), 12.0, 0.8)
			await say([{"who": "Gideon", "text": "There. Try not to break it before lunch."}])
		else:
			await say([{"who": "Gideon", "text": "Your %s is on the bench. %s. Come back then." % [GameState.item_name(str(pend["kind"])), Crafting.fmt_minutes(int(pend["done_at"]) - Crafting.now_abs())]}])
			return
	while true:
		var opts: Array = []
		var kinds: Array = []
		for k in GameState.TOOL_KINDS:
			if not GameState.has_tool(k) and not (k == "sword" and GameState.has_tool("iron_sword")):
				continue
			var t := GameState.tool_tier(k)
			if t + 1 >= GameState.TOOL_TIERS.size():
				opts.append("%s: moon (max)" % GameState.item_name(k))
			else:
				var need: Dictionary = GameState.upgrade_need(k)
				var parts: Array = []
				for id in need:
					parts.append("%d %s" % [int(need[id]), "◆" if id == "crystals" else GameState.item_name(str(id))])
				opts.append("%s%s → %s  [%s]" % ["" if GameState.can_upgrade_tool(k) else "✗ ", GameState.item_name(k), GameState.TOOL_TIERS[t + 1], ", ".join(parts)])
			kinds.append(k)
		opts.append("Leave")
		var d := Dialogue.instance(get_tree())
		d.say([{"who": "Gideon", "text": "Hand it over. Better metal, same handle.", "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= kinds.size():
			return
		var kind: String = kinds[i]
		if GameState.upgrade_tool(kind):
			# Paid and handed over: the tool is away until tomorrow morning.
			var t := GameState.tool_tier(kind)
			var hours := 6 + 4 * t
			GameState.run["jobs"] = GameState.run.get("jobs", {})
			GameState.run["jobs"]["smith_upgrade"] = {"kind": kind, "done_at": Crafting.now_abs() + hours * 60}
			GameState.run["flags"]["tool_away_" + kind] = true
			hud.toast("Gideon takes the %s. Ready in %dh." % [GameState.item_name(kind), hours], Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("plant")
			return
		else:
			hud.toast("Not enough for that yet.", Color(1, 0.7, 0.7))


## Benno's stable: buy a horse, then ride out from here whenever you like.
func _stable() -> void:
	var d := Dialogue.instance(get_tree())
	if not GameState.run["flags"].has("horse"):
		var price := 1000 if GameState.has_friend_perk("benno", 2) else 2000
		d.say([{"who": "Benno", "text": "Four in the stalls. All steady. ◆%d, saddle included.  (you have ◆%d)" % [price, int(GameState.run["crystals"])], "choice": ["The bay", "The grey", "The black", "The palomino", "Not yet"], "key": ""}])
		await d.finished
		if d.last_choice >= 0 and d.last_choice < 4:
			if int(GameState.run["crystals"]) < price:
				hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
				return
			GameState.run["crystals"] = int(GameState.run["crystals"]) - price
			GameState.run["flags"]["horse"] = true
			GameState.run["names"]["horse"] = "Clover"
			GameState.run["names"]["horse_coat"] = ["bay", "grey", "black", "palomino"][d.last_choice]
			hud.toast("Clover is yours!", Color(1, 0.9, 0.4))
			Music.instance(get_tree()).sfx("quest_done", "levelup")
			GameState.add_friend("benno", 10)
		return
	d.say([{"who": "Benno", "text": "Clover's saddled. Ride out?  (A/C with nothing in front of you dismounts; she waits where you leave her.)", "choice": ["Ride", "Not now"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		player.mount()
		var back: Array = I.get("back", ["town", 32, 93])
		go_to(str(back[0]), Vector2(float(back[1]) * TILE + 8, float(back[2]) * TILE + 4), "down")


## Ivy's bank: deposit crystals for interest (1% a day, 2% at 6 hearts), withdraw any time.
func _bank() -> void:
	var d := Dialogue.instance(get_tree())
	var bal := int(GameState.run.get("bank", 0))
	var rate := 2 if GameState.has_friend_perk("ivy", 6) else 1
	d.say([{"who": "Ivy", "text": "Balance ◆%d, %d%% a day.  You're carrying ◆%d." % [bal, rate, int(GameState.run["crystals"])], "choice": ["Deposit 100", "Deposit all", "Withdraw all", "Leave"], "key": ""}])
	await d.finished
	match d.last_choice:
		0:
			if int(GameState.run["crystals"]) >= 100:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 100
				GameState.run["bank"] = bal + 100
				hud.toast("Deposited ◆100.")
			else:
				hud.toast("Not enough on you.", Color(1, 0.7, 0.7))
		1:
			GameState.run["bank"] = bal + int(GameState.run["crystals"])
			GameState.run["crystals"] = 0
			hud.toast("Deposited everything.")
		2:
			GameState.run["crystals"] = int(GameState.run["crystals"]) + bal
			GameState.run["bank"] = 0
			hud.toast("Withdrew ◆%d." % bal)


## Out the door: back to the map named in "back" (["in_<id>", x, y] is another room,
## e.g. the Rec Center's upstairs comes down its stairs to the ground floor).
func _leave() -> void:
	var back: Array = I.get("back", ["town", 13, 11])
	var to := str(back[0])
	var at := Vector2(float(back[1]) * TILE + 8, float(back[2]) * TILE + 4)
	if to.begins_with("in_"):
		GameMap.next_interior = to.trim_prefix("in_")
		go_to("interior", at, "down")
	else:
		go_to(to, at, "down")


## Walking down onto the doorway takes you outside (no need to press A there).
var _walked_out := false


var _win_props: Array = []   # [Sprite2D, group] window props that swap day/night
var _night_was := -1
var _night_t := 0.0


## Windows (wall glass and window props) follow dusk and dawn while you're inside,
## not only when you walk in (c5_10 #5).
func _watch_night(delta: float) -> void:
	_night_t -= delta
	if _night_t > 0.0:
		return
	_night_t = 1.0
	var n := 1 if GameState.is_night() else 0
	if _night_was == -1:
		_night_was = n
		return
	if n == _night_was:
		return
	_night_was = n
	queue_redraw()
	for wp: Array in _win_props:
		if is_instance_valid(wp[0]) and Art.has(str(wp[1]), "window_night"):
			(wp[0] as Sprite2D).texture = Art.tex(str(wp[1]), "window_night" if n == 1 else "window_day")


## Lamps, candles and hearths glow indoors after dark (c5_04 #3); the Rec Center
## has its own coloured light (RecGlow).
func glow_dark() -> float:
	if RecCenter.is_rec(self):
		return 0.0
	return GameState.darkness() * Settings.night_strength() * 0.8


func _process(delta: float) -> void:
	super(delta)
	_watch_night(delta)
	if _walked_out or player == null or player.frozen or get_tree().paused:
		return
	var d: Array = I.get("door", [cols / 2, rows - 2])
	if player.cell() == Vector2i(int(d[0]), int(d[1])) and Input.is_action_pressed("down"):
		_walked_out = true
		_leave()
