extends GameMap
## Inside your house: bed (sleep to the next day), a chest with story notes,
## and the door back out.

const BED := Vector2i(3, 2)
const CHEST := Vector2i(12, 2)   # the dresser: your journal lives in the top drawer
const DOOR := Vector2i(8, 11)


func scene_id() -> String:
	return "house"


func default_spawn() -> Vector2:
	return Vector2(8 * TILE + 8, 10 * TILE)


func build() -> void:
	cols = 16
	rows = 13
	has_sky = false
	music_track = "house"
	set_thing(BED.x, BED.y, {"type": "bed", "hint": "A: sleep until morning"})
	set_thing(BED.x + 1, BED.y, {"type": "bed", "hint": "A: sleep until morning"})
	# The bed sprite covers two rows; its lower half answers A too.
	set_thing(BED.x, BED.y + 1, {"type": "bed", "hint": "A: sleep until morning"})
	set_thing(BED.x + 1, BED.y + 1, {"type": "bed", "hint": "A: sleep until morning"})
	set_thing(CHEST.x, CHEST.y, {"type": "chest", "hint": "A: dresser (journal)"})
	block_rect(1, 1, cols - 2, 1)  # back wall
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go outside"})
	set_thing(13, 9, {"type": "kitchen", "hint": "A: cook (campfire)"})


func after_ready() -> void:
	_place_props()
	RecCenter.dress_house(self)  # prize decor from the Rec Center
	if int(GameState.run["time"]) <= GameState.DAY_START + 5:
		hud.toast("%s today · %s tomorrow" % [GameState.weather_name(GameState.weather_today()), GameState.weather_name(GameState.forecast()).to_lower()], Color(0.9, 0.95, 1.0))
		if GameState.festival_today() != "":
			hud.toast("It's the %s! Head to the town plaza." % GameState.festival_name(GameState.festival_today()), Color(1, 0.9, 0.5))
		var nx := GameState.next_step()
		if nx != "":
			hud.toast("Next: " + nx, Color(1, 0.95, 0.7))
	var note := str(GameState.run["flags"].get("wake_note", ""))
	if note != "":
		GameState.run["flags"].erase("wake_note")
		player.frozen = true
		await say([{"text": note}])
		player.frozen = false


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"door":
			go_to("farm", Vector2(13 * TILE + 8, 11 * TILE + 4), "down")
			return true
		"bed":
			_sleep()
			return true
		"chest":
			later(_dresser)
			return true
		"kitchen":
			later(Crafting.run.bind(self, "kitchen", "Kitchen"))  # works at the tier of the Cooking Pot you own
			return true
		"pet_bed":
			hud.toast("%s curls up for a second, then follows you anyway." % GameState.names()["pet"])
			return true
	return false


func _sleep() -> void:
	if Net.visiting() and not Net.online():
		hud.toast("Reconnecting to your host... sleep once you're back.", Color(0.9, 0.95, 1.0))
		return
	if Net.online() and not Net.is_host():
		Net.send_host({"k": "act", "a": "sleep"})
		hud.toast("You're in bed. The day ends when everyone is.", Color(0.9, 0.95, 1.0))
		return
	if _changing:
		return
	_changing = true  # stops the 2am pass-out from firing during the fade
	player.frozen = true
	Music.instance(get_tree()).sfx("sleep")
	await hud.fade_out(0.8)
	var report := GameState.sleep()
	if Net.online():
		Net.i().clear_beds()
	var lines: Array = []
	if int(report["earned"]) > 0:
		lines.append({"who": "Sell box", "text": "%s\nTotal: ◆%d" % ["\n".join(report["sold"]), int(report["earned"])]})
	if int(report.get("left", 0)) > 0:
		lines.append({"text": "Something was left for you in the night. Check the pool and the burrow."})
	if int(report.get("washed", 0)) > 0:
		lines.append({"who": "Laundromat", "text": "Clean and folded: ◆%d." % int(report["washed"])})
	if int(report["grown"]) > 0:
		lines.append({"text": "%d watered crop%s grew overnight." % [int(report["grown"]), "" if int(report["grown"]) == 1 else "s"]})
	if int(report.get("crows", 0)) > 0:
		lines.append({"text": "Crows got into the field overnight and ate %d crop%s. A scarecrow covers about 8 steps around it." % [int(report["crows"]), "" if int(report["crows"]) == 1 else "s"]})
	if int(report.get("died", 0)) > 0:
		lines.append({"text": "%s took %d crop%s. Crops only live through their own season (or under the greenhouse glass)." % [GameState.season().capitalize(), int(report["died"]), "" if int(report["died"]) == 1 else "s"]})
	for nm in report.get("built", []):
		lines.append({"who": "Hazel", "text": "Crew's done with the %s. Go have a look." % str(nm)})
	if int(report.get("wash_back", 0)) > 0:
		lines.append({"who": "Laundromat", "text": "%d bill%s came back unwashed: the machines only take so much face value a night." % [int(report["wash_back"]), "" if int(report["wash_back"]) == 1 else "s"]})
	for kind in ["pool", "burrow"]:
		if GameState.run["flags"].has("basket_full_" + kind):
			GameState.run["flags"].erase("basket_full_" + kind)
			lines.append({"text": "The %s basket is full. Empty it, or the gifts stop." % kind})
	for l in report.get("cfarm", []):
		lines.append({"who": Commons.keeper_name(), "text": str(l)})
	if report.has("crew_jobs"):
		lines.append({"who": "HQ", "text": "Overnight:\n" + "\n".join(report["crew_jobs"])})
	if report.has("relic"):
		lines.append({"who": "Marlene", "text": "A little something from the tower. Don't ask. (%s)" % GameState.item_name(str(report["relic"]))})
	if Racket.on():
		var raids: bool = Racket.heat() >= 3 and not GameState.run["flags"].has("president_freed")  # no collectors once the stone is broken
		lines.append({"text": "Heat %d/5.%s" % [Racket.heat(), " Collectors may be out." if raids else ""]})
		if raids and Crew.perk_level("raid_warning") >= 1:
			lines.append({"who": "Ladder", "text": "Word from the roofs: the President's collectors are walking the districts today. Stay off the main streets, or bring friends."})
	var brief := "%s today, %s tomorrow." % [GameState.weather_name(GameState.weather_today()), GameState.weather_name(GameState.forecast()).to_lower()]
	if GameState.festival_today() != "":
		brief += " It's the %s: head to the plaza." % GameState.festival_name(GameState.festival_today())
	brief += " Sunset about %s." % GameState.clock_of(GameState.sunset())
	lines.push_front({"text": "Day %d. %s" % [int(GameState.run["day"]), brief]})
	var nxt := GameState.next_step()
	if nxt != "":
		lines.append({"text": "Next: " + nxt})
	for nm in report.get("gone", []):
		lines.append({"who": "", "text": "A note under the door, in a hand you know: '%s went east. Didn't say why. You know why.'" % str(nm)})
	await hud.fade_in(0.8)
	if int(report.get("earned", 0)) > 0:
		Music.instance(get_tree()).sfx("cash_register" if Money.cash() else "coin", "pickup")
	if not (report.get("built", []) as Array).is_empty():
		Music.instance(get_tree()).sfx("craft_done", "levelup")
	await say(lines)
	_changing = false
	_morning_events()
	Story.on_morning(self)
	player.frozen = false


func _morning_events() -> void:
	var day := int(GameState.run["day"])
	if day == 2:
		hud.toast("Check the mailbox.", Color(1, 0.9, 0.4))
	if day == 3:
		hud.toast("New mail.", Color(1, 0.9, 0.4))


func _journal() -> void:
	var r := GameState.run
	var lines: Array = []
	var d: Dictionary = r["decisions"]
	if GameState.is_penguins():
		var ans := int(d.get("crystal_answer", -1))
		var said: String = ["I said I'd help.", "I said I just want to farm.", "I called it a talking rock. It did not love that."][ans] if ans >= 0 else "I haven't answered the crystal yet."
		lines.append({"who": "Journal", "text": "A crystal fell in my field and talked to me about the end of the universe. %s" % said})
	else:
		var l := "sold" if r["flags"].has("letter_sold") else ("used" if r["flags"].has("doors_by_letter") or r["flags"].has("st_g5_doors_letter") else str(r["flags"].get("letter", "")))
		var said: String = {"sold": "I sold the letter to Marlene. He knows my face now.", "used": "The letter I kept opened the tower doors. He wrote it for exactly that.", "burned": "I burned the letter.", "kept": "I kept the letter with the deed.", "memorized": "I memorized the handwriting on the letter."}.get(l, "There's a letter I haven't dealt with.")
		lines.append({"who": "Journal", "text": "Someone knows I'm here. %s" % said})
	var open_q: Array = r["quests"].filter(func(q: Dictionary) -> bool: return not q["done"])
	if not open_q.is_empty():
		lines.append({"who": "To do", "text": "\n".join(open_q.map(func(q: Dictionary) -> String: return "• " + str(q["text"])))})
	await say(lines)


func draw_map() -> void:
	draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color("1a1410"))
	if Art.has("tiles", "fl_wood"):
		draw_tileset_rect("fl_wood", Rect2i(1, 2, cols - 2, rows - 3), Color("a07a4c"))
		if Art.has("furniture", "rug_rect_red"):
			# A bordered 2:1 rug (the carpet tile's inside is a flat colour block).
			draw_texture_rect(Art.tex("furniture", "rug_rect_red"), Rect2(6 * TILE, 6 * TILE + 8, 4 * TILE, 2 * TILE), false)
		else:
			_draw_rug("fl_carpet_red", Rect2i(6, 6, 4, 3), Color("b03a2e"))
		for x in range(1, cols - 1):
			var idx := 0 if x == 1 else (2 if x == cols - 2 else 1)
			var nm: String = ["wl_floral_l", "wl_floral_m", "wl_floral_r"][idx]
			var t := Art.tex("tiles", nm)
			if t:
				draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
		var night := GameState.is_night()
		Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(6 * TILE + 8, 2 * TILE))
		Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(10 * TILE + 8, 2 * TILE))
	elif Art.has("tiles", "floor_wood"):
		draw_tileset_rect("floor_wood", Rect2i(1, 2, cols - 2, rows - 3), Color("a07a4c"))
		draw_tileset_rect("rug_red", Rect2i(4, 5, 3, 3), Color("b03a2e"))
		for x in range(1, cols - 1):
			var idx := 0 if x == 1 else (2 if x == cols - 2 else 1)
			var nm: String = ["int_wall_l", "int_wall_m", "int_wall_r"][idx]
			var t := Art.tex("tiles", nm)
			if t:
				draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
		Art.draw_prop(self, "furniture", "window", Vector2(4 * TILE + 8, 2 * TILE))
		Art.draw_prop(self, "furniture", "window", Vector2(8 * TILE + 8, 2 * TILE))
	else:
		for y in range(2, rows - 1):
			for x in range(1, cols - 1):
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("a07a4c") if (x + y) % 2 == 0 else Color("96724a"))
		draw_rect(Rect2(TILE, TILE, (cols - 2) * TILE, TILE), Color("c9b08a"))
		draw_rect(Rect2(BED.x * TILE, BED.y * TILE, 2 * TILE, TILE + 4), Color("6b3b2a"))
		draw_rect(Rect2(BED.x * TILE + 2, BED.y * TILE + 2, 2 * TILE - 4, TILE), Color("d8536a"))
	draw_rect(Rect2(DOOR.x * TILE, DOOR.y * TILE, TILE, TILE), Color("3a2412"))


func _place_props() -> void:
	# A bed, a dresser, a stove, and a few plain things so it reads as a home.
	if not Art.has("furniture", "bed_single"):
		return
	var kit := Art.has("furniture", "bed_blue")
	prop("furniture", "bed_blue" if kit else "bed_single", Vector2i(BED.x, BED.y + 1), 1)
	prop("furniture", "dresser" if kit else "chest_closed", CHEST)
	if Art.has("furniture", "kitchen_stove"):
		prop("furniture", "kitchen_stove", Vector2i(13, 9))
	# Cells kept clear of the bed (3-4,2-3), dresser (12,2), stove (13,9), rug, door (8,11) and windows.
	for pr: Array in [["lamp_floor", Vector2i(1, 2), 0], ["bookshelf", Vector2i(14, 5), 0], ["table_round_cloth", Vector2i(3, 8), 1],
			["chair_down", Vector2i(3, 7), 0], ["plant2_a", Vector2i(1, 11), 0], ["plant_a", Vector2i(14, 11), 0]]:
		if Art.has("furniture", str(pr[0])):
			prop("furniture", str(pr[0]), pr[1], int(pr[2]))


## The dresser: read the journal or change your look (hair, hat, body).
func _dresser() -> void:
	var d := Dialogue.instance(get_tree())
	var pdata: Dictionary = GameState.playables.get(str(GameState.run.get("playable", "")), {})
	var sprite_id := GameState.sprite_for_playable(str(GameState.run.get("playable", "")))
	var can_look := (bool(pdata.get("custom", false)) and PaperDoll.available()) or sprite_id == "penguin"
	d.say([{"text": "The dresser. A mirror on the inside of the door.", "choice": ["Journal", "Change my look", "Close"] if can_look else ["Journal", "Close"], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		_journal()
	elif d.last_choice == 1 and can_look:
		player.frozen = true
		var layer := CanvasLayer.new()
		layer.layer = 12
		var panel := PanelContainer.new()
		panel.position = Vector2(8, 24)
		panel.size = Vector2(254, 330)
		panel.add_theme_stylebox_override("panel", Hud.panel_stylebox("panel_wood"))
		layer.add_child(panel)
		var cr := Creator.new(GameState.run.get("look", {}), sprite_id if sprite_id == "penguin" else "", true)
		panel.add_child(cr)
		add_child(layer)
		get_tree().paused = true
		Hud.modal_rect = Rect2(0, 0, 270, 480)
		var finish := func(l: Dictionary) -> void:
			if not l.is_empty():
				GameState.run["look"] = l
			Hud.modal_rect = Rect2()
			get_tree().paused = false
			layer.queue_free()
			player.frozen = false
			player.refresh_doll()
			Dialogue.block_input()
		cr.done.connect(finish)
		cr.cancelled.connect(func() -> void: finish.call({}))


## One bordered rug image: sample only inside its gold border, like the
## interiors' carpets (the 3x3 tileset cut shows the art's gutters).
func _draw_rug(nm: String, r: Rect2i, fallback: Color) -> void:
	var t := Art.tex("tiles", nm) if Art.has("tiles", nm) else null
	if t == null:
		draw_rect(Rect2(r.position * TILE, r.size * TILE), fallback)
		return
	var kc := t.get_width() / 96.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			draw_texture_rect_region(t, Rect2(Vector2(x * TILE, y * TILE), Vector2(TILE, TILE)), Rect2((22.0 + float(x % 2) * 26.0) * kc, (22.0 + float(y % 2) * 26.0) * kc, 26.0 * kc, 26.0 * kc))
