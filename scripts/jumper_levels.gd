class_name JumperLevels
extends RefCounted
## Block Jumper's world: level definitions, the seeded level builder, the
## physics step (shared by the game and the solver) and a solver that proves
## every level can be finished without the double jump.
##
## World units are pixels; y grows down, world y 0 is the top of the play area
## (328 px tall). The player is a 12 px wide box whose feet are at st[Y].

const W_PLAYER := 6.0      # half width
const H_STAND := 14.0
const H_DUCK := 7.0
const G := 1150.0
const JUMP_V := 330.0
const HOLD_G := 480.0
const HOLD_T := 0.22
const FALL_MAX := 560.0
const FAST_FALL := 1500.0
const COYOTE := 0.08
const BUFFER := 0.12
const KILL_Y := 345.0
const BUCKET := 64.0
const GY0 := 248.0          # usual ground top
const GY_MIN := 184.0
const GY_MAX := 288.0
const CEIL_GAP := 10.0      # a ceiling's underside sits this far above the ground
const CHECK_SECS := 8.0     # seconds of running between checkpoints
const CHECK_CALM := 1.2     # seconds of flat ground after a checkpoint flag

# State array slots (an Array so the solver can copy thousands cheaply).
const X := 0
const Y := 1
const VY := 2
const GND := 3     # 1 on the ground
const REF := 4     # mover index under the feet, -1 none
const HGT := 5
const HOLD := 6
const COY := 7
const BUF := 8
const AIRJ := 9
const T := 10
const AP := 11     # A held last frame
const DOWNP := 12  # down held last frame

## The eight levels. kinds = chunk weights; run = runway between chunks (px).
const LEVELS := [
	{"name": "Meadow Dash", "theme": 0, "speed0": 92.0, "speed1": 106.0, "length": 2400.0, "seed": 11, "diff": 0.0,
		"kinds": {"gap": 3, "spikes": 3, "block": 2}, "run": [110, 170]},
	{"name": "Pebble Path", "theme": 1, "speed0": 98.0, "speed1": 116.0, "length": 2900.0, "seed": 23, "diff": 0.15,
		"kinds": {"gap": 3, "spikes": 3, "block": 2, "step": 3}, "run": [96, 150]},
	{"name": "Duck & Run", "theme": 2, "speed0": 104.0, "speed1": 122.0, "length": 3400.0, "seed": 37, "diff": 0.25,
		"kinds": {"gap": 2, "spikes": 2, "block": 2, "step": 2, "ceiling": 4}, "run": [90, 140]},
	{"name": "Cloud Hops", "theme": 3, "speed0": 108.0, "speed1": 128.0, "length": 3900.0, "seed": 41, "diff": 0.38,
		"kinds": {"gap": 2, "spikes": 2, "step": 1, "ceiling": 2, "plats": 4}, "run": [84, 130]},
	{"name": "Gear Works", "theme": 4, "speed0": 114.0, "speed1": 136.0, "length": 4500.0, "seed": 53, "diff": 0.5,
		"kinds": {"gap": 2, "spikes": 2, "block": 1, "ceiling": 2, "plats": 2, "mover": 4, "combo": 1}, "run": [78, 120]},
	{"name": "Spike Garden", "theme": 5, "speed0": 120.0, "speed1": 144.0, "length": 5100.0, "seed": 67, "diff": 0.64,
		"kinds": {"gap": 2, "spikes": 4, "block": 1, "step": 1, "ceiling": 2, "plats": 1, "mover": 2, "pit": 4, "combo": 2}, "run": [72, 112]},
	{"name": "Night Rush", "theme": 6, "speed0": 128.0, "speed1": 154.0, "length": 5800.0, "seed": 79, "diff": 0.8,
		"kinds": {"gap": 3, "spikes": 3, "block": 2, "step": 2, "ceiling": 3, "plats": 2, "mover": 3, "pit": 3, "combo": 3}, "run": [66, 104]},
	{"name": "Star Gauntlet", "theme": 7, "speed0": 138.0, "speed1": 166.0, "length": 6600.0, "seed": 97, "diff": 1.0,
		"kinds": {"gap": 3, "spikes": 3, "block": 2, "step": 2, "ceiling": 3, "plats": 3, "mover": 3, "pit": 3, "combo": 4}, "run": [60, 96]},
]
const ENDLESS := {"name": "Endless Run", "theme": -1, "speed0": 105.0, "speed1": 105.0, "length": 1.0e9, "seed": 0, "diff": 0.0,
	"kinds": {"gap": 3, "spikes": 3, "block": 2, "step": 2, "ceiling": 2, "plats": 2, "mover": 2, "pit": 2}, "run": [80, 140]}

## Palettes: sky top, sky bottom, far hills, near hills, ground top, ground body, accent.
const THEMES := [
	[Color("5fb6ff"), Color("c9f0ff"), Color("8fc6e8"), Color("6fbf6a"), Color("7fd85a"), Color("8a5a3a"), Color("ffe066")],
	[Color("f28c6a"), Color("ffd9a0"), Color("c98a8a"), Color("9a7a6a"), Color("c8b38a"), Color("6e5848"), Color("fff0a0")],
	[Color("3f8f6a"), Color("a6e0b0"), Color("2f6f55"), Color("3f7f45"), Color("6ccf5a"), Color("4e3a2a"), Color("ffd060")],
	[Color("7fa8ff"), Color("ffffff"), Color("dfe8ff"), Color("c8d8ff"), Color("ffffff"), Color("b8c8e8"), Color("ff9ad0")],
	[Color("4a4a5a"), Color("9a8a7a"), Color("3a3a48"), Color("5a5048"), Color("c08a3a"), Color("5a5a66"), Color("ffb040")],
	[Color("d080c0"), Color("ffd0e8"), Color("b070a8"), Color("9a5a90"), Color("8ad87a"), Color("6a4a5a"), Color("ff6aa0")],
	[Color("101838"), Color("34386a"), Color("1c2450"), Color("242c5a"), Color("5a8aff"), Color("2a2a48"), Color("a0e0ff")],
	[Color("05040f"), Color("2a1650"), Color("1a1040"), Color("2a1a5a"), Color("ffd040"), Color("3a2a6a"), Color("ff70ff")],
]


static func level_def(n: int) -> Dictionary:
	if n <= 0:
		return ENDLESS
	return LEVELS[clampi(n - 1, 0, LEVELS.size() - 1)]


static func theme(n: int, x := 0.0) -> Array:
	if n <= 0:
		return THEMES[int(x / 6400.0) % THEMES.size()]
	return THEMES[int(level_def(n)["theme"]) % THEMES.size()]


# --- building ------------------------------------------------------------------

## A fresh level (n = 1..8; 0 = endless, built on demand with extend()).
static func build(n: int, dbl := false, seed_override := -1) -> Dictionary:
	var d := level_def(n)
	var lv := {
		"n": n, "def": d, "solids": [], "plats": [], "movers": [], "spikes": [], "coins": [],
		"checks": [], "buckets": {}, "finish": 1.0e9, "dbl": dbl, "gx": 0.0, "gy": GY0,
		"speed0": float(d["speed0"]), "speed1": float(d["speed1"]), "length": float(d["length"]),
		"next_check": 0.0, "rng": RandomNumberGenerator.new(), "done": false,
	}
	var r: RandomNumberGenerator = lv["rng"]
	r.seed = int(d["seed"]) * 7919 + 13 if seed_override < 0 else seed_override
	_ground(lv, -200.0, 720.0, GY0)
	_coin_line(lv, 200.0, 440.0, GY0 - 8.0, 48.0)
	lv["gx"] = 520.0
	# A checkpoint about every 8 seconds of running (endless: every 1600 px).
	lv["check_every"] = (float(d["speed0"]) + float(d["speed1"])) * 0.5 * CHECK_SECS if n > 0 else 1600.0
	lv["next_check"] = float(lv["check_every"])
	if n > 0:
		extend(lv, float(d["length"]))
		_finish(lv)
	else:
		extend(lv, 2400.0)
	return lv


static func speed_at(lv: Dictionary, x: float) -> float:
	if int(lv["n"]) <= 0:
		return minf(105.0 + maxf(x, 0.0) * 0.0055, 190.0)
	return lerpf(float(lv["speed0"]), float(lv["speed1"]), clampf(x / float(lv["length"]), 0.0, 1.0))


## The run is on rails: x after k frames is the same on every try, so the
## clock (which drives the moving platforms) is a function of x. A respawn
## state at x (snapped to the frame grid) with the same clock as a straight
## run, so movers are always in the phase the level was solved with.
static func respawn_state(lv: Dictionary, x: float, y: float) -> Array:
	var fx := _frame_at(lv, x)
	var st := new_state(float(fx[0]), y)
	st[T] = int(fx[1]) / 60.0
	return st


## Seconds into a straight run when the player reaches x.
static func time_at(lv: Dictionary, x: float) -> float:
	return int(_frame_at(lv, x)[1]) / 60.0


## [x on the frame grid at or past x, frames to get there].
static func _frame_at(lv: Dictionary, x: float) -> Array:
	var px := 0.0
	var k := 0
	var dt := 1.0 / 60.0
	while px < x - 0.001 and k < 60 * 3600:
		px += speed_at(lv, px) * dt
		k += 1
	return [px, k]


static func diff_at(lv: Dictionary, x: float) -> float:
	if int(lv["n"]) <= 0:
		return clampf(x / 14000.0, 0.0, 1.0)
	return float(lv["def"]["diff"])


## Horizontal distance of a jump at this speed (full hold, or a tap), feet to feet.
static func reach(sp: float, full := true) -> float:
	var vy := -JUMP_V
	var y := 0.0
	var hold := HOLD_T
	var tt := 0.0
	var dt := 1.0 / 60.0
	while tt < 3.0:
		var g := G
		if vy < 0.0 and full and hold > 0.0:
			g = HOLD_G
			hold -= dt
		vy = minf(vy + g * dt, FALL_MAX)
		y += vy * dt
		tt += dt
		if y >= 0.0 and vy > 0.0:
			break
	return sp * tt


## Builds level geometry up to x (endless calls this as you run).
static func extend(lv: Dictionary, to_x: float) -> void:
	var d: Dictionary = lv["def"]
	var r: RandomNumberGenerator = lv["rng"]
	while float(lv["gx"]) < to_x:
		var x := float(lv["gx"])
		var kinds: Dictionary = d["kinds"]
		if int(lv["n"]) <= 0:
			kinds = _endless_kinds(diff_at(lv, x))
		var kind := _pick(kinds, r)
		_chunk(lv, kind)
		# Runway: time to land, read the next thing and react.
		var sp := speed_at(lv, float(lv["gx"]))
		var run_r: Array = d["run"]
		var dd := diff_at(lv, x)
		var run := r.randf_range(float(run_r[0]), float(run_r[1]))
		if int(lv["n"]) <= 0:
			run = lerpf(150.0, 70.0, dd) * r.randf_range(0.85, 1.2)
		# Harder levels leave less room between obstacles (quicker rhythm).
		run = maxf(run, sp * lerpf(0.5, 0.4, dd))
		var gx := float(lv["gx"])
		var gy := float(lv["gy"])
		# A checkpoint flag stands at the start of a long calm runway, so a
		# respawn never drops you straight onto an obstacle.
		var flag := gx + run >= float(lv["next_check"]) and gx + run < float(lv["length"]) - 200.0
		if flag:
			run = maxf(run, sp * CHECK_CALM + 24.0)
		_ground(lv, gx, run, gy)
		if r.randf() < 0.5:
			_coin_line(lv, gx + 16.0, gx + run - 16.0, gy - 8.0, 20.0)
		if flag:
			(lv["checks"] as Array).append(Vector2(gx + 24.0, gy))
			lv["next_check"] = gx + 24.0 + float(lv["check_every"])
		lv["gx"] = gx + run


static func _endless_kinds(dd: float) -> Dictionary:
	var k := {"gap": 3, "spikes": 3, "block": 2, "step": 2}
	if dd > 0.1:
		k["ceiling"] = 2
	if dd > 0.2:
		k["plats"] = 2
	if dd > 0.35:
		k["mover"] = 2
	if dd > 0.5:
		k["pit"] = 2
	if dd > 0.6:
		k["combo"] = 2
	return k


static func _pick(kinds: Dictionary, r: RandomNumberGenerator) -> String:
	var tot := 0.0
	for k in kinds:
		tot += float(kinds[k])
	var v := r.randf() * tot
	for k in kinds:
		v -= float(kinds[k])
		if v <= 0.0:
			return str(k)
	return str(kinds.keys()[0])


static func _chunk(lv: Dictionary, kind: String) -> void:
	var r: RandomNumberGenerator = lv["rng"]
	var x := float(lv["gx"])
	var gy := float(lv["gy"])
	var sp := speed_at(lv, x)
	var rf := reach(sp, true)
	var dd := diff_at(lv, x)
	match kind:
		"gap":
			var dy := 0.0
			var roll := r.randf()
			if roll < 0.2 and gy - 16.0 >= GY_MIN:
				dy = -16.0
			elif roll < 0.45 and gy + 32.0 <= GY_MAX:
				dy = [16.0, 32.0][r.randi() % 2]
			var w := r.randf_range(lerpf(0.3, 0.42, dd), lerpf(0.5, 0.8, dd)) * rf + 12.0
			if dy < 0.0:
				w *= 0.8
			w = maxf(w, 28.0)
			_coin_arc(lv, x, x + w, gy, minf(gy, gy + dy))
			lv["gy"] = gy + dy
			lv["gx"] = x + w
		"spikes":
			var n := clampi(1 + r.randi_range(0, int(round(dd * 2.0))), 1, 3)
			while n > 1 and n * 16.0 > 0.55 * rf:
				n -= 1
			_ground(lv, x, n * 16.0, gy)
			for i in n:
				_add(lv, "spikes", Rect2(x + i * 16.0, gy - 12.0, 16.0, 12.0))
			_coin_arc(lv, x - 8.0, x + n * 16.0 + 8.0, gy, gy)
			lv["gx"] = x + n * 16.0
		"block":
			var w2 := 16.0 if r.randf() < 0.6 else 32.0
			var h2 := 16.0 if (r.randf() < 0.6 or dd < 0.3) else 32.0
			_ground(lv, x, w2, gy)
			_add(lv, "solids", Rect2(x, gy - h2, w2, h2))
			_add(lv, "coins", Vector2(x + w2 * 0.5, gy - h2 - 10.0))
			lv["gx"] = x + w2
		"step":
			var up := r.randf() < 0.5
			var dy2 := 0.0
			if up and gy - 16.0 >= GY_MIN:
				dy2 = -16.0 if (dd < 0.4 or r.randf() < 0.5 or gy - 32.0 < GY_MIN) else -32.0
			elif gy + 16.0 <= GY_MAX:
				dy2 = minf(GY_MAX - gy, [16.0, 32.0, 48.0][r.randi() % 3])
			else:
				dy2 = -16.0
			lv["gy"] = gy + dy2
			_ground(lv, x, 32.0, gy + dy2)
			_add(lv, "coins", Vector2(x + 16.0, gy + dy2 - 10.0))
			lv["gx"] = x + 32.0
		"ceiling":
			var w3 := r.randf_range(32.0, 48.0 + dd * 72.0)
			_ground(lv, x, w3, gy)
			_add(lv, "solids", Rect2(x, -400.0, w3, 400.0 + gy - CEIL_GAP))
			var cx := x + 12.0
			while cx < x + w3 - 4.0:
				_add(lv, "coins", Vector2(cx, gy - 4.0))
				cx += 22.0
			lv["gx"] = x + w3
		"plats":
			var k := 1 + r.randi_range(0, 1 + int(dd * 1.5))
			var px := x
			var py := gy
			for i in k:
				var g := r.randf_range(0.28, lerpf(0.45, 0.62, dd)) * rf + 12.0
				var pw := r.randf_range(32.0, 52.0)
				var ny := clampf(py - [0.0, 8.0, 16.0, 24.0, -16.0][r.randi() % 5], GY_MIN - 24.0, GY_MAX - 8.0)
				_coin_arc(lv, px, px + g, py, ny)
				_add(lv, "plats", Rect2(px + g, ny, pw, 6.0))
				px += g + pw
				py = ny
			var g2 := r.randf_range(0.28, 0.48) * rf + 12.0
			var ngy := clampf(py + [0.0, 16.0, 0.0][r.randi() % 3], GY_MIN, GY_MAX)
			ngy = maxf(ngy, py - 16.0)
			lv["gy"] = snappedf(ngy, 8.0)
			lv["gx"] = px + g2
		"mover":
			var vertical := r.randf() < 0.6
			var mw := 48.0
			var amp := r.randf_range(14.0, 26.0) if vertical else r.randf_range(14.0, 22.0)
			var g1 := r.randf_range(0.25, 0.42) * rf + 12.0
			var per := r.randf_range(1.8, 2.6)
			var ph0 := r.randf()
			# Timed to the run (the clock is a function of x): a sliding
			# platform swings in toward you as you reach the edge, a lift is
			# level with the ground while you're in the air.
			var ta := time_at(lv, x) + (0.3 if not vertical else 0.25) + (ph0 - 0.5) * 0.2
			var ph := -PI * 0.5 - TAU * ta / per if not vertical else -TAU * ta / per
			var mv := {"x": x + g1 + (0.0 if vertical else amp), "y": gy, "w": mw, "ax": 0.0 if vertical else amp,
				"ay": amp if vertical else 0.0, "per": per, "ph": ph}
			_add(lv, "movers", mv)
			var g3 := r.randf_range(0.25, 0.42) * rf + 12.0
			var end := float(mv["x"]) + mw + float(mv["ax"]) + g3
			_add(lv, "coins", Vector2(float(mv["x"]) + mw * 0.5, gy - 14.0))
			lv["gx"] = end
		"combo":
			# Two moves back to back: a gap whose landing pad leads straight
			# into spikes (jump again) or a low ceiling (duck at once).
			var wg := r.randf_range(0.4, lerpf(0.55, 0.72, dd)) * rf + 12.0
			_coin_arc(lv, x, x + wg, gy, gy)
			var pad := r.randf_range(0.42, 0.6) * rf
			var cx3 := x + wg
			var spiky := r.randf() < 0.55
			if not spiky:
				pad = maxf(pad, 0.62 * rf)
			_ground(lv, cx3, pad, gy)
			if spiky:
				var ns := 1 + int(r.randf() < dd * 0.7)
				_ground(lv, cx3 + pad, ns * 16.0, gy)
				for i in ns:
					_add(lv, "spikes", Rect2(cx3 + pad + i * 16.0, gy - 12.0, 16.0, 12.0))
				_coin_arc(lv, cx3 + pad - 8.0, cx3 + pad + ns * 16.0 + 8.0, gy, gy)
				lv["gx"] = cx3 + pad + ns * 16.0
			else:
				var wc := r.randf_range(32.0, 56.0)
				_ground(lv, cx3 + pad, wc, gy)
				_add(lv, "solids", Rect2(cx3 + pad, -400.0, wc, 400.0 + gy - CEIL_GAP))
				_add(lv, "coins", Vector2(cx3 + pad + wc * 0.5, gy - 4.0))
				lv["gx"] = cx3 + pad + wc
		"pit":
			var w4 := r.randf_range(64.0, 96.0 + dd * 48.0)
			var lead := r.randf_range(16.0, 24.0)
			_ground(lv, x, w4, gy)
			var sx := x
			while sx < x + w4 - 1.0:
				_add(lv, "spikes", Rect2(sx, gy - 12.0, 16.0, 12.0))
				sx += 16.0
			w4 = sx - x
			_ground(lv, x + w4, 0.0, gy)
			_add(lv, "plats", Rect2(x + lead, gy - 30.0, w4 - lead * 2.0, 6.0))
			var cx2 := x + lead + 10.0
			while cx2 < x + w4 - lead - 6.0:
				_add(lv, "coins", Vector2(cx2, gy - 40.0))
				cx2 += 20.0
			lv["gx"] = x + w4


static func _finish(lv: Dictionary) -> void:
	var gx := float(lv["gx"])
	var gy := float(lv["gy"])
	_ground(lv, gx, 600.0, gy)
	lv["finish"] = gx + 120.0
	lv["finish_y"] = gy
	lv["gx"] = gx + 600.0
	lv["done"] = true


static func _ground(lv: Dictionary, x: float, w: float, gy: float) -> void:
	if w <= 0.0:
		return
	_add(lv, "solids", Rect2(x, gy, w, 420.0 - gy))


static func _coin_line(lv: Dictionary, x0: float, x1: float, y: float, step: float) -> void:
	var x := x0
	while x <= x1:
		_add(lv, "coins", Vector2(x, y))
		x += step


## Three coins over an obstacle, along a jump-ish arc.
static func _coin_arc(lv: Dictionary, x0: float, x1: float, y0: float, y1: float) -> void:
	for i in 3:
		var f := (i + 1) / 4.0
		var y := lerpf(y0, y1, f) - 12.0 - sin(f * PI) * 24.0
		_add(lv, "coins", Vector2(lerpf(x0, x1, f), y))


static func _add(lv: Dictionary, kind: String, v: Variant) -> void:
	var arr: Array = lv[kind]
	arr.append(v)
	var i := arr.size() - 1
	var x0: float
	var x1: float
	if v is Rect2:
		x0 = (v as Rect2).position.x
		x1 = (v as Rect2).end.x
	elif v is Vector2:
		x0 = (v as Vector2).x
		x1 = x0
	else:
		var d: Dictionary = v
		x0 = float(d["x"]) - float(d["ax"])
		x1 = float(d["x"]) + float(d["w"]) + float(d["ax"])
	var bk: Dictionary = lv["buckets"]
	for c in range(int(floor(x0 / BUCKET)), int(floor(x1 / BUCKET)) + 1):
		if not bk.has(c):
			bk[c] = {"solids": [], "plats": [], "movers": [], "spikes": [], "coins": []}
		(bk[c][kind] as Array).append(i)


## Indices of one kind near [x0, x1].
static func near(lv: Dictionary, kind: String, x0: float, x1: float) -> Array:
	var bk: Dictionary = lv["buckets"]
	var c0 := int(floor(x0 / BUCKET))
	var c1 := int(floor(x1 / BUCKET))
	if c0 == c1:
		return bk[c0][kind] if bk.has(c0) else []
	var out: Array = []
	for c in range(c0, c1 + 1):
		if bk.has(c):
			for i in bk[c][kind]:
				if not out.has(i):
					out.append(i)
	return out


static func mover_rect(m: Dictionary, tt: float) -> Rect2:
	var s := sin(TAU * tt / float(m["per"]) + float(m["ph"]))
	return Rect2(float(m["x"]) + s * float(m["ax"]), float(m["y"]) + s * float(m["ay"]), float(m["w"]), 8.0)


# --- physics -----------------------------------------------------------------

static func new_state(x: float, y: float) -> Array:
	return [x, y, 0.0, 1, -1, H_STAND, 0.0, COYOTE, 0.0, 0, 0.0, false, false]


static func _box_hits(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> bool:
	return x0 < r.end.x and x1 > r.position.x and y0 < r.end.y - 0.01 and y1 > r.position.y + 0.01


static func _solid_hit(lv: Dictionary, x: float, y: float, h: float) -> bool:
	var solids: Array = lv["solids"]
	for i: int in near(lv, "solids", x - W_PLAYER, x + W_PLAYER):
		if _box_hits(solids[i], x - W_PLAYER, y - h, x + W_PLAYER, y):
			return true
	return false


## Height of what's under the feet (or INF): solids/platforms exactly, movers loosely.
static func _support(lv: Dictionary, st: Array) -> Array:
	var x := float(st[X])
	var y := float(st[Y])
	var best := INF
	var ref := -1
	var solids: Array = lv["solids"]
	for i: int in near(lv, "solids", x - W_PLAYER, x + W_PLAYER):
		var s: Rect2 = solids[i]
		if x - W_PLAYER < s.end.x and x + W_PLAYER > s.position.x and absf(s.position.y - y) < 0.6:
			best = minf(best, s.position.y)
	var plats: Array = lv["plats"]
	for i: int in near(lv, "plats", x - W_PLAYER, x + W_PLAYER):
		var p: Rect2 = plats[i]
		if x - W_PLAYER < p.end.x and x + W_PLAYER > p.position.x and absf(p.position.y - y) < 0.6:
			best = minf(best, p.position.y)
	var movers: Array = lv["movers"]
	for i: int in near(lv, "movers", x - W_PLAYER, x + W_PLAYER):
		var mr := mover_rect(movers[i], float(st[T]))
		if x - W_PLAYER < mr.end.x and x + W_PLAYER > mr.position.x and absf(mr.position.y - y) < 6.0:
			if best == INF or mr.position.y < best:
				best = mr.position.y
				ref = i
	return [best, ref]


## One 60 Hz step. Returns "", "jump", "djump", "land", "bonk", "dead" or "win".
static func step(st: Array, lv: Dictionary, a: bool, down: bool, dt := 1.0 / 60.0) -> String:
	var ev := ""
	var a_jp: bool = a and not bool(st[AP])
	st[AP] = a
	st[DOWNP] = down
	var x := float(st[X])
	var sp := speed_at(lv, x)
	# Duck (only on the ground); stay ducked while a ceiling is overhead.
	var h := H_DUCK if (down and int(st[GND]) == 1) else H_STAND
	if h == H_STAND and float(st[HGT]) == H_DUCK and _solid_hit(lv, x, float(st[Y]), H_STAND):
		h = H_DUCK
	st[HGT] = h
	# Coyote time and jump buffer.
	st[COY] = COYOTE if int(st[GND]) == 1 else float(st[COY]) - dt
	st[BUF] = BUFFER if a_jp else float(st[BUF]) - dt
	if float(st[BUF]) > 0.0 and float(st[COY]) > 0.0 and not _solid_hit(lv, x, float(st[Y]) - 1.0, H_STAND):
		st[VY] = -JUMP_V
		st[HOLD] = HOLD_T
		st[GND] = 0
		st[REF] = -1
		st[COY] = 0.0
		st[BUF] = 0.0
		st[HGT] = H_STAND
		ev = "jump"
	elif a_jp and int(st[GND]) == 0 and bool(lv["dbl"]) and int(st[AIRJ]) == 0 and float(st[COY]) <= 0.0:
		st[VY] = -JUMP_V * 0.9
		st[HOLD] = HOLD_T * 0.5
		st[AIRJ] = 1
		st[BUF] = 0.0
		ev = "djump"
	# Gravity (lighter while A is held on the way up).
	if int(st[GND]) == 0:
		var g := G
		if float(st[VY]) < 0.0 and a and float(st[HOLD]) > 0.0:
			g = HOLD_G
			st[HOLD] = float(st[HOLD]) - dt
		elif not a:
			st[HOLD] = 0.0
		if down:
			g += FAST_FALL
		st[VY] = minf(float(st[VY]) + g * dt, FALL_MAX * (1.5 if down else 1.0))
	h = float(st[HGT])
	# Run forward: running into a wall's face ends the run.
	var nx := x + sp * dt
	var y := float(st[Y])
	var solids: Array = lv["solids"]
	for i: int in near(lv, "solids", nx - W_PLAYER, nx + W_PLAYER):
		var s: Rect2 = solids[i]
		if _box_hits(s, nx - W_PLAYER, y - h, nx + W_PLAYER, y):
			if y - s.position.y <= 4.0 and float(st[VY]) >= 0.0 and not _solid_hit(lv, nx, s.position.y, h):
				y = s.position.y  # a tiny lip: step up onto it
				st[GND] = 1
				st[VY] = 0.0
			else:
				st[X] = nx
				return "dead"
	st[X] = nx
	x = nx
	st[T] = float(st[T]) + dt
	# Vertical.
	if int(st[GND]) == 1:
		st[Y] = y
		var sup := _support(lv, st)
		if float(sup[0]) == INF:
			st[GND] = 0
			st[REF] = -1
		else:
			st[Y] = float(sup[0])
			st[REF] = int(sup[1])
			st[AIRJ] = 0
	else:
		var vy := float(st[VY])
		var ny := y + vy * dt
		if vy >= 0.0:
			var land := INF
			var ref := -1
			for i: int in near(lv, "solids", x - W_PLAYER, x + W_PLAYER):
				var s2: Rect2 = solids[i]
				if x - W_PLAYER < s2.end.x and x + W_PLAYER > s2.position.x and s2.position.y >= y - 0.01 and s2.position.y <= ny and s2.position.y < land:
					land = s2.position.y
			var plats: Array = lv["plats"]
			for i: int in near(lv, "plats", x - W_PLAYER, x + W_PLAYER):
				var p: Rect2 = plats[i]
				if x - W_PLAYER < p.end.x and x + W_PLAYER > p.position.x and p.position.y >= y - 0.01 and p.position.y <= ny and p.position.y < land:
					land = p.position.y
			var movers: Array = lv["movers"]
			for i: int in near(lv, "movers", x - W_PLAYER, x + W_PLAYER):
				var mr := mover_rect(movers[i], float(st[T]))
				if x - W_PLAYER < mr.end.x and x + W_PLAYER > mr.position.x and mr.position.y >= y - 5.0 and mr.position.y <= ny + 1.0 and mr.position.y < land:
					land = mr.position.y
					ref = i
			if land != INF:
				st[Y] = land
				st[VY] = 0.0
				st[GND] = 1
				st[REF] = ref
				st[AIRJ] = 0
				st[HOLD] = 0.0
				ev = "land"
			else:
				st[Y] = ny
		else:
			for i: int in near(lv, "solids", x - W_PLAYER, x + W_PLAYER):
				var s3: Rect2 = solids[i]
				if x - W_PLAYER < s3.end.x and x + W_PLAYER > s3.position.x and s3.end.y <= y - h + 0.01 and ny - h < s3.end.y:
					ny = s3.end.y + h
					st[VY] = 0.0
					st[HOLD] = 0.0
					ev = "bonk"
			st[Y] = ny
	y = float(st[Y])
	# Spikes have a forgiving hitbox (the inner part of the triangle).
	var spikes: Array = lv["spikes"]
	for i: int in near(lv, "spikes", x - W_PLAYER, x + W_PLAYER):
		var k: Rect2 = spikes[i]
		if _box_hits(Rect2(k.position.x + 4.0, k.position.y + 5.0, 8.0, 7.0), x - W_PLAYER + 1.0, y - h + 1.0, x + W_PLAYER - 1.0, y):
			return "dead"
	if y > KILL_Y:
		return "dead"
	if x >= float(lv["finish"]):
		return "win"
	return ev


# --- solver ------------------------------------------------------------------

## Breadth-first over every frame's input (nothing / hold A / hold down), merging
## states that match, to prove the level can be finished. Returns
## {"ok", "x" (furthest), "frames", "plan" (A/down per frame when ok)}.
## from_x/from_y: start there (a checkpoint) on the straight run's clock;
## to_x: stop once past it (the next checkpoint) instead of at the goal.
static func solve(lv: Dictionary, from_x := 0.0, beam := 150, from_y := GY0, to_x := INF) -> Dictionary:
	var start := respawn_state(lv, from_x, from_y)
	var sup := _support(lv, start)
	if float(sup[0]) != INF:
		start[Y] = float(sup[0])
	var frontier: Array = [[start, null]]
	var frames := 0
	var acts := [[false, false], [true, false], [false, true]]
	var best_x := from_x
	while not frontier.is_empty() and frames < 60 * 120:
		frames += 1
		var seen := {}
		var nxt: Array = []
		for node: Array in frontier:
			var st0: Array = node[0]
			for ai in 3:
				var st := st0.duplicate()
				var ev := step(st, lv, bool(acts[ai][0]), bool(acts[ai][1]))
				if ev == "dead":
					continue
				var link := [ai, node[1]]
				if ev == "win" or float(st[X]) >= to_x:
					var plan: Array = []
					var l: Variant = link
					while l != null:
						plan.push_front(int((l as Array)[0]))
						l = (l as Array)[1]
					return {"ok": true, "x": float(st[X]), "frames": frames, "plan": plan}
				var key := "%d|%d|%d|%d|%d|%d|%d" % [int(round(float(st[Y]) / 2.0)), int(round(float(st[VY]) / 40.0)), int(st[GND]), int(st[AP]),
					int(ceil(float(st[HOLD]) * 10.0)), int(float(st[HGT])), int(float(st[BUF]) > 0.0) + 2 * int(float(st[COY]) > 0.0)]
				if seen.has(key):
					continue
				seen[key] = true
				nxt.append([st, link])
				best_x = maxf(best_x, float(st[X]))
		if nxt.size() > beam:
			# Keep every grounded state (few, and they hold all the options), then
			# an even spread of the airborne ones by height.
			var kept: Array = []
			var air: Array = []
			for n2: Array in nxt:
				if int(n2[0][GND]) == 1:
					kept.append(n2)
				else:
					air.append(n2)
			air.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0][Y]) < float(q[0][Y]))
			var room := maxi(0, beam - kept.size())
			if air.size() <= room:
				kept.append_array(air)
			else:
				var stepf := float(air.size()) / room
				for i in room:
					kept.append(air[int(i * stepf)])
			nxt = kept
		frontier = nxt
	return {"ok": false, "x": best_x, "frames": frames, "plan": []}


# --- stored plans --------------------------------------------------------------
## data/jumper_plans.json keeps one finishing input plan per level (written by
## tools/jumper_solve.gd --solve), run-length coded: [[action, frames], ...]
## with action 0 nothing / 1 hold A / 2 hold down. check.sh replays them.

const PLANS := "res://data/jumper_plans.json"


static func rle(plan: Array) -> Array:
	var out: Array = []
	for a: int in plan:
		if not out.is_empty() and int(out[-1][0]) == a:
			out[-1][1] = int(out[-1][1]) + 1
		else:
			out.append([a, 1])
	return out


static func unrle(r: Array) -> Array:
	var out: Array = []
	for pair: Array in r:
		for i in int(pair[1]):
			out.append(int(pair[0]))
	return out


static func stored_plan(n: int) -> Array:
	if not FileAccess.file_exists(PLANS):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANS))
	if not (d is Dictionary) or not (d as Dictionary).has(str(n)):
		return []
	return unrle((d as Dictionary)[str(n)])


## Plays a plan through the real physics: "win", "dead" or "short".
## From a checkpoint: start (x, y) and stop at to_x ("win" once past it).
static func replay(lv: Dictionary, plan: Array, start := Vector2(0.0, GY0), to_x := INF) -> String:
	var st := respawn_state(lv, start.x, start.y)
	var acts := [[false, false], [true, false], [false, true]]
	for a: int in plan:
		var ev := step(st, lv, bool(acts[a][0]), bool(acts[a][1]))
		if ev == "win" or ev == "dead":
			return ev
		if float(st[X]) >= to_x:
			return "win"
	return "short"


## Stored plan from checkpoint i of level n (key "n@i"; [] if none).
static func stored_check_plan(n: int, i: int) -> Array:
	if not FileAccess.file_exists(PLANS):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANS))
	var key := "%d@%d" % [n, i]
	if not (d is Dictionary) or not (d as Dictionary).has(key):
		return []
	return unrle((d as Dictionary)[key])
