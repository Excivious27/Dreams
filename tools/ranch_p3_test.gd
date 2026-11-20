extends SceneTree
## C11a P3: the Ranching tree (both arcs, caps, blueprints), ranch building tiers + Ranching gates,
## Mayo Machine / Honey Extractor books, starred inputs keeping their star, the Ranch log and Animal
## goods in the Shipping log, and the animal counter (Shops.animals_for / animal_why with injected
## Ranch data, works with ranch.json empty or full).
##   godot --headless --path . -s res://tools/ranch_p3_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(11)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 20


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		_fresh(arc)
		# Skill tree
		ok(GameState.skills_data.has("ranching"), "%s: Ranching tree exists" % arc)
		ok(GameState.skill_in_arc("ranching"), "%s: Ranching shows in this arc" % arc)
		ok(GameMenu.SKILL_ORDER.has("ranching"), "Ranching is in the Skills tab order")
		var nodes: Array = GameState.skills_data["ranching"]["nodes"]
		ok(nodes.size() == 40, "Ranching has 40 nodes (%d)" % nodes.size())
		var tot := {}
		for n: Dictionary in nodes:
			for k: String in (n.get("effect", {}) as Dictionary):
				var v: Variant = n["effect"][k]
				if v is float or v is int:
					tot[k] = float(tot.get(k, 0.0)) + float(v) * int(n.get("ranks", 1))
			ok(not (n.get("effect", {}) as Dictionary).has("hp") and not (n.get("effect", {}) as Dictionary).has("energy"), "no hp/energy filler in Ranching (%s)" % n["id"])
			ok(not str(n.get("desc", "")).to_lower().contains("crystal"), "no crystal money word in %s" % n["id"])
		for k: String in tot:
			if GameState.BONUS_CAPS.has(k):
				ok(float(tot[k]) <= float(GameState.BONUS_CAPS[k]) + 0.001, "ranching %s total %.2f under its cap" % [k, tot[k]])
			else:
				ok(k in ["blueprint"], "ranching key %s has a cap in BONUS_CAPS" % k)
		for f: Dictionary in GameState.skills_data["farming"]["nodes"]:
			ok(not (f.get("effect", {}) as Dictionary).has("animal_yield"), "Farming no longer carries animal_yield (%s)" % f["id"])
		ok(GameState.blueprint_lock("hutch") != "" and GameState.blueprint_lock("sty") != "", "hutch and sty need Ranching blueprints")
		ok(Builds.gate("hutch").contains("Ranching"), "hutch gate names the Ranching tree: %s" % Builds.gate("hutch"))
		var bp := ""
		for n: Dictionary in nodes:
			if (n.get("effect", {}) as Dictionary).get("blueprint", "") == "hutch":
				bp = str(n["id"])
		GameState.run["skills"]["ranching"] = {"level": 10, "xp": 0, "nodes": {bp: 1}}
		GameState._unlock_cache = {}
		ok(GameState.blueprint_lock("hutch") == "", "learning Hutch Blueprint opens the hutch")
		# Building tiers
		for bid in ["coop", "barn", "beehive", "silo"]:
			var tiers: Array = Builds.all()[bid]["tiers"]
			ok(tiers.size() == 3, "%s has 3 tiers" % bid)
			for t: Dictionary in tiers:
				ok(int(t.get("price", 0)) > 0 and Art.has(str(t.get("group", "props")), str(t["sprite"])), "%s tier %d priced and drawn" % [bid, int(t["tier"])])
		ok(str(Builds.all()["coop"]["tiers"][2]["unlock"]["skill"][0]) == "ranching", "Deluxe Coop is a Ranching gate")
		ok(str(Builds.all()["barn"].get("seller", "")) == "Benno" and str(Builds.all()["stable"].get("seller", "")) == "Benno", "Benno sells the barn and stable")
		ok(str(Builds.all()["beehive"].get("ranch", "")) == "apiary", "beehive is the apiary home")
		if not (GameState.run.get("builds", null) is Dictionary):
			GameState.run["builds"] = {}
		GameState.run["builds"]["silo"] = 3
		ok(Builds.silo_cap() == 720, "Twin Silo holds 720 hay (%d)" % Builds.silo_cap())
		# Stations
		ok(Crafting.is_station("mayo") and Crafting.is_station("extractor"), "Mayo Machine and Honey Extractor are stations")
		var books: Dictionary = GameState.load_json("res://data/recipes.json")
		ok((books.get("mayo", []) as Array).size() >= 2 and (books.get("extractor", []) as Array).size() >= 4, "ranch books filled")
		for id in ["mayonnaise", "duck_mayonnaise", "beeswax", "honey_jar", "cream", "yogurt", "truffle_oil"]:
			ok(GameState.items.has(id) and Hud.icon_for(id) != "" and Art.has("items", Hud.icon_for(id)), "%s exists with an icon" % id)
		# Starred inputs keep their star
		var cheese: Dictionary = {}
		for r: Dictionary in books["press"]:
			if str(r["id"]) == "cheese":
				cheese = r
		GameState.run["inventory"]["milk"] = 0
		GameState.run["quality"] = {}
		GameState.add_item("milk", 3)
		GameState.add_quality("milk", "g", 2)
		var j := Crafting.start("press", "press", cheese, 1, 1)
		ok(not j.has("q"), "one milk used plain-first: no star (%s)" % str(j.get("q", {})))
		j = Crafting.start("press", "press", cheese, 1, 2)
		ok(int((j.get("q", {}) as Dictionary).get("g", 0)) == 2, "two gold milk -> two gold cheese (%s)" % str(j.get("q", {})))
		# Collections
		ok(Collections.in_log("ranch", "egg") and Collections.in_log("ranch", "milk"), "Ranch log lists eggs and milk")
		ok(Collections.record_ranch("egg", 2, true) and Collections.amount_of("ranch", "egg") == 2 and not Collections.record_ranch("egg", 1, true), "record_ranch counts and flags the first")
		ok(Collections.in_log("shipping", "egg") and Collections.in_log("shipping", "cheese") and Collections.in_log("shipping", "mayonnaise"), "animal and artisan goods are in the Shipping log")
		ok(not Collections.where("shipping", "honey").begins_with("Forage"), "honey says where it comes from: %s" % Collections.where("shipping", "honey"))
		# Animal counter: works empty, then with injected data
		var saved := Ranch._data
		Ranch._data = {"species": {}, "buildings": {}, "rules": {}, "products": {}, "processing": {}}
		ok(Shops.animals_for("benno").is_empty(), "no species data: no animal counter")
		Ranch._data = {"species": {"chicken": {"name": "Chicken", "name_gang": "Hen", "home": "coop", "buy": {"seller": "hazel", "price": 400, "tier": 1}},
				"cow": {"name": "Cow", "home": "barn", "buy": {"seller": "Benno", "price": 1500, "tier": 1}},
				"goat": {"name": "Goat", "home": "barn", "buy": {"seller": "benno", "price": 1200, "tier": 2}}},
			"buildings": {"barn": [{"tier": 1, "cap": 1}, {"tier": 2, "cap": 8}]}, "rules": {}, "products": {}, "processing": {}}
		ok(Shops.animals_for("benno") == ["goat", "cow"], "Benno sells barn animals, cheapest first: %s" % str(Shops.animals_for("benno")))
		ok(Shops.animal_why("cow").begins_with("needs"), "no barn yet: %s" % Shops.animal_why("cow"))
		Ranch.st()["houses"]["barn"] = {"tier": 1}
		ok(Shops.animal_why("cow") == "", "barn built: a cow can come home")
		ok(Shops.animal_why("goat").contains("Big Barn"), "goats need the Big Barn: %s" % Shops.animal_why("goat"))
		ok(Ranch.add("cow") != "", "a cow joins")
		ok(Shops.animal_why("cow").contains("full"), "the barn is full: %s" % Shops.animal_why("cow"))
		ok(Shops.animal_name("chicken") == ("Hen" if arc == "gangsters" else "Chicken"), "arc name for the chicken")
		Ranch._data = saved
	print("ranch_p3_test: %s (%d fails)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
