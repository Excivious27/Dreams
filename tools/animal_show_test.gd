extends SceneTree
## CONDUCT 11b P6: the fair ribbon tables (scripts/animal_show.gd).
## Clean ring line (no "Tam's his ram"), judging on hearts/mood/quality/variant/days grown (no price),
## honourable mention for 4th, rivals seeded by day and harder each year (capped), bees can't be shown,
## goods on their own table, gangster arc "Stock Show", giver line for Tam's lamb, ribbons recorded,
## and the Show ribbons collection row.
##   godot --headless --fixed-fps 60 --path . -s res://tools/animal_show_test.gd
const AS := preload("res://scripts/animal_show.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	seed(6)
	_run.call_deferred()

func _fresh(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	for k in ["builds", "quality", "farm", "flags"]:
		if not (GameState.run.get(k, null) is Dictionary):
			GameState.run[k] = {}

func _run() -> void:
	_fresh("penguins")
	Ranch._data = {"species": {
		"cow": {"name": "Cow", "home": "barn", "group": "beast", "buy": {"price": 1500}, "art": {"variants": [{"id": "brown"}, {"id": "bw"}, {"id": "gold", "rare": true}]}},
		"pig": {"name": "Pig", "home": "barn", "group": "beast", "buy": {"price": 9000}, "art": {"variants": [{"id": "pink"}]}},
		"bees": {"name": "Bees", "home": "barn", "group": "insect", "art": {"variants": []}},
		"emu": {"name": "Emu", "home": "barn", "group": "bird", "show": false, "art": {"variants": []}}},
		"buildings": {"barn": [{"tier": 1, "cap": 9}]}, "rules": {}, "products": {"milk": {}}, "processing": {}}
	Ranch.st()["houses"]["barn"] = {"tier": 1}
	GameState.run["day"] = 1
	var a := Ranch.add("cow")
	var b := Ranch.add("cow")
	var p := Ranch.add("pig")
	var bee := Ranch.add("bees")
	var emu := Ranch.add("emu")
	GameState.run["day"] = 300
	# Judging: friendship beats a pricey species; no price term.
	Ranch.animal(a)["friend"] = 900
	Ranch.animal(a)["mood"] = 90
	Ranch.animal(p)["friend"] = 0
	Ranch.animal(p)["mood"] = 0
	check(AS.score_animal(a) > AS.score_animal(p), "a loved cow beats an unloved pricey pig")
	check(AS.score_animal(p) <= 10, "price no longer scores (%d)" % AS.score_animal(p))
	Ranch.animal(b)["friend"] = 900
	Ranch.animal(b)["mood"] = 90
	Ranch.animal(a)["variant"] = "brown"
	Ranch.animal(b)["variant"] = "gold"
	check(AS.score_animal(b) == AS.score_animal(a) + 25, "a rare variant adds 25")
	Ranch.animal(b)["variant"] = "bw"
	check(AS.score_animal(b) == AS.score_animal(a) + 8, "a non-first variant adds 8")
	Ranch.animal(b)["friend"] = 300
	Ranch.animal(b)["mood"] = 60
	var sb := AS.score_animal(b)
	Ranch.animal(b)["mood"] = 40
	check(sb - AS.score_animal(b) >= 12 + 4, "silver quality counts (mood 60 vs 40)")
	# Who can be shown.
	check(AS.can_show(a) and not AS.can_show(bee) and not AS.can_show(emu), "bees and show:false species stay home")
	var ents: Array = AS.animal_entries()
	for e: Array in ents:
		check(str(e[1]) != bee, "bees not offered")
	# Goods go to their own table; the animal table takes animals only.
	var hc: Array = AS.cats("harvest")
	check(hc.size() == 2 and str(hc[0]["kind"]) == "animal" and str(hc[1]["kind"]) == "good", "harvest: Animal Show + Ranch Goods table")
	check(not AS.cats("lantern").is_empty() and AS.cats("star").is_empty(), "summer Fleece & Feather table, no winter table")
	# Ring line: clean English for every category and rival draw.
	for fest: String in AS.CATS:
		for c: Dictionary in AS.cats(fest):
			for d in [14, 126, 238, 350]:
				var rv: Array = AS.rivals(fest, str(c["id"]), d)
				check(rv.size() == 3, "%s %s: three rivals" % [fest, c["id"]])
				var ln: String = AS.ring_line(c, rv, "Bella")
				check(not ln.contains("'s his") and not ln.contains("'s her") and not ln.contains("'s a ") and not ln.contains("'s the ") and not ln.contains("stands"), "clean line: " + ln)
				for r: Array in rv:
					check(int(r[2]) <= int(c["cap"]), "rival under the cap")
	# Rivals stable for a day, harder in later years.
	check(str(AS.rivals("harvest", "animals", 14)) == str(AS.rivals("harvest", "animals", 14)), "rivals seeded by day")
	var y1: Array = AS.rivals("harvest", "animals", 14)
	var y3: Array = AS.rivals("harvest", "animals", 14 + 2 * AS.YEAR_DAYS)
	check(int(y3[0][2]) > int(y1[0][2]), "year 3 rivals are better")
	var y9: Array = AS.rivals("harvest", "animals", 14 + 9 * AS.YEAR_DAYS)
	var best := AS.cat("harvest", "animals")
	check(int(y9[0][2]) <= int(best["cap"]) and int(best["cap"]) < 80 + 20 + 25 + 25 + 10, "a perfect rare animal can still win in year 10")
	# 4th place: honourable mention, no ribbon.
	var rv1: Array = AS.rivals("harvest", "animals", 14)
	check(AS.place_for(0, rv1) == 4, "a zero score is 4th")
	check(AS.prize(best, 4) == 10 and AS.result_line(4, "Bella", 10).contains("honourable mention") and not AS.result_line(4, "Bella", 10).contains("ribbon goes"), "4th: mention and small coins")
	check(AS.place_for(999, rv1) == 1 and AS.prize(best, 1) == 250, "a top score wins blue")
	# Records feed the ribbon count.
	AS.record("harvest", "animals", 1)
	AS.record("egg", "eggs", 4)
	check(AS.blue_ribbons() == 1 and GameState.run["flags"].has(AS.done_key("egg", "eggs")), "ribbons recorded, 4th recorded as done")
	check(int(GameState.run["flags"].get("show_won_harvest", 0)) == 1, "show_won kept")
	# Tam's lamb gets a word from Tam.
	GameState.run["flags"]["tam_lamb_home"] = a
	check(str(AS.giver_line(a)[0]) == "tam" and AS.giver_line(b).is_empty(), "Tam speaks up for his lamb")
	# Titles per arc.
	check(AS.stand_title("harvest") == "Animal Show", "penguin title")
	GameState.run["arc"] = "gangsters"
	check(AS.stand_title("harvest") == "Stock Show" and not AS.stand_title("harvest").to_lower().contains("block fair"), "gangster arc: Stock Show")
	check(AS.near_stand("harvest", Vector2i(37, 41)) and not AS.near_stand("harvest", Vector2i(50, 50)) and not AS.near_stand("star", Vector2i(36, 40)), "near the stand: its tune")
	check(ResourceLoader.exists("res://audio/music/animal_show.ogg") and ResourceLoader.exists("res://audio/music/ranch.ogg"), "show and ranch tunes exist (ACE alt takes)")
	# Collections: a Show ribbons row counts blue ribbons.
	var col: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/collections.json"))
	check(JSON.stringify(col).contains("show_blue"), "collections.json has a Show ribbons row")
	print("animal_show_test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
