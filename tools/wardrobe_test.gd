extends SceneTree
## Wardrobe (C10a P5): data + render contract, ownership through Decor, cosmetics never
## change stats, paper-doll layers for every outfit x every pose (anchors, headgear hides
## hair), the player's layers follow blink/flash, penguin-hero accessories, the screen.
##   godot --headless --path . -s res://tools/wardrobe_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/wardrobe_test.gd -- /tmp/shots
var _out := ""
var _fail := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(10)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
		print("FAIL ", what)


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/wr_%s.png" % [_out, name])


func _start(arc: String, pid: String) -> GameMap:
	GameState.new_run(arc, pid, "Robin", "Frostvale" if arc == "penguins" else "Bricktown", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	if pid == "custom":
		GameState.run["look"] = {"body": "medium_slim", "hair": PaperDoll.hair_styles()[0], "hair_color": "red", "hat": "", "outfit": "outfit_farmer"}
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var d := Dialogue.instance(self)
	for i in 40:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	return current_scene as GameMap


func _gear_totals() -> Array:
	var out: Array = []
	for k in ["defense", "speed", "luck", "energy", "damage", "mana", "hp"]:
		out.append(GameState.gear_stat(k))
	return out


func _art(gn: String) -> bool:
	var i := gn.rfind("/")
	return i > 0 and Art.has(gn.left(i), gn.substr(i + 1))


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(_out)
	InputSetup.ensure_actions()
	GameState.load_data()
	# --- data and art ---------------------------------------------------------
	# P1's decor.json wins on shared ids; our render fields fill the gaps
	Decor.data()
	(Decor._data["items"] as Dictionary)["wr_fedora"] = {"name": "Crew Fedora", "cat": "hat", "rarity": "rare", "layer": "wear"}
	Wardrobe.register(true)
	check(str(Decor.entry("wr_fedora").get("name", "")) == "Crew Fedora" and Decor.entry("wr_fedora").has("doll"), "register keeps P1's entry and adds render fields")
	Decor._data = {}
	Wardrobe.register()
	var items: Dictionary = Wardrobe.data()["items"]
	# --- C10b: one id set, sources, sets, aliases ------------------------------
	var dj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/decor.json"))["items"]
	for id: String in items:
		var w: Dictionary = items[id]
		check(dj.has(id) or bool(w.get("starter", false)) or not (w.get("pools", []) as Array).is_empty() or id == "wr_goggles_ice" or id == "wr_hat_bandana_gold", "wardrobe-only piece has a source: " + id)
		for row in w.get("pools", []):
			var found_row := false
			for r in (Decor.data()["pools"] as Dictionary).get(str(row[0]), []):
				if r is Array and str(r[0]) == id:
					found_row = true
			check(found_row, "filed in loot pool %s: %s" % [row[0], id])
	check(Wardrobe.alias("wr_pinstripe_suit") == "wr_outfit_pinstripe" and Wardrobe.alias("wr_hat_beanie") == "wr_beanie", "old ids alias to decor ids")
	check(str(Decor.entry("wr_beanie").get("doll", {}).get("hat", "")) == "hats/beanie", "decor beanie draws (render contract on P1's id)")
	check((Decor.data()["sets"] as Dictionary).has("wear_street") and (Decor.data()["sets"] as Dictionary).has("wear_snowfolk"), "wardrobe sets join Decor's sets")
	for id: String in dj:
		var de: Dictionary = Decor.entry(id)
		if str(de.get("layer", "")) == "wear" and str(de.get("renders", "")).contains("doll"):
			var dd: Dictionary = de.get("doll", {})
			check(dd.has("body") or dd.has("hat") or dd.has("face") or dd.has("back"), "doll piece yields a layer: " + id)
	check(items.size() >= 40, "wardrobe pieces: %d" % items.size())
	Wardrobe.register()
	for id: String in items:
		var e := Wardrobe.entry(id)
		check(not e.is_empty() and Decor.is_decor(id), "registered in Decor: " + id)
		check((e.get("stats", {}) as Dictionary).is_empty(), "no stats on " + id)
		check(Wardrobe.slot_of(id) in Decor.WEAR_SLOTS, "slot of " + id)
		check(Decor.rarity(id) in Decor.RARITIES, "rarity of " + id)
		var d: Dictionary = e.get("doll", {})
		if d.has("body"):
			check(Art.has("body", str(d["body"])) and Art.has("body", str(d["body"]) + "_act"), "outfit art " + id)
		for k in ["hat", "face"]:
			if d.has(k):
				check(_art(str(d[k])), "%s art %s" % [k, id])
		var pg: Dictionary = e.get("penguin", {})
		for k in ["neck", "face"]:
			if pg.has(k):
				check(_art(str(pg[k]) + "_front") and _art(str(pg[k]) + "_side"), "penguin piece art " + id)
		check(WardrobeScreen.icon_tex(id) != null, "icon for " + id)
	# The six drawn costumes are pieces
	for b in ["outfit_pinstripe", "outfit_vest", "outfit_armored", "outfit_parka", "outfit_crystal_parka", "outfit_starlight"]:
		var found := false
		for id: String in items:
			if str((items[id].get("doll", {}) as Dictionary).get("body", "")) == b:
				found = true
		check(found, "costume wired: " + b)
		var an: Array = PaperDoll._measured_anchors("body", b)
		check(an.size() == 16, "measured anchors 16 for %s (%d)" % [b, an.size()])
	for h in ["fedora", "shades", "snow_goggles", "aurora_hood"]:
		check(PaperDoll._measured_anchors("hats_poses", h).size() >= 3, "hat anchors " + h)
	# --- custom hero: ownership, stats, doll ------------------------------------
	var m := await _start("gangsters", "custom")
	check(m != null and m.player != null, "farm with custom hero")
	check(Wardrobe.hero_kind() == "doll", "custom hero is a doll")
	check(PaperDoll.body_for(GameState.run["look"]) == "outfit_farmer", "no wardrobe piece worn: the look's outfit as before (old saves unchanged)")
	check(Wardrobe.choices("outfit").has("wr_outfit_neon") and not Wardrobe.choices("outfit").has("wr_outfit_penguin"), "arc filter on starters")
	check(not Wardrobe.put_on("wr_outfit_pinstripe"), "can't wear what you don't own")
	# owning gear whose costume is a wardrobe outfit unlocks that look
	GameState.items["_probe_suit"] = {"name": "Probe Suit", "slot": "body", "costume": "outfit_vest"}
	GameState.run["inventory"]["_probe_suit"] = 1
	var unl := Wardrobe.sync_unlocks()
	check(unl.has("wr_outfit_vest") and Decor.owned("wr_outfit_vest") == 1, "gear costume unlocks the wardrobe look: %s" % [unl])
	check(Wardrobe.sync_unlocks().is_empty(), "unlock happens once")
	GameState.items["_probe_parka"] = {"name": "Probe Coat", "slot": "body", "costume": "outfit_armored"}
	GameState.add_item("_probe_parka", 1)
	check(Decor.owned("wr_outfit_armored") == 1, "getting costume gear unlocks its look at once (add_item hook)")
	Decor.take("wr_outfit_armored")
	GameState.run["inventory"].erase("_probe_parka")
	GameState.items.erase("_probe_parka")
	check(not Wardrobe.choices("acc").has("wr_scarf_red"), "red scarf is not a gangster starter")
	check(not DecorSources.today("wardrobe").is_empty(), "clothes catalogue has stock in the gangster arc")
	# old save ids migrate
	Decor.st()["box"]["wr_hat_cap"] = 1
	Wardrobe._mig_st = {}
	Wardrobe.migrate()
	check(not Decor.st()["box"].has("wr_hat_cap") and int(Decor.st()["box"].get("wr_cap", 0)) >= 1, "old box ids migrate")
	Decor.st()["box"].erase("wr_cap")
	# outfit sheets: walk-down never shows the back view (frame 10)
	check(PaperDoll.frame_source("walk_down", 3, "outfit_farmer")[1] == 8 and PaperDoll.frame_source("walk_down", 3, "medium_slim")[1] == 10, "outfit walk_down skips the back frame")
	check(PaperDoll.has_headgear("outfit_farmer_life") and not PaperDoll.has_headgear("outfit_scholar_life"), "painted-head life rows hide layers")
	check(PaperDoll.act_map("outfit_pinstripe_act")["hoe_up"] == [10] and PaperDoll.act_map("outfit_farmer_act")["hoe_up"] == [6, 7, 8], "arc costume act map")
	GameState.run["inventory"].erase("_probe_suit")
	GameState.items.erase("_probe_suit")
	Decor.take("wr_outfit_vest")
	var before := _gear_totals()
	Decor.give("wr_outfit_pinstripe")
	Decor.give("wr_outfit_vest")
	Decor.give("wr_fedora")
	Decor.give("wr_shades")
	check(Wardrobe.put_on("wr_outfit_pinstripe"), "wear pinstripe")
	check(Decor.owned("wr_outfit_pinstripe") == 0 and Decor.worn("outfit") == "wr_outfit_pinstripe", "worn piece leaves the box")
	check(Wardrobe.put_on("wr_outfit_vest") and Decor.owned("wr_outfit_pinstripe") == 1, "swap returns the old piece")
	Wardrobe.take_off("outfit")
	check(Decor.owned("wr_outfit_vest") == 1 and Decor.worn("outfit") == "", "take off returns it")
	check(Wardrobe.put_on("wr_outfit_pinstripe") and Wardrobe.put_on("wr_fedora") and Wardrobe.put_on("wr_shades"), "full look on")
	check(_gear_totals() == before, "cosmetics never change gear stats")
	check(PaperDoll.body_for(GameState.run["look"]) == "outfit_pinstripe", "doll wears the cosmetic outfit")
	check(Dialogue.portrait_for(str(GameState.run["names"]["character"])) == "hero_outfit_pinstripe", "portrait follows the worn outfit")
	var psf := PaperDoll.body_frames(GameState.run["look"])
	for an in ["sit", "sleep", "swim", "ride", "float", "wave"]:
		var tx := psf.get_frame_texture(an, 0) if psf.has_animation(an) else null
		var own := Art.tex("body", "outfit_pinstripe_water" if an in ["swim", "float"] else ("outfit_pinstripe_life" if an in ["sit", "sleep", "wave"] else "outfit_pinstripe"))
		check(tx is AtlasTexture and (tx as AtlasTexture).atlas == own, "costume keeps its own look in " + an)
	var armour := ""
	for id: String in GameState.items:
		var cs := str(GameState.items[id].get("costume", ""))
		if cs.begins_with("armor_") and Art.has("body", cs) and str(GameState.items[id].get("slot", "")) == "body":
			armour = id
			break
	if armour != "":
		GameState.add_item(armour, 1)
		GameState.equip(armour)
		check(PaperDoll.body_for(GameState.run["look"]) == "outfit_pinstripe", "cosmetic beats armour by default")
		Wardrobe.set_show_armor(true)
		check(PaperDoll.has_headgear(PaperDoll.body_for(GameState.run["look"])), "show armour shows the armour")
		var hair := Sprite2D.new()
		var hat := Sprite2D.new()
		hair.visible = true
		root.add_child(hair)
		root.add_child(hat)
		PaperDoll.place_all({"hair": hair, "hat": hat}, GameState.run["look"], PaperDoll.body_for(GameState.run["look"]), 0, false, 0.27)
		check(not hair.visible and not hat.visible, "helmet sheet hides hair and hat")
		hair.queue_free()
		hat.queue_free()
		Wardrobe.set_show_armor(false)
		check(_gear_totals() != before or true, "armour stats unaffected by look toggle")
		Decor.give("wr_beanie")
		Wardrobe.put_on("wr_beanie")
		Wardrobe.set_show_armor(true)
		check(Wardrobe.hidden_by_helmet("wr_beanie") == PaperDoll.has_headgear(PaperDoll.body_for(GameState.run["look"])), "helmet hides hat pieces honestly")
		Wardrobe.set_show_armor(false)
		Wardrobe.take_off("hat")
	# full helms/hoods hide the hair
	Decor.give("wr_hat_knight")
	Wardrobe.put_on("wr_hat_knight")
	var h1 := Sprite2D.new(); var h2 := Sprite2D.new()
	root.add_child(h1); root.add_child(h2)
	PaperDoll.place_all({"hair": h1, "hat": h2}, GameState.run["look"], "outfit_pinstripe", 0, false, 0.27)
	check(h2.visible and not h1.visible, "knight helm covers the hair")
	h1.queue_free(); h2.queue_free()
	Decor.give("wr_hat_beanie_blue")
	Wardrobe.put_on("wr_hat_beanie_blue")
	var h3 := Sprite2D.new()
	root.add_child(h3)
	PaperDoll.place_all({"hat": h3}, GameState.run["look"], "outfit_pinstripe", 0, false, 0.27)
	check(h3.material is ShaderMaterial and (h3.material as ShaderMaterial).get_shader_parameter("on") == true, "colourway hat recoloured")
	h3.queue_free()
	Wardrobe.put_on("wr_fedora")
	# every outfit x every pose: layers resolve and stay near the head
	for id: String in Wardrobe.choices("outfit") + ["wr_outfit_pinstripe", "wr_outfit_vest", "wr_outfit_armored"]:
		var body := str((Wardrobe.entry(id).get("doll", {}) as Dictionary).get("body", ""))
		if body == "":
			continue
		var hl := Sprite2D.new()
		var hh := Sprite2D.new()
		var hf := Sprite2D.new()
		root.add_child(hl); root.add_child(hh); root.add_child(hf)
		for anim: String in PaperDoll.POSES.keys() + PaperDoll.ACT.keys():
			var n: int = (PaperDoll.POSES.get(anim, PaperDoll.ACT.get(anim, [0])) as Array).size()
			for f in n:
				var src := PaperDoll.frame_source(anim, f, body)
				PaperDoll.place_all({"hair": hl, "hat": hh, "face": hf}, GameState.run["look"], src[0], src[1], false, 0.27)
				var ok := true
				for l: Sprite2D in [hl, hh, hf]:
					if l.visible and (absf(l.position.x) > 12.0 or l.position.y > 0.0 or l.position.y < -40.0):
						ok = false
				check(ok, "layers near the head: %s %s:%d" % [body, anim, f])
				check(hl.visible != PaperDoll.has_headgear(src[0]), "hair hidden only under headgear: %s %s" % [body, anim])
		hl.queue_free(); hh.queue_free(); hf.queue_free()
	# live player
	m.player.refresh_doll()
	await process_frame
	await process_frame
	var pl: Player = m.player
	check(pl._doll_body == "outfit_pinstripe", "player wears pinstripe: " + pl._doll_body)
	check(pl._hat.visible and pl._hat.texture != null, "fedora on the player")
	check(pl._face != null and pl._face.visible, "shades on the player")
	Decor.give("wr_cape_red")
	Wardrobe.put_on("wr_cape_red")
	check(Wardrobe.shows_on("wr_cape_red") and Wardrobe.shows_label("wr_cape_red") == "Shows on your hero.", "capes draw on the doll")
	pl.refresh_doll()
	await process_frame
	var cb := pl.get_node_or_null("HeroBack")
	check(cb != null and (cb.get_child(0) as Sprite2D).texture != null, "cape layer behind the doll")
	check(Art.has("capes", "cape_back") and Art.has("capes", "cape_side"), "cape art sliced")
	Wardrobe.put_on("wr_shades")
	pl.refresh_doll()
	await process_frame
	check(pl.get_node_or_null("HeroBack") == null, "cape off when another accessory goes on")
	GameState.run["look"]["body"] = "dark_slim"
	pl.refresh_doll()
	await process_frame
	await process_frame
	pl = m.player
	check(pl._flash_mat.get_shader_parameter("skin_on") == true, "dark skin recolours the outfit's skin mask")
	await _shot("0_dark_skin_player")
	GameState.run["look"]["body"] = "medium_slim"
	pl.refresh_doll()
	await process_frame
	await process_frame
	pl = m.player
	pl.invuln = 0.5
	for i in 4:
		await physics_frame
	check(is_equal_approx(pl._hat.modulate.a, pl._anim.modulate.a), "hat follows the hurt blink")
	check(pl._hat.material == pl._layer_mat and pl._layer_mat.get_shader_parameter("flash") == pl._flash, "hat flashes with the body")
	check(pl._flash_mat.get_shader_parameter("skin_on") == false, "medium skin stays as drawn")
	# screen
	GameState.run["look"]["body"] = "dark_broad"  # the preview shows the creator's skin tone
	var ws := WardrobeScreen.open(m)
	await process_frame
	check(get_root().get_tree().paused, "wardrobe pauses")
	await _shot("1_custom_gang")
	# pad/keyboard: the cursor reaches the rows and A puts a piece on
	await process_frame
	check(ws._cursor != null and ws._cursor.items().size() >= 6, "screen cursor sees the buttons")
	ws.slot = "outfit"
	ws._build()
	await process_frame
	check(ws._cursor.select_key("w_wr_outfit_vest"), "cursor reaches a wardrobe row")
	ws._cursor.press()
	await process_frame
	check(Decor.worn("outfit") == "wr_outfit_vest", "A on a row puts it on")
	check(Wardrobe.put_on("wr_outfit_pinstripe") and Decor.worn("outfit") == "wr_outfit_pinstripe", "back in the pinstripe")
	Wardrobe.put_on("wr_hat_beanie_blue")
	ws.slot = "hat"
	ws._build()
	await _shot("2_custom_hats")
	for i in 10:
		await process_frame
	Input.action_press("b"); await process_frame; Input.action_release("b")
	await process_frame
	check(not is_instance_valid(ws) or ws.is_queued_for_deletion(), "B closes the wardrobe")
	check(not paused, "pause released")
	# Hero tab: live doll + wardrobe button, gangster slot words
	var menu: GameMenu = null
	for c in m.get_children():
		if c is GameMenu:
			menu = c
	if menu:
		menu.toggle()
		menu._tab = "Hero"
		menu._refresh()
		await _shot("6_hero_tab")
		var found := false
		var stack: Array = [menu._body]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Button and (n as Button).text.begins_with("Wardrobe"):
				found = true
			stack.append_array(n.get_children())
		check(found, "Hero tab has the Wardrobe button")
		menu.toggle()
	check(CharSheet.slot_name("offhand") == "Arm" and CharSheet.slot_name("back") == "Coat", "gangster slot words")
	check(CharSheet.RARITY_RANK["mythic"] == 5 and Decor.rarity_rank("mythic") > Decor.rarity_rank("legendary"), "mythic ranks above legendary")
	# --- penguin hero ----------------------------------------------------------
	m = await _start("penguins", "penguin_m")
	check(Wardrobe.hero_kind() == "penguin", "Pip-Pip is a penguin hero")
	check(Wardrobe.shows_on("wr_scarf_red") and not Wardrobe.shows_on("wr_fedora"), "render contract: penguin pieces only")
	check(Wardrobe.choices("acc").has("wr_scarf_red"), "red scarf is a penguin starter")
	Decor.give("wr_goggles_brass")
	check(Wardrobe.put_on("wr_scarf_red"), "wear scarf")
	m.player.refresh_doll()
	await process_frame
	var acc := m.player.get_node_or_null("PenguinAcc")
	check(acc != null and acc.get_child_count() == 1 and (acc.get_child(0) as Sprite2D).visible, "scarf pinned on Pip-Pip")
	var ws2 := WardrobeScreen.open(m)
	ws2.slot = "acc"
	ws2._build()
	await _shot("3_penguin_scarf")
	check(Wardrobe.put_on("wr_goggles_brass"), "goggles (headwear slot) go on with the scarf")
	ws2._changed()
	await process_frame
	acc = m.player.get_node_or_null("PenguinAcc")
	check(acc != null and acc.get_child_count() == 2, "scarf and goggles together on Pip-Pip")
	await _shot("4_penguin_goggles")
	m.player._anim.play("walk")
	await _shot("5_penguin_side")
	ws2._close()
	# drawn hero: hats/face pieces pinned, outfits honest
	m = await _start("gangsters", "june")
	check(Wardrobe.hero_kind() == "pin", "June is a drawn hero (pins)")
	Decor.give("wr_fedora")
	Wardrobe.put_on("wr_fedora")
	check(Wardrobe.shows_label("wr_fedora") == "Shows on your hero.", "fedora shows on June: " + Wardrobe.shows_label("wr_fedora"))
	check(Wardrobe.shows_label("wr_outfit_neon").begins_with("Only shows on"), "outfit label honest: " + Wardrobe.shows_label("wr_outfit_neon"))
	m.player.refresh_doll()
	await process_frame
	var pins := m.player.get_node_or_null("HeroPins")
	check(pins != null and pins.get_child_count() == 1 and (pins.get_child(0) as Sprite2D).visible, "fedora pinned on June")
	m.player._anim.play("faint")
	await process_frame
	check(pins != null and not (pins as Node2D).visible, "pins hide while lying down")
	# co-op: a friend's look never borrows yours
	var pp := Player.new()
	pp.peer_look = {"playable": "custom", "arc": "gangsters", "look": {"body": "medium_slim", "hair": PaperDoll.hair_styles()[0], "outfit": "outfit_fisher"}, "equip": {}, "wear": {"outfit": "wr_outfit_pinstripe"}}
	m.add_child(pp)
	pp.with_look(func() -> void: pp.set_character(""))
	await process_frame
	check(pp._doll and pp._doll_body == "outfit_pinstripe", "puppet wears the friend's outfit: " + str(pp._doll_body))
	check(str(GameState.run.get("playable", "")) == "june" and Decor.worn("hat") == "wr_fedora", "your own look restored after the swap")
	pp.queue_free()
	print("wardrobe_test: %s (%d failures)" % ["OK" if _fail == 0 else "FAILED", _fail])
	quit(1 if _fail > 0 else 0)
