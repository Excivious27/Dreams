class_name Perks
extends RefCounted
## Villager heart perks from data/heart_perks.json (tools/gen_heart_perks.py):
## one-time gifts and max-stat bonuses when a heart level is first reached,
## weekly and seasonal deliveries, and a few flags other code reads.
## (Perks hand-coded with GameState.has_friend_perk live where they act.)

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/heart_perks.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
		_data.erase("_")
	return _data


static func _got() -> Dictionary:
	if not GameState.run.has("perks_got"):
		GameState.run["perks_got"] = {}
	return GameState.run["perks_got"]


## Any villager you're close enough to has given you this flag.
static var _fc: Dictionary = {}
static var _fc_frame := -1


static func flag(name: String) -> bool:
	var fr := Engine.get_process_frames()
	if fr != _fc_frame:
		_fc_frame = fr
		_fc.clear()
	if not _fc.has(name):
		_fc[name] = _flag_now(name)
	return bool(_fc[name])


static func _flag_now(name: String) -> bool:
	if GameState.run.is_empty():
		return false
	for npc: String in data():
		for h: String in data()[npc]:
			if str(data()[npc][h].get("flag", "")) == name and GameState.has_friend_perk(npc, int(h)):
				return true
	return false


## New heart levels reached: hand over their one-time gifts. Returns toast lines.
static func check(npc: String) -> Array:
	var out: Array = []
	if GameState.run.is_empty() or not data().has(npc):
		return out
	var got := _got()
	for h: String in data()[npc]:
		var k := "%s_%s" % [npc, h]
		if got.has(k) or not GameState.has_friend_perk(npc, int(h)):
			continue
		got[k] = true
		var p: Dictionary = data()[npc][h]
		var nm := str(GameState.npcs.get(npc, {}).get("name", npc))
		_give(p.get("give", {}))
		var b: Dictionary = p.get("bonus", {})
		for stat: String in b:
			GameState.run["bonus_" + stat] = int(GameState.run.get("bonus_" + stat, 0)) + int(b[stat])
		if not b.is_empty():
			GameState._apply_max_stats()
		out.append("♥%s %s: %s" % [h, nm, str(p.get("text", ""))])
	return out


static func _give(g: Dictionary) -> void:
	for id: String in g:
		var n := int(g[id])
		if id == "#gold":
			GameState.run["crystals"] = int(GameState.run["crystals"]) + n
		elif id == "#seedpack":
			GameState.add_item(seed_pack(), 5 * n)
		else:
			GameState.add_item(id, n)


## A seed for this season that you could grow now.
static func seed_pack() -> String:
	var opts: Array = []
	for cid: String in GameState.crops:
		var cd: Dictionary = GameState.crops[cid]
		if str(cd.get("season", "any")) in [GameState.season(), "any"] and int(cd.get("tier", 1)) <= GameState.progress_tier() + 1 \
				and not bool(cd.get("tree", false)) and (GameState.is_penguins() or not cid.begins_with("crystal")):
			var sid := cid + "_seed"
			if GameState.items.has(sid):
				opts.append(sid)
	return str(opts[randi() % opts.size()]) if not opts.is_empty() else "turnip_seed"


## Morning deliveries (called from GameState.sleep after the day turns over).
static func morning() -> Array:
	var out: Array = []
	if GameState.run.is_empty():
		return out
	var day := int(GameState.run["day"])
	var weekly := day % 7 == 1
	var first_of_season := (day - 1) % GameState.DAYS_PER_SEASON == 0
	for npc: String in data():
		# Villagers the story sent away (posy_gone, lumi_gone...) don't send gifts.
		if GameState.run["flags"].has(npc + "_gone"):
			continue
		# Every weekly perk keeps coming; the same item from a higher heart level replaces the lower one (no stacking).
		var best_weekly: Dictionary = {}
		var best_h := -1
		for h: String in data()[npc]:
			if GameState.has_friend_perk(npc, int(h)) and (data()[npc][h] as Dictionary).has("weekly"):
				best_h = maxi(best_h, int(h))
				var wk: Dictionary = data()[npc][h]["weekly"]
				for wid: String in wk:
					best_weekly[wid] = maxi(int(best_weekly.get(wid, 0)), int(wk[wid]))
		var nm := str(GameState.npcs.get(npc, {}).get("name", npc))
		if weekly and best_h >= 0:
			_give(best_weekly)
			out.append("%s left you something (%s)." % [nm, _list(best_weekly)])
		for h: String in data()[npc]:
			if not GameState.has_friend_perk(npc, int(h)):
				continue
			var p: Dictionary = data()[npc][h]
			if first_of_season and p.has("season"):
				_give(p["season"])
				out.append("%s sent a seed pack for the new season." % nm)
	return out


static func _list(g: Dictionary) -> String:
	var parts: Array = []
	for id: String in g:
		if id == "#gold":
			parts.append("◆%d" % int(g[id]))
		elif id == "#seedpack":
			parts.append("seeds")
		else:
			parts.append("%d %s" % [int(g[id]), GameState.item_name(id)])
	return ", ".join(parts)
