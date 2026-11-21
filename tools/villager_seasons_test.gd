extends SceneTree
## CONDUCT 15 P3: villager seasonal life. Every town villager has >= 3 lines per
## season and one line per festival, a birthday and a festival-eve line; the
## seasonal Talk parts (early/late/first/eve/birthday/y1/y2/weekend, the seasonal
## weathers) hold on the right days; every weather in WEATHER_ODDS is a known part;
## kids skip school in summer, at weekends and on snow days; nobody gardens or
## fishes the river in winter; the festival crowd spreads over the plaza spots;
## friend gifts by mail are never out-of-season crops; the festival-eve letter
## gives the real hours; spring scenes stay in spring, nothing fires in festival
## hours, every season has its own scenes and year 2 adds more; the outfit
## festival fallback uses the real festival day.
##   godot --headless --fixed-fps 60 --path . -s res://tools/villager_seasons_test.gd
var fails := 0
const SEASONS := ["spring", "summer", "fall", "winter"]
const FESTS := {"spring": "egg", "summer": "lantern", "fall": "harvest", "winter": "star"}


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(1515)
	_run.call_deferred()


func _setup(arc: String, day: int, hour: float, weather := "clear") -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = day
	GameState.run["time"] = int(hour * 60)
	GameState.run["weather"] = {str(day): weather, str(day + 1): weather}


func _town() -> Array:
	var out: Array = []
	for k in GameState.npcs:
		var d: Dictionary = GameState.npcs[k]
		if str(d.get("home_scene", "")) in ["", "town"] and not (d.get("routine", []) as Array).is_empty():
			out.append(str(k))
	out.sort()
	return out


## Day number for season index si, day of season ds, year y.
func _day(si: int, ds: int, y := 1) -> int:
	return (y - 1) * 112 + si * 28 + ds


func _run() -> void:
	_setup("penguins", 5, 10.0)
	var town := _town()
	check(town.size() >= 15, "town villagers found (%d)" % town.size())

	# --- data coverage: lines per season, per festival, birthday, eve ---
	for id: String in town:
		var blk: Dictionary = Talk.data().get(id, {})
		for se: String in SEASONS:
			var n := 0
			for key: String in blk:
				if se in key.split("&") and not "gangsters" in key.split("&"):
					n += (blk[key] as Array).size()
			check(n >= 3, "%s has >= 3 %s lines (%d)" % [id, se, n])
			var fk := "festival_" + str(FESTS[se])
			var fn := 0
			for key: String in blk:
				if fk in key.split("&"):
					fn += 1
			check(fn >= 1 or id == "juniper" and blk.has("festival"), "%s has a %s line" % [id, fk])
		check(blk.has("birthday"), "%s has a birthday line" % id)
		check(blk.has("eve"), "%s has a festival-eve line" % id)
		if blk.has("gangsters"):
			for se: String in SEASONS:
				var g := false
				for key: String in blk:
					if "gangsters" in key.split("&") and se in key.split("&"):
						g = true
				check(g or not id in ["maple", "gideon", "alder", "sal", "finn", "lumi", "hazel", "bram", "posy", "rook"], "%s has a gangsters&%s line" % [id, se])
	# generic "festival" lines don't name one festival
	var bad := RegEx.create_from_string("(?i)\\b(egg|turnip|pies?|lanterns?|star|harvest)\\b")
	for id: String in Talk.data():
		for key: String in Talk.data()[id]:
			if key.split("&").has("festival"):
				for l in Talk.data()[id][key]:
					check(bad.search(str(l)) == null, "%s generic festival line names one festival: %s" % [id, l])

	# --- every seasonal weather is a known Talk part ---
	for se: String in GameState.WEATHER_ODDS:
		for pair in GameState.WEATHER_ODDS[se]:
			var w := str(pair[0])
			_setup("penguins", _day(SEASONS.find(se), 5), 10.0, w)
			check(Talk.part_ok(w), "weather %s is a Talk part on a %s day" % [w, w])

	# --- every town villager has a winter walker (or an all-season sheet) ---
	for id: String in town:
		check(CharacterLibrary.has_character("npc_%s_winter" % id) or CharacterLibrary.has_character("npc_%s_all" % id), "%s has a winter walker" % id)

	# --- seasonal Talk parts ---
	_setup("penguins", _day(1, 1), 10.0)
	check(Talk.part_ok("first") and Talk.part_ok("early") and not Talk.part_ok("late") and Talk.part_ok("y1") and not Talk.part_ok("y2"), "summer 1: first/early/y1")
	_setup("penguins", _day(2, 24, 2), 10.0)
	check(Talk.part_ok("late") and not Talk.part_ok("early") and Talk.part_ok("y2") and Talk.year() == 2, "fall 24 year 2: late/y2 (year %d)" % Talk.year())
	_setup("penguins", _day(0, 13), 10.0)
	check(Talk.part_ok("eve"), "spring 13 is a festival eve")
	_setup("penguins", _day(0, 6), 10.0)  # day 6 = Saturday
	check(Talk.part_ok("weekend") and not Talk.part_ok("weekday"), "day 6 is a weekend (weekday %d)" % GameState.weekday())
	# birthdays: the speaker's own line wins
	for id: String in ["maple", "pip", "finn"]:
		var b := GameState.birthday_of(id)
		if b.size() != 2:
			continue
		_setup("penguins", _day(SEASONS.find(str(b[0])), int(b[1])), 10.0)
		check(not Talk.birthday_pool(id).is_empty(), "%s has birthday lines on their birthday" % id)
		_setup("penguins", _day(SEASONS.find(str(b[0])), int(b[1])) + 1, 10.0)
		check(Talk.birthday_pool(id).is_empty(), "%s's birthday lines only on the day" % id)
	# at runtime each season's pool really has seasonal lines, both arcs
	for arc: String in ["penguins", "gangsters"]:
		for si in 4:
			_setup(arc, _day(si, 5), 10.0)
			var blk: Dictionary = Talk.data()["maple"]
			var seasonal := 0
			for l in Talk.own_pool("maple"):
				for key: String in blk:
					if SEASONS[si] in key.split("&") and (blk[key] as Array).has(l):
						seasonal += 1
						break
			check(seasonal >= 3, "[%s] maple's %s pool has >= 3 seasonal lines (%d)" % [arc, SEASONS[si], seasonal])

	# --- seasonal routines ---
	_setup("penguins", _day(1, 3), 10.0)  # summer weekday
	var pip_r: Array = GameState.npcs["pip"]["routine"]
	var pip_now := Npc.place_now(pip_r, "pip")
	check(not pip_now in ["school", "school_yard"], "summer weekday 10:00: Pip is not at school (%s)" % pip_now)
	_setup("penguins", _day(0, 3), 10.0)  # spring weekday
	var spring_pip := Npc.season_place("pip", "school", 10.0)
	check(spring_pip == "school", "spring weekday: school stays school (%s)" % spring_pip)
	_setup("penguins", _day(0, 6), 10.0)  # spring Saturday
	check(Npc.season_place("pip", "school", 10.0) != "school", "Saturday: no school")
	_setup("penguins", _day(3, 3), 10.0, "snow")
	check(Npc.season_place("tobin", "school", 10.0) != "school", "snow day: no school")
	_setup("penguins", _day(3, 5), 12.0)  # clear winter noon
	for id: String in town:
		var p := Npc.place_now(GameState.npcs[id]["routine"], id)
		check(not p in Npc.GARDEN_SPOTS and not p in ["river_n", "river_s"], "winter noon: %s is not gardening or river fishing (%s)" % [id, p])
	check(Npc.season_activity("bench_nw", "sit") == "look" and Npc.season_activity("wren_garden", "garden") == "look", "winter: no sitting on snowy benches or hoeing")
	_setup("penguins", _day(1, 6), 13.0)
	check(Npc.season_activity("beach_road", "look") == "picnic", "summer beach road is a picnic")

	# --- festival crowd spreads evenly ---
	for si in 4:
		_setup("penguins", _day(si, 14), 19.5 if si in [1, 3] else 12.0)
		var count := {}
		for id: String in town:
			var fp := Npc.festival_place(id, GameState.run["time"] / 60.0)
			if fp != "" and fp != "fountain":
				count[fp] = int(count.get(fp, 0)) + 1
		var most := 0
		for k in count:
			most = maxi(most, int(count[k]))
		check(not count.is_empty() and most <= ceili(float(town.size()) / Npc.FEST_SPOTS.size()) + 1, "%s festival: at most %d per spot (%s)" % [FESTS[SEASONS[si]], most, count])

	# --- mail: friend gifts in season, eve letter hours ---
	_setup("penguins", _day(3, 5), 7.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out_season := 0
	for i in 200:
		GameState.run["day"] = _day(3, 1 + i % 27)
		for who: String in ["hazel", "posy", "maple", "bram", "lumi", "finn"]:
			var g := Mail._gift_item(who, rng)
			if not GameState.crop_in_season(g):
				out_season += 1
	check(out_season == 0, "200 winter mornings of gifts: no out-of-season crop (%d)" % out_season)
	for si in 4:
		_setup("penguins", _day(si, 13), 7.0)
		var fid: String = FESTS[SEASONS[si]]
		var txt := Mail.eve_letter(fid, _day(si, 14))
		GameState.run["day"] = _day(si, 14)
		var fh := Npc.festival_hours(fid)
		GameState.run["day"] = _day(si, 13)
		var from := GameState.clock_of(int(round(fh.x * 60.0)))
		check(from in txt and not "nine till six" in txt, "%s eve letter gives the real hours (%s): %s" % [fid, from, txt])
	_setup("gangsters", _day(2, 13), 7.0)
	check(Mail.eve_letter("harvest", _day(2, 14)).begins_with("Word from the hall"), "gang eve letter in the block's voice")

	# --- events: seasons, festival hours, year 2 ---
	for si in 4:
		_setup("penguins", _day(si, 10), 12.0)
		var town_evs := 0
		for ev in Events.data():
			if str(ev.get("scene", "")) == "town" and str(ev.get("when", {}).get("season", "")) == SEASONS[si]:
				town_evs += 1
		check(town_evs >= 2, "%s has >= 2 town scenes (%d)" % [SEASONS[si], town_evs])
	for ev in Events.data():
		if str(ev["id"]) in ["ev_prices", "ev_kids_secret", "ev_seed_pack", "ev_painting"]:
			check(str(ev["when"].get("season", "")) == "spring", "%s stays in spring" % ev["id"])
	_setup("penguins", _day(2, 10), 15.0)  # fall day 10: no spring scene eligible
	GameState.add_friend("maple", 1000)
	for id in Events.eligible("town", 15.0):
		check(not id in ["ev_prices", "ev_kids_secret", "ev_seed_pack", "ev_painting", "ev_goat"], "fall: spring scene %s not eligible" % id)
	_setup("penguins", _day(0, 14), 12.0)  # Egg Festival hours
	check(Events.eligible("town", 12.0).is_empty(), "nothing fires in festival hours (%s)" % [Events.eligible("town", 12.0)])
	_setup("penguins", _day(2, 10, 1), 12.0)
	var y1 := Events.eligible("town", 12.0)
	_setup("penguins", _day(2, 10, 2), 12.0)
	var y2 := Events.eligible("town", 12.0)
	check("ev_fall_ledger" in y2 and not "ev_fall_ledger" in y1, "year-2 scene only in year 2 (y1 %s, y2 %s)" % [y1, y2])
	check("ev_fall_press" in y1, "fall year-1 scene eligible in fall (%s)" % [y1])

	# --- seasonal side stories: due only in their season ---
	var ss := {"spring_beds": ["wren", 0], "summer_shells": ["lumi", 1], "fall_soup": ["bram", 2], "winter_tarts": ["posy", 3]}
	for cid: String in ss:
		var giver: String = ss[cid][0]
		var si: int = ss[cid][1]
		_setup("penguins", _day(si, 8), 12.0)
		var d := SideStory.due(giver)
		check(not d.is_empty() and str(d[0]["id"]) == cid, "%s due from %s in its season (%s)" % [cid, giver, d])
		_setup("penguins", _day((si + 1) % 4, 8), 12.0)
		var d2 := SideStory.due(giver)
		check(d2.is_empty() or str(d2[0]["id"]) != cid, "%s not due out of season" % cid)
	# --- spouse: festival and season lines, both arcs ---
	var sp_id := str(Romance.candidates()[0]) if not Romance.candidates().is_empty() else ""
	check(sp_id != "", "a romance candidate exists")
	for arc: String in ["penguins", "gangsters"]:
		_setup(arc, _day(3, 14), 12.0)
		var pool: Dictionary = Romance.SPOUSE_SEASON if arc == "penguins" else Romance.SPOUSE_SEASON_GANG
		check((pool["festival"] as Array).has(Romance.spouse_line(sp_id)), "[%s] spouse festival line" % arc)
		_setup(arc, _day(2, 1), 8.0)
		check((pool["fall"] as Array).has(Romance.spouse_line(sp_id)), "[%s] spouse line on Fall 1 is a fall line" % arc)

	print("villager_seasons_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
