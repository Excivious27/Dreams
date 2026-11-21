extends SceneTree
## C15 P1: seasonal weather rules (scripts/game_state.gd weather section).
##   godot --headless --fixed-fps 60 --path . -s res://tools/weather_c15_test.gd
## - every save has its own weather (wx_seed): two saves with the same town name differ
## - each season rolls only its own weathers (no snow in summer, no fireflies in winter), both arcs;
##   the city (gangster arc) has its own odds: fewer petals/fireflies, more fog than the valley
## - forecast == tomorrow's actual weather
## - a lingering wet front never turns into a heat wave (sun right after rain/storm only by the base roll)
## - special weather: at most one rolled special a season, year-2+ ones never in year 1, first snow
##   only on a snow day; names per arc
## - snow depth builds on snow/blizzard, melts on dry days, 0 outside winter
## - heat wave: an unwatered crop is set back a day overnight (report heat_dried); a watered one isn't
## - weather_here() without a sky map = weather_today()
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(1515)
	Campaign.bypass = true
	_run.call_deferred()


func _cal(ar: String, days: int) -> Array:
	var out: Array = []
	for d in range(1, days + 1):
		GameState.run["day"] = d
		out.append(GameState.weather_today())
	return out


func _run() -> void:
	var legal := {"spring": ["rain", "storm", "fog", "petals", "wind", "clear"], "summer": ["rain", "storm", "sun", "fireflies", "wind", "fog", "clear"],
		"fall": ["rain", "storm", "fog", "leaves", "wind", "clear"], "winter": ["snow", "blizzard", "fog", "wind", "clear"]}
	var counts := {}
	for ar in ["penguins", "gangsters"]:
		GameState.new_run(ar, "penguin_m" if ar == "penguins" else "pax", "Test", "Dreamhollow", "Pup")
		var a := _cal(ar, 448)
		GameState.new_run(ar, "penguin_m" if ar == "penguins" else "pax", "Test", "Dreamhollow", "Pup")
		var b := _cal(ar, 112)
		var same := 0
		for i in 112:
			same += 1 if a[i] == b[i] else 0
		check(same < 100, "%s: two Dreamhollow saves have different weather (%d/112 same)" % [ar, same])
		var c := {}
		for i in a.size():
			var se := GameState.season_of(i + 1)
			check(str(a[i]) in legal[se], "%s day %d: %s is a %s weather" % [ar, i + 1, a[i], se])
			c[a[i]] = int(c.get(a[i], 0)) + 1
		counts[ar] = c
		# Forecast is tomorrow's weather.
		for d in range(1, 60):
			GameState.run["day"] = d
			var fc := GameState.forecast()
			GameState.run["day"] = d + 1
			check(GameState.weather_today() == fc, "%s day %d forecast == actual" % [ar, d])
		# Specials: at most one rolled special per season-year (first snow apart), year gates.
		GameState.run["day"] = 1
		var seen := {}
		for d in range(1, 337):
			var sp := GameState.special_weather(d)
			if sp == "" or sp == "first_snow":
				if sp == "first_snow":
					check(GameState.weather_for(d) in ["snow", "blizzard"], "%s day %d first snow on a snow day" % [ar, d])
				continue
			var key := "%s:%d" % [GameState.season_of(d), (d - 1) / 112]
			check(not seen.has(key), "%s: one %s special per season (%s)" % [ar, key, sp])
			seen[key] = sp
			if sp in ["meteor_shower", "harvest_moon", "aurora_night"]:
				check(d > 112, "%s: %s is year 2+ (day %d)" % [ar, sp, d])
			check(GameState.special_weather_name(sp) != "", "%s: %s has a name" % [ar, sp])
		check(not seen.is_empty(), "%s: some special weather in three years" % ar)
		# Snow depth.
		GameState.run["day"] = 85  # winter 1
		GameState.run["weather"] = {"85": "blizzard"}
		GameState.run["snow_depth"] = 0
		GameState._snow_depth_step()
		check(int(GameState.run["snow_depth"]) == 2, "%s: blizzard adds 2 snow" % ar)
		GameState.run["weather"] = {"85": "snow"}
		GameState._snow_depth_step()
		GameState._snow_depth_step()
		check(int(GameState.run["snow_depth"]) == 3, "%s: snow caps at 3" % ar)
		GameState.run["weather"] = {"85": "clear"}
		GameState._snow_depth_step()
		check(int(GameState.run["snow_depth"]) == 2 and GameState.snow_depth() == 2, "%s: a clear day melts 1" % ar)
		check(GameState.run["flags"].has("first_snow_1"), "%s: first snow of year 1 logged" % ar)
		GameState.run["day"] = 10
		check(GameState.snow_depth() == 0, "%s: no snow depth in spring" % ar)
		check(GameState.weather_here() == GameState.weather_today(), "%s: weather_here without a sky map" % ar)
	# The city's own odds.
	var pc: Dictionary = counts["penguins"]
	var gc: Dictionary = counts["gangsters"]
	check(int(gc.get("petals", 0)) < int(pc.get("petals", 0)), "city has fewer petal days (%d vs %d)" % [gc.get("petals", 0), pc.get("petals", 0)])
	check(int(gc.get("fog", 0)) > int(pc.get("fog", 0)), "city has more fog (%d vs %d)" % [gc.get("fog", 0), pc.get("fog", 0)])
	# Heat wave dries unwatered crops.
	GameState.new_run("penguins", "penguin_m", "Test", "Heatville", "Pup")
	var cid := ""
	for k: String in GameState.crops:
		if GameState.crop_fits_season(GameState.crops[k], "summer") and GameState.crop_fits_season(GameState.crops[k], "fall") and int(GameState.crops[k].get("days", 0)) >= 6 and not bool(GameState.crops[k].get("tree", false)):
			cid = k
			break
	check(cid != "", "a summer crop exists")
	GameState.run["day"] = 40
	GameState.run["weather"] = {"40": "sun", "41": "clear"}
	GameState.run["farm"]["20,20"] = {"crop": cid, "days": 3, "watered": false}
	GameState.run["farm"]["21,20"] = {"crop": cid, "days": 3, "watered": true}
	var rep := GameState.sleep()
	check(int(GameState.run["farm"]["20,20"]["days"]) == 2 and int(rep.get("heat_dried", 0)) >= 1, "heat wave sets an unwatered crop back (days %d)" % int(GameState.run["farm"]["20,20"]["days"]))
	check(int(GameState.run["farm"]["21,20"]["days"]) >= 4, "a watered crop grows in the heat")
	print("weather_c15_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
