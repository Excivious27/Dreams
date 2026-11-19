class_name Marked
extends RefCounted
## The Marked: ten young gangsters (15 to 30), each carrying a Gift.
## They turn up in the districts, fight with their Gift, and never die: beaten,
## they yield, tell you where the Gift came from, and you choose whether they
## join the crew (lending you the Gift) or go home. Every origin story has the
## same man in a grey suit and the same black stone in it; the President fight
## says why. Data: data/gifts.json (tools/gen_gifts.py).

static func all() -> Dictionary:
	return Gift.data().get("marked", {})


static func state(id: String) -> String:
	return str(GameState.run["flags"].get("marked_" + id, ""))   # "", "crew", "free"


static func met() -> int:
	var n := 0
	for id: String in all():
		if state(id) != "":
			n += 1
	return n


## One Marked at most turns up when you walk into their district.
static func on_enter(m: GameMap) -> void:
	if not Racket.on() or m.player == null:
		return
	if m.scene_id() == "hideout" and not GameState.run["flags"].has("st_g2_arrive"):
		return  # not during the first walk into town
	for id: String in all():
		var d: Dictionary = all()[id]
		if str(d["scene"]) != m.scene_id() or state(id) != "":
			continue
		if GameState.progress_tier() < int(d.get("progress", 1)) - 1:
			continue
		if int(GameState.run["flags"].get("marked_try_" + id, -1)) == int(GameState.run["day"]):
			continue  # beaten you once today already; come back tomorrow
		# Come at you from the side of the map with room, never from off the edge.
		var mid := Vector2(m.cols, m.rows) * 8.0 + m.offset()
		var side := 1.0 if mid.x >= m.player.position.x else -1.0
		var e := spawn(m, id, m.player.position + Vector2(96 * side, -40 if mid.y < m.player.position.y else 40))
		if e:
			m.hud.toast("%s, \"%s\": %s" % [str(d["name"]), str(d["epithet"]), str(d["intro"])], Color(str(Gift.def(str(d["gift"])).get("colour", "ffffff"))))
			Music.instance(m.get_tree()).sfx("alert")
			Music.instance(m.get_tree()).play("marked" if Music.has_track("marked") else "boss")  # _boss_playing keeps it until they yield
		return


static func spawn(m: GameMap, id: String, at: Vector2) -> Enemy:
	var e := m.spawn_enemy("marked_" + id, at)
	if e:
		e.set_meta("marked", id)
	return e


## Called instead of dying. The fight stops; they talk.
static func yield_to(m: GameMap, e: Enemy) -> void:
	var id := str(e.get_meta("marked"))
	var d: Dictionary = all().get(id, {})
	e._alive = false
	m.enemies.erase(e)
	if Art.has("fx", "gift_yield"):
		m.fx("gift_yield", e.position + Vector2(0, -4), 10.0, 0.6)
	for o in m.enemies.duplicate():
		if is_instance_valid(o) and o.has_meta("decoy"):
			o._die()
	if e._gift:
		e._gift.queue_free()
		e._gift = null
	e.modulate.a = 1.0
	if e._sprite:
		e._sprite.modulate.a = 1.0
	GameState.run["crystals"] = int(GameState.run["crystals"]) + e.reward
	m.hud.toast("+%d crystals" % e.reward, Color(0.7, 0.9, 1))
	m.xp("combat", int(GameState.enemy_data["enemies"]["marked_" + id].get("xp", 40)))
	Music.instance(m.get_tree()).sfx("boss_down")
	m.fx("sparkle", e.position + Vector2(0, -10), 16.0, 0.8)
	var who := str(d.get("name", id))
	var first := met() == 0
	var dl := Dialogue.instance(m.get_tree())
	var lines: Array = [
		{"who": who, "text": str(d.get("yield", "..."))},
		{"who": who, "text": str(d.get("origin", ""))}]
	if first:
		lines.append({"who": "", "text": "A black stone. You've seen that colour before, in the meadow, where nothing grows."})
	elif met() == 4:
		lines.append({"who": "", "text": "Five of them now, and it is the same story every time. The same grey suit. The same stone."})
	var ask := {"who": who, "text": "So. What happens to me?", "choice": ["Come with us. We look after our own.", "Go home. Nobody's chasing you."], "key": ""}
	lines.append(ask)
	dl.say(lines)
	await dl.finished
	# Closed without picking: ask again, so nothing is decided for you.
	while dl.last_choice < 0 and is_instance_valid(dl):  # each pass waits for the player
		dl.say([ask])
		await dl.finished
	var join := dl.last_choice == 0
	if join:
		GameState.run["flags"]["marked_" + id] = "crew"
		Companion.recruit("mk_" + id, false)
		m.hud.toast("%s joins the crew. Pick them in Menu > Party to borrow the %s." % [who.split(" ")[0], str(Gift.def(str(d["gift"])).get("name", "Gift"))], Color(1, 0.9, 0.5))
	else:
		GameState.run["flags"]["marked_" + id] = "free"
		Racket.set_heat(Racket.heat() - 1)
		m.hud.toast("%s walks. Word gets round that you let them: the streets ease off a little." % who.split(" ")[0], Color(0.7, 1, 0.8))
	GameState.add_hint("%s (\"%s\", %d): %s" % [who, str(d["epithet"]), int(d["age"]), "crew" if join else "went home"])
	Ops.on_kill(m)  # the last hostile on a block yielding still claims it
	if is_instance_valid(e):
		var tw := e.create_tween()
		tw.tween_property(e, "modulate:a", 0.0, 0.6)
		tw.tween_callback(e.queue_free)


## You lost to them: they don't finish you, and they won't fight again today.
static func mark_try(id: String) -> void:
	GameState.run["flags"]["marked_try_" + id] = int(GameState.run["day"])
