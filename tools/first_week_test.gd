extends SceneTree
## First week, both arcs (headless, GameState API only): a modest phone player
## plays days 1-7 and the money/energy curve is checked against the pacing we
## want (generous but purposeful), then the faint/clinic/sleep rules are checked.
##
##   godot --headless --path . -s res://tools/first_week_test.gd [-- verbose]
##
## The player model (per 14-minute day): harvests, waters, plants a field that
## grows by about 5 tiles a day (seeds bought with ~80% of the purse, the best
## profit-per-day seed Maple stocks), chops two trees, forages a few things,
## fishes a little and, once the meadow is open (day 3), runs two mine floors.
## It hands in the early quests a new player meets (meet_town, first_harvest,
## Maple's turnips, Hazel's fence wood, Alder's bridge stone, the meadow).
## Costs come from the real tables (ENERGY_COST, buy/sell prices, saturation).

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
	_faint_rules()
	print("first_week_test: %d failures" % fails)
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
	if grow > 6:
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
	print("%s: day | purse am | field | sold | energy left/max" % arc)
	for d in range(1, 8):
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
		# 2. Water and plant, growing the field.
		var cap := 15 + 5 * (d - 1)
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
		# 3. Wood: two trees (4 swings each, 5 wood each).
		for i in 8:
			GameState.spend_for("axe")
		GameState.add_item("wood", 10)
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
		# 6. Mine from day 3: two floors (about 10 rocks x 2 swings, 40 sword swings, 4 dodges each).
		if d >= 3:
			if not GameState.has_quest("clear_meadow"):
				GameState.tick_quests()
			GameState.complete_quest("clear_meadow")
			for fl in 2:
				for i in 20:
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
		print("  %d | %4d | %3d | %4d | %3d/%3d" % row)
		GameState.sleep()
	var end := int(r["crystals"])
	print("  day 8 morning purse: %d" % end)
	# Pacing bands (both arcs): generous, but the first upgrades are a goal, not a given.
	var pack := GameState.buy_price("backpack_1")
	_ok(low_energy >= int(int(r["max_energy"]) * GameState.EXHAUSTED_FRAC), "%s: a full modest day never forces Exhausted (lowest %d)" % [arc, low_energy])
	_ok(int(curve[0][4]) <= int(int(curve[0][5]) * 0.8), "%s: day 1 uses a real share of the bar (left %d)" % [arc, int(curve[0][4])])
	var day5 := int(curve[4][1])
	_ok(day5 >= 200, "%s: day 5 morning purse is generous (%d)" % [arc, day5])
	_ok(end >= pack, "%s: the Bigger Backpack (%d) is affordable by the end of week 1 (%d)" % [arc, pack, end])
	_ok(int(curve[3][1]) < pack, "%s: ...but not before day 4 (%d)" % [arc, int(curve[3][1])])
	_ok(end < 4 * pack, "%s: week 1 doesn't flood the purse (%d)" % [arc, end])


# ---- faint, clinic, sleep ----------------------------------------------------

func _faint_rules() -> void:
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		var r := GameState.run
		# First week: no clinic bill, nothing goes missing.
		r["crystals"] = 50
		_ok(Faint.fee(true, 0) == 0, "%s day 1: no clinic bill" % arc)
		_ok(Faint.fee(false, 0) == 0, "%s day 1: nothing goes missing" % arc)
		r["day"] = 9
		r["crystals"] = 1000
		_ok(Faint.fee(true, 0) == 0, "%s day 9: first clinic visit after the grace week is free" % arc)
		_ok(Faint.fee(true, 0) == 100, "%s day 9: then the bill is 8%% + 20 (%d)" % [arc, Faint.fee(true, 0)])
		_ok(Faint.fee(true, 10) == 140, "%s day 9: deeper floors cost more (%d)" % [arc, Faint.fee(true, 10)])
		_ok(Faint.fee(false, 0) == 50, "%s day 9: 5%% goes missing at home (%d)" % [arc, Faint.fee(false, 0)])
		r["crystals"] = 30
		_ok(Faint.fee(true, 0) <= 30, "%s: never more than you carry" % arc)
		# A pass-out night: the report is kept for the wake-up, and says the bar is short.
		r["sellbox"] = {"turnip": 3}
		r["time"] = 25 * 60
		var rep := GameState.sleep(true)
		_ok(int(r["energy"]) == int(r["max_energy"]) * 3 / 4, "%s: pass-out night costs a quarter bar" % arc)
		_ok(bool(rep.get("short", false)), "%s: the report says the bar is short" % arc)
		var lines := SleepReport.lines(rep)
		var txt := ""
		for l in lines:
			txt += str(l.get("text", "")) + "\n"
		_ok("Total" in txt, "%s: pass-out report lists the sell box" % arc)
		_ok("three quarters" in txt, "%s: pass-out report explains the short bar" % arc)
		# The kept report survives to the wake-up (house/clinic) and is shown once.
		r["flags"]["wake_report"] = SleepReport.keep(rep)
		_ok(not SleepReport.take_kept().is_empty() and SleepReport.take_kept().is_empty(), "%s: kept pass-out report is shown once" % arc)
		# A normal night: no short-bar line.
		r["time"] = 20 * 60
		rep = GameState.sleep()
		_ok(not bool(rep.get("short", false)) and int(r["energy"]) == int(r["max_energy"]), "%s: a normal night refills the bar" % arc)
		# Faint before 10pm, then bed: the morning after is short and says so.
		r["time"] = 15 * 60
		r["energy"] = 0
		_ok(Faint.to_evening("tired"), "%s: 3pm faint wakes at 10pm" % arc)
		rep = GameState.sleep()
		_ok(bool(rep.get("short", false)) and int(r["energy"]) == int(r["max_energy"]) * 3 / 4, "%s: bed after an evening faint still costs a quarter bar" % arc)
		# Bedtime warnings: midnight and 1:30am, once each a night.
		r["time"] = 23 * 60
		_ok(Faint.bedtime_note() == "", "%s: no warning at 11pm" % arc)
		r["time"] = 24 * 60 + 2
		_ok("Midnight" in Faint.bedtime_note(), "%s: midnight warning" % arc)
		_ok(Faint.bedtime_note() == "", "%s: midnight warning only once" % arc)
		r["time"] = 25 * 60 + 31
		_ok("1:30" in Faint.bedtime_note(), "%s: 1:30am warning" % arc)
		r["day"] = int(r["day"]) + 1
		r["time"] = 24 * 60 + 5
		_ok("Midnight" in Faint.bedtime_note(), "%s: warnings come back the next night" % arc)
