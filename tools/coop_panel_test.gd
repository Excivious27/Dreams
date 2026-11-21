extends SceneTree
## C17 P5: co-op session UI rules, headless and deterministic. Room code checks (an empty or short
## Join never connects), friendly connect errors, player list offline, host permissions, emotes
## and phrases (preset only, unknown ids/indices ignored, 1 per second), the online switch, the
## custom-server rule (wss:// only) and router callables.
## Run: godot --headless --path . --fixed-fps 60 -s res://tools/coop_panel_test.gd

var fails := 0


func _ok(c: bool, what: String) -> void:
	if not c:
		print("FAIL: " + what)
		fails += 1


func _initialize() -> void:
	seed(17)
	_ok(CoopPanel.code_problem("") != "", "empty code refused")
	_ok(CoopPanel.code_problem("AB") != "", "short code refused")
	_ok(CoopPanel.code_problem("abcd") == "", "4-letter code ok")
	_ok(CoopPanel.clean_code("ab-c d1x9z") == "ABCD1X", "code cleaned and capped at 6: %s" % CoopPanel.clean_code("ab-c d1x9z"))
	var fe := CoopPanel.friendly_error("connection closed (1006)")
	_ok(not fe.contains("1006") and not fe.contains("wss"), "raw close code hidden: " + fe)
	fe = CoopPanel.friendly_error("Couldn't reach wss://example.org")
	_ok(not fe.contains("wss://"), "raw address hidden: " + fe)
	_ok(CoopPanel.friendly_error("No game with that code. Check the code with your host.").contains("O, 0, I or 1"), "look-alike letters explained")
	_ok(CoopPanel.players().size() == 1 and bool(CoopPanel.players()[0]["me"]), "offline: only me")
	_ok(CoopPanel.row_text() == "Play together ›", "offline row text")
	# Host permissions: defaults (farm yes, chests yes, build no), then a change.
	_ok(CoopPanel.allowed("7", "farm") and CoopPanel.allowed("7", "chests") and not CoopPanel.allowed("7", "build"), "permission defaults")
	CoopPanel.set_perm("7", "farm", false)
	_ok(not CoopPanel.allowed("7", "farm") and not CoopPanel.allowed(7, "farm"), "permission change (int or String peer)")
	CoopPanel.kick("7")
	_ok(CoopPanel.allowed("7", "farm"), "kick forgets the guest's rules")
	_ok(CoopPanel.place("bf_ridge") == "in a fight" and CoopPanel.place("") == "on the way", "place words")
	_ok(CoopPanel.link_word(80) == "good link" and CoopPanel.link_word(400) == "slow link" and CoopPanel.link_word(-1) == "", "link words")
	# Router callables resolve (offline: we're the host, so a kick/perm from anyone is ignored).
	Callable(CoopPanel, "_on_kick").call("3", {})
	Callable(CoopPanel, "_on_perm").call("3", {"perms": {"farm": false}})
	_ok(CoopPanel.my_perms.is_empty(), "host ignores perm messages")
	# Emotes: preset only.
	Emotes.log.clear()
	Callable(Emotes, "receive").call("5", {"e": "skull"})
	Callable(Emotes, "receive").call("5", {"p": 99})
	Callable(Emotes, "receive").call("5", {"text": "free text"})
	_ok(Emotes.log.is_empty(), "unknown emote / phrase / free text ignored: %s" % [Emotes.log])
	Emotes.receive("5", {"e": "heart"})
	Emotes.receive("5", {"p": 1})
	Emotes.receive("5", {"scene": "farm", "cell": [3, 4]})
	_ok(Emotes.log.size() == 3 and Emotes.log[2]["cell"] == Vector2i(3, 4), "emote, phrase and ping received: %s" % [Emotes.log])
	_ok("skull" not in Emotes.EMOTES, "no skull in the all-ages wheel")
	_ok(Emotes.send_phrase(0), "first phrase goes")
	_ok(not Emotes.send_phrase(1), "second phrase within 1 s is held")
	_ok(not Emotes.send_emote("skull"), "non-wheel emote refused")
	# The online switch hides emotes too.
	Settings.set_v("online_emotes", false)
	Emotes.log.clear()
	Emotes.receive("5", {"e": "heart"})
	_ok(Emotes.log.is_empty(), "emotes hidden when switched off")
	Settings.set_v("online_emotes", true)
	Settings.set_online_ok(false)
	_ok(not Settings.online_ok(), "online play switch off")
	Settings.set_online_ok(true)
	# Custom servers: wss:// only (plain ws:// just for this machine).
	var T: Script = load("res://scripts/title.gd")
	_ok(T.url_ok("wss://x.example") and T.url_ok("") and T.url_ok("ws://localhost:8787"), "wss and local ok")
	_ok(not T.url_ok("ws://stranger.example") and not T.url_ok("http://x"), "plain ws:// refused")
	print("COOP PANEL DONE, failures: %d" % fails)
	quit(1 if fails > 0 else 0)
