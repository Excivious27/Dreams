class_name GoalLine
## The goal line's early-story wording and the HUD arrow that points at it.
## GameState.next_step picks the quest; this turns a long quest text into the
## one step that's next (so the HUD's two lines never cut the how-to off), and
## says where the goal is. `target(m)` gives the green HUD arrow a spot on the
## current map: the person or thing to reach, or the exit that leads there.

## How the outdoor scenes join (the way a player walks; doors and gates aside).
const ADJ := {
	"farm": ["town", "meadow", "forest", "lake"],
	"town": ["farm", "beach", "mountain", "community_farm"],
	"meadow": ["farm", "crystal_meadow"],
	"crystal_meadow": ["meadow"],
	"forest": ["farm", "lake"],
	"lake": ["farm", "forest"],
	"beach": ["town"],
	"mountain": ["town"],
	"community_farm": ["town"],
	"hideout": ["crystal_meadow"],
}


## Ways between scenes that are things, not exits (a gate, a tree stair, a pad, a manhole):
## scene -> {neighbour: thing type}. Arc-only links carry the arc after a colon.
const VIA := {
	"crystal_meadow": {"wastes:penguins": "gate", "hideout:gangsters": "gate"},
	"forest": {"sky:penguins": "great_tree"},
	"mountain": {"moon:penguins": "pad"},
	"neon": {"underground": "door"},
	"sky": {"forest": "door"},
	"underground": {"neon": "door"},
	"moon": {"mountain": "pad"},
	"meadow": {"hollow_heart": "mine"},  # C9: the Hollow Heart is reached down the mine (floor 150)
}


static var _thing_cache := {}
static var _mega_adj := {}
static var _graph_arc := ""


## Neighbours of a scene: ADJ for the Valley, every regions.json area's own exits
## (both ways, so the Valley's outer regions and mega areas join by themselves), and
## the thing-ways in VIA (C7: the compass reaches orchard_hills, quarry, marsh, wastes, sky...).
static func adj(s: String) -> Array:
	var arc := "penguins" if GameState.run.is_empty() or GameState.is_penguins() else "gangsters"
	if _mega_adj.is_empty() or _graph_arc != arc:
		_mega_adj = {}
		_graph_arc = arc
		var link := func(a: String, b: String) -> void:
			if a == "" or b == "" or a == b:
				return
			for pr: Array in [[a, b], [b, a]]:
				if not _mega_adj.has(pr[0]):
					_mega_adj[pr[0]] = []
				if not (_mega_adj[pr[0]] as Array).has(pr[1]):
					(_mega_adj[pr[0]] as Array).append(pr[1])
		for k: String in ADJ:
			for n: String in ADJ[k]:
				link.call(k, n)
		var regs: Dictionary = GameState.load_json("res://data/regions.json")
		for k: String in regs:
			var r: Variant = regs[k]
			if not (r is Dictionary):
				continue
			for e in (r as Dictionary).get("exits", []):
				var sc := str(e.get("scene", "")) if e is Dictionary else ""
				link.call(k, sc)
		for k: String in VIA:
			for key: String in VIA[k]:
				var parts := key.split(":")
				if parts.size() > 1 and parts[1] != arc:
					continue
				link.call(k, parts[0])
		# The outskirts gate leads to one place per arc.
		if arc == "penguins":
			for pr: Array in [["crystal_meadow", "hideout"], ["hideout", "crystal_meadow"]]:
				if _mega_adj.has(pr[0]):
					(_mega_adj[pr[0]] as Array).erase(pr[1])
		else:
			for pr: Array in [["crystal_meadow", "wastes"], ["wastes", "crystal_meadow"]]:
				if _mega_adj.has(pr[0]):
					(_mega_adj[pr[0]] as Array).erase(pr[1])
		_mega_adj["_"] = []
	return _mega_adj.get(s, [])


## The thing on scene `from` that leads to `to` ("" = it's an ordinary exit or nothing).
static func via_thing(from: String, to: String) -> String:
	for key: String in VIA.get(from, {}):
		if key.split(":")[0] == to:
			return str(VIA[from][key])
	return ""


static func _scene() -> String:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null:
		return ""
	var m: GameMap = ml.current_scene as GameMap
	return m.scene_id() if m != null else ""


## The main quest the goal line should NOT show yet, because an earlier step
## still stands in front of it (the gangster docks wait for a first recruit).
static func defer(qid: String) -> bool:
	if qid == "docks" and not GameState.is_penguins():
		return GameState.has_quest("gang") and not GameState.quest_done("gang")
	return false


## The goal line text for main quest `qid` ("" = use the quest text).
static func text(qid: String) -> String:
	var r := GameState.run
	var pen := GameState.is_penguins()
	match qid:
		"clear_meadow":
			if _scene() == "meadow":
				var left := 5 - int(r.get("meadow_kills", 0))
				if left > 0:
					return ("Beat %d more Grumps here: something bigger is behind them." if pen else "Drop %d more lookouts here: whoever sent them will show.") % left
				return "Beat the Big Grump!" if pen else "Beat the President's Man!"
			if letter_first():
				return "A letter waits in your mailbox, by the house. Read it."
			return "Find out what's howling in the east meadow (the farm's east gate)." if pen else "Someone is asking about you. Check the east meadow (the farm's east gate)."
		"cattopia":
			if _scene() == "crystal_meadow":
				return "Talk to Catkins, the cat by the statue in the crystal meadow."
			return "Find the purring: the crystal meadow, east through the meadow. Talk to Catkins."
		"spark":
			if not Builds.is_built("resonator"):
				var need: Array = []
				if GameState.count("stone") < 10:
					need.append("%d more stone" % (10 - GameState.count("stone")))
				if GameState.count("shard") < 1:
					need.append("a crystal shard")
				if need.is_empty():
					return "Build the Crystal Resonator: Plans board by your house (10 stone, 1 shard)."
				return "Crystal Resonator (Plans board by your house) needs %s." % " and ".join(need)
			if GameState.count("shard") < 3:
				return "Find %d more crystal shard%s (mountain rocks, the beach wreck, the mine), then refine 3 at the Resonator." % [3 - GameState.count("shard"), "" if 3 - GameState.count("shard") == 1 else "s"]
			return "Refine a crystal: hold 3 Crystal Shards, USE on the Resonator by your house."
		"hideout":
			if not r["flags"].has("sal_recruited"):
				return "Tell Sal in town about the President's man. Then the outskirts gate, east past the meadow."
			return "Hideout town: the outskirts gate, east past the meadow. Find a place to work from."
		"gang":
			if not r["flags"].has("hideout_seen"):
				return "Recruit your first crew in Hideout town: the outskirts gate, east past the meadow."
			return "Recruit your first crew: Deuce at his table or Mama Rosa at the kitchen door. Each wants a favour."
	return late_text(qid)


## Where-to-go words for later main steps once their region is open (C7). "" while a
## campaign still holds it (GameState.next_step then shows the campaign pointer).
static func late_text(qid: String) -> String:
	if not ["knight", "docks", "neon", "pit", "uptown", "tower"].has(qid) or Campaign.story_pointer(qid) != "":
		return ""
	var here := _scene()
	match qid:
		"knight":
			return "Face the Crystal Knight on the sky islands." if here == "sky" else "Climb the great tree in the forest to the sky islands. Face the Crystal Knight."
		"docks":
			return "Find the dock boss on the docks and take them." if here == "docks" else "Take the city bus from Hideout town (east side) to the docks. Beat the dock boss."
		"neon":
			return "Find Flame under the dragon sign. Put the fire out." if here == "neon" else "East from the docks to the neon district. Put out Flame."
		"pit":
			return "Win the fight pit." if here == "underground" else "The unmarked stairs off the neon street lead down to the fight pit. Win it."
		"uptown":
			return "Beat the Enforcer outside the President's tower." if here == "uptown" else "East from neon to Uptown. Beat the President's Enforcer (Combat 5 helps)."
		"tower":
			if not GameState.run["flags"].has("boss_uptown"):
				return "East from neon to Uptown. Beat the Enforcer outside the tower."
			return "Open the tower's brass doors: the letter, a key, or your crew's shoulders." if not GameState.run["flags"].has("tower_open") else "The President is coming out onto the red carpet outside his tower. Meet him there."  # C12 c12_04-06
	return ""


## The meadow step opens on day 3 with a story letter (Mail.story_due mail_2):
## until it's read, the goal is the mailbox, not a quest the player hasn't been told.
static func letter_first() -> bool:
	var r := GameState.run
	if r.is_empty() or r["flags"].has("mail_2") or r["flags"].has("meadow_seen") or int(r.get("meadow_kills", 0)) > 0 or _scene() == "meadow":
		return false
	for sl: Dictionary in Mail.story_due():
		if str(sl.get("flag", "")) == "mail_2":
			return true
	return false


## A ripe first crop comes before anything else (one tap, and it's the tutorial).
static func ripe_first() -> String:
	if not GameState.has_quest("first_harvest") or GameState.quest_done("first_harvest"):
		return ""
	for t: Variant in (GameState.run.get("farm", {}) as Dictionary).values():
		if t is Dictionary and str(t.get("crop", "")) != "" and int(t.get("days", 0)) >= int(GameState.crops.get(str(t["crop"]), {}).get("days", 99)):
			return "Your crop is ripe: face it and tap USE to harvest." if _scene() == "farm" else "Your crop is ripe: go home to the farm and harvest it."
	return ""


## Where the current goal is: [scene, what to point at there] ("" = no arrow).
static func goal_place(ignore_pin := false) -> Array:
	var r := GameState.run
	if r.is_empty() or (not ignore_pin and str(r.get("pinned_quest", "")) != "" and not QuestTracker.is_main(str(r.get("pinned_quest", "")))):
		return ["", ""]
	if ripe_first() != "":
		return ["farm", ""]
	var mains := {}
	for mq in GameState.quests_data.get("main", []):
		mains[str(mq.get("id", ""))] = true
	var qs: Array = r.get("quests", [])
	var qid := ""
	for i in range(qs.size() - 1, -1, -1):
		var q: Dictionary = qs[i]
		if not bool(q.get("done", false)) and mains.has(str(q.get("id", ""))) and not defer(str(q.get("id", ""))):
			qid = str(q["id"])
			break
	match qid:
		"first_harvest":
			return ["farm", ""]
		"meet_town":
			return ["town", ""]
		"clear_meadow":
			return ["farm", "thing:mailbox"] if letter_first() else ["meadow", ""]
		"cattopia":
			return ["crystal_meadow", "npc:catkins"]
		"spark":
			if not Builds.is_built("resonator"):
				return ["farm", "thing:plans"] if GameState.count("stone") >= 10 and GameState.count("shard") >= 1 else ["mountain", ""]  # C7: rocks and shards
			return ["farm", "build:resonator"] if GameState.count("shard") >= 3 else ["mountain", ""]
		"hideout", "gang":
			if r["flags"].has("hideout_seen"):
				# C7: in Hideout town the crew comes next (Deuce's card table); "hideout" itself is done there.
				return ["hideout", "npc:deuce"] if qid == "gang" else ["", ""]
			if not r["flags"].has("sal_recruited"):
				return ["town", "npc:sal"]  # Sal first (optional, but the story asks for it)
			return ["crystal_meadow", "thing:gate"]
	return story_place(qid)


## Mid and late main steps (C7): the region (its exits/gates lead there) and its boss.
## A region still held by a campaign gets no arrow: the goal line points at the board.
static func story_place(qid: String) -> Array:
	var f: Dictionary = GameState.run.get("flags", {})
	if qid == "sky_stair":
		if not f.has("babies_done"):
			return ["mountain", "cell:27,14"]  # the crystal babies on the pass (p3_babies)
		if not f.has("campfire_done"):
			return ["", ""]  # a night's sleep after the mountain (p3_campfire)
	if Campaign.story_pointer(qid) != "":
		return ["", ""]
	match qid:
		"wastes_gate", "commander":
			return ["wastes", "thing:boss"]
		"sky_stair":
			return ["forest", "thing:great_tree"]
		"knight":
			return ["sky", "thing:boss"]
		"teleporter":
			return ["moon", "thing:tele"]
		"finale":
			return ["moon", "thing:spire"]
		"docks":
			return ["docks", "thing:boss"]
		"neon":
			return ["neon", "thing:boss"]
		"pit":
			return ["underground", "thing:boss"]
		"uptown":
			return ["uptown", "thing:boss"]
		"tower":
			if not f.has("boss_uptown"):
				return ["uptown", "thing:boss"]
			return ["uptown", "cell:17,12"] if not f.has("tower_open") else ["uptown", "cell:18,11"]  # the tower doors, then inside
	return ["", ""]


## The HUD arrow's target on map m (Vector2.ZERO = none).
## ignore_pin: follow the story even while a side quest is tracked (QuestTracker's
## fallback for a tracked quest with no place of its own).
static func target(m: GameMap, ignore_pin := false) -> Vector2:
	var gp := goal_place(ignore_pin)
	var goal := str(gp[0])
	var here := m.scene_id()
	if goal == "":
		return Vector2.ZERO
	if adj(here).is_empty() or (here != goal and next_hop(here, goal) == ""):
		# C9: the mega regions are their own islands: walk to the hub, its ride goes home.
		return QuestTracker._toward(m, goal) if MegaTravel.region_of(here) != "" else Vector2.ZERO
	if here == goal:
		var what := str(gp[1])
		if what.begins_with("npc:"):
			for ch in m.get_children():
				if ch is Npc and (ch as Npc).id == what.substr(4):
					return (ch as Node2D).position
		elif what.begins_with("thing:"):
			return thing_near(m, what.substr(6))
		elif what.begins_with("cell:"):
			var xy := what.substr(5).split(",")
			if xy.size() >= 2:
				return m.cell_center(Vector2i(int(xy[0]), int(xy[1])))
		elif what.begins_with("build:"):
			var cell: Array = Builds.data().get(what.substr(6), {}).get("cell", [])
			if cell.size() >= 2:
				return m.cell_center(Vector2i(int(cell[0]), int(cell[1])))
		return Vector2.ZERO
	return exit_toward(m, goal)


## The nearest thing of `kind` on map m (things don't move: looked up once per map and kind).
static func thing_near(m: GameMap, kind: String) -> Vector2:
	var key := "%d:%s" % [m.get_instance_id(), kind]
	if not _thing_cache.has(key):
		var spots: Array = []
		for c: Vector2i in m.things:
			if str((m.things[c] as Dictionary).get("type", "")) == kind:
				spots.append(m.cell_center(c))
		if _thing_cache.size() > 16:
			_thing_cache = {}
		_thing_cache[key] = spots
	var best := Vector2.ZERO
	for p: Vector2 in _thing_cache[key]:
		if best == Vector2.ZERO or p.distance_to(m.player.position) < best.distance_to(m.player.position):
			best = p
	return best


## The nearest exit on map m that leads toward scene `goal` (Vector2.ZERO = none).
static func exit_toward(m: GameMap, goal: String) -> Vector2:
	var hop := next_hop(m.scene_id(), goal)
	if hop == "":
		return Vector2.ZERO
	var best_e := Vector2.ZERO
	for e: Dictionary in m.exits:
		if str(e.get("scene", "")) != hop:
			continue
		var rc: Rect2i = e["rect"]
		# Exit rects are content cells: cell_pos adds the map's border pad.
		var p := m.cell_pos(rc.position.x + rc.size.x * 0.5, rc.position.y + rc.size.y * 0.5)
		if best_e == Vector2.ZERO or p.distance_to(m.player.position) < best_e.distance_to(m.player.position):
			best_e = p
	if best_e == Vector2.ZERO and via_thing(m.scene_id(), hop) != "":
		return thing_near(m, via_thing(m.scene_id(), hop))  # a gate, the great tree, a pad, a manhole
	return best_e


## The first scene on the shortest walk from `from` to `to` ("" if none).
static func next_hop(from: String, to: String) -> String:
	if from == to or adj(from).is_empty():
		return ""
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		for n: String in adj(s):
			if prev.has(n):
				continue
			prev[n] = s
			if n == to:
				var step := n
				while str(prev[step]) != from:
					step = str(prev[step])
				return step
			queue.append(n)
	return ""
