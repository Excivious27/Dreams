extends SceneTree
## The community farm (Commons): every stage of the quest line in both arcs,
## forcing the requirements, checking what changes on the map, the volunteer
## schedule, overnight growth and harvest, the stand, saves, town hooks.
##   godot --headless --path . -s res://tools/commons_test.gd
## With a display and an output dir it also saves before/after screenshots:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/commons_test.gd -- /tmp/shots
var fails := 0
var shots := ""
var arcs_done := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true  # tests walk into every region
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Click through whatever dialogue is open (choices pick "Leave"/last).
func _drain() -> void:
	var d := Dialogue.instance(self)
	for k in 40:
		if not d.active:
			await _frames(2)
			if not d.active:
				return
		d._advance()
		await _frames(2)


func _load(spawn: Vector2) -> GameMap:
	GameMap.next_spawn = spawn
	change_scene_to_file("res://scenes/community_farm.tscn")
	await _frames(12)
	await _drain()
	return current_scene as GameMap


func _wait_reload(old: Node) -> GameMap:
	var d := Dialogue.instance(self)
	for i in 400:
		await process_frame
		if d.active and i % 3 == 0:
			d._advance()
		if current_scene != null and current_scene != old and current_scene is GameMap:
			break
	await _frames(10)
	await _drain()
	return current_scene as GameMap


func _shot(m: GameMap, name: String, at: Vector2i) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	m.player.position = m.cell_center(at)
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func _count(m: GameMap, kind: String) -> int:
	var n := 0
	for c in m.things:
		if str(m.things[c].get("type", "")) == kind:
			n += 1
	return n


## Give exactly what a stage asks for ("#veg" etc. as real items).
func _give_needs() -> void:
	var stand_in := {"#seed": ["turnip_seed", "carrot_seed", "potato_seed"], "#veg": ["turnip"], "#fruit": ["strawberry"], "#flower": ["sunflower"]}
	for k: String in Commons.needs():
		var n := int(Commons.needs()[k])
		if stand_in.has(k):
			var ids: Array = stand_in[k]
			for i in ids.size():
				GameState.add_item(str(ids[i]), n / ids.size() + (1 if i < n % ids.size() else 0), true)
		else:
			GameState.add_item(k, n, true)


func _run() -> void:
	shots = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	InputSetup.ensure_actions()
	await _early()
	for arc in ["penguins", "gangsters"]:
		await _arc(arc)
	check(arcs_done == 2, "both arcs ran to the end (%d)" % arcs_done)
	await _extras()
	print("commons_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Walking west on day 1, before Hazel's letter: she's there on her morning
## schedule to greet you (the visit itself makes the place known).
func _early() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene"]:
		GameState.run["flags"][f] = true
	GameState.run["day"] = 1
	GameState.run["time"] = 7 * 60
	var m := await _load(Vector2.ZERO)
	var hz := false
	for n in m.npcs:
		hz = hz or ((n as Npc).id == "hazel" and (n as Npc).visible)
	check(hz, "[early] Hazel is at the lot on a day-1 visit")
	check(Commons.known() and GameState.run["flags"].has("cf_met"), "[early] the first visit introduces Hazel")
	check(GameState.has_quest(Commons.QUEST), "[early] the first visit starts the farm quest")
	var mails := Mail.list().size()
	GameState.run["day"] = 3
	Commons.overnight({})
	check(Mail.list().size() == mails, "[early] no invitation letter after meeting her")


func _arc(arc: String) -> void:
	var tag := arc.left(3)
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "gangsters_intro"]:
		GameState.run["flags"][f] = true
	GameState.run["weather"] = {}
	for d in range(1, 120):
		GameState.run["weather"][str(d)] = "clear"
	GameState.run["day"] = 3
	GameState.run["time"] = 7 * 60
	# Before the letter nobody volunteers; the letter makes it known and starts the quest.
	check(Commons.slot("hazel", 7.0) == "", "[%s] no volunteers before the farm is known" % tag)
	Commons.overnight({})
	check(Commons.known() and GameState.has_quest(Commons.QUEST), "[%s] Hazel's letter: known + quest" % tag)
	check(Commons.slot("hazel", 7.0) == "cf_lot", "[%s] Hazel clears the lot at 7am (got %s)" % [tag, Commons.slot("hazel", 7.0)])
	check(Npc.place_now(GameState.npcs["hazel"]["routine"], "hazel") == "cf_lot", "[%s] place_now sends Hazel to the farm" % tag)
	check(Commons.slot("benno", 18.5) == "", "[%s] Benno waits for the well" % tag)
	check(not Commons.talk_pool("maple").is_empty(), "[%s] villagers talk about the farm" % tag)
	var rc := {}
	for r: Dictionary in GameState.load_json("res://data/recipes.json")["kitchen"]:
		if str(r["id"]) == "commons_stew":
			rc = r
	check(Crafting.why_locked("kitchen", 5, rc) != "", "[%s] stew recipe locked before the seeds stage" % tag)

	# Town: the west road and Hazel away at the farm.
	GameMap.next_spawn = Vector2(4 * 16, 47 * 16 + 8)
	change_scene_to_file("res://scenes/town.tscn")
	await _frames(14)
	await _drain()
	var town := current_scene as GameMap
	var ex := false
	for e in town.exits:
		ex = ex or str(e["scene"]) == Commons.SCENE
	check(ex, "[%s] town has the west exit" % tag)
	for n in town.get("npcs"):
		if (n as Npc).id == "hazel":
			check(not (n as Npc).visible, "[%s] Hazel isn't in town while she volunteers" % tag)

	# Stage 0: the lot.
	var m := await _load(Vector2.ZERO)
	check(m != null and m.scene_id() == Commons.SCENE, "[%s] community farm loads" % tag)
	var deb := _count(m, "cf_debris")
	check(deb == 14 and int(Commons.st()["debris_left"]) == 14, "[%s] 14 piles of debris (%d)" % [tag, deb])
	var hz := false
	for n in m.npcs:
		if (n as Npc).id == "hazel" and (n as Npc).visible:
			hz = true
	check(hz, "[%s] Hazel is at the farm at 7am" % tag)
	check(GameState.run["flags"].has("cf_met"), "[%s] met Hazel on arrival" % tag)
	await _shot(m, "%s_0_lot" % tag, Vector2i(16, 20))
	await _shot(m, "%s_0_shed_well" % tag, Vector2i(27, 13))
	for c in m.things.keys():
		var t: Dictionary = m.things[c]
		if str(t.get("type", "")) == "cf_debris":
			t["kind"] = "bramble" if not GameState.is_penguins() or true else t["kind"]  # hands only: forcing the tools
			t["hp"] = 1
	var stage_before := Commons.stage()
	for c in m.things.keys():
		if m.things.has(c) and str(m.things[c].get("type", "")) == "cf_debris":
			m._clear_debris(c, m.things[c])
	check(_count(m, "cf_debris") == 0, "[%s] all debris cleared" % tag)
	m = await _wait_reload(m)
	check(Commons.stage() == stage_before + 1, "[%s] lot cleared -> stage 1 (%d)" % [tag, Commons.stage()])
	check(_count(m, "cf_debris") == 0, "[%s] no debris after reload" % tag)
	await _shot(m, "%s_1_cleared" % tag, Vector2i(16, 20))

	# Stages 1..7 through the board's bundles.
	var expect := {2: "cf_share", 3: "cf_plot", 5: "cf_well", 7: "cf_greenhouse", 8: "cf_stand"}
	var cam := {2: Vector2i(28, 12), 3: Vector2i(14, 20), 4: Vector2i(14, 20), 5: Vector2i(28, 21), 6: Vector2i(20, 32), 7: Vector2i(39, 15), 8: Vector2i(40, 28)}
	while not Commons.complete():
		var s := Commons.stage()
		_give_needs()
		var put := Commons.contribute()
		check(put > 0 and Commons.stage_ready(), "[%s] stage %d bundle filled (%d items, %s)" % [tag, s, put, str(Commons.need_lines())])
		if not Commons.stage_ready():
			return
		if s == 3:
			await _shot(m, "%s_3_before_seeds" % tag, Vector2i(14, 20))
		if Commons.is_build(s):
			# A building stage: the crew raises it overnight.
			Commons.bundle_full(m)
			m = await _wait_reload(m)
			check(Commons.pending() == s and Commons.stage() == s, "[%s] stage %d waits for the night (pending %d)" % [tag, s, Commons.pending()])
			check(Commons.contribute() == 0 and not Commons.stage_ready(), "[%s] stage %d: the board takes nothing more tonight" % [tag, s])
			var site := 0
			for c in m.props:
				if is_instance_valid(m.props[c]) and str((m.props[c] as Sprite2D).texture.resource_path).contains("cf_site_"):
					site += 1
			check(site > 0, "[%s] stage %d: build site on the map (%d)" % [tag, s, site])
			var jt := ""
			for q in GameState.run["quests"]:
				if str(q["id"]) == Commons.QUEST:
					jt = str(q["text"])
			check(jt.contains("tonight") and jt.contains("nights of work"), "[%s] journal says the crew starts tonight (%s)" % [tag, jt])
			await _shot(m, "%s_%d_site" % [tag, s], cam.get(s + 1, Vector2i(28, 20)))
			var rep := {}
			# Multi-day builds (Guide 26 #2): every night but the last is progress.
			var nd := Commons.build_days(s)
			check(nd >= 2, "[%s] stage %d takes a few nights (%d)" % [tag, s, nd])
			for night in range(1, nd):
				rep = {}
				GameState.run["day"] = int(GameState.run["day"]) + 1
				Commons.overnight(rep)
				check(Commons.pending() == s and Commons.build_done() == night and Commons.stage() == s, "[%s] stage %d night %d of %d: still building" % [tag, s, night, nd])
				check(str(rep.get("cfarm", [""])[0]) == str(Commons.tx(Commons.stages()[s]["progress"][night - 1])), "[%s] sleep report gives night %d's progress (%s)" % [tag, night, str(rep.get("cfarm", []))])
				check(Commons.quest_text().contains("night %d of %d" % [night, nd]), "[%s] journal shows build progress (%s)" % [tag, Commons.quest_text()])
				m.go_to(Commons.SCENE, m.player.position - m.offset())
				m = await _wait_reload(m)
				var half := 0
				for c in m.props:
					if is_instance_valid(m.props[c]) and str((m.props[c] as Sprite2D).texture.resource_path).contains("cf_build_"):
						half += 1
				check(half > 0, "[%s] stage %d night %d: work in progress on the map (%d)" % [tag, s, night, half])
				if night == nd - 1:
					await _shot(m, "%s_%d_progress" % [tag, s], cam.get(s + 1, Vector2i(28, 20)))
			rep = {}
			GameState.run["day"] = int(GameState.run["day"]) + 1
			Commons.overnight(rep)
			check(Commons.stage() == s + 1 and Commons.pending() == -1, "[%s] stage %d built overnight" % [tag, s])
			check(not (rep.get("cfarm", []) as Array).is_empty() and str(rep["cfarm"][0]) == str(Commons.tx(Commons.stages()[s]["night"])), "[%s] sleep report tells of the build (%s)" % [tag, str(rep.get("cfarm", []))])
			check(GameState.run["flags"].has("cf_reveal") and GameState.run["flags"].has("cf_reveal_done"), "[%s] the reveal waits for the next visit" % tag)
			m.go_to(Commons.SCENE, m.player.position - m.offset())
			m = await _wait_reload(m)
			await _frames(40)
			await _drain()
			check(not GameState.run["flags"].has("cf_reveal") and not GameState.run["flags"].has("cf_reveal_done"), "[%s] stage %d reveal played on the visit" % [tag, s])
		else:
			Commons.finish_stage(m)
			m = await _wait_reload(m)
		check(Commons.stage() == s + 1, "[%s] stage %d done" % [tag, s])
		if expect.has(s + 1):
			check(_count(m, expect[s + 1]) > 0, "[%s] stage %d shows %s" % [tag, s + 1, expect[s + 1]])
		if s + 1 == 4:
			Commons.overnight({})
			m._plots.queue_redraw()
			var planted := 0
			for k in Commons.plot_cells():
				if str(Commons.plot(k).get("crop", "")) != "":
					planted += 1
			check(planted == 84, "[%s] volunteers planted every bed cell (%d)" % [tag, planted])
			check(GameState.run["flags"].has("cf_rec_stew") and Crafting.why_locked("kitchen", 5, rc) == "", "[%s] stew recipe learned" % tag)
		if s + 1 == 6:
			var sap := 0
			for c in m.props:
				if is_instance_valid(m.props[c]) and (m.props[c] as Sprite2D).texture == Art.tex("props", "cf_sapling"):
					sap += 1
			check(sap == 8, "[%s] orchard: 8 staked saplings the first week (%d)" % [tag, sap])
			GameState.run["flags"]["cf_orchard_day"] = -99  # a week on: real trees
			m.go_to(Commons.SCENE, m.player.position - m.offset())
			m = await _wait_reload(m)
			check(_count(m, "fruit") >= 8, "[%s] orchard trees grown (%d)" % [tag, _count(m, "fruit")])
		if s + 1 == 7:
			check(Commons.plot_cells().size() == 84 + 16, "[%s] cold frames add 16 bed cells" % tag)
		if s + 1 == 4:
			await _shot(m, "%s_4_north" % tag, Vector2i(12, 7))
		if cam.has(s + 1):
			await _shot(m, "%s_%d_%s" % [tag, s + 1, str(Commons.stages()[s]["id"])], cam[s + 1])
	check(GameState.count("green_thumb_charm") == 1, "[%s] green thumb charm" % tag)
	check(GameState.quest_done(Commons.QUEST), "[%s] quest line complete" % tag)
	check(Commons.market_day(), "[%s] opening day is market day" % tag)
	check(Commons.slot("finn", 11.5) == "cf_market_2", "[%s] market-day schedule (%s)" % [tag, Commons.slot("finn", 11.5)])

	# Growth, harvest and the stand.
	var key: String = Commons.plot_cells().keys()[0]
	var p := Commons.plot(key)
	if str(p.get("crop", "")) == "":
		p["crop"] = "turnip"
	p["days"] = 99.0
	var stock_before := 0
	for v in Commons.st()["stock"].values():
		stock_before += int(v)
	var pp := key.split(",")
	var bag_before: Dictionary = (GameState.run["inventory"] as Dictionary).duplicate()
	m._plot_action(Vector2i(int(pp[0]), int(pp[1])), m.things[Vector2i(int(pp[0]), int(pp[1]))])
	var stock_after := 0
	for v in Commons.st()["stock"].values():
		stock_after += int(v)
	var share_n := 0
	for v in Commons.st()["share"].values():
		share_n += int(v)
	check(stock_after > stock_before or share_n > 0, "[%s] helping harvest fills the stand or the share" % tag)
	check(GameState.run["inventory"] != bag_before, "[%s] a handful for the player" % tag)
	var key2: String = Commons.plot_cells().keys()[5]
	Commons.plot(key2)["crop"] = "turnip"
	Commons.plot(key2)["days"] = 99.0
	var h0 := int(Commons.st()["harvests"])
	Commons.overnight({})
	check(int(Commons.st()["harvests"]) > h0, "[%s] unpicked ripe crops are harvested overnight" % tag)
	GameState.add_item("turnip", 5, true)
	Commons.donate("turnip", 5)
	check(int(Commons.st()["goodwill"]) > 0 and int(Commons.st()["stock"].get("turnip", 0)) >= 5, "[%s] donations stock the stand" % tag)
	GameState.run["day"] = 3 * 28 + 5  # winter
	var wkey := ""
	for k in Commons.plot_cells():
		if not bool(Commons.plot_cells()[k]):
			wkey = k
			break
	Commons.plot(wkey)["crop"] = ""
	Commons.overnight({})
	check(str(Commons.plot(wkey).get("crop", "")) == "", "[%s] open beds rest in winter" % tag)
	var glass := 0
	for k in Commons.plot_cells():
		if bool(Commons.plot_cells()[k]) and str(Commons.plot(k).get("crop", "")) != "":
			glass += 1
	check(glass > 0, "[%s] cold frames grow in winter (%d)" % [tag, glass])
	GameState.run["day"] = 10

	# Save and load keep it all.
	GameState.save()
	var st_saved := Commons.stage()
	GameState.run = {}
	check(GameState.has_run() and Commons.stage() == st_saved and Commons.complete(), "[%s] stage survives save/load" % tag)
	arcs_done += 1


## CONDUCT 2 (c2_09): compost before the beds, your seeds in the beds, the seasonal
## ask, the lot-cleared recovery, an old save without overnight builds.
func _extras() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "cf_known", "cf_met", "cf_intro", "community_farm_seen", "cf_letter"]:
		GameState.run["flags"][f] = true
	# An old save: no pending/asks keys.
	GameState.run["cfarm"] = {"stage": 2, "given": {}, "cleared": {}, "plots": {}, "stock": {}, "share": {}}
	check(Commons.pending() == -1 and Commons.st()["asks"] is Dictionary, "[x] old cfarm block gains pending/asks")
	# The shed's compost drops fertilizer before the beds are planted.
	GameState.run["day"] = 6
	var rep := {}
	Commons.overnight(rep)
	check(int(Commons.st()["share"].get("fertilizer", 0)) == 1 and str(rep.get("cfarm", [""])[0]).contains("compost"), "[x] compost works from stage 2 (%s)" % str(rep))
	rep = {}
	GameState.run["day"] = 7
	Commons.overnight(rep)
	check(not rep.has("cfarm"), "[x] a quiet night says nothing (%s)" % str(rep))
	# Seeds stage: what you give is what grows.
	Commons.st()["stage"] = 3
	GameState.run["day"] = 2
	GameState.add_item("pea_seed", 10, true)
	GameState.add_item("radish_seed", 8, true)
	GameState.add_item("kale_seed", 6, true)
	Commons.contribute()
	check(Commons.stage_ready() and not Commons.is_build(3), "[x] seeds bundle filled")
	Commons.finish_stage(null, false)
	Commons.overnight({})
	var kinds := {}
	for k in Commons.plot_cells():
		kinds[str(Commons.plot(k).get("crop", ""))] = int(kinds.get(str(Commons.plot(k).get("crop", "")), 0)) + 1
	var mine := int(kinds.get("pea", 0)) + int(kinds.get("radish", 0)) + int(kinds.get("kale", 0))
	check(mine * 2 >= Commons.plot_cells().size(), "[x] most beds grow the seeds you gave (%s)" % str(kinds))
	# The seasonal ask once the market is open.
	Commons.st()["stage"] = Commons.stages().size()
	GameState.run["day"] = 3
	var a := Commons.ask()
	check(not a.is_empty() and GameState.crops.has(str(a["key"])), "[x] spring ask (%s)" % str(a))
	check(Commons.give_ask() == "", "[x] the ask waits until you carry enough")
	GameState.add_item(str(a["key"]), int(a["n"]), true)
	var cr := int(GameState.run["crystals"])
	check(Commons.give_ask() != "" and int(GameState.run["crystals"]) > cr and GameState.count(str(a["key"])) == 0, "[x] ask answered and paid")
	check(Commons.ask().is_empty(), "[x] one ask a season")
	GameState.run["day"] = 3 * 28 + 2
	var wa := Commons.ask()
	check(not wa.is_empty() and (str(wa.get("key", "")).begins_with("@") or str(wa.get("key", "")).begins_with("#")), "[x] winter ask is a kind (%s)" % str(wa))
	GameState.add_item("trout", 6, true)
	GameState.add_item("carp", 6, true)
	if str(wa.get("key", "")) == "@fish":
		check(Commons.have_of("@fish") >= 12 and Commons.give_ask() != "", "[x] any fish answers the winter ask")
	# The last pile went, but the stage never closed (app shut mid-scene): the visit finishes it.
	Commons.st()["stage"] = 0
	Commons.st()["pending"] = -1
	var cl := {}
	for d: Array in preload("res://scripts/community_farm.gd").DEBRIS:
		cl["%d,%d" % [int(d[0]), int(d[1])]] = true
	Commons.st()["cleared"] = cl
	GameState.run["day"] = 4
	GameState.run["time"] = 9 * 60
	var m := await _load(Vector2.ZERO)
	for i in 60:
		await process_frame
		if Commons.stage() >= 1:
			break
		Dialogue.instance(self)._advance()
	m = await _wait_reload(m)
	check(Commons.stage() == 1, "[x] lot-cleared recovery finishes stage 1 (%d)" % Commons.stage())
