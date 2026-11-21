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
	r["energy"] = maxi(int(r["energy"]), mini(20, int(r["max_energy"]) / 8))  # C16a P3: enough to walk home (was a quarter bar)
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
	if mult <= 0.0:
		return 0  # waived anyway (C8 P1): keep the free first visit for when a bill applies
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
	match waived_by:
		"juniper": return "Juniper waves the bill away: friends don't pay."
		"perk": return "No charge: the clinic owes you one."
		"easy": return "No charge on Very easy."
	return "No charge this time."


## Why the last clinic bill was waived ("" = it wasn't): free_line names it.
static var waived_by := ""


## Days 1-7: new in town. Juniper doesn't bill a newcomer, and nobody pockets
## anything on the way home: the first week teaches the rule, it doesn't fine it.
const GRACE_DAYS := 7


static func in_grace() -> bool:
	return int(GameState.run.get("day", 1)) <= GRACE_DAYS


## What a collapse costs. Clinic: 8% of what you carry + 20 + 4 per mine floor
## (cap 750), halved/waived by Juniper's hearts. At home: 5% goes missing on
## the way (cap 300). Never more than you carry; nothing in week 1. The
## difficulty mode (Difficulty clinic_fee) scales only a combat faint
## (reason "hurt"): late nights and exhaustion cost the same in every mode.
static func fee(clinic: bool, floor_no: int, reason := "") -> int:
	var cr := int(GameState.run.get("crystals", 0))
	waived_by = ""
	if in_grace():
		return 0
	if clinic:
		var mult := 1.0
		if GameState.run["flags"].has("juniper_gone"):
			pass  # she left: no clinic perks
		elif GameState.has_friend_perk("juniper", 6):
			mult = 0.0
			waived_by = "juniper"
		elif GameState.has_friend_perk("juniper", 2):
			mult = 0.5
		if Perks.flag("no_clinic_fee") and mult > 0.0:
			mult = 0.0
			waived_by = "perk"
		if reason == "hurt" and mult > 0.0:
			mult *= Difficulty.mul("clinic_fee")
			if mult <= 0.0:
				waived_by = "easy"
		return clinic_fee(cr, floor_no, mult)  # first visit free, gentle flat part
	if at_home():
		return 0  # dropped in your own house: nobody carried you anywhere (C8 P1)
	return mini(cr, mini(300, int(ceil(cr * 0.05))))


## True when the collapse happens inside your own farmhouse (not visiting).
static func at_home() -> bool:
	var t := Engine.get_main_loop() as SceneTree
	var m: Node = t.current_scene if t else null
	return m is GameMap and (m as GameMap).scene_id() == "house" and not Net.visiting()


## The wake-up words after a collapse that ends at home (game_map.player_down).
static func home_note(evening: bool, fee: int, home: bool) -> String:
	if home:
		return "You nodded off on the floor and woke at 10pm, stiff. Get some proper sleep." if evening else "You nodded off on the floor before reaching the bed."
	if evening:
		return ("You come round on your own bed at 10pm, aching. Someone carried you home. ◆%d went missing on the way." % fee) if fee > 0 else "You come round on your own bed at 10pm, aching. Someone carried you home. Get some proper sleep."
	return ("Someone found you and carried you home. ◆%d went missing on the way." % fee) if fee > 0 else "Someone found you and carried you home to bed."


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
