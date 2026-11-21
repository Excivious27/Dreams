extends SceneTree
## C15 P1: the Calendar (scripts/calendar.gd).
##   godot --headless --fixed-fps 60 --path . -s res://tools/calendar_test.gd
## - every season x both arcs x years 1-3: events_on lists the festival/holiday/marina/event/
##   market rows of data (festivals.json or the classic four + calendar.json) on their days only,
##   year_min / every gating (year-2 rows absent in year 1), arc gating, birthdays from npcs.json
## - GameState.festival_today() == Calendar on every day 1..336 and only on festival days;
##   Npc.festival_hours follows the row hours; festival weather is forced on festival days
## - eve() is true the day before, board_notices lists tomorrow's events, year()/day_of_year()
## - no two plaza festivals share a day; no festival collides with a market on the same day
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	seed(15)
	Campaign.bypass = true
	_run.call_deferred()


func _rows() -> Array:
	var seen := {}
	var out: Array = []
	for r in Calendar.festival_rows():
		seen[str(r["id"])] = true
		out.append(r)
	for r in Calendar.calendar_rows():
		if not seen.has(str(r["id"])):
			out.append(r)
	return out


func _run() -> void:
	for ar in ["penguins", "gangsters"]:
		GameState.new_run(ar, "penguin_m" if ar == "penguins" else "pax", "Test", "Testville", "Pup")
		GameState.run["weather"] = {}
		Calendar.reload()
		var rows := _rows()
		check(rows.size() >= 4, "%s: calendar has rows (%d)" % [ar, rows.size()])
		# Every season has at least one plaza festival and the classic four keep their ids.
		for se in Calendar.SEASONS:
			var n := 0
			for r in rows:
				if str(r["season"]) == se and str(r.get("kind", "")) == "festival" and str(r.get("arc", "both")) in ["both", ar]:
					n += 1
			check(n >= 1, "%s %s has a festival" % [ar, se])
		for id in ["egg", "lantern", "harvest", "star"]:
			check(not Calendar.find(id).is_empty(), "%s classic festival %s present" % [ar, id])
		# Data <-> events_on, years 1..3.
		for yr in [1, 2, 3]:
			for r: Dictionary in rows:
				var se := str(r["season"])
				var d := int(r["day"])
				var ids: Array = Calendar.events_on(se, d, yr, ar).map(func(e: Dictionary) -> String: return str(e["id"]))
				var want := Calendar.row_ok(r, yr, ar)
				check((str(r["id"]) in ids) == want, "%s y%d %s %s %d listed=%s want=%s" % [ar, yr, r["id"], se, d, str(r["id"]) in ids, want])
			# Year gates actually exist (calendar.json carries year-2+ rows).
		var y2 := 0
		for r in rows:
			if int(r.get("year_min", 1)) >= 2 and str(r.get("arc", "both")) in ["both", ar]:
				y2 += 1
				check(not Calendar.row_ok(r, 1, ar), "%s %s absent in year 1" % [ar, r["id"]])
				check(Calendar.row_ok(r, int(r["year_min"]), ar) or int(r.get("every", 1)) > 1 or r.has("needs"), "%s %s present in its year" % [ar, r["id"]])
		check(y2 >= 2, "%s: at least two year-2+ rows (%d)" % [ar, y2])
		# Arc gating: another arc's own rows never show.
		var other := "gangsters" if ar == "penguins" else "penguins"
		for r in rows:
			if str(r.get("arc", "both")) == other:
				var ids: Array = Calendar.events_on(str(r["season"]), int(r["day"]), 3, ar).map(func(e: Dictionary) -> String: return str(e["id"]))
				check(not (str(r["id"]) in ids) or _shared(rows, str(r["id"]), ar), "%s does not show %s's %s" % [ar, other, r["id"]])
		# Day by day over three years: festival_today matches, one festival a day, hours, weather.
		for day in range(1, 337):
			GameState.run["day"] = day
			var se := GameState.season()
			var dos := GameState.day_of_season()
			var fest := Calendar.festival_on(se, dos)
			check(GameState.festival_today() == str(fest.get("id", "")), "%s day %d festival_today" % [ar, day])
			var nf := 0
			for e: Dictionary in Calendar.events_on(se, dos):
				if e["kind"] == "festival":
					nf += 1
				if e["kind"] == "market" and not fest.is_empty():
					check(false, "%s day %d market on a festival day" % [ar, day])
			check(nf <= 1, "%s day %d at most one plaza festival (%d)" % [ar, day, nf])
			if not fest.is_empty():
				var fh := Npc.festival_hours()
				check(fh.y > fh.x and fh.x >= 6.0 and fh.y <= 24.0, "%s day %d festival hours %s" % [ar, day, fh])
				var fw := str((fest["row"] as Dictionary).get("weather", ""))
				if fw != "":
					check(GameState.weather_for(day) == fw, "%s day %d festival weather %s (got %s)" % [ar, day, fw, GameState.weather_for(day)])
			else:
				check(Npc.festival_hours() == Vector2.ZERO, "%s day %d no festival hours" % [ar, day])
			check(Calendar.year() == (day - 1) / 112 + 1 and GameState.year() == Calendar.year(), "%s day %d year" % [ar, day])
			# Eve: anything tomorrow -> eve(id) and the board names it.
			var tm := Calendar.tomorrow()
			for e: Dictionary in tm:
				check(Calendar.eve(str(e["id"])), "%s day %d eve(%s)" % [ar, day, e["id"]])
			if not tm.is_empty():
				check(Calendar.board_notices(7).contains(str(tm[0]["name"])), "%s day %d board names tomorrow's %s" % [ar, day, tm[0]["name"]])
		# Birthdays come from npcs.json.
		var b: Array = GameState.birthday_of("maple")
		if b.size() == 2:
			var ids: Array = Calendar.events_on(str(b[0]), int(b[1]), 1, ar).map(func(e: Dictionary) -> String: return str(e["id"]))
			check("bday_maple" in ids, "%s maple's birthday on the calendar" % ar)
		# Gang names differ from penguin names for the classic festivals.
		if ar == "gangsters":
			check(Calendar.find("egg")["name"] != "Egg Festival", "gang egg festival has its own name (%s)" % Calendar.find("egg")["name"])
	print("calendar_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## A row id that the arc also has (e.g. a "both" row with the same id).
func _shared(rows: Array, id: String, ar: String) -> bool:
	for r in rows:
		if str(r["id"]) == id and str(r.get("arc", "both")) in ["both", ar]:
			return true
	return false
