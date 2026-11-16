extends GameMap
## Inside your house: bed (sleep to the next day), a chest with story notes,
## and the door back out.

const BED := Vector2i(2, 2)
const CHEST := Vector2i(8, 2)
const DOOR := Vector2i(5, 8)


func scene_id() -> String:
	return "house"


func default_spawn() -> Vector2:
	return Vector2(5 * TILE + 8, 7 * TILE)


func build() -> void:
	cols = 11
	rows = 10
	has_sky = false
	music_track = "house"
	set_thing(BED.x, BED.y, {"type": "bed", "hint": "A: sleep until morning"})
	set_thing(BED.x + 1, BED.y, {"type": "bed", "hint": "A: sleep until morning"})
	set_thing(CHEST.x, CHEST.y, {"type": "chest", "hint": "A: open journal"})
	block_rect(1, 1, 9, 1)  # back wall
	set_thing(DOOR.x, DOOR.y, {"type": "door", "hint": "A: go outside"})
	set_thing(5, 4, {"type": "table", "hint": ""})
	set_thing(6, 4, {"type": "table", "hint": ""})


func after_ready() -> void:
	add_child(GameMenu.new())


func interact(_c: Vector2i, thing: Dictionary) -> bool:
	match str(thing.get("type", "")):
		"door":
			go_to("farm", Vector2(5 * TILE + 8, 8 * TILE + 4), "down")
			return true
		"bed":
			_sleep()
			return true
		"chest":
			_journal()
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


func _draw() -> void:
	draw_rect(Rect2(0, 0, cols * TILE, rows * TILE), Color("3a2a1c"))
	for y in range(2, rows - 1):
		for x in range(1, cols - 1):
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("a07a4c") if (x + y) % 2 == 0 else Color("96724a"))
	draw_rect(Rect2(TILE, TILE, (cols - 2) * TILE, TILE), Color("c9b08a"))  # back wall
	draw_rect(Rect2(4 * TILE, TILE + 3, 10, 10), Color("9fd8ff"))  # window
	# Bed
	draw_rect(Rect2(BED.x * TILE, BED.y * TILE, 2 * TILE, TILE + 4), Color("6b3b2a"))
	draw_rect(Rect2(BED.x * TILE + 2, BED.y * TILE + 2, 2 * TILE - 4, TILE), Color("d8536a"))
	draw_rect(Rect2(BED.x * TILE + 3, BED.y * TILE + 3, 10, 8), Color("f5f0e6"))
	# Chest
	draw_rect(Rect2(CHEST.x * TILE + 1, CHEST.y * TILE + 4, TILE - 2, TILE - 4), Color("8b5a2b"))
	draw_rect(Rect2(CHEST.x * TILE + 1, CHEST.y * TILE + 2, TILE - 2, 4), Color("c9a86b"))
	# Table
	draw_rect(Rect2(5 * TILE, 4 * TILE + 4, 2 * TILE, TILE - 4), Color("7a5230"))
	draw_rect(Rect2(5 * TILE + 10, 4 * TILE + 6, 6, 4), Color("f2e05c"))
	# Rug and door
	draw_rect(Rect2(4 * TILE, 6 * TILE, 3 * TILE, 2 * TILE), Color("b03a2e"))
	draw_rect(Rect2(DOOR.x * TILE, DOOR.y * TILE, TILE, TILE), Color("3a2412"))
