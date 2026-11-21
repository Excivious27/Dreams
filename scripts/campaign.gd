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
static var _last_offer := -100000


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
		return {"open": {}, "won": {}, "c": {}, "fight": {}, "long": {}}
	if not (r.get("campaign") is Dictionary):
		r["campaign"] = {"v": 1, "open": {}, "won": {}, "c": {}, "fight": {}}
		_migrate(r["campaign"])
	var s: Dictionary = r["campaign"]
	for k in ["open", "won", "c", "fight", "long"]:
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
	if is_won(cid) or st()["open"].has(scene):
		return true
	_long_settle(cid)  # a long way under way arrives once its day comes
	return st()["open"].has(scene)


## C17 P3 (c17_05-09): may we walk into this region? Our own story, or (visit-only)
## a region the host opened. Only border walking/travel uses it; region_open stays
## "my story opened it" for colonies, marinas, goal lines and the board.
static func can_visit(scene: String) -> bool:
	return region_open(scene) or CampaignFollow.host_opened(scene)


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


# ---- the long way (C16b P3) ------------------------------------------------------
## Battles never block a cozy player: every campaign-held region also opens by a
## slower, non-combat route (Tom C16b). Data: battles.json campaign "long_way"
## (gen_battles.py, P5) = {kind: quest|toll|travel|story, id, cost: {money, items},
## steps, text, text_gang, unlock_after: loss|skip|always, days}; any part missing
## falls back to a toll + a one-day favour scaled by the campaign's tier. Taking
## it opens the region and sets the same story flag as a win (campaign_<region>),
## but no stars, chest or win rewards: is_won() stays false and the board stays
## playable for its prizes. Save: st()["long"][cid] = {"day", "due", "done"}.
const LONG_MONEY := [0, 300, 900, 2000, 4000, 7000]
const LONG_ITEMS := [{}, {"wood": 20}, {"hardwood": 10}, {"iron_bar": 3}, {"gold_bar": 2}, {"gold_bar": 4}]


static func long_way(cid: String) -> Dictionary:
	var c := get_c(cid)
	if c.is_empty():
		return {}
	var raw: Variant = c.get("long_way", {})
	var lw: Dictionary = (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
	if lw.get(arc()) is Dictionary:  # per-arc rows are allowed too
		lw = (lw[arc()] as Dictionary).duplicate(true)
	var t := clampi(int(c.get("tier", 1)), 1, 5)
	var reg := str(c.get("region", ""))
	if str(lw.get("kind", "")) == "":
		lw["kind"] = "toll"
	if not (lw.get("cost") is Dictionary):
		lw["cost"] = {"money": LONG_MONEY[t], "items": (LONG_ITEMS[t] as Dictionary).duplicate()}
	var cost: Dictionary = lw["cost"]
	cost["money"] = int(cost.get("money", 0))
	if not (cost.get("items") is Dictionary):
		cost["items"] = {}
	for it: String in (cost["items"] as Dictionary).keys():  # never ask for an item the game lacks
		if not GameState.items.has(it):
			(cost["items"] as Dictionary).erase(it)
	if started(cid) and not is_won(cid):  # c16b_08-12: provisions already spent at muster count towards it
		var paid := int(CampaignGate.need(cid).get("crystals", 0))
		if paid > 0 and int(cost["money"]) > 0:
			cost["money"] = maxi(0, int(cost["money"]) - paid)
			lw["discount"] = paid
	if not lw.has("days"):
		lw["days"] = 0 if str(lw["kind"]) == "story" else 1
	if str(lw.get("unlock_after", "")) == "":
		lw["unlock_after"] = "always"
	if str(lw.get("id", "")) == "":
		lw["id"] = "lw_" + reg
	if not (lw.get("steps") is Array):
		lw["steps"] = []
	lw["cid"] = cid
	lw["region"] = reg
	var tx := text(lw, "text_gang") if arc() == "gangsters" and lw.has("text_gang") else text(lw, "text")
	if tx == "":
		var due := "You're through by morning." if int(lw["days"]) > 0 else "You're through today."
		tx = ("%s knows a slower path round to %s, away from the fighting: %s for the guides. %s" if arc() == "penguins"
			else "%s knows a back way into %s, nowhere near the crews: %s for the right people. %s") % [who(cid), region_phrase(c), long_cost_words(cost), due]
	if int(lw.get("discount", 0)) > 0:
		tx += " Your provisions go towards it."
	lw["words"] = tx
	return lw


## "◆300 and Wood ×20" (or "nothing" when free).
static func long_cost_words(cost: Dictionary) -> String:
	var parts: Array = []
	if int(cost.get("money", 0)) > 0:
		parts.append(Money.amount(int(cost["money"])))
	var its: Dictionary = cost.get("items", {})
	for it: String in its:
		parts.append(ItemWords.count_id(it, int(its[it])))
	if parts.is_empty():
		return "nothing but your time"
	return " and ".join(parts) if parts.size() <= 2 else ", ".join(parts.slice(0, parts.size() - 1)) + " and " + str(parts[-1])


## The button word for the board, the loss card and the border:
## "Take the long way (◆300, Wood ×20)".
static func long_way_label(cid: String) -> String:
	var lw := long_way(cid)
	if lw.is_empty():
		return ""
	return "Take the long way (%s)" % long_cost_words(lw["cost"]).replace(" and ", ", ")


static func long_state(cid: String) -> Dictionary:
	var v: Variant = st()["long"].get(cid)
	return v if v is Dictionary else {}


## True once the long way has opened the region.
static func long_way_taken(cid: String) -> bool:
	return bool(long_state(cid).get("done", false))


## On the road (paid, the favour takes a day) but not there yet.
static func long_way_pending(cid: String) -> bool:
	var ls := long_state(cid)
	return not ls.is_empty() and not bool(ls.get("done", false))


## "" when the long way can be taken now, else why not (shown on the button).
static func long_way_lock(cid: String) -> String:
	var c := get_c(cid)
	if c.is_empty():
		return "No such campaign."
	var reg := str(c["region"])
	if is_won(cid) or long_way_taken(cid) or st()["open"].has(reg):
		return "The way is already open."
	if long_way_pending(cid):
		return "You're already on the long way. You'll be through by morning."
	if Net.visiting():
		return "You're visiting a friend's farm. The long way waits until you're home."
	for a in c.get("after", []):
		if all().has(a) and str(all()[a].get("arc", "both")) in ["both", arc()] and not region_open(str(all()[a]["region"])):
			return "Open %s first (win it, or take its long way)." % region_phrase(all()[a])
	if GameState.progress_tier() < int(c.get("min_pt", 0)):
		return "Get further in the story first."
	var lw := long_way(cid)
	if str(lw.get("unlock_after", "always")) == "loss":
		var s: Dictionary = st()["c"].get(cid, {})
		if int(s.get("losses", 0)) + int(s.get("retreats", 0)) < 1:
			return "Try the campaign once first. If it goes badly, the long way opens."
	var cost: Dictionary = lw["cost"]
	if int(GameState.run.get("crystals", 0)) < int(cost.get("money", 0)):
		return "You need %s for the long way." % Money.amount(int(cost["money"]))
	var its: Dictionary = cost.get("items", {})
	for it: String in its:
		if GameState.count(it) < int(its[it]):
			return "Bring %s for the long way (you have %d)." % [ItemWords.count_id(it, int(its[it])), GameState.count(it)]
	return ""


## Worth offering: takeable now, or only short of its toll (the pick then says what to bring).
static func long_way_offerable(cid: String) -> bool:
	var lk := long_way_lock(cid)
	return lk == "" or lk.begins_with("You need") or lk.begins_with("Bring")


static func can_take_long_way(cid: String) -> bool:
	return long_way_lock(cid) == ""


## Pay the toll / start the favour / open the travel link. Returns dialogue
## lines ([] when it can't be taken now). A day-long way arrives next morning
## (region_open settles it lazily); a 0-day way opens at once.
static func take_long_way(cid: String) -> Array:
	if not can_take_long_way(cid):
		return []
	var lw := long_way(cid)
	var cost: Dictionary = lw["cost"]
	if int(cost.get("money", 0)) > 0:
		GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) - int(cost["money"])  # spending: a plain subtraction
	var its: Dictionary = cost.get("items", {})
	for it: String in its:
		GameState.add_item(it, -int(its[it]))
	var day := int(GameState.run.get("day", 1))
	st()["long"][cid] = {"day": day, "due": day + int(lw.get("days", 1)), "done": false}
	var lines: Array = [{"who": who(cid), "text": str(lw["words"])}]
	var pic := str(lw.get("pic", "c16bp3_long_" + str(lw["region"])))
	if Art.has("ui", pic):
		lines[0]["pic"] = pic
	for stp in lw.get("steps", []):
		if str(stp) != "":
			lines.append({"who": "", "text": str(stp)})
	if int(lw.get("days", 1)) <= 0:
		lines.append_array(long_way_done(cid))
	else:
		lines.append({"text": "You're on the long way to %s. Sleep, and you'll be through by morning." % region_phrase(get_c(cid))})
	return lines


## The long way arrives: the region opens and its story flag is set exactly as a
## win does for access and story, with none of the win rewards or stars.
static func long_way_done(cid: String) -> Array:
	var c := get_c(cid)
	if c.is_empty():
		return []
	var reg := str(c["region"])
	var day := int(GameState.run.get("day", 1))
	var ls := long_state(cid)
	if ls.is_empty():
		ls = {"day": day, "due": day}
	ls["done"] = true
	ls["arrived"] = day
	st()["long"][cid] = ls
	st()["open"][reg] = true
	if not GameState.run.is_empty():
		if not (GameState.run.get("flags") is Dictionary):
			GameState.run["flags"] = {}
		GameState.run["flags"]["campaign_" + reg] = true
		GameState.run["flags"]["long_way_" + reg] = true
	return [{"text": "%s is open! You came the long way round. (The campaign is still there for its prizes.)" % region_phrase(c, true)}]


static func _long_settle(cid: String) -> void:
	if GameState.run.is_empty() or Net.visiting():
		return   # C17 P3 (c17_05-03): the long way arrives on your own clock, at home
	var ls := long_state(cid)
	if ls.is_empty() or bool(ls.get("done", false)):
		return
	if int(GameState.run.get("day", 1)) >= int(ls.get("due", 0)):
		long_way_done(cid)


## Retry the last node you lost on this campaign; easier = one assist step for
## that battle only (fewer foes and tickets, slower waves; the save's Difficulty
## never changes). With a map, launches the fight straight away. False when
## there's nothing to retry.
static func retry(cid: String, easier := false, m: GameMap = null) -> bool:
	if get_c(cid).is_empty() or is_won(cid):
		return false
	var s := cs(cid)
	var nid := str(s.get("last_lost", ""))
	if nid == "" or node(cid, nid).is_empty() or taken(cid, nid):
		return false
	if not (s.get("assist") is Dictionary):
		s["assist"] = {}
	if easier:
		s["assist"][nid] = mini(2, int(s["assist"].get(nid, 0)) + 1)
	if not linked(cid, str(s["at"]), nid):
		var sg := staging(cid, nid)
		if sg == "":
			return false
		s["at"] = sg
	if m != null:
		launch(m, cid, nid)
	return true


## Easier-retry steps on node nid (0..2).
static func assist(cid: String, nid: String) -> int:
	var a: Variant = cs(cid).get("assist", {})
	return clampi(int((a as Dictionary).get(nid, 0)), 0, 2) if a is Dictionary else 0


## The choices after a loss or a retreat: [[key, label], ...]; way out last.
static func loss_choices(cid: String) -> Array:
	var out: Array = []
	var s := cs(cid)
	var nid := str(s.get("last_lost", ""))
	if nid != "" and not taken(cid, nid) and not is_won(cid) and not Net.visiting():
		out.append(["retry", "Try again now"])
		if assist(cid, nid) < 2:
			out.append(["easier", "Try again, easier (this fight only)"])
	if not long_way(cid).is_empty() and not is_won(cid) and not long_way_taken(cid) and not long_way_pending(cid):
		var lk := long_way_lock(cid)
		out.append(["long", long_way_label(cid) if lk == "" else "The long way: " + lk])
	out.append(["board", "Back to the campaign map"])
	out.append(["leave", "Not now"])
	return out


# ---- the board -----------------------------------------------------------------

## A node's name in this run's arc (P5: shared campaigns carry "name_gangsters"; c16b_18-03).
static func node_name(cid: String, nid: String) -> String:
	var n := node(cid, nid)
	if arc() == "gangsters" and str(n.get("name_gangsters", "")) != "":
		return str(n["name_gangsters"])
	return str(n.get("name", nid))


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


## One guest guard for every campaign action (c16b_16-08): "" at home, else the toast.
static func guest_lock(what := "Campaigns") -> String:
	return "You're visiting a friend's farm. %s wait until you're home." % what if Net.visiting() else ""


static func march(cid: String, nid: String) -> bool:
	if guest_lock() != "" or not can_march(cid, nid):
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
	if guest_lock() != "":  # c16b_16-07: the board is read-only for guests
		return guest_lock()
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
	if guest_lock() != "":
		return [{"who": "", "text": guest_lock()}]
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


## C16b (P4 board): a held battle node can be fought again for stars and the rematch share.
static func can_rematch(cid: String, nid: String) -> bool:
	var n := node(cid, nid)
	if n.is_empty() or str(n.get("type", "")) in NONBATTLE or not taken(cid, nid):
		return false
	return guest_lock() == "" and not Net.visiting() and str(cfg(cid, nid).get("field", "")) != ""


## Fight a held node again (no base pay, no morale cost; Campaign.finish sees "rematch").
static func rematch(m: GameMap, cid: String, nid: String) -> bool:
	if m == null or not can_rematch(cid, nid):
		return false
	var fid := str(cfg(cid, nid).get("field", ""))
	var at := m.player.position - m.offset() if m.player else Vector2.ZERO
	st()["fight"] = {"cid": cid, "nid": nid, "field": fid, "rematch": true, "day": int(GameState.run.get("day", 1)), "back": [m.scene_id(), at.x, at.y]}
	var R: Dictionary = RegionData.region(fid)
	var sp: Array = R.get("spawn", [10, 10])
	m.go_to(fid, Vector2(float(sp[0]) * GameMap.TILE + 8, float(sp[1]) * GameMap.TILE + 8), "up")
	return true


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
	var asst := assist(cid, nid)  # easier retry (this fight only)
	if asst > 0:
		morale = maxi(morale, MORALE_START)  # a retry never starts worse than the first try
	d["assist"] = asst
	d["campaign"] = cid
	d["node"] = nid
	d["mode"] = typ
	d["title"] = "%s: %s" % [str(get_c(cid)["title"]), node_name(cid, nid)]
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
		et = maxi(10, int(et * Difficulty.mul("enemy_tickets") * [1.0, 0.85, 0.7][asst]))
	d["enemy_tickets"] = et
	d["supply"] = int(base.get("supply", 15)) + int(s.get("supply", 0))
	d["wave_every"] = float(n.get("wave_every", d.get("wave_every", 7.0))) * Difficulty.mul("wave_every") * [1.0, 1.15, 1.3][asst]
	d["enemy_cap"] = maxi(3, int(n.get("enemy_cap", d.get("enemy_cap", 14))) + Difficulty.add("enemy_cap") - [0, 2, 4][asst])
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
		d["convoy_hp"] = maxi(20, int(n.get("convoy_hp", 80)) + Difficulty.add("convoy") + 20 * asst)
		d["vehicle"] = str(cf.get("vehicle", "wagon" if arc() == "penguins" else "truck"))
	elif typ == "defend":
		d["win_by"] = "hold"
		d["hold"] = maxi(45, int(n.get("hold", 150)) + Difficulty.add("hold") - 20 * asst)
	var back: Array = f.get("back", [])
	if back.size() >= 3:
		d["back"] = [str(back[0]), float(back[1]) / GameMap.TILE, float(back[2]) / GameMap.TILE]
	return d


## A campaign battle ended. Applies morale/supply/rewards; returns dialogue lines.
static func finish(won: bool, supply_left: int) -> Array:
	if Net.visiting():
		return []   # C17 P3 (c17_05-02): no campaign progress or pay from a friend's world
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
	# Battle's stats (tickets, KO, losses, time) for the stars; the easier-retry step caps them (P4).
	var perf: Dictionary = (f.get("perf", {}) as Dictionary).duplicate() if f.get("perf") is Dictionary else {}
	if not perf.has("assist"):
		perf["assist"] = assist(cid, nid)
	if bool(f.get("rematch", false)):  # a rematch on held ground: the ladder pays (stars, rematch share), never the base reward
		if won:
			s["wins"] = int(s.get("wins", 0)) + 1
			if Engine.get_main_loop() is SceneTree:
				Music.instance(Engine.get_main_loop() as SceneTree).sfx("j_battle_won", "levelup")
			lines.append({"who": w, "text": "%s holds, and they know it now." % node_name(cid, nid)})
			lines.append_array(BattleRewards.on_win(cid, nid, int(f.get("stars", 0)), perf))
		else:
			lines.append({"who": w, "text": "They pushed us back this time, but %s is still ours. Nothing lost." % node_name(cid, nid)})
		return lines
	if won:
		s["taken"][nid] = true
		s["at"] = nid
		if s.get("assist") is Dictionary:
			(s["assist"] as Dictionary).erase(nid)
		if str(s.get("last_lost", "")) == nid:
			s.erase("last_lost")
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
		lines.append({"who": w, "text": ("%s is ours. The " + force_word() + " moves up. Morale %d (%s), supply ◇%d.") % [node_name(cid, nid), int(s["morale"]), morale_word(int(s["morale"])), int(s["supply"])]})
		if not got.is_empty():
			lines.append({"text": "+" + ", ".join(got)})
		var fl := flavour(cid, nid, true)
		if fl != "":
			lines.insert(1, {"who": w, "text": fl})
		if str(n.get("type", "")) == "gate":
			lines.append_array(_unlock(cid))
		lines.append_array(BattleRewards.on_win(cid, nid, int(f.get("stars", 0)), perf))  # C16b P4 hook: the one on_win call per win (Battle does not call it)
	else:
		s["losses"] = int(s.get("losses", 0)) + 1
		if not (s.get("lost") is Dictionary):
			s["lost"] = {}
		s["lost"][nid] = int(s["lost"].get(nid, 0)) + 1
		s["last_lost"] = nid
		st()["after_loss"] = cid  # reopen_later shows the loss card (retry / easier / long way)
		BattleRewards.on_loss(cid, nid)  # C16b P4 hook
		s["supply"] = clampi(maxi(10, supply_left / 3), 0, SUPPLY_CAP)  # never too poor to place one helper
		# The first loss on a node costs half: a retry never starts much worse than the first try.
		var ml := Difficulty.add("morale_loss")
		s["morale"] = int(s["morale"]) - (ml / 2 if int(s["lost"][nid]) == 1 else ml)
		if int(s["morale"]) <= 0:
			s["morale"] = 40
			s["supply"] = 0
			s["at"] = "n0"
			lines.append({"who": w, "text": "We're routed. Everyone back to %s to regroup. The ground we took is still ours." % node_name(cid, "n0")})
		else:
			var lf := flavour(cid, nid, false)
			if lf != "":
				lines.append({"who": w, "text": lf})
			lines.append({"who": w, "text": "We fall back from %s. Morale %d (%s). Try again, easier if you like, or take the long way round." % [node_name(cid, nid), int(s["morale"]), morale_word(int(s["morale"]))]})
	return lines


## Penguin-arc colour after a campaign fight (Tom C3): the Grumps were Crystopia
## crystals the Dark Crystal turned, so winning turns them back. Meow Pow Wow is
## only mentioned once Nova knows it. Gangster fights get their own lines.
static func flavour(cid: String, nid: String, won: bool) -> String:
	var n := node(cid, nid)
	var typ := str(n.get("type", ""))
	var i := absi(hash(cid + nid)) % 3
	if arc() != "penguins":  # c16b_14-05: the gang arc gets a story voice too (all ages: nobody hurt, nobody caught)
		if not won:
			return ["We regroup. Nobody's hurt, nobody's caught. We come back smarter.",
				"They had more cars than we had plans. Next time.",
				"Fall back to the cars. This street will still be here tomorrow."][i]
		if typ in ["boss", "gate"]:
			return "Their captain drives off and doesn't look back. One by one, the street lights come on."
		return ["The lookouts pile into their cars and leave. A shopkeeper flips her sign back to OPEN.",
			"Nobody on that block owes the President a cent tonight.",
			"Sal counts heads: everybody's here. Good."][i]
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
	if cid == "" or not all().has(cid) or bool(f.get("rematch", false)):  # walking off a rematch costs nothing
		return
	var s := cs(cid)
	s["retreats"] = int(s.get("retreats", 0)) + 1
	# Never worse than a loss (c16b_08-10).
	s["morale"] = maxi(10, int(s["morale"]) - maxi(5, Difficulty.add("morale_loss") - 5))
	s["supply"] = clampi(maxi(10, supply_left / 3), 0, SUPPLY_CAP)
	var nid := str(f.get("nid", ""))
	if nid != "" and not node(cid, nid).is_empty():
		s["last_lost"] = nid
	st()["after_loss"] = cid
	if Engine.get_main_loop() is SceneTree and not Net.visiting():
		reopen_later(Engine.get_main_loop() as SceneTree, cid)


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
	if Net.visiting():  # c16b_16-06: nothing a guest can do here
		return ("%s is held in your own story: open it from your own farm." % region_phrase(get_c(cid), true)).left(112)
	cid = first_in_chain(cid)
	var c := get_c(cid)
	if long_way_pending(cid):
		return ("On the long way to %s: sleep, and you'll be through by morning." % region_phrase(c)).left(112)
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
		if not long_way(cid).is_empty():  # C16b: never battle as the only way
			for ln in ["First: %s Then win \"%s\", or take the long way round." % [st, str(c["title"])],
					"First: %s Then win \"%s\", or take the long way." % [st, str(c["title"])],
					"Open %s: win \"%s\" (train first), or take the long way round at its border." % [region_phrase(c), str(c["title"])],
					"Open %s: win \"%s\", or take the long way round." % [region_phrase(c), str(c["title"])]]:
				if ln.length() <= 112:
					return ln
		for where in (["."] if has_map else [" (campaign map, MENU > Map).", " on the campaign map.", " (campaign map)."]):
			var line := "First: %s Then win \"%s\"%s" % [st, str(c["title"]), where]
			if line.length() <= 112:
				return line
		return ("First: %s (campaign map)" % st).left(112)
	var tail := "Open %s: win \"%s\" on the campaign map (MENU > Map)%s." % [region_phrase(c), str(c["title"]), held]
	var alt := "Open %s: win \"%s\" (MENU > Map), or take the long way round at its border%s." % [region_phrase(c), str(c["title"]), held]
	if alt.length() > 112:
		alt = "Open %s: win \"%s\" (MENU > Map), or take the long way round%s." % [region_phrase(c), str(c["title"]), held]
	if not long_way(cid).is_empty() and alt.length() <= 112:
		return alt
	return tail


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
	if can_visit(scene):   # C17 P3 (c17_05-01): follow the host past a border THEY opened, visit-only
		CampaignFollow.tell_once(m, scene)
		return false
	if Net.visiting():
		CampaignFollow.hook()   # no word from the host yet: ask (the next bump may pass)
	var now := PlayClock.ms()  # c16b_15-09: game time, like every gameplay timer
	if absi(now - _last_offer) > 1500 and not Dialogue.instance(m.get_tree()).active:
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
	# The long way (C16b): offered at the border once its campaign is the next one.
	var lcid := str(gw.get("cid", cid))
	var lway := not Net.visiting() and str(gw["stage"]) in ["after", "gather", "ready", "under_way", "train"] \
		and long_way_offerable(lcid)
	if (not bool(gw["board"]) and not lway) or Net.visiting():
		dl.say(lines)
		await dl.finished
		_last_offer = PlayClock.ms()
		return
	if lway:
		lines[lines.size() - 1]["text"] = str(lines[lines.size() - 1]["text"]) + (" Or skip the fighting: %s." % long_way_label(lcid).to_lower())
	var choices: Array = []
	if bool(gw["board"]):
		choices.append("Open the campaign map")
	if lway:
		choices.append(long_way_label(lcid))
	choices.append("Not now")
	lines[lines.size() - 1]["choice"] = choices
	lines[lines.size() - 1]["key"] = ""
	dl.say(lines)
	await dl.finished
	_last_offer = PlayClock.ms()
	if not is_instance_valid(m) or dl.last_choice < 0 or dl.last_choice >= choices.size():
		return
	var picked := str(choices[dl.last_choice])
	if picked == "Open the campaign map":
		CampaignScreen.open(m, lcid)
	elif lway and picked == long_way_label(lcid):
		var res := take_long_way(lcid)
		if res.is_empty():
			res = [{"who": "", "text": "The long way: " + long_way_lock(lcid)}]
		dl.say(res)
		await dl.finished
		_last_offer = PlayClock.ms()
		GameState.save()


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
		if cid != "" and str(st().get("after_loss", "")) == cid:
			loss_card(gm, cid)
			return
		CampaignScreen.open(gm, cid))


## After a loss or a retreat (c16b_08-03): Try again / Try again, easier / Take
## the long way / Back to the campaign map / Not now.
static func loss_card(m: GameMap, cid: String) -> void:
	st().erase("after_loss")
	if not is_instance_valid(m) or get_c(cid).is_empty():
		return
	var ch := loss_choices(cid)
	var w := who(cid)
	var t := ("We could try again, or there's a slower way round. Your call." if arc() == "penguins"
		else "We go again, or we go round. Your call, boss.")
	var labels: Array = []
	for c in ch:
		labels.append(str(c[1]))
	var dl := Dialogue.instance(m.get_tree())
	dl.say([{"who": w, "text": t, "choice": labels, "key": ""}])
	await dl.finished
	if not is_instance_valid(m):
		return
	var pick := dl.last_choice
	var key := str(ch[pick][0]) if pick >= 0 and pick < ch.size() else "leave"
	await loss_pick(m, cid, key)


## Carry out one loss-card choice (also used by tests).
static func loss_pick(m: GameMap, cid: String, key: String) -> void:
	match key:
		"retry", "easier":
			if not retry(cid, key == "easier", m) and is_instance_valid(m):
				CampaignScreen.open(m, cid)
		"long":
			var lines := take_long_way(cid)
			if lines.is_empty():
				lines = [{"who": "", "text": "The long way: " + long_way_lock(cid)}]
			if is_instance_valid(m):
				var dl := Dialogue.instance(m.get_tree())
				dl.say(lines)
				await dl.finished
				GameState.save()
		"board":
			if is_instance_valid(m):
				CampaignScreen.open(m, cid)
