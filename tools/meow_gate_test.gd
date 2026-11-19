extends SceneTree
## The Meow Pow Wow is earned in the story: Nova joins on day 2 but can't use it
## until Catkins teaches it (flag meow_taught, beat p2_catkins). Before that her
## button explains and points at Catkins; the party tab says "not yet"; old
## saves that used it early get the "gone quiet" line and the power back from
## the same beat. The Catkins beat explains what it does.
##   godot --headless --path . -s res://tools/meow_gate_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	Companion.recruit("penguin_f", false)
	Companion.party()["active"] = "penguin_f"
	change_scene_to_file("res://scenes/farm.tscn")
	for i in 30:
		await process_frame
	var m := current_scene as GameMap
	check(Companion.active_id() == "penguin_f", "Nova is the partner (%s)" % Companion.active_id())
	check(Companion.ability_for(m, m.player) == "meow_wait", "before Catkins: the button doesn't cast (%s)" % Companion.ability_for(m, m.player))
	check(Companion.ability_name("penguin_f").contains("not yet"), "party tab: %s" % Companion.ability_name("penguin_f"))
	check(Companion.ability_desc("penguin_f").contains("Catkins"), "party tab names Catkins")
	check(Companion.meow_wait_line().contains("purring"), "Nova points at the purring: %s" % Companion.meow_wait_line())
	var before := int(GameState.run["flags"].get("reverted", 0))
	Companion.use_ability(m, m.player)
	check(int(GameState.run["flags"].get("reverted", 0)) == before and GameState.run["flags"].has("meow_wait_hint"), "pressing it explains, casts nothing")
	GameState.run["flags"]["reverted"] = 3
	check(Companion.meow_wait_line().contains("gone quiet"), "an old save that used it early hears why it stopped")
	# The beat: Catkins teaches it, with an explanation of what it does.
	var beat := {}
	for ch in Story.data().get("penguins", []):
		for b in ch.get("beats", []):
			if str(b.get("id", "")) == "p2_catkins":
				beat = b
	check(not beat.is_empty() and "meow_taught" in beat.get("effects", {}).get("flags", []), "the Catkins beat grants it")
	var text := " ".join((beat.get("lines", []) as Array).map(func(l: Dictionary) -> String: return str(l.get("text", ""))))
	check(text.contains("turns back") and text.contains("Meow Pow Wow"), "Catkins explains what it does")
	GameState.run["flags"]["meow_taught"] = true
	check(Companion.ability_name("penguin_f") == "Meow Pow Wow", "after Catkins: Meow Pow Wow")
	check(Companion.ability_for(m, m.player) in ["meow_pow_wow", ""] and Companion.ability_for(m, m.player) != "meow_wait", "after Catkins: it casts")
	# Names: The Two Too Powerful Penguins everywhere.
	var pl := GameState.load_json("res://data/playable.json")
	check(str(pl["penguin_m"]["name"]).contains("The Two Too Powerful Penguins"), "Pip-Pip's card name")
	check(str(pl["penguin_f"]["name"]).contains("The Two Too Powerful Penguins"), "Nova's card name")
	print("meow_gate_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
