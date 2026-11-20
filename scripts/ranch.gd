class_name Ranch
## Ranching (CONDUCT 11a, P1). Every rule for farm animals lives here as statics so the care loop runs
## headless (tools/ranch_test.gd); farm.gd / game_map.gd / menus are thin callers that toast and emote.
## Data: data/ranch.json from tools/gen_ranch.py (edit that, never the JSON):
##   {"species": {id: {name, name_gang, arc, group, home, space, height_px, baby_h, voice, grow_days, pet_word,
##                     art{adult, baby[src, strip], shorn?, variants[{id, art, weight, rare, tint?, product?}]},
##                     buy{seller, price, tier}, feed "hay"|"forage", product{id, every_days, needs_mood, extra?, dig?,
##                     large_at?}, breed{days, litter, min_friend, chance, egg?}, names[], rehome_pay}},
##    "buildings": {home: [{tier, cap, adds:[feeder|incubator|auto_water|heater|breeding], pen:[x,y,w,h]}]},
##    "products": {item: {species[], home[]}}, "rules": {...}, "processing": {item: [goods]},
##    "legacy": [[old node name, species, variant, home, tier, young flag]], "legacy_moved": {}, "planned": {}}
## State: run["ranch"] = {ver, next_uid, animals: {uid: {species, name, home, born_day, adult_day, friend 0..1000,
##         mood 0..100, last_pet, last_fed, made_day, variant, parents, team, ready {item, q, n}|absent,
##         expecting {due, with}|absent, named bool, legacy}}, houses: {home: {tier, hay, incubator: [{species,
##         due, q}]}}, news: [lines for the next morning]}
## No animal ever dies, is slaughtered or sold for meat (all ages): "rehome" sends one to a villager's pasture.
## Breeding has no gender checks: any two adults of a species in a home whose tier adds "breeding".
## Effect keys read here (Ranching tree, P3): animal_yield, friend_gain, breed_chance, grow_speed, rare_breed,
## ranch_value (GameState.unit_sell_value) through GameState.ranch_bonus(key).

const VER := 1
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


## Species open in this run's arc ("" = both arcs).
static func species_for_arc() -> Array:
	var out: Array = []
	var arc := str(GameState.run.get("arc", ""))
	for id in data()["species"]:
		var a := str((data()["species"][id] as Dictionary).get("arc", ""))
		if a == "" or a == arc:
			out.append(id)
	return out


static func rule(key: String, def: Variant = 0) -> Variant:
	return (data()["rules"] as Dictionary).get(key, def)


static func _day() -> int:
	return int(GameState.run.get("day", 1))


static func _gang() -> bool:
	return str(GameState.run.get("arc", "")) == "gangsters"


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("ranch", null) is Dictionary):
		r["ranch"] = {"ver": VER, "next_uid": 1}
	var d: Dictionary = r["ranch"]
	for k in ["animals", "houses"]:
		if not (d.get(k, null) is Dictionary):
			d[k] = {}
	if not (d.get("news", null) is Array):
		d["news"] = []
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
	out.sort_custom(func(a: String, b: String) -> bool: return int(a.substr(1)) < int(b.substr(1)))
	return out


## The home's tier: the Plans build (Builds) or a tier set here (tests, homes not yet in Builds).
static func tier(home: String) -> int:
	var own := int(((st()["houses"] as Dictionary).get(home, {}) as Dictionary).get("tier", 0))
	return maxi(own, Builds.built_tier(home))


static func tier_row(home: String, t := -1) -> Dictionary:
	if t < 0:
		t = tier(home)
	for row in ((data()["buildings"] as Dictionary).get(home, []) as Array):
		if row is Dictionary and int(row.get("tier", 0)) == t:
			return row
	return {}


static func capacity(home: String) -> int:
	return int(tier_row(home).get("cap", 0))


static func has_add(home: String, add_id: String) -> bool:
	return (tier_row(home).get("adds", []) as Array).has(add_id)


## Room left in a home (a newborn needs a free place).
static func room(home: String) -> int:
	return maxi(0, capacity(home) - roster(home).size())


static func house(home: String) -> Dictionary:
	var hs: Dictionary = st()["houses"]
	if not (hs.get(home, null) is Dictionary):
		hs[home] = {"tier": 0, "hay": 0, "incubator": []}
	var h: Dictionary = hs[home]
	if not (h.get("incubator", null) is Array):
		h["incubator"] = []
	return h


## The variant row for an animal (its look and any product override).
static func variant_row(uid: String) -> Dictionary:
	var a := animal(uid)
	var sp := species(str(a.get("species", "")))
	var vs: Array = (sp.get("art", {}) as Dictionary).get("variants", [])
	for v in vs:
		if v is Dictionary and str(v.get("id", "")) == str(a.get("variant", "")):
			return v
	return vs[0] if not vs.is_empty() and vs[0] is Dictionary else {}


static func display_name(sid: String) -> String:
	var sp := species(sid)
	return str(sp.get("name_gang" if _gang() else "name", sid.capitalize()))


static func _make(species_id: String, h: String, nm: String, day: int, variant := "", parents: Array = []) -> String:
	var sp := species(species_id)
	var d := st()
	var uid := "a%d" % int(d["next_uid"])
	d["next_uid"] = int(d["next_uid"]) + 1
	if variant == "":
		var vs: Array = (sp.get("art", {}) as Dictionary).get("variants", [])
		variant = str((vs[0] as Dictionary).get("id", "")) if not vs.is_empty() else ""
	var grow := int(sp.get("grow_days", rule("young_days", 7)))
	grow = int(ceil(grow * (1.0 - GameState.ranch_bonus("grow_speed"))))
	d["animals"][uid] = {"species": species_id, "name": nm if nm != "" else _pick_name(species_id), "named": nm != "",
		"home": h, "born_day": day, "adult_day": day + grow, "friend": 0, "mood": 50, "last_pet": -1, "last_fed": -1,
		"made_day": -1, "variant": variant, "parents": parents, "team": false}
	return uid


## Add an animal (bought, hatched, born, quest reward). Returns its uid or "" when there is no room.
static func add(species_id: String, home := "", name := "", born_day := -1) -> String:
	var sp := species(species_id)
	if sp.is_empty():
		return ""
	var h := home if home != "" else str(sp.get("home", ""))
	if h == "" or roster(h).size() >= capacity(h):
		return ""
	var day := _day() if born_day < 0 else born_day
	var uid := _make(species_id, h, name, day)
	if born_day < 0:
		animal(uid)["adult_day"] = day  # bought grown
	return uid


## A free name from the species list (nobody on the farm has it yet).
static func _pick_name(sid: String) -> String:
	var used := {}
	for u in animals():
		used[str((animals()[u] as Dictionary).get("name", ""))] = true
	var names: Array = species(sid).get("names", [])
	for i in names.size():
		var n := str(names[(int(st()["next_uid"]) + i) % names.size()])
		if not used.has(n):
			return n
	return display_name(sid)


static func rename(uid: String, nm: String) -> bool:
	var a := animal(uid)
	var clean := ""
	for ch in nm.strip_edges():
		if ch == " " or ch == "-" or ch == "'" or (ch.to_lower() != ch.to_upper()):
			clean += ch
	clean = clean.strip_edges().left(12)
	if a.is_empty() or clean == "":
		return false
	a["name"] = clean
	a["named"] = true
	return true


## What a rehome would pay (0 for young ones: no breed-and-rehome loop).
static func rehome_pay(uid: String) -> int:
	var a := animal(uid)
	if a.is_empty() or _day() - int(a.get("born_day", 0)) < int(rule("rehome_min_age", 28)):
		return 0
	return int(species(str(a.get("species", ""))).get("rehome_pay", 0))


## Send an animal to live on at a villager's pasture (never sold for meat). A thank-you for grown ones.
static func rehome(uid: String) -> bool:
	var a := animal(uid)
	if a.is_empty():
		return false
	var pay := rehome_pay(uid)
	if pay > 0:
		GameState.add_money(pay, "rehome")
	var where := str(rule("rehome_to_gang" if _gang() else "rehome_to", "a friend's pasture"))
	(st()["news"] as Array).append("%s settled in at %s. A thank-you note came with %s." % [str(a.get("name", "")), where, Money.amount(pay) if pay > 0 else "a drawing"])
	for other in animals():
		var e: Variant = (animals()[other] as Dictionary).get("expecting", null)
		if e is Dictionary and str((e as Dictionary).get("with", "")) == uid:
			(e as Dictionary)["with"] = ""
	return (animals() as Dictionary).erase(uid)


static func is_adult(uid: String) -> bool:
	var a := animal(uid)
	return not a.is_empty() and _day() >= int(a.get("adult_day", 0))


static func _friend_add(a: Dictionary, n: int) -> void:
	if n > 0:
		n = int(round(n * (1.0 + GameState.ranch_bonus("friend_gain"))))
	a["friend"] = clampi(int(a.get("friend", 0)) + n, 0, int(rule("friend_max", 1000)))


## Hearts 0..5 for menus.
static func hearts(uid: String) -> int:
	return int(animal(uid).get("friend", 0)) * 5 / maxi(1, int(rule("friend_max", 1000)))


## Today's pet. False when already petted today.
static func pet(uid: String) -> bool:
	var a := animal(uid)
	if a.is_empty() or int(a.get("last_pet", -1)) == _day():
		return false
	a["last_pet"] = _day()
	_friend_add(a, int(rule("pet_friend", 30)))
	return true


static func needs_hay(uid: String) -> bool:
	var a := animal(uid)
	return not a.is_empty() and str(species(str(a.get("species", ""))).get("feed", "hay")) == "hay"


static func fed_today(uid: String, day := -1) -> bool:
	var a := animal(uid)
	if a.is_empty():
		return false
	if not needs_hay(uid):
		return GameState.season() != "winter"  # bees live on flowers (winter: they rest)
	return int(a.get("last_fed", -1)) >= (_day() if day < 0 else day)


## Feed one animal for a day (src: "hand" spends a hay from the bag, "silo"/"trough"/"graze"/"spouse" are free here).
static func feed(uid: String, src := "hand", day := -1) -> bool:
	var a := animal(uid)
	var d := _day() if day < 0 else day
	if a.is_empty() or not needs_hay(uid) or int(a.get("last_fed", -1)) >= d:
		return false
	if src == "hand":
		if GameState.count("hay") <= 0:
			return false
		GameState.add_item("hay", -1)
	a["last_fed"] = d
	return true


## Pasture grass eaten in the pen (P2 calls it when an animal grazes a grass cell).
static func graze(uid: String) -> bool:
	return feed(uid, "graze")


## Every animal fed for a day (the spouse's chore, helpers). Returns how many.
static func feed_all(day := -1, src := "spouse") -> int:
	var n := 0
	for uid in animals():
		if feed(str(uid), src, day):
			n += 1
	return n


## Goods waiting on an animal ({item, q, n} or {}).
static func ready(uid: String) -> Dictionary:
	var r: Variant = animal(uid).get("ready", null)
	return r if r is Dictionary else {}


## Pick up an animal's goods: clears them and returns {item, n, q} for the caller to pop/add.
static func collect(uid: String) -> Dictionary:
	var a := animal(uid)
	var r := ready(uid)
	if r.is_empty():
		return {}
	a.erase("ready")
	if str(species(str(a.get("species", ""))).get("art", {}).get("shorn", "")) != "":
		a["shorn_day"] = _day()
	return r


## collect() straight into the bag with its quality (headless; returns the same dict).
static func take(uid: String) -> Dictionary:
	var r := collect(uid)
	if not r.is_empty():
		GameState.add_item(str(r["item"]), int(r["n"]))
		if str(r.get("q", "")) != "":
			GameState.add_quality(str(r["item"]), str(r["q"]), int(r["n"]))
		if str(r.get("extra", "")) != "":
			GameState.add_item(str(r["extra"]), 1)
	return r


## One tap on an animal (P2's pet_animal calls this): feed if holding hay, pet, pick up goods.
## Returns {fed, petted, got: {item, n, q}, hungry, text} (text is the toast; "" = nothing to say).
static func tap(uid: String, held := "") -> Dictionary:
	var a := animal(uid)
	var out := {"fed": false, "petted": false, "got": {}, "hungry": false, "text": ""}
	if a.is_empty():
		return out
	var nm := str(a.get("name", ""))
	if held == "hay" and needs_hay(uid) and not fed_today(uid):
		out["fed"] = feed(uid, "hand")
	out["petted"] = pet(uid)
	out["got"] = take(uid)
	out["hungry"] = needs_hay(uid) and not fed_today(uid) and is_adult(uid)
	var bits: Array = []
	if out["fed"]:
		bits.append("%s munches the hay." % nm)
	if out["petted"]:
		bits.append("%s loves that." % nm if str(species(str(a["species"])).get("pet_word", "pet")) == "pet" else "The %s hums along." % nm)
	if not (out["got"] as Dictionary).is_empty():
		bits.append("Got %s%s." % [ItemWords.count_id(str(out["got"]["item"]), int(out["got"]["n"])), (" and " + ItemWords.count_id(str(out["got"]["extra"]), 1)) if str(out["got"].get("extra", "")) != "" else ""])
	if out["hungry"]:
		bits.append("%s is hungry: hold hay and tap%s." % [nm, ", or fill the silo" if has_add(str(a["home"]), "feeder") else ""])
	if bits.is_empty():
		bits.append("%s is happy today." % nm)
	out["text"] = " ".join(bits)
	return out


## The hint line over an animal ("A: Clover (hungry)").
static func hint(uid: String, held := "") -> String:
	var a := animal(uid)
	if a.is_empty():
		return ""
	var nm := str(a.get("name", ""))
	if not ready(uid).is_empty():
		return "A: %s (goods ready)" % nm
	if is_adult(uid) and needs_hay(uid) and not fed_today(uid):
		return "A: feed %s" % nm if held == "hay" else "A: %s (hungry)" % nm
	if int(a.get("last_pet", -1)) != _day():
		return "A: %s %s" % [str(species(str(a["species"])).get("pet_word", "pet")), nm]
	return "%s (happy)" % nm


## Which bubble an animal shows: "goods", "hungry", "pet", "sleep" or "".
static func need(uid: String) -> String:
	if animal(uid).is_empty():
		return ""
	if not ready(uid).is_empty():
		return "goods"
	if is_adult(uid) and needs_hay(uid) and not fed_today(uid):
		return "hungry"
	if int(animal(uid).get("last_pet", -1)) != _day():
		return "pet"
	return ""


## Art for a roster animal: {group, strip (idle strip id), baby, height_px, tint (Color or null), species}.
static func art_for(uid: String) -> Dictionary:
	var a := animal(uid)
	var sp := species(str(a.get("species", "")))
	var art: Dictionary = sp.get("art", {})
	var v := variant_row(uid)
	var src := str(v.get("art", art.get("adult", "")))
	if str(art.get("shorn", "")) != "" and ready(uid).is_empty() and a.has("shorn_day"):
		src = str(art["shorn"])
	var out := {"group": "animals/" + src, "strip": "idle", "baby": false, "height_px": float(sp.get("height_px", 16)),
		"tint": Color(str(v["tint"])) if v.has("tint") else null, "species": str(a.get("species", ""))}
	if not is_adult(uid):
		var b: Array = art.get("baby", [src, "idle"])
		out["group"] = "animals/" + str(b[0])
		out["strip"] = str(b[1])
		out["baby"] = true
		out["height_px"] = float(sp.get("baby_h", 8))
	return out


## Quality of today's goods from friendship and mood ("", "s", "g").
static func quality(a: Dictionary) -> String:
	var f := int(a.get("friend", 0))
	var m := int(a.get("mood", 0))
	if f >= int(rule("gold_at", 700)) and m >= 70:
		return "g"
	if f >= int(rule("silver_at", 250)) and m >= 50:
		return "s"
	return ""


static func _product_of(uid: String) -> Dictionary:
	var a := animal(uid)
	var p: Dictionary = (species(str(a.get("species", ""))).get("product", {}) as Dictionary).duplicate()
	var v := variant_row(uid)
	if v.has("product"):
		p["id"] = str(v["product"])
		p["every_days"] = maxi(3, int(p.get("every_days", 1)))
		p.erase("extra")
	return p


## Incubate an egg (Big Coop): one slot, hatches overnight in breed.days.
static func incubate(egg_item: String, q := "") -> String:
	var sid := ""
	for id in data()["species"]:
		if str(((data()["species"][id] as Dictionary).get("breed", {}) as Dictionary).get("egg", "")) == egg_item:
			sid = id
	if sid == "":
		return "That won't hatch."
	var home := str(species(sid).get("home", "coop"))
	if not has_add(home, "incubator"):
		return "The incubator comes with the Big Coop."
	var inc: Array = house(home)["incubator"]
	if inc.size() >= int(rule("incubator_slots", 4)):
		return "The incubator is full."
	if room(home) - inc.size() <= 0:
		return "No room for another bird in the %s." % home
	if GameState.count(egg_item) <= 0:
		return "Hold an egg to put it in."
	GameState.add_item(egg_item, -1)
	var days := int(ceil(int(species(sid)["breed"].get("days", 3)) * (1.0 - GameState.ranch_bonus("grow_speed"))))
	inc.append({"species": sid, "due": _day() + maxi(1, days), "q": q})
	return ""


## Genetics-lite: 45% one parent's look, 45% the other's, else a roll over the species table (rare scaled by luck).
static func _child_variant(sid: String, pa: String, pb: String, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	var base := float(rule("rare_base", 0.1))
	if pa != "" and r < (1.0 - base) / 2.0:
		return pa
	if pb != "" and r < 1.0 - base:
		return pb
	var vs: Array = species(sid).get("art", {}).get("variants", [])
	var tot := 0.0
	var ws: Array = []
	for v in vs:
		var w := float(v.get("weight", 1))
		if bool(v.get("rare", false)):
			w *= 1.0 + GameState.ranch_bonus("rare_breed") * 10.0
		ws.append(w)
		tot += w
	var pick := rng.randf() * tot
	for i in vs.size():
		pick -= float(ws[i])
		if pick <= 0.0:
			return str(vs[i]["id"])
	return str(vs[0]["id"]) if not vs.is_empty() else ""


## Overnight step (GameState.sleep, before the day turns over; host only). Returns report lines (also
## kept in report["ranch"]). Feeders, mood, friendship, goods, births, hatching, growing up.
static func overnight(report: Dictionary) -> Array:
	var lines: Array = []
	if Net.visiting():
		return lines
	var d := st()
	for l in d["news"]:
		lines.append(str(l))
	d["news"] = []
	var day := _day()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ranch%d" % day) + int(d.get("next_uid", 1))
	var winter := GameState.season() == "winter"
	var wet := GameState.is_wet()
	# Feeders: grown animals in a feeder home eat from the trough, then the silo.
	var silo_fed := 0
	for uid in animals().keys():
		var a: Dictionary = animals()[uid]
		var home := str(a.get("home", ""))
		if not needs_hay(uid) or fed_today(uid, day) or not has_add(home, "feeder"):
			continue
		var h := house(home)
		if int(h.get("hay", 0)) > 0:
			h["hay"] = int(h["hay"]) - 1
			a["last_fed"] = day
		elif Builds.silo_hay() > 0:
			GameState.run["silo"] = Builds.silo_hay() - 1
			a["last_fed"] = day
			silo_fed += 1
	var hungry := 0
	var missed: Array = []
	var made := {}
	for uid in animals().keys():
		var a: Dictionary = animals()[uid]
		var sp := species(str(a.get("species", "")))
		var home := str(a.get("home", ""))
		var fed := fed_today(uid, day)
		var petted := int(a.get("last_pet", -1)) == day
		var adult := day >= int(a.get("adult_day", 0))
		# Mood: fed, petted, sheltered (a heater in winter), fresh water.
		var mood := 0
		if fed:
			mood += int(rule("mood_fed", 45))
		if petted:
			mood += int(rule("mood_pet", 35))
		mood += int(rule("mood_winter_no_heater", 5)) if winter and not has_add(home, "heater") else int(rule("mood_comfort", 20))
		if has_add(home, "auto_water"):
			mood += int(rule("mood_auto_water", 5))
		a["mood"] = clampi(mood, 0, 100)
		if fed:
			_friend_add(a, int(rule("fed_friend", 10)))
		elif adult and needs_hay(uid):
			_friend_add(a, int(rule("unfed_friend", -15)))
			hungry += 1
		if not petted:
			if int(a.get("last_pet", -1)) == day - 1:
				missed.append(str(a.get("name", "")))  # the pet streak broke today: said once
			_friend_add(a, int(rule("missed_pet_friend", -10)))
		# Goods: a fed, content grown animal makes its product every N days (pigs dig outdoors only).
		var p := _product_of(uid)
		if adult and fed and str(p.get("id", "")) != "" and int(a.get("mood", 0)) >= int(p.get("needs_mood", 0)) \
				and day - int(a.get("made_day", -99)) >= int(p.get("every_days", 1)) and ready(uid).is_empty() \
				and not (bool(p.get("dig", false)) and (winter or wet)):
			var ay := GameState.ranch_bonus("animal_yield")
			var n := 1 + int(ay) + (1 if rng.randf() < fmod(ay, 1.0) else 0)
			var item := str(p["id"])
			var ex: Array = p.get("extra", [])
			if ex.size() == 2 and rng.randf() < float(ex[1]):
				if str(ex[0]) == item:
					n += 1
				else:
					a["extra_ready"] = str(ex[0])
			if p.has("large_at") and int(a.get("friend", 0)) >= int(p["large_at"]):
				n += 1 if rng.randf() < 0.5 else 0
			a["ready"] = {"item": item, "n": n, "q": quality(a)}
			a["made_day"] = day  # the night it was made: ready in the morning
			made[item] = int(made.get(item, 0)) + n
		# Growing up (tomorrow).
		if not adult and day + 1 >= int(a.get("adult_day", 0)):
			lines.append("%s is all grown up." % str(a.get("name", "")))
	# Extra goods (feathers, beeswax) ride along with the main pick-up.
	for uid in animals():
		var a2: Dictionary = animals()[uid]
		if a2.has("extra_ready") and a2.get("ready", null) is Dictionary:
			(a2["ready"] as Dictionary)["extra"] = str(a2["extra_ready"])
		a2.erase("extra_ready")
	# Births: expecting animals whose day has come; new pairs in breeding homes.
	lines.append_array(_births(day, rng))
	lines.append_array(_hatch(day, rng))
	if hungry > 0:
		lines.append("%d animal%s went hungry: hold hay and tap them, or fill a feeder." % [hungry, "" if hungry == 1 else "s"])
	if missed.size() > 0:
		lines.append("%s missed you yesterday: a daily pet keeps friendship growing." % _list(missed))
	if not made.is_empty():
		var bits: Array = []
		for it in made:
			bits.append(ItemWords.count_id(str(it), int(made[it])))
		lines.append("Ready in the pens: %s." % _list(bits))
	if silo_fed > 0:
		lines.append("The feeders took %d hay from the silo (%d left)." % [silo_fed, Builds.silo_hay()])
	report["ranch"] = lines
	return lines


static func _list(a: Array) -> String:
	if a.size() <= 1:
		return "".join(a)
	if a.size() > 3:
		return "%s and %d more" % [", ".join(a.slice(0, 2)), a.size() - 2]
	return "%s and %s" % [", ".join(a.slice(0, a.size() - 1)), str(a[-1])]


static func _births(day: int, rng: RandomNumberGenerator) -> Array:
	var lines: Array = []
	# Due today.
	for uid in animals().keys():
		var a: Dictionary = animals()[uid]
		var e: Variant = a.get("expecting", null)
		if not (e is Dictionary) or int((e as Dictionary).get("due", 0)) > day + 1:
			continue
		a.erase("expecting")
		var sid := str(a["species"])
		var home := str(a["home"])
		var lit: Array = species(sid).get("breed", {}).get("litter", [1, 1])
		var n := rng.randi_range(int(lit[0]), int(lit[1]))
		var other := str((e as Dictionary).get("with", ""))
		var names: Array = []
		for i in n:
			if room(home) <= 0:
				break
			var v := _child_variant(sid, str(a.get("variant", "")), str(animal(other).get("variant", "")), rng)
			var kid := _make(sid, home, "", day + 1, v, [uid, other])
			names.append(str(animal(kid)["name"]))
		if not names.is_empty():
			lines.append("%s had %s! Say hello in the %s (rename on the Animals page)." % [str(a["name"]), ("a baby, %s" % names[0]) if names.size() == 1 else "%d babies: %s" % [names.size(), _list(names)], home])
	# New pairs (no gender checks: any two content adults of a species in a breeding home).
	for home in (data()["buildings"] as Dictionary):
		if not has_add(home, "breeding"):
			continue
		var by: Dictionary = {}
		for uid in roster(home):
			var a: Dictionary = animal(uid)
			var br: Dictionary = species(str(a["species"])).get("breed", {})
			if br.get("egg", "") != "" or not is_adult(uid) or int(a.get("friend", 0)) < int(br.get("min_friend", 0)):
				continue
			by[str(a["species"])] = by.get(str(a["species"]), []) + [uid]
		for sid in by:
			var ids: Array = by[sid]
			if ids.size() < 2 or room(home) <= 0:
				continue
			var busy := false
			for u in roster(home):
				if animal(u).get("expecting", null) is Dictionary and str(animal(u)["species"]) == sid:
					busy = true
			if busy:
				continue
			var ch := float(species(sid)["breed"].get("chance", 0.0)) + GameState.ranch_bonus("breed_chance")
			if rng.randf() < ch:
				var a: Dictionary = animal(str(ids[0]))
				a["expecting"] = {"due": day + int(species(sid)["breed"].get("days", 7)), "with": str(ids[1])}
				lines.append("%s and %s are expecting a little one in %d days." % [str(a["name"]), str(animal(str(ids[1]))["name"]), int(species(sid)["breed"].get("days", 7))])
	return lines


static func _hatch(day: int, rng: RandomNumberGenerator) -> Array:
	var lines: Array = []
	for home in (st()["houses"] as Dictionary).keys():
		var inc: Array = house(home)["incubator"]
		var keep: Array = []
		for e in inc:
			if int(e.get("due", 0)) > day + 1 or room(home) <= 0:
				keep.append(e)
				continue
			var sid := str(e["species"])
			var v := _child_variant(sid, "", "", rng)
			var kid := _make(sid, home, "", day + 1, v, [])
			lines.append("A %s hatched in the %s: meet %s!" % [("chick" if sid == "chicken" else "duckling" if sid == "duck" else display_name(sid).to_lower()), home, str(animal(kid)["name"])])
		house(home)["incubator"] = keep
	return lines


## Is a product id something this farm can make now (favour letters, quests)? Held stock counts.
static func source_ok(item: String) -> bool:
	if GameState.count(item) > 0:
		return true
	var p: Dictionary = (data()["products"] as Dictionary).get(item, {})
	for uid in animals():
		var a: Dictionary = animals()[uid]
		if (p.get("species", []) as Array).has(str(a.get("species", ""))):
			return true
	for raw in data()["processing"]:
		if ((data()["processing"][raw] as Array).has(item)) and source_ok(str(raw)):
			return true
	return false


## Every species this farm keeps right now.
static func owned_species() -> Array:
	var out: Array = []
	for uid in animals():
		var s := str((animals()[uid] as Dictionary).get("species", ""))
		if not out.has(s):
			out.append(s)
	return out


## Old saves: seed the roster from the builds and run.animals once (idempotent; run.ranch.legacy_done).
## Legacy node names map to uids (record "legacy"), so streaks become friendship and nothing is lost:
## migration may exceed a tier's capacity (no animal is ever dropped).
static func migrate() -> void:
	var d := st()
	if bool(d.get("legacy_done", false)):
		return
	d["legacy_done"] = true
	d["ver"] = VER
	var r := GameState.run
	var old: Dictionary = r.get("animals", {}) if r.get("animals", null) is Dictionary else {}
	for k in (data().get("legacy_moved", {}) as Dictionary):
		if old.has(k):
			var to := str(data()["legacy_moved"][k])
			var keep: Variant = old[k]
			if old.has(to) and old[to] is Dictionary and keep is Dictionary and int((old[to] as Dictionary).get("streak", 0)) >= int((keep as Dictionary).get("streak", 0)):
				keep = old[to]
			old[to] = keep
			old.erase(k)
	var fl: Dictionary = r.get("flags", {}) if r.get("flags", null) is Dictionary else {}
	var day := _day()
	var young := int(rule("young_days", 7))
	for row in data().get("legacy", []):
		var nm := str(row[0])
		var home := str(row[3])
		if Builds.built_tier(home) < int(row[4]):
			continue
		var born := 1
		var flag := str(row[5])
		if flag != "":
			born = int(fl.get(flag, day))
		_legacy_one(nm, str(row[1]), str(row[2]), home, born, born + (young if flag != "" else 0), old.get(nm, null))
	# Incubator hatchlings (run.coop_hatch: hatch days) -> chickens, or eggs still warming.
	var hatch: Array = r.get("coop_hatch", []) if r.get("coop_hatch", null) is Array else []
	if Builds.built_tier("coop") >= 2:
		for i in hatch.size():
			var hd := int(hatch[i])
			if hd > day:
				house("coop")["incubator"].append({"species": "chicken", "due": hd, "q": ""})
			else:
				_legacy_one("hatch_%d" % i, "chicken", "white", "coop", hd, hd + young, old.get("hatch_%d" % i, null))
	r.erase("coop_hatch")
	for k in fl.keys():
		if str(k).begins_with("hatch_peep_"):
			fl.erase(k)


static func _legacy_one(nm: String, sid: String, variant: String, home: String, born: int, adult: int, rec: Variant) -> void:
	for uid in animals():
		if str((animals()[uid] as Dictionary).get("legacy", "")) == nm:
			return
	var uid := _make(sid, home, "", born, variant)
	var a: Dictionary = animal(uid)
	a["adult_day"] = adult
	a["legacy"] = nm
	if rec is Dictionary:
		var st0: Dictionary = rec
		a["friend"] = mini(int(rule("friend_max", 1000)), int(st0.get("streak", 0)) * int(rule("legacy_streak_friend", 50)))
		a["last_pet"] = int(st0.get("last_pet", -1))
		a["last_fed"] = int(st0.get("fed", -1))
		a["made_day"] = int(st0.get("made", -1))
		a["mood"] = 70 if a["last_fed"] >= _day() - 1 else 50


## Legacy node name -> uid (P2 can keep old node names working while it moves spawns to the roster).
static func uid_of_legacy(nm: String) -> String:
	for uid in animals():
		if str((animals()[uid] as Dictionary).get("legacy", "")) == nm:
			return uid
	return ""


## Is an item a ranch product (raw animal goods: sell perk, bag sort)?
static func is_good(item: String) -> bool:
	return (data()["products"] as Dictionary).has(item)
