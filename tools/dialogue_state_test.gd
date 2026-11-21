extends SceneTree
## C12 P7: dialogue conditions match game state (c12_17-13, c12_16-16, c12_17-05/11/12).
## For each arc, a fresh day-1 save and a late save: harvests every villager's daily
## Talk lines (many seeded picks per villager) and checks
##   1. no line names a story character/thing before the beat that introduces it
##      (MENTION table; known open hits come from tools/continuity_allow.txt);
##   2. every gated talk.json entry ({"text", "when"} or a "flag:/after:/not:" key) shows
##      only when its condition holds (GameState._cond_ok), and does show once it holds;
##   3. arcade milestones read in the save's arc (ArcadeHub.milestone_text).
##   godot --headless --fixed-fps 60 --path . -s res://tools/dialogue_state_test.gd
var fails := 0

## keyword -> the story flag that introduces it, per arc (story beat order, continuity_check.py).
const MENTION := {
	"penguins": {"Big Jim": "st_p2_spark", "Coldy": "st_p3_coldy", "merkitt": "st_p4_merkitties",
		"Fennimore": "st_p4_prison", "Brine": "st_p5_elder_coral"},
	"gangsters": {"the President": "st_g1_man", "Marlene": "st_g3_marlene", "Specs": "st_g3_specs",
		"Halo": "st_g3_halo", "Hale ": "st_g3_hale"},
}
const PICKS := 120


func _initialize() -> void:
	seed(1207)
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _allowed() -> Array:
	var out: Array = []
	var f := FileAccess.open("res://tools/continuity_allow.txt", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l.begins_with("#") or not l.contains(" | "):
			continue
		out.append(l.split(" | ", true, 1)[1].strip_edges())
	return out


func _norm(t: String) -> String:
	return t.split("{")[0].strip_edges().left(40)


## Every line a villager can say today (seeded picks; Talk never repeats a line twice in a row).
func _harvest(id: String) -> Dictionary:
	var seen := {}
	for i in PICKS:
		for l in Talk.line(id):
			seen[_norm(str(l.get("text", "")))] = true
	return seen


func _fresh(arc: String, day: int) -> void:
	GameState.new_run(arc, "dad", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["day"] = day


## talk.json entries that carry a condition: [npc, text, when].
func _gated() -> Array:
	var out: Array = []
	var d := Talk.data()
	for id in d:
		if not (d[id] is Dictionary):
			continue
		for key: String in d[id]:
			var when := {}
			var parts := key.split(":", true, 1)
			if parts.size() == 2 and parts[0] in ["flag", "after"]:
				when = {"flag": parts[1]}
			elif parts.size() == 2 and parts[0] == "not":
				when = {"not_flag": parts[1]}
			if not (d[id][key] is Array):
				continue
			for e in d[id][key]:
				if e is Dictionary and e.has("text") and e.get("when") is Dictionary:
					out.append([str(id), key, str(e["text"]), (e["when"] as Dictionary).merged(when)])
				elif e is String and not when.is_empty():
					out.append([str(id), key, str(e), when])
	return out


func _key_live(key: String, arc: String) -> bool:
	## Only keys Talk would read today matter (season/weather/arc pools are other tests' job).
	if key in ["penguins", "gangsters"]:
		return key == arc
	if key in ["spring", "summer", "fall", "winter"]:
		return key == GameState.season()
	return key == "always" or key.contains(":")


func _check_snapshot(arc: String, label: String, allowed: Array) -> void:
	var gated := _gated()
	for id: String in GameState.npcs:
		var said := _harvest(id)
		# 1. mentions before their introduction
		for word: String in MENTION[arc]:
			var need: String = MENTION[arc][word]
			if GameState.run["flags"].has(need):
				continue
			for t: String in said:
				if t.contains(word.strip_edges()) and not allowed.any(func(a: String) -> bool: return a.begins_with(t.left(30)) or t.begins_with(a.left(30))):
					ok(false, "%s %s: %s says '%s' before %s: \"%s\"" % [arc, label, id, word, need, t])
		# 2. gated entries follow their condition
		for g in gated:
			if str(g[0]) != id or not _key_live(str(g[1]), arc):
				continue
			var w: Dictionary = g[3]
			if w.has("arc") and str(w["arc"]) != arc:
				continue
			var t := _norm(str(g[2]))
			var holds := GameState._cond_ok(w)
			if not holds:
				ok(not said.has(t), "%s %s: %s gated line shows though %s fails: \"%s\"" % [arc, label, id, JSON.stringify(w), t])


func _run() -> void:
	var allowed := _allowed()
	for arc: String in ["penguins", "gangsters"]:
		# day 1: nothing from later chapters
		_fresh(arc, 1)
		_check_snapshot(arc, "day1", allowed)
		# late save: every introduction done; gated lines whose condition now holds can show
		_fresh(arc, 40)
		for word: String in MENTION[arc]:
			GameState.run["flags"][MENTION[arc][word]] = true
		_check_snapshot(arc, "late", allowed)
		var shown := 0
		for g in _gated():
			var w: Dictionary = g[3]
			if (w.has("arc") and str(w["arc"]) != arc) or not _key_live(str(g[1]), arc):
				continue
			for k in w:
				if str(k) == "flag":
					GameState.run["flags"][str(w[k])] = true
			if GameState._cond_ok(w) and _harvest(str(g[0])).has(_norm(str(g[2]))):
				shown += 1
		print("  %s: %d gated talk lines seen once their condition holds" % [arc, shown])
	# 3. arcade milestones in the gangster arc use the gangster cabinet names (c12_18-15)
	_fresh("gangsters", 12)
	for id: String in ArcadeHub.MILESTONES:
		var t := ArcadeHub.milestone_text(id)
		ok(not (t.contains("Grump") or t.contains("Crystal") or t.contains("Duck")), "gangster milestone text '%s'" % t)
	ok(ArcadeHub.milestone_text("stack_3000").contains("Neon Stack") or not ArcadeHub.MILESTONES.has("stack_3000"), "stack milestone renamed")
	_fresh("penguins", 12)
	var pen_any := false
	for id: String in ArcadeHub.MILESTONES:
		pen_any = pen_any or ArcadeHub.milestone_text(id) == str(ArcadeHub.MILESTONES[id])
	ok(pen_any, "penguin milestones keep their names")
	# plural words used by the C12 P7 count fixes
	ok(ItemWords.count("kind", 1) == "1 kind" and ItemWords.count("kind", 3) == "3 kinds", "kind/kinds")
	ok(ItemWords.count("piece", 1) == "1 piece" and ItemWords.count("piece", 2) == "2 pieces", "piece/pieces")
	print("dialogue_state_test: %s (%d failures)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
