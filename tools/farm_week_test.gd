extends SceneTree
## The first farming week, both arcs, played through the farm scene's own
## interact path (the same calls a USE tap makes): till with the hoe, plant the
## starter seeds, water with the can, sleep, read the growth text, harvest,
## sell at the box, get paid. Prints every toast so the texts can be read.
##   godot --headless --path . -s res://tools/farm_week_test.gd
var fails := 0
var verbose := false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	verbose = OS.get_cmdline_user_args().has("-v")
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func toasts(farm: GameMap) -> Array:
	var out: Array = []
	for c in farm.hud._toasts.get_children():
		if c is Label and c.has_meta("base") and not c.is_queued_for_deletion():
			out.append(str(c.get_meta("base")))
	return out


func clear_toasts(farm: GameMap) -> void:
	for c in farm.hud._toasts.get_children():
		c.queue_free()


func slot_of(id: String) -> int:
	return (GameState.run["toolbar"] as Array).find(id)


## USE on cell c holding toolbar item `id`; returns the toasts it raised.
func use(farm: GameMap, c: Vector2i, id: String) -> Array:
	clear_toasts(farm)
	await frames(1)
	var s := slot_of(id)
	if s >= 0:
		GameState.select_slot(s)
	farm.player.position = farm.cell_center(c + Vector2i(0, 1))
	farm.player.facing = "up"
	farm.player._busy = false
	farm.try_interact(c, false)
	await frames(2)
	var t := toasts(farm)
	if verbose:
		print("    [%s @%s] %s" % [id, str(c), " | ".join(t)])
	return t


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		await _week(arc)
	print("farm_week_test: %s (%d fails)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


func _week(arc: String) -> void:
	print("-- ", arc)
	GameState.new_run(arc, "kairi", "Kai", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["time"] = 8 * 60
	GameMap.next_spawn = Vector2.ZERO
	var farm: GameMap = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	current_scene = farm
	await frames(20)
	var dl := Dialogue.instance(self)
	# A row of three open cells with a free cell under each to stand on.
	var row: Array = []
	for y in range(12, 24):
		for x in range(8, 30):
			var ok := true
			for dx in 3:
				var c := Vector2i(x + dx, y)
				if not farm.can_till(c) or farm.blocked.has(c + Vector2i(0, 1)) or farm.things.has(c + Vector2i(0, 1)):
					ok = false
			if ok:
				row = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y)]
				break
		if not row.is_empty():
			break
	check(not row.is_empty(), "found open ground to farm")
	if row.is_empty():
		farm.queue_free()
		return
	check(slot_of("turnip_seed") >= 0, "starter turnip seeds are on the toolbar")
	check(GameState._first_crop_step().contains("hoe"), "goal line starts with the hoe (%s)" % GameState._first_crop_step())
	# Hoe on grass tills; hoe on tilled soil says something useful.
	for c: Vector2i in row:
		await use(farm, c, "hoe")
	for c: Vector2i in row:
		check(GameState.run["farm"].has("%d,%d" % [c.x, c.y]), "tilled %s" % str(c))
	var t := await use(farm, row[0], "hoe")
	check(not t.has("Hold the watering can."), "hoe on fresh soil doesn't nag about the can (%s)" % str(t))
	# Water on empty soil (dry day) or a rain line (wet day).
	check(GameState._first_crop_step().contains("Seed"), "goal line moves on to seeds (%s)" % GameState._first_crop_step())
	# Plant.
	for c: Vector2i in row:
		await use(farm, c, "turnip_seed")
	for c: Vector2i in row:
		check(str(GameState.run["farm"]["%d,%d" % [c.x, c.y]].get("crop", "")) == "turnip", "planted %s" % str(c))
	var wet := GameState.sky_waters()
	print("  day 1 weather: %s" % GameState.weather_today())
	if arc == "gangsters":
		check(wet, "gangster day 1 is the rainy night")
	# Water two of three (leave one dry to see the morning report).
	t = await use(farm, row[0], "can")
	if wet:
		check(t.any(func(s: String) -> bool: return s.contains("sky") or s.contains("rain")), "can in the rain says the sky waters (%s)" % str(t))
	else:
		check(bool(GameState.run["farm"]["%d,%d" % [row[0].x, row[0].y]]["watered"]), "watered")
	await use(farm, row[1], "can")
	t = await use(farm, row[1], "can")
	check(t.any(func(s: String) -> bool: return s.contains("more day")), "a second can pour shows the growth text (%s)" % str(t))
	# A dry crop tapped with the hoe says it's thirsty and how long it has left.
	if not wet:
		t = await use(farm, row[2], "hoe")
		check(t.any(func(x: String) -> bool: return x.contains("Thirsty")), "a dry crop says it's thirsty (%s)" % str(t))
	# Sleep through the week, watering the first two each morning.
	var report := {}
	for day in 7:
		report = GameState.sleep()
		if verbose:
			print("  morning day %d (%s): grown %d dry %d ripe %d" % [int(GameState.run["day"]), GameState.weather_today(), int(report.get("grown", 0)), int(report.get("dry", 0)), int(report.get("ripe", 0))])
		var ripe := false
		for c: Vector2i in row:
			var tile: Dictionary = GameState.run["farm"]["%d,%d" % [c.x, c.y]]
			if str(tile.get("crop", "")) != "" and int(tile["days"]) >= 3:
				ripe = true
		if ripe:
			break
		for c: Vector2i in [row[0], row[1]]:
			await use(farm, c, "can")
	check(int(report.get("dry", 0)) >= 1, "the morning report counts the unwatered crop (%s)" % str(report))
	var t0: Dictionary = GameState.run["farm"]["%d,%d" % [row[0].x, row[0].y]]
	check(int(t0["days"]) >= 3, "watered turnip ripens in the first week")
	check(GameState._first_crop_step().contains("ripe"), "goal line says ripe (%s)" % GameState._first_crop_step())
	check(int(report.get("ripe", 0)) >= 1, "the morning report counts ripe crops (%s)" % str(report))
	# Harvest with the hoe still in hand (Stardew: any tool picks a ripe crop).
	var before := GameState.count("turnip")
	t = await use(farm, row[0], "hoe")
	await frames(30)  # the crop hops to you
	check(GameState.count("turnip") > before, "harvested a turnip (%d -> %d)" % [before, GameState.count("turnip")])
	check(GameState.quest_done("first_harvest"), "first harvest quest done")
	await use(farm, row[1], "can")
	await frames(30)
	# Sell box.
	var sb: Vector2i = farm.SELLBOX
	var n := GameState.count("turnip")
	var s := slot_of("turnip")
	check(s >= 0, "turnips land on the toolbar")
	clear_toasts(farm)
	GameState.select_slot(s)
	farm.interact(sb, farm.things.get(sb, {}))
	# C8 P2: a stack asks how many: pick "All".
	var sd := Dialogue.instance(farm.get_tree())
	for i in 120:
		if sd.active and sd._in_choice:
			sd._choose("", 0)
			break
		await frames(1)
	await frames(2)
	t = toasts(farm)
	if verbose:
		print("    [sell] ", " | ".join(t))
	check(int(GameState.run["sellbox"].get("turnip", 0)) == n and GameState.count("turnip") == 0, "turnips went in the box")
	check(t.any(func(x: String) -> bool: return x.contains("◆")), "sell toast gives the price (%s)" % str(t))
	var cr := int(GameState.run["crystals"])
	report = GameState.sleep()
	check(int(GameState.run["crystals"]) > cr, "paid overnight (%d -> %d)" % [cr, int(GameState.run["crystals"])])
	check(int(report["earned"]) > 0, "report has earnings")
	# Selling with nothing in hand reads the box; with a tool in hand too.
	while dl.active:
		dl.finish_now() if dl.has_method("finish_now") else dl.hide()
		await frames(1)
	farm.queue_free()
	await frames(5)
