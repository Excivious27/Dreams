class_name Builds
## Farm buildings (data/buildings.json): tiers, permits, timed construction.
##   run["builds"][id]       = tier built (int); legacy saves store `true` = tier 1
##   run["permits"][id]      = highest tier permitted
##   run["construction"][id] = {"tier": n, "done_day": d}   (Hazel's crew, overnight)

static var _data: Dictionary = {}
static var _by_arc: Dictionary = {}
## Story gates in words a player can act on (gate() falls back to "story first").
const STORY_WORDS := {
	"clear_meadow": "after the east meadow story",
	"meow_taught": "story chapter 2 first (Catkins)",
	"babies_done": "story chapter 3 first (the crystal babies)",
	"merkitty_done": "story chapter 4 first (the Merkitties)",
}


## Every building and station in the file, whatever the arc.
static func all() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/buildings.json")
		_data.erase("_")
	return _data


## What this run can build: the shared ones plus its own arc's.
static func data() -> Dictionary:
	var arc := str(GameState.run.get("arc", ""))
	if not _by_arc.has(arc):
		var out := {}
		for id in all():
			var a := str(all()[id].get("arc", ""))
			if a == "" or a == arc:
				out[id] = all()[id]
		_by_arc[arc] = out
	return _by_arc[arc]


## Ready-made price of the next tier (0 = can't be bought).
static func price(id: String) -> int:
	return int(next_def(id).get("price", 0))


## The gates on the next tier, apart from materials ("" = open).
static func gate(id: String) -> String:
	var nd := next_def(id)
	if nd.is_empty():
		return "max"
	if not under_construction(id).is_empty():
		return "building"
	if built_tier(id) == 0:
		var bl := GameState.blueprint_lock(id)
		if bl != "":
			return bl
	var ul: Dictionary = nd.get("unlock", {})
	# Any tier may need a skill-tree blueprint (c11a_02_11): unlock.blueprint = a blueprint id from
	# gen_skill_trees UNLOCKS (e.g. "coop_3"); every unlock kind is checked in turn.
	if ul.has("blueprint"):
		var tbl := GameState.blueprint_lock(str(ul["blueprint"]))
		if tbl != "":
			return tbl
	if ul.has("year") and Calendar.year() < int(ul["year"]):
		return "opens in year %d" % int(ul["year"])  # C16a P1 hook: year-2/3 builds
	if ul.has("day") and int(GameState.run["day"]) < int(ul["day"]):
		var d := int(ul["day"])  # C16a P1 hook: a calendar floor ("from Fall 1")
		return "from %s %d" % [Calendar.season_of(d).capitalize(), Calendar.dos_of(d)]
	if ul.has("progress") and GameState.progress_tier() < int(ul["progress"]):
		return "story chapter %d first" % (int(ul["progress"]) + 1)
	if ul.has("year") and GameState.year() < int(ul["year"]):  # C16a P5 (c16a_10-02): top tiers wait for year 2
		return "opens in year %d" % int(ul["year"])
	if ul.has("skill") and GameState.skill_level(str(ul["skill"][0])) < int(ul["skill"][1]):
		return "%s level %d" % [str(ul["skill"][0]).capitalize(), int(ul["skill"][1])]
	if ul.has("flag") and not GameState.run["flags"].has(str(ul["flag"])):
		return str(ul.get("hint", STORY_WORDS.get(str(ul["flag"]), "story first")))
	if ul.has("quest") and not GameState.quest_done(str(ul["quest"])):
		return str(ul.get("hint", STORY_WORDS.get(str(ul["quest"]), "story first")))
	if ul.has("friend") and GameState.friend_hearts(str(ul["friend"][0])) < int(ul["friend"][1]):
		return "%s ♥%d" % [str(GameState.npcs[str(ul["friend"][0])]["name"]), int(ul["friend"][1])]
	if int(nd.get("permit", 0)) > 0 and permitted(id) < int(nd["tier"]):
		return "permit"
	return ""


static func built_tier(id: String) -> int:
	var v: Variant = GameState.run.get("builds", {}).get(id, 0)
	if v is bool:
		v = 1 if v else 0
	if id == "house":
		return maxi(1, int(v))   # you start in the Cottage
	return int(v)


static func is_built(id: String) -> bool:
	return built_tier(id) > 0


static func tier_def(id: String, tier: int) -> Dictionary:
	for t in all().get(id, {}).get("tiers", []):  # any arc: a co-op host can own the other story's builds
		if int(t["tier"]) == tier:
			return _arc_words(t)
	return {}


## C11b P6 (c11b_05-09): ranch buildings in the gangster arc's own words. The tier's name_gang (from
## gen_stations RANCH) wins when it differs; else GANG_NAMES; the penguin arc keeps the storybook names.
const GANG_NAMES := {
	"Coop": "Roost", "Big Coop": "Big Roost", "Deluxe Coop": "Rooftop Roost",
	"Barn": "Stock Shed", "Big Barn": "Big Stock Shed", "Deluxe Barn": "Stock Warehouse", "Grand Barn": "Lab Barn",
	"Rabbit Hutch": "Bunny Crates", "Big Hutch": "Bunny Stack",
	"Pig Sty": "Pig Pen", "Big Sty": "Big Pig Pen",
	"Beehive": "Rooftop Hive", "Bee House": "Hive Rack", "Apiary": "Hive Wall",
	"Exotic Enclosure": "Exotics Yard", "Enclosure": "Exotics Yard", "Grand Enclosure": "Big Exotics Yard",
}


static func _gang() -> bool:
	return not GameState.run.is_empty() and str(GameState.run.get("arc", "")) == "gangsters"


static func _arc_words(t: Dictionary) -> Dictionary:
	if not _gang():
		return t
	var nm := str(t.get("name", ""))
	var g := str(t.get("name_gang", ""))
	var want := g if g != "" and g != nm else str(GANG_NAMES.get(nm, nm))
	# The gangster look of the building (buildings/<sprite>_gang: corrugated metal, chain-link, neon).
	var gs := str(t.get("sprite", "")) + "_gang"
	var look := str(t.get("group", "")) == "buildings" and Art.has("buildings", gs)
	if want == nm and not look:
		return t
	var out := t.duplicate()
	out["name"] = want
	if look:
		out["sprite"] = gs
	return out


## A building's label in this arc's words ("Coop" / "Roost").
static func label(id: String) -> String:
	var bd: Dictionary = all().get(id, {})
	var nm := str(bd.get("label", id.capitalize()))
	if not _gang():
		return nm
	var g := str(bd.get("label_gang", ""))
	return g if g != "" else str(GANG_NAMES.get(nm, nm))


## Who builds or sells it in this arc (gangster arc: seller_gang, "The crew").
static func seller(id: String) -> String:
	var bd: Dictionary = all().get(id, {})
	if _gang() and str(bd.get("seller_gang", "")) != "":
		return str(bd["seller_gang"])
	return str(bd.get("seller", "Hazel"))


## C11b P6 (c11b_05-04): the map footprint of a building at a tier (default: the built tier, or tier 1).
## A tier row may carry its own cell/w/h (a Grand Barn grows); else the building's. Rect2i(cell, Vector2i(w, h)).
static func footprint(id: String, tier := -1) -> Rect2i:
	var bd: Dictionary = all().get(id, {})
	var t := tier if tier >= 0 else maxi(1, built_tier(id))
	var td := {}
	for row in bd.get("tiers", []):
		if int(row["tier"]) == t:
			td = row
	var c: Array = td.get("cell", bd.get("cell", [0, 0]))
	return Rect2i(int(c[0]), int(c[1]), int(td.get("w", bd.get("w", 0))), int(td.get("h", bd.get("h", 1))))


static func current_def(id: String) -> Dictionary:
	return tier_def(id, built_tier(id))


static func next_def(id: String) -> Dictionary:
	return tier_def(id, built_tier(id) + 1)


static func permitted(id: String) -> int:
	return int(GameState.run.get("permits", {}).get(id, 0))


static func under_construction(id: String) -> Dictionary:
	return GameState.run.get("construction", {}).get(id, {})


## How many of an item in the bag a build may use (locked items are kept).
static func _bag_free(id: String) -> int:
	return 0 if GameState.is_locked(id) else GameState.count(id)


## Why the next tier can't start ("" = it can, "permit" = needs a permit).
static func blocker(id: String) -> String:
	var nd := next_def(id)
	var g := gate(id)
	if g != "":
		return g
	var cst := cost_of(nd)
	for need in cst:
		# Materials in your chests count too (Sun Haven builds from storage).
		if _bag_free(str(need)) + Storage.total(str(need)) < int(cst[need]):
			return "need %d %s" % [int(cst[need]), GameState.item_name(str(need))]
	return ""


## Start construction (or finish instantly when days == 0). Returns a toast.
static func start(id: String, buy := false) -> String:
	var why := gate(id) if buy else blocker(id)
	if why != "":
		return "Can't build yet: %s." % why
	var nd := next_def(id)
	if buy:
		# Bought ready-made: crystals instead of materials, same gates.
		var p := price(id)
		if p <= 0:
			return "Can't build yet: nobody sells that."
		if int(GameState.run["crystals"]) < p:
			return "Can't build yet: it costs ◆%d (you have ◆%d)." % [p, int(GameState.run["crystals"])]
		GameState.run["crystals"] = int(GameState.run["crystals"]) - p
	else:
		var cst := cost_of(nd)
		for need in cst:
			# Bag first (locked items stay put), then the chests.
			var need_n := int(cst[need])
			var from_bag := mini(need_n, _bag_free(str(need)))
			var got := Storage.take_from_chests(str(need), need_n - from_bag)
			GameState.add_item(str(need), -mini(need_n - got, GameState.count(str(need))))
	var days := int(nd.get("days", 0))
	# Quick Build (Building): Hazel's crew is a day faster; a 1-day job is done on the spot.
	if days > 0:
		days = maxi(0, days - int(GameState.bonus("building", "quick_build")))
	if days <= 0:
		_finish(id, int(nd["tier"]))
		return "Built the %s." % str(nd["name"])
	GameState.run["construction"] = GameState.run.get("construction", {})
	GameState.run["construction"][id] = {"tier": int(nd["tier"]), "done_day": int(GameState.run["day"]) + days}
	return "%s starts on the %s. %d day%s." % ["The crew" if _gang() else "Hazel's crew", str(nd["name"]), days, "" if days == 1 else "s"]


static func _finish(id: String, tier: int) -> void:
	GameState.run["builds"] = GameState.run.get("builds", {})
	GameState.run["builds"][id] = tier
	GameState.add_xp("building", 10 + 10 * tier)
	var nd := tier_def(id, tier)
	# House perks.
	if id == "house":
		if tier >= 2:
			GameState.grow_vital("energy", 10)
		if tier >= 3:
			GameState.grow_vital("hp", 5)
			var s: Dictionary = GameState.run["skills"].get("building", {"level": 1, "xp": 0, "nodes": {}})
			s["level"] = int(s["level"]) + 1
			GameState.run["skills"]["building"] = s
	if id == "shrine":
		GameState.grow_vital("mana", 5 if tier == 1 else (0 if tier == 2 else 15))
	if id == "training":
		GameState.grow_vital("hp", 10 if tier == 1 else (0 if tier == 2 else 20))
	GameState.add_hint("%s finished: %s" % [str(nd.get("name", id)), str(nd.get("desc", ""))])


## Called from sleep(): finish anything whose day has come. Returns names done.
static func tick_overnight() -> Array:
	var done: Array = []
	var c: Dictionary = GameState.run.get("construction", {})
	for id in c.keys():
		if int(GameState.run["day"]) >= int(c[id]["done_day"]):
			_finish(str(id), int(c[id]["tier"]))
			done.append(str(tier_def(str(id), int(c[id]["tier"])).get("name", id)))
			c.erase(id)
	return done


## Buy a permit at the Town Hall.
static func buy_permit(id: String) -> String:
	var nd := next_def(id)
	if nd.is_empty():
		return "Nothing more to permit for that."
	var price := int(nd.get("permit", 0))
	if GameState.has_friend_perk("alder", 4):
		price = int(price * 0.8)
	if price <= 0:
		return "No permit needed."
	if permitted(id) >= int(nd["tier"]):
		return "You already hold that permit."
	if Net.visiting() and not Net.online():
		return "Reconnecting to your host... try again in a moment."
	if int(GameState.run["crystals"]) < price:
		return "A %s permit is ◆%d. You have ◆%d." % [str(nd["name"]), price, int(GameState.run["crystals"])]
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	GameState.run["permits"] = GameState.run.get("permits", {})
	GameState.run["permits"][id] = int(nd["tier"])
	if Net.online() and not Net.is_host():
		var m := Engine.get_main_loop() as SceneTree
		if m and m.current_scene is GameMap:
			(m.current_scene as GameMap).net_act({"a": "permit", "id": id, "tier": int(nd["tier"])})
	return "Permit stamped: %s (◆%d)." % [str(nd["name"]), price]


static func permit_price(id: String) -> int:
	var nd := next_def(id)
	var price := int(nd.get("permit", 0))
	if GameState.has_friend_perk("alder", 4):
		price = int(price * 0.8)
	return price


## A tier's material cost after the Building perks (Carpenter, Mason, Master Builder).
static func cost_of(nd: Dictionary) -> Dictionary:
	var out := {}
	var all_off := GameState.bonus("building", "build_discount")
	for k in nd.get("cost", {}):
		var off := all_off
		if str(k) in ["wood", "plank", "hardwood", "hardwood_plank", "beam", "ironwood_beam", "veneer"]:
			off += GameState.bonus("building", "wood_discount")
		elif str(k) in ["stone", "brick", "tile", "clay"]:
			off += GameState.bonus("building", "stone_discount")
		out[k] = maxi(1, int(ceil(int(nd["cost"][k]) * (1.0 - minf(0.6, off)))))
	return out


## Silo: hay kept outside the bag in run["silo"] (240 per tier).
static func silo_cap() -> int:
	return 240 * built_tier("silo")


static func silo_hay() -> int:
	return int(GameState.run.get("silo", 0))


## Put n hay in the silo; false (nothing stored) when there's no room.
static func silo_add(n: int) -> bool:
	if silo_hay() + n > silo_cap():
		return false
	GameState.run["silo"] = silo_hay() + n
	return true
