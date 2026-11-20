extends SceneTree
## Gangster interior skins (c5_04 #1): interiors.json "gangsters" blocks applied by
## Interior.arc_skin. Every skinned room keeps valid art, cells inside its walls,
## no penguin-arc words, and the penguin arc sees the room unchanged.
##   godot --headless --path . -s res://tools/interior_skin_test.gd
const Interior := preload("res://scripts/interior.gd")
const BAD := ["grump", "crystal", "penguin", "catkins", "the cat"]
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("SKIN FAIL: ", msg)

func _check_room(id: String, r: Dictionary, label: String) -> void:
	var cols := int(r.get("cols", 14))
	var rows := int(r.get("rows", 11))
	_ok(Art.has("tiles", str(r.get("floor", "fl_wood"))), "%s %s floor art %s" % [label, id, r.get("floor")])
	_ok(Art.has("tiles", str(r.get("wall", "wl_plaster")) + "_m"), "%s %s wall art %s" % [label, id, r.get("wall")])
	for p: Dictionary in r.get("props", []):
		var g := str(p.get("group", "furniture"))
		_ok(Art.has(g, str(p["name"])), "%s %s prop art %s/%s" % [label, id, g, p["name"]])
		var c: Array = p["cell"]
		_ok(int(c[0]) >= 1 and int(c[0]) < cols - 1 and int(c[1]) >= 1 and int(c[1]) < rows - 1, "%s %s prop %s inside the walls %s" % [label, id, p["name"], c])
	var words := (str(r.get("intro", "")) + " " + JSON.stringify(r.get("things", []))).to_lower()
	for w in BAD:
		_ok(not (w in words), "%s %s still says '%s'" % [label, id, w])

func _run() -> void:
	var all := GameState.load_json("res://data/interiors.json")
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var lib: Dictionary = all["library"]
	_ok(Interior.arc_skin(lib) == lib, "penguin arc: rooms unchanged")
	_ok(Interior.skin_name("cottage_c") == "", "penguin arc: room labels unchanged")
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	var n := 0
	for id: String in all:
		var r: Dictionary = all[id]
		if not (r.get("gangsters") is Dictionary) or bool(r.get("rec", false)):
			continue
		n += 1
		var sk: Dictionary = Interior.arc_skin(r)
		_ok(not sk.has("gangsters"), "%s skin block consumed" % id)
		_check_room(id, sk, "gang")
	_ok(n >= 12, "town rooms have a gangster skin (%d)" % n)
	_ok(not Interior.arc_skin(all["library"]).has("gangsters") and all["library"].has("gangsters"), "loaded data left untouched")
	# crew shops that moved in
	for f in ["shop_1", "shop_2", "shop_3", "crew_mama_rosa", "crew_halo", "crew_marlene"]:
		GameState.run["flags"][f] = true
	for pair in [["bakery", "Deuce"], ["cottage_c", "Specs"], ["clinic", "Doc"], ["inn", "Mama Rosa"], ["stable", "Halo"], ["chapel", "Marlene"]]:
		var sk: Dictionary = Interior.arc_skin(all[pair[0]])
		_ok(str(sk.get("intro", "")).contains(pair[1]), "%s shows %s's place once the flag is set" % pair)
		_check_room(pair[0], sk, "crew")
		_ok(Interior.skin_name(pair[0]).contains(pair[1]), "%s room label names %s" % pair)
	print("interior_skin_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
