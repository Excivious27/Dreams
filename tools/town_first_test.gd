extends SceneTree
## First town visits, both arcs (conduct 1, c1_11): the arrival and the tour
## (the guide walks up to you), first-meeting introductions, door hours for
## shops and homes (TownHours) and the counters, the community board on day 1,
## the first week's mail and the mailbox flag, villagers out in the rain.
##   godot --headless --path . -s res://tools/town_first_test.gd
var fails := 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(1101)  # the game's own randf/randi rolls repeat every run
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drain() -> void:
	var d := Dialogue.instance(self)
	var last := ""
	for k in 80:
		if not d.active:
			await _frames(3)
			if not d.active:
				return
		var cur := "%s: %s" % [d._who.text, d._full]
		if cur != last:
			said.append(cur)
			last = cur
		d._advance()
		await _frames(2)


func _toast_texts(m: GameMap) -> String:
	var out := ""
	for c in m.hud._toasts.get_children():
		if c is Label and not c.is_queued_for_deletion():
			out += (c as Label).text + "\n"
			c.queue_free()
	return out


func _npc(m: GameMap, id: String) -> Npc:
	for n: Npc in m.get("npcs"):
		if n.id == id:
			return n
	return null


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		await _arc(arc)
	print("town_first_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _arc(arc: String) -> void:
	var tag := arc.left(3)
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["partner_scene", "gangsters_intro"]:
		GameState.run["flags"][f] = true
	GameState.run["day"] = 1
	GameState.run["time"] = 10 * 60
	var pen := arc == "penguins"
	# Day 1 weather: the gangster opening is rain, and some grown-ups still go out.
	if not pen:
		check(GameState.weather_today() == "rain", "[%s] day 1 rains" % tag)
		var out := 0
		for id in GameState.npcs:
			var r: Array = GameState.npcs[id].get("routine", [])
			if r.is_empty() or id in ["finn", "rook", "sal"]:
				continue
			for h in [10, 12, 16]:
				GameState.run["time"] = h * 60
				if not Npc.is_indoors(Npc.place_now(r, str(id))):
					out += 1
					break
		GameState.run["time"] = 10 * 60
		check(out >= 3, "[%s] rain: at least 3 villagers besides Finn/Rook/Sal still out (%d)" % [tag, out])
		check(not Npc.rain_walker("pip"), "[%s] kids stay in out of the rain" % tag)

	# Arrival + tour: the guide walks up and stands by you while they talk.
	GameMap.next_spawn = Vector2(40 * 16, 3 * 16)
	change_scene_to_file("res://scenes/town.tscn")
	await _frames(14)
	var m := current_scene as GameMap
	var guide_id := "alder" if pen else "sal"
	var near := false
	said.clear()
	var d := Dialogue.instance(self)
	var gt := 0.0  # game time (summed deltas; a fixed frame count under --fixed-fps), not the wall clock
	var i := 0
	while gt < 40.0:  # the guide walks up on the game clock
		i += 1
		await process_frame
		gt += root.get_process_delta_time()
		var g := _npc(m, guide_id)
		if d.active and g and g.hold and g.visible and g.position.distance_to(m.player.position) < 48.0:
			near = true
		if d.active:
			if i % 4 == 0:
				var cur := "%s: %s" % [d._who.text, d._full]
				if said.is_empty() or said[-1] != cur:
					said.append(cur)
				d._advance()
		elif GameState.run["flags"].has("town_tour") and not m.player.frozen:
			break
	check(GameState.run["flags"].has("town_tour"), "[%s] tour ran" % tag)
	check(near, "[%s] the tour guide (%s) stood next to the player while talking" % [tag, guide_id])
	check(Intros.met(guide_id), "[%s] the guide counts as met" % tag)
	var txt := "\n".join(said)
	if not pen:
		check(not txt.contains("A woman"), "[%s] Sal is introduced as a man, like his sprite" % tag)
	var g3 := _npc(m, guide_id)
	check(g3 != null and (g3._leaving or not g3.hold), "[%s] the guide heads off after the tour" % tag)
	if g3 and g3._leaving:
		g3.position = g3.home  # skip the walk: at their door / spot
		g3._path.clear()
		g3._target = g3.home
		await _frames(10)
	check(g3 != null and not g3.hold, "[%s] the guide is back on their routine (leaving=%s vis=%s pos=%s home=%s target=%s path=%d pm=%s)" % [tag, g3._leaving, g3.visible, g3.position, g3.home, g3._target, g3._path.size(), g3.process_mode])
	_toast_texts(m)

	# Intros: first talk says who they are; the second is ordinary chatter.
	var maple := _npc(m, "maple")
	check(maple != null, "[%s] Maple is in town" % tag)
	if maple:
		said.clear()
		m.call("_talk", maple)
		await _frames(3)
		await _drain()
		check(" ".join(said).contains("General Store") and Intros.met("maple"), "[%s] Maple introduces herself and her store (%s)" % [tag, said])
		said.clear()
		m.call("_talk", maple)
		await _frames(3)
		await _drain()
		check(not " ".join(said).contains("north of the plaza: seeds"), "[%s] no second introduction" % tag)
	for id in GameState.npcs:
		if not (GameState.npcs[id].get("routine", []) as Array).is_empty():
			check(not Intros.lines_for(str(id)).is_empty(), "[%s] %s has a first-meeting introduction" % [tag, id])

	# Door hours.
	var store_door := Vector2i(-1, -1)
	var home_door := Vector2i(-1, -1)
	for c in m.things:
		var t: Dictionary = m.things[c]
		if str(t.get("interior", "")) == "store" and store_door == Vector2i(-1, -1):
			store_door = c
		if str(t.get("interior", "")) == "cottage_a" and home_door == Vector2i(-1, -1):
			home_door = c
	check(store_door != Vector2i(-1, -1) and home_door != Vector2i(-1, -1), "[%s] store and Wren's cottage doors found" % tag)
	GameState.run["time"] = 23 * 60
	m.interact(store_door, m.things[store_door])
	await _frames(2)
	var tt := _toast_texts(m)
	check(current_scene == m and not m._changing, "[%s] the store door stays shut at 11pm" % tag)
	check(tt.contains("closed") and tt.contains("7am to 9pm"), "[%s] the store's sign gives its hours (%s)" % [tag, tt])
	check(TownHours.door_reason("cottage_a") != "", "[%s] homes don't answer at 11pm" % tag)
	GameState.run["friendship"]["wren"] = 400
	check(TownHours.door_reason("cottage_a") == "", "[%s] a good friend's door opens late (hearts %d)" % [tag, GameState.friend_hearts("wren")])
	GameState.run["friendship"]["wren"] = 0
	check(TownHours.door_reason("inn") == "" and TownHours.door_reason("chapel") == "", "[%s] inn and chapel never close" % tag)
	check(TownHours.counter_shut("store") != "" and TownHours.counter_shut("bait") != "", "[%s] counters are shut at night too" % tag)
	GameState.run["time"] = 10 * 60
	check(TownHours.door_reason("store") == "" and TownHours.door_reason("cottage_a") == "" and TownHours.counter_shut("bait") == "", "[%s] all open at 10am" % tag)
	check(TownHours.door_reason("bank") == "" and TownHours.SHOPS["bank"][1] == 17, "[%s] bank keeps Ivy's 8 to 5" % tag)

	# Board on day 1: fair pay; crop orders you can actually plant.
	GameState.run.erase("board")
	var grow := Shops.growable_now()
	for j: Dictionary in GameState.board_today():
		check(int(j["crystals"]) >= 12 + 4 * int(j["n"]), "[%s] board pay %d for %d %s" % [tag, int(j["crystals"]), int(j["n"]), j["item"]])
		if str(j["id"]).ends_with("_c"):
			var ok := false
			for cid in GameState.crops:
				if str(GameState.crops[cid].get("yield", "")) == str(j["item"]) and grow.has(str(cid)):
					ok = true
			check(ok, "[%s] crop order %s has seeds in town" % [tag, j["item"]])

	# Mail, days 1-5: story letters, the first-week letters, the mailbox flag.
	check(Mail.story_due().size() == (1 if pen else 0), "[%s] day 1 mailbox: %d story letters" % [tag, Mail.story_due().size()])
	var froms: Array = []
	for day in range(1, 6):
		GameState.run["day"] = day
		GameState.run["time"] = 22 * 60
		var before: int = Mail.list().size()
		GameState.sleep()
		for x: Dictionary in Mail.list().slice(before):
			froms.append("%d:%s" % [int(GameState.run["day"]), str(x["from"])])
		if int(GameState.run["day"]) == 2 and not pen:
			check(Mail.story_due().size() == 1, "[%s] M.'s second letter waits on day 2" % tag)
	check(froms.has("2:" + ("Mayor Alder" if pen else "Maple")), "[%s] welcome letter on day 2 (%s)" % [tag, froms])
	check(froms.has("5:Posy"), "[%s] Posy's bread on day 5 (%s)" % [tag, froms])
	check(Mail.waiting() > 0, "[%s] mailbox has things waiting" % tag)
	var pm: Dictionary = {}
	for x: Dictionary in Mail.list():
		if str(x["from"]) == "Posy":
			pm = x
	var b0 := GameState.count("bread")
	check(Mail.act(pm) == "" and GameState.count("bread") == b0 + 2, "[%s] Posy's two loaves arrive" % tag)
	for x: Dictionary in Mail.list():
		x["read"] = true
		x["got"] = true
		x["done"] = true
	for sl: Dictionary in Mail.story_due():
		GameState.run["flags"][str(sl["flag"])] = true
	check(Mail.waiting() == 0, "[%s] nothing waiting once all read" % tag)
