class_name SideStory
extends RefCounted
## Side stories (CONDUCT 7 P4): short chains of scenes from data/side_stories.json
## (written by tools/gen_side_stories.py). Villager and crew talk calls
## SideStory.talk(map, id) after the story and heart scenes: the giver of a
## chain's next step plays it (one step per chain per day), asks for items if
## the step needs some, and puts the next step in the journal.
## Flags: ss_<chain>_<i> per step, ss_<chain>_done at the end, plus each step's own "flag".

static var _data: Array = []


static func chains() -> Array:
	if _data.is_empty():
		_data = GameState.load_json("res://data/side_stories.json").get("chains", [])
	return _data


static func _arc_ok(c: Dictionary) -> bool:
	return str(c.get("arc", "")) in ["", str(GameState.run.get("arc", ""))]


## Index of the chain's next step, -1 when finished.
static func next_step(c: Dictionary) -> int:
	var f: Dictionary = GameState.run["flags"]
	var steps: Array = c.get("steps", [])
	for i in steps.size():
		if not f.has("ss_%s_%d" % [str(c["id"]), i]):
			return i
	return -1


## The step this villager can play now, as [chain, index], or [].
static func due(id: String) -> Array:
	if GameState.run.is_empty():
		return []
	var f: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	for c: Dictionary in chains():
		if not _arc_ok(c) or not GameState._cond_ok(c.get("when", {})):
			continue
		var i := next_step(c)
		if i < 0:
			continue
		var st: Dictionary = c["steps"][i]
		if str(st.get("giver", "")) != id:
			continue
		# One step a day per chain: the next scene waits for tomorrow.
		if i > 0 and int(f.get("ss_%s_day" % str(c["id"]), -1)) >= day:
			continue
		return [c, i]
	return []


## Play the villager's due side-story step. Returns true if anything was said.
static func talk(m: GameMap, id: String) -> bool:
	var d := due(id)
	if d.is_empty():
		return false
	var c: Dictionary = d[0]
	var i: int = d[1]
	var st: Dictionary = c["steps"][i]
	var f: Dictionary = GameState.run["flags"]
	var cid := str(c["id"])
	if st.has("need"):
		var need: Array = st["need"]
		var asked := "ss_%s_%d_asked" % [cid, i]
		if GameState.count(str(need[0])) < int(need[1]):
			# First time: the full ask; after that, the short reminder.
			await m.say(st["lines"] if not f.has(asked) else st.get("ask", st["lines"]))
			f[asked] = true
			_hint(c, st)
			return true
		if not f.has(asked):
			await m.say(st["lines"])
		GameState.add_item(str(need[0]), -int(need[1]))
		m.hud.toast("Gave %s." % ItemWords.count_id(str(need[0]), int(need[1])), Color(1, 0.9, 0.6))
	else:
		await m.say(st["lines"])
	if st.has("choice"):
		var ch: Dictionary = st["choice"]
		var opts: Array = ch.get("options", [])
		var dlg := Dialogue.instance(m.get_tree())
		dlg.say([{"who": "", "text": str(ch.get("prompt", "")), "choice": opts, "key": ""}])
		await dlg.finished
		if dlg.last_choice < 0 or dlg.last_choice >= opts.size() - 1:
			return true  # the way out: this step waits
		f[str(ch.get("flag", "ss_%s_choice" % cid))] = str(opts[dlg.last_choice])
	_finish(m, c, i, st)
	return true


static func _finish(m: GameMap, c: Dictionary, i: int, st: Dictionary) -> void:
	var f: Dictionary = GameState.run["flags"]
	var cid := str(c["id"])
	f["ss_%s_%d" % [cid, i]] = true
	f["ss_%s_day" % cid] = int(GameState.run["day"])
	if st.has("flag"):
		f[str(st["flag"])] = true
	if st.has("give"):
		var g: Array = st["give"]
		if not DecorSources.grant(m, str(g[0]), int(g[1]), "side"):  # C10a P4 hook: decor to the decor box
			GameState.add_item(str(g[0]), int(g[1]))
		m.hud.toast("Got %s." % ItemWords.count_id(str(g[0]), int(g[1])), Color(1, 0.9, 0.4))
	if st.has("money"):
		GameState.add_money(int(st["money"]), "side_story")
		m.hud.toast("+%s" % Money.amount(int(st["money"])), Color(1, 0.9, 0.4))
	if st.has("friend"):
		GameState.add_friend(str(st["friend"][0]), int(st["friend"][1]))
	if i == 0:
		m.hud.toast("Side story: %s" % str(c.get("title", cid)), Color(0.8, 0.9, 1))
		Music.instance(m.get_tree()).sfx("j_page", "pickup")
	if next_step(c) < 0:
		f["ss_%s_done" % cid] = true
		m.hud.toast("Side story done: %s" % str(c.get("title", cid)), Color(1, 0.9, 0.4))
		Music.instance(m.get_tree()).sfx("quest_done", "levelup")
	_hint(c, st)


static func _hint(c: Dictionary, st: Dictionary) -> void:
	var h := str(st.get("hint", ""))
	if h != "":
		GameState.add_hint("%s: %s" % [str(c.get("title", "")), h])


## For a progress screen: [done, total] across this arc's side stories.
static func progress() -> Array:
	var done := 0
	var total := 0
	for c: Dictionary in chains():
		if _arc_ok(c):
			total += 1
			if GameState.run["flags"].has("ss_%s_done" % str(c["id"])):
				done += 1
	return [done, total]
