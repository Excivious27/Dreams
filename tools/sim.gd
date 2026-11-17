extends SceneTree
## Economy bot: plays N days of farming headlessly on the GameState API alone
## (no scenes) and prints a CSV of the day-by-day curve. It mirrors farm.gd's
## rules: hoe 2 energy, water 1, plant 1, harvest free, sale at sleep.
##
##   godot --headless --path . -s res://tools/sim.gd -- [days] [arc] [strategy] [csv_path]
##
## Strategies: "best" (highest profit/day in-season seed the store sells),
## "cheap" (always the cheapest seed), "mixed" (regrow crops once affordable).
## The bot works ~10 real seconds per tile per day (walk + act) inside a 23-min
## day, so the day caps at about 130 tile actions; energy is the other cap.

const DAY_SECONDS := 23.0 * 60.0
const SECONDS_PER_ACTION := 1.6   # walk a step, swing, next tile
const MINE_DAY_EVERY := 0         # 0 = never go mining (farming only)

var days := 100
var arc := "penguins"
var strategy := "best"
var csv_path := "/tmp/sim.csv"
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: days = int(args[0])
	if args.size() > 1: arc = args[1]
	if args.size() > 2: strategy = args[2]
	if args.size() > 3: csv_path = args[3]
	rng.seed = 7
	GameState.new_run(arc, "penguin_f" if arc == "penguins" else "dad", "Bot", "Simtown", "Dot")
	GameState.add_quest("first_harvest", "sim")
	var lines := ["day,season,crystals,tiles,planted,watered,harvested,sold_value,energy_left,farming_lv,seed"]
	for d in days:
		var row := _play_day()
		lines.append(row)
	var f := FileAccess.open(csv_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("sim: %d days → %s  final ◆%d, farming %d, tiles %d" % [days, csv_path, int(GameState.run["crystals"]), GameState.skill_level("farming"), GameState.run["farm"].size()])
	quit()


func _store() -> Array:
	return Shops.offers("store")


func _profit_per_day(seed_id: String) -> float:
	var it: Dictionary = GameState.items.get(seed_id, {})
	var crop := str(it.get("crop", ""))
	if crop == "" or not GameState.crops.has(crop):
		return -1.0
	var cd: Dictionary = GameState.crops[crop]
	var cs := str(cd.get("season", "any"))
	if cs != "any" and cs != GameState.season():
		return -1.0
	var days_left := 28 - GameState.day_of_season()
	var grow := int(cd["days"])
	if grow > days_left:
		return -1.0
	var value := GameState.item_value(str(cd["yield"]))
	var cost := float(GameState.buy_price(seed_id))
	if cd.has("regrow"):
		var harvests := 1 + int((days_left - grow) / int(cd["regrow"]))
		return (harvests * value - cost) / float(days_left)
	return (value - cost) / float(grow)


func _pick_seed() -> String:
	var best := ""
	var best_v := -1e9
	for sid in _store():
		var it: Dictionary = GameState.items.get(sid, {})
		if str(it.get("type", "")) != "seed":
			continue
		var v: float
		match strategy:
			"cheap": v = -float(GameState.buy_price(sid)) if _profit_per_day(sid) > 0.0 else -1e9
			_: v = _profit_per_day(sid)
		if v > best_v and v > 0.0:
			best_v = v
			best = sid
	return best


func _owned_seed() -> String:
	var best := ""
	var best_v := 0.0
	for id in GameState.run["inventory"].keys():
		if str(GameState.items.get(id, {}).get("type", "")) == "seed" and GameState.count(id) > 0:
			var v := _profit_per_day(id)
			if v > best_v:
				best_v = v
				best = id
	return best


func _plant(tile: Dictionary, seed: String) -> bool:
	if GameState.count(seed) <= 0:
		var p := GameState.buy_price(seed)
		if int(GameState.run["crystals"]) < p:
			return false
		GameState.run["crystals"] = int(GameState.run["crystals"]) - p
		GameState.add_item(seed, 1)
	if not GameState.spend_for("plant"):
		return false
	tile["crop"] = str(GameState.items[seed]["crop"])
	tile["days"] = 0
	GameState.add_item(seed, -1)
	GameState.add_xp("farming", 2)
	return true


func _play_day() -> String:
	var farm: Dictionary = GameState.run["farm"]
	var actions := 0
	var max_actions := int(DAY_SECONDS / SECONDS_PER_ACTION)
	var planted := 0
	var watered := 0
	var harvested := 0
	# 1. Harvest what is ripe.
	for key in farm.keys():
		var tile: Dictionary = farm[key]
		var crop := str(tile.get("crop", ""))
		if crop == "" or actions >= max_actions:
			continue
		var cd: Dictionary = GameState.crops[crop]
		if int(tile["days"]) >= int(cd["days"]):
			var n := 1 + (1 if rng.randf() < 0.03 * GameState.skill_level("farming") + GameState.bonus("farming", "extra_crop") else 0)
			var yid := str(cd["yield"])
			GameState.run["sellbox"][yid] = int(GameState.run["sellbox"].get(yid, 0)) + n
			GameState.add_xp("farming", 4 + 2 * int(cd.get("tier", 1)))
			if cd.has("regrow"):
				tile["days"] = int(cd["days"]) - int(cd["regrow"])
			else:
				tile["crop"] = ""
				tile["days"] = 0
			harvested += n
			actions += 1
			GameState.complete_quest("first_harvest")
	# 2. Plant the empties (seeds we own first, then the best the store sells).
	var seed := _owned_seed()
	if seed == "":
		seed = _pick_seed()
	if seed != "":
		for key in farm.keys():
			var tile: Dictionary = farm[key]
			if str(tile.get("crop", "")) != "" or actions >= max_actions:
				continue
			if not _plant(tile, seed):
				break
			planted += 1
			actions += 1
	# 3. Water everything planted (rain does it for free).
	for key in farm.keys():
		var tile: Dictionary = farm[key]
		if str(tile.get("crop", "")) == "" or bool(tile.get("watered", false)) or actions >= max_actions:
			continue
		if GameState.is_wet():
			break
		if not GameState.spend_for("can"):
			break
		tile["watered"] = true
		watered += 1
		actions += 1
	# 4. Expand the field with what is left: never more tiles than tomorrow's
	# energy can water (1 each) with a third kept back for hoeing and planting.
	if seed != "":
		var cap := int(int(GameState.run["max_energy"]) * 0.7 / maxi(1, GameState.energy_cost("can")))
		var affordable := int(int(GameState.run["crystals"]) / maxi(1, GameState.buy_price(seed))) + GameState.count(seed)
		while farm.size() < mini(cap, affordable) and actions < max_actions and int(GameState.run["energy"]) > 6:
			if not GameState.spend_for("hoe"):
				break
			var key := "%d,%d" % [10 + (farm.size() % 12), 10 + int(farm.size() / 12)]
			farm[key] = {"watered": false, "crop": "", "days": 0}
			GameState.add_xp("farming", 1)
			actions += 1
			if _plant(farm[key], seed):
				planted += 1
				actions += 1
				if GameState.spend_for("can"):
					farm[key]["watered"] = true
					watered += 1
					actions += 1
	var energy_left := int(GameState.run["energy"])
	var sold_value := 0
	for id in GameState.run["sellbox"].keys():
		sold_value += GameState.sell_price(id, int(GameState.run["sellbox"][id]))
	var day := int(GameState.run["day"])
	var season := GameState.season()
	GameState.sleep()
	return "%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s" % [day, season, int(GameState.run["crystals"]), farm.size(), planted, watered, harvested, sold_value, energy_left, GameState.skill_level("farming"), seed]
