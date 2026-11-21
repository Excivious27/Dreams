extends SceneTree
## What you hear walking into a region a campaign still holds (Campaign.gate_words):
## for every campaign of both arcs, at each stage of the lead-in (meadow not
## cleared, story, training, earlier region, story tier, team/provisions, ready,
## under way), the message names the right next step and person and agrees with
## the real locks (Campaign.why_locked / CampaignGate). Every region has its own
## sense line per arc.
##   godot --headless --path . -s res://tools/campaign_words_test.gd  (-- -v prints every line)
var fails := 0
var verbose := false


func check(ok: bool, what: String) -> void:
	if not ok or verbose:
		print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _done(qid: String) -> void:
	var def := GameState._quest_def(qid)
	GameState.add_quest(qid, str(def.get("text", qid)))
	for q in GameState.run["quests"]:
		if str(q["id"]) == qid:
			q["done"] = true


func _words(arc: String, cid: String, want: String, must: Array) -> Dictionary:
	var gw := Campaign.gate_words(cid)
	var all_text := " ".join(gw["lines"])
	check(str(gw["stage"]) == want, "%s/%s: stage %s (got %s): %s" % [arc, cid, want, gw["stage"], all_text])
	check((gw["lines"] as Array).size() == 2 and not all_text.contains("held against"), "%s/%s: a sense line and a step" % [arc, cid])
	for w: String in must:
		check(all_text.contains(w), "%s/%s [%s]: mentions '%s'" % [arc, cid, want, w])
	# C12 (c12_13-14/15): region names in sentences carry their article, and the
	# sense line's tail matches the stage (no "not yet" once it's under way).
	var bare := str(Campaign.get_c(cid).get("region_name", ""))
	for pre: String in [" into ", " to ", " for "]:
		if Campaign.region_phrase(Campaign.get_c(cid)) != bare:
			check(not all_text.contains(pre + bare + " ") and not all_text.contains(pre + bare + "."), "%s/%s [%s]: no bare region name after '%s' (%s)" % [arc, cid, want, pre.strip_edges(), all_text])
	var tail := str(gw["lines"][0])
	if want == "under_way":
		check(not tail.contains("Not yet") and not tail.contains("walking in alone"), "%s/%s: no 'not yet' tail once under way (%s)" % [arc, cid, tail])
	elif want in ["gather", "ready"]:
		check(not tail.contains("walking in alone") and not tail.contains("doesn't feel safe"), "%s/%s: muster-stage tail (%s)" % [arc, cid, tail])
	else:
		check(tail.contains("Not yet") or tail.contains("doesn't feel safe"), "%s/%s: shut-way tail (%s)" % [arc, cid, tail])
	# Truth: the board would agree.
	var wl := Campaign.why_locked(cid)
	match want:
		"story":
			check(not CampaignGate.story_ok() and CampaignGate.lock(cid) == CampaignGate.story_need() and wl != "", "%s/%s: story lock is real" % [arc, cid])
		"train":
			check(CampaignGate.story_ok() and not CampaignGate.trained() and CampaignGate.lock(cid).begins_with("Train") and wl != "", "%s/%s: training lock is real" % [arc, cid])
		"after":
			check(wl.begins_with("Open "), "%s/%s: an earlier region really comes first (%s)" % [arc, cid, wl])
		"later":
			check(wl == "Get further in the story first.", "%s/%s: story-tier lock is real (%s)" % [arc, cid, wl])
		"gather":
			check(wl != "" and wl == CampaignGate.short_text(cid), "%s/%s: team/provisions lock is real" % [arc, cid])
		"ready":
			check(wl == "", "%s/%s: ready means it can be mustered" % [arc, cid])
		"under_way":
			check(Campaign.started(cid), "%s/%s: under way" % [arc, cid])
	check(bool(gw["board"]) == (want in ["train", "after", "gather", "ready", "under_way"]), "%s/%s: board offered only when useful" % [arc, cid])
	check(not all_text.contains("only way into"), "%s/%s: no false geography" % [arc, cid])
	return gw


func _initialize() -> void:
	seed(7)
	verbose = "-v" in OS.get_cmdline_user_args()
	Campaign.bypass = false
	for arc: String in ["penguins", "gangsters"]:
		var lead := "Catkins" if arc == "penguins" else "Sal"
		GameState.new_run(arc, "kairi" if arc == "penguins" else "pax", "Hero", "Dreamhollow", "Biscuit")
		GameState.run["quests"] = []
		GameState.run["party"] = {}
		var senses := {}
		for cid: String in Campaign.for_arc():
			var s := str(Campaign.get_c(cid).get("sense", {}).get(arc, ""))
			check(s != "" and not senses.has(s), "%s/%s: its own sense line" % [arc, cid])
			senses[s] = true
			_words(arc, cid, "story", ["east meadow", lead])
		_done("clear_meadow")
		for cid: String in Campaign.for_arc():
			_words(arc, cid, "story", [lead, "crystal meadow" if arc == "penguins" else "Hideout town"])
		if arc == "penguins":
			GameState.run["flags"]["meow_taught"] = true
		else:
			GameState.run["flags"]["hideout_seen"] = true
		for cid: String in Campaign.for_arc():
			_words(arc, cid, "train", [lead, "Training"])
		GameState.run["flags"][CampaignGate.TRAINED] = true
		# Earlier region first / story tier / gather, depending on the campaign.
		for cid: String in Campaign.for_arc():
			var c := Campaign.get_c(cid)
			var pre := Campaign.first_in_chain(cid)
			if pre != cid:
				# the step names the first held campaign of the whole chain, which has none before it
				check(Campaign.first_in_chain(pre) == pre and not Campaign.region_open(str(Campaign.get_c(pre)["region"])), "%s/%s: chain start %s is real" % [arc, cid, pre])
				var gwa := _words(arc, cid, "after", [Campaign.region_phrase(Campaign.get_c(pre)), str(Campaign.get_c(pre)["title"]), Campaign.who(cid)])
				check(str(gwa.get("cid", "")) == pre, "%s/%s: the board opens on %s" % [arc, cid, pre])
			elif GameState.progress_tier() < int(c.get("min_pt", 0)):
				_words(arc, cid, "later", ["story"])
			else:
				_words(arc, cid, "gather", ["muster", str(c["title"])])
		# Open every region but one and push the story on: each campaign in turn is
		# later / gather / ready / under way.
		for q: String in ["spark", "wastes_gate", "sky_stair", "teleporter"] if arc == "penguins" else ["docks", "neon", "uptown"]:
			_done(q)
		var pool: Array = ["dad", "mom", "pax", "mer", "penguin_f", "coldy", "penguin_m", "big_jim"] if arc == "penguins" else ["sal", "dad", "mom", "pax", "mer", "big_jim", "kairi"]
		for cc: String in pool:
			if cc != str(GameState.run.get("playable", "")):
				Companion.recruit(cc, false)
		for cid: String in Campaign.for_arc():
			Campaign.st()["open"][str(Campaign.get_c(cid)["region"])] = true
		for cid: String in Campaign.for_arc():
			var c := Campaign.get_c(cid)
			var reg := str(c["region"])
			Campaign.st()["open"].erase(reg)
			var mt := int(c.get("min_pt", 0))
			var short := CampaignGate.team_short(cid) > 0 or not CampaignGate.provisions_short(cid).is_empty()
			if GameState.progress_tier() < mt:
				_words(arc, cid, "later", ["story"])
			elif short:
				_words(arc, cid, "gather", [Campaign.who(cid)])
			var nd: Dictionary = CampaignGate.need(cid)
			for it: String in nd.get("items", {}):
				GameState.add_item(it, int(nd["items"][it]))
			GameState.run["crystals"] = int(GameState.run.get("crystals", 0)) + int(nd.get("crystals", 0))
			if CampaignGate.team_short(cid) == 0 and GameState.progress_tier() >= mt:
				_words(arc, cid, "ready", [Campaign.who(cid), str(c["title"]), "Muster"])
				check(CampaignGate.muster(cid) != "", "%s/%s: musters" % [arc, cid])
				_words(arc, cid, "under_way", ["territories" if arc == "penguins" else "blocks", str(c["title"])])
			Campaign.st()["open"][reg] = true
	print("campaign_words_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
