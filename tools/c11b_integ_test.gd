extends SceneTree
## C11b integration hooks: one voice table (P6 CC0 takes first), "needs an Aviary", the hatch line and
## incubator words, art_for with odd baby data, egg_crack/feeder_fill report flags, Chores.migrate and
## guard_cells, the Harvest chore through GameState.reap_tile, the Gene Splicer handing over lab strains
## through RanchGift (gangster arc only), gift names never in pet name pools.
##   godot --headless --path . --fixed-fps 60 -s res://tools/c11b_integ_test.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(11)
	_voices()
	for arc in ["penguins", "gangsters"]:
		_words(arc)
		_chores(arc)
		_names(arc)
	_splice()
	print("c11b_integ_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(arc: String) -> void:
	GameState.use_slot(2)
	GameState.new_run(arc, "dad" if arc == "gangsters" else "mom", "Tester", "Town", "Pup")
	GameState.run["day"] = 9
	GameState.run["builds"] = {"coop": 2, "barn": 1}
	GameState.run.erase("ranch")


func _voices() -> void:
	check(RanchVoice.voice_id("moon_cow") == "cv_moon" and GameMap.animal_voice("moon_cow_baby") == "cv_moon", "moon cow: P6 CC0 take")
	check(GameMap.animal_voice("ostrich_tawny") == "cv_ostrich", "ostrich variant: CC0 take")
	check(RanchVoice.voice_id("chrome_hen") == "cluck" and RanchVoice.layer_of("chrome_hen") != "", "lab strain keeps its base voice and layer")
	check(RanchVoice.voice_id("alpaca") == "alpaca_hum", "no CC0 take: the pitched table")
	check(GameMap.animal_voice("cow") == "moo" and GameMap.animal_voice("chick") == "peep", "classic voices unchanged")
	for sid: String in Ranch.data()["species"]:
		check(RanchVoice.voice_id(sid) != "", "every species has a voice: " + sid)


func _words(arc: String) -> void:
	_fresh(arc)
	var why := Shops.animal_why("peacock")
	check(not why.contains("a A") and not why.contains("needs a Aviary") and not why.contains("needs a E"), "%s: no 'needs a Aviary' (%s)" % [arc, why])
	# Hatch line: baby word and the building's name, never the home id.
	var uid := Ranch.add("chicken", "coop")
	check(uid != "", arc + ": a hen")
	Ranch.house("coop")["incubator"] = [{"species": "chicken", "due": 9, "q": ""}]
	var rep := {}
	Ranch.overnight(rep)
	var hatched := ""
	for l in rep.get("ranch", []):
		if "hatched" in str(l):
			hatched = str(l)
	check(hatched.begins_with("A chick hatched in the ") and not hatched.contains("in the coop:"), "%s: hatch line (%s)" % [arc, hatched])
	check(int(rep.get("ranch_hatched", 0)) == 1, arc + ": report flag for the egg_crack cue")
	# The incubator refusal names the tier that brings it.
	GameState.run["builds"]["coop"] = 1
	GameState.add_item("egg", 1)
	var refuse := Ranch.incubate("egg")
	check(refuse.begins_with("The incubator comes with the ") and refuse != "The incubator comes with the .", "%s: incubator words (%s)" % [arc, refuse])
	# art_for with a bare-string baby entry never errors.
	var sp: Dictionary = Ranch.species("chicken")
	var art: Dictionary = sp["art"]
	var keep: Variant = art.get("baby", null)
	art["baby"] = "chick"
	var k2 := uid
	Ranch.animal(k2)["adult_day"] = 999
	var af := Ranch.art_for(k2)
	check(str(af.get("group", "")) == "animals/chick" and str(af.get("strip", "")) == "idle", arc + ": art_for with a string baby")
	if keep == null:
		art.erase("baby")
	else:
		art["baby"] = keep


func _chores(arc: String) -> void:
	_fresh(arc)
	GameState.run["chores"] = {"assign": {"bad": "x", "nochore": {"chore": ""}, "w1": {"chore": "water"}}, "xp": {"z": 3}}
	Chores.migrate()
	var a: Dictionary = Chores.st()["assign"]
	check(not a.has("bad") and not a.has("nochore") and a.has("w1"), arc + ": migrate drops broken rows")
	check(str(a["w1"].get("chest", "")) == "chest" and str(a["w1"].get("where", "")) == "edges", arc + ": migrate fills chest/where")
	check(int(Chores.st().get("ver", 0)) == Chores.VER and not (Chores.st()["xp"] as Dictionary).has("z"), arc + ": migrate version, xp cleaned")
	check(Chores.guard_cells().is_empty(), arc + ": nobody on guard: no circles")
	a["w2"] = {"chore": "guard", "chest": "chest", "where": "edges"}
	var g := Chores.guard_cells()
	check(g.size() == 1 and g[0]["c"] is Vector2i and float(g[0]["r"]) >= 6.0, arc + ": a guard worker watches a pen")
	check(GameState._guard_watch().size() == 1, arc + ": GameState._crows reads the circles")
	# Harvest chore: GameState.reap_tile resets the bed (fert used up).
	var key := ""
	for k in GameState.run["farm"].keys():
		key = str(k)
		break
	if key == "":
		key = "20,20"
		GameState.run["farm"][key] = {}
	var crop := "turnip" if GameState.crops.has("turnip") else str(GameState.crops.keys()[0])
	GameState.run["farm"][key] = {"crop": crop, "days": int(GameState.crops[crop].get("days", 1)), "fert": "fertilizer", "watered": true}
	var res := GameState.reap_tile(GameState.run["farm"][key], false)
	check(not (GameState.run["farm"][key] as Dictionary).has("fert") and int(res.get("xp_share", 0)) >= 1, arc + ": reap_tile resets the bed")


func _names(arc: String) -> void:
	_fresh(arc)
	for sid: String in Ranch.data()["species"]:
		for w in (Ranch.species(sid).get("names", []) as Array):
			check(not str(w) in ["Bramble", "Cinder", "Gale", "Maple", "Juniper"], "%s: %s pet name %s" % [arc, sid, w])


func _splice() -> void:
	check(GameState.items.has("splice_chrome_hen") and str(GameState.items["splice_chrome_hen"].get("type", "")) == "splice", "splice items exist")
	var bd: Dictionary = Builds.data().get("gene_splicer", {})
	check(not bd.is_empty() and str(bd.get("arc", "")) == "gangsters" and str((bd.get("station", {}) as Dictionary).get("book", "")) == "splice", "Gene Splicer station (gangsters, book splice)")
	_fresh("gangsters")
	var n0 := Ranch.roster("coop").size()
	Crafting._hand_over_splice(null, "splice_chrome_hen", 2)
	check(Ranch.roster("coop").size() == n0 + 2, "two splices: two chrome hens (%d -> %d)" % [n0, Ranch.roster("coop").size()])
	var hen := ""
	for u in Ranch.roster("coop"):
		if str(Ranch.animal(str(u)).get("species", "")) == "chrome_hen":
			hen = str(u)
	check(hen != "", "the splice is a chrome hen")
	_fresh("penguins")
	var p0 := Ranch.roster("coop").size()
	Crafting._hand_over_splice(null, "splice_chrome_hen", 1)
	check(Ranch.roster("coop").size() == p0 and RanchGift.pending().is_empty(), "penguin arc never gets a lab strain")
