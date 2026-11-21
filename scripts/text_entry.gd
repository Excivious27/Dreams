class_name TextEntry
extends Node
## S1 s1_08-01 / s1_08-08: typing with only a controller (Steam Deck Verified).
## Installed under PadInput (no autoload). When a pad is the device and A is
## pressed on a focused LineEdit/TextEdit (or ScreenCursor presses one), the
## field opens for typing:
##   1. Steam's floating keyboard through SteamService (S1 P1), when Steam runs:
##      SteamService.show_floating_keyboard(multiline, rect) -> bool, and
##      SteamService calls TextEntry.steam_dismissed() on its
##      floating_gamepad_text_input_dismissed signal. Duck-typed: nothing here
##      names Steam, so the web build and Steam-less runs never load it.
##   2. Otherwise the built-in PadKeyboard (d-pad / stick to move, A types,
##      B deletes (closes when empty), MENU done, taps work too).
## Phones and keyboard players never see it (they type with their own keys).
##   TextEntry.open(field)    open typing for a field (any device)
##   TextEntry.is_open()      a keyboard owns the input right now
##   TextEntry.typing_field() the field being typed into, or null

## Tests: pretend SteamService accepted (1) / refused (0) the floating keyboard.
static var steam_force := -1
static var _inst: TextEntry = null
static var _kb: PadKeyboard = null
static var _steam_field: Control = null
static var steam_calls := 0


static func instance() -> TextEntry:
	return _inst if _inst != null and is_instance_valid(_inst) else null


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -200  # before PadInput (-100) and every screen: A on a field opens typing


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func is_open() -> bool:
	if _kb != null and is_instance_valid(_kb) and _kb.is_inside_tree():
		return true
	return _steam_field != null and is_instance_valid(_steam_field) and _steam_field.has_focus()


static func typing_field() -> Control:
	if _kb != null and is_instance_valid(_kb):
		return _kb.field
	if is_open():
		return _steam_field
	return null


static func editable(c: Control) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	if c is LineEdit:
		return (c as LineEdit).editable
	if c is TextEdit:
		return (c as TextEdit).editable
	return false


## Open typing for `field` (LineEdit or TextEdit). Returns "steam", "pad" or "".
static func open(field: Control) -> String:
	if not editable(field) or is_open():
		return ""
	var tree := field.get_tree()
	if _steam_try(field):
		_steam_field = field
		return "steam"
	_kb = PadKeyboard.new()
	_kb.field = field
	tree.root.add_child(_kb)
	return "pad"


static func _steam_try(field: Control) -> bool:
	steam_calls += 1
	if steam_force >= 0:
		if steam_force == 1:
			field.grab_focus()
		return steam_force == 1
	if OS.has_feature("web"):
		return false
	var ss := field.get_tree().root.get_node_or_null("SteamSvc")
	if ss == null or not ss.has_method("show_floating_keyboard"):
		return false
	field.grab_focus()
	var r := field.get_global_rect()
	var xf := field.get_viewport().get_final_transform()
	var px := Rect2i(Vector2i(xf * r.position), Vector2i(r.size * xf.get_scale()))
	return bool(ss.call("show_floating_keyboard", field is TextEdit, px))


## SteamService: Steam's floating keyboard closed.
static func steam_dismissed() -> void:
	if _steam_field != null and is_instance_valid(_steam_field):
		_steam_field.release_focus()
	_steam_field = null


static func _closed(kb: PadKeyboard) -> void:
	if _kb == kb:
		_kb = null


## Pad A on a focused text field opens typing. Caught in _input, before the
## GUI, so the LineEdit never takes the press as ui_accept (text_submitted).
func _input(ev: InputEvent) -> void:
	if is_open() or not (ev is InputEventJoypadButton) or not ev.is_action_pressed("a"):
		return
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner() if vp else null
	if editable(f):
		PadInput.note_event(ev, vp)  # handled here, so PadInput._input won't see it
		vp.set_input_as_handled()
		open(f)
		Input.action_release("a")  # the press that opened the keyboard types nothing


func _process(_d: float) -> void:
	if is_open() or not PadInput.using_pad():
		return
	if not Input.is_action_just_pressed("a"):
		return
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner() if vp else null
	if editable(f):
		open(f)
		Input.action_release("a")
