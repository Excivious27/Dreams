class_name RecReno
extends RefCounted
## The rec keeps growing long after the grand opening (Tom, Guide 26 #3): a letter
## announces each renovation, the work runs a few days with that corner taped off, a
## second letter opens it. Phases come from data/rec.json "renovations" (tools/gen_rec.py
## RENOVATIONS); after the last one a seasonal Rec Cup letter keeps arriving.
##   run["flags"]["rec_reno"] = {"<id>": [start_day, open_day]}; open phases also set
##   flags "rec_reno_<id>" (quest conditions use them, e.g. the Duck Pond quest).
## Hooks: RecCenter.morning -> RecReno.morning(); RecCenter.use asks blocked(thing);
## Tickets.unlocked/lock_text ask prize_lock(tier).

## Tests and tools that want every corner open set this.
static var all_open := false


static func phases() -> Array:
	return RecCenter.data().get("renovations", [])


static func _state() -> Dictionary:
	var f: Dictionary = GameState.run["flags"]
	if not (f.get("rec_reno") is Dictionary):
		f["rec_reno"] = {}
	return f["rec_reno"]


static func _tx(v: Variant) -> String:
	if v is Dictionary:
		return str((v as Dictionary).get("penguins" if GameState.is_penguins() else "gangsters", (v as Dictionary).get("penguins", "")))
	return str(v)


static func _fill(t: String, ph: Dictionary) -> String:
	var games: Array = []
	for g in ph.get("opens", {}).get("cabinets", []):
		games.append(Tickets.game_name(str(g)))
	return t.replace("{hall}", RecCenter.name()).replace("{games}", " and ".join(games))


## Is phase `id` open? (Unknown ids count as open.)
static func is_open(id: String) -> bool:
	if all_open or GameState.run.is_empty():
		return true
	var known := false
	for ph: Dictionary in phases():
		known = known or str(ph["id"]) == id
	return not known or GameState.run["flags"].has("rec_reno_" + id)


## The phase that opens a thing, or {} when nothing waits on it.
static func _phase_for(kind: String, key: String) -> Dictionary:
	for ph: Dictionary in phases():
		var o: Dictionary = ph.get("opens", {})
		if kind == "cabinet" and key in o.get("cabinets", []):
			return ph
		if kind in ["skee", "jukebox", "cup"] and bool(o.get(kind, false)):
			return ph
	return {}


## "" when the thing is usable, else the line for the taped-off corner.
static func blocked(thing: Dictionary) -> String:
	var act := str(thing.get("act", ""))
	var ph := {}
	if act == "cabinet":
		ph = _phase_for("cabinet", str(thing.get("game", "")))
	elif act in ["skee", "jukebox"]:
		ph = _phase_for(act, "")
	if ph.is_empty() or is_open(str(ph["id"])):
		return ""
	var nm := _tx(ph.get("name", "this corner"))
	if working(str(ph["id"])):
		return "Taped off: %s is being built. Open in %s." % [nm, _days_words(days_left(str(ph["id"])))]
	return "Covered with a dust sheet. A card says: coming soon to %s." % RecCenter.name()


## Prize tier gate: "" or why the shelf is still empty.
static func prize_lock(tier: int) -> String:
	for ph: Dictionary in phases():
		var t := int(ph.get("opens", {}).get("prize_tier", 0))
		if t > 0 and tier >= t and not is_open(str(ph["id"])):
			return "Waits for %s (a renovation still to come)" % _tx(ph.get("name", "the next renovation"))
	return ""


static func working(id: String) -> bool:
	return not all_open and _state().has(id) and not GameState.run["flags"].has("rec_reno_" + id)


static func days_left(id: String) -> int:
	if not _state().has(id):
		return -1
	return maxi(0, int(_state()[id][1]) - int(GameState.run["day"]))


static func _days_words(n: int) -> String:
	return "a day" if n <= 1 else "%d days" % n


## Each morning once the rec is open: start a phase whose day has come (one at a time),
## open one whose work is done, and send the Rec Cup letter on a season's first day.
static func morning() -> void:
	if GameState.run.is_empty() or not RecCenter.is_open():
		return
	var f: Dictionary = GameState.run["flags"]
	var day := int(GameState.run["day"])
	var since := day - int(f.get("rec_open", day))
	var st := _state()
	for ph: Dictionary in phases():
		var id := str(ph["id"])
		if f.has("rec_reno_" + id):
			continue
		if st.has(id):
			if day >= int(st[id][1]):
				f["rec_reno_" + id] = day
				Mail.send("%s front desk" % RecCenter.name(), _fill(_tx(ph.get("done", "")), ph), "news")
			return  # one renovation at a time
		if since >= int(ph.get("after", 0)):
			st[id] = [day, day + maxi(1, int(ph.get("build", 3)))]
			Mail.send("%s front desk" % RecCenter.name(), _fill(_tx(ph.get("start", "")), ph), "news")
		return
	_cup(day)


## The Rec Cup: the season's game and the score to beat (grows each year), or {}.
static func cup() -> Dictionary:
	if GameState.run.is_empty() or not is_open("trophy_hall"):
		return {}
	var c: Dictionary = RecCenter.data().get("cup", {})
	var games: Array = c.get("games", [])
	if games.is_empty():
		return {}
	var day := int(GameState.run["day"])
	var season_n := (day - 1) / 28
	var g: Array = games[season_n % games.size()]
	var target := int(round(float(g[1]) * pow(float(c.get("step", 1.1)), season_n / games.size())))
	return {"key": "%d" % season_n, "game": str(g[0]), "score": target, "tickets": int(c.get("tickets", 100))}


static func _cup(day: int) -> void:
	var c := cup()
	if c.is_empty():
		return
	var f: Dictionary = GameState.run["flags"]
	var told: Dictionary = f.get("rec_cup_told", {}) if f.get("rec_cup_told") is Dictionary else {}
	if told.has(str(c["key"])):
		return
	told[str(c["key"])] = day
	f["rec_cup_told"] = told
	Mail.send("%s front desk" % RecCenter.name(), "This season's Rec Cup: %s. Beat %d before the season ends and the cup's %d tickets are yours. - The front desk" % [Tickets.game_name(str(c["game"])), int(c["score"]), int(c["tickets"])], "news")


## A finished game: did it win this season's cup? (Tickets.set_best callers pass the score.)
static func cup_score(game: String, score: int) -> int:
	var c := cup()
	if c.is_empty() or str(c["game"]) != game or score < int(c["score"]):
		return 0
	var f: Dictionary = GameState.run["flags"]
	var won: Dictionary = f.get("rec_cup_won", {}) if f.get("rec_cup_won") is Dictionary else {}
	if won.has(str(c["key"])):
		return 0
	won[str(c["key"])] = int(GameState.run["day"])
	f["rec_cup_won"] = won
	Tickets.add(int(c["tickets"]), "cup")
	GameState.notify("Rec Cup won! %s %d: +%d tickets" % [Tickets.game_name(game), score, int(c["tickets"])])
	return int(c["tickets"])


## Lines for the front-desk board: what's being built, what's next.
static func board_lines() -> Array:
	var out: Array = []
	if GameState.run.is_empty():
		return out
	for ph: Dictionary in phases():
		var id := str(ph["id"])
		if working(id):
			out.append("Under renovation: %s (open in %s)." % [_tx(ph.get("name", id)), _days_words(days_left(id))])
	var c := cup()
	if not c.is_empty():
		out.append("Rec Cup: %s, beat %d for %d tickets." % [Tickets.game_name(str(c["game"])), int(c["score"]), int(c["tickets"])])
	return out
