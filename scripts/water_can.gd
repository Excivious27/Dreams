class_name WaterCan
## Tom (C6 P7 phone playtest): the watering can runs dry and is refilled at water.
## It holds cap() pours (grows with the can's tier and the farming skill); the
## level lives in run["can_water"] (old saves have no key: they start full).
## Every pour on dry soil spends one (farm._water); USE with the can on any
## water cell (pond, river, lake, sea) or beside a well / trough / fountain
## fills it with a sound and a toast. The toolbar shows the level as a little
## blue bar under the can (Hud) and the held-item line says "Water 12/20".

const EMPTY := "Empty — refill at water."
const BASE := 20
const PER_TIER := 12
const PER_LEVEL := 2
## Props that count as a water source when you face them (or a cell beside them).
const SOURCE_WORDS := ["well", "trough", "fountain", "pump"]


static func cap() -> int:
	var lvl := GameState.skill_level("farming") if GameState.run.has("skills") else 1
	return BASE + PER_TIER * GameState.tool_tier("can") + PER_LEVEL * (lvl - 1)


static func level() -> int:
	if GameState.run.is_empty():
		return 0
	if not GameState.run.has("can_water"):
		GameState.run["can_water"] = cap()  # old saves: a full can
	return clampi(int(GameState.run["can_water"]), 0, cap())


static func frac() -> float:
	return float(level()) / float(maxi(1, cap()))


## One pour. False (nothing spent) when it's empty.
static func use() -> bool:
	var n := level()
	if n <= 0:
		return false
	GameState.run["can_water"] = n - 1
	return true


static func fill() -> void:
	GameState.run["can_water"] = cap()


## Is cell c water you can fill from (or a well/trough/fountain prop beside it)?
static func is_source(map: Node, c: Vector2i) -> bool:
	if map == null:
		return false
	if map.has_method("is_water_cell") and map.is_water_cell(c):
		return true
	var props: Variant = map.get("props")
	if not (props is Dictionary):
		return false
	for d: Vector2i in [Vector2i.ZERO, Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(-1, 1)]:
		var sp: Variant = (props as Dictionary).get(c + d, null)
		if sp is Sprite2D and is_instance_valid(sp) and (sp as Sprite2D).texture:
			var path := (sp as Sprite2D).texture.resource_path.get_file().to_lower()
			for w: String in SOURCE_WORDS:
				if path.begins_with(w) or path.contains("_" + w):
					return true
	return false


## USE with the can on cell c: fill it if c is a water source. True = handled.
static func try_refill(map: Node, c: Vector2i) -> bool:
	if GameState.held_tool() != "can" or not is_source(map, c):
		return false
	var hud: Variant = map.get("hud")
	if level() >= cap():
		if hud != null and is_instance_valid(hud):
			hud.toast("The can is already full (%d/%d)." % [cap(), cap()], Color(0.75, 0.9, 1.0))
		return true
	fill()
	var pl: Variant = map.get("player")
	if pl != null and is_instance_valid(pl) and pl.has_method("play_tool"):
		pl.play_tool("water")
	if map.is_inside_tree():
		Music.instance(map.get_tree()).sfx("splash", "water")
	if map.has_method("fx") and map.has_method("cell_center"):
		map.fx("splash", map.cell_center(c), 14.0, 0.35)
	if hud != null and is_instance_valid(hud):
		hud.toast("Can filled (%d/%d)." % [cap(), cap()], Color(0.6, 0.85, 1.0))
	return true


## The empty-can line (same look and sound as the other held-tool hints).
static func say_empty(map: Node) -> void:
	ToolHint.say(map, EMPTY)
