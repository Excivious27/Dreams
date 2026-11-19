extends SceneTree
## Goal line audit, days 1-5, both arcs: walks the early story as GameState
## steps (no maps) and prints the HUD goal (GameState.next_step) after each
## milestone, with asserts that the goal is the right one.
var fails := 0
var arc := ""


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func goal(tag: String) -> String:
	GameState.tick_quests()
	var g := GameState.next_step()
	print("[%s d%d] %s\n      -> %s   (arrow: %s)" % [arc, int(GameState.run["day"]), tag, g, str(GoalLine.goal_place())])
	# The HUD shows two lines (about 54 + 58 characters): the whole step must fit.
	check(g.length() <= 112, "%s: goal fits the HUD's two lines (%d chars)" % [arc, g.length()])
	return g


## Plays a story beat's effects without a map (flags, quests, completes).
func beat(id: String, choice := -1) -> void:
	for b in Story.beats():
		if str(b["id"]) != id:
			continue
		var fx: Dictionary = b.get("effects", {})
		for f in fx.get("flags", []):
			GameState.run["flags"][str(f)] = true
		for q in fx.get("quest", []):
			GameState.add_quest(str(q[0]), str(q[1]))
		for q in fx.get("complete", []):
			GameState.complete_quest(str(q))
		if choice >= 0:
			for f in b.get("effects_by_choice", {}).get(str(choice), {}).get("flags", []):
				GameState.run["flags"][str(f)] = true
		GameState.run["flags"]["st_" + id] = true
		return
	check(false, "beat %s exists" % id)


func next_day() -> void:
	GameState.run["day"] = int(GameState.run["day"]) + 1
	for k in GameState.run["farm"]:
		var t: Variant = GameState.run["farm"][k]
		if t is Dictionary and str(t.get("crop", "")) != "" and bool(t.get("watered", false)):
			t["days"] = int(t.get("days", 0)) + 1
		if t is Dictionary:
			t["watered"] = false


func _run() -> void:
	for a: String in ["penguins", "gangsters"]:
		arc = a
		GameState.new_run(a, "kairi" if a == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		var pen: bool = a == "penguins"
		var g := goal("new game, day 1")
		check(g.begins_with("Hold the hoe"), "%s: day 1 starts on the first crop" % a)
		GameState.run["farm"]["10,10"] = {"crop": "", "watered": false}
		g = goal("tilled")
		check(g.begins_with("Pick Turnip"), "%s: tilled -> plant" % a)
		GameState.run["farm"]["10,10"]["crop"] = "turnip"
		g = goal("planted")
		check(g.begins_with("Water") or (not pen and g.begins_with("The rain")), "%s: planted -> water (or rain)" % a)
		if not pen:
			check(g.begins_with("The rain waters it"), "gang: the rainy first night says the rain waters the crop")
		GameState.run["farm"]["10,10"]["watered"] = true
		g = goal("watered")
		check(g.begins_with("Watered") or g.begins_with("The rain"), "%s: watered -> wait" % a)
		GameState.run["flags"]["town_seen"] = true
		GameState.complete_quest("meet_town")
		next_day()
		g = goal("day 2 morning")
		check(g.begins_with("Water"), "%s: day 2 asks to water again" % a)
		GameState.run["farm"]["10,10"]["watered"] = true
		next_day()
		g = goal("day 3 morning (howl)")
		check(g.find("meadow") >= 0 and g.find("east gate") >= 0, "%s: day 3 points at the east meadow and says how" % a)
		check(GoalLine.goal_place()[0] == "meadow", "%s: the arrow leads to the meadow" % a)
		GameState.run["farm"]["10,10"]["watered"] = true
		next_day()
		g = goal("day 4: the first crop is ripe")
		check(g.begins_with("Your crop is ripe"), "%s: a ripe first crop comes before the meadow" % a)
		GameState.run["farm"]["10,10"]["crop"] = ""
		GameState.complete_quest("first_harvest")
		g = goal("harvested")
		check(g.find("meadow") >= 0, "%s: back to the meadow after the harvest" % a)
		# ---- the meadow boss
		GameState.complete_quest("clear_meadow")
		if pen:
			GameState.run["flags"]["spark"] = true
			GameState.add_item("shard", 2)
			beat("p1_grump_truth", 0)
			g = goal("meadow boss down")
			check(g.find("Catkins") >= 0, "pen: after the meadow -> Catkins")
			GameState.run["flags"]["cm_seen"] = true
			check(GoalLine.goal_place() == ["crystal_meadow", "npc:catkins"], "pen: arrow -> Catkins")
			beat("p2_catkins")
			g = goal("Catkins taught the Meow Pow Wow (no stone yet)")
			check(g.find("Resonator") >= 0 and g.find("10 more stone") >= 0, "pen: resonator step names what's missing")
			GameState.add_item("stone", 10)
			g = goal("10 stone in the bag")
			check(g.begins_with("Build the Crystal Resonator"), "pen: build step")
			check(GoalLine.goal_place() == ["farm", "thing:plans"], "pen: arrow -> Plans board")
			if not GameState.run.has("builds"):
				GameState.run["builds"] = {}
			GameState.run["builds"]["resonator"] = 1
			GameState.add_item("shard", -1)
			GameState.add_item("stone", -10)
			g = goal("resonator built, 1 shard")
			check(g.begins_with("Find 2 more crystal shards"), "pen: shard step counts")
			GameState.add_item("shard", 2)
			g = goal("3 shards")
			check(g.begins_with("Refine a crystal"), "pen: refine step")
		else:
			beat("g1_man")
			g = goal("meadow boss down")
			check(g.find("Sal") >= 0, "gang: after the meadow -> Sal")
			check(GoalLine.goal_place() == ["town", "npc:sal"], "gang: arrow -> Sal in town")
			# Skipping Sal is allowed: in Hideout the crew comes next, and the arrow stops pointing at Sal.
			var save_q: Array = (GameState.run["quests"] as Array).duplicate(true)
			GameState.run["flags"]["hideout_seen"] = true
			g = goal("(skipped Sal) arrived in Hideout town")
			check(g.find("Deuce") >= 0 and g.find("campaign") < 0, "gang: skipped Sal -> recruit crew, no campaign yet")
			check(GoalLine.goal_place() == ["", ""], "gang: skipped Sal -> no arrow back to town")
			GameState.run["flags"].erase("hideout_seen")
			GameState.run["quests"] = save_q
			GameState.run["flags"]["sal_recruited"] = true
			beat("g1_sal")
			g = goal("talked to Sal")
			check(g.begins_with("Hideout town") and g.find("outskirts gate") >= 0, "gang: after Sal -> Hideout town, and how")
			check(GoalLine.goal_place() == ["crystal_meadow", "thing:gate"], "gang: arrow -> the outskirts gate")
			GameState.run["flags"]["hideout_seen"] = true
			beat("g2_arrive")
			g = goal("arrived in Hideout town")
			check(g.find("Deuce") >= 0 and g.find("campaign") < 0, "gang: in Hideout -> recruit crew before the docks")
			GameState.run["flags"]["crew_deuce"] = true
			GameState.complete_quest("gang")
			g = goal("first crew recruited")
			check(g.find("Dockside Push") >= 0 and g.find("First:") >= 0 and g.to_lower().find("training") >= 0, "gang: docks campaign, training first")
		# Show the whole quest log for the record.
		for q in GameState.run["quests"]:
			print("      log: %s %s" % ["[x]" if q["done"] else "[ ]", q["text"]])
		next_day()
		next_day()
		g = goal("two days on")
	# The arrow's route through the scene graph.
	check(GoalLine.next_hop("town", "meadow") == "farm", "route: town -> farm -> meadow")
	check(GoalLine.next_hop("beach", "crystal_meadow") == "town", "route: beach -> town first")
	check(GoalLine.next_hop("hideout", "town") == "crystal_meadow", "route: hideout -> outskirts first")
	check(GoalLine.next_hop("farm", "farm") == "", "route: already there")
	print("goal_line_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
