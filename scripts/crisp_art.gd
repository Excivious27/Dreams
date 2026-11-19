class_name CrispArt
## Sharp-pixel material for magnified 2x-detail art (shaders/sharp_pixel.gdshader).
## GameMap.prop() gives it to buildings, props and nature sprites, so on a phone
## (canvas drawn at 3-4x) they stay crisp instead of bilinear-soft; at 1:1 or
## smaller it samples exactly like LINEAR. One shared material keeps batching.
## `CrispArt.enabled = false` turns it off (tests comparing raw output).

static var enabled := true
static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/sharp_pixel.gdshader")
	return _mat


static func apply(ci: CanvasItem) -> void:
	if enabled and ci != null and OS.get_environment("CRISP") != "0" and ci.material == null:
		ci.material = material()
