class_name Romance
## Dating and marriage (CONDUCT 7 P1), G-rated like Stardew: a Bouquet at ♥8 starts
## dating, two dates + ♥10 + a Farmhouse let you propose with the Sea-Glass Locket,
## the wedding comes three days later (Wedding scene in house.gd's morning), then the
## spouse lives with you, helps on the farm overnight and talks to you every day.
## Data: data/romance.json from tools/gen_romance.py. State: run["romance"].
## Rules: one partner at a time; no 8-heart cap for anyone; no gender checks anywhere
## (any hero can date any candidate); no divorce in v1; per save slot.

const DEFAULT := {"dating": "", "since": 0, "dates": {}, "invited": {}, "date": {}, "engaged": "",
	"engaged_day": 0, "wedding_day": 0, "spouse": "", "married_day": 0, "talk_day": -1,
	"ex": {}, "chore_day": -1, "invite_day": -99}

static var _d: Dictionary = {}
static var skip_scenes := false  # tests: no dialogue, no fades


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/romance.json")
	return _d


static func rule(k: String) -> float:
	return float((data().get("rules", {}) as Dictionary).get(k, 0))


## run["romance"] with every key (old saves get the default; friendship is never touched).
static func st() -> Dictionary:
	var r: Variant = GameState.run.get("romance", null)
	if not r is Dictionary:
		r = DEFAULT.duplicate(true)
		GameState.run["romance"] = r
	for k in DEFAULT:
		if not (r as Dictionary).has(k):
			r[k] = (DEFAULT[k] as Variant) if not (DEFAULT[k] is Dictionary) else (DEFAULT[k] as Dictionary).duplicate()
	return r


static func cand(id: String) -> Dictionary:
	return (data().get("candidates", {}) as Dictionary).get(id, {})


static func candidates() -> Array:
	var out: Array = []
	var arc := "penguins" if GameState.is_penguins() else "gangsters"
	for id: String in (data().get("candidates", {}) as Dictionary):
		if arc in (cand(id).get("arcs", []) as Array) and GameState.npcs.has(id) and not GameState.run["flags"].has(id + "_gone"):
			out.append(id)
	return out


static func is_candidate(id: String) -> bool:
	return id in candidates() and not Npc.is_kid(id)


static func status(id: String) -> String:
	var s := st()
	if str(s["spouse"]) == id:
		return "spouse"
	if str(s["engaged"]) == id:
		return "engaged"
	if str(s["dating"]) == id:
		return "dating"
	if (s["ex"] as Dictionary).has(id):
		return "ex"
	return ""


static func partner() -> String:
	var s := st()
	for k in ["spouse", "engaged", "dating"]:
		if str(s[k]) != "":
			return str(s[k])
	return ""


static func spouse() -> String:
	return str(st()["spouse"])


static func is_married() -> bool:
	return spouse() != ""


static func name_of(id: String) -> String:
	return str(GameState.npcs.get(id, {}).get("name", id.capitalize()))


static func spouse_name() -> String:
	return name_of(spouse()) if is_married() else ""


static func any_at(hearts: int) -> bool:
	for id in candidates():
		if GameState.friend_hearts(id) >= hearts:
			return true
	return false


static func _fill(t: String, id: String) -> String:
	var place := str(st().get("date", {}).get("place", ""))
	return t.replace("{name}", name_of(id)).replace("{you}", str(GameState.names().get("character", "friend"))).replace("{pet}", str(GameState.names().get("pet", "the pup"))).replace("{place}", place)


static func _lines(raw: Array, id: String) -> Array:
	var out: Array = []
	var gang := not GameState.is_penguins()
	for l0: Variant in raw:
		var l: Dictionary = (l0 as Dictionary).duplicate() if l0 is Dictionary else {"who": name_of(id), "text": str(l0)}
		if gang and l.has("text_gangsters"):
			l["text"] = l["text_gangsters"]
		l["text"] = _fill(str(l["text"]), id)
		if str(l.get("mood", "")) == "love" and not Art.has("portraits/" + _portrait(id), "love"):
			l["mood"] = "happy"  # no blush face drawn for this one
		out.append(l)
	return out


static func _portrait(id: String) -> String:
	var pp := Dialogue.portrait_for(name_of(id))
	return pp if pp != "" else str(GameState.npcs.get(id, {}).get("portrait", id))


static func _shared(key: String, id: String) -> Array:
	var v: Variant = (data().get("shared", {}) as Dictionary).get(key, [])
	if v is String:
		return _lines([{"who": name_of(id), "text": v}], id)
	var out: Array = []
	for t in v:
		out.append({"who": name_of(id), "text": str(t)})
	return _lines(out, id)


# ---------------------------------------------------------------- the rules

## "" = yes, else the shared line key that says why not.
static func bouquet_why(id: String) -> String:
	if not is_candidate(id):
		return "not"
	var s := st()
	var p := partner()
	if p == id:
		return "already"
	if p != "":
		return "taken"
	if (s["ex"] as Dictionary).has(id) and int(GameState.run["day"]) - int(s["ex"][id]) < int(rule("ex_days")):
		return "ex"
	if GameState.friend_hearts(id) < int(rule("bouquet_hearts")):
		return "too_soon"
	return ""


static func can_bouquet(id: String) -> bool:
	return bouquet_why(id) == "" and not GameState.visiting()


static func house_ok() -> bool:
	return Builds.built_tier("house") >= int(rule("house_tier"))


static func propose_why(id: String) -> String:
	var s := st()
	if str(s["dating"]) != id:
		return "not"
	if GameState.friend_hearts(id) < int(rule("propose_hearts")):
		return "too_soon"
	if int((s["dates"] as Dictionary).get(id, 0)) < int(rule("dates_needed")):
		return "not_yet_dates"
	if not house_ok():
		return "not_yet_house"
	return ""


static func can_propose(id: String) -> bool:
	return propose_why(id) == "" and not GameState.visiting()


## The wedding day: `after` days on, never a festival day or a Sunday (market/chapel).
static func pick_wedding_day(from_day: int) -> int:
	var d := from_day + int(rule("wedding_after"))
	for i in 14:
		if (d % 7) != 0 and dos(d) != GameState.FESTIVAL_DAY:
			return d
		d += 1
	return d


static func dos(day: int) -> int:
	return (day - 1) % GameState.DAYS_PER_SEASON + 1


static func wedding_due() -> bool:
	var s := st()
	return str(s["engaged"]) != "" and int(GameState.run["day"]) >= int(s["wedding_day"])


# ---------------------------------------------------------------- state changes (no UI)

static func start_dating(id: String) -> void:
	var s := st()
	s["dating"] = id
	s["since"] = int(GameState.run["day"])
	(s["ex"] as Dictionary).erase(id)
	GameState.run["flags"]["dating_" + id] = true


static func stay_friends(id: String) -> void:
	var s := st()
	if str(s["dating"]) != id:
		return
	s["dating"] = ""
	s["date"] = {}
	s["ex"][id] = int(GameState.run["day"])


static func engage(id: String) -> void:
	var s := st()
	s["engaged"] = id
	s["engaged_day"] = int(GameState.run["day"])
	s["wedding_day"] = pick_wedding_day(int(GameState.run["day"]))
	GameState.run["flags"]["engaged"] = true


static func marry() -> void:
	var s := st()
	var id := str(s["engaged"])
	if id == "":
		return
	s["spouse"] = id
	s["married_day"] = int(GameState.run["day"])
	s["engaged"] = ""
	s["dating"] = ""
	s["date"] = {}
	GameState.run["flags"]["married"] = true
	GameState.run["flags"]["married_" + id] = true


## A date finished: counts toward the proposal; the answer's friendship.
static func date_done(id: String, friend: int) -> void:
	var s := st()
	s["dates"][id] = int((s["dates"] as Dictionary).get(id, 0)) + 1
	s["date"] = {}
	GameState.add_friend(id, maxi(0, friend))


# ---------------------------------------------------------------- talk hook

## In every talk path right after Hearts.talk. True = this handled the talk.
static func talk(m: GameMap, id: String) -> bool:
	if not is_candidate(id) and spouse() != id:
		return false
	var held := GameState.held_item()
	if held in ["bouquet", "sea_locket"]:
		if GameState.visiting():
			m.hud.toast(str(data()["shared"]["no_guest"]), Color(1, 0.8, 0.8))
			return true
		if held == "bouquet":
			await _bouquet(m, id)
		else:
			await _locket(m, id)
		return true
	if spouse() == id:
		return await _spouse_talk(m, id)
	if str(st()["dating"]) == id:
		return await Dates.talk(m, id)
	return false


static func _bouquet(m: GameMap, id: String) -> void:
	var why := bouquet_why(id)
	if why == "already":
		await m.say([{"who": name_of(id), "text": "We're already together, silly. Keep those for the table at home."}])
		return
	if why != "":
		await m.say(_shared(why if why != "not" else "too_soon", id))
		return
	GameState.add_item("bouquet", -1)
	start_dating(id)
	await m.say(_lines(cand(id).get("bouquet", []), id))
	m.hud.toast("Dating %s ♥" % name_of(id), Color(1, 0.7, 0.85))
	Music.instance(m.get_tree()).sfx("j_heart", "levelup")


static func _locket(m: GameMap, id: String) -> void:
	var why := propose_why(id)
	if why == "not":
		await m.say([{"who": name_of(id), "text": "That's beautiful... but I think it's meant for someone special. Maybe start with flowers?"}])
		return
	if why != "":
		await m.say(_shared(why, id))
		return
	GameState.add_item("sea_locket", -1)
	engage(id)
	Music.instance(m.get_tree()).sfx("j_proposal", "j_heart")
	var lines := _lines(cand(id).get("propose", []), id)
	if not lines.is_empty() and Art.has("ui", "cut_proposal"):
		lines[0]["pic"] = "cut_proposal"
	await m.say(lines)
	var wd := int(st()["wedding_day"])
	m.hud.toast("Engaged to %s! Wedding on %s %d" % [name_of(id), GameState.season_of(wd).capitalize(), dos(wd)], Color(1, 0.75, 0.9))


static func _spouse_talk(m: GameMap, id: String) -> bool:
	var s := st()
	var today := int(GameState.run["day"])
	if GameState.visiting():  # the host's day must not stamp talk_day (it would skip our own days at home)
		await m.say(_lines([{"who": name_of(id), "text": "Fancy meeting you here! Say hi to your friends for me.", "mood": "happy"}], id))
		return true
	if int(s["talk_day"]) == today:
		await m.say(_lines([{"who": name_of(id), "text": ["Love you.", "Go on, the farm's waiting. I'll be here.", "Come here, you. ...There. A hug for the road."][today % 3], "mood": "love"}], id))
		return true
	s["talk_day"] = today
	GameState.add_friend(id, 10)
	await m.say(_lines([{"who": name_of(id), "text": spouse_line(id), "mood": "love" if today % 2 == 0 else "happy"}], id))
	if today > int(s["married_day"]) and (today - int(s["married_day"])) % 112 == 0:
		await m.say(_lines([{"who": name_of(id), "text": "Happy anniversary, {you}. Another year. My favourite year so far.", "mood": "love"}], id))
		GameState.add_item(str(cand(id).get("dish", "cake")), 1)
	return true


## Today's spouse line: rain, morning or evening pools (season-free text).
static func spouse_line(id: String) -> String:
	var sp: Dictionary = cand(id).get("spouse", {})
	var t := int(GameState.run["time"]) / 60
	var pool: Array = sp.get("morning", [])
	if GameState.is_wet() and not (sp.get("rain", []) as Array).is_empty():
		pool = sp["rain"]
	elif t >= 17:
		pool = sp.get("evening", pool)
	if pool.is_empty():
		return "Hi, love."
	return _fill(str(pool[int(GameState.run["day"]) % pool.size()]), id)


# ---------------------------------------------------------------- routine + farm help

## Npc.place_now hook: where the spouse is ("" = not the spouse, use the routine).
## At home (hidden in town) except 9-17 on their job days, when they keep working.
static func spouse_place(npc_id: String) -> String:
	if npc_id == "" or spouse() != npc_id:
		return ""
	var hour := int(GameState.run["time"]) / 60.0
	if GameState.festival_today() != "" and hour >= 9.0 and hour < 18.0:
		return ""  # the festival: with everyone on the plaza
	if is_job_time():
		return "work"
	return "farm_home"


static func is_job_time() -> bool:
	if not is_married():
		return false
	var hour := int(GameState.run["time"]) / 60.0
	return is_job_day(int(GameState.run["day"])) and hour >= 9.0 and hour < 17.0


## JSON numbers are floats: compare as ints (Array.has(2) misses 2.0).
static func is_job_day(day: int) -> bool:
	for jd: Variant in cand(spouse()).get("job_days", []):
		if int(jd) == day % 7:
			return true
	return false


## GameState.sleep hook: pick tonight's chore. Returns true when the spouse waters.
static func overnight(report: Dictionary) -> bool:
	if not is_married():
		return false
	var s := st()
	var day := int(GameState.run["day"])
	if int(s["married_day"]) == day:
		return false  # the wedding night: no chores
	var chore := ""
	if int(s["married_day"]) == day - 1 or int(s["chore_day"]) < 0:
		chore = "breakfast"
	elif randf() < rule("chore_chance"):
		# C11a P5: only chores there's work for: animals once the farm keeps some, water
		# only when something is planted.
		var opts: Array = ["fence", "breakfast", "pup"]
		if Mail.has_animals():
			opts.append("animals")
		if not GameState.is_wet() and _planted():
			opts.append("water")
			opts.append("water")
		chore = str(opts[randi() % opts.size()])
	if chore == "":
		return false
	s["chore_day"] = day
	var id := spouse()
	match chore:
		"animals":
			feed_all(day)
		"breakfast":
			GameState.add_item(str(cand(id).get("dish", "bread")), 1)
		"pup":
			GameState.add_xp("pup", 10)
		"fence":
			GameState.add_item("wood", 3)
	report["spouse"] = {"chore": chore, "who": id}
	return chore == "water"


## Anything planted on the farm (so a watering chore has work)?
static func _planted() -> bool:
	var farm: Dictionary = GameState.run.get("farm", {})
	for k in farm:
		if farm[k] is Dictionary and str((farm[k] as Dictionary).get("crop", "")) != "":
			return true
	return false


## The spouse feeds every animal for tomorrow and gives each a pet (keeps streaks): the
## Ranch roster (last_fed / Ranch.pet) and the legacy run.animals entries. Returns how many.
static func feed_all(day: int) -> int:
	var n := 0
	for uid: String in Ranch.animals():
		var a: Dictionary = Ranch.animals()[uid]
		a["last_fed"] = day + 1
		Ranch.pet(uid)
		n += 1
	var all: Dictionary = GameState.run.get("animals", {})
	for nm in all:
		if all[nm] is Dictionary:
			all[nm]["fed"] = day + 1
			n += 1
	return n


## SleepReport line for the chore ("" = none).
static func chore_line(report: Dictionary) -> String:
	var sp: Variant = report.get("spouse", null)
	if not sp is Dictionary:
		return ""
	var id := str(sp["who"])
	return _fill(str((cand(id).get("spouse", {}).get("chore", {}) as Dictionary).get(str(sp["chore"]), "")), id)


# ---------------------------------------------------------------- UI text

## Social tab line under a candidate/partner ("" = nothing to say).
static func social_line(id: String) -> String:
	var stt := status(id)
	var s := st()
	match stt:
		"spouse":
			return "   ♥ Spouse · married on day %d" % int(s["married_day"])
		"engaged":
			var n := int(s["wedding_day"]) - int(GameState.run["day"])
			return "   ♥ Engaged · wedding %s" % ("today" if n <= 0 else ("tomorrow" if n == 1 else "in %d days" % n))
		"dating":
			var need: Array = []
			var dn := int((s["dates"] as Dictionary).get(id, 0))
			if dn < int(rule("dates_needed")):
				need.append("%d/%d dates" % [dn, int(rule("dates_needed"))])
			if GameState.friend_hearts(id) < int(rule("propose_hearts")):
				need.append("♥%d" % int(rule("propose_hearts")))
			if not house_ok():
				need.append("a Farmhouse")
			return "   ♥ Dating" + (" · to propose: " + ", ".join(need) if not need.is_empty() else " · ready: give the Sea-Glass Locket")
	if not is_candidate(id) or partner() != "":
		return ""
	return "   Single · a Bouquet at ♥%d starts dating" % int(rule("bouquet_hearts"))


## Hero tab / journal line.
static func hero_line() -> String:
	if is_married():
		return "Married to %s · day %d" % [spouse_name(), int(st()["married_day"])]
	var p := partner()
	if p == "":
		return ""
	return ("Engaged to %s" if status(p) == "engaged" else "Dating %s") % name_of(p)


## Quests-tab rows for QuestTracker: [{text}] for a date tonight or a wedding soon.
static func tracker_rows() -> Array:
	var s := st()
	var out: Array = []
	var dt: Dictionary = s.get("date", {})
	if not dt.is_empty() and int(dt.get("day", -1)) == int(GameState.run["day"]):
		out.append({"text": "Meet %s at %s after %s" % [name_of(str(dt["id"])), str(dt["place"]), Dates.hour_text(int(dt["hours"][0]))]})
	if str(s["engaged"]) != "":
		out.append({"text": "Your wedding with %s: %s %d" % [name_of(str(s["engaged"])), GameState.season_of(int(s["wedding_day"])).capitalize(), dos(int(s["wedding_day"]))]})
	return out


## Shop hook: romance stock (bouquet at Maple's once anyone's at ♥8; the locket at
## Marlowe's in the penguin arc / Maple's in the gangster arc once your sweetheart is ♥10).
static func shop_extra(shop: String) -> Array:
	var out: Array = []
	if shop == "store" and any_at(int(rule("bouquet_hearts"))):
		out.append("bouquet")
	var locket_shop := "marlowe" if GameState.is_penguins() else "store"
	var p := str(st()["dating"])
	if shop == locket_shop and p != "" and GameState.friend_hearts(p) >= int(rule("propose_hearts")):
		out.append("sea_locket")
	return out


## Epilogue fill: {spouse} name, or "".
static func epilogue_partner() -> String:
	return spouse_name() if is_married() else (name_of(partner()) if partner() != "" else "")
