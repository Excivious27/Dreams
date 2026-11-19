extends SceneTree
## Gangster arc money is CASH. Scans every string the gangster arc can show
## (data files + string literals in scripts) and fails if any still reads as
## crystal money after Money.t; checks the Translation hook and the penguin arc.
##   godot --headless --path . -s res://tools/cash_test.gd
var fails := 0
var scanned := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _walk(o: Variant, path: String, out: Array) -> void:
	if o is Dictionary:
		for k in o:
			_walk(o[k], path + "/" + str(k), out)
	elif o is Array:
		for i in (o as Array).size():
			_walk(o[i], path + "/" + str(i), out)
	elif o is String:
		out.append([path, o])


func _scan(label: String, strings: Array) -> void:
	for ps in strings:
		scanned += 1
		var shown := Money.to_cash(str(ps[1]))
		check(not Money.looks_like_crystal_money(shown), "%s%s reads as crystal money: %s" % [label, str(ps[0]), shown.left(120)])


func _json(f: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + f))


func _run() -> void:
	# 1. Data the gangster arc shows.
	var story: Dictionary = _json("story.json")
	var s: Array = []
	_walk(story.get("gangsters", {}), "", s)
	_scan("story.json gangsters", s)
	var q: Dictionary = _json("quests.json")
	for sect in q:
		if q[sect] is Array:
			for qq in q[sect]:
				if qq is Dictionary and str(qq.get("arc", "both")) in ["both", "gangsters"]:
					var a: Array = []
					_walk(qq, "", a)
					_scan("quests.json %s/%s" % [sect, str(qq.get("id", ""))], a)
	for f in ["items.json", "npcs.json", "heart_perks.json", "projects.json", "gifts.json", "companions.json", "quest_lines.json", "skills.json", "crew.json", "talk.json", "gift_lines.json", "events.json", "recipes.json", "buildings.json"]:
		var d: Variant = _json(f)
		if d == null:
			continue
		var a: Array = []
		_walk(d, "", a)
		_scan(f, a)
	var arcs: Variant = _json("arcs.json")
	if arcs is Dictionary and (arcs as Dictionary).has("gangsters"):
		var a: Array = []
		_walk(arcs["gangsters"], "", a)
		_scan("arcs.json gangsters", a)
	# 2. String literals in scripts (toasts, shops, mail, HUD...).
	var lit := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var da := DirAccess.open("res://scripts")
	for fn in da.get_files():
		if not fn.ends_with(".gd") or fn.begins_with("money"):
			continue
		var lines := FileAccess.get_file_as_string("res://scripts/" + fn).split("\n")
		var a: Array = []
		for i in lines.size():
			for m in lit.search_all(lines[i]):
				a.append([":%d" % (i + 1), m.get_string(1)])
		_scan("scripts/" + fn, a)
	# 3. Helpers and the Translation hook.
	check(Money.looks_like_crystal_money("Pay ◆150") and Money.looks_like_crystal_money("Not enough crystals."), "the scanner catches crystal money")
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	check(Money.cash() and Money.sym() == "$" and Money.fmt(150) == "$150" and Money.word() == "cash", "gangster helpers")
	check(TranslationServer.translate("Pay his fee (◆150).") == "Pay his fee ($150).", "labels show cash: " + String(TranslationServer.translate("Pay his fee (◆150).")))
	check(Money.t("Fish worth up to %d◆ can bite") == "Fish worth up to $%d can bite", "suffix symbol")
	check(Money.t("+40 crystals") == "+$40", "number + crystals")
	check(Money.t("The Star Crystal hums.") == "The Star Crystal hums.", "story nouns untouched")
	var l := Label.new()
	root.add_child(l)
	l.text = "◆"
	var w_cash := l.get_minimum_size().x
	l.text = "$"
	check(absf(l.get_minimum_size().x - w_cash) < 0.5, "a Label draws $ for ◆ in the gangster arc")
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(not Money.cash() and Money.fmt(150) == "◆150", "penguin helpers")
	check(TranslationServer.translate("Pay ◆150") == "Pay ◆150", "penguin labels unchanged")
	l.queue_free()
	print("cash_test: scanned %d strings, %d failures" % [scanned, fails])
	quit(1 if fails > 0 else 0)
