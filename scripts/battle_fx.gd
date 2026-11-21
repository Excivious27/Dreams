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
