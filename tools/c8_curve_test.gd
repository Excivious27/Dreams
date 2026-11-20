extends SceneTree
## CONDUCT 8 P1: the core curves (headless, GameState API only).
##   godot --headless --path . -s res://tools/c8_curve_test.gd [-- verbose]
## Level curve (shape, MAX_LEVEL, multi-level grants, full trees), per-level
## effect caps, total tree hp/energy caps, passive max energy, the smooth swing
## table (every tool tier shaves swings), food that would do nothing is kept,
## heat wave, shop floor vs sell perks, quality bonus = box preview, late bed,
## bank interest, faint at home. Prints a pacing table (levels at day 28/112/336
## for steady daily XP) so balance changes show up in CI logs.

var fails := 0
var verbose := false


func _ok(cond: bool, what: String) -> void:
	if not cond:
		print("  FAIL ", what)
		fails += 1
	elif verbose:
		print("  ok   ", what)


func _initialize() -> void:
	verbose = "verbose" in OS.get_cmdline_user_args()
	seed(8)
	GameState.load_data()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	_curve()
	_multi_level()
	_full_tree()
	_caps()
	_swings()
	_food()
	_prices()
	_sleep_bits()
	_helpers()
	print("c8_curve_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _fresh() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true


func _curve() -> void:
	var early := [40, 70, 100, 130, 160, 190, 220, 250, 280, 310, 340, 370]
	for i in early.size():
		_ok(GameState.xp_for_next(i + 1) == int(early[i]), "early curve unchanged at level %d" % (i + 1))
	_ok(GameState.xp_for_next(13) == 400, "level 13 costs 400")
	var prev := 400
	for l in range(14, GameState.MAX_LEVEL):
		var x := GameState.xp_for_next(l)
		_ok(x >= prev, "curve never drops (level %d: %d)" % [l, x])
		prev = x
	_ok(GameState.xp_for_next(60) > 1200, "the curve keeps climbing past 13 (level 60: %d)" % GameState.xp_for_next(60))
	# Pacing table: steady XP a day (days in a year = 112).
	print("  pacing (level reached with steady XP/day): xp/day | d28 | d112 | d224 | d336")
	for per_day in [120, 420, 900]:
		var row := [per_day]
		var lv := 1
		var xp := 0
		for d in range(1, 337):
			xp += per_day
			while lv < GameState.MAX_LEVEL and xp >= GameState.xp_for_next(lv):
				xp -= GameState.xp_for_next(lv)
				lv += 1
			if d in [28, 112, 224, 336]:
				row.append(lv)
		print("    %4d | %3d | %3d | %3d | %3d" % row)
		if per_day == 420:
			_ok(int(row[2]) < 70, "a steady farmer is not near the cap at the end of year 1 (lv %d, was 124)" % int(row[2]))
			_ok(int(row[4]) >= 60, "...but gets most of the way by year 3 (lv %d)" % int(row[4]))


func _multi_level() -> void:
	_fresh()
	GameState.add_xp("combat", 40 + 70 + 100 + 130)
	_ok(GameState.skill_level("combat") == 5 and GameState.last_levels == 4, "one big grant: 4 levels (lv %d, %d)" % [GameState.skill_level("combat"), GameState.last_levels])
	_ok(GameState.last_crossed5, "crossing level 5 is flagged for the big fanfare")
	_ok("4 skill points" in GameState.level_up_text("combat"), "plural points line: %s" % GameState.level_up_text("combat"))
	# The cap: XP stops, the level stays, the words say mastered.
	GameState.run["skills"]["combat"]["level"] = GameState.MAX_LEVEL - 1
	GameState.add_xp("combat", 999999)
	_ok(GameState.skill_level("combat") == GameState.MAX_LEVEL and int(GameState.run["skills"]["combat"]["xp"]) == 0, "MAX_LEVEL stops levelling")
	_ok(not GameState.add_xp("combat", 5000), "no level-ups past the cap")
	_ok("mastered" in GameState.level_up_text("combat"), "mastered line at the cap")
	GameState.run["skills"]["farming"] = {"level": 300, "xp": 0, "nodes": {}}
	_ok(GameState.skill_level("farming") == GameState.MAX_LEVEL, "old runaway saves read as MAX_LEVEL")


func _full_tree() -> void:
	_fresh()
	var nodes := {}
	for n in GameState.nodes_of("farming"):
		nodes[str(n["id"])] = int(n.get("ranks", 1))
	GameState.run["skills"]["farming"] = {"level": GameState.MAX_LEVEL, "xp": 0, "nodes": nodes}
	_ok(GameState.ranks_left("farming") == 0, "every farming rank bought")
	_ok(GameState.points_free("farming") == 0, "a full tree has no points to spend (was level-1-spent)")
	_ok(not ("skill point" in GameState.level_up_text("farming")), "no 'skill point to spend' on a full tree")
	nodes.erase(nodes.keys()[0])
	_ok(GameState.points_free("farming") >= 1 and GameState.points_free("farming") <= GameState.ranks_left("farming"), "points never exceed ranks left")


func _caps() -> void:
	_fresh()
	var base_en := int(GameState.run["max_energy"])
	for sk in GameState.skills_data.keys():
		var nodes := {}
		for n in GameState.nodes_of(str(sk)):
			nodes[str(n["id"])] = int(n.get("ranks", 1))
		GameState.run["skills"][str(sk)] = {"level": GameState.MAX_LEVEL, "xp": 0, "nodes": nodes}
	GameState._apply_max_stats()
	var en := int(GameState.run["max_energy"])
	var hp := int(GameState.run["max_hp"])
	print("  maxed everything (no gear): max energy %d (start %d), max hp %d, mana %d" % [en, base_en, hp, int(GameState.run["max_mana"])])
	_ok(en <= base_en + GameState.level_energy(999) + GameState.TREE_EN_CAP + 40 + 70, "max energy with every tree full stays bounded (%d, was ~620)" % en)
	_ok(hp <= 100 + 8 * (GameState.LEVEL_EFFECT_CAP - 1) + GameState.TREE_HP_CAP + 20, "max hp with every tree full stays bounded (%d, was ~1460)" % hp)
	_ok(GameState.level_energy(12) <= 20, "passive energy at 12 summed levels (week 1) is small (+%d, was +36)" % GameState.level_energy(12))
	_ok(GameState.player_tier() <= 3 + int(GameState.gear_stat("defense") * 0.4), "levels alone don't make you top tier")
	_ok(GameState.skill_level_eff("magic") == GameState.LEVEL_EFFECT_CAP, "per-level effects stop at LEVEL_EFFECT_CAP")


func _swings() -> void:
	_fresh()
	var tiers: Dictionary = GameState.run.get("tool_tier", {})
	GameState.run["tool_tier"] = tiers
	var tree: Array = []
	var stone: Array = []
	var ore: Array = []
	for t in 8:
		tiers["axe"] = t
		tiers["pickaxe"] = t
		tree.append(GameState.hits_for(4, "axe"))
		stone.append(GameState.hits_for(2, "pickaxe"))
		ore.append(GameState.hits_for(4, "pickaxe"))
	print("  swings by tool tier (level 1): tree %s, stone %s, ore %s" % [str(tree), str(stone), str(ore)])
	_ok(int(tree[0]) == 7, "starter axe: 7 swings a tree (C6 P7 pace kept)")
	_ok(int(tree[1]) == 5 and int(tree[2]) == 4 and int(tree[3]) == 3, "copper/iron/steel axe each shave a swing (%s)" % str(tree))
	for t in range(1, 8):
		_ok(int(tree[t]) <= int(tree[t - 1]) and int(ore[t]) <= int(ore[t - 1]), "tier %d never worse than tier %d" % [t, t - 1])
	_ok(int(ore[1]) < int(ore[0]) and int(ore[2]) < int(ore[1]), "copper and iron picks both cut ore swings (%s)" % str(ore))
	_ok(int(stone[0]) == 3 and int(stone[1]) == 2, "stone: 3 swings with wood, 2 with copper (no copper one-shot)")
	tiers["axe"] = 0
	GameState.run["skills"]["foraging"] = {"level": 6, "xp": 0, "nodes": {}}
	_ok(GameState.hits_for(4, "axe") == 6, "foraging level 6 shaves one swing (%d)" % GameState.hits_for(4, "axe"))
	# toughen + the callers' own subtraction lands on exactly hits_for swings.
	tiers["axe"] = 2
	var th := {"type": "tree", "hp": 4}
	var want := GameState.hits_for(4, "axe")
	GameState.toughen(th, "axe", 3)
	var n := 0
	while int(th["hp"]) > 0 and n < 50:
		th["hp"] = int(th["hp"]) - GameState.swing_damage("axe")
		n += 1
	_ok(n == want, "real swings match hits_for (%d vs %d)" % [n, want])


func _food() -> void:
	_fresh()
	var r := GameState.run
	var potion := ""
	var bread := ""
	var treat := ""
	for id in GameState.items:
		var it: Dictionary = GameState.items[id]
		if potion == "" and str(it.get("type", "")) == "potion" and int(it.get("heal", 0)) > 0 and not it.has("energy") and not it.has("buff") and not it.has("mana"):
			potion = str(id)
		if id == "bread":
			bread = "bread"
		if treat == "" and it.has("pet_heal") and int(it.get("heal", 0)) <= 0 and int(it.get("energy", 0)) <= 0 and not it.has("buff"):
			treat = str(id)
	r["hp"] = int(r["max_hp"])
	r["energy"] = int(r["max_energy"]) - 30
	if potion != "":
		GameState.add_item(potion, 1)
		var out := GameState.consume(potion)
		_ok(out.keys() == ["full"] and GameState.count(potion) == 1 and GameState.last_full_why == "hp", "a potion at full health is kept (%s)" % str(out))
		_ok("full health" in GameState.full_text(), "...and says so")
	if treat != "":
		GameState.add_item(treat, 1)
		GameState.consume(treat)
		_ok(GameState.count(treat) == 1 and GameState.last_full_why == "pup", "pup food is not eaten by the player (%s)" % treat)
	if bread != "":
		GameState.add_item(bread, 2)
		r["energy"] = int(r["max_energy"])
		GameState.consume(bread)
		_ok(GameState.count(bread) == 2 and GameState.last_full_why == "topped", "bread at a full bar: kept, 'already full'")
		r["energy"] = 10
		r["fed_en"] = int(r["max_energy"])
		GameState.consume(bread)
		_ok(GameState.count(bread) == 2 and GameState.last_full_why == "cap", "bread past the daily food cap: kept, 'eaten all you can'")
		r["fed_en"] = 0
		var out2 := GameState.consume(bread)
		_ok(GameState.count(bread) == 1 and int(out2.get("energy", 0)) > 0, "bread with room is eaten")
	_ok(GameState.in_the_heat(), "no map (headless): the heat applies")


func _prices() -> void:
	_fresh()
	var id := "healing_potion" if GameState.items.has("healing_potion") else "bread"
	var novice := GameState.buy_price(id)
	# Max sell perks: Bartering level, Alder 8 hearts.
	GameState.run["skills"]["bartering"] = {"level": 20, "xp": 0, "nodes": {}}
	GameState.run["friendship"]["alder"] = 250
	GameState.run["friendship"]["maple"] = 250
	var expert := GameState.buy_price(id)
	_ok(expert <= novice, "an expert never pays more than a novice (%s: %d vs %d)" % [id, expert, novice])
	# A fence dump doesn't make the shop price drop for the day.
	var before := GameState.buy_price(id)
	GameState.run["sold_today"] = {id: 60}
	_ok(GameState.buy_price(id) == before, "today's saturation doesn't move shop prices (%d vs %d)" % [GameState.buy_price(id), before])
	GameState.run["sold_today"] = {}
	_ok(GameState.buy_price(id) >= int(floor(GameState.item_value(id) * GameState.SHOP_FLOOR * 0.99)), "shop price stays at or above the bare sale value")


func _sleep_bits() -> void:
	_fresh()
	var r := GameState.run
	# Quality bonus: the morning pays what the box preview promised.
	var crop := "strawberry" if GameState.items.has("strawberry") else "turnip"
	r["sellbox"] = {crop: 30}
	r["sellbox_q"] = {crop: {"g": 10, "s": 0}}
	r["sold_today"] = {}
	var promised := GameState.sell_price(crop, 30) + GameState.quality_bonus_value({crop: {"g": 10, "s": 0}})
	r["time"] = 20 * 60
	var rep := GameState.sleep()
	_ok(absi(int(rep["earned"]) - promised) <= 1 or "Lucky" in str(rep["sold"]), "morning pays the box preview (%d vs %d)" % [int(rep["earned"]), promised])
	_ok(is_equal_approx(GameState.late_wake_mult(23 * 60), 1.0) and GameState.late_wake_mult(26 * 60) <= 0.851, "late bed: full before midnight, 85% at 2am")
	r["bank"] = 5000
	_ok(GameState.bank_interest() == 0, "no bank interest before Ivy 2 hearts")
	r["friendship"]["ivy"] = 50
	_ok(GameState.bank_interest() == mini(50, GameState.bank_interest_cap()), "1%% capped from Ivy 2 hearts (%d)" % GameState.bank_interest())
	var e0 := int(r.get("earned_total", 0))
	r["time"] = 20 * 60
	GameState.sleep()
	_ok(int(r.get("earned_total", 0)) > e0 and int((r.get("earned_by", {}) as Dictionary).get("bank", 0)) > 0, "bank interest counts as earned")
	_ok("floor" in Faint.home_note(false, 0, true), "collapsing at home: no 'carried home' line")
	r["day"] = 20
	r["crystals"] = 1000
	_ok(Faint.fee(false, 0) == 50, "away from home the 5% still goes missing (headless: no map)")


func _helpers() -> void:
	_fresh()
	_ok(GameState.food_line("bread").contains("energy"), "bread shows its energy (%s)" % GameState.food_line("bread"))
	GameState.run["sellbox"] = {}
	GameState.run["sold_today"] = {}
	_ok(not GameState.saturating("turnip", 5), "5 turnips: full price")
	_ok(GameState.saturating("turnip", 30), "30 turnips: saturating")
	_ok(not GameState.ship_log("turnip", 1) or ResourceLoader.exists("res://scripts/collections.gd"), "ship log is a no-op without Collections")
