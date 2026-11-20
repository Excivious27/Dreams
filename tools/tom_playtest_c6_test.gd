extends SceneTree
## Tom's C6 phone playtest (22:37), one block per item (P7):
##  1 early pace: rocks/trees take more swings at the start (toughness),
##    energy a little dearer at level 1, no bonus crop at level 1
##  2 watering can: holds WaterCan.cap() pours, empty says so, USE on water fills
##  3 the held item's name under the toolbar fades (it used to stay for good)
##  4 the pup menu says "Gear…" until the pup wears a pack
##  5 drag and drop: bag -> bag, bag -> toolbar, toolbar -> bag, -> trash,
##    bag <-> chest (SlotDrag long press, driven through test_pos/test_down)
##  6 Organise (Stardew order), trash asks only for valuable stacks
##   godot --headless --path . --fixed-fps 60 -s res://tools/tom_playtest_c6_test.gd [-- -v]
var fails := 0
var verbose := false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)
	elif verbose:
		print("  ok   ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	verbose = OS.get_cmdline_user_args().has("-v")
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(sec: float) -> void:
	var gt := 0.0
	while gt < sec:
		await process_frame
		gt += root.get_process_delta_time()


func toasts(m: GameMap) -> Array:
	var out: Array = []
	for c in m.hud._toasts.get_children():
		if c is Label and c.has_meta("base") and not c.is_queued_for_deletion():
			out.append(str(c.get_meta("base")))
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kai", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 8 * 60
	_pace()
	GameMap.next_spawn = Vector2.ZERO
	var farm: GameMap = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	current_scene = farm
	await frames(20)
	await _can(farm)
	await _held_name(farm)
	await _pup(farm)
	await _drag(farm)
	await _chest(farm)
	_organise()
	print("tom_playtest_c6_test: %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


## 1. Hits by tool tier (printed) and the early energy/crop changes.
func _pace() -> void:
	print("-- 1 early pace (hits: rock hp2 / log hp2 / tree hp4 / farm tree hp5)")
	var tiers := GameState.run.get("tool_tier", {}) as Dictionary
	GameState.run["tool_tier"] = tiers
	for t in 5:
		tiers["axe"] = t
		tiers["pickaxe"] = t
		var line := "   tier %d: rock %d, log %d, tree %d, farm tree %d" % [t, GameState.hits_for(2, "pickaxe"), GameState.hits_for(2, "axe"), GameState.hits_for(4, "axe"), GameState.hits_for(5, "axe")]
		print(line)
	tiers["axe"] = 0
	tiers["pickaxe"] = 0
	check(GameState.hits_for(2, "pickaxe") >= 3, "starter pickaxe needs 3+ swings on a rock (was 2)")
	check(GameState.hits_for(4, "axe") >= 7, "starter axe needs 7+ swings on a tree (was 4)")
	check(GameState.hits_for(2, "axe") >= 4, "starter axe needs 4 swings on a stump (was 2)")
	tiers["pickaxe"] = 2
	check(GameState.hits_for(2, "pickaxe") < 3, "a better pickaxe brings rocks back down")
	tiers["pickaxe"] = 0
	GameState.run["skills"]["mining"] = {"level": 8, "xp": 0}
	check(GameState.toughness("pickaxe") < 1.4, "mining skill brings toughness down")
	GameState.run["skills"]["mining"] = {"level": 1, "xp": 0}
	var th := {"type": "rock", "hp": 2}
	GameState.toughen(th, "pickaxe")
	var h1 := int(th["hp"])
	GameState.toughen(th, "pickaxe")
	check(h1 == 3 and int(th["hp"]) == 3, "a rock toughens once (2 -> 3 hp), not every swing")
	var e1 := GameState.energy_cost_f("axe")
	GameState.run["skills"]["foraging"] = {"level": 5, "xp": 0}
	var e5 := GameState.energy_cost_f("axe")
	GameState.run["skills"]["foraging"] = {"level": 1, "xp": 0}
	check(e1 >= 1.1 and e5 < e1, "energy a bit dearer at level 1 (axe %.2f at L1, %.2f at L5)" % [e1, e5])


## 2. Watering can.
func _can(farm: GameMap) -> void:
	print("-- 2 watering can")
	check(not GameState.run.has("can_water") or WaterCan.level() == WaterCan.cap(), "new game: full can")
	GameState.run.erase("can_water")
	check(WaterCan.level() == WaterCan.cap() and WaterCan.cap() >= 20, "old save without the field starts full (%d)" % WaterCan.cap())
	GameState.select_slot((GameState.run["toolbar"] as Array).find("can"))
	var key := "30,20"
	GameState.run["farm"][key] = {"crop": "", "days": 0, "watered": false}
	GameState.run["can_water"] = 1
	farm.call("_water", GameState.run["farm"][key], key)
	check(bool(GameState.run["farm"][key]["watered"]) and WaterCan.level() == 0, "a pour spends one")
	GameState.run["farm"][key]["watered"] = false
	for c in farm.hud._toasts.get_children():
		c.queue_free()
	await frames(1)
	farm.call("_water", GameState.run["farm"][key], key)
	await frames(1)
	check(not bool(GameState.run["farm"][key]["watered"]), "an empty can doesn't water")
	check(toasts(farm).has(WaterCan.EMPTY), "empty can says '%s' (%s)" % [WaterCan.EMPTY, str(toasts(farm))])
	var wc := Vector2i(-1, -1)
	for c: Vector2i in farm.things.keys():
		if str(farm.things[c].get("type", "")) == "water":
			wc = c
			break
	check(wc != Vector2i(-1, -1), "the farm has water to fill from")
	if wc != Vector2i(-1, -1):
		farm.player._busy = false
		check(farm.try_interact(wc, false), "USE with the can on water is handled")
		await frames(2)
		check(WaterCan.level() == WaterCan.cap(), "USE on water fills the can")
		check(toasts(farm).any(func(t: String) -> bool: return t.begins_with("Can filled")), "a fill toast shows")
	GameState.run["farm"].erase(key)


## 3. "Turnip Seeds" no longer stays under the toolbar.
func _held_name(farm: GameMap) -> void:
	print("-- 3 held item name fades")
	var tb: Array = GameState.run["toolbar"]
	var s := tb.find("turnip_seed")
	GameState.select_slot(s if s >= 0 else 0)
	await frames(3)
	check(farm.hud.held_age < 1.0, "picking a slot shows its name")
	await wait(Hud.HELD_SHOW + 1.0)
	check(farm.hud.held_age >= Hud.HELD_SHOW + 0.5, "after %.1f s the name is gone (age %.1f)" % [Hud.HELD_SHOW + 0.5, farm.hud.held_age])
	await wait(Hud.TOAST_MAX * Settings.toast_hold() + 1.0)  # long tips stay up longer since C9 (Messages stay up)
	for c in farm.hud._toasts.get_children():
		check((c as CanvasItem).modulate.a < 0.05 or c.is_queued_for_deletion(), "no toast stays up: " + str(c.get_meta("base", "")))


## 4. The pup menu's "pack" waits for a pack.
func _pup(farm: GameMap) -> void:
	print("-- 4 pup menu")
	var st := Pet.state()
	st["gear"]["pack"] = ""
	check(Pet.pack_size() == 0, "no pack: pack size 0")
	var opts := await _pup_opts(farm)
	check(opts.has("Gear…") and not opts.any(func(o: String) -> bool: return o.to_lower().contains("pack")), "no pack: menu says Gear… (%s)" % str(opts))
	st["gear"]["pack"] = "pup_pack_small"
	opts = await _pup_opts(farm)
	check(opts.has("Gear and pack…"), "with a pack: Gear and pack… (%s)" % str(opts))
	st["gear"]["pack"] = ""


func _pup_opts(farm: GameMap) -> Array:
	farm.call("_pup_menu")
	var d := Dialogue.instance(self)
	var gt := 0.0
	while not d._in_choice and gt < 4.0:
		if d._typing:
			d._shown = 9999.0
		await process_frame
		gt += root.get_process_delta_time()
	var out: Array = []
	for b in d._choices.get_children():
		if b is Button:
			out.append(str((b as Button).text).strip_edges())
	d.last_choice = -1
	d._close()
	await frames(10)
	return out


func _drag_to(dr: SlotDrag, from: Control, to: Control) -> void:
	if from == null or to == null:
		check(false, "drag: slot missing (from %s, to %s)" % [from, to])
		return
	var to_tag := ""
	for t: Dictionary in dr._targets:
		if t["ctrl"] == to:
			to_tag = str(t["tag"])
	if verbose:
		print("    drag ", from.get_global_rect(), " -> ", to.get_global_rect())
	dr.test_pos = from.get_global_rect().get_center()
	dr.test_down = true
	var pl: Dictionary = {}
	for t: Dictionary in dr._targets:
		if t["ctrl"] == from:
			pl = t["payload"]
	dr.begin(pl)
	await wait(SlotDrag.LONG + 0.15)
	# The lift refreshes the screen: find the target again by its rect centre.
	var to2: Control = dr.find(to_tag)  # the lift may rebuild the screen
	dr.test_pos = to2.get_global_rect().get_center() if to2 else Vector2.ZERO
	await frames(2)
	dr.test_down = false
	await frames(3)
	dr.test_pos = Vector2.INF


## 5. Items tab drag and drop.
func _drag(farm: GameMap) -> void:
	print("-- 5 drag and drop (Items tab)")
	var gm: GameMenu = null
	for ch in farm.get_children():
		if ch is GameMenu:
			gm = ch
	check(gm != null, "the farm has a menu")
	if gm == null:
		return
	GameState.add_item("wood", 12)
	GameState.add_item("stone", 7)
	GameState.add_item("fiber", 3)
	gm._tab = "Items"
	gm.toggle()
	await frames(4)
	var dr: SlotDrag = gm._drag
	check(dr != null and dr.find("bag:0") != null and dr.find("trash") != null, "Items tab registers bag slots and the trash can")
	if dr == null:
		return
	var bs := GameState.bag_slots()
	var wi := bs.find("wood")
	var last := bs.size() - 1
	var tgt_tag := "bag:%d" % last
	if str(bs[last]) != "":
		tgt_tag = "bag:%d" % bs.find("")
	var tgt_i := int(tgt_tag.split(":")[1])
	await _drag_to(dr, dr.find("bag:%d" % wi), dr.find(tgt_tag))
	check(str(GameState.bag_slots()[tgt_i]) == "wood", "bag -> empty bag slot moves the stack (%s)" % str(GameState.bag_slots()))
	dr = gm._drag
	await _drag_to(dr, dr.find(tgt_tag), dr.find("bar:9"))
	check(str(GameState.run["toolbar"][9]) == "wood", "bag -> toolbar slot puts it on the bar")
	dr = gm._drag
	await _drag_to(dr, dr.find("bar:9"), dr.find("bar:10"))
	check(str(GameState.run["toolbar"][10]) == "wood" and str(GameState.run["toolbar"][9]) != "wood", "toolbar -> toolbar moves it along (swaps) %s" % str(GameState.run["toolbar"]))
	dr = gm._drag
	await _drag_to(dr, dr.find("bar:10"), dr.find("bag:%d" % GameState.bag_slots().find("stone")))
	check(not (GameState.run["toolbar"] as Array).has("wood") and GameState.count("wood") == 12, "toolbar -> bag takes it off the bar (wood kept)")
	dr = gm._drag
	var fi := GameState.bag_slots().find("fiber")
	await _drag_to(dr, dr.find("bag:%d" % fi), dr.find("trash"))
	check(GameState.count("fiber") == 0, "cheap stack -> trash goes at once")
	GameState.add_item("ruby", 3)
	gm._refresh()
	await frames(2)
	dr = gm._drag
	var ri := GameState.bag_slots().find("ruby")
	if ri >= 0 and GameState.trash_needs_confirm("ruby"):
		await _drag_to(dr, dr.find("bag:%d" % ri), dr.find("trash"))
		check(GameState.count("ruby") == 3 and gm._trash_arm == "ruby", "valuable stack -> trash asks first")
		gm._drag._swallow_until = 0
		(gm._drag.find("trash") as Button).pressed.emit()
		await frames(2)
		check(GameState.count("ruby") == 0, "second tap on the trash confirms")
	# A tap after a drop is swallowed, a plain tap still works.
	gm.toggle()
	await frames(4)


## 5b. Chest drag and drop + trash.
func _chest(farm: GameMap) -> void:
	print("-- 5b chest")
	GameState.add_item("stone", 5)
	ChestScreen.open(farm, "chest", "Chest")
	await frames(6)
	var cs: ChestScreen = null
	for ch in farm.get_children():
		if ch is ChestScreen:
			cs = ch
	if cs == null:
		for ch in root.get_children():
			if ch is ChestScreen:
				cs = ch
	check(cs != null, "the chest opens")
	if cs == null:
		return
	var dr: SlotDrag = cs._drag
	var si := GameState.bag_slots().find("stone")
	var before := Storage.amount("chest", "stone")
	await _drag_to(dr, dr.find("b:%d" % si), dr.find("c:%d" % Storage.slots("chest").find("")))
	check(Storage.amount("chest", "stone") > before and GameState.count("stone") == 0, "bag -> chest slot moves the stack")
	dr = cs._drag
	var ci := Storage.slots("chest").find("stone")
	var bf := GameState.bag_slots().find("")
	await _drag_to(dr, dr.find("c:%d" % ci), dr.find("b:%d" % bf))
	check(GameState.count("stone") > 0, "chest -> bag slot takes it back")
	dr = cs._drag
	GameState.add_item("fiber", 4)
	cs._refresh()
	await frames(2)
	dr = cs._drag
	await _drag_to(dr, dr.find("b:%d" % GameState.bag_slots().find("fiber")), dr.find("trash"))
	check(GameState.count("fiber") == 0, "bag -> chest screen trash can")
	cs.close()
	await frames(4)


## 6. Organise order.
func _organise() -> void:
	print("-- 6 organise")
	GameState.add_item("turnip", 2)
	GameState.add_item("parsnip_seed", 2)
	GameState.add_item("copper", 2)
	var tb_before: Array = (GameState.run["toolbar"] as Array).duplicate()
	GameState.sort_bag()
	var bs: Array = GameState.bag_slots().filter(func(x: Variant) -> bool: return str(x) != "")
	var rank := bs.map(func(x: Variant) -> int: return int(GameState.SORT_RANK.get(str(GameState.items.get(str(x), {}).get("type", "")), 18)))
	var sorted_ok := true
	for i in range(1, rank.size()):
		if int(rank[i]) < int(rank[i - 1]):
			sorted_ok = false
	check(sorted_ok, "bag sorted by Stardew category (%s)" % str(bs))
	check(GameState.run["toolbar"] == tb_before, "toolbar row stays put when sorting")
	check(not GameState.trash_needs_confirm("wood"), "a stack of wood trashes without asking")
