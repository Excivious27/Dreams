class_name SeasonCal
extends RefCounted
## C15 P3: the villager side (talk, mail, events, romance, commons) asks about
## festivals through here. It uses P1's Calendar (scripts/calendar.gd) when that
## script exists and falls back to the classic one-festival-on-day-14 rule, so the
## P3 branch works with or without the calendar engine merged.

static var _cal: Script = null
static var _checked := false


static func cal() -> Script:
	if not _checked:
		_checked = true
		if ResourceLoader.exists("res://scripts/calendar.gd"):
			var s: Script = load("res://scripts/calendar.gd")
			var names: Array = []
			if s:
				for m in s.get_script_method_list():
					names.append(str(m["name"]))
			if "festival_for_day" in names and "festival_on" in names:
				_cal = s
	return _cal


## The plaza festival on a save day as {id, name, time, where, day} ({} if none).
static func festival_for_day(d: int) -> Dictionary:
	var c := cal()
	if c:
		var e: Dictionary = c.call("festival_for_day", d)
		if e.is_empty():
			return {}
		return {"id": str(e.get("id", "")), "name": str(e.get("name", "")), "time": str(e.get("time", "")), "where": str(e.get("where", "")), "day": int(e.get("day", 0))}
	var dos := (d - 1) % GameState.DAYS_PER_SEASON + 1
	if dos != GameState.FESTIVAL_DAY:
		return {}
	var fid := str(GameState.FESTIVALS[GameState.season_of(d)][0])
	return {"id": fid, "name": GameState.festival_name(fid), "time": "", "where": "the plaza", "day": dos}


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
