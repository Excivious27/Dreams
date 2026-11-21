extends SceneTree
## C17 P6 (c17_15-18 / c17_15-21): a late, maxed-out host world must fit the relay's
## HOST_CAP with room to spare (an oversize snapshot is dropped silently and late
## joiners get nothing), and the host's 2 s push (build + world_delta + copy) must
## stay cheap enough for a phone host. Prints sizes and timings; names the biggest key.
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(15)
	_run.call_deferred()


func _max_world() -> void:
	GameState.new_run("penguins", "kairi", "T", "Town", "Pup")
	var farm := {}
	var crops := ["turnip", "beet", "carrot", "pumpkin", "melon", "starfruit", "corn", "wheat"]
	for y in 60:
		for x in 80:
			farm["%d,%d" % [x, y]] = {"watered": randi() % 2 == 0, "crop": crops[randi() % crops.size()], "days": randi() % 12, "q": randi() % 3, "fert": "basic" if randi() % 3 == 0 else ""}
	GameState.run["farm"] = farm
	var placed := {}
	for i in 200:
		placed["%d,%d" % [i % 80, 60 + i / 80]] = "keg" if i % 2 == 0 else "preserves_jar"
	GameState.run["placed"] = placed
	var cleared := {}
	for s in 45:
		var cells: Array = []
		for i in 150:
			cells.append("%d,%d" % [randi() % 120, randi() % 120])
		cleared["scene_%d" % s] = cells
	GameState.run["cleared"] = cleared
	var builds := {}
	for b in ["house", "barn", "coop", "shed", "silo", "well", "kitchen", "smith", "loom", "kiln", "pool", "burrow", "launchpad", "greenhouse", "stable", "workshop"]:
		builds[b] = 3
	GameState.run["builds"] = builds
	var animals := {}
	for i in 60:
		animals["a%d" % i] = {"kind": "cow" if i % 2 == 0 else "chicken", "name": "Name%d" % i, "hearts": randi() % 10, "fed": true, "pet": true, "age": randi() % 200, "mood": randi() % 100, "home": "barn" if i % 2 == 0 else "coop", "made": randi() % 3}
	var rn: Variant = GameState.run.get("ranch", {})
	if not (rn is Dictionary):
		rn = {}
	rn["animals"] = animals
	GameState.run["ranch"] = rn
	var con := {}
	for i in 6:
		con["site_%d" % i] = {"id": "bridge_%d" % i, "left": 2, "paid": true}
	GameState.run["construction"] = con


func _world(n: Variant) -> Dictionary:
	var d := {}
	for k in n.WORLD_KEYS:
		if k == "decor_home":
			d[k] = DecorMode.home_view()
		elif GameState.run.has(k):
			d[k] = GameState.run[k]
	return d


func _run() -> void:
	var n: Variant = Net.i()
	if n == null:
		check(false, "NetSvc autoload present")
		print("net_size_test: %d checks, %d failures" % [checks, fails])
		quit(1)
		return
	_max_world()
	var d := _world(n)
	var full := JSON.stringify({"t": "host_save", "d": d}).length()
	var big := ""
	var big_n := 0
	for k in d:
		var l := JSON.stringify(d[k]).length()
		if l > big_n:
			big_n = l
			big = str(k)
	print("  max world: %d KB (HOST_CAP %d KB), biggest key %s %d KB" % [full / 1024, NetTransport.HOST_CAP / 1024, big, big_n / 1024])
	check(full < int(NetTransport.HOST_CAP * 0.4), "a maxed host world fits 40%% of HOST_CAP (%d KB; biggest key %s)" % [full / 1024, big])
	# The 2 s push: build the world, diff it, keep a copy (net.gd _push_world), 20 times.
	var pushed: Dictionary = d.duplicate(true)
	var times: Array = []
	var dsize := 0
	for i in 20:
		GameState.run["time"] = 600 + i * 10
		var key := "%d,%d" % [randi() % 80, randi() % 60]
		GameState.run["farm"][key] = {"watered": true, "crop": "beet", "days": i, "q": 0, "fert": ""}
		var t0 := Time.get_ticks_usec()
		var w := _world(n)
		var delta: Dictionary = NetNode.world_delta(pushed, w)
		pushed = w.duplicate(true)
		times.append(Time.get_ticks_usec() - t0)
		dsize = maxi(dsize, JSON.stringify(delta).length())
	times.sort()
	var med := int(times[times.size() / 2])
	print("  push median %.2f ms, max delta %d bytes" % [med / 1000.0, dsize])
	check(dsize < 2048, "a typical push delta stays under 2 KB (%d bytes)" % dsize)
	# Timing is printed for the record; the bound is loose (CI runners vary) and catches only a blow-up.
	check(med < 60000, "host push median under 60 ms on CI (%.2f ms)" % (med / 1000.0))
	print("net_size_test: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
