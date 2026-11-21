extends SceneTree
## The beach marina (C14 P3): tier gates and bundles, routes in the TravelNet link
## format, passage gating, NPC shifts, charters, the grown beach in both arcs
## (ferry/Skipper at the west tip for penguins, Tidewater Launch for gangsters,
## no colony ferry in the gangster arc), sea fish, the wreck log and the sandbar.
##   godot --headless --path . --fixed-fps 60 -s res://tools/marina_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(14)
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle() -> void:
	var gt := 0.0
	var d := Dialogue.instance(self)
	while gt < 3.0:
		if d.active:
			d._advance()
		await process_frame
		gt += root.get_process_delta_time()


func _quests(ids: Array) -> void:
	for id: String in ids:
		GameState.run["quests"].append({"id": id, "done": true})


func _run() -> void:
	_data()
	for arc in ["penguins", "gangsters"]:
		await _arc(arc)
	print("marina_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	var d := Marina.data()
	check((d.get("tiers", []) as Array).size() == 4, "four marina tiers")
	for k in ["tiers", "npcs", "spots", "schedule", "shops", "quests", "charters", "routes", "festival", "lines"]:
		check(d.has(k), "marina.json has %s" % k)
	for r: Dictionary in d.get("routes", []):
		for k in ["id", "a", "b", "tier", "kind", "unlock", "cost", "free_after", "path", "both_ways"]:
			check(r.has(k), "route %s has %s (TravelNet link format)" % [r.get("id", "?"), k])
		check(str(r["a"]) in ["beach_marina", "beach_colony_ferry", "beach_tidewater"], "route %s leaves from a beach station" % r["id"])
		check(str(r["kind"]) in ["ferry", "boat"], "route %s is a ferry/boat link" % r["id"])
	for n: Dictionary in (d["npcs"] as Dictionary).values():
		check(str(n.get("name", "")) != "", "every marina NPC has a name")


func _arc(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["beach_seen"] = true
	GameState.run["day"] = 3
	GameState.run["time"] = 10 * 60
	var pen := arc == "penguins"
	check(Marina.tier() == 0, "%s: marina starts at tier 0" % arc)
	check(GameState.run.has("marina"), "%s: Marina.st() creates run.marina on demand" % arc)
	# Gates: story tier first, then the bundle.
	check(not Marina.can_upgrade() and Marina.why_not_upgrade().contains("story"), "%s: tier 1 waits on the story" % arc)
	_quests(["clear_meadow"])
	check(GameState.progress_tier() >= 1, "%s: story tier 1 forced" % arc)
	check(not Marina.can_upgrade(), "%s: tier 1 needs its bundle" % arc)
	var t1: Dictionary = Marina.next_tier()
	GameState.run["crystals"] = int(t1["money"]) + 100
	for id: String in t1["items"]:
		GameState.add_item(id, int(t1["items"][id]), true)
	check(Marina.can_upgrade(), "%s: tier 1 buildable with the bundle (%s)" % [arc, Marina.why_not_upgrade()])
	check(Marina.upgrade() and Marina.tier() == 1, "%s: tier 1 built" % arc)
	check(int(GameState.run["crystals"]) == 100, "%s: tier 1 money paid" % arc)
	for id: String in t1["items"]:
		check(GameState.count(id) == 0, "%s: tier 1 took the %s" % [arc, id])
	# Passages: regional routes open at tier 2, gangster Docks needs its campaign.
	for r: Dictionary in Marina.routes():
		check(not Marina.route_open(r), "%s: %s closed at tier 1" % [arc, r["id"]])
	check(Marina.routes().filter(func(r: Dictionary) -> bool: return str(r["a"]) == "beach_tidewater").size() == (0 if pen else 1), "%s: the Tidewater Launch route is gangster-only" % arc)
	Marina.st()["tier"] = 2
	var regional := Marina.routes().filter(func(r: Dictionary) -> bool: return str(r["a"]) == "beach_marina")
	check(regional.size() == 3, "%s: three regional passages" % arc)
	for r: Dictionary in regional:
		check(Marina.route_open(r) and Marina.route_cost(r) > 0, "%s: %s open and paid at tier 2" % [arc, r["id"]])
	Marina.st()["tier"] = 4
	for r: Dictionary in regional:
		check(Marina.route_cost(r) == 0, "%s: %s free at tier 4" % [arc, r["id"]])
	Marina.st()["tier"] = 2
	# NPC shifts.
	check(Marina.npc_here("hollis", 10) and not Marina.npc_here("hollis", 22), "%s: Hollis works days" % arc)
	check(Marina.npc_here("skipper", 10) == pen and Marina.npc_here("dutch", 10) == (not pen), "%s: Skipper Barnacle / Dutch Calloway per arc" % arc)
	check(not Marina.npc_here("saffi", 12) or int(GameState.run["day"]) % 7 == 0, "%s: Saffi only on trader days" % arc)
	check(Marina.vendor_here() == (not pen), "%s: the boardwalk vendor is a gangster-arc shift" % arc)
	# Charter: once a day, pays, brings fish home, clock moves on.
	var shoals: Dictionary = Marina.data()["charters"][0]
	GameState.run["crystals"] = 1000
	var t0 := int(GameState.run["time"])
	var got := Marina.run_charter(shoals)
	check(got.size() == int(shoals["catches"]), "%s: the Shoals charter lands its catch" % arc)
	check(int(GameState.run["crystals"]) == 1000 - int(shoals["price"]), "%s: charter paid" % arc)
	check(int(GameState.run["time"]) == t0 + 180, "%s: three hours at sea" % arc)
	check(Marina.run_charter(shoals).is_empty(), "%s: one charter a day" % arc)
	for c: Dictionary in Marina.data()["charters"]:
		check(ResourceLoader.exists("res://scenes/%s.tscn" % str(c["scene"])), "%s: charter area %s has its scene" % [arc, c["scene"]])
	check(not "salmon" in Marina.shore_pool() and not "goldfish" in Marina.shore_pool(), "%s: no freshwater fish in the sea" % arc)
	# Dock jobs: per arc, hand-in takes the goods and pays once.
	var js := Marina.jobs()
	var ids := js.map(func(q: Dictionary) -> String: return str(q["id"]))
	check(("marina_shipshape" in ids) == pen and ("marina_quiet_cargo" in ids) == (not pen), "%s: Shipshape / Quiet Cargo per arc" % arc)
	var lights: Dictionary = js.filter(func(q: Dictionary) -> bool: return str(q["id"]) == "marina_lights")[0]
	check(not Marina.hand_in(lights), "%s: no hand-in without the lamp oil" % arc)
	GameState.add_item("lamp_oil", 4, true)
	var c0 := int(GameState.run["crystals"])
	check(Marina.hand_in(lights) and GameState.count("lamp_oil") == 0 and int(GameState.run["crystals"]) > c0, "%s: lights job handed in and paid" % arc)
	check(not "marina_lights" in Marina.jobs().map(func(q: Dictionary) -> String: return str(q["id"])), "%s: a done job leaves the board" % arc)
	# The beach: grown, ferry/launch at the west tip, the marina things.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await _frames(10)
	await _settle()
	var m := current_scene as GameMap
	check(m != null and m.scene_id() == "beach", "%s: beach loads" % arc)
	if m == null:
		return
	check(m.cols >= 100 and m.rows >= 46, "%s: the beach grew (%dx%d)" % [arc, m.cols, m.rows])
	var types := {}
	var kinds := {}
	var stations := {}
	for c: Vector2i in m.things:
		var t: Dictionary = m.things[c]
		types[str(t.get("type", ""))] = true
		if str(t.get("type", "")) == "marina":
			kinds[str(t.get("kind", ""))] = true
		if t.has("station"):
			stations[str(t["station"])] = true
	check(types.has("ferry") == pen, "%s: colony ferry thing only for penguins" % arc)
	check(stations.has("beach_colony_ferry") == pen and stations.has("beach_tidewater") == (not pen), "%s: west tip station per arc" % arc)
	check(stations.has("beach_marina"), "%s: the marina passage desk (tier 1+)" % arc)
	check(kinds.has("board") and kinds.has("market") and kinds.has("boathouse"), "%s: tier-2 marina things placed" % arc)
	check(types.has("sandbar_chest"), "%s: the sandbar chest is out in the cove" % arc)
	var qe := false
	for e: Dictionary in m.exits:
		if str(e.get("scene", "")) == "quarry":
			qe = (e["rect"] as Rect2i).position.x == m.cols - 1
	check(qe, "%s: the quarry exit sits on the east edge" % arc)
	# Sandbar dig: one time.
	for c: Vector2i in m.things.keys():
		if str(m.things[c].get("type", "")) == "sandbar_chest":
			var pearls := GameState.count("pearl")
			m.interact(c, m.things[c])
			check(GameState.count("pearl") == pearls + 1 and not m.things.has(c), "%s: the sandbar chest gives a pearl once" % arc)
	# Wreck log: the third search on a new day gives the map scrap once.
	GameState.run["flags"].erase("wreck_day")
	var scraps := GameState.count("map_scrap")
	for i in 3:
		GameState.run["day"] = 10 + i * 5
		m._wreck()
		await _settle()
	check(GameState.count("map_scrap") == scraps + 1, "%s: the wreck's log turns up on the third search" % arc)
