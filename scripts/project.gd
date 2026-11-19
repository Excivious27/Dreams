class_name Project
extends RefCounted
## The town project for each arc (data/projects.json from tools/gen_projects.py):
## the Crystal Ward (penguins) and Headquarters (gangsters). Stages of bundles,
## like a community center; each finished stage grants something lasting.
##   run["project"] = {"stage": n, "given": {"s_b": {item: n}}}
##   run["crew_jobs"] = {crew_id: job_id}      (gangster HQ automations)

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/projects.json")
	return _d


static func def() -> Dictionary:
	return data().get("projects", {}).get(str(GameState.run.get("arc", "penguins")), {})


static func st() -> Dictionary:
	var p: Dictionary = GameState.run.get("project", {})
	if p.is_empty():
		p = {"stage": 0, "given": {}}
		GameState.run["project"] = p
	return p


static func stage() -> int:
	return int(st().get("stage", 0))


static func has(grant: String) -> bool:
	return GameState.run.get("flags", {}).has("proj_" + grant)


## How many of `need` you have toward a bundle (handles the special keys).
static func have_of(key: String) -> int:
	match key:
		"#fish":
			var n := 0
			for id in GameState.run["inventory"]:
				if str(GameState.items.get(id, {}).get("type", "")) == "fish" and not GameState.is_locked(str(id)):
					n += int(GameState.run["inventory"][id])
			return n
		"lieutenant_marks":
			var n2 := 0
			for lid in Gift.data().get("lieutenants", {}):
				if GameState.run["flags"].has("lt_" + str(lid)):
					n2 += 1
			return n2
		"friendship_tokens":
			var f := 0
			for npc in GameState.npcs:
				if GameState.friend_hearts(str(npc)) >= 5:
					f += 1
			return 1 if f >= 6 else 0
	return GameState.count_any(key)


static func need_name(key: String) -> String:
	match key:
		"#fish": return "any fish"
		"lieutenant_marks": return "lieutenants beaten"
		"friendship_tokens": return "six friends at 5♥"
	return GameState.need_name(key)


static func _virtual(key: String) -> bool:
	return key in ["lieutenant_marks", "friendship_tokens"]


static func given(s: int, b: int) -> Dictionary:
	var g: Dictionary = st()["given"]
	var k := "%d_%d" % [s, b]
	if not g.has(k):
		g[k] = {}
	return g[k]


static func bundle_done(s: int, b: int) -> bool:
	var bd: Dictionary = def()["stages"][s]["bundles"][b]
	var gv := given(s, b)
	for key in bd["need"]:
		var got := have_of(str(key)) if _virtual(str(key)) else int(gv.get(key, 0))
		if got < int(bd["need"][key]):
			return false
	return true


## Put what you have toward a bundle. Returns how many items went in.
static func contribute(s: int, b: int) -> int:
	var bd: Dictionary = def()["stages"][s]["bundles"][b]
	var gv := given(s, b)
	var n := 0
	for key in bd["need"]:
		var k := str(key)
		if _virtual(k):
			continue
		var left := int(bd["need"][key]) - int(gv.get(k, 0))
		if left <= 0:
			continue
		var put := mini(left, have_of(k))
		if put <= 0:
			continue
		if k == "#fish":
			var rest := put
			# Cheapest first, locked fish never.
			var ids: Array = GameState.run["inventory"].keys().filter(func(x: Variant) -> bool: return not GameState.is_locked(str(x)))
			ids.sort_custom(func(a: Variant, b: Variant) -> bool: return GameState.item_value(str(a)) < GameState.item_value(str(b)))
			for id in ids:
				if rest <= 0:
					break
				if str(GameState.items.get(id, {}).get("type", "")) == "fish":
					var t := mini(rest, int(GameState.run["inventory"][id]))
					GameState.add_item(str(id), -t)
					rest -= t
		else:
			GameState.take_any(k, put)
		gv[k] = int(gv.get(k, 0)) + put
		n += put
	return n


## The project site: bundles, the war table, crew jobs.
static func open(m: GameMap) -> void:
	var pd := def()
	if pd.is_empty():
		return
	if not GameState.run["flags"].has("proj_seen"):
		GameState.run["flags"]["proj_seen"] = true
		await m.say([{"who": str(pd["keeper"]), "text": str(pd["intro"])}])
	while true:
		var s := stage()
		var stages: Array = pd["stages"]
		var opts: Array = []
		var acts: Array = []
		var text := ""
		if s < stages.size():
			var sd: Dictionary = stages[s]
			text = "%s · stage %d of %d: %s\n%s" % [str(pd["name"]), s + 1, stages.size(), str(sd["name"]), str(sd["desc"])]
			for bi in (sd["bundles"] as Array).size():
				var bd: Dictionary = sd["bundles"][bi]
				var parts: Array = []
				for key in bd["need"]:
					var got := have_of(str(key)) if _virtual(str(key)) else int(given(s, bi).get(key, 0))
					parts.append("%d/%d %s" % [mini(got, int(bd["need"][key])), int(bd["need"][key]), need_name(str(key))])
				opts.append("%s %s: %s" % ["✓" if bundle_done(s, bi) else "•", str(bd["name"]), ", ".join(parts)])
				acts.append(["give", bi])
		else:
			text = "%s is complete." % str(pd["name"])
		opts.append("Campaign map: open new regions")
		acts.append(["campaign", 0])
		if has("war_table"):
			opts.append("⚔ War table: battles")
			acts.append(["war", 0])
		if str(GameState.run.get("arc", "")) == "gangsters" and job_slots() > 0:
			opts.append("Crew jobs (%d/%d assigned)" % [(GameState.run.get("crew_jobs", {}) as Dictionary).size(), job_slots()])
			acts.append(["jobs", 0])
		opts.append("Leave")
		acts.append(["leave", 0])
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": str(pd["name"]), "text": text, "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= acts.size():
			return
		var a: Array = acts[i]
		match str(a[0]):
			"leave":
				return
			"give":
				var put := contribute(s, int(a[1]))
				m.hud.toast("Added %d item%s." % [put, "" if put == 1 else "s"] if put > 0 else "You have nothing this bundle still needs.", Color(0.8, 1, 0.8) if put > 0 else Color(1, 0.85, 0.7))
				await _check_stage(m)
			"war":
				await war_table(m)
				return
			"campaign":
				CampaignScreen.open(m)
				return
			"jobs":
				await jobs_menu(m)


static func _check_stage(m: GameMap) -> void:
	var s := stage()
	var stages: Array = def()["stages"]
	if s >= stages.size():
		return
	for bi in (stages[s]["bundles"] as Array).size():
		if not bundle_done(s, bi):
			return
	var sd: Dictionary = stages[s]
	GameState.run["flags"]["proj_" + str(sd["grant"])] = true
	st()["stage"] = s + 1
	m.fx("levelup", m.player.position + Vector2(0, -12), 10.0, 0.9)
	m.shake(2.0)
	Music.instance(m.get_tree()).sfx("quest_done", "levelup")
	m.xp("building", 40 + 20 * s)
	await m.say([{"who": str(def()["keeper"]), "text": "%s: done.\n%s" % [str(sd["name"]), str(sd["desc"])]}])
	GameState.save()


# ---- war table ------------------------------------------------------------------

static func war_table(m: GameMap) -> void:
	var all: Dictionary = GameState.load_json("res://data/battles.json")
	var opts: Array = ["Campaign map (open new regions)"]
	var ids: Array = [["_campaign", true]]
	for bid in all:
		var b: Dictionary = all[bid]
		if str(b.get("arc", "both")) not in ["both", str(GameState.run.get("arc", ""))]:
			continue
		var ready := GameState.progress_tier() + 1 >= int(b.get("tier", 1)) and CampaignGate.trained()
		opts.append("%s%s%s" % ["✓ " if GameState.run["flags"].has("battle_" + str(bid)) else "", str(b["title"]), "" if ready else (" (needs more story)" if CampaignGate.trained() else " (train first)")])
		ids.append([str(bid), ready])
	opts.append("Not now")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "War table", "text": "Pins and string over a big map. Where do we push?", "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= ids.size():
		return
	if str(ids[i][0]) == "_campaign":
		CampaignScreen.open(m)
		return
	if not bool(ids[i][1]):
		m.hud.toast("Not yet: get further in the story first." if CampaignGate.trained() else "Not yet: finish Training on the campaign map first.", Color(1, 0.85, 0.6))
		return
	var R: Dictionary = GameState.load_json("res://data/regions.json").get(str(ids[i][0]), {})
	var sp: Array = R.get("spawn", [10, 10])
	m.go_to(str(ids[i][0]), Vector2(float(sp[0]) * GameMap.TILE + 8, float(sp[1]) * GameMap.TILE + 8), "up")


# ---- crew jobs (gangster HQ automations) ---------------------------------------

static func job_slots() -> int:
	if has("hq_workshop"):
		return 6
	if has("hq_safehouse"):
		return 4
	if has("hq_back_room"):
		return 2
	return 0


static func jobs_menu(m: GameMap) -> void:
	var jobs: Dictionary = data().get("jobs", {})
	var cj: Dictionary = GameState.run.get("crew_jobs", {})
	GameState.run["crew_jobs"] = cj
	var crew: Array = Crew.all_recruited()
	if crew.is_empty():
		m.hud.toast("Nobody's moved in yet: recruit crew first.", Color(1, 0.85, 0.6))
		return
	var opts: Array = []
	for cid in crew:
		var jn := str(jobs.get(str(cj.get(cid, "")), {}).get("name", "free"))
		opts.append("%s: %s" % [str(Crew.members()[cid]["name"]), jn])
	opts.append("Done")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Crew jobs", "text": "Who works what overnight? (%d slots)" % job_slots(), "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= crew.size():
		return
	var cid: String = crew[i]
	var jo: Array = []
	var jk: Array = []
	for k in jobs:
		jo.append("%s: %s" % [str(jobs[k]["name"]), str(jobs[k]["desc"])])
		jk.append(str(k))
	jo.append("No job")
	jo.append("← Back")  # B: keep the job as it is
	var d2 := Dialogue.instance(m.get_tree())
	d2.say([{"who": str(Crew.members()[cid]["name"]), "text": "What do you need, boss?", "choice": jo, "key": ""}])
	await d2.finished
	var j := d2.last_choice
	if j >= 0 and j < jk.size():
		if not cj.has(cid) and cj.size() >= job_slots():
			m.hud.toast("All job slots are taken. Build HQ further for more.", Color(1, 0.85, 0.6))
			return
		cj[cid] = jk[j]
	elif j == jk.size():
		cj.erase(cid)


## Called from sleep(): the arc project's lasting effects, and crew jobs.
static func overnight(report: Dictionary) -> void:
	if has("ward_stone"):
		GameState.add_item("shard", 1)
	if has("hq_safehouse"):
		Racket.set_heat(Racket.heat() - 1)
	if has("star_beacon"):  # the beacon gathers a little starlight every night
		GameState.add_item("star_dust", 1)
		report["star_beacon"] = true
	var jobs: Dictionary = data().get("jobs", {})
	var cj: Dictionary = GameState.run.get("crew_jobs", {})
	var mult := (1.5 if has("hq_workshop") else 1.0) * (1.0 + minf(0.5, GameState.bonus("hustle", "job_pay") + GameState.bonus("leadership", "job_pay")))
	var lines: Array = []
	var taken := {}
	for cid in cj:
		if not Crew.recruited(str(cid)):
			continue
		# One crew member per job: a second on the same job just gets in the way.
		if taken.has(str(cj[cid])):
			lines.append("%s had nothing to do: someone already runs that job." % str(Crew.members().get(str(cid), {}).get("name", cid)))
			continue
		taken[str(cj[cid])] = true
		var j: Dictionary = jobs.get(str(cj[cid]), {})
		GameState.add_xp("leadership", 3)
		# Goods: alternate nights bring the alternate haul; pay bonuses grow money, not goods.
		var give: Dictionary = j.get("give_alt", {}) if j.has("give_alt") and int(GameState.run["day"]) % 2 == 1 else j.get("give", {})
		for it in give:
			GameState.add_item(str(it), int(give[it]))
		if j.has("crystals"):
			GameState.run["crystals"] = int(GameState.run["crystals"]) + int(int(j["crystals"]) * mult)
		if j.has("heat"):
			Racket.set_heat(Racket.heat() + int(j["heat"]))
		if j.has("xp"):
			GameState.add_xp(str(j["xp"][0]), int(int(j["xp"][1]) * mult))
		if bool(j.get("water", false)):
			for k in GameState.run["farm"]:
				GameState.run["farm"][k]["watered"] = true
		lines.append("%s: %s" % [str(Crew.members().get(cid, {}).get("name", cid)), str(j.get("name", ""))])
	if not lines.is_empty():
		report["crew_jobs"] = lines
