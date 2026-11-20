extends SceneTree
## CONDUCT 10a P3: the Decor catalogue (DecorCatalogue) with an EMPTY and an injected catalogue:
## owned/seen/missing, filters, arc filter, hints by rarity, order -> paid -> delivered next
## morning into the decor box, unique/mythic never orderable, sets claimed once, decor milestones,
## the screen opens/pages/closes on B at 270x480 with taps >= 20 px.
##   godot --headless --path . --fixed-fps 60 -s res://tools/decor_catalogue_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(10)
	Campaign.bypass = true
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame


func _inject() -> void:
	var items := {}
	var cats := ["furniture", "wall_art", "decor", "light", "rug", "hat"]
	var i := 0
	for r in Decor.RARITIES:
		for k in 6:
			var id := "dc_t_%s_%d" % [r, k]
			items[id] = {"name": "Test %s %d" % [r, k], "cat": cats[k % cats.size()], "rarity": r, "arc": "",
				"price": 100 + 50 * Decor.rarity_rank(r), "sources": ["Maple's Mercantile"], "set": "tset" if (r == "common" and k < 3) else ""}
			i += 1
	items["dc_gang_only"] = {"name": "Neon Sign", "cat": "light", "rarity": "rare", "arc": "gangsters", "price": 300}
	items["dc_peng_only"] = {"name": "Ice Lamp", "cat": "light", "rarity": "rare", "arc": "penguins", "price": 300, "hint": "Cold places."}
	items["dc_collectors_shelf"] = {"name": "Collector's Shelf", "cat": "furniture", "rarity": "rare", "arc": "", "price": 0, "order": false}
	Decor._data = {"items": items, "sets": {"tset": {"name": "Test Set", "arc": "", "pieces": ["dc_t_common_0", "dc_t_common_1", "dc_t_common_2"],
		"reward": {"money": 250, "decor": "dc_t_rare_5"}}}, "shops": {}, "pools": {}}
	DecorCatalogue.reset()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	# 1) Empty catalogue: nothing breaks, Book row reads 0/0.
	var saved := Decor._data.duplicate(true)
	Decor._data = {}
	DecorCatalogue.reset()
	check(DecorCatalogue.ids().is_empty(), "empty catalogue has no ids")
	check(DecorCatalogue.progress() == [0, 0], "empty progress 0/0")
	check(DecorCatalogue.filtered().is_empty(), "empty filter")
	check(Collections.check_decor_milestones().is_empty(), "no decor milestones with an empty catalogue")
	# 2) Injected catalogue.
	_inject()
	var n := DecorCatalogue.ids().size()
	check(n == 7 * 6 + 2, "penguin arc sees both-arc + penguin pieces (%d)" % n)
	check(not DecorCatalogue.ids().has("dc_gang_only"), "gangster-only piece hidden in the penguin arc")
	check(DecorCatalogue.state("dc_t_common_0") == "missing", "missing by default")
	Decor.give("dc_t_common_0", 2)
	check(DecorCatalogue.state("dc_t_common_0") == "owned" and DecorCatalogue.have("dc_t_common_0") == 2, "given -> owned x2")
	DecorCatalogue.mark_seen("dc_t_uncommon_1")
	check(DecorCatalogue.state("dc_t_uncommon_1") == "seen", "mark_seen -> seen")
	Decor.give("dc_t_common_1")
	Decor.take("dc_t_common_1")
	check(DecorCatalogue.state("dc_t_common_1") == "seen", "owned once then sold -> seen (re-orderable)")
	# Filters.
	DecorCatalogue.show_i = DecorCatalogue.SHOWS.find("owned")
	check(DecorCatalogue.filtered() == ["dc_t_common_0"], "Show: owned filter")
	DecorCatalogue.show_i = DecorCatalogue.SHOWS.find("missing")
	check(DecorCatalogue.filtered().size() == n - 3, "Show: missing filter (%d)" % DecorCatalogue.filtered().size())
	DecorCatalogue.show_i = 0
	DecorCatalogue.rar_i = Decor.RARITIES.find("unique") + 1
	check(DecorCatalogue.filtered().size() == 6, "Rarity: unique filter")
	DecorCatalogue.rar_i = 0
	DecorCatalogue.cat_i = DecorCatalogue.CATS.find("light")
	for id: String in DecorCatalogue.filtered():
		check(str(Decor.entry(id).get("cat")) == "light", "Type filter keeps lights only (%s)" % id)
	DecorCatalogue.cat_i = 0
	DecorCatalogue.set_i = 1
	check(DecorCatalogue.filtered().size() == 3, "Set filter shows its pieces")
	DecorCatalogue.set_i = 0
	# Hints scale with rarity.
	check(DecorCatalogue.hint("dc_t_common_2") == "Maple's Mercantile", "common hint is exact")
	check(DecorCatalogue.hint("dc_peng_only") == "Cold places.", "rare uses its vague hint")
	check(DecorCatalogue.hint("dc_t_legendary_0") == "???", "legendary without a hint stays ???")
	check(not DecorCatalogue.hint("dc_t_unique_0").contains("Maple"), "unique never names its source")
	DecorCatalogue.mark_seen("dc_t_legendary_1")
	check(DecorCatalogue.hint("dc_t_legendary_1") == "Maple's Mercantile", "a seen legendary names where it was seen")
	# Orders.
	GameState.run["crystals"] = 1000
	check(DecorCatalogue.order_block("dc_t_rare_0") != "", "missing pieces can't be ordered")
	check(DecorCatalogue.order_block("dc_t_unique_0") != "", "unique never orderable")
	Decor.give("dc_t_mythic_0")
	check(DecorCatalogue.order_block("dc_t_mythic_0") != "", "mythic never orderable")
	check(DecorCatalogue.order_block("dc_collectors_shelf") != "", "order:false never orderable")
	var price := DecorCatalogue.order_price("dc_t_common_1")
	check(price > Decor.price("dc_t_common_1"), "re-order costs more than the shop price (%d)" % price)
	check(DecorCatalogue.order("dc_t_common_1") == "", "order a seen piece")
	check(int(GameState.run["crystals"]) == 1000 - price, "order paid")
	check(DecorCatalogue.order("dc_t_common_1") != "", "can't order the same piece twice before it arrives")
	check(Decor.owned("dc_t_common_1") == 0, "not delivered the same day")
	GameState.run["day"] = int(GameState.run.get("day", 1)) + 1
	Collections.morning()
	check(Decor.owned("dc_t_common_1") == 1, "delivered next morning into the decor box")
	check(DecorCatalogue.orders().is_empty(), "order queue empty after delivery")
	check(GameState.count("dc_t_common_1") == 0, "decor never lands in the bag")
	GameState.run["crystals"] = 5
	check(DecorCatalogue.order("dc_t_common_1").begins_with("Not enough"), "order refused without money")
	Decor.st()["placed"]["house"] = [{"id": "dc_t_common_0", "cell": [3, 3], "rot": 0}]
	var ft := DecorCatalogue.find_text("dc_t_common_0")
	check(ft.contains("box 2") and ft.contains("placed 1") and DecorCatalogue.have("dc_t_common_0") == 3, "find line counts box + placed (%s)" % ft)
	# Unique: one per game.
	Decor.give("dc_t_unique_1")
	Decor.give("dc_t_unique_1")
	check(DecorCatalogue.have("dc_t_unique_1") == 1, "unique stays one")
	# Sets: claim once, pays money + piece.
	check(DecorCatalogue.claim_set("tset") != "", "unfinished set can't be claimed")
	Decor.give("dc_t_common_2")
	GameState.run["crystals"] = 0
	check(DecorCatalogue.claim_set("tset") == "", "finished set claims")
	check(int(GameState.run["crystals"]) == 250 and Decor.owned("dc_t_rare_5") == 1, "set reward paid")
	check(DecorCatalogue.claim_set("tset") != "", "set claims once")
	check(DecorCatalogue.set_counts() == [1, 1], "set counts 1/1")
	# Decor milestones (collections.json decor_milestones): 10 kinds -> a letter + money.
	for k in 6:
		Decor.give("dc_t_uncommon_%d" % k)
	var hits := Collections.check_decor_milestones()
	check(hits.has("decor_10"), "10 kinds reach decor_10 (%s, have %d)" % [hits, int(DecorCatalogue.progress()[0])])
	var before := int(GameState.run["crystals"])
	GameState.run["day"] = int(GameState.run["day"]) + 1
	Collections.morning()
	check(int(GameState.run["crystals"]) == before + 300, "decor_10 letter pays")
	check(Collections.check_decor_milestones().is_empty(), "decor milestones claim once")
	# Legend keepsake + milestone decor through Decor.
	Decor._data["items"]["dc_koi_scroll"] = {"name": "Koi Scroll", "cat": "wall_art", "rarity": "unique", "arc": ""}
	DecorCatalogue.reset()
	check(Collections.give_decor("dc_koi_scroll", "test") and Decor.owned("dc_koi_scroll") == 1, "legend keepsake goes to the decor box")
	check(not Collections.give_decor("no_such_piece", "test"), "unknown decor gift is skipped")
	check(Collections.decor_id("museum_trophy") == "", "legacy prop with no catalogue entry keeps its fixed spot")
	# 3) The screen at 270x480.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	await frames(30)
	var d := Dialogue.instance(self)
	for i in 30:
		if not d.active:
			break
		d._advance()
		await frames(3)
	check(DecorCatalogue.new_count() > 0, "new decor kinds glow the Book")
	var scr := DecorCatalogue.open(current_scene, "grid")
	await frames(10)
	check(DecorCatalogue.new_count() == 0, "opening the catalogue clears New")
	check(get_root().get_tree().paused, "catalogue pauses the game")
	check(Hud.modal_rect.size != Vector2.ZERO, "catalogue owns the modal")
	var small := 0
	var cells := 0
	for b in scr._cur.items():
		var r: Rect2 = (b as Control).get_global_rect()
		if r.size.y < 20 or r.size.x < 20:
			small += 1
		if r.end.y > 480.5 or r.end.x > 270.5:
			small += 1
		if str((b as Control).get_meta("pc_key", "")).begins_with("cell:"):
			cells += 1
	check(small == 0, "every tap target >= 20 px and on screen (%d bad)" % small)
	check(cells == mini(DecorCatalogue.PAGE, DecorCatalogue.filtered().size()), "one page of cells (%d)" % cells)
	DecorCatalogue.sel = "dc_t_common_1"
	scr._refresh()
	await frames(2)
	var has_order := false
	for b in scr._cur.items():
		if str((b as Control).get_meta("pc_key", "")) == "act:order":
			has_order = true
	check(has_order, "card of a seen piece offers Order")
	DecorCatalogue.sel = ""
	scr._refresh()
	await frames(2)
	var fl := DecorCatalogue.filtered()
	scr._cur.select_key("cell:" + str(fl[DecorCatalogue.COLS - 1]))
	check(scr._edge_move(Vector2.RIGHT) and DecorCatalogue.part == 1, "pad right past the grid edge turns the page")
	await frames(2)
	check(scr._edge_move(Vector2.LEFT) and DecorCatalogue.part == 0, "pad left past the edge turns back")
	scr._turn(1)
	check(DecorCatalogue.part == 1, "Page › turns the page")
	var r0 := DecorCatalogue.show_i
	for b in scr._cur.items():
		if str((b as Control).get_meta("pc_key", "")) == "chip:2":
			(b as Button).pressed.emit()
			break
	check(DecorCatalogue.show_i == (r0 + 1) % DecorCatalogue.SHOWS.size(), "a plain chip press (pad A) steps forward")
	DecorCatalogue.show_i = 0
	scr.cycle_chip(1, -1)
	check(DecorCatalogue.rar_i == Decor.RARITIES.size() and DecorCatalogue.part == 0, "chip cycles back and resets the page")
	DecorCatalogue.view = "box"
	scr._refresh()
	await frames(2)
	DecorCatalogue.view = "sets"
	scr._refresh()
	await frames(2)
	DecorCatalogue.view = "grid"
	DecorCatalogue.sel = ""
	scr._refresh()
	await frames(10)
	await press("b")
	await frames(4)
	check(not is_instance_valid(scr) or scr.is_queued_for_deletion(), "B closes the catalogue")
	check(Hud.modal_rect.size == Vector2.ZERO, "modal released")
	check(not get_root().get_tree().paused, "game unpaused after close")
	Decor._data = saved
	print("decor_catalogue_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
