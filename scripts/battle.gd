class_name Battle
extends Node2D
## Conquest battles (data/regions.json "battle"): a huge map with control points.
## Stand on a point with no foes on it and the ring fills; hold it and it's
## yours. Each side has tickets: the side holding fewer points bleeds them, and
## every fallen foe costs the enemy one. Points you hold earn supply; spend it on
## a spawner at a point (USE on its banner) and it turns out helper units:
## crystals (penguins) or drones (gangsters): strikers, healers, wardens, shades.
## Take every point or run their tickets out to win.
## Campaign fights (Campaign.fight_for) reshape the field per node: mode
## skirmish / siege (their points fortified) / escort (walk a convoy to its goal)
## / defend (hold out against gates that can't be taken) / boss / gate, with the
## army's morale setting your tickets and its supply your starting purse.

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
# Campaign node (empty for a war-table battle).
var camp := ""
var mode := ""
var win_by := ""
var _t_max := {"ally": 150, "enemy": 150}
var _hold := 0.0
var _elapsed := 0.0
var _boss_down := false
var _boss_ref: Enemy = null
var _boss_t := 0.0       # seconds the commander has been on the field (it pushes after BOSS_PUSH)
const BOSS_PUSH := 20.0
var convoy: CampaignConvoy = null
var drill: BattleDrill = null   # the training drill (CampaignGate), else null
var is_drill := false
var _briefing := false   # the briefing card is up: no waves, clocks wait
var _wave_n := 0         # waves sent (every SQUAD_EVERY-th one is a squad)
var team: Array = []     # the mustered allies on the field (HelperUnit)
var _guest := false      # started as a co-op guest: being sent home is no retreat
const BattleTurretS := preload("res://scripts/battle_turret.gd")
const SQUAD_EVERY := 4
const TEAM_MAX := 4      # mustered allies who take the field at once


static func start(m: GameMap, region_id: String, data: Dictionary) -> Battle:
	var b := Battle.new()
	Music.instance(m.get_tree()).sfx("j_battle_start", "alert")
	b.map = m
	b.bid = region_id
	b.d = data
	b.z_index = 1
	m.add_child(b)
	m.set("battle", b)  # (region.gd assigns it too) so area_track sees the fight's mode now
	b._setup()
	# The fight's own song from the first frame (siege/escort moods), not ~3 s later.
	Music.instance(m.get_tree()).play(m.area_track(), 0.3)
	return b



## Who speaks the brief / win / lose lines: a crew member only once recruited.
func _who() -> String:
	if camp != "":
		return Campaign.who(camp)  # per-campaign leader, always someone you've met (P1 hook)
	var w := str(d.get("who", ""))
	var id := w.to_lower().replace(" ", "_")
	# A field's speaker from the other arc (Catkins in a gangster run) narrates instead (C9 c9_14).
	if not Hearts.in_arc(id) or (id == "catkins" and not GameState.is_penguins()):
		return ""
	return w if not Crew.members().has(id) or Crew.recruited(id) else ""

func _setup() -> void:
	var cf := Campaign.fight_for(bid)
	var df := CampaignGate.drill_for(bid)
	if not cf.is_empty():
		d = Campaign.battle_data(d, cf)
		camp = str(cf["cid"])
	elif not df.is_empty():
		d = CampaignGate.drill_data(d, df)
		is_drill = true
		d["win_by"] = "drill"
	mode = str(d.get("mode", ""))
	win_by = str(d.get("win_by", ""))
	var t := int(d.get("tickets", 150))
	tickets = {"ally": t, "enemy": int(d.get("enemy_tickets", t))}
	_t_max = {"ally": int(d.get("tickets_max", t)), "enemy": int(tickets["enemy"])}
	_hold = float(d.get("hold", 0))
	supply = int(d.get("supply", 10)) + int(GameState.bonus("strategist", "start_supply"))
	for p in d.get("points", []):
		var c := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		var pt := {"id": str(p["id"]), "name": str(p["name"]), "cell": c, "pos": map.cell_center(c), "owner": str(p.get("owner", "neutral")), "prog": 0.0, "spawner": "", "made": [], "t": 0.0,
			"gate": bool(p.get("gate", false)), "efort": bool(p.get("efort", false))}
		pt["prog"] = 1.0 if pt["owner"] == "ally" else (-1.0 if pt["owner"] == "enemy" else 0.0)
		points.append(pt)
		map.set_thing(c.x, c.y, {"type": "cpoint", "id": pt["id"], "hint": "A: %s" % pt["name"]}, true)
	if camp != "" or is_drill:
		_campaign_setup()
	if camp != "":
		_resume(cf)
		map.later(_field_team)
	_guest = Net.visiting()
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
	_rally_btn.expand_icon = true
	_rally_btn.add_theme_constant_override("icon_max_width", 14)
	_rally_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rally_btn.clip_text = true
	_rally_btn.pressed.connect(func() -> void: map.later(_pick_rally))
	layer.add_child(_rally_btn)
	Hud.extra_rects.append(RALLY_RECT)
	_set_rally(-2, true)
	if is_drill:
		drill = BattleDrill.attach(self, layer)
	if camp != "" or is_drill:
		# Campaign fights and the drill open with a briefing card (objective, how to win, controls).
		var bd := d.duplicate()
		bd["who"] = _who()
		_briefing = true
		map.later(func() -> void:
			await BattleBrief.show_for(map, bd)
			_briefing = false
			_spawn_t = minf(_spawn_t, 2.0))  # first wave about 2 s after the card goes
	else:
		map.hud.toast("%s. Take the points. Hold more than they do." % str(d.get("title", "Battle")), Color(1, 0.9, 0.6))
		map.later(func() -> void:
			await map.say([{"who": _who(), "text": str(d.get("brief", "Every point you hold earns supply. Build at a point you hold to make helpers."))}]))


const RALLY_RECT := Rect2(8, 146, 124, 21)   # >= 20 px tall: a comfortable tap
var _rally_btn: Button
var _rally := -1
var _rally_flash := 0.0
var _rally_given := false
var _push_said := false


## "RALLY", plus the key/button when the touch pad is hidden ("RALLY (L3)").
func _rally_word() -> String:
	return "RALLY" if TouchControls.visible_controls else "RALLY (%s)" % InputSetup.prompt("rally")


## Rally from keys/pad (C9): a tap of the rally action cycles guard -> follow ->
## each point; holding it RALLY_HOLD s opens the picker list.
const RALLY_HOLD := 0.35
var _rally_hold := -1.0


func _rally_input(delta: float) -> void:
	if not InputMap.has_action("rally"):
		return
	if Input.is_action_just_pressed("rally") and not Dialogue.input_blocked():
		_rally_hold = 0.0
	elif _rally_hold >= 0.0 and Input.is_action_pressed("rally"):
		_rally_hold += delta
		if _rally_hold >= RALLY_HOLD:
			_rally_hold = -1.0
			map.later(_pick_rally)
	elif _rally_hold >= 0.0:
		_rally_hold = -1.0
		_cycle_rally()


## Cycle: guard posts → follow me → each point in turn → guard posts.
func _cycle_rally() -> void:
	var i := _rally + 1
	if i >= points.size():
		i = -2
	_set_rally(i)
	_rally_sfx(i)


## One tap: pick where the helpers go from a list (instead of cycling through every point).
func _pick_rally() -> void:
	var o: Array = ["%sGuard posts: each holds the point that built it" % ("▸ " if _rally == -2 else ""), "%sFollow me: they walk with you" % ("▸ " if _rally == -1 else "")]
	for i in points.size():
		var p: Dictionary = points[i]
		o.append("%sSend to %s %s (%s)" % ["▸ " if _rally == i else "", str(p["id"]).to_upper(), str(p["name"]), {"ally": "ours", "enemy": "theirs", "neutral": "open"}.get(str(p["owner"]), "")])
	o.append("Leave as is")
	var dl := Dialogue.instance(get_tree())
	if _helpers() == 0 and not is_drill:
		dl.say([{"who": "", "text": "No helpers yet. Build at a banner you hold (USE on it) and they'll come.", "choice": ["Leave"], "key": ""}])
		await dl.finished
		return
	dl.say([{"who": "", "text": "Rally %d helper%s:" % [_helpers(), "" if _helpers() == 1 else "s"], "choice": o, "key": ""}])
	await dl.finished
	if dl.last_choice >= 0 and dl.last_choice < o.size() - 1 and not _over:
		_set_rally(dl.last_choice - 2)
		_rally_sfx(dl.last_choice - 2)


## Each rally order has its own call (c6_11): follow me = a whistle, guard = a
## confirm, send to a point = the war drum / horn.
func _rally_sfx(i: int) -> void:
	var mu := Music.instance(map.get_tree())
	if i == -1:
		mu.sfx("whistle", "j_confirm")
	elif i == -2:
		mu.sfx("j_confirm", "pickup")
	else:
		mu.sfx("war_drum", "j_confirm")


## First cue that exists (new sounds land from P3; until then the fallback plays).
static func pick_sfx(mu: Music, names: Array) -> String:
	for n: String in names:
		if mu.has_sfx(n):
			return n
	return str(names[-1])


## A field cue heard only near the player (spawns and deaths across the field stay quiet).
func _near_sfx(at: Vector2, name: String, fallback: String, reach := 220.0) -> void:
	if map == null or map.player == null or map.player.position.distance_to(at) > reach:
		return
	Music.instance(get_tree()).sfx(name, fallback)


func _helpers() -> int:
	var n := 0
	for h in map.get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit and is_instance_valid(h):
			n += 1
	return n


func _set_rally(i: int, quiet := false) -> void:
	_rally = i
	if not quiet:
		_rally_given = true  # your order: the early-fight team push stops
		if map.has_meta("team_push"):
			map.remove_meta("team_push")
	if map.has_meta("follow_me"):
		map.remove_meta("follow_me")
	if i == -1:
		if map.has_meta("rally_pos"):
			map.remove_meta("rally_pos")
		map.set_meta("follow_me", true)
		_rally_btn.text = _rally_word() + ": follow me"
		_rally_btn.icon = Art.tex("ui", "rally_follow")
		_rally_toast("Helpers: on me!")
	elif i < 0:
		if map.has_meta("rally_pos"):
			map.remove_meta("rally_pos")
		_rally_btn.text = _rally_word() + ": guard posts"
		_rally_btn.icon = Art.tex("ui", "rally_guard")
		if not quiet:
			_rally_toast("Helpers: hold your posts.")
	else:
		map.set_meta("rally_pos", points[i]["pos"])
		_rally_btn.text = "%s ▸ %s" % [_rally_word(), str(points[i]["name"])]
		_rally_btn.icon = Art.tex("ui", "rally_send")
		_rally_toast("Helpers: everyone to %s!" % str(points[i]["name"]))
	_rally_flash = 1.0


## A new rally order replaces the last one's toast instead of stacking under it.
func _rally_toast(text: String) -> void:
	var box: Variant = map.hud.get("_toasts")
	if box is Node:
		for c in (box as Node).get_children():
			if c is Label and c.has_meta("base") and str(c.get_meta("base")).begins_with("Helpers:") and str(c.get_meta("base")) != text:
				c.queue_free()
	map.hud.toast(text, Color(0.7, 0.95, 1.0))


func _exit_tree() -> void:
	if camp != "" and not _over and not _guest and not Net.visiting():
		Campaign.retreat(supply)  # walked off the field mid-fight
		# Say what the retreat cost once the next map is up (c6_11).
		var tree := get_tree()
		if tree:
			tree.create_timer(1.2).timeout.connect(func() -> void:
				var nm := tree.current_scene as GameMap
				if nm and is_instance_valid(nm) and nm.hud:
					nm.hud.toast("You fell back from the field: morale -15, most supply lost.", Color(1, 0.7, 0.6))
					Music.instance(tree).sfx("j_battle_lost", "nope"))
	elif is_drill and not _over:
		CampaignGate.drill_quit()
	Hud.extra_rects.erase(RALLY_RECT)
	if map and is_instance_valid(map) and map.has_meta("rally_pos"):
		map.remove_meta("rally_pos")
	if map and is_instance_valid(map) and map.has_meta("team_push"):
		map.remove_meta("team_push")


var _mass_ms := -100000
var _bleed_e := 0.0
var _rate := 0.0   # supply per second after upkeep (HUD)
var _bleed_a := 0.0


func _cost(k: String) -> int:
	var base := int(SPAWNER_COST[k]) if SPAWNER_COST.has(k) else int(HelperUnit.kinds().get(k, {}).get("cost", 20))
	return maxi(1, int(round(base * (1.0 - GameState.bonus("strategist", "spawner_discount")))))


## The helper kinds this run can build at a spawner: the four built-ins, then
## data kinds (battles.json "_helper_kinds") whose "arc" matches and whose
## "flag" (if any) is set: e.g. Crystal Kin once the penguins befriend them.
static func spawner_kinds() -> Array:
	var out: Array = ["striker", "healer", "warden", "shade"]
	var all := HelperUnit.kinds()
	for k: String in all:
		if k in out:
			continue
		var kd: Dictionary = all[k]
		var arc := str(kd.get("arc", ""))
		if arc != "" and arc != str(GameState.run.get("arc", "")):
			continue
		var fl := str(kd.get("flag", ""))
		if fl != "" and not GameState.run.get("flags", {}).has(fl):
			continue
		out.append(k)
	return out


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
	if _over or get_tree().paused or map.player == null or _briefing:
		return
	_capture(delta)
	_rally_input(delta)
	_sec += delta
	if _sec >= 1.0:
		_sec = 0.0
		_tick()
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = float(d.get("wave_every", 6.0))
		_enemy_wave()
	_count_kills()
	_rally_flash = maxf(0.0, _rally_flash - delta)
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
		p["near_a"] = allies
		if bool(p.get("gate", false)):
			continue  # an enemy gate: it can't be taken, only held off
		var rate := delta / CAP_TIME * (1.0 + GameState.bonus("strategist", "capture_speed"))
		if allies > 0 and foes == 0:
			# A fortified enemy point (siege) turns at half speed until it's broken.
			var fort_k := 0.5 if bool(p.get("efort", false)) and float(p["prog"]) < 0.0 else 1.0
			p["prog"] = minf(1.0, float(p["prog"]) + rate * fort_k * (1.0 + 0.25 * (allies - 1)))
		elif foes > 0 and allies == 0:
			p["prog"] = maxf(-1.0, float(p["prog"]) - rate * (1.0 + 0.25 * (foes - 1)) * (0.5 if bool(p.get("fort", false)) else 1.0) * float(d.get("foe_capture", 1.0)))
		elif allies == 0 and foes == 0 and str(p["owner"]) == "enemy" and float(p["prog"]) > -1.0:
			# Walked off half-taken: their point settles back (and spawns again once full).
			p["prog"] = maxf(-1.0, float(p["prog"]) - rate * 0.5)
		var was := str(p["owner"])
		if float(p["prog"]) >= 1.0:
			if str(p["owner"]) != "ally":
				if drill != null:
					drill.xp += 20  # the drill pays its XP in one go at the end (no level-up toasts mid-step)
				else:
					GameState.add_arc_xp(10)
					GameState.add_xp("leadership", 6)
					GameState.add_xp("strategist", 20)
			p["owner"] = "ally"
		elif float(p["prog"]) <= -1.0:
			p["owner"] = "enemy"
		elif (absf(float(p["prog"])) < 0.05 or (was == "ally" and float(p["prog"]) < 0.0)) and was != "neutral":
			p["owner"] = "neutral"
			# Lost: its level and walls go with it, spawner or not.
			p["lvl"] = 1
			p["fort"] = false
			if str(p["spawner"]) != "":
				p["spawner"] = ""
				# Whatever it built goes down with it (turrets included).
				for mm in p["made"]:
					if is_instance_valid(mm):
						(mm as Node).queue_free()
				p["made"] = []
				map.hud.toast("The spawner at %s was knocked out." % str(p["name"]), Color(1, 0.7, 0.6))
				Music.instance(get_tree()).sfx("power_off" if not GameState.is_penguins() else "glass", "thud")
		if str(p["owner"]) != was:
			if str(p["owner"]) == "ally":
				map.hud.toast("%s is ours." % str(p["name"]), Color(0.6, 1, 0.7))
				_caps += 1
				map.fx("levelup", p["pos"] + Vector2(0, -10), 10.0, 0.6)
				Music.instance(get_tree()).sfx("coin", "pickup")  # many per battle: keep levelup for real level-ups
			elif str(p["owner"]) == "enemy":
				map.hud.toast("We lost %s." % str(p["name"]), Color(1, 0.6, 0.5))
				Music.instance(get_tree()).sfx("alert", "thud")
			elif was == "ally" and str(p["owner"]) == "neutral":
				# Knocked to neutral (no spawner to lose): still a loss you should hear.
				map.hud.toast("%s is slipping: retake it!" % str(p["name"]), Color(1, 0.75, 0.55))
				Music.instance(get_tree()).sfx("alert", "thud")


func _tick() -> void:
	var a := _owned("ally")
	var e := _owned("enemy")
	# Supply trickles in (fractions carry over, so small skill bonuses count).
	var rate := minf(1.0, GameState.bonus(GameState.arc_skill(), "supply_rate") + GameState.bonus("strategist", "supply_rate"))
	_sup_f += a * int(d.get("supply_per_point", 2)) * 0.35 * (1.0 + rate) * float(d.get("supply_mul", 1.0))
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
		# (The drill's first helper steps out at once: the next step needs one to follow you.)
		var first := is_drill and (p["made"] as Array).is_empty() and float(p["t"]) >= 10.0
		if (first or float(p["t"]) >= 12.0 - 3.0 * (plv - 1)) and (p["made"] as Array).size() < (mini(2, plv) if str(p["spawner"]) == "turret" else MAX_PER_SPAWNER + plv - 1):
			p["t"] = 0.0
			if str(p["spawner"]) == "turret":
				var it: Dictionary = GameState.items.get("guard_bot", {"life": 60, "dmg": 4, "reach": 90})
				# A turret / pylon runs 45 seconds (then the point builds a new one); it
				# stands with the allies: it holds the ring and foes come to break it.
				var b: Node2D = BattleTurretS.make_at(map, p["pos"] + Vector2(randf_range(-20, 20), randf_range(-14, 14)), it)
				(p["made"] as Array).append(b)
			else:
				var h := HelperUnit.make(map, str(p["spawner"]), p["pos"] + Vector2(randf_range(-16, 16), 10), p["pos"])
				if (p["made"] as Array).is_empty() or randf() < 0.5:
					_near_sfx(p["pos"], "teleport", "pop")  # a helper steps out (craft_done is the player's own Build)
				if bool(d.get("inspired", false)):
					h.max_hp = int(h.max_hp * 1.25)  # an inspired army (campaign morale 85+)
					h.hp = h.max_hp
				(p["made"] as Array).append(h)
	_team_push()
	# Halfway through their tickets, their commander takes the field.
	_elapsed += 1.0
	if _boss_ref != null and is_instance_valid(_boss_ref):
		_boss_t += 1.0
	var boss_now := int(tickets["enemy"]) < int(_t_max["enemy"]) / 2 if str(d.get("boss_at", "half")) == "half" else _elapsed >= 8.0
	if not _boss_out and d.has("boss") and boss_now:
		_boss_out = true
		var at: Vector2 = map.player.position + Vector2(0, -90)
		for p in points:
			if str(p["owner"]) == "enemy":
				at = p["pos"]
				break
		var bk := str(d["boss"])
		if GameState.run["flags"].has(bk):
			bk = "thug_enforcer"  # a beaten lieutenant doesn't come back for the rematch
		var bb := map.spawn_enemy(bk, at, clampi(etier() + 1, 0, 5))
		if bb:
			_boss_ref = bb
			_boss_t = 0.0
			bb.set_meta("boss_name", bb.display_name())
			bb.max_hp = boss_hp(roundi(bb.max_hp / maxf(0.01, bb.diff_hp)), ctier(), GameState.progress_tier(), Difficulty.mul("boss_hp"))  # mode applied once, here
			bb.hp = bb.max_hp
			if _resume_boss_hp > 0:
				bb.hp = mini(bb.max_hp, _resume_boss_hp)
				_resume_boss_hp = -1
			if ctier() <= 1:
				bb.damage = maxi(1, bb.damage - 1)  # a first-campaign captain hits softer
			map.hud.toast("%s takes the field!" % bb.display_name(), Color(1, 0.6, 0.4))
			map.shake(3.0)
			# A full boss theme, the horn, and DangerMusic holds it till the captain falls.
			var bt := map.boss_track(bb.kind)
			var hm := Music.instance(get_tree())
			hm.sfx(pick_sfx(hm, ["war_horn", "j_battle_start"] if GameState.is_penguins() else ["war_horn_gang", "war_horn", "j_battle_start"]), "alert")  # never the bicycle 'horn'
			hm.play(bt, 0.4)
			DangerMusic.boss_started(map, bt)
	if camp != "":
		_keep()
	if int(tickets["ally"]) <= 0:
		_end(false)
		return
	match win_by:
		"hold":
			_hold -= 1.0
			if a == 0:
				_end(false)
			elif _hold <= 0.0:
				_end(true)
		"convoy":
			if convoy == null or not is_instance_valid(convoy) or convoy.hp <= 0:
				map.hud.toast("The convoy is lost!", Color(1, 0.55, 0.45))
				_end(false)
			elif convoy.arrived:
				_end(true)
		"boss":
			if _boss_down or (e == 0 and a == points.size()):
				_end(true)
		"drill":
			pass  # BattleDrill ends it when the last step is done
		_:
			if int(tickets["enemy"]) <= 0 or e == 0 and a == points.size():
				_end(true)


## The campaign's tier (1-5): a war-table field uses its enemy tier + 1.
func ctier() -> int:
	if camp != "":
		return clampi(int(Campaign.get_c(camp).get("tier", etier() + 1)), 1, 5)
	return clampi(etier() + 1, 1, 5)


## The enemy tier on this field: the campaign node's, else your progress + the field's bonus.
func etier() -> int:
	if d.has("enemy_tier"):
		return clampi(int(d["enemy_tier"]), 0, 5)
	return clampi(GameState.progress_tier() + int(d.get("tier_bonus", 0)), 0, 5)


## A commander's health: a bit tougher than its kind, floored by the campaign
## tier (T1 ~60-90, more when you've outgrown the campaign), capped for T1-2
## so a first campaign's captain stays a short fight.
static func boss_hp(base: int, ct: int, pt: int, mode_mul := 1.0) -> int:
	var floor_hp := 60.0 * ct * (1.0 + 0.5 * maxi(0, pt - ct + 1))
	var hp := maxf(base * 1.25, floor_hp)
	if ct <= 2:
		hp = minf(hp, floor_hp * 1.6)
	return maxi(20, int(hp * mode_mul))


func _enemy_wave() -> void:
	if drill != null and not drill.waves_on():
		return
	_wave_n += 1
	var cap := int(d.get("enemy_cap", 14))
	var alive := 0
	for e in map.enemies:
		if is_instance_valid(e) and e._alive:
			alive += 1
	var kinds: Array = d.get("enemies", ["grump"])
	var etr := etier()
	# Each wave leans on one kind (squads look like squads), with the odd other one.
	var lead := str(kinds[randi() % kinds.size()])
	for p in points:
		if alive >= cap:
			break
		if str(p["owner"]) != "enemy":
			continue
		var at: Vector2 = p["pos"] + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		if bool(p.get("gate", false)):
			# A gate can't be camped shut: it pours out at the ring's far side from you.
			var away: Vector2 = (p["pos"] - map.player.position).normalized()
			if away == Vector2.ZERO:
				away = Vector2.UP
			at = HelperUnit.free_spot(map, p["pos"] + away * CAP_R * 0.9)
		else:
			# No spawn-camping: a point you (or your helpers) stand on, or are taking, gets no fresh foes.
			if map.player.position.distance_to(p["pos"]) < CAP_R * 1.5 or int(p.get("near_a", 0)) > 0 or float(p.get("prog", -1.0)) > -0.99:
				continue
		var kind := lead if randf() < 0.7 else str(kinds[randi() % kinds.size()])
		if _spawn_foe(kind, at, etr):
			alive += 1
	# Every few waves the commander sends a squad of three straight at its target.
	if _wave_n % SQUAD_EVERY == 0 and not _target_pt.is_empty():
		var src: Variant = null
		var sd := 1e9
		for p in points:
			if str(p["owner"]) == "enemy" and int(p.get("near_a", 0)) == 0:
				var dd: float = (p["pos"] as Vector2).distance_to(_target_pt["pos"])
				if dd < sd:
					sd = dd
					src = p
		if src != null:
			for k in 3:
				if alive >= cap + 2:
					break
				var e := _spawn_foe(lead, (src as Dictionary)["pos"] + Vector2(randf_range(-20, 20), randf_range(-20, 20)), etr)
				if e:
					e.set_meta("goal", _target_pt["pos"])
					e.set_meta("squad", true)
					alive += 1
	# Pressed back to two points or fewer, they come faster.
	if _owned("enemy") <= 2 and _owned("enemy") > 0:
		_spawn_t *= 0.9
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
			if map.player.position.distance_to(p["pos"]) < 80.0:
				defenders += 2  # you count double
			# Weak, valuable (has a spawner) and recently lost points first.
			var sc := 10.0 - defenders * 3.0 + (6.0 if str(p["spawner"]) != "" else 0.0) + (8.0 if str(p["owner"]) == "neutral" else 0.0) + randf() * 3.0
			if sc > bs:
				bs = sc
				bestp = p
		if not bestp.is_empty() and bestp != _target_pt:
			_target_pt = bestp
			if str(bestp["owner"]) == "ally":
				map.hud.toast("They're massing on %s!" % str(bestp["name"]), Color(1, 0.6, 0.45))
				var nw := Time.get_ticks_msec()
				if nw - _mass_ms > 8000:
					_mass_ms = nw
					Music.instance(get_tree()).sfx("war_drum", "alert")
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
		if e == _boss_ref and _boss_t >= BOSS_PUSH:
			# After a while the commander stops waiting and leads the push.
			best = _target_pt["pos"] if not _target_pt.is_empty() else map.player.position
		elif e.has_meta("squad") and e.has_meta("goal") and best == null:
			continue  # a squad keeps the order it was sent with
		if best == null and convoy != null and is_instance_valid(convoy) and not convoy.arrived:
			best = convoy.position  # escort: the squad goes for the convoy
		elif best == null and not _target_pt.is_empty():
			best = _target_pt["pos"]
		if best != null:
			e.set_meta("goal", best)


func _spawn_foe(kind: String, at: Vector2, etr: int) -> Enemy:
	var e := map.spawn_enemy(kind, at, etr)
	if e:
		if e._gift:
			e._gift.queue_free()
			e._gift = null
		e.reward = maxi(1, e.reward / 2)
	return e


func _count_kills() -> void:
	# [enemy, no-count (decoy/minion), boss], remembered while alive: a decoy that
	# is queue_freed has lost its metas by the time we look.
	for e in map.enemies:
		if is_instance_valid(e) and e._alive:
			var id: int = e.get_instance_id()
			if not _known.has(id):
				_known[id] = [e, e.has_meta("decoy") or e.has_meta("minion"), false]
			(_known[id] as Array)[2] = e.has_meta("boss_name")
	for k in _known.keys():
		var rec: Array = _known[k]
		var e: Variant = rec[0]
		if not is_instance_valid(e) or not (e as Enemy)._alive:
			_known.erase(k)
			if bool(rec[1]) or (is_instance_valid(e) and ((e as Enemy).has_meta("decoy") or (e as Enemy).has_meta("minion"))):
				continue  # a mirror's reflection or a summoned minion is no real kill
			var was_boss: bool = bool(rec[2])
			tickets["enemy"] = int(tickets["enemy"]) - (30 if was_boss else 1)
			_kills += 1
			GameState.add_xp("strategist", 15 if was_boss else 1)
			if was_boss:
				_boss_down = true
				map.hud.toast("Their commander is down! Rout!", Color(1, 0.9, 0.4))
				# Boss song winds down to the fight's song; a sting unless the win jingle follows.
				DangerMusic.boss_ended(map, false, win_by != "boss")
				Music.instance(get_tree()).play(map.area_track(), DangerMusic.BOSS_WIND)


## The allies you mustered (CampaignGate.team) take the field beside you:
## up to TEAM_MAX of them (not the partner already walking with you), crew
## and friends as strikers, then a healer and a warden.
func _field_team() -> void:
	if _over or map.player == null:
		return
	var jobs := ["striker", "healer", "striker", "warden"]
	var n := 0
	var act_id := Companion.active_id()
	for m: Array in team_members():
		if n >= TEAM_MAX:
			break
		if str(m[0]) == act_id:
			continue
		# Spread on a ring around you (not a row on top of you); free_spot keeps it dry.
		var ang := PI * 0.5 + (float(n) - 1.5) * 0.9
		var at: Vector2 = map.player.position + Vector2(cos(ang), sin(ang)) * Vector2(34, 24)
		var h := HelperUnit.make_team(map, m, jobs[n % jobs.size()], at, team_sprite(m))
		h.tag_row = n % 2
		if bool(d.get("inspired", false)):
			h.max_hp = int(h.max_hp * 1.25)
			h.hp = h.max_hp
		team.append(h)
		n += 1
	if n > 0:
		var nm: Array = team.map(func(h: HelperUnit) -> String: return h.team_name)
		map.hud.toast("%s fight%s beside you." % [_and_list(nm), "s" if n == 1 else ""], Color(0.7, 0.95, 1.0))


## Early fights (campaign tier 1, not the drill): until you give a RALLY order
## your mustered team pushes on its own: the captain once out, else the
## nearest point you don't hold. (A brand-new commander shouldn't watch an
## idle team lose the field.)
func _team_push() -> void:
	if _rally_given or is_drill or team.is_empty() or ctier() > 1 or _elapsed < 6.0:
		return
	var tgt := Vector2.INF
	if _boss_ref != null and is_instance_valid(_boss_ref) and _boss_ref._alive:
		tgt = _boss_ref.position
	else:
		var bd := INF
		for p in points:
			if str(p["owner"]) == "ally" and float(p["prog"]) >= 1.0:
				continue
			var dd: float = map.player.position.distance_to(p["pos"])
			if dd < bd:
				bd = dd
				tgt = p["pos"]
	if tgt == Vector2.INF:
		if map.has_meta("team_push"):
			map.remove_meta("team_push")
		return
	map.set_meta("team_push", tgt)
	if not _push_said:
		_push_said = true
		map.hud.toast("Your team pushes on. Tap RALLY to give orders.", Color(0.7, 0.95, 1.0))


static func team_members() -> Array:
	return CampaignGate.team()


static func _and_list(a: Array) -> String:
	if a.size() <= 1:
		return "".join(a)
	return ", ".join(a.slice(0, a.size() - 1)) + " and " + str(a.back())


## The character strip a team member is drawn with.
static func team_sprite(m: Array) -> String:
	var id := str(m[0])
	match str(m[2]):
		"partner":
			return str(Companion.defs().get(id, {}).get("sprite", ""))
		"crew":
			return str(Crew.members().get(id, {}).get("sprite", ""))
	return str(GameState.npcs.get(id, {}).get("sprite", ""))


func _disc(n: int) -> int:
	return maxi(1, int(round(n * (1.0 - GameState.bonus("strategist", "spawner_discount")))))


## USE on a point's banner: build (or change) its spawner.
func interact(id: String) -> void:
	var p := point(id)
	if p.is_empty():
		return
	if str(p["owner"]) != "ally":
		map.hud.toast("Take %s first: stand in the ring with no foes on it." % str(p["name"]), Color(1, 0.85, 0.6))
		Music.instance(get_tree()).sfx("nope", "thud")
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
	var does := {"striker": "zaps foes", "healer": "mends you", "warden": "shields you", "shade": "hides you"}
	for k: String in spawner_kinds():
		var kd: Dictionary = HelperUnit.kinds()[k]
		opts.append("%s (◇%d): %s" % [str(kd.get("crystal" if crystal else "drone", k.capitalize())), _cost(k), str(kd.get("does", does.get(HelperUnit.act_of(k), "helps")))])
		keys.append(k)
	opts.append("%s (◇%d): holds the point" % ["Crystal Pylon" if crystal else "Gun Turret", _cost("turret")])
	keys.append("turret")
	var extra_cost := {"upgrade": 30 * lvl, "fortify": 40, "mend": 25, "barrage": 35}
	for oi in opts.size():
		var kk: String = keys[oi]
		var cc := _cost(kk) if (SPAWNER_COST.has(kk) or HelperUnit.kinds().has(kk)) else (_disc(int(extra_cost[kk])) if extra_cost.has(kk) else 0)
		if cc > supply:
			opts[oi] = "✕ " + str(opts[oi])
	var sp := str(p["spawner"])
	var now_nm := ""
	if sp == "turret":
		now_nm = "Crystal Pylon" if crystal else "Gun Turret"
	elif sp != "":
		now_nm = str(HelperUnit.kinds().get(sp, {}).get("crystal" if crystal else "drone", sp.capitalize()))
	opts.append("Leave")  # B picks it: the list is long and the fight goes on
	var dl := Dialogue.instance(get_tree())
	dl.say([{"who": str(p["name"]), "text": "Supply ◇%d.%s %s:" % [supply, (" Now: %s." % now_nm) if now_nm != "" else "", ("Change the %s" if sp != "" else "Build a %s here") % ("crystal spire" if crystal else "drone bay")], "choice": opts, "key": ""}])
	await dl.finished
	var i := dl.last_choice
	if i < 0 or i >= keys.size():
		return
	var k: String = keys[i]
	var extra := {"upgrade": 30 * int(p.get("lvl", 1)), "fortify": 40, "mend": 25, "barrage": 35}
	var mu := Music.instance(get_tree())
	if (k == "mend" and _mend_cd > 0.0) or (k == "barrage" and _barrage_cd > 0.0):
		map.hud.toast("Not ready yet.", Color(1, 0.8, 0.6))
		mu.sfx("nope", "thud")
		return
	if extra.has(k):
		var c := _disc(int(extra[k]))
		if supply < c:
			map.hud.toast("Not enough supply. Hold more points.", Color(1, 0.7, 0.6))
			mu.sfx("nope", "thud")
			return
		supply -= c
		GameState.add_xp("strategist", 5)
		match k:
			"upgrade":
				p["lvl"] = int(p.get("lvl", 1)) + 1
				map.hud.toast("%s upgraded to level %d." % [str(p["name"]), int(p["lvl"])], Color(0.7, 1, 0.8))
				mu.sfx("craft_done", "levelup")
			"fortify":
				p["fort"] = true
				map.hud.toast("%s fortified." % str(p["name"]), Color(0.7, 1, 0.8))
				mu.sfx("hammer", "craft_done")
			"mend":
				GameState.heal_points(40)
				for h in map.get_tree().get_nodes_in_group("allies"):
					if h is HelperUnit and (h as Node2D).position.distance_to(map.player.position) < 120.0:
						(h as HelperUnit).hp = (h as HelperUnit).max_hp
				if map.pet != null and is_instance_valid(map.pet) and map.pet.position.distance_to(map.player.position) < 120.0 and not Pet.state().has("down_until"):
					Pet.state()["hp"] = Pet.max_hp()
				map.fx("heal", map.player.position + Vector2(0, -10), 10.0, 0.6)
				mu.sfx("heal", "levelup")
				map.hud.toast("Mend pulse!", Color(0.7, 1, 0.8))
				_mend_cd = 20.0
			"barrage":
				var n := 0
				for e in map.enemies:
					if is_instance_valid(e) and e.position.distance_to(p["pos"]) < 110.0:
						e._stun = maxf(e._stun, 1.0 if e.has_meta("boss_name") else 3.0)
						n += 1
				map.shake(3.0)
				mu.sfx("boom", "thud")
				map.hud.toast("Barrage! %d foes stunned." % n, Color(1, 0.9, 0.5))
				_barrage_cd = 25.0
		return
	if k == str(p["spawner"]):
		map.hud.toast("%s already builds that." % str(p["name"]), Color(1, 0.85, 0.6))
		mu.sfx("nope", "thud")
		return
	if supply < _cost(k):
		map.hud.toast("Not enough supply. Hold more points.", Color(1, 0.7, 0.6))
		mu.sfx("nope", "thud")
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
	mu.sfx("craft_done", "levelup")
	map.hud.toast("Built at %s." % str(p["name"]), Color(0.7, 1, 0.8))


func _end(won: bool, travel := true) -> void:
	if is_drill:
		_end_drill(won, travel)
		return
	if camp != "":
		_end_campaign(won, travel)
		return
	_over = true
	# A full campaign is what trains a Strategist (more for a win, something for a loss).
	var rematch: bool = GameState.run["flags"].has("battle_" + bid)
	GameState.add_xp("strategist", (120 if rematch else 400) if won else mini(120, 20 * _caps + _kills))
	if won or travel:
		Music.instance(get_tree()).sfx("j_battle_won" if won else "j_battle_lost", "levelup")
	_duck_music()
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
		GameState.add_money(cr, "battle")
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
		# A dark under-stroke so a white (open) ring reads on pavement, snow and ash.
		draw_arc(pos, CAP_R, 0, TAU, 48, Color(0.05, 0.05, 0.08, 0.55), 4.0, true)
		var ring_c := Color(col.r, col.g, col.b, (0.75 if str(p["owner"]) == "neutral" else 0.45) + 0.1 * sin(t * 2.0))
		if str(p["owner"]) == "enemy":
			# Theirs: a dashed ring, so it never relies on red vs blue alone (C9 c9_07).
			for k in 8:
				draw_arc(pos, CAP_R, TAU * k / 8.0, TAU * k / 8.0 + TAU / 14.0, 6, ring_c, 2.0, false)
		else:
			draw_arc(pos, CAP_R, 0, TAU, 48, ring_c, 2.0, true)
		if bool(p.get("gate", false)):
			# An enemy gate (defend): a spiked double ring; it can't be taken.
			draw_arc(pos, CAP_R + 4, 0, TAU, 48, Color(0.55, 0.1, 0.12, 0.7), 2.0, true)
			for k in 12:
				var an := TAU * k / 12.0 + t * 0.3
				draw_line(pos + Vector2.from_angle(an) * (CAP_R + 4), pos + Vector2.from_angle(an) * (CAP_R + 10), Color(0.55, 0.1, 0.12, 0.7), 2.0)
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
		# Siege: a fortified enemy point shows a shield until it's broken.
		if bool(p.get("efort", false)) and str(p["owner"]) != "ally":
			var sc := pos + Vector2(12, -20)
			var sh := PackedVector2Array([sc + Vector2(-5, -6), sc + Vector2(5, -6), sc + Vector2(5, 0), sc + Vector2(0, 6), sc + Vector2(-5, 0)])
			draw_colored_polygon(sh, Color(0.75, 0.25, 0.25, 0.9))
			draw_polyline(sh + PackedVector2Array([sh[0]]), Color(1, 0.9, 0.7, 0.9), 1.0)
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
	_draw_rally(t)


## Where the helpers are headed: a pulsing ring and chevrons on the rally point,
## or a small ring round you when they follow.
func _draw_rally(t: float) -> void:
	var cyan := Color(0.55, 0.95, 1.0)
	var k := 0.5 + 0.5 * sin(t * 4.0)
	if _rally >= 0 and _rally < points.size():
		var pos: Vector2 = points[_rally]["pos"]
		draw_arc(pos, CAP_R + 7 + 2.0 * k, 0, TAU, 48, Color(cyan.r, cyan.g, cyan.b, 0.55 + 0.35 * k + _rally_flash * 0.3), 2.0 + _rally_flash * 2.0, true)
		for q in 4:
			var a := TAU * q / 4.0 + t * 0.8
			var dir := Vector2.from_angle(a)
			var tip := pos + dir * (CAP_R + 12)
			draw_colored_polygon(PackedVector2Array([tip, tip + dir * 7 + dir.orthogonal() * 4, tip + dir * 7 - dir.orthogonal() * 4]), Color(cyan.r, cyan.g, cyan.b, 0.8))
		var f := ThemeDB.fallback_font
		draw_string_outline(f, pos + Vector2(-30, -CAP_R - 14), "RALLY", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, 3, Color(0, 0, 0, 0.8))
		draw_string(f, pos + Vector2(-30, -CAP_R - 14), "RALLY", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, cyan)
	elif _rally == -1 and map.player:
		draw_arc(map.player.position + Vector2(0, -4), 22 + 2.0 * k, 0, TAU, 32, Color(cyan.r, cyan.g, cyan.b, 0.35 + 0.3 * k + _rally_flash * 0.3), 1.5, true)


func _draw_hud() -> void:
	var f := ThemeDB.fallback_font
	var txt := []  # [pos, text, align, width, size, colour]: drawn at the end, all outlines then all fills
	var y := 104.0
	# The bars stop short of the point pips (6 points used to sit on top of them).
	var bw := clampf(135.0 - points.size() * 7.0 - 14.0, 50.0, 90.0)
	var ta := clampf(float(tickets["ally"]) / float(maxi(1, int(_t_max["ally"]))), 0, 1)
	var te := clampf(float(tickets["enemy"]) / float(maxi(1, int(_t_max["enemy"]))), 0, 1)
	_hud.draw_rect(Rect2(10, y, bw, 5), Color(0, 0, 0, 0.6))
	_hud.draw_rect(Rect2(10, y, bw * ta, 5), Color(0.5, 0.9, 1.0))
	_hud.draw_rect(Rect2(260 - bw, y, bw, 5), Color(0, 0, 0, 0.6))
	_hud.draw_rect(Rect2(260 - bw + bw * (1.0 - te), y, bw * te, 5), Color(1, 0.45, 0.4))
	txt.append([Vector2(10, y + 13), "Us %d" % int(tickets["ally"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.8, 0.95, 1)])
	txt.append([Vector2(220, y + 13), "Them %s" % ("∞" if win_by in ["hold", "drill"] else str(maxi(0, int(tickets["enemy"])))), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.8, 0.75)])
	# The objective, always on screen, in its own banner.
	var goal := _goal_text() if drill == null else ""  # the drill's step card says what to do
	if goal != "":
		var gr := Rect2(8, y + 22, 254, 15)
		_hud.draw_rect(gr, Color(0.06, 0.05, 0.08, 0.72))
		_hud.draw_rect(gr, Color(1, 0.86, 0.45, 0.55), false, 1.0)
		var oi := Art.tex("ui", "icon_objective")
		if oi:
			_hud.draw_texture_rect(oi, Rect2(gr.position + Vector2(3, 1.5), Vector2(12, 12)), false)
		txt.append([Vector2(18, y + 33), goal, HORIZONTAL_ALIGNMENT_CENTER, 240, 7, Color(1, 0.92, 0.6)])
	# Helpers in the field, beside the RALLY button.
	var hn := _helpers()
	txt.append([Vector2(RALLY_RECT.end.x + 5, RALLY_RECT.position.y + 12), "%d helper%s%s" % [hn, "" if hn == 1 else "s", " · build at a banner" if hn == 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.75, 0.95, 1.0) if _rally_flash <= 0.0 else Color(1, 1, 0.7)])
	# Point pips, left to right in data order, with an arrow toward the nearest one you don't hold.
	var x0 := 135.0 - points.size() * 7.0
	for i in points.size():
		var p: Dictionary = points[i]
		var col := Color(0.5, 0.9, 1.0) if str(p["owner"]) == "ally" else (Color(1, 0.45, 0.4) if str(p["owner"]) == "enemy" else Color(0.8, 0.8, 0.8))
		# Shape as well as colour (C9 c9_07): ours a filled disc, theirs a disc with
		# a dark slash, open points a hollow ring.
		var pc := Vector2(x0 + i * 14 + 7, y + 3)
		Art.draw_disc(_hud, pc, 6.5, Color(0, 0, 0, 0.7))
		if str(p["owner"]) == "neutral":
			Art.draw_ring(_hud, pc, 5.0, 1.5, col)
		else:
			Art.draw_disc(_hud, pc, 5.5, col)
		if str(p["owner"]) == "enemy":
			_hud.draw_line(pc + Vector2(-4.5, 4.5), pc + Vector2(4.5, -4.5), Color(0.15, 0.02, 0.02, 0.9), 1.5)
	for i in points.size():
		_hud.draw_string(f, Vector2(x0 + i * 14 + 2, y + 5.5), str(points[i]["id"]).left(1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 10, 7, Color(0.08, 0.08, 0.08))
	# Who is bleeding tickets (the side holding fewer points), and supply income.
	var oa := _owned("ally")
	var oe := _owned("enemy")
	if oe > oa:
		txt.append([Vector2(42, y + 13), "-%d/s" % (oe - oa), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.5, 0.4)])
	elif oa > oe:
		txt.append([Vector2(196, y + 13), "-%d/s" % (oa - oe), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 1, 0.7)])
	var stxt := "Supply ◇%d (%+.1f/s)" % [supply, _rate]
	txt.append([Vector2(76, y + 13), stxt, HORIZONTAL_ALIGNMENT_CENTER, 124, 7, Color(1, 0.95, 0.7)])
	var si := Art.tex("ui", "icon_supply")
	if si:
		_hud.draw_texture_rect(si, Rect2(Vector2(80, y + 6), Vector2(9, 9)), false)
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
		# On an ellipse below the battle bar, so a point to the north never lands on the HUD.
		var c := Vector2(135, 310) + dir * Vector2(110.0, 80.0)
		_hud.draw_colored_polygon(PackedVector2Array([c + dir * 8, c + dir.orthogonal() * 5, c - dir.orthogonal() * 5]), Color(1, 0.9, 0.5, 0.9))
		# 90 px wide (kept on screen) so names like "Scarecrow Post" aren't cut short.
		txt.append([Vector2(clampf(c.x - 45.0, 2.0, 178.0), c.y + 14.0), str((best as Dictionary)["name"]), HORIZONTAL_ALIGNMENT_CENTER, 90, 6, Color(1, 0.95, 0.8)])


# ---- campaign nodes --------------------------------------------------------------

func _campaign_setup() -> void:
	# Falling back leads to wherever the board was opened, not the field's own camp.
	var back: Array = d.get("back", [])
	if back.size() >= 3:
		for e in map.exits:
			if str(e.get("label", "")).contains("fall back"):
				e["scene"] = str(back[0])
				e["spawn"] = Vector2(float(back[1]) * GameMap.TILE, float(back[2]) * GameMap.TILE)
	if win_by == "convoy":
		var wp: Array = []
		for id in d.get("convoy", []):
			var p := point(str(id))
			if not p.is_empty():
				wp.append(p["pos"])
		if wp.size() >= 2:
			convoy = CampaignConvoy.make(map, wp, int(d.get("convoy_hp", 80)))


## The fight's state, kept in the campaign fight record every second, so a
## game closed mid-fight and reopened carries on where it was (not afresh).
func _keep() -> void:
	var f: Dictionary = Campaign.st().get("fight", {})
	if f.is_empty() or str(f.get("cid", "")) != camp:
		return
	f["state"] = {"tickets": tickets.duplicate(), "supply": supply, "hold": _hold, "elapsed": _elapsed,
		"boss_out": _boss_out, "boss_hp": (_boss_ref.hp if _boss_ref != null and is_instance_valid(_boss_ref) else -1), "points": points.map(func(p: Dictionary) -> Array: return [str(p["id"]), str(p["owner"]), float(p["prog"]), str(p["spawner"]), int(p.get("lvl", 1)), bool(p.get("fort", false))])}


var _resume_boss_hp := -1


func _resume(cf: Dictionary) -> void:
	var stt: Dictionary = cf.get("state", {})
	if stt.is_empty():
		return
	var tk: Dictionary = stt.get("tickets", {})
	tickets = {"ally": int(tk.get("ally", tickets["ally"])), "enemy": int(tk.get("enemy", tickets["enemy"]))}
	supply = int(stt.get("supply", supply))
	_hold = float(stt.get("hold", _hold))
	_elapsed = float(stt.get("elapsed", 0.0))
	for rec: Array in stt.get("points", []):
		var p := point(str(rec[0]))
		if p.is_empty():
			continue
		p["owner"] = str(rec[1])
		p["prog"] = float(rec[2])
		p["spawner"] = str(rec[3]) if p["owner"] == "ally" else ""
		p["lvl"] = int(rec[4])
		p["fort"] = bool(rec[5])
		p["t"] = 10.0
	# A commander already out comes back for the rest of the fight.
	if bool(stt.get("boss_out", false)) and d.has("boss"):
		d["boss_at"] = "start"
		_elapsed = maxf(_elapsed, 7.0)
		_resume_boss_hp = int(stt.get("boss_hp", -1))  # the captain comes back as hurt as you left them
	map.hud.toast("The fight picks up where you left it.", Color(0.8, 0.95, 1.0))
	Music.instance(get_tree()).sfx("war_drum", "alert")


func _goal_text() -> String:
	match win_by:
		"drill":
			return "TRAINING · follow the steps below"
		"hold":
			return "HOLD %d:%02d · keep a point" % [int(maxf(0.0, _hold)) / 60, int(maxf(0.0, _hold)) % 60]
		"convoy":
			if convoy != null and is_instance_valid(convoy):
				return "CONVOY %d%% · %s · ♥%d" % [int(convoy.progress() * 100), {"roll": "rolling", "wait": "walk with it", "blocked": "clear the foes!"}.get(convoy.state, ""), convoy.hp]
		"boss":
			if _boss_ref != null and is_instance_valid(_boss_ref) and _boss_ref._alive:
				var bn := _boss_ref.display_name()
				if bn.to_lower().begins_with("captain "):
					bn = bn.substr(8)  # "CAPTAIN Captain Bramblesnout" -> "CAPTAIN Bramblesnout"
				return "CAPTAIN %s ♥%d" % [bn, _boss_ref.hp]
			return "Their captain is coming" if not _boss_out else ""
	if mode == "siege" or mode == "gate":
		var forts := points.filter(func(p: Dictionary) -> bool: return bool(p.get("efort", false)) and str(p["owner"]) != "ally").size()
		if forts > 0:
			return "SIEGE · %d fortified point%s left · or drain their tickets" % [forts, "" if forts == 1 else "s"]
	var held := _owned("ally")
	return "TAKE ALL %d POINTS (%d/%d) · or drain their tickets" % [points.size(), held, points.size()]


## The fight's over: the song drops under the jingle and the closing lines.
func _duck_music() -> void:
	# Dip the music 9 dB for 4 s so the win/loss jingle cuts through: a named duck
	# layer (P1's Music.set_duck_layer) that Ambience can't undo.
	var mu := Music.instance(get_tree())
	if mu.has_method("set_duck_layer"):
		mu.call("set_duck_layer", "battle", -9.0, 0.12, 0.8, 4.0)


## The drill can't hurt you: knocked out, worn out or up too late, the trainer
## pulls you out (half health, no fee, no pass-out) and the drill ends untaken.
## GameMap.player_down hands over here while a drill runs.
func drill_rescue(_reason := "hurt") -> void:
	if _over:
		return
	GameState.run["hp"] = maxi(int(GameState.run["hp"]), int(GameState.run["max_hp"]) / 2)
	GameState.run["energy"] = maxi(int(GameState.run["energy"]), int(GameState.run["max_energy"]) / 4)
	GameState.status_clear()
	map.player.invuln = 2.0
	var tr := CampaignGate.trainer()
	map.hud.toast("%s pulls you out of the drill. No harm done." % (tr if tr != "" else "Your trainer"), Color(1, 0.9, 0.6))
	_end(false)


func _end_drill(won: bool, travel: bool) -> void:
	_over = true
	if drill != null and drill.xp > 0:
		GameState.add_xp("strategist", drill.xp)
	Music.instance(get_tree()).sfx("j_battle_won" if won else "j_battle_lost", "levelup")
	_duck_music()
	for e in map.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	map.enemies.clear()
	for h in get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit:
			h.queue_free()
	var lines := CampaignGate.drill_finish(won)
	GameState.save()
	if not travel:
		return
	await map.say(lines)
	var back: Array = d.get("back", ["town", 0, 0])
	Campaign.reopen_later(get_tree(), "")
	map.go_to(str(back[0]), Vector2(float(back[1]) * GameMap.TILE, float(back[2]) * GameMap.TILE) if float(back[1]) > 0 else Vector2.ZERO, "down")


func _end_campaign(won: bool, travel: bool) -> void:
	_over = true
	GameState.add_xp("strategist", 150 if won else mini(80, 15 * _caps + _kills))
	# Jingles once: Campaign.finish plays the win (battle or whole campaign); a KO
	# (no travel) leaves the sound to the faint. The song ducks under the jingle.
	if not won and travel:
		Music.instance(get_tree()).sfx("j_battle_lost", "thud")
	_duck_music()
	if won:
		GameState.add_arc_xp(30)
	for e in map.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	map.enemies.clear()
	for h in get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit or h is CampaignConvoy:
			h.queue_free()
	var cid := camp
	var lines := Campaign.finish(won, supply)
	if won:
		map.xp("combat", 30)
	GameState.save()
	if not travel:
		return
	if not lines.is_empty():
		await map.say(lines)
	GameState.save()
	var back: Array = d.get("back", ["town", 0, 0])
	Campaign.reopen_later(get_tree(), cid)
	map.go_to(str(back[0]), Vector2(float(back[1]) * GameMap.TILE, float(back[2]) * GameMap.TILE) if float(back[1]) > 0 else Vector2.ZERO, "down")
