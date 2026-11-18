class_name Battle
extends Node2D
## Conquest battles (data/regions.json "battle"): a huge map with control points.
## Stand on a point with no foes on it and the ring fills; hold it and it's
## yours. Each side has tickets: the side holding fewer points bleeds them, and
## every fallen foe costs the enemy one. Points you hold earn supply; spend it on
## a spawner at a point (USE on its banner) and it turns out helper units:
## crystals (penguins) or drones (gangsters): strikers, healers, wardens, shades.
## Take every point or run their tickets out to win.

const CAP_R := 44.0          # capture radius (px)
const CAP_TIME := 7.0        # seconds for one person to take a neutral point
const SPAWNER_COST := {"striker": 20, "healer": 25, "warden": 25, "shade": 30, "turret": 30}
const MAX_PER_SPAWNER := 3

var map: GameMap
var _redraw_acc := 0.0
var bid := ""
var d: Dictionary = {}
var points: Array = []        # [{id, name, cell, pos, owner, prog, spawner, made, t}]
var tickets := {"ally": 150, "enemy": 150}
var supply := 10
var _upkeep := 0.0
var _sup_f := 0.0
var _caps := 0
var _kills := 0
var _mend_cd := 0.0
var _barrage_cd := 0.0
var _order_t := 0.0
var _target_pt: Dictionary = {}
var _sec := 0.0
var _spawn_t := 3.0
var _known := {}
var _over := false
var _boss_out := false
var _hud: Control


static func start(m: GameMap, region_id: String, data: Dictionary) -> Battle:
	var b := Battle.new()
	b.map = m
	b.bid = region_id
	b.d = data
	b.z_index = 1
	m.add_child(b)
	b._setup()
	return b



## Who speaks the brief / win / lose lines: a crew member only once recruited.
func _who() -> String:
	var w := str(d.get("who", ""))
	var id := w.to_lower().replace(" ", "_")
	return w if not Crew.members().has(id) or Crew.recruited(id) else ""

func _setup() -> void:
	var t := int(d.get("tickets", 150))
	tickets = {"ally": t, "enemy": t}
	supply = int(d.get("supply", 10)) + int(GameState.bonus("strategist", "start_supply"))
	for p in d.get("points", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		var pt := {"id": str(p["id"]), "name": str(p["name"]), "cell": c, "pos": map.cell_center(c), "owner": str(p.get("owner", "neutral")), "prog": 0.0, "spawner": "", "made": [], "t": 0.0}
		pt["prog"] = 1.0 if pt["owner"] == "ally" else (-1.0 if pt["owner"] == "enemy" else 0.0)
		points.append(pt)
		map.set_thing(c.x, c.y, {"type": "cpoint", "id": pt["id"], "hint": "A: %s" % pt["name"]}, true)
	var layer := CanvasLayer.new()
	layer.layer = 5
	map.add_child(layer)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.size = Vector2(270, 480)
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	# RALLY: send every helper to one point (tap to cycle), or let them guard their own.
	_rally_btn = Button.new()
	_rally_btn.position = RALLY_RECT.position
	_rally_btn.size = RALLY_RECT.size
	_rally_btn.add_theme_font_size_override("font_size", 8)
	_rally_btn.focus_mode = Control.FOCUS_NONE
	_rally_btn.pressed.connect(func() -> void: map.later(_pick_rally))
	layer.add_child(_rally_btn)
	Hud.extra_rects.append(RALLY_RECT)
	_set_rally(-2)
	map.hud.toast("%s. Take the points. Hold more than they do." % str(d.get("title", "Battle")), Color(1, 0.9, 0.6))
	map.later(func() -> void:
		await map.say([{"who": _who(), "text": str(d.get("brief", "Every point you hold earns supply. Build at a point you hold to make helpers."))}]))


const RALLY_RECT := Rect2(8, 128, 86, 18)
var _rally_btn: Button
var _rally := -1


## Cycle: guard posts → follow me → each point in turn → guard posts.
func _cycle_rally() -> void:
	var i := _rally + 1
	if i >= points.size():
		i = -2
	_set_rally(i)
	Music.instance(map.get_tree()).sfx("pickup")


## One tap: pick where the helpers go from a list (instead of cycling through every point).
func _pick_rally() -> void:
	var o: Array = ["Guard posts", "Follow me"]
	for p in points:
		o.append("%s %s" % [str(p["id"]).to_upper(), str(p["name"])])
	var dl := Dialogue.instance(get_tree())
	dl.say([{"who": "", "text": "Helpers:", "choice": o, "key": ""}])
	await dl.finished
	if dl.last_choice >= 0 and not _over:
		_set_rally(dl.last_choice - 2)
		Music.instance(map.get_tree()).sfx("pickup")


func _set_rally(i: int) -> void:
	_rally = i
	if map.has_meta("follow_me"):
		map.remove_meta("follow_me")
	if i == -1:
		if map.has_meta("rally_pos"):
			map.remove_meta("rally_pos")
		map.set_meta("follow_me", true)
		_rally_btn.text = "RALLY: follow me"
		map.hud.toast("Helpers: on me!", Color(0.7, 0.95, 1.0))
	elif i < 0:
		if map.has_meta("rally_pos"):
			map.remove_meta("rally_pos")
		_rally_btn.text = "RALLY: guard posts"
	else:
		map.set_meta("rally_pos", points[i]["pos"])
		_rally_btn.text = "RALLY ▸ %s %s" % [str(points[i]["id"]).to_upper(), str(points[i]["name"])]
		map.hud.toast("Helpers: everyone to %s!" % str(points[i]["name"]), Color(0.7, 0.95, 1.0))


func _exit_tree() -> void:
	Hud.extra_rects.erase(RALLY_RECT)
	if map and is_instance_valid(map) and map.has_meta("rally_pos"):
		map.remove_meta("rally_pos")


var _bleed_e := 0.0
var _rate := 0.0   # supply per second after upkeep (HUD)
var _bleed_a := 0.0


func _cost(k: String) -> int:
	return maxi(1, int(round(int(SPAWNER_COST[k]) * (1.0 - GameState.bonus("strategist", "spawner_discount")))))


func point(id: String) -> Dictionary:
	for p in points:
		if str(p["id"]) == id:
			return p
	return {}


func _owned(side: String) -> int:
	var n := 0
	for p in points:
		if str(p["owner"]) == side:
			n += 1
	return n


func _process(delta: float) -> void:
	if _over or get_tree().paused or map.player == null:
		return
	_capture(delta)
	_sec += delta
	if _sec >= 1.0:
		_sec = 0.0
		_tick()
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = float(d.get("wave_every", 6.0))
		_enemy_wave()
	_count_kills()
	_redraw_acc += delta
	if _redraw_acc >= 0.066:  # ~15 Hz is plenty for flags, arcs and the ticket HUD
		_redraw_acc = 0.0
		queue_redraw()
		_hud.queue_redraw()


func _capture(delta: float) -> void:
	for p in points:
		var allies := 0
		var foes := 0
		if map.player.position.distance_to(p["pos"]) < CAP_R:
			allies += 2
		for a in map.allies():
			if is_instance_valid(a) and a.position.distance_to(p["pos"]) < CAP_R:
				allies += 1
		for e in map.enemies:
			if is_instance_valid(e) and e._alive and e.position.distance_to(p["pos"]) < CAP_R:
				foes += 1
		var rate := delta / CAP_TIME * (1.0 + GameState.bonus("strategist", "capture_speed"))
		if allies > 0 and foes == 0:
			p["prog"] = minf(1.0, float(p["prog"]) + rate * (1.0 + 0.25 * (allies - 1)))
		elif foes > 0 and allies == 0:
			p["prog"] = maxf(-1.0, float(p["prog"]) - rate * (1.0 + 0.25 * (foes - 1)) * (0.5 if bool(p.get("fort", false)) else 1.0))
		var was := str(p["owner"])
		if float(p["prog"]) >= 1.0:
			if str(p["owner"]) != "ally":
				GameState.add_arc_xp(10)
				GameState.add_xp("leadership", 6)
				GameState.add_xp("strategist", 20)
			p["owner"] = "ally"
		elif float(p["prog"]) <= -1.0:
			p["owner"] = "enemy"
		elif (absf(float(p["prog"])) < 0.05 or (was == "ally" and float(p["prog"]) < 0.0)) and was != "neutral":
			p["owner"] = "neutral"
			if str(p["spawner"]) != "":
				p["spawner"] = ""
				# Whatever it built goes down with it (turrets included).
				for mm in p["made"]:
					if is_instance_valid(mm):
						(mm as Node).queue_free()
				p["made"] = []
				p["lvl"] = 1
				p["fort"] = false
				map.hud.toast("The spawner at %s was knocked out." % str(p["name"]), Color(1, 0.7, 0.6))
		if str(p["owner"]) != was:
			if str(p["owner"]) == "ally":
				map.hud.toast("%s is ours." % str(p["name"]), Color(0.6, 1, 0.7))
				_caps += 1
				map.fx("levelup", p["pos"] + Vector2(0, -10), 10.0, 0.6)
				Music.instance(get_tree()).sfx("coin", "pickup")  # many per battle: keep levelup for real level-ups
			elif str(p["owner"]) == "enemy":
				map.hud.toast("We lost %s." % str(p["name"]), Color(1, 0.6, 0.5))
				Music.instance(get_tree()).sfx("alert", "thud")


func _tick() -> void:
	var a := _owned("ally")
	var e := _owned("enemy")
	# Supply trickles in (fractions carry over, so small skill bonuses count).
	var rate := minf(1.0, GameState.bonus(GameState.arc_skill(), "supply_rate") + GameState.bonus("strategist", "supply_rate"))
	_sup_f += a * int(d.get("supply_per_point", 2)) * 0.35 * (1.0 + rate)
	supply += int(_sup_f)
	_sup_f -= int(_sup_f)
	_mend_cd = maxf(0.0, _mend_cd - 1.0)
	_barrage_cd = maxf(0.0, _barrage_cd - 1.0)
	# Bleed: whoever holds fewer points loses tickets every second, faster the worse it is.
	if a > e:
		_bleed_e += (a - e) * (1.0 + GameState.bonus("strategist", "ticket_bleed"))
		tickets["enemy"] = int(tickets["enemy"]) - int(_bleed_e)
		_bleed_e -= int(_bleed_e)
	elif e > a:
		_bleed_a += (e - a) * (1.0 - GameState.bonus("strategist", "ticket_guard"))
		tickets["ally"] = int(tickets["ally"]) - int(_bleed_a)
		_bleed_a -= int(_bleed_a)
	# Upkeep: every unit in the field costs a little supply.
	var units := 0
	for pp in points:
		units += (pp["made"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x)).size()
	_upkeep += units * 0.2
	_rate = a * int(d.get("supply_per_point", 2)) * 0.35 * (1.0 + rate) - units * 0.2
	var broke := supply < int(_upkeep) and units > 0
	supply = maxi(0, supply - int(_upkeep))
	_upkeep -= int(_upkeep)
	# Spawners turn out helpers.
	for p in points:
		if broke or str(p["owner"]) != "ally" or str(p["spawner"]) == "":
			continue  # (broke: can't pay the troops, no new ones this second)
		p["made"] = (p["made"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
		p["t"] = float(p["t"]) + 1.0
		var plv := int(p.get("lvl", 1))
		if float(p["t"]) >= 12.0 - 3.0 * (plv - 1) and (p["made"] as Array).size() < (mini(2, plv) if str(p["spawner"]) == "turret" else MAX_PER_SPAWNER + plv - 1):
			p["t"] = 0.0
			if str(p["spawner"]) == "turret":
				var it: Dictionary = GameState.items.get("guard_bot", {"life": 60, "dmg": 4, "reach": 90})
				var b := Bot.deploy(map, "guard_bot", it, true)
				b.position = p["pos"] + Vector2(randf_range(-20, 20), randf_range(-14, 14))
				b.life = 45.0  # a turret runs 45 seconds, then the point builds a new one
				(p["made"] as Array).append(b)
			else:
				var h := HelperUnit.make(map, str(p["spawner"]), p["pos"] + Vector2(randf_range(-16, 16), 10), p["pos"])
				(p["made"] as Array).append(h)
	# Halfway through their tickets, their commander takes the field.
	if not _boss_out and d.has("boss") and int(tickets["enemy"]) < int(d.get("tickets", 150)) / 2:
		_boss_out = true
		var at: Vector2 = map.player.position + Vector2(0, -90)
		for p in points:
			if str(p["owner"]) == "enemy":
				at = p["pos"]
				break
		var bk := str(d["boss"])
		if GameState.run["flags"].has(bk):
			bk = "thug_enforcer"  # a beaten lieutenant doesn't come back for the rematch
		var bb := map.spawn_enemy(bk, at, clampi(GameState.progress_tier() + 1, 0, 5))
		if bb:
			bb.set_meta("boss_name", bb.display_name())
			# The commander is a real fight: half again as tough.
			bb.max_hp = maxi(int(bb.max_hp * 1.5), int(120 * (1 + GameState.progress_tier()) * (0.6 if Settings.easy() else 1.0)))
			bb.hp = bb.max_hp
			map.hud.toast("%s takes the field!" % bb.display_name(), Color(1, 0.6, 0.4))
			map.shake(3.0)
	if int(tickets["enemy"]) <= 0 or e == 0 and a == points.size():
		_end(true)
	elif int(tickets["ally"]) <= 0:
		_end(false)


func _enemy_wave() -> void:
	var cap := int(d.get("enemy_cap", 14))
	var alive := 0
	for e in map.enemies:
		if is_instance_valid(e) and e._alive:
			alive += 1
	var kinds: Array = d.get("enemies", ["grump"])
	for p in points:
		if alive >= cap:
			break
		if str(p["owner"]) != "enemy":
			continue
		# No spawn-camping: a point you're standing on (or taking) gets no fresh foes.
		if map.player.position.distance_to(p["pos"]) < CAP_R * 1.5 or float(p.get("prog", -1.0)) > -0.99:
			continue
		var kind := str(kinds[randi() % kinds.size()])
		var e := map.spawn_enemy(kind, p["pos"] + Vector2(randf_range(-24, 24), randf_range(-24, 24)), clampi(GameState.progress_tier() + int(d.get("tier_bonus", 0)), 0, 5))
		if e:
			if e._gift:
				e._gift.queue_free()
				e._gift = null
			e.reward = maxi(1, e.reward / 2)
			alive += 1
	# Orders: the enemy commander picks one target every 25 s and sends a squad;
	# the rest hold the points they own, a couple of defenders each.
	_order_t -= float(d.get("wave_every", 6.0))
	if _order_t <= 0.0 or _target_pt.is_empty() or str(_target_pt.get("owner", "")) == "enemy":
		_order_t = 25.0
		var bestp: Dictionary = {}
		var bs := -1e9
		for p in points:
			if str(p["owner"]) == "enemy" and float(p["prog"]) <= -0.99:
				continue
			var defenders := 0
			for h in map.get_tree().get_nodes_in_group("allies"):
				if is_instance_valid(h) and (h as Node2D).position.distance_to(p["pos"]) < 80.0:
					defenders += 1
			# Weak, valuable (has a spawner) and recently lost points first.
			var sc := 10.0 - defenders * 3.0 + (6.0 if str(p["spawner"]) != "" else 0.0) + (8.0 if str(p["owner"]) == "neutral" else 0.0) + randf() * 3.0
			if sc > bs:
				bs = sc
				bestp = p
		if not bestp.is_empty() and bestp != _target_pt:
			_target_pt = bestp
			if str(bestp["owner"]) == "ally":
				map.hud.toast("They're massing on %s!" % str(bestp["name"]), Color(1, 0.6, 0.45))
	var held: Array = points.filter(func(p: Dictionary) -> bool: return str(p["owner"]) == "enemy")
	var guards := {}
	for e in map.enemies:
		if not is_instance_valid(e) or not e._alive:
			continue
		var best: Variant = null
		# Up to two defenders stay on each point they hold (the nearest ones).
		for hp_ in held:
			var key := str(hp_["id"])
			if int(guards.get(key, 0)) < 2 and e.position.distance_to(hp_["pos"]) < 90.0:
				guards[key] = int(guards.get(key, 0)) + 1
				best = hp_["pos"]
				break
		if best == null and not _target_pt.is_empty():
			best = _target_pt["pos"]
		if best != null:
			e.set_meta("goal", best)


func _count_kills() -> void:
	for e in map.enemies:
		if is_instance_valid(e):
			_known[e.get_instance_id()] = e
	for k in _known.keys():
		var e: Variant = _known[k]
		if not is_instance_valid(e) or not (e as Enemy)._alive:
			_known.erase(k)
			if is_instance_valid(e) and ((e as Enemy).has_meta("decoy") or (e as Enemy).has_meta("minion")):
				continue  # a mirror's reflection or a summoned minion is no real kill
			var was_boss: bool = is_instance_valid(e) and (e as Enemy).has_meta("boss_name")
			tickets["enemy"] = int(tickets["enemy"]) - (30 if was_boss else 1)
			_kills += 1
			GameState.add_xp("strategist", 15 if was_boss else 1)
			if was_boss:
				map.hud.toast("Their commander is down! Rout!", Color(1, 0.9, 0.4))


func _disc(n: int) -> int:
	return maxi(1, int(round(n * (1.0 - GameState.bonus("strategist", "spawner_discount")))))


## USE on a point's banner: build (or change) its spawner.
func interact(id: String) -> void:
	var p := point(id)
	if p.is_empty():
		return
	if str(p["owner"]) != "ally":
		map.hud.toast("Take %s first: stand in the ring with no foes on it." % str(p["name"]), Color(1, 0.85, 0.6))
		return
	var crystal := GameState.is_penguins()
	var opts: Array = []
	var keys: Array = []
	var lvl := int(p.get("lvl", 1))
	if str(p["spawner"]) != "" and lvl < 3:
		opts.append("Upgrade to level %d (◇%d): more units, faster" % [lvl + 1, _disc(30 * lvl)])
		keys.append("upgrade")
	if not bool(p.get("fort", false)):
		opts.append("Fortify (◇%d): they take it 50%% slower" % _disc(40))
		keys.append("fortify")
	opts.append("Mend pulse (◇%d): heal you and helpers near you%s" % [_disc(25), (" (ready in %ds)" % int(ceil(_mend_cd))) if _mend_cd > 0.0 else ""])
	keys.append("mend")
	opts.append("Barrage (◇%d): stun every foe near this point%s" % [_disc(35), (" (ready in %ds)" % int(ceil(_barrage_cd))) if _barrage_cd > 0.0 else ""])
	keys.append("barrage")
	# Spawners after the point actions (the list scrolls; B leaves).
	for k in ["striker", "healer", "warden", "shade"]:
		opts.append("%s (◇%d): %s" % [str(HelperUnit.KINDS[k]["crystal" if crystal else "drone"]), _cost(k), {"striker": "zaps foes", "healer": "mends you", "warden": "shields you", "shade": "hides you"}[k]])
		keys.append(k)
	opts.append("%s (◇%d): holds the point" % ["Crystal Pylon" if crystal else "Gun Turret", _cost("turret")])
	keys.append("turret")
	var extra_cost := {"upgrade": 30 * lvl, "fortify": 40, "mend": 25, "barrage": 35}
	for oi in opts.size():
		var kk: String = keys[oi]
		var cc := _cost(kk) if SPAWNER_COST.has(kk) else (_disc(int(extra_cost[kk])) if extra_cost.has(kk) else 0)
		if cc > supply:
			opts[oi] = "✕ " + str(opts[oi])
	var sp := str(p["spawner"])
	var now_nm := ""
	if sp == "turret":
		now_nm = "Crystal Pylon" if crystal else "Gun Turret"
	elif sp != "":
		now_nm = str(HelperUnit.KINDS[sp]["crystal" if crystal else "drone"])
	var dl := Dialogue.instance(get_tree())
	dl.say([{"who": str(p["name"]), "text": "Supply ◇%d.%s %s:" % [supply, (" Now: %s." % now_nm) if now_nm != "" else "", ("Change the %s" if sp != "" else "Build a %s here") % ("crystal spire" if crystal else "drone bay")], "choice": opts, "key": ""}])
	await dl.finished
	var i := dl.last_choice
	if i < 0 or i >= keys.size():
		return
	var k: String = keys[i]
	var extra := {"upgrade": 30 * int(p.get("lvl", 1)), "fortify": 40, "mend": 25, "barrage": 35}
	if (k == "mend" and _mend_cd > 0.0) or (k == "barrage" and _barrage_cd > 0.0):
		map.hud.toast("Not ready yet.", Color(1, 0.8, 0.6))
		return
	if extra.has(k):
		var c := _disc(int(extra[k]))
		if supply < c:
			map.hud.toast("Not enough supply. Hold more points.", Color(1, 0.7, 0.6))
			return
		supply -= c
		GameState.add_xp("strategist", 5)
		match k:
			"upgrade":
				p["lvl"] = int(p.get("lvl", 1)) + 1
				map.hud.toast("%s upgraded to level %d." % [str(p["name"]), int(p["lvl"])], Color(0.7, 1, 0.8))
			"fortify":
				p["fort"] = true
				map.hud.toast("%s fortified." % str(p["name"]), Color(0.7, 1, 0.8))
			"mend":
				GameState.heal_points(40)
				for h in map.get_tree().get_nodes_in_group("allies"):
					if h is HelperUnit and (h as Node2D).position.distance_to(map.player.position) < 120.0:
						(h as HelperUnit).hp = (h as HelperUnit).max_hp
				map.fx("heal", map.player.position + Vector2(0, -10), 10.0, 0.6)
				map.hud.toast("Mend pulse!", Color(0.7, 1, 0.8))
				_mend_cd = 20.0
			"barrage":
				var n := 0
				for e in map.enemies:
					if is_instance_valid(e) and e.position.distance_to(p["pos"]) < 110.0:
						e._stun = maxf(e._stun, 1.0 if e.has_meta("boss_name") else 3.0)
						n += 1
				map.shake(3.0)
				map.hud.toast("Barrage! %d foes stunned." % n, Color(1, 0.9, 0.5))
				_barrage_cd = 25.0
		return
	if k == str(p["spawner"]):
		map.hud.toast("%s already builds that." % str(p["name"]), Color(1, 0.85, 0.6))
		return
	if supply < _cost(k):
		map.hud.toast("Not enough supply. Hold more points.", Color(1, 0.7, 0.6))
		return
	supply -= _cost(k)
	GameState.add_xp("strategist", 5)
	GameState.add_xp("leadership", 8)
	# Switching type: the old units stand down, so the new spawner can start at once.
	for mm in p["made"]:
		if is_instance_valid(mm):
			(mm as Node).queue_free()
	p["made"] = []
	p["spawner"] = k
	p["t"] = 10.0
	map.fx("sparkle", p["pos"] + Vector2(0, -12), 12.0, 0.6)
	map.hud.toast("Built at %s." % str(p["name"]), Color(0.7, 1, 0.8))


func _end(won: bool, travel := true) -> void:
	_over = true
	# A full campaign is what trains a Strategist (more for a win, something for a loss).
	var rematch: bool = GameState.run["flags"].has("battle_" + bid)
	GameState.add_xp("strategist", (120 if rematch else 400) if won else mini(120, 20 * _caps + _kills))
	Music.instance(get_tree()).sfx("quest_done" if won else "die", "levelup")
	if won:
		GameState.add_arc_xp(25 if rematch else 80)
	for e in map.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	map.enemies.clear()
	for h in get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit:
			h.queue_free()
	if not travel:
		return
	var key := "battle_" + bid
	if won:
		var first: bool = not GameState.run["flags"].has(key)
		GameState.run["flags"][key] = true
		var rw: Dictionary = d.get("reward", {})
		# Rematches pay a third, and only once a day per field (no endless purse farming).
		var paid_today: bool = not first and int(GameState.run["flags"].get("bfpay_" + bid, -1)) == int(GameState.run["day"])
		GameState.run["flags"]["bfpay_" + bid] = int(GameState.run["day"])
		var cr := 0 if paid_today else int(rw.get("crystals", 300)) / (1 if first else 3)
		GameState.run["crystals"] = int(GameState.run["crystals"]) + cr
		for it in rw.get("items", {}):
			if first:
				if str(GameState.items.get(str(it), {}).get("type", "")) == "tool":
					GameState.add_tool(str(it))
				else:
					GameState.add_item(str(it), int(rw["items"][it]))
		map.xp("combat", 60 if first else 20)
		await map.say([{"who": _who(), "text": str(d.get("win", "The field is ours.")) + ("" if first else (" (You've been paid for this field today.)" if paid_today else " (A rematch pays less.)"))}, {"text": "+◆%d%s" % [cr, (", " + ", ".join((rw.get("items", {}) as Dictionary).keys().map(func(x: Variant) -> String: return GameState.item_name(str(x))))) if first and not (rw.get("items", {}) as Dictionary).is_empty() else ""]}])
	else:
		await map.say([{"who": _who(), "text": str(d.get("lose", "Fall back. We'll come back stronger."))}])
	GameState.save()
	var back: Array = d.get("back", ["town", 0, 0])
	map.go_to(str(back[0]), Vector2(float(back[1]) * GameMap.TILE, float(back[2]) * GameMap.TILE) if int(back[1]) > 0 else Vector2.ZERO, "down")


# ---- drawing -----------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Only points near the screen (this one canvas item spans the whole field, so
	# nothing culls its commands), rings first and pictures after: an antialiased
	# arc is three draw calls, so the old order cost ~32 per frame on bf maps.
	var view := ((get_viewport().get_canvas_transform() * get_global_transform()).affine_inverse() * get_viewport_rect()).grow(CAP_R + 48.0)
	for p in points:
		var pos: Vector2 = p["pos"]
		if not view.has_point(pos):
			continue
		var col := Color(0.5, 0.9, 1.0) if str(p["owner"]) == "ally" else (Color(1, 0.45, 0.4) if str(p["owner"]) == "enemy" else Color(0.85, 0.85, 0.85))
		draw_arc(pos, CAP_R, 0, TAU, 48, Color(col.r, col.g, col.b, 0.35 + 0.1 * sin(t * 2.0)), 1.5, true)
		var pr := float(p["prog"])
		if absf(pr) > 0.01:
			draw_arc(pos, CAP_R - 3, -PI / 2, -PI / 2 + TAU * absf(pr), 48, Color(0.5, 0.9, 1.0) if pr > 0 else Color(1, 0.45, 0.4), 3.0, true)
	for p in points:
		var pos: Vector2 = p["pos"]
		if not view.has_point(pos):
			continue
		var col := Color(0.5, 0.9, 1.0) if str(p["owner"]) == "ally" else (Color(1, 0.45, 0.4) if str(p["owner"]) == "enemy" else Color(0.85, 0.85, 0.85))
		# The structure built here (spire / drone bay / pylon / turret), behind the flag.
		var spn := str(p["spawner"])
		if spn != "":
			var crystal := GameState.is_penguins()
			var nm := ("pylon" if crystal else "turret") if spn == "turret" else (("spire_%d" if crystal else "bay_%d") % (3 if float(p.get("t", 0.0)) < 6.0 else 2))
			var st := Art.tex("battle", nm)
			if st:
				var w := 34.0 if spn != "turret" else 18.0
				var h := w * st.get_height() / st.get_width()
				draw_texture_rect(st, Rect2(pos + Vector2(-w - 2, 6 - h), Vector2(w, h)), false)
			else:
				draw_circle(pos + Vector2(-10, -6), 4.0, Color(col.r, col.g, col.b, 0.8))
		# Banner: the painted flag in its side's colours, waving.
		var side := str(p["owner"])
		var ft := Art.tex("battle", "flag_%s_%d" % [side, int(t * 6.0 + pos.x) % 4])
		if ft:
			var fh := 30.0
			draw_texture_rect(ft, Rect2(pos + Vector2(-fh * ft.get_width() / ft.get_height() * 0.3, 4 - fh), Vector2(fh * ft.get_width() / ft.get_height(), fh)), false)
		else:
			draw_line(pos + Vector2(0, 2), pos + Vector2(0, -26), Color(0.25, 0.2, 0.15), 2.0)
			var wave := sin(t * 4.0 + pos.x) * 2.0
			draw_colored_polygon(PackedVector2Array([pos + Vector2(1, -26), pos + Vector2(14, -22 + wave), pos + Vector2(1, -17)]), col)


func _draw_hud() -> void:
	var f := ThemeDB.fallback_font
	var txt := []  # [pos, text, align, width, size, colour]: drawn at the end, all outlines then all fills
	var y := 104.0
	var bw := 90.0
	var ta := clampf(float(tickets["ally"]) / float(d.get("tickets", 150)), 0, 1)
	var te := clampf(float(tickets["enemy"]) / float(d.get("tickets", 150)), 0, 1)
	_hud.draw_rect(Rect2(10, y, bw, 5), Color(0, 0, 0, 0.6))
	_hud.draw_rect(Rect2(10, y, bw * ta, 5), Color(0.5, 0.9, 1.0))
	_hud.draw_rect(Rect2(170, y, bw, 5), Color(0, 0, 0, 0.6))
	_hud.draw_rect(Rect2(170 + bw * (1.0 - te), y, bw * te, 5), Color(1, 0.45, 0.4))
	txt.append([Vector2(10, y + 13), "Us %d" % int(tickets["ally"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.8, 0.95, 1)])
	txt.append([Vector2(220, y + 13), "Them %d" % int(tickets["enemy"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.8, 0.75)])
	# Point pips, left to right in data order, with an arrow toward the nearest one you don't hold.
	var x0 := 135.0 - points.size() * 7.0
	for i in points.size():
		var p: Dictionary = points[i]
		var col := Color(0.5, 0.9, 1.0) if str(p["owner"]) == "ally" else (Color(1, 0.45, 0.4) if str(p["owner"]) == "enemy" else Color(0.8, 0.8, 0.8))
		Art.draw_disc(_hud, Vector2(x0 + i * 14 + 7, y + 3), 5.0, Color(0, 0, 0, 0.6))
		Art.draw_disc(_hud, Vector2(x0 + i * 14 + 7, y + 3), 4.0, col)
	for i in points.size():
		_hud.draw_string(f, Vector2(x0 + i * 14 + 4, y + 6), str(points[i]["id"]).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.1, 0.1, 0.1))
	# Who is bleeding tickets (the side holding fewer points), and supply income.
	var oa := _owned("ally")
	var oe := _owned("enemy")
	if oe > oa:
		txt.append([Vector2(42, y + 13), "-%d/s" % (oe - oa), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.5, 0.4)])
	elif oa > oe:
		txt.append([Vector2(196, y + 13), "-%d/s" % (oa - oe), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 1, 0.7)])
	var stxt := "Supply ◇%d (%+.1f/s)" % [supply, _rate]
	txt.append([Vector2(92, y + 20), stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.95, 0.7)])
	# Off-screen pointer to the nearest point you don't hold.
	var cam := map.get_viewport().get_camera_2d()
	if cam != null:
		_hud_pointer(txt)
	for pass_i in 2:
		for e: Array in txt:
			if pass_i == 0:
				_hud.draw_string_outline(f, e[0], e[1], e[2], e[3], e[4], 3, Color(0, 0, 0, 0.8))
			else:
				_hud.draw_string(f, e[0], e[1], e[2], e[3], e[4], e[5])


## Off-screen pointer to the nearest point you don't hold (its name goes in txt).
func _hud_pointer(txt: Array) -> void:
	var best: Variant = null
	var bd := 1e9
	for p in points:
		if str(p["owner"]) == "ally":
			continue
		var dd: float = map.player.position.distance_to(p["pos"])
		if dd < bd:
			bd = dd
			best = p
	if best != null and bd > 140.0:
		var dir: Vector2 = ((best as Dictionary)["pos"] - map.player.position).normalized()
		var c := Vector2(135, 260) + dir * 110.0
		_hud.draw_colored_polygon(PackedVector2Array([c + dir * 8, c + dir.orthogonal() * 5, c - dir.orthogonal() * 5]), Color(1, 0.9, 0.5, 0.9))
		txt.append([c + Vector2(-20, 14), str((best as Dictionary)["name"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 6, Color(1, 0.95, 0.8)])
