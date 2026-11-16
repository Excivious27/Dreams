class_name InputSetup
extends RefCounted
## Game actions and their keys, mapped like Stardew Valley's defaults:
##   move WASD / arrows · use tool C (left click) · check/do X (right click)
##   run Shift · menu Esc / E · inventory I · map M · journal F
##   toolbar 1-0 - = · cycle tool Tab / mouse wheel · confirm Space / Enter / Z
## Touch controls press the same actions ("a" is the generic mobile button:
## check if something's there, otherwise use the tool).

const KEYS := {
	"up": [KEY_UP, KEY_W],
	"down": [KEY_DOWN, KEY_S],
	"left": [KEY_LEFT, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"a": [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"tool": [KEY_C],
	"action": [KEY_X],
	"b": [KEY_SHIFT],
	"menu": [KEY_ESCAPE, KEY_E],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"journal": [KEY_F],
	"cycle_tool": [KEY_TAB],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	"slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9], "slot_10": [KEY_0], "slot_11": [KEY_MINUS], "slot_12": [KEY_EQUAL],
}


static func ensure_actions() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


## True on the frame any confirm-style button was pressed (dialogue, menus).
static func confirm_pressed() -> bool:
	return Input.is_action_just_pressed("a") or Input.is_action_just_pressed("action") or Input.is_action_just_pressed("tool")
