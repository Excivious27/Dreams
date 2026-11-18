class_name Events
## Scripted scenes between villagers (data/events.json). When you walk into the
## scene's area on the right day/hour (and any friendship/quest conditions
## hold), the actors step over, play the scene with portraits, and leave you a
## hint in the journal. Each plays once per run (flag "ev_<id>").

static var _data: Array = []
static var _t := 0.0


static func data() -> Array:
	if _data.is_empty():
		var f := FileAccess.open("res://data/events.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Array:
				_data = parsed
	return _data


## Call from GameMap._process. Cheap: checks twice a second.
static func tick(m: GameMap, delta: float) -> void:
	_t -= delta
	if _t > 0.0 or m.player == null or m.player.frozen or m.get_tree().paused or Dialogue.instance(m.get_tree()).active:
		return
	_t = 0.5
	var pc := m.player.cell()
	var hour := int(GameState.run["time"]) / 60.0
	for ev in data():
		if str(ev.get("scene", "")) != m.scene_id():
			continue
		if GameState.run["flags"].has("ev_" + str(ev["id"])):
			continue
		var a: Array = ev["area"]
		if not Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])).has_point(pc):
			continue
		var when: Dictionary = ev.get("when", {})
		if when.has("hours") and (hour < float(when["hours"][0]) or hour >= float(when["hours"][1])):
			continue
		if not GameState._cond_ok(when):
			continue
		# All named actors must exist in this map (regions: the resident; town: everyone with a routine).
		var actors: Array = []
		for id in ev.get("actors", []):
			var n := _npc(m, str(id))
			if n == null:
				actors.clear()
				break
			actors.append(n)
		if actors.is_empty() and not ev.get("actors", []).is_empty():
			continue
		GameState.run["flags"]["ev_" + str(ev["id"])] = true
		m.later(func() -> void: await play(m, ev, actors))
		return


static func play(m: GameMap, ev: Dictionary, actors: Array) -> void:
	m.player.frozen = true
	m.player.velocity = Vector2.ZERO
	# Gather the actors in a loose arc in front of the player.
	var pc := m.player.cell()
	var spots: Array[Vector2i] = [Vector2i(-1, -2), Vector2i(1, -2), Vector2i(0, -3), Vector2i(-2, -1), Vector2i(2, -1)]
	var i := 0
	for n in actors:
		var npc := n as Npc
		var target := pc + spots[i % spots.size()]
		for tries in 12:
			if m.in_content(target) and not m.blocked.has(target) and not m.is_water_cell(target):
				break
			target = pc + Vector2i(randi_range(-3, 3), randi_range(-3, -1))
		npc.visible = true
		npc.position = m.cell_center(target)
		npc._target = npc.position
		npc._path.clear()
		npc.face(m.player.position)
		npc._end_chat()
		i += 1
	if not actors.is_empty():
		var first := actors[0] as Npc
		m.player.face_toward(first.position)
		m.emote(first, "surprise", 1.0)
		await m.get_tree().create_timer(0.6).timeout
		if not is_instance_valid(m) or not m.is_inside_tree():
			return  # the map changed under us (scene switch mid-event)
	var ls: Array = (ev.get("lines", []) as Array).duplicate(true)
	if not GameState.is_penguins():
		for l in ls:
			if l.has("text_gangsters"):
				l["text"] = l["text_gangsters"]
	await m.say(ls)
	if not is_instance_valid(m) or not m.is_inside_tree():
		return
	var after: Dictionary = ev.get("after", {})
	for id in after.get("friend", {}):
		GameState.run["friendship"][str(id)] = int(GameState.run["friendship"].get(str(id), 0)) + int(after["friend"][id])
	if after.has("item"):
		GameState.add_item(str(after["item"][0]), int(after["item"][1]))
		m.hud.toast("Got %d %s." % [int(after["item"][1]), GameState.item_name(str(after["item"][0]))], Color(1, 0.9, 0.5))
	if after.has("flag"):
		GameState.run["flags"][str(after["flag"])] = true
	if after.has("quest"):
		var qd := GameState._quest_def(str(after["quest"]))
		if not qd.is_empty():
			GameState.add_quest(str(after["quest"]), str(qd["text"]))
	if after.has("hint"):
		var hint := str(after["hint"])
		if not GameState.is_penguins():
			hint = hint.replace("Grumps", "thugs").replace("grumps", "thugs")
		GameState.add_hint(hint)
		m.hud.toast("Journal: " + hint, Color(0.9, 0.95, 1.0))
	m.player.frozen = false
	for n in actors:
		(n as Npc)._apply_routine(true)


static func _npc(m: GameMap, id: String) -> Npc:
	for ch in m.get_children():
		if ch is Npc and (ch as Npc).id == id:
			return ch
	return null
