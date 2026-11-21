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


## Region names for sentences (c12_13-14): "into the Wastes", "the way to the
## sky islands opens". region_name stays the bare map label for pins and buttons.
const REGION_PHRASE := {"orchard_hills": "the Orchard Hills", "highlands": "the Highlands", "quarry": "the quarry",
	"marsh": "the marsh", "riverlands": "the Riverlands", "ruins": "the ruins", "wastes": "the Wastes",
	"sky": "the sky islands", "station": "the space station", "jungle": "the green planet",
	"countryside": "the countryside", "docks": "the docks", "neon": "the neon district", "uptown": "Uptown",
	"underground": "the underground"}


static func region_phrase(c: Dictionary, cap := false) -> String:
	var t := str(REGION_PHRASE.get(str(c.get("region", "")), c.get("region_name", "that way")))
	return t.left(1).to_upper() + t.substr(1) if cap else t


## A campaign/node text that may be written per arc ({"penguins": .., "gangsters": ..}).
static func text(d: Dictionary, key: String, dflt := "") -> String:
	var v: Variant = d.get(key, dflt)
	if v is Dictionary:
		var vd: Dictionary = v
		return str(vd.get(arc(), vd.values()[0] if not vd.is_empty() else dflt))
	return str(v)


## "army" in the penguin arc, "crew" in the gangster arc.
static func force_word() -> String:
	return "army" if arc() == "penguins" else "crew"


## The captain this node fields in this run's arc ("" if none).
static func boss_of(cid: String, nid: String) -> String:
	return str(cfg(cid, nid).get("boss", node(cid, nid).get("boss", "")))


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
		s["c"][cid] = {}
	var c: Dictionary = s["c"][cid]
	# Fill whatever an old or hand-edited save is missing (C3 saves audit).
	var dflt := {"at": "n0", "morale": MORALE_START, "supply": 10, "wins": 0, "losses": 0, "retreats": 0,
		"rested": -1, "started": int(GameState.run.get("day", 1))}
	for k: String in dflt:
		if not c.has(k):
			c[k] = dflt[k]
	if not (c.get("taken") is Dictionary):
		c["taken"] = {"n0": true}
	return c


## Mustered (CampaignGate.muster), or under way in an older save.
static func started(cid: String) -> bool:
	var c: Variant = st()["c"].get(cid)
	if not (c is Dictionary):
		return false
	return bool(c.get("mustered", false)) or (c.get("taken", {}) as Dictionary).size() > 1 \
		or int(c.get("wins", 0)) + int(c.get("losses", 0)) + int(c.get("retreats", 0)) > 0


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
			return "Open %s first." % region_phrase(all()[a], true)
	var gl: String = CampaignGate.lock(cid)
	if gl != "":
		return gl
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		return "Get further in the story first."
	return CampaignGate.short_text(cid)


## Like why_locked, but ignores what you can still gather (allies, provisions):
## "" when the campaign is open for planning.
static func plan_lock(cid: String) -> String:
	var w := why_locked(cid)
	return "" if w == "" or w == CampaignGate.short_text(cid) else w


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
	return not is_won(cid) and (started(cid) or bypass) and not taken(cid, nid) and linked(cid, str(cs(cid)["at"]), nid)


## A node you hold, linked to nid, that the army can stand on to attack it ("" if none).
static func staging(cid: String, nid: String) -> String:
	if is_won(cid) or taken(cid, nid) or not (started(cid) or bypass):
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


## Story beats that mark meeting a campaign leader (Tom C3: Catkins only voices
## the late campaigns; each campaign has its own leader, see gen_battles LEAD).
const MET := {"Big Jim": "st_p3_campfire", "Coldy": "st_p3_coldy", "Catkins": "st_p2_catkins"}


## Whichever of Pip-Pip / Nova you are not playing.
static func pal() -> String:
	return "Pip-Pip" if str(GameState.run.get("playable", "")) == "penguin_f" else "Nova"


static func met(nm: String) -> bool:
	if nm == "":
		return false
	if MET.has(nm):
		return (GameState.run.get("flags", {}) as Dictionary).has(MET[nm])
	var id := nm.to_lower().replace(" ", "_")
	return not Crew.members().has(id) or Crew.recruited(id)


## Who leads (and voices) campaign cid: the first leader in its list you have met.
static func who(cid: String) -> String:
	var c := get_c(cid)
	var lst: Array = (c.get("lead", {}) as Dictionary).get(arc(), [])
	if lst.is_empty():
		lst = [str((c.get("who", {}) as Dictionary).get(arc(), ""))]
	for n in lst:
		var nm := pal() if str(n) == "pal" else str(n)
		if met(nm):
			return nm
	return pal() if arc() == "penguins" else "Sal"


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
			return [["rest", "Rest the %s (+20 morale, once a day)" % force_word()]]
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
			GameState.add_money(int(lt.get("crystals", 60)), "campaign")
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


# ---- Crystal Kin (Tom C3) -----------------------------------------------------------
## Crystal babies fight for the Grumps at first. After you win a campaign battle
## they were in, prove your purpose (a gift of refined crystal, or Meow Pow Wow
## once Nova knows it) and they join you as Crystal Kin, a helper kind raised at
## spawners (battles.json "_helper_kinds", flag crystal_kin).
const KIN_FLAG := "crystal_kin"


static func kin_gift() -> Dictionary:
	return GameState.load_json("res://data/battles.json").get("_campaigns", {}).get("kin_gift", {"item": "crystal_refined", "n": 2})


## True when the crystal babies' nest is waiting for you on this board.
static func kin_due(cid: String) -> bool:
	if arc() != "penguins" or GameState.run.is_empty():
		return false
	var fl: Dictionary = GameState.run.get("flags", {})
	if fl.has(KIN_FLAG) or int(fl.get("kin_later", -1)) == int(GameState.run.get("day", 1)):
		return false
	for nd: Dictionary in get_c(cid).get("nodes", []):
		var cf: Dictionary = (nd.get("cfg", {}) as Dictionary).get("penguins", {})
		if taken(cid, str(nd.get("id", ""))) and "crystal_baby" in (cf.get("enemies", []) as Array):
			return true
	return false


static func kin_choices(cid: String) -> Array:
	var g := kin_gift()
	var out: Array = []
	var it := str(g.get("item", "crystal_refined"))
	var n := int(g.get("n", 2))
	if GameState.count(it) >= n:
		out.append(["gift", "✦ Crystal babies: offer %s ×%d" % [GameState.item_name(it), n]])
	else:
		out.append(["need", "✦ Crystal babies: bring %s ×%d (you have %d)" % [GameState.item_name(it), n, GameState.count(it)]])
	if Companion.meow_known():
		out.append(["meow", "✦ Crystal babies: Meow Pow Wow"])
	out.append(["later", "Leave their nest in peace"])
	return out


## Returns dialogue-style lines; the last one is the result.
static func kin_settle(cid: String, choice: String) -> Array:
	var w := who(cid)
	var fl: Dictionary = GameState.run["flags"]
	match choice:
		"need":
			var g := kin_gift()
			return [{"who": w, "text": "They won't trust empty paws. Bring %s ×%d and try again." % [GameState.item_name(str(g.get("item", "crystal_refined"))), int(g.get("n", 2))]}]
		"later":
			fl["kin_later"] = int(GameState.run.get("day", 1))
			return [{"who": w, "text": "We'll leave the nest be. They saw that, I think."}]
		"gift", "meow":
			if choice == "gift":
				var g := kin_gift()
				var it := str(g.get("item", "crystal_refined"))
				if GameState.count(it) < int(g.get("n", 2)):
					return []
				GameState.add_item(it, -int(g.get("n", 2)))
			fl[KIN_FLAG] = true
			var how := "You set the crystal down by their nest and step back." if choice == "gift" else "Nova purrs, and the warm wave rolls over the nest."
			return [{"who": "", "text": how},
				{"who": w, "text": "They were Crystopia crystals once, like the Grumps. Nobody had ever asked them before. Now they're with us."},
				{"text": "Crystal Kin will answer you at battle spawners."}]
	return []


# ---- battles -----------------------------------------------------------------------

## Go and fight node nid (from the board).
static func launch(m: GameMap, cid: String, nid: String) -> void:
	var cf := cfg(cid, nid)
	var fid := str(cf.get("field", ""))
	if fid == "" or not can_attack(cid, nid):
		return
	if Net.visiting():  # a guest's fight would run unsynced on the host's world
		if m and m.hud:
			m.hud.toast("You're visiting a friend's farm. Campaigns wait until you're home.", Color(1, 0.8, 0.6))
		return
	var at := m.player.position - m.offset() if m.player else Vector2.ZERO
	st()["fight"] = {"cid": cid, "nid": nid, "field": fid, "day": int(GameState.run.get("day", 1)), "back": [m.scene_id(), at.x, at.y]}
	var R: Dictionary = RegionData.region(fid)
	var sp: Array = R.get("spawn", [10, 10])
	m.go_to(fid, Vector2(float(sp[0]) * GameMap.TILE + 8, float(sp[1]) * GameMap.TILE + 8), "up")


## Kill pay for a campaign node or the drill on this field: [flag key, kills that
## pay] (each node has its own pool; [] for a free field battle).
static func kill_pool(field: String) -> Array:
	var f := fight_for(field)
	if not f.is_empty():
		return ["bfk_%s_%s" % [str(f["cid"]), str(f["nid"])], 80]
	if not CampaignGate.drill_for(field).is_empty():
		return ["bfk_drill", 40]
	return []


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
	d["brief"] = text(n, "brief", str(d.get("brief", "")))
	d["who"] = who(cid)
	d["points"] = cf.get("points", d.get("points", []))
	d["enemies"] = cf.get("enemies", d.get("enemies", []))
	d["enemy_tier"] = enemy_tier(cid, nid)
	var tk := int(cf.get("tickets", n.get("tickets", 120)))  # sieges carry their own (size-scaled) count
	d["tickets"] = maxi(40, int(tk * (0.6 + 0.4 * morale / 100.0) * Difficulty.mul("ally_tickets")))
	d["tickets_max"] = tk
	var et := int(n.get("enemy_tickets", 120))
	if typ != "defend" and typ != "escort":
		et = maxi(10, int(et * Difficulty.mul("enemy_tickets")))
	d["enemy_tickets"] = et
	d["supply"] = int(base.get("supply", 15)) + int(s.get("supply", 0))
	d["wave_every"] = float(n.get("wave_every", d.get("wave_every", 7.0))) * Difficulty.mul("wave_every")
	d["enemy_cap"] = maxi(3, int(n.get("enemy_cap", d.get("enemy_cap", 14))) + Difficulty.add("enemy_cap"))
	d["foe_capture"] = Difficulty.mul("capture")  # Battle._capture: enemy capture speed
	d["supply_mul"] = Difficulty.mul("supply")  # Battle._tick: supply trickle
	d["inspired"] = morale >= 85
	d["reward"] = {}
	d.erase("boss")
	var bk := boss_of(cid, nid)
	if bk != "":
		d["boss"] = bk
		d["boss_at"] = "start" if typ == "boss" else "half"
	if typ == "boss":
		d["win_by"] = "boss"
	elif typ == "escort":
		d["win_by"] = "convoy"
		d["convoy"] = cf.get("convoy", [])
		d["convoy_hp"] = maxi(20, int(n.get("convoy_hp", 80)) + Difficulty.add("convoy"))
		d["vehicle"] = str(cf.get("vehicle", "wagon" if arc() == "penguins" else "truck"))
	elif typ == "defend":
		d["win_by"] = "hold"
		d["hold"] = maxi(45, int(n.get("hold", 150)) + Difficulty.add("hold"))
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
		s["supply"] = clampi(maxi(10, supply_left / 2) + int(rw.get("supply", 0)), 0, SUPPLY_CAP)
		s["morale"] = mini(100, int(s["morale"]) + int(rw.get("morale", 8)))
		var cr := int(rw.get("crystals", 0))
		GameState.add_money(cr, "campaign")
		var got: Array = ["◆%d" % cr] if cr > 0 else []
		for it: String in rw.get("items", {}):
			GameState.add_item(it, int(rw["items"][it]))
			got.append("%s ×%d" % [GameState.item_name(it), int(rw["items"][it])])
		lines.append({"who": w, "text": ("%s is ours. The " + force_word() + " moves up. Morale %d (%s), supply ◇%d.") % [str(n["name"]), int(s["morale"]), morale_word(int(s["morale"])), int(s["supply"])]})
		if not got.is_empty():
			lines.append({"text": "+" + ", ".join(got)})
		var fl := flavour(cid, nid, true)
		if fl != "":
			lines.insert(1, {"who": w, "text": fl})
		if str(n.get("type", "")) == "gate":
			lines.append_array(_unlock(cid))
	else:
		s["losses"] = int(s.get("losses", 0)) + 1
		s["supply"] = clampi(maxi(10, supply_left / 3), 0, SUPPLY_CAP)  # never too poor to place one helper
		s["morale"] = int(s["morale"]) - Difficulty.add("morale_loss")
		if int(s["morale"]) <= 0:
			s["morale"] = 40
			s["supply"] = 0
			s["at"] = "n0"
			lines.append({"who": w, "text": "We're routed. Everyone back to %s to regroup. The ground we took is still ours." % str(node(cid, "n0").get("name", "camp"))})
		else:
			var lf := flavour(cid, nid, false)
			if lf != "":
				lines.append({"who": w, "text": lf})
			lines.append({"who": w, "text": "We fall back from %s. Morale %d (%s). Rest at a camp, or try again." % [str(n["name"]), int(s["morale"]), morale_word(int(s["morale"]))]})
	return lines


## Penguin-arc colour after a campaign fight (Tom C3): the Grumps were Crystopia
## crystals the Dark Crystal turned, so winning turns them back. Meow Pow Wow is
## only mentioned once Nova knows it. Gangster fights need no extra line ("").
static func flavour(cid: String, nid: String, won: bool) -> String:
	if arc() != "penguins":
		return ""
	var n := node(cid, nid)
	var typ := str(n.get("type", ""))
	var i := absi(hash(cid + nid)) % 3
	if not won:
		return ["They're not bad, you know. They've forgotten what they were. We'll come back and remind them.",
			"Their hearts are frozen hard today. Rest, and we'll try again.",
			"The Dark Crystal's hold is strong here. Not for ever."][i]
	if typ in ["boss", "gate"]:
		var bk := boss_of(cid, nid)
		var nm := str(GameState.enemy_data.get("enemies", {}).get(bk, {}).get("name", "Their captain"))
		if Companion.meow_known():
			return "%s sways, and when Nova's purr reaches it, the frown cracks. A crystal sits where it stood, glowing warm again." % nm
		return "%s crumbles into a heap of warm, glowing crystal. Whatever it was before the Dark Crystal got it, it's free now." % nm
	var lines := ["The Grumps we beat shimmer and turn back into crystals. Somewhere inside, they remembered.",
		"One by one, the frowns melt. Little crystals lie in the grass where the Grumps stood.",
		"A Grump stops mid-swing, blinks, and turns back into a crystal. Hearts melt, if you're patient."]
	if Companion.meow_known():
		lines[2] = "Nova's purr rolls over the field, and the last Grumps sit down and sparkle. That's what they were all along."
	return lines[i]


## Walking off the field mid-fight: a retreat (morale, but no loss).
static func retreat(supply_left: int) -> void:
	var f: Dictionary = st().get("fight", {})
	var cid := str(f.get("cid", ""))
	st()["fight"] = {}
	if cid == "" or not all().has(cid):
		return
	var s := cs(cid)
	s["retreats"] = int(s.get("retreats", 0)) + 1
	s["morale"] = maxi(10, int(s["morale"]) - 15)
	s["supply"] = clampi(supply_left / 3, 0, SUPPLY_CAP)


## The gate fell: the region opens.
static func _unlock(cid: String) -> Array:
	var c := get_c(cid)
	var reg := str(c["region"])
	st()["won"][cid] = int(GameState.run.get("day", 1))
	st()["open"][reg] = true
	var rw: Dictionary = c.get("reward", {})
	var cr := int(rw.get("crystals", 0))
	GameState.add_money(cr, "campaign")
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
	return [{"who": who(cid), "text": text(c, "won", "The way is open.")},
		{"text": "%s is open! +%s" % [region_phrase(c, true), ", ".join(got)]}]


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
	cid = first_in_chain(cid)
	var c := get_c(cid)
	var held := ""
	if started(cid) and taken_count(cid) > 1:
		held = " (%d/%d held)" % [taken_count(cid) - 1, (c["nodes"] as Array).size() - 1]
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		return "%s is guarded. Get further in the story, then win \"%s\"." % [region_phrase(get_c(gate_of(reg)), true), str(c["title"])]
	var first: String = CampaignGate.next_step(cid)
	if first != "" and CampaignGate.story_ok() and not CampaignGate.trained() and not started(cid):
		first = "Training with %s on the campaign map (MENU > Map)." % CampaignGate.trainer()
	if first != "":
		# The step comes first: the HUD shows two short lines, and the tail is what gets cut.
		# Goal line budget (~112 chars): the step, then the campaign; no "X is guarded."
		var st := first.left(1).to_lower() + first.substr(1)
		var has_map := first.contains("campaign map")
		for where in (["."] if has_map else [" (campaign map, MENU > Map).", " on the campaign map.", " (campaign map)."]):
			var line := "First: %s Then win \"%s\"%s" % [st, str(c["title"]), where]
			if line.length() <= 112:
				return line
		return ("First: %s (campaign map)" % st).left(112)
	return "Open %s: win \"%s\" on the campaign map (MENU > Map)%s." % [region_phrase(c), str(c["title"]), held]


## The first campaign in cid's chain of prerequisites that still holds its
## region (cid itself when nothing comes before it).
static func first_in_chain(cid: String) -> String:
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
	return cid


## How many held campaigns stand before cid (its chain, cid excluded).
static func chain_left(cid: String) -> int:
	var n := 0
	var cur := cid
	while n < 8:
		var nxt := ""
		for a in get_c(cur).get("after", []):
			if all().has(a) and str(all()[a].get("arc", "both")) in ["both", arc()] and not region_open(str(all()[a]["region"])):
				nxt = str(a)
				break
		if nxt == "":
			break
		n += 1
		cur = nxt
	return n


## True (and offers the campaign) when `scene` is still held by a campaign.
const VISIT_GATE := "This border is held in your own story. You can open it from your own farm; while you visit, it stays shut."


static func blocks(m: GameMap, scene: String) -> bool:
	if bypass or m == null or scene == m.scene_id() or GameState.run.is_empty() or region_open(scene):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_offer > 1500 and not Dialogue.instance(m.get_tree()).active:
		_last_offer = now
		Music.instance(m.get_tree()).sfx("locked", "nope")  # a held border: bump, then the gate words
		m.later(offer.bind(m, gate_of(scene)))
	return true


static func offer(m: GameMap, cid: String) -> void:
	var c := get_c(cid)
	if c.is_empty() or not is_instance_valid(m):
		return
	var gw := gate_words(cid)
	var lines: Array = []
	for t in gw["lines"]:
		lines.append({"who": "", "text": str(t)})
	if Net.visiting():  # the board's Muster/Attack wait until home: no dead-end offer on a friend's world
		lines = [{"who": "", "text": VISIT_GATE}]
	var dl := Dialogue.instance(m.get_tree())
	if not bool(gw["board"]) or Net.visiting():
		dl.say(lines)
		await dl.finished
		_last_offer = Time.get_ticks_msec()
		return
	lines[lines.size() - 1]["choice"] = ["Open the campaign map", "Not now"]
	lines[lines.size() - 1]["key"] = ""
	dl.say(lines)
	await dl.finished
	_last_offer = Time.get_ticks_msec()
	if dl.last_choice == 0 and is_instance_valid(m):
		CampaignScreen.open(m, str(gw.get("cid", cid)))


## What you sense walking up to a region campaign `cid` still holds, and the one
## true next step, checking the same conditions as why_locked (story and
## training first, as they're what to do next). {"stage", "lines": [sense, step], "board": offer the
## campaign map}. Stages: story, train, after (an earlier region first), later
## (story tier), gather (team/provisions), ready, under_way.
static func gate_words(cid: String) -> Dictionary:
	var c := get_c(cid)
	var a := arc()
	var pen := a == "penguins"
	var reg := region_phrase(c) if not c.is_empty() else "that way"
	var sense := str((c.get("sense", {}) as Dictionary).get(a, ""))
	if sense == "":
		sense = "You hear a low rumbling ahead, and every hair on your neck stands up." if pen else "The street goes quiet ahead. Too quiet."
	var lead := who(cid)
	var out := {"stage": "", "lines": [sense], "board": false, "cid": cid}
	if started(cid):
		out["stage"] = "under_way"
		out["board"] = true
		out["lines"][0] = sense   # c12_13-15: no "not yet" tail once it's under way
		out["lines"].append(("Your banners are already moving: you hold %d of %d territories. Win \"%s\" on the campaign map to break through to %s." if pen
			else "Your crew is already moving: you hold %d of %d blocks. Win \"%s\" on the campaign map to break through to %s.") % [taken_count(cid) - 1, (c["nodes"] as Array).size() - 1, str(c["title"]), reg])
		return out
	# c12_13-15: the tail fits the stage: "not yet" while the way is shut,
	# "not without the team" once only the muster is left.
	var gathering := CampaignGate.story_ok() and CampaignGate.trained() and first_in_chain(cid) == cid and GameState.progress_tier() >= int(c.get("min_pt", 0))
	if gathering:
		out["lines"][0] = sense + (" Not on your own. Not yet." if pen else " Not on foot. Not without the crew.")
	else:
		out["lines"][0] = sense + (" It doesn't feel safe to go on yet." if pen else " You'd be walking in alone. Not yet.")
	if not CampaignGate.story_ok():
		out["stage"] = "story"
		var met_meadow := GameState.quest_done("clear_meadow")
		if pen:
			out["lines"].append("Find Catkins by the cat statue in the crystal meadow. She'll know what to do." if met_meadow
				else "Something is howling in the east meadow. Find out what it is. Past it, a cat called Catkins is purring, and she'll know what to do.")
		else:
			out["lines"].append("Get through the outskirts gate to Hideout town first. Sal knows these roads and will find you there." if met_meadow
				else "Someone's been asking about you in the east meadow. Go and see who. Sal knows these roads.")
		return out
	if not CampaignGate.trained():
		out["stage"] = "train"
		out["board"] = true
		out["lines"].append(("Catkins says one brave farmer can't take a valley alone. Drill with her first: MENU > Map > Campaign map > Training." if pen
			else "Sal says you don't take a road with one pair of fists. Drill with Sal first: MENU > Map > Campaign map > Training.") if CampaignGate.trainer() in ["Catkins", "Sal"]
			else "Drill with %s first: MENU > Map > Campaign map > Training." % CampaignGate.trainer())
		return out
	var pre := first_in_chain(cid)
	if pre != cid:
		var more := chain_left(cid) - 1
		var pc := get_c(pre)
		out["stage"] = "after"
		out["board"] = true
		out["cid"] = pre
		var t := "%s won't lead you into %s until %s is taken: win \"%s\" on the campaign map first." % [lead, reg, region_phrase(pc), str(pc["title"])]
		if more > 0:
			t += " After that, %d more campaign%s." % [more, "" if more == 1 else "s"]
		if GameState.progress_tier() < int(pc.get("min_pt", 0)):
			t += " That one comes later in the story."
		out["lines"].append(t)
		return out
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		out["stage"] = "later"
		out["lines"].append("%s shakes their head: it's too soon for %s. Follow the story further (your goal line shows the next step), then come back." % [lead, reg])
		return out
	var short := CampaignGate.short_text(cid)
	out["board"] = true
	if short != "":
		out["stage"] = "gather"
		out["lines"].append(("%s is ready to lead you in, but the " + force_word() + " needs more first. %s Then muster for \"%s\" on the campaign map.") % [lead, short, str(c["title"])])
		return out
	out["stage"] = "ready"
	out["lines"].append("%s has the team and the provisions ready. Muster for \"%s\" on the campaign map, win it, and the way to %s opens." % [lead, str(c["title"]), reg])
	return out


## After a campaign fight: once back on the map, open the board again.
static func reopen_later(tree: SceneTree, cid: String, tries := 12) -> void:
	tree.create_timer(1.0, true).timeout.connect(func() -> void:
		var gm := tree.current_scene as GameMap
		if gm == null or gm._changing or gm.scene_id().begins_with("bf_") or tree.paused or Dialogue.instance(tree).active or gm.player == null:
			if tries > 0:
				reopen_later(tree, cid, tries - 1)
			return
		CampaignScreen.open(gm, cid))
