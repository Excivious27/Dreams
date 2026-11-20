class_name DangerMusic
extends RefCounted
## Combat music for the whole game. GameMap._process calls `tick(map, delta)`
## every frame; four times a second it looks at the map's enemies (read-only)
## and decides how much danger the player is in:
##   0 calm    - the area song (GameMap.area_track)
##   1 light   - a skirmish: one or two small foes after you
##   2 danger  - a real fight: a pack, a foe above your tier, or you're low on health
##   3 elite   - a mine guardian, a big foe or one far above your tier
##   4 boss    - any boss (bossy kinds, Gift fights, named bosses); its own theme
## A foe counts while it is fighting you or chasing you (noticed you and still
## close, hit you or was hit lately, on a collector run), so running away with
## foes on your heels keeps the music up. Music climbs a tier at once, drops a
## tier only after DROP_HOLD seconds lower, and fades back to the area song
## GRACE seconds after the last threat (BOSS_GRACE after a boss), so it never
## flaps as a foe wanders in and out of range. Every track goes through
## Music.has_track (packed or streamed on the web build): a streamed combat
## song not yet downloaded lets the current song carry on until it arrives.
## Tracks that play once (endings, credits, the lullaby) are never interrupted.

const CHECK := 0.25
const ENTER := 0.25        # a threat must last this long (one more check) before the music turns
const GRACE := 5.0
const BOSS_GRACE := 7.0
const DROP_HOLD := 4.0
const AREA_EVERY := 3.0    # calm: re-ask the area song this often (night, rain, festival...)
const FADE_IN := 0.6
const FADE_OUT := 2.2
const CHASE_R := 150.0     # a noticed foe this close is still after you
const BOSS_R := 260.0      # a boss this close holds the boss music even before it notices you

## Tracks by tier and arc (first that exists wins). Tier 4 is picked per boss.
const TRACKS := {
	1: {"penguins": ["combat_light", "danger"], "gangsters": ["combat_light_gang", "raid", "danger"]},
	2: {"penguins": ["danger", "battle"], "gangsters": ["raid", "danger"]},
	3: {"penguins": ["combat_elite", "battle", "danger"], "gangsters": ["combat_elite_gang", "boss_gang", "raid"]},
}
## Per-boss themes where a boss has its own song.
const PER_BOSS := {"finargle_elder": "finargle"}
## Maps whose fights have their own music (battlefields pick battle moods; the
## arcade and other full-screen games pause the tree and are left alone).
const OWN_MUSIC := ["bf_"]

static var _map_id := 0
static var _t := 0.0
static var _area_t := 0.0
static var tier := 0                 # tier now playing (0 calm)
static var track := ""               # combat track now asked for ("" calm)
static var _want := 0                # tier seen at the last check
static var _want_t := 0.0            # how long _want has held
static var _calm_t := 0.0            # seconds since the last threat
static var _low_t := 0.0             # seconds the threat has sat below the playing tier
static var last := {}                # last assessment (tests, debugging)
static var _boss_wr: WeakRef = null  # the boss holding tier 4 (boss_ended when it falls)
static var _sting_t := -1.0          # >0: seconds until the victory sting after a boss
const BOSS_WIND := 2.0               # a fallen boss's song winds down this long, then the sting
const STING := "j_victory"
## Tests: skip the ENTER delay.
static var instant := false


static func reset() -> void:
	_t = 0.0
	_area_t = 0.0
	tier = 0
	track = ""
	_want = 0
	_want_t = 0.0
	_calm_t = 0.0
	_low_t = 0.0
	last = {}
	_boss_wr = null
	_sting_t = -1.0


static func tick(m: GameMap, delta: float) -> void:
	if m.get_instance_id() != _map_id:
		_map_id = m.get_instance_id()
		reset()
		_area_t = AREA_EVERY  # the map's _ready already started its song
	if m.get_tree().paused:
		return
	if _sting_t > 0.0:
		_sting_t -= delta
		if _sting_t <= 0.0:
			Music.instance(m.get_tree()).sfx(STING, "j_battle_won")
	if tier == 4 and _boss_wr != null:
		var bo: Variant = _boss_wr.get_ref()
		if bo == null or not is_instance_valid(bo) or not (bo as Enemy)._alive:
			boss_ended(m)
	_t -= delta
	_area_t -= delta
	if _t > 0.0:
		return
	var step := CHECK - _t if _t > -1.0 else CHECK
	_t = CHECK
	var mu := Music.instance(m.get_tree())
	if mu._current in Music.ONCE:
		return  # an ending or a lullaby plays out
	if tier == 4 and own_music(m):
		return  # a battlefield commander (Battle started the song; Battle ends it)
	var a := assess(m)
	last = a
	var w := int(a["tier"])
	if w == _want:
		_want_t += step
	else:
		_want = w
		_want_t = step if instant else 0.0
	if w > 0:
		_calm_t = 0.0
	else:
		_calm_t += step
	var nt := tier
	var ntrack := track
	if w > tier and (_want_t >= ENTER or instant or tier > 0):
		nt = w  # climb at once (a first threat waits one check so a passing foe doesn't trip it)
		ntrack = str(a["track"])
		_low_t = 0.0
	elif w > 0 and w < tier:
		_low_t += step
		if _low_t >= DROP_HOLD:
			nt = w
			ntrack = str(a["track"])
			_low_t = 0.0
	elif w == tier and w > 0:
		_low_t = 0.0
		if str(a["track"]) != track and w == 4:
			ntrack = str(a["track"])  # a different boss stepped in
	elif w == 0 and tier > 0:
		if _calm_t >= (BOSS_GRACE if tier == 4 else GRACE):
			nt = 0
			ntrack = ""
	if nt != tier or ntrack != track:
		tier = nt
		track = ntrack
		if tier > 0:
			mu.play(track, FADE_IN)
		else:
			mu.play(m.area_track(), FADE_OUT)
			_area_t = AREA_EVERY
		return
	if tier == 0 and _area_t <= 0.0:
		_area_t = AREA_EVERY
		mu.play(m.area_track())
	elif tier > 0 and mu._current != track and not (mu._current in GameMap.BOSS_TRACKS and tier == 4):
		mu.play(track, FADE_IN)  # something else changed the song mid-fight: take it back


## How dangerous things are right now: {tier, track, foes, boss, score}.
static func assess(m: GameMap) -> Dictionary:
	var out := {"tier": 0, "track": "", "foes": 0, "boss": "", "score": 0.0}
	if m.player == null or not is_instance_valid(m.player):
		return out
	var sid := m.scene_id()
	for p: String in OWN_MUSIC:
		if sid.begins_with(p):
			return out
	var pp: Vector2 = m.player.position
	var pt := GameState.progress_tier()
	var best := 0
	var score := 0.0
	var boss: Enemy = null
	var boss_d := INF
	for e in m.enemies:
		if not is_instance_valid(e) or not (e is Enemy):
			continue
		var en := e as Enemy
		if not en._alive or en.has_meta("decoy") or en.has_meta("ally"):
			continue
		var d := en.position.distance_to(pp)
		var engaged := is_engaged(en, m.player, d)
		if is_boss(en):
			if (engaged or d < BOSS_R) and d < boss_d:
				boss = en
				boss_d = d
			continue
		if not engaged:
			continue
		out["foes"] = int(out["foes"]) + 1
		var sev := severity(en, pt)
		best = maxi(best, sev)
		score += 1.0 if sev == 1 else 2.0
	if boss != null:
		out["tier"] = 4
		out["boss"] = boss.kind
		out["track"] = boss_track_for(m, boss)
		_boss_wr = weakref(boss)
		return out
	if best > 0 and best < 2:
		var hp_frac := float(GameState.run.get("hp", 100)) / maxf(1.0, float(GameState.run.get("max_hp", 100)))
		if score >= 4.0 or hp_frac < 0.35:
			best = 2
	out["score"] = score
	out["tier"] = best
	if best > 0:
		out["track"] = tier_track(best)
	return out


static func own_music(m: GameMap) -> bool:
	var sid := m.scene_id()
	for p: String in OWN_MUSIC:
		if sid.begins_with(p):
			return true
	return false


## Fighting you or after you (read-only look at Enemy's own state).
static func is_engaged(e: Enemy, player: Node2D, d: float) -> bool:
	if e._aggro == player and e._aggro_t > 0.0 and d < BOSS_R:
		return true  # you hit it a moment ago
	if e._since_hit < 3.0 and e.hp < e.max_hp and d < 220.0:
		return true  # hurt lately and close
	if e.has_meta("collector") and d < 220.0:
		return true
	if e._noticed:
		var r := CHASE_R if (e._chase_t > 0.0 or not e._los_ok) else 100.0
		if d < r:
			return true
	return false


static func is_boss(e: Enemy) -> bool:
	return e.bossy or e._gift != null or e.has_meta("boss_name")


## 1 light, 2 danger, 3 elite for one ordinary foe.
static func severity(e: Enemy, pt: int) -> int:
	if e.is_guardian or e.has_meta("elite") or e.base_hp >= 36 or e.tier >= pt + 2:
		return 3
	if e.base_hp >= 18 or e.tier > pt or e._enraged:
		return 2
	return 1


static func tier_track(t: int) -> String:
	var arc := "penguins" if GameState.is_penguins() else "gangsters"
	for c: String in TRACKS[t][arc]:
		if Music.has_track(c):
			return c
	return "danger" if Music.has_track("danger") else "battle"


## A boss's song: the one already chosen for it (story/region code may pick a
## special one), its own theme, or GameMap.boss_track by kind.
static func boss_track_for(m: GameMap, e: Enemy) -> String:
	if e.has_meta("dm_track"):
		return str(e.get_meta("dm_track"))
	var cur := Music.instance(m.get_tree())._current
	var t := ""
	if PER_BOSS.has(e.kind) and Music.has_track(str(PER_BOSS[e.kind])):
		t = str(PER_BOSS[e.kind])
	elif cur in GameMap.BOSS_TRACKS:
		t = cur  # boss_card / a story beat already started this fight's song
	else:
		t = m.boss_track(e.kind)
	e.set_meta("dm_track", t)
	return t


## Boss intro hook: the fight's song is playing now; hold it from this moment.
static func boss_started(m: GameMap, t: String) -> void:
	if m.get_instance_id() != _map_id:
		_map_id = m.get_instance_id()
		reset()
	tier = 4
	track = t
	_want = 4
	_want_t = 0.0
	_calm_t = 0.0
	_low_t = 0.0


## The boss holding the boss music fell: no BOSS_GRACE linger. The song winds
## down over BOSS_WIND seconds into the area song (unless the map already
## changed the song itself, e.g. a story beat), then a victory sting plays.
## Called by tick when the boss it tracks dies, and by Battle for field commanders.
static func boss_ended(m: GameMap, play_area := true, sting := true) -> void:
	if m.get_instance_id() != _map_id:
		_map_id = m.get_instance_id()
		reset()
	var mu := Music.instance(m.get_tree())
	var was := track
	tier = 0
	track = ""
	_want = 0
	_want_t = 0.0
	_calm_t = 0.0
	_low_t = 0.0
	_boss_wr = null
	_area_t = AREA_EVERY
	_sting_t = BOSS_WIND if sting else -1.0
	if play_area and (mu.wanted() == was or mu.wanted() in GameMap.BOSS_TRACKS or was == ""):
		mu.play(m.area_track(), BOSS_WIND)


## Seconds until the post-boss sting (-1: none queued). Tests.
static func sting_in() -> float:
	return _sting_t
