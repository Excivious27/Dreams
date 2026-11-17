class_name Shops
extends RefCounted
## Shop menus and the town hall talk, shared by the town street and the interiors.

# ---- shops -------------------------------------------------------------------

static func offers(shop: String) -> Array:
	match shop:
		"bait":
			return ["bait", "energy_tea", "bread"]
		"store":
			# Maple stocks this season's seeds (and next season's in the last week).
			var by_season := {
				"spring": ["turnip_seed", "potato_seed", "carrot_seed", "strawberry_seed"],
				"summer": ["corn_seed", "tomato_seed", "rice_seed"],
				"fall": ["pumpkin_seed", "cranberry_seed", "sugar_beet_seed"],
				"winter": ["snow_pea_seed"],
			}
			var rare := {
				"spring": ["flax_seed", "tea_leaf_seed"],
				"summer": ["melon_seed", "hops_seed", "cotton_seed", "lotus_seed", "ghost_pepper_seed"],
				"fall": ["grape_seed", "moon_melon_seed"],
				"winter": [],
			}
			var se := GameState.season()
			var base: Array = by_season[se].duplicate()
			if GameState.day_of_season() >= 22:
				base += by_season[GameState.season_of(int(GameState.run["day"]) + 7)]
			base += ["wheat_seed", "gift_pie"]
			if GameState.has_perk("bartering", "Networker"):
				base += rare[se] + ["dream_seed"]
			return base
		"smith":
			return ["iron_sword", "coal", "copper_ring"]
		"potions":
			return ["potion", "energy_tea", "herb_remedy"]
		"orla":
			return ["flour", "wheat_seed", "bread"]
		"marlowe":
			return ["lamp_oil", "bait", "coffee"]
		"tam":
			return ["sheep_wool", "cider", "apple"]
		"old_moss":
			return ["glow_cap", "slime_goo", "tea"]
		"granite":
			return ["coal", "copper", "iron", "dynamite"]
		"sel":
			return ["rune_tablet", "old_coin", "book"]
		"lodge":
			var base: Array = ["meat", "bait"]
			if GameState.has_friend_perk("rook", 4):
				base += ["arrow", "trap"]
			return base
	return []


static func run(m: GameMap, shop: String) -> void:
	var keeper: String = {"store": "Maple", "smith": "Gideon", "potions": "Wren", "bait": "Finn", "lodge": "Rook", "orla": "Orla", "marlowe": "Marlowe", "tam": "Tam", "old_moss": "Old Moss", "granite": "Granite", "sel": "Sel"}.get(shop, "Shop")
	var greet: String = {
		"store": "Seeds, snacks, and whatever fell off the cart. What'll it be?",
		"smith": "Iron holds an edge. Wood holds a splinter. Your call.",
		"potions": "Red for hurts. Tea for tired. Don't mix them, I'm not liable.",
		"bait": "Bait's fresh. Fish aren't picky. People are.",
		"lodge": "Meat's from the hills. Don't ask which hill.",
		"orla": "Flour's fresh. Wheat seed if you want to grow your own.",
		"marlowe": "Oil for lamps. Bait for fish. Coffee for me, but I'll share.",
		"tam": "Wool, cider, apples. The sheep did most of the work.",
		"old_moss": "Jars. Don't ask what's in the ones at the back.",
		"granite": "Ore from the walls. Dynamite if you've got the nerve.",
		"sel": "Relics. Real ones. Mostly.",
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
	return GameState.buy_price(id)


static func hall(m: GameMap) -> void:
	var r := GameState.run
	var who: String = r["names"]["character"]
	if not r["flags"].has("hall_intro"):
		r["flags"]["hall_intro"] = true
		if GameState.is_penguins():
			await m.say([
				{"who": "Mayor Alder", "text": "Ah, %s. The farm's in good hands then. Odd lights over your field the other night, people said. Weather, I expect." % who},
				{"who": "Mayor Alder", "text": "Anything bigger than a shed on that land needs a permit. I stamp them here. It's mostly so I know what's going on."},
			])
		else:
			await m.say([
				{"who": "Mayor Alder", "text": "Deed's in order. Name's a little... unusual, but I don't ask questions. People who ask questions in this town tend to leave it."},
				{"who": "Mayor Alder", "text": "Permits for building are stamped here. Pay the fee, keep it quiet, build what you like."},
			])
	# Permits counter.
	while true:
		var ids: Array = []
		var opts: Array = []
		for id in Builds.data():
			var nd := Builds.next_def(id)
			if nd.is_empty() or int(nd.get("permit", 0)) <= 0:
				continue
			var have := Builds.permitted(id) >= int(nd["tier"])
			opts.append("%s%s permit  ◆%d%s" % ["✓ " if have else "", str(nd["name"]), Builds.permit_price(id), "" if not have else " (held)"])
			ids.append(id)
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "Mayor Alder", "text": "Permits. ◆%d on you.%s" % [int(r["crystals"]), "  (friends of the office pay 20% less)" if GameState.has_friend_perk("alder", 4) else ""], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= ids.size():
			return
		var msg := Builds.buy_permit(str(ids[i]))
		m.hud.toast(msg, Color(1, 0.9, 0.4) if msg.begins_with("Permit stamped") else Color(1, 0.7, 0.7))
		if msg.begins_with("Permit stamped"):
			Music.instance(m.get_tree()).sfx("pickup")


