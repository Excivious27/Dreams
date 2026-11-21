class_name HouseExterior
extends Node2D
## Farmhouse exterior styles (C10b P3). One node, child of the farmhouse Sprite2D
## (farm._house_sprite), that dresses the painted house for the chosen look:
##  - roof / siding / window glass / stonework recolours: a palette ShaderMaterial
##    (shaders/house_palette.gdshader, sharp-pixel sampling built in) over the
##    per-tier part masks from tools/make_house_parts.py (art/gen/house_parts);
##  - a front door and porch dressings as child sprites (art from
##    tools/slice_c10b_ext.py), fitted to each tier's door box;
##  - chimney smoke on cold days and evenings (fx/chimney_smoke).
## Night and winter keep working: the farm swaps the sprite to <house>_night /
## <house>_snow; the mask is sampled in UV space and each part has a colour gate,
## so snow and lit window panes are never repainted, and this node re-fits its
## children whenever the texture changes. Door, collision, mailbox and rects are
## never touched (door_check).
## State: run.decor.house = {part: style id} ("" / missing = the painted original),
## run.decor.house_own = {style id: true} (bought once, re-applied free). Guests
## read the host's look through DecorMode.view().house.
## Entry points: `HouseExterior.apply(map, sprite)` (farm._place_props), the style
## picker `HouseExterior.open(map)` (Plans board > Restyle the farmhouse), pen fence
## names `HouseExterior.fence_set()` (farm._plan_fences).

const PARTS := ["roof", "siding", "glass", "stone", "door", "shutters", "porch", "mailbox", "fence"]
const PART_WORDS := {"roof": "Roof", "siding": "Walls", "glass": "Windows", "stone": "Stonework", "door": "Door", "shutters": "Shutters", "porch": "Porch", "mailbox": "Mailbox", "fence": "Pen fence"}
const PART_ID := {"roof": 1, "siding": 2, "glass": 3, "stone": 4}
const DIR := "res://art/gen/house_parts/"
## Prices are one-time (owning a style lets you switch back for free); arc-only
## styles show only in their arc. Ramps run dark -> light (5 stops).
const STYLES := {
	"roof": [
		{"id": "ext_roof_slate", "name": "Slate Blue", "price": 600, "ramp": ["1d2233", "2e3a57", "45587e", "6a80a6", "9db3cf"]},
		{"id": "ext_roof_moss", "name": "Moss Green", "price": 600, "ramp": ["1b2a17", "2e4826", "496b34", "6f9147", "a3c06a"]},
		{"id": "ext_roof_charcoal", "name": "Charcoal", "price": 450, "ramp": ["151517", "26262b", "3b3b42", "5a5a63", "86868f"]},
		{"id": "ext_roof_plum", "name": "Plum Shingle", "price": 900, "ramp": ["24112a", "3f1f48", "5f3368", "86508d", "b47fb6"]},
		{"id": "ext_roof_copper", "name": "Copper Teal", "price": 1400, "ramp": ["0f2a2a", "1d4a46", "2f6f66", "4f9a88", "8acbb2"]},
		{"id": "ext_roof_sand", "name": "Sandstone Tile", "price": 800, "ramp": ["3a2412", "6a4422", "9a6c3a", "c79a5f", "ead09a"]},
		{"id": "ext_roof_frost", "name": "Snowcap Blue", "price": 1200, "arc": "penguins", "ramp": ["1a2a44", "2d4a72", "4a74a3", "7aa6cf", "c4e2f5"]},
		{"id": "ext_roof_tar", "name": "Tar Paper", "price": 500, "arc": "gangsters", "ramp": ["0d0d10", "1b1b21", "2c2c35", "44444f", "666674"]},
	],
	"siding": [
		{"id": "ext_siding_white", "name": "Whitewash", "price": 500, "ramp": ["4a4038", "8a8076", "c2b9ae", "e6dfd4", "fbf8f1"]},
		{"id": "ext_siding_sage", "name": "Sage Paint", "price": 600, "ramp": ["27301f", "4a5a3a", "718560", "9db088", "cbdab5"]},
		{"id": "ext_siding_butter", "name": "Butter Yellow", "price": 600, "ramp": ["4a3712", "8a6a22", "c49a3a", "e6c56a", "f8e7a8"]},
		{"id": "ext_siding_grey", "name": "Dove Grey", "price": 450, "ramp": ["25262a", "4a4c52", "73767e", "9ea1a9", "cdd0d6"]},
		{"id": "ext_siding_barn", "name": "Barn Red Paint", "price": 700, "ramp": ["2a0e0c", "4f1a16", "7a2a22", "a54434", "cf7a62"]},
		{"id": "ext_siding_walnut", "name": "Dark Walnut", "price": 900, "ramp": ["1a0f08", "331e10", "523219", "754c28", "a0723f"]},
		{"id": "ext_siding_ice", "name": "Pastel Ice", "price": 1100, "arc": "penguins", "ramp": ["2c3f5a", "5677a0", "88a9cf", "b9d4ee", "e8f4ff"]},
		{"id": "ext_siding_soot", "name": "Soot Grey", "price": 650, "arc": "gangsters", "ramp": ["121214", "25252a", "3a3a41", "55555e", "7a7a84"]},
		{"id": "ext_siding_brick", "name": "Red Brick", "price": 1600, "wall": "wall_brick"},
		{"id": "ext_siding_fieldstone", "name": "Fieldstone", "price": 1800, "wall": "wall_fieldstone"},
		{"id": "ext_siding_logs", "name": "Log Cabin", "price": 1400, "wall": "wall_logs"},
	],
	"glass": [
		{"id": "ext_glass_amber", "name": "Amber Glass", "price": 350, "ramp": ["3a1e05", "6e3c0c", "a8641a", "d8962e", "f6cf74"]},
		{"id": "ext_glass_sea", "name": "Sea Glass", "price": 350, "ramp": ["0b2b26", "185247", "2a7e6b", "4fae94", "9be0c6"]},
		{"id": "ext_glass_rose", "name": "Rose Glass", "price": 450, "ramp": ["2e0b1c", "5a1838", "8a2e58", "bb5a85", "e9a2c0"]},
		{"id": "ext_glass_frost", "name": "Frosted Panes", "price": 500, "ramp": ["3b4654", "6d7c8e", "a0aebd", "cdd7e1", "f2f6fa"]},
	],
	"stone": [
		{"id": "ext_stone_field", "name": "Fieldstone Grey", "price": 400, "ramp": ["2a2a2e", "4d4e55", "75777f", "a2a4ab", "d2d3d8"]},
		{"id": "ext_stone_clay", "name": "Red Clay Brick", "price": 550, "ramp": ["2e110b", "5a2316", "8a3a26", "b65c3e", "dd9472"]},
		{"id": "ext_stone_moss", "name": "Mossy Stone", "price": 500, "ramp": ["1e2619", "3b4a2e", "5f7347", "8a9e68", "bccb98"]},
		{"id": "ext_stone_slate", "name": "Dark Slate", "price": 500, "ramp": ["101218", "1f232e", "343a49", "505a6e", "7d889e"]},
	],
	"door": [
		{"id": "ext_door_oak", "name": "Light Oak Door", "price": 400, "art": "door_oak"},
		{"id": "ext_door_dutch_blue", "name": "Blue Dutch Door", "price": 600, "art": "door_dutch_blue"},
		{"id": "ext_door_round_green", "name": "Porthole Door", "price": 700, "art": "door_round_green"},
		{"id": "ext_door_glass_white", "name": "Garden Glass Door", "price": 1100, "art": "door_glass_white"},
		{"id": "ext_door_barn_red", "name": "Barn Door", "price": 600, "art": "door_barn_red"},
		{"id": "ext_door_studded", "name": "Studded Oak Door", "price": 1300, "art": "door_studded"},
		{"id": "ext_door_ice", "name": "Snowflake Door", "price": 1200, "arc": "penguins", "art": "door_ice"},
		{"id": "ext_door_steel", "name": "Steel Door", "price": 1000, "arc": "gangsters", "art": "door_steel"},
	],
	"shutters": [
		{"id": "ext_shutters_green", "name": "Forest Shutters", "price": 350, "art": "shutter_green"},
		{"id": "ext_shutters_blue", "name": "Cornflower Shutters", "price": 350, "art": "shutter_blue"},
		{"id": "ext_shutters_white", "name": "White Shutters", "price": 350, "art": "shutter_white"},
		{"id": "ext_shutters_red", "name": "Barn Red Shutters", "price": 350, "art": "shutter_red"},
		{"id": "ext_shutters_ice", "name": "Snowflake Shutters", "price": 600, "arc": "penguins", "art": "shutter_ice"},
		{"id": "ext_shutters_steel", "name": "Steel Shutters", "price": 600, "arc": "gangsters", "art": "shutter_steel"},
	],
	"porch": [
		{"id": "ext_porch_fern", "name": "Potted Ferns", "price": 300, "art": "porch_fern", "pair": true, "h": 20},
		{"id": "ext_porch_sunflowers", "name": "Sunflower Barrels", "price": 450, "art": "porch_sunflowers", "pair": true, "h": 20},
		{"id": "ext_porch_bench", "name": "Porch Bench", "price": 500, "art": "porch_bench", "h": 17},
		{"id": "ext_porch_mat", "name": "Woven Mat", "price": 200, "art": "porch_mat", "mat": true, "h": 9},
		{"id": "ext_porch_lamp_post", "name": "Lamp Post", "price": 800, "art": "porch_lamp_post", "h": 30, "glow": true, "glow_at": [0.22, 0.28]},
		{"id": "ext_porch_birdbath", "name": "Birdbath", "price": 700, "art": "porch_birdbath", "h": 22},
		{"id": "ext_porch_penguin_lamp", "name": "Penguin Lantern", "price": 900, "arc": "penguins", "art": "porch_penguin_lamp", "h": 20, "glow": true, "glow_at": [0.5, 0.6]},
		{"id": "ext_porch_crates", "name": "Crate Planter", "price": 400, "arc": "gangsters", "art": "porch_crates", "h": 20},
	],
	"mailbox": [
		{"id": "ext_mailbox_white", "name": "White Post Box", "price": 250, "art": "mailbox_white"},
		{"id": "ext_mailbox_green", "name": "Log Post Box", "price": 250, "art": "mailbox_green"},
		{"id": "ext_mailbox_birdhouse", "name": "Birdhouse Box", "price": 450, "art": "mailbox_birdhouse"},
		{"id": "ext_mailbox_copper", "name": "Copper on Stone", "price": 700, "art": "mailbox_copper"},
		{"id": "ext_mailbox_barn", "name": "Little Barn Box", "price": 500, "art": "mailbox_barn"},
		{"id": "ext_mailbox_iron", "name": "Wrought Iron Box", "price": 800, "art": "mailbox_iron"},
		{"id": "ext_mailbox_ice", "name": "Snowcap Box", "price": 600, "arc": "penguins", "art": "mailbox_ice"},
		{"id": "ext_mailbox_steel", "name": "City Steel Box", "price": 400, "arc": "gangsters", "art": "mailbox_steel"},
	],
	"fence": [
		{"id": "ext_fence_wood", "name": "Farm Rail", "price": 300, "fence": ["fence2_wood_h", "fence2_wood_end", "fence2_wood_gate_open"]},
		{"id": "ext_fence_stone", "name": "Fieldstone Wall", "price": 900, "fence": ["fence2_stone_h", "fence2_stone_end", "fence2_stone_gate_open"]},
		{"id": "ext_fence_iron", "name": "Wrought Iron", "price": 1500, "fence": ["fence2_iron_h", "fence2_iron_end", "fence2_iron_gate_open"]},
		{"id": "ext_fence_chain", "name": "Chain-Link", "price": 300, "arc": "gangsters", "fence": ["chain_fence_h", "chain_fence_v", "chain_fence_gate_open"]},
	],
}
## Chimney tops (day-picture px) per house picture, for the smoke.
const CHIMNEYS := {"house": [Vector2(150, 20)], "house_2": [Vector2(162, 8), Vector2(262, 19)], "house_3": [Vector2(84, 9), Vector2(309, 9)]}
const NIGHT_TINT := Color(0.62, 0.6, 0.78)
## Winter nights (c10b_01-05): there is no snowy night picture, so the snowy house
## stays up after dark, dimmed, with its windows lit by buildings/<house>_lit
## (make_window_glow.py) drawn additively. The tier-1 snowy picture sits 4 px higher.
const SNOW_NIGHT_TINT := Color(0.5, 0.52, 0.72)
const SNOW_LIT_DY := {"house": -4.0}

static var _meta: Dictionary = {}
static var _parts_tex: Dictionary = {}

var base := "house"  # day picture name (house, house_2, house_3)
var look_now: Dictionary = {}
var _host: Sprite2D
var _tex: Texture2D
var _kids: Array = []  # [node, day_px Vector2, size_px Vector2 (0 = native height)]
var _smoke: Array = []
var _map: Node
var _glow: Sprite2D


# --- data ---------------------------------------------------------------------

static func styles(part: String) -> Array:
	var out: Array = []
	for s: Dictionary in STYLES.get(part, []):
		var arc := str(s.get("arc", ""))
		if arc == "" or arc == _arc():
			out.append(s)
	return out


static func style(id: String) -> Dictionary:
	for part: String in STYLES:
		for s: Dictionary in STYLES[part]:
			if str(s["id"]) == id:
				return s
	return {}


static func part_of(id: String) -> String:
	for part: String in STYLES:
		for s: Dictionary in STYLES[part]:
			if str(s["id"]) == id:
				return part
	return ""


static func _arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func st() -> Dictionary:
	var d := Decor.st()
	if not (d.get("house", null) is Dictionary):
		d["house"] = {}
	if not (d.get("house_own", null) is Dictionary):
		d["house_own"] = {}
	return d


## The look to draw: the host's on a co-op visit, else this save's. Unknown or
## mismatched ids (renamed later) fall back to the painted original.
static func look() -> Dictionary:
	var raw: Variant = {}
	if GameState.visiting():
		raw = DecorMode.view().get("house", {})
	else:
		raw = st()["house"]
	return clean(raw if raw is Dictionary else {})


static func clean(raw: Dictionary) -> Dictionary:
	var out := {}
	for part: String in PARTS:
		var id := str(raw.get(part, ""))
		if id != "" and part_of(id) == part:
			out[part] = id
	return out


static func owns(id: String) -> bool:
	return bool(st()["house_own"].get(id, false))


## Buy (if needed) and put a style on the house. "" id = the original for that part.
## Returns "ok", "poor", "guest" or "bad".
static func choose(part: String, id: String) -> String:
	if GameState.visiting():
		return "guest"
	if not part in PARTS:
		return "bad"
	var d := st()
	if id == "":
		d["house"].erase(part)
		return "ok"
	var s := style(id)
	if s.is_empty() or part_of(id) != part or not (str(s.get("arc", "")) in ["", _arc()]):
		return "bad"
	if not owns(id):
		var price := int(s.get("price", 0))
		if int(GameState.run.get("crystals", 0)) < price:
			return "poor"
		GameState.run["crystals"] = int(GameState.run["crystals"]) - price
		d["house_own"][id] = true
		_first_note()
	d["house"][part] = id
	return "ok"


## The first restyle gets noticed (c10b_01-35): a friendly letter, once per save.
static func _first_note() -> void:
	var fl: Dictionary = GameState.run.get("flags", {})
	if bool(fl.get("ext_noticed", false)):
		return
	fl["ext_noticed"] = true
	if GameState.is_penguins():
		Mail.send("Hazel", "Saw your farmhouse from the road. A fresh look suits it! Folks in town have been asking who did the work. Come by if you ever want more ideas. - Hazel")
	else:
		Mail.send("Sal", "Drove past your place. New look, huh? Classy. Nobody's gonna mistake it for the old shack now. Keep it sharp. - Sal")


## Pen fence pieces [h, v, gate_open] for farm._plan_fences, or [] = the arc default
## (the gangster default is the chain-link set with its matching open gate).
static func fence_set() -> Array:
	var id := str(look().get("fence", ""))
	if id == "" and not GameState.is_penguins():
		id = "ext_fence_chain"  # gangster default: chain-link with its own gate (c10b_01-31)
	var f: Array = style(id).get("fence", [])
	for n: String in f:
		if not Art.has("props", n):
			return []
	return f


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(DIR + "parts.json"):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "parts.json"))
		if v is Dictionary:
			_meta = v
	return _meta


static func _load(name: String) -> Texture2D:
	var p := DIR + name + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


# --- applying -----------------------------------------------------------------

## Dress the farmhouse sprite for the current look (or `override`, the picker's
## preview). Safe to call again: the old dressing is replaced.
static func apply(map: Node, sprite: Sprite2D, override: Variant = null) -> HouseExterior:
	if sprite == null or not is_instance_valid(sprite):
		return null
	var old := sprite.get_node_or_null("HouseExterior")
	if old:
		sprite.remove_child(old)
		old.queue_free()
	var lk: Dictionary = clean(override) if override is Dictionary else look()
	var b := _base_name(map, sprite)
	var n := HouseExterior.new()
	n.name = "HouseExterior"
	n.base = b
	n.look_now = lk
	n._host = sprite
	n._map = map
	n.process_mode = Node.PROCESS_MODE_ALWAYS  # refit even under a pause (picker, dialogue)
	sprite.add_child(n)
	n._set_material()
	n._build()
	n._mailbox.call_deferred(map)  # the farm places the mailbox right after the house
	return n


## The farm's mailbox prop wears the chosen box (same height as buildings/mailbox,
## so it stands on the same spot); "Original" puts the painted one back.
func _mailbox(map: Node) -> void:
	if map == null or not is_inside_tree() or not is_instance_valid(map):
		return
	var orig := Art.tex("buildings", "mailbox")
	var want := orig
	var mk := str(look_now.get("mailbox", ""))
	if mk != "":
		var t := _load(str(style(mk).get("art", "")))
		if t:
			want = t
	var box: Sprite2D = map.get_meta("ext_mailbox") if map.has_meta("ext_mailbox") else null
	if box == null or not is_instance_valid(box):
		box = null
		for c: Node in map.find_children("*", "Sprite2D", true, false):
			if (c as Sprite2D).texture == orig:
				box = c
				break
		if box == null:
			return
		map.set_meta("ext_mailbox", box)
	if box.texture != want:
		box.texture = want


static func _base_name(map: Node, sprite: Sprite2D) -> String:
	if map and "_house_pics" in map and not (map._house_pics as Array).is_empty():
		var day := str(map._house_pics[0]).replace("_snow", "")
		if day in CHIMNEYS:
			return day
	var p := sprite.texture.resource_path.get_file().get_basename() if sprite.texture else "house"
	p = p.replace("_night", "").replace("_snow", "")
	return p if p in CHIMNEYS else "house"


func _set_material() -> void:
	var any := false
	for part: String in PART_ID:
		any = any or look_now.has(part)  # every siding style (ramp or wall) needs the material
	if not any:
		if _host.material is ShaderMaterial and (_host.material as ShaderMaterial).shader and (_host.material as ShaderMaterial).shader.resource_path.ends_with("house_palette.gdshader"):
			_host.material = null
			CrispArt.apply(_host)
		return
	var pt: Texture2D = _parts_tex.get(base, null)
	if pt == null:
		pt = _load(base + "_parts")
		_parts_tex[base] = pt
	if pt == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/house_palette.gdshader")
	mat.set_shader_parameter("parts", pt)
	mat.set_shader_parameter("crisp", CrispArt.on())
	var lum: Dictionary = meta().get("lum", {}).get(base, {})
	for part: String in PART_ID:
		var k := str(PART_ID[part])
		var id := str(look_now.get(part, ""))
		var ramp: Array = style(id).get("ramp", [])
		mat.set_shader_parameter("use" + k, ramp.size() == 5)
		if ramp.size() == 5:
			var cols := PackedVector3Array()
			for h: String in ramp:
				var c := Color(h)
				cols.append(Vector3(c.r, c.g, c.b))
			mat.set_shader_parameter("ramp" + k, cols)
		if part == "siding":
			var wt := _load(str(style(id).get("wall", "")))
			mat.set_shader_parameter("use_wall", wt != null)
			if wt:
				mat.set_shader_parameter("wall", wt)
				mat.set_shader_parameter("wall_px", float(wt.get_width()))
		var lr: Array = lum.get(k, [])
		if lr.size() == 2:
			mat.set_shader_parameter("lum" + k, Vector2(float(lr[0]), float(lr[1])))
	_host.material = mat  # one material per house (uniforms are per save), never CrispArt's shared one


func _build() -> void:
	var door: Array = meta().get("doors", {}).get(base, [])
	var dk := str(look_now.get("door", ""))
	if dk != "" and door.size() == 4:
		var t := _load(str(style(dk).get("art", "")))
		if t:
			_add(t, Vector2(float(door[0]), float(door[1])), Vector2(float(door[2] - door[0]), float(door[3] - door[1])))
	var sk := str(look_now.get("shutters", ""))
	if sk != "":
		var st3 := _load(str(style(sk).get("art", "")))
		if st3:
			# a shutter each side of every pane (pane boxes from the glass mask), framing
			# the glass so the night light still lands on it
			for pb: Array in meta().get("panes", {}).get(base, []):
				var ph := float(pb[3] - pb[1]) + 4.0
				var pw := ph * st3.get_width() / float(st3.get_height())
				_add(st3, Vector2(float(pb[0]) - 1.0 - pw, float(pb[1]) - 2.0), Vector2(pw, ph))
				_add(st3, Vector2(float(pb[2]) + 1.0, float(pb[1]) - 2.0), Vector2(pw, ph)).flip_h = true
	var pk := str(look_now.get("porch", ""))
	if pk != "" and door.size() == 4:
		var ps := style(pk)
		var t2 := _load(str(ps.get("art", "")))
		if t2:
			var h := float(ps.get("h", 20))
			var w := h * t2.get_width() / float(t2.get_height())
			var bottom := float(door[3]) + 13.0
			var cx := (float(door[0]) + float(door[2])) * 0.5
			if bool(ps.get("mat", false)):
				_add(t2, Vector2(cx - w * 0.5, bottom - h + 1.0), Vector2(w, h))
			else:
				var gap := (float(door[2]) - float(door[0])) * 0.5 + 10.0
				var one := _add(t2, Vector2(cx + gap, bottom - h), Vector2(w, h))
				if bool(ps.get("pair", false)):
					var s := _add(t2, Vector2(cx - gap - w, bottom - h), Vector2(w, h))
					s.flip_h = true
				if bool(ps.get("glow", false)):
					_lamp(one, Vector2(ps.get("glow_at", [0.5, 0.3])[0], ps.get("glow_at", [0.5, 0.3])[1]))
	_smoke_build()
	_refit()


func _add(t: Texture2D, day_px: Vector2, size_px: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	CrispArt.apply(s)
	add_child(s)
	_kids.append([s, day_px, size_px])
	return s


## A glowing porch piece lights up after dark through the map's NightGlow.
func _lamp(s: Sprite2D, at: Vector2) -> void:
	if _map == null or not ("glow" in _map) or not (_map.glow is NightGlow):
		return
	var mk := Node2D.new()
	mk.position = Vector2(s.texture.get_width() * at.x, s.texture.get_height() * at.y)
	s.add_child(mk)
	(_map.glow as NightGlow).lights.append([mk, 20.0, 0.0])


func _smoke_build() -> void:
	if not Art.has("fx", "chimney_smoke") or Settings.reduced_motion():
		return
	var t := Art.tex("fx", "chimney_smoke")
	if t == null:
		return
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 5.0)
	var fw := t.get_width() / 4
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(i * fw, 0, fw, t.get_height())
		sf.add_frame("default", at)
	for c: Vector2 in CHIMNEYS.get(base, []):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = sf
		a.centered = false
		a.modulate = Color(1, 1, 1, 0.75)
		a.play("default")
		a.frame = randi() % 4
		add_child(a)
		_smoke.append([a, c])
	_smoke_show()


static func smoke_due() -> bool:
	var se := GameState.look_se()
	if se == "winter" or se == "fall":
		return true
	var h := int(GameState.run.get("time", 360)) / 60 % 24
	return h < 9 or h >= 17


func _smoke_show() -> void:
	var on := smoke_due()
	for e: Array in _smoke:
		(e[0] as CanvasItem).visible = on


## Place children in the current picture's texel space (the night pictures are
## a few px narrower than the day one; farm._fit_house_pic rescales the sprite).
func _refit() -> void:
	if _host == null or _host.texture == null:
		return
	_winter_night()
	_tex = _host.texture
	_drop_from_glow()
	var day: Texture2D = Art.tex("buildings", base)
	var dw := float(day.get_width()) if day else float(_tex.get_width())
	var dh := float(day.get_height()) if day else float(_tex.get_height())
	var kx := float(_tex.get_width()) / dw
	var ky := float(_tex.get_height()) / dh
	var origin := _host.offset - (Vector2(_tex.get_width(), _tex.get_height()) * 0.5 if _host.centered else Vector2.ZERO)
	for e: Array in _kids:
		var s: Sprite2D = e[0]
		var p: Vector2 = e[1]
		var sz: Vector2 = e[2]
		s.position = origin + Vector2(p.x * kx, p.y * ky)
		s.scale = Vector2(sz.x * kx / s.texture.get_width(), sz.y * ky / s.texture.get_height())
	for e: Array in _smoke:
		var a: AnimatedSprite2D = e[0]
		var c: Vector2 = e[1]
		var fw := 40.0
		a.scale = Vector2(0.6, 0.6)
		a.position = origin + Vector2(c.x * kx - fw * 0.3 + 6.0, c.y * ky - 24.0 * 0.6 - 1.0)
	var night := _tex.resource_path.contains("_night") or (_host.self_modulate != Color.WHITE)
	for e: Array in _kids:
		(e[0] as CanvasItem).modulate = NIGHT_TINT if night else Color.WHITE


var _t := 1.9  # first tick soon after the map's NightGlow registers its windows


func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if _host.texture != _tex:
		_refit()
	_t += delta
	if _t > 2.0:
		_t = 0.0
		_smoke_show()
		_drop_from_glow()
		if _host.texture != null and GameState.is_night() != (_host.self_modulate != Color.WHITE) and _host.texture.resource_path.contains("_snow"):
			_refit()  # dusk/dawn on the snowy picture


## The farmhouse's window light is the painted _night picture (or the snowy glow
## below): NightGlow's day-registered house_lit would stack on it (c10b_01-12).
func _drop_from_glow() -> void:
	if _map and "glow" in _map and _map.glow is NightGlow:
		var nl: NightGlow = _map.glow
		nl.windows = nl.windows.filter(func(w: Array) -> bool: return w[0] != _host)


## Swap the plain night picture for the snowy one in winter (dimmed, windows lit).
func _winter_night() -> void:
	var path := _host.texture.resource_path
	var snow := base + "_snow"
	if path.ends_with("/" + base + "_night.png") and GameState.look_se() == "winter" and Art.has("buildings", snow):
		_host.texture = Art.tex("buildings", snow)
		if _map and _map.has_method("_fit_house_pic"):
			_map.call("_fit_house_pic")
		path = _host.texture.resource_path
	var snowy_night := path.ends_with("/" + snow + ".png") and GameState.is_night()
	_host.self_modulate = SNOW_NIGHT_TINT if snowy_night else Color.WHITE
	if snowy_night and _glow == null and Art.has("buildings", base + "_lit"):
		_glow = Sprite2D.new()
		_glow.texture = Art.tex("buildings", base + "_lit")
		_glow.centered = false
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = cm
		_glow.modulate = Color(2.6, 2.3, 1.8)  # the map's night CanvasModulate dims it again
		add_child(_glow)
		move_child(_glow, 0)
	if _glow:
		_glow.visible = snowy_night
		var t := _host.texture
		_glow.position = _host.offset - (Vector2(t.get_width(), t.get_height()) * 0.5 if _host.centered else Vector2.ZERO) + Vector2(0, float(SNOW_LIT_DY.get(base, 0.0)))


# --- picker -------------------------------------------------------------------

static func menu_word() -> String:
	return "Restyle the farmhouse"


static func open(map: Node) -> Node:
	if GameState.visiting():
		if map and "hud" in map and map.hud:
			map.hud.toast("Only the host restyles this house.")
		return null
	var p := load("res://scripts/house_style_screen.gd").new() as Node
	p.set("map", map)
	map.add_child(p)
	return p
