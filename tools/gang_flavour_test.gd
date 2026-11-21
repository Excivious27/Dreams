extends SceneTree
## Gangster-arc flavour of the Rec Hall, its arcade and the Westside Lot Garden:
## arc names, prize swaps (fuzzy dice / pinstripe fedora for the penguin plush and
## top hat), the claw's pool, cabinet names, every villager's lines there, and an
## all-ages word check over every gangster-arc text in those systems.
##   godot --headless --path . -s res://tools/gang_flavour_test.gd
var fails := 0

## Words that don't belong in the gangster arc's texts here (all ages; and the
## other arc's names: no crystals, commons, penguins or Rec Center).
const BANNED := ["blood", "bleed", "drug", "beer", "whisk", "booze", "drunk", " wine", "cigar", "smok", "kill", "dead", "corpse",
	"gambl", "casino", "stakes", "rec center", "commons", "dreamhollow", "penguin", "crystal"]
## C11b P6 (c11b_03-04): lab-strain hazards (all ages: cute cyber, no wounds, no experiments).
const LAB_BANNED := ["inject", "needle", "syringe", "surgery", "operate on", "operated on", "dissect", "mutant", "mutat",
	"experiment", "test subject", "lab rat", "cage", "implanted", "scalpel", "stitches", "wound"]
## Adults who visit the hall get their own gangster-arc lines (the kids' lines suit both arcs).
const KIDS := ["pip", "tobin", "mabel", "wren_jr"]


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _texts(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			_texts(x, out)
	elif v is Dictionary:
		for k in v:
			_texts(v[k], out)


func _clean(where: String, texts: Array) -> void:
	for t in texts:
		var low := str(t).to_lower()
		for w: String in BANNED:
			ok(not low.contains(w), "%s: '%s' in \"%s\"" % [where, w, str(t)])


func _run() -> void:
	# --- the gangster arc -------------------------------------------------------
	GameState.new_run("gangsters", "dad", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["rec_open"] = 1
	GameState.run["day"] = 12
	ok(RecCenter.name() == "Rec Hall", "the hall is the Rec Hall (%s)" % RecCenter.name())
	ok(Commons.place_name() == "Westside Lot Garden" and Commons.short_name() == "the lot garden", "the garden is the Westside Lot Garden")
	ok(Tickets.game_name("stack") == "Neon Stack", "the stacker is Neon Stack (%s)" % Tickets.game_name("stack"))
	ok(Tickets.game_name("bowling") == "Bowling", "other names unchanged")
	# Guide 26 #1 / #5: gangster cabinet names and the 2am Rec Hall.
	ok(Tickets.game_name("whack") == "Whack-a-Snitch" and Tickets.game_name("gallery") == "Neon Range", "whack/gallery gangster names (%s, %s)" % [Tickets.game_name("whack"), Tickets.game_name("gallery")])
	var wg := ArcadeWhack.new()
	var gg := ArcadeGallery.new()
	ok(wg.title == "Whack-a-Snitch" and gg.title == "Neon Range", "cabinet screens use the arc names")
	ok(not " ".join(wg.howto).to_lower().contains("grump"), "whack how-to has no grumps in this arc")
	wg.free()
	gg.free()
	ok(RecCenter.hours() == [9, 26], "Rec Hall open 9am to 2am (%s)" % str(RecCenter.hours()))
	GameState.run["time"] = 25 * 60 + 30
	ok(RecCenter.why_closed() == "", "Rec Hall open at 1:30am")
	GameState.run["time"] = 26 * 60 + 10
	ok(RecCenter.why_closed() != "" and RecCenter.why_closed().contains("2am"), "shut after 2am (%s)" % RecCenter.why_closed())
	GameState.run["time"] = 12 * 60
	for q: Dictionary in GameState.load_json("res://data/quests.json")["side"]:
		if q.has("text_gangsters"):
			_clean("quest " + str(q["id"]), [q["text_gangsters"]])
			ok(not str(q["text_gangsters"]).contains("Grump") and not str(q["text_gangsters"]).contains("Duck Pond"), "quest %s gangster text" % q["id"])
	ok(ArcadeStack._crush() == "NEON CRUSH!", "four-row shout is NEON CRUSH!")
	# Prize swaps.
	ok(not Tickets.arc_ok("rp_penguin_plush") and not Tickets.arc_ok("rp_top_hat"), "penguin plush and top hat are the other arc's")
	ok(Tickets.arc_ok("rp_fuzzy_dice") and Tickets.arc_ok("rp_lane_fedora"), "fuzzy dice and fedora are on this counter")
	Tickets.add(2000, "test")
	ok(Tickets.buy("rp_penguin_plush") != "" and GameState.count("rp_penguin_plush") == 0, "no penguin plush from the gangster counter")
	ok(Tickets.buy("rp_fuzzy_dice") == "" and GameState.count("rp_fuzzy_dice") == 1, "fuzzy dice for 90 tickets")
	ok(GameState.can_gift("mabel", "rp_fuzzy_dice"), "fuzzy dice make a gift")
	Tickets.set_best("bowling", 150)
	ok(Tickets.buy("rp_lane_fedora") == "" and GameState.count("rp_lane_fedora") == 1, "pinstripe fedora at a 150 game")
	ok(Art.has("items", Hud.icon_for("rp_fuzzy_dice")) and Art.has("items", Hud.icon_for("rp_lane_fedora")), "swap prizes have icons")
	ok(Tickets.lock_text("rp_top_hat") != "", "top hat stays locked here")
	# The claw never drops the other arc's plush.
	var claw := ArcadeClaw.new()
	claw.rng.seed = 7
	var seen := {}
	for i in 600:
		seen[claw._roll_item()] = true
	ok(not seen.has("rp_penguin_plush") and seen.has("rp_fuzzy_dice"), "claw pool: dice, never the penguin plush (%s)" % str(seen.keys()))
	claw.free()
	# Cabinet hints in the hall use this arc's names.
	var room: Dictionary = GameState.load_json("res://data/interiors.json")["rec"]
	var built := RecCenter.build_room(null, room)
	var hints: Array = []
	for th: Dictionary in built.get("things", []):
		if str(th.get("act", "")) == "cabinet":
			hints.append(str(th["hint"]))
	ok(hints.has("A: play Neon Stack") and not hints.has("A: play Crystal Stack"), "cabinet hint reads Neon Stack (%s)" % str(hints))
	# Every visitor's lines in the hall: adults get gangster lines, nothing off-arc.
	var rec: Dictionary = RecCenter.data()
	for id in rec.get("visitors", {}):
		if not KIDS.has(str(id)):
			ok((rec.get("chat_gang", {}) as Dictionary).has(id), "%s has gangster-arc lines at the hall" % id)
		var lines: Array = []
		for l in RecCenter.talk_pool(str(id)):
			lines.append(str(l))
		ok(not lines.is_empty(), "%s says something at the hall" % id)
		_clean("hall chat " + str(id), lines)
	# Every gangster-arc text these systems hold.
	var gang_texts: Array = []
	_texts(rec.get("chat_gang", {}), gang_texts)
	_texts(rec.get("chat_soon_gang", []), gang_texts)
	_texts(rec.get("chat_any", []), gang_texts)
	_texts(rec.get("chat_score", []), gang_texts)
	var ql: Dictionary = GameState.load_json("res://data/quest_lines.json")
	for k in ql:
		if str(k).begins_with("rec_") and str(k).ends_with("@gangsters"):
			_texts(ql[k], gang_texts)
	var cf: Dictionary = Commons.data()
	for k in cf:
		var v: Variant = cf[k]
		if v is Dictionary and (v as Dictionary).has("gangsters"):
			_texts(v["gangsters"], gang_texts)
	for s: Dictionary in cf.get("stages", []):
		for f in ["name", "desc", "done"]:
			_texts(Commons.tx(s.get(f, "")), gang_texts)
	for row: Array in cf.get("talk_own", []):
		_texts(Commons.tx(row[2]), gang_texts)
	for v in cf.get("talk_any", []):
		_texts(Commons.tx(v), gang_texts)
	for k in cf.get("at_work", {}):
		_texts(Commons.tx(cf["at_work"][k]), gang_texts)
	ok(gang_texts.size() > 100, "gangster texts gathered (%d)" % gang_texts.size())
	_clean("gangster text", gang_texts)
	# Items both arcs see (rec prizes, garden food) never name one arc's place.
	for id in GameState.items:
		var it: Dictionary = GameState.items[id]
		if (bool(it.get("rec", false)) or str(id) in ["commons_stew", "harvest_cobbler", "harvest_basket", "green_thumb_charm"]) and str(it.get("arc", "")) == "":
			var t := (str(it.get("name", "")) + " " + str(it.get("desc", ""))).to_lower()
			ok(not t.contains("rec center") and not t.contains("rec hall") and not t.contains("commons") and not t.contains("high roller"), "item %s is arc-neutral (%s)" % [id, t])
	# The bowling quest's text suits both arcs.
	for q: Dictionary in GameState.load_json("res://data/quests.json")["side"]:
		if str(q["id"]).begins_with("rec_"):
			if q.has("text_gangsters"):  # C12 P5: one text per arc (the Rec Center / the Rec Hall)
				ok(not str(q["text_gangsters"]).contains("Rec Center") and not str(q["text"]).contains("Rec Hall"), "quest %s texts fit their arcs" % q["id"])
			else:
				ok(not str(q["text"]).contains("Rec Center") and not str(q["text"]).contains("Rec Hall"), "quest %s text is arc-neutral" % q["id"])

	# --- the penguin arc keeps its own ------------------------------------------
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	ok(RecCenter.name() == "Rec Center" and Commons.place_name() == "Dreamhollow Commons", "penguin arc names")
	ok(Tickets.game_name("stack") == "Crystal Stack" and ArcadeStack._crush() == "CRYSTAL CRUSH!", "penguin arc keeps Crystal Stack")
	ok(Tickets.game_name("whack") == "Whack-a-Grump" and Tickets.game_name("gallery") == "Duck Pond", "penguin arc keeps Whack-a-Grump / Duck Pond")
	ok(RecCenter.hours() == [9, 24], "Rec Center open 9am to midnight")
	GameState.run["time"] = 24 * 60 + 30
	ok(RecCenter.why_closed() != "", "Rec Center shut at 0:30am")
	# Guide 26 #4: Prize Candy is a loved gift for anyone who likes candy.
	ok(GameState.gift_value("pip", "rp_candy") >= 20, "Prize Candy loved by Pip (%d)" % GameState.gift_value("pip", "rp_candy"))
	ok(GameState.gift_line("pip", "rp_candy", GameState.gift_value("pip", "rp_candy")) == GameState.gift_line("pip", "rp_candy", 20), "Pip reacts with a loved line")
	ok(Tickets.arc_ok("rp_penguin_plush") and not Tickets.arc_ok("rp_fuzzy_dice") and not Tickets.arc_ok("rp_lane_fedora"), "penguin counter swaps back")
	var claw2 := ArcadeClaw.new()
	claw2.rng.seed = 7
	var seen2 := {}
	for i in 600:
		seen2[claw2._roll_item()] = true
	ok(seen2.has("rp_penguin_plush") and not seen2.has("rp_fuzzy_dice"), "penguin claw pool")
	claw2.free()

	# Collections (C8 P3): every gangster text in collections.json (letters, milestones, room names, wings).
	var coll: Dictionary = GameState.load_json("res://data/collections.json")
	var ctexts := []
	for m: Dictionary in coll.get("milestones", []):
		ctexts.append(str(m.get("text_gangsters", "")))
	for k in coll.get("letters", {}):
		if str(k).ends_with("_gangsters"):
			ctexts.append(str(coll["letters"][k]))
	ctexts.append(str(coll.get("room_names", {}).get("gangsters", "")))
	for w: Dictionary in coll.get("wings", []):
		ctexts.append(str(w["title"]))
	_clean("collections", ctexts)

	# C11b P6 (c11b_03-04): ranch texts of the gangster arc (lab strains, names, show, buildings): all ages,
	# cute cyber, never a lab-hazard word.
	var rtexts: Array = []
	var rj: Dictionary = GameState.load_json("res://data/ranch.json")
	for sid: String in rj.get("species", {}):
		var sd: Dictionary = rj["species"][sid]
		if str(sd.get("arc", "")) == "penguins":
			continue  # penguin-only creatures never show in a gangster run (C11b integ)
		rtexts.append(str(sd.get("name_gang", "")))
		if str(sd.get("arc", "")) == "gangsters":
			_texts(sd, rtexts)
	for pid: String in rj.get("products", {}):
		if str((rj["products"][pid] as Dictionary).get("arc", "")) == "gangsters":
			_texts(rj["products"][pid], rtexts)
	var AS: GDScript = load("res://scripts/animal_show.gd")
	for fest: String in AS.CATS:
		for c: Dictionary in AS.CATS[fest]:
			rtexts.append_array([str(c.get("title_gang", "")), str(c.get("ask_gang", ""))])
	for bn: String in Builds.GANG_NAMES:
		rtexts.append(str(Builds.GANG_NAMES[bn]))
	_clean("ranch", rtexts)
	for t in rtexts:
		var low := str(t).to_lower()
		for w: String in LAB_BANNED:
			ok(not low.contains(w), "ranch lab word '%s' in \"%s\"" % [w, str(t)])

	print("gang_flavour_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
