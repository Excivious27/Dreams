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
## hero; "penguin" = pinned accessory on the penguin heroes (Pip-Pip, Nova) and the plain
## penguin. Everyone else shows nothing, and the wardrobe says so (shows_label).
## Look toggle: run.look.show_armor (false = cosmetics win over worn armour/helm).

static var _data: Dictionary = {}
const SLOT_NAMES := {"hat": "Hat", "outfit": "Outfit", "acc": "Accessory", "top": "Top", "bottom": "Bottom", "shoes": "Shoes"}
## Slots with art today (top/bottom/shoes come as whole outfits; no layered art yet).
const SHOWN_SLOTS := ["outfit", "hat", "acc"]
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


## Add wardrobe pieces decor.json lacks (P1's entries win, our render fields fill gaps).
static func register() -> void:
	var items: Dictionary = Decor.data()["items"]
	for id: String in data()["items"]:
		var w: Dictionary = data()["items"][id]
		if not items.has(id):
			items[id] = w.duplicate(true)
		else:
			var e: Dictionary = items[id]
			for k in ["renders", "doll", "penguin", "slot", "starter", "desc"]:
				if not e.has(k) and w.has(k):
					e[k] = w[k]


static func entry(id: String) -> Dictionary:
	register()
	return Decor.entry(id)


static func is_wear(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and (str(e.get("layer", "")) == "wear" or str(e.get("cat", "")) in Decor.WEAR_SLOTS)


static func slot_of(id: String) -> String:
	var e := entry(id)
	var s := str(e.get("slot", e.get("cat", "")))
	return s if s in Decor.WEAR_SLOTS else ""


static func arc() -> String:
	return "penguins" if GameState.is_penguins() else "gangsters"


static func in_arc(id: String) -> bool:
	var a := str(entry(id).get("arc", ""))
	return a == "" or a == arc()


static func is_starter(id: String) -> bool:
	return bool(entry(id).get("starter", false)) and in_arc(id)


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
	if slot == "":
		return ""
	return Decor.worn(slot)


## Put a piece on (its slot's old piece goes back to the box). False if you don't own it.
static func put_on(id: String) -> bool:
	var slot := slot_of(id)
	if slot == "" or not owns(id) or not in_arc(id):
		return false
	if worn_id(slot) == id:
		return true
	if not is_starter(id) and Decor.owned(id) > 0:
		Decor.take(id, 1)
	take_off(slot)
	Decor.wear(slot, id)
	if slot == "outfit":
		Decor.wear("top", "")
		Decor.wear("bottom", "")
	return true


static func take_off(slot: String) -> void:
	var cur := worn_id(slot)
	if cur == "":
		return
	Decor.wear(slot, "")
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
	return ""


static func shows_on(id: String, pid := "") -> bool:
	var r := str(entry(id).get("renders", ""))
	var k := hero_kind(pid)
	return k != "" and r.contains(k)


## Honest line for the wardrobe/shop card.
static func shows_label(id: String) -> String:
	var r := str(entry(id).get("renders", ""))
	var on := shows_on(id)
	var who := "the build-your-own hero" if r == "doll" else ("the penguin heroes" if r == "penguin" else "nobody yet")
	return ("Shows on your hero" if on else "Only shows on " + who) + "."


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


## Gear you own whose costume matches a wardrobe outfit unlocks that look (kept even
## after you sell the gear). Returns the ids newly unlocked.
static func sync_unlocks() -> Array:
	register()
	var got: Array = []
	var by_body := {}
	for id: String in data()["items"]:
		var b := str((data()["items"][id].get("doll", {}) as Dictionary).get("body", ""))
		if b != "":
			by_body[b] = id
	var have: Array = []
	for slot in GameState.SLOTS:
		have.append(GameState.equipped(slot))
	for iid: String in GameState.run.get("inv", {}):
		have.append(iid)
	var seen: Dictionary = Decor.st()["got"]
	for iid in have:
		var cs := str(GameState.items.get(str(iid), {}).get("costume", ""))
		var wid := str(by_body.get(cs, ""))
		if wid != "" and not is_starter(wid) and not seen.has(wid) and in_arc(wid):
			Decor.give(wid, 1, "gear")
			got.append(wid)
	return got


## Penguin heroes: accessory pieces pinned at PENGUIN_ANCHOR, following the sprite.
static func dress_penguin_hero(parent: Node2D, anim: AnimatedSprite2D, sprite: String) -> void:
	for ch in parent.get_children():
		if ch.name.begins_with("PenguinAcc"):
			ch.name = "OldAcc%d" % ch.get_instance_id()  # free the name for the new holder
			ch.queue_free()
	var pieces: Array = []
	for slot: String in ["acc", "hat"]:
		var id := worn_id(slot)
		if id == "" or not shows_on(id):
			continue
		var pg: Dictionary = entry(id).get("penguin", {})
		for kind: String in ["neck", "face"]:
			if pg.has(kind):
				pieces.append([kind, str(pg[kind]), Color(str(pg.get("tint", "ffffff")))])
	if pieces.is_empty():
		return
	var anc: Dictionary = PENGUIN_ANCHOR.get(sprite, PENGUIN_ANCHOR["penguin"])
	var holder := Node2D.new()
	holder.name = "PenguinAcc"
	holder.z_index = 1
	parent.add_child(holder)
	var nodes: Array = []
	for p in pieces:
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.self_modulate = p[2]
		holder.add_child(s)
		nodes.append([s, p])
	var upd := func() -> void:
		if not is_instance_valid(holder) or not is_instance_valid(anim) or anim.sprite_frames == null:
			return
		var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if tex == null:
			return
		var bb := frame_box(tex)
		var view := view_of(str(anim.animation))
		var sc := anim.scale.x
		var flip := anim.flip_h
		holder.position = anim.position
		holder.modulate = anim.modulate
		holder.visible = anim.visible
		for n in nodes:
			var s: Sprite2D = n[0]
			var kind: String = n[1][0]
			var gn: String = n[1][1]
			var i := gn.rfind("/")
			var g := gn.left(i)
			var base := gn.substr(i + 1)
			var v := view
			if not Art.has(g, "%s_%s" % [base, v]):
				v = "front" if v != "back" else ""
			if v == "" or (kind == "neck" and base == "pg_bowtie" and view == "back"):
				s.visible = false
				continue
			var t := Art.tex(g, "%s_%s" % [base, v])
			s.texture = t
			s.visible = true
			var want_w: float = bb[3] * float(anc["w"]) * float(PIECE_W.get(base, 1.0)) * (0.8 if v == "side" else 1.0)
			var k := want_w / maxf(1.0, float(t.get_width()))
			s.scale = Vector2(k, k) * sc
			var fy: float = bb[2] - (bb[2] - bb[1]) * float(anc[kind])
			var fx: float = bb[0] + (bb[3] * 0.12 * (-1.0 if flip else 1.0) if v == "side" else 0.0)
			s.flip_h = flip if v == "side" else false
			s.offset = Vector2(0, t.get_height() * 0.5 - 2.0) if kind == "neck" and base != "pg_bowtie" else Vector2.ZERO
			s.position = Vector2((fx - tex.get_width() / 2.0) * sc * (-1.0 if flip and v != "side" else 1.0), (fy - tex.get_height()) * sc)
	anim.frame_changed.connect(upd)
	anim.animation_changed.connect(upd)
	upd.call()


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
