extends SceneTree
## C16a P4 fishing: one koi rule set (Fishing.T has no koi, legends in Collections only), legend level and
## year gates, quality from a quick reel (no star for boots/legends), sizes + "biggest" in the fish log,
## skill mix uses skill_level_eff (a level-100 angler is no better than level 20 on value ceiling).
##   godot --headless --path . --fixed-fps 60 -s res://tools/c16a_p4_fish_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(5)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	ok(not Fishing.T.has("koi"), "the koi has one rule set (Collections LEGENDS)")
	var L: Dictionary = Collections.data()["legends"]
	ok(int(L["legendary_koi"]["year"]) == 3 and int(L["legendary_koi"]["lvl"]) >= 30, "the koi is a year-3 goal")
	ok(int(L["soul_salmon"].get("year", 1)) == 2 and int(L["frost_pike"].get("year", 1)) == 2, "fall/winter legends from year 2")
	# Legend gates: rain at the lake, level 30, year 1 -> never the koi.
	(GameState.run["skills"] as Dictionary)["fishing"] = {"level": 40, "xp": 0}
	GameState.run["day"] = 10
	var koi := 0
	for i in 3000:
		if Collections.legend_roll("lake", "carp", false) == "legendary_koi":
			koi += 1
	ok(koi == 0, "no koi in year 1 even at level 40 (%d)" % koi)
	# Year 3 winter dawn at the lake: the koi can bite; given away before donating, it can come back.
	GameState.run["day"] = 225
	while GameState.season() != "winter":
		GameState.run["day"] = int(GameState.run["day"]) + 1
	GameState.run["time"] = 7 * 60
	var koi3 := 0
	for i in 3000:
		if Collections.legend_roll("lake", "carp", false) == "legendary_koi":
			koi3 += 1
	ok(koi3 > 0, "year 3 winter dawn: the koi can bite (%d)" % koi3)
	if not GameState.run.has("seen"):
		GameState.run["seen"] = {}
	(GameState.run["seen"] as Dictionary)["legendary_koi"] = true
	Collections.st()["caught"]["legendary_koi"] = {"n": 1, "first": 1}
	var back := 0
	for i in 6000:
		if Collections.legend_roll("lake", "carp", false) == "legendary_koi":
			back += 1
	ok(back > 0 and back < koi3 * 2, "a koi given away before donating can come back, rarer (%d)" % back)
	Collections.st()["donated"]["legendary_koi"] = 300
	back = 0
	for i in 3000:
		if Collections.legend_roll("lake", "carp", false) == "legendary_koi":
			back += 1
	ok(back == 0, "once donated, only one koi exists")
	GameState.run["day"] = 10
	# Quality and size.
	ok(Fishing.quality_for(0.05, "carp") == "g", "a snap reel is gold")
	ok(Fishing.quality_for(0.4, "carp") == "s", "a quick reel is silver")
	ok(Fishing.quality_for(0.9, "carp") == "", "a slow reel has no star")
	ok(Fishing.quality_for(0.0, "boot") == "" and Fishing.quality_for(0.0, "legendary_koi") == "", "no star on boots or legends")
	var s0 := Fishing.size_for("minnow")
	var s1 := Fishing.size_for("tuna" if GameState.items.has("tuna") else "salmon")
	ok(s0 > 0 and s1 > s0, "bigger fish are bigger (%d vs %d)" % [s0, s1])
	Collections.record_catch("carp", 1, false, false, 40)
	Collections.record_catch("carp", 1, false, false, 31)
	ok(int(Collections.st()["caught"]["carp"]["best"]) == 40, "fish log keeps the biggest")
	# Effects cap: level 100 = level 20 on the ceiling.
	ok(Fishing.ceiling(GameState.skill_level_eff("fishing"), false, false, 0) == Fishing.ceiling(GameState.LEVEL_EFFECT_CAP, false, false, 0), "ceiling uses the effect cap")
	# Forage (c16a_08-01/08-08): a spot's find never re-rolls on re-entry; the wait follows the picked tier.
	var a := ForageRoll.spot("meadow", "forage_meadow_5_5", false)
	var same := true
	for i in 20:
		same = same and ForageRoll.spot("meadow", "forage_meadow_5_5", false) == a
	ok(a != "" and same, "a forage spot keeps its find across rebuilds (%s)" % a)
	GameState.run["flags"]["forage_meadow_5_5"] = int(GameState.run["day"])  # picked today
	GameState.run["flags"]["forage_meadow_5_5_t"] = 3
	ok(ForageRoll.spot("meadow", "forage_meadow_5_5", false) == "", "picked: regrowing")
	GameState.run["day"] = int(GameState.run["day"]) + 3
	ok(ForageRoll.spot("meadow", "forage_meadow_5_5", false) == "", "a tier-3 find waits longer than 2 days")
	GameState.run["day"] = int(GameState.run["day"]) + 4
	ok(ForageRoll.spot("meadow", "forage_meadow_5_5", false) != "", "and comes back after its wait")
	print("c16a_p4_fish_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
