extends SceneTree
## C16a P5: farm, ranch, mining, combat gear and crafting ecosystems (both arcs).
##  - weapon ladder: one damage per tier for every source (T1 3, T2 5, T3 7, T4 10, signature 11),
##    smith swords are penguin-arc, the gang smith sells the crowbar line (c16a_07-04/05);
##  - guns: gold revolver out-DPSes the tommy gun, rounds come 40 a craft (c16a_07-03);
##  - armour: defence 1..8 per metal, values rise metal by metal, steel is tier 3 (c16a_07-06);
##  - pickaxe: swing_damage == the swing mine.gd subtracts, so real swings == hits_for (c16a_07-01);
##    stone keeps 3 starter swings, copper ore drops to 5 (c16a_07-02);
##  - stations: tier-1 gates spread over season 1, top tiers wait for year 2, gang words (c16a_10-01/02/03);
##  - recipes: tier skill table and a year key (c16a_09-17); iridium sprinkler year 2 (c16a_06-09);
##  - mine: floors past 100 open in year 2, the Hollow Heart in year 3 (c16a_07-15);
##  - "any" crops sleep outdoors in winter except the crystal crops (c16a_06-11);
##  - Hazel/helper watering is capped (c16a_06-08);
##  - decor sets are finishable in the arc that shows them (c16a_09-01).
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/c16a_p5_test.gd
var fails := 0


func _initialize() -> void:
	seed(16)
	_run.call_deferred()


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func dmg(id: String) -> int:
	return int(GameState.items.get(id, {}).get("damage", -1))


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var it := GameState.items
	# Weapons
	for row in [["iron_sword", 5], ["crowbar", 5], ["fishbone_sabre", 5], ["lucky_bat", 5], ["aurora_blade", 5],
			["steel_sword", 7], ["chrome_blade", 7], ["prism_lance", 7], ["crystal_sword", 10], ["neon_cleaver", 11], ["starheart_blade", 11]]:
		check(dmg(row[0]) == int(row[1]), "%s damage %d (got %d)" % [row[0], row[1], dmg(row[0])])
	for s in ["iron_sword", "steel_sword", "crystal_sword"]:
		check(str(it[s].get("arc", "")) == "penguins", "%s is penguin-arc" % s)
	var gr: Dictionary = it["gold_revolver"]
	var tg: Dictionary = it["tommy_gun"]
	check(float(gr["damage"]) / float(gr["cd"]) > float(tg["damage"]) / float(tg["cd"]) * 1.5, "gold revolver out-DPSes the tommy gun bare")
	var rounds := 0
	for r in GameState.recipes.get("armory", []):
		if r["id"] == "rounds":
			rounds = int(r.get("n", 1))
	check(rounds == 40, "rounds craft 40 at a time")
	# Cooking: every tier-2+ kitchen dish has a buff (c16a_09-02)
	for r in GameState.recipes.get("kitchen", []):
		var di: Dictionary = it.get(str(r["give"]), {})
		if int(r.get("tier", 1)) >= 2 and str(di.get("type", "")) == "food":
			check(di.has("buff"), "tier-%d dish %s has a buff" % [int(r.get("tier", 1)), r["give"]])
	# Armour ladder
	var metals := ["leather", "copper", "iron", "steel", "silver", "gold", "crystal", "moon"]
	for sl in ["helm", "chest", "legs", "boots"]:
		var prev_v := 0
		for i in metals.size():
			var k := "%s_%s" % [metals[i], sl]
			if not it.has(k):
				continue
			check(int(it[k].get("stats", {}).get("defense", 0)) == i + 1, "%s defence %d" % [k, i + 1])
			check(int(it[k].get("value", 0)) > prev_v, "%s value rises over the metal below" % k)
			prev_v = int(it[k].get("value", 0))
			if it.has(k + "_plus"):
				check(int(it[k + "_plus"]["stats"].get("defense", 0)) == i + 2, "%s_plus is +1" % k)
	check(int(it["steel_chest"]["tier"]) == 3, "steel set is tier 3")
	# Shops: gang smith sells the crowbar, not swords
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	var gs: Array = Shops.offers("smith")
	check(gs.has("crowbar") and not gs.has("iron_sword"), "gang smith: crowbar, no iron sword")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(Shops.offers("smith").has("iron_sword"), "penguin smith: iron sword")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	# Pickaxe swing_damage matches the mine's subtraction
	for t in [0, 1, 2, 4, 7]:
		if not GameState.run.has("tool_tier"):
			GameState.run["tool_tier"] = {}
		GameState.run["tool_tier"]["pickaxe"] = t
		if GameState.tool_tier("pickaxe") == t:
			check(GameState.swing_damage("pickaxe") == Mining.pick_swing() + int(GameState.bonus("mining", "mine_power")), "pick tier %d: swing_damage == pick_swing" % t)
			var thing := {"hp": 4}
			GameState.toughen(thing, "pickaxe")
			var swings := int(ceil(float(thing["hp"]) / float(Mining.pick_swing())))
			check(swings == GameState.hits_for(4, "pickaxe"), "pick tier %d: real swings == hits_for" % t)
	GameState.run["tool_tier"]["pickaxe"] = 0
	if GameState.tool_tier("pickaxe") == 0:
		check(GameState.hits_for(2, "pickaxe") == 3, "starter pick: stone still 3 swings (Tom C6)")
		check(GameState.hits_for(4, "pickaxe") == 5, "starter pick: copper ore 5 swings (was 6)")
	# Stations
	var B: Dictionary = Builds.all()
	for sid in ["workbench", "kitchen", "furnace"]:
		check((B[sid]["tiers"][0] as Dictionary).get("unlock", {}).is_empty(), "%s tier 1 open on day 1" % sid)
	for sid in ["anvil", "sawmill", "mayo", "extractor", "armory", "shaper", "gene_splicer"]:
		check(not (B[sid]["tiers"][0] as Dictionary).get("unlock", {}).is_empty(), "%s tier 1 has a gate" % sid)
	for sid in B:
		var bd: Dictionary = B[sid]
		if str(bd.get("thing", "")) == "station" and (bd.get("tiers", []) as Array).size() >= 4:
			check(int(bd["tiers"][3].get("unlock", {}).get("year", 0)) == 2, "%s top tier waits for year 2" % sid)
	check(int(B["barn"]["tiers"][-1].get("unlock", {}).get("year", 0)) == 2 if B.has("barn") else true, "Grand Barn waits for year 2")
	# Recipe tier table + year key
	GameState.run["skills"]["building"] = {"level": 7, "xp": 0}
	check(Crafting.skill_tier("workbench") == 2, "building Lv 7 opens recipe tier 2 (was 4)")
	GameState.run["skills"]["building"] = {"level": 20, "xp": 0}
	check(Crafting.skill_tier("workbench") == 5, "building Lv 20 opens recipe tier 5")
	check(Crafting.why_locked("workbench", 4, {"id": "x", "tier": 1, "need": {}, "year": 2}).contains("year 2"), "a year-2 recipe says so in year 1")
	GameState.run["day"] = 113 + 5
	check(GameState.year() == 2, "day 118 is year 2")
	check(Crafting.why_locked("workbench", 4, {"id": "x", "tier": 1, "need": {}, "year": 2}) == "", "year-2 recipe opens in year 2")
	var irid := {}
	for r in GameState.recipes.get("workbench", []):
		if r["id"] == "sprinkler_iridium":
			irid = r
	check(int(irid.get("year", 0)) == 2, "iridium sprinkler recipe waits for year 2")
	# Mine deep end
	var MineS: Script = load("res://scripts/mine.gd")
	GameState.run["day"] = 50
	check(str(MineS.call("deep_lock", 99)) == "", "floor 99 -> 100 open in year 1")
	check(str(MineS.call("deep_lock", 100)) != "", "floor 100 -> 101 shut in year 1")
	check(str(MineS.call("deep_lock", 150)) != "", "Hollow Heart shut in year 1")
	GameState.run["day"] = 120
	check(str(MineS.call("deep_lock", 100)) == "", "deep floors open in year 2")
	check(str(MineS.call("deep_lock", 150)) != "", "Hollow Heart still shut in year 2")
	GameState.run["day"] = 230
	check(str(MineS.call("deep_lock", 150)) == "", "Hollow Heart opens in year 3")
	# Any-season crops in winter
	var C := GameState.crops
	check(not GameState.crop_fits_season(C["starfruit"], "winter"), "starfruit (any) sleeps outdoors in winter")
	check(GameState.crop_fits_season(C["starfruit"], "summer"), "starfruit (any) grows in summer")
	check(GameState.crop_fits_season(C["crystal_lettuce"], "winter"), "crystal lettuce is winter-hardy")
	# Helper watering cap
	GameState.run["farm"] = {}
	for x in 40:
		GameState.run["farm"]["%d,%d" % [x % 10, x / 10]] = {"crop": "turnip", "days": 0, "watered": false}
	check(GameState._helper_tiles(GameState.hazel_water_cap()).size() == 0, "no hearts, no help")
	GameState.run["friendship"]["hazel"] = GameState.HEART_POINTS * 4
	check(GameState._helper_tiles(GameState.hazel_water_cap()).size() == 12, "Hazel 4 hearts waters 12")
	GameState.run["friendship"]["hazel"] = GameState.HEART_POINTS * 6
	check(GameState._helper_tiles(GameState.hazel_water_cap()).size() == 30, "Hazel 6 hearts waters 30")
	# Animal show tables stay winnable in years 1-5 (c16a_06-13)
	var AnimalShow: Script = load("res://scripts/animal_show.gd")
	for fc in [["egg", "eggs"], ["lantern", "fleece"]]:
		var c: Dictionary = AnimalShow.call("cat", fc[0], fc[1])
		var best := 0
		for gid: String in (Ranch.data().get("products", {}) as Dictionary).keys():
			if AnimalShow.call("fits_family", c, gid):
				best = maxi(best, int(AnimalShow.call("score_good", gid, 20)))
		var top := 0
		for r: Array in c.get("rivals", []):
			top = maxi(top, int(r[2]))
		for yr in 5:
			check(best > mini(top + int(AnimalShow.get("YEAR_STEP") if AnimalShow.get("YEAR_STEP") != null else 10) * yr, int(c.get("cap", 999))), "%s table: the best gold good beats the top rival in year %d" % [fc[1], yr + 1])
	# Decor sets
	var ents: Dictionary = {}
	var f2 := FileAccess.open("res://data/decor.json", FileAccess.READ)
	var dj: Dictionary = JSON.parse_string(f2.get_as_text())
	var sets: Dictionary = dj.get("sets", {})
	check(sets.size() > 30, "decor sets loaded")
	for key in ["entries", "pieces", "decor", "items"]:
		if dj.has(key) and dj[key] is Dictionary:
			ents = dj[key]
			break
	for sid in sets:
		var sa := str(sets[sid].get("arc", ""))
		for p in sets[sid].get("pieces", []):
			var pa := str((ents.get(p, it.get(p, {})) as Dictionary).get("arc", ""))
			check(pa == "" or pa == sa, "set %s piece %s (%s) fits the set's arc (%s)" % [sid, p, pa, sa])
	print("c16a_p5_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
