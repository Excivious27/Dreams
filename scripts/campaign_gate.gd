class_name CampaignGate
extends RefCounted
## The lead-in to region campaigns. Nothing on the campaign map can be fought on
## day one: first the story (chapter 2 in each arc: Catkins teaches the Meow Pow
## Wow / you reach Hideout town), then a guided training drill with a veteran
## (Catkins or Sal; BattleDrill runs it), then per campaign a team of allies and
## the tier's provisions (battles.json "_campaigns" list[cid].need, written by
## tools/gen_battles.py). Mustering pays the provisions and turns them into the
## army's starting supply. Campaigns already under way in old saves are never
## re-locked.

const TRAINED := "bt_trained"
const FRIEND_HEARTS := 2   # villagers at this many hearts volunteer


static func drill_def() -> Dictionary:
	return GameState.load_json("res://data/battles.json").get("_campaigns", {}).get("drill", {})


static func trainer() -> String:
	return str(drill_def().get("who", {}).get(Campaign.arc(), "Catkins"))


# ---- story ------------------------------------------------------------------------

## Chapter 2 of the arc: Catkins has taught you (penguins) / you've reached
## Hideout town (gangsters).
static func story_ok() -> bool:
	if GameState.run.is_empty():
		return false
	if GameState.is_penguins():
		return GameState.run["flags"].has("meow_taught") or GameState.quest_done("cattopia")
	return GameState.quest_done("hideout") or GameState.run["flags"].has("hideout_seen")


static func story_need() -> String:
	if GameState.is_penguins():
		return "Reach chapter 2: find Catkins in the crystal meadow."
	return "Reach chapter 2: get through to Hideout town."


## Trained: the drill is done (old saves that already fought a campaign count).
static func trained() -> bool:
	if GameState.run.is_empty():
		return false
	if GameState.run["flags"].has(TRAINED):
		return true
	var s: Dictionary = GameState.run.get("campaign", {})
	if s is Dictionary and not (s.get("won", {}) as Dictionary).is_empty():
		return true
	if s is Dictionary:
		for cid: String in s.get("c", {}):
			if Campaign.started(cid):
				return true
	return false


# ---- the team ---------------------------------------------------------------------

## Everyone who would march with you: partners, crew, Marked friends, and
## villagers at FRIEND_HEARTS hearts or more. [[id, name, kind]]
static func team() -> Array:
	var out: Array = []
	var seen := {}
	if GameState.run.is_empty():
		return out
	for id in Companion.party().get("known", []):
		var cd: Dictionary = Companion.defs().get(str(id), {})
		if not seen.has(str(id)):
			seen[str(id)] = true
			out.append([str(id), str(cd.get("name", str(id).capitalize())), "partner"])
	if not GameState.is_penguins():
		for id in Crew.all_recruited():
			if not seen.has(str(id)):
				seen[str(id)] = true
				out.append([str(id), str(Crew.members()[id].get("name", str(id).capitalize())), "crew"])
	# C11b P6 (c11b_09-04): trained team animals muster before village friends, so they are fielded too.
	out.append_array(TeamAnimals.gate_rows())  # C11a P4: trained team animals muster too
	for r: Variant in out:
		seen[str((r as Array)[0])] = true
	var fr: Dictionary = GameState.run.get("friendship", {})
	for id: String in fr:
		if seen.has(id) or not GameState.npcs.has(id):
			continue
		if GameState.friend_hearts(id) >= FRIEND_HEARTS:
			seen[id] = true
			out.append([id, str(GameState.npcs[id].get("name", id.capitalize())), "friend"])
	return out


## C11b P6 (c11b_08-09): the battle line-up you picked on the battle card (ids, in pick order, at most
## LINE_MAX), kept in the campaign block. Empty = the muster order.
const LINE_MAX := 4


static func picked() -> Array:
	if GameState.run.is_empty():
		return []
	var c: Dictionary = Campaign.st()
	if not (c.get("line_up", null) is Array):
		c["line_up"] = []
	return c["line_up"]


## Tap a member on the battle card: in or out of the line-up. True when they're now in it.
static func toggle_pick(id: String) -> bool:
	var p := picked()
	if id in p:
		p.erase(id)
		return false
	if p.size() >= LINE_MAX:
		p.pop_front()  # full: the earliest pick makes room
	p.append(id)
	return true


## The team in fielding order: your picks first (those still on the team), then everyone else in
## muster order (partners, crew, team animals, friends).
static func line_up() -> Array:
	var all := team()
	var out: Array = []
	for id: Variant in picked():
		for r: Array in all:
			if str(r[0]) == str(id):
				out.append(r)
	for r: Array in all:
		if not r in out:
			out.append(r)
	return out


static func need(cid: String) -> Dictionary:
	return Campaign.get_c(cid).get("need", {})


static func team_short(cid: String) -> int:
	return maxi(0, int(need(cid).get("team", 0)) - team().size())


# ---- provisions -------------------------------------------------------------------

## What's still missing of the provisions: [[label, short]]; empty when you have it all.
static func provisions_short(cid: String) -> Array:
	var out: Array = []
	var nd := need(cid)
	var items: Dictionary = nd.get("items", {})
	for it: String in items:
		var miss := int(items[it]) - GameState.count(it)
		if miss > 0:
			out.append(["%d %s" % [miss, GameState.item_name(it)], miss])
	var cr := int(nd.get("crystals", 0)) - int(GameState.run.get("crystals", 0))
	if cr > 0:
		out.append(["◆%d" % cr, cr])
	return out


static func provisions_text(cid: String) -> String:
	var nd := need(cid)
	var bits: Array = []
	var items: Dictionary = nd.get("items", {})
	for it: String in items:
		bits.append("%d %s" % [int(items[it]), GameState.item_name(it)])
	if int(nd.get("crystals", 0)) > 0:
		bits.append("◆%d" % int(nd["crystals"]))
	return ", ".join(bits)


# ---- locks ------------------------------------------------------------------------

## "" when the story, training and team allow this campaign; else what to do.
## Campaigns already under way are never re-locked.
static func lock(cid: String) -> String:
	if Campaign.bypass or Campaign.started(cid) or Campaign.is_won(cid):
		return ""
	if not story_ok():
		return story_need()
	if not trained():
		return "Train with %s: open Training on the campaign map (Menu > Map)." % trainer()
	return ""


## What stands between you and mustering, as one sentence: allies and provisions
## ("Recruit 2 more allies and bring 12 Wood, ◆40."). "" when ready.
static func short_text(cid: String) -> String:
	if Campaign.bypass or Campaign.started(cid) or Campaign.is_won(cid):
		return ""
	var parts: Array = []
	var ts := team_short(cid)
	if ts > 0:
		parts.append("recruit %d more all%s" % [ts, "y" if ts == 1 else "ies"])
	var ps := provisions_short(cid)
	if not ps.is_empty():
		parts.append("bring " + ", ".join(ps.map(func(x: Array) -> String: return str(x[0]))))
	if parts.is_empty():
		return ""
	var s := " and ".join(parts) + "."
	return s.left(1).to_upper() + s.substr(1)


## A checklist for the board / list: [[done, text]].
static func checklist(cid: String) -> Array:
	var out: Array = []
	out.append([story_ok(), "Story: chapter 2" if story_ok() else story_need()])
	out.append([trained(), "Training with %s" % trainer()])
	var nd := need(cid)
	var tm := team().size()
	out.append([tm >= int(nd.get("team", 0)), "Team: %d/%d allies (partners, crew, friends at ♥%d)" % [mini(tm, int(nd.get("team", 0))), int(nd.get("team", 0)), FRIEND_HEARTS]])
	var ps := provisions_short(cid)
	out.append([ps.is_empty(), "Provisions: %s%s" % [provisions_text(cid), "" if ps.is_empty() else " (short " + ", ".join(ps.map(func(x: Array) -> String: return str(x[0]))) + ")"]])
	return out


## Pay the provisions and raise the army. Returns the line to show ("" if it can't).
static func muster(cid: String) -> String:
	if Campaign.started(cid) or Campaign.why_locked(cid) != "":
		return ""
	var nd := need(cid)
	var items: Dictionary = nd.get("items", {})
	for it: String in items:
		GameState.add_item(it, -int(items[it]))
	GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) - int(nd.get("crystals", 0))
	var s := Campaign.cs(cid)
	s["mustered"] = true
	s["supply"] = mini(Campaign.SUPPLY_CAP, int(s["supply"]) + int(nd.get("supply", 10)) + (20 if cid.begins_with("c_colony_") and Project.has("sky_lens") else 0))
	s["started"] = int(GameState.run.get("day", 1))
	GameState.add_xp("strategist", 20)
	return "%d allies answer the call: partners, crew, team animals and friends. The provisions are loaded: supply ◇%d. Pick a territory next to your camp and attack." % [team().size(), int(s["supply"])]


# ---- the drill ----------------------------------------------------------------------

## Can the drill be started now ("" yes, else why not)?
static func drill_lock() -> String:
	if not story_ok():
		return story_need()
	return ""


static func launch_drill(m: GameMap) -> void:
	var dd := drill_def()
	var fid := str(dd.get("field", "bf_orchard_line"))
	if m == null or drill_lock() != "":
		return
	var at := m.player.position - m.offset() if m.player else Vector2.ZERO
	Campaign.st()["fight"] = {"drill": true, "field": fid, "day": int(GameState.run.get("day", 1)), "back": [m.scene_id(), at.x, at.y]}
	var p0: Array = (dd.get("points", [])[0] as Dictionary).get("cell", [52, 74])
	m.go_to(fid, Vector2(float(p0[0]) * GameMap.TILE + 8, float(p0[1] + 3) * GameMap.TILE + 8), "up")


## The drill under way on this field ({} otherwise).
static func drill_for(field: String) -> Dictionary:
	var f: Dictionary = Campaign.st().get("fight", {})
	if f.is_empty() or not bool(f.get("drill", false)) or str(f.get("field", "")) != field:
		return {}
	return f


static func drill_data(base: Dictionary, f: Dictionary) -> Dictionary:
	var dd := drill_def()
	var d := base.duplicate(true)
	d["mode"] = "drill"
	d["drill"] = true
	d["title"] = "Training: First Muster"
	d["brief"] = "Three points, a few sleepy foes, and me talking you through it. Six steps, then you're ready to lead." if GameState.is_penguins() else "Three points, a couple of lookouts, and me in your ear. Six steps and you can run a crew in a fight."
	d["who"] = trainer()
	d["points"] = (dd.get("points", []) as Array).duplicate(true)
	d["enemies"] = dd.get("enemies", {}).get(Campaign.arc(), ["grump"])
	d["enemy_tier"] = 0
	d["tickets"] = 200
	d["tickets_max"] = 200
	d["enemy_tickets"] = 40
	d["supply"] = int(dd.get("supply", 40))
	d["wave_every"] = float(dd.get("wave_every", 9.0))
	d["enemy_cap"] = int(dd.get("enemy_cap", 3))
	d["reward"] = dd.get("reward", {})
	d.erase("boss")
	var back: Array = f.get("back", [])
	if back.size() >= 3:
		d["back"] = [str(back[0]), float(back[1]) / GameMap.TILE, float(back[2]) / GameMap.TILE]
	return d


## The drill ended: lines to show. A win trains you (and pays once).
static func drill_finish(won: bool) -> Array:
	Campaign.st()["fight"] = {}
	var who := trainer()
	if not won:
		return [{"who": who, "text": "That's alright. Nobody gets it first time. Come back to Training on the campaign map whenever you're ready."}]
	var first: bool = not GameState.run["flags"].has(TRAINED)
	GameState.run["flags"][TRAINED] = true
	var lines: Array = [{"who": who, "text": "That's the whole of it: take points, build, rally, spend supply, win. You're ready to lead."}]
	if first:
		var rw: Dictionary = drill_def().get("reward", {})
		GameState.add_money(int(rw.get("crystals", 0)), "campaign")
		var got: Array = ["◆%d" % int(rw.get("crystals", 0))]
		for it: String in rw.get("items", {}):
			GameState.add_item(it, int(rw["items"][it]))
			got.append("%s ×%d" % [GameState.item_name(it), int(rw["items"][it])])
		GameState.add_xp("strategist", 60)
		lines.append({"text": "Training complete! +" + ", ".join(got)})
		lines.append({"who": who, "text": "Campaigns need a team and provisions. Each one on the campaign map lists what it asks. Gather them, muster, and march."})
		GameState.add_hint("Campaigns: each one asks for allies (partners, crew, friends at ♥%d) and provisions. Muster on the campaign map (Menu > Map)." % FRIEND_HEARTS)
	return lines


static func drill_quit() -> void:
	Campaign.st()["fight"] = {}


# ---- goal line ----------------------------------------------------------------------

## The next lead-in step for campaign cid, for the goal line ("" when it can be fought).
static func next_step(cid: String) -> String:
	var l := lock(cid)
	if l != "":
		return l
	return short_text(cid)
