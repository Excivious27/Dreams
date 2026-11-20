class_name Collections
## Collections (CONDUCT 8 P3): museum donations, shipping/fish/cooking/crafting/forage logs,
## milestones and their letters. Data: data/collections.json from tools/gen_collections.py (edit that).
## State: run["coll"] = {donated:{id:day}, shipped:{id:n}, caught:{id:{n, first, night, rain}},
## made:{recipe:n}, claimed:{mid:true}, new:{cat:true}, pending:[mid], today:[item], decor:{id:true}}.
## Co-op: "coll" is not a Net.WORLD_KEYS key, so each player keeps their own logs; only donate() is
## refused while visiting (the museum is the host's world). Cases draw from the local run.

static var _d: Dictionary = {}
static var _sets: Dictionary = {}   # cat -> {key: entry} for the current arc
static var _arc := ""


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/collections.json")
	return _d


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("coll", null) is Dictionary):
		r["coll"] = {}
	var c: Dictionary = r["coll"]
	var fresh := not c.has("made")
	for k in ["donated", "shipped", "caught", "made", "claimed", "new", "decor"]:
		if not (c.get(k, null) is Dictionary):
			c[k] = {}
	for k in ["pending", "today"]:
		if not (c.get(k, null) is Array):
			c[k] = []
	if fresh:
		_backfill(c)
	return c


## Old saves: fish already seen count once, recipes known whose dish was seen count as made once.
## Shipping can't be known: it counts from today on (the page says so).
static func _backfill(c: Dictionary) -> void:
	var seen: Variant = GameState.run.get("seen", {})
	for e: Dictionary in entries("fish"):
		var id := str(e["item"])
		if GameState.has_seen(id):
			c["caught"][id] = {"n": 1, "first": 0}
	var known: Variant = GameState.run.get("known_recipes", [])
	var kn: Array = (known as Dictionary).keys() if known is Dictionary else (known as Array if known is Array else [])
	for cat in ["cooking", "crafting"]:
		for e: Dictionary in entries(cat):
			if kn.has(str(e["recipe"])) and GameState.has_seen(str(e["item"])):
				c["made"][str(e["recipe"])] = 1
	var _unused = seen


static func arc_ok(e: Dictionary) -> bool:
	var a := str(e.get("arc", ""))
	return a == "" or a == str(GameState.run.get("arc", ""))


static func cats() -> Array:
	return data().get("cats", [])


static func cat_title(cat: String) -> String:
	for c: Dictionary in cats():
		if str(c["id"]) == cat:
			return str(c["title"])
	return cat.capitalize()


## Every entry of a page for this arc. Museum entries carry "wing".
static func entries(cat: String, wing := "") -> Array:
	var out := []
	if cat == "museum":
		for w: Dictionary in data().get("wings", []):
			if wing != "" and str(w["id"]) != wing:
				continue
			for e: Dictionary in w["entries"]:
				if arc_ok(e):
					var x := e.duplicate()
					x["wing"] = str(w["id"])
					out.append(x)
		return out
	for e: Dictionary in data().get("logs", {}).get(cat, []):
		if arc_ok(e) and (wing == "" or str(e.get("station", e.get("family", ""))) == wing):
			out.append(e)
	return out


static func _key(cat: String, e: Dictionary) -> String:
	return str(e["recipe"]) if cat in ["cooking", "crafting"] else str(e["item"])


static func _catset(cat: String) -> Dictionary:
	if _arc != str(GameState.run.get("arc", "")):
		_sets = {}
		_arc = str(GameState.run.get("arc", ""))
	if not _sets.has(cat):
		var s := {}
		for e: Dictionary in entries(cat):
			s[_key(cat, e)] = e
		_sets[cat] = s
	return _sets[cat]


static func in_log(cat: String, key: String) -> bool:
	return _catset(cat).has(key)


static func have(cat: String, key: String) -> bool:
	var c := st()
	match cat:
		"museum": return c["donated"].has(key)
		"shipping": return c["shipped"].has(key)
		"fish": return c["caught"].has(key)
		"cooking", "crafting": return c["made"].has(key)
		"forage": return GameState.has_seen(key)
	return false


static func count(cat: String, wing := "") -> int:
	var n := 0
	for e: Dictionary in entries(cat, wing):
		if have(cat, _key(cat, e)):
			n += 1
	return n


static func total(cat: String, wing := "") -> int:
	return entries(cat, wing).size()


static func amount_of(cat: String, key: String) -> int:
	var c := st()
	match cat:
		"shipping": return int(c["shipped"].get(key, 0))
		"fish": return int((c["caught"].get(key, {}) as Dictionary).get("n", 0))
		"cooking", "crafting": return int(c["made"].get(key, 0))
	return 1 if have(cat, key) else 0


static func percent() -> int:
	var got := 0
	var all := 0
	for c: Dictionary in cats():
		got += count(str(c["id"]))
		all += total(str(c["id"]))
	return int(round(100.0 * got / maxf(1.0, all)))


static func _first(cat: String, key: String, quiet: bool, word: String) -> void:
	st()["new"][cat] = true
	if not quiet:
		GameState.notify("%s: first %s! (%d of %d)" % [word, GameState.item_name(key) if cat not in ["cooking", "crafting"] else str(_catset(cat)[key].get("name", key)), count(cat), total(cat)])
	check_milestones()


## A sale (sell box at sleep, Sal's fence, the market stand). True on a first.
static func record_ship(id: String, n := 1, quiet := false) -> bool:
	if not in_log("shipping", id) or n <= 0:
		return false
	var c := st()
	var first: bool = not c["shipped"].has(id)
	c["shipped"][id] = int(c["shipped"].get(id, 0)) + n
	if first:
		_first("shipping", id, quiet, "Shipping log")
	return first


## A fish on the line (GameMap.fish_at). True on a first.
static func record_catch(id: String, n := 1, night := false, rain := false) -> bool:
	if not in_log("fish", id):
		return false
	var c := st()
	var first: bool = not c["caught"].has(id)
	var e: Dictionary = c["caught"].get(id, {"n": 0, "first": int(GameState.run.get("day", 1)), "night": night, "rain": rain})
	e["n"] = int(e.get("n", 0)) + n
	c["caught"][id] = e
	if first:
		_first("fish", id, false, "Fish log")
	return first


## A finished craft (Crafting.collect). Cooking stations go to the Cookbook, the rest to Crafting.
static func record_make(_station: String, rid: String, n := 1) -> bool:
	var cat := "cooking" if in_log("cooking", rid) else ("crafting" if in_log("crafting", rid) else "")
	if cat == "":
		return false
	var c := st()
	var first: bool = not c["made"].has(rid)
	c["made"][rid] = int(c["made"].get(rid, 0)) + n
	if first:
		_first(cat, rid, false, "Cookbook" if cat == "cooking" else "Crafting log")
	return first


## A recipe that belongs to a log and was never made (CraftScreen marks it "new").
static func never_made(rid: String) -> bool:
	return (in_log("cooking", rid) or in_log("crafting", rid)) and not st()["made"].has(rid)


# ---- the museum ------------------------------------------------------------------------

static func museum_open() -> bool:
	return GameState.run.get("flags", {}).has("museum_open")


static func wing_of(id: String) -> String:
	var e: Variant = _catset("museum").get(id, null)
	return str((e as Dictionary)["wing"]) if e is Dictionary else ""


static func wing_title(wing: String) -> String:
	for w: Dictionary in data().get("wings", []):
		if str(w["id"]) == wing:
			return str(w["title"])
	return wing.capitalize()


static func can_donate(id: String) -> String:
	if GameState.visiting():
		return "This is a friend's museum. Your finds count at home."
	if not in_log("museum", id):
		return "The museum doesn't collect that."
	if st()["donated"].has(id):
		return "Already in the cases."
	if GameState.count(id) < 1:
		return "You don't have one."
	return ""


## Takes one from the bag into the cases. Returns "" or the reason it couldn't.
static func donate(id: String) -> String:
	var why := can_donate(id)
	if why != "":
		return why
	GameState.add_item(id, -1)
	var c := st()
	c["donated"][id] = int(GameState.run.get("day", 1))
	c["new"]["museum"] = true
	(c["today"] as Array).append(id)
	check_milestones()
	return ""


static func donatable() -> Array:
	var out := []
	for e: Dictionary in entries("museum"):
		if can_donate(str(e["item"])) == "":
			out.append(str(e["item"]))
	return out


static func room_name() -> String:
	var rn: Dictionary = data().get("room_names", {})
	return str(rn.get("penguins" if GameState.is_penguins() else "gangsters", "Museum"))


static func gang() -> bool:
	return not GameState.is_penguins()


static func letter(key: String) -> String:
	var l: Dictionary = data().get("letters", {})
	return str(l.get(key + "_gangsters", l.get(key, ""))) if gang() else str(l.get(key, ""))


# ---- milestones --------------------------------------------------------------------------

static func _met(m: Dictionary) -> bool:
	var cat := str(m["cat"])
	var need: Variant = m["need"]
	if need is String:
		var s := str(need)
		if s == "all":
			return count(cat) >= total(cat) and total(cat) > 0
		if s.begins_with("wing:"):
			var w := s.trim_prefix("wing:")
			return count(cat, w) >= total(cat, w) and total(cat, w) > 0
		return false
	return count(cat) >= int(need)


## Claims every milestone just reached (once) and queues its letter for the morning post.
static func check_milestones() -> Array:
	var c := st()
	var hits := []
	for m: Dictionary in data().get("milestones", []):
		var mid := str(m["id"])
		if c["claimed"].has(mid) or not _met(m):
			continue
		c["claimed"][mid] = true
		(c["pending"] as Array).append(mid)
		hits.append(mid)
		var g: Dictionary = m.get("give", {})
		if g.has("decor"):
			c["decor"][str(g["decor"])] = true
		if mid == "mus_all":
			GameState.run["flags"]["museum_done_" + ("gang" if gang() else "peng")] = true
		GameState.notify("%s milestone! Expect a letter from %s in the morning." % [cat_title(str(m["cat"])), _npc_name(str(m.get("from", "theo")))])
	return hits


static func milestone(mid: String) -> Dictionary:
	for m: Dictionary in data().get("milestones", []):
		if str(m["id"]) == mid:
			return m
	return {}


## The next milestone in a page: [text, left] or [] when none is left.
static func next_milestone(cat: String) -> Array:
	var c := st()
	for m: Dictionary in data().get("milestones", []):
		if str(m["cat"]) != cat or c["claimed"].has(str(m["id"])):
			continue
		var need: Variant = m["need"]
		var left := (total(cat) - count(cat)) if str(need) == "all" else (int(need) - count(cat) if not (need is String) else -1)
		var who := _npc_name(str(m.get("from", "theo")))
		if left > 0:
			return ["%d more: a gift from %s" % [left, who], left]
		if need is String and str(need).begins_with("wing:"):
			var w := str(need).trim_prefix("wing:")
			return ["Finish %s (%d left): a gift from %s" % [wing_title(w), total(cat, w) - count(cat, w), who], total(cat, w) - count(cat, w)]
	return []


static func _npc_name(id: String) -> String:
	return str(GameState.npcs.get(id, {}).get("name", id.capitalize()))


static func _give_text(g: Dictionary) -> String:
	var bits := []
	if int(g.get("money", 0)) > 0:
		bits.append(Money.amount(int(g["money"])))
	if g.has("decor"):
		bits.append(GameState.item_name(str(g["decor"])) if GameState.items.has(str(g["decor"])) else str(g["decor"]).replace("_", " "))
	return ", ".join(bits)


## Morning post (Mail._morning): the opening letter, yesterday's donation thanks, milestone letters.
static func morning() -> void:
	if GameState.run.is_empty():
		return
	var c := st()
	var flags: Dictionary = GameState.run["flags"]
	if not flags.has("museum_open") and int(GameState.run.get("day", 1)) >= 4:
		for e: Dictionary in entries("museum"):
			if GameState.has_seen(str(e["item"])):
				flags["museum_open"] = true
				Mail.send(_npc_name("theo"), letter("open"), "chat", {"npc": "theo", "coll": "open"})
				break
	var today: Array = c["today"]
	if not today.is_empty():
		var names := []
		for id in today.slice(0, 3):
			names.append(GameState.item_name(str(id)))
		var s := ", ".join(names) + (" and %d more" % (today.size() - 3) if today.size() > 3 else "")
		Mail.send(_npc_name("theo"), letter("thanks") % s, "chat", {"npc": "theo", "coll": "thanks"})
		GameState.add_friend("theo", 3 * mini(today.size(), 5))
		c["today"] = []
	for mid in (c["pending"] as Array):
		var m := milestone(str(mid))
		if m.is_empty():
			continue
		var g: Dictionary = m.get("give", {})
		if int(g.get("money", 0)) > 0:
			GameState.add_money(int(g["money"]), "collection")
		var text := str(m.get("text_gangsters", m["text"])) if gang() else str(m["text"])
		var enc := _give_text(g)
		if enc != "":
			text += "  (Enclosed: %s.)" % enc
		var from := str(m.get("from", "theo"))
		if g.has("item"):
			Mail.send(_npc_name(from), text, "gift", {"npc": from, "item": str(g["item"]), "n": int(g.get("n", 1)), "coll": str(mid)})
		else:
			Mail.send(_npc_name(from), text, "chat", {"npc": from, "coll": str(mid)})
	c["pending"] = []


# ---- conditions, legends, house decor ------------------------------------------------------

## Quest/event conditions: museum_n, museum_wing [wing, n], logged [cat, n], donated (item id).
static func cond_ok(when: Dictionary) -> bool:
	if when.has("museum_n") and count("museum") < int(when["museum_n"]):
		return false
	if when.has("museum_wing"):
		var w: Array = when["museum_wing"]
		if count("museum", str(w[0])) < int(w[1]):
			return false
	if when.has("logged"):
		var l: Array = when["logged"]
		if count(str(l[0])) < int(l[1]):
			return false
	if when.has("donated") and not st()["donated"].has(str(when["donated"])):
		return false
	return true


static func cond_keys(when: Dictionary) -> bool:
	return when.has("museum_n") or when.has("museum_wing") or when.has("logged") or when.has("donated")


## Legends (GameMap.fish_at): once per run, the right place and moment can swap a catch for a
## legend past the value ceiling. Returns the fish to give.
static func legend_roll(scene: String, fish: String, night: bool) -> String:
	if fish == "boot":
		return fish
	for id in data().get("legends", {}):
		var L: Dictionary = data()["legends"][id]
		if str(L.get("scene", "")) != scene or st()["caught"].has(str(id)) or GameState.has_seen(str(id)):
			continue
		if GameState.skill_level("fishing") < int(L.get("lvl", 0)):
			continue
		var w := GameState.weather_today()
		var t := int(GameState.run.get("time", 360))
		var ok := true
		match str(L.get("when", "")):
			"rain_or_winter_dawn": ok = w in ["rain", "storm"] or (GameState.season() == "winter" and t < 9 * 60)
			"night": ok = night
		if ok and randf() < float(L.get("chance", 0.05)):
			return str(id)
	return fish


## Farmhouse decor from milestones (RecCenter.dress_house calls this).
const DECOR_AT := {"museum_trophy": Vector2i(5, 2), "mineral_display": Vector2i(6, 2), "relic_shelf": Vector2i(7, 2),
	"curio_jar": Vector2i(9, 2), "fish_trophy": Vector2i(10, 2), "shipper_ribbon": Vector2i(11, 2)}


static func dress_house(m: GameMap) -> void:
	if GameState.run.is_empty():
		return
	for id in st()["decor"]:
		if DECOR_AT.has(str(id)) and Art.has("props", str(id)):
			m.prop("props", str(id), DECOR_AT[str(id)], 0, 0.0, true, 0.5)


# ---- book helpers --------------------------------------------------------------------------

static func new_count() -> int:
	return (st()["new"] as Dictionary).size()


static func is_new(cat: String) -> bool:
	return st()["new"].has(cat)


static func clear_new(cat: String) -> void:
	st()["new"].erase(cat)


## [title, got, total] rows for the Hero tab.
static func summary_rows() -> Array:
	var out := []
	for c: Dictionary in cats():
		out.append([str(c["title"]), count(str(c["id"])), total(str(c["id"]))])
	return out


## Where to find a missing entry (one line).
static func where(cat: String, key: String) -> String:
	var e: Variant = _catset(cat).get(key, null)
	return str((e as Dictionary).get("where", "")) if e is Dictionary else ""
