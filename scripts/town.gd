extends GameMap
## The starter town: general store, blacksmith, potion shop, town hall, a
## fountain, and five townspeople with their own lines per arc. Shops are
## dialogue menus. Talking once a day raises friendship; gifts raise it more.

const STORE := Rect2i(4, 5, 6, 5)
const SMITH := Rect2i(16, 5, 6, 5)
const POTIONS := Rect2i(3, 15, 5, 5)
const HALL := Rect2i(13, 15, 8, 5)
const FOUNTAIN := Rect2i(12, 24, 2, 2)
const FARM_EXIT := Rect2i(12, 0, 2, 2)
const BEACH_EXIT := Rect2i(12, 38, 2, 2)
const MOUNTAIN_EXIT := Rect2i(26, 12, 2, 3)

var npcs: Array = []


func scene_id() -> String:
	return "town"


func default_spawn() -> Vector2:
	return Vector2(13 * TILE, 3 * TILE)


func build() -> void:
	cols = 28
	rows = 40
	pad = 6
	border = {"n": "trees", "s": "trees", "w": "trees", "e": "cliff"}
	music_track = "town"
	add_exit(FARM_EXIT, "farm", Vector2(36 * TILE, 56 * TILE), "up", "▲ farm")
	add_exit(BEACH_EXIT, "beach", Vector2(14 * TILE, 2 * TILE + 8), "down", "▼ beach")
	add_exit(MOUNTAIN_EXIT, "mountain", Vector2(2 * TILE, 39 * TILE + 8), "right", "mountain ▶")
	for b: Rect2i in [STORE, SMITH, POTIONS, HALL]:
		block_rect(b.position.x, b.position.y, b.size.x, b.size.y)
	set_thing(6, 9, {"type": "door", "interior": "store", "hint": "A: General Store"})
	set_thing(18, 9, {"type": "door", "interior": "smith", "hint": "A: Blacksmith"})
	set_thing(5, 19, {"type": "door", "interior": "potions", "hint": "A: Potion Shop"})
	set_thing(16, 19, {"type": "door", "interior": "hall", "hint": "A: Town Hall"})
	# Homes and the rest of main street.
	for d in [[4, 30, "inn", "A: the Inn", 2, 27, 5, 4], [22, 30, "bakery", "A: Bakery", 21, 27, 3, 4], [8, 36, "clinic", "A: Clinic", 7, 33, 3, 4], [19, 36, "library", "A: Library", 17, 33, 4, 4], [25, 36, "chapel", "A: Chapel", 24, 33, 3, 4], [3, 24, "cottage_a", "A: Wren's cottage", 2, 22, 3, 3], [16, 24, "cottage_b", "A: Finn's cottage", 15, 22, 3, 3]]:
		block_rect(int(d[4]), int(d[5]), int(d[6]), int(d[7]))
		set_thing(int(d[0]), int(d[1]), {"type": "door", "interior": str(d[2]), "hint": str(d[3])})
	block_rect(FOUNTAIN.position.x, FOUNTAIN.position.y, 2, 2)
	for y in range(FOUNTAIN.position.y, FOUNTAIN.end.y):
		for x in range(FOUNTAIN.position.x, FOUNTAIN.end.x):
			things[Vector2i(x, y)] = {"type": "fountain", "hint": "A: toss a crystal"}
	for p: Vector2i in [Vector2i(1, 7), Vector2i(18, 8), Vector2i(6, 26), Vector2i(12, 26), Vector2i(18, 22)]:
		set_thing(p.x, p.y, {"type": "tree", "hint": ""})
	block_rect(2, 22, 3, 3)    # cottage a
	block_rect(15, 22, 3, 3)   # cottage b
	block_rect(17, 13, 2, 2)   # well
	block_rect(2, 19, 2, 2)    # market stall
	blocked[Vector2i(7, 2)] = true
	block_rect(12, 2, 2, 1)
	blocked[Vector2i(4, 25)] = true
	blocked[Vector2i(14, 25)] = true
	for c: Vector2i in [Vector2i(6, 12), Vector2i(13, 12), Vector2i(6, 21), Vector2i(13, 21)]:
		blocked[c] = true
	extend(22, 12)


func after_ready() -> void:
	WorldGen.add_backdrop(self, "hills")
	if Art.has("props", "bus_shelter"):
		prop("props", "bus_shelter", Vector2i(cols - 10, 4), 3)
	if Art.has("props", "town_gate"):
		prop("props", "town_gate", Vector2i(FARM_EXIT.position.x - 4, 3), 10, 0.0, false)
	if Art.has("props", "balloon"):
		var bl := AnimatedSprite2D.new()
		bl.sprite_frames = Art.frames("props", {"idle": "balloon"}, {"idle": 3.0})
		bl.animation = "idle"
		bl.scale = Vector2(0.5, 0.5)
		bl.position = cell_center(Vector2i(cols - 8, 8))
		bl.offset = Vector2(0, -48)
		add_child(bl)
		bl.play("idle")
		set_thing(cols - 8, 8, {"type": "balloon", "hint": "A: balloon"})
	_place_props()
	for id in GameState.npcs:
		var d: Dictionary = GameState.npcs[id]
		if id == "sal" and GameState.is_penguins() and int(GameState.run["day"]) < 4:
			continue
		if id in ["finn", "lumi", "theo", "hazel"] and not GameState.run["flags"].has("town_seen"):
			pass
		var n := Npc.new()
		n.map = self
		n.setup(id, d, cell_center(Vector2i(int(d["spot"][0]) + 2, int(d["spot"][1]) + 3)))
		add_child(n)
		npcs.append(n)
	if not GameState.run["flags"].has("town_seen"):
		GameState.run["flags"]["town_seen"] = true
		_arrival.call_deferred()


func _arrival() -> void:
	player.frozen = true
	var town: String = GameState.names()["town"]
	if GameState.is_penguins():
		await say([
			{"text": "%s. Twelve houses, one fountain, and the smell of bread from Maple's. Everyone looks up when you pass. Not unkindly." % town},
		])
	else:
		await say([
			{"text": "%s. Small enough that a new face is news. You keep your hood up and your hands in your pockets." % town},
			{"text": "There's a man by the fountain who doesn't look up when you pass. That's the one to watch."},
		])
	player.frozen = false


func _process(delta: float) -> void:
	super(delta)
	if player.frozen or _changing:
		return
	pass


func has_npc_at(c: Vector2i) -> bool:
	for n: Npc in npcs:
		if n.cell() == c:
			return true
	return false


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.cell() == c or (thing.is_empty() and n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0):
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"shop", "hall", "door":
			var id := str(thing.get("interior", thing.get("shop", "hall")))
			GameMap.next_interior = id
			go_to("interior", Vector2.ZERO, "up")
			return true
		"fountain":
			if int(GameState.run["crystals"]) >= 1:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 1
				hud.toast("Plink. You feel a little luckier.")
				GameState.run["flags"]["fountain"] = int(GameState.run["flags"].get("fountain", 0)) + 1
				Music.instance(get_tree()).sfx("pickup")
			return true
	return false


# ---- talking -----------------------------------------------------------------

func _talk(n: Npc) -> void:
	emote(n, "talk", 1.0, -30.0)
	var r := GameState.run
	var id := n.id
	var name := str(GameState.npcs[id]["name"])
	var fr: Dictionary = r["friendship"]
	var sel := str(r["selected"])
	var it: Dictionary = GameState.items.get(sel, {})
	player.frozen = true
	if GameState.complete_quest("meet_town"):
		hud.toast("Quest done: met the town.", Color(1, 0.9, 0.4))
	# Gift
	if sel != "" and GameState.count(sel) > 0 and it.get("type", "") != "tool" and it.get("type", "") != "seed":
		GameState.add_item(sel, -1)
		var gain := int(it.get("friend", 0)) + maxi(2, GameState.item_value(sel) / 3)
		fr[id] = int(fr.get(id, 0)) + gain
		await say([{"who": name, "text": _gift_line(id, sel)}])
		hud.toast("%s +%d" % [name, gain], Color(1, 0.8, 0.9))
		player.frozen = false
		return
	var talked: Dictionary = r["talked_today"]
	if not talked.has(id):
		talked[id] = true
		fr[id] = int(fr.get(id, 0)) + 5
	await say(_lines(id, int(fr.get(id, 0))))
	player.frozen = false


func _gift_line(id: String, item: String) -> String:
	var n := GameState.item_name(item)
	match id:
		"maple": return "A %s! For me? Oh, you're going to fit right in here." % n
		"gideon": return "Hm. A %s. ...Thank you. Don't make it weird." % n
		"wren": return "A %s. I can do something with this. Probably not what you'd expect." % n
		"alder": return "A %s, how civic-minded. It'll go in the town records." % n
		"sal": return "A %s. Huh. Nobody gives me things. What do you want?" % n
	return "Thanks for the %s." % n


func _lines(id: String, friend: int) -> Array:
	var r := GameState.run
	var who: String = r["names"]["character"]
	var pet: String = r["names"]["pet"]
	var peng := GameState.is_penguins()
	var meadow_done := GameState.quest_done("clear_meadow")
	match id:
		"maple":
			if peng:
				if friend >= 40:
					return [{"who": "Maple", "text": "You know, %s, I saw that light land in your field. I didn't tell anyone. Some things you keep for the people who earn them." % who}]
				return [{"who": "Maple", "text": "Morning! Turnips grow fast, strawberries pay better. And bring %s by sometime, I've got a bone with their name on it." % pet}]
			if friend >= 40:
				return [{"who": "Maple", "text": "I had a brother who ran from something once. He never said what. I never asked. He's a baker in the capital now. Just... saying."}]
			return [{"who": "Maple", "text": "New face, old plot. Seeds are in the back. Pay when you can. I mean that."}]
		"gideon":
			if GameState.has_tool("iron_sword"):
				return [{"who": "Gideon", "text": "Keep the edge dry. Iron remembers rust the way people remember insults."}]
			if peng:
				return [{"who": "Gideon", "text": "Wooden sword. Hm. It'll do for whatever's bleating in that meadow. For now."}]
			return [{"who": "Gideon", "text": "I don't ask what a farmer needs an iron sword for. I only ask for a hundred and twenty crystals."}]
		"wren":
			if meadow_done:
				return [{"who": "Wren", "text": "The howling stopped. You did that. The bottles on the left shelf are half price for you. Don't tell Alder, he'll want it in the records."}]
			if peng:
				return [{"who": "Wren", "text": "Something fell out of the sky three nights ago and the town's pretending it didn't. I'm not pretending. If it talks to you, tell it I said hello."}]
			return [{"who": "Wren", "text": "You've got the look of someone who sleeps with a chair under the doorknob. Red potion's on the left. The tea's for the nights."}]
		"alder":
			if peng:
				return [{"who": "Mayor Alder", "text": "A good year for turnips, I'm told. Odd year for the sky. We'll take the turnips."}]
			return [{"who": "Mayor Alder", "text": "Taxes are low, questions are lower. Welcome to %s." % r["names"]["town"]}]
		"finn":
			if GameState.skill_level("fishing") >= 3:
				return [{"who": "Finn", "text": "Level three already? Try the pond at dusk. The starfin only bites when the light goes blue."}]
			return [{"who": "Finn", "text": "Cast with A, wait for the splash, press A again. Patience catches more than tackle."}]
		"lumi":
			return [{"who": "Lumi", "text": "The sky over your farm has the strangest colours lately. I've started painting it. Don't tell Alder, he thinks it's weather." if peng else "I paint what I see. Lately I see a lot of people looking over their shoulders."}]
		"theo":
			return [{"who": "Theo", "text": "There's a book in the hall about crystals that fall from the sky. Nobody's checked it out in forty years. Until this week." if peng else "Every town has a ledger of who owes what to whom. I keep ours. I don't keep names."}]
		"hazel":
			return [{"who": "Hazel", "text": "Water before nine, harvest after six. Turnips forgive, strawberries don't. Come borrow my hoe if yours breaks."}]
		"sal":
			if meadow_done and not peng:
				if not r["flags"].has("sal_recruited"):
					r["flags"]["sal_recruited"] = true
					GameState.add_quest("gang", "Recruit your first crew. (Sal is in. The rest is up to Tom.)")
					return [
						{"who": "Sal", "text": "That was the President's man in the meadow. Not a good one, but one of his. You put him down."},
						{"who": "Sal", "text": "I used to run with a crew in the river cities, before. If you're building something... I'm in. Call it rent."},
					]
				return [{"who": "Sal", "text": "Say the word, boss. I've got nothing but time and a bad knee."}]
			if peng:
				return [{"who": "Sal", "text": "Drifted in last week. Stayed for the quiet. The quiet's getting loud, in the east. You hear it?"}]
			return [{"who": "Sal", "text": "...You're not from here. Neither am I. Let's leave it there, yeah?"}]
	return [{"who": id, "text": "..."}]


# ---- drawing -----------------------------------------------------------------

func draw_map() -> void:
	draw_grass(3)
	WorldGen.draw_ground_detail(self, 31, 0.08)
	var roads := cells_of([Rect2i(11, 0, 4, rows), Rect2i(1, 11, 26, 2), Rect2i(1, 21, 26, 2), Rect2i(1, 31, 26, 2), FARM_EXIT, BEACH_EXIT, MOUNTAIN_EXIT])
	if Art.has("tiles", "cobble_a"):
		for c: Vector2i in roads:
			Art.draw_tile(self, "tiles", "cobble_a", Vector2(c * TILE), 4)
	else:
		draw_ground("dirt", roads)
	draw_tileset_rect("flagstone" if Art.has("tiles", "flagstone") else "stone", Rect2i(9, 22, 8, 7), Color("9a9aa6"))
	draw_tileset_rect("brick_road" if Art.has("tiles", "brick_road") else "stone", Rect2i(10, 3, 6, 3), Color("9a9aa6"))
	draw_exits()
	if not Art.has("buildings", "store"):
		draw_building(STORE.position.x, STORE.position.y, STORE.size.x, STORE.size.y, Color("c9a86b"), Color("4f8fd0"), "GENERAL STORE")
		draw_building(SMITH.position.x, SMITH.position.y, SMITH.size.x, SMITH.size.y, Color("5a5a66"), Color("3a3a44"), "BLACKSMITH")
		draw_building(POTIONS.position.x, POTIONS.position.y, POTIONS.size.x, POTIONS.size.y, Color("7a5aa0"), Color("4a2e6b"), "POTIONS")
		draw_building(HALL.position.x, HALL.position.y, HALL.size.x, HALL.size.y, Color("e8dcc2"), Color("2f6b4a"), "TOWN HALL")
	if pad == 0:
		draw_fence_border()


func _place_props() -> void:
	if not Art.has("buildings", "store"):
		return
	prop("buildings", "store", Vector2i(STORE.position.x, STORE.end.y - 1), STORE.size.x - 1)
	prop("buildings", "smith", Vector2i(SMITH.position.x, SMITH.end.y - 1), SMITH.size.x - 1)
	prop("buildings", "potions", Vector2i(POTIONS.position.x, POTIONS.end.y - 1), POTIONS.size.x - 1)
	prop("buildings", "hall", Vector2i(HALL.position.x, HALL.end.y - 1), HALL.size.x - 1)
	prop("buildings", "fountain", Vector2i(FOUNTAIN.position.x, FOUNTAIN.end.y - 1), 1, 4.0)
	prop("buildings", "inn" if Art.has("buildings", "inn") else "cottage_a", Vector2i(2, 30), 4)
	prop("buildings", "bakery" if Art.has("buildings", "bakery") else "cottage_b", Vector2i(21, 30), 2)
	prop("buildings", "clinic" if Art.has("buildings", "clinic") else "cottage_a", Vector2i(7, 36), 2)
	prop("buildings", "library" if Art.has("buildings", "library") else "cottage_b", Vector2i(17, 36), 3)
	if Art.has("buildings", "clock_tower"):
		prop("buildings", "clock_tower", Vector2i(24, 10), 1)
		block_rect(24, 6, 2, 5)
	if Art.has("buildings", "bandstand"):
		prop("buildings", "bandstand", Vector2i(2, 2), 3)
		block_rect(2, 0, 4, 3)
	if Art.has("buildings", "chapel"):
		prop("buildings", "chapel", Vector2i(24, 36), 2)
		block_rect(24, 32, 3, 5)
	for c: Vector2i in [Vector2i(9, 20), Vector2i(16, 20)]:
		prop("props", "flowerbed_red" if c.x < 12 else "flowerbed_blue", c, 1)
		blocked[c] = true
		blocked[c + Vector2i(1, 0)] = true
	prop("props", "bench_wood", Vector2i(10, 28), 1)
	prop("props", "bench_green", Vector2i(14, 28), 1)
	block_rect(10, 28, 2, 1); block_rect(14, 28, 2, 1)
	prop("props", "statue", Vector2i(12, 4), 1)
	block_rect(12, 3, 2, 2)
	prop("props", "well_stone", Vector2i(2, 14), 1)
	prop("props", "stall_red", Vector2i(2, 8), 1); prop("props", "stall_green", Vector2i(24, 18), 1)
	block_rect(2, 7, 2, 2); block_rect(24, 17, 2, 2)
	prop("buildings", "well", Vector2i(23, 22), 1)
	for c: Vector2i in [Vector2i(8, 13), Vector2i(17, 13), Vector2i(8, 23), Vector2i(17, 23), Vector2i(8, 31), Vector2i(17, 31)]:
		prop("props", "lamp", c)
	prop("props", "stall", Vector2i(2, 24), 1)
	prop("props", "signpost", Vector2i(9, 2))
	prop("props", "board", Vector2i(15, 2), 1)
	for c: Vector2i in [Vector2i(5, 36), Vector2i(21, 36)]:
		prop("props", "lantern_lit", c)
	prop("props", "arch", Vector2i(12, 20), 1)
	prop("props", "crates_a", Vector2i(24, 4))
	prop("props", "crates_b", Vector2i(25, 4))
	prop("props", "hay", Vector2i(2, 4))
	var avoid := {}
	for b: Rect2i in [STORE.grow(1), SMITH.grow(1), POTIONS.grow(1), HALL.grow(1), Rect2i(9, 21, 8, 9), Rect2i(10, 0, 6, 40), Rect2i(0, 10, 28, 4), Rect2i(0, 20, 28, 4), Rect2i(0, 30, 28, 4)]:
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				avoid[Vector2i(x, y)] = true
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), 33, 5, avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), 34, 14, avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), 35, 8, ["pigeon", "pigeon", "sparrow", "cat_orange", "cat_grey", "butterfly_blue"])
