class_name Tickets
extends RefCounted
## Arcade tickets and high scores, kept in the run:
##   run["tickets"]       tickets in hand
##   run["arcade_best"]   game id -> best score
## Games pay with add(); the prize counter spends with spend().


static func count() -> int:
	return int(GameState.run.get("tickets", 0))


static func add(n: int, source := "") -> void:
	if n <= 0:
		return
	GameState.run["tickets"] = count() + n
	GameState.run["tickets_total"] = int(GameState.run.get("tickets_total", 0)) + n
	if source != "":
		var by: Dictionary = GameState.run.get("tickets_by", {})
		by[source] = int(by.get(source, 0)) + n
		GameState.run["tickets_by"] = by


static func spend(n: int) -> bool:
	if n < 0 or count() < n:
		return false
	GameState.run["tickets"] = count() - n
	return true


static func _bests() -> Dictionary:
	if not (GameState.run.get("arcade_best") is Dictionary):
		GameState.run["arcade_best"] = {}
	return GameState.run["arcade_best"]


static func best_score(game_id: String) -> int:
	return int(_bests().get(game_id, 0))


## Keeps the higher score; true when this one is a new best.
static func set_best(game_id: String, score: int) -> bool:
	var b := _bests()
	if score > int(b.get(game_id, 0)):
		b[game_id] = score
		return true
	return false


## A prize the counter has unlocked (bought once / milestone met).
static func unlocked(prize_id: String) -> bool:
	var u: Variant = GameState.run.get("prizes_unlocked", {})
	return u is Dictionary and bool((u as Dictionary).get(prize_id, false))
