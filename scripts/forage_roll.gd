class_name ForageRoll
extends RefCounted
## C16a P4 (c16a_08-01 / 08-08): a forage spot's find is a pure function of (region, spot, the day it was last
## picked, season), so leaving and re-entering a map never re-rolls it. The respawn wait follows the tier of the
## find that was on the spot (flags[key + "_t"], kept only for rare finds), in the region and the forest alike.


## The find on this spot now, or "" while it is still regrowing. tracker = the Tracker perk.
static func spot(region: String, key: String, tracker: bool) -> String:
	var f: Dictionary = GameState.run["flags"]
	var last_t := int(f.get(key + "_t", 1))
	var every := (1 if tracker else 2) + maxi(0, last_t - 1) * 2
	if not GameState.respawned(key, every):
		return ""
	var item := roll(region, key)
	var t := int(GameState.items.get(item, {}).get("tier", 1))
	if t > 1:
		f[key + "_t"] = t
	else:
		f.erase(key + "_t")
	return item


## Seeded roll (the global RNG stream carries on deterministically afterwards).
static func roll(region: String, key: String) -> String:
	var keep := randi()
	seed(hash([region, key, int(GameState.run["flags"].get(key, 0)), GameState.season()]))
	var item := GameState.roll_forage(region)
	seed(keep)
	return item


## C16a P4 (c16a_08-11): rare finds (tier 2+) draw as their own item icon, so a rare is visible on the map;
## common clumps (flower, wild herb, mushroom) keep the generic look.
static func shows_icon(item: String) -> bool:
	if item in ["flower", "wild_herb", "mushroom"]:
		return false
	return int(GameState.items.get(item, {}).get("tier", 1)) >= 2 and Art.has("items", Hud.icon_for(item))
