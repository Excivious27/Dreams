class_name Shops
extends RefCounted
## Shop menus and the town hall talk, shared by the town street and the interiors.

# ---- shops -------------------------------------------------------------------

static func offers(shop: String) -> Array:
	match shop:
		"bait":
			return ["bait", "energy_tea", "bread"]
		"store":
			var base: Array = ["turnip_seed", "potato_seed", "carrot_seed", "strawberry_seed", "corn_seed", "wheat_seed", "gift_pie"]
			if GameState.has_perk("bartering", "Networker"):
				base += ["tomato_seed", "pumpkin_seed", "melon_seed", "dream_seed"]
			return base
		"smith":
			return ["iron_sword", "coal", "copper_ring"]
		"potions":
			return ["potion", "energy_tea", "herb_remedy"]
	return []


static func run(m: GameMap, shop: String) -> void:
	var keeper: String = {"store": "Maple", "smith": "Gideon", "potions": "Wren", "bait": "Finn"}[shop]
	var greet: String = {
		"store": "Seeds, snacks, and whatever fell off the cart. What'll it be?",
		"smith": "Iron holds an edge. Wood holds a splinter. Your call.",
		"potions": "Red for hurts. Tea for tired. Don't mix them, I'm not liable.",
		"bait": "Bait's fresh. Fish aren't picky. People are.",
	}[shop]
	if shop == "store" and not GameState.run["flags"].has("store_first"):
		GameState.run["flags"]["store_first"] = true
		await m.say([{"who": keeper, "text": "You're the one who took the old plot! Here, first-timer's bundle. Don't tell Gideon I give things away."}])
		m.give("turnip_seed", 4)
		m.give("energy_tea", 1)
	while true:
		var offers := offers(shop)
		var opts: Array = []
		for id in offers:
			if GameState.has_tool(id):
				continue
			opts.append("%s  ◆%d" % [GameState.item_name(id), price(id)])
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": keeper, "text": "%s  (you have ◆%d)" % [greet, int(GameState.run["crystals"])], "choice": opts, "key": ""}])
		await d.finished
		var pick := d.last_choice
		var buyable := offers.filter(func(i: String) -> bool: return not GameState.has_tool(i))
		if pick < 0 or pick >= buyable.size():
			break
		var id: String = buyable[pick]
		var price := price(id)
		if int(GameState.run["crystals"]) < price:
			m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			continue
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		if GameState.items[id].get("type", "") == "tool":
			GameState.add_tool(id)
			m.hud.toast("Got the %s!" % GameState.item_name(id), Color(1, 0.9, 0.4))
		else:
			m.give(id, 1)
		m.xp("bartering", 1)
		greet = "Anything else?"


static func price(id: String) -> int:
	var base := GameState.item_value(id)
	return maxi(1, int(ceil(base * 1.5 * GameState.buy_multiplier())))


static func hall(m: GameMap) -> void:
	var r := GameState.run
	var who: String = r["names"]["character"]
	if GameState.is_penguins():
		await m.say([
			{"who": "Mayor Alder", "text": "Ah, %s. The farm's in good hands then. Odd lights over your field the other night, people said. Weather, I expect." % who},
			{"who": "Mayor Alder", "text": "The town board is here if you want it: friendship, skills, quests. (Open the MENU anywhere.)"},
		])
	else:
		await m.say([
			{"who": "Mayor Alder", "text": "Deed's in order. Name's a little... unusual, but I don't ask questions. People who ask questions in this town tend to leave it."},
			{"who": "Mayor Alder", "text": "If you've got crystals to spend, Gideon could use the business. If you've got trouble, I'd rather not know."},
		])


