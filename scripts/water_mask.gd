class_name WaterMask
extends Node2D
## One body of water drawn by shaders/water_mask.gdshader: a curved, noisy
## shoreline instead of stair-stepped cells. Gameplay still uses the cells; this
## only draws them. Sits at the map's content offset, like the anim layer.

const SHADER := preload("res://shaders/water_mask.gdshader")

var rect := Rect2()


static func make(m: GameMap, cells: Dictionary, seam: String, opts := {}, lut := false) -> WaterMask:
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
	# R: the cells. G: some cell within 1 (else the shader discards after one
	# fetch). B: every cell within 1 is water (open water: no shore maths). The blur
	# reads texels at most 1.75 cells from a pixel, which is within 1 texel of one of
	# the 4 texels the lut fetch blends, so radius 1 is exact (3 sent 2x the pixels
	# down the 14-fetch shore path). Only
	# live water bodies (lut) work these out; baked patches keep G=1, B=0.
	var w := size.x
	var h := size.y
	var base := PackedByteArray()
	base.resize(w * h)
	for c: Vector2i in cells:
		base[(c.y - mn.y) * w + (c.x - mn.x)] = 1
	var near := _morph(base, w, h, true) if lut else PackedByteArray()
	var open := _morph(base, w, h, false) if lut else PackedByteArray()
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for i in w * h:
		data[i * 3] = base[i] * 255
		data[i * 3 + 1] = near[i] * 255 if lut else 255
		data[i * 3 + 2] = open[i] * 255 if lut else 0
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
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


## Radius-1 square dilate (grow) or erode (shrink) of a 0/1 grid, as two 1-D
## passes. Outside the grid counts as no water.
static func _morph(src: PackedByteArray, w: int, h: int, grow: bool) -> PackedByteArray:
	var tmp := PackedByteArray()
	tmp.resize(w * h)
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v := 0 if grow else 1
			for d in range(-1, 2):
				var xx := x + d
				var s := src[y * w + xx] if xx >= 0 and xx < w else 0
				v = maxi(v, s) if grow else mini(v, s)
			tmp[y * w + x] = v
	for y in h:
		for x in w:
			var v := 0 if grow else 1
			for d in range(-1, 2):
				var yy := y + d
				var s := tmp[yy * w + x] if yy >= 0 and yy < h else 0
				v = maxi(v, s) if grow else mini(v, s)
			out[y * w + x] = v
	return out
