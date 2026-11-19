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


## Days 1-7: new in town. Juniper doesn't bill a newcomer, and nobody pockets
## anything on the way home: the first week teaches the rule, it doesn't fine it.
const GRACE_DAYS := 7


static func in_grace() -> bool:
	return int(GameState.run.get("day", 1)) <= GRACE_DAYS


## What a collapse costs. Clinic: 8% of what you carry + 20 + 4 per mine floor
## (cap 750), halved/waived by Juniper's hearts or easy mode. At home: 5% goes
## missing on the way (cap 300). Never more than you carry; nothing in week 1.
static func fee(clinic: bool, floor_no: int) -> int:
	var cr := int(GameState.run.get("crystals", 0))
	if in_grace():
		return 0
	if clinic:
		var mult := 1.0
		if GameState.run["flags"].has("juniper_gone"):
			pass  # she left: no clinic perks
		elif GameState.has_friend_perk("juniper", 6):
			mult = 0.0
		elif GameState.has_friend_perk("juniper", 2):
			mult = 0.5
		if Settings.easy() or Perks.flag("no_clinic_fee"):
			mult = 0.0
		return clinic_fee(cr, floor_no, mult)  # first visit free, gentle flat part
	if Settings.easy():
		return 0
	return mini(cr, mini(300, int(ceil(cr * 0.05))))


## Bedtime warnings (Stardew's "getting late"): one at midnight, one at 1:30am,
## once each per night. Returns the toast text or "". GameMap._process asks.
const LATE_WARN := [[24 * 60, "Midnight. Time to head home: at 2am you'll drop wherever you are."], [25 * 60 + 30, "It's 1:30am. Get to a bed now, or you'll pass out at 2."]]


static func bedtime_note() -> String:
	var r := GameState.run
	var t := int(r.get("time", 0))
	var day := int(r.get("day", 1))
	var w: Dictionary = r.get("late_warn", {})
	if int(w.get("day", -1)) != day:
		w = {"day": day, "n": 0}
	var n := int(w.get("n", 0))
	var out := ""
	while n < LATE_WARN.size() and t >= int(LATE_WARN[n][0]):
		out = str(LATE_WARN[n][1])
		n += 1
	if t >= GameState.DAY_END:
		out = ""  # the collapse itself says it
	w["n"] = n
	r["late_warn"] = w
	return out
