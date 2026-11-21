extends SceneTree
## C11b P3: RanchGift (creature gifts from data): add with room, once per source, waiting in
## run.ranch.pending with a letter naming what makes room, delivery when room appears, a keepsake
## (Tam's lamb) going one over a full barn, arc filtering (fantastic = penguins, lab = gangsters),
## reward rows with animal_gang; plus Companion game-time cooldowns, chest labels, show-eve letter.
##   godot --headless --path . -s res://tools/ranch_gift_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(31)
	for arc in ["penguins", "gangsters"]:
		_gifts(arc)
		_keepsake(arc)
		_arcs(arc)
	_cooldowns()
	_chests()
	_letters()
	print("ranch_gift_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(arc: String) -> void:
	GameState.use_slot(2)
	GameState.new_run(arc, "dad" if arc == "gangsters" else "mom", "Tester", "Town", "Pup")
	GameState.run["day"] = 3
	GameState.run["builds"] = {"coop": 1, "barn": 1}
	GameState.run.erase("ranch")


func _letters_with(word: String) -> int:
	var n := 0
	for m: Dictionary in Mail.list():
		if word in str(m.get("text", "")):
			n += 1
	return n


func _gifts(arc: String) -> void:
	_fresh(arc)
	var uid := RanchGift.give("chicken", "test:hen")
	check(uid != "" and bool(Ranch.animal(uid).get("gift", false)), "%s: a gift with room joins at once" % arc)
	check(RanchGift.give("chicken", "test:hen") == "", "%s: one gift per source" % arc)
	for i in Ranch.capacity("barn"):
		Ranch.add("cow")
	var before := Mail.list().size()
	check(RanchGift.give("sheep", "test:sheep") == "", "%s: a full barn: the gift waits" % arc)
	check(RanchGift.pending().size() == 1, "%s: one pending gift" % arc)
	check(Mail.list().size() == before + 1, "%s: one waiting letter" % arc)
	var want := str(Builds.tier_def("barn", 2).get("name", "Big Barn"))
	check(_letters_with(want) >= 1, "%s: the letter names what makes room (%s)" % [arc, want])
	check(RanchGift.deliver().is_empty() and RanchGift.pending().size() == 1, "%s: still full: still waiting" % arc)
	GameState.run["builds"]["barn"] = 2
	var got := RanchGift.deliver()
	check(got.size() == 1 and RanchGift.pending().is_empty(), "%s: room appears: the gift walks over" % arc)
	# A reward row (GameState._give_reward hook).
	GameState._give_reward({"animal": ["goat", "Tam"], "gift_key": "test:goat"})
	check(RanchGift.given("test:goat"), "%s: a quest reward gives an animal" % arc)


func _keepsake(arc: String) -> void:
	_fresh(arc)
	for i in Ranch.capacity("barn"):
		Ranch.add("cow")
	GameState.run["flags"]["hv_tam_8"] = true
	Mail._tam_lamb(3)
	var uid := str(GameState.run["flags"].get("tam_lamb_home", ""))
	check(uid != "", "%s: Tam's lamb goes one over a full barn" % arc)
	check(Ranch.roster("barn").size() == Ranch.capacity("barn") + 1, "%s: barn one over capacity" % arc)
	check(bool(Ranch.animal(uid).get("keepsake", false)) and not Ranch.rehome(uid), "%s: the keepsake can't be rehomed" % arc)
	# A second keepsake doesn't go two over: it waits.
	check(RanchGift.give("sheep", "test:keep2", {"keepsake": true, "home": "barn"}) == "", "%s: never two over" % arc)


func _arcs(arc: String) -> void:
	_fresh(arc)
	var before := RanchGift.pending().size()
	RanchGift.give("coral_seahorse", "colony:test")
	check(RanchGift.pending().size() == before + (1 if arc == "penguins" else 0), "%s: a penguin-only creature waits only in its arc" % arc)
	RanchGift.give("volt_gecko", "test:gecko")
	check(RanchGift.pending().size() == before + 1, "%s: one of the two arc-only creatures waits" % arc)
	var rw := {"animal": ["lantern_moth", "Liesl"], "animal_gang": ["peacock", "Liesl"], "gift_key": "mega:test"}
	RanchGift.from_reward(rw)
	var last: Dictionary = RanchGift.pending().back() if not RanchGift.pending().is_empty() else {}
	var want := "lantern_moth" if arc == "penguins" else "peacock"
	check(str(last.get("species", "")) == want or (Ranch.species(want).size() > 0 and RanchGift.given("mega:test")), "%s: reward picks the arc's creature (%s)" % [arc, want])


func _cooldowns() -> void:
	Companion.reset_cooldowns()
	check(Companion.cooldown_left("mend") == 0.0 and Companion.cooldown_frac("mend") == 0.0, "no cooldown after reset")
	Companion._start_cd("mend", 12.0)
	check(absf(Companion.cooldown_left("mend") - 12.0) < 0.01, "cooldown on the game clock")
	check(absf(Companion.cooldown_frac("mend") - 1.0) < 0.01, "ring starts empty for a shortened cooldown (frac from its own total)")
	Companion.reset_cooldowns()
	check(Companion.cooldown_left("mend") == 0.0, "new game / load clears cooldowns")


func _chests() -> void:
	_fresh("penguins")
	GameState.run["chests"] = {}
	Storage.box("p:10,10")
	Storage.box("p:40,30")
	Storage.box("p:house:3,4")
	var a := Storage.label("p:10,10")
	var b := Storage.label("p:40,30")
	var c := Storage.label("p:house:3,4")
	check(a.begins_with("Chest 1 (") and b.begins_with("Chest 2 ("), "placed chests are numbered: %s / %s" % [a, b])
	check(c == "Chest 3 (in the house)", "indoor chest label: %s" % c)
	check(not ("chest at" in Helpers.chest_name("p:10,10")), "chores show the friendly name")
	Storage.rename("p:10,10", "Seeds")
	check(Storage.label("p:10,10") == "Seeds", "a renamed chest keeps its name")


func _letters() -> void:
	for arc in ["penguins", "gangsters"]:
		_fresh(arc)
		check(Mail.show_line("harvest") != "" and Mail.show_line("egg") != "" and Mail.show_line("star") == "", "%s: festival eve names the show" % arc)
	check(Shops.animal_why("bees") != "", "bees: needs its Plans build (build_of, not a hard-coded beehive)")
