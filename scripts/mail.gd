class_name Mail
extends RefCounted
## Letters from the world, delivered every morning (GameState.sleep → Mail.morning):
##  - news: tomorrow's festival or storm, a birthday, the season ending, heat,
##    a colony in trouble, the keeper deeper in the mine;
##  - favours: a villager asks for a few of something; send it from the letter
##    for gold and friendship (it expires after a few days);
##  - gifts: friends now and then send a little something;
##  - chatter: a line from someone you know.
## Read them at the farm mailbox or in MENU → Quests → Mail.
## run["mail"] = [{id, day, from, text, kind, item, n, pay, got, read, until}]

const MAX_KEEP := 30


static func list() -> Array:
	if not GameState.run.has("mail"):
		GameState.run["mail"] = []
	return GameState.run["mail"]


static func unread() -> int:
	var n := 0
	for m: Dictionary in list():
		if not bool(m.get("read", false)):
			n += 1
	return n


static func send(from: String, text: String, kind := "chat", extra := {}) -> void:
	var m := {"id": "%d_%d" % [int(GameState.run["day"]), list().size() + randi() % 1000], "day": int(GameState.run["day"]), "from": from, "text": text, "kind": kind, "read": false}
	m.merge(extra, true)
	list().append(m)
	while list().size() > MAX_KEEP:
		list().pop_front()


static func _name(id: String) -> String:
	return str(GameState.npcs.get(id, {}).get("name", id.capitalize()))


static func _known() -> Array:
	var out: Array = []
	for id: String in GameState.npcs:
		if int(GameState.run["friendship"].get(id, 0)) > 0 and not Crew.members().has(id):
			out.append(id)
	return out


## Called once each morning. Returns how many letters arrived.
static func morning() -> int:
	if GameState.run.is_empty():
		return 0
	var before := list().size()
	var day := int(GameState.run["day"])
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7349 + hash(str(GameState.run["names"]["character"]))
	# Old favours lapse.
	for m: Dictionary in list():
		if str(m.get("kind", "")) == "favour" and not bool(m.get("done", false)) and int(m.get("until", 0)) < day:
			m["done"] = true
			m["lapsed"] = true
	_news(rng)
	var known := _known()
	if known.is_empty():
		known = ["maple", "alder"]
	# A favour about every third day.
	if rng.randf() < 0.35:
		var who := str(known[rng.randi() % known.size()])
		var want := _favour_item(who, rng)
		if want != "":
			var n := rng.randi_range(2, 6) if GameState.item_value(want) < 60 else rng.randi_range(1, 2)
			var pay := int(GameState.item_value(want) * n * 1.3) + 10
			send(_name(who), "Could you spare %d %s? I'd pay ◆%d, and I'd owe you one. Send them back with this letter within %d days." % [n, GameState.item_name(want), pay, 4], "favour", {"npc": who, "item": want, "n": n, "pay": pay, "until": day + 4})
	# Gifts from friends (2+ hearts).
	var friends: Array = []
	for id in known:
		if GameState.friend_hearts(str(id)) >= 2:
			friends.append(id)
	if not friends.is_empty() and rng.randf() < 0.25:
		var who2 := str(friends[rng.randi() % friends.size()])
		var gift := _gift_item(who2, rng)
		send(_name(who2), "Found this and thought of you. Don't make a fuss. - %s" % _name(who2), "gift", {"npc": who2, "item": gift, "n": 1})
	# Chatter.
	if rng.randf() < 0.3:
		var who3 := str(known[rng.randi() % known.size()])
		var lines := [
			"The weather's turned and the whole town's talking about it. How's the farm?",
			"I saw your lights on late. Get some sleep, will you?",
			"If you're passing, drop in. The kettle's always on.",
			"Someone left flowers on the fountain this morning. Was it you?",
			"I've been meaning to say: it's good having you here.",
			"The market was busy today. You should bring something to sell.",
		]
		send(_name(who3), str(lines[rng.randi() % lines.size()]) + " - " + _name(who3), "chat", {"npc": who3})
	return list().size() - before


static func _news(rng: RandomNumberGenerator) -> void:
	var tomorrow := int(GameState.run["day"]) + 1
	var dos := ((tomorrow - 1) % GameState.DAYS_PER_SEASON) + 1
	if dos == GameState.FESTIVAL_DAY:
		var fid: String = str(GameState.FESTIVALS[GameState.season_of(tomorrow)][0])
		send("Mayor Alder", "Reminder: the %s is TOMORROW on the plaza. Shops close for the day. Come hungry!" % GameState.festival_name(fid), "news")
	var w := GameState.weather_for(tomorrow)
	if w in ["storm", "blizzard"]:
		send("Marlowe at the lighthouse", "Storm coming in tomorrow. Bring the animals in and don't bother watering.", "news")
	for id: String in GameState.npcs:
		var b := GameState.birthday_of(id)
		if b.size() == 2 and str(b[0]) == GameState.season_of(tomorrow) and int(b[1]) == dos:
			send("Pip", "Psst! Tomorrow is %s's birthday. A gift would mean a lot (gifts count triple)." % _name(id), "news")
	if GameState.DAYS_PER_SEASON - GameState.day_of_season() == 3:
		send("Hazel", "Three days left of %s. Anything still in the ground that can't take the new season won't make it; harvest what you can." % GameState.season().capitalize(), "news")
	if Racket.on() and Racket.heat() >= 3 and rng.randf() < 0.6:
		send("Ladder", "Collectors on the avenue. Lie low a day or two, boss. Or wash some money.", "news")
	if GameState.is_penguins() and Colony.saved() < 4 and int(GameState.run["day"]) % 9 == 0 and bool(Colony.st("colony_coral").get("met", false)):
		send("Grandmother Brine", "The islands are dimming. When you have a moment, the ferry waits at the end of the pier.", "news")


static func _favour_item(who: String, rng: RandomNumberGenerator) -> String:
	var likes: Array = GameState.npcs.get(who, {}).get("likes", [])
	var opts: Array = []
	for l in likes:
		var id := str(l)
		if GameState.items.has(id) and int(GameState.items[id].get("tier", 1)) <= GameState.progress_tier() + 1:
			opts.append(id)
	for id in ["wood", "stone", "turnip", "copper", "fiber", "egg", "milk", "potato", "berry"]:
		if GameState.items.has(id):
			opts.append(id)
	return str(opts[rng.randi() % opts.size()]) if not opts.is_empty() else ""


static func _gift_item(who: String, rng: RandomNumberGenerator) -> String:
	var likes: Array = GameState.npcs.get(who, {}).get("likes", [])
	for i in 6:
		if likes.is_empty():
			break
		var id := str(likes[rng.randi() % likes.size()])
		if GameState.items.has(id) and GameState.item_value(id) <= 150:
			return id
	return ["energy_tea", "berry_pie", "potion", "tea"][rng.randi() % 4] if GameState.items.has("berry_pie") else "potion"


## Take a gift's item, or send a favour's items. "" on success, else why not.
static func act(m: Dictionary) -> String:
	match str(m.get("kind", "")):
		"gift":
			if bool(m.get("got", false)):
				return "Already taken."
			m["got"] = true
			GameState.add_item(str(m["item"]), int(m.get("n", 1)))
			return ""
		"favour":
			if bool(m.get("done", false)):
				return "That's done." if not bool(m.get("lapsed", false)) else "Too late: they found it elsewhere."
			var id := str(m["item"])
			var n := int(m["n"])
			if GameState.count(id) < n:
				return "You need %d %s (you have %d)." % [n, GameState.item_name(id), GameState.count(id)]
			GameState.add_item(id, -n)
			GameState.run["crystals"] = int(GameState.run["crystals"]) + int(m["pay"])
			if m.has("npc"):
				GameState.add_friend(str(m["npc"]), 15)
			m["done"] = true
			return ""
	return ""
