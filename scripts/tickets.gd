class_name Tickets
extends RefCounted
## Rec Center tickets and arcade progress. Shared API for every rec game
## (bowling, the arcade cabinets) and the prize counter.
##
##   Tickets.add(n, source)        award n tickets (source: "bowling", game id...)
##   Tickets.spend(n) -> bool      take n tickets if there are enough
##   Tickets.count() -> int        tickets on hand
##   Tickets.best_score(game_id)   best score of a game (0 if never played)
##   Tickets.set_best(game_id, s)  record a score; returns true if it is a new best
##   Tickets.unlocked(prize_id)    the prize's milestone is met (data/prizes.json)
##   Tickets.cond_ok(when)         quest/event condition keys for the rec (GameState._cond_ok):
##       "arcade_ms": id or [ids]   ArcadeHub milestones reached
##       "rec_best": [game, score]  best score in a game (bowling, stack, whack...)
##       "tickets_won": n           tickets won in all (every source)
##
## Lives in run["arcade"] = {"tickets": int, "best": {game: score},
##   "earned": {source: total}, "plays": {game: n}, "bought": {prize: n}}.
## Old saves get the block on first use (no migration step needed elsewhere).

const PRIZES_PATH := "res://data/prizes.json"

static var _prizes: Dictionary = {}


static func _st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("arcade") is Dictionary):
		r["arcade"] = {}
	var a: Dictionary = r["arcade"]
	if not a.has("tickets"):
		a["tickets"] = int(r.get("tickets", 0))
		r.erase("tickets")
	for k in ["best", "earned", "plays", "bought"]:
		if not (a.get(k) is Dictionary):
			a[k] = {}
	return a


static func add(n: int, source := "") -> void:
	if n <= 0:
		return
	var a := _st()
	a["tickets"] = int(a["tickets"]) + n
	if source != "":
		a["earned"][source] = int(a["earned"].get(source, 0)) + n


static func spend(n: int) -> bool:
	var a := _st()
	if n < 0 or int(a["tickets"]) < n:
		return false
	a["tickets"] = int(a["tickets"]) - n
	return true


static func count() -> int:
	return int(_st()["tickets"])


static func best_score(game_id: String) -> int:
	return int(_st()["best"].get(game_id, 0))


## Records a finished game: counts the play and keeps the best score.
static func set_best(game_id: String, score: int) -> bool:
	var a := _st()
	a["plays"][game_id] = int(a["plays"].get(game_id, 0)) + 1
	if score > int(a["best"].get(game_id, 0)):
		a["best"][game_id] = score
		return true
	return false


static func plays(game_id: String) -> int:
	return int(_st()["plays"].get(game_id, 0))


## Plays of every game except bowling (the arcade cabinets).
static func arcade_plays() -> int:
	var t := 0
	var p: Dictionary = _st()["plays"]
	for g in p:
		if str(g) != "bowling":
			t += int(p[g])
	return t


## How many different arcade games have been played at least once.
static func arcade_games() -> int:
	var t := 0
	var p: Dictionary = _st()["plays"]
	for g in p:
		if str(g) != "bowling" and int(p[g]) > 0:
			t += 1
	return t


static func earned(source := "") -> int:
	var a := _st()
	if source != "":
		return int(a["earned"].get(source, 0))
	var t := 0
	for k in a["earned"]:
		t += int(a["earned"][k])
	return t


static func prizes() -> Dictionary:
	if _prizes.is_empty():
		_prizes = GameState.load_json(PRIZES_PATH)
	return _prizes


static func prize(prize_id: String) -> Dictionary:
	return (prizes().get("prizes", {}) as Dictionary).get(prize_id, {})


## "need" in a prize: {"best": {game: score}, "plays": {game: n}, "earned": n}.
static func unlocked(prize_id: String) -> bool:
	return lock_text(prize_id) == ""


## Why a prize is still locked ("" when it is available).
static func lock_text(prize_id: String) -> String:
	var p := prize(prize_id)
	if p.is_empty():
		return "Unknown prize."
	var need: Dictionary = p.get("need", {})
	var names: Dictionary = prizes().get("game_names", {})
	for g in (need.get("best", {}) as Dictionary):
		if best_score(str(g)) < int(need["best"][g]):
			return "Score %d in %s" % [int(need["best"][g]), str(names.get(g, g))]
	for g in (need.get("plays", {}) as Dictionary):
		if plays(str(g)) < int(need["plays"][g]):
			return "Play %s %d times" % [str(names.get(g, g)), int(need["plays"][g])]
	if need.has("earned") and earned() < int(need["earned"]):
		return "Win %d tickets in all" % int(need["earned"])
	var arc: Dictionary = need.get("arcade", {})
	if arc.has("plays") and arcade_plays() < int(arc["plays"]):
		return "Play %d arcade games" % int(arc["plays"])
	if arc.has("games") and arcade_games() < int(arc["games"]):
		return "Try %d different cabinets" % int(arc["games"])
	var ms: Variant = need.get("ms", [])
	for id in (ms if ms is Array else [ms]):
		if not ArcadeHub.milestone(str(id)):
			return str(ArcadeHub.MILESTONES.get(str(id), str(id)))
	if need.has("once") and bought(prize_id) > 0:
		return "Already yours"
	return ""


## The rec's condition keys (GameState._cond_ok asks here; keys it doesn't know pass).
static func cond_ok(when: Dictionary) -> bool:
	if when.has("arcade_ms"):
		var ms: Variant = when["arcade_ms"]
		for id in (ms if ms is Array else [ms]):
			if not ArcadeHub.milestone(str(id)):
				return false
	if when.has("rec_best"):
		var rb: Array = when["rec_best"]
		if best_score(str(rb[0])) < int(rb[1]):
			return false
	if when.has("tickets_won") and earned() < int(when["tickets_won"]):
		return false
	return true


static func bought(prize_id: String) -> int:
	return int(_st()["bought"].get(prize_id, 0))


## Buys a prize: spends the tickets and gives the item. Returns "" or why not.
static func buy(prize_id: String) -> String:
	var p := prize(prize_id)
	var why := lock_text(prize_id)
	if why != "":
		return why
	var cost := int(p.get("cost", 0))
	if count() < cost:
		return "Not enough tickets."
	if not spend(cost):
		return "Not enough tickets."
	_st()["bought"][prize_id] = bought(prize_id) + 1
	GameState.add_item(str(p.get("item", prize_id)), int(p.get("n", 1)))
	return ""
