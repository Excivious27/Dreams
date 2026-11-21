class_name SeasonCal
extends RefCounted
## C15 P3: the villager side (talk, mail, events, romance, commons) asks about
## festivals through here; a thin wrapper over Calendar (scripts/calendar.gd).

## The plaza festival on a save day as {id, name, time, where, day} ({} if none).
## C15 integ: Calendar is merged, so this simply asks it.
static func festival_for_day(d: int) -> Dictionary:
	var e: Dictionary = Calendar.festival_for_day(d)
	if e.is_empty():
		return {}
	return {"id": str(e.get("id", "")), "name": str(e.get("name", "")), "time": str(e.get("time", "")), "where": str(e.get("where", "")), "day": int(e.get("day", 0))}


## Every plaza festival in the season that `d` falls in, in day order.
static func festivals_in_season(d: int) -> Array:
	var out: Array = []
	var start := d - ((d - 1) % GameState.DAYS_PER_SEASON)
	for i in GameState.DAYS_PER_SEASON:
		var f: Dictionary = festival_for_day(start + i)
		if not f.is_empty():
			out.append(f)
	return out


## A plaza festival tomorrow.
static func eve() -> bool:
	return not festival_for_day(int(GameState.run.get("day", 1)) + 1).is_empty()


static func is_festival_day(d: int) -> bool:
	return not festival_for_day(d).is_empty()
