# CONDUCT 14b contract (animation life)

## 1. Anim API (P1 builds scripts/anim.gd, class_name Anim, static; everyone uses it)
- `Anim.phase(node_or_cell) -> float` stable pseudo-random phase 0..1 from a position/instance id, so neighbours never move in lockstep.
- `Anim.t() -> float` animation time in seconds on GAME time (PlayClock), stops while paused; never Time.get_ticks_msec().
- `Anim.wind() -> float` 0..1 current wind strength from weather (calm/clear 0.25, rain 0.6, storm 1.0, snow 0.4) and season (fall +0.1), smoothed; `Anim.gust(phase) -> float` occasional gust 0..1.
- `Anim.reduced() -> bool` = Settings.reduced_motion(): when true, ambient loops run at about 30% amplitude and no flashing.
- `Anim.sway_material(strength := 1.0) -> ShaderMaterial` shared material using shaders/sway.gdshader (vertex sway pinned at the sprite's base, uniforms wind/phase/strength set per instance via instance uniforms or per-node set_instance_shader_parameter); for trees, bushes, grass tufts, crops, flowers, reeds, flags, banners, sails, laundry. One material instance shared; per-node phase via instance params (no material per node).
- `Anim.strip_fps(id, default) -> float` reads optional fps/frames overrides from data/anim_c14b.json {art_id: {fps, pingpong, random_start}} so every package tunes timing in data, not code. `Anim.apply(sprite, id)` applies fps, random start frame, ping-pong.
- `Anim.bob(node, amp_px, period_s)` / `Anim.breathe(sprite, amp, period)` cheap code motion helpers (whole-pixel snapping to avoid shimmer on the 2x art: use 0.5 px steps at 0.5 scale).
- game_map.gd anim_prop(...) (P1) applies Anim.apply automatically for any strip, so random start and fps overrides take effect everywhere.

## 2. Ownership
- game_map.gd, scenery.gd: P1. Others: hooks of at most 2 lines.
- data/anim_c14b.json: every package appends its own ids (json_merge at integration). File created by P1 with {}.
- region.gd / gen_mega_new.py / regions.json: P4. town.gd etc: P3. npc.gd/player.gd/character_library: P5. world_gen.gd/enemy.gd: P6. interior/mine/night_glow/water shaders: P2.
- art/gen/manifest.json: each slicer appends (json_merge). New art ids prefixed c14b<pk>_.
- tools/check.sh: append new test blocks at the END with an `echo "== ... =="` header, blank line before and after.

## 3. Tests
P1 writes tools/anim_test.gd: game-time only, every strip in data/anim_c14b.json loads, phases differ between neighbours, reduced motion lowers amplitude, Anim.t stops while paused. Each package adds its own targeted test (e.g. fountain frames seamless: first and last frame differ by less than a threshold; idle strips exist for every hero/facing).

## 4. Art budget (dreams-image; ~920 left today after C14)
P1 40, P2 120, P3 100, P4 120, P5 200, P6 160. Record every prompt in your report.

## 5. Rules
Smooth over flashy: easing, sub-steps, 6-12 fps for ambient strips with random start, ping-pong where loops would pop; no lockstep; reduced motion respected; web/phone budget (P1 publishes the budget in NOTES.md early; cull off-screen; bake static; prefer shaders over many frames for sway). All ages; both arcs. Notes: /home/claude/wt/c14bf_reports/NOTES.md.
