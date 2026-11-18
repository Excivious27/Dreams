class_name DockLayer
extends Node2D
## Draws dock planks over water for the cells the map marks as "dock".

var map: GameMap


func _ready() -> void:
	z_index = 0


func _draw() -> void:
	if map == null:
		return
	for k in map.things:
		if str(map.things[k].get("type", "")) in ["dock", "ferry"]:
			var at := Vector2(k * GameMap.TILE)
			if not Art.draw_tile(self, "tiles", "dock", at, 4):
				draw_rect(Rect2(at, Vector2(16, 16)), Color("a07a4c"))
