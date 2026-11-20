extends SceneTree
## C8 P6: shops, prices and money sinks. Shop floors never rise with perks or
## dumps, the community stand can't be looped, market sales count once with their
## stars, seed lines carry what the crop does, money groups its digits, Gideon's
## jobs are day-based with a rush fee, Ivy's bank says its real terms, mountain
## rocks regrow on a clock.
##   godot --headless --path . -s res://tools/shop_econ_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(8)
	_run.call_deferred()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	var sample := ["copper", "coal", "potion", "energy_tea", "bread", "turnip_seed", "fertilizer", "iron_sword"]
	var novice := {}
	for id: String in sample:
		novice[id] = GameState.buy_price(id)
		check(novice[id] >= int(GameState.item_value(id) * 1.15), "%s: novice price %d is above its value" % [id, novice[id]])

	# Saturation-free floor: dumping a stack never cheapens the shop.
	GameState.run["sold_today"] = {"copper": 80}
	check(GameState.buy_price("copper") == int(novice["copper"]), "copper price ignores today's dump (%d vs %d)" % [GameState.buy_price("copper"), novice["copper"]])
	GameState.run["sold_today"] = {}

	# Perks: friends and selling perks never raise a price; Maple's discount still lowers.
	GameState.add_friend("maple", 250)
	GameState.add_friend("alder", 250)
	for id: String in sample:
		var p := GameState.buy_price(id)
		check(p <= int(novice[id]), "%s: %d with perks is not above the novice %d" % [id, p, novice[id]])
		check(float(p) >= GameState.unit_sell_value(id), "%s: %d never under its sell price %.1f (no loop)" % [id, p, GameState.unit_sell_value(id)])
	check(GameState.buy_price("iron_sword") < int(novice["iron_sword"]), "Maple 8 hearts still discounts something")

	# Community stand: buy price is above what the market pays, donations go to the pantry.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	for id: String in ["turnip", "pumpkin", "strawberry", "corn"]:
		if GameState.items.has(id):
			check(Commons.stand_price(id) > Commons.market_pay(id, 1), "%s: stand %d above market pay %d" % [id, Commons.stand_price(id), Commons.market_pay(id, 1)])
	GameState.add_item("pumpkin", 10, true)
	Commons.donate("pumpkin", 10)
	check(int(Commons.st()["stock"].get("pumpkin", 0)) == 0 and int(Commons.st()["pantry"].get("pumpkin", 0)) == 10, "donations go to the pantry, not on sale")
	Commons.overnight({})
	check(int(Commons.st()["pantry"].get("pumpkin", 0)) < 10, "neighbours take from the pantry overnight")

	# Market sale: counted once, saturation remembered, stars paid.
	GameState.add_item("turnip", 10, true)
	var plain := Commons.market_pay("turnip", 10)
	GameState.add_quality("turnip", "g", 5)
	var starred := Commons.market_pay("turnip", 10)
	check(starred > plain, "gold turnips earn more at the market (%d vs %d)" % [starred, plain])
	var e0 := int(GameState.run.get("earned_total", 0))
	var c0 := int(GameState.run["crystals"])
	var pay := Commons.sell_at_market("turnip", 10)
	check(int(GameState.run["crystals"]) - c0 == pay and int(GameState.run.get("earned_total", 0)) - e0 == pay, "market pay counted once (%d)" % pay)
	check(int(GameState.run.get("sold_today", {}).get("turnip", 0)) == 10, "market sales count toward saturation")
	check(int(GameState.quality_of("turnip").get("g", 0)) == 0, "sold gold pieces leave the bag's stars")

	# Seed shop lines.
	var ln := Shops.line("strawberry_seed")
	check(ln.contains("sells") and ln.contains("again"), "strawberry line shows sell value and regrowth: %s" % ln)
	check(not Shops.line("turnip_seed").contains("Seeds"), "seed line drops 'Seeds' from the name")
	check(Shops.grown("smith").is_empty(), "Gideon's later stock waits for progress")

	# Money grouping, both arcs.
	check(Money.group(1234567) == "1,234,567" and Money.group(999) == "999" and Money.group(-1000) == "-1,000", "digit grouping")
	check(Money.fmt(25000) == "◆25,000", "crystal fmt groups")
	check(Money.to_cash("Earned 12,500 crystals.") == "Earned $12,500.", "cash conversion keeps grouped amounts: %s" % Money.to_cash("Earned 12,500 crystals."))

	# Gideon: day-based jobs and a rush fee; Ivy's bank terms.
	var interior: Variant = load("res://scripts/interior.gd")
	GameState.run["day"] = 6
	GameState.run["time"] = 8 * 60
	check(int(interior.upgrade_ready_at(1)) == 7 * 1440 + GameState.DAY_START, "copper upgrade ready next morning")
	check(int(interior.upgrade_ready_at(3)) == 8 * 1440 + GameState.DAY_START, "steel upgrade ready in two mornings")
	check(int(interior.rush_fee(2)) > int(interior.rush_fee(1)) and int(interior.rush_fee(7)) >= 10000, "rush fee scales")
	check(str(interior.UPGRADE_XP.get("hoe", "")) == "farming" and str(interior.UPGRADE_XP.get("pickaxe", "")) == "mining", "upgrade XP goes to the tool's skill")
	check(str(interior.bank_terms(3000)).begins_with("No interest yet"), "bank says no interest before Ivy 2 hearts")
	GameState.add_friend("ivy", 60)
	check(str(interior.bank_terms(8000)).contains("up to"), "bank shows its cap: %s" % str(interior.bank_terms(8000)))

	# Mountain rocks: regrow clock and pick damage.
	var mountain: Variant = load("res://scripts/mountain.gd")
	check(int(mountain.mrock_regrow("stone")) < int(mountain.mrock_regrow("iron")), "ore rocks take longer to come back")
	check(int(mountain.pick_damage()) >= 1, "pick damage")

	# Shared stall pricing: never under the resale floor, discounts on the listed price.
	check(Shops.stall_price("energy_tea", 12) == GameState.shop_price("energy_tea", 12), "stall price floors like shop_price")
	check(Shops.stall_price("potion", 1000, 0.5) == GameState.shop_price("potion", 500), "stall discount on the listed price")

	# The Valley Fund: a repeatable late sink with marks and friendship.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(Shops.fund_next() == 0, "fund starts at its first mark")
	check(Shops.fund_add(4999).is_empty(), "no project below the mark")
	var got := Shops.fund_add(1)
	check(got == [0] and GameState.run["flags"].has("fund_lamps"), "first project paid at 5,000")
	check(Shops.fund_next() == 1, "fund moves to the next mark")
	check(Shops.fund_add(1000000).size() == Shops.FUND.size() - 1 and Shops.fund_next() == -1, "a big gift completes the rest once")
	check(Shops.fund_add(10).is_empty(), "no project twice")
	check(Shops.fund_status() == "complete", "fund status complete")
	GameState.run["arc"] = "gangsters"
	check(Shops.fund_name() == "Neighbourhood Fund", "gangster fund name")
	Racket.set_heat(3)
	GameState.run["crystals"] = 100000
	var fee := Shops.file_fee()
	Shops.lose_file()
	check(Racket.heat() == 2 and int(GameState.run["crystals"]) == 100000 - fee, "lose a file: heat -1 for its fee")
	Shops.lose_file()
	check(Racket.heat() == 2, "one file a day")

	print("shop_econ_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
