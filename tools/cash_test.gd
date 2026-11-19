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
	for f in ["items.json", "npcs.json", "heart_perks.json", "projects.json", "gifts.json", "companions.json", "quest_lines.json", "skills.json", "crew.json", "talk.json", "gift_lines.json", "events.json", "recipes.json", "buildings.json",
			# Round 13 systems: rec center, prizes, community farm, campaigns, mega regions, hub vehicles.
			"rec.json", "prizes.json", "community_farm.json", "battles.json", "colonies.json", "campaign_story.json", "mega_regions.json", "mega_travel.json", "regions.json", "interiors.json", "epilogue.json", "hearts.json", "jumper_plans.json"]:
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
	_round13_cash()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	check(not Money.cash() and Money.fmt(150) == "◆150", "penguin helpers")
	_round13_penguins()
	check(TranslationServer.translate("Pay ◆150") == "Pay ◆150", "penguin labels unchanged")
	l.queue_free()
	print("cash_test: scanned %d strings, %d failures" % [scanned, fails])
	quit(1 if fails > 0 else 0)


## What a Label shows for s (the cash Translation), or s itself for drawn text.
func _shown(s: String) -> String:
	return String(TranslationServer.translate(s))


func _no_crystals(s: String, what: String) -> void:
	scanned += 1
	check(not Money.looks_like_crystal_money(s), "%s reads as crystal money: %s" % [what, s.left(120)])


## Round 13 systems in the gangster arc: arcade, rec center, community farm,
## campaigns muster, mega regions / hub vehicles, shops, mail.
func _round13_cash() -> void:
	GameState.run["crystals"] = 75
	check(Money.amount(40) == "$40" and Money.num(40) == "$40", "cash amount helpers")
	# Arcade: picker top line, cabinet fees, coin-op texts are drawn (no Translation).
	check(ArcadeHub.money_word() == "cash", "arcade money word follows Money")
	var hub := ArcadeHub.new()
	check(hub._top_right() == "$75", "arcade picker shows cash: " + hub._top_right())
	hub.free()
	var bj := BlockJumper.new()
	bj.state = "select"
	check(bj._top_right() == "$75", "block jumper shows cash: " + bj._top_right())
	bj.free()
	check(Money.t("A: INSERT %s" % Money.amount(10).to_upper()) == "A: INSERT $10", "insert-coin line")
	check(Money.t("Not enough %s (%s)." % [Money.word(), Money.num(10)]) == "Not enough cash ($10).", "arcade can't-pay line")
	# Rec center desk / claw / skee / snack lines and the stand (dialogue + toasts).
	for t in ["Bowling upstairs (◆25 a game).", "CLAW MACHINE · ◆10 a go.  (you have ◆75)", "Not enough crystals for a game.", "Not enough crystals.",
			"SNACK BAR · Cotton candy ◆8, Fizzy Pop ◆12.  (you have ◆75)", "Sold 3 Carrot for ◆45.", "Pumpkin ×2  ◆30", "The scrap dealer pays ◆12 for those."]:
		_no_crystals(_shown(t), "rec/commons line")
	check(_shown("Not enough crystals for a game.") == "Not enough cash for a game.", "rec center can't-pay toast")
	# Community farm stage rewards.
	for sd: Dictionary in Commons.stages():
		if int(sd.get("crystals", 0)) > 0:
			_no_crystals(_shown("Stage done! +" + "◆%d" % int(sd["crystals"])), "commons stage reward")
	# Campaign muster provisions and the battle-board texts.
	for cid: String in Campaign.all():
		var pt := _shown(CampaignGate.provisions_text(cid))
		_no_crystals(pt, "campaign %s provisions" % cid)
		var st := _shown(CampaignGate.short_text(cid))
		_no_crystals(st, "campaign %s muster line" % cid)
	# Mega hub keepers: hook quests pay through quest_done_text; Rahim's line.
	for id: String in MegaTravel.data():
		var qid := str(MegaTravel.data()[id].get("quest", ""))
		if qid != "":
			var qt := _shown(GameMap.quest_done_text(qid))
			_no_crystals(qt, "mega %s hook reward" % id)
			if int(GameState._quest_def(qid).get("reward", {}).get("crystals", 0)) > 0:
				check(qt.contains("$"), "mega %s hook pays cash: %s" % [id, qt])
	check(_shown("Bring me sunstones and I'll pay you in shade. And crystals.").ends_with("And cash."), "Rahim pays cash")
	# Shops and mail.
	_no_crystals(_shown("Seeds, ◆20 each. How many?  (you have ◆75)"), "shop line")
	_no_crystals(_shown("Could you spare 3 Wood? I'd pay ◆30, and I'd owe you one."), "mail favour")


## The penguin arc keeps its crystal words exactly.
func _round13_penguins() -> void:
	GameState.run["crystals"] = 75
	check(ArcadeHub.money_word() == "crystals" and Money.amount(40) == "40 crystals" and Money.num(40) == "40", "penguin amount helpers")
	var hub := ArcadeHub.new()
	check(hub._top_right() == "75 crystals", "penguin arcade picker unchanged: " + hub._top_right())
	hub.free()
	check(Money.t("Not enough crystals for a game.") == "Not enough crystals for a game.", "penguin rec toast unchanged")
	check(_shown("Bowling upstairs (◆25 a game).") == "Bowling upstairs (◆25 a game).", "penguin rec line unchanged")
