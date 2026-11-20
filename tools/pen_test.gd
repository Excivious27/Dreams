extends SceneTree
## Ranch on the farm (CONDUCT 11a P2): RanchFarm care rules (a care day needs a pet and a
## meal, missed days cost a little, one quality table), the one silo feeder (birds with a
## Big Coop, beasts with a Big Barn, milkers first), the classic herd's incubator (no
## lifetime cap), roster spawning from ranch.json (uid-keyed FarmAnimals in ranch.json pens),
## the roster incubator (eggs -> roster babies, capacity), pens fenced without posts inside a
## neighbouring pen and with the gate front kept clear.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(11)
	Campaign.bypass = true
	_run.call_deferred()


func frames(k: int) -> void:
	for i in k:
		await process_frame


func load_farm() -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(14)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await frames(2)
	return current_scene as GameMap


func new_run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["farm_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]
	GameState.run["day"] = 30


func animals(m: GameMap) -> Array:
	var out: Array = []
	for ch in m.get_children():
		if ch is FarmAnimal and not ch.is_queued_for_deletion():
			out.append(ch)
	return out


func _run() -> void:
	new_run()
	# --- 1. Care rules (pure) ---
	var st := {"streak": 0, "last_pet": -9, "fed": -9, "made": -9, "cared": -9}
	for d in range(1, 6):
		st["last_pet"] = d
		st["fed"] = d
		RanchFarm.tend(st, d, true)
	check(int(st["streak"]) == 5 and RanchFarm.quality_for(5) == "s", "5 care days -> silver (streak %d)" % int(st["streak"]))
	st["last_pet"] = 6
	var r := RanchFarm.tend(st, 6, true)
	check(not bool(r["up"]) and int(st["streak"]) == 5, "petted but unfed: the day doesn't count yet")
	st["fed"] = 6
	r = RanchFarm.tend(st, 6, true)
	check(bool(r["up"]) and int(st["streak"]) == 6, "fed later the same day: it counts")
	st["last_pet"] = 8; st["fed"] = 8
	RanchFarm.tend(st, 8, true)
	check(int(st["streak"]) == 6 - RanchFarm.MISS_COST + 1, "one missed day costs %d, not the whole streak (%d)" % [RanchFarm.MISS_COST, int(st["streak"])])
	var st2 := {"streak": 4, "last_pet": 9, "fed": 9, "made": -9, "cared": 8}
	r = RanchFarm.tend(st2, 9, true)
	check(str(r["milestone"]) == "s" and RanchFarm.streak_words(st2, "s").contains("Silver"), "reaching silver says so (munch or pet toast)")
	check(RanchFarm.product_for("cow_brown") == "milk" and RanchFarm.product_for("duck2") == "duck_egg" and RanchFarm.product_for("chicken2") == "egg" and RanchFarm.product_for("rooster") == "", "classic product table")
	GameState.run["builds"] = {"coop": 1, "barn": 2, "silo": 1}
	check(RanchFarm.silo_feeds("cow_brown", false) and not RanchFarm.silo_feeds("chicken2", false) and not RanchFarm.silo_feeds("calf", true) and not RanchFarm.silo_feeds("rooster", false), "feeder rule: Big Barn feeds beasts, not small-coop birds, babies or the rooster")
	GameState.run["builds"]["coop"] = 2
	check(RanchFarm.silo_feeds("chicken2", false) and RanchFarm.silo_feeds("duck2", false), "feeder rule: Big Coop feeds birds")
	check(RanchFarm.hatch_species("egg") == "chicken" and RanchFarm.hatch_species("duck_egg") == "duck" and RanchFarm.hatch_species("milk") == "", "incubator eggs (hen and duck)")

	# --- 2. Classic herd: silo feeds milkers first, petting gives goods ---
	GameState.run["builds"] = {"coop": 2, "barn": 2, "silo": 1}
	GameState.run["silo"] = 3
	var m := await load_farm()
	var herd := animals(m)
	check(herd.size() >= 12, "classic herd spawned (%d)" % herd.size())
	var fed_kinds: Array = []
	for a: Node in herd:
		if int(RanchFarm.state_of(a)["fed"]) == 30:
			fed_kinds.append(str(a.get("kind")))
	check(fed_kinds.size() == 3 and not fed_kinds.has("chicken2"), "short silo fed 3 milkers before hens: %s" % str(fed_kinds))
	var cow: Node = null
	for a: Node in herd:
		if str(a.get("kind")) == "cow_brown" and int(RanchFarm.state_of(a)["fed"]) == 30:
			cow = a
			break
	check(cow != null, "a fed cow")
	if cow:
		var before := GameState.count("milk")
		m.pet_farm_animal(cow)
		await frames(40)
		var s := RanchFarm.state_of(cow)
		check(int(s["last_pet"]) == 30 and int(s["made"]) == 30 and int(s["streak"]) == 1, "fed cow petted: care day + milk made (%s)" % str(s))
		check(GameState.count("milk") > before or m.get_children().any(func(c: Node) -> bool: return c.has_meta("item")), "milk given or popped")
	# Hen without silo hay left and no hay held: hungry, no goods, day not counted.
	GameState.run["silo"] = 0
	var hen: Node = null
	for a: Node in herd:
		if str(a.get("kind")) == "chicken2" and not bool(a.get("baby")) and int(RanchFarm.state_of(a)["fed"]) != 30:
			hen = a
			break
	if hen:
		m.pet_farm_animal(hen)
		var hs := RanchFarm.state_of(hen)
		check(int(hs["last_pet"]) == 30 and int(hs["streak"]) == 0 and int(hs["made"]) != 30, "hungry hen: petted, no care day, no egg")
		GameState.add_item("hay", 2)
		var tb: Array = GameState.run["toolbar"]
		tb[0] = "hay"
		GameState.run["slot"] = 0
		m.pet_farm_animal(hen)
		hs = RanchFarm.state_of(hen)
		check(int(hs["fed"]) == 30 and int(hs["streak"]) == 1 and int(hs["made"]) == 30, "hay held: munches, the day counts, egg made (%s)" % str(hs))
		tb[0] = ""
	# Legacy incubator: four grown hatchlings no longer block a fifth egg.
	GameState.run["coop_hatch"] = [1, 2, 3, 4]
	GameState.add_item("egg", 1)
	m._coop("egg")
	check((GameState.run["coop_hatch"] as Array).size() == 5, "grown hatchlings don't count: a 5th egg goes in")
	m._coop("egg")
	check((GameState.run["coop_hatch"] as Array).size() == 5, "one egg warming at a time")
	# Fences: no post inside a neighbouring pen; gate fronts kept clear of decor.
	var coop_pen: Rect2i = m.pen_of("coop")
	var barn_pen: Rect2i = m.pen_of("barn")
	var inside := 0
	for f: Array in m.get("_fences"):
		var c: Vector2i = f[0]
		if coop_pen.has_point(c) or barn_pen.has_point(c):
			inside += 1
	check(inside == 0, "no fence piece inside a pen (%d)" % inside)
	var pc: Dictionary = m._pen_cells()
	check(pc.has(m._gate_of("coop", coop_pen) + Vector2i(0, 1)) and pc.has(m._gate_of("barn", barn_pen) + Vector2i(0, 1)), "gate fronts reserved (no yard decor)")
	check(m.get("things").values().all(func(t: Dictionary) -> bool: return str(t.get("type", "")) != "station" or str(t.get("build", "")) != "beehive") , "beehive is not drawn as a station")

	# --- 3. Roster mode (ranch.json filled: P1) ---
	Ranch._data = {"species": {
		"chicken": {"name": "Chicken", "home": "coop", "art": {"adult": "chicken", "baby": "chick"}, "egg_item": "egg", "product": {"id": "egg"}},
		"duck": {"name": "Duck", "home": "coop", "art": {"adult": "duck2", "baby": "duck2"}, "egg_item": "duck_egg", "product": {"id": "duck_egg"}, "hatch_days": 4},
		"cow": {"name": "Cow", "home": "barn", "art": {"adult": "cow2", "baby": "calf"}, "product": {"id": "milk"}}},
		"buildings": {"coop": [{"tier": 1, "cap": 4, "pen": [25, 9, 6, 4]}, {"tier": 2, "cap": 6, "pen": [25, 9, 6, 4]}],
			"barn": [{"tier": 1, "cap": 4, "pen": [31, 6, 4, 3]}, {"tier": 2, "cap": 8, "pen": [31, 6, 4, 3]}]},
		"rules": {"silver_streak": 4, "gold_streak": 10}, "products": {}, "processing": {}}
	check(RanchFarm.silver() == 4 and RanchFarm.gold() == 10, "thresholds come from ranch.json rules")
	GameState.run.erase("ranch")
	GameState.run["ranch"] = {"ver": 1, "next_uid": 1, "animals": {}, "houses": {"coop": {"tier": 2}, "barn": {"tier": 2}}}
	var h1 := Ranch.add("chicken", "coop", "Pip", 1)
	var h2 := Ranch.add("duck", "coop", "Dot", 1)
	var c1 := Ranch.add("cow", "barn", "Clover", 1)
	var c2 := Ranch.add("cow", "barn", "Bean", 29)
	Ranch.animal(c2)["adult_day"] = 40
	check(h1 != "" and c2 != "", "roster animals added")
	m = await load_farm()
	herd = animals(m)
	var uids: Array = []
	for a: Node in herd:
		uids.append(RanchFarm.uid_of(a))
	uids.sort()
	var want := [h1, h2, c1, c2]
	want.sort()
	check(uids == want, "one FarmAnimal per roster uid, no fixed herd: %s" % str(uids))
	for a: Node in herd:
		if RanchFarm.uid_of(a) == c2:
			check(bool(a.get("baby")), "a young roster cow spawns as a calf")
		if RanchFarm.uid_of(a) == h1:
			check(m.pen_of("coop").has_point(m.world_to_cell(a.position)) or m.pen_of("coop").grow(1).has_point(m.world_to_cell(a.position)), "roster hen inside the coop pen")
	var cow_node: Node = null
	for a: Node in herd:
		if RanchFarm.uid_of(a) == c1:
			cow_node = a
	GameState.run["silo"] = 5
	if cow_node:
		m.pet_farm_animal(cow_node)
		var rec := Ranch.animal(c1)
		check(int(rec.get("last_pet", -1)) == 30 and int(rec.get("last_fed", -1)) == 30 and int(rec.get("made_day", -1)) == 30, "roster cow: care state lives on the roster record (%s)" % str(rec))
		check(int(rec.get("friend", 0)) > 0, "Ranch.pet raised friendship")
	# Roster incubator: duck egg -> duckling in 4 days, capacity counted.
	GameState.add_item("duck_egg", 1)
	m._coop("duck_egg")
	check(RanchFarm.incubator().size() == 1 and int((RanchFarm.incubator()[0] as Dictionary)["day"]) == 34, "duck egg warming (4 days)")
	check(RanchFarm.coop_room() == 6 - 2 - 1, "coop room = cap - birds - eggs (%d)" % RanchFarm.coop_room())
	GameState.run["day"] = 34
	m = await load_farm()
	check(Ranch.roster("coop").size() == 3 and RanchFarm.incubator().is_empty(), "the egg hatched into a roster duckling")
	Ranch._data = {}
	print("pen_test: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0 if fails == 0 else 1)
