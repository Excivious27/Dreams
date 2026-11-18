extends Node2D
## One 16x16-cell piece of the mine floor (scripts/mine.gd draws it).
## The floor is split so the renderer skips the chunks that are off screen,
## and a broken rock redraws one chunk instead of the whole floor.
## layer 0 = ground (rock, floor, walls, lips, chasm), 1 = things on it + label.
## The mine adds every layer-0 chunk before every layer-1 chunk.

var map = null          # the Mine; untyped on purpose (draw_chunk is a Mine method)
var cells := Rect2i()   # content cells this chunk owns
var layer := 0


func _draw() -> void:
	if map != null:
		map.draw_chunk(self, cells, layer)
