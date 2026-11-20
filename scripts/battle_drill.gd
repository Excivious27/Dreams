class_name BattleDrill
extends Control
## The guided training fight (CampaignGate.launch_drill): six short steps on
## the orchard field, each checked live against the Battle, with the veteran
## (Catkins / Sal) talking you through them and a step card on the HUD.
##   move   walk into a ring        build   a helper at a point you hold
##   follow RALLY: follow me        menu    the point menu (upgrade/fortify/mend/barrage)
##   send   RALLY to a point        take    capture their last point: win
## Foes only come once you're told to go and take their point.

const STEPS := [
	["move", "Take a point", "Walk into the ring at %s and stand in it with no foes on it. When it fills, it's yours. Follow the arrow."],
	["build", "Build helpers", "At the banner of a point you hold, press USE (A) and build a %s. It turns out helpers."],
	["follow", "Rally: follow me", "Tap RALLY (top left) and pick \"Follow me\". Once your first helper steps out, it walks with you."],
	["menu", "The point menu", "USE a banner you hold again. Supply buys Upgrade, Fortify, Mend and Barrage. Try one."],
	["send", "Rally to a point", "Tap RALLY and send everyone to %s. They go on ahead."],
	["take", "Capture and win", "Take %s: break their guards and stand in the ring. Hold every point to win."],
]
## What the trainer says out loud for each step (the card carries the details).
const SAY := [
	"First, take %s. Stand in its ring till it fills.",
	"Good. Now build helpers at your banner.",
	"Now have them follow you: RALLY, then Follow me.",
	"Your banner does more than build. Have a look.",
	"Send them on ahead to %s.",
	"Last one: take %s. These are practice foes, so go at them.",
]
const CARD := Rect2(20, 292, 230, 52)   # above the touch deck, clear of the rings up top

var b: Battle
var step := 0
var _said := -1
var _t := 0.0
var _done_t := 0.0
var xp := 0          # strategist XP earned in the drill, paid in one go at the end


static func attach(bt: Battle, layer: CanvasLayer) -> BattleDrill:
	var dr := BattleDrill.new()
	dr.b = bt
	dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dr.size = Vector2(270, 480)
	layer.add_child(dr)
	return dr


func _mill() -> Dictionary:
	for p in b.points:
		if str(p["owner"]) == "enemy" or str(p["id"]) == "b":
			return p
	return b.points.back()


func _post() -> Dictionary:
	for p in b.points:
		if str(p["owner"]) == "neutral" or str(p["id"]) == "d":
			return p
	return b.points[1] if b.points.size() > 1 else b.points[0]


## Foes come only once you're sent to take their point.
func waves_on() -> bool:
	return step >= 4


func text(i: int) -> String:
	var t := str(STEPS[i][2])
	match str(STEPS[i][0]):
		"move":
			return t % str(_post()["name"])
		"build":
			return t % str(HelperUnit.KINDS["striker"]["crystal" if GameState.is_penguins() else "drone"])
		"send", "take":
			return t % str(_mill()["name"])
	return t


func say_line(i: int) -> String:
	var t := str(SAY[i])
	match str(STEPS[i][0]):
		"move":
			return t % str(_post()["name"])
		"send", "take":
			return t % str(_mill()["name"])
	return t


func _check() -> bool:
	match str(STEPS[step][0]):
		"move":
			return b.points.filter(func(p: Dictionary) -> bool: return str(p["owner"]) == "ally").size() >= 2
		"build":
			return b.points.any(func(p: Dictionary) -> bool: return str(p["spawner"]) != "")
		"follow":
			return b._rally == -1 and b._helpers() > 0  # waits for a helper to follow you
		"menu":
			return b._mend_cd > 0.0 or b._barrage_cd > 0.0 or b.points.any(func(p: Dictionary) -> bool: return bool(p.get("fort", false)) or int(p.get("lvl", 1)) > 1)
		"send":
			return b._rally >= 0 and b.points[b._rally] == _mill()
		"take":
			return b.points.all(func(p: Dictionary) -> bool: return str(p["owner"]) == "ally")
	return false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if b == null or not is_instance_valid(b) or b._over or get_tree().paused:
		return
	if _said != step:
		_said = step
		_intro_step()
		return
	if Dialogue.instance(get_tree()).active:
		return
	if step < STEPS.size() and _check():
		_done_t += delta
		if _done_t < 0.4:
			return
		_done_t = 0.0
		if step < STEPS.size() - 1:
			Music.instance(get_tree()).sfx("quest_done", "levelup")  # the last step: the win jingle covers it (c6_11)
		xp += 8
		if step == STEPS.size() - 1:
			b._end(true)
			return
		step += 1
		if str(STEPS[step][0]) == "send":
			_guard_mill()


func _intro_step() -> void:
	var lines: Array = [{"who": b._who(), "text": say_line(step)}]
	if step == 0:
		lines.push_front({"who": b._who(), "text": "Right. A short drill before anyone trusts you with %s. Six steps, no rush. The card below has each one." % ("an army" if GameState.is_penguins() else "a crew")})
	b.map.later(func() -> void: await b.map.say(lines))


## Two sleepy guards on their point, so the last step has something to break.
func _guard_mill() -> void:
	var p := _mill()
	var kinds: Array = b.d.get("enemies", ["grump"])
	for k in 2:
		var e := b.map.spawn_enemy(str(kinds[k % kinds.size()]), p["pos"] + Vector2(randf_range(-20, 20), randf_range(-16, 16)), 0)
		if e:
			e.reward = maxi(1, e.reward / 2)


func _draw() -> void:
	if b == null or not is_instance_valid(b) or b._over:
		return  # the card leaves with the win
	if Dialogue.instance(get_tree()).active:
		return  # the trainer is talking: the card waits
	var f := ThemeDB.fallback_font
	var i := mini(step, STEPS.size() - 1)
	var body := text(i)
	var bh := f.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 12, 7).y
	var r := Rect2(CARD.position, Vector2(CARD.size.x, maxf(CARD.size.y, 20.0 + bh)))
	draw_rect(r, Color(0.08, 0.06, 0.1, 0.88))
	draw_rect(r, Color(1, 0.85, 0.45, 0.9), false, 1.0)
	var head := "TRAINING %d/%d · %s" % [i + 1, STEPS.size(), str(STEPS[i][1])]
	var wh := Art.tex("ui", "icon_whistle")
	var hx := 6.0
	if wh:
		draw_texture_rect(wh, Rect2(r.position + Vector2(4, 2), Vector2(12, 12)), false)
		hx = 19.0
	draw_string_outline(f, r.position + Vector2(hx, 11), head, HORIZONTAL_ALIGNMENT_LEFT, 170, 8, 3, Color(0, 0, 0, 0.8))
	draw_string(f, r.position + Vector2(hx, 11), head, HORIZONTAL_ALIGNMENT_LEFT, 170, 8, Color(1, 0.88, 0.5))
	# Progress pips (a finished step is green; the last one too once it's done).
	var done_now := step < STEPS.size() and _done_t > 0.0
	for k in STEPS.size():
		var c := Vector2(r.end.x - 8 - (STEPS.size() - 1 - k) * 8, r.position.y + 8)
		var green := k < step or (k == step and done_now)
		Art.draw_disc(self, c, 3.0, Color(0.5, 1, 0.6) if green else (Color(1, 0.88, 0.5, 0.6 + 0.4 * sin(_t * 5.0)) if k == step else Color(1, 1, 1, 0.25)))
	draw_multiline_string(f, r.position + Vector2(6, 23), body, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 7, 3, Color(0.95, 0.93, 0.88))
