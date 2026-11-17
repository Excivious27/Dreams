extends SceneTree
## The workshop at run time: build and buy stations by tier, queue jobs in
## slots, batch, collect, masterwork, the keg, vehicles, potions, and the
## gangster arc's press, heat, laundromat and training center.
##   godot --headless --path . -s res://tools/station_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _farm() -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = "farm"
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 8:
		await process_frame
	return current_scene as GameMap

func _progress(n: int) -> void:
	var qs := ["clear_meadow", "spark", "sky_stair", "teleporter"] if GameState.is_penguins() else ["clear_meadow", "wastes_gate", "hideout", "uptown"]
	for i in n:
		GameState.run["quests"].append({"id": qs[i], "text": qs[i], "done": true})

func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 30
	# Nothing is free: no station exists until you make or buy it.
	for id in Builds.data():
		if Crafting.is_station(id):
			check(Crafting.own_tier(id) == 0, "%s starts unbuilt" % id)
	check(not Builds.data().has("print_shop") and Builds.all().has("print_shop"), "the press is gangster-only")
	# Build tier 1 from materials.
	GameState.add_item("stone", 20); GameState.add_item("copper", 5)
	check(Builds.blocker("furnace") == "", "furnace I buildable with materials")
	check(not Builds.start("furnace").begins_with("Can't"), "furnace I built")
	check(Crafting.own_tier("furnace") == 1 and GameState.count("stone") == 0, "furnace tier 1, materials spent")
	# Tier 2 waits for the story, then can be bought outright.
	check(Builds.gate("furnace") != "", "furnace II gated (%s)" % Builds.gate("furnace"))
	GameState.run["crystals"] = 100000
	check(Builds.start("furnace", true).begins_with("Can't"), "can't buy past the gate")
	_progress(4)
	GameState.run["skills"]["mining"] = {"level": 9, "xp": 0, "nodes": {}}
	check(Builds.gate("furnace") == "", "furnace II opens with story + skill")
	var before := int(GameState.run["crystals"])
	check(not Builds.start("furnace", true).begins_with("Can't") and Crafting.own_tier("furnace") == 2, "furnace II bought ready-made")
	check(int(GameState.run["crystals"]) == before - int(Builds.tier_def("furnace", 2)["price"]), "the price was paid")
	# Recipes by tier.
	check(Crafting.available("furnace", 1).size() < Crafting.available("furnace", 4).size(), "higher tiers open more recipes")
	var dark: Dictionary = {}
	for rc in GameState.recipes["furnace"]:
		if str(rc["id"]) == "dark_bar":
			dark = rc
	check(Crafting.why_locked("furnace", 2, dark).contains("Blast Furnace"), "locked recipe names the tier it needs (%s)" % Crafting.why_locked("furnace", 2, dark))
	var m: GameMap = await _farm()
	check(m != null, "farm loads with stations")
	var found := false
	for c in m.things:
		if str(m.things[c].get("type", "")) == "station" and str(m.things[c].get("station", "")) == "furnace":
			found = true
	check(found, "the furnace stands on the farm")
	# Jobs: batch, slots, time, collect.
	GameState.run["time"] = 8 * 60
	GameState.add_item("copper", 50); GameState.add_item("coal", 20)
	var bar: Dictionary = GameState.recipes["furnace"][0]
	check(Crafting.max_qty(bar) == 10, "batch size from your pack (%d)" % Crafting.max_qty(bar))
	var t1 := Crafting.minutes_for("furnace", bar, 1, 1)
	check(Crafting.minutes_for("furnace", bar, 4, 1) < t1 and Crafting.minutes_for("furnace", bar, 1, 5) < t1 * 5, "better tiers and batches save time")
	Crafting.start("furnace", "furnace", bar, 2, 5)
	Crafting.start("furnace", "furnace", bar, 2, 5)
	check(Crafting.jobs("furnace").size() == 2 and GameState.count("copper") == 0, "two jobs in two slots, ore taken")
	check(Crafting.collect(m, "furnace", "furnace") == 0, "nothing to collect early")
	GameState.run["time"] = int(GameState.run["time"]) + 600
	check(Crafting.newly_done().size() == 2 and Crafting.newly_done().is_empty(), "told once when jobs finish")
	check(Crafting.collect(m, "furnace", "furnace") == 2 and GameState.count("copper_bar") >= 10, "collected 10+ bars (%d)" % GameState.count("copper_bar"))
	# Masterwork at tier 4.
	GameState.run["inventory"] = {}
	Crafting.jobs("furnace").append({"id": "x", "name": "x", "give": "copper_bar", "n": 200, "batches": 200, "tier": 1, "tool": false, "st": 4, "station": "furnace", "done_at": 0})
	Crafting.collect(m, "furnace", "furnace")
	check(GameState.count("copper_bar") > 215, "tier 4 turns out bonus pieces (%d from 200)" % GameState.count("copper_bar"))
	# The keg takes whatever you grow.
	GameState.run["builds"]["keg"] = 1
	GameState.run["inventory"] = {"blueberry": 2, "beet": 1, "stone": 5}
	var kr := Crafting.available("keg", 1)
	check(kr.size() == 2, "keg offers a brew per kind of produce (%d)" % kr.size())
	var j := Crafting.start("keg", "keg", kr[0], 1, 1)
	check(int(j["done_at"]) - Crafting.now_abs() >= 1440, "brews take days, not minutes")
	# Vehicles.
	GameState.add_item("scooter", 1)
	check(m.use_consumable("scooter") and m.player.vehicle == "scooter", "USE rides the scooter")
	check(m.use_consumable("scooter") and m.player.vehicle == "", "USE again hops off")
	check(GameState.gift_value("maple", "scooter") <= 8 and "vehicle" in GameState.NO_GIFT_TYPES, "vehicles aren't gifts")
	# Growth elixir.
	GameState.run["farm"]["40,40"] = {"crop": "turnip", "days": 0, "watered": false}
	GameState.add_item("growth_elixir", 1)
	m.use_consumable("growth_elixir")
	check(int(GameState.run["farm"]["40,40"]["days"]) == 1 and GameState.count("growth_elixir") == 0, "growth elixir grows the farm a day")
	# Town benches follow the keeper's friendship.
	GameState.run["friendship"]["gideon"] = 0
	var tt0 := Crafting.town_tier("anvil")
	GameState.run["friendship"]["gideon"] = GameState.HEART_POINTS * 6
	check(tt0 == 1 and Crafting.town_tier("anvil") == 3, "Gideon's forge grows with his friendship")
	# Rocket: tier 3 flies, with a beacon and fuel.
	check(Builds.all()["launchpad"]["tiers"].size() == 4, "rocket yard has four stages")

	# ---- penguin arc's own -----------------------------------------------------
	check(Builds.data().has("shaper") and Builds.data().has("litter") and Builds.data().has("campfire") and Builds.data().has("pool") and Builds.data().has("burrow") and Builds.data().has("shrine"), "the sanctuary is on the penguin plans")
	check(not Builds.data().has("armory"), "no street armory for penguins")
	check(GameState.is_sword("icicle_blade") and int(GameState.items["starheart_blade"]["damage"]) == int(GameState.items["neon_cleaver"]["damage"]), "crystal weapons match the street ones")
	var r0 := Companion.meow_rank()
	GameState.run["builds"]["shrine"] = 3
	check(Companion.meow_rank() == r0 + 2, "the shrine adds Meow Pow Wow ranks (%d → %d)" % [r0, Companion.meow_rank()])
	GameState.run["builds"]["pool"] = 2
	GameState.run["builds"]["burrow"] = 1
	GameState.run["gifts"] = {}
	var prep := GameState.sleep()
	var gp: Dictionary = GameState.run["gifts"]
	check(int(prep.get("left", 0)) >= 8 and not (gp.get("pool", {}) as Dictionary).is_empty() and not (gp.get("burrow", {}) as Dictionary).is_empty(), "pool and burrow leave gifts overnight (%d)" % int(prep.get("left", 0)))
	m = await _farm()
	GameState.run["inventory"] = {}
	await Sanctuary.collect(m, "burrow")
	check(not (GameState.run["inventory"] as Dictionary).is_empty() and (GameState.run["gifts"]["burrow"] as Dictionary).is_empty(), "collecting empties the burrow basket")
	check(float(GameState.items["mega_litter"]["radius"]) > float(GameState.items["litter_box"]["radius"]), "bigger litter boxes reach further")

	# ---- gangster arc --------------------------------------------------------
	GameState.new_run("gangsters", "dad", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	check(Builds.data().has("print_shop") and Builds.data().has("training") and Builds.data().has("laundromat") and Builds.data().has("armory") and Builds.data().has("soda"), "the operation is on the gangster plans")
	var names: Array = []
	for rc in Crafting.available("garage", 4):
		names.append(str(rc["id"]))
	GameState.run["skills"]["building"] = {"level": 9, "xp": 0, "nodes": {}}
	names.clear()
	for rc in Crafting.available("garage", 4):
		names.append(str(rc["id"]))
	check("getaway_car" in names and "crystal_sled" not in names, "arc vehicles: getaway car yes, sled no (%s)" % str(names))
	check(GameState.is_sword("crowbar") and int(GameState.items["neon_cleaver"]["damage"]) > int(GameState.items["crystal_sword"]["damage"]), "street weapons swing like swords")
	check(Racket.risk("bills_crude") > Racket.risk("bills_perfect"), "better bills are safer")
	GameState.run["heat"] = 4
	check(Racket.risk("bills_crude") > 0.45, "heat makes every bill riskier")
	m = await _farm()
	GameState.run["builds"] = GameState.run.get("builds", {})
	GameState.add_item("bills_crude", 1)
	m.use_consumable("bills_crude")
	check(GameState.count("bills_crude") == 1, "bills can't be passed on your own farm")
	GameState.run["builds"]["laundromat"] = 1
	GameState.run["wash"] = {"bills_crude": 3}
	var c0 := int(GameState.run["crystals"])
	var rep := GameState.sleep()
	check(int(GameState.run["crystals"]) - c0 >= 168 and int(rep.get("washed", 0)) == 168, "the wash pays 80%% overnight (%d)" % int(rep.get("washed", 0)))
	check(Racket.heat() == 2, "heat cools two a night with a laundromat (%d)" % Racket.heat())
	GameState.run["flags"]["crew_vic"] = true
	var p0 := Crew.perk_level("sword")
	GameState.run["builds"]["training"] = 2
	check(Crew.perk_level("sword") == mini(3, p0 + 1), "the training hall lifts crew perks (%d → %d)" % [p0, Crew.perk_level("sword")])
	print("station_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
