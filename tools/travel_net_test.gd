extends SceneTree
## C14 P4: the fast-travel network (TravelNet + TravelScene, data/travel.json).
## Tiers per arc, contract station ids, build -> ride, unlock conditions, fares and
## free-after, Campaign hold, save migration (run.travel + run.marina), the ride
## scene's skip rule on frame time, and station desks placed on a real map.
##   godot --headless --path . --fixed-fps 60 -s res://tools/travel_net_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(14)
	_run.call_deferred()


func _tiers(arc: String) -> Dictionary:
	GameState.run["arc"] = arc
	var out := {}
	for l: Dictionary in TravelNet.all_links():
		if TravelNet.link_arc_ok(l):
			out[int(l["tier"])] = true
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	TravelNet.skip_scene = true
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	check(not TravelNet.data().is_empty(), "travel.json loads")
	for sid in ["beach_marina", "beach_colony_ferry", "beach_tidewater", "colony_coral_jetty", "colony_kelp_jetty", "colony_ice_jetty", "colony_ember_jetty"]:
		check(not TravelNet.station(sid).is_empty(), "contract station %s exists" % sid)
	check(_tiers("gangsters").size() == 5, "gangster arc has tiers 1-5")
	check(_tiers("penguins").size() == 5, "penguin arc has tiers 1-5")
	GameState.run["arc"] = "penguins"
	# Save blocks.
	GameState.run.erase("travel")
	GameState.run.erase("marina")
	GameState.run["flags"]["mega_frostpeak_open"] = true
	GameState._migrate()
	check(GameState.run.get("travel") is Dictionary and GameState.run.get("marina") is Dictionary, "migrate makes run.travel and run.marina")
	check(TravelNet.st()["unlocked"].has("mega_frostpeak"), "migrate opens a keeper's ride an old save already had")
	check(GameState.SAVE_VERSION >= 13 and "travel" in GameState.RUN_BLOCKS and "marina" in GameState.RUN_BLOCKS, "save version and run blocks")
	# T1 build -> ride (town cliff stairs).
	check(not TravelNet.can_ride("t1_town_beach"), "stairs shut before they're built")
	check(TravelNet.why_not("t1_town_beach").begins_with("Build"), "why_not names the build")
	check(TravelNet.is_known("t1_town_beach"), "a build site shows on the desk/map")
	check(not TravelNet.build("town_cliff_stairs"), "can't build without the goods")
	GameState.run["crystals"] = 20000
	GameState.add_item("plank", 20)
	GameState.add_item("stone", 30)
	check(TravelNet.build("town_cliff_stairs"), "build pays and builds")
	check(int(GameState.run["crystals"]) == 19500 and GameState.count("plank") == 0, "build cost taken")
	check(TravelNet.can_ride("t1_town_beach") and TravelNet.is_free("t1_town_beach"), "stairs ride free once built")
	# T3 keeper ride: fare until five rides, then free.
	check(TravelNet.can_ride("mega_frostpeak") and not TravelNet.is_free("mega_frostpeak"), "keeper ride open with a fare")
	var before := int(GameState.run["crystals"])
	var t0 := int(GameState.run.get("time", 0))
	await TravelNet.ride("mega_frostpeak", null, "frostpeak_home")
	check(int(GameState.run["crystals"]) == before - 150, "fare paid (%d)" % (before - int(GameState.run["crystals"])))
	check(int(GameState.run["time"]) > t0, "the ride takes game time")
	check(str(TravelNet.st().get("arrive", "")) == "frostpeak_hub" and TravelNet.st()["seen"].has("mega_frostpeak"), "arrival + seen recorded")
	for i in 4:
		await TravelNet.ride("mega_frostpeak", null, "frostpeak_hub")
	check(TravelNet.is_free("mega_frostpeak"), "free after five paid rides")
	check(not TravelNet.can_ride("mega_sunscorch"), "another keeper's line stays shut")
	check(not TravelNet.can_ride("t4_frostpeak_sunscorch") and not TravelNet.can_ride("t4_gloamwood_frostpeak"), "hub-to-hub lines are each their own unlock")
	# Unlock conditions.
	check(not TravelNet.can_ride("t1_farm_meadow"), "hedge gap needs foraging 3")
	check(TravelNet.why_not("t1_farm_meadow").contains("Foraging"), "why_not words the skill")
	check(not TravelNet.can_ride("t5_way_farm_town"), "waystones wait for the teleporter")
	# Campaign hold: the colony ferry line is known once you've been, but held until won.
	if not (GameState.run.get("visited") is Dictionary):
		GameState.run["visited"] = {}
	GameState.run["visited"]["colony_coral"] = [100, 100]
	check(TravelNet.is_unlocked("t2_colony_coral"), "colony ferry line opens once visited")
	Campaign.bypass = false
	if Campaign.gate_of("colony_coral") != "" and not Campaign.region_open("colony_coral"):
		check(not TravelNet.can_ride("t2_colony_coral") and TravelNet.why_not("t2_colony_coral").contains("campaign"), "Campaign hold still applies")
	# Arc: gangster lines never run for penguins.
	check(not TravelNet.link_arc_ok(TravelNet.link("t2_bus_hideout_docks")), "gang bus not a penguin line")
	check(TravelNet.links_at("hideout").is_empty(), "no penguin lines at the hideout")
	GameState.run["arc"] = "gangsters"
	check(TravelNet.link_arc_ok(TravelNet.link("t2_bus_hideout_docks")) and not TravelNet.link_arc_ok(TravelNet.link("t1_town_beach")), "gang arc sees its own lines only")
	GameState.run["arc"] = "penguins"
	# Ride scene: first ride plays through (B ignored), seen ride skips on B; frame time only.
	var ts := TravelScene.play(root, TravelNet.link("t1_town_beach"), "town_cliff_stairs", true)
	var gt := 0.0
	var ended := [false]
	ts.finished.connect(func() -> void: ended[0] = true)
	Input.action_press("b")
	await process_frame
	Input.action_release("b")
	while not ended[0] and gt < 6.0:
		await process_frame
		gt += root.get_process_delta_time()
	check(ended[0] and gt >= TravelScene.DUR - 0.1, "first ride unskippable, ends after %.2f s" % gt)
	check(not paused, "tree unpaused after the ride")
	var ts2 := TravelScene.play(root, TravelNet.link("t1_town_beach"), "beach_cliff_stairs", false)
	var e2 := [false]
	ts2.finished.connect(func() -> void: e2[0] = true)
	await process_frame
	Input.action_press("b")
	await process_frame
	await process_frame
	Input.action_release("b")
	check(e2[0], "a seen ride skips on B")
	# Map layers draw (Valley painting + a region tab) without errors.
	var cv := Control.new()
	cv.size = Vector2(240, 190)
	var drew := [0]
	cv.draw.connect(func() -> void:
		TravelNet.map_layer(cv, ThemeDB.fallback_font, {"town": Vector2(0.52, 0.70), "beach": Vector2(0.40, 0.90)}, Vector2(0, 0), Vector2(240, 190))
		TravelNet.region_layer(cv, {"frost_hearthhold": Vector2(100, 100)})
		drew[0] += 1)
	root.add_child(cv)
	cv.queue_redraw()
	for i in 3:
		await process_frame
	check(drew[0] > 0, "map layers drew")
	cv.queue_free()
	# A real map: the built stairs' desk is placed in town (a mega_gate thing with a station key).
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = "town"
	TravelNet.placed.clear()
	change_scene_to_file("res://scenes/town.tscn")
	for i in 12:
		await process_frame
	var m := current_scene as GameMap
	var found := false
	if m:
		for c: Vector2i in m.things:
			if str(m.things[c].get("station", "")) == "town_cliff_stairs":
				found = true
	check(found, "town shows the stairs desk")
	print("travel_net_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
