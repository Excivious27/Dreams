class_name StationFx
extends Node2D
## C14b P3 (c14b_04-09): a placed craft station shows it is working. Once a second
## (game time) it reads Crafting.jobs(key): while a job runs, furnaces/kilns/forges
## puff smoke, kitchens/cauldrons/soda steam, anvils/jewelers/robotics spark in short
## bursts every 2-3 s (fx/st_smoke, st_steam, st_sparks strips, random start); when a
## job is done a small ready marker bobs over it. Ambient fx hide under reduced
## motion (the ready marker stays). Child of the station sprite, at its top.

const SMOKE := ["furnace", "kiln", "anvil", "armory", "tannery", "garage", "print_shop", "sawmill"]
const STEAM := ["kitchen", "cauldron", "soda", "campfire", "press", "laundromat", "extractor", "mayo"]
const SPARKS := ["jeweler", "robotics", "terminal", "workbench", "gene_splicer", "shaper", "launchpad"]

var key := ""
var kind := ""
var _fx: AnimatedSprite2D
var _check := 0.0
var _busy := false
var _ready_job := false
var _spark_next := 0.0
var _drawn := false


static func kind_of(station: String) -> String:
	if station in SMOKE:
		return "st_smoke"
	if station in STEAM:
		return "st_steam"
	if station in SPARKS:
		return "st_sparks"
	return ""


## Attach to a station sprite whose picture is `top_h` art px tall (feet at origin).
static func attach(st: Node2D, station: String, top_h: float) -> StationFx:
	if st == null or not Crafting.is_station(station):
		return null
	var f := StationFx.new()
	f.name = "StationFx"
	f.key = station
	f.kind = kind_of(station)
	f.position = Vector2(0, -top_h * 0.85)
	f.scale = Vector2(1.0 / maxf(0.01, st.scale.x), 1.0 / maxf(0.01, st.scale.y))  # screen-px sized
	st.add_child(f)
	return f


func _ready() -> void:
	_check = AmbientMotion.phase(global_position)  # stations don't all check on the same frame
	if kind != "" and Art.has("fx", kind):
		_fx = AnimatedSprite2D.new()
		_fx.sprite_frames = Art.frames("fx", {"idle": kind}, {"idle": 7.0}, {"idle": kind != "st_sparks"})
		_fx.animation = "idle"
		_fx.scale = Vector2(0.35, 0.35)
		_fx.offset = Vector2(0, -float(Art.info("fx", kind).get("cell_h", 48)) / 2.0)
		_fx.visible = false
		_fx.modulate.a = 0.0
		add_child(_fx)
		_fx.frame = int(AmbientMotion.phase(global_position + Vector2(7, 3)) * 4.0) % 4
		_fx.speed_scale = 0.9 + 0.2 * AmbientMotion.phase(global_position)
		_fx.play("idle")
	_refresh()


func _refresh() -> void:
	var js := Crafting.jobs(key)
	var now := Crafting.now_abs()
	_busy = false
	_ready_job = false
	for j: Dictionary in js:
		if int(j.get("done_at", 0)) > now:
			_busy = true
		else:
			_ready_job = true


func _process(delta: float) -> void:
	_check += delta
	if _check >= 1.0:
		_check = 0.0
		_refresh()
	if _fx:
		var want := _busy and not AmbientMotion.reduced()
		if kind == "st_sparks" and want:
			var t := PlayClock.now()
			if t >= _spark_next:
				_spark_next = t + 2.0 + 1.0 * AmbientMotion.phase(Vector2(t, 1))
				_fx.frame = 0
				_fx.play("idle")
		var a := move_toward(_fx.modulate.a, 0.85 if want else 0.0, delta * 2.0)
		_fx.modulate.a = a
		_fx.visible = a > 0.01
	if _ready_job or _drawn:
		_drawn = _ready_job
		queue_redraw()


func _draw() -> void:
	if not _ready_job:
		return
	var y := -6.0 - absf(sin(PlayClock.now() * 3.0)) * 3.0
	draw_circle(Vector2(0, y), 5.0, Color(0.15, 0.1, 0.05, 0.6))
	draw_circle(Vector2(0, y), 4.0, Color(1.0, 0.86, 0.35))
	draw_rect(Rect2(-0.75, y - 2.5, 1.5, 3.0), Color(0.3, 0.2, 0.05))
	draw_rect(Rect2(-0.75, y + 1.2, 1.5, 1.3), Color(0.3, 0.2, 0.05))
