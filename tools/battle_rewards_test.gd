extends SceneTree
## C16b P4: the battle reward ladder (BattleRewards, data/battle_rewards.json), both arcs.
## Stars from stats, rank-up pays only the delta, a repeat call pays nothing more, rematch
## pay once a day, the gate's first-clear chest + trophy decor (through DecorSources, never
## the bag), mastery chest + piece + legacy unique, the per-arc star track, battle bonds,
## arc-correct chest goods, preview/node words, nothing story-required.
##   godot --headless --fixed-fps 60 --path . -s res://tools/battle_rewards_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		fails += 1


func _initialize() -> void:
	seed(16)
	Campaign.bypass = false
	var d := BattleRewards.data()
	check(d.get("campaigns", {}).size() == Campaign.all().size(), "a ladder row per campaign")
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		var cid: String = Campaign.for_arc()[0]
		var cd := BattleRewards.camp(cid)
		check(not cd.is_empty(), "%s: %s has a ladder" % [arc, cid])
		var nids: Array = cd["nodes"].keys()
		var nid: String = nids[0]
		# stars from stats
		check(BattleRewards.stars_for(cid, nid, {"tickets_left": 10, "tickets_max": 100}) == 1, "%s: few tickets = 1 star" % arc)
		check(BattleRewards.stars_for(cid, nid, {"tickets_left": 60, "tickets_max": 100, "elapsed": 9999.0}) == 2, "%s: slow clean win = 2 stars" % arc)
		check(BattleRewards.stars_for(cid, nid, {"tickets_left": 60, "tickets_max": 100, "elapsed": 10.0}) == 3, "%s: quick clean win = 3 stars" % arc)
		check(BattleRewards.stars_for(cid, nid, {"tickets_left": 60, "tickets_max": 100, "player_ko": true, "elapsed": 10.0}) == 1, "%s: a KO = 1 star" % arc)
		# first win, 1 star: ladder pays nothing extra (Campaign.finish pays the node)
		var m0 := int(GameState.run.get("crystals", 0))
		BattleRewards.on_win(cid, nid, 1, {})
		check(BattleRewards.stars(cid, nid) == 1, "%s: 1 star stored" % arc)
		check(int(GameState.run.get("crystals", 0)) == m0, "%s: 1 star pays no ladder extra" % arc)
		# repeat same day, same stars: rematch pay once
		var lines := BattleRewards.on_win(cid, nid, 1, {})
		var m1 := int(GameState.run.get("crystals", 0))
		check(m1 > m0 and not lines.is_empty(), "%s: rematch pays once a day (%d -> %d)" % [arc, m0, m1])
		BattleRewards.on_win(cid, nid, 1, {})
		check(int(GameState.run.get("crystals", 0)) == m1, "%s: second rematch same day pays nothing" % arc)
		# rank up to 3: delta paid + supply chest; again: nothing more today
		lines = BattleRewards.on_win(cid, nid, 3, {})
		var m2 := int(GameState.run.get("crystals", 0))
		var cr := int(cd["nodes"][nid]["crystals"])
		check(m2 - m1 >= int(round(cr * 1.0)), "%s: 1->3 stars pays +40%%+60%% (+chest) (%d)" % [arc, m2 - m1])
		check(BattleRewards.stars(cid, nid) == 3, "%s: 3 stars stored" % arc)
		check(" ".join(lines.map(func(x): return str(x["text"]))).contains(BattleRewards.chest_name("supply")), "%s: 3 stars opens a supply chest" % arc)
		BattleRewards.on_win(cid, nid, 3, {})
		BattleRewards.on_win(cid, nid, 2, {})
		check(int(GameState.run.get("crystals", 0)) == m2, "%s: repeat calls pay nothing more" % arc)
		# chest goods fit the arc
		var cr_before := GameState.count("crystal_refined")
		var cw := BattleRewards.open_chest("field")
		check(cw.begins_with(BattleRewards.chest_name("field")), "%s: chest words %s" % [arc, cw])
		if arc == "gangsters":
			check(GameState.count("crystal_refined") == cr_before, "gangsters: no Refined Crystal from chests")
		# gate first clear: trophy decor through DecorSources, bonds
		var gate := ""
		for n: Dictionary in Campaign.get_c(cid).get("nodes", []):
			if str(n.get("type", "")) == "gate":
				gate = str(n["id"])
		check(gate != "" and cd["nodes"].has(gate), "%s: gate node in the ladder" % arc)
		var tid := str(cd["first_clear"]["trophy"])
		var before := Decor.owned(tid)
		lines = BattleRewards.on_win(cid, gate, 1, {})
		check(Decor.owned(tid) > before, "%s: first clear grants the trophy %s" % [arc, tid])
		check(" ".join(lines.map(func(x): return str(x["text"]))).contains("First clear"), "%s: first-clear words" % arc)
		var o2 := Decor.owned(tid)
		BattleRewards.on_win(cid, gate, 1, {})
		check(Decor.owned(tid) == o2, "%s: first clear only once" % arc)
		# mastery: every node at 3 stars
		var md := str(cd["mastery"]["decor"])
		var mb := Decor.owned(md)
		for n2: String in nids:
			BattleRewards.on_win(cid, n2, 3, {})
		check(BattleRewards.campaign_stars(cid) == BattleRewards.max_stars(cid), "%s: all stars counted" % arc)
		check(Decor.owned(md) > mb, "%s: mastery piece granted" % arc)
		check(int(BattleRewards.st()["track"].get(arc, 0)) >= 1, "%s: star track paid its first rung" % arc)
		# preview + node words
		var pv := BattleRewards.preview(cid)
		check(pv.size() >= 3 and str(pv[0]).contains("earned"), "%s: preview lines %s" % [arc, pv])
		check(BattleRewards.node_words(cid, nid).contains(BattleRewards.STAR), "%s: node words show stars" % arc)
		var cid2: String = Campaign.for_arc()[1]
		check(str(BattleRewards.preview(cid2)[0]).begins_with("First clear:") and not str(BattleRewards.preview(cid2)[0]).contains("earned"), "%s: unearned preview names the prize" % arc)
	# legacy uniques come back as mastery rewards
	GameState.new_run("penguins", "kairi", "Hero", "Dreamhollow", "Biscuit")
	for n3: String in BattleRewards.camp("c_wastes")["nodes"]:
		BattleRewards.on_win("c_wastes", n3, 3, {})
	check(GameState.has_tool("aurora_blade"), "penguins: Aurora Blade for mastering the Wastes")
	print("battle_rewards_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
