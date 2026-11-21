class_name Quests
## Side-quest conversations in each villager's voice (data/quest_lines.json):
## the offer, the nudge while pending, and the turn-in. Main quests keep
## auto-completing; a side quest with a giver completes face to face.

static var _lines: Dictionary = {}


static func lines(id: String) -> Dictionary:
	if _lines.is_empty():
		_lines = GameState.load_json("res://data/quest_lines.json")
	var d: Dictionary = _lines.get(id, {})
	# Gangster-arc wording for a quest line: "<id>@gangsters" overrides some keys.
	if not GameState.is_penguins() and _lines.has(id + "@gangsters"):
		d = d.merged(_lines[id + "@gangsters"], true)
	return d


## Quest done? Like GameState._cond_ok, but an item the quest only needs to
## exist (no "take") also counts when your pup is wearing it (benno_pup_pack).
static func _done(d: Dictionary) -> bool:
	if not d.has("done_when") or not (d["done_when"] is Dictionary):
		return false
	var dw: Dictionary = d["done_when"]
	if GameState._cond_ok(dw):
		return true
	if bool(d.get("take", false)) or dw.size() != 1 or not dw.has("item"):
		return false
	var it = dw["item"]
	var iid := str(it[0]) if it is Array else str(it)
	var gear: Dictionary = (GameState.run.get("pet", {}) as Dictionary).get("gear", {})
	return gear.values().has(iid)


static func _as_lines(who: String, v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for t in v:
			out.append({"who": who, "text": str(t)})
	elif v != null and str(v) != "":
		out.append({"who": who, "text": str(v)})
	return out


## An open quest from this NPC that can be handed in right now ({} if none), so
## a finished second quest isn't stuck behind an unfinished first one.
static func _ready_quest(npc: String) -> Dictionary:
	for q in GameState.run["quests"]:
		if q["done"]:
			continue
		var d := GameState._quest_def(str(q["id"]))
		if str(d.get("giver", "")) == npc and _done(d):
			return d
	return {}


## Try the quest conversation for this NPC. Returns true if one happened
## (so the caller skips the daily chat).
static func talk(m: GameMap, id: String, name: String) -> bool:
	# 1) Turn-in: a pending quest whose condition is met.
	var pend := _ready_quest(id)
	if pend.is_empty():
		pend = GameState.side_quest_pending(id)
	if not pend.is_empty():
		var qid := str(pend["id"])
		var d := GameState._quest_def(qid)
		var ql := lines(qid)
		if _done(d):
			var seq := _as_lines(name, ql.get("done", ["That's it exactly. Thank you."]))
			await m.say(seq)
			if bool(d.get("take", false)):
				var dw: Dictionary = d["done_when"]
				if dw.has("item"):
					GameState.add_item(str(dw["item"][0]), -int(dw["item"][1]))
				for pair in dw.get("items", []):
					GameState.add_item(str(pair[0]), -int(pair[1]))
			if GameState.complete_quest(qid):
				m.hud.toast(GameMap.quest_done_text(qid), Color(1, 0.9, 0.4))
				Music.instance(m.get_tree()).sfx("quest_done", "levelup")
				m.emote(_npc_node(m, id), "heart", 1.4)
			return true
		# The reminder plays once a day; after that the villager chats normally.
		var waited: Dictionary = GameState.run["talked_today"]
		if waited.has("wait_" + id):
			return false
		waited["wait_" + id] = true
		# C7: first person, what's still short (never the log's third-person text, lowercased).
		var need := _still_need(d)
		var dflt := ("Still need %s. You know where to find me." % need) if need != "" else "Still waiting on that one. It's in your quest log."
		if bool(d.get("board", false)) and d.get("done_when", {}).has("item"):
			dflt = "Still need those %s from the board. No rush. Some rush." % ItemWords.count_id(str(d["done_when"]["item"][0]), int(d["done_when"]["item"][1]))
		await m.say(_as_lines(name, ql.get("wait", dflt)))
		return true
	# 2) Offer.
	var offer := GameState.side_quest_for(id)
	if offer.is_empty() or GameState.run["talked_today"].has("decline_" + id):
		return false
	if not GameState.is_penguins() and offer.has("text_gangsters"):
		offer = offer.merged({"text": offer["text_gangsters"]}, true)  # arc wording (P5 hook)
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
		announce(m, str(offer["text"]))
		_job_taken(m, qid2)
		await m.say(_as_lines(name, ql2.get("yes", "Thank you.")))
	else:
		GameState.run["talked_today"]["decline_" + id] = true  # asked again tomorrow, not every chat
		await m.say(_as_lines(name, ql2.get("no", "Another time, then.")))
	return true


## What a job still needs, in words ("2 Gold Leaf and 1 Pearl Necklace"; "" = not an item job).
## One "new quest" moment everywhere: the toast and the j_quest cue (C13, P3's jingle).
static func announce(m: GameMap, text: String) -> void:
	if m == null:
		return
	if m.hud != null:
		m.hud.toast("New quest: %s" % text, Color(1, 0.9, 0.4))
	Music.instance(m.get_tree()).sfx("j_quest", "new_item")


static func _still_need(d: Dictionary) -> String:
	var dw: Variant = d.get("done_when", {})
	if not (dw is Dictionary):
		return ""
	var pairs: Array = []
	if (dw as Dictionary).has("item"):
		pairs.append(dw["item"])
	for pr in (dw as Dictionary).get("items", []):
		pairs.append(pr)
	var bits: Array = []
	for pr: Array in pairs:
		var short := int(pr[1]) - GameState.count(str(pr[0]))
		if short > 0:
			bits.append(ItemWords.count_id(str(pr[0]), short))
	return " and ".join(bits)


## A job whose work happens on this map right away (C7): Rook's orchard foes show up
## as soon as the job is taken, not only after the next visit to town.
static func _job_taken(m: GameMap, qid: String) -> void:
	if qid == "rook_tracks" and m.scene_id() == "town" and not bool(m.get("_orchard_watch")):
		for i in 3:
			m.spawn_enemy("grump" if GameState.is_penguins() else "thug_lookout", m.cell_center(Vector2i(75 + i * 3, 10 + i * 6)))
		m.set("_orchard_watch", true)


static func _npc_node(m: GameMap, id: String) -> Node2D:
	for ch in m.get_children():
		if ch is Npc and (ch as Npc).id == id:
			return ch
	return null
