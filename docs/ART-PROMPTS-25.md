# Dreams — Art Prompts 25: what the loop-6 audit found

WHAT THIS COVERS, most important first: the hero's face in the Neon Jacket and Ceremony Coat; a proper Big Grump boss sheet; ability button icons for 19 partners; icons for the 15 special skill unlocks.

HOW TO USE: each PROMPT below is one copy-paste into ChatGPT. It asks for at most 3 images and carries every rule it needs, so you can paste it into a fresh chat. Ask for the images one at a time if ChatGPT stops early ("now image 2"). Save each image under its exact file name and upload it here.


---

## PROMPT 25-1 — The hero's face in two coats, and Big Grump · 2 images

A hero wearing the Neon Jacket or the Ceremony Coat talks with the face of the bare body, not the coat. Big Grump, the first boss of the penguin arc, has no sprite of his own: the game blows up the little grump to twice its size, so he looks blocky and blurry and never winds up a hit.

> PROMPT 25-1. Make TWO SEPARATE IMAGES, each one its own picture, saved under the exact file name given.
>
> RULES FOR EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette (gangster-arc pieces in the dark underworld palette — charcoal, oxblood, navy, olive, tarnished brass — where it says so), flat #FF00FF magenta background, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere (not under, above or beside any piece, not even on cards, banners or icons), no watermark, NO LETTERBOXING. At least 24 px of clear magenta between separate pieces. All ages: no blood, nothing gory. Characters keep their exact look from the attached references.
>
> ■■■ IMAGE 1 of 2 — FILE NAME: "w471_hero_portraits_neon_ceremony.png" ■■■
> DIALOGUE PORTRAITS 96×96, shoulders up, soft vignette, no frame, the SAME hero face and head as the existing outfit portraits (attach portraits/hero_outfit_farmer and hero_outfit_scholar), six moods side by side in this order: NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, DETERMINED (x = 24 + N×150, y = 24 + M×150), one coat per row: (1) the NEON STREET JACKET in the dark underworld palette (attach the body/outfit_neon sheet: a short black jacket with glowing pink and cyan piping, collar up); (2) the CEREMONY COAT in the warm palette (attach the body/outfit_penguin sheet: a long midnight-blue coat with a white front and gold buttons, like a penguin's dress coat). Nothing else in the picture.
>
> ■■■ IMAGE 2 of 2 — FILE NAME: "w472_big_grump_boss.png" ■■■
> BIG GRUMP, the penguin arc's first boss, as a proper sprite sheet, the same look as the little grump but bigger and meaner (attach the enemies/grump sheet and ui/card_big_grump): a round, puffy grey-purple storm cloud with a deep scowl, heavy brows, stubby cloud arms and little yellow lightning bolts crackling underneath. 128×128 cells at x = 24 + N×152, y = 24 + M×152, the cloud filling about 112 px of the cell, all facing the viewer (down), one action per row: Row 0 IDLE ×4 (bobbing, bolts flickering); Row 1 WALK ×4 (drifting forward, puffing); Row 2 ATTACK ×6 (WIND-UP ×2: puffs up and darkens, then SLAM ×3: brings both arms down with a lightning flash and a ring of grey cloud-dust on the ground, then RECOVER ×1); Row 3 HURT ×2 (squashed, eyes squeezed shut, a few drops); Row 4 DEFEATED ×4 (shrinks and fizzles into a small sulky puff of grey smoke — sad, never hurt). Effects stay INSIDE each cell. All ages: no blood.
>
> (End of PROMPT 25-1: 2 images.)


---

## PROMPT 25-2 — Partner ability buttons and skill unlock icons · 2 images

Every partner's ability button shows the same paw, except Coco, Mer and Merry. The 15 skill-tree unlock nodes that give a special power show a plain potion or tool instead of a picture of the power.

======================================================================

COVERAGE TABLE (file → what it fixes → code name the slicer should write)

w471  hero portraits, neon + ceremony coats → portraits/hero_outfit_neon/<mood>, portraits/hero_outfit_penguin/<mood> (moods neutral|happy|sad|angry|surprised|determined, same as hero_outfit_farmer). Dialogue.portrait_for picks them up by costume name, no code needed.

w472  Big Grump boss sheet                   → enemies/big_grump/idle|walk|attack|hurt|die. Code: enemies.json big_grump "art": "big_grump" (or drop the "grump" default at enemy.gd:171 when enemies/big_grump exists) and enemy.gd:186 `var s := 0.5 if k != "big_grump" else 1.1` → `var s := 0.5 if (k != "big_grump" or Art.has("enemies/big_grump", "idle")) else 1.1`

w473  partner ability icons                  → ui/icon_ability_penguin_king|penguin_wizard|man|woman|son|girl|coldy|big_jim|npc_drifter|mk_kit|mk_ember|mk_dahlia|mk_juno|mk_rio|mk_mei|mk_bruno|mk_tomas|mk_sable|mk_atlas (48 px tall like the others; the key is the companion's "sprite"). Icon 20 is a spare (ui/icon_ability_default, optional).

w474  skill unlock icons                     → ui/node_farming_farming_u_wide_spout, node_mining_mining_u_tremor, node_foraging_foraging_u_domino_fall, node_fishing_fishing_u_tidecall, node_combat_combat_u_iron_gut, node_combat_combat_u_not_today, node_bartering_bartering_u_lucky_day, node_building_building_u_quick_build, node_magic_magic_u_twin_cast, node_strategist_strategist_u_quartermaster, node_strategist_strategist_u_drill_sergeant, node_leadership_leadership_u_rally_cry, node_leadership_leadership_u_field_medic, node_hustle_hustle_u_hot_loads, node_hustle_hustle_u_heavy_hitter (48×48; game_menu keeps node_ art for unlock nodes whose effect has no candidate list).

LEFT OUT ON PURPOSE

- Skill icons for magic, pup, bartering, building, leadership, strategist, harmony and hustle (252 nodes show item icons today): Prompts 17 w345–w352 already ask for them, and they just haven't been uploaded. Only the three " II" names need a slicer fix (fix 4).

- Effect strips for Coldy, Big Jim, Pip-Pip and Nova (17, 12B redo part 2) and for Dad, Mom, Pax, Kairi and Sal (19 w418/w419 plus a slicer mapping): already asked for.

- Countryside ground: the existing shoulder/dry_grass art is enough; the stripes are a slicer/data bug (fix 1).

- Portrait moods beyond neutral/happy for minor speakers: only 11 lines in the whole game ask for a mood.

- The 13 enemies with a "die" strip, and an attack for the ash hound: the art is already there (fixes 5 and 6).

- Ending paintings, vehicles, horses, bots, spells, tele icons, crew badges and specials: all present or already asked for (17).

> PROMPT 25-2. Make TWO SEPARATE IMAGES, each one its own picture, saved under the exact file name given.
>
> RULES FOR EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette (gangster-arc pieces in the dark underworld palette — charcoal, oxblood, navy, olive, tarnished brass — where it says so), flat #FF00FF magenta background, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere (not under, above or beside any piece, not even on cards, banners or icons), no watermark, NO LETTERBOXING. At least 24 px of clear magenta between separate pieces. All ages: no blood, nothing gory. Characters keep their exact look from the attached references.
>
> ■■■ IMAGE 1 of 2 — FILE NAME: "w473_partner_ability_icons.png" ■■■
> ABILITY BUTTON ICONS on the ICON RULE (112×112, gold frame and studs, soft background, one bold picture, no text), 20 icons in 4 rows of 5 at x = 24 + col×148, y = 24 + row×148, left to right, top to bottom. ROW 1 (penguin and both-arc partners, warm palette): 1. PIP-PIP's Power Pose (a penguin silhouette striking a pose inside a crystal aura, blue background); 2. NOVA's Meow Pow Wow (a purring penguin-cat face sending out violet rings, purple background); 3. DAD's Haul (an axe biting a falling tree, green background); 4. MOM's Mend (a heart wrapped in a healing leaf, soft pink background); 5. PAX's Scout (a running boot with speed lines and a small map pin, sky background). ROW 2: 6. KAIRI's Tinker (a wrench crossed over a small open bag, teal background); 7. COLDY's Bee Bop Boo Baby (a stomping foot cracking an icy ground ring, ice-blue background); 8. BIG JIM's Muscle (a flexed arm breaking a rock in two, orange background, dark underworld palette); 9. SAL's Fence (a coin stack on a loot sack with a small up arrow, olive background, dark underworld palette); 10. KIT's Gale gift (a curling gust of wind). ROWS 3–4: the rest of THE MARKED, each a symbol of their gift in the dark underworld palette with a faint glow, background tinted to match: 11. EMBER's Cinder (a glowing ember flame); 12. DAHLIA's Bramble (a thorny vine curling round itself); 13. JUNO's Volt (a crackling lightning fork); 14. RIO's Tempo (a pulsing music note with beat rings); 15. MEI's Fortune (a lucky coin with a sparkle); 16. BRUNO's Iron (a riveted iron fist); 17. TOMAS's Mirror (a hand mirror reflecting a star); 18. SABLE's Shade (a crescent of shadow with two bright eyes); 19. ATLAS's Gravity (a small planet pulling pebbles inward); 20. (spare) a plain glowing paw on a gold field, the same frame. Nothing else in the picture.
>
> ■■■ IMAGE 2 of 2 — FILE NAME: "w474_unlock_node_icons.png" ■■■
> SKILL UNLOCK ICONS on the ICON RULE (112×112, gold frame and studs, no text), 15 icons in 3 rows of 5 at x = 24 + col×148, y = 24 + row×148, a soft VIOLET background for all (unlock nodes are framed in violet in the game), left to right, top to bottom: 1. WIDE SPOUT (a watering can pouring a wide fan of water over three soil squares); 2. TREMOR (a pickaxe striking the ground, a ring of cracks and flying pebbles); 3. DOMINO FALL (three trees toppling in a row); 4. TIDECALL (a fishing rod pulling a rising wave with fish leaping); 5. IRON GUT (a sturdy stomach-shield badge with a little X over a green poison bubble); 6. NOT TODAY (a cracked heart held together by a golden glow and a raised fist — hopeful, nothing sad); 7. LUCKY DAY (a gold coin with a four-leaf clover and sparkles); 8. QUICK BUILD (a hammer with speed lines over a half-built wall); 9. TWIN CAST (two crystal wands crossed, each with a matching star); 10. QUARTERMASTER (a supply crate with a small flag on top); 11. DRILL SERGEANT (a whistle and a sword over a little helper's helmet); 12. RALLY CRY (a raised banner with sound rings); 13. FIELD MEDIC (a satchel with a green cross and a heart); 14. HOT LOADS (a six-shooter with a small orange glow at the muzzle, dark underworld palette, no person); 15. HEAVY HITTER (a heavy revolver with a brass star, dark underworld palette, no person). Nothing else in the picture.
>
> (End of PROMPT 25-2: 2 images.)
