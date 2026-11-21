class_name Difficulty
extends RefCounted
## Difficulty modes (Tom 2026-11-19): Very easy / Easy / Default / Hard change
## COMBAT AND BATTLE CAMPAIGNS ONLY. Rewards, loot, prices, gating, farming and
## everything else are the same in every mode. Kept per save slot in
## run.opts.difficulty (0-3, default 2); a co-op guest plays at the host's mode
## (run.opts is a Net.WORLD_KEYS entry, restored when the guest goes home).

const NAMES := ["Very easy", "Easy", "Default", "Hard"]
const DEFAULT := 2
## One line each for the new-game page and Settings.
const WORDS := [
	"Fights are gentle: foes have half the health and hit far softer.",
	"Fights go easier: foes are weaker and slower to strike.",
	"Fights play as the game was made: a fair challenge.",
	"Fights bite: foes are tougher, hit harder and strike faster.",
]
## Campaign card danger words (Campaign.danger -1..2), the same in every mode.
const DANGER_WORDS := ["light", "fair", "tough", "fierce"]

## Multipliers (or added amounts) per mode: VE, E, D, H. Design c4_15.
const TABLE := {
	"foe_hp": [0.5, 0.75, 1.0, 1.3],          # every non-boss foe's health
	"boss_hp": [0.55, 0.8, 1.0, 1.25],        # bosses (field and battle captains)
	"foe_dmg": [0.45, 0.7, 1.0, 1.3],         # foe hits on you (GameState.enemy_damage)
	"ally_dmg": [0.6, 0.8, 1.0, 1.2],         # foe hits on pets, crew, helpers
	"status": [0.5, 0.75, 1.0, 1.25],         # poison/burn/chill length and power
	"windup": [1.3, 1.15, 1.0, 0.9],          # attack telegraph time
	"enemy_tickets": [0.6, 0.8, 1.0, 1.2],
	"ally_tickets": [1.3, 1.15, 1.0, 0.9],
	"enemy_cap": [-5, -3, 0, 3],              # added to the battle's enemy cap
	"wave_every": [1.35, 1.15, 1.0, 0.9],
	"convoy": [40, 20, 0, -10],               # added convoy health
	"hold": [-50, -30, 0, 20],                # added seconds to hold
	"capture": [0.6, 0.8, 1.0, 1.15],         # enemy capture speed
	"supply": [1.3, 1.15, 1.0, 1.0],          # supply trickle
	"morale_loss": [10, 15, 20, 25],          # morale lost on a lost battle
	"keeper_n": [-2, -1, 0, 1],               # mine keeper pack size (min 1)
	"clinic_fee": [0.0, 0.5, 1.0, 1.0],       # clinic fee after a combat faint
}


## The mode for the run that's loaded (0-3).
static func level() -> int:
	var o: Variant = GameState.run.get("opts", {})
	if not o is Dictionary:
		return DEFAULT
	return clampi(int((o as Dictionary).get("difficulty", DEFAULT)), 0, 3)


static func set_level(n: int) -> void:
	if not GameState.run.get("opts", null) is Dictionary:
		GameState.run["opts"] = {}
	(GameState.run["opts"] as Dictionary)["difficulty"] = clampi(n, 0, 3)


static func name_of(n := -1) -> String:
	return str(NAMES[clampi(level() if n < 0 else n, 0, 3)])


static func words(n := -1) -> String:
	return str(WORDS[clampi(level() if n < 0 else n, 0, 3)])


## The value for a key at the current mode (or at mode n).
static func mul(key: String, n := -1) -> float:
	var row: Array = TABLE.get(key, [1.0, 1.0, 1.0, 1.0])
	return float(row[clampi(level() if n < 0 else n, 0, 3)])


static func add(key: String, n := -1) -> int:
	return int(mul(key, n))


static func is_default() -> bool:
	return level() == DEFAULT


## The global easy switch from before CONDUCT 4 (read once per slot by _migrate).
static func legacy_easy() -> bool:
	return bool(SaveGame.get_value("set_easy", false))


## The Settings (Options tab) rows: difficulty with its one-line description
## and day length. A co-op guest plays at the host's settings: shown, locked.
static func settings_rows(menu: Object) -> void:
	if Net.visiting():
		menu.call("_line", "Difficulty: %s · Day length: %d real min" % [name_of(), GameState.day_len()], 9, Color(0.95, 0.9, 0.8))
		menu.call("_line", "  Your host sets the difficulty and the day length.", 8, Color(0.85, 0.85, 0.9))
		return
	menu.call("_button", "Difficulty: %s" % name_of(), func() -> void:
		set_level((level() + 1) % NAMES.size())
		menu.call("_refresh"))
	menu.call("_line", "  " + words() + " Fights only.", 8, Color(0.85, 0.85, 0.9))
	menu.call("_button", "Day length: %d real min" % GameState.day_len(), func() -> void:
		GameState.run["day_len"] = next_day_len(GameState.day_len())
		menu.call("_refresh"))


static func next_day_len(cur: int) -> int:
	var i := GameState.DAY_LENGTHS.find(cur)
	return int(GameState.DAY_LENGTHS[(i + 1) % GameState.DAY_LENGTHS.size()])
