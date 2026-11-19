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
##   Emote menu               Y
##   Chat                     T   (unused here)
## Touch controls press the same actions ("a" is the generic mobile button:
## check if something's there, otherwise use the tool).
## Bindings can be changed in Options → Key bindings; overrides are saved in
## SaveGame under "keys" as {action: [keycodes]}.

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
	"emote": [KEY_Y],
	"cycle_tool": [KEY_TAB],
	"a": [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	"slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9], "slot_10": [KEY_0], "slot_11": [KEY_MINUS], "slot_12": [KEY_EQUAL],
}

## What the bindings page shows, in Stardew's order, with Stardew's labels.
const SHOWN := [
	["up", "Move Up"], ["left", "Move Left"], ["down", "Move Down"], ["right", "Move Right"],
	["tool", "Use Tool"], ["action", "Action"], ["b", "Run"], ["menu", "Menu"],
	["journal", "Journal"], ["map", "Map"], ["emote", "Emote"], ["cycle_tool", "Shift Toolbar"],
	["a", "Confirm (mobile A)"],
	["slot_1", "Toolbar 1"], ["slot_2", "Toolbar 2"], ["slot_3", "Toolbar 3"], ["slot_4", "Toolbar 4"],
	["slot_5", "Toolbar 5"], ["slot_6", "Toolbar 6"], ["slot_7", "Toolbar 7"], ["slot_8", "Toolbar 8"],
	["slot_9", "Toolbar 9"], ["slot_10", "Toolbar 10"], ["slot_11", "Toolbar 11"], ["slot_12", "Toolbar 12"],
]

static var _ready := false


static func ensure_actions() -> void:
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


static func apply(map: Dictionary) -> void:
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, ev)


## Rebind: the new key becomes the action's primary key (secondary keeps the
## default alternate). Any other action using that key loses it.
static func rebind(action: String, key: Key) -> void:
	var map := keys()
	for other: String in map:
		if other != action:
			(map[other] as Array).erase(int(key))
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
