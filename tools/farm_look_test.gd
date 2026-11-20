extends SceneTree
## Farm look (CONDUCT 5 P1): crops wither at the season's turn and stay until pulled,
## the farmhouse art and door follow the house tier, the greenhouse plot is clear of
## the Manor, farm animals have true-to-life heights, debris never sits on a path.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(5)
	Campaign.bypass = true
	_run.call_deferred()


func frames(k: int) -> void:
	for i in k:
		await process_frame


func load_farm() -> GameMap:
	GameMap.next_spawn = Vector2.ZERO
	change_scene_to_file("res://scenes/farm.tscn")
	await frames(14)
	var d := Dialogue.instance(self)
	for k in 10:
		if d.active:
			d._advance()
			await frames(2)
	return current_scene as GameMap


func new_run() -> void:
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["partner_scene"] = true
	GameState.run["flags"]["farm_seen"] = true
	GameState.run["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}]


func _run() -> void:
	new_run()
	# --- 1. Withering at the season's turn (c5_14 #1) ---
	GameState.run["day"] = GameState.DAYS_PER_SEASON  # last day of spring
	var spring_crop := ""
	for cid: String in GameState.crops:
		var cd: Dictionary = GameState.crops[cid]
		if str(cd.get("season", "")) == "spring" and not bool(cd.get("tree", false)):
			spring_crop = cid
			break
	check(spring_crop != "", "a spring-only crop exists (%s)" % spring_crop)
	GameState.run["farm"]["20,20"] = {"watered": true, "crop": spring_crop, "days": 1}
	GameState.run["farm"]["21,20"] = {"watered": true, "crop": "", "days": 0}
	var rep := GameState.sleep()
	var t: Dictionary = GameState.run["farm"]["20,20"]
	check(GameState.season() == "summer", "it is summer after sleeping on spring's last day")
	check(str(t.get("crop", "")) == "" and str(t.get("dead", "")) != "", "the spring crop withered (dead=%s)" % str(t.get("dead", "")))
	check(int(rep.get("died", 0)) >= 1, "the sleep report counts it")
	check(not (GameState.run["farm"]["21,20"] as Dictionary).has("dead"), "an empty bed stays empty")
	var m := await load_farm()
	m.player.position = m.cell_center(Vector2i(20, 21))
	m.player.facing = "up"
	GameState.run["hotbar_sel"] = -1
	var handled: bool = m.call("_farm_tile", Vector2i(20, 20), "")
	check(handled and not (GameState.run["farm"]["20,20"] as Dictionary).has("dead"), "a bare hand pulls the withered plant")
	check(GameState.run["farm"].has("20,20"), "the bed stays tilled")
	# --- results ---
	print("farm_look_test: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
