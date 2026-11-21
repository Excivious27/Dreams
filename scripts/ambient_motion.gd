class_name AmbientMotion
extends Node2D
## C14b P3: one cheap per-map driver for code motion on outdoor props (boats and
## buoys bobbing, signs and lanterns swinging, rotors turning). Everything runs
## on game time (PlayClock), each entry has its own phase from its position so
## neighbours never move in lockstep, and reduced motion keeps ~30% amplitude.
## Offsets snap to 0.5 px so 2x-detail art doesn't shimmer.

const KIND_BOB := 0
const KIND_SWING := 1
const KIND_SPIN := 2
const KIND_BREATHE := 3

var _items: Array = []  # [node, kind, amp, period, phase, base_pos, base_rot, extra]


## The map's driver (made on first use; lives as a child of the map).
static func of(m: Node) -> AmbientMotion:
	if m == null:
		return null
	var real: Variant = m.get("_painter_of")  # baked drawing runs on a painter twin: use the real map
	if real is Node and is_instance_valid(real):
		m = real
	var n :=m.get_node_or_null("AmbientMotion")
	if n is AmbientMotion:
		return n
	var a := AmbientMotion.new()
	a.name = "AmbientMotion"
	m.add_child(a)
	return a


## Stable 0..1 phase from a position (cells or pixels).
static func phase(p: Vector2) -> float:
	var h := sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
	return h - floorf(h)


static func reduced() -> bool:
	return Settings.reduced_motion()


## Wind 0..1: P1's Anim.wind() once it lands, else from today's weather and season.
static func wind() -> float:
	if ResourceLoader.exists("res://scripts/anim.gd"):
		var an: Script = load("res://scripts/anim.gd")
		if an != null and an.has_method("wind"):
			return float(an.call("wind"))
	var w := GameState.weather_today() if GameState.run.has("day") else "clear"
	var v: float = {"storm": 1.0, "blizzard": 1.0, "wind": 0.8, "rain": 0.6, "snow": 0.4, "leaves": 0.5, "petals": 0.4}.get(w, 0.25)
	if GameState.season() == "fall":
		v += 0.1
	return clampf(v, 0.0, 1.0)


## Gentle float: amp px up/down on a period, plus a tiny roll (degrees).
func bob(node: Node2D, amp := 0.5, period := 3.0, roll_deg := 0.6) -> void:
	if node == null:
		return
	_items.append([node, KIND_BOB, amp, period, phase(node.position) * TAU, node.position, node.rotation, deg_to_rad(roll_deg)])


## Pendulum about the node's origin (put the origin at the hinge): +-deg, scaled by wind.
func swing(node: Node2D, deg := 3.0, period := 1.6) -> void:
	if node == null:
		return
	_items.append([node, KIND_SWING, deg_to_rad(deg), period, phase(node.position) * TAU, node.position, node.rotation, 0.0])


## Idle breath for a standing figure drawn feet-at-origin: scale.y rises by `amt`.
func breathe(node: Node2D, amt := 0.018, period := 3.6) -> void:
	if node == null:
		return
	_items.append([node, KIND_BREATHE, amt, period, phase(node.position) * TAU, node.position, node.rotation, node.scale.y])


## Continuous turn (rad/s at wind 1; calm still turns at 40%).
func spin(node: Node2D, rad_s := 0.9) -> void:
	if node == null:
		return
	node.rotation = phase(node.position) * TAU
	_items.append([node, KIND_SPIN, rad_s, 0.0, 0.0, node.position, node.rotation, 0.0])


func _process(delta: float) -> void:
	if _items.is_empty() or get_tree().paused:
		return
	var t := PlayClock.now()
	var k := 0.3 if reduced() else 1.0
	var wv := wind()
	var i := _items.size() - 1
	while i >= 0:
		var e: Array = _items[i]
		var n: Node2D = e[0] if is_instance_valid(e[0]) else null
		if n == null:
			_items.remove_at(i)
			i -= 1
			continue
		match int(e[1]):
			KIND_BOB:
				var s := sin(t * TAU / float(e[3]) + float(e[4]))
				n.position.y = (e[5] as Vector2).y + snappedf(float(e[2]) * k * s, 0.5)
				n.rotation = float(e[6]) + float(e[7]) * k * sin(t * TAU / (float(e[3]) * 1.37) + float(e[4]) * 1.7)
			KIND_SWING:
				var a := float(e[2]) * k * (0.35 + 0.65 * wv)
				n.rotation = float(e[6]) + a * (sin(t * TAU / float(e[3]) + float(e[4])) + 0.3 * sin(t * TAU / (float(e[3]) * 0.43) + float(e[4]) * 2.1))
			KIND_BREATHE:
				var b := 0.5 + 0.5 * sin(t * TAU / float(e[3]) + float(e[4]))
				n.scale.y = float(e[7]) * (1.0 + float(e[2]) * k * b * b)
			KIND_SPIN:
				n.rotation += float(e[2]) * delta * (0.4 + 0.6 * wv) * (0.25 if reduced() else 1.0)
		i -= 1
