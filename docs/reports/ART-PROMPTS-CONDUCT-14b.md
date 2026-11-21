# Art prompts used in CONDUCT 14b (dreams-image, 41 images)

Every prompt from the six fix-package reports, copied verbatim (where a report shortened a repeated prompt with "..." or "same template", that is how it was recorded). All of these were already made and placed by Claude: **nothing for Tom to make.** Art still wanted later is listed in docs/ART-QUEUE.md (C14b section and the C14b lines above it).

## P1 (0 images)

None: rain, snow, aurora, ripples and the sway are drawn in code.

## P2 (0 images)

None: the fountains and pools flow in a shader on existing frames. Its three queued prompts (water mill wheel, fire_barrel2, lamp_mechanism) are in docs/ART-QUEUE.md.

## P3 (4 images)

1. c14bp3_water_mill_parts.png (edit of buildings/water_mill.png): "Use the LEFTMOST building of this sprite strip as the reference. Make a pixel-art sprite sheet on a flat solid magenta #FF00FF background with wide magenta gutters, two separate objects side by side: LEFT: the same lakeside water mill building (red tile roof, stone chimney with no smoke, timber frame, blue windows, planters, wooden stilts) but WITHOUT its water wheel and without any water splash: where the wheel was, show the plain stone wall and a small iron axle hub only. Same pose, proportions, colours and 2x-detail pixel-art style. RIGHT: the water wheel ALONE seen face-on, perfectly round and symmetric, 8 straight spokes, wooden paddles round the rim, iron rim bands and a brass hub at the exact centre, wet dark wood with light-blue highlights, no water, no shadow, centred so it can spin about its centre. Top-down 3/4 farming-game style like Stardew Valley / Sun Haven. Nothing else in the image."
2. c14bp3_windmill_parts.png (edit of props/windmill3.png): "Use the LEFTMOST windmill of this sprite strip as the reference. ... LEFT: the same farm windmill tower (same body, roof cap, door, vines and colours, same 2x-detail pixel-art style) but WITHOUT its sails: only a round wooden hub/axle cap on the front of the cap where the sails attach. RIGHT: the four-blade sail cross ALONE, seen face-on, perfectly symmetric (4 identical lattice sails with canvas at exact 90 degree steps), a round hub at the exact centre, no tower, no shadow, centred so it can spin about its centre. Nothing else in the image."
3. c14bp3_bonfire_strip.png (generate): "Pixel art sprite sheet, exactly 6 frames in ONE horizontal row, evenly spaced, on a flat solid magenta #FF00FF background with wide magenta gutters between frames: a large festival bonfire of crossed logs inside a ring of grey stones, orange and gold flames licking up and swaying, a seamless looping flicker animation. The logs and stones are IDENTICAL and in the same position in every frame; only the flames change, gradually from frame to frame, and frame 6 leads smoothly back into frame 1. No sparks flying off the frame, no smoke, no ground, no shadow outside the stones. Top-down 3/4 view, cosy 2x-detail farming-game style like Stardew Valley / Sun Haven, crisp outlines."
4. c14bp3_windpump_gang_parts.png (edit of image 2): "Same layout, size and pixel-art style as the reference (two separate objects side by side on flat solid magenta #FF00FF with wide gutters), but restyled for a gritty dark underworld / cyberpunk farm: LEFT: a steel lattice windpump tower of dark gunmetal girders with rivets, a corrugated metal hut at its foot with a small cyan neon strip light and a padlocked door, a round steel hub cap high on the front where the rotor attaches, NO rotor blades. RIGHT: the rotor ALONE seen face-on: a perfectly symmetric multi-blade steel fan wheel (12 curved galvanised metal blades in a ring) with a dark hub at the exact centre, no tower, no shadow, centred so it can spin about its centre. Nothing else in the image."
- Failed (no image made): edit of art/gen/props/c14p2_tree_planter.png (not on main): "Pixel-art sprite sheet on a flat solid magenta #FF00FF background with wide magenta gutters: the SAME plaza tree in the SAME black iron planter as the reference, twice, side by side, identical size, pose, trunk, planter and outline, 2x-detail pixel art. LEFT: autumn: the leaves orange, amber and red, a few fallen leaves on the planter soil. RIGHT: winter: bare brown branches with a light snow cap on the branches and on the planter rim, a little snow on the soil. No ground, no shadow outside the planter, nothing else in the image." -> for docs/ART-QUEUE.md after C14 merges to main.

Sliced ids: buildings/c14bp3_water_mill_base (+hub), c14bp3_water_mill_wheel, props/c14bp3_windmill_body (+hub), c14bp3_windmill_sails, c14bp3_windpump_gang_body (+hub), c14bp3_windpump_gang_rotor, c14bp3_bonfire (6 frames). art_audit --fix clean. set_import_lossy not run (new files only would be needed; default import used).

## P4 (1 image)

1 image of 120 (dreams-image, art/incoming/c14b/c14bp4_windmill_parts.png, sliced to props/c14bp4_windmill_body + props/c14bp4_windmill_sails, art_audit clean, lossy 0.8 imports for the two new files only). Prompt:
'Pixel-art game sprite sheet, 16-bit Stardew Valley style, 2x detail, crisp dark outlines, solid flat magenta #FF00FF background everywhere (no gradient, no shadow on the background). Two separate objects side by side with wide magenta gaps between them. LEFT: a cozy countryside windmill tower seen from the front in 3/4 top-down view: cream plaster round tower on a grey stone base, red shingle conical cap, small wooden round-top door, a little window, ivy and pink flowers at the base, and a round wooden hub cap on the front of the cap, but NO sails and NO blades at all. RIGHT: a windmill sail cross on its own, front view: four identical wooden lattice sails with cream canvas, arranged in a perfect plus/X shape, perfectly symmetric around a round wooden hub in the exact centre, so it can be rotated in code; nothing else.' (1536x1024, n=1)

## P5 (24 images)

One edit per idle strip, n=1, into art/incoming/c14b_p5/ (23 used; penguin_wizard's blink unused, maple redone as maple_blink2 after a GitHub 409).

Prompts (edit_image, source = the strip named above):
- Heroes (strip): "This is a pixel-art sprite strip (several frames side by side) of a chibi character facing the viewer. Make an exact copy of the image with ONE change only: in every frame the character's eyes are gently CLOSED (a blink: each eye becomes a short dark curved line, eyelids shut). Keep everything else pixel-identical: same pose, same [mouth,] outline, same colours, same clothing and accessories, same framing, same transparent background, same size and position. Pixel art, no smoothing, no new details." (The gang batch added "same mouth".) The June test used the same wording with "chibi farmer girl".
- Villagers (single frame): "This is a pixel-art sprite of a chibi villager facing the viewer. Make an exact copy of the image with ONE change only: the character's eyes are gently CLOSED (a blink: each eye becomes a short dark curved line, eyelids shut). Keep everything else pixel-identical: same pose, same mouth, same outline, same colours, same clothing and accessories, same framing, same transparent background, same size and position. Pixel art, no smoothing, no new details."

## P6 (12 images)

Every prompt asked for 1 image, used edit_image on the existing strip, size 1536x1024.

1. c14bp6_president_idle (source characters/president/idle.png): "Pixel-art sprite sheet: the SAME older gray-haired gangster boss in a long dark coat with gold trim, gray three-piece suit, red scar over one eye, identical design to the FRONT-facing figure on the left of the source. One row of 4 frames, all FRONT/3-quarter view facing the viewer (never his back): idle loop - frame 1 standing, frame 2 chest rises slightly (breathing in), frame 3 adjusts his cufflink with one hand, frame 4 breathing out. Feet on the same baseline in every frame, same size every frame, wide even gaps between frames, flat solid magenta #FF00FF background, crisp 2x-detail pixel art, soft dark outline, no text."
2. c14bp6_rabbit_idle (wildlife/rabbit/idle.png): "Pixel-art sprite strip of the SAME tan wild rabbit as the source (identical colours, size and outline style), side view facing right. One row of 4 frames, idle loop: sitting, nose twitch, ear flick, chewing. Same size and the same ground line in every frame, wide even gaps, flat solid magenta #FF00FF background, crisp 2x-detail cozy farming-game pixel art, no text."
3. c14bp6_squirrel_idle: same template; "red squirrel ... sitting upright, tail flick, nibbling an acorn, blink."
4. c14bp6_sparrow_idle: same template; "small brown sparrow ... standing on the ground ... stand, peck down, head up, tail bob."
5. c14bp6_duck_idle: same template; "mallard duck ... standing on grass ... stand, preen a wing, head bob, tail wag."
6. c14bp6_frog_idle: same template; "green frog ... sitting, throat puff, blink, small crouch."
7. c14bp6_fox_idle: same template; "red fox ... standing, ear twitch, tail swish, head turn."
8. c14bp6_storm_roc_idle (enemies/storm_roc/idle.png): "Pixel-art sprite strip of the SAME storm roc boss bird as the LEFTMOST figure of the source (identical design, colours and outline), perched and resting, side view facing right. One row of 4 frames, idle loop: wings folded the whole time, chest rises and falls, feathers ruffle, head turns slightly, faint lightning crackles along the wings. Same size and the same ground line in every frame, generous margin around each figure so nothing is cut off, flat solid magenta #FF00FF background, crisp 2x-detail pixel art, all ages, no text."
9. c14bp6_rime_wyrm_idle: same template; "rime wyrm boss ... coiled and resting ... same coiled pose in every frame, chest rises and falls, frost mist drifts, eyes glint."
10. c14bp6_cboss_kelp_idle: same template; "kelp serpent boss ... the same coil silhouette in every frame, only the kelp fronds and the head sway gently, a few bubbles rise."
11. c14bp6_cboss_coral_idle: same template; "coral treant boss ... identical body in every frame, only the branch tips sway and the polyps pulse softly."
12. c14bp6_cboss_ice_idle: same template; "frost boss ... resting ... NO frost-breath attack ... calm breathing, shoulders rise and fall, icy crystals glint, a little cold mist drifts."

## Audio

None (ACE 0).
