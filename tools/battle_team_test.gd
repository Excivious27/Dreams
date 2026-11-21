extends SceneTree
## CONDUCT 11b P6: the battle line-up and team jobs.
## CampaignGate.toggle_pick/picked/line_up (picks first, cap LINE_MAX, the earliest pick makes room),
## muster order (partners, crew, team animals, then friends), Battle.job_for (Mom heals, Big Jim
## guards, a shade Gift hides you, crew by role, friends strike), the team-push toast uses the rally
## word, and the battle card offers the pick.
##   godot --headless --fixed-fps 60 --path . -s res://tools/battle_team_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(6)
	_run.call_deferred()

func _ids(rows: Array) -> Array:
	return rows.map(func(r: Array) -> String: return str(r[0]))

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var p := Companion.party()
	p["known"] = ["mom", "big_jim", "mk_sable", "pax", "mer"]
	var fid := ""
	for id: String in GameState.npcs:
		if not id in p["known"]:
			fid = id
			break
	GameState.run["friendship"][fid] = 250
	var tm: Array = CampaignGate.team()
	check(_ids(tm).slice(0, 5) == ["mom", "big_jim", "mk_sable", "pax", "mer"], "partners muster first")
	check(_ids(tm).has(fid) and _ids(tm).find(fid) >= 5, "friends after partners")
	# Animals muster before friends.
	var src := FileAccess.get_file_as_string("res://scripts/campaign_gate.gd")
	check(src.find("TeamAnimals.gate_rows()") < src.find(">= FRIEND_HEARTS"), "team animals are listed before friends")
	# Default line-up = muster order.
	check(_ids(CampaignGate.line_up()) == _ids(tm), "no picks: muster order")
	# Picks go first, in pick order.
	check(CampaignGate.toggle_pick("mer") and CampaignGate.toggle_pick(fid), "picks go in")
	var lu := _ids(CampaignGate.line_up())
	check(lu[0] == "mer" and lu[1] == fid and lu.size() == tm.size(), "picked first, nobody lost: %s" % [lu])
	check(not CampaignGate.toggle_pick("mer") and _ids(CampaignGate.line_up())[0] == fid, "tap again takes them out")
	for id in ["mom", "big_jim", "pax", "mk_sable"]:
		CampaignGate.toggle_pick(id)
	check(CampaignGate.picked().size() == CampaignGate.LINE_MAX and not (fid in CampaignGate.picked()), "a full line-up drops the earliest pick")
	check(Campaign.st().get("line_up", null) is Array, "line-up saved in the campaign block")
	# Jobs follow who the ally is.
	var B: GDScript = load("res://scripts/battle.gd")
	check(B.job_for(["mom", "Mom", "partner"], "striker") == "healer", "Mom heals")
	check(B.job_for(["big_jim", "Big Jim", "partner"], "healer") == "warden", "Big Jim guards, never heals")
	check(B.job_for(["mk_sable", "Sable", "partner"], "healer") == "shade", "a shade Gift hides you")
	check(B.job_for(["mk_ember", "Ember", "partner"], "healer") == "striker", "other Gifts strike")
	check(B.job_for(["pax", "Pax", "partner"], "warden") == "shade", "C16b: Pax scouts, so he hides you whatever the slot")
	check(B.job_for(["zz_none", "Z", "partner"], "warden") == "warden", "no ability at all: the slot job")
	check(B.job_for([fid, "F", "friend"], "healer") == "striker", "friends strike")
	check(B.job_for(["doc", "Doc", "crew"], "striker") == "healer" and B.job_for(["sasha", "Sasha", "crew"], "striker") == "warden", "crew by role")
	check(B.team_members() == CampaignGate.line_up(), "battle fields the line-up")
	var bs := FileAccess.get_file_as_string("res://scripts/battle.gd")
	check(not bs.contains("Tap RALLY to give orders"), "team push toast uses the rally word")
	var bb := FileAccess.get_file_as_string("res://scripts/battle_brief.gd")
	check(bb.contains("CampaignGate.toggle_pick"), "battle card lets you pick the team")
	print("battle_team_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
