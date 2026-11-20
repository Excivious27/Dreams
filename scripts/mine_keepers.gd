class_name MineKeepers
## The mine floor's keeper: WHEN it wakes (the floor's pace) and WHAT wakes
## (the encounter). Tom (CONDUCT 2): it came after about the same time every
## floor and was always the same guardian. Now every floor and day rolls a pace
## (quick / normal / long / marathon: the digging threshold multiplier and the
## seconds you must spend on the floor) and the encounter comes from a big
## catalogue: one big keeper, an elder brute, a pack of small creatures, a
## swarm, a mixed den, twin keepers, themed by the floor's cave (theme index)
## and depth, with arc-only crews. Never the same encounter twice in a row.
## Pure data + rolls: Mine spawns and tracks the units (Mine._summon_guardian).

## Pace buckets: w = weight, thr = multiplier on the floor's digging threshold,
## secs = seconds on the floor before it can wake.
const PACES := {
	"quick": {"w": 26, "thr": [0.3, 0.5], "secs": [4.0, 16.0]},
	"normal": {"w": 36, "thr": [0.8, 1.15], "secs": [35.0, 80.0]},
	"long": {"w": 26, "thr": [1.4, 1.9], "secs": [120.0, 200.0]},
	"marathon": {"w": 12, "thr": [1.9, 2.5], "secs": [210.0, 320.0]},
}

## Cave themes by index (Mine.THEMES order): 0 Earthen, 1 Mossy, 2 Grey Stone,
## 3 Flooded, 4 Fungal, 5 Crystal Veins, 6 Frost, 7 Amethyst, 8 Sandstone,
## 9 Gold Seams, 10 Magma, 11 Obsidian, 12 Drowned Dark, 13 Void, 14 Heart's Edge.
## Unit tokens: "@guard" the tier's keeper, "@guard_prev" the tier before's,
## "@pool" one kind from the floor's wanderer pool (same kind for the whole pack),
## "@mix" a different pool kind per unit; else an enemy kind.
## lead / kin: the big one and the small ones; n = how many kin.
## themes: [] = any cave (themed ones weigh x2.5 in their caves).
const ENCOUNTERS := [
	{"id": "keeper", "name": "@tier_title", "lead": "@guard", "ls": 1.0, "lh": 1.0, "w": 10},
	{"id": "elder", "name": "Elder %s", "lead": "@pool", "ls": 1.55, "lh": 4.0, "w": 9},
	{"id": "pack", "name": "%s pack", "kin": "@pool", "n": [3, 5], "ks": 0.85, "kh": 0.8, "w": 9},
	{"id": "den", "name": "Den of the deep", "kin": "@mix", "n": [4, 6], "ks": 0.85, "kh": 0.7, "w": 7},
	{"id": "twins", "name": "Twin keepers", "lead": "@guard", "kin": "@guard_prev", "n": [1, 1], "ls": 0.95, "lh": 0.7, "ks": 0.95, "kh": 0.7, "w": 5, "floors": [6, 150]},
	{"id": "bat_swarm", "name": "Bat swarm", "kin": "bat", "n": [6, 8], "ks": 0.8, "kh": 0.6, "w": 5, "floors": [1, 60]},
	{"id": "moth_cloud", "name": "Moth cloud", "kin": "lantern_moth", "n": [4, 6], "ks": 0.8, "kh": 0.6, "w": 5, "floors": [8, 150]},
	{"id": "rubble_twins", "name": "Rubble twins", "lead": "golem", "kin": "golem", "n": [1, 1], "ls": 1.2, "lh": 1.2, "ks": 1.2, "kh": 1.2, "w": 5, "floors": [1, 50], "themes": [0, 2, 8, 9]},
	{"id": "grump_gang", "name": "Grump gang", "lead": "big_grump", "kin": "grump", "n": [3, 4], "ls": 1.0, "lh": 0.8, "ks": 0.95, "kh": 1.0, "w": 6, "floors": [1, 40], "themes": [0, 1], "arc": "penguins"},
	{"id": "slime_court", "name": "Slime court", "lead": "slime", "kin": "mud_slime", "n": [3, 4], "ls": 2.0, "lh": 9.0, "ks": 0.9, "kh": 0.8, "w": 6, "floors": [1, 60], "themes": [1, 3, 4]},
	{"id": "crab_shoal", "name": "Crab shoal", "lead": "rock_crab", "kin": "rock_crab", "n": [2, 3], "ls": 1.5, "lh": 2.5, "ks": 0.8, "kh": 0.7, "w": 5, "floors": [3, 50], "themes": [1, 3, 8]},
	{"id": "wolf_pack", "name": "Hill wolf pack", "lead": "hill_wolf", "kin": "hill_wolf", "n": [2, 3], "ls": 1.3, "lh": 1.8, "ks": 0.85, "kh": 0.7, "w": 5, "floors": [10, 70], "themes": [0, 2, 6]},
	{"id": "serpent", "name": "Serpent of the galleries", "lead": "river_serpent", "ls": 1.4, "lh": 2.6, "w": 6, "floors": [12, 150], "themes": [3, 12]},
	{"id": "eel_knot", "name": "Eel knot", "kin": "void_eel", "n": [3, 4], "ks": 0.8, "kh": 0.6, "w": 5, "floors": [60, 150], "themes": [3, 12, 13]},
	{"id": "gloom_nest", "name": "Gloom nest", "lead": "gloom_spider", "kin": "gloom_moth", "n": [2, 3], "ls": 1.3, "lh": 1.6, "ks": 0.8, "kh": 0.6, "w": 6, "floors": [20, 150], "themes": [4, 12]},
	{"id": "drip_brood", "name": "Drip brood", "lead": "drip_crawler", "kin": "drip_crawler", "n": [2, 3], "ls": 1.45, "lh": 2.2, "ks": 0.8, "kh": 0.6, "w": 5, "floors": [10, 90], "themes": [2, 3, 4]},
	{"id": "shard_brood", "name": "Shard brood", "lead": "shard_spider", "kin": "crystal_baby", "n": [2, 3], "ls": 1.3, "lh": 1.6, "ks": 0.85, "kh": 0.7, "w": 6, "floors": [30, 150], "themes": [5, 7]},
	{"id": "prism_choir", "name": "Prism choir", "kin": "prism_wisp", "n": [3, 4], "ks": 0.9, "kh": 0.7, "w": 5, "floors": [40, 150], "themes": [5, 7, 14]},
	{"id": "geode_heart", "name": "Geode heart", "lead": "geode_golem", "ls": 1.35, "lh": 1.8, "w": 5, "floors": [40, 150], "themes": [5, 7]},
	{"id": "frost_pack", "name": "Frost wolf pack", "lead": "frost_wolf", "kin": "ice_wisp", "n": [2, 3], "ls": 1.25, "lh": 1.5, "ks": 0.85, "kh": 0.8, "w": 6, "floors": [55, 150], "themes": [6]},
	{"id": "ice_wisps", "name": "Ice wisp ring", "kin": "ice_wisp", "n": [4, 6], "ks": 0.85, "kh": 0.8, "w": 5, "floors": [25, 150], "themes": [6, 7]},
	{"id": "rime_golem", "name": "The Rime Golem", "lead": "rime_golem", "ls": 1.35, "lh": 1.7, "w": 5, "floors": [60, 150], "themes": [6]},
	{"id": "dune_crabs", "name": "Dune crabs", "lead": "sand_hound", "kin": "dune_crab", "n": [2, 3], "ls": 1.2, "lh": 1.2, "ks": 0.85, "kh": 0.6, "w": 6, "floors": [45, 150], "themes": [8, 9]},
	{"id": "glass_golem", "name": "The Glass Golem", "lead": "glass_golem", "ls": 1.35, "lh": 1.8, "w": 5, "floors": [45, 150], "themes": [8, 9]},
	{"id": "rust_patrol", "name": "Rust patrol", "lead": "rust_knight", "kin": "knight", "n": [1, 2], "ls": 1.25, "lh": 1.4, "ks": 0.95, "kh": 0.8, "w": 5, "floors": [15, 120], "themes": [2, 9]},
	{"id": "coal_crawlers", "name": "Coal crawlers", "kin": "coal_crawler", "n": [3, 4], "ks": 0.85, "kh": 0.6, "w": 5, "floors": [45, 150], "themes": [9, 10]},
	{"id": "ash_pack", "name": "Ash hound pack", "lead": "ash_hound", "kin": "ash_hound", "n": [2, 3], "ls": 1.3, "lh": 1.6, "ks": 0.85, "kh": 0.6, "w": 6, "floors": [70, 150], "themes": [10, 11]},
	{"id": "sun_moths", "name": "Ember moths", "kin": "sun_moth", "n": [4, 5], "ks": 0.85, "kh": 0.6, "w": 5, "floors": [50, 150], "themes": [10, 14]},
	{"id": "sentinel", "name": "The Obsidian Sentinel", "lead": "obsidian_sentinel", "ls": 1.1, "lh": 1.1, "w": 5, "floors": [75, 150], "themes": [10, 11]},
	{"id": "shard_storm", "name": "Shard storm", "kin": "dark_crystal_shard", "n": [3, 4], "ks": 0.85, "kh": 0.55, "w": 5, "floors": [100, 150], "themes": [13, 14]},
	{"id": "mirror_hall", "name": "Hall of mirrors", "lead": "mirror", "kin": "prism_wisp", "n": [2, 2], "ls": 1.1, "lh": 1.0, "ks": 0.85, "kh": 0.6, "w": 5, "floors": [100, 150], "themes": [11, 13, 14]},
	# Gangster arc: rival tunnel crews (all-ages; they just want your dig).
	{"id": "dig_crew", "name": "Rival dig crew", "lead": "thug_cyber", "kin": "thug_lookout", "n": [3, 4], "ls": 1.15, "lh": 1.6, "ks": 1.0, "kh": 1.0, "w": 6, "floors": [1, 40], "arc": "gangsters"},
	{"id": "wrecking_crew", "name": "Wrecking crew", "lead": "thug_brute", "kin": "thug_speedster", "n": [2, 3], "ls": 1.1, "lh": 1.1, "ks": 1.0, "kh": 0.8, "w": 6, "floors": [15, 150], "arc": "gangsters"},
	# Penguin arc: the Dark Crystal's shards stir.
	{"id": "shard_flock", "name": "Shard flock", "kin": "shard", "n": [4, 5], "ks": 0.9, "kh": 0.9, "w": 5, "floors": [5, 60], "arc": "penguins"},
]

## Gangster arc: the Dark Crystal's creatures become crews (as Mine's wanderers do).
const GANG_SWAP := {"grump": "thug_lookout", "big_grump": "thug_brute", "shard": "thug_cyber"}

## Tints for themed kin, so a pack of pool kin reads as this cave's.
const THEME_TINT := {3: "c8dcff", 4: "f0c8ff", 6: "d0f0ff", 7: "f0c0ff", 8: "fff0c8", 10: "ffd0b8", 11: "c8c8e0", 13: "d8c8ff", 14: "ffc8e8"}


static func _arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


## Roll this floor's pace. `last` is the previous floor's bucket: the same
## bucket never comes three times running (two in a row may).
static func roll_pace(floor_no: int, rng: RandomNumberGenerator, last: Array) -> Dictionary:
	var ids: Array = PACES.keys()
	var pick := ""
	for tries in 4:
		var tot := 0
		for k in ids:
			tot += int(PACES[k]["w"])
		var r := rng.randi_range(1, tot)
		for k in ids:
			r -= int(PACES[k]["w"])
			if r <= 0:
				pick = str(k)
				break
		if last.size() < 2 or not (str(last[-1]) == pick and str(last[-2]) == pick):
			break
	var p: Dictionary = PACES[pick]
	var thr := rng.randf_range(float(p["thr"][0]), float(p["thr"][1]))
	var secs := rng.randf_range(float(p["secs"][0]), float(p["secs"][1]))
	if floor_no == 1:
		# Tom (earlier): floor 1's keeper came up far too easily. Floor 1 is never quick.
		thr = maxf(thr, 0.85)
		secs = maxf(secs, 70.0)
	elif floor_no == 2:
		secs = maxf(secs, 12.0)
	return {"pace": pick, "thr": thr, "secs": secs}


## Kinds an encounter may use here: real data, art on disk, not far above the floor's tier.
static func kind_ok(kind: String, tier: int, floor_no: int) -> bool:
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(kind, {})
	if ed.is_empty():
		return false
	var native := GameState.enemy_tier(kind)
	if native > tier + (2 if floor_no > 4 else 1) and not (floor_no <= 4 and kind == "golem"):
		return false
	return has_art(kind)


## Mirrors Enemy.setup's art lookup (no sprite = an invisible foe).
static func has_art(kind: String) -> bool:
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(kind, {})
	var art_kind := str(ed.get("art", kind if kind != "big_grump" or Art.has("enemies/big_grump", "idle") else "grump"))
	var group := "enemies/" + art_kind
	if ed.has("char"):
		group = "characters/" + str(ed["char"])
	elif kind.begins_with("thug_"):
		group = "characters/" + kind.trim_prefix("thug_")
	return Art.has(group, "idle")


static func _swap(kind: String) -> String:
	if _arc() == "gangsters" and GANG_SWAP.has(kind):
		return str(GANG_SWAP[kind])
	return kind


static func _pool(tier: int, floor_no: int) -> Array:
	var pools: Array = GameState.tier_data.get("mine", {}).get("pools", [])
	var pool: Array = (pools[mini(tier, pools.size() - 1)] as Array).duplicate() if not pools.is_empty() else ["slime", "bat"]
	var guards: Array = GameState.tier_data.get("mine", {}).get("guardians", [])
	var out: Array = []
	for k in pool:
		var kk := _swap(str(k))
		if kk in guards and kk != "golem":
			continue
		if floor_no <= 2 and kk in ["rock_crab", "hill_wolf"]:
			continue
		if kind_ok(kk, tier, floor_no) and not out.has(kk):
			out.append(kk)
	if out.is_empty():
		out = ["slime"]
	return out


static func _guard(tier: int) -> String:
	var kinds: Array = GameState.tier_data.get("mine", {}).get("guardians", ["golem"])
	return str(kinds[clampi(tier, 0, kinds.size() - 1)])


## Every encounter that can happen on this floor (ids), for tests and the roll.
static func options(floor_no: int, tier: int, theme_idx: int) -> Array:
	var out: Array = []
	for en: Dictionary in ENCOUNTERS:
		var fl: Array = en.get("floors", [1, 150])
		if floor_no < int(fl[0]) or floor_no > int(fl[1]):
			continue
		if en.has("arc") and str(en["arc"]) != _arc():
			continue
		var ok := true
		for key in ["lead", "kin"]:
			var tok := str(en.get(key, ""))
			if tok == "" or tok.begins_with("@"):
				continue
			if not kind_ok(_swap(tok), tier, floor_no):
				ok = false
		if str(en["id"]) == "twins" and tier == 0:
			ok = false   # no tier before the first
		if ok:
			out.append(str(en["id"]))
	return out


static func by_id(id: String) -> Dictionary:
	for en: Dictionary in ENCOUNTERS:
		if str(en["id"]) == id:
			return en
	return {}


## Pick and resolve the encounter: {"id", "name", "units": [{kind, scale, hp, tint, lead}]}.
## `recent` = encounter ids of the last floors (newest last): never the last
## one, and the last three only if nothing else fits.
static func pick(floor_no: int, tier: int, theme_idx: int, rng: RandomNumberGenerator, recent: Array) -> Dictionary:
	var opts := options(floor_no, tier, theme_idx)
	var last := str(recent[-1]) if not recent.is_empty() else ""
	var fresh: Array = opts.filter(func(i: String) -> bool: return not recent.slice(maxi(0, recent.size() - 3)).has(i))
	if fresh.is_empty():
		fresh = opts.filter(func(i: String) -> bool: return i != last)
	if fresh.is_empty():
		fresh = opts
	var tot := 0.0
	var ws: Array = []
	for fid in fresh:
		var en := by_id(fid)
		var w := float(en.get("w", 5))
		if (en.get("themes", []) as Array).has(theme_idx):
			w *= 2.5
		ws.append(w)
		tot += w
	var r := rng.randf() * tot
	var id := str(fresh[-1])
	for i in fresh.size():
		r -= float(ws[i])
		if r <= 0.0:
			id = str(fresh[i])
			break
	return resolve(id, floor_no, tier, theme_idx, rng)


static func resolve(id: String, floor_no: int, tier: int, theme_idx: int, rng: RandomNumberGenerator) -> Dictionary:
	var en := by_id(id)
	var pool := _pool(tier, floor_no)
	var pool_kind := str(pool[rng.randi() % pool.size()])
	var tint := str(THEME_TINT.get(theme_idx, ""))
	var units: Array = []
	var lead_tok := str(en.get("lead", ""))
	var kin_tok := str(en.get("kin", ""))
	var lead_kind := ""
	if lead_tok != "":
		lead_kind = _token(lead_tok, pool_kind, pool, tier, rng)
		units.append({"kind": lead_kind, "scale": float(en.get("ls", 1.0)), "hp": float(en.get("lh", 1.0)), "tint": tint if lead_tok == "@pool" else "", "lead": true})
	if kin_tok != "":
		var nr: Array = en.get("n", [3, 4])
		var n := rng.randi_range(int(nr[0]), int(nr[1]))
		if floor_no <= 3:
			n = mini(n, 3 + (1 if lead_tok == "" else 0))   # the first floors: smaller packs
		n = maxi(1, n + Difficulty.add("keeper_n"))  # C4 difficulty: -2/-1/0/+1
		for i in n:
			var k := _token(kin_tok, pool_kind, pool, tier, rng)
			units.append({"kind": k, "scale": float(en.get("ks", 0.85)), "hp": float(en.get("kh", 0.8)), "tint": tint if kin_tok.begins_with("@") else "", "lead": units.is_empty()})
	var nm := str(en.get("name", "Keeper"))
	if "%s" in nm:
		var base := lead_kind if lead_kind != "" else str(units[0]["kind"])
		nm = nm % _kind_name(base)
	return {"id": id, "name": nm, "units": units}


static func _token(tok: String, pool_kind: String, pool: Array, tier: int, rng: RandomNumberGenerator) -> String:
	match tok:
		"@guard":
			return _guard(tier)
		"@guard_prev":
			return _guard(maxi(0, tier - 1))
		"@pool":
			return pool_kind
		"@mix":
			return str(pool[rng.randi() % pool.size()])
	return _swap(tok)


static func _kind_name(kind: String) -> String:
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(kind, {})
	if ed.has("name"):
		return str(ed["name"])
	return kind.replace("thug_", "").replace("_", " ").capitalize()


## Resize a spawned enemy (Enemy._process redraws from _art_scale every frame).
static func resize(e: Enemy, k: float) -> void:
	if e == null or is_equal_approx(k, 1.0):
		return
	e._art_scale *= k
	e._shadow_r *= k
	if e._sprite:
		e._sprite.scale *= k
