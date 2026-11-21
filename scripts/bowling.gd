class_name Bowling
extends CanvasLayer
## Ten-pin bowling at the Rec Center: a full-screen mini-game.
##   1) Line up: drag the ball (or LEFT/RIGHT) along the foul line, UP/DOWN or the
##      spin buttons set the hook. GO (or a tap on the lane).
##   2) Aim: the predicted path sweeps across the lane; tap to lock it.
##   3) Power: the bar rises and falls; stop it in the gold band for a clean release
##      (outside it the ball wanders, and a slow ball hooks more than the preview).
## Ten frames, real scoring (strikes, spares, the 10th frame's bonus balls), a score
## sheet on the overhead monitor, a pinsetter sweep between balls, pins with simple
## 2D physics (Sim: fallen pins lie down as sticks and take out their neighbours).
## Challenge a villager on their lane: they bowl each frame on their own rack
## (RecCenter.bowl_avg -> opponent(): skill, hook, ticket bonus). B (or MENU, or ✕) twice leaves the game.
##
##   var res := await Bowling.play(map, lane, "gideon")
##   # {"done", "score", "strikes", "spares", "rolls"[, "opponent", "opp_score", "won", "bonus"]}

signal closed

# ---- scoring -----------------------------------------------------------------------

## Running totals per frame for the rolls so far (-1 where a frame can't be scored yet).
static func frame_totals(rolls: Array) -> Array:
	var out: Array = []
	var i := 0
	var total := 0
	var known := true
	for f in 10:
		if i >= rolls.size():
			break
		var add := -1
		if f < 9:
			if int(rolls[i]) == 10:
				if i + 2 < rolls.size():
					add = 10 + int(rolls[i + 1]) + int(rolls[i + 2])
				i += 1
			else:
				if i + 1 >= rolls.size():
					out.append(-1)
					break
				var two := int(rolls[i]) + int(rolls[i + 1])
				if two == 10:
					if i + 2 < rolls.size():
						add = 10 + int(rolls[i + 2])
				else:
					add = two
				i += 2
		else:
			var r: Array = rolls.slice(i)
			var need := 3 if (r.size() >= 1 and int(r[0]) == 10) or (r.size() >= 2 and int(r[0]) + int(r[1]) == 10) else 2
			if r.size() >= need:
				add = 0
				for k in need:
					add += int(r[k])
			i = rolls.size()
		if add < 0 or not known:
			known = false
			out.append(-1)
		else:
			total += add
			out.append(total)
	return out


## Final (or so-far known) score.
static func score_of(rolls: Array) -> int:
	var t := frame_totals(rolls)
	var best := 0
	for v in t:
		if int(v) >= 0:
			best = int(v)
	return best


## Where the next ball goes: {"frame": 0-9, "ball": 0-2, "reset": bool (fresh rack), "over": bool}.
static func next_state(rolls: Array) -> Dictionary:
	var i := 0
	for f in 10:
		if f < 9:
			if i >= rolls.size():
				return {"frame": f, "ball": 0, "reset": true, "over": false}
			if int(rolls[i]) == 10:
				i += 1
				continue
			if i + 1 >= rolls.size():
				return {"frame": f, "ball": 1, "reset": false, "over": false}
			i += 2
		else:
			var r: Array = rolls.slice(i)
			match r.size():
				0: return {"frame": 9, "ball": 0, "reset": true, "over": false}
				1: return {"frame": 9, "ball": 1, "reset": int(r[0]) == 10, "over": false}
				2:
					if int(r[0]) == 10:
						return {"frame": 9, "ball": 2, "reset": int(r[1]) == 10, "over": false}
					if int(r[0]) + int(r[1]) == 10:
						return {"frame": 9, "ball": 2, "reset": true, "over": false}
					return {"frame": 9, "ball": 2, "reset": false, "over": true}
				_: return {"frame": 9, "ball": 3, "reset": false, "over": true}
	return {"frame": 9, "ball": 0, "reset": false, "over": true}


## Strikes and spares in a finished line (for tickets).
static func count_marks(rolls: Array) -> Dictionary:
	var strikes := 0
	var spares := 0
	var i := 0
	for f in 10:
		if i >= rolls.size():
			break
		if f < 9:
			if int(rolls[i]) == 10:
				strikes += 1
				i += 1
			else:
				if i + 1 < rolls.size() and int(rolls[i]) + int(rolls[i + 1]) == 10:
					spares += 1
				i += 2
		else:
			var r: Array = rolls.slice(i)
			var stand := 10
			for k in r.size():
				var v := int(r[k])
				if v == 10 and stand == 10:
					strikes += 1
				elif v == stand and k > 0:
					spares += 1
				stand = 10 if v == stand else stand - v
			break
	return {"strikes": strikes, "spares": spares}


## The marks for one frame's boxes ("X", "/", "-", "7"...).
static func frame_marks(rolls: Array, frame: int) -> Array:
	var i := 0
	for f in frame:
		if i >= rolls.size():
			return []
		if int(rolls[i]) == 10:
			i += 1
		else:
			i += 2
	var out: Array = []
	if frame < 9:
		if i < rolls.size():
			if int(rolls[i]) == 10:
				return ["", "X"]
			out.append("-" if int(rolls[i]) == 0 else str(int(rolls[i])))
			if i + 1 < rolls.size():
				out.append("/" if int(rolls[i]) + int(rolls[i + 1]) == 10 else ("-" if int(rolls[i + 1]) == 0 else str(int(rolls[i + 1]))))
		return out
	var stand := 10
	for k in range(i, mini(i + 3, rolls.size())):
		var v := int(rolls[k])
		if v == 10 and stand == 10:
			out.append("X")
		elif v == stand and stand < 10:
			out.append("/")
		else:
			out.append("-" if v == 0 else str(v))
		stand = 10 if v == stand else stand - v
	return out


# ---- the pin physics ----------------------------------------------------------------

## Inches. x across the lane (0 = middle board, + = right), y down the lane (0 = foul
## line, 720 = head pin). Ball and standing pins are discs; a pin that falls lies down as
## a 15-inch stick that sweeps the deck (that's where strikes come from); a pin brushed
## too softly to fall wobbles, and a hard wobble may still tip over. Collisions are impulses.
class Sim:
	const LANE_HALF := 20.5
	const GUTTER_X := 23.5
	const HEAD_Y := 720.0
	const PIT_Y := 762.0
	const KICK_X := 25.5
	const BALL_R := 4.3
	const PIN_R := 2.4
	const PIN_LEN := 15.0
	const LIE_R := 1.7
	const BALL_M := 7.0
	const PIN_M := 1.6
	const FALL_SPEED := 14.0
	const WOB_SPEED := 4.0
	const HOOK_FROM := 430.0
	const DT := 1.0 / 240.0
	static var BALL_E := 0.7
	static var PIN_E := 0.9
	static var DOWN_DEC := 50.0
	static var KICK_E := 0.65      # how hard the kickbacks throw pins back across the deck
	static var SCATTER := 0.15     # random spread (radians) on pin-on-pin hits: pins tumble, they don't bounce like pool balls

	var pins: Array = []        # {"p", "v", "down", "gone", "fall" 0..1, "dir", "home", "wob", "wdir", "teeter"}
	var ball_p := Vector2.ZERO
	var ball_v := Vector2.ZERO
	var spin := 0.0             # -1..1, + hooks left
	var gutter := false
	var hit_any := false
	var t := 0.0
	var done := false
	var quiet := 0.0
	var aim_noise := 0.12       # degrees of random release error (the game sets it from the power bar)
	var rng := RandomNumberGenerator.new()

	func rack() -> void:
		pins.clear()
		for row in 4:
			for i in row + 1:
				var p := Vector2((i - row / 2.0) * 12.0, HEAD_Y + row * 10.39)
				pins.append({"p": p, "v": Vector2.ZERO, "down": false, "gone": false, "fall": 0.0, "dir": Vector2.UP, "home": p,
					"wob": 0.0, "wdir": Vector2.UP, "teeter": -1.0})

	## Fallen pins are swept off; standing ones stay where they are.
	func sweep() -> void:
		for p: Dictionary in pins:
			p["v"] = Vector2.ZERO
			p["wob"] = 0.0
			p["teeter"] = -1.0
			if bool(p["down"]):
				p["gone"] = true

	func standing() -> int:
		var n := 0
		for p: Dictionary in pins:
			if not bool(p["down"]) and not bool(p["gone"]):
				n += 1
		return n

	## Indices (0-9, pin number - 1) of the pins still up.
	func standing_ids() -> Array:
		var out: Array = []
		for i in pins.size():
			var p: Dictionary = pins[i]
			if not bool(p["down"]) and not bool(p["gone"]):
				out.append(i)
		return out

	## One step of the ball on the lane (shared with the aim preview): the back end
	## is dry, so the spin bites there (slower balls hook more).
	static func ball_move(p: Vector2, v: Vector2, spin_in: float, dt: float, hooking: bool) -> Array:
		if hooking and p.y > HOOK_FROM:
			var k := 330.0 / maxf(180.0, v.length())
			v.x -= spin_in * 26.0 * k * dt
		p += v * dt
		v *= 1.0 - 0.02 * dt
		return [p, v]

	## The ball's path with no pins and no release error: points every ~24 in, stopping
	## at the head pin, or where it drops into a gutter.
	static func path(x0: float, angle_deg: float, speed: float, spin_in: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		var p := Vector2(clampf(x0, -LANE_HALF + BALL_R, LANE_HALF - BALL_R), 0.0)
		var a := deg_to_rad(angle_deg)
		var v := Vector2(sin(a), cos(a)) * speed
		out.append(p)
		var next := 24.0
		var n := 0
		while p.y < HEAD_Y and n < 2000:
			var r := ball_move(p, v, clampf(spin_in, -1, 1), DT, true)
			p = r[0]
			v = r[1]
			n += 1
			if absf(p.x) > LANE_HALF:
				out.append(p)
				return out
			if p.y >= next:
				out.append(p)
				next += 24.0
		out.append(p)
		return out

	## Where the ball crosses the head-pin line (no release error); +-99 in a gutter.
	static func entry_x(x0: float, angle_deg: float, speed: float, spin_in: float) -> float:
		var pts := path(x0, angle_deg, speed, spin_in)
		var last := pts[pts.size() - 1]
		if absf(last.x) > LANE_HALF:
			return 99.0 * signf(last.x)
		return last.x

	## The aim (degrees) that brings the ball to target_x at the head pin.
	static func aim_for(target_x: float, x0: float, speed: float, spin_in: float) -> float:
		var lo := -4.0
		var hi := 4.0
		for k in 22:
			var mid := (lo + hi) / 2.0
			if entry_x(x0, mid, speed, spin_in) < target_x:
				lo = mid
			else:
				hi = mid
		return (lo + hi) / 2.0

	func throw(x0: float, angle_deg: float, speed: float, spin_in: float) -> void:
		ball_p = Vector2(clampf(x0, -LANE_HALF + BALL_R, LANE_HALF - BALL_R), 0.0)
		var a := deg_to_rad(angle_deg + rng.randfn(0.0, aim_noise * 0.6) if aim_noise > 0.0 else angle_deg)
		ball_v = Vector2(sin(a), cos(a)) * speed
		spin = clampf(spin_in, -1.0, 1.0)
		gutter = false
		hit_any = false
		t = 0.0
		done = false
		quiet = 0.0

	## The lying stick of a fallen pin, base to head (ground plane).
	static func stick(p: Dictionary) -> Array:
		var a: Vector2 = p["p"]
		return [a, a + (p["dir"] as Vector2) * PIN_LEN * 0.9 * float(p["fall"])]

	static func closest(a: Vector2, b: Vector2, q: Vector2) -> Vector2:
		var ab := b - a
		var l2 := ab.length_squared()
		if l2 < 0.0001:
			return a
		return a + ab * clampf((q - a).dot(ab) / l2, 0.0, 1.0)

	func _knock(p: Dictionary, d: Vector2) -> void:
		if bool(p["down"]):
			return
		p["down"] = true
		p["dir"] = d.normalized() if d.length() > 0.1 else Vector2.UP
		p["wob"] = 0.0
		p["teeter"] = -1.0

	func step(dt: float) -> Array:
		## Returns events: "hit" (first pin contact), "gutter", "pit", "clatter" (a fallen pin takes down another).
		var ev: Array = []
		t += dt
		if ball_p.y < PIT_Y + 30.0:
			var r := ball_move(ball_p, ball_v, spin, dt, not gutter and not hit_any)
			ball_p = r[0]
			ball_v = r[1]
			if not gutter and absf(ball_p.x) > LANE_HALF and ball_p.y < HEAD_Y - 10.0:
				gutter = true
				ball_p.x = signf(ball_p.x) * GUTTER_X
				ball_v.x = 0.0
				ev.append("gutter")
			if ball_p.y >= PIT_Y + 30.0:
				ev.append("pit")
		if not gutter:
			for p: Dictionary in pins:
				if bool(p["gone"]):
					continue
				var lying := bool(p["down"]) and float(p["fall"]) > 0.2
				var touch: Vector2 = p["p"]
				var rad := PIN_R
				if lying:
					var s := stick(p)
					touch = closest(s[0], s[1], ball_p)
					rad = LIE_R
				var d: Vector2 = touch - ball_p
				var dist := d.length()
				if dist < BALL_R + rad and dist > 0.001:
					var n := d / dist
					var vrel := (ball_v - (p["v"] as Vector2)).dot(n)
					if vrel > 0.0:
						var j := (1.0 + BALL_E) * vrel / (1.0 / BALL_M + 1.0 / PIN_M)
						ball_v -= n * j / BALL_M
						p["v"] = (p["v"] as Vector2) + n * j / PIN_M
						if not hit_any:
							hit_any = true
							ev.append("hit")
					var over := BALL_R + rad - dist
					p["p"] = (p["p"] as Vector2) + n * over * 0.8
					ball_p -= n * over * 0.2
		# Pins against pins: standing discs, and fallen sticks sweeping into standing pins.
		for a in pins.size():
			var pa: Dictionary = pins[a]
			if bool(pa["gone"]):
				continue
			var a_lying := bool(pa["down"]) and float(pa["fall"]) > 0.2
			for b in range(a + 1, pins.size()):
				var pb: Dictionary = pins[b]
				if bool(pb["gone"]):
					continue
				var b_lying := bool(pb["down"]) and float(pb["fall"]) > 0.2
				if a_lying and b_lying:
					continue  # dead wood on dead wood: let it slide
				var ca: Vector2 = pa["p"]
				var cb: Vector2 = pb["p"]
				var ra := LIE_R if a_lying else PIN_R
				var rb := LIE_R if b_lying else PIN_R
				if a_lying:
					var sa := stick(pa)
					ca = closest(sa[0], sa[1], cb)
				elif b_lying:
					var sb := stick(pb)
					cb = closest(sb[0], sb[1], ca)
				var d2: Vector2 = cb - ca
				var dist2 := d2.length()
				if dist2 < ra + rb and dist2 > 0.001:
					var n2 := d2 / dist2
					var vrel2 := ((pa["v"] as Vector2) - (pb["v"] as Vector2)).dot(n2)
					if vrel2 > 0.0:
						if SCATTER > 0.0:
							n2 = n2.rotated(rng.randfn(0.0, SCATTER))
						var j2 := (1.0 + PIN_E) * vrel2 / 2.0
						pa["v"] = (pa["v"] as Vector2) - n2 * j2
						pb["v"] = (pb["v"] as Vector2) + n2 * j2
						if (a_lying or b_lying) and j2 > FALL_SPEED * 0.5 and not ev.has("clatter"):
							ev.append("clatter")
					var ov := (ra + rb - dist2) / 2.0
					pa["p"] = (pa["p"] as Vector2) - n2 * ov
					pb["p"] = (pb["p"] as Vector2) + n2 * ov
		var moving := false
		for p: Dictionary in pins:
			if bool(p["gone"]):
				continue
			var v: Vector2 = p["v"]
			var sp := v.length()
			if not bool(p["down"]):
				if sp > FALL_SPEED:
					_knock(p, v)
				elif ((p["p"] as Vector2) - (p["home"] as Vector2)).length() > 3.2:
					_knock(p, v)
				elif sp > WOB_SPEED and float(p["wob"]) < sp / FALL_SPEED:
					# Brushed: it rocks. A hard rock can still go over after a moment.
					p["wob"] = sp / FALL_SPEED
					p["wdir"] = v.normalized()
					if float(p["teeter"]) < 0.0 and sp > 9.0 and rng.randf() < (sp - 9.0) / 5.0 * 0.6:
						p["teeter"] = 0.45 + rng.randf() * 0.4
			if not bool(p["down"]) and float(p["wob"]) > 0.0:
				p["wob"] = maxf(0.0, float(p["wob"]) - dt * 0.9)
				if float(p["teeter"]) > 0.0:
					p["teeter"] = float(p["teeter"]) - dt
					if float(p["teeter"]) <= 0.0:
						_knock(p, p["wdir"])
						p["v"] = (p["wdir"] as Vector2) * 20.0
				if float(p["wob"]) > 0.04:
					moving = true
			if bool(p["down"]):
				p["fall"] = minf(1.0, float(p["fall"]) + dt * 4.0)
			# Tumbling pins slow fast; kickbacks throw them back in; the pit swallows them.
			var dec := DOWN_DEC if bool(p["down"]) else 600.0
			v = (p["v"] as Vector2).move_toward(Vector2.ZERO, dec * dt)
			var np: Vector2 = (p["p"] as Vector2) + v * dt
			if np.y > HEAD_Y - 6.0 and absf(np.x) > KICK_X:
				np.x = signf(np.x) * KICK_X
				v.x = -v.x * KICK_E
			if np.y > PIT_Y or np.y < HEAD_Y - 60.0 or absf(np.x) > KICK_X + 1.0:
				p["down"] = true
				p["gone"] = true
			p["p"] = np
			p["v"] = v
			if v.length() > 1.0:
				moving = true
		var ball_live := ball_p.y < PIT_Y + 30.0 and ball_v.length() > 5.0
		if not moving and not ball_live:
			quiet += dt
			if quiet > 0.35 or not hit_any:
				done = true
		else:
			quiet = 0.0
		if t > 9.0:
			done = true
		return ev

	## Runs a whole throw (tests, villagers). Returns pins knocked.
	func run_throw(x0: float, angle_deg: float, speed: float, spin_in: float) -> int:
		var before := standing()
		throw(x0, angle_deg, speed, spin_in)
		var n := 0
		while not done and n < 4000:
			step(DT)
			n += 1
		return before - standing()


# ---- bowlers: villagers and the test bot ----------------------------------------------

## Villager strength comes from ONE table: their average game (gen_rec BOWL_AVG, read by
## RecCenter.bowl_avg). SKILL_AVG maps release skill (0..1) to the average game it bowls
## (measured by tools/bowl_audit.gd -- skills; re-measure after touching Sim or choose()).
## Smoothed from 24 games a step (spin 0 below skill 0.3, 2 above), 2026-11-19.
const SKILL_AVG := [[0.1, 92.0], [0.2, 112.0], [0.35, 130.0], [0.45, 140.0], [0.5, 152.0], [0.6, 180.0], [0.7, 195.0], [0.8, 224.0], [0.9, 256.0]]
const POCKET := 2.75         # entry point (in, right of the head pin) for a ball hooking left
const SWEET := Vector2(0.68, 0.88)  # the power bar's sweet band


static func opponent(id: String) -> Dictionary:
	var avg := float(RecCenter.bowl_avg(id))
	var sk := skill_for(avg)
	return {"avg": int(avg), "skill": sk, "spin": 0 if sk < 0.3 else 2,  # as SKILL_AVG was measured
		"bonus": clampi(4 + int(avg) / 15, 6, 20)}


## Release skill that bowls this average (linear between SKILL_AVG points).
static func skill_for(avg: float) -> float:
	var pts: Array = SKILL_AVG
	if avg <= float(pts[0][1]):
		return float(pts[0][0])
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if avg <= float(b[1]):
			return lerpf(float(a[0]), float(b[0]), (avg - float(a[1])) / maxf(1.0, float(b[1]) - float(a[1])))
	return float(pts.back()[0])


## A villager's (or the bot's) choice for the next ball on this rack:
## {"x0", "aim", "power", "spin", "noise"}. skill 0..1.
static func choose(sim_in: Sim, skill: float, spin_steps: int, rng: RandomNumberGenerator) -> Dictionary:
	var ids := sim_in.standing_ids()
	var full := ids.size() == 10
	var power := clampf((SWEET.x + SWEET.y) / 2.0 + rng.randfn(0.0, (1.0 - skill) * 0.16), 0.0, 1.0)
	var speed := 230.0 + 140.0 * power
	var spin := spin_steps / 3.0
	var x0 := 6.0 if spin > 0.0 else 2.0
	var target := POCKET if spin > 0.0 else 1.5
	if not full and not ids.is_empty():
		# Spare: straight at the middle of what's left, from across the lane.
		var sx := 0.0
		for i in ids:
			sx += ((sim_in.pins[i] as Dictionary)["p"] as Vector2).x
		target = sx / ids.size()
		spin = 0.0
		x0 = clampf(-target * 0.7, -14.0, 14.0)
	# Line error in inches at the pins: spares (one target, no carry to help) need more care,
	# and a shaky bowler sometimes just throws a wild one.
	var miss := rng.randfn(0.0, pow(1.0 - skill, 1.2) * 9.0 if not full else pow(1.0 - skill, 1.5) * 12.0)
	if rng.randf() < pow(1.0 - skill, 1.5) * 0.7:
		miss += rng.randf_range(10.0, 22.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var aim := Sim.aim_for(target + miss, x0, speed, spin)
	# Stand where the swing can reach it (the aim arrow only sweeps +-AIM_MAX).
	for k in 8:
		if absf(aim) <= AIM_MAX * 0.9:
			break
		x0 = clampf(x0 + signf(aim) * 4.0, -16.0, 16.0)
		aim = Sim.aim_for(target + miss, x0, speed, spin)
	return {"x0": x0, "aim": aim, "power": power, "spin": spin, "noise": release_noise(power)}


## Release error (degrees) for where the power bar was stopped: tiny in the sweet band.
static func release_noise(power: float) -> float:
	var off := maxf(SWEET.x - power, power - SWEET.y)
	return 0.03 if off <= 0.0 else 0.03 + off * 0.9


## A whole frame for a villager on their own rack; appends to rolls_out.
static func bowl_frame(sim_in: Sim, rolls_out: Array, skill: float, spin_steps: int) -> void:
	var f := int(next_state(rolls_out)["frame"])
	var guard := 0
	while guard < 4:
		guard += 1
		var ns := next_state(rolls_out)
		if bool(ns["over"]) or int(ns["frame"]) != f:
			return
		if bool(ns["reset"]):
			sim_in.rack()
		else:
			sim_in.sweep()
		var c := choose(sim_in, skill, spin_steps, sim_in.rng)
		sim_in.aim_noise = float(c["noise"])
		rolls_out.append(sim_in.run_throw(float(c["x0"]), float(c["aim"]), 230.0 + 140.0 * float(c["power"]), float(c["spin"])))


## Name for a leave after the first ball: "7-10 split", "Split", "" (none).
static func split_name(ids: Array) -> String:
	if ids.size() < 2 or ids.has(0):
		return ""
	var homes: Array = []
	for row in 4:
		for i in row + 1:
			homes.append(Vector2((i - row / 2.0) * 12.0, row * 10.39))
	var seen := {}
	var groups := 0
	for s in ids:
		if seen.has(s):
			continue
		groups += 1
		var stack: Array = [s]
		seen[s] = true
		while not stack.is_empty():
			var c: int = stack.pop_back()
			for o in ids:
				if not seen.has(o) and (homes[c] as Vector2).distance_to(homes[o]) < 12.5:
					seen[o] = true
					stack.append(o)
	if groups < 2:
		return ""
	var nums: Array = []
	for s in ids:
		nums.append(int(s) + 1)
	nums.sort()
	if nums.size() == 2:
		return "%d-%d split" % [nums[0], nums[1]]
	return "Split"


# ---- the game screen ------------------------------------------------------------------

const TriBatch := preload("res://scripts/tri_batch.gd")  # tilted pins: one draw call
const F := 330.0       # focal length (px)
const CAM_H := 42.0    # camera height (in)
const HZ := 214.0      # horizon (screen y)
const MODAL := Rect2(0, 0, 270, 372)
## Deck buttons: right-handed layout, then the left-handed one (C9 P3: GO under
## the left thumb, arrows on the right, the scorecard between). Picked in _ready.
const DECK_RH := {"l": Rect2(8, 398, 42, 34), "r": Rect2(54, 398, 42, 34), "sl": Rect2(8, 438, 42, 28),
	"sr": Rect2(54, 438, 42, 28), "go": Rect2(102, 398, 48, 68), "info": Rect2(156, 398, 108, 68)}
const DECK_LH := {"l": Rect2(174, 398, 42, 34), "r": Rect2(220, 398, 42, 34), "sl": Rect2(174, 438, 42, 28),
	"sr": Rect2(220, 438, 42, 28), "go": Rect2(6, 398, 48, 68), "info": Rect2(60, 398, 108, 68)}
var BTN_L: Rect2 = DECK_RH["l"]
var BTN_R: Rect2 = DECK_RH["r"]
var BTN_SPIN_L: Rect2 = DECK_RH["sl"]
var BTN_SPIN_R: Rect2 = DECK_RH["sr"]
var BTN_GO: Rect2 = DECK_RH["go"]
var _info_r: Rect2 = DECK_RH["info"]


func _pick_deck() -> void:
	var d: Dictionary = DECK_LH if Settings.left_handed() else DECK_RH
	BTN_L = d["l"]
	BTN_R = d["r"]
	BTN_SPIN_L = d["sl"]
	BTN_SPIN_R = d["sr"]
	BTN_GO = d["go"]
	_info_r = d["info"]


## Fingers see buttons; a pad hides them (it plays on the actions) (C9 P3).
func deck_hidden() -> bool:
	return ScreenCursor.pad_active() and not manual and bot < 0.0


## "Tap" for fingers, the button word for keys/pads.
func _verb(touch_word: String, key_word: String) -> String:
	return touch_word if TouchControls.visible_controls and not ScreenCursor.pad_active() else key_word


func _input(ev: InputEvent) -> void:
	ScreenCursor.note(ev)
const AIM_MAX := 1.0        # degrees each side the aim arrow swings
const AIM_PERIOD := 3.2     # seconds for a full swing there and back
const POWER_PERIOD := 1.5   # seconds for the power bar to rise and fall

var lane := 1
var opp_id := ""             # villager challenged ("" = solo)
## C17 P4: a CoopGames bowling session with co-op partners ("" = none). Frames go in
## lockstep: after each frame we post our total and wait until everyone has caught up.
var coop_sid := ""
var coop: CoopGames = null   # tests may hand in their own instance
var manual := false          # tests: drive tick() by hand
var bot := -1.0              # tests: >= 0 plays itself at this skill
var sim := Sim.new()
var opp_sim := Sim.new()
var _tb := TriBatch.new()
var rolls: Array = []
var opp_rolls: Array = []
var phase := "line"          # line, aim, power, roll, result, sweep, opp, over
var x0 := 6.0
var spin_step := 1           # -3..3
var aim := 0.0
var power := 0.0
var _osc := 0.0
var _cam_y := -100.0
var _msg := ""
var _msg_sub := ""
var _msg_t := 0.0
var _msg_age := 0.0
var _knocked := 0
var _before := 10
var _quit_arm := 0.0
var _arm := 0
var _hold := 0               # -1 / +1 from the on-screen arrows
var _canvas: Control
var _font: Font
var _was_down: Array = []
var result := {}
var _slowmo := 1.0
var _tap_go := false
var _drag_from := Vector2.INF
var _dragged := false
var _phase_t := 0.0
var _sweep_full := false
var _drop_t := 1.0           # 0..1 a fresh rack lowering onto the deck
var _parts: Array = []       # confetti: [pos, vel, colour, life]
var _streak := 0             # strikes in a row
var _quality := ""           # last release: "great", "ok", "wild"
var _opp_show := 0           # opp balls revealed on the card
var _opp_from := 0           # opp_rolls index where the shown frame starts
var _clatters := 0
var _bot_rng := RandomNumberGenerator.new()
var _btn_quit := Rect2(6, 72, 30, 24)


static func play(m: GameMap, lane_no: int, versus := "", coop_session := "") -> Dictionary:
	var g := Bowling.new()
	g.lane = lane_no
	g.opp_id = versus
	g.coop_sid = coop_session
	m.add_child(g)
	await g.closed
	return g.result


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_deck()
	_font = ThemeDB.fallback_font
	_btn_quit = Rect2(6, _sheet_rect().end.y + 6, 30, 24)
	Hud.modal_rect = MODAL
	for r in _rects():
		Hud.extra_rects.append(r)
	Hud.pause(get_tree(), "bowling")
	_covered = ScreenCover.cover(get_parent())  # the opaque screen hides the map: don't render it
	var seed_v := int(GameState.run.get("day", 1)) * 977 + lane * 31 + int(GameState.run.get("time", 0))
	sim.rng.seed = seed_v
	opp_sim.rng.seed = seed_v + 5
	_bot_rng.seed = seed_v + 9
	sim.rack()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_it)
	_canvas.gui_input.connect(_tap)
	add_child(_canvas)
	RecAudio.attach_bowling(self)
	_new_ball()
	_cam_y = -100.0


var _covered: CanvasItem = null


func _rects() -> Array:
	return [BTN_L, BTN_R, BTN_SPIN_L, BTN_SPIN_R, BTN_GO, _btn_quit]


func _exit_tree() -> void:
	ScreenCover.uncover(_covered)
	_covered = null
	for r in _rects():
		Hud.extra_rects.erase(r)


func opp_name() -> String:
	if opp_id == "":
		return ""
	return str(GameState.npcs.get(opp_id, {}).get("name", opp_id.capitalize()))


func _cg() -> CoopGames:
	if coop == null:
		coop = CoopGames.i()
	return coop


## Partners' rows for the sheet: [{name, frames, score, me}] (empty when solo).
func coop_rows() -> Array:
	return [] if coop_sid == "" else _cg().rows(coop_sid)


func _new_ball() -> void:
	var ns := next_state(rolls)
	if bool(ns["over"]):
		_game_over()
		return
	if coop_sid != "" and int(ns["ball"]) == 0 and _cg().sessions.has(coop_sid) and not _cg().may_bowl(coop_sid, int(ns["frame"]) + 1):
		phase = "wait"  # a partner is still on the last frame
		_phase_t = 0.0
		return
	if bool(ns["reset"]):
		sim.rack()
		_drop_t = 0.0
	phase = "line"
	_phase_t = 0.0
	_quality = ""
	_before = sim.standing()
	_was_down.clear()
	for p: Dictionary in sim.pins:
		_was_down.append(bool(p["down"]) or bool(p["gone"]))
	if int(ns["ball"]) > 0 and not bool(ns["reset"]):
		var leave := split_name(sim.standing_ids())
		if leave != "":
			_say(leave + "!", "Pick your line for the spare.", 1.4)
	sim.ball_p = Vector2(x0, -8.0)
	sim.ball_v = Vector2.ZERO
	sim.gutter = false


func _process(delta: float) -> void:
	if not manual:
		tick(delta)


## One frame of the game (tests call this directly with manual = true).
func tick(delta: float) -> void:
	_arm += 1
	_phase_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	_msg_age += delta
	_quit_arm = maxf(0.0, _quit_arm - delta)
	_drop_t = minf(1.0, _drop_t + delta * 3.0)
	_tick_parts(delta)
	if _canvas:
		_canvas.queue_redraw()
	if _arm < 8:
		return
	var live := not manual
	if live and (Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu")) and phase != "over":
		_ask_quit()
		return
	var go := _tap_go or (live and (Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action")))
	_tap_go = false
	if bot >= 0.0 and phase not in ["aim", "power"]:
		go = _bot_go()
	match phase:
		"line":
			var dir := _hold
			if live and Input.is_action_pressed("left"):
				dir = -1
			elif live and Input.is_action_pressed("right"):
				dir = 1
			x0 = clampf(x0 + dir * 16.0 * delta, -16.0, 16.0)
			if live and Input.is_action_just_pressed("up"):
				_spin(1)
			elif live and Input.is_action_just_pressed("down"):
				_spin(-1)
			sim.ball_p = Vector2(x0, -8.0)
			_cam_y = lerpf(_cam_y, -100.0, minf(1.0, delta * 5.0))
			if go and _phase_t > 0.15:
				phase = "aim"
				_osc = 0.0
				aim = 0.0
				_cam_y = -100.0
				Music.instance(get_tree()).sfx("ui_tap", "pickup")
		"aim":
			_osc += delta
			# A steady sweep (triangle wave), so the timing is learnable.
			var ph := fmod(_osc / AIM_PERIOD + 0.25, 1.0)
			aim = AIM_MAX * (4.0 * ph - 1.0 if ph < 0.5 else 3.0 - 4.0 * ph)
			if bot >= 0.0:
				go = _bot_go()
			if go:
				phase = "power"
				_osc = 0.0
				power = 0.0
				Music.instance(get_tree()).sfx("ui_tap", "pickup")
		"power":
			_osc += delta
			var pp := fmod(_osc / (POWER_PERIOD / 2.0), 2.0)
			power = pp if pp <= 1.0 else 2.0 - pp
			if bot >= 0.0:
				go = _bot_go()
			if go:
				_throw()
		"roll":
			var steps := int(ceil(delta * 240.0 * _slowmo))
			for i in mini(steps, 12):
				for e in sim.step(Sim.DT):
					_on_event(str(e))
				if sim.done:
					break
			_slowmo = 0.55 if sim.ball_p.y > 640.0 and sim.ball_p.y < 780.0 and not sim.gutter else 1.0
			var want := clampf(sim.ball_p.y - 110.0, -100.0, 575.0)
			_cam_y = lerpf(_cam_y, want, minf(1.0, delta * 6.0))
			if sim.done:
				_scored()
		"result":
			if _phase_t > 0.35 and (_msg_t <= 0.0 or go):
				_start_sweep()
		"sweep":
			# The pinsetter's bar comes down and rakes the deck: fallen pins ride it
			# into the pit (after a closed frame, the standing ones too).
			var by := lerpf(700.0, 770.0, clampf((_phase_t / 0.75 - 0.25) / 0.6, 0.0, 1.0))
			for p: Dictionary in sim.pins:
				if bool(p["gone"]) or (p["p"] as Vector2).y >= by:
					continue
				if bool(p["down"]):
					p["p"] = Vector2((p["p"] as Vector2).x, by)
				elif _sweep_full and by > 702.0:
					p["gone"] = true
			if _phase_t >= 0.75 or (go and _phase_t > 0.2):
				sim.sweep()
				if _frame_done():
					if coop_sid != "":
						var fdone := int(next_state(rolls.slice(0, rolls.size() - 1))["frame"]) + 1
						_cg().post_frame(coop_sid, fdone, score_of(rolls))
					if opp_id != "":
						_start_opp()
						return
				_new_ball()
		"opp":
			var shown := opp_rolls.size() - _opp_from
			if _opp_show < shown and _phase_t > 0.55 * (_opp_show + 1):
				_opp_show += 1
				var v := int(opp_rolls[_opp_from + _opp_show - 1])
				Music.instance(get_tree()).sfx(RecAudio.opp_roll(v), "thud")
			if _opp_show >= shown and (go or _phase_t > 0.55 * (shown + 1) + 1.1):
				_new_ball()
		"wait":
			if not _cg().sessions.has(coop_sid) or _cg().may_bowl(coop_sid, int(next_state(rolls)["frame"]) + 1):
				_new_ball()
		"over":
			if go or (live and Input.is_action_just_pressed("b")):
				_finish()


func _spin(d: int) -> void:
	spin_step = clampi(spin_step + d, -3, 3)
	Music.instance(get_tree()).sfx("ui_tap", "pickup")


## Is the player's frame finished (the last ball closed it, or the game)?
func _frame_done() -> bool:
	var before := next_state(rolls.slice(0, rolls.size() - 1))
	var now := next_state(rolls)
	return bool(now["over"]) or int(now["frame"]) != int(before["frame"])


func _start_sweep() -> void:
	phase = "sweep"
	_phase_t = 0.0
	var ns := next_state(rolls)
	_sweep_full = bool(ns["reset"]) or bool(ns["over"])
	Music.instance(get_tree()).sfx("servo", "thud")


## The villager bowls the same frame on their own rack.
func _start_opp() -> void:
	var o := opponent(opp_id)
	_opp_from = opp_rolls.size()
	if not bool(next_state(opp_rolls)["over"]):
		bowl_frame(opp_sim, opp_rolls, float(o["skill"]), int(o["spin"]))
	_opp_show = 0
	phase = "opp"
	_phase_t = 0.0
	if opp_rolls.size() == _opp_from:
		_new_ball()


func _throw() -> void:
	phase = "roll"
	_phase_t = 0.0
	_clatters = 0
	var speed := 230.0 + 140.0 * power
	sim.aim_noise = release_noise(power)
	_quality = "great" if power >= SWEET.x and power <= SWEET.y else ("ok" if sim.aim_noise < 0.15 else "wild")
	sim.throw(x0, aim, speed, spin_step / 3.0)
	_slowmo = 1.0
	Music.instance(get_tree()).sfx("swing_heavy", "swing")
	if _quality == "great":
		_say("Smooth release", "", 0.7)
	elif _quality == "wild":
		_say("Wobbly release...", "", 0.7)


func _on_event(e: String) -> void:
	match e:
		"hit":
			pass  # RecAudio plays the roll, the pins (sized to how many fall), the pit and the return
		"clatter":
			_clatters += 1
		"gutter":
			_say("Gutter...", "", 1.0)


func _scored() -> void:
	_knocked = _before - sim.standing()
	rolls.append(_knocked)
	var ns := next_state(rolls)
	var last := frame_marks(rolls, int(next_state(rolls.slice(0, rolls.size() - 1))["frame"]))
	var mark := str(last.back()) if not last.is_empty() else ""
	if mark == "X":
		_streak += 1
		var words := {2: "DOUBLE!", 3: "TURKEY!", 4: "HAMBONE!"}
		_say(str(words.get(_streak, "STRIKE!" if _streak < 5 else "%d IN A ROW!" % _streak)), "", 1.6)
		_burst(36)
		Music.instance(get_tree()).sfx("j_treasure", "levelup")
		Music.instance(get_tree()).sfx("clap", "pickup")
	elif mark == "/":
		_streak = 0
		_say("SPARE!", "", 1.4)
		_burst(18)
		Music.instance(get_tree()).sfx("sparkle", "pickup")
	else:
		_streak = 0
		if _knocked == 0:
			_say("Missed them all." if not sim.gutter else "Gutter ball.", "", 1.1)
		elif _before == 10 and _knocked == 9:
			_say("9 pins", "So close!", 1.1)
		else:
			_say("%d pin%s" % [_knocked, "" if _knocked == 1 else "s"], "", 1.0)
	phase = "result"
	_phase_t = 0.0
	if bool(ns["over"]):
		_msg_t = maxf(_msg_t, 1.2)


func _say(t: String, sub: String, secs: float) -> void:
	_msg = t
	_msg_sub = sub
	_msg_t = secs
	_msg_age = 0.0


func _burst(n: int) -> void:
	var cols := [Color("f5486e"), Color("3fa9f5"), Color("f5c842"), Color("3fdc8c"), Color.WHITE]
	for i in n:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(60.0, 170.0)
		_parts.append([Vector2(135, 200), Vector2(cos(a), sin(a)) * sp, cols[i % cols.size()], randf_range(0.8, 1.4)])


func _tick_parts(delta: float) -> void:
	for p: Array in _parts:
		p[1] = (p[1] as Vector2) + Vector2(0, 160.0) * delta
		p[0] = (p[0] as Vector2) + (p[1] as Vector2) * delta
		p[3] = float(p[3]) - delta
	_parts = _parts.filter(func(p: Array) -> bool: return float(p[3]) > 0.0)


func _game_over() -> void:
	phase = "over"
	_phase_t = 0.0
	var mk := count_marks(rolls)
	var sc := score_of(rolls)
	result = {"done": true, "score": sc, "strikes": int(mk["strikes"]), "spares": int(mk["spares"]), "rolls": rolls.duplicate()}
	if opp_id != "":
		var os := score_of(opp_rolls)
		result["opponent"] = opp_id
		result["opp_score"] = os
		result["won"] = sc > os
		result["bonus"] = int(opponent(opp_id)["bonus"]) if sc > os else (2 if sc == os else 0)
	if coop_sid != "":
		result["coop"] = coop_sid  # tickets stay personal (own score); the session ranks us
	if GameState.run.size() > 0 and sc > Tickets.best_score("bowling"):
		_burst(48)
	var new_best := GameState.run.size() > 0 and sc > Tickets.best_score("bowling")
	Music.instance(get_tree()).sfx(end_cue(result, new_best), "coin")


## The one result sting for a bowling game (RecCenter only adds the ticket cue):
## versus = won/lost; solo = the fanfare for a new best or a 100+ game, else a
## light cue (a 20-point gutter game is no victory).
static func end_cue(res: Dictionary, new_best: bool) -> String:
	if res.has("opponent"):
		return "j_victory" if bool(res.get("won", false)) else "j_page"
	if new_best or int(res.get("score", 0)) >= 100:
		return "j_victory"
	return "sparkle"


func _ask_quit() -> void:
	if _quit_arm > 0.0:
		result = {"done": false, "score": score_of(rolls), "rolls": rolls.duplicate()}
		_finish()
	else:
		_quit_arm = 2.0
		_say(_verb("Tap ✕ again to leave", "Press B again to leave"), "(no tickets)", 2.0)


func _finish() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	Dialogue.block_input(0.3)
	Hud.modal_rect = Rect2()
	closed.emit()
	queue_free()


func _tap(ev: InputEvent) -> void:
	# One tap, one action: a phone sends the touch AND an emulated mouse copy
	# (that copy used to arm and fire the quit button in one tap). TapInput drops it.
	if TapInput.is_echo(ev):
		return
	if ev is InputEventMouseMotion or ev is InputEventScreenDrag:
		# Drag the ball along the foul line while lining up.
		var pos: Vector2 = ev.position
		if phase == "line" and _drag_from != Vector2.INF:
			var dx := pos.x - _drag_from.x
			if absf(dx) > 3.0 or _dragged:
				_dragged = true
				x0 = clampf(x0 + dx / 3.3, -16.0, 16.0)
				_drag_from = pos
		return
	if TapInput.is_release(ev):
		_hold = 0
		# A tap on the lane (not a drag) is GO.
		if _drag_from != Vector2.INF and not _dragged:
			_tap_go = true
		_drag_from = Vector2.INF
		_dragged = false
		return
	var p := TapInput.press_pos(ev)
	if p == Vector2.INF or _arm < 8:
		return
	if _btn_quit.has_point(p):
		_ask_quit()
	elif phase == "line" and BTN_L.has_point(p):
		_hold = -1
	elif phase == "line" and BTN_R.has_point(p):
		_hold = 1
	elif phase == "line" and BTN_SPIN_L.has_point(p):
		_spin(1)
	elif phase == "line" and BTN_SPIN_R.has_point(p):
		_spin(-1)
	elif BTN_GO.has_point(p):
		_tap_go = true
	elif MODAL.has_point(p) and p.y > _btn_quit.end.y:
		if phase == "line":
			_drag_from = p
			_dragged = false
		else:
			_tap_go = true


## Test bot: plays the screen itself at skill `bot` (taps when the bars are where it wants).
var _bot_plan := {}
var _bot_prev := INF
func _bot_go() -> bool:
	match phase:
		"line":
			if _bot_plan.is_empty():
				_bot_plan = choose(sim, bot, 2, _bot_rng)
				x0 = float(_bot_plan["x0"])
				spin_step = int(round(float(_bot_plan["spin"]) * 3.0))
			return _phase_t > 0.2
		"aim":
			var d := aim - float(_bot_plan.get("aim", 0.0))
			var hit := (_bot_prev != INF and signf(d) != signf(_bot_prev)) or _osc > AIM_PERIOD * 3.0
			_bot_prev = INF if hit else d
			return hit
		"power":
			var d2 := power - float(_bot_plan.get("power", 0.78))
			var hit2 := (_bot_prev != INF and signf(d2) != signf(_bot_prev)) or _osc > POWER_PERIOD * 3.0
			_bot_prev = INF if hit2 else d2
			if hit2:
				_bot_plan = {}
			return hit2
		"result", "sweep", "opp", "over":
			return _phase_t > 0.3
	return false


# ---- drawing -------------------------------------------------------------------------

## Lane point (x, y, h inches) to screen; z <= 0 is behind the camera.
func _proj(x: float, y: float, h := 0.0) -> Vector3:
	var z := y - _cam_y
	if z < 6.0:
		return Vector3(0, 0, -1)
	return Vector3(135.0 + F * x / z, HZ + F * (CAM_H - h) / z, F / z)


func _p2(x: float, y: float, h := 0.0) -> Vector2:
	var v := _proj(x, y, h)
	return Vector2(v.x, v.y)


func _quad(x0q: float, x1q: float, y0q: float, y1q: float, c: Color, h := 0.0) -> void:
	var ya := maxf(y0q, _cam_y + 8.0)
	if y1q <= ya:
		return
	_canvas.draw_colored_polygon(PackedVector2Array([_p2(x0q, ya, h), _p2(x1q, ya, h), _p2(x1q, y1q, h), _p2(x0q, y1q, h)]), c)


func _sheet_rect() -> Rect2:
	if coop_sid != "":
		return Rect2(4, 4, 262, 62 + 11 * clampi(coop_rows().size() - 1, 0, CoopGames.MAX_PLAYERS - 1))
	return Rect2(4, 4, 262, 62 if opp_id == "" else 90)


func _draw_it() -> void:
	var c := _canvas
	var gang := not GameState.is_penguins()
	# Room: ceiling and back wall.
	c.draw_rect(Rect2(0, 0, 270, 480), Color("1e140e") if not gang else Color("0a0614"))
	# The far wall: ceiling lamps and the mural over the pin decks, in perspective.
	var wall := Art.tex("backdrops", "bowling_wall")
	if wall:
		var base := _proj(0.0, 790.0, 0.0)
		if base.z > 0:
			var ww := clampf(1000.0 * base.z, 300.0, 420.0)
			var wh := ww * wall.get_height() / wall.get_width()
			c.draw_texture_rect(wall, Rect2(base.x - ww / 2.0, base.y - wh, ww, wh), false, Color(1, 1, 1) if not gang else Color(0.75, 0.55, 1.0))
	# Neighbouring lanes, dimmer.
	for off in [-48.0, 48.0]:
		_quad(off - 20.5, off + 20.5, -60.0, 770.0, Color("6b4e30") if not gang else Color("1e1830"))
	_quad(-26.0, 26.0, -60.0, 770.0, Color("30303a"))  # gutters
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, -200.0, 0.0, Color("c9a36c") if not gang else Color("2c2246"))  # approach
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 0.0, 762.0, Color("dcb47c") if not gang else Color("342a58"))  # lane bed
	# Boards, oil sheen, arrows, foul line, pin deck.
	for b in range(-19, 20, 3):
		var a := _p2(float(b), maxf(0.0, _cam_y + 8.0))
		var e := _p2(float(b), 740.0)
		c.draw_line(a, e, Color(0.5, 0.33, 0.18, 0.22) if not gang else Color(0.6, 0.3, 1, 0.18), 1.0)
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 0.0, 430.0, Color(1, 1, 1, 0.05))
	for k in 7:
		var ax := (k - 3) * 5.0
		var ay := 180.0 + absf(k - 3) * 9.0
		if ay > _cam_y + 10.0:
			c.draw_colored_polygon(PackedVector2Array([_p2(ax, ay + 8.0), _p2(ax - 1.4, ay), _p2(ax + 1.4, ay)]), Color(0.3, 0.12, 0.06, 0.8) if not gang else Color(1, 0.3, 0.9, 0.9))
	if _cam_y < -8.0:
		var fa := _p2(-26.0, 0.0)
		var fb := _p2(26.0, 0.0)
		c.draw_line(fa, fb, Color("d23a3a"), maxf(1.0, _proj(0, 0).z * 2.0))
	_quad(-Sim.LANE_HALF, Sim.LANE_HALF, 708.0, 762.0, Color(1, 1, 1, 0.1))
	# Pin spots on the deck (where each pin stands in a fresh rack).
	if _proj(0, 720.0).z > 0:
		for row in 4:
			for i in row + 1:
				var sp := _p2((i - row / 2.0) * 12.0, Sim.HEAD_Y + row * 10.39)
				c.draw_circle(sp, maxf(0.6, _proj(0, 720.0).z * 1.2), Color(0.45, 0.3, 0.15, 0.35))
	# The pit and the masking unit behind the pins.
	_quad(-26.0, 26.0, 762.0, 790.0, Color("0a0a10"))
	var mu_a := _p2(-30.0, 790.0, 0.0)
	var mu_b := _p2(30.0, 790.0, 22.0)
	c.draw_rect(Rect2(mu_a.x, mu_b.y, mu_b.x - mu_a.x, mu_a.y - mu_b.y), Color("120c10") if not gang else Color("0a0412"))
	var lc := [Color("f5486e"), Color("3fa9f5"), Color("f5c842"), Color("3fdc8c")][(lane - 1) % 4] as Color
	var fsz := clampi(int((mu_a.y - mu_b.y) * 0.5), 5, 20)
	c.draw_string(_font, Vector2(mu_a.x, mu_b.y + fsz * 0.9), str(lane), HORIZONTAL_ALIGNMENT_CENTER, mu_b.x - mu_a.x, fsz, Color(lc, 0.9))
	# Kickbacks (side walls by the pins).
	for sx in [-1.0, 1.0]:
		var k0 := _p2(sx * 26.0, 700.0, 0.0)
		var k1 := _p2(sx * 26.0, 790.0, 0.0)
		var k2 := _p2(sx * 26.0, 790.0, 18.0)
		var k3 := _p2(sx * 26.0, 700.0, 18.0)
		if _proj(0, 700.0).z > 0:
			c.draw_colored_polygon(PackedVector2Array([k0, k1, k2, k3]), Color("3a2e44") if not gang else Color("2a1a40"))
			c.draw_line(k3, k2, Color(1, 1, 1, 0.12), 1.0)
	# Pins and ball, far to near.
	var objs: Array = []
	for i in sim.pins.size():
		var p: Dictionary = sim.pins[i]
		if not bool(p["gone"]):
			objs.append([(p["p"] as Vector2).y, "pin", i])
	if phase not in ["over", "opp"]:
		objs.append([sim.ball_p.y, "ball", 0])
	objs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var lift := (1.0 - _drop_t) * 24.0
	for o: Array in objs:
		if str(o[1]) == "pin":
			_draw_pin(sim.pins[int(o[2])], lift)
		else:
			_tb.flush(c)
			_draw_ball()
	_tb.flush(c)  # tilted/fallen pins (~25 discs each) go out as one draw call per run of them
	if phase == "sweep":
		_draw_sweep_bar()
	# Aim guide: the ball's real path (no release error) at a sweet-band throw.
	if phase in ["line", "aim", "power"]:
		var pw := (SWEET.x + SWEET.y) / 2.0 if phase != "power" else power
		var pts := Sim.path(x0, aim if phase != "line" else 0.0, 230.0 + 140.0 * pw, spin_step / 3.0)
		var alpha := 0.3 if phase == "line" else 0.7
		for k in range(1, pts.size()):
			if k % 2 == 0:
				var a2 := _p2(pts[k - 1].x, pts[k - 1].y, 0.5)
				var b2 := _p2(pts[k].x, pts[k].y, 0.5)
				var hot := pts[k].y > Sim.HOOK_FROM and spin_step != 0
				c.draw_line(a2, b2, Color(1, 0.75, 0.4, alpha) if hot else Color(1, 1, 0.6, alpha), 1.5)
		if phase != "line":
			var end := pts[pts.size() - 1]
			if absf(end.x) <= Sim.LANE_HALF:
				var e2 := _p2(end.x, end.y, 0.5)
				c.draw_circle(e2, 2.5, Color(1, 0.9, 0.3))
	_draw_parts()
	_draw_sheet()
	_draw_pin_chart()
	_draw_controls()
	if _msg_t > 0.0 and _msg != "":
		var big := _msg.ends_with("!")
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - _msg_age * 6.0)
		var sz := int((22 if big else 12) * pop)
		var fade := clampf(_msg_t * 3.0, 0.0, 1.0)
		var y := 196.0
		c.draw_string_outline(_font, Vector2(0, y), _msg, HORIZONTAL_ALIGNMENT_CENTER, 270, sz, 5, Color(0, 0, 0, 0.8 * fade))
		c.draw_string(_font, Vector2(0, y), _msg, HORIZONTAL_ALIGNMENT_CENTER, 270, sz, Color(Color(1, 0.85, 0.3) if big else Color.WHITE, fade))
		if _msg_sub != "":
			c.draw_string_outline(_font, Vector2(0, y + 16), _msg_sub, HORIZONTAL_ALIGNMENT_CENTER, 270, 9, 4, Color(0, 0, 0, 0.8 * fade))
			c.draw_string(_font, Vector2(0, y + 16), _msg_sub, HORIZONTAL_ALIGNMENT_CENTER, 270, 9, Color(0.9, 0.9, 1, fade))
	if phase == "opp":
		_draw_opp_card()
	if phase == "over":
		_draw_final()


## A pin: standing (profile), rocking, or tipping over and lying along its fall direction.
func _draw_pin(p: Dictionary, lift := 0.0) -> void:
	var pos: Vector2 = p["p"]
	var base := _proj(pos.x, pos.y, 0.0)
	if base.z <= 0:
		return
	var s := base.z
	var c := _canvas
	var fall := float(p["fall"])
	var wob := float(p.get("wob", 0.0))
	var lifted := not bool(p["down"]) and lift > 0.1
	var standing := fall <= 0.01 and wob < 0.04
	if standing:
		_tb.flush(c)  # keep the y-sorted order: earlier batched pins first
	if not lifted:
		if standing:
			c.draw_circle(Vector2(base.x, base.y), maxf(1.0, 2.6 * s), Color(0, 0, 0, 0.25))
		else:
			_tb.circle(Vector2(base.x, base.y), maxf(1.0, 2.6 * s), Color(0, 0, 0, 0.25))
	if standing:
		# Standing: a pin profile, belly, neck and head, with the red stripes.
		var prof := [[0.0, 1.1], [2.0, 1.9], [4.5, 2.4], [7.0, 2.0], [9.5, 1.0], [11.0, 0.9], [13.2, 1.25], [15.0, 0.4]]
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var lh := lift if not bool(p["down"]) else 0.0
		for q: Array in prof:
			left.append(_p2(pos.x - float(q[1]), pos.y, float(q[0]) + lh))
			right.append(_p2(pos.x + float(q[1]), pos.y, float(q[0]) + lh))
		right.reverse()
		var poly := left + right
		if Geometry2D.triangulate_polygon(poly).is_empty():
			return
		c.draw_colored_polygon(poly, Color(0.97, 0.96, 0.93))
		c.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.5, 0.5, 0.55, 0.6), maxf(0.5, s * 0.6))
		for band in [9.3, 10.4]:
			var b0 := _p2(pos.x - 1.0, pos.y, band + lh)
			var b1 := _p2(pos.x + 1.0, pos.y, band + lh)
			c.draw_line(b0, b1, Color("d23a3a"), maxf(1.0, s * 0.9))
		var hl := _p2(pos.x - 0.9, pos.y, 5.5 + lh)
		c.draw_circle(hl, maxf(0.6, s * 0.6), Color(1, 1, 1, 0.8))
		return
	# Tilted (rocking or falling): a chain of discs along the pin's axis, so it reads
	# as a solid pin from any angle, even pointing straight down the lane.
	var d: Vector2 = p["dir"] if fall > 0.01 else p["wdir"]
	if d.length() < 0.1:
		d = Vector2.UP
	var th := fall * PI / 2.0
	if fall <= 0.01:
		th = sin(Time.get_ticks_msec() / 45.0) * wob * 0.35
	var prof2 := [[0.0, 1.1], [1.5, 1.7], [3.0, 2.2], [4.5, 2.4], [6.0, 2.2], [7.5, 1.7], [9.0, 1.1], [10.2, 0.9], [11.5, 1.05], [13.0, 1.25], [14.4, 0.8]]
	var rest := 2.0 * sin(absf(th))  # a lying pin rests on its belly
	var pts: Array = []
	for q: Array in prof2:
		var along := float(q[0])
		var gp := pos + d * along * sin(th)
		var hh := along * cos(th) + rest * (1.0 - along / 15.0)
		var sp3 := _proj(gp.x, gp.y, maxf(0.0, hh))
		if sp3.z <= 0:
			return
		pts.append([Vector2(sp3.x, sp3.y), float(q[1]) * sp3.z, along])
	for q: Array in pts:
		_tb.circle(q[0], float(q[1]) + maxf(0.5, s * 0.5), Color(0.42, 0.42, 0.48))
	for q: Array in pts:
		var along2 := float(q[2])
		var col := Color("d23a3a") if (along2 > 9.0 and along2 < 10.6) else Color(0.95, 0.94, 0.9)
		_tb.circle(q[0], float(q[1]), col)
	var belly: Array = pts[3]
	_tb.circle((belly[0] as Vector2) + Vector2(-0.35, -0.35) * float(belly[1]), maxf(0.6, float(belly[1]) * 0.35), Color(1, 1, 1, 0.75))


func _draw_ball() -> void:
	var b := sim.ball_p
	var hh := Sim.BALL_R - (2.5 if sim.gutter else 0.0)
	var ctr := _proj(b.x, b.y, hh)
	if ctr.z <= 0:
		return
	var r := Sim.BALL_R * ctr.z
	var c := _canvas
	var g := _proj(b.x, b.y, 0.0)
	c.draw_circle(Vector2(g.x, g.y), r * 0.9, Color(0, 0, 0, 0.3))
	var col := Color("2f6fd6") if GameState.is_penguins() else Color("e03aa0")
	c.draw_circle(Vector2(ctr.x, ctr.y), r, col)
	c.draw_circle(Vector2(ctr.x, ctr.y), r, col.darkened(0.4), false, maxf(0.8, r * 0.08))
	# Finger holes roll with the ball (and turn with the spin).
	var rot := b.y * 0.12
	var tilt := sim.spin * 0.6 if phase == "roll" else spin_step / 5.0
	for k in 3:
		var ang := rot + k * 0.45
		var hp := Vector2(ctr.x, ctr.y) + Vector2(cos(ang + tilt) * 0.35, sin(ang) * 0.5 - 0.1) * r
		if sin(ang) < 0.7:
			c.draw_circle(hp, maxf(0.8, r * 0.13), Color(0.05, 0.05, 0.1, 0.85))
	c.draw_circle(Vector2(ctr.x - r * 0.35, ctr.y - r * 0.4), maxf(0.8, r * 0.22), Color(1, 1, 1, 0.45))


## The pinsetter: a bar drops in front of the deck and rakes the fallen pins away.
func _draw_sweep_bar() -> void:
	var t := clampf(_phase_t / 0.75, 0.0, 1.0)
	var down := clampf(t * 4.0, 0.0, 1.0)
	var push := clampf((t - 0.25) / 0.6, 0.0, 1.0)
	var y := lerpf(700.0, 770.0, push)
	var h := lerpf(26.0, 1.0, down)
	var a := _p2(-25.0, y, h + 5.0)
	var b := _p2(25.0, y, h)
	if _proj(0, y).z <= 0:
		return
	_canvas.draw_rect(Rect2(a.x, a.y, b.x - a.x, maxf(2.0, b.y - a.y)), Color("2a2a34"))
	_canvas.draw_rect(Rect2(a.x, a.y, b.x - a.x, maxf(2.0, b.y - a.y)), Color(1, 0.8, 0.3, 0.6), false, 1.0)


func _draw_parts() -> void:
	for p: Array in _parts:
		var life := float(p[3])
		_canvas.draw_rect(Rect2(p[0] as Vector2, Vector2(2.5, 2.5)), Color(p[2] as Color, clampf(life * 2.0, 0.0, 1.0)))


## The overhead monitor: ten frames, marks and running totals (and the villager's line).
func _draw_sheet() -> void:
	var c := _canvas
	var r := _sheet_rect()
	c.draw_rect(r, Color("1b1b26"))
	c.draw_rect(r, Color("5a5a70"), false, 1.0)
	var pname := str(GameState.run.get("names", {}).get("character", "You")) if GameState.run.size() > 0 else "You"
	var best := Tickets.best_score("bowling") if GameState.run.size() > 0 else 0
	var cur := int(next_state(rolls)["frame"]) if phase != "over" else -1
	if opp_id == "":
		c.draw_string(_font, Vector2(9, 15), "%s · LANE %d" % [pname.to_upper(), lane], HORIZONTAL_ALIGNMENT_LEFT, 120, 8, Color(0.75, 0.9, 1))
		c.draw_string(_font, Vector2(130, 15), "BEST %d" % best, HORIZONTAL_ALIGNMENT_LEFT, 60, 8, Color(1, 0.85, 0.4))
		_sheet_row(rolls, 20, 40, cur, true)
		var py := 72.0
		for row: Dictionary in coop_rows():  # C17 P4: one line per partner: name, frame, total
			if bool(row["me"]):
				continue
			var fr: Array = row["frames"]
			var ln := "%s   frame %d   %d" % [str(row["name"]).to_upper(), mini(fr.size() + 1, 10) if fr.size() < 10 else 10, int(fr[-1]) if not fr.is_empty() else 0]
			if fr.size() >= 10:
				ln += "  done"
			c.draw_string(_font, Vector2(9, py), ln, HORIZONTAL_ALIGNMENT_LEFT, 250, 8, Color(0.6, 0.85, 1))
			py += 11.0
	else:
		var head := "LANE %d · VS %s" % [lane, opp_name().to_upper()]
		c.draw_string(_font, Vector2(9, 15), head, HORIZONTAL_ALIGNMENT_LEFT, 170, fit_size(head, 170.0, 8), Color(0.75, 0.9, 1))
		c.draw_string(_font, Vector2(180, 15), "BEST %d" % best, HORIZONTAL_ALIGNMENT_RIGHT, 80, 8, Color(1, 0.85, 0.4))
		var shown_opp := opp_rolls
		if phase == "opp":
			shown_opp = opp_rolls.slice(0, _opp_from + _opp_show)
		_sheet_row(rolls, 19, 34, cur, true)
		_sheet_row(shown_opp, 54, 34, -1, false, opp_name().to_upper())


## The largest font size (down to 4) at which text fits in width px.
func fit_size(text: String, width: float, size: int) -> int:
	var sz := size
	while sz > 4 and _font != null and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		sz -= 1
	return sz


func _sheet_row(rs: Array, top: float, h: float, cur: int, frame_nums: bool, tag := "") -> void:
	var c := _canvas
	var totals := frame_totals(rs)
	var x := 8.0
	var bg := Color("262636") if frame_nums else Color("1f2a36")
	for f in 10:
		var w := 24.0 if f < 9 else 34.0
		var box := Rect2(x, top, w, h)
		c.draw_rect(box, bg if f != cur else Color("34345a"))
		c.draw_rect(box, Color("6a6a88"), false, 1.0)
		if frame_nums:
			c.draw_string(_font, Vector2(x, top + 7), str(f + 1), HORIZONTAL_ALIGNMENT_CENTER, w, DisplayMode.df(6), Color(0.6, 0.6, 0.75))
		var marks := frame_marks(rs, f)
		var nbox := 2 if f < 9 else 3
		for k in nbox:
			var mb := Rect2(x + w - (nbox - k) * 10.0, top + 9, 10, 10)
			c.draw_rect(mb, Color(0, 0, 0, 0.25))
			c.draw_rect(mb, Color("6a6a88"), false, 1.0)
			if k < marks.size() and str(marks[k]) != "":
				var mc := Color(1, 0.4, 0.4) if str(marks[k]) == "X" else (Color(0.5, 0.85, 1) if str(marks[k]) == "/" else Color.WHITE)
				c.draw_string(_font, Vector2(mb.position.x, mb.end.y - 2), str(marks[k]), HORIZONTAL_ALIGNMENT_CENTER, 10, 8, mc)
		if f < totals.size() and int(totals[f]) >= 0:
			c.draw_string(_font, Vector2(x, top + h - 4), str(int(totals[f])), HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color(1, 1, 0.85))
		x += w + 0.5
	if tag != "" and not frame_nums:
		# The opponent's whole name along the row's free top strip, never cut (c3_17 #4).
		var tw := 9 * 24.0 - 4.0
		var fs := fit_size(tag, tw, 6)
		var wide := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if _font != null else 30.0
		c.draw_rect(Rect2(8.5, top + 0.5, wide + 3.0, 8.0), bg)  # a plate so the frame lines don't cut the name
		c.draw_string(_font, Vector2(9.5, top + 7), tag, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, Color(0.6, 0.85, 1))


## The ten-pin chart (standing / down) beside the lane.
func _draw_pin_chart() -> void:
	var c := _canvas
	var o := Vector2(242, _sheet_rect().end.y + 26)
	c.draw_rect(Rect2(o.x - 22, o.y - 18, 44, 40), Color(0, 0, 0, 0.45))
	var k := 0
	for row in 4:
		for i in row + 1:
			var p := o + Vector2((i - row / 2.0) * 10.0, 14.0 - row * 9.0)
			var pin: Dictionary = sim.pins[k] if k < sim.pins.size() else {}
			var down := pin.is_empty() or bool(pin.get("down", false)) or bool(pin.get("gone", false))
			var was := k < _was_down.size() and bool(_was_down[k])
			var col := Color(0.25, 0.25, 0.3) if (down and was) else (Color(1, 0.35, 0.3) if down else Color(0.97, 0.96, 0.93))
			c.draw_circle(p, 3.4, col)
			k += 1


func _btn(r: Rect2, text: String, on := true, hot := false) -> void:
	var c := _canvas
	c.draw_rect(r, Color(0.1, 0.1, 0.16, 0.85) if not hot else Color(0.35, 0.25, 0.08, 0.95))
	c.draw_rect(r, Color(1, 1, 1, 0.5 if on else 0.15), false, 1.0)
	c.draw_string(_font, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 4), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 1, 1, 1.0 if on else 0.35))


func _draw_controls() -> void:
	var c := _canvas
	var tip := ""
	match phase:
		"line": tip = _verb("Drag the ball or ◀ ▶ · ↶ ↷ spin · then GO", "◀ ▶ line · ▲ ▼ spin · A: go")
		"aim": tip = _verb("Tap", "Press A") + " when the line hits the pocket"
		"power": tip = _verb("Tap", "Press A") + " in the gold band for a clean release"
		"opp": tip = _verb("Tap", "Press A") + " to carry on"
		"wait": tip = wait_text()
	c.draw_rect(Rect2(0, 372, 270, 108), Color(0.05, 0.04, 0.08, 0.9))
	if tip != "":
		c.draw_string(_font, Vector2(0, 388), tip, HORIZONTAL_ALIGNMENT_CENTER, 270, 8, Color(0.85, 0.85, 1))
	var line := phase == "line"
	if not deck_hidden():
		_btn(BTN_L, "◀", line)
		_btn(BTN_R, "▶", line)
		_btn(BTN_SPIN_L, "↶", line)
		_btn(BTN_SPIN_R, "↷", line)
		var go_txt := "GO" if phase == "line" else ("LOCK" if phase == "aim" else ("ROLL" if phase == "power" else "OK"))
		_btn(BTN_GO, go_txt, phase != "roll", phase in ["aim", "power"])
		_btn(_btn_quit, "✕", true, _quit_arm > 0.0)
	# Frame and ball, and the score so far.
	var ns := next_state(rolls)
	var info := _info_r
	c.draw_rect(info, Color(0.1, 0.1, 0.16, 0.6))
	c.draw_rect(info, Color(1, 1, 1, 0.2), false, 1.0)
	if not bool(ns["over"]):
		c.draw_string(_font, Vector2(info.position.x, 412), "FRAME %d" % (int(ns["frame"]) + 1), HORIZONTAL_ALIGNMENT_CENTER, info.size.x, 10, Color(1, 0.9, 0.6))
		c.draw_string(_font, Vector2(info.position.x, 424), "ball %d · %d pin%s up" % [int(ns["ball"]) + 1, sim.standing(), "" if sim.standing() == 1 else "s"], HORIZONTAL_ALIGNMENT_CENTER, info.size.x, 8, Color(0.85, 0.85, 1, 0.8))
	c.draw_string(_font, Vector2(info.position.x, 446), str(score_of(rolls)), HORIZONTAL_ALIGNMENT_CENTER, info.size.x, 18, Color.WHITE)
	if opp_id != "":
		var diff := score_of(rolls) - score_of(opp_rolls.slice(0, _opp_from + _opp_show) if phase == "opp" else opp_rolls)
		var lead := "level" if diff == 0 else ("+%d" % diff if diff > 0 else "%d" % diff)
		c.draw_string(_font, Vector2(info.position.x, 461), "vs %s: %s" % [opp_name(), lead], HORIZONTAL_ALIGNMENT_CENTER, info.size.x, 8, Color(0.6, 1, 0.6) if diff > 0 else (Color(1, 0.6, 0.6) if diff < 0 else Color(0.85, 0.85, 1)))
	# Spin dial.
	var sc := Vector2(52, 474)
	for s in range(-3, 4):
		var dx := sc.x - s * 6.0
		c.draw_rect(Rect2(dx - 2, sc.y - 3, 4, 3), Color(1, 0.8, 0.3) if s == spin_step else Color(1, 1, 1, 0.2))
	var spin_txt := "straight" if spin_step == 0 else ("hook %s %d" % ["◀" if spin_step > 0 else "▶", absi(spin_step)])
	c.draw_string(_font, Vector2(98, 476), spin_txt, HORIZONTAL_ALIGNMENT_LEFT, 60, DisplayMode.df(7), Color(1, 1, 1, 0.6))
	# Power meter on the right of the lane, with the sweet band.
	if phase in ["aim", "power", "roll", "result"]:
		var pr := Rect2(250, 150, 12, 120)
		c.draw_rect(pr, Color(0, 0, 0, 0.6))
		var band := Rect2(pr.position.x + 1, pr.end.y - pr.size.y * SWEET.y, pr.size.x - 2, pr.size.y * (SWEET.y - SWEET.x))
		c.draw_rect(band, Color(1, 0.8, 0.25, 0.35))
		var shown := power if phase != "aim" else 0.0
		var h := pr.size.y * shown
		var good := shown >= SWEET.x and shown <= SWEET.y
		var pc := Color(1, 0.85, 0.3) if good else Color(0.3, 1, 0.4).lerp(Color(1, 0.3, 0.2), shown)
		c.draw_rect(Rect2(pr.position.x + 2, pr.end.y - h, pr.size.x - 4, h), pc)
		c.draw_rect(band, Color(1, 0.85, 0.3, 0.9), false, 1.0)
		c.draw_rect(pr, Color(1, 1, 1, 0.5), false, 1.0)
		c.draw_string(_font, Vector2(pr.position.x - 10, pr.end.y + 10), "POWER", HORIZONTAL_ALIGNMENT_CENTER, 32, DisplayMode.df(6), Color(1, 1, 1, 0.7))


## The villager's frame, ball by ball.
func _draw_opp_card() -> void:
	var c := _canvas
	var r := Rect2(24, 150, 222, 96)
	c.draw_rect(r, Color(0.08, 0.06, 0.12, 0.95))
	c.draw_rect(r, Color(0.55, 0.8, 1, 0.9), false, 2.0)
	var pid := Dialogue.portrait_for(opp_name())
	var tex: Texture2D = Art.tex("portraits/" + pid, "neutral") if pid != "" else null
	if tex:
		c.draw_texture_rect(tex, Rect2(r.position.x + 8, r.position.y + 10, 48, 48), false)
	var tx := r.position.x + (64 if tex else 10)
	var tw := r.end.x - tx - 8
	var f := int(next_state(opp_rolls.slice(0, _opp_from))["frame"])
	c.draw_string(_font, Vector2(tx, r.position.y + 20), "%s · frame %d" % [opp_name(), f + 1], HORIZONTAL_ALIGNMENT_LEFT, tw, 10, Color(0.75, 0.9, 1))
	var marks := frame_marks(opp_rolls.slice(0, _opp_from + _opp_show), f)
	var x := tx
	for k in marks.size():
		var m := str(marks[k])
		if m == "":
			continue
		var mc := Color(1, 0.4, 0.4) if m == "X" else (Color(0.5, 0.85, 1) if m == "/" else Color.WHITE)
		c.draw_rect(Rect2(x, r.position.y + 28, 22, 22), Color(0, 0, 0, 0.4))
		c.draw_string(_font, Vector2(x, r.position.y + 45), m, HORIZONTAL_ALIGNMENT_CENTER, 22, 16, mc)
		x += 26
	var line := ""
	if _opp_show >= opp_rolls.size() - _opp_from:
		var last := str(marks.back()) if not marks.is_empty() else ""
		line = "Strike! The whole rec hears it." if last == "X" else ("Picks up the spare." if last == "/" else "Leaves a few standing.")
		var diff := score_of(rolls) - score_of(opp_rolls)
		var lead := "All square." if diff == 0 else ("You lead by %d." % diff if diff > 0 else "%s leads by %d." % [opp_name(), -diff])
		c.draw_string(_font, Vector2(r.position.x + 8, r.end.y - 22), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 9, Color(1, 1, 1, 0.85))
		c.draw_string(_font, Vector2(r.position.x + 8, r.end.y - 9), lead, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 9, Color(1, 0.85, 0.4))
	else:
		c.draw_string(_font, Vector2(r.position.x + 8, r.end.y - 9), "...", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 10, Color(1, 1, 1, 0.6))


func _draw_final() -> void:
	var c := _canvas
	var vs := opp_id != ""
	var r := Rect2(26, 112, 218, 196 if vs else 178)
	c.draw_rect(r, Color(0.08, 0.06, 0.12, 0.96))
	c.draw_rect(r, Color(1, 0.85, 0.3, 0.9), false, 2.0)
	var sc := int(result.get("score", 0))
	var best := Tickets.best_score("bowling") if GameState.run.size() > 0 else 0
	var y := r.position.y + 22
	var title := "GAME OVER"
	if vs:
		var os := int(result.get("opp_score", 0))
		title = "YOU WIN!" if sc > os else ("A TIE!" if sc == os else "%s WINS" % opp_name().to_upper())
	c.draw_string(_font, Vector2(r.position.x, y), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 0.85, 0.3))
	y += 38
	if vs:
		c.draw_string(_font, Vector2(r.position.x, y), "%d" % sc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x / 2.0, 28, Color.WHITE)
		c.draw_string(_font, Vector2(r.position.x + r.size.x / 2.0, y), "%d" % int(result.get("opp_score", 0)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x / 2.0, 28, Color(0.75, 0.9, 1))
		c.draw_string(_font, Vector2(r.position.x, y + 12), "you", HORIZONTAL_ALIGNMENT_CENTER, r.size.x / 2.0, 8, Color(1, 1, 1, 0.6))
		c.draw_string(_font, Vector2(r.position.x + r.size.x / 2.0, y + 12), opp_name(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x / 2.0, 8, Color(0.75, 0.9, 1, 0.7))
		y += 30
	else:
		c.draw_string(_font, Vector2(r.position.x, y), str(sc), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color.WHITE)
		y += 22
	c.draw_string(_font, Vector2(r.position.x, y), "%d strike%s · %d spare%s" % [int(result.get("strikes", 0)), "" if int(result.get("strikes", 0)) == 1 else "s", int(result.get("spares", 0)), "" if int(result.get("spares", 0)) == 1 else "s"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Color(0.8, 0.85, 1))
	y += 16
	# Ticket breakdown.
	var t := RecCenter.tickets_for(sc, int(result.get("strikes", 0)), int(result.get("spares", 0)))
	var bonus := int(result.get("bonus", 0))
	c.draw_string(_font, Vector2(r.position.x, y + 8), "+%d tickets" % (t + bonus), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(1, 0.7, 0.9))
	y += 22
	if bonus > 0:
		c.draw_string(_font, Vector2(r.position.x, y), "(%d for the game, %d for %s)" % [t, bonus, "beating " + opp_name() if bool(result.get("won", false)) else "the tie"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(1, 0.8, 0.95, 0.75))
		y += 13
	if sc > best:
		c.draw_string(_font, Vector2(r.position.x, y + 4), "NEW PERSONAL BEST!", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(1, 0.9, 0.3, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)))
		y += 14
		var unlocked := _prize_unlock(best, sc)
		if unlocked != "":
			c.draw_string(_font, Vector2(r.position.x, y + 4), unlocked, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.6, 1, 0.7))
	c.draw_string(_font, Vector2(r.position.x, r.end.y - 10), _verb("Tap", "Press A") + " to finish", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(1, 1, 1, 0.7))
	_draw_parts()


## "Prize counter: Top Hat unlocked!" when this score opens a new high-score prize.
func _prize_unlock(old_best: int, sc: int) -> String:
	if GameState.run.is_empty():
		return ""
	var names: Array = []
	var ps: Dictionary = Tickets.prizes().get("prizes", {})
	for id in ps:
		var need := int(((ps[id] as Dictionary).get("need", {}) as Dictionary).get("best", {}).get("bowling", 0))
		if need > old_best and need <= sc:
			names.append(str(GameState.items.get(str((ps[id] as Dictionary).get("item", id)), {}).get("name", id)))
	if names.is_empty():
		return ""
	return "Prize counter: %s unlocked!" % ", ".join(names)


## Line for the bottom card while waiting on partners (C17 P4).
func wait_text() -> String:
	var who := _cg().waiting_on(coop_sid, int(next_state(rolls)["frame"]) + 1)
	return "Waiting for %s" % ", ".join(who) if not who.is_empty() else "Next frame"
