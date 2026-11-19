class_name MoneyIcon
extends RefCounted
## The gangster arc's cash icon: art/gen/ui/cash (r13 render), with a drawn
## folded bill as a fallback; fly() sends a cash bundle (ui/cash_bundle) to you.


static func draw(c: CanvasItem, r: Rect2) -> void:
	if Art.has("ui", "cash"):
		var t := Art.tex("ui", "cash")
		var s := minf(r.size.x / t.get_width(), r.size.y / t.get_height())
		var sz := Vector2(t.get_width(), t.get_height()) * s
		c.draw_texture_rect(t, Rect2(r.position + (r.size - sz) * 0.5, sz), false)
		return
	# Two bills, the back one offset: dark outline, mint body, a darker centre oval.
	r = Rect2(r.position + Vector2(0, (r.size.y - 7.0) * 0.5), Vector2(r.size.x, minf(7.0, r.size.y)))
	var back := Rect2(r.position + Vector2(1, -1), r.size - Vector2(1, 0))
	c.draw_rect(back.grow(1), Color(0.08, 0.16, 0.1))
	c.draw_rect(back, Color(0.32, 0.6, 0.36))
	var front := Rect2(r.position + Vector2(0, 1), r.size - Vector2(1, 0))
	c.draw_rect(front.grow(1), Color(0.06, 0.14, 0.08))
	c.draw_rect(front, Color(0.5, 0.82, 0.5))
	c.draw_rect(Rect2(front.position + Vector2(1, 1), front.size - Vector2(2, 2)), Color(0.36, 0.68, 0.4), false, 1.0)
	var mid := front.get_center()
	c.draw_circle(mid, minf(front.size.y * 0.32, 2.2), Color(0.16, 0.38, 0.2))
	c.draw_rect(Rect2(mid + Vector2(-0.5, -front.size.y * 0.32), Vector2(1, front.size.y * 0.64)), Color(0.85, 1, 0.85))


## A bundle of cash pops out at `at` and flies into your pocket (gangster arc).
static func fly(m: GameMap, at: Vector2) -> void:
	if m == null or m.player == null or not Art.has("ui", "cash_bundle"):
		return
	var it := Sprite2D.new()
	it.texture = Art.tex("ui", "cash_bundle")
	it.scale = Vector2(0.3, 0.3)
	it.position = at + Vector2(0, -6)
	it.z_index = 5
	m.add_child(it)
	var tw := it.create_tween()
	tw.tween_property(it, "position", at + Vector2(0, -24), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_method(func(f: float) -> void:
		if is_instance_valid(m.player):
			it.position = it.position.lerp(m.player.position + Vector2(0, -10), f), 0.0, 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(it.queue_free)
