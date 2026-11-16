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
	"menu": [KEY_ESCAPE, KEY_TAB, KEY_M],
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
