class_name RecCenter
extends RefCounted
## The Rec Center (penguins) / Rec Hall (gangsters): a two-floor hub in town.
## Ground floor: lobby, prize counter, front desk, arcade cabinets; upstairs: four
## bowling lanes. Villagers drop in on schedule (data/rec.json "visitors") and talk
## about it. Data: tools/gen_rec.py. Tickets: Tickets. Bowling: Bowling. Prizes: PrizeScreen.
##
## Arcade cabinets call ArcadeHub.open(map, game_id) when that class exists (agent a2's
## games); the cabinet says "Coming soon" until then.

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = GameState.load_json("res://data/rec.json")
	return _d


static func name() -> String:
	return str(_bld().get("name", "Rec Center"))


static func _bld() -> Dictionary:
	var b: Dictionary = data().get("building", {})
	return b.get("penguins" if GameState.is_penguins() else "gangsters", {})


static func fee() -> int:
	return int(data().get("building", {}).get("fee", 25))


static func is_open() -> bool:
	return not GameState.run.is_empty() and GameState.run.get("flags", {}).has("rec_open")


## Each morning (Mail.morning): the grand opening once the town knows you and a week has gone by.
static func morning() -> void:
	if GameState.run.is_empty() or is_open():
		return
	var day := int(GameState.run["day"])
	if day < int(data().get("building", {}).get("open_day", 7)) or not GameState.quest_done("meet_town"):
		return
	open_now()


static func open_now() -> void:
	var f: Dictionary = GameState.run["flags"]
	f["rec_open"] = int(GameState.run["day"])
	var pen := GameState.is_penguins()
	var who := "Mayor Alder" if pen else "Sal"
	var text := ("The %s opens today, south-east of the library! Bowling upstairs, arcade cabinets, and a prize counter you won't believe. Your first game is on the house. Ribbon at nine. - Alder" if pen
		else "That old hotel by the library? Somebody turned it into the %s. Lanes upstairs, cabinets downstairs, a prize counter. Nobody brings heat inside. First game's on the house. - Sal") % name()
	Mail.send(who, text, "chat")
	f["rec_free_game"] = true
	GameState.add_quest("rec_visit", "Visit the new %s south-east of the library (first game free)." % name())
	GameState.add_hint("The %s (south-east of the library): bowling upstairs, arcade cabinets and a prize counter. Win tickets, trade them for prizes." % name())


## The town lot: the building, its lane, a sign. Called from town._place_buildings;
## returns the door cell (town carves a lane to it).
static func place_town(m: GameMap) -> Vector2i:
	var b := _bld()
	var c: Array = data().get("building", {}).get("cell", [47, 78])
	var spr := str(b.get("sprite", "house_2"))
	if not Art.has("buildings", spr):
		spr = "house_2"
	var sc := float(b.get("scale", 0.8))
	var info := Art.info("buildings", spr)
	var w_cells := maxi(1, int(round(float(info.get("w", 64)) * sc / GameMap.TILE)))
	# Centre narrower skins on the same door column as the wide one.
	var x0 := 54 - w_cells / 2
	var h_cells := maxi(1, int(round(float(info.get("h", 64)) * sc / GameMap.TILE)))
	var y0 := 85 - h_cells + 1
	var door := m.building(spr, Vector2i(x0, y0), "rec", "A: " + name(), sc)
	if door == Vector2i(-1, -1):
		return door
	var sign := RecDecor.new()
	sign.mode = "sign"
	sign.position = m.cell_pos(door.x + 3, door.y + 1)
	m.add_child(sign)
	m.blocked[Vector2i(door.x + 3, door.y)] = true
	for p: Array in [["bench2_wood_a", Vector2i(door.x - 5, door.y + 1)], ["flowerbed_pink", Vector2i(door.x - 3, door.y)], ["flowerbed_yellow", Vector2i(door.x + 5, door.y)]]:
		if Art.has("props", str(p[0])):
			m.prop("props", str(p[0]), p[1], 1 if str(p[0]).begins_with("bench") else 0)
	if not GameState.is_penguins() and Art.has("props", "neon_open"):
		m.anim_prop("props", "neon_open", Vector2i(door.x + 1, door.y - 1), 0, 2.0)
	return door


static func lane_rect() -> Rect2i:
	var a: Array = data().get("building", {}).get("lane", [44, 87, 12, 2])
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


## The lot kept clear of tree clumps and scatter.
static func lot_rect() -> Rect2i:
	return Rect2i(44, 74, 24, 17)


## Town door: shut (with a word about the opening) until the grand opening.
static func door_closed(m: GameMap, thing: Dictionary) -> bool:
	if str(thing.get("interior", "")) != "rec" or is_open():
		return false
	var day := int(GameState.run["day"])
	var od := int(data().get("building", {}).get("open_day", 7))
	var when := "soon" if day >= od else ("in %d day%s" % [od - day, "" if od - day == 1 else "s"])
	m.hud.toast("A painted banner: %s · GRAND OPENING %s!" % [name().to_upper(), when.to_upper()], Color(1, 0.9, 0.6))
	return true


# ---- villagers ------------------------------------------------------------------

## The slot a villager is in right now ({} if none): [days, from, to, floor].
static func slot_now(npc_id: String) -> Array:
	if not is_open():
		return []
	var v: Dictionary = data().get("visitors", {}).get(npc_id, {})
	if v.is_empty() or GameState.festival_today() != "":
		return []
	var t := int(GameState.run["time"]) % 1440
	var hour := t / 60.0
	var day := int(GameState.run["day"])
	var wet := GameState.is_wet() or GameState.weather_today() == "blizzard"
	for s: Array in v.get("slots", []):
		if hour < float(s[1]) or hour >= float(s[2]):
			continue
		var days: Variant = s[0]
		var ok := false
		if days is Array:
			ok = (days as Array).has(float(day % 7)) or (days as Array).has(day % 7)
		else:
			match str(days):
				"all": ok = true
				"rest": ok = day % 7 == 6 or day % 7 == 0
				"league": ok = day % 7 == 3
				"rain": ok = wet
		if ok:
			return s
	return []


## Npc.place_now hook: "rec" while a visit slot is on (never pulls anyone off work).
static func visit(npc_id: String, place: String) -> String:
	if place == "work" or GameState.run.is_empty():
		return place
	var s := slot_now(npc_id)
	return "rec" if not s.is_empty() else place


static func floor_of(npc_id: String) -> String:
	var s := slot_now(npc_id)
	return str(s[3]) if s.size() > 3 else ""


static func is_league_night() -> bool:
	return is_open() and int(GameState.run["day"]) % 7 == 3


## Where the villagers on this floor stand: lane approaches, cabinets, the lobby.
static func stand_cells(interior_id: String) -> Dictionary:
	var out := {}
	var st: Dictionary = data().get("stands", {}).get(interior_id, {})
	var used := {}
	var ids: Array = data().get("visitors", {}).keys()
	ids.sort()
	for id in ids:
		if floor_of(str(id)) != interior_id or GameState.run["flags"].has(str(id) + "_gone"):
			continue
		var kind := str(data()["visitors"][id].get("spot", "lobby"))
		var pool: Array = st.get(kind, []) + st.get("lobby", [])
		for c in pool:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if not used.has(cc):
				used[cc] = true
				out[str(id)] = cc
				break
	return out


## Lanes taken by villagers right now (lane number -> npc id).
static func lanes_taken() -> Dictionary:
	var out := {}
	var cells := stand_cells("rec_up")
	for id in cells:
		var c: Vector2i = cells[id]
		for ln in data().get("lanes", []):
			var x := int(ln["x"])
			if c.y >= int(data().get("lane_foul", 11)) and (c.x == x or c.x == x + 1):
				out[int(ln["n"])] = id
	return out


static func _fill(s: String) -> String:
	return s.replace("{best}", str(Tickets.best_score("bowling"))).replace("{tickets}", str(Tickets.count())).replace("{hall}", name()).replace("{name}", str(GameState.run.get("names", {}).get("character", "friend")))


## Extra everyday lines for Talk.line once the place is open.
static func talk_pool(npc_id: String) -> Array:
	if not is_open():
		return []
	var out: Array = []
	var own: Array = (data().get("chat_gang", {}) as Dictionary).get(npc_id, []) if not GameState.is_penguins() else []
	if own.is_empty():
		own = (data().get("chat", {}) as Dictionary).get(npc_id, [])
	for l in own:
		out.append(_fill(str(l)))
	if Tickets.best_score("bowling") >= 80:
		for l in data().get("chat_score", []):
			out.append(_fill(str(l)))
	elif int(GameState.run["day"]) - int(GameState.run["flags"].get("rec_open", 0)) < 7:
		for l in data().get("chat_any", []):
			out.append(_fill(str(l)))
	return out


## What a villager says inside the rec center.
static func chat(npc_id: String) -> Array:
	var who := str(GameState.npcs.get(npc_id, {}).get("name", npc_id.capitalize()))
	var pool := talk_pool(npc_id)
	if is_league_night():
		pool.append("League night! Grab a lane before Gideon does.")
	if pool.is_empty():
		pool = [_fill("Good to see you at the {hall}.")]
	var pick := str(pool[(int(GameState.run["day"]) + hash(npc_id) + int(GameState.run["time"]) / 30) % pool.size()])
	return [{"who": who, "text": pick}]


# ---- inside -----------------------------------------------------------------------

static func is_rec(m: GameMap) -> bool:
	return m.get("I") is Dictionary and bool((m.get("I") as Dictionary).get("rec", false))


## Interior.build hook: arc skin and the lane/cabinet cells that block.
static func build_room(m: GameMap, I: Dictionary) -> Dictionary:
	if not GameState.is_penguins() and I.get("gangsters") is Dictionary:
		I = I.duplicate(true)
		I.merge(I["gangsters"], true)
	if bool(I.get("lanes", false)):
		var top := int(data().get("lane_top", 3))
		var foul := int(data().get("lane_foul", 11))
		for y in range(2, foul + 1):
			for x in range(1, m.cols - 1):
				m.blocked[Vector2i(x, y)] = true  # lanes, returns and pin decks
	return I


## Interior.after_ready hook: lanes, cabinets, neon. First visit pays out the opening gift.
static func dress(m: GameMap, interior_id: String) -> void:
	var I: Dictionary = m.get("I")
	var under := RecDecor.new()
	under.mode = "lanes" if bool(I.get("lanes", false)) else "floor"
	under.map = m
	m.add_child(under)
	m.to_under(under)
	var wall := RecDecor.new()
	wall.mode = "wall"
	wall.map = m
	wall.z_index = 1
	m.add_child(wall)
	if not bool(I.get("lanes", false)):
		var bd := RecDecor.new()
		bd.mode = "board"
		bd.map = m
		bd.position = m.cell_pos(6.5, 3)
		m.add_child(bd)
	if not GameState.run["flags"].has("rec_visited"):
		GameState.run["flags"]["rec_visited"] = true
		if GameState.has_quest("rec_visit") and GameState.complete_quest("rec_visit"):
			m.hud.toast("Quest complete: visit the %s" % name(), Color(1, 0.9, 0.4))
		Tickets.add(20, "welcome")
		m.hud.toast("Welcome gift: +20 tickets", Color(1, 0.85, 0.5))


## Every "rec" thing in both rooms.
static func use(m: GameMap, thing: Dictionary, c: Vector2i) -> void:
	var act := str(thing.get("act", ""))
	match act:
		"up":
			GameMap.next_interior = "rec_up"
			m.go_to("interior", m.cell_center(Vector2i(8, 16)), "up")
		"prize":
			await PrizeScreen.open(m)
		"desk":
			await _desk(m)
		"scores":
			await _scores(m)
		"jukebox":
			_jukebox(m)
		"soda":
			await _soda(m)
		"shoes":
			await m.say([{"who": "", "text": "Rental shoes in every size, sprayed fresh. Somebody has written YOUR SIZE on a pair, in your handwriting. Spooky."}])
		"cabinet":
			_cabinet(m, str(thing.get("game", "")))
		"claw":
			await _claw(m)
		"skee":
			await _skee(m)
		"snack":
			await _snack(m)
		"trophies":
			await _trophies(m)
		"lane":
			await _lane(m, int(thing.get("lane", 1)))


static func _cabinet(m: GameMap, game: String) -> void:
	var hub: Variant = null
	for g in ProjectSettings.get_global_class_list():
		if str(g.get("class", "")) == "ArcadeHub":
			hub = load(str(g.get("path", "")))
			break
	if hub != null and hub.has_method("open"):
		hub.call("open", m, game)  # ArcadeHub.open(map, game_id): agent a2's games
		return
	var nm := str((Tickets.prizes().get("game_names", {}) as Dictionary).get(game, game.capitalize()))
	m.hud.toast("%s: coming soon. The screen says INSERT COIN, then giggles." % nm, Color(0.8, 0.95, 1))
	Music.instance(m.get_tree()).sfx("beep", "ui_tap")


static func _lane(m: GameMap, lane: int) -> void:
	var taken := lanes_taken()
	if taken.has(lane):
		var who := str(GameState.npcs.get(str(taken[lane]), {}).get("name", "Someone"))
		m.hud.toast("%s is bowling on lane %d. Try another lane." % [who, lane], Color(1, 0.9, 0.7))
		return
	var free := bool(GameState.run["flags"].get("rec_free_game", false))
	var cost := 0 if free else fee()
	var d := Dialogue.instance(m.get_tree())
	var best := Tickets.best_score("bowling")
	var txt := ("Lane %d. First game's on the house!" % lane) if free else ("Lane %d. One game, ten frames: ◆%d.  (you have ◆%d)" % [lane, cost, int(GameState.run["crystals"])])
	if best > 0:
		txt += "  Your best: %d." % best
	d.say([{"who": "", "text": txt, "choice": ["Bowl", "How to play", "Not now"], "key": ""}])
	await d.finished
	if d.last_choice == 1:
		await m.say([{"who": "", "text": "1) LEFT/RIGHT moves you along the line. UP/DOWN sets the spin (the ball hooks late). Press USE."},
			{"who": "", "text": "2) The aim arrow swings: USE to lock it.  3) The power meter rises and falls: USE to throw. Aim for the pocket, just right of the head pin."},
			{"who": "", "text": "Strikes and spares score extra, like real bowling. Tickets by score at the end: trade them at the prize counter downstairs."}])
		return
	if d.last_choice != 0:
		return
	if int(GameState.run["crystals"]) < cost:
		m.hud.toast("Not enough crystals for a game.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	GameState.run["flags"].erase("rec_free_game")
	var res: Dictionary = await Bowling.play(m, lane)
	finish_game(m, res)


## Pays out a finished (or abandoned) game. Shared with the headless test.
static func finish_game(m: GameMap, res: Dictionary) -> int:
	if res.is_empty() or not bool(res.get("done", false)):
		if m:
			m.hud.toast("Game abandoned. No tickets.", Color(1, 0.8, 0.7))
		return 0
	var score := int(res.get("score", 0))
	var t := tickets_for(score, int(res.get("strikes", 0)), int(res.get("spares", 0)))
	var best := Tickets.set_best("bowling", score)
	Tickets.add(t, "bowling")
	if score >= 120:
		GameState.run["flags"]["bowl_120"] = true
	if score >= 300:
		GameState.run["flags"]["bowl_perfect"] = true
	if m:
		m.hud.toast("Score %d%s · +%d tickets" % [score, "  NEW BEST!" if best else "", t], Color(1, 0.9, 0.4))
		Music.instance(m.get_tree()).sfx("j_victory" if best else "coin", "coin")
	return t


static func tickets_for(score: int, strikes: int, spares: int) -> int:
	return 3 + score / 10 + strikes * 2 + spares


static func _desk(m: GameMap) -> void:
	var d := Dialogue.instance(m.get_tree())
	var opts := ["Tickets & scores", "What's here?", "Leave"]
	d.say([{"who": "Front desk", "text": "Welcome to the %s! You have %d tickets.%s" % [name(), Tickets.count(), "  Tonight is LEAGUE NIGHT." if is_league_night() else ""], "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice == 0:
		await _scores(m)
	elif d.last_choice == 1:
		await m.say([{"who": "Front desk", "text": "Bowling upstairs (◆%d a game). Arcade cabinets along the back wall. Every game pays tickets; the prize counter takes them." % fee()},
			{"who": "Front desk", "text": "Some prizes only come out for high scores: a 100, a 160, a 200 game... Lanes are busy evenings and league night (every third day of the week)."}])


static func _scores(m: GameMap) -> void:
	var lines: Array = ["Bowling best: %d  (%d games)" % [Tickets.best_score("bowling"), Tickets.plays("bowling")]]
	for cab in data().get("cabinets", []):
		var g := str(cab["id"])
		if Tickets.plays(g) > 0:
			lines.append("%s: %d" % [str(cab["name"]), Tickets.best_score(g)])
	lines.append("Tickets: %d on hand, %d won in all." % [Tickets.count(), Tickets.earned()])
	var house := {"bowling": 0}
	for id in data().get("visitors", {}):
		house["bowling"] = maxi(int(house["bowling"]), 90 + absi(hash(str(id))) % 120)
	lines.append("House record: %d%s" % [maxi(int(house["bowling"]), Tickets.best_score("bowling")), "  (yours!)" if Tickets.best_score("bowling") >= int(house["bowling"]) else ""])
	await m.say([{"who": "High scores", "text": "\n".join(lines)}])


const JUKEBOX := ["rec_center", "neon", "festival", "inn", "town", "beach", "uptown", "countryside"]


static func _jukebox(m: GameMap) -> void:
	var cur := int(GameState.run["flags"].get("rec_jukebox", -1)) + 1
	for i in JUKEBOX.size():
		var t: String = JUKEBOX[(cur + i) % JUKEBOX.size()]
		if Music.has_track(t):
			GameState.run["flags"]["rec_jukebox"] = (cur + i) % JUKEBOX.size()
			Music.instance(m.get_tree()).play(t)
			m.hud.toast("♪ The jukebox clunks and spins a new record.", Color(0.9, 0.85, 1))
			return


## The claw machine: ◆10 a go, a plush now and then (better luck with Luck).
static func _claw(m: GameMap) -> void:
	var price := 10
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "", "text": "CLAW MACHINE · ◆%d a go. A teddy bear stares at you through the glass.  (you have ◆%d)" % [price, int(GameState.run["crystals"])], "choice": ["Try it", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice != 0:
		return
	if int(GameState.run["crystals"]) < price:
		m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	Music.instance(m.get_tree()).sfx("servo", "ui_tap")
	var odds := 0.12 + 0.02 * GameState.gear_stat("luck")
	var f: Dictionary = GameState.run["flags"]
	f["claw_tries"] = int(f.get("claw_tries", 0)) + 1
	if randf() < odds or int(f["claw_tries"]) >= 12:  # a pity win after a long dry run
		f["claw_tries"] = 0
		var pick: String = ["rp_teddy", "rp_penguin_plush", "rp_cat_plush"][randi() % 3]
		await m.say([{"who": "", "text": "The claw wobbles... and holds! Down the chute it comes."}])
		Music.instance(m.get_tree()).sfx("j_treasure", "levelup")
		m.give(pick, 1)
	elif randf() < 0.45:
		m.give("candy", 1, true)
		m.hud.toast("The claw drops it... and knocks a candy loose.", Color(1, 0.9, 0.7))
	else:
		m.hud.toast("So close! The claw lets go at the last second.", Color(1, 0.85, 0.7))


## Skee-ball: ◆5 for three balls, timed rolls up the ramp; tickets by the rings hit.
static func _skee(m: GameMap) -> void:
	var price := 5
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "", "text": "SKEE-BALL · ◆%d for three balls. Rings pay 10 to 50; the corner cup pays 100.  (you have ◆%d)" % [price, int(GameState.run["crystals"])], "choice": ["Roll", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice != 0:
		return
	if int(GameState.run["crystals"]) < price:
		m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	var total := 0
	var rolls: Array = []
	for i in 3:
		var r := randf() + 0.03 * GameState.gear_stat("luck")
		var pts := 100 if r > 0.95 else (50 if r > 0.82 else (40 if r > 0.65 else (30 if r > 0.45 else (20 if r > 0.25 else 10))))
		total += pts
		rolls.append(str(pts))
		Music.instance(m.get_tree()).sfx("thud", "block")
	var t := maxi(1, total / 20)
	Tickets.set_best("skee_ball", total)
	Tickets.add(t, "skee_ball")
	await m.say([{"who": "", "text": "Thunk, thunk, thunk: %s. Score %d!  +%d tickets." % [" + ".join(rolls), total, t]}])


static func _snack(m: GameMap) -> void:
	var price := 15
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "", "text": "SNACK BAR · Cotton candy ◆%d, Fizzy Pop ◆%d.  (you have ◆%d)" % [price, int(data().get("building", {}).get("soda", 12)), int(GameState.run["crystals"])], "choice": ["Cotton candy", "Fizzy Pop", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice > 1:
		return
	var cost := price if d.last_choice == 0 else int(data().get("building", {}).get("soda", 12))
	if int(GameState.run["crystals"]) < cost:
		m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	Music.instance(m.get_tree()).sfx("cash", "coin")
	m.give("rp_cotton_candy" if d.last_choice == 0 else "rp_fizzy_pop", 1)


static func _trophies(m: GameMap) -> void:
	var best := Tickets.best_score("bowling")
	var next := 100 if best < 100 else (160 if best < 160 else (220 if best < 220 else (270 if best < 270 else 300)))
	var txt := "The house trophies gleam: league cups, a golden pin, a photo of Gideon looking smug."
	txt += ("  A card: \"Bowl %d to see your name here.\"" % next) if best < 300 else "  Your name is on the top shelf. A perfect game."
	await m.say([{"who": "", "text": txt}])


static func _soda(m: GameMap) -> void:
	var price := int(data().get("building", {}).get("soda", 12))
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": "", "text": "FIZZY POP · ◆%d.  (you have ◆%d)" % [price, int(GameState.run["crystals"])], "choice": ["Buy one", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice != 0:
		return
	if int(GameState.run["crystals"]) < price:
		m.hud.toast("Not enough crystals.", Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - price
	Music.instance(m.get_tree()).sfx("drop", "pickup")
	m.give("rp_fizzy_pop", 1)


# ---- your house ---------------------------------------------------------------------

## House.after_ready hook: prize decor you own shows up at home.
static func dress_house(m: GameMap) -> void:
	var deco: Dictionary = data().get("house_decor", {})
	var shelves := {}
	for id in deco:
		if GameState.count(str(id)) < 1:
			continue
		var d: Dictionary = deco[id]
		if d.has("wall"):
			var w := RecDecor.new()
			w.mode = "house_wall"
			w.label = str(d["wall"])
			w.position = Vector2(int(d["x"]) * GameMap.TILE + 8, 2 * GameMap.TILE - 3)
			m.add_child(w)
			continue
		if d.has("shelf"):
			# A trophy shelf (once per spot) with the piece standing on its top.
			var sc := Vector2i(int(d["shelf"][0]), int(d["shelf"][1]))
			if not shelves.has(sc) and Art.has("furniture", "trophy_shelf"):
				shelves[sc] = m.prop("furniture", "trophy_shelf", sc, 1, 0.0, true, 0.5)
			var t := Art.sprite("items", str(d["name"]))
			if t:
				var tw := float(t.texture.get_height()) if t.texture else 32.0
				var ts := 13.0 / maxf(1.0, tw)
				t.scale = Vector2(ts, ts)
				t.position = m.cell_pos(sc.x + 0.35 + 0.65 * int(d.get("slot", 0)), sc.y + 1) + Vector2(0, -15)
				t.offset = Vector2(0, -t.texture.get_height() / 2.0) if t.texture else Vector2.ZERO
				m.add_child(t)
			continue
		var c := Vector2i(int(d["cell"][0]), int(d["cell"][1]))
		var g := str(d.get("group", "items"))
		var nm := str(d.get("name", ""))
		if Art.has(g, nm):
			m.prop(g, nm, c, 0, 0.0, bool(d.get("solid", false)), float(d.get("scale", 0.5)))
