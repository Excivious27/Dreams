extends SceneTree
## C14b P5: character idle life. Heroes rest facing you on their front idle
## (never the side view), multi-frame idles exist for the up/side facings of
## the 12B heroes and the player uses them, idle strips hold the rest frame,
## IdleLife breathes on game time (feet anchored, stops when paused, softer
## under reduced motion, back to exact rest when moving), villagers' pose
## scheduler rests between gestures, pose pairs loop, and neighbours differ.
##   godot --headless --fixed-fps 60 --path . -s res://tools/c14b_p5_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL " + what)


func _initialize() -> void:
	seed(14)
	_run.call_deferred()


func _run() -> void:
	GameState.load_data()
	# 1. Front rest is the front idle for every hero/crew sheet with idle_down.
	for id: String in ["penguin_king", "penguin_wizard", "june", "nia", "marisol", "ollie", "june_gang", "rafe_gang", "nia_gang", "deuce", "doc", "big_jim"]:
		if not CharacterLibrary.has_character(id):
			continue
		var sf := CharacterLibrary.frames_for(id)
		check(sf.has_animation("idle") and sf.has_animation("idle_down"), id + " has idle + idle_down")
		if sf.has_animation("idle_down"):
			check(sf.get_frame_texture("idle", 0) == sf.get_frame_texture("idle_down", 0), id + ": resting facing you shows the front idle")
		var n := sf.get_frame_count("idle")
		check(n >= 2, id + ": idle has %d frames (needs 2+)" % n)
		if n >= 2:
			check(sf.get_frame_duration("idle", 0) > sf.get_frame_duration("idle", 1), id + ": rest frame held longer (a breath, not a tick)")
			check(sf.get_frame_duration("idle", 0) / sf.get_animation_speed("idle") >= 0.6, id + ": the rest frame lasts 0.6 s or more")
	# Blinks (tools/slice_c14b_p5.py) are woven into the front idle: one short
	# blink frame per loop, body pixels identical to the rest frame.
	var blinkers := 0
	for g: String in Art.manifest().keys():
		if not g.begins_with("characters/"):
			continue
		for an: String in (Art.manifest()[g] as Dictionary).keys():
			if not an.begins_with("c14bp5_blink_"):
				continue
			blinkers += 1
			var cid := g.get_file()
			var sf := CharacterLibrary.frames_for(cid)
			var n := sf.get_frame_count("idle")
			var short := 0
			for i in n:
				if sf.get_frame_duration("idle", i) < 1.0:
					short += 1
			check(short == 1, "%s: idle has one short blink frame (got %d of %d)" % [cid, short, n])
			var bimg := Art.tex(g, an).get_image()
			var src := an.trim_prefix("c14bp5_blink_")
			var oimg := Art.tex(g, src).get_image()
			check(bimg.get_size() == oimg.get_size(), "%s %s blink strip matches its idle's size" % [cid, an])
	check(blinkers >= 5, "blink frames exist for the heroes (%d)" % blinkers)
	# Bo's mis-cut idles are not used (c14b_14-07).
	var bo := CharacterLibrary.frames_for("bo")
	check(bo.get_frame_texture("idle", 0) == bo.get_frame_texture("view_front", 0), "bo rests on his clean front view")
	# 2. 12B heroes have multi-frame up/side idles and the player picks them.
	for id: String in ["penguin_king", "penguin_wizard"]:
		var sf := CharacterLibrary.frames_for(id)
		for a: String in ["idle_up", "idle_side"]:
			check(sf.get_frame_count(a) >= 2 and not CharacterLibrary.is_alias(sf, a), "%s %s is a real 2+ frame idle" % [id, a])
	var p := Player.new()
	root.add_child(p)
	p.set_character("penguin_king")
	check(p.idle_for("up") == "idle_up", "player facing up rests on idle_up (got %s)" % p.idle_for("up"))
	check(p.idle_for("right") == "idle_side", "player facing right rests on idle_side (got %s)" % p.idle_for("right"))
	p.facing = "left"
	p._show_idle()
	check(p.anim_name == "idle_side" and p._anim.flip_h, "facing left: idle_side mirrored")
	p.set_character("june")
	check(p.idle_for("up") == "idle_up", "june facing up rests on idle_up")
	p.queue_free()
	# 3. IdleLife: breath on game time, feet anchored, fades, reduced motion.
	var host := Node2D.new()
	root.add_child(host)
	var spr := Sprite2D.new()
	spr.scale = Vector2(0.5, 0.5)
	host.add_child(spr)
	var life := IdleLife.new()
	host.add_child(life)
	life.seed_from("t")
	life.active = true
	var lo := 9.0
	var hi := 0.0
	for i in 400:
		PlayClock.advance(1.0 / 60.0)
		life._process(1.0 / 60.0)
		lo = minf(lo, spr.scale.y)
		hi = maxf(hi, spr.scale.y)
	check(hi > 0.5 * 1.012 and lo < 0.5 * 0.988, "breath moves the sprite (%.4f..%.4f)" % [lo, hi])
	check(hi < 0.5 * 1.03, "breath stays subtle")
	check(spr.position == Vector2.ZERO, "feet stay planted")
	var full := hi - lo
	Settings.set_v("shake", false)
	lo = 9.0
	hi = 0.0
	for i in 400:
		PlayClock.advance(1.0 / 60.0)
		life._process(1.0 / 60.0)
		lo = minf(lo, spr.scale.y)
		hi = maxf(hi, spr.scale.y)
	check(hi - lo < full * 0.5, "reduced motion softens the breath")
	Settings.set_v("shake", true)
	life._process(1.0 / 60.0)
	var before := spr.scale
	life._process(1.0 / 60.0)  # game clock not advanced: no change in the breath
	check(absf(spr.scale.y - before.y) < 0.002, "breath follows the game clock")
	life.active = false
	for i in 60:
		PlayClock.advance(1.0 / 60.0)
		life._process(1.0 / 60.0)
	check(spr.scale == Vector2(0.5, 0.5), "moving: back to the exact rest scale")
	spr.scale = Vector2(0.7, 0.7)  # someone else rescales (a pose fit)
	life.active = true
	for i in 30:
		PlayClock.advance(1.0 / 60.0)
		life._process(1.0 / 60.0)
	check(absf(spr.scale.x - 0.7) < 0.02, "external scale becomes the new rest")
	var l2 := IdleLife.new()
	l2.seed_from("other")
	check(absf(l2.phase - life.phase) > 0.01 or absf(l2.period - life.period) > 0.01, "two characters breathe out of step")
	host.queue_free()
	# 4. Villagers: poses rest between gestures; pairs loop; neighbours differ.
	var ids: Array = GameState.npcs.keys()
	var a: Npc = null
	var b: Npc = null
	for id: String in ids:
		if Art.has("characters/npc_" + id, "work") and Art.has("characters/npc_" + id, "work_2"):
			var cells := Npc.pose_cells("characters/npc_" + id, "work")
			check(cells.size() >= 2, id + ": work + work_2 loop as a pair")
			break
	for id: String in ["maple", "wren", "gideon", "alder"]:
		if not GameState.npcs.has(id):
			continue
		var n := Npc.new()
		root.add_child(n)
		n.setup(id, GameState.npcs[id], Vector2(100, 100))
		n._wander_t = 9999.0
		if a == null:
			a = n
		elif b == null:
			b = n
	check(a != null and b != null and a._life != null, "villagers get IdleLife")
	if a and b:
		check(absf(a._life.phase - b._life.phase) > 0.01, "villagers breathe out of step")
		a.activity = "play"
		var poses := {}
		var gesture_run := 0.0
		var longest := 0.0
		for i in 60 * 40:
			a._t = 99.0
			a._process(1.0 / 60.0)
			poses[a._pose] = true
			if a._pose in Npc.GESTURES:
				gesture_run += 1.0 / 60.0
				longest = maxf(longest, gesture_run)
			else:
				gesture_run = 0.0
		check(poses.has(""), "a playing villager also rests (poses seen: %s)" % str(poses.keys()))
		check(poses.size() >= 2, "a playing villager changes pose")
		check(longest <= 5.1, "gestures are short (%.1f s)" % longest)
		check(a._life.active, "standing villager breathes")
	print("c14b_p5_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
