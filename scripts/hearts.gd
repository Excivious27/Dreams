class_name Hearts
## Villager heart arcs (data/hearts.json). When you talk to a villager whose
## hearts have crossed 2/4/6/8/10, the milestone scene plays once (flag
## hv_<id>_<n>); at 6 their personal quest is offered with Quests.talk lines;
## after a milestone a new daily line enters their rotation.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/hearts.json").get("villagers", {})
	return _data


static func _flag(id: String, n: int) -> String:
	return "hv_%s_%d" % [id, n]


## Highest milestone already seen for this villager (0 if none).
static func seen_level(id: String) -> int:
	var lv := 0
	for n in [2, 4, 6, 8, 10]:
		if GameState.run["flags"].has(_flag(id, n)):
			lv = n
	return lv


## Next milestone that is due (hearts reached, scene not yet played), or 0.
static func due(id: String) -> int:
	if not data().has(id):
		return 0
	var hearts := GameState.friend_hearts(id)
	for n in [2, 4, 6, 8, 10]:
		if hearts >= n and not GameState.run["flags"].has(_flag(id, n)):
			return n
	return 0


## Play the due milestone scene. Returns true if one played.
static func talk(m: GameMap, id: String) -> bool:
	var n := due(id)
	if n == 0:
		return false
	var v: Dictionary = data()[id]
	var lines: Array = ((v.get("milestones", {}) as Dictionary).get(str(n), []) as Array).duplicate(true)
	if lines.is_empty():
		return false
	# Some lines are about the crystal and the penguins; the gangster arc has its own words.
	if not GameState.is_penguins():
		for l in lines:
			if l.has("text_gangsters"):
				l["text"] = l["text_gangsters"]
	# "if_gone": {who: text} when the story sent that villager away.
	for l in lines:
		for who in (l.get("if_gone", {}) as Dictionary):
			if GameState.run["flags"].has(str(who) + "_gone"):
				l["text"] = str(l["if_gone"][who])
	# A ♥6 ask for a quest you already finished plays its "if_done" words instead.
	var q6 := str(v.get("quest6_gangsters", v.get("quest6", ""))) if not GameState.is_penguins() else str(v.get("quest6", ""))
	if n == 6 and q6 != "" and GameState.quest_done(q6):
		for l in lines:
			if l.has("if_done"):
				l["text"] = str(l["if_done"])
	var name := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	m.hud.toast("%s ♥%d" % [name, n], Color(1, 0.8, 0.9))
	await m.say(lines)
	GameState.run["flags"][_flag(id, n)] = true
	if n == 6:
		var q := str(v.get("quest6_gangsters", v.get("quest6", ""))) if not GameState.is_penguins() else str(v.get("quest6", ""))
		if q != "" and not GameState.has_quest(q):
			var d := GameState._quest_def(q)
			# Respect the quest's own gates (skill, earlier quest; _quest_def already
			# drops other-arc quests); if they aren't met yet, the villager offers
			# it later through Quests.talk.
			if not d.is_empty() and GameState._cond_ok(d.get("when", {})):
				GameState.add_quest(q, str(d.get("text", q)))
				m.hud.toast("New quest: %s" % str(d.get("text", q)), Color(1, 0.9, 0.4))
				var yes := Quests._as_lines(name, Quests.lines(q).get("yes", ""))
				if not yes.is_empty():
					await m.say(yes)
	if n == 10:
		Music.instance(m.get_tree()).sfx("levelup")
		var fall := str(v.get("fall", ""))
		if fall != "":
			GameState.add_hint("%s: %s" % [name, fall])
	return true


## A daily line that reflects where you are with them, or "" if none yet.
static func daily(id: String) -> String:
	if not data().has(id):
		return ""
	var lv := seen_level(id)
	if lv == 0:
		return ""
	var after: Dictionary = data()[id].get("after", {})
	if not GameState.is_penguins():
		after = after.merged(data()[id].get("after_gangsters", {}), true)
	return str(after.get(str(lv), ""))


## For the endings: what each villager at ♥10 would do.
static func standing_with_you() -> Array:
	var out: Array = []
	for id in data():
		if GameState.friend_hearts(id) >= 10:
			out.append(str(GameState.npcs.get(id, {}).get("name", id)))
	return out
