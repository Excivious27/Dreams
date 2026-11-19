class_name Faint
## Passing out before 10pm (hurt, or out of energy) doesn't skip the day: you
## come round at 10pm the same evening (in the clinic, or at home) patched up,
## with enough energy to get to bed. Tomorrow's bar still pays the Stardew-style
## quarter (GameState.sleep reads flags.fainted_day). After 10pm, or at the 2am
## "late" collapse, the night is over: the old sleep-through to morning.

const WAKE := 22 * 60  # 10pm


## True if this collapse ends the evening at WAKE instead of the day.
static func to_evening(reason: String) -> bool:
	var r := GameState.run
	if reason == "late" or int(r.get("time", 0)) >= WAKE:
		return false
	r["time"] = WAKE
	GameState.status_clear()
	r["hp"] = maxi(int(r["hp"]), int(ceil(int(r["max_hp"]) * 0.6)))
	r["energy"] = maxi(int(r["energy"]), int(r["max_energy"]) / 4)
	r["en_frac"] = 0.0
	r["en_warn"] = 0
	r["flags"]["fainted_day"] = int(r["day"])
	return true
