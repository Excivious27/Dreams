class_name Fishing
extends RefCounted
## Fishing rules (CONDUCT 8 P4). GameMap.fish_at runs the cast/bite/tap; every
## number about WHICH fish bites, how long the bite window is, what treasure
## comes up and how much XP a catch gives lives here, in T.

const T := {
	"cheap_value": 30,          # a fish this cheap or less counts as a "common"
	"commons_min": 2,           # valley waters with fewer commons get minnow + sunfish
	"commons": ["minnow", "sunfish"],
	"cap_base": 25, "cap_per_level": 12,  # C16a P4: 15 -> 12, on skill_level_eff (cap 20)
	 "cap_night": 40, "cap_bait": 10,
	"cap_per_rod": 10,          # each rod upgrade lifts the value ceiling
	"cap_per_luck": 5,          # luck (buff + gear) lifts the ceiling
	"cap_per_area_tier": 30,    # a mega water's own fish are within reach of its tier
	"boot": 0.08,
	"rare_per_luck": 0.03,
	"rare_luck_cap": 0.15,      # luck's share of the Rare Catch chance (c10_07: luck 20 made every cast rare)
	"lit_waters": ["lake", "beach"],  # the lighthouse only draws fish to the lake and sea
	# Bite window by fish band (value <= band[i] -> window[i]); then + escape_less + rod.
	"value_bands": [30, 80, 150, 250, 99999],
	"windows": [1.2, 1.0, 0.8, 0.65, 0.5],
	"window_min": 0.45, "window_per_rod": 0.06,
	# Treasure (chest_chance skill): scaled by the water, items by the water.
	"treasure_mult": [0.35, 0.5, 0.7, 0.85, 1.0, 1.0],
	"treasure_valley": ["old_coin", "map_scrap", "map_scrap"],
	"treasure_sea": ["old_coin", "map_scrap", "pearl"],
	"treasure_deep": ["old_coin", "pearl", "pearl"],   # area tier 3+
	"treasure_decor_p": 0.17,   # share of treasure catches that bring up a decor piece instead
	"sea_waters": ["beach", "colony_coral", "colony_kelp", "colony_ice", "colony_ember", "docks", "the_shoals", "blue_deep"],
	# XP per catch: base + value / per (capped); boots give the floor.
	"xp_base": 3, "xp_per_value": 25, "xp_max": 14, "xp_boot": 2,
	# (C16a P4: the Legendary Koi's one rule set is Collections LEGENDS / gen_collections.py.)
	# Time of day: these only bite by night / by day (the rest any time). Sorted pools
	# that would lose every fish keep them all.
	"when": {"mooncarp": "night", "starfin": "night", "ghost_fish": "night", "sun_trout": "day", "goldfish": "day"},
	# Fallback pools for waters with no list of their own.
	"sea_pool": ["sunfish", "bass", "eel", "puffer", "tuna"],
	"fresh_pool": ["carp", "bass", "catfish", "salmon", "eel"],
}


static func band(fish: String) -> int:
	var v := GameState.item_value(fish)
	var bands: Array = T["value_bands"]
	for i in bands.size():
		if v <= int(bands[i]):
			return i
	return bands.size() - 1


## The water's pool sorted cheapest first; valley waters with too few commons
## get minnow/sunfish, mega and sea waters keep their own fish.
static func pool_for(pool_in: Array, area_tier: int, scene := "") -> Array:
	var pool := []
	for f in pool_in:
		if not pool.has(f) and GameState.items.has(str(f)):
			pool.append(str(f))
	if pool.is_empty():
		pool = (T["fresh_pool"] as Array).duplicate()
	# C15 P4: the season's own fish join home waters and the sea; fish out of
	# season (or out of their weather) don't bite. Never empties a pool.
	var se := GameState.season()
	var wx := GameState.weather_today()
	var water := water_kind(scene, area_tier)
	if water != "":
		for f: String in season_fish(se, water):
			if not pool.has(f):
				pool.append(f)
	var fits := pool.filter(func(f: String) -> bool: return in_season(f, se) and weather_ok(f, wx))
	if not fits.is_empty():
		pool = fits
	var now := "night" if GameState.is_night() else "day"
	if wx == "fog":
		now = "night"  # fog: night fish come up by day too (c15_09-07)
	var timed := pool.filter(func(f: String) -> bool:
		var w := str((T["when"] as Dictionary).get(f, GameState.items.get(f, {}).get("when", now)))
		return w == now or (wx == "fog" and w == "day"))
	if not timed.is_empty():
		pool = timed
	if area_tier <= 0:
		var cheap := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= int(T["cheap_value"])).size()
		if cheap < int(T["commons_min"]):
			for f: String in T["commons"]:
				if not pool.has(f):
					pool.append(f)
	pool.sort_custom(func(a: String, b: String) -> bool: return GameState.item_value(a) < GameState.item_value(b))
	return pool


## "fresh" for valley waters, "sea" for the sea, docks, charters and island seas,
## "" for mega-region waters (they keep their own fish lists).
static func water_kind(scene: String, area_tier: int) -> String:
	if scene == "":
		return ""
	if (T["sea_waters"] as Array).has(scene):
		return "sea"
	return "fresh" if area_tier <= 0 else ""


static var _season_cache := {}


## Seasonal fish (items with "seasons" + "water", gen_mega_new SEASON_FISH) for one season and water.
static func season_fish(se: String, water: String) -> Array:
	var key := se + "/" + water
	if _season_cache.has(key) and int(_season_cache.get("_n", -1)) == GameState.items.size():
		return _season_cache[key]
	if int(_season_cache.get("_n", -1)) != GameState.items.size():
		_season_cache = {"_n": GameState.items.size()}
	var out := []
	for id: String in GameState.items:
		var it: Dictionary = GameState.items[id]
		if str(it.get("type", "")) == "fish" and str(it.get("water", "")) == water and (it.get("seasons", []) as Array).has(se):
			out.append(id)
	out.sort()
	_season_cache[key] = out
	return out


static func in_season(fish: String, se: String) -> bool:
	var s: Variant = GameState.items.get(fish, {}).get("seasons", [])
	return not (s is Array) or (s as Array).is_empty() or (s as Array).has(se)


static func weather_ok(fish: String, wx: String) -> bool:
	var w: Variant = GameState.items.get(fish, {}).get("weather", [])
	return not (w is Array) or (w as Array).is_empty() or (w as Array).has(wx)


## Seasons a fish bites in (all four for the year-round fish), for the fish log.
static func seasons_of(fish: String) -> Array:
	var s: Variant = GameState.items.get(fish, {}).get("seasons", [])
	return (s as Array).duplicate() if s is Array and not (s as Array).is_empty() else ["spring", "summer", "fall", "winter"]


## The koi is one of a kind: true while it can still be caught (lighthouse lit, not caught yet). The bite
## itself is Collections.legend_roll (one rule set, C16a P4).
static func koi_open() -> bool:
	if not GameState.run.get("flags", {}).has("lighthouse_lit"):
		return false
	if GameState.has_seen("legendary_koi"):
		return false
	var coll: Variant = GameState.run.get("coll", {})
	var caught: Variant = (coll as Dictionary).get("caught", {}) if coll is Dictionary else {}
	return not (caught is Dictionary and (caught as Dictionary).has("legendary_koi"))


static func luck() -> float:
	return GameState.buff("luck") + float(GameState.gear_stat("luck"))


static func ceiling(lvl: int, night: bool, baited: bool, area_tier: int) -> int:
	return int(T["cap_base"]) + int(T["cap_per_level"]) * lvl + (int(T["cap_night"]) if night else 0) \
		+ (int(T["cap_bait"]) if baited else 0) + int(T["cap_per_rod"]) * GameState.tool_tier("rod") \
		+ int(float(T["cap_per_luck"]) * luck()) + int(T["cap_per_area_tier"]) * maxi(0, area_tier)


static func reach_n(lvl: int, night: bool, baited: bool) -> int:
	var wx := GameState.weather_today()
	var w := 1 if wx == "storm" else (-1 if wx == "blizzard" else 0)  # C15 P4: storms stir the deep fish up
	return maxi(1, 1 + lvl + (2 if night else 0) + (1 if baited else 0) + GameState.tool_tier("rod") / 2 + w)


## True when bait would open a fish the bare hook can't reach here (bait is
## only spent where it matters).
static func bait_helps(pool: Array, lvl: int, night: bool, area_tier: int) -> bool:
	var cap := ceiling(lvl, night, false, area_tier)
	var open := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap)
	return open.size() < pool.size() or reach_n(lvl, night, false) < open.size()


## Picks the fish at the bite (so the window can fit it). Returns "boot" for junk.
## rare: chance of a Rare Catch roll (skill + perks); picks from the top of reach.
static func pick(pool: Array, lvl: int, night: bool, baited: bool, area_tier: int, rare: float, _scene := "") -> String:
	if randf() < float(T["boot"]):
		return "boot"
	var cap := ceiling(lvl, night, baited, area_tier)
	var open := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap)
	if open.is_empty():
		open = [pool[0]]
	var reach := mini(open.size(), reach_n(lvl, night, baited))
	# C16a P4 (c16a_05-05): skill shifts the mix up (0.67 + 0.01/eff level, bait +0.08, cap 0.92).
	var ratio := minf(0.92, 0.67 + 0.01 * mini(lvl, GameState.LEVEL_EFFECT_CAP) + (0.08 if baited else 0.0))
	if randf() < rare + minf(float(T["rare_luck_cap"]), float(T["rare_per_luck"]) * luck()):
		# Rare Catch: one more fish and +40 ceiling, picked from the TOP down.
		var up := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap + 40)
		if up.is_empty():
			up = open
		var hi := mini(up.size(), reach + 1)
		var lo := hi / 2
		return up[hi - 1 - (weighted(0, hi - lo, ratio))]
	return open[weighted(0, reach, ratio)]


static func window_for(fish: String) -> float:
	var w: float = float((T["windows"] as Array)[band(fish)]) if fish != "boot" else float((T["windows"] as Array)[0])
	w += GameState.bonus("fishing", "escape_less") + float(T["window_per_rod"]) * GameState.tool_tier("rod")
	return maxf(float(T["window_min"]), w) * Settings.timing_factor()  # Options > Timing help (C9; rewards unchanged)


## Treasure after a catch, or "" (chest_chance scaled by where you fish).
static func treasure(scene: String, area_tier: int) -> String:
	var mults: Array = T["treasure_mult"]
	var ch := GameState.bonus("fishing", "chest_chance") * float(mults[clampi(area_tier, 0, mults.size() - 1)])
	if randf() >= ch:
		return ""
	# C10a P4: some treasure catches are a home piece instead (decor box, toast queued).
	if randf() < float(T["treasure_decor_p"]) and DecorSources.roll_grant(null, decor_pool(scene, area_tier), luck(), "fishing") != "":
		return ""
	var list: Array = T["treasure_valley"]
	if area_tier >= 3:
		list = T["treasure_deep"]
	elif (T["sea_waters"] as Array).has(scene):
		list = T["treasure_sea"]
	return str(list[randi() % list.size()])


## Decor pool for a treasure catch here: "fishing_sea" / "fishing_deep" when decor.json
## has them, else the shared "fishing" pool.
static func decor_pool(scene: String, area_tier: int) -> String:
	var want := "fishing_deep" if area_tier >= 3 else ("fishing_sea" if (T["sea_waters"] as Array).has(scene) else "fishing")
	return want if (Decor.data()["pools"] as Dictionary).has(want) else "fishing"


static func xp_for(fish: String) -> int:
	if fish == "boot":
		return int(T["xp_boot"])
	return mini(int(T["xp_max"]), int(T["xp_base"]) + GameState.item_value(fish) / int(T["xp_per_value"]))


static func night_here(scene: String) -> bool:
	return GameState.is_night() and GameState.run["flags"].has("lighthouse_lit") and (T["lit_waters"] as Array).has(scene)


## A random index in [lo, hi), each step up `ratio` times as likely as the last.
static func weighted(lo: int, hi: int, ratio := 0.67) -> int:
	var tot := 0.0
	for i in range(lo, hi):
		tot += pow(ratio, i - lo)
	var r := randf() * tot
	for i in range(lo, hi):
		r -= pow(ratio, i - lo)
		if r <= 0.0:
			return i
	return maxi(lo, hi - 1)
