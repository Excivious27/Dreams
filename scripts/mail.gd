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


## Something waits in the farm mailbox: the opening story letters (farm._mailbox) or unread mail.
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
		if int(GameState.run["friendship"].get(id, 0)) > 0 and not Crew.members().has(id) and GameState.npc_present(id):
			out.append(id)
	return out


## Letters that need reading or acting on (what GameMap.read_mail shows).
static func pending() -> int:
	var n := 0
	for m: Dictionary in list():
		if not bool(m.get("read", false)) or (str(m.get("kind", "")) == "favour" and not bool(m.get("done", false))) or (str(m.get("kind", "")) == "gift" and not bool(m.get("got", false))):
			n += 1
	return n


## The story's own letters waiting in the farm mailbox (read there, in order):
## [{flag, who, text, give: [item, n], quest: [id, text]}].
static func story_due() -> Array:
	if GameState.run.is_empty():
		return []
	var flags: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	var out: Array = []
	if GameState.is_penguins():
		if not flags.has("mail_1"):
			out.append({"flag": "mail_1", "who": "Letter", "text": "Welcome to %s! Here are a few strawberry seeds to start you off: they fruit again every few days once they're up. Stop by the Mercantile when you can. - Maple" % GameState.names()["town"], "give": ["strawberry_seed", 3]})
		if day >= 3 and not flags.has("mail_2"):
			out.append({"flag": "mail_2", "who": "Letter", "text": "Dear neighbor, something has been howling from the east meadow at night. Mayor Alder says it's nothing. It is not nothing. - Wren", "quest": ["clear_meadow", "Find out what's howling in the east meadow."]})
	else:
		# The first letter was read (and burned or kept) in the opening; M. writes again next morning.
		if day >= 2 and not flags.has("mail_1"):
			out.append({"flag": "mail_1", "who": "Letter", "text": "A second envelope, same careful hand, three packets of strawberry seed inside: 'Strawberries pay better than turnips, and nobody remembers a strawberry farmer. Maple at the store sells seeds and asks nothing. The man on the bench by the town gate has been places; he's worth a word. Burn this. - M.'", "give": ["strawberry_seed", 3]})
		if day >= 3 and not flags.has("mail_2"):
			out.append({"flag": "mail_2", "who": "Letter", "text": "A man came through town asking about a face like yours. He went east, toward the meadow. Be careful. - M.", "quest": ["clear_meadow", "Someone is asking about you. Check the east meadow."]})
	return out


## Everything waiting at the farm mailbox (the bobbing letter over it).
static func waiting() -> int:
	return story_due().size() + pending()


## The first week's letters, so the mailbox isn't empty while nobody knows you
## yet: a welcome with the town's hours (day 2) and a loaf from Posy (day 5).
## The story's own letters come on days 1-3 and Hazel's commons letter on day 4.
static func _first_week(day: int) -> void:
	var flags: Dictionary = GameState.run["flags"]
	var town := str(GameState.names()["town"])
	if day >= 2 and day <= 4 and not flags.has("wmail_2"):
		flags["wmail_2"] = true
		if GameState.is_penguins():
			send("Mayor Alder", "Welcome to %s, neighbour! What nobody tells new folk: the shops keep seven to nine (the bank eight to five), the community board on the plaza pins paid jobs every morning, and Bram's inn never closes. My office in the hall is always open to you. - Mayor Alder" % town, "news")
		else:
			send("Maple", "Saw a light on at the old plot. The store's open seven till nine: seeds in the back, bread by the door. The board on the plaza pays for errands, no questions asked, and Bram's inn never shuts. Come by. - Maple", "news")
	if day >= 5 and day <= 7 and not flags.has("wmail_5"):
		flags["wmail_5"] = true
		if GameState.is_penguins():
			send("Posy", "Two loaves for the new farmer, still warm when I wrapped them. Eat before you work; Juniper says I'm to tell everyone that. The bakery's open seven till nine. - Posy", "gift", {"npc": "posy", "item": "bread", "n": 2})
		else:
			send("Posy", "Two loaves. Don't argue. You've been out in that field from dawn and you're thinner than when you came. The bakery's open seven till nine. - Posy", "gift", {"npc": "posy", "item": "bread", "n": 2})


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
	_first_week(day)
	RecCenter.morning()
	var known := _known()
	# A favour about every third day, only from people you've met.
	if not known.is_empty() and rng.randf() < 0.35:
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
	if not known.is_empty() and rng.randf() < 0.3:
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
	for id: String in _known():
		var b := GameState.birthday_of(id)
		if b.size() == 2 and str(b[0]) == GameState.season_of(tomorrow) and int(b[1]) == dos:
			send("Wren jr" if id == "pip" else "Pip", "Psst! Tomorrow is %s's birthday. A gift would mean a lot (gifts count triple)." % _name(id), "news")
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
		if (id == "egg" and not Builds.is_built("coop")) or (id in ["milk", "cheese"] and not Builds.is_built("barn")):
			continue  # nothing to get it from yet
		if GameState.items.has(id) and int(GameState.items[id].get("tier", 1)) <= GameState.progress_tier() + 1 and not (id == "starflower" and not GameState.is_penguins()):
			opts.append(id)
	# Eggs and milk only once there's a coop / barn to get them from.
	var basics: Array = ["wood", "stone", "turnip", "copper", "fiber", "potato", "berry"]
	if Builds.is_built("coop"):
		basics.append("egg")
	if Builds.is_built("barn"):
		basics.append("milk")
	for id in basics:
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
## Plays its own cue (pickup for a gift, coin for a paid favour, nope on a refusal).
static func act(m: Dictionary) -> String:
	var err := _act(m)
	var kind := str(m.get("kind", ""))
	if err != "":
		_cue("nope", "thud")
	elif kind == "gift":
		_cue("pickup", "")
	elif kind == "favour":
		_cue("coin", "pickup")
	return err


static func _cue(name: String, fallback: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		Music.instance(tree).sfx(name, fallback)


static func _act(m: Dictionary) -> String:
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
			GameState.add_money(int(m["pay"]), "mail")
			if m.has("npc"):
				GameState.add_friend(str(m["npc"]), 15)
			m["done"] = true
			return ""
	return ""
