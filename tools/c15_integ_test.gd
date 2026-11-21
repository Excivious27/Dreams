extends SceneTree
## C15 integration hooks (calendar <-> villagers, town, crew, music, talk).
##   godot --headless --fixed-fps 60 --path . -s res://tools/c15_integ_test.gd
## - the new festival ids start on their days (GameState.festival_today) in both arcs
## - beach/farm/city festivals don't pull the town onto the plaza (Calendar.town_festival_today,
##   Npc.in_festival, festival_place, Talk "festival"); plaza festivals do
## - one festival per day in every year 1..6 for both arcs (comet vs gilt_gala)
## - SeasonCal is Calendar; crew birthdays on the gang calendar; GameState.birthday_of crew fallback
## - festival songs: new ids resolve to their row stand-in (penguins) / gang songs (gangsters)
## - talk: villagers without own lines get the shared lines for the new plaza festivals
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(1515)
	Campaign.bypass = true
	_run.call_deferred()


func _day(se: String, d: int, yr := 1) -> void:
	GameState.run["day"] = Calendar.abs_day(se, d, yr)
	Calendar.reload()


func _run() -> void:
	for ar in ["penguins", "gangsters"]:
		GameState.new_run(ar, "penguin_m" if ar == "penguins" else "pax", "Test", "Testville", "Pup")
		GameState.run["weather"] = {}
		# New plaza festivals start on their days.
		for p: Array in [["spring", 24, "blossom"], ["fall", 27, "hollow"], ["winter", 10, "winter_market"], ["winter", 28, "gift_swap"]]:
			_day(p[0], p[1])
			check(GameState.festival_today() == p[2], "%s: %s on %s %d (got '%s')" % [ar, p[2], p[0], p[1], GameState.festival_today()])
			check(Calendar.town_festival_today() == p[2], "%s: %s is a plaza festival" % [ar, p[2]])
			check(SeasonCal.festival_for_day(int(GameState.run["day"])).get("id", "") == p[2], "%s: SeasonCal = Calendar for %s" % [ar, p[2]])
		_day("summer", 7, 2)
		check(GameState.festival_today() == "founders", "%s: founders in year 2" % ar)
		# Beach festival: festival_today but the town stays as it is.
		_day("summer", 24)
		check(GameState.festival_today() == "tide_feast", "%s: tide_feast on summer 24" % ar)
		check(Calendar.town_festival_today() == "", "%s: tide_feast is not a plaza festival" % ar)
		check(not Npc.in_festival(12.0), "%s: town villagers stay put during tide_feast" % ar)
		check(Npc.festival_place("maple", 12.0) == "", "%s: Maple not on the plaza during tide_feast" % ar)
		check(not Talk.key_ok("festival"), "%s: no 'going to the plaza' chatter on tide_feast" % ar)
		# Plaza festival: the town goes.
		_day("spring", 14)
		check(Npc.in_festival(12.0) and Npc.festival_place("maple", 12.0) != "", "%s: egg festival fills the plaza" % ar)
		check(Talk.key_ok("festival"), "%s: festival chatter on the egg festival" % ar)
		# One festival a day, years 1..6.
		for yr in range(1, 7):
			for se in Calendar.SEASONS:
				for d in range(1, 29):
					var n := 0
					for e: Dictionary in Calendar.events_on(se, d, yr, ar):
						if str(e["kind"]) == "festival":
							n += 1
					check(n <= 1, "%s: %d festivals on %s %d year %d" % [ar, n, se, d, yr])
		# Songs.
		var fb := MusicResolve.festival_track("blossom", true, ar)
		check(fb != "", "%s: blossom has a song" % ar)
		if ar == "penguins":
			check(fb == "festival_night", "penguins: blossom night plays its stand-in festival_night (got %s)" % fb)
		else:
			check(not fb.begins_with("festival_egg") and not fb.begins_with("festival_star") and fb != "festival_night_2", "gangsters: no penguin fair tune for blossom (got %s)" % fb)
		check(MusicResolve.festival_track("comet", true, ar) != "", "%s: comet has a song" % ar)
		# Talk: a villager with own lines but none for blossom gets the shared ones.
		_day("spring", 24)
		var pool := Talk.festival_pool("maple")
		check(not pool.is_empty(), "%s: Maple has Blossom Dance lines" % ar)
	# Crew birthdays (gang calendar) and the triple-gift fallback.
	GameState.new_run("gangsters", "pax", "Test", "Testville", "Pup")
	Calendar.reload()
	var bd := CrewSeason.birthday_of("marlene")
	check(bd.size() == 2, "marlene has a crew birthday")
	if bd.size() == 2:
		check(GameState.birthday_of("marlene") == bd, "GameState.birthday_of falls back to the crew birthday")
		var ids: Array = Calendar.events_on(str(bd[0]), int(bd[1]), 1, "gangsters").map(func(e: Dictionary) -> String: return str(e["id"]))
		check("bday_marlene" in ids, "crew birthday on the gang calendar (%s)" % [ids])
		var pids: Array = Calendar.events_on(str(bd[0]), int(bd[1]), 1, "penguins").map(func(e: Dictionary) -> String: return str(e["id"]))
		check(not "bday_marlene" in pids, "no crew birthday on the penguin calendar")
	if fails == 0:
		print("c15_integ_test: OK")
	quit(1 if fails else 0)
