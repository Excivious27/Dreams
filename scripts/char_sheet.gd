class_name CharSheet
extends RefCounted

## Dots per rarity on a slot: Decor.RARITIES order (the one table), capped at 5 dots so
## they fit a 32 px slot; unique also gets a star plate (slot_cell) so it reads apart from mythic.
const RARITY_RANK := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5, "unique": 5}
const RANK_DOT := 2  # px per rarity dot on a slot


static func rarity_of(id: String) -> String:
	if GameState.items.has(id):
		return str(GameState.items[id].get("rarity", "common"))
	return Decor.rarity(id) if Decor.is_decor(id) else "common"


## 0 common .. 5 mythic/unique (slot dots; ChestScreen may use it too).
static func rarity_rank(id: String) -> int:
	return mini(5, Decor.rarity_rank(rarity_of(id)))


static func rarity_col(id: String) -> Color:
	var r := rarity_of(id)
	return Decor.rarity_color(r) if r in ["mythic", "unique"] else GameState.rarity_color(id)
## The Character tab of the pause menu (Stardew's inventory doll + Sun Haven's
## stat sheet): the hero card, title/rank from progression, a paper-doll of the
## ten gear slots (tap one to compare and swap what's in your bag), weapons and
## tool tiers, every stat with where each point comes from (tap a row), active
## buffs and statuses, each skill tree's level/XP, and the milestones.
## Pure helpers (stats, sets, renown) read GameState and change nothing; the UI
## half is built into GameMenu's scrolling body by build().

const SLOT_NAMES := {"head": "Head", "body": "Body", "legs": "Legs", "feet": "Feet", "hands": "Hands",
	"offhand": "Shield", "back": "Cape", "belt": "Belt", "ring": "Ring", "charm": "Trinket"}
## Gangster arc slot words (Chrome Arm is not a shield, a trench coat is not a cape).
const GANG_SLOT_NAMES := {"head": "Head", "body": "Body", "legs": "Legs", "feet": "Feet", "hands": "Hands",
	"offhand": "Arm", "back": "Coat", "belt": "Belt", "ring": "Ring", "charm": "Piece"}


static func slot_name(slot: String) -> String:
	return str((SLOT_NAMES if GameState.is_penguins() else GANG_SLOT_NAMES).get(slot, slot))
const LEFT := ["head", "body", "legs", "feet", "hands"]
const RIGHT := ["offhand", "back", "belt", "ring", "charm"]
const STAT_SHORT := {"defense": "def", "speed": "spd", "luck": "luck", "energy": "energy", "damage": "dmg", "mana": "mana", "hp": "hp"}
const STAT_WEIGHT := {"defense": 3.0, "speed": 2.5, "luck": 2.0, "damage": 3.0, "energy": 0.2, "mana": 0.2, "hp": 0.1}
## Armour sets (gen_stations.py): <set>_<part>, tempered as <set>_<part>_plus.
const SETS := ["leather", "copper", "iron", "steel", "silver", "gold", "crystal", "moon"]
const SET_PARTS := ["helm", "chest", "legs", "boots", "gloves", "shield", "cape", "belt"]
const TEMPER_AT := {"leather": "Tannery"}  # every other set tempers at the Anvil

const INK := Color(0.29, 0.17, 0.07)
const INK_SOFT := Color(0.45, 0.33, 0.2)
const GOOD := Color(0.16, 0.48, 0.14)
const BAD := Color(0.68, 0.16, 0.1)
const GOLD := Color(0.62, 0.4, 0.05)

static var sel_slot := ""
static var open_stat := ""
static var sel_tool := ""


# ---- pure helpers --------------------------------------------------------------

static func item_stats(id: String) -> Dictionary:
	return GameState.items.get(id, {}).get("stats", {})


## Gear stat summed straight from the worn items (no set bonus).
static func raw_gear(stat: String) -> int:
	var t := 0
	for s: String in GameState.SLOTS:
		var id := GameState.equipped(s)
		if id != "":
			t += int(item_stats(id).get(stat, 0))
	return t


static func set_of(id: String) -> String:
	var base := id.trim_suffix("_plus")
	for st: String in SETS:
		for p: String in SET_PARTS:
			if base == st + "_" + p:
				return st
	return ""


static func is_tempered(id: String) -> bool:
	return id.ends_with("_plus")


## Pieces worn per armour set (a tempered piece counts for its set).
static func set_counts() -> Dictionary:
	var out := {}
	for s: String in GameState.SLOTS:
		var st := set_of(GameState.equipped(s))
		if st != "":
			out[st] = int(out.get(st, 0)) + 1
	return out


## The bonus a set gives at n pieces: 4 pieces harden it, the full 8 add more.
static func set_bonus_for(st: String, n: int) -> Dictionary:
	var t := SETS.find(st)
	var out := {}
	if t < 0 or n < 4:
		return out
	out["defense"] = 1 + t / 2
	if n >= 8:
		out["luck"] = 1 + t / 3
		if st == "leather":
			out["energy"] = 15  # light kit: you work longer
		if t >= 6:
			out["speed"] = 1
	return out


## Total set bonus to one gear stat (GameState.gear_stat adds this once wired up).
static func set_bonus(stat: String) -> int:
	var t := 0
	var sc := set_counts()
	for st: String in sc:
		t += int(set_bonus_for(st, int(sc[st])).get(stat, 0))
	return t


## True once GameState.gear_stat counts set bonuses (so they're shown as live).
static func sets_live() -> bool:
	for k: String in ["defense", "luck", "energy", "speed"]:
		var b := set_bonus(k)
		if b != 0:
			return GameState.gear_stat(k) == raw_gear(k) + b
	return false


static func stat_text(st: Dictionary) -> String:
	var parts: Array = []
	for k: String in st:
		parts.append("%s %s%d" % [STAT_SHORT.get(k, k), "+" if int(st[k]) >= 0 else "", int(st[k])])
	return ", ".join(parts) if not parts.is_empty() else "no stats"


static func gear_score(st: Dictionary) -> float:
	var s := 0.0
	for k: String in st:
		s += float(st[k]) * float(STAT_WEIGHT.get(k, 1.0))
	return s


## Owned equipment for a slot (bag only: equipping takes it from the bag).
static func candidates(slot: String) -> Array:
	var out: Array = []
	for id: String in GameState.run.get("inventory", {}):
		var it: Dictionary = GameState.items.get(id, {})
		if str(it.get("type", "")) == "equip" and str(it.get("slot", "")) == slot and GameState.count(id) > 0:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return gear_score(item_stats(a)) > gear_score(item_stats(b)))
	return out


## Per-stat difference between two pieces, e.g. [["def", 2], ["luck", -1]].
static func compare(new_id: String, cur_id: String) -> Array:
	var a := item_stats(new_id)
	var b := item_stats(cur_id) if cur_id != "" else {}
	var keys: Array = a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	var out: Array = []
	for k: String in keys:
		var d := int(a.get(k, 0)) - int(b.get(k, 0))
		if d != 0:
			out.append([str(STAT_SHORT.get(k, k)), d])
	return out


static func best_melee() -> String:
	var held := GameState.held_tool()
	if held != "" and held != "sword" and int(GameState.items.get(held, {}).get("damage", 0)) > 0 and not GameState.items.get(held, {}).has("range"):
		return held
	var best := ""
	var bd := -1
	for t: String in GameState.run.get("tools", []):
		var it: Dictionary = GameState.items.get(t, {})
		if it.has("range"):
			continue
		if int(it.get("damage", 0)) > bd and int(it.get("damage", 0)) > 0:
			bd = int(it.get("damage", 0))
			best = t
	return best


static func best_gun() -> String:
	var held := GameState.held_tool()
	if GameState.items.get(held, {}).has("range"):
		return held
	var best := ""
	var bd := -1
	for t: String in GameState.run.get("tools", []):
		var it: Dictionary = GameState.items.get(t, {})
		if it.has("range") and int(it.get("damage", 0)) > bd:
			bd = int(it.get("damage", 0))
			best = t
	return best


## "Iron Sword" for the upgraded starter blade (item_name would say "Iron Wooden Sword").
static func weapon_name(id: String) -> String:
	if id == "sword" and GameState.tool_tier("sword") > 0:
		return "%s Blade" % GameState.TOOL_TIERS[GameState.tool_tier("sword")].capitalize()
	return GameState.item_name(id)


## Item art for an id: weapons with their own icon use it (Hud.icon_for maps
## every "weapon" onto the sword's tier icon).
static func icon_of(id: String) -> String:
	if not GameState.TOOL_KINDS.has(id) and Art.has("items", id):
		return id
	return Hud.icon_for(id)


## Each worn piece that gives this stat, as breakdown lines.
static func _gear_parts(parts: Array, stat: String) -> int:
	var t := 0
	for s: String in GameState.SLOTS:
		var id := GameState.equipped(s)
		var n := int(item_stats(id).get(stat, 0)) if id != "" else 0
		if n != 0:
			parts.append(["  " + GameState.item_name(id), "%+d" % n])
			t += n
	return t


static func npc_name(id: String) -> String:
	return str(GameState.npcs.get(id, {}).get("name", id.capitalize()))


static func crew_name(id: String) -> String:
	return str(Crew.members().get(id, {}).get("name", id.capitalize().replace("_", " ")))


## GameState is being reworked by others: read optional constants and helpers
## by name so the sheet follows whatever the live formula has.
static func gs_const(name: String, dflt: Variant) -> Variant:
	var s: Script = GameState
	return s.get_script_constant_map().get(name, dflt)


static func gs_has(fn: String) -> bool:
	var s: Script = GameState
	for m: Dictionary in s.get_script_method_list():
		if str(m.get("name", "")) == fn:
			return true
	return false


static func gs_call(fn: String, args: Array, dflt: Variant) -> Variant:
	if not gs_has(fn):
		return dflt
	var s: Script = GameState
	return s.callv(fn, args)


## Average energy a task costs right now (exact if GameState has energy_cost_f,
## else sampled, so it follows GameState's own formula).
static func avg_cost(task: String) -> float:
	if gs_has("energy_cost_f"):
		return float(gs_call("energy_cost_f", [task], 0.0))
	var t := 0
	for i in 60:
		t += GameState.energy_cost(task)
	return t / 60.0


static func _p(parts: Array, label: String, v: Variant, fmt := "%+d") -> void:
	if v is float and absf(float(v)) < 0.0005:
		return
	if v is int and int(v) == 0:
		return
	parts.append([label, fmt % v])


static func _rest(parts: Array, total: int, sum: int) -> void:
	if total != sum:
		parts.append(["Other effects", "%+d" % (total - sum)])


static func _pct(f: float) -> String:
	return "%d%%" % roundi(f * 100.0)


## Every stat with its sources: [{id, name, icon, value, parts: [[label, text]], note}].
static func stats() -> Array:
	var r := GameState.run
	var out: Array = []
	var in_arc: Array = []
	for sk in GameState.skills_data.keys():
		if GameState.skill_in_arc(str(sk)):
			in_arc.append(str(sk))
	# Health
	var p: Array = [["Base", "100"]]
	var sum := 100
	var v := 8 * (GameState.skill_level("combat") - 1)
	_p(p, "Combat level %d (8 a level)" % GameState.skill_level("combat"), v); sum += v
	for sk: String in in_arc:
		v = int(GameState.bonus(sk, "hp"))
		_p(p, "%s tree" % GameState.skill_name(sk), v); sum += v
	v = GameState.gear_stat("hp"); _p(p, "Gear", v); sum += v
	if GameState.has_friend_perk("juniper", 4):
		_p(p, "%s ♥4" % npc_name("juniper"), 20); sum += 20
	v = int(r.get("bonus_hp", 0)); _p(p, "Tonics & heart containers", v); sum += v
	_rest(p, int(r.get("max_hp", 100)), sum)
	out.append({"id": "hp", "name": "Max health", "icon": ["ui", "heart_full"], "value": "%d / %d" % [int(r.get("hp", 0)), int(r.get("max_hp", 100))], "parts": p,
		"note": "Food heals; sleeping restores it. %s" % ("Wren's friendship makes healing stronger." if GameState.has_friend_perk("wren", 2) else "")})
	# Energy
	var eb := int(gs_const("ENERGY_BASE", 100))
	p = [["Base", str(eb)]]
	sum = eb
	var levels := 0
	for sk: String in in_arc:
		levels += GameState.skill_level(sk) - 1
	v = 3 * mini(levels, 40); _p(p, "%d skill levels (3 each, up to 40)" % levels, v); sum += v
	for sk: String in in_arc:
		v = int(GameState.bonus(sk, "energy"))
		_p(p, "%s tree" % GameState.skill_name(sk), v); sum += v
	v = GameState.gear_stat("energy"); _gear_parts(p, "energy"); sum += v
	if v != raw_gear("energy"):
		_p(p, "Set bonus", v - raw_gear("energy"))
	v = int(gs_call("energy_milestones", [], 0)); _p(p, "Mine depth (stamina)", v); sum += v
	v = int(r.get("bonus_energy", 0)); _p(p, "Tonics & rewards", v); sum += v
	if GameState.has_friend_perk("bram", 10):
		_p(p, "%s ♥10" % npc_name("bram"), 50); sum += 50
	if GameState.has_friend_perk("posy", 8):
		_p(p, "%s ♥8" % npc_name("posy"), 20); sum += 20
	_rest(p, int(r.get("max_energy", 100)), sum)
	var fed := int(r.get("fed_en", 0))
	out.append({"id": "energy", "name": "Max energy", "icon": ["ui", "bolt_full"], "value": "%d / %d" % [int(r.get("energy", 0)), int(r.get("max_energy", 100))], "parts": p,
		"note": "Food can refill %d more energy today (one bar a day). Sleep refills it." % maxi(0, int(r.get("max_energy", 100)) - fed)})
	# Work cost
	p = []
	for t: String in ["hoe", "can", "axe", "pickaxe", "rod", "scythe", "sword"]:
		if GameState.has_tool(t) or t in ["hoe", "can", "axe", "pickaxe"]:
			var c := avg_cost(t)
			if c > 0.0 or t != "sword":
				p.append(["%s (%s)" % [GameState.item_name(t) if t != "sword" else "Sword swing", GameState.TOOL_TIERS[GameState.tool_tier(t)].capitalize()], "%.2f" % c if c < 1.0 else "%.1f" % c])
	var wn := ""
	if int(r.get("energy", 0)) < int(r.get("max_energy", 100)) * float(gs_const("EXHAUSTED_FRAC", 0.15)):
		wn = "You're exhausted: every task costs a quarter more. "
	if GameState.weather_today() == "sun":
		wn += "Heat wave today: work costs more (watering doesn't). "
	wn += "Skill levels, better tool tiers and tree nodes cut these."
	out.append({"id": "work", "name": "Energy per use", "icon": ["items", Hud.icon_for("hoe")], "value": "hoe %.2f" % avg_cost("hoe"), "parts": p, "note": wn})
	# Melee attack
	var mw := best_melee()
	var bw := int(GameState.items.get(mw, {}).get("damage", 0))
	p = [[weapon_name(mw) if mw != "" else "Bare hands", str(bw)]]
	sum = bw
	v = int(GameState.bonus("combat", "damage")); _p(p, "Combat tree", v); sum += v
	v = GameState.gear_stat("damage"); _p(p, "Gear", v); sum += v
	v = GameState.tool_tier("sword"); _p(p, "Blade tier (%s)" % GameState.TOOL_TIERS[v].capitalize(), v); sum += v
	if GameState.has_team():
		v = int(GameState.bonus("leadership", "team_damage")); _p(p, "Leadership (team out)", v); sum += v
	if GameState.count("knight_shard") > 0:
		_p(p, "Knight Shard", 1); sum += 1
	v = mini(2, Crew.perk_level("sword")); _p(p, "Crew: %s" % crew_name("vic"), v); sum += v
	if GameState.has_perk("combat", "Berserker") and int(r.get("hp", 0)) < int(r.get("max_hp", 100)) / 2:
		_p(p, "Berserker (below half health)", 2); sum += 2
	sum = maxi(1, sum)
	var melee := sum
	var held := GameState.held_tool()
	if not GameState.items.get(held, {}).has("range"):
		_rest(p, GameState.sword_damage(), sum)
		melee = GameState.sword_damage()
	var sm := GameState.status_damage_mod()
	if sm != 0:
		_p(p, "Statuses (weak)", sm)
	out.append({"id": "melee", "name": "Melee attack", "icon": ["items", icon_of(mw if mw != "" else "sword")], "value": str(maxi(1, melee + sm)), "parts": p,
		"note": "Crits hit for 1.5×."})
	# Ranged
	var gw := best_gun()
	if gw != "":
		var gd := int(GameState.items.get(gw, {}).get("damage", 0))
		p = [[GameState.item_name(gw), str(gd)]]
		sum = gd
		v = int(GameState.bonus("combat", "damage")); _p(p, "Combat tree", v); sum += v
		v = GameState.gear_stat("damage"); _p(p, "Gear", v); sum += v
		v = GameState.tool_tier("sword"); _p(p, "Weapon tier", v); sum += v
		if GameState.has_team():
			v = int(GameState.bonus("leadership", "team_damage")); _p(p, "Leadership (team out)", v); sum += v
		v = mini(2, Crew.perk_level("sword")); _p(p, "Crew: %s" % crew_name("vic"), v); sum += v
		v = int(GameState.bonus("hustle", "gun_damage")); _p(p, "Hustle tree (guns)", v); sum += v
		out.append({"id": "ranged", "name": "Ranged attack", "icon": ["items", icon_of(gw)], "value": str(maxi(1, sum + sm)), "parts": p,
			"note": "Range %d px · %d rounds in the bag (the Street Armory makes more)." % [int(GameState.items[gw].get("range", 100)), GameState.count("rounds")]})
	# Defense
	var defn := GameState.gear_stat("defense") + mini(2, Crew.perk_level("defence")) + int(GameState.buff("defense")) + (2 if Colony.has_ability("coral_ward") else 0)
	p = []
	_gear_parts(p, "defense")
	if sets_live():
		_p(p, "Set bonus", set_bonus("defense"))
	_rest(p, GameState.gear_stat("defense"), raw_gear("defense") + (set_bonus("defense") if sets_live() else 0))
	_p(p, "Crew: %s" % crew_name("val"), mini(2, Crew.perk_level("defence")))
	_p(p, "Buff", int(GameState.buff("defense")))
	if Colony.has_ability("coral_ward"):
		_p(p, "Coral Ward (colony)", 2)
	var taken := 60.0 / (60.0 + 2.5 * maxf(0.0, defn))
	var dr := minf(0.45, GameState.bonus("combat", "damage_reduction") + GameState.bonus("magic", "damage_reduction"))
	if dr > 0.0:
		p.append(["Combat/Sorcery: damage cut", _pct(dr)])
	var blk := GameState.bonus("combat", "block")
	if blk > 0.0:
		p.append(["Chance to block a hit", _pct(blk)])
	if GameState.has_team() and GameState.bonus("leadership", "team_defense") > 0.0:
		p.append(["Leadership (team out)", "-" + _pct(minf(0.4, GameState.bonus("leadership", "team_defense")))])
	if not Difficulty.is_default():
		var fm := Difficulty.mul("foe_dmg")
		p.append(["%s mode: foe hits" % Difficulty.name_of(), ("-" if fm < 1.0 else "+") + _pct(absf(1.0 - fm))])
	var dn := "You take %s of a hit after armour%s." % [_pct(taken * (1.0 - dr)), "" if dr == 0.0 else " and damage cuts"]
	if GameState.gear_stat("defense") >= 3:
		dn += " Statuses wear off 30% faster (3+ armour)."
	out.append({"id": "defense", "name": "Defense", "icon": ["items", Hud.icon_for("iron_helm")], "value": str(defn), "parts": p, "note": dn})
	# Crit
	var cl := 0.01 * GameState.skill_level("combat")
	var cb := GameState.bonus("combat", "crit")
	p = [["Combat level %d (1%% each)" % GameState.skill_level("combat"), _pct(cl)]]
	if cb > 0.0:
		p.append(["Combat tree", "+" + _pct(cb)])
	out.append({"id": "crit", "name": "Critical chance", "icon": ["items", "ruby"], "value": _pct(minf(0.40, cl + cb)), "parts": p, "note": "A crit hits for 1.5×. Capped at 40%."})
	# Speed
	# Same ladder the hero moves by (MoveSpeed, c8_10): walking parts, plus the ride/swim you're on.
	var pl = _sheet_player()
	var mmode := "foot"
	var vsp := 1.0
	var vwat := 0.0
	if pl != null:
		var vdd: Dictionary = pl.vehicle_def()
		if pl.swimming:
			mmode = "swim"
			vwat = float(vdd.get("water", 0.0))
		elif pl.mounted:
			mmode = "mount"
		elif str(pl.vehicle) != "":
			mmode = "vehicle"
			vsp = float(vdd.get("speed", 1.0))
	var mcalc := MoveSpeed.calc(pl.map if pl != null else null, false, mmode, vsp, vwat)
	var spd := float(mcalc["total"])
	p = mcalc["parts"]
	out.append({"id": "speed", "name": "Move speed", "icon": ["items", Hud.icon_for("boots")], "value": _pct(spd), "parts": p, "note": "Hold B (or the run toggle) to run. Gear, food and skills add up to +%d%%; on foot tops out at ×%.2f, rides at ×%.1f." % [roundi(MoveSpeed.FOOT_CAP * 100), MoveSpeed.FOOT_MAX, MoveSpeed.RIDE_MAX]})
	# Luck
	var lk := GameState.gear_stat("luck") + int(GameState.buff("luck"))
	p = []
	_gear_parts(p, "luck")
	if sets_live():
		_p(p, "Set bonus", set_bonus("luck"))
	_p(p, "Buff", int(GameState.buff("luck")))
	out.append({"id": "luck", "name": "Luck", "icon": ["items", "clover" if Art.has("items", "clover") else "luck_potion"], "value": str(lk), "parts": p,
		"note": "Luck means better drops (now ×%.2f on drop rolls), rarer fish and Rare Catch, and a steadier claw and Skee-Ball hand." % (1.0 + 0.05 * lk)})
	# Magic
	if GameState.skill_in_arc("magic"):
		p = [["Base", "20"]]
		sum = 20
		v = 12 * (GameState.skill_level("magic") - 1); _p(p, "Sorcery level %d (12 a level)" % GameState.skill_level("magic"), v); sum += v
		v = int(GameState.bonus("magic", "mana")); _p(p, "Sorcery tree", v); sum += v
		v = GameState.gear_stat("mana"); _p(p, "Gear", v); sum += v
		v = int(GameState.bonus(GameState.arc_skill(), "mana")); _p(p, "%s tree" % GameState.skill_name(GameState.arc_skill()), v); sum += v
		v = int(r.get("bonus_mana", 0)); _p(p, "Tonics", v); sum += v
		_rest(p, int(r.get("max_mana", 20)), sum)
		p.append(["Spell power", "×%.2f" % Spells.power()])
		if GameState.bonus("magic", "spell_discount") > 0.0:
			p.append(["Spells cost less", "-" + _pct(GameState.bonus("magic", "spell_discount"))])
		out.append({"id": "mana", "name": "Mana & spells", "icon": ["items", "mana_potion"], "value": "%d / %d" % [int(r.get("mana", 0)), int(r.get("max_mana", 20))], "parts": p,
			"note": "%d spell%s known." % [Spells.known().size(), "" if Spells.known().size() == 1 else "s"]})
	# Chop power
	var at := GameState.tool_tier("axe")
	p = [["Base", "1"], ["Axe tier (%s)" % GameState.TOOL_TIERS[at].capitalize(), "%+d" % ((at + 1) / 2)]]
	_p(p, "Foraging tree", int(GameState.bonus("foraging", "chop_power")))
	var cn := ""
	if GameState.bonus("foraging", "chop_bonus") > 0.0:
		cn = "%s chance a swing bites twice. " % _pct(0.1 * GameState.bonus("foraging", "chop_bonus"))
	out.append({"id": "chop", "name": "Chop power", "icon": ["items", Hud.icon_for("axe")], "value": str(1 + (at + 1) / 2 + int(GameState.bonus("foraging", "chop_power"))), "parts": p,
		"note": cn + "Damage each axe swing does to trees and stumps."})
	# Mine power
	var pk := GameState.tool_tier("pickaxe")
	p = [["Base", "1"], ["Pickaxe tier (%s)" % GameState.TOOL_TIERS[pk].capitalize(), "%+d" % ((pk + 1) / 2)]]
	_p(p, "Mining tree", int(GameState.bonus("mining", "mine_power")))
	var mn := ""
	if GameState.bonus("mining", "double_hit") > 0.0:
		mn = "%s chance a swing hits twice. " % _pct(GameState.bonus("mining", "double_hit"))
	out.append({"id": "mine", "name": "Mine power", "icon": ["items", Hud.icon_for("pickaxe")], "value": str(1 + (pk + 1) / 2 + int(GameState.bonus("mining", "mine_power"))), "parts": p,
		"note": mn + "Harder ores also need a pickaxe tier and Mining level."})
	# Fishing
	var fl := GameState.skill_level("fishing")
	var lit: bool = GameState.run.get("flags", {}).has("lighthouse_lit")
	p = [["Fishing level %d" % fl, "%d kinds" % (1 + fl)], ["Night", "+2 kinds, +40 value" if lit else "light the lighthouse first"], ["Bait", "+1 kind"]]
	var rare := GameState.bonus("fishing", "rare_fish") + (0.1 if GameState.has_friend_perk("finn", 8) else 0.0)
	if rare > 0.0:
		p.append(["Rare catch chance", _pct(rare)])
	if GameState.bonus("fishing", "bite_speed") > 0.0:
		p.append(["Faster bites", _pct(GameState.bonus("fishing", "bite_speed"))])
	out.append({"id": "fish", "name": "Fishing reach", "icon": ["items", Hud.icon_for("rod")], "value": "%d kinds" % (1 + fl), "parts": p,
		"note": "Fish worth up to %d◆ can bite (more with bait%s)." % [25 + 15 * fl, ", or at night" if lit else ""]})
	# Recovery
	var every := roundi(GameState.mana_regen_secs())
	p = [["Mana", "+1 every %d s" % every], ["Food energy left today", str(maxi(0, int(r.get("max_energy", 100)) - fed))], ["Sleep", "full health, energy, mana"]]
	if GameState.bonus("combat", "last_stand") > 0.0:
		p.append(["Last Stand", "once a day" + (" (used)" if int(r.get("flags", {}).get("last_stand_day", -1)) == int(r.get("day", 1)) else "")])
	if int(r.get("flags", {}).get("shield", 0)) > 0:
		p.append(["Shield charges", str(int(r["flags"]["shield"]))])
	out.append({"id": "regen", "name": "Recovery", "icon": ["ui", "status_regen"], "value": "mana 1/%ds" % every, "parts": p, "note": ""})
	# Difficulty mode and day length (per save slot; Settings changes them)
	p = [["Foe health", _pct(Difficulty.mul("foe_hp"))], ["Boss health", _pct(Difficulty.mul("boss_hp"))], ["Foe hits on you", _pct(Difficulty.mul("foe_dmg"))], ["Day length", "%d real min" % GameState.day_len()]]
	out.append({"id": "mode", "name": "Difficulty", "icon": ["items", Hud.icon_for("sword")], "value": Difficulty.name_of(), "parts": p,
		"note": Difficulty.words() + " Only fights and battle campaigns change; change it in Settings."})
	return out


## Renown: one number for how far this life has come (skills, friends, story, mines).
static func renown() -> int:
	var n := 0
	for sk in GameState.skills_data.keys():
		if GameState.skill_in_arc(str(sk)):
			n += mini(RENOWN_SKILL_CAP, GameState.skill_level(str(sk)) - 1)  # capped so story/hearts/quests weigh in (c8_05)
	n += total_hearts()
	n += (Story.chapter_no() - 1) * 6
	n += int(GameState.run.get("flags", {}).get("mine_deepest", 1)) / 5 * 2
	n += GameState.run.get("quests", []).filter(func(q: Dictionary) -> bool: return bool(q.get("done", false))).size()
	return n


const RANK_AT := [0, 15, 40, 80, 140, 220]
const RENOWN_SKILL_CAP := 12  # renown per skill tops out at 12 levels
const RANK_PENGUIN := ["Newcomer", "Settler", "Homesteader", "Floe Friend", "Keeper of the Ice", "Legend"]
const RANK_GANG := ["New Face", "Runner", "Earner", "Made", "Underboss", "Boss"]


static func rank_index(rn: int) -> int:
	var i := 0
	for k in RANK_AT.size():
		if rn >= int(RANK_AT[k]):
			i = k
	return i


static func rank_name(i: int) -> String:
	var town := str(GameState.run.get("names", {}).get("town", "Town"))
	var t: String = (RANK_PENGUIN if GameState.is_penguins() else RANK_GANG)[clampi(i, 0, 5)]
	return t + (" of " + town if i >= 2 else "")


static func total_hearts() -> int:
	var t := 0
	for id in GameState.run.get("friendship", {}):
		t += GameState.friend_hearts(str(id))
	return t


static func chapter_title() -> String:
	var n := Story.chapter_no()
	var chs: Variant = Story.data().get(str(GameState.run.get("arc", "penguins")), [])
	if chs is Array and n - 1 < (chs as Array).size() and (chs as Array)[n - 1] is Dictionary:
		return str(((chs as Array)[n - 1] as Dictionary).get("title", ""))
	return ""


static func chapter_count() -> int:
	var chs: Variant = Story.data().get(str(GameState.run.get("arc", "penguins")), [])
	return (chs as Array).size() if chs is Array else 0


static func duration(minutes: int) -> String:
	if minutes >= 60:
		return "%dh %02dm" % [minutes / 60, minutes % 60]
	return "%dm" % maxi(0, minutes)


const BUFF_NAMES := {"speed": "Swift", "luck": "Lucky", "defense": "Stoneskin", "warm": "Warm"}


static func buff_icon(kind: String) -> Array:
	var ui: String = {"defense": "status_armoured", "luck": "status_blessed", "warm": "status_regen"}.get(kind, "")
	if ui != "" and Art.has("ui", ui):
		return ["ui", ui]
	for id: String in GameState.items:
		var b: Variant = GameState.items[id].get("buff")
		if b is Dictionary and str((b as Dictionary).get("kind", "")) == kind:
			return ["items", Hud.icon_for(id)]
	return []


## Active buffs and statuses: [{name, icon, left, what, bad}].
static func effects() -> Array:
	var r := GameState.run
	var out: Array = []
	var now := GameState.now_abs()
	var bf: Dictionary = r.get("buffs", {})
	for k: String in bf:
		var b: Dictionary = bf[k]
		var left := int(b.get("until", 0)) - now
		if left <= 0:
			continue
		var amt := float(b.get("amount", 1))
		var what: String = {"speed": "+%d%% move speed" % roundi(15 * amt), "luck": "+%d luck" % int(amt), "defense": "+%d defense" % int(amt), "warm": "no chill or freeze"}.get(k, "+%s %s" % [str(amt), k])
		out.append({"name": str(BUFF_NAMES.get(k, k.capitalize())), "icon": buff_icon(k), "left": duration(left), "what": what, "bad": false})
	var haste := int(r.get("flags", {}).get("haste_abs", -1)) - now
	if haste > 0:
		out.append({"name": "Haste", "icon": ["ui", "buff2_haste"] if Art.has("ui", "buff2_haste") else [], "left": duration(haste), "what": "×1.3 move speed", "bad": false})
	if int(r.get("flags", {}).get("shield", 0)) > 0:
		out.append({"name": "Shielded", "icon": ["ui", "status_shielded"], "left": "%d hit%s" % [int(r["flags"]["shield"]), "" if int(r["flags"]["shield"]) == 1 else "s"], "what": "the next hit is stopped", "bad": false})
	var st: Dictionary = r.get("status", {})
	for k: String in st:
		var secs := float((st[k] as Dictionary).get("secs", 0.0))
		if secs <= 0.0:
			continue
		var def := GameState.status_def(k)
		var what := ""
		if def.has("dps"):
			what = "loses health"
		elif def.has("speed"):
			what = "slower (×%.2f)" % float(def["speed"])
		elif def.has("damage"):
			what = "hits softer (%d)" % int(def["damage"])
		elif def.has("aim"):
			what = "swings go wide"
		out.append({"name": k.capitalize(), "icon": ["ui", "status_" + k], "left": "%ds" % ceili(secs), "what": what, "bad": true})
	if int(r.get("energy", 0)) < int(r.get("max_energy", 100)) * float(gs_const("EXHAUSTED_FRAC", 0.15)):
		out.append({"name": "Exhausted", "icon": [], "left": "until you rest", "what": "tasks cost more, slower when nearly empty", "bad": true})
	return out


## Milestones: [[label, text, frac (or -1)]].
static func milestones() -> Array:
	var r := GameState.run
	var out: Array = []
	var cc := chapter_count()
	var ct := chapter_title()
	if ct.begins_with("Chapter"):
		ct = ct.substr(ct.find(" ", 8) + 1).trim_prefix("— ").trim_prefix("- ").trim_prefix(": ")
	out.append(["Story", "Chapter %d%s%s" % [Story.chapter_no(), (" of %d" % cc) if cc > 0 else "", (": " + ct) if ct != "" else ""], float(Story.chapter_no()) / cc if cc > 0 else -1.0])
	var hearts_def: Dictionary = GameState.load_json("res://data/hearts.json").get("villagers", {})
	var best := ""
	var bh := -1
	for id in r.get("friendship", {}):
		var h := GameState.friend_hearts(str(id))
		if h > bh:
			bh = h
			best = str(id)
	var cap := maxi(1, hearts_def.size()) * 10
	out.append(["Friendship", "%d ♥ in all%s" % [total_hearts(), (" · closest: %s (%d♥)" % [npc_name(best), bh]) if bh > 0 else ""], minf(1.0, float(total_hearts()) / cap)])
	var grown: Dictionary = r.get("grown", {})
	out.append(["Field log", "%d of %d crops grown" % [grown.size(), GameState.crops.size()], float(grown.size()) / maxi(1, GameState.crops.size())])
	var seen: Dictionary = r.get("seen", {})
	var fish_all := 0
	var fish_seen := 0
	for id: String in GameState.items:
		if str(GameState.items[id].get("type", "")) == "fish":
			fish_all += 1
			if seen.has(id):
				fish_seen += 1
	for cr: Array in Collections.summary_rows():  # museum + logs (C8 P3; replaced "Fish found", which counted unreachable fish)
		out.append([cr[0], "%d of %d" % [cr[1], cr[2]], float(cr[1]) / maxi(1, int(cr[2]))])
	out.append(["Items found", "%d kinds" % seen.size(), -1.0])
	out.append(["Foes met", "%d kinds" % (r.get("kill_counts", {}) as Dictionary).size(), -1.0])
	out.append(["Recipes known", str((r.get("known_recipes", []) as Variant).size() if r.get("known_recipes") is Array or r.get("known_recipes") is Dictionary else 0), -1.0])
	var deep := int(r.get("flags", {}).get("mine_deepest", 1))
	out.append(["Mine record", "floor %d" % deep if r.get("flags", {}).has("mine_deepest") else "not down yet", -1.0])
	var qd: int = r.get("quests", []).filter(func(q: Dictionary) -> bool: return bool(q.get("done", false))).size()
	out.append(["Quests done", "%d of %d taken" % [qd, (r.get("quests", []) as Array).size()], -1.0])
	out.append(["Crystals", "%d◆ in hand%s" % [int(r.get("crystals", 0)), (" · %d◆ earned in all" % int(r["earned_total"])) if r.has("earned_total") else ""], -1.0])
	var up := 0
	for t: String in GameState.TOOL_KINDS:
		up += GameState.tool_tier(t)
	out.append(["Tool upgrades", "%d of %d" % [up, GameState.TOOL_KINDS.size() * (GameState.TOOL_TIERS.size() - 1)], float(up) / (GameState.TOOL_KINDS.size() * (GameState.TOOL_TIERS.size() - 1))])
	out.append(["Days lived", str(int(r.get("day", 1))), -1.0])
	if Romance.hero_line() != "": out.append(["Heart", Romance.hero_line(), -1.0])  # dating/engaged/married (C7 P1)
	return out


# ---- UI ----------------------------------------------------------------------

static var _menu: GameMenu


static func build(menu: GameMenu, body: VBoxContainer) -> void:
	_menu = menu
	if sel_slot != "" and not GameState.SLOTS.has(sel_slot):
		sel_slot = ""
	_header(body)
	_doll(body)
	if sel_slot != "":
		_slot_panel(body)
	_weapons(body)
	_stats(body)
	_effects(body)
	_skills(body)
	_milestones(body)


static func _redo() -> void:
	if is_instance_valid(_menu):
		_menu._refresh()


static func _card(body: Control, title := "") -> VBoxContainer:
	if title != "":
		var tl := Label.new()
		tl.text = title
		tl.add_theme_font_size_override("font_size", Settings.font(9))  # Options > Text size (C9)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
		tl.add_theme_constant_override("outline_size", 2)
		tl.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
		body.add_child(tl)
	var pc := PanelContainer.new()
	var sb := Hud.panel_stylebox("panel_parchment") as StyleBoxFlat
	sb.set_content_margin_all(4)
	sb.set_corner_radius_all(3)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	return v


static func _lab(parent: Control, text: String, size := 8, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	# Text size grows lines in a column only; side-by-side cells (stat rows, slot
	# captions) keep their size so the 270-px sheet never widens.
	l.add_theme_font_size_override("font_size", Settings.font(size) if parent is VBoxContainer and not parent.get_parent() is HBoxContainer else size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


static func _icon(group: String, name: String, sz: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if name != "" and Art.has(group, name):
		tr.texture = Art.tex(group, name)
	return tr


static func _bar(parent: Control, frac: float, col: Color, h := 5) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 1.0
	b.step = 0.0
	b.value = clampf(frac, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.2, 0.12, 0.5)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b


## A flat parchment row button (release mode: a scroll that starts on it never fires).
static func _row(parent: Control, cb: Callable, h := 20) -> Button:
	var b := Button.new()
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.38, 0.18, 0.0 if st in ["normal", "focus"] else 0.18)
		sb.border_color = Color(0.55, 0.38, 0.18, 0.35)
		sb.border_width_bottom = 1
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func() -> void: Music.instance(b.get_tree()).sfx("ui_tap"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _fill(b: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 2
	h.offset_right = -2
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	return h


static func _small_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", Settings.font(8) if parent is VBoxContainer else 8)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 22)  # finger-sized at 270 wide
	b.pressed.connect(func() -> void: Music.instance(b.get_tree()).sfx("ui_tap"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _hero_tex() -> Texture2D:
	var pid := str(GameState.run.get("playable", ""))
	var gang := not GameState.is_penguins()
	# Gangster arc: the redrawn underworld heroes show their own sprite (the old
	# painted cards, and the farm cards, are a different look).
	var gs := GameState.sprite_for_playable(pid) if gang else ""
	var redrawn := gang and gs.ends_with("_gang") and Art.has("characters/" + gs, "swim") and Art.has("characters/" + gs, "ride")
	for cand: String in ([] if redrawn else (["card_hero_%s_gang" % pid] if gang else []) + ["card_hero_" + pid]):
		if Art.has("ui", cand):
			return Art.tex("ui", cand)
	# No card: the hero's own idle frame from the live player.
	var tree := Engine.get_main_loop() as SceneTree
	var gm := tree.current_scene as GameMap if tree and tree.current_scene is GameMap else null
	if gm and gm.player and gm.player._anim and gm.player._anim.sprite_frames:
		var sf := gm.player._anim.sprite_frames
		for a: String in ["idle", "view_front", "walk_down", str(gm.player._anim.animation)]:
			if sf.has_animation(a) and sf.get_frame_count(a) > 0:
				return sf.get_frame_texture(a, 0)
	for cand: String in ["card_hero_custom_gang" if gang else "card_hero_custom", "card_hero_custom"]:
		if Art.has("ui", cand):
			return Art.tex("ui", cand)
	return null


static func _header(body: Control) -> void:
	var r := GameState.run
	var v := _card(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)
	var rn := renown()
	var ri := rank_index(rn)
	var rk := _icon("ui", "rank_%d" % clampi(ri, 1, 5), 18)
	if ri == 0:
		rk.modulate = Color(1, 1, 1, 0.35)
	rk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(rk)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nv)
	_lab(nv, str(r.get("names", {}).get("character", "You")), 11, INK)
	_lab(nv, rank_name(ri), 8, GOLD)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", -2)
	top.add_child(cv)
	var c1 := _lab(cv, "%s %d, Year %d" % [GameState.season().capitalize(), GameState.day_of_season(), (int(r.get("day", 1)) - 1) / (GameState.DAYS_PER_SEASON * 4) + 1], 7, INK)
	c1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c1.autowrap_mode = TextServer.AUTOWRAP_OFF
	var c2 := _lab(cv, "Day %d · %s" % [int(r.get("day", 1)), GameState.clock_of(int(r.get("time", GameState.DAY_START)))], 7, INK_SOFT)
	c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c2.autowrap_mode = TextServer.AUTOWRAP_OFF
	var arc_t := str(GameState.arcs.get(str(r.get("arc", "")), {}).get("title", ""))
	if arc_t != "":
		_lab(v, arc_t, 7, INK_SOFT)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 3)
	v.add_child(rh)
	var nxt := ri + 1
	var rl := _lab(rh, "Renown %d" % rn, 7, INK)
	rl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	if nxt < RANK_AT.size():
		var lo := int(RANK_AT[ri])
		var hi := int(RANK_AT[nxt])
		var bb := _bar(rh, float(rn - lo) / maxi(1, hi - lo), Color(0.85, 0.62, 0.15), 5)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rl2 := _lab(rh, "%s at %d" % [(RANK_PENGUIN if GameState.is_penguins() else RANK_GANG)[nxt], hi], 7, INK_SOFT)
		rl2.size_flags_horizontal = Control.SIZE_SHRINK_END
		rl2.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		_lab(rh, "· the highest title", 7, GOLD)
	_lab(v, "Renown: skill levels, hearts, story chapters, mine depth, quests.", 6, INK_SOFT)


static func _slot_cell(slot: String) -> Control:
	var id := GameState.equipped(slot)
	var b := Button.new()
	b.custom_minimum_size = Vector2(32, 32)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.focus_mode = Control.FOCUS_NONE
	var tex_name := "slot2_selected" if slot == sel_slot and Art.has("ui", "slot2_selected") else "slot2"
	for st: String in ["normal", "hover", "pressed", "focus"]:
		if Art.has("ui", tex_name):
			var sbt := StyleBoxTexture.new()
			sbt.texture = Art.tex("ui", tex_name)
			sbt.texture_margin_left = 8
			sbt.texture_margin_right = 8
			sbt.texture_margin_top = 8
			sbt.texture_margin_bottom = 8
			sbt.modulate_color = Color(1.15, 1.1, 0.9) if st == "pressed" else Color.WHITE
			b.add_theme_stylebox_override(st, sbt)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.3, 0.2, 0.12)
			sb.border_color = Color(1, 0.85, 0.4) if slot == sel_slot else Color(0.15, 0.09, 0.04)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(3)
			b.add_theme_stylebox_override(st, sb)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if slot == sel_slot:
		b.self_modulate = Color(1.35, 1.2, 0.6)
	if id != "":
		var ic := _icon("items", Hud.icon_for(id), 20)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 6
		ic.offset_top = 6
		ic.offset_right = -6
		ic.offset_bottom = -6
		b.add_child(ic)
		if ic.texture == null:
			b.text = GameState.item_name(id).left(4)
			b.add_theme_font_size_override("font_size", 7)
		if is_tempered(id):
			var pl := Label.new()
			pl.text = "+1"
			pl.add_theme_font_size_override("font_size", 7)
			pl.add_theme_color_override("font_color", Color(0.6, 1, 0.5))
			pl.add_theme_constant_override("outline_size", 2)
			pl.add_theme_color_override("font_outline_color", Color.BLACK)
			pl.position = Vector2(19, 1)
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(pl)
		# Rarity in the corner: one dot per rank in the rarity colour, so colour-blind
		# players read it by count (C9 c9_07: uncommon/legendary and rare/epic collapsed).
		for di in rarity_rank(id):
			var pip := ColorRect.new()
			pip.color = rarity_col(id)
			pip.size = Vector2(RANK_DOT, RANK_DOT)
			pip.position = Vector2(4 + di * (RANK_DOT + 1), 24)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var back := ColorRect.new()
			back.color = Color(0, 0, 0, 0.8)
			back.size = Vector2(RANK_DOT + 2, RANK_DOT + 2)
			back.position = pip.position - Vector2.ONE
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(back)
			b.add_child(pip)
		if rarity_of(id) == "unique":
			var star := Label.new()  # unique: a star plate beside the dots (colour-blind safe)
			star.text = "★"
			star.add_theme_font_size_override("font_size", 7)
			star.add_theme_color_override("font_color", rarity_col(id))
			star.add_theme_constant_override("outline_size", 2)
			star.add_theme_color_override("font_outline_color", Color.BLACK)
			star.position = Vector2(22, 19)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(star)
	else:
		var el := Label.new()
		el.text = slot_name(slot)
		el.add_theme_font_size_override("font_size", 7)
		el.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6, 0.75))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		el.set_anchors_preset(Control.PRESET_FULL_RECT)
		el.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(el)
		if not candidates(slot).is_empty():
			var dot := Label.new()  # something in the bag fits here
			dot.text = "●"
			dot.add_theme_font_size_override("font_size", 7)
			dot.add_theme_color_override("font_color", Color(0.55, 1, 0.45))
			dot.position = Vector2(22, 1)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
	b.pressed.connect(func() -> void:
		Music.instance(b.get_tree()).sfx("ui_tap")
		sel_slot = "" if sel_slot == slot else slot
		_redo())
	return b


static func _doll(body: Control) -> void:
	var v := _card(body, "Equipment")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 1)
	row.add_child(lc)
	for s: String in LEFT:
		lc.add_child(_slot_cell(s))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 1)
	row.add_child(mid)
	var ht := _hero_tex()
	if Wardrobe.hero_kind() == "doll" and PaperDoll.available():
		var dv := Control.new()  # the build-your-own hero as they really look (outfit, hair, hat)
		dv.custom_minimum_size = Vector2(0, 118)
		dv.clip_contents = true
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(dv)
		var dh := Node2D.new()
		dv.add_child(dh)
		dv.resized.connect(func() -> void: dh.position = Vector2(dv.size.x / 2.0, 114))
		PaperDoll.build_preview(dh, GameState.run.get("look", {}), 3.3, "idle")
		ht = null
	elif Wardrobe.hero_kind() in ["penguin", "pin"]:
		# Penguin / drawn heroes: a live sprite wearing the pinned pieces, like the wardrobe preview (c10b_11-19).
		var spr := GameState.sprite_for_playable(str(GameState.run.get("playable", "")))
		if spr != "" and CharacterLibrary.has_character(spr):
			var pv := Control.new()
			pv.custom_minimum_size = Vector2(0, 118)
			pv.clip_contents = true
			pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mid.add_child(pv)
			var ph := Node2D.new()
			pv.add_child(ph)
			pv.resized.connect(func() -> void: ph.position = Vector2(pv.size.x / 2.0, 112))
			var sp := CharacterLibrary.make_sprite(spr)
			sp.scale *= 3.0
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			ph.add_child(sp)
			sp.play("idle" if sp.sprite_frames.has_animation("idle") else sp.sprite_frames.get_animation_names()[0])
			Wardrobe.dress_hero(ph, sp, spr)
			ht = null
	var hr := TextureRect.new()
	hr.texture = ht
	hr.custom_minimum_size = Vector2(0, 118)
	hr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if ht and ht.get_width() > 60 else CanvasItem.TEXTURE_FILTER_NEAREST
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ht != null:
		mid.add_child(hr)
	var wn := 0
	for ws: String in Wardrobe.SHOWN_SLOTS:
		wn += WardrobeScreen._choices(ws).size()
	var wb := _small_btn(mid, "Wardrobe (%d)" % wn, func() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			var w := WardrobeScreen.open(tree.current_scene)
			w.closed.connect(_redo))
	wb.set_meta("pc_key", "wardrobe")
	var worn: Array = []
	var badges: Array = []
	for ws2: String in Decor.WEAR_SLOTS:
		var wid := Wardrobe.worn_id(ws2)
		if wid == "":
			continue
		if Wardrobe.shows_on(wid):
			worn.append(str(Wardrobe.entry(wid).get("name", wid)))
		else:
			badges.append(wid)  # not drawn on this hero: a badge, not a promise (c10b_11-03/19)
	if not badges.is_empty():
		var br := HBoxContainer.new()
		br.alignment = BoxContainer.ALIGNMENT_CENTER
		br.add_theme_constant_override("separation", 2)
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(br)
		for bid: String in badges.slice(0, 6):
			var bt := TextureRect.new()
			bt.texture = WardrobeScreen.icon_tex(bid)
			if bt.texture == null:
				bt.texture = DecorCatalogue.icon_tex(bid)
			bt.custom_minimum_size = Vector2(16, 16)
			bt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			bt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			bt.tooltip_text = str(Wardrobe.entry(bid).get("name", bid))
			bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			br.add_child(bt)
		var bl := _lab(mid, "Also wearing (not drawn): " + ", ".join(badges.map(func(i: String) -> String: return str(Wardrobe.entry(i).get("name", i)))), 7, INK_SOFT)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not worn.is_empty():
		var lk := _lab(mid, "Look: " + ", ".join(worn) + ("" if Wardrobe.hero_kind() != "doll" else ("  (armour shown)" if Wardrobe.show_armor() else "")), 7, INK_SOFT)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dp := DecorCatalogue.progress()
	if int(dp[1]) > 0:  # C10a: decor catalogue progress (P3's numbers)
		var dsc := DecorCatalogue.set_counts()
		var dl := _lab(mid, "Decor: %d/%d kinds · sets %d/%d" % [int(dp[0]), int(dp[1]), int(dsc[0]), int(dsc[1])], 7, INK_SOFT)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gs: Array = []
	for k: String in ["defense", "speed", "luck", "energy", "damage", "mana"]:
		var n := GameState.gear_stat(k)
		if n != 0:
			gs.append("%s %+d" % [STAT_SHORT[k], n])
	var gl := _lab(mid, "Gear: " + (" · ".join(gs) if not gs.is_empty() else "none yet"), 7, INK)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 1)
	row.add_child(rc)
	for s: String in RIGHT:
		rc.add_child(_slot_cell(s))
	# Armour sets being worn.
	var sc := set_counts()
	var live := sets_live()
	for st: String in sc:
		var n := int(sc[st])
		var txt := "%s set %d/8" % [st.capitalize(), n]
		var b4 := set_bonus_for(st, 4)
		var b8 := set_bonus_for(st, 8)
		if live:
			txt += "  ·  4: %s%s  ·  8: %s%s" % [stat_text(b4), " ✓" if n >= 4 else "", stat_text(b8), " ✓" if n >= 8 else ""]
		_lab(v, txt, 7, GOOD if live and n >= 4 else INK_SOFT)
	if sel_slot == "":
		_lab(v, "Tap a slot to see what fits it. ● = something in your bag fits.", 6, INK_SOFT)


static func _slot_panel(body: Control) -> void:
	var slot := sel_slot
	var cur := GameState.equipped(slot)
	var v := _card(body, "%s slot" % slot_name(slot))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	if cur != "":
		h.add_child(_icon("items", Hud.icon_for(cur), 20))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(cv)
		var it: Dictionary = GameState.items.get(cur, {})
		_lab(cv, GameState.item_name(cur) + ("  (tempered)" if is_tempered(cur) else ""), 8, ink_rarity(cur))
		_lab(cv, "%s · tier %d · %s" % [str(it.get("rarity", "common")).capitalize(), int(it.get("tier", 1)), stat_text(item_stats(cur))], 7, INK)
		if it.has("desc"):
			_lab(cv, str(it["desc"]), 6, INK_SOFT)
		_small_btn(h, "Take off", func() -> void:
			if GameState.bag_free() <= 0 and GameState.count(cur) <= 0:
				GameState.notify("Your bag is full: make room first.")
				return
			GameState.unequip(slot)
			_refresh_player()
			_redo())
		var st := set_of(cur)
		var plus := cur + "_plus"
		if st != "" and not is_tempered(cur) and GameState.items.has(plus):
			_lab(v, "Temper it at the %s → %s" % [str(TEMPER_AT.get(st, "Anvil")), stat_text(item_stats(plus))], 7, GOLD)
	else:
		_lab(h, "Nothing worn here.", 8, INK_SOFT)
	var cands := candidates(slot)
	if cands.is_empty():
		var where := "the Anvil and Tannery, shops and chests" if GameState.is_penguins() else "the Anvil, the Street Armory, shops and chests"
		_lab(v, "Nothing for this slot in your bag. Gear comes from %s (pieces in chests must be in your bag to wear)." % where, 7, INK_SOFT)
	else:
		_lab(v, "In your bag (tap to wear; ▲▼ against what you have on):", 7, INK)
	for id: String in cands:
		var cmp := compare(id, cur)
		var score := gear_score(item_stats(id)) - gear_score(item_stats(cur) if cur != "" else {})
		var b := _row(v, func() -> void:
			GameState.equip(id)
			_refresh_player()
			Music.instance(_menu.get_tree()).sfx("equip", "ui_tap")
			_redo(), 22)
		var f := _fill(b)
		f.add_child(_icon("items", Hud.icon_for(id), 18))
		var nl := _lab(f, GameState.item_name(id) + ("  ×%d" % GameState.count(id) if GameState.count(id) > 1 else ""), 7, ink_rarity(id))
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var parts: Array = []
		for c: Array in cmp:
			parts.append("%s %+d%s" % [c[0], int(c[1]), "▲" if int(c[1]) > 0 else "▼"])
		var dl := _lab(f, " ".join(parts) if not parts.is_empty() else "same", 7, GOOD if score > 0.01 else (BAD if score < -0.01 else INK_SOFT))
		dl.size_flags_horizontal = Control.SIZE_SHRINK_END
		dl.autowrap_mode = TextServer.AUTOWRAP_OFF
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_small_btn(v, "Close", func() -> void: sel_slot = ""; _redo())


## Rarity colour readable on parchment (common reads as plain ink).
## darkened(0.62) keeps every rank >= 4.5:1 on the parchment (c10_07; 0.4 left
## uncommon/legendary near 3:1); the rank dots carry the colour-blind cue.
static func ink_rarity(id: String) -> Color:
	if rarity_of(id) == "common":
		return INK
	return rarity_col(id).darkened(0.62)


static func _refresh_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene is GameMap and (tree.current_scene as GameMap).player:
		(tree.current_scene as GameMap).player.refresh_doll()


static func _weapons(body: Control) -> void:
	var v := _card(body, "Weapons & tools")
	var held := GameState.held_tool()
	var ws: Array = []
	for t: String in GameState.run.get("tools", []):
		var it: Dictionary = GameState.items.get(t, {})
		if int(it.get("damage", 0)) > 0 and (GameState.is_sword(t) or it.has("range")):
			ws.append(t)
	ws.sort_custom(func(a: String, b: String) -> bool: return int(GameState.items[a].get("damage", 0)) > int(GameState.items[b].get("damage", 0)))
	if ws.is_empty():
		_lab(v, "No weapon yet.", 7, INK_SOFT)
	for t: String in ws:
		var it: Dictionary = GameState.items[t]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		v.add_child(h)
		h.add_child(_icon("items", icon_of(t), 14))
		var l := _lab(h, "%s%s" % [weapon_name(t), "  (in hand)" if t == held else ""], 7, INK if t != held else GOLD)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var d := _lab(h, ("dmg %d · range %d" % [int(it["damage"]), int(it["range"])]) if it.has("range") else "dmg %d" % int(it["damage"]), 7, INK_SOFT)
		d.size_flags_horizontal = Control.SIZE_SHRINK_END
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	v.add_child(g)
	for k: String in GameState.TOOL_KINDS:
		var owned := GameState.has_tool(k) or (k == "sword" and not ws.is_empty())
		var tier := GameState.tool_tier(k)
		var b := _row(g, func() -> void: sel_tool = "" if sel_tool == k else k; _redo(), 22)
		b.custom_minimum_size = Vector2(54, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var f := _fill(b)
		var ic := _icon("items", Hud.icon_for(k), 16)
		f.add_child(ic)
		var tl := _lab(f, GameState.TOOL_TIERS[tier].capitalize() if owned else "—", 6, INK if owned else INK_SOFT)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		if not owned:
			ic.modulate = Color(1, 1, 1, 0.35)
		if k == sel_tool:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.85, 0.62, 0.2, 0.35)
			sb.set_corner_radius_all(2)
			for st: String in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, sb)
	if sel_tool != "":
		var k := sel_tool
		var tier := GameState.tool_tier(k)
		var txt := "%s: %s (tier %d of %d)" % [GameState.item_name(k).capitalize(), GameState.TOOL_TIERS[tier].capitalize(), tier + 1, GameState.TOOL_TIERS.size()]
		if k in ["hoe", "can", "axe", "pickaxe", "rod", "scythe", "hammer"]:
			var ac := avg_cost(k)
			txt += (" · %.2f energy a use" if ac < 1.0 else " · %.1f energy a use") % ac
		var need := GameState.upgrade_need(k)
		if need.is_empty():
			txt += "\nFully upgraded."
		else:
			var parts: Array = []
			for nk: String in need:
				parts.append("%d◆" % int(need[nk]) if nk == "crystals" else "%d %s (have %d)" % [int(need[nk]), GameState.item_name(nk), GameState.count(nk)])
			txt += "\nNext: %s at the Blacksmith: %s" % [GameState.TOOL_TIERS[tier + 1].capitalize(), ", ".join(parts)]
		_lab(v, txt, 7, INK)
	else:
		_lab(v, "Tap a tool for its upgrade path.", 6, INK_SOFT)


static func _stats(body: Control) -> void:
	var v := _card(body, "Stats (tap one to see where it comes from)")
	for s: Dictionary in stats():
		var sid := str(s["id"])
		var b := _row(v, func() -> void: open_stat = "" if open_stat == sid else sid; _redo(), 20)
		var f := _fill(b)
		var ic: Array = s.get("icon", [])
		f.add_child(_icon(str(ic[0]) if ic.size() == 2 else "", str(ic[1]) if ic.size() == 2 else "", 12))
		var nl := _lab(f, ("▾ " if open_stat == sid else "▸ ") + str(s["name"]), 8, INK)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var vl := _lab(f, str(s["value"]), 8, GOLD)
		vl.size_flags_horizontal = Control.SIZE_SHRINK_END
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if open_stat == sid:
			var box := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.85, 0.74, 0.52, 0.6)
			sb.set_corner_radius_all(2)
			sb.set_content_margin_all(3)
			sb.content_margin_left = 8
			box.add_theme_stylebox_override("panel", sb)
			v.add_child(box)
			var bv := VBoxContainer.new()
			bv.add_theme_constant_override("separation", 0)
			box.add_child(bv)
			for pr: Array in s["parts"]:
				var h := HBoxContainer.new()
				bv.add_child(h)
				_lab(h, str(pr[0]), 7, INK)
				var pv := _lab(h, str(pr[1]), 7, BAD if str(pr[1]).begins_with("-") or str(pr[1]).begins_with("×0") else GOOD)
				pv.size_flags_horizontal = Control.SIZE_SHRINK_END
				pv.autowrap_mode = TextServer.AUTOWRAP_OFF
			if str(s.get("note", "")) != "":
				_lab(bv, str(s["note"]), 6, INK_SOFT)


static func _effects(body: Control) -> void:
	var v := _card(body, "Buffs & statuses")
	var ef := effects()
	if ef.is_empty():
		_lab(v, "None right now. Tonics, cocoa and some dishes give buffs; foes can poison, burn or chill you.", 7, INK_SOFT)
	for e: Dictionary in ef:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		v.add_child(h)
		var ic: Array = e["icon"]
		h.add_child(_icon(str(ic[0]) if ic.size() == 2 else "", str(ic[1]) if ic.size() == 2 else "", 14))
		var l := _lab(h, "%s: %s" % [e["name"], e["what"]], 7, BAD if e["bad"] else GOOD)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var t := _lab(h, str(e["left"]), 7, INK_SOFT)
		t.size_flags_horizontal = Control.SIZE_SHRINK_END
		t.autowrap_mode = TextServer.AUTOWRAP_OFF


const SKILL_ICON := {"farming": "hoe", "mining": "pickaxe", "foraging": "axe", "fishing": "rod", "combat": "sword", "magic": "crystal", "pup": "bone", "bartering": "gold", "building": "hammer", "leadership": "paw_charm", "strategist": "map", "harmony": "big_crystal", "hustle": "six_shooter"}


static func _skills(body: Control) -> void:
	var v := _card(body, "Skills (tap to open the tree)")
	var total := 0
	for sk: String in GameMenu.SKILL_ORDER:
		if not GameState.skills_data.has(sk) or not GameState.skill_in_arc(sk):
			continue
		var lvl := GameState.skill_level(sk)
		total += lvl
		var xp := int(GameState.run["skills"].get(sk, {}).get("xp", 0))
		var need := GameState.xp_for_next(lvl)
		var pf := GameState.points_free(sk)
		var kk := sk
		var b := _row(v, func() -> void:
			if is_instance_valid(_menu):
				_menu._skill_open = kk
				_menu._node_sel = ""
				_menu._tab = "Skills"
				_menu._refresh(), 20)
		var f := _fill(b)
		var grp := "items"
		var nm := Hud.icon_for(str(SKILL_ICON.get(sk, "map")))
		for cand: String in ["skill2_", "skill3_", "skill_"]:
			if Art.has("ui", cand + sk):
				grp = "ui"
				nm = cand + sk
				break
		f.add_child(_icon(grp, nm, 14))
		var l := _lab(f, "%s %d" % [str(GameState.skills_data[sk]["name"]), lvl], 7, INK)
		l.custom_minimum_size = Vector2(70, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bar := _bar(f, float(xp) / maxi(1, need), Color(0.35, 0.62, 0.25), 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var xl := _lab(f, ("•%d pt  " % pf if pf > 0 else "") + "%d/%d" % [xp, need], 6, GOLD if pf > 0 else INK_SOFT)
		xl.size_flags_horizontal = Control.SIZE_SHRINK_END
		xl.custom_minimum_size = Vector2(52, 0)
		xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xl.autowrap_mode = TextServer.AUTOWRAP_OFF
		xl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lab(v, "Total skill level %d · %s" % [total, "your strongest: " + _top_skill()], 7, INK_SOFT)


static func _top_skill() -> String:
	var best := ""
	var bl := 0
	for sk in GameState.skills_data.keys():
		if GameState.skill_in_arc(str(sk)) and GameState.skill_level(str(sk)) > bl:
			bl = GameState.skill_level(str(sk))
			best = str(GameState.skills_data[sk]["name"])
	return "%s %d" % [best, bl] if bl > 1 else "none yet"


static func _milestones(body: Control) -> void:
	var v := _card(body, "Milestones")
	for m: Array in milestones():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		v.add_child(h)
		var l := _lab(h, str(m[0]), 7, INK)
		l.custom_minimum_size = Vector2(62, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var t := _lab(h, str(m[1]), 7, INK_SOFT)
		if float(m[2]) >= 0.0:
			var bb := _bar(v, float(m[2]), Color(0.75, 0.55, 0.2), 3)
			bb.custom_minimum_size = Vector2(0, 3)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The hero on the current map (null in tests without one).
static func _sheet_player():
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var cs := (ml as SceneTree).current_scene
		if cs is GameMap and (cs as GameMap).player != null and is_instance_valid((cs as GameMap).player):
			return (cs as GameMap).player
	return null
