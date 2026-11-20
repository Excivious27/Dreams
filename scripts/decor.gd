class_name Decor
## Decor and wearables catalogue (CONDUCT 10a). CONTRACT STUB written by the main chat
## before the fix packages branched: every package codes against these signatures.
## P1 owns this file and fills it in (it may add functions, never change these).
## Data: data/decor.json from tools/gen_decor.py: {"items": {id: entry}, "sets": {}, "shops": {}, "pools": {}}
## entry: {name, cat (furniture|wall_art|decor|light|rug|wallpaper|flooring|hat|top|bottom|outfit|acc|shoes),
##         rarity (common|uncommon|rare|epic|legendary|mythic|unique), arc ("" = both | penguins | gangsters),
##         layer (floor|wall|under|window|wear), size [w, h], rot (int views), glow (bool), art ("group/name"),
##         icon ("group/name"), price, sell, sources [..], set ("" or set id)}
## State: run["decor"] = {box: {id: n}, placed: {key: [{id, cell:[x,y], rot}]}, wall: {room: id},
##         floor: {room: id}, wear: {slot: id}, seen: {id: day}, got: {id: day}}

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "unique"]
const WEAR_SLOTS := ["hat", "top", "bottom", "outfit", "acc", "shoes"]
const RARITY_COLORS := {
	"common": Color(0.8, 0.8, 0.8), "uncommon": Color(0.45, 0.85, 0.45), "rare": Color(0.4, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.75, 0.3), "mythic": Color(1.0, 0.4, 0.55),
	"unique": Color(0.4, 1.0, 0.95)}

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/decor.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
		for k in ["items", "sets", "shops", "pools"]:
			if not _data.has(k):
				_data[k] = {}
	return _data


static func entry(id: String) -> Dictionary:
	return (data()["items"] as Dictionary).get(id, {})


static func is_decor(id: String) -> bool:
	return not entry(id).is_empty()


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("decor", null) is Dictionary):
		r["decor"] = {}
	var d: Dictionary = r["decor"]
	for k in ["box", "placed", "wall", "floor", "wear", "seen", "got"]:
		if not (d.get(k, null) is Dictionary):
			d[k] = {}
	return d


static func owned(id: String) -> int:
	return int((st()["box"] as Dictionary).get(id, 0))


static func give(id: String, n := 1, _source := "") -> void:
	if n <= 0 or not is_decor(id):
		return
	var d := st()
	if is_unique(id) and (owned(id) > 0 or placed_count(id) > 0):
		return
	d["box"][id] = owned(id) + n
	if not (d["got"] as Dictionary).has(id):
		d["got"][id] = int(GameState.run.get("day", 1))


static func take(id: String, n := 1) -> bool:
	if owned(id) < n:
		return false
	var d := st()
	d["box"][id] = owned(id) - n
	if int(d["box"][id]) <= 0:
		(d["box"] as Dictionary).erase(id)
	return true


static func placed_count(id: String) -> int:
	var t := 0
	for key in st()["placed"]:
		for p in st()["placed"][key]:
			if p is Dictionary and str(p.get("id", "")) == id:
				t += 1
	return t


static func rarity(id: String) -> String:
	return str(entry(id).get("rarity", "common"))


static func rarity_rank(r: String) -> int:
	return maxi(0, RARITIES.find(r))


static func rarity_color(r: String) -> Color:
	return RARITY_COLORS.get(r, RARITY_COLORS["common"])


static func is_unique(id: String) -> bool:
	return rarity(id) == "unique"


static func price(id: String) -> int:
	return int(entry(id).get("price", 0))


## Ids a shop stocks today (shop keys are written by gen_decor.py).
static func stock(shop: String) -> Array:
	return ((data()["shops"] as Dictionary).get(shop, []) as Array).duplicate()


## One roll from a loot pool ("chest_t2", "boss", "fishing", ...): an id or "".
static func roll(pool: String, _luck := 0.0) -> String:
	var p: Array = (data()["pools"] as Dictionary).get(pool, [])
	if p.is_empty():
		return ""
	var id := str(p[randi() % p.size()])
	return "" if (is_unique(id) and (owned(id) > 0 or placed_count(id) > 0)) else id


static func worn(slot: String) -> String:
	return str((st()["wear"] as Dictionary).get(slot, ""))


static func wear(slot: String, id: String) -> void:
	if slot in WEAR_SLOTS:
		if id == "":
			(st()["wear"] as Dictionary).erase(slot)
		else:
			st()["wear"][slot] = id
