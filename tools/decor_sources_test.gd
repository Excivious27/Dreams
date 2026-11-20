extends SceneTree
## C10a P4: decor sources. With an empty catalogue every hook is a no-op; with entries
## injected into Decor._data: grants land in the decor box (never the bag), uniques are
## granted once and refused by the sell paths, shelves rotate deterministically and
## filter arc/tier/owned uniques, Rec decor prizes go to the box and a lost once-prize
## can be bought back, chest/mine/fishing pools roll, perks pay through add_money,
## craft chips stay few, the koi needs the lit lighthouse and is caught once.
##   godot --headless --path . -s res://tools/decor_sources_test.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	seed(10)
	_run.call_deferred()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["day"] = 5
	var saved: Dictionary = Decor.data().duplicate(true)

	# ---- empty catalogue: nothing changes -------------------------------------------------
	Decor._data = {"items": {}, "sets": {}, "shops": {}, "pools": {}}
	check(DecorSources.today("store").is_empty(), "empty catalogue: no decor shelf")
	check(DecorSources.roll_grant(null, "chest_t1") == "", "empty pool rolls nothing")
	check(not DecorSources.grant(null, "potion"), "a non-decor id is never granted as decor")
	check(not DecorSources.keeps("potion"), "potions can be sold")
	check(DecorSources.keeps("rp_music_box"), "a Rec once-prize is kept (never sold/shipped)")

	# ---- a small catalogue ----------------------------------------------------------------
	Decor._data = {
		"items": {
			"dc_stool": {"name": "Stool", "cat": "furniture", "rarity": "common", "arc": "", "price": 120, "tier": 0},
			"dc_lamp": {"name": "Lamp", "cat": "light", "rarity": "uncommon", "arc": "", "price": 300, "tier": 1},
			"dc_rug": {"name": "Rug", "cat": "rug", "rarity": "common", "arc": "", "price": 90, "stack": true},
			"dc_neon": {"name": "Neon Sign", "cat": "wall_art", "rarity": "rare", "arc": "gangsters", "price": 900},
			"dc_vase": {"name": "Vase", "cat": "decor", "rarity": "rare", "arc": "", "price": 800},
			"dc_late": {"name": "Late Piece", "cat": "decor", "rarity": "common", "arc": "", "price": 100, "tier": 4},
			"dc_crown": {"name": "Star Crown", "cat": "decor", "rarity": "unique", "arc": "", "price": 5000},
			"dc_keep": {"name": "Journal Map Table", "cat": "furniture", "rarity": "unique", "arc": ""},
			"wr_cap": {"name": "Cap", "cat": "hat", "layer": "wear", "rarity": "common", "arc": "", "price": 50},
		},
		"sets": {}, "pools": {"chest_t1": ["dc_vase"], "mine_t1": ["dc_lamp"], "fishing": ["dc_stool"], "boss": ["dc_vase"]},
		"shops": {"maple": ["dc_stool", "dc_lamp", "dc_rug", "dc_neon", "dc_vase", "dc_late", "dc_crown", "wr_cap"]},
		"grants": {"secret:journal": "dc_keep", "house:2": "dc_vase"},
	}
	var inv0: int = (GameState.run["inventory"] as Dictionary).size()
	check(DecorSources.grant(null, "dc_stool", 2, "test"), "grant a stool")
	check(Decor.owned("dc_stool") == 2 and GameState.count("dc_stool") == 0, "decor goes to the decor box, not the bag")
	check((GameState.run["inventory"] as Dictionary).size() == inv0, "the bag is untouched")
	check(DecorSources.grant(null, "dc_crown") and not DecorSources.grant(null, "dc_crown"), "a unique is granted once only")
	check(Decor.owned("dc_crown") == 1, "one crown in the box")
	check(DecorSources.keeps("dc_crown") and not DecorSources.keeps("dc_stool"), "uniques are kept, commons can go")
	check(DecorSources.is_wear("wr_cap") and not DecorSources.is_wear("dc_lamp"), "wear entries are told apart")

	# Shelf: arc + tier filtered, owned unique hidden, deterministic per day.
	var shelf := DecorSources.today("store")
	check(not shelf.has("dc_neon"), "a gangster-only piece is not on the penguin shelf")
	check(not shelf.has("dc_late"), "a tier-4 piece waits for progress")
	check(not shelf.has("dc_crown"), "an owned unique is not sold again")
	check(shelf.has("dc_stool") and shelf.size() <= int(DecorSources.T["shelf_n"]), "shelf lists today's pieces (%s)" % [shelf])
	check(DecorSources.today("store") == shelf, "same shelf on a second look (no re-roll)")
	var rares := shelf.filter(func(i: Variant) -> bool: return Decor.rarity_rank(Decor.rarity(str(i))) >= 2)
	check(rares.size() <= int(DecorSources.T["rare_n"]), "at most %d rare pieces on a shelf" % int(DecorSources.T["rare_n"]))
	var big: Array = []
	for i in 20:
		big.append("x%02d" % i)
	GameState.run["day"] = 6
	var r1 := DecorSources.rotate(big, 4, 3, 7)
	GameState.run["day"] = 8
	check(DecorSources.rotate(big, 4, 3, 7) == r1, "rotation holds within its 3-day window")
	GameState.run["day"] = 9
	check(DecorSources.rotate(big, 4, 3, 7) != r1, "rotation turns over after the window")
	GameState.run["day"] = 5

	# Buying from the shelf.
	GameState.run["crystals"] = 1000
	check(DecorSources.buy(null, "dc_lamp") == "ok" and int(GameState.run["crystals"]) == 700 and Decor.owned("dc_lamp") == 1, "buying a lamp costs 300 and boxes it")
	GameState.run["crystals"] = 10
	check(DecorSources.buy(null, "dc_lamp") == "poor" and Decor.owned("dc_lamp") == 1, "too poor: nothing changes")
	GameState.run["crystals"] = 99999
	check(DecorSources.buy(null, "dc_crown") == "owned", "a unique you own can't be bought")

	# Catalogue orders: paid now, a parcel in tomorrow's post, opened into the decor box.
	GameState.run["crystals"] = 1000
	check(DecorSources.order("dc_lamp") == "ok" and int(GameState.run["crystals"]) == 1000 - DecorSources.order_price("dc_lamp"), "an order is paid up front with the re-order fee")
	check(DecorSources.deliver_orders() == 0, "nothing arrives the same day")
	GameState.run["day"] = 6
	check(DecorSources.deliver_orders() == 1 and DecorSources.orders().is_empty(), "the order arrives next morning")
	var parcel: Dictionary = (Mail.list() as Array).back()
	check(Mail._act(parcel) == "" and Decor.owned("dc_lamp") == 2, "opening the parcel boxes the lamp")
	check(DecorSources.order("dc_crown") == "owned", "an owned unique can't be ordered")
	GameState.run["day"] = 5

	# Housewarming: one parcel per new farmhouse tier with a grant.
	if not GameState.run.has("builds"):
		GameState.run["builds"] = {}
	GameState.run["builds"]["house"] = 2
	var mails := (Mail.list() as Array).size()
	Mail._housewarming()
	Mail._housewarming()
	check((Mail.list() as Array).size() == mails + 1, "one housewarming parcel for tier 2")

	# The shelf screen: lists today's pieces and buys into the box.
	var scr := DecorShopScreen.new()
	scr.shop = "store"
	root.add_child(scr)
	check(scr._rows == DecorSources.today("store") and not scr._rows.is_empty(), "the shelf screen lists today's pieces")
	scr.sel = scr._rows.find("dc_stool")
	var before := Decor.owned("dc_stool")
	scr._buy()
	check(Decor.owned("dc_stool") == before + 1 and scr.bought == 1, "BUY on the screen boxes the piece")
	scr._close()

	# Loot hooks.
	check(Secrets.decor_pool(0) == "chest_t1" and Secrets.decor_pool(9) == "chest_t5", "chest pools by loot tier")
	var mine: Variant = load("res://scripts/mine.gd")
	check(mine.decor_pool(10, true) == "mine_t1" and mine.decor_pool(150, true) == "mine_t5" and mine.decor_pool(140, false) == "mine_t1", "mine pools by depth (miner's chests stay shallow)")
	check(Fishing.decor_pool("lake", 0) == "fishing" and Fishing.decor_pool("beach", 0) == "fishing", "fishing pools fall back to the shared pool")
	check(DecorSources.roll_grant(null, "chest_t1", 99.0) == "dc_vase" and Decor.owned("dc_vase") == 1, "a chest roll grants its piece")
	check(DecorSources.grant_key(null, "secret:journal") == "dc_keep" and DecorSources.grant_key(null, "secret:journal") == "", "a fixed grant gives its keepsake once")

	# Perks: money through add_money, decor keepsakes to the box.
	var earned := int(GameState.run.get("earned_total", 0))
	Perks._give({"#gold": 500, "#decor:dc_rug": 1})
	check(int(GameState.run.get("earned_total", 0)) == earned + 500, "friendship money counts as earned")
	check(Decor.owned("dc_rug") == 1, "a heart keepsake lands in the decor box")

	# Mail: a decor gift goes to the box; a favour can't take a unique.
	var letter := {"kind": "gift", "item": "dc_stool", "n": 1}
	var stools := Decor.owned("dc_stool")
	check(Mail._act(letter) == "" and Decor.owned("dc_stool") == stools + 1 and GameState.count("dc_stool") == 0, "mail decor gift goes to the box")

	# Commons: a kept piece never sells at the stand.
	GameState.add_item("rp_music_box", 1, true)
	check(Commons.sell_at_market("rp_music_box", 1) == 0 and GameState.count("rp_music_box") == 1, "the stand refuses a one-of-a-kind piece")
	GameState.add_item("rp_music_box", -1)

	# Rec prize counter: a lost once-prize can be bought back; decor prizes go to the box.
	RecReno.all_open = true
	Tickets.add(5000, "test")
	check(Tickets.buy("rp_music_box") == "", "buy the music box")
	check(GameState.count("rp_music_box") == 1, "a non-catalogue prize is still a bag item")
	check(Tickets.lock_text("rp_music_box") == "Already yours", "once-prize: one at a time")
	GameState.add_item("rp_music_box", -1)  # an old save sold it before C10
	check(Tickets.lock_text("rp_music_box") == "", "a lost once-prize can be bought back")
	(Decor._data["items"] as Dictionary)["rp_music_box"] = {"name": "Music Box", "cat": "decor", "rarity": "uncommon", "arc": ""}
	check(Tickets.buy("rp_music_box") == "", "buy it again")
	check(Decor.owned("rp_music_box") == 1 and GameState.count("rp_music_box") == 0, "a catalogue prize goes to the decor box")
	check(Tickets.lock_text("rp_music_box") == "Already yours", "and counts as yours from the box")
	check(Tickets.have("rp_music_box") == 1, "Tickets.have sees the box")

	# Crafting chips: few per station, decor gets its own.
	check(Crafting.decor_cat("dc_rug") == "Wall & floor" and Crafting.decor_cat("wr_cap") == "Wardrobe" and Crafting.decor_cat("dc_stool") == "Furniture", "decor chips")
	var most := 0
	var worst := ""
	for st in GameState.recipes:
		var cats := {}
		for rc: Dictionary in GameState.recipes[st]:
			if not rc.has("give"):
				continue
			cats[Crafting._cat(rc)] = true
		if cats.size() > most:
			most = cats.size()
			worst = str(st)
	check(most <= 7, "craft chips per station stay few (most %d at %s)" % [most, worst])

	# Fishing: the koi needs the lit lighthouse and exists once; luck's rare share is capped.
	check(not Fishing.koi_open(), "no koi before the lighthouse is lit")
	GameState.run["flags"]["lighthouse_lit"] = true
	check(Fishing.koi_open(), "the koi can bite at the lit lake")
	if not GameState.run.has("seen"):
		GameState.run["seen"] = {}
	(GameState.run["seen"] as Dictionary)["legendary_koi"] = true
	check(not Fishing.koi_open(), "only one koi exists")
	check(float(Fishing.T["rare_luck_cap"]) <= 0.15, "luck's Rare Catch share is capped")
	check(ArcadeClaw.grip_for(0.0, 10.0, 0.45, 25.0, 0) < 0.6, "claw: max luck no longer holds every grab at a loose machine")

	Decor._data = saved
	print("decor_sources_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
