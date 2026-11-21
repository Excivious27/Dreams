extends SceneTree
## C7 P6 text fixes: articles in gift reactions ("an Apple", "some Turnip Seeds"),
## plural item names for letters, first-person "wait" lines, side-quest wording that
## points the right way (sal_fish minnows, Orchard Hills moonwort, no wine toasts).
##   godot --headless --fixed-fps 60 --path . -s res://tools/c7_text_test.gd
var fails := 0


func _initialize() -> void:
	seed(7)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	check(GameState.with_article("Apple", true) == "An Apple", "An Apple (%s)" % GameState.with_article("Apple", true))
	check(GameState.with_article("Turnip Seeds") == "some Turnip Seeds", "some Turnip Seeds")
	check(GameState.with_article("Carrot", true) == "A Carrot", "A Carrot")
	check(GameState.with_article("Wood", true) == "Some Wood", "Some Wood")
	check(GameState.articled("A Apple! For me?", "Apple") == "An Apple! For me?", "articled fixes 'A Apple'")
	check(GameState.articled("Oh. A Iron Ore. Thanks.", "Iron Ore") == "Oh. Some Iron Ore. Thanks.", "articled mid-line (ItemWords: ore is a mass noun)")
	check(GameState.plural_name("turnip", 4) == GameState.item_name("turnip") + "s", "4 Turnips (%s)" % GameState.plural_name("turnip", 4))
	check(GameState.plural_name("turnip", 1) == GameState.item_name("turnip"), "1 Turnip")
	check(GameState.plural_name("wood", 9) == GameState.item_name("wood"), "Wood stays Wood")
	# Every villager's gift lines: no "A <vowel-name>" after the article step.
	var bad := 0
	for id: String in GameState.npcs:
		for it in ["apple", "iron_ore", "egg", "turnip_seed", "amethyst"]:
			if not GameState.items.has(it):
				continue
			for g in [25, 14, 5, -5]:
				var line := GameState.gift_line(id, it, g)
				var nm := GameState.item_name(it)
				if line.contains("A " + nm) and "AEIOU".contains(nm.left(1)):
					bad += 1
					print("    ", id, ": ", line)
	check(bad == 0, "no 'A <vowel item>' in gift lines (%d)" % bad)
	# Side-quest wording.
	var side := {}
	for q in GameState.quests_data.get("side", []):
		side[str(q["id"])] = q
	check(str(side["sal_fish"]["text"]).contains("minnow"), "sal_fish asks for minnows")
	check(str(side["wren_moonwort"]["text"]).contains("Orchard Hills"), "moonwort: Orchard Hills")
	check(not str(side["finn_trout"]["text"]).contains("week"), "finn_trout: no deadline that doesn't exist")
	check(not str(side["theo_coffee"]["text"]).contains("yourself"), "theo_coffee: shop coffee counts")
	check(str(side["moss_glowcaps"]["done_when"]["item"][0]) != "glowcap", "Old Moss doesn't ask for what he sells")
	check(str(side["orla_oil"]["done_when"]["item"][0]) != "lamp_oil", "Orla doesn't ask for Marlowe's own lamp oil")
	var ql: Dictionary = GameState.load_json("res://data/quest_lines.json")
	for qid in ["alder_wine", "bram_wine"]:
		var all := JSON.stringify(ql.get(qid, {})) + str(side[qid]["text"])
		check(not all.to_lower().contains("toast"), "%s: wine is a gift, no toast" % qid)
	check(JSON.stringify(ql["alder_gold"]).contains("twenty-one"), "alder_gold: twenty-one years")
	# A job with no wait line: first person, what's still short.
	var d := {"done_when": {"items": [["gold_leaf", 3], ["pearl", 1]]}}
	var need := Quests._still_need(d)
	check(need.begins_with("3 ") and need.contains(" and 1 "), "wait line lists what's short (%s)" % need)
	print("c7_text_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
