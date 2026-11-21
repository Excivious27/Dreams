extends SceneTree
## Steam store screenshots (CONDUCT S1, P6): scripted, clean 1920x1080 captures.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tools/steam_shots.gd -- docs/steam-store/screenshots [name ...]
## Each SHOTS entry is a full state (arc, scene, cell, minutes, day, weather,
## builds, crops, zoom, flags); every shot starts a fresh run. Clean state: no
## touch pad (touch_ui = never), every tool tip seen, the goal line emptied
## (a pinned blank side quest), dialogue closed right up to the capture frame,
## region banners and toasts freed, the farm's "Decorate yard" chip hidden.
## Outputs NN_name.jpg (quality 92, exactly 1920x1080; the wide view is 853 px x2.25 =
## 1919, so the last column is repeated); PNG=1 also writes NN_name.png.
## The HUD stays (Steam allows UI in screenshots). docs/steam-store/screenshots.md
## lists what each shot sells and its all-ages flag; tools/steam_shots_test.py checks the files.

const W := 1920
const H := 1080
const FARM_BUILDS := {"house": 3, "coop": 2, "barn": 2, "greenhouse": 1}
const SHOTS := [
	{"name": "01_farm_summer", "arc": "penguins", "scene": "farm", "cell": [10, 16], "minutes": 540, "day": 40, "weather": "clear", "builds": FARM_BUILDS, "crops": [[4, 17, 12, 23]], "greenhouse": true},
	{"name": "02_town_dusk", "arc": "penguins", "scene": "town", "cell": [40, 30], "minutes": 1140, "day": 8, "weather": "clear"},
	{"name": "03_community_market", "arc": "penguins", "scene": "community_farm", "cell": [], "minutes": 660, "day": 10, "weather": "clear", "cfarm_stage": 8},
	{"name": "04_gloamwood", "arc": "penguins", "scene": "gloam_lanternfall", "cell": [21, 24], "minutes": 1110, "day": 8, "weather": "clear"},
	{"name": "05_beach", "arc": "penguins", "scene": "beach", "cell": [], "minutes": 660, "day": 40, "weather": "clear", "tool": "cast"},
	{"name": "06_neon_night", "arc": "gangsters", "scene": "neon", "cell": [12, 14], "minutes": 1290, "day": 8, "weather": "clear"},
	{"name": "07_hideout_crew", "arc": "gangsters", "scene": "hideout", "cell": [20, 16], "minutes": 1080, "day": 8, "weather": "clear"},
	{"name": "08_mine_fight", "arc": "penguins", "scene": "mine", "cell": [], "minutes": 600, "day": 8, "weather": "clear", "keep_foes": true, "tool": "pickaxe"},
	{"name": "09_home_interior", "arc": "penguins", "scene": "house", "cell": [], "minutes": 1200, "day": 8, "weather": "clear", "builds": FARM_BUILDS, "zoom": 2.0},
	{"name": "10_rec_center", "arc": "penguins", "scene": "in_rec", "cell": [], "minutes": 1200, "day": 8, "weather": "clear", "zoom": 2.0},
	{"name": "11_farm_winter", "arc": "penguins", "scene": "farm", "cell": [13, 13], "minutes": 600, "day": 92, "weather": "snow", "builds": FARM_BUILDS},
]

var gt := 0.0  # game time (never the wall clock)


func _initialize() -> void:
	Campaign.bypass = true
	seed(11)
	_run.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await process_frame
		gt += root.get_process_delta_time()


func _fresh(s: Dictionary) -> void:
	GameState.new_run(str(s["arc"]), "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var r := GameState.run
	r["intro_done"] = true
	r["day"] = int(s.get("day", 8))
	r["time"] = int(s.get("minutes", 600))
	r["weather"] = {str(r["day"]): str(s.get("weather", "clear"))}
	r["flags"]["partner_scene"] = true
	for k in ToolHint.TIPS:
		r["flags"]["tip_" + str(k)] = true
	for f in ["coop_day", "barn_day", "barn2_day"]:
		r["flags"][f] = 1
	for f: String in s.get("flags", []):
		r["flags"][f] = true
	# Goal line off for store shots: a pinned, blank side quest makes next_step() "".
	r["quests"] = [{"id": "clear_meadow", "text": "x", "done": true}, {"id": "_store_shot", "text": "", "done": false}]
	r["pinned_quest"] = "_store_shot"
	r["builds"] = r.get("builds", {})
	var b: Dictionary = s.get("builds", {})
	for k in b:
		r["builds"][k] = int(b[k])
	if s.has("cfarm_stage"):
		Commons.st()["stage"] = int(s["cfarm_stage"])


func _load(s: Dictionary) -> GameMap:
	var sc := str(s["scene"])
	if sc.begins_with("in_"):
		GameMap.next_interior = sc.trim_prefix("in_")
		sc = "interior"
	GameState.run["flags"][sc + "_seen"] = true
	GameState.run["flags"][str(s["scene"]) + "_seen"] = true
	var c: Array = s.get("cell", [])
	GameMap.next_spawn = Vector2(int(c[0]) * 16 + 8, int(c[1]) * 16 + 8) if c.size() == 2 else Vector2.ZERO
	change_scene_to_file("res://scenes/%s.tscn" % sc)
	await _frames(25)
	await _close_talk()
	return current_scene as GameMap


func _close_talk() -> bool:
	var d := Dialogue.instance(self)
	for k in 60:
		if not d.active:
			return true
		d._advance()
		await _frames(2)
	return not d.active


## Ripe crops on legal soil in the given rects (and the greenhouse plot); then the farm reloads to draw them.
func _plant(m: GameMap, s: Dictionary) -> int:
	var crops: Array = []
	for cid in GameState.crops:
		var cd: Dictionary = GameState.crops[cid]
		if not bool(cd.get("tree", false)) and str(cid) in ["corn", "tomato", "sunflower", "melon", "pumpkin", "wheat", "strawberry", "cranberry"]:
			crops.append(str(cid))
	if crops.is_empty():
		return 0
	var rects: Array = s.get("crops", []).duplicate()
	if bool(s.get("greenhouse", false)):
		var g := GameState.GREENHOUSE_PLOT
		rects.append([g.position.x, g.position.y, g.end.x - 1, g.end.y - 1])
	var n := 0
	for rc: Array in rects:
		for y in range(int(rc[1]), int(rc[3]) + 1):
			for x in range(int(rc[0]), int(rc[2]) + 1):
				var c := Vector2i(x, y)
				if not m.has_method("_tillable") or not m.call("_tillable", c) or str(m.call("till_why", c)) != "":
					continue
				var cid: String = crops[(x / 2 + y / 3) % crops.size()]  # rows of one crop, a few kinds
				GameState.run["farm"]["%d,%d" % [x, y]] = {"watered": true, "crop": cid, "days": int(GameState.crops[cid].get("days", 4)) + 1}
				m._mark_cleared(c)
				n += 1
	return n


func _clean(m: GameMap) -> void:
	for e in m.enemies:
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()


func _tidy(m: GameMap) -> void:
	var d := Dialogue.instance(self)
	if not d.active:
		d.visible = false  # a closed box can still be fading (an empty panel in the frame)
	for n in m.get_children():
		if n is CanvasLayer and str(n.name).begins_with("MegaBanner"):
			n.queue_free()
	var yb: Variant = m.get("_yard_btn")
	if yb is Button and is_instance_valid(yb):
		(yb as Button).get_parent().visible = false
	if m.hud and m.hud.get("_toasts") is Node:
		for t in (m.hud.get("_toasts") as Node).get_children():
			t.queue_free()


func _camera(m: GameMap) -> Camera2D:
	if m.player == null:
		return null
	for ch in m.player.get_children():
		if ch is Camera2D:
			return ch
	return null


## Interiors on a 16:9 view: zoom in and centre on the room (old limits would pin it to the top).
func _zoom(m: GameMap, z: float) -> void:
	var cam := _camera(m)
	if cam == null:
		return
	var mw: float = (m.cols + 2 * m.pad) * GameMap.TILE
	var mh: float = (m.rows + 2 * m.pad) * GameMap.TILE
	var v := DisplayMode.view
	z = minf(z, minf(v.x / mw, v.y / mh))
	z = maxf(1.0, floorf(z * 4.0) / 4.0)
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000; cam.limit_top = -100000; cam.limit_right = 100000; cam.limit_bottom = 100000
	cam.zoom = Vector2(z, z)
	cam.offset = Vector2(mw * 0.5 - m.pad * GameMap.TILE, mh * 0.5 - m.pad * GameMap.TILE) - m.player.position
	cam.reset_smoothing()


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_size() != Vector2i(W, H):
		var o := Image.create(W, H, false, Image.FORMAT_RGB8)
		o.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size().min(Vector2i(W, H))), Vector2i.ZERO)
		for x in range(img.get_width(), W):  # repeat the last column (1919 -> 1920)
			o.blit_rect(img, Rect2i(img.get_width() - 1, 0, 1, mini(H, img.get_height())), Vector2i(x, 0))
		img = o
	if img.get_size() != Vector2i(W, H):
		push_error("steam_shots: %s is %s, not 1920x1080" % [path, img.get_size()])
		return false
	img.save_jpg(path + ".jpg", 0.92)  # committed (Steam takes JPG; PNGs are 4x the size)
	if OS.get_environment("PNG") == "1":
		img.save_png(path + ".png")
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "docs/steam-store/screenshots"
	if not out.begins_with("/"):
		out = ProjectSettings.globalize_path("res://" + out)
	var only := args.slice(1)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	(load("res://scripts/mine.gd") as Script).set("force_seed", 7)
	Settings.set_v("touch_ui", 2)
	var fails := 0
	for s: Dictionary in SHOTS:
		if not only.is_empty() and not (str(s["name"]) in only):
			continue
		TouchControls.visible_controls = false
		Dialogue.instance(self).visible = true
		_fresh(s)
		var m := await _load(s)
		if m == null:
			print("steam_shots: FAIL %s did not load" % s["name"]); fails += 1
			continue
		if s.has("crops") or bool(s.get("greenhouse", false)):
			var n := _plant(m, s)
			print("steam_shots: %s planted %d cells" % [s["name"], n])
			m = await _load(s)  # redraw with the crops and cleared debris
		if not bool(s.get("keep_foes", false)):
			_clean(m)
		else:
			var near := false
			for e in m.enemies:
				if is_instance_valid(e):
					e.process_mode = Node.PROCESS_MODE_DISABLED  # frozen mid-fight, no hits on the hero
					if not near and m.player:
						m.player.position = (e as Node2D).position + Vector2(0, 28)  # face the first foe
						near = true
		GameState.run["hp"] = int(GameState.run["max_hp"])
		GameState.run["energy"] = int(GameState.run["max_energy"])
		if m.sky and m.sky.get("weather") != null:
			m.sky.weather = str(s.get("weather", "clear"))
		if float(s.get("zoom", 1.0)) != 1.0:
			_zoom(m, float(s["zoom"]))
		await _frames(30)
		_tidy(m)
		if s.has("tool") and m.player:
			m.player.play_tool(str(s["tool"]))
			await _frames(6)
		else:
			await _frames(20)
		if not await _close_talk():  # a villager's greeting can open during the settle frames
			print("steam_shots: FAIL %s dialogue stays open" % s["name"]); fails += 1
			continue
		_tidy(m)
		await _frames(2)
		if Dialogue.instance(self).active:
			print("steam_shots: FAIL %s dialogue opened at the capture frame" % s["name"]); fails += 1
			continue
		if not await _capture("%s/%s" % [out, s["name"]]):
			fails += 1
			continue
		Dialogue.instance(self).visible = true
		print("steam_shots: wrote %s" % s["name"])
	print("steam_shots: %d failures" % fails)
	quit(1 if fails > 0 else 0)
