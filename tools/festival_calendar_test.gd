extends SceneTree
## CONDUCT 15 P6: the festival year (data/festivals.json, FestivalWords, FestivalExtra rules).
## Years 1-3 x 4 seasons x both arcs: 2+ festivals and 1+ holiday a season, one venue festival a
## day per scene, no festival on a villager birthday, year-gated rows (founders/moon jellies y2+,
## comet every 3rd year), marina rows need their tier, arc names and hosts, hours from the row,
## crop rivals grow by year (capped), dance/sculpt/secret-partner rules.
##   godot --headless --fixed-fps 60 --path . -s res://tools/festival_calendar_test.gd
const TownS := preload("res://scripts/town.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(15)
	_run.call_deferred()


func _run() -> void:
	var rows: Array = FestivalWords.rows()
	check(rows.size() >= 18, "festivals.json has the full year (%d rows)" % rows.size())
	var keys := ["id", "season", "day", "kind", "arc", "name", "name_gang", "venue", "hours", "closes_shops", "year_min", "every", "weather", "host", "host_gang", "handler", "stall", "prize_pool", "music", "needs"]
	for r: Dictionary in rows:
		for k: String in keys:
			check(r.has(k), "%s has %s" % [r.get("id", "?"), k])
		check(str(r["hours"]) in ["day", "evening", "night", "allday"], "%s hours word" % r["id"])
		check(str(r["kind"]) in ["festival", "holiday", "marina"], "%s kind" % r["id"])
		check(Music.has_track(str(r["music_fallback"])), "%s music fallback %s exists" % [r["id"], r["music_fallback"]])
	for id: String in ["egg", "lantern", "harvest", "star"]:
		check(int(FestivalWords.def(id).get("day", 0)) == 14, "%s keeps day 14 (saves)" % id)
	# Birthdays never share a festival day.
	var bdays := {}
	var nf := FileAccess.open("res://data/npcs.json", FileAccess.READ)
	var npcs: Variant = JSON.parse_string(nf.get_as_text())
	if npcs is Dictionary:
		for id in npcs:
			var v: Variant = npcs[id]
			if v is Dictionary and (v as Dictionary).has("birthday"):
				var b: Array = v["birthday"]
				bdays["%s_%d" % [b[0], int(b[1])]] = str(id)
	check(bdays.size() >= 20, "birthdays read (%d)" % bdays.size())
	for r: Dictionary in rows:
		if str(r["kind"]) != "holiday":
			var k := "%s_%d" % [r["season"], int(r["day"])]
			check(not bdays.has(k), "%s (%s) not on %s's birthday" % [r["id"], k, bdays.get(k, "")])
	# Per year, season, arc (needs ignored: marina tiers are a separate check).
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		for year in [1, 2, 3]:
			for se: String in ["spring", "summer", "fall", "winter"]:
				var fests := 0
				var hols := 0
				for d in range(1, 29):
					var on: Array = FestivalWords.rows_on(se, d, year, arc, false)
					var venues := {}
					for r: Dictionary in on:
						if str(r["kind"]) == "holiday":
							hols += 1
						else:
							fests += 1
							var sc := str(r["venue"]["scene"])
							check(not venues.has(sc), "%s y%d %s %d: one festival at %s" % [arc, year, se, d, sc])
							venues[sc] = true
				check(fests >= 2, "%s y%d %s: 2+ festivals (%d)" % [arc, year, se, fests])
				check(hols >= 1, "%s y%d %s: a holiday (%d)" % [arc, year, se, hols])
		var ids := func(se: String, d: int, y: int) -> Array:
			return FestivalWords.rows_on(se, d, y, arc, false).map(func(r: Dictionary) -> String: return str(r["id"]))
		check(not "founders" in ids.call("summer", 7, 1) and "founders" in ids.call("summer", 7, 2), "%s: Founders' Day from year 2" % arc)
		check(not "moon_jellies" in ids.call("summer", 27, 1) and "moon_jellies" in ids.call("summer", 27, 2), "%s: moon jellies from year 2" % arc)
		check(not "comet" in ids.call("winter", 21, 2) and "comet" in ids.call("winter", 21, 3) and not "comet" in ids.call("winter", 21, 4) and "comet" in ids.call("winter", 21, 6), "%s: comet night years 3, 6" % arc)
		# Marina rows need the marina tier.
		GameState.run["day"] = 1
		check(FestivalWords.rows_on("fall", 9, 1, arc).is_empty(), "%s: no derby without the marina" % arc)
		Marina.st()["tier"] = 2
		check(not FestivalWords.rows_on("fall", 9, 1, arc).is_empty(), "%s: derby with marina tier 2" % arc)
		check(FestivalWords.rows_on("summer", 18, 1, arc).is_empty(), "%s: regatta needs tier 3" % arc)
		# Arc words.
		var pen := arc == "penguins"
		check(FestivalWords.name_of("egg") == ("Egg Festival" if pen else "Block Party"), "%s egg name %s" % [arc, FestivalWords.name_of("egg")])
		check(FestivalWords.name_of("gift_swap") == ("Gift Swap Feast" if pen else "Year's End Swap"), "%s gift swap name" % arc)
		check(FestivalWords.host_of("egg") == ("Mayor Alder" if pen else "Dice"), "%s egg host %s" % [arc, FestivalWords.host_of("egg")])
		check(("envelope" in FestivalWords.egg_hint(false)) != pen, "%s egg hint word" % arc)
		check(not FestivalWords.again_text("hollow").is_empty(), "%s again line" % arc)
	# Hours from the row.
	var ss := GameState.sunset() / 60.0
	check(FestivalWords.hours_of("egg") == Vector2(9, 18), "egg runs 9-6")
	check(is_equal_approx(FestivalWords.hours_of("lantern").x, ss - 4.0), "lantern is an evening festival")
	check(is_equal_approx(FestivalWords.hours_of("hollow").x, ss), "hollow is a night festival")
	# Egg count: 12 in year 1, 16 (one golden) from year 2.
	GameState.run["day"] = 14
	check(FestivalWords.egg_count() == 12, "12 eggs in year 1")
	GameState.run["day"] = 126
	check(FestivalWords.egg_count() == 16 and "Sixteen" in FestivalWords.egg_call(), "16 eggs from year 2")
	# Crop rivals: harder every year, capped.
	var last := -1
	for y in [1, 2, 3, 5, 12]:
		GameState.run["day"] = 70 + (y - 1) * 112
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var sc := TownS.rival_score(120, rng)
		check(sc > last or sc == 260, "rival score grows by year (y%d %d)" % [y, sc])
		check(sc <= 260, "rival score capped")
		last = sc
	# Blossom Dance rules.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 24
	check(FestivalExtra.dance_calls() == FestivalExtra.dance_calls() and FestivalExtra.dance_calls().size() == 4, "dance calls seeded")
	check(FestivalExtra.dance_gain(4) > FestivalExtra.dance_gain(2) and FestivalExtra.dance_gain(2) > FestivalExtra.dance_gain(0), "dance gain by score")
	check(FestivalExtra.dance_partners().is_empty(), "no partners with no hearts")
	var ids2: Array = GameState.npcs.keys().filter(func(k: Variant) -> bool: return Hearts.in_arc(str(k)))
	GameState.run["friendship"][str(ids2[0])] = GameState.HEART_POINTS * 5
	GameState.run["friendship"][str(ids2[1])] = GameState.HEART_POINTS * 6
	check(FestivalExtra.dance_partners().size() == 2, "4+ hearts can dance (%d)" % FestivalExtra.dance_partners().size())
	# Snow sculpt: variety counts.
	GameState.run["day"] = 10
	check(FestivalExtra.sculpt_score([0, 1, 2]) > FestivalExtra.sculpt_score([0, 0, 0]), "varied sculptures score higher")
	# Gift swap partner: stable for a year, not the same two years running.
	for i in 6:
		GameState.run["friendship"][str(ids2[i])] = 50
	var p1 := FestivalExtra.secret_partner(1)
	check(p1 != "" and p1 == FestivalExtra.secret_partner(1), "secret partner stable")
	for y in range(2, 8):
		GameState.run["flags"]["gift_swap_y%d" % (y - 1)] = FestivalExtra.secret_partner(y - 1)
		check(FestivalExtra.secret_partner(y) != FestivalExtra.secret_partner(y - 1), "partner changes in year %d" % y)
	check(FestivalExtra.handles("blossom") and not FestivalExtra.handles("egg"), "FestivalExtra handles the new town festivals")
	# FestivalSky modes for the off-plaza festivals (jellies with a gold one from year 3, comet, fireworks).
	GameState.run["day"] = 1 + 2 * 112 + 56 + 26
	var host := Node2D.new()
	root.add_child(host)
	var fj := FestivalSky.make(host, "jellies", Rect2(0, 0, 200, 100))
	var fc := FestivalSky.make(Node2D.new(), "comet")
	var bad := FestivalSky.make(Node2D.new(), "nope")
	await process_frame
	check(fj._jel.size() >= 5 and bool(fj._jel[0][3]), "jellies drift, a gold one in year 3")
	check(fc.mode == "comet" and bad.mode == "", "comet mode kept, unknown mode off")
	var p0: Vector2 = fj._jel[1][0]
	for k in 30:
		await process_frame
	check((fj._jel[1][0] as Vector2) != p0, "jellies move on game time")
	print("festival_calendar_test: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
