class_name ArcadeHub
extends ArcadeGame
## The Recreation Center's arcade: one entry point for every cabinet.
##   ArcadeHub.open("jumper")  -> that game's screen (await .closed)
##   ArcadeHub.open("")        -> the cabinet picker
## Also the money helpers (crystals; "cash" in the gangster arc) and the
## progress milestones (prizes can need them via need.ms; quests via arcade_ms):
##   ArcadeHub.milestone("jumper_5") -> bool

const GAMES := [
	{"id": "jumper", "name": "Block Jumper", "blurb": "Run, jump, duck! 8 levels + endless", "col": Color(0.35, 0.8, 1.0)},
	{"id": "stack", "name": "Crystal Stack", "blurb": "Drop the gems, clear the rows", "gang_blurb": "Drop the neon blocks, clear the rows", "col": Color(0.75, 0.45, 1.0)},
	{"id": "whack", "name": "Whack-a-Grump", "blurb": "Bop the Grumps, spare the bunnies", "gang_blurb": "Bop the snitches, spare the bunnies", "col": Color(0.55, 0.85, 0.35)},
	{"id": "claw", "name": "Claw Machine", "blurb": "Grab a real prize", "col": Color(1.0, 0.5, 0.7)},
	{"id": "gallery", "name": "Duck Pond", "blurb": "Pop the toy ducks with corks", "gang_blurb": "Pop the tin targets with corks", "col": Color(1.0, 0.8, 0.3)},
]

## Milestones the prize counter can require (id -> what it means).
const MILESTONES := {
	"jumper_1": "Block Jumper: clear level 1",
	"jumper_2": "Block Jumper: clear level 2",
	"jumper_3": "Block Jumper: clear level 3",
	"jumper_4": "Block Jumper: clear level 4 (double jump)",
	"jumper_5": "Block Jumper: clear level 5",
	"jumper_6": "Block Jumper: clear level 6",
	"jumper_7": "Block Jumper: clear level 7",
	"jumper_8": "Block Jumper: clear every level",
	"jumper_coins": "Block Jumper: every coin in a level",
	"jumper_endless_300": "Block Jumper endless: 300 m",
	"jumper_endless_1000": "Block Jumper endless: 1000 m",
	"stack_3000": "Crystal Stack: 3,000 points",
	"stack_15000": "Crystal Stack: 15,000 points",
	"stack_tetra": "Crystal Stack: clear 4 rows at once",
	"whack_150": "Whack-a-Grump: 150 points",
	"whack_400": "Whack-a-Grump: 400 points",
	"claw_win": "Claw Machine: win a prize",
	"claw_5": "Claw Machine: win 5 prizes",
	"gallery_300": "Duck Pond: 300 points",
	"gallery_800": "Duck Pond: 800 points",
	"skee_300": "Skee-Ball: 300 in one game",
	"skee_cup": "Skee-Ball: sink a corner cup",
	"all_games": "Play every cabinet once",
}

## Score milestones: game id -> [[score, milestone]].
const SCORE_MS := {
	"stack": [[3000, "stack_3000"], [15000, "stack_15000"]],
	"whack": [[150, "whack_150"], [400, "whack_400"]],
	"gallery": [[300, "gallery_300"], [800, "gallery_800"]],
	"skee_ball": [[300, "skee_300"]],
}

var _sel := 0
var _child: ArcadeGame


## ArcadeHub.open(map, "jumper") (the Rec Center's cabinets) or ArcadeHub.open("jumper").
static func open(map_or_id: Variant, game_id := "") -> ArcadeGame:
	var parent: Node = null
	if map_or_id is Node:
		parent = map_or_id
	else:
		game_id = str(map_or_id)
	var g := make(game_id)
	if g == null:
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if parent == null:
		parent = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(g)
	return g


## The home Arcade Cabinet prize: the picker in free practice (no fee, no tickets).
static func open_home(map: Node) -> ArcadeGame:
	var g := open(map, "")
	if g:
		g.free_play = true
	return g


## A screen for a game id ("" = the picker), not yet in the tree.
static func make(game_id: String) -> ArcadeGame:
	match game_id:
		"":
			return ArcadeHub.new()
		"jumper":
			return BlockJumper.new()
		"stack":
			return ArcadeStack.new()
		"whack":
			return ArcadeWhack.new()
		"claw":
			return ArcadeClaw.new()
		"gallery":
			return ArcadeGallery.new()
		"skee_ball":
			return ArcadeSkee.new()  # the rec's skee lane (not a picker cabinet)
	push_warning("ArcadeHub: no game " + game_id)
	return null


## A cabinet's picker line in the current arc (C9 P3, c9_14: gangster blurbs).
static func blurb(g: Dictionary) -> String:
	if not GameState.is_penguins() and g.has("gang_blurb"):
		return str(g["gang_blurb"])
	return str(g.get("blurb", ""))


static func game_ids() -> Array:
	var out: Array = []
	for g: Dictionary in GAMES:
		out.append(str(g["id"]))
	return out


# --- money -------------------------------------------------------------------

static func money_word() -> String:
	return Money.word()


## A price as the player reads it: "10 crystals" / "$10" (the cabinets' own font
## draws the words, so no ◆ glyph here).
static func price(n: int) -> String:
	return Money.amount(n)


static func money() -> int:
	return int(GameState.run.get("crystals", 0))


static func charge(n: int) -> bool:
	if money() < n:
		return false
	GameState.run["crystals"] = money() - n
	return true


# --- progress ----------------------------------------------------------------

static func _data() -> Dictionary:
	# run["arcade"] belongs to Tickets; the cabinets keep their own block.
	if not (GameState.run.get("arcade_hub") is Dictionary):
		GameState.run["arcade_hub"] = {}
	var d: Dictionary = GameState.run["arcade_hub"]
	for k in ["ms", "played", "jumper"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}
	return d


static func milestone(id: String) -> bool:
	return bool(_data()["ms"].get(id, false))


## Records a milestone; true (and a toast) the first time.
static func set_milestone(id: String) -> bool:
	var ms: Dictionary = _data()["ms"]
	if bool(ms.get(id, false)):
		return false
	ms[id] = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree and Music.instance(tree):
		Music.instance(tree).sfx("j_secret", "sparkle")
	if tree and tree.current_scene is GameMap and (tree.current_scene as GameMap).hud:
		(tree.current_scene as GameMap).hud.toast("Arcade milestone: " + milestone_text(id), Color(1, 0.85, 0.4))
	return true


## A milestone's words in this save's arc: every cabinet name goes through
## Tickets.game_name, so the gangster arc reads Neon Stack / Whack-a-Snitch / Neon Range (C12 P7).
static func milestone_text(id: String) -> String:
	var t := str(MILESTONES.get(id, id))
	var base: Dictionary = Tickets.prizes().get("game_names", {})
	for g in base:
		var nm := str(base[g])
		if t.contains(nm):
			t = t.replace(nm, Tickets.game_name(str(g)))
	return t


static func mark_played(game_id: String) -> void:
	if game_id == "":
		return
	var p: Dictionary = _data()["played"]
	p[game_id] = int(p.get(game_id, 0)) + 1
	for g in game_ids():
		if not p.has(g):
			return
	set_milestone("all_games")


static func times_played(game_id: String) -> int:
	return int(_data()["played"].get(game_id, 0))


## Score-based milestones after a round (games with their own add them too).
static func check_milestones(game_id: String, sc: int, _g: ArcadeGame) -> void:
	for pair: Array in SCORE_MS.get(game_id, []):
		if sc >= int(pair[0]):
			set_milestone(str(pair[1]))


# --- the cabinet picker ------------------------------------------------------

func _init() -> void:
	super()
	game_id = ""
	title = "Arcade"
	fee = 0
	accent = Color(1.0, 0.55, 0.85)
	state = "pick"


func _deck_buttons() -> Array:
	return [
		{"action": "up", "rect": Rect2(30, 362, 44, 40), "label": "▲", "skin": "blue"},
		{"action": "down", "rect": Rect2(30, 418, 44, 40), "label": "▼", "skin": "blue"},
		{"action": "a", "rect": Rect2(196, 378, 64, 64), "label": "PLAY", "skin": "gold"},
		{"action": "b", "rect": Rect2(150, 430, 40, 40), "label": "B", "skin": "red", "hint": "leave"},
	]


func _top_right() -> String:
	return Money.amount(money())


func _card(i: int) -> Rect2:
	return Rect2(10, 52 + i * 58, 250, 52)


func _step_state(s: String, _dt: float) -> void:
	if s != "pick" or _child != null:
		return
	if repeat_pressed("up"):
		_sel = posmod(_sel - 1, GAMES.size())
		sfx("scroll_tick", "ui_tap")
	elif repeat_pressed("down"):
		_sel = posmod(_sel + 1, GAMES.size())
		sfx("scroll_tick", "ui_tap")
	elif pressed("a"):
		launch(_sel)
	elif pressed("b"):
		close()


func _tap(p: Vector2) -> void:
	if state != "pick" or _child != null:
		return
	for i in GAMES.size():
		if _card(i).has_point(p):
			if _sel == i:
				launch(i)
			else:
				_sel = i
				sfx("scroll_tick", "ui_tap")


func launch(i: int) -> ArcadeGame:
	_sel = i
	sfx("j_confirm", "ui_tap")
	_child = make(str(GAMES[i]["id"]))
	_child.manual = manual
	_child.free_play = free_play
	visible = false
	get_parent().add_child(_child)
	_child.closed.connect(_child_closed)
	return _child


func _child_closed() -> void:
	_child = null
	visible = true
	_arm = 0  # the B that closed the game must not close the arcade too


func _process(delta: float) -> void:
	if _child != null:
		return
	super(delta)


func _draw_play(c: Control) -> void:
	c.draw_rect(PLAY, Color(0.08, 0.04, 0.12))
	# Carpet: the classic arcade confetti pattern.
	for i in 60:
		var x := fmod(i * 47.0, 270.0)
		var y := 24.0 + fmod(i * 83.0, 328.0)
		var col := [Color(0.9, 0.3, 0.6, 0.18), Color(0.3, 0.7, 1, 0.18), Color(1, 0.85, 0.3, 0.18)][i % 3] as Color
		c.draw_rect(Rect2(x, y, 3, 3), col)
	text_outline(c, Vector2(0, 42), "Pick a cabinet", W, 10, Color(1, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER)
	for i in GAMES.size():
		var g: Dictionary = GAMES[i]
		var r := _card(i)
		var on := i == _sel
		var col: Color = g["col"]
		panel(c, r, col.darkened(0.7) if not on else col.darkened(0.45), col if on else col.darkened(0.3))
		if on:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			c.draw_rect(r.grow(2), Color(col, 0.4 + 0.4 * pulse), false, 1.0)
		var ic := Rect2(r.position + Vector2(6, 6), Vector2(40, 40))
		c.draw_rect(ic, Color(0.04, 0.02, 0.07))
		draw_icon(c, str(g["id"]), ic, t)
		text_outline(c, r.position + Vector2(54, 17), Tickets.game_name(str(g["id"])), 190, 10, Color.WHITE)
		text(c, r.position + Vector2(54, 30), blurb(g), 190, 7, Color(0.9, 0.88, 1))
		var cabinet := make_info(str(g["id"]))
		text(c, r.position + Vector2(54, 44), "%s · best %d" % [("free play" if free_play else Money.amount(int(cabinet["fee"]))), (Tickets.best_score(str(g["id"])) if str(g["id"]) != "jumper" else BlockJumper.best(0))], 190, 7, Color(1, 0.85, 0.5))


## Fee per game (kept here so the picker needn't build every screen).
static func make_info(id: String) -> Dictionary:
	match id:
		"claw":
			return {"fee": ArcadeClaw.FEE}
		"jumper":
			return {"fee": BlockJumper.FEE}
		"skee_ball":
			return {"fee": ArcadeSkee.FEE}
	return {"fee": 10}


## Little attract-mode icons for the picker (and a1's cabinets if wanted).
static func draw_icon(c: CanvasItem, id: String, r: Rect2, tt: float) -> void:
	var cab := ArcadeGame.tex("cabinet_" + id)
	if cab:
		var sz := Vector2(cab.get_size())
		var h := r.size.y + 2.0
		var w := sz.x * h / sz.y
		c.draw_texture_rect(cab, Rect2(r.position.x + (r.size.x - w) * 0.5, r.position.y - 1.0, w, h), false)
		return
	var o := r.position
	match id:
		"jumper":
			c.draw_rect(Rect2(o + Vector2(0, 30), Vector2(14, 10)), Color(0.35, 0.75, 0.3))
			c.draw_rect(Rect2(o + Vector2(26, 30), Vector2(14, 10)), Color(0.35, 0.75, 0.3))
			var jy := 30.0 - absf(sin(tt * 3.0)) * 18.0
			c.draw_rect(Rect2(o + Vector2(15, jy - 9), Vector2(9, 9)), Color(0.35, 0.8, 1.0))
			c.draw_rect(Rect2(o + Vector2(20, jy - 7), Vector2(2, 2)), Color.BLACK)
		"stack":
			var cols := [Color(0.9, 0.3, 0.4), Color(0.3, 0.8, 0.9), Color(0.95, 0.8, 0.3), Color(0.7, 0.4, 1)]
			for i in 8:
				c.draw_rect(Rect2(o + Vector2(4 + (i % 4) * 8, 32 - (i / 4) * 8), Vector2(7, 7)), cols[i % 4])
			var fy := fmod(tt * 14.0, 20.0)
			c.draw_rect(Rect2(o + Vector2(12, fy), Vector2(7, 7)), cols[3])
			c.draw_rect(Rect2(o + Vector2(20, fy), Vector2(7, 7)), cols[3])
		"whack":
			c.draw_rect(Rect2(o + Vector2(4, 28), Vector2(32, 8)), Color(0.25, 0.15, 0.1))
			var up := absf(sin(tt * 4.0)) * 12.0
			c.draw_circle(o + Vector2(20, 30 - up), 8, Color(0.6, 0.45, 0.85))
			c.draw_rect(Rect2(o + Vector2(15, 27 - up), Vector2(3, 2)), Color.BLACK)
			c.draw_rect(Rect2(o + Vector2(22, 27 - up), Vector2(3, 2)), Color.BLACK)
		"claw":
			var cx := 20.0 + sin(tt * 1.5) * 10.0
			c.draw_line(o + Vector2(cx, 0), o + Vector2(cx, 14), Color(0.8, 0.8, 0.85), 1.0)
			c.draw_line(o + Vector2(cx, 14), o + Vector2(cx - 5, 20), Color(0.8, 0.8, 0.85), 1.5)
			c.draw_line(o + Vector2(cx, 14), o + Vector2(cx + 5, 20), Color(0.8, 0.8, 0.85), 1.5)
			c.draw_circle(o + Vector2(10, 33), 6, Color(1, 0.6, 0.75))
			c.draw_circle(o + Vector2(28, 34), 6, Color(0.55, 0.8, 1))
		"gallery":
			c.draw_rect(Rect2(o + Vector2(0, 30), Vector2(40, 10)), Color(0.25, 0.5, 0.9))
			var dx := fmod(tt * 16.0, 48.0) - 6.0
			if dx < 38.0:
				c.draw_circle(o + Vector2(dx, 26), 5, Color(1, 0.85, 0.2))
				c.draw_circle(o + Vector2(dx + 4, 21), 3, Color(1, 0.85, 0.2))
				c.draw_rect(Rect2(o + Vector2(dx + 7, 21), Vector2(3, 1)), Color(1, 0.5, 0.1))
			c.draw_arc(o + Vector2(20, 18), 7, 0, TAU, 16, Color(1, 0.3, 0.3), 1.0)
