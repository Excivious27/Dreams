class_name InputSetup
extends RefCounted
## Game actions and their keyboard keys. Touch controls press the same actions.

const KEYS := {
	"up": [KEY_UP, KEY_W],
	"down": [KEY_DOWN, KEY_S],
	"left": [KEY_LEFT, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"a": [KEY_Z, KEY_SPACE, KEY_ENTER],
	"b": [KEY_X, KEY_SHIFT],
	"menu": [KEY_ESCAPE, KEY_TAB, KEY_M, KEY_E],
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
