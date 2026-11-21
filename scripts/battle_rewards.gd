class_name BattleRewards
## C16b P4: the battle reward ladder (contract section 3). Data data/battle_rewards.json
## (tools/gen_battle_rewards.py; never edit by hand). Battles are almost critical, never
## essential: everything here is a bonus on top of the campaign's own pay, nothing is
## story-required, and Difficulty never changes what you earn.
##
## Ladder: stars per battle node (1 win, 2 every ally standing, 3 also under par time),
## paid on rank-up only; once-a-day rematch pay; a first-clear chest + trophy on the gate;
## a mastery chest + piece (and three legacy uniques) when every node has 3 stars; a
## per-arc mastery track on total stars; battle bonds for allies in the line-up.
## State lives under the campaign state: run.campaign.ladder (no new run block).
##
## Campaign.finish calls on_win() for every won fight (and on_loss for a lost one); calling it
## twice for the same result pays nothing more (rank-ups pay deltas, rematch pay once a day,
## and never on the day of a win).

const STAR := "★"
const NO_STAR := "☆"

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/battle_rewards.json")
	return _d


static func camp(cid: String) -> Dictionary:
	return data().get("campaigns", {}).get(cid, {})


static func st() -> Dictionary:
	var s: Dictionary = Campaign.st()
	if not (s.get("ladder") is Dictionary):
		s["ladder"] = {}
	var l: Dictionary = s["ladder"]
	for k in ["stars", "first", "mastery", "rematch", "bonds", "track", "lost"]:
		if not (l.get(k) is Dictionary):
			l[k] = {}
	return l


static func gang() -> bool:
	return Campaign.arc() == "gangsters"


# ---- stars ---------------------------------------------------------------------------

## Earned stars for a node (0 = not won yet).
static func stars(cid: String, nid: String) -> int:
	return int((st()["stars"].get(cid, {}) as Dictionary).get(nid, 0)) if st()["stars"].get(cid) is Dictionary else 0


static func campaign_stars(cid: String) -> int:
	var t := 0
	for nid: String in camp(cid).get("nodes", {}):
		t += stars(cid, nid)
	return t


static func max_stars(cid: String) -> int:
	return int(camp(cid).get("max_stars", 0))


## Every campaign of this run's arc: [earned, max].
static func arc_stars() -> Array:
	var got := 0
	var mx := 0
	for cid: String in Campaign.for_arc():
		got += campaign_stars(cid)
		mx += max_stars(cid)
	return [got, mx]


static func par(cid: String, nid: String) -> float:
	return float(camp(cid).get("nodes", {}).get(nid, {}).get("par", 180))


## Stars a fight earned from Battle's stats: tickets_left, tickets_max, player_ko,
## allies_lost, elapsed (seconds of game time). No ticket stats: 1 star; no elapsed: at most 2.
static func stars_for(cid: String, nid: String, stats: Dictionary) -> int:
	var n := 1
	if not stats.has("tickets_left") or not stats.has("tickets_max"):
		return 1
	var tl := int(stats.get("tickets_left", 1))
	var tm := maxi(1, int(stats.get("tickets_max", 1)))
	if not bool(stats.get("player_ko", false)) and int(stats.get("allies_lost", 0)) == 0 and tl * 2 >= tm:
		n = 2
		if stats.has("elapsed") and float(stats["elapsed"]) <= par(cid, nid):
			n = 3
	return n


static func star_text(n: int, of := 3) -> String:
	return STAR.repeat(clampi(n, 0, of)) + NO_STAR.repeat(maxi(0, of - clampi(n, 0, of)))


## The three star goals in words (board card, brief, results).
static func goal_words(cid: String, nid: String) -> Array:
	return ["1" + STAR + " Win the battle.",
		"2" + STAR + " Keep everyone standing and half your tickets.",
		"3" + STAR + " Do that in under %s." % _mmss(par(cid, nid))]


static func _mmss(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]


# ---- chests ----------------------------------------------------------------------------

static func chest_name(kind: String) -> String:
	var ch: Dictionary = data().get("chests", {}).get(kind, {})
	return str(ch.get("name_gang" if gang() else "name", kind.capitalize()))


## The chest's icon for this arc (art/gen/ui/c16bp4_chest_<kind>_<pen|gang>, tools/slice_c16bp4.py).
static func chest_icon(kind: String) -> Texture2D:
	return Art.tex("ui", "c16bp4_chest_%s_%s" % [kind, "gang" if gang() else "pen"])


static func first_chest(cid: String) -> String:
	return str(camp(cid).get("first_clear", {}).get("chest", "supply"))


## Opens a chest at once: money + a material bundle (arc items swapped in) + a chance at
## a decor piece from the chest pool. Returns the short words of what it held.
static func open_chest(kind: String, m: Node = null) -> String:
	var ch: Dictionary = data().get("chests", {}).get(kind, {})
	if ch.is_empty():
		return ""
	var got: Array = []
	var money := int(ch.get("money", 0))
	if money > 0:
		GameState.add_money(money, "campaign")
		got.append(Money.amount(money))
	var items: Dictionary = (ch.get("items", {}) as Dictionary).duplicate()
	var ai: Dictionary = ch.get("arc_items", {}).get(Campaign.arc(), {})
	for k: String in ai:
		items[k] = int(items.get(k, 0)) + int(ai[k])
	for it: String in items:
		GameState.add_item(it, int(items[it]))
		got.append(ItemWords.count_id(it, int(items[it])))
	if randf() < float(ch.get("decor_chance", 0.0)):
		var id := DecorSources.roll_grant(m, str(ch.get("decor_pool", "")), 0.0, "campaign_chest")
		if id != "":
			got.append(DecorSources.name_of(id))
	return "%s: %s" % [chest_name(kind), ", ".join(got)]


# ---- the ladder ------------------------------------------------------------------------

## A won fight (contract section 3). stars 1-3 (0 or less: worked out from stats).
## Returns dialogue lines ({"text": ...}) for what the ladder paid; [] if nothing new.
static func on_win(cid: String, mission_id: String, stars_in: int, stats: Dictionary = {}, m: Node = null) -> Array:
	var cd := camp(cid)
	if cd.is_empty() or not cd.get("nodes", {}).has(mission_id):
		return []
	var nst := stars_in if stars_in > 0 else stars_for(cid, mission_id, stats)
	nst = clampi(nst, 1, 3)
	if int(stats.get("assist", 0)) > 0:  # P3's assist (easier retry): at most 2 stars
		nst = mini(nst, 2)
	var l := st()
	if not (l["stars"].get(cid) is Dictionary):
		l["stars"][cid] = {}
	var old := stars(cid, mission_id)
	var cr := int(cd["nodes"][mission_id].get("crystals", 0))
	var day := int(GameState.run.get("day", 1))
	var lines: Array = []
	var bits: Array = []
	if nst > old:
		var pay := 0
		for r in range(maxi(2, old + 1), nst + 1):
			pay += int(round(cr * float(data().get("star_pay", {}).get(str(r), 0.0))))
		if pay > 0:
			GameState.add_money(pay, "campaign")
			bits.append(Money.amount(pay))
		l["stars"][cid][mission_id] = nst
		if old > 0:
			GameState.add_xp("strategist", int(data().get("rematch", {}).get("xp_rank", 100)))
		lines.append({"text": "%s %s%s" % [star_text(nst), "New best! " if old > 0 else "", ("+" + ", ".join(bits)) if not bits.is_empty() else ""]})
		if nst == 3 and old < 3:
			lines.append({"text": "Three stars! " + open_chest(str(data().get("gold_node_chest", "supply")), m)})
		l["rematch"][cid + "/" + mission_id] = day  # a win today: a repeat call or rematch today pays no rematch share
	elif old > 0 and int(l["rematch"].get(cid + "/" + mission_id, -1)) != day:
		l["rematch"][cid + "/" + mission_id] = day
		var rp := int(round(cr * float(data().get("rematch", {}).get("share", 0.2))))
		if rp > 0:
			GameState.add_money(rp, "campaign")
		GameState.add_xp("strategist", int(data().get("rematch", {}).get("xp_win", 60)))
		lines.append({"text": "Rematch pay: %s. Today's rematch pay here is used up." % Money.amount(rp)})
	if l["lost"].has(cid + "/" + mission_id):
		l["lost"].erase(cid + "/" + mission_id)
		l["track"]["comeback"] = true
	var nd: Dictionary = Campaign.node(cid, mission_id)
	if str(nd.get("type", "")) == "gate" and not l["first"].has(cid):
		l["first"][cid] = day
		lines.append_array(_first_clear(cid, m))
	if not l["mastery"].has(cid) and campaign_stars(cid) >= max_stars(cid) and max_stars(cid) > 0:
		l["mastery"][cid] = day
		lines.append_array(_mastery(cid, m))
	lines.append_array(_track(m))
	return lines


## A lost fight: remembered so a later win can count as a comeback (achievement hook).
static func on_loss(cid: String, mission_id: String) -> void:
	if camp(cid).get("nodes", {}).has(mission_id) and stars(cid, mission_id) == 0:
		st()["lost"][cid + "/" + mission_id] = true


static func _first_clear(cid: String, m: Node) -> Array:
	var fc: Dictionary = camp(cid).get("first_clear", {})
	var out: Array = [{"text": "First clear! " + open_chest(str(fc.get("chest", "supply")), m)}]
	var tid := str(fc.get("trophy", ""))
	if tid != "" and DecorSources.grant(m, tid, 1, "campaign:" + cid):
		out.append({"text": "Trophy for your home: %s." % DecorSources.name_of(tid)})
	var bonded: Array = []
	var cap := int(data().get("bond_cap", 2))
	for r: Variant in CampaignGate.line_up():
		if not (r is Array) or (r as Array).is_empty():
			continue
		var id := str((r as Array)[0])
		var b := int(st()["bonds"].get(id, 0))
		if b < cap:
			st()["bonds"][id] = b + 1
			bonded.append(str((r as Array)[1]) if (r as Array).size() > 1 else id)
		if bonded.size() >= 4:
			break
	if not bonded.is_empty():
		out.append({"text": "Battle bond grows: %s." % ", ".join(bonded)})
	return out


static func _mastery(cid: String, m: Node) -> Array:
	var ms: Dictionary = camp(cid).get("mastery", {})
	var out: Array = [{"text": "Campaign mastered, every battle at three stars! " + open_chest(str(ms.get("chest", "commander")), m)}]
	var did := str(ms.get("decor", ""))
	if did != "" and DecorSources.grant(m, did, 1, "campaign_mastery:" + cid):
		out.append({"text": "Mastery piece: %s." % DecorSources.name_of(did)})
	var tool := str(ms.get("tool", {}).get(Campaign.arc(), ""))
	if tool != "" and not GameState.has_tool(tool):
		GameState.add_tool(tool)
		out.append({"text": "A legend's weapon is yours: %s." % GameState.item_name(tool)})
	return out


## Per-arc mastery track on total stars: thresholds pay strategist XP and money once.
static func _track(_m: Node) -> Array:
	var out: Array = []
	var got := int(arc_stars()[0])
	var claimed := int(st()["track"].get(Campaign.arc(), 0))
	var rows: Array = data().get("track", [])
	for i in range(claimed, rows.size()):
		var r: Dictionary = rows[i]
		if got < int(r.get("at", 0)):
			break
		st()["track"][Campaign.arc()] = i + 1
		GameState.add_money(int(r.get("money", 0)), "campaign")
		GameState.add_xp("strategist", int(r.get("xp", 0)))
		out.append({"text": "%d stars earned in all! Strategist reward: %s." % [int(r.get("at", 0)), Money.amount(int(r.get("money", 0)))]})
	return out


## Battle bond of an ally (0-2). Companion/Crew may add it to their battle rank (add-only).
static func bond(id: String) -> int:
	return int(st()["bonds"].get(id, 0))


static func comeback() -> bool:
	return bool(st()["track"].get("comeback", false))


# ---- words for the board and brief --------------------------------------------------------

## Region perks a campaign win gives (free travel links that name it in free_after).
static func perk_words(cid: String) -> String:
	var out: Array = []
	for l: Variant in TravelNet.all_links():
		if not (l is Dictionary):
			continue
		var fa: Variant = (l as Dictionary).get("free_after", {})
		if fa is Dictionary and str((fa as Dictionary).get("id", "")) == cid and TravelNet.link_arc_ok(l):
			var ld: Dictionary = l
			out.append("%s to %s" % [str(TravelNet.station(str(ld.get("a", ""))).get("name", "here")), str(TravelNet.station(str(ld.get("b", ""))).get("name", "there"))])
	if out.is_empty():
		return ""
	return "Free ride: " + ", ".join(out.slice(0, 2))


## What the board shows for a campaign (contract: BattleRewards.preview(cid) -> Array of lines).
static func preview(cid: String) -> Array:
	var cd := camp(cid)
	if cd.is_empty():
		return []
	var out: Array = []
	var fc: Dictionary = cd.get("first_clear", {})
	var tid := str(fc.get("trophy", ""))
	if not st()["first"].has(cid):
		out.append("First clear: %s + %s" % [chest_name(str(fc.get("chest", ""))), DecorSources.name_of(tid) if tid != "" else "a trophy"])
	else:
		out.append("First clear: earned")
	out.append("Stars %d/%d · 2%s and 3%s pay more, 3%s adds a %s" % [campaign_stars(cid), max_stars(cid), STAR, STAR, STAR, chest_name(str(data().get("gold_node_chest", "supply")))])
	var ms: Dictionary = cd.get("mastery", {})
	if st()["mastery"].has(cid):
		out.append("Mastery: earned")
	else:
		var bits: Array = [chest_name(str(ms.get("chest", "")))]
		if str(ms.get("decor", "")) != "":
			bits.append(DecorSources.name_of(str(ms["decor"])))
		var tool := str(ms.get("tool", {}).get(Campaign.arc(), ""))
		if tool != "":
			bits.append(GameState.item_name(tool))
		out.append("Mastery (all 3%s): %s" % [STAR, " + ".join(bits)])
	var pw := perk_words(cid)
	if pw != "":
		out.append(pw)
	return out


## One short line for a node card / brief: what winning this node gives from the ladder.
static func node_words(cid: String, nid: String) -> String:
	var cd := camp(cid)
	if cd.is_empty() or not cd.get("nodes", {}).has(nid):
		return ""
	var s := stars(cid, nid)
	if s == 0:
		return "Best: not won yet. More stars pay more."
	if s >= 3:
		var paid := int(st()["rematch"].get(cid + "/" + nid, -1)) == int(GameState.run.get("day", 1))
		return "Best %s. Rematch pay %s." % [star_text(s), "used today" if paid else Money.amount(int(round(int(cd["nodes"][nid].get("crystals", 0)) * float(data().get("rematch", {}).get("share", 0.2)))))]
	return "Best %s. Rematch for more stars." % star_text(s)
