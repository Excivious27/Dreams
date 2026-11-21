# CONDUCT 14b report: animation life (2026-11-21)

An animation pass over both arcs. Tom asked for "smooth, natural, seamless ambient motion everywhere" (flags and cloth in the wind, foliage, water, smoke and fire, wildlife), for the choppy animations to be fixed ("the Town Hall fountain" was the named bad example), for magic-area sparkles on the ground and shimmers in the sky that are "really well done", and for subtle Sun Haven-style idles for the player, the villagers and the animals. The Town Hall fountain was fixed first: the water now flows in a shader on one still drawing. Trees, grass, flowers, flags and crops sway in a wind that follows the weather; rain and snow have depth; lighthouses sweep a beam; windmills and the water mill turn; festivals get lanterns, fireworks and shooting stars; magic areas sparkle and shimmer; heroes and villagers breathe, blink and glance; critters, farm animals, pets and foes move out of step. 18 focus auditors (306 findings) fed 6 fix packages (scopes in /home/claude/wt/C14B_SCOPES.txt, the shared Anim API and ownership fixed up front in C14B_CONTRACT.md), then one hook integration pass. **Final full CI c14bi: PENDING.**

**Whole game after C14b: about 82% done, 18% remaining** (average of the 112 systems in docs/inventory.csv). New rows: animation core 88%, water features 86%, weather and sky effects 87%, character idles 80%, creature motion 80%, magic and light effects 86%. Moved: weather visuals 85% -> 90%, NPC and animal animation 78% -> 84%.

## Audit (18 focus auditors, 306 findings: 1 blocker, 136 major, 132 minor, 37 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Blocker | The President's battle idle showed his back. |
| Water (01) | The Town Hall fountain looped a "turning on" strip (dry to full, popping back to dry, basin jittering). Hot spring, glow pond, tide pools and the waterfall pool did the same; sprinklers never sprayed; still water had no life. |
| Wind, foliage, fire (02-04) | Nothing swayed: trees, grass, flags, laundry and crops were rigid, and there was no wind by weather. Fires snapped in a growth ramp, lights all flickered alike, and kettles and stations showed nothing while working. |
| Magic and tech (05-06) | No ground sparkles or sky shimmer, a hard-edged aurora, frozen region strips, everything in lockstep. |
| Player, villagers, animals, foes (07-10) | Side and up idles frozen, no breathing or blinks, villagers as statues whose poses re-rolled every frame, animals and foes looping in step, fish and rabbits sliding. |
| Town, weather, UI (11-13) | Lighthouses strobed, windmills and the water mill jittered, clocks stood still, festivals had no lanterns or fireworks; rain strobed and snow flipped frames. |
| Timing, budget, interiors, mines, seasons (14-18) | Wall-clock timers, no phase offsets, no animation budget, frozen interior fires, no cave drips, random weather on festival days. |

## Fix packages

| Package | Fixed | Images |
|---|---|---|
| P1 Anim core, weather and sky, perf | `Anim` API (scripts/anim.gd: game time, phase, wind and gusts, reduced motion, shared sway materials, strip timing from data/anim_c14b.json) and shaders/sway.gdshader: 105 swaying sprites in town on 9 materials. Every placed strip starts on its own frame and speed. Code rain/storm/hail streaks slanted by wind, snow and blizzard in 3 depth layers, soft aurora ribbons, one lightning flash per bolt, petals and leaves on clear days, 1 s fade on weather change. Water life (ripples, fish jumps, rain splashes). anim_budget_test and perf_probe animation fields. Tests: anim_core_test, weather_fx_test, anim_budget_test. | 0 |
| P2 Water, fire, light, interiors, mines | `WaterFeature` + shaders/water_flow.gdshader: the Town Hall fountain holds its full-flow drawing and only the water moves (streaks down the sheets, ripples in the bowls, glints, splash droplets), seamless on game time. Same for hot spring, glow pond, tide pools, waterfall pool and every fountain placed anywhere. Water mask on game time. Light kinds (fire, electric, neon, crystal) each with its own flicker; room fires glow indoors; kettles and pots steam; windows go out one by one at night. `MineLife` drips and dust. `tools/register_strip.py` re-registered the bonfire and bubbling pot. Casino machines hum. Tests: water_feature_test, glow_kinds_test, mine_life_test, shore_motion_test. | 0 |
| P3 Wind, town, farm, beach, festivals | Crops sway and part as you walk through (crop_sway shader). Sprinklers spray in the morning. Water mill wheel and farm windmill sails spin in code on new split art (gang arc: a steel windpump). `LighthouseBeam` sweeping cone. `FestivalSky`: river and sky lanterns, fireworks, shooting stars at the Star Festival. `ClockHands` show game time. `StationFx` smoke and steam while crafting. Boats and buoys bob, the fish pond ripples, festival days get their own weather, a 6-frame festival bonfire. Test: c14b_p3_test. | 4 |
| P4 Magic and tech areas | `MagicFx`: ground sparkles, sky veils, shimmer stars and motes in 24 magic maps (wisps, spores, embers, dust, fireflies, data blips), cloud wisps over the cloud sea, moon dusk and aurora, shooting stars. `RegionAnim`: frozen region strips play, out of step, neon hum and stutter, drones glide, boats bob. Colony crystals glow and wake with a burst. Windmill sails spin in Orchard Hills and Breezehaven. Test: c14b_p4_magic_test. | 1 |
| P5 Character idles | `IdleLife` breath for heroes and villagers (own phase, fades when moving, every layer together). Blinks for 12 heroes and 11 villagers. Real side and up idles, front idles at 3 fps with a held rest. The hero glances to the side after standing still. Villager pose scheduler (gestures then rests), indoor counter work, villagers face you within 40 px, fewer all-day umbrellas. Test: c14b_p5_test. | 24 |
| P6 Creatures, animals, foes | `CreatureMotion`: foes out of step with held idles and breath, a front-facing President idle (the blocker), new idles for 5 bosses, a hovering Dark Crystal with motes. Ranch animals hold, blink, sleep at night and hop when petted. Rabbits and frogs hop, birds perch and fly off then land, fish leap from under ripples, butterflies wobble, fireflies pulse, pets sit and nap. Test: creature_life_test. | 12 |
| Hook integration | All helpers (IdleLife, CreatureMotion, AmbientMotion, RegionAnim) read Anim time and reduced motion. Region water strips hold still and flow in the shader. One lighthouse beam per map. The moon shows a faint aurora by day. Villager walk strips no longer start in step. 25 targeted tests, 0 failures. | 0 |

**Images: 41** from dreams-image (P1 0, P2 0, P3 4, P4 1, P5 24, P6 12). **ACE: 0.** Every prompt is in docs/reports/ART-PROMPTS-CONDUCT-14b.md.

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 03:40-04:00 PT | auditor | medium | ~20 |
| Packages + contract (306 findings into 6 packages), 04:00-04:05 | conductor | medium | ~5 |
| Fix agents P1-P6 in parallel, 04:05-04:50 | fixer | medium | ~45 |
| Merges, 04:55-05:05 | integrator | medium | ~10 |
| Hook agent, 05:00-05:10 | integrator | medium | ~10 |
| Final full CI c14bi, started ~05:08 | CI | | PENDING |
| **Total** | | | **~1.5 h wall clock (03:40-05:08) + final CI** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 hook integrator |
| Images used | | | 41 |
| ACE credits used | | | 0 |

## Still open

- **Water:** mountain waterfall still a sliver, lake waterfall pool looks like a sticker, fountain water sound, a gangster fountain look.
- **Smoke and fire:** town and house chimney smoke, fire_barrel2 and lamp_mechanism frames are different drawings (need redraws), placeable fire decor, Neon battlefield neon, hanging lantern sway, industrial smoke and aviation lights.
- **Wind and town:** border trees don't sway, leaves don't land, flags and signs painted into buildings, sail bellies, wind turbine and helicopter rotors held on frame 0 (need split art), garden windmill decor and the lighthouse_lamp decor fps, the plaza tree planter's autumn/winter looks, chapel bell, cranes, mill night windows.
- **Magic:** Hollow Deeps vein pulse, Emberclaw heat shimmer, wind shrine vane, ghost path; RegionAnim timing tables still in code, not in data/anim_c14b.json.
- **People:** blinks for the other villagers, mega folk and crew; side and up idle strips for the human heroes; Bo's and the ride strips need a re-cut; swim float, spouse and evening seating poses, fishing line, festival crowds, marina staff as real walkers.
- **Animals and foes:** idles for lieutenants, Marked, thugs and three bosses; hop and flight strips; sad/walk_up/walk_down for ranch animals; CritterDirector around the camera; landing on flowers; sea birds; barn door pop; Marked off-centre cells.
- **Tech:** per-frame durations in Art.frames, a web/phone frame cap, a global reduced-motion lever for battle and campaign banners.
- **Art queue:** the prompts for all of the art above are in docs/ART-QUEUE.md (C14b section).
- **Gotcha:** never run `tools/set_import_lossy.py` over the tree (it takes the first argument as a quality and rewrote ~19,000 .import files in one worktree): set lossy only on your own new files.
- **Map look:** the paved patch around the crystal meadow standing stones has hard straight edges (pre-existing, for a later ground pass).

## Tom's call

No new questions this round.
