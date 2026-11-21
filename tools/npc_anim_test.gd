extends SceneTree
## Villager animation (CONDUCT 5 P5, c5_08): every original villager walks in
## their new design (never the old 48 px job chibi while a pose sheet exists),
## legs keep pace with a slow drift, a blocked villager stands, idles face the
## way they last walked or turned, kids are drawn shorter, poses use one size
## ratio per sheet (sitting is shorter), outfits skip base-outfit gestures,
## strips cut at another height keep the idle's size, and pose frames are one cell.
##   godot --headless --path . -s res://tools/npc_anim_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL " + what)


func _initialize() -> void:
	seed(5)
	_run.call_deferred()


func _make(id: String) -> Npc:
	var n := Npc.new()
	root.add_child(n)
	n.setup(id, GameState.npcs[id], Vector2(100, 100))
	n._wander_t = 9999.0
	return n


func _steps(n: Npc, frames: int) -> void:
	for i in frames:
		n._t = 99.0  # no routine re-apply mid-test
		n._process(1.0 / 60.0)


func _height(n: Npc) -> float:
	var t := n._anim.sprite_frames.get_frame_texture(n._anim.animation, 0)
	return t.get_height() * n._anim.scale.y


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 3  # spring, not a festival
	var ids := ["maple", "gideon", "wren", "alder", "sal", "finn", "lumi", "theo", "hazel", "bram", "posy", "juniper", "rook", "pip", "wren_jr", "tobin"]
	# 1. New design walkers for all 16.
	for id: String in ids:
		var d: Dictionary = GameState.npcs[id]
		var job := str(d.get("sprite", ""))
		var w := Npc.walker_for(id, job, job)
		check(w != job and w.begins_with("npc_" + id), "%s walks as their new design (got %s)" % [id, w])
		check(CharacterLibrary.has_character(w), "%s walker %s exists" % [id, w])
		check(w == "npc_%s_base" % id, "%s has a base-outfit walker (got %s)" % [id, w])
	check(Npc.walker_for("wren_jr", "npc_child_girl_a", "npc_child_girl_a") == "npc_wren_jr_base", "wren_jr has her own base walker")
	# 2. Kids.
	for id: String in ["pip", "wren_jr", "tobin", "mabel"]:
		check(Npc.is_kid(id), "%s is a kid" % id)
	for id: String in ["maple", "rook", "bram"]:
		check(not Npc.is_kid(id), "%s is grown up" % id)
	var maple := _make("maple")
	var pip := _make("pip")
	check(maple._anim != null and pip._anim != null, "sprites made")
	if maple._anim == null or pip._anim == null:
		_done()
		return
	var hm := _height(maple)
	var hp := _height(pip)
	check(absf(hm - CharacterLibrary.NPC_H) < 1.5, "maple stands ~24 px (%.1f)" % hm)
	check(absf(hp - Npc.KID_H) < 1.5, "pip stands ~18 px (%.1f)" % hp)
	# 3. Walking: leg pace and direction.
	check(absf(Npc.walk_speed_scale(18.0) - 0.45) < 0.01 and Npc.walk_speed_scale(60.0) == 1.0, "walk_speed_scale clamps")
	maple._target = maple.position + Vector2(30, 0)
	_steps(maple, 10)
	check(maple._anim.animation == "walk", "walks sideways (%s)" % maple._anim.animation)
	check(maple._anim.speed_scale < 0.6, "slow drift near home steps slowly (%.2f)" % maple._anim.speed_scale)
	check(not maple._anim.flip_h, "walking right is not flipped")
	maple._target = maple.position + Vector2(0, -30)
	_steps(maple, 10)
	check(maple._anim.animation == "walk_up", "walks up (%s)" % maple._anim.animation)
	maple._target = maple.position
	_steps(maple, 5)
	check(maple._anim.animation == "idle_up", "rests facing up after walking up (%s)" % maple._anim.animation)
	maple.face(maple.position + Vector2(-20, 0))
	check(maple._anim.animation == "idle_side" and maple._anim.flip_h, "face() turns to a left side idle (%s)" % maple._anim.animation)
	maple.face(maple.position + Vector2(0, 20))
	check(maple._anim.animation == "idle", "face() down = front idle")
	# 4. Per-animation size: every walker strip shows at the idle's height.
	if GameState.npcs.has("mabel"):
		var mab := _make("mabel")
		var h0 := _height(mab)
		mab._play_walker("walk")
		var h1 := _height(mab)
		check(absf(h1 - h0) < 1.0, "mabel's walk keeps the idle size (%.1f vs %.1f)" % [h1, h0])
	# 5. Poses: one ratio per sheet; sitting is shorter than standing.
	var g := "characters/npc_maple"
	var idle_h := maple._idle_h()
	var stand := Npc.pose_ratio(g, "talk", idle_h) * float(Art.info(g, "talk")["cell_h"])
	var sit := Npc.pose_ratio(g, "sit", idle_h) * float(Art.info(g, "sit")["cell_h"])
	check(sit < stand * 0.85, "sitting is drawn shorter than standing (%.1f vs %.1f)" % [sit, stand])
	check(absf(stand - idle_h) < idle_h * 0.12, "a standing pose is about the walker's height")
	# 6. Outfit skips base-outfit gestures but keeps activity poses.
	GameState.run["day"] = 3 + 28  # summer: no summer sheet for maple (spring has one since C15 P3)
	var ms := _make("maple")
	check(not ms.in_outfit() and ms.pose_ok("wave"), "maple in her base walker plays every pose")
	GameState.run["day"] = 3 + 28 * 3  # winter: her winter coat
	var mw := _make("maple")
	check(mw._walker == "npc_maple_winter" and mw.in_outfit(), "winter maple wears her coat (%s)" % mw._walker)
	maple = mw
	GameState.run["day"] = 3
	if maple.in_outfit():
		check(not maple.pose_ok("wave") and maple.pose_ok("sit"), "outfit: wave skipped, sit kept")
	var wj := _make("wren_jr")
	check(not wj.in_outfit() and wj.pose_ok("wave"), "wren_jr in her base design plays every pose")
	wj.set_pose("wave")
	check(str(wj._anim.animation).begins_with("pose_npc_wren_jr"), "wren_jr's pose comes from her own sheet")
	# 7. Broken cells: redrawn ones show, the rest borrow a walk frame.
	check(Npc.bad_cell("npc_bram_festival", "idle") and not Npc.bad_cell("npc_mabel", "idle"), "BAD_CELLS lists only what's still broken")
	if GameState.npcs.has("benno"):
		var bn := _make("benno")
		bn.set_pose("counter")
		check(bn._pose == "counter", "benno's resliced counter pose plays")
		check(int(Art.info("characters/npc_benno", "sleep").get("w", 0)) > int(Art.info("characters/npc_benno", "talk").get("w", 0)), "benno's sleep cell is the bed (w490 reslice)")
	# 8. Pose frame 0 of a multi-frame strip is one cell.
	var multi := ""
	for k: String in Art.manifest().get("characters/catkins", {}).keys():
		if int(Art.info("characters/catkins", k).get("frames", 1)) > 1:
			multi = k
			break
	if multi != "":
		var t := Npc.first_frame("characters/catkins", multi)
		check(t is AtlasTexture and t.get_width() == int(Art.info("characters/catkins", multi)["cell_w"]), "first_frame is one cell")
	_done()


func _done() -> void:
	print("npc_anim_test: %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
