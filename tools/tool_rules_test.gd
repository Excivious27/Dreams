extends SceneTree
## Held-tool rules: the right tool acts, a wrong tool says a short hint (ToolHint)
## and never acts, silently or otherwise. Farm (shared interact_common + field),
## a region (mrock, water), the mine (rock, crate), the community farm (debris),
## the hint lines themselves and the first-pick toolbar tips.
##   godot --headless --path . -s res://tools/tool_rules_test.gd
var fails := 0
var _dbg := false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drain() -> void:
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			await _frames(2)
			if not d.active:
				return
		d._advance()
		await _frames(2)


func _load(scene: String) -> GameMap:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await _frames(12)
	await _drain()
	var m := current_scene as GameMap
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	await _frames(2)
	return m


func _toasts(m: GameMap) -> String:
	var out: Array = []
	for c in m.hud._toasts.get_children():
		if c is Label and not c.is_queued_for_deletion():
			out.append(str(c.get_meta("base", (c as Label).text)))
	return " | ".join(out)


## An open cell pair (stand, target) on the map: both free, no exits, no things.
func _spot(m: GameMap) -> Array:
	var p := m.player.cell()
	for r in range(0, 30):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q: Vector2i in [p + Vector2i(dx, dy), p + Vector2i(dy, dx)]:
					var t := q + Vector2i(1, 0)
					if not m.in_content(q) or not m.in_content(t):
						continue
					if m.blocked.has(q) or m.blocked.has(t) or m.things.has(q) or m.things.has(t) or m._exit_at(q) or m._exit_at(t):
						continue
					if m.has_method("_tillable") and m.call("_tillable", t) and (GameState.run["farm"] as Dictionary).has("%d,%d" % [t.x, t.y]):
						continue
					return [q, t]
	return []


## Hold `tool` (an id on slot 0; "" = empty hand), face `c` from `stand`, press USE.
func _use(m: GameMap, stand: Vector2i, c: Vector2i, tool: String) -> String:
	GameState.run["toolbar"][0] = tool
	GameState.select_slot(0)
	for ch in m.hud._toasts.get_children():
		ch.queue_free()
	m.player.position = m.cell_center(stand)
	m.player.face_toward(m.cell_center(c))
	m.player._busy = false
	m.player._attack_cd = 0.0
	m.player.frozen = false
	m.player.auto_target = Vector2.INF
	await _frames(2)
	m.player.position = m.cell_center(stand)
	var dv := c - stand
	m.player.facing = "right" if dv.x > 0 else ("left" if dv.x < 0 else ("up" if dv.y < 0 else "down"))
	m.player.aim_cell = Vector2i(-1, -1)
	if m.player.facing_cell() != c and not _dbg:
		_dbg = true
		print("  debug: stand %s cell %s facing %s target %s pos %s" % [stand, m.player.cell(), m.player.facing_cell(), c, m.player.position])
	m.player.do_action("a")
	await _frames(4)
	var tx := _toasts(m)
	await _frames(16)
	m.player._busy = false
	await _drain()
	return tx


func _put(m: GameMap, c: Vector2i, thing: Dictionary, solid := true) -> void:
	m.things[c] = thing
	if solid:
		m.blocked[c] = true
	else:
		m.blocked.erase(c)


func _new(arc: String) -> void:
	GameState.new_run(arc, "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	for f in ["town_seen", "town_tour", "partner_scene", "gangsters_intro", "mine_seen", "mountain_seen", "cf_seen", "quarry_seen"]:
		GameState.run["flags"][f] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	if not GameState.has_tool("scythe"):
		GameState.run["tools"].append("scythe")
	GameState.add_item("turnip_seed", 5)
	# Every tool tip already seen: the tests read hint toasts only.
	for k in ToolHint.TIPS:
		GameState.run["flags"]["tip_" + k] = true


func _run() -> void:
	InputSetup.ensure_actions()
	_lines()
	for arc in ["penguins", "gangsters"]:
		await _farm(arc)
	await _region()
	await _mine()
	await _cfarm()
	await _tips()
	print("tool_rules_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


func _lines() -> void:
	_new("penguins")
	check(ToolHint.line("axe").contains("tap it on your toolbar"), "axe on toolbar: tap hint (%s)" % ToolHint.line("axe"))
	GameState.run["toolbar"][2] = ""
	check(ToolHint.line("axe").contains("MENU > Items"), "axe in the bag: toolbar hint (%s)" % ToolHint.line("axe"))
	GameState.run["flags"]["tool_away_axe"] = true
	check(ToolHint.line("axe").contains("smithy"), "axe at the smith: says so (%s)" % ToolHint.line("axe"))
	GameState.run["tools"].erase("rod")
	check(ToolHint.line("rod", "to fish") == "You need a Fishing Rod to fish.", "no rod: need line (%s)" % ToolHint.line("rod", "to fish"))
	check(ToolHint.line("axe", "x").begins_with("Your Axe"), "names read from items")
	check(ToolHint._a("Axe") == "an" and ToolHint._a("Hoe") == "a", "a/an")


func _farm(arc: String) -> void:
	var tag := arc.left(3)
	_new(arc)
	var m := await _load("farm")
	var sp := _spot(m)
	check(not sp.is_empty(), "[%s] farm: found an open spot" % tag)
	if sp.is_empty():
		return
	var st: Vector2i = sp[0]
	var c: Vector2i = sp[1]
	# Trees, logs, stumps: the axe only.
	for t in ["tree", "log", "stump"]:
		for tool in ["hoe", "can", "pickaxe", "scythe", "sword", "rod", ""]:
			_put(m, c, {"type": t, "hp": 3})
			var tx := await _use(m, st, c, tool)
			check(tx.contains("Axe") and int(m.things.get(c, {}).get("hp", -1)) == 3, "[%s] %s with %s: axe hint, untouched (%s)" % [tag, t, tool if tool != "" else "hand", tx])
		_put(m, c, {"type": t, "hp": 9})
		await _use(m, st, c, "axe")
		check(int(m.things.get(c, {}).get("hp", 9)) < 9, "[%s] %s with the axe: chopped" % [tag, t])
	# Rocks: the pickaxe only.
	for tool in ["hoe", "can", "axe", "sword", "rod", ""]:
		_put(m, c, {"type": "rock", "hp": 2})
		var tx := await _use(m, st, c, tool)
		check(tx.contains("Pickaxe") and int(m.things.get(c, {}).get("hp", -1)) == 2, "[%s] rock with %s: pickaxe hint (%s)" % [tag, tool if tool != "" else "hand", tx])
	_put(m, c, {"type": "rock", "hp": 9})
	await _use(m, st, c, "pickaxe")
	check(int(m.things.get(c, {}).get("hp", 9)) < 9, "[%s] rock with the pickaxe: broken into" % tag)
	# Weeds: by hand or any swinging tool, never the can or the rod.
	for tool in ["can", "rod"]:
		_put(m, c, {"type": "weeds", "key": "w"})
		var tx := await _use(m, st, c, tool)
		check(m.things.has(c) and tx.contains("weeds"), "[%s] weeds with %s: hint, not pulled (%s)" % [tag, tool, tx])
	for tool in ["", "scythe", "hoe", "sword"]:
		_put(m, c, {"type": "weeds", "key": "w"})
		await _use(m, st, c, tool)
		check(not m.things.has(c), "[%s] weeds with %s: pulled" % [tag, tool if tool != "" else "hand"])
	m.blocked.erase(c)
	# A berryless bush says so instead of nothing.
	_put(m, c, {"type": "bush", "berries": false, "key": "b"})
	var bt := await _use(m, st, c, "axe")
	check(bt.contains("berries") or bt.contains("spring"), "[%s] empty bush: says so (%s)" % [tag, bt])
	m.things.erase(c)
	m.blocked.erase(c)
	# Water: only the rod fishes.
	_put(m, c, {"type": "water"})
	var wt := await _use(m, st, c, "hoe")
	check(wt.contains("Fishing Rod") and not m.player.frozen, "[%s] water with the hoe: rod hint, no cast (%s)" % [tag, wt])
	GameState.run["tools"].erase("rod")
	wt = await _use(m, st, c, "")
	check(wt.contains("You need a Fishing Rod"), "[%s] water, no rod owned: says you need one (%s)" % [tag, wt])
	GameState.run["tools"].append("rod")
	m.things.erase(c)
	m.blocked.erase(c)
	# The rod at dry ground: a hint, not a cast at the grass.
	var rt := await _use(m, st, c, "rod")
	check(rt.contains("Face water"), "[%s] rod at grass: hint (%s)" % [tag, rt])
	# Seeds on untilled grass: a hint, never a punch.
	if m.call("_tillable", c):
		var seed_tx := await _use(m, st, c, "turnip_seed")
		check(seed_tx.contains("tilled soil") and not (GameState.run["farm"] as Dictionary).has("%d,%d" % [c.x, c.y]), "[%s] seeds on grass: till-first hint (%s)" % [tag, seed_tx])
		# Till, plant, then a dry crop with the axe: can hint, stays dry.
		await _use(m, st, c, "hoe")
		var key := "%d,%d" % [c.x, c.y]
		check((GameState.run["farm"] as Dictionary).has(key), "[%s] the hoe tills" % tag)
		GameState.run["weather"] = {str(int(GameState.run["day"])): "clear"}
		var et := await _use(m, st, c, "axe")
		check(et.contains("seeds"), "[%s] empty soil with the axe: plant hint (%s)" % [tag, et])
		await _use(m, st, c, "turnip_seed")
		check(str(GameState.run["farm"].get(key, {}).get("crop", "")) != "", "[%s] seeds plant in tilled soil" % tag)
		if not GameState.sky_waters():
			var dt := await _use(m, st, c, "axe")
			check((dt.contains("Watering Can") or dt.contains("with the can")) and not bool(GameState.run["farm"][key].get("watered", false)), "[%s] dry crop with the axe: can hint (%s)" % [tag, dt])
			var ht := await _use(m, st, c, "hoe")
			check(ht == "" or ht.contains("more day"), "[%s] dry crop with the hoe: quiet in rows, reads on a tap (%s)" % [tag, ht])
			await _use(m, st, c, "can")
			check(bool(GameState.run["farm"][key].get("watered", false)), "[%s] the can waters" % tag)
		(GameState.run["farm"] as Dictionary).erase(key)
	# Grove (old wood) with the axe: says why it won't chop.
	_put(m, c, {"type": "grove", "hint": ""})
	var gt := await _use(m, st, c, "axe")
	check(gt.contains("too thick"), "[%s] grove with the axe: hint (%s)" % [tag, gt])
	m.things.erase(c)
	m.blocked.erase(c)


func _region() -> void:
	_new("penguins")
	var m := await _load("quarry")
	var sp := _spot(m)
	check(not sp.is_empty(), "quarry: found an open spot")
	if sp.is_empty():
		return
	var st: Vector2i = sp[0]
	var c: Vector2i = sp[1]
	for tool in ["axe", "hoe", ""]:
		_put(m, c, {"type": "mrock", "ore": "stone", "hp": 2})
		var tx := await _use(m, st, c, tool)
		check(tx.contains("Pickaxe") and int(m.things.get(c, {}).get("hp", -1)) == 2, "region mrock with %s: pickaxe hint (%s)" % [tool if tool != "" else "hand", tx])
	_put(m, c, {"type": "mrock", "ore": "stone", "hp": 9})
	await _use(m, st, c, "pickaxe")
	check(int(m.things.get(c, {}).get("hp", 9)) < 9, "region mrock with the pickaxe: mined")
	_put(m, c, {"type": "water"})
	var wt := await _use(m, st, c, "sword")
	check(wt.contains("Fishing Rod"), "region water with the sword: rod hint (%s)" % wt)
	m.things.erase(c)
	m.blocked.erase(c)


func _mine() -> void:
	_new("penguins")
	GameState.run["mine_floor"] = 1
	var m := await _load("mine")
	var sp := _spot(m)
	check(not sp.is_empty(), "mine: found an open spot")
	if sp.is_empty():
		return
	var st: Vector2i = sp[0]
	var c: Vector2i = sp[1]
	for tool in ["axe", "hoe", ""]:
		_put(m, c, {"type": "rock", "ore": "stone", "hp": 2})
		var tx := await _use(m, st, c, tool)
		check(tx.contains("Pickaxe") and int(m.things.get(c, {}).get("hp", -1)) == 2, "mine rock with %s: pickaxe hint (%s)" % [tool if tool != "" else "hand", tx])
	for tool in ["can", "rod"]:
		_put(m, c, {"type": "crate", "hp": 2})
		var tx := await _use(m, st, c, tool)
		check(tx.contains("crates") and int(m.things.get(c, {}).get("hp", -1)) == 2, "mine crate with %s: hint (%s)" % [tool, tx])
	_put(m, c, {"type": "crate", "hp": 5})
	await _use(m, st, c, "sword")
	check(int(m.things.get(c, {}).get("hp", 5)) < 5, "mine crate with the sword: smashed")
	m.things.erase(c)
	m.blocked.erase(c)


func _cfarm() -> void:
	_new("penguins")
	GameState.run["day"] = 3
	Commons.overnight({})
	var m := await _load("community_farm")
	var junk: Dictionary = m.get_script().get_script_constant_map()["JUNK"]
	var deb := Vector2i(-1, -1)
	for c: Vector2i in m.things:
		if str(m.things[c].get("type", "")) == "cf_debris" and str(junk[str(m.things[c]["kind"])][2]) != "":
			deb = c
			break
	if deb == Vector2i(-1, -1):
		print("  (community farm: no tool debris on this save; skipped)")
		return
	var need := str(junk[str(m.things[deb]["kind"])][2])
	var stand := Vector2i(-1, -1)
	for off: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if not m.blocked.has(deb + off) and m.in_content(deb + off):
			stand = deb + off
			break
	if stand == Vector2i(-1, -1):
		return
	var hp := int(m.things[deb]["hp"])
	var wrong := "hoe" if need != "hoe" else "axe"
	var tx := await _use(m, stand, deb, wrong)
	check(tx.contains(GameState.item_name(need)) and int(m.things.get(deb, {}).get("hp", -1)) == hp, "cf debris with %s: %s hint (%s)" % [wrong, need, tx])


func _tips() -> void:
	_new("penguins")
	for k in ToolHint.TIPS:
		GameState.run["flags"].erase("tip_" + k)
	var m := await _load("farm")
	GameState.run["toolbar"][0] = "axe"
	GameState.select_slot(0)
	for ch in m.hud._toasts.get_children():
		ch.queue_free()
	await _frames(4)
	check(_toasts(m).contains("Axe: chop"), "first axe pick: tip shown (%s)" % _toasts(m))
	check(GameState.run["flags"].has("tip_axe"), "tip remembered")
	GameState.run["toolbar"][1] = "hoe"
	GameState.select_slot(1)
	await _frames(3)
	GameState.select_slot(0)
	for ch in m.hud._toasts.get_children():
		ch.queue_free()
	await _frames(4)
	check(not _toasts(m).contains("Axe: chop"), "second axe pick: no repeat")
	GameState.run["toolbar"][3] = "turnip_seed"
	GameState.select_slot(3)
	await _frames(4)
	check(_toasts(m).contains("Seeds:"), "seeds tip shown (%s)" % _toasts(m))
