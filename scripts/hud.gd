class_name Hud
extends CanvasLayer
## Stardew-style HUD for a portrait phone: hearts top-left, clock box top-right,
## a 12-slot toolbar under them, a vertical energy bar on the right, toasts, and
## the fade used for scene changes and sleep.

const TOOLBAR_Y := 34.0
const SLOT := 20.0
const TOOLBAR_X := 15.0
const TOOLBAR_BOTTOM := 70.0
## Inside buildings the HUD block sits just above the touch controls so it never
## covers the room (the whole block is drawn shifted by this much).
const INTERIOR_SHIFT := 280.0
static var y_offset := 0.0


## Other on-screen buttons that should get taps instead of the world (battle RALLY...).
static var extra_rects: Array = []
## Set by full-screen panels while open; touch buttons ignore taps inside it.
static var modal_rect := Rect2()
## A paused full-screen UI that reads directions (HackGame) sets this while open,
## so the touch stick still works under the pause.
static var stick_ok := false


static func hud_rect_blocks(p: Vector2) -> bool:
	for r: Rect2 in extra_rects:
		if r.has_point(DisplayMode.ui(p)):  # registered by centred layers (column coords)
			return true
	return p.y >= y_offset and p.y < y_offset + TOOLBAR_BOTTOM

var _canvas: Control
var _toasts: VBoxContainer
var _fade: ColorRect
var _hint := ""
var _boss_on := false  # the boss bar is up: toasts start under it
var _font: Font


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(6, 76)
	_toasts.size = Vector2(258, 100)
	_toasts.add_theme_constant_override("separation", 1)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Toasts live on their own top layer so crafting, the menu and other
	# full-screen panels never hide them.
	var top := CanvasLayer.new()
	top.layer = 90
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	top.add_child(_toasts)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false  # an invisible full-screen rect still costs a blended full-screen pass every frame
	add_child(_fade)
	_show_clinic_note.call_deferred()


## Waking in the clinic after passing out (GameMap.player_down): say what happened and the bill.
func _show_clinic_note() -> void:
	if GameState.run.is_empty():
		return
	var note := str(GameState.run.get("flags", {}).get("clinic_note", ""))
	var m := get_parent() as GameMap
	if note == "" or m == null or m.scene_id() != "interior":
		return
	GameState.run["flags"].erase("clinic_note")
	await get_tree().create_timer(0.6).timeout
	# Let the room's own greeting finish first.
	var dl := Dialogue.instance(get_tree())
	for i in 600:
		if not dl.active:
			break
		await get_tree().process_frame
	if not is_instance_valid(m) or m.player == null:
		return
	m.player.frozen = true
	m.player.facing = "down"
	Music.instance(get_tree()).sfx("heal")
	var kept := SleepReport.take_kept()  # a pass-out night: what sold, grew, arrived
	await m.say([{"text": note}, {"text": "Rest up, eat something, and don't push past empty. Exhausted (a red, flashing bar) means it's time to head home."}] + kept)
	if is_instance_valid(m) and m.player:
		m.player.frozen = false
		if not kept.is_empty():
			Story.on_morning(m)


## The region (or building) you're in, small, under the hearts' row and left of
## the clock box; it stays up for as long as you're there (PlaceNames).
var place_name := ""
var _place_done := false


func _draw_place(c: Control) -> void:
	if not _place_done:
		_place_done = true
		place_name = PlaceNames.of(get_parent() as GameMap)
	if place_name == "":
		return
	var fs := 8
	var maxw := 72.0
	while fs > 6 and _font.get_string_size(place_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 1
	var w := minf(maxw, _font.get_string_size(place_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var p := Vector2(162.0 - w, 23.0)
	c.draw_string_outline(_font, p, place_name, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, 3, Color(0.05, 0.03, 0.02, 0.85))
	c.draw_string(_font, p, place_name, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, Color(1.0, 0.95, 0.78))


func set_hint(text: String) -> void:
	# The phone has no A/B buttons: name the ones it has.
	if TouchControls.visible_controls:
		text = text.replace("A: ", "USE: ").replace("B: ", "CHECK: ")
	if text != _hint:
		_hint = text
		if _canvas:
			_canvas.queue_redraw()


var _redraw_t := 0.0
var _sig := ""
var _was_paused := false


func _process(delta: float) -> void:
	if GameState.run.is_empty():
		return
	_place_toasts()
	if GameState.overflow_note != "":
		toast(GameState.overflow_note, Color(1, 0.8, 0.5))
		Music.instance(get_tree()).sfx("thud", "nope")
		GameState.overflow_note = ""
	var sc := get_tree().current_scene
	var want := INTERIOR_SHIFT if sc is GameMap and (sc as GameMap).scene_id() in ["house", "interior"] else 0.0
	if want != y_offset:
		y_offset = want
		_canvas.queue_redraw()
	_pause_watch(sc)
	if get_tree().paused:
		# Dialogue and menus pause the tree: the HUD only changes when a menu equips
		# or spends something, so 10 Hz (it redrew every frame of every dialogue).
		_redraw_t += delta
		if _redraw_t >= 0.1 or not _was_paused:
			_redraw_t = 0.0
			_canvas.queue_redraw()
		_was_paused = true
		return
	_was_paused = false
	# Keyboard: number keys pick a toolbar slot (1-9, 0, -, =).
	for i in 12:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			GameState.select_slot(i)
	if Input.is_action_just_pressed("cycle_tool") and not Dialogue.input_blocked():
		GameState.select_slot((int(GameState.run["slot"]) + 1) % 12)
	ToolHint.first_pick(self)  # first time each tool is in hand: one line on what it does
	# Redraw when what's shown changes, and at 10 Hz for the rest (boss bar, buffs, pointer).
	var r := GameState.run
	var sig := "%d|%d|%d|%d|%d|%d|%s|%s" % [int(r["hp"]), int(r["energy"]), int(r.get("mana", 0)), int(r["crystals"]), int(r["slot"]), int(r["time"]), str(r["toolbar"][int(r["slot"])]), Dialogue.instance(get_tree()).active]
	_redraw_t += delta
	if sig != _sig or _redraw_t >= 0.1:
		_sig = sig
		_redraw_t = 0.0
		_canvas.queue_redraw()


var _orphan_pause := 0


## Softlock guard: every pauser shows something (a dialogue, the menu, or a
## full-screen UI that sets `modal_rect`). A pause left behind with none of them
## (a screen that restored a pause its opener had already dropped) would freeze
## the game for good with nothing to press, so it is let go after a moment.
## True while something still needs the game paused: a dialogue, an open menu, or a
## full-screen UI other than `except` (screens call this as they close, so a stale
## "was paused" never leaves the game frozen with nothing on screen).
static func keep_paused(tree: SceneTree, except: Node = null) -> bool:
	if tree == null:
		return false
	var d := Dialogue.instance(tree)
	if d != except and d.active:
		return true
	var sc := tree.current_scene
	if sc == null:
		return false
	for n in sc.get_children():
		if n == except:
			continue
		if n is GameMenu and (n as GameMenu)._open:
			return true
		if n is ChestScreen or n is CraftScreen or n is CampaignScreen or n is ArcadeGame \
				or n is HackGame or n is PrizeScreen or n is Bowling or n is Epilogue:
			if not n.is_queued_for_deletion():
				return true
	return false


func _pause_watch(sc: Node) -> void:
	if not get_tree().paused or not (sc is GameMap) or (sc as GameMap)._changing:
		_orphan_pause = 0
		return
	if Dialogue.instance(get_tree()).active or modal_rect.size != Vector2.ZERO:
		_orphan_pause = 0
		return
	for n in sc.get_children():
		if n is GameMenu and (n as GameMenu)._open:
			_orphan_pause = 0
			return
	_orphan_pause += 1
	if _orphan_pause >= 20:
		_orphan_pause = 0
		push_warning("Hud: the game was paused with nothing on screen; resuming")
		get_tree().paused = false


## Toasts: under the goal line outdoors, above the HUD block indoors, above the dialogue box while one is open.
func _place_toasts() -> void:
	var y := (108.0 if _boss_on else 89.0) if y_offset == 0.0 else 199.0  # under the goal (and the boss bar)
	if not is_inside_tree():
		return
	var sc := get_tree().current_scene
	# The campaign board has its own message line: toasts wait under it, unseen.
	var board := false
	if sc:
		for n in sc.get_children():
			if n is CampaignScreen:
				board = true
				break
	# A boss intro card holds the toasts (paused, unseen) until it slides away;
	# a region name card pushes them under itself.
	var hold := board or not get_tree().get_nodes_in_group("toast_hold").is_empty()
	_toasts.visible = not hold
	_hold_toasts(hold)
	for n in get_tree().get_nodes_in_group("toast_under"):
		for cc in n.get_children():
			if cc is Control and (cc as Control).visible:
				y = maxf(y, (cc as Control).position.y + (cc as Control).size.y + 3.0)
	if sc and sc.get("battle") != null and y_offset == 0.0:
		y = 178.0 if _boss_on else 168.0  # under the battle bar (tickets, objective, RALLY)
		var bt0: Variant = sc.get("battle")
		if is_instance_valid(bt0) and bt0 is Battle and (bt0 as Battle).drill != null:
			y = 214.0  # under the training card
	var d := Dialogue.instance(get_tree())
	if d.active:
		var h := 0.0
		for c in _toasts.get_children():
			h += (c as Control).size.y + 1.0
		y = maxf((4.0 if y_offset > 0.0 else TOOLBAR_Y + SLOT + 8.0), minf(y, d.panel_top() - h - 4.0))  # indoors the toolbar isn't at the top
	_toasts.position.y = y
	# The pup command strip runs down one screen edge: a stack that reaches it
	# steps in beside the buttons instead of sitting over them.
	# The energy bar (outdoors, other edge, from y 186) gets the same room.
	var hh := 0.0
	for c in _toasts.get_children():
		hh += (c as Control).size.y + 1.0
	var inset := _pup_strip_on(sc) and y + hh > TouchControls.PUP_Y0 - TouchControls.PUP_R - 6.0
	var bar := y_offset == 0.0 and not d.active and y + hh > 184.0
	var w := TOAST_W - (PUP_INSET if inset else 0.0) - (BAR_INSET if bar else 0.0)
	var lh := Settings.left_handed()
	_toasts.position.x = 6.0 + ((PUP_INSET if inset else 0.0) if not lh else (BAR_INSET if bar else 0.0))
	if w != _toast_w:
		_toast_w = w
		_toasts.size.x = w
		for c in _toasts.get_children():
			if c is Label:
				(c as Label).custom_minimum_size.x = _fit_w((c as Label).text)


const TOAST_W := 258.0
const PUP_INSET := 26.0  # the strip: centre 15, radius 11, labels to x 30
const BAR_INSET := 22.0  # the energy bar frame: x 250-270
var _toast_w := TOAST_W


func _fit_w(text: String) -> float:
	return minf(_toast_w, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0)


## The pup strip is drawn (TouchControls): pup with you outdoors, pad shown, game running.
func _pup_strip_on(sc: Node) -> bool:
	if not TouchControls.visible_controls or get_tree().paused or y_offset > 0.0 or not (sc is GameMap):
		return false
	var pt: Variant = (sc as GameMap).pet
	return pt != null and is_instance_valid(pt)


## Toasts wait while a card holds them: their fade tweens pause, then pick up again.
func _hold_toasts(hold: bool) -> void:
	for c in _toasts.get_children():
		var tw: Variant = c.get_meta("tw") if c.has_meta("tw") else null
		if tw is Tween and (tw as Tween).is_valid():
			if hold and (tw as Tween).is_running():
				(tw as Tween).pause()
			elif not hold and not (tw as Tween).is_running():
				(tw as Tween).play()


func _input(event: InputEvent) -> void:
	# Menus, dialogue and shops sit on top: their taps are theirs.
	if GameState.run.is_empty() or get_tree().paused or Dialogue.instance(get_tree()).active:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var p: Vector2 = (event as InputEventScreenTouch).position
		if p.y >= y_offset + TOOLBAR_Y - 2 and p.y <= y_offset + TOOLBAR_Y + SLOT + 2 and p.x >= TOOLBAR_X and p.x < TOOLBAR_X + 12 * SLOT:
			GameState.select_slot(int((p.x - TOOLBAR_X) / SLOT))
			Music.instance(get_tree()).sfx("ui_tap", "plant")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
			var p := mb.position
			if p.y >= y_offset + TOOLBAR_Y - 2 and p.y <= y_offset + TOOLBAR_Y + SLOT + 2 and p.x >= TOOLBAR_X and p.x < TOOLBAR_X + 12 * SLOT:
				GameState.select_slot(int((p.x - TOOLBAR_X) / SLOT))
				get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameState.select_slot((int(GameState.run["slot"]) + 1) % 12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameState.select_slot((int(GameState.run["slot"]) + 11) % 12)


## Mana matters once a spell is known or the partner casts a Gift with it.
func _shows_mana() -> bool:
	if GameState.skill_level("magic") > 1 or not Spells.known().is_empty():
		return true
	return str(Companion.defs().get(Companion.active_id(), {}).get("ability", "")).begins_with("gift:")


func _draw_hud() -> void:
	var r := GameState.run
	if r.is_empty():
		return
	var c := _canvas
	if y_offset > 0.0 and Dialogue.instance(get_tree()).active:
		return  # indoors the dialogue box opens over the HUD block: don't show it through the box
	c.draw_set_transform(Vector2(0, y_offset))
	# Hearts
	# Hearts: one per 20 HP; the last heart drains as a partial fill.
	var hp := int(r["hp"])
	var max_hp := int(r["max_hp"])
	var hearts := int(ceil(max_hp / float(GameState.HEART_HP)))
	var per := float(GameState.HEART_HP)
	if hearts > 10:  # big health pools: ten hearts, each worth a tenth
		hearts = 10
		per = max_hp / 10.0
	var heart_full := Art.tex("ui", "heart2_full") if Art.has("ui", "heart2_full") else Art.tex("ui", "heart_full")
	var heart_empty := Art.tex("ui", "heart2_empty") if Art.has("ui", "heart2_empty") else Art.tex("ui", "heart_empty")
	# Empty hearts, then the fills (each fill sits inside its own heart): two batches, not ten.
	for pass_i in (2 if heart_full and heart_empty else 1):
		for i in hearts:
			var p := Vector2(6 + i * 11, 4)
			var f := clampf((hp - i * per) / per, 0.0, 1.0)
			if heart_full and heart_empty:
				if pass_i == 0:
					c.draw_texture_rect(heart_empty, Rect2(p, Vector2(10, 10)), false)
				elif f > 0.0:
					c.draw_texture_rect_region(heart_full, Rect2(p + Vector2(0, 10 * (1.0 - f)), Vector2(10, 10 * f)), Rect2(0, heart_full.get_height() * (1.0 - f), heart_full.get_width(), heart_full.get_height() * f))
			else:
				c.draw_circle(p + Vector2(5, 5), 4.0, Color("e8484a") if f >= 1.0 else Color(0, 0, 0, 0.4))
	var hp_txt := "%d/%d" % [hp, max_hp]
	c.draw_string_outline(_font, Vector2(6 + hearts * 11 + 2, 13), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, 60, 7, 3, Color(0, 0, 0, 0.7))
	c.draw_string(_font, Vector2(6 + hearts * 11 + 2, 13), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, 60, 7, Color(1, 0.95, 0.9))
	# Mana (small blue bar under the hearts), only once you can cast (a spell, or a partner's Gift).
	if int(r.get("max_mana", 0)) > 0 and _shows_mana():
		var mb := Rect2(6, 16, 50, 4)
		# Art names are swapped: bar_h_purple is the blue one, bar_h_blue is green.
		var mana_bar := "bar_h_purple" if Art.has("ui", "bar_h_purple") else "bar_h_blue"
		if Art.has("ui", "bar_h_empty") and Art.has("ui", mana_bar):
			_hbar(c, Rect2(4, 15, 54, 7), GameState.vital("mana"), mana_bar)
		else:
			c.draw_rect(mb.grow(1), Color(0.1, 0.07, 0.04, 0.8))
			c.draw_rect(Rect2(mb.position, Vector2(mb.size.x * GameState.vital("mana"), mb.size.y)), Color("5aa8f0"))
		var mana_txt := "%d/%d" % [int(r.get("mana", 0)), int(r.get("max_mana", 0))]
		c.draw_string_outline(_font, Vector2(mb.end.x + 3, mb.end.y), mana_txt, HORIZONTAL_ALIGNMENT_LEFT, 50, 7, 3, Color(0, 0, 0, 0.7))
		c.draw_string(_font, Vector2(mb.end.x + 3, mb.end.y), mana_txt, HORIZONTAL_ALIGNMENT_LEFT, 50, 7, Color(0.8, 0.9, 1.0))
	# Active buffs (Prompts 10 icons) under the hearts.
	var bx := 6.0
	var buffs: Dictionary = r.get("buffs", {})
	for k in buffs:
		if GameState.buff(str(k)) <= 0.0:
			continue
		var bi := "buff2_" + str(k)
		if Art.has("ui", bi):
			c.draw_texture_rect(Art.tex("ui", bi), Rect2(bx, 24, 9, 9), false)
			bx += 11
	for k in r.get("status", {}):
		var sd := GameState.status_def(str(k))
		var si := str(sd.get("icon", ""))
		if si != "" and Art.has("ui", si):
			c.draw_texture_rect(Art.tex("ui", si), Rect2(bx, 24, 9, 9), false)
			c.draw_rect(Rect2(bx, 34, 9.0 * clampf(float(r["status"][k].get("secs", 0.0)) / 6.0, 0.0, 1.0), 1), Color(sd.get("colour", "ffffff")))
			bx += 11
	if int(r["flags"].get("shield", 0)) > 0 and Art.has("ui", "buff2_shield"):
		c.draw_texture_rect(Art.tex("ui", "buff2_shield"), Rect2(bx, 24, 9, 9), false); bx += 11
	if int(r["flags"].get("haste_abs", -1)) > GameState.now_abs() and Art.has("ui", "buff2_haste"):
		c.draw_texture_rect(Art.tex("ui", "buff2_haste"), Rect2(bx, 24, 9, 9), false); bx += 11
	if int(r["flags"].get("glow_day", -1)) == int(r["day"]) and Art.has("ui", "buff2_glow"):
		c.draw_texture_rect(Art.tex("ui", "buff2_glow"), Rect2(bx, 24, 9, 9), false); bx += 11
	# A wide (desktop) view: the clock box, place name and heat sit at the right edge (DisplayMode).
	var ex := DisplayMode.extra()
	c.draw_set_transform(Vector2(ex, y_offset))
	_draw_place(c)
	# Clock box (top right)
	var box := Rect2(166, 2, 100, 28)
	_panel(c, "panel_parchment", box)
	var dark := Color(0.25, 0.15, 0.05)
	var sicon := Art.tex("ui", "season2_" + GameState.season()) if Art.has("ui", "season2_" + GameState.season()) else Art.tex("ui", "season_" + GameState.season())
	if sicon:
		c.draw_texture_rect(sicon, Rect2(box.position.x + 4, box.position.y + 3, 9, 9), false)
	c.draw_string(_font, Vector2(box.position.x + (15 if sicon else 6), box.position.y + 11), "%s %d" % [GameState.season().capitalize().left(3), GameState.day_of_season()], HORIZONTAL_ALIGNMENT_LEFT, 50, 8, dark)
	c.draw_string(_font, Vector2(box.position.x + 6, box.position.y + 22), GameState.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, 60, 8, dark)
	var wx := GameState.weather_today()
	var wicon: String = {"rain": "☂", "storm": "⚡", "snow": "❄", "blizzard": "❄❄", "fog": "≈", "sun": "☀", "wind": "∿", "petals": "✿", "leaves": "❧", "fireflies": "✦"}.get(wx, "☼")
	var wxa := "wx_" + (wx if wx != "petals" else "petals_a")
	if Art.has("ui", wxa):
		c.draw_texture_rect(Art.tex("ui", wxa), Rect2(box.position.x + 50, box.position.y + 14, 11, 11), false)
	else:
		c.draw_string(_font, Vector2(box.position.x + 52, box.position.y + 22), str(wicon), HORIZONTAL_ALIGNMENT_LEFT, 20, 8, dark)
	var crystal := Art.tex("ui", "crystal")
	var cx := box.end.x - 6
	var ctext := str(int(r["crystals"]))
	var tw := _font.get_string_size(ctext, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8).x
	c.draw_string(_font, Vector2(cx - tw, box.position.y + 17), ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dark)
	if Money.cash():
		MoneyIcon.draw(c, Rect2(cx - tw - 13, box.position.y + 8, 11, 11))
	elif crystal:
		c.draw_texture_rect(crystal, Rect2(cx - tw - 11, box.position.y + 9, 9, 9), false)
	else:
		c.draw_string(_font, Vector2(cx - tw - 10, box.position.y + 17), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dark)
	c.draw_set_transform(Vector2(0, y_offset))
	# Toolbar
	var tb: Array = r["toolbar"]
	var slot := int(r["slot"])
	var frame := Art.tex("ui", "hotbar_frame")
	if frame:
		c.draw_texture_rect(frame, Rect2(TOOLBAR_X - 6, TOOLBAR_Y - 5, 12 * SLOT + 12, SLOT + 10), false)
	else:
		c.draw_rect(Rect2(TOOLBAR_X - 2, TOOLBAR_Y - 2, 12 * SLOT + 4, SLOT + 4), Color(0.1, 0.07, 0.04, 0.75))
	var slot_tex := Art.tex("ui", "slot")
	var slot_sel := Art.tex("ui", "slot_selected")
	# Three passes (slot frames, icons, counts): each stays inside its own slot, so
	# the order between slots doesn't matter and the bar batches (~10 draw calls, not ~30).
	for i in 12:
		var rect := Rect2(TOOLBAR_X + i * SLOT, TOOLBAR_Y, SLOT, SLOT)
		if slot_tex and slot_sel:
			c.draw_texture_rect(slot_sel if i == slot else slot_tex, rect, false)
		else:
			c.draw_rect(rect.grow(-1), Color(0.35, 0.25, 0.15, 0.9) if i != slot else Color(0.55, 0.42, 0.2, 1.0))
			if i == slot:
				c.draw_rect(rect.grow(-0.5), Color(1, 0.9, 0.5), false, 1.5)
	for i in 12:
		var rect := Rect2(TOOLBAR_X + i * SLOT, TOOLBAR_Y, SLOT, SLOT)
		var id := str(tb[i])
		if id == "":
			continue
		var icon := Art.tex("items", icon_for(id))
		if icon:
			# Keep the icon's shape (tier tools are tall: squashed they read as boots and bells).
			var ir := rect.grow(-2)
			var isz := icon.get_size()
			var k := minf(ir.size.x / isz.x, ir.size.y / isz.y)
			c.draw_texture_rect(icon, Rect2(ir.position + (ir.size - isz * k) / 2.0, isz * k), false)
		else:
			c.draw_string(_font, Vector2(rect.position.x + 1, rect.position.y + 13), GameState.item_name(id).left(3), HORIZONTAL_ALIGNMENT_LEFT, SLOT, 7, Color.WHITE)
	for i in 12:
		var rect := Rect2(TOOLBAR_X + i * SLOT, TOOLBAR_Y, SLOT, SLOT)
		var id := str(tb[i])
		if id != "" and r["inventory"].has(id):
			var n := str(int(r["inventory"][id]))
			var nw := _font.get_string_size(n, HORIZONTAL_ALIGNMENT_RIGHT, -1, 7).x
			# Outlined and kept inside the slot: bare white on the light slot art was hard to read.
			var np := Vector2(rect.end.x - nw - 2, rect.end.y - 2)
			c.draw_string_outline(_font, np, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color(0.1, 0.06, 0.03, 0.95))
			c.draw_string(_font, np, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	# Held item name / hint line
	var held := str(tb[slot])
	var line := ""
	if held != "":
		line = GameState.item_name(held)
	if _hint != "":
		line = Money.t((line + "   " if line != "" else "") + _hint)
	var lw := 180 if Racket.on() or y_offset > 0.0 else 240
	c.draw_string_outline(_font, Vector2(TOOLBAR_X, TOOLBAR_Y + SLOT + 11), line, HORIZONTAL_ALIGNMENT_LEFT, lw, 8, 3, Color(0, 0, 0, 0.7))  # reads on white sky ground
	c.draw_string(_font, Vector2(TOOLBAR_X, TOOLBAR_Y + SLOT + 11), line, HORIZONTAL_ALIGNMENT_LEFT, lw, 8, Color(1, 1, 0.9))
	# The goal, always on screen (one line, small).
	var nxt := Money.t(GameState.next_step())
	var sc0 := get_tree().current_scene
	if sc0 and sc0.get("battle") != null:
		nxt = ""  # the battle bar says what matters
	if nxt != "" and not Dialogue.instance(get_tree()).active:  # indoors too, under the held-item line
		# Up to two lines, cut at a word, so the how-to half of a long goal isn't lost.
		var gl: Array = [nxt]
		if nxt.length() > 54:
			var cut := nxt.rfind(" ", 54)
			if cut < 24:
				cut = 54
			var rest := nxt.substr(cut).strip_edges()
			gl = [nxt.left(cut), rest if rest.length() <= 58 else rest.left(56) + "…"]
		for gi in gl.size():
			var gy := TOOLBAR_Y + SLOT + 21 + gi * 9
			var gs := ("▸ " if gi == 0 else "   ") + str(gl[gi])
			c.draw_string_outline(_font, Vector2(TOOLBAR_X, gy), gs, HORIZONTAL_ALIGNMENT_LEFT, 240, 7, 3, Color(0, 0, 0, 0.7))
			c.draw_string(_font, Vector2(TOOLBAR_X, gy), gs, HORIZONTAL_ALIGNMENT_LEFT, 240, 7, Color(1, 0.92, 0.6))
	# Heat (gangster arc): five pips under the clock.
	# Hidden until there is some heat (first time: a toast says what it means).
	if Racket.on() and (Racket.heat() > 0 or r["flags"].has("heat_told")):
		if not r["flags"].has("heat_told"):
			r["flags"]["heat_told"] = true
			toast.call_deferred("Heat: how closely the President's people are watching you.", Color(1, 0.75, 0.6))
		var hx := 196.0 + ex
		var hy := TOOLBAR_Y + SLOT + 5.0
		c.draw_string_outline(_font, Vector2(hx, hy + 6), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0, 0, 0, 0.8))
		c.draw_string(_font, Vector2(hx, hy + 6), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.75, 0.6))
		for i in 5:
			var pc := Vector2(hx + 24 + i * 9, hy + 3)
			c.draw_circle(pc, 3.2, Color(0, 0, 0, 0.6))
			if i < Racket.heat():
				c.draw_circle(pc, 2.6, Color(1, 0.35 + 0.1 * (4 - i), 0.2))
	c.draw_set_transform(Vector2(DisplayMode.cx, y_offset))
	_draw_boss_bar(c)
	c.draw_set_transform(Vector2(0, y_offset))
	_draw_pointer(c)
	# Energy bar (vertical, right side, Stardew style)
	# The energy bar stays on the right edge; indoors (HUD at the bottom) it
	# moves up so it doesn't sit on the clock box.
	# Left-handed play mirrors the buttons to the left, so the bar moves left too
	# (the pup commands take the right edge).
	var lh := Settings.left_handed()
	var e := float(r["energy"]) / float(r["max_energy"])
	var tired := GameState.exhausted()
	# Exhausted (under 15%): the bar pulses red and says so, Stardew-style.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	if y_offset > 0.0:
		# Indoors: a short horizontal bar in the HUD block, off the room.
		c.draw_set_transform(Vector2(ex, y_offset))
		_draw_energy_h(c, e)
		if tired:
			c.draw_string_outline(_font, Vector2(206, 56), "EXHAUSTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 3, Color(0, 0, 0, 0.8))
			c.draw_string(_font, Vector2(206, 56), "EXHAUSTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.35 + 0.4 * pulse, 0.3))
		return
	if Dialogue.instance(get_tree()).active:
		return  # it would poke out past the dialogue box
	c.draw_set_transform(Vector2(-248.0 if lh else ex, 0.0))
	var bar := Rect2(256, 200, 9, 130)
	var fill_h := bar.size.y * e
	var col := Color("7ad35a") if e > 0.5 else (Color("f2c84b") if e > 0.25 else Color("e86a3a"))
	if Art.has("ui", "ebar_empty") and Art.has("ui", "ebar_green"):
		# Painted vertical bar (Prompts 09 HUD sheet): empty frame, fill cropped from the bottom.
		var fr := Rect2(250, 186, 20, 150)
		var fill_name := "ebar_green" if e > 0.5 else ("ebar_amber" if e > 0.25 else "ebar_red")
		var fe := Art.tex("ui", "ebar_empty")
		var ff := Art.tex("ui", fill_name) if Art.has("ui", fill_name) else Art.tex("ui", "ebar_green")
		c.draw_texture_rect(fe, fr, false)
		# The tube inside the frame runs ~12%..95% of its height; crop the fill texture to that.
		var top := 0.12
		var bot := 0.95
		var frac := clampf(e, 0.0, 1.0)
		var y0 := bot - (bot - top) * frac
		c.draw_texture_rect_region(ff, Rect2(fr.position.x, fr.position.y + fr.size.y * y0, fr.size.x, fr.size.y * (bot - y0)), Rect2(0, ff.get_height() * y0, ff.get_width(), ff.get_height() * (bot - y0)))
	else:
		c.draw_rect(bar.grow(1), Color(0.1, 0.07, 0.04, 0.8))
		c.draw_rect(Rect2(bar.position.x, bar.end.y - fill_h, bar.size.x, fill_h), col)
		var bolt := Art.tex("ui", "bolt_full")
		if bolt:
			c.draw_texture_rect(bolt, Rect2(bar.position.x - 2, bar.position.y - 14, 13, 13), false)
	if tired:
		var glow := Rect2(250, 186, 20, 150) if Art.has("ui", "ebar_empty") else bar.grow(2)
		c.draw_rect(glow.grow(1), Color(1, 0.2, 0.15, 0.25 + 0.45 * pulse), false, 2.0)
		var tlw := 44.0
		var tx := bar.position.x - tlw + 9 if not lh else bar.position.x - 2
		c.draw_string_outline(_font, Vector2(tx, bar.position.y - 18), "TIRED", HORIZONTAL_ALIGNMENT_RIGHT if not lh else HORIZONTAL_ALIGNMENT_LEFT, tlw, 7, 3, Color(0, 0, 0, 0.85))
		c.draw_string(_font, Vector2(tx, bar.position.y - 18), "TIRED", HORIZONTAL_ALIGNMENT_RIGHT if not lh else HORIZONTAL_ALIGNMENT_LEFT, tlw, 7, Color(1, 0.4 + 0.4 * pulse, 0.3))
	if lh:
		c.draw_string(_font, Vector2(bar.position.x - 4, bar.end.y + 10), "%d/%d" % [int(r["energy"]), int(r["max_energy"])], HORIZONTAL_ALIGNMENT_LEFT, 40, 7, Color(1, 1, 0.9))
	else:
		c.draw_string(_font, Vector2(bar.position.x - 30, bar.end.y + 10), "%d/%d" % [int(r["energy"]), int(r["max_energy"])], HORIZONTAL_ALIGNMENT_RIGHT, 40, 7, Color(1, 1, 0.9))


func _draw_energy_h(c: CanvasItem, e: float) -> void:
	var r := Rect2(206, 59, 58, 5)
	var col := Color("7ad35a") if e > 0.5 else (Color("f2c84b") if e > 0.25 else Color("e86a3a"))
	c.draw_rect(r.grow(1), Color(0.1, 0.07, 0.04, 0.85))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e, 0.0, 1.0), r.size.y)), col)
	var bolt := Art.tex("ui", "bolt_full")
	if bolt:
		c.draw_texture_rect(bolt, Rect2(r.position.x - 10, r.position.y - 3, 9, 9), false)
	var et := "%d/%d" % [int(GameState.run["energy"]), int(GameState.run["max_energy"])]
	c.draw_string_outline(_font, Vector2(r.end.x - 34, r.end.y + 8), et, HORIZONTAL_ALIGNMENT_RIGHT, 34, 6, 3, Color(0, 0, 0, 0.7))
	c.draw_string(_font, Vector2(r.end.x - 34, r.end.y + 8), et, HORIZONTAL_ALIGNMENT_RIGHT, 34, 6, Color(1, 1, 0.9))


## Close stand-ins from art we already have, until each item gets its own icon.
const ICON_NEAR := {"crystal_bloom": "cave_bloom", "strawberry_wine": "fruit_wine", "corn_ale": "harvest_ale", "berry_juice": "juice_berry",
	"sprinkler_iridium": "sprinkler_quality", "old_collar": "collar_a", "brass_locket": "pendant_pearl", "knight_shard": "light_shard",
	"manifest": "letter_sealed", "sand": "time_sand", "colony_light": "lantern_crystal", "coral_charm": "charm_tide", "tide_pearl": "rain_pearl",
	"kelp_wrap": "sandwich", "ember_glass": "storm_glass", "starfish_snack": "starfish"}


static func icon_for(id: String) -> String:
	if not GameState.TOOL_KINDS.has(id) and Art.has("items", id):
		return id  # weapons with their own art (six_shooter, crowbar...) keep it
	if GameState.TOOL_KINDS.has(id) or GameState.is_sword(id):
		var ti := GameState.tool_icon(id)
		if Art.has("items", ti):
			return ti
	if Art.has("items", id):
		return id
	var own := str(GameState.items.get(id, {}).get("icon", ""))
	if own != "" and Art.has("items", own):
		return own
	var near := str(ICON_NEAR.get(id, ""))
	if near != "" and Art.has("items", near):
		return near
	if id.begins_with("backpack_") and Art.has("items", "backpack"):
		return "backpack"
	if id.ends_with("_seed"):
		return "seeds"
	match id:
		"minnow", "trout": return "fish"
		"berry": return "apple"
		"mushroom": return "bread"
		"moonwort": return "wild_herb2"
		"shiitake": return "mushroom"
		"boot": return "map"
	return id


func _panel(c: CanvasItem, name: String, rect: Rect2) -> void:
	# panel_parchment's 24px cells have transparent gutters (they stretch into
	# dark lines): use the framed panel_parchment2 as a true 9-slice.
	if name == "panel_parchment" and Art.has("ui", "panel_parchment2"):
		name = "panel_parchment2"
	var t := Art.tex("ui", name)
	if t == null:
		c.draw_rect(rect, Color(0.95, 0.88, 0.7, 0.95))
		c.draw_rect(rect, Color(0.4, 0.25, 0.1), false, 1.0)
		return
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var sm := 12.0 if name == "panel_parchment2" else 8.0   # source corner (texture px)
	var m := minf(6.0, minf(rect.size.x, rect.size.y) / 3.0)  # drawn corner
	var xs := [0.0, sm, tw - sm, tw]
	var ys := [0.0, sm, th - sm, th]
	var dx := [rect.position.x, rect.position.x + m, rect.end.x - m, rect.end.x]
	var dy := [rect.position.y, rect.position.y + m, rect.end.y - m, rect.end.y]
	for yi in 3:
		for xi in 3:
			c.draw_texture_rect_region(t, Rect2(dx[xi], dy[yi], dx[xi + 1] - dx[xi], dy[yi + 1] - dy[yi]), Rect2(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))


## Panels in the art's palette: parchment (light, dark ink) or wood (dark, light text).
## Horizontal painted bar: bar_h_empty frame + fill cropped from the left.
func _hbar(c: CanvasItem, r: Rect2, frac: float, fill: String) -> void:
	c.draw_texture_rect(Art.tex("ui", "bar_h_empty"), r, false)
	var ff := Art.tex("ui", fill)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		c.draw_texture_rect_region(ff, Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Rect2(0, 0, ff.get_width() * f, ff.get_height()))


## Wooden button skin (Prompts 09 menu sheet) as a 9-slice on a Theme.
static func skin_buttons(ctrl: Control) -> void:
	if not Art.has("ui", "btn2_wood"):
		return
	var th := Theme.new()
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		# A flat wooden plank: the painted button art is far bigger than an
		# 18 px menu button and only showed a sliver of its edge.
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.55, 0.36, 0.2), "hover": Color(0.62, 0.42, 0.24), "pressed": Color(0.45, 0.29, 0.16), "disabled": Color(0.4, 0.36, 0.33), "focus": Color(0.55, 0.36, 0.2)}[st]
		sb.border_color = Color(0.28, 0.16, 0.08) if st != "focus" else Color(1, 0.85, 0.4)
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		if st == "focus":
			sb.draw_center = false
		th.set_stylebox(st, "Button", sb)
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	th.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	th.set_constant("outline_size", "Button", 2)
	th.set_color("font_outline_color", "Button", Color(0.2, 0.1, 0.05))
	ctrl.theme = th


static func panel_stylebox(name: String) -> StyleBox:
	var sb := StyleBoxFlat.new()
	if name == "panel_parchment":
		sb.bg_color = Color(0.96, 0.9, 0.74, 0.97)
		sb.border_color = Color(0.45, 0.28, 0.12)
	else:
		sb.bg_color = Color(0.36, 0.22, 0.1, 0.97)
		sb.border_color = Color(0.78, 0.55, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(7)
	return sb


func toast(text: String, color := Color.WHITE) -> void:
	# The same message again: bump a counter instead of stacking a copy.
	for c in _toasts.get_children():
		if c is Label and c.has_meta("base") and str(c.get_meta("base")) == text and not c.is_queued_for_deletion():
			var k := int(c.get_meta("count", 1)) + 1
			c.set_meta("count", k)
			(c as Label).text = "%s  ×%d" % [text, k]
			(c as Label).custom_minimum_size.x = _fit_w((c as Label).text)
			# Restart its fade, so a pile of "+1 Wood ×5" stays up for the last copy.
			var otw: Variant = c.get_meta("tw") if c.has_meta("tw") else null
			if otw is Tween and (otw as Tween).is_valid():
				(otw as Tween).kill()
			(c as Label).modulate.a = 1.0
			var ntw := (c as Label).create_tween()
			ntw.tween_interval(clampf(1.2 + text.length() * 0.03, 1.6, 4.0))
			ntw.tween_property(c, "modulate:a", 0.0, 0.5)
			ntw.tween_callback(c.queue_free)
			c.set_meta("tw", ntw)
			return
	# At most three on screen: the oldest goes.
	var live: Array = []
	for c in _toasts.get_children():
		if not c.is_queued_for_deletion():
			live.append(c)
	while live.size() >= 3:
		# Item pickups ("+1 Wood") go first; the oldest otherwise (it's often the important one).
		var old_l: Node = live[0]
		for v in live:
			if str(v.get_meta("base", "")).begins_with("+"):
				old_l = v
				break
		live.erase(old_l)
		_toasts.remove_child(old_l)
		old_l.queue_free()
	# Keep a short history for the journal.
	var hist: Array = GameState.run.get("toast_log", []) if not GameState.run.is_empty() else []
	hist.append(text)
	while hist.size() > 40:
		hist.pop_front()
	if not GameState.run.is_empty():
		GameState.run["toast_log"] = hist
	var l := Label.new()
	l.set_meta("base", text)
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_color_override("font_color", color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A dark rounded backing sized to the text, so toasts read over grass and portraits.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.custom_minimum_size = Vector2(_fit_w(text), 0)
	_toasts.add_child(l)
	_place_toasts()
	var tw := l.create_tween()
	l.set_meta("tw", tw)
	tw.tween_interval(clampf(1.2 + text.length() * 0.03, 1.6, 4.0))  # long messages stay long enough to read
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func fade_out(seconds := 0.4) -> void:
	_fade.visible = true
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, seconds)
	await tw.finished


func fade_in(seconds := 0.4) -> void:
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, seconds)
	await tw.finished
	_fade.visible = _fade.color.a > 0.0


## Big maps (the mines): an arrow at the screen edge toward the open shaft or the awake keeper.
func _draw_pointer(c: CanvasItem) -> void:
	var m := get_tree().current_scene as GameMap
	if m == null or m.player == null or y_offset != 0.0 or Dialogue.instance(get_tree()).active or m.get("battle") != null:
		return
	# Maps with their own target (mine ladder/guardian) first; else the goal line's place.
	var tgt: Vector2 = m.call("pointer_target") if m.has_method("pointer_target") else GoalLine.target(m)
	if tgt == Vector2.ZERO:
		return
	var sp: Vector2 = m.get_viewport().get_canvas_transform() * tgt
	var view := Rect2(18, 112, DisplayMode.view.x - 48.0, 244)
	if view.has_point(sp):
		return
	var ctr := view.get_center()
	var d := (sp - ctr)
	var k := minf(absf((view.size.x * 0.5) / maxf(0.001, absf(d.x))), absf((view.size.y * 0.5) / maxf(0.001, absf(d.y))))
	var at := ctr + d * k
	var dir := d.normalized()
	var col: Color = Color(1, 0.4, 0.35) if bool(m.get("_guardian") != null) else Color(0.5, 1, 0.6)
	var pts := PackedVector2Array([at + dir * 10.0, at - dir * 6.0 + dir.orthogonal() * 7.0, at - dir * 6.0 - dir.orthogonal() * 7.0])
	c.draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
	var pts2 := PackedVector2Array([at + dir * 8.0, at - dir * 4.5 + dir.orthogonal() * 5.3, at - dir * 4.5 - dir.orthogonal() * 5.3])
	c.draw_colored_polygon(pts2, col)
	# How far, in cells, so 10 and 80 don't look the same.
	var dist := str(int(m.player.position.distance_to(tgt) / 16.0))
	var tp := at - dir * 14.0 + Vector2(-10, 3)
	c.draw_string_outline(_font, tp, dist, HORIZONTAL_ALIGNMENT_CENTER, 20, 6, 2, Color(0, 0, 0, 0.8))
	c.draw_string(_font, tp, dist, HORIZONTAL_ALIGNMENT_CENTER, 20, 6, col)


## The nearest boss in view: name and a health bar across the top of the field.
func _draw_boss_bar(c: CanvasItem) -> void:
	var m := get_tree().current_scene as GameMap
	if m == null or m.player == null or y_offset != 0.0:
		_boss_on = false
		return
	var boss: Enemy = null
	for e in m.enemies:
		if is_instance_valid(e) and e._alive and not e.has_meta("decoy") and (e.bossy or e.is_guardian or e.has_meta("marked") or e._gift != null or e.has_meta("boss_name")) and (e.has_meta("boss_name") or e.position.distance_to(m.player.position) < 170.0):
			if boss == null or e.max_hp > boss.max_hp:
				boss = e
	_boss_on = boss != null
	if boss == null:
		return
	var nm := boss.display_name()
	var r := Rect2(40, 96, 190, 6)
	c.draw_rect(r.grow(1.5), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(boss.hp) / boss.max_hp, 0, 1), r.size.y)), Color(0.9, 0.25, 0.3))
	# Open = a timed window, or a standing rule that holds right now (wet, behind, range, real).
	var opn: bool = boss._gift != null and (boss._gift.open_t > 0.0 or boss._gift.vuln(m.player.position, false) > float(boss._gift.d.get("rule", {}).get("closed", 0.0)) + 0.01)
	if opn:
		c.draw_rect(r.grow(1.5), Color(1, 1, 1, 0.9), false, 1.0)
	c.draw_string_outline(_font, Vector2(r.position.x, r.position.y - 2), nm, HORIZONTAL_ALIGNMENT_LEFT, 190, 7, 3, Color(0, 0, 0, 0.85))
	c.draw_string(_font, Vector2(r.position.x, r.position.y - 2), nm, HORIZONTAL_ALIGNMENT_LEFT, 190, 7, Color(1, 0.9, 0.85))
	if boss._gift:
		var gn := str(boss._gift.d.get("name", ""))
		var st := "OPEN" if opn else "guarded"
		c.draw_string_outline(_font, Vector2(r.end.x - 70, r.position.y - 2), "%s · %s" % [gn, st], HORIZONTAL_ALIGNMENT_RIGHT, 70, 6, 3, Color(0, 0, 0, 0.85))
		c.draw_string(_font, Vector2(r.end.x - 70, r.position.y - 2), "%s · %s" % [gn, st], HORIZONTAL_ALIGNMENT_RIGHT, 70, 6, Color(1, 1, 0.7) if st == "OPEN" else Color(0.8, 0.85, 1))
