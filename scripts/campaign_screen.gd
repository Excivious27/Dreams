class_name CampaignScreen
extends CanvasLayer
## The campaign board (phone-first, 270x480). Without a campaign id: the list
## of this run's campaigns (open, in progress, locked and why). With one: the
## board of territories over that corner of the world map, the army's banner,
## routes, and a card for the tapped node (type, difficulty, objective, foes,
## rewards) with its action: Attack / March / Rest / settle a camp or cache.
## Tap a node, or LEFT/RIGHT to cycle, A for the main action, B to go back.

signal closed

const BOARD := Rect2(8, 66, 254, 252)
const NODE_R := 13.0

var m: GameMap
var cid := ""
var sel := ""
var _root: Control
var _board: Control
var _card: VBoxContainer
var _name: Label
var _sub: Label
var _body: Label
var _btns: HBoxContainer
var _list: ScrollContainer
var _top_btns: Array = []
var _was_paused := false
var _arm := 0
var _t := 0.0
var _flash := ""
var _flash_t := 0.0
var _acts: Array = []   # [label, callable] for the card's buttons (A presses the framed one)
var _act_i := 0         # C9 P3: the framed action (PAGE/TOOL step it, A runs it)
var _cur: ScreenCursor  # C9 P3: pad/keyboard cursor over the campaign list
var _rep := ScreenCursor.Rep.new()
const PICK_CONE := 0.5   # d-pad node pick: within 60 deg of the direction
const PICK_SIDE := 1.5   # sideways distance weighs this much more than forward
## Danger words under the pips (colour alone said it before; -1 easy .. 2 deadly).
const PIP_WORDS := ["", "", "HARD", "DEADLY"]
var _brief: PanelContainer   # the campaign briefing (first open of a board, or the ? button)
var _brief_box: VBoxContainer
var _help: Button


static func open(map: GameMap, campaign := "") -> void:
	if map == null or not is_instance_valid(map):
		return
	for n in map.get_children():
		if n is CampaignScreen:
			return  # one board at a time
	var s := CampaignScreen.new()
	s.m = map
	s.cid = campaign
	map.add_child(s)
	await s.closed


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	Hud.modal_rect = Rect2(0, 0, 270, 480)
	Hud.pause(get_tree(), "campaign_screen")
	Music.instance(get_tree()).sfx("page", "pickup")
	Music.instance(get_tree()).play("campaign_map")
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09, 1.0) if not GameState.is_penguins() else Color(0.1, 0.08, 0.06, 1.0)
	bg.size = Vector2(270, 480)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = Control.new()
	_root.size = Vector2(270, 480)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	Hud.skin_buttons(_root)
	add_child(_root)
	_board = Control.new()
	_board.size = Vector2(270, 480)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	_root.add_child(_board)
	var x := _btn("✕", close)
	x.position = Vector2(240, 6)
	x.size = Vector2(26, 22)
	_root.add_child(x)
	var back := _btn("◀ All", _show_list)
	back.position = Vector2(196, 6)
	back.size = Vector2(40, 22)
	_root.add_child(back)
	_help = _btn("?", _toggle_brief)
	_help.position = Vector2(170, 6)
	_help.size = Vector2(22, 22)
	_root.add_child(_help)
	_top_btns = [x, back, _help]
	# The node card under the board.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.12, 0.08, 0.98) if GameState.is_penguins() else Color(0.1, 0.09, 0.14, 0.98)
	sb.border_color = Color(0.85, 0.68, 0.38) if GameState.is_penguins() else Color(0.95, 0.4, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	# C5 c5_13 #5: the menus' wooden panel (Hud.panel_stylebox), not a flat dark box.
	var wood: StyleBox = Hud.panel_stylebox("panel_wood")
	panel.add_theme_stylebox_override("panel", wood if wood else sb)
	panel.position = Vector2(6, 324)
	panel.size = Vector2(258, 150)
	_root.add_child(panel)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 2)
	panel.add_child(_card)
	_name = _label("", 11, Color(1, 0.9, 0.6))
	_card.add_child(_name)
	_sub = _label("", 7, Color(0.85, 0.85, 0.9))
	_card.add_child(_sub)
	_body = _label("", 7, Color(0.95, 0.93, 0.88))
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.add_child(_body)
	_btns = HBoxContainer.new()
	_btns.add_theme_constant_override("separation", 3)
	_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(_btns)
	# The campaign list (shown instead of the board when no campaign is picked).
	_list = ScrollContainer.new()
	_list.position = Vector2(8, 40)
	_list.size = Vector2(254, 432)
	_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_list)
	_cur = ScreenCursor.make(self, _list)
	# The briefing card over the board.
	_brief = PanelContainer.new()
	var bsb := sb.duplicate() as StyleBoxFlat
	bsb.bg_color.a = 1.0
	_brief.add_theme_stylebox_override("panel", wood if wood else bsb)
	_brief.position = Vector2(10, 40)
	_brief.custom_minimum_size = Vector2(250, 0)
	_brief.visible = false
	_root.add_child(_brief)
	_brief_box = VBoxContainer.new()
	_brief_box.add_theme_constant_override("separation", 3)
	_brief.add_child(_brief_box)
	if cid == "" or Campaign.get_c(cid).is_empty():
		_show_list()
	else:
		_show_board(cid)


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(244, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	# Every board button taps (a callback's own cue, e.g. a jingle, plays on top).
	b.pressed.connect(func() -> void: Music.instance(get_tree()).sfx("ui_tap", "pickup"))
	b.pressed.connect(cb)
	return b


# ---- list -------------------------------------------------------------------------

func _show_list() -> void:
	cid = ""
	sel = ""
	_list.visible = true
	(_card.get_parent() as Control).visible = false
	_top_btns[1].visible = false
	_top_btns[2].visible = false
	_brief.visible = false
	for c in _list.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.custom_minimum_size = Vector2(242, 0)  # room for the scroll bar
	_list.add_child(v)
	var intro := _label("Each new region is held. Win its campaign, battle by battle across the board, and the way opens.", 7, Color(0.9, 0.88, 0.8))
	intro.custom_minimum_size.x = 236
	v.add_child(intro)
	# The lead-in: the story, then training with the veteran.
	var tr := CampaignGate.trainer()
	if not CampaignGate.story_ok():
		var gate := _label("✕ Campaigns aren't open yet. %s Then %s drills you to lead your %s." % [CampaignGate.story_need(), tr, Campaign.force_word()], 8, Color(1, 0.8, 0.6))
		gate.custom_minimum_size.x = 236
		v.add_child(gate)
	var tb := _btn("%s  Training: First Muster\n%s · %s" % ["✓" if CampaignGate.trained() else "★", tr,
		"done (drill again any time)" if CampaignGate.trained() else ("locked · after chapter 2" if CampaignGate.drill_lock() != "" else "ready · a short guided battle")], _start_drill)
	tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # the lock reason is long: it ran off the screen
	tb.custom_minimum_size = Vector2(242, 30)
	tb.icon = Art.tex("ui", "icon_whistle")
	tb.expand_icon = true
	tb.add_theme_constant_override("icon_max_width", 22)
	if CampaignGate.drill_lock() != "":
		tb.modulate = Color(0.7, 0.7, 0.72)
	elif not CampaignGate.trained():
		tb.modulate = Color(1.15, 1.05, 0.8)
	v.add_child(tb)
	# Under way first, then ready, gathering, locked; won ones last.
	var ids: Array = Campaign.for_arc()
	var rank := func(id: String) -> int:
		if Campaign.is_won(id) or Campaign.region_open(str(Campaign.get_c(id)["region"])):
			return 4
		if Campaign.started(id):
			return 0
		if Campaign.why_locked(id) == "":
			return 1
		return 2 if Campaign.plan_lock(id) == "" else 3
	var order := {}
	for i in ids.size():
		order[ids[i]] = rank.call(ids[i]) * 100 + i
	ids.sort_custom(func(a: String, b: String) -> bool: return int(order[a]) < int(order[b]))
	for id: String in ids:
		var c := Campaign.get_c(id)
		var why := Campaign.why_locked(id)
		var tag := ""
		if Campaign.is_won(id):
			tag = "✓ open"
		elif Campaign.region_open(str(c["region"])):
			tag = "✓ open (another way in)"
		elif Campaign.started(id):
			tag = "%d/%d taken" % [Campaign.taken_count(id) - 1, (c["nodes"] as Array).size() - 1]
		elif why != "":
			tag = "locked"
		else:
			tag = "ready"
		var plan := Campaign.plan_lock(id)
		if why != "" and why == CampaignGate.lock(id):
			why = "needs chapter 2" if not CampaignGate.story_ok() else "train first"  # said once, at the top
		if tag == "locked" and plan == "":
			tag = "gathering"
		var b := _btn("%s  %s\n%s · Tier %d · %d territories · %s" % ["✓" if Campaign.is_won(id) else ("⚔" if why == "" else ("⚑" if plan == "" else "✕")), str(c["title"]), str(c["region_name"]), int(c["tier"]), (c["nodes"] as Array).size() - 1, tag + ("" if why == "" or Campaign.is_won(id) or Campaign.region_open(str(c["region"])) else " · " + why)], _show_board.bind(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(242, 30)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 7)
		if plan != "" and not Campaign.is_won(id):
			b.modulate = Color(0.7, 0.7, 0.72)
		v.add_child(b)
	_board.queue_redraw()


# ---- board ------------------------------------------------------------------------

func _show_board(id: String) -> void:
	cid = id
	_list.visible = false
	(_card.get_parent() as Control).visible = true
	_top_btns[1].visible = true
	_top_btns[2].visible = true
	var s := Campaign.cs(id)
	sel = str(s["at"])
	# Pick the first node you can attack, so the card shows what's next.
	for n in Campaign.get_c(id)["nodes"]:
		if Campaign.can_attack(id, str(n["id"])):
			sel = str(n["id"])
			break
	_refresh()
	# The briefing opens by itself the first time you look at a campaign, and
	# whenever it isn't mustered yet; ? shows it again.
	var key := "cb_seen_" + id
	if not GameState.run["flags"].has(key):  # once; the ? button shows it again
		GameState.run["flags"][key] = true
		_show_brief()
	else:
		_brief.visible = false


func _refresh() -> void:
	if cid == "":
		return
	var c := Campaign.get_c(cid)
	var n := Campaign.node(cid, sel)
	var typ := str(n.get("type", ""))
	var why := Campaign.why_locked(cid)
	_name.text = str(n.get("name", ""))
	var st_txt := ""
	var stars := Campaign.stars(cid, sel)
	if stars > 0:
		st_txt = " · " + "★".repeat(stars) + "☆".repeat(5 - stars) + " " + Difficulty.DANGER_WORDS[Campaign.danger(cid, sel) + 1]
	var state := "yours" if Campaign.taken(cid, sel) else ("can attack" if Campaign.can_attack(cid, sel) else ("march, then attack" if Campaign.staging(cid, sel) != "" else "out of reach"))
	if str(Campaign.cs(cid)["at"]) == sel:
		state = "your %s is here" % Campaign.force_word()
	_sub.text = "%s%s · %s" % [str(Campaign.TYPE_NAME.get(typ, typ)), st_txt, state]
	var body := ""
	if Campaign.is_won(cid):
		body = "Campaign won. %s is open.\n" % str(c["region_name"])
	elif not Campaign.started(cid):
		body = ("Ready to muster: %s.\n" % CampaignGate.provisions_text(cid)) if why == "" else "Not ready: %s\n" % why
	elif why != "":
		body = "Locked: %s\n" % why
	if typ in Campaign.NONBATTLE:
		body += Campaign.text(n, "brief", "Your camp. The %s gathers here." % Campaign.force_word())
	else:
		var cf := Campaign.cfg(cid, sel)
		body += Campaign.text(n, "brief") + "\n"
		var foes: Array = []
		for k in cf.get("enemies", []):
			foes.append(_enemy_name(str(k)))
		var bk := Campaign.boss_of(cid, sel)
		body += "Foes: %s%s.\n" % [", ".join(foes.slice(0, 4)), (" · captain: " + _enemy_name(bk)) if bk != "" else ""]
		var rw: Dictionary = n.get("reward", {})
		var bits: Array = []
		if int(rw.get("crystals", 0)) > 0:
			bits.append("◆%d" % int(rw["crystals"]))
		for it: String in rw.get("items", {}):
			bits.append("%s ×%d" % [GameState.item_name(it), int(rw["items"][it])])
		if int(rw.get("supply", 0)) > 0:
			bits.append("◇+%d" % int(rw["supply"]))
		if int(rw.get("morale", 0)) > 0:
			bits.append("morale +%d" % int(rw["morale"]))
		if typ == "gate":
			var big: Dictionary = c.get("reward", {})
			bits = ["OPENS %s" % str(c["region_name"]).to_upper(), "◆%d" % int(big.get("crystals", 0))]
			var all_items: Dictionary = (big.get("items", {}) as Dictionary).duplicate()
			var ai: Dictionary = (big.get("arc_items", {}) as Dictionary).get(Campaign.arc(), {})
			for it: String in ai:
				all_items[it] = int(all_items.get(it, 0)) + int(ai[it])
			for it: String in all_items:
				bits.append("%s ×%d" % [GameState.item_name(it), int(all_items[it])])
		body += "Reward: " + ", ".join(bits)
	_body.text = body
	# Actions
	for b in _btns.get_children():
		b.queue_free()
	_acts = []
	if why == "" and not Campaign.is_won(cid) and not Campaign.started(cid):
		_acts.append(["⚑ Muster the %s (%s)" % [Campaign.force_word(), CampaignGate.provisions_text(cid)], _muster])
		_acts.append(["Briefing", _show_brief])
	elif why == "" and not Campaign.is_won(cid):
		if Campaign.can_attack(cid, sel):
			if typ in ["camp", "cache"]:
				for ch in Campaign.board_choices(cid, sel):
					_acts.append([str(ch[1]), _settle.bind(str(ch[0]))])
			else:
				_acts.append(["⚔ Attack", _attack])
		elif Campaign.staging(cid, sel) != "":
			_acts.append(["⚔ March & attack" if typ not in ["camp", "cache"] else "March there", _march_attack])
		elif Campaign.can_march(cid, sel):
			_acts.append(["March here", _march])
		elif Campaign.taken(cid, sel) and str(Campaign.cs(cid)["at"]) == sel:
			for ch in Campaign.board_choices(cid, sel):
				_acts.append([str(ch[1]), _settle.bind(str(ch[0]))])
	if Campaign.kin_due(cid):
		for ch in Campaign.kin_choices(cid):
			_acts.append([str(ch[1]), _kin.bind(str(ch[0]))])
	if _acts.is_empty() and not Campaign.is_won(cid):
		if why != "":
			_acts.append(["What's needed", _show_brief])
		else:
			if TouchControls.visible_controls:
				_acts.append(["Tap a glowing node next to ground you hold.", func() -> void: _flash_msg("Glowing nodes touch ground you hold: tap one, then Attack or March.")])
			else:
				_acts.append(["Pick a glowing node next to ground you hold.", func() -> void: _flash_msg("Glowing nodes touch ground you hold: move to one, then Attack or March.")])
	for a in _acts:
		var b := _btn(str(a[0]), a[1])
		b.custom_minimum_size = Vector2(0, 22)
		if _acts.size() > 1:
			b.add_theme_font_size_override("font_size", 7)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(120, 26)
		_btns.add_child(b)
	_frame_act(clampi(_act_i, 0, maxi(0, _acts.size() - 1)))
	_board.queue_redraw()


func _enemy_name(k: String) -> String:
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(k, {})
	var nm := str(ed.get("name", ""))
	if nm == "":
		nm = k.replace("thug_", "").replace("_", " ").capitalize()
	return nm


func _muster() -> void:
	if Net.visiting():
		_no()
		_flash_msg("You're visiting a friend's farm. Muster when you're home.")
		return
	var line := CampaignGate.muster(cid)
	if line == "":
		# Refused: say why instead of a dead tap.
		_no()
		var why := CampaignGate.lock(cid)
		if why != "":
			_flash_msg(why)
		return
	# Mustering is its own moment (the battle-start jingle is for the first fight).
	Music.instance(get_tree()).sfx("war_horn", "horn")
	Music.instance(get_tree()).sfx("j_confirm", "levelup")
	GameState.save()
	_brief.visible = false
	_show_board(cid)
	_flash_msg(line)


func _start_drill() -> void:
	var why := CampaignGate.drill_lock()
	if why != "":
		_no()
		_flash_list(why)
		return
	_close_now(false)  # the board's song carries into the fade, not the area song
	CampaignGate.launch_drill(m)


func _flash_list(t: String) -> void:
	var l := _label(t, 8, Color(1, 0.8, 0.6))
	var v := _list.get_child(0) if _list.get_child_count() > 0 else null
	if v:
		v.add_child(l)
		v.move_child(l, 1)


## The campaign briefing: what it is, how a campaign works, how long it is, and
## what it asks (story, training, team, provisions) with ticks.
func _show_brief() -> void:
	if cid == "":
		return
	for ch in _brief_box.get_children():
		ch.queue_free()
	var c := Campaign.get_c(cid)
	var wt := Art.tex("ui", "cut_war_table")
	if wt:
		var tr := TextureRect.new()
		tr.texture = wt
		tr.custom_minimum_size = Vector2(234, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.clip_contents = true
		_brief_box.add_child(tr)
	_brief_box.add_child(_label("CAMPAIGN BRIEFING · TIER %d" % int(c["tier"]), 7, Color(0.85, 0.85, 0.9)))
	_brief_box.add_child(_label(str(c["title"]), 12, Color(1, 0.9, 0.6)))
	_brief_box.add_child(_label(Campaign.text(c, "intro"), 7, Color(0.95, 0.93, 0.88)))
	_brief_box.add_child(_label("Led by %s." % Campaign.who(cid), 7, Color(0.75, 0.9, 1)))
	_brief_box.add_child(_label("HOW IT WORKS", 7, Color(1, 0.8, 0.4)))
	_brief_box.add_child(_label("• Attack a territory linked to one you hold. Battles are fought on a field; camps rest the " + Campaign.force_word() + ", caches give supply.\n• Morale sets your tickets in battle; supply is your starting purse for helpers.\n• Win the gate (the crown) and %s opens. Lose and you keep what you took." % str(c["region_name"]), 7, Color(0.92, 0.92, 0.95)))
	_brief_box.add_child(_label("LENGTH: %d territories · at least %d battle%s to the gate" % [(c["nodes"] as Array).size() - 1, int(c.get("min_battles", 3)), "" if int(c.get("min_battles", 3)) == 1 else "s"], 7, Color(0.7, 0.92, 1)))
	if not Campaign.started(cid) and not Campaign.is_won(cid):
		_brief_box.add_child(_label("TO MUSTER", 7, Color(1, 0.8, 0.4)))
		for row in CampaignGate.checklist(cid):
			_brief_box.add_child(_label(("✓ " if bool(row[0]) else "✕ ") + str(row[1]), 7, Color(0.6, 1, 0.7) if bool(row[0]) else Color(1, 0.75, 0.65)))
		var after := Campaign.why_locked(cid)
		if after != "" and after != CampaignGate.short_text(cid) and after != CampaignGate.lock(cid):
			_brief_box.add_child(_label("✕ " + after, 7, Color(1, 0.75, 0.65)))
		var tm := CampaignGate.team()
		if not tm.is_empty():
			_brief_box.add_child(_label("Your team: " + ", ".join(tm.map(func(x: Array) -> String: return str(x[1]))), 6, Color(0.85, 0.85, 0.8)))
	var ok := _btn("Got it", func() -> void: _brief.visible = false)
	ok.custom_minimum_size = Vector2(0, 22)
	_brief_box.add_child(ok)
	_brief.visible = true
	_brief.size = Vector2(250, 0)


func _toggle_brief() -> void:
	if _brief.visible:
		_brief.visible = false
	else:
		_show_brief()


func _attack() -> void:
	var id := cid
	var nid := sel
	if Net.visiting():
		_no()
		_flash_msg("You're visiting a friend's farm. Campaigns wait until you're home.")
		return
	if not Campaign.can_attack(id, nid) or str(Campaign.cfg(id, nid).get("field", "")) == "":
		_no()
		_flash_msg("That ground is out of reach: march next to it first.")
		return
	_close_now(false)
	Campaign.launch(m, id, nid)


## Walk the army to the held node next to sel, then attack (or settle) sel.
func _march_attack() -> void:
	Campaign.march(cid, Campaign.staging(cid, sel))
	if str(Campaign.node(cid, sel).get("type", "")) in ["camp", "cache"]:
		_refresh()
		_flash_msg("The %s marches out. Choose what to do there." % Campaign.force_word())
	else:
		_attack()


func _march() -> void:
	if Campaign.march(cid, sel):
		Music.instance(get_tree()).sfx("march", "war_drum")
		_flash_msg("The %s marches to %s." % [Campaign.force_word(), str(Campaign.node(cid, sel)["name"])])
		GameState.save()
	_refresh()


## Crystal babies: prove your purpose (Campaign.kin_settle).
func _kin(choice: String) -> void:
	var lines := Campaign.kin_settle(cid, choice)
	GameState.save()
	_refresh()
	if not lines.is_empty():
		if choice == "meow":
			Music.instance(get_tree()).sfx("meow", "sparkle")
		Music.instance(get_tree()).sfx("j_secret" if choice != "later" else "pickup", "sparkle")
		_flash_msg(str(lines[lines.size() - 1].get("text", "")))


func _settle(choice: String) -> void:
	var line := Campaign.settle(cid, sel, choice)
	Music.instance(get_tree()).sfx(str(SETTLE_SFX.get(choice, "pickup")), "pickup")
	GameState.save()
	_refresh()
	_flash_msg(line)


## Camp / cache choices each sound like what they do.
const SETTLE_SFX := {"take": "chest_open", "share": "coin", "rest": "cloth", "forage": "harvest"}


## A refused tap on the board: a soft "no" (the flash message says why).
func _no() -> void:
	Music.instance(get_tree()).sfx("nope", "thud")


func _flash_msg(t: String) -> void:
	_flash = t
	_flash_t = 3.5
	_body.text = t + "\n\n" + _body.text


func _on_board_input(ev: InputEvent) -> void:
	if cid == "" or _brief.visible:
		return
	var pos := TapInput.press_pos(ev)
	if pos == Vector2.INF:
		return
	var best := ""
	var bd := 22.0
	for n in Campaign.get_c(cid)["nodes"]:
		var d := pos.distance_to(_npos(n))
		if d < bd:
			bd = d
			best = str(n["id"])
	if best != "":
		_select(best)


func _select(nid: String) -> void:
	if nid == sel:
		return
	sel = nid
	_act_i = 0
	Music.instance(get_tree()).sfx("pickup")
	_refresh()


func _npos(n: Dictionary) -> Vector2:
	return BOARD.position + Vector2(18, 18) + Vector2(float(n["x"]) * (BOARD.size.x - 36), float(n["y"]) * (BOARD.size.y - 36))


func _process(delta: float) -> void:
	_t += delta
	_arm += 1
	_board.queue_redraw()
	if _arm < 8:
		return
	if _brief.visible and (Input.is_action_just_pressed("b") or Input.is_action_just_pressed("a")):
		_brief.visible = false
		return
	if Input.is_action_just_pressed("b") or Input.is_action_just_pressed("menu"):
		if cid != "":
			_show_list()
		else:
			close()
		return
	_cur.enabled = cid == "" and not _brief.visible
	if cid == "":
		return
	for a: String in ScreenCursor.DIRS:
		if _rep.pressed(a, delta):
			var nb := pick_dir(ScreenCursor.DIRS[a])
			if nb != "":
				_select(nb)
	if not _acts.is_empty() and (Input.is_action_just_pressed(ScreenCursor.PAGE) or Input.is_action_just_pressed(ScreenCursor.TOOL)):
		_frame_act((_act_i + 1) % _acts.size())
	elif Input.is_action_just_pressed(ScreenCursor.CONFIRM_ALT):
		_show_brief()  # X: the briefing, from any node
	elif Input.is_action_just_pressed("a") and not _acts.is_empty():
		(_acts[clampi(_act_i, 0, _acts.size() - 1)][1] as Callable).call()


## C9 P3: the nearest node in a direction from the selected one (spatial, like a
## map cursor); none in that cone -> wrap to the far side along that line.
func pick_dir(dir: Vector2) -> String:
	if cid == "":
		return ""
	var nodes: Array = Campaign.get_c(cid)["nodes"]
	var p := Vector2.ZERO
	for n: Dictionary in nodes:
		if str(n["id"]) == sel:
			p = _npos(n)
	var best := ""
	var bs := INF
	var far := ""
	var fs := INF
	for n: Dictionary in nodes:
		if str(n["id"]) == sel:
			continue
		var d := _npos(n) - p
		var fwd := d.dot(dir)
		var side := absf(d.dot(Vector2(-dir.y, dir.x)))
		if fwd > 1.0 and fwd >= d.length() * PICK_CONE:
			var sc := fwd + side * PICK_SIDE
			if sc < bs:
				bs = sc
				best = str(n["id"])
		elif fwd < -1.0:
			var sc2 := fwd + side * PICK_SIDE  # most negative = furthest back
			if sc2 < fs:
				fs = sc2
				far = str(n["id"])
	return best if best != "" else far


## Frame one of the card's action buttons (gold border).
func _frame_act(i: int) -> void:
	_act_i = i
	var k := 0
	for b in _btns.get_children():
		if b.is_queued_for_deletion() or not (b is Button):
			continue
		var on := k == _act_i and _acts.size() > 1
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.45, 0.33, 0.15)
			sb.border_color = ScreenCursor.FRAME_COL
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(3)
			for st in ["normal", "hover", "pressed", "focus"]:
				(b as Button).add_theme_stylebox_override(st, sb)
		else:
			for st in ["normal", "hover", "pressed", "focus"]:
				(b as Button).remove_theme_stylebox_override(st)
		k += 1


# ---- drawing -----------------------------------------------------------------------

## Board backdrop centres where the world map doesn't show the region (islands
## out at sea, highland peaks rather than the sky islands above them).
const BOARD_PIN := {"colony_coral": Vector2(0.22, 0.80), "colony_kelp": Vector2(0.18, 0.86), "colony_ice": Vector2(0.30, 0.88),
	"colony_ember": Vector2(0.26, 0.84), "highlands": Vector2(0.70, 0.24), "sky": Vector2(0.30, 0.10)}


func _draw_board() -> void:
	var f := ThemeDB.fallback_font
	var cv := _board
	var peng := GameState.is_penguins()
	var gold := Color(1, 0.86, 0.45)
	if cid == "":
		cv.draw_string_outline(f, Vector2(10, 22), "Campaigns", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.8))
		cv.draw_string(f, Vector2(10, 22), "Campaigns", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
		return
	var c := Campaign.get_c(cid)
	var s := Campaign.cs(cid)
	# Header
	_text(cv, f, Vector2(8, 20), str(c["title"]), 13, gold, 186)
	_text(cv, f, Vector2(8, 34), "%s · Tier %d%s" % [str(c["region_name"]), int(c["tier"]), " · WON" if Campaign.is_won(cid) else ""], 8, Color(0.85, 0.85, 0.9))
	# Army status: morale bar, supply, territories, record.
	var mo := int(s["morale"])
	var y := 46.0
	cv.draw_rect(Rect2(8, y, 92, 7), Color(0, 0, 0, 0.6))
	var mcol := Color(0.45, 0.95, 0.55) if mo >= 55 else (Color(1, 0.85, 0.4) if mo >= 25 else Color(1, 0.45, 0.4))
	cv.draw_rect(Rect2(8, y, 92.0 * mo / 100.0, 7), mcol)
	cv.draw_rect(Rect2(8, y, 92, 7), Color(1, 1, 1, 0.35), false, 1.0)
	_text(cv, f, Vector2(8, y + 16), "Morale %d %s" % [mo, Campaign.morale_word(mo)], 7, mcol)
	_text(cv, f, Vector2(110, y + 7), "◇ %d supply" % int(s["supply"]), 8, Color(1, 0.95, 0.7))
	_text(cv, f, Vector2(110, y + 16), "⚑ %d/%d held" % [Campaign.taken_count(cid) - 1, (c["nodes"] as Array).size() - 1], 7, Color(0.7, 0.92, 1))
	_text(cv, f, Vector2(186, y + 7), "%d won · %d lost" % [int(s.get("wins", 0)), int(s.get("losses", 0))], 7, Color(0.9, 0.9, 0.9))
	_text(cv, f, Vector2(186, y + 16), "★ = foe level", 7, Color(0.7, 0.7, 0.75))
	# Board backdrop: this region's corner of the world map, under a tint.
	var br := BOARD
	cv.draw_rect(br.grow(2), Color(0.3, 0.2, 0.1) if peng else Color(0.5, 0.2, 0.45))
	var wm := Art.tex("ui", "world_map")
	if wm:
		var pin: Vector2 = BOARD_PIN.get(str(c["region"]), GameMenu.PINS.get(str(c["region"]), Vector2(0.5, 0.5)))
		var zw := wm.get_width() * 0.42
		var zh := zw * br.size.y / br.size.x
		var src := Rect2(clampf(pin.x * wm.get_width() - zw / 2, 0, wm.get_width() - zw), clampf(pin.y * wm.get_height() - zh / 2, 0, wm.get_height() - zh), zw, zh)
		cv.draw_texture_rect_region(wm, br, src, Color(1, 0.95, 0.85) if peng else Color(0.75, 0.7, 0.95))
		cv.draw_rect(br, Color(0.12, 0.08, 0.04, 0.58) if peng else Color(0.05, 0.02, 0.12, 0.62))
	else:
		cv.draw_rect(br, Color(0.78, 0.7, 0.52) if peng else Color(0.12, 0.1, 0.2))
	# Region crest at the gate end.
	_text(cv, f, br.position + Vector2(6, 12), "▲ " + str(c["region_name"]).to_upper(), 7, Color(1, 0.92, 0.7, 0.85))
	# Links
	var nodes := {}
	for n in c["nodes"]:
		nodes[str(n["id"])] = n
	var at := str(s["at"])
	for l in c["links"]:
		var a: Dictionary = nodes[str(l[0])]
		var b: Dictionary = nodes[str(l[1])]
		var pa := _npos(a)
		var pb := _npos(b)
		var ta := Campaign.taken(cid, str(a["id"]))
		var tb := Campaign.taken(cid, str(b["id"]))
		if ta and tb:
			cv.draw_line(pa, pb, Color(0.1, 0.05, 0.02, 0.6), 5.0)
			cv.draw_line(pa, pb, Color(0.45, 0.85, 1.0), 2.5)
		elif (ta and str(a["id"]) == at) or (tb and str(b["id"]) == at):
			_dashed(cv, pa, pb, Color(1, 0.85, 0.4, 0.9), 2.0, _t * 18.0 * (1.0 if ta else -1.0))
		else:
			_dashed(cv, pa, pb, Color(0.95, 0.9, 0.8, 0.45), 1.5, 0.0)
	# Route from the army to the selected node.
	var rt := Campaign.route(cid, sel) if sel != at else []
	for k in range(1, rt.size()):
		var p0 := _npos(nodes[str(rt[k - 1])])
		var p1 := _npos(nodes[str(rt[k])])
		cv.draw_line(p0, p1, Color(1, 1, 1, 0.8), 1.5)
		var mid := p0.lerp(p1, fmod(_t * 0.8 + k * 0.3, 1.0))
		Art.draw_disc(cv, mid, 2.5, Color(1, 1, 1, 0.95))
	# Nodes
	for n in c["nodes"]:
		var id := str(n["id"])
		var p := _npos(n)
		var typ := str(n["type"])
		var tk := Campaign.taken(cid, id)
		var att := Campaign.can_attack(cid, id)
		var fill := Color(0.25, 0.55, 0.75) if tk else (Color(0.55, 0.2, 0.18) if typ == "gate" else Color(0.32, 0.28, 0.25))
		if att:
			fill = fill.lerp(Color(0.85, 0.65, 0.2), 0.45 + 0.2 * sin(_t * 4.0))
		var r := NODE_R + (3.0 if typ == "gate" else 0.0)
		Art.draw_disc(cv, p + Vector2(0, 2), r + 1.5, Color(0, 0, 0, 0.45))
		Art.draw_disc(cv, p, r + 1.5, Color(0.1, 0.07, 0.04) if peng else Color(0.05, 0.03, 0.08))
		Art.draw_disc(cv, p, r, fill)
		cv.draw_arc(p, r, 0, TAU, 32, Color(1, 0.9, 0.6, 0.8) if att else Color(1, 1, 1, 0.25), 1.5 if att else 1.0, true)
		if id == sel:
			cv.draw_arc(p, r + 4 + sin(_t * 5.0), 0, TAU, 32, Color(1, 1, 1, 0.95), 1.5, true)
		_icon(cv, p, typ, tk)
		# Difficulty pips under battle nodes.
		var stn := Campaign.stars(cid, id)
		if stn > 0 and not tk:
			var dcol: Color = [Color(0.5, 1, 0.6), Color(1, 0.95, 0.5), Color(1, 0.65, 0.35), Color(1, 0.4, 0.35)][Campaign.danger(cid, id) + 1]
			var dg := Campaign.danger(cid, id) + 1
			for k in stn:
				var pp := p + Vector2((k - (stn - 1) / 2.0) * 5.0, r + 5)
				if dg >= 2:
					# Hard/deadly: a diamond pip, not just a redder dot (colour-blind safe).
					cv.draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -2.4), pp + Vector2(2.4, 0), pp + Vector2(0, 2.4), pp + Vector2(-2.4, 0)]), dcol)
				else:
					Art.draw_disc(cv, pp, 1.8, dcol)
			if str(PIP_WORDS[dg]) != "":
				_text(cv, f, p + Vector2(-30, r + 14), str(PIP_WORDS[dg]), 6, dcol, 60, HORIZONTAL_ALIGNMENT_CENTER)
		var nm := str(n["name"])
		_text(cv, f, p + Vector2(-40, -r - 4), nm, 6, Color(1, 0.97, 0.88) if tk or att or id == sel else Color(0.9, 0.88, 0.82, 0.8), 80, HORIZONTAL_ALIGNMENT_CENTER)
	# The army's banner where it stands.
	var ap := _npos(nodes[at])
	var fl := Art.tex("battle", "flag_ally_%d" % (int(_t * 6.0) % 4))
	if fl:
		var fh := 24.0
		var fw := fh * fl.get_width() / fl.get_height()
		cv.draw_texture_rect(fl, Rect2(ap + Vector2(-NODE_R - fw + 4, -fh + 4 + sin(_t * 2.0)), Vector2(fw, fh)), false)
	else:
		cv.draw_line(ap + Vector2(8, 0), ap + Vector2(8, -22), Color(0.3, 0.2, 0.1), 2.0)
		cv.draw_colored_polygon(PackedVector2Array([ap + Vector2(9, -22), ap + Vector2(22, -18), ap + Vector2(9, -14)]), Color(0.5, 0.9, 1.0))
	if Campaign.is_won(cid):
		_text(cv, f, br.position + Vector2(0, br.size.y / 2), "REGION OPEN", 16, Color(1, 0.9, 0.5), br.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _icon(cv: Control, p: Vector2, typ: String, tk: bool) -> void:
	var w := Color(1, 0.97, 0.9)
	var dk := Color(0.1, 0.06, 0.03, 0.9)
	var badge := Art.tex("ui", "mode_" + typ) if typ not in ["start", "camp", "cache"] else null
	if badge:
		var bs := NODE_R * 2.0 + (4.0 if typ == "gate" else 0.0)
		cv.draw_texture_rect(badge, Rect2(p - Vector2(bs, bs) / 2.0, Vector2(bs, bs)), false, Color(0.75, 0.85, 1.0, 0.85) if tk else Color.WHITE)
		if tk:
			cv.draw_string(ThemeDB.fallback_font, p + Vector2(5, 11), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 1, 0.7))
		return
	match typ:
		"start", "camp":
			var tex := Art.tex("props", "st_campfire_%d" % (1 + int(_t * 6.0) % 4))
			if tex == null:
				tex = Art.tex("nature", "campfire2")
			if tex:
				var h := 16.0
				var ww := h * tex.get_width() / tex.get_height()
				cv.draw_texture_rect(tex, Rect2(p - Vector2(ww / 2, h / 2 + 1), Vector2(ww, h)), false)
			else:
				cv.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 5), p + Vector2(0, -7), p + Vector2(7, 5)]), w)
		"cache":
			var ch := Art.tex("items", "chest")
			if ch:
				cv.draw_texture_rect(ch, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, 0.6) if tk else Color.WHITE)
			else:
				cv.draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 10)), Color(0.7, 0.45, 0.2))
		"skirmish":
			for sgn in [-1.0, 1.0]:
				cv.draw_line(p + Vector2(-6 * sgn, 6), p + Vector2(6 * sgn, -6), dk, 3.5)
				cv.draw_line(p + Vector2(-6 * sgn, 6), p + Vector2(6 * sgn, -6), w, 1.8)
				cv.draw_line(p + Vector2(-6 * sgn, 6) + Vector2(sgn * 2, -2) + Vector2(-2, -2) * sgn, p + Vector2(-6 * sgn, 6) + Vector2(sgn * 2, -2) + Vector2(2, 2) * sgn, w, 1.5)
		"siege":
			cv.draw_rect(Rect2(p + Vector2(-6, -3), Vector2(12, 9)), dk)
			cv.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 7)), w)
			for k in 3:
				cv.draw_rect(Rect2(p + Vector2(-6 + k * 5, -7), Vector2(3, 4)), w)
			cv.draw_rect(Rect2(p + Vector2(-1.5, 1), Vector2(3, 4)), dk)
		"escort":
			cv.draw_rect(Rect2(p + Vector2(-7, -5), Vector2(14, 7)), w)
			cv.draw_rect(Rect2(p + Vector2(-7, -5), Vector2(14, 7)), dk, false, 1.0)
			Art.draw_disc(cv, p + Vector2(-4, 4), 2.5, dk)
			Art.draw_disc(cv, p + Vector2(4, 4), 2.5, dk)
		"defend":
			var sh := PackedVector2Array([p + Vector2(-6, -7), p + Vector2(6, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
			cv.draw_colored_polygon(sh, w)
			cv.draw_polyline(sh + PackedVector2Array([sh[0]]), dk, 1.2)
			cv.draw_line(p + Vector2(0, -5), p + Vector2(0, 4), Color(0.3, 0.55, 0.8), 2.0)
		"boss", "gate":
			var cr := Art.tex("ui", "node_crown" if typ == "gate" else "node_star")
			if cr:
				cv.draw_texture_rect(cr, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false)
			else:
				cv.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 4), p + Vector2(-7, -5), p + Vector2(-3, -1), p + Vector2(0, -7), p + Vector2(3, -1), p + Vector2(7, -5), p + Vector2(7, 4)]), Color(1, 0.85, 0.3))
	if tk and typ not in ["start", "camp"]:
		cv.draw_string(ThemeDB.fallback_font, p + Vector2(5, 11), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 1, 0.7))


func _dashed(cv: Control, a: Vector2, b: Vector2, col: Color, w: float, off: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, len)
	var seg := 6.0
	var t := fmod(off, seg * 2.0)
	if t < 0:
		t += seg * 2.0
	t -= seg * 2.0
	while t < len:
		var s0 := maxf(0.0, t)
		var s1 := minf(len, t + seg)
		if s1 > s0:
			cv.draw_line(a + dir * s0, a + dir * s1, col, w)
		t += seg * 2.0


func _text(cv: Control, f: Font, p: Vector2, t: String, size: int, col: Color, width := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	cv.draw_string_outline(f, p, Money.t(t), al, width, size, 3, Color(0, 0, 0, 0.8))
	cv.draw_string(f, p, Money.t(t), al, width, size, col)


# ---- closing ------------------------------------------------------------------------

func _close_now(restore_music := true) -> void:
	if not is_inside_tree():
		return
	_closed_ok = true
	get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	Music.instance(get_tree()).sfx("menu_close", "ui_tap")
	if restore_music and m != null and is_instance_valid(m):
		Music.instance(get_tree()).play(m.area_track())
	Hud.modal_rect = Rect2()
	Dialogue.block_input(0.4)
	closed.emit()
	queue_free()


## Freed with its map (a map change while the board was up): don't leave the
## tree paused behind a full-screen modal rect with no screen (bot 5, C11a fix).
var _closed_ok := false
func _exit_tree() -> void:
	if _closed_ok:
		return
	_closed_ok = true
	Hud.modal_rect = Rect2()
	if get_tree() and Hud.pause_owner == "campaign_screen":
		get_tree().paused = _was_paused and Hud.keep_paused(get_tree(), self)
	closed.emit()


func close() -> void:
	GameState.save()
	_close_now()
