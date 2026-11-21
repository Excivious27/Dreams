extends SceneTree
## CONDUCT 11b P6: ranch buildings in each arc's words and per-tier footprints (scripts/builds.gd).
## Gangster arc: Roost / Stock Shed names, "The crew" builds, seller_gang kept by gen_stations;
## penguin arc keeps the storybook names; Builds.footprint reads a tier's own cell/w/h when it has one.
##   godot --headless --fixed-fps 60 --path . -s res://tools/builds_words_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(6)
	_run.call_deferred()

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(str(Builds.tier_def("coop", 1)["name"]) == "Coop" and Builds.label("barn") == "Barn", "penguin arc: storybook names")
	check(Builds.seller("coop") == "Hazel", "penguin arc: Hazel builds the coop")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	check(str(Builds.tier_def("coop", 1)["name"]) == "Roost" and str(Builds.tier_def("barn", 2)["name"]) == "Big Stock Shed", "gangster arc: its own tier names")
	check(Builds.label("coop") == "Roost", "gangster arc: its own label")
	check(str(Builds.tier_def("sty", 1)["name"]) == "Pig Pen", "gen_stations name_gang wins")
	check(Builds.seller("coop") == "The crew", "gangster arc: the crew builds (seller_gang)")
	check(str(Builds.all()["coop"]["tiers"][0]["name"]) == "Coop", "the data itself is never rewritten")
	# Footprints: building default, a tier override wins.
	var bd: Dictionary = Builds.all()["barn"]
	var fp := Builds.footprint("barn", 1)
	check(fp.position == Vector2i(int(bd["cell"][0]), int(bd["cell"][1])) and fp.size == Vector2i(int(bd["w"]), int(bd["h"])), "tier 1: the building's footprint")
	var save: Dictionary = (bd["tiers"][1] as Dictionary).duplicate()
	bd["tiers"][1]["w"] = 6
	bd["tiers"][1]["h"] = 4
	check(Builds.footprint("barn", 2).size == Vector2i(6, 4) and Builds.footprint("barn", 1).size.x == int(bd["w"]), "a tier row may grow the building")
	bd["tiers"][1] = save
	var fsrc := FileAccess.get_file_as_string("res://scripts/farm.gd")
	check(fsrc.contains("Builds.footprint(id)"), "farm draws buildings by their tier footprint")
	print("builds_words_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
