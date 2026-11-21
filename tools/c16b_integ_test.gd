extends SceneTree
## C16b integration hooks, both arcs: exactly one BattleRewards.on_win per won fight
## (Campaign.finish, fed Battle's perf stats), stars from perf, the easier-retry cap,
## rematch (no base pay, no morale cost), gang node names and provisions, the gang
## drill's point names, P5's long_way rows read by Campaign.long_way, the brief's
## NEW HERE / STARS lines.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c16b_integ_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		fails += 1


func _first_battle(cid: String) -> String:
	for n: Dictionary in Campaign.get_c(cid).get("nodes", []):
		if str(n.get("type", "")) not in Campaign.NONBATTLE and BattleRewards.camp(cid).get("nodes", {}).has(str(n["id"])):
			return str(n["id"])
	return ""


func _fight(cid: String, nid: String, perf: Dictionary, rematch := false) -> void:
	Campaign.st()["fight"] = {"cid": cid, "nid": nid, "field": "x", "perf": perf, "rematch": rematch, "day": int(GameState.run.get("day", 1))}


func _initialize() -> void:
	seed(16)
	Campaign.bypass = true
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		var cid: String = Campaign.for_arc()[0]
		var nid := _first_battle(cid)
		check(nid != "", "%s: %s has a battle node" % [arc, cid])
		# one on_win per win: a clean quick win = 3 stars, paid once (node reward + ladder, never twice)
		var clean := {"tickets_left": 90, "tickets_max": 100, "player_ko": false, "allies_lost": 0, "elapsed": 5.0, "assist": 0}
		var m0 := int(GameState.run.get("crystals", 0))
		_fight(cid, nid, clean)
		var lines := Campaign.finish(true, 20)
		var m1 := int(GameState.run.get("crystals", 0))
		check(BattleRewards.stars(cid, nid) == 3, "%s: perf gives 3 stars (%d)" % [arc, BattleRewards.stars(cid, nid)])
		var star_lines := lines.filter(func(x: Variant) -> bool: return x is Dictionary and str(x.get("text", "")).begins_with(BattleRewards.STAR))
		check(star_lines.size() == 1, "%s: exactly one star line (one on_win call): %d" % [arc, star_lines.size()])
		check(m1 > m0, "%s: the win paid" % arc)
		check(Campaign.taken(cid, nid), "%s: node taken" % arc)
		# rematch: can_rematch on held ground; no base pay, rematch share once a day
		check(Campaign.can_rematch(cid, nid), "%s: can_rematch a held node" % arc)
		check(not Campaign.can_rematch(cid, "n0"), "%s: no rematch on the start camp" % arc)
		var morale := int(Campaign.cs(cid)["morale"])
		var at := str(Campaign.cs(cid)["at"])
		_fight(cid, nid, clean, true)
		Campaign.finish(true, 20)
		check(int(GameState.run.get("crystals", 0)) == m1, "%s: a same-day rematch pays no base reward and no share (%d -> %d)" % [arc, m1, int(GameState.run.get("crystals", 0))])
		GameState.run["day"] = int(GameState.run.get("day", 1)) + 1
		_fight(cid, nid, clean, true)
		Campaign.finish(true, 20)
		var m2 := int(GameState.run.get("crystals", 0))
		var base_cr := int(Campaign.node(cid, nid).get("reward", {}).get("crystals", 0))
		check(m2 > m1 and m2 - m1 < base_cr, "%s: next-day rematch pays the share only (%d of base %d)" % [arc, m2 - m1, base_cr])
		_fight(cid, nid, clean, true)
		Campaign.finish(false, 0)
		check(int(Campaign.cs(cid)["morale"]) >= morale and str(Campaign.cs(cid)["at"]) == at, "%s: a lost rematch costs no morale and doesn't move the army" % arc)
		check(Campaign.cs(cid).get("last_lost", "") != nid, "%s: a lost rematch is not a loss card" % arc)
		# assist cap: an easier retry wins at most 2 stars
		var nid2 := ""
		for n: Dictionary in Campaign.get_c(cid).get("nodes", []):
			var id := str(n["id"])
			if id != nid and str(n.get("type", "")) not in Campaign.NONBATTLE and BattleRewards.camp(cid).get("nodes", {}).has(id):
				nid2 = id
				break
		if nid2 != "":
			var easy := clean.duplicate()
			easy["assist"] = 1
			_fight(cid, nid2, easy)
			Campaign.finish(true, 20)
			check(BattleRewards.stars(cid, nid2) == 2, "%s: easier retry caps at 2 stars (%d)" % [arc, BattleRewards.stars(cid, nid2)])
		# names, provisions, long way rows
		var gname := ""
		for cc: String in Campaign.all():
			if gname != "":
				break
			for n: Dictionary in Campaign.get_c(cc).get("nodes", []):
				if str(n.get("name_gangsters", "")) != "" and str(n["name_gangsters"]) != str(n["name"]):
					check(Campaign.node_name(cc, str(n["id"])) == (str(n["name_gangsters"]) if arc == "gangsters" else str(n["name"])), "%s: node_name per arc" % arc)
					gname = str(n["name_gangsters"])
					break
		check(gname != "", "%s: a node with a gang name exists" % arc)
		var c := Campaign.get_c(cid)
		if arc == "gangsters" and c.has("need_gang"):
			check(CampaignGate.need(cid) == c["need_gang"], "gangsters: provisions read need_gang")
		else:
			check(CampaignGate.need(cid) == c.get("need", {}), "%s: provisions read need" % arc)
		var lw := Campaign.long_way(cid)
		var row: Dictionary = c.get("long_way", {})
		check(not row.is_empty() and str(lw.get("id", "")) == str(row.get("id", "-")), "%s: Campaign.long_way reads P5's row (%s)" % [arc, str(lw.get("id", ""))])
		# the brief's lines
		var d := {"campaign": cid, "node": nid, "mode": "skirmish"}
		check(BattleBrief.stars_line(d).contains("Best"), "%s: brief STARS line (%s)" % [arc, BattleBrief.stars_line(d)])
		d["assist"] = 1
		check(BattleBrief.stars_line(d).contains("at most 2"), "%s: brief says the easier-retry cap" % arc)
		var cid2: String = Campaign.for_arc()[1]
		check(BattleBrief.new_here_line({"campaign": cid2, "mode": "skirmish"}) != "" or Campaign.get_c(cid2).get("new_here", {}).is_empty(), "%s: brief NEW HERE on a fresh campaign" % arc)
		check(BattleBrief.new_here_line({"campaign": cid, "mode": "skirmish"}) == "", "%s: no NEW HERE once you've won there" % arc)
		# the drill's point names
		var dd := CampaignGate.drill_data({}, {"back": []})
		var names: Array = (dd.get("points", []) as Array).map(func(p: Variant) -> String: return str((p as Dictionary).get("name", "")))
		if arc == "gangsters":
			check(names.has("Getaway Car") and names.has("Corner Store"), "gangsters: drill points named for the gang (%s)" % str(names))
		else:
			check(not names.has("Getaway Car"), "penguins: drill keeps its own names (%s)" % str(names))
		Campaign.st()["fight"] = {}
	print("c16b_integ_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
