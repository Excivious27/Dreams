class_name Captions
extends CanvasLayer
## Sound captions (C13 P6, Options > Sound captions): short words for sounds a
## player who can't hear would miss ("[Thunder]", "[Door knock]"). `Music.sfx`
## calls `Captions.for_sfx(name)`; story and events may call `Captions.say(text)`.
## Lines stack at the top-middle above the toasts' row, fade after HOLD seconds.

## Captionable effects (played name -> words). Only sounds that carry meaning
## the screen may not show; UI clicks, steps and coins never caption.
const TABLE := {
	"thunder": "Thunder", "roar": "Roar", "growl": "Growling", "siren": "Siren", "alarm": "Alarm", "alert": "Alert!",
	"boom": "Explosion", "fireworks": "Fireworks", "door": "Door opens", "door_close": "Door closes", "knock": "Door knock",
	"car_horn": "Car horn", "car_start": "Engine starts", "horn": "Horn", "rooster": "Rooster crows", "crow": "Crow caws",
	"bark": "Barking", "howl_far": "Distant howl", "mail": "Mail arrived", "levelup": "Level up!", "quest_done": "Quest complete",
	"boss_down": "Boss defeated", "boss_fall": "Boss falls", "knockout": "Knocked out", "hurt": "Ouch", "fish_escape": "The fish got away",
	"bite": "Bite!", "splash": "Splash", "glass": "Glass breaks", "whistle": "Whistle", "heartbeat": "Heartbeat", "shot": "Gunshot",
	"shot_heavy": "Gunshot", "shot_rifle": "Rifle shot", "shot_shotgun": "Shotgun blast", "shot_smg": "Rapid fire",
	"reload": "Reloading", "clap": "Applause", "shop_bell": "Shop bell", "chest_open": "Chest opens", "j_morning": "Morning",
	"ach_unlock": "Achievement!", "energy_low": "You feel tired", "j_heart": "Heart up", "war_horn": "War horn", "war_drum": "War drums",
	"cv_merkitty": "Merkitty calls", "j_victory": "Victory!", "j_battle_won": "Battle won", "j_battle_lost": "Battle lost",
}
const HOLD := 2.2
const MAX_LINES := 3
## One caption per word within this many ms (a burst of shots is one line).
const GAP_MS := 1200

static var log: Array = []  # last 32 captions shown {text, kind} (tests)
static var _last := {}
static var _inst: Captions = null

var _box: VBoxContainer


static func for_sfx(name: String) -> void:
	if not Settings.captions_on():
		return
	var key := name
	if not TABLE.has(key) and key.ends_with("_gang"):
		key = key.trim_suffix("_gang")
	if not TABLE.has(key):
		return
	say(str(TABLE[key]), "sfx")


## Show a short caption (only when Sound captions is on).
static func say(text: String, kind := "") -> void:
	if not Settings.captions_on() or text == "":
		return
	var now := Time.get_ticks_msec()  # same real-time de-dupe as Music.sfx
	if now - int(_last.get(text, -100000)) < GAP_MS:
		return
	_last[text] = now
	log.append({"text": text, "kind": kind})
	if log.size() > 32:
		log.pop_front()
	var c := _layer()
	if c != null:
		c._add(text)


static func _layer() -> Captions:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = Captions.new()
	tree.root.add_child.call_deferred(_inst)
	return _inst


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = VBoxContainer.new()
	_box.position = Vector2(0, 62)  # DisplayMode centres the layer
	_box.size = Vector2(270, 60)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 1)
	add_child(_box)


func _add(text: String) -> void:
	while _box.get_child_count() >= MAX_LINES:
		var old := _box.get_child(0)
		_box.remove_child(old)
		old.queue_free()
	var l := Label.new()
	l.text = "[%s]" % text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(270, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", Settings.font(8))
	l.add_theme_color_override("font_color", Color(1, 1, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(HOLD * Settings.toast_hold())
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
