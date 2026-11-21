class_name FestivalExtra
extends RefCounted
## C15 P6: the festivals added in C15 that are held in town (data/festivals.json handler ids):
## Blossom Dance / Rooftop Bloom, Founders' Day / Turf Day, Hollow Night / Mask Night,
## Winter Market / Night Market, Gift Swap Feast / Year's End Swap. One try per festival day (key);
## every choice is seeded by the day so a reload replays the same festival. All ages.

const HANDLED := ["blossom", "founders", "hollow", "winter_market", "gift_swap", "tide_feast", "derby", "regatta", "moon_jellies"]
## Festivals held off the town plaza: their scene adds the festival spot through venue_thing(m)
## (one hook line in the scene's build) and routes it through interact(m, thing).
const VENUE := ["tide_feast", "derby", "regatta", "moon_jellies"]
const STEPS := ["up", "down", "left", "right"]


static func handles(fest: String) -> bool:
	return fest in HANDLED


static func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(GameState.run.get("day", 1)) * 977 + salt
	return r


static func _pen() -> bool:
	return GameState.is_penguins()


static func _ask(m: GameMap, who: String, text: String, choices: Array) -> int:
	var d := Dialogue.instance(m.get_tree())
	var line := {"text": text, "choice": choices, "key": ""}
	if who != "":
		line["who"] = who
	d.say([line])
	await d.finished
	return d.last_choice


static func play(m: GameMap, fest: String, key: String) -> void:
	match fest:
		"blossom":
			await _blossom(m, key)
		"founders":
			await _founders(m, key)
		"hollow":
			await _hollow(m, key)
		"winter_market":
			await _winter_market(m, key)
		"gift_swap":
			await _gift_swap(m, key)
		"tide_feast":
			await _tide_feast(m, key)
		"derby":
			await _derby(m, key)
		"regatta":
			await _regatta(m, key)
		"moon_jellies":
			await _jellies(m, key)


## Today's festival row held in this map's scene (venue.scene), {} when none.
static func venue_today(scene: String) -> Dictionary:
	if GameState.run.is_empty():
		return {}
	var d := int(GameState.run.get("day", 1))
	for r: Dictionary in FestivalWords.rows_on(GameState.season(), (d - 1) % 28 + 1):
		if str(r["kind"]) != "holiday" and str((r["venue"] as Dictionary).get("scene", "")) == scene and str(r["id"]) in VENUE:
			return r
	return {}


## Hook for a venue scene's build: places the festival spot (A: <name>) at the row's cell.
static func venue_thing(m: GameMap) -> void:
	var r := venue_today(m.scene_id())
	if r.is_empty():
		return
	var c0: Array = r["venue"]["cell"]
	var at := Vector2i(int(c0[0]), int(c0[1]))
	for rad in 12:  # nearest open cell to the row's cell (sea, props and things are skipped)
		var found := false
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := at + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == rad and not m.blocked.has(q) and not m.things.has(q) and q.x > 1 and q.y > 1 and q.x < m.cols - 2 and q.y < m.rows - 2:
					at = q
					found = true
					break
			if found:
				break
		if found:
			break
	var c: Array = [at.x, at.y]
	if str(r["id"]) == "moon_jellies":  # glowing jellies drift over the water round the spot
		var real: Node = m.get("_painter_of") if m.get("_painter_of") is Node else m
		FestivalSky.make(real, "jellies", Rect2(Vector2(at - Vector2i(10, 0)) * GameMap.TILE, Vector2(20, 12) * GameMap.TILE))
	m.set_thing(int(c[0]), int(c[1]), {"type": "festival_venue", "fest": str(r["id"]), "hint": "A: " + FestivalWords.name_of(str(r["id"]))}, false)


## Hook for a venue scene's interact: true when it handled the thing.
static func interact(m: GameMap, thing: Dictionary) -> bool:
	if str(thing.get("type", "")) != "festival_venue":
		return false
	m.later(_venue_play.bind(m, str(thing.get("fest", ""))))
	return true


static func _venue_play(m: GameMap, fest: String) -> void:
	var fh := FestivalWords.hours_of(fest)
	var h := (int(GameState.run.get("time", 0)) % 1440) / 60.0
	if fh.y > 0.0 and (h < fh.x or h >= fh.y):
		m.hud.toast(FestivalWords.not_open_text(fest, fh, h < fh.x), Color(1, 0.9, 0.6))
		return
	var key := "fest_%s_%d" % [fest, int(GameState.run["day"])]
	if m.player:
		m.player.frozen = true
	if GameState.run["flags"].has(key):
		await m.say([{"who": FestivalWords.host_of(fest), "text": FestivalWords.again_text(fest)}])
	else:
		await play(m, fest, key)
		if GameState.run["flags"].has(key):
			RecCenter.festival_bonus(m, key)
			if not GameState.run["flags"].has(key + "_dc"):
				GameState.run["flags"][key + "_dc"] = true
				var d := FestivalWords.def(fest)
				var pool := str(d.get("prize_pool", ""))
				if not (Decor.data().get("pools", {}) as Dictionary).has(pool):
					pool = "festival_%s_prize" % str(d.get("season", "summer"))
				DecorSources.roll_grant(m, pool, 4.0 if int(GameState.run["flags"].get(key + "_place", 0)) == 1 else 0.0, "festival")
	if m.player:
		m.player.frozen = false


## Tide Feast / Boardwalk Block Party: one dish into the big pot (the crew grill). Score by value and
## quality -> a town-wide friendship band (never a penalty). Alcohol is a trade good: never an entry.
const ALCOHOL := ["wine", "ale", "mead", "cider", "beer", "lager", "whiskey", "whisky", "rum", "brandy", "sake", "champagne"]


static func is_alcohol(id: String) -> bool:
	var words := (id + " " + GameState.item_name(id)).to_lower().replace("_", " ").split(" ", false)
	for w in words:
		if w in ALCOHOL:
			return true
	return false


static func potluck_band(id: String) -> int:
	if is_alcohol(id) or not GameState.items.has(id):
		return 0
	var it: Dictionary = GameState.items[id]
	var q: Dictionary = GameState.quality_of(id)
	var qp := 30 if int(q.get("i", 0)) > 0 else (20 if int(q.get("g", 0)) > 0 else (10 if int(q.get("s", 0)) > 0 else 0))
	var sc := GameState.item_value(id) + qp + (40 if str(it.get("type", "")) == "food" else 0)
	return 4 if sc >= 400 else (3 if sc >= 200 else (2 if sc >= 90 else (1 if sc >= 30 else 0)))


const POTLUCK_GAIN := [0, 10, 20, 40, 80]


static func _tide_feast(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("tide_feast")
	var opts: Array = []
	for id in GameState.run["inventory"].keys():
		var sid := str(id)
		var ty := str(GameState.items.get(sid, {}).get("type", ""))
		if GameState.count(sid) > 0 and not GameState.is_locked(sid) and (ty in ["food", "crop", "fruit", "fish"] or is_alcohol(sid)):
			opts.append(sid)
	opts.sort_custom(func(a: String, b: String) -> bool: return GameState.item_value(a) > GameState.item_value(b))
	opts = opts.slice(0, 4)
	if opts.is_empty():
		await m.say([{"who": host, "text": "Bring something for the pot! A fish, a crop, a dish: anything you're proud of." if _pen() else "Bring something for the grill. Fish, veg, whatever you've got."}])
		return
	var nm: Array = []
	for id: String in opts:
		nm.append(GameState.item_name(id))
	nm.append("Not now")
	var c: int = await _ask(m, host, "One thing each into the big pot. What are you adding?" if _pen() else "One thing each on the grill. What's yours?", nm)
	if c < 0 or c >= opts.size():
		return
	var pick: String = opts[c]
	if is_alcohol(pick):
		await m.say([{"who": host, "text": "That's for trading, not for the pot. Pick something we can all eat!"}])
		return
	GameState.run["flags"][key] = true
	GameState.add_item(pick, -1)
	var band := potluck_band(pick)
	var gain: int = POTLUCK_GAIN[band]
	var lines := ["A polite stir. Nobody minds.", "A nice touch. People go back for seconds.", "Lovely! The pot smells wonderful now.", "Wonderful! Everyone's talking about it.", "The best pot in years! The whole beach cheers."] if _pen() \
		else ["It's on the grill. Nobody complains.", "Not bad. A few people come back.", "Good stuff. The line gets longer.", "Big hit. The whole boardwalk's talking.", "Best grill in years. The crew salutes you."]
	await m.say([{"who": host, "text": lines[band]}])
	if gain > 0:
		for id in GameState.npcs:
			if int(GameState.run["friendship"].get(str(id), 0)) > 0 and not GameState.run["flags"].has(str(id) + "_gone"):
				GameState.add_friend(str(id), gain)
		m.hud.toast("Everyone you know +%d friendship" % gain, Color(1, 0.8, 0.9))
	if band >= 3:
		GameState.run["flags"][key + "_place"] = 1


## Villagers you could dance with: 4+ hearts, still in town, this arc; a partner (Romance) dances
## only with you and you only with them (no gender checks).
static func dance_partners() -> Array:
	var p := Romance.partner()
	if p != "" and GameState.npcs.has(p):
		return [p]
	var out: Array = []
	for id in GameState.npcs:
		var sid := str(id)
		if GameState.friend_hearts(sid) >= 4 and not GameState.run["flags"].has(sid + "_gone") and Hearts.in_arc(sid):
			out.append(sid)
	out.sort_custom(func(a: String, b: String) -> bool: return int(GameState.run["friendship"].get(a, 0)) > int(GameState.run["friendship"].get(b, 0)))
	return out.slice(0, 4)


## The host's call for the day: 4 steps, seeded.
static func dance_calls() -> Array:
	var r := _rng(24)
	var out: Array = []
	for i in 4:
		out.append(STEPS[r.randi() % 4])
	return out


## Friendship for a dance score 0..4.
static func dance_gain(score: int) -> int:
	return [10, 30, 30, 60, 90][clampi(score, 0, 4)]


static func _blossom(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("blossom")
	var partners := dance_partners()
	var who := ""
	if not partners.is_empty():
		var nm: Array = []
		for id: String in partners:
			nm.append(str(GameState.npcs[id]["name"]))
		nm.append("Dance with the whole circle")
		nm.append("Not now")
		var c: int = await _ask(m, host, "Find a partner! Who are you asking?" if _pen() else "Pick someone for the floor. Who's it going to be?", nm)
		if c < 0 or c == nm.size() - 1:
			return
		if c < partners.size():
			who = partners[c]
	else:
		var c2: int = await _ask(m, host, "Join the circle! Everybody dances." if _pen() else "No date? The circle takes everybody.", ["Join in", "Not now"])
		if c2 != 0:
			return
	GameState.run["flags"][key] = true
	var calls := dance_calls()
	var words := {"up": "step forward", "down": "step back", "left": "sway left", "right": "sway right"}
	var said: Array = []
	for s: String in calls:
		said.append(str(words[s]))
	await m.say([{"who": host, "text": "Listen, then follow: %s!" % ", ".join(said)}])
	var score := 0
	for i in calls.size():
		var opts: Array = []
		for s: String in STEPS:
			opts.append(str(words[s]).capitalize())
		var pick: int = await _ask(m, "", "Step %d of %d..." % [i + 1, calls.size()], opts)
		if pick >= 0 and pick < 4 and STEPS[pick] == calls[i]:
			score += 1
			Music.instance(m.get_tree()).sfx("beat_tick", "pickup")
		else:
			Music.instance(m.get_tree()).sfx("block", "pickup")
	var gain := dance_gain(score)
	if who != "":
		GameState.add_friend(who, gain)
		m.hud.toast("%s +%d friendship" % [str(GameState.npcs[who]["name"]), gain], Color(1, 0.8, 0.9))
	else:
		for id in GameState.npcs:
			if int(GameState.run["friendship"].get(str(id), 0)) > 0 and not GameState.run["flags"].has(str(id) + "_gone"):
				GameState.add_friend(str(id), gain / 3)
		m.hud.toast("The whole circle +%d friendship" % (gain / 3), Color(1, 0.8, 0.9))
	var verdict: Array = ["You laugh your way through it. Nobody minds.", "A few right steps. Not bad at all.", "Half the steps! People clap anyway.", "Nearly perfect. Petals land in your hair.", "Every step right. The whole park cheers."]
	await m.say([{"text": verdict[score]}])
	if score >= 3:
		GameState.run["flags"][key + "_place"] = 1
	var crown := "c15p6_flower_crown"
	if score >= 2 and Decor.data().get("items", {}).has(crown) and not DecorSources.taken(crown):
		DecorSources.grant(m, crown, 1, "festival")


## Founders' Day / Turf Day (year 2+): the parade, then three questions on the history talk.
const FOUNDERS_Q := [
	["When is the Egg Festival?", ["Spring 14", "Summer 14", "Fall 1"], 0],
	["Where do the lanterns go?", ["Down the river", "Up the hill", "Into the mine"], 0],
	["How many days in a season?", ["28", "30", "14"], 0],
	["When is the Star Festival?", ["Winter 14", "Winter 28", "Fall 27"], 0],
	["What floats down the river in summer?", ["Lanterns", "Pumpkins", "Snowmen"], 0],
]


static func _founders(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("founders")
	var c: int = await _ask(m, host, ("Happy Founders' Day! The parade's done. Three questions on the town's story, and a prize for every right answer." if _pen()
		else "Turf Day. The crew's been on this block a long time. Three questions. Get them right, get paid."), ["Ask away", "Not now"])
	if c != 0:
		return
	GameState.run["flags"][key] = true
	var r := _rng(7)
	var idx: Array = range(FOUNDERS_Q.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t: Variant = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	var right := 0
	for k in 3:
		var q: Array = FOUNDERS_Q[int(idx[k])]
		var opts: Array = (q[1] as Array).duplicate()
		var correct := str(opts[int(q[2])])
		var sh := r.randi() % opts.size()
		opts = opts.slice(sh) + opts.slice(0, sh)
		var p: int = await _ask(m, host, str(q[0]), opts)
		if p >= 0 and p < opts.size() and str(opts[p]) == correct:
			right += 1
	var pay := right * 60
	if pay > 0:
		GameState.add_money(pay, "festival")
	if right == 3:
		GameState.run["flags"][key + "_place"] = 1
	await m.say([{"who": host, "text": "%d of 3! %s" % [right, ("Here's %s for knowing your town." % Money.amount(pay)) if pay > 0 else "Next year, then."]}])


## Hollow Night / Mask Night: a lantern walk with three forks (seeded), the Golden Gourd at the
## end of the right path; treats either way; the costume judge likes any festival wear you have on.
static func hollow_path() -> Array:
	var r := _rng(27)
	return [r.randi() % 2, r.randi() % 2, r.randi() % 2]


static func _hollow(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("hollow")
	var c: int = await _ask(m, host, ("Hollow Night! Take a lantern into the maze. Somewhere in there is the Golden Gourd. Nothing scary, just Pip in a bedsheet." if _pen()
		else "Masks on. Walk the alley with a lantern; somewhere down there is the gold mask. Nobody bites."), ["Take a lantern", "Not now"])
	if c != 0:
		return
	GameState.run["flags"][key] = true
	var path := hollow_path()
	var ok := 0
	var forks := ["The path splits round a grinning pumpkin.", "Two hedges, one lantern each. A giggle from the left... or the right?", "Last turn. A paper bat sways over both ways."]
	for i in 3:
		var p: int = await _ask(m, "", forks[i], ["Go left", "Go right"])
		if p == path[i]:
			ok += 1
	m.give("candy", 2 + ok)
	if ok == 3:
		GameState.run["flags"][key + "_place"] = 1
		await m.say([{"text": "At the heart of the maze, under a straw hat: the Golden Gourd! %s" % ("Everyone cheers." if _pen() else "The crew whistles.")}])
	else:
		await m.say([{"text": "A dead end, a bedsheet ghost and a giggle. Pip hands you some candy for trying."}])
	m.xp("foraging", 20)


## Winter Market / Night Market: a guest vendor (rotates by year) and a snow-sculpt contest.
const GUESTS := [
	["the travelling toymaker", [["candy", 15], ["cake", 140]]],
	["the glassblower", [["hot_cocoa", 180], ["candy", 15]]],
	["the fishmonger", [["gift_pie", 45], ["spiced_loaf", 95]]],
	["the decor merchant", [["candy", 15], ["hot_cocoa", 180]]],
]
const SHAPES := ["Snow penguin", "Snow star", "Snow castle", "Snow cat", "Snow tree"]


static func guest() -> Array:
	return GUESTS[(FestivalWords.year_of(int(GameState.run.get("day", 1))) - 1) % GUESTS.size()]


## Snow-sculpt score: variety of the three shapes plus a seeded judge's taste. 0..100.
static func sculpt_score(picks: Array) -> int:
	var uniq := {}
	for p in picks:
		uniq[p] = true
	var r := _rng(10)
	var fav := r.randi() % SHAPES.size()
	var s := uniq.size() * 25
	if fav in picks:
		s += 25
	return clampi(s, 0, 100)


static func _winter_market(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("winter_market")
	var g := guest()
	var c: int = await _ask(m, host, ("The Winter Market! This year's guest is %s. And there's the snow-sculpt contest." if _pen()
		else "Night Market. Guest stall tonight: %s. Snow-sculpt contest round the back.") % str(g[0]), ["Visit the guest stall", "Enter the snow-sculpt contest", "Not now"])
	if c == 0:
		var treats: Array = (g[1] as Array).filter(func(t: Variant) -> bool: return GameState.items.has(str((t as Array)[0])))
		await Shops.stall(m, host, "Treats from %s, tonight only." % str(g[0]), treats, 0.0, "festival_winter")
		return
	if c != 1:
		return
	GameState.run["flags"][key] = true
	var picks: Array = []
	for i in 3:
		var p: int = await _ask(m, "", "Sculpt %d of 3: what do you make?" % (i + 1), SHAPES)
		picks.append(maxi(0, p))
	var sc := sculpt_score(picks)
	var place := 1 if sc >= 90 else (2 if sc >= 60 else 3)
	GameState.run["flags"][key + "_place"] = place
	var pay: int = [200, 100, 40][place - 1]
	GameState.add_money(pay, "festival")
	await m.say([{"who": host, "text": "The judges say %d points: %s place and %s!" % [sc, ["first", "second", "third"][place - 1], Money.amount(pay)]}])


## Gift Swap Feast / Year's End Swap: your secret partner for the year (seeded by year, a villager you know,
## never the same two years running); their reaction counts double, and your own secret giver
## hands you something back.
static func secret_partner(year := -1) -> String:
	if year < 0:
		year = FestivalWords.year_of(int(GameState.run.get("day", 1)))
	var known: Array = []
	for id in GameState.npcs:
		var sid := str(id)
		if int(GameState.run["friendship"].get(sid, 0)) > 0 and not GameState.run["flags"].has(sid + "_gone") and Hearts.in_arc(sid):
			known.append(sid)
	known.sort()
	if known.is_empty():
		return ""
	var pick := str(known[(year * 7 + 3) % known.size()])
	var last := str(GameState.run["flags"].get("gift_swap_y%d" % (year - 1), ""))
	if pick == last and known.size() > 1:
		pick = str(known[(year * 7 + 4) % known.size()])
	return pick


static func _gift_swap(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("gift_swap")
	var year := FestivalWords.year_of(int(GameState.run.get("day", 1)))
	var who := secret_partner(year)
	if who == "":
		await m.say([{"who": host, "text": "Get to know a few people this year and you'll be in the swap next time!"}])
		return
	var opts: Array = []
	for id in GameState.run["inventory"].keys():
		var sid := str(id)
		if GameState.count(sid) > 0 and not GameState.is_locked(sid) and GameState.items.has(sid):
			opts.append(sid)
	opts.sort_custom(func(a: String, b: String) -> bool: return GameState.gift_value(who, a) > GameState.gift_value(who, b))
	opts = opts.slice(0, 4)
	if opts.is_empty():
		await m.say([{"who": host, "text": "Bring a gift for %s! Anything from your bag will do." % str(GameState.npcs[who]["name"])}])
		return
	var nm: Array = []
	for id: String in opts:
		nm.append(GameState.item_name(id))
	nm.append("Not now")
	var c: int = await _ask(m, host, ("Your secret partner this year is %s. What are you giving?" if _pen() else "Your name in the hat: %s. What's in the box?") % str(GameState.npcs[who]["name"]), nm)
	if c < 0 or c >= opts.size():
		return
	GameState.run["flags"][key] = true
	GameState.run["flags"]["gift_swap_y%d" % year] = who
	var item: String = opts[c]
	GameState.add_item(item, -1)
	var v := GameState.gift_value(who, item)
	var gain := maxi(0, v) * 2
	GameState.add_friend(who, gain)
	if v >= 12:
		GameState.run["flags"][key + "_place"] = 1
	var back: String = ["cake", "hot_cocoa", "gift_pie", "spiced_loaf"][year % 4]
	await m.say([{"text": "%s unwraps it. %s" % [str(GameState.npcs[who]["name"]), "Their face lights up." if v >= 12 else ("A warm smile." if v > 0 else "A polite nod.")]},
		{"who": host, "text": "And somebody had your name! %s" % ("A year well spent, everyone. Here's to the next one." if _pen() else "Good year. Same again next year.")}])
	if GameState.items.has(back):
		m.give(back)
	m.hud.toast("%s +%d friendship" % [str(GameState.npcs[who]["name"]), gain], Color(1, 0.8, 0.9))



## Fishing Derby: bring your best fish to the judge by 2pm; scored on value and quality against two
## seeded rivals who get better every year (capped). 300/150/50 and the keepsake roll.
static func derby_rivals(year: int) -> Array:
	var r := _rng(9)
	var base := 60 + 25 * (year - 1)
	return [mini(base + r.randi() % 40, 320), mini(base - 15 + r.randi() % 30, 300)]


static func fish_score(id: String) -> int:
	var q: Dictionary = GameState.quality_of(id)
	var qp := 30 if int(q.get("i", 0)) > 0 else (20 if int(q.get("g", 0)) > 0 else (10 if int(q.get("s", 0)) > 0 else 0))
	return GameState.item_value(id) + qp


static func _derby(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("derby")
	if (int(GameState.run.get("time", 0)) % 1440) >= 14 * 60:
		await m.say([{"who": host, "text": "Weigh-in closed at two. Next year!"}])
		return
	var fish: Array = []
	for id in GameState.run["inventory"].keys():
		var sid := str(id)
		if GameState.count(sid) > 0 and str(GameState.items.get(sid, {}).get("type", "")) == "fish" \
				and not Collections.data().get("legends", {}).has(sid):  # C16a P4: legends are too precious to weigh
			fish.append(sid)
	fish.sort_custom(func(a: String, b: String) -> bool: return fish_score(a) > fish_score(b))
	fish = fish.slice(0, 4)
	if fish.is_empty():
		await m.say([{"who": host, "text": "No fish yet? The pier's open till two. Go catch me a big one!"}])
		return
	var nm: Array = []
	for id: String in fish:
		nm.append(GameState.item_name(id))
	nm.append("Not now")
	var c: int = await _ask(m, host, "What are you weighing in?", nm)
	if c < 0 or c >= fish.size():
		return
	GameState.run["flags"][key] = true
	var pick: String = fish[c]
	var sc := fish_score(pick)  # C16a P4 (c16a_05-09): the weigh-in never takes your fish
	var rv := derby_rivals(FestivalWords.year_of(int(GameState.run["day"])))
	var place := 1 + int(int(rv[0]) > sc) + int(int(rv[1]) > sc)
	GameState.run["flags"][key + "_place"] = place
	var yr := FestivalWords.year_of(int(GameState.run["day"]))
	var pay: int = int([300, 150, 50][place - 1] * minf(2.0, 1.0 + 0.25 * (yr - 1)))  # C16a P4: prizes grow (x2 cap)
	GameState.add_money(pay, "festival")
	await m.say([{"who": host, "text": "%s on the scale... %s place! %s." % [ItemWords.with_article(GameState.item_name(pick)).capitalize(), ["First", "Second", "Third"][place - 1], Money.amount(pay)]}])


## Regatta (penguins) / Harbour Lights ring toss (gangsters): three legs, read the water (or the
## wind on the rings); every leg has a tell, so it is skill, not a coin flip.
static func regatta_legs() -> Array:
	var r := _rng(18)
	return [r.randi() % 2, r.randi() % 2, r.randi() % 2]


static func _regatta(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("regatta")
	var c: int = await _ask(m, host, "The regatta! Three legs round the buoys. Watch the water and pick your line." if _pen()
		else "Harbour Lights. Three rings, three bottles. Watch the breeze off the water.", ["Race" if _pen() else "Throw", "Not now"])
	if c != 0:
		return
	GameState.run["flags"][key] = true
	var legs := regatta_legs()
	var ok := 0
	for i in 3:
		var tell: String = (["Dark ripples on the left: wind there. The right is glassy.", "Glassy water to the left; the right side is ruffled with wind."] if _pen()
			else ["The flags lean left: aim right of the bottle.", "The flags lean right: aim left of the bottle."])[legs[i]]
		var opts: Array = ["Take the left line", "Take the right line"] if _pen() else ["Aim left", "Aim right"]
		var want: int = (1 - int(legs[i])) if not _pen() else int(legs[i])
		var p: int = await _ask(m, "", "Leg %d. %s" % [i + 1, tell] if _pen() else "Ring %d. %s" % [i + 1, tell], opts)
		if p == want:
			ok += 1
	var place := 3 - ok if ok > 0 else 3
	GameState.run["flags"][key + "_place"] = place
	var pay: int = [250, 120, 40][place - 1]
	GameState.add_money(pay, "festival")
	await m.say([{"who": host, "text": "%d of 3! %s" % [ok, "%s place and %s." % [["First", "Second", "Third"][place - 1], Money.amount(pay)]]}])


## Moon Jellies / Neon Tide (year 2+, night): watch from the pier; a keepsake roll.
static func _jellies(m: GameMap, key: String) -> void:
	var host := FestivalWords.host_of("moon_jellies")
	GameState.run["flags"][key] = true
	var gold := FestivalWords.year_of(int(GameState.run["day"])) >= 3
	await m.say([{"who": host, "text": "There they are. Hundreds of them, glowing like little moons." if _pen() else "Glow buoys on, and the jellies come up to meet them."},
		{"text": "A golden one drifts right past the pier!" if gold else "They drift past the pier, slow and bright."}])
	if gold:
		GameState.run["flags"][key + "_place"] = 1
