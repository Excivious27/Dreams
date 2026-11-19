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


static var _thing_cache := {}


static func _scene() -> String:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null:
		return ""
	var m: GameMap = ml.current_scene as GameMap
	return m.scene_id() if m != null else ""


## The main quest the goal line should NOT show yet, because an earlier step
## still stands in front of it (the gangster docks wait for Sal and a first recruit).
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
				return "Show Sal in town the note from the meadow. Then the outskirts gate, east past the meadow."
			return "Hideout town: the gate at the far east of the outskirts (east past the meadow)."
		"gang":
			if not r["flags"].has("hideout_seen"):
				return "Recruit your first crew in Hideout town: the outskirts gate, east past the meadow."
			return "Recruit your first crew: Deuce at his table or Mama Rosa at the kitchen door. Each wants a favour."
		"docks":
			if not r["flags"].has("sal_recruited"):
				return "Show Sal in town the note from the meadow."
	return ""


## A ripe first crop comes before anything else (one tap, and it's the tutorial).
static func ripe_first() -> String:
	if not GameState.has_quest("first_harvest") or GameState.quest_done("first_harvest"):
		return ""
	for t: Variant in (GameState.run.get("farm", {}) as Dictionary).values():
		if t is Dictionary and str(t.get("crop", "")) != "" and int(t.get("days", 0)) >= int(GameState.crops.get(str(t["crop"]), {}).get("days", 99)):
			return "Your crop is ripe: face it and tap USE to harvest." if _scene() == "farm" else "Your crop is ripe: go home to the farm and harvest it."
	return ""


## Where the current goal is: [scene, what to point at there] ("" = no arrow).
static func goal_place() -> Array:
	var r := GameState.run
	if r.is_empty() or str(r.get("pinned_quest", "")) != "":
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
			return ["meadow", ""]
		"cattopia":
			return ["crystal_meadow", "npc:catkins"]
		"spark":
			if not Builds.is_built("resonator"):
				return ["farm", "thing:plans"] if GameState.count("stone") >= 10 and GameState.count("shard") >= 1 else ["", ""]
			return ["farm", "build:resonator"] if GameState.count("shard") >= 3 else ["", ""]
		"hideout", "gang", "docks":
			if not r["flags"].has("sal_recruited"):
				return ["town", "npc:sal"]
			if not r["flags"].has("hideout_seen"):
				return ["crystal_meadow", "thing:gate"]
	return ["", ""]


## The HUD arrow's target on map m (Vector2.ZERO = none).
static func target(m: GameMap) -> Vector2:
	var gp := goal_place()
	var goal := str(gp[0])
	var here := m.scene_id()
	if goal == "" or not ADJ.has(here):
		return Vector2.ZERO
	if here == goal:
		var what := str(gp[1])
		if what.begins_with("npc:"):
			for ch in m.get_children():
				if ch is Npc and (ch as Npc).id == what.substr(4):
					return (ch as Node2D).position
		elif what.begins_with("thing:"):
			# Things don't move: look once per map and kind.
			var key := "%d:%s" % [m.get_instance_id(), what]
			if not _thing_cache.has(key):
				var spots: Array = []
				for c: Vector2i in m.things:
					if str((m.things[c] as Dictionary).get("type", "")) == what.substr(6):
						spots.append(m.cell_center(c))
				_thing_cache = {key: spots}
			var best := Vector2.ZERO
			for p: Vector2 in _thing_cache[key]:
				if best == Vector2.ZERO or p.distance_to(m.player.position) < best.distance_to(m.player.position):
					best = p
			return best
		elif what.begins_with("build:"):
			var cell: Array = Builds.data().get(what.substr(6), {}).get("cell", [])
			if cell.size() >= 2:
				return m.cell_center(Vector2i(int(cell[0]), int(cell[1])))
		return Vector2.ZERO
	var hop := next_hop(here, goal)
	if hop == "":
		return Vector2.ZERO
	var best_e := Vector2.ZERO
	for e: Dictionary in m.exits:
		if str(e.get("scene", "")) != hop:
			continue
		var rc: Rect2i = e["rect"]
		var p := (Vector2(rc.position) + Vector2(rc.size) * 0.5) * GameMap.TILE
		if best_e == Vector2.ZERO or p.distance_to(m.player.position) < best_e.distance_to(m.player.position):
			best_e = p
	return best_e


## The first scene on the shortest walk from `from` to `to` ("" if none).
static func next_hop(from: String, to: String) -> String:
	if from == to or not ADJ.has(from):
		return ""
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		for n: String in ADJ.get(s, []):
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
