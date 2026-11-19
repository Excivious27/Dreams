class_name TapInput
extends RefCounted
## One finger tap = one tap, for drawn full-screen panels that read taps through
## a Control's gui_input (PrizeScreen, Bowling, HackGame, Epilogue...).
##
## On a phone Godot sends a Control BOTH an InputEventScreenTouch and a mouse
## event emulated from it (device DEVICE_ID_EMULATION) for every touch, so a
## handler that accepts both runs twice per tap: a prize tapped once was picked
## AND bought, bowling's quit button armed and fired at once, a hack arrow
## counted double. These helpers drop the emulated copy (a real mouse on
## desktop still works).
##
##   var p := TapInput.press_pos(ev)       # Vector2.INF unless a fresh press
##   if TapInput.is_release(ev): ...


## True for the emulated mouse copy of a touch (skip it: the touch itself comes too).
static func is_echo(ev: InputEvent) -> bool:
	return ev is InputEventMouse and ev.device == InputEvent.DEVICE_ID_EMULATION


## Where a press landed (left mouse button or a finger), or Vector2.INF.
static func press_pos(ev: InputEvent) -> Vector2:
	if is_echo(ev):
		return Vector2.INF
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return mb.position if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT else Vector2.INF
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		return st.position if st.pressed else Vector2.INF
	return Vector2.INF


## A finger lifted or the left button let go (not counting emulated copies).
static func is_release(ev: InputEvent) -> bool:
	if is_echo(ev):
		return false
	if ev is InputEventMouseButton:
		return not (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if ev is InputEventScreenTouch:
		return not (ev as InputEventScreenTouch).pressed
	return false
