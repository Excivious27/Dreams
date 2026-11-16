extends GameMap
## The starter town: general store, blacksmith, potion shop, town hall, a
## fountain, and five townspeople with their own lines per arc. Shops are
## dialogue menus. Talking once a day raises friendship; gifts raise it more.

const STORE := Rect2i(3, 4, 6, 5)
const SMITH := Rect2i(12, 4, 6, 5)
const POTIONS := Rect2i(2, 13, 5, 5)
const HALL := Rect2i(10, 13, 8, 5)
const FOUNTAIN := Rect2i(9, 21, 2, 2)
const FARM_EXIT := Rect2i(9, 1, 2, 1)

var npcs: Array = []


func scene_id() -> String:
	return "town"


func default_spawn() -> Vector2:
	return Vector2(10 * TILE, 3 * TILE)


func build() -> void:
	cols = 20
	rows = 28
	music_track = "town"
	for b: Rect2i in [STORE, SMITH, POTIONS, HALL]:
		block_rect(b.position.x, b.position.y, b.size.x, b.size.y)
	set_thing(5, 8, {"type": "shop", "shop": "store", "hint": "A: General Store"})
	set_thing(14, 8, {"type": "shop", "shop": "smith", "hint": "A: Blacksmith"})
	set_thing(4, 17, {"type": "shop", "shop": "potions", "hint": "A: Potion Shop"})
	set_thing(13, 17, {"type": "hall", "hint": "A: Town Hall"})
	block_rect(FOUNTAIN.position.x, FOUNTAIN.position.y, 2, 2)
	for y in range(FOUNTAIN.position.y, FOUNTAIN.end.y):
		for x in range(FOUNTAIN.position.x, FOUNTAIN.end.x):
			things[Vector2i(x, y)] = {"type": "fountain", "hint": "A: toss a crystal"}
	for p: Vector2i in [Vector2i(2, 24), Vector2i(17, 25), Vector2i(1, 9), Vector2i(18, 11), Vector2i(6, 26)]:
		set_thing(p.x, p.y, {"type": "tree", "hint": ""})


func after_ready() -> void:
	for c in [Vector2i(9, 1), Vector2i(10, 1), Vector2i(9, 0), Vector2i(10, 0)]:
		blocked.erase(c)
	add_child(GameMenu.new())
	for id in GameState.npcs:
		var d: Dictionary = GameState.npcs[id]
		if id == "sal" and GameState.is_penguins() and int(GameState.run["day"]) < 4:
			continue
		var n := Npc.new()
		n.map = self
		n.setup(id, d, cell_center(Vector2i(int(d["spot"][0]), int(d["spot"][1]))))
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
	if FARM_EXIT.has_point(player.cell()) or player.cell().y <= 0:
		go_to("farm", Vector2(10 * TILE, 27 * TILE), "up")


func interact(c: Vector2i, thing: Dictionary) -> bool:
	for n: Npc in npcs:
		if n.cell() == c or n.position.distance_to(player.position + player.facing_dir() * 14.0) < 16.0:
			_talk(n)
			return true
	match str(thing.get("type", "")):
		"shop":
			_shop(str(thing["shop"]))
			return true
		"hall":
			_hall()
			return true
		"fountain":
			if int(GameState.run["crystals"]) >= 1:
				GameState.run["crystals"] = int(GameState.run["crystals"]) - 1
				hud.toast("Plink. You feel a little luckier.")
				GameState.run["flags"]["fountain"] = int(GameState.run["flags"].get("fountain", 0)) + 1
				Music.instance(get_tree()).sfx("pickup")
			return true
	return false


# ---- shops -------------------------------------------------------------------

func _offers(shop: String) -> Array:
	match shop:
		"store":
			return ["turnip_seed", "strawberry_seed", "corn_seed", "dream_seed", "gift_pie"]
		"smith":
			return ["iron_sword"]
		"potions":
			return ["potion", "energy_tea"]
	return []


func _shop(shop: String) -> void:
	var keeper: String = {"store": "Maple", "smith": "Gideon", "potions": "Wren"}[shop]
	var greet: String = {
		"store": "Seeds, snacks, and whatever fell off the cart. What'll it be?",
		"smith": "Iron holds an edge. Wood holds a splinter. Your call.",
		"potions": "Red for hurts. Tea for tired. Don't mix them, I'm not liable.",
	}[shop]
	if shop == "store" and not GameState.run["flags"].has("store_first"):
		GameState.run["flags"]["store_first"] = true
		await say([{"who": keeper, "text": "You're the one who took the old plot! Here, first-timer's bundle. Don't tell Gideon I give things away."}])
		give("turnip_seed", 4)
		give("energy_tea", 1)
	while true:
		var offers := _offers(shop)
		var opts: Array = []
		for id in offers:
			if GameState.has_tool(id):
				continue
			opts.append("%s  ◆%d" % [GameState.item_name(id), _price(id)])
		opts.append("Leave")
		var d := Dialogue.instance(get_tree())
		d.say([{"who": keeper, "text": "%s  (you have ◆%d)" % [greet, int(GameState.run["crystals"])], "choice": opts, "key": ""}])
		await d.finished
		var pick := d.last_choice
		var buyable := offers.filter(func(i: String) -> bool: return not GameState.has_tool(i))
		if pick < 0 or pick >= buyable.size():
			break
		var id: String = buyable[pick]
		var price := _price(id)
		if int(GameState.run["crystals"]) < price:
			hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			continue
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		if GameState.items[id].get("type", "") == "tool":
			GameState.add_tool(id)
			hud.toast("Got the %s!" % GameState.item_name(id), Color(1, 0.9, 0.4))
		else:
			give(id, 1)
		xp("bartering", 1)
		greet = "Anything else?"


func _price(id: String) -> int:
	var base := GameState.item_value(id)
	var discount := 1.0 - 0.03 * (GameState.skill_level("bartering") - 1)
	return maxi(1, int(ceil(base * 1.5 * discount)))


func _hall() -> void:
	var r := GameState.run
	var who: String = r["names"]["character"]
	if GameState.is_penguins():
		await say([
			{"who": "Mayor Alder", "text": "Ah, %s. The farm's in good hands then. Odd lights over your field the other night, people said. Weather, I expect." % who},
			{"who": "Mayor Alder", "text": "The town board is here if you want it: friendship, skills, quests. (Open the MENU anywhere.)"},
		])
	else:
		await say([
			{"who": "Mayor Alder", "text": "Deed's in order. Name's a little... unusual, but I don't ask questions. People who ask questions in this town tend to leave it."},
			{"who": "Mayor Alder", "text": "If you've got crystals to spend, Gideon could use the business. If you've got trouble, I'd rather not know."},
		])


# ---- talking -----------------------------------------------------------------

func _talk(n: Npc) -> void:
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

func _draw() -> void:
	draw_grass()
	draw_rect(Rect2(8 * TILE, 0, 4 * TILE, rows * TILE), Color("b8945a"))
	draw_rect(Rect2(1 * TILE, 10 * TILE, 18 * TILE, 2 * TILE), Color("b8945a"))
	draw_rect(Rect2(1 * TILE, 19 * TILE, 18 * TILE, 2 * TILE), Color("b8945a"))
	draw_rect(Rect2(7 * TILE, 19 * TILE, 6 * TILE, 6 * TILE), Color("9a9aa6"))
	draw_building(STORE.position.x, STORE.position.y, STORE.size.x, STORE.size.y, Color("c9a86b"), Color("4f8fd0"), "GENERAL STORE")
	draw_building(SMITH.position.x, SMITH.position.y, SMITH.size.x, SMITH.size.y, Color("5a5a66"), Color("3a3a44"), "BLACKSMITH")
	draw_rect(Rect2(13 * TILE + 4, 5.6 * TILE, 8, 8), Color("ff8a3a"))
	draw_building(POTIONS.position.x, POTIONS.position.y, POTIONS.size.x, POTIONS.size.y, Color("7a5aa0"), Color("4a2e6b"), "POTIONS")
	draw_building(HALL.position.x, HALL.position.y, HALL.size.x, HALL.size.y, Color("e8dcc2"), Color("2f6b4a"), "TOWN HALL")
	# Fountain
	draw_circle(Vector2(10 * TILE, 22 * TILE), 17.0, Color("7a7a86"))
	draw_circle(Vector2(10 * TILE, 22 * TILE), 13.0, Color("4d93d6"))
	draw_circle(Vector2(10 * TILE, 22 * TILE - 2), 4.0, Color("9fd8ff"))
	for k in things:
		if things[k].get("type", "") == "tree":
			draw_tree(cell_center(k))
	draw_fence_border()
	draw_rect(Rect2(FARM_EXIT.position * TILE, Vector2i(2, 1) * TILE), Color("b8945a"))
	draw_rect(Rect2(9 * TILE, 0, 2 * TILE, TILE), Color("b8945a"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(6 * TILE, 2 * TILE - 2), "▲ farm", HORIZONTAL_ALIGNMENT_CENTER, 8 * TILE, 7, Color(1, 1, 0.85))
