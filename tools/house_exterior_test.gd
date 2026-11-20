extends SceneTree
## Farmhouse exterior styles (C10b P3): defaults draw the painted house untouched;
## a chosen roof/siding/door/porch dresses every tier (palette material, overlays
## fitted to the door box, inside the picture); buying charges once and owning lets
## you switch free; bad ids fall back to the original; night/snow swaps keep the
## dressing; the door, rect and mailbox never move; the picker opens and closes;
## fence styles reach the pen fences. Pass an output dir (under xvfb) for shots.
var fails := 0
var out := ""


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(7)
	Campaign.bypass = true
	var args := OS.get_cmdline_user_args()
	out = str(args[0]) if args.size() > 0 else ""
	_run.call_deferred()


func frames(k: int) -> void:
	for i in k:
		await process_frame


func load_farm() -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(14)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await frames(2)
	return current_scene as GameMap


func new_run(arc := "penguins") -> void:
	InputSetup.ensure_actions()
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["farm_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]


func shot(m: GameMap, name: String, frame := true) -> void:
	if out == "":
		return
	var sp: Sprite2D = m._house_sprite
	var cam := root.get_viewport().get_camera_2d()
	if not frame:
		await frames(6)
	elif cam and sp:
		cam.offset = Vector2.ZERO
		cam.global_position = sp.global_position + Vector2(0, -50)
		await frames(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _run() -> void:
	new_run()
	# --- data sanity: every style has its art / ramp, ids are unique ---
	var seen := {}
	for part: String in HouseExterior.STYLES:
		for s: Dictionary in HouseExterior.STYLES[part]:
			var id := str(s["id"])
			check(not seen.has(id) and id.begins_with("ext_" + part + "_"), "%s id unique and named ext_<part>_<style>" % id)
			seen[id] = true
			if s.has("wall"):
				check(ResourceLoader.exists(HouseExterior.DIR + str(s["wall"]) + ".png"), "%s wall texture exists" % id)
			check(s.has("ramp") or s.has("art") or s.has("fence") or s.has("wall"), "%s has a look" % id)
			if s.has("ramp"):
				check((s["ramp"] as Array).size() == 5, "%s ramp has 5 stops" % id)
			if s.has("art"):
				check(ResourceLoader.exists(HouseExterior.DIR + str(s["art"]) + ".png"), "%s art exists" % id)
			if s.has("fence"):
				for n: String in s["fence"]:
					check(Art.has("props", n), "%s fence piece %s exists" % [id, n])
			check(int(s.get("price", 0)) > 0 and int(s.get("price", 0)) <= 2000, "%s price within the house-tier band" % id)
	for h: String in ["house", "house_2", "house_3"]:
		var pt := load(HouseExterior.DIR + h + "_parts.png") as Texture2D
		var day := Art.tex("buildings", h)
		check(pt != null and day != null and pt.get_size() == day.get_size(), "%s part mask matches the day picture" % h)
	check(not HouseExterior.meta().get("doors", {}).is_empty(), "parts.json door boxes load")

	# --- default look: nothing added, CrispArt material kept ---
	var m := await load_farm()
	var sp: Sprite2D = m._house_sprite
	var ext := sp.get_node_or_null("HouseExterior") as HouseExterior
	check(ext != null, "farmhouse carries the HouseExterior node")
	check(ext != null and ext._kids.is_empty(), "default look adds no overlays")
	check(not (sp.material is ShaderMaterial and str((sp.material as ShaderMaterial).shader.resource_path).ends_with("house_palette.gdshader")), "default look keeps the plain (crisp) material")
	await shot(m, "t1_default")

	# --- buying, owning, switching ---
	GameState.run["crystals"] = 100
	check(HouseExterior.choose("roof", "ext_roof_slate") == "poor", "can't buy a roof without the money")
	GameState.run["crystals"] = 5000
	check(HouseExterior.choose("roof", "ext_roof_slate") == "ok", "buy Slate Blue roof")
	check(int(GameState.run["crystals"]) == 5000 - 600, "charged the roof price once")
	var notes := Mail.list().filter(func(x: Dictionary) -> bool: return str(x.get("from", "")) == "Hazel" and str(x.get("text", "")).contains("farmhouse"))
	check(notes.size() == 1, "first restyle brings Hazel's letter")
	HouseExterior.choose("roof", "")
	check(HouseExterior.choose("roof", "ext_roof_slate") == "ok" and int(GameState.run["crystals"]) == 4400, "switching back to an owned style is free")
	check(HouseExterior.choose("roof", "ext_door_oak") == "bad", "a door id can't go on the roof")
	check(HouseExterior.choose("door", "ext_door_steel") == "bad", "gangster-only door refused in the penguin arc")
	HouseExterior.choose("siding", "ext_siding_white")
	check(Mail.list().filter(func(x: Dictionary) -> bool: return str(x.get("text", "")).contains("Saw your farmhouse")).size() == 1, "the letter comes only once")
	HouseExterior.choose("door", "ext_door_dutch_blue")
	HouseExterior.choose("porch", "ext_porch_fern")
	HouseExterior.choose("fence", "ext_fence_stone")
	HouseExterior.choose("mailbox", "ext_mailbox_birdhouse")
	Decor.st()["house"]["glass"] = "ext_glass_bogus"  # a renamed id in an old save
	check(not HouseExterior.look().has("glass"), "unknown ids fall back to the original")

	for tier in [1, 2, 3]:
		GameState.run["builds"] = {"house": tier, "coop": 2, "barn": 2}
		m = await load_farm()
		sp = m._house_sprite
		var hl: Dictionary = m.call("house_look", tier)
		var mb: Sprite2D = m.get_meta("ext_mailbox") if m.has_meta("ext_mailbox") else null
		check(mb != null and str(mb.texture.resource_path).ends_with("mailbox_birdhouse.png"), "tier %d mailbox wears the Birdhouse Box" % tier)
		check(m.door_c == hl["door"] and m.house_r == hl["rect"] and m.mail_c == hl["mail"], "tier %d door/rect/mailbox unchanged" % tier)
		var mat := sp.material as ShaderMaterial
		check(mat != null and str(mat.shader.resource_path).ends_with("house_palette.gdshader"), "tier %d palette material on the house" % tier)
		check(mat != null and bool(mat.get_shader_parameter("use1")) and bool(mat.get_shader_parameter("use2")) and not bool(mat.get_shader_parameter("use3")), "tier %d roof+walls recoloured, glass original" % tier)
		ext = sp.get_node_or_null("HouseExterior") as HouseExterior
		check(ext != null and ext._kids.size() == 3, "tier %d door + a pair of ferns" % tier)
		if ext:
			var tw := float(sp.texture.get_width())
			var th := float(sp.texture.get_height())
			var org := sp.offset - Vector2(tw, th) * 0.5
			var inside := true
			for e: Array in ext._kids:
				var s: Sprite2D = e[0]
				var r := Rect2(s.position, s.texture.get_size() * s.scale)
				inside = inside and Rect2(org, Vector2(tw, th)).grow(1).encloses(r)
			check(inside, "tier %d overlays sit inside the house picture" % tier)
		var fences: Array = m._fences
		var stone := false
		for f: Array in fences:
			if str(f[1]).contains("fence2_stone"):
				stone = true
		check(fences.is_empty() or stone, "tier %d pen fences use the Fieldstone Wall" % tier)
		await shot(m, "t%d_styled" % tier)
		# night swap: the dressing follows the narrower night picture
		if not m._house_pics.is_empty() and Art.has("buildings", str(m._house_pics[1])):
			sp.texture = Art.tex("buildings", str(m._house_pics[1]))
			m.call("_fit_house_pic")
			await frames(2)
			check(ext._tex == sp.texture, "tier %d overlays refit on the night picture (%s / %s)" % [tier, ext._tex.resource_path if ext._tex else "-", sp.texture.resource_path])
			check(ext._kids.is_empty() or (ext._kids[0][0] as CanvasItem).modulate != Color.WHITE, "tier %d door dims at night" % tier)
			await shot(m, "t%d_night" % tier)

	# --- winter picture keeps the dressing ---
	GameState.run["day"] = GameState.DAYS_PER_SEASON * 3 + 2
	m = await load_farm()
	sp = m._house_sprite
	check(sp.get_node_or_null("HouseExterior") != null and sp.material is ShaderMaterial, "winter house still styled")
	await shot(m, "winter")
	GameState.run["crystals"] = 9000
	HouseExterior.choose("siding", "ext_siding_brick")
	GameState.run["day"] = 3
	m = await load_farm()
	check(bool((m._house_sprite.material as ShaderMaterial).get_shader_parameter("use_wall")), "Red Brick walls use the brick texture")
	await shot(m, "brick")
	HouseExterior.choose("siding", "ext_siding_logs")
	m = await load_farm()
	await shot(m, "logs")
	HouseExterior.choose("siding", "ext_siding_white")
	GameState.run["day"] = GameState.DAYS_PER_SEASON * 3 + 2
	# winter night (c10b_01-05): the snowy house stays, dimmed, windows lit
	for tier in [1, 3]:
		GameState.run["builds"] = {"house": tier}
		GameState.run["time"] = 22 * 60
		m = await load_farm()
		sp = m._house_sprite
		var ex := sp.get_node_or_null("HouseExterior") as HouseExterior
		check(str(sp.texture.resource_path).contains("_snow"), "tier %d winter night keeps the snowy roof (%s)" % [tier, sp.texture.resource_path.get_file()])
		check(ex != null and ex._glow != null and ex._glow.visible, "tier %d winter night windows glow" % tier)
		check(sp.self_modulate != Color.WHITE, "tier %d snowy house dimmed at night" % tier)
		await frames(130)
		var dup := false
		for w: Array in m.glow.windows:
			dup = dup or w[0] == sp
		check(not dup, "tier %d farmhouse not double-lit by NightGlow" % tier)
		await shot(m, "winter_night_t%d" % tier)
	GameState.run["time"] = 6 * 60
	GameState.run["builds"] = {"house": 3}
	m = await load_farm()

	# --- picker opens, previews, closes back to the saved look ---
	var was_paused := paused
	var pk := HouseExterior.open(m)
	await frames(3)
	check(pk != null and paused, "picker opens and pauses")
	pk.set("part", "roof")
	pk.call("_step", 1)
	await frames(2)
	check(str(HouseExterior.look().get("roof", "")) == "ext_roof_slate", "preview doesn't change the saved look")
	await shot(m, "picker", false)
	pk.call("_close")
	await frames(3)
	check(paused == was_paused, "picker closes and restores the pause state (%s)" % was_paused)
	var ext2 := m._house_sprite.get_node_or_null("HouseExterior") as HouseExterior
	check(ext2 != null and str(ext2.look_now.get("roof", "")) == "ext_roof_slate", "closing restores the saved look")

	# --- gangster arc: own styles, guests can't restyle ---
	new_run("gangsters")
	var ids: Array = HouseExterior.styles("door").map(func(s: Dictionary) -> String: return str(s["id"]))
	check("ext_door_steel" in ids and not "ext_door_ice" in ids, "gangster arc lists its own door styles")
	var gf := HouseExterior.fence_set()
	check(gf.size() == 3 and str(gf[2]) == "chain_fence_gate_open", "gangster pens default to chain-link with a chain-link gate")
	print("house exterior test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
