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
## C9: "a new place opened" letters (Rec opening, mega keepers' invitations; the
## community farm letter can join) land at most this many per day, so a save
## from before those systems isn't buried under them on its first morning.
const INTROS_PER_DAY := 2


## May another system-intro letter go out today? (Callers send it, then call intro_sent.)
static func intro_ok() -> bool:
	if GameState.run.is_empty():
		return false
	var f: Dictionary = GameState.run.get("flags", {})
	return int(f.get("intro_day", -1)) != int(GameState.run.get("day", 1)) or int(f.get("intro_n", 0)) < INTROS_PER_DAY


static func intro_sent() -> void:
	var f: Dictionary = GameState.run["flags"]
	var day := int(GameState.run.get("day", 1))
	if int(f.get("intro_day", -1)) != day:
		f["intro_day"] = day
		f["intro_n"] = 0
	f["intro_n"] = int(f["intro_n"]) + 1


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
## A letter sent outside the morning post (a keeper's invitation on arrival,
## Granite's floor-100 note) says so on the HUD: morning letters already get the
## morning toast and the mailbox marker.
static func send(from: String, text: String, kind := "chat", extra := {}, notify := true) -> void:
	var m := {"id": "%d_%d" % [int(GameState.run["day"]), list().size() + randi() % 1000], "day": int(GameState.run["day"]), "from": from, "text": text, "kind": kind, "read": false}
	m.merge(extra, true)
	list().append(m)
	_trim()
	if notify and not _morning_post and not GameState.run.is_empty():
		GameMap.notify("A letter from %s is waiting in your mailbox." % from.split(" at ")[0], "j_page")


static var _morning_post := false


## Only settled letters are dropped when the box is full: never an unread letter,
## an untaken gift or an open favour (the box may run a little over instead).
static func _trim() -> void:
	var l := list()
	while l.size() > MAX_KEEP:
		var drop := -1
		for i in l.size():
			if _settled(l[i]):
				drop = i
				break
		if drop < 0:
			return
		l.remove_at(drop)


static func _settled(m: Dictionary) -> bool:
	if not bool(m.get("read", false)):
		return false
	match str(m.get("kind", "")):
		"gift":
			return bool(m.get("got", false))
		"favour":
			return bool(m.get("done", false))
	return true


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
			out.append({"flag": "mail_2", "who": "Letter", "text": "Dear neighbour, something has been howling from the east meadow at night. Mayor Alder says it's nothing. It is not nothing. - Wren", "quest": ["clear_meadow", "Find out what's howling in the east meadow."]})
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
			send("Mayor Alder", "Welcome to %s, neighbour! What nobody tells new folk: the shops keep seven to nine (the bank eight to five), the community board on the plaza pins paid jobs every morning, and Bram's inn never closes. My office in the hall is open whenever the shops are. - Mayor Alder" % town, "news")
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
	_morning_post = true
	var got := _morning()
	_morning_post = false
	return got


static func _morning() -> int:
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
	Collections.morning()  # museum opening, donation thanks, milestone letters (C8 P3)
	var known := _known()
	# A favour about every third day, only from people you've met.
	if not known.is_empty() and rng.randf() < 0.35:
		var who := str(known[rng.randi() % known.size()])
		var want := _favour_item(who, rng)
		if want != "":
			var n := rng.randi_range(2, 6) if GameState.item_value(want) < 60 else rng.randi_range(1, 2)
			var pay := int(GameState.item_value(want) * n * 1.3) + 10
			send(_name(who), "Could you spare %s? I'd pay ◆%d, and I'd owe you one. Send %s back with this letter within %d days." % [ItemWords.count_id(want, n), pay, "it" if n == 1 or ItemWords.is_mass(GameState.item_name(want)) else "them", 4], "favour", {"npc": who, "item": want, "n": n, "pay": pay, "until": day + 4})
	# Gifts from friends (2+ hearts).
	var friends: Array = []
	for id in known:
		if GameState.friend_hearts(str(id)) >= 2:
			friends.append(id)
	if not friends.is_empty() and rng.randf() < 0.25:
		var who2 := str(friends[rng.randi() % friends.size()])
		var gift := _gift_item(who2, rng)
		send(_name(who2), "%s - %s" % [_pick_line(who2, GIFT_NOTES, rng), _name(who2)], "gift", {"npc": who2, "item": gift, "n": 1})
	# Chatter.
	if not known.is_empty() and rng.randf() < 0.3:
		var who3 := str(known[rng.randi() % known.size()])
		send(_name(who3), _pick_line(who3, CHAT_NOTES, rng) + " - " + _name(who3), "chat", {"npc": who3})
	return list().size() - before


static func _news(rng: RandomNumberGenerator) -> void:
	var tomorrow := int(GameState.run["day"]) + 1
	var dos := ((tomorrow - 1) % GameState.DAYS_PER_SEASON) + 1
	if dos == GameState.FESTIVAL_DAY:
		var fid: String = str(GameState.FESTIVALS[GameState.season_of(tomorrow)][0])
		send("Mayor Alder", "Reminder: the %s is TOMORROW on the plaza. Shops shut from nine till six so everyone can come. Come hungry!" % GameState.festival_name(fid), "news", {"npc": "alder"})
	var w := GameState.weather_for(tomorrow)
	if w == "storm":
		send("Marlowe", "Storm coming in tomorrow; I can see it from the lamp room. Bring the animals in and don't bother watering. - Marlowe", "news", {"npc": "marlowe"})
	elif w == "blizzard":
		send("Marlowe", "Blizzard coming tomorrow; the sky's gone that flat white. Bring the animals in and stay near a fire. - Marlowe", "news", {"npc": "marlowe"})
	for id: String in _known():
		var b := GameState.birthday_of(id)
		if b.size() == 2 and str(b[0]) == GameState.season_of(tomorrow) and int(b[1]) == dos:
			var tip := _birthday_tipster(id)
			if tip == "":
				send("Mayor Alder", "A note from the hall: tomorrow is %s's birthday. A gift would mean a lot (gifts count triple). - Mayor Alder" % _name(id), "news", {"npc": "alder"})
			else:
				send(_name(tip), "Psst! Tomorrow is %s's birthday. A gift would mean a lot (gifts count triple). - %s" % [_name(id), _name(tip)], "news", {"npc": tip})
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
		if not _can_get(id):
			continue
		if GameState.items.has(id) and int(GameState.items[id].get("tier", 1)) <= GameState.progress_tier() + 1 and not (id == "starflower" and not GameState.is_penguins()):
			opts.append(id)
	# Eggs and milk only once there's a coop / barn to get them from.
	var basics: Array = ["wood", "stone", "turnip", "copper", "fiber", "potato", "berry"]
	if Builds.is_built("coop"):
		basics.append("egg")
	if Builds.is_built("barn"):
		basics.append("milk")
	for id in basics:
		if GameState.items.has(id) and GameState.crop_in_season(id):
			opts.append(id)
	return str(opts[rng.randi() % opts.size()]) if not opts.is_empty() else ""


## Can the farmer get this now? Crops only in their season (a 4-day favour can't
## wait for spring); animal goods and hive honey only once they have the source
## (or already hold some).
const NEEDS_SOURCE := {"sheep_wool": "", "goat_milk": "", "duck_egg": "", "truffle": "", "honey": "beehive", "cheese": "barn", "butter": "barn", "mayo": "coop"}


static func _can_get(id: String) -> bool:
	if GameState.count(id) > 0:
		return true
	if not GameState.crop_in_season(id):
		return false
	if NEEDS_SOURCE.has(id):
		var b := str(NEEDS_SOURCE[id])
		return b != "" and Builds.is_built(b)
	return true


## Who tips you off about a birthday: Pip or Wren jr if you know them and they're
## around (not the birthday kid), else any other villager you know, else "".
static func _birthday_tipster(id: String) -> String:
	var known := _known()
	for k in ["pip", "wren_jr"]:
		if k != id and k in known:
			return k
	for k in known:
		if str(k) != id and str(k) != "catkins":
			return str(k)
	return ""


const KIDS := ["pip", "wren_jr", "tobin", "mabel"]
## Gift and chatter notes: a villager's own lines plus the kids' or the grown-ups' pool.
const GIFT_NOTES := {
	"maple": ["Came in with the last delivery and it had your name on it. Not literally. Don't argue."],
	"gideon": ["Here.", "Found it at the back of the forge. Better with you."],
	"wren": ["This was going spare. It wasn't, but take it."],
	"alder": ["With the compliments of the hall. And mine, which count for more."],
	"sal": ["Saw this. Thought of you. That's the whole story."],
	"finn": ["Off the end of the jetty this morning. Well, near it."],
	"hazel": ["From the cellar. There's more where it came from, which is the point of a cellar."],
	"bram": ["The kitchen had one over. The kitchen always has one over for you."],
	"posy": ["Wrapped it twice so it'd travel. Enjoy it, and don't tell me if you didn't."],
	"juniper": ["Take this. Doctor's orders. Mostly a friend's orders."],
	"granite": ["Out of the quarry. Thought you'd know what to do with it."],
	"marlowe": ["Washed up under the lamp. The sea sends you its regards."],
	"#kid": ["I found this and it's for YOU. Don't tell anyone I'm nice.", "This is a present. You have to say thank you next time you see me."],
	"#all": ["Found this and thought of you. Don't make a fuss.", "A little something. It made me think of your farm.", "Had one spare. Now you do."],
}
const CHAT_NOTES := {
	"maple": ["The bent turnip packet is still on the counter. People ask. I say it's a long story."],
	"gideon": ["Forge is hot. Come by. That's the letter."],
	"wren": ["The plants are doing well. So, I hear, are you. Keep it up."],
	"alder": ["The fee ledger balanced on the first try this week. I thought you should know."],
	"bram": ["Stew on all day tomorrow. The corner seat's yours."],
	"marlowe": ["Clear night last night. You could see every star from the lamp room. Thought of you down there, working."],
	"#kid": ["I saw a frog THIS big. Come and look before it leaves.", "Can you come and play? Not now. Later. When you're done farming.", "I drew your farm. The cow is purple. It's art."],
	"#all": ["The weather's turned and the whole town's talking about it. How's the farm?", "I saw your lights on late. Get some sleep, will you?", "If you're passing, drop in. The kettle's always on.", "Someone left flowers on the fountain this morning. Was it you?", "I've been meaning to say: it's good having you here.", "The market was busy today. You should bring something to sell."],
}


## A line for this villager, never the same one they sent last time (flags.mail_last).
static func _pick_line(who: String, pool: Dictionary, rng: RandomNumberGenerator) -> String:
	var opts: Array = (pool.get(who, []) as Array).duplicate()
	opts.append_array(pool["#kid"] if who in KIDS else pool["#all"])
	if not GameState.run["flags"].has("mail_last"):
		GameState.run["flags"]["mail_last"] = {}
	var last: Dictionary = GameState.run["flags"]["mail_last"]
	if opts.size() > 1:
		opts.erase(str(last.get(who, "")))
	var pick := str(opts[rng.randi() % opts.size()])
	last[who] = pick
	return pick


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
				return "You need %s (you have %d)." % [ItemWords.count_id(id, n), GameState.count(id)]
			GameState.add_item(id, -n)
			GameState.add_money(int(m["pay"]), "mail")
			if m.has("npc"):
				GameState.add_friend(str(m["npc"]), 15)
			m["done"] = true
			return ""
	return ""
