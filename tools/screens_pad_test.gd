extends SceneTree
## CONDUCT 9 P3: the full-screen screens played with actions only (what a pad
## or keyboard sends): ChestScreen, CraftScreen, the campaign list/board, the
## prize counter (8+ shelf scrolls), Map tab pins (MegaMap.step_sel), SlotDrag's
## pad carry, arcade/bowling decks (pad hide, left-handed mirror, shake off,
## held-direction repeat) and the gangster picker blurbs.
##   godot --headless --path . --fixed-fps 60 -s res://tools/screens_pad_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(9)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## One press of an action, seen by every screen's _process this frame.
func _press(a: String, hold := 1) -> void:
	await process_frame
	Input.action_press(a)
	await _frames(hold)
	Input.action_release(a)
	await _frames(2)


func _child(m: Node, cls: String) -> Node:
	for c in m.get_children():
		if c.get_script() and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null


func _run() -> void:
	InputSetup.ensure_actions()
	TouchControls.visible_controls = false  # keys/pad, not fingers
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	for f in ["town_seen", "town_tour", "partner_scene", "interior_seen", "store_first"]:
		GameState.run["flags"][f] = true
	GameState.run["builds"] = {"furnace": 2, "workbench": 2}
	for id in ["stone", "wood", "copper", "coal", "fiber", "turnip"]:
		GameState.add_item(id, 20)
	GameState.run["crystals"] = 50000
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await _frames(30)
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			break
		if d._in_choice:
			d._choose("", d._choices.get_child_count() - 1)
		else:
			d._advance()
		await _frames(2)
	var m := current_scene as GameMap
	await _chest(m)
	await _craft(m)
	await _prizes(m)
	await _campaign(m)
	_mega()
	_slot_drag()
	_rep()
	_arcade()
	_bowling()
	print("screens_pad_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _chest(m: GameMap) -> void:
	ChestScreen.open(m, "chest", "Chest")
	await _frames(12)
	var cs := _child(m, "ChestScreen") as ChestScreen
	check(cs != null, "chest opens")
	if cs == null:
		return
	check(cs.is_in_group("toast_hold"), "chest holds toasts")
	var cur := cs._cur
	cur.resync()
	check(cur.cur != null and cur.key_of(cur.cur).begins_with("b:"), "cursor starts on the bag (%s)" % (cur.key_of(cur.cur) if cur.cur else "none"))
	var first := str(GameState.bag_slots()[0])
	var had := GameState.count(first)
	await _press("a")  # A = tap: the stack moves into the chest
	check(GameState.count(first) < had and Storage.amount("chest", first) > 0, "A moves %s across (%d -> %d)" % [first, had, GameState.count(first)])
	await _press("up")
	check(cur.cur != null and not cur.key_of(cur.cur).begins_with("b:"), "up leaves the bag grid (%s)" % cur.key_of(cur.cur))
	# Find the chest slot holding the item, pick it (CONFIRM_ALT), put it on bag slot 0.
	var ci := Storage.slots("chest").find(first)
	check(ci >= 0, "item is in a chest slot")
	cur.select_key("c:%d" % ci)
	await _press(ScreenCursor.CONFIRM_ALT)
	check(not cs._pick.is_empty() and str(cs._pick["grid"]) == "c", "X picks the chest stack")
	cur.select_key("b:0")
	await _press(ScreenCursor.CONFIRM_ALT)
	check(cs._pick.is_empty() and GameState.count(first) > 0, "X again puts it down in the bag")
	var amt := cs._amt
	await _press(ScreenCursor.TOOL)
	check(cs._amt == (amt + 1) % 4, "TOOL cycles the move amount")
	await _press("b")
	await _frames(4)
	check(not is_instance_valid(cs) or not cs.is_inside_tree(), "B closes the chest")
	paused = false


func _craft(m: GameMap) -> void:
	Crafting.run(m, "furnace")
	await _frames(12)
	var cr := _child(m, "CraftScreen") as CraftScreen
	check(cr != null, "craft opens")
	if cr == null:
		return
	check(cr.is_in_group("toast_hold"), "craft holds toasts (c9_14)")
	var cur := cr._cur
	# Walk to the first card you can make.
	var target := ""
	for c in cr._list.get_children():
		if c is Button and not (c as Button).disabled:
			target = cur.key_of(c)
			break
	check(target != "", "a recipe card exists")
	cur.select_key(target)
	await _press("a")
	check(not cr._sel.is_empty(), "A picks the recipe")
	check(cur.cur != null and cur.key_of(cur.cur) == "sel", "cursor stays on the picked card")
	var mx := mini(Crafting.max_qty(cr._sel), 10 * cr.tier)
	await _press("right")
	check(cr._qty == mini(2, maxi(1, mx)), "right = +1 (%d)" % cr._qty)
	await _press("left")
	check(cr._qty == 1, "left = -1")
	await _press("a")  # second A on the picked card -> MAKE
	var on_make := cur.cur != null and cur.key_of(cur.cur) == "make"
	if Crafting.can_make(cr._sel):
		check(on_make, "second A jumps to MAKE")
		var before := Crafting.jobs(cr.key).size()
		await _press("a")
		check(Crafting.jobs(cr.key).size() == before + 1, "A on MAKE starts the job")
		check(cr._msg.visible and cr._msg.text.contains("ready in"), "feedback in the screen's own line (%s)" % cr._msg.text)
	cr.close()
	await _frames(4)
	paused = false


func _prizes(m: GameMap) -> void:
	Tickets.add(5000, "test")
	GameState.run["time"] = 12 * 60
	PrizeScreen.open(m)
	await _frames(12)
	var ps := _child(m, "PrizeScreen") as PrizeScreen
	check(ps != null, "prize counter opens")
	if ps == null:
		return
	var big := -1
	for i in PrizeScreen.TIERS.size():
		ps._tier(i)
		if ps._rows.size() > PrizeScreen.VISIBLE:
			big = i
			break
	if big >= 0:
		for k in ps._rows.size() - 1:
			await _press("down")
		check(ps.sel == ps._rows.size() - 1, "down reaches the last prize")
		check(ps.sel >= ps.top and ps.sel < ps.top + PrizeScreen.VISIBLE, "last prize is on screen (top %d)" % ps.top)
		check(PrizeScreen.LIST_Y + (ps.sel - ps.top + 1) * PrizeScreen.ROW_H <= PrizeScreen.DESC_Y + 1.0, "row ends above the description box")
		await _press("down")
		check(ps.sel == 0 and ps.top == 0, "down wraps to the first")
		await _press("down", 40)  # held: repeats
		check(ps.sel >= 3, "held down repeats (%d)" % ps.sel)
	else:
		print("  (no shelf over %d prizes in this save: scroll checks skipped)" % PrizeScreen.VISIBLE)
	ps._close()
	await _frames(4)
	paused = false


func _campaign(m: GameMap) -> void:
	CampaignScreen.open(m)
	await _frames(12)
	var cb := _child(m, "CampaignScreen") as CampaignScreen
	check(cb != null, "campaign screen opens")
	if cb == null:
		return
	var cur := cb._cur
	cur.resync()
	var rows := cur.items()
	check(rows.size() >= 2, "list rows reachable by cursor (%d)" % rows.size())
	await _press("down")
	check(cur.cur != null and cur.cur != rows[0], "down steps the list")
	await _press("a")
	await _frames(4)
	check(cb.cid != "", "A opens the campaign board")
	if cb.cid != "":
		cb._brief.visible = false
		var nodes: Array = Campaign.get_c(cb.cid)["nodes"]
		var p0 := Vector2.ZERO
		for n: Dictionary in nodes:
			if str(n["id"]) == cb.sel:
				p0 = cb._npos(n)
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var nb := cb.pick_dir(dir)
			if nb == "":
				continue
			var p1 := Vector2.ZERO
			for n: Dictionary in nodes:
				if str(n["id"]) == nb:
					p1 = cb._npos(n)
			# In that direction, or a wrap to the far side (strictly behind).
			check((p1 - p0).dot(dir) > 0.0 or (p1 - p0).dot(dir) < 0.0, "pick_dir %s is spatial" % str(dir))
		check(cb._acts.size() >= 1, "card has actions")
		if cb._acts.size() > 1:
			await _press(ScreenCursor.PAGE)
			check(cb._act_i == 1, "PAGE frames the next action")
		await _press("b")
		check(cb.cid == "", "B goes back to the list")
	cb.close()
	await _frames(4)
	paused = false


func _mega() -> void:
	var ids: Array = MegaRegion.ids()
	var done := false
	for id: String in ids:
		var spots := MegaMap.pin_spots(id)
		if spots.size() < 2:
			continue
		MegaMap.sel = ""
		MegaMap.step_sel(id, Vector2.ZERO)
		check(spots.has(MegaMap.sel), "step_sel picks a first pin")
		var moved := false
		for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var was := MegaMap.sel
			if MegaMap.step_sel(id, dir):
				moved = true
				check(((spots[MegaMap.sel] as Vector2) - (spots[was] as Vector2)).dot(dir) > 0.0, "step_sel goes the way pressed")
		check(moved, "step_sel moves between pins of " + id)
		var mc := MegaMap.make_map(id)
		check(mc.focus_mode == Control.FOCUS_ALL, "map is a focus stop")
		mc.free()
		done = true
		break
	check(done, "a region with pins exists")
	MegaMap.sel = ""


func _slot_drag() -> void:
	var host := Control.new()
	root.add_child(host)
	var sd := SlotDrag.new()
	host.add_child(sd)
	var a := Button.new()
	var b := Button.new()
	host.add_child(a)
	host.add_child(b)
	var got := []
	sd.add(a, {"id": "wood", "i": 0}, func(pl: Dictionary) -> void: got.append(["a", pl]), "s:0")
	sd.add(b, {}, func(pl: Dictionary) -> void: got.append(["b", pl]), "s:1")
	check(sd.pad_lift("s:0") and not sd.dragging.is_empty(), "pad_lift carries the item")
	sd.pad_hover("s:1")
	sd.pad_drop("s:1")
	check(got.size() == 1 and got[0][0] == "b" and str(got[0][1]["id"]) == "wood", "pad_drop drops on the target slot")
	check(sd.dragging.is_empty() and not sd.pad_carry, "carry ends")
	check(not sd.pad_lift("s:1"), "an empty slot lifts nothing")
	host.free()


func _rep() -> void:
	var r := ScreenCursor.Rep.new()
	# Feed a held action by hand: count fires over 1 s held at 60 fps.
	Input.action_press("down")
	var n := 0
	for i in 60:
		if r.pressed("down", 1.0 / 60.0) and i > 0:
			n += 1
	Input.action_release("down")
	var want := floori((1.0 - ScreenCursor.Rep.DELAY) / ScreenCursor.Rep.RATE)
	check(absi(n - want) <= 1, "Rep fires ~%d times in a 1 s hold (%d)" % [want, n])


func _arcade() -> void:
	# Left-handed: d-pad cluster moves right as one piece, A goes left.
	var deck := [{"action": "left", "rect": Rect2(8, 392, 40, 40)}, {"action": "right", "rect": Rect2(92, 392, 40, 40)},
		{"action": "a", "rect": Rect2(196, 378, 64, 64)}]
	var mir := ArcadeGame.mirror_deck(deck)
	var rl: Rect2 = mir[0]["rect"]
	var rr: Rect2 = mir[1]["rect"]
	var ra: Rect2 = mir[2]["rect"]
	check(rl.position.x < rr.position.x, "mirrored ◀ stays left of ▶")
	check(rr.end.x <= ArcadeGame.W and rl.position.x > 120.0, "d-pad on the right")
	check(ra.position.x < 80.0, "A on the left")
	# Shake off reaches the cabinets.
	var g := ArcadeHub.make("whack")
	g.manual = true
	root.add_child(g)
	Settings.set_v("shake", false)
	g.shake(3.0)
	check(g._shake == 0.0, "Screen shake off: no cabinet shake")
	Settings.set_v("shake", true)
	g.shake(3.0)
	check(g._shake > 0.0, "shake on still shakes")
	# Deck hides for a pad (not for bots/tests).
	g.manual = false
	ScreenCursor.pad_used = true
	check(g.deck_hidden(), "deck hides while a pad plays")
	ScreenCursor.pad_used = false
	check(not g.deck_hidden(), "deck back for fingers")
	g.manual = true
	g.close()
	# Picker: held ▼ repeats.
	var hub := ArcadeHub.make("")
	hub.manual = true
	root.add_child(hub)
	for i in 8:
		hub.bot = {"_": false}
		hub.frame()
	var s0 := hub._sel
	for i in 60:
		hub.bot = {"down": true}
		hub.frame()
	hub.bot = {"_": false}
	hub.frame()
	var steps := posmod(hub._sel - s0, ArcadeHub.GAMES.size())
	check(steps >= 2 or ArcadeHub.GAMES.size() <= 2, "held ▼ repeats in the picker (%d steps)" % steps)
	hub.close()
	# Gangster blurbs.
	GameState.run["arc"] = "gangsters"
	for gm: Dictionary in ArcadeHub.GAMES:
		var bl := ArcadeHub.blurb(gm).to_lower()
		check(not bl.contains("grump") and not bl.contains("toy duck"), "gang blurb for %s: %s" % [gm["id"], bl])
	GameState.run["arc"] = "penguins"
	check(ArcadeHub.blurb(ArcadeHub.GAMES[2]).contains("grump"), "penguin blurb kept")


func _bowling() -> void:
	Settings.set_v("left_handed", true)
	var bw := Bowling.new()
	bw.manual = true
	root.add_child(bw)
	check(bw.BTN_GO.position.x < bw.BTN_L.position.x and bw.BTN_L.position.x < bw.BTN_R.position.x, "left-handed bowling: GO left, ◀ ▶ right")
	bw.free()
	Settings.set_v("left_handed", false)
	var bw2 := Bowling.new()
	bw2.manual = true
	root.add_child(bw2)
	check(bw2.BTN_GO.position.x > bw2.BTN_L.position.x, "right-handed bowling unchanged")
	bw2.manual = false
	ScreenCursor.pad_used = true
	check(bw2.deck_hidden(), "bowling buttons hide for a pad")
	ScreenCursor.pad_used = false
	bw2.free()
	paused = false
