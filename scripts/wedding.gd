class_name Wedding
## The wedding day (CONDUCT 7 P1). Romance.engage sets run.romance.wedding_day
## (3 days on, never a festival or a Sunday). On that morning, after the sleep report,
## house.gd calls Wedding.check_morning: the town gathers (penguins: the chapel;
## gangsters: the plaza bandstand, since the chapel lot is Marlene's post), Mayor Alder
## officiates, vows (kept on skip), one answer (both say yes), petals, the wedding
## song, then home at 4pm married. Sleeping through it moves it to the next morning.

const GUESTS_MAX := 6


static func guests(id: String) -> Array:
	var out: Array = []
	for g: String in GameState.npcs:
		if g == id or g == "alder" or Npc.is_kid(g) or GameState.run["flags"].has(g + "_gone"):
			continue
		if GameState.friend_hearts(g) >= 4:
			out.append(Romance.name_of(g))
		if out.size() >= GUESTS_MAX:
			break
	return out


## house.gd: after the morning report (and on arriving home in the morning).
static func check_morning(m: GameMap) -> void:
	if not Romance.wedding_due() or GameState.visiting():
		return
	if int(GameState.run["time"]) / 60 >= 12:
		# Woke past noon (passed out): the town moves it to tomorrow, never lost.
		Romance.st()["wedding_day"] = int(GameState.run["day"]) + 1
		m.hud.toast("The wedding moved to tomorrow morning. Get some rest!", Color(1, 0.8, 0.9))
		return
	await play(m)


static func play(m: GameMap) -> void:
	var s := Romance.st()
	var id := str(s["engaged"])
	if id == "":
		return
	var nm := Romance.name_of(id)
	var you := str(GameState.names().get("character", "friend"))
	var arc := "penguins" if GameState.is_penguins() else "gangsters"
	var v: Dictionary = (Romance.data().get("venues", {}) as Dictionary).get(arc, {})
	if not Romance.skip_scenes:
		m.player.frozen = true
		var mu := Music.instance(m.get_tree())
		mu.sfx("town_bell", "j_heart")
		var song := "wedding_gang" if arc == "gangsters" and Music.has_track("wedding_gang") else "wedding"
		if Music.has_track(song):
			mu.play_held(song)
		await m.hud.fade_out(0.6)
		await m.hud.fade_in(0.6)
		var gl := guests(id)
		var pic := str(v.get("pic", ""))
		var lines: Array = []
		var first: Dictionary = {"text": "Your wedding day. Everyone is gathering at %s." % str(v.get("place", "the chapel"))}
		if Art.has("ui", pic):
			first["pic"] = pic
		lines.append(first)
		for t in Romance.data().get("shared", {}).get("wedding_intro", []):
			lines.append({"text": str(t)})
		if not gl.is_empty():
			lines.append({"text": "%s %s there, all smiles." % [", ".join(gl.slice(0, gl.size() - 1)) + (" and " if gl.size() > 1 else "") + str(gl[gl.size() - 1]), "is" if gl.size() == 1 else "are"]})
		lines.append({"who": "Mayor Alder", "text": "Friends! We're here to celebrate %s and %s, two people this valley is very lucky to have." % [you, nm]})
		lines.append({"who": nm, "text": str(Romance.cand(id).get("vows", "I promise to love you every day.")), "mood": "love", "keep": true})
		Dialogue.instance(m.get_tree()).begin_skippable(m)
		await m.say(Romance._lines(lines, id))
		Dialogue.instance(m.get_tree()).end_skippable()
		var dl := Dialogue.instance(m.get_tree())
		dl.say([{"who": "Mayor Alder", "text": "And you, %s?" % you, "choice": ["I do!", "With all my heart."], "key": "wedding"}])
		await dl.finished
		await m.say(Romance._lines([
			{"who": "Mayor Alder", "text": "Then by the power of this very happy town, you're married! You may hug your partner!"},
			{"text": "You and %s hold hands as petals drift down. Someone starts clapping, and then everyone is." % nm, "keep": true},
		] + _shared_end(), id))
		Music.instance(m.get_tree()).sfx("j_wedding", "j_heart")
	Romance.marry()
	GameState.add_friend(id, 25)
	GameState.run["time"] = maxi(int(GameState.run["time"]), 16 * 60)
	if not Romance.skip_scenes:
		m.hud.toast("Married to %s ♥" % nm, Color(1, 0.75, 0.9))
		Music.instance(m.get_tree()).release_hold()
		Music.instance(m.get_tree()).play(m.area_track())
		m.player.frozen = false
		if m.has_method("spouse_refresh"):
			m.spouse_refresh()


static func _shared_end() -> Array:
	var out: Array = []
	for t in Romance.data().get("shared", {}).get("wedding_end", []):
		out.append({"text": str(t)})
	return out
