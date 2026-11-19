class_name CfVolunteers
extends Node
## The community farm's volunteers at work (a child of scripts/community_farm.gd).
##  - Each volunteer gets their own patch of a shared spot (`stand_cell`), so a
##    busy market or picnic never stacks people on one cell; bench sitters sit on the bench.
##  - They walk in along the road from town when their shift starts and walk
##    back out when it ends (`npc_arrive` / `npc_leave`, hooked in Npc._apply_routine).
##  - Visible work: bed volunteers walk to a bed, crouch and tend, water dry cells,
##    pick what's ripe; haulers carry loads to the compost/shed/cart; Benno carries
##    water from the well; market keepers restock from the crates. Rain sends the
##    rest under the shed eaves / into the greenhouse, chatting (Commons.slot).
##  - Barks: short call-outs as you pass. A "!" now and then over someone with a job.
##  - Lend a hand (`offer`): weed round the beds, haul crates, or water the dry beds;
##    once per volunteer a day (Commons.reward_help).

const ENTRANCE := [Vector2i(50, 19), Vector2i(50, 20)]
## Bench seats (cells of the bench prop) by spot: sitters sit on them.
const SEATS := {"cf_bench": [Vector2i(33, 17), Vector2i(34, 17)]}
const CRATE_ART := ["props", "crates_a"]
const WEED_ART := ["nature", "bramble"]

var map: GameMap
var _stand := {}       # Npc -> Vector2i (their own cell of their spot)
var _task := {}        # Npc -> {kind, state, t, cell, target, back}
var _leaving := {}     # Npc -> seconds
var _cool := {}        # Npc -> seconds until the next job
var _bark_cd := {}     # Npc -> seconds until they may call out again
var _bark_any := 0.0
var _greeted := {}     # npc id -> true (greeted today)
var _tick := 0.0
var _bang := 4.0
var _age := 0.0
var _shelter_pose := {}  # Npc -> seconds
## The player's help task: {npc, kind, left, keys/cells, carrying, drop}
var help := {}
var _carry_sprite: Sprite2D


func _npcs() -> Array:
	return map.get("npcs") if map else []


# ---- where people stand ------------------------------------------------------------

func _free(c: Vector2i) -> bool:
	return map.in_content(c) and not map.blocked.has(c) and not map.is_water_cell(c) and not map.things.has(c) and c.x < 49


## Their own cell near `spot`: the spot itself for the first, then the nearest open cells
## at least two apart (one apart when it's packed).
func stand_cell(n: Npc, place: String, spot: Vector2i) -> Vector2i:
	var taken := {}
	for o: Npc in _npcs():
		if o != n and o.visible and not o.hold and _stand.has(o):
			taken[_stand[o]] = true
	if SEATS.has(place):
		for s: Vector2i in SEATS[place]:
			if not taken.has(s):
				_stand[n] = s
				return s
	var cands: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := spot + Vector2i(dx, dy)
			if c == spot or _free(c):
				cands.append(c)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := a.distance_squared_to(spot)
		var db := b.distance_squared_to(spot)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for gap in [2, 1]:
		for c: Vector2i in cands:
			var ok := true
			for t: Vector2i in taken:
				if maxi(absi(t.x - c.x), absi(t.y - c.y)) < gap:
					ok = false
					break
			if ok:
				_stand[n] = c
				return c
	_stand[n] = spot
	return spot


func stand_of(n: Npc) -> Vector2i:
	return _stand.get(n, n.cell())


func _entrance(n: Npc) -> Vector2i:
	return ENTRANCE[absi(hash(n.id)) % ENTRANCE.size()]


## Their shift starts while you're here: they come in along the road.
func npc_arrive(n: Npc) -> Vector2:
	if _age < 1.0 or map.player == null:
		return Vector2.INF
	return map.cell_center(_entrance(n) + Vector2i(1, 0))


## Their shift is over: walk out along the road (only when you could see it).
func npc_leave(n: Npc) -> bool:
	if _age < 1.0 or map.player == null or map.player.position.distance_to(n.position) > 330.0:
		return false
	_end_task(n)
	if n._chat_partner != null:
		n._end_chat()
	n.set_pose("")
	n.hold = true
	var e := _entrance(n)
	n.home = map.cell_center(e)
	n._target = n.home
	n._wander_t = 999.0
	n._path = map.find_path(n.cell(), e)
	_leaving[n] = 0.0
	_stand.erase(n)
	return true


# ---- the loop ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if map == null or map.player == null or map._changing:
		return
	_age += delta
	_bark_any -= delta
	for n: Npc in _leaving.keys():
		if not is_instance_valid(n):
			_leaving.erase(n)
			continue
		_leaving[n] = float(_leaving[n]) + delta
		if n._chat_partner != null:
			n._end_chat()
			n._path = map.find_path(n.cell(), _entrance(n))
		if n.position.distance_to(n.home) < 6.0 or float(_leaving[n]) > 30.0:
			_leaving.erase(n)
			n.visible = false
			n.hold = false
			n._path.clear()
	for n: Npc in _task.keys():
		if not is_instance_valid(n) or not n.visible:
			_task.erase(n)
		else:
			_run_task(n, _task[n], delta)
	for n: Npc in _cool.keys():
		_cool[n] = float(_cool[n]) - delta
	for n: Npc in _bark_cd.keys():
		_bark_cd[n] = float(_bark_cd[n]) - delta
	_help_tick()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_sit_and_shelter()
	_barks()
	_bang -= 0.5
	if _bang <= 0.0:
		_bang = randf_range(7.0, 12.0)
		_show_bang()
	for n: Npc in _npcs():
		if _idle(n) and float(_cool.get(n, 0.0)) <= 0.0:
			_start_task(n)


func _idle(n: Npc) -> bool:
	return n.visible and not n.hold and not _task.has(n) and n._chat_partner == null and n._path.is_empty() and n.position.distance_to(n.home) < 6.0


func sheltering(n: Npc) -> bool:
	return GameState.is_wet() and n._place in Commons.rain_spots() and not Npc.rain_walker(n.id)


## Bench sitters settle onto the bench; sheltering volunteers chat instead of holding umbrellas.
func _sit_and_shelter() -> void:
	for n: Npc in _npcs():
		if not n.visible or n.hold or _task.has(n):
			continue
		if SEATS.has(n._place) and n._path.is_empty() and n.position.distance_to(n.home) < 18.0 and n.position.distance_to(n.home) > 0.5:
			n.position = n.home  # the last step onto the seat (the bench cell itself is solid)
			n._target = n.home
			n._wander_t = 999.0
			n.set_pose("sit")
		if sheltering(n) and n._path.is_empty() and n._chat_partner == null:
			_shelter_pose[n] = float(_shelter_pose.get(n, 0.0)) - 0.5
			if float(_shelter_pose[n]) <= 0.0:
				_shelter_pose[n] = randf_range(4.0, 8.0)
				n._wander_t = 999.0
				n.set_pose("")
				n.set_pose(["talk", "talk_2", "laugh", "work", "shiver"][randi() % 5])


# ---- work ---------------------------------------------------------------------------

func task_of(n: Npc) -> String:
	if _leaving.has(n):
		return "leaving"
	if not _task.has(n):
		return ""
	return "%s/%s" % [str(_task[n]["kind"]), str(_task[n]["state"])]


func _start_task(n: Npc) -> void:
	if sheltering(n) or SEATS.has(n._place):
		return
	var job := {}
	match n.activity:
		"farm":
			job = _farm_job(n)
		"haul":
			job = _haul_job(n)
		"work":
			if randf() < 0.5:
				job = _haul_job(n)
			else:
				_cool[n] = randf_range(5.0, 10.0)
				return
		"market":
			if randf() < 0.25 and Commons.stage() >= 8:
				job = {"kind": "restock", "target": Vector2i(39, 29), "back": stand_of(n)}
	if job.is_empty():
		_cool[n] = randf_range(6.0, 12.0)
		return
	job["state"] = "go"
	job["t"] = 0.0
	job["place"] = n._place
	if not job.has("cell"):
		job["cell"] = _beside(job["target"])
	_task[n] = job
	_go(n, job["cell"])


## A free cell beside `c` to work from (c itself when it's walkable and not a bed).
func _beside(c: Vector2i) -> Vector2i:
	if _free(c):
		return c
	var best := c
	var bd := 99
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		var k := c + d
		if _free(k) and d.length_squared() < bd:
			bd = d.length_squared()
			best = k
	return best


func _go(n: Npc, c: Vector2i) -> void:
	n.set_pose("")
	n._wander_t = 999.0
	n.home = map.cell_center(c)
	n._target = n.home
	n._path = map.find_path(n.cell(), c)


## Bed volunteers: pick what's ripe first, water what's dry, else tend a cell; the
## orchard's volunteers tend the trees.
func _farm_job(n: Npc) -> Dictionary:
	var cells: Dictionary = map.get("_cells")
	var me := stand_of(n)
	var best := ""
	var score := -1.0
	var wet := GameState.sky_waters() or Commons.stage() >= 5
	for key: String in cells:
		var p := key.split(",")
		var c := Vector2i(int(p[0]), int(p[1]))
		var d := Vector2(c).distance_to(Vector2(me))
		if d > 7.0 or _claimed(key):
			continue
		var pl := Commons.plot(key)
		var sc := randf()
		if Commons.ripe(pl):
			sc += 3.0
		elif str(pl.get("crop", "")) != "" and not wet and not bool(pl.get("w", false)):
			sc += 2.0
		elif str(pl.get("crop", "")) == "":
			sc -= 0.5
		sc -= d * 0.08
		if sc > score:
			score = sc
			best = key
	if best != "":
		var p2 := best.split(",")
		var pl2 := Commons.plot(best)
		var kind := "tend"
		if Commons.ripe(pl2):
			kind = "pick"
		elif str(pl2.get("crop", "")) != "" and not wet and not bool(pl2.get("w", false)):
			kind = "water"
		return {"kind": kind, "key": best, "target": Vector2i(int(p2[0]), int(p2[1])), "back": me}
	# The orchard (or the lot before the beds): tend the nearest tree / patch.
	var trees: Array = []
	for o: Array in Commons.data().get("orchard", []):
		var oc := Vector2i(int(o[0]), int(o[1]))
		if Vector2(oc).distance_to(Vector2(me)) < 9.0:
			trees.append(oc)
	if not trees.is_empty() and Commons.stage() >= 6:
		var t: Vector2i = trees[randi() % trees.size()]
		return {"kind": "tree", "target": t, "cell": _beside(t + Vector2i(0, 1)), "back": me}
	return _haul_job(n)


func _claimed(key: String) -> bool:
	for o: Npc in _task:
		if str(_task[o].get("key", "")) == key:
			return true
	return false


## Haulers: pick up near their spot, carry to a drop point, come back.
func _haul_job(n: Npc) -> Dictionary:
	var me := stand_of(n)
	var s := Commons.stage()
	var pick := me + Vector2i(randi_range(-3, 3), randi_range(-2, 2))
	var drop := Vector2i(30, 9) if s < 2 else Vector2i(23, 10)  # the timber pile by the ruin / the compost
	if n._place == "cf_well":
		pick = Vector2i(29, 20)  # a bucket at the well, poured on the nearest bed
		drop = Vector2i(17, 22) if s >= 3 else Vector2i(16, 18)
		return {"kind": "water_run", "target": pick, "drop": drop, "back": me}
	if n._place in ["cf_shed"]:
		drop = Vector2i(21, 10)  # the cart by the shed
		pick = me + Vector2i(randi_range(-2, 2), 1)
	if s == 0:
		# Stage 0: drag at the junk you haven't cleared yet.
		var junk: Array = []
		for c: Vector2i in map.things:
			if str(map.things[c].get("type", "")) == "cf_debris" and Vector2(c).distance_to(Vector2(me)) < 10.0:
				junk.append(c)
		if not junk.is_empty():
			return {"kind": "junk", "target": junk[randi() % junk.size()], "back": me}
	return {"kind": "haul", "target": pick, "drop": drop, "back": me}


func _arrived(n: Npc, job: Dictionary) -> bool:
	return (n._path.is_empty() and n.position.distance_to(n.home) < 4.0) or float(job["t"]) > 12.0


func _run_task(n: Npc, job: Dictionary, delta: float) -> void:
	job["t"] = float(job["t"]) + delta
	if n._place != str(job.get("place", n._place)) or n.hold:
		_task.erase(n)  # their shift moved them on (the routine already sent them there)
		return
	if n._chat_partner != null:
		return  # a chat on the way: the job waits (and times out if it's long)
	match str(job["state"]):
		"go":
			if _arrived(n, job):
				job["state"] = "do"
				job["t"] = 0.0
				job["dur"] = randf_range(2.5, 5.0)
				n.face(map.cell_center(job["target"]))
				_begin(n, job)
		"do":
			if float(job["t"]) >= float(job["dur"]):
				_finish(n, job)
		"carry":
			if _arrived(n, job):
				job["state"] = "drop"
				job["t"] = 0.0
				n.face(map.cell_center(job["drop"]))
				n.set_pose("work_2")
				_fx(job["drop"], "splash" if str(job["kind"]) == "water_run" else "dust_puff")
				if str(job["kind"]) == "water_run":
					_water_near(job["drop"])
		"drop":
			if float(job["t"]) > 1.6:
				_back(n, job)
		"back":
			if _arrived(n, job):
				_task.erase(n)
				n.set_pose("")
				n._wander_t = randf_range(3.0, 6.0)
				_cool[n] = randf_range(2.0, 6.0)


func _begin(n: Npc, job: Dictionary) -> void:
	match str(job["kind"]):
		"pick", "tend", "tree", "junk":
			n.set_pose(["work", "work_2"][randi() % 2])
		"water":
			n.set_pose("work")
		"haul", "restock", "water_run":
			n.set_pose("carry" if str(job["kind"]) != "water_run" else "work")
			job["dur"] = 1.4


func _finish(n: Npc, job: Dictionary) -> void:
	var kind := str(job["kind"])
	match kind:
		"pick":
			var key := str(job["key"])
			if Commons.ripe(Commons.plot(key)):
				Commons.harvest(key)
				n.set_pose("carry")
				map.emote(n, "laugh", 1.0, -34.0)
				if map.player.position.distance_to(n.position) < 140.0:
					Music.instance(map.get_tree()).sfx("harvest", "pickup")
				_redraw()
		"water":
			var p := Commons.plot(str(job["key"]))
			if not p.is_empty():
				p["w"] = true
			_fx(job["target"], "splash")
			_redraw()
		"tend", "tree", "junk":
			_fx(job["target"], "leaf_green" if kind != "junk" else "dust_puff")
		"haul", "restock", "water_run":
			job["state"] = "carry"
			job["t"] = 0.0
			_go(n, _beside(job["drop"]) if kind != "restock" else job["back"])
			if kind == "restock":
				job["drop"] = job["back"]
			return
	_back(n, job)


func _back(n: Npc, job: Dictionary) -> void:
	job["state"] = "back"
	job["t"] = 0.0
	# A short pause on the spot, then home to their own cell.
	var t := map.get_tree().create_timer(0.8)
	t.timeout.connect(func() -> void:
		if is_instance_valid(n) and _task.get(n, {}) == job:
			_go(n, job["back"]))


func _end_task(n: Npc) -> void:
	_task.erase(n)


func _water_near(c: Vector2i) -> void:
	var cells: Dictionary = map.get("_cells")
	for key: String in cells:
		var p := key.split(",")
		if Vector2(int(p[0]), int(p[1])).distance_to(Vector2(c)) < 2.5:
			var pl := Commons.plot(key)
			if not pl.is_empty():
				pl["w"] = true
	_redraw()


func _fx(c: Vector2i, name: String) -> void:
	if map.player.position.distance_to(map.cell_center(c)) < 220.0:
		map.fx(name, map.cell_center(c) + Vector2(0, -4), 12.0, 0.4)


func _redraw() -> void:
	var p: Node2D = map.get("_plots")
	if p:
		p.queue_redraw()


# ---- barks and the "!" ------------------------------------------------------------------

func _barks() -> void:
	if _bark_any > 0.0 or Dialogue.instance(map.get_tree()).active:
		return
	for n: Npc in _npcs():
		if not n.visible or n.hold or n._chat_partner != null or float(_bark_cd.get(n, 0.0)) > 0.0:
			continue
		if n.position.distance_to(map.player.position) > 44.0:
			continue
		var first: bool = not _greeted.has(n.id) and not (GameState.run["talked_today"] as Dictionary).has(n.id)
		_greeted[n.id] = true
		var line := Commons.bark(n.activity if not sheltering(n) else "rain", first)
		if line == "":
			continue
		say_over(n, line)
		_bark_cd[n] = randf_range(35.0, 60.0)
		_bark_any = 5.0
		return


## A short line floating up over a volunteer.
func say_over(n: Npc, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(1, 0.98, 0.88))
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(90, 10)
	l.position = Vector2(-45, -46)
	l.z_index = 40
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	n.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", -54.0, 2.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.8)
	tw.tween_callback(l.queue_free)


func can_help(n: Npc) -> bool:
	return help.is_empty() and Commons.stage() >= 1 and not _leaving.has(n) and not sheltering(n) and Commons.help_kind(n.activity) != "" and not Commons.helped_today(n.id) and not Net.visiting() and _help_plan(n).size() > 0


func _show_bang() -> void:
	if not help.is_empty() or Dialogue.instance(map.get_tree()).active:
		return
	for n: Npc in _npcs():
		if n.visible and n.position.distance_to(map.player.position) < 150.0 and can_help(n):
			map.emote(n, "idea", 1.6, -38.0)
			return


# ---- lending a hand ---------------------------------------------------------------------

## Where a help task would happen: weeds (cells round the nearest beds), crates (cells by the
## volunteer), or the dry bed keys to water. Empty = nothing to do right now.
func _help_plan(n: Npc) -> Array:
	var kind := Commons.help_kind(n.activity)
	var me := stand_of(n)
	var out: Array = []
	match kind:
		"weed":
			var cands: Array = []
			var cells: Dictionary = map.get("_cells")
			for key: String in cells:
				var p := key.split(",")
				var c := Vector2i(int(p[0]), int(p[1]))
				if Vector2(c).distance_to(Vector2(me)) > 9.0:
					continue
				for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
					var k := c + d
					if _free(k) and not cells.has(k) and not k in cands and not _stand.values().has(k):
						cands.append(k)
			if cands.is_empty():
				for dy in range(-4, 5):
					for dx in range(-4, 5):
						var k := me + Vector2i(dx, dy)
						if absi(dx) + absi(dy) >= 2 and _free(k) and not _stand.values().has(k):
							cands.append(k)
			cands.shuffle()
			var nn := int(Commons.help_def("weed").get("n", 4))
			for c: Vector2i in cands:
				var spaced := true
				for o: Vector2i in out:
					if maxi(absi(o.x - c.x), absi(o.y - c.y)) < 2:
						spaced = false
				if spaced:
					out.append(c)
				if out.size() >= nn:
					break
		"haul":
			for dy in range(-2, 3):
				for dx in range(-3, 4):
					var k := me + Vector2i(dx, dy)
					if absi(dx) + absi(dy) >= 2 and _free(k) and not _stand.values().has(k) and out.size() < int(Commons.help_def("haul").get("n", 3)):
						var spaced := true
						for o: Vector2i in out:
							if o.distance_to(k) < 1.5:
								spaced = false
						if spaced:
							out.append(k)
		"water":
			var cells2: Dictionary = map.get("_cells")
			var keys: Array = []
			for key: String in cells2:
				var pl := Commons.plot(key)
				var p2 := key.split(",")
				if str(pl.get("crop", "")) != "" and not bool(pl.get("w", false)) and Vector2(int(p2[0]), int(p2[1])).distance_to(Vector2(me)) < 7.0:
					keys.append(key)
			keys.sort_custom(func(a: String, b: String) -> bool:
				var pa := a.split(",")
				var pb := b.split(",")
				return Vector2(int(pa[0]), int(pa[1])).distance_to(Vector2(me)) < Vector2(int(pb[0]), int(pb[1])).distance_to(Vector2(me)))
			out = keys.slice(0, 6)
	return out


## Where hauled crates go, by who asked: [thing type, name for the text].
func _drop_for(n: Npc) -> Array:
	if n.activity == "market" and Commons.stage() >= 8:
		return ["cf_stand", "market stall"]
	if Commons.stage() >= 2:
		return ["cf_compost", "compost"] if n._place == "cf_compost" else ["cf_shed", "tool shed"]
	return ["cf_shed", "old shed"]


## Talk hook (community_farm._talk): ask whether you'll help. True if a task started.
func offer(n: Npc) -> bool:
	if not can_help(n):
		return false
	var kind := Commons.help_kind(n.activity)
	var def := Commons.help_def(kind)
	var name := str(GameState.npcs.get(n.id, {}).get("name", n.id))
	var ask := str(Commons.tx(def.get("ask", "")))
	var drop := _drop_for(n)
	if "%s" in ask:
		ask = ask % str(drop[1])
	var d := Dialogue.instance(map.get_tree())
	d.say([{"who": name, "text": ask, "choice": ["Happy to help", "Not now"]}])
	await d.finished
	if d.last_choice != 0:
		return false
	var plan := _help_plan(n)
	if plan.is_empty():
		return false
	help = {"npc": n, "kind": kind, "left": plan.size(), "total": plan.size(), "carrying": false, "drop": drop[0], "drop_name": drop[1]}
	match kind:
		"weed":
			for c: Vector2i in plan:
				map.set_thing(c.x, c.y, {"type": "cf_weed", "hint": "A: pull the weed"}, false)
				var sp := map.prop(WEED_ART[0], WEED_ART[1], c, 0, 0.0, false, 0.3)
				if sp:
					sp.modulate = Color(0.75, 1.0, 0.7)
		"haul":
			for c: Vector2i in plan:
				map.set_thing(c.x, c.y, {"type": "cf_load", "hint": "A: pick up the crate"}, false)
				map.prop(CRATE_ART[0], CRATE_ART[1], c, 0, 0.0, false, 0.3)
		"water":
			help["keys"] = plan
	var go := str(Commons.tx(def.get("go", "")))
	if "%s" in go:
		go = go % (str(drop[1]) if kind == "haul" else name)
	map.hud.toast(go, Color(0.9, 1, 0.8))
	for c: Vector2i in (plan if kind != "water" else []):
		map.fx("sparkle", map.cell_center(c) + Vector2(0, -6), 12.0, 0.4)
	return true


## interact() hook: weeds, crates and the drop point while you carry one.
func interact(c: Vector2i, thing: Dictionary) -> bool:
	var t := str(thing.get("type", ""))
	if help.is_empty():
		return false
	if t == "cf_weed":
		if ToolHint.is_soft(GameState.held_tool()):
			ToolHint.say(map, "Pull it by hand or with a blade.")
			return true
		if not GameState.spend_for("weed"):
			return true
		map.player.play_tool("hold")
		Music.instance(map.get_tree()).sfx("forage", "pickup")
		_clear_cell(c)
		map.fx("leaf_burst" if Art.has("fx", "leaf_burst") else "leaf_green", map.cell_center(c), 12.0, 0.45)
		_step()
		return true
	if t == "cf_load":
		if bool(help.get("carrying", false)):
			map.hud.toast("One at a time: take this one to the %s first." % str(help["drop_name"]), Color(1, 0.9, 0.75))
			return true
		if not GameState.spend_for("weed"):
			return true
		_clear_cell(c)
		help["carrying"] = true
		map.player.play_tool("hold")
		Music.instance(map.get_tree()).sfx("pickup")
		_show_carry(true)
		map.hud.toast("Carrying a crate: take it to the %s." % str(help["drop_name"]), Color(0.9, 1, 0.8))
		return true
	if t == str(help.get("drop", "")) and bool(help.get("carrying", false)):
		help["carrying"] = false
		_show_carry(false)
		map.player.play_tool("hold")
		Music.instance(map.get_tree()).sfx("thud", "pickup")
		map.fx("dust_puff", map.cell_center(c), 12.0, 0.45)
		_step()
		return true
	return false


func hint(thing: Dictionary) -> String:
	if help.is_empty():
		return ""
	var t := str(thing.get("type", ""))
	if t == str(help.get("drop", "")) and bool(help.get("carrying", false)):
		return "A: put the crate down"
	return ""


func _clear_cell(c: Vector2i) -> void:
	map.things.erase(c)
	if map.props.has(c):
		(map.props[c] as Node).queue_free()
		map.props.erase(c)


func _show_carry(on: bool) -> void:
	if on and _carry_sprite == null and map.player:
		_carry_sprite = Sprite2D.new()
		_carry_sprite.texture = Art.tex(CRATE_ART[0], CRATE_ART[1])
		_carry_sprite.scale = Vector2(0.26, 0.26)
		_carry_sprite.position = Vector2(0, -30)
		_carry_sprite.z_index = 2
		_carry_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		map.player.add_child(_carry_sprite)
	elif not on and _carry_sprite != null:
		_carry_sprite.queue_free()
		_carry_sprite = null


## Watering tasks finish themselves as the cells get wet.
func _help_tick() -> void:
	if help.is_empty() or str(help["kind"]) != "water":
		return
	var left := 0
	for key: String in help["keys"]:
		if not bool(Commons.plot(key).get("w", false)) and not GameState.sky_waters():
			left += 1
	if left < int(help["left"]):
		help["left"] = left
		if left > 0:
			map.hud.toast("%d more to water." % left, Color(0.85, 0.95, 1))
		else:
			_complete()


func _step() -> void:
	help["left"] = int(help["left"]) - 1
	if int(help["left"]) > 0:
		map.hud.toast("%d more to go." % int(help["left"]), Color(0.9, 1, 0.85))
		return
	_complete()


func _complete() -> void:
	var n: Npc = help["npc"]
	var kind := str(help["kind"])
	help = {}
	_show_carry(false)
	var id := n.id if is_instance_valid(n) else Commons.keeper()
	var name := str(GameState.npcs.get(id, {}).get("name", id))
	var got := Commons.reward_help(id)
	map.xp("farming", 2)
	Music.instance(map.get_tree()).sfx("quest_done", "levelup")
	if is_instance_valid(n) and n.visible:
		map.emote(n, "heart", 1.4, -34.0)
		n.face(map.player.position)
	map.later(func() -> void:
		await map.say([{"who": name, "text": str(Commons.tx(Commons.help_def(kind).get("done", "Thank you!")))}])
		for g: Array in got:
			map.give(str(g[0]), int(g[1]))
		map.hud.toast("%s +10 friendship" % name, Color(1, 0.8, 0.9)))
