extends Node
class_name SteamService
## SteamService (autoload "SteamSvc"; S1 P1): the ONE place that talks to the
## GodotSteam GDExtension. Steam is optional: on web, phones, CI, headless runs,
## builds without the addon or with no Steam client running, the backend is
## "local" and every call below is a safe no-op that returns a default.
## Code elsewhere uses the static facade SteamApi (scripts/steam_api.gd).
##
## Never write the engine singleton's name as an identifier anywhere (the web
## build has no addon, so it would be a parse error): everything goes through
## `_s.call("method", ...)`. tools/web_export_guard.py --static enforces it.
##
## App ids: APP_ID_RELEASE is 0 until Tom's Steamworks account exists (docs/STEAM.md,
## "When Tom's Steamworks account is ready"). Test app 480 (Spacewar) is used only
## by debug builds or with DREAMS_STEAM_TEST=1 / --steam-test, set in code: no
## steam_appid.txt file is ever needed or shipped.

signal overlay_toggled(active: bool)
## Steam's gamepad text input closed: submitted false = cancelled.
signal text_input_done(submitted: bool, text: String)

const APP_ID_RELEASE := 0
const APP_ID_DEV := 480
const SINGLETON := "Steam"
## ESteamAPIInitResult / text-input enums as local ints (no engine constants).
const INIT_OK := 0
const FLOATING_SINGLE_LINE := 0
const FLOATING_MULTI_LINE := 1
const FLOATING_EMAIL := 2
const FLOATING_NUMERIC := 3
const GAMEPAD_INPUT_NORMAL := 0
const GAMEPAD_LINE_SINGLE := 0

var _s: Object = null
var _backend := "local"
## Why Steam is off ("web", "headless", "ci", "disabled", "no_addon", "no_app_id",
## "init_failed: ...") or "" when on. Printed by the boot probe.
var reason := ""
var app_id := 0
var _stats_dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	reason = absent_reason()
	if reason != "":
		return
	var id := pick_app_id(APP_ID_RELEASE, OS.is_debug_build(), _test_flag())
	if id <= 0:
		reason = "no_app_id"
		return
	_start(Engine.get_singleton(SINGLETON), id)


## Why Steam stays off on this run, or "" when it may start.
func absent_reason() -> String:
	if not available_on(OS.get_name(), OS.has_feature("web") or OS.has_feature("mobile")):
		return "web"
	if DisplayServer.get_name() == "headless":
		return "headless"
	if OS.get_environment("CI") != "":
		return "ci"
	if OS.get_environment("DREAMS_NO_STEAM") == "1" or "--no-steam" in OS.get_cmdline_user_args():
		return "disabled"
	if not Engine.has_singleton(SINGLETON):
		return "no_addon"
	return ""


## Steam only ever runs on Windows and Linux desktop builds.
static func available_on(os_name: String, is_web_or_mobile: bool) -> bool:
	if is_web_or_mobile:
		return false
	return os_name in ["Windows", "Linux", "FreeBSD"]


## The real id once set; 480 only for debug builds or an explicit test flag.
static func pick_app_id(release_id: int, debug_build: bool, test_flag: bool) -> int:
	if release_id > 0:
		return release_id
	if debug_build or test_flag:
		return APP_ID_DEV
	return 0


func _test_flag() -> bool:
	return OS.get_environment("DREAMS_STEAM_TEST") == "1" or "--steam-test" in OS.get_cmdline_user_args()


func _start(obj: Object, id: int) -> void:
	if obj == null:
		reason = "no_addon"
		return
	app_id = id
	OS.set_environment("SteamAppId", str(id))
	OS.set_environment("SteamGameId", str(id))
	if id == APP_ID_RELEASE and not OS.is_debug_build() and obj.has_method("restartAppIfNecessary"):
		if bool(obj.call("restartAppIfNecessary", id)):
			get_tree().quit()
			return
	var res: Variant = obj.call("steamInitEx", id, false) if obj.has_method("steamInitEx") else null
	var status := -1
	var verbal := "no steamInitEx"
	if res is Dictionary:
		status = int((res as Dictionary).get("status", -1))
		verbal = str((res as Dictionary).get("verbal", ""))
	if status != INIT_OK:
		reason = "init_failed: %d %s" % [status, verbal]
		return
	_s = obj
	_backend = "steam"
	reason = ""
	_hook("overlay_toggled", _on_overlay)
	_hook("gamepad_text_input_dismissed", _on_text_dismissed)
	set_process(true)


## Tests only: route every call to a fake object with the same method names
## (tools/steam_service_test.gd). Pass null to go back to local.
func inject(obj: Object) -> void:
	_s = obj
	_backend = "steam" if obj != null else "local"
	reason = "" if obj != null else "injected_none"


func _hook(sig: String, cb: Callable) -> void:
	if _s and _s.has_signal(sig) and not _s.is_connected(sig, cb):
		_s.connect(sig, cb)


func _process(_dt: float) -> void:
	if _s == null:
		return
	if _s.has_method("run_callbacks"):
		_s.call("run_callbacks")
	if _stats_dirty:
		_stats_dirty = false
		_call("storeStats")


func _call(method: String, args: Array = []) -> Variant:
	if _s == null or not _s.has_method(method):
		return null
	return _s.callv(method, args)


# --- state ---

func backend() -> String:
	return _backend


func is_on() -> bool:
	return _s != null


## Passthrough for other Steam features (lobbies, networking: scripts/net_transport_steam.gd).
## Returns null when Steam is off or the method does not exist.
func call_steam(method: String, args: Array = []) -> Variant:
	return _call(method, args)


## Connect a GodotSteam signal (e.g. "lobby_created") when Steam is on.
func connect_steam(sig: String, cb: Callable) -> bool:
	if _s == null or not _s.has_signal(sig):
		return false
	if not _s.is_connected(sig, cb):
		_s.connect(sig, cb)
	return true


# --- achievements and stats (stored once per frame at most) ---

func unlock_achievement(id: String) -> bool:
	if _s == null:
		return false
	_call("setAchievement", [id])
	_stats_dirty = true
	return true


func clear_achievement(id: String) -> bool:
	if _s == null:
		return false
	_call("clearAchievement", [id])
	_stats_dirty = true
	return true


func is_achievement_unlocked(id: String) -> bool:
	var r: Variant = _call("getAchievement", [id])
	return r is Dictionary and bool((r as Dictionary).get("achieved", false))


func indicate_progress(id: String, current: int, maximum: int) -> bool:
	if _s == null:
		return false
	_call("indicateAchievementProgress", [id, current, maximum])
	return true


func set_stat(name: String, value: int) -> bool:
	if _s == null:
		return false
	_call("setStatInt", [name, value])
	_stats_dirty = true
	return true


func get_stat(name: String) -> int:
	var r: Variant = _call("getStatInt", [name])
	return int(r) if r != null else 0


func store_stats() -> bool:
	if _s == null:
		return false
	_stats_dirty = false
	_call("storeStats")
	return true


# --- rich presence ---

func set_rich_presence(key: String, value: String) -> bool:
	if _s == null:
		return false
	return bool(_call("setRichPresence", [key, value]))


func clear_rich_presence() -> bool:
	if _s == null:
		return false
	_call("clearRichPresence")
	return true


# --- user, device, text input ---

func persona_name() -> String:
	var r: Variant = _call("getPersonaName")
	return str(r) if r != null else ""


func is_on_deck() -> bool:
	return bool(_call("isSteamRunningOnSteamDeck")) if _s else false


## Big Picture / Deck floating keyboard over a text field (rect in window pixels).
func show_floating_text_input(mode: int, rect: Rect2i) -> bool:
	if _s == null:
		return false
	return bool(_call("showFloatingGamepadTextInput", [mode, rect.position.x, rect.position.y, rect.size.x, rect.size.y]))


## Full-screen gamepad text input; the result arrives as text_input_done.
func show_gamepad_text_input(description: String, preset: String, max_chars: int) -> bool:
	if _s == null:
		return false
	return bool(_call("showGamepadTextInput", [GAMEPAD_INPUT_NORMAL, GAMEPAD_LINE_SINGLE, description, max_chars, preset]))


func _on_overlay(active: bool, _user_initiated := false, _app := 0) -> void:
	overlay_toggled.emit(active)


func _on_text_dismissed(submitted: bool, text: String = "", _app := 0) -> void:
	if submitted and text == "":
		var r: Variant = _call("getEnteredGamepadTextInput")
		if r is Dictionary:
			text = str((r as Dictionary).get("text", ""))
		elif r is String:
			text = r
	text_input_done.emit(submitted, text)
