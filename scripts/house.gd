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
	if not GameState.visiting():  # a guest's spouse, wedding corner and Rec decor stay in the guest's own house
		_romance_props()
		spouse_refresh()
		RecCenter.dress_house(self)  # prize decor from the Rec Center
	DecorMode.fixed_blocked(self)  # what the house itself blocks, before any placed decor
	if not GameState.visiting():
		_seed_starters()  # the starting furniture becomes your own movable decor (C10a)
		var gone: Array = DecorMode.relayout(self)  # e.g. the house grew: pieces on new rooms' fixtures go back to the box
		if not gone.is_empty():
			hud.toast("The house changed: %s went back to your decor box." % ", ".join(gone), Color(1, 0.9, 0.7))
	DecorMode.dress(self)
	_night_was = GameState.is_night()
	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.timeout.connect(_dusk_watch)
	add_child(tm)
	tm.start()
	_entry_button()
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
	if int(GameState.run["time"]) / 60 < 12 and Romance.wedding_due():
		await Wedding.check_morning(self)  # e.g. after a pass-out night at the clinic... or a reload


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	if _spouse and is_instance_valid(_spouse) and _spouse.visible and (_spouse.cell() == _c or (thing.is_empty() and _spouse.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0)):
		later(_talk_spouse)
		return true
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
	var chore := Romance.chore_line(report)  # the spouse helped overnight
	if chore != "":
		lines.append({"text": chore})
	await hud.fade_in(0.8)
	morning_cues(get_tree(), report, false)
	await say(lines)
	_changing = false
	_morning_events()
	Story.on_morning(self)
	player.frozen = false
	spouse_refresh()
	await Wedding.check_morning(self)


## The morning's sounds (c6_10-02/-14): the wake-up jingle (a softer stretch after
## a pass-out), then the till for sales, the hammer for builds, the ripe-crop chime,
## spaced so they don't stack.
const WAKE_ROUGH := ["yawn", "snore"]


static func morning_cues(tree: SceneTree, report: Dictionary, passed_out: bool) -> void:
	if tree == null:
		return
	var mu := Music.instance(tree)
	var cues: Array = []
	var wake := "j_morning"
	if passed_out:
		wake = "snore"
		for n: String in WAKE_ROUGH:
			if mu.has_sfx(n):
				wake = n
				break
	cues.append(wake)
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
		var said: String = {"sold": "I sold the letter to Marlene. He knows my face now.", "used": "The letter I kept opened the tower doors. He wrote it for exactly that.", "burned": "I burned the letter.", "kept": "I kept the letter with the deed.", "memorized": "I memorised the handwriting on the letter."}.get(l, "There's a letter I haven't dealt with.")
		lines.append({"who": "Journal", "text": "Someone knows I'm here. %s" % said})
	var open_q: Array = r["quests"].filter(func(q: Dictionary) -> bool: return not q["done"])
	if not open_q.is_empty():
		lines.append({"who": "To do", "text": "\n".join(open_q.map(func(q: Dictionary) -> String: return "• " + str(q["text"])))})
	await say(lines)


func draw_map() -> void:
	draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color("1a1410"))
	if Art.has("tiles", "fl_wood"):
		draw_tileset_rect("fl_wood", Rect2i(1, 2, cols - 2, rows - 3), Color("a07a4c"))
		_draw_room_floors()
		if _starter_id("rug_rect_red") != "":
			pass  # the rug is your own decor now (placed by DecorMode)
		elif Art.has("furniture", "rug_rect_red"):
			# A bordered 2:1 rug (the carpet tile's inside is a flat colour block).
			draw_texture_rect(Art.tex("furniture", "rug_rect_red"), Rect2(6 * TILE, 6 * TILE + 8, 4 * TILE, 2 * TILE), false)
		else:
			_draw_rug("fl_carpet_red", Rect2i(6, 6, 4, 3), Color("b03a2e"))
		_draw_room_walls()
		var night := GameState.is_night()
		Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(6 * TILE + 8, 2 * TILE))
		Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(10 * TILE + 8, 2 * TILE))
		for wx: int in ([14] if tier() == 2 else ([15, 21] if tier() >= 3 else [])):
			Art.draw_prop(self, "furniture", "window_night" if night else "window_day", Vector2(wx * TILE + 8, 2 * TILE))
		if tier() >= 3 and Art.has("furniture", "rug_rect_red") and _starter_id("rug_rect_red") == "":
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
	if Art.has("tiles", "fl_wood"):
		_draw_shell()
	draw_rect(Rect2(DOOR.x * TILE, DOOR.y * TILE, TILE, TILE), Color("3a2412"))
	DecorMode.draw_flat(self)  # your rugs and wall art, baked with the room


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
		if Art.has("furniture", str(pr[0])) and _starter_id(str(pr[0])) == "":
			prop("furniture", str(pr[0]), pr[1], int(pr[2]))
	# The bigger tiers' rooms (east of x15): the Farmhouse's pantry corner, the
	# Manor's cellar, study and bath.
	var more: Array = []
	if tier() == 2:
		more = [["shelf_jars", Vector2i(16, 2), 1], ["barrel", Vector2i(15, 2), 0], ["table_round_cloth", Vector2i(16, 7), 1], ["chair_down", Vector2i(16, 6), 0], ["plant2_b", Vector2i(18, 11), 0]]
	elif tier() >= 3:
		more = [["study_desk", STUDY, 2], ["bookcase3_a", Vector2i(15, 2), 0], ["lamp_floor_b", Vector2i(20, 2), 0],
			["cellar_hatch", CELLAR, 1], ["keg_wall", CELLAR + Vector2i(2, 0), 1], ["shelf_jars", Vector2i(21, 11), 1],
			["bathtub", BATH, 1], ["sink", Vector2i(21, 3), 0], ["plant2_c", Vector2i(24, 6), 0],
			["table_round_cloth", Vector2i(20, 7), 1], ["chair_down", Vector2i(20, 6), 0], ["plant2_b", Vector2i(24, 11), 0]]
	for pr: Array in more:
		if Art.has("furniture", str(pr[0])) and (str(pr[0]) in FIXED_ART or _starter_id(str(pr[0])) == ""):
			var sp := prop("furniture", str(pr[0]), pr[1], int(pr[2]), 0.0, str(pr[0]) != "cellar_hatch")
			if str(pr[0]) == "cellar_hatch" and sp:
				to_under(sp)  # a trapdoor lies in the floor


## The dresser: read the journal or change your look (hair, hat, body).
func _dresser() -> void:
	var d := Dialogue.instance(get_tree())
	var pdata: Dictionary = GameState.playables.get(str(GameState.run.get("playable", "")), {})
	var sprite_id := GameState.sprite_for_playable(str(GameState.run.get("playable", "")))
	var can_look := (bool(pdata.get("custom", false)) and PaperDoll.available()) or sprite_id == "penguin"
	var opts: Array = ["Journal", "Change my look", "Decorate", "Close"] if can_look else ["Journal", "Decorate", "Close"]
	d.say([{"text": "The dresser. A mirror on the inside of the door.", "choice": opts, "key": ""}])
	await d.finished
	var pickd := str(opts[d.last_choice]) if d.last_choice >= 0 and d.last_choice < opts.size() else "Close"
	if pickd == "Decorate":
		DecorMode.open(self)
		return
	if pickd == "Journal":
		_journal()
	elif pickd == "Change my look" and can_look:
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


# ---- spouse (CONDUCT 7 P1: Romance) --------------------------------------------

var _spouse: Npc = null

## Their corner piece per tier (east rooms): tier 2 Farmhouse, tier 3 Manor.
const SPOUSE_CORNER := {1: Vector2i(14, 5), 2: Vector2i(17, 4), 3: Vector2i(23, 8)}


## Where the spouse stands now (Vector2i(-1,-1) = out: at work on a job day).
static func spouse_cell(t: int, hour: int) -> Vector2i:
	if Romance.is_job_time():
		return Vector2i(-1, -1)
	if hour >= 22 or hour < 6:
		return Vector2i(BED.x + 2, BED.y + 1)    # beside the bed
	if hour < 9:
		return Vector2i(11, 9)                   # the kitchen, by the stove
	if hour < 17:
		return SPOUSE_CORNER[t] + Vector2i(0, 2) # their corner
	return Vector2i(4, 9)                        # by the table


## Spawn / move / hide the spouse for the hour (also called after the wedding).
func spouse_refresh() -> void:
	if not Romance.is_married() or GameState.visiting():
		if _spouse != null and is_instance_valid(_spouse):
			_spouse.visible = false
		return
	var id := Romance.spouse()
	var at := spouse_cell(tier(), int(GameState.run["time"]) / 60)
	if _spouse == null or not is_instance_valid(_spouse):
		_spouse = Npc.new()
		_spouse.map = self
		_spouse.setup(id, GameState.npcs.get(id, {}), cell_center(at if at.x >= 0 else DOOR))
		_spouse.routine = []  # hold them here: their town routine never pulls them out
		_spouse.hold = true
		_spouse.wander = 0.0
		add_child(_spouse)
		_romance_props()
	_spouse.visible = at.x >= 0
	if at.x >= 0:
		_spouse.position = cell_center(at)
		_spouse.home = _spouse.position
		_spouse._target = _spouse.position


func _talk_spouse() -> void:
	player.frozen = true
	_spouse.face(player.position)
	emote(_spouse, "heart", 1.2)
	await Romance.talk(self, Romance.spouse())
	player.frozen = false


var _corner_done := false


## The spouse's corner piece (romance.json corner) and, the first week, wedding decor.
func _romance_props() -> void:
	if _corner_done or not Romance.is_married() or GameState.visiting():
		return
	_corner_done = true
	var c := SPOUSE_CORNER[tier()] as Vector2i
	var art := str(Romance.cand(Romance.spouse()).get("corner", ""))
	if Art.has("furniture", art):
		prop("furniture", art, c, 1)
	if int(GameState.run["day"]) - int(Romance.st()["married_day"]) < 7:
		if Art.has("props", "wedding_heart_sign"):
			prop("props", "wedding_heart_sign", Vector2i(DOOR.x + 2, DOOR.y - 1))
	if tier() == 2 and Art.has("props", "wedding_bench"):
		prop("props", "wedding_bench", Vector2i(17, 9), 1)


# ---- decorating (CONDUCT 10a P2: DecorMode) --------------------------------------

## Rooms per tier for wallpaper/flooring (x ranges; the Farmhouse pantry, the Manor's study and bath).
const ROOMS_BY_TIER := {1: {"main": Rect2i(1, 0, 14, 13)},
	2: {"main": Rect2i(1, 0, 14, 13), "pantry": Rect2i(15, 0, 4, 13)},
	3: {"main": Rect2i(1, 0, 14, 13), "study": Rect2i(15, 0, 6, 13), "bath": Rect2i(21, 0, 4, 13)}}
## Pieces with a job (they carry things/hooks): never decor, never moved.
const FIXED_ART := ["study_desk", "cellar_hatch", "keg_wall", "bathtub", "sink"]
## The movable starting furniture per tier [art, cell, extra_w]: once the catalogue
## knows the art (decor.json entry with art "furniture/<name>") it is seeded into
## run.decor.placed["house"] as your own decor; until then it is drawn as before.
const STARTERS := {
	1: [["lamp_floor", Vector2i(1, 2), 0], ["bookshelf", Vector2i(14, 5), 0], ["table_round_cloth", Vector2i(3, 8), 1],
		["chair_down", Vector2i(3, 7), 0], ["plant2_a", Vector2i(1, 11), 0], ["plant_a", Vector2i(14, 11), 0], ["rug_rect_red", Vector2i(6, 7), 3]],
	2: [["shelf_jars", Vector2i(16, 2), 1], ["barrel", Vector2i(15, 2), 0], ["table_round_cloth", Vector2i(16, 7), 1],
		["chair_down", Vector2i(16, 6), 0], ["plant2_b", Vector2i(18, 11), 0]],
	3: [["bookcase3_a", Vector2i(15, 2), 0], ["lamp_floor_b", Vector2i(20, 2), 0], ["shelf_jars", Vector2i(21, 11), 1],
		["plant2_c", Vector2i(24, 6), 0], ["table_round_cloth", Vector2i(20, 7), 1], ["chair_down", Vector2i(20, 6), 0],
		["plant2_b", Vector2i(24, 11), 0], ["rug_rect_red", Vector2i(19, 7), 3]]}

static var _art_ids := {}


## The catalogue id whose art is furniture/<art> ("" = not in the catalogue yet).
static func _starter_id(art: String) -> String:
	if _art_ids.is_empty() or int(_art_ids.get("_n", -1)) != (Decor.data()["items"] as Dictionary).size():
		_art_ids = {"_n": (Decor.data()["items"] as Dictionary).size()}
		for id in Decor.data()["items"]:
			var a := str(Decor.entry(str(id)).get("art", ""))
			if a.begins_with("furniture/") and not _art_ids.has(a.get_slice("/", 1)):
				_art_ids[a.get_slice("/", 1)] = str(id)
	return str(_art_ids.get(art, ""))


## Seed the starting furniture as placed decor: each starter once (keyed art@x,y in
## run.decor.seeded.house), as soon as the catalogue knows its art; a bigger tier's new
## pieces join when the house grows; a starter that doesn't fit goes to the box.
func _seed_starters() -> void:
	var d := Decor.st()
	if not (d.get("seeded", null) is Dictionary):
		d["seeded"] = {}
	if not (d["seeded"].get("house", null) is Dictionary):
		d["seeded"]["house"] = {}
	var done: Dictionary = d["seeded"]["house"]
	var t := tier()
	var want: Array = STARTERS[1].duplicate() + (STARTERS.get(t, []) if t > 1 else [])
	if t >= 2:
		want = want.filter(func(pr: Array) -> bool: return str(pr[0]) != "bookshelf")
	var list: Array = DecorMode._own_placed("house")
	for pr: Array in want:
		var c: Vector2i = pr[1]
		var key := "%s@%d,%d" % [str(pr[0]), c.x, c.y]
		var id := _starter_id(str(pr[0]))
		if id == "" or done.has(key):
			continue
		done[key] = int(GameState.run.get("day", 1))
		if DecorMode.why_not(self, id, c) == "":
			list.append({"id": id, "cell": [c.x, c.y], "rot": 0})
		else:
			DecorMode._box_back(id)
		if not (d["got"] as Dictionary).has(id):
			d["got"][id] = int(GameState.run.get("day", 1))


## "Starting layout": every starter you still own goes back to its first spot
## (DecorMode stores the room first; pieces come out of the box, never new copies).
func decor_reset() -> int:
	var t := tier()
	var want: Array = STARTERS[1].duplicate() + (STARTERS.get(t, []) if t > 1 else [])
	if t >= 2:
		want = want.filter(func(pr: Array) -> bool: return str(pr[0]) != "bookshelf")
	var n := 0
	for pr: Array in want:
		var id := _starter_id(str(pr[0]))
		if id != "" and Decor.owned(id) > 0 and DecorMode.place(self, id, pr[1]) == "":
			n += 1
	return n


func decor_bounds() -> Rect2i:
	return Rect2i(1, 2, cols - 2, rows - 3)


func decor_wall_row() -> int:
	return 1


func decor_door() -> Vector2i:
	return DOOR + Vector2i(0, -1)


func decor_rooms() -> Dictionary:
	return ROOMS_BY_TIER[tier()]


func decor_windows() -> Array:
	return [6, 10] + ([14] if tier() == 2 else ([15, 21] if tier() >= 3 else []))


## Cells a floor piece may not cover, with why (shown on the ghost).
func decor_reserved() -> Dictionary:
	var r := {}
	var t := tier()
	r[CHEST + Vector2i(0, 1)] = "the dresser"
	r[DOOR] = "the door"
	r[DOOR + Vector2i(0, -1)] = "the door"
	r[Vector2i(13, 10)] = "the stove"
	# The spouse spots are fixed for every hour (job days included): keep them free always.
	for sc: Vector2i in [Vector2i(BED.x + 2, BED.y + 1), Vector2i(11, 9), SPOUSE_CORNER[t] + Vector2i(0, 2), Vector2i(4, 9)]:
		r[sc] = "a family spot"
	if Romance.is_married():
		for dx in 2:
			r[SPOUSE_CORNER[t] + Vector2i(dx, 0)] = "the spouse's corner"
	if t == 2:
		for dx in 2:
			r[Vector2i(17 + dx, 9)] = "the bench"
	if t >= 3:
		for dx in 2:
			r[CELLAR + Vector2i(dx, 0)] = "the cellar hatch"
			r[CELLAR + Vector2i(2 + dx, 0)] = "the keg rack"
			r[BATH + Vector2i(dx, 0)] = "the bath"
		for dx in 3:
			r[STUDY + Vector2i(dx, 0)] = "the study desk"
			r[STUDY + Vector2i(dx, 1)] = "the study desk"
		r[Vector2i(21, 3)] = "the sink"
	return r


func decor_must_reach() -> Array:
	var out: Array = [BED + Vector2i(0, 1), CHEST, Vector2i(13, 9)]
	if tier() >= 3:
		out += [CELLAR, STUDY + Vector2i(1, 0), BATH, Vector2i(21, 3)]
	return out


func decor_changed() -> void:
	queue_redraw()  # walls/floors are part of the baked map drawing


## Guests: the host changed the house's look.
func on_world_sync(d: Dictionary) -> void:
	super.on_world_sync(d)
	if d.has("decor_home") or d.has("decor_home_d"):
		DecorMode.dress(self)
		queue_redraw()


## Each room's flooring from run.decor.floor (missing = the house's own wood).
func _draw_room_floors() -> void:
	var rooms: Dictionary = ROOMS_BY_TIER[tier()]
	for room in rooms:
		var id := DecorMode.surface_of("floor", str(room))
		if id == "":
			continue
		var rr: Rect2i = rooms[room]
		for y in range(2, rows - 1):
			for x in range(maxi(1, rr.position.x), mini(cols - 1, rr.end.x)):
				DecorMode.draw_floor_cell(self, id, Vector2i(x, y))
	# A thin threshold where one room meets the next, so each room reads as its own.
	for room in rooms:
		var rr2: Rect2i = rooms[room]
		if rr2.position.x > 1:
			draw_rect(Rect2(rr2.position.x * TILE - 1, 2 * TILE, 2, (rows - 3) * TILE), Color(0.18, 0.12, 0.08, 0.55))


## Each room's stretch of back wall: its wallpaper (run.decor.wall) or the house floral,
## with end pieces at the room's edges (the floral's tiling middle is _m2, c10_03).
func _draw_room_walls() -> void:
	var rooms: Dictionary = ROOMS_BY_TIER[tier()]
	for room in rooms:
		var rr: Rect2i = rooms[room]
		var x0 := maxi(1, rr.position.x)
		var x1 := mini(cols - 2, rr.end.x - 1)
		var id := DecorMode.surface_of("wall", str(room))
		for x in range(x0, x1 + 1):
			var part := "_l" if x == x0 else ("_r" if x == x1 else "_m")
			if id != "" and DecorMode.draw_wall_col(self, id, x, part):
				continue
			var nm: String = "wl_floral" + (part if part != "_m" else "_m2")
			var t := Art.tex("tiles", nm) if Art.has("tiles", nm) else Art.tex("tiles", "wl_floral_m")
			if t:
				draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)


var _night_was := false


## Windows follow dusk and dawn while you stay inside (they were fixed at entry).
func _dusk_watch() -> void:
	var n := GameState.is_night()
	if n != _night_was:
		_night_was = n
		queue_redraw()


var _decor_btn: Button = null


## A small "Decorate" button under the room (also on the dresser).
func _entry_button() -> void:
	if GameState.visiting() or not is_instance_valid(hud):
		return
	var ly := CanvasLayer.new()
	ly.layer = 5
	var bt := Button.new()
	bt.text = "Decorate"
	bt.add_theme_font_size_override("font_size", Settings.font(8))
	bt.position = Vector2(206, 252)  # the dark band under the room, clear of the furniture and the HUD
	bt.size = Vector2(60, 22)
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(func() -> void:
		if not get_tree().paused and not Dialogue.instance(get_tree()).active:
			DecorMode.open(self))
	ly.add_child(bt)
	add_child(ly)
	_decor_btn = bt
	var hide_t := Timer.new()  # hidden while decorate mode or a menu owns the screen
	hide_t.wait_time = 0.25
	hide_t.process_mode = Node.PROCESS_MODE_ALWAYS
	hide_t.timeout.connect(func() -> void:
		if is_instance_valid(bt):
			bt.visible = not get_tree().paused)
	ly.add_child(hide_t)
	hide_t.start()
	Hud.extra_rects.append(Rect2(bt.position, bt.size))
	tree_exiting.connect(func() -> void: Hud.extra_rects.erase(Rect2(bt.position, bt.size)))


## Side walls, the front lip and the back wall's floor shadow, like the town interiors'
## (the house floated on black, c10_03), in the main room's wall colours.
func _draw_shell() -> void:
	var I0: Variant = load("res://scripts/interior.gd")
	var wid := DecorMode.surface_of("wall", "main")
	var wa := DecorMode.surface_art(wid) if wid != "" else ["tiles", "wl_floral", false]
	var trim := Art.tex("tiles", str(wa[1]) + "_m") if str(wa[0]) == "tiles" else null
	if trim == null:
		trim = Art.tex("tiles", "wl_floral_m")
	var ty := float(I0.first_opaque_row(trim)) if trim else 0.0
	var sx := 12.0
	var gq: Vector2i = I0.wall_gap(trim) if trim else Vector2i.ZERO
	if gq != Vector2i.ZERO and gq.x < 20 and gq.y > 12:
		sx = 2.0 if gq.x >= 10 else float(gq.y) + 1.0
	var rim := Color("3a2a1c")
	for side in [0, cols - 1]:
		var x0 := float(side * TILE) + (TILE - 8.0 if side == 0 else 0.0)
		for y in range(2, rows - 1):
			var r := Rect2(x0, y * TILE, 8, TILE)
			if trim:
				draw_texture_rect_region(trim, r, Rect2(sx, 26, 8, 16), Color(0.62, 0.56, 0.5))
			else:
				draw_rect(r, rim)
	for side in [0, cols - 1]:
		var x1 := float(side * TILE) + (TILE - 8.0 if side == 0 else 0.0)
		for y in range(2, rows - 1):
			draw_rect(Rect2(x1 + (8.0 if side == 0 else -4.0), y * TILE, 4, TILE), Color(0, 0, 0, 0.28))
	for x in range(0, cols):
		if x == DOOR.x:
			continue
		var r2 := Rect2(x * TILE, (rows - 1) * TILE, TILE, 8)
		if x == 0:
			r2 = Rect2(TILE - 8, (rows - 1) * TILE, 8, 8)
		elif x == cols - 1:
			r2 = Rect2((cols - 1) * TILE, (rows - 1) * TILE, 8, 8)
		if trim:
			draw_texture_rect_region(trim, r2, Rect2(sx, ty + 2, 8, 8), Color(0.8, 0.75, 0.7))
		else:
			draw_rect(r2, rim)
	draw_rect(Rect2(TILE, 2 * TILE, (cols - 2) * TILE, 3), Color(0, 0, 0, 0.22))


## The floor word under a cell (footsteps): the room's flooring id, else "wood".
func floor_at(c: Vector2i) -> String:
	for room in ROOMS_BY_TIER[tier()]:
		var rr: Rect2i = ROOMS_BY_TIER[tier()][room]
		if c.x >= rr.position.x and c.x < rr.end.x:
			var id := DecorMode.surface_of("floor", str(room))
			if id != "":
				var a := str(DecorMode.surface_art(id)[1])
				for w: Array in [["stone", "stone"], ["tile", "stone"], ["marble", "stone"], ["carpet", "grass"], ["rug", "grass"]]:
					if str(w[0]) in a:
						return str(w[1])
			return "wood"
	return "wood"
