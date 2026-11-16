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
	set_thing(CHEST.x, CHEST.y, {"type": "chest", "hint": "A: dresser (journal)"})
	block_rect(1, 1, cols - 2, 1)  # back wall
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go outside"})
	set_thing(13, 9, {"type": "kitchen", "hint": "A: cook (campfire)"})


func after_ready() -> void:
	_place_props()


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"door":
			go_to("farm", Vector2(13 * TILE + 8, 11 * TILE + 4), "down")
			return true
		"bed":
			_sleep()
			return true
		"chest":
			_journal()
			return true
		"kitchen":
			later(Crafting.run.bind(self, "kitchen", "Kitchen"))
			return true
		"pet_bed":
			hud.toast("%s curls up for a second, then follows you anyway." % GameState.names()["pet"])
			return true
	return false


func _sleep() -> void:
	player.frozen = true
	await hud.fade_out(0.8)
	var report := GameState.sleep()
	var lines: Array = [{"text": "Day %d." % int(GameState.run["day"])}]
	if int(report["earned"]) > 0:
		lines.append({"who": "Sell box", "text": "%s\nTotal: ◆%d" % ["\n".join(report["sold"]), int(report["earned"])]})
	if int(report["grown"]) > 0:
		lines.append({"text": "%d watered crop%s grew overnight." % [int(report["grown"]), "" if int(report["grown"]) == 1 else "s"]})
	await hud.fade_in(0.8)
	await say(lines)
	_morning_events()
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
		var l := str(r["flags"].get("letter", ""))
		var said: String = {"burned": "I burned the letter.", "kept": "I kept the letter with the deed.", "memorized": "I memorized the handwriting on the letter."}.get(l, "There's a letter I haven't dealt with.")
		lines.append({"who": "Journal", "text": "Someone knows I'm here. %s" % said})
	var open_q: Array = r["quests"].filter(func(q: Dictionary) -> bool: return not q["done"])
	if not open_q.is_empty():
		lines.append({"who": "To do", "text": "\n".join(open_q.map(func(q: Dictionary) -> String: return "• " + str(q["text"])))})
	await say(lines)


func draw_map() -> void:
	draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color("1a1410"))
	if Art.has("tiles", "fl_wood"):
		draw_tileset_rect("fl_wood", Rect2i(1, 2, cols - 2, rows - 3), Color("a07a4c"))
		draw_tileset_rect("fl_carpet_red", Rect2i(6, 6, 4, 3), Color("b03a2e"))
		for x in range(1, cols - 1):
			var idx := 0 if x == 1 else (2 if x == cols - 2 else 1)
			var nm: String = ["wl_floral_l", "wl_floral_m", "wl_floral_r"][idx]
			var t := Art.tex("tiles", nm)
			if t:
				draw_texture_rect(t, Rect2(x * TILE, 0, TILE, TILE * 2), false)
		var night := int(GameState.run["time"]) >= 19 * 60
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
	# Day one: a bed and a dresser. Everything else gets built or bought later.
	if not Art.has("furniture", "bed_single"):
		return
	var kit := Art.has("furniture", "bed_blue")
	prop("furniture", "bed_blue" if kit else "bed_single", Vector2i(BED.x, BED.y + 1), 1)
	prop("furniture", "dresser" if kit else "chest_closed", CHEST)
	if Art.has("furniture", "kitchen_stove"):
		prop("furniture", "kitchen_stove", Vector2i(13, 9))
