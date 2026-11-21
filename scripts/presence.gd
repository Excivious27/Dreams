class_name Presence
## Steam rich presence (S1 P2, s1_05-07 / 05-12). Tokens: data/rich_presence.json
## (tools/gen_achievements.py). compute() picks one from the current scene and
## never uses the player's typed names (farm, town, character): places are fixed
## ASCII words. push() hands it to SteamService.set_rich_presence (no-op without
## Steam, on web, headless or DREAMS_NO_STEAM=1). Called from Achievements.scan().

const PATH := "res://data/rich_presence.json"
static var _data: Dictionary = {}
static var _last := ""


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_data = v
	return _data


## Fixed place word for a scene id (never a typed name; <= 32 ASCII chars).
static func place(scene: String) -> String:
	var rg := MegaTravel.region_of(scene)
	if rg != "":
		var nm := str(MegaTravel.reg(rg).get("name", rg.capitalize()))
		return nm.substr(0, 32) if nm.to_ascii_buffer().get_string_from_ascii() == nm else rg.capitalize()
	return scene.capitalize().substr(0, 32)


static func compute(scene: String) -> Dictionary:
	var keys := {}
	var token := ""
	if scene == "" or GameState.run.is_empty():
		token = "Menu"
	elif Net.online() and Net.i() and Net.i().peers.size() > 0:
		token = "Coop"
		keys["size"] = str(Net.i().peers.size() + 1)
		keys[str(data().get("group_size_key", "steam_player_group_size"))] = keys["size"]
	else:
		token = str(data().get("scene_map", {}).get(scene, ""))
		if token == "":
			token = "Region" if MegaTravel.region_of(scene) != "" else "Town"
		if token == "Region":
			keys["place"] = place(scene)
	if token == "Farm":
		keys["season"] = GameState.season().capitalize()
		keys["year"] = str((int(GameState.run.get("day", 1)) - 1) / 112 + 1)
	return {"token": token, "keys": keys}


static func push() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := ""
	if tree and tree.current_scene and tree.current_scene.has_method("scene_id"):
		scene = str(tree.current_scene.call("scene_id"))
	var p := compute(scene)
	var sig := str(p)
	if sig == _last:
		return
	_last = sig
	for k in p["keys"]:
		Achievements._steam("set_rich_presence", [str(k), str(p["keys"][k])])
	Achievements._steam("set_rich_presence", ["steam_display", "#" + str(p["token"])])
