class_name ArcadeWhack
extends ArcadeGame
## Whack-a-Grump: grumps pop out of nine holes; bop them before they duck back.
## Tap a hole, or steer the mallet with the arrows and press A.
## Gold grumps are worth more, helmet grumps take two bops, and never bop a
## bunny. 40 seconds; it gets faster and busier as the clock runs down.

const ROUND := 40.0
const HOLE := [Vector2(55, 118), Vector2(135, 118), Vector2(215, 118), Vector2(55, 200), Vector2(135, 200), Vector2(215, 200), Vector2(55, 282), Vector2(135, 282), Vector2(215, 282)]
const KINDS := {
	"grump": {"pts": 10, "hp": 1, "col": Color(0.62, 0.45, 0.88)},
	"gold": {"pts": 30, "hp": 1, "col": Color(1.0, 0.82, 0.25)},
	"helmet": {"pts": 20, "hp": 2, "col": Color(0.5, 0.75, 0.4)},
	"bunny": {"pts": -15, "hp": 1, "col": Color(0.98, 0.96, 0.95)},
}

var holes: Array = []
var cursor := 4
var spawn_t := 0.0
var combo := 0
var best_combo := 0
var hits := 0
var bunnies := 0
var escaped := 0
var mallet_t := 0.0
var mallet_at := 4


func _init() -> void:
	super()
	game_id = "whack"
	title = "Whack-a-Grump"
	fee = 10
	accent = Color(0.55, 0.88, 0.35)
	howto = ["Tap a hole, or aim with the arrows + A.", "Grump 10 · Gold 30 · Helmet 20 (two bops)", "Don't bop the bunnies! (-15)", "Bop in a row for a combo. 40 seconds."]


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(8, 392, 40, 40), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(92, 392, 40, 40), "label": "▶", "skin": "blue"},
		{"action": "up", "rect": Rect2(50, 358, 40, 36), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(50, 430, 40, 36), "label": "▼", "skin": "blue"},
		{"action": "a", "rect": Rect2(196, 378, 64, 64), "label": "BOP", "skin": "gold"},
		{"action": "b", "rect": Rect2(150, 430, 40, 40), "label": "B", "skin": "red", "hint": "quit"},
	]


func _setup_round() -> void:
	holes = []
	for i in 9:
		holes.append({"kind": "", "life": 0.0, "up": 0.0, "hp": 0, "hit": 0.0, "out": false})
	cursor = 4
	spawn_t = 0.8
	combo = 0
	best_combo = 0
	hits = 0
	bunnies = 0
	escaped = 0


func _pace() -> float:
	return clampf(play_t / ROUND, 0.0, 1.0)


func _step(dt: float) -> void:
	if pressed("b"):
		_finish()
		return
	if play_t >= ROUND:
		_finish()
		return
	mallet_t = maxf(0.0, mallet_t - dt)
	if pressed("left") and cursor % 3 > 0:
		cursor -= 1
	if pressed("right") and cursor % 3 < 2:
		cursor += 1
	if pressed("up") and cursor >= 3:
		cursor -= 3
	if pressed("down") and cursor < 6:
		cursor += 3
	if pressed("a"):
		whack(cursor)
	var pace := _pace()
	spawn_t -= dt
	var busy := 0
	for h: Dictionary in holes:
		if h["kind"] != "":
			busy += 1
	if spawn_t <= 0.0:
		spawn_t = lerpf(0.85, 0.32, pace) * rng.randf_range(0.7, 1.2)
		if busy < 1 + int(pace * 3.0):
			_pop()
	for h: Dictionary in holes:
		h["hit"] = maxf(0.0, float(h["hit"]) - dt)
		if h["kind"] == "":
			h["up"] = maxf(0.0, float(h["up"]) - dt * 8.0)
			continue
		h["life"] = float(h["life"]) - dt
		if bool(h["out"]):
			h["up"] = minf(1.0, float(h["up"]) + dt * 9.0)
		if float(h["life"]) <= 0.0 and bool(h["out"]):
			h["out"] = false
			if str(h["kind"]) != "bunny" and float(h["hit"]) <= 0.0:
				escaped += 1
				combo = 0
		if not bool(h["out"]):
			h["up"] = maxf(0.0, float(h["up"]) - dt * 8.0)
			if float(h["up"]) <= 0.0:
				h["kind"] = ""


func _pop() -> void:
	var free: Array = []
	for i in 9:
		if holes[i]["kind"] == "" and float(holes[i]["up"]) <= 0.0:
			free.append(i)
	if free.is_empty():
		return
	var i: int = free[rng.randi() % free.size()]
	var pace := _pace()
	var roll := rng.randf()
	var kind := "grump"
	if roll < 0.08 + pace * 0.06:
		kind = "gold"
	elif roll < 0.22 + pace * 0.1:
		kind = "bunny"
	elif roll < 0.34 + pace * 0.12:
		kind = "helmet"
	var life := lerpf(1.25, 0.6, pace) * (0.65 if kind == "gold" else 1.0) * (1.3 if kind == "helmet" else 1.0)
	holes[i] = {"kind": kind, "life": life, "up": 0.0, "hp": int(KINDS[kind]["hp"]), "hit": 0.0, "out": true}
	sfx("pop", "ui_tap")


## Swing at hole i (tap or A). Returns the points it scored.
func whack(i: int) -> int:
	if state != "play" or i < 0 or i > 8:
		return 0
	cursor = i
	mallet_t = 0.18
	mallet_at = i
	var h: Dictionary = holes[i]
	if str(h["kind"]) == "" or not bool(h["out"]) or float(h["up"]) < 0.35:
		sfx("swing", "ui_tap")
		combo = 0
		return 0
	var k := str(h["kind"])
	var p: Vector2 = HOLE[i] + Vector2(0, -14)
	if k == "bunny":
		score = maxi(0, score - 15)
		bunnies += 1
		combo = 0
		h["out"] = false
		h["hit"] = 0.4
		sfx("whimper", "nope")
		float_text(p, "-15", Color(1, 0.5, 0.5))
		shake(2.0)
		return -15
	h["hp"] = int(h["hp"]) - 1
	sfx("hit", "thud")
	shake(2.0)
	if int(h["hp"]) > 0:
		burst(p, Color(0.8, 0.8, 0.85), 6, 60.0)
		float_text(p, "CLANK", Color(0.85, 0.9, 1))
		h["life"] = float(h["life"]) + 0.3
		return 0
	combo += 1
	best_combo = maxi(best_combo, combo)
	hits += 1
	var mult := 1 + mini(combo / 4, 2)
	var pts := int(KINDS[k]["pts"]) * mult
	score += pts
	h["out"] = false
	h["hit"] = 0.4
	burst(p, KINDS[k]["col"], 12, 90.0)
	burst(p, Color(1, 1, 0.7), 6, 50.0, 2.0, 0.0)
	float_text(p, ("+%d" % pts) + (" x%d" % mult if mult > 1 else ""), Color(1, 0.95, 0.5) if k != "gold" else Color(1, 0.8, 0.2))
	if k == "gold":
		sfx("coin")
	return pts


func _tap(p: Vector2) -> void:
	if state != "play":
		return
	for i in 9:
		if p.distance_to(HOLE[i] + Vector2(0, -10)) < 36.0:
			whack(i)
			return


func _finish() -> void:
	game_over(["!TIME!" if play_t >= ROUND else "!GAME ENDED", "Bops %d · best combo %d" % [hits, best_combo], "Bunnies bopped: %d" % bunnies])


func _tickets_for(s: int) -> int:
	return s / 12


func _good_tickets() -> int:
	return 12


func _draw_play(c: Control) -> void:
	# Lawn (painted backdrop; code stripes if the art is missing).
	if not cover(c, "stage_lawn", PLAY, 0.0):
		for i in 21:
			c.draw_rect(Rect2(0, TOP + i * 16, W, 16), Color(0.35, 0.62, 0.3) if i % 2 == 0 else Color(0.32, 0.58, 0.28))
	c.draw_rect(Rect2(0, TOP, W, 46), Color(0.16, 0.1, 0.22, 0.82))
	spr(c, "whack_bush", Rect2(-14, 318, 50, 40))
	spr(c, "whack_bush", Rect2(236, 320, 46, 36), Color.WHITE, true)
	# Timer bar.
	var left := clampf(1.0 - play_t / ROUND, 0.0, 1.0) if state == "play" else 1.0
	c.draw_rect(Rect2(12, 32, 246, 8), Color(0, 0, 0, 0.4))
	c.draw_rect(Rect2(12, 32, 246 * left, 8), Color(0.5, 0.9, 0.4).lerp(Color(1, 0.35, 0.3), 1.0 - left))
	text_outline(c, Vector2(12, 58), "Score %d" % score, 120, 10, Color.WHITE)
	if combo >= 2:
		text_outline(c, Vector2(140, 58), "Combo %d" % combo, 118, 10, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	if holes.is_empty():
		for i in 9:
			_hole(c, i, null)
	else:
		for i in 9:
			_hole(c, i, holes[i])
	# Mallet.
	var mp: Vector2 = HOLE[mallet_at if mallet_t > 0.0 else cursor] + Vector2(18, -30)
	var ang := -0.9 if mallet_t > 0.0 else -0.2 + sin(t * 4.0) * 0.08
	if state == "play":
		c.draw_rect(Rect2(HOLE[cursor] - Vector2(30, 34), Vector2(60, 50)), Color(1, 1, 0.6, 0.18 + 0.1 * sin(t * 8.0)), false, 1.0)
		var mtx := ArcadeGame.tex("whack_mallet")
		if mtx:
			# The painted mallet lies head-up-left; turn it so it swings down onto the hole.
			c.draw_set_transform(mp + draw_off + Vector2(0, 10), ang - 0.2, Vector2.ONE)
			var ms := Vector2(mtx.get_size()) * 0.42
			c.draw_texture_rect(mtx, Rect2(-ms.x * 0.75, -ms.y * 0.8, ms.x, ms.y), false)
			c.draw_set_transform(draw_off)
			draw_fx(c)
			return
		c.draw_set_transform(mp + draw_off, ang, Vector2.ONE)
		c.draw_rect(Rect2(-2, -2, 4, 26), Color(0.6, 0.4, 0.2))
		c.draw_rect(Rect2(-11, -10, 22, 12), Color(0.85, 0.25, 0.25))
		c.draw_rect(Rect2(-11, -10, 22, 3), Color(1, 0.55, 0.5))
		c.draw_rect(Rect2(-11, -10, 22, 12), Color(0.35, 0.08, 0.08), false, 1.0)
		c.draw_set_transform(draw_off)
	draw_fx(c)


const SPRITE := {"grump": "whack_grump", "gold": "whack_gold", "helmet": "whack_helmet", "bunny": "whack_bunny"}


## Painted hole and critter: the critter rises out of the hole, cut at the rim,
## with the hole's front lip drawn over it until it is fully up.
func _hole_art(c: Control, p: Vector2, d: Variant) -> bool:
	var htx := ArcadeGame.tex("whack_hole")
	if htx == null:
		return false
	var hs := Vector2(htx.get_size()) * 0.5
	var hr := Rect2(p.x - hs.x * 0.5, p.y - hs.y * 0.55, hs.x, hs.y)
	c.draw_texture_rect(htx, hr, false)
	if d == null or str((d as Dictionary)["kind"]) == "":
		return true
	var dd: Dictionary = d
	var up := float(dd["up"])
	if up <= 0.02:
		return true
	var k := str(dd["kind"])
	var hit := float(dd["hit"]) > 0.0
	var name := "whack_dizzy" if hit and k != "bunny" else str(SPRITE[k])
	var ctx := ArcadeGame.tex(name)
	if ctx == null:
		return true
	var cs := Vector2(ctx.get_size()) * 0.5
	var col := Color.WHITE
	if hit and k == "bunny":
		col = Color(1, 0.6, 0.6)
	elif hit and k == "gold":
		col = Color(1, 0.9, 0.4)
	elif k == "helmet" and int(dd["hp"]) <= 1 and not hit:
		col = Color(1, 0.85, 0.85) if fmod(t, 0.2) < 0.1 else Color.WHITE
	var bottom := hr.end.y - 2.0
	var top := bottom - cs.y * up
	var clip := hr.position.y + hs.y * 0.5  # the opening's middle
	var vis_top := top
	var vis_bot := minf(bottom, maxf(clip, top + cs.y * 0.55)) if up < 0.95 else bottom
	if vis_bot > vis_top:
		var src_h := (vis_bot - vis_top) * 2.0
		c.draw_texture_rect_region(ctx, Rect2(p.x - cs.x * 0.5, vis_top, cs.x, vis_bot - vis_top), Rect2(0, 0, cs.x * 2.0, src_h), col)
	if up < 0.95:
		var lip_y := hs.y * 0.5
		c.draw_texture_rect_region(htx, Rect2(hr.position.x, hr.position.y + lip_y, hs.x, hs.y - lip_y), Rect2(0, lip_y * 2.0, hs.x * 2.0, (hs.y - lip_y) * 2.0))
	if hit and k != "bunny":
		for st in 3:
			var a := t * 6.0 + st * TAU / 3.0
			c.draw_rect(Rect2(p.x + cos(a) * 14 - 1, top - 4 + sin(a) * 3, 3, 3), Color(1, 0.95, 0.4))
	return true


func _hole(c: Control, i: int, h: Variant) -> void:
	var p: Vector2 = HOLE[i]
	if _hole_art(c, p, h):
		return
	c.draw_set_transform(p + draw_off, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, 30, Color(0.22, 0.14, 0.08))
	c.draw_circle(Vector2(0, -3), 26, Color(0.08, 0.05, 0.03))
	c.draw_set_transform(draw_off)
	if h == null or str((h as Dictionary)["kind"]) == "":
		_dirt_lip(c, p)
		return
	var d: Dictionary = h
	var up := float(d["up"])
	var k := str(d["kind"])
	var by := p.y + 4 - up * 30.0
	var col: Color = KINDS[k]["col"]
	var hit := float(d["hit"]) > 0.0
	# Body (clipped by redrawing the lip in front).
	if k == "bunny":
		c.draw_rect(Rect2(p.x - 9, by - 30, 5, 16), col)
		c.draw_rect(Rect2(p.x + 4, by - 30, 5, 16), col)
		c.draw_rect(Rect2(p.x - 8, by - 28, 3, 12), Color(1, 0.7, 0.8))
		c.draw_rect(Rect2(p.x + 5, by - 28, 3, 12), Color(1, 0.7, 0.8))
	c.draw_circle(Vector2(p.x, by - 6), 15, col.darkened(0.35))
	c.draw_circle(Vector2(p.x, by - 7), 14, col)
	c.draw_rect(Rect2(p.x - 14, by - 7, 28, 20), col)
	if k == "helmet" and int(d["hp"]) > 1:
		c.draw_arc(Vector2(p.x, by - 8), 15, PI, TAU, 16, Color(0.7, 0.72, 0.8), 6.0)
		c.draw_rect(Rect2(p.x - 2, by - 25, 4, 5), Color(0.85, 0.3, 0.3))
	# Face.
	if hit:
		c.draw_line(Vector2(p.x - 7, by - 10), Vector2(p.x - 3, by - 6), Color.BLACK, 1.5)
		c.draw_line(Vector2(p.x - 3, by - 10), Vector2(p.x - 7, by - 6), Color.BLACK, 1.5)
		c.draw_line(Vector2(p.x + 3, by - 10), Vector2(p.x + 7, by - 6), Color.BLACK, 1.5)
		c.draw_line(Vector2(p.x + 7, by - 10), Vector2(p.x + 3, by - 6), Color.BLACK, 1.5)
		for s in 3:
			var a := t * 6.0 + s * TAU / 3.0
			c.draw_rect(Rect2(p.x + cos(a) * 12 - 1, by - 24 + sin(a) * 3, 3, 3), Color(1, 0.95, 0.4))
	elif k == "bunny":
		c.draw_rect(Rect2(p.x - 6, by - 10, 3, 3), Color.BLACK)
		c.draw_rect(Rect2(p.x + 3, by - 10, 3, 3), Color.BLACK)
		c.draw_rect(Rect2(p.x - 1, by - 5, 2, 2), Color(1, 0.5, 0.6))
	else:
		# Grumpy brows.
		c.draw_line(Vector2(p.x - 9, by - 14), Vector2(p.x - 3, by - 11), Color(0.1, 0.05, 0.1), 2.0)
		c.draw_line(Vector2(p.x + 9, by - 14), Vector2(p.x + 3, by - 11), Color(0.1, 0.05, 0.1), 2.0)
		c.draw_rect(Rect2(p.x - 7, by - 10, 3, 3), Color.WHITE)
		c.draw_rect(Rect2(p.x + 4, by - 10, 3, 3), Color.WHITE)
		c.draw_rect(Rect2(p.x - 6, by - 9, 2, 2), Color.BLACK)
		c.draw_rect(Rect2(p.x + 5, by - 9, 2, 2), Color.BLACK)
		c.draw_arc(Vector2(p.x, by - 1), 4, PI + 0.4, TAU - 0.4, 8, Color(0.1, 0.05, 0.1), 1.5)
		if k == "gold":
			c.draw_rect(Rect2(p.x - 1, by - 22 + sin(t * 10.0), 2, 2), Color.WHITE)
	_dirt_lip(c, p)


func _dirt_lip(c: Control, p: Vector2) -> void:
	# Front half of the hole rim and some grass to hide the body's bottom.
	c.draw_rect(Rect2(p.x - 32, p.y + 5, 64, 30), Color(0.35, 0.62, 0.3) if int((p.y - TOP) / 16.0) % 2 == 0 else Color(0.32, 0.58, 0.28))
	c.draw_set_transform(p + draw_off + Vector2(0, 4), 0.0, Vector2(1.0, 0.25))
	c.draw_arc(Vector2.ZERO, 30, 0.0, PI, 16, Color(0.45, 0.3, 0.18), 10.0)
	c.draw_set_transform(draw_off)
	for g in 5:
		var gx := p.x - 26 + g * 13
		c.draw_line(Vector2(gx, p.y + 12), Vector2(gx - 2, p.y + 6), Color(0.25, 0.5, 0.2), 1.0)


func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.35, 0.62, 0.3))
	if cover(c, "stage_lawn", r, 0.6):
		for i in 2:
			var px := r.position.x + 34 + i * 132
			_hole_art(c, Vector2(px, r.end.y - 26), {"kind": ["grump", "bunny"][i], "up": 0.5 + 0.5 * absf(sin(t * 2.0 + i)), "hp": 1, "hit": 0.0})
		draw_cabinet(c, r)
		return
	for i in 3:
		var p := Vector2(r.position.x + 40 + i * 60, r.end.y - 30)
		var fake := {"kind": ["grump", "gold", "bunny"][i], "up": 0.5 + 0.5 * absf(sin(t * 2.0 + i)), "hp": 1, "hit": 0.0, "out": true}
		_hole_at(c, p, fake)


func _hole_at(c: Control, p: Vector2, d: Dictionary) -> void:
	c.draw_set_transform(p + draw_off, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, 24, Color(0.08, 0.05, 0.03))
	c.draw_set_transform(draw_off)
	var col: Color = KINDS[str(d["kind"])]["col"]
	var by := p.y + 4 - float(d["up"]) * 26.0
	c.draw_circle(Vector2(p.x, by - 7), 13, col)
	c.draw_rect(Rect2(p.x - 13, by - 7, 26, 14), col)
	c.draw_rect(Rect2(p.x - 6, by - 10, 3, 3), Color.BLACK)
	c.draw_rect(Rect2(p.x + 3, by - 10, 3, 3), Color.BLACK)
	c.draw_rect(Rect2(p.x - 28, p.y + 4, 56, 12), Color(0.35, 0.62, 0.3))
