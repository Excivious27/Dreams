class_name Sanctuary
extends RefCounted
## The penguin arc's own buildings: the Merkitty Pool and the Crystal Baby
## Burrow leave things for you overnight, and the Meow Pow Wow Shrine makes
## the spell stronger.
##   run["gifts"] = {"pool": {item: n}, "burrow": {item: n}}  waiting to be picked up

const POOL := [[], ["minnow", "trout", "seashell", "shell"], ["trout", "bass", "seashell", "pearl", "crab"], ["salmon", "tuna", "pearl", "pearl", "crab", "moon_tear"]]
const BURROW := [[], ["stone", "stone", "coal", "copper", "shard"], ["coal", "copper", "iron", "iron", "shard", "shard"], ["iron", "silver", "gold", "shard", "crystal_refined", "amethyst"]]


static func on() -> bool:
	return str(GameState.run.get("arc", "")) == "penguins"


## Ranks the shrine adds to the Meow Pow Wow.
static func meow_bonus() -> int:
	return maxi(0, Builds.built_tier("shrine") - 1) if on() else 0


static func _leave(kind: String, pool: Array, rolls: int, each: int) -> int:
	var gifts: Dictionary = GameState.run.get("gifts", {})
	GameState.run["gifts"] = gifts
	var box: Dictionary = gifts.get(kind, {})
	gifts[kind] = box
	var held := 0
	for id in box:
		held += int(box[id])
	var n := 0
	for i in rolls:
		if held >= 30:
			break  # the basket is full: come and empty it
		var id := str(pool[randi() % pool.size()])
		if not GameState.items.has(id):
			continue
		box[id] = int(box.get(id, 0)) + each
		held += each
		n += each
	return n


## Called from sleep().
static func overnight(report: Dictionary) -> void:
	if not on():
		return
	var pt := Builds.built_tier("pool")
	var bt := Builds.built_tier("burrow")
	var n := 0
	if pt > 0:
		n += _leave("pool", POOL[pt], pt, 1)
	if bt > 0:
		n += _leave("burrow", BURROW[bt], 2 + bt, 1 + bt)
	if n > 0:
		report["left"] = n


static func collect(m: GameMap, kind: String) -> void:
	var box: Dictionary = GameState.run.get("gifts", {}).get(kind, {})
	var who := "The merkitties" if kind == "pool" else "The babies"
	if box.is_empty():
		if kind == "burrow":
			m.fx("baby_sleep", m.player.position + m.player.facing_dir() * 14.0 + Vector2(0, -10), 3.0, 0.5)
		var d := Dialogue.instance(m.get_tree())
		d.say([{"who": "", "text": "The water is still. Something silver turns over, far down. They leave their gifts in the night." if kind == "pool" else "Small snores from the burrow. \"Bee bop... boo...\" They dig at night and sleep all day."}])
		await d.finished
		return
	m.fx("merkitty_%s" % ["a", "b", "c"][randi() % 3] if kind == "pool" else "baby_carry", m.player.position + m.player.facing_dir() * 16.0 + Vector2(0, -10), 6.0, 0.5)
	for id in box.keys():
		m.give(str(id), int(box[id]))
	box.clear()
	m.xp("fishing" if kind == "pool" else "mining", 6)
	m.hud.toast("%s left these for you." % who, Color(0.8, 0.95, 1.0))
	Music.instance(m.get_tree()).sfx("pickup")


static func shrine(m: GameMap) -> void:
	var st := Builds.built_tier("shrine")
	var done: bool = int(GameState.run["flags"].get("shrine_day", -1)) == int(GameState.run["day"])
	var d := Dialogue.instance(m.get_tree())
	var text := "The stone is warm, like something asleep in the sun."
	if st >= 2:
		text += " Your Meow Pow Wow reaches %d rank%s further here." % [st - 1, "" if st == 2 else "s"]
	d.say([{"who": str(Builds.current_def("shrine").get("name", "Shrine")), "text": text, "choice": ["Practise (done for today)" if done else "Practise the Meow Pow Wow", "Leave"], "key": ""}])
	await d.finished
	if d.last_choice != 0 or done:
		return
	GameState.run["flags"]["shrine_day"] = int(GameState.run["day"])
	m.player.play_tool("hold")
	m.fx("heart_burst" if Art.has("fx", "heart_burst") else "pawring", m.player.position + Vector2(0, -16), 9.0, 0.5)
	GameState.restore_mana(20 * (2 if st >= 2 else 1))
	m.xp("foraging", 12 * (2 if st >= 2 else 1))
	m.hud.toast("Hands at your chest. A small heart of light, steadier than yesterday.", Color(1, 0.8, 0.95))
