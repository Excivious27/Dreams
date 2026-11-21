class_name AchievementScreen
## Title screen > Achievements (S1 P2, s1_04-10): the device's achievement list.
## Rows are flat focusable buttons, so a pad or Deck stick scrolls the list
## (the page's ScrollContainer follows focus); B or the last "Back" leaves.
## Icons: res://art/gen/ach/<icon>.png (unlocked) and <icon>_locked.png
## (tools/slice_achievements.py); a plain disc is drawn while art is missing.

const ICON_DIR := "res://art/gen/ach/"


static func icon(id: String, unlocked: bool) -> Texture2D:
	var a := Achievements.def(id)
	var base := ICON_DIR + str(a.get("icon", "ach_" + id))
	var p := base + ("" if unlocked else "_locked") + ".png"
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	if ResourceLoader.exists(base + ".png"):
		return load(base + ".png") as Texture2D
	return null


static func fill(page: Control, make_label: Callable, back: Button) -> void:
	page.add_child(make_label.call("Achievements", 16) as Control)
	page.add_child(make_label.call("%d of %d unlocked. Saved on this device, across every farm." % [Achievements.count_unlocked(), Achievements.total()], 8) as Control)
	var arc := str(GameState.run.get("arc", ""))
	var rows: Array = Achievements.list().duplicate()
	# Unlocked first, then the rest in catalogue order.
	var done: Array = rows.filter(func(a: Dictionary) -> bool: return Achievements.is_unlocked(str(a["id"])))
	var todo: Array = rows.filter(func(a: Dictionary) -> bool: return not Achievements.is_unlocked(str(a["id"])))
	for a: Dictionary in done + todo:
		var id := str(a["id"])
		var on := Achievements.is_unlocked(id)
		var t := Achievements.row_text(id)
		var path := ""
		if str(a.get("arc", "both")) != "both":
			path = "  (%s path)" % ("penguin" if str(a["arc"]) == "penguins" else "gangster")
		var prog := Achievements.progress_text(id)
		var b := Button.new()
		b.text = "%s%s\n%s%s" % [t[0], path, t[1], ("  " + prog) if prog != "" else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.flat = true
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_color", Color(1, 0.92, 0.7) if on else Color(0.72, 0.72, 0.78))
		b.add_theme_color_override("font_focus_color", Color(1, 1, 0.85))
		b.custom_minimum_size = Vector2(0, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tex := icon(id, on)
		if tex:
			b.icon = tex
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 24)
		b.modulate = Color(1, 1, 1, 1) if on else Color(0.85, 0.85, 0.9, 0.85)
		b.set_meta("ach_id", id)
		b.set_meta("arc_hint", arc)
		page.add_child(b)
	page.add_child(back)
