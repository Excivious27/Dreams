extends SceneTree
## Round 13 world/time checks (headless): fainting before 10pm wakes you at 10pm
## the same day (and costs tomorrow's quarter bar); after 10pm or at 2am it's the
## next morning. Mornings are dawn (never night-dark) with a warm glow fading by
## mid-morning, in every season. Region names exist for every map.
##   godot --headless --path . -s res://tools/r13_world_test.gd
var fails := 0


func _ok(cond: bool, what: String) -> void:
	if not cond:
		print("  FAIL ", what)
		fails += 1


func _initialize() -> void:
	GameState.load_data()
	GameState.new_run("penguins", "kairi", "T", "Dreamhollow", "Pup")
	var r := GameState.run
	# Faint at 3pm: 10pm, same day, patched up, some energy.
	r["day"] = 5
	r["time"] = 15 * 60
	r["hp"] = 0
	r["energy"] = 0
	_ok(Faint.to_evening("hurt"), "3pm faint goes to the evening")
	_ok(int(r["time"]) == 22 * 60 and int(r["day"]) == 5, "wakes 10pm same day (got day %d %s)" % [int(r["day"]), GameState.clock_text()])
	_ok(int(r["hp"]) > 0 and int(r["energy"]) >= mini(20, int(r["max_energy"]) / 8), "patched up with energy to get home")  # C16a P3: min(20, max/8)
	GameState.sleep(false)
	_ok(int(r["day"]) == 6 and int(r["energy"]) == int(r["max_energy"]) * 3 / 4, "the night after a faint still costs a quarter bar (%d)" % int(r["energy"]))
	# After 10pm, and the 2am collapse: no evening wake.
	r["time"] = 23 * 60
	_ok(not Faint.to_evening("hurt"), "11pm faint sleeps through to morning")
	r["time"] = 17 * 60
	_ok(not Faint.to_evening("late"), "2am collapse is the end of the night")
	# Mornings: dawn, not night; warm glow at sunrise, gone by mid-morning.
	for day in [1, 31, 59, 87]:
		r["day"] = day
		var sr := GameState.sunrise()
		_ok(GameState.darkness(GameState.DAY_START) <= GameState.DAWN_DARK + 0.001, "day %d: 6am darkness %.2f is dawn, not night" % [day, GameState.darkness(GameState.DAY_START)])
		_ok(GameState.darkness(sr) < 0.01, "day %d: light at sunrise" % day)
		_ok(GameState.morning_glow(sr) > 0.99, "day %d: full glow at sunrise" % day)
		_ok(GameState.morning_glow(sr + 75) > 0.2 and GameState.morning_glow(sr + 75) < 0.8, "day %d: glow fading mid-way" % day)
		_ok(GameState.morning_glow(sr + 150) < 0.01, "day %d: plain daylight by mid-morning" % day)
		_ok(GameState.morning_glow(GameState.sunset() + 30) == 0.0, "day %d: no morning glow at dusk" % day)
		_ok(GameState.darkness(GameState.full_dark()) > 0.99, "day %d: night still dark" % day)
	# Region names.
	for id: String in PlaceNames.NAMES:
		_ok(str(PlaceNames.NAMES[id]) != "", "name for " + id)
	_ok(PlaceNames.for_id("community_farm") == "Dreamhollow Commons", "community farm label (%s)" % PlaceNames.for_id("community_farm"))
	r["interior"] = "rec"
	_ok(PlaceNames.for_id("interior") == RecCenter.name(), "rec center label (%s)" % PlaceNames.for_id("interior"))
	r["interior"] = "rec_up"
	_ok(PlaceNames.for_id("interior").begins_with(RecCenter.name()), "rec lanes label (%s)" % PlaceNames.for_id("interior"))
	_ok(PlaceNames._title("deuce's arcade") == "Deuce's Arcade", "door hint titled (%s)" % PlaceNames._title("deuce's arcade"))
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	_ok(PlaceNames.for_id("community_farm") == "Westside Lot Garden", "lot garden label (%s)" % PlaceNames.for_id("community_farm"))
	_ok(PlaceNames.for_id("crystal_meadow") == "The Outskirts", "outskirts label")
	print("r13_world_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
