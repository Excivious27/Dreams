extends SceneTree
## Animation sanity (Round 13): heroes rest facing the way they walked, the
## penguins' side walk never turns to face you, critter strips hold one animal,
## farm babies use usable art, and every animated strip keeps its feet planted.
##   godot --headless --path . -s res://tools/anim_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL " + what)


func _initialize() -> void:
	_run.call_deferred()


func _region(sf: SpriteFrames, a: String, i := 0) -> Rect2:
	var t := sf.get_frame_texture(a, i) as AtlasTexture
	return t.region if t else Rect2()


func _run() -> void:
	# 1. The 12B heroes drew "idle" as a side view: "idle" must now be the front
	#    (idle_down) pose, with the side one kept as idle_side.
	for id: String in ["penguin_king", "penguin_wizard", "coldy", "big_jim", "merry", "coco", "mer"]:
		var sf := CharacterLibrary.frames_for(id)
		check(sf.has_animation("idle") and sf.has_animation("idle_down"), "%s has idle + idle_down" % id)
		if sf.has_animation("idle_down"):
			check(sf.get_frame_texture("idle", 0) == sf.get_frame_texture("idle_down", 0), "%s: idle is the front pose" % id)
			check(sf.has_animation("idle_side"), "%s: side idle kept as idle_side" % id)
		# A left rest is a real left view or the mirrored right one: never an unflipped copy.
		if sf.has_animation("view_left") and sf.has_animation("view_right"):
			var l := sf.get_frame_texture("view_left", 0)
			var r := sf.get_frame_texture("view_right", 0)
			check(l != r and (l.get_image() == null or r.get_image() == null or l.get_image().get_data() != r.get_image().get_data()), "%s: view_left is not a copy of view_right" % id)
	# 2. The penguins' redrawn walks: 6 side steps, 4 toward, 4 away.
	for id: String in ["penguin_king", "penguin_wizard"]:
		var sf := CharacterLibrary.frames_for(id)
		check(sf.get_frame_count("walk") == 6, "%s walk has 6 side frames (got %d)" % [id, sf.get_frame_count("walk")])
		check(sf.get_frame_count("walk_down") == 4 and sf.get_frame_count("walk_up") == 4, "%s has 4-frame toward/away walks" % id)
		for v in ["view_front", "view_back", "view_right"]:
			check(Art.has("characters/" + id, v), "%s has its own %s" % [id, v])
	# 3. Critter strips hold one animal: the town cats' idle frames share a coat.
	for col: String in ["grey", "orange", "black"]:
		var info := Art.info("wildlife/cat_" + col, "idle")
		var tex := Art.tex("wildlife/cat_" + col, "idle")
		check(tex != null and int(info.get("frames", 0)) == 4, "cat_%s idle has 4 poses" % col)
		if tex:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			var cw := int(info["cell_w"])
			var means: Array[Color] = []
			for i in int(info["frames"]):
				var sum := Color(0, 0, 0, 0)
				var n := 0
				for y in range(0, img.get_height(), 2):
					for x in range(i * cw, (i + 1) * cw, 2):
						var c := img.get_pixel(x, y)
						if c.a > 0.5:
							sum += c; n += 1
				means.append(sum / maxf(1.0, float(n)))
			for i in range(1, means.size()):
				var d := absf(means[i].r - means[0].r) + absf(means[i].g - means[0].g) + absf(means[i].b - means[0].b)
				check(d < 0.35, "cat_%s frame %d is the same cat (colour diff %.2f)" % [col, i, d])
	# 4. Farm babies: the chick uses the hen's baby strip; the calf has its own art.
	check(FarmAnimal.BABY_OF.has("chick") and Art.has("animals/chicken2", "baby"), "chick uses chicken2/baby")
	check(int(Art.info("animals/calf", "walk").get("frames", 0)) == 4 and Art.has("animals/calf", "eat"), "calf has its redrawn idle/walk/eat")
	# 5. Redrawn wildlife: the deer walks in 6 frames and grazes in 4; tails stay on.
	check(int(Art.info("wildlife/deer", "walk").get("frames", 0)) == 6, "deer walk has 6 frames")
	check(int(Art.info("wildlife/deer", "idle").get("frames", 0)) == 4, "deer idle (graze) has 4 frames")
	check(int(Art.info("wildlife/fox", "walk").get("frames", 0)) == 4, "fox walk has 4 frames")
	# 6. Player speed was trimmed (~10%).
	check(Player.WALK_SPEED <= 53.0 and Player.WALK_SPEED >= 50.0, "walk speed trimmed (%.0f)" % Player.WALK_SPEED)
	check(Player.RUN_SPEED > Player.WALK_SPEED * 1.5, "running still clearly faster")
	# 7. The Marked (tools/reslice_marked.py): one figure per frame, centred
	#    (no seam-cut halves), a 6-frame power strip, no back-view attack faked
	#    from other poses, and the power pose plays for a Gift move.
	for c: String in ["kit", "ember", "dahlia", "juno", "rio", "mei", "bruno", "tomas", "sable", "atlas"]:
		var id := "mk_" + c
		var sf := CharacterLibrary.frames_for(id)
		check(sf.has_animation("power") and sf.get_frame_count("power") == 6, "%s: 6-frame power strip" % id)
		check(not sf.get_animation_loop("power"), "%s: power plays once" % id)
		check(not Art.has("characters/" + id, "attack_up"), "%s: no fake attack_up strip" % id)
		check(sf.get_frame_count("walk") >= 4, "%s: walk has 4+ frames" % id)
		for a: String in ["idle", "walk", "walk_down", "walk_up", "sit", "wave", "view_right", "power"]:
			if not sf.has_animation(a):
				check(false, "%s has %s" % [id, a])
				continue
			for i in sf.get_frame_count(a):
				var img := sf.get_frame_texture(a, i).get_image()
				if img == null:
					continue
				var sx := 0.0
				var n := 0.0
				for y in range(0, img.get_height(), 2):
					for x in img.get_width():
						if img.get_pixel(x, y).a > 0.5:
							sx += x
							n += 1.0
				var cx := sx / maxf(1.0, n) / float(img.get_width())
				check(n > 150.0, "%s %s frame %d holds a figure" % [id, a, i])
				if a != "power":
					check(cx > 0.3 and cx < 0.7, "%s %s frame %d is centred (%.2f)" % [id, a, i, cx])
	# 8. C5 P4: gangster heroes fish with the drawn rod pose any way they face
	#    and pour water from a standing pose, never a punch (c5_15 #4/#5).
	for id: String in ["june_gang", "ollie_gang", "rafe_gang"]:
		var sf := CharacterLibrary.frames_for(id)
		var al: Dictionary = sf.get_meta("aliased", {})
		for an: String in ["cast_down", "cast_up", "reel_down", "reel_up", "reel_right"]:
			if al.has(an):
				check(str(al[an]) in ["cast_right", "reel_right"], "%s %s borrows the rod pose (got %s)" % [id, an, al[an]])
		for an: String in ["water_down", "water_up", "water_right"]:
			if al.has(an):
				check(not str(al[an]).begins_with("attack"), "%s %s is no punch (got %s)" % [id, an, al[an]])
	# 9. C5 P4: crew strips rebuilt - walk_down frames hold whole figures and
	#    the twins' view_front is a front view (c5_06 #3).
	for c: String in ["deuce", "vic", "val", "specs", "sasha"]:
		var info := Art.info("characters/" + c, "walk_down")
		var img := Art.tex("characters/" + c, "walk_down").get_image()
		if img.is_compressed():
			img.decompress()
		var cw := int(info["cell_w"])
		for i in int(info["frames"]):
			var xs: Array[int] = []
			for x in range(i * cw, (i + 1) * cw):
				for y in range(0, img.get_height(), 3):
					if img.get_pixel(x, y).a > 0.5:
						xs.append(x - i * cw)
						break
			check(xs.size() > cw * 0.45 and xs.min() > 0 and xs.max() < cw - 1, "%s walk_down frame %d is a whole figure" % [c, i])
	for c: String in ["vic", "val"]:
		var f := Art.tex("characters/" + c, "view_front").get_image()
		var d := Art.tex("characters/" + c, "idle_down").get_image()
		check(f.get_width() * 2 == d.get_width() or f.get_width() == int(Art.info("characters/" + c, "idle_down")["cell_w"]), "%s view_front is the front idle" % c)
	GameState.load_data()  # enemies.json (GameState is static: nothing loads it in a bare tree)
	# 10. C5 P4: thugs stand at hero height (heroes are drawn 24 px; c5_06 #1
	#     measured 0.5-scale cells against unscaled hero cells, so no data scale).
	for k: String in ["thug_brute", "thug_cyber", "thug_lookout"]:
		var th := Enemy.new()
		th.setup(k)
		var tex := th._sprite.sprite_frames.get_frame_texture("idle", 0) if th._sprite else null
		var hgt := float(tex.get_height()) * th._sprite.scale.y if tex else 0.0
		check(hgt >= 20.0 and hgt <= 32.0, "%s drawn %.0f px tall (heroes are 24)" % [k, hgt])
		th.free()
	var ember := Enemy.new()
	ember.setup("marked_ember")
	check(ember._sprite != null and ember._sprite.sprite_frames.has_animation("power"), "marked_ember loads its power pose")
	ember.play_power()
	check(ember._power_t > 0.4 and ember._sprite.animation == "power", "a Gift move plays the power pose")
	ember.free()
	print("anim_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
