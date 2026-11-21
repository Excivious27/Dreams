class_name Chores
## Chores (CONDUCT 11a P4, helper automation base). Named "Chores" to keep clear of battle
## HelperUnit / _helper_kinds / helper_hp. You assign a worker to one overnight farm chore from
## Menu > Party > Chores; GameState.sleep calls Chores.overnight(report) before crops grow.
##   workers: "pup", "animal:<ranch uid>" (team animals, chores opened by their lessons),
##            "crew:<id>" (gangster arc, not while on an HQ crew job), "partner:<id>"
##   chores:  water, harvest (to a chest), feed, pet, forage (to a chest)
## Each worker has energy a night (data workers[kind].energy); a chore unit costs chores[id].energy;
## units = base + per_level * (level - 1), capped by energy and max_units. Workers earn chore xp
## (levels 1..max_level, data levels). The player gets a little Leadership xp (rules.lead_xp_cap).
## State run["chores"] = {assign: {wkey: {chore, chest}}, xp: {wkey: {chore: xp}}, last: [lines]}.
## C11b (P5): helper spots (slots), a nightly value cap, worker energy from bond + chore level,
## two chores a night for strong workers, forage regions, feed with real hay, helper pet share.
## Data: data/helpers.json from tools/gen_helpers.py (edit that).

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/helpers.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
		for k in ["chores", "workers", "rules"]:
			if not _data.has(k):
				_data[k] = {}
		if not _data.has("levels"):
			_data["levels"] = []
	return _data


static func chore(id: String) -> Dictionary:
	return (data()["chores"] as Dictionary).get(id, {})


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("chores", null) is Dictionary):
		r["chores"] = {}
	var d: Dictionary = r["chores"]
	for k in ["assign", "xp"]:
		if not (d.get(k, null) is Dictionary):
			d[k] = {}
	if not (d.get("last", null) is Array):
		d["last"] = []
	return d


static func unlocked() -> bool:
	return not GameState.run.is_empty() and int(GameState.run.get("day", 1)) >= int((data()["rules"] as Dictionary).get("unlock_day", 8))


static func kind_of(wkey: String) -> String:
	return wkey.split(":")[0]


## Everyone who could work: [[wkey, name, kind]].
static func workers() -> Array:
	var out: Array = []
	if GameState.run.is_empty():
		return out
	out.append(["pup", Pet.name_of(), "pup"])
	for uid: String in TeamAnimals.team():
		out.append(["animal:" + uid, TeamAnimals.name_of(uid), "animal"])
	if not GameState.is_penguins():
		for id in Crew.all_recruited():
			out.append(["crew:" + str(id), str(Crew.members().get(id, {}).get("name", str(id).capitalize())), "crew"])
	for id in Companion.party().get("known", []):
		out.append(["partner:" + str(id), str(Companion.defs().get(str(id), {}).get("name", str(id).capitalize())), "partner"])
	for i in int(GameState.ranch_bonus("hand_slot")):  # Ranching: Farm Hand / Second Farm Hand
		out.append(["hand:%d" % (i + 1), "Farm Hand %d" % (i + 1), "hand"])
	return out


static func name_of(wkey: String) -> String:
	for w: Array in workers():
		if str(w[0]) == wkey:
			return str(w[1])
	return wkey


## Chores this worker may take.
static func chores_for(wkey: String) -> Array:
	var kind := kind_of(wkey)
	var allowed: Array = ((data()["workers"] as Dictionary).get(kind, {}) as Dictionary).get("chores", [])
	if kind == "animal":
		var opened := TeamAnimals.chores_for(wkey.substr(7))
		return allowed.filter(func(c: Variant) -> bool: return str(c) in opened)
	return allowed.duplicate()


## Why this worker can't work tonight ("" = it can).
static func why_idle(wkey: String) -> String:
	match kind_of(wkey):
		"pup":
			if Pet.resting():
				return "%s is resting tonight." % Pet.name_of()
		"animal":
			var uid := wkey.substr(7)
			if Ranch.animal(uid).is_empty() or not TeamAnimals.on_team(uid):
				return "Not on the team any more."
		"crew":
			if (GameState.run.get("crew_jobs", {}) as Dictionary).has(wkey.substr(5)):
				return "Busy on an HQ job."
			if not Crew.recruited(wkey.substr(5)):
				return "Not in the crew."
		"partner":
			if not str(wkey.substr(8)) in (Companion.party().get("known", []) as Array):
				return "Not in the party."
	return ""


## run.chores schema version (Chores.migrate, called from GameState._migrate).
const VER := 1


## Old saves: fill the run.chores shape, drop broken assignment rows, give rows a chest and a place.
static func migrate() -> void:
	var d := st()
	if int(d.get("ver", 0)) >= VER:
		return
	var a: Dictionary = d["assign"]
	for wk in a.keys():
		if not (a[wk] is Dictionary) or str((a[wk] as Dictionary).get("chore", "")) == "":
			a.erase(wk)
			continue
		var row: Dictionary = a[wk]
		if str(row.get("chest", "")) == "":
			row["chest"] = "chest"
		if str(row.get("where", "")) == "":
			row["where"] = "edges"
	for wk in (d["xp"] as Dictionary).keys():
		if not (d["xp"][wk] is Dictionary):
			(d["xp"] as Dictionary).erase(wk)
	d["ver"] = VER


## Guard-chore watch circles for GameState._crows: one per worker on the guard chore, at the pen of a
## built animal home (spread over the homes), radius 6 + 2 per guard level.
static func guard_cells() -> Array:
	var out: Array = []
	if GameState.run.is_empty() or GameState.visiting():
		return out
	var homes: Array = []
	for h: String in (Ranch.data()["buildings"] as Dictionary):
		if Ranch.tier(h) >= 1:
			homes.append(h)
	if homes.is_empty():
		return out
	var i := 0
	for wk: String in (st()["assign"] as Dictionary):
		var row: Dictionary = st()["assign"][wk]
		if str(row.get("chore", "")) != "guard" and str(row.get("chore2", "")) != "guard":
			continue
		var pen := RanchFarm.pen_of(str(homes[i % homes.size()]), Rect2i(30, 10, 2, 2))
		out.append({"c": pen.get_center(), "r": 6.0 + 2.0 * level(wk, "guard")})
		i += 1
	return out


static func assignment(wkey: String) -> Dictionary:
	return (st()["assign"] as Dictionary).get(wkey, {})


## Chest keys a chore can fill: the farm chest, the shed, placed chests that exist.
static func chests() -> Array:
	var out: Array = ["chest"]
	var have: Dictionary = GameState.run.get("chests", {})
	for k in (data()["rules"] as Dictionary).get("chests", ["chest", "shed"]):
		if not str(k) in out and have.has(str(k)):
			out.append(str(k))
	var placed: Array = []
	for k in have:
		if str(k).begins_with("p:"):
			placed.append(str(k))
	placed.sort()
	return out + placed


static func chest_name(key: String) -> String:
	match key:
		"chest":
			return "farm chest"
		"shed":
			return "shed"
	return Storage.label(key)  # C11b P3: "Chest 2 (by the barn)" / "Chest 3 (in the house)"


## Assign (chore "" = rest). Returns "" or why not.
static func assign(wkey: String, chore_id: String, chest := "chest") -> String:
	if GameState.visiting():
		return "Chores are for your own farm."
	if chore_id == "":
		unassign(wkey)
		return ""
	if not unlocked():
		return "Chores open after your first week."
	if not chore_id in chores_for(wkey):
		return "%s can't do that chore." % name_of(wkey)
	var a: Dictionary = st()["assign"]
	if not a.has(wkey) and _counts(wkey) and busy_slots() >= slots():
		return "All %d helper spots are busy: build the Ranch Hand Hut for more." % slots() if slots() < int((data()["rules"] as Dictionary).get("slots_max", 6)) else "All %d helper spots are busy." % slots()
	var old: Dictionary = a.get(wkey, {})
	var row := {"chore": chore_id, "chest": chest if chest in chests() else "chest", "where": str(old.get("where", "edges"))}
	if str(old.get("chore2", "")) != "" and str(old["chore2"]) != chore_id and two_chores(wkey):
		row["chore2"] = str(old["chore2"])
	a[wkey] = row
	return ""


## The second chore of a two-chore worker ("" = none).
static func assign2(wkey: String, chore_id: String) -> String:
	var a: Dictionary = st()["assign"]
	if not a.has(wkey):
		return "Give %s a first chore." % name_of(wkey)
	if chore_id == "":
		(a[wkey] as Dictionary).erase("chore2")
		return ""
	if not two_chores(wkey):
		return "%s needs more energy for two chores." % name_of(wkey)
	if not chore_id in chores_for(wkey) or chore_id == str((a[wkey] as Dictionary).get("chore", "")):
		return "%s can't do that chore." % name_of(wkey)
	(a[wkey] as Dictionary)["chore2"] = chore_id
	return ""


## Where a forager goes (an id from forage_regions()).
static func set_where(wkey: String, where: String) -> void:
	var a: Dictionary = st()["assign"]
	if a.has(wkey) and where in forage_regions():
		(a[wkey] as Dictionary)["where"] = where


static func unassign(wkey: String) -> void:
	if GameState.run.is_empty():
		return
	(st()["assign"] as Dictionary).erase(wkey)


static func xp(wkey: String, chore_id: String) -> int:
	return int(((st()["xp"] as Dictionary).get(wkey, {}) as Dictionary).get(chore_id, 0))


static func level(wkey: String, chore_id: String) -> int:
	var lv := 1
	for need in (data()["levels"] as Array):
		if xp(wkey, chore_id) >= int(need):
			lv += 1
	return mini(lv, int(data().get("max_level", 5)))


## Bond steps for a worker's energy (c11b_06-07): pup level, the rank of the lesson that opens the
## chore (+ half the animal's hearts), crew loyalty hearts, partner friendship hearts.
static func bond_steps(wkey: String, chore_id := "") -> int:
	match kind_of(wkey):
		"pup":
			return maxi(0, GameState.skill_level("pup") - 1)
		"animal":
			var uid := wkey.substr(7)
			var r := 0
			for lid: String in TeamAnimals.learned(uid):
				if chore_id == "" or str(TeamAnimals.lesson(lid).get("chore", "")) == chore_id:
					r = maxi(r, TeamAnimals.rank(uid, lid))
			return r + TeamAnimals.hearts(uid) / 2
		"crew":
			return Crew.loyalty(wkey.substr(5))
		"partner":
			return GameState.friend_hearts(wkey.substr(8))
	return 0


## A worker's energy for a night (kind base + bond, capped; + chore levels when a chore is named).
static func energy(wkey: String, chore_id := "") -> int:
	var kind := kind_of(wkey)
	var w: Dictionary = (data()["workers"] as Dictionary).get(kind, {})
	var b: Dictionary = (data().get("bond", {}) as Dictionary).get(kind, {})
	var e := int(w.get("energy", 0)) + mini(int(b.get("cap", 0)), int(b.get("per", 0)) * bond_steps(wkey, chore_id))
	if chore_id != "":
		e += int(data().get("level_energy", 2)) * (level(wkey, chore_id) - 1)
	return e


## Energy one unit of a chore costs at this worker's level (levels make it cheaper, floor 1).
static func unit_cost(wkey: String, chore_id: String, where := "") -> float:
	var c := chore(chore_id)
	var cost := float(c.get("energy", 1)) * (1.0 - float(data().get("level_discount", 0.1)) * (level(wkey, chore_id) - 1))
	if chore_id == "forage":
		cost *= float(forage_region(where).get("energy_mult", 1.0))
	return maxf(1.0, cost)


## May this worker take a second chore a night (energy split between the two)?
static func two_chores(wkey: String) -> bool:
	return energy(wkey) >= int(data().get("second_chore_energy", 24))


## Work units a worker can do of a chore tonight (level, then energy and the cap). share: energy part (0.5 with two chores).
static func units(wkey: String, chore_id: String, share := -1.0, where := "") -> int:
	var c := chore(chore_id)
	if c.is_empty():
		return 0
	if share < 0.0:
		var asg := assignment(wkey)
		share = 0.5 if str(asg.get("chore2", "")) != "" and chore_id in [str(asg.get("chore", "")), str(asg.get("chore2", ""))] else 1.0
		if where == "":
			where = str(asg.get("where", ""))
	var by_level := int(c.get("base", 1)) + int(c.get("per_level", 0)) * (level(wkey, chore_id) - 1)
	if chore_id in ["feed", "pet", "guard"]:
		by_level = int(round(by_level * (1.0 + GameState.ranch_bonus("hand_work"))))  # Ranching: more ranch chores
	var by_energy := int(floor(energy(wkey, chore_id) * share / unit_cost(wkey, chore_id, where)))
	return clampi(mini(by_level, by_energy), 0, int(data().get("max_units", 20)))


# ---- helper spots, night value cap, forage regions (C11b) ---------------------------

## Helper spots (c11b_06-08): by progress tier, + the Ranch Hand Hut tier, capped. Farm Hands don't count.
static func slots() -> int:
	var r: Dictionary = data()["rules"]
	var by: Array = r.get("slots_by_tier", [2, 2, 3, 4, 5])
	var n := int(by[clampi(GameState.progress_tier(), 0, by.size() - 1)]) if not by.is_empty() else 2
	n += Builds.built_tier(str(r.get("slots_hut", "hand_hut")))
	return mini(n, int(r.get("slots_max", 6)))


static func _counts(wkey: String) -> bool:
	return kind_of(wkey) != "hand"


static func busy_slots(except := "") -> int:
	var n := 0
	for k: String in (st()["assign"] as Dictionary):
		if k != except and _counts(k):
			n += 1
	return n


## The most a night of chores may put into chests (c11b_12-01).
static func night_cap() -> int:
	var caps: Array = (data()["rules"] as Dictionary).get("night_value_cap", [150, 300, 600, 1000, 1500])
	return int(caps[clampi(GameState.progress_tier(), 0, caps.size() - 1)]) if not caps.is_empty() else 1000


static func forage_region(id: String) -> Dictionary:
	for r: Dictionary in (data().get("forage_regions", []) as Array):
		if str(r.get("id", "")) == id:
			return r
	return {"id": "edges", "pool": "", "visit": "", "arc": "", "name": "the farm edges", "name_gang": "the lot edges", "energy_mult": 1.0}


## Forage places open to this save (the edges, plus regions of this arc you have been to).
static func forage_regions() -> Array:
	var out: Array = []
	var vis: Dictionary = GameState.run.get("visited", {})
	var arc := "penguins" if GameState.is_penguins() else "gangsters"
	for r: Dictionary in (data().get("forage_regions", []) as Array):
		var ra := str(r.get("arc", ""))
		if ra != "" and ra != arc:
			continue
		var v := str(r.get("visit", ""))
		if v != "" and not vis.has(v):
			continue
		if region_name(str(r.get("id", ""))) == "":
			continue
		out.append(str(r.get("id", "")))
	if out.is_empty():
		out.append("edges")
	return out


static func region_name(id: String) -> String:
	var r := forage_region(id)
	var gang := not GameState.is_penguins()
	var n := str(r.get("name_gang", "")) if gang else str(r.get("name", ""))
	return n


## A chore's name in this arc ("Forage" says where).
static func chore_name(cid: String, where := "") -> String:
	if cid == "forage":
		return "Forage %s" % region_name(where if where != "" else "edges")
	return str(chore(cid).get("name", cid))


## One chore sound (c11b_14-06): rate-capped and silent when far (dist px from the player).
static var _cue_t := -1000.0


static func play_cue(tree: SceneTree, cid: String, dist := 0.0, kind := "") -> bool:
	var r: Dictionary = data()["rules"]
	if tree == null or dist > float(r.get("cue_dist", 170.0)):
		return false
	var now := PlayClock.now()
	if now - _cue_t < float(r.get("cue_gap", 1.5)):
		return false
	_cue_t = now
	var cues: Array = chore(cid).get("sfx", ["pickup"])
	var first := str(cues[0]) if not cues.is_empty() else "pickup"
	var fb := str(cues[1]) if cues.size() > 1 else "pickup"
	if first == "voice":
		RanchVoice.say(tree, kind if kind != "" else "chicken", "happy")
	else:
		Music.instance(tree).sfx_chain([first, fb, "pickup"])
	return true


## A world-to-chest put (nothing leaves the bag). Returns how many fit.
static func put(key: String, id: String, n: int) -> int:
	if n <= 0 or not GameState.items.has(id):
		return 0
	n = mini(n, Storage.room_for(key, id))
	if n <= 0:
		return 0
	var b := Storage.box(key)
	b["items"][id] = Storage.amount(key, id) + n
	return n


# ---- overnight ---------------------------------------------------------------------

## Runs every assigned chore (GameState.sleep, before crops grow). Lines go to report["chores"].
## C11b: only slots() helpers work (Farm Hands don't count), two-chore workers split their energy,
## and everything put into chests in a night is capped at night_cap() in value (c11b_12-01).
static var _budget := 0


static func overnight(report: Dictionary) -> Array:
	var lines: Array = []
	if GameState.run.is_empty() or not unlocked() or GameState.visiting():
		return lines
	var a: Dictionary = st()["assign"]
	var keys: Array = a.keys()  # assignment order decides who gets a helper spot
	var spots := slots()
	var used := 0
	var on: Array = []
	for wkey: String in keys:
		if not _counts(wkey):
			on.append(wkey)
			continue
		if used < spots:
			on.append(wkey)
			used += 1
		else:
			lines.append("%s: no helper spot free tonight." % name_of(wkey))
	# Water first, then harvest, so a harvest never takes a bed a waterer just did.
	var order := ["water", "feed", "pet", "guard", "harvest", "forage", "fish", "mine"]
	var jobs: Array = []  # [wkey, chore, share]
	for wkey: String in on:
		var as_: Dictionary = a[wkey]
		var c1 := str(as_.get("chore", ""))
		var c2 := str(as_.get("chore2", ""))
		if c2 != "" and not two_chores(wkey):
			as_.erase("chore2")
			c2 = ""
		jobs.append([wkey, c1, 0.5 if c2 != "" else 1.0])
		if c2 != "":
			jobs.append([wkey, c2, 0.5])
	jobs.sort_custom(func(x: Array, y: Array) -> bool:
		var ox := order.find(str(x[1]))
		var oy := order.find(str(y[1]))
		return ox < oy if ox != oy else str(x[0]) < str(y[0]))
	_budget = night_cap()
	var capped := false
	var did_any := 0
	var told_idle := {}
	for j: Array in jobs:
		var wkey := str(j[0])
		if not a.has(wkey):
			continue
		var as_: Dictionary = a[wkey]
		var cid := str(j[1])
		var who := name_of(wkey)
		var idle := why_idle(wkey)
		if idle != "":
			if idle.begins_with("Not "):
				a.erase(wkey)  # gone from the team/crew/party: free the slot
			elif not told_idle.has(wkey):
				told_idle[wkey] = true
				lines.append("%s: %s" % [who, idle])
			continue
		if not cid in chores_for(wkey):
			if cid == str(as_.get("chore2", "")):
				as_.erase("chore2")
			else:
				a.erase(wkey)
			continue
		var where := str(as_.get("where", "edges"))
		var n := units(wkey, cid, float(j[2]), where)
		var res := _do(cid, n, str(as_.get("chest", "chest")), where, wkey)
		if bool(res.get("capped", false)):
			capped = true
		var done := int(res.get("done", 0))
		if done > 0:
			did_any += done
			var xd: Dictionary = (st()["xp"] as Dictionary).get(wkey, {})
			var lv0 := level(wkey, cid)
			xd[cid] = int(xd.get(cid, 0)) + done * int(chore(cid).get("xp", 1))
			(st()["xp"] as Dictionary)[wkey] = xd
			var ln := "%s %s %s." % [who, str(chore(cid).get("verb", cid)), str(res.get("what", ""))]
			if level(wkey, cid) > lv0:
				ln += " (%s level %d!)" % [chore_name(cid, where).to_lower(), level(wkey, cid)]
			lines.append(ln)
		elif str(res.get("why", "")) != "":
			lines.append("%s: %s" % [who, str(res["why"])])
	if capped:
		lines.append("The helpers did all they could carry tonight: the rest waits for you.")
	if did_any > 0:
		GameState.add_xp("leadership", mini(did_any, int((data()["rules"] as Dictionary).get("lead_xp_cap", 4))))
	st()["last"] = lines.duplicate()
	if not lines.is_empty():
		report["chores"] = lines
	return lines


## Value an item put into a chest uses from tonight's cap (true = it may go in).
static func _spend(id: String) -> bool:
	var v := maxi(0, GameState.item_value(id))
	if v > _budget:
		return false
	_budget -= v
	return true


## One hay for a helper feed (c11b_06-01): the animal's house trough, then the silo, then the chest.
static func _take_hay(uid: String, chest: String) -> bool:
	var h := Ranch.house(str(Ranch.animal(uid).get("home", "")))
	if int(h.get("hay", 0)) > 0:
		h["hay"] = int(h["hay"]) - 1
		return true
	if Builds.silo_hay() > 0:
		GameState.run["silo"] = Builds.silo_hay() - 1
		return true
	for key: String in [chest, "chest"]:
		if key in chests() and Storage.amount(key, "hay") > 0:
			var b := Storage.box(key)
			var left := Storage.amount(key, "hay") - 1
			if left > 0:
				b["items"]["hay"] = left
			else:
				(b["items"] as Dictionary).erase("hay")
			return true
	return false


## A helper's company (c11b_06-12): a share of a pet's friendship; sets last_helper_pet, so your own
## pet still counts the same day (Ranch.overnight treats either as petted).
static func pet_helper(uid: String, share: float) -> bool:
	var an := Ranch.animal(uid)
	var day := int(GameState.run.get("day", 1))
	if an.is_empty() or int(an.get("last_helper_pet", -1)) == day or int(an.get("last_pet", -1)) == day:
		return false
	an["last_helper_pet"] = day
	Ranch._friend_add(an, int(round(float(Ranch.rule("pet_friend", 30)) * share)))
	return true


static func _do(cid: String, n: int, chest: String, where := "edges", wkey := "") -> Dictionary:
	if n <= 0:
		return {"done": 0, "why": "too tired for that chore."}
	if not chest in chests():
		chest = "chest"
	match cid:
		"water":
			if GameState.sky_waters():
				return {"done": 0, "why": "the sky watered everything tonight."}
			var k := 0
			for key in _beds():
				var t: Dictionary = GameState.run["farm"][key]
				if k >= n:
					break
				var wcd: Dictionary = GameState.crops.get(str(t.get("crop", "")), {})
				if wcd.is_empty() or int(t.get("days", 0)) >= int(wcd.get("days", 99)):
					continue  # ripe beds wait for the harvest, not the can
				if not bool(t.get("watered", false)):
					t["watered"] = true
					k += 1
			return {"done": k, "what": "%d crop%s" % [k, "" if k == 1 else "s"], "why": "" if k > 0 else "every crop was already watered."}
		"harvest":
			var k := 0
			var full := false
			var capped := false
			for key in _beds():
				if k >= n:
					break
				var t: Dictionary = GameState.run["farm"][key]
				var cd: Dictionary = GameState.crops.get(str(t.get("crop", "")), {})
				if cd.is_empty() or int(t.get("days", 0)) < int(cd.get("days", 99)):
					continue
				var yid := str(cd.get("yield", ""))
				if Storage.room_for(chest, yid) <= 0:
					full = true
					break
				if not _spend(yid):
					capped = true
					break
				put(chest, yid, 1)
				var rr := GameState.reap_tile(t)  # c11b_06-03: the one bed reset (fert, chaff to the silo, regrow/clear, log)
				if int(rr.get("hay", 0)) > 0:
					put(chest, "hay", int(rr["hay"]))  # no silo room: the chaff's hay goes in the chest
				GameState.add_xp("farming", int(rr.get("xp_share", 0)))
				t["acc"] = 0.0
				t["watered"] = false
				k += 1
			var why := ("the %s is full." % chest_name(chest)) if full else ("" if capped else "nothing was ripe.")
			return {"done": k, "capped": capped, "what": "%d crop%s into the %s" % [k, "" if k == 1 else "s", chest_name(chest)], "why": "" if k > 0 else why}
		"feed", "pet", "guard":
			var k := 0
			var no_hay := false
			var day := int(GameState.run.get("day", 1))
			var uids: Array = Ranch.animals().keys()
			uids.sort()
			var share := float((data()["rules"] as Dictionary).get("guard_pet_share" if cid == "guard" else "helper_pet_share", 0.5))
			for uid: String in uids:
				if k >= n:
					break
				if cid == "feed":
					# c11b_06-01: through Ranch.feed; bees and flower-eaters aren't fed hay, hay comes from somewhere.
					if not Ranch.needs_hay(uid) or Ranch.fed_today(uid, day):
						continue
					if not _take_hay(uid, chest):
						no_hay = true
						break
					if Ranch.feed(uid, "helper", day):
						k += 1
				elif pet_helper(uid, share):
					k += 1
			var what := "%d animal%s" % [k, "" if k == 1 else "s"]
			var why := "no animals needed it." if not Ranch.animals().is_empty() else "there are no animals yet."
			if no_hay:
				why = "no hay in the troughs, silo or %s." % chest_name(chest)
			return {"done": k, "what": what + (" (then the hay ran out)" if no_hay and k > 0 else ""), "why": "" if k > 0 else why}
		"forage":
			var reg := forage_region(where)
			var pool_key := str(reg.get("pool", ""))
			var pool: Array = []
			if pool_key == "":
				pool = ((data()["rules"] as Dictionary).get("forage" if GameState.is_penguins() else "forage_gang", {}) as Dictionary).get(GameState.season(), [])
				pool = pool.filter(func(i: Variant) -> bool: return GameState.items.has(str(i)))
				if pool.is_empty():
					return {"done": 0, "why": "nothing to forage this season."}
			var got := {}
			var k := 0
			var capped := false
			for i in n:
				var id := str(pool[randi() % pool.size()]) if pool_key == "" else GameState.roll_forage(pool_key)
				if not GameState.items.has(id) or Storage.room_for(chest, id) <= 0:
					break
				if not _spend(id):
					capped = true
					break
				put(chest, id, 1)
				got[id] = int(got.get(id, 0)) + 1
				k += 1
			var parts: Array = []
			for id: String in got:
				parts.append(ItemWords.count_id(id, int(got[id])))
			var place := region_name(where)
			return {"done": k, "capped": capped, "what": "%s at %s into the %s" % [", ".join(parts), place, chest_name(chest)], "why": "" if k > 0 or capped else "the %s is full." % chest_name(chest)}
		"fish", "mine":
			var pool := chore_pool(cid, wkey)
			if pool.is_empty():
				return {"done": 0, "why": "nobody has been down the mine yet." if cid == "mine" else "nothing biting."}
			var got := {}
			var k := 0
			var capped := false
			for i in n:
				var id := str(pool[randi() % pool.size()])
				if not GameState.items.has(id) or Storage.room_for(chest, id) <= 0:
					break
				if not _spend(id):
					capped = true
					break
				put(chest, id, 1)
				got[id] = int(got.get(id, 0)) + 1
				k += 1
			var parts: Array = []
			for id: String in got:
				parts.append(ItemWords.count_id(id, int(got[id])))
			return {"done": k, "capped": capped, "what": "%s into the %s" % [", ".join(parts), chest_name(chest)], "why": "" if k > 0 or capped else "the %s is full." % chest_name(chest)}
	return {"done": 0}


## C16a P6 (c16a_13-11): what a fish / mine chore can bring back for this worker.
## Fish: the farm pond's commons (value <= Fishing cheap_value), and from chore level fish_rare_level
## the cheaper half of the whole pool. Mine: ore from floors up to half your deepest floor.
static func chore_pool(cid: String, wkey := "") -> Array:
	var r: Dictionary = data()["rules"]
	var out: Array = []
	if cid == "fish":
		var pool := Fishing.pool_for(Fishing.T["fresh_pool"] as Array, 0, "farm")
		var lv := level(wkey, "fish") if wkey != "" else 1
		var cheap := int(Fishing.T["cheap_value"])
		for f: String in pool:
			if GameState.item_value(f) <= cheap:
				out.append(f)
		if lv >= int(r.get("fish_rare_level", 4)):
			for f: String in pool.slice(0, maxi(1, pool.size() / 2)):
				if not out.has(f):
					out.append(f)
		if out.is_empty() and not pool.is_empty():
			out.append(pool[0])
	elif cid == "mine":
		var deepest := int(GameState.run.get("flags", {}).get("mine_deepest", 1))
		if deepest < 2:
			return []
		for row: Array in (r.get("mine_ore", [[1, "stone"]]) as Array):
			if deepest / 2 >= int(row[0]) and GameState.items.has(str(row[1])):
				out.append(str(row[1]))
		out.append("stone")  # stone stays the common pull
	return out


## Milestone title on a chore row at level 3 / 5 ("" below), C16a P6 (c16a_13-11).
static func title(wkey: String, cid: String) -> String:
	var t: Dictionary = (data()["rules"] as Dictionary).get("titles", {})
	var lv := level(wkey, cid)
	for need in ["5", "3"]:
		if lv >= int(need) and t.has(need):
			return str(t[need])
	return ""


static func _beds() -> Array:
	var out: Array = []
	for key in (GameState.run.get("farm", {}) as Dictionary):
		if str((GameState.run["farm"][key] as Dictionary).get("crop", "")) != "":
			out.append(key)
	out.sort()
	return out


# ---- Chores page (Menu > Party > Chores) -------------------------------------------

static var _open := ""


## A chore's icon (ui/chore_<id>, tools/slice_c11b_chores.py), or null.
static func icon(cid: String) -> Texture2D:
	return Art.tex("ui", "chore_" + cid) if Art.has("ui", "chore_" + cid) else null


## One plain row for a worker (c11b_06-14): "Pup: forages 2 a night → farm chest".
static func row_text(wk: String, nm: String) -> String:
	var asg := assignment(wk)
	var cid := str(asg.get("chore", ""))
	if cid == "":
		return "%s: resting (energy %d)" % [nm, energy(wk)]
	var parts: Array = []
	for c: String in [cid, str(asg.get("chore2", ""))]:
		if c == "":
			continue
		var t := "%s %d a night" % [str(chore(c).get("short", c)), units(wk, c)]
		if c == "forage":
			t += " at %s" % region_name(str(asg.get("where", "edges")))
		if str(chore(c).get("needs", "")) == "chest":
			t += " → %s" % chest_name(str(asg.get("chest", "chest")))
		parts.append(t)
	return "%s: %s" % [nm, ", ".join(parts)]


static func build_page(menu: Variant) -> void:
	menu._line("Chores", 10, Color(1, 0.95, 0.8))
	if not unlocked():
		menu._line("  After your first week, the pup, your team animals and friends can do farm chores overnight.", 8, Color(0.7, 0.7, 0.7))
		menu._button("Back to Party", func() -> void: menu._tab = "Party"; menu._refresh())
		return
	var ws := workers()
	if _open != "" and not ws.any(func(w: Array) -> bool: return str(w[0]) == _open):
		_open = ""  # that worker left (rehomed, off the team, out of the party)
	menu._line("  Pick a chore for each helper: it's done while you sleep. Helper spots: %d of %d · tonight's haul up to %s." % [busy_slots(), slots(), Money.amount(night_cap())], 8, Color(0.85, 0.85, 0.8))
	var no_animals := Ranch.animals().is_empty()
	for w: Array in ws:
		var wk := str(w[0])
		var asg := assignment(wk)
		var cid := str(asg.get("chore", ""))
		var idle := why_idle(wk)
		var b: Button = menu._button("%s%s%s" % ["▶ " if _open == wk else "", row_text(wk, str(w[1])), "" if idle == "" else " · " + idle], func() -> void:
			_open = "" if _open == wk else wk
			menu._refresh())
		b.set_meta("pc_key", "chores:" + wk)
		if _open != wk:
			continue
		menu._line("    Energy %d a night%s%s." % [energy(wk), (" (+%d from %s)" % [energy(wk) - int(((data()["workers"] as Dictionary).get(kind_of(wk), {}) as Dictionary).get("energy", 0)), str(((data().get("bond", {}) as Dictionary).get(kind_of(wk), {}) as Dictionary).get("src", "bond"))]) if energy(wk) > int(((data()["workers"] as Dictionary).get(kind_of(wk), {}) as Dictionary).get("energy", 0)) else "", " · can take two chores" if two_chores(wk) else ""], 8, Color(0.8, 0.85, 0.9))
		var can := chores_for(wk)
		if can.is_empty():
			menu._line("    No chores yet%s." % (": teach it Fetch, Guard or Carry" if kind_of(wk) == "animal" else ""), 8, Color(0.75, 0.75, 0.7))
		for c in can:
			var c2 := str(c)
			var ranch_c := c2 in ["feed", "pet", "guard"]
			var cb: Button = menu._button("    %s%s · lv %d%s, up to %d a night%s" % ["• " if c2 == cid else "", chore_name(c2, str(asg.get("where", "edges"))) if c2 != "forage" else "Forage", level(wk, c2), ("" if title(wk, c2) == "" else " " + title(wk, c2)), units(wk, c2, 1.0), " · no animals yet" if ranch_c and no_animals else ""], func() -> void:
				var r := assign(wk, c2, str(asg.get("chest", "chest")))
				if r != "":
					menu._toast(r)
				menu._refresh())
			cb.set_meta("pc_key", "chores:%s:%s" % [wk, c2])
			cb.icon = icon(c2)
			if ranch_c and no_animals:
				cb.modulate = Color(1, 1, 1, 0.55)  # still assignable: it starts once animals arrive
		if cid != "" and two_chores(wk):
			var c2now := str(asg.get("chore2", ""))
			for c in can:
				var cc := str(c)
				if cc == cid:
					continue
				var sb: Button = menu._button("    Second chore: %s%s" % ["• " if cc == c2now else "", chore_name(cc, str(asg.get("where", "edges")))], func() -> void:
					var r := assign2(wk, "" if cc == c2now else cc)
					if r != "":
						menu._toast(r)
					menu._refresh())
				sb.set_meta("pc_key", "chores:%s:2:%s" % [wk, cc])
		if cid != "" and "forage" in [cid, str(asg.get("chore2", ""))]:
			var regs := forage_regions()
			var curw := str(asg.get("where", "edges"))
			var nw := str(regs[(regs.find(curw) + 1) % regs.size()]) if regs.find(curw) >= 0 else str(regs[0])
			var wb: Button = menu._button("    Forages at: %s ›" % region_name(curw), func() -> void:
				set_where(wk, nw)
				menu._refresh())
			wb.set_meta("pc_key", "chores:%s:where" % wk)
		if cid != "" and (str(chore(cid).get("needs", "")) == "chest" or str(chore(str(asg.get("chore2", ""))).get("needs", "")) == "chest"):
			var cur := str(asg.get("chest", "chest"))
			var ks := chests()
			var nxt := str(ks[(ks.find(cur) + 1) % ks.size()]) if ks.find(cur) >= 0 else "chest"
			var chb: Button = menu._button("    Puts it in: %s ›" % chest_name(cur), func() -> void:
				assign(wk, cid, nxt)
				menu._refresh())
			chb.set_meta("pc_key", "chores:%s:chest" % wk)
		if cid != "":
			var rb: Button = menu._button("    Rest tonight", func() -> void: unassign(wk); menu._refresh())
			rb.set_meta("pc_key", "chores:%s:rest" % wk)
	var last: Array = st()["last"]
	if not last.is_empty():
		menu._line("Last night", 9, Color(0.9, 0.85, 0.7))
		for l in last:
			menu._line("  " + str(l), 8, Color(0.8, 0.8, 0.8))
	menu._button("Back to Party", func() -> void: _open = ""; menu._tab = "Party"; menu._refresh())
