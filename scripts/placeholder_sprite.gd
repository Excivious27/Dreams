class_name PlaceholderSprite
extends Node2D
## Stand-in for characters that have no art yet (penguins, Star Crystal).
## A simple rounded figure, anchored at the feet, with a gentle breathing bob.

var tint := Color("888888")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 0.6
	draw_circle(Vector2(0, -8 + bob), 7.0, tint)
	draw_circle(Vector2(0, -22 + bob), 7.5, tint.lightened(0.15))
	draw_circle(Vector2(-2.5, -24 + bob), 1.2, Color.WHITE)
	draw_circle(Vector2(2.5, -24 + bob), 1.2, Color.WHITE)
	draw_rect(Rect2(-6, -2, 12, 2), tint.darkened(0.3))
