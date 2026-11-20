class_name TownHours
extends RefCounted
## Opening hours of every town door (conduct 1, c1_11). Shops lock their front
## door outside hours, with a sign that says when they open; homes stop
## answering late at night unless you're good friends with someone who lives
## there (4+ hearts, Stardew-style); the inn and the chapel never close. The
## shop counters (Interior._counter) and the crew-shop "closed" fronts
## (Town._gang) read the same table, so the sign, the door and the till agree.

## interior id -> [open hour, close hour, sign name]. Close may pass midnight
## (24+). Kind "home" doors use HOME_OPEN/HOME_CLOSE.
const SHOPS := {
	"store": [7, 21, "Maple's General Store"],
	"smith": [7, 21, "Gideon's Forge"],
	"potions": [7, 21, "Wren's Potion Shop"],
	"bakery": [7, 21, "Posy's Bakery"],
	"hall": [7, 21, "Town Hall"],
	"clinic": [7, 21, "Clinic"],
	"library": [8, 20, "Library"],
	"bank": [8, 17, "Bank"],
	"stable": [7, 21, "Stable"],
	"lodge": [7, 21, "Rook's lodge"],
	"school": [7, 18, "School"],
}
const ALWAYS := ["inn", "chapel", "rec", "rec_up", "interior"]
const HOMES := {
	"mansion": ["alder"], "cottage_a": ["wren", "wren_jr"], "cottage_b": ["finn"], "cottage_c": ["lumi", "theo"],
	"hazel_house": ["hazel", "mabel"],
}
## Gangster-arc crew shops that took over a town building (door labels).
const CREW_SHOPS := ["Deuce's arcade", "Mama Rosa's kitchen", "Specs' net cafe", "Halo's garage", "Doc's back-room clinic", "Marlene's trading post"]
const HOME_OPEN := 7
const HOME_CLOSE := 22
const FRIEND_HEARTS := 4
## Good friends (FRIEND_HEARTS+) let you in late, until midnight (Tom, Guide 26 #16).
const FRIEND_CLOSE := 24


static func _hour() -> float:
	return (int(GameState.run.get("time", 8 * 60)) % 1440) / 60.0


static func _within(h: float, a: float, b: float) -> bool:
	if b > 24.0:
		return h >= a or h < b - 24.0
	return h >= a and h < b


static func hours_text(a: int, b: int) -> String:
	return "%s to %s" % [_clock(a), _clock(b % 24)]


static func _clock(h: int) -> String:
	if h == 0:
		return "midnight"
	if h == 12:
		return "noon"
	return "%d%s" % [h if h <= 12 else h - 12, "am" if h < 12 else "pm"]


## Is this shop serving right now? (Festival days close it 9am to 6pm, except the hall.)
static func shop_open(shop: String) -> bool:
	return why_shut(shop) == ""


## "" when the shop serves now, else the sign on the door.
static func why_shut(shop: String) -> String:
	if not SHOPS.has(shop):
		return ""
	var s: Array = SHOPS[shop]
	var h := _hour()
	if not _within(h, float(s[0]), float(s[1])):
		return "%s: closed. Open %s." % [str(s[2]), hours_text(int(s[0]), int(s[1]))]
	if shop != "hall" and GameState.festival_today() != "" and h >= 9.0 and h < 18.0:
		return "%s: closed today. Everyone's at the %s on the plaza." % [str(s[2]), GameState.festival_name(GameState.festival_today())]
	return ""


## The till's answer for any counter ("" = serving). Region keepers (Finn's
## bait, Orla, Marlowe...) keep the ordinary 7am-9pm day.
static func counter_shut(shop: String) -> String:
	if shop == "":
		return ""
	if SHOPS.has(shop):
		return why_shut(shop)
	var h := _hour()
	if not _within(h, 7.0, 21.0):
		return "Closed for the night. Open %s." % hours_text(7, 21)
	if GameState.festival_today() != "" and h >= 9.0 and h < 18.0:
		return "Closed today: everyone's at the %s on the plaza." % GameState.festival_name(GameState.festival_today())
	return ""


## The reason a town door won't open right now, or "".
static func door_reason(interior: String, label := "") -> String:
	if label in CREW_SHOPS:
		# A crew shop in a taken building keeps shop hours, like its "closed" front (Town._gang).
		if _within(_hour(), 7.0, 21.0):
			return ""
		return "%s: shutters down. Open %s." % [label, hours_text(7, 21)]
	if interior in ALWAYS or interior == "":
		return ""
	if SHOPS.has(interior):
		return why_shut(interior)
	if HOMES.has(interior):
		if _within(_hour(), HOME_OPEN, HOME_CLOSE):
			return ""
		var nm := label if label != "" else interior.capitalize()
		if late_friend(interior) != "":
			return ""  # a good friend is still up
		if _within(_hour(), HOME_OPEN, FRIEND_CLOSE):
			return "%s: the lights are low. Only close friends knock this late; come back after %s." % [nm, _clock(HOME_OPEN)]
		return "%s: the lights are out. Too late to knock; come back after %s." % [nm, _clock(HOME_OPEN)]
	return ""


## The good friend (4+ hearts) who lets you into their home after hours, or "".
static func late_friend(interior: String) -> String:
	if not HOMES.has(interior) or _within(_hour(), HOME_OPEN, HOME_CLOSE) or not _within(_hour(), HOME_OPEN, FRIEND_CLOSE):
		return ""
	for id: String in HOMES[interior]:
		if GameState.friend_hearts(id) >= FRIEND_HEARTS:
			return id
	return ""


## Town hook: stop at a closed door with its sign. True when it stopped you.
static func door_closed(m: GameMap, thing: Dictionary) -> bool:
	var id := str(thing.get("interior", thing.get("shop", "hall")))
	var label := str(thing.get("hint", "")).trim_prefix("A: ")
	var why := door_reason(id, label)
	var pal := late_friend(id)
	if why == "" and pal != "":
		m.hud.toast("%s is still up and waves you in." % str(GameState.npcs.get(pal, {}).get("name", pal.capitalize())), Color(1, 0.9, 0.75))
	if why == "":
		return false
	m.hud.toast(why, Color(1, 0.85, 0.7))
	Music.instance(m.get_tree()).sfx("locked", "thud")
	return true
