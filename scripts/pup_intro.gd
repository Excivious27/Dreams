class_name PupIntro
extends RefCounted
## The pup's lesson and the fight basics, told once, at a new player's first
## fight (the meadow's first visit, or the mine's if they go there first).
## The farm intro only says the pup exists; this says what it does and how to
## give it orders, and what an enemy's wind-up looks like.


## Dialogue lines for the first fight; empty once taught. Marks it taught.
static func lines() -> Array:
	var fl: Dictionary = GameState.run.get("flags", {})
	if fl.has("pup_taught"):
		return []
	fl["pup_taught"] = true
	var nm := Pet.name_of()
	return [
		{"text": "When a foe flashes red with a claw mark over its head, it's winding up a hit. Step back or ROLL, then swing while it recovers."},
		{"text": "%s fights at your side and nips whatever goes for you. The paw buttons on the side of the screen give orders: ATK sends %s in, HEEL calls it back, STAY parks it, CALL fetches it from anywhere." % [nm, nm]},
		{"text": "If %s gets hurt, tap it (or face it and press CHECK) to pet it or share a snack. Knocked down, it needs food within two minutes, or it limps home to the dog house until morning." % nm},
	]


## Low health: once per run, the first time it drops under a third in a fight.
static func low_hp_tip(m: GameMap) -> void:
	var fl: Dictionary = GameState.run.get("flags", {})
	if fl.has("low_hp_tip") or m == null or m.hud == null:
		return
	if int(GameState.run["hp"]) <= 0 or int(GameState.run["hp"]) * 3 > int(GameState.run.get("max_hp", 100)):
		return
	fl["low_hp_tip"] = true
	m.hud.toast("Health low! Back off and eat something: MENU > Items > Eat.", Color(1, 0.7, 0.6))
