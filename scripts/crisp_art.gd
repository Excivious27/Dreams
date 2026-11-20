class_name CrispArt
## Sharp-pixel material for magnified 2x-detail art (shaders/sharp_pixel.gdshader).
## GameMap.prop() gives it to buildings, props and nature sprites, so on a phone
## (canvas drawn at 3-4x) they stay crisp instead of bilinear-soft; at 1:1 or
## smaller it samples exactly like LINEAR. One shared material keeps batching.
## `CrispArt.enabled = false` turns it off (tests comparing raw output).

static var enabled := true
static var _mat: ShaderMaterial
static var _mat_pm: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/sharp_pixel.gdshader")
	return _mat


static func apply(ci: CanvasItem) -> void:
	if enabled and ci != null and OS.get_environment("CRISP") != "0" and ci.material == null:
		ci.material = material()


## Baked ground chunks (premultiplied render targets): crisp like the props on
## top of them instead of bilinear-soft brick/grass (c5_05 #3).
static func material_premul() -> ShaderMaterial:
	if _mat_pm == null:
		_mat_pm = ShaderMaterial.new()
		_mat_pm.shader = load("res://shaders/sharp_pixel_premul.gdshader")
	return _mat_pm


static func on() -> bool:
	return enabled and OS.get_environment("CRISP") != "0"


## Characters, pets, animals, critters, foes (any AnimatedSprite2D under a map):
## same crisp look as the buildings beside them (c5_05 #4, Tom #12). Leaves
## sprites with their own material (flash/tint shaders) alone.
static func apply_anim(n: Object) -> void:
	if not on() or not is_instance_valid(n) or not (n is AnimatedSprite2D):
		return
	var sp := n as AnimatedSprite2D
	if sp.material == null and not sp.use_parent_material:
		sp.material = material()
