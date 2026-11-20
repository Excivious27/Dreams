extends CasinoGame
## Roulette, single zero. Outside bets on big tiles plus "One number" (X / Y step the
## number). The pocket is drawn first; the wheel and ball only travel to it.

const ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const WHEEL_C := Vector2(135, 112)
const WHEEL_R := 70.0

var pocket := 0
var number := 17
var history: Array = []
var _wheel_a := 0.0
var _from_a := 0.0
var _to_a := 0.0


func bets() -> Array:
	var out: Array = []
	var b: Dictionary = Casino.data().get("roulette", {}).get("bets", {})
	for id in ["red", "black", "odd", "even", "low", "high", "dozen1", "dozen2", "dozen3", "single"]:
		if b.has(id):
			out.append([id, "%d" % number if id == "single" else str(b[id][0])])
	return out


func bet_id() -> String:
	var id := super.bet_id()
	return "single%d" % number if id == "single" else id


func _a_word() -> String:
	return "SPIN"


func _play_label(action: String) -> String:
	if state == "bet" and super.bet_id() == "single":
		return "# -" if action == "tool" else "# +"
	return ""


func _step_bet() -> void:
	if super.bet_id() == "single":
		if repeat_pressed("tool"):
			number = posmod(number - 1, 37)
			sfx("ui_tap", "scroll_tick")
		elif repeat_pressed("action"):
			number = posmod(number + 1, 37)
			sfx("ui_tap", "scroll_tick")
	super._step_bet()


func _deal() -> void:
	pocket = out_rng().randi_range(0, 36)
	_from_a = fposmod(_wheel_a, TAU)
	var idx := ORDER.find(pocket)
	# The ball rests at the top: turn the wheel so the pocket arrives there.
	_to_a = _from_a + TAU * 3.0 + fposmod(-TAU * idx / 37.0 - _from_a, TAU)
	reveal_len = 2.5
	state = "reveal"
	sfx("roulette_spin", "beat_tick")


func gross_for(p: int) -> int:
	return CasinoRules.roulette_pays(super.bet_id(), p, number) * stake


func _reveal_done() -> void:
	_wheel_a = _to_a
	history.push_front(pocket)
	if history.size() > 10:
		history.pop_back()
	sfx("roulette_ball", "pin_tap")
	finish(gross_for(pocket))


func _wheel_angle() -> float:
	if state == "reveal":
		var u := clampf(reveal_t / reveal_len, 0.0, 1.0)
		return lerpf(_from_a, _to_a, 1.0 - pow(1.0 - u, 3.0))
	return _wheel_a


func _pocket_col(n: int) -> Color:
	if n == 0:
		return Color(0.1, 0.55, 0.25)
	return Color(0.78, 0.1, 0.12) if CasinoRules.is_red(n) else Color(0.1, 0.1, 0.12)


func _draw_play(c: Control) -> void:
	draw_felt(c)
	var a0 := _wheel_angle()
	c.draw_circle(WHEEL_C, WHEEL_R + 6, Color(0.35, 0.2, 0.08))
	c.draw_circle(WHEEL_C, WHEEL_R + 2, FELT_EDGE)
	for i in 37:
		var a := a0 + TAU * i / 37.0 - PI / 2.0
		var a2 := a + TAU / 37.0
		var n: int = ORDER[i]
		var pts := PackedVector2Array([WHEEL_C + Vector2.from_angle(a) * 34.0, WHEEL_C + Vector2.from_angle(a) * WHEEL_R,
			WHEEL_C + Vector2.from_angle(a2) * WHEEL_R, WHEEL_C + Vector2.from_angle(a2) * 34.0])
		c.draw_colored_polygon(pts, _pocket_col(n))
		var mid := a + TAU / 74.0
		var tp := WHEEL_C + Vector2.from_angle(mid) * (WHEEL_R - 9.0)
		text(c, tp + Vector2(-8, 3), str(n), 16, 7, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	c.draw_circle(WHEEL_C, 34.0, Color(0.45, 0.28, 0.1))
	c.draw_circle(WHEEL_C, 12.0, FELT_EDGE)
	# Ball: orbits during the spin, then sits at the top pocket.
	var bp := WHEEL_C + Vector2(0, -(WHEEL_R - 18.0))
	if state == "reveal":
		var u := clampf(reveal_t / reveal_len, 0.0, 1.0)
		var ba := -PI / 2.0 - (1.0 - pow(1.0 - u, 2.0)) * TAU * 5.0 * (1.0 - u)
		var br := lerpf(WHEEL_R + 2.0, WHEEL_R - 18.0, u * u)
		bp = WHEEL_C + Vector2.from_angle(ba) * br
	c.draw_circle(bp, 4.0, Color(0.98, 0.98, 1))
	c.draw_circle(WHEEL_C + Vector2(0, -WHEEL_R - 9), 3.0, FELT_EDGE)
	# Last results (numbers + R/B letters: never colour alone).
	text(c, Vector2(12, 196), "Last:", 40, 7, Color(1, 1, 1, 0.7))
	for i in history.size():
		var n: int = history[i]
		var r := Rect2(40 + i * 22, 188, 20, 12)
		c.draw_rect(r, _pocket_col(n))
		text(c, Vector2(r.position.x, r.position.y + 9), "%d%s" % [n, "" if n == 0 else ("R" if CasinoRules.is_red(n) else "B")], 20, 7, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# Bet board.
	var b := bets()
	for i in b.size():
		var r: Rect2 = hit_rects()[i]
		var sel := i == bet_ix
		var id := str(b[i][0])
		var col := Color(0.06, 0.2, 0.12)
		if id == "red": col = Color(0.55, 0.08, 0.1)
		elif id == "black": col = Color(0.08, 0.08, 0.1)
		c.draw_rect(r, col)
		c.draw_rect(r, Color(1, 0.85, 0.3) if sel else Color(FELT_EDGE, 0.6), false, 2.0 if sel else 1.0)
		var won := state == "result" and CasinoRules.roulette_wins(id, pocket, number)
		if won:
			c.draw_rect(r.grow(-3), Color(1, 0.9, 0.4, 0.25 + 0.2 * sin(t * 8.0)))
		text(c, Vector2(r.position.x, r.position.y + 15), ("# %d" % number) if id == "single" else str(b[i][1]), r.size.x, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if state == "result" or (state == "bet" and not history.is_empty()):
		var pn: int = history[0] if not history.is_empty() else pocket
		text_outline(c, Vector2(WHEEL_C.x - 30, WHEEL_C.y + 5), str(pn), 60, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var pays: Dictionary = Casino.data().get("roulette", {}).get("bets", {})
	if super.bet_id() in pays:
		text(c, Vector2(12, 272), "Pays %d to 1. Zero loses outside bets." % int(pays[super.bet_id()][1]), 246, 7, Color(1, 0.92, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	draw_bet_strip(c)
	draw_fx(c)


## Ten bet tiles, two rows of five (50x22 each: over the 20 px tap floor).
func hit_rects() -> Array:
	var out: Array = []
	for i in 10:
		out.append(Rect2(7 + (i % 5) * 52.0, 206 + (i / 5) * 26.0, 50, 22))
	return out


func _tap_play(p: Vector2) -> void:
	if state != "bet":
		return
	var hr := hit_rects()
	for i in hr.size():
		if (hr[i] as Rect2).has_point(p):
			bet_ix = i
			sfx("ui_tap", "scroll_tick")
			return
