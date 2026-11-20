class_name Crew
## The gangster crew (data/crew.json): who's recruited (flag crew_<id>), their
## loyalty (run["crew"][id] = 0..3), where they stand in the world, and the
## passive perks they give by loyalty. Recruiting happens in story.json beats.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/crew.json")
	# Register members as NPCs (gangster arc only) so names, portraits and
	# friendship work; a penguin run in the same session must not list them.
	if not GameState.run.is_empty() and not GameState.is_penguins():
		var mem: Dictionary = _data.get("members", {})
		for id in mem:
			if not GameState.npcs.has(id):
				var mdef: Dictionary = mem[id]
				GameState.npcs[id] = {"name": str(mdef["name"]), "sprite": str(mdef.get("sprite", "")), "portrait": str(mdef.get("sprite", "")) if Art.has("portraits/" + str(mdef.get("sprite", "")), "neutral") else "gambler", "role": str(mdef.get("role", "")), "routine": [], "likes": ["thug_cash", "root_beer", "coffee"], "dislikes": ["turnip"]}
	return _data


static func members() -> Dictionary:
	return data().get("members", {})


static func recruited(id: String) -> bool:
	return GameState.run["flags"].has("crew_" + id)


static func all_recruited() -> Array:
	var out: Array = []
	for id in members():
		if recruited(id):
			out.append(id)
	return out


static func loyalty(id: String) -> int:
	return int(GameState.run.get("crew", {}).get(id, 0))


static func _set_loyalty(id: String, n: int) -> void:
	var c: Dictionary = GameState.run.get("crew", {})
	c[id] = clampi(n, 0, 3)
	GameState.run["crew"] = c
	if n >= 3:
		GameState.run["flags"][id + "_loyal_3"] = true
		if id == "sasha":
			GameState.run["flags"]["doors_sasha"] = true  # Sasha gets you through the tower doors quietly


## Does any recruited member at loyalty >= n have this perk key?
## Perk keys: sell_bonus, meal_heal, shop_discount, raid_warning, sword, defence,
## rides, board_bonus, run_speed, heal_hideout, status_half, fence, doors.
static func perk_level(key: String) -> int:
	var who: String = PERK_OF.get(key, "")
	if who == "" or not recruited(who):
		return 0
	return member_level(who)


const PERK_OF := {"sell_bonus": "deuce", "meal_heal": "mama_rosa", "shop_discount": "specs", "raid_warning": "ladder", "sword": "vic", "defence": "val", "rides": "halo", "board_bonus": "dice", "run_speed": "the_kid", "heal_hideout": "doc", "status_half": "doc", "fence": "marlene", "doors": "sasha"}


## A member's working perk level: loyalty plus the Recruit Training Center drill
## (drilled crew count a step or two higher).
static func member_level(id: String) -> int:
	var drill := maxi(0, Builds.built_tier("training") - 1)
	return mini(3, loyalty(id) + drill)


## Crew tab text for one member: name, role and the perk that is really active.
static func roster_text(id: String) -> String:
	var mdef: Dictionary = members().get(id, {})
	var perks: Array = mdef.get("perks", [])
	var lv := member_level(id)
	var p := "no perk yet: talk at the hideout"
	if lv > 0 and lv <= perks.size():
		p = str(perks[lv - 1]) + (" (drilled)" if lv > loyalty(id) else "")
	return "%s — %s\n%s" % [str(mdef.get("name", id)), str(mdef.get("role", "")), p]


## Crew tab: the Marked and lieutenants who joined you (they live at the hideout).
static func also_with_you() -> Array:
	var out: Array = []
	for mid: String in Marked.all():
		if Marked.state(mid) == "crew":
			var md: Dictionary = Marked.all()[mid]
			out.append("%s \"%s\" (Marked)" % [str(md["name"]), str(md["epithet"])])
	var lts: Dictionary = Gift.data().get("lieutenants", {})
	for lid: String in lts:
		if GameState.run["flags"].has("lt_joined_" + lid):
			out.append("%s (%s, retired)" % [str(lts[lid]["name"]), str(lts[lid].get("title", "lieutenant"))])
	return out


## Place crew members in this map: unrecruited ones where the story expects
## them, recruited ones at the hideout.
static func place(m: GameMap) -> void:
	if GameState.is_penguins():
		return
	data()
	if recruited("sasha") and perk_level("doors") >= 3:
		GameState.run["flags"]["doors_sasha"] = true  # drilled crew count too (Training Center)
	for id in members():
		var mdef: Dictionary = members()[id]
		var at := Vector2i(-1, -1)
		if recruited(id):
			if m.scene_id() == "hideout":
				at = Vector2i(int(mdef["home"][0]), int(mdef["home"][1]))
			elif id == "halo" and perk_level("rides") >= 3 and m.scene_id() in ["docks", "neon", "uptown"]:
				# Loyalty 3: Halo waits by wherever you arrive (the player isn't spawned yet).
				var wp := (GameMap.next_spawn + m.offset()) if GameMap.next_spawn != Vector2.ZERO else m.default_spawn()
				at = m.world_to_cell(wp) + Vector2i(3, 1)
		elif GameState.run["flags"].has(id + "_refused"):
			continue  # walked off (Dice after the letter was sold)
		else:
			var b: Dictionary = mdef.get("before", {})
			if str(b.get("scene", "")) == m.scene_id():
				at = Vector2i(int(b["cell"][0]), int(b["cell"][1]))
		if at == Vector2i(-1, -1):
			continue
		_put(m, id, _free_near(m, at))
	if m.scene_id() == "hideout":
		_place_joined(m)


static func _free_near(m: GameMap, at: Vector2i) -> Vector2i:
	for r in 10:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := at + Vector2i(dx, dy)
				if m.in_content(cc) and not m.blocked.has(cc) and not m.things.has(cc) and not m.is_water_cell(cc):
					return cc
	return at


static func _put(m: GameMap, id: String, c: Vector2i) -> void:
	var npc := Npc.new()
	npc.map = m
	npc.setup(id, GameState.npcs[id], m.cell_center(c))
	npc.wander = 10.0
	m.add_child(npc)
	if m.get("npcs") != null:
		(m.get("npcs") as Array).append(npc)


## Hideout spots for the Marked and lieutenants who joined (C7 c7_14).
const JOINED_SPOTS := [[24, 26], [28, 28], [16, 24], [32, 20], [22, 30], [38, 22], [12, 22], [30, 32], [18, 30], [40, 26], [26, 10], [8, 24]]


## Marked with state "crew" (not the one following you) and the lieutenants who
## joined stand around the hideout and talk (lines from data/gifts.json).
static func _place_joined(m: GameMap) -> void:
	var n := 0
	# A partner you didn't pick at the farm gate waits here for a second ask (c7_14).
	if partner_waiting("big_jim"):
		_register("partner_big_jim", "Big Jim", "big_jim", "partner")
		_put(m, "partner_big_jim", _free_near(m, Vector2i(8, 18)))
	for id in joined_ids():
		if id == Companion.active_id():
			continue
		var at: Array = JOINED_SPOTS[n % JOINED_SPOTS.size()]
		n += 1
		_put(m, id, _free_near(m, Vector2i(int(at[0]), int(at[1]))))


## npc ids (mk_<id>, lt_<id>) of everyone who joined outside crew.json, registered as NPCs.
static func joined_ids() -> Array:
	var out: Array = []
	for mid: String in Marked.all():
		if Marked.state(mid) == "crew":
			var md: Dictionary = Marked.all()[mid]
			_register("mk_" + mid, str(md["name"]).split(" ")[0], str(md.get("char", "cyber")), "Marked")
			out.append("mk_" + mid)
	var lts: Dictionary = Gift.data().get("lieutenants", {})
	for lid: String in lts:
		if GameState.run["flags"].has("lt_joined_" + lid):
			_register("lt_" + lid, str(lts[lid]["name"]), str(lts[lid].get("char", "enforcer")), "retired lieutenant")
			out.append("lt_" + lid)
	return out


static func _register(id: String, nm: String, sprite: String, role: String) -> void:
	if GameState.npcs.has(id):
		return
	GameState.npcs[id] = {"name": nm, "sprite": sprite, "portrait": sprite if Art.has("portraits/" + sprite, "neutral") else "gambler", "role": role, "routine": [], "likes": ["root_beer", "coffee", "thug_cash"], "dislikes": ["turnip"]}


## A joined Marked or lieutenant at the hideout: one of their lines (day-rotated).
static func _joined_talk(m: GameMap, id: String) -> bool:
	var ls: Array = []
	if id.begins_with("mk_"):
		ls = Marked.all().get(id.trim_prefix("mk_"), {}).get("hideout", [])
	else:
		ls = Gift.data().get("lieutenants", {}).get(id.trim_prefix("lt_"), {}).get("hideout", [])
	if ls.is_empty():
		return false
	if GameState.can_gift(id, str(GameState.run.get("selected", ""))):
		return false
	var nm := str(GameState.npcs.get(id, {}).get("name", id))
	await m.say([{"who": nm, "text": str(ls[int(GameState.run["day"]) % ls.size()])}])
	return true


## Loyalty talk at the hideout: one scene per three days. Returns true if played.
static func talk(m: GameMap, id: String) -> bool:
	if id.begins_with("partner_"):
		return await _partner_ask(m, id.trim_prefix("partner_"))
	if (id.begins_with("mk_") or id.begins_with("lt_")) and not GameState.is_penguins():
		return await _joined_talk(m, id)
	if not members().has(id):
		return false
	if not recruited(id):
		return await _waiting(m, id)
	if await Ops.talk(m, id):
		return true
	var mdef: Dictionary = members()[id]
	var lv := loyalty(id)
	var last := int(GameState.run.get("crew_last", {}).get(id, -10))
	var day := int(GameState.run["day"])
	if m.scene_id() == "hideout" and lv < 3 and day - last >= 3 and not (lv == 2 and Ops.mission_open(id)):
		var scenes: Array = mdef.get("loyalty", [])
		if lv < scenes.size():
			await m.say(scenes[lv])
			_set_loyalty(id, lv + 1)
			var cl: Dictionary = GameState.run.get("crew_last", {})
			cl[id] = day
			GameState.run["crew_last"] = cl
			var perks: Array = mdef.get("perks", [])
			if lv < perks.size():
				m.hud.toast("%s loyalty %d: %s" % [str(mdef["name"]), lv + 1, str(perks[lv])], Color(1, 0.85, 0.7))
				Music.instance(m.get_tree()).sfx("quest_done", "levelup")
				if m.player and Art.has("fx", "special_" + id):
					m.fx("special_" + id, m.player.position + Vector2(0, -16), 10.0, 0.5)
			return true
	# Holding a gift: let the gift confirm run (region._talk_npc) instead of a line.
	if GameState.can_gift(id, str(GameState.run.get("selected", ""))):
		return false
	# Halo: rides between the gangster districts.
	if id == "halo" and perk_level("rides") >= 1 and (m.scene_id() == "hideout" or perk_level("rides") >= 3):
		var d := Dialogue.instance(m.get_tree())
		var names := ["The docks", "Neon", "Uptown"]
		var dest := ["docks", "neon", "uptown"]
		if m.scene_id() != "hideout":
			names.append("The hideout")  # out in a district: the ride you want is home
			dest.append("hideout")
		d.say([{"who": "Halo", "text": "Say where.", "choice": names + ["Stay"], "key": ""}])
		await d.finished
		var n := dest.size()
		if perk_level("rides") < 2 and d.last_choice >= 0 and d.last_choice < n:
			GameState.run["time"] = int(GameState.run["time"]) + 30  # the drive takes a while
		if d.last_choice >= 0 and d.last_choice < n:
			var sc: String = dest[d.last_choice]
			if sc == "hideout" or GameState.run["flags"].has(sc + "_seen"):
				m.go_to(sc, Vector2.ZERO, "right")
				return true
			await m.say([{"who": "Halo", "text": "Haven't been. You go first; I don't drive blind."}])
		return true
	# Everyday crew line.
	var lines: Dictionary = {
		"deuce": ["Deck's shuffled, boss.", "Counting. Always counting.", "The boys ask after you. I tell them you're busy being a farmer."],
		"mama_rosa": ["Eat something.", "You look thin. Everyone looks thin. Eat.", "Stew's on. Sit."],
		"specs": ["Don't talk, I'm in the wire.", "Sub-basement three. Its own wire. Who DOES that.", "...Yes? Oh. Hi."],
		"ladder": ["Four hundred and twelve.", "Clear sky today. You can see the tower from the roof.", "Nothing on the road. Nothing's always something."],
		"vic": ["Val's warming up.", "We're ready.", "Left side's yours. Remember."],
		"val": ["Vic's warming up.", "Right side's ours.", "Don't listen to the stone."],
		"halo": ["Engine's warm.", "Hideout's where I park. Find me there.", "Never quit at the containers."],
		"dice": ["Nothing new. Well. Something new. Nothing I can tell you yet.", "I'm fine. I'm FINE.", "Messages are quiet. Quiet's bad."],
		"the_kid": ["...", "...", "..."],
		"doc": ["Let me see that arm.", "Sleep more.", "Try not to need me."],
		"marlene": ["Prices are up. Yours especially.", "I don't do favours. This isn't one.", "Paper, boss. Keep it dry."],
		"sasha": ["Doors?", "...", "Say the word."],
	}
	var pick: Array = (lines.get(id, ["..."]) as Array).duplicate()
	pick.append_array(flag_lines(id))
	await m.say([{"who": str(mdef["name"]), "text": str(pick[(day + lv) % pick.size()])}])
	return true


## Everyday lines that remember a recruit choice or who else joined (C7 c7_14).
static func flag_lines(id: String) -> Array:
	var f: Dictionary = GameState.run.get("flags", {})
	var out: Array = []
	match id:
		"deuce":
			if f.has("deuce_thumb"):
				out.append("Still not doing the thumb one. Don't ask.")
		"dice":
			if f.has("dice_scared"):
				out.append("The pawnbroker crosses the street when he sees me now. Is that... good?")
		"vic":
			if f.has("lt_joined_brock"):
				out.append("You kept the champion? Huh. He hits like a wall.")
		"val":
			if f.has("lt_joined_brock"):
				out.append("Brock's in. Smart. Nobody gets past the three of us.")
		"sasha":
			if f.has("lt_joined_brock"):
				out.append("I carried Brock out of that pit. Now he eats at our table. Funny city.")
	return out


## Before a member is recruited (and no story beat fits yet): an in-voice line
## that says what has to happen first, plus a one-time hint toast. Marlene after
## the letter was sold: one closing scene, then she walks (like Dice).
static func _waiting(m: GameMap, id: String) -> bool:
	var f: Dictionary = GameState.run["flags"]
	if f.has(id + "_refused"):
		return false
	var mdef: Dictionary = members()[id]
	if id == "marlene" and f.has("letter_sold"):
		await m.say(mdef.get("sold", []))
		f["marlene_refused"] = true
		return true
	var ws: Array = mdef.get("waiting", [])
	if ws.is_empty():
		return false
	var w: Variant = ws[int(GameState.run["day"]) % ws.size()]
	var line: Dictionary = (w as Dictionary).duplicate() if w is Dictionary else {"who": str(mdef["name"]), "text": str(w)}
	await m.say([line])
	var h := str(mdef.get("waiting_hint", ""))
	if h != "" and not f.has("crew_hint_" + id):
		f["crew_hint_" + id] = true
		m.hud.toast(h, Color(1, 0.85, 0.7))
	return true


## A gangster-arc partner not picked at the day-3 farm gate (or "Nobody, for now"):
## after the hideout is yours, they wait there and can still be asked.
static func partner_waiting(cid: String) -> bool:
	if GameState.is_penguins() or not GameState.run["flags"].has("partner_scene") or not GameState.run["flags"].has("hideout_seen"):
		return false
	if cid == str(GameState.run.get("playable", "")):
		return false
	return not cid in Companion.party()["known"]


static func _partner_ask(m: GameMap, cid: String) -> bool:
	if not partner_waiting(cid):
		return false
	var nm := str(Companion.defs().get(cid, {}).get("name", cid.capitalize()))
	var d := Dialogue.instance(m.get_tree())
	var first: String = {"big_jim": "You paid me in silence last time. Silence doesn't buy fuel. ...Truck's still running, though."}.get(cid, "Still looking for someone to ride with?")
	d.say([{"who": nm, "text": first, "choice": ["Ride with me?", "Not now."], "key": ""}])
	await d.finished
	if d.last_choice == 0:
		Companion.recruit(cid)
		var yes: String = {"big_jim": "I'm in. You point, I swing."}.get(cid, "Let's go.")
		await m.say([{"who": nm, "text": yes}])
		m.hud.toast("%s joins you. Swap partners in Menu > Party." % nm, Color(1, 0.9, 0.5))
		for ch in m.get_children():
			if ch is Npc and (ch as Npc).id == "partner_" + cid:
				(ch as Node2D).visible = false  # gone on the next visit; hidden now (npcs keeps refs)
				(ch as Node).process_mode = Node.PROCESS_MODE_DISABLED
	return true
