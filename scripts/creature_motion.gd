extends RefCounted
class_name CreatureMotion
## C14b P6: shared idle-life helpers for creatures, animals, foes and battle units.
## Cheap code motion (no new nodes): per-instance phase so nobody moves in lockstep,
## held-frame idles (rest pose held, the blink/flick frame short), a feet-anchored
## breath, hover for floaters. Game time only (PlayClock), reduced motion respected.
## Time and reduced motion come from P1's Anim API (Anim.t / Anim.reduced).

static var _tuned := {}   # "sf_id|recipe" -> SpriteFrames copy (Art.frames' cache is never mutated)


## Stable 0..1 phase for a node (instance id hash), so two neighbours never match.
static func phase(n: Object) -> float:
	var h := hash(n.get_instance_id() if n else 0)
	return float(h % 10007) / 10007.0


## A small seeded RNG per node: deterministic in tests (seed() in _initialize feeds randi()).
static func rng_for(n: Object) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(n.get_instance_id() if n else 0) + ":" + str(randi()))
	return r


static func reduced() -> bool:
	return Anim.reduced()


static func t() -> float:
	return Anim.t()


## Breath multiplier for scale: (x, y). amp ~0.015-0.03, period 2-3.5 s. Feet stay put
## when the sprite's offset puts its feet on the origin (offset.y = -h/2).
static func breath(ph: float, amp: float = 0.02, period: float = 2.6) -> Vector2:
	if reduced():
		amp *= 0.3
	var s := sin(t() * TAU / maxf(0.5, period) + ph * TAU)
	return Vector2(1.0 - amp * 0.45 * s, 1.0 + amp * s)


## Hover offset in px (negative = up) for floating kinds.
static func hover(ph: float, amp: float = 2.5, period: float = 3.6) -> float:
	if reduced():
		amp *= 0.3
	return -amp * (0.5 + 0.5 * sin(t() * TAU / maxf(0.5, period) + ph * TAU))


## A copy of `sf` where `anim` holds frame 0 for `hold` s and every other frame for
## `flick` s at speed 1 fps (durations are in seconds). Copies are shared per recipe.
static func held_idle(sf: SpriteFrames, anim: String, hold: float, flick: float) -> SpriteFrames:
	if sf == null or not sf.has_animation(anim) or sf.get_frame_count(anim) < 2:
		return sf
	var key := "%d|held|%s|%.2f|%.2f" % [sf.get_instance_id(), anim, hold, flick]
	if _tuned.has(key):
		return _tuned[key]
	var out := _copy(sf, anim)
	out.set_animation_speed(anim, 1.0)
	var n := sf.get_frame_count(anim)
	for i in n:
		out.add_frame(anim, sf.get_frame_texture(anim, i), hold if i == 0 else flick)
	_tuned[key] = out
	return out


## A copy of `sf` whose `anim` keeps only frame 0 (for jumbled or mixed-pose idles:
## the code breath carries the motion instead).
static func still_idle(sf: SpriteFrames, anim: String) -> SpriteFrames:
	if sf == null or not sf.has_animation(anim) or sf.get_frame_count(anim) < 2:
		return sf
	var key := "%d|still|%s" % [sf.get_instance_id(), anim]
	if _tuned.has(key):
		return _tuned[key]
	var out := _copy(sf, anim)
	out.add_frame(anim, sf.get_frame_texture(anim, 0))
	_tuned[key] = out
	return out


## A copy of `sf` whose `anim` loops 0..n-1 then n-2..1 (no wrap pop), at `fps`.
static func pingpong(sf: SpriteFrames, anim: String, fps: float) -> SpriteFrames:
	if sf == null or not sf.has_animation(anim) or sf.get_frame_count(anim) < 3:
		return sf
	var key := "%d|pp|%s|%.2f" % [sf.get_instance_id(), anim, fps]
	if _tuned.has(key):
		return _tuned[key]
	var out := _copy(sf, anim)
	out.set_animation_speed(anim, fps)
	var n := sf.get_frame_count(anim)
	for i in n:
		out.add_frame(anim, sf.get_frame_texture(anim, i))
	for i in range(n - 2, 0, -1):
		out.add_frame(anim, sf.get_frame_texture(anim, i))
	_tuned[key] = out
	return out


## Everything of `sf` except `skip` (left as an empty animation to fill).
static func _copy(sf: SpriteFrames, skip: String) -> SpriteFrames:
	var out := SpriteFrames.new()
	out.remove_animation("default")
	for a in sf.get_animation_names():
		out.add_animation(a)
		out.set_animation_speed(a, sf.get_animation_speed(a))
		out.set_animation_loop(a, sf.get_animation_loop(a))
		if a == skip:
			continue
		for i in sf.get_frame_count(a):
			out.add_frame(a, sf.get_frame_texture(a, i), sf.get_frame_duration(a, i))
	return out


## Start a playing sprite at a random frame/progress with a small speed jitter.
static func random_start(spr: AnimatedSprite2D, r: RandomNumberGenerator, jitter: float = 0.12) -> void:
	if spr == null or spr.sprite_frames == null or not spr.sprite_frames.has_animation(spr.animation):
		return
	var n := spr.sprite_frames.get_frame_count(spr.animation)
	if n > 1:
		spr.set_frame_and_progress(r.randi() % n, r.randf())
	spr.speed_scale = r.randf_range(1.0 - jitter, 1.0 + jitter)
