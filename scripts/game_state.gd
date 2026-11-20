class_name GameState
extends RefCounted
## The one place the player's run lives. Plain Dictionary so it saves to user://
## and can be synced for co-op later. Everything that changes the world goes here.

const SAVE_KEY := "run"
const DAY_START := 6 * 60      # 6:00
const DAY_END := 26 * 60       # 2:00 next day: pass out
## Real minutes for the waking day (6am-2am, 1200 game minutes), per save
## slot in run.day_len (Tom C4: 15/20/30/40; 15 is the classic pace).
const DAY_LENGTHS := [15, 20, 30, 40]
const DAY_LEN_DEFAULT := 15

static var run: Dictionary = {}


## The run's day length in real minutes (one of DAY_LENGTHS).
static func day_len() -> int:
	return _valid_len(int(run.get("day_len", DAY_LEN_DEFAULT)))


static func _valid_len(n: int) -> int:
	return n if n in DAY_LENGTHS else DAY_LEN_DEFAULT


## Game minutes per real second: the waking day (DAY_END - DAY_START) lasts
## day_len() real minutes (15 -> 1.33, 40 -> 0.5).
static func minutes_per_second() -> float:
	return float(DAY_END - DAY_START) / (float(day_len()) * 60.0)


## Game minutes that pass in `sec` real seconds at this run's pace (rounded up,
## at least 1). Real-time timers (buffs, mana, wardens) use it so they last
## the same on every day length.
static func real_min(sec: float) -> int:
	return maxi(1, ceili(sec * minutes_per_second() - 0.0001))


## Real seconds per mana point (was 20/15/10 game minutes at the old 0.7 s pace).
static func mana_regen_secs() -> float:
	return maxf(3.5, 14.0 - 3.5 * int(bonus("magic", "mana_regen")))

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


static func new_run(arc: String, playable_id: String, character_name: String, town_name: String, pet_name: String, opts := {}) -> void:
	load_data()
	quests_data = load_json("res://data/quests.json")
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
		"energy": ENERGY_BASE, "max_energy": ENERGY_BASE, "en_ver": 11,
		"hp": 100, "max_hp": 100, "mana": 20, "max_mana": 20, "hp_scale": 100,
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
		"sold_today": {},
		"quests": [],
		"scene": "farm",
		"mine_floor": 1,
		"kills": 0,
		"intro_done": false,
		"skill_ver": SKILL_VER,
		"opts": {"difficulty": clampi(int(opts.get("difficulty", Difficulty.DEFAULT)), 0, 3)},
		"day_len": _valid_len(int(opts.get("day_len", DAY_LEN_DEFAULT))),
	}
	add_item("turnip_seed", 6)
	add_item("berry", 2)
	save()


static func has_run() -> bool:
	load_data()
	if run.is_empty():
		var saved: Variant = SaveGame.get_value(save_key())
		if saved is Dictionary and not saved.is_empty():
			run = (saved as Dictionary).duplicate(true)
			# Villagers fresh from data: a gangster slot loaded earlier this session
			# must not leave its crew in a penguin save's town.
			npcs = load_json("res://data/npcs.json")
			quests_data = load_json("res://data/quests.json")  # board defs belong to one run
			Companion._ready_at = {}
			_migrate()
			# A story scene that was cut off (app closed) plays again from the start.
			if run.has("story_pending"):
				run["flags"].erase("st_" + str(run["story_pending"]))
				run.erase("story_pending")
			board_restore()
			battle_resume_fix()
	return not run.is_empty()


## C3 (saves F1/F2/F4): a save made on a battlefield (Save & title mid-fight, or
## the app closed during the win/loss lines) must not reopen a free battle.
## Only a fight or drill still under way resumes there; otherwise the run goes
## back where the fight was launched from (its record's "back"), or the farm.
static func battle_resume_fix() -> void:
	var sc := str(run.get("scene", ""))
	if not sc.begins_with("bf_"):
		return
	if not Campaign.fight_for(sc).is_empty() or not CampaignGate.drill_for(sc).is_empty():
		return
	var f: Dictionary = (run.get("campaign", {}) as Dictionary).get("fight", {}) if run.get("campaign", {}) is Dictionary else {}
	var back: Array = f.get("back", []) if f.get("back", []) is Array else []
	if back.size() >= 3 and str(back[0]) != "" and not str(back[0]).begins_with("bf_") and ResourceLoader.exists("res://scenes/%s.tscn" % str(back[0])):
		run["scene"] = str(back[0])
		run["spawn"] = [float(back[1]), float(back[2]), "down"] if float(back[1]) > 0.0 else []
	else:
		run["scene"] = "farm"
		run["spawn"] = []
	if run.get("campaign", {}) is Dictionary:
		(run["campaign"] as Dictionary)["fight"] = {}  # the fight is over (or was left)


## Unlock ids are name slugs: add an entry whenever an unlock is renamed.
## (Dropped fillers such as Starborn magic_3_8 are simply refunded.)
const NODE_RENAMES := {"combat_u_killing_edge": "combat_u_keen_edge", "combat_2_8": "combat_u_iron_gut", "hustle_u_hot_loads": "hustle_u_fresh_rounds"}
## Renames that only apply when the old node was bought under this name.
const NODE_RENAME_NAME := {"combat_2_8": "Iron Gut"}
## Bump when gen_skill_trees.py changes what existing filler nodes do: old saves get those points back.
const SKILL_VER := 8


## Older saves (or saves from before a new field existed) get the missing keys.
static func _migrate() -> void:
	# C4: difficulty and day length are per slot (the old global Easy switch -> Easy).
	if not run.get("opts", null) is Dictionary:
		run["opts"] = {"difficulty": 1 if Difficulty.legacy_easy() else Difficulty.DEFAULT}
	elif not (run["opts"] as Dictionary).has("difficulty"):
		run["opts"]["difficulty"] = Difficulty.DEFAULT
	run["day_len"] = _valid_len(int(run.get("day_len", DAY_LEN_DEFAULT)))
	Tickets._st()  # Rec Center tickets / arcade bests (old saves start at zero)
	Romance.st()  # dating/marriage state (old saves: single, friendship untouched)
	ArcadeHub._data()  # cabinet milestones / plays (run.arcade_hub)
	if not (run.get("skills") is Dictionary):
		run["skills"] = {}
	for sk in (run["skills"] as Dictionary).keys():
		if not (run["skills"][sk] is Dictionary):
			run["skills"][sk] = {"level": 1, "xp": 0, "nodes": {}}
	# The toolbar always has 12 slots.
	if run.has("toolbar") and run["toolbar"] is Array:
		while (run["toolbar"] as Array).size() < 12:
			(run["toolbar"] as Array).append("")
	if run.has("look") and run["look"] == null:
		run.erase("look")
	# Skill nodes that no longer exist (the trees were rebuilt): drop them, which refunds the points.
	if run.has("skills"):
		var renamed_back := 0
		for sk in run["skills"]:
			var have: Dictionary = (run["skills"][sk] as Dictionary).get("nodes", {}) if run["skills"][sk] is Dictionary else {}
			if have.is_empty() or not skills_data.has(sk):
				continue
			var ids := {}
			var nm := {}
			var aka := {}  # earlier names of a node whose effect did not change (gen_skill_trees.py)
			for n in skills_data[sk].get("nodes", []):
				ids[str(n["id"])] = int(n.get("ranks", 1))
				nm[str(n["id"])] = str(n.get("name", ""))
				aka[str(n["id"])] = n.get("aka", [])
			var bought_nm: Dictionary = (run["skills"][sk] as Dictionary).get_or_add("nm", {})
			for nid in have.keys():
				var ren := str(NODE_RENAMES.get(str(nid), ""))
				if ren != "" and NODE_RENAME_NAME.has(str(nid)) and str(bought_nm.get(str(nid), NODE_RENAME_NAME[str(nid)])) != str(NODE_RENAME_NAME[str(nid)]):
					ren = ""
				var moved := false
				if ren != "" and ids.has(ren) and not have.has(ren):
					have[ren] = mini(int(have[nid]), int(ids[ren]))
					bought_nm[ren] = str(nm[ren])
					moved = true
				# Positional ids can be reused by a different node when a tree is rebuilt:
				# ranks bought under another name are refunded, not moved to the new perk.
				var was := str(bought_nm.get(str(nid), nm.get(str(nid), "")))
				# A rename alone (same id, same effect) keeps the ranks silently.
				if ids.has(str(nid)) and was != str(nm[str(nid)]) and (aka[str(nid)] as Array).has(was):
					bought_nm[str(nid)] = str(nm[str(nid)])
					was = str(nm[str(nid)])
				if not ids.has(str(nid)) or was != str(nm.get(str(nid), "")):
					if not moved:
						renamed_back += maxi(0, int(have[nid]) - int((run.get("gift_nodes", {}) as Dictionary).get(str(sk) + "|" + str(nid), 0)))
					have.erase(nid)
					bought_nm.erase(nid)
				elif int(have[nid]) > int(ids[str(nid)]):
					have[nid] = ids[str(nid)]
		if renamed_back > 0:
			notify("Some skills were renamed or removed: %d skill point%s came back. Spend them in Menu > Skills." % [renamed_back, "" if renamed_back == 1 else "s"])
		# Filler nodes keep their positional id and name when the generator changes
		# their effect, so the name check can't see it: refund every positional rank
		# once per SKILL_VER (base and unlock nodes are kept).
		if int(run.get("skill_ver", 0)) < SKILL_VER:
			var rx := RegEx.create_from_string("^[a-z]+_\\d_\\d$")
			var back := 0
			for sk in run["skills"]:
				if not run["skills"][sk] is Dictionary:
					continue
				var hv: Dictionary = (run["skills"][sk] as Dictionary).get("nodes", {})
				var hn: Dictionary = (run["skills"][sk] as Dictionary).get("nm", {})
				for nid in hv.keys():
					if rx.search(str(nid)) != null:
						back += int(hv[nid])
						hv.erase(nid)
						hn.erase(nid)
			if back > 0:
				notify("The skill trees changed: %d skill point%s came back. Spend them in Menu > Skills." % [back, "" if back == 1 else "s"])
			run["skill_ver"] = SKILL_VER
			_bonus_frame = -1
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
		SaveGame.set_value(save_key() + "_unreadable", run)
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
	Storage._all()  # moves an old flags.chest stash into the farm chest now
	var old_max := int(run.get("max_energy", 100))
	_apply_max_stats()
	if int(run.get("en_ver", 0)) < 11:
		# Round 11 energy revamp: the bigger bar arrives with its extra room filled.
		run["en_ver"] = 11
		run["energy"] = mini(int(run["max_energy"]), int(run.get("energy", 0)) + maxi(0, int(run["max_energy"]) - old_max))
		run["en_frac"] = 0.0


static func save() -> void:
	# A copy: the save cache must never share the live day in progress.
	SaveGame.set_value(save_key(), (Net.save_view(run) as Dictionary).duplicate(true))


## Three save slots. Slot 1 keeps the old "run" key so existing saves are slot 1.
static func slot() -> int:
	return clampi(int(SaveGame.get_value("slot", 1)), 1, 3)


## Each slot keeps its own "farm you can bring back" (Restore).
static func prev_key() -> String:
	return "run_prev" if slot() <= 1 else "run_prev_%d" % slot()


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
	var o: Dictionary = r.get("opts", {}) if r.get("opts", {}) is Dictionary else {}
	var dl := int(r.get("day_len", DAY_LEN_DEFAULT))
	var dn := int(o.get("difficulty", 1 if Difficulty.legacy_easy() and not r.has("opts") else Difficulty.DEFAULT))
	return "%s · %s · day %d\n%s · %d-min days" % [str(r["names"].get("character", "?")), arc, int(r.get("day", 1)), Difficulty.name_of(dn), _valid_len(dl)]


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
	var txt := buf.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary or not (d as Dictionary).has("names") or not (d as Dictionary).has("arc") or not (d as Dictionary).has("playable"):
		return "The code is cut off or has a typo."
	var cur: Variant = SaveGame.get_value(save_key(), null)
	var old_prev: Variant = SaveGame.get_value(prev_key(), null)
	if cur is Dictionary and not (cur as Dictionary).is_empty():
		SaveGame.set_value(prev_key(), cur)
	run = {}
	SaveGame.set_value(save_key(), d)
	if not has_run():
		if cur is Dictionary and not (cur as Dictionary).is_empty():
			SaveGame.set_value(save_key(), cur)
			SaveGame.set_value(prev_key(), old_prev)  # the older Restore farm comes back too
			run = {}
			has_run()
		return "That save couldn't be read."
	return ""


## A guest's morning when the host's day rolls over: pay their own sell box,
## refill, clear the day's talk/gift marks. (Farm growth is the host's job.)
## Open quests from villagers the story sent away can never be handed in: drop them.
## Board jobs lapse a week after they were pinned, crop orders two (the board posts new ones every day).
## (Lapsing only on our own sleep: a guest's day is the host's.)
static func _drop_gone_quests(lapse := false) -> void:
	var today := int(run["day"])
	run["quests"] = (run["quests"] as Array).filter(func(q: Dictionary) -> bool:
		if bool(q["done"]):
			return true
		var qid := str(q["id"])
		if lapse and qid.begins_with("board_") and qid.get_slice("_", 1).is_valid_int() \
				and today - int(q.get("pin_day", int(qid.get_slice("_", 1)))) > (14 if qid.ends_with("_c") else 7):
			notify("Too late for the board job: %s" % str(q["text"]))
			return false
		var giver := str(_quest_def(qid).get("giver", ""))
		return giver == "" or not run["flags"].has(giver + "_gone"))
	# Accepted board jobs are only needed while their quest is open (board_restore).
	var acc: Dictionary = run.get("board_accepted", {})
	for id: String in acc.keys():
		if not has_quest(id) or quest_done(id):
			acc.erase(id)


static func guest_morning() -> Dictionary:
	status_clear()
	_drop_gone_quests()
	_apply_max_stats()
	var report := {"earned": 0}
	var total := 0
	if not run.has("sold_today"):
		run["sold_today"] = {}
	for id in run["sellbox"].keys():
		total += sell_price(id, int(run["sellbox"][id]))
	total += quality_bonus_value(run.get("sellbox_q", {}))
	run["sellbox_q"] = {}
	run["sellbox"] = {}
	run["sold_today"] = {}
	add_money(total, "sales")
	report["earned"] = total
	run["energy"] = int(run["max_energy"])
	run["fed_en"] = 0
	run["rest_en"] = 0
	run["kills_today"] = {}  # a guest never sleeps here: the host's morning resets the kill pay too
	run["hp"] = int(run["max_hp"])
	run["mana"] = int(run.get("max_mana", 20))
	run["talked_today"] = {}
	run["gifted_today"] = {}
	if int(run["day"]) % 7 == 1:
		run["gifts_week"] = {}
	# The laundromat, pool and burrow that count are on our own farm (the host's builds are loaded now).
	# Wash at our own tier; pool/burrow gifts wait for our own nights (our farm's days don't pass while we visit).
	var hb: Variant = run.get("builds", null)
	var nn := Net.i()
	var own: Variant = nn._solo_backup.get("builds", null) if nn != null and nn.visiting() else hb
	if own is Dictionary:
		run["builds"] = own
	else:
		run.erase("builds")
	Racket.overnight(report)
	if hb is Dictionary:
		run["builds"] = hb
	else:
		run.erase("builds")
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
	if id == "sword" and street_bat():
		return ("%s Street Bat" % TOOL_TIERS[tool_tier(id)].capitalize()) if tool_tier(id) > 0 else "Street Bat"
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
const ORE_TIER := {"stone": 0, "coal": 0, "copper": 0, "clay": 0, "iron": 1, "shard": 1, "dark": 3, "silver": 2, "gold": 2, "ruby": 2, "fossil": 2, "crystal": 3, "mithril": 3, "amethyst": 3, "emerald": 3, "moon_shard": 4, "moon": 4, "tin": 2, "sunstone": 3, "sapphire": 3, "frost": 3, "star_dust": 3, "storm_glass": 4, "platinum": 4}  # mega ores (C4): region tier - 1
const ORE_SKILL := {"tin": 3, "sunstone": 5, "sapphire": 6, "frost": 6, "star_dust": 6, "storm_glass": 7, "platinum": 8, "dark": 5, "silver": 3, "gold": 4, "ruby": 4, "crystal": 5, "mithril": 6, "amethyst": 5, "emerald": 6, "moon_shard": 7}


## "" when you can gather this, else the reason (already phrased for a toast).
static func gather_block(tool: String, need_tier: int, skill: String, need_level: int, what: String) -> String:
	if tool_tier(tool) < need_tier:
		return "%s is too hard for your %s. Gideon upgrades tools (%s)." % [what.capitalize(), item_name(tool).to_lower(), TOOL_TIERS[need_tier]]
	if need_level > 0 and skill_level(skill) < need_level:
		return "%s needs %s level %d (you're %d)." % [what.capitalize(), skill.capitalize(), need_level, skill_level(skill)]
	return ""


static func ore_block(ore: String) -> String:
	return gather_block("pickaxe", int(ORE_TIER.get(ore, 0)), "mining", int(ORE_SKILL.get(ore, 0)), ore.replace("_", " "))


## Trees: ordinary trees need any axe; big old hardwood trees copper + foraging 3;
## crystal trees iron + foraging 5.
static func tree_block(thing: Dictionary) -> String:
	var hp := int(thing.get("hp", 3))
	var kind := str(thing.get("wood", "wood"))
	# Ordinary trees always come down with any axe; only the special ones are gated.
	if kind == "crystal_wood":
		return gather_block("axe", 2, "foraging", 5, "the crystal tree")
	if kind == "hardwood":
		return gather_block("axe", 1, "foraging", 3, "this old tree")
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
	if kind == "sword" and street_bat():
		return "bat_%s" % TOOL_TIERS[tool_tier(k)]
	return "%s_%s" % [k, TOOL_TIERS[tool_tier(k)]]


## Tom (Guide 26 #1): the gangster arc starts with a Street Bat, not a sword.
## It is the same starter weapon underneath (id "sword": tiers, Gideon's bench,
## damage), only named and drawn as a bat (items/bat_<tier>).
static func street_bat() -> bool:
	return not run.is_empty() and str(run.get("arc", "")) == "gangsters"


## The starter weapon's word for hints ("sword" / "bat").
static func weapon_word() -> String:
	return "bat" if street_bat() else "sword"


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
# fish/forage for more in winter) × today's saturation (first 12 of a thing at
# full price, then -10% per further 6, floor 30%) × bartering/friend bonuses. Buying:
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
	if Crew.perk_level("fence") >= 2 and str(items.get(id, {}).get("type", "")) in ["drop", "treasure", "junk", "ore", "gem"]:
		return 1.0  # Marlene takes any amount of loot at full value
	var already := int(sold.get(id, 0)) + n_more
	# The first 12 of a thing sell at full price; after that the town has had
	# enough of it: -10% per further 6, floor 30%. Grow and gather a mix.
	if already < 12:
		return 1.0
	return maxf(0.3, 1.0 - 0.10 * (1 + (already - 12) / 6))


static func sell_price(id: String, n := 1) -> int:
	var unit := unit_sell_value(id)
	var total := 0.0
	for i in n:
		total += unit * saturation(id, i)
	return int(round(total))


## One piece's sell value with every perk and today's demand, before the daily
## saturation (C8 P1: shop floors read this, so dumping a stack on the fence
## doesn't make the same item cheap in the shops for the rest of the day).
static func unit_sell_value(id: String) -> float:
	var unit := item_value(id) * demand(id) * sell_multiplier() * (1.0 + minf(0.20, 0.02 * (skill_level("bartering") - 1))) * (1.0 + 0.05 * Crew.perk_level("sell_bonus"))
	if family(id) != "":
		unit *= 1.0 + bonus("farming", "crop_value")
	if str(items.get(id, {}).get("type", "")) == "fish":
		unit *= 1.0 + bonus("fishing", "fish_value")
	if Crew.perk_level("fence") >= 1 and str(items.get(id, {}).get("type", "")) in ["drop", "treasure", "junk"] and str(run.get("arc", "")) == "gangsters":
		unit *= 1.2
	return unit


## Shops never sell below what a piece sells back for (x SHOP_FLOOR) so they are
## no money machine, but the floor never lifts a price above the plain
## undiscounted one (C8 P1: Bartering/Alder sell perks used to push the floor
## over every buy discount, so an expert paid more than a novice).
const SHOP_FLOOR := 1.05

static func _shop_floor(id: String, cap: float) -> float:
	return minf(unit_sell_value(id) * SHOP_FLOOR, cap)


## A hand-priced stall can be cheap, but never cheaper than what the item sells for.
static func shop_price(id: String, listed: int) -> int:
	return maxi(listed, int(ceil(_shop_floor(id, maxf(float(listed), item_value(id) * 1.5)))))


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
	# The undiscounted price (tier markup and season included): the floor's ceiling.
	var plain := base * m / maxf(0.01, buy_multiplier())
	m *= [1.0, 0.95, 0.9, 0.9][clampi(Crew.perk_level("shop_discount"), 0, 3)]  # Specs knows the till codes
	return maxi(1, int(ceil(maxf(base * m, _shop_floor(id, plain)))))


static func count(id: String) -> int:
	return int(run["inventory"].get(id, 0))


## Bag size (Sun Haven style): slots for different items; tools on their own.
## Backpack upgrades (run["bag_up"], 0-3) add 12 slots each.
const BAG_BASE := 30
const BAG_STEP := 12
const BAG_MAX_UP := 3


static func bag_size() -> int:
	return BAG_BASE + BAG_STEP * int(run.get("bag_up", 0))


static func bag_used() -> int:
	return (run["inventory"] as Dictionary).size()


static func bag_free() -> int:
	return bag_size() - bag_used()


## Bag and chest order (Organise button), Stardew's: tools and weapons first,
## then its category order (gems/minerals, fish, animal goods, cooking,
## crafting/placeables, ores and bars, resources, seeds, vegetables, fruit,
## flowers, forage, rings and gear), then name, then the better stack (gold /
## silver stars), then the bigger stack. Stacks of one kind are always merged
## (one bag slot per kind), and the toolbar row never moves.
const SORT_RANK := {"tool": 0, "weapon": 1, "gem": 2, "mineral": 2, "fish": 3, "animal": 4, "egg": 4, "milk": 4, "food": 5, "dish": 5, "tonic": 5, "potion": 5, "drink": 5, "placeable": 6, "craft": 6, "station": 6, "ore": 7, "bar": 8, "material": 9, "resource": 9, "seed": 10, "crop": 11, "fruit": 12, "flower": 13, "forage": 14, "equip": 15, "petgear": 16, "gift": 17, "key": 19, "quest": 19}


static func item_order(a: String, b: String) -> bool:
	var ra := int(SORT_RANK.get(str(items.get(a, {}).get("type", "")), 18))
	var rb := int(SORT_RANK.get(str(items.get(b, {}).get("type", "")), 18))
	if ra != rb:
		return ra < rb
	var nc := item_name(a).naturalnocasecmp_to(item_name(b))
	if nc != 0:
		return nc < 0
	var qa := quality_of(a) if run.has("quality") else {}
	var qb := quality_of(b) if run.has("quality") else {}
	var sa := int(qa.get("g", 0)) * 2 + int(qa.get("s", 0))
	var sb := int(qb.get("g", 0)) * 2 + int(qb.get("s", 0))
	if sa != sb:
		return sa > sb
	return a < b


## Trash asks once for a valuable stack (Tom C6 P7): starred, rare+ or worth
## TRASH_ASK_VALUE or more in all; everyday stacks go straight in, like Stardew.
const TRASH_ASK_VALUE := 100

static func trash_needs_confirm(id: String) -> bool:
	var q := quality_of(id)
	if int(q.get("g", 0)) + int(q.get("s", 0)) > 0:
		return true
	if not str(items.get(id, {}).get("rarity", "common")) in ["common", ""]:
		return true
	return item_value(id) * count(id) >= TRASH_ASK_VALUE


static func sort_bag() -> void:
	var inv: Dictionary = run["inventory"]
	var ids: Array = inv.keys()
	ids.sort_custom(item_order)
	var d := {}
	for id in ids:
		d[id] = inv[id]
	run["inventory"] = d
	run["bag_sorted"] = true
	run["bag_slots"] = Slots.sorted(bag_slots(), run.get("bag_lock", {}), item_order)


## The bag as Sun Haven shows it: one slot per kind, in the player's own order.
static func bag_slots() -> Array:
	if not (run.get("bag_slots") is Array):
		var ids: Array = (run["inventory"] as Dictionary).keys()
		if not bool(run.get("bag_sorted", false)):
			ids.sort()
		run["bag_slots"] = ids
	return Slots.reconcile(run["bag_slots"], run["inventory"], bag_size(), 0)


static func bag_move(from: int, to: int) -> void:
	Slots.move(bag_slots(), from, to)


static func is_locked(id: String) -> bool:
	return (run.get("bag_lock", {}) as Dictionary).has(id)


static func toggle_lock(id: String) -> void:
	if not run.has("bag_lock") or not (run["bag_lock"] is Dictionary):
		run["bag_lock"] = {}
	if run["bag_lock"].has(id):
		run["bag_lock"].erase(id)
	else:
		run["bag_lock"][id] = true


static func can_trash(id: String) -> bool:
	var t := str(items.get(id, {}).get("type", ""))
	return count(id) > 0 and not has_tool(id) and not t in ["tool", "key", "quest", "upgrade", "vehicle"] and not is_locked(id)


## Throw n away. Returns how many went.
static func trash(id: String, n: int) -> int:
	if not can_trash(id):
		return 0
	n = mini(n, count(id))
	add_item(id, -n)
	return n


## Tools that aren't on the toolbar (they never take bag slots).
static func loose_tools() -> Array:
	var out: Array = []
	for t in run.get("tools", []):
		if not (run["toolbar"] as Array).has(t):
			out.append(t)
	return out


## Co-op: we're a guest on someone else's world (also while reconnecting).
static func visiting() -> bool:
	return Net.visiting()


## Set when a new item didn't fit and went to the farm chest (Hud shows it).
static var overflow_note := ""


static func add_item(id: String, n: int = 1, force := false) -> void:
	var inv: Dictionary = run["inventory"]
	# Bag full: a new kind of item goes to the farm chest instead of vanishing.
	if n > 0 and not force and not inv.has(id) and bag_free() <= 0 and not str(items.get(id, {}).get("type", "")) in ["tool", "key", "quest"] and run.has("toolbar") \
			and (Builds.is_built("chest") if not visiting() else (run.get("chests", {}) as Dictionary).has("chest")) and Storage.room_for("chest", id) >= n:
		var b := Storage.box("chest")
		b["items"][id] = int(b["items"].get(id, 0)) + n
		_mark_seen(id)
		overflow_note = "Bag full: %s sent to your farm chest." % item_name(id)
		_overflow_id = id
		return
	inv[id] = int(inv.get(id, 0)) + n
	if n < 0:
		_trim_quality(id)
	elif n > 0:
		_mark_seen(id)
	if inv[id] <= 0:
		inv.erase(id)
		# The lock stays with the item kind (a chest round trip keeps it).
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
	if run.has("bag_slots"):
		bag_slots()  # a new kind takes the first empty slot; a used-up kind leaves a hole
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


static var _overflow_id := ""


static func add_quality(id: String, q: String, n: int) -> void:
	# A starred harvest that just overflowed to the farm chest keeps its star there.
	if n > 0 and id == _overflow_id and count(id) == 0:
		_overflow_id = ""
		var cq: Dictionary = Storage.box("chest")["q"]
		var d2: Dictionary = cq.get(id, {})
		var other := int(d2.get("s" if q == "g" else "g", 0))
		d2[q] = clampi(int(d2.get(q, 0)) + n, 0, maxi(0, Storage.amount("chest", id) - other))
		cq[id] = d2
		return
	if not run.has("quality"):
		run["quality"] = {}
	var d: Dictionary = run["quality"].get(id, {})
	d[q] = int(d.get(q, 0)) + n
	# Never more starred items than you hold (an overflowed crop keeps no stars on the bag).
	var over := int(d.get("g", 0)) + int(d.get("s", 0)) - count(id)
	if over > 0:
		var cut := mini(over, int(d.get(q, 0)))
		d[q] = int(d[q]) - cut
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
		# Per-piece price of the whole box of it (saturation included).
		var nb := maxi(1, int(run.get("sellbox", {}).get(id, 1)))
		var unit := float(sell_price(id, nb)) / nb
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


## Whatever item sits in the selected toolbar slot (if you have any of it).
static func held_item() -> String:
	var tb: Array = run.get("toolbar", [])
	if tb.is_empty():
		return ""
	var id := str(tb[clampi(int(run.get("slot", 0)), 0, tb.size() - 1)])
	return id if count(id) > 0 else ""


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
	# Tools off the toolbar wait here too, so nothing you own can vanish.
	for t in run.get("tools", []):
		if not run["toolbar"].has(t) and not out.has(t):
			out.append(t)
	if not bool(run.get("bag_sorted", false)):
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
			if free < 0:  # a full bar: the first non-tool slot makes room (that item stays in the bag)
				for i in tb.size():
					if not run["tools"].has(str(tb[i])):
						free = i
						break
			if free >= 0:
				tb[free] = id


## Tom (CONDUCT 2): in the mines the pickaxe hit as hard as a sword (sword_damage
## falls back to your best blade). Farm tools swung at a foe deal TOOL_FIGHT of
## that (about 30%, at least 1): usable in a pinch, never a weapon.
const TOOL_FIGHT := 0.3


static func tool_fight_damage(held: String, dmg: int) -> int:
	if held == "" or is_sword(held) or items.get(held, {}).has("range"):
		return dmg
	return maxi(1, int(round(dmg * TOOL_FIGHT)))


static func sword_damage() -> int:
	var held := held_tool()
	var best := int(items.get(held, {}).get("damage", 0))
	if best == 0 or held == "sword":
		for t in run["tools"]:
			if not items.get(t, {}).has("range"):  # guns don't make melee stronger
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

## True while GameMap.xp grants XP (it shows its own level-up toast).
static var _xp_loud := false


static func add_xp(skill: String, xp: int) -> bool:
	var s: Dictionary = run["skills"].get(skill, {"level": 1, "xp": 0, "nodes": {}})
	last_levels = 0
	if int(s.get("level", 1)) >= MAX_LEVEL:
		s["level"] = MAX_LEVEL  # mastered: XP stops (C8 P1)
		s["xp"] = 0
		run["skills"][skill] = s
		return false
	var mult := 1.15 if has_friend_perk("theo", 8) else (1.10 if has_friend_perk("theo", 4) else (1.05 if has_friend_perk("theo", 2) else 1.0))
	if skill != "leadership" and has_team():
		mult *= 1.0 + minf(TEAM_XP_CAP, bonus("leadership", "team_xp"))
	mult *= 1.0 + bonus(skill, "xp_gain")  # "Studied" nodes: this skill levels faster
	# Carry the fraction so a +5% perk is +5%, not +50% on a 2-xp grant.
	var exact := xp * mult + float(s.get("xp_frac", 0.0))
	s["xp"] = int(s["xp"]) + int(exact)
	s["xp_frac"] = exact - int(exact)
	var lv0 := int(s["level"])
	while int(s["level"]) < MAX_LEVEL and int(s["xp"]) >= xp_for_next(int(s["level"])):
		s["xp"] = int(s["xp"]) - xp_for_next(int(s["level"]))
		s["level"] = int(s["level"]) + 1
	if int(s["level"]) >= MAX_LEVEL:
		s["xp"] = 0
	var leveled := int(s["level"]) > lv0
	last_levels = int(s["level"]) - lv0
	last_crossed5 = leveled and (int(s["level"]) / 5 > lv0 / 5)
	run["skills"][skill] = s
	# Every level-up gets a note, unless GameMap.xp is already showing its own popup.
	if leveled and not _xp_loud:
		notify(level_up_text(skill))
	if leveled:
		_apply_max_stats()
	return leveled


## Levels the last add_xp call gained (a big grant can jump several), and
## whether one of them was a multiple of 5 (the bigger fanfare).
static var last_levels := 0
static var last_crossed5 := false


## Words for a level-up: plural points, nothing to spend once the tree is full,
## "mastered" at the top (C8 P1). GameMap.xp can show the same line.
static func level_up_text(skill: String) -> String:
	var nm := skill_name(skill)
	var lv := skill_level(skill)
	if lv >= MAX_LEVEL:
		return "%s mastered! Level %d." % [nm, lv]
	var pf := points_free(skill)
	if pf <= 0:
		return "%s level %d!" % [nm, lv]
	var got := mini(pf, maxi(1, last_levels))
	if got > 1:
		return "%s level %d! %d skill points to spend (MENU → Skills)." % [nm, lv, got]
	return "%s level %d! A skill point to spend (MENU → Skills)." % [nm, lv]


## The level curve (C8 P1). 40, 70, 100 ... 400 by level 13 (unchanged early),
## then +XP_GROWTH a level, and it ends at MAX_LEVEL (enough for every rank of
## the biggest tree, 96). Old curve was flat at 400 forever: farming hit lv 100
## in year 1. Pacing: tools/c8_curve_test.gd prints levels at day 28/112/336.
const MAX_LEVEL := 100
const XP_FLAT_END := 13
const XP_GROWTH := 1.03
## Per-level terms (hp/mana per level, crop quality, can size, spell power,
## crit, player tier) stop growing here: past it, levels buy tree points only.
const LEVEL_EFFECT_CAP := 20
## Leadership's team_xp nodes stack across the tree: one ceiling.
const TEAM_XP_CAP := 0.25

static func xp_for_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 999999
	if level < XP_FLAT_END:
		return 40 + 30 * (level - 1)
	return int(round(400.0 * pow(XP_GROWTH, float(level - XP_FLAT_END))))


## Level for per-level formulas: capped at LEVEL_EFFECT_CAP.
static func skill_level_eff(skill: String) -> int:
	return mini(skill_level(skill), LEVEL_EFFECT_CAP)


static func skill_level(skill: String) -> int:
	return mini(MAX_LEVEL, int(run["skills"].get(skill, {}).get("level", 1)))


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


## Skill-tree unlocks: which node (if any) teaches a station blueprint or a spell.
static var _unlock_cache := {}


static func _unlocks() -> Dictionary:
	if _unlock_cache.is_empty():
		_unlock_cache = {"blueprint": {}, "spell": {}}
		var S: Dictionary = skills_data
		for sk in S:
			for n in S[sk].get("nodes", []):
				var e: Dictionary = n.get("effect", {})
				for kind in ["blueprint", "spell"]:
					if e.has(kind):
						_unlock_cache[kind][str(e[kind])] = [str(sk), str(n["id"]), str(n["name"])]
	return _unlock_cache


## "" if you can build it, else the node that teaches it, e.g. "Brewer's Blueprint (Farming tree)".
static func blueprint_lock(bid: String) -> String:
	var u: Variant = _unlocks()["blueprint"].get(bid)
	if u == null or node_rank(str(u[0]), str(u[1])) > 0:
		return ""
	return "learn %s (%s tree)" % [str(u[2]), skill_name(str(u[0]))]


static func spell_from_tree(spell: String) -> bool:
	var u: Variant = _unlocks()["spell"].get(spell)
	return u != null and node_rank(str(u[0]), str(u[1])) > 0


static func skill_name(sk: String) -> String:
	return str(skills_data.get(sk, {}).get("name", sk.capitalize()))


## Walking speed from every tree's movement nodes (capped).
static func move_bonus() -> float:
	var t := 0.0
	for sk in skills_data.keys():
		t += bonus(str(sk), "move_speed")
	return minf(t, 0.25)


static func node_rank(skill: String, id: String) -> int:
	return int(run["skills"].get(skill, {}).get("nodes", {}).get(id, 0))


static func points_spent(skill: String) -> int:
	var t := 0
	var nodes: Dictionary = run["skills"].get(skill, {}).get("nodes", {})
	var gifted: Dictionary = run.get("gift_nodes", {})
	for k in nodes:
		# Spells a colony gave you were a gift, not a point you spent.
		t += maxi(0, int(nodes[k]) - int(gifted.get(skill + "|" + str(k), 0)))
	return t


static func points_free(skill: String) -> int:
	var raw := maxi(0, skill_level(skill) - 1 + (1 if Perks.flag("skill_point") else 0) - points_spent(skill))
	return mini(raw, ranks_left(skill))  # a full tree has nothing to spend on (C8 P1)


## Ranks still to buy in a tree (0 = every node maxed).
static func ranks_left(skill: String) -> int:
	var t := 0
	for n in nodes_of(skill):
		t += maxi(0, int(n.get("ranks", 1)) - node_rank(skill, str(n["id"])))
	return t


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
	# Remember what was bought under this id, so a rebuilt tree can't turn it into another perk.
	(run["skills"][skill] as Dictionary).get_or_add("nm", {})[id] = str(node(skill, id).get("name", ""))
	_bonus_frame = -1
	_apply_max_stats()
	return true


static func reset_tree(skill: String) -> void:
	var keep := {}  # colony-gift spells were free: a respec keeps them
	for gk in (run.get("gift_nodes", {}) as Dictionary):
		if str(gk).get_slice("|", 0) == skill:
			keep[str(gk).get_slice("|", 1)] = int(run["gift_nodes"][gk])
	run["skills"][skill]["nodes"] = keep
	(run["skills"][skill] as Dictionary).erase("nm")
	_bonus_frame = -1
	_apply_max_stats()


## Perk by display name (legacy callers) or node id: true at rank 1+.
static func has_perk(skill: String, perk_name: String) -> bool:
	var id := perk_name.to_lower().replace(" ", "_")
	if node_rank(skill, id) > 0:
		return true
	# Perks that live on a positional or unlock node: match by name.
	for n in nodes_of(skill):
		if str(n.get("name", "")) == perk_name and node_rank(skill, str(n["id"])) > 0:
			return true
	return false


## Summed effect of ranks bought in a tree, e.g. bonus("combat", "damage").
## Ceilings for stacking effects (the big trees can't make costs negative or
## chances certain).
const BONUS_CAPS := {"farm_energy": 0.6, "mine_energy": 0.6, "block": 0.25, "crit": 0.3, "damage_reduction": 0.35, "wood_discount": 0.6,
	"stone_discount": 0.6, "build_discount": 0.6, "spell_discount": 0.6, "craft_speed": 0.6, "escape_less": 0.5, "pass_risk": 0.2,
	"heat_cool": 0.6, "ability_cooldown": 0.5, "capture_speed": 0.8, "spawner_discount": 0.6, "ticket_bleed": 1.0, "ticket_guard": 0.6, "colony_discount": 0.5, "double_hit": 0.6, "double_harvest": 0.6, "double_fish": 0.6,
	"star_chance": 0.5, "gem_chance": 0.8, "chest_chance": 0.4, "bite_speed": 0.6, "interest": 0.05, "buy_discount": 0.5,
	"sell_bonus": 0.30, "crop_value": 0.35, "fish_value": 0.5, "ore_bonus": 0.6, "extra_crop": 0.3, "forage_bonus": 12.0,
	"rare_fish": 0.4, "rare_forage": 0.3, "growth": 0.5, "extra_day": 0.25, "shard_bonus": 1.5, "gift_bonus": 10.0, "mana_regen": 3.0,
	"animal_yield": 1.0, "sap_chance": 1.0, "pet_def": 6.0, "pet_speed": 0.6, "supply_rate": 1.0,
	"wood_bonus": 8.0, "stone_bonus": 6.0, "seed_back": 0.5, "smelt_discount": 1.0, "chop_bonus": 4.0, "wash_bonus": 0.05, "job_pay": 0.5, "chop_power": 2.0, "mine_power": 2.0,
	"xp_gain": 0.5, "energy": 40.0, "hp": 60.0, "mana": 60.0, "start_supply": 30.0, "helper_hp": 40.0, "pet_hp": 60.0, "move_speed": 0.1,
	"regrowth": 2.0, "last_stand": 1.0, "free_cast": 0.15,
	"wide_water": 1.0, "timber": 1.0, "tremor": 1.0, "tidecall": 1.0, "quick_build": 1.0, "jackpot": 0.05, "pet_dmg": 24.0, "gun_damage": 12.0}
## Per-tree overrides of BONUS_CAPS (Combat's own nodes give 120 hp: Tough,
## Warrior, Legend). tools/gen_skill_trees.py reads this too.
const SKILL_CAPS := {"combat": {"hp": 140.0, "energy": 60.0}}


static var _bonus_cache := {}
static var _bonus_frame := -1


static func bonus(skill: String, key: String) -> float:
	# Cached for the current frame: the pup, partner and player ask many times a frame.
	var fr := Engine.get_process_frames()
	if fr != _bonus_frame:
		_bonus_frame = fr
		_bonus_cache.clear()
	var ck := skill + "|" + key
	if _bonus_cache.has(ck):
		return float(_bonus_cache[ck])
	var v := _bonus_raw(skill, key)
	_bonus_cache[ck] = v
	return v


static func _bonus_raw(skill: String, key: String) -> float:
	var t := 0.0
	for n in nodes_of(skill):
		var r := node_rank(skill, str(n["id"]))
		if r > 0 and n.has("effect") and n["effect"].has(key):
			t += float(n["effect"][key]) * r
	var cap: Variant = (SKILL_CAPS.get(skill, {}) as Dictionary).get(key, BONUS_CAPS.get(key))
	if cap != null:
		t = minf(t, float(cap))
	return t


## The arc's own tree: Harmony (penguins) or Hustle (gangsters).
## A partner (companion) or the pup is with you right now.
static func has_team() -> bool:
	if run.is_empty():
		return false
	if Companion.active_id() != "":
		return true
	# The pup counts only while it's actually out with you and on its feet.
	var t := Engine.get_main_loop() as SceneTree
	var m: GameMap = t.current_scene as GameMap if t and t.current_scene is GameMap else null
	return m != null and m.pet != null and is_instance_valid(m.pet) and m.pet.visible and not Pet.resting() and int(Pet.state().get("hp", 0)) > 0 and str(Pet.state().get("mode", "follow")) != "wait"


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
	add_item(id, -1)  # first, so the old piece can use the freed bag slot
	if old != "":
		add_item(old, 1)
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
	total += CharSheet.set_bonus(stat)  # armour set bonuses (4 / 8 pieces of one set)
	return total


## ---- Vitals: health 100-scale, energy weighted per task, mana for spells ----
## Health: 100 base, +8 per combat level, Tough +20, Warrior +40, gear "hp".
## Mana: 20 base, +12 per magic level, gear "mana"; regenerates slowly, fully
##   on sleep. Spells live in data/spells.json.
##
## Energy (round 11 revamp, Stardew / Sun Haven feel):
##   Max: 120 to start, +3 per level in every skill (up to +120), skill-tree
##   "energy" nodes, gear "energy", friend perks, and +4 for every 5 mine floors
##   reached (up to +40). A seasoned farmer ends near 300.
##   Cost per action = base (ENERGY_COST) x skill factor x tool factor, kept as
##   a fraction (run["en_frac"]) so 0.6 really is 0.6 on average, never random.
##     skill factor: -3.5% per level in the task's skill (ENERGY_SKILL), floor 0.6
##     tool factor:  -12%/tier for hoe/can/scythe/plant, -8%/tier otherwise
##     together never below 25% of base; tree perks (farm_energy, mine_energy) on top.
##   Walking and running are free; swimming costs a little; sword swings and
##   dodges cost a little. Below 15% you're Exhausted: a warning, a red bar and
##   slower feet (costs don't climb, so there's no death spiral). At 0 you pass
##   out (GameMap.player_down("tired")).
##   Day-1 check (C8 P1, 120 bar, level 1, wood tools, x1.15 early factor):
##   a pickaxe swing is ~0.69 and a stone takes 3 swings (~2.1 a rock), so mine
##   floors 1-3 at ~10 rocks each plus ~40 sword swings and 4 dodges are ~30 a
##   floor (~90 for three); hoeing, planting and watering 15 tiles is ~27. The
##   keeper thresholds on floors 1-3 (mine.gd, P4) decide how many rocks a floor
##   really asks. tools/first_week_test.gd models a week with these numbers.
const ENERGY_COST := {"hoe": 0.8, "can": 0.6, "axe": 1.0, "pickaxe": 0.6, "scythe": 0.2, "rod": 1.2, "hammer": 0.8, "sword": 0.15, "weed": 0.25, "forage": 0.0, "plant": 0.15, "dodge": 0.8, "swim": 0.5}
const ENERGY_SKILL := {"hoe": "farming", "can": "farming", "plant": "farming", "scythe": "farming", "weed": "foraging", "axe": "foraging", "pickaxe": "mining", "rod": "fishing", "sword": "combat", "dodge": "combat", "hammer": "building"}
const ENERGY_BASE := 120
## C8 P1: passive max energy from summed skill levels. Was +3 a level up to 40
## levels (+120: the bar doubled by day 28 and stopped binding in week 3). Now
## +1.5 a level up to 30 levels (+45); the rest of the growth is chosen: house
## tiers, tree nodes (all trees together <= TREE_EN_CAP), gear, mine milestones.
const ENERGY_PER_LEVEL := 1.5
const ENERGY_LEVELS_MAX := 30
const TREE_EN_CAP := 120
const TREE_HP_CAP := 200

static func level_energy(levels: int) -> int:
	return int(floor(ENERGY_PER_LEVEL * float(mini(levels, ENERGY_LEVELS_MAX))))

const EXHAUSTED_FRAC := 0.15
const HEART_HP := 20

static func _apply_max_stats() -> void:
	var levels := 0
	for sk in skills_data.keys():
		if skill_in_arc(str(sk)):
			levels += skill_level(str(sk)) - 1
	var arc_sk := arc_skill() if run.has("arc") else ""
	# Health and energy nodes count from every tree you can use.
	var tree_hp := 0
	var tree_en := 0
	for sk in skills_data.keys():
		if skill_in_arc(str(sk)):
			tree_hp += int(bonus(str(sk), "hp"))
			tree_en += int(bonus(str(sk), "energy"))
	# C8 P1: one ceiling over every tree (each tree's own cap still applies inside it).
	tree_hp = mini(tree_hp, TREE_HP_CAP)
	tree_en = mini(tree_en, TREE_EN_CAP)
	var base_hp := 100 + 8 * (skill_level_eff("combat") - 1) + tree_hp + gear_stat("hp")
	var base_en := ENERGY_BASE + level_energy(levels) + tree_en + gear_stat("energy") + energy_milestones()
	var base_mana := 20 + 12 * (skill_level_eff("magic") - 1) + int(bonus("magic", "mana")) + gear_stat("mana") + (int(bonus(arc_sk, "mana")) if arc_sk != "" else 0)
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


## Progress-based stamina: +4 max energy for every 5 mine floors you've reached (up to +40).
static func energy_milestones() -> int:
	var deepest := int(run.get("flags", {}).get("mine_deepest", 1))
	return mini(40, 4 * (deepest / 5))


## Exact (fractional) energy a task costs right now: skill level, tool tier and perks applied.
static func energy_cost_f(task: String) -> float:
	var base := float(ENERGY_COST.get(task, 1.0))
	if base <= 0.0:
		return 0.0
	var sk := str(ENERGY_SKILL.get(task, ""))
	var skill_mult := 1.0
	if sk != "" and run.has("skills"):
		# C6 P7: early work costs a little more (x1.15 at level 1, back to x1.0
		# by level 5), then the usual -3.5% a level down to the 0.6 floor.
		var lv := float(skill_level(sk) - 1)
		skill_mult = maxf(0.6, 1.0 - 0.035 * lv) * (1.0 + 0.15 * maxf(0.0, 1.0 - lv / 4.0))
	var tier := 0
	if task in ["sword", "dodge"]:
		tier = 0  # a better blade hits harder; it doesn't swing lighter
	elif TOOL_KINDS.has(task):
		tier = tool_tier(task)
	elif task == "plant":
		tier = tool_tier("hoe")
	# Better hoes and cans save more (they are the everyday tools).
	var tool_mult := 1.0 - (0.12 if task in ["hoe", "can", "plant", "scythe"] else 0.08) * tier
	var mult := maxf(0.25, skill_mult * tool_mult)
	if task in ["hoe", "can", "plant"]:
		mult *= 1.0 - bonus("farming", "farm_energy")
	elif task == "pickaxe":
		mult *= 1.0 - bonus("mining", "mine_energy")
	if weather_today() == "sun" and task in ["hoe", "axe", "pickaxe"] and in_the_heat():
		mult *= 1.1  # heat wave: heavy work is a little harder (outdoors only, C8 P1)
	return base * mult


## The heat wave only bites outside: not in mines, caves, interiors or on the moon.
static func in_the_heat() -> bool:
	var t := Engine.get_main_loop() as SceneTree
	var m: GameMap = t.current_scene as GameMap if t and t.current_scene is GameMap else null
	if m == null:
		return true
	var id := m.scene_id()
	if id in ["house", "moon", "interior", "mine"]:
		return false
	return not Ambience.is_cave(m)


## Tom (C6 P7 phone playtest): early chopping and mining went far too fast.
## C8 P1 made the curve smooth: swings = round(hp x effort), where effort is
## TOUGH_START (axe 1.8 / pickaxe 1.6) x TOUGH_TIER_MULT per tool tier x a skill
## factor (-TOUGH_LEVEL a level, floor TOUGH_LEVEL_FLOOR) / (1 + POWER_STEP x
## chop/mine power). Every tool tier now shaves swings (the old integer damage
## 1 + (tier+1)/2 made copper = iron and steel = silver) and levels matter.
## toughen() stores hp = swings x swing_damage so the callers' own subtraction
## (game_map / mine) lands on exactly that many swings.
## Tree (hp 4) wood..moon at level 1: 7,5,4,3,2,2,1,1; level 6 wood: 6.
## Stone (hp 2): 3,2,2,1...; copper ore (hp 4): 6,5,4,3,2,2,1,1.
## Table: tools/c8_curve_test.gd and tools/tom_playtest_c6_test.gd.
const TOUGH_START := {"axe": 1.8, "pickaxe": 1.6}
const TOUGH_TIER_MULT := 0.75
const TOUGH_LEVEL := 0.03
const TOUGH_LEVEL_FLOOR := 0.7
const POWER_STEP := 0.3

## Effort multiplier on a thing's hp for this tool right now.
static func toughness(tool: String) -> float:
	var sk := "mining" if tool == "pickaxe" else "foraging"
	var lvl := skill_level(sk) if run.has("skills") else 1
	var power := bonus("mining", "mine_power") if tool == "pickaxe" else bonus("foraging", "chop_power")
	var lv_f := maxf(TOUGH_LEVEL_FLOOR, 1.0 - TOUGH_LEVEL * float(mini(lvl, LEVEL_EFFECT_CAP) - 1))
	return float(TOUGH_START.get(tool, 1.6)) * pow(TOUGH_TIER_MULT, float(tool_tier(tool))) * lv_f / (1.0 + POWER_STEP * power)


## What one swing takes off (the formula game_map / mine / moon subtract).
static func swing_damage(tool: String) -> int:
	var power := bonus("mining", "mine_power") if tool == "pickaxe" else bonus("foraging", "chop_power")
	return 1 + (tool_tier(tool) + 1) / 2 + int(power)


## Called before the first blow lands (game_map / mine): toughens the thing once.
static func toughen(thing: Dictionary, tool: String, default_hp := 2) -> void:
	if thing.has("tough"):
		return
	thing["tough"] = true
	thing["hp"] = hits_for(int(thing.get("hp", default_hp)), tool) * swing_damage(tool)


## Swings it takes the tool right now to fell/break a thing of `hp`.
static func hits_for(hp: int, tool: String) -> int:
	return maxi(1, int(round(float(hp) * toughness(tool))))


## Whole-number view of energy_cost_f (menus, sims). Small actions can show 0.
static func energy_cost(task: String) -> int:
	return int(round(energy_cost_f(task)))


## Pay for one action. Works while you have any energy at all (Stardew: you can
## push yourself to 0 and pass out); returns false only on an empty bar.
static func spend_for(task: String) -> bool:
	if int(run["energy"]) <= 0:
		if Engine.get_main_loop() is SceneTree:
			Music.instance(Engine.get_main_loop() as SceneTree).sfx("nope")  # "Too tired." is heard, not just read
		return false
	var fr := float(run.get("en_frac", 0.0)) + energy_cost_f(task)
	var whole := int(floor(fr))
	run["en_frac"] = fr - whole
	if whole > 0:
		run["energy"] = maxi(0, int(run["energy"]) - whole)
		energy_warn()
	return true


static func exhausted() -> bool:
	return int(run.get("energy", 1)) < int(ceil(float(run.get("max_energy", 100)) * EXHAUSTED_FRAC))


## One warning when you cross 15% (Exhausted) and one at 5% (about to pass out).
## run["en_warn"]: 0 fine, 1 warned at 15%, 2 warned at 5%; drops back as you refill.
static func energy_warn() -> void:
	var e := int(run["energy"])
	var m := maxi(1, int(run["max_energy"]))
	var lvl := int(run.get("en_warn", 0))
	var now := 0
	if e <= int(ceil(m * 0.05)):
		now = 2
	elif e < int(ceil(m * EXHAUSTED_FRAC)):
		now = 1
	if now > lvl:
		if now == 1:
			notify("You're exhausted. Eat something, rest, or head home: at zero energy you'll pass out.")
		else:
			notify("You can barely stand. One more push and you'll pass out!")
	run["en_warn"] = now


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
	var m := Difficulty.mul("foe_dmg")
	if m != 1.0:
		n = maxi(3 if Difficulty.level() == 0 else 5, roundi(n * m))  # Very easy: floor 3
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
	var pool: Array = forage_data.get(region, forage_data.get("wild", forage_data.get("farm", [])))
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
	energy_warn()
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
	# C8 P1: anything that would change nothing is kept (a potion at full
	# health, a pup treat, food at a full bar or past the daily food cap).
	last_full_why = consume_blocked(id)
	if last_full_why != "":
		return {"full": true}  # callers keep the item on a "full"-only result
	add_item(id, -1)
	var hp0 := int(run["hp"]); var en0 := int(run["energy"]); var ma0 := int(run.get("mana", 0))
	var mh := Crew.perk_level("meal_heal")
	heal(int(round(int(it.get("heal", 0)) * (1.0 + (0.1 if mh == 1 else (0.25 if mh >= 2 else 0.0))))))
	# Cooked food refills energy from its heal (x8); raw catch, crops and forage
	# less (x5: a berry or a parsnip is a real snack early on, round 11), so eating the cheap catch isn't an endless energy loop
	# (audit 12#1). Potions heal but give no energy from it (only an explicit
	# "energy"), so a healing item isn't the cheapest energy drink.
	var ty := str(it.get("type", ""))
	var en_mult := 8 if ty in ["food", "consumable", "tonic", "gift"] else (0 if ty == "potion" else 5)
	# Food energy is capped at one full bar a day (fed_en resets on sleep), so
	# bought food can't turn the clock into the only limit on fishing.
	var en_gain := int(it.get("energy", 0)) + int(it.get("heal", 0)) * en_mult
	var room := maxi(0, int(run["max_energy"]) - int(run.get("fed_en", 0)))
	restore_energy(mini(room, en_gain))
	run["fed_en"] = int(run.get("fed_en", 0)) + int(run["energy"]) - en0
	if room <= 0 and en_gain > 0:
		out["full"] = true
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


## Why eating `id` right now would do nothing ("" = it would do something):
## "hp" (a heal-only item at full health), "topped" (energy bar already full),
## "cap" (today's food energy is used up), "pup" (pup-only food), "nothing".
static func consume_blocked(id: String) -> String:
	var it: Dictionary = items.get(id, {})
	if it.is_empty():
		return "nothing"
	if it.has("buff") or it.has("grow"):
		return ""
	var heal := int(it.get("heal", 0))
	var ty := str(it.get("type", ""))
	var en_mult := 8 if ty in ["food", "consumable", "tonic", "gift"] else (0 if ty == "potion" else 5)
	var en_gain := int(it.get("energy", 0)) + heal * en_mult
	var hp_room := heal > 0 and int(run["hp"]) < int(run["max_hp"])
	var mana_room := int(it.get("mana", 0)) > 0 and int(run.get("mana", 0)) < int(run.get("max_mana", 0))
	var bar_full := int(run["energy"]) >= int(run["max_energy"])
	var fed_full := int(run.get("fed_en", 0)) >= int(run["max_energy"])
	var en_room := en_gain > 0 and not bar_full and not fed_full
	if hp_room or mana_room or en_room:
		return ""
	if en_gain > 0:
		return "topped" if bar_full else "cap"
	if heal > 0:
		return "hp"
	if int(it.get("mana", 0)) > 0:
		return "mana"
	if it.has("pet_heal"):
		return "pup"
	return "nothing"


## Why the last consume() kept the item (see consume_blocked).
static var last_full_why := ""


## The toast for a kept item (after consume() returned {"full": true}).
static func full_text() -> String:
	match last_full_why:
		"topped": return "Your energy is already full."
		"hp": return "You're already at full health."
		"mana": return "Your mana is already full."
		"pup": return "That's for your pup (Pup tab → Give)."
		"nothing": return "That wouldn't do anything right now."
	return "You've eaten all the energy you can today. Sleep resets it."


## Active buff amount (0 when none / expired).
static func buff(kind: String) -> float:
	var b: Dictionary = run.get("buffs", {}).get(kind, {})
	if b.is_empty() or now_abs() > int(b.get("until", 0)):
		return 0.0
	return float(b.get("amount", 0))


## Minutes since the start of day 1: buffs and timers that cross midnight use this.
static func now_abs() -> int:
	return int(run.get("day", 1)) * 1440 + int(run.get("time", DAY_START))


## Co-op: switching between our own clock and a host's moves timers set on the other clock.
## dd: the real day gap (callers pass it, so time of day doesn't round into it);
## into: shift this run copy instead of the live run (save_view).
static func shift_clock(dm: int, dd_in: Variant = null, into: Variant = null) -> void:
	var r: Dictionary = run if into == null else into
	if r.is_empty():
		return
	var dd: int = int(round(dm / 1440.0)) if dd_in == null else int(dd_in)
	if dm == 0 and dd == 0:
		return
	var jb: Dictionary = r.get("jobs", {})
	for key in jb:
		var js: Variant = jb[key]
		for j: Variant in (js if js is Array else [js]):
			if j is Dictionary and (j as Dictionary).has("done_at"):
				j["done_at"] = int(j["done_at"]) + dm
	var fl: Dictionary = r.get("flags", {})
	if int(fl.get("haste_abs", -1)) > 0:
		fl["haste_abs"] = int(fl["haste_abs"]) + dm
	if fl.has("drone_ready"):
		fl["drone_ready"] = int(fl["drone_ready"]) + dd
	var bf: Dictionary = r.get("buffs", {})
	for k in bf:
		if bf[k] is Dictionary:
			bf[k]["until"] = int(bf[k].get("until", 0)) + dm
	var pt: Dictionary = r.get("pet", {})
	if pt.has("rest_until_abs"):
		pt["rest_until_abs"] = int(pt["rest_until_abs"]) + dm
	if pt.has("rest_until"):
		pt["rest_until"] = int(pt["rest_until"]) + dd
	var cl: Dictionary = r.get("crew_last", {})
	for id in cl:
		cl[id] = int(cl[id]) + dd
	# Day stamps in flags (forage/bush/fruit/loot/heal spots, once-a-day uses) move with the day.
	if dd != 0:
		var rx := RegEx.create_from_string("^(forage_|fg_|bush_|fruit_|shroom_|loot_|heal_|heist_try_|marked_try_|bfpay_)|_day$|^(forest_thicket|crater_flower)$")
		for k in fl.keys():
			var fv: Variant = fl[k]
			if (fv is int or fv is float) and int(fv) > 0 and rx.search(str(k)) != null:
				fl[k] = int(fv) + dd
		for k in ["petted_day", "bedroll_day", "rescued_day"]:
			if int(pt.get(k, 0)) > 0:
				pt[k] = int(pt[k]) + dd
		var pd: Variant = r.get("passed_day", null)
		if pd is Dictionary and (pd as Dictionary).has("day"):
			pd["day"] = int(pd["day"]) + dd
		# Board jobs carry their pin day in the id (the host's day if pinned while visiting): keep it on the quest.
		for q: Variant in r.get("quests", []):
			if q is Dictionary and not bool(q.get("done", false)) and str(q.get("id", "")).begins_with("board_") and str(q["id"]).get_slice("_", 1).is_valid_int():
				q["pin_day"] = int(q.get("pin_day", int(str(q["id"]).get_slice("_", 1)))) + dd


static func restore_energy(n: int) -> void:
	run["energy"] = mini(int(run["energy"]) + n, int(run["max_energy"]))
	if n > 0:
		energy_warn()  # refilling re-arms the warnings


## Energy from food, rest spots and perk meals: together at most one full bar a day
## (fed_en resets on sleep). Returns what was actually gained.
static func extra_energy(n: int) -> int:
	var room := maxi(0, int(run["max_energy"]) - int(run.get("fed_en", 0)))
	var en0 := int(run["energy"])
	restore_energy(mini(room, n))
	var got := int(run["energy"]) - en0
	run["fed_en"] = int(run.get("fed_en", 0)) + got
	return got


## Rest spots (well, spring, inn, chapel...): their own half bar a day (rest_en,
## reset each morning), apart from food and perk meals. Returns what was gained.
static func rest_energy(n: int) -> int:
	var room := maxi(0, int(run["max_energy"]) / 2 - int(run.get("rest_en", 0)))
	var en0 := int(run["energy"])
	restore_energy(mini(room, n))
	var got := int(run["energy"]) - en0
	run["rest_en"] = int(run.get("rest_en", 0)) + got
	return got


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
const NO_GIFT_TYPES := ["tool", "seed", "key", "equip", "petgear", "placeable", "outfit", "vehicle", "decor", "romance"]


static func can_gift(npc: String, item: String) -> bool:
	if item == "" or count(item) <= 0 or not items.has(item):
		return false
	if str(items[item].get("type", "")) in NO_GIFT_TYPES:
		return false
	if (run.get("gifted_today", {}) as Dictionary).has(npc):
		return false
	# Two gifts a week each, like Stardew; birthdays always count.
	return is_birthday(npc) or int((run.get("gifts_week", {}) as Dictionary).get(npc, 0)) < 2


## Give a gift: takes the item, adds friendship, remembers today. Returns the gain.
# ---- produce families ----------------------------------------------------------
## Every crop (and what it yields) belongs to a family: veg, herb, berry, fruit,
## tree, grain, mushroom, flower, magic. Recipes can ask for "#veg", villagers
## can like "#berry", the keg brews by family, the fair and journal count them.
const FAMILY_NAMES := {"veg": "Vegetable", "herb": "Herb", "berry": "Berry", "fruit": "Fruit", "tree": "Orchard Fruit", "grain": "Grain", "mushroom": "Mushroom", "flower": "Flower", "magic": "Wonder Crop"}

static func family(id: String) -> String:
	var it: Dictionary = items.get(id, {})
	var f := str(it.get("family", ""))
	if f != "":
		return f
	# Plain forage counts toward its kind: wild herbs are herbs, berries berries.
	var basic: String = {"wild_herb": "herb", "berry": "berry", "flower": "flower"}.get(id, "")
	if basic != "":
		return basic
	var ty := str(it.get("type", ""))
	return ty if ty in ["herb", "flower", "fruit"] else ""


static func family_name(f: String) -> String:
	return str(FAMILY_NAMES.get(f.trim_prefix("#"), f.capitalize()))


## How many you carry of an item, or of a whole family ("#veg").
static func count_any(key: String) -> int:
	if not key.begins_with("#"):
		return count(key)
	var f := key.substr(1)
	var n := 0
	for id in run["inventory"]:
		if (family(str(id)) == f or (f == "fruit" and family(str(id)) in ["tree", "berry"])) and not is_locked(str(id)):
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
		if (family(str(id)) == f or (f == "fruit" and family(str(id)) in ["tree", "berry"])) and not is_locked(str(id)):
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
		if (cs == se or cs == "any") and int(cd.get("tier", 1)) <= max_tier and (is_penguins() or not str(it["crop"]).begins_with("crystal")):
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
	gs[item] = gain / (3 if is_birthday(npc) else 1)
	if int(gs[item]) > 0:
		gs[item] = maxi(1, int(gs[item]) - int(bonus("bartering", "gift_bonus")) - int(items.get(item, {}).get("friend", 0)))  # what they think of the gift itself
	run["gift_seen"][npc] = gs
	var gw: Dictionary = run.get("gifts_week", {})
	gw[npc] = int(gw.get(npc, 0)) + 1
	run["gifts_week"] = gw
	var hearts_before := friend_hearts(npc)
	add_friend(npc, gain)
	var g: Dictionary = run.get("gifted_today", {})
	g[npc] = true
	run["gifted_today"] = g
	# Every gift gets a sound wherever it is given (not just in town); a new heart gets the jingle.
	if Engine.get_main_loop() is SceneTree:
		Music.instance(Engine.get_main_loop() as SceneTree).sfx("j_heart" if friend_hearts(npc) > hearts_before else ("j_gift" if gain >= 12 else ("pickup" if gain > 0 else "nope")), "pickup")
	return gain


static func add_friend(npc: String, n: int) -> void:
	var fr: Dictionary = run["friendship"]
	if n > 0:
		n = int(round(n * (1.0 + bonus("leadership", "friend_gain"))))
		if npc in Companion.party().get("known", []) or Crew.recruited(npc):
			add_xp("leadership", 3)
	var before_h := int(fr.get(npc, 0)) / 25
	fr[npc] = clampi(int(fr.get(npc, 0)) + n, 0, 250)
	if n > 0:
		Perks._fc = {}
		for line in Perks.check(npc):
			notify(str(line))
		if int(fr[npc]) / 25 > before_h:
			_apply_max_stats()
			if Engine.get_main_loop() is SceneTree:
				Music.instance(Engine.get_main_loop() as SceneTree).sfx("j_heart", "levelup")  # a new heart, from any source
			# Hand-coded heart perks (not in heart_perks.json) announce here, every level passed.
			for h in range(before_h + 1, int(fr[npc]) / 25 + 1):
				var pk := friend_perk_at(npc, h)
				if pk != "" and not (Perks.data().get(npc, {}) as Dictionary).has(str(h)):
					notify("%s ♥%d: %s" % [str(npcs.get(npc, {}).get("name", npc.capitalize())), h, pk])
	# Bram's soup: the first chat with him each day tops you up.
	if npc == "bram" and n > 0 and Perks.flag("soup") and int(run["flags"].get("soup_day", -1)) != int(run["day"]) and int(run["energy"]) < int(run["max_energy"]):  # full bar: keep today's bowl for later
		run["flags"]["soup_day"] = int(run["day"])
		var got := extra_energy(30)
		notify("Bram slides you a bowl of soup. +%d energy." % got if got > 0 else "Bram slides you a bowl of soup. You're too full for more energy today.")


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
	if str(it.get("loved_by", "-")) in likes:
		base = 20  # loved: e.g. Prize Candy for anyone who likes candy (gen_rec ITEMS "loved_by")
	elif item in likes or (kind != "" and kind in likes) or fam in likes:
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
## A villager's own reaction to a gift (data/gift_lines.json), "" if none.
static func gift_line(id: String, item: String, gain: int) -> String:
	var d := load_json("res://data/gift_lines.json") if _gift_lines.is_empty() else _gift_lines
	_gift_lines = d
	var n := item_name(item)
	if is_birthday(id) and gain > 0 and d.get("birthday", {}).has(id):
		return ItemWords.fill(str(d["birthday"][id]), n)
	var ls: Array = d.get("lines", {}).get(id, [])
	if ls.size() < 4:
		return ""
	var mult := 3 if is_birthday(id) else 1
	var g := gain / mult
	if g > 0:
		g = maxi(0, g - int(bonus("bartering", "gift_bonus")) - int(items.get(item, {}).get("friend", 0)))  # react to the gift itself, not the bonuses
	var idx := 3 if g < 0 else (0 if g >= 20 else (1 if g >= 12 else 2))
	return ItemWords.fill(str(ls[idx]), n)


static var _gift_lines := {}


## Mass nouns and plural-looking names that take "some", never "a".
const SOME_WORDS := ["wood", "stone", "hay", "fiber", "fibre", "milk", "honey", "flour", "coal", "sand", "clay", "rice", "wheat", "wool", "bait", "slime", "goo", "tea", "coffee", "sugar", "salt", "oil", "cash", "glass"]


## "an Apple" / "a Carrot" / "some Turnip Seeds" (cap = capital first letter). C7.
static func with_article(name: String, cap := false) -> String:
	var low := name.to_lower()
	var last := low.split(" ")[-1] if low != "" else ""
	var art := "a"
	if (last.ends_with("s") and not last.ends_with("ss")) or SOME_WORDS.has(last):
		art = "some"
	elif low != "" and "aeiou".contains(low.left(1)):
		art = "an"
	return (art.capitalize() if cap else art) + " " + name


## A reaction line with the right article before the item's name ("A Apple" -> "An Apple").
static func articled(text: String, name: String) -> String:
	if name == "":
		return text
	return text.replace("A " + name, with_article(name, true)).replace(" a " + name, " " + with_article(name))


## "4 Turnips", "1 Turnip", "3 Berries"; names already plural or mass nouns stay. C7.
static func plural_name(id: String, n: int) -> String:
	var nm := item_name(id)
	if n == 1 or nm == "":
		return nm
	var last := nm.to_lower().split(" ")[-1]
	if last.ends_with("s") or SOME_WORDS.has(last):
		return nm
	if last.ends_with("y") and not "aeiou".contains(last.substr(last.length() - 2, 1)):
		return nm.left(nm.length() - 1) + "ies"
	if last.ends_with("sh") or last.ends_with("ch") or last.ends_with("x"):
		return nm + "es"
	return nm + "s"


static func birthday_today() -> String:
	for id: String in npcs:
		# Only people you can give gifts to (Catkins has no heart arc) who are still around.
		if is_birthday(id) and npc_present(id):
			return id
	return ""


## A villager who is in the valley today: not sent away by the story
## (posy_gone, lumi_gone...), not Catkins (no heart arc), and Sal only from
## day 4 in the penguin arc (as in town.gd).
static func npc_present(id: String) -> bool:
	if run.is_empty():
		return false
	return not run["flags"].has(id + "_gone") and id != "catkins" and not (id == "sal" and is_penguins() and int(run["day"]) < 4)


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
				Music.instance(m.get_tree()).sfx("quest_done", "levelup")
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
	"rook": ["pelt", "bone", "meat", "leather", "fine_leather"], "theo": ["old_coin", "book", "fossil"], "lumi": ["flower", "sunflower", "seashell", "cloth", "linen", "fine_fabric"],
	"alder": ["stone", "wood", "brick", "pumpkin", "tile"], "sal": ["coffee", "bread", "minnow"], "benno": ["hay", "carrot", "apple"], "ivy": ["old_coin", "honey", "cake"],
}


## False for a crop's harvest that can't be grown this season (no strawberry orders in winter).
static func crop_in_season(item: String) -> bool:
	var found := false  # strain variants share a yield: any one in season counts
	for cid: String in crops:
		if str(crops[cid].get("yield", "")) == item:
			if str(crops[cid].get("season", "any")) in ["any", season()]:
				return true
			found = true
	return not found


## Board items any shop sells at 1.5x value: no markup on them, or buy-and-hand-in is free money.
const BOARD_SHOP_GOODS := ["coal", "copper", "iron", "stone", "brick", "old_coin", "book", "meat", "bait", "flour", "hay", "bread", "coffee"]


static func board_today() -> Array:
	var b: Dictionary = run.get("board", {})
	if int(b.get("day", -1)) == int(run["day"]):
		return b["jobs"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run["day"]) * 7919 + 13
	var npcs_ok: Array = []
	for id in BOARD_POOL:
		if npcs.has(id) and npc_present(str(id)):
			npcs_ok.append(id)
	var jobs: Array = []
	var used := {}
	var tier := progress_tier()
	for i in (3 if not npcs_ok.is_empty() else 0):
		var who: String = npcs_ok[rng.randi_range(0, npcs_ok.size() - 1)]
		if used.has(who):
			continue
		used[who] = true
		var pool: Array = BOARD_POOL[who]
		var item: String = pool[rng.randi_range(0, mini(pool.size(), 2 + tier) - 1)]
		if not items.has(item) or not crop_in_season(item):
			continue
		if (item == "egg" and not Builds.is_built("coop")) or (item in ["milk", "butter"] and not Builds.is_built("barn")):
			continue  # nothing to get it from yet
		var n := rng.randi_range(2, 4 + tier * 2)
		var val := maxi(2, item_value(item))
		var pay := int(val * n * (1.15 if item in BOARD_SHOP_GOODS else 1.6)) + 20 * tier  # shop goods: pay for the errand, not a markup
		pay = maxi(pay, 12 + 4 * n)  # a walk across town is worth more than 3 stones' price
		jobs.append({"id": "board_%d_%d" % [int(run["day"]), i], "npc": who, "item": item, "n": n, "crystals": pay, "friend": 8 + tier * 2})
	# Plus one order for something growing this season (any farmer's crop counts).
	var se := season()
	var crop_pool: Array = []
	var growable := Shops.growable_now()  # only crops you can get seeds for (or already grow)
	for cid in crops:
		var cd: Dictionary = crops[cid]
		if growable.has(str(cid)) and str(cd.get("season", "any")) in [se, "any"] and int(cd.get("tier", 1)) <= tier + 1 and items.has(str(cd["yield"])) \
				and not bool(cd.get("tree", false)) and (is_penguins() or not str(cid).begins_with("crystal")) \
				and int(cd.get("days", 4)) <= 12 and (str(cd.get("season", "any")) == "any" or int(cd.get("days", 4)) <= DAYS_PER_SEASON - day_of_season()):
			crop_pool.append(str(cd["yield"]))
	crop_pool.sort()
	if not crop_pool.is_empty():
		var who2: String = ["posy", "maple", "hazel", "wren", "lumi", "theo"][rng.randi_range(0, 5)]
		if npcs.has(who2) and npc_present(who2) and not used.has(who2):
			var item2: String = crop_pool[rng.randi_range(0, crop_pool.size() - 1)]
			var n2 := rng.randi_range(2, 3 + tier)
			jobs.append({"id": "board_%d_c" % int(run["day"]), "npc": who2, "item": item2, "n": n2, "crystals": int(maxi(2, item_value(item2)) * n2 * 1.8) + 15 * tier, "friend": 10 + tier * 2})
	run["board"] = {"day": int(run["day"]), "jobs": jobs}
	return jobs


## Accept a board job: it becomes a side quest in that villager's name.
static func board_accept(job: Dictionary) -> void:
	var id := str(job["id"])
	if has_quest(id):
		return
	var who := str(job["npc"])
	var text := "%s needs %s (board job)." % [str(npcs[who]["name"]), ItemWords.count_id(str(job["item"]), int(job["n"]))]
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
	var wait := maxi(maxi(1, int((respawn_days + 1) / 2.0)), respawn_days - int(bonus("foraging", "regrowth")))  # Honey Sense at most halves a wait
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
	if when.has("pup_gear") and count(str(when["pup_gear"])) < 1 and not ((run.get("pet", {}) as Dictionary).get("gear", {}) as Dictionary).values().has(str(when["pup_gear"])):
		return false  # in the bag or worn by the pup both count
	if when.has("kills"):
		var kl: Array = when["kills"]
		if int(run.get("kill_counts", {}).get(str(kl[0]), 0)) < int(kl[1]):
			return false
	if when.has("companion") and Companion.active_id() != str(when["companion"]):
		return false
	if when.has("known") and not (Companion.party().get("known", []) as Array).has(str(when["known"])) and str(when["known"]) != str(run.get("playable", "")):
		return false
	if when.has("mine_floor") and int(run["flags"].get("mine_deepest", 1)) < int(when["mine_floor"]):
		return false
	if when.has("crystals") and int(run.get("crystals", 0)) < int(when["crystals"]):
		return false
	if when.has("crew_any"):
		var nc := 0
		for cid in Crew.members():
			if Crew.recruited(str(cid)):
				nc += 1
		if nc < int(when["crew_any"]):
			return false
	if when.has("hp_below") and float(run.get("hp", 0)) >= float(when["hp_below"]) * float(run.get("max_hp", 100)):
		return false
	if when.has("hearts_total"):
		var tot := 0
		for k in run["friendship"]:
			tot += friend_hearts(str(k))
		if tot < int(when["hearts_total"]):
			return false
	if when.has("chapter") and Story.chapter_no() < int(when["chapter"]):
		return false
	if (when.has("arcade_ms") or when.has("rec_best") or when.has("tickets_won")) and not Tickets.cond_ok(when):
		return false  # Rec Center / arcade progress
	if (when.has("heat_min") or when.has("heat_max") or when.has("loyalty") or when.has("clean_break")) and not Epilogue.cond_ok(when):
		return false  # gangster arc: heat, crew loyalty, the Clean Break path (C7 P3)
	return true


## Money in (C3 c3_08 #9): every payout counts in earned_total ("earned in
## all" on the Hero tab), with a tally per source in run.earned_by (sales,
## quest, campaign, kills, ...). Spending stays a plain subtraction.
static func add_money(n: int, source := "other") -> void:
	if run.is_empty() or n == 0:
		return
	run["crystals"] = int(run.get("crystals", 0)) + n
	if n > 0:
		run["earned_total"] = int(run.get("earned_total", 0)) + n
		if not (run.get("earned_by") is Dictionary):
			run["earned_by"] = {}
		run["earned_by"][source] = int(run["earned_by"].get(source, 0)) + n


## Count money earned that lands somewhere other than the purse (bank interest).
static func _count_earned(n: int, source: String) -> void:
	if n <= 0:
		return
	run["earned_total"] = int(run.get("earned_total", 0)) + n
	if not (run.get("earned_by") is Dictionary):
		run["earned_by"] = {}
	run["earned_by"][source] = int(run["earned_by"].get(source, 0)) + n


static func _give_reward(rw: Dictionary) -> void:
	if rw.has("crystals"):
		add_money(int(rw["crystals"]), "quest")
	for k in ["max_hp", "max_energy", "max_mana"]:
		if rw.has(k):
			grow_vital(k.trim_prefix("max_"), int(rw[k]))
	if rw.has("flag"):
		run["flags"][str(rw["flag"])] = true
	if rw.has("item"):
		if str(items.get(str(rw["item"][0]), {}).get("type", "")) == "tool":
			add_tool(str(rw["item"][0]))  # weapons/tools go to the tool list, so they can be held
		else:
			add_item(str(rw["item"][0]), int(rw["item"][1]))
	if rw.has("xp"):
		add_xp(str(rw["xp"][0]), int(rw["xp"][1]))
	if rw.has("tickets"):
		Tickets.add(int(rw["tickets"]), "quest")
	if rw.has("friend"):
		var fr: Dictionary = run["friendship"]
		add_friend(str(rw["friend"][0]), int(rw["friend"][1]))


## Main-story quests appear as the game progresses; side quests come from the
## person who gives them (see town talk). Returns ids of quests just completed.
## Main steps tick_quests opened right after a hand-in (GameMap._check_quests toasts and clears them).
static var opened: Array = []


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
	if not done.is_empty():
		# The next main step opens now, not on the next map load.
		for q in quests_data.get("main", []):
			if str(q.get("arc", "both")) in ["both", str(run["arc"])] and not has_quest(str(q["id"])) and _cond_ok(q.get("when", {})):
				add_quest(str(q["id"]), str(q["text"]))
				opened.append(str(q["text"]))
	return done


## A side quest this NPC can offer right now (not yet taken, conditions met).
static func side_quest_for(npc: String) -> Dictionary:
	for q in quests_data.get("side", []):
		if str(q.get("giver", "")) != npc or has_quest(str(q["id"])):
			continue
		if str(q.get("arc", "both")) not in ["both", str(run["arc"])]:
			continue
		if (q.get("when", {}) as Dictionary).has("season") and day_of_season() > 18 and _quest_grows(q):
			continue  # too late in the season to grow it: asked again next year
		if _cond_ok(q.get("when", {})):
			return q
	return {}


## True when a quest asks for a crop's harvest (it has to be grown in time).
static func _quest_grows(q: Dictionary) -> bool:
	var dw: Variant = q.get("done_when", {})
	if not (dw is Dictionary):
		return false
	var want: Array = []
	if (dw as Dictionary).has("item"):
		want.append(str(dw["item"][0]))
	for pair in (dw as Dictionary).get("items", []):
		want.append(str(pair[0]))
	for cid in crops:
		if str(crops[cid].get("yield", "")) in want:
			return true
	return false


static func side_quest_pending(npc: String) -> Dictionary:
	# A quest that is ready to turn in comes first, then the oldest open one.
	var first := {}
	for q in run["quests"]:
		if q["done"]:
			continue
		var d := _quest_def(str(q["id"]))
		if str(d.get("giver", "")) != npc:
			continue
		if d.has("done_when") and d["done_when"] is Dictionary and _cond_ok(d["done_when"]):
			return d
		if first.is_empty() and not bool(d.get("board", false)) and str((d.get("when", {}) as Dictionary).get("season", season())) == season():
			first = d  # an unfinished board job doesn't stop the villager offering their own quests (it is still turned in via _ready_quest)
	return first


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


## Day of the year, 1..112. Summer's midpoint is day 42.
static func doy() -> int:
	return (int(run.get("day", 1)) - 1) % (DAYS_PER_SEASON * 4) + 1


## Minutes after midnight. Sunset drifts a little every day: about 4:30pm in
## midwinter, 8pm in midsummer. Full dark comes two hours after it starts.
static func sunset() -> int:
	return int(1095 + 105 * cos(TAU * (doy() - 42) / 112.0))


static func full_dark() -> int:
	return sunset() + 120


static func sunrise() -> int:
	return int(405 - 45 * cos(TAU * (doy() - 42) / 112.0))


## 0 = full daylight, 1 = deep night. Uses the clock and the season.
static func darkness(t := -1) -> float:
	if t < 0:
		t = int(run.get("time", DAY_START))
	var ss := sunset()
	if t >= ss:
		return smoothstep(float(ss), float(ss + 120), float(t))
	# Mornings are dawn, not night: at most DAWN_DARK before the sun is up, gone at
	# sunrise (the warm light after it is morning_glow, drawn by GameMap.sky_tint).
	var sr := sunrise()
	return DAWN_DARK * (1.0 - smoothstep(float(sr - 90), float(sr), float(t)))


const DAWN_DARK := 0.42


## 0..1 warmth of the early light: full from first light through sunrise, fading
## to plain daylight by mid-morning (2.5 h after sunrise; follows the season).
static func morning_glow(t := -1) -> float:
	if t < 0:
		t = int(run.get("time", DAY_START))
	var sr := sunrise()
	if t >= sunset() or t < sr - 120:
		return 0.0
	return 1.0 - smoothstep(float(sr), float(sr + 150), float(t))


static func is_night() -> bool:
	return darkness() > 0.5


static func clock_of(m: int) -> String:
	var h := (m / 60) % 24
	return "%d:%02d%s" % [(h + 11) % 12 + 1, m % 60, "am" if h < 12 else "pm"]


static func day_of_season() -> int:
	return (int(run.get("day", 1)) - 1) % DAYS_PER_SEASON + 1


## A map can look like another season (the ice island is always winter).
static var look_season := ""


static func look_se() -> String:
	return look_season if look_season != "" else season()


static func grass_tile() -> String:
	match look_se():
		"summer": return "grass_summer"
		"fall": return "grass_fall"
		"winter": return "grass_winter"
	return "grass"


## Tree/bush sprite names per season (variant 0..2).
static func tree_sprite(v: int) -> String:
	match look_se():
		"summer": return ["apple_tree", "pine", "orange_tree"][v % 3] if Art.has("nature", "apple_tree") else ["oak", "pine", "oak"][v % 3]
		"fall": return ["tree_red", "tree_orange", "tree_birch"][v % 3] if Art.has("nature", "tree_red") else ["oak_autumn", "pine", "oak_autumn"][v % 3]
		"winter": return ["tree_bare", "pine_snow", "tree_bare_s"][v % 3] if Art.has("nature", "tree_bare") else ["oak", "pine", "oak"][v % 3]
	return ["oak", "pine", "oak"][v % 3]


static func bush_sprite(berries: bool) -> String:
	match look_se():
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
	if day == 1 and not is_penguins() and pick in ["clear", "fog", "wind", "petals"]:
		pick = "rain"  # the gangster opening is a rainy night, and the rain is real (it waters the first crop)
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


## Rain, storms and snow water the crops (snow overnight, like sleep() does).
static func sky_waters() -> bool:
	return is_wet() or weather_today() in ["snow", "blizzard"]


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
## Bartering XP from one night's box (was 20 + 5 x level: it fed itself).
const BARTER_XP_NIGHT := 60
## Up late: bedtime past midnight wakes you on LATE_WAKE_MIN of the bar at 2am.
const LATE_WAKE_MIN := 0.85

static func late_wake_mult(bedtime: int) -> float:
	if bedtime <= 1440:
		return 1.0
	return lerpf(1.0, LATE_WAKE_MIN, clampf(float(bedtime - 1440) / 120.0, 0.0, 1.0))


## Ivy's bank: 1% a night (2% at Ivy 6), only from Ivy 2 hearts, capped.
## interior._bank can word the real rate from these (C8 P1).
static func bank_rate() -> float:
	if not has_friend_perk("ivy", 2):
		return 0.0
	return 0.02 if has_friend_perk("ivy", 6) else 0.01


static func bank_interest_cap() -> int:
	return 40 + 40 * progress_tier()


static func bank_interest() -> int:
	var bal := int(run.get("bank", 0))
	if bal <= 0:
		return 0
	return mini(int(round(bal * bank_rate())), bank_interest_cap())


static func sleep(passed_out := false) -> Dictionary:
	passed_out = passed_out or int(run["flags"].get("fainted_day", -1)) == int(run["day"])  # Faint: came round at 10pm
	status_clear()
	_apply_max_stats()
	var bedtime := int(run.get("time", DAY_START))
	var report := {"earned": 0, "sold": [], "grown": 0}
	if bonus("bartering", "interest") > 0.0:
		add_money(mini(int(int(run["crystals"]) * bonus("bartering", "interest")), 50 + 50 * progress_tier()), "interest")
	var total := 0
	# sold_today still holds the day's sales to Sal's fence, so the box saturates on top of them.
	if not (run.get("sold_today") is Dictionary):
		run["sold_today"] = {}
	# C8 P1: price the star bonus on the same pieces the box preview did (before
	# the box itself saturates sold_today), so the morning matches the promise.
	var qb := quality_bonus_value(run.get("sellbox_q", {}))
	for id in run["sellbox"].keys():
		var n: int = int(run["sellbox"][id])
		var v := sell_price(id, n)
		run["sold_today"][id] = int(run["sold_today"].get(id, 0)) + n
		total += v
		report["sold"].append("%s x%d = %d" % [item_name(id), n, v])
	if qb > 0:
		total += qb
		report["sold"].append("quality bonus = %d" % qb)
	# Lucky Day (Bartering): now and then the whole box pays double (extra capped by progress).
	if total > 0 and randf() < bonus("bartering", "jackpot"):
		var lucky := mini(total, 300 + 300 * progress_tier())
		total += lucky
		report["sold"].append("Lucky Day! +%d" % lucky)
	run["sellbox_q"] = {}
	if total > 0:
		add_xp("bartering", mini(total / 15, BARTER_XP_NIGHT))  # flat cap (C8 P1: grew with level, a feedback loop)
	run["sold_today"] = {}
	add_money(total, "sales")
	report["earned"] = total
	run["sellbox"] = {}
	# Hazel helps on the farm once you're friends (every other day at 4 hearts, daily at 6).
	var hazel_waters := has_friend_perk("hazel", 6) or (has_friend_perk("hazel", 4) and int(run["day"]) % 2 == 0)
	hazel_waters = Romance.overnight(report) or hazel_waters  # the spouse's chore (water: every planted tile)
	_sprinklers_water()
	Project.overnight(report)
	Commons.overnight(report)
	for key in run["farm"].keys():
		var tile: Dictionary = run["farm"][key]
		var crop_id := str(tile.get("crop", ""))
		if crop_id != "" and not crops.has(crop_id):
			tile["crop"] = ""  # a seed whose crop isn't defined: nothing to grow
			crop_id = ""
		if crop_id != "":
			var cd: Dictionary = crops[crop_id]
			var se := season()
			var next_se := season_of(int(run["day"]) + 1)
			var fits := crop_fits_season(cd, se)
			var glass := in_greenhouse(str(key))
			# A crop that can't take the coming season dies when it arrives, and
			# winter kills anything that isn't a winter crop, unless it's under glass.
			var is_tree := bool(cd.get("tree", false))
			var dies := (next_se != se and not crop_fits_season(cd, next_se)) or (se == "winter" and not fits)
			if dies and not glass and not is_tree:
				tile["dead"] = str(cd.get("art", crop_id))  # a withered plant stays on the bed until cleared (C5)
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
			if tile.get("watered", false) or sky_waters() or hazel_waters:
				# Growth: in its season a crop grows a full day; out of season half
				# a day (it struggles). Fertiliser and the farming tree speed it.
				var rate := 1.0
				if Project.has("prism_array"):
					rate += 0.25
				if not fits and not glass:
					rate = 0.5
					if bool(cd.get("tree", false)):
						rate = 0.0  # orchard trees rest out of season; they don't die
						report["dormant"] = int(report.get("dormant", 0)) + 1
				if rate > 0.0: rate += bonus("farming", "growth")
				if rate > 0.0 and bool(tile.get("fert", false)):
					rate += 0.5
				tile["acc"] = float(tile.get("acc", 0.0)) + rate
				while float(tile["acc"]) >= 1.0:
					tile["acc"] = float(tile["acc"]) - 1.0
					tile["days"] = int(tile.get("days", 0)) + 1
				if rate > 0.0 and randf() < bonus("farming", "extra_day"):
					tile["days"] = int(tile.get("days", 0)) + 1
				if rate > 0.0: report["grown"] += 1
			else:
				report["dry"] = int(report.get("dry", 0)) + 1  # planted but never watered: no growth tonight
			tile["watered"] = false
		else:
			tile["watered"] = false
	_crows(report)
	for k3 in run["farm"].keys():
		var t3: Dictionary = run["farm"][k3]
		if str(t3.get("crop", "")) != "" and crops.has(str(t3["crop"])) and int(t3.get("days", 0)) >= int(crops[str(t3["crop"])]["days"]):
			report["ripe"] = int(report.get("ripe", 0)) + 1
	# Sprinklers and Hazel water again so the morning starts with wet soil.
	_sprinklers_water()
	if hazel_waters:
		for k2 in run["farm"].keys():
			if str(run["farm"][k2].get("crop", "")) != "":
				run["farm"][k2]["watered"] = true
	for nm in Builds.tick_overnight():
		report["built"] = report.get("built", []) + [nm]
	Racket.overnight(report)
	Sanctuary.overnight(report)
	if Crew.perk_level("fence") >= 3 and int(run["day"]) % 7 == 6:
		var relic: String = ["relic_orb", "relic_mask", "relic_blade", "relic_crown"][randi() % 4]
		add_item(relic, 1)
		report["relic"] = relic
	if has_friend_perk("posy", 2) and not run["flags"].has("posy_gone"):
		add_item("bread", 1)
	var bi := bank_interest()
	if bi > 0:
		run["bank"] = int(run["bank"]) + bi
		_count_earned(bi, "bank")
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
	# Passing out costs a quarter of tomorrow's bar (Stardew-style), not half.
	run["energy"] = int(run["max_energy"]) if not passed_out or has_friend_perk("juniper", 8) else int(run["max_energy"]) * 3 / 4
	# C8 P1: bed after midnight wakes you a little tired (up to -15% at 2am).
	var late := late_wake_mult(bedtime) if not passed_out else 1.0
	if late < 1.0:
		run["energy"] = int(round(int(run["max_energy"]) * late))
		report["late"] = true
	report["short"] = int(run["energy"]) < int(run["max_energy"])  # SleepReport says why
	run["en_frac"] = 0.0
	run["en_warn"] = 0
	run["fed_en"] = 0
	run["rest_en"] = 0
	run["kills_today"] = {}  # per-map paid kills (game_map: re-entry respawns don't pay forever)
	run["hp"] = int(run["max_hp"])
	run["mana"] = int(run.get("max_mana", 20))
	run["talked_today"] = {}
	run["gifted_today"] = {}
	(run.get("pet", {}) as Dictionary).erase("down_until")  # a night's rest gets the pup up
	if int(run["day"]) % 7 == 1:
		run["gifts_week"] = {}
	_drop_gone_quests(true)
	for line in Perks.morning():
		notify(str(line))
	# Traps in the bag catch something overnight (Rook's design): up to 3 work.
	var caught := 0
	for i in mini(count("trap"), 3):
		if randf() < 0.4:
			caught += 1
	if caught > 0:
		add_item("pelt", caught)
		notify("Your traps caught something overnight: +%d Pelt." % caught)
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
	t += minf(2.0, skill_level("combat") * 0.25)  # C8 P1: levels alone can't make you top tier
	t += gear_stat("defense") * 0.4
	t += minf(1.0, skill_level("magic") * 0.15)
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
	if bonus("combat", "status_guard") > 0 and name in ["poison", "burn"]:
		return
	if buff("warm") > 0.0 and name in ["chill", "freeze", "cold"]:
		return
	if run.get("flags", {}).has("colony_frost_step") and name in ["chill", "freeze", "cold", "slow"]:
		return
	var secs := float(tier(t).get("status_secs", 3.0)) * (0.7 if gear_stat("defense") >= 3 else 1.0) * (0.5 if Crew.perk_level("status_half") >= 2 else 1.0)
	run["status"] = run.get("status", {})
	var cur: Dictionary = run["status"].get(name, {})
	var dm := Difficulty.mul("status")  # C4 difficulty: length and power together
	secs *= dm
	run["status"][name] = {"secs": maxf(float(cur.get("secs", 0.0)), secs), "power": float(tier(t).get("status_power", 1.0)) * dm, "tier": t}


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
## Anything you grew counts: vegetables, fruit, herbs, flowers.
static func is_grown(id: String) -> bool:
	if str(items.get(id, {}).get("type", "")) == "crop":
		return true
	if _grown_cache.is_empty():
		for cid in crops:
			_grown_cache[str(crops[cid].get("yield", cid))] = true
	return _grown_cache.has(id)


static var _grown_cache := {}


static func crop_count() -> int:
	var n := 0
	for id in run["inventory"]:
		if is_grown(str(id)):
			n += int(run["inventory"][id])
	return n


## Remove n crops of any kind (most plentiful first).
static func take_crops(n: int) -> void:
	var ids: Array = []
	for id in run["inventory"]:
		if is_grown(str(id)):
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
## Crows: a big field with no scarecrow near loses a crop or two overnight.
static func _crows(report: Dictionary) -> void:
	if weather_today() in ["rain", "storm", "snow", "blizzard"]:
		return
	var planted: Array = []
	for k in run["farm"].keys():
		var t: Dictionary = run["farm"][k]
		if str(t.get("crop", "")) != "" and not bool(crops.get(str(t["crop"]), {}).get("tree", false)) and not in_greenhouse(str(k)):
			planted.append(str(k))
	if planted.size() < 16:
		return
	var guards: Array = []
	for pk in run.get("placed", {}):
		if str(run["placed"][pk]) == "scarecrow":
			var xy := str(pk).split(",")
			guards.append(Vector2i(int(xy[0]), int(xy[1])))
	if Builds.is_built("scarecrow"):
		var sc: Array = Builds.data().get("scarecrow", {}).get("cell", [24, 14])
		guards.append(Vector2i(int(sc[0]), int(sc[1])))
	var open_: Array = []
	for k: String in planted:
		var xy := k.split(",")
		var c := Vector2i(int(xy[0]), int(xy[1]))
		var safe := false
		for g: Vector2i in guards:
			if c.distance_to(g) <= 8.0:
				safe = true
				break
		if not safe:
			open_.append(k)
	if open_.is_empty():
		return
	var n := mini(open_.size(), 1 + (randi() % 2))
	open_.shuffle()
	for i in n:
		var t: Dictionary = run["farm"][open_[i]]
		t["crop"] = ""
		t["days"] = 0
		t["acc"] = 0.0
	report["crows"] = n


## The glass plot in front of the greenhouse: crops there ignore the season.
const GREENHOUSE_PLOT := Rect2i(19, 20, 9, 6)  # south-east open ground, under the greenhouse (C5; it was 17,7 where the Manor stands)


static func in_greenhouse(key: String) -> bool:
	if not Builds.is_built("greenhouse"):
		return false
	var p := key.split(",")
	return p.size() == 2 and GREENHOUSE_PLOT.has_point(Vector2i(int(p[0]), int(p[1])))


## A crop's season can be "any", one season, or a list of seasons.
static func crop_fits_season(cd: Dictionary, se: String) -> bool:
	var cs: Variant = cd.get("season", "any")
	if cs is Array:
		return se in cs
	return str(cs) == "any" or str(cs) == se


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
## The first crop, one step at a time (the goal line for "first_harvest").
static func _first_crop_step() -> String:
	var farm: Dictionary = run.get("farm", {})
	var tiles: Array = farm.values().filter(func(t: Variant) -> bool: return t is Dictionary)
	if tiles.is_empty():
		return "Hold the hoe, face grass, tap USE to till."
	var planted: Array = tiles.filter(func(t: Dictionary) -> bool: return str(t.get("crop", "")) != "")
	if planted.is_empty():
		return "Pick Turnip Seeds on the toolbar, USE on the soil."
	if planted.any(func(t: Dictionary) -> bool: return int(t.get("days", 0)) >= int(crops.get(str(t["crop"]), {}).get("days", 99))):
		return "Your crop is ripe: face it and tap USE to harvest."
	if planted.any(func(t: Dictionary) -> bool: return not bool(t.get("watered", false))) and not sky_waters():
		return "Water your crop: watering can, USE."
	var left := 99
	for t: Dictionary in planted:
		left = mini(left, int(crops.get(str(t["crop"]), {}).get("days", 1)) - int(t.get("days", 0)))
	var w := "The rain waters it today." if sky_waters() else "Watered."
	if left <= 1:
		return w + " Sleep, and it's ripe tomorrow."
	return w + " Ripe in %d nights: water it each dry morning." % left


static func next_step() -> String:
	if run.is_empty():
		return ""
	var pinned := str(run.get("pinned_quest", ""))
	if pinned != "" and not QuestTracker.is_main(pinned):
		for q in run.get("quests", []):
			if not bool(q.get("done", false)) and str(q["id"]) == pinned:
				return str(q.get("text", ""))
	var ripe := GoalLine.ripe_first()
	if ripe != "":
		return ripe
	# The main story first (newest step), then everything else in order.
	var mains := {}
	for mq in quests_data.get("main", []):
		mains[str(mq.get("id", ""))] = true
	var qs: Array = run.get("quests", [])
	for i in range(qs.size() - 1, -1, -1):
		var q: Dictionary = qs[i]
		if not bool(q.get("done", false)) and mains.has(str(q.get("id", ""))) and not GoalLine.defer(str(q.get("id", ""))):
			var gl := GoalLine.text(str(q.get("id", "")))
			if gl != "" and Campaign.STORY_REGION.has(str(q.get("id", ""))):
				return gl  # a story step still stands before the campaign
			var cp := Campaign.story_pointer(str(q.get("id", "")))
			if cp != "" and not (str(q.get("id", "")) == "sky_stair" and not (run["flags"].has("campfire_done") and run["flags"].has("babies_done"))):
				return cp  # the story's next region is held: point at its campaign
			if str(q.get("id", "")) == "sky_stair" and run["flags"].has("campfire_done") and run["flags"].has("babies_done"):
				return "Climb the great tree in the forest: the stair goes above the clouds."
			return _first_crop_step() if str(q.get("id", "")) == "first_harvest" else (gl if gl != "" else str(q.get("text", "")))
	for q in run.get("quests", []):
		if not bool(q.get("done", false)):
			return str(q.get("text", ""))
	if run["flags"].has("final_done"):
		return "The story's done. Farm, build, fish, and finish what's left on the map."
	var j := Story.journal()
	return str(j.get("summary", ""))
