class_name RecDecor
extends Node2D
## Drawn pieces of the Rec Center: the bowling lanes (with villagers bowling on
## the lanes they hold), the arcade carpet, neon on the walls, the high-score
## board, the town sign, and a prize painting in your house.
##   mode: "lanes" | "floor" | "wall" | "board" | "sign" | "house_wall"

const T := 16.0
const TriBatch := preload("res://scripts/tri_batch.gd")

var mode := ""
var map: GameMap = null
var label := ""
var _t := 0.0
var _redraw_t := 0.0
var _tb := TriBatch.new()
var _lanes := {}  # lane n -> {"phase", "t", "x", "hook", "down": [bool x10], "who"}


func _ready() -> void:
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_redraw_t -= delta
	if mode == "lanes":
		_tick_lanes(delta)
		queue_redraw()
	elif mode in ["wall", "board"] and _redraw_t <= 0.0:
		_redraw_t = 0.12
		queue_redraw()


func _draw() -> void:
	match mode:
		"lanes": _draw_lanes()
		"floor": _draw_floor()
		"wall": _draw_wall()
		"board": _draw_board()
		"sign": _draw_sign()
		"house_wall": _draw_house_wall()


# ---- the bowling floor ------------------------------------------------------------

func _lane_defs() -> Array:
	return RecCenter.data().get("lanes", [])


func _draw_lanes() -> void:
	# Everything here is flat colour: one TriBatch, one draw call (was ~130 a frame).
	var tb := _tb
	var foul := float(RecCenter.data().get("lane_foul", 11)) + 1.0
	var gang := not GameState.is_penguins()
	var wood := Color("d9b07a") if not gang else Color("2a2140")
	var wood_line := Color(0.55, 0.38, 0.2, 0.35) if not gang else Color(0.6, 0.3, 1.0, 0.25)
	var gutter := Color("4a4a58")
	# Under everything in the lane zone: the dark deck and the divider strip.
	tb.rect(Rect2(T, 2 * T, (map.cols - 2) * T, (foul - 2) * T), Color("2b2230") if not gang else Color("120c1e"))
	# The centre divider: a carpet runner with the house logo.
	tb.rect(Rect2(7 * T + 2, 2 * T, 2 * T - 4, (foul - 2) * T), Color("6b2a3a") if not gang else Color("3a1460"))
	for i in 6:
		var y := 3.0 * T + i * 22.0
		tb.circle(Vector2(8 * T, y), 3.0, Color(1, 0.85, 0.4, 0.55) if not gang else Color(0.3, 1, 0.9, 0.5 + 0.3 * sin(_t * 3.0 + i)))
	for ln in _lane_defs():
		var x0 := float(ln["x"]) * T
		var r := Rect2(x0, 2 * T, 2 * T, (foul - 2) * T)
		tb.rect(r, gutter)
		tb.rect(Rect2(x0 + 1, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.35))
		tb.rect(Rect2(x0 + 2 * T - 3, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.35))
		var bed := Rect2(x0 + 4, r.position.y, 2 * T - 8, r.size.y)
		tb.rect(bed, wood)
		for bx in range(1, 8):
			tb.seg(Vector2(bed.position.x + bx * 3, bed.position.y), Vector2(bed.position.x + bx * 3, bed.end.y), wood_line, 1.0)
		# Pin deck (a lighter square at the far end), arrows and dots.
		tb.rect(Rect2(bed.position.x, 2 * T, bed.size.x, 22), Color(1, 1, 1, 0.12))
		for k in 5:
			var ax := bed.position.x + 2 + k * 4.5
			var ay := (foul - 3.2) * T + absf(k - 2) * 3.0
			tb.fan(PackedVector2Array([Vector2(ax, ay - 3), Vector2(ax - 1.5, ay + 1), Vector2(ax + 1.5, ay + 1)]), PackedColorArray([Color(0.3, 0.15, 0.1, 0.7) if not gang else Color(0.9, 0.3, 1, 0.9)]))
		tb.rect(Rect2(x0, foul * T - 1, 2 * T, 2), Color("d23a3a"))
		_draw_lane_action(int(ln["n"]), bed)
	# Approach: lighter boards and dots.
	tb.rect(Rect2(T, foul * T + 1, (map.cols - 2) * T, T - 1), Color(1, 1, 1, 0.07))
	for ln in _lane_defs():
		for k in 3:
			tb.circle(Vector2(float(ln["x"]) * T + 8 + k * 8, foul * T + 8), 1.0, Color(0.2, 0.1, 0.05, 0.6))
	tb.flush(self)


## Pins at the far end, and a villager's ball rolling up when the lane is theirs.
func _draw_lane_action(n: int, bed: Rect2) -> void:
	var tb := _tb
	var st: Dictionary = _lanes.get(n, {})
	var down: Array = st.get("down", [])
	var cx := bed.position.x + bed.size.x / 2.0
	var head_y := 2 * T + 18.0
	var phase := str(st.get("phase", ""))
	var k := 0
	for row in 4:
		for i in row + 1:
			var px := cx + (i - row / 2.0) * 5.0
			var py := head_y - row * 4.0
			var gone := k < down.size() and bool(down[k])
			if gone and phase == "scatter":
				var a := clampf(float(st.get("t", 0.0)) / 0.7, 0.0, 1.0)
				var dir := Vector2(px - cx + (0.7 if k % 2 == 0 else -0.7), -3.0).normalized()
				var p := Vector2(px, py) + dir * a * 7.0
				tb.seg(p, p + Vector2(3.0 * signf(dir.x + 0.01), 1.0), Color(1, 1, 1, 1.0 - a), 2.0)
			elif not gone or phase == "roll":
				tb.circle(Vector2(px, py + 1.5), 1.8, Color(0, 0, 0, 0.25))
				tb.rect(Rect2(px - 1.2, py - 3.0, 2.4, 4.5), Color(0.97, 0.96, 0.92))
				tb.rect(Rect2(px - 1.2, py - 2.0, 2.4, 0.9), Color(0.85, 0.15, 0.15))
			k += 1
	if phase == "roll":
		var foul := float(RecCenter.data().get("lane_foul", 11)) + 1.0
		var a2 := clampf(float(st.get("t", 0.0)) / 1.5, 0.0, 1.0)
		var y := lerpf(foul * T - 4, head_y + 2, a2)
		var x := cx + float(st.get("x", 0.0)) * (1.0 - a2) + float(st.get("hook", 0.0)) * a2 * a2
		tb.circle(Vector2(x, y + 1), 3.6, Color(0, 0, 0, 0.3))
		tb.circle(Vector2(x, y), 3.4, st.get("ball", Color("3a7be0")))
		tb.circle(Vector2(x - 1, y - 1), 1.0, Color(1, 1, 1, 0.55))


func _tick_lanes(delta: float) -> void:
	if map == null:
		return
	var taken := RecCenter.lanes_taken()
	for ln in _lane_defs():
		var n := int(ln["n"])
		if not _lanes.has(n):
			_lanes[n] = {"phase": "idle", "t": randf_range(1.0, 5.0), "down": []}
		var st: Dictionary = _lanes[n]
		st["t"] = float(st["t"]) + (delta if str(st["phase"]) != "idle" else -delta)
		match str(st["phase"]):
			"idle":
				if float(st["t"]) <= 0.0 and taken.has(n):
					st["phase"] = "roll"
					st["t"] = 0.0
					st["x"] = randf_range(-6.0, 6.0)
					st["hook"] = randf_range(-5.0, 5.0)
					st["ball"] = [Color("e04848"), Color("3a7be0"), Color("e0b040"), Color("9a50e0"), Color("40c080")][randi() % 5]
					st["who"] = str(taken[n])
			"roll":
				if float(st["t"]) >= 1.5:
					var hits := 10 if randf() < 0.28 else randi_range(4, 9)
					var down := []
					var order := [0, 1, 2, 4, 3, 5, 7, 8, 6, 9]
					order.shuffle()
					for i in 10:
						down.append(false)
					for i in hits:
						down[order[i]] = true
					st["down"] = down
					st["phase"] = "scatter"
					st["t"] = 0.0
					Music.instance(get_tree()).sfx("pin_crash", "thud")
					if hits == 10:
						_cheer(str(st.get("who", "")))
			"scatter":
				if float(st["t"]) >= 2.2:
					st["phase"] = "idle"
					st["down"] = []
					st["t"] = randf_range(4.0, 9.0)


func _cheer(who: String) -> void:
	for n in map.get("npcs"):
		if is_instance_valid(n) and (n as Npc).id == who:
			map.emote(n, "star", 1.2, -30.0)


# ---- ground floor -------------------------------------------------------------------

func _draw_floor() -> void:
	# Arcade carpet under the cabinets: deep blue with confetti (one TriBatch: was ~70 draw calls).
	var tb := _tb
	var gang := not GameState.is_penguins()
	var r := Rect2(7 * T, 2 * T, 7 * T, 3 * T)
	tb.rect(r, Color("1c2048") if not gang else Color("140a24"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cols := [Color("f5c842"), Color("f5486e"), Color("3fdc8c"), Color("3fa9f5"), Color("a46cf5")]
	for i in 70:
		var p := Vector2(rng.randf_range(r.position.x + 2, r.end.x - 2), rng.randf_range(r.position.y + 2, r.end.y - 2))
		var c: Color = cols[i % cols.size()]
		if i % 3 == 0:
			tb.rect(Rect2(p, Vector2(2, 2)), c)
		elif i % 3 == 1:
			tb.seg(p, p + Vector2(3, -1), c, 1.0)
		else:
			tb.arc(p, 1.5, 0, PI, 4, c, 1.0)
	tb.flush(self)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)


func _draw_wall() -> void:
	var lanes := RecCenter.is_rec(map) and bool((map.get("I") as Dictionary).get("lanes", false))
	var pulse := 0.75 + 0.25 * sin(_t * 2.3)
	if lanes:
		# Masking units over the pin decks: lane numbers in neon.
		# The units never overlap: every box and neon bar in one batch, then the numbers.
		var f := ThemeDB.fallback_font
		for ln in _lane_defs():
			var x0 := float(ln["x"]) * T
			var r := Rect2(x0, 8, 2 * T, 24)
			_tb.rect(r, Color("1a1424"))
			_tb.rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Color(0, 0, 0, 0.4))
			_tb.seg(Vector2(x0 + 3, 27), Vector2(x0 + 2 * T - 3, 27), Color(_lane_col(ln), 0.6 * pulse), 1.0)
		_tb.flush(self)
		for ln in _lane_defs():
			var x0 := float(ln["x"]) * T
			draw_string(f, Vector2(x0, 23), str(int(ln["n"])), HORIZONTAL_ALIGNMENT_CENTER, 2 * T, 12, Color(_lane_col(ln), pulse))
		var tx := Art.tex("props", "neon_sign_0")
		if tx:
			draw_texture_rect(tx, Rect2(7 * T + 6, 6, 20, 17), false, Color(1, 1, 1, pulse))
		return
	# Ground floor: neon over the cabinets, flickering out of step.
	var spots := [[9.0, 2], [12.0, 5], [2.0 + 1.0, 6]]
	for i in spots.size():
		var s: Array = spots[i]
		var tx2 := Art.tex("props", "neon_sign_%d" % int(s[1]))
		if tx2 == null:
			continue
		var on := 0.7 + 0.3 * sin(_t * (1.7 + i * 0.6) + i)
		if fmod(_t * (0.9 + i * 0.3), 7.0) < 0.12:
			on = 0.25  # the odd flicker
		draw_texture_rect(tx2, Rect2(float(s[0]) * T, 2, 22, 18), false, Color(1, 1, 1, on))


func _lane_col(ln: Dictionary) -> Color:
	return [Color("f5486e"), Color("3fa9f5"), Color("f5c842"), Color("3fdc8c")][(int(ln["n"]) - 1) % 4]


## The high-score board on legs (ground floor).
func _draw_board() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(-1, -6, 2, 6), Color("3a3a44"))
	var r := Rect2(-13, -26, 26, 20)
	draw_rect(r, Color("8a6a3a"))
	draw_rect(r.grow(-1.5), Color("0d1a14"))
	var g := Color(0.5, 1, 0.7, 0.85 + 0.15 * sin(_t * 2.0))
	draw_string(f, Vector2(r.position.x, r.position.y + 7), "HI-SCORE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 5, g)
	var best := Tickets.best_score("bowling") if not GameState.run.is_empty() else 0
	draw_string(f, Vector2(r.position.x, r.position.y + 14), "BOWL %d" % best, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 5, Color(1, 0.9, 0.4))
	draw_string(f, Vector2(r.position.x, r.position.y + 19), "♦ %d" % (Tickets.count() if not GameState.run.is_empty() else 0), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4, Color(1, 0.7, 0.9))


# ---- outside ---------------------------------------------------------------------

## The town sign (position = bottom centre).
func _draw_sign() -> void:
	var f := ThemeDB.fallback_font
	var open := RecCenter.is_open()
	var gang := not GameState.is_penguins()
	draw_rect(Rect2(-14, -6, 2, 6), Color("5a3a22"))
	draw_rect(Rect2(12, -6, 2, 6), Color("5a3a22"))
	draw_circle(Vector2(0, -1), 15.0, Color(0, 0, 0, 0.0))
	var r := Rect2(-18, -24, 36, 18)
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r, Color("2a1d34") if gang else Color("8a5a32"))
	draw_rect(r.grow(-1.5), Color("1a1024") if gang else Color("b07a44"))
	var txt := RecCenter.name().to_upper()
	var tc := Color(1, 0.4, 0.8) if gang else Color("fff2cc")
	draw_string(f, Vector2(r.position.x, r.position.y + 8), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6, tc)
	# A little pin and ball.
	draw_rect(Rect2(-9, -14, 2, 5), Color.WHITE)
	draw_rect(Rect2(-9, -13, 2, 1), Color("d23a3a"))
	draw_circle(Vector2(-4, -10.5), 2.2, Color("3a7be0") if not gang else Color("ff3fb0"))
	draw_string(f, Vector2(-1, -9), "BOWL · ARCADE", HORIZONTAL_ALIGNMENT_LEFT, 20, 3, tc)
	if not open:
		draw_set_transform(Vector2.ZERO, -0.25)
		draw_rect(Rect2(-20, -16, 40, 6), Color("d23a3a"))
		draw_string(f, Vector2(-20, -11.5), "OPENING SOON", HORIZONTAL_ALIGNMENT_CENTER, 40, 5, Color.WHITE)
		draw_set_transform(Vector2.ZERO)


## A wall picture in your house (position = where it hangs, bottom centre).
func _draw_house_wall() -> void:
	var t := Art.tex("items", label)
	if t == null:
		return
	var s := 18.0 / maxf(1.0, float(t.get_height()))
	var sz := Vector2(t.get_width(), t.get_height()) * s
	draw_texture_rect(t, Rect2(-sz.x / 2.0, -sz.y, sz.x, sz.y), false)
