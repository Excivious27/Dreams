extends SceneTree
## C15 P2: each season has its own forage, crops, shop goods, stall goods, decor and dishes, both arcs.
##   godot --headless --path . --fixed-fps 60 -s res://tools/season_goods_test.gd
var fails := 0
const SEASONS := ["spring", "summer", "fall", "winter"]


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(15)
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.look_season = ""
		_forage(arc)
		_shops(arc)
		_decor(arc)
	_crops_and_dishes()
	print("season_goods_test: %s (%d fails)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _set_season(i: int, dos := 5, yr := 1) -> void:
	GameState.run["day"] = 1 + (yr - 1) * 112 + i * 28 + (dos - 1)


func _forage(arc: String) -> void:
	for i in 4:
		_set_season(i)
		var se: String = SEASONS[i]
		check(GameState.season() == se, "%s: day maps to %s" % [arc, se])
		var own := {}
		for region in ["farm", "forest", "meadow", "lake", "beach", "mountain"]:
			for n in 600:
				var id := GameState.roll_forage(region)
				var fs: Array = GameState.items.get(id, {}).get("forage_seasons", [])
				check(fs.is_empty() or se in fs, "%s %s: %s rolled %s (a %s find)" % [arc, se, region, id, str(fs)])
				if se in fs:
					own[id] = true
				if se == "winter" and region in ["farm", "meadow"]:
					check(not id in ["berry", "flower", "wild_leek"], "%s winter %s: no %s under snow" % [arc, region, id])
		check(own.size() >= 4, "%s %s: >= 4 season-only forage ids (got %s)" % [arc, se, str(own.keys())])
	# Ground finds (WorldGen) follow the season too.
	for se in SEASONS:
		var seen := {}
		for k in 40:
			seen[SeasonGoods.ground_item(se, k / 40.0)] = true
		check(seen.size() >= 3, "%s: >= 3 ground finds (%s)" % [se, str(seen.keys())])
		if se == "winter":
			check(not seen.has("flower") and not seen.has("mushroom"), "winter ground: no flowers or mushrooms")
	# Always-winter maps forage winter whatever the calendar says.
	_set_season(1)
	GameState.look_season = "winter"
	var pool := SeasonGoods.forage_pool("forest", GameState.forage_data["forest"])
	check(pool.any(func(r: Array) -> bool: return str(r[0]) == "holly_sprig"), "look_se winter -> winter forage")
	GameState.look_season = ""
	# Mega regions keep their own tables.
	var frost: Array = GameState.forage_data.get("frost_glacier", [])
	check(SeasonGoods.forage_pool("frost_glacier", frost) == frost, "mega region pools untouched")


func _shops(arc: String) -> void:
	var lists := {}
	for i in 4:
		_set_season(i, 3)
		var se: String = SEASONS[i]
		var st := Shops.offers("store")
		lists[se] = st
		var seeds := st.filter(func(s: Variant) -> bool:
			var c := str(GameState.items.get(str(s), {}).get("crop", ""))
			return GameState.crops.has(c) and str(GameState.crops[c].get("season", "")) == se)
		check(seeds.size() >= 3, "%s %s: Maple has >= 3 season seeds (%s)" % [arc, se, str(seeds)])
		for shop in ["store", "orla", "bait", "marlowe"]:
			var ex := SeasonGoods.shop_extra(shop)
			check(not ex.is_empty(), "%s %s: %s has season goods" % [arc, se, shop])
			for id in ex:
				check(id in Shops.offers(shop), "%s %s: %s lists %s" % [arc, se, shop, id])
		# Stall seed filter and festival treats.
		var benno := Shops.stall_items([["hay", 8], ["carrot_seed", 8], ["corn_seed", 8]])
		var ids := benno.map(func(r: Variant) -> String: return str((r as Array)[0]))
		check(("carrot_seed" in ids) == (se == "spring"), "%s %s: carrot seeds only in spring on a stall" % [arc, se])
		check(("corn_seed" in ids) == (se == "summer"), "%s %s: corn seeds only in summer on a stall" % [arc, se])
		var fest := Shops.stall_items([["candy", 15]], "festival_" + se)
		check(fest.size() >= 2, "%s %s: festival stall adds the season's treats" % [arc, se])
	check(lists["spring"] != lists["summer"] and lists["fall"] != lists["winter"], "%s: store lists differ by season" % arc)
	# Year 2 adds a good.
	_set_season(0, 3, 2)
	check(SeasonGoods.year() == 2, "year 2 from the day")
	check("asparagus_tart" in Shops.offers("store"), "%s: year-2 spring good at Maple's" % arc)
	# Greenhouse: off-season packets.
	_set_season(3, 3)
	check(SeasonGoods.greenhouse_seeds().is_empty() or SeasonGoods.has_greenhouse(), "no glass seeds without a greenhouse")
	# Seed line warning: day 27, a 2-day crop no longer ripens (farm rule: nights from today to day 27).
	GameState.run["day"] = 27
	check(Shops.line("radish_seed").ends_with(" !"), "%s: '!' on a 2-day seed on spring 27" % arc)
	GameState.run["day"] = 25
	check(not Shops.line("radish_seed").ends_with(" !"), "%s: no '!' on a 2-day seed on spring 25" % arc)


func _decor(arc: String) -> void:
	_set_season(3, 4)
	check(SeasonGoods.decor_ok("dc_fest_gift_pile"), "winter decor sells in winter")
	check(not SeasonGoods.decor_ok("dc_fest_pumpkins"), "fall decor not in winter")
	check(SeasonGoods.decor_ok("dc_fest_pumpkins", "stall:festival_fall"), "festival stall keeps its own pieces")
	var key := "carpenter" if arc == "penguins" else "carpenter_gang"
	var shelf := DecorSources.today("carpenter")
	check(shelf.any(func(i: Variant) -> bool: return str(Decor.entry(str(i)).get("season", "")) == "winter"), "%s: carpenter shows winter decor in winter (%s)" % [arc, key])
	check(not shelf.any(func(i: Variant) -> bool: return str(Decor.entry(str(i)).get("season", "")) in ["spring", "summer", "fall"]), "%s: no off-season decor on the carpenter shelf" % arc)


func _crops_and_dishes() -> void:
	for se in SEASONS:
		var n := 0
		for cid in GameState.crops:
			if str(GameState.crops[cid].get("season", "")) == se:
				n += 1
		check(n >= 8, "%s has >= 8 crops (%d)" % [se, n])
		var dishes := 0
		for r: Dictionary in GameState.recipes.get("kitchen", []):
			if str(r.get("season", "")) == se:
				dishes += 1
				for k in r["need"]:
					check(str(k).begins_with("#") or GameState.items.has(str(k)), "%s needs a real item %s" % [r["id"], k])
		check(dishes >= 4, "%s has >= 4 seasonal dishes (%d)" % [se, dishes])
	for cid in ["frostkale", "snow_radish", "winter_leek", "winter_cabbage"]:
		check(GameState.crops.has(cid) and GameState.items.has(cid + "_seed"), "winter crop %s has a crop and a seed" % cid)
		check(Hud.icon_for(cid + "_seed") != "seeds", "%s_seed has its own icon" % cid)
	check(Hud.icon_for("moon_melon_seed") != "seeds", "moon melon seeds have an icon")
	for id in ["fiddlehead", "sea_glass", "chanterelle", "holly_sprig", "winter_honeycomb"]:
		check(Art.has("items", Hud.icon_for(id)), "%s has an icon" % id)
