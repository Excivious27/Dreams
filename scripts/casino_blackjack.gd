extends CasinoGame
## Blackjack: 6-deck shoe shuffled every hand, dealer peeks for blackjack, stands on
## all 17s, blackjack pays 6 to 5, double on any first two cards, no split or
## insurance (phone-sized). A hits, X stands, Y doubles. B mid-hand stands and leaves.

var shoe: Array = []
var player: Array = []
var dealer: Array = []
var doubled := false
var _dealer_shown := 2   # dealer cards visible during the reveal
var force_deck: Array = []  # tests: cards dealt in this order (player, dealer, player, dealer, then hits)
var _r: RandomNumberGenerator


func _a_word() -> String:
	return "DEAL"


func _play_label(action: String) -> String:
	if state != "play":
		return ""
	match action:
		"a": return "HIT"
		"tool": return "STAND"
		"action": return "DOUBLE" if can_double() else ""
	return ""


func staked() -> int:
	return stake * (2 if doubled else 1)


func can_double() -> bool:
	if player.size() != 2 or doubled:
		return false
	return practice or free_play or Casino.why_no_bet(stake) == ""


func _draw_card_val() -> int:
	if not force_deck.is_empty():
		return int(force_deck.pop_front())
	var i := _r.randi_range(0, shoe.size() - 1)
	var c: int = shoe[i]
	shoe.remove_at(i)
	return c


func _deal() -> void:
	_r = out_rng()
	shoe.clear()
	for d in int(Casino.data().get("blackjack", {}).get("decks", 6)):
		for s in 4:
			for rk in range(1, 14):
				shoe.append(rk)
	player = [_draw_card_val()]
	dealer = [_draw_card_val()]
	player.append(_draw_card_val())
	dealer.append(_draw_card_val())
	doubled = false
	_dealer_shown = 1
	sfx("card_deal", "cards")
	# Peek: either natural ends the hand at once.
	if CasinoRules.bj_natural(player) or CasinoRules.bj_natural(dealer):
		_to_reveal()
		return
	state = "play"


func hit() -> void:
	player.append(_draw_card_val())
	sfx("card_deal", "cards")
	if int(CasinoRules.bj_total(player)[0]) >= 21:
		_to_reveal()


func stand() -> void:
	sfx("ui_tap", "pop")
	_to_reveal()


func double_down() -> void:
	if not can_double():
		return
	if not Casino.take(stake, table, practice or free_play):
		say("The table can't take a second bet.")
		return
	doubled = true
	sfx("chip_clack", "pin_tap")
	player.append(_draw_card_val())
	_to_reveal()


func _to_reveal() -> void:
	# The dealer plays out now (drawn before the reveal); the reveal shows the cards.
	if int(CasinoRules.bj_total(player)[0]) <= 21 and not CasinoRules.bj_natural(player):
		while CasinoRules.dealer_should_hit(dealer):
			dealer.append(_draw_card_val())
	_dealer_shown = 1
	reveal_len = 0.35 + 0.4 * (dealer.size() - 1)
	reveal_t = 0.0
	state = "reveal"


func _play_step(_dt: float) -> void:
	if leave_after:
		stand()
	elif pressed("a"):
		hit()
	elif pressed("tool"):
		stand()
	elif pressed("action"):
		double_down()


func gross() -> int:
	return int(round(CasinoRules.bj_settle(player, dealer, doubled) * stake))


func _reveal_done() -> void:
	_dealer_shown = dealer.size()
	sfx("card_flip", "page")
	finish(gross())


func _hand_x(n: int, i: int) -> float:
	var fan := minf(34.0, 180.0 / maxf(1.0, n))
	return 135.0 - (fan * (n - 1) + 30.0) * 0.5 + i * fan


func _draw_hand(c: Control, cards: Array, y: float, shown: int) -> void:
	for i in cards.size():
		var r := Rect2(_hand_x(cards.size(), i), y, 30, 42)
		var v := int(cards[i])
		var suit: String = CasinoRules.SUITS[(v * 7 + i * 3) % 4]  # suit is decoration in blackjack
		draw_card(c, r, CasinoRules.card_text(v) + suit, suit in ["♥", "♦"], i < shown)


func _draw_play(c: Control) -> void:
	draw_felt(c)
	text(c, Vector2(0, 54), "BLACKJACK PAYS 6 TO 5 · DEALER PEEKS · STANDS ON ALL 17s", W, 7, Color(FELT_EDGE, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	if player.is_empty():
		text(c, Vector2(0, 160), "Set your bet, then A to deal.", W, 9, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var shown := 1
		if state == "reveal":
			shown = mini(dealer.size(), 2 + int(maxf(0.0, reveal_t - 0.35) / 0.4)) if reveal_t >= 0.35 else 1
		elif state in ["result", "bet"]:
			shown = dealer.size()
		_draw_hand(c, dealer, 72, shown)
		var dt: Array = CasinoRules.bj_total(dealer.slice(0, shown))
		text(c, Vector2(0, 128), "Dealer %s%d" % ["soft " if dt[1] and int(dt[0]) < 21 else "", int(dt[0])], W, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_hand(c, player, 190, 99)
		var pt: Array = CasinoRules.bj_total(player)
		var lbl := "Blackjack!" if CasinoRules.bj_natural(player) else ("Bust" if int(pt[0]) > 21 else ("You %s%d" % ["soft " if pt[1] else "", int(pt[0])]))
		text_outline(c, Vector2(0, 248), lbl + ("  (doubled)" if doubled else ""), W, 10, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		if state == "play":
			text(c, Vector2(0, 270), PadInput.words("A hit · X stand") + (" · " + PadInput.words("Y double") if can_double() else ""), W, 8, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	draw_bet_strip(c)
	draw_fx(c)


func hit_rects() -> Array:
	return []
