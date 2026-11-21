class_name BugNet
extends RefCounted
## C16a P4 (c16a_08-12, contract "BugNet"): the bug net. Tool ids bug_net (Twig, tier 0), silk_net (1), star_net (2)
## sold at Maple's (Shops "store" offers the next net once Foraging allows it). Swing (USE) at a critter in reach:
## it is logged in the Critter log (Collections.record_critter) and let go right away. All ages: nothing is harmed,
## kept, sold or eaten. Rules per critter: Critters (data from tools/gen_collections.py).

const NET_IDS := ["bug_net", "silk_net", "star_net"]
const REACH := [1.5, 2.5, 3.5]  # cells, by tier


static func is_net(id: String) -> bool:
	return id in NET_IDS


## Best net owned (-1: none).
static func tier() -> int:
	var t := -1
	for i in NET_IDS.size():
		if GameState.has_tool(NET_IDS[i]):
			t = i
	return t


static func net_name(t: int) -> String:
	var id: String = NET_IDS[clampi(t, 0, NET_IDS.size() - 1)]
	var it: Dictionary = GameState.items.get(id, {})
	if not GameState.is_penguins() and str(it.get("name_gang", "")) != "":
		return str(it["name_gang"])
	return str(it.get("name", id))


## Shops "store" hook: the next net, when the Foraging level allows it.
static func shop_offer() -> Array:
	var nets: Dictionary = Collections.data().get("nets", {})
	var t := tier()
	if t + 1 >= NET_IDS.size():
		return []
	var nid: String = NET_IDS[t + 1]
	if not GameState.items.has(nid):
		return []
	if GameState.skill_level("foraging") < int((nets.get(nid, {}) as Dictionary).get("lvl", 0)):
		return []
	return [nid]


## Shops hook after buying a net: the new net takes the old one's toolbar slot.
static func after_buy(id: String) -> void:
	if not is_net(id):
		return
	var tb: Array = GameState.run.get("toolbar", [])
	var at := tb.find(id)
	for old in NET_IDS:
		if old == id:
			continue
		var o := tb.find(old)
		if o >= 0:
			if at >= 0:
				tb[at] = ""
			tb[o] = id
			return


## Nearest catchable-looking critter in reach in front of `pos` (facing `dir`), or null.
static func target(m: Node, pos: Vector2, dir: Vector2, reach_cells: float) -> Node:
	var best: Node = null
	var bd := reach_cells * 16.0 + 4.0
	for ch in m.get_children():
		if not (ch is WorldGen.Critter) or not ch.visible:
			continue
		var d: Vector2 = (ch as Node2D).position - pos
		var l := d.length()
		if l > bd:
			continue
		if l > 10.0 and dir != Vector2.ZERO and d.normalized().dot(dir) < 0.2:
			continue  # behind you
		if Critters.for_kind(str(ch.kind)).is_empty():
			continue
		best = ch
		bd = l
	return best


## One swing of the held net (Player.do_action hook). Returns a short result word for tests:
## "caught:<id>", "legend:<id>", "miss", "blocked", "none", "tired".
static func swing(m: Node, p: Node2D) -> String:
	var t := tier()
	if t < 0:
		return "none"
	if not GameState.spend_for("net"):  # a light swing (energy row "net", 0.25, foraging)
		if m.get("hud"):
			m.hud.toast("Too tired.", Color(1, 0.7, 0.7))
		return "tired"
	if p.has_method("play_tool"):
		p.play_tool("axe")
	Music.instance(p.get_tree()).sfx("swing", "swing")
	var dir: Vector2 = p.facing_dir() if p.has_method("facing_dir") else Vector2.ZERO
	var hour := int(GameState.run.get("time", 720)) / 60
	var se := GameState.season()
	var lvl := GameState.skill_level("foraging")
	# Legends turn up on any swing at the right moment (Star Net, Foraging 40).
	var leg := Critters.legend_roll(se, GameState.weather_today(), hour, t, lvl)
	if leg != "":
		_logged(m, p, leg, true)
		return "legend:" + leg
	var cr := target(m, p.position, dir, REACH[t])
	if cr == null:
		return "none"
	var e := Critters.for_kind(str(cr.kind))
	var why := Critters.blocked_by(e, t, lvl)
	if why != "":
		_release(cr)
		if m.get("hud"):
			m.hud.toast(why, Color(1, 0.85, 0.6))
		return "blocked"
	if randf() > Critters.catch_chance(e, bool(cr.get("_flee")), t):
		cr.set("_flee", true)
		if m.get("hud"):
			m.hud.toast("It slipped away. Creep up slower.", Color(1, 0.85, 0.6))
		return "miss"
	_logged(m, p, str(e["id"]), false)
	_release(cr)
	return "caught:" + str(e["id"])


static func _logged(m: Node, p: Node2D, id: String, legend: bool) -> void:
	var first := Collections.record_critter(id)
	var nm := Critters.name_of(id)
	if m.get("hud"):
		if legend:
			m.hud.toast("The %s! It lets you look, then drifts off." % nm, Color(1, 0.9, 0.5))
		else:
			m.hud.toast("%s logged%s, and let go." % [nm, " (new!)" if first else ""], Color(0.8, 1, 0.8))
	Music.instance(p.get_tree()).sfx("quest_done" if legend or first else "pickup", "coin")
	if m.has_method("xp"):
		m.xp("foraging", 6 if legend else (3 if first else 1))


## Let it go: it hops/flies off and is gone from this visit (never hurt).
static func _release(cr: Node) -> void:
	if not is_instance_valid(cr):
		return
	cr.set("_flee", true)
	var tw := (cr as Node2D).create_tween()
	tw.tween_property(cr, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cr.queue_free)
