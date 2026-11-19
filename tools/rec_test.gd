extends SceneTree
## Rec Center: bowling scoring, the pin physics, tickets saved and loaded (old saves
## migrated), the prize counter, the grand opening, villager visits, both rooms load.
##   godot --headless --path . -s res://tools/rec_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _run() -> void:
	InputSetup.ensure_actions()
	# --- scoring ---
	var cases := [
		[[10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10], 300],
		[[9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0], 90],
		[[5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5], 150],
		[[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0],
		[[10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1], 167],
		[[10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9], 299],
		[[1, 4, 4, 5, 6, 4, 5, 5, 10, 0, 1, 7, 3, 6, 4, 10, 2, 8, 6], 133],
	]
	for cs: Array in cases:
		var got := Bowling.score_of(cs[0])
		ok(got == int(cs[1]), "score %s = %d (got %d)" % [str(cs[0]), int(cs[1]), got])
		ok(bool(Bowling.next_state(cs[0])["over"]), "game over after %s" % str(cs[0]))
	ok(Bowling.frame_totals([10, 3]) == [-1, -1], "strike waits for two balls")
	ok(Bowling.frame_totals([7, 3, 4]) == [14, -1], "spare + 4 = 14, frame 2 open")
	ok(Bowling.frame_totals([10, 10, 10]) == [30, -1, -1], "turkey: first frame 30")
	ok(Bowling.next_state([7])["ball"] == 1 and not bool(Bowling.next_state([7])["reset"]), "second ball same rack")
	ok(Bowling.next_state([10])["frame"] == 1 and bool(Bowling.next_state([10])["reset"]), "strike: next frame, fresh rack")
	var nine := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	ok(not bool(Bowling.next_state(nine + [10, 10])["over"]) and bool(Bowling.next_state(nine + [10, 10])["reset"]), "10th: X X gets a third ball on a fresh rack")
	ok(not bool(Bowling.next_state(nine + [10, 3])["reset"]), "10th: X 3 leaves the rack for the third ball")
	ok(bool(Bowling.next_state(nine + [4, 5])["over"]), "10th: open frame ends the game")
	ok(Bowling.frame_marks([10], 0) == ["", "X"] and Bowling.frame_marks([7, 3], 0) == ["7", "/"] and Bowling.frame_marks([0, 9], 0) == ["-", "9"], "frame marks")
	ok(Bowling.frame_marks(nine + [10, 7, 3], 9) == ["X", "7", "/"], "10th frame marks X 7 /")
	var mk := Bowling.count_marks([10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1])
	ok(int(mk["strikes"]) == 5 and int(mk["spares"]) == 2, "marks: 5 strikes 2 spares (got %s)" % str(mk))

	# --- physics: a pocket hit carries pins, a gutter ball doesn't, a full game ends ---
	var strikes := 0
	var total := 0
	for i in 40:
		var s := Bowling.Sim.new()
		s.rng.seed = 1000 + i
		s.rack()
		var n := s.run_throw(2.0, 0.3 + 0.05 * (i % 5 - 2), 320.0, 0.66)
		total += n
		if n == 10:
			strikes += 1
	print("  pocket throws: %d strikes / 40, %.1f pins avg" % [strikes, total / 40.0])
	ok(strikes >= 4 and strikes <= 36, "pocket throws strike sometimes, not always (%d/40)" % strikes)
	ok(total / 40.0 >= 7.0, "pocket throws carry most pins (avg %.1f)" % (total / 40.0))
	var g := Bowling.Sim.new()
	g.rack()
	ok(g.run_throw(18.0, 3.0, 300.0, 0.0) == 0 and g.gutter, "a ball aimed off the lane is a gutter ball")
	var c := Bowling.Sim.new()
	c.rng.seed = 5
	c.rack()
	var cn := c.run_throw(0.0, 0.0, 330.0, 0.0)
	ok(cn >= 3, "straight at the head pin knocks pins (%d)" % cn)
	# A full line from the sim scores like the rules say.
	var rolls: Array = []
	var sim := Bowling.Sim.new()
	sim.rng.seed = 42
	var guard := 0
	while not bool(Bowling.next_state(rolls)["over"]) and guard < 30:
		var ns := Bowling.next_state(rolls)
		if bool(ns["reset"]):
			sim.rack()
		else:
			sim.sweep()
		var before := sim.standing()
		var n2 := sim.run_throw(2.0, 0.3, 320.0, 0.66)
		ok(n2 >= 0 and n2 <= before, "pins knocked within what stood")
		rolls.append(n2)
		guard += 1
	ok(bool(Bowling.next_state(rolls)["over"]) and rolls.size() >= 11 and rolls.size() <= 21, "a simulated game ends in 11-21 balls (%d)" % rolls.size())
	print("  sim game: %s = %d" % [str(rolls), Bowling.score_of(rolls)])

	# --- tickets: save, load, migrate ---
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	ok(Tickets.count() == 0, "new run: no tickets")
	Tickets.add(37, "bowling")
	ok(not Tickets.spend(40) and Tickets.count() == 37, "can't overspend")
	ok(Tickets.spend(7) and Tickets.count() == 30, "spend 7")
	ok(Tickets.set_best("bowling", 133) and not Tickets.set_best("bowling", 90) and Tickets.best_score("bowling") == 133, "best score kept")
	Tickets.set_best("block_jumper", 500)
	GameState.save()
	var key := GameState.save_key()
	GameState.run = {}
	ok(GameState.has_run(), "save reloads")
	ok(Tickets.count() == 30 and Tickets.best_score("bowling") == 133 and Tickets.plays("bowling") == 2 and Tickets.arcade_plays() == 1, "tickets/bests survive save+load")
	# An old save from before tickets: migrated to zero, an old flat "tickets" field carried over.
	var old: Dictionary = GameState.run.duplicate(true)
	old.erase("arcade")
	old["tickets"] = 12
	SaveGame.set_value(key, old)
	GameState.run = {}
	ok(GameState.has_run() and Tickets.count() == 12 and Tickets.best_score("bowling") == 0, "old save migrated (tickets %d)" % Tickets.count())

	# --- prizes ---
	Tickets.add(1000, "test")
	ok(Tickets.lock_text("rp_trophy_bronze") != "", "bronze trophy locked below 100")
	Tickets.set_best("bowling", 104)
	ok(Tickets.unlocked("rp_trophy_bronze"), "bronze trophy opens at 100+")
	var tk := Tickets.count()
	ok(Tickets.buy("rp_teddy") == "" and GameState.count("rp_teddy") == 1 and Tickets.count() == tk - 80, "buy the teddy for 80")
	ok(Tickets.buy("rp_trophy_bronze") == "" and Tickets.buy("rp_trophy_bronze") != "", "once-only prize can't be bought twice")
	ok(not GameState.can_gift("mabel", "rp_trophy_bronze") and GameState.can_gift("mabel", "rp_teddy"), "decor isn't a gift; the teddy is")
	ok(Tickets.lock_text("rp_arcade_medal") != "", "arcade medal needs every cabinet")
	for gid in ArcadeHub.game_ids():
		ArcadeHub.mark_played(str(gid))
	ok(Tickets.unlocked("rp_arcade_medal"), "arcade medal opens after every cabinet (all_games)")
	for id in Tickets.prizes().get("prizes", {}):
		var item := str(Tickets.prize(str(id)).get("item", id))
		ok(GameState.items.has(item), "prize item exists: " + item)
		ok(Art.has("items", Hud.icon_for(item)), "prize icon exists: " + item)
	# Bowling payout.
	var t0 := Tickets.count()
	var got_t := RecCenter.finish_game(null, {"done": true, "score": 128, "strikes": 2, "spares": 3})
	ok(got_t == RecCenter.tickets_for(128, 2, 3) and Tickets.count() == t0 + got_t and GameState.run["flags"].has("bowl_120"), "a 128 game pays tickets and sets bowl_120")
	ok(RecCenter.finish_game(null, {"done": false}) == 0, "an abandoned game pays nothing")

	# --- opening and visitors ---
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 3
	RecCenter.morning()
	ok(not RecCenter.is_open(), "not open on day 3")
	GameState.run["day"] = 8
	RecCenter.morning()
	ok(not RecCenter.is_open(), "not open before the town intro")
	GameState.add_quest("meet_town", "x")
	GameState.complete_quest("meet_town")
	RecCenter.morning()
	ok(RecCenter.is_open() and GameState.has_quest("rec_visit"), "opens on day 8 after the town intro, with a quest")
	ok(Mail.list().any(func(m: Dictionary) -> bool: return str(m.get("text", "")).contains("Rec Center")), "opening letter sent")
	GameState.run["day"] = 10  # day % 7 == 3: league night
	GameState.run["time"] = 19 * 60 + 30
	ok(RecCenter.is_league_night(), "day 10 is league night")
	ok(Npc.place_now(GameState.npcs["gideon"]["routine"], "gideon") == "rec" and RecCenter.floor_of("gideon") == "rec_up", "Gideon bowls on league night")
	GameState.run["time"] = 10 * 60
	ok(Npc.place_now(GameState.npcs["gideon"]["routine"], "gideon") == "work", "...and works in the morning")
	GameState.run["day"] = 13  # rest day
	GameState.run["time"] = 14 * 60
	ok(Npc.place_now(GameState.npcs["pip"]["routine"], "pip") == "rec", "Pip at the arcade on a rest-day afternoon")
	ok(not RecCenter.talk_pool("pip").is_empty(), "villagers talk about the rec center once it's open")
	ok(not GameState.side_quest_for("tobin").is_empty(), "Tobin offers the 120 bet")

	# --- both rooms load, both arcs, and the cabinet hook ---
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["rec_open"] = 1
		GameState.run["day"] = 10
		GameState.run["time"] = 19 * 60 + 30
		for room in ["rec", "rec_up"]:
			GameMap.next_interior = room
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/interior.tscn")
			for i in 10:
				await process_frame
			var m := current_scene as GameMap
			ok(m != null and str(m.get("interior_id")) == room, "%s/%s loads" % [arc, room])
			if m == null:
				continue
			var vis: Array = (m.get("npcs") as Array).filter(func(n: Npc) -> bool: return is_instance_valid(n))
			if room == "rec_up":
				ok(vis.size() >= 2, "%s league night: villagers at the lanes (%d)" % [arc, vis.size()])
				ok(not RecCenter.lanes_taken().is_empty(), "%s: some lanes taken" % arc)
			var want := "bowling_alley" if room == "rec_up" else ("rec_center" if arc == "penguins" else "neon")  # the lanes have their own song (c2_08)
			ok(str(m.get("music_track")) == want, "%s/%s music" % [arc, room])
			_c2_07_checks(m, room, arc)
	await _c1_15_checks()
	await _c2_06_checks()
	print("rec_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## CONDUCT 1 (c1_15): cabinets vs props, prize balance, stands, the cabinet a visitor
## stands at, the jukebox surviving the area-song refresh, money words in both arcs.
func _c1_15_checks() -> void:
	var rd := RecCenter.data()
	var room: Dictionary = GameState.load_json("res://data/interiors.json")["rec"]
	var cab_cells := {}
	for cab: Dictionary in rd.get("cabinets", []):
		var id := str(cab["id"])
		ok(ArcadeHub.game_ids().has(id), "cabinet %s is an ArcadeHub game" % id)
		ok(Art.has("props", str(cab["sprite"])), "cabinet %s prop art %s" % [id, str(cab["sprite"])])
		ok(ArcadeHub.make(id) != null and ArcadeHub.make(id).game_id == id, "cabinet %s opens its own game" % id)
		cab_cells[Vector2i(int(cab["cell"][0]), int(cab["cell"][1]))] = id
		var has_thing := false
		for th: Dictionary in room["things"]:
			if str(th.get("act", "")) == "cabinet" and str(th.get("game", "")) == id and Vector2i(int(th["cell"][0]), int(th["cell"][1])) == Vector2i(int(cab["cell"][0]), int(cab["cell"][1])):
				has_thing = true
		ok(has_thing, "cabinet %s has its A-thing on the prop cell" % id)
	# Every arcade game is reachable in the hall: the four cabinets plus the claw prop.
	var reach: Array = cab_cells.values()
	reach.append("claw")
	for g in ArcadeHub.game_ids():
		ok(reach.has(g), "arcade game %s has a machine in the hall" % g)
	ok(int((Tickets.prize("rp_arcade_medal").get("need", {}) as Dictionary).get("arcade", {}).get("games", 0)) <= reach.size(), "arcade medal asks no more cabinets than exist")
	# Prize balance: no prize sells for as many crystals as its tickets cost.
	for pid in Tickets.prizes().get("prizes", {}):
		var pr := Tickets.prize(str(pid))
		var item := str(pr.get("item", pid))
		ok(GameState.item_value(item) * 4 <= int(pr["cost"]) * 3 or bool((pr.get("need", {}) as Dictionary).get("once", false)),
			"prize %s: worth %d crystals for %d tickets (resale loop)" % [item, GameState.item_value(item), int(pr["cost"])])

	# A rest-day afternoon: Pip and Mabel at the cabinets downstairs.
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["rec_open"] = 1
		GameState.run["day"] = 13
		GameState.run["time"] = 14 * 60 + 30
		ok(ArcadeHub.price(10) == ("10 crystals" if arc == "penguins" else "$10"), "%s cabinet price words (%s)" % [arc, ArcadeHub.price(10)])
		GameMap.next_interior = "rec"
		GameMap.next_spawn = Vector2.ZERO
		change_scene_to_file("res://scenes/interior.tscn")
		for i in 10:
			await process_frame
		var m := current_scene as GameMap
		if m == null:
			ok(false, "%s rec loads for the stand checks" % arc)
			continue
		var d := Dialogue.instance(self)
		for k in 6:
			if d.active:
				d._advance()
			await process_frame
		for kind in ["cab", "lobby"]:
			for c in rd["stands"]["rec"][kind]:
				var cc := Vector2i(int(c[0]), int(c[1]))
				ok(not m.blocked.has(cc) and not m.things.has(cc), "%s stand %s %s is open floor" % [arc, kind, str(cc)])
		var at_cab: Array = []
		for n: Npc in m.get("npcs"):
			if is_instance_valid(n) and not RecCenter.cabinet_above(m, n.cell()).is_empty():
				at_cab.append(n)
		ok(at_cab.size() >= 1, "%s: a visitor is at a cabinet on a rest day (%d)" % [arc, at_cab.size()])
		for n: Npc in at_cab:
			var spot := RecCenter.step_aside_cell(m, n.cell())
			ok(spot != Vector2i(-1, -1) and RecCenter.cabinet_above(m, spot).is_empty() and not m.blocked.has(spot), "%s: %s can step aside from %s (to %s)" % [arc, n.id, str(n.cell()), str(spot)])
		# The jukebox: a new record that the 3-second area-song refresh keeps.
		var mus := Music.instance(self)
		var house := m.area_track()
		ok(house == ("rec_center" if arc == "penguins" else "neon"), "%s house song %s" % [arc, house])
		mus.play(house)
		RecCenter._jukebox(m)
		var rec1 := mus.wanted()
		ok(rec1 != house and m.area_track() == rec1, "%s jukebox: new record %s kept by area_track (%s)" % [arc, rec1, m.area_track()])
		RecCenter._jukebox(m)
		ok(mus.wanted() != rec1 and m.area_track() == mus.wanted(), "%s jukebox: next record %s" % [arc, mus.wanted()])
		GameState.run["day"] = 14
		ok(m.area_track() == house, "%s jukebox resets the next day" % arc)


## CONDUCT 2 (c2_06): opening hours, the weekly visit schedule (every slot really
## happens, the house lane stays free, no floor overflows its stands), league night
## upstairs (every bowler at their lane), chatter, the desk board, bowling together.
func _c2_06_checks() -> void:
	var rd := RecCenter.data()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["day"] = 22
	GameState.run["time"] = 3 * 60
	ok(RecCenter.why_closed() != "", "closed at 3am")
	GameState.run["time"] = 8 * 60 + 30
	ok(RecCenter.why_closed() != "", "closed at 8:30am")
	GameState.run["time"] = 10 * 60
	ok(RecCenter.why_closed() == "", "open at 10am")
	GameState.run["time"] = 23 * 60 + 59
	ok(RecCenter.why_closed() == "", "open at 11:59pm")
	GameState.run["day"] = 14  # festival
	GameState.run["time"] = 12 * 60
	ok(RecCenter.why_closed().contains("Festival"), "closed for the festival (%s)" % RecCenter.why_closed())
	GameState.run["time"] = 19 * 60
	ok(RecCenter.why_closed() == "", "open after the festival")
	# The week, clear and wet: every visit slot really happens on some day of it.
	var stands: Dictionary = rd["stands"]
	var cap := {"rec": 0, "rec_up": 0}
	for fl in cap:
		var seen := {}
		for kind in stands[fl]:
			for c in stands[fl][kind]:
				seen[str(c)] = true
		cap[fl] = seen.size()
	var happened := {}
	for wet in [false, true]:
		for wd in 7:
			var day := 15 + wd + (28 if wet else 0)
			GameState.run["day"] = day
			GameState.run["weather"] = {str(day): "rain" if wet else "clear"}
			for hh in range(18, 48):
				GameState.run["time"] = hh * 30
				var on := {"rec": 0, "rec_up": 0}
				for id in rd["visitors"]:
					var s := RecCenter.slot_now(str(id))
					if s.is_empty():
						continue
					if Npc.place_now(GameState.npcs[id].get("routine", []), str(id)) == "rec":
						on[str(s[3])] += 1
						happened["%s:%s" % [id, str(s)]] = true
				for fl in on:
					ok(int(on[fl]) <= int(cap[fl]), "day %d %.1fh: %s holds %d (stands %d)" % [day, hh / 2.0, fl, on[fl], cap[fl]])
				ok(not RecCenter.lanes_taken().has(RecCenter.house_lane()), "house lane free day %d %.1fh" % [day, hh / 2.0])
	for id in rd["visitors"]:
		for s in rd["visitors"][id]["slots"]:
			ok(happened.has("%s:%s" % [id, str(s)]), "%s's visit %s happens (not at work then)" % [id, str(s)])
	# League night upstairs: every bowler on a lane (two to a lane), lane 4 free.
	GameState.run["day"] = 24
	GameState.run["weather"] = {"24": "clear"}
	GameState.run["time"] = 20 * 60 + 15
	var tv := RecCenter.today_visits()
	var up_ids: Array = tv["rec_up"].map(func(e: Array) -> String: return str(e[0]))
	ok(up_ids.has("gideon") and up_ids.has("maple"), "desk board: Gideon and Maple bowl tonight (%s)" % str(up_ids))
	var board := RecCenter.today_lines()
	ok(str(board[0]["text"]).contains("league") and str(board[2]["text"]).contains("Gideon"), "desk board words league night")
	GameMap.next_interior = "rec_up"
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/interior.tscn")
	for i in 10:
		await process_frame
	var m := current_scene as GameMap
	var d := Dialogue.instance(self)
	for k in 6:
		if d.active:
			d._advance()
		await process_frame
	var want := RecCenter.stand_cells("rec_up")
	var got := {}
	for n: Npc in m.get("npcs"):
		if is_instance_valid(n):
			got[n.id] = n.cell()
	for id in want:
		ok(got.has(id), "league night: %s is upstairs" % id)
		ok(got.get(id, Vector2i(-1, -1)) == want[id], "league night: %s stands at %s (at %s)" % [id, str(want[id]), str(got.get(id, "-"))])
	var lt := RecCenter.lanes_taken()
	print("  league night upstairs: %s, lanes %s" % [str(got), str(lt)])
	ok(lt.size() >= 2 and not lt.has(RecCenter.house_lane()), "league night: lanes %s taken, house lane free" % str(lt.keys()))
	for id in want:
		var line := str(RecCenter.chat(str(id))[0]["text"])
		ok(not line.contains("{") and line.length() > 8, "%s says something filled in: %s" % [id, line])
		if str(id) == "gideon":
			ok(not line.contains("before Gideon"), "Gideon doesn't talk about himself in the third person")
	# A taken lane offers a game with its bowler (and a way out); talking to a bowler too.
	var taken_lane := int(lt.keys()[0])
	RecCenter._lane(m, taken_lane)
	await process_frame
	ok(d.active and d._choices.get_child_count() == 2 and str((d._choices.get_child(0) as Button).text).begins_with("Bowl with"), "a taken lane offers a game with its bowler")
	if d.active and d._choices.get_child_count() > 0:
		d._choose("", d._choices.get_child_count() - 1)
	for k in 4:
		await process_frame
	ok(not d.active and get_root().get_tree().paused == false, "Not now closes it")
	var bowler: Npc = null
	for n: Npc in m.get("npcs"):
		if is_instance_valid(n) and RecCenter.lane_of(n.id) > 0:
			bowler = n
	if bowler:
		RecCenter.visitor_talk(m, bowler)
		await process_frame
		while d.active and d._choices.get_child_count() == 0:
			d._advance()
			await process_frame
		ok(d.active and d._choices.get_child_count() == 2 and Dialogue.is_way_out(str((d._choices.get_child(1) as Button).text)), "a bowler offers a game together, with a way out")
		if d.active and d._choices.get_child_count() > 0:
			d._choose("", 1)
		for k in 4:
			await process_frame
	# Bowling together: a result line, friendship once a day, tickets for a win.
	var f0 := int(GameState.run["friendship"].get("gideon", 0))
	var t0 := Tickets.count()
	var them := RecCenter.rival_score("gideon")
	ok(them >= 140 and them <= 195, "Gideon bowls near his average (%d)" % them)
	var r := RecCenter.together_result("gideon", them + 20)
	ok(str(r[0]["text"]).contains(str(them)), "result line names his score: %s" % str(r[0]["text"]))
	ok(int(GameState.run["friendship"]["gideon"]) > f0 and Tickets.count() == t0 + 10, "a win: friendship and +10 tickets")
	var f1 := int(GameState.run["friendship"]["gideon"])
	RecCenter.together_result("gideon", them - 20)
	ok(int(GameState.run["friendship"]["gideon"]) == f1, "friendship from bowling together once a day")
	# Closed: nobody visits, lanes and cabinets refuse.
	GameState.run["time"] = 30
	ok(RecCenter.slot_now("sal").is_empty() and RecCenter.lanes_taken().is_empty(), "after midnight: nobody at the rec")


## CONDUCT 2 (c2_07): the rooms' dressing and light. Every decor piece's art exists and
## sits off the stands and the things you use; the coloured light layer is there and
## the house lights dim (cooler, not lamplit) after dark.
func _c2_07_checks(m: GameMap, room: String, arc: String) -> void:
	var I: Dictionary = m.get("I")
	var gl: Array = m.get_children().filter(func(n: Node) -> bool: return n is RecGlow)
	ok(gl.size() == 1 and (gl[0] as RecGlow).lights.size() >= 8, "%s/%s: rec light layer (%d lights)" % [arc, room, (gl[0] as RecGlow).lights.size() if gl.size() > 0 else 0])
	var tint: Color = m.sky_tint(21 * 60)
	ok(tint.b > tint.r and tint.r < 0.9, "%s/%s: night tint is the cool rec dim (%s)" % [arc, room, tint])
	ok(m.sky_tint(13 * 60).is_equal_approx(Color(1, 1, 1)), "%s/%s: full lights by day" % [arc, room])
	for wp: Dictionary in I.get("wall_props", []):
		ok(Art.has("furniture", str(wp["name"])), "%s: wall art %s" % [room, wp["name"]])
	var used := {}
	for t: Dictionary in I.get("things", []):
		used[Vector2i(int(t["cell"][0]), int(t["cell"][1]))] = true
	var stands: Dictionary = RecCenter.data().get("stands", {}).get(room, {})
	for k: String in stands:
		for c: Array in stands[k]:
			used[Vector2i(int(c[0]), int(c[1]))] = true
	for p: Dictionary in I.get("props", []):
		var nm := str(p["name"])
		if not nm.begins_with("rec_"):
			continue
		ok(Art.has(str(p.get("group", "furniture")), nm), "%s: decor art %s" % [room, nm])
		for i in int(p.get("w", 0)) + 1:
			var c := Vector2i(int(p["cell"][0]) + i, int(p["cell"][1]))
			ok(not used.has(c), "%s: %s at %s keeps clear of stands and things" % [room, nm, c])
	if room == "rec":
		ok(Art.has("tiles", "rec_carpet") and Art.has("tiles", "rec_carpet_gang"), "arcade carpet art")
		for s: Array in RecDecor.WALL_NEON:
			ok(Art.has("props", str(s[1])) and not (int(s[0]) in m.call("window_cols")), "wall neon %s off the window" % s[1])
