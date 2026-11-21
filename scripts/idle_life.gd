class_name IdleLife
extends Node
## C14b P5: subtle Sun Haven-style idle life for characters (player, villagers,
## crew): a slow breath (a 1-2% feet-anchored stretch with a gentle counter
## squash) that fades in when the character stands still and out when it moves,
## so nobody stands as a frozen statue and nothing pops.
##
## Add as a child of the character; set `active` each frame (true while resting).
## It moves every node `targets` returns (default: the parent's Node2D children
## except cameras, shadows and labels), scaling each about the character's feet
## (the parent's origin), so doll layers, hats and overlays breathe together.
## Writes from other code (pose fits, flips, walk bobs) are noticed and become
## the new base, so it never fights or drifts. Time is game time (PlayClock):
## the breath stops under menus. Reduced motion: about 30% amplitude.

## Stretch at the top of a breath (share of height): ~0.5 px on a 26 px hero.
const AMP := 0.02
const SQUASH := 0.4  # x counter-squash share of the y stretch
const FADE := 3.0  # per second, in and out

var active := false
var amp := AMP
var period := 3.2
var phase := 0.0
## Optional Callable -> Array of Node2D to move; empty = parent's children.
var targets: Callable
var _w := 0.0
var _base := {}  # node instance id -> [scale, position]
var _wrote := {}  # node instance id -> [scale, position] we last wrote


## Stable per-character phase and period from a seed (an id or instance id),
## so two villagers side by side never breathe in step.
func seed_from(key: Variant) -> void:
	var h := absi(hash(str(key)))
	phase = float(h % 1000) / 1000.0
	period = 2.8 + float((h / 1000) % 9) * 0.1  # 2.8 .. 3.6 s


static func motion_scale() -> float:
	return 0.3 if Settings.reduced_motion() else 1.0


## The breath value at game time `t` (-1..1): a quicker inhale, a slower exhale.
static func breath(t: float, per: float, ph: float) -> float:
	var x := TAU * (t / maxf(0.5, per) + ph)
	return clampf(sin(x) + 0.22 * sin(2.0 * x), -1.2, 1.2) / 1.2


## The y stretch factor right now (1.0 = rest), for tests and callers.
func factor() -> float:
	return 1.0 + amp * motion_scale() * _w * breath(PlayClock.now(), period, phase)


func weight() -> float:
	return _w


func _ready() -> void:
	if phase == 0.0:
		seed_from(get_parent().get_instance_id() if get_parent() else 0)


func _list() -> Array:
	if targets.is_valid():
		return targets.call()
	var out: Array = []
	var p := get_parent()
	if p == null:
		return out
	for ch in p.get_children():
		if ch is Node2D and not (ch is Camera2D) and not str(ch.name).to_lower().contains("shadow"):
			out.append(ch)
	return out


func _process(delta: float) -> void:
	var goal := 1.0 if active else 0.0
	if get_tree() and get_tree().paused:
		return
	_w = move_toward(_w, goal, delta * FADE)
	if _w <= 0.0 and _wrote.is_empty():
		return
	var fy := factor()
	var fx := 1.0 - (fy - 1.0) * SQUASH
	var seen := {}
	for n: Node2D in _list():
		if not is_instance_valid(n):
			continue
		var k := n.get_instance_id()
		seen[k] = true
		var w: Array = _wrote.get(k, [])
		if w.is_empty() or n.scale != w[0] or n.position != w[1]:
			_base[k] = [n.scale, n.position]  # someone else set it: that's the new rest
		var b: Array = _base.get(k, [n.scale, n.position])
		var s: Vector2 = b[0]
		var p: Vector2 = b[1]
		if _w <= 0.0:
			n.scale = s
			n.position = p
			_wrote.erase(k)
			continue
		n.scale = Vector2(s.x * fx, s.y * fy)
		n.position = Vector2(p.x * fx, p.y * fy)
		_wrote[k] = [n.scale, n.position]
	for k in _wrote.keys():
		if not seen.has(k):
			_wrote.erase(k)
			_base.erase(k)
