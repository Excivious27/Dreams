extends GameMap
## Inside your house: bed (sleep to the next day), a chest with story notes,
## and the door back out.

const BED := Vector2i(3, 2)
const CHEST := Vector2i(12, 2)   # the dresser: your journal lives in the top drawer
const DOOR := Vector2i(8, 11)
const CELLAR := Vector2i(17, 9)   # Manor: the hatch (2x2) beside the keg rack
const STUDY := Vector2i(17, 3)    # Manor: the study desk
const BATH := Vector2i(23, 3)     # Manor: the bath nook in the east wing


func scene_id() -> String:
	return "house"


func default_spawn() -> Vector2:
	return Vector2(8 * TILE + 8, 10 * TILE)


## The house grows with its tier (C5): the Farmhouse adds a pantry corner and a
## double bed to the east, the Manor a cellar (kegs age faster), a study and a bath.
const COLS_BY_TIER := {1: 16, 2: 20, 3: 26}


static func tier() -> int:
	return clampi(Builds.built_tier("house"), 1, 3)


func build() -> void:
	cols = int(COLS_BY_TIER[tier()])
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
	if tier() >= 3:
		for hc: Vector2i in [CELLAR, CELLAR + Vector2i(1, 0)]:
			set_thing(hc.x, hc.y, {"type": "sign", "text": "The cellar. Kegs and jars down here age twice as fast.", "hint": "A: the cellar"})
		set_thing(STUDY.x + 1, STUDY.y, {"type": "sign", "text": "Your study: books, a journal and a good lamp. Thinking here sharpens you (+1 skill point when the Manor went up).", "hint": "A: the study desk"})
		set_thing(BATH.x, BATH.y, {"type": "sign", "text": "A hot bath. You feel sturdier just looking at it (+5 max health).", "hint": "A: the bath"})


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
	var kept_rep: Variant = GameState.run["flags"].get("wake_report", null)
	var kept := SleepReport.take_kept()
	if kept_rep is Dictionary and not kept.is_empty():
		morning_cues(get_tree(), kept_rep as Dictionary, true)  # a pass-out night still gets its morning sounds  # a pass-out night: what sold, grew, arrived
	if note != "" or not kept.is_empty():
		GameState.run["flags"].erase("wake_note")
		player.frozen = true
		await say(([{"text": note}] if note != "" else []) + kept)
		player.frozen = false
		if not kept.is_empty():
			_morning_events()
			Story.on_morning(self)


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"door":
			var fd: Vector2i = (load("res://scripts/farm.gd") as GDScript).house_look(Builds.built_tier("house"))["door"]  # the door of this tier's picture
			go_to("farm", Vector2(fd.x * TILE + 8, (fd.y + 1) * TILE + 4), "down")
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
	var lines := SleepReport.lines(report)
	await hud.fade_in(0.8)
	morning_cues(get_tree(), report, false)
	await say(lines)
	_changing = false
	_morning_events()
	Story.on_morning(self)
	player.frozen = false


## The morning's sounds (c6_10-02/-14): the wake-up jingle (a softer stretch after
## a pass-out), then the till for sales, the hammer for builds, the ripe-crop chime,
## spaced so they don't stack.
static func morning_cues(tree: SceneTree, report: Dictionary, passed_out: bool) -> void:
	if tree == null:
		return
	var mu := Music.instance(tree)
	var cues: Array = []
	cues.append("yawn" if passed_out and mu.has_sfx("yawn") else ("snore" if passed_out else "j_morning"))
	if int(report.get("earned", 0)) > 0:
		cues.append("cash_register" if Money.cash() else "coin")
	if not (report.get("built", []) as Array).is_empty():
		cues.append("craft_done")
	if int(report.get("ripe", 0)) > 0:
		cues.append("crop_ready")
	var at := 0.0
	for c: String in cues:
		if at <= 0.0:
			mu.sfx(c, "pickup")
		else:
			tree.create_timer(at, false).timeout.connect(func() -> void: mu.sfx(c, "pickup"))
		at += 0.9


func _morning_events() -> void:
	# Only when there's really something there (sleep() already counts the ordinary letters).
	var day := int(GameState.run["day"])
	if not Mail.story_due().is_empty():
		hud.toast("A letter in the mailbox, next to your front door." if day == 2 else "There's a letter in the mailbox.", Color(1, 0.9, 0.4))


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
		for wx: int in ([14] if tier() == 2 else ([15, 21] if tier() >= 3 else [])):
			Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(wx * TILE + 8, 2 * TILE))
		if tier() >= 3 and Art.has("furniture", "rug_rect_red"):
			draw_texture_rect(Art.tex("furniture", "rug_rect_red"), Rect2(19 * TILE, 6 * TILE + 8, 4 * TILE, 2 * TILE), false)
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
	var bed := "bed_double" if tier() >= 2 and Art.has("furniture", "bed_double") else ("bed_blue" if kit else "bed_single")
	prop("furniture", bed, Vector2i(BED.x, BED.y + 1), 1)
	prop("furniture", "dresser" if kit else "chest_closed", CHEST)
	if Art.has("furniture", "kitchen_stove"):
		prop("furniture", "kitchen_stove", Vector2i(13, 9))
	# Cells kept clear of the bed (3-4,2-3), dresser (12,2), stove (13,9), rug, door (8,11) and windows.
	for pr: Array in [["lamp_floor", Vector2i(1, 2), 0], ["bookshelf", Vector2i(14, 5), 0], ["table_round_cloth", Vector2i(3, 8), 1],
			["chair_down", Vector2i(3, 7), 0], ["plant2_a", Vector2i(1, 11), 0], ["plant_a", Vector2i(14, 11), 0]]:
		if str(pr[0]) == "bookshelf" and tier() >= 2:
			continue  # it stood on the old east wall; the bigger rooms have their own shelves
		if Art.has("furniture", str(pr[0])):
			prop("furniture", str(pr[0]), pr[1], int(pr[2]))
	# The bigger tiers' rooms (east of x15): the Farmhouse's pantry corner, the
	# Manor's cellar, study and bath.
	var more: Array = []
	if tier() == 2:
		more = [["shelf_jars", Vector2i(16, 2), 1], ["barrel", Vector2i(18, 2), 0], ["table_round_cloth", Vector2i(16, 7), 1], ["chair_down", Vector2i(16, 6), 0], ["plant2_b", Vector2i(18, 11), 0]]
	elif tier() >= 3:
		more = [["study_desk", STUDY, 2], ["bookcase3_a", Vector2i(15, 2), 0], ["lamp_floor_b", Vector2i(20, 2), 0],
			["cellar_hatch", CELLAR, 1], ["keg_wall", CELLAR + Vector2i(2, 0), 1], ["shelf_jars", Vector2i(22, 10), 1],
			["bathtub", BATH, 1], ["sink", Vector2i(21, 3), 0], ["plant2_c", Vector2i(24, 6), 0],
			["table_round_cloth", Vector2i(20, 7), 1], ["chair_down", Vector2i(20, 6), 0], ["plant2_b", Vector2i(24, 11), 0]]
	for pr: Array in more:
		if Art.has("furniture", str(pr[0])):
			var sp := prop("furniture", str(pr[0]), pr[1], int(pr[2]), 0.0, str(pr[0]) != "cellar_hatch")
			if str(pr[0]) == "cellar_hatch" and sp:
				to_under(sp)  # a trapdoor lies in the floor


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
		Hud.pause(get_tree(), "house")
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
