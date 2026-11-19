extends SceneTree
## Movement, facing, targeting and the swimming pup (CONDUCT 2 P2).
## 1. Stopping keeps the facing you walked in, for several heroes (incl. a 12B
##    hero whose idle is the front pose), with keys (straight, diagonal released
##    together or one key first) and with the touch stick (thumb roll on lift).
## 2. Walking up to a rock, a tree, a crop and a villager from all 8 directions
##    targets that thing (facing_cell, the cursor square and USE agree).
## 3. A sword swing after a diagonal approach hits the foe you walked toward.
## 4. In water the pup and a partner swim (Paddle) instead of walking on it, both arcs.
##   godot --headless --fixed-fps 60 --path . -s res://tools/move_target_test.gd [-- -v]
var fails := 0
var verbose := false


func check(ok: bool, what: String) -> void:
	if verbose or not ok:
		print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Campaign.bypass = true
	seed(7)
	verbose = "-v" in OS.get_cmdline_user_args()
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _drain() -> void:
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			await frames(2)
			if not d.active:
				return
		d._advance()
		await frames(2)


func _load(scene: String) -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await frames(12)
	await _drain()
	var m := current_scene as GameMap
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	await frames(2)
	Dialogue.block_until_ms = 0
	return m


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "a", "b", "tool", "action"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _keys(d: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if d.x < 0: out.append("left")
	if d.x > 0: out.append("right")
	if d.y < 0: out.append("up")
	if d.y > 0: out.append("down")
	return out


const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


static func _face_of(d: Vector2i) -> String:
	if d.y != 0:
		return "up" if d.y < 0 else "down"
	return "left" if d.x < 0 else "right"


## The rest pose the facing should show (with the fallbacks Player._apply uses).
func _rest_ok(p: Player, f: String) -> bool:
	var a := p.anim_name
	match f:
		"up": return a == "view_back" or (not p.has_anim("view_back") and a == "idle")
		"right": return (a == "view_right" and not p._anim.flip_h) or (not p.has_anim("view_right") and a == "idle")
		"left": return a == "view_left" or (a == "view_right" and p._anim.flip_h) or (not p.has_anim("view_right") and a == "idle")
	return a == "idle"


func _open_area(m: GameMap, at: Vector2i, r: int) -> void:
	for x in range(at.x - r, at.x + r + 1):
		for y in range(at.y - r, at.y + r + 1):
			m.clear_cell(Vector2i(x, y))
			(GameState.run["farm"] as Dictionary).erase("%d,%d" % [x, y])


func _run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["intro_done"] = true
	GameState.run["energy"] = 999
	GameState.run["max_energy"] = 999
	var m := await _load("farm")
	var p := m.player
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var home := Vector2i(22, 22)
	_open_area(m, home, 7)
	await frames(2)
	# ---- 1. facing on stop -------------------------------------------------
	for who: String in [GameState.sprite_for_playable("kairi"), "merry", "coldy", "penguin", "man_gang", "dad"]:
		if not CharacterLibrary.has_character(who):
			continue
		p.set_character(who)
		await frames(2)
		for d: Vector2i in DIRS8:
			var modes: Array[String] = ["together"]
			if d.x != 0 and d.y != 0:
				modes.append_array(["x_first", "y_first"])
			for mode: String in modes:
				p.position = m.cell_center(home)
				p.velocity = Vector2.ZERO
				p.facing = "down" if d.y < 0 or (d.y == 0 and d.x != 0) else "up"  # start the other way
				var ks := _keys(d)
				for k in ks:
					Input.action_press(k)
				await frames(24)
				if mode == "together":
					for k in ks:
						Input.action_release(k)
				else:
					var first: String = ks[0] if mode == "x_first" else ks[1]
					Input.action_release(first)
					await frames(3)
					_release_all()
				await frames(20)
				var want := _face_of(d)
				check(p.facing == want, "%s keys %s (%s): rests facing %s (got %s)" % [who, d, mode, want, p.facing])
				check(_rest_ok(p, want), "%s keys %s (%s): rest pose fits %s (anim %s flip %s)" % [who, d, mode, want, p.anim_name, p._anim.flip_h if p._anim else false])
				_release_all()
	# Touch stick: 8-way vector, then the thumb rolls to a cardinal for 2 frames on lift.
	p.set_character(GameState.sprite_for_playable("kairi"))
	await frames(2)
	var tcs := root.find_children("*", "TouchControls", true, false)
	var tc: TouchControls = tcs[0] if tcs.size() > 0 else null
	check(tc != null, "TouchControls is in the tree")
	if tc:
		var was := TouchControls.visible_controls
		TouchControls.visible_controls = true
		for d: Vector2i in DIRS8:
			p.position = m.cell_center(home)
			p.velocity = Vector2.ZERO
			p.facing = "down" if d.y <= 0 else "up"
			tc._set_vec(Vector2(d).normalized(), false)
			await frames(24)
			if d.x != 0 and d.y != 0:
				tc._set_vec(Vector2(d.x, 0), false)  # thumb roll
				await frames(2)
			tc._end_stick()
			await frames(20)
			check(p.facing == _face_of(d), "stick %s: rests facing %s (got %s)" % [d, _face_of(d), p.facing])
			check(_rest_ok(p, _face_of(d)), "stick %s: rest pose fits (anim %s)" % [d, p.anim_name])
		# A long sideways input after a diagonal does turn you (the grace is short).
		p.position = m.cell_center(home)
		tc._set_vec(Vector2(1, 1).normalized(), false)
		await frames(20)
		tc._set_vec(Vector2(1, 0), false)
		await frames(20)
		tc._end_stick()
		await frames(15)
		check(p.facing == "right", "diagonal then a real turn right: faces right (got %s)" % p.facing)
		tc.release_all()
		TouchControls.visible_controls = was
	_release_all()
	# ---- 2. targeting from all 8 directions --------------------------------
	GameState.select_slot((GameState.run["toolbar"] as Array).find("can"))
	var t := home
	for kind: String in ["rock", "tree", "crop"]:
		for d: Vector2i in DIRS8:
			_open_area(m, t, 5)
			if kind == "rock":
				m.set_thing(t.x, t.y, {"type": "rock", "hp": 2, "hint": "A: break rock"})
			elif kind == "tree":
				m.set_thing(t.x, t.y, {"type": "tree", "hp": 4, "hint": "A: chop"})
			else:
				(GameState.run["farm"] as Dictionary)["%d,%d" % [t.x, t.y]] = {"crop": "parsnip", "age": 1, "watered": false}
			var res := await _approach(m, p, t, d)
			check(res[0], "%s from %s: target %s is the %s (got %s, stood %s facing %s)" % [kind, d, t, kind, res[1], res[2], p.facing])
	_open_area(m, t, 5)
	await _villager_check()
	# ---- 3. a swing after a diagonal approach hits the foe -----------------
	m = await _load("meadow")
	p = m.player
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.select_slot((GameState.run["toolbar"] as Array).find("sword"))
	for k in 8:
		var d: Vector2i = [Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1)][k % 4]
		# First a foe on the diagonal, then one off to the side you walked toward.
		var off := Vector2(d) * 15.0 if k < 4 else Vector2(d.x * 18.0, d.y * 4.0)
		var c0 := Vector2i(14, 10)
		_open_area(m, c0, 4)
		p.position = m.cell_center(c0)
		p.velocity = Vector2.ZERO
		var g := m.spawn_enemy("grump", p.position + off)
		g.position = p.position + off
		g.process_mode = Node.PROCESS_MODE_DISABLED
		p.facing = _face_of(d)
		p.move8 = d
		p._attack_cd = 0.0
		p._busy = false
		var hp0: int = g.hp
		p.do_action("tool")
		await frames(4)
		check(not is_instance_valid(g) or g.hp < hp0 or not g._alive, "sword after a %s approach hits the foe at %s (hp %d -> %d)" % [d, off, hp0, g.hp if is_instance_valid(g) else -1])
		if is_instance_valid(g):
			g.queue_free()
		m.enemies.clear()
		await frames(25)
	# ---- 4. the pup swims ---------------------------------------------------
	for arc: String in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["energy"] = 999
		GameState.run["max_energy"] = 999
		m = await _load("lake")
		p = m.player
		var wc := _deep_water(m)
		check(wc != Vector2i(-999, -999), "%s: the lake has open water" % arc)
		if wc == Vector2i(-999, -999) or m.pet == null:
			check(m.pet != null, "%s: the pup is with you at the lake" % arc)
			continue
		var pt := m.pet as Pet
		p.position = m.cell_center(wc)
		pt.position = p.position + Vector2(-14, 4)
		pt.visible = true
		await frames(40)
		var pc := m.world_to_cell(pt.position - Vector2(0, 2))
		check(m.is_water_cell(pc), "%s: the pup followed you into the water (cell %s)" % [arc, pc])
		check(pt.swimming and pt._paddle != null and pt._paddle.visible, "%s: in water the pup swims (water band over its legs)" % arc)
		check(pt.anim.animation in ["walk"], "%s: the pup paddles, never sits or stands on the water (anim %s)" % [arc, pt.anim.animation])
		check(pt.anim.position.y > 1.0, "%s: the pup sits low in the water (body y %.1f)" % [arc, pt.anim.position.y])
		# Back on land: the band goes and the pup stands on its feet again.
		var land := _land_near(m, wc)
		p.position = m.cell_center(land)
		pt.position = p.position + Vector2(-14, 4)
		await frames(30)
		if not m.is_water_cell(m.world_to_cell(pt.position - Vector2(0, 2))):
			check(not pt.swimming and not pt._paddle.visible and absf(pt.anim.position.y) < 0.01, "%s: out of the water the pup walks again" % arc)
		# A partner (any active companion) swims too.
		for c in m.get_children():
			if c is Companion:
				var co := c as Companion
				co.position = m.cell_center(wc) + Vector2(10, 0)
				p.position = m.cell_center(wc)
				await frames(10)
				if m.is_water_cell(m.world_to_cell(co.position - Vector2(0, 2))):
					check(co._paddle != null and co._paddle.visible, "%s: a partner in the water swims too" % arc)
	print("move_target_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)


## Walk toward `t` from 3 cells away along `d` until next to it, let go, and
## see what USE would target.
func _approach(m: GameMap, p: Player, t: Vector2i, d: Vector2i) -> Array:
	var start := t - d * 3
	p.position = m.cell_center(start)
	p.velocity = Vector2.ZERO
	p.auto_target = Vector2.INF
	p.facing = "down"
	p.move8 = Vector2i.ZERO
	await frames(2)
	var ks := _keys(d)
	for k in ks:
		Input.action_press(k)
	for i in 150:
		await frames(1)
		var c := p.cell()
		if maxi(absi(c.x - t.x), absi(c.y - t.y)) <= 1:
			break
	_release_all()
	await frames(10)
	var fc := p.facing_cell()
	return [fc == t, fc, p.cell()]


func _villager_check() -> void:
	var m := await _load("town")
	var p := m.player
	if m.pet:
		m.pet.visible = false
		m.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var npc: Npc = null
	for n in m.get("npcs"):
		if n is Npc and (n as Npc).visible:
			npc = n
			break
	check(npc != null, "a villager in town")
	if npc == null:
		return
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.select_slot((GameState.run["toolbar"] as Array).find("sword"))
	# An open patch of street with room on every side.
	var t := Vector2i(-1, -1)
	for y in range(6, m.rows - 6):
		for x in range(6, m.cols - 6):
			var ok := true
			for dx in range(-4, 5):
				for dy in range(-4, 5):
					var c := Vector2i(x + dx, y + dy)
					if m.blocked.has(c) or m.things.has(c) or m._exit_at(c):
						ok = false
						break
				if not ok:
					break
			if ok:
				t = Vector2i(x, y)
				break
		if t != Vector2i(-1, -1):
			break
	check(t != Vector2i(-1, -1), "an open patch in town")
	if t == Vector2i(-1, -1):
		return
	for d: Vector2i in DIRS8:
		npc.position = m.cell_center(t)
		await _drain()
		p.frozen = false  # a first-visit beat may hold the hero: this is about aiming
		Dialogue.block_until_ms = 0
		var res := await _approach(m, p, t, d)
		check(res[0], "villager from %s: target is the villager (got %s, stood %s facing %s)" % [d, res[1], res[2], p.facing])


func _deep_water(m: GameMap) -> Vector2i:
	for c: Vector2i in m.things:
		if not m.is_water_cell(c) or not m.in_content(c) or m.hard.has(c):
			continue
		var ok := true
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if not m.is_water_cell(c + Vector2i(dx, dy)) or m.hard.has(c + Vector2i(dx, dy)):
					ok = false
		if ok:
			return c
	return Vector2i(-999, -999)


func _land_near(m: GameMap, c: Vector2i) -> Vector2i:
	for r in range(1, 30):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if m.in_content(q) and not m.is_water_cell(q) and not m.blocked.has(q):
					var open := true
					for k: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if m.blocked.has(q + k) or m.is_water_cell(q + k):
							open = false
					if open:
						return q
	return c
