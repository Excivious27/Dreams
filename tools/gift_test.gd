extends SceneTree
## Gifts: the Marked and the bosses can't be button-mashed; each has a rule.
##   godot --headless --path . -s res://tools/gift_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	InputSetup.ensure_actions()
	# Data is sound.
	var gd := Gift.data()
	check(gd["marked"].size() == 10, "ten Marked")
	for id: String in gd["marked"]:
		var mk: Dictionary = gd["marked"][id]
		check(int(mk["age"]) >= 15 and int(mk["age"]) <= 30, id + " is 15 to 30")
		check(not Gift.def(str(mk["gift"])).is_empty(), id + " has a gift")
		check(GameState.load_json("res://data/enemies.json")["enemies"].has("marked_" + id), id + " is an enemy")
		check(GameState.load_json("res://data/companions.json")["companions"].has("mk_" + id), id + " can be recruited")
		check(Art.has("characters/" + str(mk["char"]), "idle"), id + " has a sprite")
	for g: String in gd["gifts"]:
		var gg: Dictionary = gd["gifts"][g]
		check(str(gg.get("tip", "")).length() > 20, g + " explains how to beat it")
		check(not (gg.get("moves", []) as Array).is_empty(), g + " has moves")
	for b: String in gd["bosses"]:
		check(not Gift.def(str(gd["bosses"][b])).is_empty(), "boss " + b + " has a gift")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameMap.next_spawn = Vector2(40 * 16, 40 * 16)
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 10:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	for i in 30:
		if d.active:
			Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
	m.player.invuln = 9999.0
	# Volt: nothing lands while she's charged; everything lands in the window.
	var e := Marked.spawn(m, "juno", m.player.position + Vector2(60, 0))
	await process_frame
	check(e._gift != null and e._gift.gid == "volt", "Juno carries the Volt gift")
	var hp0 := e.hp
	e.hit(5, m.player.position)
	check(e.hp == hp0, "a charged Volt can't be hit (hp %d → %d)" % [hp0, e.hp])
	e._gift.open_t = 2.0
	e.hit(5, m.player.position)
	check(e.hp < hp0 - 5, "in the window she takes extra (hp %d → %d)" % [hp0, e.hp])
	# She throws things at you while the fight runs.
	var saw := false
	for i in 500:
		await process_frame
		if not e._gift._lines.is_empty() or not e._gift._bul.is_empty():
			saw = true
			break
	check(saw, "the gift attacks with its own patterns")
	# Beaten, she yields instead of dying; you choose.
	e._gift.open_t = 5.0
	e.hit(9999, m.player.position)
	check(not e._alive and not m.enemies.has(e), "at zero she yields")
	for i in 200:
		if d.active:
			if d._in_choice:
				d._choose("", 0)
			else:
				Input.action_press("a"); await process_frame; Input.action_release("a")
		await process_frame
		if Marked.state("juno") != "":
			break
	check(Marked.state("juno") == "crew", "asked to join, she joins (%s)" % Marked.state("juno"))
	check("mk_juno" in Companion.party()["known"], "and is in the party list")
	for i in 60:
		await process_frame
	# Her gift is yours to borrow.
	Companion.party()["active"] = "mk_juno"
	check(Companion.ability_for(m, m.player) == "gift:volt", "the partner ability is her gift")
	GameState.restore_mana(99)
	# An open line to the right (the Plans board's posts block the spawn row now).
	var pos0 := m.player.position
	var face0 := m.player.facing
	for cy in range(14, 30):
		var open := true
		for dx in range(0, 7):
			if m.blocked.has(Vector2i(13 + dx, cy)):
				open = false
		if open:
			m.player.position = m.cell_center(Vector2i(13, cy))
			m.player.facing = "right"
			break
	var t := m.spawn_enemy("grump", m.player.position + m.player.facing_dir() * 40.0)
	await process_frame
	t.position = m.player.position + m.player.facing_dir() * 40.0
	var th := t.hp
	Companion.use_ability(m, m.player)
	check(not is_instance_valid(t) or not t._alive or t.hp < th, "borrowed Volt hits down the line")
	m.player.position = pos0
	m.player.facing = face0
	# Bramble: front is bark, back is not.
	var b := Marked.spawn(m, "dahlia", m.player.position + Vector2(60, 40))
	await process_frame
	b._gift.face = 1.0
	var bh := b.hp
	b.hit(5, b.position + Vector2(20, 0))
	check(b.hp == bh, "Bramble's front can't be hit")
	b.hit(5, b.position + Vector2(-20, 0))
	check(b.hp < bh, "her back can")
	b.queue_free(); m.enemies.erase(b)
	# Mirror: reflections at 75%.
	var mi := Marked.spawn(m, "tomas", m.player.position + Vector2(-60, 40))
	await process_frame
	mi.hit(int(mi.max_hp * 0.3) + 1, m.player.position)
	for i in 5:
		await process_frame
	var decoys := 0
	for o in m.enemies:
		if is_instance_valid(o) and o.has_meta("decoy"):
			decoys += 1
			check(o._shadow_r == 0.0, "a reflection casts no shadow")
	check(decoys == 2, "Mirror splits into three (%d reflections)" % decoys)
	# A boss has one too, and still dies properly.
	var boss := m.spawn_enemy("golem_king", m.player.position + Vector2(0, -80))
	await process_frame
	check(boss._gift != null, "a boss carries a gift")
	boss._gift.open_t = 5.0
	boss.hit(99999, m.player.position)
	check(not boss._alive, "and can be beaten in its window")
	# The chrome: EMP opens a Gift, a bot fights for you, a scrambler cools heat.
	for o in m.enemies.duplicate():
		if is_instance_valid(o):
			o.queue_free()
	m.enemies.clear()
	check(Crafting.is_station("terminal") and Crafting.is_station("clinic") and Crafting.is_station("robotics"), "three cyber stations exist")
	check(Builds.data().has("terminal"), "and the gangster arc can build them")
	var k := Marked.spawn(m, "bruno", m.player.position + Vector2(30, 0))
	await process_frame
	k._gift.open_t = 0.0
	k._gift._closed_t = 0.0
	GameState.add_item("emp_charge", 1)
	check(m.use_consumable("emp_charge"), "an EMP charge can be used")
	check(k._gift.open_t >= 2.5 and k._stun >= 3.0, "EMP stuns and forces a Gift open (%.1f)" % k._gift.open_t)
	var kh := k.hp
	GameState.add_item("scrap_bot", 1)
	m.use_consumable("scrap_bot")
	for i in 150:
		await process_frame
		k._gift.open_t = 1.0
	check(k.hp < kh, "a deployed bot zaps what is near (hp %d → %d)" % [kh, k.hp])
	GameState.run["heat"] = 3
	GameState.add_item("scrambler", 1)
	m.use_consumable("scrambler")
	check(Racket.heat() == 1, "a scrambler takes two heat off")
	GameState.add_item("spy_drone", 1)
	m.use_consumable("spy_drone")
	check(GameState.count("spy_drone") == 1 and k._gift._told, "the spy drone is kept and reads the Gift")
	print("gift_test: %d failures" % fails)
	quit(1 if fails else 0)
