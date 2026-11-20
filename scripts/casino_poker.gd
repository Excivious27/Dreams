extends CasinoGame
## Video Poker, Jacks or Better 8/5: five cards, hold any, one draw. Tap a card (or
## LEFT/RIGHT then X) to hold it, A draws. Y holds the house hint (same simple holds
## the generator simulates). The draw comes off the same shuffled deck.

var deck: Array = []
var hand: Array = []
var held_cards := [false, false, false, false, false]
var cursor := 0
var _r: RandomNumberGenerator
var force_deck: Array = []  # tests: [rank, suit] cards dealt in order


func _a_word() -> String:
	return "DEAL"


func _play_label(action: String) -> String:
	if state != "play":
		return ""
	match action:
		"a": return "DRAW"
		"tool": return "HOLD"
		"action": return "HINT"
	return ""


func _dead(b: Dictionary) -> bool:
	if state == "play" and str(b["action"]) in ["left", "right"]:
		return false
	return super._dead(b)


func _next_card() -> Array:
	if not force_deck.is_empty():
		return force_deck.pop_front()
	return deck.pop_back()


func _deal() -> void:
	_r = out_rng()
	deck.clear()
	for r in range(2, 15):
		for s in 4:
			deck.append([r, s])
	# Fisher-Yates on the outcome stream.
	for i in range(deck.size() - 1, 0, -1):
		var j := _r.randi_range(0, i)
		var tmp: Variant = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	hand.clear()
	for i in 5:
		hand.append(_next_card())
	held_cards = [false, false, false, false, false]
	cursor = 0
	sfx("card_deal", "cards")
	state = "play"


func toggle(i: int) -> void:
	held_cards[i] = not held_cards[i]
	sfx("ui_tap", "pop")


func draw_cards() -> void:
	for i in 5:
		if not held_cards[i]:
			hand[i] = _next_card()
	sfx("card_flip", "page")
	reveal_len = 0.4
	reveal_t = 0.0
	state = "reveal"


func _play_step(_dt: float) -> void:
	if leave_after:
		draw_cards()  # B mid-hand: draw with the holds you have, then leave
	elif pressed("a"):
		draw_cards()
	elif repeat_pressed("left"):
		cursor = posmod(cursor - 1, 5)
	elif repeat_pressed("right"):
		cursor = posmod(cursor + 1, 5)
	elif pressed("tool"):
		toggle(cursor)
	elif pressed("action"):
		held_cards = CasinoRules.poker_hold_hint(hand)
		sfx("ui_tap", "pop")


func _reveal_done() -> void:
	finish(CasinoRules.poker_pays(hand) * stake)


func hit_rects() -> Array:
	var out: Array = []
	for i in 5:
		out.append(Rect2(12 + i * 50.0, 150, 46, 64))
	return out


func _tap_play(p: Vector2) -> void:
	if state != "play":
		return
	var hr := hit_rects()
	for i in 5:
		if (hr[i] as Rect2).has_point(p):
			cursor = i
			toggle(i)


func _draw_play(c: Control) -> void:
	draw_felt(c, Color(0.18, 0.08, 0.3))
	var pays: Dictionary = Casino.data().get("poker", {}).get("pays", {})
	var order: Array = Casino.data().get("poker", {}).get("order", [])
	var rk := CasinoRules.poker_rank(hand) if not hand.is_empty() else ""
	for i in order.size():
		var id := str(order[i])
		var y := 40.0 + i * 11.0
		var hl := id == rk and state in ["result", "play"]
		if hl:
			c.draw_rect(Rect2(40, y - 8, 190, 11), Color(1, 0.85, 0.3, 0.25))
		text(c, Vector2(44, y), str(pays[id][0]), 130, 8, Color(1, 0.95, 0.75) if hl else Color(1, 1, 1, 0.8))
		text(c, Vector2(170, y), "%dx" % int(pays[id][1]), 56, 8, Color(1, 0.95, 0.75) if hl else Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	if hand.is_empty():
		text(c, Vector2(0, 186), "Set your bet, then A to deal.", W, 9, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var hr := hit_rects()
		for i in 5:
			var r: Rect2 = hr[i]
			var cd: Array = hand[i]
			var up: bool = not (state == "reveal" and not held_cards[i] and reveal_t < reveal_len * 0.6)
			draw_card(c, r, CasinoRules.card_text(cd), int(cd[1]) in [1, 2], up, held_cards[i] and state == "play")
			if held_cards[i]:
				text_outline(c, Vector2(r.position.x, r.end.y + 12), "HELD", r.size.x, 8, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
			if state == "play" and i == cursor and deck_hidden():
				c.draw_rect(r.grow(4), Color(1, 1, 1, 0.6), false, 1.0)
		if state == "play":
			text(c, Vector2(0, 252), PadInput.words("Tap cards to hold · A draws"), W, 8, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	draw_bet_strip(c)
	draw_fx(c)
