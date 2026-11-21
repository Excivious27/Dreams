class_name RanchGift
extends RefCounted
## C11b P3: the one path that grants a ranch animal from data (quest rewards {"animal": [species, giver]},
## colony restores, boss nests, story letters). give() adds the animal when its home has room; a keepsake
## (a promised story gift) may go one place over capacity, like migration does. Otherwise the gift waits in
## run.ranch.pending and ONE letter says exactly what makes room; deliver() (each morning, Mail) brings it.
## Species not in data/ranch.json yet (C11b exotics land with P1's rows) also wait, never vanish.

const KEY := "pending"
## Arc of the C11b creatures before their ranch.json rows exist (art lane table): fantastic = penguins, lab = gangsters.
const PEN_ONLY := ["aurora_fox", "cloud_sheep", "coral_seahorse", "crystal_hen", "deep_glowworm", "ember_newt", "frost_otter",
	"frost_wyrmling", "glow_gecko", "kelp_calf", "lantern_moth", "moon_cow", "moon_hare", "star_jelly", "star_sheep", "storm_roc"]
const GANG_ONLY := ["chrome_hen", "chrome_runner", "circuit_cow", "circuit_goat", "drone_hog", "glow_sheep", "turbo_bunny", "volt_gecko"]


## Can this arc keep the species? (ranch.json "arc" when known, else the C11b tables above.)
static func arc_ok(species: String) -> bool:
	var arc := str(GameState.run.get("arc", ""))
	var sp := Ranch.species(species)
	if not sp.is_empty():
		return str(sp.get("arc", "")) in ["", "both", arc]
	if species in PEN_ONLY:
		return arc == "penguins"
	if species in GANG_ONLY:
		return arc == "gangsters"
	return true


static func pending() -> Array:
	var d := Ranch.st()
	if not (d.get(KEY, null) is Array):
		d[KEY] = []
	return d[KEY]


## Give one animal. opts: name, keepsake (bool), giver (letter sender), home (override), variant.
## Returns the new uid, or "" when the gift is waiting (a letter went out).
static func give(species: String, source: String, opts: Dictionary = {}) -> String:
	if species == "" or given(source) or not arc_ok(species):
		return ""
	var uid := _try(species, opts)
	_mark(source)
	if uid != "":
		_arrived(species, uid, opts, false)
		return uid
	var row := {"species": species, "source": source, "day": int(GameState.run.get("day", 1))}
	for k in ["name", "keepsake", "giver", "home", "variant"]:
		if opts.has(k):
			row[k] = opts[k]
	pending().append(row)
	_waiting_letter(row)
	return ""


## A reward row {"animal": [species, giver, keepsake?], "gift_key": "mega:sunscorch_rahim"} (GameState._give_reward).
static func from_reward(rw: Dictionary) -> String:
	var k := "animal_gang" if GameState.run.get("arc", "") == "gangsters" and rw.has("animal_gang") else "animal"
	var a: Array = rw[k] if rw.get(k, null) is Array else [str(rw.get(k, ""))]
	if a.is_empty():
		return ""
	var opts := {}
	if a.size() > 1 and str(a[1]) != "":
		opts["giver"] = str(a[1])
	if a.size() > 2:
		opts["keepsake"] = bool(a[2])
	return give(str(a[0]), str(rw.get("gift_key", "reward:" + str(a[0]))), opts)


## Has a source already given its animal (once per run)?
static func given(source: String) -> bool:
	return source != "" and ((Ranch.st().get("gift_src", {}) as Dictionary) if Ranch.st().get("gift_src", null) is Dictionary else {}).has(source)


static func _mark(source: String) -> void:
	if source == "":
		return
	var d := Ranch.st()
	if not (d.get("gift_src", null) is Dictionary):
		d["gift_src"] = {}
	(d["gift_src"] as Dictionary)[source] = int(GameState.run.get("day", 1))


static func home_of(species: String, opts: Dictionary = {}) -> String:
	if str(opts.get("home", "")) != "":
		return str(opts["home"])
	return str(Ranch.species(species).get("home", ""))


static func _try(species: String, opts: Dictionary) -> String:
	if Ranch.species(species).is_empty():
		return ""
	var h := home_of(species, opts)
	var nm := str(opts.get("name", ""))
	var uid := Ranch.add(species, h, nm)
	if uid == "" and bool(opts.get("keepsake", false)) and h != "" and Ranch.capacity(h) > 0 \
			and Ranch.roster(h).size() <= Ranch.capacity(h):
		uid = Ranch._make(species, h, nm, int(GameState.run.get("day", 1)))  # a promise may go one over
		Ranch.animal(uid)["adult_day"] = int(GameState.run.get("day", 1))
	if uid == "":
		return ""
	var a := Ranch.animal(uid)
	a["gift"] = true
	if bool(opts.get("keepsake", false)):
		a["keepsake"] = true
		a["giver"] = str(opts.get("giver", ""))
	if str(opts.get("variant", "")) != "":
		a["variant"] = str(opts["variant"])
	return uid


## Each morning: bring every waiting gift that now fits. Returns the uids delivered.
static func deliver() -> Array:
	var out: Array = []
	var keep: Array = []
	for row in pending():
		if not (row is Dictionary) or not arc_ok(str((row as Dictionary).get("species", ""))):
			continue  # another arc's creature never arrives
		var uid := _try(str(row.get("species", "")), row)
		if uid == "":
			keep.append(row)
			continue
		out.append(uid)
		_arrived(str(row["species"]), uid, row, true)
	Ranch.st()[KEY] = keep
	return out


static func _who(opts: Dictionary) -> String:
	var g := str(opts.get("giver", ""))
	if g != "":
		return str(GameState.npcs[g].get("name", g)) if GameState.npcs.has(g) else g  # an npc id signs with its name (C12 P4)
	return "Benno" if GameState.run.get("arc", "") == "gangsters" else "Hazel"


static func _kind(species: String) -> String:
	var sp := Ranch.species(species)
	if sp.is_empty():
		return species.replace("_", " ")
	return Ranch.display_name(species).to_lower()  # the arc's own name ("hen", not "chicken")


## A home in words: its Plans tier name ("coop", "tide pool"), never the raw id. C12 P4.
static func _home_word(h: String) -> String:
	var nm := _tname(Ranch.build_of(h), maxi(1, Ranch.tier(h)))
	return nm.to_lower() if nm != "" else h.replace("_", " ")


## The building that makes room (the next Plans tier of its home, by name).
static func room_hint(species: String, opts: Dictionary = {}) -> String:
	var h := home_of(species, opts)
	if h == "":
		return "a home for it on the Plans board"
	var bid := Ranch.build_of(h)
	var t := Ranch.tier(h)
	if t > 0 and Ranch.capacity(h) > 0:
		var nxt := _tname(bid, t + 1)
		if nxt != "":
			return "a %s on the Plans board, or a free place in your %s" % [nxt, _home_word(h)]
		return "a free place in your %s" % _home_word(h)
	var nm := _tname(bid, 1)
	return "a %s on the Plans board" % (nm if nm != "" else _home_word(h))


static func _tname(bid: String, t: int) -> String:
	var d := Builds.tier_def(bid, t)
	var k := "name_gang" if GameState.run.get("arc", "") == "gangsters" and d.has("name_gang") else "name"
	return str(d.get(k, ""))


static func _waiting_letter(row: Dictionary) -> void:
	var sp := str(row["species"])
	var nm := str(row.get("name", ""))
	var what := nm if nm != "" else ItemWords.with_article(_kind(sp))
	Mail.send(_who(row), "%s is waiting for you here until there's room: it needs %s. It'll walk over the morning after. - %s"
		% [what.capitalize() if nm == "" else what, room_hint(sp, row), _who(row)], "chat", {}, true)


static func _arrived(sp: String, uid: String, opts: Dictionary, was_waiting: bool) -> void:
	var nm := str(Ranch.animal(uid).get("name", _kind(sp)))
	var h := str(Ranch.animal(uid).get("home", ""))
	if was_waiting:
		Mail.send(_who(opts), "%s walked over at first light and is settling into your %s. - %s" % [nm, _home_word(h), _who(opts)], "chat", {}, true)
	else:
		GameState.notify("%s the %s joined your %s." % [nm, _kind(sp), _home_word(h)])
