class_name CasinoGame
extends ArcadeGame
## Base for every table at The Gilded Ace (C10b P4). Reuses ArcadeGame's 270x480
## screen, deck, pad hiding, left-handed mirror and pause/modal handling, but:
##   * no fee and no tickets: the stake comes from the purse (Casino.take) and the
##     payout goes back to it (Casino.settle); no best scores, no milestones;
##   * a round loop: title -> bet -> (play) -> reveal -> result -> bet ...;
##   * the outcome is drawn BEFORE the reveal from Casino.rng_for (never ArcadeGame.rng,
##     which only drives looks); tapping/A during a reveal jumps to the result;
##   * B always means back: on the bet card it takes back the bet (then leaves),
##     mid-hand it finishes the hand by its stand/finish rule and then leaves;
##   * money buttons fire only on the button they went down on (no slide-follow);
##   * cues by NET result: big-win jingle only at >= 10x, small jingle on a net win,
##     a soft click on a push, a neutral close on a loss (never a fanfare for less
##     than the stake), no streak counters.

var table := ""
var stake := 10
var bet_ix := 0            # which bet (roulette/dice) the stepper points at
var last_net := 0
var last_gross := 0
var result_text := ""
var note := ""             # the dealer's after-hand words (cold run, reality check, last call)
var reveal_t := 0.0
var reveal_len := 1.4
var leave_after := false
var practice := false      # the first hand at a table is free (how-to)
var _result_t := 0.0
var _bet_from := ""

const FELT := Color(0.09, 0.32, 0.2)
const FELT_EDGE := Color(0.84, 0.66, 0.24)
const CHIP_COLS := [Color(0.92, 0.92, 0.95), Color(0.85, 0.2, 0.22), Color(0.2, 0.45, 0.9), Color(0.15, 0.6, 0.3), Color(0.12, 0.12, 0.14)]


func _init() -> void:
	super._init()
	slide_follow = false
	fee = 0
	message_rect = Rect2(10, 314, 250, 34)


func _start_music() -> void:
	pass  # the floor's song keeps playing (Casino Row's own track)


func actions() -> Array:
	return ACTIONS + ["tool", "action"]


func _opened() -> void:
	stake = clampi(Casino.min_bet(), Casino.min_bet(), maxi(Casino.min_bet(), Casino.max_stake()))
	practice = not bool(Casino._st().get("seen", {}).get(table, false))


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(8, 392, 40, 40), "label": "-", "skin": "blue", "hint": "bet"},
		{"action": "right", "rect": Rect2(92, 392, 40, 40), "label": "+", "skin": "blue", "hint": "bet"},
		{"action": "up", "rect": Rect2(50, 360, 40, 32), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(50, 434, 40, 32), "label": "▼", "skin": "blue"},
		{"action": "a", "rect": Rect2(150, 362, 112, 34), "label": _a_word(), "skin": "gold", "shape": "pill"},
		{"action": "tool", "rect": Rect2(150, 402, 54, 30), "label": "X", "skin": "green", "shape": "pill"},
		{"action": "action", "rect": Rect2(208, 402, 54, 30), "label": "Y", "skin": "blue", "shape": "pill"},
		{"action": "b", "rect": Rect2(170, 438, 72, 30), "label": "LEAVE", "skin": "red", "shape": "pill"},
	]


func _a_word() -> String:
	return "DEAL"


## Deck label per state (drawn each frame: the deck dictionaries keep their rects).
func _label_for(action: String) -> String:
	match action:
		"a":
			match state:
				"title": return "SIT DOWN"
				"bet": return _a_word()
				"reveal": return "SKIP"
				"result": return "AGAIN"
			return _play_label("a")
		"b":
			return "STOP" if state in ["reveal", "play"] else "LEAVE"
		"tool", "action":
			return _play_label(action)
	return ""


func _play_label(_action: String) -> String:
	return ""


func _dead(b: Dictionary) -> bool:
	var a := str(b["action"])
	if a in ["tool", "action"]:
		return _play_label(a) == ""
	if a in ["left", "right"]:
		return state != "bet"
	if a in ["up", "down"]:
		return state != "bet" or bets().size() < 2
	return false


func _draw_button(c: Control, b: Dictionary) -> void:
	var nb := b.duplicate()
	var l := _label_for(str(b["action"]))
	if l != "":
		nb["label"] = l
	super._draw_button(c, nb)


# --- what a table offers -------------------------------------------------------

## [[id, label], ...] the up/down stepper walks (empty: one bet only).
func bets() -> Array:
	return []


func bet_id() -> String:
	var b := bets()
	return str(b[bet_ix][0]) if not b.is_empty() else table


## Called with the stake taken: draw the outcome from out_rng() and start the reveal
## (state "reveal") or an interactive hand (state "play").
func _deal() -> void:
	pass


## Reveal finished (or skipped): compute the gross return and call finish(gross).
func _reveal_done() -> void:
	pass


func _play_step(_dt: float) -> void:
	pass


## Each reveal frame (per-reel stop clicks and the like).
func _reveal_step() -> void:
	pass


func out_rng() -> RandomNumberGenerator:
	return Casino.rng_for(table, "%s|%d" % [bet_id(), stake])


# --- loop ----------------------------------------------------------------------

func frame() -> void:
	_arm += 1
	_read_input()
	message_t = maxf(0.0, message_t - DT)
	_shake = maxf(0.0, _shake - DT * 18.0)
	_step_fx()
	match state:
		"title":
			if pressed("a"):
				state = "bet"
				_bet_from = "title"
				_clamp_stake()
			elif pressed("b"):
				close()
		"bet":
			_step_bet()
		"play":
			play_t += DT
			if pressed("b"):
				leave_after = true
			_play_step(DT)
		"reveal":
			reveal_t += DT * (2.0 if Settings.reduced_motion() else 1.0)
			_reveal_step()
			if pressed("b"):
				leave_after = true
				reveal_t = reveal_len
			elif pressed("a") or reveal_t >= reveal_len:
				reveal_t = reveal_len
				_reveal_done()
		"result":
			_result_t += DT
			if leave_after:
				if _result_t > 0.9:
					close()
			elif _result_t > 0.3 and pressed("a"):
				state = "bet"
				_bet_from = "result"
				note = ""
				_clamp_stake()
			elif _result_t > 0.3 and pressed("b"):
				close()
		_:
			_step_state(state, DT)


func _clamp_stake() -> void:
	var mx := maxi(Casino.min_bet(), Casino.max_stake())
	stake = clampi(stake - stake % Casino.step(), Casino.min_bet(), mx)


func _step_bet() -> void:
	var st := Casino.step()
	if repeat_pressed("right"):
		var mx := Casino.max_stake()
		if stake + st <= mx:
			stake += st
			sfx("chip_clack", "pin_tap")
		else:
			say("Table limit for you: %s." % Money.amount(maxi(Casino.min_bet(), mx)))
	elif repeat_pressed("left"):
		if stake - st >= Casino.min_bet():
			stake -= st
			sfx("chip_clack", "pin_tap")
	var b := bets()
	if b.size() > 1:
		if repeat_pressed("down"):
			bet_ix = (bet_ix + 1) % b.size()
			sfx("ui_tap", "scroll_tick")
		elif repeat_pressed("up"):
			bet_ix = (bet_ix - 1 + b.size()) % b.size()
			sfx("ui_tap", "scroll_tick")
	if pressed("a"):
		place()
	elif pressed("b"):
		close()


## Puts the bet down (takes the stake, saves) and deals. False with a reason.
func place() -> bool:
	if not practice and not free_play:
		var why := Casino.why_no_bet(stake)
		if why != "":
			say(why, 2.6)
			sfx("nope", "locked")
			return false
	if not Casino.take(stake, table, practice or free_play):
		say("The table can't take that bet.")
		return false
	sfx("chip_clack", "pin_tap")
	leave_after = false
	reveal_t = 0.0
	play_t = 0.0
	result_text = ""
	_parts.clear()
	_floats.clear()
	_deal()
	return true


## Settles the hand: gross = what comes back to the purse (stake included).
func finish(gross: int) -> void:
	var free := practice or free_play
	last_gross = gross
	last_net = Casino.settle(table, staked(), gross, get_parent(), free)
	if practice:
		var seen: Dictionary = Casino._st().get("seen", {})
		seen[table] = true
		Casino._st()["seen"] = seen
		practice = false
		result_text = "Practice hand: %s" % _net_words(last_net)
	else:
		result_text = _net_words(last_net)
	note = "" if free else Casino.after_hand_note()
	if note != "":
		say(note, 4.0)
	_result_t = 0.0
	state = "result"
	_result_cue()


## Everything put down on this hand (blackjack doubles add a second stake).
func staked() -> int:
	return stake


func _net_words(n: int) -> String:
	if n > 0:
		return "+%s" % Money.amount(n)
	if n < 0:
		return "-%s" % Money.amount(-n)
	return "Push: bet back"


func _result_cue() -> void:
	if last_net >= 10 * staked():
		sfx("j_casino_big", "j_victory")
		if not Settings.reduced_motion():
			shake(3.0)
		Haptics.buzz("catch")  # one short buzz, only for the top wins
	elif last_net > 0:
		sfx("j_casino_small", "j_confirm")
		burst(Vector2(135, 200), accent, 12, 60.0)
	elif last_net == 0:
		sfx("ui_tap", "pop")
	else:
		sfx("menu_close", "thud")


func _tap(p: Vector2) -> void:
	if state == "reveal":
		reveal_t = reveal_len
		_reveal_done()
		return
	_tap_play(p)


func _tap_play(_p: Vector2) -> void:
	pass


## Taps inside the play area that act (tests check every one is >= 20 px a side).
func hit_rects() -> Array:
	return []


# --- drawing -------------------------------------------------------------------

func _draw_frame(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, W, TOP), Color(0.12, 0.05, 0.08))
	c.draw_rect(Rect2(0, TOP - 2, W, 2), accent)
	text_outline(c, Vector2(6, 16), title.to_upper(), 120, 10, accent)
	var n := Casino.net_today()
	text(c, Vector2(120, 16), Money.amount(Casino.purse()), 70, 9, Color(1, 0.92, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	text(c, Vector2(194, 16), ("today +%s" % Money.amount(n)) if n > 0 else (("today -%s" % Money.amount(-n)) if n < 0 else "today even"), 72, 8,
		Color(0.7, 1, 0.75) if n > 0 else (Color(1, 0.7, 0.7) if n < 0 else Color(0.85, 0.85, 0.9)), HORIZONTAL_ALIGNMENT_RIGHT)
	c.draw_rect(Rect2(0, DECK, W, H - DECK), Color(0.14, 0.07, 0.1))
	c.draw_rect(Rect2(0, DECK, W, 2), accent)
	_draw_deck(c)


func draw_felt(c: Control, col := FELT) -> void:
	c.draw_rect(PLAY, col.darkened(0.35))
	var r := Rect2(6, 30, 258, 284)
	c.draw_rect(r, col)
	c.draw_rect(r, FELT_EDGE, false, 2.0)
	c.draw_rect(r.grow(-4), Color(FELT_EDGE, 0.35), false, 1.0)


func draw_chip(c: Control, p: Vector2, amount: int, rad := 9.0) -> void:
	var ci := 0
	if amount >= 500: ci = 4
	elif amount >= 100: ci = 3
	elif amount >= 50: ci = 2
	elif amount >= 20: ci = 1
	var col: Color = CHIP_COLS[ci]
	c.draw_circle(p + Vector2(0, 2), rad, Color(0, 0, 0, 0.4))
	c.draw_circle(p, rad, col)
	for i in 6:
		var a := TAU * i / 6.0
		c.draw_line(p + Vector2.from_angle(a) * (rad - 3), p + Vector2.from_angle(a) * rad, Color(1, 1, 1, 0.8), 2.0)
	c.draw_circle(p, rad - 3.5, col.lightened(0.15))
	text(c, p + Vector2(-rad, 3), Money.num(amount) if amount < 1000 else "%dk" % (amount / 1000), rad * 2, 7, Color(0.1, 0.05, 0.05) if ci == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func draw_card(c: Control, r: Rect2, label: String, red: bool, face_up := true, held := false) -> void:
	c.draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.35))
	if not face_up:
		var bk := Art.tex("casino", "card_back")
		if bk:
			c.draw_texture_rect(bk, r, false)
			return
		c.draw_rect(r, Color(0.55, 0.1, 0.14))
		c.draw_rect(r.grow(-2), FELT_EDGE, false, 1.0)
		text(c, Vector2(r.position.x, r.get_center().y + 5), "A", r.size.x, 13, FELT_EDGE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	c.draw_rect(r, Color(0.98, 0.97, 0.93))
	c.draw_rect(r, Color(0.2, 0.15, 0.1), false, 1.0)
	var col := Color(0.82, 0.1, 0.14) if red else Color(0.08, 0.08, 0.1)
	text(c, r.position + Vector2(3, 12), label, r.size.x - 4, 10, col)
	var suit := label.right(1)
	if suit in CasinoRules.SUITS:
		text(c, Vector2(r.position.x, r.get_center().y + 9), suit, r.size.x, 18 if suit == "♦" else 16, col, HORIZONTAL_ALIGNMENT_CENTER)
	if held:
		c.draw_rect(r.grow(2), Color(1, 0.85, 0.3), false, 2.0)


func _draw_title(c: Control) -> void:
	draw_felt(c)
	text_outline(c, Vector2(0, 70), title.to_upper(), W, 16, accent, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 100.0
	for l in howto:
		text(c, Vector2(16, y), PadInput.words(str(l)), W - 32, 9, Color(0.95, 0.95, 1), HORIZONTAL_ALIGNMENT_CENTER)
		y += 14.0
	var keep: Dictionary = Casino.data().get("house_keeps", {})
	text(c, Vector2(16, y + 10), "House keeps about %s%.2f of every %s bet here." % [Money.sym(), float(keep.get(table, 3.0)), Money.amount(100)], W - 32, 8, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(16, y + 24), "Bets %s to %s. Stopping a spin early never changes it." % [Money.amount(Casino.min_bet()), Money.amount(Casino.max_bet())], W - 32, 8, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	if practice:
		text_outline(c, Vector2(0, y + 48), "First hand here is a free practice hand.", W, 9, Color(0.7, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	var blink := fmod(t, 1.0) < 0.65
	panel(c, Rect2(55, 270, 160, 24), Color(0.1, 0.05, 0.08), accent)
	if blink:
		text_outline(c, Vector2(55, 286), "A: SIT DOWN", 160, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text(c, Vector2(0, 306), "You have %s · B: leave" % Money.amount(Casino.purse()), W, 8, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


## The bet strip at the foot of the felt (stake, bet, practice) and the result card.
func draw_bet_strip(c: Control) -> void:
	var r := Rect2(10, 290, 250, 22)
	panel(c, r, Color(0.06, 0.03, 0.05, 0.9), FELT_EDGE)
	draw_chip(c, Vector2(24, 301), stake, 8.0)
	var b := bets()
	var lbl := ("BET %s" % Money.amount(stake)) + (("  on " + str(b[bet_ix][1])) if not b.is_empty() else "")
	if practice:
		lbl = "PRACTICE (free)  " + lbl
	text(c, Vector2(36, 305), lbl, 220, 9, Color.WHITE)
	if state == "result":
		# A compact banner over the bet board: the outcome itself (reels, wheel,
		# cards, dice) stays in view.
		var rr := Rect2(10, 238, 250, 48)
		panel(c, rr, Color(0.08, 0.04, 0.06, 0.95), accent)
		var col := Color(0.7, 1, 0.75) if last_net > 0 else (Color(1, 0.75, 0.75) if last_net < 0 else Color(0.9, 0.9, 0.95))
		text_outline(c, Vector2(rr.position.x, rr.position.y + 22), result_text, rr.size.x, 14, col, HORIZONTAL_ALIGNMENT_CENTER)
		if _result_t > 0.3 and not leave_after:
			text(c, Vector2(rr.position.x, rr.position.y + 40), PadInput.words("A: bet again   B: leave"), rr.size.x, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
