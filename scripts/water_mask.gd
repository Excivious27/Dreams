class_name WaterMask
extends Node2D
## One body of water drawn by shaders/water_mask.gdshader: a curved, noisy
## shoreline instead of stair-stepped cells. Gameplay still uses the cells; this
## only draws them. Sits at the map's content offset, like the anim layer.

const SHADER := preload("res://shaders/water_mask.gdshader")

var rect := Rect2()


static func make(m: GameMap, cells: Dictionary, seam: String, opts := {}) -> WaterMask:
	if cells.is_empty() or not Art.has("seamless", seam):
		return null
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-(1 << 20), -(1 << 20))
	for c: Vector2i in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	mn -= Vector2i(2, 2)
	mx += Vector2i(2, 2)
	var size := mx - mn + Vector2i.ONE
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for c: Vector2i in cells:
		img.set_pixel(c.x - mn.x, c.y - mn.y, Color.WHITE)
	var wm := WaterMask.new()
	wm.rect = Rect2(Vector2(mn * GameMap.TILE), Vector2(size * GameMap.TILE))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("water_tex", Art.tex("seamless", seam))
	mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("origin", Vector2(mn))
	mat.set_shader_parameter("grid", Vector2(size))
	for k in opts:
		mat.set_shader_parameter(k, opts[k])
	wm.material = mat
	wm.position = m.offset()
	wm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return wm


func _draw() -> void:
	draw_rect(rect, Color.WHITE)
