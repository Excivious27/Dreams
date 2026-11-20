extends SceneTree
## Themed battlefields (CONDUCT 3 P4, tools/bf_themes.py): every bf_* field loads,
## its points sit on open dry ground, north points stay clear of the HUD (row >= 24),
## a walk exists from the camp to every point, tree-less themes (decks, pavement,
## sewers, sky) grow no tree clumps, and the grump variant / kin / pylon art exists.
##   godot --headless --path . -s res://tools/bf_themes_test.gd
var fails := 0


func _fail(msg: String) -> void:
	fails += 1
	print("BF FAIL ", msg)


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	for v in ["crystal", "storm", "frost", "coral", "ember", "moss", "brute", "wisp"]:
		for a in ["idle", "walk", "attack", "hurt"]:
			if not Art.has("enemies/grump_" + v, a):
				_fail("art enemies/grump_%s %s missing" % [v, a])
	for a in ["idle", "walk", "act"]:
		for i in 4:
			if Art.tex("helpers", "crystal_kin_crystal_%s_%d" % [a, i]) == null:
				_fail("art helpers crystal_kin %s %d" % [a, i])
	for nm in ["crystal_pylon", "crystal_pylon_2", "bf_cairn", "bf_ruin_pillar", "bf_ruin_wall", "bf_weir_gate", "bf_sky_pillar", "bf_sewer_mouth"]:
		if Art.tex("props", nm) == null:
			_fail("art props/" + nm)
	var ids: Array = RegionData.all().keys()
	var n := 0
	for id in ids:
		if not str(id).begins_with("bf_"):
			continue
		n += 1
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/%s.tscn" % id)
		for k in 6:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			_fail("%s did not load" % id)
			continue
		var R: Dictionary = m.get("R")
		var pts: Array = R["battle"]["points"]
		var camp := Vector2i.ZERO
		for p in pts:
			var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
			if str(p["owner"]) == "ally":
				camp = c
			if c.y < 24:
				_fail("%s point %s at row %d (under the HUD)" % [id, p["name"], c.y])
			if m.is_water_cell(c):
				_fail("%s point %s in water" % [id, p["name"]])
		# a walk from the camp to every point (blocked cells and deep water stop it)
		var seen := {camp: true}
		var q: Array = [camp]
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc := c + d
				if seen.has(nc) or not m.in_content(nc) or m.blocked.has(nc) or m.is_water_cell(nc):
					continue
				seen[nc] = true
				q.append(nc)
		for p in pts:
			var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
			var ok := false
			for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if seen.has(c + d):
					ok = true
			if not ok:
				_fail("%s point %s not reachable from the camp" % [id, p["name"]])
		var th: Dictionary = (R.get("gen", {}) as Dictionary).get("theme", {})
		if th.has("trees") and (th["trees"] as Array).is_empty():
			var trees := 0
			for c in m.things:
				if str(m.things[c].get("type", "")) == "tree":
					trees += 1
			if trees > 0:
				_fail("%s: tree-less theme grew %d trees" % [id, trees])
	if n < 19:
		_fail("only %d battlefields" % n)
	print("bf_themes_test: %d fields, %d failures" % [n, fails])
	quit(1 if fails > 0 else 0)
