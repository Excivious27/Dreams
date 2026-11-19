extends SceneTree
## Footsteps follow the ground: lawns and meadows step on grass, roads and
## plazas on stone, docks on wood, tilled soil on dirt (Footsteps.word).
##   godot --headless --path . -s res://tools/footstep_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	InputSetup.ensure_actions()
	GameState.load_data()
	_run.call_deferred()


func _share(m: GameMap) -> Dictionary:
	var cnt := {}
	var n := 0
	for y in m.rows:
		for x in m.cols:
			var c := Vector2i(x, y)
			if m.blocked.has(c) or not m.in_content(c):
				continue
			var w := Footsteps.word(m, c)
			cnt[w] = int(cnt.get(w, 0)) + 1
			n += 1
	var out := {}
	for k in cnt:
		out[k] = float(cnt[k]) / maxf(1.0, n)
	return out


func _run() -> void:
	# [scene, arc, word, min share, max share]
	var cases := [
		["town", "penguins", "grass", 0.3, 1.0], ["town", "penguins", "stone", 0.03, 0.6],
		["uptown", "gangsters", "grass", 0.2, 1.0], ["uptown", "gangsters", "stone", 0.02, 0.8],
		["highlands", "penguins", "grass", 0.4, 1.0], ["meadow", "penguins", "grass", 0.5, 1.0],
		["farm", "penguins", "grass", 0.4, 1.0], ["neon", "gangsters", "stone", 0.5, 1.0],
		["docks", "gangsters", "stone", 0.4, 1.0], ["docks", "gangsters", "wood", 0.03, 0.6], ["beach", "penguins", "sand", 0.99, 1.0]]
	var shares := {}
	for cs: Array in cases:
		var key := "%s/%s" % [cs[1], cs[0]]
		if not shares.has(key):
			GameState.new_run(str(cs[1]), "man", "Tester", "Dreamhollow", "Pip")
			GameState.run["intro_done"] = true
			for f in ["cm_seen", "mine_open_1", "meow_taught", "intro_done", "gangsters_intro", str(cs[0]) + "_seen"]:
				GameState.run["flags"][f] = true
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/%s.tscn" % cs[0])
			for i in 6:
				await process_frame
			var m := current_scene as GameMap
			shares[key] = _share(m) if m else {}
			print("%s: %s" % [key, str(shares[key])])
		var s: float = float(shares[key].get(cs[2], 0.0))
		check(s >= float(cs[3]) and s <= float(cs[4]), "%s %s share %.2f not in [%.2f, %.2f]" % [key, cs[2], s, cs[3], cs[4]])
	# Words map to real sounds.
	for w: String in ["grass", "dirt", "sand", "stone", "wood", "snow", "water", "mud", "gravel", "leaves"]:
		check(ResourceLoader.exists("res://audio/sfx/step_%s.ogg" % w), "step_%s exists" % w)
	print("footstep_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
