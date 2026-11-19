extends SceneTree
## Full-screen UI touch input, played with REAL touch events (Input.parse_input_event,
## so TouchControls, Hud, GameMap and the screen all see them, plus the mouse copy
## Godot emulates from finger 0), inside the Rec Center:
##  - every arcade cabinet and the picker: insert coin with the deck A, leave with
##    the deck B, nothing held afterwards, the picker survives a cabinet closing;
##  - the USE finger that opened a cabinet and a thumb left on the stick lift
##    cleanly (no action stuck on, first A tap counts);
##  - two fingers on the deck (hold ◀, tap A), edge/corner/top-bar taps;
##  - prize counter: one tap on a prize picks it (never buys), one tap on BUY buys one;
##  - bowling: one tap on spin moves it one step, the quit X needs two taps;
##  - hack terminal: one arrow tap counts once, UNPLUG leaves;
##  - chest and craft screens opened in the rec: toolbar taps under them do nothing, ✕ closes;
##  - after each screen: tree unpaused, Hud.modal_rect/extra_rects empty, no action
##    pressed, TouchControls holds nothing, the player never moved.
##   godot --headless --path . -s res://tools/touch_ui_test.gd
var fails := 0
var m: GameMap
var tc: TouchControls
var p0 := Vector2.ZERO


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


## A finger event at a viewport point (converted to window space like a real phone).
func _touch(idx: int, p: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.position = root.get_final_transform() * p
	t.pressed = down
	Input.parse_input_event(t)
	await process_frame
	await process_frame


func _tap(p: Vector2, idx := 0, hold := 0.08) -> void:
	await _touch(idx, p, true)
	await _wait(hold)
	await _touch(idx, p, false)
	await _wait(0.08)


func _child(cls: String) -> Node:
	for c in m.get_children():
		if c.get_script() and (c.get_script() as Script).get_global_name() == cls and not c.is_queued_for_deletion():
			return c
	return null


func _gone(n: Variant) -> bool:
	return not is_instance_valid(n) or not (n as Node).is_inside_tree() or (n as Node).is_queued_for_deletion()


func _any_action() -> String:
	for a in ["up", "down", "left", "right", "a", "b", "action", "menu"]:
		if Input.is_action_pressed(a):
			return a
	return ""


## Everything a closed screen must leave behind.
func _clean(what: String) -> void:
	await _wait(0.1)
	ok(not paused, what + ": game unpaused")
	ok(not Hud.modal_rect.has_area(), what + ": Hud.modal_rect cleared")
	ok(Hud.extra_rects.is_empty(), what + ": Hud.extra_rects cleared (%d left)" % Hud.extra_rects.size())
	ok(_any_action() == "", what + ": no action left pressed (%s)" % _any_action())
	ok(tc._held.is_empty(), what + ": touch pad holds nothing (%s)" % str(tc._held.keys()))
	ok(m.player.position.distance_to(p0) < 0.6, what + ": player never moved (%s -> %s)" % [p0, m.player.position])
	m.player.position = p0


func _deck_center(g: ArcadeGame, action: String) -> Vector2:
	for b: Dictionary in g._deck:
		if str(b["action"]) == action:
			return (b["rect"] as Rect2).get_center()
	return Vector2(-1, -1)


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "interior_seen", "store_first", "rec_visited"]:
		GameState.run["flags"][f] = true
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["day"] = 10
	GameState.run["time"] = 12 * 60
	GameState.run["crystals"] = 5000
	GameState.run["builds"] = {"workbench": 2}
	for id in ["wood", "stone", "fiber", "copper", "coal"]:
		GameState.add_item(id, 20)
	GameMap.next_interior = "rec"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	for i in 30:
		await process_frame
	m = current_scene as GameMap
	ok(m != null, "rec interior loads")
	if m == null:
		_end()
		return
	for c in m.get_children():
		if c is TouchControls:
			tc = c
	TouchControls.visible_controls = true
	await _clear_dialogue()
	await _wait(0.5)
	m.player.frozen = false
	p0 = m.player.position
	await _arcade()
	await _picker()
	await _prizes()
	await _bowling()
	await _hack()
	await _chest_craft()
	_end()


func _end() -> void:
	print("touch_ui_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


# --- arcade ------------------------------------------------------------------

func _arcade() -> void:
	# The USE press that opens a cabinet is still down when it appears, and a
	# thumb is on the stick: both lift inside the cabinet.
	var use_at: Vector2 = Settings.button_at(TouchControls.BUTTONS["a"]["pos"], float(TouchControls.BUTTONS["a"]["r"]))[0]
	await _touch(1, Vector2(58, 420), true)          # thumb on the stick...
	var sd := InputEventScreenDrag.new()
	sd.index = 1
	sd.position = root.get_final_transform() * Vector2(30, 420)
	Input.parse_input_event(sd)
	await _wait(0.05)
	ok(Input.is_action_pressed("left"), "stick pushed left presses left")
	m.player.frozen = true  # USE must not talk to whoever stands in front of the spawn
	await _touch(0, use_at, true)
	ok(Input.is_action_pressed("a"), "USE button presses a")
	var g := ArcadeHub.open(m, "stack")
	await _wait(0.15)
	ok(not Input.is_action_pressed("left"), "opening a cabinet lets go of the stick")
	await _touch(0, use_at, false)                   # both lift inside the cabinet
	await _touch(1, Vector2(30, 420), false)
	ok(not Input.is_action_pressed("a"), "the USE finger lifting inside a cabinet releases a")
	ok(tc._held.is_empty() and not tc._stick_active, "touch pad holds nothing after a cabinet opens")
	m.player.frozen = false
	p0 = m.player.position  # the stick walked a step before the cabinet opened
	var c0 := ArcadeHub.money()
	await _tap(_deck_center(g, "a"))
	await _wait(0.1)
	ok(g.state == "play", "first A tap on the deck inserts the coin (state %s)" % g.state)
	ok(ArcadeHub.money() == c0 - g.fee, "one coin charged")
	# Two fingers: hold ◀ and tap A, lift in either order.
	await _touch(0, _deck_center(g, "left"), true)
	await _wait(0.1)
	ok(g.held("left"), "◀ held with finger 0")
	await _tap(_deck_center(g, "a"), 1)
	ok(g.held("left"), "◀ still held while finger 1 taps A")
	await _touch(0, _deck_center(g, "left"), false)
	await _wait(0.1)
	ok(not g.held("left") and not Input.is_action_pressed("left"), "◀ lets go")
	# Slide a thumb from ◀ to ▶.
	await _touch(0, _deck_center(g, "left"), true)
	var dr := InputEventScreenDrag.new()
	dr.index = 0
	dr.position = root.get_final_transform() * _deck_center(g, "right")
	Input.parse_input_event(dr)
	await _wait(0.1)
	ok(Input.is_action_pressed("right") and not Input.is_action_pressed("left"), "sliding ◀ to ▶ follows the thumb")
	await _touch(0, _deck_center(g, "right"), false)
	ok(not Input.is_action_pressed("right"), "▶ lets go after the slide")
	# Edge, corner and top-bar taps: nothing breaks, nothing reaches the map.
	for p: Vector2 in [Vector2(0, 0), Vector2(269, 479), Vector2(0, 479), Vector2(269, 0), Vector2(135, 10), Vector2(135, 360), Vector2(268, 240)]:
		await _tap(p)
	ok(is_instance_valid(g) and g.is_inside_tree() and g.state == "play", "edge taps leave the cabinet running")
	ok(_any_action() == "", "edge taps press nothing (%s)" % _any_action())
	await _leave(g, "stack")
	await _clean("stack")
	# Every cabinet: coin in with A, out with B.
	for id: String in ArcadeHub.game_ids():
		var gg := ArcadeHub.open(m, id)
		await _wait(0.15)
		var money := ArcadeHub.money()
		await _tap(_deck_center(gg, "a"))
		await _wait(0.1)
		ok(gg.state == "play", "%s: A tap starts a round (state %s)" % [id, gg.state])
		ok(ArcadeHub.money() < money, "%s: the coin was charged" % id)
		await _leave(gg, id)
		await _clean(id)


## B until the cabinet closes (a round first ends on B, then B leaves).
func _leave(g: ArcadeGame, id: String) -> void:
	var b := _deck_center(g, "b")
	for i in 12:
		if _gone(g):
			break
		if g.state == "play" and id == "claw":
			# The claw has no quit mid-go: drop it and let it play out.
			await _tap(_deck_center(g, "a"))
			await _wait(1.0)
			continue
		await _tap(b)
		await _wait(0.7)  # the results card ignores B for a moment
	ok(_gone(g), "%s: B on the deck leaves" % id)


func _picker() -> void:
	var hub := ArcadeHub.open(m, "") as ArcadeHub
	await _wait(0.15)
	await _tap(hub._card(2).get_center())
	ok(hub._sel == 2, "picker: a tap picks a card")
	ok(hub._child == null, "picker: one tap only picks (no launch)")
	await _tap(hub._card(2).get_center())
	await _wait(0.1)
	var child := hub._child
	ok(child != null and child.game_id == "whack", "picker: tapping the picked card launches it")
	if child:
		await _tap(_deck_center(child, "b"))
		await _wait(0.2)
		ok(_gone(child), "picker: B on the title card closes the cabinet")
		ok(not _gone(hub) and hub.visible, "picker: back on the picker")
		ok(Hud.modal_rect.has_area(), "picker: still modal after the cabinet closes")
		ok(paused, "picker: still paused after the cabinet closes")
		ok(Hud.extra_rects.size() == hub._deck.size(), "picker: its deck rects survive (%d/%d)" % [Hud.extra_rects.size(), hub._deck.size()])
		await _wait(0.2)
	await _tap(_deck_center(hub, "b"))
	await _wait(0.2)
	ok(_gone(hub), "picker: B leaves")
	await _clean("picker")


# --- prize counter -------------------------------------------------------------

func _prizes() -> void:
	Tickets.add(5000, "test")
	PrizeScreen.open(m)
	await _wait(0.3)
	var ps := _child("PrizeScreen") as PrizeScreen
	ok(ps != null, "prize counter opens")
	if ps == null:
		return
	var t0 := Tickets.count()
	await _tap(Vector2(130, PrizeScreen.LIST_Y + PrizeScreen.ROW_H * 1 + 12))
	ok(ps.sel == 1, "prizes: one tap picks row 2 (sel %d)" % ps.sel)
	ok(ps.bought == 0 and Tickets.count() == t0, "prizes: picking a prize never buys it")
	await _tap(PrizeScreen.BTN_BUY.get_center())
	ok(ps.bought == 1, "prizes: one tap on BUY buys exactly one (%d)" % ps.bought)
	await _tap(Vector2(PrizeScreen.BTN_CLOSE.get_center()))
	ok(_gone(ps), "prizes: LEAVE closes")
	await _clean("prizes")


# --- bowling -------------------------------------------------------------------

func _bowling() -> void:
	var bw := Bowling.new()
	bw.lane = 1
	m.add_child(bw)
	await _wait(0.3)
	var s0 := bw.spin_step
	await _tap(Bowling.BTN_SPIN_R.get_center())
	ok(bw.spin_step == mini(3, s0 + 1), "bowling: one spin tap = one step (%d -> %d)" % [s0, bw.spin_step])
	await _tap(Bowling.BTN_QUIT.get_center())
	ok(not _gone(bw), "bowling: one tap on X only asks")
	await _tap(Bowling.BTN_QUIT.get_center())
	await _wait(0.1)
	ok(_gone(bw), "bowling: a second tap on X leaves")
	await _clean("bowling")


# --- hack terminal ----------------------------------------------------------------

func _hack() -> void:
	HackGame.play(m, 1)
	await _wait(0.2)
	var hg := _child("HackGame") as HackGame
	ok(hg != null, "hack terminal opens")
	if hg == null:
		return
	for i in 60:
		if not hg._showing:
			break
		await _wait(0.1)
	var d := str(hg._seq[0])
	await _tap(HackGame.POS[d])
	ok(hg._at == 1, "hack: one arrow tap counts once (%d)" % hg._at)
	await _tap(HackGame.BTN_UNPLUG.get_center())
	await _wait(0.1)
	ok(_gone(hg), "hack: UNPLUG leaves")
	await _clean("hack")


# --- chest / craft in the rec ----------------------------------------------------

func _x_button(n: Node) -> Button:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).text == "✕" and (c as Button).is_visible_in_tree():
			return c
	return null


func _chest_craft() -> void:
	GameState.select_slot(0)
	var tool_y := Hud.y_offset + Hud.TOOLBAR_Y + 8.0
	ChestScreen.open(m, "chest", "Chest")
	await _wait(0.3)
	var cs := _child("ChestScreen")
	ok(cs != null, "chest opens in the rec")
	if cs:
		await _tap(Vector2(Hud.TOOLBAR_X + Hud.SLOT * 5 + 8, tool_y))
		ok(int(GameState.run["slot"]) == 0, "chest: a tap where the toolbar sits doesn't pick a slot")
		var x := _x_button(cs)
		ok(x != null, "chest: has a ✕")
		if x:
			await _tap(x.get_global_rect().get_center())
		await _wait(0.1)
		ok(_gone(cs), "chest: ✕ closes")
	await _clean("chest")
	Crafting.run(m, "workbench")
	await _wait(0.4)
	var cr := _child("CraftScreen")
	ok(cr != null, "craft screen opens in the rec")
	if cr:
		await _tap(Vector2(Hud.TOOLBAR_X + Hud.SLOT * 5 + 8, tool_y))
		ok(int(GameState.run["slot"]) == 0, "craft: a tap where the toolbar sits doesn't pick a slot")
		var x2 := _x_button(cr)
		ok(x2 != null, "craft: has a ✕")
		if x2:
			await _tap(x2.get_global_rect().get_center())
		await _wait(0.1)
		ok(_gone(cr), "craft: ✕ closes")
	await _clear_dialogue()  # Crafting.run may say a line after closing
	await _clean("craft")


func _clear_dialogue() -> void:
	var dl := Dialogue.instance(self)
	for k in 40:
		if not dl.active:
			break
		if dl._in_choice:
			dl._choose("", dl._choices.get_child_count() - 1)
		else:
			dl._advance()
		await _wait(0.05)
