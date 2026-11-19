extends SceneTree
## Audit helper (CONDUCT 1): a new penguin (or ARC=gangsters) run from the first
## line to the morning of day 3. Logs every dialogue line, toast-worthy goal line
## and quest, and saves screenshots to the dir after "--".
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/newgame_flow_c1.gd -- /tmp/ng

var out := "/tmp/ng"
var n := 0
var _last := ""


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	var arc := OS.get_environment("ARC") if OS.get_environment("ARC") != "" else "penguins"
	GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(30)
	await talk_through("intro")
	await frames(20)
	await shot("after_intro")
	goal("after intro")
	var farm := current_scene as GameMap
	# Farm a tile, as a player would.
	var p: Player = farm.player
	for dx in range(0, 10):
		if farm._tillable(Vector2i(16 + dx, 13)) and not farm.blocked.has(Vector2i(16 + dx, 14)):
			p.position = farm.cell_center(Vector2i(16 + dx, 14))
			break
	p.facing = "up"
	GameState.select_slot(0)
	await frames(5)
	await act()
	goal("tilled")
	await shot("tilled")
	GameState.run["selected"] = "turnip_seed"
	await act()
	goal("planted")
	GameState.run["selected"] = ""
	GameState.select_slot(1)
	await act()
	goal("watered")
	await shot("watered")
	await talk_through("farm extra")
	# Walk to town.
	farm.go_to("town", Vector2(40 * 16, 3 * 16), "down")
	await frames(60)
	await talk_through("town arrive")
	await shot("town")
	goal("in town")
	var town := current_scene as GameMap
	# Talk to every villager standing in town once.
	for c in town.get_children():
		if c is Npc:
			var npc := c as Npc
			print("NPC in town: ", npc.id)
	await sleep_in_house("sleep1")
	goal("day 2 morning")
	GameMap.next_spawn = Vector2(13 * 16 + 8, 11 * 16 + 4)
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	await talk_through("farm day2")
	await shot("farm_day2")
	var f2 := current_scene as GameMap
	f2.later(f2._mailbox)
	await talk_through("mailbox day2")
	goal("after mail")
	print("quests d2: ", GameState.run["quests"])
	await sleep_in_house("sleep2")
	GameMap.next_spawn = Vector2(13 * 16 + 8, 11 * 16 + 4)
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(40)
	await talk_through("farm day3")
	await shot("farm_day3")
	goal("day 3")
	print("quests: ", GameState.run["quests"])
	print("hints: ", GameState.run.get("hints", []))
	print("mail: ", GameState.run.get("mail", []))
	quit()


func sleep_in_house(tag: String) -> void:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/house.tscn")
	await frames(40)
	await talk_through(tag + " enter")
	var h := current_scene as GameMap
	h.later(h._sleep)
	await frames(80)
	await talk_through(tag)
	await shot(tag + "_after")


func goal(tag: String) -> void:
	print("GOAL [", tag, "]: ", GameState.next_step())


func talk_through(tag: String) -> void:
	var d := Dialogue.instance(self)
	for i in 200:
		await frames(4)
		if not d.active:
			if i > 20:
				return
			continue
		var t := d._full
		if t != _last:
			print("[", tag, "] ", d._who.text, ": ", t)
		_last = t
		if n < 30 and i % 3 == 0:
			await shot("%s_%02d" % [tag.replace(" ", "_"), i])
		if d._in_choice:
			await frames(14)
			var opts: Array = []
			for b in d._choices.get_children():
				opts.append((b as Button).text)
			print("   CHOICES: ", opts)
			if d._choices.get_child_count() > 0:
				(d._choices.get_child(0) as Button).pressed.emit()
		else:
			d._advance()
			await frames(2)
			if d._typing:
				d._advance()
		await frames(4)


func press(action: String, hold: int) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)
	await frames(1)


func act() -> void:
	await press("a", 3)
	for i in 60:
		await frames(1)
		var m := current_scene as GameMap
		if m and m.player and not m.player._busy:
			break
	await frames(3)


func frames(k: int) -> void:
	for i in k:
		await process_frame


func shot(name: String) -> void:
	n += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%03d_%s.png" % [out, n, name])
