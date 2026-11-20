extends SceneTree
## Decor catalogue runtime (CONDUCT 10a P1): generator data checks, give/take/unique, routing through
## GameState (count/add_item/keeps/trash/gift), seeded rolls + pity + luck, shop rotation (reload-proof),
## prices/sell-back (no loop), wardrobe, comfort, 7 rarities, old-save migration round trip, empty data.
##   godot --headless --path . -s res://tools/decor_test.gd
var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	Campaign.bypass = true
	seed(42)
	_run.call_deferred()

func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var d := Decor.data()
	var items: Dictionary = d["items"]
	# --- generator output -------------------------------------------------------------------------
	check(items.size() >= 400, "catalogue size %d" % items.size())
	check(Decor.RARITIES.size() == 7 and GameState.RARITY_RANKS == Decor.RARITIES, "one rarity table (7 levels)")
	var by_r := {}
	for id in items:
		var e: Dictionary = items[id]
		by_r[e["rarity"]] = int(by_r.get(e["rarity"], 0)) + 1
		var ref := str(e.get("icon", ""))
		if not Art.has("items", ref):
			check(false, "icon resolves through Art: %s %s" % [id, ref])
		if not e.get("ext", false):
			check(GameState.items.has(id) and str(GameState.items[id].get("type", "")) in ["decor", "wear"], "items.json entry " + id)
			check(str(GameState.items.get(id, {}).get("arc", "")) != "both", "no arc 'both' in items.json " + id)
	for r in Decor.RARITIES:
		check(int(by_r.get(r, 0)) > 0, "has %s pieces" % r)
	for p in ["chest_t1", "chest_t2", "chest_t3", "chest_t4", "chest_t5", "mine_t1", "mine_t5", "boss", "fishing", "claw", "festival"]:
		check(((d["pools"] as Dictionary).get(p, []) as Array).size() > 0, "pool exists: " + p)
	for s in ["home_goods", "wall_art", "wardrobe", "crew_goods", "hub_goods"]:
		check((d["shops"] as Dictionary).has(s), "shop exists: " + s)
	# --- keys P3/P4 reference ------------------------------------------------------------------
	for p in ["fishing_sea", "fishing_deep", "mail"]:
		check(((d["pools"] as Dictionary).get(p, []) as Array).size() > 0, "pool exists: " + p)
	for k in ["maple", "gideon", "wren", "granite", "sel", "tam", "orla", "marlowe", "rook", "old_moss", "catkins", "finn", "carpenter"]:
		check(((d["shops"] as Dictionary).get(k, []) as Array).size() > 0, "keeper shelf: " + k)
		check(not (d["shop_slots"] as Dictionary).has(k), "keeper shelf is a full list (P4 rotates): " + k)
	check((d["shops"] as Dictionary).has("maple_gang") and not (d["shops"] as Dictionary).has("catkins_gang"), "gang shelves (none for Catkins)")
	for id in ["dc_koi_scroll", "dc_golden_rod_mount", "dc_master_hearth", "dc_golden_crate", "dc_founders_orrery", "dc_collectors_shelf", "dc_grand_catalogue_stand",
			"dc_museum_trophy", "dc_mineral_display", "dc_relic_shelf", "dc_curio_jar", "dc_fish_trophy", "dc_shipper_ribbon"]:
		check(Decor.is_decor(id), "P3 keepsake entry: " + id)
	check(Decor.is_unique("dc_founders_orrery") and Decor.order_price("dc_koi_scroll") == 0, "orrery unique, keepsakes never ordered")
	check(Decor.grant_id("secret:journal") != "" and Decor.grant_id("house:2") != "" and Decor.grant_id("heart:maple:8") != "", "grant keys")
	for gk in (d.get("grants", {}) as Dictionary):
		check(Decor.is_decor(str(d["grants"][gk])), "grant points at an entry: " + str(gk))
	check(Decor.order_price("dc_sofa_red") == Decor.buy_price("dc_sofa_red", true), "order price = re-order price")
	check(str(Decor.entry("dc_sofa_red").get("arc", "x")) == "", "decor.json arc '' for both arcs")
	Decor.st()
	check(GameState.run["decor"]["orders"] is Array and GameState.run["decor"]["sets_done"] is Dictionary and GameState.run["decor"]["viewed"] is Dictionary, "P3 run.decor keys exist")
	# --- icons resolve from any group ---------------------------------------------------------------
	check(Art.has("items", "furniture/sofa_red") and Art.tex("items", "furniture/sofa_red") != null, "group-qualified icon texture")
	check(Art.info("items", "furniture/sofa_red").get("w", 0) == Art.info("furniture", "sofa_red").get("w", -1), "group-qualified info")
	# --- give / take / count routing --------------------------------------------------------------
	var sofa := "dc_sofa_red"
	check(Decor.is_decor(sofa), "sofa is decor")
	GameState.add_item(sofa, 2)
	check(not (GameState.run["inventory"] as Dictionary).has(sofa), "decor never enters the bag")
	check(Decor.owned(sofa) == 2 and GameState.count(sofa) == 2, "count reads the decor box")
	GameState.run["decor"]["placed"]["house"] = [{"id": sofa, "cell": [3, 4], "rot": 0}]
	check(GameState.count(sofa) == 3 and Decor.owned(sofa) == 2, "placed pieces count, box unchanged")
	GameState.add_item(sofa, -5)
	check(Decor.owned(sofa) == 0 and GameState.count(sofa) == 1, "negative add takes from the box only")
	check(not (GameState.run["inventory"] as Dictionary).has(sofa), "no negative bag entry")
	GameState.run["decor"]["placed"].erase("house")
	# --- uniques ---------------------------------------------------------------------------------------
	var uq := ""
	for id in items:
		if str(items[id]["rarity"]) == "unique" and not str(id).begins_with("wr_"):
			uq = str(id)
			break
	check(uq != "", "a unique exists")
	Decor.give(uq, 3)
	check(Decor.owned(uq) == 1, "unique gives one")
	Decor.give(uq)
	check(Decor.owned(uq) == 1, "second unique refused")
	check(GameState.keeps(uq) and not GameState.can_trash(uq) and Decor.sell(uq) == 0, "unique kept: no trash, no sell")
	check(not GameState.can_gift("posy", uq), "unique not giftable")
	Decor.take(uq, 1)
	Decor.give(uq)
	check(Decor.owned(uq) == 0, "a unique taken out (placed elsewhere / gone) never comes back")
	check(GameState.rarity_rank(uq) == 6 and GameState.rarity_color(uq) == Decor.rarity_color("unique"), "unique draws as rank 6 + own colour")
	# --- prices and sell-back (no loop) --------------------------------------------------------------
	var priced := 0
	for id in items:
		var p := Decor.price(str(id))
		if p > 0:
			priced += 1
			var lo := Decor.buy_price(str(id))
			check(Decor.sell_value(str(id)) < lo, "sell below cheapest buy: " + str(id))
			check(GameState.buy_price(str(id)) == lo, "GameState.buy_price uses Decor: " + str(id))
	check(priced > 300, "priced pieces %d" % priced)
	GameState.add_item("dc_tt_vase", 1)
	var m0 := int(GameState.run.get("crystals", 0))
	var pay := Decor.sell("dc_tt_vase")
	check(pay == Decor.sell_value("dc_tt_vase") and int(GameState.run.get("crystals", 0)) == m0 + pay and Decor.owned("dc_tt_vase") == 0, "sell from the box pays flat value")
	check(Decor.can_reorder("dc_tt_vase") and Decor.buy_price("dc_tt_vase", true) == Decor.buy_price("dc_tt_vase") + Decor.reorder_fee("dc_tt_vase"), "re-order adds the fee")
	check(Decor.reorder_fee("dc_tt_vase") >= 10 and Decor.reorder_fee("dc_tt_vase") <= maxi(10, int(ceil(Decor.price("dc_tt_vase") * 0.1))), "re-order fee 10%, min 10 (c10b_10_10)")
	# --- shop rotation: deterministic per day, filtered by arc --------------------------------------
	GameState.run["day"] = 5
	var a := Decor.stock("home_goods")
	Decor.reset_data()
	var b := Decor.stock("home_goods")
	check(a == b and a.size() == int(d["shop_slots"]["home_goods"]), "stock is the same on reopen (%d)" % a.size())
	GameState.run["day"] = 6
	check(Decor.stock("home_goods") != a, "stock rotates the next day")
	for id in Decor.stock_all("crew_goods", 9):
		check(Decor.in_arc(str(id)), "penguin run sees only in-arc crew stock: " + str(id))
		check(str(Decor.entry(str(id)).get("arc", "")) != "gangsters", "no gangster piece in penguin stock: " + str(id))
	# --- rolls: seeded, pity, luck ------------------------------------------------------------------
	var r1 := RandomNumberGenerator.new(); r1.seed = 7
	var r2 := RandomNumberGenerator.new(); r2.seed = 7
	GameState.run["decor"]["pity"] = {}
	var s1: Array = []
	for i in 20:
		s1.append(Decor.roll("chest_t3", 0.0, r1))
	GameState.run["decor"]["pity"] = {}
	var s2: Array = []
	for i in 20:
		s2.append(Decor.roll("chest_t3", 0.0, r2))
	check(s1 == s2 and not s1.has(""), "same seed, same rolls")
	var streak := 0
	var worst := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	GameState.run["decor"]["pity"] = {}
	for i in 400:
		var id := Decor.roll("chest_t3", 0.0, rng)
		check(not Decor.is_unique(id), "no unique from loot")
		if Decor.rarity_rank(Decor.rarity(id)) >= 2:
			streak = 0
		else:
			streak += 1
			worst = maxi(worst, streak)
	check(worst <= int(d["pity"]), "pity caps the dry streak (%d)" % worst)
	var hi0 := 0
	var hi1 := 0
	var ra := RandomNumberGenerator.new(); ra.seed = 11
	var rb := RandomNumberGenerator.new(); rb.seed = 11
	for i in 600:
		GameState.run["decor"]["pity"] = {}
		if Decor.rarity_rank(Decor.rarity(Decor.roll("boss", 0.0, ra))) >= 4: hi0 += 1
		GameState.run["decor"]["pity"] = {}
		if Decor.rarity_rank(Decor.rarity(Decor.roll("boss", 25.0, rb))) >= 4: hi1 += 1
	check(hi1 > hi0 and hi1 < hi0 * 3 + 20, "luck helps, soft-capped (%d -> %d)" % [hi0, hi1])
	check(Decor.luck_eff(100.0) <= 10.0 and absf(Decor.luck_eff(10.0) - 7.13) < 0.05, "luck curve")
	check(Decor.roll("no_such_pool") == "", "unknown pool rolls nothing")
	# --- wardrobe -------------------------------------------------------------------------------
	var hat := "wr_straw"
	GameState.add_item(hat, 1)
	check(Decor.is_wear(hat) and Decor.slot_for(hat) == "hat", "wear entry + slot")
	Decor.wear("hat", hat)
	check(Decor.worn("hat") == hat and Decor.owned(hat) == 0 and GameState.count(hat) == 1, "wearing moves it out of the box")
	Decor.wear("hat", "wr_cap")
	check(Decor.worn("hat") == hat, "can't wear what you don't own")
	Decor.wear("hat", "")
	check(Decor.worn("hat") == "" and Decor.owned(hat) == 1, "taking off returns it")
	# --- comfort + sets ------------------------------------------------------------------------------
	var sid := ""
	for k in d["sets"]:
		sid = str(k)
		break
	var pieces: Array = d["sets"][sid]["pieces"]
	var lst: Array = []
	for p in pieces:
		lst.append({"id": p, "cell": [1, 1], "rot": 0})
	GameState.run["decor"]["placed"]["house"] = lst
	var base := 0
	for p in pieces:
		base += int(Decor.entry(str(p)).get("comfort", 1))
	check(Decor.comfort() == base + int(d["sets"][sid]["comfort"]), "full set adds its comfort")
	GameState.run["decor"]["placed"].erase("house")
	check(Decor.reserved(3).size() >= 5, "tier-3 reserved cells")
	check(Decor.reserved_why(1, Vector2i(8, 11)) == "door" and Decor.reserved_why(2, Vector2i(4, 3)) == "bed", "door and bed kept free (house.gd DOOR/BED)")
	check(Decor.reserved_why(3, Vector2i(18, 10)) == "cellar" and not Decor.is_reserved(2, Vector2i(18, 10)), "cellar hatch only reserved in the Manor")
	check(Decor.reserved_why(3, Vector2i(23, 8)) == "spouse" and not Decor.is_reserved(3, Vector2i(6, 6)), "spouse corner reserved, open floor free")
	# --- migration: an old v9 save with rp_ decor in bag + chest -----------------------------------
	GameState.new_run("gangsters", "kairi", "T", "Town", "Pup")
	GameState.run.erase("decor")
	GameState.run["save_ver"] = 9
	GameState.run["inventory"]["rp_jukebox"] = 1
	GameState.run["inventory"]["dc_tt_vase"] = 2
	(GameState.run["toolbar"] as Array)[3] = "rp_jukebox"
	GameState.run["chests"] = {"chest": {"items": {"rp_trophy_gold": 1, "turnip": 4}}}
	GameState.run["flags"]["lighthouse_lit"] = true
	var txt := JSON.stringify(GameState.run)
	GameState.run = JSON.parse_string(txt)
	GameState._migrate()
	check(not (GameState.run["inventory"] as Dictionary).has("rp_jukebox") and Decor.owned("rp_jukebox") == 1, "bag rp_ decor -> box")
	check(Decor.owned("dc_tt_vase") == 2 and GameState.count("rp_jukebox") == 1, "count still sees migrated decor (RecCenter.dress_house)")
	check(Decor.owned("rp_trophy_gold") == 1 and not (GameState.run["chests"]["chest"]["items"] as Dictionary).has("rp_trophy_gold"), "chest decor -> box")
	check(int(GameState.run["chests"]["chest"]["items"]["turnip"]) == 4, "other chest goods untouched")
	check(not (GameState.run["toolbar"] as Array).has("rp_jukebox"), "toolbar slot freed")
	check(Decor.owned("dc_u_lighthouse_lamp") == 1, "old save past the lighthouse gets its unique once")
	check(int(GameState.run["save_ver"]) == GameState.SAVE_VERSION and GameState.SAVE_VERSION >= 10, "save version bumped")
	var once := JSON.stringify(JSON.parse_string(JSON.stringify(GameState.run["decor"])))
	GameState.run = JSON.parse_string(JSON.stringify(GameState.run))
	GameState._migrate()
	check(JSON.stringify(JSON.parse_string(JSON.stringify(GameState.run["decor"]))) == once, "migration is idempotent across a save round trip")
	GameState.run["decor"] = null
	GameState._migrate()
	check(Decor.st()["box"] is Dictionary, "null decor block rebuilt")
	# --- save size budget: a full house stays small ------------------------------------------
	var big: Array = []
	for i in 300:
		big.append({"id": "dc_sofa_red", "cell": [i % 24, i / 24], "rot": 0})
	GameState.run["decor"]["placed"]["house"] = big
	var bytes := JSON.stringify(GameState.run["decor"]).length()
	check(bytes < 20000, "300 placed pieces cost %d bytes" % bytes)
	GameState.run["decor"]["placed"].erase("house")
	check((Decor.st()["pity"] as Dictionary).size() <= (Decor.data()["pools"] as Dictionary).size(), "pity keeps one counter per pool")
	# --- gangster arc filter ---------------------------------------------------------------------
	var gang_ok := false
	for id in Decor.stock_all("crew_goods", 9):
		if str(Decor.entry(str(id)).get("arc", "")) == "gangsters":
			gang_ok = true
	check(gang_ok, "gangster run sees crew pieces")
	_c10b(d)
	# --- empty data: everything still answers ---------------------------------------------------
	Decor.reset_data({"items": {}, "sets": {}, "shops": {}, "pools": {}})
	check(not Decor.is_decor("dc_sofa_red") and Decor.roll("chest_t1") == "" and Decor.stock("home_goods").is_empty(), "empty catalogue is inert")
	GameState.add_item("dc_sofa_red", 1)
	check(Decor.owned("dc_sofa_red") == 0, "unknown id not boxed when the catalogue is empty")
	GameState._migrate()
	Decor.reset_data()
	print("decor_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)



## C10b P1: catalogue data, shelves, grants, comfort, migration, the carpenter.
func _c10b(d: Dictionary) -> void:
	GameState.run["arc"] = "penguins"
	var items: Dictionary = d["items"]
	var outdoor := 0
	var commons := {}
	for id in items:
		var e: Dictionary = items[id]
		if str(e["cat"]) in ["wallpaper", "flooring"]:
			check(str(e["layer"]) == str(e["cat"]), "surface layer is the cat (DecorMode.SURFACE_LAYERS): " + id)
		if str(e["layer"]) == "outdoor":
			outdoor += 1
			check(float(e.get("scale", 0)) > 0.0 and str(e["cat"]) == "outdoor", "outdoor piece has a draw scale: " + id)
		if str(e["rarity"]) == "common" and int(e["price"]) > 0:
			commons[int(e["price"])] = true
		if str(e.get("arc", "")) == "" and not e.get("ext", false):
			check(not str(e["name"]).to_lower().contains("penguin"), "no penguin name in a both-arc piece: " + id)
		if Decor.rarity(id) == "unique":
			var src: Dictionary = (e["sources"] as Array)[0]
			check(Decor.grant_id("%s:%s" % [src["kind"], src["ref"]]) == id, "unique has a live grant key: " + id)
	check(outdoor >= 60, "outdoor catalogue %d pieces" % outdoor)
	check(commons.size() >= 20, "common price ladder has %d steps" % commons.size())
	for sid in d["sets"]:
		var st: Dictionary = d["sets"][sid]
		check(int((st.get("reward", {}) as Dictionary).get("money", 0)) > 0, "set pays on claim: " + sid)
		check(not str(st["name"]).to_lower().contains("casino") and not str(st["name"]).to_lower().contains("rec hall"), "set name words: " + sid)
		if str(st.get("arc", "")) == "":
			for p in st["pieces"]:
				check(str(Decor.entry(str(p)).get("arc", "")) == "", "both-arc set %s holds only both-arc pieces (%s)" % [sid, p])
	for k in ["carpenter", "carpenter_gang", "lumi", "crew_marlene", "crew_deuce", "crew_specs", "crew_halo", "stall:festival_spring", "stall:festival_winter", "stall:gloam_lanternfall", "stall:docks"]:
		check(((d["shops"] as Dictionary).get(k, []) as Array).size() > 0, "shelf exists: " + k)
	for se in ["spring", "summer", "fall", "winter"]:
		check(((d["pools"] as Dictionary).get("festival_%s_prize" % se, []) as Array).size() > 0, "festival prize pool " + se)
	# Shelf prices: discounts apply, re-order costs more, flat 10% fee (min 10).
	var sofa := "dc_sofa_red"
	check(Decor.buy_price(sofa) <= Decor.price(sofa) and Decor.order_price(sofa) > Decor.buy_price(sofa), "shelf <= list < re-order")
	check(DecorSources.order_price(sofa) == Decor.order_price(sofa), "one re-order price")
	check(Decor.reorder_fee(sofa) == maxi(10, int(ceil(Decor.price(sofa) * 0.1))), "re-order fee 10%% (min 10)")
	# Rotation: a mixed shelf (at most two of a kind while the pool allows).
	var pool := Decor.stock_all("carpenter", 9)
	for day in [1, 4, 7, 10]:
		GameState.run["day"] = day
		var shelf := DecorSources.rotate(pool, 6, 3, 5)
		var subs := {}
		for i in shelf:
			subs[str(Decor.entry(str(i)).get("sub", ""))] = int(subs.get(str(Decor.entry(str(i)).get("sub", "")), 0)) + 1
		var worst := 0
		for k in subs:
			worst = maxi(worst, int(subs[k]))
		check(shelf.size() == 6 and worst <= 2, "day %d shelf mixed (max %d of a kind)" % [day, worst])
	GameState.run["day"] = 1
	# Event grants: a state-based key fires once from the morning sweep.
	GameState.run["flags"]["lighthouse_lit"] = true
	Decor.st()["box"].erase("dc_u_lighthouse_lamp")
	Decor.st()["got"].erase("dc_u_lighthouse_lamp")
	Decor.st()["uniques"].erase("dc_u_lighthouse_lamp")
	Decor.st()["swept"] = {}
	var got := DecorSources.sweep(null)
	check(got.has("dc_u_lighthouse_lamp") and DecorSources.sweep(null).is_empty(), "sweep grants a secret-flag unique once")
	# Comfort: duplicates count less; tiers; morning softens a late wake.
	GameState.run["decor"]["placed"]["house"] = []
	for i in 10:
		GameState.run["decor"]["placed"]["house"].append({"id": "dc_sofa_red", "cell": [i, 5], "rot": 0})
	var c10 := Decor.comfort()
	check(c10 <= int(Decor.entry("dc_sofa_red")["comfort"]) + 2, "ten copies count as one + two points (%d)" % c10)
	check(Decor.comfort_tier(0).size() == 4 and str(Decor.comfort_tier(500)[1]) == "Dream Home", "comfort tiers")
	var big: Array = []
	for id in items:
		if str(items[id]["layer"]) == "floor" and big.size() < 80:
			big.append({"id": id, "cell": [big.size() % 20, big.size() / 20], "rot": 0})
	GameState.run["decor"]["placed"]["house"] = big
	GameState.run["energy"] = 10
	var line := Decor.morning_comfort()
	check(int(GameState.run["energy"]) > 10 and line != "", "a cosy home lifts a short night's energy: " + line)
	GameState.run["decor"]["placed"].erase("house")
	# C9 keepsakes: run.coll.decor pieces land in the house once (mig 2).
	GameState.run["coll"] = {"decor": {"fish_trophy": true}}
	Decor.st()["mig"] = 1
	Decor.st()["box"].erase("dc_fish_trophy")
	Decor.migrate()
	var placed_ok := false
	for p in (Decor.st()["placed"].get("house", []) as Array):
		if str(p.get("id", "")) == "dc_fish_trophy":
			placed_ok = true
	check(placed_ok and Decor.total("dc_fish_trophy") == 1, "C9 fish trophy placed in the house")
	Decor.migrate()
	check(Decor.total("dc_fish_trophy") == 1, "keepsake migration runs once")
	Decor.st()["placed"].erase("house")
	# Exterior parts count as held (P3 run.decor.exterior {part: id}).
	check(Decor.st()["exterior"] is Dictionary, "run.decor.exterior exists")
	# Gangster names: no penguin/crystal words on a gangster shelf or display name.
	GameState.run["arc"] = "gangsters"
	for k in ["maple_gang", "carpenter_gang", "crew_deuce", "stall:neon"]:
		for id in Decor.stock_all(k, 9):
			var nm := DecorSources.name_of(str(id)).to_lower()
			check(not nm.contains("penguin") and not nm.contains("crystal"), "gang shelf %s word-clean: %s" % [k, nm])
	GameState.run["arc"] = "penguins"
	# The carpenter: villager, workshop counter, shelf key, heart keepsake.
	check(GameState.npcs.has("tess") and str(GameState.npcs["tess"]["home"]) == "workshop", "Tess the carpenter lives at the workshop")
	var rooms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors.json"))
	var has_counter := false
	for t in rooms["workshop"]["things"]:
		if str(t.get("type", "")) == "counter" and str(t.get("shop", "")) == "carpenter":
			has_counter = true
	check(has_counter and DecorSources.SHELF.has("carpenter"), "workshop counter sells the carpenter shelf")
	check(Decor.grant_id("heart:tess:8") != "" and Intros.LINES.has("tess"), "Tess: heart keepsake, first-meeting lines")
	check(TownHours.SHOPS.has("workshop"), "workshop keeps shop hours")
