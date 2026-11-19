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


## The lead-in: from day 3 until the grand opening, villagers talk about the works.
static func soon_lines() -> Array:
	if GameState.run.is_empty() or is_open() or int(GameState.run["day"]) < 3:
		return []
	var out: Array = []
	for l in data().get("chat_soon" if GameState.is_penguins() else "chat_soon_gang", []):
		out.append(_fill(str(l)))
	return out


## Town door: shut (with a word about the opening) until the grand opening.
static func door_closed(m: GameMap, thing: Dictionary) -> bool:
	if str(thing.get("interior", "")) != "rec":
		return false
	if is_open():
		var why := why_closed()
		if why != "":
			m.hud.toast(why, Color(1, 0.9, 0.6))
			return true
		return false
	var day := int(GameState.run["day"])
	var od := int(data().get("building", {}).get("open_day", 7))
	var when := "soon" if day >= od else ("in %d day%s" % [od - day, "" if od - day == 1 else "s"])
	m.hud.toast("A painted banner: %s · GRAND OPENING %s!" % [name().to_upper(), when.to_upper()], Color(1, 0.9, 0.6))
	return true


# ---- hours ------------------------------------------------------------------------

## [open hour, close hour] (close may be 24 = midnight).
static func hours() -> Array:
	var h: Array = data().get("building", {}).get("hours", [9, 24])
	return [int(h[0]), int(h[1])]


## "" while the doors are open, else the sign (closed for the night, or festival day).
static func why_closed() -> String:
	if GameState.run.is_empty():
		return ""
	var h := (int(GameState.run.get("time", 0)) % 1440) / 60.0
	var oh := hours()
	if h < float(oh[0]) or h >= float(oh[1]):
		return "%s: closed for the night. Open %s." % [name(), TownHours.hours_text(int(oh[0]), int(oh[1]))]
	if GameState.festival_today() != "" and h >= 9.0 and h < 18.0:
		return "%s: closed today. Everyone's at the %s on the plaza." % [name(), GameState.festival_name(GameState.festival_today())]
	return ""


## Acts that need the place open (the stairs, the door and looking around always work).
const NEEDS_OPEN := ["lane", "cabinet", "claw", "skee", "snack", "soda", "prize", "jukebox", "shoes"]


# ---- villagers ------------------------------------------------------------------

## Does a slot's day rule match this day? ("all", "rest", "league", "rain" or [day % 7, ...])
static func _day_ok(days: Variant, day: int) -> bool:
	if days is Array:
		return (days as Array).has(float(day % 7)) or (days as Array).has(day % 7)
	match str(days):
		"all": return true
		"rest": return is_rest_day(day)
		"league": return day % 7 == 3
		"rain": return GameState.is_wet() or GameState.weather_today() == "blizzard"
	return false


## The 6th and 7th day of every week (the town's weekend).
static func is_rest_day(day := -1) -> bool:
	if day < 0:
		day = int(GameState.run.get("day", 1))
	return day % 7 == 6 or day % 7 == 0


## The slot a villager is in right now ({} if none): [days, from, to, floor].
static func slot_now(npc_id: String) -> Array:
	if not is_open() or why_closed() != "":
		return []
	var v: Dictionary = data().get("visitors", {}).get(npc_id, {})
	if v.is_empty() or GameState.festival_today() != "" or not GameState.npc_present(npc_id):
		return []
	var t := int(GameState.run["time"]) % 1440
	var hour := t / 60.0
	var day := int(GameState.run["day"])
	for s: Array in v.get("slots", []):
		if hour < float(s[1]) or hour >= float(s[2]):
			continue
		if _day_ok(s[0], day):
			return s
	return []


## Today's visits as {floor: [[npc id, from hour, to hour], ...]}: only the hours each
## villager really comes (never while they're at work), checked half-hour by half-hour.
static func today_visits() -> Dictionary:
	var out := {"rec": [], "rec_up": []}
	if GameState.run.is_empty() or not is_open():
		return out
	var keep := int(GameState.run["time"])
	var day0 := keep - keep % 1440
	var ids: Array = data().get("visitors", {}).keys()
	ids.sort()
	for id in ids:
		var spans := {}  # floor -> [from, to]
		for hh in range(0, 48):
			GameState.run["time"] = day0 + hh * 30
			var s := slot_now(str(id))
			if s.is_empty() or Npc.place_now(GameState.npcs.get(id, {}).get("routine", []), str(id)) != "rec":
				continue
			var fl := str(s[3])
			if not spans.has(fl):
				spans[fl] = [hh / 2.0, hh / 2.0 + 0.5]
			else:
				spans[fl][1] = hh / 2.0 + 0.5
		for fl in spans:
			out[fl].append([str(id), float(spans[fl][0]), float(spans[fl][1])])
	GameState.run["time"] = keep
	return out


static func _clock(h: float) -> String:
	var hi := int(h) % 24
	var mins := int(round((h - floorf(h)) * 60.0))
	var base := "midnight" if hi == 0 and mins == 0 else ("%d" % (hi if hi <= 12 and hi > 0 else (12 if hi == 0 else hi - 12)))
	if base == "midnight":
		return base
	return base + (":%02d" % mins if mins > 0 else "") + ("am" if hi < 12 else "pm")


## The front desk's "What's on today?": who comes in when, on which floor.
static func today_lines() -> Array:
	var day := int(GameState.run["day"])
	var dw: Dictionary = data().get("day_words", {})
	var head := "Today is %s." % (str(dw.get("league", "league night")) if day % 7 == 3 else (str(dw.get("rest", "a rest day")) if is_rest_day(day) else "a working day: folks drop in after work and school"))
	var oh := hours()
	head += "  Open %s." % TownHours.hours_text(int(oh[0]), int(oh[1]))
	if GameState.festival_today() != "":
		head += "  Closed until 6pm for the %s." % GameState.festival_name(GameState.festival_today())
	var tv := today_visits()
	var lines: Array = [{"who": "Front desk", "text": head}]
	for fl in ["rec", "rec_up"]:
		var bits: Array = []
		for e: Array in tv[fl]:
			var nm := str(GameState.npcs.get(str(e[0]), {}).get("name", str(e[0]).capitalize()))
			bits.append("%s %s-%s" % [nm, _clock(float(e[1])), _clock(float(e[2]))])
		var where := "Arcade floor" if fl == "rec" else "Lanes upstairs"
		lines.append({"who": "Front desk", "text": "%s: %s." % [where, ", ".join(bits) if not bits.is_empty() else "nobody booked in, so take your pick"]})
	if GameState.is_wet():
		lines.append({"who": "Front desk", "text": "It's raining, so expect a crowd this afternoon."})
	return lines


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
		if Npc.place_now(GameState.npcs.get(id, {}).get("routine", []), str(id)) != "rec":
			continue  # still at work: their slot waits
		var kind := str(data()["visitors"][id].get("spot", "lobby"))
		var pool: Array = st.get(kind, []) + st.get("lobby", [])
		for c in pool:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if not used.has(cc):
				used[cc] = true
				out[str(id)] = cc
				break
	return out


## Interior hook: a villager may stand on this thing's cell (a lane approach: the
## bowler holds the lane, and talking to them offers a game together).
static func stand_on(thing: Variant) -> bool:
	return thing is Dictionary and str(thing.get("type", "")) == "rec" and str(thing.get("act", "")) == "lane"


static var _lt_key := ""
static var _lt: Dictionary = {}


## Lanes taken by villagers right now (lane number -> npc id). Cached per game minute
## (RecDecor asks every frame).
static func lanes_taken() -> Dictionary:
	if GameState.run.is_empty():
		return {}
	var key := "%d:%d:%s:%d" % [int(GameState.run.get("day", 0)), int(GameState.run.get("time", 0)), GameState.weather_today(), GameState.run.get("flags", {}).size()]
	if key == _lt_key:
		return _lt
	_lt = _lanes_taken()
	_lt_key = key
	return _lt


static func _lanes_taken() -> Dictionary:
	var out := {}
	var cells := stand_cells("rec_up")
	var lane_pool := {}
	for a in data().get("stands", {}).get("rec_up", {}).get("lane", []):
		lane_pool[Vector2i(int(a[0]), int(a[1]))] = true
	for id in cells:
		var c: Vector2i = cells[id]
		if not lane_pool.has(c):
			continue  # watching from the lobby, not bowling
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
		return soon_lines()
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


## Interior._talk hook for a visitor: their line, and if they're standing at a
## cabinet (so the player can't reach it) they offer you a go and step aside.
static func visitor_talk(m: GameMap, n: Npc) -> void:
	var cab := cabinet_above(m, n.cell())
	var cab_name := str(cab.get("hint", "")).trim_prefix("A: play ")
	var lines := chat(n.id, cab_name)
	var ln := lane_of(n.id)
	if ln > 0 and is_rec(m) and bool((m.get("I") as Dictionary).get("lanes", false)):
		var lastl: Dictionary = (lines[-1] as Dictionary).duplicate()
		lastl["choice"] = ["Bowl a game together", "Not now"]
		lastl["key"] = ""
		var dl := Dialogue.instance(m.get_tree())
		dl.say(lines.slice(0, lines.size() - 1) + [lastl])
		await dl.finished
		if dl.last_choice == 0:
			await bowl_with(m, n.id, ln)
		return
	if cab.is_empty():
		await m.say(lines)
		return
	var who := str(lines[0].get("who", n.id.capitalize()))
	var last: Dictionary = (lines[-1] as Dictionary).duplicate()
	last["choice"] = ["Can I have a go?", "Not now, carry on"]
	last["key"] = ""
	var d := Dialogue.instance(m.get_tree())
	d.say(lines.slice(0, lines.size() - 1) + [last])
	await d.finished
	if d.last_choice != 0:
		return
	var spot := step_aside_cell(m, n.cell())
	if spot == Vector2i(-1, -1):
		await m.say([{"who": who, "text": "Nearly done, promise. One more life!"}])
		return
	await m.say([{"who": who, "text": "All yours. %s eats coins, so aim well!" % cab_name if cab_name != "" else "All yours!"}])
	n.home = m.cell_center(spot)
	n.position = n.home
	n.set("_target", n.home)
	n.face(m.cell_center(n.cell() + Vector2i(0, -1)))
	m.player.frozen = false
	if why_closed() != "":
		m.hud.toast(why_closed(), Color(1, 0.9, 0.6))
		return
	_cabinet(m, str(cab.get("game", "")))


## The cabinet thing just above a cell ({} if none).
static func cabinet_above(m: GameMap, c: Vector2i) -> Dictionary:
	var th: Variant = m.things.get(c + Vector2i(0, -1), null)
	if th is Dictionary and str(th.get("type", "")) == "rec" and str(th.get("act", "")) == "cabinet":
		return th
	return {}


## A free floor cell beside a cabinet front where a visitor can watch from:
## never in front of another cabinet, never under furniture or someone else.
static func step_aside_cell(m: GameMap, c: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, 2)]:
		var cc := c + d
		if cc.x < 1 or cc.y < 1 or cc.x >= m.cols - 1 or cc.y >= m.rows - 1:
			continue
		if m.blocked.has(cc) or m.things.has(cc) or not cabinet_above(m, cc).is_empty():
			continue
		if m.blocked.has(cc + Vector2i(0, -1)) and d.y == 0:
			continue  # not tucked under a pot plant or a machine: watch from an open spot
		if m.player and m.world_to_cell(m.player.position) == cc:
			continue
		if m.has_method("has_npc_at") and bool(m.call("has_npc_at", cc)):
			continue
		return cc
	return Vector2i(-1, -1)


## Where a visitor is spending the visit: "cab", "lane" or "lobby" (lane folk downstairs
## on a rainy day are in the lobby).
static func spot_kind(npc_id: String) -> String:
	var kind := str(data().get("visitors", {}).get(npc_id, {}).get("spot", "lobby"))
	var fl := floor_of(npc_id)
	if kind == "lane" and fl != "rec_up":
		return "lobby"
	if kind == "cab" and fl == "rec_up":
		return "lobby"
	return kind


## The lane a villager is bowling on right now (0 = none).
static func lane_of(npc_id: String) -> int:
	var taken := lanes_taken()
	for n in taken:
		if str(taken[n]) == npc_id:
			return int(n)
	return 0


## What a villager says inside the rec center: what they're doing (league night, a rainy
## afternoon, their cabinet or lane), then their own lines about the place.
## `game` is the cabinet in front of them, if any.
static func chat(npc_id: String, game := "") -> Array:
	var who := str(GameState.npcs.get(npc_id, {}).get("name", npc_id.capitalize()))
	var pool: Array = []
	var s := slot_now(npc_id)
	if not s.is_empty():
		if is_league_night() and str(s[3]) == "rec_up":
			pool.append_array((data().get("chat_league_own", {}) as Dictionary).get(npc_id, []))
			pool.append_array(data().get("chat_league", []))
		elif str(s[0]) == "rain":
			pool.append_array(data().get("chat_rain", []))
		var kind := spot_kind(npc_id)
		if kind == "lane" and lane_of(npc_id) == 0:
			kind = "lobby"
		if kind != "cab" or game != "":
			for l in (data().get("chat_spot", {}) as Dictionary).get(kind, []):
				pool.append(str(l).replace("{game}", game))
	for l in talk_pool(npc_id):
		pool.append(l)
	if pool.is_empty():
		pool = [_fill("Good to see you at the {hall}.")]
	var pick := str(pool[absi(int(GameState.run["day"]) + hash(npc_id) + int(GameState.run["time"]) / 30) % pool.size()])
	return [{"who": who, "text": _fill(pick)}]


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
	if act in NEEDS_OPEN and why_closed() != "":
		m.hud.toast(why_closed(), Color(1, 0.9, 0.6))
		return
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
		var tid := str(taken[lane])
		var who := str(GameState.npcs.get(tid, {}).get("name", "Someone"))
		var dj := Dialogue.instance(m.get_tree())
		dj.say([{"who": "", "text": "%s is bowling on lane %d. Lane %d is the house lane, always kept free." % [who, lane, house_lane()],
			"choice": ["Bowl with %s" % who, "Not now"], "key": ""}])
		await dj.finished
		if dj.last_choice == 0:
			await bowl_with(m, tid, lane)
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


static func house_lane() -> int:
	return int(data().get("building", {}).get("house_lane", 4))


## A villager's score for today's game with you (steady for the day: their average
## give or take 25, so a rematch tomorrow can go the other way).
static func rival_score(npc_id: String) -> int:
	var avg := int(data().get("bowl_avg", {}).get(npc_id, 100))
	var swing := absi(hash("%s:%d" % [npc_id, int(GameState.run.get("day", 1))])) % 51 - 25
	return clampi(avg + swing, 30, 279)


## A game side by side with a villager on their lane: you pay as usual, they bowl
## their game, and afterwards you compare cards. Bowling together is a good evening:
## friendship once a day per villager (more if you win), and a few bonus tickets for a win.
static func bowl_with(m: GameMap, npc_id: String, lane: int) -> void:
	if why_closed() != "":
		m.hud.toast(why_closed(), Color(1, 0.9, 0.6))
		return
	var who := str(GameState.npcs.get(npc_id, {}).get("name", npc_id.capitalize()))
	var free := bool(GameState.run["flags"].get("rec_free_game", false))
	var cost := 0 if free else fee()
	if int(GameState.run["crystals"]) < cost:
		m.hud.toast("Not enough crystals for a game (%s)." % Money.amount(cost), Color(1, 0.7, 0.7))
		return
	GameState.run["crystals"] = int(GameState.run["crystals"]) - cost
	GameState.run["flags"].erase("rec_free_game")
	var res: Dictionary = await Bowling.play(m, lane)
	finish_game(m, res)
	if res.is_empty() or not bool(res.get("done", false)):
		await m.say([{"who": who, "text": "Leaving already? I'll finish the frame for you."}])
		return
	await m.say(together_result(npc_id, int(res.get("score", 0)), m))


## The talk after a game together (and its rewards). Shared with the headless test.
static func together_result(npc_id: String, you: int, m: GameMap = null) -> Array:
	var who := str(GameState.npcs.get(npc_id, {}).get("name", npc_id.capitalize()))
	var them := rival_score(npc_id)
	var res: Dictionary = data().get("chat_result", {})
	var said: Array = res.get(npc_id, res.get("_", ["", "", ""]))
	var k := 0 if you > them else (1 if you < them else 2)
	var text := str(said[k]).replace("{you}", str(you)).replace("{them}", str(them))
	var f: Dictionary = GameState.run["flags"]
	var key := "rec_bowled_" + npc_id
	var gain := 0
	if int(f.get(key, -1)) != int(GameState.run["day"]):
		f[key] = int(GameState.run["day"])
		gain = 8 if k == 0 else 5
		GameState.add_friend(npc_id, gain)
	if k == 0:
		Tickets.add(10, "rival")
	if m:
		var note := "%s bowled %d · you %d" % [who, them, you]
		if gain > 0:
			note += " · %s +%d" % [who, gain]
		if k == 0:
			note += " · +10 tickets"
		m.hud.toast(note, Color(1, 0.85, 0.95))
	return [{"who": who, "text": text}]


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
	var opts := ["What's on today?", "Tickets & scores", "What's here?", "Leave"]
	var shut := why_closed()
	var hi := "Welcome to the %s! You have %d tickets.%s" % [name(), Tickets.count(), "  Tonight is LEAGUE NIGHT." if is_league_night() else ""]
	if shut != "":
		hi = "We're closed, hon. Open %s. You have %d tickets." % [TownHours.hours_text(int(hours()[0]), int(hours()[1])), Tickets.count()]
	d.say([{"who": "Front desk", "text": hi, "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice == 0:
		await m.say(today_lines())
	elif d.last_choice == 1:
		await _scores(m)
	elif d.last_choice == 2:
		await m.say([{"who": "Front desk", "text": "Bowling upstairs (◆%d a game). Arcade cabinets along the back wall. Every game pays tickets; the prize counter takes them. Open %s." % [fee(), TownHours.hours_text(int(hours()[0]), int(hours()[1]))]},
			{"who": "Front desk", "text": "Folks drop in after work and school, all afternoon on rest days (the 6th and 7th of each week), and when it rains. League night is the 3rd, 10th, 17th and 24th."},
			{"who": "Front desk", "text": "If someone's on a lane, ask to bowl with them: it's friendlier than it looks. Lane %d is the house lane, kept free for walk-ins. Some prizes only come out for high scores: a 100, a 160, a 200 game..." % house_lane()}])


static func _scores(m: GameMap) -> void:
	var lines: Array = ["Bowling best: %d  (%d games)" % [Tickets.best_score("bowling"), Tickets.plays("bowling")]]
	var names: Dictionary = Tickets.prizes().get("game_names", {})
	for g in names:  # every cabinet, the claw and skee-ball you've played
		if str(g) != "bowling" and Tickets.plays(str(g)) > 0:
			lines.append("%s: %d" % [str(names[g]), Tickets.best_score(str(g))])
	lines.append("Tickets: %d on hand, %d won in all." % [Tickets.count(), Tickets.earned()])
	var house := {"bowling": 0}
	for id in data().get("visitors", {}):
		house["bowling"] = maxi(int(house["bowling"]), 90 + absi(hash(str(id))) % 120)
	lines.append("House record: %d%s" % [maxi(int(house["bowling"]), Tickets.best_score("bowling")), "  (yours!)" if Tickets.best_score("bowling") >= int(house["bowling"]) else ""])
	await m.say([{"who": "High scores", "text": "\n".join(lines)}])


const JUKEBOX := ["rec_center", "neon", "festival", "inn", "town", "beach", "uptown", "countryside"]


## The record the jukebox is playing today ("" = the house song). It lasts the day,
## on both floors, and survives an arcade game (GameMap.area_track asks music_for).
static func jukebox_track() -> String:
	if GameState.run.is_empty():
		return ""
	var f: Dictionary = GameState.run.get("flags", {})
	if int(f.get("rec_juke_day", -1)) != int(GameState.run.get("day", 0)):
		return ""
	var t := str(f.get("rec_juke", ""))
	return t if t != "" and Music.has_track(t) else ""


## GameMap.area_track hook: inside the rec, today's jukebox record wins over the house song.
static func music_for(m: GameMap, t: String) -> String:
	if not is_rec(m):
		return t
	var j := jukebox_track()
	return j if j != "" else t


static func _jukebox(m: GameMap) -> void:
	var mus := Music.instance(m.get_tree())
	var now := mus.wanted()
	var cur := JUKEBOX.find(now)
	for i in range(1, JUKEBOX.size() + 1):
		var t: String = JUKEBOX[(cur + i) % JUKEBOX.size()]
		if t == now or not Music.has_track(t):
			continue  # a new record, never the one already playing
		GameState.run["flags"]["rec_juke"] = t
		GameState.run["flags"]["rec_juke_day"] = int(GameState.run["day"])
		mus.play(t)
		mus.sfx("ui_tap", "ui_tap")
		m.hud.toast("♪ The jukebox clunks and spins a new record.", Color(0.9, 0.85, 1))
		return


## The claw machine: ◆10 a go, a plush now and then (better luck with Luck).
static func _claw(m: GameMap) -> void:
	# The full claw game (agent a2's ArcadeClaw) when it is there.
	for g in ProjectSettings.get_global_class_list():
		if str(g.get("class", "")) == "ArcadeHub":
			await (load(str(g.get("path", ""))).call("open", m, "claw") as CanvasLayer).closed
			return
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
