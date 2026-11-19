class_name MoneyIcon
extends RefCounted
## The gangster arc's cash icon: art/gen/ui/cash if it exists, otherwise a small
## folded green bill drawn in code.


static func draw(c: CanvasItem, r: Rect2) -> void:
	if Art.has("ui", "cash"):
		var t := Art.tex("ui", "cash")
		var s := minf(r.size.x / t.get_width(), r.size.y / t.get_height())
		var sz := Vector2(t.get_width(), t.get_height()) * s
		c.draw_texture_rect(t, Rect2(r.position + (r.size - sz) * 0.5, sz), false)
		return
	# Two bills, the back one offset: dark outline, mint body, a darker centre oval.
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
