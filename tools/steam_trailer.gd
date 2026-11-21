extends "res://tools/steam_shots.gd"
## Steam trailer capture (CONDUCT S1, P6): plays docs/steam-store/trailer_shots.json
## beat by beat under Godot's Movie Maker. Heavy (about 1 GB of MJPEG for 45 s):
## run it in CI or through tools/steam_trailer.sh, never inside check.sh.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie /tmp/trailer/raw.avi -s res://tools/steam_trailer.gd -- [beat_id ...]
## Each beat starts from a fresh scripted state (the same clean state as
## steam_shots.gd: no touch pad, goal line blank, dialogue/banners/toasts cleared),
## fades in from black over 0.3 s to hide the scene load, walks the hero from
## `from` to `to`, fires `tool` once, and holds for `seconds` (counted in frames:
## game time only). Game music is muted; tools/steam_trailer.sh lays title.ogg
## over the whole cut and adds the end card (library hero + logo).

const SPEC := "res://docs/steam-store/trailer_shots.json"
var _fade: ColorRect
var _ticks := 0
var _budget := 60 * 60 * 3  # frames; set from the beat list in _run (a script error must never record forever)


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks > _budget:
		print("steam_trailer: FAIL frame budget %d exceeded (a beat hung or the script errored)" % _budget)
		quit(1)
	return false


func _beat_shot(b: Dictionary) -> Dictionary:
	var s := b.duplicate(true)
	s["name"] = str(b["id"])
	s["cell"] = b.get("from", [])
	if s.get("builds") is bool:
		s["builds"] = FARM_BUILDS if bool(s["builds"]) else {}
	return s


func _fade_layer() -> void:
	var ly := CanvasLayer.new()
	ly.layer = 120
	ly.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.size = Vector2(4000, 4000)
	ly.add_child(_fade)
	root.add_child.call_deferred(ly)


func _run() -> void:
	var f := FileAccess.open(SPEC, FileAccess.READ)
	var spec: Dictionary = JSON.parse_string(f.get_as_text())
	var fps := int(spec.get("fps", 30))
	_budget = 0
	for b: Dictionary in spec.get("beats", []):
		_budget += int(float(b.get("seconds", 3)) * fps) + 400  # + load, settle and dialogue frames
	var only := OS.get_cmdline_user_args()
	InputSetup.ensure_actions()
	(load("res://scripts/mine.gd") as Script).set("force_seed", 7)
	Settings.set_v("touch_ui", 2)
	Settings.set_v("music_vol", 0)  # the cut gets one continuous song in the encode
	Settings.apply_audio()
	_fade_layer()
	var fails := 0
	var frames_total := 0
	var f0 := Engine.get_process_frames()
	var segs: Array = []  # [first, last] movie frame of each beat: loads between beats are cut out
	for b: Dictionary in spec.get("beats", []):
		if not only.is_empty() and not (str(b["id"]) in only):
			continue
		var s := _beat_shot(b)
		_fade.modulate.a = 1.0
		TouchControls.visible_controls = false
		Dialogue.instance(self).visible = true
		_fresh(s)
		var m := await _load(s)
		if m == null:
			print("steam_trailer: FAIL %s did not load" % s["name"]); fails += 1
			continue
		if s.has("crops"):
			_plant(m, s)
			m = await _load(s)
		if not bool(s.get("keep_foes", false)):
			_clean(m)
		else:
			for e in m.enemies:
				if is_instance_valid(e):
					e.process_mode = Node.PROCESS_MODE_DISABLED
		var z := float(s.get("zoom", 1.0))
		if z > 1.0:
			_zoom(m, z)
		elif z < 1.0:
			var cam := _camera(m)
			if cam:
				cam.position_smoothing_enabled = false
				cam.limit_left = -100000; cam.limit_top = -100000; cam.limit_right = 100000; cam.limit_bottom = 100000
				cam.zoom = Vector2(z, z)
				cam.reset_smoothing()
		if m.hud and not bool(s.get("hud", true)):
			m.hud.visible = false
		await _close_talk()
		_tidy(m)
		var a: Array = s.get("from", [])
		var t: Array = s.get("to", [])
		var n := int(float(s.get("seconds", 3)) * fps)
		var seg0 := Engine.get_process_frames() - f0
		for i in n:
			_fade.modulate.a = clampf(1.0 - float(i) / (0.3 * fps), 0.0, 1.0)
			if a.size() == 2 and t.size() == 2 and m.player:
				var p0 := m.cell_center(Vector2i(int(a[0]), int(a[1])))
				var p1 := m.cell_center(Vector2i(int(t[0]), int(t[1])))
				m.player.position = p0.lerp(p1, float(i) / maxf(1.0, n - 1.0))
			if i == int(0.4 * fps) and s.has("tool") and m.player:
				m.player.play_tool(str(s["tool"]))
			if Dialogue.instance(self).active:
				Dialogue.instance(self)._advance()
			await _frames(1)
			frames_total += 1
		segs.append([seg0, Engine.get_process_frames() - f0 - 1])
		Dialogue.instance(self).visible = true
		print("steam_trailer: beat %s (%d frames)" % [s["name"], n])
	var sp := OS.get_environment("TRAILER_SEGMENTS")
	if sp != "":
		var sf := FileAccess.open(sp, FileAccess.WRITE)
		if sf == null:
			print("steam_trailer: FAIL cannot write %s" % sp); fails += 1
		else:
			sf.store_string(JSON.stringify({"fps": fps, "segments": segs}))
			sf.close()
	print("steam_trailer: %d frames, %d failures" % [frames_total, fails])
	quit(1 if fails > 0 else 0)
