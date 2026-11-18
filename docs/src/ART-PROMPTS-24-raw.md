# Dreams — Art Prompts 24: what the loop-5 audit found

WHAT THIS COVERS, most important first: faces for the two penguin-arc villains who talk with no portrait; the hero's face in the six new costumes from Prompts 23; the pet poses the game asks for but the other breeds don't have (fetch, beg, play, dig); and attack frames for the golem and the shard, the two common enemies that still hit you without moving.

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette (gangster-arc pieces in the dark underworld palette — charcoal, oxblood, navy, olive, tarnished brass — where it says so), flat #FF00FF magenta background, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere (not under, above or beside any piece, not even on cards or banners), no watermark, NO LETTERBOXING. At least 24 px of clear magenta between separate pieces. All ages: no blood, nothing gory. Characters keep their exact look from the attached references.

GRID RULE (character sheets): 64×96 cells at x = 24 + N×88, y = 24 + M×120 (16 columns, 8 rows), feet at the bottom of the cell, the character 56 px tall (children 44 px). LEAVE A CLEAR MAGENTA GAP of at least 16 px between every sprite.

---

## BATCH 1 — Faces (3 images)

Big Grump and the Grump Commander have lines but no face in the dialogue box. And a hero wearing one of the six new costumes talks with the face of the bare body base, not the outfit.

> IMAGE "w466_villain_portraits.png": DIALOGUE PORTRAITS 96×96, shoulders up (or the whole head for a cloud), soft vignette, no frame, three moods side by side (NEUTRAL, HAPPY, WORRIED), one villain per row (x = 24 + N×150, y = 24 + M×150): (1) BIG GRUMP (attach the enemies/grump sheet): a round, puffy grey-purple storm cloud with a deep scowl, heavy brows and little yellow lightning bolts crackling under it; HAPPY is a smug, satisfied smirk with one bolt zapping, WORRIED is the cloud shrinking and raining a few drops, brows tilted up (sad, never hurt); (2) THE GRUMP COMMANDER (attach the enemies/commander sheet and card art w455): a much bigger purple-black storm cloud with a snarling scowl, a crown of sharp violet crystal spikes on top and orange lightning down both sides; HAPPY is a gloating grin with the lightning flaring, WORRIED is the spikes drooping, lightning down to a flicker, eyes wide. Same look as the other portraits (attach portraits/light_eater and portraits/dark_crystal for the style).

> IMAGE "w467_hero_costume_portraits_gang.png": DIALOGUE PORTRAITS 96×96, shoulders up, soft vignette, no frame, the SAME hero face and head as the existing outfit portraits (attach portraits/hero_outfit_farmer and hero_armor_steel), in the dark underworld palette for the clothes, six moods side by side in this order: NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, DETERMINED (x = 24 + N×150, y = 24 + M×150), one costume per row, matching the costumes in w460: (1) PINSTRIPE SUIT (charcoal pinstripe jacket, white shirt, dark tie), (2) PADDED VEST (quilted olive vest over a rolled-sleeve shirt, braces), (3) ARMORED SUIT (a dark three-piece suit with brass-riveted plates sewn in at chest and shoulders).

> IMAGE "w468_hero_costume_portraits_penguin.png": the same six-mood portrait row, same hero face, same layout as w467, warm palette, one costume per row, matching w460: (1) PUFFY PARKA (a round red quilted parka, fur-trimmed hood down), (2) CRYSTAL PARKA (icy blue parka with glowing crystal toggles and frost trim), (3) STARLIGHT MANTLE (a midnight-blue cape over a pale tunic, scattered with tiny gold stars).

## BATCH 2 — Pet poses and two enemy attacks (2 images)

Any dog or cat can be your pet. The game plays FETCH when the pet brings you something, BEG and PLAY when you fuss over it and DIG when it sniffs out a find. Five breeds and all three cats are missing some of these, so they freeze in place. The golem and the shard hit you without moving.

> IMAGE "w469_pet_poses.png": PET POSES on the GRID RULE but with 64×64 cells (x = 24 + N×88, y = 24 + M×88) and the animal 40 px long, paws on the bottom edge, every frame the same size and style as the breed's existing sheet (attach animals/dog_collie, dog_golden, dog_husky, dog_hound, dog_white, cat_orange, cat_grey, cat_calico), one animal per row, all facing right: Row 0 COLLIE, Row 1 GOLDEN, Row 2 HUSKY — each: PLAY (bow, front down, tail up) ×2, FETCH (trotting back with a stick in the mouth) ×4, BEG (sitting up, front paws raised) ×2. Row 3 HOUND, Row 4 WHITE DOG — each: DIG ×6 (dirt flying, kept INSIDE each cell, never touching the next frame), FETCH ×4, BEG ×2. Row 5 ORANGE CAT, Row 6 GREY CAT, Row 7 CALICO CAT — each: DIG ×6 (scratching at the ground, a few crumbs flying, kept inside the cell), FETCH ×4 (trotting with a small ribbon toy in the mouth), BEG ×2 (sitting up, one paw raised). Nothing else in the picture.

> IMAGE "w470_enemy_attacks_2.png": ATTACK FRAMES for two common enemies, each one row: WIND-UP ×2, ATTACK ×3, RECOVER ×1, same style as the existing sheets (attach enemies/golem and enemies/shard). Row 0 THE GOLEM, 96×96 cells at x = 24 + N×120, y = 24: the mossy stone golem with amber eyes raises both fists, then slams the ground with a dust ring and a few pebbles (no cracks in anyone). Row 1 THE SHARD, 64×64 cells at x = 24 + N×88, y = 160: the floating purple crystal draws back and glows, then spins and flings a small crystal splinter forward, then settles. Then on row 2 (y = 260) the flung SPLINTER alone ×2 frames, 24×24. All ages: no blood.

======================================================================
COVERAGE TABLE (file → what it fixes → code name the slicer should write)
w466  villain faces                       → portraits/grump/neutral|happy|worried, portraits/commander/neutral|happy|worried + Dialogue.portrait_for map "big grump"→grump, "grump commander"→commander
w467  hero portraits, 3 gangster costumes → portraits/hero_outfit_pinstripe_suit|outfit_padded_vest|outfit_armored_suit/<mood> (name = the items.json "costume" value set from w460)
w468  hero portraits, 3 penguin costumes  → portraits/hero_outfit_puffy_parka|outfit_crystal_parka|outfit_starlight_mantle/<mood>
w469  pet poses                           → animals/dog_collie|dog_golden|dog_husky/play|fetch|beg, animals/dog_hound|dog_white/dig|fetch|beg, animals/cat_orange|cat_grey|cat_calico/dig|fetch|beg (pet.gd and game_map._place_pet pick them up by name)
w470  golem and shard attacks             → enemies/golem/attack, enemies/shard/attack (6 frames; enemy.gd loads "attack" when it exists), fx/shot_crystal (splinter, optional)

LEFT OUT ON PURPOSE
- Partner ability strips for Dad, Mom, Pax, Kairi and Sal: 19 w418/w419 already ask for 18 generic ability effects; mapping them is a slicer job.
- The four skill icons with no art (Starborn, Pressure II, Delegate II, Crystal Nursery II): already drawn in the w345/w349–w351 sheets; the matcher just needs to accept the " II" names.
- A walking sheet and select card for the Star Crystal: she isn't playable in any arc (arcs.json), so the title never shows her.
- New weather overlays: the old ov_ strips tile cleanly; only the ov2_ strips are broken, and that's a code fix.
- Death animations: 24 enemies already have a "die" strip the game never plays (code fix), so asking for more is pointless.
- Ride/swim/life sheets for the new costumes and hero portraits for skin/build variants: the game falls back cleanly.
- Place signs that "talk" (Diner, Ramen, Bank, Rest stop, Book, Journal, Letter...): text boxes, no face needed.

