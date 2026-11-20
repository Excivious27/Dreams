extends SceneTree
## CONDUCT 8 P4: fishing rules (Fishing), mining curve (Mining), reward tables
## (Secrets caches/loot tiers/pages, quest and boss pay). Pure table checks: no maps.

var fails := 0


func _initialize() -> void:
	seed(808)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _share(pool: Array, lvl: int, tier: int, fish: String, n := 4000, rare := 0.0, night := false, baited := false) -> float:
	var hit := 0
	for i in n:
		if Fishing.pick(pool, lvl, night, baited, tier, rare) == fish:
			hit += 1
	return float(hit) / n


func _run() -> void:
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	if not GameState.run.has("tool_tier"):
		GameState.run["tool_tier"] = {}
	# --- Fishing pools ---
	var sky := Fishing.pool_for(["sky_fish", "sky_fish", "mooncarp"], 4)
	check(not sky.has("minnow") and not sky.has("sunfish"), "mega pool keeps its own fish (no minnow/sunfish)")
	var lake := Fishing.pool_for(["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"], 0)
	check(not lake.has("minnow"), "lake has 3 commons of its own: no forced minnow")
	var pond := Fishing.pool_for(["salmon", "eel"], 0)
	check(pond.has("minnow") and pond.has("sunfish"), "a valley water short of commons gets minnow + sunfish")
	check(_share(lake, 2, 0, "bass") > 0.15, "Finn's bass bites at the lake at Fishing 2 (%.2f)" % _share(lake, 2, 0, "bass"))
	var forest := Fishing.pool_for(["minnow", "trout", "carp"], 0)
	check(_share(forest, 2, 0, "trout") > 0.1, "trout bites at the forest stream at Fishing 2")
	# --- Area ceiling: signature fish reachable mid-game ---
	var falls := Fishing.pool_for(["ice_pike", "ice_pike", "trout", "salmon"], 4)
	var gilt := Fishing.pool_for(["carp", "ember_koi", "goldfish"], 4)
	check(_share(falls, 5, 4, "ice_pike") > 0.03, "Glacier Pike bites at Fishing 5 in Frost Falls")
	check(_share(gilt, 8, 4, "ember_koi") > 0.02, "Ember Koi bites at Fishing 8 in Gilt Gardens")
	check(_share(gilt, 2, 4, "ember_koi") == 0.0, "but not at Fishing 2")
	# --- Rare Catch now picks from the top (night: mooncarp only bites after dark) ---
	GameState.run["time"] = 23 * 60
	lake = Fishing.pool_for(["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"], 0)
	check(not lake.has("goldfish") and lake.has("mooncarp"), "night pool: mooncarp in, goldfish out")
	var lo := _share(lake, 8, 0, "mooncarp", 4000, 0.0)
	var hi := _share(lake, 8, 0, "mooncarp", 4000, 0.4)
	check(hi > lo + 0.05, "Rare Catch 40%% lifts the top fish (%.3f -> %.3f)" % [lo, hi])
	GameState.run["time"] = 10 * 60
	check(not Fishing.pool_for(["goldfish", "mooncarp"], 0).has("mooncarp"), "day pool: no mooncarp")
	# --- Window by fish ---
	check(Fishing.window_for("minnow") > Fishing.window_for("sky_fish"), "rare fish bite for a shorter window")
	GameState.run["tool_tier"]["rod"] = 3
	check(Fishing.window_for("sky_fish") > Fishing.window_for("sky_fish") - 0.001 and Fishing.ceiling(1, false, false, 0) == 25 + 15 + 30, "rod tier lifts the ceiling (+10/tier)")
	GameState.run["tool_tier"]["rod"] = 0
	check(Fishing.xp_for("sky_fish") > Fishing.xp_for("minnow") and Fishing.xp_for("boot") < Fishing.xp_for("minnow"), "XP grows with the fish's value")
	# --- Lighthouse scope ---
	GameState.run["flags"]["lighthouse_lit"] = true
	GameState.run["time"] = 23 * 60
	check(not Fishing.night_here("farm") and not Fishing.night_here("frost_falls"), "the lighthouse night bonus stays at the lake and sea")
	# --- Legendary Koi has a home ---
	lake = Fishing.pool_for(["carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish", "starfin", "mooncarp"], 0)
	var koi := 0
	for i in 6000:
		if Fishing.pick(lake, 10, true, true, 0, 0.0, "lake") == "legendary_koi":
			koi += 1
	check(koi > 0, "Legendary Koi bites at the lit lake at night, baited, Fishing 10 (%d / 6000)" % koi)
	check(Fishing.pick(lake, 9, true, true, 0, 0.0, "farm") != "legendary_koi", "never elsewhere")
	# --- Bait only where it matters ---
	check(not Fishing.bait_helps(Fishing.pool_for(["minnow", "sunfish"], 0), 10, false, 0), "no bait spent on a fished-out pond")
	check(Fishing.bait_helps(lake, 1, false, 0), "bait spent where it opens a fish")
	# --- Treasure scaled by water ---
	var t0 := 0
	for i in 2000:
		var it := Fishing.treasure("farm", 0)
		if it == "pearl":
			t0 += 1
	check(t0 == 0, "no pearls from the farm pond")
	# --- Mining curve ---
	var prev := 0
	var mono := true
	for t in Mining.PICK_SWING.size():
		GameState.run["tool_tier"]["pickaxe"] = t
		var s := Mining.pick_swing()
		mono = mono and s > prev
		prev = s
	check(mono, "every pickaxe upgrade swings harder")
	GameState.run["tool_tier"]["pickaxe"] = 4
	var php := Mining.mega_rock_hp("platinum", 5)
	check(ceili(float(php) / Mining.pick_swing()) >= 2 and ceili(float(php) / Mining.pick_swing()) <= 4, "platinum takes 2-4 swings with its gate pick (hp %d)" % php)
	GameState.run["tool_tier"]["pickaxe"] = 7
	check(ceili(float(php) / Mining.pick_swing()) < ceili(float(php) / 5.0), "a better pick breaks mega ore faster")
	check(Mining.gem_chance(true) <= Mining.gem_chance(false), "stone rolls gems less than ore")
	# --- Secrets ---
	for t in 6:
		var c := Secrets.cache_for("secret_dig_x_%d" % t, t)
		var v := GameState.item_value(str(c[0])) * int(c[1])
		check(v <= Secrets.CACHE_BUDGET[t] * 2 + 10 and (not Secrets.CACHE_SINGLE.has(str(c[0])) or int(c[1]) == 1), "cache tier %d: %s x%d (%d)" % [t, c[0], c[1], v])
	check(Secrets.loot_tier(4, false) == 2 and Secrets.loot_tier(4, true) == 4, "safe hubs hide loot two tiers lower")
	check(not (Secrets.LOOT[5] as Dictionary).has("moon_shard"), "moon shards stay a moon find")
	var peng := Secrets.pages_total()
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var gang := Secrets.pages_total()
	var want := 0
	for rid: String in Secrets.PAGES:
		if not rid.begins_with("colony_") and not (rid in Secrets.PENG_ONLY):
			want += 1
	for rid: String in Secrets.POCKET_PAGES:
		if Secrets._area_here(rid):
			want += 1
	for rid: String in HiddenArea.SANCTUMS:
		if Secrets._area_here(rid):
			want += 1
	check(gang == want and peng > 0, "pages_total skips the penguin-only island pages for gangsters (penguins %d, gangsters %d)" % [peng, gang])
	# --- Pay tables ---
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var arc_pay := {"penguins": 0, "gangsters": 0}
	for x: Dictionary in q["main"]:
		var a := str(x.get("arc", ""))
		if arc_pay.has(a):
			arc_pay[a] += int(x.get("reward", {}).get("crystals", 0))
	check(absi(int(arc_pay["penguins"]) - int(arc_pay["gangsters"])) <= 400, "main-line pay matches between arcs (%s)" % str(arc_pay))
	var e: Dictionary = GameState.enemy_data.get("enemies", {})
	check(int(e.get("thug_cyber", {}).get("reward", 99)) <= 10, "gangster thugs pay on the penguin per-hp curve")
	check(int(e.get("rime_wyrm", {}).get("reward", 0)) >= 2000, "mega bosses pay at least their area's chests")
	print("c8_p4_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
