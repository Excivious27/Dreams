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


## The clinic's bill. The first knockout of a run is free (a new player learns
## the rule without losing their seed money); after that ~8% of what you carry
## plus a small flat part that never takes more than a tenth of a thin purse,
## and a little more per mine floor. `mult` is the Juniper/easy discount.
static func clinic_fee(cr: int, floor_no: int, mult: float) -> int:
	var fl: Dictionary = GameState.run["flags"]
	if not fl.has("clinic_used"):
		fl["clinic_used"] = 1
		fl["clinic_first_free"] = true
		return 0
	fl["clinic_used"] = int(fl["clinic_used"]) + 1
	var base := int(cr * 0.08) + mini(20, int(cr * 0.1)) + 4 * floor_no
	return mini(cr, int(round(mini(750, base) * mult)))


## The clinic note's last words when there is nothing to pay.
static func free_line() -> String:
	var fl: Dictionary = GameState.run["flags"]
	if fl.has("clinic_first_free"):
		fl.erase("clinic_first_free")
		return "First visit's on the house. Next time there's a bill: eat when your health runs low, and ROLL away from a red flash."
	return "No charge this time."
