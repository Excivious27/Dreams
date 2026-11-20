extends RefCounted
## Unspent skill points are hard to miss: the menu's Skills tab and every skill
## tree tab with points shimmer gold with a count badge, and the open tree shows
## a big "N points to spend" banner (GameMenu._refresh / _skills_tab).

const GOLD := Color(1.0, 0.82, 0.25)


## Points free across every skill tree of this arc.
static func total_free() -> int:
	if GameState.run.is_empty():
		return 0
	var n := 0
	for sk: String in GameState.skills_data:
		if GameState.skill_in_arc(sk):
			n += usable(sk)
	return n


## Ranks still to buy in a tree (0 = every node maxed).
static func ranks_left(sk: String) -> int:
	var left := 0
	for nd: Dictionary in GameState.skills_data.get(sk, {}).get("nodes", []):
		left += maxi(0, int(nd.get("ranks", 1)) - GameState.node_rank(sk, str(nd.get("id", ""))))
	return left


## Points worth glowing about: free points, but never more than the tree can take
## (a fully bought tree stops shimmering, c8_05).
static func usable(sk: String) -> int:
	return mini(GameState.points_free(sk), ranks_left(sk))


## Add (n > 0) or remove the shimmering frame + badge on a tab button.
static func set_glow(b: Control, n: int, badge := true) -> void:
	if b == null:
		return
	var old := b.get_node_or_null("SkillGlow")
	if old:
		b.remove_child(old)
		old.queue_free()
	if n <= 0:
		return
	var holder := Control.new()
	holder.name = "SkillGlow"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(holder)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.22)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	holder.add_child(frame)
	# A bright sweep that slides across the button, like light on metal.
	var sweep := ColorRect.new()
	sweep.name = "Sweep"
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.color = Color(1, 1, 0.85, 0.55)
	sweep.size = Vector2(4, 40)
	sweep.position = Vector2(-6, 0)
	holder.clip_contents = true
	holder.add_child(sweep)
	if badge:
		var bl := Label.new()
		bl.name = "Badge"
		bl.text = str(n)
		bl.add_theme_font_size_override("font_size", 7)
		bl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bs := StyleBoxFlat.new()
		bs.bg_color = GOLD
		bs.set_corner_radius_all(5)
		bs.content_margin_left = 2
		bs.content_margin_right = 2
		bl.add_theme_stylebox_override("normal", bs)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		bl.offset_left = -11
		bl.offset_right = 0
		bl.offset_top = 0
		bl.offset_bottom = 10
		holder.add_child(bl)
	if not holder.is_inside_tree():
		return
	var tw := holder.create_tween().set_loops()
	tw.tween_property(frame, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(func(t: float) -> void:
		if is_instance_valid(sweep) and is_instance_valid(holder):
			sweep.size.y = holder.size.y
			sweep.position.x = lerpf(-6.0, holder.size.x + 6.0, t), 0.0, 1.0, 0.55)
	tw.tween_property(frame, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_interval(0.55)


## The big banner at the top of an open tree with points to spend.
static func points_banner(body: Control, n: int, tree_name: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = "PointsBanner"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.3, 0.05, 0.9)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "%d %s point%s to spend! Tap a node, then Learn." % [n, tree_name, "" if n == 1 else "s"]
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	body.add_child(pc)
	if not pc.is_inside_tree():
		return pc
	var tw := pc.create_tween().set_loops()
	tw.tween_property(pc, "modulate", Color(1.15, 1.1, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pc, "modulate", Color(1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE)
	return pc
