class_name Wardrobe
extends RefCounted
## Cosmetic wardrobe (CONDUCT 10a P5). Pieces are Decor wear entries (data/wardrobe.json
## from tools/gen_wardrobe.py, merged into decor.json by P1's gen_decor.py; register()
## adds any missing ones at runtime). What you wear lives in run.decor.wear (Decor.wear),
## owned pieces in run.decor.box: a worn piece leaves the box and goes back when taken
## off, so it can't be sold or gifted while worn. Starter pieces (everyday clothes of
## your arc) are always in the wardrobe, like hair. Cosmetics never carry stats: gear
## stats come only from GameState.SLOTS.
## Render contract (entry "renders"): "doll" = PaperDoll layers on the build-your-own
## hero; "penguin" = pinned accessory on the penguin heroes (Pip-Pip, Nova); drawn heroes
## (hero_kind "pin") wear the doll hats and face pieces as pins (dress_hero, HEAD table);
## outfits stay doll-only and "icon" pieces are collection pieces (badge on the Hero tab).
## Look toggle: run.look.show_armor (false = cosmetics win over worn armour/helm).

static var _data: Dictionary = {}
const SLOT_NAMES := {"hat": "Hat", "outfit": "Outfit", "acc": "Accessory", "top": "Top", "bottom": "Bottom", "shoes": "Shoes", "more": "Clothes"}
## Wardrobe tabs: outfit/hat/acc have drawn layers; "more" lists tops, bottoms and shoes
## (collection pieces, not drawn yet; WardrobeScreen._slots maps tabs to slots).
const SHOWN_SLOTS := ["outfit", "hat", "acc", "more"]
## Where a penguin accessory sits on each penguin hero, as fractions of the frame's
## opaque height measured up from the feet (neck = scarf/bowtie line, face = eyes),
## and its width as a share of the body's opaque width. Hats stay off: both heroes
## wear their own crown / wizard hat.
const PENGUIN_ANCHOR := {
	"penguin_king": {"neck": 0.42, "face": 0.62, "w": 0.78},
	"penguin_wizard": {"neck": 0.40, "face": 0.55, "w": 0.78},
	"penguin": {"neck": 0.50, "face": 0.70, "w": 0.80}}
## Piece width as a share of the anchor width; neck pieces hang from their top edge
## (the loop sits on the neck line), face pieces are centred on the eye line.
const PIECE_W := {"pg_scarf": 0.6, "pg_bowtie": 0.36, "pg_goggles": 0.78}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/wardrobe.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
		for k in ["items", "sets"]:
			if not _data.has(k):
				_data[k] = {}
	return _data


## Files the wardrobe's render contract into Decor once per data load (c10b_11-20):
## wardrobe.json pieces overlay P1's entries (renders/doll/penguin/slot/starter; name,
## price and sources stay P1's); wardrobe-only pieces are added with their own sources
## and loot-pool rows; decor wear entries the wardrobe doesn't list get a contract derived
## from their art (c10b_11-01); the wardrobe sets join Decor's sets (c10b_11-14).
static var _reg_items: Dictionary = {}


static func register(force := false) -> void:
	var dd := Decor.data()
	var items: Dictionary = dd["items"]
	if not force and is_same(_reg_items, items) and not items.is_empty():
		return
	_reg_items = items
	for id: String in data()["items"]:
		var w: Dictionary = data()["items"][id]
		if not items.has(id):
			var e2 := w.duplicate(true)
			e2.erase("pools")
			items[id] = e2
			for row in w.get("pools", []):
				var pool: Variant = (dd["pools"] as Dictionary).get(str(row[0]), null)
				if pool is Array and not (pool as Array).any(func(r: Variant) -> bool: return r is Array and str(r[0]) == id):
					(pool as Array).append([id, row[1]])
		else:
			var e: Dictionary = items[id]
			for k in ["renders", "doll", "penguin", "slot", "starter", "starter_arc"]:
				if w.has(k):
					e[k] = w[k]
			if not e.has("desc") and w.has("desc"):
				e["desc"] = w["desc"]
	for id: String in items:
		var e3: Dictionary = items[id]
		if str(e3.get("layer", "")) == "wear" and not data()["items"].has(id) and not e3.has("doll"):
			e3["doll"] = _derive_doll(e3)
	for sid: String in data()["sets"]:
		var st: Dictionary = data()["sets"][sid]
		if st.has("pieces") and not (dd["sets"] as Dictionary).has("wear_" + sid):
			dd["sets"]["wear_" + sid] = {"name": st.get("name", sid), "arc": st.get("arc", ""), "pieces": st["pieces"], "reward": st.get("reward", {}), "comfort": 0, "wardrobe": true}


## Doll contract from a decor wear entry's art: outfits -> their costume sheet, hats ->
## hats/ or hats_poses/ sheets, face pieces (acc) -> hats_poses sheets. {} = icon only.
static func _derive_doll(e: Dictionary) -> Dictionary:
	if not str(e.get("renders", "")).contains("doll"):
		return {}
	var cat := str(e.get("cat", ""))
	var art := str(e.get("art", ""))
	if cat == "outfit":
		var cs := str(e.get("costume", ""))
		return {"body": cs} if cs != "" else {}
	if art.begins_with("hats/") or art.begins_with("hats_poses/"):
		return {"hat": art} if cat == "hat" else {"face": art}
	return {}


## Old C10a ids (wr_pinstripe_suit, wr_hat_beanie...) -> decor.json ids, in saves.
static func alias(id: String) -> String:
	return str((data().get("alias", {}) as Dictionary).get(id, id))


static var _mig_st: Dictionary = {}


## Moves worn/boxed/seen pieces of a run from old ids to the current ones (once per run).
static func migrate() -> void:
	if GameState.run.is_empty() or not (GameState.run.get("decor", null) is Dictionary):
		return
	var st: Dictionary = GameState.run["decor"]
	if is_same(_mig_st, st):
		return
	_mig_st = st
	var al: Dictionary = data().get("alias", {})
	if al.is_empty():
		return
	var wear: Dictionary = st.get("wear", {})
	for slot: String in wear.keys():
		wear[slot] = al.get(str(wear[slot]), wear[slot])
	for k: String in ["box", "got"]:
		var d: Variant = st.get(k, null)
		if not (d is Dictionary):
			continue
		for old: String in (d as Dictionary).keys():
			if al.has(old):
				var nw := str(al[old])
				var v: Variant = d[old]
				d.erase(old)
				if v is int or v is float:
					d[nw] = int(d.get(nw, 0)) + int(v)
				elif not d.has(nw):
					d[nw] = v


static func entry(id: String) -> Dictionary:
	register()
	return Decor.entry(alias(id))


static func is_wear(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and (str(e.get("layer", "")) == "wear" or str(e.get("cat", "")) in Decor.WEAR_SLOTS)


static func slot_of(id: String) -> String:
	var e := entry(id)
	var s := str(e.get("slot", e.get("cat", "")))
	return s if s in Decor.WEAR_SLOTS else ""


## Arc being built on the title screen's creator (no run yet, or another run loaded): "" = the run's.
static var arc_override := ""


static func arc() -> String:
	if arc_override != "":
		return arc_override
	return "penguins" if GameState.is_penguins() else "gangsters"


static func in_arc(id: String) -> bool:
	var a := str(entry(id).get("arc", ""))
	return a == "" or a == arc()


## Free everyday piece of your arc (starter_arc: the Red Scarf is free for penguins only, c10b_11-09).
static func is_starter(id: String) -> bool:
	var e := entry(id)
	var sa := str(e.get("starter_arc", ""))
	return bool(e.get("starter", false)) and in_arc(id) and (sa == "" or sa == arc())


static func owns(id: String) -> bool:
	return is_starter(id) or Decor.owned(id) > 0 or worn_id(slot_of(id)) == id


## Every piece of a slot you can put on now (owned or starter, your arc), sorted by rarity then name.
static func choices(slot: String) -> Array:
	register()
	var out: Array = []
	for id: String in Decor.data()["items"]:
		if slot_of(id) == slot and in_arc(id) and owns(id):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ra := Decor.rarity_rank(Decor.rarity(a))
		var rb := Decor.rarity_rank(Decor.rarity(b))
		return ra < rb if ra != rb else str(entry(a).get("name", a)) < str(entry(b).get("name", b)))
	return out


static func worn_id(slot: String) -> String:
	if slot == "" or GameState.run.is_empty() or not (GameState.run.get("decor", null) is Dictionary):
		return ""  # title screen / no run yet: never create run.decor from a read
	migrate()
	return Decor.worn(slot)


## Put a piece on (its slot's old piece goes back to the box). False if you don't own it.
static func put_on(id: String) -> bool:
	var slot := slot_of(id)
	if slot == "" or not owns(id) or not in_arc(id):
		return false
	if worn_id(slot) == id:
		return true
	# Wardrobe owns the box moves itself (Decor.wear would take a second copy and can't wear starters).
	if not is_starter(id) and not Decor.take(id, 1):
		return false
	take_off(slot)
	if slot == "outfit":
		take_off("top")
		take_off("bottom")
	Decor.st()["wear"][slot] = id
	return true


static func take_off(slot: String) -> void:
	var cur := worn_id(slot)
	if cur == "":
		return
	(Decor.st()["wear"] as Dictionary).erase(slot)
	if not is_starter(cur) and is_wear(cur):
		var box: Dictionary = Decor.st()["box"]
		box[cur] = int(box.get(cur, 0)) + 1  # straight back (Decor.give refuses a unique you "own")


static func show_armor() -> bool:
	return bool(GameState.run.get("look", {}).get("show_armor", false))


static func set_show_armor(on: bool) -> void:
	if not (GameState.run.get("look", null) is Dictionary):
		GameState.run["look"] = {}
	GameState.run["look"]["show_armor"] = on


## Hero kind for the render contract: "doll" (build-your-own), "penguin", or "" (drawn hero).
static func hero_kind(pid := "") -> String:
	if pid == "":
		pid = str(GameState.run.get("playable", ""))
	var pd: Dictionary = GameState.playables.get(pid, {})
	if bool(pd.get("custom", false)):
		return "doll"
	var spr := str(pd.get("sprite", ""))
	if PaperDoll.is_penguin(spr):
		return "penguin"
	return PIN_KIND if spr != "" else ""  # drawn heroes wear hats and face pieces as pins (c10b_11-06)


static func shows_on(id: String, pid := "") -> bool:
	var r := str(entry(id).get("renders", ""))
	var k := hero_kind(pid)
	if k == PIN_KIND:
		var d: Dictionary = entry(id).get("doll", {})
		return (r.contains("doll") or r.contains("pin")) and (d.has("hat") or d.has("face") or d.has("back"))
	if k == "" or not r.contains(k):
		return false
	return not hidden_by_helmet(id, pid)


## Hat/face doll pieces vanish under an outfit or armour with a helmet painted in (c10b_11-07).
static func hidden_by_helmet(id: String, pid := "") -> bool:
	if hero_kind(pid) != "doll" or slot_of(id) == "outfit" or GameState.run.is_empty():
		return false
	var d: Dictionary = entry(id).get("doll", {})
	if not (d.has("hat") or d.has("face")):
		return false
	return PaperDoll.has_headgear(PaperDoll.body_for(GameState.run.get("look", {})))


## Honest line for the wardrobe/shop card.
static func shows_label(id: String) -> String:
	var r := str(entry(id).get("renders", ""))
	if r == "" or r == "icon":
		return "Not drawn on any hero yet (a collection piece)."
	if shows_on(id):
		return "Shows on your hero."
	if hidden_by_helmet(id):
		return "Hidden under your helmet."
	var who := "the build-your-own hero"
	if hero_kind() == PIN_KIND and slot_of(id) == "outfit":
		who = "the build-your-own hero (outfits are drawn into your hero)"
	elif r == "penguin":
		who = "the penguin heroes"
	elif r.contains("penguin") and arc() == "penguins":
		who = "the build-your-own and penguin heroes"
	return "Only shows on " + who + "."


## Body sheet of the worn cosmetic outfit, or "" (PaperDoll.body_for reads it).
static func outfit_body() -> String:
	var id := worn_id("outfit")
	if id == "":
		return ""
	var b := str((entry(id).get("doll", {}) as Dictionary).get("body", ""))
	return b if Art.has("body", b) else ""


## [group, name] of a worn doll layer ("hat" or "face"), or [].
static func doll_layer(kind: String) -> Array:
	for slot: String in (["hat"] if kind == "hat" else ["acc", "hat"]):
		var id := worn_id(slot)
		if id == "":
			continue
		var gn := str((entry(id).get("doll", {}) as Dictionary).get(kind, ""))
		var i := gn.rfind("/")
		if i > 0 and Art.has(gn.left(i), gn.substr(i + 1)):
			return [gn.left(i), gn.substr(i + 1)]
	return []


## Colourway hex of the worn hat ("" = as drawn); only while the cosmetic hat is what shows.
static func doll_tint(slot: String) -> String:
	var id := worn_id(slot)
	if id == "":
		return ""
	# Mirrors PaperDoll.hat_layer: tinted only while the cosmetic is the layer it picked (c10b_11-08).
	if slot == "hat" and PaperDoll.hat_layer(GameState.run.get("look", {})) != doll_layer("hat"):
		return ""
	return str((entry(id).get("doll", {}) as Dictionary).get("tint", ""))


## Gear you own whose costume matches a wardrobe outfit unlocks that look (kept even
## after you sell the gear). Returns the ids newly unlocked.
static func sync_unlocks() -> Array:
	register()
	var have: Array = []
	for slot in GameState.SLOTS:
		have.append(GameState.equipped(slot))
	for iid: String in GameState.run.get("inventory", {}):
		have.append(iid)
	for key: String in (GameState.run.get("chests", {}) as Dictionary):  # gear stored in chests too (c10b_11-31)
		var ch: Variant = GameState.run["chests"][key]
		if ch is Dictionary:
			have.append_array(((ch as Dictionary).get("items", {}) as Dictionary).keys())
	var got: Array = []
	for iid in have:
		var wid := unlock_for_item(str(iid), false)
		if wid != "":
			got.append(wid)
	return got


## The wardrobe look matching a gear item's costume, unlocked once ("" = none / already).
## GameState.add_item calls this for costume gear, so the look arrives the moment you get it.
static func unlock_for_item(iid: String, toast := true) -> String:
	var cs := str(GameState.items.get(iid, {}).get("costume", ""))
	if cs == "" or GameState.run.is_empty():
		return ""
	register()
	var wid := ""
	for id: String in data()["items"]:
		if str((data()["items"][id].get("doll", {}) as Dictionary).get("body", "")) == cs:
			wid = id
			break
	if wid == "" or is_starter(wid) or not in_arc(wid) or (Decor.st()["got"] as Dictionary).has(wid):
		return ""
	Decor.give(wid, 1, "gear")
	if toast:
		GameMap.notify("New look in your wardrobe: %s" % str(entry(wid).get("name", wid)))
	return wid


## Penguin heroes: accessory pieces pinned at PENGUIN_ANCHOR, following the sprite.
static func dress_penguin_hero(parent: Node2D, anim: AnimatedSprite2D, sprite: String, mat: Material = null) -> void:
	dress_hero(parent, anim, sprite, mat)


## Animations where a pin has no sensible spot (mounted, swimming, lying down): pins hide (c10b_11-16/17).
const PIN_HIDE := ["ride", "ride_down", "ride_up", "ride_run", "swim", "swim_down", "swim_up", "float", "faint", "sleep", "sleep_bed", "dive", "climb_out"]
## Animations whose frames carry effects/props (swing arcs, sparkles, wands): pins follow the
## facing's idle body box instead of the frame's opaque box (c10b_11-16).
const PIN_REF := ["attack", "attack_down", "attack_up", "powerup", "burst", "cast_right", "celebrate", "cheer", "sit", "ability",
	"hoe_down", "hoe_right", "hoe_up", "axe_down", "axe_right", "axe_up", "pickaxe_down", "pickaxe_right", "pickaxe_up", "water_down", "water_right", "water_up", "reel_right", "eat_down", "wave", "hold_down"]
## Drawn heroes ("pin" kind): head box as shares of the idle body box (top share of the
## height that is head, head width share). Hats sit on the hair, face pieces on the eyes.
const HEAD := {"default": {"h": 0.42, "w": 0.78}, "big_jim": {"h": 0.34, "w": 0.6}, "man": {"h": 0.36, "w": 0.7}, "woman": {"h": 0.38, "w": 0.7}}
const PIN_KIND := "pin"


## Wardrobe pieces pinned on a drawn sprite: penguin heroes get neck/face pieces, drawn
## heroes hats and face pieces (3-view hats/hats_poses art). Pins follow the body box of
## each frame, use the facing's idle box on effect-heavy frames and hide where no spot fits.
static func dress_hero(parent: Node2D, anim: AnimatedSprite2D, sprite: String, mat: Material = null) -> void:
	for ch in parent.get_children():
		if ch.name.begins_with("PenguinAcc") or ch.name.begins_with("HeroPins") or ch.name.begins_with("HeroBack"):
			ch.name = "OldAcc%d" % ch.get_instance_id()  # free the name for the new holder
			ch.queue_free()
	var penguin := PaperDoll.is_penguin(sprite)
	var doll := sprite == "doll"  # build-your-own hero: only back pieces pin (hats/face are PaperDoll layers)
	var pieces: Array = []
	var backs: Array = []
	for slot: String in ["acc", "hat"]:
		var id := worn_id(slot)
		if id == "" or not shows_on(id):
			continue
		var bd: Dictionary = entry(id).get("penguin" if penguin else "doll", {})
		if bd.has("back"):
			backs.append([str(bd["back"]), str(bd.get("tint", ""))])
			continue
		if doll:
			continue
		if penguin:
			var pg: Dictionary = entry(id).get("penguin", {})
			for kind: String in ["neck", "face"]:
				if pg.has(kind):
					pieces.append([kind, str(pg[kind]), Color(str(pg.get("tint", "ffffff")))])
		else:
			var dl: Dictionary = entry(id).get("doll", {})
			for kind2: String in ["hat", "face"]:
				if dl.has(kind2):
					pieces.append([kind2, str(dl[kind2]), Color(str(dl.get("tint", "ffffff"))) if dl.has("tint") else Color.WHITE])
	var anc: Dictionary = PENGUIN_ANCHOR.get(sprite, PENGUIN_ANCHOR["penguin"])
	var head: Dictionary = HEAD.get(sprite, HEAD["default"])
	if not backs.is_empty():
		_dress_back(parent, anim, backs[0], penguin, anc, head)
	if pieces.is_empty():
		return
	var holder := Node2D.new()
	holder.name = "PenguinAcc" if penguin else "HeroPins"
	holder.z_index = 1
	parent.add_child(holder)
	var nodes: Array = []
	for p in pieces:
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.self_modulate = p[2]
		if mat != null:
			s.material = mat  # hit flash follows the body
		holder.add_child(s)
		nodes.append([s, p])
	var upd := func() -> void:
		if not is_instance_valid(holder) or not is_instance_valid(anim) or anim.sprite_frames == null:
			return
		var an := str(anim.animation)
		var tex := anim.sprite_frames.get_frame_texture(an, anim.frame)
		if tex == null:
			return
		holder.position = anim.position
		holder.modulate = anim.modulate
		holder.visible = anim.visible and not an in PIN_HIDE
		if not holder.visible:
			return
		var view := view_of(an)
		var bb := frame_box(tex)
		var rt := tex
		if an in PIN_REF:
			var ref := ref_anim(anim.sprite_frames, view)
			if ref != "":
				rt = anim.sprite_frames.get_frame_texture(ref, 0)
				var rb := frame_box(rt)
				# Keep the reference box's height and width, standing on this frame's feet.
				bb = [rb[0], float(tex.get_height()) - (rt.get_height() - rb[1]), float(tex.get_height()) - (rt.get_height() - rb[2]), rb[3]]
		var sc := anim.scale.x
		var flip := anim.flip_h
		for n in nodes:
			var s: Sprite2D = n[0]
			var kind: String = n[1][0]
			var gn: String = n[1][1]
			if penguin:
				_pin_penguin(s, kind, gn, view, bb, anc, tex, sc, flip)
			else:
				_pin_drawn(s, kind, gn, view, bb, head, tex, sc, flip)
	anim.frame_changed.connect(upd)
	anim.animation_changed.connect(upd)
	upd.call()


## A cape/cloak (back layer): behind the body on front/side frames, over it on back
## frames; hangs from the neck line to just above the feet; colour by luma recolour.
static func _dress_back(parent: Node2D, anim: AnimatedSprite2D, piece: Array, penguin: bool, anc: Dictionary, head: Dictionary) -> void:
	var gn := str(piece[0])
	var i := gn.rfind("/")
	var g := gn.left(i)
	var base := gn.substr(i + 1)
	if i <= 0 or not Art.has(g, base + "_back"):
		return
	var holder := Node2D.new()
	holder.name = "HeroBack"
	parent.add_child(holder)
	var s := Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if str(piece[1]) != "":
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/hair_tint.gdshader")
		m.set_shader_parameter("tint", Color(str(piece[1])))
		m.set_shader_parameter("on", true)
		s.material = m
	holder.add_child(s)
	var upd := func() -> void:
		if not is_instance_valid(holder) or not is_instance_valid(anim) or anim.sprite_frames == null:
			return
		var an := str(anim.animation)
		var tex := anim.sprite_frames.get_frame_texture(an, anim.frame)
		if tex == null:
			return
		holder.position = anim.position
		holder.modulate = anim.modulate
		holder.visible = anim.visible and not an in PIN_HIDE
		if not holder.visible:
			return
		var view := view_of(an)
		var bb := frame_box(tex)
		if an in PIN_REF:
			var ref := ref_anim(anim.sprite_frames, view)
			if ref != "":
				var rt := anim.sprite_frames.get_frame_texture(ref, 0)
				var rb := frame_box(rt)
				bb = [rb[0], float(tex.get_height()) - (rt.get_height() - rb[1]), float(tex.get_height()) - (rt.get_height() - rb[2]), rb[3]]
		# Draw order: before the body (behind) unless we see the hero's back.
		if anim.get_parent() == holder.get_parent():
			var want := anim.get_index() + (1 if view == "back" else 0)
			var cur := holder.get_index()
			if (view == "back" and cur < anim.get_index()) or (view != "back" and cur > anim.get_index()):
				holder.get_parent().move_child(holder, want if view == "back" else anim.get_index())
		holder.z_index = 1 if view == "back" else 0
		var t := Art.tex(g, base + ("_side" if view == "side" else "_back"))
		s.texture = t
		var body_h: float = bb[2] - bb[1]
		var top: float = (bb[2] - body_h * float(anc["neck"])) if penguin else (bb[1] + body_h * float(head["h"]) * 0.9)
		var bottom: float = bb[2] - body_h * 0.05
		var k := maxf(4.0, bottom - top) / float(t.get_height())
		k = minf(k, bb[3] * (0.95 if view == "side" else 1.1) / float(t.get_width()))
		var sc := anim.scale.x
		s.scale = Vector2(k, k) * sc
		var flip := anim.flip_h
		s.flip_h = flip if view == "side" else false
		var cx: float = bb[0] - tex.get_width() / 2.0 - (bb[3] * 0.18 if view == "side" else 0.0)
		s.offset = Vector2(0, t.get_height() / 2.0)  # hang from the collar
		s.position = Vector2(cx * sc * (-1.0 if flip else 1.0), (top - tex.get_height()) * sc)
	anim.frame_changed.connect(upd)
	anim.animation_changed.connect(upd)
	upd.call()


## The facing's steady reference animation (idle body) in a sprite's frames, or "".
static func ref_anim(sf: SpriteFrames, view: String) -> String:
	var want: Array = {"front": ["idle", "idle_down", "walk_down"], "back": ["idle_up", "walk_up"], "side": ["idle_side", "walk"]}.get(view, ["idle"])
	for a: String in want:
		if sf.has_animation(a) and sf.get_frame_count(a) > 0:
			return a
	return ""


static func _pin_penguin(s: Sprite2D, kind: String, gn: String, view: String, bb: Array, anc: Dictionary, tex: Texture2D, sc: float, flip: bool) -> void:
	var i := gn.rfind("/")
	var g := gn.left(i)
	var base := gn.substr(i + 1)
	var v := view
	if not Art.has(g, "%s_%s" % [base, v]):
		v = "front" if v != "back" else ""
	if v == "" or (kind == "neck" and base == "pg_bowtie" and view == "back"):
		s.visible = false
		return
	var t := Art.tex(g, "%s_%s" % [base, v])
	s.texture = t
	s.region_enabled = false
	s.visible = true
	var want_w: float = bb[3] * float(anc["w"]) * float(PIECE_W.get(base, 1.0)) * (0.8 if v == "side" else 1.0)
	var k := want_w / maxf(1.0, float(t.get_width()))
	s.scale = Vector2(k, k) * sc
	var fy: float = bb[2] - (bb[2] - bb[1]) * float(anc[kind])
	var fx: float = bb[0] + (bb[3] * 0.12 if v == "side" else 0.0)  # side frames face right
	s.flip_h = (not flip) if v == "side" else false  # side pieces are drawn facing left
	s.offset = Vector2(0, t.get_height() * 0.5 - 2.0) if kind == "neck" and base != "pg_bowtie" else Vector2.ZERO
	s.position = Vector2((fx - tex.get_width() / 2.0) * sc * (-1.0 if flip else 1.0), (fy - tex.get_height()) * sc)


## A hat/face sheet (cells 0 front, 1 back, 2 side) pinned on a drawn hero's head box.
static func _pin_drawn(s: Sprite2D, kind: String, gn: String, view: String, bb: Array, head: Dictionary, tex: Texture2D, sc: float, flip: bool) -> void:
	var i := gn.rfind("/")
	var g := gn.left(i)
	var nm := gn.substr(i + 1)
	if i <= 0 or not Art.has(g, nm) or (kind == "face" and view == "back"):
		s.visible = false
		return
	var lf: int = {"front": 0, "back": 1, "side": 2}.get(view, 0)
	var info := Art.info(g, nm)
	var cw := int(info.get("cell_w", 96))
	var ch := int(info.get("cell_h", 96))
	s.texture = Art.tex(g, nm)
	s.region_enabled = true
	s.region_rect = Rect2(lf * cw, 0, cw, ch)
	s.visible = true
	s.flip_h = flip
	var l := PaperDoll.anchor_of(g, nm, lf)
	var body_h: float = bb[2] - bb[1]
	var head_h: float = body_h * float(head["h"])
	var head_w: float = minf(bb[3], body_h * 0.6) * float(head["w"])
	var want_w: float = head_w * (1.2 if kind == "hat" else 0.9)
	var k := want_w / maxf(1.0, float(l[3]))
	s.scale = Vector2(k, k) * sc
	var target_y: float = bb[1] + (head_h * 0.32 if kind == "hat" else head_h * 0.6)
	var lcx := float(l[0]) - cw / 2.0
	var lby := float(l[2]) - ch / 2.0
	if kind == "face":
		lby = (float(l[1]) + float(l[2])) / 2.0 - ch / 2.0
	var cx: float = bb[0] - tex.get_width() / 2.0
	s.position = Vector2(cx * sc * (-1.0 if flip else 1.0) - lcx * k * sc * (-1.0 if flip else 1.0), (target_y - tex.get_height()) * sc - lby * k * sc)


static var _box_cache: Dictionary = {}


## Opaque box of a frame texture in its own px: [cx, top, bottom, w].
static func frame_box(tex: Texture2D) -> Array:
	var key := tex.get_instance_id()
	if _box_cache.has(key):
		return _box_cache[key]
	var out := [tex.get_width() / 2.0, 0.0, float(tex.get_height()), float(tex.get_width())]
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r := img.get_used_rect()
		if r.size.x > 0:
			out = [r.position.x + r.size.x / 2.0, float(r.position.y), float(r.end.y), float(r.size.x)]
	if _box_cache.size() > 512:
		_box_cache.clear()
	_box_cache[key] = out
	return out


## Facing of a hero animation for 3-view pieces.
static func view_of(an: String) -> String:
	if an.ends_with("_up") or an == "view_back" or an == "idle_up":
		return "back"
	if an.ends_with("_down") or an in ["idle", "view_front", "idle_down", "hurt", "faint", "celebrate", "cheer", "powerup", "burst", "sit", "sleep", "sleep_bed", "wave", "float", "ability", "eat_down"]:
		return "front"
	return "side"
