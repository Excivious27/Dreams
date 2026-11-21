class_name FestivalExtra
extends RefCounted
## C15 P6: the festivals added in C15 that are held in town (data/festivals.json handler ids):
## Blossom Dance / Rooftop Bloom, Founders' Day / Turf Day, Hollow Night / Mask Night,
## Winter Market / Night Market, Gift Swap Feast / Year's End Swap. One try per festival day (key);
## every choice is seeded by the day so a reload replays the same festival. All ages.

const HANDLED := ["blossom", "founders", "hollow", "winter_market", "gift_swap"]
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
