class_name CampaignFollow
extends RefCounted
## C17 P3 (c17_05-01, c17_05-09, c17_18-15): Tom's rule: a guest may follow the
## host past a border the HOST opened, visit-only. The host answers a guest's
## "campaign_open_req" with the region scene ids its own story has open (scene ids,
## not campaign ids: a penguin host and a gangster guest share regions, not cids).
## The guest keeps that list here, never in run, so nothing is saved and the
## guest's own campaign (st().open / won / long ways / flags) is never touched.
## Campaign.can_visit(scene) = region_open(scene) or a host-opened region while
## visiting; only border walking uses it (Campaign.blocks; TravelNet.why should too).

static var _inst: CampaignFollow = null
static var host_open := {}     # guest: scene -> true, from the host
static var _told := {}         # scene -> true: the visit-only words were said


## Called on every map ready (GameMap hook) and lazily from Campaign.blocks.
static func hook() -> void:
	if _inst == null:
		_inst = CampaignFollow.new()
		Net.on_msg("campaign_open_req", _inst._on_req)
		Net.on_msg("campaign_open", _inst._on_open)
		Net.on_msg("campaign_note", _inst._on_note)
	if not Net.visiting():
		host_open.clear()
		_told.clear()
	elif Net.online():
		Net.send_host("campaign_open_req", {})


## The host's own open regions (scene ids).
static func my_open() -> Array:
	var out := {}
	for cid: String in Campaign.all():
		var reg := str((Campaign.all()[cid] as Dictionary).get("region", ""))
		if reg != "" and (Campaign.is_won(cid) or (Campaign.st().get("open", {}) as Dictionary).has(reg)):
			out[reg] = true
	for reg: String in (Campaign.st().get("open", {}) as Dictionary):
		out[reg] = true
	return out.keys()


func _on_req(from_peer: String, _d: Dictionary) -> void:
	if Net.visiting() or not Net.is_host():
		return
	Net.send_peer(from_peer, "campaign_open", {"regions": CampaignFollow.my_open()})


func _on_open(_from_peer: String, d: Dictionary) -> void:
	if not Net.visiting():
		return
	CampaignFollow.host_open.clear()
	var rv: Variant = d.get("regions", [])
	if rv is Array:
		for r: Variant in rv:
			CampaignFollow.host_open[str(r)] = true


## True when the host opened this region and we're visiting (visit-only pass).
static func host_opened(scene: String) -> bool:
	return Net.visiting() and host_open.has(scene)


## Once per region per visit: say why the border lets you through.
static func tell_once(m: GameMap, scene: String) -> void:
	if _told.has(scene) or m == null or m.hud == null:
		return
	_told[scene] = true
	m.hud.toast("Your host opened this way. You're visiting: your own story still holds it.", Color(0.85, 0.95, 1.0))


# ---- C17 P3 (c17_05-06): the host marches out / comes back: guests get word ----
static var _last_note := -100000
static var last_note_text := ""   # tests


## Host only, while guests are here: "<Host> marched to <field>. Back soon."
static func note_march(field: String) -> void:
	if not Net.online() or Net.visiting() or not Net.is_host():
		return
	var nm := NameFilter.clean(str(GameState.names().get("character", "")), "Your host")
	var where := str(GameState.load_json("res://data/battles.json").get(field, {}).get("title", "the battlefield"))
	_send_note("%s marched to %s." % [nm, where], field)


static func note_back(won: bool) -> void:
	if not Net.online() or Net.visiting() or not Net.is_host():
		return
	var nm := NameFilter.clean(str(GameState.names().get("character", "")), "Your host")
	_send_note("%s %s." % [nm, "won the battle" if won else "fell back from the battle"])


static func _send_note(text: String, field := "") -> void:
	var now := PlayClock.ms()
	if now - _last_note < 4000:
		return
	_last_note = now
	Net.broadcast("campaign_note", {"text": text, "field": field})


func _on_note(_from_peer: String, d: Dictionary) -> void:
	if not Net.visiting():
		return
	CampaignFollow.last_note_text = str(d.get("text", ""))
	var m: Variant = Engine.get_main_loop().current_scene if Engine.get_main_loop() is SceneTree else null
	if m is GameMap and (m as GameMap).hud != null:
		(m as GameMap).hud.toast(CampaignFollow.last_note_text, Color(1, 0.9, 0.7))
		var field := str(d.get("field", ""))
		if field.begins_with("bf_") and ResourceLoader.exists("res://scenes/%s.tscn" % field):
			CampaignFollow.offer_join(m as GameMap, field)


## C17 P3 (c17_05-07, minimum co-op battle): "Join them?" A guest who says yes
## stands on the same field (Battle: no campaign state, own blade drawn, foes on
## their own phone, a small xp share; nothing changes their campaign or story).
static var offered_field := ""   # tests


static func offer_join(m: GameMap, field: String) -> void:
	offered_field = field
	if not is_instance_valid(m) or m.get_tree() == null or m.scene_id() == field:
		return
	var dl := Dialogue.instance(m.get_tree())
	if dl.active or m.get_tree().paused:
		return
	dl.say([{"who": "", "text": "Your host is heading into battle. Go and help?", "choice": ["Join the fight", "Not now"], "key": ""}])
	await dl.finished
	if dl.last_choice == 0 and is_instance_valid(m) and Net.visiting():
		m.go_to(field, Vector2.ZERO, "up")
