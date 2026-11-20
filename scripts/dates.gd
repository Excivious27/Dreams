class_name Dates
## Dates while you're dating (CONDUCT 7 P1). Talking to your sweetheart by day may
## bring an invitation (at most every `invite_every` days): accept and run.romance.date
## holds {id, n, day, scene, place, hours}. Dates.tick (GameMap._process) plays the
## scene when you're on that map inside the hour window: they walk up beside you, a
## few lines, one question (every answer is kind, +10..+20 friendship), a heart.
## Three dates per candidate in data/romance.json (gen_romance.py); they cycle after.
## A missed date costs nothing but the date credit; the next talk says so gently.

static var _t := 0.0
static var _busy := false


static func hour_text(h: int) -> String:
	var hh := h % 24
	return "%d%s" % [12 if hh % 12 == 0 else hh % 12, "am" if hh < 12 else "pm"]


static func _date(id: String, n: int) -> Dictionary:
	var ds: Array = Romance.cand(id).get("dates", [])
	return ds[n % ds.size()] if not ds.is_empty() else {}


## Today's pending date ({} = none).
static func pending() -> Dictionary:
	var d: Dictionary = Romance.st().get("date", {})
	if d.is_empty() or int(d.get("day", -1)) != int(GameState.run["day"]):
		return {}
	return d


static func can_invite(id: String) -> bool:
	var s := Romance.st()
	if str(s["dating"]) != id or not pending().is_empty():
		return false
	if int(GameState.run["day"]) - int(s["invite_day"]) < int(Romance.rule("invite_every")):
		return false
	var dd := _date(id, int((s["dates"] as Dictionary).get(id, 0)))
	return not dd.is_empty() and int(GameState.run["time"]) / 60 < int(dd["hours"][0]) - 1


## Make the invitation for tonight (no UI). Returns the date dict.
static func invite(id: String) -> Dictionary:
	var s := Romance.st()
	var n := int((s["dates"] as Dictionary).get(id, 0))
	var dd := _date(id, n)
	s["invite_day"] = int(GameState.run["day"])
	s["date"] = {"id": id, "n": n, "day": int(GameState.run["day"]), "scene": str(dd["scene"]), "place": str(dd["place"]), "hours": dd["hours"]}
	return s["date"]


## Romance.talk while dating (no item held). True = handled.
static func talk(m: GameMap, id: String) -> bool:
	if GameState.visiting():
		return false  # dates run on our own days and maps; the host's day would stamp run.romance (C9 P6)
	var s := Romance.st()
	var d: Dictionary = s.get("date", {})
	if not d.is_empty() and int(d.get("day", -1)) < int(GameState.run["day"]):
		s["date"] = {}
		await m.say(Romance._shared("missed", id))
		return true
	if not pending().is_empty():
		await m.say([{"who": Romance.name_of(id), "text": "See you tonight at %s! After %s." % [str(d["place"]), hour_text(int(d["hours"][0]))], "mood": "happy"}])
		return true
	if not can_invite(id):
		return false
	var dl := Dialogue.instance(m.get_tree())
	dl.say([{"who": Romance.name_of(id), "text": Romance._fill(str(Romance.data()["shared"]["invite"]), id), "choice": ["It's a date!", "Let's just stay friends...", "Not tonight"], "key": ""}])
	await dl.finished
	match dl.last_choice:
		0:
			var nd := invite(id)
			var txt := str(Romance.data()["shared"]["invite_yes"]).replace("{place}", str(nd["place"])).replace("{hour}", hour_text(int(nd["hours"][0])))
			await m.say([{"who": Romance.name_of(id), "text": txt.left(1).to_upper() + txt.substr(1), "mood": "happy"}])
			m.hud.toast("Date tonight: %s, after %s" % [str(nd["place"]), hour_text(int(nd["hours"][0]))], Color(1, 0.75, 0.9))
		1:
			var c := Dialogue.instance(m.get_tree())
			c.say([{"text": "Stay friends with %s? You can still be close; you just won't be dating." % Romance.name_of(id), "choice": ["Yes, stay friends", "No, never mind"], "key": ""}])
			await c.finished
			if c.last_choice == 0:
				Romance.stay_friends(id)
				await m.say(Romance._shared("stay_friends", id))
		_:
			s["invite_day"] = int(GameState.run["day"])  # asked today: no nagging
			await m.say(Romance._shared("invite_no", id))
	return true


static func tick(m: GameMap, delta: float) -> void:
	_t -= delta
	if _t > 0.0 or _busy:
		return
	_t = 0.5
	if GameState.visiting():
		return
	var d := pending()
	if d.is_empty() or m.player == null or m.player.frozen or m.get_tree().paused or Dialogue.instance(m.get_tree()).active:
		return
	if str(d["scene"]) != m.scene_id():
		return
	var h := int(GameState.run["time"]) / 60.0
	var hs: Array = d["hours"]
	if h < float(hs[0]) or h >= float(hs[1]):
		return
	_busy = true
	m.later(func() -> void: await play(m, d))


## The date scene. Works without art or a villager on the map (they walk up).
static func play(m: GameMap, d: Dictionary) -> void:
	var id := str(d["id"])
	var dd := _date(id, int(d["n"]))
	var gained := 0
	if Romance.skip_scenes:
		gained = int(dd["a"][0][1])
	else:
		m.player.frozen = true
		m.player.velocity = Vector2.ZERO
		var npc := Events._npc(m, id)
		var temp := false
		if npc == null:
			npc = Npc.new()
			npc.map = m
			npc.setup(id, GameState.npcs.get(id, {}), m.player.position + Vector2(18, 0))
			m.add_child(npc)
			temp = true
		npc.hold = true
		var pc := m.player.cell()
		var at := pc + Vector2i(1, 0)
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if m.in_content(pc + off) and not m.blocked.has(pc + off) and not m.is_water_cell(pc + off):
				at = pc + off
				break
		npc.visible = true
		npc.position = m.cell_center(at)
		npc._target = npc.position
		npc._path.clear()
		npc.face(m.player.position)
		m.player.face_toward(npc.position)
		Music.instance(m.get_tree()).play_held("date_evening" if Music.has_track("date_evening") else m.area_track())
		m.emote(npc, "heart", 1.2)
		await m.say(Romance._lines(dd.get("lines", []), id))
		if not is_instance_valid(m) or not m.is_inside_tree():
			_busy = false
			return
		var opts: Array = []
		for a: Array in dd["a"]:
			opts.append(str(a[0]))
		var dl := Dialogue.instance(m.get_tree())
		dl.say([{"who": Romance.name_of(id), "text": str(dd["q"]), "choice": opts, "key": "date"}])
		await dl.finished
		var pick: Array = dd["a"][clampi(dl.last_choice, 0, opts.size() - 1)]
		gained = int(pick[1])
		await m.say(Romance._lines([{"who": Romance.name_of(id), "text": str(pick[2]), "mood": "love"}], id))
		if is_instance_valid(npc):
			m.emote(npc, "heart", 1.5)
		Music.instance(m.get_tree()).sfx("j_heart", "levelup")
		m.hud.toast("A lovely evening with %s ♥" % Romance.name_of(id), Color(1, 0.75, 0.9))
		Music.instance(m.get_tree()).release_hold()
		Music.instance(m.get_tree()).play(m.area_track())
		m.player.frozen = false
		if is_instance_valid(npc):
			if temp:
				npc.queue_free()
			else:
				npc.hold = false
				npc.walk_off()
	Romance.date_done(id, gained)
	_busy = false
