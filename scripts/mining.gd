class_name Mining
extends RefCounted
## C8 P4 mining curve: pickaxe swing per tool tier (wood, copper, iron, steel,
## silver, gold, crystal, moon): every upgrade hits harder. Rock hp: stone
## STONE_HP + floor / HP_PER_FLOORS, ore 3 + vein rank / 2 + floor / HP_PER_FLOORS
## (smooth, so the gate-tier pick takes ~3 swings at its depth). Gems roll on ore
## rocks; stone only at GEM_STONE_MULT of the chance.
const PICK_SWING := [1, 2, 3, 4, 5, 6, 7, 8]
const STONE_HP := 2
const HP_PER_FLOORS := 10
const GEM_STONE_MULT := 0.2
const MEGA_HP_MULT := 0.6      # mega-region ore: authored hp x this x the gate pick's swing
const ORE_LUMP := [0.3, 0.1]   # second lump chance: base + per pick tier (+ ore_bonus)

## Pickaxe damage per swing before double hit / mine power (PICK_SWING).
static func pick_swing() -> int:
	return int(PICK_SWING[clampi(GameState.tool_tier("pickaxe"), 0, PICK_SWING.size() - 1)])


## Gem chance for one broken rock (skill trees; stone rocks at GEM_STONE_MULT).
static func gem_chance(stone: bool) -> float:
	var ch := GameState.bonus("mining", "gem_chance") + GameState.bonus("magic", "gem_chance")
	return ch * (GEM_STONE_MULT if stone else 1.0)


## Hit points of a mega-region ore rock, scaled so the pick its gate asks for
## (GameState.ORE_TIER) takes about as many swings as the authored hp.
static func mega_rock_hp(ore: String, authored: int) -> int:
	var gate := int(GameState.ORE_TIER.get(ore, 0))
	var sw := int(PICK_SWING[clampi(gate, 0, PICK_SWING.size() - 1)])
	return maxi(authored, int(ceil(float(authored) * MEGA_HP_MULT)) * sw)


## Swing damage with skill rolls (double hit, mine power), as mine.gd/game_map.gd use.
static func swing_roll() -> int:
	var swing := pick_swing()
	if randf() < GameState.bonus("mining", "double_hit"):
		swing *= 2
	return swing + int(GameState.bonus("mining", "mine_power"))


## Lumps from an ore rock: n, one more on the lump roll (pick tier + ore_bonus).
static func lumps(n: int) -> int:
	var ch := float(ORE_LUMP[0]) + float(ORE_LUMP[1]) * GameState.tool_tier("pickaxe") + GameState.bonus("mining", "ore_bonus")
	return n + (1 if randf() < ch else 0)
