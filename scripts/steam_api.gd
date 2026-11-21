class_name SteamApi
## Static facade over the SteamSvc autoload (scripts/steam_service.gd), like Net
## over NetSvc: script-mode tests with no autoloads still compile and behave as
## "Steam absent". Every function is a safe no-op returning a default when Steam
## is off (web, phones, CI, no client, no App ID yet).

static var _node: SteamService = null


static func i() -> SteamService:
	if _node == null or not is_instance_valid(_node):
		_node = null
		var ml := Engine.get_main_loop()
		if ml is SceneTree and (ml as SceneTree).root.has_node("SteamSvc"):
			_node = (ml as SceneTree).root.get_node("SteamSvc") as SteamService
	return _node


## True only when the GodotSteam backend initialised (desktop + Steam client).
static func active() -> bool:
	var n := i()
	return n != null and n.is_on()


## "steam" or "local": the backend switch for achievements, stats, presence.
static func backend() -> String:
	var n := i()
	return n.backend() if n else "local"


static func unlock_achievement(id: String) -> bool:
	var n := i()
	return n != null and n.unlock_achievement(id)


static func is_achievement_unlocked(id: String) -> bool:
	var n := i()
	return n != null and n.is_achievement_unlocked(id)


static func indicate_progress(id: String, current: int, maximum: int) -> bool:
	var n := i()
	return n != null and n.indicate_progress(id, current, maximum)


static func set_stat(name: String, value: int) -> bool:
	var n := i()
	return n != null and n.set_stat(name, value)


static func get_stat(name: String) -> int:
	var n := i()
	return n.get_stat(name) if n else 0


static func store_stats() -> bool:
	var n := i()
	return n != null and n.store_stats()


static func set_rich_presence(key: String, value: String) -> bool:
	var n := i()
	return n != null and n.set_rich_presence(key, value)


static func clear_rich_presence() -> bool:
	var n := i()
	return n != null and n.clear_rich_presence()


static func persona_name() -> String:
	var n := i()
	return n.persona_name() if n else ""


static func is_on_deck() -> bool:
	var n := i()
	return n != null and n.is_on_deck()


static func show_floating_text_input(mode: int, rect: Rect2i) -> bool:
	var n := i()
	return n != null and n.show_floating_text_input(mode, rect)


static func show_gamepad_text_input(description: String, preset: String, max_chars: int) -> bool:
	var n := i()
	return n != null and n.show_gamepad_text_input(description, preset, max_chars)


## Any other GodotSteam method (lobbies, networking); null when Steam is off.
static func call_steam(method: String, args: Array = []) -> Variant:
	var n := i()
	return n.call_steam(method, args) if n else null


static func connect_steam(sig: String, cb: Callable) -> bool:
	var n := i()
	return n != null and n.connect_steam(sig, cb)
