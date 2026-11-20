class_name MoveSpeed
## One speed ladder for the hero (CONDUCT 8 P5, c8_10). Player moves by
## MoveSpeed.calc(...).total; the Hero tab shows the same parts list, so the two
## can never disagree again. Every number lives in the table below.
##
##   FOOT bonus  = gear + food/potion buff + skill nodes, ADDED, capped at FOOT_CAP.
##   Bursts      = Haste, crew perk, cave legs: multiply the foot speed, but the
##                 whole on-foot multiplier is clamped at FOOT_MAX.
##   Rides       = mount / vehicle own factor x (1 + RIDE_SHARE x foot bonus),
##                 clamped at RIDE_MAX / VEH_MAX (gear helps a little, never x2).
##   Swimming    = foot multiplier x swim factor (Strong Strokes, Tideswim).
##   Slows       = snow outdoors, exhausted, statuses: after every clamp.

const GEAR_PER := 0.08       # per gear "speed" point
const BUFF_PER := 0.15       # per point of a speed buff (food / potion)
const FOOT_CAP := 0.60       # gear + buff + skills, added
const FOOT_MAX := 1.75       # whole on-foot multiplier incl. bursts
const HASTE := 1.3
const CREW_PER := 0.05       # The Kid, up to CREW_LEVELS levels
const CREW_LEVELS := 2
const RIDE_SHARE := 0.5      # share of the foot bonus a mount / vehicle keeps
const MOUNT_WALK := 1.5
const MOUNT_RUN := 1.8
const RIDE_PERK := 0.10      # Benno's ride_fast perk, the stable, each
const RIDE_MAX := 2.2        # horse, of base walk / run speed
const VEH_MAX := 2.4         # scooters, sled, getaway car
const SWIM := 0.55
const SWIM_TIDE := 1.25      # Kelp Hollow's Tideswim
const SNOW := 0.9
const EXHAUSTED := 0.85      # GameState.exhausted() (under 15% energy)


## Foot bonus before the cap: [gear, buff, skills].
static func foot_raw() -> Array:
	return [GEAR_PER * GameState.gear_stat("speed"), BUFF_PER * GameState.buff("speed"), GameState.move_bonus()]


static func foot_bonus() -> float:
	var f := foot_raw()
	return clampf(float(f[0]) + float(f[1]) + float(f[2]), -0.5, FOOT_CAP)


static func haste_on() -> bool:
	return int(GameState.run.get("flags", {}).get("haste_abs", -1)) > GameState.now_abs()


static func _sk(key: String) -> float:
	var t := 0.0
	for sk in GameState.skills_data.keys():
		if GameState.skill_in_arc(str(sk)):
			t += GameState.bonus(str(sk), key)
	return t


static func _in_cave(map) -> bool:
	if map == null or not is_instance_valid(map):
		return false
	var sid := str(map.scene_id()) if map.has_method("scene_id") else ""
	return sid.begins_with("mine") or (map is GameMap and Ambience.is_cave(map))


## mode: "foot" | "swim" | "mount" | "vehicle". veh = Player.vehicle_def() (vehicle
## speed already picked for snow by the caller via veh_speed). Returns
## {total: float, parts: [[label, text]...], capped: bool}.
static func calc(map, running: bool, mode := "foot", veh_speed := 1.0, veh_water := 0.0) -> Dictionary:
	var parts: Array = [["Base", "100%"]]
	var raw := foot_raw()
	var gear := float(raw[0])
	if gear != 0.0:
		parts.append(["Gear (%+d spd, %d%% each)" % [GameState.gear_stat("speed"), roundi(GEAR_PER * 100)], "%+d%%" % roundi(gear * 100)])
	if float(raw[1]) > 0.0:
		parts.append(["Speed buff", "+%d%%" % roundi(float(raw[1]) * 100)])
	if float(raw[2]) > 0.0:
		parts.append(["Skill trees (movement)", "+%d%%" % roundi(float(raw[2]) * 100)])
	var fb := foot_bonus()
	var capped := float(raw[0]) + float(raw[1]) + float(raw[2]) > FOOT_CAP + 0.0001
	if capped:
		parts.append(["Foot bonus cap", "+%d%% max" % roundi(FOOT_CAP * 100)])
	var m := 1.0 + fb
	if mode == "mount":
		var r := (MOUNT_RUN if running else MOUNT_WALK) * (1.0 + RIDE_SHARE * fb)
		parts.append(["Horse (%s)" % ("gallop" if running else "trot"), "×%.1f" % (MOUNT_RUN if running else MOUNT_WALK)])
		if fb != 0.0:
			parts.append(["Rides keep half the foot bonus", "×%.2f" % (1.0 + RIDE_SHARE * fb)])
		if Perks.flag("ride_fast"):
			r *= 1.0 + RIDE_PERK
			parts.append(["Benno's riding tips", "+%d%%" % roundi(RIDE_PERK * 100)])
		if Builds.is_built("stable"):
			r *= 1.0 + RIDE_PERK
			parts.append(["Stable", "+%d%%" % roundi(RIDE_PERK * 100)])
		var rs := _sk("ride_speed")
		if rs > 0.0:
			r *= 1.0 + rs
			parts.append(["Smooth Ride (skill)", "+%d%%" % roundi(rs * 100)])
		if r > RIDE_MAX:
			r = RIDE_MAX
			capped = true
			parts.append(["Riding cap", "×%.1f max" % RIDE_MAX])
		m = r
	elif mode == "vehicle":
		var v := veh_speed * (1.0 + RIDE_SHARE * fb)
		parts.append(["Vehicle", "×%.2f" % veh_speed])
		var rs2 := _sk("ride_speed")
		if rs2 > 0.0:
			v *= 1.0 + rs2
			parts.append(["Smooth Ride (skill)", "+%d%%" % roundi(rs2 * 100)])
		if v > VEH_MAX:
			v = VEH_MAX
			capped = true
			parts.append(["Vehicle cap", "×%.1f max" % VEH_MAX])
		m = v
	else:
		if haste_on():
			m *= HASTE
			parts.append(["Haste spell", "×%.1f" % HASTE])
		var cl := mini(CREW_LEVELS, Crew.perk_level("run_speed"))
		if cl > 0:
			m *= 1.0 + CREW_PER * cl
			parts.append(["Crew: The Kid", "+%d%%" % roundi(CREW_PER * cl * 100)])
		var cave := _sk("cave_speed")
		if cave > 0.0 and _in_cave(map):
			m *= 1.0 + cave
			parts.append(["Tunnel Legs (in mines)", "+%d%%" % roundi(cave * 100)])
		if m > FOOT_MAX:
			m = FOOT_MAX
			capped = true
			parts.append(["On-foot cap", "×%.2f max" % FOOT_MAX])
		if mode == "swim":
			if veh_water > 0.0:
				m *= veh_water
				parts.append(["Rowing", "×%.1f" % veh_water])
			else:
				var sw := SWIM_TIDE if Colony.has_ability("tideswim") else (1.0 if Companion.has_ability("tail") else SWIM)
				var ss := _sk("swim_speed")
				m *= sw * (1.0 + ss)
				parts.append(["Swimming", "×%.2f" % sw])
				if ss > 0.0:
					parts.append(["Strong Strokes (skill)", "+%d%%" % roundi(ss * 100)])
	# Slows come last, after every cap.
	if GameState.weather_today() in ["snow", "blizzard"] and map != null and is_instance_valid(map) and bool(map.get("has_sky")):
		m *= SNOW
		parts.append(["Snow (outdoors)", "×%.1f" % SNOW])
	if GameState.exhausted():
		m *= EXHAUSTED
		parts.append(["Running on empty", "×%.2f" % EXHAUSTED])
	var st := GameState.status_speed()
	if st < 1.0:
		m *= st
		parts.append(["Statuses", "×%.2f" % st])
	return {"total": m, "parts": parts, "capped": capped}
