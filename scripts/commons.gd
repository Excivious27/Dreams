class_name Commons
extends RefCounted
## The community farm west of town (scenes/community_farm.tscn): Hazel's
## Dreamhollow Commons (penguins) / the Westside Lot Garden (gangsters).
## Data: data/community_farm.json from tools/gen_community_farm.py.
##
## Eight development stages (clear the land, shed, raised beds, seeds, well,
## orchard, greenhouse, harvest market); each finished stage changes the map,
## brings more volunteers and pays out (friendship, items, recipes).
## Volunteers come by on a schedule (`slot`, hooked into Npc.place_now): they
## tend, haul, harvest and chat there instead of being in town.
## Community plots grow overnight (`overnight`, from GameState.sleep): ripe
## crops go to the market stand's stock, a third to the player's share crate.
##   run["cfarm"] = {stage, given {item: n}, cleared {key: true}, plots {"x,y": {crop, days, w}},
##                   stock {item: n}, share {item: n}, harvests, goodwill, gw_got, gw_day [day, n], drank}

static var _d: Dictionary = {}

const SCENE := "community_farm"
const QUEST := "cf_main"
const GOODWILL := [[300, {"harvest_basket": 1}], [800, {"seed_packet": 6}], [1500, {"growth_elixir": 1}], [3000, {"harvest_basket": 3, "fertilizer": 10}]]


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/community_farm.json")
	return _d


static func arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


## A per-arc text (or anything else) from the data.
static func tx(v: Variant) -> Variant:
	if v is Dictionary and (v as Dictionary).has("penguins"):
		return (v as Dictionary).get(arc(), (v as Dictionary)["penguins"])
	return v


static func st() -> Dictionary:
	var s: Dictionary = GameState.run.get("cfarm", {})
	if s.is_empty():
		s = {"stage": 0, "given": {}, "cleared": {}, "plots": {}, "stock": {}, "share": {}, "harvests": 0, "goodwill": 0, "gw_got": 0, "gw_day": [0, 0], "drank": -1}
		GameState.run["cfarm"] = s
	for k: String in ["given", "cleared", "plots", "stock", "share"]:
		if not s.has(k):
			s[k] = {}
	return s


static func stage() -> int:
	if GameState.run.is_empty():
		return 0
	return int(st().get("stage", 0))


static func stages() -> Array:
	return data().get("stages", [])


static func complete() -> bool:
	return stage() >= stages().size()


static func known() -> bool:
	return not GameState.run.is_empty() and GameState.run["flags"].has("cf_known")


static func place_name() -> String:
	return str(tx(data().get("names", {})))


static func short_name() -> String:
	return str(tx(data().get("short", {})))


static func keeper() -> String:
	return str(data().get("keeper", "hazel"))


static func keeper_name() -> String:
	return str(GameState.npcs.get(keeper(), {}).get("name", "Hazel"))


static func stage_name(i: int) -> String:
	return str(tx(stages()[i]["name"])) if i < stages().size() else place_name()


# ---- volunteers -------------------------------------------------------------------

static func spot_open(spot: String) -> bool:
	return stage() >= int((data().get("spot_stage", {}) as Dictionary).get(spot, 0))


## Every 7th day of the season once the market stage is done (and the opening day itself).
static func market_day() -> bool:
	if GameState.run.is_empty() or not complete():
		return false
	return GameState.day_of_season() % 7 == 0 or int(GameState.run["flags"].get("cf_market_day", -1)) == int(GameState.run["day"])


static func rain_spots() -> Array:
	return data().get("rain_spots", [])


## Where villager `npc` is at the community farm at `hour`, or "" (not there).
## Npc.place_now asks this first; town then hides them (the spot isn't a town spot).
static func slot(npc: String, hour: float) -> String:
	if GameState.run.is_empty() or not known() or GameState.festival_today() != "" or not GameState.npc_present(npc):
		return ""
	var winter := GameState.season() == "winter"
	var rows: Array = []
	if market_day():
		rows = data().get("market_day", [])
		for e: Array in rows:
			if str(e[0]) == npc and hour >= float(e[1]) and hour < float(e[2]):
				return str(e[3])
	for e: Array in data().get("schedule", []):
		if str(e[0]) != npc or hour < float(e[1]) or hour >= float(e[2]) or stage() < int(e[4]):
			continue
		var spot := str(e[3])
		if winter and not spot in data().get("winter_spots", []):
			return ""
		if not spot_open(spot):
			spot = "cf_lot" if not winter else ""
		return spot
	return ""


static func spot_activity(place: String) -> String:
	var s: Array = (data().get("spots", {}) as Dictionary).get(place, [])
	return str(s[2]) if s.size() >= 3 else ""


static func spots() -> Dictionary:
	var out := {}
	var sp: Dictionary = data().get("spots", {})
	for k: String in sp:
		out[k] = Vector2i(int(sp[k][0]), int(sp[k][1]))
	return out


# ---- chatter ------------------------------------------------------------------------

## Extra everyday lines about the community farm for Talk.line (empty until you know of it).
static func talk_pool(npc: String) -> Array:
	if GameState.run.is_empty() or not known():
		return []
	var out: Array = []
	var s := mini(stage(), (data().get("talk_any", []) as Array).size() - 1)
	if s >= 0:
		out.append_array(tx(data()["talk_any"][s]))
	for e: Array in data().get("talk_own", []):
		if str(e[0]) == npc and stage() >= int(e[1]):
			out = (tx(e[2]) as Array).duplicate()  # their own voice wins over the general gossip
	return out


static func work_line(activity: String) -> String:
	var l: Array = tx((data().get("at_work", {}) as Dictionary).get(activity, {"penguins": ["Good to see you out here."]}))
	return str(l[randi() % l.size()])


# ---- the quest line -------------------------------------------------------------------

## How many of `key` you could put in ("#seed" = any seeds).
static func have_of(key: String) -> int:
	if key == "#seed":
		var n := 0
		for id in GameState.run["inventory"]:
			if str(GameState.items.get(id, {}).get("type", "")) == "seed" and not GameState.is_locked(str(id)):
				n += int(GameState.run["inventory"][id])
		return n
	return GameState.count_any(key)


static func need_name(key: String) -> String:
	return "any seeds" if key == "#seed" else GameState.need_name(key)


static func needs() -> Dictionary:
	return stages()[stage()].get("need", {}) if not complete() else {}


static func given() -> Dictionary:
	return st()["given"]


## Seed kinds handed in for the seeds stage (it asks for variety).
static func seed_kinds() -> int:
	return (st().get("seed_kinds", {}) as Dictionary).size()


static func stage_ready() -> bool:
	if complete():
		return false
	var sd: Dictionary = stages()[stage()]
	if str(sd.get("task", "")) == "debris":
		return int(st().get("debris_left", 1)) <= 0
	for k: String in sd.get("need", {}):
		if int(given().get(k, 0)) < int(sd["need"][k]):
			return false
	if sd.has("kinds") and seed_kinds() < int(sd["kinds"]):
		return false
	return true


## Put what you carry toward the current stage. Returns how many items went in.
static func contribute() -> int:
	if complete():
		return 0
	var sd: Dictionary = stages()[stage()]
	var n := 0
	for k: String in sd.get("need", {}):
		var left := int(sd["need"][k]) - int(given().get(k, 0))
		if left <= 0:
			continue
		var put := mini(left, have_of(k))
		if put <= 0:
			continue
		if k == "#seed":
			var rest := put
			var ids: Array = GameState.run["inventory"].keys().filter(func(x: Variant) -> bool: return str(GameState.items.get(x, {}).get("type", "")) == "seed" and not GameState.is_locked(str(x)))
			# Spread the gift over kinds (the stage wants variety), cheapest first.
			ids.sort_custom(func(a: Variant, b: Variant) -> bool: return GameState.item_value(str(a)) < GameState.item_value(str(b)))
			var kinds: Dictionary = st().get("seed_kinds", {})
			while rest > 0 and not ids.is_empty():
				for id in ids.duplicate():
					if rest <= 0:
						break
					if GameState.count(str(id)) <= 0:
						ids.erase(id)
						continue
					GameState.add_item(str(id), -1)
					kinds[str(id)] = int(kinds.get(str(id), 0)) + 1
					rest -= 1
			st()["seed_kinds"] = kinds
			put -= rest
		else:
			GameState.take_any(k, put)
		given()[k] = int(given().get(k, 0)) + put
		n += put
	return n


## One line per need: "12/30 Wood".
static func need_lines() -> Array:
	var out: Array = []
	if complete():
		return out
	var sd: Dictionary = stages()[stage()]
	if str(sd.get("task", "")) == "debris":
		out.append("%d piece%s of %s left to clear" % [int(st().get("debris_left", 0)), "" if int(st().get("debris_left", 0)) == 1 else "s", "junk" if arc() == "gangsters" else "overgrowth"])
	for k: String in sd.get("need", {}):
		out.append("%s %d/%d %s (you carry %d)" % ["✓" if int(given().get(k, 0)) >= int(sd["need"][k]) else "•", mini(int(given().get(k, 0)), int(sd["need"][k])), int(sd["need"][k]), need_name(k), have_of(k)])
	if sd.has("kinds"):
		out.append("%s %d/%d kinds of seed" % ["✓" if seed_kinds() >= int(sd["kinds"]) else "•", mini(seed_kinds(), int(sd["kinds"])), int(sd["kinds"])])
	return out


static func quest_text() -> String:
	if complete():
		return "%s is thriving. Market every 7th day." % place_name()
	if not GameState.run["flags"].has("cf_met"):
		return "Meet %s at %s, out the west road from the town plaza." % [keeper_name(), short_name()]
	return "%s (%d/%d): %s. Check the board by the gate." % [place_name(), stage() + 1, stages().size(), stage_name(stage())]


## Keep the journal entry in step with the current stage.
static func sync_quest() -> void:
	if GameState.run.is_empty() or not known():
		return
	if not GameState.has_quest(QUEST):
		GameState.add_quest(QUEST, quest_text())
	for q: Dictionary in GameState.run["quests"]:
		if str(q["id"]) == QUEST and not bool(q["done"]):
			q["text"] = quest_text()
	if complete() and not GameState.quest_done(QUEST):
		GameState.complete_quest(QUEST)


## Finish the current stage: rewards, friendship, the recipe, then the map shows the change
## (the map reloads; `flags.cf_reveal` makes it play the reveal).
static func finish_stage(m: GameMap) -> void:
	if complete():
		return
	var s := stage()
	var sd: Dictionary = stages()[s]
	st()["stage"] = s + 1
	st()["given"] = {}
	GameState.run["flags"]["cf_stage_" + str(sd["id"])] = true
	var got: Array = []
	if int(sd.get("crystals", 0)) > 0:
		GameState.run["crystals"] = int(GameState.run["crystals"]) + int(sd["crystals"])
		got.append("◆%d" % int(sd["crystals"]))
	for it: String in sd.get("give", {}):
		GameState.add_item(it, int(sd["give"][it]), true)
		got.append("%s ×%d" % [GameState.item_name(it), int(sd["give"][it])])
	if sd.has("recipe"):
		GameState.run["flags"][str(sd["recipe"])] = true
		for rc: Dictionary in GameState.load_json("res://data/recipes.json").get("kitchen", []):
			if str(rc.get("flag", "")) == str(sd["recipe"]):
				got.append("recipe: %s (kitchen)" % str(rc["name"]))
	for who: String in sd.get("friend", {}):
		if GameState.npcs.has(who):
			GameState.add_friend(who, int(sd["friend"][who]))
	if str(sd["id"]) == "orchard":
		GameState.run["flags"]["cf_orchard_day"] = int(GameState.run["day"])  # saplings for a week, then trees
	if complete():
		GameState.run["flags"]["cf_market_day"] = int(GameState.run["day"])  # opening day: everyone comes
	GameState.add_xp("farming", 30 + 15 * s)
	GameState.run["flags"]["cf_reveal"] = s
	GameState.run["flags"]["cf_reveal_got"] = ", ".join(got)
	sync_quest()
	if m == null or not is_instance_valid(m):
		GameState.save()
		return
	m.fx("levelup", m.player.position + Vector2(0, -12), 10.0, 0.9)
	Music.instance(m.get_tree()).sfx("quest_done", "levelup")
	m.shake(1.5)
	if m.scene_id() == SCENE:
		m.go_to(SCENE, m.player.position - m.offset(), m.player.facing)
	else:
		GameState.save()


# ---- the board ---------------------------------------------------------------------------

static func open_board(m: GameMap) -> void:
	if not GameState.run["flags"].has("cf_board_seen"):
		GameState.run["flags"]["cf_board_seen"] = true
		GameState.run["flags"]["cf_known"] = true
		await m.say([{"who": keeper_name(), "text": str(tx(data()["intro"]))}])
		sync_quest()
	while true:
		var opts: Array = []
		var acts: Array = []
		var text := ""
		if complete():
			text = "%s · all %d stages done.\nMarket every 7th day of the season%s." % [place_name(), stages().size(), " (today!)" if market_day() else ""]
		else:
			var sd: Dictionary = stages()[stage()]
			text = "%s · stage %d of %d: %s\n%s\n%s" % [place_name(), stage() + 1, stages().size(), stage_name(stage()), str(tx(sd["desc"])), "\n".join(need_lines())]
			if not sd.get("need", {}).is_empty():
				opts.append("Give what I carry")
				acts.append("give")
		opts.append("All stages")
		acts.append("list")
		opts.append("Leave")
		acts.append("leave")
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "Board", "text": text, "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= acts.size() or str(acts[i]) == "leave":
			return
		match str(acts[i]):
			"give":
				if Net.visiting():
					m.hud.toast("This is your host's valley: their farm, their board.", Color(1, 0.85, 0.7))
					continue
				var put := contribute()
				if put > 0:
					m.hud.toast("Added %d item%s." % [put, "" if put == 1 else "s"], Color(0.8, 1, 0.8))
					Music.instance(m.get_tree()).sfx("pickup")
					GameState.add_friend(keeper(), mini(10, put / 3 + 1))
				else:
					m.hud.toast("You carry nothing this stage still needs.", Color(1, 0.85, 0.7))
				if stage_ready():
					await m.say([{"who": keeper_name(), "text": str(tx(stages()[stage()]["done"]))}])
					finish_stage(m)
					return
				sync_quest()
			"list":
				var lines: Array = []
				for k in stages().size():
					lines.append("%s %d. %s" % ["✓" if k < stage() else ("▶" if k == stage() else "·"), k + 1, stage_name(k)])
				await m.say([{"who": place_name(), "text": "\n".join(lines)}])


# ---- the market stand, share crate, compost, well ---------------------------------------

static func is_produce(id: String) -> bool:
	return GameState.family(id) in ["veg", "fruit", "berry", "tree", "grain", "flower", "herb"] and str(GameState.items.get(id, {}).get("type", "")) != "seed"


static func stand_price(id: String) -> int:
	return maxi(1, int(GameState.item_value(id) * 0.8))


static func _bag_produce() -> Array:
	var ids: Array = []
	for id in GameState.run["inventory"]:
		if is_produce(str(id)) and int(GameState.run["inventory"][id]) > 0 and not GameState.is_locked(str(id)):
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return GameState.count(a) > GameState.count(b))
	return ids.slice(0, 7)


static func open_stand(m: GameMap) -> void:
	var stock: Dictionary = st()["stock"]
	while true:
		var opts: Array = []
		var acts: Array = []
		var kinds := 0
		for k in stock:
			if int(stock[k]) > 0:
				kinds += 1
		if kinds > 0:
			opts.append("Buy produce (%d kind%s)" % [kinds, "" if kinds == 1 else "s"])
			acts.append("buy")
		opts.append("Donate produce")
		acts.append("donate")
		if market_day():
			opts.append("Sell at the market (+25%)")
			acts.append("sell")
		opts.append("Leave")
		acts.append("leave")
		var head := "%s stand. %s  (you have ◆%d)" % [place_name(), "Market day! The whole town's here." if market_day() else ("Fresh from the beds." if kinds > 0 else "Nothing ripe yet: donations welcome."), int(GameState.run["crystals"])]
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "Stand", "text": head, "choice": opts, "key": ""}])
		await d.finished
		var i := d.last_choice
		if i < 0 or i >= acts.size() or str(acts[i]) == "leave":
			return
		match str(acts[i]):
			"buy":
				await _buy(m, stock)
			"donate":
				await _donate(m)
			"sell":
				await _sell(m)


static func _buy(m: GameMap, stock: Dictionary) -> void:
	var ids: Array = stock.keys().filter(func(k: Variant) -> bool: return int(stock[k]) > 0)
	ids.sort()
	ids = ids.slice(0, 8)
	var opts: Array = []
	for id in ids:
		opts.append("%s ×%d  ◆%d" % [GameState.item_name(str(id)), int(stock[id]), stand_price(str(id))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Everything here grew in the community beds.", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var id := str(ids[d.last_choice])
	var dq := Dialogue.instance(m.get_tree())
	dq.say([{"who": "Stand", "text": "%s, ◆%d each. How many?" % [GameState.item_name(id), stand_price(id)], "choice": ["1", "5", "All %d" % int(stock[id]), "Back"], "key": ""}])
	await dq.finished
	if dq.last_choice < 0 or dq.last_choice > 2:
		return
	var qty := mini(int(stock[id]), [1, 5, int(stock[id])][dq.last_choice])
	var cost := stand_price(id) * qty
	if int(GameState.run["crystals"]) < cost:
		m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	stock[id] = int(stock[id]) - qty
	if int(stock[id]) <= 0:
		stock.erase(id)
	Music.instance(m.get_tree()).sfx("cash", "coin")
	m.give(id, qty)


static func _donate(m: GameMap) -> void:
	if Net.visiting():
		m.hud.toast("This is your host's valley: give to your own commons.", Color(1, 0.85, 0.7))
		return
	var ids := _bag_produce()
	if ids.is_empty():
		m.hud.toast("You carry no produce to give.", Color(1, 0.85, 0.7))
		return
	var opts: Array = []
	for id in ids:
		opts.append("%s ×%d" % [GameState.item_name(str(id)), GameState.count(str(id))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Donations go on the stand for anyone who needs them. (All of the kind you pick.)", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var id := str(ids[d.last_choice])
	var n := GameState.count(id)
	donate(id, n)
	Music.instance(m.get_tree()).sfx("pickup")
	m.hud.toast("Donated %d %s. Goodwill %d." % [n, GameState.item_name(id), int(st().get("goodwill", 0))], Color(0.85, 1, 0.85))
	await _goodwill_rewards(m)


## Hand produce to the stand: stock, goodwill, a little friendship (capped per day).
static func donate(id: String, n: int) -> void:
	if n <= 0:
		return
	GameState.add_item(id, -n)
	var stock: Dictionary = st()["stock"]
	stock[id] = int(stock.get(id, 0)) + n
	st()["goodwill"] = int(st().get("goodwill", 0)) + GameState.item_value(id) * n
	var gd: Array = st().get("gw_day", [0, 0])
	var today := int(GameState.run["day"])
	if int(gd[0]) != today:
		gd = [today, 0]
	var f := mini(20 - int(gd[1]), n * 2)
	if f > 0:
		GameState.add_friend(keeper(), f)
		gd[1] = int(gd[1]) + f
	st()["gw_day"] = gd


static func _goodwill_rewards(m: GameMap) -> void:
	while int(st().get("gw_got", 0)) < GOODWILL.size() and int(st().get("goodwill", 0)) >= int(GOODWILL[int(st()["gw_got"])][0]):
		var rw: Dictionary = GOODWILL[int(st()["gw_got"])][1]
		st()["gw_got"] = int(st()["gw_got"]) + 1
		var bits: Array = []
		for it: String in rw:
			GameState.add_item(it, int(rw[it]), true)
			bits.append("%s ×%d" % [GameState.item_name(it), int(rw[it])])
		await m.say([{"who": keeper_name(), "text": "Folks keep asking who's been filling the stand. I tell them. Here, from all of us: %s." % ", ".join(bits)}])


static func _sell(m: GameMap) -> void:
	var ids := _bag_produce()
	if ids.is_empty():
		m.hud.toast("You carry no produce to sell.", Color(1, 0.85, 0.7))
		return
	var opts: Array = []
	for id in ids:
		opts.append("%s ×%d  ◆%d" % [GameState.item_name(str(id)), GameState.count(str(id)), market_pay(str(id), GameState.count(str(id)))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Market-day prices: a quarter over the shipping box. (All of the kind you pick.)", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var id := str(ids[d.last_choice])
	var n := GameState.count(id)
	var pay := market_pay(id, n)
	GameState.add_item(id, -n)
	GameState.run["crystals"] = int(GameState.run["crystals"]) + pay
	GameState.run["earned_total"] = int(GameState.run.get("earned_total", 0)) + pay
	Music.instance(m.get_tree()).sfx("cash", "coin")
	m.xp("bartering", mini(20, pay / 15 + 1))
	m.hud.toast("Sold %d %s for ◆%d." % [n, GameState.item_name(id), pay], Color(1, 0.9, 0.5))


static func market_pay(id: String, n: int) -> int:
	return int(GameState.sell_price(id, n) * 1.25)


static func collect_share(m: GameMap) -> void:
	var sh: Dictionary = st()["share"]
	if sh.is_empty():
		m.hud.toast("Your share crate is empty. Volunteers fill it as the beds come in.", Color(0.95, 0.9, 0.8))
		return
	var bits: Array = []
	for id: String in sh.keys():
		GameState.add_item(id, int(sh[id]), true)
		bits.append("%s ×%d" % [GameState.item_name(id), int(sh[id])])
	sh.clear()
	Music.instance(m.get_tree()).sfx("chest_open", "pickup")
	m.say.call_deferred([{"text": "Your share: %s." % ", ".join(bits)}])


static func compost(m: GameMap) -> void:
	var opts: Array = []
	var acts: Array = []
	if GameState.count("fiber") >= 5:
		opts.append("Add 5 fibre (→ 1 fertilizer)")
		acts.append("fiber")
	if GameState.count_any("#veg") >= 3:
		opts.append("Add 3 vegetable scraps (→ 1 fertilizer)")
		acts.append("veg")
	opts.append("Leave it")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Compost", "text": "Warm and busy with worms. It turns scraps into fertilizer, and drops a little in your share crate every few days by itself.", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= acts.size():
		return
	if str(acts[d.last_choice]) == "fiber":
		GameState.add_item("fiber", -5)
	else:
		GameState.take_any("#veg", 3)
	Music.instance(m.get_tree()).sfx("dig", "pickup")
	m.give("fertilizer", 1)
	m.xp("farming", 2)


static func drink(m: GameMap) -> void:
	if int(st().get("drank", -1)) == int(GameState.run["day"]):
		m.hud.toast("Cold and clear. You've had your fill today.", Color(0.85, 0.95, 1))
		return
	st()["drank"] = int(GameState.run["day"])
	GameState.run["energy"] = mini(int(GameState.run["max_energy"]), int(GameState.run["energy"]) + 15)
	Music.instance(m.get_tree()).sfx("drink", "pickup")
	m.hud.toast("You drink from the well. +15 energy.", Color(0.8, 0.95, 1))


# ---- plots ------------------------------------------------------------------------------

## Every bed cell ("x,y") and whether it's a cold frame (grows in winter once the greenhouse stands).
static func plot_cells() -> Dictionary:
	var out := {}
	if stage() < 3:
		return out
	for b: Array in data().get("beds", []):
		for y in range(int(b[1]), int(b[1]) + int(b[3])):
			for x in range(int(b[0]), int(b[0]) + int(b[2])):
				out["%d,%d" % [x, y]] = false
	if stage() >= 7:
		for b: Array in data().get("frames", []):
			for y in range(int(b[1]), int(b[1]) + int(b[3])):
				for x in range(int(b[0]), int(b[0]) + int(b[2])):
					out["%d,%d" % [x, y]] = true
	return out


static func plot(key: String) -> Dictionary:
	return (st()["plots"] as Dictionary).get(key, {})


static func ripe(p: Dictionary) -> bool:
	var cd: Dictionary = GameState.crops.get(str(p.get("crop", "")), {})
	return not cd.is_empty() and float(p.get("days", 0)) >= float(cd.get("days", 1))


## What the volunteers plant in a bed cell this season ("" = nothing: winter beds rest).
static func pick_crop(key: String, se: String, glass: bool) -> String:
	if se == "winter" and not glass:
		return ""
	var lst: Array = (data().get("plant", {}) as Dictionary).get(se, [])
	lst = lst.filter(func(c: Variant) -> bool: return GameState.crops.has(str(c)))
	if lst.is_empty():
		return ""
	var p := key.split(",")
	# Whole runs of one crop per bed row (rows read as rows), changing every season.
	var i := absi(int(p[1]) * 7 + int(p[0]) / 4 + int(GameState.run["day"]) / 28)
	return str(lst[i % lst.size()])


## Harvest one ripe plot: 1-2 of the crop; every third harvest goes to your share, the rest to the stand.
static func harvest(key: String) -> String:
	var p := plot(key)
	var cd: Dictionary = GameState.crops.get(str(p.get("crop", "")), {})
	if cd.is_empty():
		return ""
	var yid := str(cd.get("yield", p["crop"]))
	var n := 1 + (1 if (hash(key) + int(GameState.run["day"])) % 3 == 0 else 0)
	st()["harvests"] = int(st().get("harvests", 0)) + 1
	var to: Dictionary = st()["share"] if int(st()["harvests"]) % 3 == 0 else st()["stock"]
	to[yid] = mini(99, int(to.get(yid, 0)) + n)
	if cd.has("regrow"):
		p["days"] = maxf(0.0, float(cd["days"]) - float(cd["regrow"]))
	else:
		p["crop"] = ""
		p["days"] = 0.0
	return yid


## Overnight (GameState.sleep): Hazel's letter, the beds grow and get harvested and replanted,
## villagers take produce from the stand, the compost drops fertilizer.
static func overnight(report: Dictionary) -> void:
	if GameState.run.is_empty():
		return
	var flags: Dictionary = GameState.run["flags"]
	if not flags.has("cf_letter") and int(GameState.run["day"]) >= 3:
		flags["cf_letter"] = true
		flags["cf_known"] = true
		Mail.send(keeper_name(), str(tx(data()["letter"])), "chat", {"npc": keeper()})
		sync_quest()
	if stage() < 4:
		return
	var se := GameState.season_of(int(GameState.run["day"]) + 1)
	var wet := GameState.sky_waters() or stage() >= 5  # the well: Benno waters every evening
	var plots: Dictionary = st()["plots"]
	var cells := plot_cells()
	var picked := 0
	for key: String in cells:
		var glass: bool = cells[key]
		var p: Dictionary = plots.get(key, {})
		if p.is_empty():
			p = {"crop": "", "days": 0.0, "w": false}
			plots[key] = p
		var crop := str(p.get("crop", ""))
		if crop != "":
			var cd: Dictionary = GameState.crops.get(crop, {})
			if cd.is_empty() or (not glass and not GameState.crop_fits_season(cd, se)):
				p["crop"] = ""
				p["days"] = 0.0
			else:
				if ripe(p):
					harvest(key)  # nobody picked it today: the volunteers did, at dusk
					picked += 1
				else:
					p["days"] = float(p["days"]) + (1.0 if wet or bool(p.get("w", false)) else 0.5)
		if str(p.get("crop", "")) == "":
			var c := pick_crop(key, se, glass)
			if c != "":
				p["crop"] = c
				p["days"] = 0.0
		p["w"] = false
	# Neighbours take produce off the stand (more on market day).
	var stock: Dictionary = st()["stock"]
	var take := 8 if market_day() else 4
	for id: String in stock.keys():
		if take <= 0:
			break
		var t := mini(take, maxi(1, int(stock[id]) / 4))
		stock[id] = int(stock[id]) - t
		take -= t
		if int(stock[id]) <= 0:
			stock.erase(id)
	if stage() >= 2 and int(GameState.run["day"]) % 3 == 0:
		var sh: Dictionary = st()["share"]
		sh["fertilizer"] = mini(20, int(sh.get("fertilizer", 0)) + 1)
	if picked > 0 or not (st()["share"] as Dictionary).is_empty():
		report["cfarm"] = ["%s: %d bed%s harvested; something's waiting in your share crate." % [place_name(), picked, "" if picked == 1 else "s"]] if not (st()["share"] as Dictionary).is_empty() else ["%s: the volunteers harvested %d bed%s." % [place_name(), picked, "" if picked == 1 else "s"]]
