extends SceneTree
## CONDUCT 3 campaign design checks (P1): penguin foes are Grumps (variants +
## named captains, never soldiers/thugs), the Wastes and islands are penguin-only,
## per-arc texts and leaders (Catkins only late), siege tickets scale with size,
## early boards never open with an escort, kill pay per node, cs() defaults, the
## Crystal Kin nest choice and the penguin win lines.
##   godot --headless --fixed-fps 60 --path . -s res://tools/campaign_c3_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		fails += 1


func _initialize() -> void:
	seed(3)
	Campaign.bypass = false
	var E: Dictionary = GameState.load_json("res://data/enemies.json").get("enemies", {})
	if GameState.enemy_data.is_empty():
		GameState.enemy_data = GameState.load_json("res://data/enemies.json")
	var variants := ["grump_crystal", "grump_storm", "grump_frost", "grump_coral", "grump_ember", "grump_moss", "grump_brute", "grump_wisp"]
	for v: String in variants:
		check(E.has(v) and str(E[v].get("art_fallback", "")) == "grump" and E[v].has("fallback_tint"), "%s exists with a grump fallback" % v)
	check(Art.has("enemies/grump", "idle"), "the fallback grump sprite exists")
	var sigs := {}
	for v: String in variants:
		sigs[str(E[v]["abilities"]) + str(E[v].get("status", "")) + str(E[v]["hp"])] = true
	check(sigs.size() == variants.size(), "every grump variant has its own build")
	var all := Campaign.all()
	for cid: String in all:
		var c: Dictionary = all[cid]
		var arc := str(c["arc"])
		if str(c["region"]) in ["wastes", "colony_coral", "colony_kelp", "colony_ice", "colony_ember"]:
			check(arc == "penguins", "%s is penguin-only" % cid)
		if arc == "both":
			check(c["intro"] is Dictionary and str(c["intro"]["penguins"]) != str(c["intro"]["gangsters"]), "%s: intro per arc" % cid)
			check(c["won"] is Dictionary, "%s: won line per arc" % cid)
		var lead: Dictionary = c.get("lead", {})
		if lead.has("penguins") and int(c["tier"]) <= 2:
			check(str(lead["penguins"][0]) != "Catkins", "%s: Catkins doesn't lead an early campaign" % cid)
		for n: Dictionary in c["nodes"]:
			var cfg: Dictionary = n.get("cfg", {})
			if cfg.has("penguins"):
				var pe: Array = cfg["penguins"]["enemies"]
				check(not pe.any(func(k): return str(k) in ["soldier", "archer", "knight"] or str(k).begins_with("thug_")), "%s/%s: no soldiers for penguins %s" % [cid, n["id"], pe])
				check(pe.any(func(k): return str(k).begins_with("grump")), "%s/%s: penguins fight grumps %s" % [cid, n["id"], pe])
				if str(n["type"]) in ["boss", "gate"]:
					var bk := str(cfg["penguins"].get("boss", ""))
					check(bk.begins_with("gcap_") and E.has(bk) and str(E[bk].get("name", "")) != "", "%s/%s: a named grump captain" % [cid, n["id"]])
			if cfg.has("gangsters"):
				check(not (cfg["gangsters"]["enemies"] as Array).any(func(k): return str(k).begins_with("grump_")), "%s/%s: no grump variants for gangsters" % [cid, n["id"]])
			for a: String in cfg:
				if str(n["type"]) in ["siege", "gate"]:
					var ne := (cfg[a]["points"] as Array).filter(func(p): return str(p["owner"]) == "enemy").size()
					check(int(cfg[a].get("tickets", 0)) >= 150 + 40 * maxi(0, ne - 3), "%s/%s: siege tickets scale with %d points" % [cid, n["id"], ne])
			if str(n["type"]) == "escort" and int(c["tier"]) <= 2:
				check(int(n["layer"]) >= 2, "%s: no escort opener on an early board" % cid)
	# ---- penguin run -------------------------------------------------------------
	GameState.new_run("penguins", "kairi", "Hero", "Dreamhollow", "Biscuit")
	check(not Campaign.for_arc().has("c_countryside"), "penguins: no gangster campaigns")
	check(Campaign.who("c_highlands") == Campaign.pal(), "highlands: the partner leads until Big Jim is met (%s)" % Campaign.who("c_highlands"))
	GameState.run["flags"]["st_p3_campfire"] = true
	check(Campaign.who("c_highlands") == "Big Jim", "highlands: Big Jim leads once met")
	check(Campaign.who("c_ruins") == Campaign.pal(), "ruins: no Catkins before she's met")
	GameState.run["flags"]["st_p2_catkins"] = true
	check(Campaign.who("c_ruins") == "Catkins", "ruins: Catkins leads late")
	check(Campaign.force_word() == "army", "penguins: army")
	# cs() fills a partial save entry
	Campaign.st()["c"]["c_marsh"] = {"at": "n0"}
	var cs := Campaign.cs("c_marsh")
	check(cs.has("taken") and cs.has("morale") and cs.has("supply") and cs.has("wins"), "cs() fills missing keys")
	# kill pay pool per node
	var nid := ""
	for n: Dictionary in Campaign.get_c("c_orchard_hills")["nodes"]:
		if n.has("cfg") and nid == "":
			nid = str(n["id"])
	var fid := str(Campaign.cfg("c_orchard_hills", nid)["field"])
	Campaign.st()["fight"] = {"cid": "c_orchard_hills", "nid": nid, "field": fid}
	var kp := Campaign.kill_pool(fid)
	check(kp.size() == 2 and str(kp[0]) == "bfk_c_orchard_hills_" + nid, "kill pay pool is per node (%s)" % str(kp))
	Campaign.st()["fight"] = {}
	check(Campaign.kill_pool(fid).is_empty(), "a free field battle has no node pool")
	# Crystal Kin: the nest waits after a won battle with crystal babies
	var kin_cid := "c_orchard_hills"
	check(not Campaign.kin_due(kin_cid), "no nest before a battle with crystal babies")
	for n: Dictionary in Campaign.get_c(kin_cid)["nodes"]:
		if "crystal_baby" in (n.get("cfg", {}).get("penguins", {}).get("enemies", []) as Array):
			Campaign.cs(kin_cid)["taken"][str(n["id"])] = true
	check(Campaign.kin_due(kin_cid), "the crystal babies' nest waits after the battle")
	var ch: Array = Campaign.kin_choices(kin_cid)
	check(str(ch[ch.size() - 1][0]) == "later", "the nest choice has a way out")
	check(not ch.any(func(x): return str(x[0]) == "meow"), "no Meow Pow Wow before Nova learns it")
	check(str(Campaign.kin_settle(kin_cid, "need")[0]["text"]).contains("Bring"), "no gift: told what to bring")
	GameState.add_item("crystal_refined", 2)
	var kl := Campaign.kin_settle(kin_cid, "gift")
	check(GameState.run["flags"].has(Campaign.KIN_FLAG) and GameState.count("crystal_refined") == 0 and not kl.is_empty(), "a gift turns them into Crystal Kin")
	check(not Campaign.kin_due(kin_cid), "the nest is done once they've joined")
	var kinds: Dictionary = GameState.load_json("res://data/battles.json").get("_helper_kinds", {})
	check(kinds.has("crystal_kin") and str(kinds["crystal_kin"].get("flag", "")) == Campaign.KIN_FLAG, "Crystal Kin helper kind data")
	# penguin win lines: crystals turned back; captain named
	var fl := Campaign.flavour(kin_cid, nid, true)
	check(fl.contains("crystal") and not fl.contains("Meow"), "penguin win line turns them back (%s)" % fl)
	var gate := ""
	for n: Dictionary in Campaign.get_c(kin_cid)["nodes"]:
		if str(n["type"]) == "gate":
			gate = str(n["id"])
	check(Campaign.flavour(kin_cid, gate, true).contains(str(E[Campaign.boss_of(kin_cid, gate)]["name"])), "the gate line names the captain")
	# ---- gangster run --------------------------------------------------------------
	GameState.new_run("gangsters", "pax", "Hero", "Dreamhollow", "Biscuit")
	var gl := Campaign.for_arc()
	check(not gl.has("c_wastes") and not gl.has("c_colony_coral"), "gangsters: no Wastes or island campaigns")
	check(Campaign.first_in_chain("c_docks") == "c_countryside", "gangsters start with the Highway Job")
	check(int(Campaign.get_c("c_uptown")["tier"]) == 4 and "c_underground" in Campaign.get_c("c_uptown")["after"], "uptown after the underground, both tier 4")
	check(Campaign.who("c_neon") == "Sal", "Halo unrecruited: Sal leads")
	check(Campaign.force_word() == "crew", "gangsters: crew")
	check(Campaign.flavour("c_countryside", "n1", true) == "", "no penguin lines for gangsters")
	check(Campaign.text(Campaign.get_c("c_orchard_hills"), "intro").contains("lookouts"), "gangster intro on a shared campaign")
	print("campaign_c3_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
