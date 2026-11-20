class_name Fishing
extends RefCounted
## Fishing rules (CONDUCT 8 P4). GameMap.fish_at runs the cast/bite/tap; every
## number about WHICH fish bites, how long the bite window is, what treasure
## comes up and how much XP a catch gives lives here, in T.

const T := {
	"cheap_value": 30,          # a fish this cheap or less counts as a "common"
	"commons_min": 2,           # valley waters with fewer commons get minnow + sunfish
	"commons": ["minnow", "sunfish"],
	"cap_base": 25, "cap_per_level": 15, "cap_night": 40, "cap_bait": 10,
	"cap_per_rod": 10,          # each rod upgrade lifts the value ceiling
	"cap_per_luck": 5,          # luck (buff + gear) lifts the ceiling
	"cap_per_area_tier": 30,    # a mega water's own fish are within reach of its tier
	"boot": 0.08,
	"rare_per_luck": 0.03,
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
	"sea_waters": ["beach", "colony_coral", "colony_kelp", "colony_ice", "colony_ember", "docks"],
	# XP per catch: base + value / per (capped); boots give the floor.
	"xp_base": 3, "xp_per_value": 25, "xp_max": 14, "xp_boot": 2,
	# Legendary Koi: the lake at night under the lit lighthouse, baited, Fishing 10+.
	"koi": {"scene": "lake", "level": 10, "chance": 0.012},
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
static func pool_for(pool_in: Array, area_tier: int) -> Array:
	var pool := []
	for f in pool_in:
		if not pool.has(f) and GameState.items.has(str(f)):
			pool.append(str(f))
	if pool.is_empty():
		pool = (T["fresh_pool"] as Array).duplicate()
	var now := "night" if GameState.is_night() else "day"
	var timed := pool.filter(func(f: String) -> bool: return str((T["when"] as Dictionary).get(f, now)) == now)
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


static func luck() -> float:
	return GameState.buff("luck") + float(GameState.gear_stat("luck"))


static func ceiling(lvl: int, night: bool, baited: bool, area_tier: int) -> int:
	return int(T["cap_base"]) + int(T["cap_per_level"]) * lvl + (int(T["cap_night"]) if night else 0) \
		+ (int(T["cap_bait"]) if baited else 0) + int(T["cap_per_rod"]) * GameState.tool_tier("rod") \
		+ int(float(T["cap_per_luck"]) * luck()) + int(T["cap_per_area_tier"]) * maxi(0, area_tier)


static func reach_n(lvl: int, night: bool, baited: bool) -> int:
	return 1 + lvl + (2 if night else 0) + (1 if baited else 0) + GameState.tool_tier("rod") / 2


## True when bait would open a fish the bare hook can't reach here (bait is
## only spent where it matters).
static func bait_helps(pool: Array, lvl: int, night: bool, area_tier: int) -> bool:
	var cap := ceiling(lvl, night, false, area_tier)
	var open := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap)
	return open.size() < pool.size() or reach_n(lvl, night, false) < open.size()


## Picks the fish at the bite (so the window can fit it). Returns "boot" for junk.
## rare: chance of a Rare Catch roll (skill + perks); picks from the top of reach.
static func pick(pool: Array, lvl: int, night: bool, baited: bool, area_tier: int, rare: float, scene := "") -> String:
	var k: Dictionary = T["koi"]
	if scene == str(k["scene"]) and night and baited and lvl >= int(k["level"]) and randf() < float(k["chance"]):
		return "legendary_koi"
	if randf() < float(T["boot"]):
		return "boot"
	var cap := ceiling(lvl, night, baited, area_tier)
	var open := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap)
	if open.is_empty():
		open = [pool[0]]
	var reach := mini(open.size(), reach_n(lvl, night, baited))
	var ratio := 0.8 if baited else 0.67
	if randf() < rare + float(T["rare_per_luck"]) * luck():
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
	return maxf(float(T["window_min"]), w)


## Treasure after a catch, or "" (chest_chance scaled by where you fish).
static func treasure(scene: String, area_tier: int) -> String:
	var mults: Array = T["treasure_mult"]
	var ch := GameState.bonus("fishing", "chest_chance") * float(mults[clampi(area_tier, 0, mults.size() - 1)])
	if randf() >= ch:
		return ""
	var list: Array = T["treasure_valley"]
	if area_tier >= 3:
		list = T["treasure_deep"]
	elif (T["sea_waters"] as Array).has(scene):
		list = T["treasure_sea"]
	return str(list[randi() % list.size()])


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
