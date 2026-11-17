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
var _ext := Rect2i()          # area added by extend()
var _ext_paths := {}          # dirt connecting moved exits
var hitstop := 0.0
var _last_mana_t := -1
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

	if has_sky:
		sky = Scenery.new()
		sky.raining = not GameState.is_penguins() and int(GameState.run["day"]) == 1
		sky.weather = GameState.weather_today()
		add_child(sky)
	_night = CanvasModulate.new()
	add_child(_night)

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
			for extra in ["bite", "hurt", "limp", "guard", "howl", "dig", "fetch", "beg"]:
				if Art.has("animals/" + pet_kind, extra):
					anims[extra] = extra
			_pet_anim.sprite_frames = Art.frames("animals/" + pet_kind, anims, {"idle": 2.0, "walk": 8.0, "run": 12.0, "sit": 1.0, "sleep": 1.0, "bark": 4.0, "play": 4.0, "bite": 10.0, "hurt": 6.0, "limp": 5.0, "guard": 2.0, "howl": 4.0, "dig": 8.0, "fetch": 8.0, "beg": 2.0}, {"bite": false, "hurt": false, "howl": false})
			_pet_anim.scale = Vector2(0.5, 0.5)
			_pet_anim.animation = "idle"
			_pet_anim.frame_changed.connect(func() -> void:
				var tex := _pet_anim.sprite_frames.get_frame_texture(_pet_anim.animation, _pet_anim.frame)
				if tex:
					_pet_anim.offset = Vector2(0, -tex.get_height() / 2.0))
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
			Net.peers_changed.connect(_sync_puppets)
			_sync_puppets()
			Net._send({"t": "scene", "scene": scene_id()}))

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = maxi((cols + 2 * pad) * TILE, 270)
	cam.limit_bottom = maxi((rows + 2 * pad) * TILE, 480)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	cam.make_current()

	hud = Hud.new()
	add_child(hud)
	add_child(TouchControls.new())
	add_child(GameMenu.new())
	Music.instance(get_tree()).play(music_track)
	queue_redraw()
	hud.fade_in(0.5)
	after_ready()
	Story.restore_spawns(self)
	# Where you arrived here on foot: the balloon can bring you back to it.
	if has_sky and scene_id() not in ["house", "interior", "mine", "moon", "station", "sky", "title", "test_map"]:
		var vis: Dictionary = GameState.run.get("visited", {})
		if not vis.has(scene_id()):
			var at := player.position - offset()
			vis[scene_id()] = [at.x, at.y]
			GameState.run["visited"] = vis
	Racket.on_enter(self)
	Marked.on_enter(self)
	_fill_extension()
	_place_signposts()
	_place_waiting_horse()
	unstick_player()
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
	elif Art.has("props", "horse3"):
		anim_prop("props", "horse3", c, 0, 2.0)
	set_thing(c.x, c.y, {"type": "horse", "hint": "A: ride %s" % str(GameState.run.get("names", {}).get("horse", "your horse"))}, false)


## Save when the phone/browser backgrounds the game or the tab closes.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if not GameState.run.is_empty() and not _changing:
			GameState.run["scene"] = scene_id()
			GameState.save()


## Subclasses override these.
func scene_id() -> String:
	return "farm"
func build() -> void:
	pass
func after_ready() -> void:
	pass
func default_spawn() -> Vector2:
	return Vector2(cols * TILE / 2.0, rows * TILE / 2.0)
func interact(_cell: Vector2i, _thing: Dictionary) -> bool:
	return false
func hint_for(_cell: Vector2i, thing: Dictionary) -> String:
	if not resources_here and str(thing.get("type", "")) in ["tree", "rock", "log", "stump", "bush"] and not bool(thing.get("harvest", false)):
		return ""
	return str(thing.get("hint", ""))


# ---- grid helpers ------------------------------------------------------------

func block_rect(x: int, y: int, w: int, h: int) -> void:
	for i in w:
		for j in h:
			blocked[Vector2i(x + i, y + j)] = true


func set_thing(x: int, y: int, thing: Dictionary, solid := true) -> void:
	things[Vector2i(x, y)] = thing
	if solid:
		blocked[Vector2i(x, y)] = true


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
	if not swim_ok:
		return false
	if GameState.has_perk("fishing", "Swimmer") or Companion.has_ability("tail"):
		return true
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
			if blocked.has(c) and not can_swim_cell(c):
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


func try_interact(c: Vector2i) -> bool:
	var thing: Dictionary = things.get(c, {})
	if interact(c, thing):
		return true
	if thing.is_empty() and scene_id() != "farm" and use_consumable(str(GameState.run["selected"])):
		return true
	return interact_common(c, thing)


## Interactions every outdoor map shares (trees, rocks, logs, stumps, bushes).
func interact_common(c: Vector2i, thing: Dictionary) -> bool:
	var t := str(thing.get("type", ""))
	if not resources_here and t in ["tree", "rock", "log", "stump", "bush"] and not bool(thing.get("harvest", false)):
		hud.toast("That's part of the town.", Color(0.9, 0.9, 0.9))
		return true
	match t:
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
							if old is Sprite2D and Art.has("nature", "ftree_%s_late" % kind):
								(old as Sprite2D).texture = Art.tex("nature", "ftree_%s_late" % kind))
			else:
				wobble(c, 0.08)
			var n := 1 + (1 if randf() < 0.3 + GameState.bonus("foraging", "forage_bonus") * 0.2 else 0)
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
			if a != null and is_instance_valid(a):
				var key := "pet_%s_%d" % [str(a.name), int(GameState.run["day"])]
				if GameState.run["flags"].has(key):
					hud.toast("Already happy today.")
				else:
					GameState.run["flags"][key] = true
					emote(a, "heart", 1.4, -18.0)
					hud.toast("%s loves that." % str(a.kind).split("_")[0].capitalize(), Color(1, 0.8, 0.9))
					xp("farming", 2)
					# A happy animal gives: eggs from hens, milk from cows and goats, wool from sheep.
					var k := str(a.kind)
					var prod := "egg" if k.begins_with("chicken") or k.begins_with("hen") or k.begins_with("duck") else ("milk" if k.begins_with("cow") or k.begins_with("goat") else ("sheep_wool" if k.begins_with("sheep") else ""))
					if prod != "" and not bool(a.get("baby")):
						var n := 1 + (1 if randf() < GameState.bonus("farming", "animal_yield") else 0)
						pop_items(a.position, prod, n)
			return true
		"weeds":
			# Weeds come out by hand (or any tool): fiber, Stardew-style.
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
			# Now and then a weed's roots hold a packet of wild seed.
			if randf() < 0.06 + 0.01 * GameState.skill_level("foraging"):
				pop_items(cell_center(c), "seed_packet", 1)
			_mark_cleared(c)
			var wsp: Node2D = props.get(c, null)
			clear_cell(c)
			if wsp:
				wsp.queue_free()
			for i in 4:
				_leaf(cell_center(c) + Vector2(randf_range(-6, 6), -8))
			pop_items(cell_center(c), "fiber", 1 + (1 if randf() < 0.3 else 0))
			return true
		"tree", "log", "stump":
			if GameState.held_tool() != "axe":
				if GameState.has_tool("axe"):
					hud.toast("Use the axe for that.")
				return GameState.has_tool("axe")
			var tb := GameState.tree_block(thing)
			if tb != "":
				player.play_tool("axe")
				wobble(c, 0.02)
				hud.toast(tb, Color(1, 0.85, 0.6))
				return true
			if not GameState.has_perk("foraging", "Keeper of the Woods") and not GameState.spend_for("axe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("axe")
			Music.instance(get_tree()).sfx("chop")
			if GameState.bonus("foraging", "chop_bonus") > 0.0 and int(thing.get("hp", 3)) > 1:
				thing["hp"] = int(thing.get("hp", 3)) - int(GameState.bonus("foraging", "chop_bonus"))
			wobble(c, 0.08 if str(thing["type"]) == "tree" else 0.03)
			fx("wood_chips", cell_center(c) + Vector2(0, -10), 16.0, 0.5)
			thing["hp"] = int(thing.get("hp", 3)) - (1 + GameState.tool_tier("axe") / 2)
			if Companion.has_ability("haul"):
				thing["hp"] = 0  # Dad: "Just point at the tree."
			if int(thing["hp"]) <= 0:
				var is_tree := str(thing["type"]) == "tree"
				xp("foraging", 3)
				var bonus := int(GameState.bonus("foraging", "wood_bonus"))
				if is_tree:
					# Every tree comes down: it falls, leaves a stump, and regrows
					# after a few days (sooner with Old Growth). No infinite wood.
					_mark_cleared(c)
					if randf() < GameState.bonus("foraging", "sap_chance"):
						pop_items(cell_center(c), "sap", 1)
					if GameState.has_perk("foraging", "Old Growth") and randf() < 0.5:
						pop_items(cell_center(c), "hardwood" if GameState.items.has("hardwood") else "wood", 1)
					fell_tree(c, 5 + bonus)
				else:
					_mark_cleared(c)
					var sp: Node2D = props.get(c, null)
					clear_cell(c)
					if sp:
						sp.queue_free()
					fx("poof", cell_center(c) + Vector2(0, -6), 16.0, 0.5)
					pop_items(cell_center(c), "wood", 2)
			return true
		"rock":
			if GameState.held_tool() != "pickaxe":
				if GameState.has_tool("pickaxe"):
					hud.toast("Use the pickaxe for that.")
				return GameState.has_tool("pickaxe")
			var ob := GameState.ore_block(str(thing.get("ore", "stone")))
			if ob != "":
				player.play_tool("pickaxe")
				hud.toast(ob, Color(1, 0.85, 0.6))
				return true
			if not GameState.spend_for("pickaxe"):
				hud.toast("Too tired.", Color(1, 0.7, 0.7))
				return true
			player.play_tool("pickaxe")
			Music.instance(get_tree()).sfx("chop")
			wobble(c, 0.04)
			fx("stone_chips", cell_center(c) + Vector2(0, -8), 16.0, 0.5)
			thing["hp"] = int(thing.get("hp", 2)) - (1 + GameState.tool_tier("pickaxe") / 2)
			if int(thing["hp"]) <= 0:
				xp("mining", 2)
				_mark_cleared(c)
				var big := props.has(c) and (props[c] as Sprite2D).texture and str((props[c] as Sprite2D).texture.resource_path).contains("rock_m")
				var extra := "copper"
				var en := 1 if randf() < 0.25 else 0
				if randf() < GameState.bonus("mining", "gem_chance"):
					extra = ["amethyst", "ruby", "sapphire", "emerald"][randi() % 4]
					en = 1
				break_rock(c, 2 + int(GameState.bonus("mining", "stone_bonus")), extra, en, "m" if big else "")
			return true
		"bush":
			if bool(thing.get("berries", false)):
				thing["berries"] = false
				thing["hint"] = ""
				GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
				give("berry", 2)
				xp("foraging", 2)
				if props.has(c) and Art.tex("nature", GameState.bush_sprite(false)):
					(props[c] as Sprite2D).texture = Art.tex("nature", GameState.bush_sprite(false))
			return true
		"forage":
			var item := str(thing.get("item", "mushroom"))
			GameState.run["flags"][str(thing["key"])] = int(GameState.run["day"])
			things.erase(c)
			var fsp: Node2D = props.get(c, null)
			props.erase(c)
			if fsp:
				fsp.queue_free()
			pop_items(cell_center(c), item, 1 + int(GameState.bonus("foraging", "forage_bonus")))
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
	_ext = Rect2i(0, 0, cols, rows)
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
	for c: Vector2i in _ext_paths:
		blocked.erase(c)


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
func _fill_extension() -> void:
	if _ext.size == Vector2i.ZERO:
		return
	var avoid := _ext_paths.duplicate()
	for e in exits:
		for c in cells_of([(e["rect"] as Rect2i).grow(2)]):
			avoid[c] = true
	var seed_v := hash(scene_id()) % 1000
	WorldGen.tree_clumps(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 5, int(cols * rows / 260.0), avoid)
	WorldGen.scatter_props(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 6, int(cols * rows / 110.0), avoid)
	WorldGen.add_critters(self, Rect2i(2, 2, cols - 4, rows - 4), seed_v + 7, int(cols * rows / 350.0))


func _check_quests() -> void:
	if GameState.run.is_empty():
		return
	for id in GameState.tick_quests():
		hud.toast("Quest complete: %s" % id.replace("_", " "), Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")


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
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
	props.erase(c)
	# The wood is yours the moment it falls (leaving mid-animation used to lose it).
	give("wood", wood)
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
		Music.instance(get_tree()).sfx("hit")
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
	Music.instance(get_tree()).sfx("hit")
	fx("leaf_burst", leaves_at, 14.0, 0.6)
	fx("dust_puff", at + Vector2(dir * 22.0, 0), 14.0, 0.5)
	await get_tree().create_timer(0.25).timeout
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
	var sp: Node2D = props.get(c, null)
	things.erase(c)
	blocked.erase(c)
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
	if give_it:
		give(id, n)
	var icon := Art.tex("items", "pop_" + id) if Art.has("items", "pop_" + id) else Art.tex("items", Hud.icon_for(id))
	if icon == null:
		return  # no picture: the toast from give() says what you got (no flying logs)
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
			Music.instance(get_tree()).sfx("pickup"))


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


func is_cleared(c: Vector2i, regrow_days := 6) -> bool:
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
	if GameState.has_perk("foraging", "Old Growth"):
		days = mini(days, 2)
	return int(GameState.run["day"]) - int(lst[key]) < days


## Declare an exit strip: standing in `r` sends you to `scene` at `spawn`.
var exits: Array = []
func add_exit(r: Rect2i, scene: String, spawn: Vector2, facing: String, label_text := "") -> void:
	exits.append({"rect": r, "scene": scene, "spawn": spawn, "facing": facing, "label": label_text})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			blocked.erase(Vector2i(x, y))


func check_exits() -> void:
	if player == null or player.frozen or _changing:
		return
	var c := player.cell()
	for e in exits:
		if (e["rect"] as Rect2i).has_point(c):
			go_to(str(e["scene"]), e["spawn"], str(e["facing"]))
			return


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


## Interiors lay furniture out by its declared width; big kit art must not wall
## off the room (it once boxed in counters and the town hall door).
var exact_footprints := false


func prop(group: String, name: String, c: Vector2i, extra_w := 0, dy := 0.0, solid := true, scale := 0.5) -> Sprite2D:
	var s := Art.sprite(group, name)
	if s == null:
		return null
	s.scale = Vector2(scale, scale)
	s.position = cell_pos(c.x + (extra_w + 1) / 2.0, c.y + 1) + Vector2(0, dy)
	add_child(s)
	props[c] = s
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
	return s


## A building drawn large (scale 1.0 = full 2x art, "realistically" big next to a 26 px
## hero): its footprint is blocked, the door cell (bottom-centre, one row below
## the base) opens `interior`. Returns the door cell.
var _building_doors := {}  # every cell a building covers -> its door cell


func building(name: String, c: Vector2i, interior := "", hint := "", scale := 1.0) -> Vector2i:
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
	queue_redraw()


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
func find_path(from: Vector2i, to: Vector2i, max_cells := 6000) -> Array:
	if from == to:
		return []
	var ok := func(c: Vector2i) -> bool:
		return in_content(c) and not blocked.has(c) and not is_water_cell(c)
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
	if props.has(c):
		(props[c] as Node).queue_free()
		props.erase(c)


## Boss intro card (ui/card_<kind>): slides in over the screen for a couple of seconds.
func boss_card(kind: String, title := "") -> void:
	var nm: String = {"big_grump": "card_big_grump", "thug_brute": "card_thug_brute", "president": "card_president", "marsh_witch": "card_marsh_witch", "golem_king": "card_golem_king", "dark_crystal": "card_dark_crystal", "ruin_warden": "card_ruin_warden", "commander": "card_president"}.get(kind, "")
	if kind.begins_with("card:"):
		nm = kind.trim_prefix("card:")
	if nm == "" or not Art.has("ui", nm):
		return
	var layer := CanvasLayer.new()
	layer.layer = 11
	var tr := TextureRect.new()
	tr.texture = Art.tex("ui", nm)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(250, 84)
	tr.size = Vector2(250, 84)
	tr.position = Vector2(290, 180)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(tr)
	var lbl := Label.new()
	lbl.text = title if title != "" else kind.replace("_", " ").capitalize()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	lbl.position = Vector2(110, 30)
	lbl.size = Vector2(130, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr.add_child(lbl)
	add_child(layer)
	Music.instance(get_tree()).sfx("levelup")
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
func allies() -> Array:
	var out: Array = []
	if pet != null and is_instance_valid(pet) and pet.visible and not Pet.resting() and int(Pet.state().get("hp", 0)) > 0:
		out.append(pet)
	for n in get_tree().get_nodes_in_group("allies"):
		if n is Node2D and n != pet and is_instance_valid(n):
			out.append(n)
	return out


func attack_at(r: Rect2, damage: int, from := Vector2.INF) -> bool:
	Music.instance(get_tree()).sfx("swing")
	var hit := false
	if from == Vector2.INF:
		from = player.position
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		# Enemies have a body ~12px wide, 14 tall above their feet.
		var body := Rect2(e.position + Vector2(-6, -14), Vector2(12, 14))
		if r.intersects(body):
			var crit := randf() < 0.03 * GameState.skill_level("combat") + GameState.bonus("combat", "crit")
			var dmg := damage * (2 if crit else 1)
			e.provoke(player)
			if e.hit(dmg, from):
				hit = true
				fx("spark", e.position + Vector2(0, -8), 18.0, 0.5)
				damage_number(e.position + Vector2(0, -20), e.last_applied, Color(1, 0.95, 0.4) if crit else Color.WHITE)
				# Weight: a short freeze and a nudge of the camera; more on a kill or a crit.
				var killed: bool = (not is_instance_valid(e)) or (not e._alive)
				hitstop = maxf(hitstop, 0.08 if (killed or crit) else 0.035)
				shake(3.0 if killed else (2.0 if crit else 1.2))
	if hit:
		Music.instance(get_tree()).sfx("hit")
		if hitstop >= 0.08:
			Music.instance(get_tree()).sfx("crit")
	return hit


## Short freeze on a solid hit (Stardew-style weight). Counted down in _process.
func shake(amount: float) -> void:
	var cam := player.get_node_or_null("Camera2D") if player else null
	if cam == null:
		for ch in player.get_children():
			if ch is Camera2D:
				cam = ch
	if cam == null:
		return
	var c := cam as Camera2D
	var tw := c.create_tween()
	for i in 3:
		tw.tween_property(c, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(c, "offset", Vector2.ZERO, 0.04)


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
	Music.instance(get_tree()).sfx("pickup")
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
				return true
			GameState.add_item(sel, -1)
			player.play_tool("hold")
			fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.8)
			hud.toast("%d crop%s leap a day ahead." % [grew, "" if grew == 1 else "s"], Color(0.7, 1, 0.7))
			queue_redraw()
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
		Music.instance(get_tree()).sfx("pickup")
		return true
	if it.has("heal") or it.has("energy") or it.has("mana") or it.has("buff"):
		player.play_tool("eat")
		var fx_out := GameState.consume(sel)
		effect_text(player.position, fx_out)
		hud.toast("Ate %s." % GameState.item_name(sel))
		Music.instance(get_tree()).sfx("pickup")
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
	var c0 := world_to_cell(at)
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
				return at if r == 0 else cell_center(c)
	return at


func on_enemy_died(e: Enemy) -> void:
	if e.has_meta("story_flag"):
		GameState.run["flags"][str(e.get_meta("story_flag"))] = true
		shake(3.0)
	GameState.run["kills"] = int(GameState.run.get("kills", 0)) + 1
	GameState.run["crystals"] = int(GameState.run["crystals"]) + e.reward
	hud.toast("+%d crystals" % e.reward, Color(0.7, 0.9, 1))
	var ed: Dictionary = GameState.enemy_data.get("enemies", {}).get(e.kind, {})
	xp("combat", maxi(1, int(round(int(ed.get("xp", 2)) * GameState.tier_scale(e.kind, e.tier, "xp")))))
	var table: Array = GameState.enemy_data.get("drops", {}).get(e.kind, [])
	var got := GameState.roll_drops(table)
	if e.tier > GameState.enemy_tier(e.kind) and randf() < 0.5 * GameState.tier_scale(e.kind, e.tier, "loot"):
		var extra := GameState.roll_drops(table)
		for id: String in extra:
			got[id] = int(got.get(id, 0)) + int(extra[id])
	for id: String in got:
		pop_items(e.position, id, int(got[id]))
	var kc: Dictionary = GameState.run.get("kill_counts", {})
	kc[e.kind] = int(kc.get(e.kind, 0)) + 1
	GameState.run["kill_counts"] = kc
	Music.instance(get_tree()).sfx("die")


func nearest_enemy_to(p: Vector2, within: float) -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if is_instance_valid(e) and e.position.distance_to(p) < within:
			if best == null or e.position.distance_to(p) < best.position.distance_to(p):
				best = e
	return best


## Out of health: you wake in the clinic, and the nurse keeps 10% of your crystals.
## Out of time (2am) or energy: someone carries you home, and keeps 5% for the trouble.
func player_down(reason := "hurt") -> void:
	if _changing:
		return
	if reason == "hurt" and GameState.bonus("pup", "rescue") > 0.0 and pet and pet.visible and int(Pet.state().get("rescued_day", 0)) != int(GameState.run["day"]):
		Pet.state()["rescued_day"] = int(GameState.run["day"])
		GameState.run["hp"] = 20
		player.invuln = 2.0
		hud.toast("%s drags you back to your feet!" % Pet.name_of(), Color(1, 0.9, 0.6))
		emote(pet, "heart", 1.5)
		return
	_changing = true
	player.frozen = true
	var cr := int(GameState.run["crystals"])
	var rate := 0.10 if reason == "hurt" else 0.05
	if reason == "hurt":
		if GameState.has_friend_perk("juniper", 6):
			rate = 0.0
		elif GameState.has_friend_perk("juniper", 2):
			rate = 0.05
	var fee := int(ceil(cr * rate))
	hud.toast("You collapsed..." if reason == "hurt" else "You pass out...", Color(1, 0.6, 0.6))
	await hud.fade_out(1.0)
	GameState.run["crystals"] = maxi(0, cr - fee)
	if Net.online() and not Net.is_host():
		# A guest's night is the host's: wake up when the host's day rolls over.
		GameState.run["energy"] = int(GameState.run["max_energy"]) / 2
		GameState.run["hp"] = maxi(int(GameState.run["hp"]), int(GameState.run["max_hp"]) / 2)
	else:
		GameState.sleep(true)
	GameState.run["flags"]["wake_note"] = ("Nurse Ada patched you up at the clinic. Fee: ◆%d (10%%)." % fee) if reason == "hurt" else ("Someone found you and carried you home. ◆%d (5%%) went missing on the way." % fee)
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
		if (e["rect"] as Rect2i).has_point(c):
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
	var e := nearest_enemy_to(world, 14.0)
	if true:
		if e:
			player.go_to_cell(world_to_cell(e.position - Vector2(0, 2)), true)
		elif has_npc_at(c):
			player.go_to_cell(c, true)
		elif things.has(c) and (hint_for(c, things[c]) != "" or things[c].get("type") == "plot"):
			player.go_to_cell(c, true)
		elif not blocked.has(c) or _exit_at(c):
			player.go_to_cell(c, false)


func has_npc_at(_c: Vector2i) -> bool:
	return false


# ---- time --------------------------------------------------------------------

var _job_check := 0


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
	if get_tree().paused:
		return
	# Clamp: a phone coming back from the background reports one huge frame;
	# that must not fast-forward the clock by hours.
	_time_acc += minf(delta, 0.25) * GameState.MINUTES_PER_SECOND
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
	if t >= GameState.DAY_END and not _changing:
		player_down("late")
	elif int(GameState.run["energy"]) <= 0 and not _changing and not player.frozen:
		player_down("tired")
	# Mana trickles back: 1 point every 20 game minutes (Attunement: 15, 10).
	var regen_every := maxi(5, 20 - 5 * int(GameState.bonus("magic", "mana_regen")))
	if t % regen_every == 0 and t != _last_mana_t:
		_last_mana_t = t
		GameState.restore_mana(1)
	# Evening tint from 6pm, darkest by midnight.
	var dark := clampf((t - 18 * 60) / 360.0, 0.0, 1.0)
	if int(GameState.run["flags"].get("glow_day", -1)) == int(GameState.run["day"]):
		dark *= 0.3
	# The gangster arc is a darker world: overcast by day, deeper at night.
	var day_col := Color(0.84, 0.86, 0.93) if Racket.on() and has_sky else Color(1, 1, 1)
	_night.color = day_col.lerp(Color(0.38, 0.42, 0.7) if Racket.on() else Color(0.45, 0.5, 0.8), dark * (0.7 if Racket.on() else 0.6))
	if player and hud:
		var fc := player.facing_cell()
		hud.set_hint(hint_for(fc, things.get(fc, {})))
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
	_transitioning = true
	_changing = true
	player.frozen = true
	next_spawn = spawn
	next_facing = facing
	# Save as if already there, so closing the app mid-fade resumes on arrival.
	var prev_scene: Variant = GameState.run.get("scene", "")
	GameState.run["scene"] = scene
	GameState.run["spawn"] = [spawn.x, spawn.y, facing]
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


func give(id: String, n := 1) -> void:
	_check_quests.call_deferred()
	GameState.add_item(id, n)
	hud.toast("+%d %s" % [n, GameState.item_name(id)], Color(0.85, 1, 0.85))
	Music.instance(get_tree()).sfx("pickup")
	if player:
		fx("sparkle", player.position + Vector2(0, -14), 14.0, 0.5)


func xp(skill: String, n: int) -> void:
	if GameState.add_xp(skill, n):
		hud.toast("%s level %d!" % [skill.capitalize(), GameState.skill_level(skill)], Color(1, 0.9, 0.4))
		Music.instance(get_tree()).sfx("levelup")
		if player:
			fx("levelup", player.position + Vector2(0, -4), 10.0, 0.6)


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
	if _anim_layer:
		_anim_layer.jobs.clear()
	draw_set_transform(offset())
	draw_map()
	if not _ext_paths.is_empty():
		draw_ground("dirt", _ext_paths)
		draw_exits()
	if pad > 0:
		draw_border()
	draw_set_transform(Vector2.ZERO)


## Subclasses draw their ground here (content coordinates; the pad offset is applied).
func draw_map() -> void:
	pass


var _tall := {}


func draw_grass(seed_v := 1, r := Rect2i(0, 0, 0, 0)) -> void:
	if r.size == Vector2i.ZERO:
		r = Rect2i(-pad, -pad, cols + 2 * pad, rows + 2 * pad)
	_deco_rng.seed = seed_v
	var gname := GameState.grass_tile()
	var has_tiles := Art.has("tiles", gname)
	var season := GameState.season()
	# Natural variation: patches of tall / flowery / dry grass from low-frequency noise.
	var patchy := season in ["spring", "summer"] and Art.has("tiles", "g_tall") and Art.has("tiles", "g_dry")
	_tall.clear()
	var sd := hash(scene_id()) % 1000 + seed_v
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := Vector2(x * TILE, y * TILE)
			if has_tiles:
				var tname := gname
				var gv := Art.has("tiles", "gv_short_0")
				var hv := absi((x * 73856093) ^ (y * 19349663))
				if gv:
					var base: String = {"spring": "gv_short", "summer": "gv_short", "fall": "gv_autumn", "winter": "gv_snow"}.get(season, "gv_short")
					Art.draw_tile(self, "tiles", "%s_%d" % [base, hv % 12 if hv % 7 == 0 else hv % 4], at, 0)
					if patchy:
						var n := WorldGen.fbm(float(x), float(y), sd, 9.0)
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
				if season == "spring" and _deco_rng.randf() < 0.07:
					Art.draw_tile(self, "tiles", "deco_%d" % _deco_rng.randi_range(0, 5), at)
			else:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color("5a9e4b") if (x + y) % 2 == 0 else Color("67ab55"))
	if not _tall.is_empty() and Art.has("tiles", "tall_edge_top_0"):
		for c: Vector2i in _tall:
			var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
			Art.draw_tile(self, "tiles", "gv_tall_%d" % (hv % 12), Vector2(c * TILE), 0)
		Art.draw_blob(self, _tall, "tall_edge", 16.0, 0)


## Ground region with real grass transitions (W1 sets) when available.
## kind: "dirt" | "sand" | "stone". Falls back to draw_tileset_rect.
func draw_ground(kind: String, cells_in: Dictionary) -> void:
	var tset := "t_" + kind
	var fill: String = {"dirt": "dirt", "sand": "sand", "stone": "g_gravel"}.get(kind, "dirt")
	var blob: String = {"dirt": "path_dirt", "sand": "path_sand", "stone": "path_cobble", "cobble": "path_cobble", "snow": "path_snow"}.get(kind, "")
	# Prompts 10 clean path sets (smooth rims, seamless fills) when sliced.
	var blob2: String = {"cobble": "path2_cobble", "stone": "path2_cobble"}.get(kind, "")
	if blob2 != "" and Art.has("tiles", blob2 + "_top_0"):
		var cells2 := widen_path(cells_in)
		for c: Vector2i in cells2:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hash(blob2))
			Art.draw_tile(self, "tiles", "%s_fill_%d" % [blob2, h % 42], Vector2(c * TILE), 0)
			if h % 17 == 0 and _blob_interior(cells2, c) and Art.has("tiles", "%s_deco_%d" % [blob2, h / 17 % 36]):
				Art.draw_tile(self, "tiles", "%s_deco_%d" % [blob2, h / 17 % 36], Vector2(c * TILE), 0)
		Art.draw_blob(self, cells2, blob2, 16.0, 0)
		return
	if blob != "" and Art.has("tiles", blob + "_top_0"):
		# Paths are never one cell wide: a 1-wide strip is all edge tiles and reads
		# as a chain of little boxes. Widen to 2 so there is a real middle.
		var cells := widen_path(cells_in)
		# Plain fill under everything (the blob set's fill variants are mostly
		# decals: pebbles, puddles, ruts) with an occasional decal, then edges.
		for c: Vector2i in cells:
			var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ hash(blob))
			var plain := ""
			match kind:
				"dirt": plain = "path_dirt_fill_%d" % (7 + h % 5)
				"sand": plain = "sand_fill_%d" % (h % 12) if Art.has("tiles", "sand_fill_0") else "sand"
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
func draw_water(cells: Dictionary, shore := "grass") -> void:
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
			Art.draw_tile(ci, "tiles", "%s_fill_%d" % [shore, idx], Vector2(c * TILE), 0)
	if custom or Art.has("tiles", "shore_grass_top_0"):
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


func draw_fence_border(col := Color("6b4a2b")) -> void:
	if Art.has("buildings", "fence_h"):
		for x in cols:
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, TILE))
			Art.draw_prop(self, "buildings", "fence_h", Vector2(x * TILE + TILE / 2.0, rows * TILE))
		for y in range(1, rows - 1):
			Art.draw_prop(self, "buildings", "fence_v", Vector2(TILE / 2.0, (y + 1) * TILE))
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
func draw_plateau(cells: Dictionary, prefix := "cliffg", stairs: Dictionary = {}) -> void:
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
func draw_rock_mass(cells: Dictionary) -> void:
	var wall: String = {"marsh": "wall_marsh", "highlands": "wall_highlands", "ruins": "wall_ruins", "riverlands": "wall_river"}.get(scene_id(), "")
	if wall != "" and Art.has("tiles", wall + "_0"):
		# Region-themed border wall (Prompts 10): the inner edge of the band is a
		# two-tile-tall wall facing the player; deeper cells are plain dark fill.
		var n := 0
		while Art.has("tiles", "%s_%d" % [wall, n]):
			n += 1
		for c: Vector2i in cells:
			draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.08, 0.07, 0.1))
		for c: Vector2i in cells:
			var below := c + Vector2i(0, 1)
			if cells.has(below):
				continue
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			var t := Art.tex("tiles", "%s_%d" % [wall, h % n])
			if t:
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
	if Art.has("tiles", "cliff_top_0"):
		# Raised rock plateau with real edges on every side (W28 cliff set), so a
		# blocked cliff band always reads as a wall, never as floor.
		var fill := "mf_stone" if Art.has("tiles", "mf_stone") else "g_gravel"
		for c: Vector2i in cells:
			Art.draw_tile(self, "tiles", fill, Vector2(c * TILE), 4)
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			if h % 7 == 0 and Art.has("tiles", "rdeco_quarry_%d" % (h / 7 % 9)):
				Art.draw_tile(self, "tiles", "rdeco_quarry_%d" % (h / 7 % 9), Vector2(c * TILE), 0)
		Art.draw_blob(self, cells, "cliff", 16.0, 1)
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
		for y in range(-pad, rows + pad):
			for x in range(-pad, cols + pad):
				var c := Vector2i(x, y)
				if (r.position.y <= 0 and c.y < r.end.y and c.x >= g.position.x and c.x < g.end.x) \
				or (r.end.y >= rows and c.y >= r.position.y and c.x >= g.position.x and c.x < g.end.x) \
				or (r.position.x <= 0 and c.x < r.end.x and c.y >= g.position.y and c.y < g.end.y) \
				or (r.end.x >= cols and c.x >= r.position.x and c.y >= g.position.y and c.y < g.end.y):
					open[c] = true
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
			var side := _side_of(c)
			var kind := border_kind(side)
			var n := WorldGen.fbm(float(c.x), float(c.y), sd, 9.0) * amp
			# depth > 0 is outside the content; the band starts where depth + n > 1.
			var filled := depth + n > 1.2
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
			if in_content(c) and depth + n < 2.0 and (c.x + c.y) % 3 == 0:
				continue  # ragged inner edge
			blocked[c] = true
			match kind:
				"trees": _border_cells[c] = "tree"
				"cliff": _border_cells[c] = "cliff"
				"water": _border_cells[c] = "water"
				_: _border_cells[c] = "void"
	# Trees: sparse at the inner edge, dense and large deeper in.
	var rng := _border_rng
	for c: Vector2i in _border_cells:
		if _border_cells[c] != "tree":
			continue
		var depth := _band_depth(c)
		var chance := 0.35 if depth <= 1 else (0.6 if depth == 2 else 0.8)
		if rng.randf() > chance:
			continue
		var nm := GameState.tree_sprite(rng.randi_range(0, 2))
		if Art.has("nature", "big_oak_a"):
			var season := GameState.season()
			var mids: Array = {"spring": ["mid_oak", "mid_pine", "mid_birch", "mid_cherry", "mid_oak_b"], "summer": ["mid_oak", "mid_pine", "mid_birch", "mid_willow", "mid_oak_b"], "fall": ["mid_maple", "mid_oak", "mid_pine", "mid_maple_b", "mid_dead"], "winter": ["mid_snowpine", "mid_dead", "mid_snowpine_b", "mid_pine", "mid_dead_b"]}.get(season, ["mid_oak", "mid_pine"])
			var bigs: Array = {"spring": ["big_oak_a", "big_oak_b", "big_pine_a", "big_birch_a", "big_cherry_a", "big_oak_c"], "summer": ["big_oak_a", "big_oak_b", "big_pine_b", "big_birch_b", "big_willow", "big_oak_c"], "fall": ["big_maple_a", "big_maple_b", "big_oak_a", "big_pine_a", "big_dead_a"], "winter": ["big_snowpine_a", "big_snowpine_b", "big_dead_a", "big_dead_b", "big_pine_c"]}.get(season, ["big_oak_a"])
			nm = str(mids[rng.randi_range(0, mids.size() - 1)]) if depth <= 2 or rng.randf() < 0.4 else str(bigs[rng.randi_range(0, bigs.size() - 1)])
		if depth <= 1 and in_content(c + Vector2i(0, 1)) and not _border_cells.has(c + Vector2i(0, 1)):
			prop("nature", nm, c, 0, 0.0, false)  # inner-edge trees are props so you walk behind the canopy
		else:
			_border_draw.append([c, "nature", nm, rng.randf_range(-3.0, 3.0)])
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
	var water := {}
	var cliff := {}
	var treec := {}
	for c: Vector2i in _border_cells:
		match _border_cells[c]:
			"water": water[c] = true
			"cliff": cliff[c] = true
			"tree": treec[c] = true
			"void": draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.05, 0.05, 0.08))
	# Exit corridors through the band are dirt track.
	if not _border_open.is_empty():
		var corridor := {}
		for c: Vector2i in _border_open:
			if not blocked.has(c):
				corridor[c] = true
		draw_ground("dirt", corridor)
	if not water.is_empty():
		draw_water(water, "sand" if Art.has("tiles", "t_water_sand") and GameState.run["scene"] == "beach" else "grass")
	if not cliff.is_empty():
		draw_rock_mass(cliff)
	# Forest floor only under the deep part of the tree mass, with a soft edge.
	for c: Vector2i in treec:
		if _band_depth(c) >= 3 or ((c.x * 5 + c.y * 3) % 4 == 0 and _band_depth(c) == 2):
			if not Art.draw_tile(self, "tiles", "forest_floor", Vector2(c * TILE), 4):
				draw_rect(Rect2(c * TILE, Vector2i(TILE, TILE)), Color(0.2, 0.35, 0.18, 0.6))
	for item: Array in _border_draw:
		var c: Vector2i = item[0]
		Art.draw_prop(self, str(item[1]), str(item[2]), Vector2(c * TILE) + Vector2(TILE / 2.0 + float(item[3]), TILE))


## Shared fishing minigame: cast, wait for the bite, press A. `pool` is the
## water's fish from easiest to rarest; skill, night light, rain and perks
## reach deeper into it.
func fish_at(c: Vector2i, pool: Array) -> void:
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
	var speed := 1.0 - GameState.bonus("fishing", "bite_speed") - (0.1 if GameState.has_friend_perk("finn", 2) else 0.0) - (0.1 if Sanctuary.on() and Builds.is_built("pool") else 0.0)
	var night: bool = int(GameState.run["time"]) >= 19 * 60 and GameState.run["flags"].has("lighthouse_lit")
	var wait := randf_range(1.5, 4.5) * maxf(0.4, speed) * (0.7 if night else 1.0) * (0.75 if GameState.is_wet() else 1.0)
	var t := 0.0
	var bite := false
	var caught := false
	var tree := get_tree()
	while t < wait + 1.0:
		await tree.process_frame
		if not is_inside_tree():
			return  # the map changed under the line (scene change, collapse)
		t += get_process_delta_time()
		if not bite and t >= wait:
			bite = true
			hud.toast("!!!  Press A!", Color(1, 1, 0.4))
			fx("alert", player.position + Vector2(0, -26), 10.0, 0.5)
			Music.instance(get_tree()).sfx("bite")
			if bob:
				bob.play("bite")
		if (Input.is_action_just_pressed("a") or Input.is_action_just_pressed("tool") or Input.is_action_just_pressed("action")) and t > 0.2:
			caught = bite
			break
	player.frozen = false
	if bob:
		fx("reel_splash" if Art.has("fx", "reel_splash") else "splash", bob.position, 12.0, 0.5)
		if caught and Art.has("fx", "fish_jump_a"):
			fx(["fish_jump_a", "fish_jump_b", "fish_jump_c"][randi() % 3], bob.position + Vector2(0, 4), 12.0, 0.5, player.facing == "left")
		bob.queue_free()
	if caught:
		var lvl := GameState.skill_level("fishing")
		var reach := mini(pool.size(), 2 + lvl * 2 + (2 if night else 0))
		var fish: String = pool[randi() % reach] if randf() > 0.08 else "boot"
		if randf() < GameState.bonus("fishing", "rare_fish") + (0.1 if GameState.has_friend_perk("finn", 8) else 0.0):
			fish = pool[mini(pool.size() - 1, reach + 1)]
		player.play_tool("reel")
		give(fish)
		if randf() < GameState.bonus("fishing", "double_fish"):
			give(fish)
		if randf() < GameState.bonus("fishing", "chest_chance"):
			give(["old_coin", "pearl", "map_scrap"][randi() % 3])
		xp("fishing", 6)
	else:
		hud.toast("It got away.")
