class_name PuppetSmooth
extends RefCounted
## C17 P3 (c17_11-06): smooth a remote player's position under phone-network
## latency and jitter (150-300 ms, bursts, 5% loss). Puppet (P5) owns one and calls
## step() every frame with the newest packet position:
##     position = _smooth.step(delta, target, seq)
##     var moving := _smooth.moving()   # drive walk/idle from what is shown
## It keeps a short buffer of (arrival time, position) snapshots and renders DELAY
## behind the newest, linear between the two snapshots around that moment; with no
## newer snapshot it carries on along the last velocity for at most EXTRAP, then
## eases to a stop. It snaps only on a warp (teleport flag or a gap no walk or ride
## could make). Time is the sum of the deltas it is given (game frames), so tests
## are deterministic.

const DELAY := 0.14        # render this far behind the newest snapshot
const EXTRAP := 0.2        # carry on along the last velocity at most this long
const KEEP := 12           # snapshots kept
const SNAP_MIN := 120.0    # px: a jump at least this far ...
const SNAP_SECS := 0.8     # ... and further than the speed could cover in this long, snaps
const RIDE_MAX := 260.0    # px/s: fastest believable mover (a rider with buffs)
const MOVING := 4.0        # px/s: slower than this reads as standing

var t := 0.0
var _buf: Array = []       # [time, Vector2]
var _last_target := Vector2.INF
var _last_seq := -1
var _shown := Vector2.ZERO
var _vel := Vector2.ZERO
var _has := false


## Forget everything and stand at p (scene change, door, first packet).
func reset(p: Vector2) -> void:
	_buf = [[t, p]]
	_last_target = p
	_shown = p
	_vel = Vector2.ZERO
	_has = true


## Advance by delta and feed the newest packet position. seq (if the sender sends
## one) drops out-of-order packets; teleport snaps (warps, doors, respawns).
func step(delta: float, target: Vector2, seq := -1, teleport := false) -> Vector2:
	t += maxf(0.0, delta)
	if not _has or teleport:
		reset(target)
		return _shown
	if seq >= 0:
		if seq <= _last_seq:
			target = _last_target   # an old packet came late: ignore it
		else:
			_last_seq = seq
	if target != _last_target:
		var prev: Vector2 = _buf[-1][1]
		var dt := maxf(0.05, t - float(_buf[-1][0]))
		var jump := target.distance_to(prev)
		if jump > maxf(SNAP_MIN, RIDE_MAX * maxf(dt, SNAP_SECS)):
			reset(target)
			return _shown
		_buf.append([t, target])
		_last_target = target
		while _buf.size() > KEEP:
			_buf.pop_front()
	var old := _shown
	_shown = _sample(t - DELAY)
	_vel = (_shown - old) / maxf(delta, 0.001)
	return _shown


func _sample(rt: float) -> Vector2:
	var n := _buf.size()
	if n == 1:
		return _buf[0][1]
	if rt <= float(_buf[0][0]):
		return _buf[0][1]
	for i in range(n - 1, 0, -1):
		var a: Array = _buf[i - 1]
		var b: Array = _buf[i]
		if rt >= float(a[0]) and rt <= float(b[0]):
			var span := maxf(0.001, float(b[0]) - float(a[0]))
			return (a[1] as Vector2).lerp(b[1], (rt - float(a[0])) / span)
	# Past the newest snapshot: carry on along the last segment, then stop.
	var a2: Array = _buf[n - 2]
	var b2: Array = _buf[n - 1]
	var span2 := float(b2[0]) - float(a2[0])
	if span2 <= 0.0 or span2 > 1.0:
		return b2[1]
	var v := ((b2[1] as Vector2) - (a2[1] as Vector2)) / span2
	var over := minf(rt - float(b2[0]), EXTRAP)
	# Ease out over the extrapolation window so it stops softly.
	var k := over * (1.0 - 0.5 * over / EXTRAP)
	return (b2[1] as Vector2) + v * k


## The shown speed in px/s.
func speed() -> float:
	return _vel.length()


## True while the shown puppet is actually moving (walk/run anim), false when it
## stands (idle anim), so it never walks in place while waiting for packets.
func moving() -> bool:
	return speed() > MOVING


## Seconds since the last new position arrived (a silent peer: dim the puppet).
func silent_for() -> float:
	return t - float(_buf[-1][0]) if _has else 0.0
