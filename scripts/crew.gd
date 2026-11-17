class_name Crew
## The gangster crew (data/crew.json): who's recruited (flag crew_<id>), their
## loyalty (run["crew"][id] = 0..3), where they stand in the world, and the
## passive perks they give by loyalty. Recruiting happens in story.json beats.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/crew.json")
		# Register members as NPCs so names, portraits and friendship work.
		for id in members():
			if not GameState.npcs.has(id):
				var mdef: Dictionary = members()[id]
				GameState.npcs[id] = {"name": str(mdef["name"]), "sprite": str(mdef.get("sprite", "")), "portrait": str(mdef.get("sprite", "")), "role": str(mdef.get("role", "")), "routine": [], "likes": ["thug_cash", "wine", "coffee"], "dislikes": ["turnip"]}
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


## Does any recruited member at loyalty >= n have this perk key?
## Perk keys: sell_bonus, meal_heal, shop_discount, raid_warning, sword, defence,
## rides, board_bonus, run_speed, heal_hideout, status_half, fence, doors.
static func perk_level(key: String) -> int:
	var who: String = {"sell_bonus": "deuce", "meal_heal": "mama_rosa", "shop_discount": "specs", "raid_warning": "ladder", "sword": "vic", "defence": "val", "rides": "halo", "board_bonus": "dice", "run_speed": "the_kid", "heal_hideout": "doc", "status_half": "doc", "fence": "marlene", "doors": "sasha"}.get(key, "")
	if who == "" or not recruited(who):
		return 0
	return loyalty(who)


## Place crew members in this map: unrecruited ones where the story expects
## them, recruited ones at the hideout.
static func place(m: GameMap) -> void:
	if GameState.is_penguins():
		return
	data()
	for id in members():
		var mdef: Dictionary = members()[id]
		var at := Vector2i(-1, -1)
		if recruited(id):
			if m.scene_id() == "hideout":
				at = Vector2i(int(mdef["home"][0]), int(mdef["home"][1]))
		else:
			var b: Dictionary = mdef.get("before", {})
			if str(b.get("scene", "")) == m.scene_id():
				at = Vector2i(int(b["cell"][0]), int(b["cell"][1]))
		if at == Vector2i(-1, -1):
			continue
		# Find a free cell near the wanted one.
		var c := at
		for r in 4:
			var found := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cc := at + Vector2i(dx, dy)
					if m.in_content(cc) and not m.blocked.has(cc) and not m.things.has(cc) and not m.is_water_cell(cc):
						c = cc
						found = true
						break
				if found:
					break
			if found:
				break
		var npc := Npc.new()
		npc.map = m
		npc.setup(id, GameState.npcs[id], m.cell_center(c))
		npc.wander = 10.0
		m.add_child(npc)
		if m.get("npcs") != null:
			(m.get("npcs") as Array).append(npc)


## Loyalty talk at the hideout: one scene per three days. Returns true if played.
static func talk(m: GameMap, id: String) -> bool:
	if not members().has(id) or not recruited(id):
		return false
	var mdef: Dictionary = members()[id]
	var lv := loyalty(id)
	var last := int(GameState.run.get("crew_last", {}).get(id, -10))
	var day := int(GameState.run["day"])
	if m.scene_id() == "hideout" and lv < 3 and day - last >= 3:
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
				Music.instance(m.get_tree()).sfx("levelup")
			return true
	# Halo: rides between the gangster districts.
	if id == "halo" and lv >= 1 and m.scene_id() == "hideout":
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "Halo", "text": "Say where.", "choice": ["The docks", "Neon", "Uptown", "Stay"], "key": ""}])
		await d.finished
		var dest := ["docks", "neon", "uptown"]
		if d.last_choice >= 0 and d.last_choice < 3:
			var sc: String = dest[d.last_choice]
			if GameState.run["flags"].has(sc + "_seen"):
				m.go_to(sc, Vector2.ZERO, "right")
				return true
			await m.say([{"who": "Halo", "text": "Haven't been. You go first; I don't drive blind."}])
		return true
	# Everyday crew line.
	var lines: Dictionary = {
		"deuce": ["Table's open, boss.", "Counting. Always counting.", "The boys ask after you. I tell them you're busy being a farmer."],
		"mama_rosa": ["Eat something.", "You look thin. Everyone looks thin. Eat.", "Stew's on. Sit."],
		"specs": ["Don't talk, I'm in the wire.", "Sub-basement three. Its own wire. Who DOES that.", "...Yes? Oh. Hi."],
		"ladder": ["Four hundred and twelve.", "Clear sky today. You can see the tower from the roof.", "Nothing on the road. Nothing's always something."],
		"vic": ["Val's warming up.", "We're ready.", "Left side's yours. Remember."],
		"val": ["Vic's warming up.", "Right side's ours.", "Don't listen to the stone."],
		"halo": ["Engine's warm.", "Say where.", "Never quit at the containers."],
		"dice": ["Nothing new. Well. Something new. Nothing I can tell you yet.", "I'm fine. I'm FINE.", "Messages are quiet. Quiet's bad."],
		"the_kid": ["...", "...", "..."],
		"doc": ["Let me see that arm.", "Sleep more.", "Try not to need me."],
		"marlene": ["Prices are up. Yours especially.", "I don't do favours. This isn't one.", "Paper, boss. Keep it dry."],
		"sasha": ["Doors?", "...", "Say the word."],
	}
	var pick: Array = lines.get(id, ["..."])
	await m.say([{"who": str(mdef["name"]), "text": str(pick[(day + lv) % pick.size()])}])
	return true
