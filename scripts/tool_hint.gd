class_name ToolHint
## One voice for "wrong tool in hand": every map asks here instead of writing its
## own line, so a phone player always hears the same short, actionable hint
## (which tool, and how to get it in hand). Never acts; only explains.
##   if GameState.held_tool() != "axe": return ToolHint.need(self, "axe", "to chop")

## Last hint and when (msec): the nope sound plays once per burst, not per stroke.
static var _last_sfx := 0


## The line for "you need `tool` in hand" (no side effects; tests read it).
static func line(tool: String, why := "for that") -> String:
	var nm := GameState.item_name(tool)
	if GameState.has_tool(tool) and GameState.tool_away(tool):
		return "Your %s is at the smithy for its upgrade." % nm
	if not GameState.has_tool(tool):
		return "You need %s %s %s." % [_a(nm), nm, why]
	if (GameState.run.get("toolbar", []) as Array).has(tool):
		# c12_13-07: how to change slot depends on the device.
		match PadInput.device_kind():
			"pad":
				return "Hold the %s %s: switch to it on your toolbar with %s / %s." % [nm, why, InputSetup.prompt("cycle_back"), InputSetup.prompt("cycle_tool")]
			"keys":
				return "Hold the %s %s: pick it on your toolbar with its number key or the mouse wheel." % [nm, why]
		return "Hold the %s %s: tap it on your toolbar." % [nm, why]
	# c12_13-06: the menu button named per device (InputSetup.prompt).
	return "Hold the %s %s: put it on your toolbar (%s > Items)." % [nm, why, InputSetup.prompt("menu")]


## Show the hint for `tool` on `map`. Returns true (the action is used up).
static func need(map: Node, tool: String, why := "for that") -> bool:
	say(map, line(tool, why))
	return true


## Any other "not with that in your hand" line, same look and sound.
static func say(map: Node, text: String) -> void:
	if map == null or not is_instance_valid(map):
		return
	var hud: Variant = map.get("hud")
	if hud != null and is_instance_valid(hud):
		hud.toast(text, Color(1, 0.88, 0.7))
	var now := Time.get_ticks_msec()
	if now - _last_sfx > 900 and map.is_inside_tree():
		_last_sfx = now
		Music.instance(map.get_tree()).sfx("nope", "thud")


## The held thing is the rod or the can: neither swings at anything.
static func is_soft(held: String) -> bool:
	return held in ["rod", "can"]


static func _a(nm: String) -> String:
	return "an" if nm.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"


## What each tool does, said once the first time it's in hand (toolbar tutorial).
const TIPS := {
	"hoe": "Hoe: face grass on your farm and tap USE to till. Hold USE and walk to till a row.",
	"can": "Watering Can: tap USE on dry soil. When it runs dry, face any water and tap USE to refill.",
	"axe": "Axe: chop trees, logs and stumps for wood.",
	"pickaxe": "Pickaxe: break rocks for stone and ore.",
	"scythe": "Scythe: cut weeds and tall grass. Cut weeds make hay for animals.",
	"sword": "Sword: tap USE to swing at foes.",
	"rod": "Fishing Rod: face water and tap USE to cast; tap again when it bites.",
	"seed": "Seeds: face tilled soil and tap USE to plant.",
}

static var _tip_last := "?"


## The tip key for what's in the selected slot ("" = nothing to explain).
static func tip_key() -> String:
	var tb: Array = GameState.run.get("toolbar", [])
	if tb.is_empty():
		return ""
	var id := str(tb[clampi(int(GameState.run.get("slot", 0)), 0, tb.size() - 1)])
	if GameState.has_tool(id):
		return "sword" if GameState.is_sword(id) else (id if TIPS.has(id) else "")
	if str(GameState.items.get(id, {}).get("type", "")) == "seed" and GameState.count(id) > 0:
		return "seed"
	return ""


## Called by the Hud every frame: shows a tool's tip once, when nothing else is on screen.
static func first_pick(hud: Node) -> void:
	if GameState.run.is_empty() or not GameState.run.has("flags") or not bool(GameState.run.get("intro_done", false)):
		return
	var k := tip_key()
	if k == _tip_last:
		return
	if Dialogue.instance(hud.get_tree()).active or hud.get_tree().paused:
		return  # try again once the talk is over
	if not tip_fits_here(k, hud.get_tree().current_scene):
		return  # wait for a place where it makes sense (no flag set: it shows there)
	_tip_last = k
	if k == "" or GameState.run["flags"].has("tip_" + k):
		return
	GameState.run["flags"]["tip_" + k] = true
	var txt := str(TIPS[k])
	if k == "sword":
		var id := str(GameState.run["toolbar"][int(GameState.run["slot"])])
		txt = ("%s: tap USE to fire at foes. It uses rounds." if GameState.items.get(id, {}).has("range") else "%s: tap USE to swing at foes.") % GameState.item_name(id)
	hud.toast(PadInput.words(txt), Color(0.85, 0.95, 1.0))  # "tap USE" -> "press A" / "press Z" off the phone


## C3: a tool tip only where it makes sense: none on battlefields (the battle
## bar talks), farm-tool and seed tips only on the farm.
static func tip_fits_here(k: String, sc: Node) -> bool:
	var id: String = (sc as GameMap).scene_id() if sc is GameMap else ""
	if id.begins_with("bf_") or (sc != null and sc.get("battle") != null):
		return false
	if k in ["hoe", "can", "seed"]:
		return id == "farm"
	return true
