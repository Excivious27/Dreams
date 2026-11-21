class_name TravelScene
extends CanvasLayer
## C14 ride scene (c14_05-04): the vehicle of the link travels along its path on the
## Valley painting (or past a parallax sky/sea/road strip for world lines), ~3 s.
## First ride of a link plays through; after that B or the Skip button ends it.
## Time is frame delta accumulated while it runs (deterministic under --fixed-fps;
## never the wall clock). Pauses the game through Hud.pause, restores on close.

signal finished

const DUR := 3.0
const SKIP_RECT := Rect2(206, 440, 56, 24)

var link: Dictionary = {}
var from_sid := ""
var first := true
var t := 0.0
var done := false
var _was_paused := false
var _view: Control
var _veh: Texture2D
var _map: Texture2D
var _skip: Button


static func play(m: Node, l: Dictionary, from_station: String, first_ride: bool) -> TravelScene:
	var ts := TravelScene.new()
	ts.link = l
	ts.from_sid = from_station
	ts.first = first_ride
	m.add_child(ts)
	return ts


static func duration() -> float:
	return DUR


func can_skip() -> bool:
	return not first


func _ready() -> void:
	layer = 66
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_hold")
	_was_paused = get_tree().paused
	Hud.pause(get_tree(), "TravelScene")
	var kinds: Dictionary = TravelNet.data().get("kinds", {})
	var vn := str(kinds.get(str(link.get("kind", "")), {}).get("veh", ""))
	if str(link.get("kind", "")) == "mega":  # each keeper's own vehicle (C14: sled/caravan/airship/train/limo/ring)
		var rid := str(link.get("id", "")).trim_prefix("mega_").trim_prefix("t4_").get_slice("_", 0)
		vn = {"windward": "c14p4_veh_airship", "ironline": "c14p4_veh_night_train", "giltcity": "c14p4_veh_sedan", "gloamwood": "c14p4_veh_ring",
			"frostpeak": "c14p4_veh_sled", "sunscorch": "c14p4_veh_caravan"}.get(rid, vn)
	if not GameState.is_penguins():
		vn = {"c14p4_veh_cart": "c14p4_veh_trolley", "c14p4_veh_caravan": "c14p4_veh_sedan", "c14p4_veh_ferry": "c14p4_veh_launch"}.get(vn, vn)
	if vn != "" and Art.has(TravelNet.GROUP, vn):
		_veh = Art.tex(TravelNet.GROUP, vn)
	if Art.has("ui", "world_map") and (link.get("path", []) as Array).size() >= 2:
		_map = Art.tex("ui", "world_map")
	_view = Control.new()
	_view.size = Vector2(270, 480)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	add_child(_view)
	if can_skip():
		_skip = Button.new()
		_skip.text = "Skip"
		_skip.position = SKIP_RECT.position
		_skip.size = SKIP_RECT.size
		_skip.pressed.connect(end)
		_view.add_child(_skip)
		Hud.skin_buttons(_view)
		Hud.extra_rects.append(SKIP_RECT)


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	_view.queue_redraw()
	if can_skip() and Input.is_action_just_pressed("b"):
		end()
		return
	if t >= DUR:
		end()


func end() -> void:
	if done:
		return
	done = true
	Hud.extra_rects.erase(SKIP_RECT)
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	finished.emit()
	queue_free()


func _pt(pts: Array, f: float, org: Vector2, sz: Vector2) -> Vector2:
	var rev := str(link.get("a", "")) != from_sid and from_sid != ""
	if rev:
		f = 1.0 - f
	var segs := pts.size() - 1
	var x := clampf(f, 0.0, 1.0) * segs
	var i := mini(int(x), segs - 1)
	var a := Vector2(float(pts[i][0]), float(pts[i][1]))
	var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
	return org + a.lerp(b, x - i) * sz


func _draw_veh(p: Vector2, flip: bool) -> void:
	var bob := sin(t * 9.0) * 1.5
	if _veh:
		var fw := _veh.get_width() / 3
		var fh := _veh.get_height()
		var fr := int(t * 6.0) % 3
		var sc := minf(1.0, 64.0 / maxf(fw, fh))
		var dst := Rect2(p + Vector2(-fw * sc / 2.0, -fh * sc + bob), Vector2(fw * sc * (-1.0 if flip else 1.0), fh * sc))
		if flip:
			dst.position.x += fw * sc
		_view.draw_texture_rect_region(_veh, dst, Rect2(fr * fw, 0, fw, fh))
	else:
		_view.draw_circle(p + Vector2(0, bob - 4), 5.0, Color(1, 0.9, 0.5))


func _draw_view() -> void:
	var peng := GameState.is_penguins()
	var f := clampf(t / DUR, 0.0, 1.0)
	var pts: Array = link.get("path", [])
	if _map:
		var org := Vector2(10, 120)
		var sz := Vector2(250, 250.0 * _map.get_height() / maxf(1.0, _map.get_width()))
		_view.draw_rect(Rect2(0, 0, 270, 480), Color(0.06, 0.05, 0.04) if peng else Color(0.03, 0.03, 0.06))
		_view.draw_texture_rect(_map, Rect2(org, sz), false)
		for j in 24:
			var a := _pt(pts, j / 24.0, org, sz)
			var b := _pt(pts, (j + 0.5) / 24.0, org, sz)
			_view.draw_line(a, b, Color(1, 0.9, 0.4, 0.9) if peng else Color(1, 0.35, 0.8, 0.9), 1.5)
		var p := _pt(pts, f, org, sz)
		var q := _pt(pts, minf(1.0, f + 0.02), org, sz)
		_draw_veh(p, q.x < p.x)
	else:
		# A world line: sky (or night city), drifting clouds/lights, the ground or sea scrolling by.
		var top := Color(0.55, 0.78, 0.95) if peng else Color(0.08, 0.06, 0.16)
		var bot := Color(0.95, 0.88, 0.7) if peng else Color(0.2, 0.08, 0.25)
		for y in 48:
			_view.draw_rect(Rect2(0, y * 10, 270, 10), top.lerp(bot, y / 47.0))
		for k in 7:
			var cx := fposmod(k * 61.0 - t * (18.0 + k * 3.0), 330.0) - 30.0
			var cy := 60.0 + k * 37.0
			if peng:
				_view.draw_circle(Vector2(cx, cy), 9.0 + k % 3 * 3, Color(1, 1, 1, 0.75))
				_view.draw_circle(Vector2(cx + 10, cy + 2), 7.0, Color(1, 1, 1, 0.7))
			else:
				_view.draw_rect(Rect2(cx, cy + 200, 3, 3), Color(1, 0.3, 0.8, 0.8))
				_view.draw_rect(Rect2(cx + 30, cy + 150, 2, 2), Color(0.3, 0.9, 1.0, 0.8))
		var ground := Color(0.45, 0.62, 0.35) if peng else Color(0.1, 0.1, 0.12)
		_view.draw_rect(Rect2(0, 300, 270, 180), ground)
		for k in 14:
			var gx := fposmod(k * 23.0 - t * 90.0, 300.0) - 15.0
			_view.draw_rect(Rect2(gx, 304 + (k % 3) * 9, 10, 2), ground.darkened(0.25) if peng else Color(0.9, 0.8, 0.2, 0.6))
		_draw_veh(Vector2(135, 302), false)
	# Where you're going, and how to skip.
	var font := ThemeDB.fallback_font
	var to := TravelNet.other_end(link, from_sid if from_sid != "" else str(link.get("a", "")))
	var s := TravelNet.station(to)
	var nm := str(s.get("name", "")).trim_suffix(" ride") if str(s.get("kind", "")) == "mega" else PlaceNames.for_id(str(s.get("scene", "")))
	var line := "To %s" % nm
	_view.draw_string_outline(font, Vector2(0, 60), line, HORIZONTAL_ALIGNMENT_CENTER, 270, 12, 4, Color(0, 0, 0, 0.85))
	_view.draw_string(font, Vector2(0, 60), line, HORIZONTAL_ALIGNMENT_CENTER, 270, 12, Color(1, 0.95, 0.8))
	_view.draw_rect(Rect2(35, 80, 200, 4), Color(0, 0, 0, 0.5))
	_view.draw_rect(Rect2(35, 80, 200 * f, 4), Color(1, 0.85, 0.4) if peng else Color(1, 0.35, 0.8))
