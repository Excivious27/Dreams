class_name ArcadePause
## Pause card shared by Crystal Stack and Whack-a-Grump: B during a round no
## longer throws the coin away on one stray tap; it pauses, and the card asks
## A: keep playing / B: end the round. Losing focus (phone call, app switch)
## pauses too. The round clock stands still while paused (ArcadeGame only
## advances play_t in "play").


## B pressed during play: open the card.
static func pause(g: ArcadeGame) -> void:
	if g.state != "play":
		return
	g.state = "paused"
	g.set_meta("pause_t", 0.0)
	g.sfx("menu_open", "ui_tap")


## One fixed step while paused. Returns true when the round should end.
static func step(g: ArcadeGame, dt: float) -> bool:
	var pt := float(g.get_meta("pause_t", 0.0)) + dt
	g.set_meta("pause_t", pt)
	if g.pressed("a"):
		g.state = "play"
		g.sfx("menu_close", "ui_tap")
	elif g.pressed("b") and pt >= 0.15:  # a jittery double tap on B must not also quit
		g.state = "play"
		return true
	return false


static func draw(g: ArcadeGame, c: Control) -> void:
	c.draw_rect(ArcadeGame.PLAY, Color(0, 0, 0, 0.6))
	var r := Rect2(40, 120, 190, 104)
	g.panel(c, r, Color(0.1, 0.06, 0.16, 0.97), g.accent)
	g.text_outline(c, Vector2(r.position.x, r.position.y + 26), "PAUSED", r.size.x, 16, g.accent, HORIZONTAL_ALIGNMENT_CENTER)
	g.text(c, Vector2(r.position.x, r.position.y + 46), "Score %d" % g.score, r.size.x, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	g.text(c, Vector2(r.position.x, r.position.y + 70), "A: keep playing", r.size.x, 10, Color(0.85, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	g.text(c, Vector2(r.position.x, r.position.y + 88), "B: end the round", r.size.x, 10, Color(1, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER)


## The B button's caption follows what B does right now.
static func hint(g: ArcadeGame, deck: Array) -> void:
	var word := "pause" if g.state == "play" else ("end" if g.state == "paused" else "leave")
	for b: Dictionary in deck:
		if str(b["action"]) == "b":
			b["hint"] = word
