class_name Quests
## Side-quest conversations in each villager's voice (data/quest_lines.json):
## the offer, the nudge while pending, and the turn-in. Main quests keep
## auto-completing; a side quest with a giver completes face to face.

static var _lines: Dictionary = {}


static func lines(id: String) -> Dictionary:
	if _lines.is_empty():
		_lines = GameState.load_json("res://data/quest_lines.json")
	return _lines.get(id, {})


static func _as_lines(who: String, v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for t in v:
			out.append({"who": who, "text": str(t)})
	elif v != null and str(v) != "":
		out.append({"who": who, "text": str(v)})
	return out


## Try the quest conversation for this NPC. Returns true if one happened
## (so the caller skips the daily chat).
static func talk(m: GameMap, id: String, name: String) -> bool:
	# 1) Turn-in: a pending quest whose condition is met.
	var pend := GameState.side_quest_pending(id)
	if not pend.is_empty():
		var qid := str(pend["id"])
		var d := GameState._quest_def(qid)
		var ql := lines(qid)
		if d.has("done_when") and GameState._cond_ok(d["done_when"]):
			var seq := _as_lines(name, ql.get("done", ["That's it exactly. Thank you."]))
			await m.say(seq)
			if bool(d.get("take", false)):
				var dw: Dictionary = d["done_when"]
				if dw.has("item"):
					GameState.add_item(str(dw["item"][0]), -int(dw["item"][1]))
				for pair in dw.get("items", []):
					GameState.add_item(str(pair[0]), -int(pair[1]))
			if GameState.complete_quest(qid):
				m.hud.toast("Quest complete: %s" % qid.replace("_", " "), Color(1, 0.9, 0.4))
				Music.instance(m.get_tree()).sfx("quest_done", "levelup")
				m.emote(_npc_node(m, id), "heart", 1.4)
			return true
		# The reminder plays once a day; after that the villager chats normally.
		var waited: Dictionary = GameState.run["talked_today"]
		if waited.has("wait_" + id):
			return false
		waited["wait_" + id] = true
		await m.say(_as_lines(name, ql.get("wait", "Still waiting on that: " + str(pend["text"]).to_lower())))
		return true
	# 2) Offer.
	var offer := GameState.side_quest_for(id)
	if offer.is_empty() or GameState.run["talked_today"].has("decline_" + id):
		return false
	var qid2 := str(offer["id"])
	var ql2 := lines(qid2)
	var seq2 := _as_lines(name, ql2.get("offer", [str(offer["text"])]))
	var last: Dictionary = seq2.pop_back()
	if not seq2.is_empty():
		await m.say(seq2)
	var dlg := Dialogue.instance(m.get_tree())
	dlg.say([{"who": name, "text": str(last["text"]), "choice": ["Sure", "Not now"], "key": ""}])
	await dlg.finished
	if dlg.last_choice == 0:
		GameState.add_quest(qid2, str(offer["text"]))
		m.hud.toast("New quest: %s" % str(offer["text"]), Color(1, 0.9, 0.4))
		await m.say(_as_lines(name, ql2.get("yes", "Thank you.")))
	else:
		GameState.run["talked_today"]["decline_" + id] = true  # asked again tomorrow, not every chat
		await m.say(_as_lines(name, ql2.get("no", "Another time, then.")))
	return true


static func _npc_node(m: GameMap, id: String) -> Node2D:
	for ch in m.get_children():
		if ch is Npc and (ch as Npc).id == id:
			return ch
	return null
