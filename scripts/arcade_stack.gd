class_name ArcadeStack
extends ArcadeGame
## Crystal Stack: falling gem blocks. ◀ ▶ move, A turns, ▼ drops faster,
## ▲ slams it down. Fill a row to clear it; every 8 rows the gems fall faster
## (a gentle curve: 0.8 s a row at level 1, about 0.4 s at 5, 0.17 s at 10,
## never quicker than 0.07 s). B pauses (ArcadePause). Holding ▼ only speeds up
## the piece it was pressed for; a new piece waits for ▼ to be pressed again.
## Topping out greys the well row by row before the results card.

const COLS := 10
const ROWS := 18
const CELL := 16.0
const ORIGIN := Vector2(12, 40)
const SHAPES := {
	"I": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"O": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"T": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)],
	"S": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -1)],
	"Z": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)],
	"J": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	"L": [Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
}
const COLORS := {
	"I": Color(0.35, 0.9, 1.0), "O": Color(1.0, 0.85, 0.3), "T": Color(0.75, 0.45, 1.0), "S": Color(0.4, 0.9, 0.45),
	"Z": Color(1.0, 0.4, 0.45), "J": Color(0.35, 0.5, 1.0), "L": Color(1.0, 0.6, 0.25),
}
const KICKS := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]

var board: Array = []      # ROWS x COLS of "" or a shape letter
var cur := ""
var cells: Array = []      # current piece offsets
var pos := Vector2i(4, 1)
var next_q: Array = []
var lines := 0
var lvl := 1
var fall_t := 0.0
var lock_t := 0.0
var lock_moves := 0
var das_t := 0.0
var das_dir := 0
var clearing: Array = []   # rows flashing
var clear_t := 0.0
var best_combo := 0
var tetras := 0
var down_lock := false     # ▼ still held from the last piece: no soft drop yet
var flash_cells: Array = []  # cells of the piece that just locked (white flash)
var flash_t := 0.0
var topout_t := 0.0        # top-out animation clock (state "topout")
const TOPOUT_SECS := 1.1


## The four-row clear's shout (the gangster arc's cabinet is Neon Stack).
static func _crush() -> String:
	return "CRYSTAL CRUSH!" if GameState.is_penguins() else "NEON CRUSH!"


func _init() -> void:
	super()
	game_id = "stack"
	title = Tickets.game_name("stack")  # Neon Stack in the gangster arc
	fee = 10
	accent = Color(0.78, 0.5, 1.0)
	howto = ["◀ ▶ move · TURN spins · ▼ faster · ▲ slam", "Fill a row with gems to clear it.", "4 rows at once: %s" % _crush(), "Faster every 8 rows. B pauses."]
	message_rect = Rect2(18, 150, 148, 22)  # banners across the middle of the well, clear of its floor and the side panel


func _deck_buttons() -> Array:
	return [
		{"action": "left", "rect": Rect2(8, 392, 40, 40), "label": "◀", "skin": "blue"},
		{"action": "right", "rect": Rect2(92, 392, 40, 40), "label": "▶", "skin": "blue"},
		{"action": "up", "rect": Rect2(50, 358, 40, 36), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(50, 430, 40, 36), "label": "▼", "skin": "blue"},
		{"action": "a", "rect": Rect2(196, 378, 64, 64), "label": "TURN", "skin": "gold"},
		{"action": "b", "rect": Rect2(150, 430, 40, 40), "label": "B", "skin": "red", "hint": "pause"},
	]


func _setup_round() -> void:
	board = []
	for r in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill("")
		board.append(row)
	next_q = []
	lines = 0
	lvl = 1
	clearing = []
	best_combo = 0
	tetras = 0
	flash_cells = []
	flash_t = 0.0
	topout_t = 0.0
	down_lock = false
	_spawn()


func _bag() -> void:
	var bag := SHAPES.keys()
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	next_q.append_array(bag)


func _spawn() -> void:
	while next_q.size() < 3:
		_bag()
	cur = str(next_q.pop_front())
	cells = (SHAPES[cur] as Array).duplicate()
	pos = Vector2i(4, 1)
	fall_t = 0.0
	lock_t = 0.0
	lock_moves = 0
	down_lock = held("down")
	if not _fits(cells, pos):
		_top_out()


func _fits(cs: Array, p: Vector2i) -> bool:
	for c: Vector2i in cs:
		var q := c + p
		if q.x < 0 or q.x >= COLS or q.y >= ROWS:
			return false
		if q.y >= 0 and str(board[q.y][q.x]) != "":
			return false
	return true


## Seconds per row at the current level.
static func gravity_for(level: int) -> float:
	return maxf(0.07, 0.8 * pow(0.84, level - 1))


func gravity() -> float:
	return gravity_for(lvl)


func _result_lines(head: String) -> Array:
	var out := [head, "Rows %d · Level %d" % [lines, lvl]]
	if tetras > 0:
		out.append("Crystal Crushes: %d" % tetras)
	return out


## The well is full: grey it out from the bottom up, then the results card.
func _top_out() -> void:
	cur = ""
	clearing = []
	topout_t = 0.0
	state = "topout"
	say("STACKED OUT!", TOPOUT_SECS)
	shake(4.0)
	sfx("cave_in", "thud")


func _step_state(st: String, dt: float) -> void:
	if st == "paused":
		if ArcadePause.step(self, dt):
			game_over(_result_lines("!GAME ENDED"))
	elif st == "topout":
		topout_t += dt
		flash_t = maxf(0.0, flash_t - dt)
		if topout_t >= TOPOUT_SECS:
			game_over(_result_lines("!STACKED OUT"))


func frame() -> void:
	super()
	ArcadePause.hint(self, _deck)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and not manual:
		ArcadePause.pause(self)


func _step(dt: float) -> void:
	flash_t = maxf(0.0, flash_t - dt)
	if pressed("b"):
		ArcadePause.pause(self)
		return
	if not clearing.is_empty():
		clear_t -= dt
		if clear_t <= 0.0:
			_remove_rows()
			_spawn()
		return
	if cur == "":
		return
	# Turn.
	if pressed("a") and cur != "O":
		var rotd: Array = []
		for c: Vector2i in cells:
			rotd.append(Vector2i(-c.y, c.x))
		for k: Vector2i in KICKS:
			if _fits(rotd, pos + k):
				cells = rotd
				pos += k
				sfx("tab", "ui_tap")
				_touch_lock()
				break
	# Move with auto-repeat.
	var dir := (1 if held("right") else 0) - (1 if held("left") else 0)
	if pressed("left") or pressed("right"):
		das_t = 0.16
		das_dir = dir
		_shift(dir)
	elif dir != 0 and dir == das_dir:
		das_t -= dt
		if das_t <= 0.0:
			das_t = 0.05
			_shift(dir)
	else:
		das_dir = dir
	# Slam.
	if pressed("up"):
		var d := 0
		while _fits(cells, pos + Vector2i(0, 1)):
			pos.y += 1
			d += 1
		score += d * 2
		shake(2.0)
		sfx("thud", "drop")
		_lock()
		return
	# Fall.
	if not held("down"):
		down_lock = false
	var soft := held("down") and not down_lock
	var g := gravity()
	if soft:
		g = minf(g, 0.04)
	fall_t += dt
	if fall_t >= g:
		fall_t = 0.0
		if _fits(cells, pos + Vector2i(0, 1)):
			pos.y += 1
			lock_t = 0.0
			if soft:
				score += 1
	if not _fits(cells, pos + Vector2i(0, 1)):
		lock_t += dt
		if lock_t >= 0.45:
			_lock()


func _shift(dir: int) -> void:
	if dir != 0 and _fits(cells, pos + Vector2i(dir, 0)):
		pos.x += dir
		sfx("scroll_tick", "ui_tap")
		_touch_lock()


func _touch_lock() -> void:
	if lock_moves < 12:
		lock_t = 0.0
		lock_moves += 1


func _lock() -> void:
	for c: Vector2i in cells:
		if (c + pos).y < 0:
			_top_out()
			return
	flash_cells = []
	for c: Vector2i in cells:
		var q := c + pos
		board[q.y][q.x] = cur
		flash_cells.append(q)
	flash_t = 0.12
	sfx("block", "thud")
	cur = ""
	clearing = []
	for r in ROWS:
		if not (board[r] as Array).has(""):
			clearing.append(r)
	if clearing.is_empty():
		_spawn()
		return
	clear_t = 0.28
	var n := clearing.size()
	score += [0, 100, 300, 500, 800][n] * lvl
	best_combo = maxi(best_combo, n)
	for r: int in clearing:
		for cx in COLS:
			var p := ORIGIN + Vector2(cx * CELL + 8, r * CELL + 8)
			burst(p, COLORS.get(str(board[r][cx]), Color.WHITE), 3, 80.0, 2.0, 220.0)
	if n == 4:
		tetras += 1
		ArcadeHub.set_milestone("stack_tetra")
		say(_crush())
		shake(5.0)
		sfx("j_treasure", "levelup")
		float_text(ORIGIN + Vector2(80, clearing[0] * CELL), "+%d" % (800 * lvl), Color(0.85, 0.7, 1.0))
	else:
		sfx("gem", "sparkle")
		float_text(ORIGIN + Vector2(80, clearing[0] * CELL), "+%d" % ([0, 100, 300, 500, 800][n] * lvl))


func _remove_rows() -> void:
	clearing.sort()
	for r: int in clearing:
		board.remove_at(r)
		var row: Array = []
		row.resize(COLS)
		row.fill("")
		board.insert(0, row)
	var before := lvl
	lines += clearing.size()
	lvl = 1 + lines / 8
	if lvl > before:
		say("LEVEL %d · FASTER!" % lvl)
		sfx("levelup", "power_up")
		burst(ORIGIN + Vector2(COLS * CELL * 0.5, ROWS * CELL * 0.5), accent, 18, 110.0, 2.0, 60.0)
	clearing = []


func _tickets_for(s: int) -> int:
	return s / 250 + lines / 2


func _good_tickets() -> int:
	return 12


func _draw_play(c: Control) -> void:
	c.draw_rect(PLAY, Color(0.07, 0.04, 0.12))
	var cave := ArcadeGame.tex("bg_cave")
	if cave:
		# The crystal cave, drifting slowly sideways behind the well.
		var sz := Vector2(cave.get_size())
		var f := PLAY.size.y / sz.y
		var sw := PLAY.size.x / f
		var sx := fposmod(t * 6.0, sz.x - sw)
		c.draw_texture_rect_region(cave, PLAY, Rect2(sx, 0, sw, sz.y), Color(0.85, 0.85, 0.95))
	# Cave backdrop: faint crystals.
	for i in 14:
		var p := Vector2(fposmod(i * 71.0, 270.0), 30.0 + fposmod(i * 113.0, 310.0))
		c.draw_colored_polygon(PackedVector2Array([p, p + Vector2(4, -10), p + Vector2(8, 0)]), Color(0.6, 0.4, 1.0, 0.08))
	var well := Rect2(ORIGIN, Vector2(COLS * CELL, ROWS * CELL))
	var rim := Color(0.35, 0.25, 0.5)
	var top_row := _top_filled()
	if top_row < 5 and state != "over":
		# The stack is near the top: the rim pulses red as a warning.
		rim = rim.lerp(Color(1.0, 0.25, 0.3), 0.45 + 0.35 * sin(t * 9.0))
	c.draw_rect(well.grow(3), rim)
	c.draw_rect(well.grow(1), Color(0.02, 0.01, 0.05))
	c.draw_rect(well, Color(0.05, 0.03, 0.1, 0.88))
	for x in range(1, COLS):
		c.draw_rect(Rect2(ORIGIN.x + x * CELL, ORIGIN.y, 1, well.size.y), Color(1, 1, 1, 0.03))
	for y in range(1, ROWS):
		c.draw_rect(Rect2(ORIGIN.x, ORIGIN.y + y * CELL, well.size.x, 1), Color(1, 1, 1, 0.03))
	if board.is_empty():
		return
	# Top-out: rows turn to grey stone from the bottom up.
	var grey_from := ROWS
	if state == "topout" or state == "over":
		grey_from = ROWS - int(ceil(clampf(topout_t / (TOPOUT_SECS * 0.8), 0.0, 1.0) * ROWS))
	for r in ROWS:
		var flash := clearing.has(r)
		for cx in COLS:
			var k := str(board[r][cx])
			if k == "":
				continue
			var col: Color = COLORS[k]
			if flash:
				col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 40.0))
			if r >= grey_from:
				col = Color(0.42, 0.4, 0.48).lerp(col, 0.15)
			_gem(c, ORIGIN + Vector2(cx * CELL, r * CELL), col)
	if flash_t > 0.0:
		for q: Vector2i in flash_cells:
			if q.y >= 0:
				c.draw_rect(Rect2(ORIGIN + Vector2(q.x * CELL, q.y * CELL), Vector2(CELL, CELL)), Color(1, 1, 1, flash_t / 0.12 * 0.6))
	if cur != "":
		# Ghost.
		var gp := pos
		while _fits(cells, gp + Vector2i(0, 1)):
			gp.y += 1
		for cc: Vector2i in cells:
			var q := cc + gp
			if q.y >= 0:
				var gr := Rect2(ORIGIN + Vector2(q.x * CELL + 1, q.y * CELL + 1), Vector2(CELL - 2, CELL - 2))
				c.draw_rect(gr, Color(COLORS[cur], 0.12))
				c.draw_rect(gr, Color(COLORS[cur], 0.55), false, 1.0)
		for cc: Vector2i in cells:
			var q2 := cc + pos
			if q2.y >= 0:
				_gem(c, ORIGIN + Vector2(q2.x * CELL, q2.y * CELL), COLORS[cur])
	# Side panel.
	var sp := Rect2(186, 40, 74, 288)
	panel(c, sp, Color(0.1, 0.06, 0.16, 0.9), accent.darkened(0.3))
	text(c, Vector2(sp.position.x, 54), "NEXT", sp.size.x, 8, accent, HORIZONTAL_ALIGNMENT_CENTER)
	for i in mini(2, next_q.size()):
		var k2 := str(next_q[i])
		var base := Vector2(sp.position.x + 30, 74 + i * 40)
		var sc := 10.0 if i == 0 else 8.0
		for cc: Vector2i in SHAPES[k2]:
			_gem(c, base + Vector2(cc.x * sc, cc.y * sc), COLORS[k2], sc)
	var rows := [["SCORE", str(score)], ["LEVEL", str(lvl)], ["ROWS", str(lines)], ["BEST", str(maxi(score, Tickets.best_score(game_id)))]]
	for i in rows.size():
		var y := 170 + i * 36
		text(c, Vector2(sp.position.x, y), rows[i][0], sp.size.x, 7, Color(0.75, 0.7, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		text_outline(c, Vector2(sp.position.x, y + 14), rows[i][1], sp.size.x, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if i == 1:
			# Progress to the next speed-up (8 rows a level).
			var bar := Rect2(sp.position.x + 10, y + 19, sp.size.x - 20, 4)
			c.draw_rect(bar, Color(0, 0, 0, 0.45))
			c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(lines % 8) / 8.0, bar.size.y)), accent)
	draw_fx(c)
	if state == "paused":
		ArcadePause.draw(self, c)


## Highest row holding a gem (ROWS when the well is empty).
func _top_filled() -> int:
	if board.size() < ROWS:
		return ROWS
	for r in ROWS:
		if _row_has_gem(r):
			return r
	return ROWS


func _row_has_gem(r: int) -> bool:
	for cx in COLS:
		if str(board[r][cx]) != "":
			return true
	return false


func _gem(c: Control, p: Vector2, col: Color, s := CELL) -> void:
	c.draw_rect(Rect2(p, Vector2(s, s)), col.darkened(0.45))
	c.draw_rect(Rect2(p + Vector2(1, 1), Vector2(s - 2, s - 2)), col)
	c.draw_rect(Rect2(p + Vector2(1, 1), Vector2(s - 2, 2)), col.lightened(0.4))
	c.draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, s - 2)), col.lightened(0.25))
	c.draw_rect(Rect2(p + Vector2(1, s - 3), Vector2(s - 2, 2)), col.darkened(0.25))
	if s >= 10:
		c.draw_rect(Rect2(p + Vector2(4, 4), Vector2(2, 2)), Color(1, 1, 1, 0.85))


func _draw_marquee(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.08, 0.04, 0.14))
	cover(c, "bg_cave", r, 0.5, Color(0.7, 0.7, 0.8))
	var ks := SHAPES.keys()
	for i in 22:
		var k := str(ks[i % ks.size()])
		var x := r.position.x + 6 + (i % 11) * 17
		var y := r.end.y - 20 - (i / 11) * 17 - (0 if i % 3 else 17)
		_gem(c, Vector2(x, y), COLORS[k])
	var fy := r.position.y + fposmod(t * 30.0, 50.0)
	for cc: Vector2i in SHAPES["T"]:
		_gem(c, Vector2(r.position.x + 30 + cc.x * 16, fy + 16 + cc.y * 16), COLORS["T"])
	draw_cabinet(c, r)
