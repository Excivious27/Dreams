class_name Paddle
extends Node2D
## A follower in the water (the pup, a walking partner): it swims instead of
## walking on the surface. A band of water with a ripple edge covers its legs,
## the body sits a little lower and bobs, and a splash marks going in and out.
## The host calls update(delta) every frame and reads the result (in water?).
## Water colours match Player._update_wade.

var host: Node2D
var body: Node2D          # the sprite that sinks and bobs (host's AnimatedSprite2D)
var map: GameMap
var half_w := 6.0         # band half-width (px)
var depth := 7.0          # band height (px)
var on := false
var _t := 0.0
var _body_y := 0.0


static func attach(h: Node2D, b: Node2D, m: GameMap, hw: float, dp: float) -> Paddle:
	var p := Paddle.new()
	p.host = h
	p.body = b
	p.map = m
	p.half_w = hw
	p.depth = dp
	p.z_index = 1
	p.visible = false
	h.add_child(p)
	return p


func cell() -> Vector2i:
	return map.world_to_cell(host.position - Vector2(0, 2))


## Is the host in a water cell? Updates the band, the bob and the splash.
func update(delta: float) -> bool:
	if map == null or host == null:
		return false
	var now: bool = host.visible and map.is_water_cell(cell())
	if now != on:
		on = now
		visible = on
		if body:
			if on:
				_body_y = body.position.y
			else:
				body.position.y = _body_y
		if host.visible and map.is_inside_tree():
			map.fx("splash", host.position, 9.0, 0.4)
	if on:
		_t += delta
		if body:
			body.position.y = _body_y + 2.0 + sin(_t * 5.0) * 0.8
		queue_redraw()
	return on


func _draw() -> void:
	var th: Dictionary = map.things.get(cell(), {}) if map else {}
	var sh := "sand" if str(th.get("type", "")) == "sea" else str(th.get("shore", map.border_water_shore if map else ""))
	var col: Color = {"sand": Color(0.10, 0.26, 0.48, 0.85), "quay": Color(0.10, 0.26, 0.48, 0.85), "river": Color(0.12, 0.30, 0.42, 0.85), "bog": Color(0.33, 0.30, 0.2, 0.95)}.get(sh, Color(0.13, 0.45, 0.50, 0.85))
	var r := depth * 0.5
	draw_rect(Rect2(-half_w, -depth, half_w * 2.0, depth), col)
	draw_circle(Vector2(-half_w, -r), r, col)
	draw_circle(Vector2(half_w, -r), r, col)
	var n := maxi(3, int(half_w * 2.0 / 4.0) + 1)
	for i in n:
		var x := -half_w - 2.0 + i * (half_w * 2.0 + 4.0) / float(n - 1)
		draw_circle(Vector2(x, -depth + sin(_t * 3.3 + i) * 0.8), 2.0, col)
	draw_arc(Vector2(0, -depth + 1.0), half_w + 5.0, PI * 1.05, PI * 1.95, 12, Color(1, 1, 1, 0.5), 1.0)
