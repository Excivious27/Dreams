class_name Campaign
extends RefCounted
## Region campaigns: every major region is opened by winning a campaign, a board
## of 5-7 territories with branching routes (data: battles.json "_campaigns",
## written by tools/gen_battles.py). Your army sits on a node you hold; attack a
## node linked to it. Battle nodes are fights on a bf_* field with their own
## objective (skirmish, siege, escort, defend, boss, gate); camps and caches are
## settled on the board. Morale and supply carry from node to node; the gate
## node opens the region. Save: run["campaign"] =
##   {"v", "open": {region: true}, "won": {cid: day}, "c": {cid: state}, "fight": {...}}
## Board UI: CampaignScreen. Battle reads fight_for() / battle_data().

const MORALE_START := 70
const SUPPLY_CAP := 80
const NONBATTLE := ["start", "camp", "cache"]
const TYPE_NAME := {"start": "Camp", "camp": "Rest camp", "cache": "Supply cache", "skirmish": "Skirmish", "siege": "Siege",
	"escort": "Escort", "defend": "Defend", "boss": "Captain", "gate": "Region gate"}
const TYPE_GOAL := {"skirmish": "Take the points or run out their tickets.", "siege": "Every point they hold is fortified. Take them all or run out their tickets.",
	"escort": "Walk the convoy to its goal. It rolls while a friend is beside it and no foe is on it.",
	"defend": "Hold out until the timer ends. Keep at least one point.", "boss": "Bring their captain down.",
	"gate": "Take every point or run out their tickets. Their commander joins halfway."}

## Tests and debugging: no region is locked.
static var bypass := false
static var _all: Dictionary = {}
static var _last_offer := 0


static func all() -> Dictionary:
	if _all.is_empty():
		_all = GameState.load_json("res://data/battles.json").get("_campaigns", {}).get("list", {})
	return _all


static func arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func get_c(cid: String) -> Dictionary:
	return all().get(cid, {})


## This run's campaigns, easiest first.
static func for_arc() -> Array:
	var out: Array = []
	for cid: String in all():
		if str(all()[cid].get("arc", "both")) in ["both", arc()]:
			out.append(cid)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ta := int(all()[a]["tier"])
		var tb := int(all()[b]["tier"])
		return ta < tb if ta != tb else str(all()[a]["title"]) < str(all()[b]["title"]))
	return out


## The campaign that opens `scene` in this run ("" if none).
static func gate_of(scene: String) -> String:
	var cid := "c_" + scene
	if all().has(cid) and str(all()[cid].get("arc", "both")) in ["both", arc()]:
		return cid
	return ""


# ---- save ----------------------------------------------------------------------

static func st() -> Dictionary:
	var r := GameState.run
	if r.is_empty():
		return {"open": {}, "won": {}, "c": {}, "fight": {}}
	if not (r.get("campaign") is Dictionary):
		r["campaign"] = {"v": 1, "open": {}, "won": {}, "c": {}, "fight": {}}
		_migrate(r["campaign"])
	var s: Dictionary = r["campaign"]
	for k in ["open", "won", "c", "fight"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	return s


## Older saves: every gated region you've already been to stays open.
static func _migrate(s: Dictionary) -> void:
	var r := GameState.run
	var vis: Dictionary = r.get("visited", {})
	var fl: Dictionary = r.get("flags", {})
	for cid: String in all():
		var reg := str(all()[cid]["region"])
		if vis.has(reg) or fl.has(reg + "_seen") or fl.has("boss_" + reg) or str(r.get("scene", "")) == reg:
			s["open"][reg] = true


static func cs(cid: String) -> Dictionary:
	var s := st()
	if not (s["c"].get(cid) is Dictionary):
		s["c"][cid] = {"at": "n0", "taken": {"n0": true}, "morale": MORALE_START, "supply": 10, "wins": 0, "losses": 0, "retreats": 0,
			"rested": -1, "started": int(GameState.run.get("day", 1))}
	return s["c"][cid]


static func started(cid: String) -> bool:
	return st()["c"].has(cid)


static func is_won(cid: String) -> bool:
	return st()["won"].has(cid)


static func region_open(scene: String) -> bool:
	if bypass:
		return true
	var cid := gate_of(scene)
	if cid == "":
		return true
	return is_won(cid) or st()["open"].has(scene)


## "" when this campaign can be fought now, else why not.
static func why_locked(cid: String) -> String:
	var c := get_c(cid)
	if c.is_empty():
		return "No such campaign."
	for a in c.get("after", []):
		if all().has(a) and str(all()[a].get("arc", "both")) in ["both", arc()] and not region_open(str(all()[a]["region"])):
			return "Open %s first." % str(all()[a]["region_name"])
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		return "Get further in the story first."
	return ""


static func unlock_all() -> void:
	for cid: String in all():
		st()["open"][str(all()[cid]["region"])] = true


# ---- the board -----------------------------------------------------------------

static func node(cid: String, nid: String) -> Dictionary:
	for n in get_c(cid).get("nodes", []):
		if str(n["id"]) == nid:
			return n
	return {}


static func taken(cid: String, nid: String) -> bool:
	return (cs(cid)["taken"] as Dictionary).has(nid)


static func taken_count(cid: String) -> int:
	return (cs(cid)["taken"] as Dictionary).size()


static func linked(cid: String, a: String, b: String) -> bool:
	return b in (node(cid, a).get("links", []) as Array)


## Linked to where the army stands and not yet yours.
static func can_attack(cid: String, nid: String) -> bool:
	return not is_won(cid) and not taken(cid, nid) and linked(cid, str(cs(cid)["at"]), nid)


## A node you hold, linked to nid, that the army can stand on to attack it ("" if none).
static func staging(cid: String, nid: String) -> String:
	if is_won(cid) or taken(cid, nid):
		return ""
	var at := str(cs(cid)["at"])
	if linked(cid, at, nid):
		return at
	for l in node(cid, nid).get("links", []):
		if can_march(cid, str(l)):
			return str(l)
	return ""


## A node you hold that the army can walk to through ground you hold.
static func can_march(cid: String, nid: String) -> bool:
	var at := str(cs(cid)["at"])
	if nid == at or not taken(cid, nid):
		return false
	var seen := {at: true}
	var q: Array = [at]
	while not q.is_empty():
		var cur: String = q.pop_front()
		for l in node(cid, cur).get("links", []):
			if taken(cid, str(l)) and not seen.has(str(l)):
				if str(l) == nid:
					return true
				seen[str(l)] = true
				q.append(str(l))
	return false


## Shortest route (node ids) from the army to nid over held ground, ending at nid.
static func route(cid: String, nid: String) -> Array:
	var at := str(cs(cid)["at"])
	var prev := {at: ""}
	var q: Array = [at]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == nid:
			break
		for l in node(cid, cur).get("links", []):
			var ls := str(l)
			if prev.has(ls):
				continue
			if taken(cid, ls) or ls == nid:
				prev[ls] = cur
				q.append(ls)
	if not prev.has(nid):
		return []
	var out: Array = [nid]
	while str(prev[out[0]]) != "":
		out.push_front(prev[out[0]])
	return out


## Enemy level at a node: the region's tier, never more than one past your
## story progress, plus the node's depth on the board.
static func enemy_tier(cid: String, nid: String) -> int:
	var base := mini(int(get_c(cid).get("tier", 1)), GameState.progress_tier() + 1)
	return clampi(base - 1 + int(node(cid, nid).get("step", 0)), 0, 5)


static func stars(cid: String, nid: String) -> int:
	if str(node(cid, nid).get("type", "")) in NONBATTLE:
		return 0
	return clampi(enemy_tier(cid, nid) + 1, 1, 5)


## -1 easy, 0 fair, 1 hard, 2 very hard (against your progress).
static func danger(cid: String, nid: String) -> int:
	return clampi(enemy_tier(cid, nid) - GameState.progress_tier(), -1, 2)


static func cfg(cid: String, nid: String) -> Dictionary:
	var c: Dictionary = node(cid, nid).get("cfg", {})
	if c.has(arc()):
		return c[arc()]
	return c.values()[0] if not c.is_empty() else {}


static func who(cid: String) -> String:
	var w: Dictionary = get_c(cid).get("who", {})
	var n := str(w.get(arc(), ""))
	var id := n.to_lower().replace(" ", "_")
	return n if n == "" or not Crew.members().has(id) or Crew.recruited(id) else ""


static func march(cid: String, nid: String) -> bool:
	if not can_march(cid, nid):
		return false
	cs(cid)["at"] = nid
	return true


static func morale_word(m: int) -> String:
	return "Inspired" if m >= 85 else ("Steady" if m >= 55 else ("Shaken" if m >= 25 else "Wavering"))


# ---- camps and caches ------------------------------------------------------------

## Options for a camp/cache node you are moving into, or resting at.
static func board_choices(cid: String, nid: String) -> Array:
	var n := node(cid, nid)
	var lt: Dictionary = n.get("loot", {})
	match str(n.get("type", "")):
		"cache":
			if taken(cid, nid):
				return []
			return [["take", "Take the stores (+◇%d supply)" % int(lt.get("supply", 20))], ["share", "Share with the locals (+%d morale, +◆%d)" % [int(lt.get("morale", 15)), int(lt.get("crystals", 60))]]]
		"camp", "start":
			if not taken(cid, nid):
				return [["rest", "Make camp (+30 morale)"], ["forage", "Forage (+◇%d supply, +10 morale)" % int(lt.get("supply", 20) / 2 + 5)]]
			if int(cs(cid).get("rested", -1)) == int(GameState.run.get("day", 1)):
				return []
			return [["rest", "Rest the army (+20 morale, once a day)"]]
	return []


## Settle a camp/cache move. Returns the line to show.
static func settle(cid: String, nid: String, choice: String) -> String:
	var n := node(cid, nid)
	var s := cs(cid)
	var lt: Dictionary = n.get("loot", {})
	var first := not taken(cid, nid)
	var out := ""
	match choice:
		"take":
			s["supply"] = mini(SUPPLY_CAP, int(s["supply"]) + int(lt.get("supply", 20)))
			for it: String in lt.get("items", {}):
				GameState.add_item(it, int(lt["items"][it]))
			out = "The stores are loaded up. Supply ◇%d." % int(s["supply"])
		"share":
			s["morale"] = mini(100, int(s["morale"]) + int(lt.get("morale", 15)))
			GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + int(lt.get("crystals", 60))
			out = "The locals cheer you on and press a purse into your hand. Morale %d." % int(s["morale"])
		"rest":
			s["morale"] = mini(100, int(s["morale"]) + (30 if first else 20))
			s["rested"] = int(GameState.run.get("day", 1))
			out = "Fires, songs and a good night's sleep. Morale %d (%s)." % [int(s["morale"]), morale_word(int(s["morale"]))]
		"forage":
			s["supply"] = mini(SUPPLY_CAP, int(s["supply"]) + int(lt.get("supply", 20) / 2 + 5))
			s["morale"] = mini(100, int(s["morale"]) + 10)
			s["rested"] = int(GameState.run.get("day", 1))
			out = "Berries, firewood and a few lost crates. Supply ◇%d." % int(s["supply"])
	s["taken"][nid] = true
	s["at"] = nid
	GameState.add_xp("strategist", 10)
	return out


# ---- battles -----------------------------------------------------------------------

## Go and fight node nid (from the board).
static func launch(m: GameMap, cid: String, nid: String) -> void:
	var cf := cfg(cid, nid)
	var fid := str(cf.get("field", ""))
	if fid == "" or not can_attack(cid, nid):
		return
	var at := m.player.position - m.offset() if m.player else Vector2.ZERO
	st()["fight"] = {"cid": cid, "nid": nid, "field": fid, "day": int(GameState.run.get("day", 1)), "back": [m.scene_id(), at.x, at.y]}
	var R: Dictionary = GameState.load_json("res://data/regions.json").get(fid, {})
	var sp: Array = R.get("spawn", [10, 10])
	m.go_to(fid, Vector2(float(sp[0]) * GameMap.TILE + 8, float(sp[1]) * GameMap.TILE + 8), "up")


## The campaign fight on this field, if one is under way ({} otherwise).
static func fight_for(field: String) -> Dictionary:
	var f: Dictionary = st().get("fight", {})
	if f.is_empty() or str(f.get("field", "")) != field or not all().has(str(f.get("cid", ""))):
		return {}
	if node(str(f["cid"]), str(f["nid"])).is_empty() or taken(str(f["cid"]), str(f["nid"])):
		return {}
	return f


## The field's battle data reshaped for this node: points, objective, waves,
## tickets (morale), starting supply (what the army carries), enemy level.
static func battle_data(base: Dictionary, f: Dictionary) -> Dictionary:
	var cid := str(f["cid"])
	var nid := str(f["nid"])
	var n := node(cid, nid)
	var cf := cfg(cid, nid)
	var s := cs(cid)
	var d := base.duplicate(true)
	var typ := str(n.get("type", "skirmish"))
	var morale := int(s.get("morale", MORALE_START))
	d["campaign"] = cid
	d["node"] = nid
	d["mode"] = typ
	d["title"] = "%s: %s" % [str(get_c(cid)["title"]), str(n["name"])]
	d["brief"] = str(n.get("brief", d.get("brief", "")))
	d["who"] = str(get_c(cid).get("who", {}).get(arc(), d.get("who", "")))
	d["points"] = cf.get("points", d.get("points", []))
	d["enemies"] = cf.get("enemies", d.get("enemies", []))
	d["enemy_tier"] = enemy_tier(cid, nid)
	d["tickets"] = maxi(40, int(int(n.get("tickets", 120)) * (0.6 + 0.4 * morale / 100.0)))
	d["tickets_max"] = int(n.get("tickets", 120))
	var et := int(n.get("enemy_tickets", 120))
	if Settings.easy() and typ != "defend" and typ != "escort":
		et = int(et * 0.75)
	d["enemy_tickets"] = et
	d["supply"] = int(base.get("supply", 15)) + int(s.get("supply", 0))
	d["wave_every"] = float(n.get("wave_every", d.get("wave_every", 7.0)))
	d["enemy_cap"] = int(n.get("enemy_cap", d.get("enemy_cap", 14))) - (3 if Settings.easy() else 0)
	d["inspired"] = morale >= 85
	d["reward"] = {}
	d.erase("boss")
	if n.has("boss"):
		d["boss"] = str(n["boss"])
		d["boss_at"] = "start" if typ == "boss" else "half"
	if typ == "boss":
		d["win_by"] = "boss"
	elif typ == "escort":
		d["win_by"] = "convoy"
		d["convoy"] = cf.get("convoy", [])
		d["convoy_hp"] = int(n.get("convoy_hp", 80)) + (20 if Settings.easy() else 0)
	elif typ == "defend":
		d["win_by"] = "hold"
		d["hold"] = int(n.get("hold", 150)) - (30 if Settings.easy() else 0)
	var back: Array = f.get("back", [])
	if back.size() >= 3:
		d["back"] = [str(back[0]), float(back[1]) / GameMap.TILE, float(back[2]) / GameMap.TILE]
	return d


## A campaign battle ended. Applies morale/supply/rewards; returns dialogue lines.
static func finish(won: bool, supply_left: int) -> Array:
	var f: Dictionary = st().get("fight", {})
	var cid := str(f.get("cid", ""))
	var nid := str(f.get("nid", ""))
	st()["fight"] = {}
	if cid == "" or node(cid, nid).is_empty():
		return []
	var n := node(cid, nid)
	var c := get_c(cid)
	var s := cs(cid)
	var lines: Array = []
	var w := who(cid)
	if won:
		s["taken"][nid] = true
		s["at"] = nid
		if Engine.get_main_loop() is SceneTree:
			var all_taken := true
			for nd: Dictionary in c.get("nodes", []):
				if not s["taken"].has(str(nd.get("id", ""))):
					all_taken = false
			Music.instance(Engine.get_main_loop() as SceneTree).sfx("j_campaign_won" if all_taken else "j_battle_won", "levelup")
		s["wins"] = int(s.get("wins", 0)) + 1
		var rw: Dictionary = n.get("reward", {})
		s["supply"] = clampi(supply_left / 2 + int(rw.get("supply", 0)), 0, SUPPLY_CAP)
		s["morale"] = mini(100, int(s["morale"]) + int(rw.get("morale", 8)))
		var cr := int(rw.get("crystals", 0))
		GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + cr
		var got: Array = ["◆%d" % cr] if cr > 0 else []
		for it: String in rw.get("items", {}):
			GameState.add_item(it, int(rw["items"][it]))
			got.append("%s ×%d" % [GameState.item_name(it), int(rw["items"][it])])
		lines.append({"who": w, "text": "%s is ours. The army moves up. Morale %d (%s), supply ◇%d." % [str(n["name"]), int(s["morale"]), morale_word(int(s["morale"])), int(s["supply"])]})
		if not got.is_empty():
			lines.append({"text": "+" + ", ".join(got)})
		if str(n.get("type", "")) == "gate":
			lines.append_array(_unlock(cid))
	else:
		s["losses"] = int(s.get("losses", 0)) + 1
		s["supply"] = clampi(supply_left / 3, 0, SUPPLY_CAP)
		s["morale"] = int(s["morale"]) - 20
		if int(s["morale"]) <= 0:
			s["morale"] = 40
			s["supply"] = 0
			s["at"] = "n0"
			lines.append({"who": w, "text": "We're routed. Everyone back to %s to regroup. The ground we took is still ours." % str(node(cid, "n0").get("name", "camp"))})
		else:
			lines.append({"who": w, "text": "We fall back from %s. Morale %d (%s). Rest at a camp, or try again." % [str(n["name"]), int(s["morale"]), morale_word(int(s["morale"]))]})
	return lines


## Walking off the field mid-fight: a retreat (morale, but no loss).
static func retreat(supply_left: int) -> void:
	var f: Dictionary = st().get("fight", {})
	var cid := str(f.get("cid", ""))
	st()["fight"] = {}
	if cid == "" or not all().has(cid):
		return
	var s := cs(cid)
	s["retreats"] = int(s.get("retreats", 0)) + 1
	s["morale"] = maxi(10, int(s["morale"]) - 10)
	s["supply"] = clampi(supply_left / 2, 0, SUPPLY_CAP)


## The gate fell: the region opens.
static func _unlock(cid: String) -> Array:
	var c := get_c(cid)
	var reg := str(c["region"])
	st()["won"][cid] = int(GameState.run.get("day", 1))
	st()["open"][reg] = true
	var rw: Dictionary = c.get("reward", {})
	var cr := int(rw.get("crystals", 0))
	GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + cr
	var got: Array = ["◆%d" % cr]
	var items: Dictionary = (rw.get("items", {}) as Dictionary).duplicate()
	var ai: Dictionary = rw.get("arc_items", {}).get(arc(), {})
	for k: String in ai:
		items[k] = int(items.get(k, 0)) + int(ai[k])
	for it: String in items:
		GameState.add_item(it, int(items[it]))
		got.append("%s ×%d" % [GameState.item_name(it), int(items[it])])
	GameState.add_xp("strategist", int(rw.get("strategist", 300)))
	GameState.add_arc_xp(60 + 20 * int(c.get("tier", 1)))
	GameState.run["flags"]["campaign_" + reg] = true
	return [{"who": who(cid), "text": str(c.get("won", "The way is open."))},
		{"text": "%s is open! +%s" % [str(c["region_name"]), ", ".join(got)]}]


# ---- region locks (hooked from GameMap.go_to / check_exits) --------------------------

## Main-story quests that happen in a campaign-held region.
const STORY_REGION := {"wastes_gate": "wastes", "commander": "wastes", "sky_stair": "sky", "knight": "sky",
	"docks": "docks", "neon": "neon", "pit": "underground", "uptown": "uptown", "tower": "uptown"}


## The goal line for a story quest whose region is still held: which campaign
## to win and where the board is ("" when the way is open).
static func story_pointer(qid: String) -> String:
	var reg := str(STORY_REGION.get(qid, ""))
	if reg == "" or region_open(reg):
		return ""
	var cid := gate_of(reg)
	if cid == "":
		return ""
	# The first campaign in the chain that isn't won yet.
	var guard := 0
	while guard < 8:
		guard += 1
		var moved := false
		for a in get_c(cid).get("after", []):
			if all().has(a) and str(all()[a].get("arc", "both")) in ["both", arc()] and not region_open(str(all()[a]["region"])):
				cid = str(a)
				moved = true
				break
		if not moved:
			break
	var c := get_c(cid)
	var held := ""
	if started(cid) and taken_count(cid) > 1:
		held = " (%d/%d held)" % [taken_count(cid) - 1, (c["nodes"] as Array).size() - 1]
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		return "%s is held. Get further in the story, then win \"%s\"." % [str(get_c(gate_of(reg))["region_name"]), str(c["title"])]
	return "Open %s: win \"%s\" on the campaign map (Menu > Map)%s." % [str(c["region_name"]), str(c["title"]), held]


## True (and offers the campaign) when `scene` is still held by a campaign.
static func blocks(m: GameMap, scene: String) -> bool:
	if bypass or m == null or scene == m.scene_id() or GameState.run.is_empty() or region_open(scene):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_offer > 1500 and not Dialogue.instance(m.get_tree()).active:
		_last_offer = now
		m.later(offer.bind(m, gate_of(scene)))
	return true


static func offer(m: GameMap, cid: String) -> void:
	var c := get_c(cid)
	if c.is_empty() or not is_instance_valid(m):
		return
	var why := why_locked(cid)
	var prog := "" if not started(cid) else " You hold %d of %d territories." % [taken_count(cid) - 1, (c["nodes"] as Array).size() - 1]
	var dl := Dialogue.instance(m.get_tree())
	if why != "":
		dl.say([{"who": "", "text": "%s is held against you. Win the %s campaign to open the way. %s" % [str(c["region_name"]), str(c["title"]), why]}])
		await dl.finished
		_last_offer = Time.get_ticks_msec()
		return
	dl.say([{"who": "", "text": "%s is held against you. Win the %s campaign to open the way.%s" % [str(c["region_name"]), str(c["title"]), prog],
		"choice": ["Open the campaign map", "Not now"], "key": ""}])
	await dl.finished
	_last_offer = Time.get_ticks_msec()
	if dl.last_choice == 0 and is_instance_valid(m):
		CampaignScreen.open(m, cid)


## After a campaign fight: once back on the map, open the board again.
static func reopen_later(tree: SceneTree, cid: String, tries := 12) -> void:
	tree.create_timer(1.0, true).timeout.connect(func() -> void:
		var gm := tree.current_scene as GameMap
		if gm == null or gm.scene_id().begins_with("bf_") or tree.paused or Dialogue.instance(tree).active or gm.player == null:
			if tries > 0:
				reopen_later(tree, cid, tries - 1)
			return
		CampaignScreen.open(gm, cid))
