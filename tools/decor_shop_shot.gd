extends SceneTree
## Screenshot of the decor shelf screen with a few injected catalogue pieces (C10a P4).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/decor_shop_shot.gd -- /tmp/out
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	InputSetup.ensure_actions()
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	GameState.run["crystals"] = 900
	Decor._data = {"items": {
		"dc_a": {"name": "Oak Stool", "cat": "furniture", "rarity": "common", "price": 120, "icon": "items/wood", "size": [1, 1]},
		"dc_b": {"name": "Brass Reading Lamp", "cat": "light", "rarity": "uncommon", "price": 340, "icon": "items/lamp_oil", "size": [1, 1]},
		"dc_c": {"name": "Starry Rug", "cat": "rug", "rarity": "rare", "price": 800, "icon": "items/cotton", "size": [2, 2]},
		"dc_d": {"name": "Crystal Chandelier of the Old Sun", "cat": "light", "rarity": "epic", "price": 2400, "icon": "items/crystal_refined", "size": [2, 1]},
		"dc_e": {"name": "Honey Jar Shelf", "cat": "decor", "rarity": "common", "price": 90, "icon": "items/honey", "size": [1, 1]}},
		"shops": {"maple": ["dc_a", "dc_b", "dc_c", "dc_d", "dc_e"]}, "pools": {}, "sets": {}}
	var s := DecorShopScreen.new()
	s.shop = "store"
	s.who = "Maple"
	root.add_child(s)
	for i in 12:
		await process_frame
	s.sel = 1
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/decor_shop.png")
	paused = false
	quit()
