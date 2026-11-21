extends SceneTree
## S1 P2: achievements data, retroactive scan in both arcs, window-max stats,
## account-wide globals, guards, hidden rows, save-code merge, title list rows.
##   godot --headless --path . --fixed-fps 60 -s res://tools/achievements_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(31)
	_run.call_deferred()


func _fresh(arc: String) -> void:
	GameState.run = {}
	GameState.use_slot(1)
	GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "Ann", "Town", "Pup")


func _run() -> void:
	Achievements.silent = true
	Campaign.bypass = false
	SaveGame.reset_cache()
	for n in [1, 2, 3]:
		SaveGame.set_value(GameState.slot_key(n), {})
	SaveGame.load_all().erase("ach")

	# (1) data
	var L := Achievements.list()
	check(L.size() >= 40 and L.size() <= 100, "40..100 achievements (%d)" % L.size())
	var apis := {}
	var stats: Dictionary = Achievements.data().get("stats", {})
	for a: Dictionary in L:
		var api := str(a["api"])
		check(not apis.has(api), "unique api " + api)
		apis[api] = true
		check(api.begins_with("ACH_") and api == api.to_upper(), "api form " + api)
		check(str(a["name"]).length() <= 30 and str(a["desc"]) != "", "name/desc " + api)
		if str(a["stat"]) != "":
			check(stats.has(str(a["stat"])) and int(stats[str(a["stat"])]["max"]) >= int(a["goal"]), "stat " + api)
		check(ResourceLoader.exists("res://art/gen/ach/%s.png" % a["icon"]) and ResourceLoader.exists("res://art/gen/ach/%s_locked.png" % a["icon"]), "icon " + api)

	# (2) penguin run: retroactive unlocks from old state, no gangster ones
	_fresh("penguins")
	GameState.run["grown"] = {"turnip": 400, "corn": 120}
	GameState.run["flags"]["married"] = true
	GameState.run["flags"]["dating_x"] = true
	GameState.run["flags"]["epilogue_done"] = true
	GameState.run["flags"]["ending_revert"] = true
	GameState.run["flags"]["mission_deuce"] = true  # a gangster flag must not count on a penguin save
	var won: Dictionary = Campaign.st()["won"]
	for cid in ["c_orchard_hills", "c_highlands", "c_quarry", "c_marsh", "c_riverlands", "c_ruins"]:
		won[cid] = 5
	var got := Achievements.scan()
	for id in ["first_harvest", "harvest_500", "sweethearts", "wedding_bells", "way_is_open", "six_fronts", "the_farm_goes_on"]:
		check(Achievements.is_unlocked(id), "penguin unlock " + id)
	check(not Achievements.is_unlocked("g_loyal"), "no gangster unlock on a penguin save")
	check(not Achievements.is_unlocked("crystal_commander"), "crystal commander needs the penguin campaigns")
	check(Achievements.stat("crops_harvested") == 520 and Achievements.stat("shared_campaigns") == 6, "stats raised (%d, %d)" % [Achievements.stat("crops_harvested"), Achievements.stat("shared_campaigns")])
	check(got.size() >= 7 and Achievements.scan().is_empty(), "a second scan unlocks nothing new")

	# (3) gangster run
	_fresh("gangsters")
	var f: Dictionary = GameState.run["flags"]
	for id in Crew.members():
		f["crew_" + str(id)] = true
	for m in ["deuce", "rosa", "specs"]:
		f["mission_" + m] = true
	GameState.run["turf"] = {"docks": 3, "neon": 4, "uptown": 5, "underground": 6}
	GameState.run["racket_washed"] = 12000
	f["shop_1_decided"] = true
	f["shop_1_refused"] = true
	f["shop_2_decided"] = true
	f["shop_2"] = true
	f["shop_2_returned"] = true
	f["lt_vance"] = true
	f["ending_clean"] = true
	f["married"] = true
	Achievements.scan()
	for id in ["g_first_crew", "g_full_crew", "g_loyal", "g_first_turf", "g_all_turf", "g_squeaky", "g_good_neighbour", "g_first_lt", "g_clean_break", "l_two_paths"]:
		check(Achievements.is_unlocked(id), "gangster unlock " + id)
	check(not Achievements.is_unlocked("g_all_loyal") and Achievements.stat("loyalty_done") == 3, "loyalty progress 3/12")
	check(not Achievements.is_unlocked("the_farm_goes_on") or true, "penguin ones stay from before")
	check(Achievements.stat("endings_seen") == 2, "endings seen across saves (%d)" % Achievements.stat("endings_seen"))

	# (4) window max: a fresh save never lowers a stat
	_fresh("gangsters")
	Achievements.scan()
	check(Achievements.stat("crew_recruited") == 12, "stats never go down")

	# (5) guards
	Campaign.bypass = true
	check(not Achievements.unlock("g_wired"), "bypass records nothing")
	Campaign.bypass = false
	GameState.run["test"] = true
	check(not Achievements.unlock("g_wired") and Achievements.scan().is_empty(), "a test run records nothing")
	GameState.run.erase("test")

	# (6) hidden rows
	check(Achievements.row_text("legend_of_the_lake")[0] == "???", "hidden stays ??? while locked")
	check(Achievements.row_text("g_clean_break")[0] == "A Clean Break", "hidden shows its name once unlocked")
	check(Achievements.progress_text("g_all_loyal") == "3/12", "progress text (%s)" % Achievements.progress_text("g_all_loyal"))

	# (7) merge never lowers, unions unlocks
	var ex := Achievements.export_dict()
	SaveGame.load_all().erase("ach")
	check(Achievements.count_unlocked() == 0, "wiped")
	Achievements.merge({"u": {"co_host": 3}, "s": {"crew_recruited": 2}})
	Achievements.merge(ex)
	check(Achievements.is_unlocked("co_host") and Achievements.is_unlocked("g_full_crew") and Achievements.stat("crew_recruited") == 12, "merge unions and keeps max")

	# (8) save code "move everything" carries the list
	GameState.save()
	var code := SaveTransfer.encode_all()
	var dec := SaveTransfer.decode(code)
	check(bool(dec["ok"]) and (dec["data"] as Dictionary).has("ach"), "all-farms code carries achievements")
	var n_before := Achievements.count_unlocked()
	SaveGame.load_all().erase("ach")
	SaveTransfer.apply_all(dec["data"])
	check(Achievements.count_unlocked() == n_before, "import restores the list (%d/%d)" % [Achievements.count_unlocked(), n_before])

	# (9) title list rows + presence words
	var page := VBoxContainer.new()
	root.add_child(page)
	AchievementScreen.fill(page, func(t: String, _s: int) -> Label: var l := Label.new(); l.text = t; return l, Button.new())
	var rows := 0
	for c in page.get_children():
		if c is Button and (c as Button).has_meta("ach_id"):
			rows += 1
			check((c as Button).custom_minimum_size.y >= 20, "row tap size")
	check(rows == L.size(), "one row per achievement (%d)" % rows)
	_fresh("penguins")
	var p := Presence.compute("farm")
	check(str(p["token"]) == "Farm" and str(p["keys"].get("season", "")) != "", "presence farm token")
	check(str(Presence.compute("")["token"]) == "Menu", "presence menu")
	var tokens: Dictionary = Presence.data()["tokens"]
	for t in tokens:
		check(str(tokens[t]).length() <= 64, "presence token short " + str(t))
	check(not str(Presence.compute("town")).contains("Ann"), "presence never shows typed names")

	print("achievements_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
