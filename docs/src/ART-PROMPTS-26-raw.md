# Dreams — Art Prompts 26: what the loop-7 audit found

WHAT THIS COVERS, most important first: a seamless glowing teal moss ground for the three places that show it as a flat grid of identical squares today (the Hollow Heart under the world, the Jungle, and the Kelp colony); a seamless violet jungle soil so the Jungle's soil patch stops being a hard purple box; and the storm puddles, which came out as a solid pink blob and were never redrawn.

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette (the cave and jungle pieces in a glowing night palette — deep teal, cyan, violet, a little gold — where it says so), flat #FF00FF magenta background, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere (not under, above or beside any piece), no watermark, NO LETTERBOXING. At least 24 px of clear magenta between separate pieces. All ages: nothing gory.

SEAMLESS RULE: a seamless square must tile with no visible edge when copied side by side in every direction: no border, no vignette, no lighter or darker rim, no shadow on one side, no single big feature that repeats obviously (small details only, spread evenly). Squares are 256×256, 5 per row, x = 24 + N×304, y = 24 + M×304. Seen from straight above. Fill each square edge to edge (no magenta inside a square).

PROP RULE (puddles): each piece isolated on magenta, seen from slightly above like the other ground props, frames of one piece side by side in its row, cells at x = 24 + N×176, y = 24 + M×120, each cell 152×96, the puddle centred and lying flat on the ground (no shadow under it, no ground drawn around it).

---

## BATCH 1 — Glowing ground and storm puddles (2 images)

The Hollow Heart, the Jungle and the Kelp colony paint the same small moss square on every cell, so the ground looks like a grid of tiles instead of moss. The Jungle's violet soil is a hard rectangle. The storm puddles were sliced as a solid magenta blob, so storms reuse the plain rain puddles.

> IMAGE "w475_glow_ground_seamless.png": GLOWING GROUND by the SEAMLESS RULE (256×256 squares, 5 per row, x = 24 + N×304, y = 24 + M×304, no border, no rim, small details spread evenly), in the glowing night palette, matching the existing pieces (attach tiles/teal_moss, tiles/violet_soil and seamless/forest_floor for the look). Row 0, left to right: (1) TEAL MOSS — soft deep-teal moss with tiny cyan glow specks and a few pale-green sprigs, the main ground of the cave country under the world; (2) TEAL MOSS, DENSER — the same moss a little brighter, thicker tufts and more glow specks (for variety, it must match square 1 in colour); (3) TEAL MOSS, WET — the same moss darker and damp, with a few tiny glints of water (for the kelp colony); (4) VIOLET SOIL — loose violet-purple alien soil with small dark pebbles and a few faint pink glow specks (the jungle's soil); (5) VIOLET SOIL WITH MOSS — the same soil with thin teal moss creeping across it in small patches. Nothing else in the picture.

> IMAGE "w476_storm_puddles.png": STORM PUDDLES by the PROP RULE (cells 152×96 at x = 24 + N×176, y = 24 + M×120, each puddle centred, lying flat, no ground around it), the same style as the existing rain puddles (attach props/puddle_0 and props/puddle_3) but bigger and choppier: dark blue-grey water with a pale rim, splashed by heavy rain. Four puddles, one per row, each 3 frames of animation side by side (raindrops hit in different spots each frame, ripple rings grow and fade, so the three frames loop): Row 0 a wide oval puddle; Row 1 a long kidney-shaped puddle; Row 2 two small puddles joined by a thin trickle; Row 3 a round puddle with a little floating leaf. Every frame of a puddle the same size and shape, only the drops and rings change. Nothing else in the picture.

======================================================================
COVERAGE TABLE (file → what it fixes → code name the slicer should write)
w475  glowing ground squares → seamless/teal_moss, seamless/teal_moss_dense, seamless/teal_moss_wet, seamless/violet_soil, seamless/violet_moss (slice_art3.py: `square(im, b)` on the five boxes in row order, then make_seamless.py). Code: "ground_seam": "teal_moss" on jungle (regions.json), hollow_heart (gen_deep_region.py), "teal_moss_wet" on colony_kelp (gen_colonies.py); region.gd:851 layers use soft_ground(cells, "violet_soil") when seamless/violet_soil exists (audit 15 fix 2).
w476  storm puddles          → props/puddle_storm_0..3, 3-frame strips like props/puddle_0..5 (replace the wx_143–146 alias in slice_world.py w_names5). Code: world_gen.gd:108 picks puddle_storm_N on storm days (audit 15 fix 5); drop the puddle_storm line from missing_art.py.

LEFT OUT ON PURPOSE
- A cave border wall for the Hollow Heart: tiles/mine_heart_wall_0..6 already exist, so this is a one-line code fix (fix 3).
- Sand drifts on the coral and ember colonies: seamless/sand exists, and the patch block is skipped by a guard (fix 4).
- A glowing moth for the Hollow Heart: 19 w422 already asks for it. It only needs a slicer mapping to wildlife/moth (fix 6).
- The town fountain (props/fountain) and the 21 item icons in MISSING-ART.md: already asked for (19 w422; 18, 19, 23).
- Hero portraits for the two coats, Big Grump, partner ability icons and skill unlock icons: Prompts 25.
- Everything from 17–24 that is still waiting for upload (w345 onward): nothing new was uploaded since loop 2, so those prompts still stand as written.
