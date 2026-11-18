class_name Ops
extends RefCounted
## The gangster arc's side operations:
##  - Turf: clear every hostile on a district block (docks, neon, uptown,
##    underground) and you hold it. Each block pays ◆ every morning, and
##    collectors don't raid a street you hold.
##  - Heists: three one-time jobs planned with two crew members at the hideout
##    (talk to the planner). Your approach and their loyalty set the odds; a
##    failed heist costs heat and can be tried again another day.
##  - Loyalty missions: a crew member's last loyalty step needs a favour.

const TURF := {"docks": "the docks", "neon": "Neon", "uptown": "Uptown", "underground": "the pit", "alley": "the alley"}
const TURF_PAY := 40

const HEISTS := {
	"cannery": {"name": "The Cannery Job", "where": "docks", "planner": "ladder", "crew": ["ladder", "halo"], "after": "crew_halo",
		"pitch": "There's a cannery on pier nine that doesn't can anything. Crates of purple crystal go in the front and out the back. I've counted the guards for a week. Halo drives.",
		"reward": {"#gold": 900, "crystal_refined": 4}},
	"arcade": {"name": "The Neon Arcade", "where": "neon", "planner": "dice", "crew": ["dice", "vic"], "after": "crew_vic",
		"pitch": "The arcade under the dragon sign takes the whole district's tokens to a back room every Friday. Vic stands at the door looking big. I open the safe. Nobody gets hurt; that's the deal.",
		"reward": {"#gold": 1400, "data_chip": 3}},
	"vault": {"name": "The Vault", "where": "uptown", "planner": "specs", "crew": ["specs", "sasha"], "after": "crew_sasha",
		"pitch": "The bank uptown has a sub-basement on its own wire, and in it, a crystal the size of a car. I get us past the wire. Sasha gets us past the doors. We take a battery's worth and leave the rest humming.",
		"reward": {"#gold": 2500, "crystal_battery": 2}},
}

## Last loyalty step: what each crew member asks for.
const MISSIONS := {
	"deuce": ["coffee", 5, "One favour before I'd follow you anywhere. The boys need coffee for the night shift. Five cups.", "Five cups. You remembered. That's the whole job, boss: remembering."],
	"mama_rosa": ["#veg", 15, "My cellar is empty and the neighbourhood is hungry. Fifteen vegetables, any kind, and I cook for the whole street.", "Look at them eat. THIS is the business."],
	"specs": ["circuit_board", 3, "Three circuit boards. Don't ask what for. ...Fine: a radio for Ladder. Don't tell him.", "He's going to cry. Don't watch."],
	"ladder": ["lamp_oil", 3, "The rooftop lamps are dry. Three jars of lamp oil and I can see the whole city at night.", "Four hundred and thirteen. I can see it now."],
	"vic": ["potion", 3, "Val got hurt sparring and won't admit it. Three potions. Don't say they're for her.", "She drank one and said it tasted bad. That means thank you."],
	"val": ["copper_bar", 5, "Vic needs new gloves. Five copper bars to the smith and he'll make them.", "He won't take them off. Even to eat."],
	"halo": ["fuel_cell", 2, "Car's thirsty. Two fuel cells and she'll go anywhere you say.", "Hear that? That's the sound of anywhere."],
	"dice": ["data_chip", 2, "Two data chips and I can fix the arcade machines so they pay out prizes again. Tokens, not cash. For the kids.", "Every kid on the avenue just won something."],
	"the_kid": ["berry_pie", 1, "...", "...Thanks. (He eats the whole pie standing up, and smiles for the first time you've seen.)"],
	"doc": ["#herb", 10, "Ten wild herbs. The clinic's running out of the basics.", "Ten. That's ten people patched up. Try not to be one of them."],
	"marlene": ["sapphire", 1, "A sapphire. Not to sell. Mine was my mother's, and I sold it once, and I'd like to stop thinking about that.", "...It's not the same one. It doesn't need to be."],
	"sasha": ["map_scrap", 2, "Two map scraps. The tower has doors nobody's drawn. I want to draw them.", "There. Now nobody gets lost in there. Including us."],
}


static func on() -> bool:
	return not GameState.run.is_empty() and str(GameState.run.get("arc", "")) == "gangsters"


# ---- turf --------------------------------------------------------------------

static func turf() -> Dictionary:
	if not GameState.run.has("turf"):
		GameState.run["turf"] = {}
	return GameState.run["turf"]


static func holds(scene: String) -> bool:
	return turf().has(scene)


## After a kill: the last hostile on a district block hands you the block.
static func on_kill(m: GameMap) -> void:
	if not on() or not TURF.has(m.scene_id()) or holds(m.scene_id()):
		return
	for e in m.enemies:
		if is_instance_valid(e) and e._alive:
			return
	turf()[m.scene_id()] = int(GameState.run["day"])
	GameState.add_arc_xp(40)
	m.hud.toast("This block is yours: %s. ◆%d every morning, and collectors stay away." % [str(TURF[m.scene_id()]), TURF_PAY], Color(1, 0.9, 0.5))
	m.fx("sparkle", m.player.position + Vector2(0, -18), 16.0, 0.6)
	Music.instance(m.get_tree()).sfx("levelup")


static func morning() -> int:
	if not on():
		return 0
	var pay := TURF_PAY * turf().size()
	GameState.run["crystals"] = int(GameState.run["crystals"]) + pay
	return pay


# ---- heists ------------------------------------------------------------------

static func heist_ready(id: String) -> bool:
	var h: Dictionary = HEISTS[id]
	if GameState.run["flags"].has("heist_" + id):
		return false
	if not GameState.run["flags"].has(str(h["after"])):
		return false
	for c in h["crew"]:
		if not Crew.recruited(str(c)):
			return false
	return int(GameState.run["flags"].get("heist_try_" + id, -1)) != int(GameState.run["day"])


## The planner offers the job when you talk to them at the hideout. True if handled.
static func talk(m: GameMap, crew_id: String) -> bool:
	if not on() or m.scene_id() != "hideout":
		return false
	for id: String in HEISTS:
		var h: Dictionary = HEISTS[id]
		if str(h["planner"]) == crew_id and heist_ready(id):
			await _run_heist(m, id)
			return true
	return await _mission(m, crew_id)


static func _run_heist(m: GameMap, id: String) -> void:
	var h: Dictionary = HEISTS[id]
	var who := str(Crew.members()[str(h["planner"])]["name"])
	var d := Dialogue.instance(m.get_tree())
	d.say([{"who": who, "text": str(h["pitch"])}, {"who": who, "text": "%s. How do we play it?" % str(h["name"]), "choice": ["Quiet. In and out, nobody sees us.", "Fast. Hit it and run.", "Not tonight."], "key": ""}])
	await d.finished
	var c := d.last_choice
	if c < 0 or c > 1:
		return
	GameState.run["flags"]["heist_try_" + id] = int(GameState.run["day"])
	# Odds: the plan, the crew's loyalty, and how hot you are.
	var odds := 0.55 if c == 0 else 0.45
	for cm in h["crew"]:
		odds += 0.08 * Crew.loyalty(str(cm))
	odds -= 0.06 * Racket.heat()
	if c == 1:
		odds += 0.1 * minf(1.0, float(GameState.skill_level("combat")) / 8.0)
	odds = clampf(odds, 0.2, 0.95)
	GameState.run["time"] = int(GameState.run["time"]) + 120
	if randf() < odds:
		GameState.run["flags"]["heist_" + id] = true
		GameState.add_arc_xp(60)
		Perks._give(h["reward"])
		await m.say([{"who": "", "text": "It goes like a song you've all rehearsed. Nobody hurt, nobody seen, and the van is heavier on the way home."}, {"who": who, "text": "...We did it. We actually did it."}])
		m.hud.toast("%s done: %s" % [str(h["name"]), Perks._list(h["reward"])], Color(1, 0.9, 0.4))
		Music.instance(m.get_tree()).sfx("levelup")
		if c == 1:
			Racket.set_heat(Racket.heat() + 1)
	else:
		Racket.set_heat(Racket.heat() + 1)
		await m.say([{"who": "", "text": "A guard changes his route. A dog barks. You're out the back with empty hands and a siren somewhere behind you."}, {"who": who, "text": "Nobody's hurt. That's what matters. We go again another night."}])
		m.hud.toast("The heist went wrong. Heat +1. Try again another day.", Color(1, 0.6, 0.5))


# ---- loyalty missions --------------------------------------------------------

## A crew member at loyalty 2 asks a favour; the favour unlocks their last step.
static func mission_open(id: String) -> bool:
	return on() and MISSIONS.has(id) and Crew.recruited(id) and Crew.loyalty(id) == 2 and not GameState.run["flags"].has("mission_" + id)


static func _mission(m: GameMap, id: String) -> bool:
	if not mission_open(id):
		return false
	var ms: Array = MISSIONS[id]
	var nm := str(Crew.members()[id]["name"])
	var item := str(ms[0])
	var n := int(ms[1])
	if GameState.count_any(item) >= n:
		GameState.take_any(item, n)
		GameState.run["flags"]["mission_" + id] = true
		await m.say([{"who": nm, "text": str(ms[3])}])
		m.hud.toast("%s's favour done. Their last loyalty step is open." % nm, Color(1, 0.85, 0.7))
		return true
	if not GameState.run["flags"].has("mission_asked_" + id):
		GameState.run["flags"]["mission_asked_" + id] = true
		await m.say([{"who": nm, "text": str(ms[2])}])
		GameState.add_hint("%s wants %d %s." % [nm, n, GameState.need_name(item)])
		return true
	return false
