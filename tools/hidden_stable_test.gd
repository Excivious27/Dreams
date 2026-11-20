extends SceneTree
## C5 c5_17 #1: hidden pockets, secret ways and the Secrets chest/caches stay on the
## same cells day after day in one run (HiddenArea.recall/remember), even though the
## day's forage/ore change the free cells. Loads a handful of mega areas on several
## days and compares where the hidden things are.
##   godot --headless --path . -s res://tools/hidden_stable_test.gd
var fails := 0
const AREAS := ["gloam_violet_glade", "desert_dune_sea", "frost_caverns", "gilt_gardens", "desert_sunken_temple"]


func _initialize() -> void:
	Campaign.bypass = true
	seed(11)
	_run.call_deferred()


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	GameMap.next_facing = "down"
	GameState.run["scene"] = scene
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 10:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 8:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _where(m: GameMap) -> Dictionary:
	var out := {}
	for c: Vector2i in m.things:
		var t := str(m.things[c].get("type", ""))
		if t in ["hidden_mouth", "secret_way", "secret_chest", "secret_dig"]:
			out["%s:%s" % [t, str(m.things[c].get("key", ""))] + ("@%d,%d" % [c.x, c.y] if t == "secret_way" else "")] = c
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	var checked := 0
	for scene: String in AREAS:
		if not ResourceLoader.exists("res://scenes/%s.tscn" % scene):
			continue
		GameState.run["day"] = 3
		var first := _where(await _load(scene))
		if first.is_empty():
			print("  FAIL %s: nothing hidden placed" % scene)
			fails += 1
			continue
		for day in [4, 9, 17]:
			GameState.run["day"] = day
			seed(day * 31)  # forage/ore rolls differ per load
			var now := _where(await _load(scene))
			for k: String in first:
				if not now.has(k) or now[k] != first[k]:
					print("  FAIL %s day %d: %s moved %s -> %s" % [scene, day, k, str(first[k]), str(now.get(k, "gone"))])
					fails += 1
		checked += 1
		print("  %s: %d hidden things stayed put over 4 loads" % [scene, first.size()])
	if checked < 3:
		print("  FAIL only %d areas checked" % checked)
		fails += 1
	print("hidden_stable_test: %s (%d fails)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
