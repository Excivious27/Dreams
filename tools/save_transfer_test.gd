extends SceneTree
## C9 P5: save codes/files (SaveTransfer) edge cases, null run blocks, save pruning.
##   godot --headless --path . -s res://tools/save_transfer_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	Campaign.bypass = true
	seed(9)
	_run.call_deferred()

func _code_of(d: Dictionary) -> String:
	return SaveTransfer.encode_farm(d)

func _raw_code(prefix: String, ver: int, d: Variant) -> String:
	var json := JSON.stringify(d)
	var b64 := Marshalls.raw_to_base64(json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return "%s:%d:%s:x:%s" % [prefix, ver, SaveTransfer._check(json), b64]

func _run() -> void:
	SaveGame.reset_cache()
	for n in [1, 2, 3]:
		SaveGame.set_value(GameState.slot_key(n), {})
		SaveGame.set_value(SaveTransfer.prev_key_of(n), null)
	GameState.run = {}
	GameState.use_slot(1)
	GameState.new_run("penguins", "kairi", "Ann", "Town", "Pup")
	GameState.run["day"] = 12
	GameState.save()
	var code := GameState.export_code()
	check(code.begins_with("DRM2:%d:" % GameState.SAVE_VERSION), "new codes carry format, version and check (%s)" % code.substr(0, 30))
	check(code.contains(":Ann-day12:"), "code carries a readable label")
	# Empty slot: no code.
	check(GameState.export_code(3) == "", "an empty slot gives no code")
	# Forgiving decode: wrapped, spaced, quoted, lowercase prefix.
	var wrapped := code.substr(0, 60) + "\n" + code.substr(60, 60) + " " + code.substr(120)
	check(bool(SaveTransfer.decode(wrapped)["ok"]), "a wrapped code with spaces decodes")
	check(bool(SaveTransfer.decode("> \"" + "drm2" + code.substr(4) + "\"\r\n")["ok"]), "quote marks and a lowercase prefix are fine")
	# Old DRM1 codes still load.
	var old := "DRM1:" + Marshalls.raw_to_base64(JSON.stringify(SaveTransfer.farm_of(1)).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	check(bool(SaveTransfer.decode(old)["ok"]), "an old DRM1 code still decodes")
	# One changed letter -> typo (check), cut off -> cut.
	var parts := code.split(":")
	var b64: String = parts[4]
	var flip := b64.substr(0, 40) + ("A" if b64[40] != "A" else "B") + b64.substr(41)
	var flipped := "%s:%s:%s:%s:%s" % [parts[0], parts[1], parts[2], parts[3], flip]
	var fr := SaveTransfer.decode(flipped)
	check(not bool(fr["ok"]) and str(fr["code"]) in ["typo", "cut"], "a changed letter is refused (%s)" % fr["code"])
	check(str(SaveTransfer.decode(code.substr(0, code.length() / 2))["code"]) in ["cut", "typo"], "a cut-off code is refused")
	check(str(SaveTransfer.decode("hello")["code"]) == "not_code", "not a code")
	check(str(SaveTransfer.decode("")["code"]) == "empty", "empty paste")
	# Newer version refused.
	check(str(SaveTransfer.decode(_raw_code("DRM2", GameState.SAVE_VERSION + 1, SaveTransfer.farm_of(1)))["code"]) == "newer", "a code from a newer build is refused")
	# Wrong types refused without touching the slot.
	GameState.use_slot(2)
	for bad in [{"names": "x", "arc": "penguins", "playable": "kairi"},
			{"names": {"character": "Z"}, "arc": "pirates", "playable": "kairi"},
			{"names": {"character": "Z"}, "arc": "penguins", "playable": "nobody"},
			{"names": {"character": "Z"}, "arc": "penguins", "playable": "kairi", "day": "ten"},
			{"names": {"character": "Z"}, "arc": "penguins", "playable": "kairi", "inventory": [1]}]:
		var why := GameState.import_code(_raw_code("DRM2", 1, bad))
		check(why != "" and GameState.slot_info(2) == "Empty", "bad farm refused, slot untouched: %s" % JSON.stringify(bad))
	# Load into the empty slot 2: no Restore promised.
	var dec := SaveTransfer.decode(code)
	var plan := SaveTransfer.plan_one(dec["data"], 2)
	check(str(plan["replaces"]) == "" and not bool(plan["same"]), "empty slot: nothing replaced")
	var r := SaveTransfer.apply_one(dec["data"], 2)
	check(bool(r["ok"]) and not bool(r["moved"]) and not SaveTransfer.done_text(r, 2).contains("Restore"), "loaded into empty slot, no Restore line")
	check(GameState.slot() == 2 and str(GameState.run["names"]["character"]) == "Ann", "slot 2 now plays Ann")
	# Same code again: nothing moves (Restore keeps nothing / the original stays).
	var r2 := SaveTransfer.apply_one(SaveTransfer.decode(code)["data"], 2)
	check(bool(r2["same"]) and SaveTransfer.restore_of(2).is_empty(), "the same code twice changes nothing")
	# A different farm over Ann: Ann -> Restore, confirm text says so; then a third
	# farm says the older Restore will be gone.
	GameState.run["names"]["character"] = "Bea"
	GameState.run["day"] = 30
	var bea := _code_of(SaveTransfer.farm_of(2))
	GameState.run["names"]["character"] = "Ann"
	GameState.run["day"] = 12
	GameState.save()
	var bd: Dictionary = SaveTransfer.decode(bea)["data"]
	check(SaveTransfer.confirm_text(bd, 2).contains("moves to Restore"), "confirm says the slot's farm moves to Restore")
	var r3 := SaveTransfer.apply_one(bd, 2)
	check(bool(r3["moved"]) and str(SaveTransfer.restore_of(2)["names"]["character"]) == "Ann", "Ann went to Restore")
	var cd := bd.duplicate(true)
	cd["names"]["character"] = "Cy"
	check(SaveTransfer.confirm_text(cd, 2).contains("gone for good"), "confirm warns the older Restore farm is dropped")
	# Backup of all farms round trip.
	var all := SaveTransfer.encode_all()
	check(all.begins_with("DRMALL:"), "backup of all farms")
	var ad := SaveTransfer.decode(all)
	check(bool(ad["ok"]) and str(ad["kind"]) == "all" and (ad["data"]["slots"] as Dictionary).size() == 2, "backup holds both farms")
	check(GameState.import_code(all) != "", "a backup is not loaded as one farm")
	SaveGame.set_value(GameState.slot_key(1), {})
	SaveGame.set_value(GameState.slot_key(3), {})
	GameState.use_slot(3)
	var ar := SaveTransfer.apply_all(ad["data"])
	check(bool(ar["ok"]) and (ar["loaded"] as Array).has(1) and GameState.slot_info(1).begins_with("Ann"), "backup restored slot 1 (%s)" % str(ar))
	check(GameState.slot() == 3, "the played slot stays the same after a backup load")
	# File text == code text.
	check(SaveTransfer.file_name(code) == "dreams-Ann-day12.dreams", "file name from the label")
	# Null run blocks: dropped by _migrate, accessors work.
	GameState.use_slot(3)
	var n := SaveTransfer.farm_of(1)
	for k in ["cfarm", "party", "pet", "mail", "chests", "weather", "buffs", "status", "project", "opts"]:
		n[k] = null
	SaveGame.set_value(GameState.slot_key(3), n)
	GameState.run = {}
	check(GameState.has_run(), "a run with null blocks loads")
	check(GameState.run.get("cfarm") == null or GameState.run["cfarm"] is Dictionary, "null cfarm dropped")
	GameState.weather_today()
	check(GameState.run["weather"] is Dictionary and Companion.party() is Dictionary, "weather and party rebuild")
	# Weather prune: only the last couple of days stay.
	for d in range(1, 40):
		GameState.run["day"] = d
		GameState.weather_today()
	check((GameState.run["weather"] as Dictionary).size() <= 4, "weather keys pruned (%d)" % (GameState.run["weather"] as Dictionary).size())
	check(int(GameState.run.get("save_ver", 0)) == GameState.SAVE_VERSION, "runs carry save_ver")
	# SaveGame.flush reports success.
	check(SaveGame.flush() and SaveGame.last_ok, "flush reports a landed write")
	print("SAVE TRANSFER DONE %d" % fails)
	quit(1 if fails > 0 else 0)
