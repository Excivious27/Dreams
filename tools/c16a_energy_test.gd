extends SceneTree
## C16a P3 energy fixes: day-1 costs (pickaxe 0.45, no early x1.15 off the field,
## dodge 0.5, sword 0.12), tree perks inside the 0.35 floor, axe/pickaxe tiers 3%,
## Keeper of the Woods halves chopping, eaten-growth caps (stamina_root) and growth
## refilling only what it adds, buff merge (a weaker buff never overwrites), the
## stamina buff (coffee/tea), food/rest caps that don't grow with the bar and scale
## with day length, keeper waits capped on floors 1-3, the floor-1 miner's bench,
## pass-out floors, spar/teach through spend_for, en_log.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/c16a_energy_test.gd

var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(1616)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _nodes(sk: String, id: String, n: int) -> void:
	GameState.run["skills"][sk]["nodes"][id] = n
	GameState._bonus_cache.clear()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	var r := GameState.run
	# 1. Day-1 costs.
	check(is_equal_approx(GameState.energy_cost_f("pickaxe"), 0.45), "day-1 pickaxe swing 0.45 (was 0.69): %.3f" % GameState.energy_cost_f("pickaxe"))
	check(is_equal_approx(GameState.energy_cost_f("hoe"), 0.8 * 1.15), "field work keeps the early x1.15 (hoe %.3f)" % GameState.energy_cost_f("hoe"))
	check(is_equal_approx(GameState.energy_cost_f("axe"), 1.0), "axe has no early factor (%.3f)" % GameState.energy_cost_f("axe"))
	check(GameState.energy_cost_f("dodge") < GameState.energy_cost_f("pickaxe") * 1.2 and is_equal_approx(GameState.energy_cost_f("dodge"), 0.5), "dodge 0.5, no longer far above a swing")
	check(is_equal_approx(GameState.energy_cost_f("sword"), 0.12), "sword 0.12")
	# 2. Perks fold inside the floor.
	_nodes("mining", "iron_will", 3)
	check(is_equal_approx(GameState.bonus("mining", "mine_energy"), 0.15), "Iron Will x3 = 15%% (was 45%%): %.2f" % GameState.bonus("mining", "mine_energy"))
	r["tool_tier"] = r.get("tool_tier", {})
	r["tool_tier"]["pickaxe"] = 7
	r["skills"]["mining"]["level"] = 20
	var lo := GameState.energy_cost_f("pickaxe")
	check(lo >= 0.45 * GameState.ENERGY_FLOOR - 0.0001, "late pickaxe swing never below the 35%% floor (%.3f >= %.3f)" % [lo, 0.45 * GameState.ENERGY_FLOOR])
	r["tool_tier"]["pickaxe"] = 1
	r["skills"]["mining"]["level"] = 1
	_nodes("mining", "iron_will", 0)
	check(is_equal_approx(GameState.energy_cost_f("pickaxe"), 0.45 * 0.97), "a pickaxe tier saves 3%% a swing (%.4f)" % GameState.energy_cost_f("pickaxe"))
	r["tool_tier"]["pickaxe"] = 0
	_nodes("foraging", "keeper_of_the_woods", 1)
	check(is_equal_approx(GameState.energy_cost_f("axe"), 0.5), "Keeper of the Woods halves chopping (%.2f, was free)" % GameState.energy_cost_f("axe"))
	_nodes("foraging", "keeper_of_the_woods", 0)
	# 3. Stamina buff.
	var base_h := GameState.energy_cost_f("pickaxe")
	r["energy"] = 50
	GameState.add_item("coffee", 2)
	GameState.consume("coffee")
	check(GameState.buff("stamina") == 1.0, "coffee gives the stamina buff")
	check(is_equal_approx(GameState.energy_cost_f("pickaxe"), base_h * 0.9), "stamina buff: -10%% a swing (%.3f)" % GameState.energy_cost_f("pickaxe"))
	# 4. Buff merge: a weaker/shorter luck buff doesn't replace a stronger one.
	r["buffs"]["luck"] = {"until": GameState.now_abs() + 300, "amount": 2.0}
	var weak := ""
	for id in GameState.items:
		var b: Variant = GameState.items[id].get("buff")
		if b is Dictionary and str(b.get("kind", "")) == "luck" and float(b.get("amount", 1)) < 2.0 and int(b.get("minutes", 120)) < 300 and not GameState.items[id].has("grow"):
			weak = str(id)
			break
	if weak != "":
		GameState.add_item(weak, 1)
		r["hp"] = int(r["max_hp"]) - 1
		GameState.consume(weak)
		check(GameState.buff("luck") == 2.0, "a weaker luck food (%s) keeps the stronger buff" % weak)
	else:
		check(true, "no weaker luck food in data (merge rule untested here)")
	# 5. Tonic cap + growth refills only what it adds.
	r["energy"] = 10
	var m0 := int(r["max_energy"])
	GameState.add_item("stamina_root", 10)
	GameState.consume("stamina_root")
	check(int(r["max_energy"]) == m0 + 10 and int(r["energy"]) == 20, "stamina root: +10 max, +10 now (no full refill): %d/%d" % [int(r["energy"]), int(r["max_energy"])])
	for i in 6:
		GameState.consume("stamina_root")
	check(int(r["max_energy"]) == m0 + int(GameState.TONIC_CAP["energy"]), "eaten max-energy growth stops at +%d (%d)" % [int(GameState.TONIC_CAP["energy"]), int(r["max_energy"]) - m0])
	check(GameState.consume_blocked("stamina_root") == "tonic" and GameState.count("stamina_root") > 0, "past the cap the root is kept (%s)" % GameState.consume_blocked("stamina_root"))
	# 6. Recovery caps don't grow with the bar; day length scales them.
	r["max_energy"] = 400
	check(GameState.food_cap() == 120, "food cap 120 at farming 1 even on a 400 bar (%d)" % GameState.food_cap())
	check(GameState.rest_cap() == 100, "rest cap tops out at 100 (%d)" % GameState.rest_cap())
	r["day_len"] = 40
	check(GameState.food_cap() == 168 and GameState.rest_cap() == 150, "40-minute day: food x1.4, rest x1.5 (%d, %d)" % [GameState.food_cap(), GameState.rest_cap()])
	r["day_len"] = 15
	GameState.refresh_stats()
	# 7. en_log, spar/teach through spend_for.
	r["energy"] = 5
	r["en_log"] = {}
	check(GameState.spend_for("spar"), "spar works below its cost (works until 0)")
	check(float(r["en_log"].get("spar", 0.0)) > 0.0, "en_log records today's spend by task")
	check(GameState.ENERGY_COST.has("teach") and GameState.ENERGY_SKILL.get("teach", "") == "ranching", "teach is a ranching-discounted action")
	GameState.sleep(true)
	check(int(r["energy"]) == int(int(r["max_energy"]) * 0.75), "pass-out morning 75%% (%d/%d)" % [int(r["energy"]), int(r["max_energy"])])
	check((r.get("en_log", {}) as Dictionary).is_empty(), "en_log resets on sleep")
	# 8. Keeper waits on floors 1-3 never roll long/marathon seconds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := 0.0
	for i in 300:
		worst = maxf(worst, float(MineKeepers.roll_pace(1 + i % 3, rng, [])["secs"]))
	check(worst <= MineKeepers.EARLY_SECS_MAX, "floors 1-3 keeper wait <= %.0f s (worst %.0f)" % [MineKeepers.EARLY_SECS_MAX, worst])
	# 9. Floor 1 has a miner's bench that rests once a day.
	r["flags"]["mine_seen"] = true
	r["mine_floor"] = 1
	(load("res://scripts/mine.gd") as Variant).force_seed = 4242
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(10)
	var m := current_scene as GameMap
	var bench := Vector2i(-1, -1)
	for k in m.things:
		if str(m.things[k].get("type", "")) == "rest_bench":
			bench = k
	check(bench != Vector2i(-1, -1), "floor 1 has a miner's bench")
	if bench != Vector2i(-1, -1):
		r["energy"] = 20
		r["rest_en"] = 0
		m.interact(bench, m.things[bench])
		check(int(r["energy"]) == 45, "the bench rests +25 (%d)" % int(r["energy"]))
		m.interact(bench, m.things[bench])
		check(int(r["energy"]) == 45, "once a day per floor")
	print("c16a_energy_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
