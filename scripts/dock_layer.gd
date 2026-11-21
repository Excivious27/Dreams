class_name DockLayer
extends Node2D
## Draws dock planks over water for the cells the map marks as "dock".
## The dock tile is a 3x3 set (rimmed edges, post-capped corners): each cell picks
## its piece from its neighbours, the open south edge casts a shadow on the water
## and stands on pilings (c5_03 #6: piers were flat plank rectangles).

var map: GameMap
## The 3x3 plank set: "dock" (wood) or "concrete_pier" (the gangster harbour, c14_04-26).
var tiles_name := "dock"


func _ready() -> void:
	z_index = 0


func _is_dock(c: Vector2i) -> bool:
	return map.things.has(c) and (str(map.things[c].get("type", "")) in ["dock", "ferry"] or bool(map.things[c].get("pier", false)))


func _draw() -> void:
	if map == null:
		return
	var cells: Array[Vector2i] = []
	for k in map.things:
		if _is_dock(k):  # dock/ferry cells and any thing standing on the planks ("pier": true)
			cells.append(k)
	var post := Art.tex("props", "dock2_post")
	# Shadows and pilings first (under the planks' south rim).
	for k: Vector2i in cells:
		if _is_dock(k + Vector2i(0, 1)):
			continue
		var at := Vector2(k * GameMap.TILE)
		draw_rect(Rect2(at + Vector2(0, 16), Vector2(16, 4)), Color(0.02, 0.06, 0.12, 0.28))
		if post != null:
			for px: float in ([1.0, 11.0] if not _is_dock(k + Vector2i(1, 0)) or not _is_dock(k + Vector2i(-1, 0)) else [6.0]):
				if (px == 1.0 and _is_dock(k + Vector2i(-1, 0))) or (px == 11.0 and _is_dock(k + Vector2i(1, 0))):
					continue
				draw_texture_rect(post, Rect2(at + Vector2(px, 9), Vector2(4, 11)), false)
	for k: Vector2i in cells:
		var at := Vector2(k * GameMap.TILE)
		var l := _is_dock(k + Vector2i(-1, 0))
		var r := _is_dock(k + Vector2i(1, 0))
		var u := _is_dock(k + Vector2i(0, -1))
		var d := _is_dock(k + Vector2i(0, 1))
		var ix := 1 if (l == r) else (0 if not l else 2)
		var iy := 1 if (u == d) else (0 if not u else 2)
		if not Art.draw_tile(self, "tiles", tiles_name, at, iy * 3 + ix):
			draw_rect(Rect2(at, Vector2(16, 16)), Color("a07a4c"))
