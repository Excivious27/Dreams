extends SceneTree
## Bowling tuning map (read-only): strike rate / pins carried by entry point at the head
## pin, per hook, for a few physics settings; and how far the entry moves when the power
## bar is stopped a little off. Use it after touching Bowling.Sim.
##   godot --headless --path . -s res://tools/bowl_audit.gd [-- skills]
## With "skills": average villager score per skill 0.1..0.9 (to set Bowling.OPPONENTS).


func _initialize() -> void:
	if "skills" in OS.get_cmdline_user_args():
		for k in range(1, 10):
			var skill := k / 10.0
			var tot := 0
			for g in 8:
				var sim := Bowling.Sim.new()
				sim.rng.seed = 4000 + g * 31 + k
				var rs: Array = []
				var guard := 0
				while not bool(Bowling.next_state(rs)["over"]) and guard < 12:
					Bowling.bowl_frame(sim, rs, skill, 2 if skill >= 0.3 else 0)
					guard += 1
				tot += Bowling.score_of(rs)
			print("skill %.1f averages %.0f" % [skill, tot / 8.0])
		quit()
		return
	var spd := 230.0 + 140.0 * 0.78
	for sp in [0.66, 1.0]:
		var a0 := Bowling.Sim.aim_for(Bowling.POCKET, 6.0, spd, sp)
		print("spin %.2f: power +-0.07 moves the entry %.2f / %.2f in" % [sp, Bowling.Sim.entry_x(6.0, a0, spd - 10.0, sp) - Bowling.POCKET, Bowling.Sim.entry_x(6.0, a0, spd + 10.0, sp) - Bowling.POCKET])
	for cfg in [[0.65, 0.0], [0.65, 0.15], [0.7, 0.1]]:
		Bowling.Sim.KICK_E = cfg[0]
		Bowling.Sim.SCATTER = cfg[1]
		print("KICK_E %.2f SCATTER %.2f" % cfg)
		for spin in [0.66, 1.0]:
			var row := "  spin %.2f:" % spin
			var tot := 0
			for e in [0.5, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.5]:
				var a := Bowling.Sim.aim_for(e, 6.0, spd, spin)
				var st := 0
				var pins := 0
				for i in 10:
					var s := Bowling.Sim.new()
					s.rng.seed = 50 + i
					s.aim_noise = 0.03
					s.rack()
					var n := s.run_throw(6.0, a, spd, spin)
					pins += n
					if n == 10:
						st += 1
				tot += st
				row += "  %.1f:%d/%.1f" % [e, st, pins / 10.0]
			print(row, "   sum ", tot)
	quit()
