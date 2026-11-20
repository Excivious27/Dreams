class_name QuestTracker
## The quest tracker (Tom, Guide 26 #18): the player picks the quest to follow
## from a checkbox list (Menu > Quests), and a small themed compass in the HUD's
## top-right corner points the way all game. In the mines it always points to
## the way down (the map's pointer_target / pointer_aim route). Untracked
## (nothing ticked) = the story: the goal line's own place (GoalLine.target).
##
## run["pinned_quest"] holds the tracked quest id ("" = follow the story). The
## key predates the tracker (the old "Pin to the goal line" button), so older
## saves keep their pin.

const CENTER := Vector2(257, 78)  # just under the clock box, right of the goal line
const R := 8.5
const GOAL_W := 226.0  # the goal line's width while the compass is up (keeps clear of it)


## The quest being followed ("" = the story). A finished or dropped quest lets go.
static func tracked() -> String:
	var r := GameState.run
	if r.is_empty():
		return ""
	var id := str(r.get("pinned_quest", ""))
	if id == "":
		return ""
	for q in r.get("quests", []):
		if str(q.get("id", "")) == id and not bool(q.get("done", false)):
			return id
	r["pinned_quest"] = ""
	return ""


## Tick a quest (or tick it again to go back to following the story).
static func track(id: String) -> void:
	if GameState.run.is_empty():
		return
	GameState.run["pinned_quest"] = "" if tracked() == id else id


static func is_main(id: String) -> bool:
	for mq in GameState.quests_data.get("main", []):
		if str(mq.get("id", "")) == id:
			return true
	return false


## Open quests for the checkbox list: story steps first, then townsfolk jobs.
## Each: {id, text, main, giver, ready}.
static func open_quests() -> Array:
	var out: Array = []
	var side: Array = []
	if GameState.run.is_empty():
		return out
	for q in GameState.run.get("quests", []):
		if bool(q.get("done", false)):
			continue
		var id := str(q.get("id", ""))
		var d := GameState._quest_def(id)
		var row := {"id": id, "text": str(q.get("text", "")), "main": is_main(id), "giver": str(d.get("giver", "")),
			"ready": d.has("done_when") and d["done_when"] is Dictionary and GameState._cond_ok(d["done_when"])}
		if row["main"] or row["giver"] == "":
			out.append(row)
		else:
			side.append(row)
	return out + side


## Progress of an item quest, "3/5" ("" when it isn't an item count).
static func progress(id: String) -> String:
	var dw: Variant = GameState._quest_def(id).get("done_when", {})
	if not (dw is Dictionary) or not (dw as Dictionary).has("item"):
		return ""
	var it: Array = dw["item"]
	return "%d/%d" % [mini(GameState.count(str(it[0])), int(it[1])), int(it[1])]


## Where the compass points on map m (Vector2.ZERO = nowhere to point).
static func target(m: GameMap) -> Vector2:
	if m == null or m.player == null or m.get("battle") != null:
		return Vector2.ZERO
	if m.has_method("pointer_target"):  # the mines: always the way down (or the awake keeper)
		return m.call("pointer_target")
	var id := tracked()
	if id == "" or is_main(id):
		return GoalLine.target(m)
	return _giver_target(m, str(GameState._quest_def(id).get("giver", "")))


## A townsfolk job: walk to the person who asked (they hand it in face to face).
static func _giver_target(m: GameMap, giver: String) -> Vector2:
	if giver == "":
		return Vector2.ZERO
	for ch in m.get_children():
		if ch is Npc and (ch as Npc).id == giver and (ch as Node2D).visible:
			return (ch as Node2D).position
	# Valley villagers live in town; region keepers (gate_*, mg_*) stay where they are.
	if not GameState.npcs.has(giver) or m.scene_id() == "town":
		return Vector2.ZERO
	return GoalLine.exit_toward(m, "town")


## Small words under the compass: cells to go, or the job's count when it isn't ready.
static func caption(m: GameMap, tgt: Vector2) -> String:
	var id := tracked()
	if id != "" and not is_main(id):
		var d := GameState._quest_def(id)
		if not (d.has("done_when") and GameState._cond_ok(d["done_when"])):
			return progress(id)
	if tgt == Vector2.ZERO:
		return ""
	return str(int(m.call("pointer_dist")) if m.has_method("pointer_dist") else int(m.player.position.distance_to(tgt) / 16.0))


## The compass, drawn by the Hud (outdoors, no dialogue, no battle). Returns true when drawn.
static func draw(c: CanvasItem, m: GameMap, font: Font) -> bool:
	var tgt := target(m)
	var cap := caption(m, tgt)
	if tgt == Vector2.ZERO and cap == "":
		return false
	var pen := GameState.is_penguins()
	var danger: bool = m.get("_guardian") != null
	var rim := Color(0.62, 0.86, 1.0) if pen else Color(0.95, 0.72, 0.32)
	var glow := Color(0.45, 0.95, 1.0) if pen else Color(1.0, 0.36, 0.62)
	var needle := Color(1, 0.42, 0.36) if danger else glow
	var ctr := CENTER + Vector2(DisplayMode.extra(), 0)
	# Badge: soft shadow, dark face, themed rim (ice crystal / brass), four tick marks.
	c.draw_circle(ctr + Vector2(0.6, 1.2), R + 1.6, Color(0, 0, 0, 0.35))
	c.draw_circle(ctr, R + 1.2, Color(0.07, 0.06, 0.1, 0.9))
	c.draw_arc(ctr, R, 0, TAU, 28, rim, 1.4, true)
	c.draw_arc(ctr, R - 2.4, 0, TAU, 24, Color(rim, 0.25), 0.8, true)
	for k in 4:
		var a := k * PI * 0.5
		var u := Vector2.from_angle(a)
		c.draw_line(ctr + u * (R - 1.8), ctr + u * (R - 0.4), Color(rim, 0.8), 1.0)
	if tgt != Vector2.ZERO:
		var ct := m.get_viewport().get_canvas_transform()
		var d := ct * tgt - ct * m.player.position
		if m.has_method("pointer_aim"):  # walk the route, not through walls
			var aim: Vector2 = m.call("pointer_aim")
			if aim != Vector2.ZERO and aim != tgt:
				d = ct * aim - ct * m.player.position
		if d.length() < 10.0:
			# Right here: a pulsing dot instead of a needle.
			var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
			c.draw_circle(ctr, 2.2 + p * 1.2, needle)
		else:
			var u := d.normalized()
			var o := u.orthogonal()
			c.draw_colored_polygon(PackedVector2Array([ctr + u * (R - 2.0), ctr + o * 2.6, ctr - u * 2.0, ctr - o * 2.6]), needle)
			c.draw_colored_polygon(PackedVector2Array([ctr - u * (R - 3.0), ctr + o * 1.8, ctr - o * 1.8]), Color(rim, 0.45))
			c.draw_circle(ctr, 1.1, Color(0.07, 0.06, 0.1))
	else:
		c.draw_circle(ctr, 1.6, Color(rim, 0.6))
	if cap != "":
		var tp := ctr + Vector2(-14, R + 8)
		c.draw_string_outline(font, tp, cap, HORIZONTAL_ALIGNMENT_CENTER, 28, 6, 3, Color(0, 0, 0, 0.85))
		c.draw_string(font, tp, cap, HORIZONTAL_ALIGNMENT_CENTER, 28, 6, needle if tgt != Vector2.ZERO else Color(0.95, 0.92, 0.8))
	# On screen: a small bobbing chevron over the spot itself (Stardew's quest mark).
	if tgt != Vector2.ZERO and not m.has_method("pointer_aim"):
		var sp: Vector2 = m.get_viewport().get_canvas_transform() * tgt
		var view := Rect2(10, 100, DisplayMode.view.x - 20.0, 270)
		if view.has_point(sp) and sp.distance_to(m.get_viewport().get_canvas_transform() * m.player.position) > 20.0:
			var b := sp + Vector2(0, -22 + 2.0 * sin(Time.get_ticks_msec() / 220.0))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-4.5, -4), b + Vector2(4.5, -4), b + Vector2(0, 2.5)]), Color(0, 0, 0, 0.55))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-3.4, -3.4), b + Vector2(3.4, -3.4), b + Vector2(0, 1.4)]), needle)
	return true


## A checkbox row for the Quests tab: tap to follow it (tap again: back to the story).
static func checkbox_row(text: String, checked: bool, done: bool, sub: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_constant_override("h_separation", 0)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 24)
	b.focus_mode = Control.FOCUS_NONE
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(0.32, 0.24, 0.12, 0.95) if checked else Color(0.16, 0.11, 0.07, 0.85)
	pad.border_color = Color(1, 0.86, 0.45) if checked else Color(0.36, 0.27, 0.16)
	pad.set_border_width_all(1)
	pad.set_corner_radius_all(3)
	pad.content_margin_left = 22
	pad.content_margin_right = 30 if sub != "" else 6
	pad.content_margin_top = 3
	pad.content_margin_bottom = 3
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, pad)
	b.add_theme_color_override("font_color", Color(0.72, 0.85, 0.7) if done else Color(1, 0.96, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.9))
	b.disabled = done
	b.draw.connect(func() -> void:
		var y := b.size.y * 0.5
		var box := Rect2(6, y - 5, 10, 10)
		b.draw_rect(box.grow(1), Color(0, 0, 0, 0.5))
		b.draw_rect(box, Color(0.95, 0.9, 0.78) if not done else Color(0.55, 0.7, 0.55))
		b.draw_rect(box, Color(0.25, 0.17, 0.1), false, 1.0)
		if checked or done:
			var col := Color(0.15, 0.55, 0.25) if done else Color(0.85, 0.3, 0.2)
			b.draw_polyline(PackedVector2Array([box.position + Vector2(2, 5), box.position + Vector2(4.2, 7.6), box.position + Vector2(8.4, 2.2)]), col, 1.8, true)
		if sub != "":
			var f := b.get_theme_default_font()
			b.draw_string(f, Vector2(b.size.x - 28, y + 3), sub, HORIZONTAL_ALIGNMENT_RIGHT, 24, 7, Color(1, 0.86, 0.5)))
	b.pressed.connect(cb)
	return b
