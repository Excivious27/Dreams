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
		if int(GameState.run["friendship"].get(id, 0)) > 0 and not Crew.members().has(id) and GameState.npc_present(id) and not (id == "tam" and tam_away()):
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
		out.append_array(after_ending_letters())
	else:
		# The first letter was read (and burned or kept) in the opening; M. writes again next morning.
		if day >= 2 and not flags.has("mail_1"):
			out.append({"flag": "mail_1", "who": "Letter", "text": "A second envelope, same careful hand, three packets of strawberry seed inside: 'Strawberries pay better than turnips, and nobody remembers a strawberry farmer. Maple at the store sells seeds and asks nothing. The man on the bench by the town gate has been places; he's worth a word. Burn this. - M.'", "give": ["strawberry_seed", 3]})
		if day >= 3 and not flags.has("mail_2"):
			out.append({"flag": "mail_2", "who": "Letter", "text": "A man came through town asking about a face like yours. He went east, toward the meadow. Be careful. - M.", "quest": ["clear_meadow", "Someone is asking about you. Check the east meadow."]})
	return out


## C12 c12_02-22: the town writes after the penguin ending (after the end slides were shown),
## one letter at a time: the bell (if it rang), Catkins, and Finn (if you told him).
static func after_ending_letters() -> Array:
	var flags: Dictionary = GameState.run["flags"]
	if not GameState.is_penguins() or not flags.has("epilogue_done") or not flags.has("epilogue_shown"):
		return []
	var all: Array = []
	if flags.has("bell_rung"):
		all.append({"flag": "post_end_alder", "who": "Letter", "text": "The council has voted to ring the bell every morning at nine. Theo says that's too often. Theo is outvoted. Come and pull the rope sometime. - Mayor Alder"})
	all.append({"flag": "post_end_catkins", "who": "Letter", "text": "Celestica's rings are brighter this week. The kittens say it's because of you. I say it's because of you too. - C."})
	if flags.has("finn_told"):
		all.append({"flag": "post_end_finn", "who": "Letter", "text": "Got a letter. You know from who. Thanks. That's all. That's the letter. - Finn"})
	for l: Dictionary in all:
		if not flags.has(str(l["flag"])):
			return [l]
	return []


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
	DecorSources.carpenter_letter(day)  # C10b P1: Tess's workshop opens (day 3)
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
	DecorSources.deliver_orders()  # catalogue orders arrive as parcels (C10a P4)
	_housewarming()
	_ranch_mail(day)
	RanchGift.deliver()  # C11b P3: creature gifts that were waiting for room walk over
	var known := _known()
	# A favour about every third day, only from people you've met.
	if not known.is_empty() and rng.randf() < 0.35:
		var who := str(known[rng.randi() % known.size()])
		var want := _favour_item(who, rng)
		if want != "":
			var n := rng.randi_range(2, 6) if GameState.item_value(want) < 60 else rng.randi_range(1, 2)
			var pay := int(GameState.item_value(want) * n * 1.3) + 10
			if who in KIDS:  # c12_09-19: kids ask small and pay from their savings
				n = mini(n, 2)
				pay = GameState.item_value(want) * n + 5
			send(_name(who), favour_text(who, want, n, pay, 4), "favour", {"npc": who, "item": want, "n": n, "pay": pay, "until": day + 4})
	# Gifts from friends (2+ hearts).
	var friends: Array = []
	for id in known:
		if GameState.friend_hearts(str(id)) >= 2:
			friends.append(id)
	if not friends.is_empty() and rng.randf() < 0.25:
		var who2 := str(friends[rng.randi() % friends.size()])
		var gift := _gift_item(who2, rng)
		# C10a P4: a close friend (6+ hearts) now and then sends a small home piece instead.
		if GameState.friend_hearts(who2) >= int(DECOR_GIFT["hearts"]) and rng.randf() < float(DECOR_GIFT["p"]):
			var dg := Decor.roll(str(DECOR_GIFT["pool"]))
			if dg != "" and not DecorSources.taken(dg) and Decor.rarity_rank(Decor.rarity(dg)) <= Decor.rarity_rank("uncommon"):
				gift = dg
		var note := _pick_line(who2, GIFT_NOTES, rng) if not Decor.is_decor(gift) else _decor_note(rng)
		send(_name(who2), "%s - %s" % [note, _name(who2)], "gift", {"npc": who2, "item": gift, "n": 1})
	# Chatter.
	if not known.is_empty() and rng.randf() < 0.3:
		var who3 := str(known[rng.randi() % known.size()])
		send(_name(who3), _pick_line(who3, CHAT_NOTES, rng) + " - " + _name(who3), "chat", {"npc": who3})
	return list().size() - before


## The favour letter (c12_09-01/19): amounts through Money.amount, kids in their own words.
static func favour_text(who: String, item: String, n: int, pay: int, days: int) -> String:
	var it := "it" if n == 1 or ItemWords.is_mass(GameState.item_name(item)) else "them"
	if who in KIDS:
		return "Can you get me %s? I saved up %s. Send %s with this letter in %d days, PLEASE." % [ItemWords.count_id(item, n), Money.amount(pay), it, days]
	return "Could you spare %s? I'd pay %s, and I'd owe you one. Send %s back with this letter within %d days." % [ItemWords.count_id(item, n), Money.amount(pay), it, days]


## C11b P3 (c11b_10-09): the festival-eve letter announces the Animal Show / Best Egg table,
## only to a farm that keeps animals (the egg table only with a coop; c12_09-03), and
## Bram runs the egg table once the story has sent Posy away (c12_09-04).
static func show_line(fid: String) -> String:
	var pen := GameState.is_penguins()
	if fid == "harvest" and has_animals():
		return (" Benno's judging the Animal Show by the fountain: bring your friendliest grown animal. Bring a crop for the contest too." if pen
			else " Benno's judging the Stock Show by the fountain: bring your best-kept animal. Bring a crop for the contest too.")
	if fid == "egg" and (Builds.is_built("coop") or ranch_source_ok("egg")):
		var host := "Posy" if GameState.npc_present("posy") else "Bram"
		return (" %s's Best Egg table wants your shiniest egg, so save one from the coop." % host if pen
			else " %s's running the Best Egg table: save your best egg from the coop." % host)
	if fid == "lantern" and has_animals():
		var fh := FestivalWords.fest_host("Hazel")  # C12 c12_11-05
		return (" %s's Fleece & Feather table wants your softest wool, fur or feathers." % fh if pen
			else " %s's judging Fleece & Feather by the fountain: soft and clean wins." % fh)
	if fid == "star":
		return (" Everyone gives one gift, and there's a star-wish at the fountain after dark." if pen
			else " Gift swap at the fountain. One each, no regifting.")
	return ""


static func _news(rng: RandomNumberGenerator) -> void:
	var tomorrow := int(GameState.run["day"]) + 1
	var dos := ((tomorrow - 1) % GameState.DAYS_PER_SEASON) + 1
	if dos == GameState.FESTIVAL_DAY:
		var fid: String = str(GameState.FESTIVALS[GameState.season_of(tomorrow)][0])
		send("Mayor Alder", "Reminder: the %s is TOMORROW on the plaza. Shops shut from nine till six so everyone can come. Come hungry!%s" % [GameState.festival_name(fid), show_line(fid)], "news", {"npc": "alder"})
	var w := GameState.weather_for(tomorrow)
	if w == "storm":
		send("Marlowe", "Storm coming in tomorrow; I can see it from the lamp room. %sDon't bother watering. - Marlowe" % _storm_animals(), "news", {"npc": "marlowe"})
	elif w == "blizzard":
		send("Marlowe", "Blizzard coming tomorrow; the sky's gone that flat white. %sStay near a fire. - Marlowe" % _storm_animals(), "news", {"npc": "marlowe"})
	for id: String in _known():
		var b := GameState.birthday_of(id)
		if b.size() == 2 and str(b[0]) == GameState.season_of(tomorrow) and int(b[1]) == dos:
			var tip := _birthday_tipster(id)
			if tip == "":
				send("Mayor Alder", "A note from the hall: tomorrow is %s's birthday. A gift would mean a lot (gifts count triple). - Mayor Alder" % _name(id), "news", {"npc": "alder"})
			else:
				send(_name(tip), "Psst! Tomorrow is %s's birthday. A gift would mean a lot (gifts count triple). - %s" % [_name(id), _name(tip)], "news", {"npc": tip})
	if GameState.DAYS_PER_SEASON - GameState.day_of_season() == 3:
		if GameState.is_penguins():
			send("Hazel", "Three days left of %s. Anything still in the ground that can't take the new season won't make it; harvest what you can. - Hazel" % GameState.season().capitalize(), "news", {"npc": "hazel"})
		else:
			send("Hazel", "Three days left of %s. Whatever can't take the turn of the season won't make it. Pull what you can. - Hazel" % GameState.season().capitalize(), "news", {"npc": "hazel"})
	_heat_letter(rng)
	if GameState.is_penguins() and Colony.saved() < 4 and int(GameState.run["day"]) % 9 == 0 and bool(Colony.st("colony_coral").get("met", false)):
		var bl: String = BRINE_LINES[(int(GameState.run["day"]) / 9) % BRINE_LINES.size()]
		send("Grandmother Brine", bl + " - Grandmother Brine", "news")


const BRINE_LINES := [
	"The islands are dimming. When you have a moment, the ferry waits at the end of the pier.",
	"Another light went out on the far islands last night. The ferry still waits.",
	"The colonies ask after you. The ferry is at the end of the pier when you're ready.",
]


## c12_09-07: one collectors warning per heat spike (flag heat_mail until heat drops
## under 3), from Ladder once he's crew, else Sal; the laundromat only once it's built.
static func _heat_letter(rng: RandomNumberGenerator) -> void:
	var flags: Dictionary = GameState.run["flags"]
	if not Racket.on():
		return
	if Racket.heat() < 3:
		flags.erase("heat_mail")
		return
	if flags.has("heat_mail") or rng.randf() >= 0.6:
		return
	flags["heat_mail"] = int(GameState.run["day"])
	send_heat_letter()


static func send_heat_letter() -> void:
	if Crew.recruited("ladder"):
		if Builds.built_tier("laundromat") > 0:
			send("Ladder", "Collectors on the avenue, boss. Lie low a day or two, or run some bills through the laundromat. - Ladder", "news", {"npc": "ladder"})
		else:
			send("Ladder", "Collectors on the avenue, boss. Lie low a day or two and let it cool. - Ladder", "news", {"npc": "ladder"})
	else:
		send("Sal", "The President's collectors are walking the avenue. Stay off their radar a day or two. - Sal", "news", {"npc": "sal"})


static func _favour_item(who: String, rng: RandomNumberGenerator) -> String:
	var likes: Array = GameState.npcs.get(who, {}).get("likes", [])
	var opts: Array = []
	for l in likes:
		var id := str(l)
		if not _can_get(id):
			continue
		if GameState.items.has(id) and int(GameState.items[id].get("tier", 1)) <= GameState.progress_tier() + 1 and not (id == "starflower" and not GameState.is_penguins()):
			opts.append(id)
	# Eggs and milk only once there's a coop / barn to get them from.
	var basics: Array = ["wood", "stone", "turnip", "copper", "fiber", "potato", "berry"]
	for id in ["egg", "milk"]:
		if ranch_source_ok(id):
			basics.append(id)
	for id in basics:
		if GameState.items.has(id) and GameState.crop_in_season(id):
			opts.append(id)
	return str(opts[rng.randi() % opts.size()]) if not opts.is_empty() else ""


## Can the farmer get this now? Crops only in their season (a 4-day favour can't
## wait for spring); animal goods and hive honey only once they have the source
## (or already hold some).
static func _can_get(id: String) -> bool:
	if GameState.count(id) > 0:
		return true
	if not GameState.crop_in_season(id):
		return false
	if needs_source(id):
		return ranch_source_ok(id)
	return true


## C11a P5: animal goods come from Ranch (data/ranch.json species products + processing).
## Until that data exists (empty ranch.json), today's coop/barn/hive tiers stand in:
## [building, tier]. An empty building = no source on this farm yet (truffle: pigs).
const LEGACY_SOURCE := {"egg": ["coop", 1], "duck_egg": ["coop", 2], "milk": ["barn", 1], "sheep_wool": ["barn", 1],
	"goat_milk": ["barn", 2], "cheese": ["barn", 1], "butter": ["barn", 1], "goat_cheese": ["barn", 2],
	"honey": ["beehive", 1], "truffle": ["", 0]}


## Is this an animal/hive good (only gettable once the farm keeps its source)?
static func needs_source(id: String) -> bool:
	if LEGACY_SOURCE.has(id):
		return true
	return _ranch_goods().has(id)


static func _ranch_goods() -> Dictionary:
	var out := {}
	var d := Ranch.data()
	for sp: String in (d["species"] as Dictionary):
		var pid := str(((d["species"][sp] as Dictionary).get("product", {}) as Dictionary).get("id", ""))
		if pid != "":
			out[pid] = sp
	for pid: String in (d["products"] as Dictionary):
		out[pid] = true
	for pid: String in (d["processing"] as Dictionary):
		out[pid] = true
	return out


## One rule for favours, letters and the board (P1's GameState.board_today can call this).
static func ranch_source_ok(id: String) -> bool:
	if not (Ranch.data()["species"] as Dictionary).is_empty():
		return Ranch.source_ok(id)
	var src: Array = LEGACY_SOURCE.get(id, ["", 0])
	return str(src[0]) != "" and Builds.built_tier(str(src[0])) >= int(src[1])


## Does this farm keep animals at all (roster or a legacy coop/barn)?
static func has_animals() -> bool:
	return not Ranch.animals().is_empty() or Builds.is_built("coop") or Builds.is_built("barn")


## c12_09-10: names only the homes this farm has.
static func _storm_animals() -> String:
	if not has_animals():
		return ""
	var houses: Dictionary = Ranch.st().get("houses", {})
	var coop := Builds.is_built("coop") or houses.has("coop")
	var barn := Builds.is_built("barn") or houses.has("barn")
	if coop and barn:
		return "Your animals will stay in the coop and barn; give them a pet once it's passed. "
	if coop:
		return "Your hens will stay in the coop; give them a pet once it's passed. "
	if barn:
		return "Your animals will stay in the barn; give them a pet once it's passed. "
	return "Your animals will stay indoors; give them a pet once it's passed. "


## Ranch letters (C11a P5): the lead-in (a home for Hazel's hens), welcome letters when the
## coop/barn and their bigger tiers go up, a note on the first egg/milk/wool, Tam's lamb
## (♥8) arriving once the barn has room, and Tam's letters from the highlands after ♥10.
## Flags rmail_* / tam_lamb_* / tam_hl_*.
static func _ranch_mail(day: int) -> void:
	var flags: Dictionary = GameState.run["flags"]
	var pen := GameState.is_penguins()
	if day >= 6 and day <= 14 and not has_animals() and not flags.has("rmail_lead") and intro_ok():
		flags["rmail_lead"] = day
		intro_sent()
		if pen:
			send("Hazel", "My hens have gone and hatched more chicks than I've room for. Put up a coop and they're yours: the Plans board by your house, wood and stone, or I'll build it for you. Pet them of a morning and they'll lay every day. - Hazel", "news", {"npc": "hazel"})
		else:
			send("Benno", "Heard the old plot's got a new owner and no hens. Put up a coop (Plans board, by your door) and I'll find you some. Fresh eggs sell clean, no questions. - Benno", "news", {"npc": "benno"})
	for row: Array in RANCH_LETTERS:
		var fk := "rmail_%s_%d" % [row[0], row[1]]
		if flags.has(fk) or Builds.built_tier(str(row[0])) < int(row[1]):
			continue
		flags[fk] = day
		var who := str(row[2]) if pen or row.size() < 8 else str(row[7])  # [7]: the gangster-arc sender
		var text := str(row[3] if pen else row[4])
		if not pen and str(row[0]) == "coop" and int(row[1]) == 1 and not flags.has("rmail_lead"):
			text = COOP_NO_LEAD_GANG  # c12_09-17: no "Told you" without Benno's lead letter
		var alt_key := "%s_%d" % [row[0], row[1]]
		if not GameState.npc_present(who) and RANCH_ALT.has(alt_key):  # c12_09-04: Posy sent away
			var alt: Array = RANCH_ALT[alt_key]
			who = str(alt[0] if pen else alt[1])
			text = str(alt[2] if pen else alt[3])
		send(_name(who), "%s - %s" % [text, _name(who)], "gift", {"npc": who, "item": str(row[5]), "n": int(row[6])})
		break  # one welcome a morning
	for row: Array in FIRST_GOODS:
		var item := str(row[0])
		var fk2 := "rmail_first_" + item
		if flags.has(fk2) or not _made(item):
			continue
		flags[fk2] = day
		var who2 := str(row[1])
		var text2 := str(row[2] if pen else row[3])
		if not GameState.npc_present(who2) and FIRST_ALT.has(item):
			var alt2: Array = FIRST_ALT[item]
			who2 = str(alt2[0])
			text2 = str(alt2[1] if pen else alt2[2])
		send(_name(who2), "%s - %s" % [text2, _name(who2)], "chat", {"npc": who2})
		break
	_tam_lamb(day)
	_tam_highlands(day)


## [building, tier, villager, penguin text, gangster text, gift item, n, (gangster villager)]
const RANCH_LETTERS := [
	["coop", 1, "hazel", "Your hens are settled; I walked them up myself. They like a pet first thing and a full feeder. Hay's on me this once.", "Your hens are in. Told you I'd find some. Pet them mornings, keep the feeder full, and they'll pay their way. Hay's on me this once.", "hay", 3, "benno"],
	["barn", 1, "benno", "The barn smells right already. Brush them, talk to them, keep the trough full; the rest is patience. Some hay to start you off.", "Barn's up. Animals don't care who you work for: feed them, pet them, and the milk comes. Hay to start.", "hay", 5],
	["coop", 2, "posy", "A bigger coop! If any duck eggs come your way, I'll trade you a cake for every one. Here's an egg for luck.", "Bigger coop, I hear. Duck eggs make the best cakes in town and I don't say that lightly. An egg for luck.", "egg", 1],
	["barn", 2, "tam", "Goats now. They'll eat the fence, the gate and your hat. Worth it for the milk. Wool for the bedding.", "Goats. They'll eat everything you own. Worth it for the milk. Wool for the bedding.", "sheep_wool", 2],
]
const COOP_NO_LEAD_GANG := "Your hens are in. Found you some through a friend. Pet them mornings, keep the feeder full, and they'll pay their way. Hay's on me this once."
## When a letter's sender has left town (story *_gone): "<building>_<tier>": [penguin sender, gangster sender, penguin text, gangster text].
const RANCH_ALT := {
	"coop_2": ["hazel", "benno", "A bigger coop! Ducks next, then. Posy always said a duck egg makes the best cake in the valley. Here's an egg for luck.", "Bigger coop. Ducks lay richer than hens; the kitchens on the avenue pay for that. An egg for luck."],
}
## item: [sender, penguin text, gangster text]
const FIRST_ALT := {
	"egg": ["hazel", "First eggs! Keep the best for the fair and sell the rest; they never sit long.", "First eggs. They sell before they're cold. Keep one back for the fair."],
}
## [item, villager, penguin text, gangster text]: the first time the farm makes one.
const FIRST_GOODS := [
	["egg", "posy", "Hazel says your hens are laying! Bring me eggs whenever you've spare and I'll show you what a proper sponge looks like.", "First eggs off your farm, I hear. Bring me the spares; the bakery goes through dozens."],
	["milk", "hazel", "First milk! Leave it in the press overnight and you'll have cheese by morning. That's the whole secret, and don't let anyone tell you otherwise.", "First milk. The press turns it to cheese overnight; cheese keeps and sells better. You're welcome."],
	["sheep_wool", "tam", "First fleece. Don't wash it in the river; the river doesn't need it and neither do you. The loom's where it wants to go.", "First fleece. Loom's where it wants to go. Sheep don't care who buys the sweater."],
]


## Has the farm made this good yet? (Ranch roster: an animal of a species whose product it is
## has made something; before ranch.json data: holding one with its source built.)
static func _made(item: String) -> bool:
	var goods := _ranch_goods()
	if goods.has(item) and goods[item] is String:
		for uid: String in Ranch.animals():
			var a: Dictionary = Ranch.animals()[uid]
			if str(a.get("species", "")) == str(goods[item]) and int(a.get("made_day", -1)) >= 0:
				return true
	return ranch_source_ok(item) and GameState.count(item) > 0


## Tam's ♥8 lamb: she moves into the barn as soon as there is room (Ranch.add), marked as a
## keepsake so she can't be rehomed; until then one letter says she's waiting at his hut.
static func _tam_lamb(day: int) -> void:
	var flags: Dictionary = GameState.run["flags"]
	if not flags.has("hv_tam_8") or flags.has("tam_lamb_home"):
		return
	var opts := {"home": "barn", "name": "Bramble", "keepsake": true, "giver": "Tam"}
	var uid := RanchGift._try("sheep", opts)  # a promise: may go one over a full barn (c11b_04-12)
	if uid != "":
		flags["tam_lamb_home"] = uid
		if tam_away():  # c12_09-05: he's on the hills, so Benno walks her up
			send("Tam", ("Benno brought Bramble up for me; I'm still on the hills. She's in your barn now. Name her what you like. - Tam" if GameState.is_penguins()
				else "Had Benno walk Bramble up while I'm on the hills. She's in your barn. She answers to nobody. - Tam"), "chat", {"npc": "tam"})
		else:
			send("Tam", ("Brought Bramble up at first light. She's in your barn, eating something she shouldn't. Name her what you like; she won't answer to it either way. - Tam" if GameState.is_penguins()
				else "Brought Bramble up at first light. She's in your barn. Call her what you like; she answers to nobody. - Tam"), "chat", {"npc": "tam"})
	elif not flags.has("tam_lamb_wait"):
		flags["tam_lamb_wait"] = day
		send("Tam", "Bramble's waiting at my hut till there's room for her: she needs %s. She's eaten another hat. No hurry. Some hurry. - Tam" % RanchGift.room_hint("sheep", opts), "chat", {"npc": "tam"})


## After ♥10 Tam writes from the highlands, about once a week, four letters.
const TAM_LETTERS := [
	"Made the top pass. Snow to the knee and the Dollys complaining about it in harmony. Wool's thicker up here. So's the quiet.",
	"How's %s? Is she eating the fence yet? She will. Give her a pet from me; she won't know it's from me, which is the point.",
	"Met a herd of shaggy cattle up here with horns like coat racks. They looked at me like I was the odd one. Fair.",
	"Coming down for the Harvest Fair. Bring %s; I want to see if she's grown into her ears. Keep a light on.",
]
## Letter 2 while Bramble still waits at his hut; letter 4 when it's winter, not fall.
const TAM_LAMB_WAITING := "Is Bramble behaving at the hut? Benno's watching her till your barn has room. She won't be behaving."
const TAM_WINTER := "Snowed in up here; I'll be down for the Star Festival instead. Bring %s. Keep a light on."


## Tam is up in the highlands: from his ♥10 scene until his fourth letter (he comes down
## for the festival). He sends no favours/chatter and isn't in town meanwhile (c12_09-05).
static func tam_away() -> bool:
	if GameState.run.is_empty():
		return false
	var flags: Dictionary = GameState.run.get("flags", {})
	return flags.has("hv_tam_10") and int(flags.get("tam_hl_n", 0)) < TAM_LETTERS.size()


static func _tam_highlands(day: int) -> void:
	var flags: Dictionary = GameState.run["flags"]
	if not flags.has("hv_tam_10"):
		return
	var n := int(flags.get("tam_hl_n", 0))
	if n >= TAM_LETTERS.size():
		return
	if not flags.has("tam_hl_day"):
		flags["tam_hl_day"] = day  # he's only just left: the first letter comes a week on
		return
	if day - int(flags["tam_hl_day"]) < 7:
		return
	var text := str(TAM_LETTERS[n])
	if n == TAM_LETTERS.size() - 1:
		# c12_09-06: the last letter waits for the week before a festival he can come down for.
		var se := GameState.season_of(day)
		var dos := (day - 1) % GameState.DAYS_PER_SEASON + 1
		if dos < 7 or dos >= GameState.FESTIVAL_DAY or not (se in ["fall", "winter"]):
			return
		if se == "winter":
			text = TAM_WINTER
	elif n == 1 and not flags.has("tam_lamb_home") and flags.has("hv_tam_8"):
		text = TAM_LAMB_WAITING
	flags["tam_hl_n"] = n + 1
	flags["tam_hl_day"] = day
	if "%s" in text:
		text = text % lamb_name()
	send("Tam", text + " - Tam", "chat", {"npc": "tam"})


## The lamb's name as the player has it now (renamed on the Animals page) or Bramble.
static func lamb_name() -> String:
	var uid := str(GameState.run["flags"].get("tam_lamb_home", ""))
	var nm := str(Ranch.animal(uid).get("name", "")) if uid != "" else ""
	return nm if nm != "" else "Bramble"


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
	"tam": ["The Dollys found this. They voted, and it's for you.", "From the hills. Sheep don't send presents, so I have to."],
	"benno": ["From the stable. The grey mare picked it out; don't argue with her.", "Found this in the tack room. Better with you than the mice."],
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
	"tam": ["Dolly got out again. All of them did. They're back. They want you to know they're not sorry."],
	"benno": ["The grey mare threw a shoe and looked pleased about it. Horses. Come by the stable some morning."],
	"#kid": ["I saw a frog THIS big. Come and look before it leaves.", "Can you come and play? Not now. Later. When you're done farming.", "I drew your farm. The sky is purple. It's art."],
	"#all": ["The weather's turned and the whole town's talking about it. How's the farm?", "I saw your lights on late. Get some sleep, will you?", "If you're passing, drop in. The kettle's always on.", "Someone left flowers on the fountain this morning. Was it you?", "I've been meaning to say: it's good having you here.", "The market was busy today. You should bring something to sell."],
}


## The gangster arc's grown-up pools (c12_09-12): the cosy penguin lines stay in the penguin arc.
const GIFT_NOTES_GANG := ["Fell off a truck. Kidding. Mostly.", "Had one spare. Now you do. Don't mention it.", "For the farm. Somebody on this street should be doing honest work."]
const CHAT_NOTES_GANG := ["Avenue's quiet tonight. That's either good or bad. How's the farm?", "Saw your lights on late. Get some sleep. The city keeps going without you.", "If you're passing, the door's open. Knock twice.", "Somebody painted over the tags on the fountain. Was that you?", "The market was busy today. Real money, honest goods. Bring something."]
## Villager lines that only fit the penguin arc's cosy town.
const PEN_ONLY_NOTES := ["The bent turnip packet is still on the counter. People ask. I say it's a long story."]
## Decor gift notes (c12_09-13): a villager's own food/ore notes don't fit a lamp.
const DECOR_NOTES := ["This was cluttering my place and it'll look better in yours.", "Saw this and pictured it in your farmhouse.", "For the house. Put it somewhere you'll see it."]
const DECOR_NOTES_GANG := ["For your place. Makes it look lived in.", "Saw this and pictured it in your place. Don't ask where it came from."]


static func _decor_note(rng: RandomNumberGenerator) -> String:
	var pool: Array = DECOR_NOTES if GameState.is_penguins() else DECOR_NOTES_GANG
	return str(pool[rng.randi() % pool.size()])


## A line for this villager, never the same one they sent last time (flags.mail_last).
static func _pick_line(who: String, pool: Dictionary, rng: RandomNumberGenerator) -> String:
	var opts: Array = (pool.get(who, []) as Array).duplicate()
	if not GameState.is_penguins():
		for l in PEN_ONLY_NOTES:
			opts.erase(l)
		if who in KIDS:
			opts.append_array(pool["#kid"])
		else:
			opts.append_array(GIFT_NOTES_GANG if pool.has("posy") else CHAT_NOTES_GANG)  # GIFT_NOTES has posy, CHAT_NOTES not
	else:
		opts.append_array(pool["#kid"] if who in KIDS else pool["#all"])
	if not GameState.run["flags"].has("mail_last"):
		GameState.run["flags"]["mail_last"] = {}
	var last: Dictionary = GameState.run["flags"]["mail_last"]
	if opts.size() > 1:
		opts.erase(str(last.get(who, "")))
	var pick := str(opts[rng.randi() % opts.size()])
	last[who] = pick
	return pick


## A bigger farmhouse gets a housewarming parcel once per tier (decor.json grants
## "house:<tier>", c10_06): the town chips in for the new rooms.
static func _housewarming() -> void:
	var t := Builds.built_tier("house")
	for tier in range(2, t + 1):
		var fk := "house_warm_%d" % tier
		var id := DecorSources.granted_for("house:%d" % tier)
		if id == "" or GameState.run["flags"].has(fk) or DecorSources.taken(id):
			continue
		GameState.run["flags"][fk] = true
		var who := "Hazel" if GameState.is_penguins() else "The crew"
		send(who, "New rooms deserve something in them. From all of us: %s. - %s" % [DecorSources.name_of(id), who], "gift", {"item": id, "n": 1})


## Friend letters that carry a decor piece (decor.json pool "mail"; common/uncommon only).
const DECOR_GIFT := {"hearts": 6, "p": 0.125, "pool": "mail"}


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
			if Decor.is_decor(str(m["item"])):
				DecorSources.grant(null, str(m["item"]), int(m.get("n", 1)), "mail")  # decor box, not the bag (C10a)
			else:
				GameState.add_item(str(m["item"]), int(m.get("n", 1)))
			return ""
		"favour":
			if bool(m.get("done", false)):
				return "That's done." if not bool(m.get("lapsed", false)) else "Too late: they found it elsewhere."
			var id := str(m["item"])
			var n := int(m["n"])
			if DecorSources.keeps(id):
				return DecorSources.KEEP_LINE
			if GameState.count(id) < n:
				return "You need %s (you have %d)." % [ItemWords.count_id(id, n), GameState.count(id)]
			GameState.add_item(id, -n)
			GameState.add_money(int(m["pay"]), "mail")
			if m.has("npc"):
				GameState.add_friend(str(m["npc"]), 15)
			m["done"] = true
			return ""
	return ""
