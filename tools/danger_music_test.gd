extends SceneTree
## Combat music (DangerMusic): calm -> skirmish when a foe engages, kept while
## you run with it on your heels, a grace period after you escape, then the
## area song again; severity tiers (pack, low health, elite, boss), a tier
## drop only after a hold, the meadow's first boss holding its song for the
## whole fight (it used to cut out after a burst), both arcs, and the web
## build (streamed songs: the current song carries on until the combat song
## arrives from a local server).
##   godot --headless --path . --fixed-fps 60 -s res://tools/danger_music_test.gd
var fails := 0
var gt := 0.0
var pid := -1


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(7)
	_run.call_deferred()


func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await process_frame
		var d := root.get_process_delta_time()
		t += d
		gt += d


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Press A through any open dialogue for up to `secs`.
func drain(secs: float) -> void:
	var d := Dialogue.instance(self)
	var t := 0.0
	while t < secs:
		if d.active:
			Input.action_press("a")
			await frames(2)
			Input.action_release("a")
		await wait(0.2)
		t += 0.2


func mu() -> Music:
	return Music.instance(self)


func clear(m: GameMap) -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()


## A foe that stands still where we put it (tests move it by hand).
func foe(m: GameMap, kind: String, off: Vector2, tier := -1) -> Enemy:
	var e := m.spawn_enemy(kind, m.player.position + off, tier)
	e.position = m.player.position + off
	e.speed = 0.0
	e.damage = 0
	return e


func go(arc: String, scene: String) -> GameMap:
	GameState.new_run(arc, "kairi", "Tester", "Dreamhollow", "Pip")
	GameState.run["intro_done"] = true
	for f in ["meadow_seen", "intro_done", "gangsters_intro", "mine_seen"]:
		GameState.run["flags"][f] = true
	GameState.run["time"] = 600
	GameState.run["max_hp"] = 100
	GameState.run["hp"] = 100
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await frames(20)
	var m := current_scene as GameMap
	clear(m)
	m.player.invuln = 9999.0
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	m.player.position = m.cell_center(Vector2i(m.cols / 2, m.rows / 2))
	await wait(4.0)
	return m


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.load_data()
	for arc: String in ["penguins", "gangsters"]:
		await _arc(arc)
	await _meadow_boss("penguins", "boss_penguin")
	await _meadow_boss("gangsters", "boss_gang")
	await _web()
	print("danger_music_test: %d failures" % fails)
	if pid > 0:
		OS.kill(pid)
	quit(1 if fails > 0 else 0)


func _arc(arc: String) -> void:
	print("== ", arc)
	var gang := arc == "gangsters"
	var light := "combat_light_gang" if gang else "combat_light"
	var danger := "raid" if gang else "danger"
	var elite := "combat_elite_gang" if gang else "combat_elite"
	var small := "thug_lookout" if gang else "grump"
	var m: GameMap = await go(arc, "meadow")
	var area := m.area_track()
	check(mu().wanted() == area and DangerMusic.tier == 0, "calm: the area song (%s)" % mu().wanted())
	# A foe that notices you but is far off: nothing.
	var e := foe(m, small, Vector2(200, 0))
	e._noticed = true
	await wait(1.0)
	check(DangerMusic.tier == 0, "a noticed foe far away is not a fight")
	# It hits you / you hit it: skirmish.
	e.position = m.player.position + Vector2(30, 0)
	e.provoke(m.player)
	await wait(0.8)
	check(DangerMusic.tier == 1 and mu().wanted() == light, "engaged: skirmish music (%s)" % mu().wanted())
	# Run away with it on your heels (it keeps 90-130 px behind).
	var flapped := false
	for i in 24:
		m.player.position += Vector2(-4, 0)
		e.position = m.player.position + Vector2(90.0 + 40.0 * float(i % 2), 0)
		e._chase_t = 3.0
		await wait(0.25)
		if DangerMusic.tier == 0 or mu().wanted() != light:
			flapped = true
	check(not flapped, "fleeing while chased keeps the combat music")
	# Outrun it: grace period, then the area song with a slow fade.
	e.position = m.player.position + Vector2(420, 0)
	e._chase_t = 0.0
	e._aggro_t = 0.0
	await wait(DangerMusic.GRACE - 1.5)
	check(mu().wanted() == light, "grace: music holds a few seconds after the escape")
	await wait(2.5)
	check(DangerMusic.tier == 0 and mu().wanted() == area, "escaped: back to the area song (%s)" % mu().wanted())
	# No flapping when a foe hovers at the edge of range.
	var turns := 0
	var was := mu().wanted()
	for i in 40:
		e.position = m.player.position + Vector2(95.0 if i % 2 == 0 else 160.0, 0)
		e._chase_t = 0.0
		e._los_ok = true
		await wait(0.25)
		if mu().wanted() != was:
			turns += 1
			was = mu().wanted()
	check(turns <= 1, "a foe at the edge of range doesn't flap the music (%d changes)" % turns)
	clear(m)
	await wait(DangerMusic.GRACE + 1.0)
	# A pack of four small foes: a dangerous fight.
	for i in 4:
		var p := foe(m, small, Vector2(-40 + 25 * i, 30))
		p.provoke(m.player)
	await wait(0.8)
	check(DangerMusic.tier == 2 and mu().wanted() == danger, "a pack: danger music (%s)" % mu().wanted())
	clear(m)
	await wait(DangerMusic.GRACE + 1.0)
	# One small foe but you're nearly out of health: danger.
	GameState.run["hp"] = 20
	foe(m, small, Vector2(30, 0)).provoke(m.player)
	await wait(0.8)
	check(DangerMusic.tier == 2, "low health in a fight: danger music")
	GameState.run["hp"] = 100
	clear(m)
	await wait(DangerMusic.GRACE + 1.0)
	# An elite: a mine guardian (or a big foe).
	var g := foe(m, small, Vector2(30, 0))
	g.is_guardian = true
	g.provoke(m.player)
	var s := foe(m, small, Vector2(-30, 0))
	s.provoke(m.player)
	await wait(0.8)
	check(DangerMusic.tier == 3 and mu().wanted() == elite, "an elite foe: elite music (%s)" % mu().wanted())
	# The elite falls: the music drops a tier only after a hold.
	g._alive = false
	m.enemies.erase(g)
	g.queue_free()
	await wait(1.5)
	check(DangerMusic.tier == 3, "tier holds right after the elite falls")
	s.provoke(m.player)
	await wait(DangerMusic.DROP_HOLD + 0.5)
	check(DangerMusic.tier == 1 and mu().wanted() == light, "then drops to the skirmish (%s)" % mu().wanted())
	clear(m)
	await wait(DangerMusic.GRACE + 1.0)
	# A boss that walks up (no intro card) gets its theme.
	var bk := "president" if gang else "dark_crystal"
	var b := foe(m, bk, Vector2(60, 0))
	await wait(0.8)
	check(DangerMusic.tier == 4 and mu().wanted() == m.boss_track(bk), "a boss nearby: its theme (%s)" % mu().wanted())
	clear(m)
	await wait(DangerMusic.BOSS_GRACE + 1.0)
	check(mu().wanted() == m.area_track(), "boss gone: back to the area song after the grace (%s)" % mu().wanted())
	# Battlefields keep their own battle moods.
	check(DangerMusic.tier_track(1) == light and DangerMusic.tier_track(3) == elite, "tier tracks per arc")


## The meadow's first boss as the game stages it: the intro card's song must
## last the whole fight (it used to stop after a moment).
func _meadow_boss(arc: String, want: String) -> void:
	print("== meadow boss ", arc)
	var m: GameMap = await go(arc, "meadow")
	GameState.run["meadow_kills"] = 4
	m.call("_summon_boss")
	var d := Dialogue.instance(self)
	var t := 0.0
	while t < 20.0 and (d.active or bool(m.get("_boss_pending"))):
		Input.action_press("a")
		await frames(2)
		Input.action_release("a")
		await wait(0.3)
		t += 0.3
	var boss: Enemy = m.get("_boss")
	check(boss != null and is_instance_valid(boss), "the boss is out")
	if boss == null:
		return
	boss.speed = 0.0
	boss.damage = 0
	boss.position = m.player.position + Vector2(50, 0)
	check(mu().wanted() == want, "boss song starts (%s)" % mu().wanted())
	var held := true
	for i in 60:  # 15 s of fighting, circling, stepping back
		m.player.position = boss.position + Vector2(40.0 + 120.0 * float((i / 8) % 2), 0)
		await wait(0.25)
		if mu().wanted() != want:
			held = false
	check(held, "the boss song holds for the whole fight (%s)" % mu().wanted())
	m.player.position = boss.position + Vector2(8, 0)
	boss.hit(9999, m.player.position)
	await drain(4.0)
	await wait(DangerMusic.BOSS_GRACE + 2.0)
	check(mu().wanted() == m.area_track(), "after the boss: the meadow song (%s)" % mu().wanted())


## Web build: combat songs stream; the area song carries on until one arrives.
func _web() -> void:
	print("== web stream")
	var port := 18000 + randi() % 2000
	var dir := ProjectSettings.globalize_path("res://audio/music")
	pid = OS.create_process("python3", ["-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", dir])
	await wait(1.5)
	for t: String in ["combat_light", "combat_elite", "combat_light_gang", "combat_elite_gang"]:
		check(t in Music._stream_list(), "%s is streamed on the web" % t)
		check(Music.has_track(t), "%s exists (has_track)" % t)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mcache/%s.ogg" % t))
	var m: GameMap = await go("penguins", "meadow")
	Music.force_stream = true
	Music.stream_base = "http://127.0.0.1:%d/" % port
	mu()._streamed.erase("combat_light")
	var before := mu().now_playing()
	foe(m, "grump", Vector2(30, 0)).provoke(m.player)
	await wait(0.6)
	check(mu().wanted() == "combat_light", "web: combat song wanted (%s)" % mu().wanted())
	check(mu().now_playing() != "", "web: music never stops while it downloads (%s, was %s)" % [mu().now_playing(), before])
	var t := 0.0
	while t < 15.0 and mu().now_playing() != "combat_light":
		await wait(0.2)
		t += 0.2
	check(mu().now_playing() == "combat_light", "web: the combat song arrives and takes over (%s)" % mu().now_playing())
	clear(m)
	await wait(DangerMusic.GRACE + 1.0)
	check(mu().wanted() == m.area_track(), "web: back to the area song (%s)" % mu().wanted())
	Music.force_stream = false
	Music.stream_base = ""
