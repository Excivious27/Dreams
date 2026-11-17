class_name Story
## The main story, data-driven (data/story.json). Each arc is a list of
## chapters; each chapter a list of beats. A beat fires once (flag "st_<id>")
## when its trigger matches:
##   {"scene": "farm", "area": [x, y, w, h]}      walk into a spot
##   {"scene": "farm"}                             on arriving in the map
##   {"talk": "maple"}                             talking to a villager / thing
##   {"quest_done": "commander"}                   right after a quest completes
##   {"sleep": true}                               next morning, at the bed
## plus a "when" dictionary (GameState._cond_ok, extended with not_flag,
## decision, kills, companion, mine_floor, crystals, hearts_total).
## Lines are Dialogue lines; a line with "choice"+"key" can carry
## "branches": {"0": [...lines...], "1": [...]} played after the pick.
## "effects" run after the lines: flags, unflag, quest/complete, friend,
## items, hint, crystals, companion (recruit), bitter, toast, scene_to.

static var _data: Dictionary = {}
static var _t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameState.load_json("res://data/story.json")
	return _data


static func beats() -> Array:
	var arc := str(GameState.run.get("arc", "penguins"))
	var out: Array = []
	for ch in data().get(arc, []):
		for b in ch.get("beats", []):
			var bb: Dictionary = b.duplicate()
			bb["chapter"] = ch.get("id", "")
			bb["chapter_title"] = ch.get("title", "")
			out.append(bb)
	for ch in data().get("both", []):
		for b in ch.get("beats", []):
			var bb: Dictionary = b.duplicate()
			bb["chapter"] = ch.get("id", "")
			bb["chapter_title"] = ch.get("title", "")
			out.append(bb)
	return out


static func fired(id: String) -> bool:
	return GameState.run["flags"].has("st_" + id)


static func chapter_of(id: String) -> Dictionary:
	for b in beats():
		if str(b["id"]) == id:
			return {"id": b["chapter"], "title": b["chapter_title"]}
	return {}


## Current chapter number per arc (1-based), from the furthest beat fired.
static func chapter_no() -> int:
	var arc := str(GameState.run.get("arc", "penguins"))
	var n := 0
	var i := 0
	for ch in data().get(arc, []):
		i += 1
		for b in ch.get("beats", []):
			if fired(str(b["id"])):
				n = i
	return maxi(1, n)


static func _ready_beat(b: Dictionary, m: GameMap) -> bool:
	if fired(str(b["id"])):
		return false
	var when: Dictionary = b.get("when", {})
	if not GameState._cond_ok(when):
		return false
	if b.has("after") and not fired(str(b["after"])):
		return false
	return true


## Walk-in / arrival beats. Called from GameMap._process (twice a second).
static func tick(m: GameMap, delta: float) -> void:
	_t -= delta
	if _t > 0.0 or m.player == null or m.player.frozen or m.get_tree().paused or Dialogue.instance(m.get_tree()).active or Dialogue.input_blocked():
		return
	_t = 0.5
	var pc := m.player.cell()
	for b in beats():
		var tr: Dictionary = b.get("trigger", {})
		if not tr.has("scene") or str(tr["scene"]) != m.scene_id():
			continue
		if tr.has("area"):
			var a: Array = tr["area"]
			if not Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])).has_point(pc):
				continue
		if not _ready_beat(b, m):
			continue
		m.later(func() -> void: await play(m, b))
		return


## Talk beats. Returns true if one played (caller skips the daily chat).
static func talk(m: GameMap, who: String) -> bool:
	for b in beats():
		var tr: Dictionary = b.get("trigger", {})
		if str(tr.get("talk", "")) != who:
			continue
		if tr.has("scene") and str(tr["scene"]) != m.scene_id():
			continue
		if not _ready_beat(b, m):
			continue
		await play(m, b)
		return true
	return false


## Quest-done beats (GameState.complete_quest tells us).
static func on_quest_done(m: GameMap, qid: String) -> void:
	if m == null:
		return
	for b in beats():
		if str(b.get("trigger", {}).get("quest_done", "")) != qid:
			continue
		if not _ready_beat(b, m):
			continue
		m.later(func() -> void: await play(m, b))
		return


## Morning beats, at the bed (House calls after waking).
static func on_morning(m: GameMap) -> void:
	for b in beats():
		if not bool(b.get("trigger", {}).get("sleep", false)):
			continue
		if not _ready_beat(b, m):
			continue
		m.later(func() -> void: await play(m, b))
		return


static func play(m: GameMap, b: Dictionary) -> void:
	GameState.run["flags"]["st_" + str(b["id"])] = true
	m.player.frozen = true
	m.player.velocity = Vector2.ZERO
	if b.has("chapter_title") and str(b.get("chapter_title", "")) != "" and bool(b.get("title_card", false)):
		m.hud.toast(str(b["chapter_title"]), Color(1, 0.9, 0.6))
	var lines: Array = _fill(b.get("lines", []))
	await _play_lines(m, lines, str(b["id"]))
	_apply(m, b.get("effects", {}))
	m.player.frozen = false
	Dialogue.block_input()


static func _play_lines(m: GameMap, lines: Array, beat_id := "") -> void:
	var d := Dialogue.instance(m.get_tree())
	var seq: Array = []
	for ln in lines:
		var l: Dictionary = ln
		if l.has("choice"):
			if not seq.is_empty():
				d.say(seq)
				await d.finished
				seq = []
			var one: Dictionary = l.duplicate()
			one.erase("branches")
			d.say([one])
			await d.finished
			var br: Dictionary = l.get("branches", {})
			var pick := str(d.last_choice)
			var gates: Dictionary = l.get("gates", {})
			if gates.has(pick) and not GameState._cond_ok(gates[pick]):
				var g: Dictionary = gates[pick]
				var need := "that"
				if g.has("crystals"):
					need = "◆%d" % int(g["crystals"])
				elif g.has("crops"):
					need = "%d crops" % int(g["crops"])
				elif g.has("item"):
					need = "%d %s" % [int(g["item"][1]), GameState.item_name(str(g["item"][0]))]
				m.hud.toast("You don't have %s yet." % need, Color(1, 0.8, 0.6))
				# Let the beat run again later.
				if beat_id != "":
					GameState.run["flags"].erase("st_" + beat_id)
				return
			if gates.has(pick) and (gates[pick] as Dictionary).has("crops"):
				GameState.take_crops(int(gates[pick]["crops"]))
			if br.has(pick):
				await _play_lines(m, _fill(br[pick]), beat_id)
			if l.has("effects_by_choice") and (l["effects_by_choice"] as Dictionary).has(pick):
				_apply(m, l["effects_by_choice"][pick])
		else:
			seq.append(l)
	if not seq.is_empty():
		d.say(seq)
		await d.finished


## Substitute %hero, %pet, %town, %partner in texts.
static func _fill(lines: Array) -> Array:
	var names := GameState.names()
	var partner := Companion.active_name()
	var out: Array = []
	for ln in lines:
		var l: Dictionary = (ln as Dictionary).duplicate(true)
		for k in ["text", "who"]:
			if l.has(k):
				var s := str(l[k])
				s = s.replace("%hero", str(names.get("character", "you"))).replace("%pet", str(names.get("pet", "Pup"))).replace("%town", str(names.get("town", "town"))).replace("%partner", partner)
				l[k] = s
		out.append(l)
	return out


static func _apply(m: GameMap, fx: Dictionary) -> void:
	for f in fx.get("flags", []):
		GameState.run["flags"][str(f)] = true
	for f in fx.get("unflag", []):
		GameState.run["flags"].erase(str(f))
	for q in fx.get("quest", []):
		GameState.add_quest(str(q[0]), str(q[1]))
		m.hud.toast("New quest: %s" % str(q[1]), Color(1, 0.9, 0.4))
	for q in fx.get("complete", []):
		if GameState.complete_quest(str(q)):
			m.hud.toast("Quest complete.", Color(1, 0.9, 0.4))
	var fr: Dictionary = GameState.run["friendship"]
	for id in fx.get("friend", {}):
		fr[id] = int(fr.get(id, 0)) + int(fx["friend"][id])
	for pair in fx.get("items", []):
		GameState.add_item(str(pair[0]), int(pair[1]))
		m.hud.toast("+%d %s" % [int(pair[1]), GameState.item_name(str(pair[0]))], Color(0.8, 1, 0.8))
	if fx.has("crystals"):
		GameState.run["crystals"] = int(GameState.run["crystals"]) + int(fx["crystals"])
	if fx.has("hint"):
		GameState.add_hint(str(fx["hint"]))
	if fx.has("companion"):
		Companion.recruit(str(fx["companion"]))
		if m.has_method("_refresh_party"):
			m.call("_refresh_party")
	for id in fx.get("bitter", []):
		Companion.refuse(str(id))
	if fx.has("toast"):
		m.hud.toast(str(fx["toast"]), Color(1, 0.9, 0.6))
	if fx.has("sfx"):
		Music.instance(m.get_tree()).sfx(str(fx["sfx"]))
	if fx.has("heal"):
		GameState.run["hp"] = int(GameState.run["max_hp"])
	if fx.has("grow"):
		GameState.grow_vital(str(fx["grow"][0]), int(fx["grow"][1]))
	for sp in fx.get("spawn", []):
		# [kind, x, y, tier, story_flag]: a story enemy; its death sets the flag.
		var e := m.spawn_enemy(str(sp[0]), m.cell_center(Vector2i(int(sp[1]), int(sp[2]))), int(sp[3]) if sp.size() > 3 else -1)
		if sp.size() > 4:
			e.set_meta("story_flag", str(sp[4]))
			e.is_guardian = true
		if sp.size() > 5:
			e.max_hp = int(e.max_hp * float(sp[5]))
			e.hp = e.max_hp
	if fx.has("boss_card"):
		m.boss_card(str(fx["boss_card"]))
	if fx.has("ending"):
		GameState.run["ending"] = str(fx["ending"])
		GameState.run["flags"]["ending_" + str(fx["ending"])] = true
		m.hud.toast("THE END (for now): %s" % str(fx.get("ending_title", fx["ending"])), Color(1, 0.95, 0.7))
	if fx.has("music"):
		Music.instance(m.get_tree()).play(str(fx["music"]))
	if fx.has("shake"):
		m.shake(float(fx["shake"]))
	if fx.has("fx"):
		var f: Array = fx["fx"]
		m.fx(str(f[0]), m.player.position + Vector2(float(f[1]), float(f[2])), 12.0, 0.8)
	if fx.has("scene_to"):
		var s: Array = fx["scene_to"]
		m.go_to(str(s[0]), Vector2(float(s[1]) * GameMap.TILE, float(s[2]) * GameMap.TILE), str(s[3]) if s.size() > 3 else "down")


## For the journal: the current chapter title and the latest unfinished guidance.
static func journal() -> Dictionary:
	var arc := str(GameState.run.get("arc", "penguins"))
	var chs: Array = data().get(arc, [])
	var n := chapter_no()
	if chs.is_empty():
		return {}
	var ch: Dictionary = chs[clampi(n - 1, 0, chs.size() - 1)]
	return {"chapter": n, "title": str(ch.get("title", "")), "summary": str(ch.get("summary", ""))}
