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
##   Tickets.payout(game, n)       what a play that scored n tickets really pays (soft cap
##                                 and cap per game from tools/gen_rec.py PAYOUT)
##   Tickets.claw_pool(fallback)   the claw machine's [item, weight] list (gen_rec CLAW_POOL)
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
	for k in ["best", "earned", "plays", "bought", "week"]:
		if not (a.get(k) is Dictionary):
			a[k] = {}
	return a


## Awards tickets. Games pass their raw count through payout() first (and show that);
## add() itself still holds a game source to its cap, so no play can pay past it.
static func add(n: int, source := "") -> void:
	var cap: Variant = ((prizes().get("payout", {}) as Dictionary).get(source, {}) as Dictionary).get("cap")
	if cap != null:
		n = mini(n, int(cap))
	if n <= 0:
		return
	var a := _st()
	a["tickets"] = int(a["tickets"]) + n
	if source != "":
		a["earned"][source] = int(a["earned"].get(source, 0)) + n


## Tickets handed to you (welcome gift, sponsor, lane payout, quest/perk reward):
## a short ticket-stub cue, never the money sound (tickets aren't cash).
static func cue() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		Music.instance(tree).sfx("ticket_feed", "j_confirm")


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
	RecReno.cup_score(game_id, score)  # the seasonal Rec Cup (once the trophy hall stands)
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


## Per-play payout: full tickets up to the game's "soft" mark, half rate above it, never
## past its "cap" (the caps keep tickets from ever selling back for more than a play costs).
static func payout(game_id: String, n: int) -> int:
	var p: Dictionary = (prizes().get("payout", {}) as Dictionary).get(game_id, {})
	if p.is_empty() or n <= int(p.get("soft", n)):
		return maxi(0, n)
	var soft := int(p["soft"])
	return mini(int(p.get("cap", n)), soft + (n - soft) / 2)


static func claw_pool(fallback: Array) -> Array:
	var cp: Variant = prizes().get("claw_pool", [])
	return cp if cp is Array and not (cp as Array).is_empty() else fallback


## The current shop week (day 1-7 = week 0) for "weekly" prizes.
static func week() -> int:
	return maxi(0, int(GameState.run.get("day", 1)) - 1) / 7


static func prizes() -> Dictionary:
	if _prizes.is_empty():
		_prizes = GameState.load_json(PRIZES_PATH)
	return _prizes


static func prize(prize_id: String) -> Dictionary:
	return (prizes().get("prizes", {}) as Dictionary).get(prize_id, {})


## A game's name as the player reads it (gangster arc: data "game_names_gang" wins).
static func game_name(game: String) -> String:
	var names: Dictionary = prizes().get("game_names", {})
	if not GameState.is_penguins():
		names = names.merged(prizes().get("game_names_gang", {}), true)
	return str(names.get(game, game.capitalize()))


## A little ticket stub (notched ends, a perforation line), drawn in place of a glyph so
## tickets never look like crystals ◆ (c3_17 #5). `at` = left of the stub's centre line;
## returns the stub's width so text can follow it.
static func draw_ticket(c: CanvasItem, at: Vector2, h: float, col := Color(1, 0.62, 0.82)) -> float:
	var w := roundf(h * 1.6)
	var r := Rect2(at.x, at.y - h / 2.0, w, h)
	var dark := col.darkened(0.55)
	c.draw_rect(r.grow(0.6), dark)
	c.draw_rect(r, col)
	var nr := maxf(1.0, h * 0.22)
	c.draw_circle(Vector2(r.position.x, at.y), nr, dark)
	c.draw_circle(Vector2(r.end.x, at.y), nr, dark)
	var px := r.position.x + w * 0.68
	var y := r.position.y + 1.0
	while y < r.end.y - 0.5:
		c.draw_rect(Rect2(px, y, 0.8, 0.9), dark)
		y += 2.0
	return w


## A ticket stub followed by text, centred in [x, x + width] (draw_string HORIZONTAL_ALIGNMENT_CENTER
## stand-in for screens that used "♦ n").
static func draw_amount(c: CanvasItem, font: Font, x: float, base_y: float, width: float, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ih := maxf(3.0, size * 0.62)
	var iw := roundf(ih * 1.6) + 2.0
	var left := x + (width - tw - iw) / 2.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = x + width - tw - iw
	draw_ticket(c, Vector2(left, base_y - size * 0.36), ih, col if col.a > 0.6 else Color(1, 0.62, 0.82, col.a))
	c.draw_string(font, Vector2(left + iw, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## False for an item that belongs to the other arc (the counter, claw and machines skip it).
static func arc_ok(item: String) -> bool:
	var a := str(GameState.items.get(item, {}).get("arc", ""))
	return a == "" or a == str(GameState.run.get("arc", ""))


## "need" in a prize: {"best": {game: score}, "plays": {game: n}, "earned": n}.
static func unlocked(prize_id: String) -> bool:
	return lock_text(prize_id) == ""


## Why a prize is still locked ("" when it is available).
static func lock_text(prize_id: String) -> String:
	var p := prize(prize_id)
	if p.is_empty():
		return "Unknown prize."
	if not arc_ok(str(p.get("item", prize_id))):
		return "Not on this counter."
	var reno := RecReno.prize_lock(int(p.get("tier", 1)))
	if reno != "":
		return reno
	var need: Dictionary = p.get("need", {})
	for g in (need.get("best", {}) as Dictionary):
		if best_score(str(g)) < int(need["best"][g]):
			var b := best_score(str(g))
			return "Score %d in %s%s" % [int(need["best"][g]), game_name(str(g)), (" (best %d)" % b) if b > 0 else ""]
	for g in (need.get("plays", {}) as Dictionary):
		if plays(str(g)) < int(need["plays"][g]):
			return "Play %s %d times (%d/%d)" % [game_name(str(g)), int(need["plays"][g]), plays(str(g)), int(need["plays"][g])]
	if need.has("earned") and earned() < int(need["earned"]):
		return "Win %d tickets in all (%d so far)" % [int(need["earned"]), earned()]
	var arc: Dictionary = need.get("arcade", {})
	if arc.has("plays") and arcade_plays() < int(arc["plays"]):
		return "Play %d arcade games (%d/%d)" % [int(arc["plays"]), arcade_plays(), int(arc["plays"])]
	if arc.has("games") and arcade_games() < int(arc["games"]):
		return "Try %d different cabinets (%d/%d)" % [int(arc["games"]), arcade_games(), int(arc["games"])]
		return "Try %d different cabinets" % int(arc["games"])
	var ms: Variant = need.get("ms", [])
	for id in (ms if ms is Array else [ms]):
		if not ArcadeHub.milestone(str(id)):
			return str(ArcadeHub.MILESTONES.get(str(id), str(id)))
	if need.has("once") and bought(prize_id) > 0:
		return "Already yours"
	if need.has("weekly") and int((_st()["week"] as Dictionary).get(prize_id, [-1, 0])[0]) == week() \
			and int(_st()["week"][prize_id][1]) >= int(need["weekly"]):
		var left := 7 - (maxi(0, int(GameState.run.get("day", 1)) - 1) % 7)
		return "Sold out this week (more in %d day%s)" % [left, "" if left == 1 else "s"]
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
	if (p.get("need", {}) as Dictionary).has("weekly"):
		var wk: Array = (_st()["week"] as Dictionary).get(prize_id, [-1, 0])
		_st()["week"][prize_id] = [week(), (int(wk[1]) if int(wk[0]) == week() else 0) + 1]
	GameState.add_item(str(p.get("item", prize_id)), int(p.get("n", 1)))
	return ""
