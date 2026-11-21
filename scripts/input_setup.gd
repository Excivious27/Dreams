class_name InputSetup
extends RefCounted
## Game actions and their keys, matching Stardew Valley's PC defaults exactly:
##   Move up/left/down/right  W A S D (+ arrows)
##   Use Tool                 C  (+ left click, toward the cursor)
##   Action / check / talk    X  (+ right click)
##   Run                      Left Shift
##   Menu (inventory)         E / Esc
##   Journal (quests)         F
##   Map                      M
##   Toolbar slots            1 2 3 4 5 6 7 8 9 0 - =
##   Shift toolbar row        Tab  (mouse wheel cycles the selected slot)
##   (Emote / Y: dropped in S1, nothing read it; saved "emote" keys are ignored)
##   Toolbar back             Q   (C9: LB on a pad)
##   Partner ability          R   (C9: RT on a pad; B-hold still works)
##   Pup command (cycle)      G   (C9: R3 on a pad)
##   Battle rally orders      T   (C9: L3 on a pad; battlefields only)
## Touch controls press the same actions ("a" is the generic mobile button:
## check if something's there, otherwise use the tool).
## Bindings can be changed in Options → Key bindings; overrides are saved in
## SaveGame under "keys" as {action: [keycodes]}.
## Gamepads (C9 P1): PAD_DEFAULTS binds every action to a controller (Xbox
## names, Stardew-controller layout); overrides live in SaveGame "pads" as
## {action: [pad codes]}. A pad code < AXIS_BASE is a JoyButton; AXIS_BASE +
## axis*2 (+1 for the positive side) is a stick/trigger direction.
## Prompts per device: InputSetup.prompt(action) ("USE" on touch, "C" on keys,
## "X"/"□" on a pad); PadInput tracks the device and emits device_changed.

const DEFAULTS := {
	"up": [KEY_W, KEY_UP],
	"down": [KEY_S, KEY_DOWN],
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"tool": [KEY_C],
	"action": [KEY_X],
	"b": [KEY_SHIFT],
	"menu": [KEY_E, KEY_ESCAPE],
	"dodge": [KEY_V],
	"journal": [KEY_F],
	"map": [KEY_M],
	"cycle_tool": [KEY_TAB],
	"cycle_back": [KEY_Q],
	"ability": [KEY_R],
	"pup": [KEY_G],
	"rally": [KEY_T],
	"a": [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	"slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9], "slot_10": [KEY_0], "slot_11": [KEY_MINUS], "slot_12": [KEY_EQUAL],
}

const AXIS_BASE := 100
const STICK_DEADZONE := 0.25  ## movement actions: below this a stick tilt is no move
## Controller layout. Movement (d-pad + left stick) can't be rebound.
const PAD_DEFAULTS := {
	"up": [JOY_BUTTON_DPAD_UP, AXIS_BASE + JOY_AXIS_LEFT_Y * 2],
	"down": [JOY_BUTTON_DPAD_DOWN, AXIS_BASE + JOY_AXIS_LEFT_Y * 2 + 1],
	"left": [JOY_BUTTON_DPAD_LEFT, AXIS_BASE + JOY_AXIS_LEFT_X * 2],
	"right": [JOY_BUTTON_DPAD_RIGHT, AXIS_BASE + JOY_AXIS_LEFT_X * 2 + 1],
	"a": [JOY_BUTTON_A],
	"b": [JOY_BUTTON_B],
	"tool": [JOY_BUTTON_X],
	"action": [JOY_BUTTON_Y],
	"menu": [JOY_BUTTON_START],
	"map": [JOY_BUTTON_BACK],
	"cycle_back": [JOY_BUTTON_LEFT_SHOULDER],
	"cycle_tool": [JOY_BUTTON_RIGHT_SHOULDER],
	"dodge": [AXIS_BASE + JOY_AXIS_TRIGGER_LEFT * 2 + 1],
	"ability": [AXIS_BASE + JOY_AXIS_TRIGGER_RIGHT * 2 + 1],
	"pup": [JOY_BUTTON_RIGHT_STICK],
	"rally": [JOY_BUTTON_LEFT_STICK],
}
const PAD_FIXED := ["up", "down", "left", "right"]
## Godot's own ui_* actions get pad A/B so focus-driven Button screens (PadFocus) work.
const UI_PAD := {"ui_accept": [JOY_BUTTON_A], "ui_cancel": [JOY_BUTTON_B]}
## Button names per controller family (PadInput.kind).
const PAD_NAMES := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", "lt": "LT", "rt": "RT"},
	"ps": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle", JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", "lt": "L2", "rt": "R2"},
	# S1 s1_08-02: the Steam Deck's built-in controls (Steam's Deck glyph names).
	"deck": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", "lt": "L2", "rt": "R2"},
	# Nintendo layout: Godot's A (bottom) is the Switch's B.
	"switch": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_BACK: "-", JOY_BUTTON_START: "+", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", "lt": "ZL", "rt": "ZR"},
}
## What the touch pad calls each action (TouchControls.BUTTONS labels).
const TOUCH_WORDS := {"a": "USE", "action": "CHECK", "menu": "MENU", "dodge": "ROLL", "pup": "CALL", "tool": "USE", "b": "B", "ability": "♥", "rally": "HELPERS"}

## What the bindings page shows, in Stardew's order, with Stardew's labels.
const SHOWN := [
	["up", "Move Up"], ["left", "Move Left"], ["down", "Move Down"], ["right", "Move Right"],
	["tool", "Use Tool"], ["action", "Action"], ["b", "Run"], ["menu", "Menu"],
	["journal", "Journal"], ["map", "Map"], ["cycle_tool", "Shift Toolbar"],
	["cycle_back", "Toolbar Back"], ["dodge", "Dodge"], ["ability", "Partner Ability"], ["pup", "Pup Command"],
	["rally", "Helpers: orders"],
	["a", "Confirm (mobile A)"],
	["slot_1", "Toolbar 1"], ["slot_2", "Toolbar 2"], ["slot_3", "Toolbar 3"], ["slot_4", "Toolbar 4"],
	["slot_5", "Toolbar 5"], ["slot_6", "Toolbar 6"], ["slot_7", "Toolbar 7"], ["slot_8", "Toolbar 8"],
	["slot_9", "Toolbar 9"], ["slot_10", "Toolbar 10"], ["slot_11", "Toolbar 11"], ["slot_12", "Toolbar 12"],
]

static var _ready := false


static func ensure_actions() -> void:
	PadInput.install()
	if _ready:
		return
	_ready = true
	apply(keys())


## Current bindings: defaults with any saved overrides on top.
static func keys() -> Dictionary:
	var out := {}
	for action: String in DEFAULTS:
		out[action] = (DEFAULTS[action] as Array).duplicate()
	var saved: Dictionary = SaveGame.get_value("keys", {})
	for action: String in saved:
		if out.has(action):
			var arr: Array = []
			for k in saved[action]:
				arr.append(int(k))
			out[action] = arr
	return out


static func apply(map: Dictionary, pad_map := {}) -> void:
	if pad_map.is_empty():
		pad_map = pads()
	_prompts.clear()
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		if action in PAD_FIXED:
			InputMap.action_set_deadzone(action, STICK_DEADZONE)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, ev)
		for code in pad_map.get(action, []):
			InputMap.action_add_event(action, pad_event(int(code)))
	for ui: String in UI_PAD:
		if not InputMap.has_action(ui):
			continue
		for code in UI_PAD[ui]:
			var have := false
			for e in InputMap.action_get_events(ui):
				if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == code:
					have = true
			if not have:
				InputMap.action_add_event(ui, pad_event(int(code)))


## The InputEvent for a pad code (device -1 = every pad).
static func pad_event(code: int) -> InputEvent:
	if code >= AXIS_BASE:
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = ((code - AXIS_BASE) / 2) as JoyAxis
		m.axis_value = 1.0 if (code - AXIS_BASE) % 2 == 1 else -1.0
		return m
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = code as JoyButton
	return b


## The pad code an event would bind to, or -1 (sticks need a firm push).
static func pad_code_of(ev: InputEvent) -> int:
	if ev is InputEventJoypadButton:
		return int((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.6:
		var m := ev as InputEventJoypadMotion
		return AXIS_BASE + int(m.axis) * 2 + (1 if m.axis_value > 0.0 else 0)
	return -1


## Current pad bindings: PAD_DEFAULTS with SaveGame "pads" overrides on top.
static func pads() -> Dictionary:
	var out := {}
	for action: String in PAD_DEFAULTS:
		out[action] = (PAD_DEFAULTS[action] as Array).duplicate()
	var saved: Dictionary = SaveGame.get_value("pads", {})
	for action: String in saved:
		if out.has(action) and not (action in PAD_FIXED):
			var arr: Array = []
			for k in saved[action]:
				arr.append(int(k))
			out[action] = arr
	return out


## Rebind a pad button: it leaves any other action; that action gets this
## action's old button back so nothing is left without one. Returns the action
## that moved ("" if none), or "fixed" when the action/button can't change.
static func rebind_pad(action: String, code: int) -> String:
	if action in PAD_FIXED or not PAD_DEFAULTS.has(action) or code < 0:
		return "fixed"
	var map := pads()
	for f: String in PAD_FIXED:
		if code in (map[f] as Array):
			return "fixed"  # d-pad / left stick stay movement
	var old: Array = map[action]
	var moved := ""
	for other: String in map:
		if other != action and code in (map[other] as Array):
			(map[other] as Array).erase(code)
			if (map[other] as Array).is_empty() and not old.is_empty():
				(map[other] as Array).append(int(old[0]))
			moved = other
	map[action] = [code]
	var saved := {}
	for a: String in map:
		if map[a] != PAD_DEFAULTS[a]:
			saved[a] = map[a]
	SaveGame.set_value("pads", saved)
	apply(keys(), map)
	return moved


static func reset_pad() -> void:
	SaveGame.set_value("pads", {})
	apply(keys())


## The connected pad's name for a pad code ("A", "Cross", "LT", "Stick up").
static func pad_code_label(code: int, kind := "") -> String:
	if kind == "":
		kind = PadInput.kind
	var names: Dictionary = PAD_NAMES.get(kind, PAD_NAMES["xbox"])
	if code >= AXIS_BASE:
		var axis := (code - AXIS_BASE) / 2
		var pos := (code - AXIS_BASE) % 2 == 1
		if axis == JOY_AXIS_TRIGGER_LEFT:
			return str(names["lt"])
		if axis == JOY_AXIS_TRIGGER_RIGHT:
			return str(names["rt"])
		var dir := ("right" if pos else "left") if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X] else ("down" if pos else "up")
		return "Stick " + dir
	if code in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		return "D-pad " + str({JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down", JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right"}[code])
	return str(names.get(code, "Button %d" % code))


## The pad button for an action on the connected pad ("A", "Cross"...).
static func pad_label(action: String, kind := "") -> String:
	var codes: Array = pads().get(action, [])
	return pad_code_label(int(codes[0]), kind) if not codes.is_empty() else "—"


## The word to show for an action on the device in use: the touch pad's label,
## the first key, or the pad button. Hints and tips go through this.
static var _prompts := {}  # "dev|kind|action" -> word (cleared by apply)


static func prompt(action: String) -> String:
	var dev := PadInput.device_kind()
	var ck := "%s|%s|%s" % [dev, PadInput.kind, action]
	if not _prompts.has(ck):
		_prompts[ck] = _prompt_for(dev, action)
	return str(_prompts[ck])


static func _prompt_for(dev: String, action: String) -> String:
	if dev == "pad":
		return pad_label(action)
	if dev == "touch":
		return str(TOUCH_WORDS.get(action, action.to_upper()))
	var map := keys()
	var ks: Array = map.get(action, [])
	if ks.is_empty():
		return "—"
	var k := int(ks[0])
	var kc := k as Key if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(k as Key)
	return OS.get_keycode_string(kc)


## Rebind: the new key becomes the action's primary key (secondary keeps the
## default alternate). Any other action using that key loses it.
## Returns the action whose key moved ("" if none): if it would be left with no
## key it takes this action's old primary key instead (a swap, C9 c9_07).
static func rebind(action: String, key: Key) -> String:
	var map := keys()
	var old: Array = (map[action] as Array).duplicate()
	var moved := ""
	for other: String in map:
		if other != action and int(key) in (map[other] as Array):
			(map[other] as Array).erase(int(key))
			moved = other
			if (map[other] as Array).is_empty() and not old.is_empty() and int(old[0]) != int(key):
				(map[other] as Array).append(int(old[0]))
	var arr: Array = [int(key)]
	var defs: Array = DEFAULTS[action]
	if defs.size() > 1 and int(defs[1]) != int(key):
		arr.append(int(defs[1]))
	map[action] = arr
	var saved := {}
	for a: String in map:
		if map[a] != DEFAULTS[a]:
			saved[a] = map[a]
	SaveGame.set_value("keys", saved)
	apply(map)
	return moved


static func reset_bindings() -> void:
	SaveGame.set_value("keys", {})
	apply(keys())


static func key_label(action: String) -> String:
	var map := keys()
	var parts: Array = []
	for k in map.get(action, []):
		# The layout lookup needs a real display (headless test runs print an error per key).
		var kc := int(k) as Key if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(int(k) as Key)
		parts.append(OS.get_keycode_string(kc))
	return " / ".join(parts) if not parts.is_empty() else "—"


## True on the frame any confirm-style button was pressed (dialogue, menus).
static func confirm_pressed() -> bool:
	return Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action") or Input.is_action_just_pressed("tool")
