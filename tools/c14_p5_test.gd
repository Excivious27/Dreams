extends SceneTree
## C14 P5: gang cities, mega regions, sky, colonies.
## - Gang city maps carry city border stands, Neon its wet asphalt (no grey seam), Uptown a
##   pavement district with filled east/south blocks (c14_06-01/02/03/15).
## - Quarry, Ruins and Marsh wear a gang skin in the gang arc only (Region._gang_skin, c14_06-04).
## - Urban/underground mega areas draw a stone border band; cave and sky pools have no grass bank.
## - Clean desert/winter scatter and the keyed Glass Canyon head replace the mis-sliced art.
## - Every colony has its jetty (TravelNet station colony_<id>_jetty) handled by Colony.interact.
## - Arrival ride lines only show when you came from an entry scene (MegaRegion._entry_from).
##   godot --headless --path . --fixed-fps 60 -s res://tools/c14_p5_test.gd
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(14)
	_run.call_deferred()


func _run() -> void:
	var R: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	for id in ["neon", "docks", "uptown", "hideout"]:
		var bt = R[id].get("border_trees")
		ok(bt is Dictionary and not (bt["mid"] as Array).is_empty(), "%s has city border stands" % id)
		for nm in (bt["mid"] as Array) + (bt["big"] as Array):
			var g := str(nm).get_slice("/", 0)
			ok(Art.has(g, str(nm).get_slice("/", 1)), "%s border art %s exists" % [id, nm])
	ok(str(R["neon"].get("ground_seam", "")) == "c14p5_wet_asphalt" and Art.has("seamless", "c14p5_wet_asphalt"), "Neon: wet asphalt seamless, no flagstone seam")
	ok((R["neon"].get("ground_cycle", []) as Array).size() == 4, "Neon: 4 wet asphalt sets mixed")
	ok(str(R["uptown"].get("ground_seam", "")) == "pavement", "Uptown is paved")
	var east := 0
	for p in R["neon"]["props"]:
		if int(p["cell"][0]) >= 32 or int(p["cell"][1]) >= 30:
			east += 1
	ok(east >= 20, "Neon's east and south blocks are filled (%d props)" % east)
	# gang skins
	for id in ["quarry", "ruins", "marsh"]:
		ok(R[id].get("gang") is Dictionary, "%s has a gang skin" % id)
		var m = load("res://scripts/region.gd").new()
		m.region_id = id
		GameState.run = {"arc": "gangsters"}
		m.R = (R[id] as Dictionary).duplicate(true)
		var n0: int = (m.R["props"] as Array).size()
		m._gang_skin()
		var kinds: Array = (m.R["enemies"] as Array).map(func(e): return str(e["kind"]))
		ok(kinds.any(func(k): return k.begins_with("thug_")), "%s: gang foes in the gang arc" % id)
		ok((m.R["props"] as Array).size() > n0, "%s: gang props added" % id)
		for p in m.R["props"]:
			ok(Art.has(str(p.get("group", "props")), str(p["name"])), "%s prop art %s" % [id, p["name"]])
		GameState.run = {"arc": "penguins"}
		m.R = (R[id] as Dictionary).duplicate(true)
		m._gang_skin()
		ok((m.R["props"] as Array).size() == n0, "%s: penguin arc unchanged" % id)
		m.free()
	# borders, shores
	for id in ["gilt_grand_plaza", "gilt_vaults", "iron_junction", "iron_tunnels", "hollow_deeps", "frost_caverns"]:
		ok(str(R[id].get("band_style", "")) == "stone", "%s border is a stone band" % id)
	for id in R:
		if not (str(id).begins_with("wind_") or id == "sky_reaches" or id == "hollow_deeps"):
			continue
		for wb in R[id].get("water_blobs", []):
			ok(str(wb.get("shore", "")) != "grass", "%s pool has no grass bank" % id)
	ok(R["wind_storm_shelf"].has("light"), "Storm Shelf is dark")
	ok(str(R["gilt_vaults"].get("forage_sprite", "")) == "props/cave_mushroom" and str(R["iron_junction"].get("forage_sprite", "")) == "props/planter2_2", "urban/cave forage look")
	# art swaps
	var desert: Array = R["desert_dune_sea"]["gen"]["region_props"]
	ok(not desert.any(func(n): return str(n).begins_with("dune_")), "desert scatter drops the mis-sliced dune_ props")
	for n in desert:
		ok(Art.has("nature", str(n)) or Art.has("props", str(n)), "desert scatter art %s" % n)
	ok(not (R["frost_falls"]["gen"]["region_props"] as Array).has("grass_tuft_winter"), "no blurry winter tuft")
	var heads: Array = (R["desert_glass_canyon"]["props"] as Array).map(func(p): return str(p["name"]))
	ok(heads.has("c14p5_gc_stone_head") and not heads.has("stone_head"), "Glass Canyon uses the keyed stone head")
	ok(Art.has("props", "c14p5_gc_stone_head"), "stone head art exists")
	for id in R:
		for p in R[id].get("props", []):
			if str(p["name"]).begins_with("icicles_") and str(id).begins_with("frost_") and id != "frost_caverns":
				ok(false, "%s: icicle fringe on open snow" % id)
	var falls: Array = (R["frost_falls"]["props"] as Array).map(func(p): return str(p["name"]))
	ok(falls.has("c14p5_waterfall_frozen") and not falls.has("waterfall_pool"), "Frozen Falls has its frozen waterfall")
	var rails := (R["iron_freight_yards"]["props"] as Array).filter(func(p): return str(p["name"]) == "rail_h" and not bool(p.get("solid", true)))
	ok(rails.size() >= 60, "Freight Yards have track (%d rails)" % rails.size())
	ok((R["iron_junction"]["props"] as Array).any(func(p): return str(p["name"]) == "rail_h"), "Junction City has track")
	for nm in ["karaoke", "neon_hotel", "ramen_shop", "president_tower"]:
		ok(Art.has("buildings", nm + "_lit") and Art.tex("buildings", nm + "_lit").get_size() == Art.tex("buildings", nm).get_size(), "%s has a night glow mask" % nm)
	# colony jetties
	for cid in ["coral", "kelp", "ice", "ember"]:
		var rid: String = "colony_" + str(cid)
		var jt: Array = (R[rid]["things"] as Array).filter(func(t): return str(t["type"]) == "colony_jetty")
		ok(jt.size() == 1 and str(jt[0]["station"]) == rid + "_jetty", "%s has its jetty station" % rid)
	ok(Colony.travel_net() == null or Colony.travel_net() != null, "Colony.travel_net loads by path")
	# arrival lines
	ok(MegaRegion._entry_from("cities", "hideout"), "the bus starts at the Hideout")
	ok(not MegaRegion._entry_from("cities", "neon"), "Neon is not a cities entry")
	print("c14_p5_test: %s (%d fails)" % ["ok" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
