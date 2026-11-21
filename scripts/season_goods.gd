class_name SeasonGoods
extends RefCounted
## C15 P2: what each season forages and sells (data/season_goods.json from tools/gen_seasons.py).
## Hooks: GameState._roll_forage_once -> forage_pool, Shops.offers -> shop_extra / seeds,
## DecorSources.today -> decor_ok + decor_shelf, Shops.stall -> festival_treats.

static var _d: Dictionary = {}

## Out-of-season crops sell a little dearer (was 1.35 with no spoilage: harvest, chest it and sell
## next season for +35%, c15_08-04). GameState.demand reads this.
const OFF_SEASON_DEMAND := 1.1


static func data() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open("res://data/season_goods.json", FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_d = v
	return _d


## The season a map forages in: always-winter places (look_se) stay winter.
static func season_here() -> String:
	return GameState.look_se()


static func year() -> int:
	return maxi(1, (int(GameState.run.get("day", 1)) - 1) / (GameState.DAYS_PER_SEASON * 4) + 1)


## A region's base pool with the season's own finds added and off-season rows thinned or dropped.
## Only valley regions (data "valley") change; mega regions keep their own tables.
static func forage_pool(region: String, base: Array, se := "") -> Array:
	var d := data()
	if not (d.get("valley", []) as Array).has(region):
		return base
	if se == "":
		se = season_here()
	var off: Dictionary = (d.get("forage_off", {}) as Dictionary).get(se, {})
	var out: Array = []
	for row: Array in base:
		var m := float(off.get(str(row[0]), 1.0))
		if m <= 0.0:
			continue
		if m < 1.0:
			var r := row.duplicate()
			r[1] = float(row[1]) * m
			out.append(r)
		else:
			out.append(row)
	for row: Array in ((d.get("forage", {}) as Dictionary).get(se, {}) as Dictionary).get(region, []):
		out.append(row)
	return out if not out.is_empty() else base


## Season-only goods for a shop (+ year 2+ extras), arc-only items left out of the other arc.
static func shop_extra(shop: String, se := "") -> Array:
	if se == "":
		se = GameState.season()
	var d := data()
	var ids: Array = ((d.get("shops", {}) as Dictionary).get(shop, {}) as Dictionary).get(se, []).duplicate()
	if year() >= 2:
		ids += ((d.get("shops_y2", {}) as Dictionary).get(shop, {}) as Dictionary).get(se, [])
	var arc := str(GameState.run.get("arc", ""))
	return ids.filter(func(i: Variant) -> bool:
		var a := str(GameState.items.get(str(i), {}).get("arc", ""))
		return GameState.items.has(str(i)) and (a == "" or a == arc))


## Maple's off-season packets once you have a greenhouse plot (c15_08-11).
static func greenhouse_seeds(se := "") -> Array:
	if se == "":
		se = GameState.season()
	if not has_greenhouse():
		return []
	return ((data().get("greenhouse_seeds", {}) as Dictionary).get(se, []) as Array).filter(func(i: Variant) -> bool: return GameState.items.has(str(i)))


static func has_greenhouse() -> bool:
	return Builds.is_built("greenhouse")


## Seasonal decor (decor.json "season") only sells in its season, except on a festival stall's own shelf.
static func decor_ok(id: String, shop := "") -> bool:
	var se := str(Decor.entry(id).get("season", ""))
	if se == "" or shop.begins_with("stall:festival"):
		return true
	return se == GameState.season()


## The season's decor pieces a keeper shelf (carpenter / carpenter_gang) adds all season (c15_08-06).
static func decor_shelf(shop: String) -> Array:
	if not shop in ["carpenter", "carpenter_gang"]:
		return []
	var all := Decor.stock_all("stall:festival_" + GameState.season())
	return DecorSources.rotate(all, 6, 7, 15)  # six of the season's pieces, turning over weekly


## Festival stall treats for the season ([[id, price], ...]); empty if none.
static func festival_treats(se := "") -> Array:
	if se == "":
		se = GameState.season()
	return ((data().get("festival_treats", {}) as Dictionary).get(se, []) as Array).filter(func(r: Variant) -> bool: return GameState.items.has(str(r[0])) and (str(GameState.items[str(r[0])].get("arc", "")) in ["", str(GameState.run.get("arc", ""))]))


## A crop's seasons as a list ("any" -> all four); crop "season" may be a String or an Array (c15_08-16).
static func crop_seasons(cd: Dictionary) -> Array:
	var cs: Variant = cd.get("season", "any")
	if cs is Array:
		return cs
	if str(cs) == "any":
		return ["spring", "summer", "fall", "winter"]
	return [str(cs)]


## The everyday ground find on a map's grass for a season (WorldGen ground detail): mostly the
## season's own forage, sometimes the old staple (flower / wild_herb / mushroom).
const GROUND := {
	"spring": [["flower", 0.35], ["fiddlehead", 0.25], ["crocus", 0.2], ["dandelion", 0.2]],
	"summer": [["wild_herb", 0.35], ["honeysuckle", 0.3], ["chamomile", 0.15], ["cattail", 0.2]],
	"fall": [["mushroom", 0.35], ["hazelnut", 0.25], ["rosehip", 0.2], ["leaf_bundle", 0.2]],
	"winter": [["snow_yam", 0.4], ["holly_sprig", 0.4], ["wild_herb", 0.2]],
}


static func ground_item(se: String, r: float) -> String:
	var rows: Array = GROUND.get(se, GROUND["fall"])
	for row: Array in rows:
		r -= float(row[1])
		if r <= 0.0 and GameState.items.has(str(row[0])):
			return str(row[0])
	return str(rows[0][0])


## An item the season tables added (it lists the seasons it's found in).
static func is_seasonal_forage(id: String) -> bool:
	return not (GameState.items.get(id, {}).get("forage_seasons", []) as Array).is_empty()
