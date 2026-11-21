class_name CoopGames
extends RefCounted
## CONDUCT 17 (P4): 2-4 player minigames over the Net message router.
## Turn-based and score-attack only, so phone latency (seconds) never matters:
## every player plays on their own phone and only results travel.
##   duel  - arcade cabinets / Snowball lanes on one shared seed; best score wins.
##   bowl  - bowling versus: frames in lockstep (nobody starts frame k+1 before
##           everyone has finished frame k), one shared scoreboard.
## The room host is the referee: it owns every session, checks each posted
## result (player in the session, posted once, plausible score) and keeps the
## house high-score board (host-only write, names through NameFilter).
## Rewards: each player's tickets/bests come from their own play on their own
## run (ArcadeGame/Bowling already pay locally); a session only ranks players.
## Nothing here spends anything while the host is away (Net.host_present()).
## Router: Net.on_msg / send_host / send_peer / broadcast (contract section 2),
## used only when present; tests drive two or more instances through `wire`.

const TYPES := ["game_open", "game_join", "game_leave", "game_start", "game_turn",
		"game_score", "game_state", "game_result", "game_board", "game_board_ask", "game_post"]
const MAX_PLAYERS := 4
const BOARD_LEN := 8
const BOWL_FRAMES := 10
## A posted score above this is refused (a forged score never reaches a board).
const MAX_SCORE := {"bowling": 300, "skee_ball": 900, "stack": 5000, "whack": 5000,
		"gallery": 5000, "jumper": 5000}
const DUEL_GAMES := ["stack", "whack", "gallery", "skee_ball", "jumper"]

static var _me: CoopGames = null

## Our peer id ("host" for the room host when the router gives no id).
var me := "me"
var host := true
## What the router would do: send.call(to, t, d); to = "" host, "*" everyone, else a peer.
var send: Callable = Callable()
## Host absent (grace / host_away): nothing new starts and nothing is posted.
var host_ok := true
## Session id -> {id, game, kind, seed, owner, state: lobby|play|done, players: [{peer, name}],
##   scores {peer: n}, frames {peer: [frame totals]}}
var sessions := {}
## The house board as last heard from the host (guests); hosts use board_store.
var board_cache := {}
## The host's Rec Center as a guest last heard it ({} = not heard: use our own flags).
## {open: bool, reno: [open phase ids], arc: "penguins"|"gangsters"}; visit-only, never saved.
var rec_view := {}
## Where a host keeps its board (GameState.run["coop_board"] in the game; tests pass their own).
var board_store: Dictionary = {}
var _next := 1
signal changed(sid: String)
signal finished(sid: String, ranking: Array)


## The game's single instance, registered with the router on first use.
static func i() -> CoopGames:
	if _me == null:
		_me = CoopGames.new()
		_me._attach()
	elif not GameState.run.is_empty() and not (GameState.run.get("coop_board") is Dictionary and is_same(GameState.run["coop_board"], _me.board_store)):
		_me.board_store = {}  # another save was loaded: its own house board
		_me._attach_board()
	return _me


## A specific NetNode (tests run two in one process); null = the Net facade (the game).
var node: NetNode = null


## The router as a plain object, so calls compile whichever side lands first.
func _R() -> Object:
	if node != null:
		return node
	var s: Object = Net
	return s


func _router_has(m: String) -> bool:
	if node != null:
		return node.has_method(m)
	var s: Script = Net
	for f in s.get_script_method_list():
		if str(f.get("name", "")) == m:
			return true
	return false


## Tests: referee/play through this NetNode (over NetTransportLoop) instead of NetSvc.
func bind_node(n: NetNode) -> void:
	node = n
	_attach()


func _attach_board() -> void:
	if GameState.run.is_empty():
		board_store = {}
		return
	var r: Variant = GameState.run.get("coop_board")
	if not (r is Dictionary):
		r = {}
		GameState.run["coop_board"] = r
	board_store = r


func _attach() -> void:
	if node == null:
		_attach_board()
	if not _router_has("on_msg"):
		return
	for t in TYPES:
		_R().call("on_msg", t, Callable(self, "_on_router").bind(t))
	send = Callable(self, "_router_send")
	_sync_role()
	var n := node if node != null else Net.i()
	if n != null and n.has_signal("peer_left"):
		n.connect("peer_left", func(p: Variant) -> void: peer_gone(str(p)))
	if n != null and n.has_signal("peer_joined"):
		n.connect("peer_joined", func(p: Variant) -> void: welcome(str(p)))


## Our router id and role (they change as we host, join or go home).
func _sync_role() -> void:
	host = bool(_R().call("is_host"))
	if _router_has("my_peer"):
		me = str(_R().call("my_peer"))
	host_ok = (not _router_has("host_present")) or bool(_R().call("host_present"))


func _on_router(from_peer: Variant, d: Dictionary, t: String) -> void:
	_sync_role()
	handle(str(from_peer), t, d)


func _router_send(to: String, t: String, d: Dictionary) -> void:
	_sync_role()
	if to == "":
		if host:
			handle(me, t, d)  # the host is its own referee
		else:
			_R().call("send_host", t, d)
	elif to == "*":
		_R().call("broadcast", t, d, false)
	else:
		_R().call("send_peer", to, t, d)


## In a co-op session with at least one partner (otherwise menus hide versus rows).
static func available() -> bool:
	return Net.online() and Net.peers.size() > 0


## The player's OWN calendar day: run.day is the host's while visiting, so "once a
## day" counters (villager bowling, claw tightening, casino day) key on this (c17_06-16).
static func own_day() -> int:
	var n := Net.i()
	if n != null and n.visiting():
		return int(n._solo_backup.get("day", GameState.run.get("day", 1)))
	return int(GameState.run.get("day", 1))


static func my_name() -> String:
	return NameFilter.clean(str(GameState.names().get("character", "Player")))


func _out(to: String, t: String, d: Dictionary) -> void:
	if send.is_valid():
		send.call(to, t, d)


# ---- player side ----------------------------------------------------------------

## Open a session for `game` ("bowling" = versus lanes, else a duel cabinet). The host
## answers with game_state; returns false when it can't start right now.
func open(game: String, name := "") -> bool:
	if not host_ok:
		return false
	if game != "bowling" and not (game in DUEL_GAMES):
		return false
	_out("", "game_open", {"game": game, "name": name if name != "" else my_name()})
	return true


func join(sid: String, name := "") -> bool:
	if not host_ok or not sessions.has(sid):
		return false
	_out("", "game_join", {"sid": sid, "name": name if name != "" else my_name()})
	return true


func leave(sid: String) -> void:
	_out("", "game_leave", {"sid": sid})


## Only the session's owner starts it (the lobby closes, the seed is fixed).
func start(sid: String) -> void:
	if host_ok:
		_out("", "game_start", {"sid": sid})


## Bowling: our total after frame `f` (1-based).
func post_frame(sid: String, f: int, total: int) -> void:
	if host_ok:
		_out("", "game_turn", {"sid": sid, "f": f, "total": total})


## Duel (or a finished bowling game): our final score.
func post_score(sid: String, score: int) -> void:
	if host_ok:
		_out("", "game_score", {"sid": sid, "score": score})


## Bowling lockstep: may we bowl frame f (everyone has finished frame f-1)?
func may_bowl(sid: String, f: int) -> bool:
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or str(s.get("state")) != "play":
		return false
	for p in s["players"]:
		if (s["frames"].get(p["peer"], []) as Array).size() < f - 1:
			return false
	return true


## Who we are still waiting on (names), for the "Waiting for ..." card.
func waiting_on(sid: String, f: int) -> Array:
	var out := []
	var s: Dictionary = sessions.get(sid, {})
	for p in s.get("players", []):
		if (s["frames"].get(p["peer"], []) as Array).size() < f - 1:
			out.append(p["name"])
	return out


## A session waiting for players that we could join (newest first).
func open_lobby(game: String) -> String:
	var best := ""
	for sid in sessions:
		var s: Dictionary = sessions[sid]
		if s["game"] == game and s["state"] == "lobby" and s["players"].size() < MAX_PLAYERS:
			best = sid
	return best


## Rows for the scoreboard: [{name, score, frames, me}] in seat order.
func rows(sid: String) -> Array:
	var out := []
	var s: Dictionary = sessions.get(sid, {})
	for p in s.get("players", []):
		out.append({"name": p["name"], "peer": p["peer"], "me": p["peer"] == me,
				"score": int(s["scores"].get(p["peer"], -1)), "frames": s["frames"].get(p["peer"], [])})
	return out


func board(game: String) -> Array:
	var b: Variant = (board_store if host else board_cache).get(game, [])
	return b if b is Array else []


## A new personal best goes on the house board: the host's (while visiting) or our own.
func post_best(game: String, score: int) -> void:
	if GameState.run.is_empty() or score <= 0 or not MAX_SCORE.has(game):
		return
	if host:
		if submit_board(game, my_name(), score):
			_out("*", "game_board", {"board": board_store.duplicate(true)})
	elif host_ok:
		_out("", "game_post", {"game": game, "score": score, "name": my_name()})


## Host: what a guest needs to see the host's Rec Center as it is (c17_06-05).
static func rec_summary() -> Dictionary:
	var f: Dictionary = GameState.run.get("flags", {})
	var reno := []
	for k in f:
		if str(k).begins_with("rec_reno_"):
			reno.append(str(k).trim_prefix("rec_reno_"))
	return {"open": f.has("rec_open"), "reno": reno, "arc": str(GameState.run.get("arc", "penguins"))}


## The host's rec summary while we visit, else {} (callers then use our own flags).
static func host_rec() -> Dictionary:
	if not GameState.visiting() or _me == null:
		return {}
	return _me.rec_view


## The board's #1 for a game: {name, score} or {}.
func top(game: String) -> Dictionary:
	var b := board(game)
	return b[0] if not b.is_empty() and b[0] is Dictionary else {}


func ask_board() -> void:
	if not host:
		_out("", "game_board_ask", {})


# ---- referee (host) and every client --------------------------------------------

func handle(from: String, t: String, d: Dictionary) -> void:
	if host:
		match t:
			"game_open": _ref_open(from, d)
			"game_join": _ref_join(from, d)
			"game_leave": _ref_leave(from, d)
			"game_start": _ref_start(from, d)
			"game_turn": _ref_turn(from, d)
			"game_score": _ref_score(from, d)
			"game_board_ask": _out(from, "game_board", {"board": board_store.duplicate(true), "rec": rec_summary()})
			"game_post":
				if submit_board(str(d.get("game", "")), str(d.get("name", "")), int(d.get("score", 0))):
					_out("*", "game_board", {"board": board_store.duplicate(true)})
		return
	match t:
		"game_state": _apply_state(d)
		"game_result":
			_apply_state(d)
			finished.emit(str(d.get("id", "")), d.get("ranking", []))
		"game_board":
			if d.get("board") is Dictionary:
				board_cache = (d["board"] as Dictionary).duplicate(true)
			if d.get("rec") is Dictionary:
				rec_view = (d["rec"] as Dictionary).duplicate(true)


func _apply_state(d: Dictionary) -> void:
	var sid := str(d.get("id", ""))
	if sid == "":
		return
	if str(d.get("state", "")) == "gone":
		sessions.erase(sid)
	else:
		sessions[sid] = d.duplicate(true)
	changed.emit(sid)


func _push(sid: String) -> void:
	var s: Dictionary = sessions.get(sid, {"id": sid, "state": "gone"})
	_out("*", "game_state", s)
	changed.emit(sid)


func _seat(s: Dictionary, peer: String) -> int:
	for k in s["players"].size():
		if s["players"][k]["peer"] == peer:
			return k
	return -1


func _ref_open(from: String, d: Dictionary) -> void:
	if not host_ok:
		return
	var game := str(d.get("game", ""))
	if game != "bowling" and not (game in DUEL_GAMES):
		return
	for sid in sessions.keys():  # one open session per player
		if _seat(sessions[sid], from) >= 0 and sessions[sid]["state"] != "done":
			_ref_leave(from, {"sid": sid})
	var sid := "%s%d" % [game.left(3), _next]
	_next += 1
	sessions[sid] = {"id": sid, "game": game, "kind": "bowl" if game == "bowling" else "duel",
			"seed": int(hash("%s|%d|%d" % [sid, GameState.now_abs(), _next])) & 0x7fffffff,
			"owner": from, "state": "lobby", "players": [{"peer": from, "name": NameFilter.clean(str(d.get("name", "")))}],
			"scores": {}, "frames": {}}
	_push(sid)


func _ref_join(from: String, d: Dictionary) -> void:
	var sid := str(d.get("sid", ""))
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or s["state"] != "lobby" or not host_ok:
		return
	if _seat(s, from) < 0 and s["players"].size() < MAX_PLAYERS:
		s["players"].append({"peer": from, "name": NameFilter.clean(str(d.get("name", "")))})
	_push(sid)


func _ref_leave(from: String, d: Dictionary) -> void:
	var sid := str(d.get("sid", ""))
	var s: Dictionary = sessions.get(sid, {})
	var k := _seat(s, from) if not s.is_empty() else -1
	if k < 0:
		return
	s["players"].remove_at(k)
	s["scores"].erase(from)
	s["frames"].erase(from)
	if s["players"].is_empty():
		sessions.erase(sid)
		_push(sid)
		return
	if s["owner"] == from:
		s["owner"] = s["players"][0]["peer"]
	_push(sid)
	_maybe_done(sid)


## Host: a partner just joined: send them the house board, the rec as it stands, and open lobbies.
func welcome(peer: String) -> void:
	_sync_role()
	if not host:
		return
	_out(peer, "game_board", {"board": board_store.duplicate(true), "rec": rec_summary()})
	for sid in sessions:
		_out(peer, "game_state", sessions[sid])


## A partner who dropped out of the room leaves every session (the others carry on).
func peer_gone(peer: String) -> void:
	if not host:
		return
	for sid in sessions.keys():
		_ref_leave(peer, {"sid": sid})


func _ref_start(from: String, d: Dictionary) -> void:
	var sid := str(d.get("sid", ""))
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or s["owner"] != from or s["state"] != "lobby" or not host_ok:
		return
	s["state"] = "play"
	_push(sid)


func _ref_turn(from: String, d: Dictionary) -> void:
	var sid := str(d.get("sid", ""))
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or s["kind"] != "bowl" or s["state"] != "play" or _seat(s, from) < 0:
		return
	var fr: Array = s["frames"].get(from, [])
	var f := int(d.get("f", 0))
	var total := int(d.get("total", -1))
	var last := int(fr[-1]) if not fr.is_empty() else 0
	# In order, one at a time, never ahead of the slowest player, totals only grow by <= 30.
	if f != fr.size() + 1 or f > BOWL_FRAMES or not may_bowl(sid, f) or total < last or total - last > 30:
		return
	fr.append(total)
	s["frames"][from] = fr
	if f == BOWL_FRAMES:
		s["scores"][from] = total
	_push(sid)
	_maybe_done(sid)


func _ref_score(from: String, d: Dictionary) -> void:
	var sid := str(d.get("sid", ""))
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or s["state"] != "play" or _seat(s, from) < 0 or s["scores"].has(from):
		return
	if s["kind"] == "bowl":
		return  # bowling scores come only from the frames
	var sc := int(d.get("score", -1))
	if sc < 0 or sc > int(MAX_SCORE.get(s["game"], 5000)):
		return
	s["scores"][from] = sc
	_push(sid)
	_maybe_done(sid)


func _maybe_done(sid: String) -> void:
	var s: Dictionary = sessions.get(sid, {})
	if s.is_empty() or s["state"] != "play":
		return
	for p in s["players"]:
		if not s["scores"].has(p["peer"]):
			return
	s["state"] = "done"
	var ranking := ranking_of(s)
	for r in ranking:
		submit_board(s["game"], str(r["name"]), int(r["score"]))
	var out := s.duplicate(true)
	out["ranking"] = ranking
	_out("*", "game_result", out)
	_out("*", "game_board", {"board": board_store.duplicate(true)})
	changed.emit(sid)
	finished.emit(sid, ranking)


## Best first; ties share a place ("1st, 1st, 3rd").
static func ranking_of(s: Dictionary) -> Array:
	var out := []
	for p in s["players"]:
		out.append({"peer": p["peer"], "name": p["name"], "score": int(s["scores"].get(p["peer"], 0))})
	out.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and str(a["name"]) < str(b["name"])))
	for k in out.size():
		out[k]["place"] = 1 if k == 0 else (out[k - 1]["place"] if out[k]["score"] == out[k - 1]["score"] else k + 1)
	return out


## Host only: one row on the house board (filtered name, plausible score, best N kept).
func submit_board(game: String, name: String, score: int) -> bool:
	if not host or score <= 0 or score > int(MAX_SCORE.get(game, 5000)):
		return false
	var b: Array = board_store.get(game, [])
	b.append({"name": NameFilter.clean(name), "score": score, "day": int(GameState.run.get("day", 1))})
	b.sort_custom(func(x, y): return int(x["score"]) > int(y["score"]))
	if b.size() > BOARD_LEN:
		b.resize(BOARD_LEN)
	board_store[game] = b
	for r in b:
		if r["name"] == NameFilter.clean(name) and int(r["score"]) == score:
			return true
	return false


static func place_word(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


## One line per player for result cards: "1st  Pip  212".
static func result_lines(ranking: Array) -> Array:
	var out := []
	for r in ranking:
		out.append("%s  %s  %d" % [place_word(int(r["place"])), r["name"], int(r["score"])])
	return out


## Tests: connect instances as a star around the host (index 0) with a synchronous
## in-memory relay; every message is delivered in order before the call returns.
static func wire(list: Array) -> void:
	var hub: CoopGames = list[0]
	for k in list.size():
		var c: CoopGames = list[k]
		c.host = k == 0
		c.me = "p%d" % k
		c.send = func(to: String, t: String, d: Dictionary) -> void:
			var dd := d.duplicate(true)
			if to == "":
				hub.handle(c.me, t, dd)
			elif to == "*":
				for o in list:
					if o != hub:
						o.handle(hub.me, t, dd.duplicate(true))
			else:
				for o in list:
					if o.me == to:
						o.handle(c.me, t, dd)
