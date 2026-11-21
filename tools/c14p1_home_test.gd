extends SceneTree
## C14 P1 home-region shapes (WorldGen.home_build / home_dress / crop_rows):
##  - Riverlands has a real river: one winding body joined to its ponds, a walkable
##    deck where the main path crosses (bridge prop over it), and it runs out
##    through the border band (c14_02-13 / c14_14-01);
##  - Orchard Hills plants rows of fruit trees (c14_02-08);
##  - the Highway's corn is a daytime crop field by season, snow ground and no corn
##    in winter (c14_02-01 / c14_02-03);
##  - Highlands has no wide snow fields in spring (c14_14-05);
##  - no dead-end "milestone" (gravestone) and no green hedge in winter bands.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/c14p1_home_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(14)
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _load(s: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameState.run["scene"] = s
	GameState.run["flags"][s + "_seen"] = true
	change_scene_to_file("res://scenes/%s.tscn" % s)
	for i in 10:
		await process_frame
	return current_scene as GameMap


func _crop_props(m: GameMap) -> int:
	var texs := []
	for st in ["young", "growing", "mature", "ready"]:
		var t := Art.tex("crops", "corn_" + st)
		if t != null:
			texs.append(t)
	var n := 0
	for c in m.props:
		var sp: Variant = m.props[c]
		if sp is Sprite2D and is_instance_valid(sp) and texs.has((sp as Sprite2D).texture):
			n += 1
	return n


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 10  # spring
	GameState.run["time"] = 11 * 60

	_check(not WorldGen.DEAD_END_LOOKS.has("milestone"), "dead-end looks never use the gravestone-like milestone")

	var m := await _load("riverlands")
	var water := 0
	var river := 0
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "water":
			water += 1
			if bool(m.things[c].get("river", false)):
				river += 1
	_check(river >= 120, "riverlands has a river (%d river cells)" % river)
	var decks: Dictionary = m.get_meta("river_decks", {})
	_check(decks.size() >= 4, "the main path crosses the river on a deck (%d cells)" % decks.size())
	for c: Vector2i in decks:
		_check(not m.blocked.has(c), "deck cell %s is walkable" % c)
	var edge := 0
	for c: Vector2i in m.border_water_extra:
		if c.y >= m.rows - 1 or c.x >= m.cols - 1:
			edge += 1
	_check(edge >= 2, "the river runs out through the border band (%d edge cells)" % edge)
	_check(m.border_water_shore == "river", "river shore look")
	# One body: every water thing shares the river shore (ponds joined to it).
	var shores := {}
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "water":
			shores[str(m.things[c].get("shore", ""))] = true
	_check(shores.keys() == ["river"], "ponds and river share one shore look: %s" % [shores.keys()])

	m = await _load("orchard_hills")
	var fruit := 0
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "fruit" and Rect2i(26, 13, 23, 17).has_point(c):
			fruit += 1
	_check(fruit >= 12, "orchard hills has orchard rows (%d trees)" % fruit)

	GameState.run["arc"] = "gangsters"
	m = await _load("countryside")
	_check(_crop_props(m) >= 100, "the Highway has a daytime corn field in spring (%d stalks)" % _crop_props(m))
	_check(not str((m.get("R") as Dictionary).get("layers", [])).contains("cornfield_night"), "no night corn tile in the day")
	GameState.run["day"] = 3 * GameState.DAYS_PER_SEASON + 5  # winter
	m = await _load("countryside")
	_check(_crop_props(m) == 0, "no standing corn in winter")
	_check(str((m.get("R") as Dictionary).get("ground_seam", "")) == "snow", "the Highway verge is snow in winter")
	var hedge := Art.tex("nature", "hedge")
	var green := 0
	for c in m.props:
		var sp: Variant = m.props[c]
		if hedge != null and sp is Sprite2D and is_instance_valid(sp) and (sp as Sprite2D).texture == hedge and m._border_cells.has(c):
			green += 1
	_check(green == 0, "no green hedge in a winter border band (%d)" % green)

	GameState.run["arc"] = "penguins"
	GameState.run["day"] = 10
	m = await _load("highlands")
	var rd: Dictionary = (m.get("R") as Dictionary)
	_check(str(rd.get("patch_set", "")) != "snowpatch", "highlands spring has no wide snow patch set")
	var snow_r := 0.0
	for fb in rd.get("feature_blobs", []):
		if str(fb["set"]) == "snowpatch":
			for b in fb["blobs"]:
				snow_r += float(b["r"])
	_check(snow_r <= 8.0, "highlands keeps only small snow remnants (radius sum %.1f)" % snow_r)

	print("c14p1_home_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
