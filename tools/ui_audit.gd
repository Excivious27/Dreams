extends RefCounted
## Phone layout audit for any open screen (used by tools/phone_ui_test.gd).
## Walks every visible Control under a node and reports, in viewport pixels
## (portrait 270x480):
##  - off: a control that runs off the screen (scroll content only checked sideways)
##  - spill: a control that pokes out of its panel sideways
##  - tap: a button smaller than MIN_TAP on its short side
##  - cut: a label whose wrapped text has more lines than it shows
##  - tiny: text smaller than MIN_FONT px
## Each issue is "kind|screen|path|detail". Known, accepted cases go in ALLOW.

const VIEW := Vector2(270, 480)
const MIN_TAP := 20.0  # 20 game px = 40+ phone px at the 2x layout
const MIN_FONT := 6
## Accepted on purpose: substrings of "kind|path" (bag count badges are not text to read).
const ALLOW := []


static func audit(root: Node, screen: String) -> Array:
	var out: Array = []
	_walk(root, screen, out)
	return out


static func _rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return xf * Rect2(Vector2.ZERO, c.size)


static func _in_scroll(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


static func _panel_of(c: Node) -> Control:
	var p := c.get_parent()
	while p:
		if p is PanelContainer or p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


static func _short(c: Node) -> String:
	var s := str(c.name)
	if c is Label and (c as Label).text != "":
		s += "'" + (c as Label).text.left(24).replace("\n", " ") + "'"
	elif c is Button and (c as Button).text != "":
		s += "'" + (c as Button).text.left(24).replace("\n", " ") + "'"
	return s


static func _add(out: Array, kind: String, screen: String, c: Node, detail: String) -> void:
	var key := kind + "|" + _short(c)
	for a: String in ALLOW:
		if key.contains(a):
			return
	out.append("%s|%s|%s|%s" % [kind, screen, _short(c), detail])


static func _walk(n: Node, screen: String, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control:
		var c := n as Control
		var r := _rect(c)
		var sc := _in_scroll(c)
		if r.size.x > 0.5 and r.size.y > 0.5 and c.modulate.a > 0.05:
			var full := r.size.x >= VIEW.x - 1 and r.size.y >= VIEW.y - 1
			if not full:
				if r.position.x < -0.5 or r.end.x > VIEW.x + 0.5:
					_add(out, "off", screen, c, "x %d..%d" % [r.position.x, r.end.x])
				elif sc == null and (r.position.y < -0.5 or r.end.y > VIEW.y + 0.5):
					_add(out, "off", screen, c, "y %d..%d" % [r.position.y, r.end.y])
				var pn := _panel_of(c)
				if pn and not (pn is ScrollContainer and c == pn.get_child(0)):
					var pr := _rect(pn)
					if r.position.x < pr.position.x - 1 or r.end.x > pr.end.x + 1:
						_add(out, "spill", screen, c, "x %d..%d in %d..%d" % [r.position.x, r.end.x, pr.position.x, pr.end.x])
			if c is BaseButton and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not (c as BaseButton).disabled:
				if minf(r.size.x, r.size.y) < MIN_TAP:
					_add(out, "tap", screen, c, "%dx%d" % [r.size.x, r.size.y])
			if c is Label or c is Button:
				var fs := c.get_theme_font_size("font_size")
				var txt: String = (c as Label).text if c is Label else (c as Button).text
				if txt.strip_edges() != "" and fs < MIN_FONT:
					_add(out, "tiny", screen, c, "font %d" % fs)
			if c is Label:
				var l := c as Label
				if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.text != "":
					var vis := l.get_visible_line_count()
					if l.get_line_count() > vis and l.max_lines_visible < 0 and vis > 0:
						_add(out, "cut", screen, c, "%d of %d lines" % [vis, l.get_line_count()])
				elif l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
					var f := l.get_theme_font("font")
					var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
					if w > r.size.x + 1 and not l.text.contains("\n"):
						_add(out, "cut", screen, c, "text %d > %d" % [w, r.size.x])
	for ch in n.get_children():
		_walk(ch, screen, out)
