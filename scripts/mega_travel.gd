class_name MegaTravel
extends RefCounted
## Travel points to the Round 13 mega regions (data/mega_travel.json, written by
## tools/gen_mega_new.py from tools/mega_regions_new.py). Each region has one
## way in from the home world (a sled, a caravan, a fairy ring, a balloon, a night
## train, a black limo) with a keeper who opens it with a short hook quest once the
## story is far enough along. Every hub has the same vehicle waiting to take you
## home, or on to any other mega hub whose own line you have opened (C14 TravelNet).

static var _data: Dictionary = {}
const CLEARABLE := ["weed", "weeds", "grass", "rock", "stone", "stick", "twig", "forage", "log", "stump", "bush", "fruit_drop"]


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/mega_travel.json").get("regions", {})
	return _data


static func reg(id: String) -> Dictionary:
	return data().get(id, {})


static func arc_ok(r: Dictionary) -> bool:
	var a := str(r.get("arc", "both"))
	return a == "both" or a == str(GameState.run.get("arc", ""))


static func is_open(id: String) -> bool:
	return GameState.run["flags"].has("mega_%s_open" % id)


## The story is far enough along for the keeper to ask for help.
static func can_start(r: Dictionary) -> bool:
	return GameState.progress_tier() >= int(r.get("unlock", {}).get("tier", 0)) and GameState._cond_ok(r.get("unlock", {}).get("when", {}))


static func hub_of(id: String) -> String:
	return str(reg(id).get("hub", ""))


## Which mega region (new ones) a scene belongs to, or "".
static func region_of(scene: String) -> String:
	for id: String in data():
		if scene in (data()[id].get("areas", []) as Array):
			return id
	return ""


## Put this map's travel points down (home-world entries) and post the keepers' letters.
static func on_enter(m: GameMap) -> void:
	if data().is_empty() or not GameState.run.has("flags"):
		return
	var sid := m.scene_id()
	if region_of(sid) != "":
		GameState.run["flags"]["mseen_" + region_of(sid)] = true  # S1 P2: Wide World / Gilt Edge
	for id: String in data():
		var r: Dictionary = data()[id]
		if not arc_ok(r):
			continue
		_mail(id, r)
		var e: Dictionary = r.get("entry", {})
		if str(e.get("scene", "")) != sid:
			continue
		if not shows(id, r):
			continue  # Tom (C4): no "locked" limo in the field from day 1 — it arrives with the keeper's letter
		var c := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
		if m.things.has(c):
			# Weeds, stones or forage that grew on the spot make way; anything else stays.
			if str(m.things[c].get("type", "")) not in CLEARABLE:
				continue
			m.things.erase(c)
			if m.props.has(c):
				(m.props[c] as Node).queue_free()
				m.props.erase(c)
		# Keep the cells round a small gate (fairy ring) clear of tall grass and clutter so it reads
		# (two cells round a ground ring: one left it a speck in a grass field, C2).
		var g := str(e.get("group", "props"))
		var cr := 2 if g == "nature" else 1
		for dx in range(-cr, cr + 1):
			for dy in range(-cr, cr + 1):
				var n := c + Vector2i(dx, dy)
				if n != c and m.things.has(n) and str(m.things[n].get("type", "")) in ["grass", "weed", "weeds", "stick", "twig"]:
					m.things.erase(n)
					if m.props.has(n):
						(m.props[n] as Node).queue_free()
						m.props.erase(n)
		if Art.has(g, str(e.get("prop", ""))):
			# A ground ring is small art (the fairy ring is 49 px): drawn a little larger so it reads as a way through.
			var sp0 := m.prop(g, str(e["prop"]), c, int(e.get("w", 0)), 0.0, false, float(e.get("scale", 0.8 if g == "nature" else 0.5)))
			# A vehicle or booth is solid along its base row (you can't walk through the
			# limo or the caravan); a ground ring (nature group) stays walk-on.
			if sp0 and sp0.texture and g != "nature":
				var k := int(roundi(sp0.texture.get_width() * sp0.scale.x / GameMap.TILE) - 1) / 2
				for dx in range(-k, k + 1):
					var n := c + Vector2i(dx, 0)
					if dx != 0 and not m.things.has(n) and not m._exit_at(n):
						m.block_rect(n.x, n.y, 1, 1)
		m.set_thing(c.x, c.y, {"type": "mega_gate", "mega": id, "hint": "A: " + str(e.get("label", "travel"))}, true)
		var kp := str(r.get("keeper_sprite", ""))
		if kp != "" and CharacterLibrary.has_character(kp):
			var sp := CharacterLibrary.make_sprite(kp)
			if sp:
				var off: Array = e.get("keeper_at", [-1, 0])
				sp.position = m.cell_center(c + Vector2i(int(off[0]), int(off[1])))
				sp.play("idle")
				m.add_child(sp)
	TravelNet.on_enter(m)  # C14: station props + desks (after the keepers' gates), arrival beside the station


## The travel point is out in the world once the keeper's letter has come (or the way is open).
static func shows(id: String, r: Dictionary) -> bool:
	if is_open(id):
		return true
	if r.has("mail"):
		return GameState.run["flags"].has("mega_%s_mail" % id)
	return can_start(r)


## The story steps that raise GameState.progress_tier, worded per arc (C4 c4_11 #3:
## "chapter N" was wrong in the gangster arc; name the real step instead).
const TIER_STEPS := {
	"penguins": [["clear_meadow", "you find what's howling in the east meadow"],
		["spark", "you refine your first crystal at the Crystal Resonator (or beat the Grump Commander)"],
		["sky_stair", "you climb the great tree in the forest"],
		["teleporter", "you power the moon teleporter"]],
	"gangsters": [["clear_meadow", "you check out the east meadow"],
		["docks", "you beat the dock boss"],
		["neon", "you beat Flame in the neon district"],
		["uptown", "you beat the President's Enforcer"]],
}
const TIER_ALT := {"spark": ["wastes_gate", "docks"], "sky_stair": ["neon"], "teleporter": ["uptown"]}


## "Opens after you beat the Docks boss." — the next story step this way waits for.
static func gate_words(r: Dictionary) -> String:
	var need := int(r.get("unlock", {}).get("tier", 0))
	var arc := str(GameState.run.get("arc", "penguins"))
	var steps: Array = TIER_STEPS.get(arc, TIER_STEPS["penguins"])
	var have := GameState.progress_tier()
	if have < need:
		# The tier counts steps done in any order: name the first one not done yet.
		for st: Array in steps:
			var done := GameState.quest_done(str(st[0]))
			for alt in TIER_ALT.get(str(st[0]), []):
				done = done or GameState.quest_done(str(alt))
			if not done:
				return "Opens after %s." % str(st[1])
	var hint := str(r.get("unlock", {}).get("hint", ""))
	return hint if hint != "" else "Opens a little later in the story."


## One letter from the keeper when their way first opens up for you.
static func _mail(id: String, r: Dictionary) -> void:
	var key := "mega_%s_mail" % id
	if GameState.run["flags"].has(key) or is_open(id) or not can_start(r) or not r.has("mail"):
		return
	if not Mail.intro_ok():
		return  # C9: an old save catching up gets these a couple a day, not all at once
	Mail.intro_sent()
	GameState.run["flags"][key] = true
	Mail.send(str(r["mail"].get("from", r.get("keeper", ""))), str(r["mail"].get("text", "")), "news")


static func gate(m: GameMap, thing: Dictionary) -> void:
	if thing.has("station"):  # C14: a TravelNet station desk
		await TravelNet.desk(m, str(thing["station"]))
		return
	if bool(thing.get("home", false)):
		await _hub_gate(m, str(thing.get("mega", "")))
		return
	var id := str(thing.get("mega", ""))
	var r := reg(id)
	if r.is_empty():
		return
	var who := str(r.get("keeper", ""))
	var L: Dictionary = r.get("lines", {})
	if not arc_ok(r):
		Music.instance(m.get_tree()).sfx("nope", "thud")
		m.hud.toast(str(L.get("wrong_arc", "Not for you.")))
		return
	if is_open(id):
		await _travel_menu(m, id)
		return
	if not can_start(r):
		Music.instance(m.get_tree()).sfx("locked", "nope")
		await m.say([{"who": who, "text": str(L.get("locked", "Not yet."))}])
		var hint := str(r.get("unlock", {}).get("hint", {}).get(str(GameState.run.get("arc", "")), ""))
		m.hud.toast(hint if hint != "" else gate_words(r), Color(1, 0.85, 0.6))
		return
	var qid := str(r.get("quest", ""))
	var d := GameState._quest_def(qid)
	if not GameState.has_quest(qid):
		var offer: Array = L.get("offer", ["Will you help?"])
		var seq: Array = []
		for t in offer.slice(0, offer.size() - 1):
			seq.append({"who": who, "text": str(t)})
		if not seq.is_empty():
			await m.say(seq)
		var dlg := Dialogue.instance(m.get_tree())
		dlg.say([{"who": who, "text": str(offer[offer.size() - 1]), "choice": ["I'll do it", "Not now"], "key": ""}])
		await dlg.finished
		if dlg.last_choice == 0:
			GameState.add_quest(qid, str(d.get("text", "Help the keeper.")))
			Quests.announce(m, str(d.get("text", "")))
			await m.say([{"who": who, "text": str(L.get("yes", "Good. I'll be here."))}])
		return
	if not GameState.quest_done(qid):
		if not Quests._done(d):
			await m.say([{"who": who, "text": str(L.get("wait", "Still waiting: " + str(d.get("text", "")).to_lower()))}])
			return
		var dw: Dictionary = d.get("done_when", {})
		if bool(d.get("take", false)):
			if dw.has("item"):
				GameState.add_item(str(dw["item"][0]), -int(dw["item"][1]))
			for pair in dw.get("items", []):
				GameState.add_item(str(pair[0]), -int(pair[1]))
		var seq2: Array = []
		for t in L.get("done", ["That's everything. We can go."]):
			seq2.append({"who": who, "text": str(t)})
		await m.say(seq2)
		if GameState.complete_quest(qid):
			m.hud.toast(GameMap.quest_done_text(qid), Color(1, 0.9, 0.4))
	GameState.run["flags"]["mega_%s_open" % id] = true  # (the quest reward sets it too)
	Music.instance(m.get_tree()).sfx("unlock", "j_region")  # the route opens
	for nid in MegaRegion.check_unlocks():  # its map tab opens now, not on arrival (c4_11)
		m.hud.toast("New map tab: %s (Menu > Map)" % str(MegaRegion.get_r(str(nid)).get("name", nid)), Color(0.85, 0.95, 1.0))
	await _travel_menu(m, id)


static func _travel_menu(m: GameMap, id: String) -> void:
	var r := reg(id)
	var lid := "mega_" + id
	var tn := not TravelNet.link(lid).is_empty()
	if tn:
		TravelNet.unlock(lid, "keeper")  # C14: the keeper's ride is a T3 TravelNet line (fare until free, ride scene)
	var fare := " (%s)" % TravelNet.fare_words(lid) if tn else ""
	var dlg := Dialogue.instance(m.get_tree())
	dlg.say([{"who": str(r.get("keeper", "")), "text": str(r.get("lines", {}).get("travel", "Ready when you are.")), "choice": ["Go to %s%s" % [str(r.get("hub_name", r.get("name", ""))), fare], "Not now"], "key": ""}])
	await dlg.finished
	if dlg.last_choice != 0:
		return
	if not tn:
		go_hub(m, id)
		return
	var why := TravelNet.why_not(lid, id + "_home")
	if why != "":
		Music.instance(m.get_tree()).sfx("locked", "nope")
		m.hud.toast(why, Color(1, 0.85, 0.6))
		return
	await TravelNet.ride(lid, m, id + "_home")


## The ride's sound, both ways (C4 c4_12 #5): data "sfx_go"/"sfx_back" win, else these.
const TRAVEL_SFX := {"gloamwood": ["fairy_ring", "fairy_ring"], "sunscorch": ["horse", "horse"], "ironline": ["train_depart", "train_depart"],
	"frostpeak": ["sled_bells", "sled_bells"], "windward": ["airship_whoosh", "airship_whoosh"], "giltcity": ["car_start", "car_door"]}


static func travel_sfx(id: String, back: bool) -> String:
	var r := reg(id)
	var key := "sfx_back" if back else "sfx_go"
	if r.has(key):
		return str(r[key])
	var pair: Array = TRAVEL_SFX.get(id, [])
	if not pair.is_empty():
		return str(pair[1 if back else 0])
	return str(r.get("sfx", "door"))


## Play the ride sound; a new cue not imported yet falls back to the older one.
static func ride_sfx(m: GameMap, id: String, back: bool) -> void:
	var mu := Music.instance(m.get_tree())
	var n := travel_sfx(id, back)
	if not mu.has_sfx(n):
		n = {"fairy_ring": "teleport"}.get(n, "door")
	mu.sfx(n, "door")


static func go_hub(m: GameMap, id: String) -> void:
	var r := reg(id)
	var sp: Array = r.get("hub_spawn", [10, 10])
	ride_sfx(m, id, false)
	m.go_to(hub_of(id), Vector2((float(sp[0]) + 0.5) * GameMap.TILE, (float(sp[1]) + 0.5) * GameMap.TILE), "up")


## The vehicle in a hub: home, or on to another open mega hub.
static func _hub_gate(m: GameMap, id: String) -> void:
	var r := reg(id)
	if not TravelNet.station(id + "_hub").is_empty():
		# C14 (c14_05-02): every hop from a hub is its own TravelNet line (home = T3,
		# other hubs = T4 per-link unlocks, the airship/charter plane), never a free menu.
		TravelNet.unlock("mega_" + id, "keeper")
		await TravelNet.desk(m, id + "_hub")
		return
	var e: Dictionary = r.get("entry", {})
	var opts: Array = ["Home (%s)" % str(e.get("home_name", str(e.get("scene", "")).capitalize()))]
	var dests: Array = [""]
	for oid: String in data():
		if oid != id and arc_ok(data()[oid]) and is_open(oid):
			opts.append("On to %s" % str(data()[oid].get("hub_name", oid)))
			dests.append(oid)
	opts.append("Stay")
	var dlg := Dialogue.instance(m.get_tree())
	dlg.say([{"who": str(r.get("keeper", "")), "text": str(r.get("lines", {}).get("home", "Heading back?")), "choice": opts, "key": ""}])
	await dlg.finished
	var i := dlg.last_choice
	if i < 0 or i >= dests.size():
		return
	if str(dests[i]) != "":
		go_hub(m, str(dests[i]))
		return
	var hs: Array = e.get("spawn", [e["cell"][0], int(e["cell"][1]) + 2])
	ride_sfx(m, id, true)
	m.go_to(str(e["scene"]), Vector2((float(hs[0]) + 0.5) * GameMap.TILE, (float(hs[1]) + 0.5) * GameMap.TILE), "down")
