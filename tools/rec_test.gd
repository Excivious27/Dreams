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
	ok(Tickets.lock_text("rp_arcade_medal") != "", "arcade medal needs four cabinets")
	for gid in ["a", "b", "c", "d"]:
		Tickets.set_best(gid, 1)
	ok(Tickets.unlocked("rp_arcade_medal"), "arcade medal opens after four cabinets")
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
			ok(str(m.get("music_track")) == ("rec_center" if arc == "penguins" else "neon"), "%s/%s music" % [arc, room])
	print("rec_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
