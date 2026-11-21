extends SceneTree
## C17 P4: 2-4 player minigames (CoopGames) over an in-memory star relay, plus the
## co-op reward/day guards in the rec, casino, animal show, festival and laundromat.
## Run: godot --headless --fixed-fps 60 --path . -s res://tools/coop_games_test.gd
var fails := 0
const AnimalShowLib := preload("res://scripts/animal_show.gd")


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(17)
	_run.call_deferred()


func _run() -> void:
	GameState.new_run("penguins", "kairi", "Host", "Dreamhollow", "Biscuit")
	GameState.run["intro_done"] = true
	_duel()
	_bowl()
	_leave_and_away()
	await _bowling_screen()
	await _over_loop()
	_visit_guards()
	_laundromat()
	print("coop_games_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)


func _trio() -> Array:
	var l := [CoopGames.new(), CoopGames.new(), CoopGames.new(), CoopGames.new()]
	CoopGames.wire(l)
	return l


func _duel() -> void:
	var l := _trio()
	var h: CoopGames = l[0]
	var a: CoopGames = l[1]
	var b: CoopGames = l[2]
	ok(a.open("stack", "Nova"), "guest opens a duel")
	var sid := b.open_lobby("stack")
	ok(sid != "" and h.sessions.has(sid), "the lobby reaches every player and the host")
	ok(b.join(sid, "Pip") and h.join(sid, "Hosty"), "two more join")
	ok((l[3] as CoopGames).join(sid, "Fourth"), "a fourth joins")
	ok(not CoopGames.new().join("nope"), "unknown session can't be joined")
	ok(h.sessions[sid]["players"].size() == 4, "4 players seated")
	b.start(sid)
	ok(h.sessions[sid]["state"] == "lobby", "only the opener starts")
	a.start(sid)
	ok(a.sessions[sid]["state"] == "play" and b.sessions[sid]["state"] == "play", "started for everyone")
	ok(a.sessions[sid]["seed"] == b.sessions[sid]["seed"] and b.sessions[sid]["seed"] == h.sessions[sid]["seed"], "one shared seed")
	b.post_score(sid, 99999)
	ok(not h.sessions[sid]["scores"].has("p2"), "a forged score is refused")
	a.post_score(sid, 300)
	a.post_score(sid, 500)
	ok(int(h.sessions[sid]["scores"]["p1"]) == 300, "a score posts once")
	b.post_score(sid, 300)
	h.post_score(sid, 120)
	ok(h.sessions[sid]["state"] == "play", "still waiting on the 4th")
	var got := []
	a.finished.connect(func(_s: String, r: Array) -> void: got.append(r))
	(l[3] as CoopGames).post_score(sid, 50)
	ok(h.sessions[sid]["state"] == "done", "done when all posted")
	ok(got.size() == 1, "guests get the result")
	var r: Array = got[0] if got.size() > 0 else []
	ok(r.size() == 4 and int(r[0]["place"]) == 1 and int(r[1]["place"]) == 1 and int(r[2]["place"]) == 3, "ties share a place")
	ok(CoopGames.result_lines(r)[0].begins_with("1st"), "result lines")
	ok(h.board("stack").size() == 4 and int(h.board("stack")[0]["score"]) == 300, "the host keeps the house board")
	ok(a.board("stack").size() == 4, "guests see the host's board")
	ok(not a.submit_board("stack", "Cheat", 10), "guests can't write the board")
	ok(not h.submit_board("stack", "X", 999999), "implausible board scores refused")
	for i in 12:
		h.submit_board("stack", "R%d" % i, 10 + i)
	ok(h.board("stack").size() == CoopGames.BOARD_LEN, "board keeps the best %d" % CoopGames.BOARD_LEN)
	ok(not h.open("claw"), "claw stays solo")
	var f := CoopGames.new()
	f._sync_role()  # through the static Net facade (the game's path)
	ok(f.host and f.me != "" and f.host_ok, "facade: solo is host, has an id, host present")
	ok(not CoopGames.available(), "offline: no versus rows")


func _bowl() -> void:
	var l := _trio()
	var h: CoopGames = l[0]
	var a: CoopGames = l[1]
	h.open("bowling", "Hosty")
	var sid := a.open_lobby("bowling")
	a.join(sid, "Nova")
	h.start(sid)
	ok(a.sessions[sid]["state"] == "play", "bowling started")
	ok(a.may_bowl(sid, 1) and h.may_bowl(sid, 1), "frame 1 open to all")
	a.post_frame(sid, 1, 9)
	ok(not a.may_bowl(sid, 2), "lockstep: wait for the host's frame 1")
	ok(a.waiting_on(sid, 2) == ["Hosty"], "waiting on names")
	a.post_frame(sid, 2, 18)
	ok((h.sessions[sid]["frames"]["p1"] as Array).size() == 1, "can't bowl ahead of the slowest")
	h.post_frame(sid, 1, 31)
	ok(not h.sessions[sid]["frames"].has("p0"), "more than 30 a frame refused")
	h.post_frame(sid, 3, 10)
	ok(not h.sessions[sid]["frames"].has("p0"), "frames in order only")
	h.post_frame(sid, 1, 20)
	ok(a.may_bowl(sid, 2), "next frame opens")
	for f in range(2, 11):
		a.post_frame(sid, f, 9 * f)
		h.post_frame(sid, f, 20 * f)
	a.post_score(sid, 300)
	ok(h.sessions[sid]["state"] == "done", "bowling done after frame 10")
	var rk := CoopGames.ranking_of(h.sessions[sid])
	ok(rk[0]["name"] == "Hosty" and int(rk[0]["score"]) == 200 and int(rk[1]["score"]) == 90, "bowling ranking from frames, not a posted score")
	ok(int(h.board("bowling")[0]["score"]) == 200, "bowling house record")


func _leave_and_away() -> void:
	var l := _trio()
	var h: CoopGames = l[0]
	var a: CoopGames = l[1]
	var b: CoopGames = l[2]
	a.open("whack", "A")
	var sid := b.open_lobby("whack")
	b.join(sid, "B")
	a.start(sid)
	b.post_score(sid, 40)
	h.peer_gone("p1")
	ok(b.sessions[sid]["state"] == "done", "a partner dropping out lets the rest finish")
	a.open("gallery", "A")
	var s2 := b.open_lobby("gallery")
	a.leave(s2)
	ok(not h.sessions.has(s2) and not b.sessions.has(s2), "an empty lobby closes everywhere")
	a.host_ok = false
	ok(not a.open("gallery"), "nothing opens while the host is away")
	h.host_ok = false
	b.host_ok = true
	b.open("gallery", "B")
	ok(b.open_lobby("gallery") == "", "the host refuses while away")


func _bowling_screen() -> void:
	var l := _trio()
	var h: CoopGames = l[0]
	var a: CoopGames = l[1]
	h.open("bowling", "Hosty")
	var sid := a.open_lobby("bowling")
	a.join(sid, "Nova")
	h.start(sid)
	var g := Bowling.new()
	g.coop = a
	g.coop_sid = sid
	g.manual = true
	root.add_child(g)
	await process_frame
	ok(g._sheet_rect().size.y == 73.0, "sheet grows by a partner line")
	g.rolls = [3, 4]
	a.post_frame(sid, 1, 7)
	g._new_ball()
	ok(g.phase == "wait", "waits for a partner before frame 2")
	ok(g.wait_text() == "Waiting for Hosty", "wait card names them")
	h.post_frame(sid, 1, 12)
	g.tick(1.0 / 60.0)
	for i in 10:
		g.tick(1.0 / 60.0)
	ok(g.phase == "line", "frame 2 opens when they finish")
	g.queue_free()
	paused = false
	Hud.modal_rect = Rect2()
	await process_frame


func _pump(n: int) -> void:
	for i in n:
		await process_frame


## The same duel through the real router (P1) over NetTransportLoop: host + guest NetNodes.
func _over_loop() -> void:
	var bus := NetTransportLoop.Bus.new()
	var hn := NetNode.new()
	root.add_child(hn)
	hn._host = true
	hn._pending_join = {"t": "join", "room": "", "token": "cgh", "name": "H", "look": {}, "arc": "penguins", "proto": NetNode.PROTO}
	hn.tr = NetTransportLoop.new(bus)
	hn.tr.open("", hn._pending_join)
	await _pump(3)
	var gn := NetNode.new()
	root.add_child(gn)
	gn._host = false
	gn._pending_join = {"t": "join", "room": hn.room, "create": false, "token": "cgg", "name": "G", "look": {}, "arc": "gangsters", "proto": NetNode.PROTO}
	gn.tr = NetTransportLoop.new(bus)
	gn.tr.open("", gn._pending_join)
	await _pump(4)
	ok(hn.online() and gn.online() and not gn.is_host(), "loop: host and guest online")
	var hc := CoopGames.new()
	hc.board_store = {}
	hc.bind_node(hn)
	var gc := CoopGames.new()
	gc.bind_node(gn)
	ok(hc.host and not gc.host and gc.me == str(gn.my_id), "loop: roles and peer ids from the router")
	gc.open("gallery", "Guesty")
	await _pump(4)
	var sid := hc.open_lobby("gallery")
	ok(sid != "" and gc.sessions.has(sid), "loop: the guest's lobby is refereed by the host and echoed back")
	hc.join(sid, "Hosty")
	await _pump(4)
	ok(gc.sessions.get(sid, {}).get("players", []).size() == 2, "loop: the host joined (guest sees 2)")
	gc.start(sid)
	await _pump(4)
	ok(str(hc.sessions[sid]["state"]) == "play" and str(gc.sessions[sid]["state"]) == "play", "loop: started on both")
	var got := []
	gc.finished.connect(func(_s: String, r: Array) -> void: got.append(r))
	gc.post_score(sid, 210)
	hc.post_score(sid, 180)
	await _pump(4)
	ok(got.size() == 1 and str(got[0][0]["name"]) == "Guesty", "loop: the guest gets the result, guest won")
	ok(gc.board("gallery").size() == 2, "loop: the house board reached the guest")
	hn.leave()
	gn.leave()
	hn.queue_free()
	gn.queue_free()
	await _pump(2)


func _visit_guards() -> void:
	GameState.run["day"] = 60
	var net := root.get_node_or_null("NetSvc") as NetNode
	var made := net == null
	if made:
		net = NetNode.new()
		net.name = "NetSvc"
		root.add_child(net)
	Net._node = null
	net._host = false
	net._solo_backup = {"day": 10}
	ok(GameState.visiting() and CoopGames.own_day() == 10, "own day while visiting")
	ok(RecCenter.bowl_friend("juniper", true) == 8, "first villager game pays")
	GameState.run["day"] = 61
	ok(RecCenter.bowl_friend("juniper", true) == 0, "a host's new day doesn't pay again (own day)")
	ok(AnimalShowLib.animal_entries().is_empty(), "no host animals at the show for a guest")
	ok(AnimalShowLib.done_key("spring", "c1").begins_with("visit_"), "festival keys namespaced while visiting")
	ok(RecReno.cup().is_empty(), "no Rec Cup on the host's season")
	GameState.run.erase("casino")
	ok(Casino.own_day() == 10, "first casino use while visiting takes our own day")
	Casino.take_break()
	ok(int(GameState.run["casino"]["break_until"]) == 10 + int(Casino.lim("break_days")), "break counted on our calendar")
	GameState.run["casino"]["break_until"] = 67
	Casino.why_shut()
	ok(int(GameState.run["casino"]["break_until"]) <= 10 + int(Casino.lim("break_days")), "an old host-calendar break is repaired")
	net._solo_backup = {}
	if made:
		net.queue_free()
	Net._node = null


func _laundromat() -> void:
	GameState.new_run("gangsters", "dad", "Guest", "Dreamhollow", "Biscuit")
	GameState.run["wash"] = {"bills_crude": 2}
	var before := GameState.count("bills_crude")
	var rep := {}
	Racket.overnight(rep)
	ok(GameState.count("bills_crude") == before + 2 and int(rep.get("wash_back", 0)) == 2, "no laundromat of our own: bills come back, never lost")
