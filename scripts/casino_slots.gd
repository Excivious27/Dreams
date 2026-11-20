extends CasinoGame
## Gilded Slots: 3 reels, one payline. The three stops are drawn first from the
## real strips in data/casino.json; the reels only spin to them (no swapped symbols,
## no extra near-misses). Every paying line pays at least 2x the bet.

var stops := [0, 0, 0]
var _spin_from := [0.0, 0.0, 0.0]
var _stopped := 3

const REEL_X := [52.0, 113.0, 174.0]
const REEL_W := 44.0
const CELL := 34.0
const MID_Y := 150.0
const SYM_COL := {"cherry": Color(0.9, 0.15, 0.2), "bell": Color(0.95, 0.78, 0.2), "bar": Color(0.2, 0.2, 0.25), "horseshoe": Color(0.6, 0.62, 0.7),
	"star": Color(1, 0.85, 0.3), "crown": Color(0.95, 0.65, 0.1), "seven": Color(0.85, 0.1, 0.3)}
const SYM_TXT := {"cherry": "Ch", "bell": "Be", "bar": "BAR", "horseshoe": "U", "star": "*", "crown": "Cr", "seven": "7"}


func _a_word() -> String:
	return "SPIN"


func _opened() -> void:
	super._opened()
	var r := rng
	for i in 3:
		stops[i] = r.randi_range(0, maxi(0, (CasinoRules.strips()[i] as Array).size() - 1))


func _deal() -> void:
	var r := out_rng()
	for i in 3:
		_spin_from[i] = float(stops[i])
		stops[i] = r.randi_range(0, (CasinoRules.strips()[i] as Array).size() - 1)
	reveal_len = 1.4
	_stopped = 0
	state = "reveal"
	sfx("slot_spin", "scroll_tick")


func _reveal_step() -> void:
	while _stopped < 3 and reveal_t >= 0.6 + 0.3 * _stopped:
		_stopped += 1
		sfx("slot_stop", "dry_click")


func symbol(i: int, k: int) -> String:
	var s: Array = CasinoRules.strips()[i]
	return str(s[posmod(k, s.size())])


func line_symbols() -> Array:
	return [symbol(0, stops[0]), symbol(1, stops[1]), symbol(2, stops[2])]


func gross_for(syms: Array) -> int:
	return CasinoRules.slot_pay(str(syms[0]), str(syms[1]), str(syms[2])) * stake


func _reveal_done() -> void:
	if _stopped < 3:
		sfx("slot_stop", "dry_click")
	_stopped = 3
	finish(gross_for(line_symbols()))


func _step_state(_s: String, _dt: float) -> void:
	pass


## Reel i's scroll position (in cells) at the current reveal time.
func _reel_pos(i: int) -> float:
	if state != "reveal":
		return float(stops[i])
	var stop_at := 0.6 + 0.3 * i
	if reveal_t >= stop_at:
		return float(stops[i])
	var n := float((CasinoRules.strips()[i] as Array).size())
	var turns := 2.0 + i
	var u := clampf(reveal_t / stop_at, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var from := float(stops[i]) - n * turns
	var p := lerpf(from, float(stops[i]), e)
	return p


func _draw_play(c: Control) -> void:
	draw_felt(c, Color(0.3, 0.06, 0.1))
	var cab := Rect2(30, 70, 210, 160)
	panel(c, cab, Color(0.12, 0.06, 0.04), FELT_EDGE)
	text_outline(c, Vector2(cab.position.x, cab.position.y - 8), "GILDED SLOTS", cab.size.x, 12, FELT_EDGE, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var rr := Rect2(REEL_X[i], MID_Y - CELL * 1.5, REEL_W, CELL * 3)
		c.draw_rect(rr, Color(0.97, 0.95, 0.9))
		var p := _reel_pos(i)
		var base := floori(p)
		var frac := p - base
		for k in range(-2, 3):
			var y := MID_Y + (k - frac) * CELL
			if y < rr.position.y - CELL * 0.5 + 6 or y > rr.end.y + CELL * 0.5 - 6:
				continue
			_draw_symbol(c, symbol(i, base + k), Vector2(rr.get_center().x, y), clampf(1.0 - absf(y - MID_Y) / (CELL * 1.9), 0.3, 1.0))
		c.draw_rect(Rect2(rr.position, Vector2(rr.size.x, 10)), Color(0, 0, 0, 0.25))
		c.draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 10), Vector2(rr.size.x, 10)), Color(0, 0, 0, 0.25))
		c.draw_rect(rr, Color(0.25, 0.15, 0.05), false, 2.0)
	var win := state == "result" and last_gross > 0
	var lc := Color(1, 0.85, 0.3, 0.6 + 0.4 * sin(t * 10.0)) if win else Color(0.9, 0.2, 0.25, 0.8)
	c.draw_line(Vector2(44, MID_Y), Vector2(226, MID_Y), lc, 2.0)
	# Paytable (always shown: the odds are posted).
	var s: Dictionary = Casino.data().get("slots", {})
	var three: Dictionary = s.get("three", {})
	var y0 := 240.0
	var keys := ["seven", "crown", "star", "horseshoe", "bar", "bell", "cherry"]
	for j in keys.size():
		var x := 14.0 + (j % 4) * 62.0
		var y := y0 + (j / 4) * 16.0
		_draw_symbol(c, keys[j], Vector2(x + 7, y + 4), 1.0, 0.36)
		text(c, Vector2(x + 16, y + 8), "x3 = %dx" % int(three.get(keys[j], 0)), 46, 7, Color(1, 0.95, 0.8))
	_draw_symbol(c, "cherry", Vector2(14 + 3 * 62.0 + 7, y0 + 20), 1.0, 0.36)
	text(c, Vector2(14 + 3 * 62.0 + 16, y0 + 18), "first 2: %dx" % int(s.get("cherry2", 0)), 50, 7, Color(1, 0.95, 0.8))
	text(c, Vector2(14 + 3 * 62.0 + 16, y0 + 28), "first 1: %dx" % int(s.get("cherry1", 0)), 50, 7, Color(1, 0.95, 0.8))
	draw_bet_strip(c)
	draw_fx(c)


func _draw_symbol(c: Control, sym: String, ctr: Vector2, alpha := 1.0, scale := 1.0) -> void:
	var tx := Art.tex("casino", "sym_" + sym)
	var sz := 30.0 * scale
	if tx:
		c.draw_texture_rect(tx, Rect2(ctr - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, alpha))
		if sym == "bar":
			text(c, ctr + Vector2(-sz * 0.5, sz * 0.12), "BAR", sz, maxi(7, int(9 * scale)), Color(1, 0.85, 0.3, alpha), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var col: Color = SYM_COL.get(sym, Color.GRAY)
	c.draw_circle(ctr, sz * 0.42, Color(col, alpha))
	text(c, ctr + Vector2(-sz * 0.5, sz * 0.18), str(SYM_TXT.get(sym, "?")), sz, maxi(7, int(11 * scale)), Color(1, 1, 1, alpha), HORIZONTAL_ALIGNMENT_CENTER)
