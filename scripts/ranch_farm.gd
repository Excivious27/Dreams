class_name RanchFarm
## Farm-side ranching (CONDUCT 11a P2): one place for the rules the farm map and the
## petting tap share, so farm.gd and game_map.gd never disagree again (c11a_01-06, 03-03,
## 04-06, 07, 14_10). Works with an empty data/ranch.json (today's fixed herd, keyed by
## node name in run.animals) and with a filled one (Ranch roster, keyed by uid).
##   care state  : state_of(animal) -> {streak, last_pet, fed, made, cared} (a view; save_state writes it back)
##   care step   : tend(st, day, petted, fed, needs_food) -> {"streak_up", "milestone"}
##   feeder rule : silo_feeds(kind, baby) / feed_from_silo(st, kind, baby, day)
##   quality     : silver() / gold() / quality_for(streak)
##   products    : product_for(kind, uid)
##   roster      : uses_roster(home), art_for(species, adult), pen_of(home, fallback), hatch_species(item)
## All ages: animals never die, sicken or run away; neglect only slows their goods.

## Farm sprite kind (farm._animal names) per Ranch species id, used when ranch.json gives no art.
const LEGACY_ART := {"chicken": "chicken", "hen": "chicken", "duck": "duck2", "cow": "cow2", "sheep": "sheep2",
	"goat": "goat", "llama": "llama", "pig": "pig", "rabbit": "rabbit", "rooster": "rooster", "horse": "horse"}
const LEGACY_BABY := {"chicken": "chick", "hen": "chick", "cow": "calf", "sheep": "lamb", "goat": "goat_kid"}
## A missed care day costs this many streak points (never below 0): one rainy day in town
## no longer wipes 14 days of care (c11a_03-01); a hungry week still sinks it (c11a_03-12).
const MISS_COST := 2
## Eggs the incubator takes when ranch.json names none (species.egg_item wins).
const EGGS := {"egg": "chicken", "duck_egg": "duck"}
const HATCH_DAYS := {"chicken": 3, "duck": 4}


## The skill animal care trains: the Ranching tree once it exists (P3), else Farming.
static func care_skill() -> String:
	return "ranching" if GameState.skills_data.has("ranching") else "farming"


## Extra goods from both trees (effect key animal_yield) and a chance to lift the star one step
## (animal_quality, Ranching tree) on top of the care quality.
static func yield_bonus() -> float:
	return GameState.ranch_bonus("animal_yield") + GameState.ranch_bonus("big_goods")


## animal_quality is days sooner to silver/gold (whole days in quality_for); its fraction is a
## chance to lift the star one step.
static func lift_quality(q: String) -> String:
	if q == "g" or randf() >= fmod(GameState.ranch_bonus("animal_quality"), 1.0):
		return q
	return "s" if q == "" else "g"


static func _rules() -> Dictionary:
	return Ranch.data().get("rules", {}) as Dictionary


## Silver/gold care thresholds: ranch.json rules win, else farm.ANIMAL (one source for toasts and goods).
static func silver() -> int:
	return int(_rules().get("silver_streak", 5))


static func gold() -> int:
	return int(_rules().get("gold_streak", 14))


static func quality_for(streak: int) -> String:
	streak += int(GameState.ranch_bonus("animal_quality"))
	return "g" if streak >= gold() else ("s" if streak >= silver() else "")


static func is_bird(kind: String) -> bool:
	var k := kind.to_lower()
	return k.begins_with("chicken") or k.begins_with("hen") or k.begins_with("duck") or k in ["rooster", "chick", "duckling"]


## The one feeder rule (both the map-load feed and the tap): grown birds eat silo hay with a
## Big Coop (tier 2+), grown beasts with a Big Barn; the rooster and babies never need hay.
static func silo_feeds(kind: String, baby: bool) -> bool:
	if baby or kind == "rooster":
		return false
	return Builds.built_tier("coop" if is_bird(kind) else "barn") >= 2


static func feed_from_silo(st: Dictionary, kind: String, baby: bool, day: int) -> bool:
	if int(st.get("fed", -9)) == day or not silo_feeds(kind, baby) or Builds.silo_hay() <= 0:
		return false
	GameState.run["silo"] = Builds.silo_hay() - 1
	st["fed"] = day
	return true


## Pasture (c11a_03-04): on a dry day outside winter, grown animals in their pen graze and need
## no hay (ranch.json rules.graze = false turns it off). Hay and the silo carry rain, snow and winter.
const WET := ["rain", "storm", "snow", "blizzard"]


static func graze_day() -> bool:
	if not bool(_rules().get("graze", true)):
		return false
	return GameState.season() != "winter" and not (GameState.weather_today() in WET)


static func graze(st: Dictionary, kind: String, baby: bool, day: int) -> bool:
	if baby or kind == "rooster" or int(st.get("fed", -9)) == day or not graze_day():
		return false
	st["fed"] = day
	return true


## The thing hint over an animal: its name and what it needs ("A: Clover (hungry)").
static func hint_for(a: Node, day: int) -> String:
	var st := state_of(a)
	var uid := uid_of(a)
	var nm := str(Ranch.animal(uid).get("name", "")) if uid != "" else ""
	if nm == "":
		nm = "the " + str(a.get("kind")).split("_")[0].rstrip("0123456789")
	var baby := bool(a.get("baby"))
	var want := ""
	if not baby and str(a.get("kind")) != "rooster" and int(st["fed"]) != day:
		want = "hungry"
	elif int(st["last_pet"]) != day:
		want = "pet me"
	elif not baby and product_for(str(a.get("kind")), uid) != "" and int(st["made"]) != day:
		want = "goods ready"
	else:
		want = "happy"
	return "A: %s (%s)" % [nm, want]


## The care state of a FarmAnimal node: roster record (uid) or run.animals[name].
static func uid_of(a: Node) -> String:
	if a == null:
		return ""
	if a.has_meta("uid"):
		return str(a.get_meta("uid"))
	var u: Variant = a.get("uid")
	return str(u) if u != null else ""


static func state_of(a: Node) -> Dictionary:
	var uid := uid_of(a)
	if uid != "" and not Ranch.animal(uid).is_empty():
		var r := Ranch.animal(uid)
		return {"streak": int(r.get("streak", 0)), "last_pet": int(r.get("last_pet", -9)), "fed": int(r.get("last_fed", -9)),
			"made": int(r.get("made_day", -9)), "cared": int(r.get("cared", r.get("last_pet", -9)))}
	var all: Dictionary = GameState.run.get("animals", {})
	var st: Dictionary = (all.get(str(a.name), {}) as Dictionary).duplicate()
	for k: String in ["streak", "last_pet", "fed", "made"]:
		if not st.has(k):
			st[k] = 0 if k == "streak" else -9
	if not st.has("cared"):
		st["cared"] = int(st["last_pet"])  # old saves: the streak was counted on the pet day
	return st


static func save_state(a: Node, st: Dictionary) -> void:
	var uid := uid_of(a)
	if uid != "" and not Ranch.animal(uid).is_empty():
		var r := Ranch.animal(uid)
		r["streak"] = int(st["streak"]); r["last_pet"] = int(st["last_pet"]); r["last_fed"] = int(st["fed"])
		r["made_day"] = int(st["made"]); r["cared"] = int(st["cared"])
		return
	var all: Dictionary = GameState.run.get("animals", {})
	all[str(a.name)] = st
	GameState.run["animals"] = all


## A care day counts once the animal is both petted and fed that day (needs_food false: babies,
## the rooster). Missed days since the last cared day cost MISS_COST each; then +1.
## Returns {"up": bool, "milestone": "" | "s" | "g"}.
static func tend(st: Dictionary, day: int, needs_food: bool) -> Dictionary:
	var out := {"up": false, "milestone": ""}
	if int(st.get("cared", -9)) == day or int(st.get("last_pet", -9)) != day:
		return out
	if needs_food and int(st.get("fed", -9)) != day:
		return out
	var last := int(st.get("cared", -9))
	var s := int(st.get("streak", 0))
	if last >= 0 and day - last > 1:
		var missed := maxi(0, day - last - 1 - int(GameState.ranch_bonus("care_grace")))  # Steady Routine
		s = maxi(0, s - MISS_COST * missed)
	var before := quality_for(s)
	s += 1
	st["streak"] = s
	st["cared"] = day
	out["up"] = true
	var after := quality_for(s)
	if after != before and after != "":
		out["milestone"] = after
	return out


## Unfed for two days or more: a sad face (no sickness, no leaving: c11a_03-12).
static func hungry_days(st: Dictionary, day: int) -> int:
	return maxi(0, day - maxi(int(st.get("fed", -9)), int(st.get("born", -9))) - 1) if int(st.get("fed", -9)) >= 0 else 0


static func streak_words(st: Dictionary, milestone: String) -> String:
	var s := int(st.get("streak", 0))
	var t := " %d days of care." % s if s > 1 else ""
	if milestone == "s":
		t += " Silver goods from now on!"
	elif milestone == "g":
		t += " Gold goods from now on!"
	return t


## What a grown, fed, petted animal gives today ("" = nothing). Roster species may name it.
static func product_for(kind: String, uid := "") -> String:
	if uid != "":
		var sp := Ranch.species(str(Ranch.animal(uid).get("species", "")))
		var p: Variant = sp.get("product", null)
		if p is Dictionary and str((p as Dictionary).get("id", "")) != "":
			return str((p as Dictionary)["id"])
		if p is String and str(p) != "":
			return str(p)
	var k := kind.to_lower()
	if k.begins_with("duck"):
		return "duck_egg"
	if k.begins_with("chicken") or k.begins_with("hen"):
		return "egg"
	if k.begins_with("goat"):
		return "goat_milk"
	if k.begins_with("cow"):
		return "milk"
	if k.begins_with("sheep") or k.begins_with("llama"):
		return "sheep_wool"
	if k.begins_with("pig"):
		return "truffle" if GameState.items.has("truffle") and GameState.season() != "winter" else ""  # pigs root out truffles (c11a_04-08)
	if k.begins_with("rabbit"):
		return "rabbit_fur" if GameState.items.has("rabbit_fur") else ""
	return ""


# ---- roster ----------------------------------------------------------------------

static func uses_roster(home: String) -> bool:
	return not Ranch.roster(home).is_empty()


static func is_adult(uid: String) -> bool:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return true
	if a.has("adult_day"):
		return int(GameState.run.get("day", 1)) >= int(a["adult_day"])
	var grow: Variant = Ranch.species(str(a.get("species", ""))).get("grow", null)
	var days := 7
	if grow is Dictionary:
		days = int((grow as Dictionary).get("newborn_days", 0)) + int((grow as Dictionary).get("young_days", 7))
	return int(GameState.run.get("day", 1)) >= int(a.get("born_day", 0)) + days


## The farm sprite kind for a species (ranch.json art first, then the old farm names).
static func art_for(species_id: String, adult: bool, variant := "") -> String:
	var art: Variant = Ranch.species(species_id).get("art", null)
	if art is Dictionary:
		var key := "adult" if adult else "baby"
		var v: Variant = (art as Dictionary).get(key, "")
		if not adult and str(v) == "" :
			v = (art as Dictionary).get("adult", "")
		if adult and variant != "" and (art as Dictionary).get("variants", null) is Dictionary:
			v = ((art as Dictionary)["variants"] as Dictionary).get(variant, v)
		if str(v) != "":
			return str(v)
	if not adult and LEGACY_BABY.has(species_id):
		return str(LEGACY_BABY[species_id])
	return str(LEGACY_ART.get(species_id, species_id))


## A home's pen: ranch.json buildings[home] row for the built tier ("pen": [x, y, w, h]) or the fallback.
## The tier is the home's building (Ranch.build_of: the apiary lives in the "beehive" build).
static func pen_of(home: String, fallback: Rect2i) -> Rect2i:
	var t := Builds.built_tier(Ranch.build_of(home))
	var best := fallback
	for row in ((Ranch.data()["buildings"] as Dictionary).get(home, []) as Array):
		if row is Dictionary and int((row as Dictionary).get("tier", 0)) <= t and (row as Dictionary).get("pen", null) is Array:
			var p: Array = (row as Dictionary)["pen"]
			if p.size() == 4:
				best = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
	return best


## Spread n animals over a pen: a fixed, roomy order (front rows first, every other cell).
static func pen_cells(pen: Rect2i, n: int) -> Array:
	var cells: Array = []
	var odd: Array = []
	for y in range(pen.end.y - 1, pen.position.y - 1, -1):
		for x in range(pen.position.x, pen.end.x):
			((cells if (x + y) % 2 == 0 else odd) as Array).append(Vector2i(x, y))
	cells.append_array(odd)
	var out: Array = []
	for i in n:
		out.append(cells[i % maxi(1, cells.size())])
	return out


## The incubator is a thin view over Ranch (the C11a contract, c11b_01-03 / 05-07): every egg in
## ranch.json species[*].breed.egg hatches, in its species' home, in Ranch's format {species, due, q}.

## Which species an egg hatches ("" = not an incubator egg). breed.egg first, then the legacy names.
static func hatch_species(item: String) -> String:
	if item == "":
		return ""
	var sp: Dictionary = Ranch.data()["species"]
	for sid in sp:
		var row: Dictionary = sp[sid]
		var br: Variant = row.get("breed", null)
		if br is Dictionary and str((br as Dictionary).get("egg", "")) == item:
			return str(sid)
		if str(row.get("egg_item", "")) == item:
			return str(sid)
	return str(EGGS.get(item, "")) if sp.has(str(EGGS.get(item, ""))) else ""


## Days an egg warms: breed.days less the hatch_fast perk (min 1), as Ranch.incubate counts it.
static func hatch_days(sid: String) -> int:
	var sp := Ranch.species(sid)
	var br: Variant = sp.get("breed", null)
	var days := int((br as Dictionary).get("days", 0)) if br is Dictionary else 0
	if days <= 0:
		days = int(sp.get("hatch_days", HATCH_DAYS.get(sid, 3)))
	return maxi(1, days - int(GameState.ranch_bonus("hatch_fast")))


## The home an egg's species lives in ("" = none).
static func egg_home(item: String) -> String:
	var sid := hatch_species(item)
	return str(Ranch.species(sid).get("home", "")) if sid != "" else ""


## Does a home's built tier warm eggs (an "incubator" or "big_nest" add)?
static func has_incubator(home: String) -> bool:
	return Ranch.has_add(home, "incubator") or Ranch.has_add(home, "big_nest")


## Homes whose built tier has an incubator.
static func incubator_homes() -> Array:
	var out: Array = []
	for h in (Ranch.data()["buildings"] as Dictionary):
		if has_incubator(str(h)):
			out.append(str(h))
	return out


## The first tier name of a home that brings the incubator ("Big Coop", "Grand Enclosure"...).
static func incubator_tier_name(home: String) -> String:
	for row in ((Ranch.data()["buildings"] as Dictionary).get(home, []) as Array):
		if row is Dictionary:
			var adds: Array = (row as Dictionary).get("adds", [])
			if adds.has("incubator") or adds.has("big_nest"):
				var td := Builds.tier_def(Ranch.build_of(home), int((row as Dictionary).get("tier", 1)))
				if str(td.get("name", "")) != "":
					return str(td["name"])
				break
	return "a bigger %s" % str(Builds.current_def(Ranch.build_of(home)).get("name", home)).to_lower()


## Incubator slots of a home (Ranch.house(home).incubator, entries {species, due, q}).
static func incubator(home := "coop") -> Array:
	return Ranch.house(home)["incubator"]


## Every warming egg across homes.
static func all_eggs() -> Array:
	var out: Array = []
	for h in (Ranch.st()["houses"] as Dictionary):
		out.append_array(incubator(str(h)))
	return out


## An incubator entry's hatch day (Ranch.incubate writes "due"; older entries used "day").
static func egg_day(e: Variant) -> int:
	if e is Dictionary:
		return int((e as Dictionary).get("due", (e as Dictionary).get("day", 0)))
	return int(e)


## Free incubator places in a home: its capacity minus the animals living there and eggs warming.
static func room_for_egg(home: String) -> int:
	if Ranch.capacity(home) <= 0:
		return 0
	return Ranch.room(home) - incubator(home).size()


## Coop shorthand (older callers and tests).
static func coop_room() -> int:
	return room_for_egg("coop")


## Hatch every egg that is due today or earlier into a roster baby, in every home. Returns the new names.
static func hatch_due(day: int) -> Array:
	var out: Array = []
	for h in (Ranch.st()["houses"] as Dictionary).keys():
		var inc := incubator(str(h))
		for e in inc.duplicate():
			if not (e is Dictionary) or egg_day(e) > day or Ranch.room(str(h)) <= 0:
				continue
			var sid := str((e as Dictionary).get("species", "chicken"))
			var uid := Ranch.add(sid, str(h), "", egg_day(e))
			if uid != "":
				inc.erase(e)
				out.append(str(Ranch.animal(uid).get("name", sid)))
	return out


## A young one's word for a species: chick, duckling, else "baby <species>".
static func baby_word(sid: String) -> String:
	if sid == "chicken":
		return "chick"
	if sid == "duck":
		return "duckling"
	var sp := Ranch.species(sid)
	if str(sp.get("baby_word", "")) != "":
		return str(sp["baby_word"])
	return "baby %s" % str(sp.get("name", sid)).to_lower()


## Take one egg of a kind, plain before starred (a gold egg is never spent by surprise: c11a_05-04).
static func take_egg(item: String) -> void:
	GameState.add_item(item, -1)
