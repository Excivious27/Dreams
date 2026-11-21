extends SceneTree
## C13 contract: the song resolver (Music.resolve / MusicResolve.pick), GameState.weekday /
## day_name / story_stage, Music.sfx_log, the gang sfx swap, played-name mix rules and
## jingle arbitration, Music.mood. Fake track lists keep it independent of which songs
## have landed.   godot --headless --fixed-fps 60 --path . -s res://tools/music_resolve_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(13)
	GameState.load_data()
	_run.call_deferred()


func _ctx(arc: String, extra := {}) -> Dictionary:
	var c := {"arc": arc, "season": "spring", "phase": "day", "weather": "clear", "stage": 1, "day": 3}
	c.merge(extra, true)
	return c


func _run() -> void:
	var R := MusicResolve
	R.fake_tracks = ["farm", "farm_fall", "winter", "night", "night_gang", "rain", "town", "shop", "shop_gang",
		"house", "docks", "docks_night", "uptown", "morning"]
	var farm := {"shared_night": true, "shared_weather": true, "season_alias": {"fall": "farm_fall", "winter": "winter"}}
	# Penguin farm: seasons, legacy farm_fall / winter, shared night / rain / snow.
	check(R.pick("farm", _ctx("penguins", farm)) == "farm", "penguin farm spring day -> farm")
	check(R.pick("farm", _ctx("penguins", farm.merged({"season": "fall"}))) == "farm_fall", "penguin farm fall -> farm_fall")
	check(R.pick("farm", _ctx("penguins", farm.merged({"season": "winter"}))) == "winter", "penguin farm winter -> winter")
	check(R.pick("farm", _ctx("penguins", farm.merged({"phase": "night"}))) == "night", "penguin valley night -> night")
	check(R.pick("farm", _ctx("penguins", farm.merged({"phase": "dawn"}))) == "morning", "penguin valley dawn -> morning")
	check(R.pick("farm", _ctx("penguins", farm.merged({"weather": "storm"}))) == "rain", "storm falls back to rain")
	check(R.pick("town", _ctx("penguins", {"shared_night": true, "shared_weather": true, "weather": "snow", "season": "winter"})) == "winter", "penguin snow day -> winter")
	# Gang arc: never the penguin seasonal pieces; its own night; never a penguin _gang miss.
	check(R.pick("farm", _ctx("gangsters", farm.merged({"season": "fall"}))) == "farm", "gang farm fall (no gang set) -> farm, not farm_fall")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"season": "winter"}))) == "farm", "gang farm winter -> farm, not winter")
	check(R.pick("town", _ctx("gangsters", {"shared_night": true, "shared_weather": true, "weather": "snow", "season": "winter"})) == "town", "gang snow day -> not winter")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"phase": "night"}))) == "night_gang", "gang valley night -> night_gang")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"phase": "dawn"}))) == "farm", "gang dawn never plays the penguin morning")
	check(R.pick("shop_gang", _ctx("penguins")) == "shop", "penguin arc never plays a _gang file")
	check(R.pick("shop", _ctx("gangsters")) == "shop_gang", "gang arc prefers <name>_gang")
	check(R.pick("docks", _ctx("gangsters", {"phase": "night"})) == "docks_night", "hub night song")
	check(R.pick("uptown", _ctx("gangsters", {"phase": "night"})) == "uptown", "no hub night song -> base (no shared night off the valley)")
	check(R.pick("nothing_here", _ctx("penguins")) == "", "unknown base -> ''")
	R.fake_tracks = ["farm", "night", "night_gang", "night_summer", "town", "town_night", "sky", "mega_sky_night"]
	check(R.pick("farm", _ctx("penguins", farm.merged({"phase": "night", "season": "summer"}))) == "night_summer", "shared seasonal night (penguin)")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"phase": "night", "season": "summer"}))) == "night_gang", "gang never hears night_summer")
	check(R.pick("town", _ctx("penguins", {"shared_night": true, "phase": "night", "season": "summer"})) == "town_night", "an area's own night beats the shared one")
	R.fake_tracks = ["inn", "inn_evening", "shop", "shop_weekend", "house", "house_rain", "house_winter"]
	check(R.pick("inn", _ctx("penguins", {"evening": true})) == "inn_evening", "dusk band -> inn_evening")
	check(R.pick("shop", _ctx("penguins", {"weekday": 5})) == "shop_weekend", "Saturday -> shop_weekend")
	check(R.pick("shop", _ctx("penguins", {"weekday": 2})) == "shop", "Wednesday -> shop")
	check(R.pick("house", _ctx("penguins", {"weather": "rain", "season": "winter"})) == "house_rain", "rain beats season indoors")
	check(R.pick("house", _ctx("penguins", {"season": "winter"})) == "house_winter", "winter house")
	R.fake_tracks = ["farm", "night", "night_gang", "night_summer", "town", "town_night", "sky", "mega_sky_night"]
	check(R.pick("sky", _ctx("penguins", {"phase": "night", "night_group": "mega_sky_night"})) == "mega_sky_night", "group night (sky islands)")
	# When gang family songs land, the penguin seasonal is skipped for the gang set.
	R.fake_tracks = ["farm", "farm_fall", "farm_gang", "farm_fall_gang", "farm_spring_gang", "night_gang", "farm_after", "farm_after_gang"]
	check(R.pick("farm", _ctx("gangsters", farm.merged({"season": "fall"}))) == "farm_fall_gang", "gang fall set -> farm_fall_gang")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"season": "summer"}))) == "farm_gang", "gang summer (no slot) -> farm_gang, never farm")
	check(R.pick("farm", _ctx("penguins", farm.merged({"season": "summer"}))) == "farm", "penguin with gang files around -> farm")
	check(R.pick("farm", _ctx("penguins", farm.merged({"stage": 99}))) == "farm_after", "epilogue -> farm_after")
	check(R.pick("farm", _ctx("gangsters", farm.merged({"stage": 99}))) == "farm_after_gang", "gang epilogue -> farm_after_gang")
	# Rotation: stable all day, a new take the next day, every take reached in a week.
	R.fake_tracks = ["town", "town_2", "town_3", "lake", "lake_2"]
	var seen := {}
	for d in range(1, 15):
		var a := R.pick("town", _ctx("penguins", {"day": d}))
		check(a == R.pick("town", _ctx("penguins", {"day": d})), "same day -> same take (day %d)" % d)
		check(a != R.pick("town", _ctx("penguins", {"day": d + 1})), "next day -> a different take (day %d)" % d)
		check(R.pick("lake", _ctx("penguins", {"day": d})) != R.pick("lake", _ctx("penguins", {"day": d + 1})), "2 takes alternate daily (day %d)" % d)
		seen[a] = true
	check(seen.size() == 3, "every rotation take plays within two weeks (%d)" % seen.size())
	R.fake_tracks = []
	# GameState APIs.
	GameState.run = {"arc": "penguins", "day": 1, "time": 600, "flags": {}}
	check(GameState.weekday() == 0 and GameState.day_name() == "Mon", "day 1 is Mon")
	GameState.run["day"] = 7
	check(GameState.weekday() == 6 and GameState.day_name() == "Sun", "day 7 is Sun")
	GameState.run["day"] = 8
	check(GameState.weekday() == 0, "day 8 is Mon again")
	check(GameState.story_stage() >= 0 and GameState.story_stage() < 99, "story_stage before the epilogue")
	GameState.run["flags"]["epilogue_done"] = true
	check(GameState.story_stage() == 99, "story_stage 99 after the epilogue")
	GameState.run["flags"].erase("epilogue_done")
	# Real tracks: Music.resolve on a real song name answers a real song.
	check(Music.resolve("farm") != "" and Music.has_track(Music.resolve("farm")), "Music.resolve(farm) is a real song")
	# Music.sfx: log, played-name mix, jingle arbitration, mood.
	var m := Music.instance(self)
	for k in 10:
		await process_frame
	m.clear_sfx_log()
	m.sfx("no_such_sound_xyz", "ui_click" if m.has_sfx("ui_click") else "pickup")
	var e: Dictionary = m.sfx_log[-1]
	check(e["asked"] == "no_such_sound_xyz" and bool(e["fallback"]) and not bool(e["dropped"]) and str(e["played"]) != "no_such_sound_xyz", "fallback logged with the PLAYED name: %s" % e)
	m.sfx("quest_done")
	check(not bool(m.sfx_log[-1]["dropped"]), "first jingle plays")
	await create_timer(0.2).timeout
	m.sfx("levelup")
	check(not bool(m.sfx_log[-1]["dropped"]), "a higher jingle (levelup) cuts in over quest_done")
	await create_timer(0.2).timeout
	m.sfx("quest_done")
	check(bool(m.sfx_log[-1]["dropped"]), "a lower jingle inside 2.5 s is dropped")
	check(m.sfx_log.size() <= 64, "log capped")
	GameState.run["arc"] = "gangsters"
	m.sfx("pickup")
	check(not bool(m.sfx_log[-1]["arc_swap"]) or m.has_sfx("pickup_gang"), "arc swap only when a _gang take exists")
	GameState.run["arc"] = "penguins"
	check(m.mood("no_such_mood_xyz") == "", "missing mood -> '' (area song carries on)")
	check(m.mood("") == "" and m.held() == "", "empty mood -> '' and nothing held")
	# C13 integration hooks.
	check(Music._is_jingle("j_victory_gang") and Music._is_jingle("levelup_gang") and Music._is_jingle("quest_done_gang"), "gang jingle twins count as jingles (duck + arbitrate)")
	check(not Music._is_jingle("j_buy_gang") and not Music._is_jingle("j_confirm_gang"), "j_buy/j_confirm gang twins stay plain sfx")
	for g: String in ["carpet", "metal", "ice"]:
		check(Music.STEP_GROUND_DB.has(g) and float(Music.STEP_GROUND_DB[g]) < 0.0, "step ground %s has its quieter level" % g)
	R.fake_tracks = ["keeper", "keeper_2", "boss_president", "boss_president_2", "boss_dark_crystal", "boss_dark_crystal_2"]
	for d in range(1, 9):
		check(R.pick("keeper", _ctx("penguins", {"day": d})) == "keeper", "keeper_2 never in daily rotation (day %d)" % d)
		check(R.pick("boss_president", _ctx("gangsters", {"day": d})) == "boss_president", "boss_*_2 never in daily rotation (day %d)" % d)
		check(R.pick("boss_dark_crystal", _ctx("penguins", {"day": d})) == "boss_dark_crystal", "boss_dark_crystal_2 kept for phase 2 (day %d)" % d)
	R.fake_tracks = []
	for pr: Array in [["bakery", "bakery"], ["library", "library"], ["museum", "museum"], ["workshop", "workshop"], ["gilt_casino", "casino"]]:
		check(str(GameMap.INTERIOR_MUSIC.get(pr[0], "")) == pr[1], "interior %s asks its own song %s" % pr)
		check(GameMap.INTERIOR_FALLBACK.has(pr[1]), "interior song %s has a fallback" % pr[1])
	print("music_resolve_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
