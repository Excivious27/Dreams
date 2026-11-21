class_name MegaMap
extends RefCounted
## Menu > Map tabs: "Valley" (the painted home map, drawn by GameMenu) plus one
## tab per unlocked mega region (MegaRegion). Locked regions get no tab at all.
## A region tab draws its own map: a painted ui/<map_art> if the region has one,
## else a themed drawn map (theme.style), with its areas as pins, the routes
## between them, the way back to the Valley, campaign padlocks and you.

## The tab shown: "valley" or a mega region id (set on arrival by MegaRegion).
static var tab := "valley"

const W := 228.0
const H := 214.0


## The tab row (nothing when no region is unlocked yet: no spoilers).
## Returns the tab to show (a locked/unknown one falls back to the Valley).
static func tab_row(body: Control, refresh: Callable) -> String:
	var open := MegaRegion.unlocked()
	if tab != "valley" and not open.has(tab):
		tab = "valley"
	if open.is_empty():
		return tab
	# One strip that scrolls sideways (C4 c4_02: two wrapped rows pushed the map below the fold).
	var sc := ScrollContainer.new()
	sc.name = "MapTabs"
	sc.custom_minimum_size = Vector2(W, 26)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.scroll_deadzone = 8
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	sc.add_child(row)
	var all: Array = ["valley"] + open
	var sel_btn: Button = null
	for id: String in all:
		var b := Button.new()
		b.text = "Valley" if id == "valley" else str(MegaRegion.get_r(id).get("short", id))
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(0, 22)  # finger-sized
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		b.toggle_mode = true
		b.button_pressed = id == tab
		b.modulate = Color(1, 0.9, 0.5) if id == tab else Color(0.85, 0.85, 0.85)
		b.name = "MapTab_" + id
		b.mouse_filter = Control.MOUSE_FILTER_PASS  # a sideways drag scrolls the strip
		var tid := id
		b.pressed.connect(func() -> void:
			if b.is_inside_tree():
				Music.instance(b.get_tree()).sfx("tab", "ui_tap")  # (c6_11, P5 hook)
			GameMenu.last_press = "map > %s" % tid
			tab = tid
			sel = ""
			refresh.call())
		row.add_child(b)
		if id == tab:
			sel_btn = b
	if sel_btn:
		# Keep the open tab in view.
		(func() -> void:
			if is_instance_valid(sc) and is_instance_valid(sel_btn):
				sc.ensure_control_visible(sel_btn)).call_deferred()
	return tab


## The pin picked on the open region map ("" = none): its card shows under the map.
static var sel := ""
static var _press := Vector2.INF


## The map control for a region tab. Tapping a pin picks it (its card is drawn by
## the menu under the map); a drag still scrolls the tab (the map passes it on).
static func make_map(id: String, refresh: Callable = Callable()) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(W, H)
	m.name = "MegaMap_" + id
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	# C9 P3: a focus stop for pad/keyboard navigation. While focused the d-pad walks
	# the pins (step_sel); a direction with no pin that way is left unhandled so the
	# menu's focus moves on (up from the top pin goes back to the tab strip).
	m.focus_mode = Control.FOCUS_ALL
	m.focus_entered.connect(func() -> void:
		if sel == "" and not pin_spots(id).is_empty():
			step_sel(id, Vector2.ZERO)
			if refresh.is_valid():
				refresh.call.call_deferred()
		m.queue_redraw())
	m.focus_exited.connect(m.queue_redraw)
	m.draw.connect(func() -> void:
		draw_region(m, id)
		if m.has_focus() and not TouchControls.visible_controls:
			m.draw_rect(Rect2(Vector2.ZERO, m.size).grow(-1), Color(1, 0.85, 0.3), false, 2.0))
	m.gui_input.connect(func(ev: InputEvent) -> void:
		for a: String in PAD_DIRS:
			if ev.is_action_pressed(a, true):
				if step_sel(id, PAD_DIRS[a]):
					m.accept_event()
					Music.instance(m.get_tree()).sfx("ui_tap", "pickup")
					if refresh.is_valid():
						refresh.call.call_deferred()
					else:
						m.queue_redraw()
				return
		var p := TapInput.press_pos(ev)
		if p != Vector2.INF:
			_press = p
			return
		if TapInput.is_release(ev) and _press != Vector2.INF:
			var rp: Vector2 = (ev as Variant).position
			var moved := rp.distance_to(_press) > 10.0
			_press = Vector2.INF
			if moved:
				return
			var hit := pin_at(id, rp)
			if hit != sel:
				sel = hit
				if hit != "":
					Music.instance(m.get_tree()).sfx("ui_tap", "pickup")
				if refresh.is_valid():
					refresh.call()
				else:
					m.queue_redraw())
	return m


const PAD_DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const STEP_CONE := 0.4  ## a pin counts as "that way" within ~66 deg
const STEP_SIDE := 2.0  ## sideways distance weighs this much more than forward


## C9 P3: move the picked pin to the nearest pin in a direction (ZERO = the first
## pin, or the pin you stand in). Returns whether sel changed.
static func step_sel(id: String, dir: Vector2) -> bool:
	var spots := pin_spots(id)
	if spots.is_empty():
		return false
	if dir == Vector2.ZERO or not spots.has(sel):
		var here := str(GameState.run.get("scene", ""))
		var first := here if spots.has(here) else str(spots.keys()[0])
		var changed := first != sel
		sel = first
		return changed
	var p: Vector2 = spots[sel]
	var best := ""
	var bs := INF
	for aid: String in spots:
		if aid == sel:
			continue
		var d: Vector2 = (spots[aid] as Vector2) - p
		var fwd := d.dot(dir)
		if fwd <= 1.0 or fwd < d.length() * STEP_CONE:
			continue
		var sc := fwd + absf(d.dot(Vector2(-dir.y, dir.x))) * STEP_SIDE
		if sc < bs:
			bs = sc
			best = aid
	if best == "":
		return false
	sel = best
	return true


## Pin positions on a region map (control space).
static func pin_spots(id: String) -> Dictionary:
	var inner := Rect2(0, 0, W, H).grow(-3)
	var out := {}
	for a in MegaRegion.areas(id):
		out[str(a["id"])] = inner.position + Vector2(float(a["pos"][0]), float(a["pos"][1])) * inner.size
	return out


## The area pin under p (within a finger's reach), or "".
static func pin_at(id: String, p: Vector2) -> String:
	var best := ""
	var bd := 18.0
	var spots := pin_spots(id)
	for aid: String in spots:
		var d := (spots[aid] as Vector2).distance_to(p + Vector2(0, 2))
		if d < bd:
			bd = d
			best = aid
	return best


static var _regions := {}


static func _area_data(aid: String) -> Dictionary:
	if _regions.is_empty():
		_regions = GameState.load_json("res://data/regions.json")
	var r: Variant = _regions.get(aid, {})
	return r if r is Dictionary else {}


## The card for a picked pin: [[text, size, colour], ...] (Tom C4: pins tap to a card
## with the name, whether you've been, what holds it, its danger tier, how to get
## there, and the open quests that are handed in there: "Next here:").
static func pin_card(id: String, aid: String) -> Array:
	var a: Dictionary = {}
	for x in MegaRegion.areas(id):
		if str(x["id"]) == aid:
			a = x
	if a.is_empty():
		return []
	var out: Array = []
	var here := str(GameState.run.get("scene", ""))
	var seen := MegaRegion.seen(aid) or aid == here
	var cid := Campaign.gate_of(aid)
	var held := cid != "" and not Campaign.region_open(aid)
	var nm := str(a.get("name", aid))
	if held and not seen:
		nm = str(Campaign.get_c(cid).get("region_name", nm))
	if not seen and not held:
		nm = "Somewhere unexplored"
	out.append(["▸ " + nm + ("  (you are here)" if aid == here else ""), 9, Color(1, 0.92, 0.6)])
	var bits: Array = ["Visited" if seen else "Not visited yet"]
	var tier := int(_area_data(aid).get("tier", 0))
	if tier > 0:
		bits.append("Danger " + "★".repeat(clampi(tier, 1, 5)))
	out.append(["   " + " · ".join(bits), 8, Color(0.85, 0.85, 0.8)])
	if seen and str(a.get("blurb", "")) != "":
		out.append(["   " + str(a["blurb"]), 8, Color(0.8, 0.85, 0.9)])
	if held:
		var gw: Dictionary = Campaign.gate_words(cid)
		var ls: Array = gw.get("lines", [])
		out.append(["   Held: " + str(ls[ls.size() - 1] if ls.size() > 1 else (ls[0] if not ls.is_empty() else "the way is closed.")), 8, Color(1, 0.75, 0.6)])
	var how := how_to(id, aid)
	if how != "" and aid != here:
		out.append(["   Getting there: " + how, 8, Color(0.75, 0.95, 0.75)])
	var qs: Array = QuestTracker.quests_at(aid)
	if not qs.is_empty():
		for q: Dictionary in qs.slice(0, 2):
			var pr := "ready to hand in" if bool(q["ready"]) else QuestTracker.progress(str(q["id"]))
			out.append(["   Next here: %s%s" % [str(q["text"]), (" (%s)" % pr) if pr != "" else ""], 8, Color(1, 0.9, 0.5)])
	return out


## How to reach an area: the way in from the Valley, then the walk through linked areas.
static func how_to(id: String, aid: String) -> String:
	var r := MegaRegion.get_r(id)
	for e in r.get("entries", []):
		if str(e.get("to", "")) == aid:
			return "%s from %s" % [str(e.get("how", "the road")), str(e.get("label", str(e.get("from", "")).capitalize()))]
	# Walk the links back to an entry area.
	var links: Array = r.get("links", [])
	var prev := {aid: ""}
	var queue: Array = [aid]
	var entry_to := {}
	for e in r.get("entries", []):
		entry_to[str(e.get("to", ""))] = e
	while not queue.is_empty():
		var s: String = queue.pop_front()
		if entry_to.has(s):
			var path: Array = []
			var k := s
			while k != aid and k != "":
				# C5 c5_17 #7: unvisited areas on the way stay unnamed, like their pins
				var here_now := str(GameState.run.get("scene", "")) == k
				path.append(MegaRegion.area_name(k) if MegaRegion.seen(k) or here_now else "somewhere unexplored")
				k = str(prev.get(k, ""))
			var e: Dictionary = entry_to[s]
			return "%s from %s, then walk on through %s" % [str(e.get("how", "the road")), str(e.get("label", "")), " > ".join(path)]
		for l in links:
			var o := ""
			if str(l[0]) == s:
				o = str(l[1])
			elif str(l[1]) == s:
				o = str(l[0])
			if o != "" and not prev.has(o):
				prev[o] = s
				queue.append(o)
	return ""


## "You are in: ..." line for the map tab.
static func where_line() -> String:
	var sc := str(GameState.run.get("scene", ""))
	var reg := MegaRegion.region_of(sc)
	if reg == "":
		var nm := PlaceNames.for_id(sc)  # C5: the HUD's name ("Your Farm"), not the raw scene id
		if nm == "":
			nm = sc.replace("_", " ").capitalize()
		return "You are in: %s · %s Valley" % [nm, str(GameState.run.get("names", {}).get("town", "Home"))]
	return "You are in: %s · %s" % [MegaRegion.area_name(sc), str(MegaRegion.get_r(reg)["name"])]


# ---- drawing --------------------------------------------------------------------

static func draw_region(m: Control, id: String) -> void:
	var r := MegaRegion.get_r(id)
	var font := ThemeDB.fallback_font
	var th: Dictionary = r.get("theme", {})
	var bg := MegaRegion.color(id, "bg")
	var land := MegaRegion.color(id, "land")
	var acc := MegaRegion.color(id, "accent")
	var ink := MegaRegion.color(id, "ink")
	var rect := Rect2(0, 0, W, H)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	m.draw_rect(rect, Color(0.36, 0.25, 0.14))
	var inner := rect.grow(-3)
	var art := str(r.get("map_art", ""))
	var painted := art != "" and art.contains("/") and Art.has(art.get_slice("/", 0), art.get_slice("/", 1))
	if painted:
		var tex := Art.tex(art.get_slice("/", 0), art.get_slice("/", 1))
		m.draw_texture_rect(tex, inner, false)
	else:
		m.draw_rect(inner, bg)
		_backdrop(m, str(th.get("style", "")), inner, bg, land, acc, rng)
	m.draw_rect(inner, Color(0.2, 0.12, 0.06), false, 2.0)
	# Title ribbon first, so pins near the top sit over it, never under it (c4_02 #3).
	var title := str(r.get("name", id))
	var tsz := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var tsz2 := Vector2(tsz.x + 16, 15)
	var tr := Rect2(Vector2((W - tsz.x) / 2.0 - 8, 6), tsz2)
	# Slide the ribbon to a corner when a pin sits under it (pins near the top: Moonpool, Summit...).
	var spots := pin_spots(id)
	for cand: Vector2 in [Vector2((W - tsz2.x) / 2.0, 6), Vector2(7, 6), Vector2(W - tsz2.x - 7, 6), Vector2(7, H - 22)]:
		var free := true
		for k: String in spots:
			if Rect2(cand, tsz2).grow(10).has_point(spots[k]):
				free = false
				break
		if free:
			tr = Rect2(cand, tsz2)
			break
	m.draw_rect(tr, Color(0.12, 0.08, 0.05, 0.7))
	m.draw_rect(tr, acc, false, 1.0)
	m.draw_string(font, tr.position + Vector2(8, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, acc)
	var areas := MegaRegion.areas(id)
	var pos := {}
	for a in areas:
		pos[str(a["id"])] = inner.position + Vector2(float(a["pos"][0]), float(a["pos"][1])) * inner.size
	# Routes: links between areas; with none, the hub (where you come in) to every area.
	var hub_v: Array = r.get("hub", [0.5, 0.98])
	var hub := inner.position + Vector2(float(hub_v[0]), float(hub_v[1])) * inner.size
	var route := Color(acc.r, acc.g, acc.b, 0.75)
	var links: Array = r.get("links", [])
	for l in links:
		if pos.has(str(l[0])) and pos.has(str(l[1])):
			_route(m, pos[str(l[0])], pos[str(l[1])], route, str(th.get("style", "")))
	var entries: Array = r.get("entries", [])
	var into: Array = []
	if links.is_empty():
		into = pos.keys()
	else:
		for e in entries:
			if pos.has(str(e["to"])) and not into.has(str(e["to"])):
				into.append(str(e["to"]))
	for k in into:
		m.draw_dashed_line(hub, pos[k], Color(1, 1, 1, 0.55), 1.0, 3.0)
	# The way home: a gate marker at the hub.
	if not entries.is_empty():
		var hows: Array = []
		for e in entries:
			if MegaRegion.area_in_arc(id, {"arc": str(e.get("arc", "both"))}) and not hows.has(str(e.get("how", "road"))):
				hows.append(str(e.get("how", "road")))
		var lbl := "▼ Valley · %s" % " / ".join(hows)
		m.draw_circle(hub, 4.0, Color(0.2, 0.12, 0.06))
		m.draw_circle(hub, 2.6, Color(0.75, 1.0, 0.65))
		var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		var tp := Vector2(clampf(hub.x - tw / 2.0, inner.position.x + 2, inner.end.x - tw - 2), hub.y - 6)
		_text(m, font, tp, lbl, 6, Color(1, 1, 0.9), -1)
	# Areas.
	var here := str(GameState.run.get("scene", ""))
	for a in areas:
		var aid := str(a["id"])
		var p: Vector2 = pos[aid]
		var seen := MegaRegion.seen(aid) or aid == here
		var cid := Campaign.gate_of(aid)
		var held := cid != "" and not Campaign.region_open(aid)
		if painted:
			# A painted map keeps its landmarks: a small plate under the pin, no solid blob (c4_02 #4).
			m.draw_circle(p + Vector2(0, -3), 8.5, Color(0.1, 0.07, 0.04, 0.45 if seen else 0.3))
			m.draw_arc(p + Vector2(0, -3), 8.5, 0, TAU, 20, Color(acc.r, acc.g, acc.b, 0.9 if seen else 0.5), 1.2)
		else:
			_blob(m, p, land, aid, str(th.get("style", "")), seen)
		if aid == sel:
			m.draw_arc(p + Vector2(0, -3), 11.5, 0, TAU, 24, Color(1, 0.95, 0.4), 2.0)
		if seen or (held and Campaign.why_locked(cid) == ""):
			var icon := str(a.get("icon", ""))
			if icon != "" and Art.has("ui", icon):
				var isz := Vector2(12, 14)
				m.draw_texture_rect(Art.tex("ui", icon), Rect2(p - Vector2(isz.x / 2, isz.y - 2), isz), false, Color(1, 1, 1) if seen else Color(0.6, 0.6, 0.6))
			else:
				m.draw_circle(p, 3.0, acc)
			var nm := str(a.get("name", aid))
			if held and not seen:
				nm = str(Campaign.get_c(cid).get("region_name", nm))
			_text(m, font, p + Vector2(-34, 11), nm, 7, ink, 68)
		else:
			var qc := Color(1, 1, 1, 0.75) if painted else Color(ink.r, ink.g, ink.b, 0.7)
			_text(m, font, p + Vector2(-10, 1), "?", 10, qc, 20)
		if held:
			_lock(m, p + Vector2(7, -9))
	# You.
	if pos.has(here):
		var p: Vector2 = pos[here] + Vector2(0, -14)
		m.draw_circle(p, 3.2, Color(1, 0.2, 0.2))
		m.draw_arc(p, 4.6, 0, TAU, 16, Color.WHITE, 1.0)
static func _text(m: Control, font: Font, p: Vector2, s: String, size: int, col: Color, width: float) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var dark := col.get_luminance() > 0.5
	s = Money.t(s)  # drawn text skips the cash Translation
	m.draw_string_outline(font, p, s, align, width, size, 3, Color(0, 0, 0, 0.85) if dark else Color(1, 0.97, 0.88, 0.9))
	m.draw_string(font, p, s, align, width, size, col)


static func _lock(m: Control, c: Vector2) -> void:
	m.draw_arc(c + Vector2(0, -2), 2.2, PI, TAU, 8, Color(0.15, 0.1, 0.05), 1.6)
	m.draw_rect(Rect2(c + Vector2(-3.5, -1.5), Vector2(7, 5.5)), Color(0.15, 0.1, 0.05))
	m.draw_rect(Rect2(c + Vector2(-2.5, -0.5), Vector2(5, 3.5)), Color(0.95, 0.75, 0.3))


static func _route(m: Control, a: Vector2, b: Vector2, col: Color, style: String) -> void:
	if style in ["city", "chrome"]:
		# Streets: an L-shaped avenue.
		var mid := Vector2(b.x, a.y)
		m.draw_polyline(PackedVector2Array([a, mid, b]), Color(0, 0, 0, 0.5), 5.0)
		m.draw_polyline(PackedVector2Array([a, mid, b]), col, 2.0)
	elif style in ["space", "sky", "sea", "deep"]:
		# Flight paths / sea lanes: a gentle dashed curve.
		var pts := PackedVector2Array()
		var n := (a - b).normalized().orthogonal() * a.distance_to(b) * 0.18
		for i in 17:
			var t := i / 16.0
			pts.append(a.lerp(b, t) + n * sin(t * PI))
		for i in range(0, 16, 2):
			m.draw_line(pts[i], pts[i + 1], col, 1.5)
	else:
		m.draw_line(a, b, Color(0, 0, 0, 0.45), 4.0)
		m.draw_line(a, b, col, 2.0)


## The land under a pin (island, planet, plaza...), drawn in the region's land colour.
static func _blob(m: Control, p: Vector2, land: Color, aid: String, style: String, seen: bool) -> void:
	var lc := land if seen else land.darkened(0.35)
	var r0 := 13.0 + float(abs(hash(aid)) % 5)
	var edge := lc.darkened(0.45)
	if style in ["city", "chrome", "clockwork"]:
		# A district block: a square plaza with a kerb.
		var b := Rect2(p - Vector2(r0, r0 * 0.8), Vector2(r0 * 2, r0 * 1.6))
		m.draw_rect(b.grow(1.5), edge)
		m.draw_rect(b, lc)
		m.draw_rect(Rect2(b.position + Vector2(2, 2), Vector2(b.size.x - 4, 3)), Color(1, 1, 1, 0.12))
		return
	if style == "space":
		# A little world: shaded disc, craters, a rim of light.
		m.draw_circle(p, r0 + 1.5, edge)
		m.draw_circle(p, r0, lc)
		m.draw_circle(p + Vector2(r0 * 0.25, r0 * 0.25), r0 * 0.75, lc.darkened(0.12))
		for i in 3:
			var ang := float(abs(hash(aid + "c" + str(i))) % 628) / 100.0
			m.draw_circle(p + Vector2(cos(ang), sin(ang)) * r0 * 0.5, r0 * 0.14, lc.darkened(0.25))
		m.draw_arc(p, r0 - 1, PI * 1.05, PI * 1.6, 8, Color(1, 1, 1, 0.35), 1.5)
		return
	var parts: Array = []
	for i in 4:
		var ang := float(abs(hash(aid + str(i))) % 628) / 100.0
		parts.append([p + Vector2(cos(ang), sin(ang)) * r0 * 0.45, r0 * (0.55 + 0.1 * i)])
	if style in ["sea", "deep", "sky"]:
		# Shallows / cloud bank around the island.
		for q in parts:
			m.draw_circle(q[0], float(q[1]) + 6.0, Color(1, 1, 1, 0.12))
	for q in parts:
		m.draw_circle(q[0], float(q[1]) + 1.5, edge)
	for q in parts:
		m.draw_circle(q[0], float(q[1]), lc)
	m.draw_circle(p + Vector2(-r0 * 0.25, -r0 * 0.3), r0 * 0.35, Color(1, 1, 1, 0.12))


static func _backdrop(m: Control, style: String, r: Rect2, bg: Color, land: Color, acc: Color, rng: RandomNumberGenerator) -> void:
	match style:
		"space":
			for i in 6:
				m.draw_circle(r.position + Vector2(rng.randf(), rng.randf()) * r.size, rng.randf_range(20, 46), Color(acc.r, acc.g, acc.b, 0.06))
			for i in 90:
				var s := rng.randf()
				m.draw_circle(r.position + Vector2(rng.randf(), rng.randf()) * r.size, 0.5 + s * s * 1.3, Color(1, 1, 1, 0.4 + 0.6 * s))
			var pc := r.position + Vector2(r.size.x * 0.12, r.size.y * 0.12)
			m.draw_circle(pc, 18, Color(0.85, 0.45, 0.35, 0.85))
			m.draw_arc(pc, 27, PI * 0.9, PI * 2.1, 24, Color(1, 0.85, 0.6, 0.7), 2.0)
		"sea", "deep":
			for i in 70:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				m.draw_arc(p, 3.0, PI * 1.1, PI * 1.9, 5, Color(1, 1, 1, 0.22 if style == "sea" else 0.12), 1.0)
			if style == "deep":
				for i in 26:
					m.draw_arc(r.position + Vector2(rng.randf(), rng.randf()) * r.size, rng.randf_range(1, 3), 0, TAU, 8, Color(acc.r, acc.g, acc.b, 0.35), 1.0)
				for i in 10:
					var x := r.position.x + rng.randf() * r.size.x
					var pts := PackedVector2Array()
					for k in 8:
						pts.append(Vector2(x + sin(k * 0.9 + i) * 3.0, r.end.y - k * 7.0))
					m.draw_polyline(pts, Color(0.2, 0.55, 0.3, 0.7), 2.0)
		"city", "chrome":
			var step := 22.0
			var y := r.position.y + 4
			while y < r.end.y:
				var x := r.position.x + 4
				while x < r.end.x:
					var bh := rng.randf_range(10, 17)
					m.draw_rect(Rect2(x, y, 17, bh), bg.lightened(0.08 + rng.randf() * 0.06))
					if rng.randf() < 0.35:
						m.draw_rect(Rect2(x + rng.randf_range(2, 12), y + rng.randf_range(2, bh - 3), 2, 2), Color(acc.r, acc.g, acc.b, 0.8))
					x += step
				y += step
		"cave":
			for i in 14:
				var x := r.position.x + rng.randf() * r.size.x
				var hh := rng.randf_range(8, 22)
				m.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, r.position.y), Vector2(x + 5, r.position.y), Vector2(x, r.position.y + hh)]), bg.lightened(0.12))
				m.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, r.end.y), Vector2(x + 6, r.end.y), Vector2(x + 1, r.end.y - hh)]), bg.lightened(0.1))
			for i in 18:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				var s := rng.randf_range(2, 5)
				m.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 0.5), p + Vector2(-s * 0.6, 0)]), Color(acc.r, acc.g, acc.b, 0.55))
		"sky":
			for i in 16:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				for k in 4:
					m.draw_circle(p + Vector2(k * 7 - 10, sin(k * 1.7) * 3), rng.randf_range(6, 10), Color(1, 1, 1, 0.35))
		"ice":
			for i in 22:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				m.draw_circle(p, rng.randf_range(5, 14), Color(1, 1, 1, 0.35))
			for i in 8:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				m.draw_polyline(PackedVector2Array([p, p + Vector2(8, 5), p + Vector2(13, 2), p + Vector2(20, 8)]), Color(0.4, 0.55, 0.75, 0.6), 1.0)
			for i in 3:
				var y := r.position.y + 10 + i * 9
				m.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y + 6), Color(acc.r, acc.g, acc.b, 0.25), 4.0)
		"desert":
			for i in 30:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				m.draw_arc(p, rng.randf_range(8, 18), PI * 1.15, PI * 1.85, 10, bg.darkened(0.15), 1.5)
		"clockwork":
			for i in 9:
				var p := r.position + Vector2(rng.randf(), rng.randf()) * r.size
				var rr := rng.randf_range(8, 20)
				var gc := Color(land.r, land.g, land.b, 0.25)
				m.draw_arc(p, rr, 0, TAU, 24, gc, 3.0)
				for k in 8:
					var an := k * TAU / 8.0
					m.draw_line(p + Vector2(cos(an), sin(an)) * rr, p + Vector2(cos(an), sin(an)) * (rr + 4), gc, 3.0)
		_:
			pass


# ---- the Valley tab ---------------------------------------------------------------

## Gate badges on the Valley's painted map: where each unlocked region is entered.
## `pins` maps a Valley scene to its spot on the painting (0..1); `org`/`sz` place it.
static func valley_gates(m: Control, font: Font, pins: Dictionary, org: Vector2, sz: Vector2) -> void:
	var done := {}
	for id: String in MegaRegion.unlocked():
		var r := MegaRegion.get_r(id)
		for e in r.get("entries", []):
			var from := str(e["from"])
			if not pins.has(from) or done.has(from + id) or MegaRegion.region_of(from) != "":
				continue
			done[from + id] = true
			var n := 0
			for k in done:
				if str(k).begins_with(from):
					n += 1
			var p: Vector2 = org + (pins[from] as Vector2) * sz + Vector2(9, -14 + (n - 1) * 9)
			var acc := MegaRegion.color(id, "accent")
			m.draw_circle(p, 3.5, Color(0.12, 0.08, 0.05))
			m.draw_circle(p, 2.5, acc)
			var s := str(r.get("short", id))
			# Near the map's right edge the name goes on the left of the dot, inside the art.
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
			var tp := p + Vector2(5, 2)
			if tp.x + tw > org.x + sz.x - 2:
				tp = p + Vector2(-5 - tw, 2)
			m.draw_string_outline(font, tp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, DisplayMode.df(6), 3, Color(0.1, 0.06, 0.03, 0.9))
			m.draw_string(font, tp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, DisplayMode.df(6), acc.lightened(0.3))
			break
