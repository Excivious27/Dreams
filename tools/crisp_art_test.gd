extends SceneTree
## CONDUCT 2 P7: art-quality hooks.
##   godot --headless --path . -s res://tools/crisp_art_test.gd
## - the Big Grump boss card is the storm-cloud banner (764x322), not the old man card
## - GameMap.prop() gives buildings/props/nature the shared sharp-pixel material (CrispArt)
## - every mine stone/ore prop is crispened (hard alpha, no half-transparent fringe)
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	var t := Art.tex("ui", "card_big_grump")
	check(t != null and t.get_width() == 764 and t.get_height() == 322, "card_big_grump is the 764x322 banner")
	if t:
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		# the Grump is purple-grey cloud: the left half must be mostly cool/purple, not skin tones
		var purple := 0
		var skin := 0
		for y in range(60, 300, 6):
			for x in range(60, 380, 6):
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				if c.b > c.g + 0.05 and c.r > c.g:
					purple += 1
				elif c.r > 0.75 and c.g > 0.5 and c.b < 0.55 and c.r > c.b + 0.25:
					skin += 1
		check(purple > skin * 3, "card_big_grump shows the cloud (purple %d vs skin %d)" % [purple, skin])
	var mat := CrispArt.material()
	check(mat != null and mat.shader != null, "sharp_pixel shader loads")
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	var scn := load("res://scenes/town.tscn") as PackedScene
	var m := scn.instantiate()
	root.add_child(m)
	for i in 3:
		await process_frame
	var n_b := 0
	var n_crisp := 0
	for s in m.get("_bprops"):
		var sp: Sprite2D = s[3]
		if is_instance_valid(sp):
			n_b += 1
			if sp.material == mat:
				n_crisp += 1
	check(n_b > 0 and n_crisp == n_b, "town buildings use CrispArt (%d/%d)" % [n_crisp, n_b])
	# CONDUCT 5 (c5_05 #3 #4 #6): characters/animals and baked ground chunks are crisp too
	for i in 6:
		await process_frame
	var n_a := 0
	var n_ac := 0
	for a in m.find_children("*", "AnimatedSprite2D", true, false):
		n_a += 1
		var am: Material = (a as AnimatedSprite2D).material
		if am == mat or (am is ShaderMaterial and (am as ShaderMaterial).shader.resource_path.ends_with("flash.gdshader")):
			n_ac += 1
	check(n_a > 0 and n_ac == n_a, "town characters/critters crisp (%d/%d)" % [n_ac, n_a])
	var chunks: Dictionary = m.get("_bake")
	var n_ch := 0
	for ch in chunks.values():
		if (ch[1] as Sprite2D).material == CrispArt.material_premul():
			n_ch += 1
	check(chunks.size() > 0 and n_ch == chunks.size(), "baked ground chunks crisp (%d/%d)" % [n_ch, chunks.size()])
	for f in ["res://shaders/sharp_pixel.gdshader", "res://shaders/sharp_pixel_premul.gdshader", "res://shaders/flash.gdshader"]:
		check("smoothstep(vec2(0.8), vec2(1.0), d)" in FileAccess.get_file_as_string(f), "%s eases crisp -> bilinear with smoothstep" % f)
	var bad: Array = []
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/gen/manifest.json"))
	for nm: String in (man.get("props", {}) as Dictionary).keys():
		if not (nm.begins_with("mine_") and ("rock" in nm or "_ore_" in nm)) and not nm.begins_with("node_"):
			continue
		var im := Image.load_from_file("res://art/gen/props/%s.png" % nm)
		if im == null:
			continue
		var soft := 0
		for y in im.get_height():
			for x in im.get_width():
				var a := im.get_pixel(x, y).a
				if a > 0.02 and a < 0.98:
					soft += 1
		if soft > 0:
			bad.append(nm)
	check(bad.is_empty(), "mine rocks crisp (soft alpha in %s)" % [bad.slice(0, 5)])
	print("crisp_art_test: ", "OK" if fails == 0 else "%d FAIL" % fails)
	quit(1 if fails else 0)
