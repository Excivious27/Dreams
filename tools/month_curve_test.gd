extends SceneTree
## C8 P1 month curve (headless, GameState API only): first_week_test's modest
## phone player carried on for 30 days in both arcs (field grows 5 tiles a day
## up to what ~45% of the bar can water, seeds that ripen in-season). Bands:
## max energy stays a limit (passive growth slowed in C8 P1), bedtime bar left,
## purse at day 14 / 28 neither starved nor flooded. Promoted from the
## CONDUCT 8 auditor probe (c8_09).
##   godot --headless --path . -s res://tools/month_curve_test.gd [-- verbose]

var fails := 0
var verbose := false
var rng := RandomNumberGenerator.new()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		print("  FAIL ", what)
		fails += 1


func _initialize() -> void:
	verbose = "verbose" in OS.get_cmdline_user_args()
	GameState.load_data()
	for arc in ["penguins", "gangsters"]:
		_week(arc)
	print("month_curve_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


# ---- the week ----------------------------------------------------------------

func _seed_value(sid: String) -> float:
	var it: Dictionary = GameState.items.get(sid, {})
	var cid := str(it.get("crop", ""))
	if str(it.get("type", "")) != "seed" or not GameState.crops.has(cid):
		return -1.0
	var cd: Dictionary = GameState.crops[cid]
	var cs := str(cd.get("season", "any"))
	if cs != "any" and cs != GameState.season():
		return -1.0
	var grow := int(cd["days"])
	if grow > 28 - GameState.day_of_season():
		return -1.0  # a new player wants to see it come up this week
	return (GameState.item_value(str(cd["yield"])) - float(GameState.buy_price(sid))) / float(grow)


func _best_seed() -> String:
	var best := ""
	var bv := 0.0
	for sid in Shops.offers("store"):
		var v := _seed_value(str(sid))
		if v > bv:
			bv = v
			best = str(sid)
	return best


func _sell(id: String, n: int) -> void:
	GameState.run["sellbox"][id] = int(GameState.run["sellbox"].get(id, 0)) + n


func _hand_in(id: String) -> void:
	# Side quests: taken from the giver, handed in when the bag holds the goods.
	var d := GameState._quest_def(id)
	if d.is_empty() or GameState.has_quest(id) and _done(id):
		return
	if not GameState.has_quest(id):
		if not GameState._cond_ok(d.get("when", {})):
			return
		GameState.add_quest(id, str(d.get("text", id)))
	var dw: Dictionary = d.get("done_when", {})
	var pairs: Array = dw.get("items", [])
	if dw.has("item"):
		pairs = [dw["item"]]
	for p in pairs:
		if GameState.count(str(p[0])) < int(p[1]):
			return
	for p in pairs:
		GameState.add_item(str(p[0]), -int(p[1]))
	GameState.complete_quest(id)


func _done(id: String) -> bool:
	for q in GameState.run["quests"]:
		if str(q["id"]) == id:
			return bool(q["done"])
	return false


func _week(arc: String) -> void:
	rng.seed = 11
	seed(11)
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
	var r := GameState.run
	r["intro_done"] = true
	# Maple's first-timer bundle (Shops.run, first visit).
	GameState.add_item("turnip_seed", 10)
	GameState.add_item("energy_tea", 1)
	var farm: Dictionary = r["farm"]
	var curve: Array = []
	var low_energy := 999
	var refills := 0
	print("%s: day | purse am | field | sold | energy left/max" % arc)
	for d in range(1, 31):
		var purse := int(r["crystals"])
		GameState.tick_quests()
		if d == 1:
			GameState.add_quest("meet_town", "meet")
			GameState.complete_quest("meet_town")
		# 1. Harvest.
		for key in farm.keys():
			var t: Dictionary = farm[key]
			var c := str(t.get("crop", ""))
			if c == "":
				continue
			var cd: Dictionary = GameState.crops[c]
			if int(t["days"]) >= int(cd["days"]):
				GameState.add_item(str(cd["yield"]), 1)
				GameState.add_xp("farming", 4 + 2 * int(cd.get("tier", 1)))
				if cd.has("regrow"):
					t["days"] = int(cd["days"]) - int(cd["regrow"])
				else:
					t["crop"] = ""
					t["days"] = 0
		GameState.tick_quests()  # first_harvest
		_hand_in("maple_turnips")
		_hand_in("maple_strawberries")
		# Sell the rest of the harvest.
		var yields := {}
		for cid in GameState.crops:
			yields[str(GameState.crops[cid]["yield"])] = true
		for id in r["inventory"].keys():
			if yields.has(str(id)) and GameState.count(str(id)) > 0:
				var n := GameState.count(str(id))
				_sell(str(id), n)
				GameState.add_item(str(id), -n)
		var pours := 0
		# 2. Water and plant, growing the field.
		var cap := mini(15 + 5 * (d - 1), int(int(r["max_energy"]) * 0.45 / maxf(0.1, GameState.energy_cost_f("can"))))
		var sd := _best_seed()
		var budget := int(int(r["crystals"]) * 0.8)
		while farm.size() < cap:
			farm["%d,%d" % [farm.size() % 10, farm.size() / 10]] = {"crop": "", "days": 0, "watered": false}
			GameState.spend_for("hoe")
		for key in farm.keys():
			var t: Dictionary = farm[key]
			if str(t.get("crop", "")) == "":
				var use := "turnip_seed" if GameState.count("turnip_seed") > 0 else sd
				if use == "" or use == sd and GameState.count(use) <= 0:
					var p := GameState.buy_price(sd) if sd != "" else 9999
					if budget < p:
						continue
					budget -= p
					r["crystals"] = int(r["crystals"]) - p
					GameState.add_item(sd, 1)
					use = sd
				GameState.spend_for("plant")
				GameState.add_item(use, -1)
				t["crop"] = str(GameState.items[use]["crop"])
				t["days"] = 0
				GameState.add_xp("farming", 2)
			if str(t.get("crop", "")) != "" and not GameState.is_wet():
				GameState.spend_for("can")
				t["watered"] = true
				pours += 1
		# The can holds WaterCan.cap() pours: every refill is a walk to water.
		refills += maxi(0, (pours - 1) / maxi(1, WaterCan.cap()))
		# 3. Wood: two trees, swings from the real curve (GameState.hits_for: 7
		# with the starter axe at level 1), 4 wood each (game_map fell_tree).
		for i in 2 * GameState.hits_for(4, "axe"):
			GameState.spend_for("axe")
		GameState.add_item("wood", 8)
		GameState.add_xp("foraging", 8)
		_hand_in("hazel_wood")
		# 4. Forage a handful.
		for i in 5:
			var id: String = ["flower", "wild_herb", "berry", "flower", "dandelion"][rng.randi() % 5]
			_sell(id, 1)
			GameState.add_xp("foraging", 3)
		# 5. A little fishing: 5 casts, 3 small fish.
		for i in 5:
			GameState.spend_for("rod")
		_sell("minnow", 2)
		_sell("carp", 1)
		GameState.add_xp("fishing", 12)
		# 6. Mine from day 3: two floors (about 10 stone rocks at the real swing
		# count, 3 with the wood pick at level 1, 40 sword swings, 4 dodges each).
		if d >= 3:
			if not GameState.has_quest("clear_meadow"):
				GameState.tick_quests()
			GameState.complete_quest("clear_meadow")
			for fl in 2:
				for i in 10 * GameState.hits_for(2, "pickaxe"):
					GameState.spend_for("pickaxe")
				for i in 40:
					GameState.spend_for("sword")
				for i in 4:
					GameState.spend_for("dodge")
				GameState.add_item("stone", 8)
				_sell("copper", 2)
				_sell("coal", 1)
				GameState.add_xp("mining", 20)
				GameState.add_xp("combat", 15)
			_hand_in("alder_bridge")
		low_energy = mini(low_energy, int(r["energy"]))
		var sold := 0
		for id in r["sellbox"].keys():
			sold += GameState.sell_price(str(id), int(r["sellbox"][id]))
		var row := [d, purse, farm.size(), sold, int(r["energy"]), int(r["max_energy"])]
		curve.append(row)
		if verbose or d % 7 == 0 or d == 1:
			print("  %d | %4d | %3d | %4d | %3d/%3d" % row)
		GameState.sleep()
	var end := int(r["crystals"])
	print("  day 31 morning purse: %d" % end)
	var me14 := int(curve[13][5])
	var me28 := int(curve[27][5])
	_ok(me28 <= 190, "%s: day-28 max energy stays a limit (%d, was 240)" % [arc, me28])
	_ok(me14 <= 170, "%s: day-14 max energy (%d, was 189)" % [arc, me14])
	var left := 0.0
	for i in range(14, 28):
		left += float(curve[i][4]) / float(curve[i][5])
	left /= 14.0
	print("  weeks 3-4 average bar left at bedtime: %d%%" % int(left * 100))
	_ok(left <= 0.65, "%s: weeks 3-4 still use the bar (%.0f%% left, was 70-80%%)" % [arc, left * 100.0])
	_ok(low_energy >= int(int(r["max_energy"]) * 0.05), "%s: never a pass-out (lowest %d)" % [arc, low_energy])
	var p14 := int(curve[13][1])
	var p28 := int(curve[27][1])
	_ok(p14 >= 500 and p28 > p14, "%s: the purse grows (d14 %d, d28 %d)" % [arc, p14, p28])
	_ok(p28 < 40000, "%s: no flood by day 28 (%d)" % [arc, p28])
