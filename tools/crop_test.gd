extends SceneTree
## Every crop is wired into the rest of the game: a seed you can buy or find,
## produce that exists, a family, a keg brew, growth to ripeness in season,
## recipes that resolve, family gifts, wild seed packets, board orders.
##   godot --headless --path . -s res://tools/crop_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	var seed_of := {}
	for sid in GameState.items:
		var it: Dictionary = GameState.items[sid]
		if str(it.get("type", "")) == "seed":
			check(GameState.crops.has(str(it.get("crop", ""))), "seed %s has a crop" % sid)
			seed_of[str(it.get("crop", ""))] = str(sid)
	# Which seeds some shop sells in some season at full progress.
	var sold := {}
	# Late game: every progress gate passed, the Networker perk bought.
	for q in ["clear_meadow", "spark", "sky_stair", "teleporter"]:
		GameState.run["quests"].append({"id": q, "text": q, "done": true})
	var bt: Dictionary = GameState.run.get("tree_ranks", {})
	GameState.run["tree_ranks"] = bt
	for se_i in 4:
		GameState.run["day"] = 1 + se_i * 28
		for d in 28:
			GameState.run["day"] = 1 + se_i * 28 + d
			for shop in ["store", "tam", "old_moss", "sel", "catkins"]:
				for id in Shops.offers(shop):
					sold[str(id)] = true
	var fams := GameState.FAMILY_NAMES
	for cid in GameState.crops:
		var cd: Dictionary = GameState.crops[cid]
		var y := str(cd.get("yield", ""))
		check(GameState.items.has(y), "%s yields a real item (%s)" % [cid, y])
		check(fams.has(str(cd.get("family", ""))), "%s has a family" % cid)
		check(GameState.family(y) != "", "%s produce %s carries a family" % [cid, y])
		check(seed_of.has(cid), "%s has a seed" % cid)
		check(GameState.keg_brew(y) != "" and GameState.items.has(GameState.keg_brew(y)), "%s brews in the keg" % y)
		check(int(cd.get("days", 0)) >= 2 and int(cd.get("days", 0)) <= 22, "%s grows in 2-22 days" % cid)
		check(sold.has(str(seed_of.get(cid, ""))) or cid in ["melon", "grape", "lotus", "moon_melon", "dreamflower", "flax", "tea_leaf", "hops", "cotton", "ghost_pepper"], "%s seed is sold somewhere" % cid)
		# Grows to ripe in season, watered every night.
		var se := str(cd.get("season", "any"))
		var start := 1 + maxi(0, GameState.SEASONS.find(se)) * 28
		GameState.run["day"] = start
		GameState.run["farm"] = {"20,20": {"crop": cid, "days": 0, "watered": true}}
		var n := 0
		while int(GameState.run["farm"]["20,20"].get("days", 0)) < int(cd["days"]) and n < 30:
			GameState.run["farm"]["20,20"]["watered"] = true
			GameState.sleep()
			n += 1
		check(str(GameState.run["farm"]["20,20"].get("crop", "")) == cid and n <= int(cd["days"]) + 1, "%s ripens in season (%d nights)" % [cid, n])
	# Recipes resolve (items or families).
	for st in GameState.recipes:
		for rc in GameState.recipes[st]:
			for k in rc.get("need", {}):
				var key := str(k)
				check(GameState.items.has(key) or (key.begins_with("#") and fams.has(key.substr(1))), "recipe %s needs a real thing (%s)" % [str(rc.get("id")), key])
			check(GameState.items.has(str(rc.get("give", ""))), "recipe %s gives a real item" % str(rc.get("id")))
	# Family needs count and take cheapest first.
	GameState.run["inventory"] = {"beet": 2, "eggplant": 2}
	check(GameState.count_any("#veg") == 4, "count_any #veg")
	GameState.take_any("#veg", 3)
	check(GameState.count("eggplant") == 1 and GameState.count("beet") == 0, "take_any takes the cheapest first")
	# Family likes.
	check(GameState.gift_value("posy", "raspberry") >= 12, "Posy likes any berry")
	check(GameState.gift_value("tam", "pear") >= 12, "Tam likes orchard fruit")
	# Trees rest in winter instead of dying.
	GameState.run["day"] = 3 * 28 + 2
	GameState.run["farm"] = {"20,20": {"crop": "apple", "days": 3, "watered": true}}
	GameState.sleep()
	check(str(GameState.run["farm"]["20,20"].get("crop", "")) == "apple" and int(GameState.run["farm"]["20,20"]["days"]) == 3, "apple tree dormant in winter, not dead")
	# Wild seed packets have something every season.
	for i in 4:
		GameState.run["day"] = 1 + i * 28
		check(GameState.random_season_seed(2) != "", "a wild seed in season %d" % i)
	# The board has a crop order.
	GameState.run["board"] = {}
	GameState.run["day"] = 40
	var has_crop := false
	for j in GameState.board_today():
		if GameState.family(str(j["item"])) != "":
			has_crop = true
	check(has_crop, "the board posts a crop order")
	print("crop_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
