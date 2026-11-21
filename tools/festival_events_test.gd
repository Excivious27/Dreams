extends SceneTree
## CONDUCT 15 P6 (c15_06-15): every festival activity driven once through its dialogue.
## Egg hunt: eggs persist across a town rebuild, pays (money, rec, keepsake) only when the last
## egg is found; activities refused outside the festival's hours; lantern float grows a vital 3-5;
## crop contest places and pays; star wish +5 and +10 friendship; second try gives the again line;
## gang arc egg hunt is a stash hunt; the five new town festivals run (FestivalExtra).
##   godot --headless --fixed-fps 60 --path . -s res://tools/festival_events_test.gd
var fails := 0
var picks: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(15)
	Campaign.bypass = true
	_run.call_deferred()


func _go() -> GameMap:
	GameState.run["flags"]["town_seen"] = true
	GameState.run["flags"]["town_tour"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/town.tscn")
	for k in 12:
		await process_frame
	return current_scene as GameMap


## Plays the dialogue until it closes: choices from `picks` (0 when empty).
func _drive(frames := 900) -> void:
	for i in frames:
		await process_frame
		var d := root.get_node_or_null("Dialogue") as Dialogue
		if d == null or not d.active:
			if i > 4:
				var still := false
				for k in 3:
					await process_frame
					if d != null and d.active:
						still = true
				if not still:
					return
			continue
		if d._in_choice:
			d._choose("", int(picks.pop_front()) if not picks.is_empty() else 0)
		else:
			d._next()


func _hide_npcs(t: GameMap) -> void:
	for n: Npc in t.npcs:
		n.visible = false  # an egg under a villager would open their talk instead


func _eggs(t: GameMap) -> Array:
	var out: Array = []
	for c: Vector2i in t.things:
		if str(t.things[c].get("type", "")) == "egg":
			out.append(c)
	return out


func _run() -> void:
	InputSetup.ensure_actions()
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "Kairi", "Dreamhollow", "Biscuit")
		GameState.run["intro_done"] = true
		GameState.run["day"] = 14
		GameState.run["time"] = 7 * 60
		var t: GameMap = await _go()
		check(t != null and t.scene_id() == "town", "%s: town built" % arc)
		# Hours gate: 7am, egg hunt not open yet.
		check(not t._fest_open("egg"), "%s: egg hunt refused at 7am" % arc)
		GameState.run["time"] = 11 * 60
		check(t._fest_open("egg"), "%s: egg hunt open at 11am" % arc)
		var money0 := int(GameState.run["crystals"])
		picks = [0]
		t.later(t._festival_event.bind("egg"))
		await _drive()
		var eggs := _eggs(t)
		check(eggs.size() == 12, "%s: 12 eggs hidden (%d)" % [arc, eggs.size()])
		var key := "fest_egg_14"
		check(not GameState.run["flags"].has(key + "_dc") and not GameState.run["flags"].has(key + "_done"), "%s: no prize on Go!" % arc)
		if arc == "gangsters" and not eggs.is_empty():
			check("envelope" in str(t.things[eggs[0]]["hint"]), "%s: stash hunt envelopes" % arc)
		_hide_npcs(t)
		for i in 3:
			t.interact(eggs[i], t.things[eggs[i]])
		check(int(GameState.run["flags"]["eggs_left"]) == 9, "%s: 9 left after 3" % arc)
		# Rebuild the town: the nine come back.
		t = await _go()
		eggs = _eggs(t)
		check(eggs.size() == 9, "%s: 9 eggs back after a rebuild (%d)" % [arc, eggs.size()])
		# The again line while the hunt is on.
		picks = []
		t.later(t._festival_event.bind("egg"))
		await _drive()
		check(_eggs(t).size() == 9, "%s: asking again doesn't re-hide" % arc)
		_hide_npcs(t)
		for c: Vector2i in eggs:
			t.interact(c, t.things[c])
		for k in 20:
			await process_frame
		check(GameState.run["flags"].has(key + "_done"), "%s: hunt done" % arc)
		check(int(GameState.run["crystals"]) - money0 >= 200, "%s: hunt paid" % arc)
		# The kids hunt too: wait out their timer with a fresh hunt on the next year's egg day.
		GameState.run["day"] = 126
		GameState.run["time"] = 11 * 60
		t = await _go()
		picks = [0]
		t.later(t._festival_event.bind("egg"))
		await _drive()
		check(_eggs(t).size() == 16, "%s: 16 eggs in year 2 (%d)" % [arc, _eggs(t).size()])
		var gold := 0
		for c: Vector2i in _eggs(t):
			gold += int(bool(t.things[c].get("golden", false)))
		check(gold == 1, "%s: one golden egg" % arc)
		for k in int(t.kid_every() * 60.0 * 2.0) + 30:
			await process_frame
		check(int(GameState.run["flags"].get("fest_egg_kids_126", 0)) >= 2 and _eggs(t).size() <= 14, "%s: the kids took eggs (%d)" % [arc, int(GameState.run["flags"].get("fest_egg_kids_126", 0))])
		# Lantern float (summer 14 evening).
		GameState.run["day"] = 42
		GameState.run["time"] = int(GameState.sunset()) - 60
		t = await _go()
		var hp0 := int(GameState.run.get("max_hp", 0))
		var e0 := int(GameState.run.get("max_energy", 0))
		picks = [0, 0, 0]
		t.later(t._festival_event.bind("lantern"))
		await _drive()
		check(GameState.run["flags"].has("fest_lantern_42"), "%s: lantern floated" % arc)
		var grew := int(GameState.run.get("max_hp", 0)) - hp0
		check(grew >= 3 and grew <= 5 or int(GameState.run.get("max_energy", 0)) != e0, "%s: lantern grows a vital (%d)" % [arc, grew])
		# Crop contest (fall 14).
		GameState.run["day"] = 70
		GameState.run["time"] = 11 * 60
		t = await _go()
		var crop := ""
		for id in GameState.items:
			if t.contest_crop(str(id)):
				crop = str(id)
				break
		GameState.add_item(crop, 2)
		picks = [0]
		t.later(t._festival_event.bind("harvest"))
		await _drive()
		check(int(GameState.run["flags"].get("fest_harvest_70_place", 0)) in [1, 2, 3], "%s: crop contest placed" % arc)
		# Star wish (winter 14 evening).
		GameState.run["day"] = 98
		GameState.run["time"] = int(GameState.sunset()) - 60
		var known := ""
		for id in GameState.npcs:
			if Hearts.in_arc(str(id)):
				known = str(id)
				break
		GameState.run["friendship"][known] = 20
		t = await _go()
		picks = [0, 0]
		t.later(t._festival_event.bind("star"))
		await _drive()
		check(GameState.run["flags"].has("fest_star_98"), "%s: star wish made" % arc)
		check(int(GameState.run["friendship"][known]) >= 30, "%s: everyone you know +10 (%d)" % [arc, int(GameState.run["friendship"][known])])
		# New town festivals: each runs once and gives the again line after.
		for f: Array in [["blossom", 80, [0, 0, 0, 0, 0, 0]], ["founders", 133, [0, 0, 0, 0]], ["hollow", 111, [0, 0, 0, 0]], ["winter_market", 94, [1, 0, 1, 2]], ["gift_swap", 112, [0]]]:
			var fid: String = f[0]
			GameState.run["day"] = int(f[1])
			GameState.run["time"] = 12 * 60
			GameState.add_item("candy", 3)
			picks = (f[2] as Array).duplicate()
			t.later(t._festival_event.bind(fid))
			await _drive()
			check(GameState.run["flags"].has("fest_%s_%d" % [fid, int(f[1])]), "%s: %s played" % [arc, fid])
	# Tide Feast on the beach (summer 24): the venue spot, alcohol refused, a dish lifts the town.
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["day"] = 52
	GameState.run["time"] = 12 * 60
	check(FestivalExtra.is_alcohol("wine") and not FestivalExtra.is_alcohol("cake"), "wine is no potluck dish")
	check(FestivalExtra.potluck_band("wine") == 0, "alcohol scores nothing")
	GameState.run["flags"]["beach_seen"] = true
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/beach.tscn")
	for k in 12:
		await process_frame
	var b := current_scene as GameMap
	var spot := Vector2i(-1, -1)
	for c: Vector2i in b.things:
		if str(b.things[c].get("type", "")) == "festival_venue":
			spot = c
	check(spot.x >= 0, "Tide Feast spot on the beach")
	var fr := ""
	for id in GameState.npcs:
		if Hearts.in_arc(str(id)):
			fr = str(id)
			break
	GameState.run["friendship"][fr] = 10
	GameState.add_item("cake", 1)
	if spot.x >= 0:
		picks = [0]
		b.interact(spot, b.things[spot])
		await _drive()
		check(GameState.run["flags"].has("fest_tide_feast_52"), "potluck entered")
		check(int(GameState.run["friendship"][fr]) > 10, "the pot lifts the town (%d)" % int(GameState.run["friendship"][fr]))
	GameState.run["day"] = 53
	b = null
	change_scene_to_file("res://scenes/beach.tscn")
	for k in 12:
		await process_frame
	var none := true
	for c: Vector2i in (current_scene as GameMap).things:
		if str((current_scene as GameMap).things[c].get("type", "")) == "festival_venue":
			none = false
	check(none, "no Tide Feast spot the next day")
	print("festival_events_test: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
