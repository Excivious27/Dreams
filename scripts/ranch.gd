class_name Ranch
## Ranching (CONDUCT 11a). CONTRACT STUB written by the main chat before the fix packages
## branched: every package codes against these signatures. P1 owns this file and fills it in
## (it may add functions, never change these). Design: /home/claude/wt/c11a_reports/c11a_01.jsonl.
## Data: data/ranch.json from tools/gen_ranch.py:
##   {"species": {id: {name, name_gang, arc, group, home, art{adult, baby, variants}, height_px, voice,
##                     buy{seller, price, tier}, feed{}, product{id, every_days, needs_mood}, space, egg_item}},
##    "buildings": {home: [{tier, cap, adds:[feeder|incubator|auto_water|heater|breeding], pen:[x,y,w,h]}]},
##    "rules": {}, "products": {}, "processing": {}}
## State: run["ranch"] = {ver, next_uid, animals: {uid: {species, name, home, born_day, adult_day,
##         friend 0..1000, mood 0..100, last_pet, last_fed, made_day, variant, parents, team}},
##         houses: {home: {tier, hay, water_day, incubator: []}}}
## No animal ever dies, is slaughtered or sold for meat (all ages): "rehome" sends one to a villager farm.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/ranch.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
		for k in ["species", "buildings", "rules", "products", "processing"]:
			if not _data.has(k):
				_data[k] = {}
	return _data


static func species(id: String) -> Dictionary:
	return (data()["species"] as Dictionary).get(id, {})


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("ranch", null) is Dictionary):
		r["ranch"] = {"ver": 1, "next_uid": 1}
	var d: Dictionary = r["ranch"]
	for k in ["animals", "houses"]:
		if not (d.get(k, null) is Dictionary):
			d[k] = {}
	if not d.has("next_uid"):
		d["next_uid"] = 1
	return d


static func animals() -> Dictionary:
	return st()["animals"]


static func animal(uid: String) -> Dictionary:
	return (animals() as Dictionary).get(uid, {})


## Uids living in a home ("coop", "barn", "hutch", "sty", "apiary", "stable").
static func roster(home: String) -> Array:
	var out: Array = []
	for uid in animals():
		if str((animals()[uid] as Dictionary).get("home", "")) == home:
			out.append(uid)
	out.sort()
	return out


static func tier(home: String) -> int:
	return int(((st()["houses"] as Dictionary).get(home, {}) as Dictionary).get("tier", 0))


static func capacity(home: String) -> int:
	var t := tier(home)
	for row in ((data()["buildings"] as Dictionary).get(home, []) as Array):
		if row is Dictionary and int(row.get("tier", 0)) == t:
			return int(row.get("cap", 0))
	return 0


## Add an animal (bought, hatched, born, quest reward). Returns its uid or "" when there is no room.
static func add(species_id: String, home := "", name := "", born_day := -1) -> String:
	var sp := species(species_id)
	var h := home if home != "" else str(sp.get("home", ""))
	if h == "" or roster(h).size() >= capacity(h):
		return ""
	var d := st()
	var uid := "a%d" % int(d["next_uid"])
	d["next_uid"] = int(d["next_uid"]) + 1
	var day := int(GameState.run.get("day", 1)) if born_day < 0 else born_day
	d["animals"][uid] = {"species": species_id, "name": name if name != "" else str(sp.get("name", species_id)),
		"home": h, "born_day": day, "friend": 0, "mood": 50, "last_pet": -1, "last_fed": -1, "made_day": -1,
		"variant": "", "parents": [], "team": false}
	return uid


static func rehome(uid: String) -> bool:
	return (animals() as Dictionary).erase(uid)


static func is_adult(uid: String) -> bool:
	return not animal(uid).is_empty()


static func pet(uid: String) -> bool:
	var a := animal(uid)
	if a.is_empty() or int(a.get("last_pet", -1)) == int(GameState.run.get("day", 1)):
		return false
	a["last_pet"] = int(GameState.run.get("day", 1))
	a["friend"] = mini(1000, int(a.get("friend", 0)) + 15)
	return true


## Overnight step (GameState.sleep): feeding, mood, products, growth, births. Returns report lines.
static func overnight(_report: Dictionary) -> Array:
	return []


## Is a product id something this farm can make now (favour letters, quests)?
static func source_ok(_item: String) -> bool:
	return false


## Old saves: seed the roster from today's builds/animals once (idempotent).
static func migrate() -> void:
	st()
