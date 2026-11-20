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
##                   stock {item: n}, share {item: n}, harvests, goodwill, gw_got, gw_day [day, n], drank,
##                   pending (stage index the crew builds tonight, -1 none), asks {"year:season": true}}
## Building stages (data "build") finish overnight: the board takes the bundle, the crew
## raises it while you sleep, and the next visit plays the reveal. Once the market is
## open, the board carries one seasonal ask (`ask`).

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
		s = {"stage": 0, "given": {}, "cleared": {}, "plots": {}, "stock": {}, "pantry": {}, "share": {}, "harvests": 0, "goodwill": 0, "gw_got": 0, "gw_day": [0, 0], "drank": -1, "pending": -1, "asks": {}}
		GameState.run["cfarm"] = s
	for k: String in ["given", "cleared", "plots", "stock", "pantry", "share", "asks"]:
		if not s.has(k):
			s[k] = {}
	if not s.has("pending"):
		s["pending"] = -1  # saves from before overnight builds
	return s


## The stage the crew is building tonight (-1: none).
static func pending() -> int:
	if GameState.run.is_empty():
		return -1
	return int(st().get("pending", -1))


## Nights the stage being built takes (gen_community_farm BUILD_DAYS; 1 for old data).
static func build_days(i: int) -> int:
	if i < 0 or i >= stages().size():
		return 1
	return maxi(1, int(stages()[i].get("days", 1)))


## Nights of work already done on the pending build (0 = starts tonight).
static func build_done() -> int:
	return int(st().get("build_done", 0)) if pending() >= 0 else 0


## "tonight" / "2 more nights" for the pending build.
static func build_left_words() -> String:
	var left := build_days(pending()) - build_done()
	return "tonight" if left <= 1 else "%d more nights" % left


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
	# The 14th is the season festival: everyone is in town, so no market that day.
	return (GameState.day_of_season() % 7 == 0 and GameState.day_of_season() != GameState.FESTIVAL_DAY) or int(GameState.run["flags"].get("cf_market_day", -1)) == int(GameState.run["day"])


static func rain_spots() -> Array:
	return data().get("rain_spots", [])


## Where villager `npc` is at the community farm at `hour`, or "" (not there).
## Npc.place_now asks this first; town then hides them (the spot isn't a town spot).
## In the wet, grown-ups shelter at an open rain spot (shed eaves, greenhouse) and
## the kids stay home; Npc.rain_walker villagers keep to their spot.
static func slot(npc: String, hour: float) -> String:
	if GameState.run.is_empty() or not known() or GameState.festival_today() != "" or not GameState.npc_present(npc):
		return ""
	var spot := _slot_dry(npc, hour)
	if spot == "" or spot in rain_spots() or not (GameState.is_wet() or GameState.weather_today() == "blizzard"):
		return spot
	if Npc.rain_walker(npc):
		return spot
	if npc in data().get("kids", []):
		return ""
	return shelter(npc)


## The open rain spot a volunteer waits out the weather at ("" = none built yet: home).
static func shelter(npc: String) -> String:
	var open: Array = rain_spots().filter(func(sp: Variant) -> bool: return spot_open(str(sp)))
	if open.is_empty():
		return ""
	return str(open[absi(hash(npc)) % open.size()])


static func _slot_dry(npc: String, hour: float) -> String:
	var winter := GameState.season() == "winter"
	if market_day():
		for e: Array in data().get("market_day", []):
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


## True when `npc` has a market-day slot right now (it beats the 7th-day chapel morning).
static func market_slot(npc: String, hour: float) -> bool:
	if not market_day():
		return false
	for e: Array in data().get("market_day", []):
		if str(e[0]) == npc and hour >= float(e[1]) and hour < float(e[2]):
			return true
	return false


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


## What a volunteer says at work: their activity's lines, the weather/season/market day's,
## and a line of their own.
static func work_line(activity: String, npc := "") -> String:
	var aw: Dictionary = data().get("at_work", {})
	var l: Array = (tx(aw.get(activity, {"penguins": ["Good to see you out here."]})) as Array).duplicate()
	if GameState.run.is_empty():
		return str(l[randi() % l.size()])
	var extra := ""
	if GameState.is_wet() or GameState.weather_today() == "blizzard":
		extra = "rain"
	elif GameState.season() == "winter":
		extra = "winter"
	elif market_day():
		extra = "market_day"
	if extra != "" and aw.has(extra):
		var ex: Array = tx(aw[extra])
		if extra == "rain":
			return str(ex[randi() % ex.size()])  # nobody talks about weeds in a downpour
		else:
			l.append_array(ex)
	var own: Dictionary = data().get("at_work_own", {})
	if own.has(npc):
		l.append_array(tx(own[npc]))
	return str(l[randi() % l.size()])


## A short call-out as you pass (floating text over the volunteer).
static func bark(activity: String, first_today: bool) -> String:
	var b: Dictionary = data().get("barks", {})
	var key := activity
	if first_today:
		key = "greet"
	elif GameState.is_wet() and b.has("rain"):
		key = "rain"
	if not b.has(key):
		return ""
	var l: Array = tx(b[key])
	return str(l[randi() % l.size()]) if not l.is_empty() else ""


# ---- lending a hand --------------------------------------------------------------------

## The kind of help a volunteer doing `activity` asks for ("" = none). Farm help is
## watering when the beds are dry (before the well, no rain), weeding otherwise.
static func help_kind(activity: String) -> String:
	var k := str((data().get("help_kind", {}) as Dictionary).get(activity, ""))
	if k == "weed" and stage() >= 4 and stage() < 5 and not GameState.sky_waters():
		k = "water"
	return k


static func help_def(kind: String) -> Dictionary:
	return (data().get("help", {}) as Dictionary).get(kind, {})


## Co-op: a guest's run.cfarm is its OWN commons, not the host's on screen, so a guest
## can look but not act (C9 P6). True (and a toast) when we're visiting.
static func guest_blocked(m: GameMap, what := "board") -> bool:
	if not Net.visiting():
		return false
	if m != null and m.hud != null:
		m.hud.toast("This is your host's valley: their farm, their %s." % what, Color(1, 0.85, 0.7))
		Music.instance(m.get_tree()).sfx("nope", "thud")
	return true


static func helped_today(npc: String) -> bool:
	return GameState.run.is_empty() or int((st().get("helped", {}) as Dictionary).get(npc, -1)) == int(GameState.run["day"])


## A finished help task: friendship, a little goodwill, xp and a cut of the produce
## (stand stock first, else a seed packet). Returns what you got, for the thank-you line.
static func reward_help(npc: String) -> Array:
	if Net.visiting():  # the host's commons: friendship and xp are ours, the stand and goodwill are theirs
		if GameState.npcs.has(npc):
			GameState.add_friend(npc, 10)
		GameState.add_xp("farming", 8)
		return [["seed_packet", 1]]
	var h: Dictionary = st().get("helped", {})
	h[npc] = int(GameState.run["day"])
	st()["helped"] = h
	if GameState.npcs.has(npc):
		GameState.add_friend(npc, 10)
	if npc != keeper():
		GameState.add_friend(keeper(), 2)
	st()["goodwill"] = int(st().get("goodwill", 0)) + 40
	GameState.add_xp("farming", 8)
	var got: Array = []
	var stock: Dictionary = st()["stock"]
	var best := ""
	for id: String in stock:
		if int(stock[id]) > 0 and (best == "" or int(stock[id]) > int(stock[best])):
			best = id
	if best != "":
		var n := mini(2, int(stock[best]))
		stock[best] = int(stock[best]) - n
		if int(stock[best]) <= 0:
			stock.erase(best)
		got.append([best, n])
	else:
		got.append(["seed_packet", 1])
	return got


# ---- the quest line -------------------------------------------------------------------

## How many of `key` you could put in ("#seed" = any seeds).
static func have_of(key: String) -> int:
	if key == "#seed":
		var n := 0
		for id in GameState.run["inventory"]:
			if str(GameState.items.get(id, {}).get("type", "")) == "seed" and not GameState.is_locked(str(id)):
				n += int(GameState.run["inventory"][id])
		return n
	if key.begins_with("@"):
		var t := 0
		for id: String in _of_type(key.substr(1)):
			t += GameState.count(id)
		return t
	return GameState.count_any(key)


## Unlocked items you carry whose type is `ty` (cheapest first).
static func _of_type(ty: String) -> Array:
	var ids: Array = []
	for id in GameState.run["inventory"]:
		if str(GameState.items.get(id, {}).get("type", "")) == ty and int(GameState.run["inventory"][id]) > 0 and not GameState.is_locked(str(id)):
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return GameState.item_value(a) < GameState.item_value(b))
	return ids


## Takes n of an item, family ("#veg") or type ("@fish"), cheapest first.
static func take_of(key: String, n: int) -> void:
	if not key.begins_with("@"):
		GameState.take_any(key, n)
		return
	for id: String in _of_type(key.substr(1)):
		if n <= 0:
			break
		var t := mini(n, GameState.count(id))
		GameState.add_item(id, -t)
		n -= t


static func need_name(key: String) -> String:
	if key == "#seed":
		return "any seeds"
	if key.begins_with("@"):
		return {"fish": "Fish (any)", "forage": "Forage (any)"}.get(key.substr(1), key.substr(1).capitalize())
	return GameState.need_name(key)


static func needs() -> Dictionary:
	return stages()[stage()].get("need", {}) if not complete() else {}


static func given() -> Dictionary:
	return st()["given"]


## Seed kinds handed in for the seeds stage (it asks for variety).
static func seed_kinds() -> int:
	return (st().get("seed_kinds", {}) as Dictionary).size()


static func stage_ready() -> bool:
	if complete() or pending() >= 0:
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
	if complete() or pending() >= 0:
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
	if pending() >= 0:
		if build_done() > 0:
			return "%s: the crew is building the %s (night %d of %d done). Visit tomorrow." % [place_name(), build_word(pending()), build_done(), build_days(pending())]
		return "%s: the crew starts the %s tonight (%d night%s of work). Visit tomorrow." % [place_name(), build_word(pending()), build_days(pending()), "" if build_days(pending()) == 1 else "s"]
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
static func finish_stage(m: GameMap, save := true) -> void:
	if complete():
		return
	var s := stage()
	var sd: Dictionary = stages()[s]
	st()["stage"] = s + 1
	st()["given"] = {}
	st()["pending"] = -1
	st()["build_done"] = 0
	GameState.run["flags"]["cf_stage_" + str(sd["id"])] = true
	var got: Array = []
	if int(sd.get("crystals", 0)) > 0:
		GameState.add_money(int(sd["crystals"]), "commons")
		got.append(Money.fmt(int(sd["crystals"])))
	for it: String in sd.get("give", {}):
		GameState.add_item(it, int(sd["give"][it]), true)
		got.append("%s ×%d" % [GameState.item_name(it), int(sd["give"][it])])
	var keep := DecorSources.grant_key(m, "commons:" + str(sd["id"]))  # a keepsake for the house (decor.json grants, C10a)
	if keep != "":
		got.append(DecorSources.name_of(keep))
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
		if save:
			GameState.save()
		return
	m.fx("levelup", m.player.position + Vector2(0, -12), 10.0, 0.9)
	Music.instance(m.get_tree()).sfx("quest_done", "levelup")
	m.shake(1.5)
	if m.scene_id() == SCENE:
		m.go_to(SCENE, m.player.position - m.offset(), m.player.facing)
	else:
		GameState.save()


## What the crew is putting up for stage i, for "building the ___ tonight".
static func build_word(i: int) -> String:
	if i < 0 or i >= stages().size():
		return "next thing"
	return {"shed": "shed", "beds": "raised beds", "well": "well", "orchard": "orchard", "greenhouse": "greenhouse"}.get(str(stages()[i]["id"]), stage_name(i).to_lower())


## Build progress as a little bar: "■■□ 2/3 nights".
static func build_bar() -> String:
	var n := build_days(pending())
	var d := build_done()
	return "%s%s %d/%d nights" % ["■".repeat(d), "□".repeat(n - d), d, n]


static func is_build(i: int) -> bool:
	return i >= 0 and i < stages().size() and bool(stages()[i].get("build", false))


## The bundle is full: a building stage goes up overnight, anything else finishes now.
static func bundle_full(m: GameMap) -> void:
	var s := stage()
	var sd: Dictionary = stages()[s]
	if is_build(s):
		st()["pending"] = s
		st()["build_done"] = 0
		st()["given"] = {}
		sync_quest()
		if m != null and is_instance_valid(m):
			Music.instance(m.get_tree()).sfx("quest_done", "levelup")
			await m.say([{"who": keeper_name(), "text": str(tx(sd.get("tonight", sd["done"])))}])
			var nd := build_days(s)
			m.hud.toast(("The crew builds the %s tonight. Sleep, then come and see." % build_word(s)) if nd <= 1 else ("The crew starts the %s tonight: %d nights of work. Drop by and watch it go up." % [build_word(s), nd]), Color(1, 0.95, 0.8))
			if m.scene_id() == SCENE:
				m.go_to(SCENE, m.player.position - m.offset(), m.player.facing)  # the build site appears
				return
		GameState.save()
		return
	if m != null and is_instance_valid(m):
		await m.say([{"who": keeper_name(), "text": str(tx(sd["done"]))}])
	finish_stage(m)


# ---- seasonal asks (after the market opens) ---------------------------------------------

static func ask_key() -> String:
	return "%d:%s" % [(int(GameState.run["day"]) - 1) / (GameState.DAYS_PER_SEASON * 4), GameState.season()]


## This season's ask: {key, n}, or {} (none before the market, or already answered).
static func ask() -> Dictionary:
	if GameState.run.is_empty() or not complete() or (st()["asks"] as Dictionary).has(ask_key()):
		return {}
	var rows: Array = (data().get("asks", {}) as Dictionary).get(GameState.season(), [])
	if rows.is_empty():
		return {}
	var yr := (int(GameState.run["day"]) - 1) / (GameState.DAYS_PER_SEASON * 4)
	var r: Array = rows[yr % rows.size()]
	return {"key": str(r[0]), "n": int(r[1])}


static func ask_need() -> String:
	var a := ask()
	if a.is_empty():
		return ""
	var k := str(a["key"])
	return "%d %s" % [int(a["n"]), need_name(k) if k.begins_with("#") or k.begins_with("@") else GameState.item_name(k)]


## Hand in this season's ask (all at once). Returns the reward text, or "" if you can't yet.
static func give_ask() -> String:
	var a := ask()
	if a.is_empty() or have_of(str(a["key"])) < int(a["n"]):
		return ""
	take_of(str(a["key"]), int(a["n"]))
	(st()["asks"] as Dictionary)[ask_key()] = true
	var rw: Dictionary = data().get("ask_reward", {})
	var got: Array = []
	if int(rw.get("crystals", 0)) > 0:
		GameState.add_money(int(rw["crystals"]), "commons")
		got.append(Money.amount(int(rw["crystals"])))
	for it: String in rw.get("give", {}):
		GameState.add_item(it, int(rw["give"][it]), true)
		got.append("%s ×%d" % [GameState.item_name(it), int(rw["give"][it])])
	GameState.add_friend(keeper(), int(rw.get("friend", 0)))
	st()["goodwill"] = int(st().get("goodwill", 0)) + int(rw.get("goodwill", 0))
	GameState.add_xp("farming", 20)
	return ", ".join(got)


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
			text = "%s · all %d stages done.\nMarket on the 7th, 21st and 28th%s." % [place_name(), stages().size(), " (today!)" if market_day() else ""]
			if not ask().is_empty():
				text += "\n%s: \"%s\" (you carry %d)" % [keeper_name(), str(tx(data().get("ask_text", ""))).format({"need": ask_need()}), have_of(str(ask()["key"]))]
				opts.append("Give for the ask")
				acts.append("ask")
			else:
				text += "\nThis season's ask is answered. Thank you!"
		elif pending() >= 0:
			text = "%s · stage %d of %d: %s\nAll in! The crew is building the %s: %s, done %s. Come back tomorrow and see." % [place_name(), pending() + 1, stages().size(), stage_name(pending()), build_word(pending()), build_bar(), build_left_words()]
		else:
			var sd: Dictionary = stages()[stage()]
			text = "%s · stage %d of %d: %s\n%s\n%s" % [place_name(), stage() + 1, stages().size(), stage_name(stage()), str(tx(sd["desc"])), "\n".join(need_lines())]
			if not sd.get("need", {}).is_empty():
				opts.append("Give what I carry")
				acts.append("give")
			elif stage_ready():  # the lot is clear but the stage never closed (app shut mid-scene)
				opts.append("Tell %s it's done" % keeper_name())
				acts.append("finish")
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
					Music.instance(m.get_tree()).sfx("nope", "thud")
					continue
				var put := contribute()
				if put > 0:
					m.hud.toast("Added %d item%s." % [put, "" if put == 1 else "s"], Color(0.8, 1, 0.8))
					Music.instance(m.get_tree()).sfx("pickup")
					GameState.add_friend(keeper(), mini(10, put / 3 + 1))
				else:
					m.hud.toast("You carry nothing this stage still needs.", Color(1, 0.85, 0.7))
					Music.instance(m.get_tree()).sfx("nope", "thud")
				if stage_ready():
					await bundle_full(m)
					return
				sync_quest()
			"finish":
				if guest_blocked(m):
					continue
				await bundle_full(m)
				return
			"ask":
				if Net.visiting():
					m.hud.toast("This is your host's valley: their farm, their board.", Color(1, 0.85, 0.7))
					Music.instance(m.get_tree()).sfx("nope", "thud")
					continue
				var got := give_ask()
				if got == "":
					m.hud.toast("Not enough yet: %s." % ask_need(), Color(1, 0.85, 0.7))
					Music.instance(m.get_tree()).sfx("nope", "thud")
					continue
				Music.instance(m.get_tree()).sfx("quest_done", "levelup")
				await m.say([{"who": keeper_name(), "text": ("That'll feed a lot of people. Here, from the commons: %s." if arc() == "penguins" else "That feeds the whole block. Here, from all of us: %s.") % got}])
			"list":
				var lines: Array = []
				for k in stages().size():
					lines.append("%s %d. %s" % ["✓" if k < stage() else ("▶" if k == stage() else "·"), k + 1, stage_name(k)])
				await m.say([{"who": place_name(), "text": "\n".join(lines)}])


# ---- the market stand, share crate, compost, well ---------------------------------------

static func is_produce(id: String) -> bool:
	return GameState.family(id) in ["veg", "fruit", "berry", "tree", "grain", "flower", "herb"] and str(GameState.items.get(id, {}).get("type", "")) != "seed"


## Stand economy (C8 P6, c8_07): the stand sells at STAND_MARKUP over what a piece
## sells for (above the market-day pay, so buy-and-resell never gains), market day
## pays MARKET_BONUS over the shipping box, and donations go to the pantry
## (neighbours take them), never back on sale.
const STAND_MARKUP := 1.35
const PANTRY_TAKE := 40  # donated pieces neighbours take a night
const COMPOST_DAY_CAP := 5  # fertilizer the compost makes for you a day
const MARKET_BONUS := 1.25


static func stand_price(id: String) -> int:
	return maxi(1, int(ceil(GameState.unit_sell_value(id) * STAND_MARKUP)))


static func _bag_produce() -> Array:
	var ids: Array = []
	for id in GameState.run["inventory"]:
		if is_produce(str(id)) and int(GameState.run["inventory"][id]) > 0 and not GameState.is_locked(str(id)) and not DecorSources.keeps(str(id)):
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return GameState.count(a) > GameState.count(b))
	return ids.slice(0, 7)


static func open_stand(m: GameMap) -> void:
	if guest_blocked(m, "stand"):
		return
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
		var head := "%s stand. %s  (you have %s)" % [place_name(), ("Market day! The whole town's here." if arc() == "penguins" else "Market day. The whole block's out.") if market_day() else ("Fresh from the beds." if kinds > 0 else "Nothing ripe yet: donations welcome."), Money.fmt(int(GameState.run["crystals"]))]
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
		opts.append("%s ×%d  %s" % [GameState.item_name(str(id)), int(stock[id]), Money.fmt(stand_price(str(id)))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Everything here grew in the community beds.", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var id := str(ids[d.last_choice])
	var dq := Dialogue.instance(m.get_tree())
	dq.say([{"who": "Stand", "text": "%s, %s each. How many?" % [GameState.item_name(id), Money.fmt(stand_price(id))], "choice": ["1", "5", "All %d" % int(stock[id]), "Back"], "key": ""}])
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
		m.hud.toast("This is your host's valley: give to your own %s." % short_name(), Color(1, 0.85, 0.7))
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	var ids := _bag_produce()
	if ids.is_empty():
		m.hud.toast("You carry no produce to give.", Color(1, 0.85, 0.7))
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	var opts: Array = []
	for id in ids:
		opts.append("%s ×%d" % [GameState.item_name(str(id)), GameState.count(str(id))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Donations go to the pantry for neighbours who need them. (All of the kind you pick.)", "choice": opts, "key": ""}])
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
	if n <= 0 or DecorSources.keeps(id):
		return  # one-of-a-kind pieces never go to the stand (C10a)
	GameState.add_item(id, -n)
	var pantry: Dictionary = st()["pantry"]
	pantry[id] = int(pantry.get(id, 0)) + n
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
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	var opts: Array = []
	for id in ids:
		opts.append("%s ×%d  %s" % [GameState.item_name(str(id)), GameState.count(str(id)), Money.fmt(market_pay(str(id), GameState.count(str(id))))])
	opts.append("Back")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Stand", "text": "Market-day prices: a quarter over the shipping box. (All of the kind you pick.)", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var id := str(ids[d.last_choice])
	var n := GameState.count(id)
	var pay := sell_at_market(id, n)
	Music.instance(m.get_tree()).sfx("cash", "coin")
	m.xp("bartering", mini(20, pay / 15 + 1))
	m.hud.toast("Sold %s for %s." % [ItemWords.count_id(id, n), Money.fmt(pay)], Color(1, 0.9, 0.5))


static func market_pay(id: String, n: int) -> int:
	var base := float(GameState.sell_price(id, n))
	var q := GameState.quality_of(id)
	var g := mini(n, int(q.get("g", 0)))
	var sv := mini(n - g, int(q.get("s", 0)))
	var unit := base / maxi(1, n)
	var qb := unit * (float(GameState.QUALITY_BONUS["g"]) * g + float(GameState.QUALITY_BONUS["s"]) * sv)
	return int((base + qb) * MARKET_BONUS)


## Sells n of a kind at the stand (C8 P6): starred pieces earn their bonus, the
## day's saturation counts them, and the money is counted once.
static func sell_at_market(id: String, n: int) -> int:
	if DecorSources.keeps(id):
		return 0
	var pay := market_pay(id, n)
	GameState.take_quality(id, n)
	GameState.add_item(id, -n)
	var sold: Dictionary = GameState.run.get("sold_today", {})
	sold[id] = int(sold.get(id, 0)) + n
	GameState.run["sold_today"] = sold
	GameState.add_money(pay, "market")
	Collections.record_ship(id, n)  # shipping log (C8 P3)
	return pay


static func collect_share(m: GameMap) -> void:
	if guest_blocked(m, "share crate"):
		return
	var sh: Dictionary = st()["share"]
	if sh.is_empty():
		m.hud.toast("Your share crate is empty. Volunteers fill it as the beds come in.", Color(0.95, 0.9, 0.8))
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	var bits: Array = []
	for id: String in sh.keys():
		GameState.add_item(id, int(sh[id]), true)
		bits.append("%s ×%d" % [GameState.item_name(id), int(sh[id])])
	sh.clear()
	Music.instance(m.get_tree()).sfx("chest_open", "pickup")
	m.say.call_deferred([{"text": "Your share: %s." % ", ".join(bits)}])


static func compost(m: GameMap) -> void:
	if guest_blocked(m, "compost"):
		return
	var opts: Array = []
	var acts: Array = []
	if GameState.count("fiber") >= 5:
		opts.append("Add 5 fibre (→ 1 fertilizer)")
		acts.append("fiber")
	if GameState.count_any("#veg") >= 3:
		opts.append("Add 3 vegetable scraps (→ 1 fertilizer)")
		acts.append("veg")
	var cday: Array = st().get("compost_day", [0, 0])
	if int(cday[0]) != int(GameState.run["day"]):
		cday = [int(GameState.run["day"]), 0]
	if int(cday[1]) >= COMPOST_DAY_CAP:
		opts.clear()
		acts.clear()  # a side source, not a fertilizer factory (C8 P6, c8_04_10)
	opts.append("Leave it")
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "Compost", "text": "Warm and busy with worms. It turns scraps into fertilizer (up to %d a day), and drops a little in your share crate every few days by itself." % COMPOST_DAY_CAP, "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= acts.size():
		return
	if str(acts[d.last_choice]) == "fiber":
		GameState.add_item("fiber", -5)
	else:
		GameState.take_any("#veg", 3)
	cday[1] = int(cday[1]) + 1
	st()["compost_day"] = cday
	Music.instance(m.get_tree()).sfx("dig", "pickup")
	m.give("fertilizer", 1)
	m.xp("farming", 2)


static func drink(m: GameMap) -> void:
	if int(st().get("drank", -1)) == int(GameState.run["day"]):
		m.hud.toast("Cold and clear. You've had your fill today.", Color(0.85, 0.95, 1))
		Music.instance(m.get_tree()).sfx("nope", "thud")
		return
	if int(GameState.run["energy"]) >= int(GameState.run["max_energy"]):
		m.hud.toast("Cold and clear. You're not thirsty.", Color(0.85, 0.95, 1))
		return
	if not Net.visiting():  # a host-day stamp would block our own well at home
		st()["drank"] = int(GameState.run["day"])
	var got := GameState.rest_energy(15)  # the shared rest half-bar (C8 P6)
	Music.instance(m.get_tree()).sfx("drink", "pickup")
	m.hud.toast(("You drink from the well. +%d energy." % got) if got > 0 else "Cold and clear. You've rested enough today.", Color(0.8, 0.95, 1))


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
	# The seeds you donated go in first, while they suit the season (open beds only).
	var mine: Array = []
	for sid: String in (st().get("seed_kinds", {}) as Dictionary):
		var c := str(GameState.items.get(sid, {}).get("crop", ""))
		if c != "" and GameState.crops.has(c) and not c in mine and GameState.crop_fits_season(GameState.crops[c], se):
			mine.append(c)
	if not glass and not mine.is_empty() and i % 3 != 0:  # a third of the rows stay the volunteers' pick
		return str(mine[i % mine.size()])
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
	# Neighbours empty the pantry (donations) every night, whatever the stage.
	var pantry: Dictionary = st()["pantry"]
	var room := PANTRY_TAKE
	for id: String in pantry.keys():
		if room <= 0:
			break
		var t := mini(room, int(pantry[id]))
		pantry[id] = int(pantry[id]) - t
		room -= t
		if int(pantry[id]) <= 0:
			pantry.erase(id)
	var flags: Dictionary = GameState.run["flags"]
	if not flags.has("cf_letter") and int(GameState.run["day"]) >= 3 and (flags.has("cf_met") or Mail.intro_ok()):  # old saves: at most 2 opening letters a day (C9 P5)
		flags["cf_letter"] = true
		flags["cf_known"] = true
		if not flags.has("cf_met"):  # already met her out there: no "come and help" letter
			Mail.send(keeper_name(), str(tx(data()["letter"])), "chat", {"npc": keeper()})
			Mail.intro_sent()
		sync_quest()
	var lines: Array = []
	if pending() >= 0:
		var b := pending()
		var done := build_done() + 1
		if done < build_days(b):
			# A night of a multi-day build: the site shows the half-built piece tomorrow.
			st()["build_done"] = done
			var prog: Array = stages()[b].get("progress", [])
			lines.append(str(tx(prog[done - 1])) if done - 1 < prog.size() else "The crew worked on the %s all night: %d of %d nights done." % [build_word(b), done, build_days(b)])
			sync_quest()
		else:
			var night := str(tx(stages()[b].get("night", {"penguins": "The crew finished the %s overnight." % build_word(b)})))
			finish_stage(null, false)  # the sleep saves
			flags["cf_reveal_done"] = true  # Hazel's "done" line plays in the reveal on your next visit
			lines.append(night)
	# The compost works from the day the shed stands (a little fertilizer every third night).
	var share_before := _share_n()
	if stage() >= 2 and int(GameState.run["day"]) % 3 == 0:
		var sh0: Dictionary = st()["share"]
		sh0["fertilizer"] = mini(20, int(sh0.get("fertilizer", 0)) + 1)
	if stage() < 4:
		if _share_n() > share_before:
			lines.append("The compost made a little fertilizer: it's in your share crate.")
		if not lines.is_empty():
			report["cfarm"] = lines
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
	var fresh := _share_n() > share_before
	if complete():
		var nd := int(GameState.run["day"]) + 1
		var dos := (nd - 1) % GameState.DAYS_PER_SEASON + 1
		if dos % 7 == 0:
			lines.append("Market day at %s today! The stand pays a quarter over the shipping box." % short_name())
		elif dos == 1:
			lines.append("New season, new ask on the board at %s, if you can spare it." % short_name())
	if picked > 0:
		lines.append("The volunteers picked %d bed%s at %s%s" % [picked, "" if picked == 1 else "s", short_name(), ": your share's in the crate." if fresh else "."])
	elif fresh:
		lines.append("Something new is waiting in your share crate at %s." % short_name())
	if not lines.is_empty():
		report["cfarm"] = lines


static func _share_n() -> int:
	var n := 0
	for v in (st()["share"] as Dictionary).values():
		n += int(v)
	return n
