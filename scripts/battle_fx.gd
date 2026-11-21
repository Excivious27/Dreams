class_name BattleFx
extends RefCounted
## Battle effects owned by C16b P2, hooked from Battle with one line each:
##  - stand_down(map, unit): a helper / turret leaves the field with a poof and a short
##    fade, never a blink out of existence (c16b_11-08).
##  - clear_field(map, won): the battle's last second (c16b_11-17). Foes leave the fight
##    at once (map.enemies is emptied, so nothing more happens), but on screen they flee
##    with a poof (a win) or hold (a loss) while helpers cheer (a win) or poof out one by
##    one (a loss); everything is freed within OUTRO s. Reduced motion: fades in place.
##  - beat(node): wait OUTRO s of game time (the tree's pause stops it) before the
##    end-of-battle lines open, so the outro is seen.

const OUTRO := 1.2


static func stand_down(m: GameMap, u: Node, delay := 0.0) -> void:
	if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
		return
	if u is HelperUnit:
		u.remove_from_group("allies")  # out of every ally list now
		u.set_process(false)
	var n2 := u as Node2D
	if n2 == null or m == null:
		u.queue_free()
		return
	var tw := n2.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if is_instance_valid(m) and is_instance_valid(n2):
			m.fx("poof", n2.position + Vector2(0, -6), 12.0, 0.4))
	tw.tween_property(n2, "modulate:a", 0.0, 0.3)
	tw.tween_callback(n2.queue_free)


static func clear_field(m: GameMap, won: bool) -> void:
	if m == null:
		return
	var foes: Array = m.enemies.duplicate()
	m.enemies.clear()
	var reduced := Anim.reduced()
	var k := 0
	for e in foes:
		if not is_instance_valid(e):
			continue
		var en := e as Node2D
		en.set_process(false)
		if e.get("_alive") != null:
			e.set("_alive", false)
		var tw := en.create_tween()
		if won and not reduced:
			# They break and run: off toward the nearest side, then a poof.
			var away := Vector2(signf(en.position.x - m.player.position.x) if m.player else 1.0, 0.0)
			if away.x == 0.0:
				away.x = 1.0
			tw.tween_property(en, "position", en.position + away * 40.0, 0.7)
			tw.tween_callback(func() -> void:
				if is_instance_valid(m) and is_instance_valid(en):
					m.fx("poof", en.position + Vector2(0, -8), 12.0, 0.4))
			tw.tween_property(en, "modulate:a", 0.0, 0.25)
		else:
			# A loss: they hold the field a moment; reduced motion: fade in place.
			tw.tween_interval(0.6 if not won else 0.2)
			tw.tween_property(en, "modulate:a", 0.0, 0.4)
		tw.tween_callback(en.queue_free)
		k += 1
	var hi := 0
	for h in m.get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit or h is CampaignConvoy:
			if won and h is HelperUnit:
				m.emote(h, "heart", 1.0, -24.0)
				(h as HelperUnit)._act_t = 1.0  # the act pose: a cheer
				stand_down(m, h, 0.8)
			else:
				stand_down(m, h, 0.1 * hi)
			hi += 1
	if won:
		m.shake(2.0)  # (GameMap.shake skips it when shake is off)


static func beat(n: Node) -> void:
	if n == null or not n.is_inside_tree():
		return
	await n.get_tree().create_timer(OUTRO, false).timeout


## A second, red off-screen pointer toward a point you hold that is under attack
## (foes in its ring, or its hold slipping under 0.6), pulsing; its name and
## "under attack" go in the HUD's text list (c16b_11-15). Still under reduced motion.
static func threat_pointer(bt: Battle, txt: Array) -> void:
	if bt == null or bt.map == null or bt.map.player == null or bt._hud == null:
		return
	var best: Variant = threat_point(bt)
	if (best as Dictionary).is_empty():
		return
	var pp: Vector2 = bt.map.player.position
	var dir: Vector2 = ((best as Dictionary)["pos"] - pp).normalized()
	var a := 0.9 if Anim.reduced() else 0.65 + 0.35 * sin(Anim.t() * 6.0)
	var c := Vector2(135, 310) + dir * Vector2(100.0, 70.0)
	bt._hud.draw_colored_polygon(PackedVector2Array([c + dir * 9, c + dir.orthogonal() * 6, c - dir.orthogonal() * 6]), Color(1, 0.35, 0.3, a))
	bt._hud.draw_arc(c, 9.0, 0, TAU, 20, Color(1, 0.35, 0.3, a * 0.8), 1.5, true)
	txt.append([Vector2(clampf(c.x - 45.0, 2.0, 178.0), c.y - 20.0), "%s under attack" % str((best as Dictionary)["name"]), HORIZONTAL_ALIGNMENT_CENTER, 90, 7, Color(1, 0.6, 0.55)])


## The nearest off-screen (> 140 px) point you hold that is under attack, or {}.
static func threat_point(bt: Battle) -> Dictionary:
	var pp: Vector2 = bt.map.player.position
	var best: Dictionary = {}
	var bd := 1e9
	for p in bt.points:
		if str(p["owner"]) != "ally":
			continue
		var pos: Vector2 = p["pos"]
		var hit := float(p["prog"]) < 0.6
		if not hit:
			for e in bt.map.enemies:
				if is_instance_valid(e) and e._alive and (e as Node2D).position.distance_to(pos) < Battle.CAP_R + 6.0:
					hit = true
					break
		var dd := pp.distance_to(pos)
		if hit and dd > 140.0 and dd < bd:
			bd = dd
			best = p
	return best
