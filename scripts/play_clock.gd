class_name PlayClock
extends RefCounted
## Game-time clock (C9 P4): seconds of unpaused play since the app started.
## Ticked by DisplayMode._process (autoload, runs always) only while the tree is
## not paused, so timers on it stop under menus, full-screen screens and the
## focus-loss pause. Use it instead of Time.get_ticks_msec() for gameplay timers
## (sleep spells, the pup's knocked-down window, turret hit cooldowns).

static var _t := 0.0
static var _frame := -1


static func tick(delta: float, paused: bool) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	if not paused:
		_t += delta


static func now() -> float:
	return _t


static func ms() -> int:
	return int(_t * 1000.0)


## Tests.
static func advance(sec: float) -> void:
	_t += sec
