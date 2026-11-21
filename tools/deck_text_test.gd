extends "res://tools/phone_ui_test.gd"
## S1 P3 (s1_07-02): Steam Deck text check. Replays phone_ui_test's whole screen
## walk (title, HUD, dialogue, every menu tab, chest, craft, arcade, bowling,
## campaign, Rec Center, both arcs) as on a Deck at 1280x800 (DisplayMode
## deck_force + test_size: the 480-tall view scales 1.667x there) and fails on
## any visible Control text whose cap height is under Valve's 9 px
## (font_size * canvas scale * 800/480 * 0.714), plus every phone audit issue
## (raising fonts must not cut or spill text). Drawn text (draw_string) goes
## through DisplayMode.df and is covered by tools/deck_font_scan.py.
##   godot --headless --path . -s res://tools/deck_text_test.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tools/deck_text_test.gd -- /tmp/deck  (also screenshots)
const DECK_H := 800.0
var small := 0
var worst := 99.0


func _initialize() -> void:
	# DECK_NOCLAMP=1: measure without the runtime clamp (shows the "before" count).
	DisplayMode.deck_force = 0 if OS.get_environment("DECK_NOCLAMP") == "1" else 1
	DisplayMode.test_size = Vector2i(1280, 800)
	super._initialize()


func _test_name() -> String:
	if small == 0 and worst < 99.0:
		print("deck_text_test: smallest Control text cap %.1f px at 1280x800" % worst)
	return "deck_text_test"


## Phone tap-size issues are phone_ui_test's job (the Deck is pad-driven and
## 17 logical px is 28 screen px there); every other audit kind still fails.
func _check(name: String, node: Node = null) -> void:
	var before := issues.size()
	await super._check(name, node)
	var kept: Array = issues.slice(0, before)
	for i in range(before, issues.size()):
		if not str(issues[i]).begins_with("tap|"):
			kept.append(issues[i])
	issues = kept
	_deck_walk(node if node else root, arc.left(1) + "_" + name)


func _cap(c: Control, fs: int) -> float:
	var sc := c.get_global_transform_with_canvas().get_scale().y
	return float(fs) * absf(sc) * (DECK_H / DisplayMode.BASE.y) * DisplayMode.CAP_RATIO


func _deck_walk(n: Node, screen: String) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).is_visible_in_tree():
			continue
		if ch is Control:
			var c := ch as Control
			var txt := ""
			var fs := 0
			if c is RichTextLabel:
				txt = (c as RichTextLabel).get_parsed_text()
				fs = c.get_theme_font_size("normal_font_size")
			elif c is Label:
				txt = (c as Label).text
				fs = c.get_theme_font_size("font_size")
			elif c is Button:
				txt = (c as Button).text
				fs = c.get_theme_font_size("font_size")
			elif c is LineEdit:
				txt = (c as LineEdit).text + (c as LineEdit).placeholder_text
				fs = c.get_theme_font_size("font_size")
			if txt.strip_edges() != "" and fs > 0:
				var cap := _cap(c, fs)
				worst = minf(worst, cap)
				if cap < DisplayMode.DECK_CAP_PX - 0.01:
					small += 1
					var msg := "%s: deck_small '%s' fs %d cap %.1f px" % [screen, txt.left(24).replace("\n", " "), fs, cap]
					print("ISSUE ", msg)
					issues.append(msg)
		_deck_walk(ch, screen)
