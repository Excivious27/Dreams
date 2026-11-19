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
		# Campaign lead-in beats (CampaignGate) live in their own file.
		var extra: Dictionary = GameState.load_json("res://data/campaign_story.json")
		for k in ["penguins", "gangsters", "both"]:
			if extra.get(k) is Array:
				_data[k] = (_data.get(k, []) as Array) + (extra[k] as Array)
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
	# Every beat for this quest plays, in order: a follow-up whose `after` is the
	# first beat becomes ready once that one has played, so re-check after each.
	m.later(func() -> void:
		var guard := 0
		while guard < 8:
			guard += 1
			var next: Dictionary = {}
			for b in beats():
				if str(b.get("trigger", {}).get("quest_done", "")) == qid and _ready_beat(b, m):
					next = b
					break
			if next.is_empty():
				return
			while Dialogue.instance(m.get_tree()).active or (m.player and m.player.frozen):
				await m.get_tree().process_frame
				if not is_instance_valid(m):
					return
			await play(m, next))


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
	# If the app is closed mid-scene, the beat plays again next time (see GameState.has_run).
	GameState.run["story_pending"] = str(b["id"])
	if str(b["id"]) == "g5_president" and Project.has("tower_plan"):
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["mana"] = int(GameState.run["max_mana"])
		GameState.run["flags"]["shield"] = 3
		m.hud.toast("The Tower Plan: the whole crew has your back. Full health, full mana, a shield.", Color(1, 0.9, 0.5))
	m.player.frozen = true
	m.player.velocity = Vector2.ZERO
	if b.has("chapter_title") and str(b.get("chapter_title", "")) != "" and bool(b.get("title_card", false)):
		m.hud.toast(str(b["chapter_title"]), Color(1, 0.9, 0.6))
	var lines: Array = _fill(b.get("lines", []))
	if str(b["id"]) == "g5_win" and not GameState.is_penguins():
		# The crew were with you the whole way up: each one gets a line.
		var roll: Array = []
		for cid in Crew.all_recruited():
			var fl := str(Crew.members().get(cid, {}).get("finale", ""))
			if fl != "":
				roll.append({"who": "", "text": fl})
		if not roll.is_empty():
			lines = roll + lines
	await _play_lines(m, lines, str(b["id"]))
	if not is_instance_valid(m):
		# The scene changed under the beat (a door, a faint): finish on the new map.
		m = (Engine.get_main_loop() as SceneTree).current_scene as GameMap
		if m == null:
			return
	_apply(m, b.get("effects", {}))
	if is_instance_valid(m):
		_quests_now.call_deferred(m)  # beat flags (final_done, catship_done) close/open quests now
	GameState.run.erase("story_pending")
	GameState.save()
	if is_instance_valid(m) and m.player:
		m.player.frozen = false
	Dialogue.block_input()


## Twice: the first tick closes quests a beat's flags finished, the second opens the next main step.
static func _quests_now(m: GameMap) -> void:
	if is_instance_valid(m) and not GameState.run.is_empty():
		m._check_quests()
		m._check_quests()


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
			if not is_instance_valid(m):
				return  # the scene changed under the choice
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
			if not is_instance_valid(m):
				return
			if l.has("effects_by_choice") and (l["effects_by_choice"] as Dictionary).has(pick):
				_apply(m, l["effects_by_choice"][pick])
		else:
			seq.append(l)
	if not seq.is_empty():
		d.say(seq)
		await d.finished


## Substitute %hero, %pet, %town, %partner in texts.
## Fennimore beaten with a sword (not turned back) can't be turned any more:
## drop fennimore_turnable so the "Make the heart" ending doesn't free her.
static func _fennimore_check() -> void:
	var fl: Dictionary = GameState.run["flags"]
	if fl.has("boss_fennimore") and not fl.has("fennimore_free"):
		fl.erase("fennimore_turnable")


static func _fill(lines: Array) -> Array:
	_fennimore_check()
	var names := GameState.names()
	var partner := Companion.active_name()
	if partner == "":
		# No partner out right now: the friend who's been with you longest.
		for cid in Companion.party().get("known", []):
			partner = str(Companion.defs().get(str(cid), {}).get("name", str(cid).capitalize()))
			break
	if partner == "":
		partner = "a friend"
	var out: Array = []
	# Playing as a story character (Big Jim, Coldy, Mer, Nova, Pip-Pip...): their
	# own lines in scenes would have them talking to themselves, so drop those.
	var me := str(GameState.playables.get(str(GameState.run.get("playable", "")), {}).get("name", "")).get_slice(" (", 0)
	for ln in lines:
		var l: Dictionary = (ln as Dictionary).duplicate(true)
		if me != "" and str(l.get("who", "")) == me and lines.size() > 1 and not l.has("choice") and not l.has("branches"):
			continue
		# "if_flag": only said when that flag is set; "unless_flag": only when it isn't.
		if l.has("if_flag") and not GameState.run["flags"].has(str(l["if_flag"])):
			continue
		if l.has("unless_flag") and GameState.run["flags"].has(str(l["unless_flag"])):
			continue
		if l.has("branches"):
			var br: Dictionary = l["branches"]
			for bk in br:
				br[bk] = _fill(br[bk])
		for k in ["text", "who"]:
			if l.has(k):
				var s := str(l[k])
				s = s.replace("%hero", str(names.get("character", "you"))).replace("%pet", str(names.get("pet", "Pup"))).replace("%town", str(names.get("town", "town"))).replace("%partner", partner)
				l[k] = s
		# Very long lines are split at a sentence so they fit a phone screen;
		# a choice stays on the last part.
		var t := str(l.get("text", ""))
		if t.length() > 280:
			var cut := t.find(". ", t.length() / 2 - 40)
			if cut > 0 and cut < t.length() - 20:
				var first := {"who": l.get("who", ""), "text": t.substr(0, cut + 1)}
				l["text"] = t.substr(cut + 2)
				out.append(first)
		out.append(l)
	return out


static func _apply(m: GameMap, fx: Dictionary) -> void:
	for f in fx.get("flags", []):
		GameState.run["flags"][str(f)] = true
		# A villager the story sends away: drop their open quests (they can't be turned in).
		if str(f).ends_with("_gone"):
			var who := str(f).trim_suffix("_gone")
			GameState.run["quests"] = (GameState.run["quests"] as Array).filter(func(q: Dictionary) -> bool: return q["done"] or str(GameState._quest_def(str(q["id"])).get("giver", "")) != who)
	# {"needs_flag": ["flag to set", ...]}: set only when the first is already set.
	var fi: Dictionary = fx.get("flags_if", {})
	if not fi.is_empty():
		_fennimore_check()
	for need in fi:
		if GameState.run["flags"].has(str(need)):
			for f in fi[need]:
				GameState.run["flags"][str(f)] = true
	for f in fx.get("unflag", []):
		GameState.run["flags"].erase(str(f))
	for q in fx.get("quest", []):
		# Many of these are also added by tick_quests: only announce new ones.
		if GameState.has_quest(str(q[0])):
			continue
		GameState.add_quest(str(q[0]), str(q[1]))
		m.hud.toast("New quest: %s" % str(q[1]), Color(1, 0.9, 0.4))
	for q in fx.get("complete", []):
		if GameState.complete_quest(str(q)):
			m.hud.toast(GameMap.quest_done_text(str(q)), Color(1, 0.9, 0.4))
	var fr: Dictionary = GameState.run["friendship"]
	for id in fx.get("friend", {}):
		GameState.add_friend(str(id), int(fx["friend"][id]))
	for pair in fx.get("items", []):
		GameState.add_item(str(pair[0]), int(pair[1]))
		m.hud.toast("%+d %s" % [int(pair[1]), GameState.item_name(str(pair[0]))], Color(0.8, 1, 0.8) if int(pair[1]) > 0 else Color(1, 0.85, 0.7))
	if fx.has("crystals"):
		GameState.run["crystals"] = int(GameState.run["crystals"]) + int(fx["crystals"])
	if fx.has("hint"):
		GameState.add_hint(str(fx["hint"]))
	if fx.has("companion"):
		Companion.recruit(str(fx["companion"]))
		if m.has_method("_refresh_party"):
			m.call("_refresh_party")
	if fx.has("know") and not str(fx["know"]) in (Companion.party().get("known", []) as Array) and str(fx["know"]) != str(GameState.run.get("playable", "")):
		# A companion who catches up with you without taking the active slot.
		Companion.recruit(str(fx["know"]), false)
		m.hud.toast("%s catches up with you." % str(Companion.defs().get(str(fx["know"]), {}).get("name", fx["know"])), Color(0.8, 0.95, 1.0))
	for id in fx.get("bitter", []):
		Companion.refuse(str(id))
	if fx.has("weaken"):
		# ["story_flag", factor]: a live story enemy loses part of its health now.
		var wf := str(fx["weaken"][0])
		for e in m.enemies:
			if is_instance_valid(e) and str(e.get_meta("story_flag", "")) == wf:
				e.max_hp = maxi(1, int(e.max_hp * float(fx["weaken"][1])))
				e.hp = mini(e.hp, e.max_hp)
	if fx.has("clear_kind"):
		# Every enemy of this kind on the map is driven off (an ally's help).
		for e in m.enemies.duplicate():
			var kinds: Array = fx["clear_kind"] if fx["clear_kind"] is Array else [fx["clear_kind"]]
			if is_instance_valid(e) and e.kind in kinds and e._alive:
				# Freed, not beaten: Fennimore walks away when she's been turned back.
				if e.kind == "finargle_elder" and GameState.run["flags"].has("fennimore_free"):
					m.enemies.erase(e)
					e._alive = false
					m.fx("blink" if Art.has("fx", "blink") else "poof", e.position + Vector2(0, -8), 14.0, 0.4)
					e.queue_free()
					continue
				e.hit(99999, e.position, true)
	if fx.has("toast"):
		m.hud.toast(str(fx["toast"]), Color(1, 0.9, 0.6))
		if str(fx["toast"]).find("joined the crew") >= 0 and Art.has("ui", "crew_joined"):
			var sp := Art.sprite("ui", "crew_joined")
			if sp:
				sp.position = m.player.position + Vector2(0, -30)
				sp.scale = Vector2(0.6, 0.6)
				sp.z_index = 20
				m.add_child(sp)
				var tw := m.create_tween()
				tw.tween_property(sp, "modulate:a", 0.0, 1.2)
				tw.tween_callback(sp.queue_free)
	if fx.has("sfx"):
		Music.instance(m.get_tree()).sfx("quest_done" if str(fx["sfx"]) == "levelup" else str(fx["sfx"]), "levelup")
	if fx.has("heal"):
		GameState.run["hp"] = int(GameState.run["max_hp"])
	if fx.has("grow"):
		GameState.grow_vital(str(fx["grow"][0]), int(fx["grow"][1]))
	var spawns: Array = fx.get("spawn", [])
	if not spawns.is_empty():
		_spawn_list(m, spawns)
		# Remember where story enemies stand, so a story boss that wasn't beaten
		# (you died, left, or reloaded) is back when you return.
		var keep: Array = spawns.filter(func(sp: Array) -> bool: return sp.size() > 4)
		if not keep.is_empty():
			var ss: Dictionary = GameState.run.get("story_spawns", {})
			ss[m.scene_id() + "|" + str(Time.get_ticks_usec())] = keep
			GameState.run["story_spawns"] = ss
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


static func _spawn_list(m: GameMap, spawns: Array) -> void:
	for sp in spawns:
		# [kind, x, y, tier, story_flag, hp_mult]: a story enemy; its death sets the flag.
		var e := m.spawn_enemy(str(sp[0]), m.cell_center(Vector2i(int(sp[1]), int(sp[2]))), int(sp[3]) if sp.size() > 3 else -1)
		if e == null:
			continue
		if sp.size() > 4:
			e.set_meta("story_flag", str(sp[4]))
			e.is_guardian = true
		if sp.size() > 5:
			e.max_hp = int(e.max_hp * float(sp[5]))
			e.hp = e.max_hp
		# The bell: the town's help cracks the Dark Crystal's shell (half health).
		if sp.size() > 4 and str(sp[4]) == "boss_dark_crystal" and GameState.run["flags"].has("final_town_help"):
			e.max_hp = maxi(1, e.max_hp / 2)
			e.hp = e.max_hp


## Called when a map is ready: bring back story enemies whose flag isn't set yet.
## Also covers saves from before story_spawns existed (beats already fired).
static func restore_spawns(m: GameMap) -> void:
	var flags: Dictionary = GameState.run["flags"]
	var ss: Dictionary = GameState.run.get("story_spawns", {})
	var done_keys: Array = []
	var restored := {}
	for k in ss.keys():
		var parts := str(k).split("|")
		var list: Array = ss[k]
		var live: Array = list.filter(func(sp: Array) -> bool: return not flags.has(str(sp[4])))
		if live.is_empty():
			done_keys.append(k)
			continue
		if parts[0] != m.scene_id():
			continue
		_spawn_list(m, live)
		for sp in live:
			restored[str(sp[4])] = true
	for k in done_keys:
		ss.erase(k)
	# Older saves: a fired spawn beat whose flag never got set.
	for b in beats():
		var fx: Dictionary = b.get("effects", {})
		if not flags.has("st_" + str(b["id"])) or not fx.has("spawn"):
			continue
		var tr: Dictionary = b.get("trigger", {})
		var sc := str(tr.get("scene", {"spire": "moon", "tower_doors": "uptown"}.get(str(tr.get("talk", "")), "")))
		if sc != m.scene_id():
			continue
		var live2: Array = (fx["spawn"] as Array).filter(func(sp: Array) -> bool: return sp.size() > 4 and not flags.has(str(sp[4])) and not restored.has(str(sp[4])))
		if not live2.is_empty():
			_spawn_list(m, live2)


## For the journal: the current chapter title and the latest unfinished guidance.
static func journal() -> Dictionary:
	var arc := str(GameState.run.get("arc", "penguins"))
	var chs: Array = data().get(arc, [])
	var n := chapter_no()
	if chs.is_empty():
		return {}
	var ch: Dictionary = chs[clampi(n - 1, 0, chs.size() - 1)]
	return {"chapter": n, "title": str(ch.get("title", "")), "summary": str(ch.get("summary", ""))}
