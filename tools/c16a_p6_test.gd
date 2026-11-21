extends SceneTree
## C16a P6: skill-tree pacing and recruit/ally/team/pup progression guards.
## Column ladder (TIER_NEED), per-tree XP pace (SKILL_XP_MUL), the new caps (tree damage,
## kill energy, team heal, farming), hp/energy totals, partner power XP only when it did something
## (25 a day), pup bite XP (40 a day), partner ranks, crew loyalty pacing and drill cap, helper
## chore levels, team-animal ranks and the exotic team species, the gang arc's Tech tree name.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c16a_p6_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(16)
	Campaign.bypass = true
	_run.call_deferred()


func _total(sk: String, key: String) -> float:
	var t := 0.0
	for n in GameState.nodes_of(sk):
		t += float((n.get("effect", {}) as Dictionary).get(key, 0.0)) * int(n.get("ranks", 1))
	return t


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	# Starter Spark (c16a_12-02): known from day 1, a gift (not a spent point).
	check(GameState.node_rank("magic", "spark") == 1 and GameState.points_spent("magic") == 0 and "spark" in Spells.known(), "new save knows Spark as a gift")
	# Respec fee (c16a_11-13): first reset free, then 40 a point.
	GameState.run["skills"]["foraging"]["level"] = 10
	GameState.buy_node("foraging", str(GameState.nodes_of("foraging")[0]["id"]))
	check(GameState.reset_cost("foraging") == 0, "first reset is free")
	GameState.reset_tree("foraging")
	GameState.buy_node("foraging", str(GameState.nodes_of("foraging")[0]["id"]))
	check(GameState.reset_cost("foraging") == 40, "second reset costs 40 a point (%d)" % GameState.reset_cost("foraging"))
	# Column ladder: column X waits for 64 points (about level 65), not 18.
	check(GameState.col_need(9) == 64 and GameState.col_need(1) == 2 and GameState.col_need(5) == 20, "column ladder 0,2,5,9,14,20,28,38,50,64")
	check(GameState.skills_data.has("farming") and (GameState.skills_data["farming"]["nodes"] as Array).size() == 40, "farming grid still 4x10")
	var sd: Dictionary = load("res://scripts/game_state.gd").get_script_constant_map()
	check(sd.has("TIER_NEED"), "TIER_NEED constant")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	check((raw.get("tier_need", []) as Array).size() == 10 and int(raw["tier_need"][9]) == 64, "skills.json carries tier_need")
	# Locked message reads the ladder.
	GameState.run["skills"]["farming"]["level"] = 30
	var x_node := ""
	for n in GameState.nodes_of("farming"):
		if int(n.get("tier", 0)) == 9:
			x_node = str(n["id"])
			break
	check(GameState.node_locked("farming", x_node).contains("64"), "a column-X node names 64 points (%s)" % GameState.node_locked("farming", x_node))
	# Per-tree XP pace: mining slower, leadership faster; spread kept within 5x.
	var mul: Dictionary = GameState.SKILL_XP_MUL
	check(float(mul["mining"]) < 1.0 and float(mul["leadership"]) > 2.0, "gathering trees slower, service trees faster")
	var lo := 99.0
	var hi := 0.0
	for k in mul:
		lo = minf(lo, float(mul[k]))
		hi = maxf(hi, float(mul[k]))
	check(hi / lo <= 5.0, "XP pace multipliers within 5x (%.1f)" % (hi / lo))
	GameState.run["skills"]["mining"] = {"level": 1, "xp": 0, "nodes": {}}
	GameState.add_xp("mining", 100)
	check(int(GameState.run["skills"]["mining"]["xp"]) + 40 * (int(GameState.run["skills"]["mining"]["level"]) - 1) <= 70, "mining XP at 0.6x")
	# Caps: tree damage <= 8 (was 16), kill energy <= 8 (was 28), team heal <= 15, gun damage <= 6.
	for pair in [["combat", "damage", 8.0], ["combat", "kill_energy", 8.0], ["leadership", "team_heal", 15.0], ["hustle", "gun_damage", 6.0], ["farming", "growth", 0.2], ["farming", "double_harvest", 0.25], ["bartering", "buy_discount", 0.25]]:
		check(_total(pair[0], pair[1]) <= float(pair[2]) + 0.001, "%s %s total %.2f <= %.2f" % [pair[0], pair[1], _total(pair[0], pair[1]), pair[2]])
	check(float(GameState.BONUS_CAPS["damage"]) == 8.0 and float(GameState.BONUS_CAPS["kill_energy"]) == 8.0, "run-time caps for damage / kill energy")
	# Farming full-tree income multiplier <= 3x (count x value x growth).
	var fm := (1.0 + _total("farming", "extra_crop") + _total("farming", "double_harvest")) * (1.0 + _total("farming", "crop_value")) * (1.0 + _total("farming", "growth"))
	check(fm <= 3.0, "full Farming tree <= 3x income per plot (%.2f)" % fm)
	# Partner power XP: only when it did something, 25 grants a day.
	GameState.run["skills"]["leadership"] = {"level": 1, "xp": 0, "nodes": {}}
	for i in 40:
		Companion.power_done()
	var rec: Array = GameState.run["flags"]["power_xp_day"]
	check(int(rec[1]) == Companion.POWER_XP_DAY, "partner power XP stops at %d grants a day" % Companion.POWER_XP_DAY)
	check(Companion.partner_rank("mom") >= 1 and Companion.partner_rank("mom") <= 5, "partner rank 1-5")
	GameState.run["friendship"]["mom"] = 25 * 10
	check(Companion.partner_rank("mom") == 5, "ten hearts = partner rank 5")
	# Pup bites: 40 XP a day at most.
	for i in 60:
		Pet.bite_xp(2)
	check(int(GameState.run["flags"]["pup_bite_xp"][1]) == Pet.BITE_XP_DAY, "pup bite XP capped at %d a day" % Pet.BITE_XP_DAY)
	GameState.run["day"] = int(GameState.run["day"]) + 1
	Pet.bite_xp(2)
	check(int(GameState.run["flags"]["pup_bite_xp"][1]) == 2, "pup bite cap resets next day")
	# Helper chore levels: level 5 is a 1.5-3 season goal (600 XP), not two weeks.
	var hd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	check(int((hd["levels"] as Array).back()) >= 600, "helper level 5 needs 600 chore XP")
	# Fish / mine chores (c16a_13-11): crew and partners can take them; the mine needs a visit first.
	check(((hd["workers"]["crew"]["chores"]) as Array).has("fish") and ((hd["workers"]["partner"]["chores"]) as Array).has("mine"), "crew/partners fish and mine")
	check(not Chores.chore_pool("fish").is_empty(), "the fish chore has commons to bring back")
	GameState.run["flags"]["mine_deepest"] = 1
	check(Chores.chore_pool("mine").is_empty(), "no mine chore before you've been down")
	GameState.run["flags"]["mine_deepest"] = 40
	check(Chores.chore_pool("mine").has("iron") and Chores.chore_pool("mine").has("copper"), "deep floors open copper and iron")
	# Team animals: rank 5 at 35 lessons; every team:true ranch species trains.
	var ta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/team_animals.json"))
	check(int(ta["rules"]["max_rank"]) == 5, "team animal max rank 5")
	var rs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ranch.json"))["species"]
	var missing: Array = []
	for sid in rs:
		if bool((rs[sid] as Dictionary).get("team", false)) and not (ta["species"] as Dictionary).has(sid) and not (ta["aliases"] as Dictionary).has(sid):
			missing.append(sid)
	check(missing.is_empty(), "every team ranch species trains (%s)" % str(missing))
	GameState.run["skills"]["leadership"]["level"] = 30
	check(TeamAnimals.team_max() >= 3, "Leadership 25 makes team room for a third animal")
	check(str(ta["names"][0]) != "Biscuit", "team names don't start with the pup's default")
	# Gang arc: Sorcery shows as Tech; crew loyalty pacing and the drill cap.
	GameState.new_run("gangsters", "", "T", "Town", "Pup")
	check(GameState.skill_name("magic") == "Tech" and str(GameState.skill_branches("magic").get("0", "")) == "Signal", "gang arc reads Sorcery as Tech")
	GameState.run["crew"] = {"deuce": 1}
	GameState.run["crew_last"] = {"deuce": int(GameState.run["day"])}
	check(Crew.loyalty_wait("deuce") == "days", "loyalty step 2 waits a week")
	GameState.run["day"] = int(GameState.run["day"]) + 7
	GameState.run["friendship"]["deuce"] = 0
	check(Crew.loyalty_wait("deuce") == "hearts", "loyalty step 2 needs 4 hearts")
	GameState.run["friendship"]["deuce"] = 25 * 4
	check(Crew.loyalty_wait("deuce") == "", "4 hearts and a week: the talk plays")
	GameState.run["crew"] = {"deuce": 0}
	check(Crew.member_level("deuce") == 0, "a fresh recruit gets no drill boost")
	print("c16a_p6_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
