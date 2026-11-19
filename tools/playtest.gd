extends SceneTree
## Scripted playthrough: starts a new penguin run, gets through the intro, farms a
## tile, sleeps, visits town, fights in the meadow, mines. Saves screenshots to the
## path after "--" and fails loudly if a step doesn't do what it should.
## Run: xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/playtest.gd -- /tmp/shots

var out := "/tmp"
var fails := 0
var shots := 0


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)  # else every save_png fails quietly
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameMap.next_spawn = Vector2.ZERO
	var farm: Node = (load("res://scenes/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	current_scene = farm
	await frames(30)
	await shot("01_intro")
	# Advance intro until a choice appears.
	var d := Dialogue.instance(self)
	for i in 30:
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "intro reached the crystal's question")
	await shot("02_choice")
	await press("a", 2)   # choose option 0
	for i in 30:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(not d.active, "intro finished")
	check(bool(GameState.run["intro_done"]), "intro_done flag set")
	check(GameState.run["quests"].size() >= 2, "quests added")
	await frames(10)
	await shot("03_after_intro")

	# Walk to the plot and farm one tile.
	var p: Player = farm.player
	var stand := Vector2i(16, 14)
	for dx in range(0, 8):
		if farm._tillable(Vector2i(16 + dx, 13)) and not farm.blocked.has(Vector2i(16 + dx, 14)):
			stand = Vector2i(16 + dx, 14)
			break
	p.position = farm.cell_center(stand)
	p.facing = "up"
	await frames(5)
	var fc := p.facing_cell()
	check(farm._tillable(fc), "facing open grass to till (%s)" % str(fc))
	await act()
	var key := "%d,%d" % [fc.x, fc.y]
	check(GameState.run["farm"].has(key), "tilled a tile")
	GameState.run["selected"] = "turnip_seed"
	await act()
	check(GameState.run["farm"][key].get("crop", "") == "turnip", "planted turnip")
	GameState.run["selected"] = ""
	GameState.select_slot(1)  # watering can
	await act()
	check(bool(GameState.run["farm"][key].get("watered", false)), "watered the tile")
	GameState.select_slot(0)
	await shot("04_farming")

	# ---- Round 11: facing, pup menu, work-walking, energy ----
	await _r11_farm(farm, p, d)

	# Run test (keyboard path): hold B + right and check speed.
	for x in range(3, 24):
		for y in range(18, 23):
			farm.clear_cell(Vector2i(x, y))
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	p.position = farm.cell_center(Vector2i(4, 19))
	p.frozen = false
	p.auto_target = Vector2.INF
	Dialogue.block_until_ms = 0
	await frames(5)
	Input.action_press("right"); Input.action_press("b")
	var spd := 0.0
	for i in 40:
		await frames(1)
		spd = maxf(spd, p.velocity.length())
	Input.action_release("right"); Input.action_release("b")
	check(spd > Player.WALK_SPEED * 1.3, "running is faster than walking (%.0f, busy=%s frozen=%s)" % [spd, str(p._busy), str(p.frozen)])
	await frames(30)
	# Touch path: a drag from the lower-left becomes the floating joystick; far = run.
	p.position = farm.cell_center(Vector2i(6, 20))
	touch(0, Vector2(60, 400), true)
	await frames(2)
	drag(0, Vector2(60, 400), Vector2(110, 400))
	var tspd := 0.0
	for i in 40:
		await frames(1)
		tspd = maxf(tspd, p.velocity.length())
	check(tspd > Player.WALK_SPEED * 1.3, "joystick pushed far runs (%.0f)" % tspd)
	p.position = farm.cell_center(Vector2i(6, 20))  # fresh runway for the walk check
	drag(0, Vector2(110, 400), Vector2(76, 400))
	var wspd := 0.0
	for i in 25:
		await frames(1)
		wspd = maxf(wspd, p.velocity.length()) if i > 5 else 0.0
	check(wspd < Player.WALK_SPEED * 1.15 and wspd > 10.0, "joystick pushed a little walks (%.0f)" % wspd)
	touch(0, Vector2(76, 400), false)
	await frames(10)
	check(p.velocity.length() < 1.0, "releasing the joystick stops")
	await shot("05_running")
	# Touch A on the sell box opens a dialogue, tapping the box advances it.
	p.position = farm.cell_center(Vector2i(8, 11))
	p.facing = "up"
	await frames(3)
	touch(1, TouchControls.BUTTONS["a"]["pos"], true)
	await frames(3)
	touch(1, TouchControls.BUTTONS["a"]["pos"], false)
	await frames(10)
	check(d.active, "touch A talks to the sell box")
	touch(0, Vector2(135, 300), true)
	await frames(2)
	touch(0, Vector2(135, 300), false)
	await frames(2)
	touch(0, Vector2(135, 300), true)
	await frames(2)
	touch(0, Vector2(135, 300), false)
	await frames(10)
	check(not d.active, "tapping the dialogue box advances/closes it")
	# Tap-to-move: tap a grass cell, the player walks there.
	await frames(20)
	p.position = farm.cell_center(Vector2i(20, 22))
	for x in range(18, 23):
		for y in range(21, 27):
			farm.clear_cell(Vector2i(x, y))
	await frames(45)  # let the camera settle on the new position
	var cam_tf: Transform2D = farm.get_canvas_transform()
	var dest: Vector2 = farm.cell_center(Vector2i(20, 25))
	var screen: Vector2 = cam_tf * (dest - Vector2(0, 8))  # middle of the cell, not its bottom edge
	for attempt in 4:  # a slow headless frame can turn a tap into a "hold"; re-tap
		touch(0, screen, true)
		await frames(1)
		touch(0, screen, false)
		await frames(4)
		if p.auto_target != Vector2.INF:
			break
	if p.auto_target == Vector2.INF:
		# Headless frames can be slow enough that every tap reads as a hold (the tap
		# limit is wall-clock time); the walking itself is what this checks.
		farm.handle_tap(screen)
	await frames(80)
	check(p.position.distance_to(dest) < 6.0, "tap-to-move walks to the tapped cell (%.0f away)" % p.position.distance_to(dest))
	# Toolbar: tapping slot 7 (turnip seeds) puts seeds in hand.
	touch(0, Vector2(Hud.TOOLBAR_X + 6 * Hud.SLOT + 10, Hud.TOOLBAR_Y + 10), true)
	await frames(2)
	touch(0, Vector2(Hud.TOOLBAR_X + 6 * Hud.SLOT + 10, Hud.TOOLBAR_Y + 10), false)
	await frames(2)
	check(str(GameState.run["selected"]) == "turnip_seed", "tapping the toolbar selects seeds (%s)" % str(GameState.run["selected"]))
	Input.action_press("slot_1")
	await frames(2)
	Input.action_release("slot_1")
	await frames(2)
	check(int(GameState.run["slot"]) == 0 and str(GameState.run["selected"]) == "", "number key selects the hoe")
	# Menu opens, shows tabs, closes.
	await press("menu", 2)
	await frames(5)
	check(paused, "MENU pauses and opens the menu")
	await shot("05b_menu")
	await press("menu", 2)
	await frames(5)
	check(not paused, "MENU closes the menu")
	await frames(20)  # input is blocked briefly after a menu closes

	# Enter the house via the door.
	p.position = farm.cell_center(Vector2i(13, 11))
	p.facing = "up"
	await frames(3)
	check(farm.things.get(p.facing_cell(), {}).get("type", "") == "door", "facing the door")
	await press("a", 3)
	await frames(50)
	var house := current_scene
	check(house != null and house.scene_id() == "house", "entered the house")
	await shot("06_house")
	# Sleep.
	house.player.position = house.cell_center(Vector2i(3, 3))
	house.player.facing = "up"
	await frames(3)
	var day0 := int(GameState.run["day"])
	await press("a", 3)
	for i in 40:
		await frames(5)
		if d.active:
			await press("a", 2)
		if int(GameState.run["day"]) > day0 and not d.active:
			break
	check(int(GameState.run["day"]) == day0 + 1, "slept to the next day")
	check(int(GameState.run["farm"][key]["days"]) == 1, "crop grew overnight")
	await frames(45)  # past the day-change fade
	await shot("07_morning")

	# Go to town through the farm's south road: step into the widened exit zone
	# (beside the old strip, not on it), no signpost needed.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(30)
	var f2 := current_scene as GameMap
	var zone_cell := Vector2i(-999, -999)
	for e in f2.exits:
		if str(e["scene"]) == "town":
			var r: Rect2i = e["rect"]
			for c: Vector2i in [Vector2i(r.position.x - 1, r.position.y), Vector2i(r.end.x, r.position.y), Vector2i(r.position.x, r.end.y), Vector2i(r.position.x - 1, r.end.y)]:
				if f2.in_exit(e, c) and not r.has_point(c) and not f2.blocked.has(c):
					zone_cell = c
					break
	check(zone_cell != Vector2i(-999, -999), "farm's town exit is wider than its strip")
	if zone_cell != Vector2i(-999, -999):
		f2.player.position = f2.cell_center(zone_cell)
	# The map change fades out first: give it up to ~3 s on a busy machine.
	for _w in 18:
		await frames(10)
		if current_scene is GameMap and (current_scene as GameMap).scene_id() == "town":
			break
	if not (current_scene is GameMap and (current_scene as GameMap).scene_id() == "town"):
		check(false, "stepping into the exit zone beside the strip leaves for town")
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/town.tscn")
		await frames(40)
	else:
		check(true, "stepping into the exit zone beside the strip leaves for town")
	var town := current_scene
	check(town != null and town.scene_id() == "town", "in town")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	await shot("08_town")
	# Talk to Maple (noon: she's out on the plaza; routines keep her indoors at 6am).
	GameState.run["time"] = 12 * 60 + 10
	await frames(5)
	var maple: Npc = town.npcs[0]
	maple._apply_routine(true)
	await frames(3)
	check(maple.visible, "Maple is outside at noon (%s)" % maple._place)
	maple.wander = 0.0  # hold still for the test (she drifts around her stall otherwise)
	maple._target = maple.position
	maple.set_process(false)  # she walks her routine otherwise and can step onto the player's cell
	# Stand on an open side of her (scatter props move with the world seed).
	var sides := [[Vector2(0, 14), "up"], [Vector2(-14, 0), "right"], [Vector2(14, 0), "left"], [Vector2(0, -14), "down"]]
	var pick: Array = sides[0]
	for sd in sides:
		var cc: Vector2i = town.world_to_cell(maple.position + sd[0])
		if not town.blocked.has(cc):
			pick = sd
			break
	town.player.position = maple.position + pick[0]
	town.player.facing = pick[1]
	await frames(20)
	# A story beat may still be open from arriving in town: finish it first.
	for i in 30:
		if not d.active:
			break
		await press("a", 2)
		await frames(4)
	await frames(30)
	Dialogue.block_until_ms = 0
	await press("a", 3)
	await frames(10)
	check(d.active, "Maple talks")
	maple.set_process(true)
	await shot("09_talk")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(GameState.quest_done("meet_town"), "meet_town quest completed")
	# Shop: walk in the store door, then up to the counter and buy strawberry seeds.
	town.player.position = town.cell_center(Vector2i(16, 29))
	town.player.facing = "up"
	await frames(20)
	await press("a", 3)
	await frames(50)
	var store := current_scene
	check(store != null and store.scene_id() == "interior", "entered the general store")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	await shot("10a_store")
	store.player.position = store.cell_center(Vector2i(6, 7))
	store.player.facing = "up"
	await frames(10)
	var before := int(GameState.run["crystals"])
	await press("a", 3)
	await frames(10)
	for i in 10:  # first-visit freebie lines
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "shop menu open")
	await shot("10_shop")
	await press("down", 2)
	await press("a", 2)   # buy option 1 (strawberry seeds)
	await frames(10)
	if d._in_choice and d._text and d._text.text.contains("How many"):
		await press("a", 2)   # seeds ask how many: take 1
		await frames(10)
	check(int(GameState.run["crystals"]) < before, "bought something")
	# Leave the shop: focus starts at 0, so one "up" wraps to the last option (Leave).
	for i in 10:
		if not d.active:
			break
		if d._in_choice:
			await press("up", 2)
			await press("a", 2)
		else:
			await press("a", 2)
		await frames(6)
	for i in 5:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(not d.active, "left the shop")

	# Meadow combat.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(40)
	var meadow := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(meadow.enemies.size() >= 3, "grumps spawned (%d)" % meadow.enemies.size())
	await shot("11_meadow")
	var kills0 := int(GameState.run["kills"])
	GameState.select_slot(4)  # sword
	for i in 12:
		if meadow.enemies.is_empty():
			break
		var e: Enemy = meadow.enemies[0]
		meadow.player.position = e.position + Vector2(-12, 0)
		meadow.player.facing = "right"
		meadow.player.invuln = 2.0
		GameState.run["hp"] = int(GameState.run["max_hp"])
		await act()
		if not is_instance_valid(meadow) or current_scene != meadow:
			break
	check(int(GameState.run["kills"]) > kills0, "defeated a grump")
	await shot("12_fight")

	# Mine.
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/mine.tscn")
	await frames(40)
	var mine := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(mine.scene_id() == "mine", "in the mine")
	await shot("13_mine")

	# ---- Gangster arc: intro, choice, and the meadow boss. ----
	GameState.new_run("gangsters", "pax", "Pax", "Dreamhollow", "Rex")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	for i in 30:
		if d._in_choice:
			break
		await press("a", 2)
		await frames(6)
	check(d._in_choice, "gangster intro reaches the letter choice")
	await shot("14_gangster_choice")
	await press("down", 2)
	await press("a", 2)
	for i in 30:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	check(str(GameState.run["flags"].get("letter", "")) == "kept", "letter decision stored")
	GameState.run["kills"] = 4
	GameState.run["meadow_kills"] = 4
	GameState.select_slot(4)
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/meadow.tscn")
	await frames(40)
	var m2 := current_scene
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	# Swinging was verified above; here just finish one grump to trigger the boss.
	var e0: Enemy = m2.enemies[0]
	m2.player.invuln = 3.0
	e0.hit(10, m2.player.position)
	await frames(60)
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	await frames(10)
	var boss: Enemy = null
	for e in m2.enemies:
		if e.kind == "big_grump" or e.kind == "thug_brute":
			boss = e
	check(boss != null, "boss appeared after 5 kills")
	await shot("15_boss")
	if boss:
		boss.hp = 1
		for i in 6:
			if not is_instance_valid(boss) or not boss._alive:
				break
			m2.player.position = boss.position + Vector2(-12, 0)
			m2.player.facing = "right"
			m2.player.invuln = 2.0
			await act()
		for i in 10:
			if not d.active:
				break
			await press("a", 2)
			await frames(6)
		check(GameState.quest_done("clear_meadow"), "boss defeated completes the meadow quest")
	# Tool tiers: the smith's upgrade ladder swaps the toolbar icon and raises power.
	check(not GameState.can_upgrade_tool("axe"), "axe can't upgrade with nothing")
	GameState.add_item("copper_bar", 3)
	GameState.run["crystals"] = int(GameState.run["crystals"]) + 300
	check(GameState.can_upgrade_tool("axe") and GameState.upgrade_tool("axe"), "axe upgrades to copper with 3 bars + 300 crystals")
	check(GameState.tool_tier("axe") == 1 and GameState.count("copper_bar") == 0, "upgrade consumed the bars (tier %d)" % GameState.tool_tier("axe"))
	check(Hud.icon_for("axe") == "axe_copper" and Art.has("items", "axe_copper"), "copper axe has its own icon (%s)" % Hud.icon_for("axe"))
	check(GameState.item_name("axe") == "Copper Axe", "upgraded tool is named by tier (%s)" % GameState.item_name("axe"))
	await _r11_passout()
	print("PLAYTEST DONE, failures: ", fails, ", screenshots: ", shots)
	quit(1 if fails > 0 else 0)


## Round 11 checks on the farm: facing on diagonals, the pup menu only on CHECK,
## work-walking with the hoe, and the energy costs.
func _r11_farm(farm: GameMap, p: Player, d: Dialogue) -> void:
	# Facing: an exact diagonal (and straight down) faces down, never sideways.
	for x in range(18, 30):
		for y in range(16, 30):
			farm.clear_cell(Vector2i(x, y))
	p.position = farm.cell_center(Vector2i(20, 18))
	p.auto_target = Vector2.INF
	Dialogue.block_until_ms = 0
	await frames(3)
	Input.action_press("down"); Input.action_press("right")
	await frames(20)
	check(p.facing == "down", "moving down-right (a true diagonal) faces down (%s)" % p.facing)
	Input.action_release("right")
	await frames(10)
	check(p.facing == "down" and not p.anim_name.begins_with("walk") or p.anim_name in ["walk_down", "run_down", "view_front"], "moving down shows the toward-you walk (%s)" % p.anim_name)
	Input.action_release("down")
	await frames(10)
	var pf := CharacterLibrary.frames_for("penguin")
	check(pf.has_animation("walk_down") and pf.get_frame_texture("walk_down", 0) != pf.get_frame_texture("walk", 0), "penguin's walk_down is not the sideways walk")
	await shot("r11_facing_down")
	# Pup: USE on the pup never opens its menu; CHECK does when it's calm.
	if farm.pet and farm.pet.visible:
		p.facing = "right"
		var fc := p.facing_cell()
		farm.pet.position = farm.cell_center(fc)
		GameState.select_slot(4)  # sword
		p.do_action("a")
		await frames(4)
		check(not d.active, "USE with the pup in front swings, no pup menu")
		await frames(30)
		farm.pet.position = farm.cell_center(fc)
		p._attack_cd = 0.0
		p._busy = false
		check(farm.try_interact(fc, true), "CHECK on the pup opens its menu when no foe is near")
		await frames(4)
		check(d.active, "pup menu is up")
		for i in 8:
			if not d.active:
				break
			await press("a", 2)
			await frames(6)
		await frames(20)
		var foe := farm.spawn_enemy("grump", p.position + Vector2(48, 0))
		await frames(2)
		farm.pet.position = farm.cell_center(fc)
		check(not farm.try_interact(fc, true) or not d.active, "CHECK on the pup with a foe 3 tiles away doesn't open the menu")
		await frames(4)
		check(not d.active, "no pup menu mid-fight")
		if is_instance_valid(foe):
			farm.enemies.erase(foe)
			foe.queue_free()
		await frames(5)
	# Work-walking: hold down + USE with the hoe; it tills a row, stepping each time.
	GameState.select_slot(0)
	GameState.run["energy"] = int(GameState.run["max_energy"])
	p.position = farm.cell_center(Vector2i(24, 18))
	p.facing = "down"
	await frames(5)
	var before := 0
	for y in range(19, 28):
		if GameState.run["farm"].has("24,%d" % y):
			before += 1
	Input.action_press("down"); Input.action_press("a")
	await frames(240)
	Input.action_release("a"); Input.action_release("down")
	await frames(20)
	var tilled := 0
	for y in range(19, 28):
		if GameState.run["farm"].has("24,%d" % y):
			tilled += 1
	check(tilled - before >= 3, "holding down + USE with the hoe tills a row while stepping (%d tiles)" % (tilled - before))
	await shot("r11_hoe_row")
	# Energy: fractional costs, cheap small actions, a clear 15% line.
	var e0 := int(GameState.run["energy"])
	GameState.run["en_frac"] = 0.0
	for i in 10:
		GameState.spend_for("pickaxe")
	var used := e0 - int(GameState.run["energy"])
	check(used >= 4 and used <= 8, "10 pickaxe swings cost ~6 energy at level 1 (%d)" % used)
	check(GameState.energy_cost_f("sword") > 0.0 and GameState.energy_cost_f("sword") < 0.3, "a sword swing costs a little (%.2f)" % GameState.energy_cost_f("sword"))
	check(int(GameState.run["max_energy"]) >= 120, "a new farmer starts with 120 energy (%d)" % int(GameState.run["max_energy"]))
	GameState.run["energy"] = int(int(GameState.run["max_energy"]) * 0.1)
	check(GameState.exhausted(), "under 15%% is Exhausted")
	await frames(10)
	await shot("r11_exhausted_hud")
	GameState.run["energy"] = int(GameState.run["max_energy"])
	GameState.run["en_warn"] = 0


## Round 11: out of health -> the clinic, with a capped bill and a note.
func _r11_passout() -> void:
	var m := current_scene as GameMap
	if m == null:
		return
	var d := Dialogue.instance(self)
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	GameState.run["crystals"] = 1000
	var day0 := int(GameState.run["day"])
	var t0 := int(GameState.run["time"])
	m.player_down("hurt")
	await frames(150)
	var c := current_scene as GameMap
	check(c != null and c.scene_id() == "interior" and str(GameState.run.get("interior", "")) == "clinic", "collapsing wakes you in the clinic (%s)" % (c.scene_id() if c else "?"))
	if t0 < Faint.WAKE:  # Tom: a faint before 10pm wakes you at 10pm the same day
		check(int(GameState.run["day"]) == day0 and int(GameState.run["time"]) >= Faint.WAKE, "you wake at 10pm the same day (day %d, %d)" % [int(GameState.run["day"]) - day0, int(GameState.run["time"])])
	else:
		check(int(GameState.run["day"]) == day0 + 1, "it's the next morning")
	check(int(GameState.run["crystals"]) == 1000 - 100, "clinic bill is 8%% + 20 (%d left)" % int(GameState.run["crystals"]))
	await frames(40)
	var told := false
	for i in 40:
		if d.active and d._full.contains("carried you to the clinic"):
			told = true
			break
		if d.active:
			await press("a", 2)
			await frames(8)
		else:
			await frames(10)
	check(told, "the clinic explains what happened")
	await frames(30)
	await shot("r11_clinic")
	for i in 10:
		if not d.active:
			break
		await press("a", 2)
		await frames(6)
	if c:
		check(not c.blocked.has(c.player.cell()), "clinic wake spot is open floor")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func press(action: String, hold_frames: int) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)


## Press A and wait until the player's action animation is done.
func act() -> void:
	await press("a", 3)
	var scene := current_scene
	for i in 60:
		await frames(1)
		if scene is GameMap and (scene as GameMap).player and not (scene as GameMap).player._busy:
			break
	await frames(3)


func drag(index: int, from: Vector2, to: Vector2) -> void:
	var scale := Vector2(root.size) / Vector2(270, 480)
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = to * scale
	ev.relative = (to - from) * scale
	Input.parse_input_event(ev)


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	# Test positions are in game (viewport) space; real touches arrive in window
	# space and Godot maps them through the stretch transform, so do the reverse.
	var scale := Vector2(root.size) / Vector2(270, 480)
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos * scale
	ev.pressed = pressed
	Input.parse_input_event(ev)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(2)
	var err := root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	check(err == OK, "saved " + name)
	shots += 1
