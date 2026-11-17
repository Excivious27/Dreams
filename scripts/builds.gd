class_name Builds
## Farm buildings (data/buildings.json): tiers, permits, timed construction.
##   run["builds"][id]       = tier built (int); legacy saves store `true` = tier 1
##   run["permits"][id]      = highest tier permitted
##   run["construction"][id] = {"tier": n, "done_day": d}   (Hazel's crew, overnight)

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/buildings.json")
		_data.erase("_")
	return _data


static func built_tier(id: String) -> int:
	var v: Variant = GameState.run.get("builds", {}).get(id, 0)
	if v is bool:
		return 1 if v else 0
	return int(v)


static func is_built(id: String) -> bool:
	return built_tier(id) > 0


static func tier_def(id: String, tier: int) -> Dictionary:
	for t in data().get(id, {}).get("tiers", []):
		if int(t["tier"]) == tier:
			return t
	return {}


static func current_def(id: String) -> Dictionary:
	return tier_def(id, built_tier(id))


static func next_def(id: String) -> Dictionary:
	return tier_def(id, built_tier(id) + 1)


static func permitted(id: String) -> int:
	return int(GameState.run.get("permits", {}).get(id, 0))


static func under_construction(id: String) -> Dictionary:
	return GameState.run.get("construction", {}).get(id, {})


## Why the next tier can't start ("" = it can, "permit" = needs a permit).
static func blocker(id: String) -> String:
	var nd := next_def(id)
	if nd.is_empty():
		return "max"
	if not under_construction(id).is_empty():
		return "building"
	var ul: Dictionary = nd.get("unlock", {})
	if ul.has("skill") and GameState.skill_level(str(ul["skill"][0])) < int(ul["skill"][1]):
		return "%s level %d" % [str(ul["skill"][0]).capitalize(), int(ul["skill"][1])]
	if ul.has("quest") and not GameState.quest_done(str(ul["quest"])):
		return "story first"
	if ul.has("friend") and GameState.friend_hearts(str(ul["friend"][0])) < int(ul["friend"][1]):
		return "%s ♥%d" % [str(GameState.npcs[str(ul["friend"][0])]["name"]), int(ul["friend"][1])]
	if int(nd.get("permit", 0)) > 0 and permitted(id) < int(nd["tier"]):
		return "permit"
	for need in nd.get("cost", {}):
		if GameState.count(str(need)) < int(nd["cost"][need]):
			return "need %d %s" % [int(nd["cost"][need]), GameState.item_name(str(need))]
	return ""


## Start construction (or finish instantly when days == 0). Returns a toast.
static func start(id: String) -> String:
	var why := blocker(id)
	if why != "":
		return "Can't build yet: %s." % why
	var nd := next_def(id)
	for need in nd.get("cost", {}):
		GameState.add_item(str(need), -int(nd["cost"][need]))
	var days := int(nd.get("days", 0))
	if days <= 0:
		_finish(id, int(nd["tier"]))
		return "Built the %s." % str(nd["name"])
	GameState.run["construction"] = GameState.run.get("construction", {})
	GameState.run["construction"][id] = {"tier": int(nd["tier"]), "done_day": int(GameState.run["day"]) + days}
	return "Hazel's crew starts on the %s. %d day%s." % [str(nd["name"]), days, "" if days == 1 else "s"]


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
	if int(GameState.run["crystals"]) < price:
		return "A %s permit is ◆%d. You have ◆%d." % [str(nd["name"]), price, int(GameState.run["crystals"])]
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	GameState.run["permits"] = GameState.run.get("permits", {})
	GameState.run["permits"][id] = int(nd["tier"])
	return "Permit stamped: %s (◆%d)." % [str(nd["name"]), price]


static func permit_price(id: String) -> int:
	var nd := next_def(id)
	var price := int(nd.get("permit", 0))
	if GameState.has_friend_perk("alder", 4):
		price = int(price * 0.8)
	return price
