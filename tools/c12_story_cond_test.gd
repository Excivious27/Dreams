extends SceneTree
## C12 P1: penguin main story lines match game state. Hero-as-story-character
## filters (Nova, Pip-Pip, Big Jim, Coldy, Mer never narrated as someone else or
## talking to themselves), choice payoffs (crystal_answer, tell_town, locket,
## watcher, elders, %bitter, partner), backstop chapter order, hint_hero, the
## partner scene for penguin heroes, and every line fits the phone box.
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/c12_story_cond_test.gd
var fails := 0


func _initialize() -> void:
	seed(12)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _beat(id: String) -> Dictionary:
	for b in Story.beats():
		if str(b["id"]) == id:
			return b
	return {}


## Every line a beat would show (branches flattened, choice 0 and 1 both).
func _shown(id: String) -> Array:
	var out: Array = []
	_flat(Story._fill(_beat(id).get("lines", [])), out)
	return out


func _flat(lines: Array, out: Array) -> void:
	for l in lines:
		out.append(l)
		for bk in (l as Dictionary).get("branches", {}):
			_flat(l["branches"][bk], out)


func _has(id: String, sub: String) -> bool:
	for l in _shown(id):
		if sub in str(l.get("text", "")):
			return true
	return false


func _fresh(hero: String) -> void:
	GameState.new_run("penguins", hero, "Hero", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true


func _run() -> void:
	# 1) Story characters as heroes: no line spoken by the hero survives, and no
	# narration names the hero as someone else, in any penguin beat, with the
	# flags of a full run set.
	var all_flags := ["babies_done", "st_p3_campfire", "nova_dream", "fennimore_turnable", "elder_came_any", "elder_came_all",
		"auk_ally", "knight_reverted", "watch_nova", "watch_pip", "told_town", "kept_quiet", "dc_reverted", "dc_shattered", "locket_keep"]
	for hero in ["penguin_f", "penguin_m", "big_jim", "coldy", "mer"]:
		_fresh(hero)
		for f in all_flags:
			GameState.run["flags"][f] = true
		var me := str(GameState.playables.get(hero, {}).get("name", "")).get_slice(" (", 0)
		var bad: Array = []
		for b in Story.beats():
			if not str(b["id"]).begins_with("p"):
				continue
			var lines: Array = []
			_flat(Story._fill(b.get("lines", [])), lines)
			for l in lines:
				var who := str(l.get("who", ""))
				var tx := str(l.get("text", ""))
				if who == me and lines.size() > 1 and not l.has("choice"):
					bad.append("%s: %s speaks" % [b["id"], me])
				# Narration about the hero by name ("Grandfather" lines are about Auk).
				if who == "" and (tx.contains(me + " ") or tx.contains(me + ",") or tx.contains(me + ".") or tx.contains(me + "'s")) and not tx.contains("\"" + me):
					bad.append("%s: narration names %s: %s" % [b["id"], me, tx.left(60)])
		check(bad.is_empty(), "%s hero: no self lines or third-person narration %s" % [hero, str(bad.slice(0, 4))])

	# 2) Nova hero: the knight choice is hers, the dream has Pip-Pip on the fence.
	_fresh("penguin_f")
	check(_has("p3_knight_nova", "Toward you.") and not _has("p3_knight_nova", "Toward Nova"), "Nova hero: the Knight turns toward you")
	check(_has("p2_nova_dream", "Pip-Pip was already on the fence") and not _has("p2_nova_dream", "find the two penguins"), "Nova hero: dream has Pip-Pip, not 'two penguins'")
	_fresh("penguin_m")
	check(_has("p2_nova_dream", "Nova was on the fence"), "Pip-Pip hero: dream has Nova on the fence")

	# 3) The first choice (crystal_answer) is answered in p1_howl and p5_win.
	_fresh("kairi")
	check(not _has("p1_howl", "talking rock") and not _has("p1_howl", "farm in peace"), "p1_howl: no answer lines without a flag")
	GameState.run["flags"]["crystal_doubt"] = true
	check(_has("p1_howl", "Still think I'm a rock?"), "p1_howl: 'talking rock' answer is remembered")
	check(_has("p5_win", "You called me a talking rock"), "p5_win: 'talking rock' paid off")
	GameState.run["flags"].erase("crystal_doubt")
	GameState.run["flags"]["crystal_peace"] = true
	check(_has("p1_howl", "farm in peace") and _has("p5_win", "Go and do it"), "farm-in-peace answer is remembered (p1_howl, p5_win)")

	# 4) tell_town is answered: Alder / Maple talk beats and the bell scene.
	_fresh("kairi")
	check(not GameState._cond_ok(_beat("p1_alder_told").get("when", {})), "p1_alder_told waits for told_town")
	GameState.run["flags"]["told_town"] = true
	check(GameState._cond_ok(_beat("p1_alder_told").get("when", {})), "p1_alder_told ready after told_town")
	check(_has("p4_bell_rung", "They came anyway") and not _has("p4_bell_rung", "Maple catches your eye"), "bell scene answers told_town, not kept_quiet")
	GameState.run["flags"].erase("told_town")
	GameState.run["flags"]["kept_quiet"] = true
	check(GameState._cond_ok(_beat("p1_maple_quiet").get("when", {})) and _has("p4_bell_rung", "Maple catches your eye"), "kept_quiet: Maple's beat and bell line")

	# 5) Elders: one elder never reads as "four lights".
	_fresh("kairi")
	GameState.run["flags"]["elder_came_coral"] = true
	GameState.run["flags"]["elder_came_any"] = true
	check(not _has("p5_win", "four lights") and _has("p5_win", "the elders' lights brighten"), "coral elder only: no 'four lights'")
	for e in ["kelp", "ice", "ember"]:
		GameState.run["flags"]["elder_came_" + e] = true
	Story._apply(null, {})
	check(GameState.run["flags"].has("elder_came_all") and _has("p5_win", "four lights"), "all four elders: elder_came_all and 'four lights'")

	# 6) The watcher at the campfire is the penguin who didn't stay.
	var farm_s: GDScript = load("res://scripts/farm.gd")
	check(farm_s.watcher_flag("kairi", "penguin_f") == "watch_pip", "Nova stays: Pip-Pip watches")
	check(farm_s.watcher_flag("kairi", "penguin_m") == "watch_nova", "Pip-Pip stays: Nova watches")
	check(farm_s.watcher_flag("penguin_m", "") == "watch_nova" and farm_s.watcher_flag("penguin_m", "penguin_f") == "", "Pip-Pip hero: Nova watches unless she stays")
	check(farm_s.watcher_flag("penguin_f", "dad") == "watch_pip", "Nova hero: Pip-Pip watches")
	_fresh("kairi")
	GameState.run["flags"]["watch_pip"] = true
	check(_has("p3_campfire", "Also I ate the snacks") and not _has("p3_campfire", "I kept watch over the island while you were in Cat-topia. The red sky goes to that mountain every night, and comes back a little bigger.\""), "campfire: Pip-Pip says he kept watch")
	var nova_watch := false
	for l in _shown("p3_campfire"):
		if str(l.get("who", "")) == "Nova" and "kept watch" in str(l.get("text", "")):
			nova_watch = true
	check(not nova_watch, "campfire: Nova doesn't claim the watch when Pip-Pip kept it")

	# 7) Partner scene for a penguin hero: the sibling asks, nobody names you as away.
	for hero in ["penguin_m", "penguin_f"]:
		var me2 := "Pip-Pip" if hero == "penguin_m" else "Nova"
		var shown: Array = []
		for l in Companion.data().get("partner_scene", {}).get("penguins", {}).get("lines", []):
			if (l.has("not_hero") and Story._hero_in(l["not_hero"], hero)) or (l.has("only_hero") and not Story._hero_in(l["only_hero"], hero)):
				continue
			shown.append(l)
		var ok := true
		for l in shown:
			if str(l.get("who", "")) == me2 or (me2 + "'s keeping watch") in str(l.get("text", "")):
				ok = false
		check(ok and shown.size() >= 4, "%s hero: partner scene has no self lines and no 'you keep watch'" % me2)

	# 8) %bitter, the boss name, and the turned-back friend.
	_fresh("kairi")
	Companion.party()["bitter"] = ["penguin_m"]
	GameState.run["flags"]["gone_east_penguin_m"] = true
	GameState.run["flags"]["bitter_left"] = true
	check(_has("p5_bitter", "Pip-Pip. They don't look at you"), "%bitter names the friend who went east")
	check(_has("p5_win", "Where Pip-Pip stood"), "p5_win turns the bitter friend back")
	var sp: Array = _beat("p5_spire")["effects"]["spawn"]
	var fen := ""
	for s in sp:
		if str(s[0]) == "finargle_elder" and s.size() > 6:
			fen = str(s[6])
	check(fen.begins_with("Fennimore"), "Fennimore's boss bar names her, not 'The Finargle Elder'")

	# 9) if_partner lines in p4_gate.
	_fresh("kairi")
	Companion.party()["active"] = "coldy"
	check(_has("p4_gate", "Coldy bring hat") and not _has("p4_gate", "food for space"), "p4_gate: Coldy's own line when she's out")
	Companion.party()["active"] = ""
	check(_has("p4_gate", "Nobody says anything"), "p4_gate: a quiet line when nobody's out")

	# 10) Items: the collar and the locket.
	_fresh("kairi")
	check(not _has("p5_epilogue", "The collar in your pack"), "epilogue: no collar line without the collar")
	GameState.add_item("old_collar", 1)
	check(_has("p5_epilogue", "The collar in your pack"), "epilogue: the collar fits Biscuit")
	GameState.run["flags"]["locket_keep"] = true
	GameState.run["flags"]["ss_commander_home"] = true
	check(not GameState._cond_ok(_beat("p2_finn_locket_late")["when"]), "late locket beat needs the locket")
	GameState.add_item("brass_locket", 1)
	check(GameState._cond_ok(_beat("p2_finn_locket_late")["when"]), "kept locket goes to Tomas once he's home")

	# 11) Backstop chapter order: an old chapter-3 beat never plays after the finale began.
	_fresh("kairi")
	GameState.run["flags"]["st_p5_spire"] = true
	check(Story._chapter_passed(_beat("p3_knight_mercy_after")), "chapter-3 beat counts as passed once chapter 5 has begun")
	check(not Story._chapter_passed(_beat("p5_win")), "a chapter-5 beat is not passed")

	# 12) hint_hero.
	_fresh("penguin_f")
	Story._apply(null, {"hint": "default", "hint_hero": {"penguin_f": "for Nova"}})
	var hs: Array = GameState.run.get("hints", [])
	check(not hs.is_empty() and str(hs[-1]) == "for Nova", "hint_hero replaces the hint for that hero")

	# 13) Every penguin line fits the phone box after the split at 280.
	_fresh("kairi")
	var longest := 0
	var where := ""
	for b in Story.beats():
		var lines: Array = []
		_flat(Story._fill(b.get("lines", [])), lines)
		for l in lines:
			var n := str(l.get("text", "")).length()
			if n > longest:
				longest = n
				where = str(b["id"])
	check(longest <= 300, "longest shown line %d chars (%s) fits the box" % [longest, where])

	print("c12_story_cond_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
