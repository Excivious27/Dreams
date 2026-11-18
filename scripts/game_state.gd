class_name GameState
extends RefCounted
## The one place the player's run lives. Plain Dictionary so it saves to user://
## and can be synced for co-op later. Everything that changes the world goes here.

const SAVE_KEY := "run"
const DAY_START := 6 * 60      # 6:00
const DAY_END := 26 * 60       # 2:00 next day: pass out
const MINUTES_PER_SECOND := 1.0 / 0.7  # one game minute every 0.7s (about 23 min per day)

static var run: Dictionary = {}
static var items: Dictionary = {}
static var crops: Dictionary = {}
static var skills_data: Dictionary = {}
static var recipes: Dictionary = {}
static var enemy_data: Dictionary = {}
static var tier_data: Dictionary = {}
static var forage_data: Dictionary = {}
static var quests_data: Dictionary = {}
static var npcs: Dictionary = {}
static var arcs: Dictionary = {}
static var playables: Dictionary = {}


static func load_data() -> void:
	if not items.is_empty():
		return
	items = load_json("res://data/items.json")
	crops = load_json("res://data/crops.json")
	npcs = load_json("res://data/npcs.json")
	arcs = load_json("res://data/arcs.json")
	playables = load_json("res://data/playable.json")
	skills_data = load_json("res://data/skills.json").get("skills", {})
	recipes = load_json("res://data/recipes.json")
	enemy_data = load_json("res://data/enemies.json")
	tier_data = load_json("res://data/tiers.json")
	forage_data = load_json("res://data/forage.json")
	quests_data = load_json("res://data/quests.json")


static func new_run(arc: String, playable_id: String, character_name: String, town_name: String, pet_name: String) -> void:
	load_data()
	if arc == "penguins":
		# A gangster run earlier in the session registered the crew as villagers.
		for cid in (load_json("res://data/crew.json").get("members", {}) as Dictionary):
			npcs.erase(cid)
	var skills := {}
	for id in skills_data.keys():
		skills[id] = {"level": 1, "xp": 0, "nodes": {}}
	run = {
		"equip": {"head": "", "body": "", "legs": "", "feet": "", "hands": "", "offhand": "", "back": "", "belt": "", "ring": "", "charm": ""},
		"arc": arc,
		"playable": playable_id,
		"names": {"character": character_name, "town": town_name, "pet": pet_name},
		"crystals": 50 if arc == "penguins" else 60,
		"day": 1,
		"time": DAY_START,
		"energy": 100, "max_energy": 100,
		"hp": 100, "max_hp": 100, "mana": 20, "max_mana": 20, "hp_scale": 6,
		"skills": skills,
		"flags": {},
		"decisions": {},
		"friendship": {},
		"talked_today": {},
		"inventory": {},
		"tools": ["hoe", "can", "axe", "pickaxe", "sword", "rod"],
		"toolbar": ["hoe", "can", "axe", "pickaxe", "sword", "rod", "", "", "", "", "", ""],
		"slot": 0,
		"selected": "",
		"farm": {},
		"sellbox": {},
		"quests": [],
		"scene": "farm",
		"mine_floor": 1,
		"kills": 0,
		"intro_done": false,
	}
	add_item("turnip_seed", 6)
	add_item("berry", 2)
	save()


static func has_run() -> bool:
	load_data()
	if run.is_empty():
		var saved: Variant = SaveGame.get_value(save_key())
		if saved is Dictionary and not saved.is_empty():
			run = saved
			_migrate()
			# A story scene that was cut off (app closed) plays again from the start.
			if run.has("story_pending"):
				run["flags"].erase("st_" + str(run["story_pending"]))
				run.erase("story_pending")
			board_restore()
	return not run.is_empty()


## Older saves (or saves from before a new field existed) get the missing keys.
static func _migrate() -> void:
	if run.has("look") and run["look"] is Dictionary and run["look"].has("body") and not run["look"].has("outfit"):
		run["look"]["outfit"] = "outfit_neon" if str(run.get("arc", "")) == "gangsters" else "outfit_farmer"
	var defaults := {
		"crystals": 20, "day": 1, "time": DAY_START, "energy": 100, "max_energy": 100,
		"hp": 100, "max_hp": 100, "mana": 20, "max_mana": 20, "hp_scale": 6, "skills": {}, "flags": {}, "decisions": {}, "friendship": {},
		"gifted_today": {}, "equip": {"head": "", "body": "", "legs": "", "feet": "", "hands": "", "offhand": "", "back": "", "belt": "", "ring": "", "charm": ""},
		"talked_today": {}, "inventory": {}, "tools": ["hoe", "can", "axe", "pickaxe", "sword", "rod"],
		"selected": "", "farm": {}, "sellbox": {}, "quests": [], "scene": "farm", "mine_floor": 1,
		"kills": 0, "intro_done": false,
		"toolbar": ["hoe", "can", "axe", "pickaxe", "sword", "rod", "", "", "", "", "", ""], "slot": 0,
	}
	for k in defaults:
		if not run.has(k):
			run[k] = defaults[k]
	for id in skills_data.keys():
		if not run["skills"].has(id):
			run["skills"][id] = {"level": 1, "xp": 0, "nodes": {}}
		elif not run["skills"][id].has("nodes"):
			run["skills"][id]["nodes"] = {}
	if not run.has("names") or not run.has("arc") or not run.has("playable"):
		# Unreadable run: keep a copy in the save file instead of losing it.
		SaveGame.set_value("run_unreadable", run)
		run = {}
		return
	if not (run["names"] is Dictionary):
		run["names"] = {}
	for k in ["character", "town", "pet"]:
		if not run["names"].has(k):
			run["names"][k] = {"character": "Hero", "town": "Dreamhollow", "pet": "Pup"}[k]
	if not (run["skills"] is Dictionary):
		run["skills"] = {}
	for id in skills_data.keys():
		if not run["skills"].has(id):
			run["skills"][id] = {"level": 1, "xp": 0, "nodes": {}}
	_apply_max_stats()


static func save() -> void:
	SaveGame.set_value(save_key(), Net.save_view(run))


## Three save slots. Slot 1 keeps the old "run" key so existing saves are slot 1.
static func slot() -> int:
	return clampi(int(SaveGame.get_value("slot", 1)), 1, 3)


static func slot_key(n: int) -> String:
	return SAVE_KEY if n <= 1 else "%s_%d" % [SAVE_KEY, n]


static func save_key() -> String:
	return slot_key(slot())


static func slot_info(n: int) -> String:
	var d: Variant = SaveGame.get_value(slot_key(n), null)
	if not d is Dictionary or (d as Dictionary).is_empty() or not (d as Dictionary).has("names"):
		return "Empty"
	var r: Dictionary = d
	var arc := "Penguins" if str(r.get("arc", "")) == "penguins" else "Gangsters"
	return "%s · %s · day %d" % [str(r["names"].get("character", "?")), arc, int(r.get("day", 1))]


static func use_slot(n: int) -> void:
	if not run.is_empty():
		save()
	run = {}
	SaveGame.set_value("slot", clampi(n, 1, 3))


## A save as one text code (gzip + base64) to move it to another phone.
static func export_code() -> String:
	var raw := JSON.stringify(Net.save_view(run) if not run.is_empty() else SaveGame.get_value(save_key(), {})).to_utf8_buffer()
	return "DRM1:" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## Loads a code into the current slot; the slot's old farm goes to Restore. "" on success.
static func import_code(code: String) -> String:
	var c := code.strip_edges()
	if not c.begins_with("DRM1:"):
		return "That doesn't look like a Dreams save code."
	var buf := Marshalls.base64_to_raw(c.substr(5))
	if buf.is_empty():
		return "The code is cut off or has a typo."
	var txt := buf.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary or not (d as Dictionary).has("names") or not (d as Dictionary).has("arc"):
		return "The code is cut off or has a typo."
	var cur: Variant = SaveGame.get_value(save_key(), null)
	if cur is Dictionary and not (cur as Dictionary).is_empty():
		SaveGame.set_value("run_prev", cur)
	run = {}
	SaveGame.set_value(save_key(), d)
	has_run()
	return ""


## A guest's morning when the host's day rolls over: pay their own sell box,
## refill, clear the day's talk/gift marks. (Farm growth is the host's job.)
static func guest_morning() -> Dictionary:
	status_clear()
	_apply_max_stats()
	var report := {"earned": 0}
	var total := 0
	run["sold_today"] = {}
	for id in run["sellbox"].keys():
		total += sell_price(id, int(run["sellbox"][id]))
	total += quality_bonus_value(run.get("sellbox_q", {}))
	run["sellbox_q"] = {}
	run["sellbox"] = {}
	run["sold_today"] = {}
	run["crystals"] = int(run["crystals"]) + total
	report["earned"] = total
	run["energy"] = int(run["max_energy"])
	run["hp"] = int(run["max_hp"])
	run["mana"] = int(run.get("max_mana", 20))
	run["talked_today"] = {}
	run["gifted_today"] = {}
	Racket.overnight(report)
	Sanctuary.overnight(report)
	save()
	return report


static func names() -> Dictionary:
	return run["names"]


static func is_penguins() -> bool:
	return run.get("arc", "") == "penguins"


static func sprite_for_playable(playable_id: String, arc := "") -> String:
	load_data()
	var sprite := str(playables.get(playable_id, {}).get("sprite", ""))
	if arc == "":
		arc = str(run.get("arc", ""))
	if arc == "gangsters" and CharacterLibrary.has_character(sprite + "_gang"):
		sprite += "_gang"
	if sprite != "" and not CharacterLibrary.has_character(sprite):
		return ""
	return sprite


# ---- items -------------------------------------------------------------------

static func item_name(id: String) -> String:
	if TOOL_KINDS.has(id) and tool_tier(id) > 0:
		return "%s %s" % [TOOL_TIERS[tool_tier(id)].capitalize(), str(items.get(id, {}).get("name", id.capitalize()))]
	return str(items.get(id, {}).get("name", id.capitalize()))


# ---- tool tiers --------------------------------------------------------------
# Every tool upgrades through the same ladder at the smith (bars + crystals).
# Tier raises the tool's power: axe/pickaxe hit harder, sword adds damage,
# can/hoe spend less energy, rod bites sooner, scythe/hammer work wider.

const TOOL_TIERS := ["wood", "copper", "iron", "steel", "silver", "gold", "crystal", "moon"]
const TOOL_KINDS := ["hoe", "can", "axe", "pickaxe", "sword", "rod", "hammer", "scythe"]
const TOOL_UPGRADE_NEED := [
	{}, {"copper_bar": 3, "crystals": 300}, {"iron_bar": 3, "crystals": 900}, {"steel_bar": 3, "crystals": 2000},
	{"silver_bar": 3, "crystals": 3500}, {"gold_bar": 3, "crystals": 7000}, {"crystal_refined": 3, "gold_bar": 2, "crystals": 14000},
	{"moon_shard": 3, "crystal_refined": 3, "crystals": 30000},
]

# ---- gathering tiers ---------------------------------------------------------
# What a node needs before it gives anything. Tool tiers: 0 wood, 1 copper,
# 2 iron, 3 steel, 4 silver, 5 gold, 6 crystal, 7 moon. Skill levels gate the
# rare stuff a second time so a lucky upgrade alone doesn't skip the game.
const ORE_TIER := {"stone": 0, "coal": 0, "copper": 0, "clay": 0, "iron": 1, "shard": 1, "dark": 3, "silver": 2, "gold": 2, "ruby": 2, "fossil": 2, "crystal": 3, "mithril": 3, "amethyst": 3, "emerald": 3, "moon_shard": 4, "moon": 4}
const ORE_SKILL := {"dark": 5, "silver": 3, "gold": 4, "ruby": 4, "crystal": 5, "mithril": 6, "amethyst": 5, "emerald": 6, "moon_shard": 7}


## "" when you can gather this, else the reason (already phrased for a toast).
static func gather_block(tool: String, need_tier: int, skill: String, need_level: int, what: String) -> String:
	if tool_tier(tool) < need_tier:
		return "%s is too hard for your %s. Gideon upgrades tools (%s)." % [what.capitalize(), item_name(tool).to_lower(), TOOL_TIERS[need_tier]]
	if need_level > 0 and skill_level(skill) < need_level:
		return "%s needs %s level %d (you're %d)." % [what.capitalize(), skill.capitalize(), need_level, skill_level(skill)]
	return ""


static func ore_block(ore: String) -> String:
	return gather_block("pickaxe", int(ORE_TIER.get(ore, 0)), "mining", int(ORE_SKILL.get(ore, 0)), ore.replace("_", " "))


## Trees: saplings/logs free; grown trees copper; big old trees iron + foraging 3;
## crystal and moon trees further still.
static func tree_block(thing: Dictionary) -> String:
	var hp := int(thing.get("hp", 3))
	var kind := str(thing.get("wood", "wood"))
	if kind == "crystal_wood":
		return gather_block("axe", 3, "foraging", 5, "the crystal tree")
	if kind == "hardwood" or hp >= 6:
		return gather_block("axe", 2, "foraging", 3, "this old tree")
	if hp >= 4 and str(thing.get("type", "")) == "tree":
		return gather_block("axe", 1, "foraging", 0, "this tree")
	return ""


## Any blade counts as "the sword" for tiers, swinging and Gideon's bench.
static func is_sword(id: String) -> bool:
	return id == "sword" or (id.ends_with("_sword") and items.has(id)) or bool(items.get(id, {}).get("weapon", false))


static func tool_tier(kind: String) -> int:
	var k := kind
	if is_sword(kind):
		k = "sword"
	return int(run.get("tool_tier", {}).get(k, 0))


static func tool_power(kind: String) -> int:
	return 1 + tool_tier(kind)


## Icon name for a tool at its current tier, if art exists for it.
static func tool_icon(kind: String) -> String:
	var k := "sword" if is_sword(kind) else kind
	if not TOOL_KINDS.has(k):
		return kind
	return "%s_%s" % [k, TOOL_TIERS[tool_tier(k)]]


## Gideon's friendship knocks crystals off an upgrade (10/20/30%).
static func upgrade_need(kind: String) -> Dictionary:
	var t := tool_tier(kind)
	if t + 1 >= TOOL_TIERS.size():
		return {}
	var need: Dictionary = (TOOL_UPGRADE_NEED[t + 1] as Dictionary).duplicate()
	var off := 0.30 if has_friend_perk("gideon", 8) else (0.20 if has_friend_perk("gideon", 4) else (0.10 if has_friend_perk("gideon", 2) else 0.0))
	if need.has("crystals"):
		need["crystals"] = int(ceil(int(need["crystals"]) * (1.0 - off)))
	return need


static func can_upgrade_tool(kind: String) -> bool:
	var t := tool_tier(kind)
	if t + 1 >= TOOL_TIERS.size():
		return false
	var need: Dictionary = upgrade_need(kind)
	for id in need:
		if id == "crystals":
			if int(run["crystals"]) < int(need[id]):
				return false
		elif count(str(id)) < int(need[id]):
			return false
	return true


static func upgrade_tool(kind: String) -> bool:
	if not can_upgrade_tool(kind):
		return false
	var t := tool_tier(kind)
	var need: Dictionary = upgrade_need(kind)
	for id in need:
		if id == "crystals":
			run["crystals"] = int(run["crystals"]) - int(need[id])
		else:
			add_item(str(id), -int(need[id]))
	if not run.has("tool_tier"):
		run["tool_tier"] = {}
	run["tool_tier"][kind] = t + 1
	return true


static func item_value(id: String) -> int:
	return int(items.get(id, {}).get("value", 0))


# ---- economy -----------------------------------------------------------------
# Selling: base value × season demand (crops sell for more out of their season,
# fish/forage for more in winter) × today's saturation (every 20 of one thing
# sold in a day knocks 8% off the rest) × bartering/friend bonuses. Buying:
# 1.5× value with discounts, and tiered goods cost more until you've earned them.

const DEMAND_OUT_OF_SEASON := 1.35


static func demand(id: String) -> float:
	var it: Dictionary = items.get(id, {})
	var t := str(it.get("type", ""))
	var se := season()
	var m := 1.0
	for cid in crops:
		if str(crops[cid].get("yield", "")) == id:
			var cs := str(crops[cid].get("season", "any"))
			if cs != "any" and cs != se:
				m *= DEMAND_OUT_OF_SEASON
			break
	if t in ["fish", "forage"] and se == "winter":
		m *= 1.2
	if t == "forage" and se == "spring":
		m *= 0.9
	# Festival week: the town buys everything a little dearer.
	if absi(day_of_season() - FESTIVAL_DAY) <= 1:
		m *= 1.1
	return m


static func saturation(id: String, n_more := 0) -> float:
	var sold: Dictionary = run.get("sold_today", {})
	if Crew.perk_level("fence") >= 2:
		return 1.0  # Marlene takes any amount at full value
	var already := int(sold.get(id, 0)) + n_more
	# The first 20 of a thing sell at full price; after that the town has had
	# enough of it: -10% per further 10, floor 40%. Grow a few things.
	if already < 20:
		return 1.0
	return maxf(0.4, 1.0 - 0.10 * (1 + (already - 20) / 10))


static func sell_price(id: String, n := 1) -> int:
	var unit := item_value(id) * demand(id) * sell_multiplier() * (1.0 + 0.04 * (skill_level("bartering") - 1)) * (1.0 + 0.05 * Crew.perk_level("sell_bonus"))
	if family(id) != "":
		unit *= 1.0 + bonus("farming", "crop_value")
	if str(items.get(id, {}).get("type", "")) == "fish":
		unit *= 1.0 + bonus("fishing", "fish_value")
	if Crew.perk_level("fence") >= 1 and str(items.get(id, {}).get("type", "")) in ["drop", "loot", "material"] and str(run.get("arc", "")) == "gangsters":
		unit *= 1.2
	var total := 0.0
	for i in n:
		total += unit * saturation(id, i)
	return int(round(total))


## A hand-priced stall can be cheap, but never cheaper than what the item sells for.
static func shop_price(id: String, listed: int) -> int:
	return maxi(listed, int(ceil(sell_price(id, 1) * 1.15)))


static func buy_price(id: String) -> int:
	var base := item_value(id)
	var it: Dictionary = items.get(id, {})
	var tier := int(it.get("tier", 1))
	var m := 1.5 * buy_multiplier()
	# Goods above your progress cost extra: the shops know what you can afford to break.
	if tier > progress_tier() + 1:
		m *= 1.0 + 0.25 * (tier - progress_tier() - 1)
	if str(it.get("type", "")) == "seed":
		for cid in crops:
			if str(crops[cid].get("yield", "")) + "_seed" == id or cid + "_seed" == id:
				var cs := str(crops[cid].get("season", "any"))
				if cs != "any" and cs != season():
					m *= 0.85  # off-season seed is a little cheaper, and a gamble
	# Never cheaper than you could sell it back for (with every perk): shops are
	# not a money machine.
	var best_sell := base * sell_multiplier() * (1.0 + 0.04 * (skill_level("bartering") - 1)) * (1.0 + 0.05 * Crew.perk_level("sell_bonus")) * 1.1
	m *= 1.0 - 0.05 * Crew.perk_level("shop_discount") if Crew.perk_level("shop_discount") < 3 else 0.9  # Specs knows the till codes
	return maxi(1, int(ceil(maxf(base * m, best_sell * 1.1))))


static func count(id: String) -> int:
	return int(run["inventory"].get(id, 0))


static func add_item(id: String, n: int = 1) -> void:
	var inv: Dictionary = run["inventory"]
	inv[id] = int(inv.get(id, 0)) + n
	if n < 0:
		_trim_quality(id)
	elif n > 0:
		_mark_seen(id)
	if inv[id] <= 0:
		inv.erase(id)
		var tb: Array = run["toolbar"]
		var i := tb.find(id)
		if i >= 0:
			tb[i] = ""
	elif n > 0 and not run["toolbar"].has(id):
		# New item: drop it into the first free toolbar slot, like Stardew's backpack.
		var tb: Array = run["toolbar"]
		var free := tb.find("")
		if free >= 0:
			tb[free] = id
	sync_selected()


static func _mark_seen(id: String) -> void:
	if not run.has("seen"):
		run["seen"] = {}
	run["seen"][id] = true


## Ever held this item (or, for "#family", anything of that family)?
static func has_seen(key: String) -> bool:
	if count_any(key) > 0:
		return true
	var seen: Dictionary = run.get("seen", {})
	if not key.begins_with("#"):
		return seen.has(key) or has_tool(key)
	var f := key.substr(1)
	for id: String in seen:
		if family(id) == f or (f == "fruit" and family(id) in ["tree", "berry"]):
			return true
	return false


## Quality crops: run["quality"][id] = {"g": gold count, "s": silver count}, a
## subset of the stack. Gold sells for half again, silver a quarter more.
const QUALITY_BONUS := {"g": 0.5, "s": 0.25}


static func quality_of(id: String) -> Dictionary:
	return (run.get("quality", {}) as Dictionary).get(id, {})


static func add_quality(id: String, q: String, n: int) -> void:
	if not run.has("quality"):
		run["quality"] = {}
	var d: Dictionary = run["quality"].get(id, {})
	d[q] = int(d.get(q, 0)) + n
	run["quality"][id] = d


static func _trim_quality(id: String) -> void:
	var d := quality_of(id)
	if d.is_empty():
		return
	var over := int(d.get("g", 0)) + int(d.get("s", 0)) - count(id)
	if over <= 0:
		return
	var cut := mini(over, int(d.get("s", 0)))
	d["s"] = int(d.get("s", 0)) - cut
	d["g"] = maxi(0, int(d.get("g", 0)) - (over - cut))
	if int(d["s"]) + int(d["g"]) <= 0:
		run["quality"].erase(id)


## Takes up to n of the best pieces (gold first) for selling: returns {"g", "s"}.
static func take_quality(id: String, n: int) -> Dictionary:
	var d := quality_of(id)
	var g := mini(n, int(d.get("g", 0)))
	var sv := mini(n - g, int(d.get("s", 0)))
	if g + sv > 0:
		d["g"] = int(d.get("g", 0)) - g
		d["s"] = int(d.get("s", 0)) - sv
	return {"g": g, "s": sv}


## The extra a sell box's quality pieces earn on top of the normal price.
static func quality_bonus_value(box_q: Dictionary) -> int:
	var t := 0.0
	for id: String in box_q:
		var q: Dictionary = box_q[id]
		var unit := float(sell_price(id, 1))
		t += unit * (QUALITY_BONUS["g"] * int(q.get("g", 0)) + QUALITY_BONUS["s"] * int(q.get("s", 0)))
	return int(round(t))


## What's "in hand": the toolbar slot's item if it's a usable item with count > 0.
static func sync_selected() -> void:
	var tb: Array = run["toolbar"]
	var slot := clampi(int(run["slot"]), 0, tb.size() - 1)
	run["slot"] = slot
	var id := str(tb[slot])
	if id != "" and run["inventory"].has(id):
		run["selected"] = id
	else:
		run["selected"] = ""


## A tool at the smithy can't be used.
static func tool_away(kind: String) -> bool:
	return bool(run["flags"].get("tool_away_" + kind, false))


static func held_tool() -> String:
	var tb: Array = run["toolbar"]
	var id := str(tb[int(run["slot"])])
	if has_tool(id) and tool_away("sword" if is_sword(id) else id):
		return ""  # it's on Gideon's bench
	return id if has_tool(id) else ""


static func select_slot(i: int) -> void:
	run["slot"] = clampi(i, 0, run["toolbar"].size() - 1)
	sync_selected()


## Items in the inventory that are not on the toolbar (the backpack).
static func backpack() -> Array:
	var out: Array = []
	for id in run["inventory"].keys():
		if not run["toolbar"].has(id):
			out.append(id)
	out.sort()
	return out


static func has_tool(id: String) -> bool:
	return run["tools"].has(id)


static func add_tool(id: String) -> void:
	if not has_tool(id):
		run["tools"].append(id)
		var tb: Array = run["toolbar"]
		# Upgrades replace the older tool of the same kind on the toolbar.
		var old := -1
		if is_sword(id):
			# Replace the weakest blade on the toolbar.
			for sw in ["sword", "iron_sword", "steel_sword"]:
				if sw != id and tb.has(sw) and int(items.get(sw, {}).get("damage", 0)) < int(items.get(id, {}).get("damage", 0)):
					old = tb.find(sw)
					break
		if old >= 0:
			tb[old] = id
		else:
			var free := tb.find("")
			if free >= 0:
				tb[free] = id


static func sword_damage() -> int:
	var held := held_tool()
	var best := int(items.get(held, {}).get("damage", 0))
	if best == 0:
		for t in run["tools"]:
			best = maxi(best, int(items.get(t, {}).get("damage", 0)))
	best += int(bonus("combat", "damage")) + gear_stat("damage") + tool_tier("sword")
	if has_team():
		best += int(bonus("leadership", "team_damage"))
	if count("knight_shard") > 0:
		best += 1
	best += mini(2, Crew.perk_level("sword"))
	if has_perk("combat", "Berserker") and int(run["hp"]) < int(run["max_hp"]) / 2:
		best += 2
	return maxi(best, 1)


# ---- skills ------------------------------------------------------------------

static func add_xp(skill: String, xp: int) -> bool:
	var s: Dictionary = run["skills"].get(skill, {"level": 1, "xp": 0, "nodes": {}})
	var mult := 1.15 if has_friend_perk("theo", 8) else (1.10 if has_friend_perk("theo", 4) else (1.05 if has_friend_perk("theo", 2) else 1.0))
	if skill != "leadership" and has_team():
		mult *= 1.0 + bonus("leadership", "team_xp")
	# Carry the fraction so a +5% perk is +5%, not +50% on a 2-xp grant.
	var exact := xp * mult + float(s.get("xp_frac", 0.0))
	s["xp"] = int(s["xp"]) + int(exact)
	s["xp_frac"] = exact - int(exact)
	var leveled := false
	while int(s["xp"]) >= xp_for_next(int(s["level"])):
		s["xp"] = int(s["xp"]) - xp_for_next(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		leveled = true
	run["skills"][skill] = s
	if leveled:
		_apply_max_stats()
	return leveled


## Slow, steady curve: 40, 76, 136, 220, 328, 460, 616, 796, 1000...
static func xp_for_next(level: int) -> int:
	return 40 + level * level * 12 - 12 * level + (level - 1) * 24


static func skill_level(skill: String) -> int:
	return int(run["skills"].get(skill, {}).get("level", 1))


# ---- skill trees (Sun Haven style) ------------------------------------------
# Every level gives one skill point in that skill. Points buy ranks in nodes.
# A node of tier t opens once t*TIER_POINTS points are spent in that tree and
# any one of its `requires` parents has a rank.

const TIER_POINTS := 2


static func nodes_of(skill: String) -> Array:
	return skills_data.get(skill, {}).get("nodes", [])


static func node(skill: String, id: String) -> Dictionary:
	for n in nodes_of(skill):
		if str(n["id"]) == id:
			return n
	return {}


static func node_rank(skill: String, id: String) -> int:
	return int(run["skills"].get(skill, {}).get("nodes", {}).get(id, 0))


static func points_spent(skill: String) -> int:
	var t := 0
	for v in run["skills"].get(skill, {}).get("nodes", {}).values():
		t += int(v)
	return t


static func points_free(skill: String) -> int:
	return maxi(0, skill_level(skill) - 1 + (1 if Perks.flag("skill_point") else 0) - points_spent(skill))


## Why a node can't be bought ("" = it can).
static func node_locked(skill: String, id: String) -> String:
	var n := node(skill, id)
	if n.is_empty():
		return "unknown"
	if node_rank(skill, id) >= int(n.get("ranks", 1)):
		return "maxed"
	if points_free(skill) <= 0:
		return "no points"
	var tier := int(n.get("tier", 0))
	if points_spent(skill) < tier * TIER_POINTS:
		return "needs %d points in %s" % [tier * TIER_POINTS, str(skills_data[skill]["name"])]
	var req: Array = n.get("requires", [])
	if not req.is_empty():
		var ok := false
		for r in req:
			if node_rank(skill, str(r)) > 0:
				ok = true
		if not ok:
			var names: Array = []
			for r in req:
				names.append(str(node(skill, str(r)).get("name", r)))
			return "needs " + " or ".join(names)
	return ""


static func buy_node(skill: String, id: String) -> bool:
	if node_locked(skill, id) != "":
		return false
	run["skills"][skill]["nodes"][id] = node_rank(skill, id) + 1
	_apply_max_stats()
	return true


static func reset_tree(skill: String) -> void:
	run["skills"][skill]["nodes"] = {}
	_apply_max_stats()


## Perk by display name (legacy callers) or node id: true at rank 1+.
static func has_perk(skill: String, perk_name: String) -> bool:
	var id := perk_name.to_lower().replace(" ", "_")
	return node_rank(skill, id) > 0


## Summed effect of ranks bought in a tree, e.g. bonus("combat", "damage").
## Ceilings for stacking effects (the big trees can't make costs negative or
## chances certain).
const BONUS_CAPS := {"farm_energy": 0.6, "mine_energy": 0.6, "block": 0.45, "crit": 0.6, "damage_reduction": 0.6, "wood_discount": 0.6,
	"stone_discount": 0.6, "build_discount": 0.6, "spell_discount": 0.6, "craft_speed": 0.6, "escape_less": 0.9, "pass_risk": 0.2,
	"heat_cool": 0.6, "ability_cooldown": 0.5, "capture_speed": 0.8, "spawner_discount": 0.6, "ticket_bleed": 1.0, "ticket_guard": 0.6, "colony_discount": 0.5, "double_hit": 0.6, "double_harvest": 0.6, "double_fish": 0.6,
	"star_chance": 0.5, "gem_chance": 0.8, "chest_chance": 0.4, "bite_speed": 0.8, "interest": 0.05}


static func bonus(skill: String, key: String) -> float:
	var t := 0.0
	for n in nodes_of(skill):
		var r := node_rank(skill, str(n["id"]))
		if r > 0 and n.has("effect") and n["effect"].has(key):
			t += float(n["effect"][key]) * r
	if BONUS_CAPS.has(key):
		t = minf(t, float(BONUS_CAPS[key]))
	return t


## The arc's own tree: Harmony (penguins) or Hustle (gangsters).
## A partner (companion) or the pup is with you right now.
static func has_team() -> bool:
	return not run.is_empty() and (Companion.active_id() != "" or not run.get("pet", {}).is_empty())


static func arc_skill() -> String:
	return "harmony" if is_penguins() else "hustle"


## Is this skill shown in this run? (each arc hides the other's tree)
static func skill_in_arc(sk: String) -> bool:
	var a := str(skills_data.get(sk, {}).get("arc", ""))
	return a == "" or a == str(run.get("arc", ""))


static func add_arc_xp(n: int) -> bool:
	if run.is_empty():
		return false
	return add_xp(arc_skill(), n)


static func perks_of(skill: String) -> Array:
	return nodes_of(skill)


# ---- equipment ----------------------------------------------------------------

const SLOTS := ["head", "body", "legs", "feet", "hands", "offhand", "back", "belt", "ring", "charm"]


static func equipped(slot: String) -> String:
	return str(run.get("equip", {}).get(slot, ""))


static func equip(id: String) -> void:
	var it: Dictionary = items.get(id, {})
	if it.get("type", "") != "equip":
		return
	var slot := str(it.get("slot", ""))
	var eq: Dictionary = run.get("equip", {})
	var old := str(eq.get(slot, ""))
	if old != "":
		add_item(old, 1)
	add_item(id, -1)
	eq[slot] = id
	run["equip"] = eq
	_apply_max_stats()
	_refresh_wear()


static func unequip(slot: String) -> void:
	var eq: Dictionary = run.get("equip", {})
	var old := str(eq.get(slot, ""))
	if old == "":
		return
	add_item(old, 1)
	eq[slot] = ""
	run["equip"] = eq
	_apply_max_stats()
	_refresh_wear()


static func _refresh_wear() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene is GameMap:
		var gm := tree.current_scene as GameMap
		if gm.player and gm.player._wear:
			gm.player._wear.refresh()


## Sum of a stat across worn gear: defense, speed, luck, damage, energy.
static func gear_stat(stat: String) -> int:
	var total := 0
	for slot in SLOTS:
		var id := equipped(slot)
		if id != "":
			total += int(items.get(id, {}).get("stats", {}).get(stat, 0))
	return total


## ---- Vitals: health 100-scale, energy weighted per task, mana for spells ----
## Health: 100 base, +8 per combat level, Tough +20, Warrior +40, gear "hp".
## Energy: 100 base, +3 per level in every skill (a seasoned farmer lasts
##   longer), Stamina +25, gear "energy". Tasks cost by ENERGY_COST, reduced
##   8% per tool tier (a moon axe is nearly free to swing).
## Mana: 20 base, +12 per magic level, gear "mana"; regenerates slowly, fully
##   on sleep. Spells live in data/spells.json.
## Stardew-tuned: a fresh 100-bar covers ~50 hoe strokes or ~35 axe swings
## before food; tool tiers and perks stretch that further.
const ENERGY_COST := {"hoe": 3, "can": 2, "axe": 3, "pickaxe": 3, "scythe": 1, "rod": 2, "hammer": 2, "sword": 0, "weed": 1, "forage": 0, "plant": 1}
const HEART_HP := 20

static func _apply_max_stats() -> void:
	var levels := 0
	for sk in skills_data.keys():
		if skill_in_arc(str(sk)):
			levels += skill_level(str(sk)) - 1
	var arc_sk := arc_skill() if run.has("arc") else ""
	var base_hp := 100 + 8 * (skill_level("combat") - 1) + int(bonus("combat", "hp")) + gear_stat("hp") + (int(bonus(arc_sk, "hp")) if arc_sk != "" else 0)
	var base_en := 100 + 3 * levels + int(bonus("combat", "energy")) + gear_stat("energy") + (int(bonus(arc_sk, "energy")) if arc_sk != "" else 0)
	var base_mana := 20 + 12 * (skill_level("magic") - 1) + int(bonus("magic", "mana")) + gear_stat("mana") + (int(bonus(arc_sk, "mana")) if arc_sk != "" else 0)
	if has_friend_perk("juniper", 4):
		base_hp += 20
	run["max_hp"] = base_hp + int(run.get("bonus_hp", 0))
	run["max_energy"] = base_en + int(run.get("bonus_energy", 0)) + (50 if has_friend_perk("bram", 10) else 0) + (20 if has_friend_perk("posy", 8) else 0)
	run["max_mana"] = base_mana + int(run.get("bonus_mana", 0))
	if int(run["max_hp"]) > 0 and int(run["hp"]) <= 10 and int(run.get("hp_scale", 6)) == 6:
		run["hp"] = base_hp  # old 6-heart saves: refill on the new scale
	run["hp_scale"] = 100
	run["hp"] = mini(int(run["hp"]), int(run["max_hp"]))
	run["mana"] = mini(int(run.get("mana", base_mana)), int(run["max_mana"]))
	run["energy"] = mini(int(run.get("energy", base_en)), int(run["max_energy"]))


## Energy a tool use costs right now (tier and perks applied).
static func energy_cost(task: String) -> int:
	var base := int(ENERGY_COST.get(task, 2))
	if base == 0:
		return 0
	var tier := tool_tier(task) if TOOL_KINDS.has(task) else 0
	var mult := 1.0 - 0.08 * tier
	if task in ["hoe", "can", "plant"]:
		mult *= 1.0 - bonus("farming", "farm_energy")
	elif task == "pickaxe":
		mult *= 1.0 - bonus("mining", "mine_energy")
	if int(run["energy"]) < int(run["max_energy"]) * 0.15:
		mult *= 1.25  # exhausted: everything is harder
	if weather_today() == "sun" and task != "can":
		mult *= 1.2  # heat wave
	# Fractional costs average out: a 1.6 cost is 1 most swings, 2 sometimes.
	var v := base * mult
	return maxi(0, int(v) + (1 if randf() < v - floorf(v) else 0))


static func spend_for(task: String) -> bool:
	return spend_energy(energy_cost(task))


static func spend_mana(n: int) -> bool:
	var floor_m := 10 if bonus("magic", "awakened") > 0.0 else 0
	if int(run.get("mana", 0)) < n and int(run.get("mana", 0)) <= floor_m:
		if floor_m > 0 and n <= floor_m:
			return true  # Awakening: the last 10 never run dry
		return false
	if int(run.get("mana", 0)) < n:
		return false
	run["mana"] = maxi(floor_m if floor_m > 0 else 0, int(run["mana"]) - n)
	return true


static func restore_mana(n: int) -> void:
	run["mana"] = mini(int(run.get("mana", 0)) + n, int(run.get("max_mana", 20)))


## Damage an enemy deals: enemies.json "dmg" is in hearts-ish units; on the
## 100 scale a grump (1) does 12, the president (4) does 48 before defense.
static func enemy_damage(dmg_units: int) -> int:
	var n := maxi(5, dmg_units * 12)
	if run.get("flags", {}).has("proj_aurora_dome"):
		n = int(n * 0.85)  # the Aurora Dome thins the dark: foes hit softer
	return n


## Permanent growth of a vital (tonics, quest rewards, heart containers).
static func grow_vital(which: String, n: int) -> void:
	var key := "bonus_" + which
	run[key] = int(run.get(key, 0)) + n
	_apply_max_stats()
	run[which] = int(run["max_" + which])  # refill on growth


## Fraction of max, for bars.
static func vital(name: String) -> float:
	return clampf(float(run.get(name, 0)) / maxf(1.0, float(run.get("max_" + name, 1))), 0.0, 1.0)


static func refresh_stats() -> void:
	_apply_max_stats()


# ---- economy modifiers ---------------------------------------------------------

static func buy_multiplier() -> float:
	var m := 1.0 - bonus("bartering", "buy_discount")
	if has_friend_perk("maple", 8): m -= 0.20
	elif has_friend_perk("maple", 4): m -= 0.10
	elif has_friend_perk("maple", 2): m -= 0.05
	return maxf(0.4, m)


static func sell_multiplier() -> float:
	return 1.0 + bonus("bartering", "sell_bonus") + (0.10 if has_friend_perk("alder", 8) else 0.0)


## Roll a drop table: Array of [item, chance, n]. Luck nudges the chance.
static func roll_drops(table: Array, luck_bonus := 0) -> Dictionary:
	var out := {}
	var luck := 1.0 + 0.05 * (gear_stat("luck") + luck_bonus + int(buff("luck")))
	for row in table:
		if randf() < float(row[1]) * luck:
			var n := int(row[2])
			if has_perk("combat", "Champion"):
				n *= 2
			out[str(row[0])] = int(out.get(str(row[0]), 0)) + n
	return out


## Pick one forage item for a region: Array of [item, weight, (skill, level)].
static func roll_forage(region: String) -> String:
	# Rare Finds: sometimes roll twice and keep the rarer find.
	if randf() < bonus("foraging", "rare_forage") * 2.0:
		var a := _roll_forage_once(region)
		var b := _roll_forage_once(region)
		return a if int(items.get(a, {}).get("tier", 1)) >= int(items.get(b, {}).get("tier", 1)) else b
	return _roll_forage_once(region)


static func _roll_forage_once(region: String) -> String:
	var pool: Array = forage_data.get(region, forage_data.get("farm", []))
	var total := 0.0
	var ok: Array = []
	for row in pool:
		if row.size() >= 4 and skill_level(str(row[2])) < int(row[3]):
			continue
		ok.append(row)
		total += float(row[1])
	var r := randf() * total
	for row in ok:
		r -= float(row[1])
		if r <= 0.0:
			return str(row[0])
	return str(ok[0][0]) if not ok.is_empty() else "berry"


static func rarity_color(id: String) -> Color:
	match str(items.get(id, {}).get("rarity", "common")):
		"uncommon": return Color(0.5, 0.9, 0.5)
		"rare": return Color(0.45, 0.65, 1.0)
		"epic": return Color(0.8, 0.5, 1.0)
		"legendary": return Color(1.0, 0.75, 0.3)
	return Color(0.9, 0.9, 0.9)


# ---- energy / hp -------------------------------------------------------------

static func spend_energy(n: int) -> bool:
	if int(run["energy"]) < n:
		return false
	run["energy"] = int(run["energy"]) - n
	return true


static func heal_points(n: int) -> void:
	run["hp"] = mini(int(run["hp"]) + n, int(run["max_hp"]))


static func heal(n: int) -> void:
	# Items list "heal" in old heart units (1-3); scale to the 100-point bar.
	var mult := 1.5 if has_friend_perk("wren", 8) else (1.25 if has_friend_perk("wren", 2) else 1.0)
	run["hp"] = mini(int(run["hp"]) + int(n * HEART_HP * mult), int(run["max_hp"]))


## Eat/drink one item. Returns what actually changed: {"hp": +n, "energy": +n,
## "mana": +n, "grow_<bar>": +n, "buff": "name"} so the HUD can say it.
static func consume(id: String) -> Dictionary:
	var it: Dictionary = items.get(id, {})
	var out := {}
	if it.is_empty() or count(id) <= 0:
		return out
	add_item(id, -1)
	var hp0 := int(run["hp"]); var en0 := int(run["energy"]); var ma0 := int(run.get("mana", 0))
	var mh := Crew.perk_level("meal_heal")
	heal(int(round(int(it.get("heal", 0)) * (1.0 + (0.1 if mh == 1 else (0.25 if mh >= 2 else 0.0))))))
	restore_energy(int(it.get("energy", 0)) + int(it.get("heal", 0)) * 8)
	restore_mana(int(it.get("mana", 0)))
	if int(run["hp"]) != hp0:
		out["hp"] = int(run["hp"]) - hp0
	if int(run["energy"]) != en0:
		out["energy"] = int(run["energy"]) - en0
	if int(run.get("mana", 0)) != ma0:
		out["mana"] = int(run.get("mana", 0)) - ma0
	if it.has("grow"):
		for k in it["grow"]:
			grow_vital(str(k), int(it["grow"][k]))
			out["grow_" + str(k)] = int(it["grow"][k])
	if it.has("buff"):
		# {"buff": {"kind": "speed"|"luck"|"defense"|"warm", "minutes": 120, "amount": 1}}
		var b: Dictionary = it["buff"]
		run["buffs"] = run.get("buffs", {})
		run["buffs"][str(b.get("kind", "luck"))] = {"until": now_abs() + int(b.get("minutes", 120)), "amount": float(b.get("amount", 1))}
		out["buff"] = str(b.get("kind", "luck"))
	return out


## Active buff amount (0 when none / expired).
static func buff(kind: String) -> float:
	var b: Dictionary = run.get("buffs", {}).get(kind, {})
	if b.is_empty() or now_abs() > int(b.get("until", 0)):
		return 0.0
	return float(b.get("amount", 0))


## Minutes since the start of day 1: buffs and timers that cross midnight use this.
static func now_abs() -> int:
	return int(run.get("day", 1)) * 1440 + int(run.get("time", DAY_START))


static func restore_energy(n: int) -> void:
	run["energy"] = mini(int(run["energy"]) + n, int(run["max_energy"]))


# ---- friendship --------------------------------------------------------------
# 25 points per heart, 10 hearts. Talking +5/day, gifts by taste (npcs.json
# likes/dislikes), quests +10..20. Each heart level can unlock a perk
# (npcs.json "perks"); `has_friend_perk(id, hearts)` is what systems check.

const HEART_POINTS := 25


static func friend_hearts(npc: String) -> int:
	return clampi(int(run["friendship"].get(npc, 0)) / HEART_POINTS, 0, 10)


static func has_friend_perk(npc: String, hearts: int) -> bool:
	return friend_hearts(npc) >= hearts


static func friend_perk_at(npc: String, hearts: int) -> String:
	return str(npcs.get(npc, {}).get("perks", {}).get(str(hearts), ""))


## Friendship a gift earns: loved +20 (+bonus), liked +8, neutral +3, hated -8.
## Gifts: one per villager per day, and never tools, seeds, story keys or gear.
const NO_GIFT_TYPES := ["tool", "seed", "key", "equip", "petgear", "placeable", "outfit", "vehicle"]


static func can_gift(npc: String, item: String) -> bool:
	if item == "" or count(item) <= 0 or not items.has(item):
		return false
	if str(items[item].get("type", "")) in NO_GIFT_TYPES:
		return false
	return not (run.get("gifted_today", {}) as Dictionary).has(npc)


## Give a gift: takes the item, adds friendship, remembers today. Returns the gain.
# ---- produce families ----------------------------------------------------------
## Every crop (and what it yields) belongs to a family: veg, herb, berry, fruit,
## tree, grain, mushroom, flower, magic. Recipes can ask for "#veg", villagers
## can like "#berry", the keg brews by family, the fair and journal count them.
const FAMILY_NAMES := {"veg": "Vegetable", "herb": "Herb", "berry": "Berry", "fruit": "Fruit", "tree": "Orchard Fruit", "grain": "Grain", "mushroom": "Mushroom", "flower": "Flower", "magic": "Wonder Crop"}

static func family(id: String) -> String:
	return str(items.get(id, {}).get("family", ""))


static func family_name(f: String) -> String:
	return str(FAMILY_NAMES.get(f.trim_prefix("#"), f.capitalize()))


## How many you carry of an item, or of a whole family ("#veg").
static func count_any(key: String) -> int:
	if not key.begins_with("#"):
		return count(key)
	var f := key.substr(1)
	var n := 0
	for id in run["inventory"]:
		if family(str(id)) == f or (f == "fruit" and family(str(id)) in ["tree", "berry"]):
			n += int(run["inventory"][id])
	return n


## Takes n of an item or family, cheapest first (you keep your prize crops).
static func take_any(key: String, n: int) -> void:
	if not key.begins_with("#"):
		add_item(key, -n)
		return
	var f := key.substr(1)
	var ids: Array = []
	for id in run["inventory"]:
		if family(str(id)) == f or (f == "fruit" and family(str(id)) in ["tree", "berry"]):
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return item_value(a) < item_value(b))
	for id: String in ids:
		if n <= 0:
			break
		var k := mini(n, count(id))
		add_item(id, -k)
		n -= k


## A seed of something in season you could grow now (seed packets, weeds).
static func random_season_seed(max_tier := -1) -> String:
	if max_tier < 0:
		max_tier = mini(5, progress_tier() + 1)
	var se := season()
	var pool: Array = []
	for sid in items:
		var it: Dictionary = items[sid]
		if str(it.get("type", "")) != "seed" or not crops.has(str(it.get("crop", ""))):
			continue
		var cd: Dictionary = crops[str(it["crop"])]
		var cs := str(cd.get("season", "any"))
		if (cs == se or cs == "any") and int(cd.get("tier", 1)) <= max_tier:
			# Commoner seeds turn up more often.
			for w in maxi(1, 4 - int(cd.get("tier", 1))):
				pool.append(str(sid))
	return "" if pool.is_empty() else str(pool[randi() % pool.size()])


## The field log: first harvests of every crop, for the journal and the fair.
static func log_grown(crop: String) -> bool:
	var g: Dictionary = run.get("grown", {})
	var first := not g.has(crop)
	g[crop] = int(g.get(crop, 0)) + 1
	run["grown"] = g
	return first


## What the keg makes from an item: a few signature brews, then by family and tier.
static func keg_brew(id: String) -> String:
	var special := {"strawberry": "strawberry_wine", "corn": "corn_ale", "berry": "berry_juice", "dreamflower": "dream_tonic", "grape": "wine", "apple": "cider", "tea": "herbal_tea"}
	if special.has(id):
		return special[id]
	var t := int(items.get(id, {}).get("tier", 1))
	match family(id):
		"berry", "fruit", "tree":
			return "fruit_wine" if t <= 2 else ("fine_wine" if t == 3 else "starlight_wine")
		"veg":
			return "pickles"
		"herb":
			return "herbal_tea"
		"grain":
			return "harvest_ale"
		"mushroom":
			return "mushroom_broth"
		"flower":
			return "flower_mead"
		"magic":
			return "wonder_elixir"
	return ""


static func need_name(key: String) -> String:
	return ("any " + family_name(key)) if key.begins_with("#") else item_name(key)


static func give_gift(npc: String, item: String) -> int:
	add_item(item, -1)
	var gain := gift_value(npc, item)
	# Remember what they thought of it (for the Social page).
	if not run.has("gift_seen"):
		run["gift_seen"] = {}
	var gs: Dictionary = run["gift_seen"].get(npc, {})
	gs[item] = gain
	run["gift_seen"][npc] = gs
	add_friend(npc, gain)
	var g: Dictionary = run.get("gifted_today", {})
	g[npc] = true
	run["gifted_today"] = g
	return gain


static func add_friend(npc: String, n: int) -> void:
	var fr: Dictionary = run["friendship"]
	if n > 0:
		n = int(round(n * (1.0 + bonus("leadership", "friend_gain"))))
		if npc in Companion.party().get("known", []) or Crew.recruited(npc):
			add_xp("leadership", 3)
	fr[npc] = clampi(int(fr.get(npc, 0)) + n, 0, 250)
	if n > 0:
		for line in Perks.check(npc):
			notify(str(line))
	# Bram's soup: the first chat with him each day tops you up.
	if npc == "bram" and n > 0 and Perks.flag("soup") and int(run["flags"].get("soup_day", -1)) != int(run["day"]):
		run["flags"]["soup_day"] = int(run["day"])
		run["energy"] = mini(int(run["max_energy"]), int(run["energy"]) + 30)
		notify("Bram slides you a bowl of soup. +30 energy.")


## A message for the HUD from code that has no map handy (shown next frame).
static func notify(text: String) -> void:
	if not run.has("notes"):
		run["notes"] = []
	(run["notes"] as Array).append(text)


static func gift_value(npc: String, item: String) -> int:
	var d: Dictionary = npcs.get(npc, {})
	var it: Dictionary = items.get(item, {})
	var base := 3
	var likes: Array = d.get("likes", [])
	var dislikes: Array = d.get("dislikes", [])
	# Likes can name an item or a whole kind ("fish", "crystal", "flower").
	var kind := str(it.get("type", ""))
	var fam := "#" + str(it.get("family", "-"))
	if fam == "#tree" or fam == "#berry":
		if "#fruit" in likes:
			fam = "#fruit"
	if item in likes or (kind != "" and kind in likes) or fam in likes:
		base = 20 if int(it.get("tier", 1)) >= 3 or str(it.get("rarity", "common")) != "common" else 12
	elif item in dislikes or (kind != "" and kind in dislikes) or fam in dislikes:
		base = -8
	elif str(it.get("rarity", "common")) in ["rare", "epic", "legendary"]:
		base = 8
	if base > 0:
		base += int(bonus("bartering", "gift_bonus")) + int(it.get("friend", 0))
		if is_birthday(npc):
			base *= 3
	return base


## [season, day] from data/npcs.json (tools/gen_heart_perks.py).
static func birthday_of(npc: String) -> Array:
	return npcs.get(npc, {}).get("birthday", [])


static func is_birthday(npc: String) -> bool:
	var b := birthday_of(npc)
	return b.size() == 2 and str(b[0]) == season() and int(b[1]) == day_of_season()


## Whose birthday is today ("" if nobody's).
static func birthday_today() -> String:
	for id: String in npcs:
		if is_birthday(id):
			return id
	return ""


# ---- quests ------------------------------------------------------------------

static func add_quest(id: String, text: String) -> void:
	for q in run["quests"]:
		if q["id"] == id:
			return
	run["quests"].append({"id": id, "text": text, "done": false})


static func complete_quest(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id and not q["done"]:
			q["done"] = true
			_give_reward(_quest_def(id).get("reward", {}))
			var m := Engine.get_main_loop().get("current_scene") as GameMap if Engine.get_main_loop() else null
			if m:
				Story.on_quest_done(m, id)
			return true
	return false


static func has_quest(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id:
			return true
	return false


static func _quest_def(id: String) -> Dictionary:
	for q in quests_data.get("main", []) + quests_data.get("side", []):
		if str(q["id"]) == id and str(q.get("arc", "both")) in ["both", str(run["arc"])]:
			return q
	return {}


## Journal hints: short directions picked up from scenes and villagers.
static func add_hint(text: String) -> void:
	var h: Array = run.get("hints", [])
	if text in h:
		return
	h.append(text)
	while h.size() > 12:
		h.pop_front()
	run["hints"] = h


# ---- community board ---------------------------------------------------------
# Three jobs a day pinned on the plaza board: a villager, a thing they need, a
# fair price and some friendship. Jobs are rolled from the day number so they
# are the same for everyone who reads the board that day; accepted ones become
# ordinary side quests handed in to that villager.

const BOARD_POOL := {
	"maple": ["turnip", "strawberry", "corn", "honey", "apple", "wood"], "gideon": ["copper", "coal", "stone", "iron", "nails", "gear", "plating"],
	"wren": ["wild_herb", "mushroom", "slime_goo", "flower"], "finn": ["minnow", "bass", "trout", "bait"],
	"hazel": ["wood", "hay", "plank", "egg", "milk", "beam"], "posy": ["flour", "egg", "honey", "butter", "jam"],
	"bram": ["mushroom", "meat", "trout", "pumpkin"], "juniper": ["wild_herb", "honey", "flower"],
	"rook": ["pelt", "bone", "meat", "leather", "fine_leather"], "theo": ["old_coin", "book", "fossil"], "lumi": ["flower", "sunflower", "shell", "cloth", "linen", "fine_fabric"],
	"alder": ["stone", "wood", "brick", "pumpkin", "tile"], "sal": ["coffee", "bread", "minnow"], "benno": ["hay", "carrot", "apple"], "ivy": ["old_coin", "honey", "cake"],
}


static func board_today() -> Array:
	var b: Dictionary = run.get("board", {})
	if int(b.get("day", -1)) == int(run["day"]):
		return b["jobs"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run["day"]) * 7919 + 13
	var npcs_ok: Array = []
	for id in BOARD_POOL:
		if npcs.has(id):
			npcs_ok.append(id)
	var jobs: Array = []
	var used := {}
	var tier := progress_tier()
	for i in 3:
		var who: String = npcs_ok[rng.randi_range(0, npcs_ok.size() - 1)]
		if used.has(who):
			continue
		used[who] = true
		var pool: Array = BOARD_POOL[who]
		var item: String = pool[rng.randi_range(0, mini(pool.size(), 2 + tier) - 1)]
		if not items.has(item):
			continue
		var n := rng.randi_range(2, 4 + tier * 2)
		var val := maxi(5, item_value(item))
		var pay := int(val * n * 1.6) + 20 * tier
		jobs.append({"id": "board_%d_%d" % [int(run["day"]), i], "npc": who, "item": item, "n": n, "crystals": pay, "friend": 8 + tier * 2})
	# Plus one order for something growing this season (any farmer's crop counts).
	var se := season()
	var crop_pool: Array = []
	for cid in crops:
		var cd: Dictionary = crops[cid]
		if str(cd.get("season", "any")) in [se, "any"] and int(cd.get("tier", 1)) <= tier + 1 and items.has(str(cd["yield"])):
			crop_pool.append(str(cd["yield"]))
	crop_pool.sort()
	if not crop_pool.is_empty():
		var who2: String = ["posy", "maple", "hazel", "wren", "lumi", "theo"][rng.randi_range(0, 5)]
		if npcs.has(who2) and not used.has(who2):
			var item2: String = crop_pool[rng.randi_range(0, crop_pool.size() - 1)]
			var n2 := rng.randi_range(2, 3 + tier)
			jobs.append({"id": "board_%d_c" % int(run["day"]), "npc": who2, "item": item2, "n": n2, "crystals": int(maxi(5, item_value(item2)) * n2 * 1.8) + 15 * tier, "friend": 10 + tier * 2})
	run["board"] = {"day": int(run["day"]), "jobs": jobs}
	return jobs


## Accept a board job: it becomes a side quest in that villager's name.
static func board_accept(job: Dictionary) -> void:
	var id := str(job["id"])
	if has_quest(id):
		return
	var who := str(job["npc"])
	var text := "%s needs %d %s (board job)." % [str(npcs[who]["name"]), int(job["n"]), item_name(str(job["item"]))]
	quests_data["side"].append({"id": id, "giver": who, "text": text, "when": {}, "done_when": {"item": [str(job["item"]), int(job["n"])]}, "take": true, "reward": {"crystals": int(round(int(job["crystals"]) * (1.25 if Crew.perk_level("board_bonus") >= 3 else (1.1 if Crew.perk_level("board_bonus") >= 1 else 1.0)))), "friend": [who, int(job["friend"])]}, "board": true})
	add_quest(id, text)
	# Keep the job itself: the board's list is replaced every day.
	var acc: Dictionary = run.get("board_accepted", {})
	acc[id] = job.duplicate()
	run["board_accepted"] = acc


## Re-register accepted board jobs after a load (quests_data is rebuilt from file).
static func board_restore() -> void:
	for q in run.get("quests", []):
		var id := str(q["id"])
		if id.begins_with("board_") and _quest_def(id).is_empty():
			var b: Dictionary = run.get("board", {})
			var jobs: Array = (b.get("jobs", []) as Array).duplicate()
			var acc: Dictionary = run.get("board_accepted", {})
			if acc.has(id):
				jobs.push_front(acc[id])
			for job in jobs:
				if str(job["id"]) == id:
					var who := str(job["npc"])
					quests_data["side"].append({"id": id, "giver": who, "text": str(q["text"]), "when": {}, "done_when": {"item": [str(job["item"]), int(job["n"])]}, "take": true, "reward": {"crystals": int(round(int(job["crystals"]) * (1.25 if Crew.perk_level("board_bonus") >= 3 else (1.1 if Crew.perk_level("board_bonus") >= 1 else 1.0)))), "friend": [who, int(job["friend"])]}, "board": true})


## Rough "how far along" number 0..4 that scales board jobs, enemies, prices.
## Regional forage/ore respawn: a node cleared on day D comes back after its
## respawn time (days) — common forage 1 day, ore 3, rare nodes 5+, scaled by
## the foraging/mining "regrowth" bonuses.
static func respawned(key: String, respawn_days: int) -> bool:
	var cleared := int(run["flags"].get(key, 0))
	if cleared <= 0:
		return true
	var wait := maxi(1, respawn_days - int(bonus("foraging", "regrowth")))
	return int(run["day"]) >= cleared + wait


## How many of a map's enemies actually show up: half early on, full once the
## meadow is cleared, more once you're deep in the story.
static func enemy_count(base: int) -> int:
	var scale := 0.5 + 0.25 * progress_tier()
	return maxi(1 if base > 0 else 0, int(round(base * minf(1.5, scale))))


static func progress_tier() -> int:
	var t := 0
	if quest_done("clear_meadow"):
		t += 1
	if quest_done("spark") or quest_done("wastes_gate") or quest_done("docks"):
		t += 1
	if quest_done("sky_stair") or quest_done("neon"):
		t += 1
	if quest_done("teleporter") or quest_done("uptown"):
		t += 1
	return t


static func _cond_ok(when: Dictionary) -> bool:
	if when.has("day") and int(run["day"]) < int(when["day"]):
		return false
	if when.has("quest") and not quest_done(str(when["quest"])):
		return false
	if when.has("skill") and skill_level(str(when["skill"][0])) < int(when["skill"][1]):
		return false
	if when.has("flag") and not run["flags"].has(str(when["flag"])):
		return false
	if when.has("season") and season() != str(when["season"]):
		return false
	if when.has("friend") and friend_hearts(str(when["friend"][0])) < int(when["friend"][1]):
		return false
	if when.has("arc") and str(when["arc"]) != str(run["arc"]):
		return false
	if when.has("item"):
		var it = when["item"]
		if it is Array:
			if count(str(it[0])) < int(it[1]):
				return false
		elif count(str(it)) < 1:
			return false
	if when.has("items"):
		for pair in when["items"]:
			if count(str(pair[0])) < int(pair[1]):
				return false
	if when.has("not_flag") and run["flags"].has(str(when["not_flag"])):
		return false
	for f in when.get("flags", []):
		if not run["flags"].has(str(f)):
			return false
	for f in when.get("not_flags", []):
		if run["flags"].has(str(f)):
			return false
	if when.has("crops") and crop_count() < int(when["crops"]):
		return false
	if when.has("not_quest") and quest_done(str(when["not_quest"])):
		return false
	if when.has("decision"):
		var dc: Array = when["decision"]
		if int(run.get("decisions", {}).get(str(dc[0]), -1)) != int(dc[1]):
			return false
	if when.has("kills"):
		var kl: Array = when["kills"]
		if int(run.get("kill_counts", {}).get(str(kl[0]), 0)) < int(kl[1]):
			return false
	if when.has("companion") and Companion.active_id() != str(when["companion"]):
		return false
	if when.has("known") and not (Companion.party().get("known", []) as Array).has(str(when["known"])):
		return false
	if when.has("mine_floor") and int(run["flags"].get("mine_deepest", 1)) < int(when["mine_floor"]):
		return false
	if when.has("crystals") and int(run.get("crystals", 0)) < int(when["crystals"]):
		return false
	if when.has("hearts_total"):
		var tot := 0
		for k in run["friendship"]:
			tot += friend_hearts(str(k))
		if tot < int(when["hearts_total"]):
			return false
	if when.has("chapter") and Story.chapter_no() < int(when["chapter"]):
		return false
	return true


static func _give_reward(rw: Dictionary) -> void:
	if rw.has("crystals"):
		run["crystals"] = int(run["crystals"]) + int(rw["crystals"])
	for k in ["max_hp", "max_energy", "max_mana"]:
		if rw.has(k):
			grow_vital(k.trim_prefix("max_"), int(rw[k]))
	if rw.has("flag"):
		run["flags"][str(rw["flag"])] = true
	if rw.has("item"):
		add_item(str(rw["item"][0]), int(rw["item"][1]))
	if rw.has("xp"):
		add_xp(str(rw["xp"][0]), int(rw["xp"][1]))
	if rw.has("friend"):
		var fr: Dictionary = run["friendship"]
		fr[str(rw["friend"][0])] = int(fr.get(str(rw["friend"][0]), 0)) + int(rw["friend"][1])


## Main-story quests appear as the game progresses; side quests come from the
## person who gives them (see town talk). Returns ids of quests just completed.
static func tick_quests() -> Array:
	var done: Array = []
	for q in quests_data.get("main", []):
		if str(q.get("arc", "both")) not in ["both", str(run["arc"])]:
			continue
		var id := str(q["id"])
		if not has_quest(id) and _cond_ok(q.get("when", {})):
			add_quest(id, str(q["text"]))
	for q in run["quests"]:
		if q["done"]:
			continue
		var d := _quest_def(str(q["id"]))
		if str(d.get("giver", "")) != "":
			continue  # hand it in face to face (Quests.talk)
		if d.has("done_when") and _cond_ok(d["done_when"]):
			if bool(d.get("take", false)):
				var dw: Dictionary = d["done_when"]
				if dw.has("item"):
					add_item(str(dw["item"][0]), -int(dw["item"][1]))
				for pair in dw.get("items", []):
					add_item(str(pair[0]), -int(pair[1]))
			if complete_quest(str(q["id"])):
				done.append(str(q["id"]))
	return done


## A side quest this NPC can offer right now (not yet taken, conditions met).
static func side_quest_for(npc: String) -> Dictionary:
	for q in quests_data.get("side", []):
		if str(q.get("giver", "")) != npc or has_quest(str(q["id"])):
			continue
		if str(q.get("arc", "both")) not in ["both", str(run["arc"])]:
			continue
		if _cond_ok(q.get("when", {})):
			return q
	return {}


static func side_quest_pending(npc: String) -> Dictionary:
	for q in run["quests"]:
		if q["done"]:
			continue
		var d := _quest_def(str(q["id"]))
		if str(d.get("giver", "")) == npc:
			return d
	return {}


static func quest_done(id: String) -> bool:
	for q in run["quests"]:
		if q["id"] == id:
			return bool(q["done"])
	return false


# ---- time / days -------------------------------------------------------------

const DAYS_PER_SEASON := 28
const SEASONS := ["spring", "summer", "fall", "winter"]


static func season() -> String:
	return SEASONS[((int(run.get("day", 1)) - 1) / DAYS_PER_SEASON) % 4]


static func season_of(day: int) -> String:
	return SEASONS[((day - 1) / DAYS_PER_SEASON) % 4]


static func day_of_season() -> int:
	return (int(run.get("day", 1)) - 1) % DAYS_PER_SEASON + 1


static func grass_tile() -> String:
	match season():
		"summer": return "grass_summer"
		"fall": return "grass_fall"
		"winter": return "grass_winter"
	return "grass"


## Tree/bush sprite names per season (variant 0..2).
static func tree_sprite(v: int) -> String:
	match season():
		"summer": return ["apple_tree", "pine", "orange_tree"][v % 3] if Art.has("nature", "apple_tree") else ["oak", "pine", "oak"][v % 3]
		"fall": return ["tree_red", "tree_orange", "tree_birch"][v % 3] if Art.has("nature", "tree_red") else ["oak_autumn", "pine", "oak_autumn"][v % 3]
		"winter": return ["tree_bare", "pine_snow", "tree_bare_s"][v % 3] if Art.has("nature", "tree_bare") else ["oak", "pine", "oak"][v % 3]
	return ["oak", "pine", "oak"][v % 3]


static func bush_sprite(berries: bool) -> String:
	match season():
		"fall": return "berry_bush_fall" if berries else "bush_fall_orange"
		"winter": return "berry_bush_snow" if berries else "bush_snow"
		"summer": return "bush_red" if berries else "bush"
	return "berry_bush" if berries else "bush"


## Weather is rolled per day from the day number so it's stable across scenes.
## Weather: rolled once per day (seeded by run + day so it's stable across
## reloads) and kept in run["weather"][day]. Seasons shift the odds; a wet day
## is likelier after a wet day; storms are rare. Tomorrow's roll is the forecast.
## Effects: rain/storm water every crop and keep villagers in (fish bite more);
## storm also grounds the balloon and blocks the mountain pass; fog halves
## forage respawn visibility (critters hide); snow slows walking a touch;
## heat (summer "sun") dries unwatered crops twice as fast and drains energy;
## fireflies/petals/leaves are cosmetic.
const WEATHER_ODDS := {
	"spring": [["rain", 24], ["storm", 4], ["fog", 8], ["petals", 12], ["wind", 6], ["clear", 46]],
	"summer": [["rain", 10], ["storm", 8], ["sun", 16], ["fireflies", 20], ["wind", 4], ["clear", 42]],
	"fall": [["rain", 20], ["storm", 6], ["fog", 12], ["leaves", 26], ["wind", 10], ["clear", 26]],
	"winter": [["snow", 36], ["blizzard", 6], ["fog", 10], ["wind", 8], ["clear", 40]],
}

static func weather_for(day: int) -> String:
	var w: Dictionary = run.get("weather", {})
	var key := str(day)
	if w.has(key):
		return str(w[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(run.get("names", {}).get("town", "")) + ":" + key)
	var se := season_of(day)
	var table: Array = WEATHER_ODDS.get(se, WEATHER_ODDS["spring"])
	var roll := rng.randi_range(0, 99)
	var yesterday := str(w.get(str(day - 1), "clear"))
	if yesterday in ["rain", "storm"] and rng.randf() < 0.35:
		roll = rng.randi_range(0, 30)  # weather fronts linger
	var acc := 0
	var pick := "clear"
	for pair in table:
		acc += int(pair[1])
		if roll < acc:
			pick = str(pair[0])
			break
	if day <= 2 and pick in ["storm", "blizzard", "fog"]:
		pick = "clear"  # gentle first days
	w[key] = pick
	run["weather"] = w
	return pick


static func weather_today() -> String:
	return weather_for(int(run.get("day", 1)))


static func forecast() -> String:
	return weather_for(int(run.get("day", 1)) + 1)


## Festivals: one per season, on the 14th, held on the town plaza.
const FESTIVALS := {"spring": ["egg", "Egg Festival"], "summer": ["lantern", "Lantern Festival"], "fall": ["harvest", "Harvest Fair"], "winter": ["star", "Star Festival"]}
const FESTIVAL_DAY := 14


static func festival_today() -> String:
	if day_of_season() != FESTIVAL_DAY:
		return ""
	return str(FESTIVALS[season()][0])


static func festival_name(id: String) -> String:
	for se in FESTIVALS:
		if str(FESTIVALS[se][0]) == id:
			return str(FESTIVALS[se][1])
	return id.capitalize()


static func is_wet() -> bool:
	return weather_today() in ["rain", "storm"]


static func weather_name(w: String) -> String:
	return {"rain": "Rain", "storm": "Storm", "fog": "Fog", "petals": "Petal breeze", "wind": "Windy", "sun": "Heat wave", "fireflies": "Warm night", "leaves": "Falling leaves", "snow": "Snow", "blizzard": "Blizzard", "clear": "Clear"}.get(w, w.capitalize())


static func clock_text() -> String:
	var t := int(run["time"]) % (24 * 60)
	var h := t / 60
	var m := t % 60
	var suffix := "am" if h < 12 else "pm"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## Advance to the next morning: crops grow, sell box pays, energy restores.
static func sleep(passed_out := false) -> Dictionary:
	status_clear()
	_apply_max_stats()
	var report := {"earned": 0, "sold": [], "grown": 0}
	if bonus("bartering", "interest") > 0.0:
		run["crystals"] = int(run["crystals"]) + mini(int(int(run["crystals"]) * bonus("bartering", "interest")), 50 + 50 * progress_tier())
	var total := 0
	run["sold_today"] = {}
	for id in run["sellbox"].keys():
		var n: int = int(run["sellbox"][id])
		var v := sell_price(id, n)
		run["sold_today"][id] = n
		total += v
		report["sold"].append("%s x%d = %d" % [item_name(id), n, v])
	var qb := quality_bonus_value(run.get("sellbox_q", {}))
	if qb > 0:
		total += qb
		report["sold"].append("quality bonus = %d" % qb)
	run["sellbox_q"] = {}
	if total > 0:
		add_xp("bartering", total / 4)
	run["sold_today"] = {}
	run["crystals"] = int(run["crystals"]) + total
	report["earned"] = total
	run["sellbox"] = {}
	# Hazel helps on the farm once you're friends (every other day at 4 hearts, daily at 6).
	var hazel_waters := has_friend_perk("hazel", 6) or (has_friend_perk("hazel", 4) and int(run["day"]) % 2 == 0)
	_sprinklers_water()
	Project.overnight(report)
	for key in run["farm"].keys():
		var tile: Dictionary = run["farm"][key]
		var crop_id := str(tile.get("crop", ""))
		if crop_id != "" and not crops.has(crop_id):
			tile["crop"] = ""  # a seed whose crop isn't defined: nothing to grow
			crop_id = ""
		if crop_id != "":
			var cd: Dictionary = crops[crop_id]
			var cs := str(cd.get("season", "any"))
			var se := season()
			# Winter kills anything that isn't a winter crop, watered or not,
			# unless it's in the greenhouse (built).
			var is_tree := bool(cd.get("tree", false))
			if se == "winter" and cs != "winter" and cs != "any" and not Builds.is_built("greenhouse") and not is_tree:
				tile["crop"] = ""
				tile["days"] = 0
				tile["acc"] = 0.0
				tile["watered"] = false
				report["died"] = int(report.get("died", 0)) + 1
				continue
			if has_friend_perk("hazel", 8) and int(tile.get("days", 0)) >= int(cd["days"]):
				var yid := str(cd["yield"])
				run["sellbox"][yid] = int(run["sellbox"].get(yid, 0)) + 1
				log_grown(crop_id)
				if cd.has("regrow"):
					tile["days"] = int(cd["days"]) - int(cd["regrow"])
				else:
					tile["crop"] = ""
					tile["days"] = 0
				tile["acc"] = 0.0
				tile["watered"] = false
				continue
			if tile.get("watered", false) or is_wet() or hazel_waters:
				# Growth: in its season a crop grows a full day; out of season half
				# a day (it struggles). Fertiliser and the farming tree speed it.
				var rate := 1.0
				if Project.has("prism_array"):
					rate += 0.25
				if cs != "any" and cs != se and not Builds.is_built("greenhouse"):
					rate = 0.5
					if bool(cd.get("tree", false)):
						rate = 0.0  # orchard trees rest out of season; they don't die
						report["dormant"] = int(report.get("dormant", 0)) + 1
				rate += bonus("farming", "growth")
				if bool(tile.get("fert", false)):
					rate += 0.5
				tile["acc"] = float(tile.get("acc", 0.0)) + rate
				while float(tile["acc"]) >= 1.0:
					tile["acc"] = float(tile["acc"]) - 1.0
					tile["days"] = int(tile.get("days", 0)) + 1
				if rate > 0.0 and randf() < bonus("farming", "extra_day"):
					tile["days"] = int(tile.get("days", 0)) + 1
				report["grown"] += 1
			tile["watered"] = false
		else:
			tile["watered"] = false
	for nm in Builds.tick_overnight():
		report["built"] = report.get("built", []) + [nm]
	Racket.overnight(report)
	Sanctuary.overnight(report)
	if Crew.perk_level("fence") >= 3 and int(run["day"]) % 7 == 6:
		var relic: String = ["relic_orb", "relic_mask", "relic_blade", "relic_crown"][randi() % 4]
		add_item(relic, 1)
		report["relic"] = relic
	if has_friend_perk("posy", 2):
		add_item("bread", 1)
	if int(run.get("bank", 0)) > 0 and has_friend_perk("ivy", 2):
		# Interest: 1% (2% with Ivy 6), capped so it's a nest egg, not a printer.
		var rate := 0.02 if has_friend_perk("ivy", 6) else 0.01
		run["bank"] = int(run["bank"]) + mini(int(round(int(run["bank"]) * rate)), 40 + 40 * progress_tier())
	run["day"] = int(run["day"]) + 1
	run["time"] = DAY_START
	# Decisions that matter: a bitter companion leaves for the east after day 20.
	var party_d: Dictionary = run.get("party", {})
	for cid in party_d.get("bitter", []):
		if int(run["day"]) >= 20 and not run["flags"].has("gone_east_" + str(cid)) and not (party_d.get("known", []) as Array).has(cid):
			run["flags"]["gone_east_" + str(cid)] = true
			run["flags"]["bitter_left"] = true
			add_hint("%s was seen on the east road at night, heading for the dark." % str(Companion.defs().get(cid, {}).get("name", cid)))
			report["gone"] = report.get("gone", []) + [str(Companion.defs().get(cid, {}).get("name", cid))]
	run["energy"] = int(run["max_energy"]) if not passed_out or has_friend_perk("juniper", 8) else int(run["max_energy"]) / 2
	run["hp"] = int(run["max_hp"])
	run["mana"] = int(run.get("max_mana", 20))
	run["talked_today"] = {}
	run["gifted_today"] = {}
	for line in Perks.morning():
		notify(str(line))
	var nm := Mail.morning()
	if nm > 0:
		notify("You have %d new letter%s. (Mailbox on the farm, or MENU → Quests → Mail)" % [nm, "" if nm == 1 else "s"])
	var tp := Ops.morning()
	if tp > 0:
		notify("Your blocks paid ◆%d overnight." % tp)
	var bd := birthday_today()
	if bd != "":
		notify("It's %s's birthday today! Gifts count triple." % str(npcs[bd].get("name", bd)))
	# The pup heals overnight; a rest day ends with full health.
	var pt: Dictionary = run.get("pet", {})
	if not pt.is_empty():
		pt["hp"] = Pet.max_hp() if int(pt.get("hp", 0)) <= 0 or int(pt.get("rest_until", 0)) <= int(run["day"]) else mini(Pet.max_hp(), int(pt["hp"]) + Pet.max_hp() / 2)
	save()
	return report


static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameState: can't open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func look_d() -> Dictionary:
	var lk: Variant = run.get("look", {})
	if lk is Dictionary:
		return lk
	return {}


# ---- unified tiers ------------------------------------------------------------
## One weight table (data/tiers.json) drives enemy stats, armour, knockback
## resistance, abilities, status strength, loot and xp. Everything that fights
## or buffs asks here, so the whole ecosystem moves together.

static func tier_count() -> int:
	return (tier_data.get("tiers", []) as Array).size()


static func tier(t: int) -> Dictionary:
	var ts: Array = tier_data.get("tiers", [])
	if ts.is_empty():
		return {"hp": 1.0, "dmg": 1.0, "speed": 1.0, "kb_resist": 0.0, "armor": 0, "status_power": 1.0, "status_secs": 3.0, "xp": 1.0, "loot": 1.0, "abilities": []}
	return ts[clampi(t, 0, ts.size() - 1)]


static func tier_name(t: int) -> String:
	return str(tier(t).get("name", "Tier %d" % t))


## The kind's native tier from enemies.json.
static func enemy_tier(kind: String) -> int:
	return int(enemy_data.get("enemies", {}).get(kind, {}).get("tier", 0))


## Multiplier to move a kind from its native tier to `t`.
static func tier_scale(kind: String, t: int, stat: String) -> float:
	var nt := enemy_tier(kind)
	var a := float(tier(nt).get(stat, 1.0))
	var b := float(tier(t).get(stat, 1.0))
	return b / maxf(0.01, a)


## The player's own tier: gear + combat skill + magic, 0..5. Used for the
## area/mine difficulty hints and to weight status durations against you.
static func player_tier() -> int:
	var t := 0.0
	t += tool_tier("sword") * 0.8
	t += skill_level("combat") * 0.25
	t += gear_stat("defense") * 0.4
	t += skill_level("magic") * 0.15
	return clampi(int(floor(t)), 0, tier_count() - 1)


## Mine floor -> tier.
static func mine_tier(floor_no: int) -> int:
	var per := int(tier_data.get("mine", {}).get("floors_per_tier", 4))
	return clampi((floor_no - 1) / per, 0, tier_count() - 1)


# ---- player statuses ---------------------------------------------------------
## Short combat statuses enemies inflict (poison, burn, chill, slow, weak, blind),
## kept as remaining seconds in run["status"]. Strength comes from the enemy's tier.

static func status_def(name: String) -> Dictionary:
	return tier_data.get("statuses", {}).get(name, {})


static func status_apply(name: String, t: int) -> void:
	if status_def(name).is_empty():
		return
	if has_perk("combat", "Iron Gut") and name in ["poison", "burn"]:
		return
	if buff("warm") > 0.0 and name in ["chill", "freeze", "cold"]:
		return
	if run.get("flags", {}).has("colony_frost_step") and name in ["chill", "freeze", "cold", "slow"]:
		return
	var secs := float(tier(t).get("status_secs", 3.0)) * (0.7 if gear_stat("defense") >= 3 else 1.0) * (0.5 if Crew.perk_level("status_half") >= 2 else 1.0)
	run["status"] = run.get("status", {})
	var cur: Dictionary = run["status"].get(name, {})
	run["status"][name] = {"secs": maxf(float(cur.get("secs", 0.0)), secs), "power": float(tier(t).get("status_power", 1.0)), "tier": t}


static func status_active(name: String) -> bool:
	return float(run.get("status", {}).get(name, {}).get("secs", 0.0)) > 0.0


static func status_power(name: String) -> float:
	return float(run.get("status", {}).get(name, {}).get("power", 1.0))


static func status_clear(name := "") -> void:
	if name == "":
		run["status"] = {}
	elif run.has("status"):
		run["status"].erase(name)


## Called by the player every frame. Returns hp damage to apply this tick.
static func status_tick(delta: float) -> int:
	var st: Dictionary = run.get("status", {})
	if st.is_empty():
		return 0
	var dmg := 0.0
	for k in st.keys():
		var d: Dictionary = st[k]
		d["secs"] = float(d.get("secs", 0.0)) - delta
		var def := status_def(str(k))
		if def.has("dps"):
			d["acc"] = float(d.get("acc", 0.0)) + float(def["dps"]) * float(d.get("power", 1.0)) * delta
			if d["acc"] >= 1.0:
				dmg += floor(d["acc"])
				d["acc"] = fmod(float(d["acc"]), 1.0)
		if d["secs"] <= 0.0:
			st.erase(k)
		else:
			st[k] = d
	return int(dmg)


## Speed multiplier from statuses (chill/slow).
static func status_speed() -> float:
	var m := 1.0
	for k in run.get("status", {}):
		var def := status_def(str(k))
		if def.has("speed"):
			m *= float(def["speed"])
	return m


## Swing cooldown multiplier (chill makes you slow to swing).
static func status_swing() -> float:
	var m := 1.0
	for k in run.get("status", {}):
		m *= float(status_def(str(k)).get("swing", 1.0))
	return m


## Dazed (blind): your swings land off-line by up to this many pixels.
static func status_aim() -> float:
	var a := 0.0
	for k in run.get("status", {}):
		a += float(status_def(str(k)).get("aim", 0)) * 12.0
	return a


static func status_damage_mod() -> int:
	var m := 0
	for k in run.get("status", {}):
		m += int(status_def(str(k)).get("damage", 0))
	return m


## How many harvested crops (any kind) are in the pack.
static func crop_count() -> int:
	var n := 0
	for id in run["inventory"]:
		if str(items.get(id, {}).get("type", "")) == "crop":
			n += int(run["inventory"][id])
	return n


## Remove n crops of any kind (most plentiful first).
static func take_crops(n: int) -> void:
	var ids: Array = []
	for id in run["inventory"]:
		if str(items.get(id, {}).get("type", "")) == "crop":
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(run["inventory"][a]) > int(run["inventory"][b]))
	for id in ids:
		if n <= 0:
			break
		var take := mini(n, int(run["inventory"][id]))
		add_item(str(id), -take)
		n -= take


## Placed sprinklers water the tiles around them before the night's growth.
const SPRINKLER_REACH := {"sprinkler": 1, "sprinkler_quality": 2, "sprinkler_iridium": 3}
static func _sprinklers_water() -> void:
	var placed: Dictionary = run.get("placed", {})
	for key in placed:
		var kind := str(placed[key])
		if not SPRINKLER_REACH.has(kind):
			continue
		var xy := str(key).split(",")
		var cx := int(xy[0])
		var cy := int(xy[1])
		var r := int(SPRINKLER_REACH[kind])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx == 0 and dy == 0:
					continue
				var ok := false
				match r:
					1: ok = absi(dx) + absi(dy) == 1
					2: ok = absi(dx) <= 1 and absi(dy) <= 1
					_: ok = true
				var k2 := "%d,%d" % [cx + dx, cy + dy]
				if ok and run["farm"].has(k2):
					run["farm"][k2]["watered"] = true


## One line telling a phone player what to do next: the first open main quest,
## else the chapter summary.
static func next_step() -> String:
	if run.is_empty():
		return ""
	var pinned := str(run.get("pinned_quest", ""))
	for q in run.get("quests", []):
		if not bool(q.get("done", false)) and (pinned == "" or str(q["id"]) == pinned):
			return str(q.get("text", ""))
	for q in run.get("quests", []):
		if not bool(q.get("done", false)):
			return str(q.get("text", ""))
	var j := Story.journal()
	return str(j.get("summary", ""))
