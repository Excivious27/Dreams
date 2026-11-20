class_name Decor
## Decor and wearables catalogue (CONDUCT 10a). The contract signatures (data, entry, is_decor, st,
## owned/give/take, placed_count, rarity/rarity_rank/rarity_color, is_unique, price, stock, roll,
## worn/wear, RARITIES, WEAR_SLOTS) are fixed: every package codes against them. P1 owns this file.
## Data: data/decor.json from tools/gen_decor.py (edit the generator, never the JSON):
##   {rarity: [{id, rank, col, glyph, label, band, weight, comfort}], items: {id: entry}, sets, shops
##    {shop: [[tier, [ids]]]}, shop_slots, shop_days, pools {pool: [[id, weight]]}, recipes, house_reserved,
##    sell_share, reorder_fee, reorder_min, pity, luck_step, legacy}
## entry: {name, name_gang?, cat (furniture|wall_art|decor|light|rug|wallpaper|flooring|hat|top|bottom|outfit|acc|shoes),
##         sub, rarity (common..mythic|unique), tier 1-5, arc ("both"|penguins|gangsters), layer (floor|wall|under|window|wear),
##         size [w, h] cells, rot (views; rot_art lists them), glow (bool), art ("group/name"), icon ("group/name"),
##         surface?, style? (wallpaper/flooring tileset), renders? (wear: doll|icon), costume?, anim? (frames),
##         price (shop price, 0 = not sold), sell, sources [{kind, ref, once?}], set, sets [], comfort, ext? (rp_ prize)}
## State: run["decor"] = {box: {id: n}, placed: {key: [{id, cell:[x,y], rot}]}, wall: {room: id},
##         floor: {room: id}, wear: {slot: id}, seen: {id: day}, got: {id: day}, uniques: {id: day},
##         pity: {pool: n}, sold: {id: n}, mig: int}
## Decor and wearables never live in the bag: GameState.add_item routes them here, GameState.count reads total().

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "unique"]
const WEAR_SLOTS := ["hat", "top", "bottom", "outfit", "acc", "shoes"]
## CVD-safe ramp that also steps in lightness (c10_07); decor.json "rarity" carries the same values.
const RARITY_COLORS := {
	"common": Color(0.82, 0.82, 0.82), "uncommon": Color(0.35, 0.85, 0.70), "rare": Color(0.35, 0.60, 1.0),
	"epic": Color(1.0, 0.45, 0.80), "legendary": Color(1.0, 0.80, 0.25), "mythic": Color(1.0, 0.35, 0.35),
	"unique": Color(0.4, 1.0, 0.95)}
## Wear category -> slot (acc covers scarves, capes, gloves, glasses).
const CAT_SLOT := {"hat": "hat", "top": "top", "bottom": "bottom", "outfit": "outfit", "acc": "acc", "shoes": "shoes"}
const WEAR_CATS := ["hat", "top", "bottom", "outfit", "acc", "shoes"]
const MIGRATION := 1
## Toast/note for the last give (Hud may show it like GameState.overflow_note).
static var last_note := ""

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


## Tests: drop the cache (next data() reloads the file) or inject a whole table.
static func reset_data(d: Dictionary = {}) -> void:
	_data = d


static func entry(id: String) -> Dictionary:
	return (data()["items"] as Dictionary).get(id, {})


static func is_decor(id: String) -> bool:
	return id != "" and not entry(id).is_empty()


static func is_wear(id: String) -> bool:
	return str(entry(id).get("cat", "")) in WEAR_CATS


static func st() -> Dictionary:
	var r: Dictionary = GameState.run
	if not (r.get("decor", null) is Dictionary):
		r["decor"] = {}
	var d: Dictionary = r["decor"]
	for k in ["box", "placed", "wall", "floor", "wear", "seen", "got", "uniques", "pity", "sold"]:
		if not (d.get(k, null) is Dictionary):
			d[k] = {}
	return d


## Pieces in the decor box (not placed, not worn).
static func owned(id: String) -> int:
	return int((st()["box"] as Dictionary).get(id, 0))


## Everything you have of it: box + placed in every room + worn (+ room wallpaper/flooring in use).
## GameState.count(id) returns this for decor ids, so quest/prize/collection checks keep working.
static func total(id: String) -> int:
	var n := owned(id) + placed_count(id)
	var d := st()
	for slot in d["wear"]:
		if str(d["wear"][slot]) == id:
			n += 1
	for k in ["wall", "floor"]:
		for room in d[k]:
			if str(d[k][room]) == id:
				n += 1
	return n


## Was it ever yours (catalogue "owned" state; never drops when sold).
static func ever_owned(id: String) -> bool:
	return (st()["got"] as Dictionary).has(id)


static func give(id: String, n := 1, _source := "") -> void:
	if n <= 0 or not is_decor(id):
		return
	var d := st()
	if is_unique(id):
		if total(id) > 0 or (d["uniques"] as Dictionary).has(id):
			last_note = "You already have the one and only %s." % display_name(id)
			return
		n = 1
		d["uniques"][id] = int(GameState.run.get("day", 1))
	d["box"][id] = owned(id) + n
	if not (d["got"] as Dictionary).has(id):
		d["got"][id] = int(GameState.run.get("day", 1))
	see(id)
	last_note = ("%s added to your wardrobe." if is_wear(id) else "%s sent to your decor box.") % display_name(id)


## Takes from the box only (placed/worn pieces must be picked up first). Uniques can only be taken to be
## placed: callers that would sell/trash/gift check is_unique / GameState.keeps first.
static func take(id: String, n := 1) -> bool:
	if n <= 0 or owned(id) < n:
		return false
	var d := st()
	d["box"][id] = owned(id) - n
	if int(d["box"][id]) <= 0:
		(d["box"] as Dictionary).erase(id)
	return true


static func see(id: String) -> void:
	if is_decor(id) and not (st()["seen"] as Dictionary).has(id):
		st()["seen"][id] = int(GameState.run.get("day", 1))


static func placed_count(id: String) -> int:
	var t := 0
	for key in st()["placed"]:
		var lst: Variant = st()["placed"][key]
		if not (lst is Array):
			continue
		for p in lst:
			if p is Dictionary and str(p.get("id", "")) == id:
				t += 1
	return t


static func rarity(id: String) -> String:
	var r := str(entry(id).get("rarity", ""))
	if r == "":
		r = str(GameState.items.get(id, {}).get("rarity", "common"))
	return r if r in RARITIES else "common"


static func rarity_rank(r: String) -> int:
	return maxi(0, RARITIES.find(r))


static func rarity_color(r: String) -> Color:
	return RARITY_COLORS.get(r, RARITY_COLORS["common"])


static func rarity_label(r: String) -> String:
	for row in data().get("rarity", []):
		if row is Dictionary and str(row.get("id", "")) == r:
			return str(row.get("label", r.capitalize()))
	return "One of a kind" if r == "unique" else r.capitalize()


## Glyph drawn instead of / after the rank dots (mythic star, unique diamond; both in fonts/symbols.ttf).
static func rarity_glyph(r: String) -> String:
	return {"mythic": "★", "unique": "◆"}.get(r, "")


static func is_unique(id: String) -> bool:
	return rarity(id) == "unique"


static func price(id: String) -> int:
	return int(entry(id).get("price", 0))


## What a shop charges today: the list price with a small discount (Specs' till codes / buy perks), never
## below DECOR_BUY_MIN of the list price (econ_check mirrors it: no buy-sell loop). Re-ordering a piece you
## sold costs the re-order fee on top (catalogue orders, c10_12).
const DECOR_BUY_MIN := 0.8 * 0.9

static func buy_price(id: String, reorder := false) -> int:
	var p := price(id)
	if p <= 0:
		return 0
	var m: float = maxf(0.8, GameState.buy_multiplier()) * float([1.0, 0.95, 0.9, 0.9][clampi(Crew.perk_level("shop_discount"), 0, 3)])
	var out := int(ceil(p * clampf(m, DECOR_BUY_MIN, 1.0)))
	if reorder:
		out += reorder_fee(id)
	return maxi(1, out)


static func reorder_fee(id: String) -> int:
	return maxi(int(data().get("reorder_min", 50)), int(ceil(price(id) * float(data().get("reorder_fee", 0.1)))))


## Can it be ordered from the catalogue: sold once (shop price > 0), seen/owned before, not unique/mythic.
static func can_reorder(id: String) -> bool:
	return price(id) > 0 and ever_owned(id) and not rarity(id) in ["unique", "mythic"] and in_arc(id)


## Flat sell-back from the decor box: no perks, no demand (econ_check: always below the cheapest buy).
static func sell_value(id: String) -> int:
	if is_unique(id):
		return 0
	var v := int(entry(id).get("sell", 0))
	if GameState.items.has(id):
		v = mini(v, int(GameState.items[id].get("value", v))) if v > 0 else int(GameState.items[id].get("value", 0))
	return maxi(0, v)


## Sells n from the box. Returns the money paid (0 = refused: unique, none in the box).
static func sell(id: String, n := 1) -> int:
	if is_unique(id) or n <= 0 or owned(id) < n:
		return 0
	var pay := sell_value(id) * n
	take(id, n)
	st()["sold"][id] = int((st()["sold"] as Dictionary).get(id, 0)) + n
	if pay > 0:
		GameState.add_money(pay, "decor")
	return pay


## Arc filter: "" / "both" = every arc (c10_01-09; Tickets.arc_ok semantics).
static func in_arc(id: String) -> bool:
	var a := str(entry(id).get("arc", ""))
	return a == "" or a == "both" or a == str(GameState.run.get("arc", ""))


static func display_name(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return GameState.item_name(id) if GameState.items.has(id) else id
	if str(GameState.run.get("arc", "")) == "gangsters" and str(e.get("name_gang", "")) != "":
		return str(e["name_gang"])
	return str(e.get("name", id))


## Art for the catalogue/shops: [group, name]. Icon first, else the placed art.
static func icon_ref(id: String) -> Array:
	var ref := str(entry(id).get("icon", entry(id).get("art", "")))
	var i := ref.rfind("/")
	return [ref.substr(0, i), ref.substr(i + 1)] if i > 0 else ["items", ref]


static func slot_for(id: String) -> String:
	return str(CAT_SLOT.get(str(entry(id).get("cat", "")), ""))


# ---- shops: daily/weekly rotation (deterministic per shop + day: reopening never re-rolls) -------------

## Every id a shop can ever stock at this progress tier and arc (catalogue, econ, tests).
static func stock_all(shop: String, tier := -1) -> Array:
	if tier < 0:
		tier = GameState.progress_tier() + 1
	var out: Array = []
	for row in (data()["shops"] as Dictionary).get(shop, []):
		if row is Array and row.size() >= 2 and int(row[0]) <= tier:
			for id in row[1]:
				if in_arc(str(id)):
					out.append(str(id))
	return out


## Ids a shop stocks today: shop_slots of them, rotating every shop_days days (seeded by shop + period).
static func stock(shop: String) -> Array:
	var pool := stock_all(shop)
	var slots := int((data().get("shop_slots", {}) as Dictionary).get(shop, 8))
	if pool.size() <= slots:
		return pool
	var every := maxi(1, int((data().get("shop_days", {}) as Dictionary).get(shop, 1)))
	var period := int(GameState.run.get("day", 1)) / every
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [shop, period, int(GameState.run.get("seed", 0))])
	var left := pool.duplicate()
	var out: Array = []
	while out.size() < slots and not left.is_empty():
		out.append(left.pop_at(rng.randi() % left.size()))
	return out


# ---- loot rolls (c10_07): weights by rarity, soft-capped luck, pity, duplicate protection ---------------

## Effective luck on a soft curve: 3 -> 3.1, 10 -> 7.1, 20 -> 9.2, never above 10.
static func luck_eff(luck: float) -> float:
	return 10.0 * (1.0 - exp(-maxf(0.0, luck) / 8.0))


## One roll from a loot pool ("chest_t2", "boss", "fishing", "mine_t3", "claw", "festival"): an id or "".
## rng: pass a seeded RandomNumberGenerator for a reproducible roll (tests); otherwise the global RNG
## (seed(n) in tests). Pity: after `pity` rolls on a pool without a rare+, the next roll is rare+.
static func roll(pool: String, luck := 0.0, rng: RandomNumberGenerator = null) -> String:
	var rows: Variant = (data()["pools"] as Dictionary).get(pool, [])
	if not (rows is Array) or (rows as Array).is_empty():
		return ""
	var pity_n := int(data().get("pity", 8))
	var pity_d: Dictionary = st()["pity"]
	var force_rare := int(pity_d.get(pool, 0)) >= pity_n
	var step := float(data().get("luck_step", 0.04)) * luck_eff(luck)
	var cand: Array = []
	var total_w := 0.0
	for row in rows:
		var id := ""
		var w := 1.0
		if row is Array and row.size() >= 1:
			id = str(row[0])
			w = float(row[1]) if row.size() > 1 else 1.0
		else:
			id = str(row)
		if not is_decor(id) or is_unique(id) or not in_arc(id):
			continue
		var rk := rarity_rank(rarity(id))
		if force_rare and rk < 2:
			continue
		w *= 1.0 + step * rk
		# Duplicate protection: a rare+ piece you already have is a third as likely.
		if rk >= 2 and total(id) > 0:
			w /= 3.0
		cand.append([id, w])
		total_w += w
	if cand.is_empty():
		if force_rare:
			pity_d[pool] = 0  # this pool holds no rare+ piece: pity has nothing to give
			return roll(pool, luck, rng)
		return ""
	var r := (rng.randf() if rng != null else randf()) * total_w
	var pick := str(cand[-1][0])
	for c in cand:
		r -= float(c[1])
		if r <= 0.0:
			pick = str(c[0])
			break
	pity_d[pool] = 0 if rarity_rank(rarity(pick)) >= 2 else int(pity_d.get(pool, 0)) + 1
	return pick


# ---- wardrobe -------------------------------------------------------------------------------------------

static func worn(slot: String) -> String:
	return str((st()["wear"] as Dictionary).get(slot, ""))


## Wearing moves the piece out of the box (and the old one back in); id "" takes the slot off.
## A piece that isn't in the box is refused (worn(slot) tells the caller).
static func wear(slot: String, id: String) -> void:
	if not slot in WEAR_SLOTS:
		return
	var d := st()
	var old := worn(slot)
	if id == "":
		if old != "":
			d["box"][old] = owned(old) + 1
		(d["wear"] as Dictionary).erase(slot)
		return
	if id == old:
		return
	if not take(id, 1):
		return  # only pieces in the box can be put on (no copies from nothing)
	if old != "":
		d["box"][old] = owned(old) + 1
	d["wear"][slot] = id


# ---- comfort score (sets + rarity) ---------------------------------------------------------------------

## A room's comfort: each placed piece's rarity comfort, wallpaper/flooring 2 each, +set comfort when
## every piece of a set stands in that room. key "" = the whole house (every "house*" key).
static func comfort(key := "") -> int:
	var d := st()
	var ids := {}
	var pts := 0
	for k in d["placed"]:
		if key != "" and str(k) != key:
			continue
		if key == "" and not str(k).begins_with("house"):
			continue
		for p in d["placed"][k]:
			if p is Dictionary:
				var id := str(p.get("id", ""))
				pts += int(entry(id).get("comfort", 1))
				ids[id] = true
	for k in ["wall", "floor"]:
		for room in d[k]:
			if key == "" or str(room) == key:
				pts += 2
	for sid in data()["sets"]:
		var s: Dictionary = data()["sets"][sid]
		var all_in := not (s.get("pieces", []) as Array).is_empty()
		for p in s.get("pieces", []):
			if not ids.has(str(p)):
				all_in = false
				break
		if all_in:
			pts += int(s.get("comfort", 0))
	return pts


## Set progress: [have (ever owned), total].
static func set_progress(sid: String) -> Array:
	var s: Dictionary = (data()["sets"] as Dictionary).get(sid, {})
	var have := 0
	for p in s.get("pieces", []):
		if ever_owned(str(p)):
			have += 1
	return [have, (s.get("pieces", []) as Array).size()]


## Cells a house tier keeps free (walls, door, cellar hatch, study, bath): [[x, y, w, h, why]].
static func reserved(tier: int) -> Array:
	return ((data().get("house_reserved", {}) as Dictionary).get(str(tier), []) as Array)


## True when a house cell is kept free at this tier (the reason in reserved_why).
static func is_reserved(tier: int, c: Vector2i) -> bool:
	return reserved_why(tier, c) != ""


static func reserved_why(tier: int, c: Vector2i) -> String:
	for r in reserved(tier):
		if r is Array and r.size() >= 5 and c.x >= int(r[0]) and c.x < int(r[0]) + int(r[2]) and c.y >= int(r[1]) and c.y < int(r[1]) + int(r[3]):
			return str(r[4])
	return ""


# ---- migration (GameState._migrate) ---------------------------------------------------------------------

## Moves decor/wear ids out of the bag, toolbar, bag slots and every chest into the decor box (old saves
## kept rp_ prizes in the bag to show them at home: RecCenter.dress_house reads GameState.count, which now
## reads total(), so nothing vanishes). Idempotent: safe on every load.
static func migrate() -> void:
	var r: Dictionary = GameState.run
	var d := st()
	if data()["items"].is_empty():
		d["mig"] = maxi(int(d.get("mig", 0)), 0)
		return
	var inv: Variant = r.get("inventory", null)
	if inv is Dictionary:
		for id in (inv as Dictionary).keys():
			if is_decor(str(id)):
				_absorb(str(id), int(inv[id]))
				(inv as Dictionary).erase(id)
	for k in ["toolbar", "bag_slots"]:
		if r.get(k) is Array:
			var a: Array = r[k]
			for i in a.size():
				if is_decor(str(a[i])):
					a[i] = ""
	var ch: Variant = r.get("chests", null)
	if ch is Dictionary:
		for key in ch:
			var b: Variant = ch[key]
			if b is Dictionary and b.get("items") is Dictionary:
				var its: Dictionary = b["items"]
				for id in its.keys():
					if is_decor(str(id)):
						_absorb(str(id), int(its[id]))
						its.erase(id)
				if b.get("slots") is Array:
					var sl: Array = b["slots"]
					for i in sl.size():
						if is_decor(str(sl[i])):
							sl[i] = ""
	# Legacy ids renamed in the catalogue.
	var leg: Dictionary = data().get("legacy", {})
	for old in d["box"].keys():
		if leg.has(old) and is_decor(str(leg[old])):
			_absorb(str(leg[old]), int(d["box"][old]))
			(d["box"] as Dictionary).erase(old)
	d["mig"] = MIGRATION


static func _absorb(id: String, n: int) -> void:
	if n <= 0:
		return
	var d := st()
	if is_unique(id):
		n = 1 if total(id) == 0 else 0
		if n == 0:
			return
		d["uniques"][id] = int(GameState.run.get("day", 1))
	d["box"][id] = owned(id) + n
	if not (d["got"] as Dictionary).has(id):
		d["got"][id] = int(GameState.run.get("day", 1))
	see(id)
