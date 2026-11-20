extends SceneTree
## Battle balance table (C3 fix P2): every campaign node of both arcs as the
## Battle will see it (Campaign.battle_data on its field), with the numbers that
## decide how hard it is: tickets each side, enemy tier/cap/wave pace, the
## commander's HP (Battle.boss_hp at your progress tier), start supply, and two
## rough clocks: ticket-drain time holding one point more than them, and the
## drain while holding all points but one. Read-only; no scene is loaded.
##   godot --headless --path . -s res://tools/battle_audit.gd [-- pt=2]


func _initialize() -> void:
	var pt := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pt="):
			pt = int(a.substr(3))
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "mom", "T", "Town", "Pup")
		print("== %s (progress tier %d)" % [arc, pt])
		print("cid            node type      T  et  tk/etk    cap wave  sup  boss_hp  drain+1  drain-all")
		for cid: String in Campaign.all():
			var c := Campaign.get_c(cid)
			if str(c.get("arc", "both")) not in ["both", arc]:
				continue
			for n: Dictionary in c.get("nodes", []):
				var typ := str(n.get("type", ""))
				if typ in ["start", "cache", "camp"]:
					continue
				var nid := str(n["id"])
				var f := str(Campaign.cfg(cid, nid).get("field", ""))
				var base: Dictionary = RegionData.region(f).get("battle", {}) if f != "" else {}
				var d := Campaign.battle_data(base, {"cid": cid, "nid": nid, "field": f})
				var np: int = (d.get("points", []) as Array).size()
				var etk := int(d.get("enemy_tickets", 0))
				var ct := int(c.get("tier", 1))
				var bhp := Battle.boss_hp(40 + 20 * ct, ct, pt) if d.has("boss") else 0
				var near := etk  # one point ahead: 1 ticket/s
				var all_but := etk / maxi(1, np - 2)
				print("%-14s %-4s %-9s %d  %d  %3d/%-4d  %3d %4.1f  %3d  %7s  %6ds  %8ds" % [cid, nid, typ, ct, int(d.get("enemy_tier", 0)), int(d.get("tickets", 0)), etk,
					int(d.get("enemy_cap", 0)), float(d.get("wave_every", 0)), int(d.get("supply", 0)), str(bhp) if bhp > 0 else "-", near, all_but])
	quit(0)
