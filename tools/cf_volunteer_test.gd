extends SceneTree
## Community farm volunteers (CONDUCT 2, c2_10): schedules, crowding, visible work,
## walking in/out, rain days, chatter and the lend-a-hand tasks, both arcs.
##   godot --headless --path . --fixed-fps 60 -s res://tools/cf_volunteer_test.gd
## Deterministic (c3_17 #1): seeded, waits count game time (never the wall clock), and
## check.sh runs it with --fixed-fps 60, so a loaded machine can't change the outcome.
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	seed(4242)
	_run.call_deferred()


## Game seconds: frames until `sec` of game time has passed (with --fixed-fps 60,
## 0.1 s is exactly 6 frames, however slow the machine is).
func _wait(sec: float) -> void:
	var gt := 0.0
	while gt < sec - 0.0001:
		await process_frame
		gt += root.get_process_delta_time()


## Frames until cond() holds (or `cap` frames pass).
func _until(cond: Callable, cap := 600) -> void:
	for i in cap:
		if cond.call():
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drain() -> void:
	var d := Dialogue.instance(self)
	for k in 40:
		if not d.active:
			await _frames(2)
			if not d.active:
				return
		d._advance()
		await _frames(2)


func _setup(arc: String, stage: int, day: int, hour: float, weather := "clear") -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["partner_scene", "town_seen", "town_tour", "gangsters_intro", "cf_known", "cf_intro", "cf_met", "cf_board_seen", "community_farm_seen", "cf_letter"]:
		GameState.run["flags"][f] = true
	GameState.run["flags"]["cf_orchard_day"] = -99
	GameState.run["day"] = day
	GameState.run["time"] = int(hour * 60)
	GameState.run["weather"] = {str(day): weather, str(day + 1): weather}
	Commons.st()["stage"] = stage
	if stage >= 4:
		Commons.overnight({})


func _load() -> GameMap:
	GameMap.next_spawn = Vector2(40 * 16, 22 * 16)
	change_scene_to_file("res://scenes/community_farm.tscn")
	await _frames(14)
	await _drain()
	return current_scene as GameMap


func _npc(m: GameMap, id: String) -> Npc:
	for n: Npc in m.get("npcs"):
		if n.id == id:
			return n
	return null


func _visible(m: GameMap) -> Array:
	return (m.get("npcs") as Array).filter(func(n: Npc) -> bool: return n.visible)


func _run() -> void:
	InputSetup.ensure_actions()
	Engine.time_scale = 4.0
	for arc in ["penguins", "gangsters"]:
		await _market(arc)
	await _work()
	await _help()
	await _arrive_leave()
	_rain()
	_chatter()
	print("cf_volunteer_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Market day (day 7, the chapel morning): the market wins, nobody shares a cell.
func _market(arc: String) -> void:
	_setup(arc, 8, 7, 10.5)
	check(Commons.market_day(), "[%s] day 7 is a market day" % arc)
	check(Npc.place_now(GameState.npcs["hazel"]["routine"], "hazel") == "cf_market", "[%s] Hazel is at the market, not the chapel (%s)" % [arc, Npc.place_now(GameState.npcs["hazel"]["routine"], "hazel")])
	GameState.run["time"] = 12 * 60 + 10
	var m := await _load()
	await _frames(30)
	var vis := _visible(m)
	check(vis.size() >= 8, "[%s] a busy market (%d volunteers)" % [arc, vis.size()])
	var crew: CfVolunteers = m.get("crew")
	var seen := {}
	for n: Npc in vis:
		var c := crew.stand_of(n)
		check(not seen.has(c), "[%s] %s has a cell of their own (%s shared with %s)" % [arc, n.id, c, seen.get(c, "")])
		seen[c] = n.id
		check(not m.blocked.has(c) or crew.SEATS.has(n._place), "[%s] %s stands on an open cell %s" % [arc, n.id, c])
		check(c.distance_to(Commons.spots().get(n._place, c)) <= 4.3, "[%s] %s stays near %s" % [arc, n.id, n._place])


## Visible work: bed volunteers walk to a bed, tend/water/pick with a work pose.
func _work() -> void:
	_setup("penguins", 4, 10, 6.5)
	for k: String in Commons.st()["plots"]:
		Commons.st()["plots"][k]["w"] = false
	var m := await _load()
	var crew: CfVolunteers = m.get("crew")
	var hz := _npc(m, "hazel")
	check(hz != null and hz.visible and hz._place == "cf_beds_a", "[work] Hazel tends bed A at 6:30")
	var started := false
	var posed := false
	var wet_before := _wet_count()
	for i in 400:
		await _wait(0.1)
		if crew.task_of(hz) != "":
			started = true
		if hz._pose in ["work", "work_2", "carry"] and crew.task_of(hz).ends_with("/do"):
			posed = true
	check(started, "[work] Hazel takes on a job at the beds")
	check(posed, "[work] she crouches to work (work pose) at the bed")
	check(_wet_count() > wet_before, "[work] volunteers water dry bed cells (%d -> %d)" % [wet_before, _wet_count()])
	# A ripe cell gets picked by a volunteer.
	var key := ""
	for k: String in m.get("_cells"):
		if Vector2(Vector2i(int(k.split(",")[0]), int(k.split(",")[1]))).distance_to(Vector2(crew.stand_of(hz))) < 5.0:
			key = k
			break
	var p := Commons.plot(key)
	p["crop"] = "turnip"
	p["days"] = 99.0
	var h0 := int(Commons.st()["harvests"])
	for i in 600:
		await _wait(0.1)
		if int(Commons.st()["harvests"]) > h0:
			break
	check(int(Commons.st()["harvests"]) > h0, "[work] a ripe crop near a volunteer gets picked")
	check(not crew.SEATS.is_empty(), "[work] benches have seats")


func _wet_count() -> int:
	var n := 0
	for k: String in Commons.st()["plots"]:
		if bool(Commons.st()["plots"][k].get("w", false)):
			n += 1
	return n


## Lend a hand: weeding and hauling, once per volunteer a day.
func _help() -> void:
	_setup("penguins", 6, 10, 6.5)
	var m := await _load()
	var crew: CfVolunteers = m.get("crew")
	var hz := _npc(m, "hazel")
	await _frames(10)
	check(Commons.help_kind(hz.activity) == "weed", "[help] bed volunteers ask for weeding (%s)" % Commons.help_kind(hz.activity))
	check(crew.can_help(hz), "[help] Hazel has a job for you")
	await _accept(crew, hz)
	check(str(crew.help.get("kind", "")) == "weed", "[help] the weeding task starts")
	var weeds: Array = []
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "cf_weed":
			weeds.append(c)
	check(weeds.size() == 4, "[help] four weeds to pull (%d)" % weeds.size())
	var f0 := int(GameState.run["friendship"].get("hazel", 0))
	var bag0 := (GameState.run["inventory"] as Dictionary).duplicate()
	for c: Vector2i in weeds:
		check(not m.blocked.has(c), "[help] weeds don't block the way")
		m.interact(c, m.things[c])
	await _until(func() -> bool: return crew.help.is_empty(), 240)
	await _frames(4)
	await _drain()
	check(crew.help.is_empty(), "[help] weeding done")
	check(Commons.helped_today("hazel") and not crew.can_help(hz), "[help] once a day per volunteer")
	var f1 := int(GameState.run["friendship"].get("hazel", 0))
	check(f1 > f0, "[help] Hazel's friendship grows (%d -> %d)" % [f0, f1])
	check(GameState.run["inventory"] != bag0, "[help] a cut of the harvest for you")
	# Hauling for the compost volunteer.
	GameState.run["time"] = 15 * 60 + 30
	var old := m
	m.go_to(Commons.SCENE, m.player.position - m.offset())
	for i in 400:
		await process_frame
		if current_scene != null and current_scene != old and current_scene is GameMap:
			break
	await _frames(14)
	await _drain()
	m = current_scene as GameMap
	crew = m.get("crew")
	var mb := _npc(m, "mabel")
	check(mb != null and mb.visible and mb.activity == "haul", "[help] Mabel hauls compost at 3:30")
	if mb == null or not mb.visible:
		return
	await _frames(10)
	await _accept(crew, mb)
	check(str(crew.help.get("kind", "")) == "haul", "[help] the hauling task starts")
	var drop := Vector2i(-1, -1)
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == str(crew.help.get("drop", "-")):
			drop = c
	check(drop != Vector2i(-1, -1), "[help] there's somewhere to drop the crates (%s)" % str(crew.help.get("drop", "")))
	var loads: Array = []
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "cf_load":
			loads.append(c)
	check(loads.size() == 3, "[help] three crates (%d)" % loads.size())
	for c: Vector2i in loads:
		m.interact(c, m.things[c])
		check(bool(crew.help.get("carrying", false)) or crew.help.is_empty(), "[help] carrying a crate")
		if loads.size() > 1 and c == loads[0]:
			m.interact(loads[1], m.things[loads[1]])
			check(m.things.has(loads[1]), "[help] one crate at a time")
		check(m.hint_for(drop, m.things[drop]) == "A: put the crate down" or crew.help.is_empty(), "[help] the drop point says so")
		m.interact(drop, m.things[drop])
	await _until(func() -> bool: return crew.help.is_empty(), 240)
	await _frames(4)
	await _drain()
	check(crew.help.is_empty() and Commons.helped_today("mabel"), "[help] hauling done")


func _accept(crew: CfVolunteers, n: Npc) -> void:
	var d := Dialogue.instance(self)
	crew.offer(n)
	for i in 30:
		await process_frame
		if d.active and d._in_choice:
			d._choose("", 0)
			break
		elif d.active:
			d._advance()
	await _frames(4)


## Shifts: someone starting while you're there walks in from the road; someone
## finishing walks back out before vanishing.
func _arrive_leave() -> void:
	_setup("penguins", 8, 10, 14.9)
	var m := await _load()
	await _wait(1.5)
	var crew: CfVolunteers = m.get("crew")
	var fi := _npc(m, "finn")
	var hz := _npc(m, "hazel")
	check(fi.visible and not hz.visible, "[shift] Finn at the beds, Hazel not yet")
	m.player.position = fi.position + Vector2(48, 0)  # close enough to watch him go
	GameState.run["time"] = 15 * 60 + 5
	fi._t = 0.0
	hz._t = 0.0
	await _frames(3)
	check(hz.visible and hz.cell().x >= 48, "[shift] Hazel walks in from the road (at %s)" % hz.cell())
	check(fi.visible and crew.task_of(fi) == "leaving", "[shift] Finn heads off (%s)" % crew.task_of(fi))
	for i in 600:
		await _wait(0.1)
		if not fi.visible:
			break
	check(not fi.visible and not fi.hold, "[shift] Finn has gone home")
	for i in 300:
		await _wait(0.1)
		if hz.cell().distance_to(crew.stand_of(hz)) <= 2.0:
			break
	check(hz.cell().distance_to(crew.stand_of(hz)) <= 2.0, "[shift] Hazel reached the orchard (%s)" % hz.cell())


## Rain: grown-ups shelter at the shed, kids stay home, the hardy keep working.
func _rain() -> void:
	_setup("penguins", 3, 10, 16.2, "rain")
	check(Commons.slot("wren_jr", 16.2) == "", "[rain] kids stay home in the rain")
	var al := Commons.slot("alder", 16.2)
	check(al == "cf_shed" or Npc.rain_walker("alder"), "[rain] Alder shelters at the shed (%s)" % al)
	check(Npc.place_now(GameState.npcs["alder"]["routine"], "alder") in ["cf_shed", "cf_board"], "[rain] place_now keeps a sheltering volunteer at the farm")
	_setup("penguins", 3, 10, 13.5, "rain")
	check(Commons.slot("finn", 13.5) == "cf_beds_b", "[rain] Finn works the beds in any weather")
	_setup("penguins", 1, 10, 15.5, "storm")
	check(Commons.slot("alder", 15.5) == "" or Npc.rain_walker("alder"), "[rain] no shed yet: home in a storm")
	_setup("penguins", 3, 10, 16.2, "rain")
	var w := Commons.work_line("farm", "hazel")
	var rain_l: Array = Commons.tx(Commons.data()["at_work"]["rain"])
	check(w in rain_l, "[rain] at-work lines talk about the rain (%s)" % w)


func _chatter() -> void:
	_setup("gangsters", 3, 10, 9.0)
	var g := Commons.tx(Commons.data()["at_work"]["farm"]) as Array
	_setup("penguins", 3, 10, 9.0)
	var p := Commons.tx(Commons.data()["at_work"]["farm"]) as Array
	check(g != p, "[talk] the lot garden has its own at-work lines")
	check(Commons.bark("farm", true) in (Commons.tx(Commons.data()["barks"]["greet"]) as Array), "[talk] first pass is a greeting")
	check(Commons.bark("market", false) != "", "[talk] market barks")
	var own := false
	for i in 40:
		own = own or Commons.work_line("farm", "finn") in (Commons.tx(Commons.data()["at_work_own"]["finn"]) as Array)
	check(own, "[talk] volunteers have lines of their own")
