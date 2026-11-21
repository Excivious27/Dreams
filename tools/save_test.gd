extends SceneTree
## Saves for a new player (CONDUCT 1): first run with no save (settings defaults,
## title), a new game in each of the three slots (both arcs), the opening's Skip,
## save + "reopen the app" at every early milestone (intro done, first planting,
## first town visit, a shop interior, first sleep, a story beat cut off), slot
## isolation, a corrupt save file, and an old pre-Round-13 save migrating into
## the arcade / community farm / mega region / campaign gate systems.
##   godot --headless --path . -s res://tools/save_test.gd
var fails := 0
var checks := 0
var shot_dir := ""  # pass a dir (under xvfb) for a picture of the opening with its Skip button


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true  # the test walks the farm/town roads; gates are checked by hand below
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## "Close the app and open it again": nothing in memory, the save file read fresh.
func reboot() -> void:
	GameState.run = {}
	SaveGame.reset_cache()
	GameState.has_run()


func _wipe_saves() -> void:
	SaveGame.reset_cache()
	var d := DirAccess.open("user://")
	if d:
		for f in d.get_files():
			if f.begins_with("save"):
				d.remove(f)
	SaveGame.reset_cache()
	SaveGame._blocked = false


func _set_scene(n: Node) -> void:
	var old := current_scene
	root.add_child(n)
	current_scene = n
	if old and is_instance_valid(old):
		old.queue_free()


func load_map(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	var m: Node = (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate()
	_set_scene(m)
	await frames(8)
	return m as GameMap


## Reopen through the real title screen: Continue -> whatever _start_game picks.
func boot_via_title() -> GameMap:
	reboot()
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	_set_scene(t)
	await frames(3)
	check(_has_button(t, "Continue as "), "title offers Continue after a save")
	t.call("_start_game")
	for i in 120:
		await frames(1)
		if current_scene is GameMap and (current_scene as GameMap).player != null:
			break
	await frames(6)
	return current_scene as GameMap


func _buttons(n: Node, out: Array) -> Array:
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_buttons(c, out)
	return out


func _has_button(n: Node, prefix: String) -> bool:
	for t in _buttons(n, []):
		if str(t).begins_with(prefix):
			return true
	return false


## Plays the opening on the farm. skip: press Skip first. Returns the narration
## lines that were shown (choices excluded).
func play_intro(skip: bool, pick: int) -> Array:
	var d := Dialogue.instance(self)
	var shown: Array = []
	for i in 120:
		await frames(1)
		if d.active:
			break
	check(d.active and d.skippable, "the opening starts on a new farm and offers Skip")
	await frames(2)
	check(d._skip_btn.visible, "the Skip button shows during the opening")
	if shot_dir != "" and not skip:
		await frames(30)
		root.get_texture().get_image().save_png(shot_dir + "/opening_skip.png")
	if skip:
		d.skip()
	var last := ""
	var picked := false
	for i in 1500:
		await frames(1)
		if bool(GameState.run.get("intro_done", false)) and not d.active:
			break
		if not d.active:
			continue
		if d._in_choice:
			if Engine.get_process_frames() - d._choice_opened > 14:
				(d._choices.get_child(mini(pick, d._choices.get_child_count() - 1)) as Button).pressed.emit()
				picked = true
			continue
		if d._full != last:
			last = d._full
			shown.append(last)
		if i % 3 == 0:
			d._advance()
	await frames(4)
	check(picked, "the opening's choice was asked (skip=%s)" % str(skip))
	check(bool(GameState.run["intro_done"]), "intro_done after the opening (skip=%s)" % str(skip))
	check(not d.skippable and not d._skip_btn.visible, "Skip is gone once the opening ends")
	return shown


func _run() -> void:
	InputSetup.ensure_actions()
	if OS.get_cmdline_user_args().size() > 0:
		shot_dir = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(shot_dir)
	_wipe_saves()
	await _first_run()
	await _slots_and_intro()
	await _milestones(1, "penguins")
	await _milestones(2, "gangsters")
	_corrupt_file()
	_battlefield_save()
	await _migration()
	print("save_test: %d checks, %d failures" % [checks, fails])
	quit()


# ---- first run -----------------------------------------------------------------

func _first_run() -> void:
	check(not GameState.has_run(), "first run: no game")
	check(GameState.slot() == 1, "first run: slot 1")
	for n in [1, 2, 3]:
		check(GameState.slot_info(n) == "Empty", "first run: slot %d empty" % n)
	for k: String in Settings.DEFAULTS:
		check(Settings.get_v(k) == Settings.DEFAULTS[k], "first run: setting %s is its default" % k)
	check(not Settings.DEFAULTS.has("easy") and is_equal_approx(Settings.night_strength(), 1.0) and is_equal_approx(Settings.btn_scale(), 1.0), "first run: normal mode, full nights, normal buttons")
	Settings.apply_audio()
	var mi := AudioServer.get_bus_index("Music")
	check(mi >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(mi), Settings._db(int(Settings.DEFAULTS["music_vol"]))) and not AudioServer.is_bus_mute(mi), "first run: music bus at the default volume")
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	_set_scene(t)
	await frames(3)
	check(_has_button(t, "New game") and not _has_button(t, "Continue") and not _has_button(t, "Restore"), "first run title: New game, no Continue/Restore (%s)" % str(_buttons(t, [])))
	check(not FileAccess.file_exists("user://save.json") or GameState.slot_info(1) == "Empty", "first run: opening the title made no game")
	# Settings are global: set one, start a game in a slot, it stays.
	Settings.set_v("sfx_vol", 5)


# ---- slots + the opening -------------------------------------------------------

const SLOTS := [[1, "penguins", "kairi", "Ann"], [2, "gangsters", "dad", "Bob"], [3, "penguins", "custom", "Cy"]]


func _slots_and_intro() -> void:
	var counts := {}
	for s in SLOTS:
		var n: int = s[0]
		GameState.use_slot(n)
		check(not GameState.has_run(), "slot %d starts empty" % n)
		GameState.new_run(str(s[1]), str(s[2]), str(s[3]), "Town" + str(n), "Pup" + str(n), {"difficulty": n - 1, "day_len": GameState.DAY_LENGTHS[n]})
		if str(s[2]) == "custom":
			GameState.run["look"] = {"tint": "ffffff", "outfit": "outfit_farmer"}
		GameState.save()
		check(GameState.slot_info(n).begins_with(str(s[3])), "slot %d lists the new game (%s)" % [n, GameState.slot_info(n)])
		await load_map("farm")
		var shown := await play_intro(n != 1, 1)
		counts[n] = shown.size()
		var kept := false
		for l: String in shown:
			if l.contains("USE"):
				kept = true
		check(kept, "slot %d: the how-to-play line still shows (skip=%s)" % [n, str(n != 1)])
		check((GameState.run["quests"] as Array).size() >= 2, "slot %d: opening quests given" % n)
		var key := "crystal_answer" if str(s[1]) == "penguins" else "letter"
		check(int(GameState.run["decisions"].get(key, -1)) == 1, "slot %d: the opening's answer is kept" % n)
		check(str(s[1]) != "gangsters" or str(GameState.run["flags"].get("letter", "")) == "kept", "gangster opening: the letter answer sets its flag")
		reboot()
		check(bool(GameState.run.get("intro_done", false)) and str(GameState.run["names"]["character"]) == str(s[3]), "slot %d: the opening is saved" % n)
		check(Settings.get_v("sfx_vol") == 5, "slot %d: settings are shared, not per slot" % n)
		check(Difficulty.level() == n - 1 and GameState.day_len() == int(GameState.DAY_LENGTHS[n]), "slot %d: difficulty and day length are kept per slot (%s, %d)" % [n, Difficulty.name_of(), GameState.day_len()])
		check(GameState.slot_info(n).contains(Difficulty.name_of(n - 1)) and GameState.slot_info(n).contains("%d-min" % int(GameState.DAY_LENGTHS[n])), "slot %d info shows mode and day length (%s)" % [n, GameState.slot_info(n)])
	check(int(counts.get(2, 99)) <= 3 and int(counts.get(3, 99)) <= 3 and int(counts.get(1, 0)) >= 6, "Skip drops the narration (full %d lines, skipped %d / %d)" % [int(counts.get(1, 0)), int(counts.get(2, 0)), int(counts.get(3, 0))])
	for s in SLOTS:
		GameState.use_slot(int(s[0]))
		check(GameState.has_run() and str(GameState.run["names"]["character"]) == str(s[3]) and str(GameState.run["arc"]) == str(s[1]), "slot %d keeps its own game" % int(s[0]))
	# A new game over slot 1 sends the old farm to Restore (title._begin does this).
	GameState.use_slot(1)
	check(SaveGame.get_value(GameState.prev_key(), null) == null, "slot 1 has nothing to restore yet")
	Settings.set_v("sfx_vol", 8)


# ---- early milestones ----------------------------------------------------------

func _milestones(n: int, arc: String) -> void:
	GameState.use_slot(n)
	check(GameState.has_run() and str(GameState.run["arc"]) == arc, "%s: slot %d loads" % [arc, n])
	# 1. Opening done: reopening goes to the farm and doesn't replay it.
	var farm := await boot_via_title()
	check(farm != null and farm.scene_id() == "farm", "%s: Continue after the opening lands on the farm" % arc)
	await frames(20)
	check(not Dialogue.instance(self).active, "%s: the opening doesn't replay" % arc)
	# 2. First planting, then the phone hides the app.
	var p: Player = farm.player
	var fc := Vector2i(-1, -1)
	for y in range(10, 20):
		for x in range(12, 26):
			if fc.x < 0 and farm._tillable(Vector2i(x, y)) and not farm.blocked.has(Vector2i(x, y + 1)):
				fc = Vector2i(x, y)
	check(fc.x >= 0, "%s: an open patch to till" % arc)
	var key := "%d,%d" % [fc.x, fc.y]
	GameState.run["farm"][key] = {"crop": "turnip", "days": 0, "watered": true}
	GameState.add_item("turnip_seed", -1)
	p.position = farm.cell_center(fc + Vector2i(0, 1))
	p.facing = "up"
	var seeds := GameState.count("turnip_seed")
	farm._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	farm = await boot_via_title()
	check(farm != null and farm.scene_id() == "farm", "%s: reopened on the farm after planting" % arc)
	check(str(GameState.run["farm"].get(key, {}).get("crop", "")) == "turnip" and bool(GameState.run["farm"][key].get("watered", false)), "%s: the planted, watered tile is saved" % arc)
	check(GameState.count("turnip_seed") == seeds, "%s: seed count saved" % arc)
	check(farm.player.position.distance_to(farm.cell_center(fc + Vector2i(0, 1))) < 2.0, "%s: reopens where you stood (%s vs %s)" % [arc, str(farm.player.position), str(farm.cell_center(fc + Vector2i(0, 1)))])
	# 3. First trip to town (saved on the way, as if closed mid-fade, then on arrival).
	var ex: Dictionary = {}
	for e in farm.exits:
		if str(e["scene"]) == "town":
			ex = e
	check(not ex.is_empty(), "%s: farm has a road to town" % arc)
	farm.go_to("town", ex["spawn"], str(ex["facing"]))
	await frames(2)
	reboot()
	check(str(GameState.run["scene"]) == "town", "%s: closing mid-fade resumes in town" % arc)
	for i in 120:
		await frames(1)
		if current_scene is GameMap and (current_scene as GameMap).scene_id() == "town":
			break
	var town := current_scene as GameMap
	check(town != null and town.scene_id() == "town", "%s: arrived in town" % arc)
	await frames(20)
	_close_dialogue()
	await frames(10)
	_close_dialogue()
	town.save_here()
	var stand := town.player.position
	town = await boot_via_title()
	check(town != null and town.scene_id() == "town" and town.player.position.distance_to(stand) < 2.0, "%s: reopened in town where you stood" % arc)
	await frames(20)
	_close_dialogue()
	# 4. Inside the general store.
	GameMap.next_interior = "store"
	town.go_to("interior", Vector2.ZERO, "up")
	for i in 120:
		await frames(1)
		if current_scene is GameMap and (current_scene as GameMap).scene_id() == "interior":
			break
	await frames(10)
	_close_dialogue()
	var ins := await boot_via_title()
	check(ins != null and ins.scene_id() == "interior" and str(ins.get("interior_id")) == "store", "%s: reopened inside the store (%s)" % [arc, str(ins.get("interior_id")) if ins else "none"])
	await frames(10)
	_close_dialogue()
	# 5. First sleep: back home, bed, next morning saved.
	var house := await load_map("house")
	await frames(10)
	_close_dialogue()
	var day0 := int(GameState.run["day"])
	house.call("_sleep")
	var d := Dialogue.instance(self)
	for i in 600:
		await frames(1)
		if d.active and i % 4 == 0:
			if d._in_choice:
				if Engine.get_process_frames() - d._choice_opened > 14:
					(d._choices.get_child(d._choices.get_child_count() - 1) as Button).pressed.emit()
			else:
				d._advance()
		if int(GameState.run["day"]) > day0 and not d.active and not house._changing:
			break
	await frames(10)
	_close_dialogue()
	reboot()
	check(int(GameState.run["day"]) == day0 + 1, "%s: the night's sleep is saved (day %d)" % [arc, int(GameState.run["day"])])
	check(int(GameState.run["farm"].get(key, {}).get("days", 0)) == 1, "%s: the watered crop grew and that's saved" % arc)
	check(int(GameState.run["time"]) == GameState.DAY_START, "%s: the morning starts at 6:00" % arc)
	var h2 := await boot_via_title()
	check(h2 != null and h2.scene_id() == "house", "%s: reopened at home after sleeping (%s)" % [arc, h2.scene_id() if h2 else "none"])
	await frames(10)
	_close_dialogue()
	# 6. A story scene cut off by closing the app plays again from the start.
	GameState.run["story_pending"] = "test_beat"
	GameState.run["flags"]["st_test_beat"] = true
	GameState.save()
	reboot()
	check(not GameState.run.has("story_pending") and not GameState.run["flags"].has("st_test_beat"), "%s: a cut-off story scene will play again" % arc)
	GameState.save()


func _close_dialogue() -> void:
	var d := Dialogue.instance(self)
	var guard := 0
	while d.active and guard < 80:
		guard += 1
		if d._in_choice:
			(d._choices.get_child(d._choices.get_child_count() - 1) as Button).pressed.emit()
		else:
			d._typing = false
			d._next()


# ---- a corrupt file -------------------------------------------------------------

func _corrupt_file() -> void:
	GameState.use_slot(1)
	GameState.has_run()
	var nm := str(GameState.run["names"]["character"])
	GameState.save()
	GameState.save()  # the backup now holds a good copy too
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string("{\"run\": {\"names\": ")  # cut off mid-write
	f.close()
	reboot()
	check(GameState.has_run() and str(GameState.run["names"]["character"]) == nm, "a cut-off save file falls back to the backup")
	check(FileAccess.file_exists("user://save.bad.json"), "the cut-off file is kept aside")


## C3 F1/F2: a save on a battlefield with no fight under way reopens where the
## fight was launched from (or the farm), never a free battle.
func _battlefield_save() -> void:
	GameState.use_slot(1)
	GameState.has_run()
	Campaign.st()["fight"] = {"cid": "nope", "nid": "n1", "field": "bf_orchard", "day": 1, "back": ["town", 320.0, 200.0]}
	GameState.run["scene"] = "bf_orchard"
	GameState.save()
	reboot()
	check(str(GameState.run["scene"]) == "town" and (GameState.run["spawn"] as Array).size() >= 2 and float(GameState.run["spawn"][0]) == 320.0, "battlefield save without a fight reopens at the launch spot (%s)" % str(GameState.run["scene"]))
	check((Campaign.st().get("fight", {}) as Dictionary).is_empty(), "the stale fight record is dropped")
	GameState.run["scene"] = "bf_orchard"
	GameState.save()
	reboot()
	check(str(GameState.run["scene"]) == "farm", "no launch spot: back to the farm")


## C11a: the old farm's animals became roster records (same count the old farm drew, streaks -> friendship).
func _ranch_migrated() -> void:
	var cow := Ranch.uid_of_legacy("cow_brown_33_7")
	check(Ranch.roster("coop").size() == 9 and Ranch.roster("barn").size() == 5, "old save: coop 8 + 1 hatched, barn 5 (%d, %d)" % [Ranch.roster("coop").size(), Ranch.roster("barn").size()])
	check(cow != "" and int(Ranch.animal(cow)["friend"]) == 650 and int(Ranch.animal(cow)["last_pet"]) == 29, "old save: the cow's 13-day streak is friendship 650")
	check(Ranch.uid_of_legacy("cow_bw_31_8") != "" and int(Ranch.animal(Ranch.uid_of_legacy("cow_bw_31_8"))["friend"]) == 150, "old save: a moved spawn key keeps its streak")
	check((Ranch.house("coop")["incubator"] as Array).size() == 1 and not GameState.run.has("coop_hatch"), "old save: the warming egg is in the incubator, coop_hatch gone")
	check(not Ranch.is_adult(Ranch.uid_of_legacy("calf_35_7")) and Ranch.is_adult(Ranch.uid_of_legacy("chick_28_11")), "old save: the calf is still young, the chick grew up")
	check(not (GameState.run["flags"] as Dictionary).has("hatch_peep_20") and int(GameState.run.get("save_ver", 0)) == GameState.SAVE_VERSION, "old save: hatch flags dropped, save version current")
	check(SleepReport.extra_lines().is_empty(), "old save: no every-morning missed-pet nag")
	check((GameState.run["skills"] as Dictionary).has("ranching") and (GameState.run["flags"] as Dictionary).has("ranch_seeded"), "old save with animals: Ranching seeded once")


# ---- an old save meets Round 13 ---------------------------------------------------

func _migration() -> void:
	# An old gangster save from before Round 13: tickets loose on the run, no
	# arcade / cfarm / mega / campaign blocks, an older energy bar and skill trees,
	# an 8-slot toolbar, and a campaign region already walked into.
	GameState.use_slot(3)
	GameState.new_run("gangsters", "dad", "Old", "Oldtown", "Rex")
	var r: Dictionary = GameState.run
	for k in ["arcade", "cfarm", "mega", "campaign", "en_ver", "skill_ver", "equip", "hp_scale", "opts", "day_len", "coll"]:
		r.erase(k)
	r["toolbar"] = ["hoe", "can", "axe", "pickaxe", "sword", "rod", "", ""]
	r["tickets"] = 7
	r["day"] = 30
	r["intro_done"] = true
	r["max_energy"] = 100
	r["energy"] = 40
	# C10a: a v9 save kept Rec prize decor in the bag and a chest, and had no run.decor.
	r.erase("decor")
	r["save_ver"] = 9
	r["inventory"]["rp_jukebox"] = 1
	r["chests"] = {"chest": {"items": {"rp_trophy_bronze": 1}}}
	r["coll"] = {"decor": {"shipper_ribbon": true}}  # C10b: a C9 milestone keepsake drawn at its old house spot
	var visited_reg := ""
	var other_reg := ""
	var started_cid := ""
	for cid: String in Campaign.all():
		var c: Dictionary = Campaign.all()[cid]
		if str(c.get("arc", "both")) not in ["both", "gangsters"]:
			continue
		if visited_reg == "":
			visited_reg = str(c["region"])
			started_cid = cid
		elif other_reg == "" and str(c["region"]) != visited_reg:
			other_reg = str(c["region"])
	check(visited_reg != "" and other_reg != "", "two gangster campaign regions to test with")
	r["visited"] = {"town": true, visited_reg: true}
	# C11a: a pre-ranch farm: Big Coop + Barn, animals keyed by node name, incubator days, kid flags.
	r.erase("ranch")
	r["builds"] = {"coop": 2, "barn": 1}
	r["animals"] = {"cow_brown_33_7": {"streak": 13, "last_pet": 29, "fed": 29, "made": 29}, "cow_bw_36_8": {"streak": 3, "last_pet": 20, "fed": 20}}
	r["coop_hatch"] = [31, 20]
	r["flags"]["coop_day"] = 2
	r["flags"]["barn_day"] = 27
	r["flags"]["hatch_peep_20"] = true
	var old := r.duplicate(true)
	SaveGame.set_value(GameState.save_key(), old)
	SaveGame.set_value("set_easy", true)  # the old global Easy switch was on
	GameState.run = {}
	reboot()
	check(Difficulty.level() == 1 and GameState.day_len() == 15, "old save: the global Easy switch becomes this slot's Easy mode, day length 15 (%d, %d)" % [Difficulty.level(), GameState.day_len()])
	SaveGame.set_value("set_easy", false)
	check(GameState.has_run() and str(GameState.run["names"]["character"]) == "Old", "the old save loads")
	check((GameState.run["toolbar"] as Array).size() == 12, "old toolbar grows to 12 slots")
	check(int(GameState.run.get("en_ver", 0)) == 11 and int(GameState.run["max_energy"]) > 100 and int(GameState.run["energy"]) > 40, "old energy bar becomes the Round 11 bar with its new room filled")
	check(GameState.run.get("equip") is Dictionary and int(GameState.run.get("skill_ver", 0)) == GameState.SKILL_VER, "old save gets equipment slots and the skill tree version")
	# Arcade: the loose tickets move into run["arcade"].
	check(Tickets.count() == 7 and not GameState.run.has("tickets") and GameState.run["arcade"] is Dictionary, "old tickets move into run[\"arcade\"] (%d)" % Tickets.count())
	check(Tickets.best_score("bowling") == 0, "arcade bests start at zero")
	Tickets.add(3, "test")
	check(Tickets.count() == 10, "tickets add after the move")
	# Decor (C10a): bag/chest decor moved into the decor box, still counted, save version bumped.
	check(GameState.run.get("decor") is Dictionary and int(GameState.run.get("save_ver", 0)) == GameState.SAVE_VERSION, "old save gets run.decor and the new save version")
	check(not (GameState.run["inventory"] as Dictionary).has("rp_jukebox") and Decor.owned("rp_jukebox") == 1 and GameState.count("rp_jukebox") == 1, "bag decor moves to the decor box and still counts")
	check(Decor.owned("rp_trophy_bronze") == 1, "chest decor moves to the decor box")
	check(Decor.total("dc_shipper_ribbon") == 1 and int(Decor.st().get("mig", 0)) == Decor.MIGRATION and Decor.st()["exterior"] is Dictionary, "C10b: old keepsake kept in the house, decor migration 2, exterior block")
	# Collections (C8 P3): run.coll made on load, shipping starts empty.
	check(GameState.run.get("coll") is Dictionary and Collections.count("shipping") == 0, "old save gets run.coll")
	# Community farm: starts fresh, not yet known.
	check(Commons.stage() == 0 and not Commons.known() and GameState.run["cfarm"] is Dictionary, "community farm starts at stage 0 for an old save")
	check((Commons.st()["plots"] as Dictionary).is_empty() and Commons.st().has("stock"), "community farm block has its fields")
	# Mega regions: the Valley is home; nothing far away opened by itself.
	var ms := MegaRegion.st()
	check(GameState.run["mega"] is Dictionary and ms["unlocked"] is Dictionary, "run[\"mega\"] made for the old save")
	var opened: Array = []
	for id: String in MegaRegion.ids():
		if MegaRegion.is_unlocked(id) and not MegaRegion.condition_met(id) and not MegaRegion._any_seen(id):
			opened.append(id)
	check(opened.is_empty(), "no mega region opens without its condition (%s)" % str(opened))
	# Campaign gate: the region already walked into stays open; one never seen is held.
	Campaign.bypass = false
	check(GameState.run.get("campaign") == null or GameState.run["campaign"] is Dictionary, "campaign block absent or well formed before first use")
	check(Campaign.region_open(visited_reg), "a campaign region the old save had visited stays open (%s)" % visited_reg)
	var other_cid := Campaign.gate_of(other_reg)
	check(other_cid == "" or not Campaign.region_open(other_reg), "a campaign region never visited is held (%s)" % other_reg)
	check(not CampaignGate.trained(), "an old save with no campaign under way still needs the drill")
	# An old save that already had a campaign under way counts as trained and isn't re-locked.
	var cs := Campaign.cs(started_cid)
	cs["wins"] = 1
	cs["taken"]["n1"] = true
	check(CampaignGate.trained() and Campaign.started(started_cid), "a campaign already under way counts as trained")
	Campaign.bypass = true
	# Round trip: everything above survives a save + reopen, and migrating twice changes nothing.
	_ranch_migrated()
	GameState.save()
	reboot()
	var once := JSON.stringify(GameState.run, "", true)
	check(Tickets.count() == 10 and GameState.run["cfarm"] is Dictionary and GameState.run["mega"] is Dictionary and GameState.run["campaign"] is Dictionary, "Round 13 blocks are saved with the old game")
	check(CampaignGate.trained(), "trained survives the reopen")
	GameState._migrate()
	Tickets._st(); Commons.st(); MegaRegion.st(); Campaign.st()
	check(JSON.stringify(GameState.run, "", true) == once, "migrating twice changes nothing")
	# And the old save plays: farm and town load with it.
	var farm := await load_map("farm")
	check(farm != null and farm.player != null and not bool(Dialogue.instance(self).skippable), "the old save's farm loads (no opening)")
	await frames(10)
	_close_dialogue()
	var town := await load_map("town")
	check(town != null and town.player != null, "the old save's town loads")
	await frames(10)
	_close_dialogue()
	GameState.save()
	_set_scene(Node.new())
	await frames(3)
