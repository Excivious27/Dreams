extends SceneTree
## C14b P4: magic and tech areas come alive.
##  * MagicFx: the crystal meadow, the moon and a Gloamwood area get a ground sparkle
##    layer and an air layer (veils/motes/glints); sparkles appear on game time at
##    different spots and staggered lives; reduced motion lowers the counts.
##  * RegionAnim: region strips play (no strip frozen unless listed still), neighbours
##    start on different frames/speeds, pop loops ping-pong (warp pad, star crater).
##   godot --headless --path . --fixed-fps 60 -s res://tools/c14b_p4_magic_test.gd
var fails := 0


func _initialize() -> void:
	seed(14)
	Campaign.bypass = true
	_run.call_deferred()


func fail(msg: String) -> void:
	print("  FAIL ", msg)
	fails += 1


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2(-1, -1)
	GameState.run["scene"] = scene
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 8:
		await process_frame
	var d := Dialogue.instance(self)
	for k in 6:
		if d.active:
			d._advance()
			await process_frame
	return current_scene as GameMap


func _wait_game(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		await process_frame
		gt += root.get_process_delta_time()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	# Pure helpers first.
	if MagicFx.bloom(0.0) != 0.0 or MagicFx.bloom(1.0) != 0.0 or MagicFx.bloom(0.5) < 0.99:
		fail("bloom must ease 0 -> 1 -> 0")
	if not RegionAnim.wants_anim({}, "props", "star_crater") and Art.has("props", "star_crater"):
		fail("a multi-frame strip should play by default")
	if Art.has("props", "windmill3") and RegionAnim.wants_anim({}, "props", "windmill3"):
		fail("jumbled windmill strip should stay still until split art exists")
	if RegionAnim.wants_anim({"still": true}, "props", "star_crater"):
		fail("'still' must win")
	if Art.has("props", "warp_pad"):
		var n := int(Art.info("props", "warp_pad").get("frames", 1))
		var sf := RegionAnim.frames_for("props", "warp_pad", 5.0)
		if n > 2 and sf.get_frame_count("idle") != n * 2 - 2:
			fail("warp pad should ping-pong: %d frames from %d" % [sf.get_frame_count("idle"), n])
		var plain := Art.frames("props", {"idle": "warp_pad"}, {"idle": 5.0})
		if plain.get_frame_count("idle") != n:
			fail("ping-pong changed the shared Art frames")
	for scene in ["crystal_meadow", "moon", "gloam_violet_glade"]:
		var m := await _load(scene)
		if m == null:
			fail("%s did not load" % scene)
			continue
		var air := m.get_node_or_null("MagicAir") as MagicFx
		var ground: MagicFx = null
		for n in m.find_children("MagicGround", "", true, false):
			ground = n as MagicFx
		if air == null or ground == null:
			fail("%s: magic layers missing (air %s, ground %s)" % [scene, air != null, ground != null])
			continue
		await _wait_game(4.0)
		if ground._sparks.size() < 3:
			fail("%s: only %d sparkles after 4 s" % [scene, ground._sparks.size()])
		var spots := {}
		var births := {}
		for s: Array in ground._sparks:
			spots[Vector2i(s[0])] = true
			births[snappedf(float(s[1]), 0.05)] = true
		if spots.size() < 3 or births.size() < 3:
			fail("%s: sparkles in lockstep (%d spots, %d birth times)" % [scene, spots.size(), births.size()])
		if scene == "crystal_meadow" and ground._glint_cells.is_empty():
			fail("crystal_meadow: no crystal props found to glint on")
		if air.count("motes") > 0 and air._motes.is_empty():
			fail("%s: no motes" % scene)
		var full := ground.count("spark")
		Settings.set_v("shake", false)
		if ground.count("spark") >= full and full > 1:
			fail("%s: reduced motion should lower the sparkle count" % scene)
		Settings.set_v("shake", true)
		# Game time stops while paused: sparkles don't age.
		paused = true
		var t0 := air.now()
		for i in 10:
			await process_frame
		if absf(air.now() - t0) > 0.001:
			fail("%s: magic time moved while paused" % scene)
		paused = false
	# Region strips: every multi-frame prop plays and neighbours differ.
	var m2 := await _load("gloam_violet_glade")
	var frames := {}
	var speeds := {}
	var playing := 0
	for a in m2.find_children("*", "AnimatedSprite2D", true, false):
		var asp := a as AnimatedSprite2D
		if asp.is_playing() and asp.sprite_frames and asp.sprite_frames.get_frame_count(asp.animation) > 1:
			playing += 1
			frames[asp.frame] = true
			speeds[snappedf(asp.speed_scale, 0.01)] = true
	if playing >= 3 and speeds.size() < 2:
		fail("region strips run in lockstep (%d playing, %d speeds)" % [playing, speeds.size()])
	# Colony: the star crystal carries a glow (dim before the restore).
	var mc := await _load("colony_coral")
	var glows := 0
	for n in mc.get_children():
		if n is RegionAnim.Glow:
			glows += 1
	if glows < 1:
		fail("colony_coral: no crystal glow")
	# Frostpeak: the snow hot spring steams.
	var mf := await _load("frost_hearthhold")
	var steam := 0
	for n in mf.find_children("*", "Node2D", true, false):
		if n is RegionAnim.Glow and n.mode == "steam":
			steam += 1
	if steam < 1:
		fail("frost_hearthhold: hot spring has no steam")
	# Moon: dusk tint and aurora.
	var mm := await _load("moon")
	if mm.get_node_or_null("MagicTint") == null:
		fail("moon: no dusk tint")
	if mm.sky and not mm.sky.aurora:
		fail("moon: aurora off")
	# Code motion: a boat bobs on game time (helper level, deterministic).
	var ra := RegionAnim.new()
	root.add_child(ra)
	var boat := Node2D.new()
	root.add_child(boat)
	ra.add(boat, "rowboat", Vector2i(3, 4))
	var ys := {}
	for i in 40:
		await process_frame
		ys[snappedf(boat.position.y, 0.5)] = true
	if ys.size() < 2 and not Settings.reduced_motion():
		fail("boat does not bob")
	print("c14b_p4_magic_test: %d failures" % fails)
	quit(1 if fails else 0)
