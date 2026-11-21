class_name BattleDrill
extends Control
## The guided training fight (CampaignGate.launch_drill): six short steps on
## the orchard field, each checked live against the Battle, with the veteran
## (Catkins / Sal) talking you through them and a step card on the HUD. One
## helper order per step (C11b P7: helpers follow you by default in the drill):
##   move   walk into a ring        build  "Build helper" at a point you hold
##   follow walk; it comes along    hold   HELPERS > Hold here
##   call   HELPERS > Follow me     menu   the point menu (upgrade/fortify/mend/barrage)
##   send   HELPERS > Go to a point take   capture their last point: win
## Foes only come once you're told to go and take their point. "Leave training"
## (button above the card; pause menu on a pad) ends it any time.

const STEPS := [
	["move", "Take a point", "Walk into the ring at %s and stay in it. When the ring fills, the point is yours. Follow the arrow."],
	["build", "Build a helper", "Stand at the banner of a point you hold, press %s and pick \"Build helper: %s\" (◇%d supply). Helpers then step out of that banner."],
	["follow", "Order: Follow me", "Helpers follow you unless you order otherwise. Walk a few steps and watch yours come along.%s"],
	["hold", "Order: Hold here", "%s and pick \"Hold here\". Your helpers go back and guard the banner that built them."],
	["call", "Order: Follow me", "%s and pick \"Follow me\" to call them back. They walk beside you again."],
	["menu", "Spend supply", "Press %s at your banner again. Supply buys Upgrade (more helpers), Fortify, Mend and Barrage. Try one."],
	["send", "Order: Go to a point", "%s and pick \"Go to %s\". Your helpers march there ahead of you."],
	["take", "Capture and win", "Take %s: break their guards and stand in the ring. Hold every point to win."],
]
## What the trainer says out loud for each step (the card carries the details).
const SAY := [
	"First, take %s. Stand in its ring till it fills.",
	"Good. Now build a helper at your banner.",
	"There it is. Helpers follow you unless told otherwise. Take a walk and see.",
	"Now give your first order: tell them to hold here.",
	"And call them back to you: Follow me.",
	"Your banner does more than build. Have a look.",
	"Last order: send them on ahead to %s.",
	"Last one: take %s. These are practice foes, so go at them.",
]
const CARD := Rect2(20, 292, 230, 52)   # above the touch deck, clear of the rings up top
## "Leave training": always on screen, in the step card's bottom-right corner (clear of
## the toasts and the touch deck); leave_rect is where it is now (the card grows) (C11b P7).
const LEAVE_SIZE := Vector2(80, 20)
const LEAVE_ROW := 23.0    # the card's extra bottom row that holds the button
var leave_rect := Rect2()
const WALK_NEED := 80.0    # px you walk with a helper beside you (5 cells) for "follow"
const NEAR := 56.0         # a helper this close counts as "with you"

var b: Battle
var step := 0
var _said := -1
var _t := 0.0
var _done_t := 0.0
var xp := 0          # strategist XP earned in the drill, paid in one go at the end
var _orders0 := 0    # Battle.orders when this step began (order steps need a new one)
var _walked := 0.0   # px walked during the follow step
var _last_p := Vector2.INF
var _helper_said := false
var leave_btn: Button


static func attach(bt: Battle, layer: CanvasLayer) -> BattleDrill:
	var dr := BattleDrill.new()
	dr.b = bt
	dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dr.size = Vector2(270, 480)
	layer.add_child(dr)
	var lb := Button.new()
	lb.text = "Leave training"
	lb.size = LEAVE_SIZE
	lb.focus_mode = Control.FOCUS_NONE
	lb.add_theme_font_size_override("font_size", 8)
	for st: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.32, 0.12, 0.1, 0.95) if st != "pressed" else Color(0.5, 0.2, 0.15, 1.0)
		sb.border_color = Color(1, 0.85, 0.45, 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		lb.add_theme_stylebox_override(st, sb)
	lb.pressed.connect(func() -> void: bt.map.later(dr.ask_leave))
	layer.add_child(lb)
	dr.leave_btn = lb
	dr._place_leave()
	return dr


func _exit_tree() -> void:
	Hud.extra_rects.erase(leave_rect)


## The step card's rect for the current step (its body text sets the height).
func card_rect() -> Rect2:
	var f := ThemeDB.fallback_font
	var i := mini(step, STEPS.size() - 1)
	var bh := f.get_multiline_string_size(text(i), HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 12, 7).y
	return Rect2(CARD.position, Vector2(CARD.size.x, maxf(CARD.size.y, 20.0 + bh) + LEAVE_ROW))


## Keep the button (and its tap rect) in the card's corner.
func _place_leave() -> void:
	if leave_btn == null or b == null:
		return
	var r := card_rect()
	var nr := Rect2(r.end - LEAVE_SIZE - Vector2(3, 2), LEAVE_SIZE)
	if nr != leave_rect:
		Hud.extra_rects.erase(leave_rect)
		leave_rect = nr
		Hud.extra_rects.append(leave_rect)
		leave_btn.position = nr.position


func idx(key: String) -> int:
	for i in STEPS.size():
		if str(STEPS[i][0]) == key:
			return i
	return -1


## The drill under way on the current map (null otherwise).
static func running(tree: SceneTree) -> BattleDrill:
	var gm := tree.current_scene as GameMap
	if gm == null:
		return null
	var bt: Variant = gm.get("battle")
	if bt is Battle and is_instance_valid(bt) and (bt as Battle).drill != null and not (bt as Battle)._over:
		return (bt as Battle).drill
	return null


## The pause menu's way out (pad and keys): GameMenu shows it while a drill runs.
static func menu_row(gm: Node) -> void:
	var dr := running(gm.get_tree())
	if dr == null:
		return
	gm.call("_button", "End training: back to where you were (try again any time)", func() -> void:
		gm.call("toggle")
		dr.leave())


## Leave with a confirm (B / "Not now" keeps training).
func ask_leave() -> void:
	if b == null or not is_instance_valid(b) or b._over:
		return
	var dl := Dialogue.instance(get_tree())
	if dl.active:
		return
	dl.say([{"who": b._who(), "text": "End training for now? Nothing is lost. Come back to Training on the campaign map any time.", "choice": ["End training now", "Not now, keep going"], "key": ""}])
	await dl.finished
	if dl.last_choice == 0:
		leave()


## Out of the drill at once: the field ends untaken, you go back where you were
## (unpaused), and the drill can be started again later (CampaignGate.drill_finish).
func leave() -> void:
	if b == null or not is_instance_valid(b) or b._over:
		return
	var dl := Dialogue.instance(get_tree())
	if dl.active:
		await dl.finished  # let the trainer finish the line on screen first
	if b == null or not is_instance_valid(b) or b._over:
		return
	b._end(false)


## How you give orders: the HELPERS button on touch, holding the rally button on a pad/keys.
static func order_how() -> String:
	if TouchControls.visible_controls:
		return "Tap HELPERS (top left)"
	return "Hold %s" % InputSetup.prompt("rally")


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
	return step >= idx("send")


func text(i: int) -> String:
	var t := str(STEPS[i][2])
	match str(STEPS[i][0]):
		"move":
			return t % str(_post()["name"])
		"build":
			return t % [InputSetup.prompt("a"), str(HelperUnit.KINDS["striker"]["crystal" if GameState.is_penguins() else "drone"]), b._cost("striker") if b else 20]
		"follow":
			return t % ((" (Staying put? %s and pick \"Follow me\".)" % order_how()) if b and b._rally != -1 else "")
		"hold", "call":
			return t % order_how()
		"menu":
			return t % InputSetup.prompt("a")
		"send":
			return t % [order_how(), str(_mill()["name"])]
		"take":
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


## A helper of yours within NEAR px of you.
func helper_near() -> bool:
	for h in b.map.get_tree().get_nodes_in_group("allies"):
		if h is HelperUnit and is_instance_valid(h) and (h as Node2D).position.distance_to(b.map.player.position) < NEAR:
			return true
	return false


func _check() -> bool:
	match str(STEPS[step][0]):
		"move":
			return b.points.filter(func(p: Dictionary) -> bool: return str(p["owner"]) == "ally").size() >= 2
		"build":
			return b.points.any(func(p: Dictionary) -> bool: return str(p["spawner"]) != "")
		"follow":
			return b._rally == -1 and _walked >= WALK_NEED and helper_near()  # you walked and it came along
		"hold":
			return b._rally == -2 and b.orders > _orders0
		"call":
			return b._rally == -1 and b.orders > _orders0 and b._helpers() > 0
		"menu":
			return b._mend_cd > 0.0 or b._barrage_cd > 0.0 or b.points.any(func(p: Dictionary) -> bool: return bool(p.get("fort", false)) or int(p.get("lvl", 1)) > 1)
		"send":
			return b._rally >= 0 and b.points[b._rally] == _mill() and b.orders > _orders0
		"take":
			return b.points.all(func(p: Dictionary) -> bool: return str(p["owner"]) == "ally")
	return false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if leave_btn:
		_place_leave()
		leave_btn.visible = b != null and is_instance_valid(b) and not b._over and not get_tree().paused and not Dialogue.instance(get_tree()).active
	if b == null or not is_instance_valid(b) or b._over or get_tree().paused:
		return
	if _said != step:
		_said = step
		_orders0 = b.orders
		_walked = 0.0
		_last_p = Vector2.INF
		_intro_step()
		return
	if Dialogue.instance(get_tree()).active:
		return
	# The first helper: one line on where it came from and what it does.
	if not _helper_said and b._helpers() > 0:
		_helper_said = true
		b.map.hud.toast("A helper stepped out of your banner. It follows you; %s gives it orders." % ("HELPERS (top left)" if TouchControls.visible_controls else InputSetup.prompt("rally")), Color(0.7, 0.95, 1.0))
	if b.map.player:
		var pp := b.map.player.position
		if _last_p != Vector2.INF and str(STEPS[step][0]) == "follow" and helper_near():
			_walked += minf(4.0, pp.distance_to(_last_p))  # (a warp or a teleport doesn't count)
		_last_p = pp
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
		lines.push_front({"who": b._who(), "text": "Right. A short drill before anyone trusts you with %s. %d steps, no rush. The card below has each one, and \"Leave training\" ends it any time." % ["an army" if GameState.is_penguins() else "a crew", STEPS.size()]})
		if TouchControls.visible_controls:
			lines.append({"who": b._who(), "text": "The paw buttons on the left are your pup's. Your helpers take orders from the HELPERS button up top."})
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
	var r := card_rect()
	draw_rect(r, Color(0.08, 0.06, 0.1, 0.88))
	draw_rect(r, Color(1, 0.85, 0.45, 0.9), false, 1.0)
	var head := "TRAINING %d/%d · %s" % [i + 1, STEPS.size(), str(STEPS[i][1])]
	var wh := Art.tex("ui", "icon_whistle")
	var hx := 6.0
	if wh:
		draw_texture_rect(wh, Rect2(r.position + Vector2(4, 2), Vector2(12, 12)), false)
		hx = 19.0
	draw_string_outline(f, r.position + Vector2(hx, 11), head, HORIZONTAL_ALIGNMENT_LEFT, 150, 8, 3, Color(0, 0, 0, 0.8))
	draw_string(f, r.position + Vector2(hx, 11), head, HORIZONTAL_ALIGNMENT_LEFT, 150, 8, Color(1, 0.88, 0.5))
	# Progress pips (a finished step is green; the last one too once it's done).
	var done_now := step < STEPS.size() and _done_t > 0.0
	for k in STEPS.size():
		var c := Vector2(r.end.x - 7 - (STEPS.size() - 1 - k) * 7, r.position.y + 8)
		var green := k < step or (k == step and done_now)
		Art.draw_disc(self, c, 3.0, Color(0.5, 1, 0.6) if green else (Color(1, 0.88, 0.5, 0.6 + 0.4 * sin(_t * 5.0)) if k == step else Color(1, 1, 1, 0.25)))
	draw_multiline_string(f, r.position + Vector2(6, 23), body, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 7, 3, Color(0.95, 0.93, 0.88))
