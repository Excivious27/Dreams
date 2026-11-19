class_name BattleBrief
extends CanvasLayer
## The briefing card at the start of every campaign battle (and the training
## drill): what kind of fight it is, the objective, how you win and lose, a
## controls reminder and the speaker's line. Pauses the game until you start.
## The first time you see a kind of fight the card stays up a moment before it
## can be dismissed; after that A starts at once, and "Don't show again" hides
## that kind for good (flag bb_hide_<mode>; a toast still gives the objective).

signal done

const WIN := {
	"drill": "Follow the six training steps. Take every point to finish.",
	"skirmish": "Hold every point, or run their tickets to zero.",
	"siege": "Every point they hold is fortified (turns at half speed). Take them all, or run their tickets out.",
	"escort": "Walk the convoy to its last stop. It rolls while a friend is beside it and no foe is on it.",
	"defend": "Hold at least one point until the clock runs out. Their gates (spiked rings) can't be taken.",
	"boss": "Bring their captain down. Taking every point works too.",
	"gate": "Take every point or run their tickets out. Their commander joins at half tickets.",
	"": "Take the points. The side holding fewer bleeds tickets; run theirs out to win.",
}
const LOSE := {
	"drill": "You can't lose here. Take your time.",
	"escort": "The convoy is destroyed, or your tickets run out.",
	"defend": "You lose every point, or your tickets run out.",
	"": "Your tickets run out (they bleed while they hold more points), or you're knocked out.",
}
const CONTROLS := "Walk into a ring to take a point. USE on a banner you hold: build helpers, Upgrade, Fortify, Mend, Barrage (costs ◇ supply). RALLY (top left): guard posts, follow me, or send everyone to a point. Points you hold earn supply. Fall back: the ▼ exit at the bottom."

var d: Dictionary = {}
var mode := ""
var _was_paused := false
var _arm := 0.0
var _min_t := 0.0
var _go: Button
var _hide: Button
var _rects: Array = []


## Show the card for battle data d (await done). Returns at once when hidden.
static func show_for(m: GameMap, data: Dictionary) -> void:
	var md := str(data.get("mode", ""))
	if GameState.run["flags"].has("bb_hide_" + md) and md != "drill":
		m.hud.toast("%s · %s" % [str(data.get("title", "Battle")), str(WIN.get(md, WIN[""]))], Color(1, 0.9, 0.6))
		return
	var bb := BattleBrief.new()
	bb.d = data
	bb.mode = md
	m.add_child(bb)
	await bb.done


static func seen(md: String) -> bool:
	return GameState.run["flags"].has("bb_seen_" + md)


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	_min_t = 0.3 if seen(mode) else 1.6
	var root := Control.new()
	root.size = Vector2(270, 480)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	Hud.skin_buttons(root)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = Vector2(270, 480)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var peng := GameState.is_penguins()
	sb.bg_color = Color(0.17, 0.12, 0.08, 0.98) if peng else Color(0.1, 0.09, 0.14, 0.98)
	sb.border_color = Color(0.85, 0.68, 0.38) if peng else Color(0.95, 0.4, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(10, 70)
	panel.custom_minimum_size = Vector2(250, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	if mode == "drill":
		# The veteran at the training ground.
		var pic := Art.tex("ui", "cut_drill_catkins" if GameState.is_penguins() else "cut_drill_sal")
		if pic:
			var tr := TextureRect.new()
			tr.texture = pic
			tr.custom_minimum_size = Vector2(234, 110)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.clip_contents = true
			v.add_child(tr)
	var kind := "TRAINING" if mode == "drill" else str(Campaign.TYPE_NAME.get(mode, "Battle")).to_upper()
	var tier := ""
	if d.has("enemy_tier") and mode != "drill":
		var stn := clampi(int(d["enemy_tier"]) + 1, 1, 5)
		tier = "  " + "★".repeat(stn) + "☆".repeat(5 - stn)
	# Header: the kind's badge beside its name and the title.
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	v.add_child(hdr)
	var badge := Art.tex("ui", "icon_whistle" if mode == "drill" else "mode_" + (mode if mode != "" else "skirmish"))
	if badge:
		var bi := TextureRect.new()
		bi.texture = badge
		bi.custom_minimum_size = Vector2(28, 28)
		bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr.add_child(bi)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hdr.add_child(hv)
	var k := _label(kind + tier, 7, Color(0.85, 0.85, 0.9))
	k.custom_minimum_size = Vector2(200, 0)
	hv.add_child(k)
	var tl := _label(str(d.get("title", "Battle")), 11, Color(1, 0.9, 0.6))
	tl.custom_minimum_size = Vector2(200, 0)
	hv.add_child(tl)
	var brief := str(d.get("brief", ""))
	if brief != "":
		var who := str(d.get("who", ""))
		v.add_child(_label(("%s: \"%s\"" % [who, brief]) if who != "" else brief, 7, Color(0.95, 0.93, 0.88)))
	v.add_child(_head("HOW TO WIN"))
	v.add_child(_label(str(WIN.get(mode, WIN[""])), 7, Color(0.75, 1, 0.8)))
	v.add_child(_head("YOU LOSE IF"))
	v.add_child(_label(str(LOSE.get(mode, LOSE[""])), 7, Color(1, 0.8, 0.75)))
	var army := _army_line()
	if army != "":
		v.add_child(_head("YOUR ARMY"))
		v.add_child(_label(army, 7, Color(1, 0.95, 0.7)))
	v.add_child(_head("CONTROLS"))
	v.add_child(_label(CONTROLS, 6, Color(0.88, 0.88, 0.92)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_go = Button.new()
	_go.text = "⚔ Start" if mode != "drill" else "⚔ Begin training"
	_go.custom_minimum_size = Vector2(110, 24)
	_go.add_theme_font_size_override("font_size", 9)
	_go.focus_mode = Control.FOCUS_NONE
	_go.pressed.connect(_close)
	row.add_child(_go)
	if seen(mode) and mode != "drill":
		_hide = Button.new()
		_hide.text = "Don't show again"
		_hide.custom_minimum_size = Vector2(100, 24)
		_hide.add_theme_font_size_override("font_size", 7)
		_hide.focus_mode = Control.FOCUS_NONE
		_hide.pressed.connect(func() -> void:
			GameState.run["flags"]["bb_hide_" + mode] = true
			_close())
		row.add_child(_hide)
	Music.instance(get_tree()).sfx("page", "pickup")
	_track_rects.call_deferred()


func _track_rects() -> void:
	for b in [_go, _hide]:
		if b != null and is_instance_valid(b):
			var r := Rect2(b.global_position, b.size)
			_rects.append(r)
			Hud.extra_rects.append(r)


func _army_line() -> String:
	if mode == "drill":
		return "Supply ◇%d to spend. Helpers and the point menu cost supply." % int(d.get("supply", 0))
	if str(d.get("campaign", "")) == "":
		return ""
	var bits: Array = ["Tickets %d" % int(d.get("tickets", 0)), "supply ◇%d" % int(d.get("supply", 0))]
	if bool(d.get("inspired", false)):
		bits.append("inspired: helpers +25% health")
	return ", ".join(bits) + ". Morale sets your tickets; supply buys helpers."


func _head(t: String) -> Label:
	var l := _label(t, 7, Color(1, 0.8, 0.4))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(234, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_arm += delta
	if _go:
		_go.disabled = _arm < _min_t
	if _arm >= _min_t and (Input.is_action_just_pressed("a") or Input.is_action_just_pressed("b")):
		_close()


func _close() -> void:
	if not is_inside_tree() or _arm < _min_t:
		return
	GameState.run["flags"]["bb_seen_" + mode] = true
	# Unpause unless another full-screen UI is still up (the card can open while
	# the map's arrival fade has the tree paused for a moment).
	var other := false
	for n in get_parent().get_children():
		if n != self and (n is CampaignScreen or n is BattleBrief):
			other = true
	get_tree().paused = other and _was_paused
	Hud.modal_rect = Rect2()
	for r in _rects:
		Hud.extra_rects.erase(r)
	Dialogue.block_input(0.4)
	done.emit()
	queue_free()
