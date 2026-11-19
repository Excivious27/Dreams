class_name TouchControls
extends CanvasLayer
## Stardew-mobile style touch controls:
##  - Floating joystick: touch and drag anywhere on the lower-left of the screen.
##    Push further to run. Analog 8-way steering.
##  - A quick tap (no drag) anywhere in the world walks there / uses what's there.
##  - Right side: USE (tool / sword / check), CHECK (talk, pick up, eat), MENU.
## Presses the same input actions as the keyboard, so game code only reads actions.

const TOP_OF_CONTROLS := 352.0
const BUTTONS := {
	"a": {"pos": Vector2(232, 398), "r": 24.0, "label": "USE"},
	"action": {"pos": Vector2(186, 438), "r": 18.0, "label": "CHECK"},
	"menu": {"pos": Vector2(237, 460), "r": 13.0, "label": "MENU"},
	# Partner ability / Meow Pow Wow (B-hold on a keyboard). Shown only when you have one.
	"ability": {"pos": Vector2(146, 462), "r": 14.0, "label": "♥"},
	# Dodge roll: shown only while an enemy is close.
	"dodge": {"pos": Vector2(184, 384), "r": 13.0, "label": "ROLL"},
}
static var dodge_pressed := false
## What USE would do right now ("Talk", "Chop"...), set by the map every frame.
static var context_word := ""
## Pup commands: a strip down the left edge, shown while the pup is with you.
## (Teammates will get a second strip the same way.)
const PUP_CMDS := [["follow", "cmd_heel", "HEEL"], ["attack", "cmd_attack", "ATK"], ["wait", "cmd_stay", "STAY"], ["guard", "cmd_guard", "GUARD"], ["recall", "cmd_recall", "CALL"]]
const PUP_X := 15.0
const PUP_Y0 := 212.0
const PUP_STEP := 27.0
const PUP_R := 11.0
const DIRS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
const STICK_R := 34.0
const RUN_AT := 0.72
const TAP_MAX_T := 0.35
const TAP_MAX_D := 10.0

static var run_toggle := false
static var ability_pressed := false
## False on desktop (a keyboard or mouse was used): the on-screen pad hides.
static var visible_controls := true

var _touches := {}  # touch index -> "stick" | "pending" | action name
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_active := false
var _stick_vec := Vector2.ZERO
var _pending_at := {}  # touch index -> where it went down
var _pending_t := {}   # touch index -> when
var _held := {}  # action -> true while held by touch
var _canvas: Control
var _running := false


const BTN_ROW := ["btn_blue", "btn_blue_down", "btn_green", "btn_green_down", "btn_red", "btn_red_down", "btn_gold", "btn_gold_down"]
## Left edge of each circle in that 490x70 row (they touch in pairs, so equal cells would show slivers).
const BTN_SRC_X := [0, 59, 123, 182, 247, 306, 372, 431]
const TOOL_VERBS := ["Chop", "Mine", "Fish", "Cut", "Farm", "Fight"]
const SKINS := {"a": ["btn_gold", "btn_gold_down"], "action": ["btn_green", "btn_green_down"], "menu": ["sbtn_blue", "sbtn_blue_down"], "ability": ["sbtn_blue", "sbtn_blue_down"]}

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		release_all()


var _redraw_t := 0.0
var _modal_was := false
var _last_sig := ""


func _process(delta: float) -> void:
	# A full-screen panel just opened (arcade, bowling, prizes, chest...): let go of
	# the stick and any held button, so nothing walks or swings underneath it and
	# its own controls start clean. (No panel is played with the stick: HackGame
	# has its own on-screen arrows and the keys.)
	var modal := Hud.modal_rect.has_area()
	if modal and not _modal_was and not _held.is_empty():
		release_all()
	_modal_was = modal
	_canvas.visible = visible_controls
	if not visible_controls:
		return
	# Touches redraw at once (_press/_release/_set_vec); the rest (cooldown arc,
	# dodge/ability appearing, context word) is fine at 10 Hz or on change.
	_redraw_t += delta
	var sig := "%s|%s|%s" % [context_word, get_tree().paused, Dialogue.instance(get_tree()).active]
	if _redraw_t >= 0.1 or sig != _last_sig:
		_redraw_t = 0.0
		_last_sig = sig
		_canvas.queue_redraw()


func release_all() -> void:
	for action: String in _held.keys():
		if InputMap.has_action(action):
			Input.action_release(action)
	_held.clear()
	_touches.clear()
	_stick_active = false
	_stick_vec = Vector2.ZERO
	_running = false
	if _canvas:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	# Desktop detection: a real key or mouse motion hides the pad; a real touch shows it.
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		# Typing a name on the phone's on-screen keyboard isn't "desktop".
		if not (get_viewport().gui_get_focus_owner() is LineEdit):
			visible_controls = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative != Vector2.ZERO and event.device != InputEvent.DEVICE_ID_EMULATION and not DisplayServer.is_touchscreen_available():
		visible_controls = false
		Player.last_mouse_motion_ms = Time.get_ticks_msec()
	elif event is InputEventScreenTouch and DisplayServer.is_touchscreen_available():
		visible_controls = true
	if not visible_controls:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # a mouse pretending to be a finger: the mouse handlers take it
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var hit := _hit(t.position)
			if hit != "":
				_touches[t.index] = hit
				_press(hit)
				get_viewport().set_input_as_handled()
				return
			if Hud.hud_rect_blocks(t.position):
				return  # toolbar / clock: the HUD handles it
			if get_tree().paused or Dialogue.instance(get_tree()).active:
				return  # menus and dialogue take their own taps
			if _stick_active:
				return  # second finger while steering: let the world take it (tap on enemy etc.)
			# Could become a joystick drag or a tap: decide on release/drag.
			_touches[t.index] = "pending"
			_pending_at[t.index] = t.position
			_pending_t[t.index] = Time.get_ticks_msec() / 1000.0
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			var what: String = _touches[t.index]
			_touches.erase(t.index)
			if what == "stick":
				_end_stick()
			elif what == "pending":
				var held_for := Time.get_ticks_msec() / 1000.0 - float(_pending_t.get(t.index, 0.0))
				_pending_at.erase(t.index)
				_pending_t.erase(t.index)
				if held_for <= TAP_MAX_T and t.position.y < TOP_OF_CONTROLS:
					var m := get_tree().current_scene
					if m is GameMap:
						(m as GameMap).handle_tap(t.position)
			else:
				_release(what)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var what: String = _touches.get(d.index, "")
		if what == "pending":
			var at: Vector2 = _pending_at.get(d.index, d.position)
			if d.position.distance_to(at) > TAP_MAX_D and not _stick_active:
				_touches[d.index] = "stick"
				_stick_origin = at
				_stick_active = true
				_update_stick(d.position)
			get_viewport().set_input_as_handled()
		elif what == "stick":
			_update_stick(d.position)
			get_viewport().set_input_as_handled()


func _pup_x() -> float:
	return 270.0 - PUP_X if Settings.left_handed() else PUP_X


func _foe_near() -> bool:
	var m := get_tree().current_scene as GameMap
	if m == null or m.player == null or get_tree().paused:
		return false
	return m.nearest_enemy_to(m.player.position, 100.0) != null


func _has_ability() -> bool:
	if GameState.run.is_empty():
		return false
	return Companion.active_id() != "" or (GameState.is_penguins() and GameState.run.get("flags", {}).has("meow_taught"))


func _pet() -> Pet:
	var m := get_tree().current_scene
	if m is GameMap and (m as GameMap).pet != null and is_instance_valid((m as GameMap).pet):
		# Indoors the HUD sits where the strip would be: no strip inside.
		if (m as GameMap).scene_id() in ["house", "interior"]:
			return null
		return (m as GameMap).pet as Pet
	return null


## The pup is away (staying or guarding on another map): only CALL works.
func _pet_away() -> bool:
	var pt := _pet()
	return pt != null and not pt.visible


func _pup_cmd(cmd: String) -> void:
	var pt := _pet()
	if pt == null:
		return
	if cmd == "recall":
		pt.recall()
	elif not pt.visible:
		var m0 := get_tree().current_scene as GameMap
		if m0 and m0.hud:
			m0.hud.toast("%s isn't here. Tap CALL first." % Pet.name_of(), Color(1, 0.85, 0.6))
		return
	elif cmd == "guard" and GameState.bonus("pup", "guard") <= 0.0:
		var m := get_tree().current_scene as GameMap
		if m and m.hud:
			m.hud.toast("Guard needs the Guard Dog skill (Pup tree).", Color(1, 0.85, 0.6))
		return
	else:
		pt.set_mode(cmd)
		var mh := get_tree().current_scene as GameMap
		if mh and mh.hud:
			mh.hud.toast("%s: %s" % [Pet.name_of(), str({"follow": "heel", "attack": "attack", "wait": "stay", "guard": "guard"}.get(cmd, cmd)).capitalize()], Color(1, 0.95, 0.75))
	Music.instance(get_tree()).sfx("bark", "pickup")


func _hit(pos: Vector2) -> String:
	# A full-screen panel (crafting, hack, ending) owns its area: no hidden buttons under it.
	if Hud.modal_rect.has_area() and Hud.modal_rect.has_point(pos) and not Dialogue.instance(get_tree()).active:
		return ""
	if _pet() != null and not get_tree().paused and not Dialogue.instance(get_tree()).active:
		for i in PUP_CMDS.size():
			if str(PUP_CMDS[i][0]) == "guard" and GameState.bonus("pup", "guard") <= 0.0:
				continue  # locked until the Guard Dog skill: not shown
			if pos.distance_to(Vector2(_pup_x(), PUP_Y0 + PUP_STEP * i)) <= PUP_R * 1.25:
				return "pup:" + str(PUP_CMDS[i][0])
	for action: String in BUTTONS:
		if action == "ability" and not _has_ability():
			continue
		if action == "dodge" and not _foe_near():
			continue
		var b: Dictionary = BUTTONS[action]
		var br := Settings.button_at(b["pos"], float(b["r"]))
		if pos.distance_to(br[0]) <= float(br[1]) * 1.35:
			return action
	return ""


func _update_stick(pos: Vector2) -> void:
	var v := pos - _stick_origin
	# The stick base follows your thumb if you push well past its edge (floating).
	if v.length() > STICK_R * 1.6:
		_stick_origin = pos - v.normalized() * STICK_R * 1.6
		v = pos - _stick_origin
	_stick_pos = pos
	var mag := clampf(v.length() / STICK_R, 0.0, 1.0)
	if mag < 0.18:
		_set_vec(Vector2.ZERO, false)
		return
	# 8-way like Stardew's pad, but keep the analog magnitude for walk/run.
	var a := snappedf(v.angle(), PI / 4.0)
	var dir := Vector2(cos(a), sin(a)).normalized()
	_set_vec(dir, mag >= RUN_AT)


func _set_vec(dir: Vector2, running: bool) -> void:
	# Paused (a full-screen menu is open): the stick does nothing, and never presses B.
	if get_tree().paused:
		running = false  # never press B by pushing the stick far while something is open
		if not Dialogue.instance(get_tree()).active:
			dir = Vector2.ZERO  # dialogue choices still use a held stick; menus don't
	_stick_vec = dir
	for action: String in DIRS:
		var want := dir.dot(DIRS[action]) > 0.5
		if want and not _held.has(action):
			_press(action)
		elif not want and _held.has(action):
			_release(action)
	if running != _running:
		_running = running
		if running:
			_press("b")
		else:
			_release("b")
	_canvas.queue_redraw()


func _end_stick() -> void:
	_stick_active = false
	_set_vec(Vector2.ZERO, false)


func _press(action: String) -> void:
	_held[action] = true
	if action.begins_with("pup:"):
		_pup_cmd(action.trim_prefix("pup:"))
		_canvas.queue_redraw()
		return
	if action == "ability":
		ability_pressed = true
		_canvas.queue_redraw()
		return
	if action == "dodge":
		dodge_pressed = true
		_canvas.queue_redraw()
		return
	Input.action_press(action)
	_canvas.queue_redraw()


func _release(action: String) -> void:
	_held.erase(action)
	if action.begins_with("pup:"):
		_canvas.queue_redraw()
		return
	if action in ["ability", "dodge"]:
		_canvas.queue_redraw()
		return
	Input.action_release(action)
	_canvas.queue_redraw()


func _on_draw() -> void:
	var font := ThemeDB.fallback_font
	# A full-screen panel (chest, crafting, arcade...) takes every tap: don't show
	# dead buttons peeking out under it. Dialogue over it still uses the pad.
	var dlg_on := Dialogue.instance(get_tree()).active
	if not dlg_on and Hud.modal_rect.encloses(Rect2(0, 0, 270, 480)):
		return
	var base := Color(1, 1, 1, 0.16)
	var edge := Color(1, 1, 1, 0.45)
	var lit := Color(1, 1, 1, 0.5)
	# Joystick: faint resting ring bottom-left until you touch; then it floats under your thumb.
	var origin := _stick_origin if _stick_active else Vector2(212 if Settings.left_handed() else 58, 412)
	var jb := Art.tex("ui", "joy_base_a")
	var jk := Art.tex("ui", "joy_knob_light")
	if jb:
		_canvas.draw_texture_rect(jb, Rect2(origin - Vector2(STICK_R + 4, STICK_R + 4), Vector2(STICK_R + 4, STICK_R + 4) * 2), false, Color(1, 1, 1, 0.75 if _stick_active else 0.45))
	else:
		_canvas.draw_circle(origin, STICK_R, base if not _stick_active else Color(1, 1, 1, 0.22))
		_canvas.draw_arc(origin, STICK_R, 0, TAU, 48, edge, 1.5, true)
	if _stick_active:
		var knob := origin + (_stick_pos - origin).limit_length(STICK_R)
		if jk:
			_canvas.draw_texture_rect(jk, Rect2(knob - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 1, 1, 0.95 if _running else 0.8))
		else:
			_canvas.draw_circle(knob, 13.0, Color(1, 1, 1, 0.6 if _running else 0.45))
			_canvas.draw_arc(knob, 13.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.5, true)
	elif jb == null:
		for action: String in DIRS:
			var d: Vector2 = DIRS[action]
			var c := origin + d * STICK_R * 0.62
			var tip := c + d * 6.0
			var side := d.orthogonal() * 6.0
			_canvas.draw_colored_polygon(PackedVector2Array([tip, c - d * 4.0 + side, c - d * 4.0 - side]), edge)
	# Pup command strip.
	var pt := _pet()
	if pt != null and not get_tree().paused:
		var mode := str(Pet.state().get("mode", "follow"))
		# Pass by pass (discs, rings, icons, presses): a draw_circle is a draw call
		# each and an antialiased draw_arc three, so the old per-button order cost ~20.
		for pass_i in 4:
			for i in PUP_CMDS.size():
				var cmd := str(PUP_CMDS[i][0])
				if cmd == "guard" and GameState.bonus("pup", "guard") <= 0.0:
					continue  # locked until the Guard Dog skill (the others keep their spots)
				var cp := Vector2(_pup_x(), PUP_Y0 + PUP_STEP * i)
				var active := cmd == mode
				if pass_i == 0:
					Art.draw_disc(_canvas, cp, PUP_R, Color(0.12, 0.09, 0.05, 0.62))
				elif pass_i == 1:
					Art.draw_ring(_canvas, cp, PUP_R, 2.0 if active else 1.0, Color(1, 0.85, 0.35, 0.95) if active else Color(1, 1, 1, 0.35))
				elif pass_i == 2:
					var dim := (cmd == "guard" and GameState.bonus("pup", "guard") <= 0.0) or (not pt.visible and cmd != "recall")
					var ic := str(PUP_CMDS[i][1])
					if Art.has("ui", ic):
						_canvas.draw_texture_rect(Art.tex("ui", ic), Rect2(cp - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, 0.4 if dim else (1.0 if active else 0.85)))
					else:
						_canvas.draw_string(font, cp + Vector2(-PUP_R, 2), str(PUP_CMDS[i][2]), HORIZONTAL_ALIGNMENT_CENTER, PUP_R * 2.0, 5, Color(1, 1, 1, 0.9))
				elif _held.has("pup:" + cmd):
					Art.draw_disc(_canvas, cp, PUP_R, Color(1, 1, 1, 0.25))
		if int(GameState.run.get("day", 1)) <= 3:
			# Early days: name each command under its icon (all outlines, then all fills: fewer batch breaks).
			for pass_i in 2:
				for i in PUP_CMDS.size():
					var cmd := str(PUP_CMDS[i][0])
					if cmd == "guard" and GameState.bonus("pup", "guard") <= 0.0:
						continue
					if not Art.has("ui", str(PUP_CMDS[i][1])):
						continue
					var lp := Vector2(_pup_x(), PUP_Y0 + PUP_STEP * i) + Vector2(-PUP_R - 4, PUP_R + 5)
					if pass_i == 0:
						_canvas.draw_string_outline(font, lp, str(PUP_CMDS[i][2]), HORIZONTAL_ALIGNMENT_CENTER, PUP_R * 2.0 + 8, 5, 2, Color(0, 0, 0, 0.8))
					else:
						_canvas.draw_string(font, lp, str(PUP_CMDS[i][2]), HORIZONTAL_ALIGNMENT_CENTER, PUP_R * 2.0 + 8, 5, Color(1, 1, 1, 0.95))
	# Buttons
	var btn := Art.tex("ui", "button")
	var btn_down := Art.tex("ui", "button_pressed")
	var caps := []  # icon captions, drawn after the loop: all outlines, then all fills
	for action: String in BUTTONS:
		if action == "ability" and not _has_ability():
			continue
		if action == "dodge" and not _foe_near():
			continue
		var b: Dictionary = BUTTONS[action]
		var br := Settings.button_at(b["pos"], float(b["r"]))
		var p: Vector2 = br[0]
		var r := float(br[1])
		if not dlg_on and Hud.modal_rect.has_point(p):
			continue  # under a panel (bowling's lane): it can't be pressed, so it isn't drawn
		var on := _held.has(action)
		var sk: Array = SKINS.get(action, [])
		var bname := ""
		if not sk.is_empty() and Art.has("ui", str(sk[0])):
			btn = Art.tex("ui", str(sk[0]))
			btn_down = Art.tex("ui", str(sk[1]))
			bname = str(sk[1] if on else sk[0])
		if btn and btn_down:
			var bt: Texture2D = btn_down if on else btn
			var cell := float(bt.get_height())
			var src := Rect2(0, 0, cell, cell)
			if bt.get_width() > cell * 4:
				# The slicer left the whole row (8 buttons side by side): pick ours.
				var idx := maxi(BTN_ROW.find(bname), 0)
				if bt.get_width() == 490:
					src = Rect2(float(BTN_SRC_X[idx]), 3, 59, 62)  # skip the frame bar (y0-2) and label bars (y65+)
				else:
					var cw := float(bt.get_width()) / BTN_ROW.size()
					src = Rect2(cw * idx + (cw - cell) / 2.0, 0, cell, cell)
			_canvas.draw_texture_rect_region(bt, Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), src, Color(1, 1, 1, 0.85))
		else:
			_canvas.draw_circle(p, r, lit if on else base)
			_canvas.draw_arc(p, r, 0, TAU, 40, edge, 1.5, true)
		if action == "ability" and not GameState.run.is_empty():
			var m0 := get_tree().current_scene as GameMap
			if m0 and m0.player:
				var ab := Companion.ability_for(m0, m0.player)
				var cl := Companion.cooldown_left(ab)
				if cl > 0.0:
					var full := float(Companion.COOLDOWN.get(ab, Companion.DEFAULT_COOLDOWN))
					_canvas.draw_circle(p, r, Color(0, 0, 0, 0.45))
					_canvas.draw_arc(p, r - 1, -PI / 2, -PI / 2 + TAU * (1.0 - cl / full), 32, Color(0.6, 0.85, 1, 0.95), 2.5, true)
		var label := str(b["label"])
		var size := 9 if r > 20.0 else 7
		if action == "a" and context_word != "" and not get_tree().paused:
			var tw := font.get_string_size(context_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8.0
			var tp := p + Vector2(-tw / 2.0, -r - 13.0)
			_canvas.draw_rect(Rect2(tp, Vector2(tw, 11)), Color(0.1, 0.07, 0.04, 0.75))
			_canvas.draw_string(font, tp + Vector2(4, 8.5), context_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.93, 0.7))
		if action == "a":
			# Show what USE will do: the held tool's icon, or a sword.
			var held := GameState.held_tool() if not GameState.run.is_empty() else ""
			var icon := Art.tex("items", held if held != "" else "sword")
			# A context verb that isn't a tool's (Talk, Enter, Sleep, Shop...) shows a hand instead.
			if context_word != "" and not get_tree().paused and not (context_word in TOOL_VERBS) and Art.has("items", "hand"):
				# Sleep and Talk get their own picture, so USE never matches CHECK's hand.
				if context_word == "Sleep" and Art.has("ui", "buff2_asleep"):
					icon = Art.tex("ui", "buff2_asleep")
				elif context_word in ["Talk", "Pet"] and Art.has("ui", "bubble"):
					icon = Art.tex("ui", "bubble")
				elif context_word in ["Go", "Enter", "Exit", "Leave"] and Art.has("ui", "arrow_up"):
					icon = Art.tex("ui", "arrow_up")
				else:
					icon = Art.tex("items", "hand")
			if icon:
				caps.append([p, r, label])
				_canvas.draw_texture_rect(icon, Rect2(p - Vector2(12, 12), Vector2(24, 24)), false)
				continue
		if action == "ability" and not GameState.run.is_empty():
			var sid := str(Companion.defs().get(Companion.active_id(), {}).get("sprite", Companion.active_id()))
			if Art.has("ui", "icon_ability_" + sid):
				_canvas.draw_texture_rect(Art.tex("ui", "icon_ability_" + sid), Rect2(p - Vector2(10, 10), Vector2(20, 20)), false)
				continue
			# The Marked: show their Gift until their own button icon exists.
			var ab := str(Companion.defs().get(Companion.active_id(), {}).get("ability", ""))
			if ab.begins_with("gift:"):
				var fam := ab.trim_prefix("gift:")
				if fam == "beat":
					fam = "tempo"
				if Art.has("fx", "gift_" + fam):
					var gsf := Art.frames("fx", {"a": "gift_" + fam})
					if gsf and gsf.has_animation("a") and gsf.get_frame_count("a") > 0:
						_canvas.draw_texture_rect(gsf.get_frame_texture("a", 0), Rect2(p - Vector2(10, 10), Vector2(20, 20)), false)
						continue
		if action == "ability" and Art.has("ui", "party_paw"):
			_canvas.draw_texture_rect(Art.tex("ui", "party_paw"), Rect2(p - Vector2(9, 9), Vector2(18, 18)), false)
			continue
		if action == "menu" and Art.has("ui", "ic_menu"):
			caps.append([p, r, label])
			_canvas.draw_texture_rect(Art.tex("ui", "ic_menu"), Rect2(p - Vector2(9, 9), Vector2(18, 18)), false)
			continue
		if action == "action" and Art.has("items", "hand"):
			caps.append([p, r, label])
			_canvas.draw_texture_rect(Art.tex("items", "hand"), Rect2(p - Vector2(11, 11), Vector2(22, 22)), false)
			continue
		_canvas.draw_string(font, p + Vector2(-r, size * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(1, 1, 1, 0.9))
	for pass_i in 2:
		for cap: Array in caps:
			_caption(font, cap[0], cap[1], cap[2], pass_i == 0)


## A small word under an icon button (the tutorial says "tap USE", "open MENU").
func _caption(font: Font, p: Vector2, r: float, label: String, outline: bool) -> void:
	var at := Vector2(p.x - r, minf(p.y + r + 7.0, 479.0))
	if outline:
		_canvas.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 6, 2, Color(0, 0, 0, 0.8))
	else:
		_canvas.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 6, Color(1, 1, 1, 0.85))
