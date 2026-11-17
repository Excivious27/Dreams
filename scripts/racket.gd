class_name Racket
extends RefCounted
## The gangster arc's own machinery: printed bills and the risk they carry
## (heat), the laundromat that washes them slowly and safely, forged permits,
## and the Recruit Training Center.
##   run["heat"]  0-5. Each bill that gets noticed adds one. It cools one a night
##                (two with a laundromat). At 3+ the President's collectors may
##                be waiting when you walk into a street.
##   run["wash"]  {bill id: count} left at the laundromat, paid out overnight.

const PEOPLED := ["town", "hideout", "docks", "neon", "uptown", "countryside", "interior", "beach", "riverlands", "quarry"]
const WASH_CAP := [0, 3, 6, 10]
const WASH_RATE := [0.0, 0.8, 0.85, 0.9]
const WASH_FACE_CAP := [0, 300, 900, 2500]   # most face value the wash takes a night
const WASH_TIER_CUT := [0.0, 0.0, 0.0, 0.1, 0.25]  # big notes are harder to clean


static func on() -> bool:
	return str(GameState.run.get("arc", "")) == "gangsters"


static func heat() -> int:
	return int(GameState.run.get("heat", 0))


## The one place heat changes: always 0-5.
static func set_heat(n: int) -> void:
	GameState.run["heat"] = clampi(n, 0, 5)


static func add_heat(m: GameMap, n: int) -> void:
	set_heat(heat() + n)
	if m and n > 0:
		m.hud.toast("Heat %d/5. %s" % [heat(), "Lie low a while." if heat() < 3 else "The President's collectors will be looking."], Color(1, 0.6, 0.4))


## Chance this bill gets noticed right now.
static func risk(id: String) -> float:
	var r := float(GameState.items.get(id, {}).get("risk", 0.3)) + 0.05 * heat()
	r += 0.04 * passed_today()                     # every till you hit today talks to the next
	r -= 0.03 * Crew.perk_level("shop_discount")  # Specs knows which tills to avoid
	return clampf(r, 0.03, 0.9)


## Bills passed today, and how many the streets will take in a day.
static func passed_today() -> int:
	var pd: Dictionary = GameState.run.get("passed_day", {})
	return int(pd.get("n", 0)) if int(pd.get("day", -1)) == int(GameState.run["day"]) else 0


static func pass_cap() -> int:
	return 3 + 2 * GameState.progress_tier()


static func pass_bills(m: GameMap, id: String) -> bool:
	if not on():
		m.hud.toast("Funny-looking money. Best not.")
		return true
	if m.scene_id() not in PEOPLED:
		m.hud.toast("Nobody here to pass them to. Try a town.")
		return true
	if int(GameState.run["flags"].get("burned_day", -1)) == int(GameState.run["day"]):
		m.hud.toast("Word's out today. Every till in town is checking twice.", Color(1, 0.8, 0.6))
		return true
	if passed_today() >= pass_cap():
		m.hud.toast("That's enough paper for one day. Try again tomorrow. (%d/%d)" % [passed_today(), pass_cap()], Color(1, 0.8, 0.6))
		return true
	var it: Dictionary = GameState.items[id]
	var face := int(it.get("face", 50))
	GameState.add_item(id, -1)
	m.player.play_tool("hold")
	var r_now := risk(id)
	GameState.run["passed_day"] = {"day": int(GameState.run["day"]), "n": passed_today() + 1}
	if randf() >= r_now:
		GameState.run["crystals"] = int(GameState.run["crystals"]) + face
		# Big notes get remembered even when nobody says anything.
		if int(it.get("tier", 1)) >= 3:
			GameState.run["heat_shadow"] = float(GameState.run.get("heat_shadow", 0.0)) + 0.25
			if float(GameState.run["heat_shadow"]) >= 1.0:
				GameState.run["heat_shadow"] = 0.0
				add_heat(m, 1)
		GameState.run["passed"] = int(GameState.run.get("passed", 0)) + 1
		GameState.add_xp("bartering", 2 + int(it.get("tier", 1)))
		m.hud.toast("Passed. +◆%d  (risk was %d%%, %d/%d today)" % [face, int(round(r_now * 100.0)), passed_today(), pass_cap()], Color(0.7, 1, 0.7))
		Music.instance(m.get_tree()).sfx("pickup")
		return true
	# Noticed: the bill is gone, you pay to make it go away, and people remember.
	var fine := mini(int(GameState.run["crystals"]), int(face / 2))
	GameState.run["crystals"] = int(GameState.run["crystals"]) - fine
	GameState.run["flags"]["burned_day"] = int(GameState.run["day"])
	var shopkeepers: Array = []
	for k in ["maple", "gideon", "posy", "wren", "ivy"]:
		if GameState.npcs.has(k):
			shopkeepers.append(k)
	var who := str(shopkeepers[randi() % shopkeepers.size()]) if not shopkeepers.is_empty() else ""
	if who != "":
		GameState.add_friend(who, -8)
	m.hud.toast("%s holds it to the light. You pay ◆%d to make it a misunderstanding." % [str(GameState.npcs.get(who, {}).get("name", "The clerk")), fine], Color(1, 0.6, 0.5))
	m.shake(2.0)
	add_heat(m, 1)
	return true


static func forged_permit(m: GameMap, id: String) -> bool:
	if not on():
		m.hud.toast("It wouldn't fool Alder for a second.")
		return true
	var target := ""
	for bid in Builds.data():
		if Builds.gate(str(bid)) == "permit":
			target = str(bid)
			break
	if target == "":
		m.hud.toast("Nothing you can build right now is waiting on a permit.")
		return true
	GameState.add_item(id, -1)
	var nd := Builds.next_def(target)
	if randf() < float(GameState.items[id].get("risk", 0.25)) + 0.05 * heat():
		m.hud.toast("The clerk knows Alder's signature. This isn't it.", Color(1, 0.6, 0.5))
		add_heat(m, 1)
		return true
	GameState.run["permits"] = GameState.run.get("permits", {})
	GameState.run["permits"][target] = int(nd["tier"])
	m.hud.toast("Stamped, more or less: %s permit." % str(nd["name"]), Color(0.7, 1, 0.7))
	return true


## Walking into a street with heat on you.
static func on_enter(m: GameMap) -> void:
	if not on() or heat() < 3 or not m.has_sky or m.scene_id() in ["farm", "house", "moon", "station", "sky", "mine", "hideout"]:
		return
	if int(GameState.run["flags"].get("raid_day", -1)) == int(GameState.run["day"]) or randf() > 0.5:
		return
	GameState.run["flags"]["raid_day"] = int(GameState.run["day"])
	var n := 2 + (heat() - 3)
	for i in n:
		var c := m.spawn_enemy("thug_brute" if i == 0 else "thug_cyber", m.player.position + Vector2(48 + 14 * i, -20 + 20 * i))
		if c:
			c.reward = 0          # collectors carry no cash; beating them is the point
			c.set_meta("collector", true)
	m.hud.toast("Collectors. Somebody remembered your face. Beat them all and the heat drops.", Color(1, 0.5, 0.4))


## A collector went down: when the last one in this street falls, heat drops one.
static func on_collector_down(m: GameMap) -> void:
	for e in m.enemies:
		if is_instance_valid(e) and e._alive and e.has_meta("collector"):
			return
	set_heat(heat() - 1)
	m.hud.toast("The collectors won't be reporting back. Heat %d/5." % heat(), Color(0.7, 1, 0.7))


## Called from sleep(): heat cools, the wash pays out.
static func overnight(report: Dictionary) -> void:
	if not on():
		return
	var lt := Builds.built_tier("laundromat")
	set_heat(heat() - (2 if lt > 0 else 1))
	var wash: Dictionary = GameState.run.get("wash", {})
	var paid := 0
	var face_left := int(WASH_FACE_CAP[clampi(lt, 0, 3)])
	var back := {}
	for id in wash:
		var it: Dictionary = GameState.items.get(str(id), {})
		var face := int(it.get("face", 0))
		var rate := float(WASH_RATE[clampi(lt, 0, 3)]) - float(WASH_TIER_CUT[clampi(int(it.get("tier", 1)), 0, 4)])
		for k in int(wash[id]):
			if face > face_left:
				back[id] = int(back.get(id, 0)) + 1
				continue
			face_left -= face
			paid += int(face * rate)
	for id in back:
		GameState.add_item(str(id), int(back[id]))
		report["wash_back"] = int(report.get("wash_back", 0)) + int(back[id])
	if paid > 0:
		GameState.run["crystals"] = int(GameState.run["crystals"]) + paid
		report["washed"] = paid
	GameState.run["wash"] = {}


static func laundromat(m: GameMap) -> void:
	var lt := Builds.built_tier("laundromat")
	var d := Dialogue.instance(m.get_tree())
	while true:
		var wash: Dictionary = GameState.run.get("wash", {})
		GameState.run["wash"] = wash
		var inside := 0
		for id in wash:
			inside += int(wash[id])
		var room := int(WASH_CAP[lt]) - inside
		var ids: Array = []
		var opts: Array = []
		for id in ["bills_crude", "bills_passable", "bills_fine", "bills_perfect"]:
			if GameState.count(id) > 0 and room > 0:
				ids.append(id)
				opts.append("Wash %s  (have %d · pays ◆%d each tomorrow)" % [GameState.item_name(id), GameState.count(id), int(int(GameState.items[id]["face"]) * float(WASH_RATE[lt]))])
		opts.append("Leave")
		d.say([{"who": str(Builds.current_def("laundromat").get("name", "Laundromat")), "text": "%d of %d in the wash. Paid out clean in the morning, no risk. Heat: %d/5." % [inside, int(WASH_CAP[lt]), heat()], "choice": opts, "key": ""}])
		await d.finished
		if d.last_choice < 0 or d.last_choice >= ids.size():
			return
		var pick := str(ids[d.last_choice])
		var n := mini(room, GameState.count(pick))
		GameState.add_item(pick, -n)
		wash[pick] = int(wash.get(pick, 0)) + n
		m.hud.toast("%d in the wash." % n, Color(0.8, 0.95, 1.0))


static func training(m: GameMap) -> void:
	var tt := Builds.built_tier("training")
	var crew := Crew.all_recruited().size()
	var d := Dialogue.instance(m.get_tree())
	var done: bool = int(GameState.run["flags"].get("spar_day", -1)) == int(GameState.run["day"])
	d.say([{"who": str(Builds.current_def("training").get("name", "Training")), "text": "%d crew on the roster.%s" % [crew, " Their perks count %d step%s higher." % [tt - 1, "" if tt == 2 else "s"] if tt >= 2 else " Build it up and their perks grow."], "choice": ["Spar (done for today)" if done else "Spar with the crew", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice != 0 or done:
		return
	if not GameState.spend_energy(10):
		m.hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	GameState.run["flags"]["spar_day"] = int(GameState.run["day"])
	m.player.play_tool("axe")
	m.xp("combat", (15 + 3 * crew) * (2 if tt >= 2 else 1))
	m.hud.toast("A good session. The new ones are learning to keep their guard up.", Color(1, 0.9, 0.5))
