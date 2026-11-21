extends SceneTree
## C14b P6: creature / foe / animal idle life.
##   godot --headless --path . --fixed-fps 60 -s res://tools/creature_life_test.gd
## - The President's idle is 4 frames (no back view in the loop).
## - Foe idles: mixed-pose idles rest on frame 0, 2-frame idles are held (not a 5 fps flip),
##   Art's shared SpriteFrames are never mutated, foes of one kind don't start in lockstep.
## - Farm animals hold the rest frame >= 2.5 s; kid_goat draws from the goat strip.
## - Wild critters: random start (no lockstep), perching birds sit on the ground when calm,
##   fish are hidden under ripples, sizes vary; game time only.
## - Reduced motion lowers the breath amplitude.
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(11)
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	# 1. President idle.
	check(int(Art.info("characters/president", "idle").get("frames", 0)) == 4, "president idle has 4 frames")
	# 2. Foe idle tuning.
	var sf_slime := Art.frames("enemies/slime", {"idle": "idle"}, {"idle": 5.0})
	var n_before := sf_slime.get_frame_count("idle")
	var still := Enemy.idle_frames(sf_slime, "slime")
	check(still.get_frame_count("idle") == 1, "slime idle rests on frame 0")
	check(sf_slime.get_frame_count("idle") == n_before, "Art's slime SpriteFrames untouched")
	var sf_thug := Art.frames("characters/president", {"idle": "idle"}, {"idle": 5.0})
	var sf_two := Art.frames("characters/lt_brock", {"idle": "idle"}, {"idle": 5.0}) if Art.has("characters/lt_brock", "idle") else null
	if sf_two and sf_two.get_frame_count("idle") == 2:
		var held := Enemy.idle_frames(sf_two, "lt_brock")
		var dur := held.get_frame_duration("idle", 0) / held.get_animation_speed("idle")
		check(dur >= 0.9, "2-frame foe idle is held (%.2f s)" % dur)
	check(sf_thug.get_frame_count("idle") == 4, "president strip loads 4 frames")
	var frames_seen := {}
	var speeds := {}
	for i in 8:
		var e := Enemy.new()
		e.setup("grump")
		if e._sprite:
			frames_seen[e._sprite.frame * 100 + int(e._sprite.frame_progress * 10)] = true
			speeds[snappedf(e._sprite.speed_scale, 0.001)] = true
		e.free()
	check(frames_seen.size() >= 3 and speeds.size() >= 3, "grumps start out of step (%d starts, %d speeds)" % [frames_seen.size(), speeds.size()])
	# 3. Farm animal holds.
	var sf_cow := Art.frames("animals/cow_brown", {"idle": "idle"}, {"idle": 3.0}) if Art.has("animals/cow_brown", "idle") else null
	if sf_cow and sf_cow.get_frame_count("idle") >= 2:
		var hf := FarmAnimal.idle_frames(sf_cow, 3)
		check(hf.get_frame_duration("idle", 0) / hf.get_animation_speed("idle") >= 2.5, "cow holds its rest frame")
		check(hf.get_frame_duration("idle", 1) / hf.get_animation_speed("idle") <= 0.3, "cow's blink frame is short")
	check(FarmAnimal.BABY_OF.has("kid_goat") and "kid_goat" in FarmAnimal.SCRAP_ART, "kid_goat drawn from the goat strip")
	# 4. Reduced motion.
	Settings.set_v("shake", true)
	var full := absf(CreatureMotion.breath(0.25, 0.03, 2.0).y - 1.0) + absf(CreatureMotion.breath(0.75, 0.03, 2.0).y - 1.0)
	Settings.set_v("shake", false)
	var calm := absf(CreatureMotion.breath(0.25, 0.03, 2.0).y - 1.0) + absf(CreatureMotion.breath(0.75, 0.03, 2.0).y - 1.0)
	Settings.set_v("shake", true)
	check(calm < full * 0.5 or full == 0.0, "reduced motion lowers breath (%.4f vs %.4f)" % [calm, full])
	var wet_pool := WorldGen.critter_pool(["butterfly_orange", "bee", "rabbit"], 0, 0, 1)
	check(not wet_pool.has("butterfly_orange") and not wet_pool.has("bee") and wet_pool.has("rabbit"), "no butterflies or bees out in the rain")
	# 5. Wild critters on live maps.
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for s: String in ["meadow", "lake", "farm"]:
		GameState.run["flags"][s + "_seen"] = true
		GameMap.next_spawn = Vector2.ZERO
		GameState.run["scene"] = s
		change_scene_to_file("res://scenes/%s.tscn" % s)
		for i in 8:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			continue
		if m.player:
			m.player.position = Vector2(-4000, -4000)
		var gt := 0.0
		while gt < 3.0:
			await process_frame
			gt += root.get_process_delta_time()
		var starts := {}
		var sizes := {}
		var n := 0
		for c in m.get_children():
			if not (c is WorldGen.Critter):
				continue
			var cr := c as WorldGen.Critter
			if cr._anim == null:
				continue
			n += 1
			starts[str(cr._anim.frame) + ":" + str(snappedf(cr._anim.frame_progress, 0.05)) + ":" + str(snappedf(cr._anim.speed_scale, 0.01))] = true
			sizes[snappedf(cr._sz, 0.001)] = true
			if cr._percher and not cr._flee and cr._away <= 0.0:
				check(cr._lift < 3.0, "%s %s sits on the ground when calm (lift %.1f)" % [s, cr.kind, cr._lift])
			if cr.kind in WorldGen.WATER_CRITTERS and cr._leap < 0.0:
				check(not cr._anim.visible, "%s fish hidden under its ripples between leaps" % s)
		if n >= 3:
			check(starts.size() >= mini(n, 3), "%s critters out of step (%d/%d)" % [s, starts.size(), n])
			check(sizes.size() >= 2, "%s critters vary in size" % s)
		print("%s: %d critters" % [s, n])
	print("creature_life_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
