extends SceneTree
## C16a P4 (c16a_08-12): bug net + Critter log. Data (every critter has an icon, a where line, value 0, never
## sold), Critters.catchable (season / hour rules), BugNet.swing on a live WorldGen.Critter (logged, let go,
## net tier and Foraging gates), Critters.legend_roll gates, museum Live Exhibit counts, shop offers the
## next net, after_buy swaps the toolbar slot. Both arcs.
##   godot --headless --path . --fixed-fps 60 -s res://tools/critter_net_test.gd
var fails := 0


func _initialize() -> void:
	Campaign.bypass = true
	seed(16)
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _critter(m: Node2D, kind: String, at: Vector2) -> Node2D:
	var cr := WorldGen.Critter.new()
	cr.kind = kind
	cr.position = at
	cr.home = at
	m.add_child(cr)
	return cr


func _run() -> void:
	InputSetup.ensure_actions()
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		# --- data ---
		ok(Collections.total("critters") >= 16, arc + ": critter log has entries (%d)" % Collections.total("critters"))
		for e: Dictionary in Collections.entries("critters"):
			var id := str(e["item"])
			ok(Art.has("items", Hud.icon_for(id)), "critter icon " + id)
			ok(str(e.get("where", "")) != "", "critter where " + id)
			ok(int(GameState.items[id].get("value", 1)) == 0 and str(GameState.items[id].get("type", "")) == "critter", "critter never sold " + id)
		for n in BugNet.NET_IDS:
			ok(str(GameState.items.get(n, {}).get("type", "")) == "tool" and Art.has("items", Hud.icon_for(n)), "net item " + n)
		# --- contract: Critters.catchable ---
		var day_summer := Critters.catchable("meadow", "summer", 12)
		ok(day_summer.has("cr_meadow_hopper") and not day_summer.has("cr_firefly"), arc + ": summer noon has hoppers, no fireflies")
		ok(Critters.catchable("meadow", "summer", 22).has("cr_firefly"), arc + ": fireflies at night")
		ok(not Critters.catchable("meadow", "winter", 12).has("cr_ladybug"), arc + ": no ladybugs in winter")
		ok(not Critters.catchable("meadow", "spring", 7).has("cr_petal_emperor"), arc + ": legends never in the plain list")
		# --- swing ---
		ok(BugNet.tier() == -1 and BugNet.shop_offer() == ["bug_net"], arc + ": Maple offers the Twig Net first")
		GameState.add_tool("bug_net")
		ok(BugNet.tier() == 0 and BugNet.shop_offer().is_empty(), arc + ": Silk Net waits for Foraging 15")
		var m := Node2D.new()
		root.add_child(m)
		var p := Node2D.new()
		root.add_child(p)
		GameState.run["energy"] = 200
		GameState.run["time"] = 12 * 60
		var cr := _critter(m, "ladybug", Vector2(10, 0))
		await process_frame
		var r := BugNet.swing(m, p)
		ok(r == "caught:cr_ladybug", arc + ": the Twig Net logs a ladybug (%s)" % r)
		ok(Collections.have("critters", "cr_ladybug") and Collections.have("museum", "cr_ladybug"), arc + ": logged + Live Exhibit")
		ok(GameState.count("cr_ladybug") == 0, arc + ": nothing goes in the bag (let go)")
		for i in 60:
			await process_frame
		ok(not is_instance_valid(cr) or cr.is_queued_for_deletion(), arc + ": the critter flies off after the catch")
		var far := _critter(m, "ladybug", Vector2(60, 0))
		await process_frame
		ok(BugNet.swing(m, p) == "none", arc + ": out of reach: nothing")
		far.queue_free()
		var ff := _critter(m, "firefly", Vector2(10, 0))
		await process_frame
		ok(BugNet.swing(m, p) == "blocked", arc + ": a firefly needs the Star Net")
		if is_instance_valid(ff):
			ff.queue_free()
		(GameState.run["skills"] as Dictionary)["foraging"] = {"level": 40, "xp": 0}
		ok(BugNet.shop_offer() == ["silk_net"], arc + ": Foraging 15+: Silk Net on offer")
		GameState.add_tool("silk_net")
		BugNet.after_buy("silk_net")
		ok(not (GameState.run["toolbar"] as Array).has("bug_net") and (GameState.run["toolbar"] as Array).has("silk_net"), arc + ": the Silk Net takes the Twig Net's slot")
		GameState.add_tool("star_net")
		BugNet.after_buy("star_net")
		ok(BugNet.tier() == 2 and BugNet.shop_offer().is_empty(), arc + ": Star Net is the top")
		GameState.run["time"] = 22 * 60
		_critter(m, "firefly", Vector2(10, 0))
		await process_frame
		r = BugNet.swing(m, p)
		ok(r == "caught:cr_firefly" or r.begins_with("legend:"), arc + ": Star Net + Foraging 40 logs a firefly (%s)" % r)
		# --- legends ---
		ok(Critters.legend_roll("spring", "clear", 7, 2, 40) == "", arc + ": Petal Emperor needs rain")
		ok(Critters.legend_roll("spring", "rain", 7, 1, 40) == "", arc + ": legends need the Star Net")
		ok(Critters.legend_roll("spring", "rain", 7, 2, 30) == "", arc + ": legends need Foraging 40")
		var got := ""
		for i in 400:
			got = Critters.legend_roll("spring", "rain", 7, 2, 40)
			if got != "":
				break
		ok(got == "cr_petal_emperor", arc + ": the Petal Emperor turns up in spring rain at dawn (%s)" % got)
		Collections.record_critter(got)
		for i in 400:
			ok(Critters.legend_roll("spring", "rain", 7, 2, 40) == "", arc + ": a legend is logged once")
			break
		ok(Critters.name_of("cr_meadow_hopper") == ("Meadow Hopper" if arc == "penguins" else "Alley Cricket"), arc + ": arc names")
		m.queue_free()
		p.queue_free()
		await process_frame
	print("critter_net_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
