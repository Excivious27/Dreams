class_name Marina
extends RefCounted
## The beach marina (C14 P3): a tier-built harbour at the east of the beach.
## Data data/marina.json (tools/gen_marina.py); state run["marina"] via st()
## (P4 adds "marina" to GameState.RUN_BLOCKS; st() creates it on demand).
## Tiers are Project-style bundles (items + money); boat passages are TravelNet
## links (marina.json "routes"), ridden through TravelNet when it exists, else
## through this desk. Both arcs: same tiers and people, per-arc dressing/words.

const PATH := "res://data/marina.json"
const TRAVEL := "res://scripts/travel_net.gd"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
	return _data


static func st() -> Dictionary:
	if not GameState.run.has("marina") or not (GameState.run["marina"] is Dictionary):
		GameState.run["marina"] = {}
	var s: Dictionary = GameState.run["marina"]
	for k: String in ["tier", "charter_day", "wreck_searches", "wreck_last"]:
		if not s.has(k):
			s[k] = -1 if k in ["charter_day", "wreck_last"] else 0
	for k: String in ["quests", "met", "routes_open"]:
		if not s.has(k) or not (s[k] is Dictionary):
			s[k] = {}
	return s


static func tier() -> int:
	return int(st()["tier"])


static func arc_key() -> String:
	return "pen" if GameState.is_penguins() else "gang"


static func line(key: String) -> String:
	return str((data().get("lines", {}) as Dictionary).get(arc_key(), {}).get(key, ""))


static func music() -> String:
	var t := line("music")
	return t if t != "" and Music.has_track(t) else ""


## The next tier's bundle, or {} when the marina is complete.
static func next_tier() -> Dictionary:
	for t: Dictionary in data().get("tiers", []):
		if int(t["n"]) == tier() + 1:
			return t
	return {}


## Why the next tier can't be built yet ("" = it can). All-ages words.
static func why_not_upgrade() -> String:
	var t := next_tier()
	if t.is_empty():
		return "The marina is finished."
	if GameState.progress_tier() < int(t["gate"]):
		return "Hollis: 'Not yet. Come back once the story's moved on a little.'"
	if not GameState.is_penguins() and str(t.get("gang_campaign", "")) != "":
		if not Campaign.region_open(str(t["gang_campaign"])):
			return "Hollis: 'The Docks crew runs this water. Settle things there first.'"
	if int(GameState.run["crystals"]) < int(t["money"]):
		return "Hollis: 'That's %s short.'" % Money.amount(int(t["money"]) - int(GameState.run["crystals"]))
	var items: Dictionary = t["items"]
	for id: String in items:
		if GameState.count(id) < int(items[id]):
			return "Hollis: 'Still need %s.'" % ItemWords.count_id(id, int(items[id]) - GameState.count(id))
	return ""


static func can_upgrade() -> bool:
	return why_not_upgrade() == ""


## Pays the next bundle and raises the tier. False if it can't.
static func upgrade() -> bool:
	if not can_upgrade():
		return false
	var t := next_tier()
	GameState.run["crystals"] = int(GameState.run["crystals"]) - int(t["money"])
	var items: Dictionary = t["items"]
	for id: String in items:
		GameState.add_item(id, -int(items[id]))
	st()["tier"] = int(t["n"])
	for r: Dictionary in routes():
		if route_open(r):
			st()["routes_open"][str(r["id"])] = true
	return true


static func bundle_text(t: Dictionary) -> String:
	var parts: Array = []
	var items: Dictionary = t["items"]
	for id: String in items:
		parts.append(ItemWords.count_id(id, int(items[id])))
	parts.append(Money.amount(int(t["money"])))
	return ", ".join(parts)


# ---- routes (TravelNet link format) ------------------------------------------

static func routes() -> Array:
	var out: Array = []
	var arc := "penguins" if GameState.is_penguins() else "gangsters"
	for r: Dictionary in data().get("routes", []):
		if str(r.get("arc", "both")) in ["both", arc]:
			out.append(r)
	return out


static func route_open(r: Dictionary) -> bool:
	if tier() < int(r.get("tier", 1)):
		return false
	var u: Dictionary = r.get("unlock", {})
	if str(u.get("type", "")) == "campaign" and not Campaign.region_open(str(u.get("id", ""))):
		return false
	return true


static func routes_open() -> Array:
	var out: Array = []
	for r: Dictionary in routes():
		if route_open(r):
			out.append(r)
	return out


static func route_cost(r: Dictionary) -> int:
	if tier() >= int(r.get("free_after", 99)):
		return 0
	return int((r.get("cost", {}) as Dictionary).get("money", 0))


static func route_why(r: Dictionary) -> String:
	if tier() < int(r.get("tier", 1)):
		return "opens with marina tier %d" % int(r.get("tier", 1))
	if not route_open(r):
		return "opens after the Docks"
	return ""


static func has_travel_net() -> bool:
	return ResourceLoader.exists(TRAVEL)


## A station's ride list: TravelNet's desk when it exists, else this one.
static func desk(m: GameMap, station: String) -> void:
	if has_travel_net():
		var tn: Script = load(TRAVEL)
		if tn and tn.has_method("desk"):
			tn.call("desk", m, station)
			return
	await passage(m, station)


## Fallback passage desk (no TravelNet yet): the routes from `station`, way out last.
static func passage(m: GameMap, station: String) -> void:
	var list: Array = []
	var opts: Array = []
	for r: Dictionary in routes():
		if str(r["a"]) != station:
			continue
		var why := route_why(r)
		var cost := route_cost(r)
		opts.append("%s%s" % [str(r.get("label", r["b"])), (" (%s)" % why) if why != "" else ("  " + (Money.amount(cost) if cost > 0 else "free"))])
		list.append(r)
	var who := "Dutch Calloway" if station == "beach_tidewater" else "Hollis Wade"
	if list.is_empty():
		m.hud.toast("%s: 'No boats out of here yet.'" % who)
		return
	opts.append("Stay ashore")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": who, "text": "Where to?" if GameState.is_penguins() else "Quiet passage. Where to?", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= list.size():
		return
	ride(m, list[i])


## Pays and sails one route (fallback when TravelNet isn't there to ride it).
static func ride(m: GameMap, r: Dictionary) -> bool:
	var why := route_why(r)
	if why != "":
		m.hud.toast("That passage %s." % why)
		return false
	var cost := route_cost(r)
	if int(GameState.run["crystals"]) < cost:
		m.hud.toast("A ticket costs %s." % Money.amount(cost))
		return false
	var land: Array = (data().get("landings", {}) as Dictionary).get(str(r["b"]), [])
	if land.is_empty():
		return false
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	st()["routes_open"][str(r["id"])] = true
	Music.instance(m.get_tree()).sfx("horn", "quest_done")
	var c: Array = land[1]
	m.go_to(str(land[0]), Vector2(int(c[0]) * GameMap.TILE, int(c[1]) * GameMap.TILE + 8), str(land[2]))
	return true


# ---- people ------------------------------------------------------------------

static func npc(id: String) -> Dictionary:
	return (data().get("npcs", {}) as Dictionary).get(id, {})


## Is marina person `id` at work at `hour` today (tier, arc, schedule, trader day)?
static func npc_here(id: String, hour: int) -> bool:
	var n := npc(id)
	if n.is_empty() or tier() < int(n.get("tier", 0)):
		return false
	var arc := str(n.get("arc", "both"))
	if arc == "penguins" and not GameState.is_penguins():
		return false
	if arc == "gangsters" and GameState.is_penguins():
		return false
	if n.has("every") and int(GameState.run["day"]) % int(n["every"]) != 0:
		return false
	var sch: Array = (data().get("schedule", {}) as Dictionary).get(id, [0, 24])
	return hour >= int(sch[0]) and hour < int(sch[1])


static func hour_now() -> int:
	return int(GameState.run["time"]) / 60 % 24


## Gangster arc: the boardwalk vendor (Dabney's stall) is on shift: the beach
## counts as peopled for Racket only then (c14_04-17).
static func vendor_here() -> bool:
	return not GameState.is_penguins() and npc_here("dabney", hour_now())


static func greet(id: String) -> String:
	var n := npc(id)
	var t := str(n.get(arc_key(), n.get("pen", n.get("gang", "..."))))
	return t


# ---- fish --------------------------------------------------------------------

static func shore_pool() -> Array:
	return (data().get("pools", {}) as Dictionary).get("shore", ["sunfish", "bass", "eel", "puffer", "starfin"])


static func deep_pool() -> Array:
	return (data().get("pools", {}) as Dictionary).get("deep", [])


## Ines' catch of the day: one named fish, rotating by day.
static func catch_of_day() -> String:
	var pool := shore_pool().filter(func(f: String) -> bool: return f != "crab")
	return str(pool[int(GameState.run["day"]) % pool.size()])


static func charter_why(c: Dictionary) -> String:
	if tier() < int(c.get("tier", 2)):
		return "opens with marina tier %d" % int(c.get("tier", 2))
	if int(st()["charter_day"]) == int(GameState.run["day"]):
		return "one charter a day"
	if bool(c.get("night", false)) and not GameState.is_night():
		return "night only"
	return ""


static func charter_price(c: Dictionary) -> int:
	return 0 if tier() >= 4 else int(c.get("price", 0))


## Roz's charter: pay, three hours at sea, the catch comes home with you.
## Returns the fish caught (deterministic per day).
static func run_charter(c: Dictionary) -> Array:
	if charter_why(c) != "" or int(GameState.run["crystals"]) < charter_price(c):
		return []
	GameState.run["crystals"] = int(GameState.run["crystals"]) - charter_price(c)
	st()["charter_day"] = int(GameState.run["day"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(c["id"]) + str(GameState.run["day"]))
	var fish: Array = c["fish"]
	var got: Array = []
	for i in int(c.get("catches", 3)):
		var f := str(fish[rng.randi_range(0, fish.size() - 1)])
		GameState.add_item(f, 1)
		got.append(f)
	GameState.run["time"] = mini(int(GameState.run["time"]) + int(c.get("hours", 3)) * 60, 25 * 60)
	return got


static func charter(m: GameMap) -> void:
	var cs: Array = data().get("charters", [])
	var opts: Array = []
	for c: Dictionary in cs:
		var why := charter_why(c)
		opts.append("%s%s" % [str(c["name"]), (" (%s)" % why) if why != "" else ("  " + (Money.amount(charter_price(c)) if charter_price(c) > 0 else "free"))])
	opts.append("Not today")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Captain Roz Tern", "text": greet("roz"), "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= cs.size():
		return
	var c: Dictionary = cs[i]
	var why := charter_why(c)
	if why != "":
		m.hud.toast("Roz: 'That one's %s.'" % why)
		return
	if int(GameState.run["crystals"]) < charter_price(c):
		m.hud.toast("Roz: 'It's %s a head.'" % Money.amount(charter_price(c)))
		return
	var got := run_charter(c)
	var names: Array = []
	for f: String in got:
		names.append(GameState.item_name(f))
	m.tell([{"who": "Captain Roz Tern", "text": "Three hours out on %s. Lines in! You bring home: %s." % [str(c["name"]), ", ".join(names)]}])


# ---- interactions ------------------------------------------------------------

## Marina things placed by beach.gd: {type: "marina", kind: ...}.
static func interact(m: GameMap, _c: Vector2i, thing: Dictionary) -> bool:
	if str(thing.get("type", "")) != "marina":
		return false
	match str(thing.get("kind", "")):
		"board":
			m.later(board.bind(m))
		"passage":
			m.later(desk.bind(m, str(thing.get("station", "beach_marina"))))
		"charter", "camp":
			if tier() < 2:
				m.tell([{"who": "Captain Roz Tern", "text": greet("roz") + " 'Fix the pier with Hollis and I'll take folk out.'"}])
			else:
				m.later(charter.bind(m))
		"bait", "market", "boathouse", "trader":
			_shop(m, str(thing["kind"]))
		"skipper":
			m.later(Colony.ferry.bind(m))
		_:
			return false
	return true


static func _shop(m: GameMap, sid: String) -> void:
	var s: Dictionary = (data().get("shops", {}) as Dictionary).get(sid, {})
	if s.is_empty() or tier() < int(s.get("tier", 1)):
		m.tell([{"text": line("closed")}])
		return
	var who := str(npc(str(s["who"])).get("name", ""))
	if not npc_here(str(s["who"]), hour_now()):
		m.hud.toast("%s is off shift." % who)
		return
	var greet_t := greet(str(s["who"]))
	if sid == "market":
		greet_t += " Today: %s." % GameState.item_name(catch_of_day())
	Shops.stall(m, who, greet_t, s["goods"], 0.0, "marina_" + sid)


static func board(m: GameMap) -> void:
	var t := next_tier()
	if t.is_empty():
		m.tell([{"who": "Hollis Wade", "text": "Every berth full, every light lit. Finest marina on the coast."}])
		return
	var why := why_not_upgrade()
	var opens := str(t.get("opens" if GameState.is_penguins() else "opens_gang", ""))
	var opts: Array = ["Build it (%s)" % bundle_text(t), "Not yet"]
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Hollis Wade", "text": "%s %s: %s" % [greet("hollis") if tier() == 0 else "Next job:", str(t["name"]), opens], "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice != 0:
		return
	if why != "":
		m.hud.toast(why, Color(1, 0.85, 0.6))
		return
	if upgrade():
		Music.instance(m.get_tree()).sfx("horn", "quest_done")
		m.tell([{"who": "Hollis Wade", "text": line("upgrade_done") % str(t["name"])}])
		if m.has_method("rebuild_marina"):
			m.call_deferred("rebuild_marina")
