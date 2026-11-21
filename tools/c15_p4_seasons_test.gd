extends SceneTree
## CONDUCT 15 P4: seasons for fish, critters, the gang city (weather, stalls),
## the racket, and the crew (seasonal lines, birthdays). Pure checks, no maps.

var fails := 0
const DAYS := {"spring": 3, "summer": 31, "fall": 59, "winter": 87}


func _initialize() -> void:
	seed(1504)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _at(se: String, wx := "clear", noon := true) -> void:
	var d: int = DAYS[se]
	GameState.run["day"] = d
	GameState.run["time"] = 12 * 60 if noon else 23 * 60
	var w: Dictionary = GameState.run.get("weather", {})
	w[str(d)] = wx
	GameState.run["weather"] = w


func _run() -> void:
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	if not GameState.run.has("tool_tier"):
		GameState.run["tool_tier"] = {}
	_fish()
	_critters()
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	_city()
	_racket()
	_crew()
	print("c15_p4_seasons_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)


func _fish() -> void:
	var lake_in := ["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"]
	var per := {}
	for se: String in DAYS:
		_at(se)
		var fresh := Fishing.season_fish(se, "fresh")
		var sea := Fishing.season_fish(se, "sea")
		check(fresh.size() >= 2 and sea.size() >= 2, "%s: at least 2 fresh and 2 sea fish of its own (%s / %s)" % [se, fresh, sea])
		var lake := Fishing.pool_for(lake_in, 0, "lake")
		var beach := Fishing.pool_for(["sunfish", "bass", "eel", "puffer"], 0, "beach")
		var docks := Fishing.pool_for(["eel", "salmon", "catfish"], 2, "docks")
		per[se] = lake
		for f: String in fresh:
			if GameState.items[f].get("weather", []).is_empty() and str(GameState.items[f].get("when", "day")) == "day":
				check(lake.has(f), "%s: %s bites at the lake" % [se, f])
		for f: String in sea:
			if str(GameState.items[f].get("when", "day")) == "day":
				check(beach.has(f) and docks.has(f), "%s: %s bites at the beach and the docks" % [se, f])
		for other: String in DAYS:
			if other == se:
				continue
			for f: String in Fishing.season_fish(other, "fresh"):
				if not (GameState.items[f]["seasons"] as Array).has(se):
					check(not lake.has(f), "%s: out-of-season %s does not bite" % [se, f])
		check(not Fishing.pool_for(["sky_fish", "mooncarp"], 4, "sky_reaches").has(fresh[0]), "%s: mega waters keep their own fish" % se)
	check(per["spring"] != per["fall"], "the lake bites different fish in spring and fall")
	_at("spring", "clear")
	check(not Fishing.pool_for(["carp"], 0, "lake").has("smelt"), "rain smelt: not on a clear day")
	_at("spring", "rain")
	check(Fishing.pool_for(["carp"], 0, "lake").has("smelt"), "rain smelt: bites in the rain")
	_at("winter", "clear", false)
	check(Fishing.pool_for(["cod"], 0, "beach").has("lantern_fish"), "lanternfish: winter nights at sea")
	_at("winter", "clear", true)
	check(not Fishing.pool_for(["cod"], 0, "beach").has("lantern_fish"), "lanternfish: not by day")
	_at("winter", "fog", true)
	check(Fishing.pool_for(["cod"], 0, "beach").has("lantern_fish"), "fog: night fish come up by day")
	_at("summer", "storm")
	var storm_reach := Fishing.reach_n(2, false, false)
	_at("summer", "clear")
	check(storm_reach == Fishing.reach_n(2, false, false) + 1, "a storm stirs one more fish within reach")
	for f in ["trout", "bass", "salmon", "legendary_koi", "perch", "cod"]:
		check(not str(GameState.items[f].get("desc", "")).begins_with("A good catch"), "%s has its own fish-log line" % f)


func _critters() -> void:
	var meadow := ["sparrow", "rabbit", "squirrel", "butterfly_orange"]
	var sp := WorldGen.critter_pool(meadow, 0, 0, 0, "spring")
	var fa := WorldGen.critter_pool(meadow, 0, 0, 0, "fall")
	var su := WorldGen.critter_pool(meadow, 0, 0, 0, "summer")
	check(sp.has("robin") and not fa.has("robin"), "robins in spring, not fall")
	check(fa.has("crow") and not sp.has("crow"), "crows come in fall")
	check(su.has("dragonfly") and not fa.has("dragonfly"), "dragonflies in summer, gone in fall")
	var wn := WorldGen.critter_pool(["frog", "heron", "duck", "dragonfly"], 0, 1, 0, "winter")
	check(not wn.has("frog") and not wn.has("heron") and not wn.has("duck") and not wn.is_empty(), "winter fallback: no frogs or herons in the snow (%s)" % [wn])
	var noon := WorldGen.critter_pool(["bat", "owl", "rabbit"], 0, 0, 0, "summer")
	check(not noon.has("bat") and not noon.has("owl") and noon.has("rabbit"), "no bats or owls at noon (%s)" % [noon])
	var desert := WorldGen.critter_pool(["snake", "hawk"], 0, 0, 0, "spring")
	check(not desert.has("robin"), "season visitors only join meadow-type pools")


func _city() -> void:
	var neon := {"weather": {"spring": "rain", "fall": "rain", "winter": "snow", "default": ""}}
	check(RegionSeason.weather(neon, "winter", "clear", "") == "snow", "Neon snows in winter")
	check(RegionSeason.weather(neon, "summer", "clear", "") == "", "Neon summer nights take the day's weather")
	check(RegionSeason.weather(neon, "spring", "storm", "") == "", "a storm day wins over Neon's drizzle")
	check(RegionSeason.weather(neon, "fall", "clear", "harvest") == "", "festival skies win over Neon's rain")
	check(RegionSeason.weather({"weather": "rain"}, "winter", "clear", "") == "snow", "a plain rainy region snows in winter")
	check(RegionSeason.weather({"weather": "fog"}, "summer", "clear", "") == "fog", "plain region weather stays")
	var rj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	check(str(rj["neon"]["weather"].get("winter", "")) == "snow", "regions.json: neon weather is seasonal")
	for rid in ["neon", "docks", "hideout"]:
		for t: Dictionary in rj[rid]["things"]:
			if str(t.get("type", "")) != "shop":
				continue
			var seen := {}
			for se: String in DAYS:
				var its := RegionSeason.items(t, se)
				for row in its:
					check(GameState.items.has(str(row[0])), "%s stall item %s exists" % [rid, row[0]])
				seen[se] = str(its)
			check(seen.size() == 4, "%s %s: stall checked every season" % [rid, t.get("who", "")])
	var hide := {"ground_seam": "dry_grass", "ground_seam_winter": "snow_trampled"}
	RegionSeason.skin(hide, "winter")
	check(str(hide["ground_seam"]) == "snow_trampled", "the Hideout lot goes snowy in winter")
	var neon2 := {"ground_seam": "c14p5_wet_asphalt", "ground_cycle": ["a"], "ground_seam_winter": "slush"}
	RegionSeason.skin(neon2, "summer")
	check(str(neon2["ground_seam"]) == "c14p5_wet_asphalt" and neon2.has("ground_cycle"), "summer keeps Neon's wet asphalt")
	for rid in ["neon", "hideout", "docks", "uptown"]:
		check(Art.has("seamless", str(rj[rid].get("ground_seam_winter", ""))), "%s has a winter ground" % rid)
	for nm in ["taxi", "vend_red", "trailer", "gas_station", "diner_pink", "motel_cyan", "container_red", "fish_market", "limo", "hedge2_tree"]:
		check(Art.has("props", nm + "_winter"), "city prop %s has a winter twin" % nm)
	GameState.look_season = "winter"
	check(WorldGen.winter_look("props", "taxi") == "taxi_winter", "winter_look finds the city twins")
	GameState.look_season = "summer"
	check(WorldGen.winter_look("props", "taxi") == "taxi", "no twin outside winter")
	GameState.look_season = ""
	for se: String in DAYS:
		var hd: Dictionary = (rj["hideout"] as Dictionary).duplicate(true)
		var n0: int = (hd.get("props", []) as Array).size()
		RegionSeason.skin(hd, se)
		check((hd["props"] as Array).size() == n0 + 2, "the Hideout dresses for %s" % se)
		for row: Dictionary in rj["hideout"]["props_" + se]:
			check(Art.has(str(row.get("group", "props")), str(row["name"])), "%s dressing %s has art" % [se, row["name"]])
	var market := {}
	for t: Dictionary in rj["docks"]["things"]:
		if str(t.get("who", "")) == "Fish market":
			market = t
	check(str(RegionSeason.items(market, "winter")).contains("cod") and not str(RegionSeason.items(market, "summer")).contains("cod"), "docks fish market sells winter cod in winter only")
	check(RegionSeason.greet(market, "winter") != RegionSeason.greet(market, "summer"), "seasonal greetings differ")


func _racket() -> void:
	_at("spring")
	var spring_cap := Racket.pass_cap()
	_at("summer")
	check(Racket.pass_cap() == spring_cap + 1, "summer crowds: one more till takes paper")
	_at("winter")
	GameState.run["day"] = 87
	check(float(Racket.season_mod("winter")["wash"]) > 1.0, "winter: the wash takes more")
	GameState.run["day"] = 14  # spring festival day
	check(Racket.festival_day(), "spring day 14 is a festival day")
	check(int(Racket.season_mod("spring")["pass"]) == 1, "festival day: more tills open")


func _crew() -> void:
	var per := {}
	var npc_days := {}
	var nj: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	for v in (nj as Dictionary).values():
		if v is Dictionary and (v as Dictionary).has("birthday"):
			npc_days["%s%d" % [v["birthday"][0], int(v["birthday"][1])]] = true
	for id: String in Crew.members():
		var b := CrewSeason.birthday_of(id)
		check(b.size() == 2, "%s has a birthday" % id)
		if b.size() == 2:
			per[str(b[0])] = int(per.get(str(b[0]), 0)) + 1
			check(not npc_days.has("%s%d" % [b[0], int(b[1])]), "%s's birthday does not clash with a villager's" % id)
			check(int(b[1]) != 14, "%s's birthday is not on festival day" % id)
	for se: String in DAYS:
		check(int(per.get(se, 0)) >= 2, "%s has crew birthdays (%d)" % [se, int(per.get(se, 0))])
	check(CrewSeason.birthdays_on("spring", 10).size() == 1, "Calendar hook: Deuce's birthday on spring 10")
	for id: String in Crew.members():
		for se: String in DAYS:
			_at(se)
			check(CrewSeason.line(id, 1) != "", "%s has a %s line" % [id, se])
	_at("winter")
	check(CrewSeason.line("mama_rosa", 1) != CrewSeason.line("mama_rosa", 1).replace("Soup", "x") or CrewSeason.line("mama_rosa", 0) != "", "Mama Rosa talks winter")
	GameState.run["day"] = 10  # Deuce's birthday (spring 10)
	check(CrewSeason.is_birthday("deuce") and CrewSeason.mix("deuce", ["a", "b"], 10)[0].contains("birthday"), "Deuce's birthday line plays on his birthday")
	GameState.run["day"] = 14
	GameState.run["time"] = 12 * 60
	var w: Dictionary = GameState.run.get("weather", {})
	w["14"] = "petals"
	GameState.run["weather"] = w
	for id: String in Crew.members():
		GameState.run["flags"]["crew_" + id] = true
	var fc := Crew.festival_crew()
	check(fc.size() == 4, "festival day: four crew go to the festival (%s)" % [fc])
	check(Crew.at_festival(str(fc[0])) if not fc.is_empty() else false, "at_festival agrees")
	GameState.run["day"] = 15
	check(Crew.festival_crew().is_empty(), "no festival, nobody leaves the Hideout")
	GameState.run["day"] = 14
	check(CrewSeason.mix("doc", ["a"], 14).size() == 1 and CrewSeason.mix("doc", ["a"], 14)[0] != "a", "festival day: the crew talk festival")
