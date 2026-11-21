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


## Does this villager's heart arc belong to the current story arc? (hearts.json
## "arc": Catkins' arc is penguins-only.)
static func in_arc(id: String) -> bool:
	return str(data().get(id, {}).get("arc", "")) in ["", str(GameState.run.get("arc", ""))]


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
	if not data().has(id) or not in_arc(id):
		return 0
	var hearts := GameState.friend_hearts(id)
	for n in [2, 4, 6, 8, 10]:
		if hearts >= n and not GameState.run["flags"].has(_flag(id, n)):
			return n if _ready_for(id, n) else 0
	return 0


## ♥8 scenes that tell what came of the ♥6 quest (or of another villager's scene) wait for it.
const AFTER_Q6 := ["gideon", "wren", "lumi", "theo", "bram", "posy", "tobin", "marlowe", "ivy", "tam", "sel"]
const NEEDS_FLAG := {"hazel": "hv_granite_8", "mabel": "hv_granite_8", "posy": "hv_bram_8", "orla": "lighthouse_lit", "juniper": "hv_gideon_8", "ivy": "hv_theo_8"}
## ♥10 scenes that retell another villager's beat wait for it (C12 P4): Granite's ♥10 is Mabel singing to the stone.
const NEEDS10 := {"granite": "hv_mabel_8"}


## The villager's ♥6 quest in this arc ("" if none).
static func quest6(id: String) -> String:
	var v: Dictionary = data().get(id, {})
	return str(v.get("quest6_gangsters", v.get("quest6", ""))) if not GameState.is_penguins() else str(v.get("quest6", ""))


static func _ready_for(id: String, n: int) -> bool:
	if n == 10:
		if NEEDS10.has(id) and not GameState.run["flags"].has(NEEDS10[id]):
			return false
		# Hazel's and Mabel's ♥10 talk about the full cellar: that needs Hazel's milk.
		return not (id in ["hazel", "mabel"]) or GameState._quest_def("hazel_milk").is_empty() or GameState.quest_done("hazel_milk")
	if n != 8:
		return true
	var q := quest6(id)
	if id in AFTER_Q6 and q != "" and not GameState._quest_def(q).is_empty() and not GameState.quest_done(q):
		return false
	return not NEEDS_FLAG.has(id) or GameState.run["flags"].has(NEEDS_FLAG[id])


## Why a reached milestone is held back, for the journal.
const WAIT_WHY := {"hv_granite_8": "once Granite has walked up the road", "hv_bram_8": "once Bram has had his say", "lighthouse_lit": "once Marlowe's lamp is lit", "hv_gideon_8": "Gideon has something to give her first", "hv_theo_8": "once Theo has read the miners' log", "hv_mabel_8": "once Mabel has sung at the quarry"}


## A milestone you've reached that waits (_ready_for): say why in the journal (once).
static func _held_hint(id: String) -> void:
	if not data().has(id):
		return
	var n := seen_level(id) + 2
	if n > 10 or GameState.friend_hearts(id) < n or _ready_for(id, n):
		return
	var cellar := n == 10 and id in ["hazel", "mabel"]
	var q := "hazel_milk" if cellar else (quest6(id) if n == 8 else "")
	var why := ""
	if q != "" and not GameState._quest_def(q).is_empty() and not GameState.quest_done(q) and (cellar or id in AFTER_Q6):
		why = "first: " + str(GameState._quest_def(q).get("text", q))
	elif n == 10 and NEEDS10.has(id):
		why = str(WAIT_WHY.get(NEEDS10[id], ""))
	elif n == 8 and NEEDS_FLAG.has(id):
		why = str(WAIT_WHY.get(NEEDS_FLAG[id], ""))
	if why != "":
		var nm := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
		GameState.add_hint("%s has more to say at ♥%d (%s)." % [nm, n, why])


## Play the due milestone scene. Returns true if one played.
static func talk(m: GameMap, id: String) -> bool:
	var n := due(id)
	if n == 0:
		_held_hint(id)
		return false
	var v: Dictionary = data()[id]
	var lines := scene_lines(id, n)
	if lines.is_empty():
		return false
	var name := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	m.hud.toast("%s ♥%d" % [name, n], Color(1, 0.8, 0.9))
	# Every heart scene opens on a soft cue; ♥10 keeps its full j_heart after the scene.
	var gang := not GameState.is_penguins()
	var open_cue := "j_page" if n < 10 else ("j_heart_gang" if gang else "sparkle")
	Music.instance(m.get_tree()).sfx(open_cue, "j_page" if gang else "sparkle")
	# C13 06-10: a heart scene has its own mood song (not the fight/shop song under it).
	var mooded := Dialogue.scene_mood(m.get_tree(), heart_mood(n))
	await m.say(lines)
	if mooded and is_instance_valid(m):
		Dialogue.scene_end(m.get_tree())
	GameState.run["flags"][_flag(id, n)] = true
	if n == 6:
		var q := quest6(id)
		if q != "" and not GameState.has_quest(q):
			var d := GameState._quest_def(q)
			# Respect the quest's own gates (skill, earlier quest; _quest_def already
			# drops other-arc quests); if they aren't met yet, the villager offers
			# it later through Quests.talk.
			# A crop quest offered late in its season would sit a year: offer it next season.
			var late := (d.get("when", {}) as Dictionary).has("season") and GameState.day_of_season() > 18 and GameState._quest_grows(d)
			if not d.is_empty() and not late and GameState._cond_ok(d.get("when", {})):
				GameState.add_quest(q, str(d.get("text", q)))
				m.hud.toast("New quest: %s" % str(d.get("text", q)), Color(1, 0.9, 0.4))
				Music.instance(m.get_tree()).sfx("new_item", "pickup")
				var yes := Quests._as_lines(name, Quests.lines(q).get("yes", ""))
				if not yes.is_empty():
					await m.say(yes)
			elif not d.is_empty():
				# Not yet: say what's missing so the ask isn't left hanging.
				var w: Dictionary = d.get("when", {})
				var need := ""
				if w.has("skill") and GameState.skill_level(str(w["skill"][0])) < int(w["skill"][1]):
					need = " (once your %s is %d)" % [str(w["skill"][0]).capitalize(), int(w["skill"][1])]
				elif w.has("season"):
					need = " (next %s)" % str(w["season"]).capitalize()
				GameState.add_hint("%s will ask you again: %s%s" % [name, str(d.get("text", q)), need])
	if n == 10:
		Music.instance(m.get_tree()).sfx("j_heart_gang" if gang else "j_heart", "j_heart")
		var fall := str(v.get("fall", ""))
		if fall != "":
			GameState.add_hint("If the town ever fell: %s" % fall)
	return true


## The mood song of a ♥n scene: early hearts are light, later ones tender.
static func heart_mood(n: int) -> String:
	return "comic" if n <= 4 else "tender"


## The ♥n scene's lines with every variant applied (arc words, if_gone, if_partner,
## if_done). Tests read this to check the words match the game state. C12 P4.
static func scene_lines(id: String, n: int) -> Array:
	var v: Dictionary = data().get(id, {})
	var lines: Array = ((v.get("milestones", {}) as Dictionary).get(str(n), []) as Array).duplicate(true)
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
	# "if_partner": the words when you're already their sweetheart (dating, engaged or married).
	if Romance.status(id) in ["dating", "engaged", "spouse"]:
		for l in lines:
			if l.has("if_partner"):
				l["text"] = str(l["if_partner"])
	# A ♥6 ask for a quest you already finished plays its "if_done" words instead.
	var q6 := quest6(id)
	if n == 6 and q6 != "" and GameState.quest_done(q6):
		for l in lines:
			if l.has("if_done"):
				l["text"] = str(l["if_done"])
	return lines


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
		if in_arc(id) and GameState.friend_hearts(id) >= 10:
			out.append(str(GameState.npcs.get(id, {}).get("name", id)))
	return out
