class_name GameMap
extends Node2D
## Base for every playable area. Owns the grid (size, blocked cells, things you
## can interact with), the player, the pet, camera, HUD, touch controls, sky, the
## clock, tap-to-move, and scene transitions. Subclasses draw the ground and
## place props. Children are y-sorted so the player walks behind tall things.

const TILE := 16
static var next_spawn := Vector2.ZERO
static var next_facing := "down"
static var next_interior := ""

var cols := 20
var rows := 30
var music_track := "farm"
var has_sky := true
var has_pet := true
var blocked := {}        # Vector2i -> true
var things := {}         # Vector2i -> Dictionary {type, ...}
var player: Player
var pet: Node2D
var companion: Companion = null
var hud: Hud
var enemies: Array = []
var sky: Scenery
var glow: NightGlow
var _canopies: Array = []      # tall sprites that fade when you walk behind them
var _faded: Array = []
var _fade_t := 0.0
const GLOW_WORDS := ["lamp", "lantern", "torch", "fire_barrel", "campfire", "beacon_on", "brazier", "crystal_lit", "streetlight", "neon"]
var props := {}          # Vector2i -> Sprite2D (so things can change their look)
## Organic border: `pad` cells of forest/cliff/water around the content, drawn by
## draw_border(). Content coordinates stay 0..cols-1; world = (cell + pad) * TILE.
var pad := 0
## "trees" | "cliff" | "water" | "none", or a Dictionary per side {"n","s","e","w"}.
var border: Variant = "trees"
var _border_cells := {}  # Vector2i -> "tree" | "bigtree" | "rock" | "water" | "cliff"
var _border_draw: Array = []  # [[Vector2i cell, String group, String name], ...] sorted by y
var _border_rng := RandomNumberGenerator.new()
var _border_open := {}
## Content water drawn in ONE mask with the border water (beach sea, lake outlet),
## so no bank line runs across open water where they meet.
var border_water_extra := {}
var border_water_shore := ""
## Footstep word per cell for soft ground patches (paths, sand, groves); player._ground_word reads it.
var ground_word := {}
var step_word := {}  # cell -> footstep word of tile paths (Footsteps.mark); soft patches use ground_word
var ground_seam := {}  # cell -> seam of the soft patch drawn there (exit corridors join the path's own body)
var _ext := Rect2i()          # area added by extend()
var _ext_paths := {}          # dirt connecting moved exits
var hitstop := 0.0
var _mana_acc := 0.0  # real seconds toward the next mana point
var _sign_labels := {}
## False in places where trees and rocks are scenery (the town): they can't be chopped or broken.
var resources_here := true
## Maps where water is swimmable (lake, beach, riverlands...). Border water never is.
var swim_ok := true
var _anim_layer: AnimLayer
var _pet_anim: AnimatedSprite2D
var _night: CanvasModulate
var _changing := false
var _time_acc := 0.0
var _pet_idle := 0.0
var _pet_busy := false
var _deco_rng := RandomNumberGenerator.new()


func _ready() -> void:
	if _painter_of != null:
		# The baked-ground painter (see _bake_setup): a drawing-only twin, no game.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	GameState.look_season = ""
	CliffPainter.memo.clear()  # recorded cliff/forest-floor drawing belongs to one map
	Art.trim_cache()
	InputSetup.ensure_actions()
	y_sort_enabled = true
	# Art is 2x detail drawn at half size; linear sampling keeps thin lines intact.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_anim_layer = AnimLayer.new()
	_anim_layer.position = offset()
	_anim_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_anim_layer)
	if not GameState.has_run():
		GameState.new_run("penguins", "dad", "Hero", "Dreamhollow", "Pup")
	GameState.run["scene"] = scene_id()
	build()
	# build() is where subclasses set pad; the animated layer must follow it.
	_anim_layer.position = offset()
	# Outer ring is always solid; with a pad the organic border fills the rest.
	for x in range(-pad, cols + pad):
		blocked[Vector2i(x, -pad)] = true
		blocked[Vector2i(x, rows + pad - 1)] = true
	for y in range(-pad, rows + pad):
		blocked[Vector2i(-pad, y)] = true
		blocked[Vector2i(cols + pad - 1, y)] = true
	if pad > 0:
		_build_border()
	for e in exits:
		var r: Rect2i = e["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				blocked.erase(Vector2i(x, y))
				hard.erase(Vector2i(x, y))
		_exit_zone(e)  # the whole road mouth, out through the border band
	if has_sky:
		sky = Scenery.new()
		sky.weather = GameState.weather_today()  # (gangster day 1 is real rain in weather_for)
		add_child(sky)
	_night = CanvasModulate.new()
	add_child(_night)
	_night.color = sky_tint(int(GameState.run["time"]))
	glow = NightGlow.new()
	glow.map = self
	add_child(glow)

	player = Player.new()
	player.map = self
	player.position = (next_spawn + offset()) if next_spawn != Vector2.ZERO else default_spawn()
	player.facing = next_facing
	next_spawn = Vector2.ZERO
	add_child(player)
	player.set_character(GameState.sprite_for_playable(str(GameState.run["playable"])))

	if has_pet and not Pet.resting():
		var pt := Pet.new()
		pt.map = self
		pet = pt
		var pet_kind := str(GameState.look_d().get("pet", ""))
		if pet_kind != "" and Art.has("animals/" + pet_kind, "idle"):
			# Prompts-09 pets (corgi, shepherd, hound, white dog, cats); "" = Tom's original pup.
			_pet_anim = AnimatedSprite2D.new()
			var anims := {"idle": "idle", "walk": "walk", "run": "run", "sit": "sit", "sleep": "sleep", "bark": "bark", "play": "play"}
			for extra in ([] if pet_kind == "dog_hound" else ["bite", "hurt", "limp", "guard", "howl", "dig", "fetch", "beg"]):  # the hound's fight strips are another dog (red collar)
				if Art.has("animals/" + pet_kind, extra):
					anims[extra] = extra
			_pet_anim.sprite_frames = Art.frames("animals/" + pet_kind, anims, {"idle": 2.0, "walk": 8.0, "run": 12.0, "sit": 1.0, "sleep": 1.0, "bark": 4.0, "play": 4.0, "bite": 10.0, "hurt": 6.0, "limp": 5.0, "guard": 2.0, "howl": 4.0, "dig": 8.0, "fetch": 8.0, "beg": 2.0}, {"bite": false, "hurt": false, "howl": false, "bark": false, "play": false, "dig": false})
			# Same size on screen as the classic pup, whatever the breed's art size.
			var ih := float(Art.info("animals/" + pet_kind, "idle").get("cell_h", 60))
			var ps := clampf(17.0 / maxf(20.0, ih), 0.12, 0.5)
			_pet_anim.scale = Vector2(ps, ps)
			_pet_anim.animation = "idle"
			var pa := _pet_anim
			var fit := func() -> void:
				var tex := pa.sprite_frames.get_frame_texture(pa.animation, pa.frame)
				if tex:
					pa.offset = Vector2(0, -tex.get_height() / 2.0)
			_pet_anim.frame_changed.connect(fit)
			_pet_anim.animation_changed.connect(fit)  # frame 0 -> frame 0 swaps too
		else:
			_pet_anim = CharacterLibrary.make_sprite("dog")
		pt.anim = _pet_anim
		pet.add_child(_pet_anim)
		# Where the pup is: waiting/guarding on some map, or at your heel.
		var w: Array = Pet.state().get("wait", [])
		if w.size() >= 3 and str(w[0]) == scene_id():
			pet.position = Vector2(float(w[1]), float(w[2]))
		elif w.size() >= 3:
			pet.visible = false  # it's on another map; Recall brings it
		else:
			pet.position = player.position + Vector2(-14, 4)
		_pet_anim.play("idle")
		add_child(pet)

	# Active companion walks with you (not in interiors/house/moon by default).
	var cid := Companion.active_id()
	if cid != "" and Companion.defs().has(cid) and scene_id() not in ["house", "interior", "moon"]:
		var comp := Companion.new()
		comp.setup(cid, self)
		comp.position = player.position + Vector2(14, 6)
		add_child(comp)
		companion = comp

	if Net.online():
		Net.peers_changed.connect(_sync_puppets)
		_sync_puppets()
		Net._send({"t": "scene", "scene": scene_id()})
	elif Net.i() != null:
		# Still connecting when the scene loaded: hook up once we're online.
		Net.connected.connect(func(_h: bool) -> void:
			if not Net.peers_changed.is_connected(_sync_puppets):
				Net.peers_changed.connect(_sync_puppets)
			_sync_puppets()
			Net._send({"t": "scene", "scene": scene_id()}))

	var cam := Camera2D.new()
	fit_camera(cam)
	# A desktop window resized (or fullscreen toggled): refit to the new view width.
	if DisplayMode.svc():
		DisplayMode.svc().changed.connect(func() -> void: if is_instance_valid(cam): fit_camera(cam))
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	cam.make_current()

	hud = Hud.new()
	add_child(hud)
	add_child(TouchControls.new())
	add_child(GameMenu.new())
	Music.instance(get_tree()).play(area_track())
	Ambience.instance(get_tree()).scene_changed()
	queue_redraw()
	_fade_in_when_baked()
	after_ready()
	_lock_untouched_buildings()
	Story.restore_spawns(self)
	Racket.on_enter(self)
	Marked.on_enter(self)
	MegaTravel.on_enter(self)
	MegaRegion.on_enter.call_deferred(self)  # mega region unlocks, name banner, map tab
	_fill_extension()
	_place_signposts()
	_place_waiting_horse()
	unstick_player()
	# Where you arrived here on foot (after unsticking): the balloon can bring you back.
	# Never a battlefield or the Hollow Heart: landing there would start a fight unasked.
	if has_sky and scene_id() not in ["house", "interior", "mine", "moon", "station", "sky", "title", "test_map", "hollow_heart"] and not scene_id().begins_with("bf_"):
		var vis: Dictionary = GameState.run.get("visited", {})
		if not vis.has(scene_id()):
			if not vis.is_empty():
				Music.instance(get_tree()).sfx("j_region", "levelup")
			var at := player.position - offset()
			vis[scene_id()] = [at.x, at.y]
			GameState.run["visited"] = vis
	_check_quests.call_deferred()


## Your horse waits where you dismounted (flags.horse_at = [scene, x, y]);
## drawn from animals/horse_<coat>, A to ride again.
func _place_waiting_horse() -> void:
	var at: Array = GameState.run["flags"].get("horse_at", [])
	if at.size() < 3 or str(at[0]) != scene_id() or GameState.run["flags"].has("mounted"):
		return
	var coat := str(GameState.run.get("names", {}).get("horse_coat", "bay"))
	var c := Vector2i(int(at[1]), int(at[2]))
	if Art.has("animals/horse_" + coat, "idle"):
		var a := anim_prop("animals/horse_" + coat, "idle", c, 0, 2.0)
		if a:
			a.flip_h = c.x % 2 == 0
	elif Art.has("animals/horse3", "idle"):
		anim_prop("animals/horse3", "idle", c, 0, 2.0)
	set_thing(c.x, c.y, {"type": "horse", "hint": "A: ride %s" % str(GameState.run.get("names", {}).get("horse", "your horse"))}, false)


## Save when the phone/browser backgrounds the game or the tab closes.
func _notification(what: int) -> void:
	if _painter_of != null:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if not GameState.run.is_empty() and not _changing:
			save_here()


## Save with the player's current spot, so reopening the app resumes right here
## (not at the last door). Battles and interiors keep their own entry points.
func save_here() -> void:
	GameState.run["scene"] = scene_id()
	var sid := scene_id()
	if player and is_instance_valid(player) and not sid.begins_with("bf_") and sid != "interior":
		var p := player.position - offset()
		GameState.run["spawn"] = [p.x, p.y, player.facing]
	GameState.save()


## Subclasses override these.
func scene_id() -> String:
	return "farm"
func build() -> void:
	pass
func after_ready() -> void:
	pass
func default_spawn() -> Vector2:
	return Vector2(cols * TILE / 2.0, rows * TILE / 2.0) + offset()
func interact(_cell: Vector2i, _thing: Dictionary) -> bool:
	return false
## One short verb for what USE / CHECK would do on this cell (shown on the button).
const ACTION_WORDS := {"tree": "Chop", "stump": "Chop", "log": "Chop", "rock": "Mine", "ore": "Mine", "bush": "Pick", "forage": "Pick", "chest": "Open", "door": "Enter", "sign": "Read", "board": "Read", "bed": "Sleep", "shop": "Shop", "station": "Craft", "fish": "Fish", "water": "Fish", "grass": "Cut", "weeds": "Cut", "plot": "Farm", "animal": "Pet", "project": "Build", "cpoint": "Build", "ferry": "Sail", "mega_gate": "Travel", "elder": "Talk", "beacon": "Light", "secret_chest": "Open", "page": "Read", "boss": "Face"}


func action_word(c: Vector2i) -> String:
	if player == null:
		return ""
	if has_npc_at(c):
		return "Talk"
	if nearest_enemy_to(player.position, 22.0) != null:
		return "Fight"
	if descent_near(player.cell()) != Vector2i(-1, -1):
		return "Down"
	if _exit_at(c):
		return "Go"
	var thing: Dictionary = things.get(c, {})
	if thing.is_empty() or hint_for(c, thing) == "":
		return ""
	var t := str(thing.get("type", ""))
	if ACTION_WORDS.has(t):
		return str(ACTION_WORDS[t])
	for k: String in ACTION_WORDS:
		if t.begins_with(k) or t.ends_with(k):
			return str(ACTION_WORDS[k])
	return "Use"


func hint_for(_cell: Vector2i, thing: Dictionary) -> String:
	if not resources_here and str(thing.get("type", "")) in ["tree", "rock", "log", "stump", "bush"] and not bool(thing.get("harvest", false)):
		return ""
	return str(thing.get("hint", ""))


# ---- grid helpers ------------------------------------------------------------

func block_rect(x: int, y: int, w: int, h: int) -> void:
	for i in w:
		for j in h:
			blocked[Vector2i(x + i, y + j)] = true
			hard[Vector2i(x + i, y + j)] = true
	_flows.clear()


## Cells blocked by a structure (prop, building, hut on stilts): even a swimmer
## can't pass under these.
var hard := {}


func set_thing(x: int, y: int, thing: Dictionary, solid := true) -> void:
	things[Vector2i(x, y)] = thing
	if solid:
		blocked[Vector2i(x, y)] = true
		_flows.clear()


func rect_blocked(r: Rect2) -> bool:
	var x0 := floori(r.position.x / TILE) - pad
	var y0 := floori(r.position.y / TILE) - pad
	var x1 := floori((r.end.x - 0.01) / TILE) - pad
	var y1 := floori((r.end.y - 0.01) / TILE) - pad
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if blocked.has(Vector2i(x, y)):
				return true
	return false


## Water you can swim in: "water"/"sea" things. Deep water (no land within
## 3 cells) needs the Swimmer perk (fishing tree).
func is_water_cell(c: Vector2i) -> bool:
	return str(things.get(c, {}).get("type", "")) in ["water", "sea"]


func can_swim_cell(c: Vector2i) -> bool:
	if not is_water_cell(c) or player == null or player.mounted:
		return false
	if float(player.vehicle_def().get("water", 0.0)) > 0.0:
		return true  # a boat goes where a swimmer can't
	if Colony.has_ability("tideswim"):
		return true
	if not swim_ok:
		return false
	if GameState.has_perk("fishing", "Swimmer") or Companion.has_ability("tail"):
		return true
	# Bog and marsh mud: thick, sucking, not for wading. Only a swimmer or a boat.
	if str(things.get(c, {}).get("shore", "")) == "bog":
		return false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var n := c + Vector2i(dx, dy)
			if not is_water_cell(n) and not blocked.has(n):
				return true
	return false


## Like rect_blocked, but swimmable water counts as open for the player.
func rect_blocked_player(r: Rect2, _p: Node) -> bool:
	var x0 := floori(r.position.x / TILE) - pad
	var y0 := floori(r.position.y / TILE) - pad
	var x1 := floori((r.end.x - 0.01) / TILE) - pad
	var y1 := floori((r.end.y - 0.01) / TILE) - pad
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var c := Vector2i(x, y)
			if blocked.has(c) and (hard.has(c) or not can_swim_cell(c)):
				return true
	return false


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + pad) * TILE + TILE / 2.0, (c.y + pad) * TILE + TILE)


## World position of a content coordinate (cells, may be fractional).
func cell_pos(x: float, y: float) -> Vector2:
	return Vector2((x + pad) * TILE, (y + pad) * TILE)


func offset() -> Vector2:
	return Vector2(pad, pad) * TILE


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE) - pad, floori(p.y / TILE) - pad)


func in_content(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


## A villager on (or right by) this cell: talking wins over the pup at your feet.
func _npc_near(c: Vector2i) -> bool:
	# Every villager child counts, not only a map's `npcs` list (Catkins, crew on farm/meadow...).
	var list: Array = get_children()
	var extra = get("npcs")
	if extra is Array:
		list.append_array(extra)
	for n in list:
		if n is Npc and is_instance_valid(n) and (n as Node2D).visible and (n as Node2D).position.distance_to(cell_center(c)) < 14.0:
			return true
	return false


func _pup_at(c: Vector2i) -> bool:
	return pet != null and is_instance_valid(pet) and pet.visible and pet is Pet and (pet.position.distance_to(cell_center(c)) < 13.0 or (player and pet.position.distance_to(player.position) < 16.0 and world_to_cell(pet.position) == c))


## May the pup's menu open now? Never mid-fight: not with a foe within ~5
## tiles, and not while a sword or tool swing is still playing.
func pup_menu_allowed() -> bool:
	if player == null:
		return false
	if player._busy or player._attack_cd > 0.0 or player.anim_name.begins_with("attack"):
		return false
	for e in enemies:
		if is_instance_valid(e) and e._alive and e.position.distance_to(player.position) < 5.0 * TILE:
			return false
	return true


## `check`: the CHECK button (the hand) / right click. Only a check opens the
## pup's menu; USE on the pup falls through to whatever else is there.
func try_interact(c: Vector2i, check := false) -> bool:
	if check and _pup_at(c) and not _npc_near(c) and pup_menu_allowed():
		later(_pup_menu)
		return true
	var thing: Dictionary = things.get(c, {})
	if interact(c, thing):
		return true
	if thing.is_empty() and scene_id() != "farm" and use_consumable(str(GameState.run["selected"])):
		return true
	if interact_common(c, thing):
		return true
	if thing.is_empty() and _building_doors.has(c) and _building_doors[c] != c and blocked.has(c):
		var door: Vector2i = _building_doors[c]
		# Anywhere along the front wall counts as knocking on the door (painted
		# doors aren't always dead centre).
		if player and player.cell().y >= door.y - 1 and things.has(door):
			return interact(door, things[door]) or interact_common(door, things[door])
		hud.toast("The way in is round the front (%s)." % ("below you" if player and player.cell().y < door.y else "this side"), Color(0.95, 0.9, 0.8))
		return true
	return false


## Interactions every outdoor map shares (trees, rocks, logs, stumps, bushes).
func interact_common(c: Vector2i, thing: Dictionary) -> bool:
	var t := str(thing.get("type", ""))
	if t == "project":
		later(Project.open.bind(self))
		return true
	if t == "ferry":
		later(Colony.ferry.bind(self))
		return true
	if t == "mega_gate":
		later(MegaTravel.gate.bind(self, thing))
		return true
	if t in ["elder", "beacon", "star_crystal", "colony_shop"]:
		return Colony.interact(self, scene_id(), thing)
	if not resources_here and t in ["tree", "rock", "log", "stump", "bush"] and not bool(thing.get("harvest", false)):
		hud.toast("That's part of the town.", Color(0.9, 0.9, 0.9))
		return true
	match t:
		"grove":
			# The forest's old wood (the dense border stands): never chopped.
			if GameState.held_tool() == "axe":
				hud.toast("The old wood is too thick to chop. Try a lone tree.", Color(0.9, 0.9, 0.9))
				return true
			return false
		"stone":
			# Standing stones (crystal meadow): the pickaxe only rings off them.
			if GameState.held_tool() == "pickaxe":
				hud.toast("The standing stone won't chip. Old magic, or just very hard rock.", Color(0.9, 0.9, 0.9))
				return true
			return false
		"fruit":
			if not bool(thing.get("ripe", false)):
				hud.toast("Nothing on it today." if GameState.season() != "winter" else "Bare till spring.", Color(0.9, 0.9, 0.9))
				return true
			thing["ripe"] = false
			thing["hint"] = ""
			GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
			var kind := str(thing.get("kind", ""))
			if Art.has("nature", "ftree_%s_shake" % kind) and props.has(c):
				var old: Node = props[c]
				var sh := anim_prop("nature", "ftree_%s_shake" % kind, c, 0, 8.0)
				if sh:
					sh.sprite_frames.set_animation_loop("idle", false)
					old.visible = false
					sh.animation_finished.connect(func() -> void:
						sh.queue_free()
						if is_instance_valid(old):
							old.visible = true
							var after := "ftree_%s_green" % kind if Art.has("nature", "ftree_%s_green" % kind) else "ftree_%s_late" % kind
							if old is Sprite2D and Art.has("nature", after):
								(old as Sprite2D).texture = Art.tex("nature", after))
			else:
				wobble(c, 0.08)
			var n := 1 + (1 if randf() < GameState.bonus("foraging", "forage_bonus") * 0.06 else 0)
			pop_items(cell_center(c), str(thing["item"]), n)
			xp("foraging", 4)
			player.play_tool("hold")
			return true
		"horse":
			if not player.has_anim("ride"):
				player.mount()  # explains why, leaves the horse where it is
				return true
			things.erase(c)
			if props.has(c):
				(props[c] as Node).queue_free()
				props.erase(c)
			for ch in get_children():
				if ch is AnimatedSprite2D and (ch as AnimatedSprite2D).position.distance_to(cell_center(c)) < 10.0:
					ch.queue_free()
			GameState.run["flags"].erase("horse_at")
			player.mount()
			return true
		"sign":
			tell([{"text": str(thing.get("text", "A signpost."))}])
			return true
		"pet_animal":
			var a: Variant = thing.get("animal", null)
			if a != null and is_instance_valid(a) and Net.visiting():
				# The host's animals: a guest's visit never touches their own animals, silo or goods.
				emote(a, "heart", 1.4, -18.0)
				hud.toast("The host's animals. They're happy to see you.", Color(1, 0.8, 0.9))
				return true
			if a != null and is_instance_valid(a):
				var nm := str(a.name)
				var all: Dictionary = GameState.run.get("animals", {})
				var st: Dictionary = all.get(nm, {"streak": 0, "last_pet": -9, "fed": -9})
				var day := int(GameState.run["day"])
				var species := str(a.kind).split("_")[0].rstrip("0123456789").capitalize()
				var fed_now := false
				# Big Barn auto-feeder: barn animals eat from the silo by themselves.
				var bird := str(a.kind).begins_with("chicken") or str(a.kind).begins_with("hen") or str(a.kind).begins_with("duck") or str(a.kind) in ["rooster", "chick"]
				if int(st["fed"]) != day and not bird and not bool(a.get("baby")) and Builds.built_tier("barn") >= 2 and Builds.silo_hay() > 0:
					GameState.run["silo"] = Builds.silo_hay() - 1
					st["fed"] = day
				# Holding hay: feed it (once a day), then the same tap pets it.
				var no_hay := bool(a.get("baby")) or str(a.kind) == "rooster"  # babies and the rooster give nothing: no hay, no nagging
				if GameState.held_item() == "hay" and int(st["fed"]) != day and not no_hay:
					GameState.add_item("hay", -1)
					st["fed"] = day
					fed_now = true
					Music.instance(get_tree()).sfx("eat", "pickup")
					hud.toast("%s munches the hay." % species, Color(0.9, 1, 0.8))
				if int(st["last_pet"]) == day and not fed_now:
					hud.toast("Already happy today." if int(st["fed"]) == day or no_hay else ("%s is hungry. Bring hay (hold it and tap)%s." % [species, ", or fill the silo" if Builds.built_tier("barn") >= 2 and not bird else ""]))
					return true
				if int(st["last_pet"]) != day:
					st["streak"] = int(st["streak"]) + 1 if int(st["last_pet"]) == day - 1 else 1
					st["last_pet"] = day
					emote(a, "heart", 1.4, -18.0)
					if not fed_now:
						hud.toast("%s loves that." % species, Color(1, 0.8, 0.9))
					xp("farming", 2)
				else:
					emote(a, "happy", 1.0, -18.0)
				all[nm] = st
				GameState.run["animals"] = all
				# A happy, fed animal gives: eggs from hens, milk from cows, goat milk, wool.
				var k := str(a.kind)
				var prod := "egg" if k.begins_with("chicken") or k.begins_with("hen") or k.begins_with("duck") else ("goat_milk" if k.begins_with("goat") else ("milk" if k.begins_with("cow") else ("sheep_wool" if k.begins_with("sheep") or k.begins_with("llama") else "")))
				if prod != "" and not bool(a.get("baby")) and int(st.get("made", -9)) != day:
					if int(st["fed"]) != day:
						hud.toast("%s is too hungry to give anything today. Hay first." % species, Color(1, 0.85, 0.7))
					else:
						st["made"] = day
						var ay := GameState.bonus("farming", "animal_yield")
						var n := 1 + int(ay) + (1 if randf() < fmod(ay, 1.0) else 0)
						pop_items(a.position, prod, n)
						# Friendship shows in the goods: silver after 5 days running, gold after 14.
						var q := "g" if int(st["streak"]) >= 14 else ("s" if int(st["streak"]) >= 5 else "")
						if q != "":
							GameState.add_quality(prod, q, n)
			return true
		"weeds":
			# Weeds come out by hand (or any tool that swings): fiber, Stardew-style.
			# The can and the rod don't pull weeds (a watering row must not weed).
			if ToolHint.is_soft(GameState.held_tool()):
				ToolHint.say(self, "Pull weeds by hand or with a blade, hoe or scythe.")
				return true
			if not GameState.spend_for("weed"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			var ht := GameState.held_tool()
			if ht == "scythe" or GameState.is_sword(ht):
				player.play_tool("axe")
			else:
				player.play_tool("hold")
			Music.instance(get_tree()).sfx("chop")
			xp("foraging", 1)
			# Cut with the scythe, weeds and tall grass make hay for the animals.
			if ht == "scythe" and randf() < float(thing.get("hay", 0.5)):  # farm: old weed-spot grass always, meadow clumps half
				if not (not Net.visiting() and Builds.silo_add(1)):  # a built silo takes it straight in (host's silo)
					pop_items(cell_center(c), "hay", 1)
			# Now and then a weed's roots hold a packet of wild seed.
			if randf() < 0.06 + 0.01 * GameState.skill_level("foraging"):
				pop_items(cell_center(c), "seed_packet", 1)
			_mark_cleared(c)
			var wsp: Node2D = props.get(c, null)
			clear_cell(c)
			if wsp:
				wsp.queue_free()
			if ht == "scythe" and has_method("scythe_sweep"):
				call("scythe_sweep", c)  # farm: a 3-cell swath (C4 P6)
			for i in 4:
				_leaf(cell_center(c) + Vector2(randf_range(-6, 6), -8))
			pop_items(cell_center(c), "fiber", 1 + (1 if randf() < 0.3 else 0))
			return true
		"tree", "log", "stump":
			if GameState.held_tool() != "axe":
				return ToolHint.need(self, "axe", "to chop it")
			var tb := GameState.tree_block(thing)
			if tb != "":
				player.play_tool("axe")
				wobble(c, 0.02)
				hud.toast(tb, Color(1, 0.85, 0.6))
				Music.instance(get_tree()).sfx("dry_click", "thud")  # clink, no
				return true
			if not GameState.has_perk("foraging", "Keeper of the Woods") and not GameState.spend_for("axe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("axe")
			Music.instance(get_tree()).sfx("chop")
			# Woodcutter nodes: a chance (10% per point) that a swing bites twice as deep.
			if randf() < 0.1 * GameState.bonus("foraging", "chop_bonus") and int(thing.get("hp", 3)) > 1:
				thing["hp"] = int(thing.get("hp", 3)) - 1
			wobble(c, 0.08 if str(thing["type"]) == "tree" else 0.03)
			fx("wood_chips", cell_center(c) + Vector2(0, -10), 16.0, 0.5)
			hitstop = maxf(hitstop, 0.025)  # a little weight on each swing
			thing["hp"] = int(thing.get("hp", 3)) - (1 + (GameState.tool_tier("axe") + 1) / 2 + int(GameState.bonus("foraging", "chop_power")))
			if Companion.has_ability("haul"):
				thing["hp"] = 0  # Dad: "Just point at the tree."
			if int(thing["hp"]) <= 0:
				var is_tree := str(thing["type"]) == "tree"
				xp("foraging", 3)
				# Woodcutting nodes: every 4 points is a sure extra log, the rest a chance at one.
				var wb := GameState.bonus("foraging", "wood_bonus")
				var bonus := int(wb / 4.0) + (1 if randf() < fmod(wb, 4.0) / 4.0 else 0)
				if is_tree:
					# Every tree comes down: it falls, leaves a stump, and regrows
					# after a few days (sooner with Old Growth). No infinite wood.
					_mark_cleared(c)
					if randf() < 0.10 + GameState.bonus("foraging", "sap_chance"):
						pop_items(cell_center(c), "sap", 1)
					if randf() < 0.2 + (0.5 if GameState.has_perk("foraging", "Old Growth") else 0.0):
						pop_items(cell_center(c), "hardwood" if GameState.items.has("hardwood") else "wood", 1)
					fell_tree(c, 4 + bonus)
					# Domino Fall (Foraging): the trunk knocks down the next tree in line.
					if GameState.bonus("foraging", "timber") > 0:
						var dd := c - player.cell()
						dd = Vector2i(signi(dd.x), signi(dd.y))
						if dd == Vector2i.ZERO:
							dd = Vector2i(player.facing_dir())
						var nx := c + dd
						var nt: Dictionary = things.get(nx, {})
						if str(nt.get("type", "")) == "tree" and GameState.tree_block(nt) == "":
							_mark_cleared(nx)
							xp("foraging", 3)
							fell_tree(nx, 4)
				else:
					_mark_cleared(c)
					var sp: Node2D = props.get(c, null)
					clear_cell(c)
					if sp:
						sp.queue_free()
					fx("poof", cell_center(c) + Vector2(0, -6), 16.0, 0.5)
					pop_items(cell_center(c), "wood", 1 + (1 if randf() < 0.5 else 0) + bonus / 2)
					if randf() < 0.35 and GameState.items.has("hardwood"):
						pop_items(cell_center(c) + Vector2(4, 0), "hardwood", 1)
			return true
		"rock":
			if GameState.held_tool() != "pickaxe":
				return ToolHint.need(self, "pickaxe", "to break it")
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				Music.instance(get_tree()).sfx("dry_click", "thud")  # clink, no
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("pick", "chop")
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			hitstop = maxf(hitstop, 0.025)
			var swing := 1 + (GameState.tool_tier("pickaxe") + 1) / 2
			if randf() < GameState.bonus("mining", "double_hit"):
				swing *= 2
			swing += int(GameState.bonus("mining", "mine_power"))
			thing["hp"] = int(thing.get("hp", 2)) - swing
			if int(thing["hp"]) <= 0:
				hitstop = maxf(hitstop, 0.05)
				xp("mining", 2)
				_tremor(c, swing)
				_mark_cleared(c)
				var big := props.has(c) and (props[c] as Sprite2D).texture and str((props[c] as Sprite2D).texture.resource_path).contains("rock_m")
				var extra := "copper"
				var en := 1 if randf() < 0.15 else 0
				if randf() < GameState.bonus("mining", "gem_chance") + GameState.bonus("magic", "gem_chance"):
					extra = ["amethyst", "ruby", "sapphire", "emerald"][randi() % 4]
					en = 1
				break_rock(c, 1 + (1 if randf() < 0.5 else 0) + int(GameState.bonus("mining", "stone_bonus") / 3.0), extra, en, "m" if big else "")
			return true
		"bush":
			if not bool(thing.get("berries", false)):
				hud.toast("No berries on it right now." if GameState.season() != "winter" else "Bare till spring.", Color(0.9, 0.9, 0.9))
				return true
			if bool(thing.get("berries", false)):
				thing["berries"] = false
				thing["hint"] = ""
				GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
				give("berry", 1)
				xp("foraging", 2)
				if props.has(c) and Art.tex("nature", GameState.bush_sprite(false)):
					(props[c] as Sprite2D).texture = Art.tex("nature", GameState.bush_sprite(false))
			return true
		"locked":
			hud.toast(str(thing.get("text", "Locked.")), Color(1, 0.9, 0.75))
			Music.instance(get_tree()).sfx("locked", "thud")
			return true
		"forage":
			var item := str(thing.get("item", "mushroom"))
			GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
			things.erase(c)
			blocked.erase(c)
			hard.erase(c)
			var fsp: Node2D = props.get(c, null)
			props.erase(c)
			if fsp:
				fsp.queue_free()
			# Forager nodes: +6% chance per rank of a double pick, not a flat extra.
			pop_items(cell_center(c), item, 1 + (1 if randf() < GameState.bonus("foraging", "forage_bonus") * 0.06 else 0))
			xp("foraging", 2 + int(GameState.items.get(item, {}).get("tier", 1)))
			return true
	return false


## Open the map up: add `dx` columns of grass to the right and `dy` rows below,
## moving exits that sat on the old right/bottom edges out to the new edges and
## laying a dirt track to them. Call at the end of build(), after add_exit().
func extend(dx: int, dy: int) -> void:
	var oc := cols
	var orow := rows
	cols += dx
	rows += dy
	_ext = Rect2i(oc, orow, dx, dy)  # position: where the added columns/rows start
	for e in exits:
		var r: Rect2i = e["rect"]
		if r.end.x >= oc and dx > 0:
			var nr := Rect2i(cols - r.size.x, r.position.y, r.size.x, r.size.y)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, cols):
					_ext_paths[Vector2i(x, y)] = true
			e["rect"] = nr
		if r.end.y >= orow and dy > 0:
			var nr := Rect2i(r.position.x, rows - r.size.y, r.size.x, r.size.y)
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, rows):
					_ext_paths[Vector2i(x, y)] = true
			e["rect"] = nr
	# Blocks the old map put on its own right/bottom ring are now in the open: clear them.
	for c: Vector2i in blocked.keys():
		if (c.x == oc - 1 or c.y == orow - 1) and not things.has(c) and not props.has(c):
			blocked.erase(c)
			hard.erase(c)
	for c: Vector2i in _ext_paths:
		blocked.erase(c)
		hard.erase(c)
## A wooden signpost beside every labelled exit (W26 travel pieces).
func _place_signposts() -> void:
	if not Art.has("props", "signpost_1"):
		return
	var i := 0
	for e in exits:
		if str(e["label"]) == "":
			continue
		var r: Rect2i = e["rect"]
		var c := Vector2i(r.end.x, r.position.y) if r.size.y >= r.size.x else Vector2i(r.position.x - 1, r.end.y - 1)
		if r.position.x <= 0:
			c = Vector2i(r.end.x, r.position.y - 1)
		elif r.end.x >= cols:
			c = Vector2i(r.position.x - 1, r.position.y - 1)
		elif r.position.y <= 0:
			c = Vector2i(r.end.x, r.end.y)
		else:
			c = Vector2i(r.end.x, r.position.y - 1)
		if not in_content(c) or blocked.has(c) or things.has(c) or props.has(c):
			continue
		var sp := prop("props", "signpost_%d" % (1 + i % 3), c)
		if sp:
			# The sign's text appears when you walk up to it (not painted on the map).
			var txt := str(e["label"]).replace("▲", "").replace("▼", "").replace("◀", "").replace("▶", "").strip_edges()
			things[c] = {"type": "sign", "text": "To the %s" % txt, "hint": "A: read the sign"}
			var l := Label.new()
			l.text = "→ " + txt
			l.add_theme_font_size_override("font_size", 7)
			l.add_theme_color_override("font_color", Color(1, 1, 0.85))
			l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03))
			l.add_theme_constant_override("outline_size", 3)
			l.position = Vector2(-28, -34)
			l.custom_minimum_size = Vector2(56, 10)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.z_index = 30
			l.visible = false
			sp.add_child(l)
			_sign_labels[c] = l
		i += 1


## Light life for the added space: a few rocks, logs, bushes, clumps and critters.
var fill_ext := true  # maps with their own look (the moon) turn the generic filler off


func _fill_extension() -> void:
	if _ext.size == Vector2i.ZERO or not fill_ext:
		return
	var avoid := _ext_paths.duplicate()
	for e in exits:
		for c in cells_of([(e["rect"] as Rect2i).grow(2)]):
			avoid[c] = true
	# Stairs, the rim cell above them and two cells below their foot stay clear.
	for pl: Dictionary in plateaus:
		for st: Vector2i in pl["stairs"]:
			for dy in range(-1, 3):
				avoid[st + Vector2i(0, dy)] = true
	var seed_v := hash(scene_id()) % 1000
	# Only the added strips: the old area is dressed by the map itself, and its own paths
	# (drawn later, so not in ground_word yet) got trees and stumps on them (lake north road).
	var k := 0
	for r: Rect2i in [Rect2i(_ext.position.x, 2, _ext.size.x - 2, rows - 4), Rect2i(2, _ext.position.y, _ext.position.x - 2, _ext.size.y - 2)]:
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var area := float(r.size.x * r.size.y)
		WorldGen.tree_clumps(self, r, seed_v + 5 + k, int(area / 260.0), avoid)
		WorldGen.scatter_props(self, r, seed_v + 6 + k, int(area / 110.0), avoid)
		WorldGen.add_critters(self, r, seed_v + 7 + k, int(area / 350.0))
		k += 10


## "Quest complete: <the quest's own line> (reward)" instead of the raw id.
static func quest_done_text(id: String) -> String:
	var q := GameState._quest_def(id)
	var rw: Dictionary = q.get("reward", {})
	var bits: Array = []
	if rw.has("crystals"):
		bits.append("◆%d" % int(rw["crystals"]))
	if rw.get("item") is Array and (rw["item"] as Array).size() >= 2:
		bits.append("%s ×%d" % [GameState.item_name(str(rw["item"][0])), int(rw["item"][1])])
	for k in ["max_hp", "max_energy", "max_mana"]:
		if rw.has(k):
			bits.append("+%d max %s" % [int(rw[k]), k.trim_prefix("max_")])
	if rw.has("tickets"):
		bits.append("%d tickets" % int(rw["tickets"]))
	var t := str(q.get("text", id.replace("_", " "))).get_slice(". ", 0).trim_suffix(".")  # first sentence: a short toast
	if t.length() > 70:
		t = t.left(67) + "..."
	return "Quest complete: %s%s" % [t, "" if bits.is_empty() else "  (" + ", ".join(bits) + ")"]


func _check_quests() -> void:
	if GameState.run.is_empty():
		return
	for id in GameState.tick_quests():
		hud.toast(quest_done_text(id), Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("quest_done", "levelup")
	for t in GameState.opened:
		hud.toast("New quest: %s" % str(t), Color(1, 0.9, 0.4))
	GameState.opened.clear()


## Emote bubble over a node (W36): "heart", "surprise", "confused", "sleep", "music", "angry", "talk"...
func emote(over: Node2D, name: String, secs := 1.2, dy := -22.0) -> void:
	if over == null or not Art.has("emotes", name):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("emotes", {"e": name}, {"e": 6.0})
	a.animation = "e"
	a.scale = Vector2(0.5, 0.5)
	a.position = Vector2(0, dy)
	a.z_index = 30
	over.add_child(a)
	a.play("e")
	var tw := a.create_tween()
	tw.tween_property(a, "position:y", dy - 4.0, secs)
	tw.tween_callback(a.queue_free)


# ---- action feedback (chop/mine cinematics) ----------------------------------

## Shake a prop when it's hit (trees sway, rocks jolt).
func wobble(c: Vector2i, amount := 0.08) -> void:
	if not props.has(c):
		return
	var sp := props[c] as Node2D
	var tw := sp.create_tween()
	tw.tween_property(sp, "rotation", amount, 0.05)
	tw.tween_property(sp, "rotation", -amount * 0.7, 0.08)
	tw.tween_property(sp, "rotation", amount * 0.3, 0.07)
	tw.tween_property(sp, "rotation", 0.0, 0.06)
	for i in 3:
		_leaf(cell_center(c) + Vector2(randf_range(-8, 8), randf_range(-26, -12)))


## Fell a tree: it tips over away from the player, thuds, bursts into wood.
func fell_tree(c: Vector2i, wood := 5) -> void:
	Music.instance(get_tree()).sfx("timber")
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	_flows.clear()
	props.erase(c)
	# The wood is yours the moment it falls (leaving mid-animation used to lose it).
	give("wood", wood, sp != null)  # quiet: the flying logs chime when they land
	if sp == null:
		return
	var dir := 1.0 if player.position.x <= sp.position.x else -1.0
	var pine := sp is Sprite2D and (sp as Sprite2D).texture and str((sp as Sprite2D).texture.resource_path).contains("pine")
	var anim := ("pine_fall_r" if pine else ("oak_fall_r" if dir > 0 else "oak_fall_l"))
	if Art.has("fx", anim):
		_fell_tree_fx(sp, c, dir, anim, pine, wood)
		return
	var tw := sp.create_tween()
	tw.tween_property(sp, "rotation", dir * 0.25, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "rotation", dir * PI / 2.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		shake(2.5)
		Music.instance(get_tree()).sfx("thud", "hit")
		fx("poof", sp.position + Vector2(dir * 20.0, -4), 14.0, 0.7)
		for i in 5:
			_leaf(sp.position + Vector2(dir * randf_range(6, 30), randf_range(-10, 0))))
	tw.tween_interval(0.35)
	tw.tween_property(sp, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		sp.queue_free()
		pop_items(cell_center(c) + Vector2(dir * 16.0, 0), "wood", wood, false))


func _fell_tree_fx(sp: Node2D, c: Vector2i, dir: float, anim: String, pine: bool, wood: int) -> void:
	# The painted fall: swap the prop for the W32 strip, then the trunk breaks into logs.
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames("fx", {"fall": anim, "trunk": "trunk_break"}, {"fall": 12.0, "trunk": 10.0}, {"fall": false, "trunk": false})
	a.animation = "fall"
	a.scale = Vector2(0.5, 0.5)
	a.position = sp.position
	a.offset = Vector2(0, -float(Art.info("fx", anim).get("cell_h", 112)) / 2.0)
	a.flip_h = pine and dir < 0
	a.z_index = sp.z_index
	add_child(a)
	sp.queue_free()
	a.play("fall")
	var at := cell_center(c)
	var leaves_at := at + Vector2(dir * 18.0, -14)
	await a.animation_finished
	shake(2.5)
	Music.instance(get_tree()).sfx("thud", "hit")
	fx("leaf_burst", leaves_at, 14.0, 0.6)
	fx("dust_puff", at + Vector2(dir * 22.0, 0), 14.0, 0.5)
	await get_tree().create_timer(0.25, false).timeout
	if not is_inside_tree() or not is_instance_valid(a):
		return
	if a.sprite_frames.has_animation("trunk"):
		a.animation = "trunk"
		a.offset = Vector2(0, -float(Art.info("fx", "trunk_break").get("cell_h", 56)) / 2.0)
		a.flip_h = dir < 0
		a.position = at + Vector2(dir * 10.0, 0)
		a.play("trunk")
		fx("wood_chips", at + Vector2(dir * 14.0, -8), 14.0, 0.6)
		await a.animation_finished
	a.queue_free()
	pop_items(at + Vector2(dir * 16.0, 0), "wood", wood, false)


## Break a rock: jolt, crumble, stone pops out.
func break_rock(c: Vector2i, stone := 2, extra := "", extra_n := 0, kind := "") -> void:
	Music.instance(get_tree()).sfx("crate_break", "thud")  # the shatter (hits only "pick")
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	_flows.clear()
	props.erase(c)
	var at := cell_center(c)
	var anim: String = {"copper": "ore_copper_break", "iron": "ore_iron_break", "shard": "ore_crystal_break", "m": "rock_m_break"}.get(kind, "rock_s_break")
	if Art.has("fx", anim):
		if sp:
			sp.queue_free()
		# Frames 0-3 are the crack (already shown on hits); play the shatter.
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.frames("fx", {"b": anim}, {"b": 16.0}, {"b": false})
		a.animation = "b"
		a.frame = 4
		a.scale = Vector2(0.5, 0.5)
		a.position = at
		a.offset = Vector2(0, -float(Art.info("fx", anim).get("cell_h", 72)) / 2.0 + 4)
		add_child(a)
		a.play("b")
		a.animation_finished.connect(a.queue_free)
		fx("stone_chips", at + Vector2(0, -8), 14.0, 0.6)
		fx("dust_puff", at, 14.0, 0.45)
		shake(1.5)
		pop_items(at, "stone", stone)
		if extra != "" and extra_n > 0:
			pop_items(at, extra, extra_n)
		return
	if sp:
		var tw := sp.create_tween()
		tw.tween_property(sp, "scale", sp.scale * Vector2(1.25, 0.7), 0.08)
		tw.tween_property(sp, "modulate:a", 0.0, 0.1)
		tw.tween_callback(sp.queue_free)
	fx("poof", at + Vector2(0, -6), 16.0, 0.5)
	shake(1.5)
	pop_items(at, "stone", stone)
	if extra != "" and extra_n > 0:
		pop_items(at, extra, extra_n)


## Items burst out of a spot, bounce, then fly to you and land in the bag.
func pop_items(at: Vector2, id: String, n: int, give_it := true) -> void:
	if id in ["shard", "crystal_shard"]:
		var ex := GameState.bonus("mining", "shard_bonus") * n
		n += int(ex) + (1 if randf() < fmod(ex, 1.0) else 0)
	var icon := Art.tex("items", "pop_" + id) if Art.has("items", "pop_" + id) else Art.tex("items", Hud.icon_for(id))
	if give_it:
		give(id, n, icon != null)  # flying icons make their own sound on arrival
	if icon == null:
		return  # no picture: the toast from give() says what you got (no flying logs)
	var last := mini(n, 6) - 1
	for i in mini(n, 6):
		var it := Sprite2D.new()
		it.texture = icon
		it.scale = Vector2(0.5, 0.5)
		it.position = at + Vector2(0, -6)
		it.z_index = 5
		it.add_to_group("drops")
		add_child(it)
		var land := at + Vector2(randf_range(-18, 18), randf_range(-4, 10))
		var tw := it.create_tween()
		tw.tween_property(it, "position", land + Vector2(0, -22), 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(it, "position", land, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_interval(0.25 + i * 0.05)
		tw.tween_method(func(f: float) -> void:
			if is_instance_valid(player):
				it.position = it.position.lerp(player.position + Vector2(0, -10), f), 0.0, 1.0, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			it.queue_free()
			# One pickup sound (and sparkle) when the last one lands, not a chatter per icon.
			if i == last:
				Music.instance(get_tree()).sfx("pickup")
				if is_instance_valid(player):
					fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.5))


func _leaf(at: Vector2) -> void:
	var d := Node2D.new()
	d.position = at
	d.z_index = 4
	var age := [0.0]
	var col := Color(0.35, 0.65, 0.25) if GameState.season() != "fall" else Color(0.85, 0.5, 0.2)
	var drift := randf_range(-10, 10)
	d.draw.connect(func() -> void:
		var a: float = age[0]
		d.draw_rect(Rect2(Vector2(drift * a + sin(a * 9.0) * 3.0, a * 22.0), Vector2(2, 2)), Color(col, 1.0 - a)))
	add_child(d)
	var tw := d.create_tween()
	tw.tween_method(func(v: float) -> void: age[0] = v; d.queue_redraw(), 0.0, 1.0, 0.7)
	tw.tween_callback(d.queue_free)


## Tremor (Mining): breaking a rock cracks its 4 neighbours down to one last hit.
func _tremor(c: Vector2i, _swing: int) -> void:
	if GameState.bonus("mining", "tremor") <= 0:
		return
	for dv: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var nt: Dictionary = things.get(c + dv, {})
		if str(nt.get("type", "")) == "rock" and GameState.ore_block(str(nt.get("ore", "stone"))) == "":
			nt["hp"] = mini(int(nt.get("hp", 2)), 1)  # down to one last hit (node text)
			fx("stone_chips", cell_center(c + dv) + Vector2(0, -8), 16.0, 0.4)


## Debris that stays gone: scenes that generate rocks/logs/weeds from a seed skip
## cells recorded here (GameState.run["cleared"][scene] = ["x,y", ...]).
## Remember a chopped tree / broken rock per map, with the day it happened, so
## it stays gone for a while and then regrows (trees 6 days, 2 with Old Growth;
## rocks 4). Older saves stored a plain list: treat those as day 0.
func _mark_cleared(c: Vector2i) -> void:
	var all: Dictionary = GameState.run.get("cleared", {})
	var lst = all.get(scene_id(), {})
	if lst is Array:
		var d := {}
		for k in lst:
			d[str(k)] = 0
		lst = d
	lst["%d,%d" % [c.x, c.y]] = int(GameState.run["day"])
	all[scene_id()] = lst
	GameState.run["cleared"] = all
	net_act({"a": "cleared", "scene": scene_id(), "key": "%d,%d" % [c.x, c.y]})


func is_cleared(c: Vector2i, regrow_days := 10) -> bool:
	var all: Dictionary = GameState.run.get("cleared", {})
	var lst = all.get(scene_id(), {})
	var key := "%d,%d" % [c.x, c.y]
	if lst is Array:
		# Old saves: a plain list of cleared cells, treated as cleared on day 0.
		return key in lst and (regrow_days <= 0 or int(GameState.run["day"]) < regrow_days)
	if not lst.has(key):
		return false
	if regrow_days <= 0:
		return true
	var days := regrow_days
	if GameState.has_perk("foraging", "Old Growth") and scene_id() != "farm":
		days = mini(days, 4)
	return int(GameState.run["day"]) - int(lst[key]) < days


## Declare an exit strip: standing in `r` sends you to `scene` at `spawn`.
var exits: Array = []
func add_exit(r: Rect2i, scene: String, spawn: Vector2, facing: String, label_text := "") -> void:
	exits.append({"rect": r, "scene": scene, "spawn": spawn, "facing": facing, "label": label_text})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			blocked.erase(Vector2i(x, y))
			hard.erase(Vector2i(x, y))
## The trigger area of an exit (round 11): the declared strip widened along the
## map edge over the open road mouth (at least the border corridor's extra cell
## each side, up to 3), and stretched outward through the whole border band, so
## stepping anywhere into the mouth leaves; no need to find the signpost's cell.
## Exits away from the edge keep their own rect. Cached in e["zone"].
func _exit_zone(e: Dictionary) -> Rect2i:
	if e.has("zone"):
		return e["zone"]
	var r: Rect2i = e["rect"]
	var z := r
	var far := pad + 2
	if r.position.x <= 0 or r.end.x >= cols:
		var ex := 0 if r.position.x <= 0 else cols - 1
		var lo := r.position.y - _mouth_run(Vector2i(ex, r.position.y), Vector2i(0, -1))
		var hi := r.end.y + _mouth_run(Vector2i(ex, r.end.y - 1), Vector2i(0, 1))
		if r.position.x <= 0:
			z = Rect2i(-far, lo, r.end.x + far, hi - lo)
		else:
			z = Rect2i(r.position.x, lo, cols + far - r.position.x, hi - lo)
	elif r.position.y <= 0 or r.end.y >= rows:
		var ey := 0 if r.position.y <= 0 else rows - 1
		var lo := r.position.x - _mouth_run(Vector2i(r.position.x, ey), Vector2i(-1, 0))
		var hi := r.end.x + _mouth_run(Vector2i(r.end.x - 1, ey), Vector2i(1, 0))
		if r.position.y <= 0:
			z = Rect2i(lo, -far, hi - lo, r.end.y + far)
		else:
			z = Rect2i(lo, r.position.y, hi - lo, rows + far - r.position.y)
	e["zone"] = z
	# Open nooks of the border band right beside the mouth count too (the band's
	# edge meanders), so there's no spot by the road where you stand and don't go.
	var extra := {}
	if z != r:
		var near := z.grow(3)
		for y in range(near.position.y, near.end.y):
			for x in range(near.position.x, near.end.x):
				var c := Vector2i(x, y)
				if not z.has_point(c) and not in_content(c) and not blocked.has(c):
					extra[c] = true
	e["zone_x"] = extra
	return z


## Is cell `c` inside exit `e`'s trigger area?
func in_exit(e: Dictionary, c: Vector2i) -> bool:
	return _exit_zone(e).has_point(c) or (e.get("zone_x", {}) as Dictionary).has(c)


## How many open edge cells continue the road mouth past `from` along `step`
## (at least 1: the border keeps a corridor one cell wider than the strip).
func _mouth_run(from: Vector2i, step: Vector2i) -> int:
	var n := 1
	for i in range(2, 4):
		var c := from + step * i
		if not in_content(c) or blocked.has(c) or things.has(c):
			break
		n = i
	return n


## Ladders / shafts down: walking onto one (or USE next to it) takes it.
const DESCENT_TYPES := ["down", "shaft", "hole"]
var _exit_grace := {}        # exit index -> true while you stand in it on arrival
var _exit_init := false
var _desc_armed := false     # false until you've stepped off a descent cell


## A way down on `c` or any of the 8 cells around it (own cell first), or (-1, -1).
func descent_near(c: Vector2i) -> Vector2i:
	if things.has(c) and str(things[c].get("type", "")) in DESCENT_TYPES:
		return c
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n := c + d
		if things.has(n) and str(things[n].get("type", "")) in DESCENT_TYPES:
			return n
	return Vector2i(-1, -1)


func check_exits() -> void:
	if player == null or _changing:
		return
	var c := player.cell()
	if not _exit_init:
		# Arriving inside an exit's zone (a spawn near the edge) doesn't bounce you back.
		# Taken on the first frame even while frozen (a fade or greeting), so the
		# grace is about where you arrived, not where you are when it ends.
		_exit_init = true
		for i in exits.size():
			if in_exit(exits[i], c):
				_exit_grace[i] = true
		_desc_armed = not (things.has(c) and str(things[c].get("type", "")) in DESCENT_TYPES)
	if player.frozen:
		return
	for i in exits.size():
		var e: Dictionary = exits[i]
		if in_exit(e, c):
			if _exit_grace.has(i):
				continue
			if Campaign.blocks(self, str(e["scene"])):
				_exit_grace[i] = true  # stay put; step out of the strip and back in to be asked again
				continue
			go_to(str(e["scene"]), e["spawn"], str(e["facing"]))
			return
		_exit_grace.erase(i)
	# Walk into an open ladder / shaft: down you go (the map's interact handles it).
	var on_desc := things.has(c) and str(things[c].get("type", "")) in DESCENT_TYPES
	if on_desc and _desc_armed and player.auto_target == Vector2.INF and not Dialogue.instance(get_tree()).active:
		_desc_armed = false
		try_interact(c)
	elif not on_desc:
		_desc_armed = true


func draw_exits() -> void:
	if Art.has("props", "signpost_1"):
		return  # signposts carry the text; nothing painted on the ground
	for e in exits:
		var r: Rect2i = e["rect"]
		if str(e["label"]) != "":
			var p := Vector2(r.position * TILE)
			label(str(e["label"]), p + Vector2(-24, -3 if r.position.y > 2 else TILE + 12), r.size.x * TILE + 48)


## Place a sprite from art/gen with its feet at the bottom-center of cell `c`
## (plus `extra_w` cells to the right for wide props). Returns null if missing.
## Animated prop (strip in the manifest) placed like prop(); never solid unless asked.
func anim_prop(group: String, name: String, c: Vector2i, extra_w := 0, fps := 4.0, solid := false, scale := 0.5) -> AnimatedSprite2D:
	if _painter_of != null:  # drawing code that places nodes: they belong to the real map
		return _painter_of.anim_prop(group, name, c, extra_w, fps, solid, scale)
	if not Art.has(group, name):
		return null
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.frames(group, {"idle": name}, {"idle": fps})
	a.animation = "idle"
	a.scale = Vector2(scale, scale)
	a.position = cell_pos(c.x + (extra_w + 1) / 2.0, c.y + 1)
	a.offset = Vector2(0, -float(Art.info(group, name).get("cell_h", 48)) / 2.0)
	add_child(a)
	a.play("idle")
	if solid:
		for i in extra_w + 1:
			blocked[Vector2i(c.x + i, c.y)] = true
	return a


## Make a y-sorted prop draw under whoever stands on it (bridges, docks, rugs):
## the sort point moves up `rows` cells while the picture stays where it is.
func walk_over(sp: Sprite2D, rows: int) -> void:
	if sp == null:
		return
	var delta := rows * TILE
	sp.position.y -= delta
	sp.offset.y += delta / sp.scale.y


var _bprops: Array = []


## Every building you can't go into says why, instead of ignoring you (BuildingAccess).
func _lock_untouched_buildings() -> void:
	BuildingAccess.apply(self)


## Interiors lay furniture out by its declared width; big kit art must not wall
## off the room (it once boxed in counters and the town hall door).
var exact_footprints := false


## Each area's own song where one exists, the festival tune on festival day in
## town, a quiet night piece outdoors after dark, and a winter piece on the farm.
const AREA_MUSIC := {"forest": "forest", "wastes": "wastes", "uptown": "uptown", "neon": "neon", "hideout": "hideout",
	"docks": "docks", "underground": "underground", "countryside": "countryside", "orchard_hills": "orchard", "highlands": "mountain",
	"ruins": "ruins", "quarry": "quarry", "riverlands": "lake", "sky": "sky", "station": "mega_station", "moon": "moon",
	"jungle": "jungle", "marsh": "marsh", "bf_frostfield": "battle", "bf_shattered_vale": "battle", "bf_rail_yards": "battle",
	"bf_dockside": "battle", "bf_orchard_line": "battle", "bf_bog_crossing": "battle", "bf_ash_wastes": "battle", "bf_neon_block": "battle",
	"colony_coral": "colony_coral", "colony_kelp": "colony_kelp", "colony_ice": "colony_ice",
	"colony_ember": "colony_ember", "hollow_heart": "hollow_heart", "sanctuary": "sanctuary"}
## Interiors by kind (data/interiors.json ids). Gangster-arc shops get the crew's lounge tune.
const INTERIOR_MUSIC := {"store": "shop", "smith": "shop", "potions": "shop", "bank": "shop", "quarry_office": "shop", "stable": "shop",
	"inn": "inn", "bakery": "inn", "lodge": "inn", "hall": "inn", "clinic": "clinic", "library": "chapel", "chapel": "chapel",
	"school": "chapel", "mansion": "chapel", "lighthouse": "house", "water_mill": "house", "fishing_hut": "house"}
## Every track that counts as boss music (it keeps playing while the fight lasts).
const BOSS_TRACKS := ["boss", "boss_gang", "boss_penguin", "keeper", "marked", "raid",
	"boss_thornmother", "boss_colossus", "boss_wyrm", "boss_roc", "boss_coalbrook", "boss_aurum", "boss_light_eater"]
## Mega bosses' own themes (C4): by kind (a gangster variant may share the stem), then by the
## region the fight is in, so a reskinned boss still gets its region's theme.
const MEGA_BOSS := {"thornmother": "boss_thornmother", "sun_colossus": "boss_colossus", "colossus": "boss_colossus",
	"rime_wyrm": "boss_wyrm", "wyrm": "boss_wyrm", "storm_roc": "boss_roc", "baron_coalbrook": "boss_coalbrook",
	"coalbrook": "boss_coalbrook", "madame_aurum": "boss_aurum", "aurum": "boss_aurum", "light_eater": "boss_light_eater"}
const MEGA_REGION_BOSS := {"gloamwood": "boss_thornmother", "sunscorch": "boss_colossus", "frostpeak": "boss_wyrm",
	"windward": "boss_roc", "ironline": "boss_coalbrook", "giltcity": "boss_aurum"}
var boss_music := "boss"


## The boss song for a foe: the arc themes for arc bosses, stone drums for mine keepers,
## the Marked's own theme for Gift fights.
func boss_track(kind: String) -> String:
	var k := kind.to_lower()
	var t := "boss"
	var mt := ""
	for stem: String in MEGA_BOSS:
		if k == stem or k.begins_with(stem + "_") or k.ends_with("_" + stem):
			mt = str(MEGA_BOSS[stem])
			break
	if mt == "" and not (k.begins_with("marked") or k.begins_with("mk_")):
		var sid := scene_id()
		mt = str(MEGA_REGION_BOSS.get(MegaTravel.region_of(sid), ""))
		if mt == "" and sid == "hollow_deeps":
			mt = "boss_light_eater"
	if mt != "" and Music.has_track(mt):
		return mt
	if k.begins_with("marked") or k.begins_with("mk_"):
		t = "marked"
	elif "golem" in k or "keeper" in k or scene_id() == "mine":
		t = "keeper"
	elif k in ["big_grump", "dark_crystal", "grump_commander", "finargle"] or (k == "commander" and GameState.is_penguins()) or (GameState.is_penguins() and k.begins_with("cboss")):
		t = "boss_penguin"
	elif k in ["president", "thug_brute"] or k.begins_with("lieutenant") or k.begins_with("lt_") or (k == "commander" and not GameState.is_penguins()) or (Racket.on() and k.begins_with("thug")):
		t = "boss_gang"
	return t if Music.has_track(t) else "boss"
const NIGHT_OK := ["farm", "town", "meadow", "lake", "beach", "mountain", "forest", "orchard_hills", "countryside", "riverlands", "highlands"]  # not crystal_meadow: cattopia is its song day and night


func area_track() -> String:
	var id := scene_id()
	var t := str(AREA_MUSIC.get(id, music_track))
	if id == "interior":
		var iid := str(get("interior_id"))
		t = str(INTERIOR_MUSIC.get(iid, music_track if music_track != "town" else "house"))
		if t == "shop" and Racket.on():
			t = "shop_gang"
		t = RecCenter.music_for(self, t)  # today's jukebox record
	if id == "mine" and int(get("floor_no") if get("floor_no") != null else 1) > 30:
		t = "mine_deep"
	if id.begins_with("bf_") and get("battle") != null and is_instance_valid(get("battle")):
		var md := str(get("battle").get("mode"))
		if md in ["siege", "gate", "defend", "camp"]:
			t = "battle_siege"
		elif md in ["escort", "supply"]:
			t = "battle_escort"
		if not GameState.is_penguins() and Music.has_track(t + "_gang"):
			t += "_gang"  # gangster battles: gritty funk/noir variants (battle_gang, battle_siege_gang)
	if Racket.on() and _collectors_near():
		return "raid"
	if not Music.has_track(t):
		t = music_track
	if id == "town" and GameState.festival_today() != "":
		return "festival"
	if id in NIGHT_OK and GameState.is_night():
		return "night"
	if id in NIGHT_OK and (GameState.is_wet() or (sky != null and sky.weather in ["rain", "storm"])) and Music.has_track("rain"):
		return "rain"
	if id == "farm" and GameState.season() == "winter":
		return "winter"
	if id == "farm" and GameState.season() == "fall" and Music.has_track("farm_fall"):
		return "farm_fall"
	return t  # combat/danger music: DangerMusic


## The President's collectors are on this map and close: chase music.
func _collectors_near() -> bool:
	if player == null:
		return false
	for e in enemies:
		if is_instance_valid(e) and e._alive and e.has_meta("collector") and e.position.distance_to(player.position) < 220.0:
			return true
	return false


## Walking behind a tree canopy or a roof: that sprite turns see-through so you
## (and anything hidden behind it) stay visible.
func _update_canopy_fade() -> void:
	for s in _faded:
		if is_instance_valid(s):
			(s as Sprite2D).modulate.a = 1.0
	_faded.clear()
	var pp := player.position
	for s in _canopies:
		if not is_instance_valid(s):
			continue
		var sp := s as Sprite2D
		if absf(sp.position.x - pp.x) > 80.0 or absf(sp.position.y - pp.y) > 120.0:
			continue
		var sz := sp.texture.get_size() * sp.scale
		var r := Rect2(sp.position - Vector2(sz.x / 2.0, sz.y) + (sp.offset * sp.scale if not sp.centered else Vector2(0, sz.y / 2.0)), sz)
		if sp.centered:
			r = Rect2(sp.position + sp.offset * sp.scale - sz / 2.0, sz)
		if pp.y < sp.position.y - 4.0 and r.grow(-3.0).has_point(pp + Vector2(0, -8)):
			sp.modulate.a = 0.45
			_faded.append(sp)


## The light colour for this map at time t (minutes). Outdoors follows the
## season's sunset and sunrise: warm gold at dusk, then real night. Indoors
## gets lamplight after dark; underground and space keep their own light.
func sky_tint(t: int) -> Color:
	var dark := GameState.darkness(t)
	if int(GameState.run["flags"].get("glow_day", -1)) == int(GameState.run["day"]):
		dark *= 0.3
	dark *= Settings.night_strength()
	if not has_sky:
		if RecCenter.is_rec(self):
			return RecGlow.tint(dark)
		if scene_id() in ["house", "interior"]:
			return Color(1, 1, 1).lerp(Color(1.0, 0.9, 0.78), dark)
		return Color(1, 1, 1)
	var gang := Racket.on()
	var day_col := Color(0.84, 0.86, 0.93) if gang else Color(1, 1, 1)
	var dusk_col := Color(1.0, 0.84, 0.70) if not gang else Color(0.92, 0.76, 0.70)
	var night_col := Color(0.28, 0.30, 0.52) if gang else Color(0.36, 0.40, 0.66)
	var glow := GameState.morning_glow(t) * Settings.night_strength()
	if glow > 0.0:
		# Sunrise: a soft rose dawn before the sun, then orange-gold light that
		# fades to plain day by mid-morning. Never night-dark.
		var gold := Color(1.0, 0.82, 0.60) if not gang else Color(0.98, 0.78, 0.64)
		var dawn := Color(0.80, 0.66, 0.72) if not gang else Color(0.70, 0.60, 0.70)
		var col := day_col.lerp(gold, glow * 0.85)
		return col.lerp(dawn, clampf(dark / GameState.DAWN_DARK, 0.0, 1.0) * 0.85)
	if dark < 0.35:
		return day_col.lerp(dusk_col, dark / 0.35)
	return dusk_col.lerp(night_col, (dark - 0.35) / 0.65)


func prop(group: String, name: String, c: Vector2i, extra_w := 0, dy := 0.0, solid := true, scale := 0.5) -> Sprite2D:
	if _painter_of != null:  # e.g. WorldGen.draw_ground_detail places forage from draw_map
		return _painter_of.prop(group, name, c, extra_w, dy, solid, scale)
	var s := Art.sprite(group, name)
	if s == null:
		return null
	var fr := int(Art.info(group, name).get("frames", 1))
	if fr > 1 and s.texture:
		# An animation strip placed as a still: show its first frame, not all of them.
		var at := AtlasTexture.new()
		at.atlas = s.texture
		var cw := float(Art.info(group, name).get("cell_w", s.texture.get_width() / fr))
		at.region = Rect2(0, 0, cw, s.texture.get_height())
		s.texture = at
		s.offset = Vector2(0, -at.get_height() / 2.0)
	s.scale = Vector2(scale, scale)
	s.position = cell_pos(c.x + (extra_w + 1) / 2.0, c.y + 1) + Vector2(0, dy)
	add_child(s)
	props[c] = s
	if s.texture and s.texture.get_height() * scale > 30.0 and group in ["nature", "buildings", "props"]:
		_canopies.append(s)
	if glow and not name.ends_with("unlit") and not name.ends_with("_off"):
		for gw: String in GLOW_WORDS:
			if gw in name:
				glow.lights.append([s, 34.0, s.texture.get_height() * scale * 0.7])
				break
	if group == "buildings":
		_bprops.append([name, c, extra_w, s])
	if group in ["buildings", "props", "nature"]:
		CrispArt.apply(s)  # crisp when the phone magnifies 2x-detail art (shaders/sharp_pixel)
	if solid:
		# Base row always; big structures (buildings, barns, huts) also block the
		# rows their body covers so you can't walk "into" them. Trees stay 1 row.
		var tex_w := s.texture.get_width() * scale
		var tex_h := s.texture.get_height() * scale
		var rows_up := 1
		var w_cells := maxi(extra_w + 1, int(round(tex_w / TILE)))
		if group == "nature" or group == "props":
			# Trees, rocks, bushes, crystals: only the trunk/base cell(s) are solid.
			# The canopy is drawn over you; you walk behind it (y-sort handles it).
			w_cells = extra_w + 1
		elif tex_w >= 56.0 or group == "buildings":
			rows_up = clampi(int(round(tex_h / TILE)) - 1, 1, 5)
		if exact_footprints:
			w_cells = extra_w + 1
			rows_up = 1
		var x0 := c.x + (extra_w + 1) / 2 - w_cells / 2
		for i in w_cells:
			for j in rows_up:
				var bc := Vector2i(x0 + i, c.y - j)
				if j == 0 or not things.has(bc):
					blocked[bc] = true
					if group != "nature":
						hard[bc] = true
	return s


## A building drawn large (scale 1.0 = full 2x art, "realistically" big next to a 26 px
## hero): its footprint is blocked, the door cell (bottom-centre, one row below
## the base) opens `interior`. Returns the door cell.
var _building_doors := {}  # every cell a building covers -> its door cell


func building(name: String, c: Vector2i, interior := "", hint := "", scale := 1.0) -> Vector2i:
	if _painter_of != null:
		return _painter_of.building(name, c, interior, hint, scale)
	var info := Art.info("buildings", name)
	var w_cells := maxi(1, int(round(float(info.get("w", 64)) * scale / TILE)))
	var h_cells := maxi(1, int(round(float(info.get("h", 64)) * scale / TILE)))
	var base := Vector2i(c.x, c.y + h_cells - 1)
	var s := prop("buildings", name, base, w_cells - 1, 0.0, false, scale)
	if s == null:
		return Vector2i(-1, -1)
	# Block the body (leave the top ~1/3 open so you can walk "behind" the roof line).
	var body_rows := maxi(1, int(ceil(h_cells * 0.62)))
	for y in range(base.y - body_rows + 1, base.y + 1):
		for x in range(c.x, c.x + w_cells):
			blocked[Vector2i(x, y)] = true
	var door := Vector2i(c.x + w_cells / 2, base.y + 1)
	if interior != "":
		things[door] = {"type": "door", "interior": interior, "hint": hint if hint != "" else "A: " + interior.capitalize()}
		for y in range(c.y, base.y + 2):
			for x in range(c.x, c.x + w_cells):
				_building_doors[Vector2i(x, y)] = door
	return door


# ---- multiplayer ---------------------------------------------------------------
var _puppets := {}
var _puppet_t := 0.0


func _sync_puppets() -> void:
	for id in Net.peers:
		var info: Dictionary = Net.peers[id]
		var here := str(info.get("scene", "")) == scene_id()
		if here and not _puppets.has(id):
			var pp := Puppet.new()
			pp.setup(int(id), self)
			add_child(pp)
			_puppets[id] = pp
		elif not here and _puppets.has(id):
			(_puppets[id] as Node).queue_free()
			_puppets.erase(id)
	for id in _puppets.keys():
		if not Net.peers.has(id):
			(_puppets[id] as Node).queue_free()
			_puppets.erase(id)


## The host changed the world: redraw what's visible. Guests only.
func on_world_sync(_d: Dictionary) -> void:
	# The soil layer is cheap; a full map redraw costs 150-350 ms, so at most one per 2 s.
	var soil = get("_soil")
	var ssig := hash([GameState.run.get("farm", {}), GameState.sky_waters(), Builds.is_built("greenhouse")])
	if soil is CanvasItem and ssig != _soil_sig:
		_soil_sig = ssig
		(soil as CanvasItem).queue_redraw()
	# The host pushes the world every 2 s. Farm tiles live on the soil layer, time and
	# weather on the HUD/sky: only cleared cells, builds and construction can change
	# the static (baked) ground. Redraw and re-bake only when one of those changed.
	var sig := hash([GameState.run.get("cleared", {}), GameState.run.get("builds", {}), GameState.run.get("construction", {})])  # tilled cells live on the soil layer (solo tilling doesn't redraw the ground either)
	if sig == _sync_sig:
		return
	_sync_sig = sig
	var now := Time.get_ticks_msec()
	if now - _last_sync_redraw >= 2000:
		_last_sync_redraw = now
		queue_redraw()
	elif not _sync_redraw_queued:
		_sync_redraw_queued = true
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			_sync_redraw_queued = false
			if is_inside_tree():
				_last_sync_redraw = Time.get_ticks_msec()
				queue_redraw())


var _last_sync_redraw := -10000
var _sync_sig := 0
var _soil_sig := 0
var _sync_redraw_queued := false


## Guests route world changes through the host.
func net_act(d: Dictionary) -> void:
	if Net.online() and not Net.is_host():
		d["k"] = "act"
		Net.send_host(d)


func _refresh_party() -> void:
	if companion:
		companion.queue_free()
		companion = null
	var cid := Companion.active_id()
	if cid != "" and Companion.defs().has(cid) and scene_id() not in ["house", "interior", "moon"]:
		var comp := Companion.new()
		comp.setup(cid, self)
		comp.position = player.position + Vector2(14, 6)
		add_child(comp)
		companion = comp


## A click/tap anywhere on a building means "go to its door".
func door_for_cell(c: Vector2i) -> Vector2i:
	return _building_doors.get(c, Vector2i(-1, -1))


## Grid path (BFS, 4-neighbour) between content cells, avoiding blocked cells and
## water. Returns the cells to walk through (excluding `from`), or [] if none
## within `max_cells` steps. Cheap enough for villagers to call on a schedule change.
## Cells villagers' paths and idle wanders stay off (crop beds); the player is unaffected.
var keep_off := {}


func find_path(from: Vector2i, to: Vector2i, max_cells := 6000) -> Array:
	if from == to:
		return []
	var ko := keep_off if not keep_off.has(from) and not keep_off.has(to) else {}
	var ok := func(c: Vector2i) -> bool:
		return in_content(c) and not blocked.has(c) and not is_water_cell(c) and not ko.has(c)
	# Snap an unwalkable goal to its nearest walkable neighbour.
	var goal := to
	if not ok.call(goal):
		var best := Vector2i(-1, -1)
		for r in range(1, 4):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var c := to + Vector2i(dx, dy)
					if ok.call(c) and (best == Vector2i(-1, -1) or c.distance_squared_to(to) < best.distance_squared_to(to)):
						best = c
			if best != Vector2i(-1, -1):
				break
		if best == Vector2i(-1, -1):
			return []
		goal = best
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var qi := 0
	var found := false
	while qi < q.size() and qi < max_cells:
		var c: Vector2i = q[qi]
		qi += 1
		if c == goal:
			found = true
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if prev.has(n) or not ok.call(n):
				continue
			prev[n] = c
			q.append(n)
	if not found:
		return []
	var out: Array = []
	var c := goal
	while c != from:
		out.push_front(c)
		c = prev[c]
	return out


## Remove a prop and its thing/block at a cell.
func clear_cell(c: Vector2i) -> void:
	things.erase(c)
	blocked.erase(c)
	hard.erase(c)
	_flows.clear()
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)


## Boss intro card (ui/card_<kind>): slides in over the screen for a couple of seconds.
func boss_card(kind: String, title := "") -> void:
	boss_music = boss_track(kind)
	Music.instance(get_tree()).play(boss_music, DangerMusic.FADE_IN)  # every boss, mine keepers too
	DangerMusic.boss_started(self, boss_music)  # held while the boss fights, then a grace period
	var nm: String = {"big_grump": "card_big_grump", "thug_brute": "card_thug_brute", "president": "card_president", "marsh_witch": "card_marsh_witch", "golem_king": "card_golem_king", "dark_crystal": "card_dark_crystal", "ruin_warden": "card_ruin_warden", "commander": "card_president" if not GameState.is_penguins() else ""}.get(kind, "")
	if kind.begins_with("card:"):
		nm = kind.trim_prefix("card:")
	if nm == "" and Art.has("ui", "card_" + kind):  # lieutenants and later bosses: ui/card_<kind>
		nm = "card_" + kind
	if nm == "" or not Art.has("ui", nm):
		return
	var layer := CanvasLayer.new()
	layer.layer = 11
	layer.add_to_group("toast_hold")  # Hud: toasts wait until the card is gone
	var tr := TextureRect.new()
	tr.texture = Art.tex("ui", nm)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(250, 84)
	tr.size = Vector2(250, 84)
	tr.position = Vector2(290, 100)  # above the player (screen centre), under the boss bar
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(tr)
	var lbl := Label.new()
	lbl.text = title if title != "" else kind.replace("_", " ").capitalize()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	# The card art is drawn keep-aspect (about x 33-216 of the 250), so the title wraps inside it.
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(112, 18)
	lbl.size = Vector2(98, 48)
	if tr.texture and tr.texture.get_height() > tr.texture.get_width() * 0.5:  # a framed portrait card, not a banner
		tr.custom_minimum_size = Vector2(250, 150)
		tr.size = Vector2(250, 150)
		tr.position.y = 60
		lbl.position = Vector2(60, 150)
		lbl.size = Vector2(130, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr.add_child(lbl)
	add_child(layer)
	Music.instance(get_tree()).sfx("roar" if not ("thug" in kind or kind == "president") else "alert", "alert")  # danger, not the level-up jingle
	shake(4.0)
	var tw := create_tween()
	tw.tween_property(tr, "position:x", 10.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(tr, "position:x", -300.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)


## One-shot effect from art/gen/fx at a world position (bottom-center). Falls back to nothing.
func fx(name: String, at: Vector2, fps := 12.0, scale := 0.5, flip := false) -> void:
	if not Art.has("fx", name):
		return
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = Art.frames("fx", {name: name}, {name: fps}, {name: false})
	sp.animation = name
	sp.position = at
	sp.scale = Vector2(scale, scale)
	sp.flip_h = flip
	sp.z_index = 3
	sp.centered = true
	add_child(sp)
	sp.play(name)
	sp.animation_finished.connect(sp.queue_free)


## Rain/snow/leaves/fireflies overlay; set by season/weather.
func set_weather(kind: String) -> void:
	if sky:
		sky.weather = kind


func set_aurora(on: bool) -> void:
	if sky:
		sky.aurora = on


# ---- enemies -----------------------------------------------------------------

## Swing at enemies inside the rect. Subclasses can extend (rocks, etc.).
## Everyone fighting on your side that an enemy can turn on: the pup now,
## teammates later (anything with a position and take_damage()).
var _allies_cache: Array = []
var _allies_frame := -1


func allies() -> Array:
	var fr := Engine.get_process_frames()
	if fr == _allies_frame:
		return _allies_cache
	_allies_frame = fr
	_allies_cache = _allies_raw()
	return _allies_cache


func _allies_raw() -> Array:
	var out: Array = []
	if pet != null and is_instance_valid(pet) and pet.visible and not Pet.resting() and int(Pet.state().get("hp", 0)) > 0:
		out.append(pet)
	for n in get_tree().get_nodes_in_group("allies"):
		if n is Node2D and n != pet and is_instance_valid(n):
			out.append(n)
	return out


## Nothing solid between a and b (stepped every 4 px).
## Path-finding for marching units: a breadth-first "flow field" toward a goal
## cell, cached per goal. flow_dir() gives the direction of the next step from
## a world position, around cliffs, water and buildings.
var _flows := {}


func flow_dir(from: Vector2, goal: Vector2, max_r := 0) -> Vector2:
	var gc := world_to_cell(goal)
	if blocked.has(gc):
		# (Water cells too: on a bank the snapped goal lands in the stream, and a field
		# grown from there reaches both banks.) A goal snapped to the 32-px grid can land on the wall you stand against:
		# use a free cell of the 2x2 block at that corner (the one you're in).
		for d2: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			if not blocked.has(gc + d2):
				gc += d2
				break
	var fc := world_to_cell(from)
	if fc == gc or from.distance_to(goal) < 18.0:
		return (goal - from).normalized() if from.distance_to(goal) > 4.0 else Vector2.ZERO
	var key := Vector3i(gc.x, gc.y, max_r)
	if not _flows.has(key):
		if _flows.size() > 24:
			# Drop the short-lived chase fields first; objective fields are costly to rebuild.
			for k: Vector3i in _flows.keys():
				if k.z > 0:
					_flows.erase(k)
			if _flows.size() > 24:
				_flows.clear()
		_flows[key] = _build_flow(gc, max_r)
	var f: Dictionary = _flows[key]
	if not f.has(fc):
		# No way there from here (and not just outside a chase window): stand, don't push into the bank.
		var inside := max_r == 0 or (absi(fc.x - gc.x) <= max_r and absi(fc.y - gc.y) <= max_r)
		if inside and not blocked.has(fc) and not is_water_cell(fc) and (f.size() > 1 or is_water_cell(gc)):
			return Vector2.ZERO
		return (goal - from).normalized()
	var nxt: Vector2i = f[fc]
	if nxt == gc and blocked.has(gc):
		return Vector2.ZERO  # you're in the water just off this bank: wait here, don't wade
	return (cell_center(nxt) - Vector2(0, TILE / 2.0) - from).normalized()


func _build_flow(gc: Vector2i, max_r := 0) -> Dictionary:
	var out := {gc: gc}
	var q: Array = [gc]
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d: Vector2i in dirs:
			var n := c + d
			if out.has(n) or n.x < -pad or n.y < -pad or n.x >= cols + pad or n.y >= rows + pad:
				continue
			if max_r > 0 and (absi(n.x - gc.x) > max_r or absi(n.y - gc.y) > max_r):
				continue  # chase fields only need the ground round you
			if blocked.has(n) or is_water_cell(n):
				continue
			# No cutting corners past a wall on a diagonal.
			if d.x != 0 and d.y != 0 and (blocked.has(c + Vector2i(d.x, 0)) or blocked.has(c + Vector2i(0, d.y))):
				continue
			out[n] = c
			q.append(n)
	return out


func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 4.0)
	var ca := world_to_cell(a)
	var cb := world_to_cell(b)
	for i in range(1, steps):
		var c := world_to_cell(a + d * (float(i) / steps))
		if c == ca or c == cb:
			continue  # standing in (or against) a blocked cell yourself doesn't hide you
		if blocked.has(c) and not is_water_cell(c):
			return false
	return true


## Where a line from a toward b first hits something solid (or b).
func line_end(a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	var steps := int(d.length() / 4.0)
	for i in range(1, steps):
		var p := a + d * (float(i) / steps)
		if blocked.has(world_to_cell(p)) and not is_water_cell(world_to_cell(p)):
			return p
	return b


func attack_at(r: Rect2, damage: int, from := Vector2.INF, whoosh := true) -> bool:
	if whoosh:
		Music.instance(get_tree()).sfx("swing")  # gun hits pass false: no sword whoosh on a shot
	var hit := false
	var crit_any := false
	var guarded := false
	if from == Vector2.INF:
		from = player.position
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		# Enemies have a body ~12px wide, 14 tall above their feet.
		var body := Rect2(e.position + Vector2(-6, -14), Vector2(12, 14))
		if r.intersects(body) and line_clear(from + Vector2(0, -4), e.position + Vector2(0, -4)):
			var crit := randf() < minf(0.40, 0.01 * GameState.skill_level("combat") + GameState.bonus("combat", "crit"))
			var dmg := int(round(damage * (1.5 if crit else 1.0)))
			if e.kind.begins_with("thug_") and Crew.perk_level("doors") >= 2:
				dmg += 2
			e.provoke(player)
			if e.hit(dmg, from):
				hit = true
				fx("spark", e.position + Vector2(0, -8), 18.0, 0.5)
				damage_number(e.position + Vector2(0, -20), e.last_applied, Color(1, 0.95, 0.4) if crit else Color.WHITE)
				# Weight: a short freeze and a nudge of the camera; more on a kill or a crit.
				var killed: bool = (not is_instance_valid(e)) or (not e._alive)
				hitstop = maxf(hitstop, 0.08 if (killed or crit) else 0.035)
				crit_any = crit_any or crit
				shake(3.0 if killed else (2.0 if crit else 1.2))
			else:
				guarded = true  # shield or GUARD: a 0 pops up, so it shouldn't sound like a whiff
	if hit:
		Music.instance(get_tree()).sfx("hit")
		if crit_any:  # a kill already gets Enemy._die's thud
			Music.instance(get_tree()).sfx("crit")
	elif guarded:
		Music.instance(get_tree()).sfx("dry_click", "thud")
	return hit


var _shake_tw: Tween


## Camera limits: rooms smaller than the view sit in the middle of it, not
## pinned top-left. The view is 270 wide on phones, wider on a desktop (DisplayMode).
func fit_camera(cam: Camera2D) -> void:
	var vw := int(DisplayMode.view.x)
	var mw := (cols + 2 * pad) * TILE
	var mh := (rows + 2 * pad) * TILE
	var ox := maxi(0, (vw - mw) / 2)
	# Indoors the HUD sits across the bottom (Hud.INTERIOR_SHIFT): fit the room above it.
	var view_h := int(Hud.INTERIOR_SHIFT) if scene_id() in ["house", "interior"] and not DisplayMode.wide() else 480
	var oy := maxi(0, (view_h - mh) / 2)
	cam.limit_left = -ox
	cam.limit_top = -oy
	cam.limit_right = maxi(mw, vw) - ox
	cam.limit_bottom = maxi(mh, view_h) - oy + (480 - view_h)


## Camera nudge on a hit (more on a kill or crit).
func shake(amount: float) -> void:
	if player == null or not bool(Settings.get_v("shake")):
		return
	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		for ch in player.get_children():
			if ch is Camera2D:
				cam = ch
	if cam == null:
		return
	var c := cam as Camera2D
	# One shake at a time: a new one takes over (at least as strong) and always ends at zero.
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
		amount = maxf(amount, c.offset.length())
	_shake_tw = c.create_tween()
	for i in 3:
		_shake_tw.tween_property(c, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	_shake_tw.tween_property(c, "offset", Vector2.ZERO, 0.04)


## Floating damage number.
## Ride, row or fly what you built at the Vehicle Workshop.
func _use_vehicle(id: String, it: Dictionary) -> bool:
	if not has_sky:
		hud.toast("Not indoors.")
		return true
	if bool(it.get("fly", false)):
		later(_balloon)
		return true
	if player.vehicle == id:
		player.unride()
		hud.toast("You hop off.")
		return true
	if player.swimming and float(it.get("water", 0.0)) <= 0.0:
		hud.toast("Not in the water.")
		return true
	player.ride(id)
	Music.instance(get_tree()).sfx("menu_open", "pickup")
	hud.toast("%s: USE to hop off." % GameState.item_name(id), Color(0.9, 0.95, 1.0))
	return true


## The balloon drifts to anywhere you've arrived on foot before.
func _balloon() -> void:
	var seen: Dictionary = GameState.run.get("visited", {})
	var ids: Array = []
	var opts: Array = []
	for k in seen:
		if str(k) != scene_id() and ResourceLoader.exists("res://scenes/%s.tscn" % str(k)):
			ids.append(str(k))
			opts.append(str(k).capitalize().replace("_", " "))
	if ids.is_empty():
		hud.toast("Nowhere to drift to yet. Walk somewhere first.")
		return
	if not enemies.is_empty():
		for e in enemies:
			if is_instance_valid(e) and e.position.distance_to(player.position) < 90.0:
				hud.toast("Not with trouble this close.")
				return
	opts.append("Stay")
	var d := Dialogue.instance(get_tree())
	d.say([{"who": "Balloon", "text": "The burner roars. Where to?", "choice": opts, "key": ""}])
	await d.finished
	if d.last_choice < 0 or d.last_choice >= ids.size():
		return
	var sp: Array = seen[ids[d.last_choice]]
	go_to(str(ids[d.last_choice]), Vector2(float(sp[0]), float(sp[1])), "down")


## Eat/drink what you hold (any map). Returns true if something was consumed.
func use_consumable(sel: String) -> bool:
	if sel == "" or GameState.count(sel) <= 0:
		return false
	var it: Dictionary = GameState.items.get(sel, {})
	if str(it.get("type", "")) == "vehicle":
		return _use_vehicle(sel, it)
	match str(it.get("effect", "")):
		"counterfeit":
			return Racket.pass_bills(self, sel)
		"forged_permit":
			return Racket.forged_permit(self, sel)
		"growth":
			var grew := 0
			for k in GameState.run["farm"]:
				var tl: Dictionary = GameState.run["farm"][k]
				var cid := str(tl.get("crop", ""))
				if cid != "" and GameState.crops.has(cid) and int(tl.get("days", 0)) < int(GameState.crops[cid]["days"]):
					tl["days"] = int(tl.get("days", 0)) + 1
					grew += 1
			if grew == 0:
				hud.toast("Nothing is growing on your farm right now.")
				Music.instance(get_tree()).sfx("nope", "thud")
				return true
			GameState.add_item(sel, -1)
			player.play_tool("hold")
			fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.8)
			Music.instance(get_tree()).sfx("spell", "pickup")
			hud.toast("%d crop%s leap a day ahead." % [grew, "" if grew == 1 else "s"], Color(0.7, 1, 0.7))
			# Crops live on the farm's soil layer: never redraw the whole map for them.
			var soil = get("_soil")
			if soil is CanvasItem:
				(soil as CanvasItem).queue_redraw()
			return true
	match str(it.get("effect", "")):
		"scrub":
			if Racket.heat() <= 0:
				hud.toast("Nobody is looking for you right now.")
				Music.instance(get_tree()).sfx("nope", "thud")
				return true
			GameState.add_item(sel, -1)
			player.play_tool("hold")
			Racket.set_heat(Racket.heat() - int(it.get("amount", 2)))
			Music.instance(get_tree()).sfx("zap", "pickup")
			fx("cy_scramble" if Art.has("fx", "cy_scramble") else "sparkle", player.position + Vector2(0, -14), 12.0, 0.6)
			hud.toast("%s: heat down to %d." % [GameState.item_name(sel), Racket.heat()], Color(0.5, 1.0, 0.95))
			return true
		"emp":
			var any_near := false
			for e in enemies:
				if is_instance_valid(e) and e._alive and e.position.distance_to(player.position) < float(it.get("radius", 84.0)):
					any_near = true
			if not any_near:
				hud.toast("Nothing close enough to fry. Save it.", Color(0.7, 0.9, 1.0))
				Music.instance(get_tree()).sfx("nope", "thud")
				return true
			GameState.add_item(sel, -1)
			player.play_tool("hold")
			fx("emp" if Art.has("fx", "emp") else "ripple_ring" if Art.has("fx", "ripple_ring") else "spark", player.position + Vector2(0, -8), 10.0, 0.5 * float(it.get("radius", 84.0)) / 40.0)
			shake(2.0)
			Music.instance(get_tree()).sfx("emp", "zap")
			var hit_n := 0
			var opened := 0
			for e in enemies:
				if is_instance_valid(e) and e.position.distance_to(player.position) < float(it.get("radius", 84.0)):
					e._stun = maxf(e._stun, float(it.get("stun", 4.0)))
					e._knock = Vector2.ZERO
					hit_n += 1
					if e._gift and not e._gift.decoy:
						e._gift.open_t = maxf(e._gift.open_t, float(it.get("open", 3.0)))
						opened += 1
			hud.toast("%s: %d locked up%s." % [GameState.item_name(sel), hit_n, ", %d Gift%s stuttering OPEN" % [opened, "" if opened == 1 else "s"] if opened > 0 else ""], Color(0.5, 1.0, 0.95))
			return true
		"bot":
			GameState.add_item(sel, -1)
			player.play_tool("hold")
			Bot.deploy(self, sel, it)  # plays its own zap
			fx("cy_bot_deploy" if Art.has("fx", "cy_bot_deploy") else "poof", player.position + Vector2(10, 0), 12.0, 0.5)
			hud.toast("%s deployed: %d seconds of cover." % [GameState.item_name(sel), int(it.get("life", 30))], Color(0.5, 1.0, 0.95))
			return true
		"drone":
			var ready_day := int(GameState.run["flags"].get("drone_ready", 0))
			if int(GameState.run["day"]) < ready_day:
				hud.toast("The drone is still charging. Ready on day %d." % ready_day, Color(0.7, 0.9, 1.0))
				Music.instance(get_tree()).sfx("nope", "thud")
				return true
			GameState.run["flags"]["drone_ready"] = int(GameState.run["day"]) + 2
			Music.instance(get_tree()).sfx("alert", "zap")
			player.play_tool("hold")
			fx("cy_drone_scan" if Art.has("fx", "cy_drone_scan") else "sparkle", player.position + Vector2(0, -26), 10.0, 0.6)
			var seen := 0
			var tips: Array = []
			for e in enemies:
				if is_instance_valid(e) and e._alive and not e.has_meta("decoy"):
					seen += 1
					if e._gift:
						e._gift._told = true
						tips.append("%s: %s" % [str(e._gift.d.get("name", "Gift")), str(e._gift.d.get("tip", ""))])
			GameState.run["flags"]["raid_day"] = int(GameState.run["day"])
			hud.toast("Drone: %d hostile%s here. No collectors will find you today. (Recharges in 2 days.)" % [seen, "" if seen == 1 else "s"], Color(0.5, 1.0, 0.95))
			for t: String in tips:
				hud.toast(t, Color(1, 0.9, 0.6))
				GameState.add_hint(t)
			return true
	if str(it.get("effect", "")) == "seed_packet":
		GameState.add_item(sel, -1)
		var sd := GameState.random_season_seed()
		if sd != "":
			player.play_tool("hold")
			give(sd, 2)
			hud.toast("The packet holds: %s!" % GameState.item_name(sd), Color(0.8, 1, 0.7))
		return true
	if str(it.get("effect", "")) == "stink":
		Music.instance(get_tree()).sfx("stink")
		# Cat-topia's secret weapon: everything nearby stops to hold its nose.
		GameState.add_item(sel, -1)
		player.play_tool("hold")
		var cloud: String = {"scented_litter": "stink_scented", "mega_litter": "stink_big"}.get(sel, "stink_small")
		if Art.has("fx", cloud):
			fx(cloud, player.position + Vector2(0, -8), 9.0, 0.5 * float(it.get("radius", 56.0)) / 56.0)
		else:
			fx("poof", player.position + Vector2(0, -6), 12.0, 0.8)
		var n := 0
		for e in enemies:
			if is_instance_valid(e) and e.position.distance_to(player.position) < float(it.get("radius", 56.0)):
				e._stun = maxf(e._stun, float(it.get("stun", 3.0)))
				e._knock = Vector2.ZERO
				n += 1
		hud.toast("%s! %d held their noses." % [GameState.item_name(sel), n] if n > 0 else "%s. Nobody around to mind." % GameState.item_name(sel), Color(0.9, 0.9, 0.7))
		Music.instance(get_tree()).sfx("stink", "pickup")
		return true
	if it.has("heal") or it.has("energy") or it.has("mana") or it.has("buff"):
		var fx_out := GameState.consume(sel)
		effect_text(player.position, fx_out)
		if fx_out.keys() == ["full"]:
			# Nothing to gain: the food stays in the bag.
			hud.toast("Too full for more energy today.", Color(1, 0.8, 0.6))
			return true
		player.play_tool("eat")
		hud.toast("Ate %s.%s" % [GameState.item_name(sel), "  Too full for more energy today." if fx_out.has("full") else ""])
		Music.instance(get_tree()).sfx("eat", "pickup")
		return true
	return false



## Floating "+12 energy" style readouts for what an item just did.
func effect_text(at: Vector2, fx_in: Dictionary) -> void:
	var i := 0
	var names := {"hp": ["health", Color(1, 0.45, 0.45)], "energy": ["energy", Color(0.6, 1, 0.5)], "mana": ["mana", Color(0.55, 0.75, 1)]}
	for k in fx_in:
		var txt := ""
		var col := Color.WHITE
		if names.has(k):
			var v := int(fx_in[k])
			txt = "%s%d %s" % ["+" if v >= 0 else "", v, str(names[k][0])]
			col = names[k][1]
		elif str(k).begins_with("grow_"):
			txt = "max %s +%d" % [str(k).trim_prefix("grow_"), int(fx_in[k])]
			col = Color(1, 0.9, 0.4)
		elif k == "buff":
			txt = "%s up" % str(fx_in[k])
			col = Color(0.9, 0.7, 1)
		elif k == "full":
			txt = "too full"
			col = Color(1, 0.8, 0.6)
		if txt == "":
			continue
		var l := Label.new()
		l.text = txt
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_color", col)
		l.add_theme_constant_override("outline_size", 2)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
		l.position = at + Vector2(-30, -26 - i * 9)
		l.size = Vector2(60, 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_index = 500
		add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "position:y", l.position.y - 14.0, 1.1).set_delay(0.1 * i)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7 + 0.1 * i)
		tw.tween_callback(l.queue_free)
		i += 1


func damage_number(at: Vector2, n: int, col := Color.WHITE) -> void:
	if n <= 0:
		return
	var l := Label.new()
	l.text = str(n)
	l.position = at + Vector2(-8, 0)
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 18.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func spawn_enemy(kind: String, at: Vector2, tier_override := -1) -> Enemy:
	var e := Enemy.new()
	e.map = self
	e.setup(kind, tier_override)
	e.position = free_spot_near(at)
	add_child(e)
	enemies.append(e)
	return e


## Nearest walkable spot to `at` (an enemy spawned inside a tree or wall can
## never move). Spirals out a few cells; falls back to `at`.
func free_spot_near(at: Vector2) -> Vector2:
	var c0 := world_to_cell(at - Vector2(0, 2))  # cell_center sits on the cell's bottom edge
	for r in range(0, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if c.x < 1 or c.y < 1 or c.x >= cols - 1 or c.y >= rows - 1:
					continue
				if blocked.has(c) or is_water_cell(c):
					continue
				# `at` itself only if the 8x3 feet box fits (a box half in a wall can never move).
				return at if r == 0 and not rect_blocked(Rect2(at + Vector2(-4, -3), Vector2(8, 3))) else cell_center(c)
	# Nothing free near `at` (or `at` is off the map): search from a point inside the map.
	var cc := Vector2i(clampi(c0.x, 2, cols - 3), clampi(c0.y, 2, rows - 3))
	if cc != c0:
		for r in range(0, 8):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var c := cc + Vector2i(dx, dy)
					if c.x < 1 or c.y < 1 or c.x >= cols - 1 or c.y >= rows - 1:
						continue
					if blocked.has(c) or is_water_cell(c):
						continue
					return cell_center(c)
	return at


## Item ids that open (not yet done) quests ask for in done_when.item.
func _open_quest_items() -> Dictionary:
	var out := {}
	for q in GameState.run.get("quests", []):
		if bool(q.get("done", false)):
			continue
		var dw: Dictionary = GameState._quest_def(str(q["id"])).get("done_when", {})
		var it = dw.get("item", [])
		if it is String:
			out[it] = true
		elif it is Array and it.size() > 0:
			out[str(it[0])] = true
		for pair in dw.get("items", []):  # [[id, n], ...] (maple_supply_run's stone)
			if pair is Array and pair.size() > 0:
				out[str(pair[0])] = true
	return out


func on_enemy_died(e: Enemy) -> void:
	if e.has_meta("story_flag") and e.kind == "crystal_baby" and not e.get_meta("reverted", false):
		# Broken with a blade, not turned back: she comes back, and the flag waits for ♥.
		hud.toast("Don't break her: turn her back with ♥ (Meow Pow Wow).", Color(1, 0.85, 0.95))
		var c := world_to_cell(e.position)
		Story._spawn_list.call_deferred(self, [[e.kind, c.x, c.y, e.tier, str(e.get_meta("story_flag")), 2.0]])
		return  # no pay for breaking her (else it's a repeatable farm)
	elif e.has_meta("story_flag"):
		GameState.run["flags"][str(e.get_meta("story_flag"))] = true
		shake(3.0)
	if e.has_meta("minion"):
		# Summoned help pays nothing: no crystals, XP, drops or kill counts (no farming a summoner).
		Ops.on_kill(self)  # the last foe on a turf block can be a minion
		return  # Enemy._die already plays the thud
	GameState.run["kills"] = int(GameState.run.get("kills", 0)) + 1
	var kt: Dictionary = GameState.run.get("kills_today", {})
	var kkey := scene_id() + (":%d" % int(get("floor_no")) if scene_id() == "mine" else "")
	# Re-entering a map respawns its foes: only the first 12 a day per map (per mine floor) pay.
	# Named bosses, an unwon battle (160 kills in all: about two full fights, not endless
	# fall-back-and-retry) and an island's foes until its quota always pay, and don't
	# use up the map's 12.
	var boss: bool = e.is_guardian or e.has_meta("boss_name") or e.has_meta("story_flag") or e.has_meta("colony_boss") or e.kind.begins_with("lt_") or e.kind.begins_with("cboss_") or e.kind.begins_with("marked_")
	var fkey := "bfk_" + kkey  # kept in flags: an unwon battle pays its first 160 kills in all, not 80 every day
	var fcap := 160
	var kpool: Array = Campaign.kill_pool(scene_id()) if scene_id().begins_with("bf_") else []  # campaign node / drill: its own pool
	if not kpool.is_empty():
		fkey = str(kpool[0])
		fcap = int(kpool[1])
	var first_battle: bool = scene_id().begins_with("bf_") and (not kpool.is_empty() or not GameState.run["flags"].has("battle_" + scene_id())) and int(GameState.run["flags"].get(fkey, 0)) < fcap
	var quota: bool = e.has_meta("colony_foe") and Colony.data().has(scene_id()) and int(Colony.st(scene_id()).get("kills", 0)) < int((Colony.data()[scene_id()] as Dictionary).get("kills", 0))
	var exempt := boss or first_battle or quota
	if first_battle:
		GameState.run["flags"][fkey] = int(GameState.run["flags"].get(fkey, 0)) + 1
		kt["bf:" + kkey] = int(kt.get("bf:" + kkey, 0)) + 1  # today's count (Fortune's "picked clean" reads it)
		if int(GameState.run["flags"][fkey]) == fcap:
			hud.toast("These foes have paid all the crystals they will. Win the fight to move on.", Color(0.8, 0.8, 0.9))
	elif not exempt:
		kt[kkey] = int(kt.get(kkey, 0)) + 1
	GameState.run["kills_today"] = kt
	var paid: bool = exempt or int(kt.get(kkey, 0)) <= 12
	if paid:
		GameState.add_money(e.reward, "combat")
		hud.toast("+%d crystals" % e.reward, Color(0.7, 0.9, 1))
	elif int(kt.get(kkey, 0)) == 13:
		hud.toast("No more crystals from these foes today.", Color(0.8, 0.8, 0.9))
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(e.kind, {})
	xp("combat", maxi(1, int(round(int(ed.get("xp", 2)) * GameState.tier_scale(e.kind, e.tier, "xp")))))
	var ke := int(GameState.bonus("combat", "kill_energy"))
	if ke > 0 and paid:  # past the cap foes give nothing, energy included
		GameState.extra_energy(ke)
	var table: Array = GameState.enemy_data.get("drops", {}).get(e.kind, [])
	var got: Dictionary = GameState.roll_drops(table)
	if not paid:
		# Past the cap: no loot to sell, but items an open quest asks for still drop.
		var want := _open_quest_items()
		for id: String in got.keys():
			if not want.has(id):
				got.erase(id)
	if paid and e.tier > GameState.enemy_tier(e.kind) and randf() < 0.5 * GameState.tier_scale(e.kind, e.tier, "loot"):
		var extra := GameState.roll_drops(table)
		for id: String in extra:
			got[id] = int(got.get(id, 0)) + int(extra[id])
	for id: String in got:
		pop_items(e.position, id, int(got[id]))
	if e.has_meta("collector"):
		Racket.on_collector_down(self)
	if (e.has_meta("colony_foe") or e.has_meta("colony_boss")) and not e.has_meta("decoy"):
		Colony.on_kill(self, e)
	if e.kind.begins_with("lt_") and not e.has_meta("decoy") and not GameState.run["flags"].has(e.kind):
		GameState.run["flags"][e.kind] = true
		var down := 0
		var total := 0
		var lts: Dictionary = Gift.data().get("lieutenants", {})
		for lid in lts:
			if str((lts[lid] as Dictionary).get("where", "")) == "wastes":
				continue  # penguin-only map: never reachable in the gangster arc
			total += 1
			if GameState.run["flags"].has("lt_" + str(lid)):
				down += 1
		hud.toast("The President's lieutenants: %d of %d down." % [down, total], Color(1, 0.85, 0.5))
		GameState.add_hint("Lieutenant down: %s (%d/%d)" % [e.display_name(), down, total])
		later(_lieutenant_choice.bind(e.kind.trim_prefix("lt_"), e.display_name()))
	Ops.on_kill(self)
	GameState.add_arc_xp(2)
	if GameState.has_team():
		GameState.add_xp("leadership", 2)
	var kc: Dictionary = GameState.run.get("kill_counts", {})
	kc[e.kind] = int(kc.get(e.kind, 0)) + 1
	GameState.run["kill_counts"] = kc


func nearest_enemy_to(p: Vector2, within: float) -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if is_instance_valid(e) and e._alive and e.position.distance_to(p) < within:
			if best == null or e.position.distance_to(p) < best.position.distance_to(p):
				best = e
	return best


## Passing out (round 11):
##   Out of health anywhere, or out of energy / time in the mines: carried to the
##   town clinic. The bill is 8% of your crystals + 20 + 4 per mine floor, capped
##   at 750 (never more than you have). Juniper's perks halve / waive it; easy
##   mode and the no-fee perk waive it.
##   Out of energy (or up past 2am) anywhere else: someone carries you home and
##   5% of your crystals goes missing, capped at 300.
##   Either way you wake next morning with 3/4 energy (GameState.sleep(true)).
const CLINIC_SPAWN := Vector2(3 * 16 + 8, 4 * 16 + 12)  # beside the first bed (interiors.json clinic), clear of the nurse
const MINE_SCENES := ["mine", "hollow_heart", "underground"]


func in_mines() -> bool:
	return scene_id() in MINE_SCENES or scene_id().begins_with("cave")


func player_down(reason := "hurt") -> void:
	if _changing:
		return
	if reason == "hurt" and GameState.bonus("pup", "rescue") > 0.0 and pet and pet.visible and int(Pet.state().get("rescued_day", 0)) != int(GameState.run["day"]):
		Pet.state()["rescued_day"] = int(GameState.run["day"])
		GameState.run["hp"] = 20
		GameState.status_clear()
		player.invuln = 2.0
		hud.toast("%s drags you back to your feet!" % Pet.name_of(), Color(1, 0.9, 0.6))
		emote(pet, "heart", 1.5)
		return
	# Knocked out mid-battle counts as a lost campaign (and still teaches something).
	var bt: Variant = get("battle")
	if bt is Battle and (bt as Battle).is_drill and not (bt as Battle)._over:
		(bt as Battle).drill_rescue(reason)  # the drill is risk-free: no faint, no fee
		return
	if bt is Battle and not (bt as Battle)._over:
		(bt as Battle)._end(false, false)
	_changing = true
	player.frozen = true
	var cr := int(GameState.run["crystals"])
	var mines := in_mines()
	var clinic := (reason == "hurt" or mines) and not Net.visiting()
	var fee := Faint.fee(clinic, int(GameState.run.get("mine_floor", 1)) if mines else 0, reason)
	# A Marked who beat you won't come at you again today.
	for e in enemies:
		if is_instance_valid(e) and e.has_meta("marked"):
			Marked.mark_try(str(e.get_meta("marked")))
	var why := "You collapsed..." if reason == "hurt" else ("Too tired to go on... you pass out." if reason == "tired" else "It's so late... you pass out.")
	hud.toast(why, Color(1, 0.6, 0.6))
	Music.instance(get_tree()).sfx("die" if reason == "hurt" else "sleep")
	await hud.fade_out(1.0)
	GameState.run["crystals"] = maxi(0, cr - fee)
	if Net.visiting():
		# A guest's night is the host's: wake up when the host's day rolls over.
		GameState.run["flags"]["guest_out_day"] = int(GameState.run["day"])
		GameState.run["energy"] = int(GameState.run["max_energy"]) / 2
		GameState.run["hp"] = maxi(int(GameState.run["hp"]), int(GameState.run["max_hp"]) / 2)
	var evening := false
	if not Net.visiting():
		evening = Faint.to_evening(reason)  # before 10pm: come round at 10pm, same day
		if not evening:
			GameState.run["flags"]["wake_report"] = SleepReport.keep(GameState.sleep(true))
	if clinic:
		var where := "in the mines" if mines else "out there"
		var cause := "You'd pushed yourself past empty" if reason == "tired" else ("It was far too late to be down there" if reason == "late" else "You were hurt badly")
		var bill := ("Clinic bill: ◆%d." % fee) if fee > 0 else ("No charge: Juniper doesn't bill anyone in their first week in town." if Faint.in_grace() else Faint.free_line())
		# Shown by the HUD when the clinic loads (Hud._show_clinic_note).
		var finder := "A miner" if mines else "A passer-by"
		var nurse := "the night nurse" if GameState.run["flags"].has("juniper_gone") or evening else "Juniper"
		var kept := "patched you up. It's 10pm now: get home to bed" if evening else "kept you overnight"
		GameState.run["flags"]["clinic_note"] = "%s %s. %s found you and carried you to the clinic, where %s %s. %s" % [cause, where, finder, nurse, kept, bill]
		GameMap.next_interior = "clinic"
		go_to("interior", CLINIC_SPAWN, "down", true)
		return
	if evening:
		GameState.run["flags"]["wake_note"] = ("You come round on your own bed at 10pm, aching. Someone carried you home. ◆%d went missing on the way." % fee) if fee > 0 else "You come round on your own bed at 10pm, aching. Someone carried you home. Get some proper sleep."
	else:
		GameState.run["flags"]["wake_note"] = ("Someone found you and carried you home. ◆%d went missing on the way." % fee) if fee > 0 else "Someone found you and carried you home to bed."
	go_to("house", Vector2(5 * TILE + 8, 5 * TILE), "down", true)


# ---- tap to move -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or player == null or player.frozen or _changing:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and (event as InputEventScreenTouch).device != InputEvent.DEVICE_ID_EMULATION:
		var pos: Vector2 = (event as InputEventScreenTouch).position
		if pos.y >= TouchControls.TOP_OF_CONTROLS and TouchControls.visible_controls:
			return
		if Hud.hud_rect_blocks(pos):
			return
		handle_tap(pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).device != InputEvent.DEVICE_ID_EMULATION:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			player.mouse_held = false
			return
		if not mb.pressed or mb.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] or Hud.hud_rect_blocks(mb.position):
			return
		# Real mouse (not a touch emulated as a mouse). Left click: if you clicked a
		# door, a person, an enemy or anything with a prompt, walk over and use it
		# (like a tap on the phone); otherwise swing the tool toward the cursor, and
		# keep swinging while the button is held. Right click: check/talk only.
		var world := get_canvas_transform().affine_inverse() * mb.position
		var c := world_to_cell(world)
		var dc := door_for_cell(c)
		if dc != Vector2i(-1, -1):
			c = dc
			world = cell_center(c)
		var me := player.cell()
		var near := absi(c.x - me.x) <= 1 and absi(c.y - me.y) <= 1
		var target_thing: Dictionary = things.get(c, {})
		var interactable := has_npc_at(c) or nearest_enemy_to(world, 14.0) != null or (not target_thing.is_empty() and hint_for(c, target_thing) != "") or _exit_at(c)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if interactable and not near:
				handle_tap(mb.position)
			else:
				player.face_toward(world)
				player.do_action("action")
		elif interactable and not near and (GameState.held_tool() == "" or GameState.is_sword(GameState.held_tool())) or (interactable and not near and str(target_thing.get("type", "")) in ["door", "idoor", "npc", "sign", "bed", "chest", "counter", "shop", "exit"]):
			handle_tap(mb.position)
		else:
			player.face_toward(world)
			player.mouse_held = true
			player.do_action("a" if near and interactable else "tool")
		get_viewport().set_input_as_handled()


## Can the hoe open this cell? Farm overrides.
func can_till(_c: Vector2i) -> bool:
	return false


func _exit_at(c: Vector2i) -> bool:
	for e in exits:
		if in_exit(e, c):
			return true
	return false


## Stardew-mobile tap: walk there, or walk up to the thing and use it.
func handle_tap(pos: Vector2) -> void:
	if get_tree().paused or player == null or player.frozen or _changing:
		return
	var world := get_canvas_transform().affine_inverse() * pos
	var c := world_to_cell(world)
	var dc := door_for_cell(c)
	if dc != Vector2i(-1, -1):
		c = dc
	# Tapping a tree's leaves means the tree: its trunk is a few cells below.
	if not (things.has(c) and str(things[c].get("type", "")) in ["tree", "fruit_tree"]):
		for dy in range(1, 4):
			var tc := c + Vector2i(0, dy)
			if things.has(tc) and str(things[tc].get("type", "")) in ["tree", "fruit_tree"]:
				c = tc
				break
	var e := nearest_enemy_to(world, 14.0)
	# An enemy under your finger wins over the pup biting it; the pup needs a close tap.
	if e == null and pet != null and is_instance_valid(pet) and pet.visible and world.distance_to(pet.position + Vector2(0, -6)) < 9.0 and pup_menu_allowed():
		if player.position.distance_to(pet.position) < 40.0:
			later(_pup_menu)
		else:
			player.go_to_cell(world_to_cell(pet.position), false)
		return
	if true:
		if e:
			player.go_to_cell(world_to_cell(e.position - Vector2(0, 2)), true)
		elif has_npc_at(c):
			player.go_to_cell(c, true)
		elif things.has(c) and (hint_for(c, things[c]) != "" or things[c].get("type") == "plot"):
			player.go_to_cell(c, true)
		elif not blocked.has(c) or _exit_at(c):
			player.go_to_cell(c, false)


## Tap the pup (or face it and press CHECK): feed it, give a potion, pet it,
## change its gear or pack, or give it an order.
func _pup_menu() -> void:
	var pt := pet as Pet
	if pt == null:
		return
	var nm := Pet.name_of()
	var st := Pet.state()
	var down := pt.is_down()
	var foods: Array = []
	for id in GameState.run["inventory"].keys():
		var it: Dictionary = GameState.items.get(str(id), {})
		if it.has("pet_heal") or int(it.get("heal", 0)) > 0 or (int(it.get("energy", 0)) > 0 and str(it.get("type", "")) in ["food", "crop", "fish", "drink", "forage", "potion"]):
			foods.append(str(id))
	foods.sort_custom(func(a: String, b: String) -> bool: return _pet_heal_of(a) > _pet_heal_of(b))
	var opts: Array = []
	var acts: Array = []
	if not down:
		opts.append("Pet %s" % nm); acts.append(["pet", ""])
	# Food only when it's needed; cheapest that fully heals first, so a pat never costs your best meal.
	var missing := Pet.max_hp() - int(st["hp"])
	if down or missing > 0:
		foods.sort_custom(func(a: String, b: String) -> bool:
			var ha := _pet_heal_of(a) >= missing
			var hb := _pet_heal_of(b) >= missing
			if ha != hb:
				return ha
			return _pet_heal_of(a) < _pet_heal_of(b) if ha else _pet_heal_of(a) > _pet_heal_of(b))
		for id in foods.slice(0, 3):
			opts.append("Give %s (+%d health)" % [GameState.item_name(id), _pet_heal_of(id)])
			acts.append(["feed", id])
	if not down:
		opts.append("Gear and pack…"); acts.append(["menu", ""])
		opts.append("Heel" if str(st.get("mode", "")) != "follow" else "Stay here"); acts.append(["mode", "follow" if str(st.get("mode", "")) != "follow" else "wait"])
	opts.append("Leave"); acts.append(["leave", ""])
	var hp_line := "%s · health %d / %d" % [nm, int(st["hp"]), Pet.max_hp()]
	if down:
		hp_line = "%s is down. Food or a potion will get %s up." % [nm, "it"]
		if foods.is_empty():
			hp_line += " (You have nothing to give: find food fast, or %s goes home to rest.)" % nm
	var d := Dialogue.instance(get_tree())
	d.say([{"who": nm, "text": hp_line, "choice": opts, "key": ""}])
	await d.finished
	var i := d.last_choice
	if i < 0 or i >= acts.size():
		return
	match str(acts[i][0]):
		"feed":
			var id := str(acts[i][1])
			GameState.add_item(id, -1)
			pt.revive_with(_pet_heal_of(id))
			emote(pt, "heart", 0.8)
			Music.instance(get_tree()).sfx("eat", "pickup")
		"pet":
			emote(pt, "heart", 1.0)
			if pt.anim.sprite_frames.has_animation("play"):
				pt.anim.play("play")
			if int(st.get("petted_day", -1)) != int(GameState.run["day"]):
				st["petted_day"] = int(GameState.run["day"])
				GameState.add_xp("pup", 3)
				GameState.add_xp("leadership", 2)
		"menu":
			for ch in get_children():
				if ch is GameMenu:
					(ch as GameMenu)._tab = "Pup"
					(ch as GameMenu).toggle()
		"mode":
			pt.set_mode(str(acts[i][1]))


func _pet_heal_of(id: String) -> int:
	var it: Dictionary = GameState.items.get(id, {})
	if it.has("pet_heal"):
		return int(it["pet_heal"])
	return clampi(int(it.get("heal", 0)) * 2 + int(it.get("energy", 0)) / 2, 5, 60)


## Read letters one by one; gifts and favours are handled from the letter.
func read_mail() -> void:
	var unread: Array = []
	for m: Dictionary in Mail.list():
		if not bool(m.get("read", false)) or (str(m.get("kind", "")) == "favour" and not bool(m.get("done", false))) or (str(m.get("kind", "")) == "gift" and not bool(m.get("got", false))):
			unread.append(m)
	if unread.is_empty():
		await say([{"text": "No new mail."}])
		return
	for m: Dictionary in unread:
		m["read"] = true
		var opts: Array = []
		match str(m.get("kind", "")):
			"gift":
				if not bool(m.get("got", false)):
					opts = ["Take the %s" % GameState.item_name(str(m["item"])), "Later"]
			"favour":
				if not bool(m.get("done", false)):
					opts = ["Send %d %s (have %d)" % [int(m["n"]), GameState.item_name(str(m["item"])), GameState.count(str(m["item"]))], "Not now"]
		var line := {"who": "Letter from " + str(m["from"]), "text": str(m["text"])}
		if not opts.is_empty():
			line["choice"] = opts
			line["key"] = ""
		var d := Dialogue.instance(get_tree())
		d.say([line])
		await d.finished
		if not opts.is_empty() and d.last_choice == 0:
			var err := Mail.act(m)
			if err != "":
				hud.toast(err, Color(1, 0.8, 0.6))
			elif str(m["kind"]) == "gift":
				hud.toast("+%d %s" % [int(m.get("n", 1)), GameState.item_name(str(m["item"]))], Color(0.85, 1, 0.85))
			else:
				hud.toast("Sent. +◆%d" % int(m["pay"]), Color(1, 0.9, 0.5))


func has_npc_at(_c: Vector2i) -> bool:
	return false


# ---- time --------------------------------------------------------------------

var _job_check := 0


var _autosave_t := 0.0


## A beaten lieutenant: let them walk, or (Old Mags and Brock only) bring them in.
const LT_JOINS := {"mags": "Fine. I know every back road from here to the coast. They're yours.", "brock": "Nobody ever asked. ...Yeah. I'll stand with you."}


func _lieutenant_choice(id: String, nm: String) -> void:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": nm, "text": "...Go on, then. What happens to me now?", "choice": ["Walk away. Don't come back.", "Come with us. Work for the crew."], "key": "lt_" + id}])
	await d.finished
	if d.last_choice == 1:
		if LT_JOINS.has(id):
			GameState.run["flags"]["lt_joined_" + id] = true
			d.say([{"who": nm, "text": str(LT_JOINS[id])}])
			await d.finished
			if id == "brock":
				GameState.run["bonus_hp"] = int(GameState.run.get("bonus_hp", 0)) + 15
				GameState._apply_max_stats()
				hud.toast("Brock joins: +15 max health (he spars with you).", Color(1, 0.9, 0.5))
			else:
				GameState.run["bonus_energy"] = int(GameState.run.get("bonus_energy", 0)) + 20
				GameState._apply_max_stats()
				hud.toast("Old Mags joins: +20 max energy (her back roads save your legs).", Color(1, 0.9, 0.5))
			return
		d.say([{"who": nm, "text": "Work for you? I'd rather walk. Don't worry. I'm done with him too."}])
		await d.finished
	GameState.run["flags"]["lt_spared_" + id] = true


var _upd_t := 0.0
static var _update_told := false
static var _other_told := false


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
	if _night:
		_night.color = sky_tint(int(GameState.run["time"]))
	DangerMusic.tick(self, delta)  # area song, or combat music while foes fight or chase you
	_fade_t -= delta
	if _fade_t <= 0.0 and player:
		_fade_t = 0.1
		_update_canopy_fade()
	if get_tree().paused:
		return
	if hud and not (GameState.run.get("notes", []) as Array).is_empty():
		for nt in GameState.run["notes"]:
			hud.toast(str(nt), Color(1, 0.85, 0.9))
			var low := str(nt).to_lower()
			if "letter" in low:
				Music.instance(get_tree()).sfx("mail")
			elif "level" in low or "heart" in low or low.begins_with("built"):  # (learned: the menu already played craft_done)
				Music.instance(get_tree()).sfx("levelup")
				if player:
					fx("skill_up" if Art.has("fx", "skill_up") else "levelup", player.position + Vector2(0, -4), 10.0, 0.6)
		GameState.run["notes"] = []
	if not GameState.run.is_empty() and GameState.run["flags"].has("epilogue_done") and not GameState.run["flags"].has("epilogue_shown") and not _changing and not Dialogue.instance(get_tree()).active and player and not player.frozen:
		GameState.run["flags"]["epilogue_shown"] = true
		Epilogue.play(self)
	# Autosave every 90 s of play when nothing is mid-scene (phones kill tabs).
	_autosave_t += minf(delta, 0.5)
	if _autosave_t >= 90.0 and not _changing and not Dialogue.instance(get_tree()).active:
		_autosave_t = 0.0
		GameState.save()
	# Web: a new version was deployed (the page's service worker found it). Save
	# now so tapping the update banner loses nothing, and say where the banner is.
	_upd_t += delta
	if _upd_t >= 3.0 and OS.has_feature("web") and not _other_told and bool(JavaScriptBridge.eval("window.dreamsOtherOpen === true", true)):
		_other_told = true
		SaveGame._blocked = true  # the newer window owns the farm now; this one stops writing (its handover save already ran from the page)
		say([{"text": "Dreams was opened in another window. This copy has stopped saving so it can't overwrite your farm. Close it, or reload the page to play here."}])
	if _upd_t >= 3.0 and OS.has_feature("web") and not _other_told and bool(JavaScriptBridge.eval("window.dreamsOtherOlder === true", true)):
		_other_told = true
		hud.toast("Dreams is open in another window too. That one has stopped saving; keep playing here.", Color(1, 0.85, 0.6))
	if _upd_t >= 3.0:
		_upd_t = 0.0  # every check above runs once per 3 s, never every frame
	if _upd_t == 0.0 and not _update_told and OS.has_feature("web"):
		if bool(JavaScriptBridge.eval("window.dreamsUpdateReady === true", true)):
			_update_told = true
			if not _changing:
				GameState.save()
			hud.toast("A new version of Dreams is ready. Tap the yellow bar at the top to update. Your farm is saved.", Color(1, 0.85, 0.4))
	# Clamp: a phone coming back from the background reports one huge frame;
	# that must not fast-forward the clock by hours.
	_time_acc += minf(delta, 0.25) * GameState.minutes_per_second()  # C4: per-slot day length
	if _time_acc >= 1.0:
		var m := int(_time_acc)
		_time_acc -= m
		GameState.run["time"] = int(GameState.run["time"]) + m
		# A station finished something: say so once, wherever you are.
		_job_check += m
		if _job_check >= 10:
			_job_check = 0
			for note in Crafting.newly_done():
				hud.toast(str(note), Color(1, 0.9, 0.5))
	var t := int(GameState.run["time"])
	if t >= 24 * 60 and not _changing:
		var bn := Faint.bedtime_note()
		if bn != "":
			hud.toast(bn, Color(1, 0.75, 0.55))
	if t >= GameState.DAY_END and not _changing and not (Net.visiting() and int(GameState.run["flags"].get("guest_out_day", -1)) == int(GameState.run["day"])):  # a guest already out tonight waits for the host's morning
		player_down("late")
	elif int(GameState.run["energy"]) <= 0 and not _changing and not player.frozen:
		player_down("tired")
	# Mana trickles back in real time: 1 point every 14 s (Attunement: 10.5, 7), any day length.
	_mana_acc += delta
	if _mana_acc >= GameState.mana_regen_secs():
		_mana_acc = 0.0
		GameState.restore_mana(1)
	if player and hud:
		var fc := player.facing_cell()
		hud.set_hint(hint_for(fc, things.get(fc, {})))
		TouchControls.context_word = action_word(fc)
	Events.tick(self, delta)
	Story.tick(self, delta)
	if Net.online():
		_puppet_t += delta
		if _puppet_t > 1.0:
			_puppet_t = 0.0
			_sync_puppets()
	for c: Vector2i in _sign_labels:
		(_sign_labels[c] as Label).visible = player.position.distance_to(cell_center(c)) < 30.0
	update_enemies(delta)
	check_exits()


func update_enemies(_delta: float) -> void:
	pass


# ---- transitions -------------------------------------------------------------

var _transitioning := false


func go_to(scene: String, spawn: Vector2, facing := "down", force := false) -> void:
	# One transition at a time. player_down passes force (it set _changing itself).
	if _transitioning or (_changing and not force):
		return
	# Regions held by a campaign stay shut until it's won (Campaign offers the board).
	if not force and Campaign.blocks(self, scene):
		return
	_transitioning = true
	if scene == "interior":
		PlaceNames.entering(self)  # the HUD labels the room as its door read
	# A creak only for real doors (in or out of a building, a mine), not road edges or ferries.
	if not force and (scene.contains("house") or scene.contains("interior") or scene.contains("mine") or scene_id() in ["house", "interior", "mine"]):
		Music.instance(get_tree()).sfx("door")
	_changing = true
	player.frozen = true
	next_spawn = spawn
	next_facing = facing
	# Save as if already there, so closing the app mid-fade resumes on arrival.
	var prev_scene: Variant = GameState.run.get("scene", "")
	GameState.run["scene"] = scene
	GameState.run["spawn"] = [spawn.x, spawn.y, facing]
	if scene == "interior" and next_interior != "":
		GameState.run["interior"] = next_interior  # a kill mid-fade reopens the right building
	GameState.save()
	GameState.run["scene"] = prev_scene
	await hud.fade_out(0.35)
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


func say(lines: Array) -> void:
	var d := Dialogue.instance(get_tree())
	d.say(lines)
	await d.finished


## Fire-and-forget dialogue for sync contexts (interact() must return a bool,
## so it can't be a coroutine; Godot errors on un-awaited coroutine calls).
func tell(lines: Array) -> void:
	Dialogue.instance(get_tree()).say(lines)


## Start a coroutine from a sync context without the "call without await" error.
func later(cb: Callable) -> void:
	cb.call_deferred()


func give(id: String, n := 1, quiet := false) -> void:
	_check_quests.call_deferred()
	GameState.add_item(id, n)
	hud.toast("+%d %s" % [n, GameState.item_name(id)], Color(0.85, 1, 0.85))
	if not quiet:
		Music.instance(get_tree()).sfx("pickup")
		if player:
			fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.5)


func xp(skill: String, n: int) -> void:
	GameState._xp_loud = true
	var up := GameState.add_xp(skill, n)
	GameState._xp_loud = false
	if up:
		hud.toast("%s level %d! A skill point to spend." % [str(GameState.skills_data.get(skill, {}).get("name", skill.capitalize())), GameState.skill_level(skill)], Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")
		if player:
			fx("skill_up" if Art.has("fx", "skill_up") else "levelup", player.position + Vector2(0, -4), 10.0, 0.6)
			if GameState.skill_level(skill) % 5 == 0 and Art.has("fx", "levelup2"):
				fx("levelup2", player.position + Vector2(0, -20), 12.0, 0.4)


# ---- shared drawing helpers --------------------------------------------------

## Grass everywhere with scattered decoration tiles (seeded so it's stable).
## Per-frame layer for the few things that animate on the ground (water, waterfalls).
class AnimLayer extends Node2D:
	var jobs: Array[Callable] = []
	## Cells on screen (plus a margin), so water off-screen isn't drawn.
	var view := Rect2i(-9999, -9999, 99999, 99999)
	var _tick := -1
	var _cam := Vector2(INF, INF)
	func _process(_d: float) -> void:
		if jobs.is_empty():
			return
		# Redraw at 8 fps (the water frames change at 4) or when the camera has
		# moved past the margin; not every frame.
		var t := int(Time.get_ticks_msec() / 125)
		var xf := get_viewport().get_canvas_transform() * get_global_transform()
		var cam := xf.origin
		if t == _tick and cam.distance_squared_to(_cam) < 256.0:
			return
		_tick = t
		_cam = cam
		var r := xf.affine_inverse() * get_viewport_rect()
		view = Rect2i(int(floor(r.position.x / TILE)) - 3, int(floor(r.position.y / TILE)) - 3, int(ceil(r.size.x / TILE)) + 6, int(ceil(r.size.y / TILE)) + 6)
		queue_redraw()
	func _draw() -> void:
		for j in jobs:
			j.call(self)


func _draw() -> void:
	if _bake_on():
		_bake_request()
		return
	# Painter, clipped to one chunk: draw helpers skip what lies outside it, per-cell
	# loops walk only its cells; the animated jobs (water) stay as the full pass made them.
	var clipped := _painter_of != null and _bake_clip.has_area()
	var jobs_n := -1
	if _anim_layer:
		if clipped:
			jobs_n = _anim_layer.jobs.size()
		else:
			_anim_layer.jobs.clear()
	Art.clip = _bake_clip if clipped else Rect2()
	draw_set_transform(offset())
	draw_map()
	if not _ext_paths.is_empty():
		draw_ground("dirt", _ext_paths)
		draw_exits()
	if pad > 0:
		draw_border()
	draw_set_transform(Vector2.ZERO)
	Art.clip = Rect2()
	if jobs_n >= 0 and _anim_layer.jobs.size() > jobs_n:
		_anim_layer.jobs.resize(jobs_n)
	if _painter_of != null and not clipped:
		_bake_full_done = true


## Cells (content coordinates) a clipped painter pass must walk: the clip plus
## `grow` cells for things drawn beyond their cell (tufts, flowers, rims). The
## whole padded map when not clipped.
func clip_cells(grow := 4) -> Rect2i:
	var all := Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	if not Art.clip.has_area():
		return all
	var p0 := Vector2i((Art.clip.position / TILE).floor()) - Vector2i(grow, grow)
	var p1 := Vector2i((Art.clip.end / TILE).ceil()) + Vector2i(grow, grow)
	return Rect2i(p0, p1 - p0).intersection(all)


## Exit corridors through the border band (region.gd draws its own road tiles).
func draw_corridor(cells: Dictionary) -> void:
	var k := corridor_kind()
	if k in ["dirt", "sand"] and scene_id() != "beach":
		var body := widen_path(cells)
		var seam := "dirt_track" if k == "dirt" else "sand"
		var gs: Dictionary = (_painter_of if _painter_of != null else self).ground_seam
		for c: Vector2i in gs:
			if str(gs[c]) == seam:
				body[c] = true  # redraw the map's own paths with the corridor as one shape: no ring where they meet
		if soft_ground(body, seam, Color(0.25, 0.15, 0.06, 0.3 if k == "dirt" else 0.0)):
			return
	draw_ground(k, cells)


## What the exit corridors through the border band are paved with. Regions use
## their own path kind (stone for asphalt, metal and the like) instead of dirt.
func corridor_kind() -> String:
	var rd = get("R")
	if rd is Dictionary:
		var k := str((rd as Dictionary).get("path", "dirt"))
		return k if k in ["dirt", "sand", "stone"] else "stone"
	return "dirt"


## Subclasses draw their ground here (content coordinates; the pad offset is applied).
func draw_map() -> void:
	pass


var _tall := {}
var _geom_memo := {}  # drawing geometry/orders worked out by a full pass, reused by clipped bakes (shared with the painter)


## Seamless ground (Prompts 16): a 256px texture that tiles every 8 cells. Each
## cell draws its own 32px window, so any set of cells joins up with no seams.
const SEAM_PERIOD := 128.0   # world px per texture repeat (256 art px at 2x detail)


## A seamless texture over a whole world-px rect, in blocks aligned to the 8-cell
## period: exactly the texels seam_cell draws for each cell inside it.
func seam_fill(ci: CanvasItem, name: String, area: Rect2, col := Color.WHITE) -> bool:
	var t := Art.tex("seamless", name)
	if t == null:
		return false
	var by := floorf(area.position.y / SEAM_PERIOD) * SEAM_PERIOD
	while by < area.end.y:
		var bx := floorf(area.position.x / SEAM_PERIOD) * SEAM_PERIOD
		while bx < area.end.x:
			var blk := Rect2(bx, by, SEAM_PERIOD, SEAM_PERIOD).intersection(area)
			if not Art.clipped(blk):
				ci.draw_texture_rect_region(t, blk, Rect2((blk.position - Vector2(bx, by)) * 2.0, blk.size * 2.0), col)
			bx += SEAM_PERIOD
		by += SEAM_PERIOD
	return true


func seam_cell(ci: CanvasItem, name: String, c: Vector2i, col := Color.WHITE, scroll := Vector2.ZERO) -> bool:
	var t := Art.tex("seamless", name)
	if t == null:
		return false
	var wx := fposmod(c.x * TILE + scroll.x, SEAM_PERIOD) * 2.0
	var wy := fposmod(c.y * TILE + scroll.y, SEAM_PERIOD) * 2.0
	var src := Rect2(wx, wy, TILE * 2, TILE * 2)
	var dst := Rect2(c * TILE, Vector2i(TILE, TILE))
	if Art.clipped(dst):
		return true
	if wx + TILE * 2 > 256.0 or wy + TILE * 2 > 256.0:
		# Window straddles the texture's edge: draw it in up to four pieces.
		var w1 := minf(TILE * 2, 256.0 - wx)
		var h1 := minf(TILE * 2, 256.0 - wy)
		for part in [[wx, wy, w1, h1, 0.0, 0.0], [0.0, wy, TILE * 2 - w1, h1, w1, 0.0], [wx, 0.0, w1, TILE * 2 - h1, 0.0, h1], [0.0, 0.0, TILE * 2 - w1, TILE * 2 - h1, w1, h1]]:
			if part[2] > 0.01 and part[3] > 0.01:
				ci.draw_texture_rect_region(t, Rect2(dst.position + Vector2(part[4], part[5]) * 0.5, Vector2(part[2], part[3]) * 0.5), Rect2(part[0], part[1], part[2], part[3]), col)
		return true
	ci.draw_texture_rect_region(t, dst, src, col)
	return true


func draw_grass(seed_v := 1, r := Rect2i(0, 0, 0, 0)) -> void:
	if r.size == Vector2i.ZERO:
		r = Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	_deco_rng.seed = seed_v
	var gname := GameState.grass_tile()
	var has_tiles := Art.has("tiles", gname)
	var season := GameState.look_se()
	# Natural variation: patches of tall / flowery / dry grass from low-frequency noise.
	var patchy := season in ["spring", "summer"] and Art.has("tiles", "g_tall") and Art.has("tiles", "g_dry")
	_tall.clear()
	var sd := hash(scene_id()) % 1000 + seed_v
	# Loop constants hoisted out of the per-cell loop (this runs over ~10k cells per redraw).
	var seam_name: String = {"spring": "meadow_grass", "summer": "meadow_grass", "fall": "dry_grass", "winter": "snow"}.get(season, "meadow_grass")
	var has_seam := Art.has("seamless", seam_name)
	var seam_col := Color(1, 0.93, 0.82) if season == "fall" else Color.WHITE
	var fl: Array = ["gdeco_dandelion", "gdeco_clover", "fdeco_0", "fdeco_1", "fdeco_2", "fdeco_3", "fdeco_4", "fdeco_5"]
	var noise9 := _fbm_grid(sd, 9.0)
	var nw := cols + 2 * pad
	var dry_cells: Array[Vector3i] = []
	var flower_cells: Array[Vector2i] = []
	if has_seam:
		# The base grass in whole texture repeats (8x8 cells each, clipped to r): the
		# same texels seam_cell would draw cell by cell, at ~1/64 of the calls and CPU.
		var tseam := Art.tex("seamless", seam_name)
		var area := Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE))
		var by := floorf(area.position.y / SEAM_PERIOD) * SEAM_PERIOD
		while by < area.end.y:
			var bx := floorf(area.position.x / SEAM_PERIOD) * SEAM_PERIOD
			while bx < area.end.x:
				var blk := Rect2(bx, by, SEAM_PERIOD, SEAM_PERIOD).intersection(area)
				if not Art.clipped(blk):
					draw_texture_rect_region(tseam, blk, Rect2((blk.position - Vector2(bx, by)) * 2.0, blk.size * 2.0), seam_col)
				bx += SEAM_PERIOD
			by += SEAM_PERIOD
	# A clipped painter pass walks only the cells near its chunk (every branch below
	# but the old g_tall one is per-cell, so the subset draws the same pixels).
	var lr := r
	if Art.clip.has_area() and (has_seam or (has_tiles and Art.has("tiles", "gv_short_0")) or not has_tiles):
		lr = r.intersection(clip_cells())
	for y in range(lr.position.y, lr.end.y):
		for x in range(lr.position.x, lr.end.x):
			var at := Vector2(x * TILE, y * TILE)
			var ni := (y + pad) * nw + (x + pad)
			var n9: float = noise9[ni] if x >= -pad and y >= -pad and x < cols + pad and y < rows + pad else WorldGen.fbm(float(x), float(y), sd, 9.0)
			if has_seam:
				# One texture for the whole field first (it batches into a few draw
				# calls); dry patches and flower decals go in later passes, so they
				# don't break the batch cell by cell (and aren't cut by the next cell).
				var n0 := n9
				if season == "summer" and n0 < -0.3:
					dry_cells.append(Vector3i(x, y, int(clampf((-0.3 - n0) * 4.0, 0.0, 0.8) * 1000.0)))
				elif patchy and n0 > 0.42:
					_tall[Vector2i(x, y)] = true
				elif season == "spring" and n0 < -0.4 and absi((x * 73856093) ^ (y * 19349663)) % 3 == 0:
					flower_cells.append(Vector2i(x, y))
				continue
			if has_tiles:
				var tname := gname
				var gv := Art.has("tiles", "gv_short_0")
				var hv := absi((x * 73856093) ^ (y * 19349663))
				if gv:
					var base: String = {"spring": "gv_short", "summer": "gv_short", "fall": "gv_autumn", "winter": "gv_snow"}.get(season, "gv_short")
					# Only the first four short variants: 4..11 are brighter opaque squares that grid the field.
					Art.draw_tile(self, "tiles", "%s_%d" % [base, hv % 4], at, 0)
					if patchy:
						var n := n9
						if n > 0.42:
							_tall[Vector2i(x, y)] = true
						elif n < -0.36 and hv % 3 != 0:
							# Flower drifts: thin them with the short tiles so they read as meadow, not carpet.
							Art.draw_tile(self, "tiles", "%s_%d" % ["gv_dry" if season == "summer" else "gv_flower", hv % 12], at, 0)
					continue
				if patchy:
					var n := WorldGen.fbm(float(x), float(y), sd, 11.0)
					if n > 0.32:
						tname = "g_tall"
					elif n < -0.38:
						tname = "g_dry" if season == "summer" else "g_flower"
				Art.draw_tile(self, "tiles", tname, at, 4)
				if season == "spring" and _deco_rng.randf() < 0.07 and Art.has("nature", "gdeco_dandelion"):
					Art.draw_prop(self, "nature", "gdeco_dandelion" if _deco_rng.randf() < 0.5 else "gdeco_clover", at + Vector2(8, 14))
			else:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color("5a9e4b") if (x + y) % 2 == 0 else Color("67ab55"))
	for d: Vector3i in dry_cells:
		seam_cell(self, "dry_grass", Vector2i(d.x, d.y), Color(1, 1, 1, d.z / 1000.0))
	# Flower drifts as cut-out decals with a little jitter (the old gv_flower tiles
	# were opaque squares on the grass). One pass per flower texture: picking one of
	# eight per cell broke the batch at almost every flower.
	for fi in fl.size():
		var nm: String = fl[fi]
		if not Art.has("nature", nm):
			continue
		for fc: Vector2i in flower_cells:
			var hv0 := absi((fc.x * 73856093) ^ (fc.y * 19349663))
			if hv0 % fl.size() == fi:
				Art.draw_prop(self, "nature", nm, Vector2(fc * TILE) + Vector2(8 + (hv0 >> 4) % 7 - 3, 14 + (hv0 >> 8) % 5 - 2))
	# Tall grass as cut-out tufts on top of the base grass (the gv_tall tiles were
	# opaque squares that showed as a grid of light patches).
	if not _tall.is_empty() and Art.has("nature", "gdeco_tuft_a"):
		var tufts := ["gdeco_tuft_a", "gdeco_tuft_b", "gdeco_tuft_c"]
		# One pass per tuft texture: alternating textures broke the batch on every tuft.
		for ti in 3:
			for c: Vector2i in _tall:
				var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
				var base_p := Vector2(c * TILE)
				if hv % 3 == ti:
					Art.draw_prop(self, "nature", tufts[ti], base_p + Vector2(5 + (hv >> 3) % 6, 9 + (hv >> 6) % 4))
				if hv % 3 != 0 and (hv >> 2) % 3 == ti:
					Art.draw_prop(self, "nature", tufts[ti], base_p + Vector2(10 + (hv >> 9) % 5, 15 + (hv >> 12) % 2))


## WorldGen.fbm over the whole padded map, computed once per (seed, scale) and kept.
var _fbm_cache := {}


func _fbm_grid(sd: int, scale: float) -> PackedFloat32Array:
	var key := "%d:%.1f:%d:%d:%d" % [sd, scale, cols, rows, pad]
	if _fbm_cache.has(key):
		return _fbm_cache[key]
	var w := cols + 2 * pad
	var h := rows + 2 * pad
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = WorldGen.fbm(float(x - pad), float(y - pad), sd, scale)
	_fbm_cache[key] = a
	return a


## Ground region with real grass transitions (W1 sets) when available.
## kind: "dirt" | "sand" | "stone". Falls back to draw_tileset_rect.
func draw_ground(kind: String, cells_in: Dictionary) -> void:
	var tset := "t_" + kind
	Footsteps.mark(self, widen_path(cells_in), Footsteps.path_word(kind))
	var fill: String = {"dirt": "dirt", "sand": "sand", "stone": "g_gravel"}.get(kind, "dirt")
	var blob: String = {"dirt": "path_dirt", "sand": "path_sand", "stone": "path_cobble", "cobble": "path_cobble", "snow": "path_snow"}.get(kind, "")
	# Prompts 10 clean path sets (smooth rims, seamless fills) when sliced.
	var blob2: String = {"cobble": "path2_cobble", "stone": "path2_cobble"}.get(kind, "")
	if blob2 != "" and Art.has("tiles", blob2 + "_top_0"):
		var cells2 := widen_path(cells_in)
		var hb := hash(blob2)
		for c: Vector2i in cells2:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hb)
			# One seamless paving texture inside (per-cell fill variants didn't line up at the seams).
			if not seam_cell(self, "pavement", c):
				Art.draw_tile(self, "tiles", Art.fill_name(blob2, h), Vector2(c * TILE), 0)
		# Decals in a second pass (each sits in its own cell): the paving batches unbroken.
		for c: Vector2i in cells2:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hb)
			if h % 17 == 0 and _blob_interior(cells2, c) and Art.has("tiles", "%s_deco_%d" % [blob2, h / 17 % 36]):
				Art.draw_tile(self, "tiles", "%s_deco_%d" % [blob2, h / 17 % 36], Vector2(c * TILE), 0)
		Art.draw_blob(self, cells2, blob2, 16.0, 0)
		return
	if blob != "" and Art.has("tiles", blob + "_top_0"):
		# Paths are never one cell wide: a 1-wide strip is all edge tiles and reads
		# as a chain of little boxes. Widen to 2 so there is a real middle.
		var cells := widen_path(cells_in)
		# Dirt and sand paths: one soft, wobbly-edged shape instead of square cells.
		if kind in ["dirt", "sand"] and scene_id() != "beach" and soft_ground(cells, "dirt_track" if kind == "dirt" else "sand", Color(0.25, 0.15, 0.06, 0.3 if kind == "dirt" else 0.0)):
			return
		# Plain fill under everything (the blob set's fill variants are mostly
		# decals: pebbles, puddles, ruts) with an occasional decal, then edges.
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hash(blob))
			var plain := ""
			var seam_p: String = {"dirt": "dirt_track", "sand": "sand"}.get(kind, "")
			if seam_p != "" and seam_cell(self, seam_p, c):
				continue
			match kind:
				"dirt": plain = "path_dirt_fill_%d" % (7 + h % 5)
				"sand": plain = Art.fill_name("sand", h) if Art.has("tiles", "sand_fill_0") else "sand"
				"stone", "cobble": plain = "cobble_a" if Art.has("tiles", "cobble_a") else "g_gravel"
				_: plain = fill
			Art.draw_tile(self, "tiles", plain, Vector2(c * TILE), 0)
			if kind == "dirt" and h % 13 == 0 and _blob_interior(cells, c):
				Art.draw_tile(self, "tiles", "path_dirt_fill_%d" % (h / 13 % 7), Vector2(c * TILE), 0)
		if kind == "dirt" or kind == "sand":
			# Soft procedural rim instead of the scalloped edge tiles: a worn,
			# slightly darker lip on the path side and a thin grass shadow outside,
			# with rounded outer corners. Reads as a trodden path, no boxes.
			_draw_soft_rim(cells, Color(0.25, 0.15, 0.06, 0.28), Color(0.1, 0.2, 0.05, 0.22))
			return
		Art.draw_blob(self, cells, blob, 16.0, 0)
		return
	if Art.has("tiles", tset):
		Art.draw_autotile(self, cells_in, "@", tset, Art.T_GROUND_IDX)
		if kind == "dirt" and Art.has("tiles", "pdeco_pebbles"):
			for c: Vector2i in cells_in:
				var h := (c.x * 73856093) ^ (c.y * 19349663) ^ hash(scene_id())
				if h % 23 == 0:
					Art.draw_tile(self, "tiles", ["pdeco_pebbles", "pdeco_puddle", "pdeco_hoofprints", "pdeco_ruts", "pdeco_roots"][absi(h / 23) % 5], Vector2(c * TILE))
		return
	for c: Vector2i in cells_in:
		if not Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("b8945a"))


func _draw_soft_rim(cells: Dictionary, inner: Color, outer: Color) -> void:
	for c: Vector2i in cells:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		if not n:
			draw_rect(Rect2(r.position, Vector2(TILE, 2)), inner)
			draw_rect(Rect2(r.position + Vector2(0, -1), Vector2(TILE, 1)), outer)
		if not so:
			draw_rect(Rect2(r.position + Vector2(0, TILE - 2), Vector2(TILE, 2)), inner)
			draw_rect(Rect2(r.position + Vector2(0, TILE), Vector2(TILE, 1)), outer)
		if not w:
			draw_rect(Rect2(r.position, Vector2(2, TILE)), inner)
			draw_rect(Rect2(r.position + Vector2(-1, 0), Vector2(1, TILE)), outer)
		if not e:
			draw_rect(Rect2(r.position + Vector2(TILE - 2, 0), Vector2(2, TILE)), inner)
			draw_rect(Rect2(r.position + Vector2(TILE, 0), Vector2(1, TILE)), outer)
		# Outer corners: knock a little triangle of grass back in so corners round off.
		var grass := Color(0.36, 0.62, 0.27, 0.9)
		if not n and not w:
			draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(4, 0), r.position + Vector2(0, 4)]), grass)
		if not n and not e:
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(TILE, 0), r.position + Vector2(TILE - 4, 0), r.position + Vector2(TILE, 4)]), grass)
		if not so and not w:
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, TILE), r.position + Vector2(4, TILE), r.position + Vector2(0, TILE - 4)]), grass)
		if not so and not e:
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(TILE, TILE), r.position + Vector2(TILE - 4, TILE), r.position + Vector2(TILE, TILE - 4)]), grass)


## 1-wide runs become 2-wide (adds the right / lower neighbour), corners filled.
static func widen_path(cells: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in cells:
		out[c] = true
	for c: Vector2i in cells:
		var lr := cells.has(c + Vector2i(-1, 0)) or cells.has(c + Vector2i(1, 0))
		var ud := cells.has(c + Vector2i(0, -1)) or cells.has(c + Vector2i(0, 1))
		if ud and not lr:
			out[c + Vector2i(1, 0)] = true
		elif lr and not ud:
			out[c + Vector2i(0, 1)] = true
		elif not lr and not ud:
			out[c + Vector2i(1, 0)] = true
			out[c + Vector2i(0, 1)] = true
			out[c + Vector2i(1, 1)] = true
	# Fill single-cell notches so edges stay smooth.
	var add := {}
	for c: Vector2i in out:
		for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var k := c + d
			if not out.has(k) and out.has(c + Vector2i(d.x, 0)) and out.has(c + Vector2i(0, d.y)):
				add[k] = true
	for k: Vector2i in add:
		out[k] = true
	return out


static func _blob_interior(cells: Dictionary, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not cells.has(c + d):
			return false
	return true


func cells_of(rects: Array) -> Dictionary:
	var d := {}
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				d[Vector2i(x, y)] = true
	return d


## Water body with proper shore edges (grass or sand outside) and animated fill.
var _water_masks := {}  # shape key -> WaterMask (one shader rect per water body)


func draw_water(cells: Dictionary, shore := "grass") -> void:
	# The soft shoreline: one shader rect per body of water (curved, noisy edge,
	# moving water, foam and bank), made once and kept.
	if _water_mask(cells, shore):
		return
	# Water is the only thing that animates on the ground, so it lives on its own
	# layer that redraws every frame; the rest of the map is drawn once.
	# Which cells are on the edge never changes: work it out once, not per frame.
	var edges := {}
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not cells.has(c + d):
				edges[c] = true
				break
	if _anim_layer:
		_anim_layer.jobs.append(func(ci: CanvasItem) -> void: _draw_water_on(ci, _on_screen(cells), shore, _on_screen(edges), cells))
	else:
		_draw_water_on(self, cells, shore, edges, cells)


## The part of a cell set inside the anim layer's view.
func _on_screen(cells: Dictionary) -> Dictionary:
	if _anim_layer == null:
		return cells
	var v := _anim_layer.view
	if v.size.x * v.size.y >= cells.size():
		var out := {}
		for c: Vector2i in cells:
			if v.has_point(c):
				out[c] = true
		return out
	var out2 := {}
	for y in range(v.position.y, v.end.y):
		for x in range(v.position.x, v.end.x):
			var c := Vector2i(x, y)
			if cells.has(c):
				out2[c] = true
	return out2


func _draw_water_on(ci: CanvasItem, cells: Dictionary, shore: String, edge_cells: Dictionary = {}, all_cells: Dictionary = {}) -> void:
	if all_cells.is_empty():
		all_cells = cells
	# Animated fill, then a procedural bank that always lines up: a dark earth
	# lip on the land side, a lighter wet rim and foam inside the water. Corners
	# are rounded with quarter discs so blobs read as real shorelines.
	var frame := int(Time.get_ticks_msec() / 250) % 4
	var fill := "water2" if Art.has("tiles", "water2") else "water"
	var seam: String = {"bog": "bog_water", "river": "river", "sand": "sea", "lava": "lava"}.get(shore, "lake_shallow")
	if Art.has("seamless", seam):
		# Two copies of the seamless water drifting past each other read as moving water.
		var tt := Time.get_ticks_msec() / 1000.0
		var drift := Vector2(tt * 3.0, tt * 1.2) if seam != "river" else Vector2(tt * 9.0, 0.0)
		for c: Vector2i in cells:
			seam_cell(ci, seam, c, Color.WHITE, drift)
			seam_cell(ci, seam, c, Color(1, 1, 1, 0.35), Vector2(-drift.y * 1.7 + 40.0, drift.x * 0.6 + 70.0))
		if shore in ["bog", "river", "cave"]:
			if shore == "cave":
				for c: Vector2i in cells:
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if not all_cells.has(c + d):
							var rr := Rect2(c * TILE, Vector2i(TILE, TILE))
							var edge_r := {Vector2i(0, -1): Rect2(rr.position, Vector2(TILE, 2)), Vector2i(0, 1): Rect2(rr.position + Vector2(0, TILE - 2), Vector2(TILE, 2)), Vector2i(-1, 0): Rect2(rr.position, Vector2(2, TILE)), Vector2i(1, 0): Rect2(rr.position + Vector2(TILE - 2, 0), Vector2(2, TILE))}
							ci.draw_rect(edge_r[d], Color(0.85, 0.95, 1.0, 0.45))
			return  # the painted bog/river edge sets go on top below otherwise; seamless already reads as water
	else:
		for c: Vector2i in cells:
			if not Art.draw_tile(ci, "tiles", fill, Vector2(c * TILE), frame):
				ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("2f6fb5"))
	var custom := shore in ["bog", "river"] and Art.has("tiles", shore + "_top_0")
	if custom:
		# Region water set (Prompts 09): its own fills (animated for the river) and edges.
		var fc := 42
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			var idx := h % fc
			if shore == "river":
				idx = (h % 12) + (frame if h % 12 < 12 else 0)  # current tiles 12-15 animate
				if h % 5 == 0:
					idx = 12 + frame
			Art.draw_tile(ci, "tiles", Art.fill_name(shore, h), Vector2(c * TILE), 0)
			if shore == "bog":
				ci.draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.3, 0.42, 0.22, 0.28))
	if (custom or Art.has("tiles", "shore_grass_top_0")) and shore not in ["bog", "river"]:
		# Painted 47-tile shore set. Edges only: keep the animated fill underneath.
		_draw_blob_edges(ci, all_cells, edge_cells, shore if custom else ("shore_grass" if shore == "grass" else "shore_sand"))
		return
	var earth := Color("6b4a2b") if shore == "grass" else Color("c9a86b")
	var rim := Color("4f8fd0", 0.9)
	var foam := Color(0.85, 0.95, 1.0, 0.55 + 0.2 * sin(Time.get_ticks_msec() / 400.0))
	for c: Vector2i in edge_cells if not edge_cells.is_empty() else cells:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		var n := all_cells.has(c + Vector2i(0, -1))
		var so := all_cells.has(c + Vector2i(0, 1))
		var w := all_cells.has(c + Vector2i(-1, 0))
		var e := all_cells.has(c + Vector2i(1, 0))
		if not n:
			ci.draw_rect(Rect2(r.position, Vector2(TILE, 3)), earth)
			ci.draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(TILE, 2)), rim)
			ci.draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(TILE, 1)), foam)
		if not so:
			ci.draw_rect(Rect2(r.position + Vector2(0, TILE - 2), Vector2(TILE, 2)), earth)
			ci.draw_rect(Rect2(r.position + Vector2(0, TILE - 4), Vector2(TILE, 2)), rim)
			ci.draw_rect(Rect2(r.position + Vector2(0, TILE - 5), Vector2(TILE, 1)), foam)
		if not w:
			ci.draw_rect(Rect2(r.position, Vector2(2, TILE)), earth)
			ci.draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(2, TILE)), rim)
			ci.draw_rect(Rect2(r.position + Vector2(4, 0), Vector2(1, TILE)), foam)
		if not e:
			ci.draw_rect(Rect2(r.position + Vector2(TILE - 2, 0), Vector2(2, TILE)), earth)
			ci.draw_rect(Rect2(r.position + Vector2(TILE - 4, 0), Vector2(2, TILE)), rim)
			ci.draw_rect(Rect2(r.position + Vector2(TILE - 5, 0), Vector2(1, TILE)), foam)
		# Outer corners: round them off with a land disc.
		var land := Color(str(GameState.run.get("_land", "")), 1.0) if false else (Color("5a9e4b") if shore == "grass" else Color("e2cf96"))
		if Art.has("tiles", GameState.grass_tile()) and shore == "grass":
			land = Color("55a04a")
		for corner: Array in [[not n and not w, Vector2(0, 0)], [not n and not e, Vector2(TILE, 0)], [not so and not w, Vector2(0, TILE)], [not so and not e, Vector2(TILE, TILE)]]:
			if corner[0]:
				var cp: Vector2 = r.position + corner[1]
				ci.draw_circle(cp, 6.0, land)
				ci.draw_arc(cp, 5.0, 0, TAU, 12, earth, 2.5)
				ci.draw_arc(cp, 7.5, 0, TAU, 12, rim, 1.5)
		# Inner corners: a dab of earth where two banks meet diagonally.
		for corner: Array in [[n and w and not cells.has(c + Vector2i(-1, -1)), Vector2(0, 0)], [n and e and not cells.has(c + Vector2i(1, -1)), Vector2(TILE, 0)], [so and w and not cells.has(c + Vector2i(-1, 1)), Vector2(0, TILE)], [so and e and not cells.has(c + Vector2i(1, 1)), Vector2(TILE, TILE)]]:
			if corner[0]:
				var cp: Vector2 = r.position + corner[1]
				ci.draw_circle(cp, 3.0, earth)
				ci.draw_circle(cp, 1.5, rim)


const WATER_LOOK := {
	"grass": {"seam": "lake_shallow", "bank": Color(0.40, 0.29, 0.17, 0.85), "deep": "lake_deep"},
	"river": {"seam": "river", "bank": Color(0.38, 0.28, 0.17, 0.9), "drift": Vector2(0.0, 9.0)},
	"bog": {"seam": "bog_water", "bank": Color(0.22, 0.18, 0.11, 0.9), "foam": Color(0.55, 0.62, 0.4, 0.25)},
	"sand": {"seam": "sea", "bank": Color(0.80, 0.70, 0.50, 0.75), "foam": Color(1.0, 1.0, 1.0, 0.95), "drift": Vector2(4.0, 1.5)},
	"quay": {"seam": "sea", "bank": Color(0.10, 0.08, 0.06, 0.55), "foam": Color(1, 1, 1, 0.3), "drift": Vector2(4.0, 1.5)},
	"cave": {"seam": "lake_shallow", "bank": Color(0.12, 0.1, 0.14, 0.75), "tint": Color(0.5, 0.62, 0.78), "foam": Color(0.8, 0.9, 1.0, 0.3)},
	"lava": {"seam": "lava", "bank": Color(0.12, 0.08, 0.06, 0.9), "foam": Color(1.0, 0.75, 0.3, 0.6), "drift": Vector2(1.0, 0.5)},
}


func _water_mask(cells: Dictionary, shore: String) -> bool:
	if cells.is_empty():
		return false
	var look: Dictionary = WATER_LOOK.get(shore, WATER_LOOK["grass"])
	if not Art.has("seamless", str(look["seam"])):
		return false
	var key := "%s:%d:%d" % [shore, cells.size(), cells.hash()]
	if _water_masks.has(key):
		return true
	var opts := {"bank": look["bank"]}
	if GameState.look_se() == "winter" and shore in ["grass", "river"]:
		opts["bank"] = Color(0.9, 0.93, 0.98, 0.9)
		opts["tint"] = Color(0.78, 0.86, 1.0)
	for k in ["foam", "tint", "drift"]:
		if look.has(k) and not opts.has(k):
			opts[k] = look[k]
	if look.has("deep") and Art.has("seamless", str(look["deep"])):
		opts["deep_tex"] = Art.tex("seamless", str(look["deep"]))
		opts["deep_amt"] = 0.55
	var host: GameMap = _painter_of if _painter_of != null else self
	var wm := WaterMask.make(host, cells, str(look["seam"]), opts, true)
	if wm == null:
		return false
	_water_masks[key] = wm
	host._add_under.call_deferred(wm)
	return true


## A patch of one ground drawn over another with a soft, noisy edge (same
## shader as the water, standing still, no foam, a faint worn lip outside).
func soft_ground(cells: Dictionary, seam: String, lip := Color(0.2, 0.14, 0.07, 0.28), tint := Color.WHITE) -> bool:
	if cells.is_empty():
		return false
	var gw_host: GameMap = _painter_of if _painter_of != null else self
	var gw := "sand" if "sand" in seam else ("stone" if ("ruin" in seam or "stone" in seam or "cobble" in seam or "pave" in seam) else ("grass" if ("grass" in seam or "moss" in seam) else "dirt"))
	var sw := Footsteps.seam_word(seam)
	for gc in cells:
		gw_host.ground_word[gc] = gw
		gw_host.step_word[gc] = sw
		gw_host.ground_seam[gc] = seam
	if not Art.has("seamless", seam):
		return false
	var key := "g:%s:%d:%d" % [seam, cells.size(), cells.hash()]
	if _water_masks.has(key):
		return true
	var host: GameMap = _painter_of if _painter_of != null else self
	var wm := WaterMask.make(host, cells, seam, {"drift": Vector2.ZERO, "foam": Color(1, 1, 1, 0.0), "bank": lip, "tint": tint, "wobble": 0.3, "soft": 0.09})
	if wm == null:
		return false
	wm.set_meta("under_rank", 0)
	_water_masks[key] = wm
	if _painter_of != null and BAKE_SOFT_GROUND:
		# Standing ground patches don't move: draw them into the baked chunks
		# (the painter's own child, over its drawing) instead of shading a
		# map-sized rect every frame.
		add_child.call_deferred(wm)
		return true
	host._add_under.call_deferred(wm)
	return true


## Ground-level layers go right after the anim layer: above the ground, below
## docks, props and people (y-sort ties fall back to tree order).
## Flat things that lie on the ground (decals, pools, pads): above the ground
## drawing, below everything that stands. (z_index -1 would hide them under the map.)
var _under_layer: Node2D


func under_layer() -> Node2D:
	if _painter_of != null:
		return _painter_of.under_layer()
	if _under_layer == null or not is_instance_valid(_under_layer):
		_under_layer = Node2D.new()
		_under_layer.name = "UnderLayer"
		# Sort just after the water and path layers (which sit at the content offset).
		_under_layer.position = Vector2(0, offset().y + 0.5)
		_under_layer.set_meta("under_rank", 2)
		_add_under(_under_layer)
	return _under_layer


func to_under(n: Node2D) -> void:
	if n == null:
		return
	n.z_index = 0
	if n.get_parent():
		n.reparent(under_layer())
	else:
		n.position -= under_layer().position  # given in map coordinates
		under_layer().add_child(n)


var _under_nodes: Array = []

## Ground-level nodes go right above the anim layer: ground patches, then
## water bodies, then the under layer (decals); same rank keeps call order.
func _add_under(n: Node) -> void:
	if _painter_of != null:
		_painter_of._add_under(n)
		return
	add_child(n)
	if not (_anim_layer and _anim_layer.get_parent() == self):
		return
	var rank := int(n.get_meta("under_rank", 1))
	var at := _anim_layer.get_index() + 1
	_under_nodes = _under_nodes.filter(func(x): return is_instance_valid(x) and x.get_parent() == self and x != n)
	for x in _under_nodes:
		if int(x.get_meta("under_rank", 1)) <= rank:
			at = maxi(at, x.get_index() + 1)
	move_child(n, at)
	_under_nodes.append(n)


## A rectangle of a 3x3 tile set (dirt, stone, dock...) with proper edges.
func draw_tileset_rect(name: String, r: Rect2i, fallback: Color) -> void:
	if not Art.has("tiles", name):
		draw_rect(Rect2(r.position * TILE, r.size * TILE), fallback)
		return
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ix := 1
			var iy := 1
			if r.size.x > 1:
				ix = 0 if x == r.position.x else (2 if x == r.end.x - 1 else 1)
			if r.size.y > 1:
				iy = 0 if y == r.position.y else (2 if y == r.end.y - 1 else 1)
			Art.draw_tile(self, "tiles", name, Vector2(x * TILE, y * TILE), iy * 3 + ix)


## gap_e: rows (keyed by y + 1, the post's foot) where the east fence is left open for a road.
func draw_fence_border(col := Color("6b4a2b"), gap_e := {}) -> void:
	if Art.has("buildings", "fence_h"):
		for x in cols:
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, TILE))
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, rows * TILE))
		for y in range(1, rows - 1):
			Art.draw_prop(self, "buildings", "fence_v", Vector2(TILE / 2.0, (y + 1) * TILE))
			if not gap_e.has(y + 1):
				Art.draw_prop(self, "buildings", "fence_v", Vector2((cols - 0.5) * TILE, (y + 1) * TILE))
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(cols * TILE, TILE)), col)
	draw_rect(Rect2(0, (rows - 1) * TILE, cols * TILE, TILE), col)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, rows * TILE)), col)
	draw_rect(Rect2((cols - 1) * TILE, 0, TILE, rows * TILE), col)


func draw_tree(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 2, p.y - 4, 4, 6), Color("5a3a1a"))
	draw_circle(Vector2(p.x, p.y - 10), 8.0, Color("2f7a3a"))
	draw_circle(Vector2(p.x - 3, p.y - 13), 5.0, Color("3f9a48"))


func draw_building(x: int, y: int, w: int, h: int, wall: Color, roof: Color, label_text: String) -> void:
	draw_rect(Rect2(x * TILE, (y + 1) * TILE, w * TILE, (h - 1) * TILE), wall)
	draw_rect(Rect2(x * TILE - 4, y * TILE, w * TILE + 8, TILE * 1.5), roof)
	var dx := (x + w / 2.0) * TILE - TILE / 2.0
	draw_rect(Rect2(dx, (y + h - 1) * TILE, TILE, TILE), Color("3a2412"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x * TILE, (y + 1.3) * TILE), label_text, HORIZONTAL_ALIGNMENT_CENTER, w * TILE, 7, Color(1, 1, 0.85))


func label(text: String, at: Vector2, w := 64.0) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, 7, Color(1, 1, 0.85))


## Raised ground with a real cliff face under its southern edge (W28/W29 sets).
## `cells` are the walkable top cells; the row below the southern edge is the face
## (block it yourself, except `stairs` cells). prefix: "cliffg" (grass) or "cliffs" (stone).
## Which painted cliff and stair set this map uses (Prompts 16).
func cliff_style() -> Array:
	var sc := scene_id()
	if sc in ["mountain", "highlands"] or sc == "colony_ice" or sc == "bf_frostfield":
		return ["snow", "stair_snow"]
	if sc in ["wastes", "beach", "colony_ember"]:
		return ["sand", "stair_wood"]
	if sc.begins_with("colony_") or sc == "quarry":
		# Grassy tops: grass faces (a sand fringe read as a yellow outline on green).
		return ["grass", "stair_wood"]
	if sc in ["hideout", "docks", "neon", "uptown", "underground", "bf_rail_yards", "bf_dockside"]:
		return ["grass", "stair_iron"]
	if sc in ["crystal_meadow", "bf_shattered_vale", "hollow_heart"]:
		return ["grass", "stair_crystal"]
	return ["grass", "stair_stone"]


## Big one-piece cliff faces and stair sets, when the art is in: organic outline
## (rounded corners, smooth slopes on stepped edges), painted faces on the front,
## rock side walls, rims in the ground's own colour (CliffPainter).
func _draw_plateau_painted(cells: Dictionary, stairs: Dictionary) -> bool:
	var st := cliff_style()
	if Art.tex("cliffs", str(st[0]) + "_strip") == null or not Art.has("stairs", str(st[1])):
		return false
	return CliffPainter.draw(self, cells, stairs, {"style": str(st[0]), "stair_set": str(st[1])})


func draw_plateau(cells: Dictionary, prefix := "cliffg", stairs: Dictionary = {}) -> void:
	if prefix == "cliffg" and _draw_plateau_painted(cells, stairs):
		return
	var tset := "t_" + prefix
	if Art.has("tiles", "cliff_top_0") and prefix == "cliffg":
		Art.draw_blob(self, cells, "cliff", 16.0, 1)
		# A real rock face under every southern edge (the blocked ledge row), and
		# proper stair tiles cut into it where you can climb.
		var n_up := 0
		while Art.has("tiles", "cliff2g_upper_%d" % n_up):
			n_up += 1
		for c: Vector2i in cells:
			var below := c + Vector2i(0, 1)
			if cells.has(below) or stairs.has(below):
				continue
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			if n_up > 0:
				# Two-row painted face (Prompts 10): upper row over the ledge cell, lower row under it.
				Art.draw_tile(self, "tiles", "cliff2g_upper_%d" % (h % n_up), Vector2(below * TILE), 0)
				if Art.has("tiles", "cliff2g_lower_%d" % (h % n_up)) and not cells.has(below + Vector2i(0, 1)):
					Art.draw_tile(self, "tiles", "cliff2g_lower_%d" % (h % n_up), Vector2((below + Vector2i(0, 1)) * TILE), 0)
				continue
			var face := Art.tex("tiles", "cliffg_" + ["face_a", "face_b", "face_c"][absi(c.x * 7 + c.y) % 3])
			if face:
				draw_texture_rect(face, Rect2(below.x * TILE, below.y * TILE - TILE * 0.5, TILE, TILE * 1.5), false)
			else:
				draw_rect(Rect2(below.x * TILE, below.y * TILE, TILE, TILE), Color("5a4634"))
		for below: Vector2i in stairs:
			var l := not stairs.has(below + Vector2i(-1, 0))
			var r := not stairs.has(below + Vector2i(1, 0))
			# Dirt ramps (they continue a path); stone steps if the set has no ramps.
			var kind := "ramp" if Art.has("tiles", "cliff_ramp_m") else "stairs"
			if Art.has("tiles", "cliff2_ramp_m"):
				var nm2 := "cliff2_ramp_m"
				if l and r:
					nm2 = "cliff2_ramp_s"
				elif l:
					nm2 = "cliff2_ramp_l"
				elif r:
					nm2 = "cliff2_ramp_r"
				var t2 := Art.tex("tiles", nm2)
				if t2:
					draw_texture_rect(t2, Rect2(below.x * TILE, below.y * TILE, TILE, TILE * 2), false)
					# The lower face row under a ramp is the ramp's foot: keep it clear.
					continue
			var nm := "cliff_%s_m" % kind
			if l and r:
				nm = "cliff_%s_w" % kind if Art.has("tiles", "cliff_%s_w" % kind) else "cliff_%s_m" % kind
			elif l:
				nm = "cliff_%s_l" % kind
			elif r:
				nm = "cliff_%s_r" % kind
			var t := Art.tex("tiles", nm) if Art.has("tiles", nm) else Art.tex("tiles", "cliff_stairs_m")
			if t:
				draw_texture_rect(t, Rect2(below.x * TILE, below.y * TILE - TILE * 0.5, TILE, TILE * 1.5), false)
		return
	if not Art.has("tiles", tset):
		for c: Vector2i in cells:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("6a6a74"))
		return
	# The sets are drawn as raised blocks: plain grass inside, a rock lip on the
	# side that faces open ground. Pick the tile from which neighbours are missing.
	var I := Art.T_CLIFF_IDX
	for c: Vector2i in cells:
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		var key := "mid"
		if not so:
			key = "bl" if not w else ("br" if not e else "bottom")
		elif not n:
			key = "tl" if not w else ("tr" if not e else "top")
		elif not w:
			key = "left"
		elif not e:
			key = "right"
		Art.draw_tile(self, "tiles", tset, Vector2(c * TILE), int(I[key]))
	if prefix != "cliffg":
		return
	var faces := []
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)):
			faces.append(c)
	faces.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in faces:
		var below := c + Vector2i(0, 1)
		var has_l := cells.has(c + Vector2i(-1, 0)) and not cells.has(c + Vector2i(-1, 1))
		var has_r := cells.has(c + Vector2i(1, 0)) and not cells.has(c + Vector2i(1, 1))
		var nm := ""
		if stairs.has(below):
			var sl := stairs.has(below + Vector2i(-1, 0))
			var sr := stairs.has(below + Vector2i(1, 0))
			nm = "stairs_m" if (sl and sr) or (not sl and not sr) else ("stairs_r" if sl else "stairs_l")
		elif has_l and has_r:
			nm = ["face_a", "face_b", "face_c"][(c.x * 7 + c.y) % 3]
		elif not has_l and not has_r:
			nm = "fcorner_l"
		else:
			nm = "face_l" if not has_l else "face_r"
		var t := Art.tex("tiles", prefix + "_" + nm)
		if t:
			draw_texture_rect(t, Rect2(below.x * TILE, c.y * TILE + TILE * 0.5, TILE, TILE * 1.5), false)


## Draw blob tiles for `edge_cells` using neighbourhood from the full `cells` set.
func _draw_blob_edges(ci: CanvasItem, cells: Dictionary, edge_cells: Dictionary, set_name: String) -> void:
	for c: Vector2i in edge_cells:
		var sub := {}
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if cells.has(n):
					sub[n] = true
		# draw_blob on a 3x3 window: only c itself is drawn (others are context)
		var one := {c: true}
		for k: Vector2i in sub:
			if k != c:
				one[k] = true
		# cheap: call draw_blob with the window but mask drawing to c via a tiny trick:
		Art.draw_blob_cell(ci, sub, c, set_name)


## A mass of raised rock (map edges, mountain walls): stone fill with a grassy
## lip facing the open ground and painted cliff faces on the sides that face south.
## A cliff border band as raised wooded ground: the map's own ground on top (it is
## drawn under the band), an organic painted face along its inner edge (inside the
## band, so the face never hangs over walkable cells), rock side walls, shade
## deepening outward and a few boulders and shrubs on the top.
func _draw_band_cliff(cells: Dictionary) -> bool:
	var st := cliff_style()
	if Art.tex("cliffs", str(st[0]) + "_strip") == null:
		return false
	# Shade: the deeper into the band, the darker (no hard line at the pad edge).
	for c: Vector2i in cells:
		var dd := _band_depth(c)
		if dd >= 2:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.04, 0.05, 0.08, minf(0.32, 0.07 * dd)))
	# Face along the inner edge: drawn on the band's own last row.
	if not CliffPainter.draw(self, cells, {}, {"style": str(st[0]), "skip_rect": Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad), "inset": true}):
		return false
	# Top dressing: boulders, shrubs and ferns, deterministic per cell.
	var se := GameState.look_se()
	var pool: Array = ["rock_m", "bush", "ferns", "rock_s", "rock_l"]
	if se == "winter":
		pool = ["rock_snow_l", "bush_snow", "rock_s", "rock_m"]
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)) or _band_depth(c) < 2:
			continue
		var h := absi((c.x * 73856093) ^ (c.y * 19349663)) % 100
		if h < 14:
			var nm: String = pool[h % pool.size()]
			if Art.has("nature", nm):
				Art.draw_prop(self, "nature", nm, Vector2(c * TILE) + Vector2(TILE / 2.0, TILE - 2))
	return true


func draw_rock_mass(cells: Dictionary) -> void:
	var wall: String = {"marsh": "wall_marsh", "highlands": "wall_highlands", "ruins": "wall_ruins", "quarry": "wall_ruins", "riverlands": "wall_river", "hollow_heart": "mine_heart_wall"}.get(scene_id(), "")
	if wall != "" and Art.has("tiles", wall + "_0"):
		# Region-themed border wall (Prompts 10): the inner edge of the band is a
		# two-tile-tall wall facing the player; deeper cells are plain dark fill.
		var n := 0
		while Art.has("tiles", "%s_%d" % [wall, n]):
			n += 1
		var wfill := "mf_stone" if Art.has("tiles", "mf_stone") else "g_gravel"
		var crystal := scene_id() == "hollow_heart" and Art.has("seamless", "cave_crystal_rock")
		for c: Vector2i in cells:
			# Dark rock mass behind the wall, not a black hole.
			if crystal and seam_cell(self, "cave_crystal_rock", c):
				pass  # blue crystal rock behind the Hollow Heart's crystal band, not a grey slab
			elif not Art.draw_tile(self, "tiles", wfill, Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.3, 0.29, 0.32))
		# The shade in its own pass: a plain rect after every textured cell broke the
		# batch twice per cell (hollow_heart: ~4000 draw calls per chunk bake).
		for c: Vector2i in cells:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.05, 0.04, 0.08, 0.2))
		# Wall faces grouped by texture (they never overlap: a face sits on the cell
		# above it, which is band fill with no face of its own).
		var faces := {}
		for c: Vector2i in cells:
			var below := c + Vector2i(0, 1)
			if cells.has(below):
				continue
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			(faces.get_or_add(h % n, []) as Array).append(c)
		for fi: int in faces:
			var t := Art.tex("tiles", "%s_%d" % [wall, fi])
			if t:
				for c: Vector2i in faces[fi]:
					draw_texture_rect(t, Rect2(c.x * TILE, c.y * TILE - TILE, TILE, TILE * 2), false)
		# side walls: cells with open land to the left/right get an end cap
		for c: Vector2i in cells:
			for side: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0)]:
				var nb := c + side
				if cells.has(nb) or not in_content(nb) or cells.has(c + Vector2i(0, 1)) == false:
					continue
				var cap := Art.tex("tiles", wall + ("_end_r" if side.x < 0 else "_end_l"))
				if cap:
					draw_texture_rect(cap, Rect2(c.x * TILE, c.y * TILE - TILE, TILE, TILE * 2), false)
		return
	var stone_band := scene_id() in ["neon", "uptown", "docks", "hideout", "countryside", "moon", "wastes", "hollow_heart"]
	if not stone_band and _draw_band_cliff(cells):
		return
	if Art.has("tiles", "cliff_top_0"):
		# Raised rock plateau with real edges on every side (W28 cliff set), so a
		# blocked cliff band always reads as a wall, never as floor.
		var fill := "mf_stone" if Art.has("tiles", "mf_stone") else "g_gravel"
		# (No rdeco_quarry "decals" here: they are opaque tan ground tiles and showed as boxes in the rock.)
		for c: Vector2i in cells:
			Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4)
		var cset := "cliff_stone" if stone_band and Art.has("tiles", "cliff_stone_top_0") else "cliff"
		Art.draw_blob(self, cells, cset, 16.0, 1)
		return
	var fill := "mf_stone" if Art.has("tiles", "mf_stone") else "g_gravel"
	for c: Vector2i in cells:
		if not Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4):
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color("6a6a74"))
		# subtle variation
		if (c.x * 31 + c.y * 17) % 5 == 0:
			draw_rect(Rect2(c * TILE + Vector2i(3, 4), Vector2i(6, 3)), Color(1, 1, 1, 0.08))
	var dark := Color("2e2a33")
	var grass := Color("55a04a")
	for c: Vector2i in cells:
		var r := Rect2(c * TILE, Vector2i(TILE, TILE))
		var n := cells.has(c + Vector2i(0, -1))
		var so := cells.has(c + Vector2i(0, 1))
		var w := cells.has(c + Vector2i(-1, 0))
		var e := cells.has(c + Vector2i(1, 0))
		if not so:
			# Face toward the player: painted face tile over the row below.
			var face := Art.tex("tiles", "cliffg_" + ["face_a", "face_b", "face_c"][(c.x * 7 + c.y) % 3])
			if face:
				draw_texture_rect(face, Rect2(r.position + Vector2(0, TILE * 0.4), Vector2(TILE, TILE * 1.6)), false)
			else:
				draw_rect(Rect2(r.position + Vector2(0, TILE - 4), Vector2(TILE, 4)), dark)
		if not n:
			draw_rect(Rect2(r.position, Vector2(TILE, 3)), grass)
			draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(TILE, 1)), dark)
		if not w:
			draw_rect(Rect2(r.position, Vector2(3, TILE)), grass)
			draw_rect(Rect2(r.position + Vector2(3, 0), Vector2(1, TILE)), dark)
		if not e:
			draw_rect(Rect2(r.position + Vector2(TILE - 3, 0), Vector2(3, TILE)), grass)
			draw_rect(Rect2(r.position + Vector2(TILE - 4, 0), Vector2(1, TILE)), dark)
		for corner: Array in [[not n and not w, Vector2(0, 0)], [not n and not e, Vector2(TILE, 0)]]:
			if corner[0]:
				draw_circle(r.position + corner[1], 4.0, grass)
	# A few boulders on top for texture.
	for c: Vector2i in cells:
		if (c.x * 7 + c.y * 13) % 11 == 0 and cells.has(c + Vector2i(0, 1)) and cells.has(c + Vector2i(0, -1)):
			Art.draw_prop(self, "props" if Art.has("props", "boulder2_s_a") else "nature", "boulder2_s_a" if Art.has("props", "boulder2_s_a") else "rock_s", Vector2(c * TILE) + Vector2(8, 15))


# ---- organic borders ---------------------------------------------------------

## The cells of an exit strip a path actually runs through (maps with paths
## override; Rect2i() = the whole strip).
func exit_lanes(_r: Rect2i) -> Rect2i:
	return Rect2i()


func border_kind(side: String) -> String:
	if border is Dictionary:
		return str((border as Dictionary).get(side, "trees"))
	return str(border)


## Which side of the content a pad cell belongs to (nearest edge).
func _side_of(c: Vector2i) -> String:
	var dn := -c.y
	var ds := c.y - (rows - 1)
	var dw := -c.x
	var de := c.x - (cols - 1)
	var m := maxi(maxi(dn, ds), maxi(dw, de))
	if m == dn: return "n"
	if m == ds: return "s"
	if m == dw: return "w"
	return "e"


func _build_border() -> void:
	_border_rng.seed = hash(scene_id()) % 100000
	var sd := hash(scene_id()) % 10000
	# Exit corridors: cells in line with an exit stay open through the band.
	var open := {}
	for e in exits:
		var r: Rect2i = e["rect"]
		var g := r.grow(1)
		# Void edges (sky islands, space): open only the path's own lanes, no shoulder,
		# so the road leaves the island without a wide notch (CONDUCT 4).
		var lanes := exit_lanes(r)
		if lanes.size.x > 0 and border_kind(_side_of(r.get_center())) == "none":
			g = lanes
		# Same cells as testing every map cell: each case needs x inside g's columns
		# (north/south exits) or y inside g's rows (west/east exits).
		for y in range(-pad, rows + pad):
			for x in range(maxi(g.position.x, -pad), mini(g.end.x, cols + pad)):
				if (r.position.y <= 0 and y < r.end.y) or (r.end.y >= rows and y >= r.position.y):
					open[Vector2i(x, y)] = true
		for y in range(maxi(g.position.y, -pad), mini(g.end.y, rows + pad)):
			for x in range(-pad, cols + pad):
				if (r.position.x <= 0 and x < r.end.x) or (r.end.x >= cols and x >= r.position.x):
					open[Vector2i(x, y)] = true
	_border_open = open
	# Meandering edge: the band's inner edge is content-edge + noise, so it wanders
	# in and out by a few cells (and eats into the content where nothing stands).
	var amp := float(pad) * 0.55
	for y in range(-pad, rows + pad):
		for x in range(-pad, cols + pad):
			var c := Vector2i(x, y)
			if open.has(c):
				continue
			# Signed distance to the content rectangle, rounded at the corners.
			var dx := maxf(-c.x, c.x - (cols - 1))
			var dy := maxf(-c.y, c.y - (rows - 1))
			var depth := 0.0
			if dx > 0 and dy > 0:
				depth = sqrt(dx * dx + dy * dy)
			else:
				depth = maxf(dx, dy)
			if depth <= 0.0 and depth < pad - 1 and depth + amp <= 1.2:
				continue  # deep inside the content: no noise value can fill it (|n| <= amp)
			var side := _side_of(c)
			var kind := border_kind(side)
			var n := WorldGen.fbm(float(c.x), float(c.y), sd, 9.0) * (amp * 0.3 if kind == "cliff" else amp)  # cliffs run straighter
			# depth > 0 is outside the content; the band starts where depth + n > 1.
			var filled := depth + n > 1.2
			var inner := Vector2i(clampi(c.x, 0, cols - 1), clampi(c.y, 0, rows - 1))
			if depth > 0 and border_water_extra.has(inner):
				filled = true
				kind = "water"  # the sea carries straight on out past the map edge
			if depth >= pad - 1:
				filled = true
			if kind == "none":
				filled = depth >= pad - 1
			if not filled:
				continue
			if in_content(c) and (things.has(c) or props.has(c)):
				continue
			if in_content(c) and _near_exit(c, 3):
				continue
			if in_content(c) and depth + n < 2.0 and (c.x + c.y) % 3 == 0 and kind != "cliff":
				continue  # ragged inner edge (not on cliffs: the holes become stairs of grass caps)
			blocked[c] = true
			match kind:
				"trees": _border_cells[c] = "tree"
				"cliff": _border_cells[c] = "cliff"
				"water": _border_cells[c] = "water"
				_: _border_cells[c] = "void"
	# Trees: sparse at the inner edge, dense and large deeper in.
	var rng := _border_rng
	var has_big := Art.has("nature", "big_oak_a")
	var season := GameState.look_se()
	var mids: Array = {"spring": ["mid_oak", "mid_pine", "mid_birch", "mid_cherry"], "summer": ["mid_oak", "mid_pine", "mid_birch", "mid_willow"], "fall": ["mid_maple", "mid_oak", "mid_pine", "mid_maple_b", "mid_dead"], "winter": ["mid_snowpine", "mid_dead", "mid_snowpine_b", "mid_pine", "mid_dead_b"]}.get(season, ["mid_oak", "mid_pine"])
	var bigs: Array = {"spring": ["big_oak_a", "big_oak_b", "big_pine_a", "big_birch_a", "big_cherry_a", "big_oak_c"], "summer": ["big_oak_a", "big_oak_b", "big_pine_b", "big_birch_b", "big_willow", "big_oak_c"], "fall": ["big_maple_a", "big_maple_b", "big_oak_a", "big_pine_a", "big_dead_a"], "winter": ["big_snowpine_a", "big_snowpine_b", "big_dead_a", "big_dead_b", "big_pine_c"]}.get(season, ["big_oak_a"])
	if scene_id() == "wastes" and Art.has("nature", "mid_dead"):
		mids = ["mid_dead", "mid_dead_b"]  # a corrupted wasteland, not a blossom ring
		bigs = ["big_dead_a", "big_dead_b"]
	var bt = get("R")  # themed border stands (regions.json "border_trees": {"mid": [...], "big": [...]}, "props/x" allowed)
	if bt is Dictionary and (bt as Dictionary).get("border_trees") is Dictionary:
		mids = (bt as Dictionary)["border_trees"].get("mid", mids)
		bigs = (bt as Dictionary)["border_trees"].get("big", bigs)
	for c: Vector2i in _border_cells:
		if _border_cells[c] != "tree":
			continue
		var depth := _band_depth(c)
		var chance := 0.35 if depth <= 1 else (0.6 if depth == 2 else 0.8)
		if rng.randf() > chance:
			continue
		var nm := GameState.tree_sprite(rng.randi_range(0, 2))
		if has_big:
			nm = str(mids[rng.randi_range(0, mids.size() - 1)]) if depth <= 2 or rng.randf() < 0.4 else str(bigs[rng.randi_range(0, bigs.size() - 1)])
		var bg := "nature"
		if "/" in nm:
			bg = nm.get_slice("/", 0)
			nm = nm.get_slice("/", 1)
		if depth <= 1 and in_content(c + Vector2i(0, 1)) and not _border_cells.has(c + Vector2i(0, 1)):
			prop(bg, nm, c, 0, 0.0, false)  # inner-edge trees are props so you walk behind the canopy
		else:
			_border_draw.append([c, bg, nm, rng.randf_range(-3.0, 3.0)])
	_border_draw.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2i).y < (b[0] as Vector2i).y)


func _near_exit(c: Vector2i, d: int) -> bool:
	for e in exits:
		if (e["rect"] as Rect2i).grow(d).has_point(c):
			return true
	var sp := world_to_cell((next_spawn + offset()) if next_spawn != Vector2.ZERO else default_spawn())
	return absi(sp.x - c.x) <= d and absi(sp.y - c.y) <= d


## If the player stands inside something solid (after a map change), slide to the nearest open cell.
func unstick_player() -> void:
	if player == null:
		return
	var feet := Rect2(player.position + Player.FEET.position, Player.FEET.size)
	if not rect_blocked(feet):
		return
	var start := world_to_cell(player.position - Vector2(0, 2))
	for rad in range(1, 8):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var c := start + Vector2i(dx, dy)
				if not in_content(c) or blocked.has(c):
					continue
				player.position = cell_center(c)
				return


## How deep a band cell sits (1 = touching open ground).
func _band_depth(c: Vector2i) -> int:
	for d in range(1, pad + 3):
		for off: Vector2i in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d)]:
			var n := c + off
			if not _border_cells.has(n) and not blocked.has(n):
				return d
	return pad + 2


func draw_border() -> void:
	# The band's cell sets never change after _build_border: sorted once per band
	# (c3_16 #2), not on every redraw and clipped chunk bake.
	var bkey := "border:%d:%d" % [_border_cells.size(), _border_cells.hash()]
	var bg: Dictionary = _geom_memo.get(bkey, {})
	if bg.is_empty():
		bg = {"water": {}, "cliff": {}, "tree": {}, "void": []}
		for c: Vector2i in _border_cells:
			match _border_cells[c]:
				"water": bg["water"][c] = true
				"cliff": bg["cliff"][c] = true
				"tree": bg["tree"][c] = true
				"void": (bg["void"] as Array).append(c)
		var ring0 := {}
		var deep0 := {}
		var shade0 := {}
		for c: Vector2i in bg["tree"]:
			var dd := _band_depth(c)
			if dd >= 2:
				ring0[c] = true
			if dd >= 3:
				deep0[c] = true
			if dd >= 4:
				shade0[c] = true
		bg["ring"] = ring0
		bg["deep"] = deep0
		bg["shade"] = shade0
		_geom_memo[bkey] = bg
	var water: Dictionary = bg["water"]
	var cliff: Dictionary = bg["cliff"]
	var treec: Dictionary = bg["tree"]
	for c: Vector2i in bg["void"]:
		var vr := Rect2(c * TILE, Vector2i(TILE, TILE))
		if not Art.clipped(vr):
			draw_rect(vr, Color(0.05, 0.05, 0.08))
	# Exit corridors through the band match the map's own paths (dirt on grass maps).
	if not _border_open.is_empty():
		# Each exit's corridor is as wide as the exit (not the grown band opening), and on
		# soft paths it overlaps the map's own path by 2 cells so the two shapes join.
		var corridor := {}
		var rd = get("R")
		var pk := str((rd as Dictionary).get("path", "dirt")) if rd is Dictionary else "dirt"
		# Any soft (seamless) region path keeps to its lanes too: a full-width corridor
		# beside a 2-wide path read as a notch at the map edge (Windward hub).
		var soft_k := not (rd is Dictionary) or pk in ["dirt", "sand", "stone"] or Art.has("seamless", pk)
		var gw_map: Dictionary = (_painter_of if _painter_of != null else self).ground_word
		var rpcs = get("_pcs")  # region paths (any kind)
		for e in exits:
			var r: Rect2i = e["rect"]
			var vert := r.size.y >= r.size.x  # west/east exit
			var inward := Vector2i(1 if r.position.x <= 0 else (-1 if r.end.x >= cols else 0), 1 if r.position.y <= 0 else (-1 if r.end.y >= rows else 0))
			# Where the map's own soft path meets the exit, keep to its lanes (no wide slab with shoulders).
			var lanes := {}
			if soft_k:
				for c: Vector2i in cells_of([Rect2i(r.position + inward * 3, r.size)]):
					if str(gw_map.get(c, "")) in ["dirt", "sand", "stone"] or (rpcs is Dictionary and (rpcs as Dictionary).has(c)):
						lanes[c.y if vert else c.x] = true
			for c: Vector2i in _border_open:
				if not blocked.has(c) and ((vert and c.y >= r.position.y and c.y < r.end.y) or (not vert and c.x >= r.position.x and c.x < r.end.x)) and (lanes.is_empty() or lanes.has(c.y if vert else c.x)):
					corridor[c] = true
			if soft_k:
				for k in range(1, 3):
					for c: Vector2i in cells_of([Rect2i(r.position + inward * k, r.size)]):
						if in_content(c) and not blocked.has(c) and (lanes.is_empty() or lanes.has(c.y if vert else c.x)):
							corridor[c] = true
		draw_corridor(corridor)
	if not water.is_empty() or not border_water_extra.is_empty():
		var body := water.duplicate()
		body.merge(border_water_extra)
		# Carry the water two cells past the outermost ring, so its soft bank
		# never shows as a sand strip down the screen edge.
		var outer := Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
		for c: Vector2i in body.keys():
			var on_x := c.x == outer.position.x or c.x == outer.end.x - 1
			var on_y := c.y == outer.position.y or c.y == outer.end.y - 1
			if not (on_x or on_y):
				continue
			# Carry 2 cells outward (the whole 2x2 block beside a corner, not only its diagonal).
			for kx in range(0, 3 if on_x else 1):
				for ky in range(0, 3 if on_y else 1):
					body[c + Vector2i(signi(c.x - cols / 2) * kx, signi(c.y - rows / 2) * ky)] = true
		draw_water(body, border_water_shore if border_water_shore != "" else ("sand" if scene_id() == "beach" else "grass"))
	if not cliff.is_empty():
		draw_rock_mass(cliff)
	# Forest floor only under the deep part of the tree mass, with a soft, rounded
	# edge in two layers (a faint outer ring, then the full floor), and shade that
	# deepens toward the map's outer edge: layered woods, no square steps.
	var ff := Art.tex("seamless", "forest_floor")
	var ring: Dictionary = bg["ring"]
	var deep: Dictionary = bg["deep"]
	if ff != null:
		CliffPainter.draw_rounded_cells(self, ring, ff, SEAM_PERIOD, Color(1, 1, 1, 0.4))
		CliffPainter.draw_rounded_cells(self, deep, ff, SEAM_PERIOD, Color(1, 1, 1, 0.85))
	else:
		for c: Vector2i in deep:
			if not Art.draw_tile(self, "tiles", "forest_floor", Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.2, 0.35, 0.18, 0.6))
	_draw_soft_shade(bg["shade"], Color(0.03, 0.06, 0.05, 0.22))
	if _painter_of != null:
		_border_stripes()
		return
	for item: Array in _border_draw:
		var c: Vector2i = item[0]
		Art.draw_prop(self, str(item[1]), str(item[2]), Vector2(c * TILE) + Vector2(TILE / 2.0 + float(item[3]), TILE))


## A flat shade over a cell set with rounded edges (deep woods, band depth).
func _draw_soft_shade(cells: Dictionary, col: Color) -> void:
	if cells.is_empty():
		return
	var skey := "shade:%d:%d" % [cells.size(), cells.hash()]
	if not _geom_memo.has(skey):
		var polys: Array = []
		for lp: PackedVector2Array in CliffPainter.loops(cells):
			if CliffPainter.is_hole(lp):
				continue
			var poly0 := CliffPainter.smooth(lp, 1.2)
			if poly0.size() >= 3 and not Geometry2D.triangulate_polygon(poly0).is_empty():
				var bb := Rect2(poly0[0], Vector2.ZERO)
				for q in poly0:
					bb = bb.expand(q)
				polys.append([poly0, bb.grow(2.0)])
		_geom_memo[skey] = polys
	for pe: Array in _geom_memo[skey]:
		var poly: PackedVector2Array = pe[0]
		if not Art.clipped(pe[1]):
			draw_colored_polygon(poly, col)


## Painter only: the border trees (hundreds of sprites, a draw call each) go into
## one canvas item per 256 px row band, in the same y order. A chunk render then
## skips the bands it doesn't touch (Godot culls whole items) instead of drawing
## every border tree on the map for each chunk.
var _bake_stripes := {}


func _border_stripes() -> void:
	# One Sprite2D per border tree under a y-sorted holder: a chunk render then draws
	# only the trees that touch it (Godot culls each sprite), still in y order.
	var holder: Node2D = _bake_stripes.get("trees")
	if holder != null and holder.get_child_count() == _border_draw.size():
		return  # the band never changes after _build_border
	if holder == null:
		holder = Node2D.new()
		holder.y_sort_enabled = true
		holder.texture_filter = texture_filter
		add_child(holder)
		_bake_stripes["trees"] = holder
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.free()
	for item: Array in _border_draw:
		var t := Art.tex(str(item[1]), str(item[2]))
		var s := Sprite2D.new()
		if t != null:
			s.texture = t
			s.centered = false
			s.scale = Vector2(0.5, 0.5)
			s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
		s.position = offset() + Vector2((item[0] as Vector2i) * TILE) + Vector2(TILE / 2.0 + float(item[3]), TILE)
		holder.add_child(s)


## Shared fishing minigame: cast, wait for the bite, press A. `pool` is the
## water's fish from easiest to rarest; skill, night light, rain and perks
## reach deeper into it.
func fish_at(c: Vector2i, pool_in: Array) -> void:
	# Pools run cheapest → priciest, so the weighted pick keeps valuable fish rare.
	var pool := pool_in.duplicate()
	for f: String in ["minnow", "sunfish"]:  # every water has its common fish
		if not pool.has(f):
			pool.append(f)
	pool.sort_custom(func(a: String, b: String) -> bool: return GameState.item_value(a) < GameState.item_value(b))
	if GameState.held_tool() != "rod":
		# Only the rod in hand fishes (an axe or a hoe at the water does nothing).
		ToolHint.need(self, "rod", "to fish")
		return
	if not GameState.spend_for("rod"):
		hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return
	player.play_tool("cast")
	player.frozen = true
	var bob: AnimatedSprite2D = null
	if Art.has("fx", "bobber"):
		bob = AnimatedSprite2D.new()
		var b2 := Art.has("fx", "bobber2")
		bob.sprite_frames = Art.frames("fx", {"bobber": "bobber2" if b2 else "bobber", "bite": "bobber2_bite" if b2 else "bobber_bite"}, {"bobber": 4.0, "bite": 8.0})
		bob.animation = "bobber"
		bob.scale = Vector2(0.5, 0.5)
		bob.position = cell_center(c) + Vector2(0, -6)
		bob.z_index = 1
		add_child(bob)
		bob.play("bobber")
	hud.toast("Casting...")
	Music.instance(get_tree()).sfx("cast")
	var speed := 1.0 - GameState.bonus("fishing", "bite_speed") - (0.1 if GameState.has_friend_perk("finn", 2) else 0.0) - (0.1 if Sanctuary.on() and Builds.is_built("pool") else 0.0)
	var night: bool = GameState.is_night() and GameState.run["flags"].has("lighthouse_lit")
	var wait := randf_range(1.5, 4.5) * maxf(0.4, speed) * (0.7 if night else 1.0) * (0.75 if GameState.is_wet() else 1.0)
	# Tidecall (Fishing): the first cast of the day bites at once.
	if GameState.bonus("fishing", "tidecall") > 0 and int(GameState.run["flags"].get("tide_day", -1)) != int(GameState.run["day"]):
		GameState.run["flags"]["tide_day"] = int(GameState.run["day"])
		wait = 0.3
		hud.toast("Tidecall!", Color(0.6, 0.9, 1))
	var baited := false
	if GameState.count("bait") > 0:  # bait: quicker bites and a shot at better fish
		GameState.add_item("bait", -1)
		wait *= 0.6
		baited = true
		hud.toast("Bait on the hook (%d left)" % GameState.count("bait"), Color(0.8, 0.95, 1))
	var window := 1.0 + GameState.bonus("fishing", "escape_less")
	var t := 0.0
	var bite := false
	var caught := false
	var tree := get_tree()
	while t < wait + window:
		await tree.process_frame
		if not is_inside_tree():
			return  # the map changed under the line (scene change, collapse)
		if tree.paused or Dialogue.instance(tree).active:
			continue  # menu open: the fish waits
		t += get_process_delta_time()
		if not bite and t >= wait:
			bite = true
			hud.toast("!!!  Tap USE!", Color(1, 1, 0.4))
			fx("alert", player.position + Vector2(0, -26), 10.0, 0.5)
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if (Input.is_action_just_pressed("a") or Input.is_action_just_pressed("tool") or Input.is_action_just_pressed("action")) and t > 0.2:
			caught = bite
			if not bite:
				hud.toast("Too soon! Wait for the !!!", Color(1, 0.8, 0.6))
				Music.instance(get_tree()).sfx("nope")
			break
	player.frozen = false
	var bob_at := player.position
	if bob:
		bob_at = bob.position
		fx("reel_splash" if Art.has("fx", "reel_splash") else "splash", bob.position, 12.0, 0.5)
		if caught and Art.has("fx", "fish_jump_a"):
			fx(["fish_jump_a", "fish_jump_b", "fish_jump_c"][randi() % 3], bob.position + Vector2(0, 4), 12.0, 0.5, player.facing == "left")
		bob.queue_free()
	if caught:
		var lvl := GameState.skill_level("fishing")
		# Fish above a value ceiling (skill, night light, bait) stay out of reach.
		var cap_v := 25 + 15 * lvl + (40 if night else 0) + (10 if baited else 0)
		var open := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap_v)
		if open.is_empty():
			open = [pool[0]]
		var reach := mini(open.size(), 1 + lvl + (2 if night else 0) + (1 if baited else 0))
		# Pools run easiest → rarest: weight the pick so rare fish stay rare.
		var fish: String = open[_weighted_index(0, reach, 0.8 if baited else 0.67)] if randf() > 0.08 else "boot"
		if randf() < GameState.bonus("fishing", "rare_fish") + (0.1 if GameState.has_friend_perk("finn", 8) else 0.0):
			# Rare Catch: one step up (ceiling +40, one more fish in reach), weighted as usual.
			var up := pool.filter(func(f: String) -> bool: return GameState.item_value(f) <= cap_v + 40)
			if up.is_empty():
				up = open
			fish = up[_weighted_index(0, mini(up.size(), reach + 1), 0.8 if baited else 0.67)]
		Music.instance(get_tree()).sfx("reel")
		player.play_tool("reel")
		# The fish flies out of the water to you; a boot thuds, a rare one sparkles.
		pop_items(bob_at, fish, 2 if randf() < GameState.bonus("fishing", "double_fish") else 1)
		if fish == "boot":
			Music.instance(get_tree()).sfx("thud", "nope")
		elif open.find(fish) >= maxi(3, reach - 1) or not open.has(fish):
			Music.instance(get_tree()).sfx("quest_done", "levelup")
			fx("sparkle", bob_at + Vector2(0, -8), 14.0, 0.7)
		if randf() < GameState.bonus("fishing", "chest_chance"):
			give(["old_coin", "pearl", "map_scrap"][randi() % 3])
		elif scene_id() == "lake" and GameState.has_quest("finn_pearl") and not GameState.quest_done("finn_pearl") and GameState.count("pearl") == 0 and randf() < 0.05:
			give("pearl")
			hud.toast("Something pale rolls out of the net. Finn's pearl?", Color(1, 0.9, 0.6))
		xp("fishing", 4)
	else:
		hud.toast("It got away.")
		Music.instance(get_tree()).sfx("fish_escape")


## A random index in [lo, hi), each step up `ratio` times as likely as the last
## (bait flattens it to 0.8, so the better fish in reach bite more often).
func _weighted_index(lo: int, hi: int, ratio := 0.67) -> int:
	var tot := 0.0
	for i in range(lo, hi):
		tot += pow(ratio, i - lo)
	var r := randf() * tot
	for i in range(lo, hi):
		r -= pow(ratio, i - lo)
		if r <= 0.0:
			return i
	return hi - 1


## Ask before handing a villager the item you're holding.
func confirm_gift(who_name: String, sel: String) -> bool:
	var d := Dialogue.instance(get_tree())
	d.say([{"who": who_name, "text": "Give them your %s?" % GameState.item_name(sel), "choice": ["Give it", "Just chat"], "key": ""}])
	await d.finished
	return d.last_choice == 0


## A reaction that tells you how much they liked it.
func gift_reaction(who_name: String, sel: String, gain: int) -> String:
	var nm := GameState.item_name(sel)
	var gid := ""
	for k in GameState.npcs:
		if str(GameState.npcs[k].get("name", "")) == who_name or str(k) == who_name:
			gid = str(k)
			break
	var own := GameState.gift_line(gid, sel, gain)
	if own != "":
		return own
	if gain >= 20:
		return "A %s! How did you know? This is my favourite thing." % nm
	if gain >= 12:
		return "A %s! That's a kindness. Thank you." % nm
	if gain > 0:
		return "A %s. That's nice of you." % nm
	return "A %s? Oh. I really don't like these." % nm


# ---- elevation: plateaus with cliff faces and ramps --------------------------

var plateaus: Array = []   # [{cells, stairs}] drawn in draw_plateaus()


## Raise `cells` into a plateau. `ramps` are cells on its south edge where a ramp
## leads down (if empty, two are cut near the middle of the longest south edge).
## The rim and the rock face below south edges are solid; ramps are the way up.
func add_plateau(cells: Dictionary, ramps: Array = []) -> void:
	if cells.is_empty():
		return
	var south: Array = []
	for c: Vector2i in cells:
		if not cells.has(c + Vector2i(0, 1)):
			south.append(c)
	if ramps.is_empty() and not south.is_empty():
		# A pair of side-by-side cells on one straight south run (a stepped edge's
		# middle could put the second stair under the plateau's own rim).
		ramps = WorldGen.pick_ramps(self, cells)
		if ramps.is_empty():
			south.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
			var mid: Vector2i = south[south.size() / 2]
			ramps = [mid, mid + Vector2i(1, 0)]
	var ramp_set := {}
	for r in ramps:
		var rc := Vector2i(int(r[0]), int(r[1])) if r is Array else r as Vector2i
		ramp_set[rc] = true
	var stairs := {}
	for c: Vector2i in cells:
		var edge := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(c + d):
				edge = true
		var below := c + Vector2i(0, 1)
		if ramp_set.has(c):
			stairs[below] = true
			blocked.erase(c)
			hard.erase(c)
			blocked.erase(below)
			hard.erase(below)
			continue
		if edge and not ramp_set.has(c + Vector2i(-1, 0)) and not ramp_set.has(c + Vector2i(1, 0)):
			blocked[c] = true
		if not cells.has(below) and in_content(below):
			blocked[below] = true  # the rock face itself
	plateaus.append({"cells": cells, "stairs": stairs})


func draw_plateaus() -> void:
	for p: Dictionary in plateaus:
		draw_plateau(p["cells"], "cliffg", p["stairs"])


## Place this arc's town project site (the Crystal Ward / Headquarters) if it lives here.
func place_project_site() -> void:
	var pd := Project.def()
	if pd.is_empty() or str(pd.get("where", "")) != scene_id():
		return
	var want := Vector2i(int(pd["cell"][0]), int(pd["cell"][1]))
	var c := want
	for r in range(0, 8):
		var found := false
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := want + Vector2i(dx, dy)
				if in_content(q) and not blocked.has(q) and not things.has(q) and not blocked.has(q + Vector2i(0, 1)):
					c = q
					found = true
					break
			if found:
				break
		if found:
			break
	set_thing(c.x, c.y, {"type": "project", "hint": "A: %s" % str(pd["name"])}, true)
	var stg := Project.stage()
	var nm := ""
	if GameState.is_penguins():
		nm = "ccrystal_%d" % clampi(stg, 1, 4)
		if stg == 0:
			nm = "crystal_rock"
	else:
		nm = "warehouse_b" if stg >= 1 and Art.has("buildings", "warehouse_b") else "card_table"
	# The real build stages (Prompt 16-2) once a stage is done.
	var real := "%s_%d" % ["ward" if GameState.is_penguins() else "hq", clampi(stg, 1, 6)]
	if stg >= 1 and Art.has("buildings", real):
		nm = real
	if Art.has("buildings", nm):
		prop("buildings", nm, c, 1)
	elif Art.has("props", nm):
		prop("props", nm, c)


# ---- baked ground (phone performance) -----------------------------------------
## Everything _draw() paints on the map's own canvas used to be ONE canvas item
## the size of the whole map: Godot can't cull part of an item, so all of its
## 2000-4300 draw calls went out every frame. Now a drawing-only twin of this map
## (the painter, same script, same variables) runs that drawing once inside a
## hidden SubViewport, and the ground is shown as 256px chunk textures near the
## camera: about 6-12 draw calls. Off-screen chunks are culled (and freed past
## BAKE_MAX). queue_redraw() on the map still works: it re-runs the drawing on the
## painter and re-bakes the chunks. Small maps (houses, interiors) skip this.
const BAKE_GROUND := true
const BAKE_SOFT_GROUND := true   # soft_ground() patches go into the bake too
const BAKE_MIN_CELLS := 1200     # padded cols*rows below this draw the old way
const BAKE_CHUNK := 256          # world px per chunk side
const BAKE_SCALE := 2.0          # texels per world px (the art is 2x detail)
const BAKE_MARGIN := 2           # texels around each chunk: linear filtering never seams
const BAKE_MAX := 12             # chunks kept (a 516px render target measured ~2-2.6 MB of VRAM)
const BAKE_PER_FRAME := 1        # margin chunks baked per frame (missing visible ones always)
const BAKE_REDO_PER_FRAME := 3   # stale visible chunks re-baked per frame after a redraw
static var bake_disabled := false   # tests/tools can turn it off
static var _bake_mat: CanvasItemMaterial
var _painter_of: GameMap = null  # on the painter: the real map
var _painter: GameMap = null
var _bake_holder: SubViewport
var _bake_layer: BakeLayer
var _bake := {}                  # Vector2i chunk -> [SubViewport, Sprite2D, dirty]
var _bake_n := 0                 # chunk renders so far (perf probes)
var _bake_last := Vector2(INF, INF)  # view centre at the last full check
var _bake_busy := true           # chunks still to bake (or dirty)
var _bake_frame := -1            # budgets below are per drawn frame (_bake_update runs from _process AND call_deferred)
var _bake_budget := 0
var _bake_redo := 0
var _bake_cover_left := 0
static var bake_clip := true     # clipped single-chunk bakes (tests/tools can turn it off to compare)
const BAKE_MODE_FULL := Vector2i(-99999, -99999)
var _bake_mode_frame := -1       # the frame _bake_mode was chosen for
var _bake_mode := BAKE_MODE_FULL # what the painter's list holds this frame: the full map or one chunk
var _bake_clip := Rect2()        # on the painter: the draw-space rect its list is clipped to (empty = all)
var _bake_clips := 0             # clipped painter redraws so far (perf probes)


## The draw-space rect a chunk needs (chunk + its margin texels, in the painter's
## offset() drawing coordinates).
func _bake_chunk_clip(k: Vector2i) -> Rect2:
	return Rect2(Vector2(k * BAKE_CHUNK), Vector2(BAKE_CHUNK, BAKE_CHUNK)).grow(2.0)


func _bake_set_clip(r: Rect2) -> void:
	var dr := r
	if r.has_area():
		dr.position -= offset()
	if _painter._bake_clip == dr:
		return  # the list already holds exactly this
	_painter._bake_clip = dr
	if dr.has_area():
		_bake_clips += 1
	_painter.queue_redraw()


## Painter: clipped redraws are safe once a full one has run since the last
## request (that one did the drawing's one-off work: forage, masks, stripes).
func _bake_can_clip() -> bool:
	return _bake_full_done
var _bake_full_done := false
var _bake_pool: Array = []       # freed chunks [SubViewport, Sprite2D] kept for reuse
var _bake_covered := false       # the arrival fade is still opaque: visible chunks may spread over frames
const BAKE_COVER_PER_FRAME := 2  # missing on-screen chunks per frame while covered (player's chunk first)
const BAKE_COVER_MAX_FRAMES := 45  # never hold the arrival fade longer than this


## The arrival fade stays opaque until the on-screen ground chunks are baked
## (c3_16 #3): the bake is spread over a few short frames under the cover instead
## of one long hitch, and the first thing seen is the finished ground.
func _fade_in_when_baked() -> void:
	if not _bake_on():
		hud.fade_in(0.5)
		return
	_bake_covered = true
	var cover: ColorRect = hud.get("_fade")
	if cover != null:  # a new Hud starts clear: hold it black over the first bake
		cover.color.a = 1.0
		cover.visible = true
	for i in BAKE_COVER_MAX_FRAMES:
		await get_tree().process_frame
		if not is_inside_tree() or hud == null:
			return
		if _painter != null and not _bake_visible_missing():
			break
	_bake_covered = false
	hud.fade_in(0.2)


func _bake_visible_missing() -> bool:
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var vis := xf.affine_inverse() * get_viewport_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2((cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE)).grow(TILE * 2)
	var want := vis.intersection(bounds)
	if want.size.x <= 0.0 or want.size.y <= 0.0:
		return false
	var k0 := Vector2i((want.position / BAKE_CHUNK).floor())
	var k1 := Vector2i((want.end / BAKE_CHUNK).floor())
	for ky in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var ch = _bake.get(Vector2i(kx, ky))
			if ch == null or ch[2]:
				return true
	return false


## Holds the chunk sprites; first child of the map, sorted above nothing.
class BakeLayer extends Node2D:
	var map: GameMap
	func _process(_d: float) -> void:
		map._bake_update()


func _bake_on() -> bool:
	return BAKE_GROUND and not bake_disabled and _painter_of == null and (cols + 2 * pad) * (rows + 2 * pad) >= BAKE_MIN_CELLS


func _bake_setup() -> void:
	if _bake_mat == null:
		# The bake is drawn onto a clear target, so it holds premultiplied colour.
		_bake_mat = CanvasItemMaterial.new()
		_bake_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_bake_holder = SubViewport.new()
	_bake_holder.name = "BakeHolder"
	_bake_holder.size = Vector2i(2, 2)
	_bake_holder.disable_3d = true
	_bake_holder.transparent_bg = true
	_bake_holder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_bake_holder)
	_painter = get_script().new()
	_painter.name = "Painter"
	_painter._painter_of = self
	_painter.texture_filter = texture_filter
	_bake_holder.add_child(_painter)
	_bake_layer = BakeLayer.new()
	_bake_layer.name = "BakeLayer"
	_bake_layer.map = self
	_bake_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # finish re-bakes under a paused menu
	_bake_layer.process_priority = 1000  # after Camera2D has moved the view this frame (else a jump shows a frame of bare ground)
	# y-sorted children draw in y order: put the ground before everything (even
	# things above the map's top edge), exactly where the map's own drawing was.
	_bake_layer.position = Vector2(0, -100000)
	add_child(_bake_layer)
	move_child(_bake_layer, 0)


## Copy every script variable to the painter (containers are shared, so the
## drawing sees live gameplay state; plain values are refreshed per redraw).
func _sync_painter() -> void:
	for p in get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n.begins_with("_bake") or n == "_painter" or n == "_painter_of":
			continue
		_painter.set(n, get(n))


func _bake_request() -> void:
	if _painter == null:
		_bake_setup()
	_sync_painter()
	_painter._bake_clip = Rect2()
	_painter._bake_full_done = false
	_painter.queue_redraw()
	_bake_mode_frame = Engine.get_process_frames()
	_bake_mode = BAKE_MODE_FULL
	for ch in _bake.values():
		ch[2] = true
	_bake_busy = true
	_bake_update.call_deferred()


func _bake_update() -> void:
	if _painter == null or not is_inside_tree():
		return
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var vis := xf.affine_inverse() * get_viewport_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2((cols + 2 * pad) * TILE, (rows + 2 * pad) * TILE)).grow(TILE * 2)
	var want := vis.grow(BAKE_CHUNK * 0.25).intersection(bounds)
	if want.size.x <= 0.0 or want.size.y <= 0.0:
		return
	var k0 := Vector2i((want.position / BAKE_CHUNK).floor())
	var k1 := Vector2i((want.end / BAKE_CHUNK).floor())
	var center := vis.get_center()
	if not _bake_busy and center.distance_squared_to(_bake_last) < 256.0:
		return  # nothing to do until the view moves 16 px
	_bake_last = center
	_bake_busy = false
	var keys: Array[Vector2i] = []
	for ky in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			keys.append(Vector2i(kx, ky))
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(center / BAKE_CHUNK) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(center / BAKE_CHUNK))
	# A chunk render costs what a whole frame used to (every ground draw call),
	# so spread them: a missing on-screen chunk is made at once (else a hole),
	# a stale on-screen one keeps its old picture for a frame or two.
	var f := Engine.get_process_frames()
	if f != _bake_frame:
		_bake_frame = f
		_bake_budget = BAKE_PER_FRAME
		_bake_redo = BAKE_REDO_PER_FRAME
		_bake_cover_left = BAKE_COVER_PER_FRAME
	var todo: Array[Vector2i] = []
	for k in keys:
		var on_screen := Rect2(Vector2(k * BAKE_CHUNK), Vector2(BAKE_CHUNK, BAKE_CHUNK)).intersects(vis)
		var ch = _bake.get(k)
		if ch != null and not ch[2]:
			continue
		if on_screen and ch == null and _bake_covered:
			if _bake_cover_left <= 0:
				_bake_busy = true
				continue
			_bake_cover_left -= 1
		elif on_screen and ch != null:
			if _bake_redo <= 0:
				_bake_busy = true
				continue
			_bake_redo -= 1
		elif not on_screen:
			if _bake_budget <= 0:
				_bake_busy = true
				continue
			_bake_budget -= 1
		todo.append(k)
	if not todo.is_empty():
		# Clipped bakes (c3_16 #1): the painter's list holds what ONE chunk needs, so a
		# frame that renders a single chunk redraws the painter clipped to it (a few
		# dozen draw calls instead of the whole map's). Several chunks in one frame
		# (arrival, a camera jump, re-bakes after a redraw) share the full list.
		if _bake_mode_frame != f:
			_bake_mode_frame = f
			if bake_clip and todo.size() == 1 and _painter._bake_can_clip():
				_bake_mode = todo[0]
				_bake_set_clip(_bake_chunk_clip(todo[0]))
			else:
				_bake_mode = BAKE_MODE_FULL
				_bake_set_clip(Rect2())
		if _bake_mode != BAKE_MODE_FULL:
			# This frame's list is one chunk's: only that chunk may render now.
			var keep := todo.filter(func(k: Vector2i) -> bool: return k == _bake_mode)
			if keep.size() < todo.size():
				_bake_busy = true
				# Undo the budget the skipped ones took: they wait for a later frame.
			todo.assign(keep)
		for k in todo:
			var ch = _bake.get(k)
			if ch == null:
				_bake_make(k)
			else:
				(ch[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
				_bake_n += 1
				ch[2] = false
	if _bake.size() > BAKE_MAX:
		var far: Array = _bake.keys().filter(func(k: Vector2i) -> bool: return not keys.has(k))
		far.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a).distance_squared_to(center / BAKE_CHUNK) > Vector2(b).distance_squared_to(center / BAKE_CHUNK))
		for k: Vector2i in far:
			if _bake.size() <= BAKE_MAX:
				break
			_bake_free(k)
	# Dirty chunks that left the wanted area: drop them (re-made when needed).
	for k: Vector2i in _bake.keys():
		if _bake[k][2] and not keys.has(k):
			_bake_free(k)


func _bake_make(k: Vector2i) -> void:
	var origin := Vector2(k * BAKE_CHUNK)
	var px := int(BAKE_CHUNK * BAKE_SCALE)
	if not _bake_pool.is_empty():  # reuse a render target: creating one is a hitch on phones
		var re: Array = _bake_pool.pop_back()
		var rsv := re[0] as SubViewport
		rsv.canvas_transform = Transform2D(0.0, Vector2(BAKE_SCALE, BAKE_SCALE), 0.0, -origin * BAKE_SCALE + Vector2(BAKE_MARGIN, BAKE_MARGIN))
		rsv.render_target_update_mode = SubViewport.UPDATE_ONCE
		(re[1] as Sprite2D).position = origin - _bake_layer.position
		(re[1] as Sprite2D).visible = true
		_bake[k] = [rsv, re[1], false]
		_bake_n += 1
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(px + 2 * BAKE_MARGIN, px + 2 * BAKE_MARGIN)
	sv.disable_3d = true
	sv.transparent_bg = true
	sv.world_2d = _bake_holder.world_2d
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	_bake_layer.add_child(sv)
	# (only after add_child: the shared canvas is attached on entering the tree)
	sv.canvas_transform = Transform2D(0.0, Vector2(BAKE_SCALE, BAKE_SCALE), 0.0, -origin * BAKE_SCALE + Vector2(BAKE_MARGIN, BAKE_MARGIN))
	var sp := Sprite2D.new()
	sp.texture = sv.get_texture()
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = Rect2(BAKE_MARGIN, BAKE_MARGIN, px, px)
	sp.scale = Vector2.ONE / BAKE_SCALE
	sp.position = origin - _bake_layer.position
	sp.material = _bake_mat
	_bake_layer.add_child(sp)
	_bake[k] = [sv, sp, false]
	_bake_n += 1


func _bake_free(k: Vector2i) -> void:
	var ch: Array = _bake[k]
	_bake.erase(k)
	if _bake_pool.size() < 3:  # keep a few render targets for reuse
		(ch[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		(ch[1] as Sprite2D).visible = false
		_bake_pool.append(ch)
		return
	(ch[1] as Node).queue_free()
	(ch[0] as Node).queue_free()
