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
	(st()["assign"] as Dictionary)[wkey] = {"chore": chore_id, "chest": chest if chest in chests() else "chest"}
	return ""


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


## Work units a worker can do of a chore tonight (level, then energy and the cap).
static func units(wkey: String, chore_id: String) -> int:
	var c := chore(chore_id)
	if c.is_empty():
		return 0
	var w: Dictionary = (data()["workers"] as Dictionary).get(kind_of(wkey), {})
	var by_level := int(c.get("base", 1)) + int(c.get("per_level", 0)) * (level(wkey, chore_id) - 1)
	if chore_id in ["feed", "pet"]:
		by_level = int(round(by_level * (1.0 + GameState.ranch_bonus("hand_work"))))  # Ranching: more ranch chores
	var by_energy := int(w.get("energy", 0)) / maxi(1, int(c.get("energy", 1)))
	return clampi(mini(by_level, by_energy), 0, int(data().get("max_units", 20)))


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
static func overnight(report: Dictionary) -> Array:
	var lines: Array = []
	if GameState.run.is_empty() or not unlocked() or GameState.visiting():
		return lines
	var a: Dictionary = st()["assign"]
	var keys: Array = a.keys()
	keys.sort()
	# Water first, then harvest, so a harvest never takes a bed a waterer just did.
	var order := ["water", "feed", "pet", "harvest", "forage"]
	keys.sort_custom(func(x: String, y: String) -> bool:
		return order.find(str(a[x].get("chore", ""))) < order.find(str(a[y].get("chore", ""))))
	var did_any := 0
	for wkey: String in keys:
		var as_: Dictionary = a[wkey]
		var cid := str(as_.get("chore", ""))
		var who := name_of(wkey)
		var idle := why_idle(wkey)
		if idle != "":
			if idle.begins_with("Not "):
				a.erase(wkey)  # gone from the team/crew/party: free the slot
			else:
				lines.append("%s: %s" % [who, idle])
			continue
		if not cid in chores_for(wkey):
			a.erase(wkey)
			continue
		var n := units(wkey, cid)
		var res := _do(cid, n, str(as_.get("chest", "chest")))
		var done := int(res.get("done", 0))
		if done > 0:
			did_any += done
			var xd: Dictionary = (st()["xp"] as Dictionary).get(wkey, {})
			var lv0 := level(wkey, cid)
			xd[cid] = int(xd.get(cid, 0)) + done * int(chore(cid).get("xp", 1))
			(st()["xp"] as Dictionary)[wkey] = xd
			var ln := "%s %s %s." % [who, str(chore(cid).get("verb", cid)), str(res.get("what", ""))]
			if level(wkey, cid) > lv0:
				ln += " (%s level %d!)" % [str(chore(cid).get("name", cid)).to_lower(), level(wkey, cid)]
			lines.append(ln)
		elif str(res.get("why", "")) != "":
			lines.append("%s: %s" % [who, str(res["why"])])
	if did_any > 0:
		GameState.add_xp("leadership", mini(did_any, int((data()["rules"] as Dictionary).get("lead_xp_cap", 4))))
	st()["last"] = lines.duplicate()
	if not lines.is_empty():
		report["chores"] = lines
	return lines


static func _do(cid: String, n: int, chest: String) -> Dictionary:
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
			for key in _beds():
				if k >= n:
					break
				var t: Dictionary = GameState.run["farm"][key]
				var cd: Dictionary = GameState.crops.get(str(t.get("crop", "")), {})
				if cd.is_empty() or int(t.get("days", 0)) < int(cd.get("days", 99)):
					continue
				var yid := str(cd.get("yield", ""))
				if put(chest, yid, 1) <= 0:
					full = true
					break
				GameState.log_grown(str(t["crop"]))
				if cd.has("regrow"):
					t["days"] = int(cd["days"]) - int(cd["regrow"])
				else:
					t["crop"] = ""
					t["days"] = 0
				t["acc"] = 0.0
				t["watered"] = false
				k += 1
			var why := ("the %s is full." % chest_name(chest)) if full else "nothing was ripe."
			return {"done": k, "what": "%d crop%s into the %s" % [k, "" if k == 1 else "s", chest_name(chest)], "why": "" if k > 0 else why}
		"feed", "pet":
			var k := 0
			var day := int(GameState.run.get("day", 1))
			var uids: Array = Ranch.animals().keys()
			uids.sort()
			for uid: String in uids:
				if k >= n:
					break
				var an := Ranch.animal(uid)
				if cid == "feed":
					if int(an.get("last_fed", -1)) == day:
						continue
					an["last_fed"] = day
					k += 1
				elif Ranch.pet(uid):
					k += 1
			var what := "%d animal%s" % [k, "" if k == 1 else "s"]
			return {"done": k, "what": what, "why": "" if k > 0 else ("no animals needed it." if not Ranch.animals().is_empty() else "there are no animals yet.")}
		"forage":
			var pool: Array = ((data()["rules"] as Dictionary).get("forage", {}) as Dictionary).get(GameState.season(), [])
			pool = pool.filter(func(i: Variant) -> bool: return GameState.items.has(str(i)))
			if pool.is_empty():
				return {"done": 0, "why": "nothing to forage this season."}
			var got := {}
			var k := 0
			for i in n:
				var id := str(pool[randi() % pool.size()])
				if put(chest, id, 1) <= 0:
					break
				got[id] = int(got.get(id, 0)) + 1
				k += 1
			var parts: Array = []
			for id: String in got:
				parts.append(ItemWords.count_id(id, int(got[id])))
			return {"done": k, "what": "%s into the %s" % [", ".join(parts), chest_name(chest)], "why": "" if k > 0 else "the %s is full." % chest_name(chest)}
	return {"done": 0}


static func _beds() -> Array:
	var out: Array = []
	for key in (GameState.run.get("farm", {}) as Dictionary):
		if str((GameState.run["farm"][key] as Dictionary).get("crop", "")) != "":
			out.append(key)
	out.sort()
	return out


# ---- Chores page (Menu > Party > Chores) -------------------------------------------

static var _open := ""


static func build_page(menu: Variant) -> void:
	menu._line("Chores", 10, Color(1, 0.95, 0.8))
	if not unlocked():
		menu._line("  After your first week, the pup, your team animals and friends can do farm chores overnight.", 8, Color(0.7, 0.7, 0.7))
		menu._button("Back to Party", func() -> void: menu._tab = "Party"; menu._refresh())
		return
	menu._line("  Pick a chore for each helper: it's done while you sleep.", 8, Color(0.85, 0.85, 0.8))
	for w: Array in workers():
		var wk := str(w[0])
		var asg := assignment(wk)
		var cid := str(asg.get("chore", ""))
		var idle := why_idle(wk)
		var now := ("%s (lv %d, %d)" % [str(chore(cid).get("name", cid)), level(wk, cid), units(wk, cid)]) if cid != "" else "resting"
		var b: Button = menu._button("%s%s: %s%s" % ["▶ " if _open == wk else "", str(w[1]), now, "" if idle == "" else " · " + idle], func() -> void:
			_open = "" if _open == wk else wk
			menu._refresh())
		b.set_meta("pc_key", "chores:" + wk)
		if _open != wk:
			continue
		var can := chores_for(wk)
		if can.is_empty():
			menu._line("    No chores yet%s." % (": teach it Fetch, Guard or Carry" if kind_of(wk) == "animal" else ""), 8, Color(0.75, 0.75, 0.7))
		for c in can:
			var c2 := str(c)
			var cd := chore(c2)
			var cb: Button = menu._button("    %s%s  (lv %d, up to %d a night)" % ["• " if c2 == cid else "", str(cd.get("name", c2)), level(wk, c2), units(wk, c2)], func() -> void:
				var r := assign(wk, c2, str(asg.get("chest", "chest")))
				if r != "":
					menu._toast(r)
				menu._refresh())
			cb.set_meta("pc_key", "chores:%s:%s" % [wk, c2])
		if cid != "" and str(chore(cid).get("needs", "")) == "chest":
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
