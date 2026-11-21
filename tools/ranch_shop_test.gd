extends SceneTree
## C11a fix2: every ranch species can be bought from its seller in both arcs. Hazel (farmhouse counter +
## morning stall) sells hens, ducks, cows and hogs; Posy (bakery back counter) rabbits and hives, Hazel
## standing in while Posy is away; Tam keeps sheep, goats and llamas. Tier and capacity gates, way out on
## every menu, counter hours (TownHours), and Hazel's starter gift living in the roster (Ranch.starter_gift)
## so the old hard-coded herd never shows on your own farm.
##   godot --headless --fixed-fps 60 --path . -s res://tools/ranch_shop_test.gd
var fails := 0
var checks := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(23)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 20
	GameState.run["time"] = 10 * 60


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Wait for a choice box; returns its option texts ([] = none came up).
func _choice_texts() -> Array:
	var d := Dialogue.instance(self)
	for i in 120:
		if d.active and d._in_choice:
			break
		if d.active and not d._in_choice:
			d._advance()
		await process_frame
	if not (d.active and d._in_choice):
		return []
	var out: Array = []
	for b in d._choices.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	for b in d._pin.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


func _pick(i: int) -> void:
	var d := Dialogue.instance(self)
	d._choose(str(d._choice_key), i)
	await frames(3)


func _run() -> void:
	InputSetup.ensure_actions()
	var sp_all: Dictionary = Ranch.data().get("species", {})
	ok(sp_all.size() >= 9, "ranch.json lists the species (%d)" % sp_all.size())
	for arc in ["penguins", "gangsters"]:
		_fresh(arc)
		for sid: String in sp_all:
			var sel := Shops.seller_of(sid)
			ok(sel != "", "%s %s: has a seller" % [arc, sid])
			# C11b: earned creatures (buy.price 0: quests, regions, the Gene Splicer) and the other arc's creatures
			# are never on a counter.
			var spd: Dictionary = sp_all[sid]
			if int((spd.get("buy", {}) as Dictionary).get("price", 0)) <= 0 or str(spd.get("arc", "")) not in ["", arc]:
				ok(not Shops.animals_for(sel).has(sid), "%s %s: earned or other-arc, not sold" % [arc, sid])
				continue
			ok(Shops.animals_for(sel).has(sid), "%s %s: on %s's animal counter" % [arc, sid, sel])
			var reach := sel == "tam" or not Shops.ranch_counters(str(Shops.seller_row(sel).get("interior", ""))).filter(func(t: Dictionary) -> bool: return t["shop"] == sel).is_empty()
			ok(reach, "%s %s: %s has a counter Shops.run reaches" % [arc, sid, sel])
			ok(Shops.animal_name(sid) != "", "%s %s: has a name" % [arc, sid])
		ok(Shops.seller_greet("hazel") != "" and Shops.seller_greet("posy") != "", "%s: Hazel and Posy have counter words" % arc)
		ok(not Shops.seller_greet("hazel").to_lower().contains("crystal") or arc == "penguins", "%s: no crystal words in the gangster arc" % arc)
		ok(Shops.animals_for("hazel") == ["chicken", "duck", "cow", "peacock", "pig", "emu", "ostrich"],  # C11b exotics
			"%s: Hazel's list, cheapest first: %s" % [arc, str(Shops.animals_for("hazel"))])
		ok(Shops.animals_for("posy") == ["rabbit", "bees", "tortoise"], "%s: Posy's list: %s" % [arc, str(Shops.animals_for("posy"))])
		# Posy away: Hazel sells rabbits and hives, and the bakery counter is gone.
		GameState.run["flags"]["posy_gone"] = true
		ok(Shops.seller_of("rabbit") == "hazel" and Shops.animals_for("hazel").has("bees"), "%s: Posy away -> Hazel sells rabbits and hives" % arc)
		ok(Shops.ranch_counters("bakery").is_empty(), "%s: no Posy counter while she's away" % arc)
		GameState.run["flags"].erase("posy_gone")
		GameState.run["flags"]["shop_1"] = true  # Deuce's arcade takes the bakery (gangster arc only)
		ok(Shops.seller_away("posy") == (arc == "gangsters"), "%s: Deuce's arcade sends Posy away only in the gangster arc" % arc)
		GameState.run["flags"].erase("shop_1")
		# Gates: no home, too low a tier, full.
		ok(Shops.animal_why("rabbit") != "", "%s: no hutch -> rabbit can't be bought (%s)" % [arc, Shops.animal_why("rabbit")])
		Ranch.house("hutch")["tier"] = 1
		ok(Shops.animal_why("rabbit") == "", "%s: hutch built -> rabbit buyable" % arc)
		Ranch.house("coop")["tier"] = 1
		ok(Shops.animal_why("duck").begins_with("needs"), "%s: ducks need the bigger coop (%s)" % [arc, Shops.animal_why("duck")])
		for i in Ranch.capacity("hutch"):
			Ranch.add("rabbit")
		ok(Shops.animal_why("rabbit").contains("full"), "%s: full hutch says so (%s)" % [arc, Shops.animal_why("rabbit")])
		# Counter hours (same table as the doors): shut at night.
		GameState.run["time"] = 22 * 60
		ok(TownHours.counter_shut("hazel") != "" and TownHours.counter_shut("posy") != "", "%s: counters shut at 10pm" % arc)
		GameState.run["time"] = 10 * 60
		ok(TownHours.counter_shut("hazel") == "" and TownHours.counter_shut("posy") == "", "%s: counters serve at 10am" % arc)
		# Starter gift: into the roster, once per tier, room left to buy.
		_fresh(arc)
		Ranch.house("coop")["tier"] = 1
		var g1 := Ranch.starter_gift("coop")
		ok(g1.size() == 2 and Ranch.roster("coop").size() == 2, "%s: coop tier 1 gift = 2 hens in the roster (%d)" % [arc, g1.size()])
		ok(RanchFarm.uses_roster("coop"), "%s: a populated roster means no starter-herd fallback" % arc)
		ok(Ranch.starter_gift("coop").is_empty(), "%s: the gift comes once" % arc)
		ok(Ranch.roster("coop").size() < Ranch.capacity("coop") and Shops.animal_why("chicken") == "", "%s: room left to buy hens" % arc)
		Ranch.house("coop")["tier"] = 2
		var g2 := Ranch.starter_gift("coop")
		ok(g2.size() == 1 and str(Ranch.animal(str(g2[0])).get("species", "")) == "duck", "%s: Big Coop adds a duck" % arc)
		Ranch.house("barn")["tier"] = 1
		ok(Ranch.starter_gift("barn").size() == 2 and Ranch.roster("barn").size() < Ranch.capacity("barn"), "%s: barn gift leaves room" % arc)
		# A save that migrated the legacy herd already had its gift.
		_fresh(arc)
		Ranch.house("coop")["tier"] = 1
		var luid := Ranch.add("chicken", "coop")
		Ranch.animal(luid)["legacy"] = "chicken2_27_10"
		ok(Ranch.starter_gift("coop").is_empty() and Ranch.roster("coop").size() == 1, "%s: legacy herd -> no second gift" % arc)
	ok((Ranch.data().get("starter", {}) as Dictionary).has("coop"), "ranch.json carries the starter table")
	await _ui("penguins")
	await _ui("gangsters")
	print("ranch_shop_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## The rooms and the menus: counters stand where the sellers do, a purchase pays and joins the roster,
## and the last option is always a way out.
func _ui(arc: String) -> void:
	_fresh(arc)
	GameState.run["crystals"] = 5000
	Ranch.house("coop")["tier"] = 1
	GameMap.next_interior = "hazel_house"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	await frames(10)
	var m := current_scene as GameMap
	ok(m != null and str(m.things.get(Vector2i(5, 5), {}).get("shop", "")) == "hazel", "%s: Hazel's farmhouse has her animal counter" % arc)
	if m == null:
		return
	var run_done := [false]
	var go := func() -> void:
		await Shops.run(m, "hazel")
		run_done[0] = true
	go.call()
	var opts := await _choice_texts()
	ok(opts.filter(func(o: Variant) -> bool: return not Dialogue.is_way_out(str(o))).size() == 7 and Dialogue.is_way_out(str(opts[-1])), "%s: Hazel's counter lists 7 animals + a way out (%s)" % [arc, str(opts)])
	ok(not opts.is_empty() and Dialogue.is_way_out(str(opts[-1])), "%s: last option is a way out" % arc)
	ok(not opts.is_empty() and str(opts[0]).contains(Money.fmt(400)), "%s: price through Money.fmt (%s)" % [arc, str(opts[0]) if not opts.is_empty() else ""])
	ok(opts.size() > 1 and str(opts[1]).contains("needs"), "%s: duck row says why not (%s)" % [arc, str(opts[1]) if opts.size() > 1 else ""])
	var before := int(GameState.run["crystals"])
	var n0 := Ranch.roster("coop").size()
	await _pick(0)
	ok(Ranch.roster("coop").size() == n0 + 1 and int(GameState.run["crystals"]) == before - 400, "%s: bought a hen from Hazel" % arc)
	opts = await _choice_texts()
	await _pick(opts.size() - 1)
	await frames(5)
	ok(run_done[0], "%s: Back leaves Hazel's counter" % arc)
	# Posy's bakery counter, a hutch to fill.
	Ranch.house("hutch")["tier"] = 1
	GameMap.next_interior = "bakery"
	change_scene_to_file("res://scenes/interior.tscn")
	await frames(10)
	m = current_scene as GameMap
	var bt: Dictionary = m.things.get(Vector2i(5, 5), {}) if m else {}
	ok(str(bt.get("shop", "")) == "posy", "%s: the bakery has Posy's animal counter" % arc)
	if m == null:
		return
	run_done[0] = false
	var go2 := func() -> void:
		await Shops.run(m, "posy")
		run_done[0] = true
	go2.call()
	opts = await _choice_texts()
	ok(opts.size() == 4 and Dialogue.is_way_out(str(opts[-1])), "%s: Posy lists rabbits, hives, tortoises and a way out (%s)" % [arc, str(opts)])
	var r0 := Ranch.roster("hutch").size()
	await _pick(0)
	ok(Ranch.roster("hutch").size() == r0 + 1 and str(Ranch.animal(str(Ranch.roster("hutch")[-1])).get("species", "")) == "rabbit", "%s: bought a rabbit from Posy" % arc)
	opts = await _choice_texts()
	await _pick(opts.size() - 1)
	await frames(5)
	ok(run_done[0], "%s: Back leaves Posy's counter" % arc)
