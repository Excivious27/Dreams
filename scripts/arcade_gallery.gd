class_name ArcadeGallery
extends ArcadeGame
## Duck Pond: a cork-popper gallery. Toy ducks paddle across three lanes; aim
## the sight with the arrows (or tap where you want to shoot) and press A.
## Far lanes pay more, golden ducks pay big, and don't pop the frogs.
## 40 corks and 45 seconds; the ducks speed up as time runs out.

const ROUND := 45.0
const CORKS := 40
const LANES := [112.0, 188.0, 264.0]
const LANE_PTS := [30, 20, 10]
const LANE_SPEED := [52.0, 40.0, 30.0]
const LANE_SCALE := [0.75, 0.9, 1.05]

var ducks: Array = []
var sight := Vector2(135, 190)
var corks := CORKS
var cool := 0.0
var spawn := [0.0, 0.6, 1.2]
var shots := 0
var hits := 0
var frogs := 0
var golds := 0
var cork_fx: Array = []


func _init() -> void:
	super()
	game_id = "gallery"
	title = "Duck Pond"
	fee = 10
	accent = Color(1.0, 0.8, 0.3)
	howto = ["Aim with the arrows (or tap) · A pop", "Back lane 30 · middle 20 · front 10", "Golden duck 60 · frog -20", "40 corks, 45 seconds."]


func _deck_buttons() -> Array:
	var d := super()
	for b: Dictionary in d:
		if b["action"] == "a":
			b["label"] = "POP"
		elif b["action"] == "b":
			b["hint"] = "quit"
	return d


func _setup_round() -> void:
	ducks = []
	sight = Vector2(135, 190)
	corks = CORKS
	cool = 0.0
	spawn = [0.2, 0.8, 1.4]
	shots = 0
	hits = 0
	frogs = 0
	golds = 0
	cork_fx = []
	# A few already on the water.
	for lane in 3:
		for k in 2:
			_spawn(lane, rng.randf_range(30.0, 240.0))


func _pace() -> float:
	return clampf(play_t / ROUND, 0.0, 1.0)


func _dir(lane: int) -> float:
	return 1.0 if lane % 2 == 0 else -1.0


func _spawn(lane: int, at := -999.0) -> void:
	var d := _dir(lane)
	var roll := rng.randf()
	var kind := "duck"
	if roll < 0.07 + _pace() * 0.05:
		kind = "gold"
	elif roll < 0.2 + _pace() * 0.08:
		kind = "frog"
	var x := at if at > -900.0 else (-20.0 if d > 0 else W + 20.0)
	ducks.append({"lane": lane, "x": x, "kind": kind, "down": 0.0, "alive": true, "bob": rng.randf() * TAU})


func _step(dt: float) -> void:
	if pressed("b") or play_t >= ROUND or (corks <= 0 and cool <= 0.0 and cork_fx.is_empty()):
		_finish()
		return
	cool = maxf(0.0, cool - dt)
	var mv := Vector2((1.0 if held("right") else 0.0) - (1.0 if held("left") else 0.0), (1.0 if held("down") else 0.0) - (1.0 if held("up") else 0.0))
	sight = (sight + mv * 150.0 * dt).clamp(Vector2(10, 70), Vector2(260, 300))
	if pressed("a"):
		shoot()
	var pace := _pace()
	for lane in 3:
		spawn[lane] = float(spawn[lane]) - dt
		if float(spawn[lane]) <= 0.0:
			spawn[lane] = lerpf(1.6, 0.7, pace) * rng.randf_range(0.75, 1.3)
			_spawn(lane)
	for i in range(ducks.size() - 1, -1, -1):
		var d: Dictionary = ducks[i]
		var lane := int(d["lane"])
		var sp := float(LANE_SPEED[lane]) * (1.0 + pace * 1.3) * (1.4 if str(d["kind"]) == "gold" else 1.0)
		d["x"] = float(d["x"]) + _dir(lane) * sp * dt
		if not bool(d["alive"]):
			d["down"] = minf(1.0, float(d["down"]) + dt * 5.0)
		if float(d["x"]) < -40.0 or float(d["x"]) > W + 40.0 or float(d["down"]) >= 1.0:
			ducks.remove_at(i)
	for i in range(cork_fx.size() - 1, -1, -1):
		var f: Dictionary = cork_fx[i]
		f["t"] = float(f["t"]) + dt
		if float(f["t"]) >= 0.12:
			cork_fx.remove_at(i)


## Pop a cork at the sight. Returns points scored.
func shoot() -> int:
	if state != "play" or cool > 0.0 or corks <= 0:
		if corks <= 0:
			sfx("dry_click", "nope")
		return 0
	corks -= 1
	shots += 1
	cool = 0.22
	sfx("pop", "shot")
	cork_fx.append({"to": sight, "t": 0.0})
	# Front lanes are drawn on top, so test them first.
	var best := -1
	for lane in [2, 1, 0]:
		for i in ducks.size():
			var d: Dictionary = ducks[i]
			if int(d["lane"]) != lane or not bool(d["alive"]):
				continue
			var s := float(LANE_SCALE[lane])
			var ctr := Vector2(float(d["x"]), float(LANES[lane]) - 16.0 * s)
			if absf(sight.x - ctr.x) < 13.0 * s and absf(sight.y - ctr.y) < 14.0 * s:
				best = i
				break
		if best >= 0:
			break
	if best < 0:
		burst(sight, Color(0.5, 0.7, 1.0), 4, 30.0)
		return 0
	var dk: Dictionary = ducks[best]
	dk["alive"] = false
	var lane2 := int(dk["lane"])
	var pts := int(LANE_PTS[lane2])
	match str(dk["kind"]):
		"gold":
			pts = 60
			golds += 1
			sfx("coin")
		"frog":
			pts = -20
			frogs += 1
			sfx("nope", "whimper")
		_:
			sfx("hit", "thud")
	score = maxi(0, score + pts)
	if pts > 0:
		hits += 1
	burst(sight, Color(1, 0.9, 0.4) if pts > 0 else Color(0.5, 0.9, 0.5), 10, 70.0)
	float_text(sight + Vector2(0, -12), ("+%d" % pts) if pts > 0 else str(pts), Color(1, 0.95, 0.5) if pts > 0 else Color(1, 0.5, 0.5))
	return pts


func _tap(p: Vector2) -> void:
	if state != "play":
		return
	sight = p.clamp(Vector2(10, 70), Vector2(260, 300))
	shoot()


func _finish() -> void:
	var acc := int(100.0 * hits / maxf(1.0, shots))
	game_over(["!TIME!" if play_t >= ROUND else ("!OUT OF CORKS" if corks <= 0 else "!GAME ENDED"), "Hits %d/%d (%d%%)" % [hits, shots, acc], "Golden ducks %d · frogs %d" % [golds, frogs]])


func _tickets_for(s: int) -> int:
	return s / 15


func _good_tickets() -> int:
	return 12


func _draw_play(c: Control) -> void:
	# Booth: the painted back wall with its three shelf rails lined up with the lanes.
	var booth := ArcadeGame.tex("stage_booth")
	if booth:
		var bs := Vector2(booth.get_size())
		var k := bs.x / 540.0
		c.draw_texture_rect_region(booth, PLAY, Rect2(0, 88.0 * k, bs.x, PLAY.size.y * 2.0 * k))
	else:
		c.draw_rect(PLAY, Color(0.95, 0.88, 0.7))
	for i in 10:
		c.draw_rect(Rect2(i * 27, TOP, 27, 22), Color(0.9, 0.25, 0.3) if i % 2 == 0 else Color(1, 0.97, 0.9))
		c.draw_circle(Vector2(i * 27 + 13.5, TOP + 22), 13.5, Color(0.9, 0.25, 0.3) if i % 2 == 0 else Color(1, 0.97, 0.9))
	var left := clampf(1.0 - play_t / ROUND, 0.0, 1.0) if state == "play" else 1.0
	c.draw_rect(Rect2(10, 64, 250, 5), Color(0, 0, 0, 0.2))
	c.draw_rect(Rect2(10, 64, 250 * left, 5), Color(0.3, 0.6, 1.0))
	for lane in 3:
		var y := float(LANES[lane])
		if booth == null:
			c.draw_rect(Rect2(0, y - 34, W, 6), Color(0.65, 0.45, 0.3))
			c.draw_rect(Rect2(0, y - 3, W, 22), Color(0.25, 0.5, 0.9).darkened(0.1 * (2 - lane)))
		_draw_lane_ducks(c, lane)
		# Painted tin waves in front of the ducks' stands.
		var pts := PackedVector2Array()
		pts.append(Vector2(0, y + 6))
		for x in range(0, 277, 6):
			pts.append(Vector2(x, y - 4 + sin(x * 0.12 + t * (3.0 + lane) * _dir(lane)) * 2.5))
		pts.append(Vector2(W, y + 6))
		c.draw_colored_polygon(pts, Color(0.3, 0.58, 0.95).darkened(0.08 * (2 - lane)))
		for x in range(0, 270, 18):
			var wx := fposmod(x + t * 20.0 * _dir(lane), 270.0)
			c.draw_rect(Rect2(wx, y, 6, 1), Color(1, 1, 1, 0.45))
		text_outline(c, Vector2(W - 34, y + 4), "%d" % LANE_PTS[lane], 30, 7, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	if booth == null:
		c.draw_rect(Rect2(0, 286, W, 66), Color(0.55, 0.35, 0.22))
		c.draw_rect(Rect2(0, 286, W, 3), Color(0.75, 0.52, 0.32))
	else:
		c.draw_rect(Rect2(0, 292, W, 60), Color(0.3, 0.18, 0.1, 0.35))
	# Corks on the counter.
	for i in mini(corks, 40):
		var cx := 10 + (i % 20) * 12.5
		var cy := 300 + (i / 20) * 12
		c.draw_rect(Rect2(cx, cy, 5, 8), Color(0.8, 0.6, 0.38))
		c.draw_rect(Rect2(cx, cy, 5, 2), Color(0.92, 0.75, 0.5))
	text_outline(c, Vector2(10, 340), "Corks %d" % corks, 120, 8, Color.WHITE)
	text_outline(c, Vector2(140, 340), "Score %d" % score, 120, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	for f: Dictionary in cork_fx:
		var to: Vector2 = f["to"]
		var from := Vector2(135, 352)
		var p := from.lerp(to, float(f["t"]) / 0.12)
		c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 5)), Color(0.85, 0.62, 0.38))
	var ptx := ArcadeGame.tex("gallery_popper")
	if ptx and state == "play":
		var base := Vector2(135, 340)
		var ang := (sight - base).angle()
		var ps := Vector2(ptx.get_size()) * 0.42
		c.draw_set_transform(base + draw_off, ang, Vector2(1, -1 if absf(ang) > PI / 2 else 1))
		c.draw_texture_rect(ptx, Rect2(-ps.x * 0.3, -ps.y * 0.5, ps.x, ps.y), false)
		c.draw_set_transform(draw_off)
	if state == "play":
		var s := sight
		var col := Color(0.9, 0.15, 0.15)
		c.draw_arc(s, 9, 0, TAU, 20, col, 1.5)
		c.draw_line(s + Vector2(-14, 0), s + Vector2(-4, 0), col, 1.0)
		c.draw_line(s + Vector2(4, 0), s + Vector2(14, 0), col, 1.0)
		c.draw_line(s + Vector2(0, -14), s + Vector2(0, -4), col, 1.0)
		c.draw_line(s + Vector2(0, 4), s + Vector2(0, 14), col, 1.0)
		c.draw_rect(Rect2(s - Vector2(0.5, 0.5), Vector2(1, 1)), col)
	draw_fx(c)


func _draw_lane_ducks(c: Control, lane: int) -> void:
	for d: Dictionary in ducks:
		if int(d["lane"]) != lane:
			continue
		var s := float(LANE_SCALE[lane])
		var base := Vector2(float(d["x"]), float(LANES[lane]) + sin(t * 4.0 + float(d["bob"])) * 1.0)
		var flip := float(d["down"])
		c.draw_set_transform(base + draw_off, 0.0, Vector2(s * _dir(lane), s * (1.0 - flip)))
		_duck(c, str(d["kind"]), bool(d["alive"]))
		c.draw_set_transform(draw_off)


func _duck(c: Control, kind: String, alive: bool) -> void:
	# Drawn facing right with its stand's foot at y=0.
	var name := {"duck": "gallery_duck", "gold": "gallery_duck_gold", "frog": "gallery_frog"}.get(kind, "gallery_duck") as String
	if spr_h(c, name, Vector2(0, 2), 30.0, Color.WHITE if alive else Color(0.75, 0.75, 0.75)):
		return
	if kind == "frog":
		var g := Color(0.35, 0.75, 0.3)
		c.draw_circle(Vector2(0, -6), 9, g)
		c.draw_circle(Vector2(-4, -15), 3.5, g)
		c.draw_circle(Vector2(4, -15), 3.5, g)
		c.draw_rect(Rect2(-5, -16, 2, 2), Color.BLACK)
		c.draw_rect(Rect2(3, -16, 2, 2), Color.BLACK)
		c.draw_line(Vector2(-4, -6), Vector2(4, -6), Color(0.15, 0.35, 0.15), 1.0)
		c.draw_rect(Rect2(-12, -26, 24, 7), Color(1, 1, 1))
		c.draw_rect(Rect2(-12, -26, 24, 7), Color(0.8, 0.2, 0.2), false, 1.0)
		c.draw_line(Vector2(-8, -24), Vector2(8, -21), Color(0.8, 0.2, 0.2), 1.0)
		return
	var col := Color(1, 0.88, 0.25) if kind == "duck" else Color(1, 0.72, 0.1)
	c.draw_circle(Vector2(-1, -6), 9, col.darkened(0.25))
	c.draw_circle(Vector2(-1, -7), 8.5, col)
	c.draw_rect(Rect2(-10, -8, 18, 8), col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(-15, -12), Vector2(-9, -3)]), col)
	c.draw_circle(Vector2(5, -16), 5.5, col)
	c.draw_rect(Rect2(9, -16, 5, 3), Color(1, 0.5, 0.1))
	if alive:
		c.draw_rect(Rect2(6, -18, 2, 2), Color.BLACK)
	else:
		c.draw_line(Vector2(5, -19), Vector2(8, -16), Color.BLACK, 1.0)
		c.draw_line(Vector2(8, -19), Vector2(5, -16), Color.BLACK, 1.0)
	c.draw_line(Vector2(-6, -8), Vector2(2, -6), col.darkened(0.3), 1.0)
	if kind == "gold":
		c.draw_rect(Rect2(-2, -22 + sin(t * 9.0), 2, 2), Color.WHITE)
		c.draw_rect(Rect2(10, -10 + cos(t * 7.0), 2, 2), Color.WHITE)


func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.25, 0.5, 0.9))
	if cover(c, "stage_booth", r, 0.2):
		for i in 2:
			c.draw_set_transform(Vector2(r.position.x + 30 + i * 140, r.end.y - 10) + draw_off, 0.0, Vector2(1.3, 1.3))
			_duck(c, "gold" if i == 1 else "duck", true)
			c.draw_set_transform(draw_off)
		draw_cabinet(c, r)
		return
	for i in 4:
		var x := fposmod(i * 60.0 + t * 30.0, r.size.x + 40) + r.position.x - 20
		c.draw_set_transform(Vector2(x, r.end.y - 30) + draw_off, 0.0, Vector2(1.4, 1.4))
		_duck(c, "gold" if i == 2 else "duck", true)
		c.draw_set_transform(draw_off)
	c.draw_rect(Rect2(r.position.x, r.end.y - 30, r.size.x, 30), Color(0.3, 0.58, 0.95))
	c.draw_arc(r.get_center() + Vector2(0, -15), 12, 0, TAU, 24, Color(0.9, 0.15, 0.15), 2.0)
