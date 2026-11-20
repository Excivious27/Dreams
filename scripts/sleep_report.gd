class_name SleepReport
extends RefCounted
## The morning summary (sell box, growth, crows, builds, crew, weather, next
## step) as dialogue lines. house.gd shows it after a night in bed; a pass-out
## night (GameMap.player_down) keeps the report in flags.wake_report and the
## house or the clinic shows it on waking, so nothing that happened overnight
## is lost to a collapse.


## A copy that survives the save file (the report is plain ints/strings/arrays).
static func keep(report: Dictionary) -> Dictionary:
	return report.duplicate(true)


## Lines from a stored pass-out report (and clear it); empty when there's none.
static func take_kept() -> Array:
	var f: Dictionary = GameState.run.get("flags", {})
	var rep: Variant = f.get("wake_report", null)
	f.erase("wake_report")
	if not (rep is Dictionary) or (rep as Dictionary).is_empty():
		return []
	return lines(rep as Dictionary)


static func lines(report: Dictionary) -> Array:
	var lines: Array = []
	if int(report.get("earned", 0)) > 0:
		lines.append({"who": "Sell box", "text": "%s\nTotal: ◆%d" % ["\n".join(report.get("sold", [])), int(report.get("earned", 0))]})
	var ship_new: Array = report.get("ship_new", [])  # Collections (C8 P3) fills it from GameState.sleep
	if not ship_new.is_empty():
		var names: Array = []
		for id in ship_new.slice(0, 3):
			names.append(GameState.item_name(str(id)))
		lines.append({"who": "Shipping log", "text": "New: %s%s." % [", ".join(names), (" +%d more" % (ship_new.size() - 3)) if ship_new.size() > 3 else ""]})
	if int(report.get("left", 0)) > 0:
		lines.append({"text": Sanctuary.morning_line()})
	if int(report.get("washed", 0)) > 0:
		lines.append({"who": "Laundromat", "text": "Clean and folded: ◆%d." % int(report["washed"])})
	if int(report.get("grown", 0)) > 0:
		lines.append({"text": "%d watered crop%s grew overnight." % [int(report.get("grown", 0)), "" if int(report.get("grown", 0)) == 1 else "s"]})
	if int(report.get("dry", 0)) > 0:
		lines.append({"text": "%d crop%s went without water and didn't grow. Water each one with the can every day (rain does it for you)." % [int(report["dry"]), "" if int(report["dry"]) == 1 else "s"]})
	if int(report.get("ripe", 0)) > 0 and GameState.quest_done("first_harvest"):  # before that the Next: line says it
		lines.append({"text": "%d crop%s ripe: face %s and tap USE to harvest." % [int(report["ripe"]), " is" if int(report["ripe"]) == 1 else "s are", "it" if int(report["ripe"]) == 1 else "them"]})
	if GameState.sky_waters() and not (GameState.run["farm"] as Dictionary).values().filter(func(t: Variant) -> bool: return t is Dictionary and str(t.get("crop", "")) != "").is_empty():
		lines.append({"text": "The %s waters the field today: no need for the can." % ("snow" if GameState.weather_today() in ["snow", "blizzard"] else "rain")})
	if int(report.get("crows", 0)) > 0:
		lines.append({"text": "Crows got into the field overnight and ate %d crop%s. A scarecrow covers about 8 steps around it." % [int(report["crows"]), "" if int(report["crows"]) == 1 else "s"]})
	if int(report.get("died", 0)) > 0:
		lines.append({"text": "%s took %d crop%s. Crops only live through their own season (or under the greenhouse glass)." % [GameState.season().capitalize(), int(report["died"]), "" if int(report["died"]) == 1 else "s"]})
	for l in extra_lines():
		lines.append(l)
	for nm in report.get("built", []):
		lines.append({"who": "Hazel", "text": "Crew's done with the %s. Go have a look." % str(nm)})
	if int(report.get("wash_back", 0)) > 0:
		lines.append({"who": "Laundromat", "text": "%d bill%s came back unwashed: the machines only take so much face value a night." % [int(report["wash_back"]), "" if int(report["wash_back"]) == 1 else "s"]})
	for kind in ["pool", "burrow"]:
		if GameState.run["flags"].has("basket_full_" + kind):
			GameState.run["flags"].erase("basket_full_" + kind)
			lines.append({"text": "The %s basket is full. Empty it, or the gifts stop." % kind})
	for l in report.get("cfarm", []):
		lines.append({"who": Commons.keeper_name(), "text": str(l)})
	if report.has("crew_jobs"):
		lines.append({"who": "HQ", "text": "Overnight:\n" + "\n".join(report["crew_jobs"])})
	# Arc project effects that work overnight (Project.overnight).
	var proj: Array = []
	if report.has("ward_shard"):
		proj.append("The Ward Stone left a crystal shard for you.")
	if report.has("star_beacon"):
		proj.append("The Star Beacon gathered a pinch of star dust.")
	if report.has("safehouse"):
		proj.append("The safehouse kept things quiet: heat cooled a notch.")
	if not proj.is_empty():
		lines.append({"text": "\n".join(proj)})
	if report.has("relic"):
		lines.append({"who": "Marlene", "text": "A little something from the tower. Don't ask. (%s)" % GameState.item_name(str(report["relic"]))})
	if Racket.on() and (Racket.heat() > 0 or GameState.run["flags"].has("heat_told")):  # "Heat 0/5" means nothing before it's explained
		var raids: bool = Racket.heat() >= 3 and not GameState.run["flags"].has("president_freed")  # no collectors once the stone is broken
		lines.append({"text": "Heat %d/5.%s" % [Racket.heat(), " Collectors may be out." if raids else ""]})
		if raids and Crew.perk_level("raid_warning") >= 1:
			lines.append({"who": "Ladder", "text": "Word from the roofs: the President's collectors are walking the districts today. Stay off the main streets, or bring friends."})
	var brief := "%s today, %s tomorrow." % [GameState.weather_name(GameState.weather_today()), GameState.weather_name(GameState.forecast()).to_lower()]
	if GameState.festival_today() != "":
		brief += " It's the %s: head to the plaza." % GameState.festival_name(GameState.festival_today())
	brief += " Sunset about %s." % GameState.clock_of(GameState.sunset())
	lines.push_front({"text": "Day %d. %s" % [int(GameState.run["day"]), brief]})
	_open_due()  # today's new main steps (day-gated) first, so Next: matches the goal line
	var nxt := GameState.next_step()
	if nxt != "":
		lines.append({"text": "Next: " + nxt})
	for nm in report.get("gone", []):
		lines.append({"who": "", "text": "A note under the door, in a hand you know: '%s went east. Didn't say why. You know why.'" % str(nm)})
	if bool(report.get("short", false)):
		if bool(report.get("late", false)):
			lines.insert(1, {"text": "Up late: you woke a little tired. Bed before midnight and you wake on a full bar."})
		else:
			lines.insert(1, {"text": "Collapsing takes it out of you: you wake on three quarters of your energy. Get to bed before you drop (and before 2am) and you wake full."})
	return lines


## C8 P1: a finished tool upgrade waiting at the forge, and animals that missed
## yesterday's pet (their streak resets).
static func extra_lines() -> Array:
	var out: Array = []
	var r := GameState.run
	var job: Variant = (r.get("jobs", {}) as Dictionary).get("smith_upgrade", null)
	if job is Dictionary and (job as Dictionary).has("done_at") and GameState.now_abs() >= int(job["done_at"]):
		out.append({"who": "Gideon", "text": "Your %s is ready at the forge." % GameState.item_name(str(job.get("kind", "tool")))})
	var day := int(r.get("day", 1))
	var missed := 0
	for nm in (r.get("animals", {}) as Dictionary):
		var st: Variant = r["animals"][nm]
		if st is Dictionary and int((st as Dictionary).get("last_pet", -9)) >= 0 and int(st.get("last_pet", -9)) < day - 1:
			missed += 1
	if missed > 0:
		out.append({"text": "%d animal%s went without a pet yesterday: a daily pet keeps the friendship streak going." % [missed, "" if missed == 1 else "s"]})
	return out


## Opens main quests whose day (or other condition) came round overnight, the
## way GameState.tick_quests would on the next map tick, quietly.
static func _open_due() -> void:
	if GameState.run.is_empty():
		return
	for q: Dictionary in GameState.quests_data.get("main", []):
		if str(q.get("arc", "both")) in ["both", str(GameState.run["arc"])] and not GameState.has_quest(str(q["id"])) and GameState._cond_ok(q.get("when", {})):
			GameState.add_quest(str(q["id"]), str(q["text"]))
