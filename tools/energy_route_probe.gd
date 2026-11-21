extends SceneTree
## Tom's C16a energy case, measured on real mine layouts: gang arc, level 1, wood
## tools, day 1. Builds floors 1-3 with 15 force_seeds each and prints each floor's
## keeper threshold (tries), rock count and the day-1 energy one try costs, then
## the whole route (meadow fight + floor 1 + half of floor 2) as a share of the bar.
## Run: godot --headless --path . -s res://tools/energy_route_probe.gd -- [max_pct]
## Exit 1 when the route mean is above max_pct (default 40).

const SEEDS := 15
var out := {}


func _initialize() -> void:
	Campaign.bypass = true
	seed(77)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var max_pct := 40.0
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		max_pct = float(a[0])
	InputSetup.ensure_actions()
	GameState.new_run("gangsters", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	GameState.run["flags"]["mine_seen"] = true
	var means := [0.0, 0.0, 0.0, 0.0]
	for fl in [1, 2, 3]:
		var tot := 0
		var lo := 999
		var hi := 0
		for s in SEEDS:
			GameState.run["mine_floor"] = fl
			GameState.run["mine_pace"] = {}
			GameState.run["mine_thresh"] = {}
			(load("res://scripts/mine.gd") as Variant).force_seed = 1000 + s * 37 + fl
			GameMap.next_spawn = Vector2.ZERO
			change_scene_to_file("res://scenes/mine.tscn")
			await frames(6)
			var m := current_scene
			var t := int(m.call("_threshold"))
			tot += t
			lo = mini(lo, t)
			hi = maxi(hi, t)
		means[fl] = float(tot) / SEEDS
		print("FLOOR %d threshold mean %.1f min %d max %d" % [fl, means[fl], lo, hi])
	# One try = one rock: 83% stone (hits_for 2), 17% ore (hits_for 4), measured by the C16a audit.
	var swings := 0.83 * GameState.hits_for(2, "pickaxe") + 0.17 * GameState.hits_for(4, "pickaxe")
	var per_try := swings * GameState.energy_cost_f("pickaxe")
	var fight := 40.0 * GameState.energy_cost_f("sword") + 4.0 * GameState.energy_cost_f("dodge")
	var bar := float(GameState.run["max_energy"])
	var route: float = fight + means[1] * per_try + 0.5 * means[2] * per_try + 1.5 * fight
	var pct: float = 100.0 * route / bar
	print("SWING pickaxe %.3f sword %.3f dodge %.3f swings/rock %.2f energy/try %.2f" % [GameState.energy_cost_f("pickaxe"), GameState.energy_cost_f("sword"), GameState.energy_cost_f("dodge"), swings, per_try])
	print("ROUTE meadow fight %.1f + floor1 %.1f + half floor2 %.1f + mine fights %.1f = %.1f of %d (%.0f%%)" % [fight, means[1] * per_try, 0.5 * means[2] * per_try, 1.5 * fight, route, int(bar), pct])
	quit(0 if pct <= max_pct else 1)
