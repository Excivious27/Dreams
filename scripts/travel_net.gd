class_name TravelNet
extends RefCounted
## C14 fast-travel network (contract section 1). Travel is earned: you walk first,
## then find or build stations and open links tier by tier (T1 local shortcuts,
## T2 regional lines, T3 world lines, T4 hub-to-hub, T5 instant hops), per arc.
## Data: data/travel.json (tools/gen_travel.py) + data/marina.json["routes"] (P3).
## State: run["travel"] = {unlocked: {link: true}, seen: {link: true}, built: {station: true},
##   rides: {link: n}, arrive: station_id}. Station desks are `mega_gate` things with a
## "station" key (MegaTravel.gate hands them here); props go down in on_enter.
## Co-op: a guest rides on the host's network (no fares, no building) - see ride().

const GROUP := "c14p4"
const SEARCH := 8  # cells round a data cell to find a free spot for a station

static var _d: Dictionary = {}
static var _stations: Dictionary = {}
static var _links: Dictionary = {}
static var skip_scene := false  # tests: no overlay


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/travel.json")
		_stations = {}
		_links = {}
		for s in _d.get("stations", []):
			_stations[str(s["id"])] = s
		for l in _d.get("links", []):
			_links[str(l["id"])] = l
		# P3's marina routes ride on the same network (contract: TravelNet loads them).
		var pairs := {}
		for l: Dictionary in _links.values():
			pairs[str(l["a"]) + ">" + str(l["b"])] = true
		if FileAccess.file_exists("res://data/marina.json"):
			var md := GameState.load_json("res://data/marina.json")
			for s in md.get("stations", []):
				if s is Dictionary and not _stations.has(str(s.get("id", ""))):
					_stations[str(s["id"])] = s
			var lands: Dictionary = md.get("landings", {})
			for l0 in md.get("routes", []):
				if not (l0 is Dictionary) or _links.has(str(l0.get("id", ""))) or pairs.has(str(l0.get("a", "")) + ">" + str(l0.get("b", ""))):
					continue
				var l: Dictionary = (l0 as Dictionary).duplicate(true)
				l["marina"] = true  # unlock/fare through Marina.route_open / route_cost
				var b := str(l.get("b", ""))
				if not _stations.has(b) and lands.get(b) is Array and (lands[b] as Array).size() >= 2:
					# A landing with no station of its own: an arrival-only spot at marina.json "landings".
					var ln: Array = lands[b]
					var lid := "landing_" + b
					_stations[lid] = {"id": lid, "arc": str(l.get("arc", "both")), "scene": str(ln[0]), "cell": ln[1], "spawn": ln[1],
						"kind": str(l.get("kind", "boat")), "name": str(l.get("label", b)), "placed": false}
					l["b"] = lid
				if _stations.has(str(l.get("a", ""))) and _stations.has(str(l.get("b", ""))):
					_links[str(l["id"])] = l
	return _d


static func reload() -> void:
	_d = {}
	data()


static func station(id: String) -> Dictionary:
	data()
	var s: Dictionary = _stations.get(id, {})
	if not s.is_empty() and str(s.get("kind", "")) == "cart" and not GameState.run.is_empty() and not GameState.is_penguins() and str(s.get("name", "")) == "Cart Stop":
		s = s.duplicate()
		s["name"] = str(data().get("kinds", {}).get("cart", {}).get("gang_name", "Freight Trolley Stop"))
	return s


static func link(id: String) -> Dictionary:
	data()
	return _links.get(id, {})


static func all_links() -> Array:
	data()
	return _links.values()


static func st() -> Dictionary:
	var t: Variant = GameState.run.get("travel")
	if not (t is Dictionary):
		t = {}
		GameState.run["travel"] = t
	for k in ["unlocked", "seen", "built", "rides"]:
		if not ((t as Dictionary).get(k) is Dictionary):
			t[k] = {}
	return t


## Save step (GameState._migrate): both C14 blocks exist; links that old saves already
## earned another way open at once (mega keepers' rides, colonies sailed to).
static func migrate() -> void:
	st()
	if not (GameState.run.get("marina") is Dictionary):
		GameState.run["marina"] = {}
	for l: Dictionary in all_links():
		var u: Dictionary = l.get("unlock", {})
		if str(u.get("type", "")) == "flag" and str(u.get("id", "")).begins_with("mega_") and cond_ok(u, l):
			st()["unlocked"][str(l["id"])] = true


static func arc_ok(arc: String) -> bool:
	return arc == "" or arc == "both" or arc == str(GameState.run.get("arc", "penguins"))


static func link_arc_ok(l: Dictionary) -> bool:
	return arc_ok(str(station(str(l.get("a", ""))).get("arc", "both"))) and arc_ok(str(station(str(l.get("b", ""))).get("arc", "both"))) and arc_ok(str(l.get("arc", "both")))


static func stations_at(scene: String) -> Array:
	data()
	var out: Array = []
	for s: Dictionary in _stations.values():
		if str(s.get("scene", "")) == scene and arc_ok(str(s.get("arc", "both"))):
			out.append(s)
	return out


## Links you can take from this station (b -> a too when both_ways).
static func links_from(sid: String) -> Array:
	var out: Array = []
	for l: Dictionary in all_links():
		if not link_arc_ok(l):
			continue
		if str(l["a"]) == sid or (str(l["b"]) == sid and bool(l.get("both_ways", true))):
			out.append(l)
	return out


static func links_at(scene: String) -> Array:
	var out: Array = []
	for s in stations_at(scene):
		for l in links_from(str(s["id"])):
			if not out.has(l):
				out.append(l)
	return out


static func other_end(l: Dictionary, sid: String) -> String:
	return str(l["b"]) if str(l["a"]) == sid else str(l["a"])


static func is_built(sid: String) -> bool:
	return not station(sid).has("build") or st()["built"].has(sid)


## Stations of the link still to build (each end with a "build" cost).
static func to_build(l: Dictionary) -> Array:
	var out: Array = []
	for sid in [str(l.get("a", "")), str(l.get("b", ""))]:
		if not is_built(sid):
			out.append(sid)
	return out


static func cond_ok(c: Dictionary, l: Dictionary = {}, skip_project := false) -> bool:
	var r := GameState.run
	match str(c.get("type", "always")):
		"always", "":
			return true
		"all":
			for sub in c.get("of", []):
				if not cond_ok(sub, l, skip_project):
					return false
			return true
		"quest":
			return GameState.quest_done(str(c.get("id", "")))
		"campaign":
			return Campaign.is_won(str(c.get("id", "")))
		"skill":
			return GameState.skill_level(str(c.get("id", ""))) >= int(c.get("n", 1))
		"perk":
			var p := str(c.get("id", "")).split(":")
			return p.size() == 2 and GameState.has_perk(p[0], p[1])
		"crew_perk":
			return Crew.perk_level(str(c.get("id", ""))) >= int(c.get("n", 1))
		"explore":
			return (r.get("visited", {}) as Dictionary).has(str(c.get("id", "")))
		"flag":
			return (r.get("flags", {}) as Dictionary).has(str(c.get("id", "")))
		"tier":
			return GameState.progress_tier() >= int(c.get("n", 0))
		"project":
			if str(c.get("id", "")) == "marina":
				return skip_project or Marina.tier() >= int(c.get("n", 1))
			return skip_project or to_build(l).is_empty()
		"rides":
			return int(st()["rides"].get(str(l.get("id", "")), 0)) >= int(c.get("n", 5))
	return false


static func is_unlocked(id: String) -> bool:
	var l := link(id)
	if l.is_empty() or not link_arc_ok(l):
		return false
	if bool(l.get("marina", false)):  # P3's boat passages open with the marina tiers
		return Marina.route_open(l)
	if st()["unlocked"].has(id):
		return to_build(l).is_empty()
	if cond_ok(l.get("unlock", {}), l):
		st()["unlocked"][id] = true
		return true
	return false


## Shows at the desk / on the map: everything but building is done (a build site),
## or it is open.
static func is_known(id: String) -> bool:
	var l := link(id)
	return not l.is_empty() and link_arc_ok(l) and (st()["unlocked"].has(id) or cond_ok(l.get("unlock", {}), l, true))


static func is_free(id: String) -> bool:
	var l := link(id)
	if bool(l.get("marina", false)):
		return Marina.route_cost(l) <= 0
	var c: Dictionary = l.get("cost", {})
	if int(c.get("money", 0)) <= 0 and (c.get("items", {}) as Dictionary).is_empty():
		return true
	if not (l.get("free_after", {}) is Dictionary):
		return false
	var fa: Dictionary = l.get("free_after", {})
	return not fa.is_empty() and cond_ok(fa, l)


static func fare_words(id: String) -> String:
	if is_free(id) or Net.visiting():
		return "free"
	var c: Dictionary = link(id).get("cost", {})
	var parts: Array = []
	if int(c.get("money", 0)) > 0:
		parts.append(Money.amount(int(c["money"])))
	for it: String in c.get("items", {}):
		parts.append(ItemWords.count_id(it, int(c["items"][it])))
	return ", ".join(parts)


static func _can_pay(c: Dictionary) -> bool:
	if int(GameState.run.get("crystals", 0)) < int(c.get("money", 0)):
		return false
	for it: String in c.get("items", {}):
		if GameState.count(it) < int(c["items"][it]):
			return false
	return true


static func _pay(c: Dictionary, source: String) -> void:
	if int(c.get("money", 0)) > 0:
		GameState.add_money(-int(c["money"]), source)
	for it: String in c.get("items", {}):
		GameState.add_item(it, -int(c["items"][it]))


static func dest_scene(id: String, from_sid := "") -> String:
	var l := link(id)
	var to := other_end(l, from_sid) if from_sid != "" else str(l.get("b", ""))
	return str(station(to).get("scene", ""))


static func can_ride(id: String) -> bool:
	return why_not(id) == ""


## Why this link can't be ridden yet, in all-ages words ("" = it can).
static func why_not(id: String, from_sid := "") -> String:
	var l := link(id)
	if l.is_empty():
		return "That line doesn't run."
	if not link_arc_ok(l):
		return "That line isn't for your crowd." if not GameState.is_penguins() else "That line doesn't run for you."
	var tb := to_build(l)
	if not tb.is_empty():
		return "Build the %s first." % str(station(str(tb[0])).get("name", "station"))
	if not is_unlocked(id):
		if bool(l.get("marina", false)):
			var mw := Marina.route_why(l)
			return ("That passage %s." % mw) if mw != "" else "Not open yet."
		return unlock_words(l.get("unlock", {}), l)
	var dest := dest_scene(id, from_sid)
	if dest != "" and not Campaign.region_open(dest):
		return Campaign.VISIT_GATE if Net.visiting() else "That way is still held. Win its campaign first."
	if not is_free(id) and not Net.visiting() and not _can_pay(l.get("cost", {})):
		return "The fare is %s." % fare_words(id)
	return ""


static func unlock_words(c: Dictionary, l: Dictionary) -> String:
	match str(c.get("type", "")):
		"all":
			for sub in c.get("of", []):
				if not cond_ok(sub, l):
					return unlock_words(sub, l)
		"quest":
			var d := GameState._quest_def(str(c.get("id", "")))
			return "Opens after a job: %s" % str(d.get("title", d.get("text", "a quest"))) if not d.is_empty() else "Opens later in your story."
		"campaign":
			return "Opens when that region's campaign is won."
		"skill":
			return "Opens at %s level %d." % [str(c.get("id", "")).capitalize(), int(c.get("n", 1))]
		"perk", "crew_perk":
			return "Opens with a crew or skill perk."
		"explore":
			return "Find %s on foot first." % PlaceNames.for_id(str(c.get("id", "")))
		"flag":
			return "Opens when the keeper's ride is open." if str(c.get("id", "")).begins_with("mega_") else "Not open yet."
		"tier":
			return "Opens further along in your story."
		"project":
			return "Build both ends first."
	return "Not open yet."


static func unlock(id: String, source := "") -> void:
	if link(id).is_empty():
		return
	st()["unlocked"][id] = true
	if source != "":
		st()["rides"]["_src_" + id] = source


static func can_build(sid: String) -> bool:
	var s := station(sid)
	return s.has("build") and not st()["built"].has(sid) and not Net.visiting() and _can_pay(s["build"])


static func build(sid: String) -> bool:
	var s := station(sid)
	if s.is_empty() or st()["built"].has(sid):
		return false
	if s.has("build"):
		if not can_build(sid):
			return false
		_pay(s["build"], "travel_build")
	st()["built"][sid] = true
	return true


static func build_words(sid: String) -> String:
	var c: Dictionary = station(sid).get("build", {})
	var parts: Array = []
	if int(c.get("money", 0)) > 0:
		parts.append(Money.amount(int(c["money"])))
	for it: String in c.get("items", {}):
		parts.append(ItemWords.count_id(it, int(c["items"][it])))
	return ", ".join(parts)


static func _cur_map() -> GameMap:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).current_scene is GameMap:
		return (ml as SceneTree).current_scene as GameMap
	return null


## Arrival cell at a station (its spawn, else the cell below it).
static func arrive_cell(sid: String) -> Vector2i:
	var s := station(sid)
	var sp: Array = s.get("spawn", [])
	if sp.size() == 2:
		return Vector2i(int(sp[0]), int(sp[1]))
	var c: Array = s.get("cell", [10, 10])
	return Vector2i(int(c[0]), int(c[1]) + 1)


## Take the link: pay, pass game time, the ride scene (skippable once seen), then go.
static func ride(link_id: String, m: GameMap = null, from_sid := "") -> bool:
	if m == null:
		m = _cur_map()
	var l := link(link_id)
	if l.is_empty() or why_not(link_id, from_sid) != "":
		return false
	if from_sid == "":
		from_sid = str(l["a"])
		if m != null and str(station(from_sid).get("scene", "")) != m.scene_id() and str(station(str(l["b"])).get("scene", "")) == m.scene_id():
			from_sid = str(l["b"])
	var to := other_end(l, from_sid)
	if not is_free(link_id) and not Net.visiting():
		_pay(l.get("cost", {}), "travel")
		st()["rides"][link_id] = int(st()["rides"].get(link_id, 0)) + 1
	var mins := int(l.get("minutes", 0))
	if mins > 0 and GameState.run.has("time"):
		GameState.run["time"] = mini(int(GameState.run["time"]) + mins, GameState.DAY_END - 30) if int(GameState.run["time"]) < GameState.DAY_END - 30 else int(GameState.run["time"])
	var first: bool = not st()["seen"].has(link_id)
	st()["seen"][link_id] = true
	st()["arrive"] = to
	if m == null:
		return true
	var k := str(l.get("kind", ""))
	var snd := str(data().get("kinds", {}).get(k, {}).get("sfx", "door"))
	var mu := Music.instance(m.get_tree())
	mu.sfx(snd if mu.has_sfx(snd) else "door", "door")
	if not skip_scene and str(data().get("kinds", {}).get(k, {}).get("veh", "")) != "":
		var ts := TravelScene.play(m, l, from_sid, first)
		await ts.finished
	var dest := str(station(to).get("scene", ""))
	var c := arrive_cell(to)
	var pos := Vector2((float(c.x) + 0.5) * GameMap.TILE, (float(c.y) + 0.5) * GameMap.TILE)
	if dest == m.scene_id():
		m.player.position = pos
		st().erase("arrive")
		return true
	m.go_to(dest, pos, "down", true)
	return true


## A free spot near the station's data cell (path, not a wall, not another thing).
static func _spot(m: GameMap, c: Vector2i) -> Vector2i:
	for r in range(0, SEARCH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if n.x < 1 or n.y < 1 or n.x >= m.cols - 1 or n.y >= m.rows - 1:
					continue
				var dn := n + Vector2i(0, 1)
				if m.blocked.has(n) or m.things.has(n) or m._exit_at(n) or m.blocked.has(dn) or m.things.has(dn) or _near_gate(m, n):
					continue
				return n
	return Vector2i(-1, -1)


## A keeper's vehicle or another station next door (their keeper stands beside them).
static func _near_gate(m: GameMap, n: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-2, 3):
			var k := n + Vector2i(dx, dy)
			if m.things.has(k) and str(m.things[k].get("type", "")) == "mega_gate":
				return true
	return false


static var placed: Dictionary = {}  # "scene:sid" -> Vector2i (this visit)


## The station's prop (and its desk thing) on map `m`. Contract API: maps may call it
## from their own code; on_enter calls it for every station this map has.
static func station_prop(m: GameMap, sid: String) -> void:
	var s := station(sid)
	if s.is_empty() or m == null:
		return
	var key := m.scene_id() + ":" + sid
	if placed.has(key) and m.things.has(placed[key]) and str(m.things[placed[key]].get("station", "")) == sid:
		return
	var cell: Array = s.get("cell", [10, 10])
	var own := _own_desk(m, sid, Vector2i(int(cell[0]), int(cell[1])))
	if own.x >= 0:
		# The map already has its own desk thing for this station (beach marina, ferry tip):
		# draw the station's sign beside it and keep that desk (no second desk).
		placed[key] = own
		var pn0 := str(s.get("prop", ""))
		if pn0 != "" and Art.has(GROUP, pn0):
			m.prop(GROUP, pn0, own, 0, 0.0, false, 0.5)
		return
	var c := _spot(m, Vector2i(int(cell[0]), int(cell[1])))
	if c.x < 0:
		return
	placed[key] = c
	var pn := str(s.get("prop", ""))
	if not GameState.is_penguins() and str(s.get("kind", "")) == "cart":
		pn = "c14p4_trolley_stop"  # the gangster arc's freight trolley line (c14_12-16)
	if pn != "" and Art.has(GROUP, pn):
		var sp := m.prop(GROUP, pn, c, 0, 0.0, false, 0.5)
		if sp and not is_built(sid):
			sp.modulate = Color(0.72, 0.7, 0.66, 1.0)  # a build site: weathered/dim until built (solid, never see-through)
	var hint := "A: " + (str(s.get("name", "travel")) if is_built(sid) else "build " + str(s.get("name", "station")))
	m.set_thing(c.x, c.y, {"type": "mega_gate", "station": sid, "hint": hint}, false)  # walk-on: a station never blocks a path


## A thing the map placed itself for station `sid` near its data cell, else (-1, -1).
static func _own_desk(m: GameMap, sid: String, near: Vector2i) -> Vector2i:
	for dy in range(-SEARCH, SEARCH + 1):
		for dx in range(-SEARCH, SEARCH + 1):
			var k := near + Vector2i(dx, dy)
			var t = m.things.get(k)
			if t is Dictionary and str(t.get("station", "")) == sid and str(t.get("type", "")) != "mega_gate":
				return k
	return Vector2i(-1, -1)


## Which stations show on this visit: built ones, and build sites/finds whose links
## are otherwise open (nothing shows for a line you couldn't start yet).
static func shows(sid: String) -> bool:
	var s := station(sid)
	if s.is_empty() or not arc_ok(str(s.get("arc", "both"))) or not bool(s.get("placed", true)):
		return false
	for l in links_from(sid):
		if is_known(str(l["id"])):
			return true
	return false


## GameMap._ready (through MegaTravel.on_enter): station props + desks, then the
## arrival spot beside the station you rode to.
static func on_enter(m: GameMap) -> void:
	if GameState.run.is_empty() or data().is_empty():
		return
	var sid := m.scene_id()
	for s in stations_at(sid):
		if shows(str(s["id"])):
			station_prop(m, str(s["id"]))
	var arr := str(st().get("arrive", ""))
	if arr != "" and str(station(arr).get("scene", "")) == sid:
		st().erase("arrive")
		var key := sid + ":" + arr
		if placed.has(key) and not station(arr).has("spawn") and m.player != null and is_instance_valid(m.player):
			var c: Vector2i = placed[key] + Vector2i(0, 1)
			if not m.blocked.has(c) and not m.things.has(c):
				m.player.position = m.cell_center(c)


## The ride list at a station (contract API), the way out last.
static func desk(m: GameMap, sid: String) -> void:
	var s := station(sid)
	if s.is_empty():
		return
	var who := str(s.get("keeper", ""))
	if who == "":
		who = str(s.get("name", "Station"))
	if not is_built(sid):
		if Net.visiting():
			await m.say([{"who": who, "text": "Only the farm's owner can build this."}])
			return
		var dlg0 := Dialogue.instance(m.get_tree())
		dlg0.say([{"who": who, "text": "A %s could stand here. It needs %s." % [str(s.get("name", "station")), build_words(sid)], "choice": ["Build it", "Not now"], "key": ""}])
		await dlg0.finished
		if dlg0.last_choice != 0:
			return
		if not build(sid):
			Music.instance(m.get_tree()).sfx("nope", "thud")
			m.hud.toast("Not enough yet: %s." % build_words(sid), Color(1, 0.85, 0.6))
			return
		Music.instance(m.get_tree()).sfx("unlock", "j_region")
		m.hud.toast("%s built." % str(s.get("name", "Station")), Color(0.8, 1, 0.8))
		var key := m.scene_id() + ":" + sid
		if placed.has(key) and m.props.has(placed[key]):
			(m.props[placed[key]] as CanvasItem).modulate = Color.WHITE
		if m.things.has(placed.get(key, Vector2i(-1, -1))):
			m.things[placed[key]]["hint"] = "A: " + str(s.get("name", "travel"))
	var ls: Array = []
	var opts: Array = []
	for l in links_from(sid):
		var lid := str(l["id"])
		if not is_known(lid):
			continue
		var to := other_end(l, sid)
		var nm := PlaceNames.for_id(str(station(to).get("scene", "")))
		if str(station(to).get("kind", "")) == "mega":
			nm = str(station(to).get("name", nm)).trim_suffix(" ride")
		var w := why_not(lid, sid)
		opts.append("To %s (%s)" % [nm, fare_words(lid) if w == "" else "shut"])
		ls.append(lid)
	if ls.is_empty():
		await m.say([{"who": who, "text": "No line runs from here yet."}])
		return
	opts.append("Not now")
	var dlg := Dialogue.instance(m.get_tree())
	dlg.say([{"who": who, "text": "Where to?", "choice": opts, "key": ""}])
	await dlg.finished
	var i := dlg.last_choice
	if i < 0 or i >= ls.size():
		return
	var why := why_not(str(ls[i]), sid)
	if why != "":
		Music.instance(m.get_tree()).sfx("locked", "nope")
		m.hud.toast(why, Color(1, 0.85, 0.6))
		return
	await ride(str(ls[i]), m, sid)


## The Hot-Air Balloon / charter plane item (c14_05-01): it flies only from a built
## Balloon Mast (penguins) or Charter Pad (gangsters) to another built one.
static func balloon(m: GameMap) -> void:
	var here := ""
	for s in stations_at(m.scene_id()):
		if str(s.get("kind", "")) in ["mast", "plane"] and str(s["id"]).begins_with("mast_" if GameState.is_penguins() else "pad_") and is_built(str(s["id"])):
			if placed.has(m.scene_id() + ":" + str(s["id"])) and m.player.position.distance_to(m.cell_center(placed[m.scene_id() + ":" + str(s["id"])])) < 64.0:
				here = str(s["id"])
	if here == "":
		var what := "Balloon Mast" if GameState.is_penguins() else "Charter Pad"
		m.hud.toast("It only flies from a %s you've built. Stand beside one." % what, Color(1, 0.85, 0.6))
		return
	await desk(m, here)


## Menu > Map, the Valley painting: built stations (bright) and found build sites
## (grey), with the open lines drawn along their paths. Hook in GameMenu._draw_map.
static func map_layer(m: Control, font: Font, pins: Dictionary, org: Vector2, sz: Vector2) -> void:
	if GameState.run.is_empty() or data().is_empty():
		return
	var pos: Dictionary = data().get("pos", {})
	var drawn := {}
	for l: Dictionary in all_links():
		var lid := str(l["id"])
		if not is_known(lid) or str(l.get("kind", "")) == "mega":
			continue
		var pts: Array = l.get("path", [])
		if pts.size() < 2:
			continue
		var open := is_unlocked(lid)
		var col := Color(0.95, 0.85, 0.35, 0.9) if open else Color(0.6, 0.6, 0.6, 0.6)
		for j in pts.size() - 1:
			var p0: Vector2 = org + Vector2(float(pts[j][0]), float(pts[j][1])) * sz
			var p1: Vector2 = org + Vector2(float(pts[j + 1][0]), float(pts[j + 1][1])) * sz
			m.draw_dashed_line(p0, p1, col, 1.0, 3.0)
		for sid in [str(l["a"]), str(l["b"])]:
			var sc := str(station(sid).get("scene", ""))
			if drawn.has(sc) or not (pins.has(sc) or pos.has(sc)):
				continue
			drawn[sc] = true
			var pp: Vector2 = pins.get(sc, Vector2(float(pos[sc][0]), float(pos[sc][1]))) if pins.has(sc) else Vector2(float(pos[sc][0]), float(pos[sc][1]))
			var p: Vector2 = org + pp * sz + Vector2(-9, -14)
			m.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.12, 0.08, 0.05))
			m.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.4, 0.85, 1.0) if open and is_built(sid) else Color(0.55, 0.55, 0.55))


## A region map tab (MegaMap.draw_region hook): a small station badge beside every
## area pin with a station you know of (blue = built and running, grey = not yet).
static func region_layer(m: Control, pins: Dictionary) -> void:
	if GameState.run.is_empty() or data().is_empty():
		return
	for aid: String in pins:
		var known := false
		var open := false
		for s in stations_at(aid):
			for l in links_from(str(s["id"])):
				if is_known(str(l["id"])):
					known = true
					if is_unlocked(str(l["id"])):
						open = true
		if not known:
			continue
		var p: Vector2 = (pins[aid] as Vector2) + Vector2(-10, -12)
		m.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.12, 0.08, 0.05))
		m.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.4, 0.85, 1.0) if open else Color(0.55, 0.55, 0.55))


## How many stations/lines of the arc are open (Map tab line, reports).
static func counts() -> Dictionary:
	var n_open := 0
	var n_all := 0
	for l: Dictionary in all_links():
		if not link_arc_ok(l):
			continue
		n_all += 1
		if is_unlocked(str(l["id"])):
			n_open += 1
	return {"open": n_open, "all": n_all}
