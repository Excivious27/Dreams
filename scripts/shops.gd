class_name Shops
extends RefCounted
## Shop menus and the town hall talk, shared by the town street and the interiors.

# ---- shops -------------------------------------------------------------------

## Seeds whose crop passes `keep(crop_id, crop)`, in or near season, a few at a
## time: the pick turns over every 3 days so a phone shop list stays short.
static func _seeds(keep: Callable, n: int, salt: int) -> Array:
	var se := GameState.season()
	var pool: Array = []
	for sid in GameState.items:
		var it: Dictionary = GameState.items[sid]
		if str(it.get("type", "")) != "seed":
			continue
		var cid := str(it.get("crop", ""))
		if not GameState.crops.has(cid):
			continue
		var cd: Dictionary = GameState.crops[cid]
		var cs := str(cd.get("season", "any"))
		if cs != "any" and cs != se:
			continue
		if keep.call(cid, cd):
			pool.append(str(sid))
	pool.sort()
	if pool.size() <= n:
		return pool
	var out: Array = []
	var start := (int(GameState.run.get("day", 1)) / 3 + salt) * n
	for i in n:
		out.append(pool[(start + i) % pool.size()])
	return out


## Crop ids whose seeds the town sells today (Maple, Tam) or that you already
## hold seeds or harvest of: board crop orders only ask for these.
static func growable_now() -> Dictionary:
	var out := {}
	var sids: Array = offers("store") + offers("tam")
	for sid in GameState.items:
		var it: Dictionary = GameState.items[sid]
		if str(it.get("type", "")) == "seed" and (sid in sids or GameState.count(str(sid)) > 0):
			out[str(it.get("crop", ""))] = true
	for cid in GameState.crops:
		if GameState.count(str(GameState.crops[cid].get("yield", ""))) > 0:
			out[str(cid)] = true
	return out


static func offers(shop: String) -> Array:
	match shop:
		"bait":
			return ["bait", "energy_tea", "bread"]
		"store":
			# Maple stocks this season's seeds (and next season's in the last week).
			var by_season := {
				"spring": ["turnip_seed", "potato_seed", "carrot_seed", "strawberry_seed", "flax_seed"],
				"summer": ["corn_seed", "tomato_seed", "rice_seed", "sunflower_seed"],
				"fall": ["pumpkin_seed", "cranberry_seed", "sugar_beet_seed"],
				"winter": ["snow_pea_seed"],
			}
			var rare := {
				"spring": ["tea_leaf_seed"],
				"summer": ["melon_seed", "hops_seed", "cotton_seed", "lotus_seed", "ghost_pepper_seed"],
				"fall": ["grape_seed", "moon_melon_seed"],
				"winter": [],
			}
			var se := GameState.season()
			var base: Array = by_season[se].duplicate()
			if GameState.day_of_season() >= 22:
				base += by_season[GameState.season_of(int(GameState.run["day"]) + 7)]
			# Plus a few of the season's other vegetables and herbs.
			base += _seeds(func(cid: String, cd: Dictionary) -> bool: return int(cd.get("tier", 1)) <= 2 and not bool(cd.get("tree", false)) and not ("berry" in cid) and not (cid + "_seed" in base) and not (cid + "_seed" in rare[se]) and cid != "wheat", 4, 0)
			base += ["wheat_seed", "fertilizer", "bread", "coffee", "hay", "gift_pie", "paint", "sap", "candy", "toy", "chest"]
			if int(GameState.run.get("bag_up", 0)) < GameState.BAG_MAX_UP:
				base.append("backpack_%d" % (int(GameState.run.get("bag_up", 0)) + 1))
			if GameState.has_perk("bartering", "Networker") or GameState.has_friend_perk("maple", 4):
				base += rare[se] + ["dream_seed"]
			return base + Romance.shop_extra("store")
		"smith":
			return ["iron_sword", "coal", "copper_ring"] + grown("smith")
		"potions":
			return ["potion", "energy_tea", "herb_remedy"]
		"orla":
			return ["flour", "wheat_seed", "bread"]
		"marlowe":
			return ["lamp_oil", "bait", "rope"] + Romance.shop_extra("marlowe")
		"tam":
			# Orchard stock: saplings and berry canes for the season.
			return ["sheep_wool", "hay"] + ranch_supplies() + ({"summer": ["blueberry_seed"], "fall": ["pear_seed"]}.get(GameState.season(), []) as Array) + _seeds(func(cid: String, cd: Dictionary) -> bool: return not (cid in ["blueberry", "pear"]) and int(cd.get("tier", 1)) <= 3 and (bool(cd.get("tree", false)) or "berry" in cid or "melon" in cid or cid in ["pineapple", "dragonfruit", "kiwi", "passionfruit", "watermelon", "cantaloupe"]) and not cid.begins_with("crystal") and int(cd.get("tier", 1)) <= GameState.progress_tier() + 2, 4, 1)
		"old_moss":
			return ["glowcap", "slime_goo", "herb_remedy"] + _seeds(func(cid: String, cd: Dictionary) -> bool: return cid in ["mushroom", "truffle", "morel", "glowcap", "glowcap2", "glowcap3", "saffron", "aloe", "wasabi", "ginger", "turmeric", "vanilla", "tea", "coffee", "cacao", "watercress", "water_chestnut", "sesame", "chia"] and int(cd.get("tier", 1)) <= GameState.progress_tier() + 2, 4, 2)
		"granite":
			return ["stone", "brick", "coal", "copper", "iron", "glass", "dynamite"]
		"sel":
			# Seeds from the old places: wonders once you've gone far enough to grow them.
			return ["rune_tablet", "old_coin", "book"] + _seeds(func(cid: String, cd: Dictionary) -> bool: return int(cd.get("tier", 1)) >= 4 and int(cd.get("tier", 1)) <= GameState.progress_tier() + 1 and not cid.begins_with("crystal"), 3, 3)
		"catkins":
			return ["litter_box", "crystal_bloom", "potion"] + _seeds(func(cid: String, cd: Dictionary) -> bool: return cid.begins_with("crystal") or cid in ["starflower", "moonflower", "moonberry", "starfruit"], 3, 4)
		"lodge":
			var base: Array = ["meat", "bait"]
			if GameState.has_friend_perk("rook", 4):
				base += ["arrow", "trap"]
			return base
	return []


## Stock that arrives as you progress (C8 P6, c8_14_07): shop -> [[progress tier, ids]].
## Arc-only items (items.json "arc") are left out of the other arc's shop.
const GROWN := {
	"smith": [[2, ["silver_ring", "iron_helm", "leather_vest", "running_shoes"]], [3, ["steel_sword", "ruby_ring", "iron_mail", "iron_greaves"]], [4, ["crystal_sword", "ring_warmth", "moon_ring"]]],  # c10_07: tier tops out at 4; ring_platinum stays Madame Aurum's
	"potions": [[3, ["dream_tonic"]]],
	"granite": [[3, ["silver", "tin"]]],
}


static func grown(shop: String) -> Array:
	var out: Array = []
	var arc := str(GameState.run.get("arc", ""))
	for row: Array in GROWN.get(shop, []):
		if GameState.progress_tier() < int(row[0]):
			continue
		for id: String in row[1]:
			var a := str(GameState.items.get(id, {}).get("arc", ""))
			if GameState.items.has(id) and (a == "" or a == arc):
				out.append(id)
	return out


## The shop-list line: name · price, and for seeds what the crop does (C8 P6,
## c8_01-16): grow days, what one harvest sells for, regrowth, "!" when it won't
## ripen before the season ends.
static func line(id: String) -> String:
	var it: Dictionary = GameState.items.get(id, {})
	var cd: Dictionary = GameState.crops.get(str(it.get("crop", "")), {})
	if cd.is_empty():
		return "%s · %s%s" % [GameState.item_name(id), Money.fmt(price(id)), food_note(id)]
	var nm := GameState.item_name(id).trim_suffix(" Seeds").trim_suffix(" Seed")
	var days := int(cd.get("days", 0))
	var bits := "%s · %s · %dd" % [nm, Money.fmt(price(id)), days]
	var y := str(cd.get("yield", ""))
	if GameState.items.has(y):
		bits += " · sells %s" % Money.fmt(GameState.item_value(y))
	if int(cd.get("regrow", 0)) > 0:
		bits += " · again %dd" % int(cd["regrow"])
	var cs := str(cd.get("season", "any"))
	var left := GameState.DAYS_PER_SEASON - GameState.day_of_season() + 1
	if cs != "any" and (cs != GameState.season() or days > left):
		bits += " !"
	return bits


## " · +45 energy +5 hp" for food in a shop list (c8_06): the same sums as
## GameState.consume (cooked x8 heal into energy, raw x5, potions none).
static func food_note(id: String) -> String:
	var it: Dictionary = GameState.items.get(id, {})
	var ty := str(it.get("type", ""))
	if not ty in ["food", "consumable", "tonic", "potion", "crop", "fruit", "fish", "forage"]:
		return ""
	var en_mult := 8 if ty in ["food", "consumable", "tonic", "gift"] else (0 if ty == "potion" else 5)
	var en := int(it.get("energy", 0)) + int(it.get("heal", 0)) * en_mult
	var bits := ""
	if en > 0:
		bits += " · +%d energy" % en
	if int(it.get("heal", 0)) > 0:
		bits += " +%d hp" % int(it["heal"])
	return bits


static func run(m: GameMap, shop: String, absent := false) -> void:
	var keeper: String = {"store": "Maple", "smith": "Gideon", "potions": "Wren", "bait": "Finn", "lodge": "Rook", "orla": "Orla", "marlowe": "Marlowe", "tam": "Tam", "posy": "Posy", "old_moss": "Old Moss", "granite": "Granite", "sel": "Sel", "catkins": "Catkins", "hazel": "Hazel", "carpenter": "Tess", "lumi": "Lumi", "crew_marlene": "Marlene", "crew_deuce": "Deuce", "crew_specs": "Specs", "crew_halo": "Halo"}.get(shop, "Shop")
	var greet: String = {
		"store": "Seeds, snacks, and whatever fell off the cart. What'll it be?",
		"smith": "Iron holds an edge. Wood holds a splinter. Your call.",
		"potions": "Red for hurts. Tea for tired. Don't mix them, I'm not liable.",
		"bait": "Bait's fresh. Fish aren't picky. People are.",
		"lodge": "Meat's from the hills. Don't ask which hill.",
		"orla": "Flour's fresh. Wheat seed if you want to grow your own.",
		"marlowe": "Oil for lamps. Bait for fish. Coffee for me, but I'll share.",
		"tam": "Wool, hay, and saplings for the orchard. The sheep did most of the work.",
		"old_moss": "Jars. Don't ask what's in the ones at the back.",
		"granite": "Ore from the walls. Dynamite if you've got the nerve.",
		"sel": "Relics. Real ones. Mostly.",
		"catkins": "Litter boxes. Every Grump stops to hold its nose. Don't ask how we found out.",
		"carpenter": "Chairs, beds, shelves, rugs, and pieces for the yard. New stock off the bench every few days.",  # Tess's workshop (C10b P1)
		"lumi": "Off the loom this week. Try it on, it's all looks and no fuss.",  # wardrobe counter (C10b P1, cottage_c)
		"crew_marlene": "Everything here has a price and a story. The story's free.",
		"crew_deuce": "Signs, cabinets, lights. Make your place look like a winner's.",
		"crew_specs": "Screens and gadgets, tested twice. Mostly.",
		"crew_halo": "Garage stock. Chrome, drums, and the odd car for the yard.",
	}.get(shop, seller_greet(shop) if seller_greet(shop) != "" else "What'll it be?")
	if absent:
		# Nobody at the counter: a note on the till, no keeper's voice.
		greet = "A note on the till: \"Back soon. Prices on the tags. - %s\"" % keeper
		keeper = ""
	if shop == "store" and not GameState.run["flags"].has("store_first"):
		GameState.run["flags"]["store_first"] = true
		if absent:
			await m.say([{"text": "A bundle on the counter, tagged: \"For whoever took the old plot. First-timer's gift, don't tell Gideon. - Maple\""}])
		else:
			await m.say([{"who": keeper, "text": "You're the one who took the old plot! Here, first-timer's bundle. Don't tell Gideon I give things away."}])
		m.give("turnip_seed", 10)
		m.give("energy_tea", 1)
	# A ranch-only counter (Hazel's farmhouse, Posy's back room: fix2) opens the animal counter straight away.
	if offers(shop).is_empty() and DecorSources.today(shop).is_empty() and not seller_row(shop).is_empty():
		if absent:
			await m.say([{"text": greet}])
		else:
			await animal_counter(m, shop, keeper)
		return
	# A decor-only counter (Hazel, Lumi, crew shops: no item offers) opens its shelf straight away (C10b P1).
	if offers(shop).is_empty() and not DecorSources.today(shop).is_empty():
		await DecorSources.shelf(m, shop, keeper if keeper != "" else "Shelf")
		return
	while true:
		var offers := offers(shop)
		var opts: Array = []
		for id in offers:
			if GameState.has_tool(id):
				continue
			opts.append(line(id))
		var decor_i := -1
		if not DecorSources.today(shop).is_empty():
			decor_i = opts.size()
			opts.append("Home goods (decor shelf)")  # C10a P4: rotating decor from data/decor.json
		var animal_i := -1
		if not absent and not animals_for(shop).is_empty():
			animal_i = opts.size()
			opts.append("Animals for your ranch")  # C11a P3: Ranch species this keeper sells
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": keeper, "text": "%s  (you have %s)" % [greet, Money.fmt(int(GameState.run["crystals"]))], "choice": opts, "key": ""}])
		await d.finished
		var pick := d.last_choice
		if animal_i >= 0 and pick == animal_i:
			await animal_counter(m, shop, keeper if keeper != "" else "Counter")
			continue
		if decor_i >= 0 and pick == decor_i:
			await DecorSources.shelf(m, shop, keeper if keeper != "" else "Shelf")
			continue
		var buyable := offers.filter(func(i: String) -> bool: return not GameState.has_tool(i))
		if pick < 0 or pick >= buyable.size():
			break
		var id: String = buyable[pick]
		var price := price(id)
		var qty := 1
		if str(GameState.items[id].get("type", "")) == "seed" or id in BULK:
			var dq := Dialogue.instance(m.get_tree())
			var most := mini(MAX_SEEDS, int(GameState.run["crystals"]) / maxi(1, price))
			var qs: Array = [1, 5, 10]
			var qo: Array = ["1", "5", "10"]
			if most > 10:
				qs.append(most)
				qo.append("%d (all you can afford)" % most)
			qo.append("Back")
			var cdq: Dictionary = GameState.crops.get(str(GameState.items[id].get("crop", "")), {})
			var how := (" Comes back every %d days after the first picking." % int(cdq["regrow"])) if int(cdq.get("regrow", 0)) > 0 else " One harvest per seed."
			if id in BULK:
				how = str(BULK[id])
			dq.say([{"who": keeper, "text": "%s, %s each.%s How many?  (you have %s)" % [GameState.item_name(id), Money.fmt(price), how, Money.fmt(int(GameState.run["crystals"]))], "choice": qo, "key": ""}])
			await dq.finished
			if dq.last_choice < 0 or dq.last_choice >= qs.size():
				continue
			qty = int(qs[dq.last_choice])
		price *= qty
		if int(GameState.run["crystals"]) < price:
			m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			continue
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		Music.instance(m.get_tree()).sfx("cash", "coin")
		if id.begins_with("backpack_"):
			GameState.run["bag_up"] = int(GameState.run.get("bag_up", 0)) + 1
			m.hud.toast("%s! Bag now holds %d kinds of item." % [GameState.item_name(id), GameState.bag_size()], Color(1, 0.9, 0.4))
		elif GameState.items[id].get("type", "") == "tool":
			GameState.add_tool(id)
			m.hud.toast("Got the %s!" % GameState.item_name(id), Color(1, 0.9, 0.4))
		else:
			m.give(id, qty)
		m.xp("bartering", 1)
		greet = "Anything else?" if not absent else "(The till's honesty jar clinks.)"


const MAX_SEEDS := 99
## Goods sold by the handful like seeds (C11a P3): what the "How many?" line says.
const BULK := {"hay": " One feeds one animal for a day."}
## Ranch supplies a farm keeper stocks once tools/gen_ranch.py has made them (ids that don't exist are left out).
const RANCH_SUPPLIES := ["feed_mix", "animal_treat", "animal_brush", "shears", "milk_pail"]


static func ranch_supplies() -> Array:
	return RANCH_SUPPLIES.filter(func(i: String) -> bool: return GameState.items.has(i))


## A ranch seller's row (ranch.json "sellers", tools/gen_ranch.py SELLERS) or {}.
static func seller_row(seller: String) -> Dictionary:
	var all: Dictionary = Ranch.data().get("sellers", {}) if Ranch.data().get("sellers", null) is Dictionary else {}
	return all.get(seller.to_lower(), {}) if all.get(seller.to_lower(), null) is Dictionary else {}


## The seller's greeting in this arc ("" = not a ranch seller).
static func seller_greet(seller: String) -> String:
	var r := seller_row(seller)
	return str(r.get("greet" if GameState.is_penguins() else "greet_gang", r.get("greet", "")))


## Is a seller away today (an away flag set: "gang:<flag>" only counts in the gangster arc)?
static func seller_away(seller: String) -> bool:
	var fl: Dictionary = GameState.run.get("flags", {}) if GameState.run.get("flags", null) is Dictionary else {}
	for f in seller_row(seller).get("away", []):
		var fs := str(f)
		if fs.begins_with("gang:"):
			if not GameState.is_penguins() and fl.has(fs.trim_prefix("gang:")):
				return true
		elif fl.has(fs):
			return true
	return false


## Who actually sells a species today: its buy.seller, or that seller's fallback while they're away.
static func seller_of(sid: String) -> String:
	var buy: Variant = Ranch.species(sid).get("buy", {})
	var sel := str((buy as Dictionary).get("seller", "")).to_lower() if buy is Dictionary else ""
	if sel != "" and seller_away(sel):
		var fb := str(seller_row(sel).get("fallback", ""))
		if fb != "":
			return fb
	return sel


## Counter things for a room (fix2): every ranch seller whose counter stands in this interior and who is
## in today. Interior.build appends them to the room's things (the till asks TownHours.counter_shut).
static func ranch_counters(iid: String) -> Array:
	var out: Array = []
	var all: Dictionary = Ranch.data().get("sellers", {}) if Ranch.data().get("sellers", null) is Dictionary else {}
	for sel in all:
		var r: Dictionary = all[sel]
		if str(r.get("interior", "")) != iid or iid == "" or not (r.get("cell", null) is Array) or seller_away(str(sel)):
			continue
		var c: Array = r["cell"]
		out.append({"type": "counter", "shop": str(sel), "cell": [int(c[0]), int(c[1])], "hint": "A: animals", "solid": false})
	return out


## Ranch species a keeper sells (data/ranch.json species.buy.seller = shop/keeper id, or the keeper standing
## in for an away seller: Shops.seller_of), this arc only.
static func animals_for(seller: String) -> Array:
	var out: Array = []
	var arc := str(GameState.run.get("arc", ""))
	var sp_all: Dictionary = Ranch.data().get("species", {})
	for sid in sp_all:
		var sp: Dictionary = sp_all[sid]
		var buy: Dictionary = sp.get("buy", {}) if sp.get("buy", {}) is Dictionary else {}
		if buy.is_empty() or seller_of(str(sid)) != seller.to_lower() or int(buy.get("price", 0)) <= 0:
			continue
		if str(sp.get("arc", "")) not in ["", arc, "both"]:
			continue
		if str(buy.get("flag", "")) != "" and not (GameState.run.get("flags", {}) as Dictionary).has(str(buy["flag"])):
			continue  # C11b P3 (c11b_02-08): a story gate (e.g. the Moon Hare after Gideon's moon quest)
		out.append(str(sid))
	out.sort_custom(func(a: String, b: String) -> bool: return int(sp_all[a]["buy"]["price"]) < int(sp_all[b]["buy"]["price"]))
	return out


static func animal_name(sid: String) -> String:
	var sp := Ranch.species(sid)
	if GameState.run.get("arc", "") == "gangsters" and str(sp.get("name_gang", "")) != "":
		return str(sp["name_gang"])
	return str(sp.get("name", sid.capitalize()))


## Why an animal can't be bought now ("" = it can): its home not built, too low a tier, or full.
static func animal_why(sid: String) -> String:
	var sp := Ranch.species(sid)
	var home := str(sp.get("home", ""))
	var need := maxi(1, int((sp.get("buy", {}) as Dictionary).get("tier", 1)))
	var bid := Ranch.build_of(home)  # c11b_01-04: any home whose Plans build has another id (apiary -> beehive)
	if Ranch.tier(home) < need:
		var td := Builds.tier_def(bid, need)
		return "needs a %s" % str(td.get("name", bid.capitalize())) if not td.is_empty() else "needs a %s" % bid
	if Ranch.roster(home).size() >= Ranch.capacity(home):
		return "the %s is full" % str(Builds.current_def(bid).get("name", bid))
	return ""


## The animal counter: pick a species, pay, it moves into its home tonight (Ranch.add).
static func animal_counter(m: GameMap, seller: String, keeper: String) -> void:
	while true:
		var ids := animals_for(seller)
		var opts: Array = []
		for sid: String in ids:
			var why := animal_why(sid)
			var pr := int(Ranch.species(sid)["buy"]["price"])
			opts.append("%s  %s%s" % [animal_name(sid), Money.fmt(pr), ("  (%s)" % why) if why != "" else ""])
		opts.append("Back")
		var d := Dialogue.instance(m.get_tree())
		var gang: bool = str(GameState.run.get("arc", "")) == "gangsters"
		var greet := "Healthy stock, raised right. Nobody asks questions about a farm." if gang else "Healthy animals, raised with care. Who's coming home with you?"
		if offers(seller).is_empty() and seller_greet(seller) != "":
			greet = seller_greet(seller)  # a ranch-only counter speaks for itself (fix2)
		d.say([{"who": keeper, "text": "%s  (you have %s)" % [greet, Money.fmt(int(GameState.run["crystals"]))], "choice": opts, "key": ""}])
		await d.finished
		var pick := d.last_choice
		if pick < 0 or pick >= ids.size():
			return
		var sid: String = ids[pick]
		var why2 := animal_why(sid)
		if why2 != "":
			m.hud.toast("%s: %s." % [animal_name(sid), why2], Color(1, 0.8, 0.6))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			continue
		var price := int(Ranch.species(sid)["buy"]["price"])
		if int(GameState.run["crystals"]) < price:
			m.hud.toast("Not enough %s." % ("cash" if gang else "crystals"), Color(1, 0.7, 0.7))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			continue
		var uid := Ranch.add(sid)
		if uid == "":
			m.hud.toast("No room for it right now.", Color(1, 0.8, 0.6))
			continue
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		Music.instance(m.get_tree()).sfx("cash", "coin")
		m.hud.toast("%s joins your ranch! Look in on it at home." % animal_name(sid), Color(1, 0.9, 0.5))
		m.xp("ranching", 5)


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
			opts.append("%s%s permit · %s%s" % ["✓ " if have else "", str(nd["name"]), Money.fmt(Builds.permit_price(id)), "" if not have else " (held)"])
			ids.append(id)
		var fund_i := opts.size()
		opts.append("%s (%s)" % [fund_name(), fund_status()])
		var file_i := -1
		if Racket.on() and Racket.heat() > 0:
			file_i = opts.size()
			opts.append("Lose a file (heat -1) · %s" % Money.fmt(file_fee()))
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "Mayor Alder", "text": "Permits. %s on you.%s" % [Money.fmt(int(r["crystals"])), "  (friends of the office pay 20% less)" if GameState.has_friend_perk("alder", 4) else ""], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i == fund_i:
			await fund(m)
			continue
		if i == file_i:
			m.hud.toast(lose_file(), Color(1, 0.9, 0.5))
			continue
		if i < 0 or i >= ids.size():
			return
		var msg := Builds.buy_permit(str(ids[i]))
		m.hud.toast(msg, Color(1, 0.9, 0.4) if msg.begins_with("Permit stamped") else Color(1, 0.7, 0.7))
		if msg.begins_with("Permit stamped"):
			Music.instance(m.get_tree()).sfx("coin", "pickup")


# ---- shared stall (C8 P6, c8_07) ----------------------------------------------
## One loop for every hand-priced stall (region stalls, colony shops, camps):
## items = [[id, listed], ...]; the price goes through GameState.shop_price (and
## `discount`, e.g. a colony perk, applied to the listed price); stackables offer
## 1/5/10; cash/nope sounds and bartering XP like the town shops. Callers keep
## their own lists: region._shop -> Shops.stall(self, who, greet, items).
static func stall_price(id: String, listed: int, discount := 0.0) -> int:
	return GameState.shop_price(id, int(listed * (1.0 - discount)))


static func stall(m: GameMap, who: String, greet: String, items: Array, discount := 0.0, stall_id := "") -> void:
	var hello := greet
	# Decor shelf key for this stall: "stall:<scene>" (or the caller's id) in decor.json "shops".
	var dkey := ("stall:" + stall_id) if stall_id != "" else ("stall:" + m.scene_id())
	while true:
		var opts: Array = []
		for it: Array in items:
			var iid := str(it[0])
			opts.append("%s  %s%s%s" % [GameState.item_name(iid), Money.fmt(stall_price(iid, int(it[1]), discount)), food_note(iid), "  (owned)" if GameState.has_tool(iid) else ""])
		var decor_i := -1
		if not DecorSources.today(dkey).is_empty():
			decor_i = opts.size()
			opts.append("Home goods (decor shelf)")
		opts.append("Leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": who, "text": "%s  (you have %s)" % [hello, Money.fmt(int(GameState.run["crystals"]))], "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if decor_i >= 0 and i == decor_i:
			await DecorSources.shelf(m, dkey, who)
			continue
		if i < 0 or i >= items.size():
			return
		var id := str(items[i][0])
		var unit := stall_price(id, int(items[i][1]), discount)
		var ty := str(GameState.items.get(id, {}).get("type", ""))
		if ty == "tool" and GameState.has_tool(id):
			m.hud.toast("You already have one.")
			continue
		if Decor.is_decor(id):
			# A decor piece listed by hand on a stall: decor box, unique guard, no x5/x10.
			if DecorSources.taken(id):
				m.hud.toast("You already have the %s." % DecorSources.name_of(id))
				continue
			if int(GameState.run["crystals"]) < unit:
				m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
				Music.instance(m.get_tree()).sfx("nope", "thud")
				continue
			GameState.run["crystals"] = int(GameState.run["crystals"]) - unit
			Music.instance(m.get_tree()).sfx("cash", "coin")
			DecorSources.grant(m, id, 1, "stall")
			m.xp("bartering", 1)
			hello = "Anything else?"
			continue
		var qty := 1
		if not ty in ["tool", "equip", "key", "vehicle", "upgrade"]:
			var dq := Dialogue.instance(m.get_tree())
			dq.say([{"who": who, "text": "%s, %s each. How many?" % [GameState.item_name(id), Money.fmt(unit)], "choice": ["1", "5", "10", "Back"], "key": ""}])
			await dq.finished
			if dq.last_choice < 0 or dq.last_choice > 2:
				continue
			qty = [1, 5, 10][dq.last_choice]
		var cost := unit * qty
		if int(GameState.run["crystals"]) < cost:
			m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
			Music.instance(m.get_tree()).sfx("nope", "thud")
			continue
		GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
		Music.instance(m.get_tree()).sfx("cash", "coin")
		if ty == "tool":
			GameState.add_tool(id)
			m.hud.toast("Got the %s." % GameState.item_name(id), Color(1, 0.9, 0.4))
		else:
			m.give(id, qty)
		m.xp("bartering", 1)
		hello = "Anything else?"


# ---- the gangster arc's own sink (C8 P6, c8_14_11) ------------------------------
## Alder "loses" a file for a fee: heat -1, once a day, dearer as you rise.
const FILE_FEE := 300  # x (progress tier + current heat)


static func file_fee() -> int:
	return FILE_FEE * (GameState.progress_tier() + Racket.heat())


## Pays and cools one heat step; returns the toast text.
static func lose_file() -> String:
	if int(GameState.run["flags"].get("file_day", 0)) == int(GameState.run["day"]):
		return "Alder: \"One file a day. People notice an empty cabinet.\""
	var fee := file_fee()
	if int(GameState.run["crystals"]) < fee:
		return "Not enough cash."
	GameState.run["crystals"] = int(GameState.run["crystals"]) - fee
	GameState.run["flags"]["file_day"] = int(GameState.run["day"])
	Racket.set_heat(Racket.heat() - 1)
	return "A folder goes missing. Heat %d/5." % Racket.heat()


# ---- the Valley Fund (C8 P6, c8_14): a long, repeatable money sink ------------
## Year-2/3 goal at the town hall: chip in any amount; each mark the town reaches
## brings a project, a letter from Alder and +FUND_FRIEND with every villager.
## [id, penguin name, gangster name, running total needed].
const FUND := [
	["lamps", "new plaza lamps", "new street lamps", 5000],
	["bridge", "the river bridge repaired", "the river bridge fixed up", 15000],
	["bandstand", "a festival bandstand", "a block-party stage", 40000],
	["library", "a new library wing", "a new library wing", 90000],
	["fireworks", "founders' fireworks every year", "fireworks over the block every year", 200000],
]
const FUND_FRIEND := 10
const FUND_STEPS := [500, 5000]


static func fund_name() -> String:
	return "Valley Fund" if GameState.is_penguins() else "Neighbourhood Fund"


static func fund_paid() -> int:
	return int(GameState.run.get("fund_paid", 0))


## The next mark the fund is saving for (-1 = all done).
static func fund_next() -> int:
	for i in FUND.size():
		if fund_paid() < int(FUND[i][3]):
			return i
	return -1


static func fund_status() -> String:
	var n := fund_next()
	if n < 0:
		return "complete"
	return "%s / %s" % [Money.fmt(fund_paid()), Money.fmt(int(FUND[n][3]))]


static func _fund_what(i: int) -> String:
	return str(FUND[i][1] if GameState.is_penguins() else FUND[i][2])


## Adds n to the fund and returns the projects that just completed (tests use it).
static func fund_add(n: int) -> Array:
	var before := fund_next()
	GameState.run["fund_paid"] = fund_paid() + n
	var done: Array = []
	for i in FUND.size():
		if (before < 0 or i >= before) and fund_paid() >= int(FUND[i][3]) and not GameState.run["flags"].has("fund_" + str(FUND[i][0])):
			GameState.run["flags"]["fund_" + str(FUND[i][0])] = true
			done.append(i)
			for npc in GameState.npcs:
				GameState.add_friend(str(npc), FUND_FRIEND)
			Mail.send("Mayor Alder", "The %s paid for %s. People keep asking who chipped in the most. I tell them. Thank you." % [fund_name(), _fund_what(i)], "chat")
	return done


static func fund(m: GameMap) -> void:
	var n := fund_next()
	if n < 0:
		await m.say([{"who": "Mayor Alder", "text": "The %s is done. Every project paid for. The town won't forget it." % fund_name()}])
		return
	var have := int(GameState.run["crystals"])
	var opts: Array = []
	var amts: Array = []
	for a: int in FUND_STEPS:
		if have >= a:
			opts.append("Give %s" % Money.fmt(a))
			amts.append(a)
	var left := int(FUND[n][3]) - fund_paid()
	if have > 0:
		opts.append("Give %s" % Money.fmt(mini(have, left)))
		amts.append(mini(have, left))
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Mayor Alder", "text": "The %s: %s raised. Next up, %s at %s. Every bit helps." % [fund_name(), Money.fmt(fund_paid()), _fund_what(n), Money.fmt(int(FUND[n][3]))], "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= amts.size():
		return
	var give := int(amts[d.last_choice])
	GameState.run["crystals"] = int(GameState.run["crystals"]) - give
	Music.instance(m.get_tree()).sfx("cash", "coin")
	var done := fund_add(give)
	if done.is_empty():
		m.hud.toast("%s raised for the %s." % [Money.fmt(fund_paid()), fund_name()], Color(1, 0.9, 0.5))
	else:
		Music.instance(m.get_tree()).sfx("quest_done", "levelup")
		await m.say([{"who": "Mayor Alder", "text": "That does it: %s. I'll have the crew start in the morning. Everyone in town will hear who made it happen." % _fund_what(int(done[-1]))}])

