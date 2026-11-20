extends SceneTree
## Randomised play bot. Many of these run in parallel (tools/bots.sh), each with
## its own seed, arc, hero, story progress and play style, each in its own
## user:// (XDG_DATA_HOME), so they don't share a save.
##
##   godot --headless --path . -s res://tools/bot.gd -- <seed> <arc> <playable> <style> <progress> [<difficulty 0-3> <day_len>] <days>
##   (C5: the bots.sh / tools/conduct/bot_spec.sh tables give every bot a difficulty and a day length)
##
## style: wander | farmer | fighter | menus | story
## progress: 0..5 — how far the story is pushed before starting (flags/quests),
##           so late chapters, deep mine floors and the moon get exercised too.
## Prints "BOT FAIL ..." for broken invariants and "BOT WARN ..." for suspicious
## state (stuck player); the runner also counts SCRIPT ERRORs in the log.

var rng := RandomNumberGenerator.new()
var seed_ := 1
var arc := "penguins"
var playable := "kairi"
var style := "wander"
var progress := 0
var difficulty := 2
var day_len := 15
var kills := 0
var days := 6
var fails := 0
var warns := 0
var steps := 0
var scenes_visited := {}

## Gangster-only maps (the lieutenant cities and the Hideout): penguin bots stay out (C5 c5_19 #5).
const GANG_ONLY := ["docks", "hideout", "neon", "underground", "uptown"]
const SCENES_COMMON := ["farm", "town", "beach", "mountain", "forest", "lake", "meadow", "mine", "house", "moon",
	"countryside", "docks", "hideout", "highlands", "jungle", "marsh", "neon", "orchard_hills", "quarry", "riverlands",
	"ruins", "sky", "station", "underground", "uptown", "wastes", "interior"]

# Story progress presets: quests completed and flags set, cumulative.
const PROGRESS := [
	{"quests": [], "flags": ["intro_done_flag"]},
	{"quests": ["first_harvest", "clear_meadow"], "flags": ["town_seen", "meow_taught", "crystal_meadow_seen"]},
	{"quests": ["spark", "wastes_gate", "hideout"], "flags": ["catship_done", "mine_open_1", "mountain_seen"]},
	{"quests": ["commander", "sky_stair", "knight"], "flags": ["babies_done", "campfire_done", "sky_seen", "boss_sky"]},
	{"quests": ["uptown"], "flags": ["prison_done", "merkitty_done", "mermaid_gift"]},
	{"quests": ["teleporter", "alder_gold"], "flags": ["bell_rung", "final_started"]},
]


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: seed_ = int(a[0])
	if a.size() > 1: arc = a[1]
	if a.size() > 2: playable = a[2]
	if a.size() > 3: style = a[3]
	if a.size() > 4: progress = int(a[4])
	if a.size() >= 8:  # seed arc playable style progress difficulty day_len days
		difficulty = int(a[5])
		day_len = int(a[6])
		days = int(a[7])
	elif a.size() > 5: days = int(a[5])
	rng.seed = seed_
	seed(seed_)
	InputSetup.ensure_actions()
	Dialogue.audit = true
	GameState.new_run(arc, playable, "Bot%d" % seed_, "Bottown", "Pup")
	GameState.run["intro_done"] = true
	if not GameState.run.get("opts", null) is Dictionary:
		GameState.run["opts"] = {}
	GameState.run["opts"]["difficulty"] = clampi(difficulty, 0, 3)
	GameState.run["day_len"] = day_len
	_apply_progress()
	print("BOT %d start arc=%s hero=%s style=%s progress=%d difficulty=%d day_len=%d" % [seed_, arc, playable, style, progress, Difficulty.level(), GameState.day_len()])
	for d in days:
		var n_scenes := 3 if style != "farmer" else 2
		for s in n_scenes:
			var sc := _pick_scene()
			await _go(sc)
			await _play_scene(sc)
		await _sleep_and_roundtrip()
	for t in Dialogue.audit_log:
		_warn("menu B can't leave: " + str(t))
	print("BOT %d done: %d fails, %d warns, %d steps, %d kills, %d ownerless pauses, scenes %s, day %d, ◆%d" % [seed_, fails, warns, steps, kills, Hud.orphan_count, str(scenes_visited.keys()), int(GameState.run["day"]), int(GameState.run["crystals"])])
	quit(1 if fails > 0 else 0)


func _apply_progress() -> void:
	for i in mini(progress + 1, PROGRESS.size()):
		for q in PROGRESS[i]["quests"]:
			GameState.add_quest(q, "bot")
			GameState.complete_quest(q)
		for f in PROGRESS[i]["flags"]:
			GameState.run["flags"][f] = true
	if progress >= 2:
		GameState.run["crystals"] = int(GameState.run["crystals"]) + 2000
		GameState.run["mine_floor"] = 4 * progress
		for it in ["copper_bar", "iron_bar", "crystal_shard", "refined_crystal", "litter_box", "potion", "bread"]:
			if GameState.items.has(it):
				GameState.add_item(it, 5)
	if progress >= 3:
		for sk in GameState.run["skills"]:
			GameState.add_xp(sk, 3000)


## Every mega-region area (data/mega_regions.json) open to `a` whose scene exists.
static func mega_areas(a: String) -> Array:
	var out: Array = []
	var d: Dictionary = GameState.load_json("res://data/mega_regions.json")
	for rid: String in d.get("order", []):
		var r: Dictionary = d.get("list", {}).get(rid, {})
		if str(r.get("arc", "both")) not in ["both", a]:
			continue
		var areas: Variant = r.get("areas", {})
		for k: Variant in areas:
			var id := str(k) if areas is Dictionary else str((k as Dictionary).get("id", ""))
			if id != "" and id not in out and ResourceLoader.exists("res://scenes/%s.tscn" % id):
				out.append(id)
	return out


func _pick_scene() -> String:
	# A quarter of the time, go and poke the newer systems: battlefields,
	# colonies, the big mine caverns, the gangster districts with their bosses.
	if rng.randf() < 0.25:
		var newer: Array = ["bf_frostfield", "bf_shattered_vale", "colony_coral", "colony_kelp", "colony_ice", "colony_ember", "mine"] if arc == "penguins" else ["bf_rail_yards", "bf_dockside", "docks", "neon", "crystal_meadow", "countryside", "mine"]
		# Half of those trips: one of the mega-region areas open to this arc (C4 P6).
		var mega := mega_areas(arc)
		if not mega.is_empty() and rng.randf() < 0.5:
			return mega[rng.randi_range(0, mega.size() - 1)]
		return newer[rng.randi_range(0, newer.size() - 1)]
	match style:
		"farmer":
			return ["farm", "farm", "town", "house"][rng.randi_range(0, 3)]
		"fighter":
			return ["meadow", "mine", "mine", "wastes", "sky", "quarry", "ruins"][rng.randi_range(0, 6)]
		"story":
			var arc_scenes := ["farm", "town", "meadow", "mountain", "sky", "lake", "moon", "mine"]
			arc_scenes.append("crystal_meadow" if arc == "penguins" else "hideout")
			return arc_scenes[rng.randi_range(0, arc_scenes.size() - 1)]
	var pool: Array = SCENES_COMMON.duplicate()
	if arc == "penguins":
		pool = pool.filter(func(x: String) -> bool: return not x in GANG_ONLY)
		pool.append("crystal_meadow")
	return pool[rng.randi_range(0, pool.size() - 1)]


func _go(sc: String) -> void:
	var path := "res://scenes/%s.tscn" % sc
	if not ResourceLoader.exists(path):
		_fail("scene missing: " + sc)
		return
	GameMap.next_spawn = Vector2.ZERO
	var err := change_scene_to_file(path)
	if err != OK:
		_fail("change_scene %s -> %d" % [sc, err])
		return
	await frames(25)
	scenes_visited[sc] = true
	if current_scene == null:
		_fail("no current scene after loading " + sc)


func _play_scene(sc: String) -> void:
	var n := 70 if style != "menus" else 40
	var stuck_frames := 0
	var last_pos := Vector2.INF
	for i in n:
		var m := current_scene as GameMap
		if m == null:
			await frames(5)
			continue
		await _dialogue_tick()
		var roll := rng.randf()
		match style:
			"farmer":
				if roll < 0.35: await _walk()
				elif roll < 0.85: await _farm_step(m)
				else: await _random_button()
			"fighter":
				if roll < 0.7 and is_instance_valid(m) and await _hunt(m): pass  # C5: seek a foe and fight it
				elif roll < 0.85: await _walk()
				elif roll < 0.95: await _swing()
				else: await _random_button()
			"menus":
				if roll < 0.5:
					_last_act = "menu_crawl"
					await _menu_crawl(m)
				elif roll < 0.8:
					_last_act = "walk"
					await _walk()
				else:
					_last_act = "random_button"
					await _random_button()
			_:
				if roll < 0.55: await _walk()
				elif roll < 0.8: await _random_button()
				elif roll < 0.9: await _swing()
				elif is_instance_valid(m): await _tap_world(m)  # the map may have been freed by an await above
		steps += 1
		_check_invariants(sc)
		# Stuck detection: lots of walking but the player never moves.
		m = current_scene as GameMap
		if m and m.player:
			if last_pos != Vector2.INF and m.player.position.distance_to(last_pos) < 0.5:
				stuck_frames += 1
			else:
				stuck_frames = 0
			last_pos = m.player.position
			if stuck_frames == 25:
				# Only a real trap counts: probe all four ways before warning.
				var where := "%s at cell %s" % [_scene_name(), str(m.player.cell())]
				var froz := m.player.frozen
				if await _boxed_in(m):
					var dl := Dialogue.instance(self)
					var said := ""
					if dl.active and dl._text:
						said = " (dialogue up: \"%s\")" % dl._text.text.left(80)
					if froz:
						said += " story_pending=%s" % str(GameState.run.get("story_pending", ""))
					_warn("player boxed in at %s, frozen=%s paused=%s%s" % [where, str(froz), str(paused), said])
				stuck_frames = 0
		if current_scene != null and str(current_scene.scene_file_path).get_file().get_basename() != sc and not (current_scene is GameMap):
			pass


func _dialogue_tick() -> void:
	var d := Dialogue.instance(self)
	var guard := 0
	var rounds := 0
	while d.active and guard < 60:
		guard += 1
		if d._in_choice:
			rounds += 1
			# A real player leaves menus: after a pick or two, take the way out (B).
			# Loops like the farm Plans board otherwise keep a bot browsing forever.
			if rounds > 2 or rng.randf() < 0.3:
				var before_text := d._text.text if d._text else ""
				await press("b", 2)
				await frames(4)
				if not d.active or not d._in_choice or (d._text and d._text.text != before_text):
					continue
				# A menu that just opened may still be settling: wait it out, try B again.
				await frames(12)
				await press("b", 2)
				await frames(4)
				if not d.active or not d._in_choice or (d._text and d._text.text != before_text):
					continue
				# No way out on B: a story question; pick an answer.
			var k := rng.randi_range(0, 2)
			for j in k:
				await press("down", 1)
			await press("a", 2)
		else:
			await press("a", 2)
		await frames(4)
	if d.active:
		_warn("dialogue still open after 60 presses: %s" % (d._text.text.left(80) if d._text else ""))
	await _clear_screens()


## A paused tree with no dialogue is a full-screen UI (menu, craft, chest, prize,
## bowling...). Every one must close on B (or MENU); one that doesn't is a softlock.
func _clear_screens() -> void:
	if not paused or Dialogue.instance(self).active:
		return
	for i in 4:
		await press("b" if i < 3 else "menu", 2)
		await frames(6)
		if not paused or Dialogue.instance(self).active:
			return
	var open: Array = []
	_modal_names(root, open)
	var why := ""
	if current_scene:
		for ch in current_scene.get_children():
			if ch is GameMenu:
				why = " [menu open=%s panel=%s tab=%s rebind='%s' was_paused=%s modal=%s]" % [ch._open, ch._panel.visible, ch._tab, ch._rebinding, ch._was_paused, Hud.modal_rect]
	var layers: Array = []
	for n in [root, current_scene]:
		if n:
			for ch in n.get_children():
				if ch is CanvasLayer and (ch as CanvasLayer).visible and ch.get_child_count() > 0:
					var kids: Array = []
					for k in ch.get_children():
						var ks: Script = k.get_script()
						kids.append("%s:%s%s" % [k.name, k.get_class(), (":" + ks.resource_path.get_file()) if ks else ""])
					layers.append("%s(%d)%s" % [ch.name, ch.layer, kids])
	_fail("screen won't close on B/MENU in %s: %s%s layers=%s last=%s act=%s" % [_scene_name(), ", ".join(open), why, layers, _last_press, _last_act])
	# Unstick so the run carries on.
	paused = false
	Hud.modal_rect = Rect2()


func _modal_names(n: Node, out: Array) -> void:
	for c in n.get_children():
		var sc: Script = c.get_script()
		var shown: bool = (c as CanvasLayer).visible if c is CanvasLayer else ((c as CanvasItem).visible if c is CanvasItem else true)
		if sc and shown and (c is CanvasLayer or c is Control):
			var nm := str(sc.get_global_name())
			if nm != "" and nm not in ["Hud", "TouchControls", "Dialogue"]:
				out.append(nm)
		if out.size() < 8:
			_modal_names(c, out)


func _scene_name() -> String:
	var m := current_scene as GameMap
	if m and m.has_method("scene_id"):
		return m.scene_id()
	return str(current_scene.scene_file_path).get_file().get_basename() if current_scene else "?"


## Is the player boxed in? Try each direction; true if none moves.
func _boxed_in(m: GameMap) -> bool:
	for dname in ["up", "down", "left", "right"]:
		if not is_instance_valid(m) or current_scene != m:
			return false
		var before := m.player.position
		await press(dname, 16)
		await _dialogue_tick()
		if not is_instance_valid(m) or current_scene != m or m.player.position.distance_to(before) > 2.0:
			return false
	return true


func _walk() -> void:
	var dirs := ["up", "down", "left", "right"]
	var dname: String = dirs[rng.randi_range(0, 3)]
	var run := rng.randf() < 0.4
	if run:
		Input.action_press("b")
	await press(dname, rng.randi_range(8, 40))
	if run:
		Input.action_release("b")


func _swing() -> void:
	var slots := [4]  # sword
	GameState.select_slot(slots[0])
	await press("a", 2)
	await frames(rng.randi_range(6, 14))


## Fighter bots (C5 c5_19 #4): walk at the nearest live foe in sight and swing at it.
## False when there's none near (the caller then walks instead).
func _hunt(m: GameMap) -> bool:
	if m.player == null:
		return false
	var best: Enemy = null
	var bd := 170.0
	for e in m.enemies:
		if is_instance_valid(e) and e._alive and e.position.distance_to(m.player.position) < bd:
			best = e
			bd = e.position.distance_to(m.player.position)
	if best == null:
		return false
	GameState.select_slot(4)  # sword / bat
	for i in 14:
		if not is_instance_valid(m) or not is_instance_valid(best) or not best._alive or m.player == null:
			break
		var d := best.position - m.player.position
		if d.length() < 22.0:
			var face := ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up")
			await press(face, 2)
			await press("a", 2)
			await frames(10)
		else:
			await press(("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up"), 8)
		await _dialogue_tick()
	if is_instance_valid(best) and not best._alive:
		kills += 1
	elif not is_instance_valid(best):
		kills += 1
	return true


func _farm_step(m: GameMap) -> void:
	var slot := rng.randi_range(0, 2)
	if rng.randf() < 0.3:
		# hold seeds
		for id in GameState.run["inventory"].keys():
			if str(GameState.items.get(id, {}).get("type", "")) == "seed":
				GameState.run["selected"] = id
				break
	else:
		GameState.run["selected"] = ""
		GameState.select_slot([0, 1, 0][slot])
	await press(["up", "down", "left", "right"][rng.randi_range(0, 3)], 3)
	await press("a", 2)
	await frames(8)


func _random_button() -> void:
	var acts := ["a", "b", "tool", "action"]
	var act: String = acts[rng.randi_range(0, acts.size() - 1)]
	if InputMap.has_action(act):
		var m := current_scene as GameMap
		if m and m.player:
			var fc := m.player.facing_cell()
			_last_press = "%s held=%s at %s facing %s thing=%s" % [act, GameState.held_tool(), str(m.player.cell()), str(fc), str(m.things.get(fc, {})).left(80)]
		await press(act, rng.randi_range(1, 4))
		if paused and not Dialogue.instance(self).active:
			print("BOT PAUSE after ", _last_press)
	if rng.randf() < 0.3:
		GameState.select_slot(rng.randi_range(0, 11))
	await frames(3)


func _menu_crawl(m: GameMap) -> void:
	var menu: GameMenu = null
	for ch in m.get_children():
		if ch is GameMenu:
			menu = ch
	if menu == null:
		return
	await press("menu", 2)
	await frames(4)
	if not is_instance_valid(menu):
		return
	for t in menu._tab_buttons.keys():
		if not is_instance_valid(menu) or not menu.is_inside_tree():
			return  # valid until the queued free: a menu that left the tree is done (c9_10)
		if rng.randf() < 0.6 and is_instance_valid(menu._tab_buttons.get(t)):
			(menu._tab_buttons[t] as Button).pressed.emit()
			await frames(3)
			# press a random button in the body
			if not is_instance_valid(menu) or not menu.is_inside_tree():
				return
			var btns: Array = []
			_collect_buttons(menu._body, btns)
			if not btns.is_empty() and rng.randf() < 0.5:
				var b: BaseButton = btns[rng.randi_range(0, btns.size() - 1)]
				if is_instance_valid(b) and not b.disabled:
					_last_press = "%s > %s" % [t, str(b.get("text"))]
					b.pressed.emit()
					await frames(3)
	if paused and is_instance_valid(menu) and menu._open:
		menu.toggle()
	await frames(4)
	if paused and not Dialogue.instance(self).active:
		# a sub-dialog may have opened; clear it
		await press("menu", 2)
		await frames(3)


var _last_press := ""
var _last_act := ""


func _collect_buttons(n: Node, out: Array) -> void:
	if not is_instance_valid(n):
		return
	for c in n.get_children():
		if c is BaseButton:
			out.append(c)
		_collect_buttons(c, out)


func _tap_world(m: GameMap) -> void:
	if m.player == null:
		return
	var target := m.player.position + Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
	if m.has_method("handle_tap"):
		var screen := m.get_canvas_transform() * target
		m.handle_tap(screen)
	await frames(rng.randi_range(10, 40))


func _sleep_and_roundtrip() -> void:
	var day_before := int(GameState.run["day"])
	var rep := GameState.sleep()
	if int(GameState.run["day"]) != day_before + 1:
		_fail("sleep didn't advance the day (%d -> %d)" % [day_before, int(GameState.run["day"])])
	if typeof(rep) != TYPE_DICTIONARY:
		_fail("sleep report not a dictionary")
	# Save → wipe → load: the run must come back intact (types included).
	var before := JSON.stringify(GameState.run)
	GameState.save()
	var keys_before: Array = GameState.run.keys()
	GameState.run = {}
	if not GameState.has_run():
		_fail("save/load roundtrip lost the run")
		return
	for k in keys_before:
		if not GameState.run.has(k) and str(k) != "story_pending":  # load drops it on purpose: a beat cut off mid-play replays
			_fail("save/load dropped key " + str(k))
	if typeof(GameState.run["day"]) != TYPE_INT and typeof(GameState.run["day"]) != TYPE_FLOAT:
		_fail("day has wrong type after load")
	if JSON.stringify(GameState.run).length() < before.length() * 0.9:
		_warn("run shrank a lot across save/load (%d -> %d chars)" % [before.length(), JSON.stringify(GameState.run).length()])


func _check_invariants(sc: String) -> void:
	var r := GameState.run
	if r.is_empty():
		_fail("run became empty in " + sc)
		return
	if int(r["crystals"]) < 0:
		_fail("crystals negative (%d) in %s" % [int(r["crystals"]), sc])
	if int(r["energy"]) < 0:
		_fail("energy negative (%d) in %s" % [int(r["energy"]), sc])
	if int(r["hp"]) > int(r["max_hp"]) + 1:
		_fail("hp above max (%d/%d)" % [int(r["hp"]), int(r["max_hp"])])
	for id in r["inventory"].keys():
		if int(r["inventory"][id]) < 0:
			_fail("negative count %s=%d in %s" % [id, int(r["inventory"][id]), sc])
		if not GameState.items.has(id):
			_fail("inventory holds unknown item " + str(id))
	for key in r["farm"].keys():
		var t: Variant = r["farm"][key]
		if typeof(t) != TYPE_DICTIONARY:
			_fail("farm tile %s not a dictionary" % key)
		elif str(t.get("crop", "")) != "" and not GameState.crops.has(str(t["crop"])):
			_fail("farm tile %s has unknown crop %s" % [key, str(t["crop"])])
	var m := current_scene as GameMap
	if m and m.player:
		var p := m.player.position
		if is_nan(p.x) or is_nan(p.y):
			_fail("player position NaN in " + sc)


func _fail(what: String) -> void:
	fails += 1
	printerr("BOT FAIL [%d %s] %s" % [seed_, style, what])


func _warn(what: String) -> void:
	warns += 1
	print("BOT WARN [%d %s] %s" % [seed_, style, what])


func press(action: String, hold_frames: int) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)


func frames(n: int) -> void:
	for i in n:
		await process_frame
