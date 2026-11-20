extends CasinoGame
## Big or Small: three dice, Small 4-10 or Big 11-17, pays 1 to 1, any triple loses.
## The dice are drawn first; the tumble only shows them.

var dice := [1, 2, 3]
var history: Array = []


func bets() -> Array:
	return [["small", "Small 4-10"], ["big", "Big 11-17"]]


func _a_word() -> String:
	return "ROLL"


func _deal() -> void:
	var r := out_rng()
	dice = [r.randi_range(1, 6), r.randi_range(1, 6), r.randi_range(1, 6)]
	reveal_len = 0.9
	state = "reveal"
	sfx("dice_roll", "dice")


func gross_for(d: Array) -> int:
	return (2 * stake) if CasinoRules.dice_wins(bet_id(), d) else 0


func _reveal_done() -> void:
	history.push_front(dice.duplicate())
	if history.size() > 8:
		history.pop_back()
	finish(gross_for(dice))


func _draw_die(c: Control, ctr: Vector2, v: int, sz := 36.0) -> void:
	var r := Rect2(ctr - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
	c.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, Color(0.97, 0.96, 0.92))
	c.draw_rect(r, Color(0.3, 0.2, 0.15), false, 1.5)
	var pips := {1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
		5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]]}
	for p: Array in pips[clampi(v, 1, 6)]:
		c.draw_circle(ctr + Vector2(float(p[0]), float(p[1])) * sz * 0.27, sz * 0.08, Color(0.75, 0.1, 0.12) if v == 1 else Color(0.1, 0.08, 0.08))


func _draw_play(c: Control) -> void:
	draw_felt(c, Color(0.08, 0.2, 0.4))
	var bowl := Vector2(135, 110)
	c.draw_circle(bowl, 62, Color(0.85, 0.66, 0.24))
	c.draw_circle(bowl, 56, Color(0.06, 0.14, 0.3))
	for i in 3:
		var v: int = dice[i]
		var off := Vector2((i - 1) * 40.0, (12.0 if i == 1 else -6.0))
		if state == "reveal":
			v = rng.randi_range(1, 6)
			off += Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		_draw_die(c, bowl + off, v)
	if state == "result" or (state == "bet" and not history.is_empty()):
		var s := int(dice[0]) + int(dice[1]) + int(dice[2])
		var trip := int(dice[0]) == int(dice[1]) and int(dice[1]) == int(dice[2])
		text_outline(c, Vector2(0, 190), ("Triple %d: house wins" % int(dice[0])) if trip else ("%d  %s" % [s, "SMALL" if s <= 10 else "BIG"]), W, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var hr := hit_rects()
	var b := bets()
	for i in 2:
		var r: Rect2 = hr[i]
		var sel := i == bet_ix
		c.draw_rect(r, Color(0.05, 0.12, 0.25))
		c.draw_rect(r, Color(1, 0.85, 0.3) if sel else Color(FELT_EDGE, 0.6), false, 2.0 if sel else 1.0)
		text_outline(c, Vector2(r.position.x, r.position.y + 20), str(b[i][1]), r.size.x, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		text(c, Vector2(r.position.x, r.position.y + 34), "pays 1 to 1", r.size.x, 7, Color(1, 0.92, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(10, 268), "Any triple: the house wins both bets.", 250, 7, Color(1, 0.92, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	for i in history.size():
		var h: Array = history[i]
		text(c, Vector2(10 + i * 32, 282), "%d" % (int(h[0]) + int(h[1]) + int(h[2])), 30, 7, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	draw_bet_strip(c)
	draw_fx(c)


func hit_rects() -> Array:
	return [Rect2(14, 208, 118, 44), Rect2(138, 208, 118, 44)]


func _tap_play(p: Vector2) -> void:
	if state != "bet":
		return
	var hr := hit_rects()
	for i in 2:
		if (hr[i] as Rect2).has_point(p):
			bet_ix = i
			sfx("ui_tap", "scroll_tick")
