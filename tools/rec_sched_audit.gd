extends SceneTree
## Rec visitor schedule audit (c2_06): for each arc prints, per weekday (day % 7), who is at
## the rec when, and which visit slots never happen (the villager is at work / away).
##   godot --headless --path . -s res://tools/rec_sched_audit.gd   (WEATHER=rain for a wet week)


func _initialize() -> void:
	Campaign.bypass = true
	_run.call_deferred()


func _run() -> void:
	for arc in ["penguins", "gangsters"]:
		GameState.new_run(arc, "kairi" if arc == "penguins" else "dad", "T", "Town", "Pup")
		GameState.run["intro_done"] = true
		GameState.run["flags"]["rec_open"] = 1
		print("== ", arc)
		var dead := {}
		for id in RecCenter.data()["visitors"]:
			dead[id] = 0
			if not GameState.npcs.has(id):
				print("  MISSING npc ", id)
		for wd in 7:
			GameState.run["day"] = 15 + wd
			GameState.run["weather"] = {str(15 + wd): OS.get_environment("WEATHER") if OS.get_environment("WEATHER") != "" else "clear"}
			var row := []
			for hh in range(16, 48):
				GameState.run["time"] = hh * 30
				var here := {"rec": [], "rec_up": []}
				for id in RecCenter.data()["visitors"]:
					var s := RecCenter.slot_now(str(id))
					if s.is_empty():
						continue
					var p := Npc.place_now(GameState.npcs.get(id, {}).get("routine", []), str(id))
					if p == "rec":
						here[str(s[3])].append(id)
					else:
						dead[id] += 1
						row.append("%s@%.1f blocked(%s)" % [id, hh / 2.0, p])
				if not here["rec"].is_empty() or not here["rec_up"].is_empty():
					row.append("%.1f dn%s up%s lanes%s" % [hh / 2.0, str(here["rec"]), str(here["rec_up"]), str(RecCenter.lanes_taken().keys())])
			print(" wd%d: " % wd, "\n   ".join(row))
		print("  blocked half-hours: ", dead)
	quit()
